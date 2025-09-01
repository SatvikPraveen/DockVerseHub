# Docker Installation - Windows

**File Location:** `concepts/01_getting_started/installation/windows.md`

## Prerequisites

- Windows 10/11 64-bit (Pro, Enterprise, or Education)
- Hyper-V and Containers Windows features enabled
- BIOS-level hardware virtualization support enabled

## Installation Options

### Option 1: Docker Desktop (Recommended)

1. **Download Docker Desktop**

   - Visit [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
   - Download Docker Desktop for Windows

2. **Install Docker Desktop**

   ```cmd
   # Run the installer as Administrator
   # Follow the installation wizard
   # Restart when prompted
   ```

3. **Enable Required Features** (if not already enabled)
   ```powershell
   # Run PowerShell as Administrator
   Enable-WindowsOptionalFeature -Online -FeatureName containers -All
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
   # Restart required
   ```

### Option 2: WSL 2 Backend (Recommended for Windows 10)

1. **Install WSL 2**

   ```powershell
   # Enable WSL
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

   # Enable Virtual Machine Platform
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

   # Download and install WSL2 kernel update
   # https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi

   # Set WSL 2 as default
   wsl --set-default-version 2
   ```

2. **Install Ubuntu from Microsoft Store**

   ```cmd
   # Or use PowerShell
   wsl --install -d Ubuntu
   ```

3. **Configure Docker Desktop to use WSL 2**
   - Open Docker Desktop
   - Go to Settings → General
   - Check "Use the WSL 2 based engine"

## Post-Installation Configuration

### Verify Installation

```cmd
# Check Docker version
docker --version
docker-compose --version

# Test installation
docker run hello-world
```

### Configure Resource Limits

1. Open Docker Desktop
2. Go to Settings → Resources
3. Adjust CPU, Memory, and Disk limits as needed

### Configure WSL Integration (if using WSL 2)

1. Settings → Resources → WSL Integration
2. Enable integration with your WSL distributions

## Common Issues and Solutions

### Hyper-V Not Available

```powershell
# Check if Hyper-V is supported
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

# Enable if available
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

### Virtualization Disabled in BIOS

1. Restart computer and enter BIOS/UEFI settings
2. Enable Intel VT-x or AMD-V
3. Enable Intel VT-d or AMD IOMMU (if available)

### WSL 2 Installation Issues

```powershell
# Update WSL
wsl --update

# List installed distributions
wsl --list --verbose

# Set default version
wsl --set-default-version 2
```

### Docker Service Not Starting

```cmd
# Restart Docker Desktop from system tray
# Or restart Windows Docker service
net stop com.docker.service
net start com.docker.service
```

## Performance Optimization

### Memory Usage

```cmd
# In WSL 2 terminal, create .wslconfig in Windows user home
# %UserProfile%\.wslconfig
[wsl2]
memory=4GB
processors=4
swap=2GB
```

### File System Performance

- Use WSL 2 file system for better I/O performance
- Avoid cross-file system operations (Windows ↔ WSL)

## Alternative: Docker Toolbox (Legacy)

For older Windows versions:

1. Download Docker Toolbox
2. Install VirtualBox
3. Run Docker Quickstart Terminal

```bash
# Verify in Docker Quickstart Terminal
docker --version
docker run hello-world
```

## Uninstallation

```cmd
# Uninstall Docker Desktop through Windows Settings
# Or use Control Panel → Programs and Features

# Clean up remaining files
del /s %APPDATA%\Docker
del /s %LOCALAPPDATA%\Docker
```

## Next Steps

- Run verification script
- Configure development environment
- Try first container examples
