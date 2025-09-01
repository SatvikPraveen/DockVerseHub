// File Location: labs/lab_05_microservices_demo/notification-service/app.js

const express = require("express");
const mongoose = require("mongoose");
const amqp = require("amqplib");
const kafka = require("kafkajs");
const nodemailer = require("nodemailer");
const WebSocket = require("ws");
const http = require("http");

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.use(express.json());

// Configuration
const PORT = process.env.PORT || 3000;
const MONGODB_URL =
  process.env.MONGODB_URL || "mongodb://localhost:27017/notifications";
const RABBITMQ_URL = process.env.RABBITMQ_URL || "amqp://localhost:5672";
const KAFKA_BROKERS = process.env.KAFKA_BROKERS
  ? process.env.KAFKA_BROKERS.split(",")
  : ["localhost:9092"];

// MongoDB Schema
const notificationSchema = new mongoose.Schema({
  userId: { type: Number, required: true },
  type: { type: String, required: true },
  title: { type: String, required: true },
  message: { type: String, required: true },
  channel: {
    type: String,
    enum: ["email", "sms", "push", "websocket"],
    default: "websocket",
  },
  status: {
    type: String,
    enum: ["pending", "sent", "failed"],
    default: "pending",
  },
  metadata: { type: Object, default: {} },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

const Notification = mongoose.model("Notification", notificationSchema);

// Email transporter
const emailTransporter = nodemailer.createTransporter({
  host: "localhost",
  port: 1025,
  ignoreTLS: true,
});

class NotificationService {
  constructor() {
    this.rabbitConnection = null;
    this.kafkaProducer = null;
    this.kafkaConsumer = null;
    this.websocketClients = new Map();
  }

  async initMongoDB() {
    try {
      await mongoose.connect(MONGODB_URL);
      console.log("Connected to MongoDB");
    } catch (error) {
      console.error("MongoDB connection error:", error);
      throw error;
    }
  }

  async initRabbitMQ() {
    try {
      this.rabbitConnection = await amqp.connect(RABBITMQ_URL);
      const channel = await this.rabbitConnection.createChannel();

      // Declare exchange and queue
      await channel.assertExchange("orders", "topic", { durable: true });
      const q = await channel.assertQueue("notifications", { durable: true });

      await channel.bindQueue(q.queue, "orders", "order.*");

      // Consume messages
      channel.consume(q.queue, (msg) => {
        if (msg !== null) {
          try {
            const data = JSON.parse(msg.content.toString());
            this.handleOrderEvent(data);
            channel.ack(msg);
          } catch (error) {
            console.error("Error processing message:", error);
            channel.nack(msg, false, false);
          }
        }
      });

      console.log("Connected to RabbitMQ");
    } catch (error) {
      console.error("RabbitMQ connection error:", error);
    }
  }

  async initKafka() {
    try {
      const kafka_client = kafka({
        clientId: "notification-service",
        brokers: KAFKA_BROKERS,
      });

      this.kafkaProducer = kafka_client.producer();
      await this.kafkaProducer.connect();

      this.kafkaConsumer = kafka_client.consumer({
        groupId: "notification-group",
      });
      await this.kafkaConsumer.connect();
      await this.kafkaConsumer.subscribe({ topic: "user-events" });

      await this.kafkaConsumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          try {
            const data = JSON.parse(message.value.toString());
            await this.handleUserEvent(data);
          } catch (error) {
            console.error("Error processing Kafka message:", error);
          }
        },
      });

      console.log("Connected to Kafka");
    } catch (error) {
      console.error("Kafka connection error:", error);
    }
  }

  initWebSocket() {
    wss.on("connection", (ws, req) => {
      console.log("New WebSocket connection");

      ws.on("message", (message) => {
        try {
          const data = JSON.parse(message.toString());
          if (data.type === "auth" && data.userId) {
            this.websocketClients.set(data.userId, ws);
            ws.send(
              JSON.stringify({ type: "auth_success", message: "Authenticated" })
            );
          }
        } catch (error) {
          console.error("WebSocket message error:", error);
        }
      });

      ws.on("close", () => {
        // Remove client from map
        for (const [userId, client] of this.websocketClients.entries()) {
          if (client === ws) {
            this.websocketClients.delete(userId);
            break;
          }
        }
      });
    });
  }

  async handleOrderEvent(data) {
    const { event_type, data: orderData } = data;

    let title, message;
    switch (event_type) {
      case "created":
        title = "Order Created";
        message = `Your order #${orderData.id} has been created successfully.`;
        break;
      case "status_updated":
        title = "Order Status Updated";
        message = `Your order #${orderData.order_id} status is now: ${orderData.status}`;
        break;
      default:
        return;
    }

    await this.createNotification({
      userId: orderData.user_id || orderData.userId,
      type: "order",
      title,
      message,
      channel: "websocket",
      metadata: {
        orderId: orderData.id || orderData.order_id,
        eventType: event_type,
      },
    });
  }

  async handleUserEvent(data) {
    const { event_type, user_data } = data;

    if (event_type === "user_registered") {
      await this.createNotification({
        userId: user_data.id,
        type: "welcome",
        title: "Welcome!",
        message: `Welcome to our platform, ${user_data.username}!`,
        channel: "email",
        metadata: { email: user_data.email },
      });
    }
  }

  async createNotification(notificationData) {
    try {
      const notification = new Notification(notificationData);
      await notification.save();

      await this.sendNotification(notification);
      return notification;
    } catch (error) {
      console.error("Error creating notification:", error);
      throw error;
    }
  }

  async sendNotification(notification) {
    try {
      switch (notification.channel) {
        case "websocket":
          await this.sendWebSocketNotification(notification);
          break;
        case "email":
          await this.sendEmailNotification(notification);
          break;
        case "sms":
          await this.sendSMSNotification(notification);
          break;
        case "push":
          await this.sendPushNotification(notification);
          break;
      }

      notification.status = "sent";
      notification.updatedAt = new Date();
      await notification.save();
    } catch (error) {
      console.error("Error sending notification:", error);
      notification.status = "failed";
      notification.updatedAt = new Date();
      await notification.save();
    }
  }

  async sendWebSocketNotification(notification) {
    const client = this.websocketClients.get(notification.userId);
    if (client && client.readyState === WebSocket.OPEN) {
      client.send(
        JSON.stringify({
          type: "notification",
          id: notification._id,
          title: notification.title,
          message: notification.message,
          createdAt: notification.createdAt,
        })
      );
    }
  }

  async sendEmailNotification(notification) {
    await emailTransporter.sendMail({
      from: "notifications@dockversehub.com",
      to: notification.metadata.email,
      subject: notification.title,
      text: notification.message,
      html: `<p>${notification.message}</p>`,
    });
  }

  async sendSMSNotification(notification) {
    // SMS implementation would go here
    console.log("SMS notification sent:", notification.message);
  }

  async sendPushNotification(notification) {
    // Push notification implementation would go here
    console.log("Push notification sent:", notification.message);
  }
}

