# Phase 2 Log: Docker Containerization & Reverse Proxy Layer

## [Step 1] Official Docker Engine Installation
Provisioned the official upstream Docker runtime repository on **SVR-01** following the official Ubuntu deployment guide:

```bash
# Update package index and install prerequisites
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings

# Download and assign the official Docker GPG key
sudo curl -fsSL [https://download.docker.com/linux/ubuntu/gpg](https://download.docker.com/linux/ubuntu/gpg) -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Register the stable repository with Apt sources
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: [https://download.docker.com/linux/ubuntu](https://download.docker.com/linux/ubuntu)
Suites: \$(. /etc/os-release && echo "\${UBUNTU_CODENAME:-\$VERSION_CODENAME}")
Components: stable
Architectures: \$(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Update repository state and verify daemon health
sudo apt update
sudo systemctl status docker

```

**Verification Payload:**
Executed the standard container verification test to confirm proper socket communications and architecture mapping:

```bash
sudo docker run hello-world

```

*Result: Status: Downloaded newer image for hello-world:latest. Core execution verified.*

---

## [Step 2] Reverse Proxy Deployment (Nginx Proxy Manager)

Created a dedicated data directory for the reverse proxy stack:

```bash
mkdir -p ~/data/nginx-proxy-manager
cd ~/data/nginx-proxy-manager

```

### Incident 1: API Unhealthy Exception (Database Boot Failure)

* **Initial Configuration:** Deployed Nginx Proxy Manager backed by the `linuxserver/mariadb` image.
* **Symptom:** The proxy application layer threw an unhealthy API exception. Checking database runtime logs (`sudo docker compose logs db`) revealed:
`s6-rc-compile: fatal: invalid /etc/s6-overlay/s6-rc.d/init-mariadb-config/type: must be oneshot, longrun, or bundle`
* **Root Cause Analysis:** A known permission/filesystem compilation bug inside the Linuxserver `s6-overlay` layer when running inside a Linux guest VM hosted on a Windows operating system via shared volume mounts.
* **Resolution:** Pivoted the database engine config from the community image to the official upstream `mariadb:10.11` build and remapped the physical state mount to local storage.

```yaml
  db:
    image: 'mariadb:10.11'
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: '[REDACTED_DB_PASSWORD]'
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: '[REDACTED_DB_PASSWORD]'
      TZ: "Africa/Casablanca"
    volumes:
      - ./mysql:/var/lib/mysql

```

*Result: Database initialized cleanly on port 3306. System ready for proxy connections.*

---

## [Step 3] Multi-Tenant Nextcloud Integration

Verified network port availability to avoid host-level conflicts before provisioning the storage workspace:

```bash
ss -tulpn | grep ":8080"

```

*Result: Port 8080 returned empty, confirming availability. Tracked mapping directly in `port-mapper.txt`.*

Isolated the Nextcloud configuration by generating a dedicated service directory and a masked `.env` file for credentials tracking:

```bash
mkdir -p ~/data/nextcloud
vim ~/data/nextcloud/.env

```

### Incident 2: Database Access Denied (SQLSTATE[HY000] [1045])

* **Symptom:** Nextcloud container initialization failed on first run with the error:
`Error while trying to create admin account: An exception occurred in the driver: SQLSTATE[HY000] [1045] Access denied for user 'nextcloud'@'172.18.0.4' (using password: YES)`
* **Root Cause Analysis:** Because the MariaDB container had already been spun up and initialized by Nginx Proxy Manager, the fresh Nextcloud runtime lacked administrative permissions to register its net-new database schema autonomously under standard tenant credentials.
* **Resolution:** Realigned parameters within `../nextcloud/.env` to map database interaction through `MYSQL_USER=root` for the initial installation phase, granting the container the structural rights required to provision the `nextcloud` database instance.

### Incident 3: Nextcloud Security Interlock (`CAN_INSTALL` Missing)

* **Symptom:** After database remediation, the web portal blocked configuration with the error:
`It looks like you are trying to reinstall your Nextcloud. However the file CAN_INSTALL is missing from your config directory.`
* **Resolution:** Manually bypassed the reinstallation block by dropping the explicit safety token file directly into the mapped storage target:

```bash
touch ../nextcloud/config/CAN_INSTALL

```

---

## [Final Validation] Stack State

Both application environments are running stably. Nextcloud storage abstractions, core filesystem objects (`Readme.md`, manual structures, and graphic files), and background components are fully responsive through port 8080.

