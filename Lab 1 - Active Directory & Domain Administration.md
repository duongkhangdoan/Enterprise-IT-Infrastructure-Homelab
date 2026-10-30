# Windows Server 2022 Active Directory & File Services Home Lab
## 1. Executive Summary

Built a small Windows domain environment using Windows Server 2022 and two Windows 10 workstations. Configured Active Directory Domain Services (AD DS), DNS, DHCP, organizational units (OUs), users, security groups, and domain-joined clients. Extended the lab with SMB file shares and NTFS access controls for separate IT and HR departments. Practiced connectivity testing, domain authentication verification, SMB troubleshooting, and least-privilege access design.

This lab demonstrates foundational skills relevant to IT support, desktop administration, and entry-level infrastructure roles. It is a personal learning project and is **not affiliated with or endorsed by RTX**.

## 2. Objectives

- Deploy and configure a Windows Server 2022 domain controller.
- Create an Active Directory forest/domain and organize directory objects into OUs.
- Provision domain users and security groups for IT and HR.
- Join two Windows 10 clients to the domain and verify domain sign-in.
- Configure internal DNS and DHCP scope options.
- Provide internet access through VirtualBox NAT Network while preserving domain DNS resolution.
- Publish departmental SMB shares with NTFS and share-level permissions.
- Validate authorized access and denied cross-department access.
- Troubleshoot network paths, DNS, SMB connectivity, and permissions using built-in Windows tools.

## 3. Lab Architecture

```text
                   Internet
                      |
             VirtualBox NAT Network
              192.168.10.0/24
              Gateway: 192.168.10.1
                      |
       +--------------+--------------+
       |              |              |
   DC01.ad.lab     CLIENT01       CLIENT02
  192.168.10.10  192.168.10.101  DHCP address
  Windows Server  Windows 10      Windows 10
  2022            AD\jsmith       AD\edavis
  AD DS / DNS     IT user         HR user
  DHCP / SMB
       |
  C:\Shares\IT  -> \\DC01\IT
  C:\Shares\HR  -> \\DC01\HR
```

**Important:** The NAT Network gateway `192.168.10.1` is provided by VirtualBox. DC01 provides the lab's DHCP service at `192.168.10.10`. The NAT Network's own DHCP service should be disabled to prevent competing DHCP servers. The DNS server advertised to domain clients is DC01 (`192.168.10.10`); DC01 can use DNS forwarders for external lookups. The network name shown in VirtualBox may differ from the illustrative diagram.

### Systems and addressing

| Component | Hostname | OS | IP / addressing | Role |
|---|---|---|---|---|
| Domain controller | DC01 | Windows Server 2022 | `192.168.10.10/24` static | AD DS, DNS, DHCP, SMB |
| IT workstation | CLIENT01 | Windows 10 | DHCP; observed `192.168.10.101` | Domain-joined client |
| HR workstation | CLIENT02 | Windows 10 | DHCP | Domain-joined client |
| Default gateway | VirtualBox NAT Network | Virtual router | `192.168.10.1` | Outbound connectivity |

**Domain DNS name:** `ad.lab`  
**NetBIOS domain name:** `AD`
> `.lab` is used here only as a private training namespace. For a real deployment, use a domain naming strategy aligned with an organization-owned DNS domain.

## 4. Technologies and Skills

- Windows Server 2022, Windows 10, Oracle VirtualBox
- Active Directory Domain Services (AD DS), organizational units, user/group administration
- DNS, DHCP, IPv4, TCP/IP, network troubleshooting
- SMB file sharing, NTFS access control lists (ACLs), role-based access
- PowerShell, CMD, Server Manager, Active Directory Users and Computers (ADUC)
- Principle of least privilege, access validation, technical documentation

## 5. Implementation Walkthrough

### Phase A — Build the virtual network and server

