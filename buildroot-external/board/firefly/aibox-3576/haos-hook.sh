#!/bin/bash
# shellcheck disable=SC2155

function filt_val()
{
	sed -n "/${1}=/s/${1}=//p" $2 | tr -d '\r' | tr -d '"'
}

function haos_pre_image() {
    local BOOT_DATA="$(path_boot_dir)"
    local RK_SOC_FAMILY="rk3576"
    local RK_IDBLOCK_IMG="idblock.img"
    local RK_LOADER_BIN="loader.bin"
    local TMP_INI="tmp/MINIALL.ini"
    local SPL_BIN=""
    local RK_UBOOTSPL="1"

    cp "${BINARIES_DIR}/boot.scr" "${BOOT_DATA}/boot.scr"
    cp "${BINARIES_DIR}"/*.dtb "${BOOT_DATA}/"

    cp "${BOARD_DIR}/boot-env.txt" "${BOOT_DATA}/haos-config.txt"
    cp "${BOARD_DIR}/cmdline.txt" "${BOOT_DATA}/cmdline.txt"

    if [ "x${UBOOT_CUSTOM_VERSION_VALUE}" != "x" ]; then
        cd ${BUILD_DIR}
        rm -f rkbin
        ln -sn rockchip-blobs-${ROCKCHIP_BLOBS_VERSION} rkbin

        pushd ${BUILD_DIR}/uboot-${UBOOT_CUSTOM_VERSION_VALUE} > /dev/null
        if [ ! -d "bin" ]; then
            cp -rf ../rkbin/bin .
        fi
    
        find ${BINARIES_DIR} -name "*_loader*.bin" -delete

        if [ "x${RK_UBOOTSPL}" == "x1" ]; then
            SPL_BIN=${BUILD_DIR}/uboot-${UBOOT_CUSTOM_VERSION_VALUE}/spl/u-boot-spl.bin
            rm tmp -rf && mkdir tmp -p
            cp ../rkbin/RKBOOT/${INI_LOADER} ${TMP_INI}
            cp ${SPL_BIN} tmp/u-boot-spl.bin
            sed -i "s/FlashBoot=.*$/FlashBoot=.\/tmp\/u-boot-spl.bin/" ${TMP_INI}

            ../rkbin/tools/boot_merger ${TMP_INI}
            rm tmp/ -rf
        else
            ../rkbin/tools/boot_merger ../rkbin/RKBOOT/${INI_LOADER}
        fi

        cp *_loader*.bin ${BINARIES_DIR}

        # Generate idblock image
        echo "Generating ${RK_IDBLOCK_IMG}..."

        SPL_BIN=../rkbin/$(cat ../rkbin/RKBOOT/${INI_LOADER} | grep FlashBoot= | cut -d "=" -f 2)
        TPL_BIN=../rkbin/$(cat ../rkbin/RKBOOT/${INI_LOADER} | grep FlashData= | cut -d "=" -f 2)
        ./tools/mkimage -n "${RK_SOC_FAMILY}" -T rksd -d ${TPL_BIN}:${SPL_BIN} idblock.bin
        cp idblock.bin "${BINARIES_DIR}/${RK_IDBLOCK_IMG}"
        popd > /dev/null

        cd ${BINARIES_DIR}
        ln -sf *_loader*.bin loader.bin
    fi

}

function gen_rkparameter() {
    if [ ! -f "${BINARIES_DIR}/loader.bin" ]; then
        echo "Skip making Rockchip parameter."
        return
    fi

    IMAGE="$(haos_image_name img)"
    if [ ! -f "${IMAGE}" ]; then
        echo "${IMAGE} not found."
        return
    fi
    PARTUUID_A=8d3d53e3-6d49-4c38-8349-aff6859e82fd
    PARTUUID_B=a3ec664e-32ce-4665-95ea-7ae90ce9aa20

    cd "${BINARIES_DIR}"

    OUT="$(haos_image_basename).parameter"
    ln -sf $(basename ${OUT}) parameter

    echo "Generating ${OUT}..."

    echo "# IMAGE_NAME: ${IMAGE}" > "${OUT}"
    echo "FIRMWARE_VER: 1.0" >> "${OUT}"
    echo "TYPE: GPT" >> "${OUT}"
    echo -n "CMDLINE: mtdparts=rk29xxnand:" >> "${OUT}"
    sgdisk -p "${IMAGE}" | grep -E "^ +[0-9]" | while read line;do
        NAME=$(echo ${line} | cut -f 7 -d ' ')
        START=$(echo ${line} | cut -f 2 -d ' ')
        END=$(echo ${line} | cut -f 3 -d ' ')
        SIZE=$(expr ${END} - ${START} + 1)
        printf "0x%08x@0x%08x(%s)," ${SIZE} ${START} ${NAME} >> "${OUT}"
    done

    # userdata
    if [ "$RK_PARTITION_USERDATA" = "1" ]; then
        sgdisk -p "${IMAGE}" | grep -E "^ +[0-9]" | tail -n 1 | while read line; do
            END=$(echo ${line} | cut -f 3 -d ' ')
            END=$(expr ${END} + 1)
            SIZE="0"
            printf "0x%08x@0x%08x(%s:grow)" ${SIZE} ${END} "userdata" >> "${OUT}"
        done
    fi

    echo >> "${OUT}"
    echo "uuid: hassos-system0=${PARTUUID_A}" >> "${OUT}"
    echo "uuid: hassos-system1=${PARTUUID_B}" >> "${OUT}"
}

function gen_rkupdateimg() {
    if [ ! -f "${BINARIES_DIR}/loader.bin" ]; then
        echo "Skip packing Rockchip update image."
        return
    fi

    IMAGE="$(haos_image_name img)"
    if [ ! -f "${IMAGE}" ]; then
        echo "${IMAGE} not found."
        return
    fi

    RK_PACK_TOOL_DIR=${HOST_DIR}/bin
    if [ ! -x ${RK_PACK_TOOL_DIR}/afptool ]; then
        echo "Rockchip Tools is not install!"
        return
    fi

    cd "${BINARIES_DIR}"

    OUT="$(haos_image_basename).package-file"
    ln -sf $(basename ${OUT}) package-file

    echo "Generating ${OUT}..."

    echo "# IMAGE_NAME: ${IMAGE}" > "${OUT}"
    echo "package-file package-file" >> "${OUT}"
    echo "bootloader loader.bin" >> "${OUT}"
    echo "parameter parameter" >> "${OUT}"
    #echo "uboot uboot.img" >> "${OUT}"
    grep -o "([^)^:]*" parameter | tr -d "(" | while read NAME;do
       case "${NAME}" in
            uboot-env) IMAGE="uboot.env" ;;
            spl) IMAGE="spl.img" ;;
            uboot) IMAGE="uboot.img" ;;
            backup) echo "backup RESERVED" >> "${OUT}"; continue ;;
            overlay) echo "overlay RESERVED" >> "${OUT}"; continue ;;
                hassos-boot) IMAGE="boot.vfat" ;;
                hassos-kernel0|hassos-kernel1) IMAGE="kernel.img" ;;
                hassos-system0|hassos-system1) IMAGE="rootfs.erofs" ;;
                hassos-overlay) IMAGE="overlay.ext4" ;;
                hassos-data) IMAGE="data.ext4" ;;
            *) IMAGE="${NAME}.img" ;;
        esac

        [ ! -r "$IMAGE" ] || echo "$NAME $IMAGE" >> "${OUT}"
    done

    PSEUDO_DISABLED=1
    ${RK_PACK_TOOL_DIR}/afptool -pack ./ update.raw.img
    ${RK_PACK_TOOL_DIR}/rkImageMaker -RK$(hexdump -s 21 -n 4 -e '4/1 "%c"' loader.bin | rev) \
        loader.bin update.raw.img "$(haos_image_basename).update.img" \
        -os_type:androidos
    ln -sf $(basename "$(haos_image_basename).update.img") update.img

    rm -rf update.raw.img
}

function gen_cfg() {
    if [ -f "${BOARD_DIR}/haos.cfg" ]; then
        cp "${BOARD_DIR}/haos.cfg" "${BINARIES_DIR}"
    fi

    # get u-boot.itb
    if [ -f "${BINARIES_DIR}/spl.img" ]; then
        dd if=${BINARIES_DIR}/spl.img of=${BINARIES_DIR}/tmp.img bs=1 skip=8388608 count=4194304 > /dev/null 2>&1
        cat ${BINARIES_DIR}/tmp.img > ${BINARIES_DIR}/uboot.img
        cat ${BINARIES_DIR}/tmp.img >> ${BINARIES_DIR}/uboot.img
        rm -f ${BINARIES_DIR}/tmp.img
    fi
}

function haos_post_image() {
    gen_cfg
    gen_rkparameter
    #gen_rkupdateimg
    convert_disk_image_xz
}

