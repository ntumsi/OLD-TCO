var _pcsInputFieldValueChanged = false;
var _pcsContentCount = null;
var _viewProjectsSortColumn = "ProjectSaveDate";
var _viewProjectsSortOrder = "desc";
var _valueChangedElementId = null;
$(document).ready(function () {
    _pcsContentCount = document.getElementById("PCSContentCount").value;
    LoadSummaryTable();
    HandleUserEdits();
    $(".cal-row-delete").click(function () {
        DeleteProject(this.getAttribute("value"));
    });
    $(".selectable-row").click(function () {
        HandleProjectRowClick(this);
    });
});

function HandleProjectRowClick(element) {
    if (!element) { return; }
    $(".selectable-row").removeClass("cal-row-selected");
    element.classList.add("cal-row-selected");
    let textBox = document.getElementById('SaveAsProjectName');
    if (textBox != null) {
        textBox.value = GetSelectedProject("SaveAsModel") || "";
    }
}
function HandleUserEdits() {
    let controls = document.getElementsByClassName('pcs-input-field');
    for (let x = 0; x < controls.length; x++) {
        controls[x].addEventListener('change', function () {
            _pcsInputFieldValueChanged = true;
            _valueChangedElementId = this.id;
            CalculateAll();
            _valueChangedElementId = null;
        });
    }
    controls = document.getElementsByClassName('pcs-input-rebase');
    for (let x = 0; x < controls.length; x++) {
        controls[x].addEventListener('change', function () {
            ResetBaseline();
        });
    }
}
function GetSelectedProject(modelId) {
    let element = document.getElementById(modelId).getElementsByClassName("cal-row-selected")[0];
    if (element != null) {
        let child = element.getElementsByClassName("selectable-project")[0];
        if (child != null) {
            return child.textContent.trim();
        }
    }
}
function PopulateViewProjectBody(data) {
    $("[name='ViewProjectBody']").each(function () { this.innerHTML = ''; });
    for (let x = 0; x < data.length; x++) {
        let row = document.createElement('tr');
        row.classList.add('selectable-row');
        let col1 = document.createElement('td');
        col1.classList.add('selectable-project');
        col1.textContent = data[x].Item1;
        row.appendChild(col1);
        let col2 = document.createElement('td');
        col2.classList.add("selectable-project");
        col2.textContent = data[x].Item2;
        row.appendChild(col2);
        let col3 = document.createElement('td');
        col3.classList.add("selectable-project-icon");
        let iconButton = document.createElement('a');
        iconButton.classList.add("cal-row-delete");
        iconButton.setAttributeNode(document.createAttribute("data-tooltip"));
        iconButton.setAttributeNode(document.createAttribute("title"));
        iconButton.setAttribute("title", "Delete");
        iconButton.setAttributeNode(document.createAttribute("data-click-open"));
        iconButton.setAttribute("data-click-open", "false");
        iconButton.setAttributeNode(document.createAttribute("value"));
        iconButton.setAttribute("value", data[x].Item1);
        iconButton.textContent = '\uD83D\uDDD1';
        col3.appendChild(iconButton);
        row.appendChild(col3);

        $("[name='ViewProjectBody']").append(row);
    }
    $(".cal-row-delete").click(function () {
        DeleteProject(this.getAttribute("value"));
    });
    $(".selectable-row").click(function () {
        HandleProjectRowClick(this);
    });
}
function AjaxPost(url, data, handleSuccess, handleError) {
    
    $.ajax({
        url: url,
        type: 'POST',
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        data: data,
        dataType: 'json',
        error: handleError,
        success: function (res) {
            //reset the antiforgery token
            if (res.AntiForgeryToken) {
                document.getElementById("AntiForgeryToken").value = res.AntiForgeryToken;                
            }
            //if (res.SessionTimeout) {               
            //    let timeout = new Date(Date.now() + res.SessionTimeout * 60 * 1000);               
            //    document.getElementById("SessionTimeout").value = timeout.toUTCString();
            //}
            handleSuccess(res);
        }
    });
}
function ShowModelContent(element) {
    element.click();    
}
function AutoSavePCSContent() {
    if (_pcsInputFieldValueChanged) {
        SavePCSContent("AUTO-SAVE");
        $(".cal-autosaved").fadeIn().delay(1500).fadeOut();
    }
}
function ViewProjectSort(columnName) {
    $("body").css("cursor", "progress");
    _viewProjectsSortColumn = columnName;
    //reverse the sort order direction
    if (_viewProjectsSortOrder == "asc") {
        _viewProjectsSortOrder = "desc";
    } else {
        _viewProjectsSortOrder = "asc";
    }
    $.ajax({
        url: _sortProjectsURL,
        type: 'POST',
        data: { sortColumn: _viewProjectsSortColumn, sortOrder: _viewProjectsSortOrder },
        headers: {
            AntiForgeryToken: $('#AntiForgeryToken').val()
        },
        dataType: 'json',
        error: HandleError,
        success: function (res) {
            // Set all column sort order icons
            $(".table-view-project").each(function (table) {
                let cols = this.getElementsByTagName("thead")[0].getElementsByTagName("span");
                for (let x = 0; x < cols.length; x++) {
                    if (cols[x].getAttribute("data-column") == _viewProjectsSortColumn) {
                        if (_viewProjectsSortOrder == "asc") {
                            cols[x].textContent = "\u25B2";
                        } else {
                            cols[x].textContent = "\u25BC";
                        }
                    } else {
                        cols[x].textContent = null;
                    }
                }
            });            
            PopulateViewProjectBody(res);
            $("body").css("cursor", "default");
        }
    });
}
function ExportClick() {
    ExportToFile("PCS-Export-" + Date.now());
}
function OpenProjectClick(modalId) {
    OpenProject(GetSelectedProject("OpenProjectModel"));
    $('#' + modalId).foundation('close');
}
function SaveAsClick() {
    SavePCSContent(document.getElementById("SaveAsProjectName").value);
}
function SavePCSContent(projectName) {
    _pcsInputFieldValueChanged = false;
    SavePCSContentAction(projectName);
}
function LoadSummaryTable() {
    let titles = document.getElementsByClassName("summary-item-title");
    let values = document.getElementsByClassName("summary-item-value");
    let table = document.getElementById("pcs-summary-table");
    table.innerHTML = '';
    let total = 0.0;
    for (let i = 0; i < titles.length; i++) {
        let row = table.insertRow(i);
        let subtotal = parseFloat(values.item(i).value);
        row.insertCell(0).textContent = titles.item(i).value;
        row.insertCell(1).textContent = "$" + GetFormattedNumber(subtotal, 2);
        total = total + subtotal;
    }
    $(".StrongTotal").text(GetFormattedNumber(total, 2));
}

