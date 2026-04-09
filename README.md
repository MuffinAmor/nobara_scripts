# nobara_scripts

A collection of daily maintenance and health-check scripts for [Nobara Linux](https://nobaraproject.org/).

## Scripts

| Script | Root required | Description |
|---|---|---|
| `daily.sh` | Yes (unless `--health-only`) | **Master script** – runs all steps in sequence |
| `daily_update.sh` | Yes | Updates system packages (DNF), Flatpak apps, and firmware |
| `daily_cleanup.sh` | Yes | Removes orphaned packages, old kernels, stale caches, and unused Flatpak runtimes |
| `system_health.sh` | No | Reports disk, memory, CPU load, failed services, and pending reboots |

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/MuffinAmor/nobara_scripts.git
cd nobara_scripts

# Make scripts executable
chmod +x *.sh

# Run all daily maintenance steps
sudo ./daily.sh
```

---

## daily.sh – Master Script

Runs the health check, system update, and cleanup in sequence.

```
Usage: sudo ./daily.sh [OPTIONS]

Options:
  --no-update    Skip the system update step
  --no-cleanup   Skip the system cleanup step
  --health-only  Run health check only (no root required)
  --help, -h     Show this help message
```

**Examples:**

```bash
# Full daily maintenance
sudo ./daily.sh

# Health check only (no root needed)
./daily.sh --health-only

# Update without cleanup
sudo ./daily.sh --no-cleanup
```

---

## daily_update.sh – System Update

Updates the system in three steps:

1. **DNF** – updates all system packages
2. **Flatpak** – updates all Flatpak applications (skipped if Flatpak is not installed)
3. **Firmware** – refreshes and applies firmware updates via `fwupdmgr` (skipped if not available)

```bash
sudo ./daily_update.sh
```

---

## daily_cleanup.sh – System Cleanup

Frees disk space by:

1. Cleaning the **DNF package cache**
2. Removing **orphaned/autoremovable packages**
3. Removing **old kernel versions** (keeps the 2 most recent by default)
4. Removing **unused Flatpak runtimes** (skipped if Flatpak is not installed)
5. Vacuuming **systemd journal logs** older than 7 days
6. Deleting files in **/tmp** older than 7 days

**Environment variables (optional):**

| Variable | Default | Description |
|---|---|---|
| `KEEP_KERNELS` | `2` | Number of kernel versions to keep |
| `JOURNAL_MAX_AGE` | `7d` | Maximum age for journal logs |

```bash
# Default cleanup
sudo ./daily_cleanup.sh

# Keep 3 kernels, purge journals older than 14 days
sudo KEEP_KERNELS=3 JOURNAL_MAX_AGE=14d ./daily_cleanup.sh
```

---

## system_health.sh – Health Check

Checks and reports:

- **System uptime**
- **Disk usage** per mounted filesystem (warns at ≥ 80 %, critical at ≥ 90 %)
- **Memory and swap usage** (warns at ≥ 80 %, critical at ≥ 90 %)
- **CPU load average** (warns when load exceeds the number of logical CPUs)
- **Failed systemd services**
- **Pending reboot** status

Exits with code `0` if everything is healthy, `1` if any check is critical.

**Environment variables (optional):**

| Variable | Default | Description |
|---|---|---|
| `DISK_WARN` | `80` | Disk usage warning threshold (%) |
| `DISK_CRIT` | `90` | Disk usage critical threshold (%) |
| `MEM_WARN` | `80` | Memory usage warning threshold (%) |
| `MEM_CRIT` | `90` | Memory usage critical threshold (%) |

```bash
# Default health check
./system_health.sh

# Custom thresholds
DISK_WARN=70 DISK_CRIT=85 ./system_health.sh
```

---

## Automating with cron

To run the full maintenance every day at 03:00:

```bash
sudo crontab -e
```

Add:

```cron
0 3 * * * /path/to/nobara_scripts/daily.sh >> /var/log/nobara_daily.log 2>&1
```

---

## Requirements

- Nobara Linux (or any Fedora-based distribution)
- `dnf` (pre-installed)
- `flatpak` (optional – skipped automatically if absent)
- `fwupdmgr` (optional – skipped automatically if absent)
- `systemd` (pre-installed)
