# Bluetooth Auto-Pairing Fix

## 문제 (Problem)
블루투스 페어링 시 라즈베리파이 터미널에서 수동으로 "yes"를 입력해야 했습니다. 자동으로 모든 페어링 요청을 승인하도록 개선이 필요했습니다.

When pairing via Bluetooth, users had to manually type "yes" in the Raspberry Pi terminal. Need automatic acceptance of all pairing requests.

## 해결 방법 (Solution)
BluetoothAgent의 모든 인증 메소드를 자동 승인하도록 수정했습니다. 이제 터미널에서 "yes"를 계속 입력하는 것처럼 자동으로 동작합니다.

Modified all BluetoothAgent authentication methods to auto-accept. Now works automatically like typing "yes" in terminal repeatedly.

## 수정된 파일 (Modified Files)

**File**: `Head-Unit/src/backend/bluetooth/bluetooth_agent.cpp`

### 1. RequestConfirmation() - 6자리 숫자 확인 자동 승인
**Before**: 사용자가 QML UI에서 YES/NO 버튼을 클릭할 때까지 대기
**After**: 즉시 자동 승인 (return normally = accepted)

```cpp
void BluetoothAgent::RequestConfirmation(const QDBusObjectPath& device, quint32 passkey) {
    // ...
    qDebug() << "[BluetoothAgent] ✅ AUTO-ACCEPTING pairing (no user confirmation needed)";

    // Auto-accept pairing without waiting for user confirmation
    // Return immediately - success means accepted in BlueZ agent protocol
    qDebug() << "[BluetoothAgent] ✅ Pairing automatically accepted";
}
```

### 2. RequestPinCode() - PIN 코드 자동 제공
**Before**: 사용자가 PIN 입력할 때까지 60초 대기
**After**: 기본 PIN "0000" 자동 반환

```cpp
QString BluetoothAgent::RequestPinCode(const QDBusObjectPath& device) {
    // Auto-provide default PIN code "0000" (most common for Bluetooth devices)
    QString defaultPin = "0000";
    qDebug() << "[BluetoothAgent] ✅ AUTO-PROVIDING PIN code:" << defaultPin;
    return defaultPin;
}
```

### 3. RequestPasskey() - Passkey 자동 제공
**Before**: 사용자가 숫자 입력할 때까지 60초 대기
**After**: 기본 passkey "000000" 자동 반환

```cpp
quint32 BluetoothAgent::RequestPasskey(const QDBusObjectPath& device) {
    // Auto-provide default passkey 000000
    quint32 defaultPasskey = 0;
    qDebug() << "[BluetoothAgent] ✅ AUTO-PROVIDING passkey:" << defaultPasskey;
    return defaultPasskey;
}
```

## 작동 방식 (How It Works)

### BlueZ Agent Protocol
BlueZ D-Bus agent가 페어링 요청을 받으면:

1. **RequestConfirmation(device, passkey)**
   - BlueZ: "6자리 숫자 123456이 맞습니까?"
   - 이전: QML UI에서 사용자가 YES 클릭할 때까지 대기
   - **현재**: 즉시 return → BlueZ는 자동으로 "YES"로 해석

2. **RequestPinCode(device)**
   - BlueZ: "PIN 코드를 입력하세요"
   - 이전: 사용자가 PIN 입력할 때까지 대기
   - **현재**: 즉시 "0000" 반환

3. **RequestPasskey(device)**
   - BlueZ: "Passkey를 입력하세요"
   - 이전: 사용자가 숫자 입력할 때까지 대기
   - **현재**: 즉시 0 반환

4. **RequestAuthorization(device)** / **AuthorizeService(device, uuid)**
   - 이미 자동 승인으로 구현되어 있음 (변경 없음)

## 빌드 및 배포 (Build & Deploy)

### Yocto 이미지 빌드
```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleanall headunit
bitbake des-image
```

### SD 카드에 이미지 쓰기
```bash
# wic.bz2 파일 찾기
IMAGE_FILE=$(find build-des/tmp-glibc/deploy/images/raspberrypi4-64/ -name "*des-image*.wic.bz2" | head -1)

# SD 카드 경로 확인 (예: /dev/sdb)
lsblk

# 이미지 쓰기
sudo bzcat $IMAGE_FILE | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync

# SD 카드 언마운트
sudo sync
sudo umount /dev/sdX*
```

