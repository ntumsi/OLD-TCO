const inflationYear = typeof _defaultYear !== 'undefined' ? _defaultYear : new Date().getFullYear().toString();
var costsFilter = {
    payPlan: "-1",
    categoryGroupCode: "-1",
    categorySubgroupCode: "-1",
    careerProgramNumber: "-1",
    locationId: -1,
    locationText: "-1",
    scienceTechnologyReinventionLaboratory: "-1",
    dependentStatus: "-1",
    numberOfDependents: -1,
    overheadPercent: 0,
    inflationConversion: "ThenToThen",
    inflationYear: inflationYear,
    costSummaryName: "Default",
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
        this.overheadPercent = 0;
        this.inflationConversion = "ThenToThen";
        this.inflationYear = inflationYear;
        this.costSummaryName = "Default";
    },
    setHiddenFields: function () {
        document.getElementById("selectedPayPlan").value = this.payPlan;
        document.getElementById("selectedCostSummary").value = this.costSummaryName;
        document.getElementById("selectedCategoryGroupCode").value = this.categoryGroupCode;
        document.getElementById("selectedCategorySubgroupCode").value = this.categorySubgroupCode;
        document.getElementById("selectedCareerProgramNumber").value = this.careerProgramNumber;
        document.getElementById("selectedLocationId").value = this.locationId;
        document.getElementById("selectedLocationText").value = this.locationText;
        document.getElementById("selectedScienceTechnologyReinventionLaboratory").value = this.scienceTechnologyReinventionLaboratory;
        document.getElementById("selectedDependentStatusText").value = this.dependentStatus;
        document.getElementById("selectedNumberOfDependents").value = this.numberOfDependents;
        document.getElementById("inputOverheadPercent").value = this.overheadPercent;
        document.getElementById("selectedInflationConversionType").value = this.inflationConversion;
        document.getElementById("selectedInflationYear").value = this.inflationYear;
    }
};
var blinkFlag;
var blinkHandle;

function _antiforgeryToken() {
    return document.querySelector('input[name="__RequestVerificationToken"]')?.value ?? '';
}

docReady(function () {
    amcosLitePageLoad();
    stopBlink();
});

function alertForAllCostSummary() {
    if (costsFilter.costSummaryName === 'Ancillary') {
        alert("CAUTION NOTE: \nDO NOT SUM the 'Ancillary' Summary cost elements. Depending on the cost category, i.e., training or recruiting, summing the sub-elements could result in counting costs multiple times.");
    }
}

function amcosLitePageLoad() {
    initializePayPlanList(document.getElementById("payPlanList"));
}

function changeCategory(payPlan, categoryCode) {
    logFilter("Category");

    let theCategory = amcos.parseCategory(payPlan, categoryCode);
    costsFilter.categoryGroupCode = theCategory.categoryGroupCode;
    costsFilter.categorySubgroupCode = theCategory.categorySubgroupCode;
    costsFilter.careerProgramNumber = theCategory.armyCareerProgramNumber;
    costsFilter.locationId = -1;
    costsFilter.locationText = "-1";
    costsFilter.setHiddenFields();

    let payPlansThatDoNotUseLocation = ['NE', 'NO', 'NWO', 'RE', 'RO', 'RWO'];

    if (activeDutyArmyPayPlans.indexOf(payPlan) !== -1) {
        if (costsFilter.categoryGroupCode === '-1' || costsFilter.categorySubgroupCode === '-1') {
            hideLocationFilter(costsFilter);
            hideDependentStatusFilter(costsFilter);
            hideNumberOfDependentsFilter(costsFilter);
        } else {
            showLocationFilter();
            initializeLocationListMilitary(document.getElementById("locationList"), costsFilter);
            loadLocationList(payPlan, costsFilter.categoryGroupCode, costsFilter.categorySubgroupCode, costsFilter.careerProgramNumber);
            $(document.getElementById('locationList')).selectize()[0].selectize.enable();
        }
    } else if (payPlansThatDoNotUseLocation.indexOf(payPlan) !== -1) {
        hideLocationFilter(costsFilter);
        hideDependentStatusFilter(costsFilter);
        hideNumberOfDependentsFilter(costsFilter);
    } else {
        showLocationFilter();
        loadLocationList(payPlan, costsFilter.categoryGroupCode, costsFilter.categorySubgroupCode, costsFilter.careerProgramNumber);
        $(document.getElementById('locationList')).selectize()[0].selectize.enable();
    }

    startBlink();
}

function changeCostSummary(costSummaryName) {
    logFilter("CostSummaryList");
    if (costSummaryName === 'Weapon System Manpower') {
        showWeaponSystemWarning();
    } else {
        hideWeaponSystemWarning();
    }
    costsFilter.setHiddenFields();
    startBlink();
}

