using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Pipster.Identity.Data;

namespace Pipster.Identity.Health;

/// <summary>
/// Health check for PostgreSQL database connectivity and availability
/// </summary>
public class DatabaseHealthCheck : IHealthCheck
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<DatabaseHealthCheck> _logger;

    public DatabaseHealthCheck(
        ApplicationDbContext context,
        ILogger<DatabaseHealthCheck> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Check database connection by executing a simple query
            var canConnect = await _context.Database.CanConnectAsync(cancellationToken);

            if (!canConnect)
            {
                return HealthCheckResult.Unhealthy(
                    "Cannot connect to the database");
            }

            // Check if migrations are pending (optional but useful)
            var pendingMigrations = await _context.Database
                .GetPendingMigrationsAsync(cancellationToken);

            var hasPendingMigrations = pendingMigrations.Any();

            var data = new Dictionary<string, object>
            {
                { "database", "PostgreSQL" },
                { "connection", "healthy" },
                { "pending_migrations", hasPendingMigrations }
            };

            if (hasPendingMigrations)
            {
                data["pending_migration_count"] = pendingMigrations.Count();
                _logger.LogWarning(
                    "Database is healthy but has {Count} pending migrations",
                    pendingMigrations.Count());
            }

            return HealthCheckResult.Healthy(
                "Database is healthy",
                data);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database health check failed");

            return HealthCheckResult.Unhealthy(
                "Database health check failed",
                ex,
                new Dictionary<string, object>
                {
                    { "database", "PostgreSQL" },
                    { "error", ex.Message }
                });
        }
    }
}