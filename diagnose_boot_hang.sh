#!/bin/bash
# DES Boot Hang Diagnosis Script
# Run this on the Raspberry Pi via SSH to diagnose why the system hangs after Plymouth

echo "=============================================="
echo "  DES Boot Hang Diagnosis"
echo "=============================================="
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "1. Service Status Check"
echo "======================="
echo

# Check Weston socket
echo -n "weston.socket: "
if systemctl is-active --quiet weston.socket; then
    echo -e "${GREEN}ACTIVE${NC}"
else
    echo -e "${RED}INACTIVE/FAILED${NC}"
fi
systemctl status weston.socket --no-pager | head -15
echo

# Check Weston service
echo -n "weston.service: "
if systemctl is-active --quiet weston.service; then
    echo -e "${GREEN}ACTIVE${NC}"
else
    echo -e "${RED}INACTIVE/FAILED${NC}"
fi
systemctl status weston.service --no-pager | head -15
echo

# Check HeadUnit
echo -n "headunit.service: "
if systemctl is-active --quiet headunit.service; then
    echo -e "${GREEN}ACTIVE${NC}"
else
    echo -e "${RED}INACTIVE/FAILED${NC}"
fi
systemctl status headunit.service --no-pager | head -15
echo

# Check IC
echo -n "instrument-cluster.service: "
if systemctl is-active --quiet instrument-cluster.service; then
    echo -e "${GREEN}ACTIVE${NC}"
else
    echo -e "${RED}INACTIVE/FAILED${NC}"
fi
systemctl status instrument-cluster.service --no-pager | head -15
echo

echo "2. Critical File Existence Check"
echo "================================="
echo

# Check Wayland socket
if [ -S /run/wayland-0 ]; then
    echo -e "${GREEN}✓${NC} /run/wayland-0 exists (socket)"
    ls -la /run/wayland-0
else
    echo -e "${RED}✗${NC} /run/wayland-0 NOT FOUND or not a socket"
fi
echo

# Check weston.ini
if [ -f /etc/xdg/weston/weston.ini ]; then
    echo -e "${GREEN}✓${NC} /etc/xdg/weston/weston.ini exists"
    echo "First 10 lines:"
    head -10 /etc/xdg/weston/weston.ini
else
    echo -e "${RED}✗${NC} /etc/xdg/weston/weston.ini NOT FOUND"
fi
echo

# Check weston defaults
if [ -f /etc/default/weston ]; then
    echo -e "${GREEN}✓${NC} /etc/default/weston exists"
    cat /etc/default/weston
else
    echo -e "${YELLOW}⚠${NC} /etc/default/weston NOT FOUND (may be optional)"
fi
echo

# Check app binaries
if [ -x /usr/bin/HeadUnitApp ]; then
    echo -e "${GREEN}✓${NC} /usr/bin/HeadUnitApp exists and is executable"
else
    echo -e "${RED}✗${NC} /usr/bin/HeadUnitApp NOT FOUND or not executable"
fi

if [ -x /usr/bin/appIC ]; then
    echo -e "${GREEN}✓${NC} /usr/bin/appIC exists and is executable"
else
    echo -e "${RED}✗${NC} /usr/bin/appIC NOT FOUND or not executable"
fi
echo

echo "3. TTY and Plymouth Status"
echo "=========================="
echo

# Check TTY7
echo "TTY7 status:"
if fuser /dev/tty7 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC} /dev/tty7 is being used by:"
    fuser -v /dev/tty7 2>&1
else
    echo -e "${GREEN}✓${NC} /dev/tty7 is free"
fi
echo

# Check Plymouth processes
if pgrep -a plymouth >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Plymouth processes still running:"
    pgrep -a plymouth
else
    echo -e "${GREEN}✓${NC} No Plymouth processes running"
fi
echo

echo "4. Running Processes"
echo "===================="
echo

echo "Weston processes:"
ps aux | grep weston | grep -v grep || echo "  None"
echo

echo "HeadUnitApp processes:"
ps aux | grep HeadUnitApp | grep -v grep || echo "  None"
echo

echo "appIC processes:"
ps aux | grep appIC | grep -v grep || echo "  None"
echo

echo "5. Failed Services"
echo "=================="
echo

if systemctl --failed --no-pager | grep -q "0 loaded units"; then
    echo -e "${GREEN}✓${NC} No failed services"
else
    echo -e "${RED}✗${NC} Failed services found:"
    systemctl --failed --no-pager
fi
echo

echo "6. System Target Status"
echo "======================="
echo

echo "Current system state:"
systemctl is-system-running
echo

echo "graphical.target status:"
systemctl status graphical.target --no-pager | head -20
echo

echo "7. Recent Relevant Logs (last 50 lines)"
echo "========================================"
echo

echo "--- Weston logs ---"
journalctl -u weston.service -n 30 --no-pager
echo

echo "--- Weston socket logs ---"
journalctl -u weston.socket -n 20 --no-pager
echo

echo "--- HeadUnit logs ---"
journalctl -u headunit.service -n 30 --no-pager
echo

echo "--- IC logs ---"
journalctl -u instrument-cluster.service -n 30 --no-pager
echo

echo "--- Plymouth quit timer logs ---"
journalctl -u plymouth-quit-timer.service -n 20 --no-pager
echo

echo "8. Dependency Analysis"
echo "======================"
echo

echo "graphical.target dependencies:"
systemctl list-dependencies graphical.target --no-pager | head -30
echo

echo "weston.service dependencies:"
systemctl list-dependencies weston.service --no-pager
echo

echo "=============================================="
echo "  Diagnosis Complete"
echo "=============================================="
echo

echo "Next steps:"
echo "1. Review the output above"
echo "2. Look for RED ✗ marks indicating problems"
echo "3. Check service status (ACTIVE vs INACTIVE/FAILED)"
echo "4. Review logs for error messages"
echo "5. Save this output: ./diagnose_boot_hang.sh > /tmp/diagnosis.txt"
