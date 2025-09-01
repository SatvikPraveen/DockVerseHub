# File Location: labs/lab_04_logging_dashboard/log_app/app.py

from flask import Flask, jsonify, request
import logging
import json
import datetime
import socket
import threading
import time
import os
import requests
from log_generator import LogGenerator

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/app.log'),
        logging.StreamHandler()
    ]
)

# Create structured log formatter
class StructuredFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            '@timestamp': datetime.datetime.utcnow().isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'service': 'log_app',
            'host': {
                'name': socket.gethostname(),
                'ip': socket.gethostbyname(socket.gethostname())
            },
            'container': {
                'name': os.getenv('HOSTNAME', socket.gethostname()),
                'image': 'log_app:latest'
            },
            'environment': 'development'
        }
        
        if record.exc_info:
            log_entry['error'] = {
                'type': record.exc_info[0].__name__,
                'stack_trace': self.formatException(record.exc_info)
            }
            
        return json.dumps(log_entry)

# Set up structured logging
structured_handler = logging.FileHandler('/app/logs/structured.log')
structured_handler.setFormatter(StructuredFormatter())

# Create logger
logger = logging.getLogger(__name__)
logger.addHandler(structured_handler)

# Initialize log generator
log_generator = LogGenerator()

@app.route('/')
def index():
    """Main endpoint"""
    logger.info("Index page accessed")
    return jsonify({
        'message': 'DockVerseHub Lab 04 - Log Generation App',
        'service': 'log_app',
        'timestamp': datetime.datetime.utcnow().isoformat(),
        'hostname': socket.gethostname(),
        'endpoints': [
            '/health',
            '/metrics',
            '/generate-logs',
            '/generate-errors',
            '/simulate-traffic'
        ]
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    logger.debug("Health check performed")
    return jsonify({
        'status': 'healthy',
        'service': 'log_app',
        'timestamp': datetime.datetime.utcnow().isoformat()
    }), 200

@app.route('/metrics')
def metrics():
    """Metrics endpoint"""
    logger.info("Metrics requested")
    return jsonify({
        'service': 'log_app',
        'metrics': {
            'logs_generated': log_generator.get_stats()['total_logs'],
            'errors_generated': log_generator.get_stats()['total_errors'],
            'uptime_seconds': time.time() - log_generator.start_time
        },
        'timestamp': datetime.datetime.utcnow().isoformat()
    })

@app.route('/generate-logs', methods=['POST'])
def generate_logs():
    """Generate sample logs"""
    try:
        data = request.get_json() or {}
        count = data.get('count', 10)
        log_level = data.get('level', 'INFO')
        
        logger.info(f"Generating {count} logs at level {log_level}")
        
        logs_generated = log_generator.generate_logs(count, log_level)
        
        logger.info(f"Successfully generated {logs_generated} log entries")
        
        return jsonify({
            'status': 'success',
            'logs_generated': logs_generated,
            'level': log_level,
            'timestamp': datetime.datetime.utcnow().isoformat()
        })
    
    except Exception as e:
        logger.error(f"Error generating logs: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.datetime.utcnow().isoformat()
        }), 500

@app.route('/generate-errors', methods=['POST'])
def generate_errors():
    """Generate error logs for testing"""
    try:
        data = request.get_json() or {}
        count = data.get('count', 5)
        
        logger.warning(f"Generating {count} error logs for testing")
        
        errors_generated = log_generator.generate_errors(count)
        
        return jsonify({
            'status': 'success',
            'errors_generated': errors_generated,
            'timestamp': datetime.datetime.utcnow().isoformat()
        })
    
    except Exception as e:
        logger.error(f"Error generating error logs: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.datetime.utcnow().isoformat()
        }), 500

@app.route('/simulate-traffic', methods=['POST'])
def simulate_traffic():
    """Simulate HTTP traffic for access log generation"""
    try:
        data = request.get_json() or {}
        duration = data.get('duration', 60)  # seconds
        requests_per_second = data.get('rps', 2)
        
        logger.info(f"Starting traffic simulation: {requests_per_second} req/s for {duration}s")
        
        def traffic_thread():
            log_generator.simulate_traffic(duration, requests_per_second)
        
        threading.Thread(target=traffic_thread, daemon=True).start()
        
        return jsonify({
            'status': 'success',
            'message': f'Traffic simulation started: {requests_per_second} req/s for {duration}s',
            'timestamp': datetime.datetime.utcnow().isoformat()
        })
    
    except Exception as e:
        logger.error(f"Error starting traffic simulation: {str(e)}", exc_info=True)
        return jsonify({
            'status': 'error',
            'error': str(e),
            'timestamp': datetime.datetime.utcnow().isoformat()
        }), 500

@app.route('/api/users')
def api_users():
    """Simulated API endpoint for generating access logs"""
    logger.info("API users endpoint accessed")
    
    # Simulate some processing time
    time.sleep(0.1)
    
    return jsonify({
        'users': [
            {'id': 1, 'name': 'Alice', 'email': 'alice@example.com'},
            {'id': 2, 'name': 'Bob', 'email': 'bob@example.com'},
            {'id': 3, 'name': 'Charlie', 'email': 'charlie@example.com'}
        ],
        'total': 3,
        'timestamp': datetime.datetime.utcnow().isoformat()
    })

@app.route('/api/orders')
def api_orders():
    """Simulated API endpoint for generating access logs"""
    logger.info("API orders endpoint accessed")
    
    # Simulate longer processing time
    time.sleep(0.2)
    
    return jsonify({
        'orders': [
            {'id': 101, 'user_id': 1, 'total': 29.99},
            {'id': 102, 'user_id': 2, 'total': 15.50}
        ],
        'total': 2,
        'timestamp': datetime.datetime.utcnow().isoformat()
    })

@app.route('/api/error-test')
def api_error_test():
    """Endpoint that intentionally generates errors for testing"""
    logger.warning("Error test endpoint accessed - generating intentional error")
    
    try:
        # Intentionally cause an error
        result = 1 / 0
    except ZeroDivisionError as e:
        logger.error("Intentional division by zero error", exc_info=True)
        return jsonify({
            'status': 'error',
            'error': 'Division by zero - this is intentional for testing',
            'timestamp': datetime.datetime.utcnow().isoformat()
        }), 500

def start_background_logging():
    """Start background log generation"""
    def background_thread():
        while True:
            try:
                # Generate some background logs every 30 seconds
                log_generator.generate_logs(5, 'INFO')
                time.sleep(30)
                
                # Occasionally generate warnings
                if time.time() % 120 < 30:  # Every 2 minutes for 30 seconds
                    log_generator.generate_logs(2, 'WARNING')
                
                # Rarely generate errors
                if time.time() % 300 < 30:  # Every 5 minutes for 30 seconds
                    log_generator.generate_errors(1)
                    
            except Exception as e:
                logger.error(f"Background logging error: {str(e)}", exc_info=True)
                time.sleep(60)  # Wait longer on error
    
    threading.Thread(target=background_thread, daemon=True).start()
    logger.info("Background log generation started")

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    debug = os.getenv('FLASK_ENV') == 'development'
    
    logger.info(f"Starting Log Generation App on port {port}")
    logger.info(f"Debug mode: {debug}")
    logger.info(f"Log level: {os.getenv('LOG_LEVEL', 'INFO')}")
    
    # Start background logging
    start_background_logging()
    
    app.run(host='0.0.0.0', port=port, debug=debug)