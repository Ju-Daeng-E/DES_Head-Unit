#!/bin/bash
# Comprehensive Weston + WiFi Fix
# This script applies all necessary fixes for weston.service failure and wlan0 down issue

set -e

echo "============================================"
echo "Weston Service + WiFi Fix Application"
echo "============================================"
echo ""

cd /home/seame/DES_Head-Unit

# Backup existing files
echo "📦 Creating backups..."
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service \
   yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service.backup_$(date +%Y%m%d_%H%M%S) || true

cp yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service \
   yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service.backup_$(date +%Y%m%d_%H%M%S) || true

echo "✅ Backups created"
echo ""

# Apply Weston fix
echo "🔧 Applying Weston service fix..."
cp yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service.fixed \
   yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service

echo "✅ Weston service updated"
echo ""

# Apply WiFi fix
echo "📡 Applying WiFi service fix..."
cp yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service.fixed \
   yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service

echo "✅ WiFi service updated"
echo ""

# Show what was changed
echo "============================================"
echo "Changes Applied:"
echo "============================================"
echo ""
echo "🔧 Weston Service Improvements:"
echo "  • Added XDG_RUNTIME_DIR environment"
echo "  • Added DRM device wait logic"
echo "  • Clean up stale sockets before start"
echo "  • Added /run directory creation"
echo "  • Increased timeouts for reliability"
echo "  • Added logging to /var/log/weston.log"
echo "  • Added SupplementaryGroups=video input render"
echo "  • Wait for multi-user.target"
echo "  • Condition on /dev/dri/card0 existence"
echo ""
echo "📡 WiFi Service Improvements:"
echo "  • Added timeout to prevent boot hang"
echo "  • Dynamic wlan* interface detection"
echo "  • Multiple unblock attempts"
echo "  • Non-blocking failure (won't stop boot)"
echo "  • Uses connmanctl as fallback"
echo ""

echo "============================================"
echo "Next Steps:"
echo "============================================"
echo ""
echo "1. Clean and rebuild:"
echo "   cd yocto-workspace"
echo "   . poky/oe-init-build-env build-des"
echo "   bitbake -c cleansstate weston-init wifi-auto-enable"
echo "   bitbake des-image"
echo ""
echo "2. Deploy to SD card"
echo ""
echo "3. Boot and check logs via serial console:"
echo "   journalctl -u weston.service -b"
echo "   journalctl -u wifi-auto-enable.service -b"
echo "   cat /var/log/weston.log"
echo ""

echo "✅ Fix application complete!"
echo ""

# Create a quick test file for serial console
cat > /tmp/weston_debug_serial.sh << 'EOF'
#!/bin/sh
# Run this on Raspberry Pi via serial console to debug Weston

echo "=== Weston Debug Information ==="
echo ""

echo "1. Weston service status:"
systemctl status weston.service --no-pager
echo ""

echo "2. DRM devices:"
ls -la /dev/dri/
echo ""

echo "3. TTY status:"
fgconsole
echo ""

echo "4. Wayland socket:"
ls -la /run/wayland-0 2>&1 || echo "Socket does not exist"
echo ""

echo "5. Weston log:"
tail -50 /var/log/weston.log 2>&1 || echo "Log file does not exist"
echo ""

echo "6. Recent Weston journal:"
journalctl -u weston.service -b --no-pager | tail -50
echo ""

echo "7. WiFi status:"
ip link show wlan0 2>&1 || echo "wlan0 not found"
connmanctl services 2>&1 || echo "connman not available"
echo ""

echo "8. rfkill status:"
rfkill list
echo ""
EOF

chmod +x /tmp/weston_debug_serial.sh

echo "📝 Created debug script: /tmp/weston_debug_serial.sh"
echo "   Copy this to SD card and run on Pi to get debug info"
echo ""
