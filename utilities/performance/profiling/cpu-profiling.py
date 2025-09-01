# Location: utilities/performance/profiling/cpu-profiling.py
# CPU profiling tool for Docker containers

import psutil
import time
import json
import argparse
import threading
import docker
from collections import defaultdict
from datetime import datetime
import sys

class CPUProfiler:
    def __init__(self, container_name=None):
        self.container_name = container_name
        self.client = docker.from_env() if container_name else None
        self.container = None
        self.running = False
        self.stats_history = []
        
        if container_name:
            try:
                self.container = self.client.containers.get(container_name)
            except docker.errors.NotFound:
                print(f"Container '{container_name}' not found")
                sys.exit(1)
    
    def get_system_cpu_stats(self):
        """Get system-wide CPU statistics"""
        cpu_percent = psutil.cpu_percent(interval=1)
        cpu_per_core = psutil.cpu_percent(interval=None, percpu=True)
        load_avg = psutil.getloadavg()
        
        return {
            'timestamp': datetime.now().isoformat(),
            'type': 'system',
            'cpu_percent_total': cpu_percent,
            'cpu_percent_per_core': cpu_per_core,
            'load_average': {
                '1min': load_avg[0],
                '5min': load_avg[1],
                '15min': load_avg[2]
            },
            'cpu_count': psutil.cpu_count(logical=True)
        }
    
    def get_container_cpu_stats(self):
        """Get container CPU statistics"""
        if not self.container:
            return None
        
        try:
            stats = self.container.stats(stream=False)
            cpu_stats = stats['cpu_stats']
            precpu_stats = stats['precpu_stats']
            
            cpu_delta = cpu_stats['cpu_usage']['total_usage'] - precpu_stats['cpu_usage']['total_usage']
            system_delta = cpu_stats['system_cpu_usage'] - precpu_stats['system_cpu_usage']
            
            cpu_percent = 0.0
            if system_delta > 0 and cpu_delta > 0:
                cpu_percent = (cpu_delta / system_delta) * len(cpu_stats['cpu_usage']['percpu_usage']) * 100.0
            
            return {
                'timestamp': datetime.now().isoformat(),
                'type': 'container',
                'container_name': self.container_name,
                'cpu_percent': cpu_percent,
                'throttling_periods': cpu_stats.get('throttling_data', {}).get('periods', 0),
                'throttling_throttled_periods': cpu_stats.get('throttling_data', {}).get('throttled_periods', 0)
            }
        except Exception as e:
            print(f"Error getting container stats: {e}")
            return None
    
    def start_profiling(self, interval=1.0, duration=60):
        """Start CPU profiling"""
        print(f"Starting CPU profiling for {duration} seconds...")
        self.running = True
        
        start_time = time.time()
        while self.running and (time.time() - start_time) < duration:
            if self.container_name:
                stats = self.get_container_cpu_stats()
            else:
                stats = self.get_system_cpu_stats()
            
            if stats:
                self.stats_history.append(stats)
                print(f"CPU: {stats.get('cpu_percent_total', stats.get('cpu_percent', 0)):.1f}%")
            
            time.sleep(interval)
        
        self.running = False
        print("Profiling completed!")
    
    def save_results(self, filename):
        """Save profiling results to JSON file"""
        with open(filename, 'w') as f:
            json.dump(self.stats_history, f, indent=2)
        print(f"Results saved to {filename}")
    
    def generate_report(self):
        """Generate profiling report"""
        if not self.stats_history:
            print("No profiling data available")
            return
        
        cpu_values = []
        for stat in self.stats_history:
            if 'cpu_percent_total' in stat:
                cpu_values.append(stat['cpu_percent_total'])
            elif 'cpu_percent' in stat:
                cpu_values.append(stat['cpu_percent'])
        
        if cpu_values:
            avg_cpu = sum(cpu_values) / len(cpu_values)
            max_cpu = max(cpu_values)
            min_cpu = min(cpu_values)
            
            print(f"\n📊 CPU Profiling Report")
            print(f"=======================")
            print(f"Target: {'System' if not self.container_name else f'Container {self.container_name}'}")
            print(f"Duration: {len(self.stats_history)} samples")
            print(f"Average CPU: {avg_cpu:.2f}%")
            print(f"Peak CPU: {max_cpu:.2f}%")
            print(f"Minimum CPU: {min_cpu:.2f}%")
            
            if self.container_name and any('throttling_throttled_periods' in s for s in self.stats_history):
                throttled = sum(s.get('throttling_throttled_periods', 0) for s in self.stats_history)
                print(f"CPU Throttling Events: {throttled}")

def main():
    parser = argparse.ArgumentParser(description="CPU profiling tool for Docker containers")
    parser.add_argument("-c", "--container", help="Container name or ID to profile")
    parser.add_argument("-d", "--duration", type=int, default=60, help="Profiling duration in seconds")
    parser.add_argument("-i", "--interval", type=float, default=1.0, help="Sampling interval in seconds")
    parser.add_argument("-o", "--output", help="Output JSON file")
    parser.add_argument("--report-only", action="store_true", help="Generate report from existing data")
    
    args = parser.parse_args()
    
    profiler = CPUProfiler(args.container)
    
    if not args.report_only:
        try:
            profiler.start_profiling(args.interval, args.duration)
        except KeyboardInterrupt:
            print("\nProfiling interrupted by user")
            profiler.running = False
    
    profiler.generate_report()
    
    if args.output:
        profiler.save_results(args.output)

if __name__ == "__main__":
    main()