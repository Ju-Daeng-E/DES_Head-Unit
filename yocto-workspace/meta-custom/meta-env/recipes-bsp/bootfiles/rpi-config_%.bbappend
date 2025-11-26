#
# Instrument cluster CAN setup:
#  - SPI + I2C stay enabled so the controller stack can talk to the CAN HW.
#  - CAN overlays are injected explicitly so we can mix modules: a classic
#    MCP2515-based board (Arduino side) plus the Seeed CAN-FD HAT v2.0.
#

ENABLE_SPI_BUS = "1"
ENABLE_I2C = "1"


# GPU Memory Configuration (optimized for dual display with power efficiency)
GPU_MEM = "128"

# Enable psplash boot logo support
ENABLE_UART = "1"

# Override VC4 dtoverlay to include noaudio parameter (prevents duplication)
VC4DTBO = "vc4-kms-v3d,noaudio"

# Dual HDMI Display Configuration for Head-Unit and Instrument Cluster
# HDMI-0: Head-Unit (1024x600), HDMI-1: Instrument Cluster (1024x600)
RPI_EXTRA_CONFIG:append = "
dtoverlay=mcp2515-can1,oscillator=16000000,interrupt=25
dtoverlay=seeed-can-fd-hat-v2
hdmi_drive:0=2
hdmi_drive:1=2
hdmi_force_hotplug:0=1
hdmi_force_hotplug:1=1
hdmi_group:0=2
hdmi_group:1=2
hdmi_mode:0=87
hdmi_mode:1=87
hdmi_cvt:0=1024 600 60 6 0 0 0
hdmi_cvt:1=1024 600 60 6 0 0 0
config_hdmi_boost:0=2
config_hdmi_boost:1=2
disable_overscan=1
max_framebuffers=2
enable_uart=1
disable_splash=1
"