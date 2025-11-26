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
"

do_install:append() {
    # Install DES theme files
    install -d ${D}${datadir}/plymouth/themes/des
    install -m 0644 ${WORKDIR}/des-theme/des.plymouth ${D}${datadir}/plymouth/themes/des/
    install -m 0644 ${WORKDIR}/des-theme/des.script ${D}${datadir}/plymouth/themes/des/
    install -m 0644 ${WORKDIR}/des-theme/logo.png ${D}${datadir}/plymouth/themes/des/

    # Install plymouthd defaults to set DES as default theme
    install -d ${D}${datadir}/plymouth
    install -m 0644 ${WORKDIR}/plymouthd.defaults ${D}${datadir}/plymouth/plymouthd.defaults
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
