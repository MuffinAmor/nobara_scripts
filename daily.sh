#!/usr/bin/env bash
# daily.sh – Master daily maintenance script for Nobara Linux
# Runs: system health check → system update → system cleanup
#
# Usage:
#   sudo ./daily.sh              # run all steps
#   sudo ./daily.sh --no-update  # skip update step
#   sudo ./daily.sh --no-cleanup # skip cleanup step
#   sudo ./daily.sh --health-only # health check only (no root needed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}========================================${NC}"; \
             echo -e "${BOLD}  $*${NC}"; \
             echo -e "${BOLD}========================================${NC}\n"; }

RUN_UPDATE=true
RUN_CLEANUP=true
RUN_HEALTH=true

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --no-update)   RUN_UPDATE=false ;;
            --no-cleanup)  RUN_CLEANUP=false ;;
            --health-only) RUN_UPDATE=false; RUN_CLEANUP=false ;;
            --help|-h)     usage; exit 0 ;;
            *)
                error "Unknown option: $arg"
                usage
                exit 1
                ;;
        esac
    done
}

usage() {
    echo ""
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --no-update    Skip the system update step"
    echo "  --no-cleanup   Skip the system cleanup step"
    echo "  --health-only  Run health check only (no root required)"
    echo "  --help, -h     Show this help message"
    echo ""
}

require_root_unless_health_only() {
    if $RUN_UPDATE || $RUN_CLEANUP; then
        if [[ $EUID -ne 0 ]]; then
            error "Update and cleanup steps require root. Use sudo or pass --health-only."
            exit 1
        fi
    fi
}

run_step() {
    local name="$1"
    local script="$2"
    header "$name"
    if [[ ! -x "$script" ]]; then
        chmod +x "$script"
    fi
    if bash "$script"; then
        success "${name} completed successfully."
    else
        warn "${name} completed with warnings or errors."
    fi
}

main() {
    parse_args "$@"
    require_root_unless_health_only

    echo ""
    echo -e "${BOLD}########################################${NC}"
    echo -e "${BOLD}#   Nobara Linux – Daily Maintenance   #${NC}"
    echo -e "${BOLD}########################################${NC}"
    echo ""
    echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    $RUN_HEALTH  && run_step "System Health Check" "${SCRIPT_DIR}/system_health.sh"
    $RUN_UPDATE  && run_step "System Update"       "${SCRIPT_DIR}/daily_update.sh"
    $RUN_CLEANUP && run_step "System Cleanup"      "${SCRIPT_DIR}/daily_cleanup.sh"

    echo ""
    echo -e "${BOLD}########################################${NC}"
    echo -e "${BOLD}#         Daily Maintenance Done       #${NC}"
    echo -e "${BOLD}########################################${NC}"
    echo ""
    echo "  Finished: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

main "$@"
