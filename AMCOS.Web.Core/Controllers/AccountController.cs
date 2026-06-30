using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Mvc;

namespace AMCOS.Web.Core.Controllers;

[Route("account")]
public class AccountController : Controller
{
    [HttpGet("login")]
    public IActionResult Login(string? returnUrl = null)
    {
        var redirectUri = string.IsNullOrWhiteSpace(returnUrl) ? "/" : returnUrl;
        return Challenge(new AuthenticationProperties { RedirectUri = redirectUri }, OpenIdConnectDefaults.AuthenticationScheme);
    }

    [HttpPost("logout")]
    [ValidateAntiForgeryToken]
    public IActionResult Logout()
    {
        // After the OIDC end-session round-trip (which clears the local cookie and ends the
        // Keycloak SSO session via id_token_hint), land on the login endpoint. /account/login is
        // anonymous and issues a fresh OIDC challenge, so the user reliably ends on the Keycloak
        // login page. Redirecting to "/" instead relied on the home page's [Authorize] re-challenge,
        // which is indirect and did not consistently surface the login page.
        var properties = new AuthenticationProperties { RedirectUri = "/account/login" };
        return SignOut(properties, CookieAuthenticationDefaults.AuthenticationScheme, OpenIdConnectDefaults.AuthenticationScheme);
    }

    [HttpPost("keepalive")]
    [Microsoft.AspNetCore.Authorization.Authorize]
    [ValidateAntiForgeryToken]
    public IActionResult KeepAlive()
    {
        // Touching the cookie auth middleware renews the sliding expiration.
        var timeout = (int)TimeSpan.FromMinutes(15).TotalSeconds;
        return Ok(new { AuthenticationTimeout = timeout });
    }
}
