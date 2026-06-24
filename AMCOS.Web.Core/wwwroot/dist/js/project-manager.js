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
    inventory: [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    reset: function () {
        this.payPlan = "-1"; this.categoryGroupCode = "-1"; this.categorySubgroupCode = "-1";
        this.careerProgramNumber = "-1"; this.locationId = -1; this.locationText = "-1";
        this.scienceTechnologyReinventionLaboratory = "-1"; this.dependentStatus = "-1";
        this.numberOfDependents = -1; this.activeDutyDays = 15; this.overheadPercent = 0;
        this.gradeLevel = -1;
        this.inventory = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1];
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
        this.uic = ""; this.authorizationDocument = ""; this.containsContractorCostEstimate = false;
        this.excludedPayPlans = ""; this.unitDataAction = "Replace"; this.newSubprojectName = "";
        this.unitLocation = "Unchanged"; this.mtoeProjectInventoryYear = null;
        this.projectExtendsSacsYears = null; this.unitContractorOverheadPercent = 150; this.uicUnitYears = 0;
    },
    setHiddenFields: function () {
        document.getElementById("selectedUnit").value = this.uic;
        document.getElementById("excludedPayPlans").value = this.excludedPayPlans;
        document.getElementById("selectedOperation").value = this.unitDataAction;
        document.getElementById("inputNewSubprojectName").value = this.newSubprojectName;
        document.getElementById("unitLocation").value = this.unitLocation;
        var projInvYearEl = document.querySelector('input[name="projectInventoryYear"]:checked');
        if (projInvYearEl && projInvYearEl.value === 'Sync') {
            this.mtoeProjectInventoryYear = null;
        }
        document.getElementById("selectedMtoeProjectInventoryYear").value = this.mtoeProjectInventoryYear ?? '';
        document.getElementById("selectedProjectExtendsSacsYears").value = this.projectExtendsSacsYears ?? '';
        document.getElementById("inputUnitContractorOverheadPercent").value = this.unitContractorOverheadPercent;
    },
    setAccordionTitles: function () {
        var projectActionTitle = document.getElementsByClassName("project-action");
        if (projectActionTitle[0]) {
            var opEl = document.querySelector('input[name="operation"]:checked');
            projectActionTitle[0].innerHTML = "Project Action Selection: <b>" + (opEl ? opEl.value : '') + "</b>";
        }
        var unitLocationTitle = document.getElementsByClassName("unit-location");
        if (unitLocationTitle[0]) {
            var ulEl = document.querySelector('input[name="unitLocation"]:checked');
            unitLocationTitle[0].innerHTML = "Unit Location Selection: <b>" + (ulEl ? ulEl.value : '') + "</b>";
        }
        var fiscalYearsTitle = document.getElementsByClassName("fiscal-years");
        if (fiscalYearsTitle[0]) {
            if (unitData.authorizationDocument === 'MTOE') {
                var pyEl = document.querySelector('input[name="projectInventoryYear"]:checked');
                var pyVal = pyEl ? pyEl.value : '';
                if (pyVal === 'Sync') {
                    var extEl = document.querySelector('input[name="projectExtendsSacsYears"]:checked');
                    fiscalYearsTitle[0].innerHTML = "Fiscal Years Selection: <b>Sync; " + (extEl ? extEl.value : '') + " for project years that extend SACS years</b>";
                } else {
                    fiscalYearsTitle[0].innerHTML = "Fiscal Years Selection: <b>" + pyVal + "</b>";
                }
            } else {
                fiscalYearsTitle[0].innerHTML = "Fiscal Years Selection: <b>Not Applicable</b>";
            }
        }
        var cceTitle = document.getElementsByClassName("contractor-cost-estimate-overhead");
        if (cceTitle[0]) {
            if (unitData.containsContractorCostEstimate) {
                var pctEl = document.getElementById('unitContractorOverheadPercent');
                cceTitle[0].innerHTML = "Overhead Percentage: <b>" + (pctEl ? pctEl.value : '') + "</b>";
            } else {
                cceTitle[0].innerHTML = "Overhead Percentage: <b>Not Applicable</b>";
            }
        }
    }
};

