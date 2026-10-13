SUMMARY = "SWR SmartRoute gateway image (development)"
DESCRIPTION = "swr-image plus on-target debugging/diagnostic tools. Same root \
password and services as production so deploy/redeploy scripts work unchanged."
LICENSE = "MIT"

require swr-image.bb

# tools-debug: gdb, strace 등
IMAGE_FEATURES += "tools-debug"

IMAGE_INSTALL += " \
    kernel-modules \
    tcpdump \
    ethtool \
    net-tools \
    minicom \
    i2c-tools \
    sqlite3 \
    util-linux \
"

# kernel-modules를 통째로 넣으면 udev가 입력장치(snvs 전원키) modalias로 evbug
# (모든 입력 이벤트를 커널 로그에 찍는 디버그 모듈)를 자동 로드한다(2026-10-13
# 실기기 확인). 양산 이미지에는 모듈 자체가 없으므로 개발 이미지에서만 차단.
blacklist_debug_modules() {
    install -d ${IMAGE_ROOTFS}${sysconfdir}/modprobe.d
    echo "blacklist evbug" > ${IMAGE_ROOTFS}${sysconfdir}/modprobe.d/swr-dev-blacklist.conf
}
ROOTFS_POSTPROCESS_COMMAND += "blacklist_debug_modules"
