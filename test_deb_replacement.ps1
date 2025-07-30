$content = Get-Content kamiwaza_headless_installer.py
$replaced = $content -replace '{{DEB_FILE_URL}}', 'https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_v0.5.0_noble_amd64_build14.deb'
$replaced | Where-Object { $_ -match 'def get_deb_url' -or $_ -match 'return.*deb' } | Select-Object -First 5
Write-Output "Replacement test completed"