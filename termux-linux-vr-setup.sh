#!/data/data/com.termux/files/usr/bin/bash

#######################################################
#  Termux Linux VR Setup Script
#  
#  Features:
#  - Choice of Desktop Environment (XFCE, LXQt, MATE, KDE)
#  - Smart GPU acceleration detection
#      Quest / Horizon OS: VirGL (Adreno via Android's GLES driver)
#      Other Adreno phones: Turnip/Zink
#  - Productivity and Media tools (VLC, Chromium)
#  - Python & Web Dev environment pre-installed
#  - Windows App Support (Wine/Hangover)
#  - Termux:X11 autolaunch
#  - Special edition banners :>
#######################################################

# ============== CONFIGURATION ==============
TOTAL_STEPS=12
REPO_TARBALL="https://github.com/drakfyre/termux-linux-vr/archive/refs/heads/main.tar.gz"
ASSET_DIR=""
CURRENT_STEP=0
DE_CHOICE="1"
DE_NAME="XFCE4"

# ============== COLORS ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# ============== PROGRESS FUNCTIONS ==============
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    
    FILLED=$((PERCENT / 5))
    EMPTY=$((20 - FILLED))
    
    BAR="${GREEN}"
    for ((i=0; i<FILLED; i++)); do BAR+="*"; done
    BAR+="${GRAY}"
    for ((i=0; i<EMPTY; i++)); do BAR+="-"; done
    BAR+="${NC}"
    
    echo ""
    echo -e "${WHITE}------------------------------------------------------------${NC}"
    echo -e "${CYAN}  OVERALL PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}------------------------------------------------------------${NC}"
    echo ""
}

spinner() {
    local pid=$1
    local message=$2
    local spin='-\|/'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r  [*] ${message} ${CYAN}${spin:$i:1}${NC}  "
        sleep 0.1
    done
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r  [+] ${message}                    \n"
    else
        printf "\r  [-] ${message} ${RED}(failed)${NC}     \n"
    fi
    
    return $exit_code
}

install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}
    (DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confold" $pkg > /dev/null 2>&1) &
    spinner $! "Installing ${name}..."
}

# ============== EXTRA FILES (BANNERS) ==============
# The one-line install only downloads this script, so fetch the rest of the
# repo (Banners/, BannerBash.txt) from GitHub when it isn't next to us.
find_assets() {
    local script_dir
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    for dir in "$script_dir" "$PWD"; do
        if [ -f "$dir/BannerBash.txt" ] && [ -d "$dir/Banners" ]; then
            ASSET_DIR="$dir"
            return 0
        fi
    done
    local tmp="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/termux-linux-vr-assets"
    rm -rf "$tmp" && mkdir -p "$tmp"
    if curl -fsSL "$REPO_TARBALL" | tar -xz -C "$tmp" --strip-components=1 2>/dev/null \
        && [ -f "$tmp/BannerBash.txt" ] && [ -d "$tmp/Banners" ]; then
        ASSET_DIR="$tmp"
        return 0
    fi
    echo -e "${YELLOW}[!] Couldn't download the banner files; skipping banners.${NC}"
    return 1
}

# ============== BANNER ==============
show_banner() {
    clear
    echo -e "${CYAN}"
    [ -n "$ASSET_DIR" ] && cat "$ASSET_DIR/Banners/Quest.txt"
    cat << 'BANNER'
    -------------------------------------------
                                               
            Termux Linux Setup Script          
                                               
    -------------------------------------------
BANNER
    echo -e "${NC}"
    echo ""
}

