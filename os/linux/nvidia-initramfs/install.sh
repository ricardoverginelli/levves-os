#!/usr/bin/bash
# Load the NVIDIA driver (akmod-nvidia*) from the initramfs and keep it in sync
# with akmods rebuilds. Run as root: sudo bash install.sh
# Undo: remove the files below, systemctl daemon-reload, dracut -f --regenerate-all
# Boot without it once: add rd.driver.blacklist=nvidia to the kernel line in GRUB.
set -e
cd "$(dirname "$0")"
install -m644 99-nvidia-dracut.conf /etc/dracut.conf.d/
install -m755 nvidia-initramfs-sync /usr/local/sbin/
restorecon -v /usr/local/sbin/nvidia-initramfs-sync
install -m644 nvidia-initramfs-sync.service /etc/systemd/system/
install -Dm644 akmods-initramfs.conf /etc/systemd/system/akmods@.service.d/initramfs.conf
install -Dm644 akmods-initramfs.conf /etc/systemd/system/akmods.service.d/initramfs.conf
systemctl daemon-reload
systemctl enable --now nvidia-initramfs-sync.service
/usr/local/sbin/nvidia-initramfs-sync
lsinitrd /boot/initramfs-"$(uname -r)".img | grep -E 'nvidia.*\.ko|modprobe.d'
