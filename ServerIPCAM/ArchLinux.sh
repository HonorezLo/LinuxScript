#!/bin/bash

echo -e "\nSynchronisation de l'heure et du fuseaux Europe/Brussels\n"
ln -sfv /usr/share/zoneinfo/Europe/Brussels /etc/localtime
hwclock --systohc --utc

echo -e "\n"

echo -e "\nInstall Video Drivers\n"
sudo pacman -S xf86-video-vesa intel-ucode

echo -e "\nInstall Audio Packages\n"
sudo pacman -S gst-plugins-base gst-plugins-bad gst-plugins-good gst-plugins-ugly gst-libav pulseaudio pulseaudio-alsa pavucontrol alsa-utils

echo -e "\nInstall Xorg-app\n"
sudo pacman -S xorg-server xorg-xinit xorg-xmessage xorg-apps xf86-input-mouse xf86-input-keyboard xf86-input-synaptics xf86-input-libinput xdg-user-dirs

echo -e "\nInstall Printer Drivers\n"
sudo pacman -S cups hplip python-pyqt5 foomatic-db foomatic-db-ppds foomatic-db-gutenprint-ppds foomatic-db-nonfree foomatic-db-nonfree-ppds gutenprint

echo -e "\nInstall Tools\n"
sudo pacman -S evince vlc xfce4-notifyd gnome-keyring

echo -e "\nInstallation de zssh\n"
sudo pacman -S zsh zsh-autosuggestions zsh-completions zshdb zsh-history-substring-search \
		zsh-lovers zsh-syntax-highlighting zsh-theme-powerlevel9k \
		 powerline-fonts awesome-terminal-fonts
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"


echo -e "\nRécupération des Source Pakku(AUR HELPER)\n"
cd /opt
git clone https://aur.archlinux.org/pakku.git
cd pakku

echo -e "\nCompilation et Installation Selinux\n"
makepkg -si
cd ..

echo -e "\nRésolution des Driversn"
pakku -S wdx71

echo "\nChange lightdm\n"
pakku -S lightdm-webkit-theme-aether

echo -e "\nInstall Lightdm\n"
pakku -S pamac


