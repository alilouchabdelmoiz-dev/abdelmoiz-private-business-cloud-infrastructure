# Week 3 Infrastructure Log: Centralized Monitoring, Metrics Collection & Alerting

## Overview
This week's focus was implementing a centralized monitoring and alerting framework across the private business cloud infrastructure. By isolating the monitoring tools on a dedicated hub (`SVR-02`), resource overhead on production nodes is minimized while maintaining continuous visibility into system health, storage trends, and service availability.

---

## 1. Monitoring Hub Deployment (SVR-02)
To maximize agility and simplify container communication, Prometheus and Grafana were deployed via Docker on `SVR-02`.

### Docker Engine Verification
After provisioning Docker on the host, the engine status was verified using the official validation image:
```bash
sudo docker run hello-world


```

*Result: Clean execution return from daemon, confirming functional container architecture.*

### Environment Optimization

For faster workspace navigation, a permanent shell alias was introduced to the environment variables:

```bash
# Append shortcut alias to bash configuration
vim ~/.bashrc

# Configuration lines added:
# shortcuts
alias cdpg='cd ~/prometheus-grafana-docker'

source ~/.bashrc


```

### Docker Compose Architecture

An isolated stack directory `~/prometheus-grafana-docker` was created. The stack layout uses persistent named volumes to guarantee state preservation across container restarts.

```yaml
# docker-compose.yml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - '9090:9090'
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - '3000:3000'
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus

volumes:
  prometheus-data:
    driver: local
  grafana-data:
    driver: local


```

### Baseline Prometheus Configuration

A baseline control loop was created to monitor the local instance telemetry prior to attaching outer edge environments.

```yaml
# prometheus.yml (Initial Baseline)
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'watchtower'
    static_configs:
      - targets: ['localhost:9090']


```

The stack initialization command executed cleanly:

```bash
sudo docker compose up -d


```

*Output verification: Container prometheus Running (0.0s), Container grafana Running (0.0s).*

---

## 2. Distributed Metrics Collection (SVR-01 & SVR-03)

Host metrics collection was deployed natively on endpoints `SVR-01` (Application Node) and `SVR-03` using the Prometheus `node_exporter` binary to ensure low-impact, raw hardware and OS visibility.

### Installation and System Integration

Executed across targets using the corresponding system architecture payload (x86_64):

```bash
# Workspace setup and package ingestion
mkdir -p ~/downloads && cd ~/downloads
wget [https://github.com/prometheus/node_exporter/releases/download/v1.11.1/node_exporter-1.11.1.linux-amd64.tar.gz](https://github.com/prometheus/node_exporter/releases/download/v1.11.1/node_exporter-1.11.1.linux-amd64.tar.gz)

# Extract payload and relocate executable to system path
tar -xvf node_exporter-1.11.1.linux-amd64.tar.gz
sudo mv node_exporter-1.11.1.linux-amd64/node_exporter /usr/local/bin/

# Provision isolated system user for daemon privilege restriction
sudo useradd -rs /bin/false node_exporter


```

### Systemd Daemon Standardization

To manage the lifecycle of the exporter alongside host OS boots, a dedicated configuration unit file was provisioned:

```ini
# /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target


```

```bash
# Reload service engine and enforce start rules
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter


```

Local polling confirmed metric distribution exposure on standard port `9100`:

```bash
curl http://localhost:9100/metrics


```

---

## 3. Prometheus Target Aggregation

With metrics active on the endpoint layer, the main runtime configurations on the `SVR-02` hub were modified to establish systematic scraping loops.

```yaml
# /home/vmadmin/prometheus-grafana-docker/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'watchtower'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'SVR-01-Core'
    static_configs:
      - targets: ['192.168.x.x:9100']

  - job_name: 'SVR-03-Core'
    static_configs:
      - targets: ['192.168.x.y:9100']


```

### Grafana Visualization Verification

* **SVR-01 Engine Health Status:**

* **SVR-03 Engine Health Status:**


---

## 4. Production-Grade Alerting Infrastructure

Alerting criteria were engineered in Grafana to map real-world infrastructure failure scenarios, pushing critical incident alerts out via a unified Telegram notification policy.

### Alert 1: Host Instance Failure (Host Down)

* **Target Scope:** `SVR-01`, `SVR-03`, and core containers.
* **Condition Rules:** Evaluates metrics connection status over a 2-minute duration threshold.
* **Expression (PromQL):**

```promql
up{job=~"SVR.*|watchtower"}


```

* **Severity:** Critical
* **Incident Summary:** Triggered when any infrastructure node falls offline or stops responding to data collection queries.

### Alert 2: Storage Hardware Detachment (USB Offline)

* **Target Scope:** Dedicated backup mount points.
* **Condition Rules:** Monitors device structural absence across logical volumes.
* **Expression (PromQL):**

```promql
absent(node_filesystem_size_bytes{instance="192.168.x.x:9100", mountpoint="/media/backup-usb"})


```

* **Severity:** Critical
* **Incident Summary:** Immediate warning triggered if the backup storage array becomes unmounted or unreadable on the node.

### Alert 3: Proactive Disk Exhaustion Modeling (Predictive Analysis)

* **Target Scope:** Root System Drive (`/`)
* **Condition Rules:** Samples data consumption rate variations over a moving 1-hour window to project storage bounds over a 24-hour future timeline.
* **Expression (PromQL):**

```promql
predict_linear(node_filesystem_free_bytes{instance="192.168.x.x:9100", mountpoint="/"}[1h], 86400) < 0


```

* **Severity:** Warning
* **Incident Summary:** Proactively alerts operations before physical runtime space runs out, completely eliminating risk patterns associated with unexpected MariaDB database corruption due to disk fill starvation.

### Alert 4: Memory Starvation Defense (OOM Killer Mitigation)

* **Target Scope:** `SVR-01` Core RAM Allocation
* **Condition Rules:** Tracks percentage boundaries of dynamically available host memory against system pools over a 2-minute window.
* **Expression (PromQL):**

```promql
(node_memory_MemAvailable_bytes{instance="192.168.x.x:9100"} / node_memory_MemTotal_bytes{instance="192.168.x.x:9100"}) * 100


```

* **Threshold:** `< 10`
* **Severity:** Warning
* **Incident Summary:** Alerts engineering when available host memory dips below 10%. This intercept step triggers early remediation before the Linux Out-Of-Memory (OOM) Killer aggressively terminates running containers (such as the backend MariaDB database instances).


