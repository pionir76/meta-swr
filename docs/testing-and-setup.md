# 테스트 및 설정 절차

빌드/플래싱, 네트워크/RTC 확인, SDK, 빌드 환경 이슈를 정리한다. 하드웨어 사양과 DTS는 `docs/hardware.md` 참고.

## 빌드 확인 현황

- 2026-10-13: EVK 기반 구성에서 전용 머신 `swr-gateway` + 배포판 `fsl-imx-fb-swr` + `swr-image`로 전환. **실기기 검증 완료**(아래). 양산 이미지 `swr-image`는 아직 빌드/검증 전. `bitbake swr-image-dev` 첫 전체 빌드 **성공**(4810 태스크, 에러 0, 경고 86개는 전부 알려진 sstate 복원 실패 → 실제 태스크 대체). 산출물: 패키지 653개(구 1166), `wic.zst` 101MB(구 145MB), U-Boot 기본 `fdt_file=imx6ull-swr.dtb`, boot 파티션에 `imx6ull-swr.dtb` + 복구용 EVK DTB.
- 2026-10-13 **실기기 검증(swr-image-dev, 첫 부팅)**: 모델 `SWR SmartRoute Gateway (i.MX6ULL)`, 호스트명 `smartroute`, bootargs에 `quiet` 반영. **부팅 25.9초**(커널 1.5 + userspace 24.4, 구 구성 2분 8초). 실패 유닛 0. swr/lighttpd/networkd active, lighttpd `/` 200, `/api/login` 프록시 401(앱 응답), eth1(FEC1) 192.168.0.150, rtc0 = rs5c372(hctosys), VT/램디스크/fbcon 제거 확인(`/dev/tty*` 3개), rootfs 자동 확장 7.0G, /usr 224MB(구 710MB), 패키지 653개, 사용 메모리 29MB/497MB. **2번째 부팅 18.6초**(커널 1.5 + userspace 17.1, multi-user 16.7초 — 첫 부팅 전용 rootfs 확장/ldconfig/postinsts가 빠짐). 남은 병목: `dev-mmcblk1p2.device` 12.3초(eMMC 인식), udev 트리거 7.2초, resolved 3.5초. 실패 유닛 0, ntpd active(앱 HUP 후 자동 재시작 1회), evbug 없음, 메모리 사용 30MB.
- 발견/조치: (1) **ntpd가 앱 기동 직후 죽음** — 앱의 `kill -HUP ntpd`에 ntpd가 종료함("exiting on signal 1"). `recipes-support/ntp` drop-in(`Restart=always`)으로 자동 재시작하게 함(실기기에서 HUP 후 1초 내 재시작 확인). (2) 개발 이미지의 `kernel-modules` 때문에 udev가 입력장치 modalias로 `evbug`(입력 이벤트를 커널 로그에 찍는 디버그 모듈)를 로드 — `swr-image-dev`에서 modprobe blacklist. (3) 시제품 FEC2 PHY 부재 지연은 40초→약 14초(부팅을 막지는 않음). (4) **`reboot`가 "Reboot failed -- System halted"로 멈춤** — OP-TEE 제거로 커널이 wdog1로 재시작하는데 EVK의 `fsl,ext-reset-output`이 이 보드에 없는 외부 리셋 핀만 구동. DTS에서 속성 제거(`docs/hardware.md`), 같은 김에 RTC `aliases`(rtc0 = 외부 RTC) 추가. **재빌드/재플래싱 후 검증 완료(2026-10-13)**: `reboot` 발행 02:50:30 → 새 부팅 02:50:59 → SSH 복귀 02:51:14(약 45초, 워치독 128초 대기 없음). 재부팅 후 18.4초 부팅, 실패 유닛 0, rtc0 별칭 = rs5c372, swr/lighttpd/ntpd active.
- 2026-09-02 (구 구성, `imx-image-core`/`imx6ull14x14evk`): 빌드, 플래싱, rootfs 확장, 외부 RTC 배터리 백업 실기기 검증 완료.

