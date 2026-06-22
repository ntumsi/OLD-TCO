var AMCOS = {
    checkSessionIntervalId: 0,
    loggingout: false,
    validatingSession: false,
    sessionDurationSeconds: 600, // E.g., 10 minutes

    startup: () => {
        // 1. Pause the death timer from firing immediately
        AMCOS.validatingSession = true;

        // 2. Immediately ask the server for the TRUE session state on a fresh page load.
        // This prevents the old localStorage timestamp from killing a fresh login.
        $.ajax({
            url: _validateSessionURL,
            type: 'POST',
            headers: { AntiForgeryToken: $('#AntiForgeryToken').val() },
            dataType: 'json',
            success: function (res) {
                AMCOS.validatingSession = false;
                if (res.AuthenticationTimeout) {
                    // Fresh login confirmed! Overwrite the old, dead timestamp.
                    AMCOS.setNewExpirationTime(res.AuthenticationTimeout);
                    AMCOS.sessionDurationSeconds = res.AuthenticationTimeout;
                }

                // 3. Now that we have the truth, start the interval timers
                AMCOS.startTimers();
            },
            error: function () {
                // Server says we are dead (e.g. 401 Unauthorized)
                AMCOS.validatingSession = false;
                AMCOS.forceLogout();
            }
        });
    },

    startTimers: () => {
        AMCOS.checkSession();
        setInterval(() => { $('.blinking').fadeOut().fadeIn(); }, 1500);
        AMCOS.checkSessionIntervalId = setInterval(AMCOS.checkSession, 1000);
    },

    forceLogout: () => {
        if (!AMCOS.loggingout) {
            AMCOS.loggingout = true;
            // Destroy the timestamp so other tabs and the Back button know the session is dead
            localStorage.removeItem('sessionExpirationTime');

            let $modal = $("#SessionExpiringModal");
            if ($modal.length && $modal.attr('aria-hidden') === 'false') {
                $modal.foundation("close");
            }
            document.getElementById("AMCOSLogout").click();
        }
    },

    setNewExpirationTime: (seconds) => {
        const expireTime = Date.now() + (seconds * 1000);
        localStorage.setItem('sessionExpirationTime', expireTime);
    },

    checkSession: () => {
        const expireTime = parseInt(localStorage.getItem('sessionExpirationTime'), 10);

        // If the time is NaN (because it was cleared on logout), treat seconds as 0
        const secondsRemaining = isNaN(expireTime) ? 0 : Math.floor((expireTime - Date.now()) / 1000);

        let $modal = $("#SessionExpiringModal");

        // 1. Check for expiration FIRST
        if (secondsRemaining <= 0) {
            console.log("Session Expired");
            clearInterval(AMCOS.checkSessionIntervalId);
            AMCOS.forceLogout();
            return; // Stop processing further
        }

        // 2. Check for Warning Window (180 seconds or less)
        if (secondsRemaining <= 180) {
            if ($modal.length && $modal.attr('aria-hidden') === 'true') {
                $modal.foundation("open");
                if (document.hidden) {
                    const title = document.title;
                    const stopFlashing = AMCOS.flashTabTitle("\u{1F534} Session Expiring!", title);
                    $(window).one('focus', function () {
                        stopFlashing();
                    });
                }
            }
            $("#SessionMinutes").text(parseInt(secondsRemaining / 60));
            $("#SessionSeconds").text(parseInt(secondsRemaining % 60));
        }
        // 3. Close modal if time is bumped back up above 180
        else {
            if ($modal.length && $modal.attr('aria-hidden') === 'false') {
                $modal.foundation("close");
            }
        }
    },

    helpers: {
        isDigit: function (val) {
            var strBuffer = new String(val);
            var nPos = 0;
            if (isEmpty(strBuffer)) return false;
            for (nPos = 0; nPos < strBuffer.length; nPos++)
                if (strBuffer.charAt(nPos) < '0' || strBuffer.charAt(nPos) > '9') return false;
            return true;
        }
    },

    keepSessionAlive: () => {
        const expireTime = parseInt(localStorage.getItem('sessionExpirationTime'), 10);
        const secondsRemaining = isNaN(expireTime) ? 0 : Math.floor((expireTime - Date.now()) / 1000);

        // THROTTLE: Only ping the server if we are more than 50% through the session.
        const isPastHalfway = secondsRemaining < (AMCOS.sessionDurationSeconds / 2);

        // Only ping if we are past halfway AND the session isn't already dead
        if (!AMCOS.validatingSession && isPastHalfway && secondsRemaining > 0) {
            AMCOS.validatingSession = true;
            $.ajax({
                url: _validateSessionURL,
                type: 'POST',
                headers: { AntiForgeryToken: $('#AntiForgeryToken').val() },
                dataType: 'json',
                error: function (err) {
                    console.log("Error on send:" + err);
                    AMCOS.validatingSession = false;
                },
                success: function (res) {
                    console.log("Valid Session");
                    AMCOS.validatingSession = false;
                    if (res.AntiForgeryToken) {
                        document.getElementById("AntiForgeryToken").value = res.AntiForgeryToken;
                    }
                    if (res.AuthenticationTimeout) {
                        AMCOS.setNewExpirationTime(res.AuthenticationTimeout);
                        AMCOS.sessionDurationSeconds = res.AuthenticationTimeout;
                    }
                }
            });
        }
    },

    flashTabTitle(alertMessage, originalTitle) {
        let isOriginalTitle = true;
        let interval = setInterval(() => {
            document.title = isOriginalTitle ? alertMessage : originalTitle;
            isOriginalTitle = !isOriginalTitle;
        }, 1000);

        const stopFlashing = () => {
            clearInterval(interval);
            document.title = originalTitle;
        }
        return stopFlashing;
    }
};

