<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.AdminApproval" Title="Admin Approval"  Codebehind="AdminApproval.aspx.vb" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
<br />  
    <h3 style="text-align:center">Pending User Account(s) Approval</h3> 
    <br />
    <asp:GridView ID="UserList" runat="server" AutoGenerateColumns="False" AllowSorting="True" CellPadding="3" CellSpacing="3" HorizontalAlign="Center">
        <Columns>
            <asp:BoundField DataField="UserInfo" Visible="False" />
            <asp:BoundField DataField="UserName" HeaderText="User Name" SortExpression="UserName" />
            <asp:BoundField DataField="UserEmail" HeaderText="User Email" SortExpression="UserEmail" />
            <asp:BoundField DataField="UserPhone" HeaderText="User Phone" SortExpression="UserPhone" />

            <asp:BoundField DataField="UserOfficeName" HeaderText="User Office Name" SortExpression="UserOfficeName" />
            <asp:BoundField DataField="UserMacom" HeaderText="User Command/Macom" SortExpression="UserMacom" />
            <asp:BoundField DataField="UserAccountType" HeaderText="User Account Type" SortExpression="UserAccountType" />

            <asp:BoundField DataField="UserArmyRank" HeaderText="User Army Rank" SortExpression="UserArmyRank" />
            <asp:BoundField DataField="UserCompanyName" HeaderText="User Company Name" SortExpression="UserCompanyName" />

            <asp:BoundField DataField="UserLastLogin" DataFormatString="{0:MM/dd/yyyy}" HtmlEncode="False" HeaderText="User Last Login" SortExpression="UserLastLogin">
                <ItemStyle Width="75px" HorizontalAlign="Left" />
            </asp:BoundField>

            <asp:BoundField DataField="SponsorName" HeaderText="Sponsor Name" SortExpression="SponsorName" ItemStyle-BackColor="#F0E68C" />
            <asp:BoundField DataField="SponsorEmail" HeaderText="Sponsor Email" SortExpression="SponsorEmail" ItemStyle-BackColor="#F0E68C" />
            <asp:BoundField DataField="SponsorPhone" HeaderText="Sponsor Phone" SortExpression="SponsorPhone" ItemStyle-BackColor="#F0E68C" />

            <asp:BoundField DataField="SponsorOfficeName" HeaderText="Sponsor Office Name" SortExpression="SponsorOfficeName" ItemStyle-BackColor="#F0E68C" />
            <asp:BoundField DataField="SponsorMacom" HeaderText="Sponsor Command/Macom" SortExpression="SponsorMacom" ItemStyle-BackColor="#F0E68C" />
            <asp:BoundField DataField="SponsorAccountType" HeaderText="Sponsor Account Type" SortExpression="SponsorAccountType" ItemStyle-BackColor="#F0E68C" />

            <asp:BoundField DataField="SponsorArmyRank" HeaderText="Sponsor Rank" SortExpression="SponsorArmyRank" ItemStyle-BackColor="#F0E68C" />

            <asp:BoundField DataField="UserStatus" HeaderText="User Status" SortExpression="UserStatus" />
            <asp:TemplateField ShowHeader="False">
                <ItemStyle HorizontalAlign="Center" Wrap="false" />
                <ItemTemplate>
                    <asp:Button ID="btnApprove" runat="server" CommandName="Approve" CommandArgument='<%# Bind("UserInfo") %>' Width="60px" Text="Approve" OnClientClick="return confirm('Are you sure you want to approve this user?');" /> &nbsp;
                    <asp:Button ID="btnDeny" runat="server" CommandName="Deny"  CommandArgument='<%# Bind("UserInfo") %>' Width="60px" Text="Deny" OnClientClick="return confirm('Are you sure you want to deny this user?');" />
                </ItemTemplate>
            </asp:TemplateField>
        </Columns>
        <EmptyDataTemplate>
            There are no pending user accounts.
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
