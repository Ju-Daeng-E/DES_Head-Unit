#!/bin/bash
# Weston 즉시 수정 스크립트
# weston.service 실패 문제를 완전히 해결합니다

set -e

echo "=========================================="
echo "Weston Service 긴급 수정"
echo "=========================================="
echo ""

cd /home/seame/DES_Head-Unit

# 백업 생성
echo "📦 기존 파일 백업 중..."
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service \
   yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service.backup_${BACKUP_TIME}
echo "✅ 백업 완료: weston.service.backup_${BACKUP_TIME}"
echo ""

# 수정된 파일 적용
echo "🔧 수정된 weston.service 적용 중..."
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service.fixed-complete \
   yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service

echo "✅ weston.service 업데이트 완료"
echo ""

# 변경 사항 표시
echo "=========================================="
echo "적용된 수정 사항:"
echo "=========================================="
echo ""
echo "✅ 1. Plymouth 의존성 추가"
echo "   - After=plymouth-quit-timer.service"
echo "   - DRM 충돌 방지"
echo ""
echo "✅ 2. 환경 변수 설정"
echo "   - XDG_RUNTIME_DIR=/run"
echo "   - XDG_SESSION_TYPE=wayland"
echo ""
echo "✅ 3. DRM 장치 체크"
echo "   - ConditionPathExists=/dev/dri/card0"
echo "   - ExecStartPre에서 DRM 대기"
echo ""
echo "✅ 4. Wayland 소켓 정리"
echo "   - 시작 전 /run/wayland-0 제거"
echo "   - 시작 후 소켓 생성 확인"
echo ""
echo "✅ 5. 설정 파일 명시"
echo "   - --config=/etc/xdg/weston/weston.ini"
echo "   - --log=/var/log/weston.log"
echo ""
echo "✅ 6. TTY 설정"
echo "   - TTYPath=/dev/tty7"
echo "   - TTY 리셋 및 할당 해제"
echo ""
echo "✅ 7. 재시작 정책"
echo "   - Restart=on-failure"
echo "   - 최대 5번 재시도"
echo ""
echo "✅ 8. 그룹 권한"
echo "   - SupplementaryGroups=video input render"
echo ""
echo "✅ 9. 타임아웃"
echo "   - TimeoutStartSec=30"
echo "   - StartLimitBurst=5"
echo ""

echo "=========================================="
echo "다음 단계:"
echo "=========================================="
echo ""
echo "1. 이미지 재빌드:"
echo "   cd yocto-workspace"
echo "   . poky/oe-init-build-env build-des"
echo "   bitbake -c cleansstate weston-init"
echo "   bitbake des-image"
echo ""
echo "2. SD 카드에 배포"
echo ""
echo "3. 라즈베리파이 부팅 후 확인:"
echo "   systemctl status weston.service"
echo "   journalctl -u weston.service -b"
echo "   ls -la /run/wayland-0"
echo "   cat /var/log/weston.log"
echo ""

echo "=========================================="
echo "진단 스크립트:"
echo "=========================================="
echo ""
echo "라즈베리파이에서 문제 확인용 스크립트를 생성합니다..."

# 라즈베리파이용 진단 스크립트 생성
cat > /tmp/check_weston_on_pi.sh << 'EOFPI'
#!/bin/bash
# 라즈베리파이에서 실행하세요

echo "=========================================="
echo "Weston 상태 확인"
echo "=========================================="
echo ""

echo "1. 서비스 상태:"
systemctl status weston.service --no-pager -l
echo ""

echo "2. 최근 로그:"
journalctl -u weston.service -n 50 --no-pager
echo ""

echo "3. Weston 로그 파일:"
if [ -f /var/log/weston.log ]; then
    echo "--- /var/log/weston.log (마지막 30줄) ---"
    tail -30 /var/log/weston.log
else
    echo "❌ /var/log/weston.log 파일 없음"
fi
echo ""

echo "4. DRM 장치:"
ls -la /dev/dri/
echo ""

echo "5. Wayland 소켓:"
ls -la /run/wayland* 2>&1 || echo "❌ Wayland 소켓 없음"
echo ""

echo "6. 현재 TTY:"
fgconsole 2>&1 || echo "명령어 없음"
echo ""

echo "7. Weston 프로세스:"
ps aux | grep -E "[w]eston" || echo "❌ Weston 프로세스 없음"
echo ""

echo "8. 앱 서비스 상태:"
echo "--- Head-Unit ---"
systemctl status headunit.service --no-pager | head -10
echo ""
echo "--- Instrument Cluster ---"
systemctl status instrument-cluster.service --no-pager | head -10
echo ""

echo "=========================================="
echo "진단 완료"
echo "=========================================="
EOFPI

chmod +x /tmp/check_weston_on_pi.sh

echo "✅ 진단 스크립트 생성 완료: /tmp/check_weston_on_pi.sh"
echo "   이 파일을 SD 카드에 복사해서 라즈베리파이에서 실행하세요"
echo ""

echo "=========================================="
echo "즉시 테스트 (현재 시스템):"
echo "=========================================="
echo ""
echo "현재 weston.service 내용 확인:"
echo "---"
head -20 yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service
echo "..."
echo ""

echo "✅ 수정 완료!"
echo ""
echo "이제 bitbake로 재빌드하세요."
