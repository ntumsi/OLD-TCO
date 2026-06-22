var _selectLocationsData = null;
var _originationCallback = null;
var _destinationCallback = null;
var _originationLocationId = null;
var _destinationLocationId = null;
var _civLocationPerDiemURL = null;
var _calculateAllURL = null;
var _saveProjectURL = null;
var _deleteProjectURL = null;
var _openProjectURL = null;
var _getYearListURL = null;
var _civPCSLocationsById = null;
var _amcosVersionId = null;
var _exportProjectURL = null;
var _sortProjectsURL = null;

var _pcsState = {
    InitialState: true,
    OriginationSelected: false,
    DestinationSelected: false,
    SelectLocationsAvailable: false,
    OriginationSelectLocationLoaded: false,
    DestinationSelectLocationLoaded: false,
    LocationChanged: false,
    MileageChanged: false,
    POVMileageChanged: false,
    IsIsolatedDutyStationChanged: false,
    TransDependentsChanged: false
};

$(document).ready(function () {
    _civLocationPerDiemURL = document.getElementById("CivPCSLocationsURL").value;
    _saveProjectURL = document.getElementById("CivPCSSaveProjectURL").value;
    _deleteProjectURL = document.getElementById("CivPCSDeleteProjectURL").value;
    _calculateAllURL = document.getElementById("CalculateAllURL").value;
    _civPCSLocationsById = document.getElementById("CivPCSLocationsById").value;
    _getYearListURL = document.getElementById("GetYearListURL").value;
    _amcosVersionId = document.getElementById("AmcosVersionId").value;
    _openProjectURL = document.getElementById("CivPCSOpenProjectURL").value;
    _exportProjectURL = document.getElementById("CivPCSExportURL").value;
    _sortProjectsURL = document.getElementById("CivPCSSortProjectsURL").value;
    InitializeLocation('#SourceLocation', LoadOriginationList);
    InitializeLocation('#TargetDestination', LoadDestinationList);
    DisplayTransportationPanel('Goods');
    DisplayRealEstateOrLease("RealEstate");
    let buttons = document.getElementsByName("TransportationType");
    for (let i = 0; i < 2; i++) {
        buttons[i].onclick = function () {
            DisplayTransportationPanel(this.value);
        };
    }
    let rolButtons = document.getElementsByName("RealEstateOrLease");
    for (let i = 0; i < 2; i++) {
        rolButtons[i].onclick = function () {
            DisplayRealEstateOrLease(this.value);
        };
    }
    document.getElementById('CalculatedDistance').addEventListener('change', function () {
        _pcsInputFieldValueChange = true;
        _pcsState.MileageChanged = true;
        CalculateAll();
        _pcsState.MileageChanged = false;
    });
    document.getElementById('POVMileage').addEventListener('change', function () {
        _pcsInputFieldValueChange = true;
        _pcsState.POVMileageChanged = true;
        CalculateAll();
        _pcsState.POVMileageChanged = false;
    });
    document.getElementById('HHGTotalWeight').addEventListener('change', function () {
        let maxWeight = parseFloat($("#HHGMaxWeight").text().replace(',', ''));
        if (this.value > maxWeight) {
            document.getElementById('HHGTotalWeightWarning').style.display = "inline-block";
            document.getElementById('HHGTotalWeightWarning').textContent = "The maximum weight of " + maxWeight + " will be used.";
        } else {
            document.getElementById('HHGTotalWeightWarning').style.display = "none";
        }
    });
    document.getElementById('MEASubtotal').addEventListener('change', function () {
        _pcsInputFieldValueChanged = true;
        CalculateAll();
    });
    let isolatedCheckBox = document.getElementById("IsIsolatedDutyStation");
    DisableNTSSubtotal(!isolatedCheckBox.checked);
    isolatedCheckBox.addEventListener('change', function () {
        DisableNTSSubtotal(!this.checked);
        _pcsState.IsIsolatedDutyStationChanged = true;
        _pcsInputFieldValueChanged = true;
        CalculateAll();
        _pcsState.IsIsolatedDutyStationChanged = false;
    });
    let transportationDependents = document.getElementById("TransportationDependents");
    transportationDependents.addEventListener('change', function () {
        _pcsState.TransDependentsChanged = true;
        _pcsInputFieldValueChanged = true;
        CalculateAll();
        _pcsState.TransDependentsChanged = false;
    });
    document.getElementById("Appropriation").addEventListener('change', function () {
        let yearList = document.getElementById("Year");
        let selectedYear = yearList.value;
        yearList.innerHTML = "";

        $.ajax({
            url: _getYearListURL,
            type: 'POST',
            data: {
                amcosVersionId: _amcosVersionId,
                appropriation: this.value,
                conversionType: document.getElementById('ConversionType').value
            },
            headers: {
                AntiForgeryToken: $('#AntiForgeryToken').val()
            },
            dataType: 'json',
            error: function () {
                alert("Failed to retrieve data from server.");
            },
            success: function (response) {
                let valueExists = false;
                for (let x = 0; x < response.length; x++) {
                    let option = document.createElement("option");
                    option.value = response[x].Value;
                    option.textContent = response[x].Text;
                    yearList.appendChild(option);
                    if (response[x].Value == selectedYear) { valueExists = true; }
                }
                if (valueExists) {
                    yearList.value = selectedYear;
                } else {
                    yearList.value = document.getElementById("AmcosVersionYear").textContent;
                }
                ResetBaseline();
            }
        });
    });
    document.getElementById('MEAHasSpouse').addEventListener('change', function () {
        if (this.checked) {
            document.getElementById('MEASubtotal').value = GetFormattedNumber(document.getElementById('MEACivilianAndSpouse').textContent, 2);
            document.getElementById('MEASubtotalValue').value = FormatAsNumber(document.getElementById('MEACivilianAndSpouse').textContent);
        } else {
            document.getElementById('MEASubtotal').value = GetFormattedNumber(document.getElementById('MEACivilian').textContent, 2);
            document.getElementById('MEASubtotalValue').value = FormatAsNumber(document.getElementById('MEACivilian').textContent);
        }
        _pcsInputFieldValueChanged = true;
        CalculateAll();
    });
});
function ResetBaseline() {
    _pcsState.InitialState = true;
    _pcsInputFieldValueChanged = true;
    CalculateAll();
    _pcsState.InitialState = false;
}
function SetDefaultTax() {
    document.getElementById("FederalTaxRate").value = document.getElementById("DefaultFederalTaxRate").value;
    CalculateAll();
}
function DisableNTSSubtotal(option) {
    let element = document.getElementById("NTSSubtotal");
    if (option == true) {
        element.value = "0.00";
    }
    element.disabled = option;
}
function LoadOriginationList(query, callback) {
    if (_pcsState.SelectLocationsAvailable && !_pcsState.OriginationSelectLocationLoaded) {
        _pcsState.OriginationSelectLocationLoaded = true;
        callback(_selectLocationsData);
        SetLocationId();
        return;
    }
    _originationCallback = callback;
    GetCivLocationPerDiem(_amcosVersionId, query);
    return;

}
function LoadDestinationList(query, callback) {
    if (_pcsState.SelectLocationsAvailable && !_pcsState.DestinationSelectLocationLoaded) {
        _pcsState.DestinationSelectLocationLoaded = true;
        callback(_selectLocationsData);
        SetLocationId();
        return;
    }
    _destinationCallback = callback;
    GetCivLocationPerDiem(_amcosVersionId, query);
    return;
}
function SetLocationId() {
    if (_originationLocationId && _pcsState.OriginationSelectLocationLoaded) {
        $('#SourceLocation').selectize()[0].selectize.setValue(_originationLocationId, true);
        _originationLocationId = null;
    }
    if (_destinationLocationId && _pcsState.DestinationSelectLocationLoaded) {
        $('#TargetDestination').selectize()[0].selectize.setValue(_destinationLocationId, true);
        _destinationLocationId = null;
    }
    if (_pcsState.DestinationSelectLocationLoaded && _pcsState.OriginationSelectLocationLoaded) {
        CalculateAll();
    }
}
function InitializeLocation(selectObject, loadFunction) {
    let preload = true;

    $(selectObject).selectize()[0].selectize.destroy();
    $(selectObject).selectize({
        options: [],
        create: false,
        maxItems: 1,
        //maxOptions: 1000,
        selectOnTab: true,
        optgroups: [
            { $order: 1, value: 'Zip', label: 'Zip' },
            { $order: 2, value: 'Civilian Overseas', label: 'Civilian Overseas' }
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
            //Set flag for auto save
            _pcsInputFieldValueChanged = true;
            //Set flag location changed
            _pcsState.LocationChanged = true;
            _pcsState.OriginationSelected = $('#SourceLocation').val();
            _pcsState.DestinationSelected = $('#TargetDestination').val();
            //If a both source and destination locations have a value then calculate values
            if (_pcsState.OriginationSelected && _pcsState.DestinationSelected) {
                CalculateAll();
                _pcsState.InitialState = false;
            } else {
                _pcsState.InitialState = true;
            }
        },
        preload: preload,
        load: loadFunction
    });
}

