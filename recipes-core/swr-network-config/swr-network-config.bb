SUMMARY = "Static network configuration for the SWR SmartRoute gateway"
DESCRIPTION = "systemd-networkd .network files for the two Ethernet ports, \
matched by udev ID_PATH (FEC1 = field 192.168.0.150, FEC2 = service \
192.168.0.151) so the assignment does not depend on eth0/eth1 probe order."
LICENSE = "CLOSED"

SRC_URI = " \
    file://10-swr-field.network \
    file://20-swr-service.network \
"

PACKAGE_ARCH = "${MACHINE_ARCH}"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${sysconfdir}/systemd/network
    install -m 0644 ${UNPACKDIR}/10-swr-field.network \
        ${D}${sysconfdir}/systemd/network/10-swr-field.network
    install -m 0644 ${UNPACKDIR}/20-swr-service.network \
        ${D}${sysconfdir}/systemd/network/20-swr-service.network

    install -d ${D}${sysconfdir}/systemd/system/multi-user.target.wants
    ln -sf ${systemd_system_unitdir}/systemd-networkd.service \
        ${D}${sysconfdir}/systemd/system/multi-user.target.wants/systemd-networkd.service
}

FILES:${PN} += " \
    ${sysconfdir}/systemd/network \
    ${sysconfdir}/systemd/system/multi-user.target.wants/systemd-networkd.service \
"

RDEPENDS:${PN} += "systemd"
