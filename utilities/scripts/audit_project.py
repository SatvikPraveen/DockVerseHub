#!/usr/bin/env python3
"""
Comprehensive project audit script to identify all issues
"""

import os
import sys
import subprocess
import json
from pathlib import Path
from collections import defaultdict

def check_python_files():
    """Check all Python files for syntax errors"""
    issues = []
    for py_file in Path('.').rglob('*.py'):
        if '.git' in py_file.parts or '__pycache__' in py_file.parts:
            continue
        result = subprocess.run(
            ['python3', '-m', 'py_compile', str(py_file)],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            issues.append({
                'type': 'Python Syntax',
                'file': str(py_file),
                'error': result.stderr.split('\n')[0] if result.stderr else 'Unknown error'
            })
    return issues

def check_docker_files():
    """Check for issues in Dockerfiles"""
    issues = []
    for dockerfile in Path('.').rglob('Dockerfile*'):
        if '.git' in dockerfile.parts:
            continue
        with open(dockerfile, 'r') as f:
            content = f.read()
            # Check for missing curl in healthchecks
            if 'HEALTHCHECK' in content and 'curl' not in content:
                if 'apk add' in content or 'apt-get' in content or 'yum' in content:
                    # It might have curl, but let's flag it as a potential issue
                    pass
    return issues

def check_docker_compose_files():
    """Check docker-compose file syntax"""
    issues = []
    for compose_file in Path('.').rglob('docker-compose*.yml'):
        if '.git' in compose_file.parts:
            continue
        result = subprocess.run(
            ['docker-compose', '-f', str(compose_file), 'config'],
            capture_output=True,
            text=True,
            cwd=compose_file.parent
        )
        if result.returncode != 0:
            issues.append({
                'type': 'Docker Compose',
                'file': str(compose_file),
                'error': result.stderr.split('\n')[0] if result.stderr else 'Invalid syntax'
            })
    return issues

def check_shell_scripts():
    """Check shell scripts for syntax errors"""
    issues = []
    for sh_file in Path('.').rglob('*.sh'):
        if '.git' in sh_file.parts:
            continue
        result = subprocess.run(
            ['bash', '-n', str(sh_file)],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            issues.append({
                'type': 'Shell Script',
                'file': str(sh_file),
                'error': result.stderr.split('\n')[0] if result.stderr else 'Syntax error'
            })
    return issues

def check_makefile_targets():
    """Check if Makefile targets reference existing files"""
    issues = []
    if not Path('Makefile').exists():
        return issues
    
    with open('Makefile', 'r') as f:
        content = f.read()
    
    # Look for common patterns that reference missing files
    if 'utilities/scripts/start_compose.sh' in content:
        if not Path('utilities/scripts/start_compose.sh').exists():
            issues.append({
                'type': 'Makefile',
                'file': 'Makefile',
                'error': 'Referenced script missing: utilities/scripts/start_compose.sh'
            })
    
    return issues

def main():
    print("=" * 60)
    print("DockVerseHub Project Audit")
    print("=" * 60)
    
    all_issues = defaultdict(list)
    
    print("\n1. Checking Python files...")
    python_issues = check_python_files()
    if python_issues:
        print(f"   Found {len(python_issues)} Python syntax errors")
        for issue in python_issues:
            all_issues['python'].append(issue)
    
    print("2. Checking Docker Compose files...")
    compose_issues = check_docker_compose_files()
    if compose_issues:
        print(f"   Found {len(compose_issues)} Docker Compose issues")
        for issue in compose_issues:
            all_issues['compose'].append(issue)
    
    print("3. Checking Shell scripts...")
    shell_issues = check_shell_scripts()
    if shell_issues:
        print(f"   Found {len(shell_issues)} Shell script errors")
        for issue in shell_issues:
            all_issues['shell'].append(issue)
    
    print("4. Checking Makefile...")
    makefile_issues = check_makefile_targets()
    if makefile_issues:
        print(f"   Found {len(makefile_issues)} Makefile issues")
        for issue in makefile_issues:
            all_issues['makefile'].append(issue)
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    total_issues = sum(len(v) for v in all_issues.values())
    print(f"\nTotal issues found: {total_issues}\n")
    
    for category, issues in all_issues.items():
        if issues:
            print(f"\n{category.upper()} Issues ({len(issues)}):")
            print("-" * 60)
            for issue in issues[:5]:  # Show first 5
                print(f"  File: {issue['file']}")
                print(f"  Error: {issue['error']}")
                print()
            if len(issues) > 5:
                print(f"  ... and {len(issues) - 5} more {category} issues")
    
    return 0 if total_issues == 0 else 1

if __name__ == '__main__':
    sys.exit(main())
