using Duende.IdentityServer.ResponseHandling;
using Duende.IdentityServer.Services;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Pipster.Identity.Health;

/// <summary>
/// Health check for IdentityServer discovery document endpoint
/// Validates that IdentityServer is properly configured and responding
/// </summary>
public class IdentityServerHealthCheck : IHealthCheck
{
    private readonly IDiscoveryResponseGenerator _discoveryResponseGenerator;
    private readonly ILogger<IdentityServerHealthCheck> _logger;

    public IdentityServerHealthCheck(
        IDiscoveryResponseGenerator discoveryResponseGenerator,
        ILogger<IdentityServerHealthCheck> logger)
    {
        _discoveryResponseGenerator = discoveryResponseGenerator;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Generate discovery document (this validates IdentityServer configuration)
            var discoveryResponse = await _discoveryResponseGenerator
                .CreateDiscoveryDocumentAsync("", "");

            if (discoveryResponse == null)
            {
                return HealthCheckResult.Unhealthy(
                    "IdentityServer discovery document is null");
            }

            var data = new Dictionary<string, object>
            {
                { "identity_server", "operational" },
                { "discovery_endpoint", "healthy" }
            };

            return HealthCheckResult.Healthy(
                "IdentityServer is healthy",
                data);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "IdentityServer health check failed");

            return HealthCheckResult.Unhealthy(
                "IdentityServer health check failed",
                ex,
                new Dictionary<string, object>
                {
                    { "identity_server", "unhealthy" },
                    { "error", ex.Message }
                });
        }
    }
}