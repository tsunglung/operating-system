#!/bin/bash

function echo_red() {
	echo -e '\033[1;31m'"$@"'\033[0m'
}

function echo_purple() {
	echo -e '\033[1;35m'"$@"'\033[0m'
}

function echo_blue() {
	echo -e '\033[1;34m'"$@"'\033[0m'
}

function do_abort() {
	if [ -e Not ]; then
		rm -f Not
	fi
	exit $1
}

OUTPUT_IMAGE=/Volumes/haos/output/images
UPGRADE_TOOL=${PWD}/output/host/bin/upgrade_tool

function check_rockusb() {
	# DevNo=1 Vid=0x2207,Pid=0x350e,LocationID=33     Mode=Loader     SerialNo=
	device=$(${UPGRADE_TOOL} ld | grep "Maskrom")
}


function check_answer_and_upgrade() {

	case $ANSWER in

	1)
		${UPGRADE_TOOL} uf ${OUTPUT_IMAGE}/update.img
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	2)
		${UPGRADE_TOOL} di -hassos-kernel0 ${OUTPUT_IMAGE}/kernel.img
		${UPGRADE_TOOL} di -hassos-kernel1 ${OUTPUT_IMAGE}/kernel.img
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	24)
		${UPGRADE_TOOL} di -hassos-boot ${OUTPUT_IMAGE}/boot.vfat
		${UPGRADE_TOOL} di -hassos-kernel0 ${OUTPUT_IMAGE}/kernel.img
		${UPGRADE_TOOL} di -hassos-kernel1 ${OUTPUT_IMAGE}/kernel.img
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	3)
		${UPGRADE_TOOL} di -hassos-system0 ${OUTPUT_IMAGE}/rootfs.erofs
		${UPGRADE_TOOL} di -hassos-system1 ${OUTPUT_IMAGE}/rootfs.erofs
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	4)
		${UPGRADE_TOOL} wl 0x4000 ${OUTPUT_IMAGE}/uboot.img
		${UPGRADE_TOOL} di -hassos-boot ${OUTPUT_IMAGE}/boot.vfat
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	45)
		${UPGRADE_TOOL} wl 0x4000 ${OUTPUT_IMAGE}/uboot.img
		${UPGRADE_TOOL} di -hassos-boot ${OUTPUT_IMAGE}/boot.vfat
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	5)
		${UPGRADE_TOOL} wl 0x4000 ${OUTPUT_IMAGE}/uboot.img
		${UPGRADE_TOOL} di -hassos-boot ${OUTPUT_IMAGE}/boot.vfat
		${UPGRADE_TOOL} di -hassos-kernel0 ${OUTPUT_IMAGE}/kernel.img
		${UPGRADE_TOOL} di -hassos-kernel1 ${OUTPUT_IMAGE}/kernel.img
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	a)
		${UPGRADE_TOOL} di -p ${OUTPUT_IMAGE}/parameter
		${UPGRADE_TOOL} wl 0x4000 ${OUTPUT_IMAGE}/uboot.img
		${UPGRADE_TOOL} di -hassos-boot ${OUTPUT_IMAGE}/boot.vfat
		${UPGRADE_TOOL} di -hassos-kernel0 ${OUTPUT_IMAGE}/kernel.img
		${UPGRADE_TOOL} di -hassos-system0 ${OUTPUT_IMAGE}/rootfs.erofs
		${UPGRADE_TOOL} di -hassos-kernel1 ${OUTPUT_IMAGE}/kernel.img
		${UPGRADE_TOOL} di -hassos-system1 ${OUTPUT_IMAGE}/rootfs.erofs
		#${UPGRADE_TOOL} di -hassos-overlay ${OUTPUT_IMAGE}/overlay.ext4
		#${UPGRADE_TOOL} di -hassos-data ${OUTPUT_IMAGE}/data.ext4
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	u)
		${UPGRADE_TOOL} wl 0x4000 ${OUTPUT_IMAGE}/uboot.img
		${UPGRADE_TOOL} rd
		QUIT=true
		;;

	q | 9) do_abort 0;;
	100)
		echo_red "== RUN COMMAND $VAROPTS ==";
		eval "$VAROPTS";
		do_abort $?;;

	*)
		echo_red "====================================================="
		echo_red "== $ANSWER =="
		echo_red "I didn't understand your response.  Please try again."
		echo
		;;

	esac
}

ANSWER=$1
check_rockusb
check_answer_and_upgrade
