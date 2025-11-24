# Backup Scripts

This directory contains automated backup scripts for the homelab infrastructure.

## Available Scripts

### backup-vms.sh

Automated VM backup script for Proxmox environments.

**Features:**
- Backup individual or all VMs
- Configurable retention policy
- Dry-run mode for testing
- Comprehensive logging
- Snapshot-based backups with compression

**Usage:**
```bash
# Backup all VMs
./backup-vms.sh --all

# Backup specific VMs
./backup-vms.sh -i 100 -i 101

# Dry run
./backup-vms.sh --all --dry-run

# Custom retention
./backup-vms.sh --all --retention 14
```

## Backup Strategy

### What Gets Backed Up

1. **Virtual Machines**
   - VM configurations
   - Disk images
   - Snapshots

2. **Containers**
   - Container configs
   - Volumes
   - Persistent data

3. **Configuration Files**
   - System configs
   - Application configs
   - Network configs

4. **Databases**
   - Database dumps
   - Transaction logs
   - Configuration backups

### Backup Schedule

```
Daily:   02:00 - Critical VMs and databases
Weekly:  03:00 - All VMs and containers
Monthly: 04:00 - Full system backup
```

## Backup Storage

### Primary Storage
- Location: `/mnt/backup/`
- Type: ZFS pool on dedicated storage
- Features: Compression, deduplication, snapshots

### Secondary Storage
- Location: NAS (TrueNAS)
- Replication: Daily sync from primary
- Retention: Extended retention period

### Off-site Storage
- Location: Cloud storage (encrypted)
- Frequency: Weekly for critical data
- Retention: Long-term archive

## Restoration

### Quick Restore

```bash
# Restore VM from backup
qmrestore /mnt/backup/vzdump-qemu-100-*.vma.zst 100

# Restore container
pct restore 101 /mnt/backup/vzdump-lxc-101-*.tar.zst
```

### Full Disaster Recovery

See `docs/backup-strategy.md` for comprehensive recovery procedures.

## Monitoring

### Backup Status Checks

```bash
# Check last backup time
find /mnt/backup -name "vzdump-*.vma.zst" -mtime -1 -ls

# Verify backup integrity
zstd -t /mnt/backup/vzdump-qemu-100-*.vma.zst
```

### Alerts

Configured alerts for:
- Backup failures
- Low storage space
- Long backup duration
- Missing backups

## Automation

### Cron Schedule

```cron
# Daily backups
0 2 * * * /opt/homelab/scripts/backup/backup-vms.sh --all >> /var/log/backup.log 2>&1

# Weekly verification
0 3 * * 0 /opt/homelab/scripts/backup/verify-backups.sh
```

### Systemd Timer

```bash
# Enable backup timer
systemctl enable backup-daily.timer
systemctl start backup-daily.timer
```

## Best Practices

1. **Test Restores**: Regularly test backup restoration
2. **Verify Backups**: Run integrity checks
3. **Monitor Storage**: Keep adequate free space
4. **Encrypt Backups**: Encrypt off-site backups
5. **Document Process**: Keep procedures updated
6. **Multiple Copies**: Follow 3-2-1 rule

## Troubleshooting

### Backup Fails

```bash
# Check logs
tail -f /var/log/homelab/vm-backup.log

# Test manually
vzdump 100 --dumpdir /tmp --mode snapshot

# Check storage space
df -h /mnt/backup
```

### Slow Backups

- Check storage I/O performance
- Verify network bandwidth (for remote backups)
- Consider snapshot method vs stop mode
- Review compression settings

### Restore Issues

- Verify backup file integrity
- Check target storage availability
- Ensure sufficient space for restore
- Review VM ID conflicts

## Security

- Backup files encrypted at rest
- Secure backup storage access
- Audit logs for backup operations
- Off-site backups use separate credentials

## Future Enhancements

- [ ] Implement incremental backups
- [ ] Add backup encryption
- [ ] Integrate with backup monitoring dashboard
- [ ] Automated restore testing
- [ ] Cloud backup automation
- [ ] Backup deduplication reporting
