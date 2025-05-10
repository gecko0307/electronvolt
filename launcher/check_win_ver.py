import sys
import platform

if platform.system() == "Windows":
    print("Checking Windows version...")
    ver = sys.getwindowsversion()
    if ver.major < 10:
        import ctypes
        ctypes.windll.user32.MessageBoxW(None, "Launcher requires Windows 10 or later", "Error", 0)
        sys.exit(1)
