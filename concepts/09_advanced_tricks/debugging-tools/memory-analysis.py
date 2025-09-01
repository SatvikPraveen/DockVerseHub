# 09_advanced_tricks/debugging-tools/memory-analysis.py

"""
Container Memory Analysis Tool
Advanced memory profiling, leak detection, and optimization recommendations
"""

import subprocess
import json
import sys
import argparse
import time
import os
import re
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from datetime import datetime
import threading
import psutil

@dataclass
class MemorySnapshot:
    timestamp: datetime
    total_memory: int
    used_memory: int
    free_memory: int
    cached_memory: int
    buffers: int
    swap_total: int
    swap_used: int
    processes: List[Dict[str, Any]]

@dataclass
class ProcessMemInfo:
    pid: int
    name: str
    memory_percent: float
    memory_rss: int
    memory_vms: int
    memory_shared: int
    memory_data: int
    memory_lib: int
    memory_dirty: int

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'

class ContainerMemoryAnalyzer:
    def __init__(self, container_id: str, verbose: bool = False):
        self.container_id = container_id
        self.verbose = verbose
        self.snapshots: List[MemorySnapshot] = []
        self.monitoring_active = False
        
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
    
    def docker_exec(self, command: List[str]) -> Tuple[bool, str]:
        """Execute command inside container"""
        cmd = ['docker', 'exec', self.container_id] + command
        return self.run_command(cmd)
    
    def get_container_stats(self) -> Optional[Dict]:
        """Get Docker container statistics"""
        success, output = self.run_command(['docker', 'stats', self.container_id, '--no-stream', '--format', 'json'])
        if success:
            try:
                return json.loads(output)
            except json.JSONDecodeError:
                return None
        return None
    
    def get_memory_info(self) -> Optional[Dict]:
        """Get detailed memory information from inside container"""
        success, output = self.docker_exec(['cat', '/proc/meminfo'])
        if not success:
            return None
        
        mem_info = {}
        for line in output.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                value = value.strip().replace(' kB', '').replace(' kb', '')
                try:
                    mem_info[key.strip()] = int(value) * 1024  # Convert to bytes
                except ValueError:
                    mem_info[key.strip()] = value
        
        return mem_info
    
    def get_process_memory(self) -> List[ProcessMemInfo]:
        """Get memory information for all processes in container"""
        success, output = self.docker_exec(['ps', 'aux', '--sort=-%mem'])
        if not success:
            return []
        
        processes = []
        lines = output.split('\n')[1:]  # Skip header
        
        for line in lines[:20]:  # Top 20 processes
            parts = line.split(None, 10)
            if len(parts) >= 11:
                try:
                    # Get detailed memory info for process
                    pid = int(parts[1])
                    success_stat, stat_output = self.docker_exec(['cat', f'/proc/{pid}/status'])
                    
                    memory_data = {
                        'pid': pid,
                        'name': parts[10].split()[0],
                        'memory_percent': float(parts[3]),
                        'memory_rss': 0,
                        'memory_vms': 0,
                        'memory_shared': 0,
                        'memory_data': 0,
                        'memory_lib': 0,
                        'memory_dirty': 0
                    }
                    
                    if success_stat:
                        for stat_line in stat_output.split('\n'):
                            if 'VmRSS:' in stat_line:
                                memory_data['memory_rss'] = int(stat_line.split()[1]) * 1024
                            elif 'VmSize:' in stat_line:
                                memory_data['memory_vms'] = int(stat_line.split()[1]) * 1024
                            elif 'VmData:' in stat_line:
                                memory_data['memory_data'] = int(stat_line.split()[1]) * 1024
                            elif 'VmLib:' in stat_line:
                                memory_data['memory_lib'] = int(stat_line.split()[1]) * 1024
                    
                    processes.append(ProcessMemInfo(**memory_data))
                    
                except (ValueError, IndexError):
                    continue
        
        return processes
    
    def take_memory_snapshot(self) -> Optional[MemorySnapshot]:
        """Take a snapshot of current memory usage"""
        mem_info = self.get_memory_info()
        if not mem_info:
            return None
        
        processes = self.get_process_memory()
        process_data = [
            {
                'pid': p.pid,
                'name': p.name,
                'memory_percent': p.memory_percent,
                'memory_rss': p.memory_rss,
                'memory_vms': p.memory_vms
            }
            for p in processes
        ]
        
        snapshot = MemorySnapshot(
            timestamp=datetime.now(),
            total_memory=mem_info.get('MemTotal', 0),
            used_memory=mem_info.get('MemTotal', 0) - mem_info.get('MemFree', 0) - mem_info.get('Buffers', 0) - mem_info.get('Cached', 0),
            free_memory=mem_info.get('MemFree', 0),
            cached_memory=mem_info.get('Cached', 0),
            buffers=mem_info.get('Buffers', 0),
            swap_total=mem_info.get('SwapTotal', 0),
            swap_used=mem_info.get('SwapTotal', 0) - mem_info.get('SwapFree', 0),
            processes=process_data
        )
        
        self.snapshots.append(snapshot)
        return snapshot
    
    def analyze_current_memory(self):
        """Analyze current memory usage"""
        self.print_header("CURRENT MEMORY ANALYSIS")
        
        # Get Docker stats
        stats = self.get_container_stats()
        if stats:
            print(f"{Colors.WHITE}Docker Container Stats:{Colors.NC}")
            print(f"Memory Usage: {stats.get('MemUsage', 'N/A')}")
            print(f"Memory Percentage: {stats.get('MemPerc', 'N/A')}")
            print(f"Memory Limit: {stats.get('MemLimit', 'N/A')}")
        
        # Get detailed memory info
        mem_info = self.get_memory_info()
        if mem_info:
            print(f"\n{Colors.CYAN}Detailed Memory Information:{Colors.NC}")
            total_mb = mem_info.get('MemTotal', 0) / 1024 / 1024
            free_mb = mem_info.get('MemFree', 0) / 1024 / 1024
            cached_mb = mem_info.get('Cached', 0) / 1024 / 1024
            buffers_mb = mem_info.get('Buffers', 0) / 1024 / 1024
            used_mb = total_mb - free_mb - cached_mb - buffers_mb
            
            print(f"Total Memory: {total_mb:.1f} MB")
            print(f"Used Memory: {used_mb:.1f} MB ({used_mb/total_mb*100:.1f}%)")
            print(f"Free Memory: {free_mb:.1f} MB")
            print(f"Cached: {cached_mb:.1f} MB")
            print(f"Buffers: {buffers_mb:.1f} MB")
            
            if mem_info.get('SwapTotal', 0) > 0:
                swap_total_mb = mem_info.get('SwapTotal', 0) / 1024 / 1024
                swap_free_mb = mem_info.get('SwapFree', 0) / 1024 / 1024
                swap_used_mb = swap_total_mb - swap_free_mb
                print(f"Swap Total: {swap_total_mb:.1f} MB")
                print(f"Swap Used: {swap_used_mb:.1f} MB ({swap_used_mb/swap_total_mb*100:.1f}%)")
        
        # Get top memory consumers
        print(f"\n{Colors.CYAN}Top Memory Consuming Processes:{Colors.NC}")
        processes = self.get_process_memory()
        
        print(f"{'PID':<8} {'Name':<20} {'%MEM':<8} {'RSS (MB)':<10} {'VMS (MB)':<10}")
        print("-" * 65)
        
        for proc in processes[:10]:
            rss_mb = proc.memory_rss / 1024 / 1024
            vms_mb = proc.memory_vms / 1024 / 1024
            print(f"{proc.pid:<8} {proc.name[:20]:<20} {proc.memory_percent:<8.1f} {rss_mb:<10.1f} {vms_mb:<10.1f}")
    
    def monitor_memory_usage(self, duration: int, interval: int = 5):
        """Monitor memory usage over time"""
        self.print_header(f"MEMORY MONITORING ({duration}s)")
        
        self.monitoring_active = True
        start_time = time.time()
        end_time = start_time + duration
        
        print(f"{'Timestamp':<20} {'Used (MB)':<12} {'Used %':<8} {'Free (MB)':<12} {'Cached (MB)':<12}")
        print("-" * 70)
        
        while time.time() < end_time and self.monitoring_active:
            snapshot = self.take_memory_snapshot()
            if snapshot:
                used_mb = snapshot.used_memory / 1024 / 1024
                total_mb = snapshot.total_memory / 1024 / 1024
                free_mb = snapshot.free_memory / 1024 / 1024
                cached_mb = snapshot.cached_memory / 1024 / 1024
                used_percent = (used_mb / total_mb) * 100 if total_mb > 0 else 0
                
                timestamp_str = snapshot.timestamp.strftime("%H:%M:%S")
                print(f"{timestamp_str:<20} {used_mb:<12.1f} {used_percent:<8.1f} {free_mb:<12.1f} {cached_mb:<12.1f}")
            
            time.sleep(interval)
        
        self.monitoring_active = False
        self.log_info(f"Collected {len(self.snapshots)} memory snapshots")
    
    def detect_memory_leaks(self):
        """Detect potential memory leaks"""
        self.print_header("MEMORY LEAK DETECTION")
        
        if len(self.snapshots) < 3:
            self.log_warn("Need at least 3 snapshots for leak detection")
            return
        
        # Analyze memory trends
        memory_usage_trend = []
        for snapshot in self.snapshots:
            used_mb = snapshot.used_memory / 1024 / 1024
            memory_usage_trend.append(used_mb)
        
        # Calculate trend
        n = len(memory_usage_trend)
        if n > 1:
            # Simple linear trend calculation
            x_sum = sum(range(n))
            y_sum = sum(memory_usage_trend)
            xy_sum = sum(i * memory_usage_trend[i] for i in range(n))
            x2_sum = sum(i * i for i in range(n))
            
            slope = (n * xy_sum - x_sum * y_sum) / (n * x2_sum - x_sum * x_sum)
            
            print(f"{Colors.CYAN}Memory Usage Trend Analysis:{Colors.NC}")
            print(f"Slope: {slope:.2f} MB per interval")
            
            if slope > 1.0:
                self.log_warn("⚠️ Potential memory leak detected! Memory usage is increasing")
                print(f"Memory increased by {slope:.2f} MB per monitoring interval")
            elif slope < -1.0:
                self.log_info("✅ Memory usage is decreasing (good)")
            else:
                self.log_info("✅ Memory usage appears stable")
        
        # Analyze per-process trends
        print(f"\n{Colors.CYAN}Process Memory Trend Analysis:{Colors.NC}")
        process_trends = {}
        
        for snapshot in self.snapshots:
            for proc in snapshot.processes:
                proc_name = proc['name']
                if proc_name not in process_trends:
                    process_trends[proc_name] = []
                process_trends[proc_name].append(proc['memory_rss'])
        
        for proc_name, memory_values in process_trends.items():
            if len(memory_values) >= 3:
                first_val = memory_values[0] / 1024 / 1024
                last_val = memory_values[-1] / 1024 / 1024
                change = last_val - first_val
                
                if change > 10:  # More than 10MB increase
                    print(f"⚠️ {proc_name}: +{change:.1f} MB (potential leak)")
                elif change < -10:
                    print(f"✅ {proc_name}: {change:.1f} MB (memory freed)")
                else:
                    print(f"✅ {proc_name}: {change:+.1f} MB (stable)")
    
    def analyze_memory_fragmentation(self):
        """Analyze memory fragmentation"""
        self.print_header("MEMORY FRAGMENTATION ANALYSIS")
        
        # Check /proc/buddyinfo for fragmentation
        success, buddy_info = self.docker_exec(['cat', '/proc/buddyinfo'])
        if success:
            print(f"{Colors.CYAN}Memory Fragmentation (Buddy System):{Colors.NC}")
            print(buddy_info)
            
            # Analyze fragmentation levels
            lines = buddy_info.split('\n')
            for line in lines:
                if 'Node' in line:
                    parts = line.split()
                    if len(parts) > 4:
                        # Check higher order allocations
                        higher_orders = [int(x) for x in parts[4:]]
                        if sum(higher_orders[-3:]) < 10:  # Few large blocks available
                            self.log_warn("High memory fragmentation detected")
                        else:
                            self.log_info("Memory fragmentation looks reasonable")
        
        # Check /proc/pagetypeinfo
        success, page_info = self.docker_exec(['cat', '/proc/pagetypeinfo'])
        if success:
            print(f"\n{Colors.CYAN}Page Type Information:{Colors.NC}")
            # Show summary of page types
            lines = page_info.split('\n')[:10]  # First 10 lines
            for line in lines:
                if line.strip():
                    print(line)
    
    def generate_memory_recommendations(self):
        """Generate memory optimization recommendations"""
        self.print_header("MEMORY OPTIMIZATION RECOMMENDATIONS")
        
        if not self.snapshots:
            self.log_warn("No memory snapshots available for analysis")
            return
        
        latest_snapshot = self.snapshots[-1]
        total_mb = latest_snapshot.total_memory / 1024 / 1024
        used_mb = latest_snapshot.used_memory / 1024 / 1024
        used_percent = (used_mb / total_mb) * 100 if total_mb > 0 else 0
        
        recommendations = []
        
        # Memory usage analysis
        if used_percent > 90:
            recommendations.append("🔴 Critical: Memory usage > 90% - immediate action required")
            recommendations.append("   - Consider increasing container memory limits")
            recommendations.append("   - Review memory-intensive processes")
        elif used_percent > 80:
            recommendations.append("🟡 Warning: Memory usage > 80% - monitor closely")
            recommendations.append("   - Consider optimizing memory usage")
        else:
            recommendations.append("🟢 Memory usage is within acceptable limits")
        
        # Swap analysis
        if latest_snapshot.swap_used > 0:
            swap_percent = (latest_snapshot.swap_used / latest_snapshot.swap_total) * 100
            if swap_percent > 50:
                recommendations.append("🔴 High swap usage detected - performance may be impacted")
                recommendations.append("   - Consider increasing physical memory")
        
        # Process analysis
        top_process = max(latest_snapshot.processes, key=lambda p: p['memory_rss'], default=None)
        if top_process and top_process['memory_percent'] > 50:
            recommendations.append(f"⚠️ Process '{top_process['name']}' using {top_process['memory_percent']:.1f}% of memory")
            recommendations.append("   - Investigate if this is expected behavior")
        
        # Memory leak detection
        if len(self.snapshots) > 2:
            first_used = self.snapshots[0].used_memory / 1024 / 1024
            last_used = self.snapshots[-1].used_memory / 1024 / 1024
            if last_used > first_used + 50:  # 50MB increase
                recommendations.append("🔴 Possible memory leak detected")
                recommendations.append("   - Monitor memory usage over longer period")
                recommendations.append("   - Review application for memory leaks")
        
        # Print recommendations
        for recommendation in recommendations:
            print(recommendation)
        
        if not recommendations:
            print("✅ No specific recommendations - memory usage appears healthy")
    
    def export_analysis(self, output_file: str):
        """Export memory analysis to file"""
        self.print_header("EXPORTING MEMORY ANALYSIS")
        
        analysis_data = {
            'container_id': self.container_id,
            'analysis_time': datetime.now().isoformat(),
            'snapshots_count': len(self.snapshots),
            'snapshots': []
        }
        
        for snapshot in self.snapshots:
            snapshot_data = {
                'timestamp': snapshot.timestamp.isoformat(),
                'total_memory_mb': snapshot.total_memory / 1024 / 1024,
                'used_memory_mb': snapshot.used_memory / 1024 / 1024,
                'free_memory_mb': snapshot.free_memory / 1024 / 1024,
                'cached_memory_mb': snapshot.cached_memory / 1024 / 1024,
                'swap_used_mb': snapshot.swap_used / 1024 / 1024,
                'top_processes': snapshot.processes[:5]
            }
            analysis_data['snapshots'].append(snapshot_data)
        
        try:
            with open(output_file, 'w') as f:
                json.dump(analysis_data, f, indent=2)
            self.log_info(f"Memory analysis exported to {output_file}")
        except Exception as e:
            self.log_error(f"Failed to export analysis: {e}")

