#!/bin/bash


# Make sure to change placeholders to your actual ip adresses before runnig

WINDOWS_TAILSCALE="[YOUR_WINDOWS_TAILSCALE_IP]"
WINDOWS_LOCAL="[YOUR_WINDOWS_LOCAL_HOST_ONLY_IP]"
SVR01_TAILSCALE="[YOUR_SVR01_TAILSCALE_IP]"
SVR02_TAILSCALE="[YOUR_SVR02_TAILSCALE_IP]"

# Reset baseline firewall rules
sudo ufw reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 1. PRIMARY: Tailscale SSH
sudo ufw allow from $WINDOWS_TAILSCALE to any port 22 proto tcp

# 2. FALLBACK: Windows Host-Only SSH
sudo ufw allow from $WINDOWS_LOCAL to any port 22 proto tcp

# 3. CORE ROUTING: Allow Nginx Proxy (SVR-01) to forward app web traffic
sudo ufw allow from $SVR01_TAILSCALE to any port 80 proto tcp
sudo ufw allow from $SVR01_TAILSCALE to any port 443 proto tcp

# 4. MONITORING: Allow SVR-02 to collect system performance data
sudo ufw allow from $SVR02_TAILSCALE to any port 9100 proto tcp

# Enable the firewall ruleset
sudo ufw --force enable
