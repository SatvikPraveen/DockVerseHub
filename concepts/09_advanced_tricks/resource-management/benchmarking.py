# 09_advanced_tricks/resource-management/benchmarking.py

import time
import psutil
import docker
import json
import subprocess
import threading
import statistics
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from typing import List, Dict, Any
import argparse
import sys

@dataclass
class BenchmarkResult:
    """Container benchmark result structure"""
    container_name: str
    test_type: str
    duration: float
    cpu_usage_avg: float
    cpu_usage_max: float
    memory_usage_avg: int  # bytes
    memory_usage_max: int  # bytes
    disk_io_read: int      # bytes
    disk_io_write: int     # bytes
    network_io_rx: int     # bytes  
    network_io_tx: int     # bytes
    timestamp: str
    status: str
    error_message: str = ""

class ContainerBenchmark:
    """Advanced Docker container benchmarking tool"""
    
    def __init__(self, container_name: str):
        self.container_name = container_name
        self.docker_client = docker.from_env()
        self.container = None
        self.monitoring_active = False
        self.metrics = {
            'cpu_usage': [],
            'memory_usage': [],
            'disk_io': [],
            'network_io': []
        }
    
    def get_container(self):
        """Get container object"""
        try:
            self.container = self.docker_client.containers.get(self.container_name)
            return True
        except docker.errors.NotFound:
            print(f"❌ Container '{self.container_name}' not found")
            return False
        except Exception as e:
            print(f"❌ Error accessing container: {e}")
            return False
    
    def start_monitoring(self):
        """Start resource monitoring in background"""
        if not self.get_container():
            return False
        
        self.monitoring_active = True
        self.monitoring_thread = threading.Thread(target=self._monitor_resources)
        self.monitoring_thread.daemon = True
        self.monitoring_thread.start()
        return True
    
    def stop_monitoring(self):
        """Stop resource monitoring"""
        self.monitoring_active = False
        if hasattr(self, 'monitoring_thread'):
            self.monitoring_thread.join(timeout=2)
    
    def _monitor_resources(self):
        """Background resource monitoring"""
        while self.monitoring_active:
            try:
                # Get container stats
                stats = self.container.stats(stream=False)
                
                # Calculate CPU usage percentage
                cpu_usage = self._calculate_cpu_percent(stats)
                self.metrics['cpu_usage'].append(cpu_usage)
                
                # Memory usage
                memory_usage = stats['memory_stats']['usage']
                self.metrics['memory_usage'].append(memory_usage)
                
                # Disk I/O
                disk_io = stats.get('blkio_stats', {}).get('io_service_bytes_recursive', [])
                disk_read = sum(item['value'] for item in disk_io if item['op'] == 'Read')
                disk_write = sum(item['value'] for item in disk_io if item['op'] == 'Write')
                self.metrics['disk_io'].append({'read': disk_read, 'write': disk_write})
                
                # Network I/O
                networks = stats.get('networks', {})
                net_rx = sum(net['rx_bytes'] for net in networks.values())
                net_tx = sum(net['tx_bytes'] for net in networks.values())
                self.metrics['network_io'].append({'rx': net_rx, 'tx': net_tx})
                
            except Exception as e:
                print(f"⚠️ Monitoring error: {e}")
            
            time.sleep(1)
    
    def _calculate_cpu_percent(self, stats):
        """Calculate CPU usage percentage"""
        try:
            cpu_stats = stats['cpu_stats']
            precpu_stats = stats['precpu_stats']
            
            cpu_total = cpu_stats['cpu_usage']['total_usage']
            cpu_system = cpu_stats['system_cpu_usage']
            
            precpu_total = precpu_stats['cpu_usage']['total_usage']
            precpu_system = precpu_stats['system_cpu_usage']
            
            cpu_num = len(cpu_stats['cpu_usage']['percpu_usage'])
            
            cpu_delta = cpu_total - precpu_total
            system_delta = cpu_system - precpu_system
            
            if system_delta > 0:
                return (cpu_delta / system_delta) * cpu_num * 100.0
            return 0.0
        except (KeyError, ZeroDivisionError):
            return 0.0
    
    def benchmark_cpu(self, duration: int = 30) -> BenchmarkResult:
        """CPU-intensive benchmark"""
        print(f"🔥 Running CPU benchmark for {duration}s...")
        
        if not self.start_monitoring():
            return self._create_error_result("CPU", "Failed to start monitoring")
        
        start_time = time.time()
        
        # Execute CPU-intensive command in container
        try:
            cpu_cmd = f"timeout {duration} sh -c 'while true; do echo \"scale=5000; 4*a(1)\" | bc -l > /dev/null 2>&1; done'"
            exec_result = self.container.exec_run(cpu_cmd, detach=False)
            
        except Exception as e:
            self.stop_monitoring()
            return self._create_error_result("CPU", str(e))
        
        end_time = time.time()
        self.stop_monitoring()
        
        return self._create_result("CPU", end_time - start_time)
    
    def benchmark_memory(self, duration: int = 30, memory_mb: int = 100) -> BenchmarkResult:
        """Memory-intensive benchmark"""
        print(f"🧠 Running memory benchmark ({memory_mb}MB for {duration}s)...")
        
        if not self.start_monitoring():
            return self._create_error_result("Memory", "Failed to start monitoring")
        
        start_time = time.time()
        
        try:
            # Memory allocation command
            mem_cmd = f"timeout {duration} sh -c 'head -c {memory_mb}M /dev/zero > /tmp/memtest && sleep 10 && rm -f /tmp/memtest'"
            exec_result = self.container.exec_run(mem_cmd, detach=False)
            
        except Exception as e:
            self.stop_monitoring()
            return self._create_error_result("Memory", str(e))
        
        end_time = time.time()
        self.stop_monitoring()
        
        return self._create_result("Memory", end_time - start_time)
    
    def benchmark_disk_io(self, duration: int = 30, file_size_mb: int = 100) -> BenchmarkResult:
        """Disk I/O benchmark"""
        print(f"💾 Running disk I/O benchmark ({file_size_mb}MB for {duration}s)...")
        
        if not self.start_monitoring():
            return self._create_error_result("Disk I/O", "Failed to start monitoring")
        
        start_time = time.time()
        
        try:
            # Disk I/O commands
            io_cmd = f"""timeout {duration} sh -c '
            echo "Writing {file_size_mb}MB file..."
            dd if=/dev/zero of=/tmp/iotest bs=1M count={file_size_mb} 2>/dev/null
            echo "Reading file back..."
            dd if=/tmp/iotest of=/dev/null bs=1M 2>/dev/null
            echo "Random I/O test..."
            for i in $(seq 1 10); do
                dd if=/dev/urandom of=/tmp/random$i bs=1M count=10 2>/dev/null &
            done
            wait
            rm -f /tmp/iotest /tmp/random*
            '"""
            exec_result = self.container.exec_run(io_cmd, detach=False)
            
        except Exception as e:
            self.stop_monitoring()
            return self._create_error_result("Disk I/O", str(e))
        
        end_time = time.time()
        self.stop_monitoring()
        
        return self._create_result("Disk I/O", end_time - start_time)
    
    def benchmark_network(self, duration: int = 30) -> BenchmarkResult:
        """Network benchmark (internal)"""
        print(f"🌐 Running network benchmark for {duration}s...")
        
        if not self.start_monitoring():
            return self._create_error_result("Network", "Failed to start monitoring")
        
        start_time = time.time()
        
        try:
            # Network activity simulation
            net_cmd = f"""timeout {duration} sh -c '
            echo "Generating network traffic..."
            for i in $(seq 1 100); do
                wget -q -O /dev/null http://httpbin.org/bytes/1024 2>/dev/null &
                if [ $((i % 10)) -eq 0 ]; then wait; fi
            done
            wait
            '"""
            exec_result = self.container.exec_run(net_cmd, detach=False)
            
        except Exception as e:
            self.stop_monitoring()
            return self._create_error_result("Network", str(e))
        
        end_time = time.time()
        self.stop_monitoring()
        
        return self._create_result("Network", end_time - start_time)
    
    def benchmark_comprehensive(self, duration: int = 60) -> BenchmarkResult:
        """Comprehensive benchmark combining all tests"""
        print(f"🚀 Running comprehensive benchmark for {duration}s...")
        
        if not self.start_monitoring():
            return self._create_error_result("Comprehensive", "Failed to start monitoring")
        
        start_time = time.time()
        
        try:
            # Combined workload
            comp_cmd = f"""timeout {duration} sh -c '
            echo "Starting comprehensive workload..."
            
            # CPU load
            (while true; do echo "scale=1000; 4*a(1)" | bc -l > /dev/null 2>&1; done) &
            CPU_PID=$!
            
            # Memory load
            head -c 50M /dev/zero > /tmp/memload &
            MEM_PID=$!
            
            # Disk I/O load
            (for i in $(seq 1 20); do 
                dd if=/dev/urandom of=/tmp/disk$i bs=1M count=5 2>/dev/null
                rm -f /tmp/disk$i
            done) &
            DISK_PID=$!
            
            # Network load
            (for i in $(seq 1 50); do
                wget -q -O /dev/null http://httpbin.org/bytes/512 2>/dev/null &
                if [ $((i % 5)) -eq 0 ]; then wait; fi
            done) &
            NET_PID=$!
            
            # Wait for completion or timeout
            wait $CPU_PID $MEM_PID $DISK_PID $NET_PID 2>/dev/null
            
            # Cleanup
            rm -f /tmp/memload /tmp/disk*
            '"""
            exec_result = self.container.exec_run(comp_cmd, detach=False)
            
        except Exception as e:
            self.stop_monitoring()
            return self._create_error_result("Comprehensive", str(e))
        
        end_time = time.time()
        self.stop_monitoring()
        
        return self._create_result("Comprehensive", end_time - start_time)
    
    def _create_result(self, test_type: str, duration: float) -> BenchmarkResult:
        """Create benchmark result from collected metrics"""
        try:
            # Calculate statistics
            cpu_avg = statistics.mean(self.metrics['cpu_usage']) if self.metrics['cpu_usage'] else 0
            cpu_max = max(self.metrics['cpu_usage']) if self.metrics['cpu_usage'] else 0
            
            mem_avg = statistics.mean(self.metrics['memory_usage']) if self.metrics['memory_usage'] else 0
            mem_max = max(self.metrics['memory_usage']) if self.metrics['memory_usage'] else 0
            
            disk_read = max([d['read'] for d in self.metrics['disk_io']]) if self.metrics['disk_io'] else 0
            disk_write = max([d['write'] for d in self.metrics['disk_io']]) if self.metrics['disk_io'] else 0
            
            net_rx = max([n['rx'] for n in self.metrics['network_io']]) if self.metrics['network_io'] else 0
            net_tx = max([n['tx'] for n in self.metrics['network_io']]) if self.metrics['network_io'] else 0
            
            return BenchmarkResult(
                container_name=self.container_name,
                test_type=test_type,
                duration=duration,
                cpu_usage_avg=round(cpu_avg, 2),
                cpu_usage_max=round(cpu_max, 2),
                memory_usage_avg=int(mem_avg),
                memory_usage_max=int(mem_max),
                disk_io_read=disk_read,
                disk_io_write=disk_write,
                network_io_rx=net_rx,
                network_io_tx=net_tx,
                timestamp=datetime.now().isoformat(),
                status="success"
            )
            
        except Exception as e:
            return self._create_error_result(test_type, f"Result calculation error: {e}")
    
    def _create_error_result(self, test_type: str, error_msg: str) -> BenchmarkResult:
        """Create error result"""
        return BenchmarkResult(
            container_name=self.container_name,
            test_type=test_type,
            duration=0,
            cpu_usage_avg=0,
            cpu_usage_max=0,
            memory_usage_avg=0,
            memory_usage_max=0,
            disk_io_read=0,
            disk_io_write=0,
            network_io_rx=0,
            network_io_tx=0,
            timestamp=datetime.now().isoformat(),
            status="error",
            error_message=error_msg
        )
    
    def run_all_benchmarks(self) -> List[BenchmarkResult]:
        """Run all benchmark types"""
        results = []
        
        print("🎯 Starting comprehensive benchmark suite...")
        
        # Reset metrics for each test
        benchmarks = [
            ("CPU", lambda: self.benchmark_cpu(30)),
            ("Memory", lambda: self.benchmark_memory(30, 100)),
            ("Disk I/O", lambda: self.benchmark_disk_io(30, 50)),
            ("Network", lambda: self.benchmark_network(30)),
            ("Comprehensive", lambda: self.benchmark_comprehensive(60))
        ]
        
        for name, benchmark_func in benchmarks:
            self.metrics = {'cpu_usage': [], 'memory_usage': [], 'disk_io': [], 'network_io': []}
            result = benchmark_func()
            results.append(result)
            
            # Brief pause between tests
            time.sleep(5)
        
        return results
    
    def export_results(self, results: List[BenchmarkResult], filename: str = None):
        """Export results to JSON"""
        if not filename:
            filename = f"benchmark_{self.container_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        results_dict = [asdict(result) for result in results]
        
        with open(filename, 'w') as f:
            json.dump(results_dict, f, indent=2)
        
        print(f"📊 Results exported to {filename}")
        return filename

