#!/bin/bash
set -e

echo "========================================"
echo "Bluetooth 자동 페어링 테스트"
echo "========================================"
echo ""

# 모든 방해 요소 제거
sudo killall -9 bluetoothctl 2>/dev/null || true
sudo systemctl restart bluetooth
sleep 2

# iPhone 페어링 완전 삭제
sudo bluetoothctl << EOF
remove F0:C7:25:35:91:E8
remove 48:BC:E1:18:C6:0F
exit
EOF

sleep 1

echo ""
echo "========================================"
echo "앱 시작 - 자동 페어링 모드"
echo "========================================"
echo ""
echo "1. 앱에서 'Start Broadcasting' 클릭"
echo "2. iPhone에서 'SEAME2025' 선택"
echo "3. 자동으로 페어링됨 (6자리 숫자 없이)"
echo ""

cd /home/seame/DES_Head-Unit/Head-Unit
sudo build/HeadUnitApp
