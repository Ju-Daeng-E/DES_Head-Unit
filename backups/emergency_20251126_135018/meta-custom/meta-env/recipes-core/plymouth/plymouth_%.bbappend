# Remove initrd dependency (which requires dracut) for embedded use
# Enable DRM for Raspberry Pi hardware rendering
# Use custom DES theme with Ferrari logo

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

PACKAGECONFIG:remove = "initrd"
PACKAGECONFIG:append = " drm script"

# Enable script theme for custom branding
PLYMOUTH_THEMES = "script"

# DES Cockpit branding colors
PLYMOUTH_BACKGROUND_COLOR = "0x000000"
PLYMOUTH_BACKGROUND_START_COLOR_STOP = "0x1a1a1a"
PLYMOUTH_BACKGROUND_END_COLOR_STOP = "0x000000"

# Install custom DES theme
SRC_URI += " \
    file://des-theme/des.plymouth \
    file://des-theme/des.script \
    file://des-theme/logo.png \
    file://plymouthd.defaults \
    file://plymouth-quit-wait.service \
    file://plymouth-quit-timer.service \
"

# Add all video frame images to source (140 frames @ 20fps)
python __anonymous() {
    src_uri = d.getVar('SRC_URI', True) or ""
    for i in range(140):
        frame_file = "file://des-theme/frames/frame_{:04d}.png".format(i)
        src_uri += " " + frame_file
    d.setVar('SRC_URI', src_uri)
}

do_install:append() {
    # Install DES theme files
    install -d ${D}${datadir}/plymouth/themes/des
    install -m 0644 ${WORKDIR}/des-theme/des.plymouth ${D}${datadir}/plymouth/themes/des/
    install -m 0644 ${WORKDIR}/des-theme/des.script ${D}${datadir}/plymouth/themes/des/
    install -m 0644 ${WORKDIR}/des-theme/logo.png ${D}${datadir}/plymouth/themes/des/

    # Install video frame images for animation (140 frames @ 20fps)
    for i in $(seq 0 139); do
        frame_num=$(printf "%04d" $i)
        install -m 0644 ${WORKDIR}/des-theme/frames/frame_${frame_num}.png ${D}${datadir}/plymouth/themes/des/
    done

    # Install plymouthd defaults to set DES as default theme
    install -d ${D}${datadir}/plymouth
    install -m 0644 ${WORKDIR}/plymouthd.defaults ${D}${datadir}/plymouth/plymouthd.defaults

    # Install plymouth-quit-timer service
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/plymouth-quit-timer.service ${D}${systemd_system_unitdir}/
}

# Mask default plymouth-quit services via systemd
SYSTEMD_SERVICE:${PN} += "plymouth-quit.service plymouth-quit-wait.service plymouth-quit-timer.service"

pkg_postinst_ontarget:${PN}:append() {
    # Enable plymouth-quit-timer (this will quit Plymouth after 7 seconds)
    systemctl enable plymouth-quit-timer.service || true

    # Mask default plymouth-quit services to prevent early termination
    systemctl mask plymouth-quit.service || true
    systemctl mask plymouth-quit-wait.service || true

    systemctl daemon-reload || true
}

FILES:${PN} += "${datadir}/plymouth/themes/des/*"

# Set DES as default theme
ALTERNATIVE_PRIORITY = "200"

# Post-install script to set DES theme as default
pkg_postinst_ontarget:${PN}() {
    if [ -x $D${sbindir}/plymouth-set-default-theme ]; then
        $D${sbindir}/plymouth-set-default-theme des
    fi
}
