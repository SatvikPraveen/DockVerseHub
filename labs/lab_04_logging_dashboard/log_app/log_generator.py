# File Location: labs/lab_04_logging_dashboard/log_app/log_generator.py

import logging
import json
import datetime
import random
import time
import socket
import os
import threading
from typing import Dict, List

class LogGenerator:
    def __init__(self):
        self.logger = logging.getLogger('log_generator')
        self.start_time = time.time()
        self.stats = {
            'total_logs': 0,
            'total_errors': 0,
            'logs_by_level': {'DEBUG': 0, 'INFO': 0, 'WARNING': 0, 'ERROR': 0, 'FATAL': 0}
        }
        self.setup_logging()
    
    def setup_logging(self):
        """Setup structured logging for generated logs"""
        # Create formatter for generated logs
        class GeneratedLogFormatter(logging.Formatter):
            def format(self, record):
                log_entry = {
                    '@timestamp': datetime.datetime.utcnow().isoformat(),
                    'level': record.levelname,
                    'logger': record.name,
                    'message': record.getMessage(),
                    'service': 'generated_logs',
                    'host': {
                        'name': socket.gethostname(),
                        'ip': socket.gethostbyname(socket.gethostname())
                    },
                    'container': {
                        'name': os.getenv('HOSTNAME', socket.gethostname()),
                        'image': 'log_app:latest'
                    },
                    'environment': 'development',
                    'tags': ['generated', 'synthetic']
                }
                
                if hasattr(record, 'extra_fields'):
                    log_entry.update(record.extra_fields)
                
                return json.dumps(log_entry)
        
        # Setup handler for generated logs
        generated_handler = logging.FileHandler('/app/logs/generated.log')
        generated_handler.setFormatter(GeneratedLogFormatter())
        self.logger.addHandler(generated_handler)
        self.logger.setLevel(logging.DEBUG)
    
    def generate_logs(self, count: int, level: str = 'INFO') -> int:
        """Generate specified number of logs at given level"""
        generated_count = 0
        
        log_messages = self._get_sample_messages(level)
        
        for i in range(count):
            try:
                message = random.choice(log_messages)
                extra_fields = self._generate_extra_fields(level)
                
                # Create log record with extra fields
                record = logging.LogRecord(
                    name='generated_service',
                    level=getattr(logging, level),
                    pathname='',
                    lineno=0,
                    msg=message,
                    args=(),
                    exc_info=None
                )
                record.extra_fields = extra_fields
                
                self.logger.handle(record)
                
                generated_count += 1
                self.stats['total_logs'] += 1
                self.stats['logs_by_level'][level] += 1
                
                # Add small random delay to simulate realistic timing
                time.sleep(random.uniform(0.01, 0.1))
                
            except Exception as e:
                self.logger.error(f"Error generating log: {str(e)}")
        
        return generated_count
    
    def generate_errors(self, count: int) -> int:
        """Generate error logs with stack traces"""
        generated_count = 0
        
        error_scenarios = [
            "Database connection timeout",
            "Authentication failed for user",
            "Invalid API key provided",
            "Rate limit exceeded",
            "Service unavailable",
            "Failed to parse JSON request",
            "File not found",
            "Permission denied",
            "Network connection lost",
            "Memory allocation failed"
        ]
        
        for i in range(count):
            try:
                scenario = random.choice(error_scenarios)
                
                extra_fields = {
                    'error': {
                        'type': random.choice(['ConnectionError', 'AuthenticationError', 'ValidationError', 'SystemError']),
                        'code': random.choice([400, 401, 403, 404, 500, 502, 503, 504]),
                        'details': f"Error occurred in service component: {scenario}"
                    },
                    'request_id': f"req-{random.randint(10000, 99999)}",
                    'user_id': random.randint(1, 1000),
                    'operation': random.choice(['login', 'data_fetch', 'api_call', 'file_read', 'db_query'])
                }
                
                record = logging.LogRecord(
                    name='error_service',
                    level=logging.ERROR,
                    pathname='',
                    lineno=0,
                    msg=scenario,
                    args=(),
                    exc_info=None
                )
                record.extra_fields = extra_fields
                
                self.logger.handle(record)
                
                generated_count += 1
                self.stats['total_errors'] += 1
                self.stats['logs_by_level']['ERROR'] += 1
                
                time.sleep(random.uniform(0.1, 0.3))
                
            except Exception as e:
                self.logger.error(f"Error generating error log: {str(e)}")
        
        return generated_count
    
    def simulate_traffic(self, duration: int, requests_per_second: int):
        """Simulate HTTP traffic and generate access logs"""
        end_time = time.time() + duration
        request_interval = 1.0 / requests_per_second
        request_count = 0
        
        while time.time() < end_time:
            try:
                self._generate_access_log()
                request_count += 1
                time.sleep(request_interval)
            except Exception as e:
                self.logger.error(f"Error in traffic simulation: {str(e)}")
                break
        
        self.logger.info(f"Traffic simulation completed: {request_count} requests generated")
    
    def _generate_access_log(self):
        """Generate HTTP access log entry"""
        methods = ['GET', 'POST', 'PUT', 'DELETE']
        endpoints = ['/api/users', '/api/orders', '/api/products', '/api/auth', '/health', '/metrics']
        status_codes = [200, 200, 200, 201, 400, 401, 404, 500]  # Weighted towards success
        user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'curl/7.68.0',
            'Python-requests/2.28.1'
        ]
        
        method = random.choice(methods)
        endpoint = random.choice(endpoints)
        status_code = random.choice(status_codes)
        response_time = random.uniform(0.01, 2.0)
        bytes_sent = random.randint(100, 5000)
        
        # Simulate realistic IP addresses
        ip_address = f"{random.randint(10, 192)}.{random.randint(1, 255)}.{random.randint(1, 255)}.{random.randint(1, 255)}"
        
        extra_fields = {
            'http': {
                'method': method,
                'url': endpoint,
                'status_code': status_code,
                'response_time': round(response_time, 3),
                'bytes_sent': bytes_sent,
                'user_agent': random.choice(user_agents),
                'remote_ip': ip_address
            },
            'request_id': f"req-{random.randint(10000, 99999)}",
            'tags': ['http', 'access_log']
        }
        
        # Determine log level based on status code
        if status_code >= 500:
            level = logging.ERROR
            level_name = 'ERROR'
        elif status_code >= 400:
            level = logging.WARNING
            level_name = 'WARNING'
        else:
            level = logging.INFO
            level_name = 'INFO'
        
        message = f"{ip_address} - - [{datetime.datetime.utcnow().strftime('%d/%b/%Y:%H:%M:%S +0000')}] \"{method} {endpoint} HTTP/1.1\" {status_code} {bytes_sent}"
        
        record = logging.LogRecord(
            name='access_log',
            level=level,
            pathname='',
            lineno=0,
            msg=message,
            args=(),
            exc_info=None
        )
        record.extra_fields = extra_fields
        
        self.logger.handle(record)
        
        self.stats['total_logs'] += 1
        self.stats['logs_by_level'][level_name] += 1
    
    def _get_sample_messages(self, level: str) -> List[str]:
        """Get sample log messages for different levels"""
        messages = {
            'DEBUG': [
                'Processing user request',
                'Database query executed successfully',
                'Cache hit for key: user_profile_123',
                'Validating input parameters',
                'Starting background task',
                'Configuration loaded from file',
                'Connection pool initialized',
                'Parsing JSON response data'
            ],
            'INFO': [
                'User logged in successfully',
                'Order processed: #12345',
                'Email sent to user@example.com',
                'Service started on port 8080',
                'Health check passed',
                'Backup completed successfully',
                'User profile updated',
                'Payment processed successfully'
            ],
            'WARNING': [
                'High memory usage detected',
                'Slow query detected (>2s)',
                'Rate limit approaching for user',
                'Disk space running low',
                'Connection timeout, retrying',
                'Invalid input received, using default',
                'Session expired for user',
                'Service degraded performance'
            ],
            'ERROR': [
                'Database connection failed',
                'Authentication failed',
                'Payment processing error',
                'Service unavailable',
                'File not found: config.json',
                'Network connection lost',
                'Invalid API response format',
                'Permission denied for operation'
            ],
            'FATAL': [
                'System out of memory',
                'Critical service failure',
                'Database corruption detected',
                'Security breach detected',
                'System shutdown initiated',
                'Unrecoverable error occurred'
            ]
        }
        
        return messages.get(level, messages['INFO'])
    
    def _generate_extra_fields(self, level: str) -> Dict:
        """Generate additional fields for log entries"""
        base_fields = {
            'request_id': f"req-{random.randint(10000, 99999)}",
            'user_id': random.randint(1, 1000) if random.random() > 0.3 else None,
            'session_id': f"sess-{random.randint(1000, 9999)}",
            'operation': random.choice(['create', 'read', 'update', 'delete', 'process', 'validate']),
            'module': random.choice(['auth', 'user_mgmt', 'orders', 'payments', 'notifications', 'reports'])
        }
        
        # Add level-specific fields
        if level in ['ERROR', 'FATAL']:
            base_fields['error_code'] = random.randint(1000, 9999)
            base_fields['stack_trace'] = f"at module.function (line {random.randint(1, 100)})"
        
        if level == 'WARNING':
            base_fields['warning_type'] = random.choice(['performance', 'security', 'resource', 'validation'])
        
        return base_fields
    
    def get_stats(self) -> Dict:
        """Get current statistics"""
        return {
            **self.stats,
            'uptime_seconds': time.time() - self.start_time
        }