#!/bin/bash

echo "=========================================="
echo "페어링 다이얼로그 디버깅 스크립트"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. QML 파일에 다이얼로그 구현 확인
echo "1. BluetoothScreen.qml 페어링 다이얼로그 확인..."
echo ""

if grep -q "passkeyConfirmDialog" ui/pages/BluetoothScreen.qml; then
    echo -e "${GREEN}✓${NC} passkeyConfirmDialog 구현됨 (YES/NO 확인)"
else
    echo -e "${RED}✗${NC} passkeyConfirmDialog 없음"
fi

if grep -q "pinCodeDialog" ui/pages/BluetoothScreen.qml; then
    echo -e "${GREEN}✓${NC} pinCodeDialog 구현됨 (PIN 입력)"
else
    echo -e "${RED}✗${NC} pinCodeDialog 없음"
fi

if grep -q "passkeyDisplayDialog" ui/pages/BluetoothScreen.qml; then
    echo -e "${GREEN}✓${NC} passkeyDisplayDialog 구현됨 (코드 표시)"
else
    echo -e "${RED}✗${NC} passkeyDisplayDialog 없음"
fi

echo ""

# 2. 시그널 연결 확인
echo "2. QML 시그널 연결 확인..."
echo ""

if grep -q "passkeyConfirmationRequested.connect" ui/pages/BluetoothScreen.qml; then
    echo -e "${GREEN}✓${NC} passkeyConfirmationRequested 시그널 연결됨"
else
    echo -e "${RED}✗${NC} passkeyConfirmationRequested 시그널 연결 안됨"
fi

if grep -q "pinCodeRequested.connect" ui/pages/BluetoothScreen.qml; then
    echo -e "${GREEN}✓${NC} pinCodeRequested 시그널 연결됨"
else
    echo -e "${RED}✗${NC} pinCodeRequested 시그널 연결 안됨"
fi

echo ""

# 3. BluetoothAgent 클래스 확인
echo "3. BluetoothAgent C++ 클래스 확인..."
echo ""

if [ -f "src/backend/bluetooth/bluetooth_agent.h" ]; then
    echo -e "${GREEN}✓${NC} bluetooth_agent.h 존재"
else
    echo -e "${RED}✗${NC} bluetooth_agent.h 없음"
fi

if [ -f "src/backend/bluetooth/bluetooth_agent.cpp" ]; then
    echo -e "${GREEN}✓${NC} bluetooth_agent.cpp 존재"
else
    echo -e "${RED}✗${NC} bluetooth_agent.cpp 없음"
fi

echo ""

# 4. CMakeLists.txt에 포함되었는지 확인
echo "4. CMakeLists.txt에 Agent 파일 포함 확인..."
echo ""

if grep -q "bluetooth_agent.cpp" CMakeLists.txt; then
    echo -e "${GREEN}✓${NC} bluetooth_agent.cpp CMakeLists.txt에 포함됨"
else
    echo -e "${RED}✗${NC} bluetooth_agent.cpp CMakeLists.txt에 없음"
fi

echo ""

# 5. D-Bus 권한 확인
echo "5. D-Bus 시스템 버스 권한 확인..."
echo ""

if dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | grep -q bluez; then
    echo -e "${GREEN}✓${NC} BlueZ D-Bus 서비스 접근 가능"
else
    echo -e "${YELLOW}⚠${NC} BlueZ D-Bus 서비스 접근 불가 (권한 문제일 수 있음)"
fi

echo ""

# 6. 사용자 그룹 확인
echo "6. 사용자 Bluetooth 그룹 확인..."
echo ""

if groups | grep -q bluetooth; then
    echo -e "${GREEN}✓${NC} 사용자가 bluetooth 그룹에 속함"
else
    echo -e "${YELLOW}⚠${NC} 사용자가 bluetooth 그룹에 속하지 않음"
    echo "   추가 방법: sudo usermod -a -G bluetooth $USER"
    echo "   (재로그인 필요)"
fi

echo ""

echo "=========================================="
echo "실시간 테스트 방법"
echo "=========================================="
echo ""
echo "터미널 1: 앱 실행 및 로그 확인"
echo "----------------------------------------"
echo -e "${YELLOW}cd /home/seame/DES_Head-Unit/Head-Unit${NC}"
echo -e "${YELLOW}build/HeadUnitApp 2>&1 | tee app.log${NC}"
echo ""
echo "다음 로그를 찾으세요:"
echo "  [BluetoothManager] Agent object registered at /com/des/headunit/bluetooth/agent"
echo "  [BluetoothManager] Agent registered with BlueZ AgentManager"
echo "  [BluetoothManager] Default agent set successfully"
echo ""

echo "터미널 2: D-Bus Agent 호출 모니터"
echo "----------------------------------------"
echo -e "${YELLOW}dbus-monitor --system \"interface='org.bluez.Agent1'\"${NC}"
echo ""
echo "페어링 시작 시 다음과 같은 메시지가 나타나야 함:"
echo "  method call ... interface=org.bluez.Agent1; member=RequestConfirmation"
echo "  method call ... interface=org.bluez.Agent1; member=RequestPinCode"
echo ""

echo "터미널 3: BlueZ 로그 확인"
echo "----------------------------------------"
echo -e "${YELLOW}journalctl -f -u bluetooth${NC}"
echo ""

echo "=========================================="
echo "페어링 시나리오 테스트"
echo "=========================================="
echo ""
echo "1. 앱에서 Bluetooth Settings 열기"
echo "2. 'Start Broadcasting' 클릭"
echo "3. 폰에서 Bluetooth 검색"
echo "4. PC/HeadUnit 선택"
echo ""
echo -e "${GREEN}예상 결과:${NC}"
echo "  - 터미널 1에 [BluetoothAgent] RequestConfirmation 로그"
echo "  - 터미널 2에 D-Bus method call 메시지"
echo "  - 앱 UI에 페어링 다이얼로그 나타남"
echo ""
echo -e "${RED}다이얼로그가 안나타나면:${NC}"
echo "  1. 터미널 1 로그 확인:"
echo "     - Agent 등록 실패 메시지가 있나?"
echo "     - 'Failed to register agent' 에러가 있나?"
echo ""
echo "  2. 터미널 2 D-Bus 모니터 확인:"
echo "     - Agent1 메소드 호출이 오나?"
echo "     - 안오면 BlueZ가 agent를 인식 못함"
echo ""
echo "  3. sudo로 실행 테스트:"
echo "     sudo build/HeadUnitApp"
echo "     (D-Bus 권한 문제인지 확인)"
echo ""

echo "=========================================="
echo "수동으로 Agent 테스트"
echo "=========================================="
echo ""
echo "BlueZ Agent가 등록되었는지 직접 확인:"
echo ""
echo -e "${YELLOW}# bluetoothctl에서 agent 확인${NC}"
echo "bluetoothctl"
echo "> agent off"
echo "> agent on"
echo "> default-agent"
echo ""
echo "그 후 앱 실행하면 'Agent already exists' 에러가 나와야 정상"
echo "(앱이 agent를 등록하려고 시도하는 것)"
echo ""

echo "=========================================="
echo "빠른 진단"
echo "=========================================="
echo ""
echo -e "${YELLOW}다음 명령으로 현재 등록된 agent 확인:${NC}"
echo "gdbus introspect --system --dest org.bluez --object-path /org/bluez/hci0"
echo ""
echo -e "${YELLOW}D-Bus에 HeadUnit agent가 등록되었는지 확인:${NC}"
echo "gdbus introspect --system --dest org.bluez --object-path /com/des/headunit/bluetooth/agent"
echo ""
