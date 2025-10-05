using Duende.IdentityServer;
using Duende.IdentityServer.Models;

namespace Pipster.Identity;

/// <summary>
/// IdentityServer configuration for clients, scopes, and resources.
/// </summary>
public static class Config
{
    /// <summary>
    /// Identity resources (user claims).
    /// </summary>
    public static IEnumerable<IdentityResource> IdentityResources =>
        new IdentityResource[]
        {
            new IdentityResources.OpenId(),
            new IdentityResources.Profile(),
            new IdentityResources.Email(),
            new IdentityResource
            {
                Name = "tenant",
                DisplayName = "Tenant Information",
                UserClaims = new[] { "tenant_id" }
            }
        };

    /// <summary>
    /// API scopes that clients can request.
    /// </summary>
    public static IEnumerable<ApiScope> ApiScopes =>
        new ApiScope[]
        {
            new ApiScope("pipster.api", "Pipster API")
            {
                UserClaims = new[] { "tenant_id" }
            }
        };

    /// <summary>
    /// Clients that can request tokens.
    /// </summary>
    public static IEnumerable<Client> Clients =>
        new Client[]
        {
            // Next.js Frontend (SPA)
            new Client
            {
                ClientId = "pipster-web",
                ClientName = "Pipster Web Application",

                AllowedGrantTypes = GrantTypes.Code,
                RequirePkce = true,
                RequireClientSecret = false,  // Public client (SPA)
                
                // Redirect URIs (where to send user after login)
                RedirectUris =
                {
                    "http://localhost:3000/api/auth/callback/identityserver",
                    "https://pipster.app/api/auth/callback/identityserver",
                    "https://www.pipster.app/api/auth/callback/identityserver"
                },
                
                // Post-logout redirect URIs
                PostLogoutRedirectUris =
                {
                    "http://localhost:3000",
                    "https://pipster.app",
                    "https://www.pipster.app"
                },
                
                // CORS origins
                AllowedCorsOrigins =
                {
                    "http://localhost:3000",
                    "https://pipster.app",
                    "https://www.pipster.app"
                },

                // Scopes the client can request
                AllowedScopes =
                {
                    IdentityServerConstants.StandardScopes.OpenId,
                    IdentityServerConstants.StandardScopes.Profile,
                    IdentityServerConstants.StandardScopes.Email,
                    "tenant",
                    "pipster.api"
                },

                // Allow refresh tokens
                AllowOfflineAccess = true,
                
                // Token lifetimes
                AccessTokenLifetime = 3600,  // 1 hour
                RefreshTokenExpiration = TokenExpiration.Sliding,
                SlidingRefreshTokenLifetime = 2592000,  // 30 days
                
                // Security settings
                RequireConsent = false,  // No consent screen for first-party app
                AlwaysSendClientClaims = true,
                AlwaysIncludeUserClaimsInIdToken = true
            },

            // Future: Mobile app
            new Client
            {
                ClientId = "pipster-mobile",
                ClientName = "Pipster Mobile App",
                Enabled = false,  // Not implemented yet
                
                AllowedGrantTypes = GrantTypes.Code,
                RequirePkce = true,
                RequireClientSecret = false,

                RedirectUris = { "pipster://callback" },
                PostLogoutRedirectUris = { "pipster://logout" },

                AllowedScopes =
                {
                    IdentityServerConstants.StandardScopes.OpenId,
                    IdentityServerConstants.StandardScopes.Profile,
                    IdentityServerConstants.StandardScopes.Email,
                    "tenant",
                    "pipster.api"
                },

                AllowOfflineAccess = true,
                AccessTokenLifetime = 3600,
                RefreshTokenExpiration = TokenExpiration.Sliding,
                SlidingRefreshTokenLifetime = 2592000
            }
        };
}