// Initialize service
const notificationService = new NotificationService();

// Routes
app.get("/health", async (req, res) => {
  const health = {
    status: "healthy",
    service: "notification-service",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
    dependencies: {
      mongodb:
        mongoose.connection.readyState === 1 ? "connected" : "disconnected",
      rabbitmq: notificationService.rabbitConnection
        ? "connected"
        : "disconnected",
      kafka: notificationService.kafkaProducer ? "connected" : "disconnected",
    },
  };

  const overallHealthy = Object.values(health.dependencies).every(
    (status) => status === "connected"
  );
  if (!overallHealthy) {
    health.status = "degraded";
    res.status(503);
  }

  res.json(health);
});

app.post("/api/notifications", async (req, res) => {
  try {
    const {
      userId,
      type,
      title,
      message,
      channel = "websocket",
      metadata = {},
    } = req.body;

    if (!userId || !title || !message) {
      return res
        .status(400)
        .json({ error: "userId, title, and message are required" });
    }

    const notification = await notificationService.createNotification({
      userId,
      type,
      title,
      message,
      channel,
      metadata,
    });

    res.status(201).json({
      message: "Notification created successfully",
      notification: {
        id: notification._id,
        userId: notification.userId,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        status: notification.status,
        createdAt: notification.createdAt,
      },
    });
  } catch (error) {
    console.error("Error creating notification:", error);
    res.status(500).json({ error: "Failed to create notification" });
  }
});

app.get("/api/notifications/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50, offset = 0 } = req.query;

    const notifications = await Notification.find({ userId })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(offset));

    res.json({
      notifications,
      total: notifications.length,
    });
  } catch (error) {
    console.error("Error getting notifications:", error);
    res.status(500).json({ error: "Failed to get notifications" });
  }
});

app.post("/api/notifications/broadcast", async (req, res) => {
  try {
    const { title, message, userIds, channel = "websocket" } = req.body;

    if (!title || !message || !Array.isArray(userIds)) {
      return res
        .status(400)
        .json({ error: "title, message, and userIds array are required" });
    }

    const notifications = [];
    for (const userId of userIds) {
      const notification = await notificationService.createNotification({
        userId,
        type: "broadcast",
        title,
        message,
        channel,
        metadata: { broadcast: true },
      });
      notifications.push(notification);
    }

    res.json({
      message: "Broadcast notifications sent",
      count: notifications.length,
    });
  } catch (error) {
    console.error("Error broadcasting notifications:", error);
    res.status(500).json({ error: "Failed to broadcast notifications" });
  }
});

// Initialize and start server
async function startServer() {
  try {
    await notificationService.initMongoDB();
    notificationService.initWebSocket();

    // Initialize message queues (non-blocking)
    notificationService.initRabbitMQ().catch(console.error);
    notificationService.initKafka().catch(console.error);

    server.listen(PORT, () => {
      console.log(`Notification service running on port ${PORT}`);
    });
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
}

startServer();
