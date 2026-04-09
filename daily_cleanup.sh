#!/usr/bin/env bash
# daily_cleanup.sh – System cleanup for Nobara Linux
# Removes orphaned packages, old kernels, stale caches, and unused Flatpak runtimes.

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

# Number of kernel versions to keep (current + 1 previous)
KEEP_KERNELS=${KEEP_KERNELS:-2}

# Maximum age for journal logs
JOURNAL_MAX_AGE=${JOURNAL_MAX_AGE:-"7d"}

clean_dnf_cache() {
    info "Cleaning DNF package cache…"
    dnf clean all
    success "DNF cache cleaned."
}

remove_orphaned_packages() {
    info "Removing orphaned/autoremovable packages…"
    if dnf autoremove -y; then
        success "Orphaned packages removed."
    else
        warn "dnf autoremove encountered issues."
    fi
}

remove_old_kernels() {
    info "Removing old kernel versions (keeping ${KEEP_KERNELS} most recent)…"
    # Count installed kernels
    local installed
    installed=$(rpm -q kernel | wc -l)
    if [[ $installed -le $KEEP_KERNELS ]]; then
        info "Only ${installed} kernel(s) installed – nothing to remove."
        return 0
    fi
    if dnf remove --oldinstallonly --setopt="installonly_limit=${KEEP_KERNELS}" kernel -y; then
        success "Old kernels removed."
    else
        warn "Could not remove old kernels."
    fi
}

clean_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        warn "Flatpak is not installed – skipping."
        return 0
    fi
    info "Removing unused Flatpak runtimes…"
    if flatpak uninstall --unused -y; then
        success "Unused Flatpak runtimes removed."
    else
        warn "Flatpak cleanup encountered issues."
    fi
}

clean_journal() {
    info "Truncating systemd journal logs older than ${JOURNAL_MAX_AGE}…"
    if journalctl --vacuum-time="${JOURNAL_MAX_AGE}"; then
        success "Journal logs cleaned."
    else
        warn "Journal cleanup encountered issues."
    fi
}

clean_tmp() {
    info "Removing files in /tmp older than 7 days…"
    find /tmp -mindepth 1 -maxdepth 1 -atime +7 -exec rm -rf {} + 2>/dev/null || true
    success "Old /tmp files removed."
}

show_disk_usage() {
    info "Current disk usage:"
    df -h / | tail -1 | awk '{printf "  Filesystem: %s  Used: %s / %s  (%s used)\n", $1, $3, $2, $5}'
}

main() {
    require_root

    echo ""
    echo "========================================"
    echo "  Nobara Linux – Daily System Cleanup"
    echo "========================================"
    echo ""

    clean_dnf_cache
    remove_orphaned_packages
    remove_old_kernels
    clean_flatpak
    clean_journal
    clean_tmp

    echo ""
    show_disk_usage
    success "Cleanup completed."
}

main "$@"
