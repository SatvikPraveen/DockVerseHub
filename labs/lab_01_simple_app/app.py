# File Location: labs/lab_01_simple_app/app.py

from flask import Flask, jsonify
import os
import datetime
import socket

app = Flask(__name__)

@app.route('/')
def hello():
    """Main endpoint that returns welcome message"""
    custom_message = os.getenv('CUSTOM_MESSAGE', 'Hello from Docker!')
    hostname = socket.gethostname()
    timestamp = datetime.datetime.now().isoformat()
    
    return jsonify({
        'message': custom_message,
        'hostname': hostname,
        'timestamp': timestamp,
        'status': 'success'
    })

@app.route('/health')
def health_check():
    """Health check endpoint for Docker healthcheck"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now().isoformat(),
        'service': 'simple-app'
    }), 200

@app.route('/info')
def info():
    """System information endpoint"""
    import sys
    return jsonify({
        'python_version': sys.version,
        'hostname': socket.gethostname(),
        'environment': os.getenv('FLASK_ENV', 'development'),
        'custom_message': os.getenv('CUSTOM_MESSAGE', 'Not set')
    })

@app.route('/env')
def env_vars():
    """Display environment variables (excluding sensitive ones)"""
    safe_env_vars = {}
    sensitive_keys = ['PASSWORD', 'SECRET', 'KEY', 'TOKEN']
    
    for key, value in os.environ.items():
        if not any(sensitive_key in key.upper() for sensitive_key in sensitive_keys):
            safe_env_vars[key] = value
    
    return jsonify({
        'environment_variables': safe_env_vars,
        'count': len(safe_env_vars)
    })

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'
    
    print(f"Starting Flask application on port {port}")
    print(f"Debug mode: {debug}")
    print(f"Custom message: {os.getenv('CUSTOM_MESSAGE', 'Not set')}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)