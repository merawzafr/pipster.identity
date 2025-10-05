# Pipster Identity Server

ASP.NET Core Identity Server implementation for Pipster - A SaaS trading signal auto-execution platform.

---

## 🚀 Quick Start

### Prerequisites

- Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- Git
- Optional: .NET 9 SDK (for local development without Docker)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd pipster.identity
   ```

2. **Create environment configuration**
   ```bash
   # Linux/Mac
   ./setup-env.sh development
   
   # Windows
   .\setup-env.ps1 -Environment Development
   ```

3. **Review and customize .env**
   ```bash
   # Edit if needed (dev defaults are fine for local development)
   code .env  # or vim .env
   ```

4. **Validate configuration**
   ```bash
   ./validate-env.sh  # Linux/Mac
   ```

5. **Start services**
   ```bash
   docker-compose up -d
   ```

6. **Verify health**
   ```bash
   # Linux/Mac
   ./test-health.sh
   
   # Windows
   .\test-health.ps1
   
   # Or manually
   curl http://localhost:5000/health
   ```

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────┐
│              Pipster Identity Server            │
├─────────────────────────────────────────────────┤
│  ASP.NET Core 9 + Duende IdentityServer         │
│  - OAuth 2.0 / OpenID Connect                   │
│  - Multi-tenant B2C authentication              │
│  - JWT token issuance                           │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │   PostgreSQL 16     │
         │   - User accounts   │
         │   - Client configs  │
         │   - Consent data    │
         └─────────────────────┘
```

---

## 🔧 Configuration

### Environment Variables

Configuration is managed through `.env` files. See [ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) for complete documentation.

**Key variables:**

| Variable | Description | Default (Dev) |
|----------|-------------|---------------|
| `ASPNETCORE_ENVIRONMENT` | Runtime environment | `Development` |
| `POSTGRES_PASSWORD` | Database password | `postgres` |
| `IDENTITYSERVER_ISSUER_URI` | Public IdentityServer URL | `http://localhost:5000` |
| `LOG_LEVEL` | Application log level | `Information` |

**Production-specific:**

| Variable | Required | Description |
|----------|----------|-------------|
| `JWT_SIGNING_KEY` | ✅ | 256-bit JWT signing key |
| `DATA_PROTECTION_KEY` | ✅ | ASP.NET Data Protection key |
| `IDENTITYSERVER_ISSUER_URI` | ✅ | Must use HTTPS |

---

## 🏥 Health Checks

Three health check endpoints for different purposes:

| Endpoint | Purpose | Use Case |
|----------|---------|----------|
| `/health` | Full status with details | Monitoring, debugging |
| `/health/ready` | Readiness check | Kubernetes readiness probe |
| `/health/live` | Liveness check | Kubernetes liveness probe |

**Example:**
```bash
# Full health status
curl http://localhost:5000/health | jq

# Quick liveness check
curl http://localhost:5000/health/live
```

See [HEALTH_CHECKS.md](docs/Health/HEALTH_CHECKS.md) for detailed documentation.

---

## 🐳 Docker Commands

### Basic Operations

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f identity

# Restart services
docker-compose restart

# Rebuild and start
docker-compose up -d --build
```

### Troubleshooting

```bash
# Check container status
docker-compose ps

# Check health status
docker ps --format "table {{.Names}}\t{{.Status}}"

# View detailed container health
docker inspect pipster-identity | jq '.[0].State.Health'

# Access container shell
docker exec -it pipster-identity /bin/bash

# View PostgreSQL logs
docker-compose logs postgres
```

---

## 📁 Project Structure

```
pipster.identity/
├── .env                          # Active configuration (not committed)
├── .env.example                  # Configuration template
├── .env.staging                  # Staging template
├── .env.production               # Production template
├── docker-compose.yml            # Docker services configuration
├── Dockerfile                    # Multi-stage production build
├── setup-env.sh/ps1             # Environment setup scripts
├── validate-env.sh              # Configuration validator
├── test-health.sh/ps1           # Health check test scripts
├── Health/
│   ├── DatabaseHealthCheck.cs   # PostgreSQL connectivity check
│   └── IdentityServerHealthCheck.cs  # IdentityServer validation
├── docs/
│   ├── ENVIRONMENT_VARIABLES.md # Environment config guide
│   └── Health/
│       ├── HEALTH_CHECKS.md     # Health check documentation
│       └── health-quick-reference.md
└── appsettings.json             # Base application settings
```

---

## 🔒 Security

### Development

- Default credentials (`postgres/postgres`) are acceptable
- HTTP endpoints are fine for local testing
- Detailed error pages enabled

### Production

**Requirements:**
- ✅ All default passwords changed
- ✅ Secrets stored in Azure Key Vault
- ✅ HTTPS enforced
- ✅ JWT signing keys generated
- ✅ Data Protection keys configured
- ✅ `.env` never committed to git

**Generate secure keys:**
```bash
# JWT Signing Key
openssl rand -base64 32

# Data Protection Key
openssl rand -base64 32

