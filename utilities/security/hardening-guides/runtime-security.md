# Location: utilities/security/hardening-guides/runtime-security.md

# Docker Runtime Security Guide

Comprehensive guide for securing Docker containers during runtime, including monitoring, threat detection, and incident response.

## Table of Contents

- [Runtime Threat Model](#runtime-threat-model)
- [Runtime Security Monitoring](#runtime-security-monitoring)
- [Access Control](#access-control)
- [Network Runtime Security](#network-runtime-security)
- [Process Monitoring](#process-monitoring)
- [Incident Response](#incident-response)

## Runtime Threat Model

### Common Runtime Threats

1. **Container Escape**: Breaking out of container isolation
2. **Privilege Escalation**: Gaining higher privileges than intended
3. **Resource Exhaustion**: DoS through resource consumption
4. **Data Exfiltration**: Unauthorized data access and theft
5. **Lateral Movement**: Moving between containers/hosts
6. **Malware Injection**: Runtime code injection attacks

### Attack Vectors

- Exploiting vulnerable applications
- Misconfigured container permissions
- Docker daemon vulnerabilities
- Kernel vulnerabilities
- Supply chain attacks

## Runtime Security Monitoring

### Falco Security Monitoring

```yaml
# falco-deployment.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
spec:
  selector:
    matchLabels:
      app: falco
  template:
    spec:
      serviceAccount: falco
      hostNetwork: true
      hostPID: true
      containers:
        - name: falco
          image: falcosecurity/falco:latest
          securityContext:
            privileged: true
          volumeMounts:
            - mountPath: /host/var/run/docker.sock
              name: docker-socket
            - mountPath: /host/proc
              name: proc-fs
            - mountPath: /etc/falco
              name: falco-config
      volumes:
        - name: docker-socket
          hostPath:
            path: /var/run/docker.sock
        - name: proc-fs
          hostPath:
            path: /proc
        - name: falco-config
          configMap:
            name: falco-rules
```

### Custom Security Rules

```yaml
# falco-rules.yaml
- rule: Suspicious Container Activity
  desc: Detect suspicious process execution
  condition: >
    spawned_process and container and
    (proc.name in (nc, ncat, netcat, nmap, socat, tcpdump))
  output: >
    Suspicious network tool executed in container
    (user=%user.name container=%container.name command=%proc.cmdline)
  priority: WARNING

- rule: Container Privilege Escalation
  desc: Detect privilege escalation attempts
  condition: >
    spawned_process and container and
    (proc.name in (sudo, su, setuid, chmod))
  output: >
    Potential privilege escalation in container
    (user=%user.name container=%container.name command=%proc.cmdline)
  priority: HIGH

- rule: Sensitive File Access
  desc: Monitor access to sensitive files
  condition: >
    open_read and container and
    (fd.name startswith /etc/passwd or
     fd.name startswith /etc/shadow or
     fd.name contains docker.sock)
  output: >
    Sensitive file accessed (file=%fd.name container=%container.name)
  priority: HIGH
```

## Access Control

### Runtime RBAC Policies

```bash
#!/bin/bash
# runtime-access-control.sh

check_container_permissions() {
    local container="$1"
    local user="$2"
    local operation="$3"

    # Get container info
    local image=$(docker inspect "$container" --format='{{.Config.Image}}')
    local running_user=$(docker inspect "$container" --format='{{.Config.User}}')

    # Check image whitelist
    if [[ ! "$image" =~ ^(registry\.company\.com|docker\.io/library) ]]; then
        echo "DENY: Unauthorized image"
        return 1
    fi

    # Check user permissions
    case "$operation" in
        "exec")
            if [[ "$user" != "admin" && "$image" != *"dev/"* ]]; then
                echo "DENY: Exec not allowed"
                return 1
            fi
            ;;
        "logs")
            echo "ALLOW: Log access permitted"
            ;;
        *)
            echo "DENY: Unknown operation"
            return 1
            ;;
    esac

    echo "ALLOW: Operation permitted"
    return 0
}

# Usage: check_container_permissions container_name user operation
check_container_permissions "$1" "$2" "$3"
```

## Network Runtime Security

### Network Monitoring Setup

```yaml
# network-security-stack.yml
version: "3.8"
services:
  suricata:
    image: jasonish/suricata:latest
    network_mode: host
    cap_add:
      - NET_ADMIN
    volumes:
      - ./suricata-config:/etc/suricata:ro
      - suricata-logs:/var/log/suricata
    command: suricata -c /etc/suricata/suricata.yaml -i docker0

  network-monitor:
    build:
      context: .
      dockerfile: Dockerfile.network-monitor
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - ALERT_WEBHOOK_URL=${WEBHOOK_URL}
    restart: unless-stopped

volumes:
  suricata-logs:
```

### Network Anomaly Detection

```python
# network-monitor.py
import docker
import time
import json
from collections import defaultdict, deque

class NetworkMonitor:
    def __init__(self):
        self.client = docker.from_env()
        self.connections = defaultdict(int)
        self.alerts = []

    def monitor_connections(self):
        """Monitor container network connections"""
        for container in self.client.containers.list():
            try:
                # Get network stats
                stats = container.stats(stream=False)
                networks = stats.get('networks', {})

                for net_name, net_stats in networks.items():
                    rx_bytes = net_stats.get('rx_bytes', 0)
                    tx_bytes = net_stats.get('tx_bytes', 0)

                    # Check for unusual traffic
                    if rx_bytes > 100 * 1024 * 1024:  # 100MB
                        self.create_alert(container.name,
                                        f"High incoming traffic: {rx_bytes} bytes")

                    if tx_bytes > 100 * 1024 * 1024:  # 100MB
                        self.create_alert(container.name,
                                        f"High outgoing traffic: {tx_bytes} bytes")

            except Exception as e:
                print(f"Error monitoring {container.name}: {e}")

    def create_alert(self, container, message):
        alert = {
            'timestamp': time.time(),
            'container': container,
            'message': message,
            'severity': 'warning'
        }
        self.alerts.append(alert)
        print(f"ALERT: {message} in container {container}")

if __name__ == "__main__":
    monitor = NetworkMonitor()
    while True:
        monitor.monitor_connections()
        time.sleep(30)
```

## Process Monitoring

### Runtime Process Analysis

```bash
#!/bin/bash
# process-monitor.sh

monitor_container_processes() {
    local container="$1"

    echo "Monitoring processes in container: $container"

    while true; do
        # Get running processes
        processes=$(docker exec "$container" ps aux 2>/dev/null || echo "")

        if [ -n "$processes" ]; then
            # Check for suspicious processes
            echo "$processes" | while IFS= read -r line; do
                case "$line" in
                    *nc\ *|*netcat*|*nmap*|*tcpdump*)
                        echo "ALERT: Suspicious network tool detected: $line"
                        ;;
                    *wget\ http*|*curl\ http*)
                        echo "WARNING: HTTP request detected: $line"
                        ;;
                    *chmod\ +x*|*chmod\ 777*)
                        echo "ALERT: Dangerous chmod operation: $line"
                        ;;
                esac
            done
        fi

        sleep 10
    done
}

# Monitor all running containers
for container in $(docker ps --format "{{.Names}}"); do
    monitor_container_processes "$container" &
done

wait
```

### System Call Monitoring

```yaml
# syscall-monitor.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sysdig-rules
data:
  rules.yaml: |
    - rule: Unexpected syscall
      desc: Detect dangerous system calls
      condition: >
        syscall and (
          syscall.type in (setuid, setgid, capset, mknod, mount, umount) or
          (syscall.type = openat and fd.name startswith /etc/passwd)
        )
      output: >
        Dangerous syscall executed
        (user=%user.name command=%proc.cmdline syscall=%syscall.type)
      priority: HIGH
```

## Incident Response

### Automated Response Actions

```python
# incident-response.py
import docker
import logging
from datetime import datetime

class IncidentResponder:
    def __init__(self):
        self.client = docker.from_env()
        self.setup_logging()

    def setup_logging(self):
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('security-incidents.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

    def quarantine_container(self, container_name, reason):
        """Isolate suspicious container"""
        try:
            container = self.client.containers.get(container_name)

            # Create quarantine network
            try:
                quarantine_net = self.client.networks.get('quarantine')
            except docker.errors.NotFound:
                quarantine_net = self.client.networks.create(
                    'quarantine',
                    driver='bridge',
                    internal=True  # No external access
                )

            # Disconnect from all networks except quarantine
            for network in container.attrs['NetworkSettings']['Networks']:
                if network != 'quarantine':
                    self.client.networks.get(network).disconnect(container)

            # Connect to quarantine network
            quarantine_net.connect(container)

            self.logger.warning(f"Container {container_name} quarantined: {reason}")

        except Exception as e:
            self.logger.error(f"Failed to quarantine {container_name}: {e}")

    def stop_container(self, container_name, reason):
        """Stop malicious container"""
        try:
            container = self.client.containers.get(container_name)
            container.stop(timeout=10)

            self.logger.critical(f"Container {container_name} stopped: {reason}")

        except Exception as e:
            self.logger.error(f"Failed to stop {container_name}: {e}")

    def collect_forensics(self, container_name):
        """Collect forensic data"""
        try:
            container = self.client.containers.get(container_name)

            # Export container filesystem
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            export_path = f"/forensics/{container_name}_{timestamp}.tar"

            with open(export_path, 'wb') as f:
                for chunk in container.export():
                    f.write(chunk)

            # Get container logs
            logs = container.logs(timestamps=True, tail=1000)
            with open(f"/forensics/{container_name}_{timestamp}.log", 'wb') as f:
                f.write(logs)

            self.logger.info(f"Forensic data collected for {container_name}")

        except Exception as e:
            self.logger.error(f"Failed to collect forensics for {container_name}: {e}")

# Usage
responder = IncidentResponder()

# Example incident response
def handle_security_alert(container_name, alert_type, severity):
    if severity == "CRITICAL":
        responder.collect_forensics(container_name)
        responder.stop_container(container_name, alert_type)
    elif severity == "HIGH":
        responder.quarantine_container(container_name, alert_type)
    else:
        responder.logger.warning(f"Security alert for {container_name}: {alert_type}")
```

### Incident Response Playbook

```yaml
# incident-response-playbook.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-playbook
data:
  playbook.yaml: |
    incidents:
      container_escape:
        severity: critical
        actions:
          - stop_container
          - collect_forensics
          - alert_security_team
          - isolate_host
        
      privilege_escalation:
        severity: high
        actions:
          - quarantine_container
          - collect_forensics
          - review_permissions
        
      suspicious_network:
        severity: medium
        actions:
          - monitor_traffic
          - log_connections
          - notify_admin
        
      malware_detected:
        severity: critical
        actions:
          - stop_container
          - scan_image
          - update_signatures
          - alert_security_team
```

## Security Automation

### Automated Remediation

```bash
#!/bin/bash
# auto-remediation.sh

remediate_security_incident() {
    local container="$1"
    local incident_type="$2"
    local severity="$3"

    case "$incident_type" in
        "container_escape"|"privilege_escalation")
            echo "CRITICAL: Stopping container $container"
            docker stop "$container"
            docker network disconnect bridge "$container" 2>/dev/null || true
            ;;
        "suspicious_process")
            echo "HIGH: Quarantining container $container"
            docker network create quarantine --internal 2>/dev/null || true
            docker network disconnect bridge "$container"
            docker network connect quarantine "$container"
            ;;
        "resource_abuse")
            echo "MEDIUM: Limiting resources for $container"
            docker update --memory=256m --cpus=0.5 "$container"
            ;;
    esac

    # Log incident
    echo "$(date): $severity - $incident_type in $container" >> /var/log/docker-security.log
}
```

## Compliance and Reporting

### Security Compliance Check

```bash
#!/bin/bash
# compliance-check.sh

check_runtime_compliance() {
    echo "Docker Runtime Security Compliance Check"
    echo "========================================"

    local score=100

    # Check 1: Non-root containers
    root_containers=$(docker ps --format "{{.Names}}" --filter "user=root" | wc -l)
    if [ "$root_containers" -gt 0 ]; then
        echo "❌ Found $root_containers containers running as root (-10)"
        ((score -= 10))
    else
        echo "✅ All containers running as non-root"
    fi

    # Check 2: Privileged containers
    priv_containers=$(docker ps --filter "status=running" --format "{{.Names}}" | \
        xargs -I {} docker inspect {} --format '{{.Name}} {{.HostConfig.Privileged}}' | \
        grep -c true)
    if [ "$priv_containers" -gt 0 ]; then
        echo "❌ Found $priv_containers privileged containers (-20)"
        ((score -= 20))
    else
        echo "✅ No privileged containers found"
    fi

    # Check 3: Resource limits
    no_limits=$(docker ps --format "{{.Names}}" | while read container; do
        memory=$(docker inspect "$container" --format '{{.HostConfig.Memory}}')
        if [ "$memory" = "0" ]; then
            echo "$container"
        fi
    done | wc -l)

    if [ "$no_limits" -gt 0 ]; then
        echo "⚠️  Found $no_limits containers without memory limits (-5)"
        ((score -= 5))
    else
        echo "✅ All containers have resource limits"
    fi

    echo ""
    echo "Final Compliance Score: $score/100"

    if [ "$score" -ge 90 ]; then
        echo "✅ EXCELLENT security posture"
    elif [ "$score" -ge 70 ]; then
        echo "⚠️  GOOD security posture with room for improvement"
    else
        echo "❌ POOR security posture - immediate action required"
        exit 1
    fi
}

check_runtime_compliance
```

## Security Checklist

### Runtime Security Checklist

- [ ] Security monitoring deployed (Falco/Sysdig)
- [ ] Network traffic monitoring enabled
- [ ] Process monitoring configured
- [ ] Incident response plan documented
- [ ] Automated remediation configured
- [ ] Security alerts configured
- [ ] Compliance checks automated
- [ ] Forensic collection ready
- [ ] Security training completed
- [ ] Regular security reviews scheduled

This runtime security guide provides comprehensive protection against threats during container execution. Regular monitoring, quick incident response, and automated remediation are key to maintaining a secure runtime environment.
