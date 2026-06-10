# Execution Log: Infrastructure Security & Routing Overhaul

**Date:** June 2026

**Environment:** Private Business Cloud (SVR-01, SVR-02, SVR-03)

**Objective:** Secure inter-node communication, establish zero-trust mesh routing, deploy automated backups, and configure intrusion prevention.

---

### Phase 1: Initial UFW Provisioning & Node Exporter Lockdown

**Action:** Enabled UFW on all nodes. Allowed baseline web/SSH traffic, but strictly restricted Node Exporter (port 9100) to SVR-02's IP to secure the metrics pipeline.

**Execution (SVR-01 & SVR-03):**

```bash
vmadmin@SVR-01:~$ sudo ufw allow openSSH
Rules updated
vmadmin@SVR-01:~$ sudo ufw enable
Command may disrupt existing ssh connections. Proceed with operation (y|n)? y
Firewall is active and enabled on system startup
vmadmin@SVR-01:~$ sudo ufw allow from [my SVR-02 ip adress] to any port 9100 proto tcp
Rule added

```

**Execution (SVR-02 - Grafana/Prometheus App Host):**

```bash
vmadmin@SVR-02:~$ sudo ufw allow 3000/tcp
Rule added
vmadmin@SVR-02:~$ sudo ufw allow 9090/tcp
Rule added

```

---

### Phase 2: Mesh Deployment (Tailscale)

**Action:** Installed Tailscale across the cluster to pivot away from unencrypted local VM routing to a secure, encrypted mesh network.

**Execution (Deployed across SVR-01, SVR-02, SVR-03):**

```bash
vmadmin@SVR-01:~$ curl -fsSL https://tailscale.com/install.sh | sh
Installing Tailscale for ubuntu resolute, using method apt
...
Installation complete! Log in to start using Tailscale by running:
sudo tailscale up

vmadmin@SVR-01:~$ sudo tailscale up
To authenticate, visit:
        https://login.tailscale.com/a/[link]
Success.

```

**Pivoting Firewall Rules to Tailscale Interfaces:**

```bash
vmadmin@SVR-01:~$ sudo ufw delete allow from [my SVR-02 ip adress] to any port 9100 proto tcp
Rule deleted
vmadmin@SVR-01:~$ sudo ufw allow in on tailscale0 from [SVR-02_TAILSCALE_IP] to any port 9100 proto tcp
Rule added

```

---

### Phase 3: Out-of-Band (OOB) Management & Ruleset Rebuild

**Action:** Rebuilt UFW rulesets to prioritize the new Tailscale IP addresses. Added an OOB emergency backdoor using the local Windows host-only IP in case the mesh tunnel fails.

**Execution (SVR-01 Edge Router Example):**

```bash
vmadmin@SVR-01:~$ sudo ufw reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# PRIMARY: Tailscale Access (Encrypted Tunnel)
sudo ufw allow from [my windows tailscale ip adress] to any port 22 proto tcp
sudo ufw allow from [my windows tailscale ip adress] to any port 80 proto tcp
sudo ufw allow from [my windows tailscale ip adress] to any port 443 proto tcp

# FALLBACK: Local Windows Host-Only Access
sudo ufw allow from [my windows ip adress] to any port 22 proto tcp
sudo ufw allow from [my windows ip adress] to any port 80 proto tcp
sudo ufw allow from [my windows ip adress] to any port 443 proto tcp

# MONITORING:
sudo ufw allow from [my tailscale SVR-02 ip adress] to any port 9100 proto tcp

vmadmin@SVR-01:~$ sudo ufw enable
Backing up 'user.rules' to '/etc/ufw/user.rules.20260607_120737'
...
Firewall is active and enabled on system startup 

```

*(Note: Identical OOB reset and routing lockdown executed on SVR-02 and SVR-03).*

---

### Phase 4: Automated System Backups (Rsync & Cron)

**Action:** Created a custom backup script (`backup.sh`) targeting system rules (`/etc`) and active container data, pushing to a mounted USB drive.

**Script Execution & Validation:**

