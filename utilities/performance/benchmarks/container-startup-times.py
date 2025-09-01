# Location: utilities/performance/benchmarks/container-startup-times.py
# Container startup time benchmarking tool

import docker
import time
import statistics
import json
import argparse
import sys
from typing import Dict, List
import matplotlib.pyplot as plt
import pandas as pd
from datetime import datetime

class StartupBenchmark:
    def __init__(self):
        self.client = docker.from_env()
        self.results = {}
        
    def benchmark_image(self, image: str, iterations: int = 10, command: str = None) -> Dict:
        """Benchmark startup time for a specific image"""
        print(f"Benchmarking {image} ({iterations} iterations)...")
        
        startup_times = []
        ready_times = []
        
        for i in range(iterations):
            print(f"  Iteration {i+1}/{iterations}")
            
            # Record start time
            start_time = time.time()
            
            try:
                # Start container
                container = self.client.containers.run(
                    image,
                    command=command or "sleep 30",
                    detach=True,
                    remove=True
                )
                
                # Wait for container to be running
                while container.status != 'running':
                    container.reload()
                    time.sleep(0.01)
                
                startup_time = time.time() - start_time
                startup_times.append(startup_time)
                
                # Check if container has health check
                container_info = self.client.api.inspect_container(container.id)
                if container_info.get('State', {}).get('Health'):
                    # Wait for healthy status
                    health_start = time.time()
                    while True:
                        container.reload()
                        health = container.attrs.get('State', {}).get('Health', {})
                        if health.get('Status') == 'healthy':
                            ready_time = time.time() - start_time
                            ready_times.append(ready_time)
                            break
                        elif health.get('Status') == 'unhealthy':
                            ready_times.append(float('inf'))
                            break
                        time.sleep(0.1)
                        if time.time() - health_start > 60:  # Timeout
                            ready_times.append(float('inf'))
                            break
                else:
                    ready_times.append(startup_time)
                
                # Stop container
                container.stop(timeout=1)
                
            except Exception as e:
                print(f"    Error: {e}")
                startup_times.append(float('inf'))
                ready_times.append(float('inf'))
            
            time.sleep(0.5)  # Brief pause between iterations
        
        # Calculate statistics
        valid_startup = [t for t in startup_times if t != float('inf')]
        valid_ready = [t for t in ready_times if t != float('inf')]
        
        if not valid_startup:
            return {"error": "All benchmark iterations failed"}
        
        return {
            "image": image,
            "iterations": iterations,
            "startup_times": startup_times,
            "ready_times": ready_times,
            "startup_stats": {
                "mean": statistics.mean(valid_startup),
                "median": statistics.median(valid_startup),
                "min": min(valid_startup),
                "max": max(valid_startup),
                "stdev": statistics.stdev(valid_startup) if len(valid_startup) > 1 else 0
            },
            "ready_stats": {
                "mean": statistics.mean(valid_ready) if valid_ready else 0,
                "median": statistics.median(valid_ready) if valid_ready else 0,
                "min": min(valid_ready) if valid_ready else 0,
                "max": max(valid_ready) if valid_ready else 0,
                "stdev": statistics.stdev(valid_ready) if len(valid_ready) > 1 else 0
            },
            "success_rate": len(valid_startup) / iterations * 100
        }
    
    def benchmark_multiple_images(self, images: List[str], iterations: int = 10) -> Dict:
        """Benchmark multiple images"""
        results = {
            "timestamp": datetime.now().isoformat(),
            "iterations_per_image": iterations,
            "images": {}
        }
        
        for image in images:
            try:
                # Pull image if not exists
                print(f"Pulling {image}...")
                self.client.images.pull(image)
                
                result = self.benchmark_image(image, iterations)
                results["images"][image] = result
                
            except Exception as e:
                print(f"Failed to benchmark {image}: {e}")
                results["images"][image] = {"error": str(e)}
        
        return results
    
    def compare_base_images(self) -> Dict:
        """Compare common base images startup times"""
        base_images = [
            "alpine:latest",
            "alpine:3.19",
            "ubuntu:22.04",
            "debian:12-slim",
            "python:3.11-alpine",
            "python:3.11-slim",
            "node:18-alpine",
            "node:18-slim",
            "nginx:alpine",
            "redis:alpine"
        ]
        
        return self.benchmark_multiple_images(base_images)
    
    def generate_report(self, results: Dict, format_type: str = "text") -> str:
        """Generate benchmark report"""
        if format_type == "json":
            return json.dumps(results, indent=2)
        
        elif format_type == "csv":
            data = []
            for image, result in results.get("images", {}).items():
                if "error" not in result:
                    data.append({
                        "image": image,
                        "mean_startup": result["startup_stats"]["mean"],
                        "median_startup": result["startup_stats"]["median"],
                        "min_startup": result["startup_stats"]["min"],
                        "max_startup": result["startup_stats"]["max"],
                        "success_rate": result["success_rate"]
                    })
            
            df = pd.DataFrame(data)
            return df.to_csv(index=False)
        
        else:  # text format
            report = []
            report.append("🚀 Container Startup Time Benchmark Report")
            report.append("=" * 50)
            report.append(f"Timestamp: {results.get('timestamp', 'N/A')}")
            report.append(f"Iterations per image: {results.get('iterations_per_image', 'N/A')}")
            report.append("")
            
            # Sort by mean startup time
            image_results = []
            for image, result in results.get("images", {}).items():
                if "error" not in result:
                    image_results.append((image, result))
            
            image_results.sort(key=lambda x: x[1]["startup_stats"]["mean"])
            
            for image, result in image_results:
                report.append(f"📦 {image}")
                report.append("-" * 30)
                stats = result["startup_stats"]
                report.append(f"  Mean startup time: {stats['mean']:.3f}s")
                report.append(f"  Median startup time: {stats['median']:.3f}s")
                report.append(f"  Min/Max: {stats['min']:.3f}s / {stats['max']:.3f}s")
                report.append(f"  Standard deviation: {stats['stdev']:.3f}s")
                report.append(f"  Success rate: {result['success_rate']:.1f}%")
                report.append("")
            
            # Summary
            if image_results:
                fastest = image_results[0]
                slowest = image_results[-1]
                report.append("📊 Summary")
                report.append("-" * 20)
                report.append(f"Fastest: {fastest[0]} ({fastest[1]['startup_stats']['mean']:.3f}s)")
                report.append(f"Slowest: {slowest[0]} ({slowest[1]['startup_stats']['mean']:.3f}s)")
                
                speedup = slowest[1]['startup_stats']['mean'] / fastest[1]['startup_stats']['mean']
                report.append(f"Speed difference: {speedup:.2f}x")
            
            return "\n".join(report)
    
    def plot_results(self, results: Dict, output_file: str = "startup_benchmark.png"):
        """Generate visualization of results"""
        image_names = []
        startup_times = []
        
        for image, result in results.get("images", {}).items():
            if "error" not in result:
                image_names.append(image.replace(":", "\n"))
                startup_times.append(result["startup_stats"]["mean"])
        
        if not image_names:
            print("No data to plot")
            return
        
        plt.figure(figsize=(12, 8))
        bars = plt.bar(image_names, startup_times, color='skyblue', edgecolor='navy')
        
        # Add value labels on bars
        for bar, time_val in zip(bars, startup_times):
            plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                    f'{time_val:.3f}s', ha='center', va='bottom')
        
        plt.title('Container Startup Time Comparison', fontsize=16, fontweight='bold')
        plt.xlabel('Docker Images', fontsize=12)
        plt.ylabel('Startup Time (seconds)', fontsize=12)
        plt.xticks(rotation=45, ha='right')
        plt.grid(axis='y', alpha=0.3)
        plt.tight_layout()
        
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Chart saved to {output_file}")

