# 07_logging_monitoring/alerting/webhook-examples/generic-webhook.py

import json
import requests
from flask import Flask, request, jsonify
from datetime import datetime
import os
import logging
import sqlite3
import threading
from contextlib import contextmanager

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
DATABASE_PATH = os.getenv('DATABASE_PATH', '/tmp/alerts.db')
WEBHOOK_ENDPOINTS = os.getenv('WEBHOOK_ENDPOINTS', '').split(',')
WEBHOOK_ENDPOINTS = [url.strip() for url in WEBHOOK_ENDPOINTS if url.strip()]

# Initialize database
def init_database():
    """Initialize SQLite database for alert storage"""
    with sqlite3.connect(DATABASE_PATH) as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                group_key TEXT,
                status TEXT,
                alert_name TEXT,
                instance TEXT,
                severity TEXT,
                summary TEXT,
                description TEXT,
                labels TEXT,
                annotations TEXT,
                raw_data TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.execute('''
            CREATE INDEX IF NOT EXISTS idx_timestamp ON alerts(timestamp);
        ''')
        
        conn.execute('''
            CREATE INDEX IF NOT EXISTS idx_status ON alerts(status);
        ''')
        
        conn.execute('''
            CREATE INDEX IF NOT EXISTS idx_severity ON alerts(severity);
        ''')

@contextmanager
def get_db_connection():
    """Get database connection with context manager"""
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()