def main():
    parser = argparse.ArgumentParser(description='Container Memory Analysis Tool')
    parser.add_argument('container', help='Container ID or name to analyze')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('-c', '--current', action='store_true', help='Analyze current memory usage')
    parser.add_argument('-m', '--monitor', type=int, metavar='DURATION', help='Monitor memory for specified duration (seconds)')
    parser.add_argument('-i', '--interval', type=int, default=5, help='Monitoring interval in seconds (default: 5)')
    parser.add_argument('-l', '--leak-detection', action='store_true', help='Run memory leak detection')
    parser.add_argument('-f', '--fragmentation', action='store_true', help='Analyze memory fragmentation')
    parser.add_argument('-r', '--recommendations', action='store_true', help='Generate optimization recommendations')
    parser.add_argument('-o', '--output', help='Export analysis to JSON file')
    parser.add_argument('-a', '--all', action='store_true', help='Run all analysis types')
    
    args = parser.parse_args()
    
    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)
    
    analyzer = ContainerMemoryAnalyzer(args.container, args.verbose)
    
    try:
        # Check if container exists and is running
        success, _ = analyzer.run_command(['docker', 'inspect', args.container])
        if not success:
            analyzer.log_error(f"Container '{args.container}' not found")
            sys.exit(1)
        
        if args.all:
            args.current = True
            args.monitor = args.monitor or 60
            args.leak_detection = True
            args.fragmentation = True
            args.recommendations = True
        
        if args.current:
            analyzer.analyze_current_memory()
        
        if args.monitor:
            analyzer.monitor_memory_usage(args.monitor, args.interval)
        
        if args.leak_detection:
            analyzer.detect_memory_leaks()
        
        if args.fragmentation:
            analyzer.analyze_memory_fragmentation()
        
        if args.recommendations:
            analyzer.generate_memory_recommendations()
        
        if args.output:
            analyzer.export_analysis(args.output)
        
        if not any([args.current, args.monitor, args.leak_detection, args.fragmentation, args.recommendations]):
            # Default behavior - show current memory usage
            analyzer.analyze_current_memory()
    
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Analysis interrupted by user{Colors.NC}")
        analyzer.monitoring_active = False
        sys.exit(0)
    except Exception as e:
        analyzer.log_error(f"Analysis failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()