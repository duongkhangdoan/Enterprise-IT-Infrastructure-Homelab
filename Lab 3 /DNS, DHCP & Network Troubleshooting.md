## Overview

This hands-on lab demonstrates foundational IT Support and Junior System Administrator skills in a Windows Active Directory environment. I configured and verified DNS and DHCP functionality, diagnosed a simulated DNS outage, tested network service ports, and documented a simulated help desk ticket.

The lab builds on an existing Active Directory domain, `ad.lab`, and uses a Windows Server 2022 domain controller with two domain-joined Windows 10 clients.

## Lab Environment

| Component | Hostname / Setting | Details |
|---|---|---|
| Hypervisor | Oracle VirtualBox | NAT Network: `192.168.10.0/24` |
| Domain / Forest root | `ad.lab` | Active Directory Domain Services |
| Domain Controller | `DC01.ad.lab` | Windows Server 2022; `192.168.10.10`; AD DS, DNS, DHCP, SMB shares |
| Client 1 | `CLIENT01.ad.lab` | Windows 10; DHCP address `192.168.10.101`; user `AD\jsmith` |
| Client 2 | `CLIENT02.ad.lab` | Windows 10; DHCP address `192.168.10.100`; user `AD\edavis` |
| Default gateway | `192.168.10.1` | VirtualBox NAT Network gateway |
| Internal DNS | `192.168.10.10` | DNS hosted on DC01 |
| DHCP server | `192.168.10.10` | DHCP hosted on DC01 |

## Objectives

- Validate client IP configuration and connectivity to the domain controller.
- Understand forward DNS (hostname → IP) and reverse DNS (IP → hostname).
- Create an Active Directory-integrated reverse lookup zone and PTR record.
- Inspect DHCP leases, release and renew a client lease, and configure a reservation.
- Reproduce and resolve a client-side DNS misconfiguration.
- Check TCP connectivity to common Windows and Active Directory service ports.
- Follow an IT Support troubleshooting workflow and write ticket documentation.

## Exercise 1 — Network Baseline & Connectivity

On `CLIENT01`, I reviewed the network configuration and verified reachability to the domain controller and gateway.

```cmd
ipconfig /all
ping 192.168.10.10
ping 192.168.10.1
```
<img width="671" height="471" alt="image" src="https://github.com/user-attachments/assets/36084050-e4fe-450a-aaa8-f8a204de92fa" />

**Observed results:**

- `CLIENT01` obtained `192.168.10.101` via DHCP.
- Subnet mask: `255.255.255.0` (`/24`).
- Gateway: `192.168.10.1`.
- DHCP and DNS server: `192.168.10.10`.
- Pings to DC01 and the gateway succeeded with **0% packet loss**.

**Takeaway:** Successful IP connectivity establishes a baseline but does not guarantee DNS or application services are working.

## Exercise 2 — Forward & Reverse DNS Lookup

### Forward lookup

```cmd
nslookup dc01.ad.lab
```
<img width="489" height="291" alt="image" src="https://github.com/user-attachments/assets/e53a7d17-937b-40c5-805e-72c08ef49c08" />


**Result:** The hostname resolved to `192.168.10.10`, confirming the forward DNS record was available.

### Reverse lookup troubleshooting

An initial reverse lookup did not return the expected hostname:

```cmd
nslookup 192.168.10.10
```

I inspected **DNS Manager → Reverse Lookup Zones** on DC01 and found that the required reverse lookup zone was absent.

**Configuration performed:**

1. Created an **Active Directory-integrated Primary Zone**.
2. Selected replication to **DNS servers running on domain controllers in the `ad.lab` domain**.
3. Created an **IPv4 Reverse Lookup Zone** for network ID `192.168.10`.
4. Selected **Allow only secure dynamic updates**.
5. Created a **PTR record** mapping `192.168.10.10` to `dc01.ad.lab`.
6. Re-tested reverse resolution from CLIENT01; it succeeded.

**Created zone:** `10.168.192.in-addr.arpa`

