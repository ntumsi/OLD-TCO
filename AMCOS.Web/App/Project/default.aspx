<%@ Page Language="VB" AutoEventWireup="false" Inherits="AMCOS.Web.ProjectDefault" Title="Projects" Codebehind="default.aspx.vb" MasterPageFile="~/SiteAdmin.Master" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
    <div class="reportPage">
        <h1>Project Manager</h1>
        <p class="summary">
            Project Manager costs organizations, groups or individuals for current and future years using JIC Inflation Rates and OMB Discounting & Present Value Factors (PVF).  All reports and project assumptions are exportable to Excel.
        </p>
        <div class="leftPanel">
            <div class="row">
                <div class="small-12 column">
                    <h2>Add a new project:</h2>

                    <ul>
                        <li>Enter new Project Name and Description and click "Add Project", <b>or</b></li>
                        <li>Choose from the drop down selection and click "Copy Project"</li>
                    </ul>
                </div>
            </div>
            <asp:DetailsView ID="dvProject" runat="server" AutoGenerateRows="False" DataSourceID="SqlProject" DefaultMode="Insert" GridLines="None">
                <Fields>
                    <asp:TemplateField HeaderText="Project Name" SortExpression="ProjectName" ShowHeader="false">
                        <InsertItemTemplate>
                            <asp:Label ID="lblName" AssociatedControlID="tbName" runat="server" Text="Project Name" />
                            <asp:TextBox ID="tbName" runat="server" Text='<%# Bind("ProjectName") %>'></asp:TextBox>
                            <asp:RequiredFieldValidator ID="RequiredFieldValidator2" ValidationGroup="NewProject" runat="server" ErrorMessage="Required" Display="Dynamic" ControlToValidate="tbName"></asp:RequiredFieldValidator>
                        </InsertItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="Description" SortExpression="Description" ShowHeader="false">
                        <InsertItemTemplate>
                            <asp:Label ID="lblDescription" AssociatedControlID="tbDescription" runat="server" Text="Description" />
                            <asp:TextBox ID="tbDescription" TextMode="MultiLine" runat="server" Text='<%# Bind("Description") %>' Height="100px"></asp:TextBox>
                            <asp:RequiredFieldValidator ID="RequiredFieldValidator1" ValidationGroup="NewProject" runat="server" ErrorMessage="Required" ControlToValidate="tbDescription" Display="Dynamic"></asp:RequiredFieldValidator>
                        </InsertItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField ShowHeader="False">
                        <InsertItemTemplate>
                            <div class="row">
                                <div class="small-12 column text-center">
                                    <asp:Button ID="btnInsert" runat="server" ValidationGroup="NewProject" CausesValidation="True" CommandName="Insert" Text="Add Project" Width="100%"/>
                                </div>
                                <div class="small-12 column text-center">
                                    or
                                </div>
                                <div class="small-12 column text-center">
                                    <asp:DropDownList ID="ddlExistingProjects" runat="server" DataSourceID="ObjectDataSourceProjects" DataTextField="ProjectName" DataValueField="ProjectId"></asp:DropDownList>
                                    <asp:Button ID="btnCopy" runat="server" ValidationGroup="NewProject" CausesValidation="True" CommandName="Copy" Text="Copy Project" Width="100%"/>
                                </div>
                            </div>
                            <table width="100%">
                                <tr>
                                    <td align="center" style="width: 40%"></td>
                                    <td align="center" style="width: 20%"><p>&nbsp;</p></td>
                                    <td align="center" style="width: 40%"></td>
                                </tr>
                            </table>
                        </InsertItemTemplate>
                    </asp:TemplateField>
                </Fields>
            </asp:DetailsView>
        </div>
        <div class="rightPanel">
            <div class="tableWrapper">
                <asp:GridView ID="projectList" runat="server" AutoGenerateColumns="False" DataKeyNames="ProjectId" DataSourceID="ObjectDataSourceProjects" AllowSorting="True" CellPadding="3" CellSpacing="3">
                    <Columns>
                        <asp:CommandField ShowSelectButton="True" ButtonType="Button">
                            <ItemStyle HorizontalAlign="Center" />
                            <ControlStyle Width="100%" />
                        </asp:CommandField>
                        <asp:BoundField DataField="ProjectId" HeaderText="ProjectId" ReadOnly="True" SortExpression="ProjectId" Visible="False" />
                        <asp:BoundField DataField="UserId" HeaderText="UserId" InsertVisible="False" ReadOnly="True" SortExpression="UserId" Visible="False" />
                        <asp:BoundField DataField="ProjectName" HeaderText="Project Name" SortExpression="ProjectName" />
                        <asp:BoundField DataField="Description" HeaderText="Project Description" SortExpression="Description" />
                        <asp:BoundField DataField="YearStart" HeaderText="Project Start Year" SortExpression="YearStart">
                            <ItemStyle Width="50px" HorizontalAlign="Center" />
                        </asp:BoundField>
                        <asp:BoundField DataField="YearDuration" HeaderText="Project Duration (In Years)" SortExpression="YearDuration">
                            <ItemStyle Width="50px" HorizontalAlign="Center" />
                        </asp:BoundField>
                        <asp:BoundField DataField="LastUpdate" DataFormatString="{0:MM/dd/yyyy}" HtmlEncode="False" HeaderText="Last Update" SortExpression="LastUpdate">
                            <ItemStyle Width="75px" HorizontalAlign="Center" />
                        </asp:BoundField>
                        <asp:BoundField DataField="CreateDate" DataFormatString="{0:MM/dd/yyyy}" HtmlEncode="False" HeaderText="Create Date" SortExpression="CreateDate">
                            <ItemStyle Width="75px" HorizontalAlign="Center" />
                        </asp:BoundField>
                        <asp:TemplateField ShowHeader="False">
                            <ItemStyle HorizontalAlign="Center" />
                            <ItemTemplate>
                                <asp:Button ID="btnProjDelete" runat="server" CausesValidation="true" CommandName="Delete" Width="100%" Text="Delete" OnClientClick="return confirm('Are you sure?');" />
                            </ItemTemplate>
                        </asp:TemplateField>
                    </Columns>
                    <EmptyDataTemplate>
                        No Projects
                    </EmptyDataTemplate>
                    <HeaderStyle BackColor="#0f6938" ForeColor="White" />
                </asp:GridView>
            </div>
        </div>
        <div class="clearfix"><!-- This "clearfix" box keeps the footer from flowing up into the leftPanel when the project list is short.  --></div>
        <asp:SqlDataSource ID="SqlProject" runat="server" ConnectionString="<%$ ConnectionStrings:AmcosAdo %>"
            SelectCommand="SELECT ProjectName, Description FROM webuser.PMProject" 
            InsertCommand="INSERT INTO webuser.PMProject (UserId, ProjectName, YearStart, Description) VALUES (@UserId, @ProjectName, @YearStart, @Description)">
            <InsertParameters>
                <asp:Parameter Name="UserId" />
                <asp:Parameter Name="ProjectName" />
                <asp:Parameter Name="YearStart" />
                <asp:Parameter Name="Description" />
            </InsertParameters>
        </asp:SqlDataSource>
        <asp:ObjectDataSource ID="ObjectDataSourceProjects" runat="server" TypeName="AMCOS.Logic.Project" SelectMethod="GetAllProjectsForUserId" DeleteMethod="DeleteProject">
            <DeleteParameters>
                <asp:Parameter Name="ProjectId" Type="Int32" />
            </DeleteParameters>
        </asp:ObjectDataSource>
    </div>
</asp:Content>