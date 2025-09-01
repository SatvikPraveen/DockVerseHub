# 07_logging_monitoring/alerting/webhook-examples/pagerduty-webhook.py

import json
import requests
from flask import Flask, request, jsonify
from datetime import datetime
import os
import logging
import hashlib

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# PagerDuty configuration
PAGERDUTY_INTEGRATION_KEY = os.getenv('PAGERDUTY_INTEGRATION_KEY', 'your-integration-key-here')
PAGERDUTY_API_URL = 'https://events.pagerduty.com/v2/enqueue'

def create_dedup_key(alert):
    """Create a deduplication key for PagerDuty"""
    labels = alert.get('labels', {})
    key_components = [
        labels.get('alertname', ''),
        labels.get('instance', ''),
        labels.get('service', ''),
        labels.get('job', '')
    ]
    key_string = '|'.join(filter(None, key_components))
    return hashlib.md5(key_string.encode()).hexdigest()

def format_pagerduty_event(alert, event_action='trigger'):
    """Format alert data for PagerDuty Events API v2"""
    labels = alert.get('labels', {})
    annotations = alert.get('annotations', {})
    
    # Determine severity mapping
    severity_map = {
        'critical': 'critical',
        'warning': 'warning', 
        'info': 'info',
        'unknown': 'info'
    }
    
    severity = labels.get('severity', 'unknown')
    pd_severity = severity_map.get(severity, 'info')
    
    # Create custom details
    custom_details = {
        'alert_name': labels.get('alertname', 'Unknown Alert'),
        'instance': labels.get('instance', 'Unknown Instance'),
        'job': labels.get('job', 'Unknown Job'),
        'severity': severity,
        'description': annotations.get('description', 'No description available'),
        'labels': labels,
        'annotations': annotations
    }
    
    # Add generator URL if available
    generator_url = alert.get('generatorURL')
    if generator_url:
        custom_details['graph_url'] = generator_url
    
    # Add runbook URL if available
    runbook_url = annotations.get('runbook_url')
    if runbook_url:
        custom_details['runbook_url'] = runbook_url
    
    event = {
        'routing_key': PAGERDUTY_INTEGRATION_KEY,
        'event_action': event_action,
        'dedup_key': create_dedup_key(alert),
        'payload': {
            'summary': annotations.get('summary', f"Alert: {labels.get('alertname', 'Unknown')}"),
            'source': labels.get('instance', 'AlertManager'),
            'severity': pd_severity,
            'component': labels.get('service', 'Unknown Service'),
            'group': labels.get('job', 'Unknown Job'),
            'class': labels.get('alertname', 'Alert'),
            'custom_details': custom_details
        }
    }
    
    # Add timestamps
    if event_action == 'trigger':
        fired_at = alert.get('startsAt')
        if fired_at:
            event['payload']['timestamp'] = fired_at
    
    return event

def send_pagerduty_event(event):
    """Send event to PagerDuty Events API"""
    try:
        response = requests.post(
            PAGERDUTY_API_URL,
            json=event,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        response.raise_for_status()
        
        result = response.json()
        logger.info(f"Successfully sent event to PagerDuty: {result}")
        return True, result
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to send PagerDuty event: {e}")
        return False, str(e)
    except Exception as e:
        logger.error(f"Unexpected error sending PagerDuty event: {e}")
        return False, str(e)

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy', 
        'timestamp': datetime.utcnow().isoformat(),
        'pagerduty_configured': bool(PAGERDUTY_INTEGRATION_KEY != 'your-integration-key-here')
    })

@app.route('/webhook', methods=['POST'])
def webhook():
    """Main webhook endpoint for AlertManager"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No JSON data provided'}), 400
        
        logger.info(f"Received webhook data: {json.dumps(data, indent=2)}")
        
        alerts = data.get('alerts', [])
        if not alerts:
            return jsonify({'error': 'No alerts in payload'}), 400
        
        results = []
        
        for alert in alerts:
            status = alert.get('status')
            labels = alert.get('labels', {})
            
            # Determine event action based on alert status
            if status == 'firing':
                event_action = 'trigger'
            elif status == 'resolved':
                event_action = 'resolve'
            else:
                logger.warning(f"Unknown alert status: {status}")
                continue
            
            # Only process critical and warning alerts for PagerDuty
            severity = labels.get('severity', 'info')
            if severity not in ['critical', 'warning']:
                logger.info(f"Skipping alert with severity: {severity}")
                continue
            
            # Create and send PagerDuty event
            event = format_pagerduty_event(alert, event_action)
            success, result = send_pagerduty_event(event)
            
            results.append({
                'alert': labels.get('alertname', 'Unknown'),
                'action': event_action,
                'success': success,
                'result': result
            })
        
        return jsonify({
            'message': f'Processed {len(results)} alerts',
            'results': results
        }), 200
        
    except Exception as e:
        logger.error(f"Error processing webhook: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/test', methods=['POST'])
def test_alert():
    """Test endpoint to send a sample alert to PagerDuty"""
    test_alert = {
        "status": "firing",
        "labels": {
            "alertname": "TestAlert",
            "severity": "critical",
            "instance": "test-instance:8080",
            "job": "test-job",
            "service": "test-service"
        },
        "annotations": {
            "summary": "Test alert for PagerDuty integration",
            "description": "This is a test alert to verify PagerDuty webhook integration",
            "runbook_url": "https://runbooks.example.com/test-alert"
        },
        "generatorURL": "http://prometheus:9090/graph?g0.expr=up",
        "startsAt": datetime.utcnow().isoformat() + "Z"
    }
    
    event = format_pagerduty_event(test_alert, 'trigger')
    success, result = send_pagerduty_event(event)
    
    return jsonify({
        'message': 'Test alert sent',
        'success': success,
        'result': result,
        'event': event
    }), 200 if success else 500

@app.route('/resolve', methods=['POST'])
def test_resolve():
    """Test endpoint to resolve a sample alert in PagerDuty"""
    test_alert = {
        "status": "resolved",
        "labels": {
            "alertname": "TestAlert",
            "severity": "critical",
            "instance": "test-instance:8080",
            "job": "test-job",
            "service": "test-service"
        },
        "annotations": {
            "summary": "Test alert for PagerDuty integration",
            "description": "This test alert has been resolved"
        }
    }
    
    event = format_pagerduty_event(test_alert, 'resolve')
    success, result = send_pagerduty_event(event)
    
    return jsonify({
        'message': 'Test alert resolved',
        'success': success,
        'result': result,
        'event': event
    }), 200 if success else 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8081))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    if PAGERDUTY_INTEGRATION_KEY == 'your-integration-key-here':
        logger.warning("PagerDuty integration key not configured!")
        logger.warning("Set PAGERDUTY_INTEGRATION_KEY environment variable")
    
    logger.info(f"Starting PagerDuty webhook service on port {port}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)