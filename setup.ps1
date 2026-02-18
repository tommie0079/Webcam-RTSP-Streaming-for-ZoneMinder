# setup.ps1
# Downloads FFmpeg (full GPL build) and MediaMTX into .\tools\
# Run this ONCE before anything else.

$ErrorActionPreference = "Stop"
$toolsDir = "$PSScriptRoot\tools"

if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
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
    Write-Host "[FFmpeg] Downloading full GPL build (may take a few minutes)..."
    Invoke-WebRequest -Uri $ffmpegUrl -OutFile $ffmpegZip -UseBasicParsing

    Write-Host "[FFmpeg] Extracting..."
    Expand-Archive -Path $ffmpegZip -DestinationPath $toolsDir -Force

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

    Write-Host "[MediaMTX] Downloading $($release.tag_name) from $($asset.browser_download_url)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $mediamtxZip -UseBasicParsing

    Write-Host "[MediaMTX] Extracting..."
    if (-not (Test-Path $mediamtxDir)) {
        New-Item -ItemType Directory -Path $mediamtxDir | Out-Null
    }
    Expand-Archive -Path $mediamtxZip -DestinationPath $mediamtxDir -Force
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
Write-Host "  1. Connect both webcams (if not already done)"
Write-Host "  2. Run  .\detect-cameras.ps1  to identify them"
Write-Host "  3. Review / edit  cameras.conf  if needed"
Write-Host "  4. Run  .\start-streams.ps1   to start broadcasting"
Write-Host ""
