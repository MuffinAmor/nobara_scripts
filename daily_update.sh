#!/usr/bin/env bash
# daily_update.sh – Full system update for Nobara Linux
# Updates system packages (DNF), Flatpak apps, and firmware.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)."
        exit 1
    fi
}

update_dnf() {
    info "Updating system packages via DNF…"
    if dnf update -y; then
        success "DNF packages updated."
    else
        error "DNF update failed."
        return 1
    fi
}

update_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        warn "Flatpak is not installed – skipping."
        return 0
    fi
    info "Updating Flatpak applications…"
    if flatpak update -y; then
        success "Flatpak applications updated."
    else
        warn "Flatpak update encountered issues."
    fi
}

update_firmware() {
    if ! command -v fwupdmgr &>/dev/null; then
        warn "fwupdmgr is not installed – skipping firmware update."
        return 0
    fi
    info "Refreshing firmware metadata…"
    fwupdmgr refresh --force || warn "Could not refresh firmware metadata."

    info "Applying available firmware updates…"
    if fwupdmgr update -y 2>/dev/null; then
        success "Firmware updated."
    else
        warn "No firmware updates available or update failed."
    fi
}

main() {
    require_root

    echo ""
    echo "========================================"
    echo "  Nobara Linux – Daily System Update"
    echo "========================================"
    echo ""

    update_dnf
    update_flatpak
    update_firmware

    echo ""
    success "All updates completed."

    if [ -f /run/reboot-required ] || ! needs-restarting -r &>/dev/null; then
        warn "A system reboot is recommended to apply all updates."
    fi
}

main "$@"