# ============== DEVICE & USER SELECTION ==============
setup_environment() {
    echo -e "${PURPLE}[*] Detecting your device...${NC}"
    echo ""
    
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    CPU_ABI=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a")
    DEVICE_MANUFACTURER=$(getprop ro.product.manufacturer 2>/dev/null || echo "Unknown")
    GPU_VENDOR=$(getprop ro.hardware.egl 2>/dev/null || echo "")
    
    echo -e "  [*] Device: ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  [*] Android: ${WHITE}${ANDROID_VERSION}${NC}"
    
    # Quest headsets (Horizon OS) block the KGSL GPU memory allocation that
    # Turnip needs, so Turnip/Zink can't work there. VirGL forwards OpenGL to
    # Android's own Adreno driver instead: GLES 3.2 / desktop GL 2.1.
    if [[ "${DEVICE_MANUFACTURER,,}" == "oculus" ]] || [[ "${DEVICE_MANUFACTURER,,}" == "meta" ]] || [[ "${DEVICE_BRAND,,}" == "oculus" ]] || [[ "$DEVICE_MODEL" == *"Quest"* ]]; then
        GPU_DRIVER="virgl"
        echo -e "  [*] GPU: ${WHITE}Adreno (Meta Quest) - VirGL Hardware Acceleration${NC}"
    elif [[ "$GPU_VENDOR" == *"adreno"* ]] || [[ "$DEVICE_BRAND" == *"samsung"* ]] || [[ "$DEVICE_BRAND" == *"Samsung"* ]] || [[ "$DEVICE_BRAND" == *"oneplus"* ]] || [[ "$DEVICE_BRAND" == *"xiaomi"* ]]; then
        GPU_DRIVER="freedreno"
        echo -e "  [*] GPU: ${WHITE}Adreno (Qualcomm) - Hardware Acceleration Supported${NC}"
    else
        GPU_DRIVER="zink_native"
        echo -e "  [*] GPU: ${WHITE}Non-Adreno - Zink Native Vulkan${NC}"
        echo -e "${YELLOW}      [!] WARNING: Your device may not fully support advanced GPU acceleration.${NC}"
        echo -e "${YELLOW}      [!] We HIGHLY RECOMMEND choosing LXQt or XFCE for smooth performance.${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}Please choose your Desktop Environment:${NC}"
    echo -e "  ${WHITE}1) XFCE4${NC}       (Recommended - Fast, Customizable, macOS style dock)"
    echo -e "  ${WHITE}2) LXQt${NC}        (Ultra lightweight - Best for low end devices)"
    echo -e "  ${WHITE}3) MATE${NC}        (Classic UI, moderately heavy)"
    echo -e "  ${WHITE}4) KDE Plasma${NC}  (Very heavy - Modern, Windows 11 style, requires strong GPU/RAM)"
    echo ""
    while true; do
        read -p "Enter number (1-4) [default: 1]: " DE_INPUT
        DE_INPUT=${DE_INPUT:-1}
        if [[ "$DE_INPUT" =~ ^[1-4]$ ]]; then
            DE_CHOICE="$DE_INPUT"
            break
        else
            echo "Invalid input. Please enter 1, 2, 3, or 4."
        fi
    done
    
    case $DE_CHOICE in
        1) DE_NAME="XFCE4";;
        2) DE_NAME="LXQt";;
        3) DE_NAME="MATE";;
        4) DE_NAME="KDE Plasma";;
    esac
    
    echo -e "\n${GREEN}[+] Selected: ${DE_NAME}.${NC}"
    sleep 2
}

# ============== STEP 1: UPDATE SYSTEM ==============
step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating system packages...${NC}"
    echo ""
    (DEBIAN_FRONTEND=noninteractive apt-get update -y > /dev/null 2>&1) &
    spinner $! "Updating package lists..."
    (DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q -o Dpkg::Options::="--force-confold" > /dev/null 2>&1) &
    spinner $! "Upgrading installed packages..."
}

# ============== STEP 2: INSTALL REPOSITORIES ==============
step_repos() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Adding package repositories...${NC}"
    echo ""
    install_pkg "x11-repo" "X11 Repository"
    install_pkg "tur-repo" "TUR Repository"
}

# ============== STEP 3: INSTALL TERMUX-X11 ==============
step_x11() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Termux-X11...${NC}"
    echo ""
    install_pkg "termux-x11-nightly" "Termux-X11 Display Server"
    install_pkg "xorg-xrandr" "XRandR (Display Settings)"
}

# ============== STEP 4: INSTALL DESKTOP ==============
step_desktop() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing ${DE_NAME} Desktop...${NC}"
    echo ""
    
    if [ "$DE_CHOICE" == "1" ]; then
        # XFCE
        install_pkg "xfce4" "XFCE4 Desktop"
        install_pkg "xfce4-terminal" "XFCE4 Terminal"
        install_pkg "xfce4-whiskermenu-plugin" "Whisker Menu"
        install_pkg "plank-reloaded" "Plank Dock"
        install_pkg "thunar" "Thunar File Manager"
        install_pkg "mousepad" "Mousepad Editor"
    elif [ "$DE_CHOICE" == "2" ]; then
        # LXQt
        install_pkg "lxqt" "LXQt Desktop"
        install_pkg "qterminal" "QTerminal"
        install_pkg "pcmanfm-qt" "PCManFM-Qt"
        install_pkg "featherpad" "FeatherPad"
    elif [ "$DE_CHOICE" == "3" ]; then
        # MATE
        install_pkg "mate" "MATE Desktop"
        install_pkg "mate-tweak" "MATE Tweak"
        install_pkg "plank-reloaded" "Plank Dock"
        install_pkg "mate-terminal" "MATE Terminal"
    elif [ "$DE_CHOICE" == "4" ]; then
        # KDE
        install_pkg "plasma-desktop" "KDE Plasma"
        install_pkg "konsole" "Konsole"
        install_pkg "dolphin" "Dolphin"
    fi
}

