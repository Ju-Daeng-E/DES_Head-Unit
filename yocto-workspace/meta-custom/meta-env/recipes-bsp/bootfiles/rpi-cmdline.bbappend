# Minimal boot - NO PLYMOUTH
# Just serial console for debugging
CMDLINE_SERIAL = "console=serial0,115200 console=tty1"
CMDLINE:append = " quiet loglevel=3"
