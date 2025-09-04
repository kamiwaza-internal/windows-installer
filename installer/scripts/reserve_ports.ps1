# Reserve Kamiwaza port range 61100-61299
# Run as Administrator

param(
    [switch]$Remove
)

$StartPort = 61100
$EndPort = 61299
$PortCount = $EndPort - $StartPort + 1

Write-Host "Kamiwaza Port Reservation Script" -ForegroundColor Green
Write-Host "Port range: $StartPort-$EndPort ($PortCount ports)" -ForegroundColor Yellow

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Red
    exit 1
}

if ($Remove) {
    Write-Host "Removing port reservations..." -ForegroundColor Yellow
    try {
        # Remove the port reservation
        $result = netsh int ipv4 delete excludedportrange protocol=tcp startport=$StartPort numberofports=$PortCount
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully removed port reservations for range $StartPort-$EndPort" -ForegroundColor Green
        } else {
            Write-Host "Failed to remove port reservations: $result" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error removing port reservations: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Creating port reservations..." -ForegroundColor Yellow
    try {
        # Reserve the port range using netsh
        $result = netsh int ipv4 add excludedportrange protocol=tcp startport=$StartPort numberofports=$PortCount store=persistent
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully reserved ports $StartPort-$EndPort for Kamiwaza" -ForegroundColor Green
            Write-Host "These ports are now excluded from dynamic allocation" -ForegroundColor Green
        } else {
            Write-Host "Failed to reserve ports: $result" -ForegroundColor Red
            Write-Host "This may be because some ports in the range are already in use" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error reserving ports: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Show current port reservations
Write-Host "`nCurrent TCP port exclusions:" -ForegroundColor Cyan
netsh int ipv4 show excludedportrange protocol=tcp | Select-String -Pattern "61[0-9]" -Context 1,1

Write-Host "`nTo verify ports are available, you can use:" -ForegroundColor Gray
Write-Host "  netstat -an | findstr :611" -ForegroundColor Gray
Write-Host "`nTo remove these reservations later, run:" -ForegroundColor Gray
Write-Host "  .\reserve_ports.ps1 -Remove" -ForegroundColor Gray