# Or use setup script (automatic)
./setup-env.sh production
```

See [ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) for complete security checklist.

---

## 🧪 Testing

### Automated Tests

```bash
# All health checks
./test-health.sh

# Individual endpoints
curl http://localhost:5000/health
curl http://localhost:5000/health/ready
curl http://localhost:5000/health/live
```

### Manual Testing

1. **Check containers are healthy**
   ```bash
   docker ps
   # Both containers should show "healthy"
   ```

2. **Verify database connection**
   ```bash
   docker exec -it pipster-postgres psql -U postgres -c "\l"
   ```

3. **Test IdentityServer configuration**
   ```bash
   curl http://localhost:5000/.well-known/openid-configuration
   ```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) | Complete environment configuration guide |
| [HEALTH_CHECKS.md](docs/Health/HEALTH_CHECKS.md) | Health check implementation details |
| [health-quick-reference.md](docs/Health/health-quick-reference.md) | Quick reference card |

---

## 🚢 Deployment

### Development

```bash
./setup-env.sh development
docker-compose up -d
```

### Staging

```bash
./setup-env.sh staging
# Edit .env with staging credentials
./validate-env.sh
docker-compose up -d
```

### Production

```bash
./setup-env.sh production
# CRITICAL: Update all CHANGE_ME placeholders
# Store secrets in Azure Key Vault
./validate-env.sh  # Must pass
docker-compose up -d
```

**Production Checklist:**
- [ ] All default passwords changed
- [ ] Secrets in Azure Key Vault
- [ ] SSL/TLS certificates configured
- [ ] Database backups enabled
- [ ] Monitoring & alerting set up
- [ ] `.env` in `.gitignore` verified
- [ ] Disaster recovery tested

---

## 🔄 Environment Migration

### Switching Environments

```bash
# Copy current .env
cp .env .env.backup

# Create new environment
./setup-env.sh staging

# Restore if needed
cp .env.backup .env
```

### Using Specific .env Files

```bash
# Use staging config
docker-compose --env-file .env.staging up -d

# Use production config
docker-compose --env-file .env.production up -d
```

---

## 🐛 Troubleshooting

### Common Issues

**1. Containers won't start**
```bash
# Check logs
docker-compose logs

# Verify .env is properly formatted
cat .env

# Validate configuration
./validate-env.sh
```

**2. Database connection errors**
```bash
# Check if PostgreSQL is healthy
docker ps

# Verify connection string
docker-compose config | grep ConnectionStrings

# Test database directly
docker exec -it pipster-postgres psql -U postgres
```

**3. Health checks failing**
```bash
# Check detailed health status
curl http://localhost:5000/health | jq

# View application logs
docker-compose logs identity

# Restart services
docker-compose restart
```

**4. Environment variables not loading**
```bash
# Recreate containers (required after .env changes)
docker-compose down
docker-compose up -d

# Verify what Docker sees
docker-compose config
```

---

## 🤝 Contributing

1. Never commit `.env` files with real credentials
2. Update `.env.example` when adding new variables
3. Run `./validate-env.sh` before committing
4. Test all environments (dev/staging/prod templates)
5. Update documentation

---

## 📝 License

[Your License Here]

---

## 🆘 Support

- Documentation: `docs/` directory
- Health Check Issues: See `docs/Health/HEALTH_CHECKS.md`
- Environment Issues: See `docs/ENVIRONMENT_VARIABLES.md`
- Validation: Run `./validate-env.sh`

---

## 🎯 Next Steps

After successful setup:

1. **Configure Azure Resources**
   - Azure Key Vault for secrets
   - Application Insights for monitoring
   - Azure Database for PostgreSQL (production)

2. **Integrate with Pipster API**
   - Configure OAuth clients
   - Set up API scopes
   - Test authentication flow

3. **Set Up CI/CD**
   - GitHub Actions / Azure DevOps
   - Automated testing
   - Secret injection from Key Vault

4. **Enable Production Monitoring**
   - Application Insights dashboards
   - Health check alerts
   - Performance metrics

---

## 📊 Performance

### Resource Requirements

**Development:**
- CPU: 2 cores
- Memory: 2GB
- Disk: 5GB

**Production:**
- CPU: 4+ cores
- Memory: 4GB+
- Disk: 20GB+ (with logs/backups)

### Benchmarks

| Metric | Target | Measured |
|--------|--------|----------|
| Health check response time | < 100ms | ~50-80ms |
| Database connection pool | 10-100 | Configurable |
| Startup time | < 60s | ~30-45s |
| Container health grace period | 60s | 60s |

---

## 🔗 Related Projects

- **Pipster API** - Main trading API
- **Pipster Workers** - Background job processing
- **Pipster Application** - Business logic layer
- **Pipster Infrastructure** - Telegram integration & external services

---

## 📞 Contact

For questions about Identity Server setup:
- Review documentation in `docs/`
- Check troubleshooting section
- Run validation: `./validate-env.sh`

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-05  
**Status:** ✅ Production Ready (with proper configuration)