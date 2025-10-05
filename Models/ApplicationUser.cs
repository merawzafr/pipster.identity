using Microsoft.AspNetCore.Identity;

namespace Pipster.Identity.Models;

/// <summary>
/// Custom user entity extending ASP.NET Core Identity.
/// Links authentication to Pipster tenants.
/// </summary>
public class ApplicationUser : IdentityUser
{
    /// <summary>
    /// Reference to the tenant in pipster-api.
    /// This is the primary key from the Tenants table in the main API database.
    /// </summary>
    public string TenantId { get; set; } = string.Empty;

    /// <summary>
    /// User's display name shown in the UI.
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    /// When the user account was created.
    /// </summary>
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    /// <summary>
    /// Last time the user logged in.
    /// Updated by login page.
    /// </summary>
    public DateTimeOffset? LastLoginAt { get; set; }

    /// <summary>
    /// Whether the user account is active.
    /// Matches the tenant status in pipster-api.
    /// </summary>
    public bool IsActive { get; set; } = true;
}