function changeDependentStatus() {
    logFilter("DependentStatusList");
    costsFilter.setHiddenFields();
    startBlink();
}

function changeNumberOfDependents() {
    logFilter("NumberOfDependentsList");
    costsFilter.setHiddenFields();
    startBlink();
}

function changeInflationConversionType(inflationConversionType) {
    logFilter("InflationConversionTypeList");
    costsFilter.setHiddenFields();
    initializeInflationYearList(document.getElementById("inflationYearList"), inflationConversionType, costsFilter, inflationYear);
    startBlink();
}

function changeInflationYear() {
    logFilter("InflationYearList");
    costsFilter.setHiddenFields();
    startBlink();
}

function changeLocation(locationType) {
    logFilter("LocationList");
    if (activeDutyArmyPayPlans.indexOf(costsFilter.payPlan) !== -1) {
        hideNumberOfDependentsFilter(costsFilter);
        if (costsFilter.locationId === -1 || locationType === 'mha-oconus') {
            hideDependentStatusFilter(costsFilter);
        } else {
            showDependentStatusFilter();
            initializeDependentStatusList(document.getElementById("dependentStatusList"), costsFilter);
            hideNumberOfDependentsFilter(costsFilter);
        }
    } else if (laboratoryDemoPayPlans.indexOf(costsFilter.payPlan) !== -1) {
        loadScienceTechnologyReinventionLaboratoryList(costsFilter.payPlan, costsFilter.categoryGroupCode, costsFilter.categorySubgroupCode, costsFilter.careerProgramNumber, costsFilter.locationId);
    } else if (payPlansThatContainCivilianOverseasLocations.indexOf(costsFilter.payPlan) !== -1) {
        if (costsFilter.locationId !== -1 && locationType === 'civilianOverseasArea') {
            showNumberOfDependentsFilter();
            initializeNumberOfDependentsList(document.getElementById("numberOfDependentsList"), costsFilter);
            hideDependentStatusFilter(costsFilter);
        } else {
            hideDependentStatusFilter(costsFilter);
            hideNumberOfDependentsFilter(costsFilter);
        }
    } else {
        hideDependentStatusFilter(costsFilter);
        hideNumberOfDependentsFilter(costsFilter);
    }
    costsFilter.setHiddenFields();
    startBlink();
}

function changeOverheadPercent() {
    logFilter("Overhead Percent");
    costsFilter.overheadPercent = document.getElementById("overheadPercent").value;
    costsFilter.setHiddenFields();
    startBlink();
}

function changePayPlan(payPlan) {
    logFilter("PayPlanList");
    costsFilter.reset();
    costsFilter.payPlan = payPlan;
    setVisibleElements(payPlan);
    startBlink();
}

function changeStrl() {
    logFilter("scienceTechnologyReinventionLaboratoryList");
    costsFilter.setHiddenFields();
    startBlink();
}

function drawC3Chart() {
    var chartEl = document.getElementById('amcosLiteChart');
    if (!chartEl) return;
    while (chartEl.firstChild) chartEl.removeChild(chartEl.firstChild);

    if (costsFilter.costSummaryName !== 'Default') {
        chartEl.textContent = 'Graph results are only available for the Default Cost Summary';
        return;
    }
    if (costsFilter.payPlan === 'CCE') {
        chartEl.textContent = 'Graph Results are not available for Contractor Cost Estimate';
        return;
    }
    if (typeof c3 === 'undefined' || typeof c3ChartData === 'undefined') return;

    c3.generate({
        bindto: '#amcosLiteChart',
        size: { height: 500, width: 1170 },
        data: c3ChartData,
        grid: { y: { lines: [{ value: 0 }] } },
        axis: {
            rotated: false,
            x: { type: 'category', categories: 'Grade' },
            y: { tick: { format: d3.format("$,.2f") } },
            y2: { show: true, tick: { format: d3.format(",") } }
        }
    });
}

function logFilter(pageElement) {
    var payload = {
        userId: document.getElementById("hidUserId")?.value ?? '',
        pageElement: pageElement,
        payPlan: costsFilter.payPlan,
        costSummaryName: costsFilter.costSummaryName,
        categoryGroupCode: costsFilter.categoryGroupCode,
        categorySubgroupCode: costsFilter.categorySubgroupCode,
        careerProgramNumber: costsFilter.careerProgramNumber,
        locationId: costsFilter.locationId,
        locationText: costsFilter.locationText,
        scienceTechnologyReinventionLaboratory: costsFilter.scienceTechnologyReinventionLaboratory,
        dependentStatus: costsFilter.dependentStatus,
        numberOfDependents: costsFilter.numberOfDependents,
        overheadPercent: costsFilter.overheadPercent,
        inflationConversionType: costsFilter.inflationConversion,
        inflationYear: costsFilter.inflationYear
    };
    $.ajax({
        type: "POST",
        url: "/api/lite/LogChoices",
        data: JSON.stringify(payload),
        contentType: "application/json; charset=utf-8",
        headers: { 'RequestVerificationToken': _antiforgeryToken() },
        dataType: "json"
    });
}

