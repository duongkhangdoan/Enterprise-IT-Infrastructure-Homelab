## Overview

This lab demonstrates practical automation tasks for a junior IT Support Specialist or System Administrator. Using **Windows Server 2022** and **Ubuntu Server**, I created reusable scripts to manage Active Directory users, monitor Windows disk capacity, monitor Linux services, and schedule recurring checks.

The exercises were completed directly in the Windows Server PowerShell console and the Ubuntu terminal. The workflow below documents the final implementation from setup to successful results.

## Lab Environment

| Component | Configuration |
| --- | --- |
| Virtualization | Oracle VirtualBox |
| Domain Controller | DC01 — Windows Server 2022 Standard Evaluation |
| Active Directory domain | `ad.lab` |
| DC01 IP address | `192.168.10.10` |
| Linux server | Ubuntu Server (`duong`) |
| Ubuntu IP address | `192.168.10.102` |
| Windows tools | Windows PowerShell 5.1, Active Directory module, Task Scheduler |
| Linux tools | Bash, systemd, cron |
| AD groups | `GG_IT_Users`, `GG_HR_Users` |

### Objectives

1. Use PowerShell to inspect Windows Server information, processes, and services.
2. Automate Active Directory account creation and group assignment using CSV input.
3. Export Active Directory account reports.
4. Monitor disk capacity with a reusable PowerShell script and scheduled logging.
5. Monitor Ubuntu services with Bash and automate execution using cron.

---

## Part 1 — Windows PowerShell Fundamentals

### Step 1: Review PowerShell and server information

Open **Windows PowerShell as Administrator** on DC01.

```powershell
$PSVersionTable.PSVersion
Get-ComputerInfo | Select-Object CsName, WindowsProductName
Get-Service -Name DNS
Get-Process | Select-Object -First 5
```

These commands identify the PowerShell version, Windows Server edition, DNS service status, and active processes.

### Step 2: Practice variables and output

```powershell
$ServerName = "DC01"
$DomainName = "ad.lab"
$ServerIP = "192.168.10.10"

Write-Host "Server: $ServerName | Domain: $DomainName | IP: $ServerIP"
```
<img width="666" height="360" alt="image" src="https://github.com/user-attachments/assets/361d073e-9983-4f21-95c3-2c72d9f3e07c" />

### Step 3: Create a reusable service-check script

Create the scripts directory:

```powershell
New-Item -Path "C:\Scripts" -ItemType Directory -Force
```

Save the following content as **`C:\Scripts\ServiceCheck.ps1`**:

```powershell
$Services = @("DNS", "NTDS", "Netlogon")

foreach ($Service in $Services) {
    $Status = (Get-Service -Name $Service -ErrorAction Stop).Status

    if ($Status -eq "Running") {
        Write-Host "$Service : RUNNING" -ForegroundColor Green
    } else {
        Write-Host "$Service : NOT RUNNING ($Status)" -ForegroundColor Red
    }
}
```

Run the script:

```powershell
& "C:\Scripts\ServiceCheck.ps1"
```
<img width="573" height="189" alt="image" src="https://github.com/user-attachments/assets/b9a66fb2-dd33-427c-adfd-4f05e16487e2" />

**Result:** DNS, NTDS, and Netlogon were running on DC01.

---

## Part 2 — Active Directory User Provisioning

### Step 4: Create an organizational unit

```powershell
Import-Module ActiveDirectory

New-ADOrganizationalUnit -Name "AutomationLab" -Path "DC=ad,DC=lab"
```

The OU `AutomationLab` is used to organize the accounts created during this lab.

### Step 5: Create an individual AD account

```powershell
New-ADUser `
    -Name "Michael Brown" `
    -GivenName "Michael" `
    -Surname "Brown" `
    -SamAccountName "mbrown" `
    -UserPrincipalName "mbrown@ad.lab" `
    -Path "OU=AutomationLab,DC=ad,DC=lab" `
    -Enabled $false