function DeleteProject(projectName) {
    $("body").css("cursor", "progress");
    $.ajax({
        url: _deleteProjectURL,
        type: 'POST',
        data: { projectName: projectName, sortColumn: _viewProjectsSortColumn, sortOrder: _viewProjectsSortOrder },
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        dataType: 'json',
        error: HandleError,
        success: function (res) {

            PopulateViewProjectBody(res);
            $("body").css("cursor", "default");
        }
    });
}
function ExportToFile(projectName) {
    $("body").css("cursor", "progress");
    $.ajax({
        url: _saveProjectURL,
        type: 'POST',
        data: GetPCSData(projectName),
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        dataType: 'json',
        error: HandleError,
        success: function (res) {
            $(".pcs-project-name").text(projectName);
            window.location.href = _exportProjectURL + '?projectName=' + projectName;
            $("body").css("cursor", "default");
        }
    });
}
function GetCivLocationPerDiem(amcosVersionId, query) {
    $.ajax({
        url: _civLocationPerDiemURL,
        type: 'POST',
        data: { amcosVersionId: amcosVersionId, query: query },
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        dataType: 'json',
        error: function () {
            alert("Failed to retrieve data from server.");
        },
        success: function (res) {
            _pcsState.AllLocationsAvailable = true;
            if (_originationCallback) {
                _originationCallback(res);
            }
            if (_destinationCallback) {
                _destinationCallback(res);
            }
        }
    });
}
function GetCivPCSLocationById() {
    $.ajax({
        url: _civPCSLocationsById,
        type: 'POST',
        data: { originationId: _originationLocationId, destinationId: _destinationLocationId, amcosVersionId: _amcosVersionId },
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        dataType: 'json',
        error: function () {
            alert("Failed to fetch data from server.");
        },
        success: function (res) {
            _selectLocationsData = res;
            _pcsState.SelectLocationsAvailable = true;
            if (_originationCallback && !_pcsState.OriginationSelectLocationLoaded) {
                _pcsState.OriginationSelectLocationLoaded = true;
                _originationCallback(res);
            }
            if (_destinationCallback && !_pcsState.DestinationSelectLocationLoaded) {
                _pcsState.DestinationSelectLocationLoaded = true;
                _destinationCallback(res);
            }
            SetLocationId();
        }
    });
}
function DisplayTransportationPanel(transportationType) {
    if (transportationType == "Goods") {
        $("#house-hold-goods").show();
        $("#mobile-home-transportation").hide();
    } else {
        $("#mobile-home-transportation").show();
        $("#house-hold-goods").hide();
    }
}
function DisplayRealEstateOrLease(selectedValue) {
    if (selectedValue == "RealEstate") {
        $("#Real-Estate").show();
        $("#Unexpired-Lease").hide();
    } else {
        $("#Unexpired-Lease").show();
        $("#Real-Estate").hide();
    }
}
function OpenProject(projectName) {
    $("body").css("cursor", "progress");
    $.ajax({
        url: _openProjectURL,
        type: 'POST',
        data: { projectName: projectName },
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        dataType: 'json',
        error: HandleError,
        success: function (res) {
            //Populate the dropdowns with the location data.
            SetPCSValues(res);
            _pcsState.OriginationSelectLocationLoaded = false;
            _pcsState.DestinationSelectLocationLoaded = false;
            _pcsState.SelectLocationsAvailable = false;
            _pcsState.InitialState = false;
            _destinationLocationId = res.DestinationId;
            _originationLocationId = res.OriginationId;
            GetCivPCSLocationById();            
        }
    });
}
function CalculateAll() {
    $("body").css("cursor", "progress");
    $.ajax({
        url: _calculateAllURL,
        type: 'POST',
        data: GetPCSData(),
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        dataType: 'json',
        error: HandleError,
        success: SetPCSValues

    });
}
function SavePCSContentAction(projectName) {
    $.ajax({
        url: _saveProjectURL,
        type: 'POST',
        data: GetPCSData(projectName),
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        dataType: 'json',
        error: HandleError,
        success: function (res) {
            $(".pcs-project-name").text(projectName);
            PopulateViewProjectBody(res); //In pcs-common.js
        }
    });
}
function HandleError(xhr, status, err) {
    console.log(xhr.responseJSON + ":  " + status + "  " + err);
    $("body").css("cursor", "default");    
}
function GetPCSData(projectName) {
    return {
        ProjectName: projectName,
        ViewProjectsSortColumn: _viewProjectsSortColumn,
        ViewProjectsSortOrder: _viewProjectsSortOrder,
        AmcosVersionId: _amcosVersionId,
        LocationChanged: _pcsState.LocationChanged,
        InitialState: _pcsState.InitialState,
        TransDependentsChanged: _pcsState.TransDependentsChanged,
        POVMileageChanged: _pcsState.POVMileageChanged,
        ValueChangedElementId: _valueChangedElementId,
        MileageChanged: _pcsState.MileageChanged,
        /*** Mileage ***/
        OriginationId: document.getElementById('SourceLocation').value,
        DestinationId: document.getElementById('TargetDestination').value,
        CalculatedDistance: FormatAsNumber(document.getElementById('CalculatedDistance').value),
        Year: FormatAsNumber(document.getElementById('Year').value),
        Appropriation: document.getElementById('Appropriation').value,
        ConversionType: document.getElementById('ConversionType').value,
        /*** House Hunting ***/
        NumberOfDaysHunting: FormatAsNumber(document.getElementById('NumberOfDaysHunting').value),
        HouseHuntingHaveSpouse: $('#HouseHuntingHaveSpouse').prop("checked"),
        /*** Transportation ***/
        POVMileage: FormatAsNumber($('#POVMileage').val()),
        TransportationDependents: FormatAsNumber($('#TransportationDependents').val()),
        TransportationSubTotal: FormatAsNumber($('#TransportationSubTotal').val()),
        /*** TQSE ***/
        NumberDaysTQSE: FormatAsNumber($('#NumberDaysTQSE').val()),
        TQSEDependents: FormatAsNumber($('#TQSEDependents').val()),
        /*** HHG / Mobile Home ***/
        TransportationType: document.querySelector('input[name="TransportationType"]:checked').value,
        HHGTotalMileage: FormatAsNumber($('#HHGTotalMileage').val()),
        HHGTotalWeight: FormatAsNumber($('#HHGTotalWeight').val()),
        HHGEstimatedCostPerMile: FormatAsNumber($('#HHGEstimatedCostPerMile').val()),
        HHGEstimatedCostPerPound: FormatAsNumber($('#HHGEstimatedCostPerPound').val()),
        MobileHomeTotalMileage: FormatAsNumber($('#MobileHomeTotalMileage').val()),
        MobileHomeEstCostPerMile: FormatAsNumber($('#MobileHomeEstCostPerMile').val()),
        /*** Misc Expenses ***/
        MEASubtotal: FormatAsNumber($('#MEASubtotal').val()),
        MEAHasSpouse: $('#MEAHasSpouse').prop('checked'),
        /*** Real Estate / Lease ***/
        RealEstateOrLease: document.querySelector('input[name="RealEstateOrLease"]:checked').value,
        SalePriceRefund: FormatAsNumber($('#SalePriceRefund').val()),
        SalePriceAmount: FormatAsNumber($('#SalePriceAmount').val()),
        PurchasePriceRefund: FormatAsNumber($('#PurchasePriceRefund').val()),
        PurchasePriceAmount: FormatAsNumber($('#PurchasePriceAmount').val()),
        UELAmount: FormatAsNumber($('#UELAmount').val()),
        /*** NTS ***/
        IsIsolatedDutyStation: $('#IsIsolatedDutyStation').prop("checked"),
        IsIsolatedDutyStationChanged: _pcsState.IsIsolatedDutyStationChanged,
        NTSSubtotal: FormatAsNumber($('#NTSSubtotal').val()),
        /*** RITA ***/
        FederalTaxRate: FormatAsNumber($('#FederalTaxRate').val()),
        MedicareTaxRate: FormatAsNumber($('#MedicareTaxRate').val()),
        SocialSecurityTaxRate: FormatAsNumber($('#SocialSecurityTaxRate').val()),
        StateTaxRate: FormatAsNumber($('#StateTaxRate').val()),
        CountyTaxRate: FormatAsNumber($('#CountyTaxRate').val()),
        CityTaxRate: FormatAsNumber($('#CityTaxRate').val()),
    };
}
function SetPCSValues(res) {
    //reset the antiforgery token
    if (res.AntiForgeryToken) {
        document.getElementById("AntiForgeryToken").value = res.AntiForgeryToken;
    }    
    if (res.ProjectName) {
        $(".pcs-project-name").text(res.ProjectName);
    }
    $('#SourceLocation').selectize()[0].selectize.setValue(res.OriginationId, true);
    $('#TargetDestination').selectize()[0].selectize.setValue(res.DestinationId, true);
    document.getElementById('Year').value = res.Year;
    document.getElementById('Appropriation').value = res.Appropriation;
    document.getElementById('ConversionType').value = res.ConversionType;
    $('#CalculatedDistance').val(GetFormattedNumber(res.CalculatedDistance, 0));
    $('#JicInflationRate').text(GetFormattedNumber(res.JicInflationRate, 6));
    /*** House Hunting ***/
    document.getElementById('NumberOfDaysHunting').value = GetFormattedNumber(res.NumberOfDaysHunting, 0);
    $('#HouseHuntingHaveSpouse').prop("checked", res.HouseHuntingHaveSpouse);
    $('#SelfLodgingPerDiem').text('$' + GetFormattedNumber(res.SelfLodgingPerDiem, 2));
    $('#SelfMIEPerDiem').text('$' + GetFormattedNumber(res.SelfMIEPerDiem, 2));
    $('#SpouseLodgingPerDiem').text('$' + GetFormattedNumber(res.SpouseLodgingPerDiem, 2));
    $('#SpouseMIEPerDiem').text('$' + GetFormattedNumber(res.SpouseMIEPerDiem, 2));
    $('#HouseHuntingTotalCell').text('$' + GetFormattedNumber(res.HouseHuntingTotal, 2));
    $('#HouseHuntingTotal').val(res.HouseHuntingTotal);
    $('#SelfPerDiemRate').text(parseFloat(res.SelfPerDiemRate) * 100);
    /*** Transportation ***/
    $('#POVMileage').val(GetFormattedNumber(res.POVMileage, 0));
    $('#TransportationDependents').val(res.TransportationDependents);
    $('#PCSMaltRate').text(GetFormattedNumber(res.PCSMaltRate, 2));
    $('#TransportationVersionYear').text(res.TransportationVersionYear);
    $('#MileageReimbursement').text('$' + GetFormattedNumber(res.MileageReimbursement, 2));
    $('#DependantMileageReimbursement').text('$' + GetFormattedNumber(res.DependantMileageReimbursement, 2));
    $('#TransportationSubTotal').val(GetFormattedNumber(res.TransportationSubTotal, 2));
    $('#TransportationSubTotalValue').val(res.TransportationSubTotal);
    /*** TQSE ***/
    $('#NumberDaysTQSE').val(GetFormattedNumber(res.NumberDaysTQSE, 0));
    $('#TQSEDependents').val(res.TQSEDependents);
    $('#TQSESelfPerDiemLodging').text('$' + GetFormattedNumber(res.TQSESelfPerDiemLodging, 2));
    $('#TQSESpousePerDiemLodging').text('$' + GetFormattedNumber(res.TQSESpousePerDiemLodging, 2));
    $('#TQSESelfPerDiemMIE').text('$' + GetFormattedNumber(res.TQSESelfPerDiemMIE, 2));
    $('#TQSESpousePerDiemMIE').text('$' + GetFormattedNumber(res.TQSESpousePerDiemMIE, 2));
    $('#TQSETotal').val(res.TQSETotal);
    $('#TQSETotalValue').text('$' + GetFormattedNumber(res.TQSETotal, 2));
    $('#TQSEPerDiemRate').text(GetFormattedNumber(res.TQSEPerDiemRate, 2));
    $('#TQSESpousePerDiemRate').text(GetFormattedNumber(res.TQSESpousePerDiemRate, 2));
    /*** Goods Home Transporation ***/
    $('input[name="TransportationType"][value="' + res.TransportationType + '"]').prop("checked", true);
    $('#GHTransportationTotal').val(res.GHTransportationTotal);
    $('#HHGTotalMileage').val(GetFormattedNumber(res.HHGTotalMileage, 0));
    $('#HHGTotalWeight').val(GetFormattedNumber(res.HHGTotalWeight, 0));
    $('#HHGMaxWeight').text(res.HHGMaxWeight.toLocaleString());
    $('#HHGEstimatedCostPerMile').val(GetFormattedNumber(res.HHGEstimatedCostPerMile, 2));
    $('#HHGEstimatedCostPerMileValue').text(GetFormattedNumber(res.HHGEstimatedCostPerMile, 2));
    $('#HHGEstimatedCostPerPound').val(GetFormattedNumber(res.HHGEstimatedCostPerPound, 2));
    $('#HHGEstimatedCostPerPoundValue').text(GetFormattedNumber(res.HHGEstimatedCostPerPound, 2));
    $('#HHGCostByTotalMiles').text('$' + GetFormattedNumber(res.HHGCostByTotalMiles, 2));
    $('#HHGCostByTotalWeight').text('$' + GetFormattedNumber(res.HHGCostByTotalWeight, 2));
    $('#SubtotalHHG').text('$' + GetFormattedNumber(res.SubtotalHHG, 2));
    $('#MobileHomeTotalMileage').val(GetFormattedNumber(res.MobileHomeTotalMileage, 0));
    $('#MobileHomeEstCostPerMile').val(GetFormattedNumber(res.MobileHomeEstCostPerMile, 2));
    $('#MobileHomeEstCostPerMileValue').text(GetFormattedNumber(res.MobileHomeEstCostPerMile, 2));
    $('#MobileHomeSubtotal').text('$' + GetFormattedNumber(res.MobileHomeSubtotal, 2));
    /*** MEA ***/
    $('#MEACivilian').text(GetFormattedNumber(res.MEACivilian, 2));
    $('#MEACivilianAndSpouse').text(GetFormattedNumber(res.MEACivilianAndSpouse, 2));
    $('#MEASubtotal').val(GetFormattedNumber(res.MEASubtotal, 2));
    $('#MEASubtotalValue').val(res.MEASubtotal);
    $('#MEAHasSpouse').prop('checked', res.MEAHasSpouse);
    /*** Real Estate / Lease ***/
    $('input[name="RealEstateOrLease"][value="' + res.RealEstateOrLease + '"]').prop("checked", true);
    $('#SalePriceAmount').val(GetFormattedNumber(res.SalePriceAmount, 2));
    $('#SalePriceRefund').val(res.SalePriceRefund);
    $('#PurchasePriceAmount').val(GetFormattedNumber(res.PurchasePriceAmount, 2));
    $('#PurchasePriceRefund').val(res.PurchasePriceRefund);
    $('#RealEstateSubtotalValue').text('$' + GetFormattedNumber(res.RealEstateSubtotal, 2));
    $('#UELAmount').val(GetFormattedNumber(res.UELAmount, 2));
    $('#UELTotalValue').text('$' + GetFormattedNumber(res.UELTotal, 2));
    $('#RealEstateLeaseTotal').val(res.RealEstateLeaseTotal);
    /*** NTS ***/
    $('#IsIsolatedDutyStation').prop("checked", res.IsIsolatedDutyStation);
    $('#NTSSubtotal').val(GetFormattedNumber(res.NTSSubtotal, 2));
    $('#NTSSubtotalValue').val(res.NTSSubtotal);
    /*** RITA ***/
    $("[name='DefaultFederalTaxRate']").val(GetFormattedNumber(res.DefaultFederalTaxRate, 2));
    $('#FederalTaxRate').val(GetFormattedNumber(res.FederalTaxRate, 2));
    $('#SocialSecurityTaxRate').val(GetFormattedNumber(res.SocialSecurityTaxRate, 2));
    $('#MedicareTaxRate').val(GetFormattedNumber(res.MedicareTaxRate, 2));
    $('#StateTaxRate').val(GetFormattedNumber(res.StateTaxRate, 2));
    $('#CountyTaxRate').val(GetFormattedNumber(res.CountyTaxRate, 2));
    $('#CityTaxRate').val(GetFormattedNumber(res.CityTaxRate, 2));
    $('#TotalTaxRate').text(GetFormattedNumber(res.TotalTaxRate, 2));
    $("[name='TaxBracketLabel']").text(GetFormattedNumber(res.TotalTaxRate / 100, 4));
    $('#RITASubtotal').val(res.RITASubtotal);
    $('#RITASubtotalValue').text('$' + GetFormattedNumber(res.RITASubtotal, 2));
    $('#HouseHuntingTotalLabel').text(GetFormattedNumber(res.HouseHuntingTotal, 2));
    $('#HouseHuntingRITA').text(GetFormattedNumber(res.HouseHuntingRITA, 2));
    $('#TransportationSubTotalLabel').text(GetFormattedNumber(res.TransportationSubTotal, 2));
    $('#TransportationRITA').text(GetFormattedNumber(res.TransportationRITA, 2));
    $('#TQSESubtotalLabel').text(GetFormattedNumber(res.TQSETotal, 2));
    $('#TQSERITA').text(GetFormattedNumber(res.TQSERITA, 2));
    $('#GHTransportationTotalLabel').text(GetFormattedNumber(res.GHTransportationTotal, 2));
    $('#GHTransportationRITA').text(GetFormattedNumber(res.GHTransportationRITA, 2));
    $('#MEASubtotalLabel').text(GetFormattedNumber(res.MEASubtotal, 2));
    $('#MEARITA').text(GetFormattedNumber(res.MEARITA, 2));
    $('#RealEstateLeaseTotalLabel').text(GetFormattedNumber(res.RealEstateLeaseTotal, 2));
    $('#RealEstateLeaseRITA').text(GetFormattedNumber(res.RealEstateLeaseRITA, 2));
    $('#NTSSubtotalLabel').text(GetFormattedNumber(res.NTSSubtotal, 2));
    $('#NTSRITA').text(GetFormattedNumber(res.NTSRITA, 2));
    /*** Grand Total ***/
    $("#HouseHuntingSummarySubtotal").text('$' + GetFormattedNumber(res.HouseHuntingTotal, 2));
    $("#TransportationSummarySubtotal").text('$' + GetFormattedNumber(res.TransportationSubTotal, 2));
    $("#TQSESummarySubtotal").text('$' + GetFormattedNumber(res.TQSETotal, 2));
    $("#GHTransportationSummarySubtotal").text('$' + GetFormattedNumber(res.GHTransportationTotal, 2));
    $("#MEASummarySubtotal").text('$' + GetFormattedNumber(res.MEASubtotal, 2));
    $("#RealEstateLeaseSummarySubtotal").text('$' + GetFormattedNumber(res.RealEstateLeaseTotal, 2));
    $("#NTSSummarySubtotal").text('$' + GetFormattedNumber(res.NTSSubtotal, 2));
    $("#RITASummarySubtotal").text('$' + GetFormattedNumber(res.RITASubtotal, 2));
    $("#GrandTotal").text('$' + GetFormattedNumber(res.GrandTotal, 2));
    LoadSummaryTable();

    //Reset change notification pcsState flags
    _pcsState.LocationChanged = false;
    _pcsState.IsIsolatedDutyStationChanged = false;
    //Set cursor back to default
    $("body").css("cursor", "default");
}



