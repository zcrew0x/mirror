#!/bin/bash
set -e

echo "=== Cập nhật hệ thống ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl build-essential meson ninja-build pkg-config \
  libwayland-dev libxcb1-dev libpixman-1-dev libxkbcommon-dev \
  libudev-dev libseat-dev libegl1-mesa-dev libgles2-mesa-dev \
  libgtk-3-dev libnotify-dev libpulse-dev libjson-glib-dev libglib2.0-dev scdoc

echo "=== Cài swww (wallpaper manager) ==="
if [ ! -d "$HOME/swww" ]; then
  git clone https://github.com/Horus645/swww.git ~/swww
fi
cd ~/swww
meson setup build
ninja -C build
sudo ninja -C build install
cd ~

echo "=== Cài swaync (notification center) ==="
if [ ! -d "$HOME/SwayNotificationCenter" ]; then
  git clone https://github.com/ErikReider/SwayNotificationCenter.git ~/SwayNotificationCenter
fi
cd ~/SwayNotificationCenter
meson build
ninja -C build
sudo ninja -C build install
cd ~

echo "=== Cài starship (shell prompt) ==="
curl -sS https://starship.rs/install.sh | sh -s -- -y

echo "=== Thêm starship vào shell ==="
if [ -n "$BASH_VERSION" ]; then
  echo 'eval "$(starship init bash)"' >> ~/.bashrc
elif [ -n "$ZSH_VERSION" ]; then
  echo 'eval "$(starship init zsh)"' >> ~/.zshrc
fi
mkdir -p ~/.config/fish
echo 'eval "$(starship init fish)"' >> ~/.config/fish/config.fish

echo "=== Hoàn tất! ==="
echo "Giờ bạn có thể dùng:"
echo "  - swww init && swww img <ảnh>  (để đặt wallpaper)"
echo "  - swaync  (để bật notification center)"
echo "  - starship prompt sẽ tự hoạt động khi mở shell"
