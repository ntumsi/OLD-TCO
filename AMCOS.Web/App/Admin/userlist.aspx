<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.UserList" Title="Admin User List" ValidateRequest="false" Codebehind="UserList.aspx.vb" %>

<asp:Content ContentPlaceHolderID="JSPlaceHolder" runat="server">
    <script type="text/javascript">
        function GetDownloadData() {
            document.getElementById("<%= _hidDownloadClientID %>").value = document.getElementById("theExportContent").innerHTML;
        }
    </script>
</asp:Content>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">

    <asp:HiddenField ID="hidDownload" runat="server" Value="" />

    <div class="reportPage users">

        <h1>User List</h1>

        <p class="summary">
            &nbsp;
        </p>

        <div class="topPanel">

            <div class="row">
                <div class="small-12 column notes">
                    <h3>Set Filters for Selected Users List</h3>
                </div>
            </div>
            <div class="row">
                <div class="large-2 column">
                    <asp:Label ID="lblFirstName" AssociatedControlID="tbFirstName" runat="server" Text="First Name:" />
                    <asp:TextBox ID="tbFirstName" runat="server"></asp:TextBox>
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lbLastName" AssociatedControlID="tbLastName" runat="server" Text="Last Name:" />
                    <asp:TextBox ID="tbLastName" runat="server"></asp:TextBox>
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblArmyRank" AssociatedControlID="tbArmyRank" runat="server" Text="Rank/Grade:" />
                    <asp:TextBox ID="tbArmyRank" runat="server"></asp:TextBox>
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblMacom" AssociatedControlID="macomList" runat="server" Text="Organization:" />
                    <asp:DropDownList ID="macomList" runat="server" DataValueField="Value" DataTextField="Text"></asp:DropDownList>
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblOfficeName" AssociatedControlID="tbOfficeName" runat="server" Text="Office Name:" />
                    <asp:TextBox ID="tbOfficeName" runat="server" MaxLength="85"></asp:TextBox>
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblCompanyName" AssociatedControlID="tbCompanyName" runat="server" Text="Company Name:" />
                    <asp:TextBox ID="tbCompanyName" runat="server" MaxLength="85"></asp:TextBox>
                </div>
            </div>
            <div class="row">
                <div class="large-2 column">
                    <asp:Label ID="lblDateCreatedFrom" AssociatedControlID="txtDateCreatedFrom" runat="server" Text="Date Created between:" />
                    <asp:TextBox ID="txtDateCreatedFrom" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    and
                    <asp:TextBox ID="txtDateCreatedTo" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    <asp:CompareValidator ID="cvCreatedFrom" runat="server" ControlToValidate="txtDateCreatedFrom" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarDateCreatedFrom" TargetControlID="txtDateCreatedFrom" runat="server" />
                    <asp:CompareValidator ID="cvCreatedTo" runat="server" ControlToValidate="txtDateCreatedTo" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarDateCreatedTo" TargetControlID="txtDateCreatedTo" runat="server" />
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblDateUpdatedFrom" AssociatedControlID="txtDateUpdatedFrom" runat="server" Text="Last Updated between:" />
                    <asp:TextBox ID="txtDateUpdatedFrom" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    and
                    <asp:TextBox ID="txtDateUpdatedTo" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    <asp:CompareValidator ID="cvUpdatedFrom" runat="server" ControlToValidate="txtDateUpdatedFrom" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarDateUpdatedFrom" TargetControlID="txtDateUpdatedFrom" runat="server" />
                    <asp:CompareValidator ID="cvUpdatedTo" runat="server" ControlToValidate="txtDateUpdatedTo" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarDateUPdatedTo" TargetControlID="txtDateUpdatedTo" runat="server" />
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblLastLoginFrom" AssociatedControlID="txtLastLoginFrom" runat="server" Text="Last Login between:" />
                    <asp:TextBox ID="txtLastLoginFrom" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    and
                    <asp:TextBox ID="txtLastLoginTo" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    <asp:CompareValidator ID="cvLastLoginFrom" runat="server" ControlToValidate="txtLastLoginFrom" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarLastLoginFrom" TargetControlID="txtLastLoginFrom" runat="server" />
                    <asp:CompareValidator ID="cvLastLoginTo" runat="server" ControlToValidate="txtLastLoginTo" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarLastLoginTo" TargetControlID="txtLastLoginTo" runat="server" />
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblLoginFrom" AssociatedControlID="txtLoginFrom" runat="server" Text="Login History between:" />
                    <asp:TextBox ID="txtLoginFrom" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    and
                    <asp:TextBox ID="txtLoginTo" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    <asp:CompareValidator ID="cvLoginFrom" runat="server" ControlToValidate="txtLoginFrom" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarLoginFrom" TargetControlID="txtLoginFrom" runat="server" />
                    <asp:CompareValidator ID="cvLoginTo" runat="server" ControlToValidate="txtLoginTo" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarLoginTo" TargetControlID="txtLoginTo" runat="server" />
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblLastApprovedFrom" AssociatedControlID="txtLastApprovedFrom" runat="server" Text="DASA-CE Approved between:" />
                    <asp:TextBox ID="txtLastApprovedFrom" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    and
                    <asp:TextBox ID="txtLastApprovedTo" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    <asp:CompareValidator ID="cvLastApprovedFrom" runat="server" ControlToValidate="txtLastApprovedFrom" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarLastApprovedFrom" TargetControlID="txtLastApprovedFrom" runat="server" />
                    <asp:CompareValidator ID="cvLastApprovedTo" runat="server" ControlToValidate="txtLastApprovedTo" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarLastApprovedTo" TargetControlID="txtLastApprovedTo" runat="server" />
                </div>
                <div class="large-2 column">
                    <asp:Label ID="lblLastDeniedFrom" AssociatedControlID="txtLastDeniedFrom" runat="server" Text="DASA-CE Denied between:" />
                    <asp:TextBox ID="txtLastDeniedFrom" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    and
                    <asp:TextBox ID="txtLastDeniedTo" runat="server" CssClass="halfSize inline"></asp:TextBox>
                    <asp:CompareValidator ID="cvLastDeniedFrom" runat="server" ControlToValidate="txtLastDeniedFrom" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarLastDeniedFrom" TargetControlID="txtLastDeniedFrom" runat="server" />
                    <asp:CompareValidator ID="cvLastDeniedTo" runat="server" ControlToValidate="txtLastDeniedTo" Operator="DataTypeCheck" Type="Date" ErrorMessage="Invalid Date" />
                    <ajaxToolkit:CalendarExtender ID="calendarLastDeniedTo" TargetControlID="txtLastDeniedTo" runat="server" />
                </div>
            </div>
            <div class="row">
                <div class="large-2 column large-offset-5 text-center">
                    <asp:Button runat="server" ID="btnSearch" Text="Search" CssClass="fullWidth" />
                    <asp:Label runat="server" ID="lblRecCount"></asp:Label>&nbsp;&nbsp;
                    <asp:ImageButton ID="ibDownloadExcel" OnClientClick='GetDownloadData();' runat="server" ImageUrl="~/dist/img/ms-excel.gif" Width="20px" ToolTip="Export into MS Excel" Visible="false" />
                </div>
            </div>

        </div>

        <div class="bottomPanel">

            <div class="tableWrapper">
                <asp:GridView ID="GridView1" runat="server" CellPadding="3" CellSpacing="3" AutoGenerateColumns="False" AllowSorting="True">
                    <HeaderStyle BackColor="DarkBlue" ForeColor="White" />
                    <Columns>
                        <asp:BoundField DataField="Name" HeaderText="Name" SortExpression="Name" />
                        <asp:BoundField DataField="Email" HeaderText="Email" SortExpression="Email" />
                        <asp:BoundField DataField="ArmyRank" HeaderText="Rank/Grade" SortExpression="ArmyRank" />
                        <asp:BoundField DataField="Macom" HeaderText="Organization" SortExpression="Macom" />
                        <asp:BoundField DataField="OfficeName" HeaderText="Office  Name / Symbol" SortExpression="OfficeName" />
                        <asp:BoundField DataField="CompanyName" HeaderText="Company Name" SortExpression="CompanyName" />
                        <asp:BoundField DataField="ComPhone" HeaderText="Commercial Phone" SortExpression="ComPhone" />
                        <asp:BoundField DataField="ArmyAccountType" HeaderText="Army Account Type" SortExpression="ArmyAccountType" />
                        <asp:BoundField DataField="DateCreated" HeaderText="Date Created" SortExpression="DateCreated" />
                        <asp:BoundField DataField="LastUpdate" HeaderText="Last Updated" SortExpression="LastUpdate" />
                        <asp:BoundField DataField="LastLogin" HeaderText="Last Login" SortExpression="LastLogin" />
                        <asp:BoundField DataField="LoginCount" HeaderText="Login Count" SortExpression="LoginCount" />
                        <asp:BoundField DataField="Role" HeaderText="User Role" SortExpression="Role" />
                        <asp:TemplateField HeaderText="">
                            <ItemTemplate>
                                <asp:Button runat="server" ID="btnChangeRole" CommandName="ChangeRole" CommandArgument='<%# Eval("UserId") %>' Text="Change Role" />
                            </ItemTemplate>
                        </asp:TemplateField>
                    </Columns>
                </asp:GridView>
            </div>

            <div id="theExportContent" style="display:none">

                <table>
                    <tr>
                        <td>First Name:&nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbFirstNameEx" runat="server"></asp:Label>
                        </td>
                    </tr>
                    <tr>
                        <td>Last Name:&nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbLastNameEx" runat="server"></asp:Label>
                        </td>
                    </tr>
                    <tr>
                        <td>Rank/Grade:&nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbArmyRankEx" runat="server"></asp:Label>
                        </td>
                    </tr>
                    <tr>
                        <td>Organization:&nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbMacomEx" runat="server"></asp:Label>
                        </td>
                    </tr>
                    <tr>
                        <td>Office Name: &nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbOfficeNameEx" runat="server"></asp:Label>
                        </td>
                    </tr>
                    <tr>
                        <td>Company Name: &nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbCompanyNameEx" runat="server"></asp:Label>
                        </td>
                    </tr>
                    <tr>
                        <td>Date Created between: &nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbDateCreatedFromEx" runat="server"></asp:Label>
                            &nbsp;&nbsp;and&nbsp;&nbsp;&nbsp;
                    	<asp:Label ID="tbDateCreatedToEx" runat="server"></asp:Label>
                        </td>
                    </tr>


                    <tr>
                        <td>Last Updated between: &nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbDateUpdatedFromEx" runat="server"></asp:Label>
                            &nbsp;&nbsp;and&nbsp;&nbsp;&nbsp;
                    	<asp:Label ID="tbDateUpdatedToEx" runat="server"></asp:Label>
                        </td>
                    </tr>

                    <tr>
                        <td>Last Login between: &nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbLastLoginFromEx" runat="server"></asp:Label>
                            &nbsp;&nbsp;and&nbsp;&nbsp;&nbsp;
                    	<asp:Label ID="tbLastLoginToEx" runat="server"></asp:Label>
                        </td>
                    </tr>

                    <tr>
                        <td>Login History between: &nbsp;
                        </td>
                        <td>
                            <asp:Label ID="tbLoginFromEx" runat="server"></asp:Label>
                            &nbsp;&nbsp;and&nbsp;&nbsp;&nbsp;
                    	<asp:Label ID="tbLoginToEx" runat="server"></asp:Label>
                        </td>
                    </tr>
                </table>

                <div class="tableWrapper">
                <asp:GridView ID="GridView2" runat="server" CellPadding="3" CellSpacing="3" AutoGenerateColumns="False">
                    <HeaderStyle BackColor="DarkBlue" ForeColor="White" />
                    <Columns>
                        <asp:BoundField DataField="Name" HeaderText="Name" />
                        <asp:BoundField DataField="Email" HeaderText="Email" />
                        <asp:BoundField DataField="ArmyRank" HeaderText="Rank/Grade" />
                        <asp:BoundField DataField="Macom" HeaderText="Organization" />
                        <asp:BoundField DataField="OfficeName" HeaderText="Office Name / Symbol" />
                        <asp:BoundField DataField="CompanyName" HeaderText="Company Name" />
                        <asp:BoundField DataField="ComPhone" HeaderText="Commercial Phone" />
                        <asp:BoundField DataField="ArmyAccountType" HeaderText="Army Account Type" />
                        <asp:BoundField DataField="DateCreated" HeaderText="Date Created" />
                        <asp:BoundField DataField="LastUpdate" HeaderText="Last Updated" />
                        <asp:BoundField DataField="LastLogin" HeaderText="Last Login" />
                        <asp:BoundField DataField="LoginCount" HeaderText="Login Count" SortExpression="LoginCount" />
                        <asp:BoundField DataField="Role" HeaderText="User Role" SortExpression="Role" />
                    </Columns>
                </asp:GridView>
                </div>

            </div>

        </div>

        <div class="clearfix"></div>

    </div>

</asp:Content>