var availablePayPlans = [];

function _antiforgeryToken() {
    return document.querySelector('input[name="__RequestVerificationToken"]')?.value ?? '';
}

function handler() {
    if (this.status === 200) {
        processUnitData(JSON.parse(this.responseText));
    } else {
        console.log('Error: ' + this.status);
    }
}

function adjustUnitInventoryOption(authorizationDocument) {
    if (authorizationDocument === 'MTOE') {
        document.getElementById('projectInventoryYearOptionsText').innerHTML = "You've selected an MTOE unit. AMCOS can automatically set your project to follow changes in the SACS file year over year, or stay static.";
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
        document.getElementById('contractorCostEstimateOverheadAccordionText').innerHTML = "The CCE Overhead Percentage figure represents benefit costs a contractor would incur above wages. AMCOS recommends users research the typical contractor markup in their line of business. Our default value of 150% represents the lower end of the possible scenarios.";
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
    var theCategory = amcos.parseCategory(payPlan, categoryCode);
    personnelArea.categoryGroupCode = theCategory.categoryGroupCode;
    personnelArea.categorySubgroupCode = theCategory.categorySubgroupCode;
    personnelArea.careerProgramNumber = theCategory.armyCareerProgramNumber;
    personnelArea.locationId = -1;
    personnelArea.locationText = "-1";
    personnelArea.setHiddenFields();

    if (activeDutyArmyPayPlans.indexOf(payPlan) !== -1) {
        if (personnelArea.categoryGroupCode === '-1' || personnelArea.categorySubgroupCode === '-1') {
            hideLocationFilter(personnelArea); hideDependentStatusFilter(personnelArea); hideNumberOfDependentsFilter(personnelArea);
            loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
            displayInventoryEntry();
        } else {
            showLocationFilter();
            initializeLocationListMilitary(document.getElementById("locationList"), personnelArea);
            loadLocationList(payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber);
            $(document.getElementById('locationList')).selectize()[0].selectize.enable();
        }
    } else if (payPlansThatDoNotUseLocation.indexOf(payPlan) !== -1) {
        hideLocationFilter(personnelArea); hideDependentStatusFilter(personnelArea); hideNumberOfDependentsFilter(personnelArea);
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
function changeGradeLevel() { personnelArea.setHiddenFields(); }
function changeInventory() {
    for (var i = 1; i <= 30; i++) {
        var el = document.getElementById("InsertYear" + i);
        personnelArea.inventory[i - 1] = el ? parseInt(el.value) : 1;
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
            hideDependentStatusFilter(personnelArea); hideNumberOfDependentsFilter(personnelArea);
            loadGradeLevelList(personnelArea.payPlan, personnelArea.categoryGroupCode, personnelArea.categorySubgroupCode, personnelArea.careerProgramNumber, personnelArea.locationId);
            displayInventoryEntry();
        }
    } else {
        hideDependentStatusFilter(personnelArea); hideNumberOfDependentsFilter(personnelArea);
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
    unitData.mtoeProjectInventoryYear = document.querySelector('input[name="projectInventoryYear"]:checked').value;
    var sel = $(document.getElementById('mtoeUnitYearList'));
    if (sel.length && sel[0].selectize) {
        if (unitData.mtoeProjectInventoryYear === 'Freeze') {
            sel[0].selectize.enable();
        } else {
            sel[0].selectize.disable();
        }
    }
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
    displayExtendsYears();
}
function changeSelectedPayPlans() {
    var selectedPayPlans = Array.from(document.querySelectorAll('input[name="payPlansToAdd"]:checked')).map(function (cb) { return cb.value; });
    unitData.excludedPayPlans = availablePayPlans.filter(function (x) { return !selectedPayPlans.includes(x); });
    unitData.setHiddenFields();
    var title = document.getElementsByClassName("unit-summary");
    if (title[0]) title[0].innerHTML = "Unit Summary(Pay Plan / Location) Selection(s): <b>" + selectedPayPlans.join() + "</b>";
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
        var projectStartYear = document.getElementById("projectStartYear").value;
        fetchUnitDetails(uic, projectStartYear);
    }
}
function changeUnitLocation() {
    $(document.getElementById('unitLocationList'))[0].selectize.clear();
    unitData.unitLocation = document.querySelector('input[name="unitLocation"]:checked').value;
    var sel = $(document.getElementById('unitLocationList'));
    if (sel.length && sel[0].selectize) {
        if (unitData.unitLocation === 'Change') { sel[0].selectize.enable(); }
        else { sel[0].selectize.disable(); }
    }
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
}
function changeUnitOverheadPercent() {
    unitData.unitContractorOverheadPercent = document.getElementById("unitContractorOverheadPercent").value;
    unitData.setHiddenFields();
    unitData.setAccordionTitles();
}
function displayExtendsYears() {
    var duration = document.getElementById('projectDuration').value;
    var pyEl = document.querySelector('input[name="projectInventoryYear"]:checked');
    if (pyEl && pyEl.value === 'Sync' && duration > unitData.uicUnitYears) {
        showMtoeSyncOptionFilter();
    } else {
        hideMtoeSyncOptionFilter();
    }
}
function displayInventoryEntry() {
    document.getElementById('inventoryFilter').classList.remove('hide');
    var duration = document.getElementById('projectDuration').value;
    var show = '-n+' + parseInt(duration);
    var hide = 'n+' + (parseInt(duration) + 1);
    $('#tblInventory tr > *:nth-child(' + show + ')').removeClass('hide');
    $('#tblInventory tr > *:nth-child(' + hide + ')').addClass('hide');
    $('#tblInventory input').val('1');
}
function drawInventoryInput(projectStartYear, projectDuration) {
    var projectYearTextCell = document.getElementById('projectYearText');
    var projectYearInventoryCell = document.getElementById('projectYearInventory');
    for (var yearCounter = 0; yearCounter < projectDuration; yearCounter++) {
        var headerDiv = document.createElement("div");
        headerDiv.id = 'year' + yearCounter;
        headerDiv.className = 'column';
        headerDiv.textContent = projectStartYear + yearCounter;
        projectYearTextCell.appendChild(headerDiv);

        var inventoryDiv = document.createElement("div");
        inventoryDiv.id = 'inventory' + yearCounter;
        inventoryDiv.className = 'column';
        projectYearInventoryCell.appendChild(inventoryDiv);

        var inventoryInput = document.createElement("input");
        inventoryInput.id = 'inventoryInput' + yearCounter;
        inventoryInput.type = "number";
        inventoryInput.value = 1;
        inventoryInput.required = true;
        document.getElementById('inventory' + yearCounter).appendChild(inventoryInput);
    }
}
function fetchUnitDetails(uic, projectStartYear) {
    var xhr = new XMLHttpRequest();
    xhr.onload = handler;
    xhr.open('GET', '/api/units/' + encodeURIComponent(uic) + '/' + encodeURIComponent(projectStartYear) + '/personnel');
    xhr.send();
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

    document.querySelectorAll('input[name="operation"]').forEach(function (el) { el.addEventListener('click', changeOperation); });
    document.querySelectorAll('input[name="projectInventoryYear"]').forEach(function (el) { el.addEventListener('click', changeProjectInventoryYear); });
    document.querySelectorAll('input[name="projectExtendsSacsYears"]').forEach(function (el) { el.addEventListener('click', changeProjectExtendsSacsYears); });
    document.querySelectorAll('input[name="unitLocation"]').forEach(function (el) { el.addEventListener('click', changeUnitLocation); });

    var newSubprojectNameEl = document.getElementById("newSubprojectName");
    if (newSubprojectNameEl) newSubprojectNameEl.addEventListener('input', changeNewSubprojectName);
}
function logAddUnit(pageElement) {
    var payload = {
        userId: document.getElementById("hidUserId")?.value ?? '',
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
        url: "/api/project/LogAddUnit",
        data: JSON.stringify(payload),
        contentType: "application/json; charset=utf-8",
        headers: { 'RequestVerificationToken': _antiforgeryToken() },
        dataType: "json"
    });
}
function processUnitData(data) {
    var table = document.getElementById("payPlansInUnit");
    while (table.firstChild) table.removeChild(table.firstChild);

    var authorizationDocument = data[0].AuthorizationDocument;
    unitData.authorizationDocument = authorizationDocument;
    var inventoryFiscalYear = data[0].UnitYear;
    unitData.uicUnitYears = data[0].NumUnitYears;

    var header = table.createTHead();
    var row = header.insertRow(0);
    row.insertCell(0).textContent = "Select";
    row.insertCell(1).textContent = "Pay Plan";
    row.insertCell(2).textContent = authorizationDocument === 'MTOE' ? "# Personnel (FY " + inventoryFiscalYear + ")" : "# Personnel";
    row.insertCell(3).textContent = "AMCOS Pay Plan Location";

    availablePayPlans = data.map(function (a) { return a.PayPlan; });
    unitData.containsContractorCostEstimate = availablePayPlans.includes('CCE');

    data.forEach(function (item) {
        var tableRow = table.insertRow();
        var cb = document.createElement("input");
        cb.type = "checkbox";
        cb.name = "payPlansToAdd";
        cb.value = item.PayPlan;
        cb.checked = true;
        cb.addEventListener("input", changeSelectedPayPlans);
        tableRow.insertCell().appendChild(cb);
        tableRow.insertCell().textContent = item.PayPlan;
        tableRow.insertCell().textContent = item.Inventory;
        tableRow.insertCell().textContent = item.Location;
    });

    document.getElementById('payPlansInUnit').classList.remove('hide');
    document.getElementById('unitLocationFilter').classList.remove('hide');
    adjustUnitInventoryOption(authorizationDocument);
    adjustUnitOverheadOption(unitData.containsContractorCostEstimate);
}
function setVisibleElements(payPlan) {
    var doc = document;

    if (activeDutyArmyPayPlans.indexOf(payPlan) !== -1 || armyNationalGuardPayPlans.indexOf(payPlan) !== -1 || armyReservePayPlans.indexOf(payPlan) !== -1) {
        hideLocationFilter(personnelArea); hideScienceTechnologyReinventionLaboratoryFilter(); hideOverheadPercentFilter();
    } else if (laboratoryDemoPayPlans.indexOf(payPlan) !== -1) {
        showLocationFilter(); showScienceTechnologyReinventionLaboratoryFilter(); hideOverheadPercentFilter();
        initializeLocationListGS(doc.getElementById("locationList"), personnelArea);
        initializeScienceTechnologyReinventionLaboratoryList(doc.getElementById("scienceTechnologyReinventionLaboratoryList"), personnelArea);
    } else if (acquisitionDemoPayPlans.indexOf(payPlan) !== -1) {
        showLocationFilter(); hideScienceTechnologyReinventionLaboratoryFilter(); hideOverheadPercentFilter();
        initializeLocationListGS(doc.getElementById("locationList"), personnelArea);
    } else if (payPlan === 'CCE') {
        showLocationFilter(); hideScienceTechnologyReinventionLaboratoryFilter(); showOverheadPercentFilter();
        if (doc.getElementById("overheadPercent")) doc.getElementById("overheadPercent").value = '0';
        initializeLocationListCCE(doc.getElementById("locationList"), personnelArea);
        doc.getElementById("overheadPercent").addEventListener("input", changeOverheadPercent);
    } else if (civilianPayPlans.indexOf(payPlan) !== -1) {
        hideLocationFilter(personnelArea); hideScienceTechnologyReinventionLaboratoryFilter(); hideOverheadPercentFilter();
        initializeLocationListGS(doc.getElementById("locationList"), personnelArea);
    } else if (wageAppropriatedFundPayPlans.indexOf(payPlan) !== -1 || wageNonAppropriatedFundPayPlans.indexOf(payPlan) !== -1) {
        hideLocationFilter(personnelArea); hideScienceTechnologyReinventionLaboratoryFilter(); hideOverheadPercentFilter();
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

    for (var i = 1; i <= 30; i++) {
        var el = doc.getElementById("InsertYear" + i);
        if (el) el.addEventListener("input", changeInventory);
    }
}
