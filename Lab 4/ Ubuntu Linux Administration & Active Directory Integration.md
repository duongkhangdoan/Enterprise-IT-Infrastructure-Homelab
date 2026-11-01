## Objective
Deploy an Ubuntu Server in a Windows Active Directory lab, enable domain authentication and remote administration, host an internal web service, and provide an SMB file share restricted to the IT security group.

## Lab environment

| Host | Role | IP address |
|---|---|---|
| DC01 | Windows Server 2022 — AD DS, DNS, DHCP | `192.168.10.10` |
| CLIENT01 | Windows 10 — IT user `AD\jsmith` | `192.168.10.101` |
| CLIENT02 | Windows 10 — HR user `AD\edavis` | `192.168.10.100` |
| Ubuntu (`duong`) | Linux server — SSSD, SSH, Apache, Samba | `192.168.10.102` |

- AD domain: `ad.lab`
- Ubuntu FQDN: `duong.ad.lab`
- VirtualBox NAT Network: `192.168.10.0/24`
- Gateway: `192.168.10.1`
- AD/DNS server: `192.168.10.10`
- IT AD group: `GG_IT_Users`
- Ubuntu: Ubuntu Server 26.04.1 LTS

## 1. Install Ubuntu Server

1. Create an Ubuntu Server VM in VirtualBox and attach it to the lab NAT Network.
2. Install Ubuntu Server and create the local administrator account `duong`.
3. Set the server hostname:

   ```bash
   sudo hostnamectl set-hostname duong
   ```
<img width="744" height="445" alt="image" src="https://github.com/user-attachments/assets/5670b175-7feb-4209-820b-5819eb455446" />

## 2. Configure static IP and DNS

Edit the Netplan configuration:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Configure the existing `enp0s3` interface with the following network settings (preserve any installer-specific settings required by your VM):

```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: false
      addresses:
        - 192.168.10.102/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses:
          - 192.168.10.10
        search:
          - ad.lab
```

Apply the configuration:

```bash
sudo netplan apply
```

Set the local hostname mapping in `/etc/hosts`:

```text
127.0.1.1 duong.ad.lab duong
```

On **DC01**, create a DNS **A record** in the `ad.lab` zone:

```text
duong.ad.lab → 192.168.10.102
```

Reserve/exclude `192.168.10.102` from the DHCP scope so it is not assigned to another host.

## 3. Join Ubuntu to Active Directory using realmd and SSSD

Install the AD integration packages:

```bash
sudo apt update
sudo apt install -y realmd sssd sssd-tools adcli libnss-sss libpam-sss samba-common-bin krb5-user packagekit
```

Join the domain using the AD Administrator account:

```bash
sudo realm join --user=Administrator ad.lab
```

Allow the IT security group to sign in:

```bash
sudo realm permit -g GG_IT_Users@ad.lab
```

Use SSSD for Linux identity lookup and authentication. The lab's `/etc/sssd/sssd.conf` domain settings include:

```ini
[sssd]
domains = ad.lab
config_file_version = 2
services = nss, pam

[domain/ad.lab]
id_provider = ad
ad_domain = ad.lab
krb5_realm = AD.LAB
realmd_tags = manages-system joined-with-adcli
krb5_store_password_if_offline = True
cache_credentials = True
fallback_homedir = /home/%u@%d
default_shell = /bin/bash
use_fully_qualified_names = True
ldap_id_mapping = True
access_provider = simple
simple_allow_groups = GG_IT_Users@ad.lab
```

Protect the SSSD configuration and start the service:

```bash
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl enable --now sssd
```

Keep SSSD as the NSS/PAM identity provider; do not replace the existing `sss` entries in `/etc/nsswitch.conf` with Winbind.

## 4. Configure SSH remote administration

Install and enable OpenSSH Server:

```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

Allow SSH in UFW:

```bash
sudo ufw allow 22/tcp
```

The IT user can connect from CLIENT01 using the AD identity `jsmith@ad.lab`, subject to SSSD access policy.

## 5. Deploy Apache web server

Install and enable Apache:

```bash
sudo apt install -y apache2
sudo systemctl enable --now apache2
sudo ufw allow 80/tcp
```
<img width="1043" height="275" alt="image" src="https://github.com/user-attachments/assets/d0c642ae-a43f-40f3-8369-ca705a2980fd" />  
<img width="456" height="501" alt="image" src="https://github.com/user-attachments/assets/d96ab273-db02-46be-95ad-2746eed4dce7" />  
<img width="592" height="258" alt="image" src="https://github.com/user-attachments/assets/dfa60e08-5056-49de-91c1-3e54093bb906" />   
<img width="591" height="249" alt="image" src="https://github.com/user-attachments/assets/396cba16-e04b-4313-be65-82f63addd833" />  
<img width="409" height="313" alt="image" src="https://github.com/user-attachments/assets/a8b9d6e5-0f81-4830-8e6e-419adfab18aa" />  

The internal website is served from the Ubuntu server at `http://192.168.10.102/`.

