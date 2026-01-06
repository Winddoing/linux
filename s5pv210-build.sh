#!/bin/bash
##########################################################
# File Name		: m.sh
# Author		: winddoing
# Created Time	: 2022年01月18日 星期二 19时52分13秒
# Description	:
##########################################################
set -eo pipefail

export ARCH=arm
export CROSS_COMPILE=arm-none-eabi-

BURN_SD_DEV="/dev/sda"

UBOOT_DIR="../uboot"
KERNEL_FIT_ITS="wdg_boot.its"
UIMAGE_ITB_FILE="boot.itb"

WDG_DTB="arch/arm/boot/dts/samsung/s5pv210-wdg.dtb"

make_kernel() {
	echo "Build kernel"
	set -x

	#make distclean
	#make clean
	make s5pv210_wdg_defconfig
	make -j`nproc`

	${UBOOT_DIR}/tools/mkimage -f $KERNEL_FIT_ITS $UIMAGE_ITB_FILE
	cp $UIMAGE_ITB_FILE ~/tftprootfs

	set +x
}

save_defconfig() {
	echo "Save defconfig"
	set -x

	make savedefconfig
	cp -v defconfig arch/arm/configs/s5pv210_wdg_defconfig

	set +x
}

burn_kernel() {
	echo "Burn kernel"
	local zImage="arch/arm/boot/zImage"
	local boot_mode="$1"

	if [ ! -b $BURN_SD_DEV ]; then
		echo "SD dev($BURN_SD_DEV) does not exist"
		exit 255
	fi

	if [ ! -f $zImage ] && [ ! -f $WDG_DTB ]; then
		echo "zImage or dtb file not generated"
		exit 255
	fi

	sudo fdisk $BURN_SD_DEV -l | grep "SD" > /dev/null
	if [ $? -ne 0 ]; then
		echo "the current device($BURN_SD_DEV) is not an SD card"
		exit 255
	fi

	echo "MMC boot mode: $boot_mode"
	case $boot_mode in
		mmcfatboot)
			local vfat_boot="boot.fat"
			set -x
			sudo dd if=/dev/zero of=${vfat_boot} bs=1M count=8
			sudo mkfs.fat ${vfat_boot}
			sudo mount -o loop ${vfat_boot} /mnt/
			sudo cp $zImage $WDG_DTB /mnt/
			sudo umount /mnt
			sudo dd if=boot.fat of=$BURN_SD_DEV bs=512 seek=4096	   #0x1000
			set +x
			;;
		mmcrawboot)
			set -x
			sudo dd if=$zImage of=$BURN_SD_DEV bs=512 seek=4096		#0x1000
			sudo dd if=$WDG_DTB of=$BURN_SD_DEV bs=512 seek=18432	#0x4800
			set +x
			;;
		mmcfitboot)
			set -x
			sudo dd if=$UIMAGE_ITB_FILE of=$BURN_SD_DEV bs=512 seek=4096  #0x1000
			set +x
			;;
		*)
			echo "Default boot mmcfitboot"
			set -x
			sudo dd if=$UIMAGE_ITB_FILE of=$BURN_SD_DEV bs=512 seek=4096  #0x1000
			set +x
			;;
	esac

	set -x
	sync
	set +x
}

make_config()
{
	echo "Make menuconfig"

	make s5pv210_wdg_defconfig
	make menuconfig
}

distclean()
{
	echo "Clean"

	set -x
	make mrproper
	make clean
	make distclean
	set +x
}

usage() {
cat << EOF
	*** No parameters for compiling kernel ***

	Usage:
	  $0 <option>

	option:
		h|help		Help
		s|save		Save current config
		c|config	make menuconfig
		d|distclean	Build kernel
		m|make		Build kernel
		b|burn		Burn dts & kernel to SD
                    Boot mode supported by mmc:
                "mmcfatboot", "mmcfatboot", "mmcfitboot(default)"
EOF
}

case $1 in
	h|help)
		usage
		;;
	c|config)
		make_config
		save_defconfig
		;;
	s|save)
		save_defconfig
		;;
	d|distclean)
		distclean
		;;
	m|make)
		make_kernel
		;;
	b|burn)
		burn_kernel $2
		;;
	*)
		make_kernel
		;;
esac
