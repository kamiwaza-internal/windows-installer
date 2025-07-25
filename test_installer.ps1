Write-Host "=== Kamiwaza Installer Test Mode ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will test the installer without actually installing the .deb package" -ForegroundColor Yellow
Write-Host "Memory will be set to 16GB to test WSL configuration" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

Write-Host "Starting installer in test mode..." -ForegroundColor Green
python windows_installer.py --test --memory 16GB --debug

Write-Host ""
Write-Host "Test completed. Check the log output above." -ForegroundColor Cyan
exit