<%@ Page Title="Updating my profile" Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.UpdateMyProfile" Codebehind="UpdateMyProfile.aspx.vb" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" Runat="Server">
<asp:Literal runat="server" ID="litCloseWindow"></asp:Literal>

    <div class="amcos-page">
        <table border="0" cellpadding="3" cellspacing="3" width="800" align="center">
            <tr>
                <td align="left" style="width: 163px; font-size:larger">
                    <b>Updating My Profile</b></td>
                <td style="text-align: right">
                    <asp:Button ID="btnUpdate" runat="server" Text="Update" Height="20px" />&nbsp;&nbsp;
                    <asp:Button ID="btnDelete" runat="server" Text="Delete Me for Testing" CausesValidation="False" Visible="false" Height="20px" Width="140px" />
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <hr />
                </td>
            </tr>
            <tr>
                <td style="width: 163px">
                    User AKO ID:
                </td>
                <td>
                    <%= currentUser.UserId%>
                </td>
            </tr>
            <tr>
                <td style="width: 163px">
                    First Name:
                </td>
                <td>
                    <asp:Label ID="lblFirstName" runat="server"></asp:Label>
                </td>
            </tr>
            <tr>
                <td style="width: 163px">
                    Last Name:
                </td>
                <td>
                    <asp:Label ID="lblLastName" runat="server"></asp:Label>
                </td>
            </tr>
            <tr>
                <td style="width: 163px">
                    Army Rank:
                </td>
                <td>
                    <asp:dropdownlist ID="ddlRankGrade" runat="server" AutoPostBack="True"></asp:dropdownlist>
                    &nbsp; 
                    <asp:TextBox ID="txtRankGrade" runat="server" MaxLength="100" Width="250px" Visible="false"></asp:TextBox>
                </td>
            </tr>
            <tr>
                <td style="width: 163px">
                    Army Account Type:
                </td>
                <td>
                    <asp:Label ID="lblArmyAcctType" runat="server"></asp:Label>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <hr />
                </td>
            </tr>
            <tr>
                <td style="width: 163px;">
                    Email<font color="red" size="2pt">*</font>
                </td>
                <td>
                    <asp:TextBox ID="txtEmail" runat="server" MaxLength="75" Width="550px"></asp:TextBox>
                    <asp:RequiredFieldValidator ID="rfvEmail" runat="server" Display="Dynamic" ErrorMessage="Required" ControlToValidate="txtEmail"></asp:RequiredFieldValidator>
                    <asp:RegularExpressionValidator ID="revEmail" runat="server" Display="Dynamic" ErrorMessage="Invalid Email address" ControlToValidate="txtEmail" ValidationExpression="^(([\w-]+\.)+[\w-]+|([a-zA-Z]{1}|[\w-]{2,}))@((([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1]?[0-9]{1,2}|25[0-5]|2[0-4][0-9])\.([0-1][0-9]{1,2}|25[0-5]|2[0-4][0-9])){1}|([a-zA-Z]+[\w-]+\.)+[a-zA-Z]{2,4})$" />
                </td>
            </tr>
            <tr>
                <td style="width: 163px;">
                    Organization<font color="red" size="2pt">*</font>
                </td>
                <td>
                    <asp:dropdownlist ID="macomList" runat="server" DataValueField="Value" DataTextField="Text"></asp:dropdownlist>
                    <asp:RequiredFieldValidator ID="rfvMacom" runat="server" Display="Dynamic" ErrorMessage="Required" ControlToValidate="macomList"></asp:RequiredFieldValidator>
                </td>
            </tr>
            <tr>
                <td style="width: 163px;">
                    Office Name<font color="red" size="2pt">*</font>
                </td>
                <td>
                    <asp:TextBox ID="OfficeName" runat="server" width="550px" MaxLength="100"></asp:TextBox>
                    <asp:RequiredFieldValidator ID="rfvOfficeName" runat="server" Display="Dynamic" ErrorMessage="Required" ControlToValidate="OfficeName"></asp:RequiredFieldValidator></td>
            </tr>
            <asp:Panel runat="server" ID="pnlCompanyName">
            <tr>
                <td style="width: 163px;">
                    Company Name<font color="red" size="2pt">*</font>
                </td>
                <td>
                    <asp:TextBox ID="CompanyName" runat="server" MaxLength="100" Width="550px"></asp:TextBox>
                    <asp:RequiredFieldValidator ID="rfvCompanyName" runat="server" Display="Dynamic" ErrorMessage="Required" ControlToValidate="CompanyName"></asp:RequiredFieldValidator>
                </td>
            </tr>
            </asp:Panel>
            <tr>
                <td style="width: 163px;">
                    USA Phone #
                </td>
                <td>
                    <asp:TextBox ID="CommercialPhoneNumber" runat="server" MaxLength="50" ToolTip="Validates a U.S. phone number. It must consist of 3 numeric characters, optionally enclosed in parentheses, followed by a set of 3 numeric characters and then a set of 4 numeric characters. "></asp:TextBox>
                    <asp:RegularExpressionValidator ID="regexpPhone1" runat="server" Display="Dynamic" ErrorMessage="Invalid phone number" ControlToValidate="CommercialPhoneNumber" ValidationExpression="^\(?([0-9]{3})\)?[-.●]?([0-9]{3})[-.●]?([0-9]{4})$" /></td>
            </tr>
            <tr>
                <td style="width: 163px;">
                    International Phone #
                </td>
                <td>
                    <asp:TextBox ID="InternationalPhoneNumber" runat="server" MaxLength="30" ToolTip="Valid international phone number if located overseas. "></asp:TextBox>
                    <asp:Label runat="server" ID="lblPhoneMsg" ForeColor="Red" Visible="false">Must enter a phone number</asp:Label>
                </td>
            </tr>
            <tr>
                <td style="width: 163px;">
                    Name Prefix<font color="red" size="2pt">*</font>
                </td>
                <td>
                    <asp:dropdownlist ID="ddlPrefix" runat="server">
                        <asp:ListItem Value="">(Select)</asp:ListItem>
                        <asp:ListItem Value="Mr." Text="Mr."></asp:ListItem>
                        <asp:ListItem Value="Ms." Text="Ms."></asp:ListItem>
                        <asp:ListItem Value="Mrs." Text="Mrs."></asp:ListItem>
                    </asp:dropdownlist>
                    <asp:RequiredFieldValidator ID="rfvPrefix" runat="server" Display="Dynamic" ErrorMessage="Required" ControlToValidate="ddlPrefix"></asp:RequiredFieldValidator>
                </td>
            </tr>
            <tr>
                <td colspan="2" align="right">
                    <asp:Label runat="server" ID="lblUpdatedMsg" Visible="false" CssClass="message" >Updated your profile record successfully.</asp:Label>
                </td>
            </tr>
        </table>
    </div>

</asp:Content>

