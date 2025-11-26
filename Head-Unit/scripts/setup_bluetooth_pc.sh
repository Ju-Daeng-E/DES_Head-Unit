#!/bin/bash

# Bluetooth 오디오 테스트를 위한 Linux PC 자동 설정 스크립트
# 사용법: sudo ./scripts/setup_bluetooth_pc.sh

set -e

echo "========================================"
echo "Bluetooth Audio 테스트 환경 설정"
echo "========================================"
echo ""

# Root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo "❌ 오류: 이 스크립트는 root 권한이 필요합니다."
    echo "사용법: sudo $0"
    exit 1
fi

# 1. 필수 패키지 설치
echo "[1/6] 필수 패키지 설치 중..."
apt-get update -qq
apt-get install -y \
    bluez \
    bluez-tools \
    pulseaudio-module-bluetooth \
    pavucontrol \
    d-feet \
    dbus-x11 \
    > /dev/null 2>&1

echo "✅ 패키지 설치 완료"

# 2. BlueZ 설정
echo "[2/6] BlueZ 설정 중..."
cat > /etc/bluetooth/main.conf <<'EOF'
[General]
# 클래스: Audio/Video (Computer)
Class = 0x200420

# 디스커버블 & 페어러블 (무제한)
DiscoverableTimeout = 0
PairableTimeout = 0

[Policy]
# 자동 재연결
AutoEnable = true
EOF

echo "✅ BlueZ 설정 완료"

# 3. 현재 사용자를 bluetooth 그룹에 추가
REAL_USER=$(logname)
echo "[3/6] 사용자 '$REAL_USER'를 bluetooth 그룹에 추가 중..."
usermod -a -G bluetooth "$REAL_USER"
echo "✅ 사용자 그룹 설정 완료"

# 4. PulseAudio 설정
echo "[4/6] PulseAudio 설정 중..."
USER_HOME=$(eval echo ~$REAL_USER)
mkdir -p "$USER_HOME/.config/pulse"

cat > "$USER_HOME/.config/pulse/default.pa" <<'EOF'
.include /etc/pulse/default.pa

# Bluetooth 자동 전환
load-module module-switch-on-connect
EOF

chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config/pulse"
echo "✅ PulseAudio 설정 완료"

# 5. BlueZ 서비스 재시작
echo "[5/6] BlueZ 서비스 재시작 중..."
systemctl restart bluetooth
systemctl enable bluetooth > /dev/null 2>&1
echo "✅ BlueZ 서비스 활성화 완료"

# 6. 설정 확인
echo "[6/6] 설정 확인 중..."
sleep 2

if systemctl is-active --quiet bluetooth; then
    echo "✅ Bluetooth 서비스: 실행 중"
else
    echo "❌ Bluetooth 서비스: 실행되지 않음"
fi

if groups "$REAL_USER" | grep -q bluetooth; then
    echo "✅ 사용자 그룹: bluetooth 그룹에 속함"
else
    echo "❌ 사용자 그룹: bluetooth 그룹에 속하지 않음"
fi

echo ""
echo "========================================"
echo "✅ 설정 완료!"
echo "========================================"
echo ""
echo "다음 단계:"
echo "1. 로그아웃 후 다시 로그인 (또는 재부팅)"
echo "2. PulseAudio 재시작: pulseaudio -k && pulseaudio --start"
echo "3. PC를 디스커버블 모드로 설정:"
echo "   $ bluetoothctl"
echo "   [bluetooth]# power on"
echo "   [bluetooth]# agent on"
echo "   [bluetooth]# discoverable on"
echo "   [bluetooth]# pairable on"
echo ""
echo "4. Head-Unit 앱 실행:"
echo "   $ cd ~/Head-Unit"
echo "   $ ./build/Desktop_Qt_6_9_3-Debug/HeadUnitApp"
echo ""
echo "자세한 내용은 BLUETOOTH_TESTING_GUIDE.md를 참고하세요."
