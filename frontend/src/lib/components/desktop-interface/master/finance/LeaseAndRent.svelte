<script lang="ts">
    import { _ as t, locale } from '$lib/i18n';
    import { supabase } from '$lib/utils/supabase';

    let activeTab: 'lease' | 'rent' | 'leaseSpecial' | 'rentSpecial' | 'payments' | 'reports' | 'manager' = 'manager';

    // Format date from YYYY-MM-DD (or ISO datetime) to DD-MM-YYYY
    function fmtDate(d: string | null | undefined): string {
        if (!d) return '';
        const iso = d.length > 10 ? d.substring(0, 10) : d;
        const parts = iso.split('-');
        if (parts.length !== 3) return d;
        return `${parts[2]}-${parts[1]}-${parts[0]}`;
    }

    $: tabs = [
        { id: 'lease' as const, label: $t('finance.leaseAndRent.leaseTab'), icon: '📋', color: 'green' },
        { id: 'rent' as const, label: $t('finance.leaseAndRent.rentTab'), icon: '🏠', color: 'orange' },
        { id: 'leaseSpecial' as const, label: $t('finance.leaseAndRent.leaseSpecialTab'), icon: '✨', color: 'blue' },
        { id: 'rentSpecial' as const, label: $t('finance.leaseAndRent.rentSpecialTab'), icon: '🔧', color: 'purple' },
        { id: 'payments' as const, label: $t('finance.leaseAndRent.paymentsTab'), icon: '💰', color: 'indigo' },
        { id: 'reports' as const, label: $t('finance.leaseAndRent.reportsTab'), icon: '📊', color: 'cyan' },
        { id: 'manager' as const, label: $t('finance.leaseAndRent.managerTab'), icon: '🛠️', color: 'red' }
    ];

    // Payment type state (for Payments tab)
    let paymentType: 'lease' | 'rent' | null = null;
    let paymentPartySearch = '';
    let showPaymentPartyDropdown = false;
    let selectedPaymentParty: any = null;

    $: filteredPaymentParties = (paymentType === 'rent' ? rentRecords : paymentType === 'lease' ? leaseRecords : []).filter(r => {
        if (!paymentPartySearch.trim()) return true;
        const q = paymentPartySearch.toLowerCase();
        return (r.party_name_en || '').toLowerCase().includes(q) || (r.party_name_ar || '').includes(q);
    });

    function selectPaymentParty(party: any) {
        selectedPaymentParty = party;
        paymentPartySearch = '';
        showPaymentPartyDropdown = false;
        // Load changes for this party
        loadPaymentScheduleChanges();
    }

    function clearPaymentParty() {
        selectedPaymentParty = null;
        paymentPartySearch = '';
        paymentSchedule = [];
    }

    // Payment schedule
    let paymentSchedule: any[] = [];
    let paymentScheduleChanges: any[] = [];

    async function loadPaymentScheduleChanges() {
        if (!selectedPaymentParty || !paymentType) return;
        // Single RPC: get changes + entries in one call
        const { data, error } = await supabase.rpc('get_party_payment_data', {
            p_party_type: paymentType,
            p_party_id: selectedPaymentParty.id
        });
        if (!error && data) {
            paymentScheduleChanges = data.changes || [];
            // Pre-load payment entries from same response
            const entries = data.entries || [];
            const map: Record<string, any[]> = {};
            for (const entry of entries) {
                const key = `${entry.period_num}_${entry.column_name}`;
                if (!map[key]) map[key] = [];
                map[key].push(entry);
            }
            paymentEntriesMap = map;
        } else {
            paymentScheduleChanges = [];
            paymentEntriesMap = {};
        }
        generatePaymentSchedule();
    }

    function generatePaymentSchedule() {
        if (!selectedPaymentParty || !paymentType) { paymentSchedule = []; return; }
        const party = selectedPaymentParty;
        const startDate = party.contract_start_date ? new Date(party.contract_start_date) : null;
        if (!startDate) { paymentSchedule = []; return; }

        let endDate: Date;
        if (party.is_open_contract || !party.contract_end_date) {
            // Open contract: show 24 months from start
            endDate = new Date(startDate);
            endDate.setMonth(endDate.getMonth() + 24);
        } else {
            endDate = new Date(party.contract_end_date);
        }

        const period = party.payment_period || 'monthly';
        const isRent = paymentType === 'rent';
        const baseContract = Number(isRent ? party.rent_amount_contract : party.lease_amount_contract) || 0;
        const baseOutside = Number(isRent ? party.rent_amount_outside_contract : party.lease_amount_outside_contract) || 0;
        const baseUtility = Number(party.utility_charges) || 0;
        const baseSecurity = Number(party.security_charges) || 0;
        const baseOther = party.other_charges ? party.other_charges.reduce((s: number, c: any) => s + (Number(c.amount) || 0), 0) : 0;

        const schedule: any[] = [];
        let current = new Date(startDate);
        let periodNum = 1;

        while (current < endDate) {
            let periodEnd = new Date(current);
            if (period === 'daily') periodEnd.setDate(periodEnd.getDate() + 1);
            else if (period === 'monthly') periodEnd.setMonth(periodEnd.getMonth() + 1);
            else if (period === 'every_3_months') periodEnd.setMonth(periodEnd.getMonth() + 3);
            else if (period === 'every_6_months') periodEnd.setMonth(periodEnd.getMonth() + 6);
            else if (period === 'yearly') periodEnd.setFullYear(periodEnd.getFullYear() + 1);
            else periodEnd.setMonth(periodEnd.getMonth() + 1);

            if (periodEnd > endDate) periodEnd = new Date(endDate);

            const periodFrom = current.toISOString().split('T')[0];
            const periodTo = periodEnd.toISOString().split('T')[0];

            // Check for changes applying to this period
            let amtContract = baseContract;
            let amtOutside = baseOutside;
            let amtUtility = baseUtility;
            let amtSecurity = baseSecurity;
            let hasChange = false;
            const appliedChanges: string[] = [];

            const amtPrefix = isRent ? 'rent_amount' : 'lease_amount';
            for (const ch of paymentScheduleChanges) {
                const chFrom = ch.effective_from;
                const chUntil = ch.effective_until || (ch.till_end_of_contract ? endDate.toISOString().split('T')[0] : null);
                // Check if change overlaps this period
                if (chFrom <= periodTo && (!chUntil || chUntil >= periodFrom)) {
                    hasChange = true;
                    const label = (ch.field_name || '').replace(/_/g, ' ');
                    if (ch.field_name === `${amtPrefix}_contract`) { amtContract = Number(ch.new_value); appliedChanges.push(label); }
                    else if (ch.field_name === `${amtPrefix}_outside_contract`) { amtOutside = Number(ch.new_value); appliedChanges.push(label); }
                    else if (ch.field_name === 'utility_charges') { amtUtility = Number(ch.new_value); appliedChanges.push(label); }
                    else if (ch.field_name === 'security_charges') { amtSecurity = Number(ch.new_value); appliedChanges.push(label); }
                    else { appliedChanges.push(label); }
                }
            }

            const total = amtContract + amtOutside + amtUtility + amtSecurity + baseOther;

            schedule.push({
                num: periodNum,
                from: periodFrom,
                to: periodTo,
                amtContract,
                amtOutside,
                amtUtility,
                amtSecurity,
                amtOther: baseOther,
                total,
                hasChange,
                appliedChanges
            });

            current = new Date(periodEnd);
            periodNum++;
            if (periodNum > 500) break; // safety limit
        }
        paymentSchedule = schedule;
        // Apply already-loaded payment entries to schedule rows (no extra query needed)
        applyPaymentEntriesToSchedule();
    }

    function applyPaymentEntriesToSchedule() {
        for (const row of paymentSchedule) {
            row.paidContract = sumEntries(row.num, 'contract');
            row.paidOutside = sumEntries(row.num, 'outside');
            row.paidUtility = sumEntries(row.num, 'utility');
            row.paidSecurity = sumEntries(row.num, 'security');
            row.paidOther = sumEntries(row.num, 'other');
        }
        paymentSchedule = [...paymentSchedule];
    }

    // Payment entries from DB - keyed by "periodNum_columnName"
    let paymentEntriesMap: Record<string, any[]> = {};
    let paymentSaving = false;

    // Payment popup state
    let showPaymentPopup = false;
    let paymentPopupRow: any = null;
    let paymentPopupColumn = '';
    let paymentPopupColumnLabel = '';
    let paymentPopupTotalDue = 0;
    let paymentPopupAlreadyPaid = 0;
    let paymentPopupRemaining = 0;
    let paymentPopupMode: 'full' | 'partial' = 'full';
    let paymentPopupAmount = 0;
    let paymentPopupEntries: any[] = [];

    async function loadPaymentEntries() {
        if (!selectedPaymentParty || !paymentType) return;
        // Uses single RPC to reload entries only (after saving a new entry)
        const { data, error } = await supabase.rpc('get_party_payment_data', {
            p_party_type: paymentType,
            p_party_id: selectedPaymentParty.id
        });
        if (!error && data) {
            const entries = data.entries || [];
            const map: Record<string, any[]> = {};
            for (const entry of entries) {
                const key = `${entry.period_num}_${entry.column_name}`;
                if (!map[key]) map[key] = [];
                map[key].push(entry);
            }
            paymentEntriesMap = map;
            // Apply to schedule rows
            for (const row of paymentSchedule) {
                row.paidContract = sumEntries(row.num, 'contract');
                row.paidOutside = sumEntries(row.num, 'outside');
                row.paidUtility = sumEntries(row.num, 'utility');
                row.paidSecurity = sumEntries(row.num, 'security');
                row.paidOther = sumEntries(row.num, 'other');
            }
            paymentSchedule = [...paymentSchedule];
        } else {
            paymentEntriesMap = {};
        }
    }

    function sumEntries(periodNum: number, column: string): number {
        const key = `${periodNum}_${column}`;
        const entries = paymentEntriesMap[key];
        if (!entries || entries.length === 0) return 0;
        return entries.reduce((s: number, e: any) => s + (Number(e.amount) || 0), 0);
    }

    function getColumnAmount(row: any, column: string): number {
        if (column === 'contract') return row.amtContract;
        if (column === 'outside') return row.amtOutside;
        if (column === 'utility') return row.amtUtility;
        if (column === 'security') return row.amtSecurity;
        if (column === 'other') return row.amtOther;
        return 0;
    }

    function getColumnPaid(row: any, column: string): number {
        if (column === 'contract') return Number(row.paidContract) || 0;
        if (column === 'outside') return Number(row.paidOutside) || 0;
        if (column === 'utility') return Number(row.paidUtility) || 0;
        if (column === 'security') return Number(row.paidSecurity) || 0;
        if (column === 'other') return Number(row.paidOther) || 0;
        return 0;
    }

    function isColumnFullyPaid(row: any, column: string): boolean {
        return getColumnPaid(row, column) >= getColumnAmount(row, column);
    }

    function getLastPaidDate(row: any, column: string): string {
        const key = `${row.num}_${column}`;
        const entries = paymentEntriesMap[key];
        if (!entries || entries.length === 0) return '';
        return fmtDate(entries[entries.length - 1].paid_date) || '';
    }

    function getPaidAmount(row: any): number {
        return (Number(row.paidContract) || 0) + (Number(row.paidOutside) || 0) + (Number(row.paidUtility) || 0) + (Number(row.paidSecurity) || 0) + (Number(row.paidOther) || 0);
    }

    function isFullyPaid(row: any): boolean {
        return row.paidContract >= row.amtContract && row.paidOutside >= row.amtOutside && row.paidUtility >= row.amtUtility && row.paidSecurity >= row.amtSecurity && row.paidOther >= row.amtOther;
    }

    function isPartiallyPaid(row: any): boolean {
        return getPaidAmount(row) > 0 && !isFullyPaid(row);
    }

    const columnLabels: Record<string, string> = {
        contract: 'Base Amount',
        outside: 'Outside Contract',
        utility: 'Utility',
        security: 'Security',
        other: 'Other'
    };

    function openPaymentPopup(row: any, column: string) {
        const totalDue = getColumnAmount(row, column);
        const alreadyPaid = getColumnPaid(row, column);
        const remaining = Math.max(totalDue - alreadyPaid, 0);
        paymentPopupRow = row;
        paymentPopupColumn = column;
        paymentPopupColumnLabel = columnLabels[column] || column;
        paymentPopupTotalDue = totalDue;
        paymentPopupAlreadyPaid = alreadyPaid;
        paymentPopupRemaining = remaining;
        paymentPopupMode = 'full';
        paymentPopupAmount = remaining;
        // Load history entries for this cell
        const key = `${row.num}_${column}`;
        paymentPopupEntries = paymentEntriesMap[key] || [];
        showPaymentPopup = true;
    }

    async function savePaymentEntry() {
        if (!selectedPaymentParty || !paymentType || !paymentPopupRow || paymentSaving) return;
        const amount = paymentPopupMode === 'full' ? paymentPopupRemaining : Math.min(Math.max(Number(paymentPopupAmount) || 0, 0.01), paymentPopupRemaining);
        paymentSaving = true;
        try {
            const { error } = await supabase
                .from('lease_rent_payment_entries')
                .insert({
                    party_type: paymentType,
                    party_id: selectedPaymentParty.id,
                    period_num: paymentPopupRow.num,
                    column_name: paymentPopupColumn,
                    amount: amount,
                    paid_date: new Date().toISOString().split('T')[0]
                });
            if (error) {
                console.error('Save payment entry error:', error);
            } else {
                showPaymentPopup = false;
                await loadPaymentEntries();
            }
        } finally {
            paymentSaving = false;
        }
    }

    let leaseRecords: any[] = [];
    let leasePartiesLoaded = false;
    let leasePartiesLoading = false;
    let rentRecords: any[] = [];
    let rentPartiesLoaded = false;
    let rentPartiesLoading = false;

    // ===== REPORTS TAB STATE =====
    let reportType: 'lease' | 'rent' | null = null;
    let reportLoading = false;
    let reportMonths: string[] = [];
    let reportMonthLabels: string[] = [];
    let reportRows: any[] = [];
    let reportAllEntries: any[] = [];
    let reportAllChanges: any[] = [];
    let reportGenerated = false;

    // Report popup state
    let showReportPopup = false;
    let reportPopupType: 'lease' | 'rent' = 'lease';
    let reportPartySearch = '';
    let reportSelectedPartyIds: Set<string> = new Set();
    let reportDateFrom = '';
    let reportDateTo = '';
    let reportPartySummaries: Record<string, { totalDue: number; totalPaid: number }> = {};
    let reportPartiesLoading = false;

    // Load current month report directly for ALL parties
    async function loadCurrentMonthReport(type: 'lease' | 'rent') {
        reportType = type;
        reportLoading = true;
        reportGenerated = false;
        reportRows = [];
        reportMonths = [];
        reportMonthLabels = [];

        // Ensure parties are loaded
        if (type === 'lease' && !leasePartiesLoaded) await loadLeasePartiesForTab();
        if (type === 'rent' && !rentPartiesLoaded) await loadRentPartiesForTab();

        const parties = type === 'lease' ? leaseRecords : rentRecords;
        if (parties.length === 0) { reportLoading = false; reportGenerated = true; return; }

        const today = new Date();
        const currentMonthKey = today.toISOString().slice(0, 7);
        const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        reportMonths = [currentMonthKey];
        reportMonthLabels = [`${monthNames[today.getMonth()]} ${today.getFullYear()}`];
        const dateFrom = `${currentMonthKey}-01`;
        const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
        const dateTo = `${currentMonthKey}-${String(lastDay).padStart(2, '0')}`;

        await buildReportRows(type, parties, [currentMonthKey], dateFrom, dateTo);
    }

    // Open popup for custom report generation
    async function openReportPopup(type: 'lease' | 'rent') {
        reportPopupType = type;
        reportPartySearch = '';
        reportSelectedPartyIds = new Set();
        reportDateFrom = '';
        reportDateTo = new Date().toISOString().split('T')[0];
        reportPartySummaries = {};
        reportPartiesLoading = true;
        showReportPopup = true;

        // Ensure parties are loaded
        if (type === 'lease' && !leasePartiesLoaded) await loadLeasePartiesForTab();
        if (type === 'rent' && !rentPartiesLoaded) await loadRentPartiesForTab();

        const parties = type === 'lease' ? leaseRecords : rentRecords;

        // Server-side SUM per party (single RPC, tiny response)
        const { data: paidTotals } = await supabase.rpc('get_report_party_paid_totals', { p_party_type: type });
        const paidMap: Record<string, number> = {};
        if (paidTotals) {
            for (const [pid, total] of Object.entries(paidTotals)) {
                paidMap[pid] = Number(total) || 0;
            }
        }

        // Compute total due per party
        const summaries: Record<string, { totalDue: number; totalPaid: number }> = {};
        const isRent = type === 'rent';
        const today = new Date();

        for (const party of parties) {
            const startDate = party.contract_start_date ? new Date(party.contract_start_date) : null;
            if (!startDate) { summaries[party.id] = { totalDue: 0, totalPaid: paidMap[party.id] || 0 }; continue; }

            let endDate: Date;
            if (party.is_open_contract || !party.contract_end_date) {
                endDate = new Date(today);
            } else {
                endDate = new Date(party.contract_end_date);
                if (endDate > today) endDate = new Date(today);
            }

            const baseContract = Number(isRent ? party.rent_amount_contract : party.lease_amount_contract) || 0;
            const baseOutside = Number(isRent ? party.rent_amount_outside_contract : party.lease_amount_outside_contract) || 0;
            const baseUtility = Number(party.utility_charges) || 0;
            const baseSecurity = Number(party.security_charges) || 0;
            const baseOther = party.other_charges ? party.other_charges.reduce((s: number, c: any) => s + (Number(c.amount) || 0), 0) : 0;
            const perPeriod = baseContract + baseOutside + baseUtility + baseSecurity + baseOther;

            const period = party.payment_period || 'monthly';
            let periodCount = 0;
            let cur = new Date(startDate);
            while (cur < endDate && periodCount < 500) {
                if (period === 'daily') cur.setDate(cur.getDate() + 1);
                else if (period === 'monthly') cur.setMonth(cur.getMonth() + 1);
                else if (period === 'every_3_months') cur.setMonth(cur.getMonth() + 3);
                else if (period === 'every_6_months') cur.setMonth(cur.getMonth() + 6);
                else if (period === 'yearly') cur.setFullYear(cur.getFullYear() + 1);
                else cur.setMonth(cur.getMonth() + 1);
                periodCount++;
            }

            summaries[party.id] = { totalDue: perPeriod * periodCount, totalPaid: paidMap[party.id] || 0 };
        }
        reportPartySummaries = summaries;
        reportPartiesLoading = false;
    }

    $: reportFilteredParties = (() => {
        const parties = reportPopupType === 'lease' ? leaseRecords : reportPopupType === 'rent' ? rentRecords : [];
        if (!reportPartySearch.trim()) return parties;
        const q = reportPartySearch.toLowerCase();
        return parties.filter((r: any) => (r.party_name_en || '').toLowerCase().includes(q) || (r.party_name_ar || '').includes(q));
    })();

    function toggleReportParty(partyId: string) {
        const newSet = new Set(reportSelectedPartyIds);
        if (newSet.has(partyId)) newSet.delete(partyId);
        else newSet.add(partyId);
        reportSelectedPartyIds = newSet;
    }

    function selectAllReportParties() {
        const parties = reportPopupType === 'lease' ? leaseRecords : rentRecords;
        reportSelectedPartyIds = new Set(parties.map((p: any) => p.id));
    }

    function deselectAllReportParties() {
        reportSelectedPartyIds = new Set();
    }

    async function generateReport() {
        if (reportSelectedPartyIds.size === 0 || !reportDateFrom || !reportDateTo) return;
        showReportPopup = false;
        reportType = reportPopupType;
        reportLoading = true;
        reportGenerated = false;
        reportRows = [];
        reportMonths = [];
        reportMonthLabels = [];

        const parties = (reportPopupType === 'lease' ? leaseRecords : rentRecords).filter((p: any) => reportSelectedPartyIds.has(p.id));
        if (parties.length === 0) { reportLoading = false; reportGenerated = true; return; }

        // Generate month columns within date range
        const fromDate = new Date(reportDateFrom);
        const toDate = new Date(reportDateTo);
        const months: string[] = [];
        const labels: string[] = [];
        const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        let curM = new Date(fromDate.getFullYear(), fromDate.getMonth(), 1);
        const endM = new Date(toDate.getFullYear(), toDate.getMonth(), 1);
        while (curM <= endM) {
            const key = curM.toISOString().slice(0, 7);
            months.push(key);
            labels.push(`${monthNames[curM.getMonth()]} ${curM.getFullYear()}`);
            curM.setMonth(curM.getMonth() + 1);
        }
        reportMonths = months;
        reportMonthLabels = labels;

        await buildReportRows(reportPopupType, parties, months, reportDateFrom, reportDateTo);
    }

    // Shared report-building logic used by both current-month and custom report
    async function buildReportRows(type: 'lease' | 'rent', parties: any[], months: string[], dateFrom: string, dateTo: string) {
        // Single RPC: entries + changes via UUID[] param (no URL length issue)
        const { data: reportData } = await supabase.rpc('get_report_data', {
            p_party_type: type,
            p_party_ids: parties.map((p: any) => p.id)
        });
        reportAllEntries = reportData?.entries || [];
        reportAllChanges = reportData?.changes || [];

        const toDate = new Date(dateTo);

        // Build maps
        const entriesMap: Record<string, any[]> = {};
        for (const e of reportAllEntries) {
            if (!entriesMap[e.party_id]) entriesMap[e.party_id] = [];
            entriesMap[e.party_id].push(e);
        }
        const changesMap: Record<string, any[]> = {};
        for (const c of reportAllChanges) {
            if (!changesMap[c.party_id]) changesMap[c.party_id] = [];
            changesMap[c.party_id].push(c);
        }

        const rows: any[] = [];
        const isRent = type === 'rent';
        const amtPrefix = isRent ? 'rent_amount' : 'lease_amount';

        for (const party of parties) {
            const startDate = party.contract_start_date ? new Date(party.contract_start_date) : null;
            if (!startDate) continue;

            let endDate: Date;
            if (party.is_open_contract || !party.contract_end_date) {
                endDate = new Date(toDate);
                endDate.setMonth(endDate.getMonth() + 1);
            } else {
                endDate = new Date(party.contract_end_date);
            }

            const period = party.payment_period || 'monthly';
            const baseContract = Number(isRent ? party.rent_amount_contract : party.lease_amount_contract) || 0;
            const baseOutside = Number(isRent ? party.rent_amount_outside_contract : party.lease_amount_outside_contract) || 0;
            const baseUtility = Number(party.utility_charges) || 0;
            const baseSecurity = Number(party.security_charges) || 0;
            const baseOther = party.other_charges ? party.other_charges.reduce((s: number, c: any) => s + (Number(c.amount) || 0), 0) : 0;
            const partyChanges = changesMap[party.id] || [];

            const periods: any[] = [];
            let periodCur = new Date(startDate);
            let pNum = 1;
            while (periodCur < endDate && pNum <= 500) {
                let periodEnd = new Date(periodCur);
                if (period === 'daily') periodEnd.setDate(periodEnd.getDate() + 1);
                else if (period === 'monthly') periodEnd.setMonth(periodEnd.getMonth() + 1);
                else if (period === 'every_3_months') periodEnd.setMonth(periodEnd.getMonth() + 3);
                else if (period === 'every_6_months') periodEnd.setMonth(periodEnd.getMonth() + 6);
                else if (period === 'yearly') periodEnd.setFullYear(periodEnd.getFullYear() + 1);
                else periodEnd.setMonth(periodEnd.getMonth() + 1);
                if (periodEnd > endDate) periodEnd = new Date(endDate);

                const pFrom = periodCur.toISOString().split('T')[0];
                const pTo = periodEnd.toISOString().split('T')[0];
                const periodMonth = pFrom.slice(0, 7);

                if (pFrom >= dateFrom && pFrom <= dateTo) {
                    let amtC = baseContract, amtO = baseOutside, amtU = baseUtility, amtS = baseSecurity;
                    for (const ch of partyChanges) {
                        const chFrom = ch.effective_from;
                        const chUntil = ch.effective_until || (ch.till_end_of_contract ? endDate.toISOString().split('T')[0] : null);
                        if (chFrom <= pTo && (!chUntil || chUntil >= pFrom)) {
                            if (ch.field_name === `${amtPrefix}_contract`) amtC = Number(ch.new_value);
                            else if (ch.field_name === `${amtPrefix}_outside_contract`) amtO = Number(ch.new_value);
                            else if (ch.field_name === 'utility_charges') amtU = Number(ch.new_value);
                            else if (ch.field_name === 'security_charges') amtS = Number(ch.new_value);
                        }
                    }
                    const totalDue = amtC + amtO + amtU + amtS + baseOther;
                    periods.push({ num: pNum, from: pFrom, to: pTo, month: periodMonth, due: totalDue });
                }
                periodCur = new Date(periodEnd);
                pNum++;
            }

            const partyEntries = entriesMap[party.id] || [];
            const paidByPeriod: Record<number, number> = {};
            for (const e of partyEntries) {
                paidByPeriod[e.period_num] = (paidByPeriod[e.period_num] || 0) + (Number(e.amount) || 0);
            }

            const monthData: Record<string, { due: number; paid: number }> = {};
            for (const m of months) { monthData[m] = { due: 0, paid: 0 }; }
            for (const p of periods) {
                if (monthData[p.month]) {
                    monthData[p.month].due += p.due;
                    monthData[p.month].paid += paidByPeriod[p.num] || 0;
                }
            }

            let totalDue = 0, totalPaid = 0;
            for (const m of months) { totalDue += monthData[m].due; totalPaid += monthData[m].paid; }

            rows.push({ party, months: monthData, totalDue, totalPaid, totalUnpaid: totalDue - totalPaid });
        }
        reportRows = rows;
        reportLoading = false;
        reportGenerated = true;
    }
    let refreshing = false;
    let otherChargesDetailId: string | null = null;
    let leaseOtherChargesDetailId: string | null = null;
    let leaseSpecialRecords: any[] = [];

    // Special changes lookup maps for displaying in tables
    let rentChangesMap: Record<string, any[]> = {};
    let leaseChangesMap: Record<string, any[]> = {};
    let rentChangesLoaded = false;
    let leaseChangesLoaded = false;

    async function loadChangesForParties(partyType: 'rent' | 'lease') {
        const { data, error } = await supabase
            .from('lease_rent_special_changes')
            .select('*')
            .eq('party_type', partyType)
            .order('created_at', { ascending: false });
        if (!error && data) {
            const map: Record<string, any[]> = {};
            for (const row of data) {
                if (!map[row.party_id]) map[row.party_id] = [];
                map[row.party_id].push(row);
            }
            if (partyType === 'rent') { rentChangesMap = map; rentChangesLoaded = true; }
            else { leaseChangesMap = map; leaseChangesLoaded = true; }
        }
    }

    // Calculate remaining time from today to end date
    function getRemainingTime(endDate: string | null, isOpen: boolean): string {
        if (isOpen) return '♾️';
        if (!endDate) return '—';
        const end = new Date(endDate);
        const now = new Date();
        if (end <= now) return '⛔ Expired';
        let years = end.getFullYear() - now.getFullYear();
        let months = end.getMonth() - now.getMonth();
        let days = end.getDate() - now.getDate();
        if (days < 0) { months--; const prev = new Date(end.getFullYear(), end.getMonth(), 0); days += prev.getDate(); }
        if (months < 0) { years--; months += 12; }
        const parts: string[] = [];
        if (years > 0) parts.push(`${years}y`);
        if (months > 0) parts.push(`${months}m`);
        if (days > 0 || parts.length === 0) parts.push(`${days}d`);
        return parts.join(' ');
    }
    let rentSpecialRecords: any[] = [];

    // Manager sub-form state
    let managerActiveForm: string | null = null;
    let formMode: 'add' | 'edit' | null = null;

    // Edit mode tracking
    let editingPropertyId: string | null = null;
    let editingSpaceId: string | null = null;
    let editingLeasePartyId: string | null = null;
    let editingRentPartyId: string | null = null;

    // Edit record lists
    let editLeaseParties: any[] = [];
    let editRentParties: any[] = [];
    let editFullProperties: any[] = [];
    let editPropertySpaces: any[] = [];

    // Add Property form fields
    let propertyNameEn = '';
    let propertyNameAr = '';
    let propertyLocationEn = '';
    let propertyLocationAr = '';
    let propertyIsLeased = false;
    let propertyIsRented = false;

    // Add Property Space form fields
    let selectedPropertyId = '';
    let spaceNumber = '';

    // Properties list for dropdown
    let propertiesList: any[] = [];

    // Spaces grouped by property_id
    let spacesMap: Record<string, any[]> = {};

    // Spaces for the selected property (derived)
    $: propertySpaces = selectedPropertyId ? (spacesMap[selectedPropertyId] || []) : [];

    // Common refresh - reloads everything
    async function refreshAllData() {
        refreshing = true;
        try {
            await Promise.all([
                loadPropertiesWithSpaces(),
                loadRentPartiesForTab(),
                loadLeasePartiesForTab(),
                loadEmployees()
            ]);
        } finally {
            refreshing = false;
        }
    }

    // Load parties + changes in ONE RPC call (replaces 2 separate queries)
    async function loadRentPartiesForTab() {
        if (rentPartiesLoading) return;
        rentPartiesLoading = true;
        const { data, error } = await supabase.rpc('get_lease_rent_tab_data', { p_party_type: 'rent' });
        if (!error && data) {
            rentRecords = data.parties || [];
            rentPartiesLoaded = true;
            // Build changes map from same response
            const map: Record<string, any[]> = {};
            for (const row of (data.changes || [])) {
                if (!map[row.party_id]) map[row.party_id] = [];
                map[row.party_id].push(row);
            }
            rentChangesMap = map;
            rentChangesLoaded = true;
        }
        rentPartiesLoading = false;
    }

    // Auto-load rent parties + changes when switching to rent tab
    $: if (activeTab === 'rent' && !rentPartiesLoaded) {
        loadRentPartiesForTab();
    }

    // Load parties + changes in ONE RPC call (replaces 2 separate queries)
    async function loadLeasePartiesForTab() {
        if (leasePartiesLoading) return;
        leasePartiesLoading = true;
        const { data, error } = await supabase.rpc('get_lease_rent_tab_data', { p_party_type: 'lease' });
        if (!error && data) {
            leaseRecords = data.parties || [];
            leasePartiesLoaded = true;
            // Build changes map from same response
            const map: Record<string, any[]> = {};
            for (const row of (data.changes || [])) {
                if (!map[row.party_id]) map[row.party_id] = [];
                map[row.party_id].push(row);
            }
            leaseChangesMap = map;
            leaseChangesLoaded = true;
        }
        leasePartiesLoading = false;
    }

    // Auto-load lease parties + changes when switching to lease tab
    $: if (activeTab === 'lease' && !leasePartiesLoaded) {
        loadLeasePartiesForTab();
    }

    // Single RPC call to load all properties + their spaces
    async function loadPropertiesWithSpaces() {
        const { data, error } = await supabase.rpc('get_lease_rent_properties_with_spaces');
        if (!error && data) {
            // Build unique properties list and spaces map
            const propsMap = new Map<string, any>();
            const sMap: Record<string, any[]> = {};
            for (const row of data) {
                if (!propsMap.has(row.property_id)) {
                    propsMap.set(row.property_id, {
                        id: row.property_id,
                        name_en: row.property_name_en,
                        name_ar: row.property_name_ar,
                        is_rented: row.property_is_rented,
                        is_leased: row.property_is_leased
                    });
                    sMap[row.property_id] = [];
                }
                if (row.space_id) {
                    sMap[row.property_id].push({
                        id: row.space_id,
                        space_number: row.space_number
                    });
                }
            }
            propertiesList = Array.from(propsMap.values());
            spacesMap = sMap;
        }
    }

    // Manager form navigation
    function setManagerForm(form: string) {
        if (managerActiveForm === form) { managerActiveForm = null; }
        else { managerActiveForm = form; }
        formMode = null;
        editingPropertyId = null;
        editingSpaceId = null;
        editingLeasePartyId = null;
        editingRentPartyId = null;
    }

    function enterAddMode() {
        formMode = 'add';
        resetCurrentForm();
        if (managerActiveForm === 'propertySpace' || managerActiveForm === 'rent' || managerActiveForm === 'lease') {
            loadPropertiesWithSpaces();
        }
        if (managerActiveForm === 'rent' || managerActiveForm === 'lease') {
            loadEmployees();
        }
    }

    async function enterEditMode() {
        formMode = 'edit';
        resetCurrentForm();
        if (managerActiveForm === 'property') {
            await loadEditProperties();
        } else if (managerActiveForm === 'propertySpace') {
            await loadPropertiesWithSpaces();
            await loadEditPropertySpaces();
        } else if (managerActiveForm === 'lease') {
            await loadPropertiesWithSpaces();
            await loadEmployees();
            await loadEditLeaseParties();
        } else if (managerActiveForm === 'rent') {
            await loadPropertiesWithSpaces();
            await loadEmployees();
            await loadEditRentParties();
        }
    }

    function resetCurrentForm() {
        if (managerActiveForm === 'property') resetPropertyForm();
        else if (managerActiveForm === 'propertySpace') resetSpaceForm();
        else if (managerActiveForm === 'lease') resetLeaseForm();
        else if (managerActiveForm === 'rent') resetRentForm();
    }

    // Load functions for edit mode
    async function loadEditProperties() {
        const { data, error } = await supabase.from('lease_rent_properties').select('*').order('name_en');
        if (!error && data) editFullProperties = data;
    }

    async function loadEditPropertySpaces() {
        const { data, error } = await supabase.from('lease_rent_property_spaces').select('*').order('space_number');
        if (!error && data) editPropertySpaces = data;
    }

    async function loadEditLeaseParties() {
        const { data, error } = await supabase.from('lease_rent_lease_parties').select('*').order('party_name_en');
        if (!error && data) editLeaseParties = data;
    }

    async function loadEditRentParties() {
        const { data, error } = await supabase.from('lease_rent_rent_parties').select('*').order('party_name_en');
        if (!error && data) editRentParties = data;
    }

    // Populate functions for edit mode
    function populatePropertyForEdit(id: string) {
        const rec = editFullProperties.find(p => p.id === id);
        if (!rec) return;
        editingPropertyId = rec.id;
        propertyNameEn = rec.name_en || '';
        propertyNameAr = rec.name_ar || '';
        propertyLocationEn = rec.location_en || '';
        propertyLocationAr = rec.location_ar || '';
        propertyIsLeased = rec.is_leased || false;
        propertyIsRented = rec.is_rented || false;
    }

    function populateSpaceForEdit(id: string) {
        const rec = editPropertySpaces.find(s => s.id === id);
        if (!rec) return;
        editingSpaceId = rec.id;
        selectedPropertyId = rec.property_id || '';
        spaceNumber = rec.space_number || '';
    }

    function populateLeaseForEdit(id: string) {
        const rec = editLeaseParties.find(l => l.id === id);
        if (!rec) return;
        editingLeasePartyId = rec.id;
        leasePropertyId = rec.property_id || '';
        leasePropertySpaceId = rec.property_space_id || '';
        leasePartyNameEn = rec.party_name_en || '';
        leasePartyNameAr = rec.party_name_ar || '';
        leaseShopName = rec.shop_name || '';
        leaseContactNumber = rec.contact_number || '';
        leaseEmail = rec.email || '';
        leaseContractStart = rec.contract_start_date || '';
        leaseContractEnd = rec.contract_end_date || '';
        leaseOpenContract = rec.is_open_contract || false;
        leaseAmountContract = rec.lease_amount_contract?.toString() || '';
        leaseAmountOutside = rec.lease_amount_outside_contract?.toString() || '';
        leaseUtilityCharges = rec.utility_charges?.toString() || '';
        leaseSecurityCharges = rec.security_charges?.toString() || '';
        leaseOtherCharges = rec.other_charges || [];
        leasePaymentMode = rec.payment_mode || 'cash';
        leaseCollectionInchargeId = rec.collection_incharge_id || '';
        leasePaymentPeriod = rec.payment_period || 'monthly';
        leasePaymentSpecificDate = rec.payment_specific_date?.toString() || '';
        leasePaymentEndOfMonth = rec.payment_end_of_month || false;
    }

    function populateRentForEdit(id: string) {
        const rec = editRentParties.find(r => r.id === id);
        if (!rec) return;
        editingRentPartyId = rec.id;
        rentPropertyId = rec.property_id || '';
        rentPropertySpaceId = rec.property_space_id || '';
        rentPartyNameEn = rec.party_name_en || '';
        rentPartyNameAr = rec.party_name_ar || '';
        rentShopName = rec.shop_name || '';
        rentContactNumber = rec.contact_number || '';
        rentEmail = rec.email || '';
        rentContractStart = rec.contract_start_date || '';
        rentContractEnd = rec.contract_end_date || '';
        rentOpenContract = rec.is_open_contract || false;
        rentAmountContract = rec.rent_amount_contract?.toString() || '';
        rentAmountOutside = rec.rent_amount_outside_contract?.toString() || '';
        rentUtilityCharges = rec.utility_charges?.toString() || '';
        rentSecurityCharges = rec.security_charges?.toString() || '';
        rentOtherCharges = rec.other_charges || [];
        rentPaymentMode = rec.payment_mode || 'cash';
        rentCollectionInchargeId = rec.collection_incharge_id || '';
        rentPaymentPeriod = rec.payment_period || 'monthly';
        rentPaymentSpecificDate = rec.payment_specific_date?.toString() || '';
        rentPaymentEndOfMonth = rec.payment_end_of_month || false;
    }

    // Reset functions
    function resetPropertyForm() {
        editingPropertyId = null;
        propertyNameEn = ''; propertyNameAr = '';
        propertyLocationEn = ''; propertyLocationAr = '';
        propertyIsLeased = false; propertyIsRented = false;
    }

    function resetSpaceForm() {
        editingSpaceId = null;
        selectedPropertyId = ''; spaceNumber = '';
    }

    function resetLeaseForm() {
        editingLeasePartyId = null;
        leasePropertyId = ''; leasePropertySpaceId = '';
        leasePartyNameEn = ''; leasePartyNameAr = '';
        leaseShopName = ''; leaseContactNumber = ''; leaseEmail = '';
        leaseContractStart = ''; leaseContractEnd = ''; leaseOpenContract = false;
        leaseAmountContract = ''; leaseAmountOutside = '';
        leaseUtilityCharges = ''; leaseSecurityCharges = '';
        leaseOtherCharges = []; leasePaymentMode = 'cash';
        leaseCollectionInchargeId = ''; leasePaymentPeriod = 'monthly';
        leasePaymentSpecificDate = ''; leasePaymentEndOfMonth = false;
    }

    function resetRentForm() {
        editingRentPartyId = null;
        rentPropertyId = ''; rentPropertySpaceId = '';
        rentPartyNameEn = ''; rentPartyNameAr = '';
        rentShopName = ''; rentContactNumber = ''; rentEmail = '';
        rentContractStart = ''; rentContractEnd = ''; rentOpenContract = false;
        rentAmountContract = ''; rentAmountOutside = '';
        rentUtilityCharges = ''; rentSecurityCharges = '';
        rentOtherCharges = []; rentPaymentMode = 'cash';
        rentCollectionInchargeId = ''; rentPaymentPeriod = 'monthly';
        rentPaymentSpecificDate = ''; rentPaymentEndOfMonth = false;
    }

    // Save states
    let savingProperty = false;
    let savingSpace = false;

    // Save property
    async function saveProperty() {
        if (!propertyNameEn.trim() || !propertyNameAr.trim()) return;
        savingProperty = true;
        try {
            const payload = {
                name_en: propertyNameEn.trim(),
                name_ar: propertyNameAr.trim(),
                location_en: propertyLocationEn.trim() || null,
                location_ar: propertyLocationAr.trim() || null,
                is_leased: propertyIsLeased,
                is_rented: propertyIsRented
            };
            if (formMode === 'edit' && editingPropertyId) {
                const { error } = await supabase.from('lease_rent_properties').update(payload).eq('id', editingPropertyId);
                if (error) throw error;
            } else {
                const { error } = await supabase.from('lease_rent_properties').insert(payload);
                if (error) throw error;
            }
            resetPropertyForm();
            await loadPropertiesWithSpaces();
            if (formMode === 'edit') await loadEditProperties();
        } catch (err) {
            console.error('Failed to save property:', err);
        } finally {
            savingProperty = false;
        }
    }

    // Save property space
    async function savePropertySpace() {
        if (!selectedPropertyId || !spaceNumber.trim()) return;
        savingSpace = true;
        try {
            const payload = {
                property_id: selectedPropertyId,
                space_number: spaceNumber.trim()
            };
            if (formMode === 'edit' && editingSpaceId) {
                const { error } = await supabase.from('lease_rent_property_spaces').update(payload).eq('id', editingSpaceId);
                if (error) throw error;
            } else {
                const { error } = await supabase.from('lease_rent_property_spaces').insert(payload);
                if (error) {
                    if (error.code === '23505') {
                        alert($t('finance.leaseAndRent.duplicateSpaceNumber'));
                    } else {
                        throw error;
                    }
                    return;
                }
            }
            resetSpaceForm();
            await loadPropertiesWithSpaces();
            if (formMode === 'edit') await loadEditPropertySpaces();
        } catch (err) {
            console.error('Failed to save property space:', err);
        } finally {
            savingSpace = false;
        }
    }

    // Load everything via RPC when propertySpace or rent form is opened
    $: if (managerActiveForm === 'propertySpace' || managerActiveForm === 'rent') {
        loadPropertiesWithSpaces();
    }

    // --- Rent Party Form ---
    // Properties filtered for renting
    $: rentProperties = propertiesList.filter(p => p.is_rented);

    let rentPropertyId = '';
    let rentPropertySpaceId = '';
    let rentPartyNameEn = '';
    let rentPartyNameAr = '';
    let rentShopName = '';
    let rentContactNumber = '';
    let rentEmail = '';
    let rentContractStart = '';
    let rentContractEnd = '';
    let rentOpenContract = false;
    let rentAmountContract = '';
    let rentAmountOutside = '';
    let rentUtilityCharges = '';
    let rentSecurityCharges = '';
    let rentOtherCharges: { name: string; amount: number }[] = [];
    let rentPaymentMode = 'cash';
    let rentCollectionInchargeId = '';
    let rentPaymentPeriod = 'monthly';
    let rentPaymentSpecificDate = '';
    let rentPaymentEndOfMonth = false;

    // Other charges popup
    let showOtherChargesPopup = false;
    let newChargeName = '';
    let newChargeAmount = '';

    function addOtherCharge() {
        if (!newChargeName.trim() || !newChargeAmount) return;
        rentOtherCharges = [...rentOtherCharges, { name: newChargeName.trim(), amount: parseFloat(newChargeAmount) || 0 }];
        newChargeName = '';
        newChargeAmount = '';
        showOtherChargesPopup = false;
    }

    function removeOtherCharge(index: number) {
        rentOtherCharges = rentOtherCharges.filter((_, i) => i !== index);
    }

    // Spaces for selected rent property
    $: rentSpaces = rentPropertyId ? (spacesMap[rentPropertyId] || []) : [];

    // Payment period has sub-fields
    $: rentPeriodHasSubFields = rentPaymentPeriod !== 'daily';

    // Employees list for collection incharge
    let employeesList: any[] = [];
    let employeeSearch = '';
    let showEmployeeDropdown = false;

    $: filteredEmployees = employeesList.filter(emp => {
        if (!employeeSearch.trim()) return true;
        const q = employeeSearch.toLowerCase();
        return (emp.name_en || '').toLowerCase().includes(q) || (emp.name_ar || '').includes(q);
    });

    // Get selected employee name for display
    $: selectedEmployeeName = (() => {
        if (!rentCollectionInchargeId) return '';
        const emp = employeesList.find(e => e.id === rentCollectionInchargeId);
        if (!emp) return '';
        return $locale === 'ar' ? (emp.name_ar || emp.name_en) : emp.name_en;
    })();

    function selectEmployee(emp: any) {
        rentCollectionInchargeId = emp.id;
        employeeSearch = '';
        showEmployeeDropdown = false;
    }

    function clearEmployee() {
        rentCollectionInchargeId = '';
        employeeSearch = '';
    }

    async function loadEmployees() {
        const { data, error } = await supabase
            .from('hr_employee_master')
            .select('id, name_en, name_ar')
            .order('name_en');
        if (!error && data) {
            employeesList = data;
        }
    }

    // Load employees when rent form opens
    $: if (managerActiveForm === 'rent') {
        loadEmployees();
    }

    // Save rent party
    let savingRentParty = false;

    async function saveRentParty() {
        if (!rentPropertyId || !rentPartyNameEn.trim() || !rentPartyNameAr.trim()) return;
        savingRentParty = true;
        try {
            const payload = {
                property_id: rentPropertyId,
                property_space_id: rentPropertySpaceId || null,
                party_name_en: rentPartyNameEn.trim(),
                party_name_ar: rentPartyNameAr.trim(),
                shop_name: rentShopName.trim() || null,
                contact_number: rentContactNumber.trim() || null,
                email: rentEmail.trim() || null,
                contract_start_date: rentContractStart || null,
                contract_end_date: rentOpenContract ? null : (rentContractEnd || null),
                is_open_contract: rentOpenContract,
                rent_amount_contract: parseFloat(rentAmountContract) || 0,
                rent_amount_outside_contract: parseFloat(rentAmountOutside) || 0,
                utility_charges: parseFloat(rentUtilityCharges) || 0,
                security_charges: parseFloat(rentSecurityCharges) || 0,
                other_charges: rentOtherCharges,
                payment_mode: rentPaymentMode,
                collection_incharge_id: rentCollectionInchargeId || null,
                payment_period: rentPaymentPeriod,
                payment_specific_date: rentPaymentSpecificDate ? parseInt(rentPaymentSpecificDate) : null,
                payment_end_of_month: rentPaymentEndOfMonth
            };
            if (formMode === 'edit' && editingRentPartyId) {
                const { error } = await supabase.from('lease_rent_rent_parties').update(payload).eq('id', editingRentPartyId);
                if (error) throw error;
            } else {
                const { error } = await supabase.from('lease_rent_rent_parties').insert(payload);
                if (error) throw error;
            }
            resetRentForm();
            rentPartiesLoaded = false; // refresh rent tab data
            if (formMode === 'edit') await loadEditRentParties();
        } catch (err) {
            console.error('Failed to save rent party:', err);
        } finally {
            savingRentParty = false;
        }
    }

    // --- Lease Party Form ---
    // Properties filtered for leasing
    $: leaseProperties = propertiesList.filter(p => p.is_leased);

    let leasePropertyId = '';
    let leasePropertySpaceId = '';
    let leasePartyNameEn = '';
    let leasePartyNameAr = '';
    let leaseShopName = '';
    let leaseContactNumber = '';
    let leaseEmail = '';
    let leaseContractStart = '';
    let leaseContractEnd = '';
    let leaseOpenContract = false;
    let leaseAmountContract = '';
    let leaseAmountOutside = '';
    let leaseUtilityCharges = '';
    let leaseSecurityCharges = '';
    let leaseOtherCharges: { name: string; amount: number }[] = [];
    let leasePaymentMode = 'cash';
    let leaseCollectionInchargeId = '';
    let leasePaymentPeriod = 'monthly';
    let leasePaymentSpecificDate = '';
    let leasePaymentEndOfMonth = false;

    // Other charges popup for lease
    let showLeaseOtherChargesPopup = false;
    let newLeaseChargeName = '';
    let newLeaseChargeAmount = '';

    function addLeaseOtherCharge() {
        if (!newLeaseChargeName.trim() || !newLeaseChargeAmount) return;
        leaseOtherCharges = [...leaseOtherCharges, { name: newLeaseChargeName.trim(), amount: parseFloat(newLeaseChargeAmount) || 0 }];
        newLeaseChargeName = '';
        newLeaseChargeAmount = '';
        showLeaseOtherChargesPopup = false;
    }

    function removeLeaseOtherCharge(index: number) {
        leaseOtherCharges = leaseOtherCharges.filter((_, i) => i !== index);
    }

    // Spaces for selected lease property
    $: leaseSpaces = leasePropertyId ? (spacesMap[leasePropertyId] || []) : [];

    // Payment period has sub-fields for lease
    $: leasePeriodHasSubFields = leasePaymentPeriod !== 'daily';

    // Collection incharge search for lease form
    let leaseEmployeeSearch = '';
    let showLeaseEmployeeDropdown = false;

    $: filteredLeaseEmployees = employeesList.filter(emp => {
        if (!leaseEmployeeSearch.trim()) return true;
        const q = leaseEmployeeSearch.toLowerCase();
        return (emp.name_en || '').toLowerCase().includes(q) || (emp.name_ar || '').includes(q);
    });

    $: selectedLeaseEmployeeName = (() => {
        if (!leaseCollectionInchargeId) return '';
        const emp = employeesList.find(e => e.id === leaseCollectionInchargeId);
        if (!emp) return '';
        return $locale === 'ar' ? (emp.name_ar || emp.name_en) : emp.name_en;
    })();

    function selectLeaseEmployee(emp: any) {
        leaseCollectionInchargeId = emp.id;
        leaseEmployeeSearch = '';
        showLeaseEmployeeDropdown = false;
    }

    function clearLeaseEmployee() {
        leaseCollectionInchargeId = '';
        leaseEmployeeSearch = '';
    }

    // Load properties + employees when lease form opens
    $: if (managerActiveForm === 'lease') {
        loadPropertiesWithSpaces();
        loadEmployees();
    }

    // --- Rent Special Changes Form ---
    let rentSpecialPartySearch = '';
    let showRentSpecialPartyDropdown = false;
    let selectedRentSpecialParty: any = null;

    $: filteredRentSpecialParties = rentRecords.filter(r => {
        if (!rentSpecialPartySearch.trim()) return true;
        const q = rentSpecialPartySearch.toLowerCase();
        return (r.party_name_en || '').toLowerCase().includes(q) || (r.party_name_ar || '').includes(q);
    });

    function selectRentSpecialParty(party: any) {
        selectedRentSpecialParty = party;
        rentSpecialPartySearch = '';
        showRentSpecialPartyDropdown = false;
    }

    function clearRentSpecialParty() {
        selectedRentSpecialParty = null;
        rentSpecialPartySearch = '';
    }

    // --- Lease Special Changes Form ---
    let leaseSpecialPartySearch = '';
    let showLeaseSpecialPartyDropdown = false;
    let selectedLeaseSpecialParty: any = null;

    $: filteredLeaseSpecialParties = leaseRecords.filter(r => {
        if (!leaseSpecialPartySearch.trim()) return true;
        const q = leaseSpecialPartySearch.toLowerCase();
        return (r.party_name_en || '').toLowerCase().includes(q) || (r.party_name_ar || '').includes(q);
    });

    function selectLeaseSpecialParty(party: any) {
        selectedLeaseSpecialParty = party;
        leaseSpecialPartySearch = '';
        showLeaseSpecialPartyDropdown = false;
    }

    function clearLeaseSpecialParty() {
        selectedLeaseSpecialParty = null;
        leaseSpecialPartySearch = '';
    }

    // Auto-load rent/lease data when special tabs are active
    $: if (activeTab === 'rentSpecial' && !rentPartiesLoaded) {
        loadRentPartiesForTab();
    }
    $: if (activeTab === 'leaseSpecial' && !leasePartiesLoaded) {
        loadLeasePartiesForTab();
    }
    $: if (activeTab === 'payments' && paymentType === 'rent' && !rentPartiesLoaded) {
        loadRentPartiesForTab();
    }
    $: if (activeTab === 'payments' && paymentType === 'lease' && !leasePartiesLoaded) {
        loadLeasePartiesForTab();
    }

    // --- Special Changes Popup ---
    let showSpecialChangePopup = false;
    let specialChangePartyType: 'rent' | 'lease' = 'rent';
    let specialChangePartyId = '';
    let specialChangeFieldName = '';
    let specialChangeFieldLabel = '';
    let specialChangeOldValue = 0;
    let specialChangeNewValue = '';
    let specialChangeEffectiveFrom = '';
    let specialChangeTillEnd = true;
    let specialChangeEffectiveUntil = '';
    let specialChangePaymentPeriod = 'monthly';
    let specialChangeReason = '';
    let savingSpecialChange = false;

    // Changes history for selected party
    let specialChangesHistory: any[] = [];
    let loadingChangesHistory = false;

    function openSpecialChangePopup(partyType: 'rent' | 'lease', party: any, fieldName: string, fieldLabel: string, oldValue: number) {
        specialChangePartyType = partyType;
        specialChangePartyId = party.id;
        specialChangeFieldName = fieldName;
        specialChangeFieldLabel = fieldLabel;
        specialChangeOldValue = oldValue;
        specialChangeNewValue = '';
        specialChangeEffectiveFrom = new Date().toISOString().split('T')[0];
        specialChangeTillEnd = true;
        specialChangeEffectiveUntil = '';
        specialChangePaymentPeriod = party.payment_period || 'monthly';
        specialChangeReason = '';
        showSpecialChangePopup = true;
    }

    async function saveSpecialChange() {
        if (!specialChangeNewValue || !specialChangeEffectiveFrom) return;
        savingSpecialChange = true;
        try {
            const payload = {
                party_type: specialChangePartyType,
                party_id: specialChangePartyId,
                field_name: specialChangeFieldName,
                old_value: specialChangeOldValue,
                new_value: parseFloat(specialChangeNewValue) || 0,
                effective_from: specialChangeEffectiveFrom,
                effective_until: specialChangeTillEnd ? null : (specialChangeEffectiveUntil || null),
                till_end_of_contract: specialChangeTillEnd,
                payment_period: specialChangePaymentPeriod,
                reason: specialChangeReason.trim() || null
            };
            const { error } = await supabase.from('lease_rent_special_changes').insert(payload);
            if (error) throw error;
            showSpecialChangePopup = false;
            // Reload history
            if (specialChangePartyType === 'rent' && selectedRentSpecialParty) {
                await loadSpecialChangesHistory('rent', selectedRentSpecialParty.id);
            } else if (specialChangePartyType === 'lease' && selectedLeaseSpecialParty) {
                await loadSpecialChangesHistory('lease', selectedLeaseSpecialParty.id);
            }
        } catch (err) {
            console.error('Failed to save special change:', err);
        } finally {
            savingSpecialChange = false;
        }
    }

    async function loadSpecialChangesHistory(partyType: string, partyId: string) {
        loadingChangesHistory = true;
        const { data, error } = await supabase
            .from('lease_rent_special_changes')
            .select('*')
            .eq('party_type', partyType)
            .eq('party_id', partyId)
            .order('created_at', { ascending: false });
        if (!error && data) {
            specialChangesHistory = data;
        }
        loadingChangesHistory = false;
    }

    // Auto-load changes history when party is selected
    $: if (selectedRentSpecialParty) {
        loadSpecialChangesHistory('rent', selectedRentSpecialParty.id);
    } else if (selectedLeaseSpecialParty) {
        loadSpecialChangesHistory('lease', selectedLeaseSpecialParty.id);
    } else {
        specialChangesHistory = [];
    }

    // Save lease party
    let savingLeaseParty = false;

    async function saveLeaseParty() {
        if (!leasePropertyId || !leasePartyNameEn.trim() || !leasePartyNameAr.trim()) return;
        savingLeaseParty = true;
        try {
            const payload = {
                property_id: leasePropertyId,
                property_space_id: leasePropertySpaceId || null,
                party_name_en: leasePartyNameEn.trim(),
                party_name_ar: leasePartyNameAr.trim(),
                shop_name: leaseShopName.trim() || null,
                contact_number: leaseContactNumber.trim() || null,
                email: leaseEmail.trim() || null,
                contract_start_date: leaseContractStart || null,
                contract_end_date: leaseOpenContract ? null : (leaseContractEnd || null),
                is_open_contract: leaseOpenContract,
                lease_amount_contract: parseFloat(leaseAmountContract) || 0,
                lease_amount_outside_contract: parseFloat(leaseAmountOutside) || 0,
                utility_charges: parseFloat(leaseUtilityCharges) || 0,
                security_charges: parseFloat(leaseSecurityCharges) || 0,
                other_charges: leaseOtherCharges,
                payment_mode: leasePaymentMode,
                collection_incharge_id: leaseCollectionInchargeId || null,
                payment_period: leasePaymentPeriod,
                payment_specific_date: leasePaymentSpecificDate ? parseInt(leasePaymentSpecificDate) : null,
                payment_end_of_month: leasePaymentEndOfMonth
            };
            if (formMode === 'edit' && editingLeasePartyId) {
                const { error } = await supabase.from('lease_rent_lease_parties').update(payload).eq('id', editingLeasePartyId);
                if (error) throw error;
            } else {
                const { error } = await supabase.from('lease_rent_lease_parties').insert(payload);
                if (error) throw error;
            }
            resetLeaseForm();
            leasePartiesLoaded = false; // refresh lease tab data
            if (formMode === 'edit') await loadEditLeaseParties();
        } catch (err) {
            console.error('Failed to save lease party:', err);
        } finally {
            savingLeaseParty = false;
        }
    }