def main():
    parser = argparse.ArgumentParser(description="Container startup time benchmarking")
    parser.add_argument("images", nargs="*", help="Images to benchmark")
    parser.add_argument("-i", "--iterations", type=int, default=10, help="Iterations per image")
    parser.add_argument("-f", "--format", choices=["text", "json", "csv"], default="text", help="Output format")
    parser.add_argument("-o", "--output", help="Output file")
    parser.add_argument("--plot", help="Generate plot (PNG file)")
    parser.add_argument("--base-images", action="store_true", help="Benchmark common base images")
    parser.add_argument("--command", help="Custom command to run in container")
    
    args = parser.parse_args()
    
    benchmark = StartupBenchmark()
    
    try:
        if args.base_images:
            results = benchmark.compare_base_images()
        elif args.images:
            results = benchmark.benchmark_multiple_images(args.images, args.iterations)
        else:
            print("No images specified. Use --base-images or provide image names.")
            sys.exit(1)
        
        # Generate report
        report = benchmark.generate_report(results, args.format)
        
        if args.output:
            with open(args.output, 'w') as f:
                f.write(report)
            print(f"Report saved to {args.output}")
        else:
            print(report)
        
        # Generate plot if requested
        if args.plot:
            benchmark.plot_results(results, args.plot)
        
    except KeyboardInterrupt:
        print("\nBenchmark interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Benchmark failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()