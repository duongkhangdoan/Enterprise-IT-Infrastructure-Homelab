# Enterprise IT Infrastructure & Systems Administration Homelab

A comprehensive, multi-vendor enterprise IT infrastructure lab designed to simulate real-world System Administration, Network Services, Cross-Platform Integration, Automation, and Help Desk Troubleshooting workflows.

---

## 🛠️ Lab Architecture & Components

* **Hypervisor:** VMware Workstation
* **Directory Services & Core Infra:** Windows Server (Active Directory Domain Services, DNS, DHCP)
* **Endpoints:** Windows Clients (`CLIENT01`, `CLIENT02`)
* **Linux Infrastructure:** Ubuntu Server (Cross-platform AD integration, Web/File services)
<img width="1536" height="1024" alt="Enterprise IT Homelab Roadmap" src="https://github.com/user-attachments/assets/f1d18a49-d621-441b-9daa-a223120da599" />

---

## 📋 Lab Modules & Overview

### Lab 1 — Active Directory & Domain Administration
* **Objectives:** Installed Windows Server, established an Active Directory domain, structured Organizational Units (OUs) for IT and HR departments, managed users/groups, and successfully joined `CLIENT01` and `CLIENT02` to the domain. Verified cross-machine domain authentication.
* **Key Skills:** Windows Server, Active Directory, DNS, User Management.

### Lab 2 — Group Policy & Security Hardening
* **Objectives:** Deployed Group Policy Objects (GPOs) to enforce screen locks after idle time, configured Windows Firewall profiles, implemented strong password policies, and restricted local administrator privileges. Validated policy application using `gpresult` and Event Viewer.
* **Key Skills:** Windows Administration, Security Hardening, Troubleshooting.

### Lab 3 — DNS, DHCP & Network Troubleshooting
* **Objectives:** Configured internal DNS zones, defined DHCP scopes and IP reservations. Performed network validation and troubleshooting using diagnostic utilities (`ipconfig`, `nslookup`, `ping`, `tracert`, and `Test-NetConnection`).
* **Key Skills:** TCP/IP, DNS, DHCP, Network Diagnostics.

### Lab 4 — Ubuntu Linux Administration & AD Integration
* **Objectives:** Deployed Ubuntu Server, configured SSH secure access, managed Linux users, groups, and file permissions (`chmod`/`chown`). Controlled system services via `systemctl`, secured the host with UFW firewall, hosted an Apache web server, set up Samba file sharing, and successfully integrated Ubuntu into the Active Directory domain using `realmd`/`sssd` for centralized authentication.
* **Key Skills:** Linux CLI, SSH, Access Controls, Cross-Platform Infrastructure.

### Lab 5 — PowerShell & Bash Scripting & Automation
* **Objectives:** Developed PowerShell automation scripts to batch-create 20 user accounts from a CSV file, exported Active Directory user reports, monitored disk space and service statuses, and implemented logging mechanisms. Wrote Bash scripts on Ubuntu to monitor system resources (CPU, RAM, and disk utilization).
* **Key Skills:** Scripting, Process Automation, Reporting.

### Lab 6 — IT Help Desk Troubleshooting & Incident Resolution
* **Objectives:** Simulated and resolved common enterprise support tickets, including locked-out accounts, password resets, domain-join failures, DNS resolution issues, shared folder access permission blocks, and unexpected Windows service outages. Documented root causes, resolution steps, and outcomes.
* **Key Skills:** Desktop Support, Incident Resolution, Technical Documentation.

---

