# Location: utilities/performance/benchmarks/image-build-performance.py
# Docker image build performance analyzer

import docker
import time
import json
import os
import subprocess
import argparse
from pathlib import Path
from typing import Dict, List, Tuple
import tempfile
import shutil
from datetime import datetime

class BuildPerformanceAnalyzer:
    def __init__(self):
        self.client = docker.from_env()
        self.build_results = []
        
    def analyze_dockerfile(self, dockerfile_path: str) -> Dict:
        """Analyze Dockerfile for build optimization opportunities"""
        optimizations = []
        layer_count = 0
        
        try:
            with open(dockerfile_path, 'r') as f:
                lines = f.readlines()
        except Exception as e:
            return {"error": f"Cannot read Dockerfile: {e}"}
        
        run_commands = 0
        copy_commands = 0
        
        for i, line in enumerate(lines, 1):
            line = line.strip().upper()
            
            if line.startswith('RUN'):
                run_commands += 1
                layer_count += 1
                
                # Check for multiple RUN commands that could be combined
                if run_commands > 3:
                    optimizations.append({
                        "line": i,
                        "type": "layer_optimization",
                        "message": "Consider combining RUN commands to reduce layers"
                    })
                
                # Check for package manager cleanup
                if any(pm in line for pm in ['APT-GET INSTALL', 'YUM INSTALL', 'APKINSTALL']) and 'RM -RF' not in line:
                    optimizations.append({
                        "line": i,
                        "type": "size_optimization", 
                        "message": "Missing package cache cleanup"
                    })
            
            elif line.startswith(('COPY', 'ADD')):
                copy_commands += 1
                layer_count += 1
                
                # Check for copying entire context
                if '. .' in line or './ ./' in line:
                    optimizations.append({
                        "line": i,
                        "type": "build_context",
                        "message": "Copying entire build context - consider .dockerignore"
                    })
            
            elif line.startswith(('FROM', 'WORKDIR', 'USER', 'EXPOSE', 'ENV', 'CMD', 'ENTRYPOINT')):
                if line.startswith(('ENV', 'EXPOSE')):
                    layer_count += 1
        
        return {
            "total_lines": len(lines),
            "estimated_layers": layer_count,
            "run_commands": run_commands,
            "copy_commands": copy_commands,
            "optimizations": optimizations,
            "optimization_score": max(0, 100 - len(optimizations) * 10)
        }
    
    def benchmark_build(self, dockerfile_path: str, context_path: str = None, 
                       iterations: int = 3, use_cache: bool = True) -> Dict:
        """Benchmark Docker build performance"""
        print(f"Benchmarking build for {dockerfile_path}...")
        
        if context_path is None:
            context_path = os.path.dirname(dockerfile_path) or "."
        
        build_times = []
        build_sizes = []
        cache_usage = []
        
        # Get initial cache state
        initial_images = len(self.client.images.list())
        
        for i in range(iterations):
            print(f"  Build iteration {i+1}/{iterations}")
            
            # Clear build cache if no-cache build
            if not use_cache:
                try:
                    self.client.api.prune_builds()
                except:
                    pass
            
            start_time = time.time()
            
            try:
                # Build image with logging
                build_log = []
                image, build_logs = self.client.images.build(
                    path=context_path,
                    dockerfile=os.path.basename(dockerfile_path),
                    rm=True,
                    nocache=not use_cache,
                    tag=f"benchmark-test-{i}:latest"
                )
                
                build_time = time.time() - start_time
                build_times.append(build_time)
                
                # Get image size
                image_size = image.attrs.get('Size', 0)
                build_sizes.append(image_size)
                
                # Analyze cache usage from logs
                cached_steps = 0
                total_steps = 0
                
                for log_entry in build_logs:
                    if 'stream' in log_entry:
                        log_line = log_entry['stream'].strip()
                        build_log.append(log_line)
                        
                        if 'Step' in log_line and '/' in log_line:
                            total_steps += 1
                        elif 'Using cache' in log_line:
                            cached_steps += 1
                
                cache_hit_rate = (cached_steps / total_steps * 100) if total_steps > 0 else 0
                cache_usage.append(cache_hit_rate)
                
                # Clean up test image
                try:
                    self.client.images.remove(image.id, force=True)
                except:
                    pass
                
            except Exception as e:
                print(f"    Build failed: {e}")
                build_times.append(float('inf'))
                build_sizes.append(0)
                cache_usage.append(0)
        
        # Calculate statistics
        valid_times = [t for t in build_times if t != float('inf')]
        
        if not valid_times:
            return {"error": "All build iterations failed"}
        
        return {
            "dockerfile": dockerfile_path,
            "context_path": context_path,
            "iterations": iterations,
            "use_cache": use_cache,
            "build_times": build_times,
            "build_sizes": build_sizes,
            "cache_usage": cache_usage,
            "stats": {
                "mean_time": sum(valid_times) / len(valid_times),
                "min_time": min(valid_times),
                "max_time": max(valid_times),
                "mean_size_mb": sum(build_sizes) / len(build_sizes) / (1024*1024),
                "mean_cache_hit_rate": sum(cache_usage) / len(cache_usage) if cache_usage else 0
            },
            "success_rate": len(valid_times) / iterations * 100
        }
    
    def compare_build_strategies(self, dockerfile_path: str, context_path: str = None) -> Dict:
        """Compare different build strategies"""
        strategies = {
            "with_cache": {"use_cache": True, "description": "Build with cache"},
            "no_cache": {"use_cache": False, "description": "Build without cache"},
        }
        
        results = {
            "dockerfile": dockerfile_path,
            "timestamp": datetime.now().isoformat(),
            "strategies": {}
        }
        
        for strategy_name, config in strategies.items():
            print(f"\nTesting {config['description']}...")
            result = self.benchmark_build(
                dockerfile_path, 
                context_path, 
                iterations=3,
                use_cache=config["use_cache"]
            )
            results["strategies"][strategy_name] = result
        
        return results
    
    def analyze_build_context(self, context_path: str) -> Dict:
        """Analyze build context for optimization opportunities"""
        context_size = 0
        file_count = 0
        large_files = []
        
        # Walk through context directory
        for root, dirs, files in os.walk(context_path):
            # Skip .git and other VCS directories
            dirs[:] = [d for d in dirs if not d.startswith('.git')]
            
            for file in files:
                filepath = os.path.join(root, file)
                try:
                    file_size = os.path.getsize(filepath)
                    context_size += file_size
                    file_count += 1
                    
                    # Track large files (> 10MB)
                    if file_size > 10 * 1024 * 1024:
                        large_files.append({
                            "path": os.path.relpath(filepath, context_path),
                            "size_mb": file_size / (1024 * 1024)
                        })
                        
                except (OSError, IOError):
                    continue
        
        # Check for .dockerignore
        dockerignore_exists = os.path.exists(os.path.join(context_path, '.dockerignore'))
        
        return {
            "context_size_mb": context_size / (1024 * 1024),
            "file_count": file_count,
            "large_files": large_files,
            "dockerignore_exists": dockerignore_exists,
            "recommendations": self._get_context_recommendations(context_size, file_count, large_files, dockerignore_exists)
        }
    
    def _get_context_recommendations(self, size: int, files: int, large_files: List, has_dockerignore: bool) -> List[str]:
        """Generate recommendations for build context optimization"""
        recommendations = []
        
        size_mb = size / (1024 * 1024)
        
        if size_mb > 100:
            recommendations.append("Build context is large (>100MB). Consider using .dockerignore to exclude unnecessary files.")
        
        if files > 1000:
            recommendations.append("Build context has many files. This may slow down the build process.")
        
        if large_files:
            recommendations.append(f"Found {len(large_files)} large files in context. Consider excluding them with .dockerignore.")
        
        if not has_dockerignore:
            recommendations.append("No .dockerignore file found. Create one to exclude unnecessary files from build context.")
        
        return recommendations
    
    def generate_optimization_report(self, dockerfile_path: str, context_path: str = None) -> Dict:
        """Generate comprehensive optimization report"""
        if context_path is None:
            context_path = os.path.dirname(dockerfile_path) or "."
        
        print("Generating comprehensive build optimization report...")
        
        # Analyze Dockerfile
        dockerfile_analysis = self.analyze_dockerfile(dockerfile_path)
        
        # Analyze build context
        context_analysis = self.analyze_build_context(context_path)
        
        # Benchmark build performance
        performance_analysis = self.compare_build_strategies(dockerfile_path, context_path)
        
        return {
            "timestamp": datetime.now().isoformat(),
            "dockerfile": dockerfile_path,
            "context": context_path,
            "dockerfile_analysis": dockerfile_analysis,
            "context_analysis": context_analysis,
            "performance_analysis": performance_analysis,
            "overall_score": self._calculate_overall_score(dockerfile_analysis, context_analysis, performance_analysis)
        }
    
    def _calculate_overall_score(self, dockerfile_analysis: Dict, context_analysis: Dict, performance_analysis: Dict) -> int:
        """Calculate overall optimization score"""
        score = 100
        
        # Dockerfile optimizations
        score -= len(dockerfile_analysis.get('optimizations', [])) * 5
        
        # Context size penalty
        context_size_mb = context_analysis.get('context_size_mb', 0)
        if context_size_mb > 500:
            score -= 30
        elif context_size_mb > 100:
            score -= 15
        elif context_size_mb > 50:
            score -= 5
        
        # Large files penalty
        large_files = len(context_analysis.get('large_files', []))
        score -= large_files * 5
        
        # No .dockerignore penalty
        if not context_analysis.get('dockerignore_exists', False):
            score -= 10
        
        return max(0, min(100, score))

