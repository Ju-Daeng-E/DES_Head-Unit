# Bluetooth Discoverable Button Fix

## Problem
The Qt app's "Make Discoverable" button didn't work when clicked. Users had to manually run `bluetoothctl discoverable on` in the terminal to make the Raspberry Pi visible to phones for pairing.

## Root Cause
The `BluetoothManager::startBroadcasting()` function was using QtBluetooth's `setHostMode(QBluetoothLocalDevice::HostDiscoverable)` API, which doesn't properly interface with BlueZ on embedded Linux systems like Raspberry Pi.

## Solution
Replaced QtBluetooth API calls with direct BlueZ D-Bus interface calls in both `startBroadcasting()` and `stopBroadcasting()` functions.

### Changes Made

**File**: `Head-Unit/src/backend/bluetooth/bluetooth_manager.cpp`

#### 1. Added QDBusVariant include (line 11)
```cpp
#include <QDBusVariant>
```

#### 2. Rewrote startBroadcasting() (lines 159-210)
Now uses BlueZ D-Bus to:
- Set `Discoverable` property to `true`
- Set `Pairable` property to `true`
- Set `DiscoverableTimeout` to `0` (infinite, won't auto-disable)

The function now does the same as `bluetoothctl discoverable on`.

#### 3. Rewrote stopBroadcasting() (lines 212-239)
Now uses BlueZ D-Bus to:
- Set `Discoverable` property to `false`

The function now does the same as `bluetoothctl discoverable off`.

### Technical Details

**BlueZ D-Bus Interface Used**:
- Service: `org.bluez`
- Object Path: `/org/bluez/hci0`
- Interface: `org.freedesktop.DBus.Properties`
- Method: `Set`
- Target Interface: `org.bluez.Adapter1`
- Properties Modified: `Discoverable`, `Pairable`, `DiscoverableTimeout`

## Building the Updated Image

### Option 1: Full Yocto Build
```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleanall headunit
bitbake des-image
```

### Option 2: Quick Headunit-Only Rebuild
```bash
cd yocto-workspace
. poky/oe-init-build-env build-des
bitbake -c cleanall headunit
bitbake headunit
```

Then manually copy the updated binary to Raspberry Pi:
```bash
scp tmp-glibc/work/cortexa72-poky-linux/headunit/1.0/image/usr/bin/HeadUnitApp root@192.168.86.22:/usr/bin/
ssh root@192.168.86.22 'systemctl restart headunit'
```

## Testing

1. **Flash the new image to SD card** (or use Option 2 for quick update)
2. **Boot Raspberry Pi and open Qt Head-Unit app**
3. **Navigate to Bluetooth Settings**
4. **Click "Make Discoverable" button**
5. **Expected result**:
   - Console shows: `[BluetoothManager] ✅ Device is now discoverable and pairable`
   - iPhone/Android Bluetooth settings should immediately show "raspberrypi4-64" or your device name
6. **Pair from phone**:
   - Select the device on phone
   - Accept 6-digit pairing code on both devices
7. **Connection**:
   - Device should automatically connect after pairing
   - Audio profile (A2DP Source) should activate
   - Phone music can now stream to Raspberry Pi speakers

## Verification Commands (SSH to Raspberry Pi)

Check if discoverable mode is active:
```bash
dbus-send --system --print-reply \
  --dest=org.bluez \
  /org/bluez/hci0 \
  org.freedesktop.DBus.Properties.Get \
  string:org.bluez.Adapter1 string:Discoverable
```

Should return: `boolean true` when discoverable button is active.

## Expected Log Output

When clicking "Make Discoverable" in Qt app:
```
[BluetoothManager] Starting broadcast mode - discoverable and pairable
[BluetoothManager] ✅ Device is now discoverable and pairable
[BluetoothManager] Visible as: raspberrypi4-64
[BluetoothManager] Pair from your phone to connect
```

## Success Criteria

- ✅ Clicking "Make Discoverable" button makes device visible on phone without terminal commands
- ✅ Phone can initiate pairing directly from Bluetooth settings
- ✅ Pairing completes with automatic yes/no prompts
- ✅ Audio connection establishes after pairing
- ✅ Phone music streams to Raspberry Pi via A2DP
- ✅ Volume control works via Qt app slider
