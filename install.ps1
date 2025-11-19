# UptimeMatrix Windows Agent Installer
# Version: 1.0

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ServerKey
)

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

# Installation paths
$InstallPath = "C:\ProgramData\UptimeMatrix"
$AgentPath = Join-Path $InstallPath "agent.ps1"
$ServerKeyPath = Join-Path $InstallPath "serverkey.txt"
$GatewayPath = Join-Path $InstallPath "gateway.txt"
$LogPath = Join-Path $InstallPath "install.log"

# Start logging
Start-Transcript -Path $LogPath -Append | Out-Null

# Validate server key
if ([string]::IsNullOrWhiteSpace($ServerKey)) {
    Write-Error-Custom "The server key parameter is missing"
    Write-Host "→ Usage: .\install.ps1 <server-key>" -ForegroundColor Yellow
    Write-Host "→ Exiting installer" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# Check for previous installation
if (Test-Path $InstallPath) {
    Write-Warning-Custom "Found previous installation, removing..."
    
    # Remove scheduled task
    $taskName = "UptimeMatrix Agent"
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    # Remove directory
    Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "Previous installation removed"
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

# Check SSL connection
Write-Info "Checking SSL connection..."
$Gateway = "https://hop.uptimematrix.com"
try {
    $response = Invoke-WebRequest -Uri $Gateway -Method Head -TimeoutSec 10 -ErrorAction Stop
    Write-Success "SSL Connection established"
} catch {
    Write-Warning-Custom "Cannot establish SSL connection"
    Write-Host ""
    Write-Host "Maybe you are using an old OS which cannot establish SSL connection." -ForegroundColor Yellow
    Write-Host "But you can still continue monitoring using HTTP protocol (less secure)." -ForegroundColor Yellow
    Write-Host ""
    
    $continue = Read-Host "Do you want to continue? [Y/n]"
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
    $Gateway = "http://hop.uptimematrix.com"
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
Write-Host "   .\uninstall.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "   Thank you for choosing UptimeMatrix!" -ForegroundColor White
Write-Host "   www.uptimematrix.com" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

Stop-Transcript | Out-Null
