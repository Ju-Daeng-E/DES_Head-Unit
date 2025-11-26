#!/bin/bash
# Script to check weston.service configuration and likely failure causes
# Run this on your development machine

echo "============================================"
echo "Weston Service Failure Diagnostic Script"
echo "============================================"
echo ""

echo "📁 Checking weston.service configuration..."
echo ""

WESTON_SERVICE="yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.service"

if [ -f "$WESTON_SERVICE" ]; then
    echo "✅ weston.service found"
    echo ""
    echo "🔍 Service configuration:"
    cat "$WESTON_SERVICE"
    echo ""
else
    echo "❌ weston.service NOT FOUND"
    exit 1
fi

echo "============================================"
echo "Checking for common failure causes:"
echo "============================================"
echo ""

# Check 1: EnvironmentFile
echo "1️⃣ Checking EnvironmentFile configuration..."
if grep -q "EnvironmentFile=" "$WESTON_SERVICE"; then
    ENV_FILE=$(grep "EnvironmentFile=" "$WESTON_SERVICE" | cut -d'=' -f2)
    echo "   Found: $ENV_FILE"

    if [[ "$ENV_FILE" == "-"* ]]; then
        echo "   ✅ Optional file (- prefix) - OK"
    else
        echo "   ⚠️  Required file - might not exist on target!"
        echo "   → Check if /etc/default/weston exists on deployed image"
    fi
else
    echo "   ℹ️  No EnvironmentFile configured"
fi
echo ""

# Check 2: TTY configuration
echo "2️⃣ Checking TTY configuration..."
if grep -q "TTYPath=" "$WESTON_SERVICE"; then
    TTY_PATH=$(grep "TTYPath=" "$WESTON_SERVICE" | cut -d'=' -f2)
    echo "   TTY: $TTY_PATH"
    echo "   ⚠️  Check if Plymouth releases this TTY properly"
fi
echo ""

# Check 3: User/Group
echo "3️⃣ Checking User/Group configuration..."
if grep -q "^User=" "$WESTON_SERVICE"; then
    USER=$(grep "^User=" "$WESTON_SERVICE" | cut -d'=' -f2)
    echo "   User: $USER"
else
    echo "   ⚠️  No User specified - will run as default"
fi

if grep -q "^Group=" "$WESTON_SERVICE"; then
    GROUP=$(grep "^Group=" "$WESTON_SERVICE" | cut -d'=' -f2)
    echo "   Group: $GROUP"
else
    echo "   ℹ️  No Group specified"
fi
echo ""

# Check 4: weston.ini existence
echo "4️⃣ Checking weston.ini..."
WESTON_INI="yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/weston.ini"
if [ -f "$WESTON_INI" ]; then
    echo "   ✅ weston.ini found"
    echo "   Backend: $(grep "backend=" "$WESTON_INI" | cut -d'=' -f2)"
else
    echo "   ❌ weston.ini NOT FOUND - CRITICAL!"
    echo "   → Weston will fail to start without config"
fi
echo ""

# Check 5: Dependencies
echo "5️⃣ Checking service dependencies..."
echo "   After:"
grep "^After=" "$WESTON_SERVICE" || echo "   (none)"
echo ""
echo "   Requires:"
grep "^Requires=" "$WESTON_SERVICE" || echo "   (none)"
echo ""
echo "   Wants:"
grep "^Wants=" "$WESTON_SERVICE" || echo "   (none)"
echo ""

# Check 6: weston.socket
echo "6️⃣ Checking weston.socket..."
WESTON_SOCKET="yocto-workspace/meta-custom/meta-env/recipes-graphics/wayland/weston-init/systemd/weston.socket"
if [ -f "$WESTON_SOCKET" ]; then
    echo "   ✅ weston.socket found"
    cat "$WESTON_SOCKET"
else
    echo "   ❌ weston.socket NOT FOUND"
fi
echo ""

echo "============================================"
echo "Likely Failure Causes:"
echo "============================================"
echo ""

echo "🔴 MOST LIKELY ISSUES:"
echo ""
echo "1. Missing /etc/default/weston file"
echo "   → weston.service has EnvironmentFile=/etc/default/weston"
echo "   → If file doesn't exist and no '-' prefix, service fails"
echo ""
echo "2. Plymouth not releasing TTY7"
echo "   → weston.service uses TTYPath=/dev/tty7"
echo "   → If Plymouth still holds it, Weston can't start"
echo ""
echo "3. Missing weston.ini"
echo "   → ExecStart uses --config=/etc/xdg/weston/weston.ini"
echo "   → If file not installed, Weston fails"
echo ""
echo "4. DRM/KMS access denied"
echo "   → Weston needs /dev/dri/card0 access"
echo "   → Check user/group permissions"
echo ""

echo "============================================"
echo "Next Steps:"
echo "============================================"
echo ""
echo "Choose one:"
echo ""
echo "A) If you have serial console access:"
echo "   1. Boot the Pi"
echo "   2. When you see TTY1 login, press Enter"
echo "   3. Login as root (no password usually)"
echo "   4. Run: journalctl -u weston.service -b | tail -50"
echo "   5. Send me the output"
echo ""
echo "B) If you can mount SD card on laptop:"
echo "   1. Insert SD card into laptop"
echo "   2. Mount the root partition"
echo "   3. Check these files exist:"
echo "      - /etc/default/weston"
echo "      - /etc/xdg/weston/weston.ini"
echo "      - /lib/systemd/system/weston.service"
echo "   4. Send me: cat <path-to-sd>/var/log/journal/*/system.journal | strings | grep weston"
echo ""
echo "C) Fix it blindly (recommended):"
echo "   → I'll create a fixed configuration now"
echo ""