```
<img width="750" height="125" alt="image" src="https://github.com/user-attachments/assets/b8e79625-1b57-4eec-8832-73ead19daf75" />

Set a password securely without placing plaintext credentials in the script:

```powershell
$Password = Read-Host "Enter password for mbrown" -AsSecureString
Set-ADAccountPassword -Identity "mbrown" -NewPassword $Password -Reset
Set-ADUser -Identity "mbrown" -ChangePasswordAtLogon $true
Enable-ADAccount -Identity "mbrown"
```

**Result:** The `mbrown` account was enabled and configured to require a password change at first sign-in.

### Step 6: Prepare a CSV of new employees

Create **`C:\Users\Administrator\NewEmployees.csv`** with this content:

```csv
FirstName,LastName,Username,Department
James,Wilson,jwilson,IT
Sarah,Johnson,sjohnson,HR
David,Miller,dmiller,IT
Emily,Clark,eclark,HR
Robert,Taylor,rtaylor,IT
Jessica,Anderson,janderson,HR
Daniel,Thomas,dthomas,IT
Ashley,Moore,amoore,HR
Christopher,Martin,cmartin,IT
Olivia,White,owhite,HR
```

Read the CSV into PowerShell:

```powershell
$Employees = Import-Csv "C:\Users\Administrator\NewEmployees.csv"
$Employees | Format-Table -AutoSize
```
<img width="744" height="307" alt="image" src="https://github.com/user-attachments/assets/f7813888-ecb9-4514-8be0-d29e0959cbd6" />

The CSV contains **10 employees**: five in IT and five in HR.

### Step 7: Automate account creation and group assignment

Save the following as **`C:\Scripts\Create-ADUsers.ps1`**:

```powershell
Import-Module ActiveDirectory

$Employees = Import-Csv "C:\Users\Administrator\NewEmployees.csv"
$OU = "OU=AutomationLab,DC=ad,DC=lab"

foreach ($Employee in $Employees) {
    $Username = $Employee.Username
    $FullName = "$($Employee.FirstName) $($Employee.LastName)"

    if ($Employee.Department -eq "IT") {
        $Group = "GG_IT_Users"
    }
    elseif ($Employee.Department -eq "HR") {
        $Group = "GG_HR_Users"
    }
    else {
        Write-Warning "Unknown department for $Username"
        continue
    }

    $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$Username'"

    if ($ExistingUser) {
        Write-Host "Skipped: $Username already exists" -ForegroundColor Yellow
        continue
    }

    try {
        New-ADUser `
            -Name $FullName `
            -GivenName $Employee.FirstName `
            -Surname $Employee.LastName `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@ad.lab" `
            -Department $Employee.Department `
            -Path $OU `
            -Enabled $false `
            -ErrorAction Stop

        Add-ADGroupMember `
            -Identity $Group `
            -Members $Username `
            -ErrorAction Stop

        Write-Host "Created: $Username | Group: $Group" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed: $Username - $($_.Exception.Message)"
    }
}
```

Run the provisioning script:

```powershell
& "C:\Scripts\Create-ADUsers.ps1"
```
<img width="709" height="566" alt="image" src="https://github.com/user-attachments/assets/3ea45ea3-4354-46c6-859e-f3373d29b2de" />

**Result:** Ten AD users were created in `AutomationLab`. Five were added to `GG_IT_Users` and five to `GG_HR_Users`. The new accounts remain disabled until their passwords and onboarding requirements are configured. The script checks whether a username already exists before creating it, so it can be reused with updated CSV data.

> **Operational note:** This is a training script. For production use, add input validation, structured logging, an approval workflow, and a policy for handling existing accounts whose group memberships need updating.
<img width="713" height="538" alt="image" src="https://github.com/user-attachments/assets/223cf8ca-4951-47aa-97ce-83cbed724e28" />

### Step 8: Export an Active Directory report

```powershell
Get-ADUser `
    -Filter * `
    -SearchBase "OU=AutomationLab,DC=ad,DC=lab" `
    -Properties Department, Enabled |
Select-Object Name, SamAccountName, Department, Enabled |
Export-Csv "C:\Users\Administrator\ADUsersReport.csv" -NoTypeInformation
```

The report can be viewed directly on DC01 or loaded in PowerShell:

```powershell
Import-Csv "C:\Users\Administrator\ADUsersReport.csv" |
    Format-Table -AutoSize
```

**Result:** The report contained **11 accounts**: Michael Brown (enabled) and ten newly provisioned employees (disabled).

To list disabled accounts in the lab OU:

