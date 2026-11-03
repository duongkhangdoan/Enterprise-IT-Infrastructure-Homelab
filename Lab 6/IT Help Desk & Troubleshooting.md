## Overview

This hands-on lab documents six help desk scenarios completed in a VirtualBox environment. The exercises focused on identifying symptoms, validating the cause, applying a controlled fix, and verifying the outcome. Only the intended, successful troubleshooting workflow is documented; incidental command-entry and authentication mistakes are omitted.

> **Lab safety:** All disruptions below were simulated in isolated virtual machines. Do not deliberately change DNS, routes, user lockouts, or service states on production systems without authorization and a rollback plan.

## Environment

| Component | Configuration |
|---|---|
| Hypervisor | Oracle VirtualBox |
| Domain | `ad.lab` |
| Domain controller / DNS | Windows Server 2022, `DC01.ad.lab`, `192.168.10.10` |
| Windows clients | Windows 10 `CLIENT01` and `CLIENT02` |
| CLIENT02 | `192.168.10.100` during testing |
| Ubuntu server | Ubuntu Server 22.04, `192.168.10.102` |
| Lab subnet | `192.168.10.0/24` |
| Default gateway | `192.168.10.1` |
| File shares | `\\DC01\IT`, `\\DC01\HR` |
| Test users | `ad\jsmith`, `ad\edavis` |
| Department groups | `AD\GG_IT_Users`, `AD\GG_HR_Users` |

DC01 also had a separate `192.168.56.103` adapter for host access. This is distinct from the primary lab network.

---

## Ticket #1001 — Active Directory Account Lockout

### Scenario
A domain user, John Smith (`jsmith`), cannot sign in because Windows reports that the account is locked out.

### Investigation and resolution

1. On DC01, review the configured domain account policy:

   ```powershell
   gpupdate /force
   net accounts /domain
   ```
<img width="645" height="222" alt="image" src="https://github.com/user-attachments/assets/618d4648-49a0-4da4-8747-5382a86cf427" />

   Observed settings included a **lockout threshold of 3 attempts**, **15-minute lockout duration**, and **15-minute observation window**. The policy also showed a minimum password length of 7, password history of 24, and maximum password age of 42 days.

2. Reproduce the lockout in the test environment and confirm the user account status:

   ```powershell
   Get-ADUser -Identity jsmith -Properties LockedOut |
       Select-Object Name,SamAccountName,LockedOut
   ```

   Observed result:

   ```text
   Name        SamAccountName  LockedOut
   John Smith  jsmith          True
   ```

3. On DC01, open **Event Viewer → Windows Logs → Security** and inspect **Event ID 4740** (*A user account was locked out*).

   The event identified:

   ```text
   Account That Was Locked Out: jsmith
   Caller Computer Name: CLIENT01
   Computer: DC01.ad.lab
   Event ID: 4740
   ```
<img width="419" height="291" alt="image" src="https://github.com/user-attachments/assets/69e15f7b-886d-4dd2-a9df-f428743a8c52" />
<img width="486" height="135" alt="image" src="https://github.com/user-attachments/assets/8e0bbb7e-38f0-46d6-98fa-66d96f90aa18" />

   This identifies the computer associated with the lockout event, not necessarily the exact application or process that submitted the credentials.

4. After confirming the simulated incident, unlock the account in **Active Directory Users and Computers** (or with an authorized administrative command):

   ```powershell
   Unlock-ADAccount -Identity jsmith
   Get-ADUser -Identity jsmith -Properties LockedOut |
       Select-Object Name,LockedOut
   ```
<img width="486" height="133" alt="image" src="https://github.com/user-attachments/assets/11e5eadd-4e99-44c4-b1c2-45a475384666" />

### Outcome
Confirmed a locked-out AD account and traced the event to `CLIENT01` using Security Event ID 4740. The lab then proceeded to account recovery.

### Evidence to capture
- Windows sign-in lockout message
- `Get-ADUser` output showing `LockedOut = True`
- Event Viewer 4740 showing `jsmith` and `CLIENT01`
<img width="403" height="409" alt="image" src="https://github.com/user-attachments/assets/8dc16790-3766-426f-afe6-de1f5ce24877" />

---

## Ticket #1002 — Password Reset and Security Auditing

### Scenario
A domain user's password must be reset and the password-management activity audited.

### Investigation and resolution

1. Open **Active Directory Users and Computers** on DC01, locate `jsmith`, and select **Reset Password**.
2. Set a temporary password compliant with domain policy and select **User must change password at next logon**. Do not record real passwords in the repository.
3. Confirm the account is not configured to block password changes or prevent password expiry:

   ```powershell
   Get-ADUser jsmith -Properties PasswordNeverExpires,CannotChangePassword |
       Select-Object Name,PasswordNeverExpires,CannotChangePassword
   ```
