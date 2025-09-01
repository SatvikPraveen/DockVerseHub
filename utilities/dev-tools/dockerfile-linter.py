# Location: utilities/dev-tools/dockerfile-linter.py
# Dockerfile best practices checker and linter

import os
import re
import sys
import json
import argparse
from pathlib import Path
from typing import List, Dict, Tuple

class DockerfileLinter:
    def __init__(self):
        self.issues = []
        self.line_count = 0
        
    def lint_file(self, filepath: str) -> List[Dict]:
        """Lint a Dockerfile and return issues found"""
        self.issues = []
        self.line_count = 0
        
        try:
            with open(filepath, 'r') as f:
                lines = f.readlines()
        except Exception as e:
            return [{"line": 0, "level": "error", "message": f"Cannot read file: {e}"}]
        
        # Check each line
        for i, line in enumerate(lines, 1):
            self.line_count = i
            self._check_line(line.strip(), i)
        
        # Check overall structure
        self._check_overall_structure(lines)
        
        return self.issues
    
    def _add_issue(self, line: int, level: str, message: str, rule: str = ""):
        """Add an issue to the list"""
        self.issues.append({
            "line": line,
            "level": level,
            "message": message,
            "rule": rule
        })
    
    def _check_line(self, line: str, line_num: int):
        """Check individual line for issues"""
        if not line or line.startswith('#'):
            return
        
        # Check for common issues
        self._check_from_instruction(line, line_num)
        self._check_run_instruction(line, line_num)
        self._check_copy_add_instruction(line, line_num)
        self._check_workdir_instruction(line, line_num)
        self._check_expose_instruction(line, line_num)
        self._check_user_instruction(line, line_num)
        self._check_cmd_entrypoint(line, line_num)
        self._check_general_practices(line, line_num)
    
    def _check_from_instruction(self, line: str, line_num: int):
        """Check FROM instruction best practices"""
        if line.upper().startswith('FROM'):
            # Check for latest tag
            if ':latest' in line or not ':' in line:
                self._add_issue(line_num, "warning", "Avoid using 'latest' tag or untagged images", "DL3006")
            
            # Check for specific version
            if re.search(r'FROM\s+\w+$', line, re.IGNORECASE):
                self._add_issue(line_num, "info", "Consider pinning image to specific version", "DL3007")
    
    def _check_run_instruction(self, line: str, line_num: int):
        """Check RUN instruction best practices"""
        if line.upper().startswith('RUN'):
            # Check for apt-get without -y
            if 'apt-get' in line and '-y' not in line and '--yes' not in line:
                self._add_issue(line_num, "error", "apt-get install should use -y flag", "DL3009")
            
            # Check for apt-get update without install
            if 'apt-get update' in line and 'apt-get install' not in line:
                self._add_issue(line_num, "warning", "apt-get update should be paired with install in same RUN", "DL3008")
            
            # Check for missing clean up after apt-get
            if 'apt-get install' in line and 'rm -rf /var/lib/apt/lists/*' not in line:
                self._add_issue(line_num, "warning", "Missing cleanup after apt-get install", "DL3009")
            
            # Check for curl/wget without clean up
            if re.search(r'curl|wget', line) and 'rm' not in line:
                self._add_issue(line_num, "info", "Consider cleaning up downloaded files", "DL4001")
            
            # Check for using sudo
            if 'sudo' in line:
                self._add_issue(line_num, "error", "Avoid using sudo in containers", "DL3004")
            
            # Check for chaining commands
            if '&&' not in line and ('apt-get' in line or 'yum' in line):
                self._add_issue(line_num, "info", "Consider chaining commands with && to reduce layers", "DL3001")
    
    def _check_copy_add_instruction(self, line: str, line_num: int):
        """Check COPY/ADD instruction best practices"""
        if line.upper().startswith(('COPY', 'ADD')):
            # Prefer COPY over ADD
            if line.upper().startswith('ADD') and not re.search(r'\.tar\.|\.zip|http', line):
                self._add_issue(line_num, "warning", "Use COPY instead of ADD for files/directories", "DL3020")
            
            # Check for copying everything
            if '. .' in line or './ ./' in line:
                self._add_issue(line_num, "warning", "Avoid copying everything, use specific files/directories", "DL3021")
            
            # Check for missing --chown
            if line.upper().startswith('COPY') and '--chown=' not in line:
                self._add_issue(line_num, "info", "Consider using --chown with COPY to set ownership", "DL3022")
    
    def _check_workdir_instruction(self, line: str, line_num: int):
        """Check WORKDIR instruction best practices"""
        if line.upper().startswith('WORKDIR'):
            # Check for relative paths
            workdir = line.split()[1] if len(line.split()) > 1 else ""
            if workdir and not workdir.startswith('/'):
                self._add_issue(line_num, "warning", "Use absolute paths for WORKDIR", "DL3000")
    
    def _check_expose_instruction(self, line: str, line_num: int):
        """Check EXPOSE instruction best practices"""
        if line.upper().startswith('EXPOSE'):
            # Check for common ports
            ports = re.findall(r'\d+', line)
            for port in ports:
                port_num = int(port)
                if port_num < 1024 and port_num not in [80, 443]:
                    self._add_issue(line_num, "warning", f"Exposing privileged port {port}", "DL3011")
    
    def _check_user_instruction(self, line: str, line_num: int):
        """Check USER instruction best practices"""
        if line.upper().startswith('USER'):
            user = line.split()[1] if len(line.split()) > 1 else ""
            if user in ['root', '0']:
                self._add_issue(line_num, "warning", "Running as root user is not recommended", "DL3002")
    
    def _check_cmd_entrypoint(self, line: str, line_num: int):
        """Check CMD/ENTRYPOINT best practices"""
        if line.upper().startswith(('CMD', 'ENTRYPOINT')):
            # Check for shell form vs exec form
            if not line.strip().endswith(']') and '"' not in line:
                self._add_issue(line_num, "info", "Consider using exec form instead of shell form", "DL3025")
    
    def _check_general_practices(self, line: str, line_num: int):
        """Check general best practices"""
        # Check for hardcoded secrets
        secret_patterns = [
            r'password\s*=\s*[\'"][^\'"]+[\'"]',
            r'api_key\s*=\s*[\'"][^\'"]+[\'"]',
            r'secret\s*=\s*[\'"][^\'"]+[\'"]',
            r'token\s*=\s*[\'"][^\'"]+[\'"]'
        ]
        
        for pattern in secret_patterns:
            if re.search(pattern, line, re.IGNORECASE):
                self._add_issue(line_num, "error", "Possible hardcoded secret detected", "DL3003")
        
        # Check for missing quotes around arguments
        if 'ENV' in line.upper() and '=' in line and '"' not in line and "'" not in line:
            self._add_issue(line_num, "info", "Consider quoting ENV values", "DL3024")
    
    def _check_overall_structure(self, lines: List[str]):
        """Check overall Dockerfile structure"""
        instructions = []
        for line in lines:
            line = line.strip()
            if line and not line.startswith('#'):
                inst = line.split()[0].upper() if line.split() else ""
                if inst in ['FROM', 'RUN', 'COPY', 'ADD', 'WORKDIR', 'EXPOSE', 'USER', 'CMD', 'ENTRYPOINT']:
                    instructions.append(inst)
        
        # Check for FROM as first instruction
        if instructions and instructions[0] != 'FROM':
            self._add_issue(1, "error", "Dockerfile must start with FROM instruction", "DL3001")
        
        # Check for multiple CMD/ENTRYPOINT
        cmd_count = instructions.count('CMD')
        entry_count = instructions.count('ENTRYPOINT')
        
        if cmd_count > 1:
            self._add_issue(0, "warning", "Multiple CMD instructions found, only last one takes effect", "DL3026")
        
        if entry_count > 1:
            self._add_issue(0, "warning", "Multiple ENTRYPOINT instructions found, only last one takes effect", "DL3027")
        
        # Check for missing health check
        if 'HEALTHCHECK' not in [line.strip().split()[0].upper() for line in lines if line.strip() and not line.startswith('#')]:
            self._add_issue(0, "info", "Consider adding HEALTHCHECK instruction", "DL3028")

