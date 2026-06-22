<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Template.aspx.vb" Inherits="AMCOS.Web.Template" %>

<asp:Label runat="server" id="Label0" /><p />
<p>An error has occurred within the AMCOS application. Please click <a href="<%=ConfigurationManager.AppSettings("AmcosUrl")%>" target="_blank">here</a> to visit the website for more information.</p>
<asp:DataList id="EventList" runat="server">
    <ItemTemplate>
        Event time: <%# DataBinder.Eval(Container.DataItem, "EventTime").ToString() %>
        Event message: <%# DataBinder.Eval(Container.DataItem, "Message").ToString() %>
    </ItemTemplate>
</asp:DataList>