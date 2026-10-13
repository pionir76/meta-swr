SUMMARY = "SmartRoute web UI (static files served by lighttpd)"
DESCRIPTION = "Static HTML/CSS/JS web UI for the SWR SmartRoute gateway, \
installed to /var/www/html. API calls go to the same origin and are proxied \
by lighttpd to the SmartRoute app on :8080 (see recipes-extended/lighttpd)."
LICENSE = "CLOSED"

# 웹 UI 소스는 별도 git 저장소(/home/dev3/project/swr_web). 다른 PC에서는
# local.conf에서 SWR_WEB_SRC_DIR을 바꿔준다. 설치 규칙(제외 목록, config.js
# API_BASE 패치)은 그 저장소의 deploy.py와 동일하게 맞춰둠.
SWR_WEB_SRC_DIR ?= "/home/dev3/project/swr_web"

inherit allarch externalsrc

EXTERNALSRC = "${SWR_WEB_SRC_DIR}"

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}/var/www/html
    cd ${S}
    find . -type f \
        -not -path './.git/*' \
        -not -path './referencs/*' \
        -not -path './webtest/*' \
        -not -path './webtest_for_help/*' \
        -not -path './docs/*' \
        -not -path '*/__pycache__/*' \
        -not -name '*.md' \
        -not -name 'deploy.py' \
        -not -name 'dev-server.py' \
        -not -name 'dev_restore.py' \
        | while read -r f; do
            install -D -m 0644 "$f" "${D}/var/www/html/$f"
        done

    # 개발 중에는 Live Server(PC)에서 기기 API를 직접 부르도록 분기되어 있는
    # API_BASE를, 기기에서는 같은 오리진(lighttpd 프록시) 상대 경로로 고정.
    sed -i 's|^const API_BASE = .*;|const API_BASE = "";|' ${D}/var/www/html/config.js
    grep -q '^const API_BASE = "";' ${D}/var/www/html/config.js || \
        bbfatal "config.js API_BASE patch failed - check swr_web/config.js format"
}

FILES:${PN} = "/var/www/html"

RDEPENDS:${PN} += "lighttpd lighttpd-module-proxy"
