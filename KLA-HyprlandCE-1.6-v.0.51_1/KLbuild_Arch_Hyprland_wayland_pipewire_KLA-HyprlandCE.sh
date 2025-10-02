#!/bin/bash
# Sofiya Created: 25Nov2023 Revised: 25 Movember 2023 Licence: MIT
# KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh version 1.0 -CE

# General Build Instructions:
# Create an empty directory at root of partition you want to bootfrom
# For example: /KLA-Hyprland
# In a terminal opened at that bootfrom directory simply run this single script!!! ;-)

# Fetch the build_firstrib_rootfs build parts:
wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA_modules/build_firstrib_rootfs.sh && chmod +x build_firstrib_rootfs.sh

# Arch Linux build plugin used during the build (you can add to this plugin for whatever extras you want in your build)
wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/Arch-KLA-Hyprland/Plugin/f_00_Arch_amd64-KLA-Hyprland_Wayland_pipewire.plug

# Download the boot components:
# wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA-Hyprland/huge_kernels/initrd-latest.gz -O initrd.gz
# wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA-Hyprland/huge_kernels/vmlinuz
# wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA-Hyprland/huge_kernels/00zdrv_vanilladpup_10.0.30.sfs
# wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA-Hyprland/huge_kernels/01fdrv_vanilladpup_10.0.30.sfs

wget -c https://github.com/sofijacom/linux-6.11.1.arch1-1-x86_64/releases/download/linux-6.11.7/00modules_6.11.7.sfs
wget -c https://github.com/sofijacom/linux-6.11.1.arch1-1-x86_64/releases/download/linux-6.11.7/01firmware_6.11.7.sfs
wget -c https://github.com/sofijacom/linux-6.11.1.arch1-1-x86_64/releases/download/linux-6.11.7/initrd.gz
wget -c https://github.com/sofijacom/linux-6.11.1.arch1-1-x86_64/releases/download/linux-6.11.7/vmlinuz

# Some useful FirstRib utilities in case you want to modify the initrd or the 07firstrib_rootfs
# All these utilities have a --help option
wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA_modules/archstrap_wiak_mod.sh && chmod +x archstrap_wiak_mod.sh
wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wd_grubconfig && chmod +x wd_grubconfig  # When run finds correct grub menu stanza for your system
wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/modify_initrd_gz.sh && chmod +x modify_initrd_gz.sh  # For 'experts' to modify initrd.gz
wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/mount_chroot.sh && chmod +x mount_chroot.sh  # To enter rootfs in a chroot
wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/umount_chroot.sh && chmod +x umount_chroot.sh  # to 'clean up mounts used by above mount_chroot.sh'
wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/mount_chroot_umount.sh && chmod +x mount_chroot_umount.sh  # combined mount and umount chroot...
wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA_modules/restore-sys && chmod +x restore-sys  # creating a backup copy of upper_changes
wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA_modules/FRextract_kernel.sh && chmod +x FRextract_kernel.sh
wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA_modules/FRmake_initrd.sh && chmod +x FRmake_initrd.sh
wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA_modules/FRmake_initrd_dep.sh && chmod +x FRmake_initrd_dep.sh
#wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/KLA_modules/w_init

# Optional addon layers

# Main KL addon containing settings
# save2flash works with command-line-only distros too
wget -c https://gitlab.com/sofija.p2018/kla-ot2/-/raw/main/Arch-KLA-Hyprland/Plugin/10KLA_hyprland_spot_settings.sfs

# Build the Arch Linux root filesystem to firstrib_rootfs directory
# NOTE WELL: If you have an alternative f_plugin in your bootfrom directory (name must start with f_),
# simply alter below command to use it
./build_firstrib_rootfs.sh arch default amd64 f_00_Arch_amd64-KLA-Hyprland_Wayland_pipewire.plug

# Number the layer ready for booting
mv firstrib_rootfs 07firstrib_rootfs

# The only thing now to do is find correct grub stanza for your system
printf "\nPress any key to run utility wd_grubconfig
which will output suitable exact grub stanzas
Use one of these with your pre-installed grub
Press enter to finish\n"
read choice
./wd_grubconfig
exit 0