<img width="665" height="129" alt="image" src="https://github.com/user-attachments/assets/1656e021-6860-4b42-b4e8-79ffe28db9f4" />

   The observed output for both attributes was `False`.

4. Test the password-change workflow from the Windows client and inspect the DC01 Security log. The observed events were:

   | Event ID | Meaning | Observed actor |
   |---|---|---|
   | 4724 | Attempt to reset an account's password | `Administrator` |
   | 4723 | Attempt to change an account's password | `jsmith` |

   Event 4723 and 4724 describe **attempts**; the event details and associated audit result must be checked before inferring success from an event ID alone.
   
<img width="514" height="470" alt="image" src="https://github.com/user-attachments/assets/7e0c8f8c-0dcc-4311-b4dd-29e392a5ebab" />  
<img width="511" height="385" alt="image" src="https://github.com/user-attachments/assets/299e1a9b-1e0b-4575-8154-25f2fe49805b" />


### Outcome
Performed the AD password reset workflow and inspected the relevant Windows Security audit events to distinguish an administrator reset from a user's own password change.

### Evidence to capture
- ADUC reset dialog (without password contents)
- `Get-ADUser` account flags
- Security events 4723 and 4724

---

## Ticket #1003 — DNS Misconfiguration / Domain Controller Discovery

### Scenario
A domain-joined Windows client cannot locate `ad.lab`'s domain controller because its DNS configuration points to a public resolver.

### Baseline
On CLIENT02, the internal DNS server is `192.168.10.10` (DC01). The DC is discoverable when the client uses the internal DNS service.

### Reproduce the issue

1. In **elevated PowerShell on CLIENT02**, temporarily set the Ethernet adapter's DNS server to Google DNS:

   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "8.8.8.8"
   Get-DnsClientServerAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4
   ```
<img width="506" height="139" alt="image" src="https://github.com/user-attachments/assets/86d6a2e5-f354-44e1-851b-863c813ddc8c" />

   Observed DNS server: `{8.8.8.8}`.

2. Clear the client resolver cache and test internal DNS resolution:

   ```powershell
   ipconfig /flushdns
   nslookup dc01.ad.lab
   ```

   Observed failure:

   ```text
   Server: dns.google
   Address: 8.8.8.8
   *** dns.google can't find dc01.ad.lab: Non-existent domain
   ```

3. Force a fresh domain controller discovery:

   ```powershell
   nltest /dsgetdc:ad.lab /force
   ```

   Observed failure:

   ```text
   Getting DC name failed: Status = 1355 0x54b ERROR_NO_SUCH_DOMAIN
   ```
<img width="503" height="76" alt="image" src="https://github.com/user-attachments/assets/2ba1df90-9122-4e3a-b78c-7cc6a9be6d8d" />

### Restore and verify

4. Restore the internal DNS server:

   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "192.168.10.10"
   ipconfig /flushdns
   nslookup dc01.ad.lab
   nltest /dsgetdc:ad.lab /force
   ```
<img width="534" height="133" alt="image" src="https://github.com/user-attachments/assets/b463782e-c0a8-4f5a-a5e8-7e1885ca4500" />

