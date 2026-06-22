
const activeDutyArmyPayPlans = ['AE', 'AO', 'AWO'];
const armyNationalGuardPayPlans = ['NE', 'NO', 'NWO'];
const armyReservePayPlans = ['RE', 'RO', 'RWO'];
const armyEnlistedPayPlans = ['AE', 'NE', 'RE'];
const armyOfficerPayPlans = ['AO', 'NO', 'RO'];
const armyWarrantOfficerPayPlans = ['AWO', 'NWO', 'RWO'];
const civilianPayPlans = ['AD', 'CA', 'EE', 'EF', 'EX', 'GG', 'GL', 'GP', 'GS', 'IE', 'IG', 'IP', 'SES', 'SL', 'ST', 'ZZ'];
const laboratoryDemoPayPlans = ['DB', 'DE', 'DJ', 'DK'];
const wageNonAppropriatedFundPayPlans = ['CY', 'NA', 'NF', 'NL', 'NS'];
const acquisitionDemoPayPlans = ['NH', 'NJ', 'NK'];
const wageAppropriatedFundPayPlans = ['WA', 'WB', 'WD', 'WG', 'WJ', 'WK', 'WL', 'WN', 'WO', 'WQ', 'WR', 'WS', 'WT', 'WU', 'WY', 'XF', 'XG', 'XH', 'XR', 'XT', 'XU'];
const payPlansThatContainCivilianOverseasLocations = ['GG', 'GS', 'SES', 'WG', 'WL', 'WS'];
const payPlansThatDoNotUseLocation = ['NE', 'NO', 'NWO', 'RE', 'RO', 'RWO'];

export class AMCOSCommon {
    constructor() {
        this.myCategory = {
            categoryGroupCode: '-1',
            categorySubgroupCode: '-1',
            armyCareerProgramNumber: '-1'
        };
    }   
    parseCategory(payPlan, category) {        
        
        if (armyEnlistedPayPlans.indexOf(payPlan) !== -1 || armyOfficerPayPlans.indexOf(payPlan) !== -1) {
            if (category === '-1') {
                this.myCategory.categoryGroupCode = '-1';
                this.myCategory.categorySubgroupCode = '-1';
                this.myCategory.armyCareerProgramNumber = '-1';
            } else if (category.length === 2) {
                this.myCategory.categoryGroupCode = category;
                this.myCategory.categorySubgroupCode = '-1';
                this.myCategory.armyCareerProgramNumber = '-1';
            } else if (category.length > 2) {
                this.myCategory.categoryGroupCode = category.substring(0, 2);
                this.myCategory.categorySubgroupCode = category.substring(0, 3);
                this.myCategory.armyCareerProgramNumber = '-1';
            }
        } else if (armyWarrantOfficerPayPlans.indexOf(payPlan) !== -1) {
            if (category === '-1') {
                this.myCategory.categoryGroupCode = '-1';
                this.myCategory.categorySubgroupCode = '-1';
                this.myCategory.armyCareerProgramNumber = '-1';
            }
            else if (category.length === 2) {
               this.myCategory.categoryGroupCode = category;
                this.myCategory.categorySubgroupCode = '-1';
                this.myCategory.armyCareerProgramNumber = '-1';
            } else if (category.length > 2) {
               this.myCategory.categoryGroupCode = category.substring(0, 2);
                this.myCategory.categorySubgroupCode = category.substring(0, 4);
                this.myCategory.armyCareerProgramNumber = '-1';
            }
        } else if (laboratoryDemoPayPlans.indexOf(payPlan) !== -1 || acquisitionDemoPayPlans.indexOf(payPlan) !== -1 || civilianPayPlans.indexOf(payPlan) !== -1 || wageNonAppropriatedFundPayPlans.indexOf(payPlan) !== -1) {
            if (category === '-1') {
               this.myCategory.categoryGroupCode = '-1';
                this.myCategory.categorySubgroupCode = '-1';
                this.myCategory.armyCareerProgramNumber = '-1';
            }
            else if (category.length === 2) {
                this.myCategory.categoryGroupCode = '-1';
                this.myCategory.categorySubgroupCode = '-1';
                this.myCategory.armyCareerProgramNumber = category;
            }
            else if (category.length === 5) {
                if (category.substring(2, 4) === '00') {
                   this.myCategory.categoryGroupCode = category;
                    this.myCategory.categorySubgroupCode = '-1';
                    this.myCategory.armyCareerProgramNumber = '-1';
                }
                else {
                   this.myCategory.categoryGroupCode = category.substring(0, 2) + '00';
                    this.myCategory.categorySubgroupCode = category.substring(0, 5);
                    this.myCategory.armyCareerProgramNumber = '-1';
                }
            }
            else if (category.length === 4) {
                if (category.substring(2, 4) === '00') {
                   this.myCategory.categoryGroupCode = category;
                    this.myCategory.categorySubgroupCode = '-1';
                    this.myCategory.armyCareerProgramNumber = '-1';
                }
                else {
                   this.myCategory.categoryGroupCode = category.substring(0, 2) + '00';
                    this.myCategory.categorySubgroupCode = category.substring(0, 4);
                    this.myCategory.armyCareerProgramNumber = '-1';
                }
            }
        } else if (payPlan === 'CCE') {
            if (category.length === 7) {
                if (category.substring(3) === '0000') {
                   this.myCategory.categoryGroupCode = category;
                    this.myCategory.categorySubgroupCode = '-1';
                    this.myCategory.armyCareerProgramNumber = '-1';
                }
                else {
                   this.myCategory.categoryGroupCode = category.substring(0, 2) + '-0000';
                    this.myCategory.categorySubgroupCode = category;
                    this.myCategory.armyCareerProgramNumber = '-1';
                }
            }
        } else if (wageAppropriatedFundPayPlans.indexOf(payPlan) !== -1) {
            if (category === '-1') {
               this.myCategory.categoryGroupCode = '-1';
                this.myCategory.categorySubgroupCode = '-1';
                this.myCategory.armyCareerProgramNumber = '-1';
            }
            else if (category.length === 4) {
                if (category.substring(2, 4) === '00') {
                   this.myCategory.categoryGroupCode = category;
                    this.myCategory.categorySubgroupCode = '-1';
                    this.myCategory.armyCareerProgramNumber = '-1';
                }
                else {
                   this.myCategory.categoryGroupCode = category.substring(0, 2) + '00';
                    this.myCategory.categorySubgroupCode = category.substring(0, 4);
                    this.myCategory.armyCareerProgramNumber = '-1';
                }
            }
        }

        return this.myCategory;
    }
    
}
var amcos = amcos || new AMCOSCommon();
function docReady(fn) {
    if (document.readyState === "complete" || document.readyState === "interactive") {
        setTimeout(fn, 1);
    } else {
        document.addEventListener("DOMContentLoaded", fn);
    }
}

