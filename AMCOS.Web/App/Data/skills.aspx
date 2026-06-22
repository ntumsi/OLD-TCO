<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.Skills" Title="Skills" Codebehind="skills.aspx.vb" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
    <table class="reserve-component-drills" width="100%" border="0" cellspacing="3" cellpadding="3"
        summary="Information on Reserve Component Pay Rates - POM 05-09.">
        <tr>
            <td align="left">
                <b>Skills</b>
            </td>
        </tr>
    </table>
    <table>
        <tr>
            <td style="width: 100px">
                Pay Plan
            </td>
            <td style="width: 100px">
                <asp:DropDownList ID="PayPlanList" runat="server" AutoPostBack="True" DataSourceID="SqlDataSkillPayPlan"
                    DataTextField="Description" DataValueField="PayPlan">
                </asp:DropDownList>
                <asp:SqlDataSource ID="SqlDataSkillPayPlan" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
                    SelectCommand="SELECT DISTINCT PayPlan,Description FROM lookup.PayPlan ORDER BY PayPlan;"></asp:SqlDataSource>
            </td>
        </tr>
        <tr>
            <td style="width: 100px">
                Group
            </td>
            <td style="width: 100px">
                <asp:DropDownList ID="ddlGroup" runat="server" AutoPostBack="True" DataSourceID="SqlDataSkillGroup"
                    DataTextField="CategoryGroupCode" DataValueField="CategoryGroupCode">
                </asp:DropDownList>
                <asp:SqlDataSource ID="SqlDataSkillGroup" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
                    SelectCommand="SELECT DISTINCT CategoryGroupCode FROM data.GroupByPayPlan WHERE (PayPlan = @PayPlan) ORDER BY CategoryGroupCode;">
                    <SelectParameters>
                        <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
                    </SelectParameters>
                </asp:SqlDataSource>
            </td>
        </tr>
        <tr>
            <td style="width: 100px">
                SubGroup
            </td>
            <td style="width: 100px">
                <asp:DropDownList ID="ddlSubGroup" runat="server" AutoPostBack="True" DataSourceID="SqlDataSkillSubGroup"
                    DataTextField="CategorySubGroupCode" DataValueField="CategorySubGroupCode">
                </asp:DropDownList>
                <asp:SqlDataSource ID="SqlDataSkillSubGroup" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
                    SelectCommand="SELECT CategorySubGroupCode FROM data.GroupSubGroupByPayPlan WHERE (PayPlan = @PayPlan) AND (CategoryGroupCode = @CategoryGroupCode) ORDER BY CategorySubGroupCode;">
                    <SelectParameters>
                        <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
                        <asp:ControlParameter ControlID="ddlGroup" Name="CategoryGroupCode" PropertyName="SelectedValue" />
                    </SelectParameters>
                </asp:SqlDataSource>
            </td>
        </tr>
    </table>
    <asp:DetailsView ID="DetailsView1" runat="server" AutoGenerateRows="False" BackColor="White"
        BorderColor="White" BorderStyle="Ridge" BorderWidth="2px" CellPadding="3" CellSpacing="1"
        DataSourceID="SqlDataSkillData" GridLines="None" Height="50px" Width="50%">
        <FooterStyle BackColor="#C6C3C6" ForeColor="Black" />
        <EditRowStyle BackColor="#9471DE" Font-Bold="True" ForeColor="White" />
        <RowStyle BackColor="#DEDFDE" ForeColor="Black" />
        <PagerStyle BackColor="#C6C3C6" ForeColor="Black" HorizontalAlign="Right" />
        <Fields>
            <asp:BoundField DataField="CategoryGroupCode" HeaderText="Group" SortExpression="Group" />
            <asp:BoundField DataField="CategoryGroupDescription" HeaderText="Group Description" SortExpression="CategoryGroupDescription" />
            <asp:BoundField DataField="CategorySubGroupCode" HeaderText="Subgroup" SortExpression="CategorySubGroupCode" />
            <asp:BoundField DataField="CategorySubGroupDescription" HeaderText="Subgroup Description"
                SortExpression="CategorySubGroupDescription" />
        </Fields>
        <FieldHeaderStyle Width="150px" Wrap="False" />
        <HeaderStyle BackColor="#4A3C8C" Font-Bold="True" ForeColor="#E7E7FF" />
    </asp:DetailsView>
    <asp:SqlDataSource ID="SqlDataSkillData" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
        SelectCommand="SELECT CategoryGroupCode,CategoryGroupDescription,CategorySubGroupCode,CategorySubGroupDescription FROM data.GroupSubGroupByPayPlan WHERE (PayPlan = @PayPlan) AND (CategoryGroupCode = @CategoryGroupCode) AND (CategorySubGroupCode = @CategorySubGroupCode);">
        <SelectParameters>
            <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
            <asp:ControlParameter ControlID="ddlGroup" Name="CategoryGroupCode" PropertyName="SelectedValue" />
            <asp:ControlParameter ControlID="ddlSubGroup" Name="CategorySubGroupCode" PropertyName="SelectedValue" />
        </SelectParameters>
    </asp:SqlDataSource>
</asp:Content>
