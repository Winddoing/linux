#!/bin/bash
##########################################################
# File Name		: m.sh
# Author		: winddoing
# Created Time	: 2022年01月18日 星期二 19时52分13秒
# Description	:
##########################################################


export ARCH=arm
export CROSS_COMPILE=arm-none-eabi-

make_kernel() {
	echo "Build kernel"
	set -x

	#make distclean
	#make clean
	make s5pv210_wdg_defconfig
	make -j`nproc`

	make uImage LOADADDR=0x20008000
	cp arch/arm/boot/uImage ~/tftprootfs

	cp arch/arm/boot/dts/s5pv210-wdg.dtb ~/tftprootfs
	cp arch/arm/boot/zImage ~/tftprootfs

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
	local sd_dev="/dev/sda"

	if [ ! -b $sd_dev ]; then
		echo "SD dev($sd_dev) does not exist"
		exit 255
	fi

	set -x
	sudo dd if=$spl_bin of=$sd_dev bs=512 seek=1
	sudo dd if=$uboot_bin of=$sd_dev bs=512 seek=49

	sync
	set +x
}

make_config()
{
	echo "Make menuconfig"

	make s5pv210_wdg_defconfig
	make menuconfig
}

usage() {
cat << EOF
	*** No parameters for compiling kernel ***

	Usage:
	  $0 <option>

	option:
		h|help      Help
		s|save      Save current config
		c|config    make menuconfig
		m|make      Build kernel
		b|burn      Burn dts & kernel to SD
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
	m|make)
		make_kernel
		;;
	b|burn)
		burn_kernel
		;;
	*)
		make_kernel
		;;
esac
