# Enable Plymouth splash screen with minimal console output
# serial0 = UART serial console (for debugging kernel panic)
# console=tty1 REMOVED to prevent auto-switch after Plymouth quits
# splash = Enable Plymouth graphical boot
# quiet = Hide kernel messages
# loglevel=3 = Show only errors
# vt.global_cursor_default=0 = Hide cursor
# plymouth.ignore-serial-consoles = Don't show on serial
CMDLINE_SERIAL = "console=serial0,115200"
CMDLINE:append = " splash quiet loglevel=3 vt.global_cursor_default=0 plymouth.ignore-serial-consoles"
