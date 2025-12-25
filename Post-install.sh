#!/bin/bash

# 设置遇到错误停止
set -e

# 1. 权限与身份检查
if [[ $EUID -ne 0 ]]; then
   echo "错误: 必须使用 sudo 运行此脚本" 
   exit 1
fi

REAL_USER=${SUDO_USER:-$USER}

# 定义询问函数
ask() {
    read -p "$1 (y/n): " resp
    if [[ $resp == "y" || $resp == "Y" ]]; then return 0; else return 1; fi
}

echo "--- 开始系统配置 ---"

# 2.1 软件源配置
apt update && apt install -y nala
# 自动选择最快源 (跳过交互，使用默认更新)
nala update

# 2.2 基础软件安装
nala install -y gdm3 gnome-terminal flatpak fonts-noto-cjk git ibus-libpinyin preload adb fastboot thermald
# 清理冗余
nala remove -y fortune-* debian-reference-* malcontent-*
nala autoremove -y --purge

# 2.3 Flatpak 配置 (针对普通用户)
sudo -u $REAL_USER flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo --user
sudo -u $REAL_USER flatpak remote-modify flathub --url=https://mirrors.ustc.edu.cn/flathub --user

echo "正在后台安装 Flatpak 应用..."
sudo -u $REAL_USER flatpak install --user -y flathub \
  com.github.tchx84.Flatseal io.gitlab.librewolf-community org.libreoffice.LibreOffice \
  net.cozic.joplin_desktop io.github.ungoogled_software.ungoogled_chromium \
  net.agalwood.Motrix org.gimp.GIMP com.dec05eba.gpu_screen_recorder \
  com.mattjakeman.ExtensionManager org.localsend.localsend_app com.cherry_ai.CherryStudio \
  com.usebottles.bottles org.telegram.desktop page.tesk.Refine

# 2.4 更换 Xanmod 内核
wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list
nala update && nala install -y linux-xanmod-x64v3

# 2.5 (可选) 电源管理
if ask "是否安装 auto-cpufreq 电源优化?"; then
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git /tmp/auto-cpufreq
    cd /tmp/auto-cpufreq && ./auto-cpufreq-installer --install
    auto-cpufreq --install
    cd - && rm -rf /tmp/auto-cpufreq
fi

# 2.6 zram 自动配置
nala install -y zram-tools
echo -e "ALGO=lz4\nPERCENT=50" > /etc/default/zramswap
systemctl restart zramswap

# 3.1 (可选) Docker 配置
if ask "是否安装 Docker?"; then
    nala install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    
    # 修复原文变量无法识别的问题
    V_NAME=$(grep "VERSION_CODENAME" /etc/os-release | cut -d= -f2)
    echo "Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $V_NAME
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc" > /etc/apt/sources.list.d/docker.sources

    nala update
    nala install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 用户组与镜像源配置
    usermod -aG docker $REAL_USER
    mkdir -p /etc/docker /home/docker
    echo '{
      "data-root": "/home/docker",
      "registry-mirrors": [
        "https://docker.xuanyuan.me",
        "https://docker.m.daocloud.io",
        "https://hub.rat.dev"
      ]
    }' > /etc/docker/daemon.json
    systemctl restart docker
fi

# 4. 系统参数优化
systemctl enable --now fstrim.timer thermald

cat >> /etc/sysctl.conf << EOF
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
EOF

sysctl -p

echo "--- 配置完成，请重启系统以生效 ---"
