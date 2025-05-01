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

# Update and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y git build-essential cmake automake libtool autoconf \
  libhwloc-dev libssl-dev libuv1-dev screen

# sudo rm -rf /opt/xmrig

# Clone and build XMRig
cd /opt
sudo git clone https://github.com/xmrig/xmrig.git
cd xmrig
sudo git pull origin master  # Ensure we get the latest version
sudo chmod +x /opt/xmrig/build/xmrig
mkdir build && cd build
sudo make clean  # Clean any previous builds
sudo cmake ..
sudo make -j$(nproc)

# Dynamically calculate the CPU usage and threads
CPU_THREADS=$(nproc)  # Get the total number of CPU threads
USED_THREADS=$((CPU_THREADS * 90 / 100))  # 90% of the total threads
if [ "$USED_THREADS" -lt 1 ]; then
  USED_THREADS=1  # Ensure at least 1 thread is used
fi

# Ensure that 1 thread is left for the system
USED_THREADS=$((USED_THREADS - 1))
if [ "$USED_THREADS" -lt 1 ]; then
  USED_THREADS=1  # Ensure at least 1 thread for mining
fi

# Update config.json with the correct settings
sudo tee /opt/xmrig/build/config.json > /dev/null <<EOL
{
    "api": {
        "id": null,
        "worker-id": null
    },
    "http": {
        "enabled": false,
        "host": "127.0.0.1",
        "port": 0,
        "access-token": null,
        "restricted": true
    },
    "autosave": true,
    "background": false,
    "colors": false,
    "title": true,
    "randomx": {
        "init": -1,
        "init-avx2": 0,  # Disable AVX2 if not supported
        "mode": "auto",
        "1gb-pages": false,
        "rdmsr": true,
        "wrmsr": true,
        "cache_qos": false,
        "numa": true,
        "scratchpad_prefetch_mode": 1
    },
    "cpu": {
        "enabled": true,
        "max-threads-hint": 1.0,  # Use all threads
        "huge-pages": true,
        "threads": $USED_THREADS,  # Dynamically set the number of threads
        "huge-pages-jit": false,
        "hw-aes": null,
        "priority": null,
        "memory-pool": false,
        "yield": true,
        "asm": true,
        "argon2-impl": null,
        "argon2": [0, 4, 1, 5, 2, 6, 3, 7],
        "cn": [
            [1, 0],
            [1, 4],
            [1, 1],
            [1, 5],
            [1, 2],
            [1, 6],
            [1, 3],
            [1, 7]
        ],
        "cn-heavy": [
            [1, 0],
            [1, 1],
            [1, 2],
            [1, 3]
        ],
        "cn-lite": [
            [1, 0],
            [1, 4],
            [1, 1],
            [1, 5],
            [1, 2],
            [1, 6],
            [1, 3],
            [1, 7]
        ],
        "cn-pico": [
            [2, 0],
            [2, 4],
            [2, 1],
            [2, 5],
            [2, 2],
            [2, 6],
            [2, 3],
            [2, 7]
        ],
        "cn/upx2": [
            [2, 0],
            [2, 4],
            [2, 1],
            [2, 5],
            [2, 2],
            [2, 6],
            [2, 3],
            [2, 7]
        ],
        "ghostrider": [
            [8, 0],
            [8, 1],
            [8, 2],
            [8, 3]
        ],
        "rx": [0, 4, 1, 5, 2, 6, 3, 7],
        "rx/wow": [0, 4, 1, 5, 2, 6, 3, 7],
        "cn-lite/0": false,
        "cn/0": false,
        "rx/arq": "rx/wow"
    },
    "opencl": {
        "enabled": false,
        "cache": true,
        "loader": null,
        "platform": "AMD",
        "adl": true
    },
    "cuda": {
        "enabled": false,
        "loader": null,
        "nvml": true
    },
    "log-file": null,
    "donate-level": 0,  # Set to 0 for max hash rate
    "donate-over-proxy": 1,
    "pools": [
        {
            "algo": null,
            "coin": null,
            "url": "gulf.moneroocean.stream:10128",
            "user": "41jDs7aYqSFYpyvSBs7JAzSpRCjL9sSCS9WPuVGRukYcYTtUTszDdp71RFVtWD2icADwsnAQoSBJfDm7J1Chsuou5AHG36P",
            "pass": "x",
            "rig-id": "Ubuntu-W002",
            "nicehash": false,
            "keepalive": true,
            "enabled": true,
            "tls": false,
            "sni": false,
            "tls-fingerprint": null,
            "daemon": false,
            "socks5": null,
            "self-select": null,
            "submit-to-origin": false
        }
    ],
    "retries": 5,
    "retry-pause": 5,
    "print-time": 60,
    "health-print-time": 60,
    "dmi": true,
    "syslog": false,
    "tls": {
        "enabled": false,
        "protocols": null,
        "cert": null,
        "cert_key": null,
        "ciphers": null,
        "ciphersuites": null,
        "dhparam": null
    },
    "dns": {
        "ipv6": false,
        "ttl": 30
    },
    "user-agent": null,
    "verbose": 0,
    "watch": true,
    "pause-on-battery": false,
    "pause-on-active": false
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
Nice=0  # Set Nice to 0 for max CPU priority
CPUWeight=100  # Ensure maximum CPU usage

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