# ============== STEP 5: INSTALL GPU DRIVERS ==============
step_gpu() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing GPU Acceleration...${NC}"
    echo ""
    if [ "$GPU_DRIVER" == "virgl" ]; then
        # Needs the current Termux "mesa" (26.x). The old "mesa-zink" (22.x)
        # crashes with "stack corruption" under VirGL; installing "mesa"
        # replaces it automatically (the two packages conflict).
        install_pkg "mesa" "Mesa OpenGL"
        install_pkg "virglrenderer-android" "VirGL Renderer (Android GLES bridge)"
    else
        install_pkg "mesa-zink" "Mesa Zink Core"
        if [ "$GPU_DRIVER" == "freedreno" ]; then
            install_pkg "mesa-vulkan-icd-freedreno" "Turnip Adreno Driver"
        fi
        install_pkg "vulkan-loader-android" "Vulkan Loader"
    fi
    install_pkg "mesa-demos" "Mesa Demos (glxinfo, glxgears)"
}

# ============== STEP 6: INSTALL AUDIO ==============
step_audio() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Audio...${NC}"
    echo ""
    install_pkg "pulseaudio" "PulseAudio Server"
}

# ============== STEP 7: INSTALL APPS (VS Code, VLC, etc.) ==============
step_apps() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Media & Dev Apps...${NC}"
    echo ""
    # Chromium uses the GPU with no extra flags: it falls back to ANGLE on
    # top of the desktop's GL driver, so WebGL/WebGPU run on the GPU.
    install_pkg "chromium" "Chromium Browser"
    install_pkg "vlc" "VLC Media Player"
    install_pkg "git" "Git Version Control"
    install_pkg "wget" "Wget Downloader"
    install_pkg "curl" "cURL"
}

# ============== STEP 8: PYTHON & FLASK DEMO ==============
step_python() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Python Environment...${NC}"
    echo ""
    install_pkg "python" "Python 3"
    
    (pip install flask > /dev/null 2>&1) &
    spinner $! "Installing Flask Web Framework..."
    
    # Create Python Demo
    mkdir -p ~/demo_python
    cat > ~/demo_python/app.py << 'EOF'
from flask import Flask, render_template_string
app = Flask(__name__)

@app.route("/")
def hello():
    return render_template_string("""
    <html>
        <body style="background-color:#1e1e1e;color:#00ff00;font-family:monospace;text-align:center;padding:50px">
            <h1>Hardware Accelerated Linux</h1>
            <h3>This Python server is running natively on a Snapdragon Android phone!</h3>
        </body>
    </html>
    """)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF
    echo -e "  [+] Python Web Demo created in ~/demo_python"
}

# ============== STEP 9: INSTALL WINE ==============
step_wine() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Windows Support (Wine/Box64)...${NC}"
    echo ""
    (pkg remove wine-stable -y > /dev/null 2>&1) &
    spinner $! "Removing old Wine versions..."
    
    install_pkg "hangover-wine" "Wine Compatibility Layer"
    install_pkg "hangover-wowbox64" "Box64 Wrapper"
    
    ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/wine /data/data/com.termux/files/usr/bin/wine
    ln -sf /data/data/com.termux/files/usr/opt/hangover-wine/bin/winecfg /data/data/com.termux/files/usr/bin/winecfg
}

# ============== STEP 10: CREATE LAUNCHERS ==============
step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring Startup Scripts...${NC}"
    echo ""
    
    mkdir -p ~/.config
    
    # Base XDG variables for Termux Paths
    XDG_INJECT="export XDG_DATA_DIRS=/data/data/com.termux/files/usr/share:\${XDG_DATA_DIRS}\nexport XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg:\${XDG_CONFIG_DIRS}"

    # KDE needs a special env injection
    if [ "$DE_CHOICE" == "4" ]; then
        mkdir -p ~/.config/plasma-workspace/env
        echo -e "#!/data/data/com.termux/files/usr/bin/bash\n$XDG_INJECT" > ~/.config/plasma-workspace/env/xdg_fix.sh
        chmod +x ~/.config/plasma-workspace/env/xdg_fix.sh
    fi
    
    # GPU & Environment Config
    if [ "$GPU_DRIVER" == "virgl" ]; then
    cat > ~/.config/linux-gpu.sh << 'EOF'
