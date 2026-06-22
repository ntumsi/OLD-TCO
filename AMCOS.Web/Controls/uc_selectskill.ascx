<%@ Control Language="VB" AutoEventWireup="false"
    Inherits="AMCOS.Web.Controls_uc_selectskill" Codebehind="uc_selectskill.ascx.vb" %>
<table>
    <tr>
        <td style="width: 100px">
            <asp:Label ID="lbPayPlan" runat="server" Text="Pay Plan" Font-Size="XX-Small"></asp:Label></td>
        <td style="width: 350px">
            <asp:DropDownList ID="PayPlanList" runat="server" AutoPostBack="True" DataSourceID="SqlDataSource1"
                DataTextField="Description" DataValueField="PayPlan" Font-Size="XX-Small">
            </asp:DropDownList>
        </td>
    </tr>
    <tr>
        <td style="width: 100px">
            <asp:Label ID="lbGroup" runat="server" Text="Group" Font-Size="XX-Small"></asp:Label></td>
        <td style="width: 350px">
            <asp:DropDownList ID="ddlGroup" runat="server" DataSourceID="SqlDataSource2" DataTextField="CategoryGroupDescription"
                DataValueField="Group" AutoPostBack="True" Font-Size="XX-Small">
            </asp:DropDownList>
        </td>
    </tr>
    <tr>
        <td style="width: 100px">
            <asp:Label ID="lbSubGroup" runat="server" Text="Sub Group" Font-Size="XX-Small"></asp:Label></td>
        <td style="width: 350px">
            <asp:DropDownList ID="ddlSubGroup" runat="server" DataSourceID="SqlDataSource3" DataTextField="CategorySubGroupDescription"
                DataValueField="CategorySubGroupCode" Font-Size="XX-Small">
            </asp:DropDownList>
        </td>
    </tr>
    <tr>
        <td style="width: 100px">
            <asp:Label ID="lbLocality" runat="server" Text="Locality" Font-Size="XX-Small"></asp:Label></td>
        <td style="width: 350px">
            <asp:DropDownList ID="LocalityList" runat="server" DataSourceID="SqlDataSource4" DataTextField="Description"
                DataValueField="ID" Font-Size="XX-Small">
            </asp:DropDownList>
        </td>
    </tr>
</table>
<asp:SqlDataSource ID="SqlDataSource1" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
    SelectCommand="SELECT PayPlan , Description FROM lookup.PayPlan"></asp:SqlDataSource>
<asp:SqlDataSource ID="SqlDataSource2" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
    SelectCommand="SELECT DISTINCT CategoryGroupCode , CategoryGroupDescription FROM data.GroupByPayPlan WHERE (PayPlan = @PayPlan) ORDER BY CategoryGroupCode;">
    <SelectParameters>
        <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
    </SelectParameters>
</asp:SqlDataSource>
<asp:SqlDataSource ID="SqlDataSource3" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
    SelectCommand="SELECT CategorySubGroupCode , CategorySubGroupDescription FROM data.GroupSubGroupByPayPlan WHERE ( PayPlan = @PayPlan ) AND ( CategoryGroupCode = @CategoryGroupCode );">
    <SelectParameters>
        <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
        <asp:ControlParameter ControlID="ddlGroup" Name="CategoryGroupCode" PropertyName="SelectedValue" />
    </SelectParameters>
</asp:SqlDataSource>
<asp:SqlDataSource ID="SqlDataSource4" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
    SelectCommand="SELECT ID, Description, Amount FROM lookup.LocalityRates"></asp:SqlDataSource>
