@Code
    Layout = Nothing
End Code

<!DOCTYPE html>

<html>
<head>
    <meta name="viewport" content="width=device-width" />
    <meta http-equiv="X-UA-Compatible" content="IE=Edge, chrome=1" />
    <title>AMCOS</title>
    @System.Web.Optimization.Styles.Render("~/bundles/css")
    @System.Web.Optimization.Scripts.Render("~/bundles/jquery")
</head>
<body style="font-family: Arial; font-size: 9pt">
    <div>
        @Html.Partial("_DMZHeader")
        @RenderBody()
    </div>
    @Html.Partial("_Footer")
    @*<script>$(document).foundation();</script>*@
</body> 
</html>
