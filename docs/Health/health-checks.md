# Health Checks - Pipster Identity Server

## Overview

The Identity Server implements comprehensive health checks for monitoring application health, readiness, and liveness. These endpoints are crucial for container orchestration (Docker, Kubernetes) and production monitoring.

---

## Health Check Endpoints

### 1. `/health` - Comprehensive Health Check

**Purpose**: Full system health status with detailed diagnostics

**Use Case**: 
- Monitoring dashboards
- Detailed health reports
- Debugging issues

**Response Format**:
```json
{
  "status": "Healthy",
  "timestamp": "2025-10-05T10:30:00Z",
  "checks": [
    {
      "name": "database",
      "status": "Healthy",
      "description": "Database is healthy",
      "duration": 45.3,
      "data": {
        "database": "PostgreSQL",
        "connection": "healthy",
        "pending_migrations": false
      }
    },
    {
      "name": "identityserver",
      "status": "Healthy",
      "description": "IdentityServer is healthy",
      "duration": 12.7,
      "data": {
        "identity_server": "operational",
        "discovery_endpoint": "healthy"
      }
    }
  ]
}
```

**Possible Statuses**:
- `Healthy`: All checks passed
- `Degraded`: Some non-critical checks failed
- `Unhealthy`: Critical checks failed

**HTTP Status Codes**:
- `200 OK`: Healthy
- `503 Service Unavailable`: Unhealthy

---

### 2. `/health/ready` - Readiness Probe

**Purpose**: Indicates if the application is ready to accept traffic

**Use Case**:
- Kubernetes readiness probe
- Load balancer health checks
- Zero-downtime deployments

**Checks Performed**:
- Database connectivity (tagged: `ready`)
- IdentityServer initialization (tagged: `ready`)

**Response Format**:
```json
{
  "status": "Healthy",
  "timestamp": "2025-10-05T10:30:00Z"
}
```

**When It Returns Unhealthy**:
- Database connection failed
- IdentityServer not properly configured
- Application dependencies unavailable

---

### 3. `/health/live` - Liveness Probe

**Purpose**: Indicates if the application process is alive

**Use Case**:
- Kubernetes liveness probe
- Container restart decisions
- Deadlock detection

**Checks Performed**: 
- None (lightweight check)
- Returns `200 OK` if the app is running

**Response**: HTTP `200 OK` (empty body)

**When It Fails**:
- Application process crashed
- Web server unresponsive
- Process deadlocked

---

## Docker Compose Integration

The `docker-compose.yml` uses the `/health` endpoint for container health monitoring:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:80/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

**Parameters**:
- `interval`: Check every 30 seconds
- `timeout`: Wait max 10 seconds for response
- `retries`: Mark unhealthy after 3 failures
- `start_period`: Grace period of 60s on container start

---

## Kubernetes Configuration Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pipster-identity
spec:
  containers:
  - name: identity
    image: pipster-identity:latest
    ports:
    - containerPort: 80
    
    # Liveness: restart if process is dead
    livenessProbe:
      httpGet:
        path: /health/live
        port: 80
      initialDelaySeconds: 60
      periodSeconds: 30
      timeoutSeconds: 5
      failureThreshold: 3
    
    # Readiness: remove from load balancer if not ready
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 80
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
```

---

## Health Check Components

### DatabaseHealthCheck

**Location**: `Health/DatabaseHealthCheck.cs`

**Responsibilities**:
- Verifies PostgreSQL connectivity
- Checks for pending migrations
- Reports connection status

**Dependencies**:
- `ApplicationDbContext`
- `ILogger<DatabaseHealthCheck>`

---

### IdentityServerHealthCheck

**Location**: `Health/IdentityServerHealthCheck.cs`

**Responsibilities**:
- Validates IdentityServer configuration
- Checks discovery document generation
- Confirms operational status

**Dependencies**:
- `IDiscoveryResponseGenerator` (Duende IdentityServer)
- `ILogger<IdentityServerHealthCheck>`

---

## Testing Health Endpoints

### Local Development

```bash
# Full health check
curl http://localhost:5000/health | jq

# Readiness check
curl http://localhost:5000/health/ready | jq

# Liveness check
curl http://localhost:5000/health/live
```

### Docker Container

```bash
# Check container health status
docker ps --format "table {{.Names}}\t{{.Status}}"

# View health check logs
docker inspect pipster-identity | jq '.[0].State.Health'

# Execute health check manually
docker exec pipster-identity curl -f http://localhost:80/health
```

---

## Monitoring Integration

### Application Insights

Health check failures are logged to Application Insights with structured data:

```csharp
// Automatic telemetry on health check failures
{
  "severity": "Error",
  "message": "Database health check failed",
  "customDimensions": {
    "check_name": "database",
    "error": "Connection refused",
    "database": "PostgreSQL"
  }
}
```

### Prometheus (Future)

Add `AspNetCore.HealthChecks.Publisher.Prometheus` package for metrics:

```
# HELP health_check_status Health check status (1 = Healthy, 0 = Unhealthy)
# TYPE health_check_status gauge
health_check_status{name="database"} 1
health_check_status{name="identityserver"} 1
```

---

## Troubleshooting

### Health Check Fails Immediately

**Symptom**: `/health` returns 503 immediately

**Possible Causes**:
1. Database connection string incorrect
2. PostgreSQL not running
3. IdentityServer misconfigured

**Debug Steps**:
```bash
# Check database connectivity
docker exec pipster-postgres psql -U postgres -d pipster_identity_dev -c "SELECT 1"

# View application logs
docker logs pipster-identity

# Check health endpoint response
curl -v http://localhost:5000/health
```

---

### Health Check Timeout

**Symptom**: Health check takes >10 seconds

**Possible Causes**:
1. Database query timeout
2. Network latency
3. Resource exhaustion

**Mitigation**:
- Increase timeout in healthcheck configuration
- Add database connection pooling
- Review slow queries

---

### Container Keeps Restarting

**Symptom**: Docker container in restart loop

**Possible Causes**:
1. Health check failing continuously
2. Application crash on startup
3. Invalid health check command

**Debug Steps**:
```bash
# Disable healthcheck temporarily
docker-compose up -d --no-healthcheck

# Check startup logs
docker logs -f pipster-identity

# Test health endpoint manually
docker exec pipster-identity curl http://localhost:80/health
```

---

## Best Practices

### ✅ DO

- Use `/health/live` for liveness probes (lightweight)
- Use `/health/ready` for readiness probes (comprehensive)
- Set appropriate timeouts (30s interval, 10s timeout)
- Allow grace period on startup (60s+)
- Log health check failures with context

### ❌ DON'T

- Don't use `/health` for liveness (too heavy)
- Don't set overly aggressive timeouts (<10s)
- Don't restart containers on first failure (use retries)
- Don't expose sensitive data in health responses
- Don't skip health checks in production

---

## Next Steps

1. **Add Custom Health Checks**:
   - Redis connectivity (if caching added)
   - External API dependencies
   - Disk space checks

2. **Integrate with Monitoring**:
   - Prometheus metrics
   - Grafana dashboards
   - PagerDuty alerts

3. **Performance Testing**:
   - Load test health endpoints
   - Verify sub-second response times
   - Test under degraded conditions

---

## References

- [ASP.NET Core Health Checks](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks)
- [Kubernetes Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)