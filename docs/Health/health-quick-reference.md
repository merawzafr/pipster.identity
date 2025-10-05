# Health Checks - Quick Reference Card

## 🔗 Endpoints

| Endpoint | Purpose | Use Case | Response Time |
|----------|---------|----------|---------------|
| `/health` | Full health check | Monitoring, debugging | ~50-100ms |
| `/health/ready` | Readiness probe | K8s readiness, LB | ~50-100ms |
| `/health/live` | Liveness probe | K8s liveness | <10ms |

---

## 🧪 Quick Tests

```bash
# All tests (automated)
./test-health.sh

# Individual endpoints
curl http://localhost:5000/health | jq
curl http://localhost:5000/health/ready | jq
curl http://localhost:5000/health/live
```

---

## 🐳 Docker Commands

```bash
# Container health status
docker ps --format "table {{.Names}}\t{{.Status}}"

# Health check logs
docker inspect pipster-identity | jq '.[0].State.Health'

# Watch logs
docker logs -f pipster-identity | grep -i health

# Disable healthcheck (debugging)
docker-compose up -d --no-healthcheck
```

---

## 📊 Health Statuses

| Status | Meaning | HTTP Code | Action |
|--------|---------|-----------|--------|
| `Healthy` | All checks passed | 200 | None |
| `Degraded` | Some checks failed | 200 | Investigate |
| `Unhealthy` | Critical failure | 503 | Alert/Fix |

---

## ⚙️ Kubernetes Config (Copy-Paste Ready)

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 80
  initialDelaySeconds: 60
  periodSeconds: 30
  
readinessProbe:
  httpGet:
    path: /health/ready
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10
```

---

## 🚨 Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| 503 on `/health` | DB down | Check PostgreSQL container |
| Container restarting | Failed healthcheck | Check logs: `docker logs` |
| Slow response | DB timeout | Check connection pool |
| "Unhealthy" status | Config issue | Review `appsettings.json` |

---

## 📝 Files to Know

```
Health/DatabaseHealthCheck.cs          ← DB connectivity check
Health/IdentityServerHealthCheck.cs    ← IdentityServer check
Program.cs                             ← Endpoint registration
docker-compose.yml                     ← Healthcheck config
docs/HEALTH_CHECKS.md                  ← Full documentation
```

---

## 🎯 Production Checklist

```bash
✓ Health endpoints return 200 OK
✓ Docker healthcheck shows "healthy"
✓ Liveness probe < 10ms response
✓ Readiness probe passes on startup
✓ 60s grace period configured
✓ Alerts configured for failures
```

---

## 🔄 Next: Environment Variables

Recommended next step: **Option B** - `.env` file

```bash
# Currently hardcoded (⚠️ not production-ready)
POSTGRES_PASSWORD=postgres

# Should be externalized
POSTGRES_PASSWORD=${DB_PASSWORD}
```

This secures credentials and enables per-environment configuration.