| DNS direction | Record type | Mapping |
|---|---|---|
| Forward | A | `dc01.ad.lab` → `192.168.10.10` |
| Reverse | PTR | `192.168.10.10` → `dc01.ad.lab` |
<img width="726" height="268" alt="image" src="https://github.com/user-attachments/assets/e27964f8-faec-4afb-a5c4-7c78165b28f2" />

**Takeaway:** Forward and reverse DNS use separate records. Successful forward resolution does not automatically imply a working reverse lookup.

## Exercise 3 — DHCP Lease & Reservation

### Inspecting leases

On CLIENT01:

```cmd
ipconfig /all
```

On DC01, I used **DHCP Manager → IPv4 → Scope → Address Leases** to verify active assignments.

| Client | DHCP-assigned IPv4 address |
|---|---|
| CLIENT01 | `192.168.10.101` |
| CLIENT02 | `192.168.10.100` |

I reviewed lease obtained/expiration times and confirmed that the DHCP server was tracking client leases.
<img width="819" height="798" alt="image" src="https://github.com/user-attachments/assets/415bdc5b-74ae-4190-822a-36a391547fef" />

### Release and renew

On CLIENT01:

```cmd
ipconfig /release
ipconfig /renew
ipconfig /all
ping 192.168.10.10
```

**Result:** CLIENT01 successfully renewed its lease, retained `192.168.10.101`, and could still ping DC01. Receiving the same address after renewal is normal DHCP behavior.

### DHCP reservation

I created a reservation in **DHCP Manager → IPv4 → Scope → Reservations**:

| Field | Value |
|---|---|
| Reservation name | `CLIENT01` |
| Reserved IP | `192.168.10.101` |
| Client MAC / Unique ID | `080027C05C19` |
| Supported types | Both |

I confirmed the reservation's MAC address matched CLIENT01's physical address (`08-00-27-C0-5C-19`) and verified the client continued to receive `192.168.10.101`.  

<img width="568" height="537" alt="image" src="https://github.com/user-attachments/assets/7a10f717-bf31-4ac3-a77b-569238bc0cda" />

**Takeaway:** DHCP reservations associate a predictable address with a specific client identifier. A renewed lease retaining the same IP is supportive evidence, while verifying the reservation entry and matching MAC confirms its configuration.


## Exercise 4 — Simulated DNS Failure & Recovery

### Scenario

A user can reach a server by IP address but cannot resolve its hostname.

### Reproducing the problem

On CLIENT01, I temporarily changed the preferred DNS server from the DHCP-provided internal DNS address to an intentionally nonresponsive lab address:

- **Incorrect DNS:** `192.168.10.250`
- **Correct internal DNS:** `192.168.10.10`

I left the client's IP assignment set to DHCP.

```cmd
ping 192.168.10.10
nslookup dc01.ad.lab
```

**Observed results:**

- Ping to `192.168.10.10`: **successful**.
- `nslookup dc01.ad.lab`: **DNS request timed out**, querying `192.168.10.250`.

### Resolution

I restored **Obtain DNS server address automatically** in the Windows IPv4 adapter settings. The client again received internal DNS `192.168.10.10`, and DNS resolution worked.

**Root cause:** Incorrect client DNS server configuration.

**Takeaway:** Working IP connectivity does not prove that name resolution works. Compare IP-based connectivity with hostname-based DNS queries to isolate the issue.

**Useful diagnostic command:**

```cmd
nslookup dc01.ad.lab 192.168.10.10
```

This explicitly queries DC01's DNS server, regardless of the client's configured default DNS server.

## Exercise 5 — Network Ports & Firewall Troubleshooting

From CLIENT01, I used PowerShell to test TCP connectivity to DC01:

```powershell
Test-NetConnection 192.168.10.10 -Port 445
Test-NetConnection 192.168.10.10 -Port 53
Test-NetConnection 192.168.10.10 -Port 88
Test-NetConnection 192.168.10.10 -Port 389
Test-NetConnection 192.168.10.10 -Port 3389
```

| TCP port | Service | Observed result |
|---|---|---|
| 445 | SMB / file sharing | `TcpTestSucceeded : True` |
| 53 | DNS over TCP | `TcpTestSucceeded : True` |
| 88 | Kerberos over TCP | `TcpTestSucceeded : True` |
| 389 | LDAP over TCP | `TcpTestSucceeded : True` |
| 3389 | Remote Desktop (RDP) | `TcpTestSucceeded : False` |    

