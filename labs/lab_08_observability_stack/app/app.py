"""
Lab 08 - Complete Observability Stack Application

This is an instrumented Flask application with:
- OpenTelemetry for metrics and tracing
- Prometheus metrics export
- Jaeger trace collection
- Redis caching
"""

import os
import random
import time
import json
from datetime import datetime
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest
import redis

# OpenTelemetry imports
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Initialize Flask
app = Flask(__name__)

# Initialize Redis
redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "localhost"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    decode_responses=True
)

# Create resource
resource = Resource(attributes={
    SERVICE_NAME: "lab-app",
    "service.version": "1.0.0",
    "deployment.environment": "lab"
})

# Setup Jaeger tracing
jaeger_exporter = JaegerExporter(
    agent_host_name=os.getenv("JAEGER_AGENT_HOST", "localhost"),
    agent_port=int(os.getenv("JAEGER_AGENT_PORT", 6831)),
)
trace_provider = TracerProvider(resource=resource)
trace_provider.add_span_processor(BatchSpanProcessor(jaeger_exporter))
trace.set_tracer_provider(trace_provider)

# Setup Prometheus metrics
prometheus_reader = PrometheusMetricReader()
metrics_provider = MeterProvider(
    resource=resource,
    metric_readers=[prometheus_reader]
)
metrics.set_meter_provider(metrics_provider)

# Auto-instrument
FlaskInstrumentor().instrument_app(app)
RedisInstrumentor().instrument(client=redis_client)
RequestsInstrumentor().instrument()

# Get tracer and meter
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)

# Create metrics
request_counter = meter.create_counter(
    name="app_requests_total",
    description="Total requests"
)
request_duration = meter.create_histogram(
    name="app_request_duration_ms",
    description="Request duration"
)
active_requests = meter.create_gauge(
    name="app_active_requests",
    description="Active requests"
)
error_counter = meter.create_counter(
    name="app_errors_total",
    description="Total errors"
)
cache_hits = meter.create_counter(
    name="cache_hits_total",
    description="Cache hits"
)

active_count = 0

@app.before_request
def before_request():
    global active_count
    active_count += 1
    active_requests.observe(active_count)
    request.start_time = time.time()

@app.after_request
def after_request(response):
    global active_count
    active_count -= 1
    active_requests.observe(active_count)
    
    duration = (time.time() - request.start_time) * 1000
    
    request_counter.add(1, {
        "method": request.method,
        "endpoint": request.path,
        "status": response.status_code
    })
    
    request_duration.record(int(duration), {
        "method": request.method,
        "endpoint": request.path
    })
    
    if response.status_code >= 400:
        error_counter.add(1, {"status": response.status_code})
    
    return response

# Routes

@app.route('/')
def index():
    """Homepage"""
    with tracer.start_as_current_span("index"):
        return jsonify({"status": "healthy", "service": "Lab App v1.0"})

@app.route('/health')
def health():
    """Health check"""
    return jsonify({"status": "healthy"}), 200

@app.route('/api/data')
def get_data():
    """Get sample data"""
    with tracer.start_as_current_span("get_data") as span:
        # Try cache
        cache_key = "sample_data"
        cached = redis_client.get(cache_key)
        
        if cached:
            cache_hits.add(1)
            span.set_attribute("cache.hit", True)
            return jsonify(json.loads(cached))
        
        # Simulate processing
        with tracer.start_as_current_span("compute"):
            time.sleep(random.uniform(0.01, 0.05))
            data = {"id": random.randint(1, 1000), "value": random.random() * 100}
        
        # Cache it
        redis_client.setex(cache_key, 60, json.dumps(data))
        
        span.set_attribute("cache.hit", False)
        return jsonify(data)

@app.route('/api/slow')
def slow_endpoint():
    """Intentionally slow endpoint for testing"""
    with tracer.start_as_current_span("slow_endpoint"):
        delay = random.uniform(0.5, 1.5)
        time.sleep(delay)
        return jsonify({"message": "Slow operation", "delay_ms": delay * 1000})

@app.route('/api/error')
def error_endpoint():
    """Intentionally returns error"""
    with tracer.start_as_current_span("error_endpoint") as span:
        span.set_attribute("error", True)
        span.set_attribute("error.kind", "TestError")
        return jsonify({"error": "Test error"}), 500

@app.route('/api/compute', methods=['POST'])
def compute():
    """Compute operation"""
    with tracer.start_as_current_span("compute_handler") as span:
        data = request.get_json() or {}
        value = data.get("value", 0)
        span.set_attribute("input", value)
        
        with tracer.start_as_current_span("math_operation"):
            result = value ** 2
            time.sleep(random.uniform(0.02, 0.1))
        
        span.set_attribute("output", result)
        return jsonify({"input": value, "output": result})

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(prometheus_reader)

if __name__ == '__main__':
    print("Starting Lab 08 App...")
    print(f"Redis: {os.getenv('REDIS_HOST', 'localhost')}:{os.getenv('REDIS_PORT', 6379)}")
    print(f"Jaeger: {os.getenv('JAEGER_AGENT_HOST', 'localhost')}:{os.getenv('JAEGER_AGENT_PORT', 6831)}")
    print("Listening on http://0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
