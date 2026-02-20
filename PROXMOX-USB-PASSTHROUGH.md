# Proxmox USB Passthrough — Webcams to a VM

This guide covers passing USB webcams from a Proxmox host through to a VM so they appear as `/dev/video*` devices inside the VM.

---

## Overview

Proxmox supports two methods for USB passthrough:

| Method | Use when |
|---|---|
| Pass by **USB ID** (vendor:product) | All cameras are different models |
| Pass by **USB port** (bus-port path) | Two or more cameras share the same USB ID (same model) |

If you have two identical cameras (e.g. two Logitech C930e), passing by ID will only pass through **one** of them — Proxmox picks the first match. You must use port-based passthrough for the duplicate.

---

## Step 1 — Identify cameras on the Proxmox host

Run on the **Proxmox host**:

```bash
lsusb
```

Example output:
```
Bus 001 Device 007: ID 046d:085b Logitech, Inc. Logitech Webcam C925e
Bus 001 Device 008: ID 046d:0843 Logitech, Inc. Webcam C930e
Bus 002 Device 004: ID 046d:0843 Logitech, Inc. Webcam C930e
```

To see the bus/port tree (needed for port-based passthrough):

```bash
lsusb -t
```

Example output (relevant portions):
```
/:  Bus 001.Port 001: Dev 001, Class=root_hub, Driver=ehci-pci/2p, 480M
    |__ Port 001: Dev 002, If 0, Class=Hub, Driver=hub/6p, 480M
        |__ Port 004: Dev 007, If 0, Class=Video, Driver=usbfs, 480M   ← C925e
        |__ Port 005: Dev 008, If 0, Class=Video, Driver=uvcvideo, 480M ← C930e #1
/:  Bus 002.Port 001: Dev 001, Class=root_hub, Driver=ehci-pci/2p, 480M
    |__ Port 001: Dev 002, If 0, Class=Hub, Driver=hub/8p, 480M
        |__ Port 006: Dev 004, If 0, Class=Video, Driver=usbfs, 480M   ← C930e #2
```

Map each camera to its **port path** (bus number + port chain from the tree):

| Camera | Bus | Port path | Proxmox port string |
|---|---|---|---|
| Logitech C925e | 1 | 1 → 4 | `1-1.4` |
| Logitech C930e #1 | 1 | 1 → 5 | `1-1.5` |
| Logitech C930e #2 | 2 | 1 → 6 | `2-1.6` |

> **Reading the port string:** Start from the root hub port, follow the chain of `|__ Port N` entries down to the device. Join with dots: bus `-` first_port `.` next_port …

---

## Step 2 — Check current passthrough config

```bash
qm config 104 | grep usb
```

Example output showing two already configured:
```
usb0: host=046d:085b,usb3=1
usb1: host=2-1.6,usb3=1
```

The slot names are `usb0`, `usb1`, `usb2` … — use the next available number for each camera you add.

---

## Step 3 — Add missing cameras

### Pass through by USB ID (for unique camera models)

```bash
qm set 104 -usb0 host=046d:085b,usb3=1   # C925e
```

### Pass through by USB port (for duplicate models or to be explicit)

```bash
qm set 104 -usb1 host=2-1.6,usb3=1   # C930e on Bus 2, port 1.6
qm set 104 -usb2 host=1-1.5,usb3=1   # C930e on Bus 1, port 1.5
```

> **Note:** The `usb3=1` flag enables USB 3.0 speed. Webcams are USB 2.0 but this flag does no harm and is good practice.

---

## Step 4 — Apply the changes

If the VM is currently **running**, USB devices added with `qm set` are hot-plugged automatically — no reboot needed. Verify immediately inside the VM:

```bash
lsusb
v4l2-ctl --list-devices
```

If the cameras don't appear, do a full stop/start:

```bash
qm stop 104 && qm start 104
```

---

## Step 5 — Verify inside the VM

After the VM boots, all three cameras should appear:

```bash
lsusb
# Should show all three cameras

v4l2-ctl --list-devices
# Should show /dev/video0, /dev/video2, /dev/video4 (one pair per camera)
```

Then re-run camera detection to update `cameras.conf`:

```bash
./detect-cameras.sh
```

---

## Troubleshooting

### Camera visible in `lsusb` on host but not in VM

- Check that the passthrough entry exists: `qm config 104 | grep usb`
- If you passed by ID and have duplicate cameras, switch to port-based passthrough (Step 3)
- Try a full VM stop/start: `qm stop 104 && qm start 104`

### Camera in VM but not in `v4l2-ctl --list-devices`

The `uvcvideo` kernel module may not be loaded. See the [uvcvideo section in TROUBLESHOOTING-UBUNTU.md](TROUBLESHOOTING-UBUNTU.md#cameras-visible-in-lsusb-but-not-in-v4l2-ctl---list-devices).

### Two cameras of the same model — only one passes through

Proxmox de-duplicates by USB ID when using vendor:product — only one device is passed per ID. Use port-based passthrough for all duplicates (Step 3).

### Port path changes after reboot

USB port paths are stable as long as cameras stay in the same physical USB ports on the host. If you move a camera to a different port, update the `qm set` entry with the new port string.
