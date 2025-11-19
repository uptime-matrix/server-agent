# UptimeMatrix Windows Agent
# Version: 1.1

# Set error action preference
$ErrorActionPreference = 'SilentlyContinue'

# Configuration paths
$InstallPath = "C:\ProgramData\UptimeMatrix"
$ServerKeyPath = Join-Path $InstallPath "serverkey.txt"
$GatewayPath = Join-Path $InstallPath "gateway.txt"

# Load configuration
$SERVERKEY = Get-Content $ServerKeyPath -Raw -ErrorAction Stop | ForEach-Object { $_.Trim() }
$GATEWAY = Get-Content $GatewayPath -Raw -ErrorAction Stop | ForEach-Object { $_.Trim() }

# Initialize POST data
$POST = ""

# Helper Functions
function Get-WindowsOS {
    $os = Get-CimInstance Win32_OperatingSystem
    return "$($os.Caption) $($os.Version)"
}

function Get-CPUSpeed {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    return $cpu.MaxClockSpeed
}

function Get-DefaultInterface {
    $route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | 
             Sort-Object -Property RouteMetric | 
             Select-Object -First 1
    if ($route) {
        return $route.InterfaceAlias
    }
    return ""
}

function Get-ActiveConnections {
    $tcp = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue).Count
    $udp = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue).Count
    return $tcp + $udp
}

function Get-PingLatency {
    try {
        $ping = Test-Connection -ComputerName google.com -Count 2 -ErrorAction Stop
        $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
        return [math]::Round($avgLatency, 2)
    } catch {
        return ""
    }
}

function Get-CPUUsageSnapshot {
    # Get CPU performance counters
    $counters = Get-Counter '\Processor(*)\% User Time','\Processor(*)\% Privileged Time','\Processor(*)\% Idle Time' -ErrorAction SilentlyContinue
    $result = ""
    
    # Use WMI as fallback for consistent format
    $cpus = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor
    foreach ($cpu in $cpus) {
        $name = if ($cpu.Name -eq '_Total') { 'cpu' } else { "cpu$($cpu.Name)" }
        
        # Map Windows performance data to Linux /proc/stat format:
        # Format: name,user,nice,system,idle,iowait,irq,softirq,steal,guest,guest_nice
        $user = [int]$cpu.PercentUserTime
        $nice = 0  # Windows doesn't have nice
        $system = [int]$cpu.PercentPrivilegedTime
        $idle = [int]$cpu.PercentIdleTime
        $iowait = 0  # Windows doesn't separate IO wait
        $irq = [int]$cpu.PercentInterruptTime
        $softirq = [int]$cpu.PercentDPCTime
        $steal = 0  # Not applicable to Windows
        $guest = 0  # Not applicable to Windows
        $guest_nice = 0  # Not applicable to Windows
        
        $result += "$name,$user,$nice,$system,$idle,$iowait,$irq,$softirq,$steal,$guest,$guest_nice;"
    }
    return $result.TrimEnd(';')
}

function Get-RDPSessions {
    try {
        $sessions = qwinsta 2>$null | Select-String "Active|Disc" | Measure-Object
        return $sessions.Count
    } catch {
        return 0
    }
}

# Agent version
$agent_version = "1.1"
$POST += "{agent_version}$agent_version{/agent_version}"

# Server key
$POST += "{serverkey}$SERVERKEY{/serverkey}"

# Gateway
$POST += "{gateway}$GATEWAY{/gateway}"

# Hostname
$hostname = $env:COMPUTERNAME
$POST += "{hostname}$hostname{/hostname}"

# Kernel (Windows Build)
$os = Get-CimInstance Win32_OperatingSystem
$kernel = "$($os.Version) Build $($os.BuildNumber)"
$POST += "{kernel}$kernel{/kernel}"

# Time
$time = [int][double]::Parse((Get-Date -UFormat %s))
$POST += "{time}$time{/time}"

# OS
$os_name = Get-WindowsOS
$POST += "{os}$os_name{/os}"

# OS Arch
$os_arch = "$($env:PROCESSOR_ARCHITECTURE),$($env:PROCESSOR_ARCHITECTURE)"
$POST += "{os_arch}$os_arch{/os_arch}"

# CPU Model
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpu_model = $cpu.Name.Trim()
$POST += "{cpu_model}$cpu_model{/cpu_model}"

