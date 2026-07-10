// AMCOS Lite — native (Bootstrap 5) cascading filter implementation.
// Port of the legacy amcos-common.js + amcos-lite.js cascade onto the new
// LookupApiController (/api/*) endpoints. No jQuery / selectize dependency.
// Requires object-payplan.js (payPlanObject) and object-inflationyear.js
// (inflationYearObject) to be loaded first, and window._defaultYear / _userId.
(() => {
    'use strict';

    // ---- Pay-plan family groupings (verbatim from legacy amcos-common.js) ----
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

    const inIn = (arr, v) => arr.indexOf(v) !== -1;

    const baseApi = (window._baseApiUrl || '/api');
    const defaultYear = String(window._defaultYear || new Date().getFullYear());
    const userId = window._userId || '';

    // ---- Filter state (mirrors legacy costsFilter) ----
    const costsFilter = {
        payPlan: '-1',
        categoryGroupCode: '-1',
        categorySubgroupCode: '-1',
        careerProgramNumber: '-1',
        locationId: -1,
        locationText: '-1',
        scienceTechnologyReinventionLaboratory: '-1',
        dependentStatus: '-1',
        numberOfDependents: -1,
        overheadPercent: 0,
        inflationConversion: 'ThenToThen',
        inflationYear: defaultYear,
        costSummaryName: 'Default',
        reset() {
            this.payPlan = '-1';
            this.categoryGroupCode = '-1';
            this.categorySubgroupCode = '-1';
            this.careerProgramNumber = '-1';
            this.locationId = -1;
            this.locationText = '-1';
            this.scienceTechnologyReinventionLaboratory = '-1';
            this.dependentStatus = '-1';
            this.numberOfDependents = -1;
            this.overheadPercent = 0;
            this.inflationConversion = 'ThenToThen';
            this.inflationYear = defaultYear;
            this.costSummaryName = 'Default';
        }
    };

    // ---- DOM helpers ----
    const el = id => document.getElementById(id);
    const show = id => { const e = el(id); if (e) e.classList.remove('d-none'); };
    const hide = id => { const e = el(id); if (e) e.classList.add('d-none'); };

    // Populate a native <select>, optionally grouped into <optgroup>s.
    // groupOrder/groupLabels define optgroup ordering + display labels by key.
    function fill(select, items, { valueField = 'Value', textField = 'Text', groupField = null,
        groupOrder = [], groupLabels = {}, placeholder = null, selected = null, disabled = false } = {}) {
        if (!select) return;
        select.innerHTML = '';
        if (placeholder !== null) {
            const o = document.createElement('option');
            o.value = '-1';
            o.textContent = placeholder;
            select.appendChild(o);
        }
        const append = (parent, item) => {
            const o = document.createElement('option');
            o.value = item[valueField];
            o.textContent = item[textField];
            if (selected != null && String(item[valueField]) === String(selected)) o.selected = true;
            parent.appendChild(o);
        };
        if (groupField) {
            const keys = groupOrder.length ? groupOrder : [...new Set(items.map(i => i[groupField]))];
            keys.forEach(key => {
                const groupItems = items.filter(i => i[groupField] === key);
                if (!groupItems.length) return;
                const og = document.createElement('optgroup');
                og.label = groupLabels[key] || key;
                groupItems.forEach(i => append(og, i));
                select.appendChild(og);
            });
        } else {
            items.forEach(i => append(select, i));
        }
        select.disabled = disabled;
    }

    const payPlanIndex = pp => payPlanObject.findIndex(p => p.payPlanValue === pp);

    // ---- parseCategory (verbatim logic from legacy AMCOSCommon.parseCategory) ----
    function parseCategory(payPlan, category) {
        const c = { categoryGroupCode: '-1', categorySubgroupCode: '-1', careerProgramNumber: '-1' };
        if (inIn(armyEnlistedPayPlans, payPlan) || inIn(armyOfficerPayPlans, payPlan)) {
            if (category === '-1') return c;
            if (category.length === 2) { c.categoryGroupCode = category; }
            else if (category.length > 2) { c.categoryGroupCode = category.substring(0, 2); c.categorySubgroupCode = category.substring(0, 3); }
        } else if (inIn(armyWarrantOfficerPayPlans, payPlan)) {
            if (category === '-1') return c;
            if (category.length === 2) { c.categoryGroupCode = category; }
            else if (category.length > 2) { c.categoryGroupCode = category.substring(0, 2); c.categorySubgroupCode = category.substring(0, 4); }
        } else if (inIn(laboratoryDemoPayPlans, payPlan) || inIn(acquisitionDemoPayPlans, payPlan) || inIn(civilianPayPlans, payPlan) || inIn(wageNonAppropriatedFundPayPlans, payPlan)) {
            if (category === '-1') return c;
            if (category.length === 2) { c.careerProgramNumber = category; }
            else if (category.length === 5) {
                if (category.substring(2, 4) === '00') { c.categoryGroupCode = category; }
                else { c.categoryGroupCode = category.substring(0, 2) + '00'; c.categorySubgroupCode = category.substring(0, 5); }
            } else if (category.length === 4) {
                if (category.substring(2, 4) === '00') { c.categoryGroupCode = category; }
                else { c.categoryGroupCode = category.substring(0, 2) + '00'; c.categorySubgroupCode = category.substring(0, 4); }
            }
        } else if (payPlan === 'CCE') {
            if (category.length === 7) {
                if (category.substring(3) === '0000') { c.categoryGroupCode = category; }
                else { c.categoryGroupCode = category.substring(0, 2) + '-0000'; c.categorySubgroupCode = category; }
            }
        } else if (inIn(wageAppropriatedFundPayPlans, payPlan)) {
            if (category === '-1') return c;
            if (category.length === 4) {
                if (category.substring(2, 4) === '00') { c.categoryGroupCode = category; }
                else { c.categoryGroupCode = category.substring(0, 2) + '00'; c.categorySubgroupCode = category.substring(0, 4); }
            }
        }
        return c;
    }

    // ---- Location optgroup labels (union of the legacy per-family optgroup sets) ----
    const LOCATION_GROUP_ORDER = ['all', 'installation', 'mha-conus', 'mha-oconus', 'localityPayArea',
        'specialPayArea', 'wageSchedule', 'cityCounty', 'country', 'gfebsCountry',
        'metropolitanStatisticalArea', 'civilianOverseasArea'];
    const LOCATION_GROUP_LABELS = {
        all: 'All', installation: 'Installation', 'mha-conus': 'Military Housing Area (CONUS)',
        'mha-oconus': 'Military Housing Area (OCONUS)', localityPayArea: 'Locality Pay Area',
        specialPayArea: 'Special Pay Area', wageSchedule: 'Wage Schedule', cityCounty: 'City/County',
        country: 'Country', gfebsCountry: 'Country', metropolitanStatisticalArea: 'Metropolitan Statistical Area',
        civilianOverseasArea: 'Overseas'
    };

    // ---- Fetch helpers against LookupApiController ----
    async function apiGet(url) {
        const res = await fetch(url, { headers: { Accept: 'application/json' } });
        if (!res.ok) throw new Error(`${url} -> ${res.status}`);
        return res.json();
    }

    async function loadCategoryList(payPlan) {
        const idx = payPlanIndex(payPlan);
        const placeholder = (idx >= 0 && payPlanObject[idx].categoryPlaceholderText) || 'Make a selection';
        const groups = (idx >= 0 ? payPlanObject[idx].categoryOptionGroups : []) || [];
        const groupOrder = groups.map(g => g.optgroup);
        const groupLabels = {};
        groups.forEach(g => { groupLabels[g.optgroup] = g.label; });
        try {
            const items = await apiGet(`${baseApi}/categories/${encodeURIComponent(payPlan)}`);
            fill(el('categoryList'), items, { groupField: 'OptionGroup', groupOrder, groupLabels, placeholder });
        } catch (e) {
            fill(el('categoryList'), [], { placeholder: 'Categories unavailable' });
        }
    }

    async function loadLocationList(payPlan, group, sub, career) {
        const sel = el('locationList');
        sel.disabled = true;
        try {
            const url = `${baseApi}/locations/${encodeURIComponent(payPlan)}/${encodeURIComponent(group)}/${encodeURIComponent(sub)}/${encodeURIComponent(career)}`;
            const items = await apiGet(url);
            fill(sel, items, {
                groupField: 'OptionGroup', groupOrder: LOCATION_GROUP_ORDER,
                groupLabels: LOCATION_GROUP_LABELS, placeholder: 'Select a Location'
            });
            sel.disabled = false;
        } catch (e) {
            fill(sel, [], { placeholder: 'Locations unavailable' });
        }
    }

    async function loadStrlList(payPlan, group, sub, career, locationId) {
        const sel = el('strlList');
        try {
            const url = `${baseApi}/strls/${encodeURIComponent(payPlan)}/${encodeURIComponent(group)}/${encodeURIComponent(sub)}/${encodeURIComponent(career)}/${locationId}`;
            const items = await apiGet(url);
            fill(sel, items, { placeholder: 'Select a Laboratory' });
        } catch (e) {
            fill(sel, [], { placeholder: 'Laboratories unavailable' });
        }
    }

    function loadInflationYearList(conversionType) {
        const obj = inflationYearObject.find(o => o.conversionType === conversionType);
        const items = (obj ? obj.years : []).map(y => ({ Value: y.yearValue, Text: String(y.yearValue) }));
        fill(el('inflationYearList'), items, { selected: costsFilter.inflationYear });
        // Keep the selected year if still present, else fall back to default.
        if (!items.some(i => String(i.Value) === String(costsFilter.inflationYear))) {
            costsFilter.inflationYear = defaultYear;
            el('inflationYearList').value = defaultYear;
        }
    }

    function loadCostSummaryList(payPlan) {
        const idx = payPlanIndex(payPlan);
        const summaries = (idx >= 0 ? payPlanObject[idx].costSummaries : ['Default']) || ['Default'];
        fill(el('costSummaryList'), summaries.map(s => ({ Value: s, Text: s })), { selected: 'Default', disabled: summaries.length === 1 });
        costsFilter.costSummaryName = 'Default';
    }

    // ---- Visibility orchestration (mirrors legacy setVisibleElements) ----
    function setVisibleElements(payPlan) {
        // Reset conditional filters.
        ['strlFilter', 'dependentStatusFilter', 'numberOfDependentsFilter', 'overheadPercentFilter',
            'gfebsSelectAllWarning', 'cceNote', 'weaponSystemWarning'].forEach(hide);

        if (inIn(activeDutyArmyPayPlans, payPlan) || inIn(armyNationalGuardPayPlans, payPlan) || inIn(armyReservePayPlans, payPlan)) {
            hide('locationFilter');
        } else if (inIn(laboratoryDemoPayPlans, payPlan)) {
            show('locationFilter'); show('strlFilter'); show('gfebsSelectAllWarning');
        } else if (inIn(acquisitionDemoPayPlans, payPlan)) {
            show('locationFilter'); show('gfebsSelectAllWarning');
        } else if (inIn(civilianPayPlans, payPlan) || payPlan === 'CCE') {
            show('locationFilter');
            if (payPlan === 'CCE') { show('overheadPercentFilter'); show('cceNote'); if (el('overheadPercent')) el('overheadPercent').value = '0'; }
            else if (payPlan === 'GP') { show('gfebsSelectAllWarning'); }
        } else if (inIn(wageAppropriatedFundPayPlans, payPlan) || inIn(wageNonAppropriatedFundPayPlans, payPlan)) {
            show('locationFilter');
        }

        // Category, cost summary, and inflation are always available once a pay plan is chosen.
        show('categoryFilter'); show('costSummaryFilter'); show('inflationFilter');
        loadCategoryList(payPlan);
        loadCostSummaryList(payPlan);
        loadInflationYearList(costsFilter.inflationConversion);

        // Location is loaded only after a category is chosen — disable until then.
        const loc = el('locationList');
        if (loc) { fill(loc, [], { placeholder: 'Select a category first' }); loc.disabled = true; }
    }

    // ---- Change handlers ----
    function onPayPlanChange() {
        const payPlan = el('payPlanList').value;
        logFilter('PayPlanList');
        costsFilter.reset();
        costsFilter.payPlan = payPlan;
        if (payPlan === '-1' || payPlan === '') {
            ['categoryFilter', 'costSummaryFilter', 'inflationFilter', 'locationFilter', 'strlFilter',
                'dependentStatusFilter', 'numberOfDependentsFilter', 'overheadPercentFilter'].forEach(hide);
            return;
        }
        setVisibleElements(payPlan);
        startBlink();
    }

    function onCategoryChange() {
        const category = el('categoryList').value;
        logFilter('Category');
        const parsed = parseCategory(costsFilter.payPlan, category);
        costsFilter.categoryGroupCode = parsed.categoryGroupCode;
        costsFilter.categorySubgroupCode = parsed.categorySubgroupCode;
        costsFilter.careerProgramNumber = parsed.careerProgramNumber;
        costsFilter.locationId = -1;
        costsFilter.locationText = '-1';
        hide('dependentStatusFilter'); hide('numberOfDependentsFilter');

        const pp = costsFilter.payPlan;
        if (inIn(activeDutyArmyPayPlans, pp)) {
            if (costsFilter.categoryGroupCode === '-1' || costsFilter.categorySubgroupCode === '-1') {
                hide('locationFilter');
            } else {
                show('locationFilter');
                loadLocationList(pp, costsFilter.categoryGroupCode, costsFilter.categorySubgroupCode, costsFilter.careerProgramNumber);
            }
        } else if (inIn(payPlansThatDoNotUseLocation, pp)) {
            hide('locationFilter');
        } else {
            show('locationFilter');
            loadLocationList(pp, costsFilter.categoryGroupCode, costsFilter.categorySubgroupCode, costsFilter.careerProgramNumber);
        }
        startBlink();
    }

    function onLocationChange() {
        const sel = el('locationList');
        const value = sel.value;
        const opt = sel.options[sel.selectedIndex];
        logFilter('LocationList');
        costsFilter.locationId = value ? parseInt(value.split('.')[0], 10) : -1;
        costsFilter.locationText = opt ? opt.textContent : '-1';
        const locationType = value ? value.split('.')[2] : undefined; // installation | mha-oconus | civilianOverseasArea | ...

        const pp = costsFilter.payPlan;
        if (inIn(activeDutyArmyPayPlans, pp)) {
            hide('numberOfDependentsFilter');
            if (costsFilter.locationId === -1 || locationType === 'mha-oconus') {
                hide('dependentStatusFilter');
            } else {
                show('dependentStatusFilter');
            }
        } else if (inIn(laboratoryDemoPayPlans, pp)) {
            loadStrlList(pp, costsFilter.categoryGroupCode, costsFilter.categorySubgroupCode, costsFilter.careerProgramNumber, costsFilter.locationId);
            show('strlFilter');
        } else if (inIn(payPlansThatContainCivilianOverseasLocations, pp)) {
            if (costsFilter.locationId !== -1 && locationType === 'civilianOverseasArea') {
                show('numberOfDependentsFilter'); hide('dependentStatusFilter');
            } else {
                hide('dependentStatusFilter'); hide('numberOfDependentsFilter');
            }
        } else {
            hide('dependentStatusFilter'); hide('numberOfDependentsFilter');
        }
        startBlink();
    }

    function onCostSummaryChange() {
        costsFilter.costSummaryName = el('costSummaryList').value;
        logFilter('CostSummaryList');
        if (costsFilter.costSummaryName === 'Weapon System Manpower') show('weaponSystemWarning');
        else hide('weaponSystemWarning');
        startBlink();
    }

    function onInflationConversionChange() {
        costsFilter.inflationConversion = el('inflationConversionTypeList').value;
        logFilter('InflationConversionTypeList');
        loadInflationYearList(costsFilter.inflationConversion);
        startBlink();
    }

    function onInflationYearChange() { costsFilter.inflationYear = el('inflationYearList').value; logFilter('InflationYearList'); startBlink(); }
    function onDependentStatusChange() { costsFilter.dependentStatus = el('dependentStatusList').value; logFilter('DependentStatusList'); startBlink(); }
    function onNumberOfDependentsChange() { costsFilter.numberOfDependents = parseInt(el('numberOfDependentsList').value, 10); logFilter('NumberOfDependentsList'); startBlink(); }
    function onStrlChange() { costsFilter.scienceTechnologyReinventionLaboratory = el('strlList').value; logFilter('scienceTechnologyReinventionLaboratoryList'); startBlink(); }
    function onOverheadChange() { costsFilter.overheadPercent = el('overheadPercent').value; logFilter('Overhead Percent'); startBlink(); }

    function alertForAllCostSummary() {
        if (costsFilter.costSummaryName === 'Ancillary') {
            alert("CAUTION NOTE: \nDO NOT SUM the 'Ancillary' Summary cost elements. Depending on the cost category, i.e., training or recruiting, summing the sub-elements could result in counting costs multiple times.");
        }
    }

    // ---- Filter-choice logging (best-effort; mirrors legacy LiteService.LogChoices) ----
    function logFilter(pageElement) {
        const params = new URLSearchParams({
            userId, pageElement,
            payPlan: costsFilter.payPlan, costSummaryName: costsFilter.costSummaryName,
            categoryGroupCode: costsFilter.categoryGroupCode, categorySubgroupCode: costsFilter.categorySubgroupCode,
            careerProgramNumber: costsFilter.careerProgramNumber, locationId: costsFilter.locationId,
            locationText: costsFilter.locationText, scienceTechnologyReinventionLaboratory: costsFilter.scienceTechnologyReinventionLaboratory,
            dependentStatus: costsFilter.dependentStatus, numberOfDependents: costsFilter.numberOfDependents,
            overheadPercent: costsFilter.overheadPercent, inflationConversionType: costsFilter.inflationConversion,
            inflationYear: costsFilter.inflationYear
        });
        fetch(`${baseApi}/lite/LogChoices?${params.toString()}`, { headers: { Accept: 'application/json' } }).catch(() => { });
    }

    // ---- Refresh button blink (legacy visual cue) ----
    let blinkFlag = false, blinkHandle = null;
    function setButtonColor(c) { const b = el('showCostsButton'); if (b) b.style.backgroundColor = c; }
    function processBlink() {
        if (blinkFlag) { setButtonColor('#FF3300'); setTimeout(() => setButtonColor('#CCCC00'), 500); blinkHandle = setTimeout(processBlink, 1500); }
        else { setButtonColor(''); clearTimeout(blinkHandle); }
    }
    // A filter change makes the last-loaded grid stale, so hide the export until the next refresh.
    function startBlink() { blinkFlag = true; hide('exportButton'); processBlink(); }
    function stopBlink() { blinkFlag = false; processBlink(); }

    // ---- Cost grid + chart rendering ----
    const cceSalaryLimit = Number(window._cceMaxPayFootnote || 0);
    const APPROP_COLORS = {
        'ARMY CIVPAY': '#1F8802', 'CIV ARMY CIVPAY': '#1F8802', 'MPA': '#5D7430', 'MPA NON-PAY': '#5D7430',
        'OMA': '#6A9303', 'OMA_1': '#6A9303', 'FEDERAL OM': '#00008B', 'FEDERAL OMA': '#00008B',
        'DOD OMA': '#7030A0', 'OMDW': '#7030A0', 'NGPA': '#74B803', 'NG PA': '#74B803', 'OMNG': '#8BA103',
        'OMNG_1': '#8BA103', 'RPA': '#5C9303', 'RES PA': '#5C9303', 'OMAR': '#6E8003', 'OMAR_1': '#6E8003',
        'CCE': '#006D8B', 'TOTAL': '#DEDFDE'
    };
    const WEAPON_COLOR = '#FFA500', SALARY_LIMIT_COLOR = '#FFFF99';
    const appropColor = v => v == null ? null : (APPROP_COLORS[String(v).trim().toUpperCase()] || null);
    const isNumeric = v => v !== null && v !== '' && !isNaN(Number(String(v).replace(/[$,]/g, '')));
    const num = v => Number(String(v).replace(/[$,]/g, ''));
    // Grade/cost columns in the crosstab: any 1-3 letter grade prefix + number
    // (E1/O10/W5 military, GS15/GG1/WG9/DB5 civilian), plain numbers, SES MIN/AVG/MAX,
    // and CCE percentile bands (A_PCT10 … A_MEDIAN).
    const looksLikeMoney = h => /amount|cost|pay|rate|\$/i.test(h)
        || /^[A-Za-z]{1,3}\d{1,2}$/.test(h)
        || /^\d/.test(h)
        || /^(MIN|AVG|MAX)$/i.test(h)
        || /^A_(PCT|MEDIAN)/i.test(h);

    // Internal/bookkeeping columns the legacy grid never displays (Description becomes a tooltip).
    const HIDDEN_COLS = ['showorder', 'appngroup', 'description'];
    // Preferred left-to-right order (legacy detail grid: APPN, Category, Cost Element Name, then grades).
    const PREFERRED_COLS = ['appn', 'Cost Element Category', 'Cost Element Name'];
    const isGradeCol = h => /^[A-Za-z]{1,3}\d{1,2}$/.test(h) || /^(MIN|AVG|MAX)$/i.test(h) || /^A_(PCT|MEDIAN)/i.test(h);
    const gradeNum = h => { const m = h.match(/\d+/); return m ? parseInt(m[0], 10) : 0; };
    function orderHeaders(all) {
        const visible = all.filter(h => !HIDDEN_COLS.includes(String(h).toLowerCase()));
        const lead = PREFERRED_COLS.filter(h => visible.includes(h));
        const grades = visible.filter(h => isGradeCol(h) && !lead.includes(h)).sort((a, b) => gradeNum(a) - gradeNum(b));
        const rest = visible.filter(h => !lead.includes(h) && !grades.includes(h));
        return [...lead, ...rest, ...grades];
    }

    const round2 = v => Math.round((Number(v) || 0) * 100) / 100;
    // Currency formatting to match the legacy FormatCurrency: $1,234.00 and ($1,234.00) for negatives.
    const usdFmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', currencySign: 'accounting' });
    const fmtMoney = v => usdFmt.format(num(v));

    // Shapes the raw cost rows to match the legacy detail grid (Lite.GetCostTableWithOrder +
    // CostsGridView row handling): suppress all-zero weapon-training rows, sort by ShowOrder,
    // add the WEAPON SYSTEM MANPOWER / FEDERAL OM subtotals (Active-military WSM only) and a
    // single grand Total row for every summary except Ancillary.
    const NAME_COL = 'Cost Element Name';
    function shapeCostTable(rows, summary, payPlan) {
        if (!rows || rows.length === 0) return rows;
        const gradeCols = Object.keys(rows[0]).filter(isGradeCol);

        // 1. Suppress the weapon-specific-training rows whose every grade cell is zero.
        let work = rows.filter(r => {
            if (!String(r[NAME_COL] ?? '').toLowerCase().includes('weapon specific training')) return true;
            return !gradeCols.every(gc => num(r[gc]) === 0);
        });

        // 2. Order by ShowOrder (the migrated proc does not return rows pre-sorted).
        work = work.slice().sort((a, b) => (Number(a.showorder) || 0) - (Number(b.showorder) || 0));

        if (gradeCols.length === 0) return work;

        const maxShow = work.reduce((m, r) => Math.max(m, Number(r.showorder) || 0), 0);
        const sumRow = (label, predicate, order, kind) => {
            const row = { [NAME_COL]: label, showorder: order, _total: true, [kind]: true };
            gradeCols.forEach(gc => { row[gc] = round2(work.filter(predicate).reduce((s, r) => s + num(r[gc]), 0)); });
            return row;
        };

        const extras = [];
        // 3. Weapon System Manpower subtotals (Active-military "A*" pay plans only).
        if (summary === 'Weapon System Manpower' && /^A/i.test(payPlan)) {
            extras.push(sumRow('WEAPON SYSTEM MANPOWER Total', r => String(r.appn ?? '') !== 'Federal OM', maxShow + 1, '_subtotal'));
            if (work.some(r => String(r.appn ?? '') === 'Federal OM'))
                extras.push(sumRow('FEDERAL OM Total', r => String(r.appn ?? '') === 'Federal OM', maxShow + 2, '_subtotal'));
        }
        // 4. Grand Total (every summary except Ancillary), over the detail rows only.
        if (summary !== 'Ancillary')
            extras.push(sumRow('Total', r => !String(r[NAME_COL] ?? '').toLowerCase().endsWith('total'), maxShow + 3, '_grand'));

        return [...work, ...extras];
    }

    function renderTable(rows, isCce) {
        if (!rows || rows.length === 0) return '<div class="alert alert-light border mb-3">No data returned for this grid.</div>';
        const dataRows = rows.filter(r => !r._total);
        const headers = orderHeaders(Object.keys(dataRows[0] ?? rows[0]));
        const gradeCols = headers.filter(isGradeCol);

        // CCE parity: legacy highlights the ENTIRE grade column (and shows the note) when a value
        // equals the salary-limit sentinel (cceMaxPayFootnote), not per-cell on > limit.
        const cceCols = (isCce && cceSalaryLimit > 0)
            ? gradeCols.filter(gc => dataRows.some(r => num(r[gc]) === cceSalaryLimit))
            : [];

        const head = headers.map(h => `<th${isGradeCol(h) ? ' class="text-end"' : ''}>${h}</th>`).join('');
        const body = rows.map(row => {
            const isTotal = !!row._total, isGrand = !!row._grand;
            const rowText = headers.map(h => String(row[h] ?? '')).join(' ').toUpperCase();
            const isWeapon = !isTotal && rowText.includes('WEAPON SYSTEM');
            const cells = headers.map(h => {
                const val = row[h];
                const grade = isGradeCol(h);
                let bg = null, fg = '';
                if (isTotal) {
                    bg = isGrand ? '#343a40' : '#dee2e6';
                    fg = isGrand ? 'color:#fff;' : '';
                } else {
                    bg = appropColor(val);
                    if (!bg && isWeapon) bg = WEAPON_COLOR;
                    if (bg) fg = 'color:#fff;';
                    else if (cceCols.includes(h)) bg = SALARY_LIMIT_COLOR; // yellow, dark text
                }
                const style = bg ? ` style="background-color:${bg};${fg}"` : '';
                const text = grade && isNumeric(val) ? fmtMoney(val) : (val ?? '');
                return `<td${grade ? ' class="text-end"' : ''}${style}>${text}</td>`;
            }).join('');
            return `<tr${isTotal ? ' class="fw-bold"' : ''}>${cells}</tr>`;
        }).join('');

        // Show the CCE over-limit highlight note only when a column actually hit the sentinel.
        const note = el('cceHighlightNote');
        if (note) note.classList.toggle('d-none', cceCols.length === 0);

        return `<div class="table-responsive mb-3"><table class="table table-sm table-bordered align-middle mb-0">`
            + `<thead class="table-dark"><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
    }

    function buildChart(table, payPlan, summary) {
        const chartEl = el('amcosLiteChart');
        chartEl.innerHTML = '';
        if (payPlan === 'CCE') { chartEl.innerHTML = '<div class="text-muted small">Graph is not available for Contractor Cost Estimate.</div>'; return; }
        if (summary && summary !== 'Default') { chartEl.innerHTML = '<div class="text-muted small">Graph is only available for the Default cost summary.</div>'; return; }
        if (!table || !table.rows || table.rows.length === 0 || typeof c3 === 'undefined') return;
        const headers = Object.keys(table.rows[0]);
        const gradeCols = headers.filter(h => table.rows.every(r => r[h] == null || isNumeric(r[h])) && looksLikeMoney(h));
        const labelCol = headers.find(h => !gradeCols.includes(h)) || headers[0];
        if (gradeCols.length === 0) return;
        const columns = [['x', ...gradeCols]];
        table.rows.forEach(r => {
            const label = String(r[labelCol] ?? 'Series');
            if (/total/i.test(label)) return;
            columns.push([label, ...gradeCols.map(g => (r[g] == null ? 0 : num(r[g])))]);
        });
        try {
            c3.generate({
                bindto: '#amcosLiteChart', size: { height: 420 },
                data: { x: 'x', columns, type: 'bar' },
                axis: { x: { type: 'category' }, y: { tick: { format: d3.format('$,.0f') } } },
                grid: { y: { lines: [{ value: 0 }] } }
            });
        } catch (e) { chartEl.innerHTML = `<div class="text-muted small">Chart unavailable: ${e.message}</div>`; }
    }

    function renderLegend() {
        const legendEl = el('liteLegend');
        const items = [
            ['Active OMA/MPA', '#6A9303'], ['Federal OM', '#00008B'], ['DoD OMDW', '#7030A0'],
            ['ARNG', '#8BA103'], ['USAR', '#6E8003'], ['CCE', '#006D8B'],
            ['Weapon System', WEAPON_COLOR], ['Over CCE salary limit', SALARY_LIMIT_COLOR]
        ];
        legendEl.innerHTML = items.map(([t, c]) =>
            `<span class="me-2"><span style="display:inline-block;width:10px;height:10px;background:${c};border:1px solid #999;"></span> ${t}</span>`).join('');
        legendEl.classList.remove('d-none');
    }

    // Renders the inflation-rate header table (legacy default.aspx PopulateRateHeader). The server
    // handler picks the column set per pay-plan family; values are fractional and shown as percent.
    async function renderInflationHeader() {
        const tbl = el('inflationRatesTable');
        if (!tbl) return;
        try {
            const params = new URLSearchParams({
                payPlan: costsFilter.payPlan,
                conversionType: costsFilter.inflationConversion,
                year: costsFilter.inflationYear
            });
            const res = await fetch(`?handler=InflationHeader&${params.toString()}`, { headers: { Accept: 'application/json' } });
            if (!res.ok) throw new Error();
            const data = await res.json();
            if (!data.headers || !data.row) { hide('inflationRatesHeader'); hide('inflationRatesTable'); return; }
            const pct = v => (v === null || v === '' || isNaN(Number(v))) ? '' : (Number(v) * 100).toFixed(4) + '%';
            const head = data.headers.map(h => `<th>${h}</th>`).join('');
            const cells = data.headers.map(h =>
                `<td>${h === 'Appropriation' ? (data.row[h] ?? '') : pct(data.row[h])}</td>`).join('');
            tbl.innerHTML = `<table class="table table-sm table-bordered mb-0">`
                + `<thead class="table-secondary"><tr>${head}</tr></thead><tbody><tr>${cells}</tr></tbody></table>`;
            show('inflationRatesHeader'); show('inflationRatesTable');
        } catch {
            hide('inflationRatesHeader'); hide('inflationRatesTable');
        }
    }

    // Validates every currently-visible required filter (legacy amcos-common.js validateFilters /
    // isValidX). Hidden filters pass. Surfaces the legacy alert text and blocks the refresh.
    function validateFilters() {
        const visible = id => { const e = el(id); return e && !e.classList.contains('d-none'); };
        if (costsFilter.payPlan === '-1' || costsFilter.payPlan === '') {
            alert('Please select a pay plan from the list'); return false;
        }
        if (visible('categoryFilter')
            && costsFilter.categoryGroupCode === '-1' && costsFilter.categorySubgroupCode === '-1'
            && costsFilter.careerProgramNumber === '-1') {
            alert('Please select an option from the category list'); return false;
        }
        if (visible('locationFilter') && costsFilter.locationId === -1) {
            alert('Please select an option from the location list'); return false;
        }
        if (visible('strlFilter')
            && (costsFilter.scienceTechnologyReinventionLaboratory === '-1' || costsFilter.scienceTechnologyReinventionLaboratory === '')) {
            alert('Please select a laboratory from the list'); return false;
        }
        if (visible('dependentStatusFilter')
            && (costsFilter.dependentStatus === '-1' || costsFilter.dependentStatus === '')) {
            alert('Please select a dependent status from the list'); return false;
        }
        if (visible('numberOfDependentsFilter')
            && (isNaN(costsFilter.numberOfDependents) || costsFilter.numberOfDependents === -1)) {
            alert('Please select the number of dependents from the list'); return false;
        }
        if (visible('overheadPercentFilter')) {
            const ov = el('overheadPercent');
            if (!ov || ov.value === '' || isNaN(Number(ov.value))) {
                alert('Please enter an overhead percent'); return false;
            }
        }
        return true;
    }

    async function loadCosts() {
        stopBlink();
        alertForAllCostSummary();
        const status = el('liteStatus'), results = el('liteResults');

        if (!validateFilters()) {
            status.className = 'alert alert-warning';
            status.textContent = 'Please complete the required filters.';
            return;
        }

        // Per-refresh audit logging (server honors the AmcosLiteLogging mode).
        logFilter('ShowCostsButton');

        status.className = 'alert alert-info';
        status.textContent = 'Loading cost data...';
        results.innerHTML = '';
        el('amcosLiteChart').innerHTML = '';

        const params = new URLSearchParams({
            PayPlan: costsFilter.payPlan, CostSummaryName: costsFilter.costSummaryName,
            CategoryGroupCode: costsFilter.categoryGroupCode, CategorySubgroupCode: costsFilter.categorySubgroupCode,
            CareerProgramNumber: costsFilter.careerProgramNumber, LocationId: costsFilter.locationId,
            LocationText: costsFilter.locationText, ScienceTechnologyReinventionLaboratory: costsFilter.scienceTechnologyReinventionLaboratory,
            DependentStatus: costsFilter.dependentStatus, NumberOfDependents: costsFilter.numberOfDependents,
            OverheadPercent: costsFilter.overheadPercent, InflationConversionType: costsFilter.inflationConversion,
            InflationYear: costsFilter.inflationYear
        });

        try {
            const response = await fetch(`?handler=CostData&${params.toString()}`, { headers: { Accept: 'application/json' } });
            if (!response.ok) throw new Error(`Request failed with ${response.status}`);
            const payload = await response.json();
            const tables = payload.tables ?? [];
            const isCce = costsFilter.payPlan === 'CCE';
            // Legacy binds a single cost grid; the migrated payload carries just the 'costs' set,
            // so render that one (not every intermediate result set) with no per-grid heading.
            const costTable = tables.find(t => t.name === 'costs') ?? tables[0];
            if (!costTable || !costTable.rows || costTable.rows.length === 0) {
                results.innerHTML = '<div class="alert alert-light border">No data returned.</div>';
                hide('inflationRatesHeader'); hide('inflationRatesTable');
            } else {
                const rows = shapeCostTable(costTable.rows, costsFilter.costSummaryName, costsFilter.payPlan);
                results.innerHTML = renderTable(rows, isCce);
                buildChart({ rows: costTable.rows }, costsFilter.payPlan, costsFilter.costSummaryName);
                renderLegend();
                await renderInflationHeader();
                show('exportButton');
            }
            status.className = 'alert alert-success';
            status.textContent = costTable && costTable.rows && costTable.rows.length
                ? 'Cost data loaded.' : 'No data returned.';
        } catch (error) {
            status.className = 'alert alert-danger';
            status.textContent = error.message;
        }
    }

    // Downloads the current (last-refreshed) grid as a formatted .xlsx (legacy Download Excel).
    function exportCosts() {
        const params = new URLSearchParams({
            PayPlan: costsFilter.payPlan, CostSummaryName: costsFilter.costSummaryName,
            CategoryGroupCode: costsFilter.categoryGroupCode, CategorySubgroupCode: costsFilter.categorySubgroupCode,
            CareerProgramNumber: costsFilter.careerProgramNumber, LocationId: costsFilter.locationId,
            LocationText: costsFilter.locationText, ScienceTechnologyReinventionLaboratory: costsFilter.scienceTechnologyReinventionLaboratory,
            DependentStatus: costsFilter.dependentStatus, NumberOfDependents: costsFilter.numberOfDependents,
            OverheadPercent: costsFilter.overheadPercent, InflationConversionType: costsFilter.inflationConversion,
            InflationYear: costsFilter.inflationYear
        });
        window.location = `?handler=Export&${params.toString()}`;
    }

    // ---- Wire up ----
    function init() {
        const bind = (id, evt, fn) => { const e = el(id); if (e) e.addEventListener(evt, fn); };
        bind('payPlanList', 'change', onPayPlanChange);
        bind('categoryList', 'change', onCategoryChange);
        bind('locationList', 'change', onLocationChange);
        bind('strlList', 'change', onStrlChange);
        bind('costSummaryList', 'change', onCostSummaryChange);
        bind('dependentStatusList', 'change', onDependentStatusChange);
        bind('numberOfDependentsList', 'change', onNumberOfDependentsChange);
        bind('inflationConversionTypeList', 'change', onInflationConversionChange);
        bind('inflationYearList', 'change', onInflationYearChange);
        bind('overheadPercent', 'input', onOverheadChange);
        bind('showCostsButton', 'click', loadCosts);
        bind('exportButton', 'click', exportCosts);
        stopBlink();
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
})();
