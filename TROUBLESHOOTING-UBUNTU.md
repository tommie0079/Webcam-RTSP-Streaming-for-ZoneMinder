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

### Module loaded but cameras still not showing (`Cannot open device /dev/video0`)

If `modprobe uvcvideo` runs without error but `v4l2-ctl --list-devices` still shows nothing, the driver loaded after the USB devices were already enumerated — so it never bound to the cameras.

**Simplest fix — reboot** (the `uvcvideo.conf` file ensures it loads before USB enumeration next time):

```bash
sudo reboot
```

After reboot, verify:

```bash
v4l2-ctl --list-devices
ls /dev/video*
```

**Alternative — force re-enumeration without rebooting:**

```bash
# Confirm the module is loaded
dmesg | grep -i uvc

# Re-bind USB devices on Bus 002 (where the cameras are)
for dev in /sys/bus/usb/devices/2-*/; do
    echo -n "$(basename $dev)" | sudo tee /sys/bus/usb/drivers/usb/unbind
    sleep 0.5
    echo -n "$(basename $dev)" | sudo tee /sys/bus/usb/drivers/usb/bind
done
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

**Symptom:** FFmpeg or `v4l2-ctl` return `Permission denied` on `/dev/video0`, even though the devices are visible in `ls /dev/video*`.

This commonly happens right after loading `uvcvideo` — the devices appear but your user has no access yet.

**Fix:** Add your user to the `video` group, then activate it in the current session:

```bash
sudo usermod -aG video $USER
newgrp video
```

Verify it worked:
```bash
v4l2-ctl --list-devices
```

The `newgrp video` applies the group immediately without logging out. The change is also permanent — on next login it will be active automatically.

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

---

## Stream is choppy / frames duplicating (`dup=` count climbing in log)

**Symptom:** FFmpeg log shows `dup=` increasing rapidly, e.g. `dup=994 drop=0`. Video is choppy or stuttery in ZoneMinder.

**Cause:** The camera is sending raw YUYV frames, which saturate USB bandwidth at full resolution/framerate. The Logitech C930e is especially prone to this — it defaults to YUYV which only delivers ~8fps over USB at 640x480.

**Fix:** Use MJPEG input format — the camera compresses frames in hardware before sending them over USB, delivering full 30fps:

In `cameras.conf`, ensure this is set:
```
INPUT_FORMAT=mjpeg
```

This is now the default in `detect-cameras.sh`. If you have an old `cameras.conf`, re-run detect:
```bash
./detect-cameras.sh
```

Or add it manually to your existing `cameras.conf`:
```bash
echo "INPUT_FORMAT=mjpeg" >> cameras.conf
```

Then restart streams:
```bash
./start-streams.sh
```

To verify it's working, the `dup=` count in the log should stay near zero.

---

## Check stream logs

Use this to quickly see the last 30 lines of both camera logs at once:

```bash
echo "=== CAM1 ===" && tail -30 tools/mediamtx/ffmpeg-cam1-err.log && echo "=== CAM2 ===" && tail -30 tools/mediamtx/ffmpeg-cam2-err.log
```

To follow logs live while streams are running:
```bash
tail -f tools/mediamtx/ffmpeg-cam1-err.log tools/mediamtx/ffmpeg-cam2-err.log
```

**What to look for:**

| Log output | Meaning |
|---|---|
| `frame= 100 fps= 30` | Stream is working normally |
| `dup=` count climbing fast | Frame duplication — see choppy stream section above |
| `Dequeued v4l2 buffer contains corrupted data` | Wrong `INPUT_FORMAT` for this camera — try blank or yuyv |
| `mjpeg_decode_dc: bad vlc` | MJPEG corruption — camera doesn't support MJPEG properly |
| `No such file or directory` | Wrong device node in `cameras.conf` |
| `Permission denied` | User not in `video` group — see permission section above |
| `Connection refused` on RTSP output | MediaMTX not running or wrong port |

---

## `git pull` fails — "Your local changes would be overwritten"

**Symptom:**
```
error: Your local changes to the following files would be overwritten by merge:
        detect-cameras.sh
        start-streams.sh
Please commit your changes or stash them before you merge.
Aborting
```

**Cause:** The VM has local edits to scripts that conflict with updated versions in the repository.

**Fix:** Discard the local changes and pull the remote versions:

```bash
git checkout -- detect-cameras.sh start-streams.sh
git pull
```

> Only do this if you haven't intentionally customised those files. Your `cameras.conf` is not tracked by git and will not be affected.