1. Created a VirtualBox NAT Network with the lab subnet `192.168.10.0/24` and gateway `192.168.10.1`.
2. Attached the VMs to the same NAT Network. Disabled the VirtualBox NAT Network DHCP service so Windows Server could provide DHCP without conflicts.
3. Installed Windows Server 2022 and renamed the machine **DC01**.
4. Configured the DC01 network adapter:

   ```text
   IPv4 address:   192.168.10.10
   Subnet mask:    255.255.255.0
   Default gateway:192.168.10.1
   Preferred DNS:  192.168.10.10
   ```
<img width="503" height="395" alt="image" src="https://github.com/user-attachments/assets/25dda1c0-b701-4454-b80d-449ee6505cf8" />

5. Verified basic network connectivity using `ipconfig /all` and `ping`.
<img width="617" height="272" alt="image" src="https://github.com/user-attachments/assets/1a756ed4-995e-48c1-b274-4836d355cde1" />

**Design rationale:** A fixed DC address makes DNS and DHCP service discovery predictable. Domain members should query the domain DNS server rather than a public DNS server directly.

### Phase B — Install AD DS and DNS

1. In **Server Manager → Manage → Add Roles and Features**, installed **Active Directory Domain Services** and DNS management components.
2. Promoted DC01 to a domain controller using **Add a new forest**.
3. Entered root domain name `ad.lab` and completed the promotion wizard and reboot.
4. Verified the server was identified as `DC01.ad.lab` and the domain was visible in **Active Directory Users and Computers**.
<img width="663" height="224" alt="image" src="https://github.com/user-attachments/assets/18f51a49-f207-4b68-a82a-cb04bd087835" />

Useful checks:

```powershell
Get-ADDomain
Get-Service NTDS,DNS
Resolve-DnsName dc01.ad.lab
```

> The commands above are repeatable validation commands; screenshots or saved command output should be added as evidence when available.

### Phase C — Design Active Directory organizational structure

Created the following OU structure:

```text
ad.lab
└── RTX-LAB
    ├── IT
    ├── HR
    ├── Computers
    ├── Servers
    └── Groups
```

Created two **Global Security Groups**:

- `GG_IT_Users` — departmental IT users
- `GG_HR_Users` — departmental HR users
<img width="699" height="475" alt="image" src="https://github.com/user-attachments/assets/cec00beb-ee4c-459c-89fd-f383f2be8f20" />

Example lab user assignments:

| User | Department | Security group |
|---|---|---|
| `jsmith` | IT | `GG_IT_Users` |
| `abrown` | IT | `GG_IT_Users` |
| `edavis` | HR | `GG_HR_Users` |
| `swilson` | HR | `GG_HR_Users` |

Created users in their respective departmental OUs and managed group membership through ADUC. These are fictional training accounts; do not publish passwords.
<img width="558" height="744" alt="image" src="https://github.com/user-attachments/assets/7738644e-985a-4b4e-a6da-f1d6ae9f35c2" />

### Phase D — Configure Windows DHCP

1. Installed the **DHCP Server** role on DC01 and completed the required post-install configuration / authorization in AD.
2. Created and activated an IPv4 scope for the `192.168.10.0/24` network. The exact address pool should be recorded from the DHCP console; avoid including static infrastructure addresses in the assignable pool.
3. Configured these scope options:

   | DHCP option | Value | Purpose |
   |---|---|---|
   | `003 Router` | `192.168.10.1` | Default gateway |
   | `006 DNS Servers` | `192.168.10.10` | Internal domain DNS |
   | `015 DNS Domain Name` | `ad.lab` | DNS suffix |
<img width="654" height="302" alt="image" src="https://github.com/user-attachments/assets/a008dfc0-e2d0-483b-9939-79f774c356eb" />

4. Confirmed CLIENT01 received a lease from `192.168.10.10`, including IP `192.168.10.101`, DNS `192.168.10.10`, and gateway `192.168.10.1`.

Validation:

```cmd
ipconfig /all
ipconfig /renew
nslookup dc01.ad.lab
```

### Phase E — Join Windows 10 clients to the domain

1. Installed Windows 10 on CLIENT01 and CLIENT02.
2. Confirmed both clients used the same VirtualBox NAT Network and received DNS settings pointing to DC01.
3. Joined both machines to `ad.lab` using Windows system/domain settings and rebooted.
4. Signed in with domain accounts:
   - CLIENT01: `AD\jsmith`
   - CLIENT02: `AD\edavis`
