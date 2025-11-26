#!/bin/bash
set -e

echo "=========================================="
echo "완전 클린 빌드 - Bluetooth 기능"
echo "=========================================="
echo ""

# Yocto 환경 설정
cd /home/seame/DES_Head-Unit/yocto-workspace
. poky/oe-init-build-env build-des

echo "1. 영향받은 패키지 완전 클린..."
echo ""

# headunit 완전 클린
echo "  - headunit 클린 중..."
bitbake -c cleanall headunit
echo "    ✅ headunit 클린 완료"
echo ""

# bluez5 완전 클린
echo "  - bluez5 클린 중..."
bitbake -c cleanall bluez5
echo "    ✅ bluez5 클린 완료"
echo ""

# 선택적: shared-state 캐시 정리
echo "2. (선택) Shared state 캐시 정리..."
echo "  - headunit sstate 삭제 중..."
rm -rf tmp-glibc/sstate-control/*headunit* 2>/dev/null || true
echo "  - bluez5 sstate 삭제 중..."
rm -rf tmp-glibc/sstate-control/*bluez5* 2>/dev/null || true
echo "    ✅ 캐시 정리 완료"
echo ""

echo "3. 이미지 빌드 시작..."
echo "  ⏳ 이 작업은 30-60분 소요될 수 있습니다..."
echo ""

# 전체 이미지 빌드
bitbake des-image

echo ""
echo "=========================================="
echo "빌드 완료!"
echo "=========================================="
echo ""
echo "이미지 위치:"
echo "  build-des/tmp-glibc/deploy/images/raspberrypi4-64/"
echo ""
echo "다음 단계:"
echo "  1. SD 카드 플래싱"
echo "  2. 라즈베리파이 부팅"
echo "  3. Bluetooth 테스트"
echo ""
