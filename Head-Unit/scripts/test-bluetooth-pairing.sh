#!/bin/bash

echo "========================================"
echo "Bluetooth 페어링 테스트 스크립트"
echo "========================================"
echo ""

# 1. BlueZ 상태 확인
echo "1. BlueZ 서비스 상태 확인..."
systemctl status bluetooth | grep "Active:"
echo ""

# 2. Bluetooth 어댑터 확인
echo "2. Bluetooth 어댑터 확인..."
hciconfig
echo ""

# 3. D-Bus 권한 확인
echo "3. D-Bus 시스템 버스 접근 확인..."
dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames | grep bluez
echo ""

echo "========================================"
echo "테스트 시나리오:"
echo "========================================"
echo ""
echo "1. 이 터미널에서 다음 명령 실행:"
echo "   build/HeadUnitApp"
echo ""
echo "2. 다른 터미널에서 로그 모니터링:"
echo "   journalctl -f | grep -i bluetooth"
echo ""
echo "3. 또 다른 터미널에서 D-Bus 메시지 모니터링:"
echo "   dbus-monitor --system \"interface='org.bluez.Agent1'\""
echo ""
echo "4. 폰에서 Bluetooth 검색 후 PC 선택"
echo ""
echo "5. 페어링 다이얼로그 확인:"
echo "   - passkeyConfirmDialog: 6자리 코드 YES/NO"
echo "   - pinCodeDialog: PIN 입력"
echo "   - passkeyDisplayDialog: 코드 표시"
echo ""

echo "========================================"
echo "문제 해결:"
echo "========================================"
echo ""
echo "✗ 다이얼로그가 안나타나는 경우:"
echo "  → Agent가 BlueZ에 등록 안됨"
echo "  → 로그 확인: '[BluetoothManager] Agent registered with BlueZ AgentManager'"
echo ""
echo "✗ 'Access Denied' 에러:"
echo "  → D-Bus 권한 부족"
echo "  → sudo로 실행: sudo build/HeadUnitApp"
echo ""
echo "✗ 'Agent already registered' 에러:"
echo "  → 기존 agent 제거 필요"
echo "  → bluetoothctl에서: agent off"
echo ""
