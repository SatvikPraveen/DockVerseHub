# Location: utilities/performance/profiling/memory-profiling.py
# Memory profiling tool for Docker containers

import psutil
import time
import json
import argparse
import docker
from datetime import datetime
import sys

class MemoryProfiler:
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
    
    def get_system_memory_stats(self):
        """Get system-wide memory statistics"""
        memory = psutil.virtual_memory()
        swap = psutil.swap_memory()
        
        return {
            'timestamp': datetime.now().isoformat(),
            'type': 'system',
            'memory': {
                'total': memory.total,
                'available': memory.available,
                'used': memory.used,
                'free': memory.free,
                'percent': memory.percent,
                'cached': getattr(memory, 'cached', 0),
                'buffers': getattr(memory, 'buffers', 0)
            },
            'swap': {
                'total': swap.total,
                'used': swap.used,
                'free': swap.free,
                'percent': swap.percent
            }
        }
    
    def get_container_memory_stats(self):
        """Get container memory statistics"""
        if not self.container:
            return None
        
        try:
            stats = self.container.stats(stream=False)
            memory_stats = stats['memory_stats']
            
            usage = memory_stats.get('usage', 0)
            limit = memory_stats.get('limit', 0)
            cache = memory_stats.get('stats', {}).get('cache', 0)
            
            # Calculate memory usage percentage
            if limit > 0:
                percent = (usage / limit) * 100
            else:
                percent = 0
            
            return {
                'timestamp': datetime.now().isoformat(),
                'type': 'container',
                'container_name': self.container_name,
                'memory': {
                    'usage': usage,
                    'limit': limit,
                    'percent': percent,
                    'cache': cache,
                    'rss': memory_stats.get('stats', {}).get('rss', 0),
                    'swap': memory_stats.get('stats', {}).get('swap', 0)
                }
            }
        except Exception as e:
            print(f"Error getting container stats: {e}")
            return None
    
    def get_process_memory_stats(self, pid=None):
        """Get process memory statistics"""
        try:
            if pid:
                process = psutil.Process(pid)
            else:
                process = psutil.Process()
            
            memory_info = process.memory_info()
            memory_percent = process.memory_percent()
            
            return {
                'timestamp': datetime.now().isoformat(),
                'type': 'process',
                'pid': process.pid,
                'name': process.name(),
                'memory': {
                    'rss': memory_info.rss,
                    'vms': memory_info.vms,
                    'percent': memory_percent,
                    'shared': getattr(memory_info, 'shared', 0),
                    'text': getattr(memory_info, 'text', 0),
                    'data': getattr(memory_info, 'data', 0)
                }
            }
        except Exception as e:
            print(f"Error getting process stats: {e}")
            return None
    
    def start_profiling(self, interval=1.0, duration=60, include_processes=False):
        """Start memory profiling"""
        print(f"Starting memory profiling for {duration} seconds...")
        self.running = True
        
        start_time = time.time()
        while self.running and (time.time() - start_time) < duration:
            if self.container_name:
                stats = self.get_container_memory_stats()
            else:
                stats = self.get_system_memory_stats()
            
            if stats:
                self.stats_history.append(stats)
                
                if stats['type'] == 'system':
                    usage_gb = stats['memory']['used'] / (1024**3)
                    total_gb = stats['memory']['total'] / (1024**3)
                    print(f"Memory: {usage_gb:.1f}GB/{total_gb:.1f}GB ({stats['memory']['percent']:.1f}%)")
                else:
                    usage_mb = stats['memory']['usage'] / (1024**2)
                    limit_mb = stats['memory']['limit'] / (1024**2)
                    print(f"Memory: {usage_mb:.1f}MB/{limit_mb:.1f}MB ({stats['memory']['percent']:.1f}%)")
            
            # Include top memory processes if requested
            if include_processes and not self.container_name:
                top_processes = []
                for proc in sorted(psutil.process_iter(['pid', 'name', 'memory_percent']), 
                                 key=lambda x: x.info['memory_percent'] or 0, reverse=True)[:5]:
                    try:
                        top_processes.append({
                            'pid': proc.info['pid'],
                            'name': proc.info['name'],
                            'memory_percent': proc.info['memory_percent'] or 0
                        })
                    except:
                        continue
                
                if 'top_processes' not in stats:
                    stats['top_processes'] = top_processes
            
            time.sleep(interval)
        
        self.running = False
        print("Profiling completed!")
    
    def detect_memory_leaks(self, threshold_percent=10):
        """Detect potential memory leaks"""
        if len(self.stats_history) < 10:
            print("Need more data points to detect memory leaks")
            return []
        
        leaks = []
        memory_values = []
        
        # Extract memory usage values
        for stat in self.stats_history:
            if stat['type'] == 'system':
                memory_values.append(stat['memory']['percent'])
            else:
                memory_values.append(stat['memory']['percent'])
        
        # Simple linear trend analysis
        n = len(memory_values)
        if n < 2:
            return leaks
        
        # Calculate trend (slope)
        x_mean = sum(range(n)) / n
        y_mean = sum(memory_values) / n
        
        numerator = sum((i - x_mean) * (memory_values[i] - y_mean) for i in range(n))
        denominator = sum((i - x_mean) ** 2 for i in range(n))
        
        if denominator != 0:
            slope = numerator / denominator
            
            # If slope is positive and significant, potential memory leak
            if slope > threshold_percent / len(memory_values):
                leaks.append({
                    'type': 'increasing_trend',
                    'slope': slope,
                    'description': f'Memory usage increasing by ~{slope:.2f}% per sample'
                })
        
        return leaks
    
    def save_results(self, filename):
        """Save profiling results to JSON file"""
        with open(filename, 'w') as f:
            json.dump(self.stats_history, f, indent=2)
        print(f"Results saved to {filename}")
    
    def generate_report(self):
        """Generate memory profiling report"""
        if not self.stats_history:
            print("No profiling data available")
            return
        
        memory_values = []
        for stat in self.stats_history:
            if stat['type'] == 'system':
                memory_values.append(stat['memory']['percent'])
            else:
                memory_values.append(stat['memory']['percent'])
        
        if memory_values:
            avg_memory = sum(memory_values) / len(memory_values)
            max_memory = max(memory_values)
            min_memory = min(memory_values)
            
            print(f"\n💾 Memory Profiling Report")
            print(f"==========================")
            print(f"Target: {'System' if not self.container_name else f'Container {self.container_name}'}")
            print(f"Duration: {len(self.stats_history)} samples")
            print(f"Average Memory: {avg_memory:.2f}%")
            print(f"Peak Memory: {max_memory:.2f}%")
            print(f"Minimum Memory: {min_memory:.2f}%")
            
            # Memory leak detection
            leaks = self.detect_memory_leaks()
            if leaks:
                print(f"\n⚠️  Potential Memory Issues:")
                for leak in leaks:
                    print(f"  • {leak['description']}")
            else:
                print(f"\n✅ No memory leaks detected")
            
            # Additional container-specific info
            if self.container_name and self.stats_history:
                last_stat = self.stats_history[-1]
                usage_mb = last_stat['memory']['usage'] / (1024**2)
                limit_mb = last_stat['memory']['limit'] / (1024**2)
                print(f"\nCurrent Usage: {usage_mb:.1f}MB / {limit_mb:.1f}MB")

