#!/usr/bin/env bash
# system_health.sh – System health check for Nobara Linux
# Reports disk usage, memory, CPU load, failed systemd services, and pending reboots.
# Can be run as a normal user (no root required).

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
bad()     { echo -e "${RED}[FAIL]${NC}  $*"; }
header()  { echo -e "\n${BOLD}--- $* ---${NC}"; }

# Thresholds (percentage)
DISK_WARN=${DISK_WARN:-80}
DISK_CRIT=${DISK_CRIT:-90}
MEM_WARN=${MEM_WARN:-80}
MEM_CRIT=${MEM_CRIT:-90}

EXIT_CODE=0

check_disk() {
    header "Disk Usage"
    while IFS= read -r line; do
        local usage mount
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        mount=$(echo "$line" | awk '{print $6}')
        local size used avail
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        avail=$(echo "$line" | awk '{print $4}')
        if [[ $usage -ge $DISK_CRIT ]]; then
            bad "  ${mount}: ${used}/${size} used (${usage}%) – CRITICAL"
            EXIT_CODE=1
        elif [[ $usage -ge $DISK_WARN ]]; then
            warn "  ${mount}: ${used}/${size} used (${usage}%) – WARNING"
        else
            ok "  ${mount}: ${used}/${size} used (${usage}%)"
        fi
    done < <(df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x efivarfs | tail -n +2)
}

check_memory() {
    header "Memory Usage"
    local total used_pct
    total=$(free -m | awk '/^Mem:/{print $2}')
    local used
    used=$(free -m | awk '/^Mem:/{print $3}')
    used_pct=$(( used * 100 / total ))
    local total_h used_h avail_h
    total_h=$(free -h | awk '/^Mem:/{print $2}')
    used_h=$(free -h | awk '/^Mem:/{print $3}')
    avail_h=$(free -h | awk '/^Mem:/{print $7}')

    if [[ $used_pct -ge $MEM_CRIT ]]; then
        bad "  RAM: ${used_h} / ${total_h} used (${used_pct}%) – CRITICAL"
        EXIT_CODE=1
    elif [[ $used_pct -ge $MEM_WARN ]]; then
        warn "  RAM: ${used_h} / ${total_h} used (${used_pct}%) – WARNING"
    else
        ok "  RAM: ${used_h} / ${total_h} used (${used_pct}%)"
    fi

    local swap_total
    swap_total=$(free -m | awk '/^Swap:/{print $2}')
    if [[ $swap_total -gt 0 ]]; then
        local swap_used swap_pct
        swap_used=$(free -m | awk '/^Swap:/{print $3}')
        swap_pct=$(( swap_used * 100 / swap_total ))
        local swap_used_h swap_total_h
        swap_used_h=$(free -h | awk '/^Swap:/{print $3}')
        swap_total_h=$(free -h | awk '/^Swap:/{print $2}')
        if [[ $swap_pct -ge $MEM_WARN ]]; then
            warn "  Swap: ${swap_used_h} / ${swap_total_h} used (${swap_pct}%)"
        else
            ok "  Swap: ${swap_used_h} / ${swap_total_h} used (${swap_pct}%)"
        fi
    fi
}

check_cpu_load() {
    header "CPU Load"
    local cpus load1 load5 load15
    cpus=$(nproc)
    read -r load1 load5 load15 _ < /proc/loadavg
    local load1_int
    load1_int=$(echo "$load1" | awk -v c="$cpus" '{printf "%d", ($1/c)*100}')
    if [[ $load1_int -ge 100 ]]; then
        warn "  Load avg (1/5/15 min): ${load1} / ${load5} / ${load15}  [${cpus} CPUs] – HIGH"
    else
        ok "  Load avg (1/5/15 min): ${load1} / ${load5} / ${load15}  [${cpus} CPUs]"
    fi
}

check_failed_services() {
    header "Systemd Failed Services"
    local failed
    failed=$(systemctl --failed --no-legend --plain 2>/dev/null | grep -c '●' || true)
    if [[ $failed -eq 0 ]]; then
        ok "  No failed services."
    else
        bad "  ${failed} failed service(s):"
        systemctl --failed --no-pager 2>/dev/null | head -20
        EXIT_CODE=1
    fi
}

check_pending_reboot() {
    header "Pending Reboot"
    local needs_reboot=false
    # Check via needs-restarting (dnf-utils)
    if command -v needs-restarting &>/dev/null; then
        if ! needs-restarting -r &>/dev/null; then
            needs_reboot=true
        fi
    fi
    # Fallback: check for reboot-required flag
    if [[ -f /run/reboot-required ]]; then
        needs_reboot=true
    fi

    if $needs_reboot; then
        warn "  A system reboot is recommended."
    else
        ok "  No reboot required."
    fi
}

check_uptime() {
    header "System Uptime"
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null || uptime)
    ok "  ${uptime_str}"
}

main() {
    echo ""
    echo "========================================"
    echo "  Nobara Linux – System Health Check"
    echo "========================================"

    check_uptime
    check_disk
    check_memory
    check_cpu_load
    check_failed_services
    check_pending_reboot

    echo ""
    if [[ $EXIT_CODE -eq 0 ]]; then
        ok "System is healthy."
    else
        bad "One or more checks require attention."
    fi
    echo ""

    exit $EXIT_CODE
}

main "$@"