# GPU acceleration for the Termux:X11 desktop on Meta Quest, via VirGL.
# Turnip/Zink can't work here: Horizon OS blocks KGSL GPU memory allocation.
# VirGL forwards GL to Android's own Adreno driver: GLES 3.2 / desktop GL 2.1.
# Check it with: glxinfo -B | grep renderer   (should say "virgl (Adreno ...)")
if ! pgrep -f '^virgl_test_server_android' >/dev/null 2>&1; then
  virgl_test_server_android >"${TMPDIR:-/data/data/com.termux/files/usr/tmp}/virgl.log" 2>&1 &
  sleep 1
fi
export GALLIUM_DRIVER=virpipe
unset MESA_LOADER_DRIVER_OVERRIDE
EOF
    else
    cat > ~/.config/linux-gpu.sh << EOF
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
EOF
    fi

    if [ "$DE_CHOICE" == "4" ]; then
        echo "export KWIN_COMPOSE=O2ES" >> ~/.config/linux-gpu.sh
    else
        echo -e "$XDG_INJECT" >> ~/.config/linux-gpu.sh
    fi

    # No plank
    rm -f ~/.config/autostart/plank.desktop 2>/dev/null

    # Determine execution commands and kill commands based on DE
    case $DE_CHOICE in
        1)
            EXEC_CMD="exec startxfce4"
            KILL_CMD="pkill -9 xfce4-session"
            ;;
        2)
            EXEC_CMD="exec startlxqt"
            KILL_CMD="pkill -9 lxqt-session"
            ;;
        3)
            EXEC_CMD="exec mate-session"
            KILL_CMD="pkill -9 mate-session"
            ;;
        4)
            EXEC_CMD="(sleep 5 && pkill -9 plasmashell && plasmashell) > /dev/null 2>&1 &\nexec startplasma-x11"
            KILL_CMD="pkill -9 startplasma-x11; pkill -9 kwin_x11"
            ;;
    esac

    # Main Launcher
    cat > ~/start-linux.sh << LAUNCHEREOF
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "[*] Starting ${DE_NAME}..."
echo ""
source ~/.config/linux-gpu.sh 2>/dev/null

echo "[*] Cleaning up old sessions..."
pkill -9 -f "termux.x11" 2>/dev/null
${KILL_CMD} 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
# A stale X lock survives a device reboot and blocks the desktop from starting
rm -f "\$PREFIX/tmp/.X0-lock" "\$PREFIX/tmp/.X11-unix/X0"

unset PULSE_SERVER
pulseaudio --kill 2>/dev/null
rm -f "\$PREFIX"/tmp/pulse-*/pid   # stale after a reboot; makes pulseaudio think it is running
sleep 0.5
echo "[*] Starting audio server..."
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null
export PULSE_SERVER=127.0.0.1

echo "[*] Starting X11 server..."
termux-x11 :0 -ac &
sleep 3
export DISPLAY=:0

am start -n com.termux.x11/.MainActivity

echo "-----------------------------------------------"
echo "  [*] Install Termux-X11 app to view desktop!"
echo "-----------------------------------------------"
echo ""
${EXEC_CMD}
LAUNCHEREOF
    chmod +x ~/start-linux.sh
    echo -e "  [+] Created ~/start-linux.sh"
    
    # Stopper
    cat > ~/stop-linux.sh << STOPEOF
#!/data/data/com.termux/files/usr/bin/bash
echo "Stopping ${DE_NAME}..."
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "pulseaudio" 2>/dev/null
${KILL_CMD} 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
pkill -f "^virgl_test_server_android" 2>/dev/null
echo "Desktop stopped."
STOPEOF
    chmod +x ~/stop-linux.sh
    echo -e "  [+] Created ~/stop-linux.sh"
}

# ============== STEP 11: CREATE SHORTCUTS ==============
step_shortcuts() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Desktop Shortcuts...${NC}"
    echo ""
    mkdir -p ~/Desktop
    
    # App shortcuts
    cat > ~/Desktop/Chromium.desktop << 'EOF'
