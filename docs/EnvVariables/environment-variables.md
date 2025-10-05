# Environment Variables Guide

## Overview

Pipster Identity Server uses `.env` files for environment-specific configuration. This approach:

- ✅ Externalizes secrets from code
- ✅ Enables per-environment configuration
- ✅ Improves security posture
- ✅ Simplifies deployment across dev/staging/prod
- ✅ Follows 12-factor app principles

---

## Quick Start

### 1. Create Environment File

```bash
# Development (default)
./setup-env.sh development

# Staging
./setup-env.sh staging

# Production (generates secure passwords)
./setup-env.sh production
```

Or on Windows:
```powershell
# Development
.\setup-env.ps1 -Environment Development

# Production
.\setup-env.ps1 -Environment Production
```

### 2. Validate Configuration

```bash
# Linux/Mac
./validate-env.sh

# Windows
.\validate-env.ps1
```

### 3. Start Services

```bash
docker-compose up -d
```

---

## Environment Files

| File | Purpose | Committed to Git? |
|------|---------|-------------------|
| `.env.example` | Template with documentation | ✅ Yes |
| `.env.staging` | Staging template | ✅ Yes (no real secrets) |
| `.env.production` | Production template | ✅ Yes (no real secrets) |
| `.env` | **Active configuration** | ❌ **NEVER** |

**CRITICAL**: Never commit `.env` to version control!

---

## Environment Variables Reference

### Core Configuration

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `ASPNETCORE_ENVIRONMENT` | Runtime environment | `Development`, `Staging`, `Production` | ✅ |
| `IDENTITYSERVER_ISSUER_URI` | Public URL for IdentityServer | `https://identity.pipster.app` | ✅ |
| `IDENTITYSERVER_PUBLIC_ORIGIN` | Override for reverse proxy | `https://identity.pipster.app` | ❌ |

### Database Configuration

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `POSTGRES_USER` | PostgreSQL username | `postgres` | ✅ |
| `POSTGRES_PASSWORD` | PostgreSQL password | `secure_password_here` | ✅ |
| `POSTGRES_DB` | Database name | `pipster_identity_dev` | ✅ |
| `DB_HOST` | Database hostname | `postgres` (Docker), `azure-db.postgres.database.azure.com` | ✅ |
| `DB_PORT` | Database port | `5432` | ✅ |
| `DB_NAME` | Connection database name | `pipster_identity_dev` | ✅ |
| `DB_USERNAME` | Connection username | `postgres` | ✅ |
| `DB_PASSWORD` | Connection password | `secure_password_here` | ✅ |

### Security (Production)

| Variable | Description | Example | Required in Prod |
|----------|-------------|---------|------------------|
| `JWT_SIGNING_KEY` | JWT token signing key | `<base64-encoded-256-bit-key>` | ✅ |
| `DATA_PROTECTION_KEY` | ASP.NET Data Protection key | `<base64-encoded-key>` | ✅ |

Generate with: `openssl rand -base64 32`

### Application Ports

| Variable | Description | Default |
|----------|-------------|---------|
| `IDENTITY_HTTP_PORT` | Host port for Identity Server | `5000` |
| `POSTGRES_PORT` | Host port for PostgreSQL | `5432` |

### Logging

| Variable | Description | Values | Default |
|----------|-------------|--------|---------|
| `LOG_LEVEL` | Global log level | `Trace`, `Debug`, `Information`, `Warning`, `Error`, `Critical` | `Information` |
| `LOG_LEVEL_MICROSOFT` | Microsoft libraries | Same as above | `Warning` |
| `LOG_LEVEL_DUENDE` | IdentityServer | Same as above | `Information` |

### Health Checks

| Variable | Description | Default |
|----------|-------------|---------|
| `HEALTHCHECK_INTERVAL` | Check frequency | `30s` |
| `HEALTHCHECK_TIMEOUT` | Check timeout | `10s` |
| `HEALTHCHECK_RETRIES` | Retry attempts | `3` |
| `HEALTHCHECK_START_PERIOD` | Grace period on startup | `60s` |

### Docker

| Variable | Description | Values | Default |
|----------|-------------|--------|---------|
| `RESTART_POLICY` | Container restart behavior | `no`, `always`, `on-failure`, `unless-stopped` | `unless-stopped` |

