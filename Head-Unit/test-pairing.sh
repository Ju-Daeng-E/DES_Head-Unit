#!/bin/bash

echo "========================================"
echo "Bluetooth Pairing 진단 스크립트"
echo "========================================"
echo ""

# 1. Bluetooth 서비스 상태
echo "1. Bluetooth 서비스 상태 확인..."
sudo systemctl status bluetooth | grep "Active:" || echo "Bluetooth 서비스 없음"
echo ""

# 2. 현재 등록된 agent 확인
echo "2. 현재 등록된 Bluetooth Agent 확인..."
echo "   (다른 agent가 있으면 우리 agent가 작동 안 함!)"
sudo gdbus call --system --dest org.bluez --object-path /org/bluez \
  --method org.freedesktop.DBus.ObjectManager.GetManagedObjects 2>/dev/null | \
  grep -o "agent" && echo "   ⚠️ Agent가 이미 등록되어 있음!" || echo "   ✅ Agent 없음 (정상)"
echo ""

# 3. bluetoothctl agent 확인
echo "3. bluetoothctl의 agent 상태 확인..."
echo "   만약 'Agent is already registered' 에러가 나오면:"
echo "   → bluetoothctl이 자체 agent를 등록한 것"
echo "   → bluetoothctl을 종료해야 함!"
echo ""

# 4. 앱 실행 및 로그 확인
echo "4. Head-Unit 앱 실행 중..."
echo "   로그에서 다음을 확인하세요:"
echo ""
echo "   ✅ 성공 메시지:"
echo "      [BluetoothManager] ✅ Agent object registered"
echo "      [BluetoothManager] ✅ Agent registered with BlueZ AgentManager"
echo "      [BluetoothManager] ✅ Agent set as default"
echo ""
echo "   ❌ 실패 메시지:"
echo "      *** FAILED to register agent ***"
echo "      Error: ... (D-Bus 권한 문제)"
echo ""
echo "   📱 페어링 요청 메시지 (iPhone 연결 시):"
echo "      [BluetoothAgent] *** PAIRING REQUEST ***"
echo "      [BluetoothAgent] Passkey: 123456"
echo "      [main.qml] Pairing dialog OPENED"
echo ""
echo "========================================"
echo "5초 후 앱이 시작됩니다..."
echo "터미널 로그를 주의깊게 보세요!"
echo "========================================"
sleep 5

cd /home/seame/DES_Head-Unit/Head-Unit
sudo build/HeadUnitApp 2>&1 | tee pairing_debug.log