[Desktop Entry]
Name=Chromium
Exec=chromium-browser %U
Icon=chromium
Type=Application
EOF

    cat > ~/Desktop/VLC.desktop << 'EOF'
[Desktop Entry]
Name=VLC Media Player
Exec=vlc
Icon=vlc
Type=Application
EOF

    cat > ~/Desktop/Wine_Config.desktop << 'EOF'
[Desktop Entry]
Name=Wine Config (Windows)
Exec=wine winecfg
Icon=wine
Type=Application
EOF

    # Dynamic terminal shortcut
    local term_cmd="xfce4-terminal"
    local term_icon="utilities-terminal"
    if [ "$DE_CHOICE" == "2" ]; then term_cmd="qterminal"; fi
    if [ "$DE_CHOICE" == "3" ]; then term_cmd="mate-terminal"; fi
    if [ "$DE_CHOICE" == "4" ]; then term_cmd="konsole"; fi
    
    cat > ~/Desktop/Terminal.desktop << EOF
[Desktop Entry]
Name=Terminal
Exec=${term_cmd}
Icon=${term_icon}
Type=Application
EOF

    chmod +x ~/Desktop/*.desktop 2>/dev/null
    echo -e "  [+] Added Chromium, VLC, Wine, and Terminal shortcuts."

    # Make Chromium the default web browser
    if command -v xdg-mime > /dev/null 2>&1; then
        for mt in x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml; do
            xdg-mime default chromium.desktop "$mt" > /dev/null 2>&1
        done
    fi
    if [ "$DE_CHOICE" == "1" ]; then
        mkdir -p ~/.config/xfce4
        touch ~/.config/xfce4/helpers.rc
        sed -i '/^WebBrowser=/d' ~/.config/xfce4/helpers.rc
        echo "WebBrowser=chromium" >> ~/.config/xfce4/helpers.rc
    fi
    echo -e "  [+] Set Chromium as the default browser."
}

# ============== STEP 12: COPY BANNERS AND AUTOSTART ==============
step_banners()
{
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Banners & Autostart...${NC}"
    echo ""
    if [ -n "$ASSET_DIR" ]; then
        mkdir -p ~/Banners
        cp -r "$ASSET_DIR/Banners/." ~/Banners/
        cp -f "$ASSET_DIR/BannerBash.txt" ~/.bashrc
        echo -e "  [+] Installed terminal banners and ~/.bashrc"
    else
        echo -e "  [-] Banner files not available ${RED}(skipped)${NC}"
    fi
    
    # Only auto-start the desktop in real interactive terminals, not in
    # scripts or tool shells (e.g. Claude Code), which would otherwise hang.
    cat > ~/.profile << 'EOF'
if [ -z "$CLAUDECODE" ] && [[ $- == *i* ]]; then
  ~/start-linux.sh
fi
EOF
}

# ============== COMPLETION ==============
show_completion() {
    echo ""
    echo -e "${GREEN}"
    cat << 'COMPLETE'
    ---------------------------------------------------------------
             [*]  INSTALLATION COMPLETE!  [*]                      
    ---------------------------------------------------------------
COMPLETE
    echo -e "${NC}"
    
    echo -e "${WHITE}[*] Your ${DE_NAME} environment is ready.${NC}"
    echo -e "${CYAN}[*] Installed Software:${NC}"
    echo "    - Python (Flask Demo located in ~/demo_python)"
    echo "    - Chromium Browser & VLC Media Player"
    echo "    - Wine & Hangover (Windows PC App compatibility)"
    if [ "$GPU_DRIVER" == "virgl" ]; then
        echo "    - GPU Hardware Acceleration Enabled (VirGL -> Adreno, GLES 3.2)"
    else
        echo "    - GPU Hardware Acceleration Enabled (Zink)"
    fi
    echo ""
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo -e "${WHITE}[*] TO START THE DESKTOP:${NC}  ${GREEN}./start-linux.sh${NC}"
    echo -e "${WHITE}[*] TO STOP THE DESKTOP:${NC}   ${GREEN}./stop-linux.sh${NC}"
    echo -e "${YELLOW}------------------------------------------------------------${NC}"
    echo ""
}

# ============== MAIN ==============
main() {
    find_assets
    show_banner
    setup_environment
    
    step_update
    step_repos
    step_x11
    step_desktop
    step_gpu
    step_audio
    step_apps
    step_python
    step_wine
    step_launchers
    step_shortcuts
    step_banners
    
    show_completion
}

main
