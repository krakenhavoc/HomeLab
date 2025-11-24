# Monitoring Scripts

Health check and monitoring scripts for homelab infrastructure.

## Overview

This directory contains scripts for monitoring system health, performance, and availability.

## Available Scripts

### health-check.sh

Comprehensive health check script for all homelab services.

**Checks:**
- Service availability
- Resource usage (CPU, memory, disk)
- Network connectivity
- VM/container status
- Backup status
- Certificate expiration

### log-analyzer.sh

Analyzes system and application logs for issues.

**Features:**
- Error pattern detection
- Log aggregation
- Anomaly detection
- Report generation

### resource-monitor.sh

Monitors resource usage across the infrastructure.

**Metrics:**
- CPU utilization
- Memory usage
- Disk I/O
- Network traffic
- Temperature sensors

## Monitoring Stack

### Prometheus

Metrics collection and alerting.

```yaml
# Example scrape config
scrape_configs:
  - job_name: 'homelab-nodes'
    static_configs:
      - targets:
        - 'node1.homelab.local:9100'
        - 'node2.homelab.local:9100'
```

### Grafana

Visualization and dashboards.

**Dashboards:**
- Node overview
- VM performance
- Network traffic
- Storage utilization
- Service availability

### Node Exporter

System metrics exporter for Prometheus.

```bash
# Install node exporter
apt install prometheus-node-exporter

# Enable and start
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter
```

## Alert Rules

### Critical Alerts

```yaml
groups:
  - name: critical_alerts
    rules:
      - alert: HighCPUUsage
        expr: node_cpu_seconds_total > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High CPU usage detected"
      
      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk space low on {{ $labels.device }}"
```

## Health Checks

### Service Health Checks

```bash
#!/usr/bin/env bash

check_service() {
    local service=$1
    systemctl is-active --quiet "$service" && echo "OK" || echo "FAILED"
}

check_http() {
    local url=$1
    curl -f -s -o /dev/null "$url" && echo "OK" || echo "FAILED"
}

# Check critical services
echo "Docker: $(check_service docker)"
echo "Nginx: $(check_service nginx)"
echo "Prometheus: $(check_http http://localhost:9090/-/healthy)"
```

### Network Connectivity Checks

```bash
#!/usr/bin/env bash

check_connectivity() {
    local host=$1
    ping -c 1 -W 1 "$host" &> /dev/null && echo "OK" || echo "FAILED"
}

# Check gateway
echo "Gateway: $(check_connectivity 192.168.1.1)"

# Check DNS
echo "DNS: $(check_connectivity 8.8.8.8)"

# Check internet
echo "Internet: $(check_connectivity 1.1.1.1)"
```

## Log Monitoring

### Log Aggregation

```bash
# Collect logs from multiple sources
rsyslog configuration:
*.* @syslog-server.homelab.local:514
```

### Log Analysis

```bash
# Common error patterns
grep -i "error\|failed\|critical" /var/log/syslog

# Security events
grep -i "authentication failure\|sudo" /var/log/auth.log

# Disk errors
grep -i "input/output error" /var/log/kern.log
```

## Performance Monitoring

### CPU Monitoring

```bash
# Top CPU processes
ps aux --sort=-%cpu | head -10

# CPU usage per core
mpstat -P ALL 1 5
```

### Memory Monitoring

```bash
# Memory usage
free -h

# Top memory processes
ps aux --sort=-%mem | head -10
```

### Disk Monitoring

```bash
# Disk usage
df -h

# Disk I/O
iostat -x 1 5

# SMART status
smartctl -a /dev/sda
```

### Network Monitoring

```bash
# Network traffic
iftop -i eth0

# Connection statistics
ss -s

# Bandwidth usage
vnstat -i eth0
```

## Automated Monitoring

### Cron Jobs

```cron
# Hourly health check
0 * * * * /opt/homelab/scripts/monitoring/health-check.sh

# Every 5 minutes resource check
*/5 * * * * /opt/homelab/scripts/monitoring/resource-monitor.sh

# Daily log analysis
0 6 * * * /opt/homelab/scripts/monitoring/log-analyzer.sh
```

## Alerting

### Alert Channels

1. **Email**: Critical alerts
2. **Slack/Discord**: All alerts
3. **SMS**: Critical alerts only (via Twilio)
4. **PagerDuty**: Production incidents

### Alert Script Example

```bash
#!/usr/bin/env bash

send_alert() {
    local severity=$1
    local message=$2
    
    # Send to appropriate channels based on severity
    case $severity in
        critical)
            send_email "$message"
            send_sms "$message"
            ;;
        warning)
            send_slack "$message"
            ;;
        info)
            log_message "$message"
            ;;
    esac
}
```

## Dashboards

### Grafana Dashboards

1. **System Overview**
   - All hosts at a glance
   - Critical metrics
   - Alert summary

2. **Network Dashboard**
   - Traffic graphs
   - Connection statistics
   - Firewall hits

3. **Storage Dashboard**
   - Disk usage trends
   - I/O performance
   - SMART status

4. **Application Dashboard**
   - Service status
   - Response times
   - Error rates

## Troubleshooting

### High CPU Usage

```bash
# Find CPU-intensive processes
top -o %CPU

# Check for runaway processes
ps aux --sort=-%cpu | head -20
```

### High Memory Usage

```bash
# Memory breakdown
smem -tk

# Find memory leaks
valgrind --leak-check=full ./program
```

### Disk Issues

```bash
# Check for large files
du -sh /* | sort -hr | head -10

# Find deleted files still held by processes
lsof | grep deleted
```

## Best Practices

1. **Baseline Metrics**: Establish normal performance baselines
2. **Alert Tuning**: Reduce false positives
3. **Regular Reviews**: Review metrics and alerts weekly
4. **Documentation**: Document all monitoring procedures
5. **Retention**: Keep metrics for trend analysis

## Integration

### With Ansible

```yaml
- name: Deploy monitoring agents
  hosts: all
  tasks:
    - name: Install node exporter
      apt:
        name: prometheus-node-exporter
        state: present
```

### With Terraform

```hcl
resource "proxmox_vm_qemu" "monitoring" {
  # Monitoring VM configuration
}
```

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Node Exporter Guide](https://github.com/prometheus/node_exporter)

## Future Enhancements

- [ ] Machine learning for anomaly detection
- [ ] Automated remediation scripts
- [ ] Enhanced log correlation
- [ ] Custom metric exporters
- [ ] Mobile monitoring app