```bash
vmadmin@SVR-01:~$ chmod +x /home/vmadmin/backup.sh
vmadmin@SVR-01:~$ sudo ./backup.sh
vmadmin@SVR-01:~$ tail -n 20 /var/log/svr01-backup.log
...
nginx-proxy-manager/mysql/sys/x@0024waits_global_by_latency.frm
sent 66,115,603 bytes  received 11,811 bytes  10,173,448.31 bytes/sec
total size is 306,254,156  speedup is 4.63
=== Backup Completed Successfully at 2026-06-07_14-01-41 ===

```

**Cron Scheduling:**

```bash
vmadmin@SVR-01:~$ sudo crontab -e
# Added line to automate at midnight:
0 0 * * * /home/vmadmin/backup.sh

```

---

### Phase 5: Intrusion Prevention (Fail2Ban Implementation)

**Action:** Deployed Fail2Ban to parse system logs and automatically inject UFW block rules for malicious actors. Fixed a daemon deadlock issue (`fail2ban.sock`) during configuration.

**Execution & Verification:**

```bash
vmadmin@SVR-01:~$ sudo apt update && sudo apt install fail2ban -y
vmadmin@SVR-01:~$ sudo systemctl enable fail2ban

# Cleared deadlock preventing startup:
vmadmin@SVR-01:~$ sudo rm -f /var/run/fail2ban/fail2ban.sock

# Verified SSH Jail functionality across nodes:
vmadmin@SVR-01:/etc/fail2ban$ sudo fail2ban-client status sshd
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  `- Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   `- Banned IP list:

```

*Custom jail (`nginx-proxy.local`) also successfully deployed on SVR-01 to monitor `*_access.log`.*

**Active Jail Verifications:**
![SVR-01 SSH Status](./screenshots/fail2ban%20ssh%20SVR-01.png)
![SVR-02 SSH Status](./screenshots/fail2ban%20ssh%20SVR-02.png)
![SVR-03 SSH Status](./screenshots/fail2ban%20ssh%20SVR-03.png)
![Nginx Web Jail Running](./screenshots/jail2ban%20nginx%20up.png)

---

### Phase 6: Post-Migration Application Remediation

**Action:** Addressed routing failures caused by network changes.

**1. Prometheus/Grafana Link Fix:**

* **Issue:** Grafana lost connection to Prometheus after moving off direct host IPs.
* **Resolution:** Leveraged Docker internal DNS. Changed Grafana Data Source URL from `http://[my SVR-02 ip adress]:9090` to `http://prometheus:9090`. Metrics resumed instantly.

**Telemetry & Dashboard Verification:**
![Prometheus Scraper Setup](./screenshots/promotheus%20nginx%20setup.png)
![Prometheus Target Status](./screenshots/prometheus%20final%20check.png)
![SVR-01 Live Metrics](./screenshots/SVR-01%20grafana%20final%20check.png)
![SVR-03 Live Metrics](./screenshots/SVR-03%20grafana%20final%20check.png)
![Alert Engine Armed](./screenshots/Grafana%20alert%20rules%20finalcheck.png)

**2. Nextcloud Reverse Proxy Alignment:**

* **Issue:** Connecting via the new `http://cloud/` domain triggered an "Untrusted Domain" error.
* **Resolution:** Modified `config.php` to explicitly trust the proxy header, accept the custom domain, and force absolute URL overwrites to maintain internal navigation links.

**File Modification Audit (`config.php`):**

```php
  'trusted_domains' =>
  array (
    0 => '[my SVR-01 ip adress]:8080',
    1 => '[my tailscale SVR-01 ip adress]',
    2 => 'cloud',
  ),
  'trusted_proxies' => array('[my tailscale SVR-01 ip adress]'),
  'overwritehost' => 'cloud',
  'overwriteprotocol' => 'http',
  'overwrite.cli.url' => 'http://cloud/',

```
**Reverse Proxy Routing Verification:**
![Nginx Nextcloud Route](./screenshots/nginx%20nextcloud%20tailscale.png)
![Nginx Prometheus Route](./screenshots/nginx%20prometheus%20ip%20adress.png)
![Nginx Grafana Route](./screenshots/grafana%20taiscale%20ip%20adress%20setup.png)
![Nginx Global Status](./screenshots/Nginx%20final%20check.png)


---
###  Final Cluster Verification
Nextcloud loading cleanly over custom local DNS via the encrypted Tailscale proxy tunnel:

![Nextcloud Production Interface Live](./screenshots/NEXCLOD%20IS%20UP!%20final%20check.png)
