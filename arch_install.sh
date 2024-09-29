#!/usr/bin/env bash

# == MY ARCH SETUP INSTALLER == #
printf '\033c'
echo "Welcome to void's Arch installer script"

# Update pacman config for parallel downloads
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

# Ensure the archlinux keyring is up to date
pacman --noconfirm -Sy archlinux-keyring
loadkeys us
timedatectl set-ntp true

# Show available drives
lsblk
echo "Enter the drive (e.g., /dev/sda): "
read drive

# Partition the drive
echo "Creating partitions..."
(
echo o      # Create a new empty DOS partition table
echo n      # New partition
echo p      # Primary
echo 1      # Partition number
echo        # Default - first sector
echo +1G    # Size of the EFI partition
echo n      # New partition
echo p      # Primary
echo 2      # Partition number
echo        # Default - first sector
echo        # Use the rest of the disk
echo w      # Write changes
) | fdisk $drive || { echo "Partitioning failed."; exit 1; }

# Format the partitions automatically
echo "Formatting partitions..."
efipartition="${drive}1"
rootpartition="${drive}2"

mkfs.vfat -F 32 $efipartition || { echo "Failed to format the EFI partition."; exit 1; }
mkfs.ext4 $rootpartition || { echo "Failed to format the root partition."; exit 1; }

# Mount the root partition
mount $rootpartition /mnt || { echo "Failed to mount the root partition."; exit 1; }

# Install base system
pacstrap /mnt base base-devel linux linux-firmware || { echo "Base installation failed."; exit 1; }
genfstab -U /mnt >> /mnt/etc/fstab

# Prepare for chroot
sed '1,/^#part2$/d' `basename $0` > /mnt/arch_install2.sh
chmod +x /mnt/arch_install2.sh
arch-chroot /mnt ./arch_install2.sh
exit

# part2
printf '\033c'
pacman -S --noconfirm sed
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

# Set timezone and locale
ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname setup
echo "Enter hostname: "
read hostname
echo $hostname > /etc/hostname
{
  echo "127.0.0.1       localhost"
  echo "::1             localhost"
  echo "127.0.1.1       $hostname.localdomain $hostname"
} >> /etc/hosts

mkinitcpio -P
passwd

# Install GRUB
pacman --noconfirm -S grub efibootmgr
mkdir /boot/efi
mount $efipartition /boot/efi || { echo "Failed to mount EFI partition."; exit 1; }

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB || { echo "GRUB installation failed."; exit 1; }
sed -i 's/quiet/pci=noaer/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Install packages
# efibootmgr base base-devel intel-ucode xorg-xbacklight xorg-xkill gst-plugin-pipewire libpulse wireplumber
# mesa libva-intel-driver intel-media-driver intel-media-driver vulkan-intel
# slock

# Install essential packages
pacman -S --noconfirm \
	xorg-server xorg-xinit xorg-xset xorg-xprop \
	brightnessctl xwallpaper htop lf xdotool alsa-utils \
	ttf-font-awesome ttf-hack ttf-hack-nerd noto-fonts-emoji xcompmgr fastfetch \
	firefox nsxiv neovim mpv newsboat bleachbit unzip zathura zathura-pdf-poppler \
	libxft libxinerama scrot xf86-video-intel bluez bluez-utils unclutter xclip \
	zip unzip pipewire pipewire-alsa pipewire-pulse \
	networkmanager bluez bluez-utils libxft libxinerama

# Enable services
systemctl enable NetworkManager.service

# Configure sudo
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# User setup
echo "Enter Username: "
read username
useradd -m -G wheel -s /bin/bash $username
passwd $username

# Prepare for next part
echo "Pre-Installation Finished. Reboot now."
ai3_path=/home/$username/arch_install3.sh
sed '1,/^#part3$/d' arch_install2.sh > $ai3_path
chown $username:$username $ai3_path
chmod +x $ai3_path
su -c $ai3_path -s /bin/sh $username
exit

# part3
printf '\033c'
cd $HOME

git clone --depth=1 https://github.com/nyx-void/archrice $HOME/archrice
mkdir -p $HOME/.local/share $HOME/.config $HOME/.local/src $HOME/.local/bin $HOME/.local/hugo-dir

# Copying Dotfiles
echo "=> copying configs from dotfiles"

cp -r $HOME/archrice/.local/share/* $HOME/.local/share
cp $HOME/archrice/.local/bin/* $HOME/.local/bin
cp -r $HOME/archrice/.config/* $HOME/.config
cp $HOME/archrice/.bashrc $HOME/.bashrc
cp $HOME/archrice/.inputrc $HOME/.inputrc
cp $HOME/archrice/.xinitrc $HOME/.xinitrc

# Install window manager and other applications
declare -a repos=(
  "https://github.com/nyx-void/dwm.git"
  "https://github.com/nyx-void/dmenu.git"
  "https://github.com/nyx-void/st.git"
  "https://github.com/nyx-void/slstatus.git"
  "https://github.com/nyx-void/slock.git"
)

for repo in "${repos[@]}"; do
  git clone --depth=1 "$repo" ~/.local/src/$(basename "$repo" .git)
  cd ~/.local/src/$(basename "$repo" .git) || exit
  sudo make install
  cd -
done

exit
