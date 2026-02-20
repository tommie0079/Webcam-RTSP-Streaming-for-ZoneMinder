# 📷 Webcam RTSP Streaming for ZoneMinder

Broadcast any number of USB webcams as independent RTSP streams, ready to import into [ZoneMinder](https://zoneminder.com/) or any other NVR/VMS.

Built with **FFmpeg** (H.264 capture) and **MediaMTX** (RTSP server).

---

## Platform guides

| Platform | Guide | Scripts |
|---|---|---|
| **Windows 11** (IoT or any edition) | [README-WINDOWS.md](README-WINDOWS.md) | `menu.ps1`, `detect-cameras.ps1`, `start-streams.ps1` |
| **Ubuntu / Linux** | [README-UBUNTU.md](README-UBUNTU.md) | `menu.sh`, `detect-cameras.sh`, `start-streams.sh` |

---

## Architecture

```
Webcam 1 ──[FFmpeg]──┐
Webcam 2 ──[FFmpeg]──┼──► MediaMTX (RTSP :8554) ──► ZoneMinder
Webcam N ──[FFmpeg]──┘
```

Each camera gets its own RTSP path:

| Stream | URL |
|---|---|
| Camera 1 | `rtsp://<host-ip>:8554/cam1` |
| Camera 2 | `rtsp://<host-ip>:8554/cam2` |
| Camera N | `rtsp://<host-ip>:8554/camN` |

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for camera driver issues, FFmpeg errors, MediaMTX problems, and ZoneMinder connection issues.

---

## Credits

- [FFmpeg](https://ffmpeg.org/) — media capture and encoding
- [MediaMTX](https://github.com/bluenviron/mediamtx) — lightweight RTSP server
- [ZoneMinder](https://zoneminder.com/) — open-source video surveillance

---

## License

MIT
