# Running on Ubuntu / Linux

This folder contains bash equivalents of the Windows PowerShell scripts.

| Windows script         | Linux equivalent        | Purpose                                  |
|------------------------|-------------------------|------------------------------------------|
| `menu.ps1`             | `menu.sh`               | Main launcher menu                       |
| `detect-cameras.ps1`   | `detect-cameras.sh`     | Detect cameras, write `cameras.conf`     |
| `start-streams.ps1`    | `start-streams.sh`      | Start MediaMTX + FFmpeg, stream via RTSP |

---

## Quick start

### 1 — Install dependencies

```bash
sudo apt update
sudo apt install -y ffmpeg v4l-utils
```

### 2 — Install MediaMTX (Linux binary)

```bash
mkdir -p tools/mediamtx
cd /tmp
wget https://github.com/bluenviron/mediamtx/releases/latest/download/mediamtx_linux_amd64.tar.gz
tar -xzf mediamtx_linux_amd64.tar.gz -C ~/path/to/scripts/tools/mediamtx/
chmod +x ~/path/to/scripts/tools/mediamtx/mediamtx
```

> Replace `~/path/to/scripts/` with the actual folder path.

### 3 — Make scripts executable

```bash
chmod +x menu.sh detect-cameras.sh start-streams.sh
```

### 4 — Run the menu

```bash
./menu.sh
```

Or run directly:

```bash
./detect-cameras.sh       # detect cameras, write cameras.conf
./start-streams.sh        # start streaming (Ctrl+C to stop)
```

---

## Key differences from Windows

| Windows (DirectShow)                  | Linux (V4L2)                        |
|---------------------------------------|-------------------------------------|
| Camera identified by name string      | Camera identified by device path    |
| `CAMERA1_NAME=Logitech Webcam C930e`  | `CAMERA1_DEVICE=/dev/video0`        |
| `ffmpeg -f dshow -i "video=Name"`     | `ffmpeg -f v4l2 -i /dev/video0`     |
| `mediamtx.exe`                        | `mediamtx` (Linux binary)           |

---

## Check cameras manually

```bash
# List all V4L2 devices with friendly names
v4l2-ctl --list-devices

# List just device nodes
ls /dev/video*

# Test a device with FFmpeg
ffmpeg -f v4l2 -i /dev/video0 -t 3 /tmp/test.mp4
```

---

## Proxmox USB passthrough

If running in a Proxmox VM, USB cameras must be passed through from the host:

```bash
# On Proxmox host — check cameras are visible
lsusb | grep -E "046d:0843|17ef:482f"

# Pass through with USB 3.0 flag
qm set 103 --usb0 host=046d:0843,usb3=1

# Full stop/start to enumerate USB
qm stop 103 && qm start 103
```

Inside the VM, verify the camera appeared:
```bash
v4l2-ctl --list-devices
```

---

## Log files

All logs are written to `tools/mediamtx/`:

| File                        | Contents                  |
|-----------------------------|---------------------------|
| `mediamtx.log`              | MediaMTX server output    |
| `mediamtx-err.log`          | MediaMTX errors           |
| `ffmpeg-cam1-err.log`       | FFmpeg output for Camera 1|
| `ffmpeg-cam2-err.log`       | FFmpeg output for Camera 2|

```bash
# Watch Camera 1 log live
tail -f tools/mediamtx/ffmpeg-cam1-err.log
```
