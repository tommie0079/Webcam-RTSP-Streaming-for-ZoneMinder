#!/usr/bin/env bash
# menu.sh
# Main launcher menu for the webcam streaming setup on Ubuntu/Linux.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_status() {
    local ffmpeg_ok=0 mtx_ok=0 conf_ok=0

    command -v ffmpeg &>/dev/null       && ffmpeg_ok=1
    [[ -x "$SCRIPT_DIR/tools/mediamtx/mediamtx" ]] && mtx_ok=1
    [[ -f "$SCRIPT_DIR/cameras.conf" ]]             && conf_ok=1

    local ffmpeg_str mtx_str conf_str
    ffmpeg_str=$([ $ffmpeg_ok -eq 1 ] && echo "[OK]" || echo "[NOT INSTALLED]")
    mtx_str=$(  [ $mtx_ok    -eq 1 ] && echo "[OK]" || echo "[NOT INSTALLED]")
    conf_str=$( [ $conf_ok   -eq 1 ] && echo "[OK]" || echo "[NOT FOUND]")

    local c_ffmpeg c_mtx c_conf RESET='\033[0m' GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[0;33m'
    c_ffmpeg=$([ $ffmpeg_ok -eq 1 ] && echo -e "$GREEN" || echo -e "$RED")
    c_mtx=$(   [ $mtx_ok   -eq 1 ] && echo -e "$GREEN" || echo -e "$RED")
    c_conf=$(  [ $conf_ok  -eq 1 ] && echo -e "$GREEN" || echo -e "$YELLOW")

    echo "  Status:"
    echo -e "    ffmpeg       : ${c_ffmpeg}${ffmpeg_str}${RESET}"
    echo -e "    MediaMTX     : ${c_mtx}${mtx_str}${RESET}"
    echo -e "    cameras.conf : ${c_conf}${conf_str}${RESET}"
}

show_urls() {
    local conf_file="$SCRIPT_DIR/cameras.conf"
    if [[ ! -f "$conf_file" ]]; then
        echo "[!] cameras.conf not found. Run option 2 first."
        return
    fi

    local ip
    ip=$(ip -4 route get 1.0.0.0 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
    ip="${ip:-<your-ip>}"

    echo ""
    echo "  RTSP Stream URLs for ZoneMinder:"
    echo ""

    local n=1
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# || -z "${key// }" ]] && continue
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        if [[ "$key" == "CAMERA${n}_STREAM" ]]; then
            echo "    Camera $n: rtsp://${ip}:8554/${value}"
            n=$((n+1))
        fi
    done < "$conf_file"
    echo ""
    echo "  In ZoneMinder: Source Type = FFmpeg, Source Path = rtsp://..."
    echo ""
}

install_deps() {
    echo ""
    echo "Installing dependencies..."
    echo ""
    sudo apt update
    sudo apt install -y ffmpeg v4l-utils
    echo ""
    echo "ffmpeg and v4l-utils installed."
    echo ""
    echo "--- MediaMTX ---"
    echo "Download the latest Linux amd64 binary from:"
    echo "  https://github.com/bluenviron/mediamtx/releases"
    echo ""
    echo "Then place the binary at:"
    echo "  $SCRIPT_DIR/tools/mediamtx/mediamtx"
    echo ""
    echo "Quick install (adjust version as needed):"
    echo "  mkdir -p $SCRIPT_DIR/tools/mediamtx"
    echo "  cd /tmp"
    echo "  wget https://github.com/bluenviron/mediamtx/releases/latest/download/mediamtx_linux_amd64.tar.gz"
    echo "  tar -xzf mediamtx_linux_amd64.tar.gz -C $SCRIPT_DIR/tools/mediamtx/"
    echo "  chmod +x $SCRIPT_DIR/tools/mediamtx/mediamtx"
    echo ""
}

main_menu() {
    while true; do
        clear
        echo "========================================================="
        echo "       Webcam RTSP Streaming - Main Menu (Linux)         "
        echo "========================================================="
        echo ""
        show_status
        echo ""
        echo "---------------------------------------------------------"
        echo ""
        echo "  [1]  Install deps   - Install ffmpeg, v4l-utils + MediaMTX instructions"
        echo "  [2]  Detect cameras - Find webcams & create cameras.conf"
        echo "  [3]  Start streams  - Launch RTSP streams (keep open!)"
        echo "  [4]  Edit config    - Open cameras.conf in nano"
        echo "  [5]  Show URLs      - Print stream URLs for ZoneMinder"
        echo "  [q]  Quit"
        echo ""
        echo "========================================================="
        echo ""
        read -rp "  Select an option: " choice

        case "$choice" in
            1)
                install_deps
                read -rp "  Press Enter to continue..." _
                ;;
            2)
                echo ""
                bash "$SCRIPT_DIR/detect-cameras.sh"
                read -rp "  Press Enter to continue..." _
                ;;
            3)
                echo ""
                bash "$SCRIPT_DIR/start-streams.sh"
                # start-streams.sh blocks until Ctrl+C, so we return here after it exits
                read -rp "  Press Enter to continue..." _
                ;;
            4)
                if [[ -f "$SCRIPT_DIR/cameras.conf" ]]; then
                    nano "$SCRIPT_DIR/cameras.conf"
                else
                    echo "  cameras.conf not found. Run option 2 first."
                    read -rp "  Press Enter to continue..." _
                fi
                ;;
            5)
                show_urls
                read -rp "  Press Enter to continue..." _
                ;;
            q|Q)
                echo "Bye."
                exit 0
                ;;
            *)
                echo "  Invalid option."
                sleep 1
                ;;
        esac
    done
}

main_menu
