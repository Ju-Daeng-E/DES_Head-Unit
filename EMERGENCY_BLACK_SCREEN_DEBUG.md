# 🚨 긴급 디버깅: 검은 화면 문제

## 즉시 실행할 명령어

SSH로 라즈베리 파이에 접속 후 아래 명령어를 순서대로 실행하세요.

### 1단계: 서비스 상태 확인

```bash
# 모든 관련 서비스 상태 한번에 확인
systemctl status weston.service
systemctl status headunit.service
systemctl status instrument-cluster.service
systemctl status piracer-controller.service
```

**예상 결과:**
- `active (running)` ✅ 정상
- `failed` ❌ 문제!
- `activating (start-pre)` ⚠️ 시작 중 멈춤

### 2단계: 실패 원인 확인

```bash
# 서비스 로그 확인
journalctl -u weston.service -n 50 --no-pager
journalctl -u headunit.service -n 50 --no-pager
journalctl -u instrument-cluster.service -n 50 --no-pager
```

**주의깊게 볼 것:**
- `Failed to start` - 시작 실패
- `timeout` - 타임아웃
- `No such file` - 파일 없음
- `Permission denied` - 권한 문제

### 3단계: Wayland 소켓 확인

```bash
# Weston이 생성한 소켓 존재 여부
ls -la /run/wayland-0

# 예상 출력:
# srwxrwxrwx 1 root root 0 Nov 25 10:00 /run/wayland-0
```

**만약 없으면:** Weston이 시작 안됨!

### 4단계: 프로세스 확인

```bash
# 실행 중인 프로세스 확인
ps aux | grep -E "weston|HeadUnit|appIC"

# 예상:
# root  234  weston
# root  456  HeadUnitApp
# root  567  appIC
```

## 🔍 일반적인 원인과 해결책

### 원인 1: ExecStartPre 타임아웃

**증상:**
```
Nov 25 10:00:05 raspberrypi4-64 systemd[1]: Starting Head Unit...
Nov 25 10:00:08 raspberrypi4-64 systemd[1]: headunit.service: Start-pre operation timed out. Terminating.
```

**문제:** Weston 소켓을 기다리다가 3초 타임아웃

**임시 해결:**
```bash
# Weston 먼저 수동 시작
systemctl start weston.service
sleep 2

# 앱들 시작
systemctl start headunit.service
systemctl start instrument-cluster.service
```

**영구 해결:** 타임아웃 늘리기 (아래 참조)

### 원인 2: Weston 시작 실패

**증상:**
```
Nov 25 10:00:05 raspberrypi4-64 weston[234]: fatal: failed to create display
```

**확인:**
```bash
# DRM 디바이스 존재 확인
ls -la /dev/dri/card*

# tty 확인
who
```

**해결:**
```bash
# Weston 재시작
systemctl restart weston.service

# 로그 확인
journalctl -u weston.service -f
```

### 원인 3: 권한 문제

**증상:**
```
Permission denied: /run/wayland-0
```

**해결:**
```bash
# 권한 확인
ls -la /run/wayland-0

# 권한 수정
chmod 777 /run/wayland-0
```

### 원인 4: 서비스 의존성 문제

**증상:** 서비스가 계속 `activating` 상태

**확인:**
```bash
# 의존성 트리 확인
systemctl list-dependencies headunit.service
systemctl list-dependencies instrument-cluster.service
```

**해결:** 서비스 파일 수정 (아래 참조)

## ⚡ 긴급 수정

### 수정 1: 타임아웃 늘리기

SSH에서 즉시 수정:

```bash
# Head-Unit 서비스 수정
sudo mkdir -p /etc/systemd/system/headunit.service.d
sudo cat > /etc/systemd/system/headunit.service.d/override.conf << 'EOF'
[Service]
TimeoutStartSec=30
ExecStartPre=
ExecStartPre=/bin/sh -c 'timeout 10 sh -c "while [ ! -S /run/wayland-0 ]; do sleep 0.1; done"'
EOF

# Instrument Cluster 서비스 수정
sudo mkdir -p /etc/systemd/system/instrument-cluster.service.d
sudo cat > /etc/systemd/system/instrument-cluster.service.d/override.conf << 'EOF'
[Service]
TimeoutStartSec=30
ExecStartPre=
ExecStartPre=/bin/sh -c 'timeout 10 sh -c "while [ ! -S /run/wayland-0 ]; do sleep 0.1; done"'
EOF

# 변경사항 적용
sudo systemctl daemon-reload
sudo systemctl restart headunit.service
sudo systemctl restart instrument-cluster.service
```

### 수정 2: Weston 먼저 완전히 시작되도록 보장

```bash
# Weston 서비스에 지연 추가
sudo mkdir -p /etc/systemd/system/weston.service.d
sudo cat > /etc/systemd/system/weston.service.d/override.conf << 'EOF'
[Service]
ExecStartPost=/bin/sleep 2
EOF

sudo systemctl daemon-reload
sudo systemctl restart weston.service
```

### 수정 3: 순차 시작으로 임시 복구

병렬 시작이 문제면 임시로 순차 시작:

