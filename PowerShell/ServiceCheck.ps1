# Lab 5 - Domain Controller Service Monitoring
# Run on DC01 using Windows PowerShell.
$Services = @('DNS', 'NTDS', 'Netlogon')

foreach ($Service in $Services) {
    try {
        $Status = (Get-Service -Name $Service -ErrorAction Stop).Status
        $Color = if ($Status -eq 'Running') { 'Green' } else { 'Red' }
        Write-Host "${Service}: $Status" -ForegroundColor $Color
    }
    catch {
        Write-Warning "Unable to check ${Service}: $($_.Exception.Message)"
    }
}
