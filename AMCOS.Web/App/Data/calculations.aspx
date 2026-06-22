<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.calculations" Title="AMCOS Cost Calculations" Codebehind="calculations.aspx.vb" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">

    <div class="reportPage">

        <h1>Cost Element Data Dictionary</h1>

        <p class="summary">
            &nbsp;
        </p>

        <div class="leftPanel">

            <div class="row">
                <div class="small-12 column">
                    <asp:Label ID="PayPlanLabel" AssociatedControlID="PayPlanList" runat="server" Text="Pay Plan" />
                    <asp:DropDownList ID="PayPlanList" runat="server" AutoPostBack="True" DataSourceID="SqlDataCalPayPlan" DataTextField="Description" DataValueField="PayPlan"></asp:DropDownList>
                    <asp:SqlDataSource ID="SqlDataCalPayPlan" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>" SelectCommand="SELECT a.PayPlan, b.Description FROM data.CostElement a INNER JOIN lookup.PayPlan b ON a.PayPlan = b. PayPlan GROUP BY a.PayPlan, b.Description ORDER BY Description"></asp:SqlDataSource>
                </div>
            </div>
            <div class="row">
                <div class="small-12 column">
                    <asp:Label ID="AppnLabel" AssociatedControlID="AppnList" runat="server" Text="APPN" />
                    <asp:DropDownList ID="AppnList" runat="server" AutoPostBack="True" DataSourceID="SqlDataElemAppn" DataTextField="APPN" DataValueField="APPN"></asp:DropDownList>
                    <asp:SqlDataSource ID="SqlDataElemAppn" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>" SelectCommand="SELECT APPN FROM data.CostElement WHERE (PayPlan = @PayPlan) GROUP BY APPN">
                        <SelectParameters>
                            <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
                        </SelectParameters>
                    </asp:SqlDataSource>
                </div>
            </div>
            <div class="row">
                <div class="small-12 column">
                    <asp:Label ID="CategoryLabel" AssociatedControlID="CategoryList" runat="server" Text="Category" />
                    <asp:DropDownList ID="CategoryList" runat="server" AutoPostBack="True" DataSourceID="SqlDataElemCategory" DataTextField="CostElementCategory" DataValueField="CostElementCategory"></asp:DropDownList>
                    <asp:SqlDataSource ID="SqlDataElemCategory" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>" SelectCommand="SELECT CostElementCategory FROM data.CostElement WHERE (PayPlan = @PayPlan) AND (APPN = @APPN) GROUP BY CostElementCategory">
                        <SelectParameters>
                            <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
                            <asp:ControlParameter ControlID="AppnList" Name="APPN" PropertyName="SelectedValue" />
                        </SelectParameters>
                    </asp:SqlDataSource>
                </div>
            </div>
            <div class="row">
                <div class="small-12 column">
                    <asp:Label ID="ElementLabel" AssociatedControlID="ElementList" runat="server" Text="Element" />
                    <asp:DropDownList ID="ElementList" runat="server" AutoPostBack="True" DataSourceID="SqlDataElemElement" DataTextField="CostElementName" DataValueField="CostElementName"></asp:DropDownList>
                    <asp:SqlDataSource ID="SqlDataElemElement" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>" SelectCommand="SELECT CostElementName FROM data.CostElement WHERE (PayPlan = @PayPlan) AND (APPN = @APPN) AND (CostElementCategory = @CostElementCategory) GROUP BY CostElementName">
                        <SelectParameters>
                            <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
                            <asp:ControlParameter ControlID="AppnList" Name="APPN" PropertyName="SelectedValue" />
                            <asp:ControlParameter ControlID="CategoryList" Name="CostElementCategory" PropertyName="SelectedValue" />
                        </SelectParameters>
                    </asp:SqlDataSource>
                </div>
            </div>
            <div class="row">
                <div class="small-12 column">
                </div>
            </div>

        </div>

        <div class="rightPanel">

            <asp:SqlDataSource ID="SqlDataElemData" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>" SelectCommand="SELECT CostElementName, Description, BusinessLogic, BasisOfComputation, Source FROM data.CostElement WHERE (PayPlan = @PayPlan) AND (APPN = @APPN) AND (CostElementCategory = @CostElementCategory) AND (CostElementName = @CostElementName)">
                <SelectParameters>
                    <asp:ControlParameter ControlID="PayPlanList" Name="PayPlan" PropertyName="SelectedValue" />
                    <asp:ControlParameter ControlID="AppnList" Name="APPN" PropertyName="SelectedValue" />
                    <asp:ControlParameter ControlID="CategoryList" Name="CostElementCategory" PropertyName="SelectedValue" />
                    <asp:ControlParameter ControlID="ElementList" Name="CostElementName" PropertyName="SelectedValue" />
                </SelectParameters>
            </asp:SqlDataSource>

            <div class="tableWrapper">
                <asp:DetailsView ID="DetailsView1" runat="server" AutoGenerateRows="False" DataSourceID="SqlDataElemData" Height="50px" HorizontalAlign="Left" Width="100%"
                    BackColor="White" BorderColor="White" BorderStyle="Ridge" BorderWidth="2px" CellPadding="3" CellSpacing="1" Font-Size="10pt" GridLines="None" Font-Strikeout="False">
                    <Fields>
                        <asp:BoundField DataField="CostElementName" HeaderText="CostElementName" SortExpression="CostElementName" />
                        <asp:BoundField DataField="Description" HeaderText="Description" SortExpression="Description" />
                        <asp:BoundField DataField="BusinessLogic" HeaderText="BusinessLogic" SortExpression="BusinessLogic" />
                        <asp:BoundField DataField="BasisOfComputation" HeaderText="BasisOfComputation" SortExpression="BasisOfComputation" />
                        <asp:BoundField DataField="Source" HeaderText="Source" SortExpression="Source" />
                    </Fields>
                    <FooterStyle BackColor="#C6C3C6" ForeColor="Black" />
                    <EditRowStyle BackColor="#9471DE" Font-Bold="True" ForeColor="White" />
                    <RowStyle BackColor="#DEDFDE" ForeColor="Black" />
                    <PagerStyle BackColor="#C6C3C6" ForeColor="Black" HorizontalAlign="Right" />
                    <FieldHeaderStyle Width="150px" Wrap="True" />
                    <HeaderStyle BackColor="#4A3C8C" Font-Bold="True" ForeColor="#E7E7FF" />
                </asp:DetailsView>
            </div>

        </div>

        <div class="clearfix">&nbsp;</div>

    </div>

</asp:Content>
