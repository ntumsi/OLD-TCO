<%@ Page Language="VB" MaintainScrollPositionOnPostback="true" AutoEventWireup="false" Inherits="AMCOS.Web.ProjectDetails" Title="Project Details" Codebehind="details.aspx.vb" MasterPageFile="~/SiteAdmin.Master" %>
<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
    <asp:HiddenField ID="projectStartYear" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="projectDuration" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedPayPlan" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedCategoryGroupCode" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedCategorySubgroupCode" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedCareerProgramNumber" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedLocationId" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedLocationText" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedScienceTechnologyReinventionLaboratory" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedDependentStatus" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedNumberOfDependents" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedGradeLevel" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="inputActiveDutyDays" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="inputOverheadPercent" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="inputProjectInventory" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedUnit" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="excludedPayPlans" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="unitLocation" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedOperation" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="inputNewSubprojectName" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedMtoeProjectInventoryYear" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="selectedProjectExtendsSacsYears" runat="server" ClientIDMode="Static" />
    <asp:HiddenField ID="inputUnitContractorOverheadPercent" runat="server" ClientIDMode="Static" />
    <div class="reportPage">
        <h1>Name: <%=currentProject.ProjectName%>
            <asp:Button ID="btnCloseProject" runat="server" Text="Close Project" CausesValidation="False" CssClass="btnCloseProject" />
        </h1>
        <p class="summary">Description: <%=currentProject.Description%></p>
        <asp:Wizard ID="wizProject" runat="server" CellPadding="5" CellSpacing="5" ActiveStepIndex="0">          
            <LayoutTemplate>
                <div class="expanded row">
                    <div class="columns large-2">
                        <asp:PlaceHolder ID="sideBarPlaceHolder" runat="server" />
                    </div>
                    <div class="columns large-10">
                        <asp:PlaceHolder ID="WizardStepPlaceHolder" runat="server" />
                    </div>
                </div>                    
                <div class="expanded column row">
                    <asp:PlaceHolder ID="navigationPlaceHolder" runat="server" />
                </div>
            </LayoutTemplate>
            <SideBarStyle VerticalAlign="Top" Width="125px" Wrap="False" Font-Size="X-Large" />
            <FinishCompleteButtonStyle CssClass="wizardFinishButtonHide" />
            <SideBarTemplate>
                <asp:DataList ID="SideBarList" runat="server">
                    <ItemTemplate>
                        <asp:LinkButton ID="SideBarButton" runat="server" CssClass="wizardStepButton" />
                    </ItemTemplate>
                    <SelectedItemTemplate>
                        <asp:LinkButton ID="SideBarButton" runat="server" CssClass="wizardCurrentStepHighlight" />
                    </SelectedItemTemplate>
                </asp:DataList>
            </SideBarTemplate>
            <WizardSteps>
                <asp:WizardStep ID="wizardStep1" runat="server" Title="Properties">
                    <p>The Properties Page establishes initial settings for the project.<br />
                        <br />
                        <b>The initial Project Name may be modified by clicking into the Project Name field, editing the text and clicking next.</b>
                    </p>
                    <asp:DetailsView ID="ProjectPropertiesDetail" runat="server" AutoGenerateRows="False" DataKeyNames="ProjectId" DataSourceID="ProjectProperties" Height="50px" DefaultMode="Edit">
                        <FieldHeaderStyle Width="220px" BackColor="#0f6938" ForeColor="White" />
                        <Fields>
                            <asp:BoundField DataField="UserId" HeaderText="UserId" ReadOnly="True" Visible="False" SortExpression="UserId" />
                            <asp:BoundField DataField="ProjectId" HeaderText="ProjectId" InsertVisible="False" ReadOnly="True" Visible="False" SortExpression="ProjectId" />
                            <asp:TemplateField HeaderText="Project Name" SortExpression="ProjectName">
                                <EditItemTemplate>
                                    <asp:TextBox ID="tbName" runat="server" Text='<%# Bind("ProjectName") %>' ToolTip="Enter Project Name"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="rfvName" runat="server" ControlToValidate="tbName" Display="Dynamic" ErrorMessage="*"></asp:RequiredFieldValidator>
                                </EditItemTemplate>
                                <ControlStyle Width="300px" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Description" SortExpression="Description">
                                <EditItemTemplate>
                                    <asp:TextBox ID="tbDescription" TextMode="MultiLine" Width="300px" Height="75px" runat="server" Text='<%# Bind("Description") %>'></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="rfvDescription" runat="server" ControlToValidate="tbName" Display="Dynamic" ErrorMessage="*"></asp:RequiredFieldValidator>
                                </EditItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Start Year" SortExpression="YearStart">
                                <EditItemTemplate>
                                    <asp:TextBox ID="tbYearStart" runat="server" Text='<%# Bind("YearStart") %>' ToolTip="Enter first year of project"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="rfvYearStart" runat="server" ControlToValidate="tbYearStart" Display="Dynamic" Visible="true" ErrorMessage="Required">Required</asp:RequiredFieldValidator>
                                    <asp:RangeValidator ID="rvYearStart" runat="server" ControlToValidate="tbYearStart" Display="Dynamic" Type="Integer" MinimumValue="<%# Me.minimumStartYear %>" MaximumValue="<%# Me.maximumStartYear %>" ErrorMessage="* Must be within the next 30 years"></asp:RangeValidator>
                                </EditItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Project Duration" SortExpression="YearDuration">
                                <EditItemTemplate>
                                    <asp:TextBox ID="tbYearDuration" runat="server" Text='<%# Bind("YearDuration") %>' ToolTip="Enter number of years of the Project" ClientIDMode="Static"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="rfvYearDuration" runat="server" ControlToValidate="tbYearDuration" Display="Dynamic" ErrorMessage="Required">Required</asp:RequiredFieldValidator>
                                    <asp:RangeValidator ID="rvYearDuration" runat="server" ControlToValidate="tbYearDuration" Display="Dynamic" ErrorMessage="* Value must be between 1 and 30 years" MaximumValue="30" MinimumValue="1" Type="Integer"></asp:RangeValidator>
                                </EditItemTemplate>
                            </asp:TemplateField>
                        </Fields>
                    </asp:DetailsView>
                    <asp:ObjectDataSource ID="ProjectProperties" runat="server" TypeName="AMCOS.Logic.Project" SelectMethod="GetProject" UpdateMethod="UpdateProjectProperties" OldValuesParameterFormatString="original{0}">
                        <SelectParameters>
                            <asp:Parameter Name="ProjectId" />
                        </SelectParameters>                        
                    </asp:ObjectDataSource>
                    <br />
                </asp:WizardStep>
                <asp:WizardStep ID="wizardStep2" runat="server" Title="Add unit (Optional)">
                    <p>If you do not need to add an entire unit, please click the 'Next' button to move to Faces & Spaces where you can add positions individually.</p>
                    <select id="unitList" class="demo-default selectized extended-width"></select>
                    <ul class="accordion" data-accordion data-allow-all-closed="true">
                        <li class="accordion-item" data-accordion-item>
                            <a href="#" class="accordion-title unit-summary">Unit Summary (Pay Plan/Location) Selection(s): <b>All</b></a>
                            <div class="accordion-content" data-tab-content>
                                <p id="personnelForUnit"></p>
                                <table id="payPlansInUnit" class="hide"></table>
                            </div>
                        </li>
                        <li class="accordion-item" data-accordion-item>
                            <a href="#" class="accordion-title project-action">Project Action  Selection: <b>Replace</b></a>
                            <div class="accordion-content" data-tab-content>
                                <p>Select the action below you would like taken in regards to your existing project</p>
                                <fieldset>
                                    <div>
                                        <label style="display:block"><input type="radio" style="vertical-align:middle" name="operation" value="Replace" id="operationReplace" required checked>Replace the main project</label>
                                        <label style="display:block"><input type="radio" style="vertical-align:middle" name="operation" value="Append" id="operationAppend">Append to the main project</label>
                                        <label style="display:block"><input type="radio" style="vertical-align:middle" name="operation" value="Subproject" id="operationSubproject">Add this unit as a subproject with name: <input type="text" id="newSubprojectName" /></label>
                                    </div>
                                </fieldset>
                            </div>
                        </li>
                        <li class="accordion-item" data-accordion-item>
                            <a href="#" class="accordion-title unit-location">Unit Location Selection: <b>Unchanged</b></a>
                            <div class="accordion-content" data-tab-content>
                                <p>Select whether you would like AMCOS to change the entire location of the unit for all pay plans.  Note that if you choose an installation for which AMCOS does not have data, the application will follow the reassignment priority shown at the bottom of the page.</p>
                                <fieldset id="unitLocationFilter">
                                    <div>
                                        <label style="display:block"><input type="radio" style="vertical-align:middle" name="unitLocation" value="Unchanged" id="unitLocationKeep" required checked>Leave the location unchanged</label>
                                        <label style="display:block"><input type="radio" style="vertical-align:middle" name="unitLocation" value="National Average" id="unitNationalAverage">Use a National Average</label>
                                        <label style="display:block"><input type="radio" style="vertical-align:middle" name="unitLocation" value="Change" id="unitLocationChange">Choose a new location</label>
                                        <select id="unitLocationList" class="demo-default selectized"></select>
                                    </div>
                                </fieldset>
                            </div>
                        </li>
                        <li class="accordion-item" data-accordion-item>
                            <a href="#" class="accordion-title fiscal-years">Fiscal Years Selection: <b>Not applicable</b></a>
                            <div class="accordion-content" data-tab-content>
                                <p id="projectInventoryYearOptionsText"></p>
                                <fieldset id="projectInventoryYear" class="hide">                                    
                                    <label style="display:block"><input type="radio" style="vertical-align:middle" name="projectInventoryYear" value="Sync" id="projectInventoryYearSync" required checked>Sync your project's years to the SACS' years</label>
                                    <label style="display:block"><input type="radio" style="vertical-align:middle" name="projectInventoryYear" value="Freeze" id="projectInventoryYearFreeze">Freeze the data at year:</label><select id="mtoeUnitYearList" class="demo-default selectized"></select>
                                </fieldset>
                                <div id="mtoeSyncOption" class="hide">
                                    <fieldset id="projectExtendsSacsYears">                                
                                        <legend>Your project extends beyond the available FYs in the SACS file.  Do you want to:</legend>
                                        <label style="display:block"><input type="radio" name="projectExtendsSacsYears" value="Last MTOE" id="projectExtendsSacsYearsLastMtoe" required checked>Freeze project years beyond the current SACS at the last available MTOE year</label>
                                        <label style="display:block"><input type="radio" name="projectExtendsSacsYears" value="OTOE" id="projectExtendsSacsYearsOtoe">Use the Objective TOE (OTOE) for years beyond the SACS years</label>
                                    </fieldset>
                                </div>
                            </div>                            
                        </li>
                        <li class="accordion-item" data-accordion-item>
                            <a href="#" class="accordion-title contractor-cost-estimate-overhead">Contractor Cost Estimate Overhead: <b>Not applicable</b></a>
                            <div class="accordion-content" data-tab-content>
                                <p id="contractorCostEstimateOverheadAccordionText"></p>
                                <fieldset id="contractorCostEstimateOverheadAccordionInput" class="hide">
                                    <label for="unitContractorOverheadPercent">Overhead Percentage:</label><input id="unitContractorOverheadPercent" type="number" value="150"/>
                                </fieldset>
                            </div>
                        </li>
                    </ul>                  
                    <p>Note:  AMCOS may not have a cost for certain scenarios as our costs are based on inventory.  In those cases, we will add the personnel to your project using the following priority:</p>
                    <ol>
                        <li>Unit driven location(s) but Group average</li>
                        <li>Unit driven location(s) but Pay Plan average</li>
                        <li>All locations (average) and Unit driven Subgroup(s)</li>
                        <li>All locations (average) and Group average</li>
                        <li>All locations (average) and Pay Plan average</li>
                        <li>A zero cost</li>
                    </ol>
                </asp:WizardStep>
                <asp:WizardStep ID="wizardStep3" runat="server" Title="Faces &amp; Spaces">
                    <h3>Faces and Spaces are for personnel inventory input.</h3>
                    <p>
                        <b>NOTE: No output will be generated if no inventory is provided.</b>
                    </p>
                    <p>
                        Edit any Year's inventory and commit changes by clicking the "Update" button.
                    </p>
                    <div>
                        <asp:ValidationSummary ID="InsertInventoryValidationSummary" runat="server" DisplayMode="BulletList" ShowSummary="true" ValidationGroup="InventoryInsert" HeaderText="Errors while inserting new inventory:"/>
                    </div>
                    <div>
                        <asp:ValidationSummary ID="UpdateInventoryValidationSummary" runat="server" DisplayMode="BulletList" ShowSummary="true" ValidationGroup="InventoryUpdate" HeaderText="Errors while updating existing inventory:"/>
                    </div>
                    <asp:DataList ID="PMCategoryDataList" runat="server" RepeatDirection="Horizontal" CellPadding="1" CellSpacing="1" DataSourceID="odsCategories">
                        <ItemTemplate>
                            <asp:Button ID="btnCategory" CausesValidation="false" CommandName='ButtonTab' CommandArgument='<%# Eval("CategoryId") %>' runat="server" Text='<%# Eval("CategoryName") %>' />
                        </ItemTemplate>
                    </asp:DataList>
                    <asp:ObjectDataSource ID="odsCategories" runat="server" SelectMethod="GetRequirements" TypeName="AMCOS.Logic.ProjectRequirement">
                        <SelectParameters>
                            <asp:Parameter Name="ProjectId" Type="Int32" />
                        </SelectParameters>
                    </asp:ObjectDataSource>
                    <div style="overflow-x: scroll;">
                        <asp:GridView HorizontalAlign="Center" ID="InventoryGridView" runat="server" ShowFooter="True" AutoGenerateColumns="False" DataKeyNames="CategoryId" DataSourceID="odsSkillInventories" EmptyDataText="No Inventory Found">
                        <Columns>
                            <asp:TemplateField HeaderText="UIC" SortExpression="Uic">
                                <ItemTemplate>
                                    <asp:Label ID="UicLabel" runat="server" Text='<%# Bind("Uic") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="PayPlan" SortExpression="PayPlan">
                                <ItemTemplate>
                                    <asp:Label ID="lblPayPlan" Text='<%# Bind("PayPlan") %>' runat="server" />
                                    <asp:HiddenField ID="skillId" runat="server" Value='<%# Bind("SkillId") %>'></asp:HiddenField>
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Group" SortExpression="CategoryGroupCode">
                                <ItemTemplate>
                                    <asp:Label ID="lblGroup" runat="server" Text='<%# Bind("CategoryGroupCode") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Subgroup" SortExpression="CategorySubgroupCode">
                                <ItemTemplate>
                                    <asp:Label ID="lblSubGroup" runat="server" Text='<%# Bind("CategorySubgroupCode") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Career Program" SortExpression="CareerProgramNumber">
                                <ItemTemplate>
                                    <asp:Label ID="lblCareerProgram" runat="server" Text='<%# Bind("CareerProgramNumber") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Location" SortExpression="Location">
                                <ItemTemplate>
                                    <asp:Label ID="lblLocation" runat="server" Text='<%# Bind("Location") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="STRL" SortExpression="STRL">
                                <ItemTemplate>
                                    <asp:Label ID="lblSTRL" runat="server" Text='<%# Bind("STRL") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Dependent Status" SortExpression="DependentStatus">
                                <ItemTemplate>
                                    <asp:Label ID="lblDependentStatus" runat="server" Text='<%# Bind("DependentStatus") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Number of Dependents" SortExpression="NumberOfDependents">
                                <ItemTemplate>
                                    <asp:Label ID="lblNumberOfDependents" runat="server" Text='<%# Bind("NumberOfDependents") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Active Duty Days" SortExpression="activeDays">
                                <ItemTemplate>
                                    <asp:Label ID="lblActiveDays" runat="server" Text='<%# Bind("ActiveDutyDays") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Overhead %" SortExpression="plmOverheadPct">
                                <ItemTemplate>
                                    <asp:Label ID="lblOverheadPct" runat="server" Text='<%# Bind("OverheadPercent") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Grade" SortExpression="Grade">
                                <ItemTemplate>
                                    <asp:Label ID="lblGrade" runat="server" Text='<%# Bind("Grade") %>' />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear0" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear0NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear0" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear0RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear0" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 1." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear1" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear1NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear1" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear1RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear1" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 2." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear2" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear2NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear2" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear2RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear2" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 3." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear3" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear3NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear3" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear3RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear3" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 4." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear4" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear4NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear4" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear4RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear4" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 5." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear5" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear5NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear5" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear5RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear5" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 6." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear6" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear6NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear6" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear6RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear6" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 7." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear7" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear7NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear7" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear7RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear7" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 8." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear8" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear8NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear8" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear8RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear8" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 9." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear9" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear9NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear9" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear9RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear9" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 10." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear10" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear10NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear10" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear10RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear10" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 11." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear11" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear11NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear11" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear11RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear11" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 12." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear12" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear12NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear12" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear12RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear12" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 13." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear13" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear13NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear13" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear13RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear13" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 14." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear14" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear14NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear14" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear14RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear14" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 15." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear15" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear15NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear15" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear15RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear15" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 16." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear16" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear16NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear16" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear16RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear16" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 17." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear17" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear17NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear17" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear17RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear17" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 18." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear18" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear18NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear18" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear18RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear18" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 19." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear19" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear19NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear19" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear19RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear19" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 20." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear20" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear20NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear20" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear20RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear20" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 21." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear21" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear21NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear21" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear21RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear21" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 22." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear22" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear22NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear22" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear22RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear22" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 23." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear23" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear23NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear23" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear23RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear23" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 24." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear24" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear24NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear24" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear24RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear24" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 25." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear25" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear25NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear25" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear25RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear25" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 26." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear26" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear26NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear26" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear26RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear26" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 27." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear27" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear27NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear27" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear27RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear27" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 28." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear28" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear28NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear28" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear28RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear28" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 29." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear29" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear29NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear29" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear29RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear29" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 30." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField Visible="False">
                                <ItemTemplate>
                                    <asp:TextBox ID="UpdateYear30" runat="server" MaxLength="5" Text="1" />
                                    <asp:RegularExpressionValidator ID="UpdateYear30NumberValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear30" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                    <asp:RequiredFieldValidator ID="UpdateYear30RequiredValidator" runat="server" ValidationGroup="InventoryUpdate" ControlToValidate="UpdateYear30" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for year 31." />
                                </ItemTemplate>
                                <ItemStyle CssClass="updateProjectInventory" />
                                <HeaderStyle CssClass="updateProjectInventory" />
                            </asp:TemplateField>
                            <asp:TemplateField>
                                <HeaderTemplate>
                                    <asp:Button ID="btnDelete" Text="Delete" CommandName="btnDelete" runat="server" OnClientClick="return confirm('Are you sure to delete all the checked rows?');" />
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <asp:CheckBox ID="chkDelete" runat="server" />
                                </ItemTemplate>
                            </asp:TemplateField>
                        </Columns>
                        <HeaderStyle BackColor="#0f6938" ForeColor="White" Font-Size="7pt" />
                        <AlternatingRowStyle Font-Size="7pt" />
                        <RowStyle Font-Size="7pt" />
                    </asp:GridView>
                    </div>
                    <asp:ObjectDataSource ID="odsSkillInventories" runat="server" SelectMethod="GetRequirementsAndInventory" TypeName="AMCOS.Logic.ProjectRequirement">
                        <SelectParameters>
                            <asp:Parameter Name="CategoryId" Type="Int32" />
                        </SelectParameters>
                    </asp:ObjectDataSource>
                    <br />
                    <div class="text-center">
                        <asp:Button runat="server" ID="btnUpdate" Text="Update" CausesValidation="true" ValidationGroup="InventoryUpdate" />
                    </div>
                    <br />To add positions to the current project, complete the Personnel Area selections:<br />
                    <br />
                    <div>
                        <div class="row">
                            <div class="column small-1"><b>NOTE:</b></div>
                            <div class="column small-9 end">
                                <ul>
                                    <li>Your initial manpower requirements build can be added to any one of the sub-project tabs.</li>
                                    <li>If you are unable to select a particular skill, there was no inventory reported for that skill at the end of the previous fiscal year.</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                    <div id="ProjectInventoryInsertTable">
                        <div class="row">
                            <div class="column">
                                <label>Pay Plan
                                    <select id="payPlanList" class="demo-default selectized"></select>
                                </label>
                            </div>
                        </div>
                        <div id="categoryFilter" class="row hide">
                            <div class="column">
                                <label>Group
                                    <select id="categoryList" class="demo-default selectized"></select>
                                </label>
                            </div>
                        </div>
                        <div id="locationFilter" class="row hide">
                            <div class="column">
                                <label>Location
                                    <select id="locationList" class="demo-default selectized"></select>
                                </label>
                            </div>
                        </div>
                        <div id="scienceTechnologyReinventionLaboratoryFilter" class="row hide">
                            <div class="column">
                                <label>Science and Technology Reinvention Laboratory (STRL)
                                    <select id="scienceTechnologyReinventionLaboratoryList" class="demo-default selectized"></select>
                                </label>
                            </div>
                        </div>
                        <div id="dependentStatusFilter" class="row hide">
                            <div class="column">
                                <label>Dependent Status
                                    <select id="dependentStatusList" class="demo-default selectized"></select>
                                </label>
                            </div>
                        </div>
                        <div id="numberOfDependentsFilter" class="row hide">
                            <div class="column">    
                                <label>Number of Dependents
                                    <select id="numberOfDependentsList" class="demo-default selectized"></select>
                                </label>
                            </div>
                        </div>
                        <div id="gradeLevelFilter" class="row hide">
                            <div class="column">
                                <label>Grade
                                    <select id="gradeLevelList" class="demo-default selectized"></select>
                                </label>
                            </div>
                        </div>
                        <div id="activeDutyDaysFilter" class="row hide">
                            <div class="column">
                                <label for="activeDutyDays">Active Duty Days
                                    <input type="number" id="activeDutyDays" value="15" min="15" max="365" required />
                                </label>
                                Note: Costs include a fixed assumption of 24 weekend drill days.  The default Active Duty days of 15 are for the two week annual drill period and may be increased, impacting variable cost elements.
                            </div>
                        </div>
                        <div id="overheadPercentFilter" class="row hide">
                            <div class="column">
                                <label for="overheadPercent">Overhead Percent
                                    <input type="number" id="overheadPercent" value="0" min="0" max="200" required />
                                </label>
                            </div>
                        </div>
                        <div id="inventoryFilter" class="row hide">
                            <div class="column">
                                <label>Inventory
                                    <div class="table-scroll">
                                        <table id="tblInventory">
                                            <thead>
                                            <tr>
                                                <th>1</th>
                                                <th>2</th>
                                                <th>3</th>
                                                <th>4</th>
                                                <th>5</th>
                                                <th>6</th>
                                                <th>7</th>
                                                <th>8</th>
                                                <th>9</th>
                                                <th>10</th>
                                                <th>11</th>
                                                <th>12</th>
                                                <th>13</th>
                                                <th>14</th>
                                                <th>15</th>
                                                <th>16</th>
                                                <th>17</th>
                                                <th>18</th>
                                                <th>19</th>
                                                <th>20</th>
                                                <th>21</th>
                                                <th>22</th>
                                                <th>23</th>
                                                <th>24</th>
                                                <th>25</th>
                                                <th>26</th>
                                                <th>27</th>
                                                <th>28</th>
                                                <th>29</th>
                                                <th>30</th>
                                            </tr>                                                
                                        </thead>
                                            <tbody>
                                            <tr>
                                                <td>
                                                    <asp:TextBox ID="InsertYear1" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear1NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear1" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear1RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear1" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the first year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear2" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear2NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear2" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear2RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear2" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the second year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear3" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear3NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear3" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear3RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear3" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the third year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear4" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear4NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear4" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear4RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear4" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the fourth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear5" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear5NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear5" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear5RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear5" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the fifth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear6" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear6NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear6" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear6RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear6" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the sixth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear7" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear7NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear7" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear7RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear7" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the seventh year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear8" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear8NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear8" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear8RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear8" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear9" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear9NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear9" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear9RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear9" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the ninth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear10" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear10NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear10" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear10RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear10" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the tenth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear11" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear11NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear11" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear11RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear11" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eleventh year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear12" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear12NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear12" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear12RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear12" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the twelfth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear13" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear13NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear13" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear13RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear13" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the thirteenth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear14" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear14NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear14" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear14RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear14" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the fourteenth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear15" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear15NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear15" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear15RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear15" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the fifteenth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear16" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear16NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear16" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear16RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear16" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the sixteenth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear17" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear17NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear17" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear17RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear17" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear18" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear18NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear18" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear18RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear18" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear19" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear19NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear19" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear19RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear19" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear20" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear20NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear20" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear20RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear20" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear21" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear21NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear21" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear21RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear21" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear22" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear22NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear22" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear22RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear22" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear23" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear23NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear23" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear23RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear23" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear24" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear24NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear24" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear24RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear24" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear25" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear25NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear25" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear25RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear25" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear26" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear26NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear26" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear26RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear26" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear27" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear27NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear27" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear27RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear27" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear28" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear28NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear28" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear28RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear28" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear29" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear29NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear29" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear29RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear29" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="InsertYear30" MaxLength="5" runat="server" ClientIDMode="Static" />
                                                    <asp:RegularExpressionValidator ID="InsertYear30NumberValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear30" ValidationExpression="^[0-9]+" Display="None" Visible="True" ErrorMessage="The inventory value must be a number." />
                                                    <asp:RequiredFieldValidator ID="InsertYear30RequiredValidator" runat="server" ValidationGroup="InventoryInsert" ControlToValidate="InsertYear30" Display="None" Visible="True" ErrorMessage="Please enter the inventory value for the eighth year." />
                                                </td>
                                            </tr>
                                        </tbody>
                                        </table>
                                    </div>
                                </label>
                            </div>
                        </div>
                        <div class="row">
                            <div class="column small-1"></div>
                            <div class="column small-9 end text-center">
                                <asp:Button ID="btnAddRequirement" runat="server" Text="Insert" CausesValidation="true" ValidationGroup="InventoryInsert" OnClientClick="return validateFilters();"/><br />
                                <asp:CustomValidator ID="CustomValidator1" runat="server" ValidationGroup="InventoryInsert" Display="None" ErrorMessage="The sum of inventory for all years must be greater than zero" OnServerValidate="ValidateInsertInventory"></asp:CustomValidator>
                                <asp:Label runat="server" ID="lblInsertMsg" ForeColor="Red"></asp:Label>
                            </div>
                        </div>
                    </div>
                    <hr />
                    <div class="row">
                        <div class="columns large-6">
                                <h3>Add, Rename, or Remove Sub-Project Names (PN)</h3>
                                <h6>Note - To rename the parent project use the properties page.</h6>
                                <br />
                                <div>
                                    <h6>Enter Sub-Project Name</h6>
                                    <div class="column row">
                                        <asp:TextBox ID="newCategoryName" runat="server" ValidationGroup="InsCategory" />
                                        <asp:RequiredFieldValidator ID="rfvInsCategory" runat="server" ControlToValidate="newCategoryName" ErrorMessage="Required" ValidationGroup="InsCategory"></asp:RequiredFieldValidator>
                                    </div>
                                    <div class="column row">
                                        <asp:Button ID="btnAddSubproject" runat="server" Text="Create" ValidationGroup="InsCategory" />
                                    </div>
                                    <div class="column row">
                                        <asp:Panel runat="server" ID="pnlRenameOrDelete">
                                            <h6>Rename or Remove Sub-Project Name</h6>
                                            <div class="column row">
                                                <asp:DropDownList ID="ddlDelCategoryList" runat="server" DataSourceID="ListOfCategoriesToDelete" DataTextField="CategoryName" DataValueField="CategoryId" AutoPostBack="true">
                                                </asp:DropDownList>
                                                <asp:ObjectDataSource ID="ListOfCategoriesToDelete" runat="server" SelectMethod="GetCategories" TypeName="AMCOS.Logic.ProjectRequirement">
                                                    <SelectParameters>
                                                        <asp:Parameter Name="ProjectId" Type="Int32" />
                                                    </SelectParameters>
                                                </asp:ObjectDataSource>
                                                <asp:Panel runat="server" ID="pnlRename" Visible="false">
                                                    New Name: &nbsp;
                                                    <asp:TextBox ID="txtNewName" runat="server" Width="160px" ValidationGroup="txtNewName" />
                                                    <asp:RequiredFieldValidator ID="rfValidator3" runat="server" ControlToValidate="txtNewName" ErrorMessage="Required" ValidationGroup="txtNewName"></asp:RequiredFieldValidator>
                                                    <asp:Button ID="btnSave" runat="server" Text=" Save " ValidationGroup="txtNewName" />&nbsp;&nbsp;&nbsp;
                                                    <asp:Button ID="btnCancel" runat="server" Text=" Cancel " CausesValidation="false" />
                                                </asp:Panel>
                                            </div>
                                            <div class="column row">
                                                <asp:Button ID="btnRename" runat="server" Text=" Rename " />&nbsp;&nbsp;&nbsp;
                                                <asp:Button ID="btnDelCategoryList" runat="server" Text="Remove" OnClientClick="return confirm('Are you sure to remove this project?');" />
                                            </div>
                                        </asp:Panel>
                                    </div>
                                </div>
                            </div>
                        <div class="columns large-6">
                                <h3>Copy between a Project and Sub-Project</h3>
                                At times it may be useful to copy an entire Project's manpower requirements between a Project and Sub-Project.
                                <ul style="margin-top: 5px">
                                    <li>Before the Copy tool can be used a Sub-Project must already exist or be added</li>
                                    <li>Select the Project or Sub-Project tab to be populated</li>
                                    <li>Select a Project or Sub-Project from the drop down (only one can be selected at a time) and click the Copy button</li>
                                    <li>Repeat to copy other Project or Sub-Project</li>
                                </ul>
                                <asp:Panel runat="server" ID="pnlCopyCat">
                                    <div class="row">
                                                
                                            <div class="columns">Copy Positions From Project:</div>
                                            <div class="columns">
                                                <asp:DropDownList ID="PMCategoryList" runat="server" AutoPostBack="false" DataValueField="Value" DataTextField="Text"/>
                                            </div>
                                    </div>
                                    <div class="row">
                                            <div class="columns">
                                                <asp:Button ID="btnCopyCat" runat="server" Text="Copy" /><br />
                                                <asp:Label runat="server" ID="lbCopyCatMsg" ForeColor="Red"></asp:Label>
                                            </div>
                                    </div>
                                </asp:Panel>
                            </div>
                    </div>
                </asp:WizardStep>
                <asp:WizardStep ID="wizardStep4" runat="server" Title="Output">
                    <h3>Output builds a personnel summary report based on requirements set by user.</h3>
                    <p>
                        Select one or more costing fields to include in your report.
                    </p>
                    <asp:GridView ID="gvOutput" runat="server" AutoGenerateColumns="False" DataSourceID="ProjectOutputs" CellPadding="3" CellSpacing="3" EmptyDataText="(No Summary data found)">
                        <Columns>
                            <asp:TemplateField HeaderText="CategoryId">
                                <ItemTemplate>
                                    <asp:HiddenField ID="Label1" runat="server" Value='<%# Bind("CategoryId") %>' />
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:BoundField DataField="PayPlan" HeaderText="PayPlan" />
                            <asp:BoundField DataField="Category" HeaderText="Sub-Project Name" />
                            <asp:TemplateField HeaderText="Include In Report">
                                <ItemTemplate>
                                    <asp:CheckBox ID="chkOuputInReport" ToolTip="In Report" runat="server" AutoPostBack="true" />
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" Width="75px" />
                            </asp:TemplateField>
                        </Columns>
                        <HeaderStyle BackColor="#0f6938" ForeColor="White" />
                    </asp:GridView>
                    <asp:ObjectDataSource ID="ProjectOutputs" runat="server" SelectMethod="GetProjectOutputs" TypeName="AMCOS.Logic.Project">
                        <SelectParameters>
                            <asp:Parameter Name="ProjectId" Type="Int32" />
                        </SelectParameters>
                    </asp:ObjectDataSource>
                    <asp:CustomValidator ID="cvOutputReport" runat="server" EnableClientScript="False" ErrorMessage="Please select a Pay Plan / Sub-Project Name combination" ValidationGroup="OutputPage"></asp:CustomValidator>
                    <br />
                    <asp:LinkButton runat="server" ID="lnkCheckAllPayPlan" Text="Check all Pay Plans" Font-Underline="true"></asp:LinkButton>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 
                    <asp:LinkButton runat="server" ID="lnkRemoveAllPayPlan" Text="Remove all checks" Font-Underline="true"></asp:LinkButton>
                    <br />
                    <br />
                    <br />
                    <div style="display: none">
                        <asp:CheckBoxList ID="cblSumOutputFields" runat="server" RepeatDirection="Horizontal">
                            <asp:ListItem Value="PMCategoryName">Sub-Project Name</asp:ListItem>
                            <asp:ListItem Value="PayPlan">PayPlan</asp:ListItem>
                            <asp:ListItem Value="CategoryGroupDescription">Group</asp:ListItem>
                            <asp:ListItem Value="CategorySubgroupDescription">Subgroup</asp:ListItem>
                            <asp:ListItem Value="Grade">Grade</asp:ListItem>
                            <asp:ListItem Value="ExceedsSalaryLimit">ExceedsSalaryLimit</asp:ListItem>
                            <asp:ListItem Value="APPN">APPN</asp:ListItem>
                            <asp:ListItem Value="CostElementCategory">Category</asp:ListItem>
                            <asp:ListItem Value="CostElementName">Cost Element</asp:ListItem>
                        </asp:CheckBoxList>
                        <br />
                        <asp:CustomValidator ID="cvOutFields" runat="server" EnableClientScript="False" ErrorMessage="Please select the desired display field(s)<br /><br />"  ValidationGroup="OutputPage"></asp:CustomValidator> 
                        <asp:LinkButton runat="server" ID="lnkCheckAllFileds" Text="Check all fields" Font-Underline="true"></asp:LinkButton>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                        <asp:LinkButton runat="server" ID="lnkRemoveAllFileds" Text="Remove all checks" Font-Underline="true"></asp:LinkButton>
                        <br />
                        <br />
                    </div>
                    <asp:Button ID="buildReport" runat="server" Text="Build Report" Width="200px" ValidationGroup="OutputPage" />
                </asp:WizardStep>
            </WizardSteps>
            <HeaderStyle Width="100px" />
        </asp:Wizard>
    </div>
</asp:Content>
<asp:Content ID="JSContent" ContentPlaceHolderID="JSPlaceHolder" runat="server">
    <script type="text/javascript" src="../../dist/js/selectize.min.js"></script>
    <script type="text/javascript" src="../../dist/js/object-payplan.min.js"></script>
    <script type="text/javascript">
        var exports = {};
    </script>    
    <script type="text/javascript" src="../../dist/js/amcos-common.js"></script>
    <script type="text/javascript" src="../../dist/js/project-manager.js"></script>
    <script>
        (function () {
            loadProjectManagerPage();
        })();
    </script>
</asp:Content>
