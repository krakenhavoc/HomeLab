# Deployment Scripts

Automation scripts for deploying and managing services in the homelab.

## Overview

This directory contains scripts for automated deployment, updates, and management of homelab services.

## Available Scripts

### deploy-service.sh

Generic service deployment script.

**Features:**
- Docker container deployment
- Kubernetes pod deployment
- Configuration management
- Health check validation
- Rollback on failure

### rolling-update.sh

Perform rolling updates with zero downtime.

**Features:**
- Gradual service updates
- Health checks between updates
- Automatic rollback on failure
- Blue-green deployment support

### rollback.sh

Rollback to previous service version.

**Features:**
- Version history tracking
- Quick rollback capability
- Configuration restoration
- Data preservation

## Deployment Strategies

### Blue-Green Deployment

```bash
#!/usr/bin/env bash

# Deploy new version (green)
deploy_green_environment

# Run tests on green
test_green_environment

# Switch traffic to green
switch_traffic_to_green

# Decommission blue (old version)
cleanup_blue_environment
```

### Canary Deployment

```bash
#!/usr/bin/env bash

# Deploy canary version (10% traffic)
deploy_canary 0.1

# Monitor metrics
monitor_canary_metrics

# Gradually increase traffic
for percentage in 0.25 0.5 0.75 1.0; do
    increase_canary_traffic $percentage
    monitor_and_validate
done
```

### Rolling Update

```bash
#!/usr/bin/env bash

# Update nodes one at a time
for node in "${nodes[@]}"; do
    drain_node "$node"
    update_node "$node"
    validate_node "$node"
    uncordon_node "$node"
done
```

## Docker Deployment

### Docker Compose Deployment

```bash
#!/usr/bin/env bash

deploy_docker_compose() {
    local compose_file=$1

    # Pull latest images
    docker-compose -f "$compose_file" pull

    # Deploy services
    docker-compose -f "$compose_file" up -d

    # Verify deployment
    docker-compose -f "$compose_file" ps
}
```

### Docker Stack Deployment

```bash
#!/usr/bin/env bash

deploy_stack() {
    local stack_name=$1
    local compose_file=$2

    # Deploy stack
    docker stack deploy -c "$compose_file" "$stack_name"

    # Wait for services
    docker stack services "$stack_name"
}
```

## Kubernetes Deployment

### Apply Manifests

```bash
#!/usr/bin/env bash

deploy_k8s_app() {
    local manifest_dir=$1

    # Apply configurations
    kubectl apply -f "$manifest_dir/"

    # Wait for rollout
    kubectl rollout status deployment/myapp

    # Verify pods
    kubectl get pods -l app=myapp
}
```

### Helm Chart Deployment

```bash
#!/usr/bin/env bash

deploy_helm_chart() {
    local chart_name=$1
    local release_name=$2

    # Update helm repos
    helm repo update

    # Install/upgrade chart
    helm upgrade --install "$release_name" "$chart_name" \
        --values values.yaml \
        --namespace production

    # Verify release
    helm status "$release_name"
}
```

## Configuration Management

### Environment Variables

```bash
# Load environment configuration
load_env() {
    local env_file=$1
    if [[ -f "$env_file" ]]; then
        set -a
        source "$env_file"
        set +a
    fi
}

# Deploy with environment
load_env ".env.production"
deploy_application
```

### Secret Management

```bash
# Deploy secrets to Kubernetes
kubectl create secret generic app-secrets \
    --from-env-file=secrets.env \
    --namespace=production

# Use vault for secret management
vault kv get -format=json secret/app | jq -r '.data.data'
```

## Health Checks

### HTTP Health Check

```bash
wait_for_healthy() {
    local url=$1
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s "$url/health" > /dev/null; then
            echo "Service is healthy"
            return 0
        fi
        ((attempt++))
        sleep 10
    done

    echo "Service failed to become healthy"
    return 1
}
```

### Service Health Check

```bash
check_service_health() {
    local service=$1

    # Check if running
    systemctl is-active --quiet "$service" || return 1

    # Check if responsive
    curl -f -s http://localhost:8080/health || return 1

    return 0
}
```