function getPayPlanIndex(payPlan) {
    for (var i = 0; i < payPlanObject.length; i++) {
        if (payPlanObject[i].payPlanValue === payPlan) {
            return i;
        }
    }
}

function getCategoryGroupLabel(payPlan) {
    var payPlanIndex = getPayPlanIndex(payPlan);
    return payPlanObject[payPlanIndex].categoryGroupLabel;
}

function getCategorySubgroupLabel(payPlan) {
    var payPlanIndex = getPayPlanIndex(payPlan);
    return payPlanObject[payPlanIndex].categorySubgroupLabel;
}

function getInflationConversionTypeIndex(inflationConversionType) {
    for (var i = 0; i < inflationYearObject.length; i++) {
        if (inflationYearObject[i].conversionType === inflationConversionType) {
            return i;
        }
    }
}

function initializeCategoryList(selectObject, payPlan) {
    $(selectObject).selectize()[0].selectize.destroy();
    let payPlanIndex = getPayPlanIndex(payPlan);
    $(selectObject).selectize({
        maxItems: 1,
        options: [],
        create: false,
        optgroups: payPlanObject[payPlanIndex].categoryOptionGroups,
        labelField: 'Text',
        valueField: 'Value',
        optgroupField: 'OptionGroup',
        optgroupLabelField: 'label',
        optgroupValueField: 'optgroup',
        sortField: [
            {
                field: 'Value',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        placeholder: payPlanObject[payPlanIndex].categoryPlaceholderText,
        plugins: ['optgroup_columns'],
        preload: true,
        load: function (query, data) {
            $.ajax({
                url: _baseApiUrl + '/categories/' + encodeURIComponent(payPlan),
                dataType: "json",
                type: "GET",
                error: function () {
                    data();
                },
                success: function (results) {
                    data(results);
                }
            });
        },
        onChange: function (value) {
            changeCategory(payPlan, value);
        }
    });
}

function initializeCostSummaryList(selectObject, payPlan, filterObject) {
    var payPlanIndex = getPayPlanIndex(payPlan);
    $(selectObject).selectize()[0].selectize.destroy();

    var items = payPlanObject[payPlanIndex].costSummaries.map(function (x) { return { value: x, text: x }; });

    $(selectObject).selectize({
        options: items,
        items: ['Default'],
        maxItems: 1,
        valueField: 'value',
        labelField: 'text',
        searchField: ['text'],
        placeholder: 'Select a Cost Summary',
        onChange: function (value) {
            filterObject.costSummaryName = value;
            changeCostSummary(value);
        }
    });

    if (items.length === 1) {
        $(selectObject).selectize()[0].selectize.disable();
    } else {
        $(selectObject).selectize()[0].selectize.enable();
    }
}

function initializeDependentStatusList(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [
            { value: 'average', text: 'Average' },
            { value: 'with', text: 'With Dependents' },
            { value: 'without', text: 'Without Dependents' }
        ],
        maxItems: 1,
        valueField: 'value',
        labelField: 'text',
        placeholder: 'Select a Dependent Status',
        selectOnTab: false,
        onChange: function (value) {
            filterObject.dependentStatus = value;
            changeDependentStatus();
        }
    });
    filterObject.dependentStatus = "-1";
}

function initializeGradeLevelList(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        maxItems: 1,
        placeholder: 'Choose a grade level',
        valueField: 'Value',
        labelField: 'Text',
        sortField: [
            {
                field: 'Value',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        selectOnTab: false,
        onChange: function (value) {
            filterObject.gradeLevel = value;
            changeGradeLevel(value);
        }
    });
}

function initializeInflationConversionTypeList(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();

    $(selectObject).selectize({
        items: ['ThenToThen'],
        maxItems: 1,
        onChange: function (value) {
            filterObject.inflationConversion = value;
            changeInflationConversionType(value);
        }
    });
}

function initializeInflationYearList(selectObject, inflationConversionType, filterObject, defaultValue) {
    var inflationConversionTypeIndex = getInflationConversionTypeIndex(inflationConversionType);
    $(selectObject).selectize()[0].selectize.destroy();

    var items = inflationYearObject[inflationConversionTypeIndex].years.map(function (x) { return { value: x.yearValue, text: x.yearValue }; });

    $(selectObject).selectize({
        options: items,
        items: [defaultValue],
        valueField: 'value',
        labelField: 'text',
        searchField: ['text'],
        placeholder: 'Select an Inflation Year',
        selectOnTab: false,
        onChange: function (value) {
            filterObject.inflationYear = value;
            changeInflationYear(value);
        }
    });
}

