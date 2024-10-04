if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

[System.Console]::BackgroundColor = 'Black'
[System.Console]::ForegroundColor = 'White'
[System.Console]::Clear()

function Show-Menu {
    param (
        [string]$prompt = "Select an option:"
    )
    $options = @("Continue", "Cancel")
    $selectedIndex = 0

    while ($true) {
        Clear-Host
        Write-Host "Discord is going to be killed. Select an option:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $options.Length; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "> $($options[$i])" -BackgroundColor DarkGray -ForegroundColor White
            }
            else {
                Write-Host "  $($options[$i])"
            }
        }

        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            0x26 {
                $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $options.Length - 1 }
            }
            0x28 {
                $selectedIndex = if ($selectedIndex -lt ($options.Length - 1)) { $selectedIndex + 1 } else { 0 }
            }
            0x0D {
                return $options[$selectedIndex]
            }
        }
    }
}

$selection = Show-Menu

if ($selection -eq "Cancel") {
    Write-Host "[ $([char]0x1b)[31mERROR$([char]0x1b)[0m ] Operation cancelled." -ForegroundColor White
    Exit
}

$discordProcess = Get-Process -Name "Discord" -ErrorAction SilentlyContinue
if ($discordProcess) {
    Write-Host "[ $([char]0x1b)[36mINFO$([char]0x1b)[0m ] Killing Discord process..." -ForegroundColor White
    Stop-Process -Name "Discord" -Force
    Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Discord process killed." -ForegroundColor White
}

$url = "https://archive.torproject.org/tor-package-archive/torbrowser/13.5.6/tor-expert-bundle-windows-x86_64-13.5.6.tar.gz"
$destPath = "C:\Tor"
$archivePath = Join-Path $destPath "tor-expert-bundle.tar.gz"
$torExePath = Join-Path $destPath "Tor\tor.exe"
$iconUrl = "https://raw.githubusercontent.com/Inplex-sys/discord-tor/refs/heads/main/assets/app-tor.ico"
$iconPath = "$env:LOCALAPPDATA\Discord\app.ico"

if (-Not (Test-Path $torExePath)) {
    New-Item -ItemType Directory -Force -Path $destPath
    Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Directory created." -ForegroundColor White

    Invoke-WebRequest -Uri $url -OutFile $archivePath
    Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Tor Bundle Download completed." -ForegroundColor White

    tar -xzf $archivePath -C $destPath
    Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Extraction completed." -ForegroundColor White

    Remove-Item $archivePath
    Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Archive file removed." -ForegroundColor White
}
else {
    Write-Host "[ $([char]0x1b)[36mINFO$([char]0x1b)[0m ] Tor is already installed. Skipping installation." -ForegroundColor White
}

if (-Not (Get-Service -Name "Tor" -ErrorAction SilentlyContinue)) {
    Write-Host "[ $([char]0x1b)[36mINFO$([char]0x1b)[0m ] Installing Tor as a service..." -ForegroundColor White
    Start-Process -FilePath $torExePath -ArgumentList "--service", "install" -Wait
    Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Tor service installed." -ForegroundColor White
}
else {
    Write-Host "[ $([char]0x1b)[36mINFO$([char]0x1b)[0m ] Tor service is already installed. Skipping installation." -ForegroundColor White
}

if ((Get-Service -Name "Tor").Status -ne 'Running') {
    Write-Host "[ $([char]0x1b)[36mINFO$([char]0x1b)[0m ] Starting Tor service..." -ForegroundColor White
    Start-Service -Name "Tor"
    Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Tor service started." -ForegroundColor White
}
else {
    Write-Host "[ $([char]0x1b)[36mINFO$([char]0x1b)[0m ] Tor service is already running. Skipping start." -ForegroundColor White
}

Write-Host "[ $([char]0x1b)[36mINFO$([char]0x1b)[0m ] Updating Discord shortcut with Tor proxy..." -ForegroundColor White

Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath

$WshShell = New-Object -ComObject WScript.Shell
$startMenuShortcut = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Discord Inc\Discord.lnk"
$desktopShortcut = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Discord.lnk")

foreach ($shortcutPath in @($startMenuShortcut, $desktopShortcut)) {
    if (Test-Path $shortcutPath) {
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "$env:LOCALAPPDATA\Discord\Update.exe"
        $Shortcut.Arguments = '--processStart Discord.exe --process-start-args "--proxy-server=socks5://127.0.0.1:9050"'
        $Shortcut.IconLocation = $iconPath
        $Shortcut.Save()
        Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Shortcut updated at $shortcutPath." -ForegroundColor White
    }
}

$discordLocalPath = "$env:LOCALAPPDATA\Discord"

Get-ChildItem -Path $discordLocalPath -Filter "app-*" -Recurse | ForEach-Object {
    Copy-Item -Path $iconPath -Destination "$($_.FullName)\app.ico" -Force
    Write-Host "[ $([char]0x1b)[32mOK$([char]0x1b)[0m ] Icon replaced at $($_.FullName)\app.ico" -ForegroundColor White
}

Write-Host "Tor has been installed as service and started. It's accessible at 127.0.0.1:9050" -ForegroundColor White
Write-Host "The Discord shortcut has been updated with Tor proxy settings." -ForegroundColor White

Write-Host "Press Enter to finish ..." -ForegroundColor Yellow
[void][System.Console]::ReadLine()
