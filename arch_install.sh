#!/usr/bin/env bash

# == MY ARCH SETUP INSTALLER == #
printf '\033c'
echo "Welcome to void's Arch installer script"

# Function to handle errors
handle_error() {
    echo "$1" && exit 1
}

# Safety confirmation for drive selection
echo "Available drives:"
lsblk
echo "Enter the drive (e.g., /dev/sda): "
read -r drive

echo "This will delete all existing partitions on $drive. Proceed? (y/n)"
read -r confirmation
if [[ "$confirmation" != "y" ]]; then
    echo "Operation canceled."
    exit 1
fi

# Update pacman config for parallel downloads
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

# Ensure the archlinux keyring is up to date
pacman --noconfirm -Sy archlinux-keyring || handle_error "Failed to update archlinux keyring"
loadkeys us
timedatectl set-ntp true

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
) | fdisk "$drive" || handle_error "Partitioning failed."

# Format the partitions automatically
echo "Formatting partitions..."
efipartition="${drive}1"
rootpartition="${drive}2"

mkfs.vfat -F 32 "$efipartition" || handle_error "Failed to format the EFI partition."
mkfs.ext4 "$rootpartition" || handle_error "Failed to format the root partition."

# Mount the root partition
mount "$rootpartition" /mnt || handle_error "Failed to mount the root partition."

# Install base system
pacstrap /mnt base base-devel linux linux-firmware || handle_error "Base installation failed."
genfstab -U /mnt >> /mnt/etc/fstab

# Prepare for chroot
sed '1,/^#part2$/d' "$(basename "$0")" > /mnt/arch_install2.sh
chmod +x /mnt/arch_install2.sh
arch-chroot /mnt ./arch_install2.sh
exit

# part2
printf '\033c'
pacman -S --noconfirm sed || handle_error "Failed to install sed"

# Set timezone and locale
ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname setup
echo "Enter hostname: "
read -r hostname
echo "$hostname" > /etc/hostname
{
  echo "127.0.0.1       localhost"
  echo "::1             localhost"
  echo "127.0.1.1       $hostname.localdomain $hostname"
} >> /etc/hosts

mkinitcpio -P || handle_error "Failed to generate initramfs"
passwd

# Install GRUB
pacman --noconfirm -S grub efibootmgr || handle_error "Failed to install GRUB and efibootmgr"
mkdir /boot/efi
mount "$efipartition" /boot/efi || handle_error "Failed to mount EFI partition."

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB || handle_error "GRUB installation failed."
sed -i 's/quiet/pci=noaer/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg || handle_error "Failed to generate GRUB configuration."

# Install essential packages
pacman -S --noconfirm \
    xorg-server xorg-xinit xorg-xset xorg-xprop \
    brightnessctl xwallpaper htop lf xdotool alsa-utils \
    ttf-font-awesome ttf-hack ttf-hack-nerd noto-fonts-emoji xcompmgr fastfetch \
    firefox nsxiv neovim mpv newsboat bleachbit unzip zathura zathura-pdf-poppler \
    libxft libxinerama scrot xf86-video-intel bluez bluez-utils unclutter xclip \
    zip unzip pipewire pipewire-alsa pipewire-pulse || handle_error "Failed to install essential packages."

# Enable services
systemctl enable NetworkManager.service || handle_error "Failed to enable NetworkManager service"

# Configure sudo
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# User setup
echo "Enter Username: "
read -r username
useradd -m -G wheel -s /bin/bash "$username"
passwd "$username"

# Prepare for next part
echo "Pre-Installation Finished. Reboot now."
ai3_path="/home/$username/arch_install3.sh"
sed '1,/^#part3$/d' arch_install2.sh > "$ai3_path"
chown "$username:$username" "$ai3_path"
chmod +x "$ai3_path"
su -c "$ai3_path" -s /bin/sh "$username"
exit

# part3
printf '\033c'
cd "$HOME" || exit

git clone --depth=1 https://github.com/nyx-void/archrice "$HOME/archrice" || handle_error "Failed to clone archrice"
mkdir -p "$HOME/.local/share" "$HOME/.config" "$HOME/.local/src" "$HOME/.local/bin" "$HOME/.local/hugo-dir"

# Copying Dotfiles
echo "=> copying configs from dotfiles"
cp -r "$HOME/archrice/.local/share/"* "$HOME/.local/share/" || handle_error "Failed to copy share files"
cp "$HOME/archrice/.local/bin/"* "$HOME/.local/bin/" || handle_error "Failed to copy bin files"
cp -r "$HOME/archrice/.config/"* "$HOME/.config/" || handle_error "Failed to copy config files"
cp "$HOME/archrice/.bashrc" "$HOME/.bashrc" || handle_error "Failed to copy .bashrc"
cp "$HOME/archrice/.inputrc" "$HOME/.inputrc" || handle_error "Failed to copy .inputrc"
cp "$HOME/archrice/.xinitrc" "$HOME/.xinitrc" || handle_error "Failed to copy .xinitrc"

# Install window manager and other applications
declare -a repos=(
  "https://github.com/nyx-void/dwm.git"
  "https://github.com/nyx-void/dmenu.git"
  "https://github.com/nyx-void/st.git"
  "https://github.com/nyx-void/slstatus.git"
  "https://github.com/nyx-void/slock.git"
)

for repo in "${repos[@]}"; do
  git clone --depth=1 "$repo" "$HOME/.local/src/$(basename "$repo" .git)" || handle_error "Failed to clone $(basename "$repo")"
  cd "$HOME/.local/src/$(basename "$repo" .git)" || handle_error "Failed to enter directory for $(basename "$repo")"
  sudo make install || handle_error "Failed to install $(basename "$repo")"
  cd - || exit
done

# Cleanup: Remove temporary installation scripts
rm -f /mnt/arch_install2.sh

echo "Installation complete. Please reboot."