def print_results(results: List[BenchmarkResult]):
    """Print benchmark results in a formatted table"""
    print("\n" + "="*80)
    print("📊 BENCHMARK RESULTS")
    print("="*80)
    
    for result in results:
        status_icon = "✅" if result.status == "success" else "❌"
        
        print(f"\n{status_icon} {result.test_type} Test")
        print(f"   Duration: {result.duration:.2f}s")
        
        if result.status == "success":
            print(f"   CPU Usage: {result.cpu_usage_avg:.1f}% avg, {result.cpu_usage_max:.1f}% max")
            print(f"   Memory: {result.memory_usage_avg / (1024*1024):.1f}MB avg, {result.memory_usage_max / (1024*1024):.1f}MB max")
            print(f"   Disk I/O: {result.disk_io_read / (1024*1024):.1f}MB read, {result.disk_io_write / (1024*1024):.1f}MB write")
            print(f"   Network: {result.network_io_rx / 1024:.1f}KB rx, {result.network_io_tx / 1024:.1f}KB tx")
        else:
            print(f"   Error: {result.error_message}")
        
        print(f"   Timestamp: {result.timestamp}")

def main():
    """Main function with CLI interface"""
    parser = argparse.ArgumentParser(description="Docker Container Benchmarking Tool")
    parser.add_argument("container", help="Container name or ID")
    parser.add_argument("--test", choices=["cpu", "memory", "disk", "network", "comprehensive", "all"], 
                       default="all", help="Test type to run")
    parser.add_argument("--duration", type=int, default=30, help="Test duration in seconds")
    parser.add_argument("--memory-mb", type=int, default=100, help="Memory test size in MB")
    parser.add_argument("--file-size-mb", type=int, default=100, help="Disk test file size in MB")
    parser.add_argument("--export", action="store_true", help="Export results to JSON")
    parser.add_argument("--output", help="Output filename for JSON export")
    
    args = parser.parse_args()
    
    # Create benchmark instance
    benchmark = ContainerBenchmark(args.container)
    
    # Check if container exists
    if not benchmark.get_container():
        sys.exit(1)
    
    results = []
    
    # Run specific test or all tests
    if args.test == "cpu":
        results.append(benchmark.benchmark_cpu(args.duration))
    elif args.test == "memory":
        results.append(benchmark.benchmark_memory(args.duration, args.memory_mb))
    elif args.test == "disk":
        results.append(benchmark.benchmark_disk_io(args.duration, args.file_size_mb))
    elif args.test == "network":
        results.append(benchmark.benchmark_network(args.duration))
    elif args.test == "comprehensive":
        results.append(benchmark.benchmark_comprehensive(args.duration))
    else:  # all
        results = benchmark.run_all_benchmarks()
    
    # Print results
    print_results(results)
    
    # Export if requested
    if args.export:
        benchmark.export_results(results, args.output)

if __name__ == "__main__":
    main()