function initializeLocationListCCE(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        maxOptions: 10000,
        maxItems: 1,
        placeholder: 'Select a Location',
        preload: true,
        optgroups: [
            { $order: 1, value: 'all', label: 'All' },
            { $order: 2, value: 'installation', label: 'Installation' },
            { $order: 3, value: 'metropolitanStatisticalArea', label: 'Metropolitan Statistical Area' }
        ],
        valueField: 'Value',
        optgroupValueField: 'value',
        labelField: 'Text',
        optgroupLabelField: 'label',
        optgroupField: 'OptionGroup',
        sortField: [
            {
                field: 'Text',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        plugins: { 'optgroup_columns': { equalizeWidth: false, equalizeHeight: false } },
        lockOptgroupOrder: true,
        onChange: function (value) {
            filterObject.locationId = parseInt(value.split(".")[0]);
            filterObject.locationText = $(selectObject)[0].selectize.getItem($(selectObject)[0].selectize.getValue()).text();
            var locationType = value.split(".")[2];
            changeLocation(locationType);
        }
    });
    $(selectObject).selectize()[0].selectize.disable();
}

function initializeLocationListFWS(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        maxOptions: 10000,
        maxItems: 1,
        placeholder: 'Select a Location',
        preload: true,
        optgroups: [
            { $order: 1, value: 'all', label: 'All' },
            { $order: 2, value: 'installation', label: 'Installation' },
            { $order: 3, value: 'wageSchedule', label: 'Wage Schedule' },
            { $order: 4, value: 'cityCounty', label: 'City/County' },
            { $order: 5, value: 'civilianOverseasArea', label: 'Overseas' }
        ],
        valueField: 'Value',
        optgroupValueField: 'value',
        labelField: 'Text',
        optgroupLabelField: 'label',
        optgroupField: 'OptionGroup',
        sortField: [
            {
                field: 'Text',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        plugins: { 'optgroup_columns': { equalizeWidth: false, equalizeHeight: false } },
        lockOptgroupOrder: true,
        onChange: function (value) {
            filterObject.locationId = parseInt(value.split(".")[0]);
            filterObject.locationText = $(selectObject)[0].selectize.getItem($(selectObject)[0].selectize.getValue()).text();
            var locationType = value.split(".")[2];
            changeLocation(locationType);
        }
    });
    $(selectObject).selectize()[0].selectize.disable();
}

function initializeLocationListGS(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        maxOptions: 10000,
        maxItems: 1,
        placeholder: 'Select a Location',
        preload: true,
        optgroups: [
            { $order: 1, value: 'all', label: 'All' },
            { $order: 2, value: 'installation', label: 'Installation' },
            { $order: 3, value: 'localityPayArea', label: 'Locality Pay Area' },
            { $order: 4, value: 'specialPayArea', label: 'Special Pay Area' },
            { $order: 5, value: 'country', label: 'Country' },
            { $order: 6, value: 'civilianOverseasArea', label: 'Overseas' }
        ],
        valueField: 'Value',
        optgroupValueField: 'value',
        labelField: 'Text',
        optgroupLabelField: 'label',
        optgroupField: 'OptionGroup',
        sortField: [
            {
                field: 'Text',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        plugins: { 'optgroup_columns': { equalizeWidth: false, equalizeHeight: false } },
        lockOptgroupOrder: true,
        onChange: function (value) {
            filterObject.locationId = parseInt(value.split(".")[0]);
            filterObject.locationText = $(selectObject)[0].selectize.getItem($(selectObject)[0].selectize.getValue()).text();
            var locationType = value.split(".")[2];
            changeLocation(locationType);
        }
    });
    $(selectObject).selectize()[0].selectize.disable();
}

function initializeLocationListMilitary(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        maxOptions: 10000,
        maxItems: 1,
        placeholder: 'Select a Location',
        optgroups: [
            { $order: 1, value: 'all', label: 'All' },
            { $order: 2, value: 'installation', label: 'Military Installation' },
            { $order: 3, value: 'mha-conus', label: 'Military Housing Area (CONUS)' },
            { $order: 4, value: 'mha-oconus', label: 'Military Housing Area (OCONUS)' }
        ],
        valueField: 'Value',
        optgroupValueField: 'value',
        labelField: 'Text',
        optgroupLabelField: 'label',
        optgroupField: 'OptionGroup',
        sortField: [
            {
                field: 'Text',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        plugins: { 'optgroup_columns': { equalizeWidth: false, equalizeHeight: false } },
        lockOptgroupOrder: true,
        onChange: function (value) {
            filterObject.locationId = parseInt(value.split(".")[0]);
            filterObject.locationText = $(selectObject)[0].selectize.getItem($(selectObject)[0].selectize.getValue()).text();
            var locationType = value.split(".")[2];
            changeLocation(locationType);
        }
    });
}
function initializeMtoeUnitYearList(selectObject, unitObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        maxOptions: 10000,
        maxItems: 1,
        placeholder: 'Select a year',
        valueField: 'Value',
        labelField: 'Text',
        sortField: [
            {
                field: 'Text',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        onChange: function (value) {
            unitObject.mtoeProjectInventoryYear = value;
            unitObject.setHiddenFields();
            unitObject.setAccordionTitles();
        }
    });
    $(selectObject).selectize()[0].selectize.disable();
}
function initializeNumberOfDependentsList(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [
            { value: '0', text: '0' },
            { value: '1', text: '1' },
            { value: '2', text: '2' },
            { value: '3', text: '3' },
            { value: '4', text: '4' },
            { value: '5', text: '5' }
        ],
        valueField: 'value',
        labelField: 'text',
        maxItems: 1,
        placeholder: 'Number of Dependents',
        selectOnTab: false,
        onChange: function (value) {
            filterObject.numberOfDependents = parseInt(value);
            changeNumberOfDependents();
        }
    });
    filterObject.numberOfDependents = -1;
}

