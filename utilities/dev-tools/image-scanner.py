# Location: utilities/dev-tools/image-scanner.py
# Docker image security vulnerability scanner

import os
import sys
import json
import subprocess
import argparse
from typing import Dict, List, Optional
import tempfile
from pathlib import Path

class ImageScanner:
    def __init__(self):
        self.scan_results = {}
        self.tools_available = self._check_tools()
    
    def _check_tools(self) -> Dict[str, bool]:
        """Check which scanning tools are available"""
        tools = {
            'trivy': self._command_exists('trivy'),
            'docker': self._command_exists('docker'),
            'grype': self._command_exists('grype'),
            'syft': self._command_exists('syft')
        }
        return tools
    
    def _command_exists(self, command: str) -> bool:
        """Check if a command exists in PATH"""
        try:
            subprocess.run([command, '--version'], 
                         capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def scan_with_trivy(self, image: str, severity: str = "HIGH,CRITICAL") -> Dict:
        """Scan image with Trivy"""
        if not self.tools_available.get('trivy', False):
            return {"error": "Trivy not available"}
        
        try:
            cmd = [
                'trivy', 'image',
                '--format', 'json',
                '--severity', severity,
                '--no-progress',
                image
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return json.loads(result.stdout)
            
        except subprocess.CalledProcessError as e:
            return {"error": f"Trivy scan failed: {e.stderr}"}
        except json.JSONDecodeError:
            return {"error": "Failed to parse Trivy output"}
    
    def scan_with_grype(self, image: str) -> Dict:
        """Scan image with Grype"""
        if not self.tools_available.get('grype', False):
            return {"error": "Grype not available"}
        
        try:
            cmd = ['grype', '-o', 'json', image]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return json.loads(result.stdout)
            
        except subprocess.CalledProcessError as e:
            return {"error": f"Grype scan failed: {e.stderr}"}
        except json.JSONDecodeError:
            return {"error": "Failed to parse Grype output"}
    
    def analyze_image_layers(self, image: str) -> Dict:
        """Analyze image layers for size and efficiency"""
        if not self.tools_available.get('docker', False):
            return {"error": "Docker not available"}
        
        try:
            # Get image history
            cmd = ['docker', 'history', '--format', 'json', '--no-trunc', image]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            layers = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    layers.append(json.loads(line))
            
            # Get image size
            cmd = ['docker', 'inspect', '--format', '{{.Size}}', image]
            size_result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            total_size = int(size_result.stdout.strip())
            
            return {
                "layers": layers,
                "total_size": total_size,
                "layer_count": len(layers)
            }
            
        except subprocess.CalledProcessError as e:
            return {"error": f"Layer analysis failed: {e.stderr}"}
    
    def generate_sbom(self, image: str) -> Dict:
        """Generate Software Bill of Materials using Syft"""
        if not self.tools_available.get('syft', False):
            return {"error": "Syft not available"}
        
        try:
            cmd = ['syft', '-o', 'json', image]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return json.loads(result.stdout)
            
        except subprocess.CalledProcessError as e:
            return {"error": f"SBOM generation failed: {e.stderr}"}
        except json.JSONDecodeError:
            return {"error": "Failed to parse SBOM output"}
    
    def check_image_config(self, image: str) -> Dict:
        """Check image configuration for security issues"""
        if not self.tools_available.get('docker', False):
            return {"error": "Docker not available"}
        
        try:
            cmd = ['docker', 'inspect', image]
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            config = json.loads(result.stdout)[0]
            
            security_issues = []
            
            # Check if running as root
            user = config.get('Config', {}).get('User', '')
            if not user or user == 'root' or user == '0':
                security_issues.append({
                    "type": "user",
                    "severity": "medium",
                    "message": "Image configured to run as root"
                })
            
            # Check exposed ports
            exposed_ports = config.get('Config', {}).get('ExposedPorts', {})
            for port in exposed_ports:
                port_num = int(port.split('/')[0])
                if port_num < 1024:
                    security_issues.append({
                        "type": "port",
                        "severity": "low",
                        "message": f"Privileged port {port_num} exposed"
                    })
            
            # Check environment variables for secrets
            env_vars = config.get('Config', {}).get('Env', [])
            secret_keywords = ['password', 'secret', 'key', 'token', 'api_key']
            
            for env_var in env_vars:
                var_name = env_var.split('=')[0].lower()
                if any(keyword in var_name for keyword in secret_keywords):
                    security_issues.append({
                        "type": "environment",
                        "severity": "high",
                        "message": f"Potential secret in environment variable: {var_name}"
                    })
            
            return {
                "config": config['Config'],
                "security_issues": security_issues
            }
            
        except subprocess.CalledProcessError as e:
            return {"error": f"Config check failed: {e.stderr}"}
        except (json.JSONDecodeError, KeyError, IndexError) as e:
            return {"error": f"Failed to parse config: {e}"}
    
    def comprehensive_scan(self, image: str, severity: str = "HIGH,CRITICAL") -> Dict:
        """Perform comprehensive security scan"""
        results = {
            "image": image,
            "timestamp": subprocess.run(['date', '-u', '+%Y-%m-%dT%H:%M:%SZ'], 
                                      capture_output=True, text=True).stdout.strip(),
            "tools_used": [],
            "vulnerabilities": {},
            "config_issues": {},
            "layer_analysis": {},
            "sbom": {},
            "summary": {
                "total_vulnerabilities": 0,
                "critical": 0,
                "high": 0,
                "medium": 0,
                "low": 0
            }
        }
        
        # Trivy scan
        if self.tools_available.get('trivy', False):
            print(f"🔍 Scanning {image} with Trivy...")
            trivy_result = self.scan_with_trivy(image, severity)
            results["vulnerabilities"]["trivy"] = trivy_result
            results["tools_used"].append("trivy")
            
            # Count vulnerabilities from Trivy
            if "Results" in trivy_result:
                for result in trivy_result["Results"]:
                    for vuln in result.get("Vulnerabilities", []):
                        severity_level = vuln.get("Severity", "").lower()
                        if severity_level in results["summary"]:
                            results["summary"][severity_level] += 1
                            results["summary"]["total_vulnerabilities"] += 1
        
        # Grype scan
        if self.tools_available.get('grype', False):
            print(f"🔍 Scanning {image} with Grype...")
            grype_result = self.scan_with_grype(image)
            results["vulnerabilities"]["grype"] = grype_result
            results["tools_used"].append("grype")
        
        # Configuration check
        print(f"⚙️  Checking {image} configuration...")
        config_result = self.check_image_config(image)
        results["config_issues"] = config_result
        
        # Layer analysis
        print(f"📊 Analyzing {image} layers...")
        layer_result = self.analyze_image_layers(image)
        results["layer_analysis"] = layer_result
        
        # SBOM generation
        if self.tools_available.get('syft', False):
            print(f"📋 Generating SBOM for {image}...")
            sbom_result = self.generate_sbom(image)
            results["sbom"] = sbom_result
            results["tools_used"].append("syft")
        
        return results
    
    def generate_report(self, scan_results: Dict, format_type: str = "json") -> str:
        """Generate formatted report"""
        if format_type == "json":
            return json.dumps(scan_results, indent=2)
        
        elif format_type == "html":
            return self._generate_html_report(scan_results)
        
        else:  # text format
            return self._generate_text_report(scan_results)
    
    def _generate_text_report(self, results: Dict) -> str:
        """Generate text report"""
        lines = []
        lines.append("🛡️  Docker Image Security Scan Report")
        lines.append("=" * 50)
        lines.append(f"Image: {results['image']}")
        lines.append(f"Scan Time: {results['timestamp']}")
        lines.append(f"Tools Used: {', '.join(results['tools_used'])}")
        lines.append("")
        
        # Summary
        summary = results['summary']
        lines.append("📊 Vulnerability Summary:")
        lines.append(f"  Total: {summary['total_vulnerabilities']}")
        lines.append(f"  Critical: {summary['critical']}")
        lines.append(f"  High: {summary['high']}")
        lines.append(f"  Medium: {summary['medium']}")
        lines.append(f"  Low: {summary['low']}")
        lines.append("")
        
        # Configuration issues
        config_issues = results.get('config_issues', {}).get('security_issues', [])
        if config_issues:
            lines.append("⚠️  Configuration Issues:")
            for issue in config_issues:
                lines.append(f"  [{issue['severity'].upper()}] {issue['message']}")
            lines.append("")
        
        # Layer analysis
        layer_info = results.get('layer_analysis', {})
        if 'total_size' in layer_info:
            size_mb = layer_info['total_size'] / (1024 * 1024)
            lines.append(f"📦 Image Size: {size_mb:.2f} MB ({layer_info['layer_count']} layers)")
            lines.append("")
        
        # Detailed vulnerabilities (top 10)
        trivy_vulns = results.get('vulnerabilities', {}).get('trivy', {})
        if 'Results' in trivy_vulns:
            lines.append("🔴 Top Vulnerabilities:")
            vuln_count = 0
            for result in trivy_vulns['Results']:
                for vuln in result.get('Vulnerabilities', []):
                    if vuln_count >= 10:
                        break
                    lines.append(f"  {vuln.get('VulnerabilityID', 'N/A')} ({vuln.get('Severity', 'N/A')})")
                    lines.append(f"    Package: {vuln.get('PkgName', 'N/A')}")
                    lines.append(f"    Version: {vuln.get('InstalledVersion', 'N/A')}")
                    if 'FixedVersion' in vuln:
                        lines.append(f"    Fixed in: {vuln['FixedVersion']}")
                    lines.append("")
                    vuln_count += 1
        
        return "\n".join(lines)
    
    def _generate_html_report(self, results: Dict) -> str:
        """Generate HTML report"""
        html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Security Scan Report - {results['image']}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .header {{ background: #f8f9fa; padding: 20px; border-radius: 5px; }}
        .summary {{ background: #e3f2fd; padding: 15px; margin: 10px 0; border-radius: 5px; }}
        .critical {{ color: #d32f2f; font-weight: bold; }}
        .high {{ color: #f57c00; font-weight: bold; }}
        .medium {{ color: #fbc02d; font-weight: bold; }}
        .low {{ color: #388e3c; font-weight: bold; }}
        table {{ border-collapse: collapse; width: 100%; margin: 10px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ Security Scan Report</h1>
        <p><strong>Image:</strong> {results['image']}</p>
        <p><strong>Scan Time:</strong> {results['timestamp']}</p>
        <p><strong>Tools Used:</strong> {', '.join(results['tools_used'])}</p>
    </div>
    
    <div class="summary">
        <h2>📊 Vulnerability Summary</h2>
        <p>Total Vulnerabilities: <strong>{results['summary']['total_vulnerabilities']}</strong></p>
        <p>
            <span class="critical">Critical: {results['summary']['critical']}</span> |
            <span class="high">High: {results['summary']['high']}</span> |
            <span class="medium">Medium: {results['summary']['medium']}</span> |
            <span class="low">Low: {results['summary']['low']}</span>
        </p>
    </div>
</body>
</html>
        """
        return html

def main():
    parser = argparse.ArgumentParser(description="Docker image security scanner")
    parser.add_argument("images", nargs="+", help="Images to scan")
    parser.add_argument("-s", "--severity", default="HIGH,CRITICAL",
                       help="Vulnerability severity levels to include")
    parser.add_argument("-f", "--format", choices=["json", "text", "html"],
                       default="text", help="Output format")
    parser.add_argument("-o", "--output", help="Output file")
    parser.add_argument("--install-tools", action="store_true",
                       help="Show tool installation instructions")
    
    args = parser.parse_args()
    
    scanner = ImageScanner()
    
    if args.install_tools:
        print("📦 Security Scanning Tools Installation:")
        print("=" * 40)
        print("# Install Trivy")
        print("curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin")
        print()
        print("# Install Grype")
        print("curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin")
        print()
        print("# Install Syft")
        print("curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin")
        return
    
    # Check if any scanning tools are available
    if not any(scanner.tools_available.values()):
        print("❌ No scanning tools available. Use --install-tools for installation instructions.")
        sys.exit(1)
    
    all_results = []
    
    for image in args.images:
        print(f"\n🔍 Scanning image: {image}")
        print("-" * 50)
        
        try:
            result = scanner.comprehensive_scan(image, args.severity)
            all_results.append(result)
            
            # Print summary
            summary = result['summary']
            if summary['total_vulnerabilities'] > 0:
                print(f"❌ Found {summary['total_vulnerabilities']} vulnerabilities")
                print(f"   Critical: {summary['critical']}, High: {summary['high']}")
            else:
                print("✅ No vulnerabilities found")
                
        except Exception as e:
            print(f"❌ Error scanning {image}: {e}")
            continue
    
    # Generate final report
    if len(all_results) == 1:
        report = scanner.generate_report(all_results[0], args.format)
    else:
        # Multiple images - create combined report
        if args.format == "json":
            report = json.dumps(all_results, indent=2)
        else:
            report_parts = []
            for result in all_results:
                report_parts.append(scanner.generate_report(result, args.format))
            report = "\n\n" + "="*80 + "\n\n".join(report_parts)
    
    # Output report
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"\n📄 Report saved to: {args.output}")
    else:
        print("\n" + report)
    
    # Exit with error code if vulnerabilities found
    total_vulns = sum(r['summary']['total_vulnerabilities'] for r in all_results)
    if total_vulns > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()