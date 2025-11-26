#!/bin/bash
set -e

echo "Applying Bluetooth audio fix..."

# Add bluetooth modules to pulseaudio system config
echo "" | sudo tee -a /etc/pulse/system.pa
echo "load-module module-bluetooth-policy" | sudo tee -a /etc/pulse/system.pa
echo "load-module module-bluetooth-discover" | sudo tee -a /etc/pulse/system.pa
echo "load-module module-bluez5-discover" | sudo tee -a /etc/pulse/system.pa

# Add bluetooth modules to pulseaudio user config
echo "" | sudo tee -a /etc/pulse/default.pa
echo "load-module module-bluetooth-policy" | sudo tee -a /etc/pulse/default.pa
echo "load-module module-bluetooth-discover" | sudo tee -a /etc/pulse/default.pa
echo "load-module module-bluez5-discover" | sudo tee -a /etc/pulse/default.pa

# Restart pulseaudio and bluetooth
echo "Restarting services..."
pulseaudio -k
pulseaudio --start
sudo systemctl restart bluetooth

echo "Fix applied. Please try connecting your bluetooth device again."