function initializePayPlanList(selectObject) {
    if (selectObject) {
        $(selectObject).selectize()[0].selectize.destroy();
        $(selectObject).selectize({
            options: [
                { value: 'AE', text: 'Active Enlisted (AE)', optionGroup: 'military' },
                { value: 'AO', text: 'Active Officer (AO)', optionGroup: 'military' },
                { value: 'AWO', text: 'Active Warrant Officer (AWO)', optionGroup: 'military' },
                { value: 'NE', text: 'National Guard Enlisted (NE)', optionGroup: 'military' },
                { value: 'NO', text: 'National Guard Officer (NO)', optionGroup: 'military' },
                { value: 'NWO', text: 'National Guard Warrant Officer (NWO)', optionGroup: 'military' },
                { value: 'RE', text: 'Reserve Enlisted (RE)', optionGroup: 'military' },
                { value: 'RO', text: 'Reserve Officer (RO)', optionGroup: 'military' },
                { value: 'RWO', text: 'Reserve Warrant Officer (RWO)', optionGroup: 'military' },
                { value: 'AD', text: 'Administratively Determined (AD)', optionGroup: 'civilian' },
                { value: 'CA', text: 'Board of Contract Appeals (CA)', optionGroup: 'civilian' },
                { value: 'CCE', text: 'Contractor Cost Estimate (CCE)', optionGroup: 'civilian' },
                { value: 'EE', text: 'Expert (EE)', optionGroup: 'civilian' },
                { value: 'EF', text: 'Consultant (EF)', optionGroup: 'civilian' },
                { value: 'EX', text: 'Executive (EX)', optionGroup: 'civilian' },
                { value: 'GG', text: 'Intelligence Personnel (GG)', optionGroup: 'civilian' },
                { value: 'GL', text: 'Law Enforcement Officers (GL)', optionGroup: 'civilian' },
                { value: 'GP', text: 'Physicians and Dentists (GP)', optionGroup: 'civilian' },
                { value: 'GS', text: 'General Schedule (GS)', optionGroup: 'civilian' },
                { value: 'IE', text: 'Senior Intelligence Executive Service (IE)', optionGroup: 'civilian' },
                { value: 'IG', text: 'Inspectors General (IG)', optionGroup: 'civilian' },
                { value: 'IP', text: 'Senior Intelligence Professional (IP)', optionGroup: 'civilian' },
                { value: 'SES', text: 'Senior Executive Schedule (SES)', optionGroup: 'civilian' },
                { value: 'SL', text: 'Senior Level Positions (SL)', optionGroup: 'civilian' },
                { value: 'ST', text: 'Scientific and Professional (ST)', optionGroup: 'civilian' },
                { value: 'ZZ', text: 'Non-applicable (ZZ)', optionGroup: 'civilian' },
                { value: 'DB', text: 'Engineers & Scientists (DB)', optionGroup: 'laboratory' },
                { value: 'DE', text: 'Engineer & Scientist Technicians (DE)', optionGroup: 'laboratory' },
                { value: 'DJ', text: 'Administrative (DJ)', optionGroup: 'laboratory' },
                { value: 'DK', text: 'General Support (DK)', optionGroup: 'laboratory' },
                { value: 'NH', text: 'Business and Technical Management Professionals (NH)', optionGroup: 'acquisition' },
                { value: 'NJ', text: 'Technical Management Support (NJ)', optionGroup: 'acquisition' },
                { value: 'NK', text: 'Administration Support (NK)', optionGroup: 'acquisition' },
                { value: 'WG', text: 'Wage Grade (WG)', optionGroup: 'wage-af' },
                { value: 'WL', text: 'Wage Leader (WL)', optionGroup: 'wage-af' },
                { value: 'WS', text: 'Wage Supervisor (WS)', optionGroup: 'wage-af' },
                { value: 'XF', text: 'Floating Plant Grade (XF)', optionGroup: 'wage-af' },
                { value: 'XG', text: 'Floating Plant Leader (XG)', optionGroup: 'wage-af' },
                { value: 'XH', text: 'Floating Plant Supervisor (XH)', optionGroup: 'wage-af' },
                { value: 'WJ', text: 'Hopper Dredge (WJ)', optionGroup: 'wage-af' },
                { value: 'WK', text: 'Hopper Dredge - nonsupervisory (WK)', optionGroup: 'wage-af' },
                { value: 'WY', text: 'Lock & Dam Grade (WY)', optionGroup: 'wage-af' },
                { value: 'WO', text: 'Lock & Dam Leader (WO)', optionGroup: 'wage-af' },
                { value: 'WA', text: 'Lock & Dam Supervisor (WA)', optionGroup: 'wage-af' },
                { value: 'WD', text: 'Production Facility Grade (WD)', optionGroup: 'wage-af' },
                { value: 'WN', text: 'Production Facility Supervisor (WN)', optionGroup: 'wage-af' },               
                { value: 'WT', text: 'Trainees (WT)', optionGroup: 'wage-af' },
                { value: 'WU', text: 'Special Puerto Rico Grade (WU)', optionGroup: 'wage-af' },
                { value: 'WB', text: 'Wage not otherwise designated (WB)', optionGroup: 'wage-af' },
                { value: 'NA', text: 'Wage Grade (NA)', optionGroup: 'wage-naf' },
                { value: 'NL', text: 'Wage Leader (NL)', optionGroup: 'wage-naf' },
                { value: 'NS', text: 'Wage Supervisor (NS)', optionGroup: 'wage-naf' },
                { value: 'CY', text: 'Child and Youth Programs (CY)', optionGroup: 'wage-naf' },
                { value: 'NF', text: 'NAF Pay Band (NF)', optionGroup: 'wage-naf' }
            ],
            optgroups: [
                { $order: 1, value: 'military', label: 'Military' },
                { $order: 2, value: 'civilian', label: 'Civilian-G/S/C' },
                { $order: 3, value: 'laboratory', label: 'Laboratory Demo' },
                { $order: 4, value: 'acquisition', label: 'Acquisition Demo' },
                { $order: 5, value: 'wage-af', label: 'Wage (AF)' },
                { $order: 6, value: 'wage-naf', label: 'Wage (NAF)' }
            ],
            valueField: 'value',
            optgroupValueField: 'value',
            labelField: 'text',
            optgroupLabelField: 'label',
            optgroupField: 'optionGroup',
            maxItems: 1,
            placeholder: 'Select a Pay Plan',
            selectOnTab: false,
            onChange: function (value) {
                changePayPlan(value);
            },
            plugins: { 'optgroup_columns': { equalizeWidth: false, equalizeHeight: false } }
        });
    }
}

