# UptimeMatrix Server Agent

Monitor your servers with UptimeMatrix. Cross-platform support for Linux and Windows.

## 🐧 Linux Installation

```bash
curl -o install.sh https://raw.githubusercontent.com/uptime-matrix/server-agent/refs/heads/main/install.sh
sudo bash install.sh YOUR_SERVER_KEY
```

**With custom gateway:**
```bash
sudo bash install.sh YOUR_SERVER_KEY https://your-gateway.example.com
```

## 🪟 Windows Installation

Run PowerShell as Administrator:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/uptime-matrix/server-agent/refs/heads/main/install.ps1" -OutFile "install.ps1"; powershell -ExecutionPolicy Bypass -File .\install.ps1 YOUR_SERVER_KEY
```

**With custom gateway:**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/uptime-matrix/server-agent/refs/heads/main/install.ps1" -OutFile "install.ps1"; powershell -ExecutionPolicy Bypass -File .\install.ps1 YOUR_SERVER_KEY https://your-gateway.example.com
```

## 📊 View Your Servers

After installation, view your server data at:
**https://app.uptimematrix.com/servers**

## 🗑️ Uninstallation

### Linux
```bash
sudo rm -rf /opt/uptimematrix && sudo crontab -r -u uptimematrixagent && sudo userdel uptimematrixagent
```

Or simply re-run the installer and choose option `[2] Remove / Uninstall agent`.

### Windows
Run PowerShell as Administrator:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\ProgramData\UptimeMatrix\uninstall.ps1"
```

Or simply re-run the installer and choose option `[2] Remove / Uninstall agent`.

## 📝 What's Monitored

- **System Info**: OS, Hostname, Kernel/Build
- **CPU**: Model, Cores, Speed, Load, Usage
- **Memory**: RAM, SWAP/PageFile usage
- **Disk**: All volumes, usage, inodes
- **Network**: Interfaces, IP addresses, traffic stats
- **Processes**: Top processes by CPU/Memory
- **Connections**: Active network connections
- **Uptime**: System uptime
- **Sessions**: SSH/RDP sessions

## 🔄 Update Frequency

The agent sends data every **1 minute** automatically.

## 📂 File Locations

### Linux
- Installation: `/opt/uptimematrix/`
- Logs: `/tmp/uptimematrix.log`

### Windows
- Installation: `C:\ProgramData\UptimeMatrix\`
- Logs: `C:\ProgramData\UptimeMatrix\install.log`

## 🌐 Website

[www.uptimematrix.com](https://www.uptimematrix.com)