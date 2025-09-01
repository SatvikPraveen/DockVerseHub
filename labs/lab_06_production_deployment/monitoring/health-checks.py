#!/usr/bin/env python3
# Location: labs/lab_06_production_deployment/monitoring/health-checks.py

import asyncio
import aiohttp
import json
import time
import logging
import os
import sys
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum

# Configuration
SERVICES = {
    'user-service': 'http://user-service:8000/health',
    'order-service': 'http://order-service:8001/health',
    'notification-service': 'http://notification-service:8002/health',
    'nginx': 'http://nginx/health',
    'grafana': 'http://grafana:3000/api/health',
    'prometheus': 'http://prometheus:9090/-/healthy'
}

DATABASES = {
    'postgres-user': 'postgresql://userdb_user:password@postgres-user:5432/userdb',
    'postgres-order': 'postgresql://orderdb_user:password@postgres-order:5432/orderdb',
    'mongodb': 'mongodb://notifydb_user:password@mongodb:27017/notifydb',
    'redis': 'redis://redis:6379',
    'elasticsearch': 'http://elasticsearch:9200/_cluster/health'
}

EXTERNAL_ENDPOINTS = {
    'domain': f"https://{os.getenv('DOMAIN', 'localhost')}/health",
    'api-users': f"https://{os.getenv('DOMAIN', 'localhost')}/api/v1/users/health",
    'api-orders': f"https://{os.getenv('DOMAIN', 'localhost')}/api/v1/orders/health"
}

class HealthStatus(Enum):
    HEALTHY = "healthy"
    UNHEALTHY = "unhealthy"
    DEGRADED = "degraded"
    UNKNOWN = "unknown"

@dataclass
class HealthResult:
    service: str
    status: HealthStatus
    response_time: float
    details: Dict
    error: Optional[str] = None

