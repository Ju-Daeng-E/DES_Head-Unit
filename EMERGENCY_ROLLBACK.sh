#!/bin/bash
# EMERGENCY: Rollback to minimal safe configuration
# This removes ALL optimizations and returns to basic working config

set -e

echo "============================================"
echo "EMERGENCY ROLLBACK - Minimal Safe Config"
echo "============================================"
echo ""

cd /home/seame/DES_Head-Unit

# Backup current broken config
echo "📦 Backing up broken configuration..."
mkdir -p backups/emergency_$(date +%Y%m%d_%H%M%S)
cp -r yocto-workspace/meta-custom backups/emergency_$(date +%Y%m%d_%H%M%S)/ || true
echo "✅ Backup created"
echo ""

# REVERT Weston to absolute minimum
echo "🔧 Creating MINIMAL weston.service..."
cat > yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service << 'EOF'
[Unit]
Description=Weston Wayland Compositor (Minimal Safe)
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/weston
Restart=no
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF

echo "✅ Minimal weston.service created"
echo ""

# DISABLE Plymouth completely
echo "🔧 DISABLING Plymouth..."
cat > yocto-workspace/meta-custom/meta-env/recipes-bsp/bootfiles/rpi-cmdline.bbappend << 'EOF'
# Minimal boot - NO PLYMOUTH
# Just serial console for debugging
CMDLINE_SERIAL = "console=serial0,115200 console=tty1"
CMDLINE:append = " quiet loglevel=3"
EOF

echo "✅ Plymouth disabled"
echo ""

# DISABLE WiFi auto-enable
echo "📡 Disabling WiFi auto-enable..."
cat > yocto-workspace/meta-custom/meta-env/recipes-connectivity/wifi-auto-enable/files/wifi-auto-enable.service << 'EOF'
[Unit]
Description=WiFi Auto-Enable (Disabled)

[Service]
Type=oneshot
ExecStart=/bin/true
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "✅ WiFi service disabled"
echo ""

# Create minimal weston.ini
echo "🔧 Creating minimal weston.ini..."
cat > yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini << 'EOF'
[core]
backend=drm-backend.so
shell=desktop-shell.so
EOF

echo "✅ Minimal weston.ini created"
echo ""

# Disable instrument cluster temporarily
echo "⚠️  Temporarily disabling Instrument Cluster..."
cat > yocto-workspace/meta-custom/meta-app/recipes-des/instrument-cluster/files/instrument-cluster.service << 'EOF'
[Unit]
Description=Instrument Cluster (Temporarily Disabled)

[Service]
Type=oneshot
ExecStart=/bin/true
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF

echo "✅ IC disabled"
echo ""

# Simplify headunit service
echo "🔧 Simplifying HeadUnit service..."
cat > yocto-workspace/meta-custom/meta-app/recipes-des/headunit/files/headunit.service << 'EOF'
[Unit]
Description=Head Unit Application (Minimal)
After=weston.service

[Service]
Type=simple
Environment=QT_QPA_PLATFORM=wayland
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/HeadUnitApp
Restart=no
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF

echo "✅ HeadUnit simplified"
echo ""

echo "============================================"
echo "Rollback Complete - Configuration Summary"
echo "============================================"
echo ""
echo "Changes:"
echo "  • Weston: Absolute minimum (no options)"
echo "  • Plymouth: DISABLED"
echo "  • WiFi auto-enable: DISABLED"
echo "  • Instrument Cluster: DISABLED (for debugging)"
echo "  • HeadUnit: Simplified"
echo ""
echo "This configuration should boot to:"
echo "  1. TTY1 console (no Plymouth)"
echo "  2. Weston on tty7 (basic)"
echo "  3. HeadUnit only (IC disabled)"
echo ""
echo "============================================"
echo "Next Steps:"
echo "============================================"
echo ""
echo "1. Rebuild with minimal config:"
echo "   cd yocto-workspace"
echo "   . poky/oe-init-build-env build-des"
echo "   bitbake -c cleansstate rpi-cmdline plymouth weston-init headunit instrument-cluster wifi-auto-enable"
echo "   bitbake des-image"
echo ""
echo "2. Deploy to SD card"
echo ""
echo "3. Boot should show:"
echo "   - Kernel messages"
echo "   - TTY1 login"
echo "   - System responsive (can switch TTY)"
echo ""
echo "4. Check logs via TTY1:"
echo "   root (login)"
echo "   journalctl -xe | tail -100"
echo ""
echo "✅ Emergency rollback ready!"
echo ""
