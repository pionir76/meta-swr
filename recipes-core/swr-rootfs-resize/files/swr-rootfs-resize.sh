#!/bin/sh
# Grow the root partition and its ext4 filesystem to fill the remaining
# space on the eMMC. The .wic image only sizes the root partition to fit
# the rootfs content at build time, so on an 8GB eMMC most of the device
# is left unpartitioned after flashing. This is safe to run on every boot:
# it exits immediately once the partition already covers the whole disk.

set -e

FLAG=/var/lib/swr-rootfs-resized
[ -e "$FLAG" ] && exit 0

ROOT_SRC=$(findmnt -n -o SOURCE /)
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SRC")
ROOT_DISK="/dev/${ROOT_DISK}"
ROOT_PART_NUM=$(echo "$ROOT_SRC" | grep -o '[0-9]*$')

if [ -z "$ROOT_DISK" ] || [ -z "$ROOT_PART_NUM" ]; then
    echo "swr-rootfs-resize: could not determine root disk/partition, skipping" >&2
    exit 0
fi

# parted -m 출력의 디스크 요약 줄은 "BYT;" 다음 줄, "/dev/xxx:<size>s:..."
# 형태로 항상 두 번째 줄에 나온다. "tail -1"로 잡으면 파티션이 여러 개일 때
# 마지막 파티션 줄을 잘못 집어서(디스크 크기가 아니라 그 파티션의 시작
# 섹터를 디스크 크기로 착각) "이미 꽉 찼다"고 오판하는 버그가 있었음
# (실기기에서 실제로 재현됨 - 2파티션 구성에서 DISK_END가 파티션2의 시작
# 섹터로 잘못 계산됨). 디스크 경로로 시작하는 줄을 명시적으로 찾는다.
DISK_END=$(parted -s -m "$ROOT_DISK" unit s print | grep "^${ROOT_DISK}:" | cut -d: -f2 | tr -d 's')
PART_END=$(parted -s -m "$ROOT_DISK" unit s print | grep "^${ROOT_PART_NUM}:" | cut -d: -f3 | tr -d 's')

if [ -z "$DISK_END" ] || [ -z "$PART_END" ]; then
    echo "swr-rootfs-resize: could not read partition table, skipping" >&2
    exit 0
fi

# Already using (close to) the full disk - nothing to grow.
if [ "$PART_END" -ge "$((DISK_END - 2048))" ]; then
    mkdir -p "$(dirname "$FLAG")"
    touch "$FLAG"
    exit 0
fi

echo "swr-rootfs-resize: growing ${ROOT_DISK} partition ${ROOT_PART_NUM} to 100%"
parted -s "$ROOT_DISK" resizepart "$ROOT_PART_NUM" 100%
partprobe "$ROOT_DISK" 2>/dev/null || true
udevadm settle 2>/dev/null || true

echo "swr-rootfs-resize: growing ext4 filesystem on ${ROOT_SRC}"
resize2fs "$ROOT_SRC"

mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
