# Jaeger: Distributed Tracing

**Duration:** 2 hours | **Level:** Advanced

---

## 🎯 What is Jaeger?

Jaeger is an open-source distributed tracing platform for monitoring and troubleshooting transactions in complex microservices architectures.

**Key Features:**
- Trace visualization
- Latency analysis
- Dependency mapping
- Root cause analysis
- Multiple backends support
- Sampling strategies
- OpenTelemetry native

---

## 🏗️ Architecture

```
Applications           Jaeger Collectors        Storage              Query
├─ Service A    ┐                    ┌─────────────────────────────────┐
├─ Service B    ├─→ OpenTelemetry ──→├─ Elasticsearch               UI/API
├─ Service C    ┘    Protocol       │  or Cassandra  ──────────→ Visualization
└─ Service D                         │  or Badger
                                     └─────────────────────────────────┘
```

---

## 📦 Installation

### Docker Compose

```yaml
version: '3.8'

services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "6831:6831/udp"   # Jaeger agent
      - "16686:16686"     # UI
      - "14268:14268"     # Collector HTTP
    environment:
      COLLECTOR_ZIPKIN_HTTP_PORT: 9411
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:latest
        ports:
        - containerPort: 6831
          protocol: UDP
        - containerPort: 16686  # UI
        - containerPort: 14268  # Collector
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger
spec:
  selector:
    app: jaeger
  ports:
  - port: 6831
    targetPort: 6831
    protocol: UDP
    name: agent
  - port: 16686
    targetPort: 16686
    name: ui
  - port: 14268
    targetPort: 14268
    name: collector
  type: LoadBalancer
```

---

## 🔍 Core Concepts

### Span

A named, timed operation representing a unit of work.

```python
# Example span structure
{
  "traceID": "abc123",
  "spanID": "def456",
  "operationName": "GET /api/users",
  "startTime": 1234567890,
  "duration": 45,  # milliseconds
  "tags": {
    "http.method": "GET",
    "http.status_code": 200,
    "span.kind": "server"
  },
  "logs": [
    {
      "timestamp": 1234567891,
      "message": "Query started"
    }
  ],
  "references": [
    {
      "refType": "CHILD_OF",
      "traceID": "abc123",
      "spanID": "parent123"
    }
  ]
}
```

### Trace

A collection of spans representing a request flow.

```
Trace ID: abc123

GET /api/users (500ms total)
├─ Database query (100ms)
│  ├─ Connection setup (10ms)
│  └─ Execute query (90ms)
├─ Permission check (50ms)
│  └─ Cache lookup (20ms)
└─ Response formatting (100ms)
```

### Tags

Key-value pairs for span metadata.

```python
span.set_tag("http.method", "GET")
span.set_tag("http.status_code", 200)
span.set_tag("db.type", "postgresql")
span.set_tag("user.id", "12345")
```

### Logs

Timestamped messages within a span.

```python
span.log_kv({
    "event": "cache_miss",
    "cache_key": "user:123",
    "latency_ms": 5
})
```

---

## 🔗 Context Propagation

### W3C Trace Context

```
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
  ├─ version: 00
  ├─ trace-id: 0af7651916cd43dd8448eb211c80319c
  ├─ parent-id: b7ad6b7169203331
  └─ trace-flags: 01 (sampled)
```

### Jaeger Propagation

```
uber-trace-id: abc123:def456:0:1
  ├─ trace-id: abc123
  ├─ span-id: def456
  ├─ parent-id: 0
  └─ sampled: 1
```

### HTTP Header Example

```python
from jaeger_client import Config
from opentelemetry import trace, propagate
from opentelemetry.propagators.jaeger import JaegerPropagator

# Server receives request with trace header
@app.route('/api/data')
def handle_request():
    # Extract trace context from headers
    ctx = propagate.extract("http_headers", request.headers)
    
    with tracer.start_as_current_span("handle_request", context=ctx) as span:
        # Process request
        return jsonify(data)

# Client sends request with trace header
def make_request():
    span = tracer.start_span("call_downstream")
    headers = {}
    propagate.inject("http_headers", span, headers)
    
    response = requests.get("http://other-service/api", headers=headers)
    return response
```

---

## 📚 Instrumentation

### Python (OpenTelemetry)

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from jaeger_exporter import JaegerExporter

# Setup Jaeger exporter
jaeger_exporter = JaegerExporter(
    agent_host_name="localhost",
    agent_port=6831,
)

trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)

tracer = trace.get_tracer(__name__)

# Create spans
with tracer.start_as_current_span("process_request"):
    # Do work
    with tracer.start_as_current_span("database_query"):
        result = db.query("SELECT * FROM users")
```

### Node.js (OpenTelemetry)

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { JaegerExporter } = require('@opentelemetry/exporter-trace-jaeger');

const sdk = new NodeSDK({
  traceExporter: new JaegerExporter({
    endpoint: 'http://localhost:14268/api/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
console.log('Tracing initialized');

process.on('SIGTERM', () => {
  sdk.shutdown().then(() => console.log('Tracing terminated'));
});
```

### Go

