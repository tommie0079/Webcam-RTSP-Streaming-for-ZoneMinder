# 📷 Webcam RTSP Streaming for ZoneMinder

Broadcast two USB webcams as independent RTSP streams on Windows 11, ready to import into [ZoneMinder](https://zoneminder.com/) or any other NVR/VMS.

Built with **FFmpeg** (H.264 capture) and **MediaMTX** (RTSP server) — no installation required, everything runs from a single folder.

---

## Architecture

```
Webcam 1 ──[FFmpeg / DirectShow]──┐
                                   ├──► MediaMTX (RTSP server :8554) ──► ZoneMinder
Webcam 2 ──[FFmpeg / DirectShow]──┘
```

| Stream | URL |
|--------|-----|
| Camera 1 | `rtsp://<windows-host-ip>:8554/cam1` |
| Camera 2 | `rtsp://<windows-host-ip>:8554/cam2` |

---

## Requirements

| Requirement | Notes |
|---|---|
| Windows 11 (IoT or any edition) | x64 |
| PowerShell 5.1+ | Built into Windows |
| Internet access | First run only — to download FFmpeg & MediaMTX |
| 2× USB webcams | Must appear in Windows Device Manager |

> FFmpeg and MediaMTX are downloaded automatically by `setup.ps1`. You do not need to install anything manually.

---

## Quick Start

### 1. Clone or download this repo

```powershell
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```

Or simply download the ZIP and extract it.

### 2. Launch the menu

Right-click `menu.ps1` → **Run with PowerShell**, or in a terminal:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\menu.ps1
```

### 3. Follow the menu steps in order

```
=========================================================
         Webcam RTSP Streaming - Main Menu
=========================================================
  Status:
    FFmpeg       : [NOT INSTALLED]
    MediaMTX     : [NOT INSTALLED]
    cameras.conf : [NOT FOUND]
---------------------------------------------------------
  [1]  Setup          - Download FFmpeg & MediaMTX
  [2]  Detect Cameras - Find webcams & create cameras.conf
  [3]  Start Streams  - Launch RTSP streams (keep open!)
  [4]  Edit Config    - Open cameras.conf in Notepad
  [5]  Show URLs      - Print stream URLs for ZoneMinder
  [Q]  Quit
=========================================================
```

| Step | Menu option | What it does |
|------|-------------|--------------|
| 1 | **[1] Setup** | Downloads FFmpeg (~100 MB) and MediaMTX into `tools\` |
| 2 | **[2] Detect Cameras** | Lists all DirectShow video devices and writes `cameras.conf` |
| 3 | **[4] Edit Config** *(optional)* | Fine-tune resolution, framerate, bitrate, quality |
| 4 | **[3] Start Streams** | Starts MediaMTX and both FFmpeg processes in a new window |
| 5 | **[5] Show URLs** | Prints the RTSP URLs to paste into ZoneMinder |

---

## cameras.conf Reference

Generated automatically by **Detect Cameras**. Edit with menu option **[4]**.

```ini
# --- Camera identifiers (DirectShow device names) ---
CAMERA1_NAME=USB Webcam
CAMERA2_STREAM=cam1

CAMERA2_NAME=USB Webcam 2
CAMERA2_STREAM=cam2

# --- Encoding ---
BITRATE=8000        # Average bitrate in kbps (8000 = ~8 Mbit/s, good for 1080p)
MAXRATE=12000       # Peak bitrate cap in kbps
CRF=18              # H.264 quality: 0=lossless, 18=visually lossless, 23=default
PRESET=veryfast     # Encoder speed: ultrafast → medium (slower = better compression)

# --- Optional overrides (leave blank for camera native) ---
RESOLUTION=         # e.g. 1920x1080
FRAMERATE=          # e.g. 30
```

### Quality presets

| Use case | CRF | Preset | Bitrate |
|---|---|---|---|
| Archival / best quality | 15 | fast | 12000 |
| **Default (visually lossless)** | **18** | **veryfast** | **8000** |
| Low bandwidth (LAN tight) | 23 | ultrafast | 4000 |

---

## Adding Cameras in ZoneMinder

1. Go to **ZoneMinder → Monitors → Add Monitor**
2. Set the following:

| Field | Value |
|---|---|
| **Source Type** | `FFmpeg` |
| **Source Path** | `rtsp://<windows-host-ip>:8554/cam1` |
| **Remote Method** | `TCP` |

3. Repeat for Camera 2 (`cam2`).

> Find `<windows-host-ip>` in menu option **[5]** or run `ipconfig` in PowerShell.

---

## File Structure

```
📁 script/
├── menu.ps1              ← Main launcher menu (start here)
├── setup.ps1             ← Downloads FFmpeg & MediaMTX
├── detect-cameras.ps1    ← Enumerates webcams, writes cameras.conf
├── start-streams.ps1     ← Starts MediaMTX + both FFmpeg streams
├── cameras.conf          ← Generated config (created by detect-cameras.ps1)
├── mediamtx.yml          ← Generated RTSP server config (created at stream start)
└── tools/
    ├── ffmpeg/           ← FFmpeg binaries (downloaded by setup.ps1)
    └── mediamtx/         ← MediaMTX binary  (downloaded by setup.ps1)
```

---

## Troubleshooting

**No cameras detected by `detect-cameras.ps1`**
- Ensure both webcams are plugged in and visible in Device Manager
- Try running PowerShell as Administrator
- Run `.\tools\ffmpeg\bin\ffmpeg.exe -list_devices true -f dshow -i dummy` manually to see raw output

**Stream drops or freezes**
- Increase `BITRATE` and `MAXRATE` in `cameras.conf`
- Switch `PRESET` to `fast` or `medium` for better compression efficiency
- Check USB bandwidth — two high-res cameras on the same USB controller can saturate it

**ZoneMinder cannot connect**
- Confirm Windows Firewall allows inbound TCP on port **8554**
- Run menu option **[5]** to confirm the correct host IP
- Test the stream locally: `.\tools\ffmpeg\bin\ffmpeg.exe -i rtsp://localhost:8554/cam1 -frames:v 1 test.jpg`

**Execution policy error**
```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

---

## Credits

- [FFmpeg](https://ffmpeg.org/) — media capture and encoding
- [MediaMTX](https://github.com/bluenviron/mediamtx) — lightweight RTSP/RTMP server
- [ZoneMinder](https://zoneminder.com/) — open-source video surveillance

---

## License

MIT
