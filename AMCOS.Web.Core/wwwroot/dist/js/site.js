var AMCOS = {
    checkSessionIntervalId: 0,
    loggingout: false,
    validatingSession: false,
    sessionDurationSeconds: 900, // 15 minutes default

    startup: function () {
        AMCOS.validatingSession = true;
        fetch('/account/keepalive', {
            method: 'POST',
            headers: {
                'RequestVerificationToken': document.querySelector('input[name="__RequestVerificationToken"]')?.value ?? ''
            }
        })
        .then(function (res) {
            AMCOS.validatingSession = false;
            if (res.ok) {
                return res.json().then(function (data) {
                    // ASP.NET Core serializes JSON as camelCase by default.
                    var timeout = data.authenticationTimeout ?? data.AuthenticationTimeout;
                    if (timeout) {
                        AMCOS.setNewExpirationTime(timeout);
                        AMCOS.sessionDurationSeconds = timeout;
                    }
                    AMCOS.startTimers();
                });
            } else {
                // Session already invalid — go straight to login (a POST logout would fail
                // antiforgery, since the request is now anonymous).
                AMCOS.sessionExpired();
            }
        })
        .catch(function () {
            AMCOS.validatingSession = false;
            AMCOS.startTimers();
        });
    },

    startTimers: function () {
        AMCOS.checkSession();
        AMCOS.checkSessionIntervalId = setInterval(AMCOS.checkSession, 1000);
    },

    // Explicit logout while the session is STILL valid (the modal's "Log Out" button). Posts the
    // logout form so the OIDC end-session round-trip runs (ends the Keycloak SSO and returns to login).
    forceLogout: function () {
        if (!AMCOS.loggingout) {
            AMCOS.loggingout = true;
            localStorage.removeItem('sessionExpirationTime');
            var modal = bootstrap.Modal.getInstance(document.getElementById('SessionExpiringModal'));
            if (modal) modal.hide();
            var form = document.getElementById('amcos-logout-form');
            if (form) form.submit();
        }
    },

    // Session has already EXPIRED (idle timeout or a 401). The auth cookie is gone, so a POST logout
    // would fail antiforgery and the OIDC end-session would lack id_token_hint (stranding the user on
    // Keycloak). Just clear local state and hit /account/login, which issues a fresh OIDC challenge.
    sessionExpired: function () {
        if (!AMCOS.loggingout) {
            AMCOS.loggingout = true;
            clearInterval(AMCOS.checkSessionIntervalId);
            localStorage.removeItem('sessionExpirationTime');
            var modal = bootstrap.Modal.getInstance(document.getElementById('SessionExpiringModal'));
            if (modal) modal.hide();
            window.location = '/account/login';
        }
    },

    setNewExpirationTime: function (seconds) {
        var expireTime = Date.now() + (seconds * 1000);
        localStorage.setItem('sessionExpirationTime', expireTime);
    },

    checkSession: function () {
        var expireTime = parseInt(localStorage.getItem('sessionExpirationTime'), 10);
        var secondsRemaining = isNaN(expireTime) ? 0 : Math.floor((expireTime - Date.now()) / 1000);
        var modalEl = document.getElementById('SessionExpiringModal');

        if (secondsRemaining <= 0) {
            clearInterval(AMCOS.checkSessionIntervalId);
            AMCOS.sessionExpired();
            return;
        }

        if (secondsRemaining <= 180) {
            if (modalEl && !modalEl.classList.contains('show')) {
                new bootstrap.Modal(modalEl).show();
                if (document.hidden) {
                    var originalTitle = document.title;
                    var stopFlashing = AMCOS.flashTabTitle('\uD83D\uDD34 Session Expiring!', originalTitle);
                    window.addEventListener('focus', function handler() {
                        stopFlashing();
                        window.removeEventListener('focus', handler);
                    });
                }
            }
            var minsEl = document.getElementById('SessionMinutes');
            var secsEl = document.getElementById('SessionSeconds');
            if (minsEl) minsEl.textContent = Math.floor(secondsRemaining / 60);
            if (secsEl) secsEl.textContent = secondsRemaining % 60;
        } else {
            if (modalEl && modalEl.classList.contains('show')) {
                bootstrap.Modal.getInstance(modalEl)?.hide();
            }
        }
    },

    keepSessionAlive: function () {
        var expireTime = parseInt(localStorage.getItem('sessionExpirationTime'), 10);
        var secondsRemaining = isNaN(expireTime) ? 0 : Math.floor((expireTime - Date.now()) / 1000);
        var isPastHalfway = secondsRemaining < (AMCOS.sessionDurationSeconds / 2);

        if (!AMCOS.validatingSession && isPastHalfway && secondsRemaining > 0) {
            AMCOS.validatingSession = true;
            fetch('/account/keepalive', {
                method: 'POST',
                headers: {
                    'RequestVerificationToken': document.querySelector('input[name="__RequestVerificationToken"]')?.value ?? ''
                }
            })
            .then(function (res) {
                AMCOS.validatingSession = false;
                if (res.ok) {
                    return res.json().then(function (data) {
                        var timeout = data.authenticationTimeout ?? data.AuthenticationTimeout;
                        if (timeout) {
                            AMCOS.setNewExpirationTime(timeout);
                            AMCOS.sessionDurationSeconds = timeout;
                        }
                    });
                }
            })
            .catch(function () { AMCOS.validatingSession = false; });
        }
    },

    flashTabTitle: function (alertMessage, originalTitle) {
        var isOriginal = true;
        var interval = setInterval(function () {
            document.title = isOriginal ? alertMessage : originalTitle;
            isOriginal = !isOriginal;
        }, 1000);
        return function () {
            clearInterval(interval);
            document.title = originalTitle;
        };
    }
};

document.addEventListener('DOMContentLoaded', function () {
    if (document.getElementById('amcos-logout-form')) {
        AMCOS.startup();
    }

    window.addEventListener('pageshow', function (event) {
        if (event.persisted) AMCOS.checkSession();
    });

    document.addEventListener('mouseup', function () { AMCOS.keepSessionAlive(); });
    document.addEventListener('keyup', function () { AMCOS.keepSessionAlive(); });
});

// Global jQuery AJAX error handler (used by feature pages that still use $.ajax)
if (typeof $ !== 'undefined') {
    $(document).ajaxError(function (event, xhr) {
        if (xhr.status === 0) {
            window.location.reload(true);
        } else if (xhr.status === 401) {
            AMCOS.sessionExpired();
        }
    });
}
