SUMMARY = "Minimal Qt Quick head unit (QML)"
LICENSE = "CLOSED"
SRC_URI = "file://main.qml \
           file://run-headunit.sh \
           file://headunit.service"
S = "${WORKDIR}"
RDEPENDS:${PN} = "qtdeclarative-tools qtwayland qtmultimedia"
inherit systemd
do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/run-headunit.sh ${D}${bindir}/run-headunit
    install -d ${D}/usr/share/headunit
    install -m 0644 ${WORKDIR}/main.qml ${D}/usr/share/headunit/main.qml
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/headunit.service ${D}${systemd_system_unitdir}/headunit.service
}
SYSTEMD_SERVICE:${PN} = "headunit.service"
SYSTEMD_AUTO_ENABLE = "enable"
FILES:${PN} += "${systemd_system_unitdir}/headunit.service /usr/share/headunit/main.qml"
