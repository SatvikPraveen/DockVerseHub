# OpenTelemetry: Unified Instrumentation

**Duration:** 1.5 hours | **Level:** Advanced

---

## 🎯 What is OpenTelemetry?

OpenTelemetry is a vendor-neutral open standard for collecting metrics, traces, and logs from applications and infrastructure.

**Key Features:**
- Unified API across languages
- Multiple exporters support
- Zero-cost abstraction
- Auto-instrumentation
- Context propagation
- Language SDKs
- Backwards compatible

---

## 🏗️ Architecture

```
Application Code
  ├─ Metrics API
  ├─ Traces API
  └─ Logs API
      ↓
Instrumentation
  ├─ Manual
  ├─ Auto (Libraries)
  └─ Collector SDKs
      ↓
Processors
  ├─ Batch
  ├─ Simple
  └─ Span/Metric processors
      ↓
Exporters
  ├─ Jaeger
  ├─ Prometheus
  ├─ OpenTelemetry Protocol (OTLP)
  └─ Other vendors
      ↓
Backends
  ├─ Jaeger
  ├─ Prometheus
  ├─ Grafana
  └─ Others
```

---

## 📦 Installation

### Python

```bash
pip install opentelemetry-api
pip install opentelemetry-sdk
pip install opentelemetry-exporter-jaeger
pip install opentelemetry-exporter-prometheus
pip install opentelemetry-instrumentation-flask
pip install opentelemetry-instrumentation-sqlalchemy
pip install opentelemetry-instrumentation-requests
```

### Node.js

```bash
npm install @opentelemetry/api
npm install @opentelemetry/sdk-node
npm install @opentelemetry/auto-instrumentations-node
npm install @opentelemetry/exporter-trace-jaeger
npm install @opentelemetry/resources
npm install @opentelemetry/semantic-conventions
```

### Go

```bash
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/otel/sdk
go get go.opentelemetry.io/otel/exporter/jaeger/thrift
go get go.opentelemetry.io/otel/exporters/prometheus
```

---

## 🔧 Configuration

### Python Setup

```python
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Create resource
resource = Resource(attributes={
    SERVICE_NAME: "my-service"
})

# Setup tracing
jaeger_exporter = JaegerExporter(
    agent_host_name="localhost",
    agent_port=6831,
)
trace_provider = TracerProvider(resource=resource)
trace_provider.add_span_processor(BatchSpanProcessor(jaeger_exporter))
trace.set_tracer_provider(trace_provider)

# Setup metrics
prometheus_reader = PrometheusMetricReader()
metrics_provider = MeterProvider(
    resource=resource,
    metric_readers=[prometheus_reader]
)
metrics.set_meter_provider(metrics_provider)

# Auto-instrument libraries
FlaskInstrumentor().instrument()
SQLAlchemyInstrumentor().instrument()
RequestsInstrumentor().instrument()

# Get tracer
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
```

### Node.js Setup

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { JaegerExporter } = require('@opentelemetry/exporter-trace-jaeger');
const { PrometheusExporter } = require('@opentelemetry/exporter-prometheus');
const { MeterProvider, PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

const jaegerExporter = new JaegerExporter({
  endpoint: 'http://localhost:14268/api/traces',
});

const prometheusExporter = new PrometheusExporter(
  {
    port: 9090,
  },
  () => {
    console.log('Prometheus metrics ready at http://localhost:9090/metrics');
  }
);

const sdk = new NodeSDK({
  traceExporter: jaegerExporter,
  instrumentations: [getNodeAutoInstrumentations()],
  metricReader: new PeriodicExportingMetricReader(prometheusExporter),
});

sdk.start();
console.log('OpenTelemetry initialized');
```

### Go Setup

```go
package main

import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/sdk/trace"
    sdkmetric "go.opentelemetry.io/otel/sdk/metric"
    "go.opentelemetry.io/otel/exporter/jaeger/thrift"
    "go.opentelemetry.io/otel/exporters/prometheus"
    "go.opentelemetry.io/otel/sdk/resource"
    semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
)

func initOTel() {
    // Create resource
    res, _ := resource.New(context.Background(),
        resource.WithAttributes(semconv.ServiceName("my-service")),
    )

    // Setup tracing
    exporter, _ := thrift.New(
        thrift.WithAgentHost("localhost"),
        thrift.WithAgentPort(6831),
    )
    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(res),
    )
    otel.SetTracerProvider(tp)

    // Setup metrics
    prometheusExporter, _ := prometheus.New()
    mp := sdkmetric.NewMeterProvider(
        sdkmetric.WithReader(prometheusExporter),
        sdkmetric.WithResource(res),
    )
    otel.SetMeterProvider(mp)
}
```

---

## 📊 Metrics

### Counter

```python
from opentelemetry import metrics

meter = metrics.get_meter(__name__)

# Create counter
request_counter = meter.create_counter(
    name="http_requests_total",
    description="Total HTTP requests",
    unit="1"
)

# Increment
request_counter.add(1, {"method": "GET", "status": 200})
```

### Gauge

```python
# Create gauge
memory_gauge = meter.create_gauge(
    name="process_memory_bytes",
    description="Process memory usage",
    unit="bytes"
)

# Set value
memory_gauge.observe(123456789, {})
```

### Histogram

```python
# Create histogram
latency_histogram = meter.create_histogram(
    name="http_request_duration_ms",
    description="HTTP request latency",
    unit="ms"
)

