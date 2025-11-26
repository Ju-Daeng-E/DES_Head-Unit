# 빠른 테스트 가이드

## ✅ 변경사항 확인 (2025-11-17)

### 1. **볼륨 UI 추가됨** ✅
- 위치: MusicScreen → Bluetooth 모드
- 기능:
  - 🔊 슬라이더로 볼륨 조절
  - 볼륨 퍼센트 표시
  - 양방향 동기화 (헤드유닛 ↔ 폰)

### 2. **페어링 다이얼로그 구현됨** ✅
- 위치: BluetoothScreen.qml (138-455줄)
- 종류:
  1. `passkeyConfirmDialog` - 6자리 코드 YES/NO 확인
  2. `pinCodeDialog` - PIN 코드 입력
  3. `passkeyDisplayDialog` - 코드 표시

---

## 🧪 테스트 방법

### **볼륨 슬라이더 테스트**

```bash
# 1. 앱 실행
build/HeadUnitApp

# 2. Bluetooth 기기 연결
# 3. Music Screen 이동
# 4. 볼륨 슬라이더 확인 (재생 버튼 아래)
# 5. 슬라이더 조작 → 폰 볼륨 변경 확인
# 6. 폰에서 볼륨 변경 → 슬라이더 업데이트 확인
```

### **페어링 다이얼로그 테스트**

#### **준비사항**:
```bash
# BlueZ 서비스 확인
systemctl status bluetooth

# Bluetooth 어댑터 확인
hciconfig
```

#### **시나리오 1: Passkey Confirmation (일반적인 경우)**

**터미널 1 - 앱 실행**:
```bash
build/HeadUnitApp
```

**터미널 2 - 로그 확인**:
```bash
# Agent 등록 확인
journalctl -f | grep "Agent registered"

# 출력 예시:
# [BluetoothManager] Agent object registered at /com/des/headunit/bluetooth/agent
# [BluetoothManager] Agent registered with BlueZ AgentManager
# [BluetoothManager] Default agent set successfully
```

**터미널 3 - D-Bus 모니터**:
```bash
dbus-monitor --system "interface='org.bluez.Agent1'"
```

**폰에서 실행**:
1. Bluetooth 설정 열기
2. 주변 기기 검색
3. "HeadUnit" 또는 PC 이름 선택
4. **예상 결과**: Head-Unit에 6자리 코드와 YES/NO 버튼 다이얼로그 나타남
5. YES 클릭 → 페어링 완료

#### **시나리오 2: PIN Code (레거시 기기)**

일부 구형 기기는 PIN 코드 요청:
1. 폰에서 PC 선택
2. **예상 결과**: PIN 입력 다이얼로그
3. "0000" 또는 "1234" 입력
4. Pair 클릭 → 페어링 완료

---

## 🚨 문제 해결

### **문제 1: 페어링 다이얼로그가 안나타남**

**원인**: BlueZ Agent가 system bus에 등록 실패

**확인 방법**:
```bash
# 앱 실행 시 로그에서 에러 찾기
build/HeadUnitApp 2>&1 | grep -i "agent\|error\|failed"

# 예상 에러:
# [BluetoothManager] Failed to register agent object: Access denied
# [BluetoothManager] AgentManager interface invalid
```

**해결책**:
```bash
# 방법 1: sudo로 실행 (system bus 권한)
sudo build/HeadUnitApp

# 방법 2: D-Bus 정책 파일 확인
cat /etc/dbus-1/system.d/bluetooth.conf

# 방법 3: 기존 agent 제거 후 재시도
bluetoothctl
> agent off
> exit

build/HeadUnitApp
```

### **문제 2: "Agent already registered" 에러**

**원인**: bluetoothctl이나 다른 앱이 이미 agent 등록함

**해결책**:
```bash
# bluetoothctl agent 비활성화
bluetoothctl
> agent off
> exit

# 앱 재실행
build/HeadUnitApp
```

### **문제 3: 볼륨 슬라이더가 안보임**

**원인**: Bluetooth 모드가 아님

**확인**:
- Music Screen 상단 오른쪽에 "📱 Bluetooth" 표시 확인
- 표시가 "💿 Local"이면 Bluetooth 연결 안됨
- Bluetooth Settings에서 기기 연결 필요

### **문제 4: 볼륨 동기화 안됨**

**원인**: 폰이 AVRCP 볼륨 컨트롤 미지원

**확인**:
```bash
# D-Bus로 MediaControl1 인터페이스 확인
busctl introspect org.bluez /org/bluez/hci0/dev_XX_XX_XX_XX_XX_XX

# Volume property 있는지 확인
```

**해결책**:
- 일부 폰은 개발자 옵션에서 "절대 볼륨" 활성화 필요
- Android: 설정 → 개발자 옵션 → Bluetooth 절대 볼륨 비활성화/활성화

---

## 📊 로그 확인 가이드

### **정상 실행 로그**:
```
[BluetoothManager] Initializing BluetoothManager...
[BluetoothAgent] Agent created
[BluetoothManager] Agent object registered at /com/des/headunit/bluetooth/agent
[BluetoothManager] Agent registered with BlueZ AgentManager
[BluetoothManager] Default agent set successfully
[BluetoothManager] Bluetooth initialization complete
```

### **페어링 시작 로그**:
```
[BluetoothAgent] RequestConfirmation: Device: SM-G991N Passkey: 123456
# 다이얼로그 표시됨
[BluetoothAgent] User accepted pairing
# 또는
[BluetoothAgent] User rejected pairing
```

### **볼륨 변경 로그**:
```
[BluetoothAudioPlayer] setVolume: 75
# 또는
[BluetoothAudioPlayer] Volume changed from phone: 80
```

---

## 📝 참고 사항

### **실행 모드**:

1. **개발 모드 (Gear 통신용 session bus)**:
   ```bash
   DES_GEAR_USE_SESSION_BUS=1 build/HeadUnitApp
   ```
   - Gear 통신: session bus
   - Bluetooth: system bus (항상)

2. **일반 모드**:
   ```bash
   build/HeadUnitApp
   ```
   - 모든 D-Bus 통신: system bus

### **권한 문제 해결**:

만약 계속 권한 에러가 나면 사용자를 bluetooth 그룹에 추가:
```bash
sudo usermod -a -G bluetooth $USER
# 재로그인 필요
```

---

## 🎯 빠른 체크리스트

- [ ] BlueZ 서비스 실행 중
- [ ] Bluetooth 어댑터 켜짐 (hciconfig 확인)
- [ ] 앱 실행 시 "Agent registered" 로그 확인
- [ ] Bluetooth Settings에서 "Start Broadcasting" 클릭
- [ ] 폰에서 PC 검색
- [ ] 페어링 다이얼로그 나타남
- [ ] YES 클릭 → 페어링 완료
- [ ] Music Screen에서 볼륨 슬라이더 확인
- [ ] 볼륨 조작 → 폰 볼륨 변경 확인

---

**문제가 계속되면**:
- 전체 로그 캡처: `build/HeadUnitApp 2>&1 | tee app.log`
- D-Bus 메시지 캡처: `dbus-monitor --system > dbus.log`
- 로그 분석해서 구체적인 에러 찾기
