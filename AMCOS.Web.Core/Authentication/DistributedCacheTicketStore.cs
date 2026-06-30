using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Options;

namespace AMCOS.Web.Core.Authentication;

/// <summary>
/// Attaches the <see cref="DistributedCacheTicketStore"/> to the cookie authentication scheme.
/// Runs as a post-configure step so it reliably wins over the scheme's own option setup.
/// </summary>
public sealed class ConfigureCookieTicketStore : IPostConfigureOptions<CookieAuthenticationOptions>
{
    private readonly ITicketStore _store;

    public ConfigureCookieTicketStore(ITicketStore store) => _store = store;

    public void PostConfigure(string? name, CookieAuthenticationOptions options)
    {
        if (name == CookieAuthenticationDefaults.AuthenticationScheme)
        {
            options.SessionStore = _store;
        }
    }
}

/// <summary>
/// Server-side store for authentication tickets, backed by <see cref="IDistributedCache"/>.
/// <para>
/// Without this, the full ticket (including the OIDC access/id/refresh tokens and all
/// user-info claims) is serialized into the auth cookie. With Keycloak that ticket is ~8&nbsp;KB,
/// forcing the cookie to be split into multiple chunks that sit right at the request-header
/// size limit. Any additional cookie on a later request (e.g. the antiforgery cookie that every
/// page with a form sets) pushes the combined <c>Cookie</c> header over the limit, the chunked
/// auth cookie fails to reassemble, and the request silently becomes unauthenticated.
/// </para>
/// <para>
/// Storing the ticket server-side keeps the cookie down to a small session key, so token-heavy
/// principals no longer break authentication. Tokens saved via <c>SaveTokens = true</c> (used by
/// the sign-out flow for <c>id_token_hint</c>) remain available through the ticket.
/// </para>
/// </summary>
public sealed class DistributedCacheTicketStore : ITicketStore
{
    private const string KeyPrefix = "auth-ticket:";
    private readonly IDistributedCache _cache;

    public DistributedCacheTicketStore(IDistributedCache cache) => _cache = cache;

    public async Task<string> StoreAsync(AuthenticationTicket ticket)
    {
        var key = KeyPrefix + Guid.NewGuid().ToString("N");
        await RenewAsync(key, ticket);
        return key;
    }

    public async Task RenewAsync(string key, AuthenticationTicket ticket)
    {
        var options = new DistributedCacheEntryOptions();
        var expiresUtc = ticket.Properties.ExpiresUtc;
        if (expiresUtc.HasValue)
        {
            options.SetAbsoluteExpiration(expiresUtc.Value);
        }
        else
        {
            // Fall back to a sliding window so abandoned tickets do not accumulate forever.
            options.SetSlidingExpiration(TimeSpan.FromHours(8));
        }

        var bytes = TicketSerializer.Default.Serialize(ticket);
        await _cache.SetAsync(key, bytes, options);
    }

    public async Task<AuthenticationTicket?> RetrieveAsync(string key)
    {
        var bytes = await _cache.GetAsync(key);
        return bytes is null ? null : TicketSerializer.Default.Deserialize(bytes);
    }

    public Task RemoveAsync(string key) => _cache.RemoveAsync(key);
}
