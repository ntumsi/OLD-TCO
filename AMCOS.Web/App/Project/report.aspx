<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.ProjectReport" ValidateRequest="false" Codebehind="report.aspx.vb" %>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <meta http-equiv="x-ua-compatible" content="ie=edge" />
    <title>AMCOS Report</title>
    <script type="text/javascript" src='<%= ResolveClientUrl("~/dist/js/jquery.min.js")%>'></script>
    <script type="text/javascript">
        function openThisLink() {
            window.open("http://asafm.army.mil/offices/CE/Rates.aspx?OfficeCode=1400");
        }

        function showHide(img) {
            // imgP, imgT, imgD, imgTP, imgDP, imgDT
            //var divID = "div" + img.id.substr(3);
            var img = document.getElementById(img.id);
            if (img.src.indexOf("Expand") > 0) {
                img.src = "../../dist/img/Shrink.gif";
                $("#div" + img.id.substr(3)).show();
            } else {
                img.src = "../../dist/img/Expand.gif"
                $("#div" + img.id.substr(3)).hide();
            }
        }
    </script>
</head>
<body>
    <form id="form1" runat="server">
        <div id="page">
            <div id="contentArea">

                <asp:ImageButton ID="ibDownloadExcel" runat="server" ImageUrl="~/dist/img/ms-excel.gif" Width="20px" ToolTip="Export into MS Excel" />&nbsp;&nbsp;&nbsp;
                    <b>NOTE: This report can also be copied into MS Excel directly.</b>
        
                <asp:HiddenField ID="hidDownload" runat="server" Value="" /><br />
        
                <hr />
        
                
                <div id="divExportContent">
                <table>
                    <tr>
                        <td colspan="2">
                            <h3>Report Properties</h3>
    <%--                        <p>Report Properties display the basic characteristics of the project. The Category describes the portion of the cost estimate being displayed; the Pay Plan
                                identifies the pay table(s) being referenced and the Cost Summary, the grouping of cost factors the analyst has chosen.</p>
                            <p>As a reminder, if the reserve component Pay Plans are used, RCInactive Training Days are a default value representing the reservist’s weekend drills, while
                                the active training days range from a default value of 15 (summer Annual Training) upward to 342, if the analyst anticipates a call to active duty.</p>
    --%>                    </td>
                    </tr>
                    <tr>
                        <td valign="top" colspan="2" style="white-space: nowrap !important;" >
                        <table border="0" cellpadding="5">
                    <tr>
                    <td valign="top">
                            <asp:DetailsView ID="dvProjectDetails" runat="server" DataSourceID="odsRepProjectDetails" AutoGenerateRows="False"  cellpadding="3">
                                <FieldHeaderStyle BackColor="DarkBlue" ForeColor="White" />
                                <Fields>
                                    <asp:BoundField DataField="ProjectCreator" HeaderText="ProjectCreator" SortExpression="ProjectCreator" />
                                    <asp:BoundField DataField="CreateDate" HeaderText="Create Date" SortExpression="CreateDate" />
                                    <asp:BoundField DataField="LastUpdate" HeaderText="Last Update" SortExpression="LastUpdate" />
                                    <asp:BoundField DataField="ProjectName" HeaderText="Project Name" SortExpression="ProjectName" />
                                    <asp:BoundField DataField="Description" HeaderText="Description" SortExpression="Description" />
                                    <asp:BoundField DataField="YearStart" HeaderText="Start Year" SortExpression="YearStart" />
                                    <asp:BoundField DataField="YearDuration" HeaderText="Project Duration" SortExpression="YearDuration" />
                                </Fields>
                            </asp:DetailsView>
                            <asp:ObjectDataSource ID="odsRepProjectDetails" runat="server" SelectMethod="GetProject" TypeName="AMCOS.Logic.Project">
                                <SelectParameters>
                                    <asp:Parameter Name="ProjectId" Type="Int32" />
                                </SelectParameters>
                            </asp:ObjectDataSource>
                    </td>
                    <td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                    </td>
                    <td valign="top">
                            <asp:GridView ID="gvProjectReport" runat="server" AutoGenerateColumns="False" DataSourceID="SqlDataReportSelection"  cellpadding="3">
                                <Columns>
                                    <asp:BoundField DataField="Category" HeaderText="Sub-Project Name" SortExpression="Category" HeaderStyle-HorizontalAlign="Left" />
                                    <asp:BoundField DataField="PayPlan" HeaderText="PayPlan" SortExpression="PayPlan" />
                                </Columns>
                                <HeaderStyle BackColor="DarkBlue" ForeColor="White" />
                            </asp:GridView>
                            <asp:SqlDataSource ID="SqlDataReportSelection" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>" SelectCommand="SELECT DISTINCT PMCategory.CategoryName AS Category, PMReport.PayPlan FROM webuser.PMReport PMReport INNER JOIN webuser.PMCategory PMCategory ON PMReport.CategoryId = PMCategory.CategoryId WHERE PMCategory.ProjectId = @ProjectId;">
                                <SelectParameters>
                                    <asp:Parameter Name="ProjectId" Type="Int32"  />
                                </SelectParameters>
                            </asp:SqlDataSource>
                    </td>
                    </tr>
                        </table>
                        </td>
                    </tr>
                    <tr>
                        <td colspan="2">
                            <br /><h3>Inflation Factors</h3>
                            <div>The current Joint Inflation Calculator (JIC) found on the OASA (FM&C) website, <span style="cursor:pointer; color: blue; text-decoration: underline"; onclick="javascript:openThisLink()">http://asafm.army.mil/offices/CE/Rates.aspx?OfficeCode=1400</span>,
                            is the source for the fourteen (14) inflation factors built into Project Manager (PM).  Each component (Active, NG, & Reserves) has their own separate set of "MPA", "MPA Non Pay", & "OMA" inflation factors and Civilian (GS, WG, WL, WS, & SES) positions 
                            are only inflated by two inflation factors, "CivPay" or "OMA".  The "MPA" inflation factor is applied to all MPA Appropriation (APPN) cost elements except Permanent Change of Station (PCS) related cost elements.  In this case,
                            the "MPA Non Pay" inflation factor is applied to a PCS cost element.  When AMCOS LITE displays APPN = "OMA" or "Other", the "OMA" inflation factor is applied to any cost element with either APPN.</div>
                            <br />
                        </td>
                    </tr>
                    <tr>
                        <td valign="top" colspan="2">
                            <asp:GridView ID="InflationGridView" runat="server" AutoGenerateColumns="True" cellpadding="3">
                                <HeaderStyle BackColor="DarkBlue" ForeColor="White" />
                            </asp:GridView>
                        </td>
                    </tr>
                    <tr>
                        <td colspan="2">
                        <div style="border-width:thin; border-style:solid; padding-left:5px; padding-right:5px; padding-top:2px; padding-bottom:0px; border-spacing:0px">
                        <div style="text-decoration:underline; font-weight:bold; border-spacing:3px; padding:3px">Inflation Calculation Note:</div>

                        <div style="border-spacing:3px; padding:3px">
                        In Project Manager (PM), the Fiscal Year (FY) costs generated in AMCOS LITE will be referred to as "BASE YEAR" costs. PM multiplies BASE YEAR costs by the appropriate target year INFLATION FACTOR generating Future Start Year and/or Future Year Cost Element costs across the entire duration.
                        </div>
                        <div style="text-decoration:underline; font-weight:bold; border-spacing:3px; padding:3px">For Example</div>
                        <div style="border-spacing:3px; padding:3px">
                            The Project Start Year (YearStart) is set to <%=_projectStartYear.ToString("#")%> and the number of years (YearDuration) is set to 5 years for costing an Active Duty position with the focus on "SALARY" cost element:
                            <ul style=" margin-bottom:2px; margin-top:2px">
                              <li><%=_projectStartYear.ToString("#")%> Active Duty Salary = (AMCOS LITE "Avg Cost Base Pay (Military)" BASE YEAR SALARY) * (<%=_projectStartYear.ToString("#")%> Active Duty MPA Inflation Factor)</li>
                              <li><%=(_projectStartYear + 1).ToString("#")%> Active Duty Salary = (AMCOS LITE "Avg Cost Base Pay (Military)" BASE YEAR SALARY) * (<%=(_projectStartYear + 1).ToString("#")%> Active Duty MPA Inflation Factor)</li>
                              <li><%=(_projectStartYear + 2).ToString("#")%> Active Duty Salary = (AMCOS LITE "Avg Cost Base Pay (Military)" BASE YEAR SALARY) * (<%=(_projectStartYear + 2).ToString("#")%> Active Duty MPA Inflation Factor)</li>
                              <li>Repeating the Inflation process until the specified duration completes.</li>
                            </ul>
                        </div>
                        </div>
                        </td>
                    </tr>
                    <tr>
                        <td colspan="2" rowspan="">
                            <br /><h3>Discounting and Present Value Factor (PVF)</h3>
                            Most cost comparison techniques take into consideration the time value of money, that is, a dollar today is worth some amount less in the future.  
                            Discount rates are prepared annually by the Office of Management and Budget (OMB).  OMB Circular A-94 and Department of Defense Instruction (DoDI) 7041.3 
                            require the use of a discount rate based on the Treasury Department cost of borrowing funds, and reflect the expected cost of borrowing for 
                            3, 5, 7, 10, 20, and 30 years securities.<br /><br />
                            <b>Discount Rates Based on <asp:Label runat="server" ID="lblYearForTheDiscount" Font-Underline="true"></asp:Label> Years Securities:</b><br />
                            <asp:GridView ID="gvDiscountRates" runat="server" cellpadding="3" AutoGenerateColumns="true">
                            </asp:GridView>
                        </td>
                    </tr> 
                
                    <tr>
                        <td colspan="2" rowspan="">
                            <br /><h3>Inventory</h3>
                        </td>
                    </tr> 
                    <tr>
                        <td colspan="2" valign="top">
                            <asp:GridView ID="gvProjectInventory" runat="server" cellpadding="3">
                                <HeaderStyle BackColor="DarkBlue" ForeColor="White" />
                            </asp:GridView>
                        </td>
                    </tr>               
                    <tr>
                        <td colspan="2">
                            <br />
                            <h3>Cost</h3>
                            <p>The Costing Reports are produced both with and without the discount rate the analyst inputs to the cost estimate.</p>
                            <asp:Literal runat="server" ID="litNoteSpecialPay"><h3 style="color:Navy">**NOTE - Cost Values are not inflated for "Average Cost of Special Pays".</h3></asp:Literal>
                        </td>
                    </tr>
                    <tr>
                        <td colspan="2" valign="top">
                            <h3>
                                <asp:Label runat="server" ID="lblUndiscounted_Default" Font-Underline="true"  Font-Italic="true">Default Summary:</asp:Label>
                            </h3>
                            <asp:GridView ID="gvUndiscounted_Default" runat="server" CellPadding="3" EmptyDataText="No Data">
                                <HeaderStyle BackColor="DarkBlue" ForeColor="White" />
                            </asp:GridView>
                            <h3 id="cceSalaryOverLimitNoteUndiscounted" runat="server" visible="false" style="color:Navy">
                                NOTE: The highlighted field(s) indicate a value based on CCE salary greater than <% =FormatCurrency(cceMaxPayFootnote, 2) %> per year.  The Contractor APPN Total sums the displayed CCE values but may be greater if your report includes highlighted cells
                            </h3>

                            <h3>                               
                                <img id="imgDiscount" src="../../dist/img/Expand.gif" onclick="javascript:showHide(this);" alt="[Discount]" />
                                <asp:Label runat="server" ID="lblDiscounted_Default" Font-Underline="true"   Font-Italic="true">Discounted Default Summary:</asp:Label>
                            </h3>
                            <div id="divDiscount" style="display: none">
                                <asp:GridView ID="gvDiscounted_Default" runat="server" CellPadding="3" EmptyDataText="No Data">
                                    <HeaderStyle BackColor="DarkBlue" ForeColor="White" /> 
                                </asp:GridView>
                                <h3 id="cceSalaryOverLimitNoteDiscounted" runat="server" visible="false" style="color:Navy">
                                NOTE: The highlighted field(s) indicate a value based on CCE salary greater than <% =FormatCurrency(cceMaxPayFootnote, 2) %> per year.  The Contractor APPN Total sums the displayed CCE values but may be greater if your report includes highlighted cells
                            </h3>
                            </div>
                        </td>
                    </tr>
                </table>
                </div>
            </div>
        </div>
    </form>
</body>
</html>