function initializeScienceTechnologyReinventionLaboratoryList(selectObject, filterObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        maxItems: 1,
        placeholder: 'Select an STRL',
        valueField: 'Value',
        labelField: 'Text',
        sortField: [
            {
                field: 'Text',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        selectOnTab: false,
        onChange: function (value) {
            filterObject.scienceTechnologyReinventionLaboratory = value;
            changeStrl();
        }
    });
}

function initializeUnitList(selectObject, unitObject) {
    if (selectObject) {
        $(selectObject).selectize()[0].selectize.destroy();
        $(selectObject).selectize({
            options: [],
            create: false,
            maxItems: 1,
            placeholder: 'Please select a unit to add',
            preload: true,
            valueField: 'Value',
            labelField: 'Text',
            sortField: [
                {
                    field: 'Text',
                    direction: 'asc'
                }
            ],
            searchField: ['Text'],
            selectOnTab: false,
            onChange: function (value) {
                unitObject.reset();
                unitObject.uic = value;
                changeUnit(value);
            },
            load: function(query, callback) {
                $.ajax({
                    url: _baseApiUrl + '/units',
                    dataType: "json",
                    type: "GET",
                    error: function() {
                        callback();
                    },
                    success: function(results) {
                        callback(results);
                    }
                });
            }
        });
    }
}

function initializeUnitLocationList(selectObject, unitObject) {
    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        //maxOptions: 10000,
        maxItems: 1,
        placeholder: 'Select a Location',
        optgroups: [
            { $order: 1, value: 'installation', label: 'Military Installation' }
        ],
        valueField: 'Value',
        optgroupValueField: 'value',
        labelField: 'Text',
        optgroupLabelField: 'label',
        optgroupField: 'OptionGroup',
        sortField: [
            {
                field: 'Text',
                direction: 'asc'
            }
        ],
        searchField: ['Text'],
        plugins: { 'optgroup_columns': { equalizeWidth: false, equalizeHeight: false } },
        lockOptgroupOrder: true,
        onChange: function (value) {
            unitObject.unitLocation = parseInt(value.split(".")[0]);
            unitObject.setHiddenFields();
            unitObject.setAccordionTitles();
        }
    });
    $(selectObject).selectize()[0].selectize.disable();
}

function isValidCategory() {
    var isValid = false;
    if (!document.getElementById('categoryFilter').classList.contains('hide')) {
        if ($(document.getElementById("categoryList"))[0].selectize !== undefined) {
            if ($(document.getElementById("categoryList"))[0].selectize.getValue() !== '') {
                isValid = true;
            }
            else {
                alert("Please select an option from the category list");
                isValid = false;
            }
        }
    } else {
        isValid = true;
    }
    return isValid;
}

function isValidDependentStatus() {
    var isValid = false;
    if (!document.getElementById('dependentStatusFilter').classList.contains('hide')) {
        if ($(document.getElementById('dependentStatusList'))[0].selectize !== undefined) {
            if ($(document.getElementById('dependentStatusList'))[0].selectize.getValue() !== '') {
                isValid = true;
            }
            else {
                alert("Please select an option from the dependent status list");
                isValid = false;
            }
        }
    } else {
        isValid = true;
    }
    return isValid;
}

function isValidGradeLevel() {
    var isValid = false;
    if (document.getElementById('gradeLevelFilter') == null) {
        isValid = true;
    } else
    if (!document.getElementById('gradeLevelFilter').classList.contains('hide')) {
        if ($(document.getElementById('gradeLevelList'))[0].selectize !== undefined) {
            if ($(document.getElementById('gradeLevelList'))[0].selectize.getValue() !== '') {
                isValid = true;
            }
            else {
                alert("Please select an option from the grade level list");
                isValid = false;
            }
        }
    } else {
        isValid = true;
    }
    return isValid;
}

function isValidLocation() {
    var isValid = false;
    if (!document.getElementById('locationFilter').classList.contains('hide')) {
        if ($(document.getElementById("locationList"))[0].selectize !== undefined) {
            if ($(document.getElementById("locationList"))[0].selectize.getValue() !== '') {
                isValid = true;
            }
            else {
                alert("Please select an option from the location list");
                isValid = false;
            }
        }
    } else {
        isValid = true;
    }
    return isValid;
}

function isValidNumberOfDependents() {
    var isValid = false;
    if (!document.getElementById('numberOfDependentsFilter').classList.contains('hide')) {
        if ($(document.getElementById('numberOfDependentsList'))[0].selectize !== undefined) {
            if ($(document.getElementById('numberOfDependentsList'))[0].selectize.getValue() !== '') {
                isValid = true;
            }
            else {
                alert("Please select the number of dependents");
                isValid = false;
            }
        }
    } else {
        isValid = true;
    }
    return isValid;
}

