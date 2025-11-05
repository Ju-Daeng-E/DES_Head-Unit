SUMMARY = "DES Head-Unit base image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
inherit core-image
inherit sdcard_image-rpi
BOOT_SPACE = "98304"
IMAGE_FEATURES += "ssh-server-openssh package-management"
IMAGE_INSTALL:append = " \
    packagegroup-core-buildessential \
    iproute2 can-utils \
    wpa-supplicant \
    connman connman-client \
    qtbase qtbase-plugins qtdeclarative qtmultimedia qtwayland \
    qtdeclarative-plugins qtdeclarative-qmlplugins qtshadertools \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good alsa-utils ca-certificates \
    weston weston-init \
    i2c-dev-autoload \
    headunit \
    instrument-cluster \
    des-gear-dbus-config \
    can1 \
    piracer-controller \
    des-piracer-vehicles \
"
IMAGE_FSTYPES += "wic.bz2 rpi-sdimg"
