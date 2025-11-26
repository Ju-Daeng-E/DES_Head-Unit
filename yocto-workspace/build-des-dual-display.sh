#!/bin/bash
# DES Dual Display Build Script
# This script rebuilds the Yocto image with eglfs support for independent display output

set -e

echo "=================================="
echo "DES Dual Display Image Build"
echo "=================================="

cd "$(dirname "$0")"

# Source Yocto environment
echo "Sourcing Yocto environment..."
. poky/oe-init-build-env build-des

echo ""
echo "Cleaning previous builds..."
bitbake -c cleansstate headunit instrument-cluster weston-init rpi-config

echo ""
echo "Building des-image with eglfs support..."
bitbake des-image

echo ""
echo "=================================="
echo "Build Complete!"
echo "=================================="
echo ""
echo "Image location:"
echo "  build-des/tmp-glibc/deploy/images/raspberrypi4-64/"
echo ""
echo "Key changes in this build:"
echo "  ✓ Qt eglfs plugins added (direct DRM rendering)"
echo "  ✓ HeadUnit → HDMI-A-1 via /etc/headunit-kms.json"
echo "  ✓ Instrument Cluster → HDMI-A-2 via /etc/cluster-kms.json"
echo "  ✓ GPU memory: 128MB (power optimized)"
echo "  ✓ HDMI boost: 2 (reduced from 7 for power efficiency)"
echo "  ✓ Weston disabled (apps use direct DRM instead)"
echo ""
echo "Flash to SD card:"
echo "  sudo dd if=des-image-raspberrypi4-64.wic of=/dev/sdX bs=4M status=progress && sync"
echo ""