```bash
# IC가 Head-Unit 이후 시작하도록
sudo mkdir -p /etc/systemd/system/instrument-cluster.service.d
sudo cat > /etc/systemd/system/instrument-cluster.service.d/override.conf << 'EOF'
[Unit]
After=weston.service headunit.service
[Service]
ExecStartPre=/bin/sleep 2
EOF

sudo systemctl daemon-reload
sudo reboot
```

## 🔧 완전한 롤백

모든 최적화를 취소하고 원래대로:

```bash
# 오버라이드 제거
sudo rm -rf /etc/systemd/system/headunit.service.d
sudo rm -rf /etc/systemd/system/instrument-cluster.service.d
sudo rm -rf /etc/systemd/system/weston.service.d

# 기본 서비스 파일로 복원
sudo systemctl daemon-reload
sudo systemctl restart weston.service
sudo systemctl restart headunit.service
sudo systemctl restart instrument-cluster.service
```

## 📋 디버그 정보 수집

아래 명령어로 전체 상태를 파일로 저장:

```bash
cat > /tmp/debug_report.sh << 'EOF'
#!/bin/bash
echo "=== System Status ===" > /tmp/debug.log
date >> /tmp/debug.log
echo >> /tmp/debug.log

echo "=== Service Status ===" >> /tmp/debug.log
systemctl status weston.service >> /tmp/debug.log 2>&1
systemctl status headunit.service >> /tmp/debug.log 2>&1
systemctl status instrument-cluster.service >> /tmp/debug.log 2>&1
echo >> /tmp/debug.log

echo "=== Weston Log ===" >> /tmp/debug.log
journalctl -u weston.service -n 50 --no-pager >> /tmp/debug.log 2>&1
echo >> /tmp/debug.log

echo "=== HeadUnit Log ===" >> /tmp/debug.log
journalctl -u headunit.service -n 50 --no-pager >> /tmp/debug.log 2>&1
echo >> /tmp/debug.log

echo "=== Instrument Cluster Log ===" >> /tmp/debug.log
journalctl -u instrument-cluster.service -n 50 --no-pager >> /tmp/debug.log 2>&1
echo >> /tmp/debug.log

echo "=== Wayland Socket ===" >> /tmp/debug.log
ls -la /run/wayland* >> /tmp/debug.log 2>&1
echo >> /tmp/debug.log

echo "=== Running Processes ===" >> /tmp/debug.log
ps aux | grep -E "weston|HeadUnit|appIC" >> /tmp/debug.log 2>&1
echo >> /tmp/debug.log

echo "=== Boot Time ===" >> /tmp/debug.log
systemd-analyze >> /tmp/debug.log 2>&1
echo >> /tmp/debug.log

echo "Done. Check /tmp/debug.log"
EOF

chmod +x /tmp/debug_report.sh
/tmp/debug_report.sh
cat /tmp/debug.log
```

## 🎯 단계별 트러블슈팅

### Step 1: Weston 확인

```bash
systemctl status weston.service
```

- **active (running)** → Step 2로
- **failed/inactive** → Weston 문제:
  ```bash
  journalctl -u weston.service -n 30
  systemctl restart weston.service
  ```

### Step 2: Wayland 소켓 확인

```bash
ls -la /run/wayland-0
```

- **존재함** → Step 3으로
- **없음** → Weston 재시작:
  ```bash
  systemctl restart weston.service
  sleep 2
  ls -la /run/wayland-0
  ```

### Step 3: 앱 수동 시작

```bash
# Head-Unit 시작
systemctl start headunit.service
sleep 2

# Instrument Cluster 시작
systemctl start instrument-cluster.service

# 상태 확인
systemctl status headunit.service
systemctl status instrument-cluster.service
```

### Step 4: 로그에서 에러 찾기

```bash
# 에러 키워드 검색
journalctl -b | grep -i "error\|fail\|fatal" | tail -20

# Qt 관련 에러
journalctl -b | grep -i "qt\|qml\|wayland" | tail -20
```

## 🚀 빠른 복구 시나리오

### 시나리오 A: Weston만 문제

```bash
systemctl restart weston.service
sleep 2
systemctl restart headunit.service instrument-cluster.service
```

### 시나리오 B: 타임아웃 문제

```bash
# 위의 "수정 1" 적용 후
systemctl daemon-reload
systemctl restart headunit.service instrument-cluster.service
```

### 시나리오 C: 전부 안됨

```bash
# 순차 시작으로 임시 복구
systemctl stop headunit.service instrument-cluster.service
systemctl start weston.service
sleep 3
systemctl start headunit.service
sleep 3
systemctl start instrument-cluster.service
```

## 📞 추가 도움

위의 모든 방법이 실패하면 아래 정보를 확인해주세요:

```bash
# 1. 부팅 시간 분석
systemd-analyze critical-chain graphical.target

# 2. 실패한 서비스 목록
systemctl --failed

# 3. 전체 부팅 로그
journalctl -b | less

# 4. DRM/그래픽 확인
ls -la /dev/dri/
dmesg | grep -i drm
```