<img width="681" height="1350" alt="image" src="https://github.com/user-attachments/assets/d417a657-30b6-4593-9aea-49fb4dc9bb52" />

### Investigating RDP port 3389

The RDP test showed that **ping to DC01 succeeded**, while **TCP port 3389 failed**. I checked **Server Manager → Local Server** on DC01 and confirmed **Remote Desktop was Disabled**.

**Decision:** I did **not** enable RDP just to make the port test pass. On a domain controller, unnecessary remote access should remain disabled unless explicitly required and securely managed.

> `Test-NetConnection -Port` tests **TCP connectivity**, not UDP. DNS and Kerberos also use UDP in relevant scenarios. An open TCP port does not by itself verify successful authentication, authorization, or complete application functionality.

**Takeaway:** A failed port test is not automatically a network outage; the service may be intentionally disabled or filtered by policy.

## Exercise 6 — IT Support Ticket Simulation

### Ticket #1001 — Cannot Access Shared Folder

**User:** John Smith (`AD\jsmith`)  
**Workstation:** `CLIENT01.ad.lab`  
**Server:** `DC01.ad.lab`  
**Affected resource:** `\\DC01\IT`

**Reported issue:** User stated they could not access the IT network share.

### Troubleshooting and verification

1. Reviewed previous network, DNS, and SMB connectivity checks.
2. Opened `\\DC01\IT` successfully while signed in as `AD\jsmith`.
3. Created, edited, and saved `IT-Test.txt` in the IT share.
4. Attempted to open `\\DC01\HR` with the IT user and received **Access is denied**, as expected under the lab's access-control design.
5. Determined that the original access problem could **not be reproduced** during testing.
6. Recorded the results without making unnecessary configuration changes.

### Ticket documentation

**Initial status:** Pending User Confirmation  
**Finding:** Unable to Reproduce (UTR)  
**Root cause:** Not identified  
**Actions taken:** Connectivity and access validation; no configuration changes required  
**Final simulated status:** Resolved, **after the scenario's user confirmed the share was working**

**Example resolution note:**

> Verified network connectivity, DNS resolution, and SMB TCP port 445. Successfully accessed the IT share and created, modified, and saved a test file. Confirmed that the IT account was denied access to the HR share as expected. The reported issue could not be reproduced. No configuration changes were required. User subsequently confirmed access was working; ticket marked Resolved.

**Takeaway:** Do not claim a fix when the issue cannot be reproduced. Document evidence, ask the user to confirm, and close or resolve the ticket according to the organization's workflow.

## Troubleshooting Command Reference

| Command | Purpose |
|---|---|
| `ipconfig /all` | Inspect client IP, gateway, DNS, DHCP, and lease information |
| `ping 192.168.10.10` | Test ICMP reachability to DC01 |
| `nslookup dc01.ad.lab` | Test forward DNS resolution |
| `nslookup 192.168.10.10` | Test reverse DNS resolution |
| `nslookup dc01.ad.lab 192.168.10.10` | Query a specific DNS server |
| `ipconfig /release` | Release a DHCP-assigned IPv4 address |
| `ipconfig /renew` | Request a DHCP lease |
| `Test-NetConnection 192.168.10.10 -Port 445` | Test TCP connectivity to SMB |

## Skills Demonstrated

- Windows Server 2022 administration
- Active Directory-integrated DNS management
- Forward and reverse DNS troubleshooting (A/PTR records)
- DHCP lease analysis, renewal, and reservation
- Windows 10 TCP/IP adapter configuration
- Network connectivity and TCP service-port diagnostics
- SMB share access and NTFS permission verification
- Root-cause analysis and controlled troubleshooting
- Help desk ticket documentation and user confirmation workflow
- Security-minded administration: leaving unneeded RDP access disabled

## Outcome

**Lab 3 completed.** I validated the lab network, corrected reverse DNS configuration, verified DHCP behavior and a client reservation, reproduced and resolved a DNS client misconfiguration, investigated expected service-port behavior, and documented an IT Support ticket from initial report through simulated user confirmation.


