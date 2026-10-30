## Project Overview

This home lab demonstrates centralized Windows user configuration and endpoint restrictions using **Group Policy Objects (GPOs)** in a Windows Server 2022 Active Directory domain. I deployed a corporate desktop wallpaper from an SMB share, configured a password-protected screen saver with a 10-minute timeout, restricted access to administrative utilities, and validated policy application on domain-joined Windows 10 clients using `gpresult` and an HTML Resultant Set of Policy (RSoP) report.

This is **Lab 02** in my Windows Infrastructure / System Administration home-lab series, building on Lab 01 (Active Directory, DNS, DHCP, domain join, and SMB file shares).

> **Scope:** An isolated VirtualBox training environment, not a production deployment. IP addresses, account names, and domain names below are lab-only examples.

## Objectives

1. Create and manage GPOs through Group Policy Management Console (GPMC).
2. Understand **User Configuration** and why GPO links must target OUs containing the relevant user accounts.
3. Deploy a desktop wallpaper from a centrally managed, read-only SMB share.
4. Configure a 600-second screen saver timeout and require credentials on resume.
5. Restrict Control Panel, Windows Settings, and Task Manager access for selected lab users.
6. Refresh and validate applied GPOs with `gpupdate` and `gpresult`.
7. Produce evidence suitable for troubleshooting documentation and a GitHub portfolio.

## Lab Topology

```text
                       Oracle VirtualBox NAT Network
                              192.168.10.0/24
                                     |
                           DC01 — 192.168.10.10
                           Windows Server 2022
                         AD DS / DNS / DHCP / GPMC
                              Domain: ad.lab
                                     |
                    +----------------+----------------+
                    |                                 |
            CLIENT01 — Windows 10              CLIENT02 — Windows 10
            AD\jsmith (IT OU)                  AD\edavis (HR OU)
            192.168.10.101                     DHCP-assigned address
```

### Active Directory OU Layout

```text
ad.lab
└── RTX-LAB
    ├── IT                 # AD\jsmith
    ├── HR                 # AD\edavis
    ├── Computers          # Domain-joined client computer objects
    ├── Groups
    └── Servers
```

**Key design decision:** The three policies in this lab are under **User Configuration**. I linked them to the **IT** and **HR** user OUs, rather than assuming that linking to the **Computers** OU would apply user policies. The same GPO can be linked to multiple OUs without duplicating it.

## Technologies & Tools

| Component | Purpose |
|---|---|
| Windows Server 2022 (DC01) | Active Directory Domain Controller and policy administration |
| Windows 10 (CLIENT01, CLIENT02) | Domain-joined endpoints for policy testing |
| Active Directory Domain Services | Domain identities and OU targeting |
| Group Policy Management Console (GPMC) | Create, edit, and link GPOs |
| SMB file sharing | Host the centralized wallpaper image |
| NTFS and SMB permissions | Grant read access without allowing users to modify the wallpaper |
| `gpupdate` / `gpresult` | Refresh and inspect effective policies |
| VirtualBox NAT Network | Isolated network connectivity between lab VMs |

## Implementation

### Exercise 1 — Deploy a Corporate Desktop Wallpaper

**Goal:** Apply the same desktop wallpaper automatically when domain users in the IT and HR OUs sign in.

**A. Create the GPO**

1. On DC01, open **Server Manager → Tools → Group Policy Management**.
2. Navigate to **Forest: ad.lab → Domains → ad.lab → Group Policy Objects**.
3. Right-click **Group Policy Objects → New**.
4. Name the object `GPO-Desktop-Wallpaper`; leave **Source Starter GPO** as `(none)`.
<img width="619" height="369" alt="image" src="https://github.com/user-attachments/assets/30d75d01-ef09-4cab-ae79-2359fde66450" />

**B. Prepare the central wallpaper file**

1. Create `C:\Wallpapers` on DC01.
2. Copy a JPEG into the folder and name it `company.jpg`.
3. Open **Properties → Sharing → Advanced Sharing** and share the folder as `Wallpapers`.
4. Configure **SMB share permissions** for read access. In this lab, `Everyone` was granted **Read** only (no Change/Full Control).
5. Check **Properties → Security** (NTFS). The existing `AD\Users` entry had **Read & execute**, **List folder contents**, and **Read**; administrators and SYSTEM retained administrative permissions.
6. From CLIENT01, confirm that `\\DC01\Wallpapers` can be opened and `company.jpg` is readable.
<img width="490" height="148" alt="image" src="https://github.com/user-attachments/assets/5ec98ac2-7678-4f7f-8dce-4c3a971286f1" />