# CPU Cores
$cpu_cores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
$POST += "{cpu_cores}$cpu_cores{/cpu_cores}"

# CPU Speed (MHz)
$cpu_speed = Get-CPUSpeed
$POST += "{cpu_speed}$cpu_speed{/cpu_speed}"

# CPU Load (Windows doesn't have 1,5,15 min averages like Linux, using current %)
$cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$POST += "{cpu_load}$cpuLoad,$cpuLoad,$cpuLoad{/cpu_load}"

# CPU Info (performance data snapshot)
$cpu_info = Get-CPUUsageSnapshot
$POST += "{cpu_info}$cpu_info{/cpu_info}"
Start-Sleep -Seconds 1
$cpu_info_current = Get-CPUUsageSnapshot
$POST += "{cpu_info_current}$cpu_info_current{/cpu_info_current}"

# Disks
# Format matches Linux: device,fstype,total_blocks,used_blocks,available_blocks,use%,mounted_on
$disks = ""
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $device = $_.DeviceID
    $fstype = if ($_.FileSystem) { $_.FileSystem } else { "NTFS" }
    $total = if ($_.Size) { [math]::Round($_.Size / 1KB) } else { 0 }
    $available = if ($_.FreeSpace) { [math]::Round($_.FreeSpace / 1KB) } else { 0 }
    $used = $total - $available
    $usePercent = if ($total -gt 0) { [math]::Round(($used / $total) * 100) } else { 0 }
    $mountedOn = $device
    
    # Match df output format: device,fstype,total,used,available,use%,mounted
    $disks += "$device,$fstype,$total,$used,$available,${usePercent}%,$mountedOn;"
}
$POST += "{disks}$($disks.TrimEnd(';')){/disks}"

# Disk inodes (Windows uses MFT records, approximating with file count would be slow)
# Using same disk info as placeholder for compatibility
$disks_inodes = ""
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $drive = $_.DeviceID
    $disks_inodes += "$drive,0,0,0,0%,$drive;"
}
$POST += "{disks_inodes}$($disks_inodes.TrimEnd(';')){/disks_inodes}"

# File descriptors (Windows equivalent: Handle count)
$handleCount = (Get-Process | Measure-Object -Property HandleCount -Sum).Sum
$POST += "{file_descriptors}$handleCount,0,0{/file_descriptors}"

# RAM Total (KB)
$ram_total = [math]::Round($os.TotalVisibleMemorySize)
$POST += "{ram_total}$ram_total{/ram_total}"

# RAM Free (KB)
$ram_free = [math]::Round($os.FreePhysicalMemory)
$POST += "{ram_free}$ram_free{/ram_free}"

# RAM Caches (Windows caches are included in free memory calculation)
$ram_caches = 0
$POST += "{ram_caches}$ram_caches{/ram_caches}"

# RAM Buffers (Windows doesn't expose this separately)
$ram_buffers = 0
$POST += "{ram_buffers}$ram_buffers{/ram_buffers}"

# RAM Usage (KB)
$ram_usage = $ram_total - $ram_free
$POST += "{ram_usage}$ram_usage{/ram_usage}"

# SWAP/PageFile Total (KB)
$pageFile = Get-CimInstance Win32_PageFileUsage
$swap_total = if ($pageFile) { [math]::Round($pageFile.AllocatedBaseSize * 1024) } else { 0 }
$POST += "{swap_total}$swap_total{/swap_total}"

# SWAP Free (KB)
$swap_used_mb = if ($pageFile) { $pageFile.CurrentUsage } else { 0 }
$swap_free = $swap_total - ($swap_used_mb * 1024)
$POST += "{swap_free}$swap_free{/swap_free}"

# SWAP Usage (KB)
$swap_usage = $swap_used_mb * 1024
$POST += "{swap_usage}$swap_usage{/swap_usage}"

# Default Interface
$default_interface = Get-DefaultInterface
$POST += "{default_interface}$default_interface{/default_interface}"

