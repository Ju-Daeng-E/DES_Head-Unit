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
    pulseaudio \
    pulseaudio-server \
    pulseaudio-module-bluetooth-discover \
    pulseaudio-module-bluetooth-policy \
    pulseaudio-module-bluez5-device \
    pulseaudio-module-bluez5-discover \
    pulseaudio-module-loopback \
    fontconfig fontconfig-utils \
    ttf-dejavu-sans ttf-dejavu-sans-mono \
    liberation-fonts \
    ttf-noto-emoji-color \
    wayland weston weston-init weston-examples \
    libinput \
    evtest \
    i2c-dev-autoload \
    headunit \
    instrument-cluster \
    des-gear-dbus-config \
    can1 \
    piracer-controller \
    des-piracer-vehicles \
    plymouth \
    plymouth-set-default-theme \
    wifi-auto-enable \
"

add_users_to_groups() {
    sed -i 's/root:x:0:0:root:\/root:\/bin\/sh/root:x:0:0:root:\/root:\/bin\/bash/' ${IMAGE_ROOTFS}/etc/passwd
    groupadd bluetooth -R ${IMAGE_ROOTFS}
    usermod -a -G audio root -R ${IMAGE_ROOTFS}
    usermod -a -G bluetooth pulse -R ${IMAGE_ROOTFS}
}

enable_pulseaudio_service() {
    # Manually enable pulseaudio.service for automatic startup
    if [ -f ${IMAGE_ROOTFS}/usr/lib/systemd/system/pulseaudio.service ]; then
        mkdir -p ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants
        ln -sf /usr/lib/systemd/system/pulseaudio.service \
               ${IMAGE_ROOTFS}/etc/systemd/system/multi-user.target.wants/pulseaudio.service
        bbnote "Enabled pulseaudio.service"
    else
        bbwarn "pulseaudio.service not found, skipping enablement"
    fi
}

ROOTFS_POSTPROCESS_COMMAND += " add_users_to_groups; enable_pulseaudio_service; "

IMAGE_FSTYPES += "wic.bz2 rpi-sdimg"