## 전환 후 처음 할 일

1. `build-swr/conf/local.conf`: `MACHINE ??= 'swr-gateway'`, `DISTRO ?= 'fsl-imx-fb-swr'` 로 변경. `PACKAGECONFIG:append:pn-qtbase = " sql-sqlite"` 줄은 레이어(`recipes-qt/qt6/qtbase_%.bbappend`)로 옮겼으므로 지워도 된다. (또는 매번 `MACHINE=swr-gateway DISTRO=fsl-imx-fb-swr source setup-environment build-swr`)
2. `bitbake swr-image-dev` (개발) 또는 `bitbake swr-image` (양산). 머신/배포판이 바뀌어 사실상 전체 재빌드다(meta-sdr100 같은 조건에서 약 22분).
3. `scripts/flash-emmc.sh` 로 플래싱. `IMAGE`를 안 주면 deploy 디렉토리의 최신 `swr-image*`(dev 포함)를 자동 선택하고 시작 로그에 표시한다. 명시하려면 `IMAGE=swr-image ./flash-emmc.sh`.
4. 부팅 후 확인:
   ```sh
   ssh root@192.168.0.150            # 비밀번호 root (키 등록되어 있으면 생략)
   cat /proc/device-tree/model       # "SWR SmartRoute Gateway (i.MX6ULL)"
   hostname                          # smartroute
   systemctl is-active swr lighttpd systemd-networkd
   systemd-analyze time              # 목표: multi-user 25초 안쪽 (구 구성 2분 8초, meta-sdr100 동일 조치 후 20~24초)
   systemctl --failed                # 실패 유닛 없어야 함
   systemctl is-active ntpd; systemctl is-enabled systemd-timesyncd   # ntpd active / timesyncd masked
   ip -br addr                       # eth1(FEC1) 192.168.0.150 - 시제품 기준
   curl -s localhost/api/version     # lighttpd -> 앱 프록시 동작 확인 (엔드포인트는 api-spec.md 참고)
   ```
5. 부팅이 안 되면 시리얼 콘솔에서 U-Boot 프롬프트로 들어가 `setenv fdt_file imx6ull-14x14-evk.dtb; saveenv; boot` 로 순정 EVK DTB로 부팅해 원인을 좁힌다(`docs/hardware.md`).

## 1. UUU로 eMMC 플래싱

보드를 Serial Download Mode로 리셋한 뒤:

```sh
~/yocto-imx6ull/sources/meta-swr/scripts/flash-emmc.sh
```

스크립트가 `tmp/deploy/images/swr-gateway/`에서 `.wic.zst`를 풀고, 레이어의 `scripts/flash_emmc.uuu` 템플릿에 이미지 파일명을 넣은 복사본으로 `uuu`를 실행한다. U-Boot 환경에 `fdt_file=imx6ull-swr.dtb`, `bootdelay=2`, 시리얼 콘솔을 `saveenv`한다.

파일이 없다는 에러(`fail open file`)는 deploy 디렉터리에 `.wic`/`u-boot.imx`가 없을 때 난다 — 먼저 `bitbake swr-image`가 끝났는지 확인.

## 2. 네트워크

- `recipes-core/swr-network-config`가 systemd-networkd 설정을 설치한다. 이름(eth0/eth1)이 아니라 udev `ID_PATH`로 포트를 고정한다:

  | 파일 | 매칭 | 주소 | 용도 |
  |---|---|---|---|
  | `10-swr-field.network` | `platform-2188000.ethernet` (FEC1) | 192.168.0.150/24, GW 192.168.0.1 | 현장/유지보수 (시제품에서 동작하는 포트) |
  | `20-swr-service.network` | `platform-20b4000.ethernet` (FEC2) | 192.168.0.151/24 | 서비스 포트 (양산 보드 PHY 실장 후) |

