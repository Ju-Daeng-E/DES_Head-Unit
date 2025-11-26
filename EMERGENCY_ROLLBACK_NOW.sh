#!/bin/bash
# 긴급 롤백: 가장 단순하고 안전한 버전으로
set -e

echo "=========================================="
echo "🚨 긴급 롤백"
echo "=========================================="
echo ""

cd /home/seame/DES_Head-Unit

# 백업
echo "📦 현재 버전 백업..."
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service \
   yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service.broken_$(date +%Y%m%d_%H%M%S)

# 가장 오래된 작동하던 버전으로 복원
echo "🔄 안전한 버전으로 복원 중..."
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service.backup_20251126_132914 \
   yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service

echo "✅ 복원 완료"
echo ""

echo "=========================================="
echo "복원된 버전:"
echo "=========================================="
cat yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service
echo ""

echo "=========================================="
echo "이제 재빌드하세요:"
echo "=========================================="
echo ""
echo "cd yocto-workspace"
echo ". poky/oe-init-build-env build-des"
echo "bitbake -c cleansstate weston-init"
echo "bitbake des-image"
echo ""