function isValidOverheadPercent() {
    var isValid = false;
    if (!document.getElementById('overheadPercentFilter').classList.contains('hide')) {
        if (document.getElementById('overheadPercent').value !== undefined) {
            if (document.getElementById('overheadPercent').value !== '') {
                isValid = true;
            }
            else {
                alert("Please enter an overhead percent");
                isValid = false;
            }
        }
    } else {
        isValid = true;
    }
    return isValid;
}

function isValidPayPlan() {
    var isValid = false;
    if ($(document.getElementById("payPlanList"))[0].selectize !== undefined) {
        if ($(document.getElementById("payPlanList"))[0].selectize.getValue() !== '') {
            isValid = true;
        }
        else {
            alert("Please select a pay plan from the list");
            isValid = false;
        }
    }
    return isValid;
}

function isValidScienceTechnologyReinventionLaboratory() {
    var isValid = false;
    if (!document.getElementById('scienceTechnologyReinventionLaboratoryFilter').classList.contains('hide')) {
        if ($(document.getElementById("scienceTechnologyReinventionLaboratoryList"))[0].selectize !== undefined) {
            if ($(document.getElementById("scienceTechnologyReinventionLaboratoryList"))[0].selectize.getValue() !== '') {
                isValid = true;
            }
            else {
                alert("Please select an STRL from the list");
                isValid = false;
            }
        }
    } else {
        isValid = true;
    }
    return isValid;
}

function isValidUnitLocation() {
    var isValid = false;
    if ($(document.getElementById("unitLocationList"))[0].selectize !== undefined) {
        if ($(document.getElementById("unitLocationList"))[0].selectize.getValue() !== '') {
            isValid = true;
        } else {
            alert("Please select an UnitLocation from the list");
            isValid = false;
        }
    }
    return isValid;
}

function isValidUnitFreezeYear() {
    var isValid = false;
    if ($(document.getElementById("mtoeUnitYearList"))[0].selectize !== undefined) {
        if ($(document.getElementById("mtoeUnitYearList"))[0].selectize.getValue() !== '') {
            isValid = true;
        } else {
            alert("Please select an UnitFreezeYear from the list");
            isValid = false;
        }
    }
    return isValid;
}

function loadGradeLevelList(payPlan, categoryGroupCode, categorySubgroupCode, careerProgramNumber, locationId) {
    document.getElementById('gradeLevelFilter').classList.remove('hide');
    $(document.getElementById("gradeLevelList"))[0].selectize.clear(true);
    $(document.getElementById("gradeLevelList"))[0].selectize.clearOptions();

    if (payPlan === 'CCE') {
        $(document.getElementById("gradeLevelList"))[0].selectize.load(function (data) {
            data([
                { "Value": 1, "Text": "A_PCT10" },
                { "Value": 2, "Text": "A_PCT25" },
                { "Value": 3, "Text": "A_MEDIAN" },
                { "Value": 4, "Text": "A_PCT75" },
                { "Value": 5, "Text": "A_PCT90" }
            ]);  
        });
    } else {        
        $(document.getElementById("gradeLevelList"))[0].selectize.load(function (data) {
            $.ajax({
                url: _baseApiUrl + '/grades/' + encodeURIComponent(payPlan) + '/' + encodeURIComponent(categoryGroupCode) + '/' + encodeURIComponent(categorySubgroupCode) + '/' + encodeURIComponent(careerProgramNumber) + '/' + encodeURIComponent(locationId),
                dataType: "json",
                type: "GET",
                error: function () {
                    data();
                },
                success: function (results) {
                    data(results);
                }
            });
        });
    }
}

function loadLocationList(payPlan, categoryGroupCode, categorySubgroupCode, careerProgramNumber) {
    $(document.getElementById("locationList"))[0].selectize.clear(true);
    $(document.getElementById("locationList"))[0].selectize.clearOptions();
    $(document.getElementById("locationList"))[0].selectize.load(function (data) {
        $.ajax({
            url: _baseApiUrl + '/locations/' + encodeURIComponent(payPlan) + '/' + encodeURIComponent(categoryGroupCode) + '/' + encodeURIComponent(categorySubgroupCode) + '/' + encodeURIComponent(careerProgramNumber),
            dataType: "json",
            type: "GET",
            error: function () {
                data();
            },
            success: function (results) {
                data(results);
            }
        });
    });
}

function loadScienceTechnologyReinventionLaboratoryList(payPlan, categoryGroupCode, categorySubgroupCode, careerProgramNumber, locationId) {
    $(document.getElementById("scienceTechnologyReinventionLaboratoryList"))[0].selectize.clear(true);
    $(document.getElementById("scienceTechnologyReinventionLaboratoryList"))[0].selectize.clearOptions();
    $(document.getElementById("scienceTechnologyReinventionLaboratoryList"))[0].selectize.load(function (data) {
        $.ajax({
            url: _baseApiUrl + '/strls/' + encodeURIComponent(payPlan) + '/' + encodeURIComponent(categoryGroupCode) + '/' + encodeURIComponent(categorySubgroupCode) + '/' + encodeURIComponent(careerProgramNumber) + '/' + encodeURIComponent(locationId),
            dataType: "json",
            type: "GET",
            error: function () {
                data();
            },
            success: function (results) {
                data(results);
            }
        });
    });
}

function loadMtoeUnitYearList(uic) {
    $(document.getElementById("mtoeUnitYearList"))[0].selectize.clear(true);
    $(document.getElementById("mtoeUnitYearList"))[0].selectize.clearOptions();
    $(document.getElementById("mtoeUnitYearList"))[0].selectize.load(function (data) {
        $.ajax({
            url: _baseApiUrl + '/units/' + encodeURIComponent(uic) + '/mtoeyears',
            dataType: "json",
            type: "GET",
            error: function () {
                data();
            },
            success: function (results) {
                data(results);
            }
        });
    });
}

