# Bluetooth Class 0x200408 → 0x240408 수정

## 문제 상황

**증상**: Bluetooth 연결은 되지만 음악 데이터를 받지 못함

**원인**:
```bash
hciconfig hci0 class
# 출력: Class: 0x200408  ❌ (Computer)
# 예상: Class: 0x240408  ✅ (Audio/Video Device)
```

**왜 문제인가?**
- `0x200408` = Computer 장치로 인식
- MediaPlayer1 인터페이스가 생성되지 않음
- AVRCP 미디어 제어 불가능

**Class 코드 설명**:
- `0x240408` = `0x24` (Audio/Video) + `0x04` (Audio) + `0x08` (Rendering)
- `0x200408` = `0x20` (Computer) + `0x04` (Audio) + `0x08` (Rendering)

## 해결 방법

### 방법 1: 즉시 테스트 (임시, 재부팅 시 초기화)

라즈베리파이에서 실행:

```bash
# Class 변경
sudo hciconfig hci0 class 0x240408

# 확인
hciconfig hci0 class
# 출력: Class: 0x240408

# Bluetooth 재시작
sudo systemctl restart bluetooth

# iPhone/Android에서 음악 재생 테스트
```

### 방법 2: 영구적 해결 (systemd 서비스 사용)

#### 왜 main.conf가 안 먹히나?

BlueZ의 `/etc/bluetooth/main.conf`는 **어댑터 초기화 시** 읽히지만:
1. 일부 Bluetooth 펌웨어가 자체 기본값을 사용
2. bluetoothd가 명령줄 인자로 Class를 덮어쓸 수 있음
3. Raspberry Pi의 Bluetooth 칩이 Class를 캐싱할 수 있음

**해결책**: systemd 서비스로 **부팅 시마다 강제 설정**

#### 적용된 수정

**파일 1**: `bluetooth-class-fix.service`

```ini
[Unit]
Description=Set Bluetooth Class to Audio/Video Device
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/hciconfig hci0 class 0x240408

[Install]
WantedBy=multi-user.target
```

**설명**:
- `After=bluetooth.service`: Bluetooth 서비스가 시작된 후 실행
- `ExecStartPre=/bin/sleep 2`: hci0가 준비될 때까지 2초 대기
- `ExecStart=/usr/bin/hciconfig hci0 class 0x240408`: Class 설정
- `Type=oneshot`: 한 번만 실행 후 종료
- `RemainAfterExit=yes`: 서비스가 완료된 것으로 표시

**파일 2**: `headunit.bb` 수정

```bitbake
SRC_URI = "file://headunit.service \
           file://rfkill-unblock.service \
           file://headunit-bluetooth.conf \
           file://bluetooth-class-fix.service \     # ← 추가
"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/headunit.service ${D}${systemd_system_unitdir}/headunit.service
    install -m 0644 ${WORKDIR}/rfkill-unblock.service ${D}${systemd_system_unitdir}/rfkill-unblock.service
    install -m 0644 ${WORKDIR}/bluetooth-class-fix.service ${D}${systemd_system_unitdir}/bluetooth-class-fix.service  # ← 추가
    install -d ${D}${sysconfdir}/dbus-1/system.d/
    install -m 0644 ${WORKDIR}/headunit-bluetooth.conf ${D}${sysconfdir}/dbus-1/system.d/headunit-bluetooth.conf
}

FILES:${PN} += "\
    ${bindir}/HeadUnitApp \
    ${datadir}/headunit \
    ${systemd_system_unitdir}/headunit.service \
    ${systemd_system_unitdir}/rfkill-unblock.service \
    ${systemd_system_unitdir}/bluetooth-class-fix.service \  # ← 추가
    ${sysconfdir}/dbus-1/system.d/headunit-bluetooth.conf \
"

SYSTEMD_SERVICE:${PN} = "headunit.service rfkill-unblock.service bluetooth-class-fix.service"  # ← 추가
```

## 빌드 및 배포

### 빌드

```bash
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

# headunit 레시피만 클린 (빠른 빌드)
bitbake -c cleanall headunit

# 이미지 재빌드
bitbake des-image
```

### 플래싱

```bash
cd build-des/tmp-glibc/deploy/images/raspberrypi4-64

# SD 카드 확인
lsblk

# 플래싱
sudo bzcat des-image-raspberrypi4-64.rootfs.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress conv=fsync
sync
```

