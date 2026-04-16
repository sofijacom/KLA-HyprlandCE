#!/bin/sh
## Build_firstrib_rootfs script to create
#    FirstRib rootfs (structure and contents)
# Uses busybox static plus relevant native package manager or debootstrap code
# Revision Date: modded from 22Aug2023 on 16April2026
# Copyright wiak (William McEwan) 30 May 2019+; Licence: MIT

##### Just run this script from an empty directory to create firstrib_rootfs
# NOTE: You should run this from appropriate Linux host architecture relevant to the build required
# It uses 32-bit busybox static for all system architectures
# ----------------------------------------------------------
version="8.0.1"; revision="-rc1"
export CONNECTION_TIMEOUT=-1

trap _trapcleanup INT TERM ERR

#### variables-used-in-script:
# re: script commandline arguments $1 $2 $3 $4 $5
distro="$1"; release="$2"; arch="$3"	
export distro release arch

# where distro is currently one of void, ubuntu, debian, devuan, arch, fedora or
#   vmini (xbps-static cmdline base Void system), vzstperl (mini) or vnopm (no package manager, just busybox and wiakwifi script).
# release is one of oldstable, stable, testing, or unstable.
# arch is currently one of i386 (i686 for Void), amd64 (x86_64 for Void), or arm64

firstribplugin="f_00.plug"			# contains extra commandlines to execute in chroot during build
									# e.g. xbps-install -y package_whatever (for Void flavour)
									# e.g. apt install -y package_whatever (for deb-based flavour)
									# e.g. pacman -Sy package_whatever (for Arch-Linux-based flavour)
[ "$4" ] && firstribplugin="$4"		# optional fourth parameter specifies alternative f_00 plugin name
firstribplugin01="f_01.plug"		# This second plugin will be sourced immediately after main firstribplugin has finished its work
[ "$5" ] && firstribplugin01="$5"	# optional fifth parameter specifies alternative f_01 plugin name

HERE="`pwd`"
bootdir=`basename "$HERE"` # for use with grub config
#### ----------------- end of variables used

#### functions-used-in-script:
_trapcleanup (){
	# Just a quick attempt to clean up some possible chroot-related mounts
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
	exit
}

_grub_config (){
	cd "$HERE"
	subdir="$bootdir"
	bootuuid=`df . | awk '/^\/dev/ {print $1}' | xargs blkid -s UUID | awk -F\" '{print $2}'`
	bootlabel=`df . | awk '/^\/dev/ {print $1}' | xargs blkid -s LABEL | awk -F\" '{print $2}'`
	printf "
Assuming names: kernel is vmlinuz and initrd is initrd.gz and booting is
from this build directory and needed modules and firmware are present:

#####menu.lst (note the LABEL or UUID options below):
title $subdir
  find --set-root --ignore-floppies /${subdir}/grub_config.txt
  kernel /$subdir/vmlinuz w_bootfrom=LABEL=${bootlabel}=/$subdir
  initrd /$subdir/initrd.gz
#############################OR uuid method:
title $subdir
  find --set-root uuid () $bootuuid
  kernel /$subdir/vmlinuz w_bootfrom=UUID=${bootuuid}=/$subdir
  initrd /$subdir/initrd.gz

#####grub.cfg (note the UUID or LABEL options below):
menuentry \"${subdir}\" {
  insmod ext2
  search --no-floppy --label $bootlabel --set
  linux /$subdir/vmlinuz w_bootfrom=LABEL=${bootlabel}=/$subdir
  initrd /$subdir/initrd.gz
}
#############################OR uuid method:
menuentry \"${subdir}\" {
  insmod ext2
  search --no-floppy --fs-uuid --set $bootuuid
  linux /$subdir/vmlinuz w_bootfrom=UUID=${bootuuid}=/$subdir
  initrd /$subdir/initrd.gz
}

Refer to $HERE/grub_config.txt for
copy of this information plus blkid info\n" > grub_config.txt
	blkid -s UUID >> grub_config.txt
}

_getlatestfile (){
	# NOTE WELL: needs three quoted arguments in call ($3 is a command, usually grep command, for extra versatility)
	latest_file=`wget -q -O - $1 | grep -o -E "[^<>]*?${2}" | $3 | sort -V | tail -n 1`
	wget -c "${1}"/"${latest_file}"
}
_getlatestfile2 (){
	# NOTE WELL: needs three quoted arguments in call ($3 is a command, usually grep command, for extra versatility)
	latest_file2=`wget -q -O - $1 | grep -o -E "[^<>]*?${2}" | $3 | sort -V | tail -n 1`
	wget -c "${1}"/"${latest_file2}"
}

_usage (){
	case "$1" in
		'-v'|'--version') printf "Build FirstRib firstrib_rootfs Revision ${version}${revision}\n";exit;;

		''|'-h'|'--help'|'-?') printf '
Usage:
./build_firstrib_rootfsX.sh distro release arch [filename.plug(s)]

where distro is currently one of void, ubuntu, debian, devuan, [a|A]rch,
fedora, vmini (xbps-static cmdline Void system), vzstdperl (mini),
or vnopm (for Void Linux structure but no package manager)
Architecture (arch) can currently be one of amd64 or i686.
For distro void, Arch, or fedora, "release" can be "default".
For example:
./build_firstrib_rootfsX.sh void default amd64 f_00_Void_amd64-XXX.plug
All f_*.plug files automatically get copied into firstrib_rootfs/tmp
If it exists, the commands in optional primary plugin, f_00XX.plug are
automatically executed in a chroot after the core build is complete.
If it exists, additional plugin f_01XX.plug is then similarly sourced.
Either f_00, or f_01 plugin can of course themselves be used to access
other f_XX plugins that were copied into firstrib_rootfs/tmp (for
example: other f_XX lists of commands, or image files or whatever).
NOTE WELL that f_XX plugins (e.g. f_00XX.plug) are not exec scripts.
Rather they should simply contain a list of valid shell commandlines
without any hash bang shell header. Boot info provided on completion.
-v --version    display version information and exit
-h --help -?    display this help and exit
';exit;;
		"-*") echo "option $1 not available";exit;;
	esac
}

