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

UBOOT_DIR="../u-boot"
KERNEL_FIT_ITS="dfd_boot.its"
UIMAGE_ITB_FILE="boot.itb"

DTB="arch/arm64/boot/dts/dfd/dfd.dtb"

top=$(pwd)

if [ $# -eq 0 ]; then
        args_list="-db"
else
        args_list=$@
fi

echo -n "Args list: $args_list"

info() { echo -e "\n\e[34m$@\e[0m"; }
warn() { echo -e "\n\e[33m$@\e[0m"; }

set -- $(getopt -q dmbch "$args_list")
while [ -n "$1" ]
do
        case "$1" in
                -d) info "Defconfig"
			set -x
			make $KDEFCONFIG
			set +x
                        shift ;;
                -m) info "Menuconfig"
			set -x
			make menuconfig
			make savedefconfig
			cp -v defconfig arch/${ARCH}/configs/$KDEFCONFIG
			set +x
                        shift ;;
                -b) info "Build Project"
			KVER=$(make kernelversion)
			echo "----KVER=$KVER"
			KREL=$(make kernelrelease)
			echo "====KREL=$KREL"

			set -x
                        bear -- make KBUILD_IMAGE=Image.lzma -j`nproc`
			#bear -- make KERNELRELEASE=6.16.0 KBUILD_IMAGE=Image.lzma -j`nproc`
			${UBOOT_DIR}/tools/mkimage -f linux_dfd.its boot.bin
			set +x
			ls -lsh arch/$ARCH/boot/Image*
                        shift ;;
                -c) info "Clean project"
			set -x
                        make distclean
			set +x
                        shift ;;
                -h) info "Help"
			echo "-d defconfig"
			echo "-m menuconfig"
			echo "-b build make"
			echo "-c distclean"
                        shift ;;
                --) shift
                        break ;;
                -*) warn "Nothing to do";;
        esac
done


