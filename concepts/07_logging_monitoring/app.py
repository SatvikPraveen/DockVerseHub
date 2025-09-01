# 07_logging_monitoring/app.py

import json
import logging
import random
import time
from datetime import datetime
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import os
import threading

app = Flask(__name__)

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s'
)

logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency')
ACTIVE_CONNECTIONS = Gauge('active_connections', 'Active connections')
ERROR_COUNT = Counter('errors_total', 'Total errors', ['type'])

class StructuredLogger:
    @staticmethod
    def log(level, message, **kwargs):
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': level,
            'message': message,
            'service': os.getenv('APP_NAME', 'sample-app'),
            'version': '1.0.0',
            **kwargs
        }
        logger.info(json.dumps(log_entry))

structured_logger = StructuredLogger()

def generate_sample_logs():
    """Generate sample logs for demonstration"""
    events = [
        {'event': 'user_login', 'user_id': random.randint(1, 1000), 'success': True},
        {'event': 'api_call', 'endpoint': '/api/data', 'response_time': random.randint(10, 500)},
        {'event': 'database_query', 'query_time': random.randint(5, 200), 'rows_affected': random.randint(1, 100)},
        {'event': 'cache_hit', 'cache_key': f'user_{random.randint(1, 100)}', 'hit_rate': random.uniform(0.7, 0.95)},
        {'event': 'error_occurred', 'error_type': 'ValidationError', 'error_code': 400}
    ]
    
    event = random.choice(events)
    level = 'ERROR' if event.get('event') == 'error_occurred' else 'INFO'
    
    structured_logger.log(level, f"Application event: {event['event']}", **event)
    
    if event.get('event') == 'error_occurred':
        ERROR_COUNT.labels(type=event['error_type']).inc()

@app.before_request
def before_request():
    request.start_time = time.time()
    ACTIVE_CONNECTIONS.inc()

@app.after_request
def after_request(response):
    request_latency = time.time() - request.start_time
    REQUEST_LATENCY.observe(request_latency)
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    ACTIVE_CONNECTIONS.dec()
    
    # Log the request
    structured_logger.log(
        'INFO',
        'HTTP request processed',
        method=request.method,
        path=request.path,
        status_code=response.status_code,
        response_time=request_latency,
        user_agent=request.headers.get('User-Agent', 'unknown'),
        ip_address=request.remote_addr
    )
    
    return response

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()})

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/')
def index():
    """Main endpoint"""
    structured_logger.log('INFO', 'Index page accessed')
    return jsonify({
        'message': 'Sample logging application',
        'endpoints': ['/health', '/metrics', '/api/logs', '/api/data', '/api/error']
    })

@app.route('/api/logs')
def api_logs():
    """Trigger sample log generation"""
    for _ in range(random.randint(3, 10)):
        generate_sample_logs()
        time.sleep(0.1)
    
    structured_logger.log('INFO', 'Sample logs generated')
    return jsonify({'message': 'Sample logs generated successfully'})

@app.route('/api/data')
def api_data():
    """Sample data endpoint"""
    data = {
        'timestamp': datetime.utcnow().isoformat(),
        'data': [random.randint(1, 100) for _ in range(10)],
        'request_id': f'req_{random.randint(1000, 9999)}'
    }
    
    structured_logger.log(
        'INFO',
        'Data requested',
        request_id=data['request_id'],
        data_points=len(data['data'])
    )
    
    return jsonify(data)

@app.route('/api/error')
def api_error():
    """Intentionally trigger an error for testing"""
    error_types = ['DatabaseError', 'ValidationError', 'AuthenticationError']
    error_type = random.choice(error_types)
    
    structured_logger.log(
        'ERROR',
        f'Intentional error triggered: {error_type}',
        error_type=error_type,
        stack_trace='Traceback (most recent call last)...'
    )
    
    ERROR_COUNT.labels(type=error_type).inc()
    
    return jsonify({'error': error_type, 'message': 'This is a test error'}), 500

def background_log_generator():
    """Generate background logs to simulate real application activity"""
    while True:
        try:
            generate_sample_logs()
            time.sleep(random.randint(5, 15))
        except Exception as e:
            structured_logger.log('ERROR', 'Background log generation failed', error=str(e))

if __name__ == '__main__':
    # Start background log generation
    bg_thread = threading.Thread(target=background_log_generator, daemon=True)
    bg_thread.start()
    
    structured_logger.log('INFO', 'Application starting', port=8080)
    
    app.run(host='0.0.0.0', port=8080, debug=False)