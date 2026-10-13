FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# 전용 보드 DTS. EVK dtsi를 패치하던 방식(모든 EVK 변형 DTB에 영향, 보드에
# 없는 장치 노드가 그대로 남음) 대신 독립된 파일을 커널 소스 트리에 복사해
# 넣는다. Makefile 등록 없이도 kernel-devicetree.bbclass가
# KERNEL_DEVICETREE에 적힌 .dtb를 패턴 규칙으로 직접 빌드하므로 패치가
# 필요 없다. DTS를 고친 뒤에는 `bitbake virtual/kernel -c configure -f`
# 또는 그냥 이미지 재빌드로 반영된다.
SRC_URI:append = " file://imx6ull-swr.dts"
SRC_URI:append = " file://rtc-rs5c372.cfg"
SRC_URI:append = " file://no-fbcon.cfg"
SRC_URI:append = " file://fewer-block-devices.cfg"

do_configure:prepend() {
    install -m 0644 ${UNPACKDIR}/imx6ull-swr.dts \
        ${S}/arch/arm/boot/dts/nxp/imx/imx6ull-swr.dts
}

# 주의: linux-imx_6.12.bb가 do_kernel_configme 직후 do_copy_defconfig
# 태스크로 .config를 arch/arm/configs/imx_v7_defconfig로 통째로 덮어써서,
# 표준 kernel-yocto SRC_URI .cfg fragment 병합 결과를 지워버린다(레시피
# 자체 주석에 "This task effectively disables kernel config fragments"라고
# 명시되어 있음 - 실기기에서 CONFIG_RTC_DRV_RS5C372가 반영 안 되는 걸로
# 실제 확인함). 대신 do_copy_defconfig 다음에 도는 do_merge_delta_config가
# DELTA_KERNEL_DEFCONFIG에 나열된 파일들을 ${UNPACKDIR}에서 찾아 병합하므로
# 이 메커니즘을 써야 실제로 반영된다.
DELTA_KERNEL_DEFCONFIG += "rtc-rs5c372.cfg"
# 디스플레이 없음: fbcon/부팅 로고/VT 제거 (부팅 시 udev 장치 수 감소) - 파일 안 주석 참고
DELTA_KERNEL_DEFCONFIG += "no-fbcon.cfg"
# 램디스크/loop 미리 생성 안 함 (부팅 시 udev 부하 감소) - 파일 안 주석 참고
DELTA_KERNEL_DEFCONFIG += "fewer-block-devices.cfg"