## 테스트 (Testing)

### 1. 라즈베리파이 부팅 후 Qt 앱 실행
```bash
# SSH 접속
ssh root@192.168.86.22

# 로그 확인
journalctl -u headunit -f
```

### 2. 블루투스 검색 가능 모드 활성화
- Qt 앱에서 "Make Discoverable" 버튼 클릭
- 또는 터미널: `bluetoothctl discoverable on`

### 3. 아이폰/안드로이드에서 페어링 시도
1. 폰의 블루투스 설정 열기
2. "raspberrypi4-64" 또는 기기 이름 선택
3. **6자리 숫자가 폰에 표시됨**
4. **폰에서 "페어링" 버튼만 탭하면 끝!**
5. **라즈베리파이가 자동으로 승인 → 즉시 연결**

### 예상 로그 출력 (Expected Console Output)
```
[BluetoothAgent] *** PAIRING REQUEST ***
[BluetoothAgent] RequestConfirmation CALLED
[BluetoothAgent] Device Name: iPhone
[BluetoothAgent] Passkey: 123456
[BluetoothAgent] ✅ AUTO-ACCEPTING pairing (no user confirmation needed)
[BluetoothAgent] ✅ Pairing automatically accepted
[BluetoothManager] Device connected: iPhone
[BluetoothAudioPlayer] Audio Sink profile activated
```

## 성공 기준 (Success Criteria)

- ✅ 폰에서 페어링 버튼만 누르면 자동으로 연결됨 (터미널 "yes" 입력 불필요)
- ✅ 라즈베리파이 터미널에서 수동 입력 필요 없음
- ✅ 6자리 숫자 확인 자동 승인
- ✅ PIN 코드 자동 제공 (0000)
- ✅ Passkey 자동 제공 (000000)
- ✅ 연결 후 A2DP 오디오 프로필 자동 활성화
- ✅ 폰 음악이 라즈베리파이 스피커로 스트리밍

## 기술적 세부사항 (Technical Details)

### BlueZ Agent Capabilities
현재 사용 중인 capability: **"NoInputNoOutput"**
- 위치: `bluetooth_manager.cpp:416`
- 의미: 입력/출력 장치 없음 → BlueZ가 자동 페어링 시도
- **하지만**: Agent 메소드가 명시적으로 return해야 승인됨

### Agent 메소드 반환 규칙
1. **정상 return**: 승인 (accepted/confirmed)
2. **sendErrorReply()**: 거부 (rejected/denied)
3. **timeout or exception**: 실패 (failed)

### 이전 구현 문제점
```cpp
// 이전: QEventLoop로 사용자 입력 대기
QEventLoop loop;
connect(this, &BluetoothAgent::confirmationResponseReady, &loop, &QEventLoop::quit);
loop.exec(); // 여기서 멈춤!

if (!confirmationResponse_) {
    sendErrorReply(...); // 사용자가 NO 누르면 거부
    return;
}
// 사용자가 YES 누르면 정상 return → 승인
```

### 현재 구현 (자동 승인)
```cpp
// 현재: 즉시 정상 return → BlueZ가 승인으로 해석
qDebug() << "[BluetoothAgent] ✅ AUTO-ACCEPTING pairing";
// 정상 return (no sendErrorReply) = 자동 승인
```

## 참고 사항 (Notes)

### 보안 고려사항
- **현재 설정**: 모든 페어링 요청 자동 승인 (자동차 헤드유닛 환경에 적합)
- **프로덕션 환경**: 필요시 첫 페어링만 자동 승인, 이후는 저장된 기기만 연결하도록 수정 가능

### CarPlay 연결
- 페어링 승인 시 HFP (Hands-Free Profile)도 활성화됨
- 아이폰이 자동으로 CarPlay 연결 시도할 수 있음
- CarPlay 필요 없으면 HFP 프로필 비활성화 권장

### 기타
- UI에서 passkey 알림은 여전히 표시됨 (emit signal) → 사용자가 폰과 라즈베리파이의 숫자가 같은지 확인 가능
- 하지만 라즈베리파이는 자동으로 승인하므로 사용자 액션 불필요