_void_repo_mirrors (){
	if [ -s "./firstrib.repo" ];then
		. "./firstrib.repo"
		# i.e. If firstrib.repo exists then source it to change build repo from above default
		# For example, for "us" repo, firstrib.repo text file should just contain the single commandline
		#     repo="https://alpha.us.repo.voidlinux.org"
	elif [ "$distro" = "vnopm" ];then
		repo="https://alpha.de.repo.voidlinux.org"
	else
		while :
		do
			printf '
Tier 1 mirrors
1 https://repo-de.voidlinux.org        EU: Germany
2 https://repo-fastly.voidlinux.org Global: Fastly Global CDN
3 https://mirrors.summithq.com   USA: Chicago
4 https://repo-fi.voidlinux.org        EU: Finland
Tier 2 mirrors
5 https://mirror.aarnet.edu.au         AU: Canberra
6 https://mirror.vofr.net              USA: Virginia
7 https://ftp.accum.se                 EU: Sweden
8 https://mirrors.dotsrc.org           EU: Denmark
9 https://mirror.freedif.org      Asia: Singapore
10 https://mirrors.cicku.me       Globaly reachable
11 https://ftp.lysator.liu.se          EU: Sweden
12 https://mirror.yandex.ru            RU: Russia
13 https://void.sakamoto.pl             EU: Poland
14 https://mirrors.lug.mtu.edu        USA: Michigan
q for quit this firstrib_rootfs build

Please make your choice '
			read choice
			case $choice in
				'1'|'01') repo="https://repo-de.voidlinux.org";break;;
				'2'|'02') repo="https://repo-fastly.voidlinux.org";break;;
				'3'|'03') repo="https://mirrors.summithq.com/voidlinux";break;;
				'4'|'04') repo="https://repo-fi.voidlinux.org";break;;
				'5'|'05') repo="https://mirror.aarnet.edu.au/pub/voidlinux";break;;
				'6'|'06') repo="https://mirror.vofr.net/voidlinux";break;;
				'7'|'07') repo="https://ftp.accum.se/mirror/voidlinux";break;;
				'8'|'08') repo="https://mirrors.dotsrc.org/voidlinux";break;;
				'9'|'09') repo="https://mirror.freedif.org/voidlinux";break;;
				'10') repo="https://mirrors.cicku.me/voidlinux";break;;
				'11') repo="https://ftp.lysator.liu.se/pub/voidlinux";break;;
				'12') repo="https://mirror.yandex.ru/mirrors/voidlinux";break;;
				'13') repo="https://void.sakamoto.pl";break;;
				'14') repo="https://mirrors.lug.mtu.edu/voidlinux";break;;
				'q'|'Q') echo "build terminated";exit 0;;
				*) 
					echo "The choice you made is not available."
					echo "Press enter to return to this menu"
					read choice
				;;
			esac
		done
	fi
}

_arch_repo_mirrors (){ #wiak remove: currently not being used but keep in case needed later
	if [ -s "./firstrib.repo" ];then
		. "./firstrib.repo"
		# i.e. If firstrib.repo exists then source it to change build repo from above default
		# For example, for one South African mirror, firstrib.repo text file could just contain the single commandline
		#     repo="https://mirrors.urbanwave.co.za/archlinux"
	else
		while :
		do
			printf '
Some Arch Linux Repository Mirrors
For many more mirrors refer to: https://www.archlinux.org/mirrorlist/
1 https://mirror.rackspace.com        Worldwide
2 https://mirror.netcologne.de        EU: Germany
3 https://uk.mirror.allworldit.com    EU: UK
4 https://ftp.lysator.liu.se          EU: Sweden
5 https://mirrors.xtom.nl             EU: Netherlands
6 https://mirror.fsmg.org.nz          NZ 
7 https://mirror.aarnet.edu.au        AUS
8 https://mirrors.kernel.org          USA
9 https://mirrors.ocf.berkeley.edu    USA: California
10 https://ftp.lanet.kr               South Korea
11 https://ftp.jaist.ac.jp            Japan
12 https://www.caco.ic.unicamp.br     Brazil
13 https://mirror.rol.ru              Russia
14 https://mirrors.ustc.edu.cn        China
q for quit this firstrib_rootfs build
https://salsa.debian.org/installer-team/debootstrap.git
Please make your choice '
			read choice
			case $choice in
				'1'|'01') repo="https://mirror.rackspace.com/archlinux";break;;
				'2'|'02') repo="https://mirror.netcologne.de/archlinux";break;;
				'3'|'03') repo="https://archlinux.uk.mirror.allworldit.com/archlinux";break;;
				'4'|'04') repo="https://ftp.lysator.liu.se/pub/archlinux";break;;
				'5'|'05') repo="https://mirrors.xtom.nl/archlinux";break;;
				'6'|'06') repo="https://mirror.fsmg.org.nz/archlinux";break;;
				'7'|'07') repo="https://mirror.aarnet.edu.au/pub/archlinux";break;;
				'8'|'08') repo="https://mirrors.kernel.org/archlinux";break;;
				'9'|'09') repo="https://mirrors.ocf.berkeley.edu/archlinux";break;;
				'10') repo="https://ftp.lanet.kr/pub/archlinux";break;;
				'11') repo="https://ftp.jaist.ac.jp/pub/Linux/ArchLinux";break;;
				'12') repo="https://www.caco.ic.unicamp.br/archlinux";break;;
				'13') repo="https://mirror.rol.ru/archlinux";break;;
				'14') repo="https://mirrors.ustc.edu.cn/archlinux";break;;
				'q'|'Q') echo "build terminated";exit 0;;
				*) 
					echo "The choice you made is not available."
					echo "Press enter to return to this menu"
					read choice
				;;
			esac
		done
	fi
}

