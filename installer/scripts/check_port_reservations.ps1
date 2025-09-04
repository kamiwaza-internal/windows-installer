# Check Kamiwaza port reservations and conflicts
# Can be run without administrator privileges

Write-Host "Kamiwaza Port Status Check" -ForegroundColor Green
Write-Host "Checking ports 61100-61299" -ForegroundColor Yellow
Write-Host ""

# Check port exclusions
Write-Host "=== Port Exclusions (Reserved by Windows) ===" -ForegroundColor Cyan
$exclusions = netsh int ipv4 show excludedportrange protocol=tcp | Select-String -Pattern "^\s*61[0-9]"
if ($exclusions) {
    $exclusions | ForEach-Object { Write-Host $_.Line -ForegroundColor Green }
    Write-Host "[OK] Kamiwaza ports appear to be reserved" -ForegroundColor Green
} else {
    Write-Host "[WARN] No port exclusions found in Kamiwaza range (61100-61299)" -ForegroundColor Yellow
    Write-Host "Run reserve_kamiwaza_ports.bat as Administrator to reserve them" -ForegroundColor Yellow
}

Write-Host ""

# Check active connections
Write-Host "=== Active Connections in Kamiwaza Range ===" -ForegroundColor Cyan
$connections = netstat -an | Select-String -Pattern ":61[0-9]"
if ($connections) {
    Write-Host "[WARN] Found active connections in Kamiwaza port range:" -ForegroundColor Yellow
    $connections | ForEach-Object { Write-Host "  $($_.Line)" -ForegroundColor Red }
} else {
    Write-Host "[OK] No active connections found in Kamiwaza port range" -ForegroundColor Green
}

Write-Host ""

# Check listening services
Write-Host "=== Services Listening in Kamiwaza Range ===" -ForegroundColor Cyan
$listeners = netstat -an | Select-String -Pattern ":61[0-9].*LISTENING"
if ($listeners) {
    Write-Host "[WARN] Found services listening in Kamiwaza port range:" -ForegroundColor Yellow
    $listeners | ForEach-Object { Write-Host "  $($_.Line)" -ForegroundColor Red }
    
    Write-Host ""
    Write-Host "To identify which processes are using these ports:" -ForegroundColor Yellow
    Write-Host "  netstat -ano | findstr :61" -ForegroundColor Gray
    Write-Host "Then use Task Manager or:" -ForegroundColor Gray
    Write-Host "  tasklist /fi \"PID eq [PID_NUMBER]\"" -ForegroundColor Gray
} else {
    Write-Host "[OK] No services listening in Kamiwaza port range" -ForegroundColor Green
}

Write-Host ""

# Dynamic port range check
Write-Host "=== Windows Dynamic Port Range ===" -ForegroundColor Cyan
$dynamicRange = netsh int ipv4 show dynamicport tcp
Write-Host $dynamicRange
$startPort = ($dynamicRange | Select-String -Pattern "Start Port\s*:\s*(\d+)").Matches.Groups[1].Value
$numPorts = ($dynamicRange | Select-String -Pattern "Number of Ports\s*:\s*(\d+)").Matches.Groups[1].Value

if ($startPort -and $numPorts) {
    $endPort = [int]$startPort + [int]$numPorts - 1
    Write-Host ""
    if ([int]$startPort -le 61299 -and $endPort -ge 61100) {
        Write-Host "[WARN] Kamiwaza port range (61100-61299) overlaps with Windows dynamic range ($startPort-$endPort)" -ForegroundColor Yellow
        Write-Host "This is why port reservations are important!" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Kamiwaza port range (61100-61299) does not overlap with Windows dynamic range ($startPort-$endPort)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor White
Write-Host "Kamiwaza uses ports 61100-61299 for internal services" -ForegroundColor Gray
Write-Host "Port reservations prevent Windows from dynamically assigning these ports to other applications" -ForegroundColor Gray
Write-Host ""
Write-Host "To reserve ports: Run reserve_kamiwaza_ports.bat as Administrator" -ForegroundColor Gray
Write-Host "To release ports: netsh int ipv4 delete excludedportrange protocol=tcp startport=61100 numberofports=200" -ForegroundColor Gray