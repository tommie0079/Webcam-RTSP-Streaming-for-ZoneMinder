# setup.ps1
# Downloads FFmpeg (full GPL build) and MediaMTX into .\tools\
# Run this ONCE before anything else.

$ErrorActionPreference = "Stop"
$toolsDir = "$PSScriptRoot\tools"

if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
}

# ---------------------------------------------------------------------------
# Helper: download with a live progress bar
# ---------------------------------------------------------------------------

function Invoke-Download {
    param (
        [string]$Label,
        [string]$Url,
        [string]$OutFile
    )

    Write-Host "[$Label] Connecting..."

    $webClient = New-Object System.Net.WebClient

    # Track bytes received and show Write-Progress
    $webClient.add_DownloadProgressChanged({
        param($s, $e)
        $pct     = $e.ProgressPercentage
        $recvMB  = [math]::Round($e.BytesReceived   / 1MB, 1)
        $totalMB = [math]::Round($e.TotalBytesToReceive / 1MB, 1)
        $status  = if ($e.TotalBytesToReceive -gt 0) {
            "$recvMB MB / $totalMB MB"
        } else {
            "$recvMB MB downloaded"
        }
        Write-Progress -Activity "Downloading $Label" -Status $status -PercentComplete $pct
    })

    # Use an async download so we can pump the event loop
    $task = $webClient.DownloadFileTaskAsync($Url, $OutFile)

    # Wait, processing events every 200 ms so progress callbacks fire
    while (-not $task.IsCompleted) {
        [System.Threading.Thread]::Sleep(200)
    }

    Write-Progress -Activity "Downloading $Label" -Completed

    if ($task.IsFaulted) {
        throw $task.Exception.InnerException
    }

    $webClient.Dispose()
    Write-Host "[$Label] Download complete."
}

# ---------------------------------------------------------------------------
# Helper: extract zip with progress
# ---------------------------------------------------------------------------

function Invoke-Extract {
    param (
        [string]$Label,
        [string]$ZipPath,
        [string]$Destination
    )

    Write-Host "[$Label] Extracting..."

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip     = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $total   = $zip.Entries.Count
    $current = 0

    foreach ($entry in $zip.Entries) {
        $current++
        $pct = [math]::Round(($current / $total) * 100)
        Write-Progress -Activity "Extracting $Label" `
                       -Status "$current / $total files" `
                       -PercentComplete $pct

        # Reproduce directory structure
        $destPath = Join-Path $Destination $entry.FullName
        $destDir  = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        # Skip directory entries (no data to extract)
        if (-not $entry.FullName.EndsWith('/')) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
        }
    }

    $zip.Dispose()
    Write-Progress -Activity "Extracting $Label" -Completed
    Write-Host "[$Label] Extraction complete."
}

# ---------------------------------------------------------------------------
# FFmpeg
# ---------------------------------------------------------------------------

$ffmpegDir    = "$toolsDir\ffmpeg"
$ffmpegBin    = "$ffmpegDir\bin\ffmpeg.exe"
$ffmpegZip    = "$toolsDir\ffmpeg.zip"
$ffmpegUrl    = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"

if (Test-Path $ffmpegBin) {
    Write-Host "[FFmpeg] Already installed at $ffmpegBin - skipping download."
} else {
    Invoke-Download -Label "FFmpeg" -Url $ffmpegUrl -OutFile $ffmpegZip
    Invoke-Extract  -Label "FFmpeg" -ZipPath $ffmpegZip -Destination $toolsDir

    # The zip extracts to a dated folder name like "ffmpeg-master-latest-win64-gpl"
    $extracted = Get-ChildItem $toolsDir -Directory |
                 Where-Object { $_.Name -like "ffmpeg-*" } |
                 Select-Object -First 1

    if (-not $extracted) {
        Write-Error "Could not find extracted FFmpeg folder in $toolsDir"
        exit 1
    }

    Rename-Item -Path $extracted.FullName -NewName "ffmpeg" -Force
    Remove-Item $ffmpegZip

    Write-Host "[FFmpeg] Installed at $ffmpegBin"
}

# ---------------------------------------------------------------------------
# MediaMTX
# ---------------------------------------------------------------------------

$mediamtxDir = "$toolsDir\mediamtx"
$mediamtxExe = "$mediamtxDir\mediamtx.exe"
$mediamtxZip = "$toolsDir\mediamtx.zip"

if (Test-Path $mediamtxExe) {
    Write-Host "[MediaMTX] Already installed at $mediamtxExe - skipping download."
} else {
    Write-Host "[MediaMTX] Fetching latest release info from GitHub..."
    $release = Invoke-RestMethod "https://api.github.com/repos/bluenviron/mediamtx/releases/latest"
    $asset   = $release.assets |
               Where-Object { $_.name -like "*windows_amd64.zip" } |
               Select-Object -First 1

    if (-not $asset) {
        Write-Error "Could not find a Windows amd64 asset in the latest MediaMTX release."
        exit 1
    }

    if (-not (Test-Path $mediamtxDir)) {
        New-Item -ItemType Directory -Path $mediamtxDir | Out-Null
    }

    Invoke-Download -Label "MediaMTX $($release.tag_name)" `
                    -Url $asset.browser_download_url `
                    -OutFile $mediamtxZip

    Invoke-Extract  -Label "MediaMTX" -ZipPath $mediamtxZip -Destination $mediamtxDir

    Remove-Item $mediamtxZip
    Write-Host "[MediaMTX] Installed at $mediamtxExe"
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================="
Write-Host " Setup complete!"
Write-Host "========================================="
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Connect your webcams (if not already done)"
Write-Host "  2. Run  .\detect-cameras.ps1  to identify them"
Write-Host "  3. Review / edit  cameras.conf  if needed"
Write-Host "  4. Run  .\start-streams.ps1   to start broadcasting"
Write-Host ""
