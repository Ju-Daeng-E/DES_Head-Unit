#
# Enable the MCP2515 overlays for both CAN buses used by the PiRacer.
# This ensures the CAN0/CAN1 interfaces appear during boot so that the
# piracer-controller and instrument-cluster services can start.
#

ENABLE_SPI_BUS = "1"
ENABLE_DUAL_CAN = "1"
CAN_OSCILLATOR = "16000000"
CAN0_INTERRUPT_PIN = "25"
CAN1_INTERRUPT_PIN = "24"
ENABLE_I2C = "1"
