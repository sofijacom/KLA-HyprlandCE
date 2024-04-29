# KLA- PLUG
![Скриншот_24 марта_04-43-49_22640](https://github.com/sofijacom/KLA-Hyprland/assets/107557749/9cb7631c-6fd2-4c3c-9c21-7225ee09fd70)

1) Create a folder `KLA-HyprlandCE` typing in the terminal `mkdir -p KLA-HyprlandCE`

2) Open a terminal in the created folder `KLA-HyprlandCE` or go to the folder by typing in the terminal `cd KLA-HyprlandCE`

3) Place the build script  `KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh`  there.
   
4) Make it executable.`chmod +x KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh`

6) Enter in terminal `./KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh`

7) Wait for the build to finish.

8) After the build is complete to package `07firstrib_rootfs` into `07KLA-HyprlandCE-x.x.sfs` -- where x.x is your build number.

9) Type in terminal

```
mksquashfs 07firstrib_rootfs 07 KLA-HyprlandCE-x.x.sfs -noappend -comp xz -b 512k
```
where x.x is your build number.

10) Delete the `07firstrib_rootfs` folder

FirstRib-KLA build script 

```
./KLbuild_Arch_Hyprland_wayland_pipewire_KLA-HyprlandCE.sh
```
FirstRib-KLA build script PLUG file.

Example of using a .plug file:

```
./build_firstrib_rootfs.sh Arch default amd64 f_00_Arch_amd64-KLA-Hyprland_Wayland_pipewire.plug
```

*f_00_Arch_amd64-KLA-Hyprland_Wayland_pipewire.plug* builds a *root filesystem* for the Arch Linux-based Hyprland desktop operating system, similar to *KLA-Hyprland*.

To create a complete distribution, all other utilities, tools and configurations are downloaded from a centralized repository and installed as a .tar.gz file.

