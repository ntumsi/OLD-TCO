var personnelArea = {
    payPlan: "-1",
    categoryGroupCode: "-1",
    categorySubgroupCode: "-1",
    careerProgramNumber: "-1",
    locationId: -1,
    locationText: "-1",
    scienceTechnologyReinventionLaboratory: "-1",
    dependentStatus: "-1",
    numberOfDependents: -1,
    activeDutyDays: 15,
    overheadPercent: 0,
    gradeLevel: -1,
    inventory: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    reset: function () {
        this.payPlan = "-1";
        this.categoryGroupCode = "-1";
        this.categorySubgroupCode = "-1";
        this.careerProgramNumber = "-1";
        this.locationId = -1;
        this.locationText = "-1";
        this.scienceTechnologyReinventionLaboratory = "-1";
        this.dependentStatus = "-1";
        this.numberOfDependents = -1;
        this.activeDutyDays = 15;
        this.overheadPercent = 0;
        this.gradeLevel = -1;
        this.inventory = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
    },
    setHiddenFields: function () {
        document.getElementById("selectedPayPlan").value = this.payPlan;
        document.getElementById("selectedCategoryGroupCode").value = this.categoryGroupCode;
        document.getElementById("selectedCategorySubgroupCode").value = this.categorySubgroupCode;
        document.getElementById("selectedCareerProgramNumber").value = this.careerProgramNumber;
        document.getElementById("selectedLocationId").value = this.locationId;
        document.getElementById("selectedLocationText").value = this.locationText;
        document.getElementById("selectedScienceTechnologyReinventionLaboratory").value = this.scienceTechnologyReinventionLaboratory;
        document.getElementById("selectedDependentStatus").value = this.dependentStatus;
        document.getElementById("selectedNumberOfDependents").value = this.numberOfDependents;
        document.getElementById("selectedGradeLevel").value = this.gradeLevel;
        document.getElementById("inputActiveDutyDays").value = this.activeDutyDays;
        document.getElementById("inputOverheadPercent").value = this.overheadPercent;
        document.getElementById("inputProjectInventory").value = this.inventory;
        console.log(this);
    }
};
var unitData = {
    uic: "-1",
    authorizationDocument: "",
    containsContractorCostEstimate: false,
    excludedPayPlans: "",
    unitDataAction: "Replace",
    newSubprojectName: "-1",
    unitLocation: "Unchanged",
    mtoeProjectInventoryYear: "",
    projectExtendsSacsYears: "",
    unitContractorOverheadPercent: 150,
    uicUnitYears: 0,
    reset: function () {
        this.uic = "";
        this.authorizationDocument = "";
        this.containsContractorCostEstimate = false;
        this.excludedPayPlans = "";
        this.unitDataAction = "Replace";
        this.newSubprojectName = "";
        this.unitLocation = "Unchanged";
        this.mtoeProjectInventoryYear = null;
        this.projectExtendsSacsYears = null;
        this.unitContractorOverheadPercent = 150;
        this.uicUnitYears = 0;
    },
    setHiddenFields: function () {
        document.getElementById("selectedUnit").value = this.uic;
        document.getElementById("excludedPayPlans").value = this.excludedPayPlans;
        document.getElementById("selectedOperation").value = this.unitDataAction;
        document.getElementById("inputNewSubprojectName").value = this.newSubprojectName;
        document.getElementById("unitLocation").value = this.unitLocation;
        if (document.querySelector('input[name="projectInventoryYear"]:checked').value === 'Sync') {
            this.mtoeProjectInventoryYear = null;
            document.getElementById("selectedMtoeProjectInventoryYear").value = this.mtoeProjectInventoryYear;
        } else {
            document.getElementById("selectedMtoeProjectInventoryYear").value = this.mtoeProjectInventoryYear;
        }
        document.getElementById("selectedProjectExtendsSacsYears").value = this.projectExtendsSacsYears;
        document.getElementById("inputUnitContractorOverheadPercent").value = this.unitContractorOverheadPercent;
        console.log(this);
    },
    setAccordionTitles: function () {
        const projectActionTitle = document.getElementsByClassName("project-action");
        projectActionTitle[0].innerHTML = "Project Action  Selection: <b>" + document.querySelector('input[name="operation"]:checked').value + "</b>";

        const unitLocationTitle = document.getElementsByClassName("unit-location");
        unitLocationTitle[0].innerHTML = "Unit Location  Selection: <b>" + document.querySelector('input[name="unitLocation"]:checked').value + "</b>";

        const fiscalYearsTitle = document.getElementsByClassName("fiscal-years");
        if (unitData.authorizationDocument === 'MTOE') {
            if (unitData.projectExtendsSacsYears = true) {
                if (document.querySelector('input[name="projectInventoryYear"]:checked').value == 'Sync') {
                    fiscalYearsTitle[0].innerHTML = "Fiscal Years Selection: <b>" + document.querySelector('input[name="projectInventoryYear"]:checked').value + "; " + document.querySelector('input[name="projectExtendsSacsYears"]:checked').value + " for project years that extend SACS years</b>";
                } else {
                    fiscalYearsTitle[0].innerHTML = "Fiscal Years Selection: <b>" + document.querySelector('input[name="projectInventoryYear"]:checked').value + "</b>";
                }                
            }
        } else {
            fiscalYearsTitle[0].innerHTML = "Fiscal Years Selection: <b>Not Applicable</b>";
        }

        const contractorCostEstimateOverheadTitle = document.getElementsByClassName("contractor-cost-estimate-overhead");
        if (unitData.containsContractorCostEstimate) {
            if (!document.getElementById('contractorCostEstimateOverheadAccordionInput').classList.contains('hide')) {
                contractorCostEstimateOverheadTitle[0].innerHTML = "Overhead Percentage: <b>" + document.getElementById('unitContractorOverheadPercent').value + "</b>";
            }            
        } else {
            contractorCostEstimateOverheadTitle[0].innerHTML = "Overhead Percentage: <b>Not Applicable</b>";
        }
        
    }
};
let availablePayPlans = [];

