@ModelType AMCOS.Logic.ViewModels.HomeViewModel
@Code
    ViewData("Title") = "AMCOS Home"
    Layout = "~/Views/Shared/_Layout.vbhtml"
End Code

<div id="homeModal">
    <p id="homeText">
        <span class="amcosLarge">AMCOS</span> is an automated tool that helps users estimate the costs associated with personnel requirements for different components, grades and skills. AMCOS contains a comprehensive database of personnel-related cost factors for the Active, the Reserve Components, the Civilian workforce, and the Contractor Cost Estimate (CCE).
        <br />
        <br />
        What's New<br />
        Current Release: Jan 2025<br />
        Next Full Release: July 2026<br />
        <br />
        For full details on the latest release please see the <a href='@(Url.Content("~/Public/AMCOS Release Update History.pdf"))' target="_blank">AMCOS Release/Update History</a>
    </p>
    <a id="introButton" class="button" href="about.aspx">Introduction &#9654;</a>
</div>
@Section AdditionalJavascript
    <script type="text/javascript">
        const i = document.createElement("img");
        i.id = "AMCOSbg";
        i.src = "#";
        i.classList.add("bg");
        document.body.insertBefore(i, document.body.firstChild);
        document.getElementById('AMCOSbg').src = '@Model.ImageUrl';
    </script>
End Section

