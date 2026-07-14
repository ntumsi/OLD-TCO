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
    public async Task<IActionResult> Logout()
    {
        // The OIDC end-session round-trip needs the id_token as id_token_hint. On a normal logout the
        // ticket (stored server-side) still holds it, so we can end the Keycloak SSO session and land
        // back on the login page.
        //
        // On an IDLE-TIMEOUT forced logout the ticket has already expired, so there is no id_token to
        // hint with. Sending an end-session request WITHOUT id_token_hint makes Keycloak prompt / not
        // honor the post-logout redirect, which strands the user and prevents them logging back in.
        // In that case just clear the local cookie and go straight to the login page (a fresh OIDC
        // challenge), which reliably surfaces the Keycloak login.
        var idToken = await HttpContext.GetTokenAsync("id_token");
        if (!string.IsNullOrWhiteSpace(idToken))
        {
            var properties = new AuthenticationProperties { RedirectUri = "/account/login" };
            return SignOut(properties, CookieAuthenticationDefaults.AuthenticationScheme, OpenIdConnectDefaults.AuthenticationScheme);
        }

        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return Redirect("/account/login");
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