class HealthChecker:
    def __init__(self):
        self.session = None
        self.results: List[HealthResult] = []
        self.timeout = int(os.getenv('HEALTH_CHECK_TIMEOUT', '10'))
        self.retry_count = int(os.getenv('HEALTH_CHECK_RETRIES', '3'))
        
        # Setup logging
        log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
        logging.basicConfig(
            level=getattr(logging, log_level),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

    async def __aenter__(self):
        timeout = aiohttp.ClientTimeout(total=self.timeout)
        self.session = aiohttp.ClientSession(timeout=timeout)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    async def check_http_endpoint(self, name: str, url: str) -> HealthResult:
        start_time = time.time()
        
        for attempt in range(self.retry_count):
            try:
                async with self.session.get(url) as response:
                    response_time = time.time() - start_time
                    
                    if response.status == 200:
                        try:
                            data = await response.json()
                        except:
                            data = {"status": "ok", "content": await response.text()}
                        
                        return HealthResult(
                            service=name,
                            status=HealthStatus.HEALTHY,
                            response_time=response_time,
                            details=data
                        )
                    else:
                        details = {
                            "status_code": response.status,
                            "content": await response.text()
                        }
                        return HealthResult(
                            service=name,
                            status=HealthStatus.UNHEALTHY,
                            response_time=response_time,
                            details=details,
                            error=f"HTTP {response.status}"
                        )
                        
            except asyncio.TimeoutError:
                if attempt < self.retry_count - 1:
                    await asyncio.sleep(1)
                    continue
                    
                return HealthResult(
                    service=name,
                    status=HealthStatus.UNHEALTHY,
                    response_time=time.time() - start_time,
                    details={},
                    error="Timeout"
                )
                
            except Exception as e:
                if attempt < self.retry_count - 1:
                    await asyncio.sleep(1)
                    continue
                    
                return HealthResult(
                    service=name,
                    status=HealthStatus.UNHEALTHY,
                    response_time=time.time() - start_time,
                    details={},
                    error=str(e)
                )
        
        return HealthResult(
            service=name,
            status=HealthStatus.UNKNOWN,
            response_time=time.time() - start_time,
            details={},
            error="All retries failed"
        )

    async def check_database(self, name: str, connection_string: str) -> HealthResult:
        start_time = time.time()
        
        try:
            if connection_string.startswith('postgresql://'):
                return await self._check_postgres(name, connection_string, start_time)
            elif connection_string.startswith('mongodb://'):
                return await self._check_mongodb(name, connection_string, start_time)
            elif connection_string.startswith('redis://'):
                return await self._check_redis(name, connection_string, start_time)
            elif connection_string.startswith('http://') and 'elasticsearch' in name:
                return await self.check_http_endpoint(name, connection_string)
            else:
                return HealthResult(
                    service=name,
                    status=HealthStatus.UNKNOWN,
                    response_time=time.time() - start_time,
                    details={},
                    error="Unsupported database type"
                )
                
        except Exception as e:
            return HealthResult(
                service=name,
                status=HealthStatus.UNHEALTHY,
                response_time=time.time() - start_time,
                details={},
                error=str(e)
            )

    async def _check_postgres(self, name: str, connection_string: str, start_time: float) -> HealthResult:
        try:
            import asyncpg
            
            conn = await asyncpg.connect(connection_string)
            result = await conn.fetchval("SELECT 1")
            await conn.close()
            
            if result == 1:
                return HealthResult(
                    service=name,
                    status=HealthStatus.HEALTHY,
                    response_time=time.time() - start_time,
                    details={"database": "postgresql", "query": "SELECT 1"}
                )
            else:
                return HealthResult(
                    service=name,
                    status=HealthStatus.UNHEALTHY,
                    response_time=time.time() - start_time,
                    details={},
                    error="Query failed"
                )
                
        except ImportError:
            # Fallback to HTTP check if asyncpg not available
            self.logger.warning("asyncpg not available, skipping PostgreSQL health check")
            return HealthResult(
                service=name,
                status=HealthStatus.UNKNOWN,
                response_time=time.time() - start_time,
                details={},
                error="asyncpg not available"
            )

    async def _check_mongodb(self, name: str, connection_string: str, start_time: float) -> HealthResult:
        try:
            from motor.motor_asyncio import AsyncIOMotorClient
            
            client = AsyncIOMotorClient(connection_string)
            result = await client.admin.command('ping')
            client.close()
            
            if result.get('ok') == 1:
                return HealthResult(
                    service=name,
                    status=HealthStatus.HEALTHY,
                    response_time=time.time() - start_time,
                    details={"database": "mongodb", "command": "ping"}
                )
            else:
                return HealthResult(
                    service=name,
                    status=HealthStatus.UNHEALTHY,
                    response_time=time.time() - start_time,
                    details={},
                    error="Ping failed"
                )
                
        except ImportError:
            self.logger.warning("motor not available, skipping MongoDB health check")
            return HealthResult(
                service=name,
                status=HealthStatus.UNKNOWN,
                response_time=time.time() - start_time,
                details={},
                error="motor not available"
            )

    async def _check_redis(self, name: str, connection_string: str, start_time: float) -> HealthResult:
        try:
            import aioredis
            
            redis = aioredis.from_url(connection_string)
            result = await redis.ping()
            await redis.close()
            
            if result:
                return HealthResult(
                    service=name,
                    status=HealthStatus.HEALTHY,
                    response_time=time.time() - start_time,
                    details={"database": "redis", "command": "ping"}
                )
            else:
                return HealthResult(
                    service=name,
                    status=HealthStatus.UNHEALTHY,
                    response_time=time.time() - start_time,
                    details={},
                    error="Ping failed"
                )
                
        except ImportError:
            self.logger.warning("aioredis not available, skipping Redis health check")
            return HealthResult(
                service=name,
                status=HealthStatus.UNKNOWN,
                response_time=time.time() - start_time,
                details={},
                error="aioredis not available"
            )

    async def run_all_checks(self) -> Dict:
        self.results = []
        
        # Check services
        tasks = []
        for name, url in SERVICES.items():
            tasks.append(self.check_http_endpoint(name, url))
        
        # Check databases
        for name, connection_string in DATABASES.items():
            tasks.append(self.check_database(name, connection_string))
        
        # Check external endpoints
        for name, url in EXTERNAL_ENDPOINTS.items():
            tasks.append(self.check_http_endpoint(name, url))
        
        self.results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Handle exceptions
        for i, result in enumerate(self.results):
            if isinstance(result, Exception):
                service_name = list(SERVICES.keys()) + list(DATABASES.keys()) + list(EXTERNAL_ENDPOINTS.keys())
                self.results[i] = HealthResult(
                    service=service_name[i] if i < len(service_name) else f"unknown-{i}",
                    status=HealthStatus.UNHEALTHY,
                    response_time=0,
                    details={},
                    error=str(result)
                )
        
        return self.generate_summary()

    def generate_summary(self) -> Dict:
        healthy_count = sum(1 for r in self.results if r.status == HealthStatus.HEALTHY)
        unhealthy_count = sum(1 for r in self.results if r.status == HealthStatus.UNHEALTHY)
        degraded_count = sum(1 for r in self.results if r.status == HealthStatus.DEGRADED)
        unknown_count = sum(1 for r in self.results if r.status == HealthStatus.UNKNOWN)
        
        overall_status = HealthStatus.HEALTHY
        if unhealthy_count > 0:
            overall_status = HealthStatus.UNHEALTHY
        elif degraded_count > 0:
            overall_status = HealthStatus.DEGRADED
        elif unknown_count > 0:
            overall_status = HealthStatus.DEGRADED
        
        summary = {
            "timestamp": datetime.utcnow().isoformat(),
            "overall_status": overall_status.value,
            "summary": {
                "total": len(self.results),
                "healthy": healthy_count,
                "unhealthy": unhealthy_count,
                "degraded": degraded_count,
                "unknown": unknown_count
            },
            "services": []
        }
        
        for result in self.results:
            summary["services"].append({
                "name": result.service,
                "status": result.status.value,
                "response_time_ms": round(result.response_time * 1000, 2),
                "details": result.details,
                "error": result.error
            })
        
        return summary

    def send_notifications(self, summary: Dict):
        """Send notifications for unhealthy services"""
        unhealthy_services = [
            s for s in summary["services"] 
            if s["status"] in [HealthStatus.UNHEALTHY.value, HealthStatus.DEGRADED.value]
        ]
        
        if not unhealthy_services:
            return
        
        # Slack notification
        slack_webhook = os.getenv('SLACK_WEBHOOK')
        if slack_webhook:
            self._send_slack_notification(slack_webhook, unhealthy_services)
        
        # Email notification
        email_recipient = os.getenv('NOTIFICATION_EMAIL')
        if email_recipient:
            self._send_email_notification(email_recipient, unhealthy_services)

    def _send_slack_notification(self, webhook_url: str, unhealthy_services: List[Dict]):
        try:
            import requests
            
            message = f"🚨 Health Check Alert - {len(unhealthy_services)} services unhealthy"
            fields = []
            
            for service in unhealthy_services:
                fields.append({
                    "title": service["name"],
                    "value": f"Status: {service['status']}\nError: {service.get('error', 'N/A')}",
                    "short": True
                })
            
            payload = {
                "text": message,
                "attachments": [{
                    "color": "danger",
                    "fields": fields
                }]
            }
            
            response = requests.post(webhook_url, json=payload, timeout=10)
            if response.status_code == 200:
                self.logger.info("Slack notification sent successfully")
            else:
                self.logger.error(f"Failed to send Slack notification: {response.status_code}")
                
        except Exception as e:
            self.logger.error(f"Error sending Slack notification: {e}")

    def _send_email_notification(self, recipient: str, unhealthy_services: List[Dict]):
        try:
            import smtplib
            from email.mime.text import MimeText
            from email.mime.multipart import MimeMultipart
            
            smtp_host = os.getenv('SMTP_HOST')
            smtp_port = int(os.getenv('SMTP_PORT', '587'))
            smtp_user = os.getenv('SMTP_USER')
            smtp_password = os.getenv('SMTP_PASSWORD')
            
            if not all([smtp_host, smtp_user, smtp_password]):
                self.logger.warning("SMTP configuration incomplete, skipping email notification")
                return
            
            msg = MimeMultipart()
            msg['From'] = smtp_user
            msg['To'] = recipient
            msg['Subject'] = f"Health Check Alert - {len(unhealthy_services)} services unhealthy"
            
            body = f"""
Health Check Alert - {datetime.utcnow().isoformat()}

The following services are experiencing issues:

"""
            
            for service in unhealthy_services:
                body += f"- {service['name']}: {service['status']}"
                if service.get('error'):
                    body += f" (Error: {service['error']})"
                body += "\n"
            
            body += "\nPlease investigate and take appropriate action."
            
            msg.attach(MimeText(body, 'plain'))
            
            server = smtplib.SMTP(smtp_host, smtp_port)
            server.starttls()
            server.login(smtp_user, smtp_password)
            text = msg.as_string()
            server.sendmail(smtp_user, recipient, text)
            server.quit()
            
            self.logger.info("Email notification sent successfully")
            
        except Exception as e:
            self.logger.error(f"Error sending email notification: {e}")

async def main():
    output_file = os.getenv('HEALTH_CHECK_OUTPUT', '/tmp/health-check.json')
    
    async with HealthChecker() as checker:
        summary = await checker.run_all_checks()
        
        # Print summary
        print(json.dumps(summary, indent=2))
        
        # Save to file
        with open(output_file, 'w') as f:
            json.dump(summary, f, indent=2)
        
        # Send notifications if needed
        checker.send_notifications(summary)
        
        # Exit with appropriate code
        if summary["overall_status"] in [HealthStatus.UNHEALTHY.value, HealthStatus.DEGRADED.value]:
            sys.exit(1)
        else:
            sys.exit(0)

if __name__ == "__main__":
    asyncio.run(main())