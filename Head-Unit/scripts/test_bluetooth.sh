#!/bin/bash

# Bluetooth 오디오 기능을 테스트하기 위한 빌드 및 실행 스크립트
# 사용법: ./scripts/test_bluetooth.sh

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "========================================"
echo "Head-Unit Bluetooth 테스트"
echo "========================================"
echo ""

# Qt 경로 확인
QT_PATH="/home/seame/Qt/6.9.3/gcc_64"
if [ ! -d "$QT_PATH" ]; then
    echo "⚠️  경고: Qt 경로를 찾을 수 없습니다: $QT_PATH"
    echo "Qt 설치 경로를 확인하고 스크립트를 수정하세요."
    exit 1
fi

# Bluetooth 서비스 확인
if ! systemctl is-active --quiet bluetooth; then
    echo "❌ Bluetooth 서비스가 실행되지 않습니다."
    echo "다음 명령으로 서비스를 시작하세요:"
    echo "  sudo systemctl start bluetooth"
    exit 1
fi

echo "✅ Bluetooth 서비스 실행 중"
echo ""

# 빌드
echo "[1/2] 프로젝트 빌드 중..."
BUILD_DIR="build/Desktop_Qt_6_9_3-Debug"

if [ "$1" == "--clean" ]; then
    echo "클린 빌드 수행 중..."
    rm -rf build/
fi

cmake -S . -B "$BUILD_DIR" \
    -DCMAKE_PREFIX_PATH="$QT_PATH" \
    -DCMAKE_BUILD_TYPE=Debug

cmake --build "$BUILD_DIR" -j$(nproc)

if [ ! -f "$BUILD_DIR/HeadUnitApp" ]; then
    echo "❌ 빌드 실패: HeadUnitApp을 찾을 수 없습니다."
    exit 1
fi

echo "✅ 빌드 완료"
echo ""

# 실행
echo "[2/2] 애플리케이션 실행 중..."
echo ""
echo "====== 디버그 로그 ======"

# Qt 및 D-Bus 디버깅 활성화
export QT_LOGGING_RULES="qt.bluetooth*=true"
export QT_DEBUG_PLUGINS=0

"$BUILD_DIR/HeadUnitApp"