def main():
    parser = argparse.ArgumentParser(description="Docker build performance analyzer")
    parser.add_argument("dockerfile", help="Path to Dockerfile")
    parser.add_argument("-c", "--context", help="Build context path")
    parser.add_argument("-i", "--iterations", type=int, default=3, help="Build iterations")
    parser.add_argument("-o", "--output", help="Output JSON file")
    parser.add_argument("--analyze-only", action="store_true", help="Only analyze, don't benchmark builds")
    parser.add_argument("--format", choices=["json", "text"], default="text", help="Output format")
    
    args = parser.parse_args()
    
    analyzer = BuildPerformanceAnalyzer()
    
    try:
        if args.analyze_only:
            # Quick analysis without building
            dockerfile_analysis = analyzer.analyze_dockerfile(args.dockerfile)
            context_analysis = analyzer.analyze_build_context(args.context or os.path.dirname(args.dockerfile) or ".")
            
            result = {
                "timestamp": datetime.now().isoformat(),
                "dockerfile_analysis": dockerfile_analysis,
                "context_analysis": context_analysis
            }
        else:
            # Full optimization report
            result = analyzer.generate_optimization_report(args.dockerfile, args.context)
        
        # Output results
        if args.format == "json":
            output = json.dumps(result, indent=2)
        else:
            output = format_text_report(result)
        
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output)
            print(f"Report saved to {args.output}")
        else:
            print(output)
            
    except KeyboardInterrupt:
        print("\nAnalysis interrupted by user")
    except Exception as e:
        print(f"Analysis failed: {e}")