def store_alert(alert_data, group_key):
    """Store alert in database"""
    try:
        alerts = alert_data.get('alerts', [])
        
        with get_db_connection() as conn:
            for alert in alerts:
                labels = alert.get('labels', {})
                annotations = alert.get('annotations', {})
                
                conn.execute('''
                    INSERT INTO alerts (
                        timestamp, group_key, status, alert_name, instance, 
                        severity, summary, description, labels, annotations, raw_data
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    datetime.utcnow().isoformat(),
                    group_key,
                    alert.get('status'),
                    labels.get('alertname'),
                    labels.get('instance'),
                    labels.get('severity'),
                    annotations.get('summary'),
                    annotations.get('description'),
                    json.dumps(labels),
                    json.dumps(annotations),
                    json.dumps(alert)
                ))
            
            conn.commit()
            logger.info(f"Stored {len(alerts)} alerts to database")
            
    except Exception as e:
        logger.error(f"Failed to store alerts: {e}")

def forward_to_webhooks(data):
    """Forward alert data to configured webhook endpoints"""
    if not WEBHOOK_ENDPOINTS:
        return
    
    def send_webhook(url):
        try:
            response = requests.post(
                url,
                json=data,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            response.raise_for_status()
            logger.info(f"Successfully forwarded alert to {url}")
        except Exception as e:
            logger.error(f"Failed to forward alert to {url}: {e}")
    
    # Send webhooks in parallel
    threads = []
    for url in WEBHOOK_ENDPOINTS:
        thread = threading.Thread(target=send_webhook, args=(url,))
        thread.start()
        threads.append(thread)
    
    # Wait for all threads to complete (with timeout)
    for thread in threads:
        thread.join(timeout=15)

def process_alert_data(data):
    """Process and transform alert data"""
    alerts = data.get('alerts', [])
    processed_alerts = []
    
    for alert in alerts:
        labels = alert.get('labels', {})
        annotations = alert.get('annotations', {})
        
        processed_alert = {
            'id': f"{labels.get('alertname', '')}_{labels.get('instance', '')}",
            'status': alert.get('status'),
            'severity': labels.get('severity', 'unknown'),
            'alert_name': labels.get('alertname'),
            'instance': labels.get('instance'),
            'service': labels.get('service'),
            'job': labels.get('job'),
            'summary': annotations.get('summary'),
            'description': annotations.get('description'),
            'runbook_url': annotations.get('runbook_url'),
            'dashboard_url': annotations.get('dashboard_url'),
            'graph_url': alert.get('generatorURL'),
            'starts_at': alert.get('startsAt'),
            'ends_at': alert.get('endsAt'),
            'labels': labels,
            'annotations': annotations,
            'fingerprint': alert.get('fingerprint'),
            'processed_at': datetime.utcnow().isoformat()
        }
        
        processed_alerts.append(processed_alert)
    
    return {
        'group_key': data.get('groupKey'),
        'group_labels': data.get('groupLabels', {}),
        'common_labels': data.get('commonLabels', {}),
        'common_annotations': data.get('commonAnnotations', {}),
        'external_url': data.get('externalURL'),
        'version': data.get('version'),
        'alerts': processed_alerts,
        'alert_count': len(processed_alerts),
        'firing_count': len([a for a in processed_alerts if a['status'] == 'firing']),
        'resolved_count': len([a for a in processed_alerts if a['status'] == 'resolved']),
        'processed_at': datetime.utcnow().isoformat()
    }

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    try:
        with get_db_connection() as conn:
            cursor = conn.execute('SELECT COUNT(*) as count FROM alerts')
            alert_count = cursor.fetchone()['count']
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'database_path': DATABASE_PATH,
            'total_alerts': alert_count,
            'webhook_endpoints': len(WEBHOOK_ENDPOINTS),
            'configured_endpoints': WEBHOOK_ENDPOINTS
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 500

@app.route('/webhook', methods=['POST'])
def webhook():
    """Main webhook endpoint for AlertManager"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        logger.info(f"Received webhook with {len(data.get('alerts', []))} alerts")
        
        # Process alert data
        processed_data = process_alert_data(data)
        
        # Store alerts in database
        store_alert(data, processed_data['group_key'])
        
        # Forward to other webhooks
        forward_to_webhooks(processed_data)
        
        return jsonify({
            'message': 'Webhook processed successfully',
            'group_key': processed_data['group_key'],
            'alert_count': processed_data['alert_count'],
            'firing_count': processed_data['firing_count'],
            'resolved_count': processed_data['resolved_count'],
            'processed_at': processed_data['processed_at']
        }), 200
        
    except Exception as e:
        logger.error(f"Error processing webhook: {e}")
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@app.route('/alerts', methods=['GET'])
def get_alerts():
    """Get stored alerts with filtering and pagination"""
    try:
        # Query parameters
        limit = min(int(request.args.get('limit', 100)), 1000)
        offset = int(request.args.get('offset', 0))
        status = request.args.get('status')
        severity = request.args.get('severity')
        alert_name = request.args.get('alert_name')
        since_hours = request.args.get('since_hours', type=int)
        
        # Build query
        query = 'SELECT * FROM alerts WHERE 1=1'
        params = []
        
        if status:
            query += ' AND status = ?'
            params.append(status)
        
        if severity:
            query += ' AND severity = ?'
            params.append(severity)
        
        if alert_name:
            query += ' AND alert_name LIKE ?'
            params.append(f'%{alert_name}%')
        
        if since_hours:
            query += ' AND created_at > datetime("now", "-{} hours")'.format(since_hours)
        
        query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?'
        params.extend([limit, offset])
        
        with get_db_connection() as conn:
            cursor = conn.execute(query, params)
            alerts = [dict(row) for row in cursor.fetchall()]
            
            # Parse JSON fields
            for alert in alerts:
                alert['labels'] = json.loads(alert['labels']) if alert['labels'] else {}
                alert['annotations'] = json.loads(alert['annotations']) if alert['annotations'] else {}
                alert['raw_data'] = json.loads(alert['raw_data']) if alert['raw_data'] else {}
        
        return jsonify({
            'alerts': alerts,
            'count': len(alerts),
            'limit': limit,
            'offset': offset,
            'filters': {
                'status': status,
                'severity': severity,
                'alert_name': alert_name,
                'since_hours': since_hours
            }
        })
        
    except Exception as e:
        logger.error(f"Error getting alerts: {e}")
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@app.route('/alerts/stats', methods=['GET'])
def get_alert_stats():
    """Get alert statistics"""
    try:
        with get_db_connection() as conn:
            # Total alerts
            total = conn.execute('SELECT COUNT(*) as count FROM alerts').fetchone()['count']
            
            # Alerts by status
            status_stats = conn.execute('''
                SELECT status, COUNT(*) as count 
                FROM alerts 
                GROUP BY status
            ''').fetchall()
            
            # Alerts by severity
            severity_stats = conn.execute('''
                SELECT severity, COUNT(*) as count 
                FROM alerts 
                GROUP BY severity
            ''').fetchall()
            
            # Recent alerts (last 24 hours)
            recent = conn.execute('''
                SELECT COUNT(*) as count 
                FROM alerts 
                WHERE created_at > datetime("now", "-24 hours")
            ''').fetchone()['count']
            
            # Most frequent alerts
            frequent_alerts = conn.execute('''
                SELECT alert_name, COUNT(*) as count 
                FROM alerts 
                GROUP BY alert_name 
                ORDER BY count DESC 
                LIMIT 10
            ''').fetchall()
        
        return jsonify({
            'total_alerts': total,
            'recent_24h': recent,
            'by_status': {row['status']: row['count'] for row in status_stats},
            'by_severity': {row['severity']: row['count'] for row in severity_stats},
            'most_frequent': [dict(row) for row in frequent_alerts],
            'generated_at': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error getting alert stats: {e}")
        return jsonify({'error': 'Internal server error', 'details': str(e)}), 500

@app.route('/test', methods=['POST'])
def test_webhook():
    """Test endpoint to send a sample alert"""
    test_data = {
        "receiver": "webhook-test",
        "status": "firing",
        "alerts": [
            {
                "status": "firing",
                "labels": {
                    "alertname": "GenericWebhookTest",
                    "severity": "warning",
                    "instance": "test-instance:8080",
                    "job": "webhook-test",
                    "service": "generic-webhook"
                },
                "annotations": {
                    "summary": "Generic webhook test alert",
                    "description": "This is a test alert for the generic webhook service",
                    "runbook_url": "https://runbooks.example.com/webhook-test"
                },
                "startsAt": datetime.utcnow().isoformat() + "Z",
                "generatorURL": "http://prometheus:9090/graph",
                "fingerprint": "test123456789"
            }
        ],
        "groupLabels": {
            "alertname": "GenericWebhookTest"
        },
        "commonLabels": {
            "alertname": "GenericWebhookTest",
            "job": "webhook-test"
        },
        "commonAnnotations": {},
        "externalURL": "http://alertmanager:9093",
        "version": "4",
        "groupKey": "test-group-key"
    }
    
    # Process the test data
    return webhook()

if __name__ == '__main__':
    # Initialize database
    init_database()
    
    port = int(os.getenv('PORT', 8083))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting generic webhook service on port {port}")
    logger.info(f"Database path: {DATABASE_PATH}")
    if WEBHOOK_ENDPOINTS:
        logger.info(f"Forwarding to: {', '.join(WEBHOOK_ENDPOINTS)}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)