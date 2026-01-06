#!/bin/bash
##########################################################
# File Name		: m.sh
# Author		: winddoing
# Created Time	: 2022年01月18日 星期二 19时52分13秒
# Description	:
##########################################################
set -eo pipefail

export ARCH="arm64"
export CROSS_COMPILE="aarch64-linux-gnu-"

KDEFCONFIG="dfd_defconfig"

UBOOT_DIR="../uboot"
KERNEL_FIT_ITS="dfd_boot.its"
UIMAGE_ITB_FILE="boot.itb"

DTB="arch/arm64/boot/dts/dfd.dtb"

make_kernel() {
	echo "Build kernel ($KDEFCONFIG)"

	set -x
	make $KDEFCONFIG
	#make O=build $KDEFCONFIG

	#sed -i "/CONFIG_BLK_DEV_INITRD=y/d" .config
	#bear -- make KBUILD_IMAGE=Image.lzma -j'nproc'
	bear -- make -j`nproc`
	#make KBUILD_IMAGE=Image.lzma O=build -j'nproc'
	#make -j`nproc`

	${UBOOT_DIR}/tools/mkimage -f $KERNEL_FIT_ITS $UIMAGE_ITB_FILE
	set +x
}

save_defconfig() {
	echo "Save defconfig ($KDEFCONFIG)"

	set -x
	make savedefconfig
	cp -v defconfig arch/${ARCH}/configs/$KDEFCONFIG
	set +x
}

make_config()
{
	echo "Make menuconfig ($KDEFCONFIG)"

	set -x
	make $KDEFCONFIG
	make menuconfig
	set +x
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
		h|help      	Help
		s|save      	Save current config
		c|config    	make menuconfig
		d|distclean	distclean
		m|make      	Build kernel
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
	*)
		make_kernel
		;;
esac