function handler() {
    if (this.status === 200) {
        processUnitData(JSON.parse(this.responseText));
    } else {
        console.log('Error:  ' + this.status);
    }
}
function adjustUnitInventoryOption(authorizationDocument) {
    if (authorizationDocument === 'MTOE') {
        document.getElementById('projectInventoryYearOptionsText').innerHTML = "You've selected an MTOE unit.  AMCOS can automatically set your project to follow changes in the SACS file year over year, or stay static.";
        showProjectInventoryYear();
        displayExtendsYears();
        loadMtoeUnitYearList(unitData.uic);
        unitData.mtoeProjectInventoryYear = "";
        unitData.projectExtendsSacsYears = "LastMtoe";
    } else {
        document.getElementById('projectInventoryYearOptionsText').innerHTML = "You've selected a TDA or Aug TDA unit so AMCOS will use the latest FMSWeb lockpoint data for all years of your project.";
        hideProjectInventoryYear();
        hideMtoeSyncOptionFilter();
        unitData.mtoeProjectInventoryYear = "";
        unitData.projectExtendsSacsYears = "";
    }
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
}
function adjustUnitOverheadOption(containsCCE) {
    if (containsCCE) {
        document.getElementById('contractorCostEstimateOverheadAccordionText').innerHTML = "The CCE Overhead Percentage figure represents benefit costs a contractor would incur above wages, and thus they would include in their price back to the Government.  That figure may vary widely based on the nature of the work and the benefits being paid, as well as where the work occurs (Government site or Contractor site).  AMCOS recommends users research the typical contractor markup in their line of business.  Our default value of 150% (equivalent to a wrap rate of 1.5) represents the lower end of the possible scenarios.";
        showContractorCostEstimateOverheadAccordionInput();
    } else {
        document.getElementById('contractorCostEstimateOverheadAccordionText').innerHTML = "You've selected a unit that does not contain requirements for the Contractor Cost Estimate pay plan.";
        hideContractorCostEstimateOverheadAccordionInput();
    }
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
}
function changeActiveDutyDays() {
    personnelArea.activeDutyDays = document.getElementById("activeDutyDays").value;
    personnelArea.setHiddenFields();
}
function changeCategory(payPlan, categoryCode) {
    let theCategory = amcos.parseCategory(payPlan, categoryCode);
    personnelArea.categoryGroupCode = theCategory.categoryGroupCode;
    personnelArea.categorySubgroupCode = theCategory.categorySubgroupCode;
    personnelArea.careerProgramNumber = theCategory.armyCareerProgramNumber;
    personnelArea.locationId = -1;
    personnelArea.locationText = "-1";
    personnelArea.setHiddenFields();

    if (activeDutyArmyPayPlans.indexOf(payPlan) !== -1) {
        if (personnelArea.categoryGroupCode === '-1' || personnelArea.categorySubgroupCode === '-1') {
            hideLocationFilter(personnelArea);
            hideDependentStatusFilter(personnelArea);
            hideNumberOfDependentsFilter(personnelArea);
            loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
            displayInventoryEntry();
        }
        else {
            showLocationFilter();
            initializeLocationListMilitary(document.getElementById("locationList"), personnelArea);
            loadLocationList(payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber);
            $(document.getElementById('locationList')).selectize()[0].selectize.enable();
        }
    } else if (payPlansThatDoNotUseLocation.indexOf(payPlan) !== -1) {
        hideLocationFilter(personnelArea);
        hideDependentStatusFilter(personnelArea);
        hideNumberOfDependentsFilter(personnelArea);
        showActiveDutyDaysFilter();
        loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
        displayInventoryEntry();
    } else {
        showLocationFilter();
        loadLocationList(payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber);
        $(document.getElementById('locationList')).selectize()[0].selectize.enable();
    }
}
function changeDependentStatus() {
    personnelArea.setHiddenFields();
    loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
    displayInventoryEntry();
}
function changeGradeLevel() {
    personnelArea.setHiddenFields();
}
function changeInventory() {
    for (let i = 1; i <= 30; i++) {
        let inventoryElement = "InsertYear" + i;
        personnelArea.inventory[i - 1] = parseInt(document.getElementById(inventoryElement).value);
    }
    personnelArea.setHiddenFields();
}
function changeLocation(locationType) {
    personnelArea.setHiddenFields();
    if (activeDutyArmyPayPlans.indexOf(personnelArea.payPlan) !== -1) {
        if (personnelArea.locationId === -1 || locationType === 'mha-oconus') {
            hideDependentStatusFilter(personnelArea);
            loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
            displayInventoryEntry();
        } else {
            showDependentStatusFilter();
            initializeDependentStatusList(document.getElementById("dependentStatusList"), personnelArea);
            hideNumberOfDependentsFilter(personnelArea);
        }
    } else if (laboratoryDemoPayPlans.indexOf(personnelArea.payPlan) !== -1) {
        loadScienceTechnologyReinventionLaboratoryList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
    } else if (payPlansThatContainCivilianOverseasLocations.indexOf(personnelArea.payPlan) !== -1) {
        if (personnelArea.locationId !== -1 && locationType === 'civilianOverseasArea') {
            hideDependentStatusFilter(personnelArea);
            showNumberOfDependentsFilter();
            initializeNumberOfDependentsList(document.getElementById("numberOfDependentsList"), personnelArea);
        } else {
            hideDependentStatusFilter(personnelArea);
            hideNumberOfDependentsFilter(personnelArea);
            loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
            displayInventoryEntry();
        }
    }
    else {
        hideDependentStatusFilter(personnelArea);
        hideNumberOfDependentsFilter(personnelArea);
        loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
        displayInventoryEntry();
    }
}
function changeNewSubprojectName() {
    unitData.newSubprojectName = document.getElementById("newSubprojectName").value;
    unitData.setHiddenFields();
}
function changeNumberOfDependents() {
    loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
    displayInventoryEntry();
    personnelArea.setHiddenFields();
}
function changeOperation() {
    unitData.unitDataAction = document.querySelector('input[name="operation"]:checked').value;
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
}
function changeOverheadPercent() {
    personnelArea.overheadPercent = document.getElementById("overheadPercent").value;
    personnelArea.setHiddenFields();
}
function changePayPlan(payPlan) {
    personnelArea.reset();
    personnelArea.payPlan = payPlan;
    setVisibleElements(payPlan);
}
function changeProjectExtendsSacsYears() {
    unitData.projectExtendsSacsYears = document.querySelector('input[name="projectExtendsSacsYears"]:checked').value;
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
}
function changeProjectInventoryYear() {
    //reset the unit year list when changing from freeze to Sync
    unitData.mtoeProjectInventoryYear = document.querySelector('input[name="projectInventoryYear"]:checked').value;
    if (unitData.mtoeProjectInventoryYear === 'Freeze') {
        $(document.getElementById('mtoeUnitYearList')).selectize()[0].selectize.enable();
    } else {
        $(document.getElementById('mtoeUnitYearList')).selectize()[0].selectize.disable();
    }
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
    displayExtendsYears();
}
function changeSelectedPayPlans() {
    let selectedPayPlans = [];
    let payPlans = document.querySelectorAll('input[name="payPlansToAdd"]:checked');
    for (let i = 0; i < payPlans.length; i++) {
        selectedPayPlans.push(payPlans[i].value);
    }
    let unselectedPayPlans = availablePayPlans.filter(function (x) { return !selectedPayPlans.join().includes(x); });

    unitData.excludedPayPlans = unselectedPayPlans;
    unitData.setHiddenFields();

    const title = document.getElementsByClassName("unit-summary");
    title[0].innerHTML = "Unit Summary(Pay Plan / Location) Selection(s): <b>" + selectedPayPlans.join() + "</b>";
}
function changeStrl() {
    personnelArea.setHiddenFields();
    loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
    displayInventoryEntry();
}
function changeUnit(uic) {
    if (uic !== "") {
        unitData.uic = uic;
        unitData.setHiddenFields();
        unitData.setAccordionTitles();
        const projectStartYear = document.getElementById("projectStartYear").value;
        fetchUnitDetails(uic, projectStartYear);
    }
}
function changeUnitLocation() {
    $(document.getElementById('unitLocationList'))[0].selectize.clear();
    unitData.unitLocation = document.querySelector('input[name="unitLocation"]:checked').value;
    if (unitData.unitLocation === 'Change') {
        $(document.getElementById('unitLocationList')).selectize()[0].selectize.enable();
    } else {
        $(document.getElementById('unitLocationList')).selectize()[0].selectize.disable();
    }
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
    //if (unitData.unitLocation === 'Change') {

    //}
}
function changeUnitOverheadPercent() {
    unitData.unitContractorOverheadPercent = document.getElementById("unitContractorOverheadPercent").value;
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
}
function displayExtendsYears() {
    //console.log('Project duration: ' + document.getElementById('projectDuration').value);
    //console.log('Unit years: ' + unitData.uicUnitYears);
    const duration = document.getElementById('projectDuration').value;
    if (document.querySelector('input[name="projectInventoryYear"]:checked').value === 'Sync' && duration > unitData.uicUnitYears) {
        showMtoeSyncOptionFilter();
    } else {
        hideMtoeSyncOptionFilter();
    }
}
function displayInventoryEntry() {
    document.getElementById('inventoryFilter').classList.remove('hide');
    let duration = document.getElementById('projectDuration').value;
    let show = '-n+' + parseInt(duration);
    let hide = 'n+' + (parseInt(duration) + 1);
    $('#tblInventory tr > *:nth-child(' + show + ')').removeClass('hide');
    $('#tblInventory tr > *:nth-child(' + hide + ')').addClass('hide');
    $('#tblInventory input').val('1');
}
function drawInventoryInput(projectStartYear, projectDuration) {

    let projectYearTextCell = document.getElementById('projectYearText');
    let projectYearInventoryCell = document.getElementById('projectYearInventory');
    for (let yearCounter = 0; yearCounter < projectDuration; yearCounter++) {
        let headerDiv = document.createElement("div");
        headerDiv.id = 'year' + yearCounter;
        headerDiv.className = 'column';
        headerDiv.innerHTML = projectStartYear + yearCounter;
        projectYearTextCell.appendChild(headerDiv);

        let inventoryDiv = document.createElement("div");
        inventoryDiv.id = 'inventory' + yearCounter;
        inventoryDiv.className = 'column';
        projectYearInventoryCell.appendChild(inventoryDiv);

        let inventoryInput = document.createElement("input");
        inventoryInput.id = 'inventoryInput' + yearCounter;
        inventoryInput.setAttribute('type', "number");
        inventoryInput.setAttribute('value', 1);
        inventoryInput.required = true;
        document.getElementById('inventory' + yearCounter).appendChild(inventoryInput);
    }
}
function fetchUnitDetails(uic, projectStartYear) {
    let xhr = new XMLHttpRequest();
    xhr.onload = handler;
    xhr.open('GET', _baseApiUrl + '/units/' + encodeURIComponent(uic) + '/' + encodeURIComponent(projectStartYear) + '/personnel');
    xhr.send();
}
function GetExcludedPayPlans() {
    let array = [];
    let checkboxes = document.querySelectorAll('input[type=checkbox]:checked');

    for (let i = 0; i < checkboxes.length; i++) {
        array.push(checkboxes[i].value);
    }
}
function loadProjectManagerPage() {
    initializePayPlanList(document.getElementById("payPlanList"));
    initializeUnitList(document.getElementById("unitList"), unitData);

    if (document.getElementById("unitLocationList")) {
        initializeUnitLocationList(document.getElementById("unitLocationList"), unitData);
        loadUnitLocationList();
    }
    if (document.getElementById("mtoeUnitYearList")) {
        initializeMtoeUnitYearList(document.getElementById("mtoeUnitYearList"), unitData);
    }
    const operationOptions = document.querySelectorAll('input[name="operation"]');
    for (let i = 0; i < operationOptions.length; i++) {
        operationOptions[i].addEventListener('click', changeOperation);
    }
    const optionProjectInventoryYear = document.querySelectorAll('input[name="projectInventoryYear"]');
    for (let i = 0; i < optionProjectInventoryYear.length; i++) {
        optionProjectInventoryYear[i].addEventListener('click', changeProjectInventoryYear);
    }
    const optionProjectExtendsSacsYears = document.querySelectorAll('input[name="projectExtendsSacsYears"]');
    for (let i = 0; i < optionProjectExtendsSacsYears.length; i++) {
        optionProjectExtendsSacsYears[i].addEventListener('click', changeProjectExtendsSacsYears);
    }
    const unitLocationOptions = document.querySelectorAll('input[name="unitLocation"]');
    for (let i = 0; i < unitLocationOptions.length; i++) {
        unitLocationOptions[i].addEventListener('click', changeUnitLocation);
    }
    if (document.getElementById("newSubprojectName")) {
        document.getElementById("newSubprojectName").addEventListener('input', changeNewSubprojectName);
    }
}
function logAddUnit(pageElement) {

    var UnitDataObject = {
        userId: document.getElementById("hidUserId").value,
        pageElement: pageElement,
        uic: unitData.uic,
        excludedPayPlans: unitData.excludedPayPlans,
        unitDataAction: unitData.unitDataAction,
        newSubprojectName: unitData.newSubprojectName,
        unitLocation: unitData.unitLocation,
        mtoeProjectInventoryYear: unitData.mtoeProjectInventoryYear,
        projectExtendsSacsYears: unitData.projectExtendsSacsYears,
        unitContractorOverheadPercent: unitData.unitContractorOverheadPercent
    };

    $.ajax({
        type: "POST",
        url: "ProjectService.asmx/LogAddUnit",
        data: JSON.stringify(AmcosLiteObject),
        contentType: "application/json; charset=utf-8",
        dataType: "json",
        error: function (e) {
            alert("An error occured: " + e.status + " " + e.statusText);
        }
    });
}
function processUnitData(data) {
    //console.log(data);
    const selectedUnitInformation = data;
    const table = document.getElementById("payPlansInUnit");
    while (table.firstChild) {
        table.removeChild(table.firstChild);
    }
    const authorizationDocument = selectedUnitInformation[0].AuthorizationDocument;
    unitData.authorizationDocument = authorizationDocument;
    const inventoryFiscalYear = selectedUnitInformation[0].UnitYear;
    unitData.uicUnitYears = selectedUnitInformation[0].NumUnitYears;
    const header = table.createTHead();
    const row = header.insertRow(0);
    const cell1 = row.insertCell(0);
    cell1.innerHTML = "Select";
    const cell2 = row.insertCell(1);
    cell2.innerHTML = "Pay Plan";
    const cell3 = row.insertCell(2);
    if (authorizationDocument === 'MTOE') {
        cell3.innerHTML = "# Personnel (FY " + inventoryFiscalYear + ")";
    } else {
        cell3.innerHTML = "# Personnel";
    }
    const cell4 = row.insertCell(3);
    cell4.innerHTML = "AMCOS Pay Plan Location";

    availablePayPlans = selectedUnitInformation.map(function (a) { return a.PayPlan; });
    unitData.containsContractorCostEstimate = availablePayPlans.includes('CCE');

    for (let key in selectedUnitInformation) {
        let tableRow = table.insertRow();
        let cell1 = tableRow.insertCell();
        let cell2 = tableRow.insertCell();
        let cell3 = tableRow.insertCell();
        let cell4 = tableRow.insertCell();
        const newInput = document.createElement("input");
        newInput.setAttribute("type", "checkbox");
        newInput.setAttribute("name", "payPlansToAdd");
        newInput.setAttribute("value", selectedUnitInformation[key].PayPlan);
        newInput.setAttribute("checked", true);
        newInput.addEventListener("input", changeSelectedPayPlans);

        cell1.appendChild(newInput);
        cell2.appendChild(document.createTextNode(selectedUnitInformation[key].PayPlan));
        cell3.appendChild(document.createTextNode(selectedUnitInformation[key].Inventory));
        cell4.appendChild(document.createTextNode(selectedUnitInformation[key].Location));
    }

    document.getElementById('payPlansInUnit').classList.remove('hide');
    document.getElementById('unitLocationFilter').classList.remove('hide');    
    adjustUnitInventoryOption(authorizationDocument);
    adjustUnitOverheadOption(unitData.containsContractorCostEstimate);
}
function setVisibleElements(payPlan) {
    let doc = document;

    if (activeDutyArmyPayPlans.indexOf(payPlan) !== -1 || armyNationalGuardPayPlans.indexOf(payPlan) !== -1 || armyReservePayPlans.indexOf(payPlan) !== -1) {
        hideLocationFilter(personnelArea);
        hideScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
    } else if (laboratoryDemoPayPlans.indexOf(payPlan) !== -1) {
        showLocationFilter();
        showScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
        initializeLocationListGS(doc.getElementById("locationList"), personnelArea);
        initializeScienceTechnologyReinventionLaboratoryList(doc.getElementById("scienceTechnologyReinventionLaboratoryList"), personnelArea);
    } else if (acquisitionDemoPayPlans.indexOf(payPlan) !== -1) {
        showLocationFilter();
        hideScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
        initializeLocationListGS(doc.getElementById("locationList"), personnelArea);
    } else if (payPlan === 'CCE') {
        showLocationFilter();
        hideScienceTechnologyReinventionLaboratoryFilter();
        showOverheadPercentFilter();
        if (doc.getElementById("overheadPercent")) {
            doc.getElementById("overheadPercent").value = '0';
        }
        initializeLocationListCCE(doc.getElementById("locationList"), personnelArea);
        doc.getElementById("overheadPercent").addEventListener("input", changeOverheadPercent);
    }
    else if (civilianPayPlans.indexOf(payPlan) !== -1) {
        hideLocationFilter(personnelArea);
        hideScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
        initializeLocationListGS(doc.getElementById("locationList"), personnelArea);
    } else if (wageAppropriatedFundPayPlans.indexOf(payPlan) !== -1 || wageNonAppropriatedFundPayPlans.indexOf(payPlan) !== -1) {
        hideLocationFilter(personnelArea);
        hideScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
        if (payPlan === 'CY') {
            initializeLocationListGS(doc.getElementById("locationList"), personnelArea);
        } else {
            initializeLocationListFWS(doc.getElementById("locationList"), personnelArea);
        }
    }

    showCategoryFilter();
    hideDependentStatusFilter(personnelArea);
    hideNumberOfDependentsFilter(personnelArea);
    hideGradeLevelFilter();
    hideActiveDutyDaysFilter();
    hideInventoryFilter();
    initializeCategoryList(doc.getElementById("categoryList"), payPlan);
    initializeGradeLevelList(doc.getElementById("gradeLevelList"), personnelArea);

    for (let i = 1; i <= 30; i++) {
        let inventoryElement = "InsertYear" + i;
        doc.getElementById(inventoryElement).addEventListener("input", changeInventory);
    }
}