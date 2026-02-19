# Troubleshooting Guide

## Quick diagnostics

Run these in **PowerShell on the VM** to see what Windows can detect:

```powershell
# List all recognised camera/image devices
Get-PnpDevice | Where-Object { $_.Class -eq 'Camera' -or $_.Class -eq 'Image' } |
    Select-Object Status, Class, FriendlyName

# Check if a specific vendor ID is visible (046D = Logitech, 17EF = Lenovo)
Get-PnpDevice | Where-Object { $_.InstanceId -like '*046D*' -or $_.InstanceId -like '*17EF*' } |
    Select-Object Status, FriendlyName, InstanceId

# List all cameras seen by FFmpeg (the definitive test)
& ".\tools\ffmpeg\bin\ffmpeg.exe" -f dshow -list_devices true -i dummy 2>&1
```

---

## Camera not detected by Windows at all

**Symptom:** Device does not appear in `Get-PnpDevice` output.

**Cause:** Proxmox USB passthrough is not working correctly.

**Fix on Proxmox host:**

```bash
# Verify the device is visible on the Proxmox host first
lsusb | grep -E "046d:0843|17ef:482f"

# Remove and re-add with USB 3.0 flag (required for USB 3.0 cameras like Logitech C930e)
qm set 103 -delete usb0
qm set 103 -usb0 host=046d:0843,usb3=1

# Verify the VM has an XHCI (USB 3.0) controller
grep usb /etc/pve/qemu-server/103.conf

# Full shutdown and cold start (required for USB re-enumeration)
qm shutdown 103 && qm start 103
```

> **Note:** `qm reset` is not enough — you must do a full `shutdown` + `start`.

---

## Camera visible in Device Manager but with an error / yellow triangle

**Symptom:** `Get-PnpDevice` shows the device with `Status = Error`.

**Cause:** Missing or wrong driver. UVC cameras (Logitech, most webcams) use the
built-in Windows **USB Video Device** driver — no download needed.

**Fix in PowerShell on the VM:**

```powershell
# Step 1 – Find the device instance ID
Get-PnpDevice | Where-Object { $_.InstanceId -like '*046D*' } |
    Select-Object Status, FriendlyName, InstanceId

# Step 2 – Force install the built-in UVC driver
pnputil /add-driver C:\Windows\INF\usbvideo.inf /install

# Step 3 – Cycle the device to re-trigger driver binding
$dev = Get-PnpDevice | Where-Object { $_.InstanceId -like '*046D*0843*' }
$dev | Disable-PnpDevice -Confirm:$false
Start-Sleep -Seconds 2
$dev | Enable-PnpDevice -Confirm:$false

# Step 4 – Rescan hardware
pnputil /scan-devices
```

---

## Camera visible in FFmpeg but not in Windows Settings

**Symptom:** `ffmpeg -list_devices` shows the camera, but Bluetooth & Devices > Cameras is empty.

**Cause:** Windows 11 IoT does not show the Cameras page. This is expected — the camera
is working fine and the script will use it.

---

## FFmpeg exits immediately with "Could not find video device"

**Symptom in log:**
```
Could not find video device with name [Logitech Webcam C930e] among source devices
```

**Causes and fixes:**

| Cause | Fix |
|---|---|
| Camera name in `cameras.conf` doesn't match exactly | Run `detect-cameras.ps1` again to regenerate the correct name |
| USB device enumerated late during VM boot | The script auto-restarts and will retry every 3 seconds |
| Two cameras starting too close together | Already handled — 3 second delay between each camera start |

**Verify the exact device name FFmpeg sees:**
```powershell
& ".\tools\ffmpeg\bin\ffmpeg.exe" -f dshow -list_devices true -i dummy 2>&1
```
Then compare with what is in `cameras.conf`.

---

## FFmpeg runs for a while then crashes with "Error during demuxing: I/O error"

**Symptom in log:**
```
[in#0/dshow @ ...] Error during demuxing: I/O error
```

**Cause:** USB connection dropped mid-stream. Common in VMs due to USB bandwidth
contention or power management.

**The script handles this automatically** — it will restart the crashed camera within
3 seconds. Watch for:
```
[Auto-restart] Restarting Camera 1 in 3 seconds...
[Auto-restart] Camera 1 restarted (PID 1234).
```

**To reduce the frequency of drops:**

On the **Proxmox host**, disable USB autosuspend:
```bash
echo -1 > /sys/module/usbcore/parameters/autosuspend
# To make it permanent:
echo 'options usbcore autosuspend=-1' > /etc/modprobe.d/usbcore.conf
update-initramfs -u
```

In the **VM**, disable USB selective suspend via PowerShell:
```powershell
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT
```

---

## MediaMTX exits immediately

**Symptom:**
```
ERROR: MediaMTX exited immediately.
```

**Check the log shown on screen. Common causes:**

| Error in log | Fix |
|---|---|
| `json: cannot unmarshal bool` | Upgrade to the version of the script that quotes `rtspEncryption: "no"` |
| `bind: address already in use` | Another MediaMTX is still running — run `Stop-Process -Name mediamtx -Force` |
| No output at all | Antivirus blocked `mediamtx.exe` — add an exclusion in Windows Security |

---

## Streams start but video is very slow / high latency in ZoneMinder

**In `cameras.conf`, try reducing quality to lower CPU load:**
```ini
PRESET=ultrafast
CRF=28
MAXRATE=4000
```

**In ZoneMinder**, set the monitor to:
- **Method:** `ffmpeg`
- **Options:** `-rtsp_transport tcp`

---

## Log file locations

All log files are written next to `mediamtx.exe`:

| File | Contents |
|---|---|
| `tools\mediamtx\mediamtx.log` | MediaMTX server output |
| `tools\mediamtx\mediamtx-err.log` | MediaMTX errors |
| `tools\mediamtx\ffmpeg-cam1-err.log` | FFmpeg output for Camera 1 |
| `tools\mediamtx\ffmpeg-cam2-err.log` | FFmpeg output for Camera 2 |

Read the latest log:
```powershell
Get-Content ".\tools\mediamtx\ffmpeg-cam1-err.log" | Select-Object -Last 40
```