def format_text_report(result: Dict) -> str:
    """Format analysis result as text report"""
    lines = []
    lines.append("🏗️  Docker Build Performance Analysis")
    lines.append("=" * 50)
    lines.append(f"Timestamp: {result.get('timestamp', 'N/A')}")
    lines.append(f"Dockerfile: {result.get('dockerfile', 'N/A')}")
    lines.append("")
    
    # Dockerfile analysis
    if 'dockerfile_analysis' in result:
        df_analysis = result['dockerfile_analysis']
        lines.append("📄 Dockerfile Analysis")
        lines.append("-" * 25)
        lines.append(f"Total lines: {df_analysis.get('total_lines', 0)}")
        lines.append(f"Estimated layers: {df_analysis.get('estimated_layers', 0)}")
        lines.append(f"Optimization score: {df_analysis.get('optimization_score', 0)}/100")
        
        optimizations = df_analysis.get('optimizations', [])
        if optimizations:
            lines.append("\n⚠️  Optimization Opportunities:")
            for opt in optimizations:
                lines.append(f"  Line {opt['line']}: {opt['message']}")
        lines.append("")
    
    # Context analysis
    if 'context_analysis' in result:
        ctx_analysis = result['context_analysis']
        lines.append("📁 Build Context Analysis")
        lines.append("-" * 30)
        lines.append(f"Context size: {ctx_analysis.get('context_size_mb', 0):.1f} MB")
        lines.append(f"File count: {ctx_analysis.get('file_count', 0)}")
        lines.append(f".dockerignore exists: {ctx_analysis.get('dockerignore_exists', False)}")
        
        large_files = ctx_analysis.get('large_files', [])
        if large_files:
            lines.append(f"\n📦 Large files ({len(large_files)}):")
            for file_info in large_files[:5]:  # Show top 5
                lines.append(f"  {file_info['path']}: {file_info['size_mb']:.1f} MB")
        
        recommendations = ctx_analysis.get('recommendations', [])
        if recommendations:
            lines.append("\n💡 Recommendations:")
            for rec in recommendations:
                lines.append(f"  • {rec}")
        lines.append("")
    
    # Performance analysis
    if 'performance_analysis' in result:
        perf_analysis = result['performance_analysis']
        lines.append("⚡ Performance Analysis")
        lines.append("-" * 25)
        
        strategies = perf_analysis.get('strategies', {})
        for strategy_name, strategy_result in strategies.items():
            if 'stats' in strategy_result:
                stats = strategy_result['stats']
                lines.append(f"{strategy_name.replace('_', ' ').title()}:")
                lines.append(f"  Mean build time: {stats.get('mean_time', 0):.2f}s")
                lines.append(f"  Image size: {stats.get('mean_size_mb', 0):.1f} MB")
                lines.append(f"  Cache hit rate: {stats.get('mean_cache_hit_rate', 0):.1f}%")
        lines.append("")
    
    # Overall score
    if 'overall_score' in result:
        score = result['overall_score']
        lines.append(f"🎯 Overall Optimization Score: {score}/100")
        
        if score >= 90:
            lines.append("   Excellent! Your build is well optimized.")
        elif score >= 70:
            lines.append("   Good, but there's room for improvement.")
        elif score >= 50:
            lines.append("   Moderate optimization needed.")
        else:
            lines.append("   Significant optimization opportunities exist.")
    
    return "\n".join(lines)

if __name__ == "__main__":
    main()