## 6. Create the IT shared directory

Create the directory and assign it to the IT AD group resolved through SSSD:

```bash
sudo mkdir -p /srv/it-share
sudo chown 'duong:gg_it_users@ad.lab' /srv/it-share
sudo chmod 2770 /srv/it-share
```

The setgid bit (`2` in `2770`) causes newly created files and subdirectories to inherit the directory's group where applicable.

## 7. Install and configure Samba and Winbind

Install packages:

```bash
sudo apt install -y samba winbind libnss-winbind acl
```

Back up the existing Samba configuration and Kerberos keytab:

```bash
sudo cp -p /etc/samba/smb.conf /etc/samba/smb.conf.pre-ad
sudo cp -p /etc/krb5.keytab /root/krb5.keytab.before-samba
```

Edit `/etc/samba/smb.conf` and set the relevant parameters under the existing `[global]` section (retain other required Ubuntu/Samba defaults):

```ini
[global]
   workgroup = AD
   security = ADS
   realm = AD.LAB

   idmap config * : backend = tdb
   idmap config * : range = 100000-999999
   idmap config AD : backend = rid
   idmap config AD : range = 1000000-999999999

   kerberos method = secrets and keytab
   sync machine password to keytab = /etc/krb5.keytab:account_name:sync_kvno:machine_password
```

Join Samba as an AD domain member:

```bash
sudo net ads join -U Administrator
```

Synchronize the Samba machine credentials into the Kerberos keytab used by SSSD:

```bash
sudo net ads keytab create
```

Start the Samba and Winbind services:

```bash
sudo systemctl enable --now smbd winbind
sudo systemctl restart smbd winbind sssd
```

**Important:** Samba and SSSD must use machine credentials consistent with the AD computer account. The keytab synchronization setting is included to keep `/etc/krb5.keytab` aligned after Samba joins the domain.

## 8. Publish the IT Samba share

Add the following section to `/etc/samba/smb.conf`:

```ini
[IT]
   path = /srv/it-share
   browseable = yes
   read only = no
   valid users = @"AD\GG_IT_Users"
   create mask = 0660
   directory mask = 2770
```

In this lab, Winbind maps the IT group to numeric GID `1001109`. Preserve the existing SSSD-based ownership and add an ACL for the Winbind-mapped group:

```bash
sudo setfacl -m g:1001109:rwx /srv/it-share
sudo setfacl -d -m g:1001109:rwx /srv/it-share
```

**Environment-specific:** `1001109` is the group GID observed in this lab; a new AD deployment may use a different GID. The numeric value should be adjusted to that environment.

Reload the Samba service:

```bash
sudo systemctl restart smbd
```

## 9. Configure firewall access for SMB

Enable UFW and allow SMB only from the lab subnet:

```bash
sudo ufw allow from 192.168.10.0/24 to any port 445 proto tcp
sudo ufw enable
```

## 10. Windows client access

From **CLIENT01**, sign in as the IT user `AD\jsmith` and open:

```text
\\192.168.10.102\IT
```
<img width="724" height="408" alt="image" src="https://github.com/user-attachments/assets/e9b59e27-0013-4b25-ac5a-22536dd4c0c2" />  
<img width="726" height="149" alt="image" src="https://github.com/user-attachments/assets/d3241268-000a-4735-bd4a-b8bafa09dd57" />  
<img width="732" height="275" alt="image" src="https://github.com/user-attachments/assets/f4ccb416-fe9a-4c17-b763-1a49833066b7" />

The IT user can read and create files in the share. The HR user `AD\edavis` on CLIENT02 is not authorized to open the IT share.

## Final architecture

- **AD DS / DNS:** DC01 (`192.168.10.10`)
- **Linux domain authentication:** realmd + SSSD + Kerberos
- **Remote management:** OpenSSH (`22/tcp`)
- **Web service:** Apache (`80/tcp`)
- **Windows file sharing:** Samba + Winbind (`445/tcp`)
- **Share:** `\\192.168.10.102\IT` → `/srv/it-share`
- **Authorization:** AD group `GG_IT_Users`, Samba `valid users`, Linux permissions and ACL


