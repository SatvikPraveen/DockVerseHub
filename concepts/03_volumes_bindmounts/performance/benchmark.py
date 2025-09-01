#!/usr/bin/env python3
# File Location: concepts/03_volumes_bindmounts/performance/benchmark.py

import os
import time
import json
import subprocess
import tempfile
from pathlib import Path
import statistics
import argparse

class VolumeBenchmark:
    def __init__(self):
        self.results = {}
        self.test_sizes = [1024, 10*1024, 100*1024, 1024*1024]  # 1KB, 10KB, 100KB, 1MB
        self.iterations = 5
        
    def run_docker_command(self, cmd):
        """Run docker command and return output"""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.returncode == 0, result.stdout, result.stderr
        except Exception as e:
            return False, "", str(e)
    
    def create_test_data(self, size):
        """Create test data of specified size"""
        return "x" * size
    
    def benchmark_named_volume(self):
        """Benchmark named volume performance"""
        print("Benchmarking Named Volume...")
        volume_name = "benchmark-volume"
        
        # Create volume
        self.run_docker_command(f"docker volume create {volume_name}")
        
        results = {
            "write_times": [],
            "read_times": [],
            "delete_times": []
        }
        
        for size in self.test_sizes:
            write_times = []
            read_times = []
            delete_times = []
            
            for i in range(self.iterations):
                test_data = self.create_test_data(size)
                
                # Write test
                start_time = time.time()
                cmd = f'''docker run --rm -v {volume_name}:/data alpine:latest sh -c "echo '{test_data}' > /data/test_{size}_{i}.txt"'''
                success, _, _ = self.run_docker_command(cmd)
                if success:
                    write_times.append(time.time() - start_time)
                
                # Read test
                start_time = time.time()
                cmd = f'''docker run --rm -v {volume_name}:/data alpine:latest cat /data/test_{size}_{i}.txt'''
                success, _, _ = self.run_docker_command(cmd)
                if success:
                    read_times.append(time.time() - start_time)
                
                # Delete test
                start_time = time.time()
                cmd = f'''docker run --rm -v {volume_name}:/data alpine:latest rm /data/test_{size}_{i}.txt'''
                success, _, _ = self.run_docker_command(cmd)
                if success:
                    delete_times.append(time.time() - start_time)
            
            if write_times:
                results["write_times"].append({
                    "size": size,
                    "avg_time": statistics.mean(write_times),
                    "min_time": min(write_times),
                    "max_time": max(write_times)
                })
            
            if read_times:
                results["read_times"].append({
                    "size": size,
                    "avg_time": statistics.mean(read_times),
                    "min_time": min(read_times),
                    "max_time": max(read_times)
                })
            
            if delete_times:
                results["delete_times"].append({
                    "size": size,
                    "avg_time": statistics.mean(delete_times),
                    "min_time": min(delete_times),
                    "max_time": max(delete_times)
                })
        
        # Cleanup
        self.run_docker_command(f"docker volume rm {volume_name}")
        
        self.results["named_volume"] = results
        return results
    
    def benchmark_bind_mount(self):
        """Benchmark bind mount performance"""
        print("Benchmarking Bind Mount...")
        
        with tempfile.TemporaryDirectory() as temp_dir:
            results = {
                "write_times": [],
                "read_times": [],
                "delete_times": []
            }
            
            for size in self.test_sizes:
                write_times = []
                read_times = []
                delete_times = []
                
                for i in range(self.iterations):
                    test_data = self.create_test_data(size)
                    
                    # Write test
                    start_time = time.time()
                    cmd = f'''docker run --rm -v {temp_dir}:/data alpine:latest sh -c "echo '{test_data}' > /data/test_{size}_{i}.txt"'''
                    success, _, _ = self.run_docker_command(cmd)
                    if success:
                        write_times.append(time.time() - start_time)
                    
                    # Read test
                    start_time = time.time()
                    cmd = f'''docker run --rm -v {temp_dir}:/data alpine:latest cat /data/test_{size}_{i}.txt'''
                    success, _, _ = self.run_docker_command(cmd)
                    if success:
                        read_times.append(time.time() - start_time)
                    
                    # Delete test
                    start_time = time.time()
                    cmd = f'''docker run --rm -v {temp_dir}:/data alpine:latest rm /data/test_{size}_{i}.txt'''
                    success, _, _ = self.run_docker_command(cmd)
                    if success:
                        delete_times.append(time.time() - start_time)
                
                if write_times:
                    results["write_times"].append({
                        "size": size,
                        "avg_time": statistics.mean(write_times),
                        "min_time": min(write_times),
                        "max_time": max(write_times)
                    })
                
                if read_times:
                    results["read_times"].append({
                        "size": size,
                        "avg_time": statistics.mean(read_times),
                        "min_time": min(read_times),
                        "max_time": max(read_times)
                    })
                
                if delete_times:
                    results["delete_times"].append({
                        "size": size,
                        "avg_time": statistics.mean(delete_times),
                        "min_time": min(delete_times),
                        "max_time": max(delete_times)
                    })
            
            self.results["bind_mount"] = results
            return results
    
    def benchmark_tmpfs(self):
        """Benchmark tmpfs performance"""
        print("Benchmarking tmpfs...")
        
        results = {
            "write_times": [],
            "read_times": [],
            "delete_times": []
        }
        
        for size in self.test_sizes:
            write_times = []
            read_times = []
            delete_times = []
            
            for i in range(self.iterations):
                test_data = self.create_test_data(size)
                
                # Write test
                start_time = time.time()
                cmd = f'''docker run --rm --tmpfs /data alpine:latest sh -c "echo '{test_data}' > /data/test_{size}_{i}.txt"'''
                success, _, _ = self.run_docker_command(cmd)
                if success:
                    write_times.append(time.time() - start_time)
                
                # Read test
                start_time = time.time()
                cmd = f'''docker run --rm --tmpfs /data alpine:latest sh -c "echo '{test_data}' > /data/test_{size}_{i}.txt && cat /data/test_{size}_{i}.txt"'''
                success, _, _ = self.run_docker_command(cmd)
                if success:
                    read_times.append(time.time() - start_time)
                
                # Delete test (implicit with container removal for tmpfs)
                delete_times.append(0.001)  # Minimal time for tmpfs
            
            if write_times:
                results["write_times"].append({
                    "size": size,
                    "avg_time": statistics.mean(write_times),
                    "min_time": min(write_times),
                    "max_time": max(write_times)
                })
            
            if read_times:
                results["read_times"].append({
                    "size": size,
                    "avg_time": statistics.mean(read_times),
                    "min_time": min(read_times),
                    "max_time": max(read_times)
                })
            
            results["delete_times"].append({
                "size": size,
                "avg_time": statistics.mean(delete_times),
                "min_time": min(delete_times),
                "max_time": max(delete_times)
            })
        
        self.results["tmpfs"] = results
        return results
    
    def format_size(self, size):
        """Format size in human readable format"""
        if size >= 1024*1024:
            return f"{size/(1024*1024):.1f}MB"
        elif size >= 1024:
            return f"{size/1024:.1f}KB"
        else:
            return f"{size}B"
    
    def print_results(self):
        """Print benchmark results"""
        print("\n" + "="*80)
        print("DOCKER VOLUME PERFORMANCE BENCHMARK RESULTS")
        print("="*80)
        
        for storage_type, data in self.results.items():
            print(f"\n{storage_type.upper()} RESULTS:")
            print("-" * 50)
            
            for operation in ["write_times", "read_times", "delete_times"]:
                if operation in data and data[operation]:
                    print(f"\n{operation.replace('_', ' ').title()}:")
                    print("Size\t\tAvg Time\tMin Time\tMax Time")
                    for result in data[operation]:
                        size_str = self.format_size(result["size"])
                        print(f"{size_str}\t\t{result['avg_time']:.4f}s\t\t{result['min_time']:.4f}s\t\t{result['max_time']:.4f}s")
    
    def save_results(self, filename="benchmark_results.json"):
        """Save results to JSON file"""
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"\nResults saved to {filename}")
    
    def run_all_benchmarks(self):
        """Run all benchmark tests"""
        print("Starting Docker Volume Performance Benchmark...")
        print(f"Test configuration: {len(self.test_sizes)} sizes, {self.iterations} iterations each")
        
        try:
            self.benchmark_named_volume()
            self.benchmark_bind_mount()
            self.benchmark_tmpfs()
            
            self.print_results()
            self.save_results()
            
        except KeyboardInterrupt:
            print("\nBenchmark interrupted by user")
        except Exception as e:
            print(f"Error during benchmark: {e}")

def main():
    parser = argparse.ArgumentParser(description="Docker Volume Performance Benchmark")
    parser.add_argument("--iterations", type=int, default=5, help="Number of iterations per test")
    parser.add_argument("--output", type=str, default="benchmark_results.json", help="Output file for results")
    
    args = parser.parse_args()
    
    benchmark = VolumeBenchmark()
    benchmark.iterations = args.iterations
    
    benchmark.run_all_benchmarks()
    if args.output != "benchmark_results.json":
        benchmark.save_results(args.output)

if __name__ == "__main__":
    main()