# Record value
latency_histogram.record(45, {"method": "GET", "endpoint": "/api/users"})
```

---

## 🔗 Traces

### Creating Spans

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

# Start span
with tracer.start_as_current_span("process_request") as span:
    span.set_attribute("request.method", "GET")
    span.set_attribute("request.path", "/api/users")
    
    # Nested span
    with tracer.start_as_current_span("database_query") as db_span:
        db_span.set_attribute("db.system", "postgresql")
        db_span.set_attribute("db.statement", "SELECT * FROM users")
        
        # Do work
        result = query_database()
    
    return result
```

### Adding Events

```python
span.add_event(
    "cache_hit",
    attributes={
        "cache.key": "user:123",
        "cache.hit": True
    }
)

span.add_event(
    "error_occurred",
    attributes={
        "error.type": "ConnectionError",
        "error.message": "Connection refused"
    }
)
```

### Context Propagation

```python
from opentelemetry.propagate import extract, inject
from opentelemetry import trace

# In server receiving request
ctx = extract("http_headers", request.headers)
with tracer.start_as_current_span("handle_request", context=ctx):
    # Process request
    pass

# In client making request
headers = {}
span = tracer.start_span("call_service")
inject("http_headers", span, headers)
response = requests.get("http://other-service", headers=headers)
```

---

## 🔌 Exporters

### OTLP (OpenTelemetry Protocol)

```python
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

trace_exporter = OTLPSpanExporter(
    endpoint="localhost:4317",
)

metric_exporter = OTLPMetricExporter(
    endpoint="localhost:4317",
)
```

### Multiple Exporters

```python
# Export to both Jaeger and Prometheus
trace_provider.add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)
trace_provider.add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)
```

---

## 🏭 Collectors

### Collector Configuration

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  
  attributes:
    actions:
      - key: environment
        value: production
        action: insert

exporters:
  jaeger:
    endpoint: jaeger:14250
  
  prometheus:
    endpoint: 0.0.0.0:8888
  
  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [jaeger, logging]
    
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

### Docker Compose with Collector

```yaml
version: '3.8'

services:
  otel-collector:
    image: otel/opentelemetry-collector:latest
    ports:
      - "4317:4317"  # OTLP gRPC
      - "4318:4318"  # OTLP HTTP
      - "8888:8888"  # Prometheus
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    command: ["--config=/etc/otel-collector-config.yaml"]
    depends_on:
      - jaeger

  jaeger:
    image: jaegertracing/all-in-one
    ports:
      - "16686:16686"

  app:
    build: .
    environment:
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317
    depends_on:
      - otel-collector
```

---

## 🎓 Complete Example

### Instrumented Flask App

```python
from flask import Flask, request, jsonify
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from prometheus_client import start_http_server

app = Flask(__name__)

# Setup resource
resource = Resource(attributes={
    SERVICE_NAME: "shopping-api"
})

# Setup tracing
jaeger_exporter = JaegerExporter(
    agent_host_name="localhost",
    agent_port=6831,
)
trace_provider = TracerProvider(resource=resource)
trace_provider.add_span_processor(BatchSpanProcessor(jaeger_exporter))
trace.set_tracer_provider(trace_provider)

# Setup metrics
prometheus_reader = PrometheusMetricReader()
metrics_provider = MeterProvider(
    resource=resource,
    metric_readers=[prometheus_reader]
)
metrics.set_meter_provider(metrics_provider)

# Auto-instrument
FlaskInstrumentor().instrument_app(app)
SQLAlchemyInstrumentor().instrument()
RequestsInstrumentor().instrument()

# Start Prometheus server
start_http_server(8000)

# Get tracer and meter
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)

# Create custom metrics
order_counter = meter.create_counter(
    name="orders_total",
    description="Total orders"
)

order_duration = meter.create_histogram(
    name="order_processing_duration_ms",
    description="Order processing time"
)

@app.route('/api/orders', methods=['POST'])
def create_order():
    with tracer.start_as_current_span("create_order") as span:
        span.set_attribute("order.type", "purchase")
        
        # Process order
        order_data = request.get_json()
        
        # Call payment service
        with tracer.start_as_current_span("process_payment"):
            span.set_attribute("payment.method", order_data.get("method"))
            # Process payment
            payment_result = call_payment_service(order_data)
        
        # Save to database
        with tracer.start_as_current_span("save_order"):
            # Save to DB
            order = save_order(order_data)
        
        # Record metrics
        order_counter.add(1)
        order_duration.record(100)  # ms
        
        return jsonify({"order_id": order.id}), 201

if __name__ == '__main__':
    app.run(debug=True)
```

---

## 🚀 Best Practices

1. **Use semantic conventions**
   ```
   https://opentelemetry.io/docs/reference/specification/protocol/exporter/
   ```

2. **Set appropriate resource attributes**
   ```python
   Resource(attributes={
       SERVICE_NAME: "my-service",
       SERVICE_VERSION: "1.0.0",
       DEPLOYMENT_ENVIRONMENT: "production"
   })
   ```

3. **Use batch processors**
   ```python
   trace_provider.add_span_processor(
       BatchSpanProcessor(exporter)
   )
   ```

4. **Implement sampling**
   ```python
   from opentelemetry.sdk.trace.sampling import TraceIdRatioBased
   
   sampler = TraceIdRatioBased(0.1)  # 10%
   trace_provider = TracerProvider(sampler=sampler)
   ```

5. **Export via OTLP for flexibility**
   ```
   Use OTLP to support multiple backends
   ```

---

## 📚 Key Takeaways

1. ✅ OpenTelemetry unified instrumentation
2. ✅ Multiple languages supported
3. ✅ Flexible exporter architecture
4. ✅ Auto-instrumentation available
5. ✅ Vendor-neutral standard
6. ✅ Context propagation

---

## 🔗 Next Steps

1. Install OpenTelemetry SDK
2. Setup exporters
3. Instrument applications
4. Configure collectors
5. Export to multiple backends

