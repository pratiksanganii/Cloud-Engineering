#!/bin/bash
# ------------------------------------------------------------
# user-data.sh – Phase 2 bootstrap for the EC2 Linux web server
# ------------------------------------------------------------
# What this does:
#   1️⃣ Update OS & install required packages
#   2️⃣ Create a Python virtual‑env, install app deps
#   3️⃣ Set up systemd service to run the Flask app via Gunicorn
#   4️⃣ Install & configure Nginx as a reverse‑proxy (port 80 → 8080)
#   5️⃣ Harden the instance (fail2ban, unattended‑upgrades, etc.)
# ------------------------------------------------------------

# ---- 0. Logging -------------------------------------------------
LOG_FILE="/var/log/user-data.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== User‑data start: $(date) ==="


# ---- 1. OS update & package install -----------------------------
apt-get update -y
apt-get upgrade -y

# Essential packages
apt-get install -y python3 python3-venv python3-pip \
                   nginx git curl unzip \
                   fail2ban unattended-upgrades

# ---- 2. Application setup ---------------------------------------
APP_DIR="/opt/flask-app"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Pull from GitHub repo
git clone https://github.com/pratiksanganii/Cloud-Engineering.git
# Copy files to app directory
cp -r Cloud-Engineering/A02-ec2-linux-server/* "$APP_DIR"
# Clean up
rm -rf Cloud-Engineering

# Create a virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies (requirements.txt must be present)
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

# Verify the app starts (optional, will be managed by systemd later)
# gunicorn --bind 0.0.0.0:8080 app:app --daemon

# ---- 3. Systemd service -----------------------------------------
SERVICE_FILE="/etc/systemd/system/flask-app.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Gunicorn instance to serve Flask app
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:8080 app:app

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable flask-app.service
systemctl start flask-app.service

# ---- 4. Nginx reverse proxy --------------------------------------
NGINX_CONF="/etc/nginx/sites-available/flask-app"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    # Optional health‑check endpoint
    location /health {
        proxy_pass http://127.0.0.1:8080/health;
    }
}
EOF

# Enable the site and disable default
ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx config and reload
nginx -t && systemctl restart nginx

# ---- 5. Security hardening ---------------------------------------
# Fail2ban – protect SSH
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
EOF
systemctl enable fail2ban
systemctl start fail2ban

# Unattended upgrades – automatic security patches
dpkg-reconfigure -plow unattended-upgrades

# ---- 6. Cleanup -------------------------------------------------
# Remove any temporary files you don’t need
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "=== User‑data completed: $(date) ==="