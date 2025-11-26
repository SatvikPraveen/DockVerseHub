"""
Instrumented Flask application with OpenTelemetry
Demonstrates metrics, traces, and logging integration
"""

import os
import random
import time
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest

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
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Initialize Flask
app = Flask(__name__)

# Create resource
resource = Resource(attributes={
    SERVICE_NAME: "observability-demo",
    "service.version": "1.0.0",
    "deployment.environment": "local"
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

# Auto-instrument Flask and Requests
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

# Get tracer and meter
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)

# Create custom metrics
request_counter = meter.create_counter(
    name="app_requests_total",
    description="Total application requests"
)

request_duration = meter.create_histogram(
    name="app_request_duration_ms",
    description="Application request duration"
)

active_requests = meter.create_gauge(
    name="app_active_requests",
    description="Active requests"
)

error_counter = meter.create_counter(
    name="app_errors_total",
    description="Total errors"
)

# Track active requests
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
    
    # Record metrics
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
        error_counter.add(1, {
            "status": response.status_code
        })
    
    return response

# Routes

@app.route('/')
def index():
    """Health check endpoint"""
    with tracer.start_as_current_span("index_handler"):
        return jsonify({
            "status": "healthy",
            "service": "observability-demo",
            "version": "1.0.0"
        })

@app.route('/api/data')
def get_data():
    """Get sample data - demonstrates normal operation"""
    with tracer.start_as_current_span("get_data"):
        # Simulate some processing
        with tracer.start_as_current_span("process_data"):
            time.sleep(random.uniform(0.01, 0.05))
            data = {
                "id": random.randint(1, 1000),
                "timestamp": time.time(),
                "value": random.random() * 100
            }
        
        return jsonify(data)

@app.route('/api/slow')
def slow_endpoint():
    """Slow endpoint - demonstrates latency"""
    with tracer.start_as_current_span("slow_endpoint"):
        with tracer.start_as_current_span("slow_operation"):
            sleep_time = random.uniform(0.5, 1.5)
            time.sleep(sleep_time)
        
        return jsonify({
            "message": "Slow operation completed",
            "duration": sleep_time
        })

@app.route('/api/error')
def error_endpoint():
    """Error endpoint - demonstrates error tracking"""
    with tracer.start_as_current_span("error_endpoint"):
        tracer.get_current_span().set_attribute("error.type", "DemoError")
        return jsonify({"error": "Intentional error"}), 500

@app.route('/api/compute', methods=['POST'])
def compute():
    """POST endpoint - demonstrates request handling"""
    with tracer.start_as_current_span("compute_handler") as span:
        data = request.get_json()
        span.set_attribute("input.value", data.get("value", 0))
        
        with tracer.start_as_current_span("computation"):
            # Simulate computation
            result = data.get("value", 0) ** 2
            time.sleep(random.uniform(0.01, 0.1))
        
        span.set_attribute("output.value", result)
        
        return jsonify({
            "input": data.get("value"),
            "output": result
        })

@app.route('/metrics')
def metrics_endpoint():
    """Prometheus metrics endpoint"""
    return generate_latest(prometheus_reader)

@app.route('/health')
def health():
    """Health check endpoint"""
    with tracer.start_as_current_span("health_check"):
        return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    print("Starting observability demo app...")
    print(f"Jaeger Agent: {os.getenv('JAEGER_AGENT_HOST', 'localhost')}:{os.getenv('JAEGER_AGENT_PORT', 6831)}")
    print("Listening on http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