# All Interfaces (name, bytes received, bytes sent, packets received, packets sent)
$all_interfaces = ""
Get-NetAdapterStatistics | ForEach-Object {
    $name = $_.Name
    $stats = $_
    $all_interfaces += "$name,$($stats.ReceivedBytes),$($stats.SentBytes),$($stats.ReceivedUnicastPackets),$($stats.SentUnicastPackets);"
}
$POST += "{all_interfaces}$($all_interfaces.TrimEnd(';')){/all_interfaces}"
Start-Sleep -Seconds 1
$all_interfaces_current = ""
Get-NetAdapterStatistics | ForEach-Object {
    $name = $_.Name
    $stats = $_
    $all_interfaces_current += "$name,$($stats.ReceivedBytes),$($stats.SentBytes),$($stats.ReceivedUnicastPackets),$($stats.SentUnicastPackets);"
}
$POST += "{all_interfaces_current}$($all_interfaces_current.TrimEnd(';')){/all_interfaces_current}"

# IPv4 Addresses
$ipv4_addresses = ""
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | ForEach-Object {
    $ipv4_addresses += "$($_.InterfaceAlias),$($_.IPAddress);"
}
$POST += "{ipv4_addresses}$($ipv4_addresses.TrimEnd(';')){/ipv4_addresses}"

# IPv6 Addresses
$ipv6_addresses = ""
Get-NetIPAddress -AddressFamily IPv6 | Where-Object { $_.IPAddress -notlike "::1" -and $_.IPAddress -notlike "fe80:*" } | ForEach-Object {
    $ipv6_addresses += "$($_.InterfaceAlias),$($_.IPAddress);"
}
$POST += "{ipv6_addresses}$($ipv6_addresses.TrimEnd(';')){/ipv6_addresses}"

# Active Connections
$active_connections = Get-ActiveConnections
$POST += "{active_connections}$active_connections{/active_connections}"

# Ping Latency
$ping_latency = Get-PingLatency
$POST += "{ping_latency}$ping_latency{/ping_latency}"

# RDP Sessions (equivalent to SSH sessions)
$rdp_sessions = Get-RDPSessions
$POST += "{ssh_sessions}$rdp_sessions{/ssh_sessions}"

# Uptime (seconds)
$bootTime = $os.LastBootUpTime
$uptime = ((Get-Date) - $bootTime).TotalSeconds
$uptime = [math]::Round($uptime, 2)
$POST += "{uptime}$uptime{/uptime}"

# Processes (top processes by CPU and Memory)
$processes = ""
$totalRAM = $os.TotalVisibleMemorySize * 1024  # Convert to bytes

# Get process performance data for CPU percentage
$processPerf = @{}
Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | ForEach-Object {
    if ($_.IDProcess -ne 0) {
        $processPerf[$_.IDProcess] = $_.PercentProcessorTime
    }
}

Get-Process | Sort-Object -Property WorkingSet64 -Descending | Select-Object -First 100 | ForEach-Object {
    $pid = $_.Id
    $ppid = try { (Get-CimInstance Win32_Process -Filter "ProcessId=$pid").ParentProcessId } catch { 0 }
    $rss = [math]::Round($_.WorkingSet64 / 1KB)
    $vsz = [math]::Round($_.VirtualMemorySize64 / 1KB)
    $user = try { $_.UserName } catch { "SYSTEM" }
    if (-not $user) { $user = "SYSTEM" }
    
    # Calculate memory percentage
    $pmem = if ($totalRAM -gt 0) { [math]::Round(($_.WorkingSet64 / $totalRAM) * 100, 2) } else { 0 }
    
    # Get CPU percentage from performance counter
    $pcpu = if ($processPerf.ContainsKey($pid)) { [math]::Round($processPerf[$pid], 2) } else { 0 }
    
    $comm = $_.ProcessName
    $cmd = $_.Path
    if (-not $cmd) { $cmd = $comm }
    $processes += "$pid,$ppid,$rss,$vsz,$user,$pmem,$pcpu,$comm,$cmd;"
}
$POST += "{processes}$($processes.TrimEnd(';')){/processes}"

# Send data to gateway
$body = "data=$POST"
$headers = @{
    "Authorization" = $SERVERKEY
    "Content-Type" = "application/x-www-form-urlencoded"
}

try {
    Invoke-RestMethod -Uri $GATEWAY -Method Post -Body $body -Headers $headers -TimeoutSec 50 -ErrorAction Stop | Out-Null
} catch {
    # Log error silently
    $error[0] | Out-File -FilePath (Join-Path $InstallPath "error.log") -Append
}