_void_x86_64 (){
    local distro="${1##*_}"  # call from _debian makes $1 temp_vzstdperl so this cuts off the temp_ part
	export XBPS_ARCH=x86_64
	_void_repo_mirrors # Choose Void repo to use for build
	# build firstrib_rootfs
	mkdir -p firstrib_rootfs
	cd firstrib_rootfs
	# make rootfilesystem directory structure
	mkdir -p boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/void media mnt opt proc root run sys tmp usr/bin usr/lib usr/include usr/lib32 usr/libexec usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/share/udhcpc usr/share/xbps.d usr/src var/log

	# The following is per Void Linux structure. e.g. puts most all binaries in /bin and most all libs in /usr/lib:
	ln -sT usr/bin bin; ln -sT usr/lib lib; ln -sT usr/sbin sbin; ln -sT bin usr/sbin; ln -sT usr/lib lib64
	ln -sT usr/lib32 lib32         # In i686 version /usr/lib32 is just a symlink to /lib and there is no /lib32
	# ln -sT usr/lib usr/local/lib # Seems required in i686 32bit version but not I think in this one

	# Using i686 32-bit busybox to begin with, even in x86_64 build (user can install coreutils later if so wanted)
	wget -c -nc "$busybox_url" -P bin && chmod +x bin/busybox	
	# Make the command applet symlinks for busybox
	for i in `bin/busybox --list-full`; do ln -s /bin/busybox ${i}; done; mv bin/getty bin/gettyDISABLED

	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	# For ethernet connection simply then need enter command: udhcpc -i <interface_name> 
	# You can find interface names with command: ip link, or ip address (for example eth0, eno1, ... etc, for ethernet)
	# Note that for wifi (interface_name: wlan0, wls1, etc), prior to obtaining dhcp lease you 
	# need to install, configure and run wpa_supplicant using following two wpa commands:
	# wpa_passphrase <wifiSSID> <wifiPassword> >> /etc/wpa_supplicant/wpa_supplicant.conf
	# wpa_supplicant -B -i <device> -c /etc/wpa_supplicant/wpa_supplicant.conf (option -B means run daemon in Background)
	# Note well that the provided simple network script /usr/local/bin/wiakwifi does the above for you if you wish to use it
	wget -c https://raw.githubusercontent.com/brgl/busybox/refs/heads/master/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox):
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script

	if [ "$distro" != "vnopm" ];then
		# The following puts xbps static binaries in firstrib_rootfs/usr/bin
		_getlatestfile2 "${repo}/static" ".i686-musl.tar.xz" "grep xbps-static"
		tar xJvf "${latest_file2}" && rm "${latest_file2}"
		
		# Default void repos use usr/share/xbps.d https repos, so ssl certs needed for these:
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		# If no sslcertificates available can use insecure temporary /etc/xbps.d non-https repos:
	fi

	# Install wiakwifi (can autostart on boot via /etc/profile/profile.d)
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wiakwifi -O usr/local/bin/wiakwifi && chmod +x usr/local/bin/wiakwifi
	# Install wd_mount
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wd_mount -O usr/local/bin/wd_mount && chmod +x usr/local/bin/wd_mount
	# cd to where we started this build (i.e. immediately outside of firstrib_rootfs):
	cd ..

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	# The plugin file should contain any extra commandlines you want executed in chroot during build
	# e.g. For Void Linux might be: xbps-install -y package_whatever
	# NOTE WELL (for Void) the -y above, since chroot needs answer supplied
	# also note that the primary plugin is not a script, simply a list
	# of commandlines without any hash bang shell header
	cp -a f_* firstrib_rootfs/tmp

    [ -e firstrib_rootfs/etc/resolv.conf -o -L firstrib_rootfs/etc/resolv.conf ] && mv firstrib_rootfs/etc/resolv.conf firstrib_rootfs/etc/resolv.confORIG
    rm -f firstrib_rootfs/etc/resolv.conf
    cp -aL /etc/resolv.conf firstrib_rootfs/etc/resolv.conf  # changing etc/resolv.conf causes problems sometimes. For example, systemd distros want to auto-create resolv.conf as a symlink and cannot copy over dangling symlink

	# Next part of script does bind mounts (not really required unless using I/O) for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts
	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfs sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
case "$distro" in
	vnopm)
		# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
		# should each simply contain a list of extra commands
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
	vmini)
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers 
		# make sure xbps continues to use desired main and non-free repos
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		sleep 1  # to give time for package installs to settle... maybe not required
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
    vzstdperl)	# include base, and full non-static xbps
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers base-files zstd perl xbps
        # NOTE WELL: if you wish to boot this root filesystem, you also need to install base-minimal,
        # and eudev, run commands, pwconv, and grpconv, and set passwd for root user
		# make sure xbps static continues to use desired main and non-free repos
		sleep 1  # to give time for xbps static to complete above installs
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		rm /usr/bin/xbps*.static  # Since dynamic xbps now installed
		sleep 1  # to give time to make sure shared lib xbps will be used
        if [ "$distro" = "$1" ]; then  # doesn't process f_plugs if actually part of Debian-based build
		  [ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		  [ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
        fi
	;;  
	*)	# include base, and full non-static xbps
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers base-files xbps
		# make sure xbps continues to use desired main and non-free repos
		sleep 1  # to give time for xbps static to complete above installs
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		rm /usr/bin/xbps*.static  # Since dynamic xbps now installed
		sleep 1  # to give time to make sure shared lib xbps will be used

		# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
		# and/or wpasupplicant you need to xbps-install -Syu them in an f_XXX build plugin
		# For example: xbps-install -Syu eudev wpa_supplicant
		# For a bootable system you'll also want linux kernel and appropriate firmware.
		# For some detailed examples, refer to already provided FirstRib Linux f_XXX plugin files available on download site.
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
esac
exit
INSIDE_CHROOT
    sync;sync
	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
    rm -f firstrib_rootfs/etc/resolv.conf
    [ -e firstrib_rootfs/etc/resolv.confORIG -o -L firstrib_rootfs/etc/resolv.confORIG ] && mv firstrib_rootfs/etc/resolv.confORIG firstrib_rootfs/etc/resolv.conf  # put back resolv.conf to its original form
	rm -rf firstrib_rootfs/tmp/*
    [ -s ./addons_f.plug ] && . ./addons_f.plug  # for downloading layer addons and FR utils (e.g. 12KL...sfs; 11rox...sfs, wd_grubconfig)
    sync;sync
}

_void_i686 (){
    local distro="${1##*_}"  # call from _debian makes $1 temp_vzstdperl so this cuts off the temp_ part
	export XBPS_ARCH=i686
	_void_repo_mirrors # Choose Void repo to use for build
	# build firstrib_rootfs
	mkdir -p firstrib_rootfs
	cd firstrib_rootfs
	# make rootfilesystem directory structure
	mkdir -p boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/void media mnt opt proc root run sys tmp usr/bin usr/lib usr/include usr/libexec usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/share/udhcpc usr/share/xbps.d usr/src var/log

	# The following is per Void Linux structure. e.g. puts most all binaries in /bin and most all libs in /usr/lib:
	ln -sT usr/bin bin; ln -sT usr/lib lib; ln -sT usr/sbin sbin; ln -sT bin usr/sbin
	# ln -sT usr/lib lib64       # Required in x86_64 version but not I think in this one
	ln -sT lib usr/lib32         # In x86_64 version /usr/lib32 is an actual directory not a symlink
	ln -sT usr/lib usr/local/lib # Seems to be required in i686 version - nah, gives irrelevant error, but just leave in case

	# Using i686 32-bit busybox to begin with (user can install coreutils later if so wanted)
	wget -c -nc "$busybox_url" -P bin && chmod +x bin/busybox	
	# Make the command applet symlinks for busybox
	for i in `bin/busybox --list-full`; do ln -s /bin/busybox ${i}; done; mv bin/getty bin/gettyDISABLED

	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox):
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script

	if [ "$distro" != "vnopm" ];then
		# The following puts xbps static binaries in firstrib_rootfs/usr/bin
		_getlatestfile2 "${repo}/static" ".i686-musl.tar.xz" "grep xbps-static"
		tar xJvf "${latest_file2}" && rm "${latest_file2}"

		# Default void repos use usr/share/xbps.d https repos, so ssl certs needed for these:
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		# If no sslcertificates available can use insecure temporary /etc/xbps.d non-https repos:
	fi

	# Install wiakwifi (can autostart on boot via /etc/profile/profile.d)
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wiakwifi -O usr/local/bin/wiakwifi && chmod +x usr/local/bin/wiakwifi
	# Install wd_mount
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wd_mount -O usr/local/bin/wd_mount && chmod +x usr/local/bin/wd_mount
	# cd to where we started this build (i.e. immediately outside of firstrib_rootfs):
	cd ..

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	cp -a f_* firstrib_rootfs/tmp

    [ -e firstrib_rootfs/etc/resolv.conf -o -L firstrib_rootfs/etc/resolv.conf ] && mv firstrib_rootfs/etc/resolv.conf firstrib_rootfs/etc/resolv.confORIG
    rm -f firstrib_rootfs/etc/resolv.conf
    cp -aL /etc/resolv.conf firstrib_rootfs/etc/resolv.conf  # changing etc/resolv.conf causes problems sometimes. For example, systemd distros want to auto-create resolv.conf as a symlink and cannot copy over dangling symlink

	# Next part of script does bind mounts (not really required unless using I/O) for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfs sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
case "$distro" in
	vnopm)
		# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
		# should each simply contain a list of extra commands
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
	vmini)
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers 
		# make sure xbps continues to use desired main and non-free repos
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		sleep 1  # to give time for package installs to settle... maybe not required
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
	vzstdperl)	# include base, and full non-static xbps
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers base-files zstd perl xbps
        # NOTE WELL: if you wish to boot this root filesystem, you also need to install base-minimal,
        # and eudev, run commands, pwconv, and grpconv, and set passwd for root user
		# make sure xbps static continues to use desired main and non-free repos
		sleep 1  # to give time for xbps static to complete above installs
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		rm /usr/bin/xbps*.static  # Since dynamic xbps now installed
		sleep 1  # to give time to make sure shared lib xbps will be used
        if [ "$distro" = "$1" ]; then  # doesn't process f_plugs if actually part of Debian-based build
		  [ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		  [ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
        fi
	;;
	*)	# include base, and full non-static xbps
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers base-files xbps
		# make sure xbps continues to use desired main and non-free repos
		sleep 1  # to give time for xbps static to complete above installs
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		rm /usr/bin/xbps*.static  # Since dynamic xbps now installed
		sleep 1  # to give time to make sure shared lib xbps will be used
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"

		# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
		# and/or wpasupplicant you need to xbps-install -Syu them in an f_XXX build plugin
		# For example: xbps-install -Syu eudev wpa_supplicant
		# For a bootable system you'll also want linux kernel and appropriate firmware.
		# For some detailed examples, refer to already provided FirstRib Linux f_XXX plugin files available on download site.
	;;
esac
exit
INSIDE_CHROOT
    sync;sync
	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts and clean /tmp:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
    rm -f firstrib_rootfs/etc/resolv.conf
    [ -e firstrib_rootfs/etc/resolv.confORIG -o -L firstrib_rootfs/etc/resolv.confORIG ] && mv firstrib_rootfs/etc/resolv.confORIG firstrib_rootfs/etc/resolv.conf  # put back resolv.conf to its original form
	rm -rf firstrib_rootfs/tmp/*
    [ -s ./addons_f.plug ] && . ./addons_f.plug  # for downloading layer addons and FR utils (e.g. 12KL...sfs; 11rox...sfs, wd_grubconfig)
    sync;sync
}

_debian (){
	# If you want a variant other than minbase set env variable DBTSTRP_VARIANT to variant you desire
	# For example: export DBTSTRP_VARIANT=buildd (Refer: man debootstrap)
	local debootstrap_repo="$1"; local distro_repo="$2"; local latest_file="$3"; export distro_repo

	# build firstrib_rootfsDBTSTRP
    # mkdir -p firstrib_rootfsDBTSTRP
    if [ -d firstrib_rootfsDBTSTRP ]; then
        echo firstrib_rootfsDBTSTRP exists so no need to build mini Void Linux host distro
    elif [ -e vzstdperl.sfs ];then  # no need to build new vzstdperl mini Void Linux distro if exists as sfs
        unsquashfs -d firstrib_rootfsDBTSTRP vzstdperl.sfs  # the sfs contains vzstdperl minimum filesystem build
    else
        _void_x86_64 "temp_vzstdperl"; mv firstrib_rootfs firstrib_rootfsDBTSTRP  # ready for chroot debootstrap build
        # optionally if uncomment below you can archive the newly made firstrib_rootfsDBTSTRP as vzstdperl.sfs for easier next time Debian-based builds
        # mksquashfs firstrib_rootfsDBTSTRP vzstdperl.sfs
    fi
	cd firstrib_rootfsDBTSTRP; rm -f var/cache/xbps/*  # just slims it down a wee bit before debootstrap build
	# make rootfilesystem directory structure
    # mkdir -p bin boot/kernel dev/pts etc/apt etc/skel home/debian lib media mnt opt proc root sbin sys tmp usr/bin usr/include usr/lib32 usr/libexec usr/lib/debootstrap usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/sbin usr/share/udhcpc usr/src var/log  # etc/udh$repo/os/$archcpc
    mkdir -p etc/apt home/debian usr/lib/debootstrap  #wiak remove/check if necessary

	# Using i686 32-bit busybox to begin with (user can install coreutils later if so wanted)
    ##	wget -c -nc "$busybox_url" -P bin && chmod +x bin/busybox #(already done in vzstperl containing build)
	# Make the command applet symlinks for busybox
    ##	for i in `bin/busybox --list-full`; do ln -s /bin/busybox ${i}; done #(already done in vzstperl containing build)
	# Install Debian debootstrap into debian-based-build /usr hierarchy
	mkdir -p work
	cd work
	wget -c "${debootstrap_repo}"/"${latest_file}"
	ar -x "${latest_file}"  # ar -x filename
	cd ..
	zcat work/data.tar.gz | tar xv && rm -rf work
	# Download pkgdetails from firstrib github repo, for debootstrap
    # wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/pkgdetails_musl_static_wiak -O usr/lib/debootstrap/pkgdetails && chmod +x usr/lib/debootstrap/pkgdetails
    # Alternatively: cp  ../pkgdetails usr/lib/debootstrap && chmod +x usr/lib/debootstrap/pkgdetails #wiak remove_change
	# cd to where we started this build (i.e. immediately outside of firstrib_rootfsDBTSTRP):
	cd ..

	# Next part of script does bind mounts (not really required unless using I/O) for chroot used for debootstrap build
	mount --bind /proc firstrib_rootfsDBTSTRP/proc && mount --bind /sys firstrib_rootfsDBTSTRP/sys && mount --bind /dev firstrib_rootfsDBTSTRP/dev && mount -t devpts devpts firstrib_rootfsDBTSTRP/dev/pts
    [ -e firstrib_rootfsDBTSTRP/etc/resolv.conf ] && mv firstrib_rootfsDBTSTRP/etc/resolv.conf firstrib_rootfsDBTSTRP/etc/resolv.confORIG
    cp /etc/resolv.conf firstrib_rootfsDBTSTRP/etc/resolv.conf  # changing etc/resolv.conf causes problems sometimes. For example, systemd distros want to auto-create resolv.conf as a symlink

	# debootstrap build is created inside firstrib_rootfsDBTSTRP (via here_document pipe to chroot):
	# Host Linux system does not need debootstrap installed (or perl)
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfsDBTSTRP /bin/sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
variant="minbase"
[ "\$DBTSTRP_VARIANT" ] && variant="\$DBTSTRP_VARIANT"  # man debootstrap to see variants available
# Maybe --include apt-transport-https for older distro apt, but new distros (bionic) baulk since not needed
/usr/sbin/debootstrap --extractor=ar --arch=\$arch --variant=\$variant --include=ca-certificates \$release distro_root "\$distro_repo"
exit
INSIDE_CHROOT
    sync;sync
	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfsDBTSTRP/proc && umount -l firstrib_rootfsDBTSTRP/sys && umount -l firstrib_rootfsDBTSTRP/dev/pts && umount -l firstrib_rootfsDBTSTRP/dev
    rm -f firstrib_rootfsDBTSTRP/etc/resolv.conf
    [ -e firstrib_rootfsDBTSTRP/etc/resolv.confORIG -o -L firstrib_rootfsDBTSTRP/etc/resolv.confORIG ] && mv firstrib_rootfsDBTSTRP/etc/resolv.confORIG firstrib_rootfsDBTSTRP/etc/resolv.conf  # put back resolv.conf to its original form
	rm -rf firstrib_rootfsDBTSTRP/tmp/*

	if [ ! -d firstrib_rootfsDBTSTRP/distro_root ]; then printf "\ndebootstrap download failed, please check its url\n";exit;fi
	cd firstrib_rootfsDBTSTRP/distro_root  # to add extra packages to debian-based filesystem
	mkdir -p etc/udhcpc
	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox): wiak remove but maybe not here
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script  # wiak remove but maybe not needed here

	# Install wiakwifi (can autostart on boot via /etc/profile/profile.d)
	mkdir -p usr/local/bin && wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wiakwifi -O usr/local/bin/wiakwifi && chmod +x usr/local/bin/wiakwifi
	# Install wd_mount
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wd_mount -O usr/local/bin/wd_mount && chmod +x usr/local/bin/wd_mount
	# cd to where we started this build (i.e. immediately outside of firstrib_rootfsDBTSTRP):
	cd ../..

	# Extract distro_root, the debian-based firstrib_rootfs build out of firstrib_rootfsDBTSTRP
	mv firstrib_rootfsDBTSTRP/distro_root firstrib_rootfs

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	cp -a f_* firstrib_rootfs/tmp

    [ -e firstrib_rootfs/etc/resolv.conf -o -L firstrib_rootfs/etc/resolv.conf ] && mv firstrib_rootfs/etc/resolv.conf firstrib_rootfs/etc/resolv.confORIG
    rm -f firstrib_rootfs/etc/resolv.conf
    cp -aL /etc/resolv.conf firstrib_rootfs/etc/resolv.conf  # changing etc/resolv.conf causes problems sometimes. For example, systemd distros want to auto-create resolv.conf as a symlink and cannot copy over dangling symlink

	# Next part of script does bind mounts (not really required unless using I/O) for chroot used to
	# directly install extras required or by means of f_00.plug
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT2 | LC_ALL=C chroot firstrib_rootfs /bin/sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
apt update && apt install systemd systemd-sysv -y  # so can boot using huge-kernel arrangement without needing f_00 plug extra
printf "root\nroot\n" | passwd >/dev/null 2>&1 # Quietly set default root passwd to "root"
# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
# should each simply contain a list of extra commands
[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"

# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
# and/or wpasupplicant you need to apt install them in an f_XXX build plugin
# For a bootable system you'll also want linux kernel and appropriate firmware.
# You may also need to configure system for use of other repos (e.g. non-free).
# For some detailed examples, refer to already provided FirstRib Linux f_XXX plugin files available on download site.
exit
INSIDE_CHROOT2
    sync;sync
	# Finished doing the INSIDE_CHROOT2 stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
    rm -f firstrib_rootfs/etc/resolv.conf
    [ -e firstrib_rootfs/etc/resolv.confORIG -o -L firstrib_rootfs/etc/resolv.confORIG ] && mv firstrib_rootfs/etc/resolv.confORIG firstrib_rootfs/etc/resolv.conf  # put back resolv.conf to its original form
	rm -rf firstrib_rootfs/tmp/*
	# uncomment below to: Clean up no longer required build assembly
    if [ -e vzstdperl.sfs ]; then rm -rf firstrib_rootfsDBTSTRP; fi
    [ -s ./addons_f.plug ] && . ./addons_f.plug  # for downloading layer addons and FR utils (e.g. 12KL...sfs; 11rox...sfs, wd_grubconfig)
    sync;sync
}

_arch_amd64 (){
	# Currently auto-downloading and using archstrap_wiak_mod.sh to create the base Arch rootfs build.
	# https://gitlab.com/tearch-linux/applications-and-tools
	# However, archstrap has several dependencies: 
	# bash >= 4, busybox, sed, grep, tar, zstd
	# For simplicity building Arch base outside of chroot and relying on host system to provide these
	# _arch_repo_mirrors # Choose Arch Linux repo to use for build #wiak remove: currently not being used, but keep in case
	# export MIRROR="${repo}" #wiak remove: probably not required
	# Download archstrap scripts:
	# Previous (only works with http, not https): wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/arch-bootstrap.sh && chmod +x arch-bootstrap.sh
	# ./arch-bootstrap.sh -a $arch firstrib_rootfs #  -r "${repo}" 
	# Other (had issues): wget -c https://raw.githubusercontent.com/BiteDasher/archbashstrap/master/packages
	#./archbashstrap firstrib_rootfs
	#wget -c https://gitlab.com/tearch-linux/applications-and-tools/archstrap/-/raw/master/archstrap.sh && chmod +x archstrap.sh
	# ./archstrap.sh firstrib_rootfs  # wiak remove: not using chosen repo -r "${repo}/\\\$repo/os/\\\$arch"
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/archstrap_wiak_mod.sh && chmod +x archstrap_wiak_mod.sh
	./archstrap_wiak_mod.sh firstrib_rootfs  # not using repo -r
	cd firstrib_rootfs

	# pacman.conf configurations #wiak remove: maybe required or needs modified?
	sed -i 's/^CheckSpace/#CheckSpace/g' etc/pacman.conf
	sed -i 's/^#ParallelDownloads/ParallelDownloads/g' etc/pacman.conf
	sed -i "s/^[[:space:]]*\(CheckSpace\)/# \1/" etc/pacman.conf
	sed -i "s/^[[:space:]]*SigLevel[[:space:]]*=.*$/SigLevel = Never/" etc/pacman.conf
	cd .. # to immediately outside of firstrib_rootfs

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	cp -a f_* firstrib_rootfs/tmp

    [ -e firstrib_rootfs/etc/resolv.conf -o -L firstrib_rootfs/etc/resolv.conf ] && mv firstrib_rootfs/etc/resolv.conf firstrib_rootfs/etc/resolv.confORIG
    rm -f firstrib_rootfs/etc/resolv.conf
    cp -aL /etc/resolv.conf firstrib_rootfs/etc/resolv.conf  # changing etc/resolv.conf causes problems sometimes. For example, systemd distros want to auto-create resolv.conf as a symlink and cannot copy over dangling symlink

	# Next part of script does bind mounts (not really required unless using I/O) for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfs sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
# should each simply contain a list of extra commands
[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"

# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
# and/or wpasupplicant you need to apt install them in an f_XXX build plugin
# For a bootable system you'll also want linux kernel and appropriate firmware.
# You may also need to configure system for use of other repos (e.g. non-free).
# For some detailed examples, refer to already provided FirstRib Linux f_XXX plugin files available on download site.
exit
INSIDE_CHROOT
    sync;sync
	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
    rm -f firstrib_rootfs/etc/resolv.conf
    [ -e firstrib_rootfs/etc/resolv.confORIG -o -L firstrib_rootfs/etc/resolv.confORIG ] && mv firstrib_rootfs/etc/resolv.confORIG firstrib_rootfs/etc/resolv.conf  # put back resolv.conf to its original form
	rm -rf firstrib_rootfs/tmp/*
    [ -s ./addons_f.plug ] && . ./addons_f.plug  # for downloading layer addons and FR utils (e.g. 12KL...sfs; 11rox...sfs, wd_grubconfig)
    sync;sync
}

#*PREVIOUS WAY
#*_arch_amd64 (){
#*	# Currently auto-downloading and using arch-bootstrap to create the base Arch rootfs build.
#*	# However, arch_bootstrap has several dependencies: 
#*	# bash >= 4, coreutils, wget, sed, gawk, tar, gzip, chroot, xz
#*	# so for simplicity building Arch base outside of chroot and relying on host system to provide these
#*	_arch_repo_mirrors # Choose Arch Linux repo to use for build

#*    mkdir -p firstrib_rootfs
#*    cd firstrib_rootfs
#*    cd ..  # to immediately outside of firstrib_rootfs
#*	# build firstrib_rootfs
#*	# Download arch_debootstrap scripts:
#*	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/core_resources/arch-bootstrap.sh && chmod +x arch-bootstrap.sh
#*	./arch-bootstrap.sh -a $arch -r "${repo}" firstrib_rootfs
#*	cd firstrib_rootfs

#*	mkdir -p etc/udhcpc # needed to receive udhcpc default.script
#*	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
#*	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
#*	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
#*	# udhcpc sometimes needs default.script in /usr/share/udhcpc:
#*	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script
#*	# Install wiakwifi (can autostart on boot via /etc/profile/profile.d)
#*	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wiakwifi -O usr/local/bin/wiakwifi && chmod +x usr/local/bin/wiakwifi
#*	# Install wd_mount
#*	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wd_mount -O usr/local/bin/wd_mount && chmod +x usr/local/bin/wd_mount
#*	cd .. # to immediately outside of firstrib_rootfs

#*	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
#*	cp -a f_* firstrib_rootfs/tmp

#*	# Next part of script does bind mounts (not really required unless using I/O) for chroot and installs extras required
#*	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf

#*	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
#*cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfs sh
#*export PATH=/sbin:/usr/sbin:/bin:/usr/bin
#*# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
#*# should each simply contain a list of extra commands
#*[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
#*[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"

#*# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
#*# and/or wpasupplicant you need to apt install them in an f_XXX build plugin
#*# For a bootable system you'll also want linux kernel and appropriate firmware.
#*# You may also need to configure system for use of other repos (e.g. non-free).
#*# For some detailed examples, refer to already provided FirstRib Linux f_XXX plugin files available on download site.
#*exit
#*INSIDE_CHROOT
#*  sync;sync
#*	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
#*	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
#*	rm -rf firstrib_rootfs/tmp/*
#*}

_fedora_amd64 (){ # wiak remove later: under dev/test
	# Currently auto-downloading and using fdstrap () to create the base fedora rootfs build.
	# https://gitlab.com/tearch-linux/applications-and-tools

	# build firstrib_rootfs
	# Download fdstrap scripts:
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/fdstrap.sh && chmod +x fdstrap.sh
#	wget -c https://gitlab.com/tearch-linux/applications-and-tools/fdstrap/-/raw/main/fdstrap.sh && chmod +x fdstrap.sh
	./fdstrap.sh firstrib_rootfs
	cd firstrib_rootfs
	mkdir -p etc/udhcpc # needed to receive udhcpc default.script
	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# udhcpc sometimes needs default.script in /usr/share/udhcpc:
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script
	# Install wiakwifi (can autostart on boot via /etc/profile/profile.d) - but optional since likely using NetworkManager now
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wiakwifi -O usr/local/bin/wiakwifi && chmod +x usr/local/bin/wiakwifi
	# Install wd_mount
	wget -c https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/wd_mount -O usr/local/bin/wd_mount && chmod +x usr/local/bin/wd_mount
	cd .. # to immediately outside of firstrib_rootfs

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	cp -a f_* firstrib_rootfs/tmp

    [ -e firstrib_rootfs/etc/resolv.conf -o -L firstrib_rootfs/etc/resolv.conf ] && mv firstrib_rootfs/etc/resolv.conf firstrib_rootfs/etc/resolv.confORIG
    rm -f firstrib_rootfs/etc/resolv.conf
    cp -aL /etc/resolv.conf firstrib_rootfs/etc/resolv.conf  # changing etc/resolv.conf causes problems sometimes. For example, systemd distros want to auto-create resolv.conf as a symlink and cannot copy over dangling symlink

	# Next part of script does bind mounts (not really required unless using I/O) for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfs sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
printf "root\nroot\n" | passwd >/dev/null 2>&1 # Quietly set default root passwd to "root"
dnf upgrade && dnf install iproute -y; ln -s /sbin/busybox /sbin/udhcpc; ln -s /sbin/busybox /sbin/ping  # so can boot using huge-kernel arrangement without needing f_00 plug extra
# dnf clean all  # clean all package caches and so on
# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
# should each simply contain a list of extra commands
[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"

# NOTE WELL: If not using huge-kernel, 00modules/01firmware addons, you'll need dnf install kernel linux-firmware
exit
INSIDE_CHROOT
    sync;sync
	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
    rm -f firstrib_rootfs/etc/resolv.conf
    [ -e firstrib_rootfs/etc/resolv.confORIG -o -L firstrib_rootfs/etc/resolv.confORIG ] && mv firstrib_rootfs/etc/resolv.confORIG firstrib_rootfs/etc/resolv.conf  # put back resolv.conf to its original form
	rm -rf firstrib_rootfs/tmp/*
    [ -s ./addons_f.plug ] && . ./addons_f.plug  # for downloading layer addons and FR utils (e.g. 12KL...sfs; 11rox...sfs, wd_grubconfig)
    sync;sync
}

#### ----------------- end of functions used

_usage "$1"  # check if - or --cmdarg (e.g. --version or -h for help)
echo "Initialising FirstRib build. Please wait patiently..."
case "$distro" in
	arch|Arch) :
	;;
	*)
# disabled for now cos slow to reach		busybox_repo="https://busybox.net/downloads/binaries/"
# disabled for now cos slow to reach		busybox_dir=`wget -q -O - $busybox_repo | sed 's/a href=\"//' |  grep -o -E "[^<>]*?i686-linux-musl" | sort -V | tail -n 1` # thanks fredx181
# disabled for now cos slow to reach		busybox_url="${busybox_repo}${busybox_dir}/busybox"
		busybox_url="https://gitlab.com/firstrib/firstrib/-/raw/master/latest/build_system/upstream_bins/busybox"
	;;
esac
case "$distro" in
	void|Void|vmini|vzstdperl|vnopm)
		case "$arch" in
			amd64)
				_void_x86_64 "$distro"	# call build Void amd64 function
			;;
			i686)
				_void_i686 "$distro"	# call build Void i386 function
			;;
			arm64)
				echo "arch $arch is supported by Void but not yet FirstRib";_usage "--help";exit
			;;
			*) # no such arch catered for
				echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	ubuntu|Ubuntu)
		case "$release" in
			oldstable|stable|testing|unstable|xenial|bionic|focal|jammy)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_repo="http://archive.ubuntu.com/ubuntu/pool/main/d/debootstrap"
# very latest ubuntu debootstrap not currently working... _getlatestfile "$debootstrap_repo" "_all.deb" "grep -vE \(nmu|ubuntu\)"
latest_file="debootstrap_1.0.128+nmu2ubuntu1_all.deb" # wiak temporarily not using _getlatestfile routine for Ubuntu since most recent debootstrap version not including Ubuntu distros...
						distro_repo="http://archive.ubuntu.com/ubuntu/"
						_debian "$debootstrap_repo" "$distro_repo" "$latest_file" # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	debian|Debian)
		case "$release" in
			oldstable|stable|testing|unstable|stretch|buster|sid)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_repo="http://ftp.debian.org/debian/pool/main/d/debootstrap"
						_getlatestfile "$debootstrap_repo" "_all.deb" "grep -vE \(nmu|debian\)"
						distro_repo="http://ftp.us.debian.org/debian/"
						_debian "$debootstrap_repo" "$distro_repo" "$latest_file" # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	devuan|Devuan)
		case "$release" in
			oldstable|stable|testing|unstable|ascii|beowulf|ceres|chimaera|daedalus)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_repo="http://pkgmaster.devuan.org/devuan/pool/main/d/debootstrap"
						_getlatestfile "$debootstrap_repo" "_all.deb" "grep -vE \(nmu\)"
						distro_repo="http://pkgmaster.devuan.org/merged/"
						_debian "$debootstrap_repo" "$distro_repo" "$latest_file" # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	arch|Arch)  # wiak remove later: Arch Linux - under development
		case "$arch" in
			amd64)
				arch=x86_64
				_arch_amd64  # call build Arch amd64 function
			;;
			*) # no such arch catered for
				echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	fedora|Fedora)  # wiak remove later: Fedora Linux - under development
		case "$arch" in
			amd64)
				arch=x86_64
				_fedora_amd64  # call build Arch amd64 function
			;;
			*) # no such arch catered for
				echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	*) # no such distro catered for
	echo "distro $distro not currently available from FirstRib";_usage "--help";exit
	;;
esac
sync
printf "
Assuming no errors have occurred above,
firstrib_rootfs flavour $distro $release $arch is now ready.
If you wish, you can now use it via convenience script,
./mount_chrootXXX.sh and after such use, exit, and, IMPORTANT:
run ./umount_chrootXXX.sh to clean up temporary mounts.
Or, you can make it bootable via wiak's FirstRib initrd (initramfs)
after downloading that and suitable huge-kernel/00modules/01firmware
Alternativly, can use non-huge-style kernel and run command:
./FRmake_initrd.sh (use that scripts --help for details)
which auto-downloads FR initrd-latest.gz and remakes it correctly or
earlier technique of running command:
./build_wiak_initrdXXX.sh <distroname> [OPTIONS], and then
frugal install it by copying the resultant initrdXX, vmlinuz,
and firstrib_rootfs.sfs (or firstrib_rootfs directory) into
/mnt/bootpartition/bootdir and configuring grub to boot it.
NOTE WELL: firstrib_rootfs needs renamed NN<anything> For example:
08rootfs or 08rootfs.sfs (if squashed using mksquashfs utility),
or for a pseudo-full-install only: rename uncompressed firstrib_rootfs
as upper_changes and mkdir -p NNdummy (e.g. 08dummy)
More details on booting at end of build_firstrib_initrd script.
Refer to $HERE/grub_config.txt for related booting information.
"
_grub_config
exit 0


