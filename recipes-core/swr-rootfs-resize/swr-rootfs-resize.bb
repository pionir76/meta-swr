SUMMARY = "Grow root partition/filesystem to fill available eMMC storage on first boot"
LICENSE = "CLOSED"

SRC_URI = " \
    file://swr-rootfs-resize.sh \
    file://swr-rootfs-resize.service \
"

PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit systemd

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${UNPACKDIR}/swr-rootfs-resize.sh ${D}${sbindir}/swr-rootfs-resize.sh

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${UNPACKDIR}/swr-rootfs-resize.service \
        ${D}${systemd_unitdir}/system/swr-rootfs-resize.service
}

FILES:${PN} += " \
    ${sbindir}/swr-rootfs-resize.sh \
    ${systemd_unitdir}/system/swr-rootfs-resize.service \
"

SYSTEMD_SERVICE:${PN} = "swr-rootfs-resize.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += " \
    parted \
    e2fsprogs-resize2fs \
    util-linux-lsblk \
    util-linux-findmnt \
"