```powershell
Get-ADUser `
    -Filter 'Enabled -eq $false' `
    -SearchBase "OU=AutomationLab,DC=ad,DC=lab" |
Select-Object Name, SamAccountName, Enabled |
Format-Table -AutoSize
```
<img width="636" height="477" alt="image" src="https://github.com/user-attachments/assets/558a2881-ef9f-48ce-985c-710b67716d7a" />

---

## Part 3 — Windows Disk Monitoring and Scheduling

### Step 9: Inspect local disk capacity

```powershell
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
Select-Object DeviceID,
    @{Name="FreeGB"; Expression={[math]::Round($_.FreeSpace / 1GB, 2)}},
    @{Name="TotalGB"; Expression={[math]::Round($_.Size / 1GB, 2)}}
```
<img width="636" height="477" alt="image" src="https://github.com/user-attachments/assets/f22d32cc-86cf-4cb4-b3de-22b16ed90219" />

**Observed result:** Drive `C:` had approximately **86.87 GB free out of 99.39 GB** during the lab.

### Step 10: Create a disk-monitoring script with logging

Save the following as **`C:\Scripts\DiskMonitor.ps1`**:

```powershell
$Disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$FreePercent = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 2)
$Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if ($FreePercent -lt 20) {
    $Message = "$Time WARNING: Disk C has $FreePercent% free space"
    Write-Host $Message -ForegroundColor Red
} else {
    $Message = "$Time HEALTHY: Disk C has $FreePercent% free space"
    Write-Host $Message -ForegroundColor Green
}

Add-Content -Path "C:\Scripts\DiskMonitor.log" -Value $Message
```

Run it:

```powershell
& "C:\Scripts\DiskMonitor.ps1"
```
<img width="673" height="78" alt="image" src="https://github.com/user-attachments/assets/da165b89-dd06-4f1c-88a3-10f83e021001" />

The script calculates the free-space percentage, displays a warning when it falls below 20%, and appends a timestamped entry to `C:\Scripts\DiskMonitor.log`.

### Step 11: Schedule daily disk monitoring

On DC01, open **Task Scheduler** (`taskschd.msc`) and choose **Create Task**.

**General**
- **Name:** `Daily Disk Monitor`
- **Description:** `Automatically monitor disk space on DC01`
- **Account:** `AD\Administrator` (lab account)
- **Run whether user is logged on or not:** Selected
- **Run with highest privileges:** Selected for this lab
<img width="530" height="399" alt="image" src="https://github.com/user-attachments/assets/bc1f2656-7f44-458d-9aa8-e5cedd8b6e84" />

**Triggers**
- **Begin the task:** On a schedule
- **Schedule:** Daily
- **Time:** 10:00 AM
- **Enabled:** Selected
<img width="533" height="188" alt="image" src="https://github.com/user-attachments/assets/6d60c255-b5a0-48d0-8aa3-bb7cf799269e" />

**Actions**
- **Action:** Start a program
- **Program/script:** `powershell.exe`
- **Add arguments:** `-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Scripts\DiskMonitor.ps1"`
- **Start in:** `C:\Scripts`
<img width="530" height="233" alt="image" src="https://github.com/user-attachments/assets/39936841-4392-4498-ad0e-fa9cd31996b8" />

Save the task, run it from Task Scheduler, and inspect the output:

```powershell
Get-Content "C:\Scripts\DiskMonitor.log" -Tail 5
```
<img width="673" height="78" alt="image" src="https://github.com/user-attachments/assets/06e871df-56e6-449b-a64c-a901c47640bf" />  


**Result:** Task Scheduler reported **`0x0` (successful completion)** and the log received a new timestamped disk-status entry. The scheduled task is configured to run every day at 10:00 AM.

> **Operational note:** Production monitoring should use a least-privilege service identity and centralized alerting where appropriate. The scheduled task in this lab is a local training exercise.

---

## Part 4 — Bash Service Monitoring on Ubuntu

### Step 12: Check Linux service status

Open the Ubuntu terminal and run:

```bash
systemctl is-active ssh apache2 smbd
```
<img width="489" height="99" alt="image" src="https://github.com/user-attachments/assets/ee2227ce-7836-4628-885c-28ffe9df5dad" />

The monitored services are:

| Service | Purpose |
| --- | --- |
| `ssh` | Secure remote administration |
| `apache2` | Apache web server |
| `smbd` | Samba file sharing |

