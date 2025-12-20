#!/bin/bash
# Labwc Installer for Debian 13 (Trixie) - TTY Optimized version

set -e

# 1. Check Root
if [ "$(id -u)" -eq 0 ]; then
    echo "Please run as normal user (not root)."
    exit 1
fi

echo ">> Updating System..."
sudo apt update

echo ">> Installing Packages..."
# Core components
sudo apt install -y labwc waybar swaybg foot fuzzel pcmanfm lxpolkit \
    xwayland grim slurp mako-notifier wireplumber pipewire-pulse \
    fonts-jetbrains-mono curl

echo ">> Creating Configs..."
mkdir -p ~/.config/labwc ~/.config/waybar

# 2. Environment
cat > ~/.config/labwc/environment << EOF
XDG_CURRENT_DESKTOP=labwc
XDG_SESSION_TYPE=wayland
MOZ_ENABLE_WAYLAND=1
EOF

# 3. Autostart
cat > ~/.config/labwc/autostart << EOF
#!/bin/sh
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
lxpolkit &
waybar &
mako &
swaybg -c "#2e3440" &
EOF
chmod +x ~/.config/labwc/autostart

# 4. Keybinds (Win+Enter=Term, Win+D=Menu, Win+Q=Close)
cat > ~/.config/labwc/rc.xml << EOF
<labwc_config>
<keyboard>
  <default />
  <keybind key="W-Return"><action name="Execute" command="foot" /></keybind>
  <keybind key="W-d"><action name="Execute" command="fuzzel" /></keybind>
  <keybind key="W-e"><action name="Execute" command="pcmanfm" /></keybind>
  <keybind key="W-q"><action name="Close" /></keybind>
  <keybind key="W-S-e"><action name="Exit" /></keybind>
</keyboard>
<theme><cornerRadius>8</cornerRadius></theme>
</labwc_config>
EOF

# 5. Waybar
cat > ~/.config/waybar/config << EOF
{
    "layer": "top", "height": 30,
    "modules-left": ["wlr/taskbar"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "tray"]
}
EOF

cat > ~/.config/waybar/style.css << EOF
* { font-family: sans-serif; font-size: 13px; }
window#waybar { background: #2e3440; color: #fff; }
EOF

echo ">> Installation Complete. Type 'labwc' to start."
