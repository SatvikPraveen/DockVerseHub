# File Location: concepts/03_volumes_bindmounts/Dockerfile
# Demo app persisting logs

FROM python:3.9-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Create log directory and set permissions
RUN mkdir -p /app/logs && chmod 755 /app/logs

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy application files
COPY app.py requirements.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Create the application
RUN cat > app.py << 'EOF'
import os
import time
import json
import logging
from datetime import datetime
from flask import Flask, jsonify
import signal
import sys

app = Flask(__name__)

# Configure logging to file
log_dir = '/app/logs'
os.makedirs(log_dir, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'{log_dir}/app.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# Request counter
request_count = 0

@app.route('/')
def hello():
    global request_count
    request_count += 1
    logger.info(f'Request #{request_count} received')
    
    return jsonify({
        'message': 'Hello from persistent logging app!',
        'request_count': request_count,
        'timestamp': datetime.now().isoformat(),
        'hostname': os.uname().nodename
    })

@app.route('/logs')
def get_logs():
    try:
        with open('/app/logs/app.log', 'r') as f:
            logs = f.readlines()[-50:]  # Last 50 lines
        return jsonify({
            'logs': [line.strip() for line in logs],
            'total_lines': len(logs)
        })
    except FileNotFoundError:
        return jsonify({'error': 'Log file not found'}), 404

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'uptime': time.time(),
        'log_file_exists': os.path.exists('/app/logs/app.log')
    })

@app.route('/generate-load')
def generate_load():
    """Generate some log entries for testing"""
    for i in range(10):
        logger.info(f'Generated log entry #{i+1}')
        time.sleep(0.1)
    return jsonify({'message': '10 log entries generated'})

def signal_handler(sig, frame):
    logger.info('Application shutting down gracefully')
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

if __name__ == '__main__':
    logger.info('Starting application')
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

# Create requirements.txt
RUN echo "flask==2.0.1" > requirements.txt && \
    pip install --no-cache-dir -r requirements.txt

# Change ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Volume for persistent logs
VOLUME ["/app/logs"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Expose port
EXPOSE 5000

# Start application
CMD ["python", "app.py"]