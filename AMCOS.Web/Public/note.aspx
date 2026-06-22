<%@ Page AutoEventWireup="false" Inherits="AMCOS.Web.PublicNote" Language="VB" Codebehind="note.aspx.vb" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>RSS Notes</title>
</head>
<body>
    <form id="form1" runat="server">
        <div>
            <asp:DetailsView ID="DetailsView1" runat="server" AutoGenerateRows="False" DataSourceID="XmlDataSource1" Height="50px" Width="100%" BackColor="White" BorderColor="White" BorderStyle="Ridge" BorderWidth="2px" CellPadding="3" CellSpacing="1" GridLines="None">
                <Fields>
                    <asp:TemplateField HeaderText="Title">
                        <ItemTemplate>
                            <asp:Label ID="Label1" runat="server" Text='<%#XPath("title")%>'></asp:Label>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Description">
                        <ItemTemplate>
                            <asp:Label ID="Label1" runat="server" Text='<%#XPath("description")%>'></asp:Label>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Category">
                        <ItemTemplate>
                            <asp:Label ID="Label1" runat="server" Text='<%#XPath("category")%>'></asp:Label>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Content">
                        <ItemTemplate>
                            <asp:Label ID="Label1" runat="server" Text='<%#XPath("content")%>'></asp:Label>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="DatePub">
                        <ItemTemplate>
                            <asp:Label ID="Label1" runat="server" Text='<%#XPath("pubDate")%>'></asp:Label>
                        </ItemTemplate>
                    </asp:TemplateField>
                </Fields>
                <FooterStyle BackColor="#C6C3C6" ForeColor="Black" />
                <EditRowStyle BackColor="#9471DE" Font-Bold="True" ForeColor="White" />
                <RowStyle BackColor="#DEDFDE" ForeColor="Black" />
                <PagerStyle BackColor="#C6C3C6" ForeColor="Black" HorizontalAlign="Right" />
                <FieldHeaderStyle Width="100px" />
                <HeaderStyle BackColor="#4A3C8C" Font-Bold="True" ForeColor="#E7E7FF" />
            </asp:DetailsView>
            <asp:XmlDataSource ID="XmlDataSource1" runat="server" DataFile="~/Public/rss.xml"></asp:XmlDataSource>
        </div>
    </form>
</body>
</html>