**Security note:** Effective SMB access is constrained by both share and NTFS permissions. A read-only share is not sufficient if the NTFS ACL denies access, and a permissive NTFS ACL does not override a restrictive share ACL. In production, a dedicated domain group is preferable to broad `Everyone` share access.

**C. Configure the wallpaper policy**

Open `GPO-Desktop-Wallpaper → Edit` and navigate to:

```text
User Configuration
└── Policies
    └── Administrative Templates
        └── Desktop
            └── Desktop
                └── Desktop Wallpaper
```

Configure:

| Setting | Value |
|---|---|
| Desktop Wallpaper | Enabled |
| Wallpaper Name | `\\DC01\Wallpapers\company.jpg` |
| Wallpaper Style | Stretch (or an appropriate available option) |

<img width="578" height="474" alt="image" src="https://github.com/user-attachments/assets/be89ea3e-523a-44e3-bc15-e811412d1656" />
<img width="549" height="347" alt="image" src="https://github.com/user-attachments/assets/6c8bcb1b-1980-4afa-96e0-3be8d4144de0" />


**Important:** The wallpaper path must be a network-accessible UNC path. `C:\Wallpapers\company.jpg` would refer to the *client's* C: drive when the policy is processed, not DC01's local C: drive.


**D. Link and test**

- Right-click **RTX-LAB → IT → Link an Existing GPO** and select `GPO-Desktop-Wallpaper`.
- Repeat for **RTX-LAB → HR**.
- On the clients, refresh policy and sign out/sign in if necessary.
- **Observed:** The wallpaper changed successfully after deployment.
<img width="695" height="375" alt="image" src="https://github.com/user-attachments/assets/12c5b262-1f98-4c06-9bb8-06db205a85ce" />
<img width="694" height="414" alt="image" src="https://github.com/user-attachments/assets/a28e4330-ae88-461a-bd72-8db5ed01d525" />

<img width="754" height="509" alt="image" src="https://github.com/user-attachments/assets/ba8c6ba6-e0bb-451c-914e-6354f406ae30" />

### Exercise 2 — Configure Screen Saver Timeout and Password Protection

**Goal:** Configure a screen saver to activate after **600 seconds (10 minutes)** of inactivity and require a password on resume.

1. Create `GPO-Screen-Lock` under **Group Policy Objects**.
2. Edit the GPO at:

```text
User Configuration
└── Policies
    └── Administrative Templates
        └── Control Panel
            └── Personalization
```
<img width="766" height="279" alt="image" src="https://github.com/user-attachments/assets/f32925a5-c8fe-4549-8810-ef0a431c5e6f" />

3. Configure the following settings:

| Policy | Configuration |
|---|---|
| Enable screen saver | Enabled |
| Screen saver timeout | Enabled — `600` seconds |
| Password protect the screen saver | Enabled |
<img width="801" height="458" alt="image" src="https://github.com/user-attachments/assets/982c5531-69d5-4e51-8049-850db10d518f" />
<img width="793" height="403" alt="image" src="https://github.com/user-attachments/assets/5d0cd500-9f70-4e00-b2dc-7c2eddadda14" />
<img width="803" height="321" alt="image" src="https://github.com/user-attachments/assets/7693e87e-231e-4f49-b5dc-3b65ef1e6489" />

4. Link `GPO-Screen-Lock` to both **IT** and **HR** OUs.  
<img width="800" height="295" alt="image" src="https://github.com/user-attachments/assets/fc15019c-ff0d-422a-a535-3b96c7b30073" />


5. On CLIENT01, run `gpupdate /force` followed by `gpresult /r /scope user`.

**Observed:** `GPO-Screen-Lock` appeared under **Applied Group Policy Objects** on CLIENT01 and in the CLIENT02 HTML report.

**Validation limitation:** A GPO appearing in RSoP verifies that the GPO was applied; it does **not** by itself prove that the workstation actually locked after 10 minutes. The end-to-end idle timeout and password prompt were **not independently documented as verified** in this project. Some Windows configurations may also require a configured screen saver, such as the **Force specific screen saver** policy, to ensure activation. This should be tested before claiming complete behavioral enforcement.

### Exercise 3 — Restrict Control Panel, Settings, and Task Manager

**Goal:** Demonstrate how user-scoped policies can restrict access to administrative tools.

1. Create `GPO-User-Restrictions`.
<img width="760" height="336" alt="image" src="https://github.com/user-attachments/assets/37b7caf1-2d06-4159-b104-41a6a7b5ba2a" />

2. Edit the first setting at:

```text
User Configuration
└── Policies
    └── Administrative Templates
        └── Control Panel
            └── Prohibit access to Control Panel and PC settings
```
<img width="760" height="336" alt="image" src="https://github.com/user-attachments/assets/bbf5f796-df32-4f64-8d86-f7e5686a2dde" />

Set **Prohibit access to Control Panel and PC settings** to **Enabled**.

3. Edit the second setting at:

```text
User Configuration
└── Policies
    └── Administrative Templates
        └── System
            └── Ctrl+Alt+Del Options
                └── Remove Task Manager
```

Set **Remove Task Manager** to **Enabled**.
<img width="788" height="411" alt="image" src="https://github.com/user-attachments/assets/e143f953-120f-494e-95e1-0a0271d40082" />

4. Link `GPO-User-Restrictions` to both **IT** and **HR** OUs.
<img width="786" height="322" alt="image" src="https://github.com/user-attachments/assets/0979b220-ce58-4a1d-84f2-b828c4c4f8db" />

5. Refresh Group Policy on both clients.
6. Test opening Control Panel (`control`), Windows Settings (`Win + I`), and Task Manager (`Ctrl + Shift + Esc`, or right-click the taskbar).

**Observed:** On CLIENT01, Task Manager displayed the message **“Task Manager has been disabled by your administrator.”** Control Panel and Settings restrictions were reported working on CLIENT02. The user also confirmed completion of CLIENT02 policy testing.

**Production consideration:** Restricting Task Manager can impede legitimate help desk and IT troubleshooting. For a real organization, scope these restrictions according to job role, support requirements, and security policy rather than applying them indiscriminately to IT administrators.
<img width="761" height="294" alt="image" src="https://github.com/user-attachments/assets/33ec67f0-eddf-41d2-bbb4-c84cd9bacad0" />
<img width="697" height="347" alt="image" src="https://github.com/user-attachments/assets/27706475-a873-4885-9e75-1b624438a351" />

## Verification Commands

Run from a standard Command Prompt while signed in as the target domain user:

```cmd
whoami
gpupdate /force
gpresult /r /scope user
```

**Expected applied GPOs:**

```text
GPO-Desktop-Wallpaper
GPO-Screen-Lock
GPO-User-Restrictions
```
<img width="564" height="738" alt="image" src="https://github.com/user-attachments/assets/5cf9f8d2-73ea-4576-adee-b4c49f27040e" />
<img width="640" height="973" alt="image" src="https://github.com/user-attachments/assets/b75d64b2-dbc5-48b9-9726-0c0b81f59a3b" />  

To export an HTML report, create a writable directory and run:

```cmd
mkdir C:\GPO-Reports
gpresult /scope user /h C:\GPO-Reports\GPO-Report.html /f
```
<img width="933" height="111" alt="image" src="https://github.com/user-attachments/assets/8095ff5b-5a1d-4baa-90c9-4818de3336fd" />

Open the report in a browser and inspect **User Details → Group Policy Objects → Applied GPOs**. The `/scope user` option targets the logged-in user's policies, while `/f` allows overwriting an existing report.
<img width="975" height="659" alt="image" src="https://github.com/user-attachments/assets/5f28192c-0201-4d3c-a010-ebc8ed1f6427" />

### Lesson  
  
Confirm the output directory exists, verify command syntax, and use an explicitly writable destination. Narrowing output to the relevant user scope can help when gathering user-policy evidence.

## Key Takeaways

- Administered Windows user settings centrally through Active Directory Group Policy.
- Distinguished user-targeted policy links from computer-targeted OU placement.
- Used an SMB-hosted resource and permissions to support centralized wallpaper deployment.
- Applied user security restrictions and validated them on domain-joined endpoints.
- Used `gpupdate`, `gpresult /r`, and `gpresult /h` to troubleshoot and document policy processing.
- Learned to separate **GPO applied** from **control behavior verified**.

## Resume-Ready Project Description

**Windows Server 2022 Group Policy & Endpoint Security Home Lab** — Created and linked three Active Directory GPOs across IT and HR organizational units to centrally deploy desktop wallpaper, configure screen saver security settings, and restrict Windows administrative utilities. Validated policy application on two domain-joined Windows 10 clients using `gpupdate`, `gpresult`, and HTML RSoP reports; troubleshot UNC paths and report export issues.

## Next Steps

- Complete and document the **10-minute screen saver / password-on-resume** behavioral test.
- Compare policy scope and security filtering between IT and HR users.
- Explore GPO inheritance, precedence, and loopback processing.

---

*Built as a hands-on learning project for Windows infrastructure, IT support, and junior system administration skills.*
