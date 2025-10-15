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
    headunit \
"
IMAGE_FSTYPES += "wic.bz2 rpi-sdimg"
IMAGE_INSTALL:append = " weston weston-init "
