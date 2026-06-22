@Code
    ViewData("Title") = "AMCOS"
    Layout = "~/Views/Shared/_DMZLayout.vbhtml"
End Code

<h2>You have been logged out. <a href="@Url.Content(ConfigurationManager.AppSettings("AmcosUrl"))">Click here</a> to log back in.</h2>

<script type="text/javascript">  
    window.location.href = "https://federation.eams.army.mil/sso/logout";    
</script>