# Utility Scripts

This directory contains utility scripts and automation tools for the homelab.

## Directory Structure

```
scripts/
├── backup/          # Backup automation scripts
├── monitoring/      # Monitoring and health check scripts
└── deployment/      # Deployment automation scripts
```

## Prerequisites

### Required Tools

```bash
# Install common tools
sudo apt install -y \
  bash \
  python3 \
  python3-pip \
  jq \
  curl \
  git

# Python packages
pip3 install requests pyyaml
```

## Script Categories

### Backup Scripts
- Automated backup routines
- Backup verification
- Restore procedures
- Off-site replication

### Monitoring Scripts
- Health checks
- Resource monitoring
- Log analysis
- Alert generation

### Deployment Scripts
- Service deployment automation
- Configuration updates
- Rolling updates
- Rollback procedures

## General Guidelines

### Script Standards

1. **Shebang**: Use `#!/usr/bin/env bash` or `#!/usr/bin/env python3`
2. **Error Handling**: Always check for errors
3. **Logging**: Log all operations
4. **Documentation**: Include usage comments
5. **Variables**: Use uppercase for constants
6. **Functions**: Use lowercase with underscores

### Example Script Template

```bash
#!/usr/bin/env bash

# Script: example-script.sh
# Description: Brief description of what this script does
# Author: Your Name
# Date: 2025-11
# Usage: ./example-script.sh [options]

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/example-script.log"
readonly CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# Functions
log() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --dry-run   Perform dry run without making changes

Example:
    $(basename "$0") --verbose

EOF
    exit 0
}

main() {
    log "INFO" "Script started"

    # Main logic here

    log "INFO" "Script completed successfully"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Run main function
main "$@"
```

## Common Functions Library

Create `lib/common.sh` for shared functions:

```bash
#!/usr/bin/env bash

# Common functions library

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    local deps=("$@")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required command '$cmd' not found"
            exit 1
        fi
    done
}

send_notification() {
    local title="$1"
    local message="$2"
    local priority="${3:-normal}"

    # Send to various notification channels
    # Email, Slack, Discord, etc.
}

lock_script() {
    local lockfile="/var/lock/$(basename "$0").lock"
    exec 200>"$lockfile"
    flock -n 200 || error_exit "Script is already running"
}

unlock_script() {
    local lockfile="/var/lock/$(basename "$0").lock"
    rm -f "$lockfile"
}
```

## Environment Variables

### Configuration File (.env)

```bash
# Homelab Configuration
HOMELAB_DOMAIN="homelab.local"
ADMIN_EMAIL="admin@homelab.local"

# Proxmox
PROXMOX_HOST="proxmox.homelab.local"
PROXMOX_USER="root@pam"

# Backup
BACKUP_DIR="/mnt/backup"
BACKUP_RETENTION_DAYS=30

# Monitoring
PROMETHEUS_URL="http://prometheus.homelab.local:9090"
GRAFANA_URL="http://grafana.homelab.local:3000"

# Notifications
SLACK_WEBHOOK_URL=""
DISCORD_WEBHOOK_URL=""

# Storage
NAS_HOST="truenas.homelab.local"
NAS_SHARE="/mnt/nas/homelab"
```

## Python Script Template

```python
#!/usr/bin/env python3
"""
Script: example-script.py
Description: Brief description
Author: Your Name
Date: 2025-11
"""

import argparse
import logging
import sys
from datetime import datetime
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/example-script.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)


class ScriptException(Exception):
    """Custom exception for script errors"""
    pass


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Script description',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )

    parser.add_argument(
        '-d', '--dry-run',
        action='store_true',
        help='Perform dry run'
    )

    return parser.parse_args()


def main():
    """Main function"""
    args = parse_arguments()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    logger.info("Script started")

    try:
        # Main logic here
        pass

    except ScriptException as e:
        logger.error(f"Script error: {e}")
        return 1
    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        return 1

    logger.info("Script completed successfully")
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

## Scheduling with Cron

### Crontab Examples

```bash
# Edit crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /opt/scripts/backup/daily-backup.sh >> /var/log/backup.log 2>&1