5. Moved both computer objects from the default **Computers** container to `RTX-LAB\Computers` in ADUC for future GPO targeting.
<img width="601" height="348" alt="image" src="https://github.com/user-attachments/assets/b7852858-96a2-4bcd-8909-4136df9589e5" />


Client verification commands:

```cmd
whoami
hostname
ipconfig /all
nltest /dsgetdc:ad.lab
```

Observed on CLIENT01:

```text
whoami           -> ad\jsmith
hostname         -> CLIENT01
IPv4             -> 192.168.10.101
DHCP Server      -> 192.168.10.10
DNS Servers      -> 192.168.10.10
Default Gateway  -> 192.168.10.1
```
<img width="469" height="758" alt="image" src="https://github.com/user-attachments/assets/675b8e68-b538-4235-ae36-a23869198306" />

Observed on CLIENT02:  
<img width="500" height="444" alt="image" src="https://github.com/user-attachments/assets/c82592b9-bf1a-46e7-9199-42164740ea74" />

### Phase F — Configure departmental NTFS permissions

Created two directories on DC01: 

```text
C:\Shares\IT
C:\Shares\HR
```
<img width="566" height="361" alt="image" src="https://github.com/user-attachments/assets/d8481438-02a2-4c6c-b524-1ab70c59e69f" />


For each departmental directory, disabled inherited ACLs and converted inherited entries to explicit entries before removing overly broad user access. Kept system and administrative access and granted Modify only to the relevant department group.

| Folder | Principal | NTFS permission |
|---|---|---|
| IT | `SYSTEM` | Full Control |
| IT | `Administrators` | Full Control |
| IT | `GG_IT_Users` | Modify |
| HR | `SYSTEM` | Full Control |
| HR | `Administrators` | Full Control |
| HR | `GG_HR_Users` | Modify |
<img width="584" height="670" alt="image" src="https://github.com/user-attachments/assets/ed182404-50ba-4c84-9787-d79f651fec74" />

No explicit **Deny** entry was required for the opposite department; lack of an applicable Allow is sufficient when no other group grants access.

**Troubleshooting lesson:** Initially, permissions were accidentally applied to the parent `C:\Shares` folder. Corrected the parent ACL and configured department-specific ACLs on `C:\Shares\IT` and `C:\Shares\HR` instead. This illustrated the difference between parent-folder inheritance and explicit child-folder permissions.

### Phase G — Publish SMB shares

Used **Server Manager → File and Storage Services → Shares → Tasks → New Share → SMB Share – Quick** to publish:

| Share name | Local path | UNC path |
|---|---|---|
| `IT` | `C:\Shares\IT` | `\\DC01\IT` |
| `HR` | `C:\Shares\HR` | `\\DC01\HR` |

Configured share-level permissions so administrators retain full control and the appropriate department group has **Change** access. Avoided broad Everyone access. Share-level and NTFS permissions are both evaluated; the effective network permission is constrained by both layers.

Validation commands on DC01:

```powershell
Get-SmbShare -Name IT,HR
Get-SmbShareAccess -Name IT
Get-SmbShareAccess -Name HR
```

Observed both `IT` and `HR` in the Server Manager Shares list, alongside the default domain-controller shares `NETLOGON` and `SYSVOL`. Those system shares should not be removed.

### Phase H — Client access testing

Test cases used for departmental access validation:

| Test | User / machine | UNC path | Expected result |
|---|---|---|---|
| 1 | `AD\jsmith` / CLIENT01 | `\\DC01\IT` | Read/write allowed |
| 2 | `AD\jsmith` / CLIENT01 | `\\DC01\HR` | Access denied |
| 3 | `AD\edavis` / CLIENT02 | `\\DC01\HR` | Read/write allowed |
| 4 | `AD\edavis` / CLIENT02 | `\\DC01\IT` | Access denied |

To verify write access, create, edit, and save a small text file in the authorized share. To verify isolation, attempt to list the unauthorized share and record the actual error.

