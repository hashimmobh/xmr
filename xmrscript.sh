#!/bin/bash

# Update and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y git build-essential cmake automake libtool autoconf \
  libhwloc-dev libssl-dev libuv1-dev screen

# Clone and build XMRig
cd /opt
sudo git clone https://github.com/xmrig/xmrig.git
cd xmrig
mkdir build && cd build
sudo cmake ..
sudo make -j$(nproc)

# Create a config with 90% CPU usage
CPU_THREADS=$(nproc)
USED_THREADS=$((CPU_THREADS * 90 / 100))
if [ "$USED_THREADS" -lt 1 ]; then
  USED_THREADS=1
fi

sudo tee /opt/xmrig/build/config.json > /dev/null <<EOL
{
  "autosave": true,
  "cpu": {
    "enabled": true,
    "huge-pages": true,
    "max-threads-hint": 0.9,
    "priority": null
  },
  "opencl": false,
  "cuda": false,
  "donate-level": 1,
  "pools": [
    {
      "url": "gulf.moneroocean.stream:10128",
      "user": "41jDs7aYqSFYpyvSBs7JAzSpRCjL9sSCS9WPuVGRukYcYTtUTszDdp71RFVtWD2icADwsnAQoSBJfDm7J1Chsuou5AHG36P",
      "pass": "x",
      "keepalive": true,
      "tls": false
    }
  ]
}
EOL

# Create systemd service
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
Nice=10
CPUWeight=90

[Install]
WantedBy=multi-user.target
EOL

# Enable and start miner service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable xmrig
sudo systemctl start xmrig

echo "XMRig is now running in the background as a systemd service."
echo "Use 'journalctl -u xmrig -f' to monitor logs."
