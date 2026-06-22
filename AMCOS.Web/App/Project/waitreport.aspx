<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.ProjectWaitReport" Codebehind="waitreport.aspx.vb" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
    <script  type="text/javascript">
        function loadReport() {
            window.location =  window.location.href.replace("waitreport", "report");
        }
    </script>
</head>
<body onload="loadReport();">
<br />
<br />
<h1>&nbsp; &nbsp;Loading the report ... ... Please wait !</h1>
</body>
</html>
