SUMMARY = "SWR SmartRoute gateway image (production)"
DESCRIPTION = "Headless image for the SWR SmartRoute Modbus gateway: systemd, \
SmartRoute Qt6 application, lighttpd web UI, static network config, RTC/eMMC \
support. No display stack, no NXP demo/debug tooling. Development extras \
(tcpdump, gdb, kernel modules, ...) live in swr-image-dev.bb."
LICENSE = "MIT"

inherit core-image extrausers

# core-image 기본값(packagegroup-core-boot + CORE_IMAGE_EXTRA_INSTALL)에 더함.
# Qt 라이브러리(qtbase/qtserialport/qtserialbus/qthttpserver/qtwebsockets)와
# sqlite, parted 등은 swr / swr-rootfs-resize 패키지의 RDEPENDS로 자동으로
# 따라오므로 여기 적지 않는다 - 실제 필요 여부의 기준은 앱 쪽에 둔다.
# ntp(ntpd): SmartRoute 앱이 config.json의 ntpServer를 /etc/ntp.conf에 쓰고
#   ntpd에 적용하는 구조(main.cpp applyNtpConfig)라 ntpd가 있어야 동작한다.
#   systemd-timesyncd와 둘 다 돌면 시간이 되돌아가는 문제가 있어(2026-09 실기기)
#   timesyncd는 아래에서 마스킹한다.
# systemd-analyze: 부팅 시간 분석용(64KB). tools-profile 없이도 쓸 수 있게 따로 넣음.
# curl: 현장 API 테스트/배포 스크립트용(펌웨어팀 요청 2026-10-13). libcurl은 이미
#   의존성으로 들어 있어 CLI 바이너리(약 300KB)만 추가됨.
# kernel-module-imx-rngc/rng-core: 하드웨어 난수(/dev/hwrng) - 모듈 전체 대신 이것만.
# firmware-imx-sdma-imx6q + firmwared: **필수**. SDMA 펌웨어(imx/sdma/sdma-imx6q.bin)가
#   없으면 i.MX UART 드라이버의 DMA 준비가 실패해 "We cannot prepare for the TX slave
#   dma!"가 반복되고 RS485(ttymxc1) Modbus RTU 통신이 전부 타임아웃된다(2026-10-13
#   실기기 - imx-image-core에서 전용 이미지로 바꾸며 빠뜨렸던 항목). firmwared는 커널
#   request_firmware의 sysfs 폴백을 처리하는 NXP 데몬 - imx-image-core/meta-sdr100과
#   동일하게 유지(마스킹 금지).
IMAGE_INSTALL += " \
    swr \
    swr-web \
    swr-network-config \
    swr-rootfs-resize \
    ntp \
    tzdata \
    systemd-analyze \
    curl \
    firmware-imx-sdma-imx6q \
    firmwared \
    kernel-module-imx-rngc \
    kernel-module-rng-core \
"

# --------------------------------------------------
# 부팅 시간 단축 (meta-sdr100 2026-10-07 실기기 검증 항목 중 헤드리스 보드에 해당하는 것)
# --------------------------------------------------
# 이 보드에서 쓰지 않는 서비스 마스킹 (/etc/systemd/system/<unit> -> /dev/null).
# bluetooth/ofono/neard/avahi/rpcbind/wpa 계열은 배포판(fsl-imx-fb-swr) 기능 정리로
# 패키지 자체가 빠지므로 여기 없다. 남는 것 중:
#   busybox-syslog/klogd: journald로 충분.
#   systemd-networkd-wait-online: swr.service는 network.target만 기다리면 됨.
#   systemd-vconsole-setup: VT 없음(no-fbcon.cfg).
#   systemd-userdbd: 동적 사용자 조회 데몬(+작업 프로세스 3개, 약 12MB). /etc/passwd만 사용.
#   systemd-timesyncd: 앱이 ntpd를 쓰므로 중복(위 참고).
#   firmwared는 SDMA 펌웨어 로드라 마스킹 금지.
MASKED_SYSTEMD_UNITS = " \
    busybox-syslog.service busybox-klogd.service \
    systemd-networkd-wait-online.service \
    systemd-vconsole-setup.service \
    systemd-userdbd.service systemd-userdbd.socket \
    systemd-timesyncd.service \
"

mask_unused_systemd_units() {
    install -d ${IMAGE_ROOTFS}${sysconfdir}/systemd/system
    for u in ${MASKED_SYSTEMD_UNITS}; do
        ln -sf /dev/null ${IMAGE_ROOTFS}${sysconfdir}/systemd/system/$u
    done
}
ROOTFS_POSTPROCESS_COMMAND += "mask_unused_systemd_units"

# ssh-server-openssh: 현장 유지보수/배포(deploy.sh)에 필요.
# package-management: dpkg -i로 개별 패키지(swr 등)만 갱신할 수 있게 함.
# allow-root-login: deploy 스크립트가 root로 접속함.
IMAGE_FEATURES += " \
    ssh-server-openssh \
    package-management \
    allow-root-login \
"

# root 비밀번호(현재 "root"). 양산 출하 전에 반드시 바꿀 것 -
#   openssl passwd -6 '<새 비밀번호>'  로 해시 생성 후 교체.
ROOT_PASSWORD_HASH = "\$6\$8krzpZZrH0JTZe5i\$vbRkLYKiBZx11mOWbbU7VMYYuKQxJd63TxSD4jOXNUwGJcg3PWmgaxt7JTqRb4u7S1rYcfosTzYvZqCzM417s0"
EXTRA_USERS_PARAMS:append = " usermod -p '${ROOT_PASSWORD_HASH}' root;"

# --------------------------------------------------
# SDK (bitbake swr-image -c populate_sdk)
# --------------------------------------------------
# SmartRoute 앱을 PC에서 크로스 컴파일하기 위한 타겟 -dev 패키지와,
# Ubuntu 호스트용 Qt6 빌드 도구(moc/uic/rcc, Qt6HostInfoConfig.cmake 등).
SDKIMAGE_FEATURES:append = " dev-pkgs tools-sdk"

TOOLCHAIN_TARGET_TASK:append = " \
    qtbase-dev \
    qtserialport-dev \
    qtserialbus-dev \
    qthttpserver-dev \
    qtwebsockets-dev \
    libsqlite3-dev \
"

TOOLCHAIN_HOST_TASK:append = " \
    nativesdk-packagegroup-qt6-toolchain-host \
    nativesdk-packagegroup-qt6-toolchain-host-essentials \
    nativesdk-cmake \
    nativesdk-ninja \
"