function FormatAsNumber(val) {
    if (typeof val == "string") {
        return parseFloat(val.replace(',', '')) || 0;
    } else {
        return val;
    }    
}
function GetFormattedNumber(val, num) {
    if (typeof val == "string") {
        val = parseFloat(val.replace(',', ''));
    }
    if (typeof val == "number") {
        return val.toLocaleString('en-US', { minimumFractionDigits: num, maximumFractionDigits: num });
    } else {
        alert("Could not parse number");
    }
}
function NextTab() {
    let next = document.getElementsByClassName('tabs-title is-active')[0].nextElementSibling;
    next = next ? next.nextElementSibling : null;
    if (next) {
        ShowModelContent(next.firstChild);
    }
}
function PreviousTab() {
    let previous = document.getElementsByClassName('tabs-title is-active')[0].previousElementSibling;
    previous = previous ? previous.previousElementSibling : null;
    if (previous) {
        ShowModelContent(previous.firstChild);
    }
}
$(document).keydown(function (e) {
    //if the active element is a select box we do not want to escape the up and down keys.
    if (document.activeElement.id.indexOf("-selectized") != -1 || document.activeElement.tagName == "select") { return; }
   
    //If foundation reveal is shown then we want to process up down in context of the reveal
    if ($('.reveal-overlay:visible').length > 0) {
        if (e.keyCode == 37 || e.keyCode == 38) {
            //Left or Up key pressed
            HandleProjectRowClick(document.getElementsByClassName('selectable-row cal-row-selected')[0].previousElementSibling)
        } else if (e.keyCode == 39 || e.keyCode == 40) {
            // Right or Down key pressed
            HandleProjectRowClick(document.getElementsByClassName('selectable-row cal-row-selected')[0].nextElementSibling);
        }
        return;
    }
    //Process up down in context of the PCS accordion tabs
    if (e.keyCode == 37 || e.keyCode == 38) {
        //Left or Up Key pressed
        PreviousTab();       
        
    } else if (e.keyCode == 39 || e.keyCode == 40) {
        // Right or Down key pressed
        NextTab();
    }
});
