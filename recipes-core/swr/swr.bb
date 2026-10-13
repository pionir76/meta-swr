SUMMARY = "SmartRoute gateway application"
DESCRIPTION = "SWR SmartRoute: Modbus RTU/ASCII/TCP + PCLink data collection, \
SQLite register/device DB, REST API (QHttpServer :8080), Modbus TCP server \
(:502), trend recording. Qt6 QCoreApplication, no GUI."
LICENSE = "CLOSED"

# 앱 소스는 별도 git 저장소(/home/dev3/project/swr)에 있고 이 레이어에는
# 들어있지 않다. externalsrc로 그 디렉터리를 직접 빌드하므로, 다른 PC에서
# 빌드할 때는 local.conf에서 경로를 바꿔준다:
#   SWR_SRC_DIR = "/path/to/swr"
# (externalsrc 특성상 이 레시피는 sstate 캐시를 쓰지 않고 소스가 바뀌면
# 매번 다시 빌드된다 - 의도된 동작.)
SWR_SRC_DIR ?= "/home/dev3/project/swr"

inherit cmake pkgconfig qt6-cmake systemd externalsrc

EXTERNALSRC = "${SWR_SRC_DIR}"
EXTERNALSRC_BUILD = "${WORKDIR}/build"

SRC_URI = " \
    file://swr.service \
    file://swr-tmpfiles.conf \
"

DEPENDS = "qtbase qthttpserver qtserialport qtserialbus"

# CMakeLists.txt의 SR_* 캐시 변수는 기본값(/etc/swr/config.json,
# /var/lib/swr/smartroute.db, /trend_data, API 8080)을 그대로 쓴다.
# 바꿔야 하면 여기서 -DSR_...=... 로 넘기면 됨.
EXTRA_OECMAKE += "-DSR_LOG_PRINT=0"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/swr.service ${D}${systemd_system_unitdir}/swr.service

    # 앱이 쓰는 디렉터리. config.json은 없으면 앱이 첫 실행 때 공장 초기값으로
    # 직접 생성하므로(main.cpp factoryReset) 여기서 배포하지 않는다.
    install -d ${D}${sysconfdir}/swr
    install -d ${D}${localstatedir}/lib/swr
    install -d ${D}/trend_data

    # /var/log는 기본적으로 tmpfs(volatile)라 패키지로 디렉터리를 못 만든다 -
    # 부팅 때마다 systemd-tmpfiles가 /var/log/swr를 만들어주게 한다.
    install -d ${D}${nonarch_libdir}/tmpfiles.d
    install -m 0644 ${UNPACKDIR}/swr-tmpfiles.conf ${D}${nonarch_libdir}/tmpfiles.d/swr.conf
}

SYSTEMD_SERVICE:${PN} = "swr.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

# qtbase-plugins: Qt SQL의 sqlite 드라이버(plugins/sqldrivers)는 dlopen이라
#   shlibs 자동 의존성으로 안 잡힘 - 명시 필요.
# iproute2: 앱이 네트워크 설정 변경 시 `ip` 명령을 실행함(NetworkConfigurator).
RDEPENDS:${PN} += "qtbase-plugins iproute2"

FILES:${PN} += " \
    ${systemd_system_unitdir}/swr.service \
    ${sysconfdir}/swr \
    ${localstatedir}/lib/swr \
    /trend_data \
    ${nonarch_libdir}/tmpfiles.d/swr.conf \
"