function loadUnitList() {
    $(document.getElementById("unitList"))[0].selectize.clear(true);
    $(document.getElementById("unitList"))[0].selectize.clearOptions();
    $(document.getElementById("unitList"))[0].selectize.load(function (data) {
        $.ajax({
            url: _baseApiUrl + '/units',
            dataType: "json",
            type: "GET",
            error: function () {
                data();
            },
            success: function (results) {
                data(results);
            }
        });
    });
}

function loadUnitLocationList() {
    $(document.getElementById("unitLocationList"))[0].selectize.clear(true);
    $(document.getElementById("unitLocationList"))[0].selectize.clearOptions();
    $(document.getElementById("unitLocationList"))[0].selectize.load(function (data) {
        $.ajax({
            url: _baseApiUrl + '/locations/installations',
            dataType: "json",
            type: "GET",
            error: function () {
                data();
            },
            success: function (results) {
                data(results);
            }
        });
    });
}

function hideActiveDutyDaysFilter() {
    document.getElementById("activeDutyDaysFilter").classList.add('hide');
}

function hideCCENote() {
    if (document.getElementById("cceNote")) {
        document.getElementById("cceNote").classList.add('hide');
    }
}

function hideContractorCostEstimateOverheadAccordionInput() {
    if (document.getElementById("contractorCostEstimateOverheadAccordionInput")) {
        document.getElementById("contractorCostEstimateOverheadAccordionInput").classList.add('hide');
    }
}

function hideDependentStatusFilter(filterObject) {
    filterObject.dependentStatus = '-1';
    document.getElementById('dependentStatusFilter').classList.add('hide');
}

function hideGfebsSelectAllWarning() {
    if (document.getElementById("gfebsSelectAllWarning")) {
        document.getElementById("gfebsSelectAllWarning").classList.add('hide');
    }
}

function hideGradeLevelFilter() {
    document.getElementById("gradeLevelFilter").classList.add('hide');
}

function hideInventoryFilter() {
    document.getElementById("inventoryFilter").classList.add('hide');
}

function hideLocationFilter(filterObject) {
    filterObject.locationId = -1;
    filterObject.locationText = "-1";
    document.getElementById('locationFilter').classList.add('hide');
}

function hideProjectInventoryYear() {
    document.getElementById('projectInventoryYear').classList.add('hide');
}

function hideMtoeSyncOptionFilter() {
    document.getElementById('mtoeSyncOption').classList.add('hide');
}

function hideNumberOfDependentsFilter(filterObject) {
    filterObject.numberOfDependents = -1;
    document.getElementById('numberOfDependentsFilter').classList.add('hide');
}

function hideOverheadPercentFilter() {
    document.getElementById("overheadPercentFilter").classList.add('hide');
}

function hideScienceTechnologyReinventionLaboratoryFilter() {
    document.getElementById('scienceTechnologyReinventionLaboratoryFilter').classList.add('hide');
}

function hideWeaponSystemWarning() {
    if (document.getElementById("weaponSystemWarning")) {
        document.getElementById("weaponSystemWarning").classList.add('hide');
    }
}

function showActiveDutyDaysFilter() {
    document.getElementById('activeDutyDaysFilter').classList.remove('hide');
    document.getElementById("activeDutyDays").addEventListener("input", changeActiveDutyDays);
}

function showCategoryFilter() {
    document.getElementById('categoryFilter').classList.remove('hide');
}

function showCCENote() {
    if (document.getElementById("cceNote")) {
        document.getElementById("cceNote").classList.remove('hide');
    }
}

function showContractorCostEstimateOverheadAccordionInput() {
    if (document.getElementById("contractorCostEstimateOverheadAccordionInput")) {
        document.getElementById("contractorCostEstimateOverheadAccordionInput").classList.remove('hide');
        if (document.getElementById("unitContractorOverheadPercent")) {
            document.getElementById("unitContractorOverheadPercent").addEventListener('input', changeUnitOverheadPercent);
        }
    }
}

function showDependentStatusFilter() {
    document.getElementById('dependentStatusFilter').classList.remove('hide');
}

function showGfebsSelectAllWarning() {
    if (document.getElementById("gfebsSelectAllWarning")) {
        document.getElementById("gfebsSelectAllWarning").classList.remove('hide');
    }
}

function showLocationFilter() {
    document.getElementById('locationFilter').classList.remove('hide');
}

function showProjectInventoryYear() {
    document.getElementById('projectInventoryYear').classList.remove('hide');
}

function showMtoeSyncOptionFilter() {
    document.getElementById('mtoeSyncOption').classList.remove('hide');
}

function showNumberOfDependentsFilter() {
    document.getElementById('numberOfDependentsFilter').classList.remove('hide');
}

function showOverheadPercentFilter() {
    document.getElementById("overheadPercentFilter").classList.remove('hide');
}

function showScienceTechnologyReinventionLaboratoryFilter() {
    document.getElementById('scienceTechnologyReinventionLaboratoryFilter').classList.remove('hide');
}

function showWeaponSystemWarning() {
    if (document.getElementById("weaponSystemWarning")) {
        document.getElementById("weaponSystemWarning").classList.remove('hide');
    }
}

function validateFilters() {
    var isValid = false;

    if (isValidPayPlan()) {
        if (isValidCategory()) {
            if (isValidLocation()) {
                if (isValidScienceTechnologyReinventionLaboratory()) {
                    if (isValidDependentStatus()) {
                        if (isValidNumberOfDependents()) {
                            if (isValidOverheadPercent()) {
                                if (isValidGradeLevel()) {
                                    isValid = true;
                                } else {
                                    isValid = false;
                                }
                            } else {
                                isValid = false;
                            }
                        } else {
                            isValid = false;
                        }
                    } else {
                        isValid = false;
                    }
                } else {
                    isValid = false;
                }
            } else {
                isValid = false;
            }
        } else {
            isValid = false;
        }
    }
    return isValid;
}

