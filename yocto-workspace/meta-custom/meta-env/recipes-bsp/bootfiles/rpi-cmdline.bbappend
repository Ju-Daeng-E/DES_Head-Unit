# Enable Plymouth splash screen and keep both serial and tty console for debugging
# serial0 = UART serial console (for debugging kernel panic)
# tty1 = HDMI console output
# splash = Enable Plymouth graphical boot
# quiet = Hide kernel messages (show only Plymouth)
CMDLINE_SERIAL = "console=serial0,115200 console=tty1"
CMDLINE:append = " splash quiet"