// Kick off startup script when page finished loading
$(document).ready(function () {
    $(document).foundation();

    // Always ping the server on a fresh load to get the truth
    AMCOS.startup();

    // INTERCEPT THE BACK BUTTON
    window.addEventListener("pageshow", function (event) {
        // event.persisted is TRUE if the page was loaded from the browser's back/forward cache
        if (event.persisted) {
            // We immediately check the session. If they logged out, 
            // localStorage will be empty/expired, and they will be kicked out.
            AMCOS.checkSession();
        }
    });

    window.onerror = (message, source, lineno, colno, error) => {
        console.log(message);
        if (typeof message === 'string' && message.startsWith('Websocket onclose failed')) {
            location.reload();
        }
    }

    document.onmouseup = (ev) => { AMCOS.keepSessionAlive(); };
    document.onkeyup = (ev) => { AMCOS.keepSessionAlive(); }
});
//Handle all ajax errors
$(document).ajaxError(function (event, xhr, settings, err) {
    if (navigator.userAgent.indexOf("Firefox") > -1) {
        //Let's put this here for now. We may want to elevate this to an alert if we encounter more errors.
        console.log("Some features of this site may not work correctly with Firefox.  Please consider using another browser like Chrome or Edge.");
    } else if (xhr.status == 0) {
        console.log("Ajax Error: " + err);
        //just refresh the page authencation needs to be reestablished.
        window.location.reload(true);
    } else {
        //let the user know there was an error
        alert("Ajax Exception: " + err + ". If this continues try refreshing the page.");
    }
});

function toggleOnOffCanvas(id, callback) {
    const element = document.getElementById(id);
    if (callback) {
        //execute callback after animation completed
        var executeCallbackOnce = function () {
            callback();
            element.removeEventListener('animationend', executeCallbackOnce);
        }
        element.addEventListener('animationend', executeCallbackOnce);
    }
    if (element.classList.contains("cal-off-canvas")) {
        element.classList.remove("cal-off-canvas");
        element.classList.add("cal-on-canvas");
    } else if (element.classList.contains("cal-on-canvas")) {
        element.classList.remove("cal-on-canvas");
        element.classList.add("cal-off-canvas");
    } else {
        element.classList.remove("cal-default-canvas");
        element.classList.add("cal-off-canvas");
    }
}