The lab owner reported completing the access tests. Add screenshots of each outcome to make the evidence independently reviewable.
<img width="729" height="806" alt="image" src="https://github.com/user-attachments/assets/b07d2ba6-e1d3-4768-88d3-6a7ce635cc93" />
<img width="741" height="699" alt="image" src="https://github.com/user-attachments/assets/204c125d-5ce3-4627-9e81-b9474128628c" />

## 6. Troubleshooting Case Study — SMB Share Not Opening by Name

**Symptom:** On CLIENT01, entering `\\DC01\IT` in the Run dialog initially returned a Windows network access error.

**Conclusion:** IP reachability and SMB TCP connectivity were working, and an SMB mapping to the share was active. The original Run-dialog issue was not conclusively root-caused from the available evidence; it should not be labeled a confirmed DNS, firewall, or ACL failure. Further diagnostics would include the exact Windows error code, `dir \\DC01\IT`, credential/session checks, and name-resolution comparisons.

**Operational lesson:** Validate one layer at a time—IP, DNS, TCP port, SMB session, then permissions—before making security or network changes.

## 7. Verification Checklist

- [x] Windows Server 2022 installed and configured as DC01
- [x] AD DS domain `ad.lab` created
- [x] DNS and DHCP configured
- [x] Department OUs, users, and security groups created
- [x] CLIENT01 and CLIENT02 domain-joined
- [x] CLIENT01 domain sign-in confirmed with `whoami`
- [x] Departmental folders and NTFS ACLs configured
- [x] IT and HR SMB shares created
- [x] CLIENT01 connectivity to DC01 TCP 445 verified
- [x] CLIENT01 mapped share connection observed
- [x] Lab owner reports end-to-end Lab 1 completed

## 8. Security Considerations and Limitations

- This is a learning environment, not a production architecture.
- DC01 also hosts DHCP and SMB for simplicity. In production, separate roles according to security, resilience, and operational requirements.
- Use separate standard-user accounts for everyday client activity; avoid granting Domain Admin privileges to test users.
- Do not publish passwords, recovery keys, license keys, personal identifiers, or sensitive infrastructure information.
- Use lab-only IPs and fictional users in public documentation.
- Avoid broad share permissions and unnecessary explicit Deny entries.
- Active Directory Certificate Services (AD CS) was **not** installed as part of this lab; it is a possible future extension.
- Group Policy hardening, firewall policy, and Linux domain integration are planned as separate labs, not claims of completion here.

## 10. Key Takeaways

- Learned how AD DS centralizes identity and computer administration.
- Configured DHCP to advertise the internal domain DNS server and correct NAT gateway.
- Practiced domain join, domain-user sign-in, and OU placement.
- Applied role-based access with AD security groups, NTFS ACLs, and SMB share permissions.
- Used `ping`, `nslookup`, `ipconfig`, `whoami`, `Test-NetConnection`, and `net use` for systematic troubleshooting.
- Documented a real configuration mistake involving NTFS inheritance and a separate SMB access issue without overstating its root cause.

## 11. Next Labs

1. **Group Policy & Security:** workstation policies, password/account lockout, firewall, local administrator restrictions, drive mapping.
2. **DNS, DHCP & Network Troubleshooting:** reservations, diagnostics, DNS records, and failure simulations.
3. **Ubuntu Linux Administration:** SSH, permissions, services, firewall, Apache/Samba, and AD integration.
4. **PowerShell & Bash Automation:** user provisioning, inventory, service monitoring, and logging.
5. **IT Help Desk Ticket Simulations:** account lockout, password reset, domain join failures, DNS issues, share access, and service outages.

---

### Resume-ready project description

**Windows Server Active Directory & File Services Home Lab** — Deployed a three-VM Windows domain in Oracle VirtualBox with Windows Server 2022, two Windows 10 clients, AD DS, DNS, DHCP, and departmental SMB shares. Configured OUs, domain users, security groups, domain joins, NTFS/share permissions, and network-drive access. Troubleshot SMB connectivity using PowerShell and Windows networking utilities, documenting validation results and least-privilege access controls.
