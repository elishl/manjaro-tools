#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

prepare_initcpio(){
    msg2 "Copying initcpio ..."
    cp /etc/initcpio/hooks/miso* $1/etc/initcpio/hooks
    cp /etc/initcpio/install/miso* $1/etc/initcpio/install
    cp /etc/initcpio/miso_shutdown $1/etc/initcpio
}

prepare_initramfs(){
    cp ${DATADIR}/mkinitcpio.conf $1/etc/mkinitcpio-${iso_name}.conf
    local _kernver=$(cat $1/usr/lib/modules/*/version)
    if [[ -n ${gpgkey} ]]; then
        su ${OWNER} -c "gpg --export ${gpgkey} >${USERCONFDIR}/gpgkey"
        exec 17<>${USERCONFDIR}/gpgkey
    fi
    MISO_GNUPG_FD=${gpgkey:+17} chroot-run $1 \
        /usr/bin/mkinitcpio -k ${_kernver} \
        -c /etc/mkinitcpio-${iso_name}.conf \
        -g /boot/initramfs.img

    if [[ -n ${gpgkey} ]]; then
        exec 17<&-
    fi
    if [[ -f ${USERCONFDIR}/gpgkey ]]; then
        rm ${USERCONFDIR}/gpgkey
    fi
}

prepare_boot_extras(){
    cp $1/boot/intel-ucode.img $2/intel_ucode.img
    cp $1/usr/share/licenses/intel-ucode/LICENSE $2/intel_ucode.LICENSE
    cp $1/boot/memtest86+/memtest.bin $2/memtest
    cp $1/usr/share/licenses/common/GPL2/license.txt $2/memtest.COPYING
}

vars_to_boot_conf(){
    sed -e "s|@ISO_NAME@|${iso_name}|g" \
        -e "s|@ISO_LABEL@|${iso_label}|g" \
        -e "s|@DIST_NAME@|${dist_name}|g" \
        -e "s|@ARCH@|${target_arch}|g" \
        -i $1
}

prepare_grub(){
    local platform=i386-pc img='core.img' grub=$2/boot/grub efi=$2/efi/boot \
        data=$1/usr/share/grub lib=$1/usr/lib/grub prefix=/boot/grub

    prepare_dir ${grub}/${platform}

    cp ${data}/cfg/*.cfg ${grub}

    vars_to_boot_conf "${grub}/kernels.cfg"

    cp ${lib}/${platform}/* ${grub}/${platform}

    msg2 "Building %s ..." "${img}"

    grub-mkimage -d ${grub}/${platform} -o ${grub}/${platform}/${img} -O ${platform} -p ${prefix} biosdisk iso9660

    cat ${grub}/${platform}/cdboot.img ${grub}/${platform}/${img} > ${grub}/${platform}/eltorito.img

    case ${target_arch} in
        'i686')
            platform=i386-efi
            img=bootia32.efi
        ;;
        'x86_64')
            platform=x86_64-efi
            img=bootx64.efi
        ;;
    esac

    prepare_dir ${efi}
    prepare_dir ${grub}/${platform}

    cp ${lib}/${platform}/* ${grub}/${platform}

    msg2 "Building %s ..." "${img}"

    grub-mkimage -d ${grub}/${platform} -o ${efi}/${img} -O ${platform} -p ${prefix} iso9660

    prepare_dir ${grub}/themes
    cp -r ${data}/themes/${iso_name}-live ${grub}/themes/
    cp ${data}/unicode.pf2 ${grub}
    cp -r ${data}/{locales,tz} ${grub}

    local size=8M mnt="${mnt_dir}/efiboot" img="$2/efi.img"
    msg2 "Creating fat image of %s ..." "${size}"
    truncate -s ${size} "${img}"
    mkfs.fat -n MISO_EFI "${img}" &>/dev/null
    mkdir -p "${mnt}"
    mount_img "${img}" "${mnt}"

    prepare_dir ${mnt}/efi/boot

    msg2 "Building %s ..." "${img}"
    grub-mkimage -d ${grub}/${platform} -o ${mnt}/efi/boot/${img} -O ${platform} -p ${prefix} iso9660

    umount_img "${mnt}"
}