- 앱의 `config.json`(`network.interfaces`)에도 eth0/eth1 이름과 주소가 들어 있지만, 현재 앱은 부팅 시 네트워크를 적용하지 않는다(`main.cpp`의 적용 루프가 주석 처리됨). 웹 UI에서 네트워크를 바꾸면 `ip addr`로 즉시 적용만 하고 영속화하지 않으므로, 영속 설정은 위 `.network` 파일이 기준이다. 앱 쪽을 영속화하려면 `.network` 파일을 쓰고 `networkctl reload`하는 방식으로 맞추는 것이 다음 과제.
- 확인:
  ```sh
  networkctl status
  udevadm info /sys/class/net/eth1 | grep ID_PATH
  ```

## 3. 커널 DTS 수정

DTS는 패치가 아니라 파일 자체(`recipes-kernel/linux/files/imx6ull-swr.dts`)를 수정한다. 커널 bbappend가 `do_configure` 전에 커널 소스 트리로 복사한다.

```sh
# 빌드 없이 문법만 확인 (기존 빌드 트리의 dtc 사용)
KS=~/yocto-imx6ull/build-swr/tmp/work-shared/swr-gateway/kernel-source
DTC=$(ls ~/yocto-imx6ull/build-swr/tmp/work/swr-gateway-poky-linux-gnueabi/linux-imx/*/build/scripts/dtc/dtc | head -1)
cpp -nostdinc -I$KS/include -I$KS/arch/arm/boot/dts -I$KS/arch/arm/boot/dts/nxp/imx -undef -D__DTS__ -x assembler-with-cpp \
    ~/yocto-imx6ull/sources/meta-swr/recipes-kernel/linux/files/imx6ull-swr.dts -o /tmp/swr.pp.dts
$DTC -I dts -O dtb -o /tmp/swr.dtb -i $KS/arch/arm/boot/dts/nxp/imx /tmp/swr.pp.dts

# 반영
bitbake virtual/kernel -c configure -f && bitbake swr-image
```

**커널 config**: `linux-imx_6.12.bb`는 `do_copy_defconfig`가 `.config`를 `imx_v7_defconfig`로 덮어써서 표준 SRC_URI `.cfg` fragment가 무효다. 반드시 `DELTA_KERNEL_DEFCONFIG`를 쓸 것. 현재 fragment: `rtc-rs5c372.cfg`(외부 RTC), `no-fbcon.cfg`(fbcon/로고/VT 제거), `fewer-block-devices.cfg`(램디스크/loop 제거). 반영 여부는 기기에서 `zcat /proc/config.gz | grep -E "RS5C372|CONFIG_VT=|BLK_DEV_RAM"`로 확인.

## 4. 외부 RTC 배터리 백업 테스트

목적: 주 전원이 완전히 끊긴 상태에서도 코인셀로 시간이 유지되는지 확인.

```sh
cat /sys/class/rtc/rtc0/name; cat /sys/class/rtc/rtc1/name   # rs5c372a 쪽 번호 확인
systemctl stop ntpd                                           # NTP가 되돌리지 않게
date -s "2026-10-13 17:05:00"
hwclock -w -f /dev/rtcN
hwclock -r -f /dev/rtcN
```

전원을 완전히 차단했다가 재연결 후:

```sh
dmesg | grep -i "setting system clock"
hwclock -r -f /dev/rtcN
```

설정한 시각 + 꺼져 있던 시간이 나오면 정상. 1970년 근처면 코인셀 미장착/방전/배선 문제. 끝나면 `systemctl start ntpd`.

**시간 동기화 구조**: 앱(`main.cpp applyNtpConfig`)이 `config.json`의 `ntpServer`를 `/etc/ntp.conf`에 쓰고 ntpd에 HUP을 보내는 구조라 이미지에 `ntp`(ntpd)를 넣고 `systemd-timesyncd`는 마스킹했다(둘 다 돌면 시간이 되돌아감). 참고: ntpd는 SIGHUP으로 설정을 다시 읽지 않으므로(로그 파일만 재오픈) 서버를 바꾼 뒤에는 `systemctl restart ntpd`가 필요하다 — 앱 쪽에서 HUP 대신 restart로 바꾸는 것을 권장.

