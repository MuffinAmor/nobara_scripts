#!/usr/bin/env python3
"""
SteelSeries Alias Micro - LED ausschalten
Einmaliges Ausführungs-Script mit automatischem pip-Check
"""

import subprocess
import sys

def check_and_install(package):
    try:
        __import__(package)
    except ImportError:
        print(f"[*] '{package}' nicht gefunden, installiere...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
        print(f"[+] '{package}' installiert!")

def main():
    check_and_install("hid")

    import hid

    VENDOR_ID = 0x1038
    PRODUCT_ID = 0x1b04
    CMD_LED_OFF = [0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

    devices = hid.enumerate(VENDOR_ID, PRODUCT_ID)

    if not devices:
        print("[-] SteelSeries Alias Micro nicht gefunden!")
        print("    Stelle sicher dass das Gerät angeschlossen ist.")
        sys.exit(1)

    for interface in [3, 4]:
        path = None
        for d in devices:
            if d["interface_number"] == interface:
                path = d["path"]
                break
        if not path:
            continue

        try:
            h = hid.device()
            h.open_path(path)
            h.set_nonblocking(1)
            h.write(CMD_LED_OFF)
            h.close()
            print(f"[+] LED ausgeschaltet! (Interface {interface})")
            sys.exit(0)
        except Exception as e:
            print(f"[-] Interface {interface} fehlgeschlagen: {e}")

    print("[-] Konnte LED nicht ausschalten. Versuche: sudo python3 steelseries_alias_led_off.py")
    sys.exit(1)


if __name__ == "__main__":
    main()