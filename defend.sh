#!/bin/bash
# All-in-one DoS defense script (lab use)
echo "[*] Installing tools..."
apt-get update && apt-get install -y fail2ban nginx iptables-persistent

echo "[*] Configuring Nginx defense..."
cat > /etc/nginx/nginx.conf <<EOF
worker_processes auto;
events {
    worker_connections 1024;
}
http {
    limit_req_zone \$binary_remote_addr zone=req_limit:10m rate=10r/s;
    limit_conn_zone \$binary_remote_addr zone=conn_limit:10m;

    server {
        listen 80;
        limit_req zone=req_limit burst=20;
        limit_conn conn_limit 10;

        client_header_timeout 5s;
        client_body_timeout 5s;

        location / {
            return 200 'OK';
        }

        location /login {
            limit_req zone=req_limit burst=10;
            return 403;
        }
    }
}
EOF
nginx -s reload

echo "[*] Setting up iptables rules..."
iptables -F
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 20 -j DROP
iptables -A INPUT -p udp --sport 53 -m length --length 512:65535 -j DROP
iptables -A INPUT -p tcp --dport 80 -m recent --set
iptables -A INPUT -p tcp --dport 80 -m recent --update --seconds 10 --hitcount 30 -j DROP

echo "[*] Saving iptables rules..."
iptables-save > /etc/iptables/rules.v4

echo "[*] Configuring Fail2Ban..."
cat > /etc/fail2ban/jail.local <<EOF
[nginx-http-auth]
enabled  = true
port     = http
filter   = nginx-http-auth
logpath  = /var/log/nginx/access.log
maxretry = 5
bantime  = 3600
EOF

systemctl restart fail2ban

echo "[*] Optional: Installing CrowdSec (AI-based Defender)..."
curl -s https://install.crowdsec.net | bash

echo "[*] Defense system fully deployed."