## 검증

### 라즈베리파이 부팅 후 확인

```bash
# SSH 접속
ssh root@raspberrypi4-64

# 1. 서비스 상태 확인
systemctl status bluetooth-class-fix.service
# 출력: active (exited), "Set Bluetooth Class to Audio/Video Device"

# 2. Class 확인
hciconfig hci0 class
# 출력: Class: 0x240408 ✅

# 3. Bluetooth 서비스 확인
systemctl status bluetooth
# 출력: active (running)

# 4. 서비스 로그 확인
journalctl -u bluetooth-class-fix.service -n 20
```

### 기능 테스트

1. **Bluetooth 페어링**
   - Head-Unit → Bluetooth 설정
   - "Start Broadcasting"
   - iPhone/Android에서 "SEAME2025" 연결
   - 자동 페어링 성공

2. **음악 재생 테스트**
   - iPhone/Android에서 음악 앱 실행
   - 아무 노래나 재생
   - Head-Unit Music 화면에서 확인:
     - ✅ 트랙 제목 표시
     - ✅ 아티스트/앨범 표시
     - ✅ Play/Pause 버튼 동작
     - ✅ Next/Previous 버튼 동작

3. **D-Bus 인터페이스 확인**
   ```bash
   # MediaPlayer1 인터페이스 확인
   gdbus introspect --system --dest org.bluez --object-path /org/bluez/hci0/dev_XX_XX_XX_XX_XX_XX | grep MediaPlayer
   # 출력: interface org.bluez.MediaPlayer1 ✅
   ```

## 트러블슈팅

### 문제 1: Class가 여전히 0x200408

**확인**:
```bash
systemctl status bluetooth-class-fix.service
```

**원인 1**: 서비스가 실행되지 않음
```bash
# 수동 실행
sudo systemctl start bluetooth-class-fix.service

# 로그 확인
journalctl -u bluetooth-class-fix.service -n 50
```

**원인 2**: hci0가 준비되기 전에 실행됨
- `bluetooth-class-fix.service`의 `ExecStartPre=/bin/sleep 2`를 3초로 증가
- 또는 `ExecStartPre=/bin/sh -c 'while ! hciconfig hci0; do sleep 1; done'`

**원인 3**: 서비스가 활성화되지 않음
```bash
sudo systemctl enable bluetooth-class-fix.service
sudo systemctl start bluetooth-class-fix.service
```

### 문제 2: 서비스는 성공했지만 Class가 바뀌지 않음

**Bluetooth 펌웨어 리셋**:
```bash
# Bluetooth 완전 재시작
sudo systemctl stop bluetooth
sudo hciconfig hci0 down
sleep 2
sudo hciconfig hci0 up
sudo systemctl start bluetooth
sleep 2
sudo hciconfig hci0 class 0x240408
```

### 문제 3: 재부팅 후 다시 0x200408로 돌아감

**원인**: systemd 서비스가 부팅 시 자동 시작되지 않음

**해결**:
```bash
# 서비스 활성화 확인
systemctl is-enabled bluetooth-class-fix.service
# 출력: enabled

# 활성화되지 않았다면
sudo systemctl enable bluetooth-class-fix.service
```

## 왜 이 방법이 필요한가?

### BlueZ main.conf의 한계

1. **펌웨어 우선순위**
   - Raspberry Pi의 Bluetooth 칩(CYW43455)은 자체 펌웨어 설정을 가짐
   - 펌웨어 기본값이 main.conf보다 우선할 수 있음

2. **초기화 타이밍**
   - bluetoothd가 시작할 때 main.conf를 읽음
   - 하지만 hci0 어댑터 초기화 후 펌웨어가 Class를 덮어쓸 수 있음

3. **설정 적용 방법**
   - main.conf: bluetoothd 시작 시 1회 읽기
   - hciconfig: 런타임에 직접 하드웨어 설정

### systemd 서비스의 장점

1. **확실성**: 부팅마다 강제 설정
2. **타이밍 제어**: bluetooth.service 이후 실행 보장
3. **로깅**: journalctl로 실행 여부 확인 가능
4. **유지보수**: 설정 변경 시 서비스 파일만 수정

