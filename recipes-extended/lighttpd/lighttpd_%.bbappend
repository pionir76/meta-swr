FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# poky의 lighttpd 레시피가 이미 SRC_URI에 file://lighttpd.conf를 넣고
# ${sysconfdir}/lighttpd/lighttpd.conf로 설치하므로, FILESEXTRAPATHS로 이
# 디렉터리의 lighttpd.conf(mod_proxy /api -> 127.0.0.1:8080)가 대신 잡히게만
# 하면 된다. 웹 UI 파일 자체는 swr-web 레시피가 /var/www/html에 설치.
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
