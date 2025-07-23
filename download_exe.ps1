param(
    [string]$DownloadUrl,
    [string]$OutputPath
)

try {
    $logFile = Join-Path (Split-Path $OutputPath -Parent) "download.log"
    "Starting download at $(Get-Date)" | Out-File -FilePath $logFile -Append
    "URL: $DownloadUrl" | Out-File -FilePath $logFile -Append
    "Output: $OutputPath" | Out-File -FilePath $logFile -Append
    
    Write-Host "Creating directory: $OutputPath"
    New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent) | Out-Null
    
    Write-Host "Downloading from: $DownloadUrl"
    Write-Host "Saving to: $OutputPath"
    
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
    
    if (Test-Path $OutputPath) {
        $fileSize = (Get-Item $OutputPath).Length
        Write-Host "Download completed successfully. File size: $fileSize bytes"
        "Download completed successfully. File size: $fileSize bytes at $(Get-Date)" | Out-File -FilePath $logFile -Append
        exit 0
    } else {
        Write-Host "Download failed: File not found after download"
        "Download failed: File not found after download at $(Get-Date)" | Out-File -FilePath $logFile -Append
        exit 1
    }
} catch {
    $errorMsg = "Download failed: $($_.Exception.Message)"
    Write-Host $errorMsg
    "$errorMsg at $(Get-Date)" | Out-File -FilePath $logFile -Append
    exit 1
} 