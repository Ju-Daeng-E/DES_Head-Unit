#
# Instrument cluster CAN setup:
#  - SPI + I2C stay enabled so the controller stack can talk to the CAN HW.
#  - CAN overlays are injected explicitly so we can mix modules: a classic
#    MCP2515-based board (Arduino side) plus the Seeed CAN-FD HAT v2.
#

ENABLE_SPI_BUS = "1"
ENABLE_I2C = "1"

RPI_EXTRA_CONFIG:append = "\
\n# CAN bus configuration\n\
dtoverlay=mcp2515-can1,oscillator=16000000,interrupt=25\n\
dtoverlay=seeed-can-fd-hat-v2\n\
"
