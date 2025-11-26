# Bluetooth 페어링 완전 가이드 (터치스크린 전용)

## ✅ 올바른 방법 (Head-Unit UI 사용)

### 1️⃣ Raspberry Pi에서 Head-Unit 앱 실행
```bash
cd /home/seame/DES_Head-Unit/Head-Unit
sudo build/HeadUnitApp
```

**중요**: `sudo`로 실행해야 D-Bus system bus에 agent를 등록할 수 있습니다!

### 2️⃣ 앱 실행 후 로그 확인
다음 메시지들이 나타나야 정상입니다:
```
[BluetoothManager] Bluetooth adapter available
[BluetoothManager] Agent object registered at /com/des/headunit/bluetooth/agent
[BluetoothManager] Agent registered with BlueZ AgentManager
[BluetoothManager] Agent set as default
```

만약 이런 에러가 나오면:
```
Failed to register agent with BlueZ: ...
```
→ `sudo`를 사용했는지 확인하세요!

### 3️⃣ UI에서 Bluetooth 활성화
1. HomeScreen에서 **Bluetooth Settings** 클릭
2. **Bluetooth Power** 스위치를 **ON**으로 켜기
3. **"Start Broadcasting"** 버튼 클릭
4. 화면 하단 "System Status"에서 다음을 확인:
   - ✅ Bluetooth Available: Yes
   - ✅ Bluetooth Powered: On
   - 📡 Broadcasting: Active
   - ✅ Agent Registered: Yes

### 4️⃣ iPhone에서 연결
1. iPhone 설정 → Bluetooth
2. "raspberrypi4-64" (또는 표시되는 이름) 선택
3. **iPhone에 6자리 숫자 표시됨**

### 5️⃣ Head-Unit 화면 확인 ⭐ 중요!
**자동으로 다이얼로그가 나타납니다!**
- 제목: "Pairing Request"
- 장치 이름: "iPhone"
- **큰 6자리 숫자** (iPhone과 동일해야 함)
- 질문: "Does this code match the one on your phone?"
- 버튼: **NO** (빨강) / **YES** (초록)

### 6️⃣ 페어링 완료
1. Head-Unit 화면에서 **YES** 터치
2. iPhone에서 "페어링" 버튼 터치
3. 연결 완료! 🎉

---

## ❌ 잘못된 방법 (bluetoothctl 사용 - 키보드 필요)

**절대로 이렇게 하지 마세요:**
```bash
bluetoothctl  # ❌ 이거 사용하면 안 됨!
```

이 방법은:
- ❌ 키보드가 필요함
- ❌ 터미널 명령어를 쳐야 함
- ❌ 자동차 환경에서 불가능

---

## 🔧 문제 해결

### 다이얼로그가 안 나타날 때

**1. System Status 패널 확인** (화면 하단)
```
Agent Registered: ❌ No
```
→ 앱을 `sudo`로 재시작하세요!

**2. 로그에서 에러 확인**
터미널에서 다음 에러가 있는지 확인:
```
Failed to register agent object: ...
Failed to register agent with BlueZ: ...
```

**3. D-Bus 권한 확인**
```bash
# BlueZ 서비스가 실행 중인지 확인
sudo systemctl status bluetooth

# D-Bus에 agent가 등록되었는지 확인
sudo gdbus introspect --system --dest org.bluez --object-path /com/des/headunit/bluetooth/agent
```

**4. Bluetooth 서비스 재시작**
```bash
sudo systemctl restart bluetooth
sudo build/HeadUnitApp
```

### 에러 메시지 보는 법

UI에 2가지 방법으로 에러가 표시됩니다:

1. **빨간 토스트 알림** (상단)
   - 에러 발생 시 자동으로 5초간 표시
   - 예: "⚠️ Bluetooth Error: Bluetooth must be powered on"

2. **System Status 패널** (하단)
   - "⚠️ Last Error: ..." 줄에 표시
   - 마지막 에러가 계속 보임

---

## 📱 실제 페어링 화면 예시

### Head-Unit 화면:
```
┌─────────────────────────────────────┐
│     Pairing Request                 │
├─────────────────────────────────────┤
│  Confirm pairing with:              │
│                                     │
│  iPhone                             │
│                                     │
│  ┌─────────────────────────────┐  │
│  │       1 2 3 4 5 6           │  │
│  └─────────────────────────────┘  │
│                                     │
│  Does this code match the one on    │
│  your phone?                        │
│                                     │
│     [  NO  ]         [ YES ]        │
└─────────────────────────────────────┘
```

### iPhone 화면:
```
Bluetooth Pairing Request
"raspberrypi4-64" would like to pair with your iPhone.

123456

[Cancel]  [Pair]
```

**숫자가 같으면**: Head-Unit에서 YES → iPhone에서 Pair

---

## 🚗 자동차 환경에서 사용

1. **키보드 불필요** ✅
2. **터치스크린만으로 완료** ✅
3. **모든 에러 화면에 표시** ✅
4. **실시간 상태 확인 가능** ✅

---

## 📋 체크리스트

페어링 전에 확인:
- [ ] Head-Unit 앱을 `sudo`로 실행했나요?
- [ ] 로그에 "Agent registered" 메시지가 보이나요?
- [ ] UI의 "Agent Registered: ✅ Yes"가 보이나요?
- [ ] "Start Broadcasting" 버튼을 눌렀나요?
- [ ] "Broadcasting: 📡 Active"가 표시되나요?

모두 ✅이면 iPhone에서 연결 시도하세요!
