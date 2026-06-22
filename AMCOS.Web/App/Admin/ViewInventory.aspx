<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.ViewInventory" Codebehind="ViewInventory.aspx.vb" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
    <div>
        <h2>Inventory Comparison between Development and Production:</h2>
    <table cellpadding="3px" cellspacing="3px">
        <tr>
            <td>
                Pay Plan:
            </td>
            <td><asp:Label runat="server" ID="lblPayPlan" Font-Underline="true"></asp:Label></td>
        </tr>
        <tr>
            <td>
                <asp:Label ID="lbGroup" runat="server" Text="Group:"></asp:Label>
            </td>
            <td><asp:Label runat="server" ID="lblGroup" Font-Underline="true"></asp:Label></td>
        </tr>
        <tr>
            <td>
                <asp:Label ID="lbSubGroup" runat="server" Text="SubGroup:"></asp:Label>
            </td>
            <td><asp:Label runat="server" ID="lblSubGroup" Font-Underline="true"></asp:Label></td>
        </tr>
</table>
        <br />
        <asp:GridView ID="gvDiffDP" runat="server" CellPadding="5" ShowFooter="True" EmptyDataText="No Data">
            <FooterStyle BackColor="#DEDFDE" />
            <HeaderStyle BackColor="DarkBlue" ForeColor="White" />
        </asp:GridView>
    </div>
    </form>
</body>
</html>