def format_output(issues: List[Dict], format_type: str, filepath: str) -> str:
    """Format output based on specified format"""
    if format_type == 'json':
        return json.dumps({
            "file": filepath,
            "issues": issues,
            "total_issues": len(issues)
        }, indent=2)
    
    elif format_type == 'sarif':
        sarif_output = {
            "version": "2.1.0",
            "runs": [{
                "tool": {
                    "driver": {
                        "name": "dockerfile-linter",
                        "version": "1.0.0"
                    }
                },
                "results": []
            }]
        }
        
        for issue in issues:
            sarif_output["runs"][0]["results"].append({
                "ruleId": issue.get("rule", "GENERIC"),
                "level": issue["level"],
                "message": {"text": issue["message"]},
                "locations": [{
                    "physicalLocation": {
                        "artifactLocation": {"uri": filepath},
                        "region": {"startLine": issue["line"]}
                    }
                }]
            })
        
        return json.dumps(sarif_output, indent=2)
    
    else:  # Default table format
        if not issues:
            return f"✅ {filepath}: No issues found!"
        
        output = [f"📋 Dockerfile Linting Results for: {filepath}"]
        output.append("=" * 50)
        
        # Group by severity
        errors = [i for i in issues if i['level'] == 'error']
        warnings = [i for i in issues if i['level'] == 'warning']
        info = [i for i in issues if i['level'] == 'info']
        
        if errors:
            output.append(f"\n🔴 ERRORS ({len(errors)}):")
            for issue in errors:
                output.append(f"  Line {issue['line']}: {issue['message']}")
                if issue.get('rule'):
                    output.append(f"    Rule: {issue['rule']}")
        
        if warnings:
            output.append(f"\n🟡 WARNINGS ({len(warnings)}):")
            for issue in warnings:
                output.append(f"  Line {issue['line']}: {issue['message']}")
                if issue.get('rule'):
                    output.append(f"    Rule: {issue['rule']}")
        
        if info:
            output.append(f"\n🔵 INFO ({len(info)}):")
            for issue in info:
                output.append(f"  Line {issue['line']}: {issue['message']}")
                if issue.get('rule'):
                    output.append(f"    Rule: {issue['rule']}")
        
        output.append(f"\n📊 Summary: {len(errors)} errors, {len(warnings)} warnings, {len(info)} suggestions")
        
        return "\n".join(output)

