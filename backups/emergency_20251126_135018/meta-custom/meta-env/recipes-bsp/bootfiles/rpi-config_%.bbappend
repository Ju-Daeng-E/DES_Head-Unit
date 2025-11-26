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

# GPU Memory Configuration (optimized for dual display with power efficiency)
GPU_MEM = "128"

# Enable psplash boot logo support
ENABLE_UART = "1"

# Override VC4 dtoverlay to include noaudio parameter (prevents duplication)
VC4DTBO = "vc4-kms-v3d,noaudio"

# Dual HDMI Display Configuration for Head-Unit and Instrument Cluster
# HDMI-0: Head-Unit (1024x600), HDMI-1: Instrument Cluster (1024x600)
RPI_EXTRA_CONFIG = "\
hdmi_drive:0=2\n\
hdmi_drive:1=2\n\
hdmi_force_hotplug:0=1\n\
hdmi_force_hotplug:1=1\n\
hdmi_group:0=2\n\
hdmi_group:1=2\n\
hdmi_mode:0=87\n\
hdmi_mode:1=87\n\
hdmi_cvt:0=1024 600 60 6 0 0 0\n\
hdmi_cvt:1=1024 600 60 6 0 0 0\n\
config_hdmi_boost:0=2\n\
config_hdmi_boost:1=2\n\
disable_overscan=1\n\
max_framebuffers=2\n\
enable_uart=1\n\
disable_splash=1\n\
"
