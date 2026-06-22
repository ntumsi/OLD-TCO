<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.About" Title="About AMCOS" Codebehind="about.aspx.vb" MasterPageFile="~/SiteAdmin.Master" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
    <div class="amcos-page">
        <h1>Introduction to AMCOS</h1>
        <p>AMCOS is used to develop cost factors for civilian and military personnel costs.  It is updated twice a year with a spring update in April and a fall update in October.  AMCOS contains three major tools which allows users to export results to Microsoft Excel:</p>
        <ul>
            <li>
                <b>AMCOS Lite</b> - a quick and simple way to retrieve cost factors for specific types of personnel.  AMCOS Lite displays costs for each grade, appropriation and cost factor.
            </li>
            <li>
                <b>Project Manager</b> - used to perform a multi-year cost analysis for a combination of personnel requirements from one or more pay plans.  Project Manager allows greater flexibility in specifying your personnel requirements and defining your parameters (i.e., MOS/AOC/Occupational Series/Private Labor Market Standard Occupational Codes, Grade, project start year, project duration, inflation and discount rates).
            </li>
            <li>
                <b>Xwalk</b> - provides a crosswalk (Xwalk) between related military and civilian careers to private labor market salary / benefits as reported by the Bureau of Labor Statistics (BLS) Occupational Employment Statistics (OES).  Active Military Pay Plans work skills (MOS/AOCs) are associated with Federal Occupational Series (FEDCODEs) and Standard Occupational Classifications (SOCs).  The Contractor Cost Estimate (formerly called "Private Labor Market") will have a SubGroup containing an occupation associated with the MOS/AOC or civilian occupational specialties.
            </li>
            <li>
                <b>Civilian Permanent Change of Station (PCS)</b> - The Civilian PCS module allows users to quickly derive an estimated cost to move a civilian from one location to another. It uses several initial assumptions to derive the starting cost which is then user adjustable to tailor the estimate to the specifics of the move. Because Civilian PCS is governed by numerous cost components with their own set of rules and regulations, AMCOS sections out the PCS page by cost element and provides reference to applicable policy.
            </li>
        </ul>
        <hr />
    </div>
</asp:Content>