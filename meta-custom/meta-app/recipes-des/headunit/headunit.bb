SUMMARY = "Qt 6 modular head unit application"
LICENSE = "CLOSED"

SRC_URI = "file://headunit.service"

S = "${WORKDIR}/HeadUnit"

inherit qt6-cmake systemd

HEADUNIT_SRC ?= "${TOPDIR}/../DES_Head-Unit/HeadUnit"

DEPENDS = "\
    qtbase \
    qtdeclarative \
    qtdeclarative-native \
    qtmultimedia \
    qtwayland \
    qtshadertools-native \
"

RDEPENDS:${PN} = "\
    qtwayland \
    qtdeclarative-plugins \
    qtdeclarative-qmlplugins \
    qtmultimedia \
"

do_prepare_sources() {
    src="${HEADUNIT_SRC}"
    if [ ! -d "${src}" ]; then
        bberror "HeadUnit sources not found at ${src}"
        exit 1
    fi

    rm -rf ${S}
    mkdir -p ${S}
    cp -a "${src}"/. ${S}/

    # Drop developer-only build directories that should not be staged
    find ${S} -maxdepth 1 -type d -name "build*" -exec rm -rf {} +
    rm -rf ${S}/.qtc_clangd
}

addtask prepare_sources after do_unpack before do_patch
do_prepare_sources[dirs] = "${WORKDIR}"

do_install:append() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/headunit.service ${D}${systemd_system_unitdir}/headunit.service
}

FILES:${PN} += "\
    ${bindir}/HeadUnitApp \
    ${datadir}/headunit \
    ${systemd_system_unitdir}/headunit.service \
"

SYSTEMD_SERVICE:${PN} = "headunit.service"
SYSTEMD_AUTO_ENABLE = "enable"