## 대안: Bluetooth 펌웨어 패치 (고급)

더 근본적인 해결책은 Bluetooth 펌웨어에서 기본 Class를 변경하는 것이지만:
- Broadcom/Cypress 펌웨어 바이너리 수정 필요
- 복잡하고 리스크가 높음
- systemd 서비스 방법이 충분히 효과적임

## 요약

| 항목 | 설명 |
|------|------|
| **문제** | Class 0x200408 (Computer) → MediaPlayer 없음 |
| **해결** | systemd 서비스로 0x240408 (Audio/Video) 강제 설정 |
| **효과** | AVRCP 미디어 제어 활성화 |
| **지속성** | 부팅 시마다 자동 설정 |

**즉시 테스트**: `sudo hciconfig hci0 class 0x240408`
**영구 해결**: 위의 빌드 및 배포 과정 진행





최종 목표: 차량용 헤드유닛(Qt App)이 블루투스 오디오 기기(A2DP Sink)로 동작하며, 별도의 입력 없이 스마트폰과 자동으로 페어링 및 연결되는 것.                                           
    
                                                                                                                                                                                         
    
  현재 상태:                                                                                                                                                                             
    
   * Yocto 이미지를 새로 빌드하고 기기에 설치 완료.                                                                                                                                      
    
   * 자동 페어링은 성공함. (연결 시 6자리 숫자 확인 과정 없음)                                                                                                                           
    
   * 하지만, 페어링 후에도 스마트폰에서 라즈베리파이를 오디오 출력 기기로 인식하지 못함.                                                                                                 
    
                                                                                                                                                                                         
    
  지금까지 확인 및 수정된 사항:                                                                                                                                                          
    
                                                                                                                                                                                         
    
   1. `HeadUnitApp` 자동 페어링 에이전트 (`BluetoothAgent`):                                                                                                                             
    
       * 소스 코드에 자동 인증 로직이 정상적으로 포함되어 있음을 확인.                                                                                                                   
    
       * systemd 서비스를 통해 앱이 부팅 시 실행되고, 에이전트가 BlueZ에 성공적으로 등록됨을 journalctl 로그로 확인.                                                                     
    
                                                                                                                                                                                         
    
   2. Yocto 레시피 (`pulseaudio_%.bbappend`):                                                                                                                                            
    
       * RDEPENDS 변수가 += 연산자 및 ${PN} 변수와 함께 사용될 때, 의존성을 추가하는 대신 덮어쓰는 문제를 발견.                                                                          
    
       * ${PN}을 pulseaudio로 명시적으로 변경하여 RDEPENDS:pulseaudio-server에 의존성이 올바르게 추가되도록 수정. 빌드 경고가 사라짐을 확인.                                             
    
                                                                                                                                                                                         
    
   3. PulseAudio 설정 (`system.pa`):                                                                                                                                                     
    
       * 스피커 없는 환경을 위해, Yocto 레시피의 system.pa.append 파일에 다음 내용을 추가하여 빌드에 포함시킴:                                                                           
    
           * load-module module-bluetooth-policy                                                                                                                                         
    
           * load-module module-bluetooth-discover                                                                                                                                       
    
           * load-module module-null-sink sink_name=bt_sink                                                                                                                              
    
           * set-default-sink bt_sink                                                                                                                                                    
    
                                                                                                                                                                                         
    
   4. PulseAudio 서비스:                                                                                                                                                                 
    
       * 초기에 서비스가 inactive (dead) 상태였음을 확인.                                                                                                                                
    
       * systemctl enable pulseaudio.service를 통해 부팅 시 자동 실행되도록 설정 완료. 서비스가 active (running) 상태임을 확인.                                                          
    
                                                                                                                                                                                         
    
  남아있는 의문점:                                                                                                                                                                       
    
   * 위 모든 조건이 충족되었음에도 불구하고, 왜 A2DP 오디오 프로필이 최종적으로 활성화되지 않는가?                                                                                       
    
   * 수동 디버깅 중 bluetoothd 로그에서 관찰된 "Authentication Failure (status 5)" 오류는, 당시 HeadUnitApp이 실행되지 않았기 때문으로 추정했으나, 모든 서비스가 정상 실행되는 지금도 
비슷한 
     인증/프로필 활성화 실패가 내부적으로 발생하고 있을 가능성. 