</script>

<svelte:window on:click={(e) => { const target = e.target as HTMLElement; if (target) { if (showEmployeeDropdown && !target.closest?.('.employee-search-container')) showEmployeeDropdown = false; if (showLeaseEmployeeDropdown && !target.closest?.('.lease-employee-search-container')) showLeaseEmployeeDropdown = false; if (otherChargesDetailId && !target.closest?.('.other-charges-detail')) otherChargesDetailId = null; if (leaseOtherChargesDetailId && !target.closest?.('.lease-other-charges-detail')) leaseOtherChargesDetailId = null; if (showRentSpecialPartyDropdown && !target.closest?.('.rent-special-party-container')) showRentSpecialPartyDropdown = false; if (showLeaseSpecialPartyDropdown && !target.closest?.('.lease-special-party-container')) showLeaseSpecialPartyDropdown = false; if (showPaymentPartyDropdown && !target.closest?.('.payment-party-container')) showPaymentPartyDropdown = false; } }} />

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div class="flex gap-2">
            <button
                class="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-slate-600 text-white text-xs font-bold hover:bg-slate-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed {refreshing ? 'animate-pulse' : ''}"
                on:click={refreshAllData}
                disabled={refreshing}
            >
                <span class="{refreshing ? 'animate-spin' : ''}">🔄</span> {$t('common.refresh')}
            </button>
        </div>
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button
                    class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id
                        ? (tab.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
                          : tab.color === 'orange' ? 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]'
                          : tab.color === 'blue' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]'
                          : tab.color === 'purple' ? 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]'
                          : tab.color === 'indigo' ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-200 scale-[1.02]'
                          : tab.color === 'cyan' ? 'bg-cyan-600 text-white shadow-lg shadow-cyan-200 scale-[1.02]'
                          : 'bg-red-600 text-white shadow-lg shadow-red-200 scale-[1.02]')
                        : 'bg-white/50 text-slate-500 border border-slate-200/60 hover:bg-white hover:text-slate-800 hover:shadow-md hover:border-slate-300'}"
                    on:click={() => { activeTab = tab.id; }}
                >
                    <span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
                    <span class="relative z-10">{tab.label}</span>

                    {#if activeTab === tab.id}
                        <div class="absolute inset-0 bg-white/10 animate-pulse"></div>
                    {/if}
                </button>
            {/each}
        </div>
    </div>

    <!-- Main Content Area -->
    <div class="flex-1 px-8 pt-3 pb-4 relative overflow-hidden bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Futuristic background decorative elements -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col overflow-y-auto">
            {#if activeTab === 'lease'}
                {#if leasePartiesLoading}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center">
                        <div class="text-4xl mb-3 animate-spin">⏳</div>
                        <p class="text-slate-500 font-semibold text-sm">{$t('common.loading')}...</p>
                    </div>
                {:else if leaseRecords.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📋</div>
                        <p class="text-slate-600 font-semibold">{$t('finance.leaseAndRent.noLeaseRecords')}</p>
                    </div>
                {:else}
                    <!-- Lease Parties Full Details Table -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex flex-col">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse text-xs [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-100">
                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">#</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.partyName')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.contactDetails')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.propertyColumn')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.contractDates')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.leaseAmount')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.charges')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.otherCharges')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.paymentMode')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400 bg-emerald-700">{$t('finance.leaseAndRent.totalLease')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.paymentPeriod')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400 bg-emerald-700">{$t('finance.leaseAndRent.changesColumn')}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each leaseRecords as record, index}
                                        <tr class="hover:bg-emerald-50/40 transition-colors duration-150 cursor-pointer {selectedPaymentParty?.id === record.id && paymentType === 'lease' ? 'bg-emerald-100/80 ring-1 ring-emerald-400' : index % 2 === 0 ? 'bg-slate-50/30' : 'bg-white/30'}" on:click={() => { paymentType = 'lease'; selectPaymentParty(record); }}>
                                            <td class="px-2 py-2 text-slate-500 font-semibold">{index + 1}</td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="text-slate-800 font-semibold">{record.party_name_en || '—'}</div>
                                                <div class="text-emerald-700 font-semibold" dir="rtl">{record.party_name_ar || '—'}</div>
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="text-emerald-700 font-semibold">{record.contact_number || '—'}</div>
                                                <div class="text-blue-600 font-semibold">{record.email || '—'}</div>
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="text-slate-800 font-semibold">{$locale === 'ar' ? (record.property?.name_ar || '—') : (record.property?.name_en || '—')}</div>
                                                <div class="text-blue-700 font-semibold">{$t('finance.leaseAndRent.spaceNumber')}: {record.space?.space_number || '—'}</div>
                                                <div class="text-violet-700 font-semibold">{record.shop_name || '—'}</div>
                                            </td>
                                            <td class="px-2 py-2 text-slate-700 whitespace-nowrap leading-tight">
                                                <div class="text-slate-800">{fmtDate(record.contract_start_date) || '—'}</div>
                                                <div class="text-[10px] text-slate-400">{record.is_open_contract ? '♾️ Open' : (fmtDate(record.contract_end_date) || '—')}</div>
                                                <div><span class="inline-flex px-1.5 py-0 rounded-full text-[9px] font-bold
                                                    {getRemainingTime(record.contract_end_date, record.is_open_contract) === '♾️' ? 'bg-purple-100 text-purple-700' : getRemainingTime(record.contract_end_date, record.is_open_contract) === '⛔ Expired' ? 'bg-red-100 text-red-700' : 'bg-emerald-100 text-emerald-700'}">{getRemainingTime(record.contract_end_date, record.is_open_contract)}</span></div>
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="flex items-center gap-1"><span class="text-green-600">✅</span><span class="text-slate-800 font-semibold">{record.lease_amount_contract ? Number(record.lease_amount_contract).toLocaleString() : '—'}</span></div>
                                                <div class="flex items-center gap-1"><span class="text-red-500">✔</span><span class="text-slate-800 font-semibold">{record.lease_amount_outside_contract ? Number(record.lease_amount_outside_contract).toLocaleString() : '—'}</span></div>
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="flex items-center gap-1"><span class="text-cyan-600 font-semibold">{$t('finance.leaseAndRent.utilityCharges')}:</span><span class="text-slate-800 font-semibold">{record.utility_charges ? Number(record.utility_charges).toLocaleString() : '—'}</span></div>
                                                <div class="flex items-center gap-1"><span class="text-amber-600 font-semibold">{$t('finance.leaseAndRent.securityCharges')}:</span><span class="text-slate-800 font-semibold">{record.security_charges ? Number(record.security_charges).toLocaleString() : '—'}</span></div>
                                            </td>
                                            <td class="px-2 py-2">
                                                {#if record.other_charges && record.other_charges.length > 0}
                                                    <div class="relative inline-flex items-center gap-1 lease-other-charges-detail">
                                                        <span class="font-semibold text-slate-800">{record.other_charges.reduce((s, c) => s + (Number(c.amount) || 0), 0).toLocaleString()}</span>
                                                        <button class="w-4 h-4 rounded-full bg-amber-500 text-white text-[9px] font-bold leading-none hover:bg-amber-600 transition-colors" on:click={() => { leaseOtherChargesDetailId = leaseOtherChargesDetailId === record.id ? null : record.id; }}>?</button>
                                                        {#if leaseOtherChargesDetailId === record.id}
                                                            <div class="absolute z-50 top-6 {$locale === 'ar' ? 'right-0' : 'left-0'} bg-white border border-amber-200 rounded-xl shadow-xl p-3 min-w-[160px]">
                                                                <div class="text-[10px] font-bold text-amber-700 uppercase mb-1.5">{$t('finance.leaseAndRent.otherCharges')}</div>
                                                                {#each record.other_charges as charge}
                                                                    <div class="flex justify-between text-xs py-0.5 border-b border-slate-100 last:border-0">
                                                                        <span class="text-slate-700">{charge.name}</span>
                                                                        <span class="font-semibold text-slate-800">{Number(charge.amount).toLocaleString()}</span>
                                                                    </div>
                                                                {/each}
                                                                <div class="flex justify-between text-xs pt-1.5 mt-1 border-t border-amber-300 font-bold">
                                                                    <span class="text-amber-700">Total</span>
                                                                    <span class="text-amber-800">{record.other_charges.reduce((s, c) => s + (Number(c.amount) || 0), 0).toLocaleString()}</span>
                                                                </div>
                                                            </div>
                                                        {/if}
                                                    </div>
                                                {:else}
                                                    <span class="text-slate-400">—</span>
                                                {/if}
                                            </td>
                                            <td class="px-2 py-2">
                                                <span class="inline-flex px-2 py-0.5 rounded-full text-[10px] font-bold {record.payment_mode === 'bank' ? 'bg-blue-100 text-blue-700' : 'bg-green-100 text-green-700'}">
                                                    {record.payment_mode === 'bank' ? $t('finance.leaseAndRent.bank') : $t('finance.leaseAndRent.cash')}
                                                </span>
                                            </td>
                                            <td class="px-2 py-2 font-bold text-emerald-800 bg-emerald-50/50 whitespace-nowrap">{((Number(record.lease_amount_contract) || 0) + (Number(record.lease_amount_outside_contract) || 0) + (Number(record.utility_charges) || 0) + (Number(record.security_charges) || 0) + (record.other_charges ? record.other_charges.reduce((s, c) => s + (Number(c.amount) || 0), 0) : 0)).toLocaleString()}</td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="text-slate-800 font-semibold capitalize">{(record.payment_period || 'monthly').replace(/_/g, ' ')}</div>
                                                {#if record.payment_period === 'daily'}
                                                    <div class="text-blue-600 text-[10px] font-semibold">{$t('finance.leaseAndRent.everyDay')}</div>
                                                {:else if record.payment_end_of_month}
                                                    <div class="text-violet-600 text-[10px] font-semibold">{$t('finance.leaseAndRent.endOfMonth')}</div>
                                                {:else if record.payment_specific_date}
                                                    <div class="text-blue-600 text-[10px] font-semibold">{$t('finance.leaseAndRent.dayOfMonth', { day: record.payment_specific_date })}</div>
                                                {/if}
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                {#if leaseChangesMap[record.id] && leaseChangesMap[record.id].length > 0}
                                                    {@const changes = leaseChangesMap[record.id]}
                                                    {@const latest = changes[0]}
                                                    <div class="flex flex-col gap-0.5">
                                                        <span class="inline-flex px-1.5 py-0 rounded-full text-[9px] font-bold bg-violet-100 text-violet-700">{changes.length} {$t('finance.leaseAndRent.changesColumn')}</span>
                                                        <div class="text-[10px] text-slate-600">{$t('finance.leaseAndRent.latestChange')}: <span class="font-semibold text-violet-700">{latest.field_name?.replace(/_/g, ' ')}</span></div>
                                                        <div class="text-[10px] text-slate-500">{Number(latest.old_value).toLocaleString()} → <span class="font-bold text-emerald-700">{Number(latest.new_value).toLocaleString()}</span></div>
                                                        <div class="text-[9px] text-slate-400">{fmtDate(latest.effective_from) || '—'}</div>
                                                    </div>
                                                {:else}
                                                    <span class="text-slate-400 text-[10px]">{$t('finance.leaseAndRent.noChanges')}</span>
                                                {/if}
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                        <div class="px-4 py-2 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('finance.leaseAndRent.showingRecords', { count: leaseRecords.length })}
                        </div>
                    </div>

                    <!-- Lease Payment Schedule (shown when a party is selected) -->
                    {#if selectedPaymentParty && paymentType === 'lease' && paymentSchedule.length > 0}
                        <div class="mt-3">
                            <div class="flex items-center gap-2 mb-2">
                                <h3 class="text-sm font-black text-emerald-800">💳 {$t('finance.leaseAndRent.paymentSchedule')}: {selectedPaymentParty.party_name_en}</h3>
                                <button class="text-red-400 hover:text-red-600 text-xs font-bold px-2 py-0.5 rounded-lg hover:bg-red-50" on:click={clearPaymentParty}>✕ {$t('common.cancel')}</button>
                            </div>
                            {#if selectedPaymentParty.is_open_contract}
                                <div class="bg-purple-50 border border-purple-200 rounded-xl px-4 py-1.5 mb-2 text-xs text-purple-700 font-semibold">
                                    ♾️ {$t('finance.leaseAndRent.openContractNote')}
                                </div>
                            {/if}
                            <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex flex-col">
                                <div class="overflow-x-auto flex-1">
                                    <table class="w-full border-collapse text-xs [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-100">
                                        <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                            <tr>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">#</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.fromDate')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.toDate')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.baseAmount')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.outsideContract')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.utility')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.security')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.other')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400 bg-emerald-700">{$t('finance.leaseAndRent.total')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.paid')}</th>
                                                <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('finance.leaseAndRent.status')}</th>
                                            </tr>
                                        </thead>
                                        <tbody class="divide-y divide-slate-100">
                                            {#each paymentSchedule as row, index}
                                                <tr class="{isFullyPaid(row) ? 'bg-green-50/60' : isPartiallyPaid(row) ? 'bg-yellow-50/60' : row.hasChange ? 'bg-amber-50/60' : (index % 2 === 0 ? 'bg-slate-50/30' : 'bg-white/30')} hover:bg-emerald-50/40 transition-colors duration-150">
                                                    <td class="px-2 py-1.5 text-slate-500 font-semibold">{row.num}</td>
                                                    <td class="px-2 py-1.5 text-slate-700 font-semibold whitespace-nowrap">{fmtDate(row.from)}</td>
                                                    <td class="px-2 py-1.5 text-slate-700 font-semibold whitespace-nowrap">{fmtDate(row.to)}</td>
                                                    {#each ['contract', 'outside', 'utility', 'security', 'other'] as col}
                                                        {@const due = getColumnAmount(row, col)}
                                                        {@const paid = getColumnPaid(row, col)}
                                                        {@const remaining = due - paid}
                                                        {@const full = paid >= due}
                                                        <td class="px-1.5 py-1">
                                                            <div class="flex items-center gap-1 cursor-pointer group" title="{full ? 'Fully paid' : remaining > 0 ? 'Click to pay' : ''}">
                                                                <button type="button" disabled={due === 0} on:click={() => { openPaymentPopup(row, col); }} class="w-5 h-5 flex items-center justify-center rounded-full text-[11px] font-bold transition-all {full ? 'bg-green-500 text-white shadow-sm' : paid > 0 ? 'bg-yellow-400 text-white shadow-sm hover:bg-yellow-500' : due === 0 ? 'bg-slate-100 text-slate-300' : 'bg-slate-200 text-slate-400 hover:bg-green-500 hover:text-white hover:shadow'} disabled:cursor-default">
                                                                    ✓
                                                                </button>
                                                                <span class="flex flex-col leading-tight">
                                                                    {#if full}
                                                                        <span class="font-semibold text-[10px] text-green-700 line-through">{due.toLocaleString()}</span>
                                                                        {#if getLastPaidDate(row, col)}<span class="text-[8px] text-green-600">{getLastPaidDate(row, col)}</span>{/if}
                                                                    {:else if paid > 0}
                                                                        <span class="font-semibold text-[10px] text-yellow-700">{remaining.toLocaleString()}</span>
                                                                        <span class="text-[8px] text-green-600">({paid.toLocaleString()} {$t('finance.leaseAndRent.paid')} {getLastPaidDate(row, col)})</span>
                                                                    {:else}
                                                                        <span class="font-semibold text-[10px] {row.hasChange && (col === 'contract' || col === 'outside') ? 'text-amber-700' : 'text-slate-800'}">{due.toLocaleString()}</span>
                                                                    {/if}
                                                                </span>
                                                            </div>
                                                        </td>
                                                    {/each}
                                                    <td class="px-2 py-1.5 font-bold text-emerald-800 bg-emerald-50/50 whitespace-nowrap">{row.total.toLocaleString()}</td>
                                                    <td class="px-2 py-1.5 font-bold {isFullyPaid(row) ? 'text-green-700' : isPartiallyPaid(row) ? 'text-yellow-700' : 'text-slate-400'} whitespace-nowrap">{getPaidAmount(row).toLocaleString()}</td>
                                                    <td class="px-2 py-1.5">
                                                        {#if isFullyPaid(row)}
                                                            <span class="inline-flex px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-green-100 text-green-700">✅ {$t('finance.leaseAndRent.fullyPaid')}</span>
                                                        {:else if isPartiallyPaid(row)}
                                                            <span class="inline-flex px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-yellow-100 text-yellow-700">⚡ {$t('finance.leaseAndRent.partiallyPaid')}</span>
                                                        {:else if row.hasChange}
                                                            <span class="inline-flex px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-amber-100 text-amber-700" title={row.appliedChanges.join(', ')}>⚠️ {$t('finance.leaseAndRent.changed')}</span>
                                                        {:else}
                                                            <span class="inline-flex px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-slate-100 text-slate-500">{$t('finance.leaseAndRent.unpaid')}</span>
                                                        {/if}
                                                    </td>
                                                </tr>
                                            {/each}
                                        </tbody>
                                    </table>
                                </div>
                                <!-- Footer Totals -->
                                <div class="border-t-2 border-emerald-300 bg-white/80 backdrop-blur-sm">
                                    <table class="w-full border-collapse text-xs [&_td]:border-x [&_td]:border-slate-100">
                                        <tfoot>
                                            <tr class="bg-emerald-100/80 font-bold">
                                                <td class="px-2 py-2 w-[60px]" colspan="1"></td>
                                                <td class="px-2 py-2" colspan="2">{$t('finance.leaseAndRent.total')}</td>
                                                <td class="px-2 py-2 text-emerald-800">{paymentSchedule.reduce((s, r) => s + r.amtContract, 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-emerald-800">{paymentSchedule.reduce((s, r) => s + r.amtOutside, 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-emerald-800">{paymentSchedule.reduce((s, r) => s + r.amtUtility, 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-emerald-800">{paymentSchedule.reduce((s, r) => s + r.amtSecurity, 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-emerald-800">{paymentSchedule.reduce((s, r) => s + r.amtOther, 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-emerald-900 bg-emerald-200/50 font-black">{paymentSchedule.reduce((s, r) => s + r.total, 0).toLocaleString()}</td>
                                                <td class="px-2 py-2"></td>
                                                <td class="px-2 py-2"></td>
                                            </tr>
                                            <tr class="bg-green-100/80 font-bold">
                                                <td class="px-2 py-2" colspan="1"></td>
                                                <td class="px-2 py-2 text-green-800" colspan="2">✅ {$t('finance.leaseAndRent.paidTotal')}</td>
                                                <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidContract) || 0), 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidOutside) || 0), 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidUtility) || 0), 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidSecurity) || 0), 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidOther) || 0), 0).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-green-900 bg-green-200/50 font-black">{paymentSchedule.reduce((s, r) => s + getPaidAmount(r), 0).toLocaleString()}</td>
                                                <td class="px-2 py-2"></td>
                                                <td class="px-2 py-2"></td>
                                            </tr>
                                            <tr class="bg-red-100/80 font-bold">
                                                <td class="px-2 py-2" colspan="1"></td>
                                                <td class="px-2 py-2 text-red-800" colspan="2">❌ {$t('finance.leaseAndRent.unpaidTotal')}</td>
                                                <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtContract, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidContract) || 0), 0)).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtOutside, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidOutside) || 0), 0)).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtUtility, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidUtility) || 0), 0)).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtSecurity, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidSecurity) || 0), 0)).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtOther, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidOther) || 0), 0)).toLocaleString()}</td>
                                                <td class="px-2 py-2 text-red-900 bg-red-200/50 font-black">{(paymentSchedule.reduce((s, r) => s + r.total, 0) - paymentSchedule.reduce((s, r) => s + getPaidAmount(r), 0)).toLocaleString()}</td>
                                                <td class="px-2 py-2"></td>
                                                <td class="px-2 py-2"></td>
                                            </tr>
                                        </tfoot>
                                    </table>
                                </div>
                                <div class="px-4 py-2 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold flex items-center gap-3">
                                    <span>{$t('finance.leaseAndRent.showingRecords', { count: paymentSchedule.length })}</span>
                                    {#if paymentSaving}
                                        <span class="text-emerald-600 animate-pulse">💾 {$t('finance.leaseAndRent.saving')}</span>
                                    {/if}
                                </div>
                            </div>
                        </div>
                    {/if}
                {/if}

            {:else if activeTab === 'rent'}
                {#if rentPartiesLoading}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center">
                        <div class="text-4xl mb-3 animate-spin">⏳</div>
                        <p class="text-slate-500 font-semibold text-sm">{$t('common.loading')}...</p>
                    </div>
                {:else if rentRecords.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">🏠</div>
                        <p class="text-slate-600 font-semibold">{$t('finance.leaseAndRent.noRentRecords')}</p>
                    </div>
                {:else}
                    <!-- Rent Parties Full Details Table -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex flex-col">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse text-xs [&_th]:border-x [&_th]:border-orange-500/30 [&_td]:border-x [&_td]:border-slate-100">
                                <thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">#</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.partyName')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.contactDetails')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.propertyColumn')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.contractDates')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.rentAmount')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.charges')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.otherCharges')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.paymentMode')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400 bg-orange-700">{$t('finance.leaseAndRent.totalRent')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('finance.leaseAndRent.paymentPeriod')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-orange-400 bg-orange-700">{$t('finance.leaseAndRent.changesColumn')}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each rentRecords as record, index}
                                        <tr class="hover:bg-orange-50/40 transition-colors duration-150 {index % 2 === 0 ? 'bg-slate-50/30' : 'bg-white/30'}">
                                            <td class="px-2 py-2 text-slate-500 font-semibold">{index + 1}</td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="text-slate-800 font-semibold">{record.party_name_en || '—'}</div>
                                                <div class="text-orange-700 font-semibold" dir="rtl">{record.party_name_ar || '—'}</div>
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="text-emerald-700 font-semibold">{record.contact_number || '—'}</div>
                                                <div class="text-blue-600 font-semibold">{record.email || '—'}</div>
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="text-slate-800 font-semibold">{$locale === 'ar' ? (record.property?.name_ar || '—') : (record.property?.name_en || '—')}</div>
                                                <div class="text-blue-700 font-semibold">{$t('finance.leaseAndRent.spaceNumber')}: {record.space?.space_number || '—'}</div>
                                                <div class="text-violet-700 font-semibold">{record.shop_name || '—'}</div>
                                            </td>
                                            <td class="px-2 py-2 text-slate-700 whitespace-nowrap leading-tight">
                                                <div class="text-slate-800">{fmtDate(record.contract_start_date) || '—'}</div>
                                                <div class="text-[10px] text-slate-400">{record.is_open_contract ? '♾️ Open' : (fmtDate(record.contract_end_date) || '—')}</div>
                                                <div><span class="inline-flex px-1.5 py-0 rounded-full text-[9px] font-bold
                                                    {getRemainingTime(record.contract_end_date, record.is_open_contract) === '♾️' ? 'bg-purple-100 text-purple-700' : getRemainingTime(record.contract_end_date, record.is_open_contract) === '⛔ Expired' ? 'bg-red-100 text-red-700' : 'bg-emerald-100 text-emerald-700'}">{getRemainingTime(record.contract_end_date, record.is_open_contract)}</span></div>
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="flex items-center gap-1"><span class="text-green-600">✅</span><span class="text-slate-800 font-semibold">{record.rent_amount_contract ? Number(record.rent_amount_contract).toLocaleString() : '—'}</span></div>
                                                <div class="flex items-center gap-1"><span class="text-red-500">✔</span><span class="text-slate-800 font-semibold">{record.rent_amount_outside_contract ? Number(record.rent_amount_outside_contract).toLocaleString() : '—'}</span></div>
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="flex items-center gap-1"><span class="text-cyan-600 font-semibold">{$t('finance.leaseAndRent.utilityCharges')}:</span><span class="text-slate-800 font-semibold">{record.utility_charges ? Number(record.utility_charges).toLocaleString() : '—'}</span></div>
                                                <div class="flex items-center gap-1"><span class="text-amber-600 font-semibold">{$t('finance.leaseAndRent.securityCharges')}:</span><span class="text-slate-800 font-semibold">{record.security_charges ? Number(record.security_charges).toLocaleString() : '—'}</span></div>
                                            </td>
                                            <td class="px-2 py-2">
                                                {#if record.other_charges && record.other_charges.length > 0}
                                                    <div class="relative inline-flex items-center gap-1 other-charges-detail">
                                                        <span class="font-semibold text-slate-800">{record.other_charges.reduce((s, c) => s + (Number(c.amount) || 0), 0).toLocaleString()}</span>
                                                        <button class="w-4 h-4 rounded-full bg-amber-500 text-white text-[9px] font-bold leading-none hover:bg-amber-600 transition-colors" on:click={() => { otherChargesDetailId = otherChargesDetailId === record.id ? null : record.id; }}>?</button>
                                                        {#if otherChargesDetailId === record.id}
                                                            <div class="absolute z-50 top-6 {$locale === 'ar' ? 'right-0' : 'left-0'} bg-white border border-amber-200 rounded-xl shadow-xl p-3 min-w-[160px]">
                                                                <div class="text-[10px] font-bold text-amber-700 uppercase mb-1.5">{$t('finance.leaseAndRent.otherCharges')}</div>
                                                                {#each record.other_charges as charge}
                                                                    <div class="flex justify-between text-xs py-0.5 border-b border-slate-100 last:border-0">
                                                                        <span class="text-slate-700">{charge.name}</span>
                                                                        <span class="font-semibold text-slate-800">{Number(charge.amount).toLocaleString()}</span>
                                                                    </div>
                                                                {/each}
                                                                <div class="flex justify-between text-xs pt-1.5 mt-1 border-t border-amber-300 font-bold">
                                                                    <span class="text-amber-700">Total</span>
                                                                    <span class="text-amber-800">{record.other_charges.reduce((s, c) => s + (Number(c.amount) || 0), 0).toLocaleString()}</span>
                                                                </div>
                                                            </div>
                                                        {/if}
                                                    </div>
                                                {:else}
                                                    <span class="text-slate-400">—</span>
                                                {/if}
                                            </td>
                                            <td class="px-2 py-2">
                                                <span class="inline-flex px-2 py-0.5 rounded-full text-[10px] font-bold {record.payment_mode === 'bank' ? 'bg-blue-100 text-blue-700' : 'bg-green-100 text-green-700'}">
                                                    {record.payment_mode === 'bank' ? $t('finance.leaseAndRent.bank') : $t('finance.leaseAndRent.cash')}
                                                </span>
                                            </td>
                                            <td class="px-2 py-2 font-bold text-orange-800 bg-orange-50/50 whitespace-nowrap">{((Number(record.rent_amount_contract) || 0) + (Number(record.rent_amount_outside_contract) || 0) + (Number(record.utility_charges) || 0) + (Number(record.security_charges) || 0) + (record.other_charges ? record.other_charges.reduce((s, c) => s + (Number(c.amount) || 0), 0) : 0)).toLocaleString()}</td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                <div class="text-slate-800 font-semibold capitalize">{(record.payment_period || 'monthly').replace(/_/g, ' ')}</div>
                                                {#if record.payment_period === 'daily'}
                                                    <div class="text-blue-600 text-[10px] font-semibold">{$t('finance.leaseAndRent.everyDay')}</div>
                                                {:else if record.payment_end_of_month}
                                                    <div class="text-violet-600 text-[10px] font-semibold">{$t('finance.leaseAndRent.endOfMonth')}</div>
                                                {:else if record.payment_specific_date}
                                                    <div class="text-blue-600 text-[10px] font-semibold">{$t('finance.leaseAndRent.dayOfMonth', { day: record.payment_specific_date })}</div>
                                                {/if}
                                            </td>
                                            <td class="px-2 py-2 whitespace-nowrap leading-snug">
                                                {#if rentChangesMap[record.id] && rentChangesMap[record.id].length > 0}
                                                    {@const changes = rentChangesMap[record.id]}
                                                    {@const latest = changes[0]}
                                                    <div class="flex flex-col gap-0.5">
                                                        <span class="inline-flex px-1.5 py-0 rounded-full text-[9px] font-bold bg-purple-100 text-purple-700">{changes.length} {$t('finance.leaseAndRent.changesColumn')}</span>
                                                        <div class="text-[10px] text-slate-600">{$t('finance.leaseAndRent.latestChange')}: <span class="font-semibold text-purple-700">{latest.field_name?.replace(/_/g, ' ')}</span></div>
                                                        <div class="text-[10px] text-slate-500">{Number(latest.old_value).toLocaleString()} → <span class="font-bold text-emerald-700">{Number(latest.new_value).toLocaleString()}</span></div>
                                                        <div class="text-[9px] text-slate-400">{fmtDate(latest.effective_from) || '—'}</div>
                                                    </div>
                                                {:else}
                                                    <span class="text-slate-400 text-[10px]">{$t('finance.leaseAndRent.noChanges')}</span>
                                                {/if}
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                        <div class="px-4 py-2 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('finance.leaseAndRent.showingRecords', { count: rentRecords.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'leaseSpecial'}
                <!-- Lease Special Changes -->
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
                    <h3 class="text-base font-bold text-slate-800 mb-4 flex items-center gap-2">
                        <span class="text-xl">✨</span> {$t('finance.leaseAndRent.leaseSpecialTab')}
                    </h3>
                    <!-- Party Search Dropdown -->
                    <div class="mb-4">
                        <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectParty')}</label>
                        <div class="relative lease-special-party-container">
                            {#if selectedLeaseSpecialParty}
                                <div class="flex items-center gap-2 px-4 py-2.5 bg-blue-50 border border-blue-200 rounded-xl">
                                    <span class="text-blue-800 font-bold text-sm flex-1">{selectedLeaseSpecialParty.party_name_en} — <span dir="rtl">{selectedLeaseSpecialParty.party_name_ar}</span></span>
                                    <button class="text-red-400 hover:text-red-600 text-lg font-bold" on:click={clearLeaseSpecialParty}>✕</button>
                                </div>
                            {:else}
                                <input
                                    type="text"
                                    bind:value={leaseSpecialPartySearch}
                                    on:focus={() => { showLeaseSpecialPartyDropdown = true; }}
                                    placeholder={$t('finance.leaseAndRent.searchPartyPlaceholder')}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                                />
                                {#if showLeaseSpecialPartyDropdown}
                                    <div class="absolute z-40 top-full mt-1 w-full max-h-52 overflow-y-auto bg-white border border-slate-200 rounded-xl shadow-xl">
                                        {#each filteredLeaseSpecialParties as party}
                                            <button class="w-full text-left px-4 py-2.5 hover:bg-blue-50 transition-colors text-sm border-b border-slate-50 last:border-0" on:click={() => selectLeaseSpecialParty(party)}>
                                                <div class="font-semibold text-slate-800">{party.party_name_en}</div>
                                                <div class="text-blue-600 text-xs" dir="rtl">{party.party_name_ar}</div>
                                            </button>
                                        {:else}
                                            <div class="px-4 py-3 text-sm text-slate-400 text-center">{$t('finance.leaseAndRent.noResults')}</div>
                                        {/each}
                                    </div>
                                {/if}
                            {/if}
                        </div>
                    </div>

                    <!-- Selected Party Data -->
                    {#if selectedLeaseSpecialParty}
                        <div class="bg-white/60 rounded-2xl border border-slate-200 p-5 space-y-3">
                            <h4 class="text-sm font-bold text-blue-700 uppercase tracking-wide mb-3 flex items-center gap-2">📊 {$t('finance.leaseAndRent.currentData')} <span class="text-[10px] text-slate-400 normal-case font-normal">({$t('finance.leaseAndRent.doubleClickToChange')})</span></h4>
                            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
                                <div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
                                    <div class="text-[10px] font-bold text-slate-500 uppercase mb-1">{$t('finance.leaseAndRent.contractDates')}</div>
                                    <div class="text-sm font-semibold text-slate-800">{fmtDate(selectedLeaseSpecialParty.contract_start_date) || '—'}</div>
                                    <div class="text-xs text-slate-500">{selectedLeaseSpecialParty.is_open_contract ? '♾️ Open' : (fmtDate(selectedLeaseSpecialParty.contract_end_date) || '—')}</div>
                                </div>
                                <div class="bg-green-50 rounded-xl p-3 border border-green-100 cursor-pointer hover:ring-2 hover:ring-green-400 transition-all" on:dblclick={() => openSpecialChangePopup('lease', selectedLeaseSpecialParty, 'lease_amount_contract', $t('finance.leaseAndRent.amountContract'), Number(selectedLeaseSpecialParty.lease_amount_contract) || 0)}>
                                    <div class="text-[10px] font-bold text-green-600 uppercase mb-1">✅ {$t('finance.leaseAndRent.amountContract')}</div>
                                    <div class="text-sm font-bold text-green-800">{selectedLeaseSpecialParty.lease_amount_contract ? Number(selectedLeaseSpecialParty.lease_amount_contract).toLocaleString() : '—'}</div>
                                </div>
                                <div class="bg-red-50 rounded-xl p-3 border border-red-100 cursor-pointer hover:ring-2 hover:ring-red-400 transition-all" on:dblclick={() => openSpecialChangePopup('lease', selectedLeaseSpecialParty, 'lease_amount_outside_contract', $t('finance.leaseAndRent.amountOutsideContract'), Number(selectedLeaseSpecialParty.lease_amount_outside_contract) || 0)}>
                                    <div class="text-[10px] font-bold text-red-600 uppercase mb-1">✔ {$t('finance.leaseAndRent.amountOutsideContract')}</div>
                                    <div class="text-sm font-bold text-red-800">{selectedLeaseSpecialParty.lease_amount_outside_contract ? Number(selectedLeaseSpecialParty.lease_amount_outside_contract).toLocaleString() : '—'}</div>
                                </div>
                                <div class="bg-cyan-50 rounded-xl p-3 border border-cyan-100 cursor-pointer hover:ring-2 hover:ring-cyan-400 transition-all" on:dblclick={() => openSpecialChangePopup('lease', selectedLeaseSpecialParty, 'utility_charges', $t('finance.leaseAndRent.utilityCharges'), Number(selectedLeaseSpecialParty.utility_charges) || 0)}>
                                    <div class="text-[10px] font-bold text-cyan-600 uppercase mb-1">{$t('finance.leaseAndRent.utilityCharges')}</div>
                                    <div class="text-sm font-bold text-cyan-800">{selectedLeaseSpecialParty.utility_charges ? Number(selectedLeaseSpecialParty.utility_charges).toLocaleString() : '—'}</div>
                                </div>
                                <div class="bg-amber-50 rounded-xl p-3 border border-amber-100 cursor-pointer hover:ring-2 hover:ring-amber-400 transition-all" on:dblclick={() => openSpecialChangePopup('lease', selectedLeaseSpecialParty, 'security_charges', $t('finance.leaseAndRent.securityCharges'), Number(selectedLeaseSpecialParty.security_charges) || 0)}>
                                    <div class="text-[10px] font-bold text-amber-600 uppercase mb-1">{$t('finance.leaseAndRent.securityCharges')}</div>
                                    <div class="text-sm font-bold text-amber-800">{selectedLeaseSpecialParty.security_charges ? Number(selectedLeaseSpecialParty.security_charges).toLocaleString() : '—'}</div>
                                </div>
                                <div class="bg-violet-50 rounded-xl p-3 border border-violet-100">
                                    <div class="text-[10px] font-bold text-violet-600 uppercase mb-1">{$t('finance.leaseAndRent.otherCharges')}</div>
                                    <div class="text-sm font-bold text-violet-800">{selectedLeaseSpecialParty.other_charges ? selectedLeaseSpecialParty.other_charges.reduce((s: number, c: any) => s + (Number(c.amount) || 0), 0).toLocaleString() : '—'}</div>
                                    {#if selectedLeaseSpecialParty.other_charges && selectedLeaseSpecialParty.other_charges.length > 0}
                                        <div class="mt-1 space-y-0.5">
                                            {#each selectedLeaseSpecialParty.other_charges as charge}
                                                <div class="text-[10px] text-violet-600">{charge.name}: {Number(charge.amount).toLocaleString()}</div>
                                            {/each}
                                        </div>
                                    {/if}
                                </div>
                                <div class="bg-blue-50 rounded-xl p-3 border border-blue-100">
                                    <div class="text-[10px] font-bold text-blue-600 uppercase mb-1">{$t('finance.leaseAndRent.paymentMode')}</div>
                                    <div class="text-sm font-bold text-blue-800 capitalize">{selectedLeaseSpecialParty.payment_mode || '—'}</div>
                                </div>
                                <div class="bg-emerald-50 rounded-xl p-3 border border-emerald-200">
                                    <div class="text-[10px] font-bold text-emerald-600 uppercase mb-1">{$t('finance.leaseAndRent.totalLease')}</div>
                                    <div class="text-lg font-black text-emerald-800">{((Number(selectedLeaseSpecialParty.lease_amount_contract) || 0) + (Number(selectedLeaseSpecialParty.lease_amount_outside_contract) || 0) + (Number(selectedLeaseSpecialParty.utility_charges) || 0) + (Number(selectedLeaseSpecialParty.security_charges) || 0) + (selectedLeaseSpecialParty.other_charges ? selectedLeaseSpecialParty.other_charges.reduce((s: number, c: any) => s + (Number(c.amount) || 0), 0) : 0)).toLocaleString()}</div>
                                </div>
                            </div>
                        </div>
                        <!-- Changes History -->
                        {#if specialChangesHistory.length > 0}
                            <div class="bg-white/60 rounded-2xl border border-blue-200 p-5 mt-4">
                                <h4 class="text-sm font-bold text-blue-700 uppercase tracking-wide mb-3 flex items-center gap-2">📜 {$t('finance.leaseAndRent.changesHistory')} ({specialChangesHistory.length})</h4>
                                <div class="overflow-x-auto">
                                    <table class="w-full text-xs">
                                        <thead><tr class="bg-blue-50">
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-blue-700">{$t('finance.leaseAndRent.fieldChanged')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-blue-700">{$t('finance.leaseAndRent.oldValueLabel')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-blue-700">{$t('finance.leaseAndRent.newValueLabel')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-blue-700">{$t('finance.leaseAndRent.effectiveFrom')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-blue-700">{$t('finance.leaseAndRent.effectiveUntil')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-blue-700">{$t('finance.leaseAndRent.reasonLabel')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-blue-700">{$t('finance.leaseAndRent.dateCreated')}</th>
                                        </tr></thead>
                                        <tbody class="divide-y divide-slate-100">
                                            {#each specialChangesHistory as change}
                                                <tr class="hover:bg-blue-50/40">
                                                    <td class="px-2 py-1.5 font-semibold text-slate-700 capitalize">{change.field_name.replace(/_/g, ' ')}</td>
                                                    <td class="px-2 py-1.5 text-red-600 font-semibold">{Number(change.old_value).toLocaleString()}</td>
                                                    <td class="px-2 py-1.5 text-green-600 font-bold">{Number(change.new_value).toLocaleString()}</td>
                                                    <td class="px-2 py-1.5 text-slate-700">{fmtDate(change.effective_from)}</td>
                                                    <td class="px-2 py-1.5 text-slate-700">{change.till_end_of_contract ? '♾️ ' + $t('finance.leaseAndRent.tillEndOfContract') : (fmtDate(change.effective_until) || '—')}</td>
                                                    <td class="px-2 py-1.5 text-slate-500">{change.reason || '—'}</td>
                                                    <td class="px-2 py-1.5 text-slate-400">{fmtDate(change.created_at)}</td>
                                                </tr>
                                            {/each}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        {/if}
                    {/if}
                </div>
            {:else if activeTab === 'rentSpecial'}
                <!-- Rent Special Changes -->
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
                    <h3 class="text-base font-bold text-slate-800 mb-4 flex items-center gap-2">
                        <span class="text-xl">🔧</span> {$t('finance.leaseAndRent.rentSpecialTab')}
                    </h3>
                    <!-- Party Search Dropdown -->
                    <div class="mb-4">
                        <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectParty')}</label>
                        <div class="relative rent-special-party-container">
                            {#if selectedRentSpecialParty}
                                <div class="flex items-center gap-2 px-4 py-2.5 bg-purple-50 border border-purple-200 rounded-xl">
                                    <span class="text-purple-800 font-bold text-sm flex-1">{selectedRentSpecialParty.party_name_en} — <span dir="rtl">{selectedRentSpecialParty.party_name_ar}</span></span>
                                    <button class="text-red-400 hover:text-red-600 text-lg font-bold" on:click={clearRentSpecialParty}>✕</button>
                                </div>
                            {:else}
                                <input
                                    type="text"
                                    bind:value={rentSpecialPartySearch}
                                    on:focus={() => { showRentSpecialPartyDropdown = true; }}
                                    placeholder={$t('finance.leaseAndRent.searchPartyPlaceholder')}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all"
                                />
                                {#if showRentSpecialPartyDropdown}
                                    <div class="absolute z-40 top-full mt-1 w-full max-h-52 overflow-y-auto bg-white border border-slate-200 rounded-xl shadow-xl">
                                        {#each filteredRentSpecialParties as party}
                                            <button class="w-full text-left px-4 py-2.5 hover:bg-purple-50 transition-colors text-sm border-b border-slate-50 last:border-0" on:click={() => selectRentSpecialParty(party)}>
                                                <div class="font-semibold text-slate-800">{party.party_name_en}</div>
                                                <div class="text-purple-600 text-xs" dir="rtl">{party.party_name_ar}</div>
                                            </button>
                                        {:else}
                                            <div class="px-4 py-3 text-sm text-slate-400 text-center">{$t('finance.leaseAndRent.noResults')}</div>
                                        {/each}
                                    </div>
                                {/if}
                            {/if}
                        </div>
                    </div>

                    <!-- Selected Party Data -->
                    {#if selectedRentSpecialParty}
                        <div class="bg-white/60 rounded-2xl border border-slate-200 p-5 space-y-3">
                            <h4 class="text-sm font-bold text-purple-700 uppercase tracking-wide mb-3 flex items-center gap-2">📊 {$t('finance.leaseAndRent.currentData')} <span class="text-[10px] text-slate-400 normal-case font-normal">({$t('finance.leaseAndRent.doubleClickToChange')})</span></h4>
                            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
                                <div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
                                    <div class="text-[10px] font-bold text-slate-500 uppercase mb-1">{$t('finance.leaseAndRent.contractDates')}</div>
                                    <div class="text-sm font-semibold text-slate-800">{fmtDate(selectedRentSpecialParty.contract_start_date) || '—'}</div>
                                    <div class="text-xs text-slate-500">{selectedRentSpecialParty.is_open_contract ? '♾️ Open' : (fmtDate(selectedRentSpecialParty.contract_end_date) || '—')}</div>
                                </div>
                                <div class="bg-green-50 rounded-xl p-3 border border-green-100 cursor-pointer hover:ring-2 hover:ring-green-400 transition-all" on:dblclick={() => openSpecialChangePopup('rent', selectedRentSpecialParty, 'rent_amount_contract', $t('finance.leaseAndRent.amountContract'), Number(selectedRentSpecialParty.rent_amount_contract) || 0)}>
                                    <div class="text-[10px] font-bold text-green-600 uppercase mb-1">✅ {$t('finance.leaseAndRent.amountContract')}</div>
                                    <div class="text-sm font-bold text-green-800">{selectedRentSpecialParty.rent_amount_contract ? Number(selectedRentSpecialParty.rent_amount_contract).toLocaleString() : '—'}</div>
                                </div>
                                <div class="bg-red-50 rounded-xl p-3 border border-red-100 cursor-pointer hover:ring-2 hover:ring-red-400 transition-all" on:dblclick={() => openSpecialChangePopup('rent', selectedRentSpecialParty, 'rent_amount_outside_contract', $t('finance.leaseAndRent.amountOutsideContract'), Number(selectedRentSpecialParty.rent_amount_outside_contract) || 0)}>
                                    <div class="text-[10px] font-bold text-red-600 uppercase mb-1">✔ {$t('finance.leaseAndRent.amountOutsideContract')}</div>
                                    <div class="text-sm font-bold text-red-800">{selectedRentSpecialParty.rent_amount_outside_contract ? Number(selectedRentSpecialParty.rent_amount_outside_contract).toLocaleString() : '—'}</div>
                                </div>
                                <div class="bg-cyan-50 rounded-xl p-3 border border-cyan-100 cursor-pointer hover:ring-2 hover:ring-cyan-400 transition-all" on:dblclick={() => openSpecialChangePopup('rent', selectedRentSpecialParty, 'utility_charges', $t('finance.leaseAndRent.utilityCharges'), Number(selectedRentSpecialParty.utility_charges) || 0)}>
                                    <div class="text-[10px] font-bold text-cyan-600 uppercase mb-1">{$t('finance.leaseAndRent.utilityCharges')}</div>
                                    <div class="text-sm font-bold text-cyan-800">{selectedRentSpecialParty.utility_charges ? Number(selectedRentSpecialParty.utility_charges).toLocaleString() : '—'}</div>
                                </div>
                                <div class="bg-amber-50 rounded-xl p-3 border border-amber-100 cursor-pointer hover:ring-2 hover:ring-amber-400 transition-all" on:dblclick={() => openSpecialChangePopup('rent', selectedRentSpecialParty, 'security_charges', $t('finance.leaseAndRent.securityCharges'), Number(selectedRentSpecialParty.security_charges) || 0)}>
                                    <div class="text-[10px] font-bold text-amber-600 uppercase mb-1">{$t('finance.leaseAndRent.securityCharges')}</div>
                                    <div class="text-sm font-bold text-amber-800">{selectedRentSpecialParty.security_charges ? Number(selectedRentSpecialParty.security_charges).toLocaleString() : '—'}</div>
                                </div>
                                <div class="bg-violet-50 rounded-xl p-3 border border-violet-100">
                                    <div class="text-[10px] font-bold text-violet-600 uppercase mb-1">{$t('finance.leaseAndRent.otherCharges')}</div>
                                    <div class="text-sm font-bold text-violet-800">{selectedRentSpecialParty.other_charges ? selectedRentSpecialParty.other_charges.reduce((s: number, c: any) => s + (Number(c.amount) || 0), 0).toLocaleString() : '—'}</div>
                                    {#if selectedRentSpecialParty.other_charges && selectedRentSpecialParty.other_charges.length > 0}
                                        <div class="mt-1 space-y-0.5">
                                            {#each selectedRentSpecialParty.other_charges as charge}
                                                <div class="text-[10px] text-violet-600">{charge.name}: {Number(charge.amount).toLocaleString()}</div>
                                            {/each}
                                        </div>
                                    {/if}
                                </div>
                                <div class="bg-blue-50 rounded-xl p-3 border border-blue-100">
                                    <div class="text-[10px] font-bold text-blue-600 uppercase mb-1">{$t('finance.leaseAndRent.paymentMode')}</div>
                                    <div class="text-sm font-bold text-blue-800 capitalize">{selectedRentSpecialParty.payment_mode || '—'}</div>
                                </div>
                                <div class="bg-orange-50 rounded-xl p-3 border border-orange-200">
                                    <div class="text-[10px] font-bold text-orange-600 uppercase mb-1">{$t('finance.leaseAndRent.totalRent')}</div>
                                    <div class="text-lg font-black text-orange-800">{((Number(selectedRentSpecialParty.rent_amount_contract) || 0) + (Number(selectedRentSpecialParty.rent_amount_outside_contract) || 0) + (Number(selectedRentSpecialParty.utility_charges) || 0) + (Number(selectedRentSpecialParty.security_charges) || 0) + (selectedRentSpecialParty.other_charges ? selectedRentSpecialParty.other_charges.reduce((s: number, c: any) => s + (Number(c.amount) || 0), 0) : 0)).toLocaleString()}</div>
                                </div>
                            </div>
                        </div>
                        <!-- Changes History -->
                        {#if specialChangesHistory.length > 0}
                            <div class="bg-white/60 rounded-2xl border border-purple-200 p-5 mt-4">
                                <h4 class="text-sm font-bold text-purple-700 uppercase tracking-wide mb-3 flex items-center gap-2">📜 {$t('finance.leaseAndRent.changesHistory')} ({specialChangesHistory.length})</h4>
                                <div class="overflow-x-auto">
                                    <table class="w-full text-xs">
                                        <thead><tr class="bg-purple-50">
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-purple-700">{$t('finance.leaseAndRent.fieldChanged')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-purple-700">{$t('finance.leaseAndRent.oldValueLabel')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-purple-700">{$t('finance.leaseAndRent.newValueLabel')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-purple-700">{$t('finance.leaseAndRent.effectiveFrom')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-purple-700">{$t('finance.leaseAndRent.effectiveUntil')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-purple-700">{$t('finance.leaseAndRent.reasonLabel')}</th>
                                            <th class="px-2 py-1.5 {$locale === 'ar' ? 'text-right' : 'text-left'} font-bold text-purple-700">{$t('finance.leaseAndRent.dateCreated')}</th>
                                        </tr></thead>
                                        <tbody class="divide-y divide-slate-100">
                                            {#each specialChangesHistory as change}
                                                <tr class="hover:bg-purple-50/40">
                                                    <td class="px-2 py-1.5 font-semibold text-slate-700 capitalize">{change.field_name.replace(/_/g, ' ')}</td>
                                                    <td class="px-2 py-1.5 text-red-600 font-semibold">{Number(change.old_value).toLocaleString()}</td>
                                                    <td class="px-2 py-1.5 text-green-600 font-bold">{Number(change.new_value).toLocaleString()}</td>
                                                    <td class="px-2 py-1.5 text-slate-700">{fmtDate(change.effective_from)}</td>
                                                    <td class="px-2 py-1.5 text-slate-700">{change.till_end_of_contract ? '♾️ ' + $t('finance.leaseAndRent.tillEndOfContract') : (fmtDate(change.effective_until) || '—')}</td>
                                                    <td class="px-2 py-1.5 text-slate-500">{change.reason || '—'}</td>
                                                    <td class="px-2 py-1.5 text-slate-400">{fmtDate(change.created_at)}</td>
                                                </tr>
                                            {/each}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        {/if}
                    {/if}
                </div>
            {:else if activeTab === 'reports'}
                <!-- Reports Action Buttons -->
                <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg px-4 py-2.5 mb-3 overflow-visible relative z-30">
                    <div class="flex items-center gap-3 flex-wrap">
                        <div class="flex gap-2 flex-wrap">
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105
                                {reportType === 'lease' ? 'bg-emerald-700 shadow-md shadow-emerald-300 ring-2 ring-emerald-400 scale-105' : 'bg-emerald-600 shadow-sm shadow-emerald-200'}"
                                on:click={() => { loadCurrentMonthReport('lease'); }}
                            >
                                📋 {$t('finance.leaseAndRent.leaseReport')}
                            </button>
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105
                                {reportType === 'rent' ? 'bg-orange-700 shadow-md shadow-orange-300 ring-2 ring-orange-400 scale-105' : 'bg-orange-600 shadow-sm shadow-orange-200'}"
                                on:click={() => { loadCurrentMonthReport('rent'); }}
                            >
                                🏠 {$t('finance.leaseAndRent.rentReport')}
                            </button>
                        </div>
                        <!-- Generate Custom Report button -->
                        {#if reportType}
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105 bg-cyan-600 shadow-sm shadow-cyan-200"
                                on:click={() => { openReportPopup(reportType || 'lease'); }}
                            >
                                🔍 {$t('finance.leaseAndRent.generateReport')}
                            </button>
                        {/if}
                        {#if reportLoading}
                            <span class="text-xs text-cyan-600 font-bold animate-pulse">⏳ {$t('finance.leaseAndRent.reportLoading')}</span>
                        {/if}
                    </div>
                </div>

                <!-- Report Table (shown after Generate) -->
                {#if reportGenerated && reportRows.length > 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex flex-col">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse text-xs">
                                <thead class="sticky top-0 z-10">
                                    <tr class="{reportType === 'lease' ? 'bg-emerald-600' : 'bg-orange-600'} text-white">
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 {reportType === 'lease' ? 'border-emerald-400' : 'border-orange-400'} sticky left-0 z-20 {reportType === 'lease' ? 'bg-emerald-600' : 'bg-orange-600'} min-w-[160px]">{$t('finance.leaseAndRent.reportPartyName')}</th>
                                        {#each reportMonthLabels as label}
                                            <th class="px-2 py-2 text-center font-black uppercase tracking-wider border-b-2 {reportType === 'lease' ? 'border-emerald-400' : 'border-orange-400'} whitespace-nowrap min-w-[90px]">{label}</th>
                                        {/each}
                                        <th class="px-2 py-2 text-center font-black uppercase tracking-wider border-b-2 {reportType === 'lease' ? 'border-emerald-400 bg-emerald-700' : 'border-orange-400 bg-orange-700'} whitespace-nowrap min-w-[90px]">{$t('finance.leaseAndRent.reportTotalDue')}</th>
                                        <th class="px-2 py-2 text-center font-black uppercase tracking-wider border-b-2 {reportType === 'lease' ? 'border-emerald-400' : 'border-orange-400'} bg-green-700 whitespace-nowrap min-w-[90px]">{$t('finance.leaseAndRent.reportTotalPaid')}</th>
                                        <th class="px-2 py-2 text-center font-black uppercase tracking-wider border-b-2 {reportType === 'lease' ? 'border-emerald-400' : 'border-orange-400'} bg-red-700 whitespace-nowrap min-w-[90px]">{$t('finance.leaseAndRent.reportTotalUnpaid')}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each reportRows as row, index}
                                        <tr class="{index % 2 === 0 ? 'bg-slate-50/30' : 'bg-white/30'} hover:bg-cyan-50/40 transition-colors duration-150">
                                            <td class="px-2 py-1.5 sticky left-0 z-10 bg-white/90 backdrop-blur-sm border-r border-slate-200 min-w-[160px]">
                                                <div class="font-bold text-slate-800 text-[10px] truncate">{row.party.party_name_en || '—'}</div>
                                                <div class="font-semibold {reportType === 'lease' ? 'text-emerald-700' : 'text-orange-700'} text-[9px] truncate" dir="rtl">{row.party.party_name_ar || '—'}</div>
                                            </td>
                                            {#each reportMonths as month}
                                                {@const m = row.months[month]}
                                                <td class="px-1 py-1 text-center">
                                                    {#if m && m.due > 0}
                                                        <div class="flex flex-col items-center gap-0.5">
                                                            {#if m.paid >= m.due}
                                                                <span class="font-bold text-[10px] text-green-700 bg-green-50 rounded px-1">{m.paid.toLocaleString()}</span>
                                                            {:else if m.paid > 0}
                                                                <span class="font-bold text-[10px] text-green-600 bg-green-50 rounded px-1">{m.paid.toLocaleString()}</span>
                                                                <span class="font-bold text-[9px] text-red-600 bg-red-50 rounded px-1">{(m.due - m.paid).toLocaleString()}</span>
                                                            {:else}
                                                                <span class="font-bold text-[10px] text-red-600 bg-red-50 rounded px-1">{m.due.toLocaleString()}</span>
                                                            {/if}
                                                        </div>
                                                    {:else}
                                                        <span class="text-slate-300">—</span>
                                                    {/if}
                                                </td>
                                            {/each}
                                            <td class="px-2 py-1.5 text-center font-black {reportType === 'lease' ? 'text-emerald-800 bg-emerald-50/50' : 'text-orange-800 bg-orange-50/50'}">{row.totalDue.toLocaleString()}</td>
                                            <td class="px-2 py-1.5 text-center font-black text-green-800 bg-green-50/50">{row.totalPaid.toLocaleString()}</td>
                                            <td class="px-2 py-1.5 text-center font-black text-red-800 bg-red-50/50">{row.totalUnpaid.toLocaleString()}</td>
                                        </tr>
                                    {/each}
                                </tbody>
                                <!-- Summary Footer -->
                                <tfoot>
                                    <tr class="{reportType === 'lease' ? 'bg-emerald-100/80' : 'bg-orange-100/80'} font-black border-t-2 {reportType === 'lease' ? 'border-emerald-400' : 'border-orange-400'}">
                                        <td class="px-2 py-2 sticky left-0 z-10 {reportType === 'lease' ? 'bg-emerald-100' : 'bg-orange-100'} border-r border-slate-200">{$t('finance.leaseAndRent.reportTotalDue')}</td>
                                        {#each reportMonths as month}
                                            <td class="px-1 py-2 text-center {reportType === 'lease' ? 'text-emerald-800' : 'text-orange-800'}">{reportRows.reduce((s, r) => s + (r.months[month]?.due || 0), 0).toLocaleString()}</td>
                                        {/each}
                                        <td class="px-2 py-2 text-center {reportType === 'lease' ? 'text-emerald-900 bg-emerald-200/50' : 'text-orange-900 bg-orange-200/50'}">{reportRows.reduce((s, r) => s + r.totalDue, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-center text-green-900 bg-green-200/50">{reportRows.reduce((s, r) => s + r.totalPaid, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-center text-red-900 bg-red-200/50">{reportRows.reduce((s, r) => s + r.totalUnpaid, 0).toLocaleString()}</td>
                                    </tr>
                                    <tr class="bg-green-100/80 font-black">
                                        <td class="px-2 py-2 sticky left-0 z-10 bg-green-100 border-r border-slate-200 text-green-800">✅ {$t('finance.leaseAndRent.reportTotalPaid')}</td>
                                        {#each reportMonths as month}
                                            <td class="px-1 py-2 text-center text-green-800">{reportRows.reduce((s, r) => s + (r.months[month]?.paid || 0), 0).toLocaleString()}</td>
                                        {/each}
                                        <td class="px-2 py-2"></td>
                                        <td class="px-2 py-2 text-center text-green-900 bg-green-200/50">{reportRows.reduce((s, r) => s + r.totalPaid, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2"></td>
                                    </tr>
                                    <tr class="bg-red-100/80 font-black">
                                        <td class="px-2 py-2 sticky left-0 z-10 bg-red-100 border-r border-slate-200 text-red-800">❌ {$t('finance.leaseAndRent.reportTotalUnpaid')}</td>
                                        {#each reportMonths as month}
                                            {@const due = reportRows.reduce((s, r) => s + (r.months[month]?.due || 0), 0)}
                                            {@const paid = reportRows.reduce((s, r) => s + (r.months[month]?.paid || 0), 0)}
                                            <td class="px-1 py-2 text-center text-red-800">{(due - paid).toLocaleString()}</td>
                                        {/each}
                                        <td class="px-2 py-2"></td>
                                        <td class="px-2 py-2"></td>
                                        <td class="px-2 py-2 text-center text-red-900 bg-red-200/50">{reportRows.reduce((s, r) => s + r.totalUnpaid, 0).toLocaleString()}</td>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                        <div class="px-4 py-2 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('finance.leaseAndRent.showingRecords', { count: reportRows.length })} — {reportMonths.length} {$t('finance.leaseAndRent.period')}s
                        </div>
                    </div>
                {:else if reportGenerated && reportRows.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📊</div>
                        <p class="text-slate-600 font-semibold">{$t('finance.leaseAndRent.reportNoData')}</p>
                    </div>
                {:else if !reportGenerated}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📊</div>
                        <p class="text-slate-600 font-semibold">{$t('finance.leaseAndRent.selectPartiesAndDateRange')}</p>
                    </div>
                {/if}

            {:else if activeTab === 'manager'}
                <!-- Manager Action Buttons -->
                <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg px-4 py-2.5 mb-2">
                    <div class="flex gap-2 flex-wrap">
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105
                                {managerActiveForm === 'lease' ? 'bg-emerald-700 shadow-md shadow-emerald-300 ring-2 ring-emerald-400 scale-105' : 'bg-emerald-600 shadow-sm shadow-emerald-200'}"
                                on:click={() => setManagerForm('lease')}
                            >
                                {$t('finance.leaseAndRent.addNewLease')}
                            </button>
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105
                                {managerActiveForm === 'rent' ? 'bg-orange-700 shadow-md shadow-orange-300 ring-2 ring-orange-400 scale-105' : 'bg-orange-600 shadow-sm shadow-orange-200'}"
                                on:click={() => setManagerForm('rent')}
                            >
                                {$t('finance.leaseAndRent.addNewRentParty')}
                            </button>
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105
                                {managerActiveForm === 'property' ? 'bg-violet-700 shadow-md shadow-violet-300 ring-2 ring-violet-400 scale-105' : 'bg-violet-600 shadow-sm shadow-violet-200'}"
                                on:click={() => setManagerForm('property')}
                            >
                                {$t('finance.leaseAndRent.addProperty')}
                            </button>
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105
                                {managerActiveForm === 'propertySpace' ? 'bg-rose-700 shadow-md shadow-rose-300 ring-2 ring-rose-400 scale-105' : 'bg-rose-600 shadow-sm shadow-rose-200'}"
                                on:click={() => setManagerForm('propertySpace')}
                            >
                                {$t('finance.leaseAndRent.addPropertySpace')}
                            </button>
                    </div>
                </div>

                <!-- Add / Edit Mode Buttons (separate card, shown only when a form is active) -->
                {#if managerActiveForm}
                    <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg px-4 py-2.5 mb-3">
                        <div class="flex gap-2">
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl font-bold text-xs transition-all duration-200 transform hover:scale-105
                                {formMode === 'add' ? 'bg-sky-600 text-white shadow-md shadow-sky-200 ring-2 ring-sky-400' : 'bg-white text-slate-700 border border-slate-200 hover:bg-sky-50 shadow-sm'}"
                                on:click={enterAddMode}
                            >
                                📝 {$t('finance.leaseAndRent.addMode')}
                            </button>
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl font-bold text-xs transition-all duration-200 transform hover:scale-105
                                {formMode === 'edit' ? 'bg-amber-600 text-white shadow-md shadow-amber-200 ring-2 ring-amber-400' : 'bg-white text-slate-700 border border-slate-200 hover:bg-amber-50 shadow-sm'}"
                                on:click={enterEditMode}
                            >
                                ✏️ {$t('finance.leaseAndRent.editMode')}
                            </button>
                        </div>
                    </div>
                {/if}

                <!-- Manager Form Area -->
                {#if managerActiveForm === 'property' && formMode}
                    <!-- Add Property Form -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8">
                        <h3 class="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2">
                            <span class="text-2xl">🏢</span> {formMode === 'edit' ? $t('finance.leaseAndRent.editProperty') : $t('finance.leaseAndRent.addProperty')}
                        </h3>
                        {#if formMode === 'edit'}
                            <div class="mb-6">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.selectRecordToEdit')}</label>
                                <select
                                    on:change={(e) => populatePropertyForEdit(e.currentTarget.value)}
                                    class="w-full px-4 py-2.5 bg-white border border-amber-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all"
                                >
                                    <option value="">{$t('finance.leaseAndRent.selectRecordToEdit')}</option>
                                    {#each editFullProperties as prop}
                                        <option value={prop.id} selected={editingPropertyId === prop.id}>{$locale === 'ar' ? prop.name_ar : prop.name_en}</option>
                                    {/each}
                                </select>
                            </div>
                        {/if}
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
                            <!-- Property Name English -->
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.propertyNameEn')}</label>
                                <input
                                    type="text"
                                    bind:value={propertyNameEn}
                                    placeholder={$t('finance.leaseAndRent.propertyNameEnPlaceholder')}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all"
                                />
                            </div>
                            <!-- Property Name Arabic -->
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.propertyNameAr')}</label>
                                <input
                                    type="text"
                                    bind:value={propertyNameAr}
                                    placeholder={$t('finance.leaseAndRent.propertyNameArPlaceholder')}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all"
                                    dir="rtl"
                                />
                            </div>
                            <!-- Property Location English -->
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.propertyLocationEn')}</label>
                                <input
                                    type="text"
                                    bind:value={propertyLocationEn}
                                    placeholder={$t('finance.leaseAndRent.propertyLocationEnPlaceholder')}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all"
                                />
                            </div>
                            <!-- Property Location Arabic -->
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.propertyLocationAr')}</label>
                                <input
                                    type="text"
                                    bind:value={propertyLocationAr}
                                    placeholder={$t('finance.leaseAndRent.propertyLocationArPlaceholder')}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all"
                                    dir="rtl"
                                />
                            </div>
                        </div>
                        <!-- Checkboxes -->
                        <div class="flex gap-6 mt-6">
                            <label class="flex items-center gap-3 cursor-pointer group">
                                <input type="checkbox" bind:checked={propertyIsLeased} class="w-5 h-5 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer" />
                                <span class="text-sm font-bold text-slate-700 group-hover:text-emerald-700 transition-colors">{$t('finance.leaseAndRent.propertyIsLeased')}</span>
                            </label>
                            <label class="flex items-center gap-3 cursor-pointer group">
                                <input type="checkbox" bind:checked={propertyIsRented} class="w-5 h-5 rounded border-slate-300 text-orange-600 focus:ring-orange-500 cursor-pointer" />
                                <span class="text-sm font-bold text-slate-700 group-hover:text-orange-700 transition-colors">{$t('finance.leaseAndRent.propertyIsRented')}</span>
                            </label>
                        </div>
                        <!-- Save Button -->
                        <div class="flex justify-end mt-6">
                            <button
                                class="inline-flex items-center gap-2 px-8 py-3 rounded-xl bg-violet-600 text-white text-sm font-bold hover:bg-violet-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                                on:click={saveProperty}
                                disabled={savingProperty || !propertyNameEn.trim() || !propertyNameAr.trim()}
                            >
                                {#if savingProperty}
                                    ⏳ {$t('common.saving')}
                                {:else}
                                    💾 {$t('common.save')}
                                {/if}
                            </button>
                        </div>
                    </div>
                {:else if managerActiveForm === 'propertySpace' && formMode}
                    <!-- Add Property Space Form -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8">
                        <h3 class="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2">
                            <span class="text-2xl">📐</span> {formMode === 'edit' ? $t('finance.leaseAndRent.editPropertySpace') : $t('finance.leaseAndRent.addPropertySpace')}
                        </h3>
                        {#if formMode === 'edit'}
                            <div class="mb-6">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.selectRecordToEdit')}</label>
                                <select
                                    on:change={(e) => populateSpaceForEdit(e.currentTarget.value)}
                                    class="w-full px-4 py-2.5 bg-white border border-amber-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all"
                                >
                                    <option value="">{$t('finance.leaseAndRent.selectRecordToEdit')}</option>
                                    {#each editPropertySpaces as sp}
                                        {@const prop = propertiesList.find(p => p.id === sp.property_id)}
                                        <option value={sp.id} selected={editingSpaceId === sp.id}>{$locale === 'ar' ? (prop?.name_ar || '') : (prop?.name_en || '')} - {sp.space_number}</option>
                                    {/each}
                                </select>
                            </div>
                        {/if}
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
                            <!-- Choose Property Dropdown -->
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.chooseProperty')}</label>
                                <select
                                    bind:value={selectedPropertyId}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
                                >
                                    <option value="">{$t('finance.leaseAndRent.choosePropertyPlaceholder')}</option>
                                    {#each propertiesList as property}
                                        <option value={property.id}>{$locale === 'ar' ? property.name_ar : property.name_en}</option>
                                    {/each}
                                </select>
                            </div>
                            <!-- Space Number -->
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.spaceNumber')}</label>
                                <input
                                    type="text"
                                    bind:value={spaceNumber}
                                    placeholder={$t('finance.leaseAndRent.spaceNumberPlaceholder')}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-transparent transition-all"
                                />
                            </div>
                        </div>
                        <!-- Save Button -->
                        <div class="flex justify-end mt-6">
                            <button
                                class="inline-flex items-center gap-2 px-8 py-3 rounded-xl bg-rose-600 text-white text-sm font-bold hover:bg-rose-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                                on:click={savePropertySpace}
                                disabled={savingSpace || !selectedPropertyId || !spaceNumber.trim()}
                            >
                                {#if savingSpace}
                                    ⏳ {$t('common.saving')}
                                {:else}
                                    💾 {$t('common.save')}
                                {/if}
                            </button>
                        </div>
                    </div>

                    <!-- Existing Spaces for Selected Property -->
                    {#if selectedPropertyId && propertySpaces.length > 0}
                        <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6 mt-6">
                            <h4 class="text-sm font-bold text-slate-700 mb-4 flex items-center gap-2">
                                <span class="text-lg">📋</span> {$t('finance.leaseAndRent.existingSpaces')}
                            </h4>
                            <div class="flex flex-wrap gap-3">
                                {#each propertySpaces as space}
                                    <button
                                        type="button"
                                        on:click={() => { formMode = 'edit'; editingSpaceId = space.id; spaceNumber = space.space_number; }}
                                        class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl border transition-all duration-150 hover:scale-105 hover:shadow-md
                                            {editingSpaceId === space.id ? 'bg-rose-600 border-rose-600 text-white shadow-md' : 'bg-rose-50 border-rose-200 text-rose-600 hover:bg-rose-100'}"
                                        title={$t('finance.leaseAndRent.editPropertySpace')}
                                    >
                                        <span class="font-bold text-sm">{space.space_number}</span>
                                        <span class="text-[10px] opacity-70">✏️</span>
                                    </button>
                                {/each}
                            </div>
                        </div>
                    {:else if selectedPropertyId && propertySpaces.length === 0}
                        <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6 mt-6 text-center">
                            <p class="text-slate-500 text-sm">{$t('finance.leaseAndRent.noSpacesYet')}</p>
                        </div>
                    {/if}
                {:else if managerActiveForm === 'lease' && formMode}
                    <!-- Lease Party Form (compact) -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
                        <h3 class="text-base font-bold text-slate-800 mb-4 flex items-center gap-2">
                            <span class="text-xl">📋</span> {formMode === 'edit' ? $t('finance.leaseAndRent.editLease') : $t('finance.leaseAndRent.addNewLease')}
                        </h3>
                        {#if formMode === 'edit'}
                            <div class="mb-4">
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectRecordToEdit')}</label>
                                <select on:change={(e) => populateLeaseForEdit(e.currentTarget.value)} class="w-full px-3 py-2 bg-white border border-amber-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent">
                                    <option value="">{$t('finance.leaseAndRent.selectRecordToEdit')}</option>
                                    {#each editLeaseParties as lp}
                                        <option value={lp.id} selected={editingLeasePartyId === lp.id}>{$locale === 'ar' ? lp.party_name_ar : lp.party_name_en}</option>
                                    {/each}
                                </select>
                            </div>
                        {/if}

                        <!-- Row 1: Property + Space + Shop + Contact + Email + Open Contract -->
                        <div class="grid grid-cols-2 md:grid-cols-6 gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectPropertyLeased')}</label>
                                <select bind:value={leasePropertyId} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent">
                                    <option value="">{$t('finance.leaseAndRent.choosePropertyPlaceholder')}</option>
                                    {#each leaseProperties as property}
                                        <option value={property.id}>{$locale === 'ar' ? property.name_ar : property.name_en}</option>
                                    {/each}
                                </select>
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectPropertySpace')}</label>
                                <select bind:value={leasePropertySpaceId} disabled={!leasePropertyId} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent disabled:opacity-50">
                                    <option value="">{$t('finance.leaseAndRent.choosePropertyPlaceholder')}</option>
                                    {#each leaseSpaces as space}
                                        <option value={space.id}>{space.space_number}</option>
                                    {/each}
                                </select>
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.shopName')}</label>
                                <input type="text" bind:value={leaseShopName} placeholder={$t('finance.leaseAndRent.shopNamePlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.contactNumber')}</label>
                                <input type="text" bind:value={leaseContactNumber} placeholder={$t('finance.leaseAndRent.contactNumberPlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.email')}</label>
                                <input type="email" bind:value={leaseEmail} placeholder={$t('finance.leaseAndRent.emailPlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            <div class="flex items-end">
                                <label class="flex items-center gap-2 cursor-pointer group pb-2">
                                    <input type="checkbox" bind:checked={leaseOpenContract} class="w-5 h-5 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer" />
                                    <span class="text-sm font-bold text-slate-700 group-hover:text-emerald-700 transition-colors">{$t('finance.leaseAndRent.openContract')}</span>
                                </label>
                            </div>
                        </div>

                        <!-- Row 2: Party Names + Contract Dates -->
                        <div class="grid grid-cols-2 {leaseOpenContract ? 'md:grid-cols-3' : 'md:grid-cols-4'} gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.leasePartyNameEn')}</label>
                                <input type="text" bind:value={leasePartyNameEn} placeholder={$t('finance.leaseAndRent.leasePartyNameEnPlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.leasePartyNameAr')}</label>
                                <input type="text" bind:value={leasePartyNameAr} placeholder={$t('finance.leaseAndRent.leasePartyNameArPlaceholder')} dir="rtl" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.contractStartDate')}</label>
                                <input type="date" bind:value={leaseContractStart} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            {#if !leaseOpenContract}
                                <div>
                                    <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.contractEndDate')}</label>
                                    <input type="date" bind:value={leaseContractEnd} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                                </div>
                            {/if}
                        </div>

                        <!-- Row 3: All 4 amounts -->
                        <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.leaseAmountContract')}</label>
                                <input type="number" step="0.01" bind:value={leaseAmountContract} placeholder="0.00" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.leaseAmountOutsideContract')}</label>
                                <input type="number" step="0.01" bind:value={leaseAmountOutside} placeholder="0.00" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.utilityCharges')}</label>
                                <input type="number" step="0.01" bind:value={leaseUtilityCharges} placeholder="0.00" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.securityCharges')}</label>
                                <input type="number" step="0.01" bind:value={leaseSecurityCharges} placeholder="0.00" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                            </div>
                        </div>

                        <!-- Row 4: Payment Mode + Collection Incharge + Other Charges -->
                        <div class="grid grid-cols-2 md:grid-cols-3 gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.paymentMode')}</label>
                                <select bind:value={leasePaymentMode} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent">
                                    <option value="cash">{$t('finance.leaseAndRent.cash')}</option>
                                    <option value="bank">{$t('finance.leaseAndRent.bank')}</option>
                                </select>
                            </div>
                            <div class="relative lease-employee-search-container">
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.collectionIncharge')}</label>
                                {#if leaseCollectionInchargeId && !showLeaseEmployeeDropdown}
                                    <div class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm flex items-center justify-between">
                                        <span class="font-semibold text-slate-800 truncate">{selectedLeaseEmployeeName}</span>
                                        <div class="flex items-center gap-1">
                                            <button class="text-slate-400 hover:text-emerald-600 transition-colors" on:click={() => { showLeaseEmployeeDropdown = true; leaseEmployeeSearch = ''; }}>✏️</button>
                                            <button class="text-slate-400 hover:text-red-500 transition-colors" on:click={clearLeaseEmployee}>✕</button>
                                        </div>
                                    </div>
                                {:else}
                                    <input type="text" bind:value={leaseEmployeeSearch} on:focus={() => { showLeaseEmployeeDropdown = true; }} placeholder={$t('finance.leaseAndRent.selectCollectionIncharge')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" />
                                    {#if showLeaseEmployeeDropdown}
                                        <div class="absolute z-50 mt-1 w-full max-h-40 overflow-y-auto bg-white border border-slate-200 rounded-xl shadow-xl">
                                            {#each filteredLeaseEmployees as emp}
                                                <button class="w-full text-left px-3 py-2 text-sm hover:bg-emerald-50 transition-colors first:rounded-t-xl last:rounded-b-xl" on:click={() => selectLeaseEmployee(emp)}>
                                                    <span class="font-semibold text-slate-800">{$locale === 'ar' ? (emp.name_ar || emp.name_en) : emp.name_en}</span>
                                                    {#if emp.name_ar && emp.name_en}<span class="text-slate-400 text-xs ml-1">({$locale === 'ar' ? emp.name_en : emp.name_ar})</span>{/if}
                                                </button>
                                            {:else}
                                                <div class="px-3 py-2 text-sm text-slate-400 text-center">No results</div>
                                            {/each}
                                        </div>
                                    {/if}
                                {/if}
                            </div>
                            <div class="flex items-end gap-2">
                                <button class="inline-flex items-center gap-1 px-4 py-2 rounded-lg bg-amber-500 text-white text-xs font-bold hover:bg-amber-600 transition-all" on:click={() => { showLeaseOtherChargesPopup = true; }}>+ {$t('finance.leaseAndRent.addOtherCharges')}</button>
                                {#if leaseOtherCharges.length > 0}
                                    <div class="flex flex-wrap gap-1">
                                        {#each leaseOtherCharges as charge, idx}
                                            <div class="inline-flex items-center gap-1 px-2 py-1 bg-amber-50 border border-amber-200 rounded-lg text-xs">
                                                <span class="font-semibold text-amber-800">{charge.name}</span>
                                                <span class="text-amber-600">{charge.amount}</span>
                                                <button class="text-red-400 hover:text-red-600 font-bold" on:click={() => removeLeaseOtherCharge(idx)}>✕</button>
                                            </div>
                                        {/each}
                                    </div>
                                {/if}
                            </div>
                        </div>

                        <!-- Row 5: Payment Period + Schedule + Date -->
                        <div class="grid grid-cols-2 md:grid-cols-3 gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.paymentPeriod')}</label>
                                <select bind:value={leasePaymentPeriod} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent">
                                    <option value="daily">{$t('finance.leaseAndRent.daily')}</option>
                                    <option value="monthly">{$t('finance.leaseAndRent.monthly')}</option>
                                    <option value="every_3_months">{$t('finance.leaseAndRent.every3Months')}</option>
                                    <option value="every_6_months">{$t('finance.leaseAndRent.every6Months')}</option>
                                    <option value="yearly">{$t('finance.leaseAndRent.yearly')}</option>
                                </select>
                            </div>
                            {#if leasePeriodHasSubFields}
                                <div>
                                    <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectPaymentSchedule')}</label>
                                    <div class="flex gap-3 pt-1">
                                        <label class="flex items-center gap-1 cursor-pointer"><input type="radio" bind:group={leasePaymentEndOfMonth} value={false} class="text-emerald-600 focus:ring-emerald-500" /><span class="text-xs font-semibold text-slate-700">{$t('finance.leaseAndRent.specificDate')}</span></label>
                                        <label class="flex items-center gap-1 cursor-pointer"><input type="radio" bind:group={leasePaymentEndOfMonth} value={true} class="text-emerald-600 focus:ring-emerald-500" /><span class="text-xs font-semibold text-slate-700">{$t('finance.leaseAndRent.endOfMonth')}</span></label>
                                    </div>
                                </div>
                                {#if !leasePaymentEndOfMonth}
                                    <div>
                                        <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectDate')}</label>
                                        <select bind:value={leasePaymentSpecificDate} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent">
                                            <option value="">{$t('finance.leaseAndRent.selectDate')}</option>
                                            {#each Array.from({ length: 28 }, (_, i) => i + 1) as day}<option value={day}>{day}</option>{/each}
                                        </select>
                                    </div>
                                {/if}
                            {/if}
                        </div>

                        <!-- Save Button -->
                        <div class="flex justify-end mt-3">
                            <button class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-emerald-600 text-white text-sm font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none" on:click={saveLeaseParty} disabled={savingLeaseParty || !leasePropertyId || !leasePartyNameEn.trim() || !leasePartyNameAr.trim()}>
                                {#if savingLeaseParty}⏳ {$t('common.saving')}{:else}💾 {$t('common.save')}{/if}
                            </button>
                        </div>
                    </div>
                {:else if managerActiveForm === 'rent' && formMode}
                    <!-- Rent Party Form (compact) -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-6">
                        <h3 class="text-base font-bold text-slate-800 mb-4 flex items-center gap-2">
                            <span class="text-xl">🏠</span> {formMode === 'edit' ? $t('finance.leaseAndRent.editRentParty') : $t('finance.leaseAndRent.addNewRentParty')}
                        </h3>
                        {#if formMode === 'edit'}
                            <div class="mb-4">
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectRecordToEdit')}</label>
                                <select on:change={(e) => populateRentForEdit(e.currentTarget.value)} class="w-full px-3 py-2 bg-white border border-amber-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent">
                                    <option value="">{$t('finance.leaseAndRent.selectRecordToEdit')}</option>
                                    {#each editRentParties as rp}
                                        <option value={rp.id} selected={editingRentPartyId === rp.id}>{$locale === 'ar' ? rp.party_name_ar : rp.party_name_en}</option>
                                    {/each}
                                </select>
                            </div>
                        {/if}

                        <!-- Row 1: Property + Space + Shop + Contact + Email + Open Contract -->
                        <div class="grid grid-cols-2 md:grid-cols-6 gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectProperty')}</label>
                                <select bind:value={rentPropertyId} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent">
                                    <option value="">{$t('finance.leaseAndRent.choosePropertyPlaceholder')}</option>
                                    {#each rentProperties as property}
                                        <option value={property.id}>{$locale === 'ar' ? property.name_ar : property.name_en}</option>
                                    {/each}
                                </select>
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectPropertySpace')}</label>
                                <select bind:value={rentPropertySpaceId} disabled={!rentPropertyId} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent disabled:opacity-50">
                                    <option value="">{$t('finance.leaseAndRent.choosePropertyPlaceholder')}</option>
                                    {#each rentSpaces as space}
                                        <option value={space.id}>{space.space_number}</option>
                                    {/each}
                                </select>
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.shopName')}</label>
                                <input type="text" bind:value={rentShopName} placeholder={$t('finance.leaseAndRent.shopNamePlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.contactNumber')}</label>
                                <input type="text" bind:value={rentContactNumber} placeholder={$t('finance.leaseAndRent.contactNumberPlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.email')}</label>
                                <input type="email" bind:value={rentEmail} placeholder={$t('finance.leaseAndRent.emailPlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            <div class="flex items-end">
                                <label class="flex items-center gap-2 cursor-pointer group pb-2">
                                    <input type="checkbox" bind:checked={rentOpenContract} class="w-5 h-5 rounded border-slate-300 text-orange-600 focus:ring-orange-500 cursor-pointer" />
                                    <span class="text-sm font-bold text-slate-700 group-hover:text-orange-700 transition-colors">{$t('finance.leaseAndRent.openContract')}</span>
                                </label>
                            </div>
                        </div>

                        <!-- Row 2: Party Names + Contract Dates -->
                        <div class="grid grid-cols-2 {rentOpenContract ? 'md:grid-cols-3' : 'md:grid-cols-4'} gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.rentPartyNameEn')}</label>
                                <input type="text" bind:value={rentPartyNameEn} placeholder={$t('finance.leaseAndRent.rentPartyNameEnPlaceholder')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.rentPartyNameAr')}</label>
                                <input type="text" bind:value={rentPartyNameAr} placeholder={$t('finance.leaseAndRent.rentPartyNameArPlaceholder')} dir="rtl" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.contractStartDate')}</label>
                                <input type="date" bind:value={rentContractStart} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            {#if !rentOpenContract}
                                <div>
                                    <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.contractEndDate')}</label>
                                    <input type="date" bind:value={rentContractEnd} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                                </div>
                            {/if}
                        </div>

                        <!-- Row 3: All 4 amounts -->
                        <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.rentAmountContract')}</label>
                                <input type="number" step="0.01" bind:value={rentAmountContract} placeholder="0.00" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.rentAmountOutsideContract')}</label>
                                <input type="number" step="0.01" bind:value={rentAmountOutside} placeholder="0.00" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.utilityCharges')}</label>
                                <input type="number" step="0.01" bind:value={rentUtilityCharges} placeholder="0.00" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.securityCharges')}</label>
                                <input type="number" step="0.01" bind:value={rentSecurityCharges} placeholder="0.00" class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                            </div>
                        </div>

                        <!-- Row 4: Payment Mode + Collection Incharge + Other Charges -->
                        <div class="grid grid-cols-2 md:grid-cols-3 gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.paymentMode')}</label>
                                <select bind:value={rentPaymentMode} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent">
                                    <option value="cash">{$t('finance.leaseAndRent.cash')}</option>
                                    <option value="bank">{$t('finance.leaseAndRent.bank')}</option>
                                </select>
                            </div>
                            <div class="relative employee-search-container">
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.collectionIncharge')}</label>
                                {#if rentCollectionInchargeId && !showEmployeeDropdown}
                                    <div class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm flex items-center justify-between">
                                        <span class="font-semibold text-slate-800 truncate">{selectedEmployeeName}</span>
                                        <div class="flex items-center gap-1">
                                            <button class="text-slate-400 hover:text-orange-600 transition-colors" on:click={() => { showEmployeeDropdown = true; employeeSearch = ''; }}>✏️</button>
                                            <button class="text-slate-400 hover:text-red-500 transition-colors" on:click={clearEmployee}>✕</button>
                                        </div>
                                    </div>
                                {:else}
                                    <input type="text" bind:value={employeeSearch} on:focus={() => { showEmployeeDropdown = true; }} placeholder={$t('finance.leaseAndRent.selectCollectionIncharge')} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                                    {#if showEmployeeDropdown}
                                        <div class="absolute z-50 mt-1 w-full max-h-40 overflow-y-auto bg-white border border-slate-200 rounded-xl shadow-xl">
                                            {#each filteredEmployees as emp}
                                                <button class="w-full text-left px-3 py-2 text-sm hover:bg-orange-50 transition-colors first:rounded-t-xl last:rounded-b-xl" on:click={() => selectEmployee(emp)}>
                                                    <span class="font-semibold text-slate-800">{$locale === 'ar' ? (emp.name_ar || emp.name_en) : emp.name_en}</span>
                                                    {#if emp.name_ar && emp.name_en}<span class="text-slate-400 text-xs ml-1">({$locale === 'ar' ? emp.name_en : emp.name_ar})</span>{/if}
                                                </button>
                                            {:else}
                                                <div class="px-3 py-2 text-sm text-slate-400 text-center">No results</div>
                                            {/each}
                                        </div>
                                    {/if}
                                {/if}
                            </div>
                            <div class="flex items-end gap-2">
                                <button class="inline-flex items-center gap-1 px-4 py-2 rounded-lg bg-amber-500 text-white text-xs font-bold hover:bg-amber-600 transition-all" on:click={() => { showOtherChargesPopup = true; }}>+ {$t('finance.leaseAndRent.addOtherCharges')}</button>
                                {#if rentOtherCharges.length > 0}
                                    <div class="flex flex-wrap gap-1">
                                        {#each rentOtherCharges as charge, idx}
                                            <div class="inline-flex items-center gap-1 px-2 py-1 bg-amber-50 border border-amber-200 rounded-lg text-xs">
                                                <span class="font-semibold text-amber-800">{charge.name}</span>
                                                <span class="text-amber-600">{charge.amount}</span>
                                                <button class="text-red-400 hover:text-red-600 font-bold" on:click={() => removeOtherCharge(idx)}>✕</button>
                                            </div>
                                        {/each}
                                    </div>
                                {/if}
                            </div>
                        </div>

                        <!-- Row 5: Payment Period + Schedule + Date -->
                        <div class="grid grid-cols-2 md:grid-cols-3 gap-3 mb-3">
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.paymentPeriod')}</label>
                                <select bind:value={rentPaymentPeriod} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent">
                                    <option value="daily">{$t('finance.leaseAndRent.daily')}</option>
                                    <option value="monthly">{$t('finance.leaseAndRent.monthly')}</option>
                                    <option value="every_3_months">{$t('finance.leaseAndRent.every3Months')}</option>
                                    <option value="every_6_months">{$t('finance.leaseAndRent.every6Months')}</option>
                                    <option value="yearly">{$t('finance.leaseAndRent.yearly')}</option>
                                </select>
                            </div>
                            {#if rentPeriodHasSubFields}
                                <div>
                                    <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectPaymentSchedule')}</label>
                                    <div class="flex gap-3 pt-1">
                                        <label class="flex items-center gap-1 cursor-pointer"><input type="radio" bind:group={rentPaymentEndOfMonth} value={false} class="text-orange-600 focus:ring-orange-500" /><span class="text-xs font-semibold text-slate-700">{$t('finance.leaseAndRent.specificDate')}</span></label>
                                        <label class="flex items-center gap-1 cursor-pointer"><input type="radio" bind:group={rentPaymentEndOfMonth} value={true} class="text-orange-600 focus:ring-orange-500" /><span class="text-xs font-semibold text-slate-700">{$t('finance.leaseAndRent.endOfMonth')}</span></label>
                                    </div>
                                </div>
                                {#if !rentPaymentEndOfMonth}
                                    <div>
                                        <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.selectDate')}</label>
                                        <select bind:value={rentPaymentSpecificDate} class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent">
                                            <option value="">{$t('finance.leaseAndRent.selectDate')}</option>
                                            {#each Array.from({ length: 28 }, (_, i) => i + 1) as day}<option value={day}>{day}</option>{/each}
                                        </select>
                                    </div>
                                {/if}
                            {/if}
                        </div>

                        <!-- Save Button -->
                        <div class="flex justify-end mt-3">
                            <button class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-orange-600 text-white text-sm font-bold hover:bg-orange-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none" on:click={saveRentParty} disabled={savingRentParty || !rentPropertyId || !rentPartyNameEn.trim() || !rentPartyNameAr.trim()}>
                                {#if savingRentParty}⏳ {$t('common.saving')}{:else}💾 {$t('common.save')}{/if}
                            </button>
                        </div>
                    </div>
                {:else if !managerActiveForm}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">🛠️</div>
                        <p class="text-slate-600 font-semibold">{$t('finance.leaseAndRent.selectManagerAction')}</p>
                    </div>
                {/if}

            {:else if activeTab === 'payments'}
                <!-- Payments Action Buttons + Party Dropdown -->
                <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg px-4 py-2.5 mb-3 overflow-visible relative z-30">
                    <div class="flex items-center gap-3 flex-wrap">
                        <div class="flex gap-2 flex-wrap">
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105
                                {paymentType === 'lease' ? 'bg-emerald-700 shadow-md shadow-emerald-300 ring-2 ring-emerald-400 scale-105' : 'bg-emerald-600 shadow-sm shadow-emerald-200'}"
                                on:click={() => { paymentType = 'lease'; clearPaymentParty(); }}
                            >
                                {$t('finance.leaseAndRent.leasePayments')}
                            </button>
                            <button
                                class="flex items-center gap-1.5 px-4 py-2 rounded-xl text-white font-bold text-xs hover:shadow-lg transition-all duration-200 transform hover:scale-105
                                {paymentType === 'rent' ? 'bg-orange-700 shadow-md shadow-orange-300 ring-2 ring-orange-400 scale-105' : 'bg-orange-600 shadow-sm shadow-orange-200'}"
                                on:click={() => { paymentType = 'rent'; clearPaymentParty(); }}
                            >
                                {$t('finance.leaseAndRent.rentPayments')}
                            </button>
                        </div>
                        {#if paymentType}
                            <div class="flex-1 min-w-[250px] max-w-md relative payment-party-container">
                                {#if selectedPaymentParty}
                                    <div class="flex items-center gap-2 px-3 py-1.5 {paymentType === 'lease' ? 'bg-emerald-50 border-emerald-200' : 'bg-orange-50 border-orange-200'} border rounded-xl">
                                        <span class="{paymentType === 'lease' ? 'text-emerald-800' : 'text-orange-800'} font-bold text-xs flex-1 truncate">{selectedPaymentParty.party_name_en} — <span dir="rtl">{selectedPaymentParty.party_name_ar}</span></span>
                                        <button class="text-red-400 hover:text-red-600 text-sm font-bold" on:click={clearPaymentParty}>✕</button>
                                    </div>
                                {:else}
                                    <input
                                        type="text"
                                        bind:value={paymentPartySearch}
                                        on:focus={() => { showPaymentPartyDropdown = true; }}
                                        placeholder={$t('finance.leaseAndRent.searchPartyPlaceholder')}
                                        class="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 {paymentType === 'lease' ? 'focus:ring-emerald-500' : 'focus:ring-orange-500'} focus:border-transparent transition-all"
                                    />
                                    {#if showPaymentPartyDropdown}
                                        <div class="absolute z-50 top-full mt-1 w-full max-h-52 overflow-y-auto bg-white border border-slate-200 rounded-xl shadow-2xl">
                                            {#each filteredPaymentParties as party}
                                                <button class="w-full text-left px-4 py-2 {paymentType === 'lease' ? 'hover:bg-emerald-50' : 'hover:bg-orange-50'} transition-colors text-xs border-b border-slate-50 last:border-0" on:click={() => selectPaymentParty(party)}>
                                                    <div class="font-semibold text-slate-800">{party.party_name_en}</div>
                                                    <div class="{paymentType === 'lease' ? 'text-emerald-600' : 'text-orange-600'} text-[10px]" dir="rtl">{party.party_name_ar}</div>
                                                </button>
                                            {:else}
                                                <div class="px-4 py-2 text-xs text-slate-400 text-center">{$t('finance.leaseAndRent.noResults')}</div>
                                            {/each}
                                        </div>
                                    {/if}
                                {/if}
                            </div>
                        {/if}
                    </div>
                </div>

                <!-- Payment Schedule Table -->
                {#if selectedPaymentParty && paymentSchedule.length > 0}
                    {#if selectedPaymentParty.is_open_contract}
                        <div class="bg-purple-50 border border-purple-200 rounded-xl px-4 py-1.5 mb-2 text-xs text-purple-700 font-semibold">
                            ♾️ {$t('finance.leaseAndRent.openContractNote')}
                        </div>
                    {/if}
                    <div class="bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex flex-col">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse text-xs [&_th]:border-x [&_th]:border-indigo-500/30 [&_td]:border-x [&_td]:border-slate-100">
                                <thead class="sticky top-0 bg-indigo-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">#</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.fromDate')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.toDate')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.baseAmount')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.outsideContract')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.utility')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.security')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.other')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400 bg-indigo-700">{$t('finance.leaseAndRent.total')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.paid')}</th>
                                        <th class="px-2 py-2 {$locale === 'ar' ? 'text-right' : 'text-left'} font-black uppercase tracking-wider border-b-2 border-indigo-400">{$t('finance.leaseAndRent.status')}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each paymentSchedule as row, index}
                                        <tr class="{isFullyPaid(row) ? 'bg-green-50/60' : isPartiallyPaid(row) ? 'bg-yellow-50/60' : row.hasChange ? 'bg-amber-50/60' : (index % 2 === 0 ? 'bg-slate-50/30' : 'bg-white/30')} hover:bg-indigo-50/40 transition-colors duration-150">
                                            <td class="px-2 py-1.5 text-slate-500 font-semibold">{row.num}</td>
                                            <td class="px-2 py-1.5 text-slate-700 font-semibold whitespace-nowrap">{fmtDate(row.from)}</td>
                                            <td class="px-2 py-1.5 text-slate-700 font-semibold whitespace-nowrap">{fmtDate(row.to)}</td>
                                            {#each ['contract', 'outside', 'utility', 'security', 'other'] as col}
                                                {@const due = getColumnAmount(row, col)}
                                                {@const paid = getColumnPaid(row, col)}
                                                {@const remaining = due - paid}
                                                {@const full = paid >= due}
                                                <td class="px-1.5 py-1">
                                                    <div class="flex items-center gap-1 cursor-pointer group" title="{full ? 'Fully paid' : remaining > 0 ? 'Click to pay' : ''}">
                                                        <button type="button" disabled={due === 0} on:click={() => { openPaymentPopup(row, col); }} class="w-5 h-5 flex items-center justify-center rounded-full text-[11px] font-bold transition-all {full ? 'bg-green-500 text-white shadow-sm' : paid > 0 ? 'bg-yellow-400 text-white shadow-sm hover:bg-yellow-500' : due === 0 ? 'bg-slate-100 text-slate-300' : 'bg-slate-200 text-slate-400 hover:bg-green-500 hover:text-white hover:shadow'} disabled:cursor-default">
                                                            ✓
                                                        </button>
                                                        <span class="flex flex-col leading-tight">
                                                            {#if full}
                                                                <span class="font-semibold text-[10px] text-green-700 line-through">{due.toLocaleString()}</span>
                                                                {#if getLastPaidDate(row, col)}<span class="text-[8px] text-green-600">{getLastPaidDate(row, col)}</span>{/if}
                                                            {:else if paid > 0}
                                                                <span class="font-semibold text-[10px] text-yellow-700">{remaining.toLocaleString()}</span>
                                                                <span class="text-[8px] text-green-600">({paid.toLocaleString()} {$t('finance.leaseAndRent.paid')} {getLastPaidDate(row, col)})</span>
                                                            {:else}
                                                                <span class="font-semibold text-[10px] {row.hasChange && (col === 'contract' || col === 'outside') ? 'text-amber-700' : 'text-slate-800'}">{due.toLocaleString()}</span>
                                                            {/if}
                                                        </span>
                                                    </div>
                                                </td>
                                            {/each}
                                            <td class="px-2 py-1.5 font-bold text-indigo-800 bg-indigo-50/50 whitespace-nowrap">{row.total.toLocaleString()}</td>
                                            <td class="px-2 py-1.5 font-bold {isFullyPaid(row) ? 'text-green-700' : isPartiallyPaid(row) ? 'text-yellow-700' : 'text-slate-400'} whitespace-nowrap">{getPaidAmount(row).toLocaleString()}</td>
                                            <td class="px-2 py-1.5">
                                                {#if isFullyPaid(row)}
                                                    <span class="inline-flex px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-green-100 text-green-700">✅ {$t('finance.leaseAndRent.fullyPaid')}</span>
                                                {:else if isPartiallyPaid(row)}
                                                    <span class="inline-flex px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-yellow-100 text-yellow-700">⚡ {$t('finance.leaseAndRent.partiallyPaid')}</span>
                                                {:else if row.hasChange}
                                                    <span class="inline-flex px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-amber-100 text-amber-700" title={row.appliedChanges.join(', ')}>⚠️ {$t('finance.leaseAndRent.changed')}</span>
                                                {:else}
                                                    <span class="inline-flex px-1.5 py-0.5 rounded-full text-[9px] font-bold bg-slate-100 text-slate-500">{$t('finance.leaseAndRent.unpaid')}</span>
                                                {/if}
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                        <!-- Sticky Footer with Totals -->
                        <div class="border-t-2 border-indigo-300 bg-white/80 backdrop-blur-sm">
                            <table class="w-full border-collapse text-xs [&_td]:border-x [&_td]:border-slate-100">
                                <tfoot>
                                    <tr class="bg-indigo-100/80 font-bold">
                                        <td class="px-2 py-2 w-[60px]" colspan="1"></td>
                                        <td class="px-2 py-2" colspan="2">{$t('finance.leaseAndRent.total')}</td>
                                        <td class="px-2 py-2 text-indigo-800">{paymentSchedule.reduce((s, r) => s + r.amtContract, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-indigo-800">{paymentSchedule.reduce((s, r) => s + r.amtOutside, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-indigo-800">{paymentSchedule.reduce((s, r) => s + r.amtUtility, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-indigo-800">{paymentSchedule.reduce((s, r) => s + r.amtSecurity, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-indigo-800">{paymentSchedule.reduce((s, r) => s + r.amtOther, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-indigo-900 bg-indigo-200/50 font-black">{paymentSchedule.reduce((s, r) => s + r.total, 0).toLocaleString()}</td>
                                        <td class="px-2 py-2"></td>
                                        <td class="px-2 py-2"></td>
                                    </tr>
                                    <tr class="bg-green-100/80 font-bold">
                                        <td class="px-2 py-2" colspan="1"></td>
                                        <td class="px-2 py-2 text-green-800" colspan="2">✅ {$t('finance.leaseAndRent.paidTotal')}</td>
                                        <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidContract) || 0), 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidOutside) || 0), 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidUtility) || 0), 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidSecurity) || 0), 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-green-800">{paymentSchedule.reduce((s, r) => s + (Number(r.paidOther) || 0), 0).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-green-900 bg-green-200/50 font-black">{paymentSchedule.reduce((s, r) => s + getPaidAmount(r), 0).toLocaleString()}</td>
                                        <td class="px-2 py-2"></td>
                                        <td class="px-2 py-2"></td>
                                    </tr>
                                    <tr class="bg-red-100/80 font-bold">
                                        <td class="px-2 py-2" colspan="1"></td>
                                        <td class="px-2 py-2 text-red-800" colspan="2">❌ {$t('finance.leaseAndRent.unpaidTotal')}</td>
                                        <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtContract, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidContract) || 0), 0)).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtOutside, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidOutside) || 0), 0)).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtUtility, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidUtility) || 0), 0)).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtSecurity, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidSecurity) || 0), 0)).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-red-800">{(paymentSchedule.reduce((s, r) => s + r.amtOther, 0) - paymentSchedule.reduce((s, r) => s + (Number(r.paidOther) || 0), 0)).toLocaleString()}</td>
                                        <td class="px-2 py-2 text-red-900 bg-red-200/50 font-black">{(paymentSchedule.reduce((s, r) => s + r.total, 0) - paymentSchedule.reduce((s, r) => s + getPaidAmount(r), 0)).toLocaleString()}</td>
                                        <td class="px-2 py-2"></td>
                                        <td class="px-2 py-2"></td>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                        <div class="px-4 py-2 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold flex items-center gap-3">
                            <span>{$t('finance.leaseAndRent.showingRecords', { count: paymentSchedule.length })}</span>
                            {#if paymentSaving}
                                <span class="text-indigo-600 animate-pulse">💾 {$t('finance.leaseAndRent.saving')}</span>
                            {/if}
                        </div>
                    </div>
                {:else if selectedPaymentParty && paymentSchedule.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📅</div>
                        <p class="text-slate-600 font-semibold">{$t('finance.leaseAndRent.noSchedule')}</p>
                    </div>
                {:else}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">💰</div>
                        <p class="text-slate-600 font-semibold">{$t('finance.leaseAndRent.noSchedule')}</p>
                    </div>
                {/if}
            {/if}
        </div>
    </div>
</div>

<!-- Other Charges Popup -->
{#if showOtherChargesPopup}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center" on:click|self={() => { showOtherChargesPopup = false; }} on:keydown={(e) => { if (e.key === 'Escape') showOtherChargesPopup = false; }}>
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-[400px] max-w-[90vw]">
            <h4 class="text-lg font-bold text-slate-800 mb-4 flex items-center gap-2">
                <span class="text-xl">💰</span> {$t('finance.leaseAndRent.addOtherCharges')}
            </h4>
            <div class="space-y-4">
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.chargeName')}</label>
                    <input type="text" bind:value={newChargeName} placeholder={$t('finance.leaseAndRent.chargeNamePlaceholder')} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.chargeAmount')}</label>
                    <input type="number" step="0.01" bind:value={newChargeAmount} placeholder={$t('finance.leaseAndRent.chargeAmountPlaceholder')} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
                </div>
            </div>
            <div class="flex justify-end gap-3 mt-6">
                <button class="px-5 py-2.5 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-100 transition-all" on:click={() => { showOtherChargesPopup = false; }}>
                    {$t('common.cancel')}
                </button>
                <button
                    class="px-5 py-2.5 rounded-xl bg-amber-500 text-white text-sm font-bold hover:bg-amber-600 transition-all disabled:opacity-50"
                    on:click={addOtherCharge}
                    disabled={!newChargeName.trim() || !newChargeAmount}
                >
                    {$t('finance.leaseAndRent.addCharge')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Lease Other Charges Popup -->
{#if showLeaseOtherChargesPopup}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center" on:click|self={() => { showLeaseOtherChargesPopup = false; }} on:keydown={(e) => { if (e.key === 'Escape') showLeaseOtherChargesPopup = false; }}>
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-[400px] max-w-[90vw]">
            <h4 class="text-lg font-bold text-slate-800 mb-4 flex items-center gap-2">
                <span class="text-xl">💰</span> {$t('finance.leaseAndRent.addOtherCharges')}
            </h4>
            <div class="space-y-4">
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.chargeName')}</label>
                    <input type="text" bind:value={newLeaseChargeName} placeholder={$t('finance.leaseAndRent.chargeNamePlaceholder')} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('finance.leaseAndRent.chargeAmount')}</label>
                    <input type="number" step="0.01" bind:value={newLeaseChargeAmount} placeholder={$t('finance.leaseAndRent.chargeAmountPlaceholder')} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent transition-all" />
                </div>
            </div>
            <div class="flex justify-end gap-3 mt-6">
                <button class="px-5 py-2.5 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-100 transition-all" on:click={() => { showLeaseOtherChargesPopup = false; }}>
                    {$t('common.cancel')}
                </button>
                <button
                    class="px-5 py-2.5 rounded-xl bg-amber-500 text-white text-sm font-bold hover:bg-amber-600 transition-all disabled:opacity-50"
                    on:click={addLeaseOtherCharge}
                    disabled={!newLeaseChargeName.trim() || !newLeaseChargeAmount}
                >
                    {$t('finance.leaseAndRent.addCharge')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Special Change Popup -->
{#if showSpecialChangePopup}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center" on:click|self={() => { showSpecialChangePopup = false; }} on:keydown={(e) => { if (e.key === 'Escape') showSpecialChangePopup = false; }}>
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-[500px] max-w-[90vw]" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <h4 class="text-lg font-bold text-slate-800 mb-5 flex items-center gap-2">
                <span class="text-xl">⚡</span> {$t('finance.leaseAndRent.specialChange')} — <span class="text-purple-600">{specialChangeFieldLabel}</span>
            </h4>
            <div class="space-y-4">
                <!-- Current Value -->
                <div class="flex items-center gap-3 bg-slate-50 rounded-xl p-3 border border-slate-200">
                    <span class="text-xs font-bold text-slate-500 uppercase">{$t('finance.leaseAndRent.currentValue')}:</span>
                    <span class="text-sm font-bold text-red-600">{specialChangeOldValue.toLocaleString()}</span>
                </div>
                <!-- New Value -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{$t('finance.leaseAndRent.newValueLabel')}</label>
                    <input type="number" step="0.01" bind:value={specialChangeNewValue} placeholder="0.00" class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all" />
                </div>
                <!-- Effective From -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{$t('finance.leaseAndRent.effectiveFrom')}</label>
                    <input type="date" bind:value={specialChangeEffectiveFrom} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all" />
                </div>
                <!-- Till End of Contract OR Date Range -->
                <div class="bg-purple-50 rounded-xl p-3 border border-purple-200">
                    <label class="flex items-center gap-2 cursor-pointer mb-2">
                        <input type="checkbox" bind:checked={specialChangeTillEnd} class="w-4 h-4 rounded text-purple-600 focus:ring-purple-500" />
                        <span class="text-sm font-bold text-purple-700">♾️ {$t('finance.leaseAndRent.tillEndOfContract')}</span>
                    </label>
                    {#if !specialChangeTillEnd}
                        <div class="mt-2">
                            <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wide">{$t('finance.leaseAndRent.effectiveUntil')}</label>
                            <input type="date" bind:value={specialChangeEffectiveUntil} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all" />
                        </div>
                    {/if}
                </div>
                <!-- Payment Period -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{$t('finance.leaseAndRent.paymentPeriod')}</label>
                    <select bind:value={specialChangePaymentPeriod} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all">
                        <option value="daily">{$t('finance.leaseAndRent.daily')}</option>
                        <option value="monthly">{$t('finance.leaseAndRent.monthly')}</option>
                        <option value="every_3_months">{$t('finance.leaseAndRent.every3Months')}</option>
                        <option value="every_6_months">{$t('finance.leaseAndRent.every6Months')}</option>
                        <option value="yearly">{$t('finance.leaseAndRent.yearly')}</option>
                    </select>
                </div>
                <!-- Reason -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{$t('finance.leaseAndRent.reasonLabel')}</label>
                    <input type="text" bind:value={specialChangeReason} placeholder={$t('finance.leaseAndRent.reasonPlaceholder')} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all" />
                </div>
            </div>
            <div class="flex justify-end gap-3 mt-6">
                <button class="px-5 py-2.5 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-100 transition-all" on:click={() => { showSpecialChangePopup = false; }}>
                    {$t('common.cancel')}
                </button>
                <button
                    class="px-5 py-2.5 rounded-xl bg-purple-600 text-white text-sm font-bold hover:bg-purple-700 transition-all disabled:opacity-50"
                    on:click={saveSpecialChange}
                    disabled={savingSpecialChange || !specialChangeNewValue || !specialChangeEffectiveFrom || (!specialChangeTillEnd && !specialChangeEffectiveUntil)}
                >
                    {#if savingSpecialChange}⏳ {$t('common.saving')}{:else}💾 {$t('common.save')}{/if}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- PAYMENT POPUP -->
{#if showPaymentPopup}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50" on:click|self={() => { showPaymentPopup = false; }} on:keydown={(e) => { if (e.key === 'Escape') showPaymentPopup = false; }}>
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-[440px] max-h-[90vh] overflow-y-auto border border-indigo-200/50">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-black text-indigo-900">💳 {$t('finance.leaseAndRent.paymentPopupTitle')}</h3>
                <button class="text-slate-400 hover:text-slate-600 text-xl font-bold" on:click={() => { showPaymentPopup = false; }}>✕</button>
            </div>

            <!-- Info -->
            <div class="bg-indigo-50 rounded-xl p-3 mb-4 space-y-1 text-sm">
                <div class="flex justify-between"><span class="text-slate-600 font-medium">{$t('finance.leaseAndRent.columnLabel')}:</span><span class="font-bold text-indigo-800">{paymentPopupColumnLabel}</span></div>
                <div class="flex justify-between"><span class="text-slate-600 font-medium">{$t('finance.leaseAndRent.period')} #{paymentPopupRow?.num}:</span><span class="font-bold text-indigo-800">{fmtDate(paymentPopupRow?.from)} → {fmtDate(paymentPopupRow?.to)}</span></div>
                <div class="flex justify-between"><span class="text-slate-600 font-medium">{$t('finance.leaseAndRent.totalDue')}:</span><span class="font-bold text-indigo-800">{paymentPopupTotalDue.toLocaleString()}</span></div>
                {#if paymentPopupAlreadyPaid > 0}
                    <div class="flex justify-between"><span class="text-green-600 font-medium">{$t('finance.leaseAndRent.alreadyPaid')}:</span><span class="font-bold text-green-700">{paymentPopupAlreadyPaid.toLocaleString()}</span></div>
                {/if}
                <div class="flex justify-between border-t border-indigo-200 pt-1"><span class="{paymentPopupRemaining > 0 ? 'text-red-600' : 'text-green-600'} font-bold">{paymentPopupRemaining > 0 ? $t('finance.leaseAndRent.remaining') : '✅ ' + $t('finance.leaseAndRent.fullyPaid')}:</span><span class="font-black {paymentPopupRemaining > 0 ? 'text-red-700' : 'text-green-700'} text-base">{paymentPopupRemaining.toLocaleString()}</span></div>
            </div>

            {#if paymentPopupRemaining > 0}
            <!-- Payment Mode -->
            <div class="flex gap-2 mb-4">
                <button
                    class="flex-1 py-2.5 rounded-xl text-sm font-bold transition-all {paymentPopupMode === 'full' ? 'bg-green-600 text-white shadow-lg' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                    on:click={() => { paymentPopupMode = 'full'; paymentPopupAmount = paymentPopupRemaining; }}
                >
                    ✅ {$t('finance.leaseAndRent.payInFull')}
                </button>
                <button
                    class="flex-1 py-2.5 rounded-xl text-sm font-bold transition-all {paymentPopupMode === 'partial' ? 'bg-yellow-500 text-white shadow-lg' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                    on:click={() => { paymentPopupMode = 'partial'; paymentPopupAmount = 0; }}
                >
                    📝 {$t('finance.leaseAndRent.payPartial')}
                </button>
            </div>

            <!-- Partial Amount Input -->
            {#if paymentPopupMode === 'partial'}
                <div class="mb-4">
                    <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">{$t('finance.leaseAndRent.enterAmount')}</label>
                    <input type="number" step="0.01" min="0.01" max={paymentPopupRemaining} bind:value={paymentPopupAmount} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-bold focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all" placeholder="0.00" />
                    {#if paymentPopupAmount > paymentPopupRemaining}
                        <p class="text-[10px] text-red-500 mt-1 font-bold">Max: {paymentPopupRemaining.toLocaleString()}</p>
                    {/if}
                </div>
            {/if}
            {/if}

            <!-- Payment History -->
            {#if paymentPopupEntries.length > 0}
                <div class="mb-4">
                    <h4 class="text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">📋 {$t('finance.leaseAndRent.paymentHistory')}</h4>
                    <div class="bg-slate-50 rounded-xl border border-slate-200 divide-y divide-slate-100 max-h-[120px] overflow-y-auto">
                        {#each paymentPopupEntries as entry}
                            <div class="flex justify-between items-center px-3 py-1.5 text-xs">
                                <span class="text-slate-500">{fmtDate(entry.paid_date)}</span>
                                <span class="font-bold text-green-700">{Number(entry.amount).toLocaleString()}</span>
                            </div>
                        {/each}
                    </div>
                </div>
            {/if}

            <!-- Actions -->
            <div class="flex justify-end gap-3">
                <button class="px-5 py-2.5 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-100 transition-all" on:click={() => { showPaymentPopup = false; }}>
                    {$t('common.cancel')}
                </button>
                {#if paymentPopupRemaining > 0}
                <button
                    class="px-5 py-2.5 rounded-xl bg-indigo-600 text-white text-sm font-bold hover:bg-indigo-700 transition-all disabled:opacity-50"
                    on:click={savePaymentEntry}
                    disabled={paymentSaving || (paymentPopupMode === 'partial' && (!paymentPopupAmount || paymentPopupAmount <= 0 || paymentPopupAmount > paymentPopupRemaining))}
                >
                    {#if paymentSaving}⏳ {$t('finance.leaseAndRent.saving')}{:else}💾 {$t('finance.leaseAndRent.save')}{/if}
                </button>
                {/if}
            </div>
        </div>
    </div>
{/if}

<!-- Report Popup: Multi-select parties + Date Range -->
{#if showReportPopup}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50" on:click|self={() => { showReportPopup = false; }} on:keydown={(e) => { if (e.key === 'Escape') showReportPopup = false; }}>
        <div class="bg-white rounded-3xl shadow-2xl border border-slate-200 w-[520px] max-h-[85vh] flex flex-col overflow-hidden">
            <!-- Header -->
            <div class="flex items-center justify-between px-5 py-4 border-b border-slate-200 {reportPopupType === 'lease' ? 'bg-emerald-50' : 'bg-orange-50'}">
                <h3 class="text-base font-black {reportPopupType === 'lease' ? 'text-emerald-800' : 'text-orange-800'}">
                    {reportPopupType === 'lease' ? '📋' : '🏠'} {$t(`finance.leaseAndRent.${reportPopupType}Report`)}
                </h3>
                <button class="text-slate-400 hover:text-slate-600 text-xl font-bold" on:click={() => { showReportPopup = false; }}>✕</button>
            </div>

            <!-- Party Selection -->
            <div class="px-5 pt-4 pb-2">
                <div class="flex items-center justify-between mb-2">
                    <span class="text-xs font-bold text-slate-700">{$t('finance.leaseAndRent.selectParties')}</span>
                    <div class="flex gap-1.5">
                        <button class="px-2 py-0.5 rounded text-[10px] font-bold text-cyan-700 bg-cyan-50 hover:bg-cyan-100 transition-colors" on:click={selectAllReportParties}>{$t('finance.leaseAndRent.selectAll')}</button>
                        <button class="px-2 py-0.5 rounded text-[10px] font-bold text-slate-500 bg-slate-50 hover:bg-slate-100 transition-colors" on:click={deselectAllReportParties}>{$t('finance.leaseAndRent.deselectAll')}</button>
                    </div>
                </div>
                <!-- Search -->
                <input
                    type="text"
                    class="w-full px-3 py-2 rounded-lg border border-slate-200 text-xs focus:ring-2 {reportPopupType === 'lease' ? 'focus:ring-emerald-300' : 'focus:ring-orange-300'} focus:border-transparent outline-none mb-2"
                    placeholder="🔍 {$t('finance.leaseAndRent.searchParty')}..."
                    bind:value={reportPartySearch}
                />
                <!-- Party List with Checkboxes -->
                <div class="max-h-[200px] overflow-y-auto rounded-lg border border-slate-100 bg-slate-50/50">
                    {#if reportPartiesLoading}
                        <div class="p-4 text-center text-xs text-slate-500 animate-pulse">⏳ {$t('finance.leaseAndRent.reportLoading')}</div>
                    {:else if reportFilteredParties.length === 0}
                        <div class="p-4 text-center text-xs text-slate-400">{$t('finance.leaseAndRent.reportNoData')}</div>
                    {:else}
                        {#each reportFilteredParties as party}
                            {@const summary = reportPartySummaries[party.id]}
                            {@const isSelected = reportSelectedPartyIds.has(party.id)}
                            <button
                                class="w-full flex items-center gap-2 px-3 py-2 text-left hover:bg-white/80 transition-colors border-b border-slate-100 last:border-b-0 {isSelected ? (reportPopupType === 'lease' ? 'bg-emerald-50/60' : 'bg-orange-50/60') : ''}"
                                on:click={() => toggleReportParty(party.id)}
                            >
                                <!-- Checkbox -->
                                <div class="w-4 h-4 rounded border-2 flex items-center justify-center flex-shrink-0 transition-all {isSelected ? (reportPopupType === 'lease' ? 'bg-emerald-500 border-emerald-500' : 'bg-orange-500 border-orange-500') : 'border-slate-300 bg-white'}">
                                    {#if isSelected}<span class="text-white text-[10px] font-bold">✓</span>{/if}
                                </div>
                                <!-- Party Info -->
                                <div class="flex-1 min-w-0">
                                    <div class="text-[11px] font-bold text-slate-800 truncate">{party.party_name_en || '—'}</div>
                                    <div class="text-[10px] text-slate-500 truncate" dir="rtl">{party.party_name_ar || '—'}</div>
                                </div>
                                <!-- Paid/Unpaid Summary -->
                                {#if summary}
                                    <div class="flex flex-col items-end gap-0.5 flex-shrink-0">
                                        <span class="text-[9px] font-bold text-green-600 bg-green-50 rounded px-1.5 py-0.5">✅ {summary.totalPaid.toLocaleString()}</span>
                                        <span class="text-[9px] font-bold text-red-600 bg-red-50 rounded px-1.5 py-0.5">❌ {(summary.totalDue - summary.totalPaid).toLocaleString()}</span>
                                    </div>
                                {/if}
                            </button>
                        {/each}
                    {/if}
                </div>
                <div class="text-[10px] text-slate-500 mt-1 font-semibold">
                    {reportSelectedPartyIds.size} / {reportFilteredParties.length} {$t('finance.leaseAndRent.selected')}
                </div>
            </div>

            <!-- Date Range -->
            <div class="px-5 py-3 border-t border-slate-100">
                <span class="text-xs font-bold text-slate-700 mb-2 block">{$t('finance.leaseAndRent.dateRange')}</span>
                <div class="flex gap-3 items-center">
                    <div class="flex-1">
                        <label class="text-[10px] font-bold text-slate-500 mb-0.5 block">{$t('finance.leaseAndRent.dateFrom')}</label>
                        <input type="date" class="w-full px-3 py-2 rounded-lg border border-slate-200 text-xs focus:ring-2 {reportPopupType === 'lease' ? 'focus:ring-emerald-300' : 'focus:ring-orange-300'} focus:border-transparent outline-none" bind:value={reportDateFrom} />
                    </div>
                    <span class="text-slate-400 font-bold mt-4">→</span>
                    <div class="flex-1">
                        <label class="text-[10px] font-bold text-slate-500 mb-0.5 block">{$t('finance.leaseAndRent.dateTo')}</label>
                        <input type="date" class="w-full px-3 py-2 rounded-lg border border-slate-200 text-xs focus:ring-2 {reportPopupType === 'lease' ? 'focus:ring-emerald-300' : 'focus:ring-orange-300'} focus:border-transparent outline-none" bind:value={reportDateTo} />
                    </div>
                </div>
            </div>

            <!-- Actions -->
            <div class="flex items-center justify-end gap-3 px-5 py-4 border-t border-slate-200 bg-slate-50/50">
                <button class="px-5 py-2.5 rounded-xl text-sm font-bold text-slate-600 hover:bg-slate-100 transition-all" on:click={() => { showReportPopup = false; }}>
                    {$t('finance.leaseAndRent.close')}
                </button>
                <button
                    class="px-5 py-2.5 rounded-xl text-sm font-bold text-white transition-all disabled:opacity-50 {reportPopupType === 'lease' ? 'bg-emerald-600 hover:bg-emerald-700' : 'bg-orange-600 hover:bg-orange-700'}"
                    on:click={generateReport}
                    disabled={reportSelectedPartyIds.size === 0 || !reportDateFrom || !reportDateTo}
                >
                    📊 {$t('finance.leaseAndRent.generateReport')}
                </button>
            </div>
        </div>
    </div>
{/if}