### Performance Tuning (Optional)

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_MAX_POOL_SIZE` | Max connections in pool | `100` |
| `DB_MIN_POOL_SIZE` | Min connections in pool | `10` |
| `DB_CONNECTION_LIFETIME` | Connection lifetime (seconds) | `300` |

---

## Environment-Specific Configurations

### Development

```bash
# Minimal security, verbose logging
ASPNETCORE_ENVIRONMENT=Development
POSTGRES_PASSWORD=postgres  # OK for dev
IDENTITYSERVER_ISSUER_URI=http://localhost:5000
LOG_LEVEL=Information
```

### Staging

```bash
# Production-like, with monitoring
ASPNETCORE_ENVIRONMENT=Staging
POSTGRES_PASSWORD=<strong-password>
IDENTITYSERVER_ISSUER_URI=https://staging-identity.pipster.app
LOG_LEVEL=Information
JWT_SIGNING_KEY=<generated-key>
DATA_PROTECTION_KEY=<generated-key>
```

### Production

```bash
# Maximum security, minimal logging
ASPNETCORE_ENVIRONMENT=Production
POSTGRES_PASSWORD=<azure-key-vault-secret>
IDENTITYSERVER_ISSUER_URI=https://identity.pipster.app
LOG_LEVEL=Warning
RESTART_POLICY=always
JWT_SIGNING_KEY=<azure-key-vault-secret>
DATA_PROTECTION_KEY=<azure-key-vault-secret>
```

---

## Security Best Practices

### ✅ DO

1. **Use strong passwords** (min 32 characters, random)
   ```bash
   openssl rand -base64 32
   ```

2. **Store production secrets in Azure Key Vault**
   - Never hardcode in `.env.production` template
   - Use managed identities where possible

3. **Validate before deployment**
   ```bash
   ./validate-env.sh
   ```

4. **Rotate secrets regularly**
   - Quarterly for production
   - After any security incident

5. **Use different credentials per environment**
   - Never reuse dev passwords in staging/prod

### ❌ DON'T

1. **Never commit `.env` to git**
   ```bash
   # Verify it's ignored
   git status .env
   # Should return: "Untracked files"
   ```

2. **Never log sensitive values**
   - Docker Compose redacts by default
   - Application code must not log passwords/keys

3. **Never share `.env` files**
   - Use secure channels (Azure Key Vault, 1Password)

4. **Never use default passwords in production**
   - Validation script will catch this

---

## Troubleshooting

### `.env` not loading

**Problem**: Changes to `.env` not reflected in containers

**Solution**:
```bash
# Recreate containers to pick up new env vars
docker-compose down
docker-compose up -d
```

### Variable substitution not working

**Problem**: Variables like `${DB_HOST}` not being substituted

**Solution**: Ensure using `docker-compose` (not `docker compose` on older versions)

### Secrets exposed in logs

**Problem**: Sensitive data appearing in `docker logs`

**Solution**:
```bash
# Check what's actually set (Docker redacts secrets)
docker-compose config

# If exposed, review application logging code
```

### Permission denied on scripts

**Problem**: `./setup-env.sh: Permission denied`

**Solution**:
```bash
chmod +x setup-env.sh validate-env.sh
```

---

## Migration from Hardcoded Values

### Before (hardcoded in docker-compose.yml)

```yaml
environment:
  - ConnectionStrings__DefaultConnection=Host=postgres;Port=5432;Database=pipster_identity_dev;Username=postgres;Password=postgres
```

### After (using .env)

**.env**:
```bash
DB_HOST=postgres
DB_PASSWORD=secure_password
```

**docker-compose.yml**:
```yaml
environment:
  - ConnectionStrings__DefaultConnection=Host=${DB_HOST};...;Password=${DB_PASSWORD}
```

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Create .env
  run: |
    echo "POSTGRES_PASSWORD=${{ secrets.DB_PASSWORD }}" >> .env
    echo "JWT_SIGNING_KEY=${{ secrets.JWT_KEY }}" >> .env
```

### Azure DevOps

```yaml
- task: Bash@3
  inputs:
    targetType: 'inline'
    script: |
      echo "POSTGRES_PASSWORD=$(DB_PASSWORD)" >> .env
      echo "JWT_SIGNING_KEY=$(JWT_KEY)" >> .env
```

---

## FAQ

### Q: Should I commit `.env.example`?

**A**: Yes! It serves as documentation and a template.

### Q: How do I share `.env` with team members?

**A**: Don't. Use:
1. Azure Key Vault for production
2. Team documentation for dev defaults
3. `setup-env.sh` to generate local `.env`

### Q: Can I have multiple `.env` files?

**A**: Yes, but only `.env` is loaded by default. Use:
```bash
docker-compose --env-file .env.staging up
```

### Q: What if I accidentally commit `.env`?

**A**: Immediately:
```bash
# Remove from repo
git rm --cached .env
git commit -m "Remove committed .env file"
git push

# Rotate ALL secrets that were in the file
# Update .gitignore to prevent future commits
```

---

## Checklist

### Development Setup
- [ ] Run `./setup-env.sh development`
- [ ] Review `.env` file
- [ ] Run `./validate-env.sh`
- [ ] Start with `docker-compose up -d`
- [ ] Verify health: `./test-health.sh`

### Production Deployment
- [ ] Run `./setup-env.sh production`
- [ ] Replace ALL `CHANGE_ME` placeholders
- [ ] Store secrets in Azure Key Vault
- [ ] Run `./validate-env.sh` (must pass)
- [ ] Verify `.env` is in `.gitignore`
- [ ] Test SSL/TLS certificates
- [ ] Configure monitoring & alerting
- [ ] Document secret rotation procedure
- [ ] Test disaster recovery

---

## Next Steps

After setting up environment variables:

1. **Configure Azure Key Vault** (Production)
   - Store all production secrets
   - Use managed identities
   - Set up secret rotation

2. **Set Up CI/CD Pipeline**
   - Automate environment setup
   - Inject secrets from vault
   - Validate before deployment

3. **Enable Monitoring**
   - Application Insights integration
   - Alert on configuration errors
   - Track secret usage

4. **Document Runbooks**
   - Secret rotation procedure
   - Disaster recovery steps
   - Environment provisioning

---

## Support

For issues or questions:
- Review this documentation
- Check validation output: `./validate-env.sh`
- Consult [12-Factor App](https://12factor.net/config) methodology
- See `docs/HEALTH_CHECKS.md` for related health check configuration