## Rollback Procedures

### Automatic Rollback

```bash
deploy_with_rollback() {
    local version=$1
    local previous_version=$(get_current_version)

    # Deploy new version
    if ! deploy_version "$version"; then
        echo "Deployment failed, rolling back..."
        deploy_version "$previous_version"
        return 1
    fi

    # Verify health
    if ! wait_for_healthy; then
        echo "Health check failed, rolling back..."
        deploy_version "$previous_version"
        return 1
    fi

    echo "Deployment successful"
    return 0
}
```

### Manual Rollback

```bash
rollback_service() {
    local service=$1
    local target_version=$2

    echo "Rolling back $service to version $target_version"

    # Stop current version
    stop_service "$service"

    # Deploy previous version
    deploy_version "$service" "$target_version"

    # Start service
    start_service "$service"

    # Verify
    verify_service "$service"
}
```

## Pre-deployment Checks

### Validation Script

```bash
pre_deployment_checks() {
    echo "Running pre-deployment checks..."

    # Check dependencies
    check_dependencies || return 1

    # Validate configuration
    validate_config || return 1

    # Check resources
    check_resources || return 1

    # Verify connectivity
    check_connectivity || return 1

    echo "All pre-deployment checks passed"
    return 0
}
```

## Post-deployment Actions

### Verification Script

```bash
post_deployment_verification() {
    echo "Running post-deployment verification..."

    # Health checks
    verify_health || return 1

    # Smoke tests
    run_smoke_tests || return 1

    # Performance checks
    check_performance || return 1

    # Notify success
    send_notification "Deployment successful"

    return 0
}
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run deployment script
        run: ./scripts/deployment/deploy-service.sh
        env:
          DEPLOY_ENV: production
```

### GitLab CI

```yaml
deploy:
  stage: deploy
  script:
    - ./scripts/deployment/deploy-service.sh
  only:
    - main
  environment:
    name: production
```

## Monitoring Deployment

### Track Deployment Metrics

```bash
track_deployment() {
    local start_time=$(date +%s)

    # Perform deployment
    deploy_application

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Send metrics to Prometheus
    echo "deployment_duration_seconds $duration" | \
        curl --data-binary @- http://pushgateway:9091/metrics/job/deployment
}
```

## Disaster Recovery

### Backup Before Deployment

```bash
deploy_with_backup() {
    local service=$1

    # Create backup
    echo "Creating backup..."
    backup_service "$service"

    # Deploy
    if deploy_service "$service"; then
        echo "Deployment successful"
        return 0
    else
        echo "Deployment failed, restoring backup..."
        restore_service "$service"
        return 1
    fi
}
```

## Best Practices

1. **Always Test First**: Test in dev/staging before production
2. **Incremental Changes**: Deploy small, frequent changes
3. **Automated Testing**: Run automated tests before deployment
4. **Monitoring**: Monitor deployments closely
5. **Documentation**: Document deployment procedures
6. **Rollback Plan**: Always have a rollback strategy
7. **Communication**: Notify team of deployments

## Automation

### Scheduled Deployments

```cron
# Deploy updates weekly
0 2 * * 0 /opt/homelab/scripts/deployment/rolling-update.sh

# Daily configuration sync
0 3 * * * /opt/homelab/scripts/deployment/sync-configs.sh
```

## Troubleshooting

### Deployment Failures

```bash
# Check logs
kubectl logs -f deployment/myapp

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Describe resources
kubectl describe deployment myapp
```

### Service Won't Start

```bash
# Check service status
systemctl status service-name

# View logs
journalctl -u service-name -f

# Check ports
netstat -tlnp | grep :8080
```

## Security Considerations

- Validate inputs
- Use secure credentials management
- Audit deployment actions
- Implement RBAC
- Encrypt sensitive data
- Regular security scans

## Resources

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Helm Charts](https://helm.sh/docs/)

## Future Enhancements

- [ ] Automated canary analysis
- [ ] A/B testing framework
- [ ] Progressive delivery
- [ ] Deployment approval workflows
- [ ] Enhanced rollback automation
- [ ] Deployment analytics dashboard