def main():
    parser = argparse.ArgumentParser(description="Memory profiling tool for Docker containers")
    parser.add_argument("-c", "--container", help="Container name or ID to profile")
    parser.add_argument("-p", "--pid", type=int, help="Process ID to profile")
    parser.add_argument("-d", "--duration", type=int, default=60, help="Profiling duration in seconds")
    parser.add_argument("-i", "--interval", type=float, default=1.0, help="Sampling interval in seconds")
    parser.add_argument("-o", "--output", help="Output JSON file")
    parser.add_argument("--include-processes", action="store_true", help="Include top memory processes")
    parser.add_argument("--leak-threshold", type=float, default=10, help="Memory leak detection threshold")
    
    args = parser.parse_args()
    
    if args.pid:
        # Profile specific process
        profiler = MemoryProfiler()
        try:
            profiler.running = True
            start_time = time.time()
            while (time.time() - start_time) < args.duration:
                stats = profiler.get_process_memory_stats(args.pid)
                if stats:
                    profiler.stats_history.append(stats)
                    print(f"Memory: {stats['memory']['rss']/(1024**2):.1f}MB ({stats['memory']['percent']:.1f}%)")
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print("\nProfiling interrupted by user")
    else:
        # Profile container or system
        profiler = MemoryProfiler(args.container)
        
        try:
            profiler.start_profiling(args.interval, args.duration, args.include_processes)
        except KeyboardInterrupt:
            print("\nProfiling interrupted by user")
            profiler.running = False
    
    profiler.generate_report()
    
    if args.output:
        profiler.save_results(args.output)

if __name__ == "__main__":
    main()