2026-09-02 실기기 검증 완료(구 구성, 하드웨어 동일).

## 5. 크로스 컴파일 SDK

```sh
bitbake swr-image -c populate_sdk
# 설치 후
source /opt/<sdk>/environment-setup-cortexa7t2hf-neon-poky-linux-gnueabi
```

`swr-image.bb`가 Qt6(base/serialport/serialbus/httpserver/websockets)-dev, sqlite-dev와 호스트용 Qt 빌드 도구를 SDK에 넣는다. 앱 저장소의 `scripts/deploy.sh`/`redeploy.sh`가 쓰는 `/opt/imx6ull-core-sdk/...`는 2026-05-07 스냅샷이라 새 SDK로 교체 권장.

앱을 이미지에 넣지 않고 빠르게 바꿔 끼울 때는 기존대로 `redeploy.sh`(scp + `systemctl restart swr`)를 써도 된다. `swr` 패키지는 `externalsrc`라 `bitbake swr -c package_write_deb` 후 `.deb`를 `dpkg -i`하는 방법도 있다.

## 빌드 환경 이슈 (하드웨어와 무관)

- **pseudo `openat2()` 미인터셉트**: 호스트 커널 6.8 + pseudo가 `openat2()`를 가로채지 못해 `do_package`/`dpkg-deb`의 tar 파이프가 실패. `classes/swr-pseudo-openat2-fix.bbclass`를 `layer.conf`의 `USER_CLASSES:append`로 전역 적용(`INHERIT +=`는 `defaultsetup.conf`가 덮어써서 안 됨). `glibc-locale`은 자체 클래스 때문에 `recipes-core/glibc/glibc-locale_%.bbappend`에서 따로 우회.
- **`tar.zst` 제외**: `do_image_tar`가 `tar-replacement-native`(`ASSUME_PROVIDED`) 문제로 항상 실패. 플래싱에 안 쓰므로 머신 conf에서 `IMAGE_FSTYPES:remove`.
- **NTP 중복**: `ntp`(ntpd)를 넣으면 기본 `systemd-timesyncd`와 둘 다 떠서 시간이 되돌아감. timesyncd만 사용.
- **rootfs 1GB 문제**: `.wks`가 rootfs를 내용물 크기로만 잡음 → `swr-rootfs-resize`가 첫 부팅에 확장.
- **`PACKAGECONFIG:append:pn-X`는 X 레시피 파일 안에서만 유효**: 다른 레시피(이미지 등)의 bbappend에 넣으면 조용히 무시됨.
- **부팅 2분 8초(구 구성)**: psplash 타임아웃 90초, FEC2 PHY 없음 40초, avahi/ofono/sshdgenkeys 약 30초. 새 구성은 psplash/avahi/ofono가 아예 없고, FEC2 지연은 시제품에서만 남는다.

## 부팅 시간 단축 조치 (2026-10-13, meta-sdr100 2026-10-07 실기기 검증 항목 반영)

meta-sdr100에서 같은 SoC/EVK 기반으로 multi-user 42.7초 → 20~24초까지 줄인 조치 중 헤드리스 보드에 해당하는 것을 그대로 가져왔다(LCD/psplash 관련은 제외). 전부 새 구성에 들어 있으며 **실기기 측정은 아직 안 됨**.

