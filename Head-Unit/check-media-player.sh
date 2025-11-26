#!/bin/bash

echo "========================================"
echo "Bluetooth MediaPlayer 진단"
echo "========================================"
echo ""

DEVICE="/org/bluez/hci0/dev_F0_C7_25_35_91_E8"

echo "1. 현재 연결된 장치 확인..."
gdbus introspect --system --dest org.bluez --object-path "$DEVICE" 2>/dev/null | head -20
echo ""

echo "2. MediaPlayer 인터페이스 확인..."
gdbus introspect --system --dest org.bluez --object-path "$DEVICE" 2>/dev/null | grep -i "media"
echo ""

echo "3. 모든 MediaPlayer 객체 검색..."
gdbus call --system \
  --dest org.bluez \
  --object-path / \
  --method org.freedesktop.DBus.ObjectManager.GetManagedObjects \
  2>/dev/null | grep -i "player" | head -5
echo ""

echo "========================================"
echo "해결 방법:"
echo "========================================"
echo ""
echo "1. iPhone에서 음악 앱을 열고 아무 노래나 재생하세요"
echo "2. 음악이 재생되면 MediaPlayer가 자동으로 생성됩니다"
echo ""
echo "또는:"
echo ""
echo "BlueZ 설정 수정:"
echo "sudo nano /etc/bluetooth/main.conf"
echo ""
echo "다음 줄을 찾아서 주석 해제하고 수정:"
echo "Class = 0x240408"
echo ""
echo "그 다음:"
echo "sudo systemctl restart bluetooth"
echo ""