```go
import (
    "github.com/jaegertracing/jaeger-client-go"
    "go.uber.org/zap"
)

func initTracer(service string) (opentracing.Tracer, closer io.Closer) {
    cfg := &config.Configuration{
        ServiceName: service,
        Sampler: &config.SamplerConfig{
            Type:  "const",
            Param: 1,
        },
        Reporter: &config.ReporterConfig{
            LocalAgentHostPort: "localhost:6831",
        },
    }
    
    tracer, closer, _ := cfg.NewTracer(config.Logger(jaeger.StdLogger))
    return tracer, closer
}

// Usage
tracer, closer := initTracer("my-service")
defer closer.Close()

span := tracer.StartSpan("my-operation")
defer span.Finish()
```

---

## 🎯 Sampling Strategies

### Const Sampler

```yaml
sampler:
  type: const
  param: 1  # Always sample
  # param: 0  # Never sample
```

### Probabilistic Sampler

```yaml
sampler:
  type: probabilistic
  param: 0.1  # Sample 10% of traces
```

### Rate Limiting Sampler

```yaml
sampler:
  type: ratelimiting
  param: 100  # Max 100 traces per second
```

### Remote Sampler

```yaml
sampler:
  type: remote
  param: 1
  samplingServerURL: http://jaeger-agent:5778/sampling
```

---

## 🔍 Trace Analysis

### Trace Details View

```
Operation: POST /api/checkout
Status: ERROR
Duration: 500ms
Services: 4
Errors: 1

Timeline:
├─ POST /api/checkout (500ms) [frontend]
│  ├─ Authorization (50ms) [auth-service]
│  ├─ Inventory check (100ms) [inventory-service] ⚠️ ERROR
│  └─ Payment (350ms) [payment-service]
└─ Response

Errors:
- inventory-service: Connection timeout
```

### Service Dependency Graph

```
Frontend
  ├─→ API Gateway
  │    ├─→ Auth Service
  │    ├─→ User Service
  │    │    └─→ PostgreSQL
  │    ├─→ Order Service
  │    │    └─→ MongoDB
  │    └─→ Payment Service
  │         └─→ Payment API
  └─→ Web Server
```

---

## 📊 Metrics from Traces

```yaml
# Example metrics derived from traces
- name: trace_duration_ms
  type: histogram
  desc: "Trace duration"
  labels: [service, operation, status]

- name: error_rate
  type: gauge
  desc: "Error rate per service"
  labels: [service]

- name: service_dependency_calls
  type: counter
  desc: "Calls between services"
  labels: [from_service, to_service]
```

---

## 🛠️ Advanced Features

### Error Tagging

```python
try:
    result = process_data()
except Exception as e:
    span.set_attribute("error", True)
    span.set_attribute("error.kind", type(e).__name__)
    span.set_attribute("error.message", str(e))
    raise
```

### Baggage (Context Propagation)

```python
from opentelemetry.baggage import get_baggage, set_baggage

# Set baggage
set_baggage("user_id", "12345")
set_baggage("request_id", "abc123")

# Get baggage in child span
user_id = get_baggage("user_id")
```

### Span Events

```python
span.add_event(
    "cache_hit",
    attributes={"cache_key": "user:123"}
)

span.add_event(
    "database_query_slow",
    attributes={"duration_ms": 500, "threshold_ms": 100}
)
```

---

## 🎓 Complete Example

### Application with Tracing

```python
from flask import Flask, request
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

app = Flask(__name__)

# Setup Jaeger
jaeger_exporter = JaegerExporter(
    agent_host_name="localhost",
    agent_port=6831,
)
trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)

# Auto-instrument
FlaskInstrumentor().instrument_app(app)
SQLAlchemyInstrumentor().instrument()

tracer = trace.get_tracer(__name__)

@app.route('/api/users/<user_id>')
def get_user(user_id):
    with tracer.start_as_current_span("get_user") as span:
        span.set_attribute("user.id", user_id)
        
        # This is auto-instrumented
        user = User.query.get(user_id)
        
        if not user:
            span.set_attribute("error", True)
            return {"error": "Not found"}, 404
        
        return user.to_dict()

if __name__ == '__main__':
    app.run(debug=True)
```

---

## 📚 Best Practices

1. **Use structured field names**
   ```
   Good: http.method, db.type, user.id
   Avoid: method, db, uid
   ```

2. **Sample appropriately**
   ```
   High traffic: 0.1% (every 1000th request)
   Normal: 1-10%
   Debug: 100%
   ```

3. **Propagate trace context**
   ```
   Always include trace headers in cross-service calls
   ```

4. **Tag for debugging**
   ```
   Always include: service, operation, status, error
   ```

5. **Monitor trace latency**
   ```
   High-latency traces indicate performance issues
   ```

---

## 📚 Key Takeaways

1. ✅ Jaeger enables distributed tracing
2. ✅ Traces show complete request flow
3. ✅ Context propagation across services
4. ✅ Root cause analysis of issues
5. ✅ Service dependency mapping
6. ✅ OpenTelemetry integration

---

## 🔗 Next Steps

1. Deploy Jaeger
2. Instrument applications
3. Propagate trace context
4. Analyze traces
5. Set up sampling

