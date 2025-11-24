#!/usr/bin/env bash

# Script: backup-vms.sh
# Description: Automated VM backup script for Proxmox
# Author: HomeLab Administrator
# Date: 2025-11-24
# Usage: ./backup-vms.sh [options]

set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/homelab/vm-backup.log"
readonly BACKUP_DIR="${BACKUP_DIR:-/mnt/backup/vms}"
readonly RETENTION_DAYS="${RETENTION_DAYS:-7}"
readonly DATE_FORMAT="%Y%m%d-%H%M%S"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Variables
VERBOSE=false
DRY_RUN=false
VM_IDS=()

# Functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
    log "INFO" "$*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    log "WARN" "$*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    log "ERROR" "$*"
}

error_exit() {
    log_error "$1"
    exit 1
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Automated VM backup script for Proxmox environments.

Options:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run          Perform dry run without making changes
    -i, --vm-id ID         Backup specific VM ID (can be used multiple times)
    -a, --all              Backup all VMs
    -r, --retention DAYS   Number of days to retain backups (default: 7)
    -o, --output DIR       Backup output directory (default: /mnt/backup/vms)

Examples:
    $(basename "$0") -i 100 -i 101              # Backup VMs 100 and 101
    $(basename "$0") --all                      # Backup all VMs
    $(basename "$0") --all --retention 14       # Backup all with 14-day retention
    $(basename "$0") --dry-run --all            # Simulate backup of all VMs

EOF
    exit 0
}

check_dependencies() {
    local deps=("vzdump" "pvesh" "jq")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error_exit "Required command '$cmd' not found. Please install it."
        fi
    done
}

check_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "Creating backup directory: $BACKUP_DIR"
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory"
        fi
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        if [[ ! -w "$BACKUP_DIR" ]]; then
            error_exit "Backup directory is not writable: $BACKUP_DIR"
        fi
    fi
}

get_all_vms() {
    log_info "Fetching list of all VMs..."
    pvesh get /cluster/resources --type vm --output-format json | jq -r '.[].vmid'
}

backup_vm() {
    local vm_id="$1"
    local timestamp=$(date +"$DATE_FORMAT")
    local backup_file="${BACKUP_DIR}/vzdump-qemu-${vm_id}-${timestamp}.vma.zst"
    
    log_info "Starting backup of VM ${vm_id}..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would backup VM ${vm_id} to ${backup_file}"
        return 0
    fi
    
    if vzdump "$vm_id" \
        --storage "$BACKUP_DIR" \
        --mode snapshot \
        --compress zstd \
        --mailnotification failure \
        2>&1 | tee -a "$LOG_FILE"; then
        log_info "Successfully backed up VM ${vm_id}"
        return 0
    else
        log_error "Failed to backup VM ${vm_id}"
        return 1
    fi
}

cleanup_old_backups() {
    log_info "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would delete backups older than ${RETENTION_DAYS} days"
        find "$BACKUP_DIR" -name "vzdump-*.vma.zst" -mtime +"$RETENTION_DAYS" -ls
        return 0
    fi
    
    local deleted_count=0
    while IFS= read -r -d '' backup_file; do
        log_info "Deleting old backup: $backup_file"
        rm -f "$backup_file"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -name "vzdump-*.vma.zst" -mtime +"$RETENTION_DAYS" -print0)
    
    log_info "Deleted $deleted_count old backup(s)"
}

send_notification() {
    local status="$1"
    local message="$2"
    
    # Placeholder for notification system
    # Could integrate with email, Slack, Discord, etc.
    log_info "Notification: [$status] $message"
}

main() {
    log_info "VM Backup Script Started"
    log_info "Backup Directory: $BACKUP_DIR"
    log_info "Retention Period: $RETENTION_DAYS days"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Running in DRY RUN mode - no changes will be made"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Check backup directory
    check_backup_dir
    
    # Get VMs to backup
    local vm_list=()
    if [[ ${#VM_IDS[@]} -eq 0 ]]; then
        log_info "No specific VMs specified, backing up all VMs"
        mapfile -t vm_list < <(get_all_vms)
    else
        vm_list=("${VM_IDS[@]}")
    fi
    
    log_info "VMs to backup: ${vm_list[*]}"
    
    # Backup each VM
    local success_count=0
    local fail_count=0
    
    for vm_id in "${vm_list[@]}"; do
        if backup_vm "$vm_id"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Summary
    log_info "Backup Summary:"
    log_info "  Total VMs: ${#vm_list[@]}"
    log_info "  Successful: $success_count"
    log_info "  Failed: $fail_count"
    
    # Send notification
    if [[ $fail_count -eq 0 ]]; then
        send_notification "SUCCESS" "All VM backups completed successfully"
        log_info "VM Backup Script Completed Successfully"
        exit 0
    else
        send_notification "FAILURE" "$fail_count VM backup(s) failed"
        log_error "VM Backup Script Completed with Errors"
        exit 1
    fi
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
        -i|--vm-id)
            VM_IDS+=("$2")
            shift 2
            ;;
        -a|--all)
            VM_IDS=()
            shift
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -o|--output)
            BACKUP_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Run main function
main "$@"
