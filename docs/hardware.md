# 하드웨어 사양

meta-swr이 타겟으로 하는 SWR SmartRoute 게이트웨이 보드의 명세와, 실기기(192.168.0.150)를 SSH로 확인한 실측값. 제품 기능 사양은 `/home/dev3/project/swr/docs/spec/spec.md` 참고.

## 기본 사양

| 항목 | 내용 |
|---|---|
| SoC | NXP i.MX6ULL (싱글코어 ARMv7 Cortex-A7 528MHz, GPU 없음) |
| DRAM | 512MB (커널 인식 497MB — OP-TEE 제거 전에는 453MB) |
| 스토리지 | eMMC 8GB (uSDHC2). 첫 부팅 시 rootfs 자동 전체 확장 |
| Ethernet | 2포트: FEC1 + FEC2, PHY는 둘 다 FEC2의 MDIO 버스(EVK와 동일 구성). **시제품은 FEC1 쪽 PHY만 실장** |
| RS485 | 1포트, UART2 (`/dev/ttymxc1`) |
| 디버그 콘솔 | UART1 (`/dev/ttymxc0`, 115200) |
| RTC | 외부 Ricoh RS5C372A (`i2c1`/Linux `i2c-0`, 주소 `0x32`), 코인셀 백업 |
| 디스플레이/터치/오디오/부저/무선 | **없음** (헤드리스) |

## 디바이스트리: `recipes-kernel/linux/files/imx6ull-swr.dts`

EVK dtsi를 include하지 않는 독립 파일. 보드에 있는 장치만 들어 있고 나머지는 SoC dtsi 기본값(disabled)이다. 핀먹스는 EVK와 같은 배선인 부분(이더넷, eMMC, UART1/2, I2C1)을 EVK dtsi에서 그대로 가져왔다.

| 노드 | 상태 | 비고 |
|---|---|---|
| `&fec1`, `&fec2` | okay | KSZ8081 PHY 주소 2(FEC1), 1(FEC2), RMII |
| `&i2c1` | okay | `ext_rtc: rtc@32` ricoh,rs5c372a. `aliases`로 rtc0 고정(rtc1 = SNVS) |
| `&uart1` | okay | 콘솔 |
| `&uart2` | okay | RS485. EVK 설정(RTS/CTS 핀 포함, `uart-has-rtscts`) 유지 |
| `&usdhc2` | okay | eMMC, 4bit (EVK 기본) |
| `&wdog1` | - | SoC 내부 리셋. EVK의 `fsl,ext-reset-output`은 제거(아래 참고) |
| `&snvs_pwrkey`, `&snvs_poweroff` | okay | |
| `reg_peri_3v3` | always-on | GPIO5_IO02. EVK에서는 PHY 전원 enable |

**재부팅/워치독**: OP-TEE(PSCI)가 없으므로 커널은 wdog1로 재시작한다. EVK의 `fsl,ext-reset-output`은 외부 WDOG_B 핀(LCD_RESET 패드)만 구동하는데 이 보드는 그 핀이 리셋에 연결돼 있지 않아 `reboot`가 "Reboot failed -- System halted"로 멈추고 128초 워치독 타임아웃으로만 재시작됐다(2026-10-13 실기기, meta-sdr100 동일). 속성을 빼서 SoC 내부 리셋 사용.

복구용으로 순정 `imx6ull-14x14-evk.dtb`도 boot 파티션에 같이 들어간다(`conf/machine/swr-gateway.conf`). U-Boot에서 `setenv fdt_file imx6ull-14x14-evk.dtb; saveenv`로 전환 가능.

### 회로도 확인이 필요한 항목

1. **RS485 방향 제어** — 트랜시버가 자동 방향전환이면 현재 설정으로 충분. RTS로 DE/RE를 제어해야 하면 `&uart2`에 `linux,rs485-enabled-at-boot-time;`과 극성(`rs485-rts-active-high;`)을 추가.
2. **eMMC 버스 폭** — DATA4~7이 배선되어 있으면 EVK `-emmc.dts`처럼 8bit 핀먹스로 전환해 성능 향상 가능.
3. **`reg_peri_3v3`(GPIO5_IO02)** — 이 보드에 해당 레귤레이터 회로가 없으면 노드와 `phy-supply`를 제거.
4. **FEC2 PHY** — 양산 보드에 주소 1 PHY가 실장되면 그대로 동작. 시제품에서는 PHY 리셋 폴링 타임아웃으로 부팅이 약 40초 지연됨(FEC2를 잠시 `disabled`로 두면 사라짐).

## 실기기 실측값 (2026-10-13)

- 인터페이스 이름: 커널 프로브 순서상 **FEC2 = eth0, FEC1 = eth1**. 시제품에서 동작하는 포트는 eth1(FEC1). 네트워크 설정은 이름이 아니라 udev `ID_PATH`(`platform-2188000.ethernet` = FEC1, `platform-20b4000.ethernet` = FEC2)로 매칭하므로 이름이 바뀌어도 영향 없음.
- RTC: DTS `aliases`로 rtc0 = RS5C372A(외부, 배터리), rtc1 = SNVS로 고정. `CONFIG_RTC_HCTOSYS`/`SYSTOHC`로 NTP 동기화 후 약 11분마다 커널이 rtc0에 되씀.
- 메모리: SmartRoute 앱 RSS 약 19MB. 여유 약 250MB.

## 관련 커널 설정

- `CONFIG_RTC_DRV_RS5C372=y` — `recipes-kernel/linux/files/rtc-rs5c372.cfg`, `DELTA_KERNEL_DEFCONFIG`로 반영(표준 SRC_URI `.cfg` fragment는 이 커널 레시피에서 무효 — `docs/testing-and-setup.md` 참고).
