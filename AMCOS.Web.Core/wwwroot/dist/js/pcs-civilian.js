"use strict";

// ── Utility functions ────────────────────────────────────────────────────────

function FormatAsNumber(val) {
    if (typeof val === "string") return parseFloat(val.replace(/,/g, "")) || 0;
    return val || 0;
}

function GetFormattedNumber(val, decimals) {
    if (typeof val === "string") val = parseFloat(val.replace(/,/g, ""));
    if (typeof val === "number")
        return val.toLocaleString("en-US", { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
    return "0";
}

// ── Global state ────────────────────────────────────────────────────────────

var _pcsInputFieldValueChanged = false;
var _viewProjectsSortColumn = "ProjectSaveDate";
var _viewProjectsSortOrder = "desc";
var _valueChangedElementId = null;

// ── Tab navigation ──────────────────────────────────────────────────────────

function PcsNextTab() {
    // The nav-links are direct <button> children of #pcs-tabs (no <li> wrappers), so advance by
    // index rather than relying on parentElement siblings.
    var links = document.querySelectorAll("#pcs-tabs .nav-link");
    for (var i = 0; i < links.length - 1; i++) {
        if (links[i].classList.contains("active")) { links[i + 1].click(); break; }
    }
}

function PcsPrevTab() {
    var links = document.querySelectorAll("#pcs-tabs .nav-link");
    for (var i = 1; i < links.length; i++) {
        if (links[i].classList.contains("active")) { links[i - 1].click(); break; }
    }
}

// ── Project list ─────────────────────────────────────────────────────────────

function PopulateViewProjectBody(data) {
    document.querySelectorAll("[name='ViewProjectBody']").forEach(function (tbody) { tbody.innerHTML = ""; });
    for (var x = 0; x < data.length; x++) {
        var row = document.createElement("tr");
        row.className = "selectable-row";
        var c1 = document.createElement("td"); c1.className = "selectable-project"; c1.textContent = data[x].Item1; row.appendChild(c1);
        var c2 = document.createElement("td"); c2.className = "selectable-project"; c2.textContent = data[x].Item2; row.appendChild(c2);
        var c3 = document.createElement("td"); c3.className = "text-end";
        var del = document.createElement("a"); del.className = "cal-row-delete"; del.title = "Delete"; del.setAttribute("value", data[x].Item1);
        del.style.cursor = "pointer"; del.textContent = "\uD83D\uDDD1";
        c3.appendChild(del); row.appendChild(c3);
        document.querySelectorAll("[name='ViewProjectBody']").forEach(function (tbody) { tbody.appendChild(row.cloneNode(true)); });
    }
    document.querySelectorAll(".cal-row-delete").forEach(function (el) {
        el.addEventListener("click", function () { _civPCS.DeleteProject(this.getAttribute("value")); });
    });
    document.querySelectorAll(".selectable-row").forEach(function (el) {
        el.addEventListener("click", function () { HandleProjectRowClick(this); });
    });
}

function HandleProjectRowClick(element) {
    if (!element) return;
    document.querySelectorAll(".selectable-row").forEach(function (r) { r.classList.remove("cal-row-selected"); });
    element.classList.add("cal-row-selected");
    var textBox = document.getElementById("SaveAsProjectName");
    if (textBox) textBox.value = GetSelectedProject("OpenProjectModel") || "";
}

function GetSelectedProject(containerId) {
    var container = document.getElementById(containerId);
    if (!container) return null;
    var selected = container.querySelector(".cal-row-selected");
    if (!selected) return null;
    var cell = selected.querySelector(".selectable-project");
    return cell ? cell.textContent.trim() : null;
}

function ViewProjectSort(columnName) {
    document.body.style.cursor = "progress";
    _viewProjectsSortColumn = columnName;
    _viewProjectsSortOrder = _viewProjectsSortOrder === "asc" ? "desc" : "asc";
    $.ajax({
        url: "?handler=SortProjects",
        type: "POST",
        data: { sortColumn: _viewProjectsSortColumn, sortOrder: _viewProjectsSortOrder },
        dataType: "json",
        error: function (xhr, status, err) { console.error(status, err); document.body.style.cursor = "default"; },
        success: function (res) {
            document.querySelectorAll(".table-view-project thead span[data-column]").forEach(function (s) {
                if (s.getAttribute("data-column") === _viewProjectsSortColumn)
                    s.textContent = _viewProjectsSortOrder === "asc" ? "\u25B2" : "\u25BC";
                else
                    s.textContent = "";
            });
            PopulateViewProjectBody(res);
            document.body.style.cursor = "default";
        }
    });
}

// ── Summary table ─────────────────────────────────────────────────────────────

function LoadSummaryTable() {
    var titles = document.getElementsByClassName("summary-item-title");
    var values = document.getElementsByClassName("summary-item-value");
    var table = document.getElementById("pcs-summary-table");
    if (!table) return;
    table.innerHTML = "";
    var total = 0;
    for (var i = 0; i < titles.length; i++) {
        var subtotal = parseFloat(values[i].value) || 0;
        var row = table.insertRow(i);
        row.insertCell(0).textContent = titles[i].value;
        row.insertCell(1).textContent = "$" + GetFormattedNumber(subtotal, 2);
        total += subtotal;
    }
    document.querySelectorAll(".StrongTotal").forEach(function (el) { el.textContent = GetFormattedNumber(total, 2); });
}

// ── Open / Save / Export helpers ──────────────────────────────────────────────

function OpenProjectClick(modalId) {
    var name = GetSelectedProject("OpenProjectModel");
    if (!name) return;
    _civPCS.OpenProject(name);
    var modal = bootstrap.Modal.getInstance(document.getElementById(modalId));
    if (modal) modal.hide();
}

function SaveAsClick() {
    var name = document.getElementById("SaveAsProjectName").value.trim();
    if (!name) return;
    SavePCSContent(name);
}

function SavePCSContent(projectName) {
    _pcsInputFieldValueChanged = false;
    _civPCS.SavePCSContentAction(projectName);
}

function ExportClick() {
    _civPCS.ExportToFile("PCS-Export-" + Date.now());
}

// ── CivPCS class ──────────────────────────────────────────────────────────────

var _civPCS;

var CivPCS = (function () {
    function CivPCS() {
        var self = this;
        self._amcosVersionId = parseInt(document.getElementById("AmcosVersionId").value) || 0;
        self._pcsState = {
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
        self._selectLocationsData = null;
        self._originationLocationId = null;
        self._destinationLocationId = null;
        self._originationCallback = null;
        self._destinationCallback = null;

        self.InitializeLocation("#SourceLocation", function (q, cb) { self.LoadOriginationList(q, cb); });
        self.InitializeLocation("#TargetDestination", function (q, cb) { self.LoadDestinationList(q, cb); });
        self.DisplayTransportationPanel("Goods");
        self.DisplayRealEstateOrLease("RealEstate");
    }

    CivPCS.prototype.SetDefaultTax = function () {
        var defVal = document.querySelector("[name='DefaultFederalTaxRate']").value;
        document.getElementById("FederalTaxRate").value = defVal;
        this.CalculateAll();
    };

    CivPCS.prototype.DisableNTSSubtotal = function (disabled) {
        var el = document.getElementById("NTSSubtotal");
        if (disabled) el.value = "0.00";
        el.disabled = disabled;
    };

    CivPCS.prototype.DisplayTransportationPanel = function (type) {
        document.getElementById("house-hold-goods").style.display = type === "Goods" ? "" : "none";
        document.getElementById("mobile-home-transportation").style.display = type === "Home" ? "" : "none";
    };

    CivPCS.prototype.DisplayRealEstateOrLease = function (val) {
        document.getElementById("Real-Estate").style.display = val === "RealEstate" ? "" : "none";
        document.getElementById("Unexpired-Lease").style.display = val === "Lease" ? "" : "none";
    };

    CivPCS.prototype.ResetBaseline = function () {
        var self = this;
        self._pcsState.InitialState = true;
        _pcsInputFieldValueChanged = true;
        self.CalculateAll();
        self._pcsState.InitialState = false;
    };

    CivPCS.prototype.LoadOriginationList = function (query, callback) {
        var self = this;
        if (self._pcsState.SelectLocationsAvailable && !self._pcsState.OriginationSelectLocationLoaded) {
            self._pcsState.OriginationSelectLocationLoaded = true;
            callback(self._selectLocationsData);
            self.SetLocationId();
            return;
        }
        self._originationCallback = callback;
        self.GetCivLocationPerDiem(self._amcosVersionId, query);
    };

    CivPCS.prototype.LoadDestinationList = function (query, callback) {
        var self = this;
        if (self._pcsState.SelectLocationsAvailable && !self._pcsState.DestinationSelectLocationLoaded) {
            self._pcsState.DestinationSelectLocationLoaded = true;
            callback(self._selectLocationsData);
            self.SetLocationId();
            return;
        }
        self._destinationCallback = callback;
        self.GetCivLocationPerDiem(self._amcosVersionId, query);
    };

    CivPCS.prototype.SetLocationId = function () {
        var self = this;
        if (self._originationLocationId && self._pcsState.OriginationSelectLocationLoaded) {
            $("#SourceLocation")[0].selectize.setValue(self._originationLocationId, true);
            self._originationLocationId = null;
        }
        if (self._destinationLocationId && self._pcsState.DestinationSelectLocationLoaded) {
            $("#TargetDestination")[0].selectize.setValue(self._destinationLocationId, true);
            self._destinationLocationId = null;
        }
        if (self._pcsState.DestinationSelectLocationLoaded && self._pcsState.OriginationSelectLocationLoaded) {
            self.CalculateAll();
        }
    };

    CivPCS.prototype.InitializeLocation = function (selector, loadFn) {
        var self = this;
        var existing = $(selector)[0].selectize;
        if (existing) existing.destroy();
        $(selector).selectize({
            options: [],
            create: false,
            maxItems: 1,
            selectOnTab: true,
            optgroups: [
                { $order: 1, value: "Zip", label: "Zip" },
                { $order: 2, value: "Civilian Overseas", label: "Civilian Overseas" }
            ],
            valueField: "Value",
            optgroupValueField: "value",
            labelField: "Text",
            optgroupLabelField: "label",
            optgroupField: "OptionGroup",
            sortField: [{ field: "Text", direction: "asc" }],
            searchField: ["Text"],
            plugins: { "optgroup_columns": { equalizeWidth: false, equalizeHeight: false } },
            lockOptgroupOrder: true,
            preload: true,
            load: loadFn,
            onChange: function (value) {
                _pcsInputFieldValueChanged = true;
                self._pcsState.LocationChanged = true;
                self._pcsState.OriginationSelected = !!$("#SourceLocation").val();
                self._pcsState.DestinationSelected = !!$("#TargetDestination").val();
                if (self._pcsState.OriginationSelected && self._pcsState.DestinationSelected) {
                    self.CalculateAll();
                    self._pcsState.InitialState = false;
                } else {
                    self._pcsState.InitialState = true;
                }
            }
        });
    };

    CivPCS.prototype.GetCivLocationPerDiem = function (amcosVersionId, query) {
        var self = this;
        $.ajax({
            url: "?handler=GetLocations",
            type: "GET",
            data: { amcosVersionId: amcosVersionId, q: query || "A" },
            dataType: "json",
            error: function () { alert("Failed to retrieve location data from server."); },
            success: function (res) {
                self._pcsState.AllLocationsAvailable = true;
                if (self._originationCallback) { self._originationCallback(res); self._originationCallback = null; }
                if (self._destinationCallback) { self._destinationCallback(res); self._destinationCallback = null; }
            }
        });
    };

    CivPCS.prototype.GetCivPCSLocationById = function () {
        var self = this;
        $.ajax({
            url: "?handler=GetSpecificLocations",
            type: "GET",
            data: { amcosVersionId: self._amcosVersionId, originationId: self._originationLocationId, destinationId: self._destinationLocationId },
            dataType: "json",
            error: function () { alert("Failed to fetch location data from server."); },
            success: function (res) {
                self._selectLocationsData = res;
                self._pcsState.SelectLocationsAvailable = true;
                if (self._originationCallback && !self._pcsState.OriginationSelectLocationLoaded) {
                    self._pcsState.OriginationSelectLocationLoaded = true;
                    self._originationCallback(res);
                    self._originationCallback = null;
                }
                if (self._destinationCallback && !self._pcsState.DestinationSelectLocationLoaded) {
                    self._pcsState.DestinationSelectLocationLoaded = true;
                    self._destinationCallback(res);
                    self._destinationCallback = null;
                }
                self.SetLocationId();
            }
        });
    };

    CivPCS.prototype.GetPCSData = function (projectName) {
        return {
            ProjectName: projectName || null,
            ViewProjectsSortColumn: _viewProjectsSortColumn,
            ViewProjectsSortOrder: _viewProjectsSortOrder,
            AmcosVersionId: this._amcosVersionId,
            LocationChanged: this._pcsState.LocationChanged,
            InitialState: this._pcsState.InitialState,
            TransDependentsChanged: this._pcsState.TransDependentsChanged,
            POVMileageChanged: this._pcsState.POVMileageChanged,
            ValueChangedElementId: _valueChangedElementId,
            MileageChanged: this._pcsState.MileageChanged,
            IsIsolatedDutyStationChanged: this._pcsState.IsIsolatedDutyStationChanged,
            // Mileage
            OriginationId: document.getElementById("SourceLocation").value,
            DestinationId: document.getElementById("TargetDestination").value,
            CalculatedDistance: FormatAsNumber(document.getElementById("CalculatedDistance").value),
            Year: FormatAsNumber(document.getElementById("Year").value),
            Appropriation: document.getElementById("Appropriation").value,
            ConversionType: document.getElementById("ConversionType").value,
            // House Hunting
            NumberOfDaysHunting: FormatAsNumber(document.getElementById("NumberOfDaysHunting").value),
            HouseHuntingHaveSpouse: document.getElementById("HouseHuntingHaveSpouse").checked,
            // Transportation
            POVMileage: FormatAsNumber(document.getElementById("POVMileage").value),
            TransportationDependents: FormatAsNumber(document.getElementById("TransportationDependents").value),
            TransportationSubTotal: FormatAsNumber(document.getElementById("TransportationSubTotal").value),
            // TQSE
            NumberDaysTQSE: FormatAsNumber(document.getElementById("NumberDaysTQSE").value),
            TQSEDependents: FormatAsNumber(document.getElementById("TQSEDependents").value),
            // GH Transportation
            TransportationType: (document.querySelector("input[name='TransportationType']:checked") || { value: "Goods" }).value,
            HHGTotalMileage: FormatAsNumber(document.getElementById("HHGTotalMileage").value),
            HHGTotalWeight: FormatAsNumber(document.getElementById("HHGTotalWeight").value),
            HHGEstimatedCostPerMile: FormatAsNumber(document.getElementById("HHGEstimatedCostPerMile").value),
            HHGEstimatedCostPerPound: FormatAsNumber(document.getElementById("HHGEstimatedCostPerPound").value),
            MobileHomeTotalMileage: FormatAsNumber(document.getElementById("MobileHomeTotalMileage").value),
            MobileHomeEstCostPerMile: FormatAsNumber(document.getElementById("MobileHomeEstCostPerMile").value),
            // MEA
            MEASubtotal: FormatAsNumber(document.getElementById("MEASubtotal").value),
            MEAHasSpouse: document.getElementById("MEAHasSpouse").checked,
            // Real Estate / Lease
            RealEstateOrLease: (document.querySelector("input[name='RealEstateOrLease']:checked") || { value: "RealEstate" }).value,
            SalePriceAmount: FormatAsNumber(document.getElementById("SalePriceAmount").value),
            SalePriceRefund: FormatAsNumber(document.getElementById("SalePriceRefund").value),
            PurchasePriceAmount: FormatAsNumber(document.getElementById("PurchasePriceAmount").value),
            PurchasePriceRefund: FormatAsNumber(document.getElementById("PurchasePriceRefund").value),
            UELAmount: FormatAsNumber(document.getElementById("UELAmount").value),
            // NTS
            IsIsolatedDutyStation: document.getElementById("IsIsolatedDutyStation").checked,
            NTSSubtotal: FormatAsNumber(document.getElementById("NTSSubtotal").value),
            // RITA
            FederalTaxRate: FormatAsNumber(document.getElementById("FederalTaxRate").value),
            MedicareTaxRate: FormatAsNumber(document.getElementById("MedicareTaxRate").value),
            SocialSecurityTaxRate: FormatAsNumber(document.getElementById("SocialSecurityTaxRate").value),
            StateTaxRate: FormatAsNumber(document.getElementById("StateTaxRate").value),
            CountyTaxRate: FormatAsNumber(document.getElementById("CountyTaxRate").value),
            CityTaxRate: FormatAsNumber(document.getElementById("CityTaxRate").value)
        };
    };

    CivPCS.prototype.SetPCSValues = function (res) {
        if (res.ProjectName) document.querySelectorAll(".pcs-project-name").forEach(function (el) { el.textContent = res.ProjectName; });
        // Mileage
        document.getElementById("Year").value = res.Year;
        document.getElementById("Appropriation").value = res.Appropriation;
        document.getElementById("ConversionType").value = res.ConversionType;
        $("#CalculatedDistance").val(GetFormattedNumber(res.CalculatedDistance, 0));
        $("#JicInflationRate").text(GetFormattedNumber(res.JicInflationRate, 6));
        // House Hunting
        document.getElementById("NumberOfDaysHunting").value = GetFormattedNumber(res.NumberOfDaysHunting, 0);
        document.getElementById("HouseHuntingHaveSpouse").checked = res.HouseHuntingHaveSpouse;
        $("#SelfLodgingPerDiem").text("$" + GetFormattedNumber(res.SelfLodgingPerDiem, 2));
        $("#SelfMIEPerDiem").text("$" + GetFormattedNumber(res.SelfMIEPerDiem, 2));
        $("#SpouseLodgingPerDiem").text("$" + GetFormattedNumber(res.SpouseLodgingPerDiem, 2));
        $("#SpouseMIEPerDiem").text("$" + GetFormattedNumber(res.SpouseMIEPerDiem, 2));
        $("#HouseHuntingTotalCell").text("$" + GetFormattedNumber(res.HouseHuntingTotal, 2));
        $("#HouseHuntingTotal").val(res.HouseHuntingTotal);
        $("#SelfPerDiemRate").text(parseFloat(res.SelfPerDiemRate) * 100);
        // Transportation
        $("#POVMileage").val(GetFormattedNumber(res.POVMileage, 0));
        $("#TransportationDependents").val(res.TransportationDependents);
        $("#PCSMaltRate").text(GetFormattedNumber(res.PCSMaltRate, 2));
        $("#TransportationVersionYear").text(res.TransportationVersionYear);
        $("#MileageReimbursement").text("$" + GetFormattedNumber(res.MileageReimbursement, 2));
        $("#DependantMileageReimbursement").text("$" + GetFormattedNumber(res.DependantMileageReimbursement, 2));
        $("#TransportationSubTotal").val(GetFormattedNumber(res.TransportationSubTotal, 2));
        $("#TransportationSubTotalValue").val(res.TransportationSubTotal);
        // TQSE
        $("#NumberDaysTQSE").val(GetFormattedNumber(res.NumberDaysTQSE, 0));
        $("#TQSEDependents").val(res.TQSEDependents);
        $("#TQSESelfPerDiemLodging").text("$" + GetFormattedNumber(res.TQSESelfPerDiemLodging, 2));
        $("#TQSESpousePerDiemLodging").text("$" + GetFormattedNumber(res.TQSESpousePerDiemLodging, 2));
        $("#TQSESelfPerDiemMIE").text("$" + GetFormattedNumber(res.TQSESelfPerDiemMIE, 2));
        $("#TQSESpousePerDiemMIE").text("$" + GetFormattedNumber(res.TQSESpousePerDiemMIE, 2));
        $("#TQSETotal").val(res.TQSETotal);
        $("#TQSETotalValue").text("$" + GetFormattedNumber(res.TQSETotal, 2));
        $("#TQSEPerDiemRate").text(GetFormattedNumber(res.TQSEPerDiemRate, 2));
        $("#TQSESpousePerDiemRate").text(GetFormattedNumber(res.TQSESpousePerDiemRate, 2));
        // GH Transportation
        $("input[name='TransportationType'][value='" + res.TransportationType + "']").prop("checked", true);
        this.DisplayTransportationPanel(res.TransportationType);
        $("#GHTransportationTotal").val(res.GHTransportationTotal);
        $("#HHGTotalMileage").val(GetFormattedNumber(res.HHGTotalMileage, 0));
        $("#HHGTotalWeight").val(GetFormattedNumber(res.HHGTotalWeight, 0));
        $("#HHGMaxWeight").text(res.HHGMaxWeight.toLocaleString());
        $("#HHGEstimatedCostPerMile").val(GetFormattedNumber(res.HHGEstimatedCostPerMile, 2));
        $("#HHGEstimatedCostPerMileValue").text(GetFormattedNumber(res.HHGEstimatedCostPerMile, 2));
        $("#HHGEstimatedCostPerPound").val(GetFormattedNumber(res.HHGEstimatedCostPerPound, 2));
        $("#HHGEstimatedCostPerPoundValue").text(GetFormattedNumber(res.HHGEstimatedCostPerPound, 2));
        $("#HHGCostByTotalMiles").text("$" + GetFormattedNumber(res.HHGCostByTotalMiles, 2));
        $("#HHGCostByTotalWeight").text("$" + GetFormattedNumber(res.HHGCostByTotalWeight, 2));
        $("#SubtotalHHG").text("$" + GetFormattedNumber(res.SubtotalHHG, 2));
        $("#MobileHomeTotalMileage").val(GetFormattedNumber(res.MobileHomeTotalMileage, 0));
        $("#MobileHomeEstCostPerMile").val(GetFormattedNumber(res.MobileHomeEstCostPerMile, 2));
        $("#MobileHomeEstCostPerMileValue").text(GetFormattedNumber(res.MobileHomeEstCostPerMile, 2));
        $("#MobileHomeSubtotal").text("$" + GetFormattedNumber(res.MobileHomeSubtotal, 2));
        // MEA
        $("#MEACivilian").text(GetFormattedNumber(res.MEACivilian, 2));
        $("#MEACivilianAndSpouse").text(GetFormattedNumber(res.MEACivilianAndSpouse, 2));
        $("#MEASubtotal").val(GetFormattedNumber(res.MEASubtotal, 2));
        $("#MEASubtotalValue").val(res.MEASubtotal);
        document.getElementById("MEAHasSpouse").checked = res.MEAHasSpouse;
        // Real Estate / Lease
        $("input[name='RealEstateOrLease'][value='" + res.RealEstateOrLease + "']").prop("checked", true);
        this.DisplayRealEstateOrLease(res.RealEstateOrLease);
        $("#SalePriceAmount").val(GetFormattedNumber(res.SalePriceAmount, 2));
        $("#SalePriceRefund").val(res.SalePriceRefund);
        $("#PurchasePriceAmount").val(GetFormattedNumber(res.PurchasePriceAmount, 2));
        $("#PurchasePriceRefund").val(res.PurchasePriceRefund);
        $("#RealEstateSubtotalValue").text("$" + GetFormattedNumber(res.RealEstateSubtotal, 2));
        $("#UELAmount").val(GetFormattedNumber(res.UELAmount, 2));
        $("#UELTotalValue").text("$" + GetFormattedNumber(res.UELTotal, 2));
        $("#RealEstateLeaseTotal").val(res.RealEstateLeaseTotal);
        // NTS
        document.getElementById("IsIsolatedDutyStation").checked = res.IsIsolatedDutyStation;
        this.DisableNTSSubtotal(!res.IsIsolatedDutyStation);
        $("#NTSSubtotal").val(GetFormattedNumber(res.NTSSubtotal, 2));
        $("#NTSSubtotalValue").val(res.NTSSubtotal);
        // RITA
        $("[name='DefaultFederalTaxRate']").val(GetFormattedNumber(res.DefaultFederalTaxRate, 2));
        $("#FederalTaxRate").val(GetFormattedNumber(res.FederalTaxRate, 2));
        $("#SocialSecurityTaxRate").val(GetFormattedNumber(res.SocialSecurityTaxRate, 2));
        $("#MedicareTaxRate").val(GetFormattedNumber(res.MedicareTaxRate, 2));
        $("#StateTaxRate").val(GetFormattedNumber(res.StateTaxRate, 2));
        $("#CountyTaxRate").val(GetFormattedNumber(res.CountyTaxRate, 2));
        $("#CityTaxRate").val(GetFormattedNumber(res.CityTaxRate, 2));
        $("#TotalTaxRate").text(GetFormattedNumber(res.TotalTaxRate, 2));
        $("[name='TaxBracketLabel']").text(GetFormattedNumber(res.TotalTaxRate / 100, 4));
        $("#RITASubtotal").val(res.RITASubtotal);
        $("#RITASubtotalValue").text("$" + GetFormattedNumber(res.RITASubtotal, 2));
        // RITA breakdown labels
        $("#HouseHuntingTotalLabel").text(GetFormattedNumber(res.HouseHuntingTotal, 2));
        $("#HouseHuntingRITA").text(GetFormattedNumber(res.HouseHuntingRITA, 2));
        $("#TransportationSubTotalLabel").text(GetFormattedNumber(res.TransportationSubTotal, 2));
        $("#TransportationRITA").text(GetFormattedNumber(res.TransportationRITA, 2));
        $("#TQSESubtotalLabel").text(GetFormattedNumber(res.TQSETotal, 2));
        $("#TQSERITA").text(GetFormattedNumber(res.TQSERITA, 2));
        $("#GHTransportationTotalLabel").text(GetFormattedNumber(res.GHTransportationTotal, 2));
        $("#GHTransportationRITA").text(GetFormattedNumber(res.GHTransportationRITA, 2));
        $("#MEASubtotalLabel").text(GetFormattedNumber(res.MEASubtotal, 2));
        $("#MEARITA").text(GetFormattedNumber(res.MEARITA, 2));
        $("#RealEstateLeaseTotalLabel").text(GetFormattedNumber(res.RealEstateLeaseTotal, 2));
        $("#RealEstateLeaseRITA").text(GetFormattedNumber(res.RealEstateLeaseRITA, 2));
        $("#NTSSubtotalLabel").text(GetFormattedNumber(res.NTSSubtotal, 2));
        $("#NTSRITA").text(GetFormattedNumber(res.NTSRITA, 2));
        // Grand Total
        $("#HouseHuntingSummarySubtotal").text("$" + GetFormattedNumber(res.HouseHuntingTotal, 2));
        $("#TransportationSummarySubtotal").text("$" + GetFormattedNumber(res.TransportationSubTotal, 2));
        $("#TQSESummarySubtotal").text("$" + GetFormattedNumber(res.TQSETotal, 2));
        $("#GHTransportationSummarySubtotal").text("$" + GetFormattedNumber(res.GHTransportationTotal, 2));
        $("#MEASummarySubtotal").text("$" + GetFormattedNumber(res.MEASubtotal, 2));
        $("#RealEstateLeaseSummarySubtotal").text("$" + GetFormattedNumber(res.RealEstateLeaseTotal, 2));
        $("#NTSSummarySubtotal").text("$" + GetFormattedNumber(res.NTSSubtotal, 2));
        $("#RITASummarySubtotal").text("$" + GetFormattedNumber(res.RITASubtotal, 2));
        $("#GrandTotal").text("$" + GetFormattedNumber(res.GrandTotal, 2));

        LoadSummaryTable();
        this._pcsState.LocationChanged = false;
        this._pcsState.IsIsolatedDutyStationChanged = false;
        document.body.style.cursor = "default";
    };

    CivPCS.prototype.CalculateAll = function () {
        var self = this;
        document.body.style.cursor = "progress";
        $.ajax({
            url: "?handler=CalculateAll",
            type: "POST",
            data: self.GetPCSData(),
            dataType: "json",
            error: function (xhr, status, err) { console.error(status, err); document.body.style.cursor = "default"; },
            success: function (res) { self.SetPCSValues(res); }
        });
    };

    CivPCS.prototype.SavePCSContentAction = function (projectName) {
        var self = this;
        $.ajax({
            url: "?handler=SaveProject",
            type: "POST",
            data: self.GetPCSData(projectName),
            dataType: "json",
            error: function (xhr, status, err) { console.error(status, err); document.body.style.cursor = "default"; },
            success: function (res) {
                document.querySelectorAll(".pcs-project-name").forEach(function (el) { el.textContent = projectName; });
                PopulateViewProjectBody(res);
            }
        });
    };

    CivPCS.prototype.OpenProject = function (projectName) {
        var self = this;
        document.body.style.cursor = "progress";
        $.ajax({
            url: "?handler=OpenProject",
            type: "POST",
            data: { projectName: projectName },
            dataType: "json",
            error: function (xhr, status, err) { console.error(status, err); document.body.style.cursor = "default"; },
            success: function (res) {
                self.SetPCSValues(res);
                self._pcsState.OriginationSelectLocationLoaded = false;
                self._pcsState.DestinationSelectLocationLoaded = false;
                self._pcsState.SelectLocationsAvailable = false;
                self._destinationLocationId = res.DestinationId;
                self._originationLocationId = res.OriginationId;
                self.GetCivPCSLocationById();
            }
        });
    };

    CivPCS.prototype.ExportToFile = function (projectName) {
        var self = this;
        document.body.style.cursor = "progress";
        $.ajax({
            url: "?handler=SaveProject",
            type: "POST",
            data: self.GetPCSData(projectName),
            dataType: "json",
            error: function (xhr, status, err) { console.error(status, err); document.body.style.cursor = "default"; },
            success: function () {
                document.querySelectorAll(".pcs-project-name").forEach(function (el) { el.textContent = projectName; });
                window.location.href = "?handler=Export&projectName=" + encodeURIComponent(projectName);
                document.body.style.cursor = "default";
            }
        });
    };

    CivPCS.prototype.DeleteProject = function (projectName) {
        var self = this;
        if (!confirm("Delete project \"" + projectName + "\"?")) return;
        document.body.style.cursor = "progress";
        $.ajax({
            url: "?handler=DeleteProject",
            type: "POST",
            data: { projectName: projectName, sortColumn: _viewProjectsSortColumn, sortOrder: _viewProjectsSortOrder },
            dataType: "json",
            error: function (xhr, status, err) { console.error(status, err); document.body.style.cursor = "default"; },
            success: function (res) {
                PopulateViewProjectBody(res);
                document.body.style.cursor = "default";
            }
        });
    };

    return CivPCS;
})();

// ── DOM ready ─────────────────────────────────────────────────────────────────

$(document).ready(function () {
    _civPCS = new CivPCS();

    // Year list: load when Appropriation or ConversionType changes
    function reloadYearList() {
        var amcosVersionId = _civPCS._amcosVersionId;
        var appropriation = document.getElementById("Appropriation").value;
        var conversionType = document.getElementById("ConversionType").value;
        var yearEl = document.getElementById("Year");
        var selectedYear = yearEl.value;
        yearEl.innerHTML = "";
        $.ajax({
            url: "?handler=GetYearList",
            type: "GET",
            data: { amcosVersionId: amcosVersionId, appropriation: appropriation, conversionType: conversionType },
            dataType: "json",
            error: function () { alert("Failed to retrieve year list."); },
            success: function (res) {
                var found = false;
                for (var x = 0; x < res.length; x++) {
                    var opt = document.createElement("option");
                    opt.value = res[x].Value;
                    opt.textContent = res[x].Text;
                    yearEl.appendChild(opt);
                    if (res[x].Value == selectedYear) found = true;
                }
                if (found) yearEl.value = selectedYear;
                else yearEl.value = document.getElementById("AmcosVersionYear").textContent;
                _civPCS.ResetBaseline();
            }
        });
    }

    document.getElementById("Appropriation").addEventListener("change", reloadYearList);
    // Initial year list load
    reloadYearList();

    // CalculatedDistance manual edit
    document.getElementById("CalculatedDistance").addEventListener("change", function () {
        _pcsInputFieldValueChanged = true;
        _civPCS._pcsState.MileageChanged = true;
        _civPCS.CalculateAll();
        _civPCS._pcsState.MileageChanged = false;
    });

    // POVMileage manual edit (transportation tab has its own listener via pcs-input-field class)
    document.getElementById("POVMileage").addEventListener("change", function () {
        _pcsInputFieldValueChanged = true;
        _civPCS._pcsState.POVMileageChanged = true;
        _civPCS.CalculateAll();
        _civPCS._pcsState.POVMileageChanged = false;
    });

    // HHG weight warning
    document.getElementById("HHGTotalWeight").addEventListener("change", function () {
        var maxWeight = parseFloat(document.getElementById("HHGMaxWeight").textContent.replace(/,/g, "")) || 0;
        var warning = document.getElementById("HHGTotalWeightWarning");
        if (parseFloat(this.value) > maxWeight) {
            warning.style.display = "inline-block";
            warning.textContent = "The maximum weight of " + maxWeight + " will be used.";
        } else {
            warning.style.display = "none";
        }
    });

    // MEA Subtotal manual change
    document.getElementById("MEASubtotal").addEventListener("change", function () {
        _pcsInputFieldValueChanged = true;
        _civPCS.CalculateAll();
    });

    // MEA Spouse checkbox
    document.getElementById("MEAHasSpouse").addEventListener("change", function () {
        if (this.checked)
            document.getElementById("MEASubtotal").value = GetFormattedNumber(parseFloat(document.getElementById("MEACivilianAndSpouse").textContent), 2);
        else
            document.getElementById("MEASubtotal").value = GetFormattedNumber(parseFloat(document.getElementById("MEACivilian").textContent), 2);
        _pcsInputFieldValueChanged = true;
        _civPCS.CalculateAll();
    });

    // NTS isolated checkbox
    var isolatedCb = document.getElementById("IsIsolatedDutyStation");
    _civPCS.DisableNTSSubtotal(!isolatedCb.checked);
    isolatedCb.addEventListener("change", function () {
        _civPCS.DisableNTSSubtotal(!this.checked);
        _civPCS._pcsState.IsIsolatedDutyStationChanged = true;
        _pcsInputFieldValueChanged = true;
        _civPCS.CalculateAll();
        _civPCS._pcsState.IsIsolatedDutyStationChanged = false;
    });

    // TransportationDependents
    document.getElementById("TransportationDependents").addEventListener("change", function () {
        _civPCS._pcsState.TransDependentsChanged = true;
        _pcsInputFieldValueChanged = true;
        _civPCS.CalculateAll();
        _civPCS._pcsState.TransDependentsChanged = false;
    });

    // Transportation type radio
    document.getElementsByName("TransportationType").forEach(function (btn) {
        btn.addEventListener("change", function () { _civPCS.DisplayTransportationPanel(this.value); });
    });

    // Real estate / lease radio
    document.getElementsByName("RealEstateOrLease").forEach(function (btn) {
        btn.addEventListener("change", function () { _civPCS.DisplayRealEstateOrLease(this.value); });
    });

    // Generic pcs-input-field change handler
    document.querySelectorAll(".pcs-input-field").forEach(function (el) {
        el.addEventListener("change", function () {
            _pcsInputFieldValueChanged = true;
            _valueChangedElementId = this.id;
            _civPCS.CalculateAll();
            _valueChangedElementId = null;
        });
    });

    // pcs-input-rebase: ConversionType
    document.getElementById("ConversionType").addEventListener("change", function () { _civPCS.ResetBaseline(); });
    document.getElementById("Year").addEventListener("change", function () { _civPCS.ResetBaseline(); });

    // New Calculation button
    document.getElementById("btn-new").addEventListener("click", function () {
        if (!confirm("Clear all fields and start a new calculation?")) return;
        location.reload();
    });

    // Export button
    document.getElementById("btn-export").addEventListener("click", ExportClick);

    // Project list initial wiring
    document.querySelectorAll(".cal-row-delete").forEach(function (el) {
        el.addEventListener("click", function () { _civPCS.DeleteProject(this.getAttribute("value")); });
    });
    document.querySelectorAll(".selectable-row").forEach(function (el) {
        el.addEventListener("click", function () { HandleProjectRowClick(this); });
    });

    LoadSummaryTable();
});
