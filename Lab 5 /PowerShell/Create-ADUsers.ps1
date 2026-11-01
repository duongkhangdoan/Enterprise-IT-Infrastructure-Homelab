# Lab 5 - Bulk Active Directory User Provisioning
# Run on a domain controller with the ActiveDirectory PowerShell module.
# Expected CSV headers: FirstName,LastName,Username,Department
# New accounts remain disabled until an administrator sets a compliant password.
Import-Module ActiveDirectory -ErrorAction Stop

$CsvPath = 'C:\Users\Administrator\NewEmployees.csv'
$TargetOU = 'OU=AutomationLab,DC=ad,DC=lab'
$Employees = Import-Csv -Path $CsvPath -ErrorAction Stop

foreach ($Employee in $Employees) {
    $Username = $Employee.Username.Trim()
    $FullName = "$($Employee.FirstName) $($Employee.LastName)"

    if ([string]::IsNullOrWhiteSpace($Username)) {
        Write-Warning 'Skipped a CSV row with no username.'
        continue
    }

    switch ($Employee.Department.Trim().ToUpperInvariant()) {
        'IT' { $Group = 'GG_IT_Users' }
        'HR' { $Group = 'GG_HR_Users' }
        default {
            Write-Warning "Skipped ${Username}: unsupported department '$($Employee.Department)'"
            continue
        }
    }

    try {
        $ExistingUser = Get-ADUser -Identity $Username -ErrorAction SilentlyContinue
        if ($ExistingUser) {
            Write-Host "Skipped: $Username already exists" -ForegroundColor Yellow
            continue
        }

        New-ADUser -Name $FullName `
            -GivenName $Employee.FirstName `
            -Surname $Employee.LastName `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@ad.lab" `
            -Department $Employee.Department `
            -Path $TargetOU `
            -Enabled $false `
            -ErrorAction Stop

        Add-ADGroupMember -Identity $Group -Members $Username -ErrorAction Stop
        Write-Host "Created: $Username | Group: $Group" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed: ${Username} - $($_.Exception.Message)"
    }
}
