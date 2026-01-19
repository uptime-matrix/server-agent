# UptimeMatrix Windows Agent Installer
# Version: 1.1

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ServerKey,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$Gateway = "https://hop.uptimematrix.com"
)

# ============================================
# PRE-FLIGHT CHECKS - Run before anything else
# ============================================

$preflightErrors = @()
$preflightWarnings = @()

# Check 1: Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $preflightErrors += @{
        Issue = "Administrator privileges required"
        Fix = "Right-click PowerShell and select 'Run as Administrator', then run the installer again"
    }
}

# Check 2: PowerShell version (minimum 5.0)
if ($PSVersionTable.PSVersion.Major -lt 5) {
    $preflightErrors += @{
        Issue = "PowerShell version $($PSVersionTable.PSVersion) is too old (minimum: 5.0)"
        Fix = "Update PowerShell: https://aka.ms/PSWindows"
    }
}

# Check 3: Execution Policy
$execPolicy = Get-ExecutionPolicy
if ($execPolicy -eq "Restricted") {
    $preflightWarnings += @{
        Issue = "Execution Policy is set to 'Restricted'"
        Fix = "Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    }
}

# Check 4: Network connectivity
try {
    $null = [System.Net.Dns]::GetHostAddresses("hop.uptimematrix.com")
} catch {
    $preflightErrors += @{
        Issue = "Cannot resolve hop.uptimematrix.com - no network connectivity"
        Fix = "Check your internet connection and DNS settings"
    }
}

# Check 5: GitHub connectivity (for downloading agent)
try {
    $null = [System.Net.Dns]::GetHostAddresses("raw.githubusercontent.com")
} catch {
    $preflightErrors += @{
        Issue = "Cannot resolve raw.githubusercontent.com"
        Fix = "Check your internet connection or firewall settings"
    }
}

# Display pre-flight results if there are issues
if ($preflightErrors.Count -gt 0 -or $preflightWarnings.Count -gt 0) {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "   PRE-FLIGHT CHECK FAILED" -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host ""

    if ($preflightErrors.Count -gt 0) {
        Write-Host "ERRORS (must fix before installation):" -ForegroundColor Red
        Write-Host ""
        $errorNum = 1
        foreach ($err in $preflightErrors) {
            Write-Host "  $errorNum. $($err.Issue)" -ForegroundColor Red
            Write-Host "     -> FIX: $($err.Fix)" -ForegroundColor Yellow
            Write-Host ""
            $errorNum++
        }
    }

    if ($preflightWarnings.Count -gt 0) {
        Write-Host "WARNINGS (may cause issues):" -ForegroundColor Yellow
        Write-Host ""
        $warnNum = 1
        foreach ($warn in $preflightWarnings) {
            Write-Host "  $warnNum. $($warn.Issue)" -ForegroundColor Yellow
            Write-Host "     -> FIX: $($warn.Fix)" -ForegroundColor Cyan
            Write-Host ""
            $warnNum++
        }
    }

    if ($preflightErrors.Count -gt 0) {
        Write-Host "==============================================" -ForegroundColor Red
        Write-Host "Please resolve the errors above and try again." -ForegroundColor White
        Write-Host "==============================================" -ForegroundColor Red
        Write-Host ""
        exit 1
    }

    # Only warnings - ask user if they want to continue
    $continue = Read-Host "Do you want to continue despite warnings? [Y/n]"
    if ($continue -match "^[Nn]") {
        Write-Host ""
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 1
    }
    Write-Host ""
}

# ============================================
# END PRE-FLIGHT CHECKS
# ============================================

# Clear console
Clear-Host

# Color functions for interactive output
function Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Error-Custom { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Warning-Custom { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Header { param([string]$Message) Write-Host $Message -ForegroundColor White }

# Welcome banner
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Welcome to UptimeMatrix Agent Installer" -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor White
Write-Host "   Gateway: $Gateway" -ForegroundColor Cyan
Write-Host ""

# Installation paths
$InstallPath = "C:\ProgramData\UptimeMatrix"
$AgentPath = Join-Path $InstallPath "agent.ps1"
$ServerKeyPath = Join-Path $InstallPath "serverkey.txt"
$GatewayPath = Join-Path $InstallPath "gateway.txt"
$LogPath = Join-Path $InstallPath "install.log"
$UninstallPath = Join-Path $InstallPath "uninstall.ps1"

# Start logging
Start-Transcript -Path $LogPath -Append | Out-Null

# Validate server key
if ([string]::IsNullOrWhiteSpace($ServerKey)) {
    Write-Error-Custom "The server key parameter is missing"
    Write-Host "→ Usage: .\install.ps1 <server-key> [gateway-url]" -ForegroundColor Yellow
    Write-Host "→ Example: .\install.ps1 ABC123DEF456" -ForegroundColor Cyan
    Write-Host "→ Example: .\install.ps1 ABC123DEF456 https://hop.uptimematrix.com" -ForegroundColor Cyan
    Write-Host "→ Exiting installer" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# Check for existing installation
# Only detect as "installed" if agent.ps1 exists OR scheduled task exists
$taskName = "UptimeMatrix Agent"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$existingAgent = Test-Path $AgentPath  # Check for agent.ps1, not just the folder

if ($existingAgent -or $existingTask) {
    Write-Host "=============================================" -ForegroundColor Yellow
    Write-Host "   Existing Installation Detected" -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Yellow
    Write-Host ""

    if ($existingAgent) {
        Write-Host "   Found: $AgentPath" -ForegroundColor Cyan
    }
    if ($existingTask) {
        Write-Host "   Found: Scheduled Task '$taskName'" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "What would you like to do?" -ForegroundColor White
    Write-Host ""
    Write-Host "   [1] Repair / Re-install agent" -ForegroundColor Green
    Write-Host "   [2] Remove / Uninstall agent" -ForegroundColor Red
    Write-Host "   [3] Cancel and exit" -ForegroundColor Yellow
    Write-Host ""

    $choice = Read-Host "Enter your choice (1/2/3)"

    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Info "Proceeding with repair/re-install..."
            Write-Host ""

            # Remove existing installation
            if ($existingTask) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            }
            if (Test-Path $InstallPath) {
                Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Success "Previous installation removed"
        }
        "2" {
            Write-Host ""
            Write-Info "Removing UptimeMatrix Agent..."
            Write-Host ""

            # Remove scheduled task
            if ($existingTask) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                Write-Success "Scheduled task removed"
            }

            # Remove installation directory
            if (Test-Path $InstallPath) {
                Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Installation files removed"
            }

            Write-Host ""
            Write-Host "=============================================" -ForegroundColor Green
            Write-Host "   UptimeMatrix Agent Removed Successfully" -ForegroundColor Green
            Write-Host "=============================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Thank you for using UptimeMatrix!" -ForegroundColor Cyan
            Write-Host ""
            Stop-Transcript | Out-Null
            exit 0
        }
        default {
            Write-Host ""
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            Stop-Transcript | Out-Null
            exit 0
        }
    }
}

# Create installation directory
Write-Info "Creating installation directory..."
try {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Success "Directory created at $InstallPath"
} catch {
    Write-Error-Custom "Failed to create installation directory"
    Write-Host "→ Exiting installer" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# Check gateway connection
Write-Info "Checking gateway connection to $Gateway..."

# Validate Gateway URL format
if ($Gateway -notmatch "^https?://") {
    Write-Error-Custom "Invalid Gateway URL format. Must start with http:// or https://"
    Write-Host "→ Exiting installer" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

$isHttps = $Gateway.StartsWith("https://")

try {
    $response = Invoke-WebRequest -Uri $Gateway -Method Head -TimeoutSec 10 -ErrorAction Stop
    if ($isHttps) {
        Write-Success "SSL Connection established to $Gateway"
    } else {
        Write-Success "Connection established to $Gateway (HTTP - less secure)"
    }
} catch {
    if ($isHttps) {
        Write-Warning-Custom "Cannot establish SSL connection to $Gateway"
        Write-Host ""
        Write-Host "Maybe you are using an old OS which cannot establish SSL connection." -ForegroundColor Yellow
        Write-Host "But you can still continue monitoring using HTTP protocol (less secure)." -ForegroundColor Yellow
        Write-Host ""

        $continue = Read-Host "Do you want to continue with HTTP? [Y/n]"
        if ($continue -match "^[Nn]") {
            Write-Host ""
            Write-Error-Custom "Terminated UptimeMatrix agent installation."
            Write-Host "If you think this is an error, please contact support." -ForegroundColor Cyan
            Write-Host ""
            Stop-Transcript | Out-Null
            exit 1
        }

        Write-Host ""
        Write-Host "→ Continuing installation with HTTP protocol..." -ForegroundColor Yellow
        $Gateway = $Gateway -replace "^https://", "http://"
    } else {
        Write-Error-Custom "Cannot connect to gateway: $Gateway"
        Write-Host "→ Check your network connection and try again" -ForegroundColor Yellow
        Stop-Transcript | Out-Null
        exit 1
    }
}

# Download agent script
Write-Info "Downloading agent..."
$AgentUrl = "https://raw.githubusercontent.com/uptime-matrix/server-agent/refs/heads/main/agent.ps1"
try {
    Invoke-WebRequest -Uri $AgentUrl -OutFile $AgentPath -ErrorAction Stop
    Write-Success "Agent downloaded successfully"
} catch {
    Write-Error-Custom "Unable to download agent!"
    Write-Host "→ Exiting installer" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# Verify download
if (-not (Test-Path $AgentPath)) {
    Write-Error-Custom "Unable to install!"
    Write-Host "→ Exiting installer" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# Save configuration
Write-Info "Saving configuration..."
Set-Content -Path $ServerKeyPath -Value $ServerKey -Force
Set-Content -Path $GatewayPath -Value $Gateway -Force
Write-Success "Configuration saved"

# Create uninstall script
Write-Info "Creating uninstall script..."
$UninstallScript = @'
# UptimeMatrix Windows Agent Uninstaller
# This script removes the UptimeMatrix agent from your system

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "[ERROR] Administrator privileges required" -ForegroundColor Red
    Write-Host "-> FIX: Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   UptimeMatrix Agent Uninstaller" -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$InstallPath = "C:\ProgramData\UptimeMatrix"
$TaskName = "UptimeMatrix Agent"

# Confirm uninstallation
$confirm = Read-Host "Are you sure you want to uninstall UptimeMatrix Agent? [y/N]"
if ($confirm -notmatch "^[Yy]") {
    Write-Host ""
    Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Remove scheduled task
Write-Host "[INFO] Removing scheduled task..." -ForegroundColor Cyan
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "[OK] Scheduled task removed" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Scheduled task not found (already removed?)" -ForegroundColor Yellow
}

# Remove installation directory
Write-Host "[INFO] Removing installation files..." -ForegroundColor Cyan
if (Test-Path $InstallPath) {
    # Copy this script to temp so we can delete the install folder
    $tempScript = Join-Path $env:TEMP "uptimematrix_cleanup.ps1"
    $cleanupScript = @"

Start-Sleep -Seconds 2
Remove-Item -Path '$InstallPath' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
"@
    Set-Content -Path $tempScript -Value $cleanupScript -Force

    Write-Host "[OK] Installation files will be removed" -ForegroundColor Green
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "   Uninstallation Completed Successfully!" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Thank you for using UptimeMatrix!" -ForegroundColor Cyan
    Write-Host ""

    # Start cleanup script and exit
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempScript`"" -WindowStyle Hidden
} else {
    Write-Host "[WARNING] Installation directory not found (already removed?)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "   Uninstallation Completed!" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
}
'@

Set-Content -Path $UninstallPath -Value $UninstallScript -Force
Write-Success "Uninstall script created"

# Create scheduled task
Write-Info "Configuring scheduled task..."
try {
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$AgentPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew
    
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "UptimeMatrix Server Monitoring Agent"
    Register-ScheduledTask -TaskName "UptimeMatrix Agent" -InputObject $task -Force | Out-Null
    
    Write-Success "Scheduled task configured"
} catch {
    Write-Error-Custom "Failed to create scheduled task: $_"
    Write-Host "-> Exiting installer" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# Run agent once to send initial data
Write-Host ""
Write-Info "Sending initial server data..."
try {
    & PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File $AgentPath
    Write-Success "Initial data sent successfully"
} catch {
    Write-Warning-Custom "Could not send initial data (will retry via scheduled task)"
}

# Installation complete
Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "        Installation Completed Successfully!" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "   1. Check your server data at:" -ForegroundColor Cyan
Write-Host "      https://app.uptimematrix.com/servers" -ForegroundColor Blue
Write-Host ""
Write-Host "   2. Agent is running and will send data every minute" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation Log:" -ForegroundColor White
Write-Host "   $LogPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Uninstall Instructions:" -ForegroundColor White
Write-Host "   $UninstallPath" -ForegroundColor Yellow
Write-Host "   (Run as Administrator)" -ForegroundColor Cyan
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "   Thank you for choosing UptimeMatrix!" -ForegroundColor White
Write-Host "   www.uptimematrix.com" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

Stop-Transcript | Out-Null
