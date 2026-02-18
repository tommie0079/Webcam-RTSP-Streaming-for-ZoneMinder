# menu.ps1
# Main launcher menu for the webcam streaming setup.

$scriptDir = $PSScriptRoot

function Show-Menu {
    Clear-Host
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "         Webcam RTSP Streaming - Main Menu               " -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host ""

    # Show status indicators
    $ffmpegOk   = Test-Path "$scriptDir\tools\ffmpeg\bin\ffmpeg.exe"
    $mtxOk      = Test-Path "$scriptDir\tools\mediamtx\mediamtx.exe"
    $confOk     = Test-Path "$scriptDir\cameras.conf"

    $ffmpegStatus = if ($ffmpegOk)  { "[OK]" } else { "[NOT INSTALLED]" }
    $mtxStatus    = if ($mtxOk)     { "[OK]" } else { "[NOT INSTALLED]" }
    $confStatus   = if ($confOk)    { "[OK]" } else { "[NOT FOUND]"     }

    $ffmpegColor  = if ($ffmpegOk)  { "Green" } else { "Red" }
    $mtxColor     = if ($mtxOk)     { "Green" } else { "Red" }
    $confColor    = if ($confOk)    { "Green" } else { "Yellow" }

    Write-Host "  Status:" -ForegroundColor Gray
    Write-Host "    FFmpeg   : " -NoNewline; Write-Host $ffmpegStatus -ForegroundColor $ffmpegColor
    Write-Host "    MediaMTX : " -NoNewline; Write-Host $mtxStatus    -ForegroundColor $mtxColor
    Write-Host "    cameras.conf : " -NoNewline; Write-Host $confStatus -ForegroundColor $confColor
    Write-Host ""
    Write-Host "---------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1]  Setup         - Download FFmpeg & MediaMTX" -ForegroundColor White
    Write-Host "  [2]  Detect Cameras- Find webcams & create cameras.conf" -ForegroundColor White
    Write-Host "  [3]  Start Streams - Launch RTSP streams (keep open!)" -ForegroundColor White
    Write-Host "  [4]  Edit Config   - Open cameras.conf in Notepad" -ForegroundColor White
    Write-Host "  [5]  Show URLs     - Print stream URLs for ZoneMinder" -ForegroundColor White
    Write-Host "  [Q]  Quit" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-URLs {
    $confFile = "$scriptDir\cameras.conf"
    if (-not (Test-Path $confFile)) {
        Write-Host "[!] cameras.conf not found. Run option 2 first." -ForegroundColor Yellow
        return
    }

    $conf = @{}
    Get-Content $confFile |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -match '^\s*\w+\s*=' } |
        ForEach-Object {
            $parts = $_ -split '=', 2
            $conf[$parts[0].Trim()] = $parts[1].Trim()
        }

    $localIp = (
        Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.InterfaceAlias -notlike "*Loopback*" -and
            $_.PrefixOrigin   -ne "WellKnown"       -and
            $_.IPAddress      -notlike "169.254.*"
        } |
        Sort-Object -Property InterfaceMetric |
        Select-Object -First 1
    ).IPAddress

    # Discover all cameras dynamically
    $camList = [System.Collections.Generic.List[hashtable]]::new()
    $idx = 1
    while ($true) {
        $name   = if ($conf["CAMERA${idx}_NAME"])   { $conf["CAMERA${idx}_NAME"]   } else { "" }
        $stream = if ($conf["CAMERA${idx}_STREAM"]) { $conf["CAMERA${idx}_STREAM"] } else { "cam$idx" }
        if (-not $name) { break }
        $camList.Add(@{ Index = $idx; Stream = $stream })
        $idx++
    }

    Write-Host ""
    Write-Host "  ZoneMinder stream URLs ($($camList.Count) camera(s)):" -ForegroundColor Cyan
    Write-Host ""
    foreach ($c in $camList) {
        Write-Host "    Camera $($c.Index) : rtsp://${localIp}:8554/$($c.Stream)" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "  Source Type in ZoneMinder: FFmpeg" -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

while ($true) {
    Show-Menu
    $key = Read-Host "  Select an option"

    switch ($key.Trim().ToUpper()) {

        "1" {
            Write-Host ""
            Write-Host "Running setup.ps1 ..." -ForegroundColor Cyan
            Write-Host ""
            & "$scriptDir\setup.ps1"
            Write-Host ""
            Write-Host "Press Enter to return to menu..." -ForegroundColor DarkGray
            Read-Host | Out-Null
        }

        "2" {
            Write-Host ""
            Write-Host "Running detect-cameras.ps1 ..." -ForegroundColor Cyan
            Write-Host ""
            & "$scriptDir\detect-cameras.ps1"
            Write-Host ""
            Write-Host "Press Enter to return to menu..." -ForegroundColor DarkGray
            Read-Host | Out-Null
        }

        "3" {
            Write-Host ""
            Write-Host "Starting streams in a new window (this menu will stay open)..." -ForegroundColor Cyan
            Write-Host ""
            Start-Process powershell.exe -ArgumentList @(
                "-NoExit",
                "-ExecutionPolicy", "Bypass",
                "-File", "`"$scriptDir\start-streams.ps1`""
            )
            Write-Host "Stream window launched. Check the new window for URLs." -ForegroundColor Green
            Write-Host ""
            Write-Host "Press Enter to return to menu..." -ForegroundColor DarkGray
            Read-Host | Out-Null
        }

        "4" {
            $confFile = "$scriptDir\cameras.conf"
            if (Test-Path $confFile) {
                Write-Host ""
                Write-Host "Opening cameras.conf in Notepad..." -ForegroundColor Cyan
                Start-Process notepad.exe -ArgumentList $confFile
            } else {
                Write-Host ""
                Write-Host "[!] cameras.conf not found. Run option 2 first." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Press Enter to return to menu..." -ForegroundColor DarkGray
                Read-Host | Out-Null
            }
        }

        "5" {
            Show-URLs
            Write-Host "Press Enter to return to menu..." -ForegroundColor DarkGray
            Read-Host | Out-Null
        }

        "Q" {
            Write-Host ""
            Write-Host "Goodbye!" -ForegroundColor DarkGray
            Write-Host ""
            exit 0
        }

        default {
            Write-Host ""
            Write-Host "[!] Invalid option. Press Enter and try again." -ForegroundColor Yellow
            Read-Host | Out-Null
        }
    }
}
