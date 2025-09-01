# 07_logging_monitoring/alerting/webhook-examples/slack-webhook.py

import json
import requests
from flask import Flask, request, jsonify
from datetime import datetime
import os
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Slack webhook configuration
SLACK_WEBHOOK_URL = os.getenv('SLACK_WEBHOOK_URL', 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK')
SLACK_CHANNEL = os.getenv('SLACK_CHANNEL', '#alerts')
SLACK_USERNAME = os.getenv('SLACK_USERNAME', 'AlertManager')

def format_alert_message(alert):
    """Format alert data for Slack message"""
    status = alert.get('status', 'unknown')
    labels = alert.get('labels', {})
    annotations = alert.get('annotations', {})
    
    # Determine color based on status and severity
    color = 'good'  # Green
    if status == 'firing':
        severity = labels.get('severity', 'info')
        if severity == 'critical':
            color = 'danger'  # Red
        elif severity == 'warning':
            color = 'warning'  # Yellow
    
    # Build the message
    title = f"🚨 {annotations.get('summary', 'Alert Triggered')}"
    
    fields = [
        {
            "title": "Status",
            "value": status.upper(),
            "short": True
        },
        {
            "title": "Severity", 
            "value": labels.get('severity', 'unknown').upper(),
            "short": True
        },
        {
            "title": "Alert Name",
            "value": labels.get('alertname', 'Unknown'),
            "short": True
        },
        {
            "title": "Instance",
            "value": labels.get('instance', 'Unknown'),
            "short": True
        }
    ]
    
    # Add description if available
    description = annotations.get('description')
    if description:
        fields.append({
            "title": "Description",
            "value": description,
            "short": False
        })
    
    # Add runbook URL if available
    runbook_url = annotations.get('runbook_url')
    if runbook_url:
        fields.append({
            "title": "Runbook",
            "value": f"<{runbook_url}|View Runbook>",
            "short": False
        })
    
    # Add generator URL if available
    generator_url = alert.get('generatorURL')
    if generator_url:
        fields.append({
            "title": "Graph",
            "value": f"<{generator_url}|View Graph>",
            "short": False
        })
    
    attachment = {
        "color": color,
        "title": title,
        "fields": fields,
        "footer": "AlertManager",
        "ts": int(datetime.utcnow().timestamp())
    }
    
    return attachment

def send_slack_message(attachments, text=""):
    """Send message to Slack via webhook"""
    payload = {
        "channel": SLACK_CHANNEL,
        "username": SLACK_USERNAME,
        "text": text,
        "attachments": attachments
    }
    
    try:
        response = requests.post(
            SLACK_WEBHOOK_URL,
            json=payload,
            timeout=10
        )
        response.raise_for_status()
        logger.info(f"Successfully sent alert to Slack")
        return True
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to send Slack message: {e}")
        return False

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()})

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
        
        # Group alerts by status
        firing_alerts = [alert for alert in alerts if alert.get('status') == 'firing']
        resolved_alerts = [alert for alert in alerts if alert.get('status') == 'resolved']
        
        attachments = []
        
        # Process firing alerts
        if firing_alerts:
            for alert in firing_alerts:
                attachment = format_alert_message(alert)
                attachments.append(attachment)
        
        # Process resolved alerts
        if resolved_alerts:
            for alert in resolved_alerts:
                attachment = format_alert_message(alert)
                attachment['color'] = 'good'
                attachment['title'] = f"✅ {alert.get('annotations', {}).get('summary', 'Alert Resolved')}"
                attachments.append(attachment)
        
        # Send to Slack
        if attachments:
            group_key = data.get('groupKey', 'unknown')
            text = f"Alert Group: {group_key}"
            
            success = send_slack_message(attachments, text)
            
            if success:
                return jsonify({'message': 'Alerts sent to Slack successfully'}), 200
            else:
                return jsonify({'error': 'Failed to send alerts to Slack'}), 500
        else:
            return jsonify({'message': 'No alerts to process'}), 200
            
    except Exception as e:
        logger.error(f"Error processing webhook: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/test', methods=['POST'])
def test_alert():
    """Test endpoint to send a sample alert"""
    test_alert = {
        "alerts": [
            {
                "status": "firing",
                "labels": {
                    "alertname": "TestAlert",
                    "severity": "warning",
                    "instance": "test-instance:8080"
                },
                "annotations": {
                    "summary": "This is a test alert from the webhook service",
                    "description": "Test alert generated to verify Slack integration",
                    "runbook_url": "https://runbooks.example.com/test-alert"
                },
                "generatorURL": "http://prometheus:9090/graph"
            }
        ],
        "groupKey": "test-group"
    }
    
    # Process the test alert
    return webhook()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting Slack webhook service on port {port}")
    logger.info(f"Slack channel: {SLACK_CHANNEL}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)