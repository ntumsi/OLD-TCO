// Project Manager — native (Bootstrap 5) cascading filter for the "Add Position"
// form on the Faces & Spaces tab. Port of the legacy project-manager.js / amcos-common.js
// cascade onto the LookupApiController (/api/*) endpoints. No jQuery / selectize.
//
// Exposes window.pmRequirement (the resolved selection the page's Insert handler reads)
// and window.pmResetRequirement(). Requires object-payplan.js (payPlanObject) loaded
// first, plus window._baseApiUrl and window._amcosVersionId.
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
    const reserveComponentPayPlans = armyNationalGuardPayPlans.concat(armyReservePayPlans);

    const inIn = (arr, v) => arr.indexOf(v) !== -1;
    const baseApi = (window._baseApiUrl || '/api');
    const amcosVersionId = Number(window._amcosVersionId || 0);

    // ---- Resolved selection the page's Insert handler consumes ----
    const req = {
        payPlan: '-1',
        categoryGroupCode: '-1', categorySubgroupCode: '-1', careerProgramNumber: '-1',
        locationId: -1, locationText: '-1', strl: '-1', gradeLevel: 1,
        dependentStatus: '-1', numberOfDependents: -1, activeDutyDays: 15, overheadPercent: 0
    };
    window.pmRequirement = req;

    // ---- DOM helpers ----
    const el = id => document.getElementById(id);
    const show = id => { const e = el(id); if (e) e.classList.remove('d-none'); };
    const hide = id => { const e = el(id); if (e) e.classList.add('d-none'); };

    function fill(select, items, { valueField = 'Value', textField = 'Text', groupField = null,
        groupOrder = [], groupLabels = {}, placeholder = null, disabled = false } = {}) {
        if (!select) return;
        select.innerHTML = '';
        if (placeholder !== null) {
            const o = document.createElement('option');
            o.value = '-1'; o.textContent = placeholder;
            select.appendChild(o);
        }
        const append = (parent, item) => {
            const o = document.createElement('option');
            o.value = item[valueField]; o.textContent = item[textField];
            parent.appendChild(o);
        };
        if (groupField) {
            const keys = groupOrder.length ? groupOrder : [...new Set(items.map(i => i[groupField]))];
            keys.forEach(key => {
                const groupItems = items.filter(i => String(i[groupField]).toLowerCase() === String(key).toLowerCase());
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

    const payPlanIndex = pp => (typeof payPlanObject !== 'undefined' ? payPlanObject.findIndex(p => p.payPlanValue === pp) : -1);

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

    async function apiGet(url) {
        const res = await fetch(url, { headers: { Accept: 'application/json' } });
        if (!res.ok) throw new Error(`${url} -> ${res.status}`);
        return res.json();
    }

    // ---- Loaders ----
    async function loadPayPlans() {
        try {
            const items = await apiGet(`${baseApi}/payplans`);
            fill(el('reqPayPlan'), items, {
                groupField: 'OptionGroup', groupOrder: ['Military', 'Civilian'],
                groupLabels: { Military: 'Military', Civilian: 'Civilian' }, placeholder: 'Select a Pay Plan'
            });
        } catch (e) { fill(el('reqPayPlan'), [], { placeholder: 'Pay plans unavailable' }); }
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
            fill(el('reqCategory'), items, { groupField: 'OptionGroup', groupOrder, groupLabels, placeholder });
        } catch (e) { fill(el('reqCategory'), [], { placeholder: 'Categories unavailable' }); }
    }

    async function loadLocationList(payPlan, group, sub, career) {
        const sel = el('reqLocation');
        sel.disabled = true;
        try {
            const url = `${baseApi}/locations/${encodeURIComponent(payPlan)}/${encodeURIComponent(group)}/${encodeURIComponent(sub)}/${encodeURIComponent(career)}`;
            const items = await apiGet(url);
            fill(sel, items, { groupField: 'OptionGroup', groupOrder: LOCATION_GROUP_ORDER, groupLabels: LOCATION_GROUP_LABELS, placeholder: 'Select a Location' });
            sel.disabled = false;
        } catch (e) { fill(sel, [], { placeholder: 'Locations unavailable' }); }
    }

    async function loadStrlList(payPlan, group, sub, career, locationId) {
        try {
            const url = `${baseApi}/strls/${encodeURIComponent(payPlan)}/${encodeURIComponent(group)}/${encodeURIComponent(sub)}/${encodeURIComponent(career)}/${locationId}`;
            const items = await apiGet(url);
            fill(el('reqSTRL'), items, { placeholder: 'Select a Laboratory' });
        } catch (e) { fill(el('reqSTRL'), [], { placeholder: 'Laboratories unavailable' }); }
    }

    // Grade depends on the full classification; reload whenever it changes.
    async function loadGrades(payPlan, group, sub, career, locationId) {
        const sel = el('reqGradeLevel');
        try {
            const url = `${baseApi}/grades/${encodeURIComponent(payPlan)}/${encodeURIComponent(group)}/${encodeURIComponent(sub)}/${encodeURIComponent(career)}/${locationId}?amcosVersionId=${amcosVersionId}`;
            const items = await apiGet(url);
            fill(sel, items, { placeholder: 'Select a Grade' });
            req.gradeLevel = 1;
            show('reqGradeWrap');
        } catch (e) { fill(sel, [], { placeholder: 'Grades unavailable' }); show('reqGradeWrap'); }
    }

    // ---- Visibility orchestration (mirrors legacy setVisibleElements) ----
    function setVisibleElements(payPlan) {
        ['reqLocationWrap', 'reqStrlWrap', 'reqDependentStatusWrap', 'reqNumDependentsWrap',
            'reqActiveDutyDaysWrap', 'reqOverheadWrap', 'reqGradeWrap'].forEach(hide);

        if (inIn(reserveComponentPayPlans, payPlan)) {
            // NG/Reserve: no location, but active-duty-days applies.
            show('reqActiveDutyDaysWrap');
            if (el('reqActiveDutyDays')) el('reqActiveDutyDays').value = '15';
            req.activeDutyDays = 15;
        } else if (inIn(activeDutyArmyPayPlans, payPlan)) {
            // Active duty army: location appears after a category is chosen.
        } else if (inIn(laboratoryDemoPayPlans, payPlan)) {
            show('reqLocationWrap'); show('reqStrlWrap');
        } else if (inIn(acquisitionDemoPayPlans, payPlan)) {
            show('reqLocationWrap');
        } else if (inIn(civilianPayPlans, payPlan) || payPlan === 'CCE') {
            show('reqLocationWrap');
            if (payPlan === 'CCE') { show('reqOverheadWrap'); if (el('reqOverheadPct')) el('reqOverheadPct').value = '0'; req.overheadPercent = 0; }
        } else if (inIn(wageAppropriatedFundPayPlans, payPlan) || inIn(wageNonAppropriatedFundPayPlans, payPlan)) {
            show('reqLocationWrap');
        }

        show('reqCategoryWrap');
        loadCategoryList(payPlan);
        const loc = el('reqLocation');
        if (loc) { fill(loc, [], { placeholder: 'Select a category first' }); loc.disabled = true; }
    }

    // ---- Change handlers ----
    function onPayPlanChange() {
        const payPlan = el('reqPayPlan').value;
        Object.assign(req, {
            payPlan, categoryGroupCode: '-1', categorySubgroupCode: '-1', careerProgramNumber: '-1',
            locationId: -1, locationText: '-1', strl: '-1', gradeLevel: 1,
            dependentStatus: '-1', numberOfDependents: -1, activeDutyDays: 15, overheadPercent: 0
        });
        if (payPlan === '-1' || payPlan === '') {
            ['reqCategoryWrap', 'reqLocationWrap', 'reqStrlWrap', 'reqDependentStatusWrap',
                'reqNumDependentsWrap', 'reqActiveDutyDaysWrap', 'reqOverheadWrap', 'reqGradeWrap'].forEach(hide);
            return;
        }
        setVisibleElements(payPlan);
    }

    function onCategoryChange() {
        const category = el('reqCategory').value;
        const parsed = parseCategory(req.payPlan, category);
        req.categoryGroupCode = parsed.categoryGroupCode;
        req.categorySubgroupCode = parsed.categorySubgroupCode;
        req.careerProgramNumber = parsed.careerProgramNumber;
        req.locationId = -1; req.locationText = '-1';
        hide('reqDependentStatusWrap'); hide('reqNumDependentsWrap');

        const pp = req.payPlan;
        if (inIn(activeDutyArmyPayPlans, pp)) {
            if (req.categoryGroupCode === '-1' || req.categorySubgroupCode === '-1') hide('reqLocationWrap');
            else { show('reqLocationWrap'); loadLocationList(pp, req.categoryGroupCode, req.categorySubgroupCode, req.careerProgramNumber); }
        } else if (inIn(payPlansThatDoNotUseLocation, pp)) {
            hide('reqLocationWrap');
        } else {
            show('reqLocationWrap'); loadLocationList(pp, req.categoryGroupCode, req.categorySubgroupCode, req.careerProgramNumber);
        }
        if (category !== '-1') loadGrades(pp, req.categoryGroupCode, req.categorySubgroupCode, req.careerProgramNumber, req.locationId);
        else hide('reqGradeWrap');
    }

    function onLocationChange() {
        const sel = el('reqLocation');
        const value = sel.value;
        const opt = sel.options[sel.selectedIndex];
        req.locationId = value && value !== '-1' ? parseInt(value.split('.')[0], 10) : -1;
        req.locationText = opt ? opt.textContent : '-1';
        const locationType = value ? value.split('.')[2] : undefined;

        const pp = req.payPlan;
        if (inIn(activeDutyArmyPayPlans, pp)) {
            hide('reqNumDependentsWrap');
            if (req.locationId === -1 || locationType === 'mha-oconus') hide('reqDependentStatusWrap');
            else show('reqDependentStatusWrap');
        } else if (inIn(laboratoryDemoPayPlans, pp)) {
            loadStrlList(pp, req.categoryGroupCode, req.categorySubgroupCode, req.careerProgramNumber, req.locationId);
            show('reqStrlWrap');
        } else if (inIn(payPlansThatContainCivilianOverseasLocations, pp)) {
            if (req.locationId !== -1 && locationType === 'civilianOverseasArea') { show('reqNumDependentsWrap'); hide('reqDependentStatusWrap'); }
            else { hide('reqDependentStatusWrap'); hide('reqNumDependentsWrap'); }
        } else {
            hide('reqDependentStatusWrap'); hide('reqNumDependentsWrap');
        }
        loadGrades(pp, req.categoryGroupCode, req.categorySubgroupCode, req.careerProgramNumber, req.locationId);
    }

    function resetRequirement() {
        Object.assign(req, {
            payPlan: '-1', categoryGroupCode: '-1', categorySubgroupCode: '-1', careerProgramNumber: '-1',
            locationId: -1, locationText: '-1', strl: '-1', gradeLevel: 1,
            dependentStatus: '-1', numberOfDependents: -1, activeDutyDays: 15, overheadPercent: 0
        });
        if (el('reqPayPlan')) el('reqPayPlan').value = '-1';
        ['reqCategoryWrap', 'reqLocationWrap', 'reqStrlWrap', 'reqDependentStatusWrap',
            'reqNumDependentsWrap', 'reqActiveDutyDaysWrap', 'reqOverheadWrap', 'reqGradeWrap'].forEach(hide);
    }
    window.pmResetRequirement = resetRequirement;

    function init() {
        if (!el('reqPayPlan')) return; // Add Position form not on this page
        const bind = (id, fn) => { const e = el(id); if (e) e.addEventListener('change', fn); };
        bind('reqPayPlan', onPayPlanChange);
        bind('reqCategory', onCategoryChange);
        bind('reqLocation', onLocationChange);
        bind('reqSTRL', () => { req.strl = el('reqSTRL').value || '-1'; });
        bind('reqDependentStatus', () => { req.dependentStatus = el('reqDependentStatus').value || '-1'; });
        bind('reqNumDependents', () => { const n = parseInt(el('reqNumDependents').value, 10); req.numberOfDependents = isNaN(n) ? -1 : n; });
        bind('reqGradeLevel', () => { req.gradeLevel = parseInt(el('reqGradeLevel').value, 10) || 1; });
        const adId = el('reqActiveDutyDays'); if (adId) adId.addEventListener('input', () => { req.activeDutyDays = parseInt(adId.value, 10) || 15; });
        const ohId = el('reqOverheadPct'); if (ohId) ohId.addEventListener('input', () => { req.overheadPercent = parseFloat(ohId.value) || 0; });
        loadPayPlans();
        resetRequirement();
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
})();
