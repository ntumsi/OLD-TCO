"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CivPCS = void 0;
var pcs_common_js_1 = require("../js/pcs-common.js");
var _civPCS;
$(document).ready(function () {
    _civPCS = new CivPCS();
    var buttons = document.getElementsByName("TransportationType");
    for (var i = 0; i < 2; i++) {
        buttons[i].onclick = function () {
            _civPCS.DisplayTransportationPanel(this.value);
        };
    }
    var rolButtons = document.getElementsByName("RealEstateOrLease");
    for (var i = 0; i < 2; i++) {
        rolButtons[i].onclick = function () {
            _civPCS.DisplayRealEstateOrLease(this.value);
        };
    }
    document.getElementById('CalculatedDistance').addEventListener('change', function () {
        pcs_common_js_1.PCS._pcsInputFieldValueChange = true;
        _civPCS._pcsState.MileageChanged = true;
        _civPCS.CalculateAll();
        _civPCS._pcsState.MileageChanged = false;
    });
    document.getElementById('POVMileage').addEventListener('change', function () {
        pcs_common_js_1.PCS._pcsInputFieldValueChange = true;
        _civPCS._pcsState.POVMileageChanged = true;
        _civPCS.CalculateAll();
        _civPCS._pcsState.POVMileageChanged = false;
    });
    document.getElementById('HHGTotalWeight').addEventListener('change', function () {
        var maxWeight = parseFloat($("#HHGMaxWeight").text().replace(',', ''));
        if (parseFloat(this.value) > maxWeight) {
            document.getElementById('HHGTotalWeightWarning').style.display = "inline-block";
            document.getElementById('HHGTotalWeightWarning').textContent = "The maximum weight of " + maxWeight + " will be used.";
        }
        else {
            document.getElementById('HHGTotalWeightWarning').style.display = "none";
        }
    });
    document.getElementById('MEASubtotal').addEventListener('change', function () {
        pcs_common_js_1.PCS._pcsInputFieldValueChanged = true;
        _civPCS.CalculateAll();
    });
    var isolatedCheckBox = document.getElementById("IsIsolatedDutyStation");
    _civPCS.DisableNTSSubtotal(!isolatedCheckBox.checked);
    isolatedCheckBox.addEventListener('change', function () {
        _civPCS.DisableNTSSubtotal(!this.checked);
        _civPCS._pcsState.IsIsolatedDutyStationChanged = true;
        pcs_common_js_1.PCS._pcsInputFieldValueChanged = true;
        _civPCS.CalculateAll();
        _civPCS._pcsState.IsIsolatedDutyStationChanged = false;
    });
    var transportationDependents = document.getElementById("TransportationDependents");
    transportationDependents.addEventListener('change', function () {
        _civPCS._pcsState.TransDependentsChanged = true;
        pcs_common_js_1.PCS._pcsInputFieldValueChanged = true;
        _civPCS.CalculateAll();
        _civPCS._pcsState.TransDependentsChanged = false;
    });
    document.getElementById("Appropriation").addEventListener('change', function () {
        var yearList = document.getElementById("Year");
        var selectedYear = yearList.value;
        yearList.innerHTML = "";
        $.ajax({
            url: _civPCS._getYearListURL,
            type: 'POST',
            data: {
                amcosVersionId: _civPCS._amcosVersionId,
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
                var valueExists = false;
                for (var x = 0; x < response.length; x++) {
                    var option = document.createElement("option");
                    option.value = response[x].Value;
                    option.textContent = response[x].Text;
                    yearList.appendChild(option);
                    if (response[x].Value == selectedYear) {
                        valueExists = true;
                    }
                }
                if (valueExists) {
                    yearList.value = selectedYear;
                }
                else {
                    yearList.value = document.getElementById("AmcosVersionYear").textContent;
                }
                _civPCS.ResetBaseline();
            }
        });
    });
    document.getElementById('MEAHasSpouse').addEventListener('change', function () {
        if (this.checked) {
            document.getElementById('MEASubtotal').value = pcs_common_js_1.PCS.GetFormattedNumber(document.getElementById('MEACivilianAndSpouse').textContent, 2);
            document.getElementById('MEASubtotalValue').value = pcs_common_js_1.PCS.FormatAsNumber(document.getElementById('MEACivilianAndSpouse').textContent);
        }
        else {
            document.getElementById('MEASubtotal').value = pcs_common_js_1.PCS.GetFormattedNumber(document.getElementById('MEACivilian').textContent, 2);
            document.getElementById('MEASubtotalValue').value = pcs_common_js_1.PCS.FormatAsNumber(document.getElementById('MEACivilian').textContent);
        }
        pcs_common_js_1.PCS._pcsInputFieldValueChanged = true;
        _civPCS.CalculateAll();
    });
});
var CivPCS = /** @class */ (function () {
    function CivPCS() {
        this._selectLocationsData = null;
        this._originationCallback = null;
        this._destinationCallback = null;
        this._originationLocationId = null;
        this._destinationLocationId = null;
        this._pcsState = {
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
        this._civLocationPerDiemURL = document.getElementById("CivPCSLocationsURL").value;
        this._saveProjectURL = document.getElementById("CivPCSSaveProjectURL").value;
        this._deleteProjectURL = document.getElementById("CivPCSDeleteProjectURL").value;
        this._calculateAllURL = document.getElementById("CalculateAllURL").value;
        this._civPCSLocationsById = document.getElementById("CivPCSLocationsById").value;
        this._getYearListURL = document.getElementById("GetYearListURL").value;
        this._amcosVersionId = parseInt(document.getElementById("AmcosVersionId").value);
        this._openProjectURL = document.getElementById("CivPCSOpenProjectURL").value;
        this._exportProjectURL = document.getElementById("CivPCSExportURL").value;
        this._sortProjectsURL = document.getElementById("CivPCSSortProjectsURL").value;
        this.InitializeLocation('#SourceLocation', this.LoadOriginationList);
        this.InitializeLocation('#TargetDestination', this.LoadDestinationList);
        this.DisplayTransportationPanel('Goods');
        this.DisplayRealEstateOrLease("RealEstate");
    }
    CivPCS.prototype.ResetBaseline = function () {
        this._pcsState.InitialState = true;
        pcs_common_js_1.PCS._pcsInputFieldValueChanged = true;
        this.CalculateAll();
        this._pcsState.InitialState = false;
    };
    CivPCS.prototype.SetDefaultTax = function () {
        document.getElementById("FederalTaxRate").value = document.getElementById("DefaultFederalTaxRate").value;
        this.CalculateAll();
    };
    CivPCS.prototype.DisableNTSSubtotal = function (option) {
        var element = document.getElementById("NTSSubtotal");
        if (option == true) {
            element.value = "0.00";
        }
        element.disabled = option;
    };
    CivPCS.prototype.LoadOriginationList = function (query, callback) {
        if (this._pcsState.SelectLocationsAvailable && !this._pcsState.OriginationSelectLocationLoaded) {
            this._pcsState.OriginationSelectLocationLoaded = true;
            callback(this._selectLocationsData);
            this.SetLocationId();
            return;
        }
        this._originationCallback = callback;
        this.GetCivLocationPerDiem(this._amcosVersionId, query);
        return;
    };
    CivPCS.prototype.LoadDestinationList = function (query, callback) {
        if (this._pcsState.SelectLocationsAvailable && !this._pcsState.DestinationSelectLocationLoaded) {
            this._pcsState.DestinationSelectLocationLoaded = true;
            callback(this._selectLocationsData);
            this.SetLocationId();
            return;
        }
        this._destinationCallback = callback;
        this.GetCivLocationPerDiem(this._amcosVersionId, query);
        return;
    };
    CivPCS.prototype.SetLocationId = function () {
        if (this._originationLocationId && this._pcsState.OriginationSelectLocationLoaded) {
            $('#SourceLocation').selectize()[0].selectize.setValue(this._originationLocationId, true);
            this._originationLocationId = null;
        }
        if (this._destinationLocationId && this._pcsState.DestinationSelectLocationLoaded) {
            $('#TargetDestination').selectize()[0].selectize.setValue(this._destinationLocationId, true);
            this._destinationLocationId = null;
        }
        if (this._pcsState.DestinationSelectLocationLoaded && this._pcsState.OriginationSelectLocationLoaded) {
            this.CalculateAll();
        }
    };
    CivPCS.prototype.InitializeLocation = function (selectObject, loadFunction) {
        var preload = true;
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
                pcs_common_js_1.PCS._pcsInputFieldValueChanged = true;
                //Set flag location changed
                this._pcsState.LocationChanged = true;
                this._pcsState.OriginationSelected = $('#SourceLocation').val();
                this._pcsState.DestinationSelected = $('#TargetDestination').val();
                //If a both source and destination locations have a value then calculate values
                if (this._pcsState.OriginationSelected && this._pcsState.DestinationSelected) {
                    this.CalculateAll();
                    this._pcsState.InitialState = false;
                }
                else {
                    this._pcsState.InitialState = true;
                }
            },
            preload: preload,
            load: loadFunction
        });
    };
    CivPCS.prototype.DeleteProject = function (projectName) {
        $("body").css("cursor", "progress");
        $.ajax({
            url: this._deleteProjectURL,
            type: 'POST',
            data: { projectName: projectName, sortColumn: pcs_common_js_1.PCS._viewProjectsSortColumn, sortOrder: pcs_common_js_1.PCS._viewProjectsSortOrder },
            headers: {
                AntiForgeryToken: $('#AntiForgeryToken').val()
            },
            dataType: 'json',
            error: this.HandleError,
            success: function (res) {
                pcs_common_js_1.PCS.PopulateViewProjectBody(res);
                $("body").css("cursor", "default");
            }
        });
    };
    CivPCS.prototype.ExportToFile = function (projectName) {
        $("body").css("cursor", "progress");
        $.ajax({
            url: this._saveProjectURL,
            type: 'POST',
            data: this.GetPCSData(projectName),
            headers: {
                AntiForgeryToken: $('#AntiForgeryToken').val()
            },
            dataType: 'json',
            error: this.HandleError,
            success: function (res) {
                $(".pcs-project-name").text(projectName);
                window.location.href = this._exportProjectURL + '?projectName=' + projectName;
                $("body").css("cursor", "default");
            }
        });
    };
    CivPCS.prototype.GetCivLocationPerDiem = function (amcosVersionId, query) {
        $.ajax({
            url: this._civLocationPerDiemURL,
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
                this._pcsState.AllLocationsAvailable = true;
                if (this._originationCallback) {
                    this._originationCallback(res);
                }
                if (this._destinationCallback) {
                    this._destinationCallback(res);
                }
            }
        });
    };
    CivPCS.prototype.GetCivPCSLocationById = function () {
        $.ajax({
            url: this._civPCSLocationsById,
            type: 'POST',
            data: { originationId: this._originationLocationId, destinationId: this._destinationLocationId, amcosVersionId: this._amcosVersionId },
            headers: {
                AntiForgeryToken: $('#AntiForgeryToken').val()
            },
            dataType: 'json',
            error: function () {
                alert("Failed to fetch data from server.");
            },
            success: function (res) {
                this._selectLocationsData = res;
                this._pcsState.SelectLocationsAvailable = true;
                if (this._originationCallback && !this._pcsState.OriginationSelectLocationLoaded) {
                    this._pcsState.OriginationSelectLocationLoaded = true;
                    this._originationCallback(res);
                }
                if (this._destinationCallback && !this._pcsState.DestinationSelectLocationLoaded) {
                    this._pcsState.DestinationSelectLocationLoaded = true;
                    this._destinationCallback(res);
                }
                this.SetLocationId();
            }
        });
    };
    CivPCS.prototype.DisplayTransportationPanel = function (transportationType) {
        if (transportationType == "Goods") {
            $("#house-hold-goods").show();
            $("#mobile-home-transportation").hide();
        }
        else {
            $("#mobile-home-transportation").show();
            $("#house-hold-goods").hide();
        }
    };
    CivPCS.prototype.DisplayRealEstateOrLease = function (selectedValue) {
        if (selectedValue == "RealEstate") {
            $("#Real-Estate").show();
            $("#Unexpired-Lease").hide();
        }
        else {
            $("#Unexpired-Lease").show();
            $("#Real-Estate").hide();
        }
    };
    CivPCS.prototype.OpenProject = function (projectName) {
        $("body").css("cursor", "progress");
        $.ajax({
            url: this._openProjectURL,
            type: 'POST',
            data: { projectName: projectName },
            headers: {
                AntiForgeryToken: $('#AntiForgeryToken').val()
            },
            dataType: 'json',
            error: this.HandleError,
            success: function (res) {
                //Populate the dropdowns with the location data.
                this.SetPCSValues(res);
                this._pcsState.OriginationSelectLocationLoaded = false;
                this._pcsState.DestinationSelectLocationLoaded = false;
                this._pcsState.SelectLocationsAvailable = false;
                this._destinationLocationId = res.DestinationId;
                this._originationLocationId = res.OriginationId;
                this.GetCivPCSLocationById();
            }
        });
    };
    CivPCS.prototype.CalculateAll = function () {
        $("body").css("cursor", "progress");
        $.ajax({
            url: this._calculateAllURL,
            type: 'POST',
            data: this.GetPCSData(),
            headers: {
                AntiForgeryToken: $('#AntiForgeryToken').val()
            },
            dataType: 'json',
            error: this.HandleError,
            success: this.SetPCSValues
        });
    };
    CivPCS.prototype.SavePCSContentAction = function (projectName) {
        $.ajax({
            url: this._saveProjectURL,
            type: 'POST',
            data: this.GetPCSData(projectName),
            headers: {
                AntiForgeryToken: $('#AntiForgeryToken').val()
            },
            dataType: 'json',
            error: this.HandleError,
            success: function (res) {
                $(".pcs-project-name").text(projectName);
                pcs_common_js_1.PCS.PopulateViewProjectBody(res); //In pcs-common.js
            }
        });
    };
    CivPCS.prototype.HandleError = function (xhr, status, err) {
        console.log(xhr.responseJSON + ":  " + status + "  " + err);
        $("body").css("cursor", "default");
    };
    CivPCS.prototype.GetPCSData = function (projectName) {
        if (projectName === void 0) { projectName = null; }
        return {
            ProjectName: projectName,
            ViewProjectsSortColumn: pcs_common_js_1.PCS._viewProjectsSortColumn,
            ViewProjectsSortOrder: pcs_common_js_1.PCS._viewProjectsSortOrder,
            AmcosVersionId: this._amcosVersionId,
            LocationChanged: this._pcsState.LocationChanged,
            InitialState: this._pcsState.InitialState,
            TransDependentsChanged: this._pcsState.TransDependentsChanged,
            POVMileageChanged: this._pcsState.POVMileageChanged,
            ValueChangedElementId: pcs_common_js_1.PCS._valueChangedElementId,
            MileageChanged: this._pcsState.MileageChanged,
            /*** Mileage ***/
            OriginationId: document.getElementById('SourceLocation').value,
            DestinationId: document.getElementById('TargetDestination').value,
            CalculatedDistance: pcs_common_js_1.PCS.FormatAsNumber(document.getElementById('CalculatedDistance').value),
            Year: pcs_common_js_1.PCS.FormatAsNumber(document.getElementById('Year').value),
            Appropriation: document.getElementById('Appropriation').value,
            ConversionType: document.getElementById('ConversionType').value,
            /*** House Hunting ***/
            NumberOfDaysHunting: pcs_common_js_1.PCS.FormatAsNumber(document.getElementById('NumberOfDaysHunting').value),
            HouseHuntingHaveSpouse: $('#HouseHuntingHaveSpouse').prop("checked"),
            /*** Transportation ***/
            POVMileage: pcs_common_js_1.PCS.FormatAsNumber($('#POVMileage').val()),
            TransportationDependents: pcs_common_js_1.PCS.FormatAsNumber($('#TransportationDependents').val()),
            TransportationSubTotal: pcs_common_js_1.PCS.FormatAsNumber($('#TransportationSubTotal').val()),
            /*** TQSE ***/
            NumberDaysTQSE: pcs_common_js_1.PCS.FormatAsNumber($('#NumberDaysTQSE').val()),
            TQSEDependents: pcs_common_js_1.PCS.FormatAsNumber($('#TQSEDependents').val()),
            /*** HHG / Mobile Home ***/
            TransportationType: document.querySelector('input[name="TransportationType"]:checked').value,
            HHGTotalMileage: pcs_common_js_1.PCS.FormatAsNumber($('#HHGTotalMileage').val()),
            HHGTotalWeight: pcs_common_js_1.PCS.FormatAsNumber($('#HHGTotalWeight').val()),
            HHGEstimatedCostPerMile: pcs_common_js_1.PCS.FormatAsNumber($('#HHGEstimatedCostPerMile').val()),
            HHGEstimatedCostPerPound: pcs_common_js_1.PCS.FormatAsNumber($('#HHGEstimatedCostPerPound').val()),
            MobileHomeTotalMileage: pcs_common_js_1.PCS.FormatAsNumber($('#MobileHomeTotalMileage').val()),
            MobileHomeEstCostPerMile: pcs_common_js_1.PCS.FormatAsNumber($('#MobileHomeEstCostPerMile').val()),
            /*** Misc Expenses ***/
            MEASubtotal: pcs_common_js_1.PCS.FormatAsNumber($('#MEASubtotal').val()),
            MEAHasSpouse: $('#MEAHasSpouse').prop('checked'),
            /*** Real Estate / Lease ***/
            RealEstateOrLease: document.querySelector('input[name="RealEstateOrLease"]:checked').value,
            SalePriceAmount: pcs_common_js_1.PCS.FormatAsNumber($('#SalePriceAmount').val()),
            SalePriceRefund: pcs_common_js_1.PCS.FormatAsNumber($('#SalePriceRefund').val()),
            PurchasePriceAmount: pcs_common_js_1.PCS.FormatAsNumber($('#PurchasePriceAmount').val()),
            PurchasePriceRefund: pcs_common_js_1.PCS.FormatAsNumber($('#PurchasePriceRefund').val()),
            UELAmount: pcs_common_js_1.PCS.FormatAsNumber($('#UELAmount').val()),
            /*** NTS ***/
            IsIsolatedDutyStation: $('#IsIsolatedDutyStation').prop("checked"),
            IsIsolatedDutyStationChanged: this._pcsState.IsIsolatedDutyStationChanged,
            NTSSubtotal: pcs_common_js_1.PCS.FormatAsNumber($('#NTSSubtotal').val()),
            /*** RITA ***/
            FederalTaxRate: pcs_common_js_1.PCS.FormatAsNumber($('#FederalTaxRate').val()),
            MedicareTaxRate: pcs_common_js_1.PCS.FormatAsNumber($('#MedicareTaxRate').val()),
            SocialSecurityTaxRate: pcs_common_js_1.PCS.FormatAsNumber($('#SocialSecurityTaxRate').val()),
            StateTaxRate: pcs_common_js_1.PCS.FormatAsNumber($('#StateTaxRate').val()),
            CountyTaxRate: pcs_common_js_1.PCS.FormatAsNumber($('#CountyTaxRate').val()),
            CityTaxRate: pcs_common_js_1.PCS.FormatAsNumber($('#CityTaxRate').val()),
        };
    };
    CivPCS.prototype.SetPCSValues = function (res) {
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
        $('#CalculatedDistance').val(pcs_common_js_1.PCS.GetFormattedNumber(res.CalculatedDistance, 0));
        $('#JicInflationRate').text(pcs_common_js_1.PCS.GetFormattedNumber(res.JicInflationRate, 6));
        /*** House Hunting ***/
        document.getElementById('NumberOfDaysHunting').value = pcs_common_js_1.PCS.GetFormattedNumber(res.NumberOfDaysHunting, 0);
        $('#HouseHuntingHaveSpouse').prop("checked", res.HouseHuntingHaveSpouse);
        $('#SelfLodgingPerDiem').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.SelfLodgingPerDiem, 2));
        $('#SelfMIEPerDiem').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.SelfMIEPerDiem, 2));
        $('#SpouseLodgingPerDiem').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.SpouseLodgingPerDiem, 2));
        $('#SpouseMIEPerDiem').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.SpouseMIEPerDiem, 2));
        $('#HouseHuntingTotalCell').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.HouseHuntingTotal, 2));
        $('#HouseHuntingTotal').val(res.HouseHuntingTotal);
        $('#SelfPerDiemRate').text(parseFloat(res.SelfPerDiemRate) * 100);
        /*** Transportation ***/
        $('#POVMileage').val(pcs_common_js_1.PCS.GetFormattedNumber(res.POVMileage, 0));
        $('#TransportationDependents').val(res.TransportationDependents);
        $('#PCSMaltRate').text(pcs_common_js_1.PCS.GetFormattedNumber(res.PCSMaltRate, 2));
        $('#TransportationVersionYear').text(res.TransportationVersionYear);
        $('#MileageReimbursement').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.MileageReimbursement, 2));
        $('#DependantMileageReimbursement').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.DependantMileageReimbursement, 2));
        $('#TransportationSubTotal').val(pcs_common_js_1.PCS.GetFormattedNumber(res.TransportationSubTotal, 2));
        $('#TransportationSubTotalValue').val(res.TransportationSubTotal);
        /*** TQSE ***/
        $('#NumberDaysTQSE').val(pcs_common_js_1.PCS.GetFormattedNumber(res.NumberDaysTQSE, 0));
        $('#TQSEDependents').val(res.TQSEDependents);
        $('#TQSESelfPerDiemLodging').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.TQSESelfPerDiemLodging, 2));
        $('#TQSESpousePerDiemLodging').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.TQSESpousePerDiemLodging, 2));
        $('#TQSESelfPerDiemMIE').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.TQSESelfPerDiemMIE, 2));
        $('#TQSESpousePerDiemMIE').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.TQSESpousePerDiemMIE, 2));
        $('#TQSETotal').val(res.TQSETotal);
        $('#TQSETotalValue').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.TQSETotal, 2));
        $('#TQSEPerDiemRate').text(pcs_common_js_1.PCS.GetFormattedNumber(res.TQSEPerDiemRate, 2));
        $('#TQSESpousePerDiemRate').text(pcs_common_js_1.PCS.GetFormattedNumber(res.TQSESpousePerDiemRate, 2));
        /*** Goods Home Transporation ***/
        $('input[name="TransportationType"][value="' + res.TransportationType + '"]').prop("checked", true);
        $('#GHTransportationTotal').val(res.GHTransportationTotal);
        $('#HHGTotalMileage').val(pcs_common_js_1.PCS.GetFormattedNumber(res.HHGTotalMileage, 0));
        $('#HHGTotalWeight').val(pcs_common_js_1.PCS.GetFormattedNumber(res.HHGTotalWeight, 0));
        $('#HHGMaxWeight').text(res.HHGMaxWeight.toLocaleString());
        $('#HHGEstimatedCostPerMile').val(pcs_common_js_1.PCS.GetFormattedNumber(res.HHGEstimatedCostPerMile, 2));
        $('#HHGEstimatedCostPerMileValue').text(pcs_common_js_1.PCS.GetFormattedNumber(res.HHGEstimatedCostPerMile, 2));
        $('#HHGEstimatedCostPerPound').val(pcs_common_js_1.PCS.GetFormattedNumber(res.HHGEstimatedCostPerPound, 2));
        $('#HHGEstimatedCostPerPoundValue').text(pcs_common_js_1.PCS.GetFormattedNumber(res.HHGEstimatedCostPerPound, 2));
        $('#HHGCostByTotalMiles').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.HHGCostByTotalMiles, 2));
        $('#HHGCostByTotalWeight').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.HHGCostByTotalWeight, 2));
        $('#SubtotalHHG').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.SubtotalHHG, 2));
        $('#MobileHomeTotalMileage').val(pcs_common_js_1.PCS.GetFormattedNumber(res.MobileHomeTotalMileage, 0));
        $('#MobileHomeEstCostPerMile').val(pcs_common_js_1.PCS.GetFormattedNumber(res.MobileHomeEstCostPerMile, 2));
        $('#MobileHomeEstCostPerMileValue').text(pcs_common_js_1.PCS.GetFormattedNumber(res.MobileHomeEstCostPerMile, 2));
        $('#MobileHomeSubtotal').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.MobileHomeSubtotal, 2));
        /*** MEA ***/
        $('#MEACivilian').text(pcs_common_js_1.PCS.GetFormattedNumber(res.MEACivilian, 2));
        $('#MEACivilianAndSpouse').text(pcs_common_js_1.PCS.GetFormattedNumber(res.MEACivilianAndSpouse, 2));
        $('#MEASubtotal').val(pcs_common_js_1.PCS.GetFormattedNumber(res.MEASubtotal, 2));
        $('#MEASubtotalValue').val(res.MEASubtotal);
        $('#MEAHasSpouse').prop('checked', res.MEAHasSpouse);
        /*** Real Estate / Lease ***/
        $('input[name="RealEstateOrLease"][value="' + res.RealEstateOrLease + '"]').prop("checked", true);
        $('#SalePriceAmount').val(pcs_common_js_1.PCS.GetFormattedNumber(res.SalePriceAmount, 2));
        $('#SalePriceRefund').val(res.SalePriceRefund);
        $('#PurchasePriceAmount').val(pcs_common_js_1.PCS.GetFormattedNumber(res.PurchasePriceAmount, 2));
        $('#PurchasePriceRefund').val(res.PurchasePriceRefund);
        $('#RealEstateSubtotalValue').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.RealEstateSubtotal, 2));
        $('#UELAmount').val(pcs_common_js_1.PCS.GetFormattedNumber(res.UELAmount, 2));
        $('#UELTotalValue').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.UELTotal, 2));
        $('#RealEstateLeaseTotal').val(res.RealEstateLeaseTotal);
        /*** NTS ***/
        $('#IsIsolatedDutyStation').prop("checked", res.IsIsolatedDutyStation);
        $('#NTSSubtotal').val(pcs_common_js_1.PCS.GetFormattedNumber(res.NTSSubtotal, 2));
        $('#NTSSubtotalValue').val(res.NTSSubtotal);
        /*** RITA ***/
        $("[name='DefaultFederalTaxRate']").val(pcs_common_js_1.PCS.GetFormattedNumber(res.DefaultFederalTaxRate, 2));
        $('#FederalTaxRate').val(pcs_common_js_1.PCS.GetFormattedNumber(res.FederalTaxRate, 2));
        $('#SocialSecurityTaxRate').val(pcs_common_js_1.PCS.GetFormattedNumber(res.SocialSecurityTaxRate, 2));
        $('#MedicareTaxRate').val(pcs_common_js_1.PCS.GetFormattedNumber(res.MedicareTaxRate, 2));
        $('#StateTaxRate').val(pcs_common_js_1.PCS.GetFormattedNumber(res.StateTaxRate, 2));
        $('#CountyTaxRate').val(pcs_common_js_1.PCS.GetFormattedNumber(res.CountyTaxRate, 2));
        $('#CityTaxRate').val(pcs_common_js_1.PCS.GetFormattedNumber(res.CityTaxRate, 2));
        $('#TotalTaxRate').text(pcs_common_js_1.PCS.GetFormattedNumber(res.TotalTaxRate, 2));
        $("[name='TaxBracketLabel']").text(pcs_common_js_1.PCS.GetFormattedNumber(res.TotalTaxRate / 100, 4));
        $('#RITASubtotal').val(res.RITASubtotal);
        $('#RITASubtotalValue').text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.RITASubtotal, 2));
        $('#HouseHuntingTotalLabel').text(pcs_common_js_1.PCS.GetFormattedNumber(res.HouseHuntingTotal, 2));
        $('#HouseHuntingRITA').text(pcs_common_js_1.PCS.GetFormattedNumber(res.HouseHuntingRITA, 2));
        $('#TransportationSubTotalLabel').text(pcs_common_js_1.PCS.GetFormattedNumber(res.TransportationSubTotal, 2));
        $('#TransportationRITA').text(pcs_common_js_1.PCS.GetFormattedNumber(res.TransportationRITA, 2));
        $('#TQSESubtotalLabel').text(pcs_common_js_1.PCS.GetFormattedNumber(res.TQSETotal, 2));
        $('#TQSERITA').text(pcs_common_js_1.PCS.GetFormattedNumber(res.TQSERITA, 2));
        $('#GHTransportationTotalLabel').text(pcs_common_js_1.PCS.GetFormattedNumber(res.GHTransportationTotal, 2));
        $('#GHTransportationRITA').text(pcs_common_js_1.PCS.GetFormattedNumber(res.GHTransportationRITA, 2));
        $('#MEASubtotalLabel').text(pcs_common_js_1.PCS.GetFormattedNumber(res.MEASubtotal, 2));
        $('#MEARITA').text(pcs_common_js_1.PCS.GetFormattedNumber(res.MEARITA, 2));
        $('#RealEstateLeaseTotalLabel').text(pcs_common_js_1.PCS.GetFormattedNumber(res.RealEstateLeaseTotal, 2));
        $('#RealEstateLeaseRITA').text(pcs_common_js_1.PCS.GetFormattedNumber(res.RealEstateLeaseRITA, 2));
        $('#NTSSubtotalLabel').text(pcs_common_js_1.PCS.GetFormattedNumber(res.NTSSubtotal, 2));
        $('#NTSRITA').text(pcs_common_js_1.PCS.GetFormattedNumber(res.NTSRITA, 2));
        /*** Grand Total ***/
        $("#HouseHuntingSummarySubtotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.HouseHuntingTotal, 2));
        $("#TransportationSummarySubtotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.TransportationSubTotal, 2));
        $("#TQSESummarySubtotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.TQSETotal, 2));
        $("#GHTransportationSummarySubtotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.GHTransportationTotal, 2));
        $("#MEASummarySubtotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.MEASubtotal, 2));
        $("#RealEstateLeaseSummarySubtotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.RealEstateLeaseTotal, 2));
        $("#NTSSummarySubtotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.NTSSubtotal, 2));
        $("#RITASummarySubtotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.RITASubtotal, 2));
        $("#GrandTotal").text('$' + pcs_common_js_1.PCS.GetFormattedNumber(res.GrandTotal, 2));
        pcs_common_js_1.PCS.LoadSummaryTable();
        //Reset change notification pcsState flags
        this._pcsState.LocationChanged = false;
        this._pcsState.IsIsolatedDutyStationChanged = false;
        //Set cursor back to default
        $("body").css("cursor", "default");
    };
    return CivPCS;
}());
exports.CivPCS = CivPCS;
