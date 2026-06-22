<div class="reveal cal-modal" id="SessionExpiringModal" data-reveal data-options="closeOnClick:true;">
    <strong >Your Session Is About To Expire</strong>
    <label class="cal-pad-line" >Due to inactivity, your session will expire after <span id="SessionMinutes">3</span> minutes and <span id="SessionSeconds">0</span> seconds</label>
    <input type="button" data-close value="Stay Logged In" class="cal-button-dark x2" onclick="AMCOS.keepSessionAlive();" />
    <input type="button" value="Log Out" class="cal-button-dark x2" onclick="document.getElementById('AMCOSLogout').click();" />
</div>