5. `nslookup` returned `dc01.ad.lab` with `192.168.10.10` and also `192.168.56.103` (the DC's separate host-access adapter). The `nltest` result confirmed:

   ```text
   DC: \\DC01.ad.lab
   Address: \\192.168.10.10
   Dom Name: ad.lab
   The command completed successfully
   ```
<img width="565" height="140" alt="image" src="https://github.com/user-attachments/assets/cf284c91-0701-4765-bf23-5b9b3f72403c" />    

<img width="565" height="116" alt="image" src="https://github.com/user-attachments/assets/ba4dd505-0f9b-44e7-b962-caeae79ae5ae" />


### Root cause and outcome
**Root cause:** CLIENT02 was configured to query public DNS rather than the AD-integrated internal DNS service. Restoring `192.168.10.10` resolved internal names and restored DC discovery. No domain unjoin/rejoin was necessary.

### Evidence to capture
- DNS adapter setting showing `8.8.8.8`
- `nslookup` failure and `nltest` Error 1355
- Corrected DNS setting and successful `nltest`

---

## Ticket #1004 — External DNS Resolution and Default Gateway Troubleshooting

This ticket involved two separate network issues: an incorrect DNS forwarder on DC01 and a missing default route on CLIENT02.

### Part A — DNS forwarder troubleshooting

**Symptom:** On CLIENT02, `nslookup google.com` using DC01 (`192.168.10.10`) timed out, while a direct query to `8.8.8.8` succeeded.

1. From CLIENT02, compare DNS behavior:

   ```powershell
   nslookup google.com
   nslookup google.com 8.8.8.8
   ```

   The public DNS query successfully returned addresses for `google.com`, including `142.251.41.174` at the time of testing.

2. On DC01, inspect the forwarder:

   ```powershell
   nslookup google.com
   Get-DnsServerForwarder
   ```

   The forwarder configuration displayed **`168.168.10.1`**, which differed from the intended lab gateway **`192.168.10.1`**. DC01's own lookup eventually succeeded, so the evidence showed delayed/inconsistent external resolution rather than total loss of DNS capability.

3. Correct the configured forwarder to the intended address:

   ```powershell
   Set-DnsServerForwarder -IPAddress 192.168.10.1
   Get-DnsServerForwarder
   ```

   **Important:** A gateway is a suitable DNS forwarder only if it actually provides DNS service. This lab's follow-up client query succeeded; do not assume every gateway can act as a DNS resolver.

4. On CLIENT02, verify:

   ```powershell
   ipconfig /flushdns
   nslookup google.com
   ```

   Observed result: `Server: DC01.ad.lab`, `Address: 192.168.10.10`, and a successful non-authoritative answer for `google.com` without the earlier timeout.

**Outcome:** External DNS resolution through the internal DNS server worked after the forwarder correction.

### Part B — Missing default gateway route

**Scenario:** A workstation can communicate with servers on the local subnet but cannot reach off-subnet destinations.

1. Verify the baseline on CLIENT02:

   ```powershell
   Get-NetIPConfiguration
   route print -4
   ```

   Observed:

   ```text
   IPv4Address        : 192.168.10.100
   IPv4DefaultGateway : 192.168.10.1
   DNSServer          : 192.168.10.10
   ```

2. In elevated PowerShell **inside the CLIENT02 VirtualBox console**, remove the default route to simulate a routing issue:

   ```powershell
   Remove-NetRoute -InterfaceAlias "Ethernet" -DestinationPrefix "0.0.0.0/0" -Confirm:$false
   route print -4
   ```

   The routing table no longer contained a `0.0.0.0/0` route through `192.168.10.1`.
<img width="502" height="313" alt="image" src="https://github.com/user-attachments/assets/5e228d6b-9614-4f6f-83ac-50c5e5da619f" />

3. Compare local versus external reachability:

   ```powershell
   ping 192.168.10.10
   ping 8.8.8.8
   tracert -d 8.8.8.8
   ```

   Observed:

   | Test | Result |
   |---|---|
   | `ping 192.168.10.10` | 4 replies, 0% packet loss |
   | `ping 8.8.8.8` | `PING: transmit failed. General failure.`; 100% packet loss |
   | `tracert -d 8.8.8.8` | `Transmit error: code 1231` |
<img width="486" height="454" alt="image" src="https://github.com/user-attachments/assets/81259f18-1abb-469c-ac68-885ded2082f3" />

   Because DC01 is on the same `/24` subnet, local traffic can use an on-link route. External destinations need an appropriate route, normally the default gateway.

4. Restore DHCP-provided network settings:

   ```powershell
   ipconfig /renew
   route print -4
   ```

   Observed restored route:

   ```text
   Network Destination  Netmask    Gateway       Interface
   0.0.0.0              0.0.0.0    192.168.10.1  192.168.10.100
   ```

5. Recommended final validation:

   ```powershell
   ping 8.8.8.8
   nslookup google.com
   ```

   **Evidence note:** The restored routing table is documented in the screenshots. The final post-restoration ping result was not separately captured in the conversation, so this README does not claim it was observed.

### Root cause and outcome
**Root cause:** The lab deliberately removed CLIENT02's IPv4 default route. DHCP renewal restored the route through `192.168.10.1`. Local connectivity remained available during the simulated outage.
<img width="468" height="604" alt="image" src="https://github.com/user-attachments/assets/80de16ae-3668-4061-b541-b3129143a50b" />

### Evidence to capture
- Forwarder configuration before correction
- Successful `nslookup google.com` through DC01
- Routing table without the default route
- Local ping success / external ping failure / traceroute error
- Routing table after DHCP renewal

---

## Ticket #1005 — Shared Folder Access Denied / Least Privilege

### Scenario
User `AD\edavis` can access the HR department share but receives **Access Denied** for the IT share. Determine whether this is a defect or an intended access restriction.

### Investigation

1. On CLIENT02, test TCP connectivity to SMB using the DC's IP:

   ```powershell
   Test-NetConnection 192.168.10.10 -Port 445
   ```
<img width="538" height="212" alt="image" src="https://github.com/user-attachments/assets/5d7fbad7-dc9d-417b-8316-d43897910d55" />

   Observed:

   ```text
   SourceAddress    : 192.168.10.100
   RemoteAddress   : 192.168.10.10
   RemotePort      : 445
   TcpTestSucceeded: True
   ```

2. While signed in as `AD\edavis`, test both shares in File Explorer:

   ```text
   \\192.168.10.10\IT  → Access Denied
   \\192.168.10.10\HR  → Access Granted
   ```
<img width="680" height="221" alt="image" src="https://github.com/user-attachments/assets/5fb62237-db8d-42e2-8b7a-c8b124078909" />

   The IP was used to isolate SMB authorization from any potential short-hostname resolution issue.

3. On DC01, inspect SMB share permissions:

   ```powershell
   Get-SmbShareAccess -Name "IT"
   Get-SmbShareAccess -Name "HR"
   ```

   Observed:

   | Share | Principal | Share right |
   |---|---|---|
   | IT | `BUILTIN\Administrators` | Full |
   | IT | `AD\GG_IT_Users` | Change |
   | HR | `BUILTIN\Administrators` | Full |
   | HR | `AD\GG_HR_Users` | Change |

4. Inspect the user's AD group membership:

   ```powershell
   Get-ADPrincipalGroupMembership edavis | Select-Object Name
   ```

   Observed groups: `Domain Users` and `GG_HR_Users`. `GG_IT_Users` was not listed.

5. Inspect NTFS access control entries on both share directories:

   ```powershell
   (Get-Acl (Get-SmbShare -Name IT).Path).Access |
       Format-Table IdentityReference,FileSystemRights,AccessControlType,IsInherited -AutoSize

   (Get-Acl (Get-SmbShare -Name HR).Path).Access |
       Format-Table IdentityReference,FileSystemRights,AccessControlType,IsInherited -AutoSize
   ```
<img width="589" height="398" alt="image" src="https://github.com/user-attachments/assets/8b1a353e-98b7-4908-9521-d8723ad41287" />
<img width="589" height="287" alt="image" src="https://github.com/user-attachments/assets/b3fe59bd-85c0-4935-b52c-e9986afb4c40" />

   Observed NTFS entries:

   | Directory | Principal | NTFS rights | Inherited |
   |---|---|---|---|
   | IT | `NT AUTHORITY\SYSTEM` | FullControl | False |
   | IT | `BUILTIN\Administrators` | FullControl | False |
   | IT | `AD\GG_IT_Users` | Modify, Synchronize | False |
   | HR | `NT AUTHORITY\SYSTEM` | FullControl | False |
   | HR | `BUILTIN\Administrators` | FullControl | False |
   | HR | `AD\GG_HR_Users` | Modify, Synchronize | False |

### Root cause and outcome
**Finding:** This was **expected authorization behavior**, not a broken file server. The user belonged to the HR group and was not granted IT access through the configured share and NTFS ACLs. No permissions were changed. This demonstrated **role-based access control (RBAC)** and **least privilege**.

### Evidence to capture
- TCP 445 connectivity success
- Share access test for IT and HR
- `Get-SmbShareAccess` outputs
- `Get-ADPrincipalGroupMembership` output
- NTFS ACL outputs for both directories

---

## Ticket #1006 — Apache Service Outage on Ubuntu

### Scenario
Employees cannot open an internal website hosted on the Ubuntu server at `http://192.168.10.102`.

### Baseline

1. On Ubuntu, check the Apache service:

   ```bash
   sudo systemctl status apache2
   ```
<img width="608" height="285" alt="image" src="https://github.com/user-attachments/assets/03664d49-eb1d-4812-8e32-debaa44798a4" />

   Observed before the simulation: `active (running)` and `enabled`.

### Reproduce the outage

2. Stop Apache intentionally:

   ```bash
   sudo systemctl stop apache2
   ```

3. Test HTTP locally:

   ```bash
   curl -I http://localhost
   ```

   Observed:

   ```text
   curl: (7) Failed to connect to localhost port 80 ... Could not connect to server
   ```
<img width="606" height="48" alt="image" src="https://github.com/user-attachments/assets/40e23dba-b690-463c-a437-3c5988141840" />

### Investigate the cause

4. Inspect service logs:

   ```bash
   sudo journalctl -u apache2 -n 20 --no-pager
   ```
<img width="523" height="289" alt="image" src="https://github.com/user-attachments/assets/e51e8285-b3a4-461e-b6c6-be5694642727" />

   Observed log entries:

   ```text
   Nov 02 17:53:01 Stopping apache2.service...
   Nov 02 17:53:01 apache2.service: Deactivated successfully.
   Nov 02 17:53:01 Stopped apache2.service...
   ```

   These entries show an orderly service stop, not evidence of an Apache crash. They do not by themselves identify who initiated the stop.

5. Optional port check:

   ```bash
   sudo ss -tlnp | grep ':80 '
   ```

### Restore and verify

6. Start Apache:

   ```bash
   sudo systemctl start apache2
   sudo systemctl status apache2
   curl -I http://localhost
   ```
<img width="602" height="129" alt="image" src="https://github.com/user-attachments/assets/74db973b-585c-4783-874c-615ac3aae01c" />

7. On Windows CLIENT02, browse to:

   ```text
   http://192.168.10.102
   ```

   **Observed:** The browser displayed the **Apache2 Ubuntu Default Page — “It works!”**. This is direct evidence that the Windows client reached the Ubuntu web server over HTTP after service restoration.

### Root cause and outcome
**Root cause:** Apache2 was deliberately stopped during the simulation. Starting the service restored web access, verified from another VM.

### Evidence to capture
- Apache `active (running)` baseline
- Failed `curl` while service was stopped
- `journalctl` showing orderly stop
- Apache default page loaded in CLIENT02 browser
- 
<img width="594" height="439" alt="image" src="https://github.com/user-attachments/assets/94867762-b7b2-4a1f-8346-3093a624c103" />
<img width="595" height="302" alt="image" src="https://github.com/user-attachments/assets/af6e627a-be85-4ffa-826c-1e6de51fc4db" />

---

## Troubleshooting Methodology

The same process was used across tickets:

1. **Identify the symptom** — collect the exact error or observed behavior.
2. **Establish a baseline** — check known-good IPs, routes, accounts, services, and permissions.
3. **Isolate the layer** — distinguish DNS, routing, TCP/SMB, authorization, and service availability.
4. **Inspect evidence** — use Event Viewer, PowerShell, routing tables, and Linux journals.
5. **Apply the smallest safe change** — restore only the incorrect setting or stopped service.
6. **Verify the result** — repeat the failing test and document the observed outcome.
7. **Record the ticket** — distinguish a real fault from expected security behavior.

## Command Reference

| Command | Use |
|---|---|
| `net accounts /domain` | Review domain account policy |
| `Get-ADUser` | Inspect account status and flags |
| `Unlock-ADAccount` | Unlock a domain user after investigation |
| Event Viewer (4740 / 4723 / 4724) | Audit lockouts and password operations |
| `Get-DnsClientServerAddress` | Inspect client DNS settings |
| `Set-DnsClientServerAddress` | Set client DNS servers |
| `nslookup` | Test DNS resolution |
| `nltest /dsgetdc:ad.lab /force` | Force domain controller discovery |
| `Get-DnsServerForwarder` | Inspect DNS forwarder configuration |
| `Set-DnsServerForwarder` | Update DNS forwarders |
| `ipconfig /flushdns` | Clear DNS resolver cache |
| `ipconfig /renew` | Renew DHCP settings |
| `route print -4` | Inspect IPv4 routing table |
| `Remove-NetRoute` | Remove a route in the controlled simulation |
| `ping` / `tracert` | Diagnose reachability and routing |
| `Test-NetConnection -Port 445` | Test SMB TCP connectivity |
| `Get-SmbShareAccess` | Review share-level permissions |
| `Get-ADPrincipalGroupMembership` | Review AD group membership |
| `Get-Acl` | Inspect NTFS permissions |
| `systemctl` | Check, stop, and start Linux services |
| `journalctl` | Review Linux service logs |
| `curl -I` | Check HTTP response headers |

## Skills Demonstrated

- Active Directory account administration and security auditing
- Windows authentication and account recovery
- Internal DNS and domain controller discovery troubleshooting
- DNS forwarding, DHCP, and IPv4 routing diagnostics
- TCP/SMB connectivity testing
- SMB share and NTFS ACL inspection
- Role-based access control and least privilege
- Ubuntu service administration, HTTP checks, and log investigation
- Evidence-based help desk ticket documentation
- 
## Conclusion  

Completed six hands-on help desk scenarios across Windows Server, Windows clients, and Ubuntu. The lab demonstrated account lockout analysis, password auditing, DNS recovery, routing troubleshooting, file share access control validation, and Linux web service restoration. The work emphasized isolating root causes, making minimal corrective changes, and validating outcomes with command output and event logs.
