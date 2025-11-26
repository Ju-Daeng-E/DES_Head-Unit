# 동기화 완료 요약

## ✅ 완료된 작업

### 1. 작동하는 라즈베리파이에서 파일 추출
- IP: 192.168.86.48
- 모든 서비스 active 상태 확인

### 2. 동기화된 파일들

#### weston.service
- **소스**: /usr/lib/systemd/system/weston.service (Pi)
- **대상**: yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service
- **핵심 차이점**:
  - User=weston, Group=weston (not root)
  - Type=notify (not simple)
  - ExecStartPre=/bin/sleep 3
  - After=plymouth-quit-wait.service
  - --continue-without-input --modules=systemd-notify.so
  - PAMName=weston-autologin

#### headunit.service
- **소스**: /usr/lib/systemd/system/headunit.service (Pi)
- **대상**: yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit.service
- **핵심**: ExecStartPre=/bin/sleep 2, SupplementaryGroups=wayland

#### instrument-cluster.service
- **소스**: /usr/lib/systemd/system/instrument-cluster.service (Pi)
- **대상**: DES_Instrument-Cluster/systemd/instrument-cluster.service
- **핵심**: After=headunit.service (순차 시작), ExecStartPre=/bin/sleep 3

#### weston.ini
- **소스**: /etc/xdg/weston/weston.ini (Pi)
- **대상**: yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini
- **핵심**: require-input=true, app-ids 설정, cursor-size=0

### 3. 백업된 파일들
모든 원본 파일은 `.before_sync` 확장자로 백업됨

## 📋 현재 상태

### 작동하는 것 (Pi):
- ✅ Weston 실행
- ✅ Head-Unit 표시
- ✅ Instrument Cluster 표시
- ✅ 듀얼 디스플레이 작동

### 작동 안하는 것 (Pi):
- ❌ Plymouth 부팅 영상 깨짐

## 🔨 다음 단계

### 1. Yocto 재빌드
```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleansstate weston-init headunit instrument-cluster
bitbake des-image
```

### 2. SD 카드에 배포
```bash
sudo umount /dev/sdb*
sudo bzcat build-des/tmp-glibc/deploy/images/raspberrypi4-64/des-image-raspberrypi4-64.rootfs.wic.bz2 | sudo dd of=/dev/sdb bs=4M status=progress
sync
```

### 3. Plymouth 부팅 영상 수정 (별도 작업)
- des 테마 확인 필요
- des.script 검증
- 프레임 이미지 확인

## 📊 예상 결과

재빌드 후:
- ✅ Weston 안정적으로 시작
- ✅ 두 앱 모두 표시됨
- ✅ 깜빡임 없음
- ✅ TTY switching 없음
- ❌ Plymouth 영상은 여전히 깨짐 (별도 수정 필요)
