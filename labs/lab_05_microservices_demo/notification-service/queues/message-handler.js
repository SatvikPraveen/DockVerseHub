// File Location: labs/lab_05_microservices_demo/notification-service/queues/message-handler.js

const amqp = require("amqplib");
const kafka = require("kafkajs");

class MessageHandler {
  constructor(notificationService) {
    this.notificationService = notificationService;
    this.rabbitConnection = null;
    this.kafkaConsumer = null;
  }

  async initRabbitMQ() {
    const RABBITMQ_URL = process.env.RABBITMQ_URL || "amqp://localhost:5672";

    try {
      this.rabbitConnection = await amqp.connect(RABBITMQ_URL);
      const channel = await this.rabbitConnection.createChannel();

      // Declare exchanges and queues
      await channel.assertExchange("orders", "topic", { durable: true });
      await channel.assertExchange("users", "topic", { durable: true });

      const orderQueue = await channel.assertQueue("order_notifications", {
        durable: true,
      });
      const userQueue = await channel.assertQueue("user_notifications", {
        durable: true,
      });

      // Bind queues to exchanges
      await channel.bindQueue(orderQueue.queue, "orders", "order.*");
      await channel.bindQueue(userQueue.queue, "users", "user.*");

      // Set up consumers
      this.setupOrderConsumer(channel, orderQueue.queue);
      this.setupUserConsumer(channel, userQueue.queue);

      console.log("RabbitMQ message handlers initialized");
    } catch (error) {
      console.error("RabbitMQ initialization error:", error);
      throw error;
    }
  }

  async initKafka() {
    const KAFKA_BROKERS = process.env.KAFKA_BROKERS
      ? process.env.KAFKA_BROKERS.split(",")
      : ["localhost:9092"];

    try {
      const kafka_client = kafka({
        clientId: "notification-message-handler",
        brokers: KAFKA_BROKERS,
      });

      this.kafkaConsumer = kafka_client.consumer({
        groupId: "notification-message-group",
        sessionTimeout: 30000,
        heartbeatInterval: 3000,
      });

      await this.kafkaConsumer.connect();
      await this.kafkaConsumer.subscribe({
        topics: ["user-events", "order-events", "system-events"],
        fromBeginning: false,
      });

      await this.kafkaConsumer.run({
        eachMessage: async ({ topic, partition, message }) => {
          try {
            const data = JSON.parse(message.value.toString());
            await this.handleKafkaMessage(topic, data);
          } catch (error) {
            console.error("Kafka message processing error:", error);
          }
        },
      });

      console.log("Kafka message handlers initialized");
    } catch (error) {
      console.error("Kafka initialization error:", error);
    }
  }

  setupOrderConsumer(channel, queueName) {
    channel.consume(queueName, async (msg) => {
      if (msg !== null) {
        try {
          const data = JSON.parse(msg.content.toString());
          await this.handleOrderMessage(data);
          channel.ack(msg);
        } catch (error) {
          console.error("Order message processing error:", error);
          channel.nack(msg, false, false);
        }
      }
    });
  }

  setupUserConsumer(channel, queueName) {
    channel.consume(queueName, async (msg) => {
      if (msg !== null) {
        try {
          const data = JSON.parse(msg.content.toString());
          await this.handleUserMessage(data);
          channel.ack(msg);
        } catch (error) {
          console.error("User message processing error:", error);
          channel.nack(msg, false, false);
        }
      }
    });
  }

  async handleOrderMessage(data) {
    const { event_type, data: orderData } = data;

    let title,
      message,
      channel = "websocket";

    switch (event_type) {
      case "created":
        title = "Order Created";
        message = `Your order #${orderData.id} has been created successfully. Total: $${orderData.price}`;
        break;

      case "status_updated":
        title = "Order Status Updated";
        message = `Your order #${orderData.order_id} status is now: ${orderData.status}`;

        // Send email for important status changes
        if (["shipped", "delivered", "cancelled"].includes(orderData.status)) {
          channel = "email";
        }
        break;

      case "payment_failed":
        title = "Payment Failed";
        message = `Payment failed for order #${orderData.order_id}. Please update your payment method.`;
        channel = "email";
        break;

      default:
        console.log(`Unhandled order event type: ${event_type}`);
        return;
    }

    await this.notificationService.createNotification({
      userId: orderData.user_id || orderData.userId,
      type: "order",
      title,
      message,
      channel,
      metadata: {
        orderId: orderData.id || orderData.order_id,
        eventType: event_type,
        source: "rabbitmq",
      },
    });
  }

  async handleUserMessage(data) {
    const { event_type, data: userData } = data;

    let title,
      message,
      channel = "email";

    switch (event_type) {
      case "registered":
        title = "Welcome to DockVerseHub!";
        message = `Welcome ${userData.username}! Thank you for joining our microservices platform.`;
        break;

      case "password_changed":
        title = "Password Changed";
        message =
          "Your password has been successfully changed. If this wasn't you, please contact support.";
        break;

      case "profile_updated":
        title = "Profile Updated";
        message = "Your profile has been successfully updated.";
        channel = "websocket";
        break;

      default:
        console.log(`Unhandled user event type: ${event_type}`);
        return;
    }

    await this.notificationService.createNotification({
      userId: userData.id || userData.user_id,
      type: "user",
      title,
      message,
      channel,
      metadata: {
        eventType: event_type,
        email: userData.email,
        source: "rabbitmq",
      },
    });
  }

  async handleKafkaMessage(topic, data) {
    console.log(`Received Kafka message from topic: ${topic}`, data);

    switch (topic) {
      case "user-events":
        await this.handleUserMessage(data);
        break;

      case "order-events":
        await this.handleOrderMessage(data);
        break;

      case "system-events":
        await this.handleSystemMessage(data);
        break;

      default:
        console.log(`Unhandled Kafka topic: ${topic}`);
    }
  }

  async handleSystemMessage(data) {
    const { event_type, data: systemData } = data;

    // Handle system-wide notifications
    if (event_type === "maintenance_scheduled") {
      // Broadcast to all active users
      await this.notificationService.createNotification({
        userId: 0, // System notification
        type: "system",
        title: "Scheduled Maintenance",
        message: `System maintenance scheduled for ${systemData.scheduled_time}. Expected downtime: ${systemData.duration}`,
        channel: "broadcast",
        metadata: {
          eventType: event_type,
          source: "kafka",
          broadcast: true,
        },
      });
    }
  }

  async close() {
    try {
      if (this.kafkaConsumer) {
        await this.kafkaConsumer.disconnect();
      }

      if (this.rabbitConnection) {
        await this.rabbitConnection.close();
      }

      console.log("Message handlers closed");
    } catch (error) {
      console.error("Error closing message handlers:", error);
    }
  }
}

module.exports = MessageHandler;