def main():
    parser = argparse.ArgumentParser(description="Dockerfile linter and best practices checker")
    parser.add_argument("files", nargs="+", help="Dockerfile(s) to lint")
    parser.add_argument("-f", "--format", choices=["table", "json", "sarif"], 
                       default="table", help="Output format")
    parser.add_argument("-o", "--output", help="Output file (default: stdout)")
    parser.add_argument("--ignore", action="append", help="Rules to ignore (e.g., DL3006)")
    parser.add_argument("-q", "--quiet", action="store_true", help="Only show errors and warnings")
    parser.add_argument("--fail-on-warning", action="store_true", help="Exit with error code on warnings")
    
    args = parser.parse_args()
    
    linter = DockerfileLinter()
    all_results = {}
    total_issues = 0
    has_errors = False
    has_warnings = False
    
    # Process each file
    for dockerfile in args.files:
        if not os.path.exists(dockerfile):
            print(f"❌ Error: File {dockerfile} not found", file=sys.stderr)
            sys.exit(1)
        
        issues = linter.lint_file(dockerfile)
        
        # Filter ignored rules
        if args.ignore:
            issues = [i for i in issues if i.get('rule', '') not in args.ignore]
        
        # Filter by quiet mode
        if args.quiet:
            issues = [i for i in issues if i['level'] in ['error', 'warning']]
        
        all_results[dockerfile] = issues
        total_issues += len(issues)
        
        # Check for errors and warnings
        if any(i['level'] == 'error' for i in issues):
            has_errors = True
        if any(i['level'] == 'warning' for i in issues):
            has_warnings = True
    
    # Format output
    if len(args.files) == 1:
        output = format_output(all_results[args.files[0]], args.format, args.files[0])
    else:
        # Multiple files
        if args.format == 'json':
            output = json.dumps(all_results, indent=2)
        else:
            output_lines = []
            for filepath, issues in all_results.items():
                output_lines.append(format_output(issues, args.format, filepath))
                output_lines.append("")  # Separator
            output = "\n".join(output_lines)
    
    # Write output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(output)
        print(f"✅ Results written to {args.output}")
    else:
        print(output)
    
    # Exit with appropriate code
    if has_errors:
        sys.exit(2)  # Error code for errors
    elif has_warnings and args.fail_on_warning:
        sys.exit(1)  # Error code for warnings if fail-on-warning is set
    else:
        sys.exit(0)  # Success

if __name__ == "__main__":
    main()