# UptimeMatrix Server Agent

Monitor your servers with UptimeMatrix. Cross-platform support for Linux and Windows.

## 🐧 Linux Installation

```bash
curl -o install.sh https://raw.githubusercontent.com/UptimeMatrix/ServerAgent/master/install.sh
sudo bash install.sh YOUR_SERVER_KEY
```

## 🪟 Windows Installation

Run PowerShell as Administrator:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UptimeMatrix/ServerAgent/master/install.ps1" -OutFile "install.ps1"
.\install.ps1 YOUR_SERVER_KEY
```

## 📊 View Your Servers

After installation, view your server data at:
**https://app.uptimematrix.com/servers**

## 🗑️ Uninstallation

### Linux
```bash
rm -rf /opt/uptimematrix && crontab -r -u uptimematrixagent && userdel uptimematrixagent
```

### Windows
Run PowerShell as Administrator:
```powershell
.\uninstall.ps1
```

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