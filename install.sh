#!/usr/bin/env bash

echo "Please enter EFI paritition: (example /dev/sda1 or /dev/nvme0n1p1)"
read EFI

echo "Please enter Root(/) paritition: (example /dev/sda3)"
read ROOT

echo "Please enter your Username"
read USER

echo "Please enter your Full Name"
read NAME

echo "Please enter your Password"
read PASSWORD

# make filesystems
echo -e "\nCreating Filesystems...\n"

mkfs.ext4 "${ROOT}"

# mount target
mount "${ROOT}" /mnt
mount --mkdir "$EFI" /mnt/boot/efi

echo "--------------------------------------"
echo "-- INSTALLING Base Arch Linux --"
echo "--------------------------------------"

sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

pacstrap /mnt base base-devel linux linux-firmware linux-headers networkmanager wireless_tools intel-ucode bluez bluez-utils git --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

cat <<REALEND > /mnt/next.sh
useradd -m $USER
usermod -c "${NAME}" $USER
usermod -aG wheel,storage,power,audio,video $USER
echo $USER:$PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "-------------------------------------------------"
echo "Setup Language to US and set locale"
echo "-------------------------------------------------"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

echo "archlinux" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	archlinux.localdomain	archlinux
EOF

echo "--------------------------------------"
echo "-- Bootloader Installation  --"
echo "--------------------------------------"

pacman -S --noconfirm sed
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

pacman -S grub ntfs-3g os-prober efibootmgr --noconfirm --needed
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Arch Linux"
grub-mkconfig -o /boot/grub/grub.cfg

echo "-------------------------------------------------"
echo "Video and Audio Drivers"
echo "-------------------------------------------------"

pacman -S --noconfirm --needed\
	xorg-server xorg-xinit xorg-xset xorg-xprop \
	brightnessctl xwallpaper htop lf xdotool alsa-utils \
	ttf-font-awesome ttf-hack ttf-hack-nerd noto-fonts-emoji xcompmgr fastfetch \
	firefox nsxiv neovim mpv newsboat bleachbit unzip zathura zathura-pdf-poppler \
	libxft libxinerama scrot xf86-video-intel bluez bluez-utils unclutter xclip \
	zip unzip pipewire pipewire-alsa pipewire-pulse git\
	networkmanager bluez bluez-utils libxft libxinerama

systemctl enable NetworkManager bluetooth
systemctl --user enable pipewire pipewire-pulse


echo "-------------------------------------------------"
echo "Window Manager"
echo "-------------------------------------------------"

cd $HOME

git clone --depth=1 https://github.com/nyx-void/archrice $HOME/archrice
mkdir -p $HOME/.local/share $HOME/.config $HOME/.local/src $HOME/.local/bin $HOME/.local/hugo-dir

echo "=> copying configs from dotfiles"

cp -r $HOME/archrice/.local/share/* $HOME/.local/share
cp $HOME/archrice/.local/bin/* $HOME/.local/bin
cp -r $HOME/archrice/.config/* $HOME/.config
cp $HOME/archrice/.bashrc $HOME/.bashrc
cp $HOME/archrice/.inputrc $HOME/.inputrc
cp $HOME/archrice/.xinitrc $HOME/.xinitrc

declare -a repos=(
  "https://github.com/amritxyz/dwm.git"
  "https://github.com/amritxyz/dmenu.git"
  "https://github.com/amritxyz/st.git"
  "https://github.com/amritxyz/slstatus.git"
  "https://github.com/amritxyz/slock.git"
)

for repo in "${repos[@]}"; do
  git clone --depth=1 "$repo" ~/.local/src/$(basename "$repo" .git)
  cd ~/.local/src/$(basename "$repo" .git) || exit
  sudo make install
  cd -
done

echo "-------------------------------------------------"
echo "Install Complete, You can reboot now"
echo "-------------------------------------------------"

REALEND

arch-chroot /mnt sh next.sh
