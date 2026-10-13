#!/bin/sh
# 최신 빌드 이미지를 압축 해제하고 UUU로 eMMC에 플래싱하는 걸 한 번에 처리.
# (meta-sdr100/scripts/flash-emmc.sh와 같은 구조 - 레이어마다 플래싱 방법이 달라
#  혼동되지 않도록 맞춤)
#
# 사용법:
#   ./flash-emmc.sh                         # build-swr에 빌드된 최신 swr-image*(dev 포함) 플래싱
#   IMAGE=swr-image ./flash-emmc.sh         # 이미지 명시 (swr-image | swr-image-dev)
#   BUILD_DIR=/path/to/build ./flash-emmc.sh
#
# 사전 조건:
#   - bitbake <IMAGE> 빌드가 이미 완료되어 있을 것 (MACHINE=swr-gateway)
#   - 보드가 Serial Download Mode로 리셋되어 USB로 연결되어 있을 것
#     (SDP 모드가 아니면 uuu가 기기를 못 찾고 대기/타임아웃됨)
#
# UUU 스크립트(*.uuu)는 이 디렉토리(meta-swr/scripts/)에 보관하며, 실행 시
# deploy 디렉토리로 복사해서 사용한다(이미지 파일명 @WIC@만 치환). deploy
# 디렉토리는 빌드 산출물 위치라 빌드 디렉토리를 새로 만들면 비어 있기 때문.

set -e

# $HOME 대신 이 스크립트 자신의 위치를 기준으로 경로를 계산한다.
# sudo ./flash-emmc.sh처럼 실행하면 $HOME이 /root로 바뀌어서 잘못된 경로를
# 가리키는 문제가 있었음 - 스크립트는 항상
# <yocto-imx6ull>/sources/meta-swr/scripts/ 밑에 있으므로 sudo 여부와
# 무관하게 정확한 경로가 나온다.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
YOCTO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

MACHINE="${MACHINE:-swr-gateway}"
BUILD_DIR="${BUILD_DIR:-$YOCTO_ROOT/build-swr}"
DEPLOY_DIR="${DEPLOY_DIR:-$BUILD_DIR/tmp/deploy/images/$MACHINE}"
UBOOT="u-boot.imx"
UUU_SCRIPT="flash_emmc_with_bootdelay.uuu"

if [ ! -d "$DEPLOY_DIR" ]; then
    echo "ERROR: deploy 디렉토리 없음: $DEPLOY_DIR" >&2
    echo "       먼저 '$BUILD_DIR'에서 'bitbake swr-image-dev' 또는 'bitbake swr-image'를 실행할 것" >&2
    exit 1
fi

cd "$DEPLOY_DIR"

# IMAGE를 지정하지 않으면 deploy 디렉토리에 빌드되어 있는 swr-image*.wic.zst 중
# 가장 최근 것을 쓴다(swr-image / swr-image-dev 둘 다 있으면 최근 빌드 우선).
# 어느 이미지를 플래싱하는지 아래 로그에 찍히므로 확인할 것.
if [ -z "$IMAGE" ]; then
    LATEST="$(ls -t swr-image*-"$MACHINE".rootfs.wic.zst 2>/dev/null | head -1)"
    if [ -z "$LATEST" ]; then
        echo "ERROR: $DEPLOY_DIR 에 swr-image*.wic.zst 없음 - 먼저 'bitbake swr-image-dev' 또는 'bitbake swr-image'를 실행할 것" >&2
        exit 1
    fi
    IMAGE="${LATEST%-"$MACHINE".rootfs.wic.zst}"
fi
WIC="$IMAGE-$MACHINE.rootfs.wic"
WIC_ZST="$WIC.zst"
echo "==> 이미지: $IMAGE ($DEPLOY_DIR)"

for f in "$WIC_ZST" "$UBOOT"; do
    if [ ! -e "$f" ]; then
        echo "ERROR: $DEPLOY_DIR/$f 없음 - 먼저 'bitbake $IMAGE'를 실행할 것" >&2
        exit 1
    fi
done

echo "==> UUU 스크립트 복사: $SCRIPT_DIR/*.uuu -> $DEPLOY_DIR (이미지명: $WIC)"
for u in "$SCRIPT_DIR"/*.uuu; do
    sed "s|@WIC@|$WIC|g" "$u" > "./$(basename "$u")"
done

echo "==> 최신 이미지 압축 해제: $WIC_ZST"
zstd -d -f "$WIC_ZST"

echo "==> USB로 연결된 보드 확인 (Serial Download Mode 상태여야 함)"
uuu -lsusb

echo "==> eMMC 플래싱 시작 ($UUU_SCRIPT)"
sudo uuu "./$UUU_SCRIPT"

echo "==> 완료 - 보드를 eMMC 부팅 모드로 바꾸고 재시작할 것"
