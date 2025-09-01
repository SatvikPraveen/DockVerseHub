# 09_advanced_tricks/debugging-tools/network-debugging.py

"""
Docker Network Debugging and Analysis Tool
Comprehensive network troubleshooting for Docker containers and networks
"""

import subprocess
import json
import sys
import argparse
import ipaddress
import socket
import time
from typing import Dict, List, Optional, Tuple
import threading
from dataclasses import dataclass
from datetime import datetime

@dataclass
class NetworkInfo:
    name: str
    driver: str
    scope: str
    subnet: str
    gateway: str
    containers: List[str]

@dataclass
class ContainerNetInfo:
    container_id: str
    name: str
    ip_address: str
    mac_address: str
    network_mode: str
    ports: Dict[str, str]

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'  # No Color

class DockerNetworkDebugger:
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.networks = {}
        self.containers = {}
        
    def log_info(self, message: str):
        print(f"{Colors.GREEN}[INFO]{Colors.NC} {message}")
    
    def log_warn(self, message: str):
        print(f"{Colors.YELLOW}[WARN]{Colors.NC} {message}")
    
    def log_error(self, message: str):
        print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")
    
    def log_debug(self, message: str):
        if self.verbose:
            print(f"{Colors.CYAN}[DEBUG]{Colors.NC} {message}")
    
    def print_header(self, title: str):
        print(f"\n{Colors.BLUE}{'='*20} {title} {'='*20}{Colors.NC}")
    
    def run_command(self, cmd: List[str]) -> Tuple[bool, str]:
        """Execute a command and return success status and output"""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            return result.returncode == 0, result.stdout.strip()
        except subprocess.TimeoutExpired:
            return False, "Command timed out"
        except Exception as e:
            return False, str(e)
    
    def docker_exec(self, container_id: str, command: List[str]) -> Tuple[bool, str]:
        """Execute command inside container"""
        cmd = ['docker', 'exec', container_id] + command
        return self.run_command(cmd)
    
    def get_docker_networks(self) -> Dict[str, NetworkInfo]:
        """Get all Docker networks and their information"""
        success, output = self.run_command(['docker', 'network', 'ls', '--format', 'json'])
        if not success:
            self.log_error("Failed to get Docker networks")
            return {}
        
        networks = {}
        for line in output.split('\n'):
            if line.strip():
                try:
                    net_data = json.loads(line)
                    net_id = net_data['ID']
                    
                    # Get detailed network information
                    success, detail = self.run_command(['docker', 'network', 'inspect', net_id])
                    if success:
                        detail_data = json.loads(detail)[0]
                        
                        # Extract subnet and gateway information
                        subnet = "N/A"
                        gateway = "N/A"
                        if 'IPAM' in detail_data and detail_data['IPAM']['Config']:
                            config = detail_data['IPAM']['Config'][0] if detail_data['IPAM']['Config'] else {}
                            subnet = config.get('Subnet', 'N/A')
                            gateway = config.get('Gateway', 'N/A')
                        
                        # Get connected containers
                        containers = list(detail_data.get('Containers', {}).keys())
                        
                        networks[net_id] = NetworkInfo(
                            name=net_data['Name'],
                            driver=net_data['Driver'],
                            scope=net_data['Scope'],
                            subnet=subnet,
                            gateway=gateway,
                            containers=containers
                        )
                except json.JSONDecodeError:
                    continue
        
        return networks
    
    def get_container_network_info(self, container_id: str) -> Optional[ContainerNetInfo]:
        """Get network information for a specific container"""
        success, output = self.run_command(['docker', 'inspect', container_id])
        if not success:
            return None
        
        try:
            data = json.loads(output)[0]
            
            # Extract network information
            network_settings = data.get('NetworkSettings', {})
            networks = network_settings.get('Networks', {})
            
            # Get primary network info (first network found)
            ip_address = "N/A"
            mac_address = "N/A"
            if networks:
                first_net = next(iter(networks.values()))
                ip_address = first_net.get('IPAddress', 'N/A')
                mac_address = first_net.get('MacAddress', 'N/A')
            
            # Extract port mappings
            ports = {}
            port_bindings = data.get('HostConfig', {}).get('PortBindings', {})
            for container_port, host_configs in port_bindings.items():
                if host_configs:
                    host_port = host_configs[0].get('HostPort', 'N/A')
                    ports[container_port] = host_port
            
            return ContainerNetInfo(
                container_id=container_id,
                name=data.get('Name', '').lstrip('/'),
                ip_address=ip_address,
                mac_address=mac_address,
                network_mode=data.get('HostConfig', {}).get('NetworkMode', 'N/A'),
                ports=ports
            )
        except (json.JSONDecodeError, KeyError, IndexError):
            return None
    
    def list_networks(self):
        """List all Docker networks with detailed information"""
        self.print_header("DOCKER NETWORKS")
        
        networks = self.get_docker_networks()
        if not networks:
            self.log_warn("No Docker networks found")
            return
        
        for net_id, info in networks.items():
            print(f"\n{Colors.WHITE}Network: {info.name}{Colors.NC}")
            print(f"  ID: {net_id[:12]}")
            print(f"  Driver: {info.driver}")
            print(f"  Scope: {info.scope}")
            print(f"  Subnet: {info.subnet}")
            print(f"  Gateway: {info.gateway}")
            print(f"  Connected Containers: {len(info.containers)}")
            
            if info.containers and self.verbose:
                for container_id in info.containers:
                    container_info = self.get_container_network_info(container_id)
                    if container_info:
                        print(f"    - {container_info.name} ({container_info.ip_address})")
    
    def inspect_container_network(self, container_id: str):
        """Inspect network configuration of a specific container"""
        self.print_header(f"CONTAINER NETWORK INSPECTION: {container_id}")
        
        container_info = self.get_container_network_info(container_id)
        if not container_info:
            self.log_error(f"Could not get network info for container {container_id}")
            return
        
        print(f"{Colors.WHITE}Container: {container_info.name}{Colors.NC}")
        print(f"ID: {container_info.container_id[:12]}")
        print(f"IP Address: {container_info.ip_address}")
        print(f"MAC Address: {container_info.mac_address}")
        print(f"Network Mode: {container_info.network_mode}")
        
        if container_info.ports:
            print(f"\n{Colors.CYAN}Port Mappings:{Colors.NC}")
            for container_port, host_port in container_info.ports.items():
                print(f"  {container_port} -> {host_port}")
        
        # Get detailed network interfaces from inside container
        print(f"\n{Colors.CYAN}Network Interfaces (inside container):{Colors.NC}")
        success, interfaces = self.docker_exec(container_id, ['ip', 'addr', 'show'])
        if success:
            print(interfaces)
        else:
            self.log_warn("Could not get network interfaces from container")
        
        # Get routing table
        print(f"\n{Colors.CYAN}Routing Table:{Colors.NC}")
        success, routes = self.docker_exec(container_id, ['ip', 'route', 'show'])
        if success:
            print(routes)
        else:
            self.log_warn("Could not get routing table from container")
        
        # Get DNS configuration
        print(f"\n{Colors.CYAN}DNS Configuration:{Colors.NC}")
        success, dns = self.docker_exec(container_id, ['cat', '/etc/resolv.conf'])
        if success:
            print(dns)
        else:
            self.log_warn("Could not read DNS configuration")
    
    def test_connectivity(self, source_container: str, target_container: str):
        """Test network connectivity between two containers"""
        self.print_header(f"CONNECTIVITY TEST: {source_container} -> {target_container}")
        
        # Get target container IP
        target_info = self.get_container_network_info(target_container)
        if not target_info:
            self.log_error(f"Could not get info for target container {target_container}")
            return
        
        target_ip = target_info.ip_address
        if target_ip == "N/A":
            self.log_error(f"Target container {target_container} has no IP address")
            return
        
        print(f"Testing connectivity from {source_container} to {target_container} ({target_ip})")
        
        # Ping test
        print(f"\n{Colors.CYAN}Ping Test:{Colors.NC}")
        success, output = self.docker_exec(source_container, ['ping', '-c', '3', target_ip])
        if success:
            print(output)
            self.log_info("Ping test successful")
        else:
            self.log_error("Ping test failed")
            print(output)
        
        # Port connectivity tests
        if target_info.ports:
            print(f"\n{Colors.CYAN}Port Connectivity Tests:{Colors.NC}")
            for container_port, _ in target_info.ports.items():
                port_num = container_port.split('/')[0]  # Remove protocol
                success, output = self.docker_exec(source_container, 
                    ['nc', '-z', '-v', target_ip, port_num])
                if success:
                    self.log_info(f"Port {port_num} is reachable")
                else:
                    self.log_warn(f"Port {port_num} is not reachable")
        
        # DNS resolution test
        print(f"\n{Colors.CYAN}DNS Resolution Test:{Colors.NC}")
        success, output = self.docker_exec(source_container, ['nslookup', target_info.name])
        if success:
            print(output)
            self.log_info("DNS resolution successful")
        else:
            self.log_warn("DNS resolution failed")
    
    def analyze_network_performance(self, container_id: str, duration: int = 10):
        """Analyze network performance of a container"""
        self.print_header(f"NETWORK PERFORMANCE ANALYSIS: {container_id}")
        
        print(f"Analyzing network performance for {duration} seconds...")
        
        # Get initial network statistics
        success, initial_stats = self.run_command(['docker', 'stats', '--no-stream', '--format', 'json', container_id])
        if not success:
            self.log_error("Could not get initial network stats")
            return
        
        time.sleep(duration)
        
        # Get final network statistics
        success, final_stats = self.run_command(['docker', 'stats', '--no-stream', '--format', 'json', container_id])
        if not success:
            self.log_error("Could not get final network stats")
            return
        
        try:
            initial_data = json.loads(initial_stats)
            final_data = json.loads(final_stats)
            
            # Parse network I/O data
            initial_net = initial_data['NetIO'].split(' / ')
            final_net = final_data['NetIO'].split(' / ')
            
            print(f"\n{Colors.CYAN}Network I/O Statistics:{Colors.NC}")
            print(f"Initial - RX: {initial_net[0]}, TX: {initial_net[1]}")
            print(f"Final - RX: {final_net[0]}, TX: {final_net[1]}")
            
        except (json.JSONDecodeError, KeyError, IndexError):
            self.log_error("Could not parse network statistics")
    
    def diagnose_network_issues(self, container_id: str):
        """Diagnose common network issues for a container"""
        self.print_header(f"NETWORK DIAGNOSTICS: {container_id}")
        
        container_info = self.get_container_network_info(container_id)
        if not container_info:
            self.log_error(f"Could not get container info for {container_id}")
            return
        
        issues_found = []
        
        # Check if container has IP address
        if container_info.ip_address == "N/A":
            issues_found.append("Container has no IP address assigned")
        
        # Test external connectivity
        print(f"{Colors.CYAN}Testing External Connectivity:{Colors.NC}")
        success, _ = self.docker_exec(container_id, ['ping', '-c', '1', '-W', '5', '8.8.8.8'])
        if not success:
            issues_found.append("No external internet connectivity")
            self.log_error("External connectivity failed")
        else:
            self.log_info("External connectivity OK")
        
        # Test DNS resolution
        print(f"\n{Colors.CYAN}Testing DNS Resolution:{Colors.NC}")
        success, _ = self.docker_exec(container_id, ['nslookup', 'google.com'])
        if not success:
            issues_found.append("DNS resolution not working")
            self.log_error("DNS resolution failed")
        else:
            self.log_info("DNS resolution OK")
        
        # Check for port conflicts
        if container_info.ports:
            print(f"\n{Colors.CYAN}Checking Port Mappings:{Colors.NC}")
            for container_port, host_port in container_info.ports.items():
                # Check if host port is actually listening
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(1)
                    result = sock.connect_ex(('localhost', int(host_port)))
                    sock.close()
                    
                    if result == 0:
                        self.log_info(f"Port {host_port} is accessible")
                    else:
                        issues_found.append(f"Host port {host_port} is not accessible")
                        self.log_warn(f"Host port {host_port} is not accessible")
                except ValueError:
                    issues_found.append(f"Invalid host port: {host_port}")
        
        # Check network configuration
        print(f"\n{Colors.CYAN}Network Configuration Analysis:{Colors.NC}")
        success, routes = self.docker_exec(container_id, ['ip', 'route', 'show'])
        if success:
            if 'default' not in routes:
                issues_found.append("No default route configured")
                self.log_warn("No default route found")
            else:
                self.log_info("Default route is configured")
        
        # Summary
        print(f"\n{Colors.CYAN}Diagnostic Summary:{Colors.NC}")
        if issues_found:
            self.log_warn(f"Found {len(issues_found)} potential issues:")
            for i, issue in enumerate(issues_found, 1):
                print(f"  {i}. {issue}")
        else:
            self.log_info("No network issues detected")
    
    def monitor_network_traffic(self, container_id: str, duration: int = 30):
        """Monitor network traffic for a container"""
        self.print_header(f"NETWORK TRAFFIC MONITORING: {container_id}")
        
        print(f"Monitoring network traffic for {duration} seconds...")
        print("Press Ctrl+C to stop early")
        
        try:
            # Use tcpdump inside container if available
            success, _ = self.docker_exec(container_id, ['which', 'tcpdump'])
            if success:
                print(f"\n{Colors.CYAN}Network Traffic (tcpdump):{Colors.NC}")
                cmd = ['docker', 'exec', container_id, 'tcpdump', '-i', 'any', '-n', '-c', '50']
                
                process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                
                start_time = time.time()
                while time.time() - start_time < duration:
                    try:
                        output = process.stdout.readline()
                        if output:
                            print(output.strip())
                        elif process.poll() is not None:
                            break
                    except KeyboardInterrupt:
                        break
                
                process.terminate()
            else:
                # Fallback to Docker stats
                print(f"\n{Colors.CYAN}Network I/O Monitoring:{Colors.NC}")
                cmd = ['docker', 'stats', '--format', 
                       'table {{.Container}}\\t{{.NetIO}}\\t{{.BlockIO}}', container_id]
                
                process = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True)
                
                start_time = time.time()
                while time.time() - start_time < duration:
                    try:
                        time.sleep(1)
                    except KeyboardInterrupt:
                        break
                
                process.terminate()
                
        except KeyboardInterrupt:
            self.log_info("Monitoring stopped by user")
    
    def trace_network_path(self, source_container: str, destination: str):
        """Trace network path from container to destination"""
        self.print_header(f"NETWORK PATH TRACE: {source_container} -> {destination}")
        
        # Try traceroute first
        success, output = self.docker_exec(source_container, ['traceroute', destination])
        if success:
            print(f"{Colors.CYAN}Traceroute Output:{Colors.NC}")
            print(output)
        else:
            # Fallback to ping with TTL
            print(f"{Colors.CYAN}TTL-based Path Trace:{Colors.NC}")
            for ttl in range(1, 11):
                success, output = self.docker_exec(source_container, 
                    ['ping', '-c', '1', '-t', str(ttl), destination])
                if 'Time to live exceeded' in output:
                    print(f"Hop {ttl}: TTL exceeded")
                elif 'bytes from' in output:
                    print(f"Hop {ttl}: Destination reached")
                    break
                else:
                    print(f"Hop {ttl}: No response")
    
    def generate_network_report(self, output_file: str):
        """Generate a comprehensive network report"""
        self.print_header("GENERATING NETWORK REPORT")
        
        report_data = {
            'timestamp': datetime.now().isoformat(),
            'networks': {},
            'containers': {},
            'connectivity_matrix': {}
        }
        
        # Get all networks
        networks = self.get_docker_networks()
        for net_id, net_info in networks.items():
            report_data['networks'][net_id] = {
                'name': net_info.name,
                'driver': net_info.driver,
                'subnet': net_info.subnet,
                'gateway': net_info.gateway,
                'container_count': len(net_info.containers)
            }
        
        # Get all containers with network info
        success, containers_output = self.run_command(['docker', 'ps', '-q'])
        if success:
            container_ids = containers_output.split('\n')
            for container_id in container_ids:
                if container_id.strip():
                    container_info = self.get_container_network_info(container_id.strip())
                    if container_info:
                        report_data['containers'][container_id] = {
                            'name': container_info.name,
                            'ip_address': container_info.ip_address,
                            'network_mode': container_info.network_mode,
                            'ports': container_info.ports
                        }
        
        # Save report
        with open(output_file, 'w') as f:
            json.dump(report_data, f, indent=2)
        
        self.log_info(f"Network report saved to {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Docker Network Debugging Tool')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('-c', '--container', help='Container ID or name to inspect')
    parser.add_argument('-n', '--networks', action='store_true', help='List all Docker networks')
    parser.add_argument('-t', '--test-connectivity', nargs=2, metavar=('SOURCE', 'TARGET'),
                       help='Test connectivity between two containers')
    parser.add_argument('-p', '--performance', help='Analyze network performance for container')
    parser.add_argument('-d', '--diagnose', help='Diagnose network issues for container')
    parser.add_argument('-m', '--monitor', help='Monitor network traffic for container')
    parser.add_argument('--duration', type=int, default=30, help='Duration for monitoring/performance tests')
    parser.add_argument('-r', '--report', help='Generate network report to file')
    parser.add_argument('--trace', nargs=2, metavar=('CONTAINER', 'DESTINATION'),
                       help='Trace network path from container to destination')
    
    args = parser.parse_args()
    
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    
    debugger = DockerNetworkDebugger(verbose=args.verbose)
    
    try:
        if args.networks:
            debugger.list_networks()
        
        if args.container:
            debugger.inspect_container_network(args.container)
        
        if args.test_connectivity:
            source, target = args.test_connectivity
            debugger.test_connectivity(source, target)
        
        if args.performance:
            debugger.analyze_network_performance(args.performance, args.duration)
        
        if args.diagnose:
            debugger.diagnose_network_issues(args.diagnose)
        
        if args.monitor:
            debugger.monitor_network_traffic(args.monitor, args.duration)
        
        if args.trace:
            container, destination = args.trace
            debugger.trace_network_path(container, destination)
        
        if args.report:
            debugger.generate_network_report(args.report)
    
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Operation cancelled by user{Colors.NC}")
        sys.exit(0)
    except Exception as e:
        print(f"{Colors.RED}Error: {e}{Colors.NC}")
        sys.exit(1)

if __name__ == '__main__':
    main()