| 조치 | 위치 | sdr100 실측 효과 |
|---|---|---|
| OP-TEE/wifi/bt 머신 기능 제거 → U-Boot `tee=no`, tee-supplicant 없음, RAM 32MB 회수 | `conf/machine/swr-gateway.conf` | sysinit 대기 약 21초 제거 |
| DISTRO_FEATURES 정리(bluetooth/wifi/3g/nfc/nfs/zeroconf/pcmcia/pci/ptest/alsa/opengl) | `conf/distro/fsl-imx-fb-swr.conf` | 패키지 811→500, rootfs 758→413MB |
| 램디스크 16개/loop 8개 미생성 | `fewer-block-devices.cfg` | udev 처리 32→15초, 블록 장치 25→4개 |
| udev automount/autonet 규칙 제거 | `recipes-core/udev` | 위와 함께 |
| fbcon/로고/VT 제거(tty0~63 등 85개 장치) | `no-fbcon.cfg` | udev 장치 395→305개 |
| `kernel-modules` 전체(301개) 대신 rngc 2개만 | 머신 conf `MACHINE_EXTRA_RRECOMMENDS=""` + 이미지 | udev 모듈 처리 감소 |
| 미사용 유닛 마스킹(busybox-syslog/klogd, networkd-wait-online, vconsole-setup, userdbd, timesyncd) | `swr-image.bb` | 프로세스/메모리 약 12MB |
| `bootdelay` 1, bootargs `quiet` | `scripts/*.uuu` | U-Boot 1초, 커널 3.7→2.0초 |
| imx-image-core 대신 core-image 기반(tools-sdk/debug/profile, packagegroup-imx-security(lvm2 udev 규칙) 없음) | `swr-image.bb` | lvm2 udev 규칙 제거 |

남는 병목(sdr100 기준): udev 트리거 약 9초, 루트 장치(eMMC) 인식 약 17초. SWR 시제품은 FEC2 PHY 부재로 networkd의 eth0 up에서 약 40초 추가 — 양산 보드에서는 사라진다.

## 빌드 에러 대응 조치 점검 (2026-10-13)

meta-sdr100(2026-10-08 최신 빌드, 에러 0)과 대조해 각 워크어라운드가 아직 필요한지 확인한 결과:

| 조치 | 판단 | 근거 |
|---|---|---|
| `classes/swr-pseudo-openat2-fix.bbclass` (USER_CLASSES) | **유지** | 호스트 커널 6.8 그대로. sdr100도 동일 클래스를 쓰며 최신 빌드에서 여전히 필요 |
| `recipes-core/glibc/glibc-locale_%.bbappend` | **유지** | 동일. glibc-locale은 항상 빌드됨 |
| `IMAGE_FSTYPES:remove = "tar.zst"` | **유지** | `tar-replacement-native` 문제 그대로. 머신 conf로 이동 |
| perl `do_install_ptest` tar 교체(sdr100 `recipes-devtools/perl`) | **불필요 → 미반영** | ptest를 DISTRO_FEATURES에서 뺐으므로 `do_install_ptest`가 아예 실행되지 않는다(`ptest.bbclass`의 `PTEST_ENABLED=0`). sdr100도 fb-lite 전환 후에는 사실상 쓰이지 않는 파일 |
| local.conf의 `PACKAGECONFIG:append:pn-qtbase = " sql-sqlite"` | **레이어로 이동** | 빌드 디렉토리를 새로 만들면 빠지는 문제 → `recipes-qt/qt6/qtbase_%.bbappend` |
| `packagegroup-imx-core-tools`의 ntp 제거(sdr100) | **불필요** | swr-image는 그 packagegroup을 쓰지 않음. 오히려 앱이 ntpd를 요구하므로 `ntp`를 명시 설치 |
| `packagegroup-base.bbappend`로 kernel-modules 제거(sdr100) | **불필요** | 머신 conf에서 `MACHINE_EXTRA_RRECOMMENDS=""`로 같은 효과 |
| psplash 유닛 수정/`lcd-console`(sdr100) | **해당 없음** | 디스플레이 없음 |
- **`externalsrc` 레시피(`swr`, `swr-web`)**: 소스 경로가 없는 PC에서는 빌드가 실패한다 — `local.conf`에 `SWR_SRC_DIR`/`SWR_WEB_SRC_DIR` 지정. sstate 재사용 없음.
