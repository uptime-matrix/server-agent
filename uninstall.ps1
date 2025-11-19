# UptimeMatrix Windows Agent Uninstaller
# Version: 1.0

#Requires -RunAsAdministrator

# Clear console
Clear-Host

# Color functions
function Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Error-Custom { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }

# Banner
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   UptimeMatrix Agent Uninstaller" -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Confirm uninstallation
$confirm = Read-Host "Are you sure you want to uninstall UptimeMatrix Agent? [y/N]"
if ($confirm -notmatch "^[Yy]") {
    Write-Host ""
    Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host ""
$InstallPath = "C:\ProgramData\UptimeMatrix"

# Remove scheduled task
Write-Info "Removing scheduled task..."
$taskName = "UptimeMatrix Agent"
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Success "Scheduled task removed"
    } catch {
        Write-Error-Custom "Failed to remove scheduled task: $_"
    }
} else {
    Write-Host "  Scheduled task not found (already removed)" -ForegroundColor Gray
}

# Remove installation directory
Write-Info "Removing installation files..."
if (Test-Path $InstallPath) {
    try {
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop
        Write-Success "Installation files removed"
    } catch {
        Write-Error-Custom "Failed to remove installation files: $_"
    }
} else {
    Write-Host "  Installation directory not found (already removed)" -ForegroundColor Gray
}

# Completion
Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "   Uninstallation Completed!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "UptimeMatrix Agent has been removed from this server." -ForegroundColor Cyan
Write-Host "Thank you for using UptimeMatrix!" -ForegroundColor White
Write-Host ""