### Step 13: Create a Bash monitoring script

Create **`/home/duong/ServiceCheck.sh`**:

```bash
nano ~/ServiceCheck.sh
```

Add:

```bash
#!/bin/bash

services=("ssh" "apache2" "smbd")
logfile="$HOME/ServiceCheck.log"

for service in "${services[@]}"; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if systemctl is-active --quiet "$service"; then
        echo -e "\e[32m$service : RUNNING\e[0m"
        echo "$timestamp $service : RUNNING" >> "$logfile"
    else
        echo -e "\e[31m$service : NOT RUNNING\e[0m"
        echo "$timestamp $service : NOT RUNNING" >> "$logfile"
    fi
done
```
<img width="495" height="303" alt="image" src="https://github.com/user-attachments/assets/59cb6541-e0e9-4c17-a8a8-59b3cee593eb" />

Save and close nano, then make the script executable and run it:

```bash
chmod +x ~/ServiceCheck.sh
~/ServiceCheck.sh
cat ~/ServiceCheck.log
```
<img width="491" height="132" alt="image" src="https://github.com/user-attachments/assets/5c7c88e5-c4bd-493a-afad-71ba7d208503" />

**Result:** SSH, Apache, and Samba were reported as **RUNNING**. The script appended timestamped service statuses to `ServiceCheck.log`.

### Step 14: Schedule service monitoring with cron

Open the current user's crontab:

```bash
crontab -e
```
<img width="742" height="248" alt="image" src="https://github.com/user-attachments/assets/497b30c1-3d9d-4c15-b5e2-7c078a62826a" />

Add the daily schedule:

```cron
0 10 * * * /home/duong/ServiceCheck.sh
```
<img width="739" height="227" alt="image" src="https://github.com/user-attachments/assets/9164e6e1-a858-4a23-9f17-dc54e0a072af" />

This runs the script **every day at 10:00 AM according to Ubuntu's local time zone**.

Confirm the scheduled entry and cron service:

```bash
crontab -l
systemctl is-active cron
```

**Result:** Cron was active and the scheduled monitoring job was saved. During the lab, a temporary every-minute schedule was used to demonstrate unattended execution; the log received new entries automatically. The final schedule was set back to 10:00 AM daily.

---

## Deliverables

| File or configuration | Purpose |
| --- | --- |
| `C:\Scripts\ServiceCheck.ps1` | Check DC01 services |
| `C:\Users\Administrator\NewEmployees.csv` | Input list of new employees |
| `C:\Scripts\Create-ADUsers.ps1` | Create AD users and assign department groups |
| `C:\Users\Administrator\ADUsersReport.csv` | Export AD user inventory |
| `C:\Scripts\DiskMonitor.ps1` | Monitor Windows disk capacity |
| `C:\Scripts\DiskMonitor.log` | Timestamped Windows disk history |
| Task Scheduler: `Daily Disk Monitor` | Run Windows monitoring daily |
| `/home/duong/ServiceCheck.sh` | Monitor Ubuntu services |
| `/home/duong/ServiceCheck.log` | Timestamped Linux service history |
| User crontab entry | Run Ubuntu monitoring daily |

## Final Results

- Created a reusable PowerShell service-check script for DC01.
- Provisioned **10 Active Directory accounts** from a CSV file.
- Assigned **five IT users** and **five HR users** to their corresponding AD security groups.
- Exported an AD report containing **11 accounts** in `AutomationLab`.
- Created a PowerShell disk-monitoring script with a **20% free-space warning threshold**.
- Scheduled Windows monitoring daily with Task Scheduler and confirmed successful execution and logging.
- Created a Bash script to monitor **SSH, Apache, and Samba**.
- Scheduled daily Linux service monitoring with cron and confirmed automatic log entries.

## Skills Demonstrated

**Windows administration:** PowerShell 5.1, service management, system information, Task Scheduler, logging.

**Active Directory:** Organizational units, user provisioning, account enable/disable states, password configuration, group membership, CSV reporting.

**Scripting:** Variables, arrays, loops, conditional statements, reusable `.ps1` and `.sh` files, basic error handling.

**Linux administration:** Bash, `systemctl`, executable permissions, log files, cron scheduling.

**Automation:** Reusable provisioning workflows, scheduled monitoring, operational reporting.

---
