# Troubleshooting — Ubuntu / Linux

---

## Cameras visible in `lsusb` but not in `v4l2-ctl --list-devices`

**Symptom:** `lsusb` shows the cameras, but `v4l2-ctl --list-devices` returns nothing and `detect-cameras.sh` reports "No V4L2 video devices found".

**Cause:** The `uvcvideo` kernel driver (USB Video Class) is not loaded. This is common on minimal Ubuntu server installs.

**Fix:**

```bash
# Load the driver now
sudo modprobe uvcvideo

# Verify cameras are now visible
v4l2-ctl --list-devices
ls /dev/video*
```

**Make it permanent** (loads automatically on every boot):

```bash
echo "uvcvideo" | sudo tee /etc/modules-load.d/uvcvideo.conf
```

---

## No V4L2 devices found — other causes

If loading `uvcvideo` does not help:

```bash
# Check for USB errors in the kernel log
dmesg | grep -i usb | tail -20

# Check if the camera is enumerated at all
lsusb | grep -E "046d:0843|17ef:482f"
```

If cameras are missing from `lsusb` entirely, USB passthrough from Proxmox is not configured — see the [Proxmox USB passthrough](README-UBUNTU.md#proxmox-usb-passthrough) section.

---

## Permission denied on `/dev/videoN`

**Symptom:** FFmpeg or `v4l2-ctl` return `Permission denied` on `/dev/video0`.

**Fix:** Add your user to the `video` group:

```bash
sudo usermod -aG video $USER
```

Then log out and back in (or run `newgrp video` in the current session).

---

## MediaMTX won't start — port already in use

**Symptom:** MediaMTX exits immediately with `bind: address already in use`.

**Fix:** Check what is using port 8554:

```bash
sudo ss -tlnp | grep 8554
```

Kill the conflicting process or change the RTSP port in `mediamtx.yml`.

---

## FFmpeg fails — "Invalid data found when processing input"

**Symptom:** FFmpeg exits with this error after detect-cameras.sh runs fine.

**Cause:** The detected `/dev/videoN` node is a metadata node, not a capture node.

**Fix:** Re-run `detect-cameras.sh` — it filters to capture nodes automatically. If the wrong device ended up in `cameras.conf`, check which node works:

```bash
v4l2-ctl --list-devices
# Try each node for the camera — the correct one will respond
v4l2-ctl -d /dev/video0 --get-fmt-video
v4l2-ctl -d /dev/video2 --get-fmt-video
```

Update `cameras.conf` with the correct `CAMERA1_DEVICE=` path.