function processBlink() {
    try {
        if (blinkFlag === true) {
            setButtonColor("#FF3300");
            setTimeout(function () { setButtonColor('#CCCC00'); }, 500);
            blinkHandle = setTimeout(processBlink, 1500);
        } else {
            setButtonColor('#CCCC00');
            clearTimeout(blinkHandle);
        }
    } catch (e) { console.log(e); }
}

function setButtonColor(colorName) {
    var btn = document.getElementById("showCostsButton");
    if (btn) btn.style.backgroundColor = colorName;
}

function setVisibleElements(payPlan) {
    var doc = document;

    if (activeDutyArmyPayPlans.indexOf(payPlan) !== -1 || armyNationalGuardPayPlans.indexOf(payPlan) !== -1 || armyReservePayPlans.indexOf(payPlan) !== -1) {
        hideLocationFilter(costsFilter);
        hideScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
        hideCCENote();
        hideGfebsSelectAllWarning();
    } else if (laboratoryDemoPayPlans.indexOf(payPlan) !== -1) {
        showLocationFilter();
        showScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
        hideCCENote();
        showGfebsSelectAllWarning();
        initializeLocationListGS(doc.getElementById("locationList"), costsFilter);
        initializeScienceTechnologyReinventionLaboratoryList(doc.getElementById("scienceTechnologyReinventionLaboratoryList"), costsFilter);
    } else if (acquisitionDemoPayPlans.indexOf(payPlan) !== -1) {
        showLocationFilter();
        hideScienceTechnologyReinventionLaboratoryFilter();
        showGfebsSelectAllWarning();
        hideNumberOfDependentsFilter(costsFilter);
        hideOverheadPercentFilter();
        hideCCENote();
        initializeLocationListGS(doc.getElementById("locationList"), costsFilter);
    } else if (civilianPayPlans.indexOf(payPlan) !== -1 || payPlan === 'CCE') {
        showLocationFilter();
        hideScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
        hideCCENote();
        if (payPlan === 'CCE') {
            showOverheadPercentFilter();
            hideGfebsSelectAllWarning();
            if (doc.getElementById("overheadPercent")) doc.getElementById("overheadPercent").value = '0';
            initializeLocationListCCE(doc.getElementById("locationList"), costsFilter);
            doc.getElementById("overheadPercent").addEventListener("input", changeOverheadPercent);
        } else if (payPlan === 'GP') {
            showGfebsSelectAllWarning();
            initializeLocationListGS(doc.getElementById("locationList"), costsFilter);
        } else {
            hideGfebsSelectAllWarning();
            initializeLocationListGS(doc.getElementById("locationList"), costsFilter);
        }
    } else if (wageAppropriatedFundPayPlans.indexOf(payPlan) !== -1 || wageNonAppropriatedFundPayPlans.indexOf(payPlan) !== -1) {
        showLocationFilter();
        hideScienceTechnologyReinventionLaboratoryFilter();
        hideOverheadPercentFilter();
        hideCCENote();
        hideGfebsSelectAllWarning();
        if (payPlan === 'CY') {
            initializeLocationListGS(doc.getElementById("locationList"), costsFilter);
        } else {
            initializeLocationListFWS(doc.getElementById("locationList"), costsFilter);
        }
    }

    showCategoryFilter();
    hideDependentStatusFilter(costsFilter);
    hideNumberOfDependentsFilter(costsFilter);

    ['AppropriationGroupGridView', 'CostsGridView', 'InflationRatesGridView', 'exportButton'].forEach(function (id) {
        var el = doc.getElementById(id);
        if (el) el.classList.add('hide');
    });

    var inflationFilter = doc.getElementById("inflationFilter");
    if (inflationFilter) inflationFilter.classList.remove('hide');
    var costSummaryFilter = doc.getElementById("costSummaryFilter");
    if (costSummaryFilter) costSummaryFilter.classList.remove('hide');

    initializeCategoryList(doc.getElementById("categoryList"), payPlan);
    initializeInflationConversionTypeList(doc.getElementById("inflationConversionTypeList"), costsFilter);
    var inflConvSel = doc.getElementById("inflationConversionTypeList");
    if (inflConvSel && $(inflConvSel)[0].selectize) {
        initializeInflationYearList(doc.getElementById("inflationYearList"), $(inflConvSel)[0].selectize.getValue(), costsFilter, inflationYear);
    }
    initializeCostSummaryList(doc.getElementById("costSummaryList"), payPlan, costsFilter);
}

function startBlink() { blinkFlag = true; processBlink(); }
function stopBlink() { blinkFlag = false; processBlink(); }
