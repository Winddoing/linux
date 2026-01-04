#!/bin/bash
# * ============================================================================
# * Script for setup build environment
# * Copyright (C): 2021 vanxum 
# * ============================================================================

export ARCH="arm64"
export CROSS_COMPILE="aarch64-none-elf-"
#export CROSS_COMPILE="aarch64-none-linux-gnu-"
#export CROSS_COMPILE="aarch64-linux-gnu-"

VXCONFIG=defconfig

set -x

if [ x$1 = x"m" ]
then
	echo "do make menuconfig"
	make $VXCONFIG
	make menuconfig
	exit
elif [ x$1 = x"c" ]
then
	make mrproper
	make clean
	make distclean
	exit
elif [ x$1 = x"s" ]
then
	echo "do make savedefconfig"
	make savedefconfig
	cp  defconfig arch/arm64/configs/$VXCONFIG
	exit
fi

set -x
make $VXCONFIG
#sed -i "/CONFIG_BLK_DEV_INITRD=y/d" .config
bear -- make KBUILD_IMAGE=Image.lzma -j8

#make O=build $VXCONFIG
#make KBUILD_IMAGE=Image.lzma O=build -j8
[ $? -ne 0 ] && exit;

echo "Done."