function validateAddUnit() {
    //var isValid = false;

    //if (isValidPayPlan()) {
    //    isValid = true;
    //} else {
    //    isValid = false;
    //}
    //return isValid;
}

function validateSumOfInventory() {
    let year1;
    let year2;
    let year3;
    let year4;
    let year5;
    let year6;
    let year7;
    let year8;
    let year9;
    let year10;
    let year11;
    let year12;
    let year13;
    let year14;
    let year15;
    let year16;
    let year17;
    let year18;
    let year19;
    let year20;
    let year21;
    let year22;
    let year23;
    let year24;
    let year25;
    let year26;
    let year27;
    let year28;
    let year29;
    let year30;

    if (document.getElementById("InsertYear1")) {
        year1 = document.getElementById("InsertYear1").value;
    }
    else {
        year1 = 0;
    }

    if (document.getElementById("InsertYear2")) {
        year2 = document.getElementById("InsertYear2").value;
    }
    else {
        year2 = 0;
    }

    if (document.getElementById("InsertYear3")) {
        year3 = document.getElementById("InsertYear3").value;
    }
    else {
        year3 = 0;
    }

    if (document.getElementById("InsertYear4")) {
        year4 = document.getElementById("InsertYear4").value;
    }
    else {
        year4 = 0;
    }

    if (document.getElementById("InsertYear5")) {
        year5 = document.getElementById("InsertYear5").value;
    }
    else {
        year5 = 0;
    }

    if (document.getElementById("InsertYear6")) {
        year6 = document.getElementById("InsertYear6").value;
    }
    else {
        year6 = 0;
    }

    if (document.getElementById("InsertYear7")) {
        year7 = document.getElementById("InsertYear7").value;
    }
    else {
        year7 = 0;
    }

    if (document.getElementById("InsertYear8")) {
        year8 = document.getElementById("InsertYear8").value;
    }
    else {
        year8 = 0;
    }

    if (document.getElementById("InsertYear9")) {
        year9 = document.getElementById("InsertYear9").value;
    }
    else {
        year9 = 0;
    }

    if (document.getElementById("InsertYear10")) {
        year10 = document.getElementById("InsertYear10").value;
    }
    else {
        year10 = 0;
    }

    if (document.getElementById("InsertYear11")) {
        year11 = document.getElementById("InsertYear11").value;
    }
    else {
        year11 = 0;
    }

    if (document.getElementById("InsertYear12")) {
        year12 = document.getElementById("InsertYear12").value;
    }
    else {
        year12 = 0;
    }

    if (document.getElementById("InsertYear13")) {
        year13 = document.getElementById("InsertYear13").value;
    }
    else {
        year13 = 0;
    }

    if (document.getElementById("InsertYear14")) {
        year14 = document.getElementById("InsertYear14").value;
    }
    else {
        year14 = 0;
    }

    if (document.getElementById("InsertYear15")) {
        year15 = document.getElementById("InsertYear15").value;
    }
    else {
        year15 = 0;
    }

    if (document.getElementById("InsertYear16")) {
        year16 = document.getElementById("InsertYear16").value;
    }
    else {
        year16 = 0;
    }

    if (document.getElementById("InsertYear17")) {
        year17 = document.getElementById("InsertYear17").value;
    }
    else {
        year17 = 0;
    }

    if (document.getElementById("InsertYear18")) {
        year18 = document.getElementById("InsertYear18").value;
    }
    else {
        year18 = 0;
    }

    if (document.getElementById("InsertYear19")) {
        year19 = document.getElementById("InsertYear19").value;
    }
    else {
        year19 = 0;
    }
    if (document.getElementById("InsertYear20")) {
        year20 = document.getElementById("InsertYear20").value;
    }
    else {
        year20 = 0;
    }

    if (document.getElementById("InsertYear21")) {
        year21 = document.getElementById("InsertYear21").value;
    }
    else {
        year21 = 0;
    }

    if (document.getElementById("InsertYear22")) {
        year22 = document.getElementById("InsertYear22").value;
    }
    else {
        year22 = 0;
    }

    if (document.getElementById("InsertYear23")) {
        year23 = document.getElementById("InsertYear23").value;
    }
    else {
        year23 = 0;
    }

    if (document.getElementById("InsertYear24")) {
        year24 = document.getElementById("InsertYear24").value;
    }
    else {
        year24 = 0;
    }

    if (document.getElementById("InsertYear25")) {
        year25 = document.getElementById("InsertYear25").value;
    }
    else {
        year25 = 0;
    }

    if (document.getElementById("InsertYear26")) {
        year26 = document.getElementById("InsertYear26").value;
    }
    else {
        year26 = 0;
    }

    if (document.getElementById("InsertYear27")) {
        year27 = document.getElementById("InsertYear27").value;
    }
    else {
        year27 = 0;
    }

    if (document.getElementById("InsertYear28")) {
        year28 = document.getElementById("InsertYear28").value;
    }
    else {
        year28 = 0;
    }

    if (document.getElementById("InsertYear29")) {
        year29 = document.getElementById("InsertYear29").value;
    }
    else {
        year29 = 0;
    }

    if (document.getElementById("InsertYear30")) {
        year30 = document.getElementById("InsertYear30").value;
    }
    else {
        year30 = 0;
    }

    let sumOfInventory = year1 + year2 + year3 + year4 + year5 + year6 + year7 + year8 + year9 + year10
        + year11 + year12 + year13 + year14 + year15 + year16 + year17 + year18 + year19 + year20
        + year21 + year22 + year23 + year24 + year25 + year26 + year27 + year28 + year29 + year30;

    if (sumOfInventory === 99) {
        args.IsValid = true;
    } else {
        args.Invalid = false;
    }
}