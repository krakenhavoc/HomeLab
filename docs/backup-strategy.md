# Backup Strategy

## Overview

This document outlines the backup strategy for the homelab environment, including what data is backed up, backup schedules, retention policies, and disaster recovery procedures.

## Backup Philosophy

The backup strategy follows the **3-2-1 rule**:
- **3** copies of data
- **2** different storage media types
- **1** off-site backup

## Backup Scope

### What Gets Backed Up

#### Critical (Daily Backups)
- VM configurations and metadata
- Database dumps
- Application configurations
- User data and documents
- Docker volumes for critical services
- Network device configurations

#### Important (Weekly Backups)
- Full VM disk images
- Media libraries metadata
- Development repositories
- Application logs (rotated)

#### Archive (Monthly Backups)
- Historical data
- Old VM snapshots
- Audit logs
- Documentation archives

### What's Not Backed Up
- Temporary files
- Cache directories
- ISO images and installation media
- Easily re-downloadable content
- Test/development environments

## Backup Infrastructure

### Primary Backup Storage

**Proxmox Backup Server (PBS)**
- Location: Dedicated backup server
- Storage: ZFS pool with snapshots
- Deduplication and compression enabled
- Incremental backups

### Secondary Backup Storage

**TrueNAS NAS**
- Network-attached storage
- Replicated from PBS
- ZFS snapshots for point-in-time recovery

### Off-site Backup

**Cloud Storage**
- Encrypted backups to cloud provider
- Critical data only (cost optimization)
- Monthly sync from NAS

## Backup Schedules

### Automated Backup Times

```
Daily Backups:     02:00 AM (Low activity period)
Weekly Backups:    Sunday 03:00 AM
Monthly Backups:   1st Sunday 04:00 AM
```

### Service-Specific Schedules

| Service | Frequency | Retention |
|---------|-----------|-----------|
| Database VMs | Daily | 7 days |
| Application VMs | Daily | 14 days |
| File Server | Daily | 30 days |
| Development VMs | Weekly | 4 weeks |
| Docker Volumes | Daily | 7 days |

## Retention Policy

### Short-term Retention (On-site)
- Daily backups: 7 days
- Weekly backups: 4 weeks
- Monthly backups: 12 months

### Long-term Retention (Off-site)
- Monthly archives: 2 years
- Yearly archives: 5 years
- Critical business data: 7 years

### Cleanup Policy
- Automated cleanup based on retention policy
- Manual review before deleting monthly archives
- Alerts for backup storage capacity > 80%

## Backup Methods

### Proxmox VE Virtual Machines

```bash
# Manual backup command
vzdump <vmid> --storage pbs-backup --mode snapshot --compress zstd

# Scheduled backup (configured in Proxmox UI)
# Datacenter > Backup > Add
```

### Docker Volumes

```bash
# Backup script example
#!/bin/bash
docker run --rm \
  -v volume_name:/data \
  -v /backup:/backup \
  alpine tar czf /backup/volume_name-$(date +%Y%m%d).tar.gz /data
```

### Database Backups

```bash
# PostgreSQL
pg_dump -U postgres dbname | gzip > /backup/dbname-$(date +%Y%m%d).sql.gz

# MySQL/MariaDB
mysqldump -u root -p dbname | gzip > /backup/dbname-$(date +%Y%m%d).sql.gz

# MongoDB
mongodump --out /backup/mongodb-$(date +%Y%m%d)
```

### Configuration Files

```bash
# Ansible playbook for config backup
ansible-playbook backup-configs.yml

# Backed up configs:
# - /etc/
# - Network device configs
# - Application configs
# - SSL certificates
```

## Monitoring and Verification

### Backup Monitoring

**Automated Checks**
- Backup job completion status
- Backup size trends
- Storage capacity monitoring
- Integrity verification

**Alerts Configured For**
- Failed backup jobs
- Backup duration > expected time
- Storage capacity warnings
- Verification failures

### Backup Verification

**Weekly Verification**
- Random backup restore test
- Integrity check on backup files
- Verification logs reviewed

**Monthly Verification**
- Full restore test of critical VM
- Database restore test
- Application restore test

## Disaster Recovery

### Recovery Time Objective (RTO)
- Critical services: 1 hour
- Important services: 4 hours
- Non-critical services: 24 hours

### Recovery Point Objective (RPO)
- Critical data: 1 hour (incremental)
- Important data: 24 hours
- Archive data: 30 days

### Disaster Recovery Procedures

#### Complete Infrastructure Loss

1. **Immediate Actions**
   - Assess damage and scope
   - Activate disaster recovery team
   - Set up temporary infrastructure

2. **Recovery Steps**
   ```
   1. Restore hypervisor host
   2. Configure network connectivity
   3. Restore critical VMs from backup
   4. Restore databases
   5. Restore application data
   6. Verify service functionality
   ```

3. **Validation**
   - Test all critical services
   - Verify data integrity
   - Update DNS and network configs
   - Document recovery process

#### Partial Service Loss

1. Identify affected services
2. Restore from most recent backup
3. Validate restored data
4. Resume normal operations

#### Data Corruption

1. Identify corruption extent
2. Restore from pre-corruption backup
3. Replay transaction logs if available
4. Validate data consistency

## Backup Scripts

### Automated Backup Script

Location: `scripts/backup/automated-backup.sh`

Key features:
- Pre-backup health checks
- Parallel backup execution
- Post-backup verification
- Notification on completion/failure

### Restore Script

Location: `scripts/backup/restore.sh`

Capabilities:
- Interactive restore wizard
- Point-in-time recovery
- Validation checks
- Rollback on failure

## Security

### Backup Encryption
- All backups encrypted at rest
- AES-256 encryption
- Keys stored in vault
- Regular key rotation

### Access Control
- Role-based access to backups
- Audit logging of all restore operations
- MFA required for restore operations

### Network Security
- Backup traffic over isolated VLAN
- VPN for off-site replication
- Firewall rules restricting backup access

## Documentation

### Backup Documentation Maintained
- Backup configuration details
- Restore procedures per service
- Recovery runbooks
- Contact information
- Vendor support details

### Change Management
- All backup changes documented
- Testing before production implementation
- Rollback procedures defined

## Metrics and Reporting

### Weekly Reports
- Backup success/failure rates
- Storage utilization trends
- Backup duration trends
- Failed backup analysis

### Monthly Reports
- Comprehensive backup status
- Capacity planning recommendations
- Disaster recovery test results
- Compliance verification

## Future Enhancements

- [ ] Implement continuous data protection (CDP)
- [ ] Add cross-region replication
- [ ] Automate disaster recovery testing
- [ ] Implement immutable backups
- [ ] Add ransomware protection features
- [ ] Enhance monitoring with ML anomaly detection

## Resources

### Tools Used
- Proxmox Backup Server
- Borgmatic
- Restic
- Duplicati
- rclone for cloud sync

### External Documentation
- [Proxmox Backup Server Documentation](https://pbs.proxmox.com/docs/)
- [Best Practices for Backup](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/)
