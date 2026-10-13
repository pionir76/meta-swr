# meta-swr

SWR **SmartRoute** 게이트웨이(NXP i.MX6ULL, 헤드리스 Modbus 통신변환 디바이스)용 Yocto BSP/애플리케이션 레이어.

제품 사양과 앱 소스는 이 레이어 밖에 있다:

| 저장소 | 내용 |
|---|---|
| `/home/dev3/project/swr` | SmartRoute Qt6 앱 (`QCoreApplication`, REST API :8080, Modbus TCP :502). 사양: `docs/spec/spec.md` |
| `/home/dev3/project/swr_web` | 웹 UI 정적 파일 (lighttpd :80이 서비스, `/api`는 앱으로 프록시) |

2026-10-13에 NXP EVK 기반 구성(머신 `imx6ull14x14evk` + `imx-image-core`)에서 전용 머신/이미지로 정리했고, 같은 보드를 쓰던 다른 제품의 LCD/터치/중국어 입력 작업분은 레이어에서 뺐다(백업: `../../meta-swr-attic-20261013/`).

## 문서

| 문서 | 내용 |
|---|---|
| [`docs/hardware.md`](docs/hardware.md) | 하드웨어 사양, 실기기 실측값, DTS 반영 현황과 미확인 항목 |
| [`docs/testing-and-setup.md`](docs/testing-and-setup.md) | 빌드/플래싱 절차, 네트워크/RTC 테스트, SDK, 빌드 환경 이슈 |

## 레이어 구성

| 경로 | 역할 |
|---|---|
| `conf/machine/swr-gateway.conf` | 전용 머신. imx-base.inc 위에 전용 DTB, EVK U-Boot 포팅, 헤드리스 `MACHINE_FEATURES`(optee/wifi/bt 없음), 호스트명 `smartroute` |
| `conf/distro/fsl-imx-fb-swr.conf` | 배포판. NXP fsl-imx-fb에서 bluetooth/wifi/3g/nfc/nfs/zeroconf/pcmcia/pci/ptest/alsa/opengl 제거 — bluez/ofono/avahi/rpcbind/wpa/mesa가 이미지에서 빠짐. 기본 시간대 Asia/Seoul |
| `recipes-core/images/swr-image.bb` | 양산 이미지: systemd + swr + swr-web + lighttpd + ntpd + curl + SDMA 펌웨어/firmwared(RS485 DMA 필수) + 네트워크/rootfs 확장 + ssh. 미사용 systemd 유닛 마스킹, SDK 설정 포함 |
| `recipes-core/images/swr-image-dev.bb` | 양산 이미지 + 디버그 도구(gdb/strace/tcpdump/ethtool/minicom/i2c-tools/sqlite3/jq/htop/kernel-modules) |
| `recipes-core/swr` | SmartRoute 앱 빌드/설치 (`externalsrc`, `SWR_SRC_DIR`), `swr.service` 자동 실행, 런타임 디렉터리 |
| `recipes-core/swr-web` | 웹 UI를 `/var/www/html`에 설치 (`externalsrc`, `SWR_WEB_SRC_DIR`), `config.js` API_BASE 패치 |
| `recipes-extended/lighttpd` | `lighttpd.conf` 교체 (`mod_proxy`: `/api` → 127.0.0.1:8080), 서비스 자동 실행 |
| `recipes-core/swr-network-config` | systemd-networkd: FEC1 = field 192.168.0.150/GW, FEC2 = service 192.168.0.151 (udev ID_PATH로 매칭) |
| `recipes-core/swr-rootfs-resize` | 첫 부팅 시 rootfs를 eMMC 전체로 자동 확장 |
| `recipes-kernel/linux` | 전용 DTS `imx6ull-swr.dts` + 커널 설정(`DELTA_KERNEL_DEFCONFIG`): RTC, fbcon/VT 제거, 램디스크/loop 제거 |
| `recipes-bsp/u-boot` | EVK U-Boot의 기본 `fdt_file`을 `imx6ull-swr.dtb`로 변경 + MAC 퓨즈 빈 보드용 `CONFIG_NET_RANDOM_ETHADDR` |
| `recipes-core/udev/udev-extraconf_%.bbappend` | automount/autonet udev 규칙 제거 (부팅 시 udev 부하) |
| `recipes-support/ntp/ntp_%.bbappend` | `ntpd.service` drop-in `Restart=always` — 앱이 설정 변경 후 보내는 SIGHUP에 ntpd가 종료되므로 자동 재시작 |
| `recipes-qt/qt6/qtbase_%.bbappend` | `sql-sqlite` 드라이버 (앱의 QSqlDatabase) |
| `recipes-core/glibc/glibc-locale_%.bbappend`, `classes/swr-pseudo-openat2-fix.bbclass` | 호스트 커널 6.8 + pseudo `openat2()` 빌드 환경 워크어라운드 (보드와 무관) |
| `scripts/` | UUU 플래싱 — meta-sdr100과 같은 구조: `flash-emmc.sh`가 `*.uuu`를 deploy 디렉토리로 복사해 실행. `flash_emmc_with_bootdelay.uuu`(전체 플래싱, `env default -a`), `set_bootdelay.uuu`(환경만), `prove_emmc.uuu`(eMMC 확인) |

## 빠른 시작

```sh
cd ~/yocto-imx6ull
MACHINE=swr-gateway DISTRO=fsl-imx-fb-swr source setup-environment build-swr
bitbake swr-image          # 또는 swr-image-dev
~/yocto-imx6ull/sources/meta-swr/scripts/flash-emmc.sh
```

`build-swr/conf/local.conf`의 `MACHINE`을 `swr-gateway`, `DISTRO`를 `fsl-imx-fb-swr`로 바꿔두면 매번 환경변수로 줄 필요 없다. 앱/웹 소스 경로가 기본값(`/home/dev3/project/...`)과 다르면 `local.conf`에 `SWR_SRC_DIR`, `SWR_WEB_SRC_DIR`을 설정한다.

## 의존성

- `LAYERDEPENDS_meta-swr = "core"`, `LAYERSERIES_COMPAT_meta-swr = "walnascar"`
- 실제로 필요한 레이어: poky, meta-openembedded(oe, python, networking, filesystems), meta-freescale(+3rdparty, distro), meta-imx(bsp, sdk), meta-qt6, meta-arm(툴체인). `bblayers.conf`에 들어 있는 meta-imx-ml/v2x, meta-nxp-demo-experience, meta-nxp-connectivity, meta-clang, meta-gnome, meta-security, meta-virtualization은 이 이미지에 쓰이지 않는다.
