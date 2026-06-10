# Mesh Network Architecture (Phase 4)

## Objective
To isolate inter-node server traffic and telemetry data scraping away from public interfaces and unencrypted local networks, simulating a business-grade secure production environment.



## Topology Layout
Instead of passing traffic unencrypted over the hypervisor's private network interfaces, all nodes utilize a secure, encrypted Tailscale overlay network (`tailscale0`).

* **Management Workstation (Windows Host):** Acts as the primary orchestrator. Accesses the cluster securely via its Tailscale IP.
* **SVR-01 (Edge/Reverse Proxy):** Serves as the public-facing gateway for external HTTP/HTTPS traffic, passing connections securely down the tunnel.
* **SVR-02 (Application & Monitoring Hub):** Hosts core internal services (Nextcloud, Prometheus, Grafana). It handles traffic forwarded by SVR-01 and safely scrapes performance telemetry.
* **SVR-03 (Remote Node Endpoint):** Runs standalone application targets and Node Exporter services.

### Proxy Verification Routing
Below is the verification of the Nginx Proxy Manager interface routing frontend custom domains securely to internal Tailscale IP interfaces:

![Nginx Proxy Gateway Configuration](./screenshots/Nginx%20final%20check.png)

| Service Domain | Target Proxy Destination (Tailscale) | Verification State |
| :--- | :--- | :--- |
| `http://cloud/` | `http://100.103.203.43:8080` (SVR-02 Nextcloud) | ![Verified](./screenshots/nginx%20nextcloud%20tailscale.png) |
| `http://prom/` | `http://100.103.203.43:9090` (SVR-02 Prometheus) | ![Verified](./screenshots/nginx%20prometheus%20ip%20adress.png) |
| `http://grafana/` | `http://100.103.203.43:3000` (SVR-02 Grafana) | ![Verified](./screenshots/grafana%20taiscale%20ip%20adress%20setup.png) |

---

## Per-Interface Perimeter Strategy

1. **The Core Mesh Tunnel (`tailscale0`):** This is the high-security primary pathway. All inter-VM communications, application reverse-proxying, and Prometheus metrics collection are bound explicitly to Tailscale IP addresses.
2. **Out-of-Band (OOB) Emergency Fallback:** The local VirtualBox Host-Only adapter network (`192.168.56.0/24`) is strictly reserved as an unexposed backdoor. It is firewalled to drop all incoming traffic *except* for explicit SSH and administrative access originating directly from the host machine's private gateway IP. If the encrypted mesh tunnel fails, management access is maintained without breaking production routing.

### Secure Metrics Telemetry Pipeline
With UFW restrictions active, Prometheus metrics scraping has been shifted entirely onto the Tailscale overlay network.

![Prometheus Target Status Verification](./screenshots/prometheus%20final%20check.png)
*Figure: Active endpoint scrapers showing verified green `UP` states over encrypted channels via `promotheus nginx setup.png` configuration rules.*

---

## Final Production Verification
The ultimate success criterion of Phase 4 requires clean application rendering across the front-facing client host using local DNS domains without routing loops or security blocks:

![Nextcloud Production Interface Live](./screenshots/NEXCLOD%20IS%20UP!%20final%20check.png)