# Hourly monitoring check
0 * * * * /opt/scripts/monitoring/health-check.sh

# Weekly cleanup on Sunday at 3 AM
0 3 * * 0 /opt/scripts/cleanup/weekly-cleanup.sh

# Monthly report on 1st at 9 AM
0 9 1 * * /opt/scripts/reporting/monthly-report.sh
```

### Systemd Timer Alternative

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily Backup Timer

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Daily Backup Service

[Service]
Type=oneshot
ExecStart=/opt/scripts/backup/daily-backup.sh
User=backup
Group=backup
```

```bash
# Enable and start timer
sudo systemctl enable backup.timer
sudo systemctl start backup.timer

# Check status
sudo systemctl list-timers
```

## Testing Scripts

### Shell Script Testing

```bash
# Syntax check
bash -n script.sh

# Shell linting
shellcheck script.sh

# Dry run with debug
bash -x script.sh --dry-run
```

### Python Script Testing

```bash
# Syntax check
python3 -m py_compile script.py

# Linting
pylint script.py
flake8 script.py

# Type checking
mypy script.py
```

## Version Control

```bash
# Track script changes
git add scripts/
git commit -m "Add new monitoring script"
git tag -a v1.0.0 -m "Release version 1.0.0"
```

## Documentation

Each script should include:
- Purpose and description
- Usage examples
- Prerequisites
- Input parameters
- Output format
- Error codes
- Known issues

## Security Considerations

1. **Credentials**: Never hardcode passwords
2. **Permissions**: Set appropriate file permissions (chmod 750)
3. **Input Validation**: Validate all inputs
4. **Logging**: Don't log sensitive information
5. **Error Messages**: Don't expose system details

### Secure Credential Handling

```bash
# Use environment variables
DB_PASSWORD="${DB_PASSWORD:-}"

# Use credential files with restricted permissions
if [[ -f ~/.credentials ]]; then
    chmod 600 ~/.credentials
    source ~/.credentials
fi

# Use vault or secret manager
SECRET=$(vault kv get -field=password secret/database)
```

## Monitoring Script Execution

### Log Aggregation

```bash
# Centralize logs
logger -t script-name "Message to syslog"

# Send to remote syslog
logger -n syslog-server.homelab.local -t script-name "Remote log"
```

### Metrics Collection

```python
# Prometheus metrics
from prometheus_client import Counter, Gauge, push_to_gateway

script_runs = Counter('script_runs_total', 'Total script executions')
script_duration = Gauge('script_duration_seconds', 'Script execution time')

# In your script
script_runs.inc()
with script_duration.time():
    # Your code here
    pass

# Push to Prometheus
push_to_gateway('localhost:9091', job='backup_script', registry=registry)
```

## Examples

See subdirectories for specific examples:
- `backup/README.md` - Backup script examples
- `monitoring/README.md` - Monitoring script examples
- `deployment/README.md` - Deployment script examples

## Troubleshooting

### Common Issues

**Permission Denied**
```bash
chmod +x script.sh
```

**Command Not Found**
```bash
which command-name
export PATH=$PATH:/usr/local/bin
```

**Script Runs but Fails**
```bash
# Enable debugging
set -x
bash -x script.sh
```

## Resources

- [Bash Guide](https://mywiki.wooledge.org/BashGuide)
- [ShellCheck](https://www.shellcheck.net/)
- [Python Best Practices](https://docs.python-guide.org/)
- [Cron Documentation](https://man7.org/linux/man-pages/man5/crontab.5.html)

## Future Enhancements

- Add more comprehensive error handling
- Implement retry logic
- Add notification integrations
- Create dashboard for script monitoring
- Automated testing framework
