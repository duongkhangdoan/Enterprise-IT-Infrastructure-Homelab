# Lab 5 - Daily Disk Space Monitoring
# Suitable for execution from Windows Task Scheduler on DC01.
$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
if (-not $Disk -or $Disk.Size -le 0) {
    throw 'Unable to retrieve valid disk information for C:.'
}

$FreePercent = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 2)
$Time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

if ($FreePercent -lt 20) {
    $Message = "$Time WARNING: Disk C has $FreePercent% free space"
    Write-Host $Message -ForegroundColor Red
}
else {
    $Message = "$Time HEALTHY: Disk C has $FreePercent% free space"
    Write-Host $Message -ForegroundColor Green
}

Add-Content -Path 'C:\Scripts\DiskMonitor.log' -Value $Message -ErrorAction Stop
