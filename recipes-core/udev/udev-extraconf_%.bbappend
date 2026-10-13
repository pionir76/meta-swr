# 부팅 시간 단축 (meta-sdr100 2026-10-07 실측 기준)
# automount.rules: 모든 블록 장치마다 셸 스크립트(mount.sh)를 실행한다. 단일 코어
#   528MHz에서 udev 처리를 크게 늦췄다. 이 보드는 SD 슬롯이 없고 eMMC는 fstab/wic로
#   마운트되므로 불필요. (USB 메모리 자동 마운트도 같이 없어짐 - 필요해지면 전용
#   규칙을 따로 추가할 것)
# autonet.rules: 네트워크 인터페이스마다 network.sh 실행 - systemd-networkd를 쓰므로 불필요.
do_install:append() {
    rm -f ${D}${sysconfdir}/udev/rules.d/automount.rules
    rm -f ${D}${sysconfdir}/udev/rules.d/autonet.rules
}
