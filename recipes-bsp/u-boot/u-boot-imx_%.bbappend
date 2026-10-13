FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# SWR 보드는 EVK U-Boot 포팅(mx6ull_14x14_evk)을 그대로 쓰되 전용 DTB
# (imx6ull-swr.dtb)로 부팅한다. EVK U-Boot의 findfdt는 fdt_file이
# "undefined"일 때 보드 ID로 EVK DTB를 고르므로, 컴파일 기본값을 전용 DTB로
# 바꿔 환경변수가 지워진 상태에서도 올바른 DTB가 선택되게 한다.
# (uuu 플래싱 스크립트도 같은 값을 saveenv로 저장한다 - scripts/ 참고.)
SRC_URI:append:swr-gateway = " file://0001-mx6ullevk-default-fdt_file-imx6ull-swr.patch"

# MAC 퓨즈가 빈 보드에서의 U-Boot 크래시 방지 - files/net-random-ethaddr.cfg 참고.
# 주의: 무작위 MAC은 U-Boot 환경변수 ethaddr에 들어간다. 그 상태에서 saveenv 하면
# eMMC 환경에 남아, MAC 퓨즈를 기록한 뒤에도 저장된 무작위 MAC을 쓰게 된다.
# 플래싱 스크립트는 env default -a로 지운 뒤 저장하므로 안전하고, 양산 MAC 기록
# 절차에서도 saveenv 전에 ethaddr를 지워야 한다.
SRC_URI:append = " file://net-random-ethaddr.cfg"
