# Kafka Message Queue Configuration

This directory contains Apache Kafka configuration for the microservices demo. Kafka serves as the event streaming platform for asynchronous communication between services.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Service  │    │  Order Service  │    │Notification Svc │
│                 │    │                 │    │                 │
│ Publishes:      │    │ Publishes:      │    │ Consumes:       │
│ - user-events   │    │ - order-events  │    │ - user-events   │
│                 │    │                 │    │ - order-events  │
│ Consumes:       │    │ Consumes:       │    │ - notification- │
│ - none          │    │ - user-events   │    │   events        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Apache Kafka   │
                    │                 │
                    │ Topics:         │
                    │ - user-events   │
                    │ - order-events  │
                    │ - notification- │
                    │   events        │
                    │ - dead-letter-  │
                    │   queue         │
                    └─────────────────┘
```

## 📁 Files Overview

- **docker-compose.yml** - Complete Kafka setup with Zookeeper, Kafka UI, and topic initialization
- **producer.properties** - Producer configuration for optimal performance and reliability
- **consumer.properties** - Consumer configuration for reliable message consumption
- **README.md** - This documentation file

## 🚀 Quick Start

### 1. Start Kafka Infrastructure

```bash
# Start all Kafka services
docker-compose up -d

# Check service health
docker-compose ps

# View logs
docker-compose logs -f kafka
```

### 2. Access Kafka UI

Open your browser and navigate to:

- **Kafka UI**: http://localhost:8080

The UI provides:

- Topic management
- Message browsing
- Consumer group monitoring
- Performance metrics

### 3. Verify Topics

```bash
# List all topics
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

# Describe a topic
docker exec kafka kafka-topics --describe --topic user-events --bootstrap-server localhost:9092
```

## 📋 Available Topics

| Topic Name            | Partitions | Use Case                                                  |
| --------------------- | ---------- | --------------------------------------------------------- |
| `user-events`         | 3          | User registration, profile updates, authentication events |
| `order-events`        | 3          | Order creation, updates, cancellations, payments          |
| `notification-events` | 3          | Email, SMS, push notification requests                    |
| `dead-letter-queue`   | 1          | Failed message processing for debugging                   |

## 🔧 Configuration Details

### Producer Settings

- **Acknowledgments**: `all` (ensures message durability)
- **Retries**: `3` with exponential backoff
- **Idempotence**: Enabled to prevent duplicates
- **Compression**: Snappy for optimal performance
- **Batching**: Optimized for throughput

### Consumer Settings

- **Auto-commit**: Disabled for manual offset management
- **Isolation Level**: `read_committed`
- **Offset Reset**: `earliest` for complete message history
- **Session Timeout**: 30 seconds with 10-second heartbeats

## 📊 Monitoring

### Health Checks

```bash
# Check Kafka broker health
docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092

# Check Zookeeper health
docker exec zookeeper nc -z localhost 2181 && echo "ZK is alive"
```

### Performance Metrics

Access metrics via:

- **JMX Metrics**: Port 9101 (Kafka)
- **Kafka UI**: Real-time broker and topic metrics
- **Log Analysis**: View producer/consumer logs

## 🔐 Security Configuration

For production deployments, uncomment and configure:

```properties
# Enable SASL/SSL
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
    username="<username>" \
    password="<password>";

# SSL Configuration
ssl.truststore.location=/path/to/kafka.client.truststore.jks
ssl.truststore.password=<truststore-password>
ssl.keystore.location=/path/to/kafka.client.keystore.jks
ssl.keystore.password=<keystore-password>
```

## 🛠️ Common Operations

### Produce Messages

```bash
# Produce a test message
docker exec -it kafka kafka-console-producer --bootstrap-server localhost:9092 --topic user-events

# Example message format
{"eventType":"user.registered","userId":"123","timestamp":"2024-01-01T10:00:00Z","data":{"email":"user@example.com"}}
```

### Consume Messages

```bash
# Consume from beginning
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic user-events --from-beginning

# Consume with consumer group
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic user-events --group microservices-demo
```

### Manage Consumer Groups

```bash
# List consumer groups
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list

# Describe consumer group
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group microservices-demo
```

## 🚨 Troubleshooting

### Common Issues

**1. Kafka fails to start**

```bash
# Check Zookeeper is running first
docker-compose logs zookeeper

# Verify port availability
netstat -an | grep :9092
```

**2. Cannot produce/consume messages**

```bash
# Check topic exists
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

# Verify broker is leader for partitions
docker exec kafka kafka-topics --describe --topic user-events --bootstrap-server localhost:9092
```

**3. Consumer lag issues**

```bash
# Monitor consumer lag
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group microservices-demo

# Reset consumer group offset
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --group microservices-demo --reset-offsets --to-earliest --topic user-events --execute
```

### Log Analysis

```bash
# View Kafka logs
docker-compose logs kafka | grep ERROR

# View specific service logs
docker-compose logs kafka-ui
```

## 🔄 Integration with Services

### Python Example (User Service)

```python
from kafka import KafkaProducer, KafkaConsumer
import json

# Producer
producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    value_serializer=lambda x: json.dumps(x).encode('utf-8')
)

# Send user event
producer.send('user-events', {
    'eventType': 'user.registered',
    'userId': '123',
    'timestamp': '2024-01-01T10:00:00Z',
    'data': {'email': 'user@example.com'}
})
```

### Go Example (Order Service)

```go
package main

import (
    "github.com/Shopify/sarama"
    "encoding/json"
)

func main() {
    config := sarama.NewConfig()
    config.Producer.Return.Successes = true

    producer, _ := sarama.NewSyncProducer([]string{"localhost:9092"}, config)
    defer producer.Close()

    message := &sarama.ProducerMessage{
        Topic: "order-events",
        Value: sarama.StringEncoder(`{"eventType":"order.created","orderId":"456"}`),
    }

    producer.SendMessage(message)
}
```

### Node.js Example (Notification Service)

```javascript
const kafka = require("kafkajs");

const client = kafka({
  clientId: "notification-service",
  brokers: ["localhost:9092"],
});

const consumer = client.consumer({ groupId: "notification-group" });

const run = async () => {
  await consumer.connect();
  await consumer.subscribe({ topic: "notification-events" });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      const event = JSON.parse(message.value.toString());
      // Process notification event
      console.log("Processing notification:", event);
    },
  });
};

run().catch(console.error);
```

## 📚 Additional Resources

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka Best Practices](https://kafka.apache.org/documentation/#bestpractices)
- [Schema Registry Integration](https://docs.confluent.io/platform/current/schema-registry/index.html)
- [Kafka Connect](https://kafka.apache.org/documentation/#connect)

## 🤝 Contributing

When making changes to Kafka configuration:

1. Update relevant configuration files
2. Test with all microservices
3. Update this README with new topics or configurations
4. Ensure backward compatibility with existing consumers
