<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.SponsorAction" Title="Pending Users"  Codebehind="SponsorAction.aspx.vb" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
<br />  
    <H3 style="text-align:center">New AMCOS User Account(s) Pending My Approval</H3> 
    <br />
    <asp:GridView ID="UserList" runat="server" AutoGenerateColumns="False" AllowSorting="True" CellPadding="3" CellSpacing="3" HorizontalAlign="Center">
        <Columns>
            <asp:BoundField DataField="UserInfo" Visible="False" />
            <asp:BoundField DataField="fullName" HeaderText="User Name" SortExpression="fullName" />
            <asp:BoundField DataField="Email" HeaderText="Email" SortExpression="Email" />
            <asp:BoundField DataField="ComPhone" HeaderText="Phone" SortExpression="ComPhone" />

            <asp:BoundField DataField="OfficeName" HeaderText="Office Name" SortExpression="OfficeName" />
            <asp:BoundField DataField="Macom" HeaderText="Command/Macom" SortExpression="Macom" />
            <asp:BoundField DataField="SelfAccountType" HeaderText="Account Type" SortExpression="SelfAccountType" />

            <asp:BoundField DataField="ArmyRank" HeaderText="Army Rank" SortExpression="ArmyRank" />
            <asp:BoundField DataField="CompanyName" HeaderText="Company Name" SortExpression="CompanyName" />

            <asp:BoundField DataField="LastLogin" DataFormatString="{0:MM/dd/yyyy}" HtmlEncode="False" HeaderText="Last Login" SortExpression="LastLogin">
                <ItemStyle Width="75px" HorizontalAlign="Left" />
            </asp:BoundField>

            <asp:TemplateField ShowHeader="False">
                <ItemStyle HorizontalAlign="Center" Wrap="false" />
                <ItemTemplate>
                    <asp:Button ID="btnApprove" runat="server" CommandName="Approve" CommandArgument='<%# Bind("UserInfo") %>' Width="60px" Text="Approve" OnClientClick="return confirm('Are you sure you want to approve this user?');" /> &nbsp;
                    <asp:Button ID="btnDeny" runat="server" CommandName="Deny"  CommandArgument='<%# Bind("UserInfo") %>' Width="60px" Text="Deny" OnClientClick="return confirm('Are you sure you want to deny this user?');" />
                </ItemTemplate>
            </asp:TemplateField>
        </Columns>
        <EmptyDataTemplate>
            There are no further users pending your approval.
        </EmptyDataTemplate>
        <HeaderStyle BackColor="DarkBlue" ForeColor="White" />
    </asp:GridView>
    <br />
        <asp:Panel Visible="false" runat="server" ID="EmailSentPanel">
        <hr />
        <table border="1">
        <tr>
        <td>
        From: <asp:Literal runat="server" ID="EmailFrom1Literal"></asp:Literal><br />
        To: <asp:Literal runat="server" ID="EmailTo1Literal"></asp:Literal><br />
        Subject: <asp:Literal runat="server" ID="EmailSubject1Literal"></asp:Literal><br />
        <asp:Literal runat="server" ID="EmailBody1Literal"></asp:Literal><br />
        </td>
        </tr>
        <tr>
        <td>
        <asp:Literal runat="server" ID="EmailFrom2Literal"></asp:Literal><br />
        <asp:Literal runat="server" ID="EmailTo2Literal"></asp:Literal><br />
        <asp:Literal runat="server" ID="EmailSubject2Literal"></asp:Literal><br />
        <asp:Literal runat="server" ID="EmailBody2Literal"></asp:Literal><br />
        </td>
        </tr>
        </table>
        </asp:Panel>
</asp:Content>
