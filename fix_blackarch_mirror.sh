#!/bin/bash

echo "🛠️ Đang sửa lỗi mirror cho Arch và BlackArch..."

# Cập nhật gói hệ thống cơ bản nếu cần
sudo pacman -Sy --noconfirm reflector curl git

# Cập nhật mirror Arch
echo "📡 Cập nhật mirrorlist Arch Linux..."
sudo reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Cập nhật mirror BlackArch
echo "📥 Cập nhật mirror BlackArch..."
cd ~
curl -O https://blackarch.org/strap.sh
chmod +x strap.sh
sudo ./strap.sh

# Làm sạch và cập nhật hệ thống
echo "🔁 Làm mới database và cập nhật..."
sudo pacman -Syyu --noconfirm

echo "✅ Hoàn tất! Bạn đã sẵn sàng dùng pacman và yay."