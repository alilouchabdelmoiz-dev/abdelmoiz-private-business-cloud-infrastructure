
```markdown
# Week 1: Infrastructure Log - SVR-01 Setup & Storage Migration

## 1. Network Layout
I'm using a parent VM (SVR-00) with two adapters: NAT for internet access, and a Host-Only adapter for local traffic.

* Base Subnet: `192.168.56.0/24`
* SVR-01 IP: `192.168.56.5`
* SVR-02 IP: `192.168.56.6`
* SVR-03 IP: `192.168.56.7`

My Netplan config (`/etc/netplan/01-netcfg.yaml`):
```yaml
network:
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses: [192.168.56.5/24]
  version: 2

```

## 2. SSH Access & Hardening

Generated an Ed25519 key on Windows and piped it to the server.

```bash
ssh-keygen -t ed25519
```
```
Generating public/private ed25519 key pair.
Enter file in which to save the key (C:\Users\LocalUser/.ssh/id_ed25519):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in C:\Users\LocalUser/.ssh/id_ed25519
Your public key has been saved in C:\Users\LocalUser/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:F2oY3iBeAKszf+Q05eS6ts9actJRdQpknnfk5RpDEPY user@DESKTOP-ENV
The key's randomart image is:
+--[ED25519 256]--+
|  ...  .+ =o+ .  |
|   . . o = B o   |
|  . . * + + E .  |
| . . O * o o +   |
|+   = * S . .    |
| + + + o .       |
|  . * +          |
|   ..B           |
|   .++o          |
+----[SHA256]-----+
```
I manually set the permissions (`600` for keys, `700` for directory) so Linux wouldn't reject them.

```powershell
type "$HOME\.ssh\id_ed25519.pub" | ssh vmadmin@192.168.56.4 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

I also set a ssh-agent to avoid writing passphrase manually
```powrshell
ssh-agent (automatic) Get-Service -Name ssh-agent | Set-Service -StartupType Automatic
```

Then I locked down `/etc/ssh/sshd_config` to kill password logins:

```
PasswordAuthentication no
KbdInteractiveAuthenticatio no
ChallengeResponseAuthentication no
```

## 3. Cloning & The Machine ID Trap

I made 3 linked clones via VirtualBox GUI.
*


*The Bug:** Linked clones share the same machine ID, which messes up networking logs.
**The Fix:** Cleared the old ID and generated random ones for each clone:

```bash
sudo cp -p /etc/machine-id /root/SVR-[num]-orig-machine-id # copy old machine-id
sudo cat /dev/null > /etc/machine-id 
sudo systemd-machine-id-setup --root=/ 

```

## 4. The USB Backup Nightmare (Ext4 Journaling)

I connected my 64GB flash drive. VirtualBox didn't see it at first until I messed with the USB filters in the GUI.

```bash
lsusb
#Bus 001 Device 005: ID 1908:1320 GEMBIRD DM8261 Flashdisc
```

Once visible as `/dev/sdb`, I ran:

```bash
sudo mkfs -t ext4 -L backup-usb /dev/sdb

```

**The Bug:** The mount failed.

```bash
sudo mount backup-usb /media/backup-usb
#failed mount doest understand which file I wanted
#mount: /media/backup-usb: special device backup-usb does not exist.
#       dmesg(1) may have more information after failed mount system call.
```

 Checked `dmesg` and saw:

`JBD2: no valid journal superblock found`
`EXT4-fs (sdb): Could not load journal inode`

**The Fix:** Cheap USB sticks choke on heavy Ext4 journaling writes. I ran a file repair and forced the filesystem to format **without** a journal using the `^has_journal` flag. It worked instantly.

```bash
sudo fsck.ext4 -fy /dev/sdb
sudo mkfs.ext4 -O ^has_journal -L backup-usb /dev/sdb1

```

Now it correctly mounts to `/media/backup-usb`.

```bash
vmadmin@SVR-01:~$ df -h
/dev/sdb1        62G  464M   58G   1% /media/backup-usb
```

## 5. Headless Automation

Tired of opening the VirtualBox GUI, so I added `D:\virtualbox` to my Windows Environment Path variables.

Now I boot the lab background-only from PowerShell:

```powershell
vboxmanage startvm SVR-01 --type headless
#Waiting for VM "SVR-01" to power on...
#VM "SVR-01" has been successfully started.
```

```



