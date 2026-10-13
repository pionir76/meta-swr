FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# ntpd.service drop-in: 앱이 보내는 SIGHUP으로 ntpd가 죽어도 자동 재시작
# (files/10-swr-restart.conf 주석 참고)
SRC_URI:append = " file://10-swr-restart.conf"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}/ntpd.service.d
    install -m 0644 ${UNPACKDIR}/10-swr-restart.conf \
        ${D}${systemd_system_unitdir}/ntpd.service.d/10-swr-restart.conf
}

FILES:${PN} += "${systemd_system_unitdir}/ntpd.service.d"
