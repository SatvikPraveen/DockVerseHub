// File Location: labs/lab_05_microservices_demo/database/mongodb/init-notification-db.js

// Initialize notifications database
db = db.getSiblingDB("notifications");

// Create collections
db.createCollection("notifications");
db.createCollection("templates");

// Create indexes
db.notifications.createIndex({ userId: 1, createdAt: -1 });
db.notifications.createIndex({ status: 1 });
db.notifications.createIndex({ type: 1 });
db.notifications.createIndex({ createdAt: -1 });

db.templates.createIndex({ type: 1 });
db.templates.createIndex({ channel: 1 });

// Insert sample notification templates
db.templates.insertMany([
  {
    type: "welcome",
    channel: "email",
    subject: "Welcome to DockVerseHub!",
    template: "Welcome {{username}}! Thank you for joining our platform.",
    createdAt: new Date(),
  },
  {
    type: "order_created",
    channel: "websocket",
    template: "Your order #{{orderId}} has been created successfully.",
    createdAt: new Date(),
  },
  {
    type: "order_status_updated",
    channel: "websocket",
    template: "Your order #{{orderId}} status is now: {{status}}.",
    createdAt: new Date(),
  },
]);

// Insert sample notifications
db.notifications.insertMany([
  {
    userId: 1,
    type: "system",
    title: "System Notification",
    message: "Welcome to the microservices demo!",
    channel: "websocket",
    status: "sent",
    createdAt: new Date(),
    updatedAt: new Date(),
  },
]);

print("Notification database initialized successfully");
