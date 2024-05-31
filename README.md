# 💧 _Assembly of KLA-HyprlandCE_ 💧

![Screenshot_01-мая_13-58-16_22010](https://github.com/sofijacom/KLA-HyprlandCE/assets/107557749/7b55db00-8611-4931-af58-ecf956e4ea35)

##
![Скриншот_24 марта_04-43-49_22640](https://github.com/sofijacom/KLA-Hyprland/assets/107557749/9cb7631c-6fd2-4c3c-9c21-7225ee09fd70)

1) Create a folder `KLA-HyprlandCE` typing in the terminal `mkdir -p KLA-HyprlandCE`

2) Open a terminal in the created folder `KLA-HyprlandCE` or go to the folder by typing in the terminal

   - `cd KLA-HyprlandCE`

3) Place the build script  `KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh` in the created folder.
   
4) Make it executable.`chmod +x KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh`

5) Enter in terminal `./KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh`

6) Wait for the build to finish.

7) After the build is complete to package `07firstrib_rootfs` into `07KLA-HyprlandCE-x.x.sfs` where x.x is your build number.

8) Type in terminal.

```
mksquashfs 07firstrib_rootfs 07KLA-HyprlandCE-x.x.sfs -noappend -comp xz -b 512k
```
  - where x.x is your build number.

9) Delete the `07firstrib_rootfs` folder.

##

FirstRib-KLA build script. 

```
./KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh
```
FirstRib-KLA build script PLUG file.

Example of using a .plug file:

```
./build_firstrib_rootfs.sh Arch default amd64 f_00_Arch_amd64-KLA-Hyprland_Wayland_pipewire.plug
```

***f_00_Arch_amd64-KLA-Hyprland_Wayland_pipewire.plug***  builds a  ***(root filesystem)***  for the Arch Linux-based Hyprland desktop operating system, similar to **KLA-Hyprland**.

To create a complete distribution, all other utilities, tools and configurations are downloaded from a centralized repository and installed as a .tar.gz file.

<p align="center">	
  <img src="https://github.com/sofijacom/sofijacom/blob/49e18fe1d7c2223884efd95af9370dcb84697427/icons_line/gray0_ctp_on_line.svg?sanitize=true" />
</p>
