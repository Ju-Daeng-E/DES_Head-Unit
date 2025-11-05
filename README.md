# DES Cockpit Workspace

두 Qt 애플리케이션(Instrument Cluster, Head-Unit)과 Yocto 빌드 환경을 한곳에 모은 통합 워크스페이스. 개발용 랩탑에서는 세션 버스, 라즈베리 파이에서는 시스템 버스를 사용하도록 구성.

## 구성 개요

| 경로 | 설명 |
| --- | --- |
| `DES_Instrument-Cluster/` | 계기판 Qt 앱(`Cluster-app`), Arduino 스케치, systemd 유닛, 문서 |
| `Head-Unit/` | 헤드유닛 Qt 앱. D-Bus 로 Cluster와 기어 상태를 주고받음 |
| `yocto-workspace/` | Yocto Project 워크스페이스 (poky, meta-*, build-des 등) |

상세 사용법은 각 디렉터리의 `README.md`를 참고하세요.

## 로컬 개발(랩탑) 절차

1. Qt Creator 또는 CMake CLI로 **Cluster-app(appIC)** 을 빌드합니다.  
   실행 전 `DES_GEAR_USE_SESSION_BUS=1` 환경변수를 설정해 세션 버스를 사용합니다.
2. 같은 변수 설정으로 **HeadUnitApp** 을 실행합니다.  
   순서는 *appIC → HeadUnitApp* 이어야 D-Bus 서비스(`com.des.vehicle`)가 먼저 등록.
3. 두 앱이 실행 중이면 Head-Unit 좌측 상단의 기어 상태가 Cluster에서 오는 값으로 동기화됩니다.

## Yocto 빌드 & 배포

```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake des-image
```

- `meta-custom/meta-app/recipes-des/headunit/headunit.bb` 가 `../../Head-Unit` 소스를 패키징합니다.  
- 계기판 앱 및 지원 스크립트는 `meta-custom` 하위 레시피에서 포함되며, 완성된 이미지는  
  `build-des/tmp-glibc/deploy/images/raspberrypi4-64/`에 생성됩니다.

## D-Bus 프로토콜 요약

| 항목 | 값 |
| --- | --- |
| 서비스 | `com.des.vehicle` |
| 오브젝트 | `/com/des/vehicle/Gear` |
| 인터페이스 | `com.des.vehicle.Gear` |
| 메서드 | `GetGear() -> [quint8 gear, quint32 seq]`, `RequestGear(quint8 gear, QString source)` |
| 시그널 | `GearChanged(quint8 gear, QString source, quint32 seq)`, `GearRequestRejected(quint8 gear, QString reason)` |

- 개발 환경: `DES_GEAR_USE_SESSION_BUS=1`로 세션 버스를 명시합니다.  
- 배포 환경: 환경변수를 설정하지 않아 시스템 버스를 사용한다. 정책파일로 이름 소유만 허용

## 자주 쓰는 명령 모음

```bash
# 세션 버스에서 서비스 등록 여부 확인
busctl --user list | grep com.des.vehicle

# 시스템 버스 확인 (라즈베리 파이)
busctl --system list | grep com.des.vehicle

# Qt Creator 없이 실행
DES_GEAR_USE_SESSION_BUS=1 \
  DES_Instrument-Cluster/Cluster-app/build/Desktop_Qt_6_9_3-Debug/appIC &
DES_GEAR_USE_SESSION_BUS=1 \
  Head-Unit/build/Desktop_Qt_6_9_3-Debug/HeadUnitApp
```

## 라이선스

모든 코드와 문서는 MIT License를 따릅니다 (`LICENSE` 파일 참조).
