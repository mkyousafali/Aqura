<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface Branch {
        id: string;
        name_en: string;
        name_ar: string;
        location_en?: string;
        location_ar?: string;
        name?: string;
    }

    interface Nationality {
        id: string;
        name_en: string;
        name_ar: string;
        name?: string;
    }

    interface EmployeeForSelection {
        id: string;
        employee_name_en: string;
        employee_name_ar: string;
        branch_name_en: string;
        branch_name_ar: string;
    }

    interface EmployeeMaster {
        id: string;
        name_en: string;
        name_ar: string;
        current_branch_id: string;
        nationality_id: string;
        employment_status: string;
        sponsorship_status?: string;
    }

    interface ShiftSlot {
        id?: number;
        version_id?: number;
        slot_order: number;
        shift_start_time: string;
        shift_start_buffer: number;
        shift_end_time: string;
        shift_end_buffer: number;
        is_shift_overlapping_next_day: boolean;
        working_hours: number;
        allowed_late_start_minutes?: number;
        allowed_early_end_minutes?: number;
    }

    interface ShiftVersion {
        version_id: number;
        date_from: string;
        date_to: string | null;
        slots: ShiftSlot[];
    }

    interface RegularRow {
        employee_id: string;
        employee_name_en: string;
        employee_name_ar: string;
        branch_id: string;
        branch_name_en: string;
        branch_name_ar: string;
        branch_location_en: string;
        branch_location_ar: string;
        nationality_id: string;
        nationality_name_en: string;
        nationality_name_ar: string;
        sponsorship_status?: string;
        employment_status: string;
        version_id?: number;
        date_from?: string;
        date_to?: string | null;
        slots: ShiftSlot[];
        allVersions: ShiftVersion[];
    }

    interface WeekdayRow {
        employee_id: string;
        employee_name_en: string;
        employee_name_ar: string;
        branch_id: string;
        branch_name_en: string;
        branch_name_ar: string;
        branch_location_en: string;
        branch_location_ar: string;
        nationality_id: string;
        nationality_name_en: string;
        nationality_name_ar: string;
        sponsorship_status?: string;
        employment_status: string;
        weekdaySlots: { [weekday: number]: { version_id: number; date_from?: string; date_to?: string | null; slots: ShiftSlot[] } | null };
    }

    interface DateWiseRow {
        version_id: number;
        employee_id: string;
        employee_name_en: string;
        employee_name_ar: string;
        branch_id: string;
        branch_name_en: string;
        branch_name_ar: string;
        branch_location_en: string;
        branch_location_ar: string;
        nationality_id: string;
        nationality_name_en: string;
        nationality_name_ar: string;
        sponsorship_status?: string;
        employment_status: string;
        date_from: string;
        date_to: string;
        slots: ShiftSlot[];
        _grouped?: boolean;
        _allVersionIds?: number[];
        _allDates?: string[];
        _dateFrom?: string;
        _dateTo?: string;
        _dayCount?: number;
    }

    let activeTab: 'regular' | 'weekday' | 'date' = 'regular';
    let supabase: any;
    let realtimeChannel: any;
    let loading = false;
    let error: string | null = null;

    let regularRows: RegularRow[] = [];
    let weekdayRows: WeekdayRow[] = [];
    let dateWiseRows: DateWiseRow[] = [];

    let availableBranches: Branch[] = [];
    let availableNationalities: Nationality[] = [];
    let searchQuery = '';
    let branchFilter = '';
    let nationalityFilter = '';
    let statusFilter = '';
    let dateFilterStart = '';
    let dateFilterEnd = '';

    let allEmployees: EmployeeForSelection[] = [];
    let showEmployeeSelectModal = false;
    let employeeSearchQuery = '';
    let isRangeMode = false;

    let showModal = false;
    let isSaving = false;
    let selectedEmployeeId: string | null = null;
    let modalSlots: ShiftSlot[] = [];
    let modalDateFrom = '';
    let modalDateTo = '';
    let modalWeekday = 0;
    let editingVersionId: number | null = null;

    let slotTime12: Array<{
        startHour: string; startMinute: string; startPeriod: string;
        endHour: string; endMinute: string; endPeriod: string;
    }> = [];

    let showNotification = false;
    let notificationMessage = '';
    let notificationType: 'success' | 'error' = 'success';
    let notificationTimeout: ReturnType<typeof setTimeout> | null = null;

    // Delete version picker modal
    let showDeletePickerModal = false;
    let deletePickerEmployee: RegularRow | null = null;
    let deletePickerChecked: Record<number, boolean> = {};
    let isDeletingVersions = false;

    const tabs = [
        { id: 'regular', label: 'Regular Shifts', icon: '🕒' },
        { id: 'weekday', label: 'Day-Wise Shifts', icon: '📅' },
        { id: 'date', label: 'Date-Wise Shifts', icon: '📆' }
    ];

    $: weekdayNames = [
        $t('common.days.sunday'), $t('common.days.monday'), $t('common.days.tuesday'),
        $t('common.days.wednesday'), $t('common.days.thursday'), $t('common.days.friday'),
        $t('common.days.saturday')
    ];

    $: availableEmploymentStatuses = [
        { id: 'Job (With Finger)', label: $t('employeeFiles.statuses.jobWithFinger') },
        { id: 'Job (No Finger)', label: $t('employeeFiles.statuses.jobNoFinger') },
        { id: 'Remote Job', label: $t('employeeFiles.statuses.remoteJob') },
        { id: 'Vacation', label: $t('employeeFiles.statuses.vacation') },
        { id: 'Resigned', label: $t('employeeFiles.statuses.resigned') },
        { id: 'Terminated', label: $t('employeeFiles.statuses.terminated') },
        { id: 'Run Away', label: $t('employeeFiles.statuses.escape') }
    ];

    $: filteredRegular = filterRows(regularRows, searchQuery, branchFilter, nationalityFilter, statusFilter);
    $: filteredWeekday = filterRows(weekdayRows, searchQuery, branchFilter, nationalityFilter, statusFilter);
    $: filteredDateWise = filterRows(dateWiseRows, searchQuery, branchFilter, nationalityFilter, statusFilter);

    $: activeWeekdays = (() => {
        const days: { index: number; name: string }[] = [];
        for (let i = 0; i < 7; i++) {
            const hasShift = filteredWeekday.some((r: WeekdayRow) => r.weekdaySlots?.[i] != null);
            if (hasShift) days.push({ index: i, name: weekdayNames[i] });
        }
        return days;
    })();

    function filterRows(rows: any[], _search: string, _branch: string, _nat: string, _status: string): any[] {
        let filtered = [...rows];
        if (branchFilter) filtered = filtered.filter(r => String(r.branch_id) === String(branchFilter));
        if (nationalityFilter) filtered = filtered.filter(r => String(r.nationality_id) === String(nationalityFilter));
        if (statusFilter) filtered = filtered.filter(r => r.employment_status === statusFilter);
        if (searchQuery.trim()) {
            const q = searchQuery.toLowerCase();
            filtered = filtered.filter(r =>
                r.employee_name_en?.toLowerCase().includes(q) ||
                r.employee_name_ar?.toLowerCase().includes(q) ||
                String(r.employee_id).toLowerCase().includes(q)
            );
        }
        return sortEmployees(filtered);
    }

    function sortEmployees(list: any[]): any[] {
        const order: Record<string, number> = {
            'Job (With Finger)': 1, 'Job (No Finger)': 2, 'Remote Job': 3,
            'Vacation': 4, 'Resigned': 5, 'Terminated': 6, 'Run Away': 7
        };
        return list.sort((a, b) => {
            const sa = order[a.employment_status] || 99;
            const sb = order[b.employment_status] || 99;
            if (sa !== sb) return sa - sb;
            return (a.employee_name_en || '').toLowerCase().localeCompare((b.employee_name_en || '').toLowerCase());
        });
    }

    function empName(r: any): string { return $locale === 'ar' ? (r.employee_name_ar || r.employee_name_en) : r.employee_name_en; }
    function natName(r: any): string { return $locale === 'ar' ? (r.nationality_name_ar || r.nationality_name_en) : r.nationality_name_en; }
    function branchDisplay(r: any): string {
        const name = $locale === 'ar' ? (r.branch_name_ar || r.branch_name_en) : r.branch_name_en;
        const loc = $locale === 'ar' ? (r.branch_location_ar || r.branch_location_en) : r.branch_location_en;
        return loc ? `${name} (${loc})` : name;
    }
    function sponsorDisplay(status: any): { color: string; text: string } {
        const isSponsored = status === true || status === 'true' || status === 'yes' || status === 'Yes';
        return isSponsored
            ? { color: 'bg-green-100 text-green-800', text: $locale === 'ar' ? 'على الكفالة' : 'On Sponsorship' }
            : { color: 'bg-red-100 text-red-800', text: $locale === 'ar' ? 'ليس على الكفالة' : 'Not On Sponsorship' };
    }
    function statusDisplay(status: string | undefined): { color: string; text: string } {
        switch (status) {
            case 'Job (With Finger)': return { color: 'bg-green-100 text-green-800', text: $t('employeeFiles.inJob') || 'Job (With Finger)' };
            case 'Job (No Finger)': return { color: 'bg-emerald-100 text-emerald-800', text: $t('employeeFiles.jobNoFinger') || 'Job (No Finger)' };
            case 'Remote Job': return { color: 'bg-cyan-100 text-cyan-800', text: $t('employeeFiles.remoteJob') || 'Remote Job' };
            case 'Vacation': return { color: 'bg-blue-100 text-blue-800', text: $t('employeeFiles.vacation') || 'Vacation' };
            case 'Terminated': return { color: 'bg-red-100 text-red-800', text: $t('employeeFiles.terminated') || 'Terminated' };
            case 'Run Away': return { color: 'bg-purple-100 text-purple-800', text: $t('employeeFiles.runAway') || 'Run Away' };
            default: return { color: 'bg-gray-100 text-gray-800', text: $t('employeeFiles.resigned') || 'Resigned' };
        }
    }

    function fmt12(time: string | undefined): string {
        if (!time) return '—';
        const [h, m] = time.split(':').map(Number);
        const period = h >= 12 ? 'PM' : 'AM';
        return `${(h % 12 || 12)}:${String(m).padStart(2, '0')} ${period}`;
    }

    function calculateWorkingHours(start: string, end: string, overlap: boolean): number {
        const [sh, sm] = start.split(':').map(Number);
        const [eh, em] = end.split(':').map(Number);
        const startMin = sh * 60 + sm;
        const endMin = eh * 60 + em;
        const total = overlap ? (1440 - startMin + endMin) : (endMin - startMin);
        return Math.round((total / 60) * 100) / 100;
    }

    function showSuccess(msg: string) {
        notificationMessage = msg; notificationType = 'success'; showNotification = true;
        if (notificationTimeout) clearTimeout(notificationTimeout);
        notificationTimeout = setTimeout(() => showNotification = false, 3000);
    }
    function showError(msg: string) {
        notificationMessage = msg; notificationType = 'error'; showNotification = true;
        if (notificationTimeout) clearTimeout(notificationTimeout);
        notificationTimeout = setTimeout(() => showNotification = false, 4000);
    }

    async function initSupabase() {
        if (!supabase) {
            const { supabase: client } = await import('$lib/utils/supabase');
            supabase = client;
        }
    }

    onMount(async () => {
        await initSupabase();
        setupRealtime();
        resetFilters();
        await refreshCurrentTab();
    });

    onDestroy(() => {
        if (realtimeChannel && supabase) supabase.removeChannel(realtimeChannel);
    });

    function setupRealtime() {
        if (!supabase) return;
        realtimeChannel = supabase.channel('shifts-module-realtime')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'hr_regular_shift_versions' }, () => refreshCurrentTab())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'hr_regular_shift_slots' }, () => refreshCurrentTab())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'hr_special_shift_weekday_versions' }, () => refreshCurrentTab())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'hr_special_shift_weekday_slots' }, () => refreshCurrentTab())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'hr_special_shift_date_wise_versions' }, () => refreshCurrentTab())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'hr_special_shift_date_wise_slots' }, () => refreshCurrentTab())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'hr_employee_master' }, () => refreshCurrentTab())
            .subscribe();
    }

    function resetFilters() {
        searchQuery = ''; branchFilter = ''; nationalityFilter = ''; statusFilter = '';
        if (activeTab === 'date') {
            const today = new Date();
            const past40 = new Date(today); past40.setDate(today.getDate() - 40);
            const fmt = (d: Date) => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
            dateFilterStart = fmt(past40); dateFilterEnd = fmt(today);
        }
    }

    async function refreshCurrentTab() {
        if (activeTab === 'regular') await loadRegular();
        else if (activeTab === 'weekday') await loadWeekday();
        else if (activeTab === 'date') await loadDateWise();
    }

    async function handleTabChange(tabId: string) {
        activeTab = tabId as any;
        resetFilters();
        await refreshCurrentTab();
    }

    // ---- Shared employee/branch/nationality loader ----

    async function loadEmployeeBase() {
        const [empRes, branchRes, natRes] = await Promise.all([
            supabase.from('hr_employee_master').select('id, name_en, name_ar, current_branch_id, nationality_id, employment_status, sponsorship_status'),
            supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar'),
            supabase.from('nationalities').select('id, name_en, name_ar')
        ]);
        if (empRes.error) throw empRes.error;
        const employees: EmployeeMaster[] = empRes.data || [];
        const branches: Branch[] = branchRes.data || [];
        const nationalities: Nationality[] = natRes.data || [];
        availableBranches = branches;
        availableNationalities = nationalities;
        const branchMap = new Map(branches.map(b => [String(b.id), b]));
        const natMap = new Map(nationalities.map(n => [String(n.id), n]));
        allEmployees = sortEmployees(employees.map(e => {
            const br = branchMap.get(String(e.current_branch_id));
            return { id: e.id, employee_name_en: e.name_en, employee_name_ar: e.name_ar, branch_name_en: br?.name_en || 'N/A', branch_name_ar: br?.name_ar || 'N/A' };
        }));
        return { employees, branchMap, natMap };
    }

    function buildRow(emp: EmployeeMaster, branchMap: Map<string, Branch>, natMap: Map<string, Nationality>) {
        const br = branchMap.get(String(emp.current_branch_id));
        const nat = natMap.get(String(emp.nationality_id));
        return {
            employee_id: emp.id, employee_name_en: emp.name_en, employee_name_ar: emp.name_ar,
            branch_id: emp.current_branch_id, branch_name_en: br?.name_en || 'N/A', branch_name_ar: br?.name_ar || 'N/A',
            branch_location_en: br?.location_en || '', branch_location_ar: br?.location_ar || '',
            nationality_id: emp.nationality_id, nationality_name_en: nat?.name_en || 'N/A', nationality_name_ar: nat?.name_ar || 'N/A',
            sponsorship_status: emp.sponsorship_status, employment_status: emp.employment_status,
        };
    }

    // ---- REGULAR SHIFTS ----

    async function loadRegular() {
        loading = true; error = null;
        try {
            await initSupabase();
            const { employees, branchMap, natMap } = await loadEmployeeBase();
            const { data: regRows } = await supabase.rpc('get_hr_regular_shifts', { p_employee_ids: employees.map(e => e.id) });
            // Group RPC rows by employee, then by version
            const empVersions = new Map<string, Map<number, { date_from: string; date_to: string | null; slots: ShiftSlot[] }>>();
            for (const r of regRows || []) {
                const eid = String(r.employee_id);
                if (!empVersions.has(eid)) empVersions.set(eid, new Map());
                const verMap = empVersions.get(eid)!;
                if (!verMap.has(r.version_id)) verMap.set(r.version_id, { date_from: r.date_from, date_to: r.date_to, slots: [] });
                verMap.get(r.version_id)!.slots.push(r);
            }
            const todayStr = new Date().toISOString().split('T')[0];
            regularRows = employees.map(emp => {
                const base = buildRow(emp, branchMap, natMap);
                const verMap = empVersions.get(emp.id);
                const allVersions: ShiftVersion[] = [];
                let activeVersion: ShiftVersion | null = null;
                if (verMap) {
                    for (const [vid, v] of verMap) {
                        const sv: ShiftVersion = { version_id: vid, date_from: v.date_from, date_to: v.date_to, slots: v.slots };
                        allVersions.push(sv);
                        // Pick the version covering today (or the latest open-ended one)
                        if ((!v.date_from || todayStr >= v.date_from) && (!v.date_to || todayStr <= v.date_to)) activeVersion = sv;
                    }
                    if (!activeVersion && allVersions.length > 0) activeVersion = allVersions[allVersions.length - 1];
                }
                return { ...base, version_id: activeVersion?.version_id, date_from: activeVersion?.date_from, date_to: activeVersion?.date_to, slots: activeVersion?.slots || [], allVersions } as RegularRow;
            });
        } catch (err: any) { console.error('Error loading regular shifts:', err); error = err.message || 'Failed to load'; }
        finally { loading = false; }
    }

    // ---- WEEKDAY SHIFTS ----

    async function loadWeekday() {
        loading = true; error = null;
        try {
            await initSupabase();
            const { employees, branchMap, natMap } = await loadEmployeeBase();
            const { data: versions } = await supabase.from('hr_special_shift_weekday_versions').select('id, employee_id, weekday, date_from, date_to');
            const versionIds = (versions || []).map((v: any) => v.id);
            let slots: any[] = [];
            if (versionIds.length > 0) {
                const { data } = await supabase.from('hr_special_shift_weekday_slots').select('*').in('version_id', versionIds).order('slot_order');
                slots = data || [];
            }
            const empWeekdayMap = new Map<string, { [weekday: number]: { version_id: number; slots: ShiftSlot[] } }>();
            for (const v of (versions || [])) {
                if (!empWeekdayMap.has(v.employee_id)) empWeekdayMap.set(v.employee_id, {});
                empWeekdayMap.get(v.employee_id)![v.weekday] = { version_id: v.id, date_from: v.date_from, date_to: v.date_to, slots: [] };
            }
            for (const s of slots) {
                const v = (versions || []).find((vv: any) => vv.id === s.version_id);
                if (v && empWeekdayMap.has(v.employee_id)) empWeekdayMap.get(v.employee_id)![v.weekday]?.slots.push(s);
            }
            weekdayRows = employees.map(emp => {
                const base = buildRow(emp, branchMap, natMap);
                const wd = empWeekdayMap.get(emp.id) || {};
                const weekdaySlots: { [w: number]: { version_id: number; date_from?: string; date_to?: string | null; slots: ShiftSlot[] } | null } = {};
                for (let i = 0; i < 7; i++) weekdaySlots[i] = wd[i] || null;
                return { ...base, weekdaySlots } as WeekdayRow;
            });
        } catch (err: any) { console.error('Error loading weekday shifts:', err); error = err.message || 'Failed to load'; }
        finally { loading = false; }
    }

    // ---- DATE-WISE SHIFTS ----

    async function loadDateWise() {
        loading = true; error = null;
        try {
            await initSupabase();
            const { employees, branchMap, natMap } = await loadEmployeeBase();
            let query = supabase.from('hr_special_shift_date_wise_versions').select('id, employee_id, date_from, date_to');
            if (dateFilterStart) query = query.gte('date_from', dateFilterStart);
            if (dateFilterEnd) query = query.lte('date_to', dateFilterEnd);
            query = query.order('date_from', { ascending: false });
            const { data: versions } = await query;
            const versionIds = (versions || []).map((v: any) => v.id);
            let slots: any[] = [];
            if (versionIds.length > 0) {
                const { data } = await supabase.from('hr_special_shift_date_wise_slots').select('*').in('version_id', versionIds).order('slot_order');
                slots = data || [];
            }
            const slotsByVersion = new Map<number, ShiftSlot[]>();
            for (const s of slots) { if (!slotsByVersion.has(s.version_id)) slotsByVersion.set(s.version_id, []); slotsByVersion.get(s.version_id)!.push(s); }
            const empMap = new Map(employees.map(e => [e.id, e]));
            const rawRows: DateWiseRow[] = (versions || []).map((v: any) => {
                const emp = empMap.get(v.employee_id);
                const base = emp ? buildRow(emp, branchMap, natMap) : {
                    employee_id: v.employee_id, employee_name_en: v.employee_id, employee_name_ar: '',
                    branch_id: '', branch_name_en: 'N/A', branch_name_ar: 'N/A', branch_location_en: '', branch_location_ar: '',
                    nationality_id: '', nationality_name_en: 'N/A', nationality_name_ar: 'N/A', sponsorship_status: undefined, employment_status: ''
                };
                return { ...base, version_id: v.id, date_from: v.date_from, date_to: v.date_to, slots: slotsByVersion.get(v.id) || [] } as DateWiseRow;
            });
            dateWiseRows = groupDateWise(rawRows);
        } catch (err: any) { console.error('Error loading date-wise shifts:', err); error = err.message || 'Failed to load'; }
        finally { loading = false; }
    }

    function groupDateWise(rows: DateWiseRow[]): DateWiseRow[] {
        const groups = new Map<string, DateWiseRow[]>();
        for (const r of rows) {
            const s = r.slots[0];
            const key = `${r.employee_id}_${s?.shift_start_time}_${s?.shift_end_time}_${s?.shift_start_buffer}_${s?.shift_end_buffer}_${s?.is_shift_overlapping_next_day}`;
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key)!.push(r);
        }
        const grouped: DateWiseRow[] = [];
        for (const [, records] of groups) {
            records.sort((a, b) => (a.date_from || '').localeCompare(b.date_from || ''));
            const first = records[0]; const last = records[records.length - 1];
            if (records.length === 1) {
                grouped.push({ ...first, _grouped: false, _dayCount: 1 });
            } else {
                grouped.push({ ...first, _grouped: true, _allVersionIds: records.map(r => r.version_id), _allDates: records.map(r => r.date_from), _dateFrom: first.date_from, _dateTo: last.date_from, _dayCount: records.length });
            }
        }
        return grouped;
    }

    // ---- MODAL TIME HELPERS ----

    function syncSlotTimeTo12h() {
        slotTime12 = modalSlots.map(slot => {
            const [sh, sm] = (slot.shift_start_time || '09:00').split(':').map(Number);
            const [eh, em] = (slot.shift_end_time || '17:00').split(':').map(Number);
            return {
                startHour: String((sh % 12) || 12).padStart(2, '0'), startMinute: String(sm || 0).padStart(2, '0'), startPeriod: sh >= 12 ? 'PM' : 'AM',
                endHour: String((eh % 12) || 12).padStart(2, '0'), endMinute: String(em || 0).padStart(2, '0'), endPeriod: eh >= 12 ? 'PM' : 'AM'
            };
        });
    }

    function updateSlotStartTime(index: number) {
        const t12 = slotTime12[index]; let h = parseInt(t12.startHour);
        if (t12.startPeriod === 'PM' && h < 12) h += 12; if (t12.startPeriod === 'AM' && h === 12) h = 0;
        modalSlots[index].shift_start_time = `${String(h).padStart(2, '0')}:${t12.startMinute}`;
        recalcSlotHours(index);
    }

    function updateSlotEndTime(index: number) {
        const t12 = slotTime12[index]; let h = parseInt(t12.endHour);
        if (t12.endPeriod === 'PM' && h < 12) h += 12; if (t12.endPeriod === 'AM' && h === 12) h = 0;
        modalSlots[index].shift_end_time = `${String(h).padStart(2, '0')}:${t12.endMinute}`;
        recalcSlotHours(index);
    }

    function recalcSlotHours(index: number) {
        const s = modalSlots[index];
        s.working_hours = calculateWorkingHours(s.shift_start_time, s.shift_end_time, s.is_shift_overlapping_next_day);
        modalSlots = [...modalSlots];
    }

    function addSlot() {
        if (modalSlots.length < 4) {
            modalSlots = [...modalSlots, { slot_order: modalSlots.length + 1, shift_start_time: '09:00', shift_start_buffer: 0, shift_end_time: '17:00', shift_end_buffer: 0, is_shift_overlapping_next_day: false, working_hours: 8, allowed_late_start_minutes: 0, allowed_early_end_minutes: 0 }];
            syncSlotTimeTo12h();
        }
    }

    function removeSlot(index: number) {
        if (modalSlots.length > 1) { modalSlots = modalSlots.filter((_, i) => i !== index); syncSlotTimeTo12h(); }
    }

    $: totalHours = modalSlots.reduce((sum, s) => sum + (Number(s.working_hours) || 0), 0);

    // ---- OPEN MODAL ----

    function openRegularModal(row: RegularRow) {
        selectedEmployeeId = row.employee_id;
        // "Change" always creates a new version (auto-closes old); never edits in-place
        editingVersionId = null;
        modalDateFrom = new Date().toISOString().split('T')[0];
        modalDateTo = '';
        // Pre-fill with current shift times as a starting point
        modalSlots = row.slots.length > 0 ? row.slots.map(s => ({ ...s })) : [{ slot_order: 1, shift_start_time: '09:00', shift_start_buffer: 3, shift_end_time: '17:00', shift_end_buffer: 3, is_shift_overlapping_next_day: false, working_hours: 8, allowed_late_start_minutes: 0, allowed_early_end_minutes: 0 }];
        syncSlotTimeTo12h(); showModal = true;
    }

    function openWeekdayModal(row: WeekdayRow, weekday?: number) {
        selectedEmployeeId = row.employee_id; modalWeekday = weekday ?? 0;
        // Always create new version (auto-closes old), never edit in-place
        editingVersionId = null;
        modalDateFrom = new Date().toISOString().split('T')[0];
        modalDateTo = '';
        // Pre-fill with current shift times if exists
        const entry = row.weekdaySlots[modalWeekday];
        modalSlots = entry && entry.slots.length > 0 ? entry.slots.map(s => ({ ...s })) : [{ slot_order: 1, shift_start_time: '09:00', shift_start_buffer: 3, shift_end_time: '17:00', shift_end_buffer: 3, is_shift_overlapping_next_day: false, working_hours: 8, allowed_late_start_minutes: 0, allowed_early_end_minutes: 0 }];
        syncSlotTimeTo12h(); showModal = true;
    }

    function openDateWiseAddModal(emp: EmployeeForSelection) {
        selectedEmployeeId = emp.id; editingVersionId = null;
        const today = new Date().toISOString().split('T')[0]; modalDateFrom = today; modalDateTo = today;
        modalSlots = [{ slot_order: 1, shift_start_time: '09:00', shift_start_buffer: 3, shift_end_time: '17:00', shift_end_buffer: 3, is_shift_overlapping_next_day: false, working_hours: 8, allowed_late_start_minutes: 0, allowed_early_end_minutes: 0 }];
        syncSlotTimeTo12h(); showEmployeeSelectModal = false; showModal = true;
    }

    function closeModal() { showModal = false; selectedEmployeeId = null; editingVersionId = null; modalSlots = []; slotTime12 = []; }

    // ---- SAVE ----

    async function saveShift() {
        if (!selectedEmployeeId) return;
        isSaving = true;
        try {
            await initSupabase();
            if (activeTab === 'regular') await saveRegularShift();
            else if (activeTab === 'weekday') await saveWeekdayShift();
            else if (activeTab === 'date') await saveDateWiseShift();
            closeModal();
            showSuccess($t('hr.shift.success_saved') || 'Shift saved successfully!');
            await refreshCurrentTab();
        } catch (err: any) {
            console.error('Error saving shift:', err);
            showError(($t('hr.shift.error_failed_save') || 'Failed to save shift: ') + err.message);
        } finally { isSaving = false; }
    }

    async function saveRegularShift() {
        if (editingVersionId) {
            await supabase.from('hr_regular_shift_versions').update({ date_from: modalDateFrom || new Date().toISOString().split('T')[0], date_to: modalDateTo || null }).eq('id', editingVersionId);
            await supabase.from('hr_regular_shift_slots').delete().eq('version_id', editingVersionId);
            const payloads = modalSlots.map((s, i) => ({ version_id: editingVersionId, slot_order: i + 1, shift_start_time: s.shift_start_time, shift_start_buffer: s.shift_start_buffer, shift_end_time: s.shift_end_time, shift_end_buffer: s.shift_end_buffer, is_shift_overlapping_next_day: s.is_shift_overlapping_next_day, working_hours: s.working_hours, allowed_late_start_minutes: s.allowed_late_start_minutes || 0, allowed_early_end_minutes: s.allowed_early_end_minutes || 0 }));
            const { error } = await supabase.from('hr_regular_shift_slots').insert(payloads);
            if (error) throw error;
        } else {
            const newDateFrom = modalDateFrom || new Date().toISOString().split('T')[0];
            // Auto-close previous open-ended version for this employee
            const { data: prevVersions } = await supabase.from('hr_regular_shift_versions').select('id, date_to').eq('employee_id', selectedEmployeeId).is('date_to', null);
            if (prevVersions && prevVersions.length > 0) {
                const prevEndDate = new Date(newDateFrom);
                prevEndDate.setDate(prevEndDate.getDate() - 1);
                const prevEndStr = prevEndDate.toISOString().split('T')[0];
                for (const pv of prevVersions) {
                    await supabase.from('hr_regular_shift_versions').update({ date_to: prevEndStr }).eq('id', pv.id);
                }
            }
            const { data: ver, error: verErr } = await supabase.from('hr_regular_shift_versions').insert({ employee_id: selectedEmployeeId, date_from: newDateFrom, date_to: modalDateTo || null }).select('id').single();
            if (verErr) throw verErr;
            const payloads = modalSlots.map((s, i) => ({ version_id: ver.id, slot_order: i + 1, shift_start_time: s.shift_start_time, shift_start_buffer: s.shift_start_buffer, shift_end_time: s.shift_end_time, shift_end_buffer: s.shift_end_buffer, is_shift_overlapping_next_day: s.is_shift_overlapping_next_day, working_hours: s.working_hours, allowed_late_start_minutes: s.allowed_late_start_minutes || 0, allowed_early_end_minutes: s.allowed_early_end_minutes || 0 }));
            const { error } = await supabase.from('hr_regular_shift_slots').insert(payloads);
            if (error) throw error;
        }
    }

    async function saveWeekdayShift() {
        if (editingVersionId) {
            await supabase.from('hr_special_shift_weekday_slots').delete().eq('version_id', editingVersionId);
            await supabase.from('hr_special_shift_weekday_versions').update({ weekday: modalWeekday, date_from: modalDateFrom || new Date().toISOString().split('T')[0], date_to: modalDateTo || null }).eq('id', editingVersionId);
            const payloads = modalSlots.map((s, i) => ({ version_id: editingVersionId, slot_order: i + 1, shift_start_time: s.shift_start_time, shift_start_buffer: s.shift_start_buffer, shift_end_time: s.shift_end_time, shift_end_buffer: s.shift_end_buffer, is_shift_overlapping_next_day: s.is_shift_overlapping_next_day, working_hours: s.working_hours, allowed_late_start_minutes: s.allowed_late_start_minutes || 0, allowed_early_end_minutes: s.allowed_early_end_minutes || 0 }));
            const { error } = await supabase.from('hr_special_shift_weekday_slots').insert(payloads);
            if (error) throw error;
        } else {
            const newDateFrom = modalDateFrom || new Date().toISOString().split('T')[0];
            // Auto-close previous open-ended version for this employee+weekday
            const { data: prevVersions } = await supabase.from('hr_special_shift_weekday_versions').select('id, date_to').eq('employee_id', selectedEmployeeId).eq('weekday', modalWeekday).is('date_to', null);
            if (prevVersions && prevVersions.length > 0) {
                const prevEndDate = new Date(newDateFrom);
                prevEndDate.setDate(prevEndDate.getDate() - 1);
                const prevEndStr = prevEndDate.toISOString().split('T')[0];
                for (const pv of prevVersions) {
                    await supabase.from('hr_special_shift_weekday_versions').update({ date_to: prevEndStr }).eq('id', pv.id);
                }
            }
            const { data: ver, error: verErr } = await supabase.from('hr_special_shift_weekday_versions').insert({ employee_id: selectedEmployeeId, weekday: modalWeekday, date_from: newDateFrom, date_to: modalDateTo || null }).select('id').single();
            if (verErr) throw verErr;
            const payloads = modalSlots.map((s, i) => ({ version_id: ver.id, slot_order: i + 1, shift_start_time: s.shift_start_time, shift_start_buffer: s.shift_start_buffer, shift_end_time: s.shift_end_time, shift_end_buffer: s.shift_end_buffer, is_shift_overlapping_next_day: s.is_shift_overlapping_next_day, working_hours: s.working_hours, allowed_late_start_minutes: s.allowed_late_start_minutes || 0, allowed_early_end_minutes: s.allowed_early_end_minutes || 0 }));
            const { error } = await supabase.from('hr_special_shift_weekday_slots').insert(payloads);
            if (error) throw error;
        }
    }

    async function saveDateWiseShift() {
        if (isRangeMode && modalDateFrom && modalDateTo) {
            const start = new Date(modalDateFrom); const end = new Date(modalDateTo);
            if (start > end) { showError('Start date cannot be after end date'); return; }
            const dates: string[] = []; let dt = new Date(start);
            while (dt <= end) { dates.push(dt.toISOString().split('T')[0]); dt.setDate(dt.getDate() + 1); }
            for (const date of dates) {
                const { data: ver, error: verErr } = await supabase.from('hr_special_shift_date_wise_versions').insert({ employee_id: selectedEmployeeId, date_from: date, date_to: date }).select('id').single();
                if (verErr) throw verErr;
                const payloads = modalSlots.map((s, i) => ({ version_id: ver.id, slot_order: i + 1, shift_start_time: s.shift_start_time, shift_start_buffer: s.shift_start_buffer, shift_end_time: s.shift_end_time, shift_end_buffer: s.shift_end_buffer, is_shift_overlapping_next_day: s.is_shift_overlapping_next_day, working_hours: s.working_hours, allowed_late_start_minutes: s.allowed_late_start_minutes || 0, allowed_early_end_minutes: s.allowed_early_end_minutes || 0 }));
                const { error } = await supabase.from('hr_special_shift_date_wise_slots').insert(payloads);
                if (error) throw error;
            }
            showSuccess(`Date-wise shifts assigned for ${dates.length} days!`);
        } else if (editingVersionId) {
            await supabase.from('hr_special_shift_date_wise_slots').delete().eq('version_id', editingVersionId);
            await supabase.from('hr_special_shift_date_wise_versions').update({ date_from: modalDateFrom, date_to: modalDateTo }).eq('id', editingVersionId);
            const payloads = modalSlots.map((s, i) => ({ version_id: editingVersionId, slot_order: i + 1, shift_start_time: s.shift_start_time, shift_start_buffer: s.shift_start_buffer, shift_end_time: s.shift_end_time, shift_end_buffer: s.shift_end_buffer, is_shift_overlapping_next_day: s.is_shift_overlapping_next_day, working_hours: s.working_hours, allowed_late_start_minutes: s.allowed_late_start_minutes || 0, allowed_early_end_minutes: s.allowed_early_end_minutes || 0 }));
            const { error } = await supabase.from('hr_special_shift_date_wise_slots').insert(payloads);
            if (error) throw error;
        } else {
            const { data: ver, error: verErr } = await supabase.from('hr_special_shift_date_wise_versions').insert({ employee_id: selectedEmployeeId, date_from: modalDateFrom, date_to: modalDateTo || modalDateFrom }).select('id').single();
            if (verErr) throw verErr;
            const payloads = modalSlots.map((s, i) => ({ version_id: ver.id, slot_order: i + 1, shift_start_time: s.shift_start_time, shift_start_buffer: s.shift_start_buffer, shift_end_time: s.shift_end_time, shift_end_buffer: s.shift_end_buffer, is_shift_overlapping_next_day: s.is_shift_overlapping_next_day, working_hours: s.working_hours, allowed_late_start_minutes: s.allowed_late_start_minutes || 0, allowed_early_end_minutes: s.allowed_early_end_minutes || 0 }));
            const { error } = await supabase.from('hr_special_shift_date_wise_slots').insert(payloads);
            if (error) throw error;
        }
    }

    // ---- DELETE ----

    async function deleteVersion(versionId: number, table: 'regular' | 'weekday' | 'date') {
        try {
            await initSupabase();
            const tbl = table === 'regular' ? 'hr_regular_shift_versions' : table === 'weekday' ? 'hr_special_shift_weekday_versions' : 'hr_special_shift_date_wise_versions';
            const { error } = await supabase.from(tbl).delete().eq('id', versionId);
            if (error) throw error;
            showSuccess($t('hr.shift.success_deleted') || 'Shift deleted');
            await refreshCurrentTab();
        } catch (err: any) { console.error('Error deleting shift:', err); showError(($t('hr.shift.error_failed_delete') || 'Failed to delete: ') + err.message); }
    }

    async function deleteGroupedDateWise(versionIds: number[]) {
        try {
            await initSupabase();
            const { error } = await supabase.from('hr_special_shift_date_wise_versions').delete().in('id', versionIds);
            if (error) throw error;
            showSuccess($t('hr.shift.success_deleted') || 'Shifts deleted');
            await refreshCurrentTab();
        } catch (err: any) { console.error('Error deleting grouped shifts:', err); showError(($t('hr.shift.error_failed_delete') || 'Failed to delete: ') + err.message); }
    }

    $: filteredEmployeesForSelect = (() => {
        if (!allEmployees.length) return [];
        const q = employeeSearchQuery.toLowerCase().trim();
        if (!q) return allEmployees;
        return allEmployees.filter(e => e.id.toLowerCase().includes(q) || e.employee_name_en.toLowerCase().includes(q) || e.employee_name_ar.toLowerCase().includes(q) || e.branch_name_en.toLowerCase().includes(q));
    })();

    function openEmployeeSelect(range: boolean) { isRangeMode = range; employeeSearchQuery = ''; showEmployeeSelectModal = true; }

    function openDeletePicker(row: RegularRow) {
        deletePickerEmployee = row;
        deletePickerChecked = {};
        for (const v of row.allVersions) deletePickerChecked[v.version_id] = false;
        showDeletePickerModal = true;
    }

    function isVersionActive(v: ShiftVersion): boolean {
        const today = new Date().toISOString().split('T')[0];
        return (!v.date_from || today >= v.date_from) && (!v.date_to || today <= v.date_to);
    }

    async function deleteSelectedVersions() {
        const idsToDelete = Object.entries(deletePickerChecked).filter(([, checked]) => checked).map(([id]) => Number(id));
        if (idsToDelete.length === 0) return;
        isDeletingVersions = true;
        try {
            await initSupabase();
            const { error } = await supabase.from('hr_regular_shift_versions').delete().in('id', idsToDelete);
            if (error) throw error;
            showDeletePickerModal = false;
            deletePickerEmployee = null;
            showSuccess($locale === 'ar' ? 'تم حذف الوردية' : 'Shift(s) deleted');
            await refreshCurrentTab();
        } catch (err: any) {
            showError(($t('hr.shift.error_failed_delete') || 'Delete failed: ') + err.message);
        } finally { isDeletingVersions = false; }
    }

    function formatDateDisplay(dateStr: string): string {
        if (!dateStr) return '';
        const parts = dateStr.split('-');
        if (parts.length === 3 && parts[0].length === 4) {
            const date = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
            const dayName = date.toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US', { weekday: 'short' });
            return `${dayName} ${parts[2]}-${parts[1]}-${parts[0]}`;
        }
        return dateStr;
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Tab Bar -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm">
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button
                    class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-300 rounded-xl
                    {activeTab === tab.id ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                    on:click={() => handleTabChange(tab.id)}
                >
                    <span class="text-base">{tab.icon}</span>
                    <span>{tab.label}</span>
                </button>
            {/each}
        </div>
    </div>

    <!-- Content Area -->
    <div class="flex-1 min-h-0 p-6 overflow-y-auto">
        {#if loading}
            <div class="flex items-center justify-center h-full">
                <div class="text-center">
                    <div class="animate-spin inline-block w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                    <p class="mt-4 text-slate-600 font-semibold">{$t('common.loading') || 'Loading...'}</p>
                </div>
            </div>
        {:else if error}
            <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                <button class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition" on:click={refreshCurrentTab}>{$t('common.retry') || 'Retry'}</button>
            </div>
        {:else}
            <!-- Filters -->
            <div class="mb-4 flex gap-3 flex-wrap">
                <div class="flex-1 min-w-[150px]">
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.shift.filter_branch')}</label>
                    <select bind:value={branchFilter} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" style="color:#000!important;background:#fff!important;">
                        <option value="">{$t('hr.shift.all_branches')}</option>
                        {#each availableBranches as branch}
                            <option value={branch.id}>{$locale === 'ar' ? `${branch.name_ar || branch.name_en}${branch.location_ar ? ' (' + branch.location_ar + ')' : ''}` : `${branch.name_en || 'Unnamed'}${branch.location_en ? ' (' + branch.location_en + ')' : ''}`}</option>
                        {/each}
                    </select>
                </div>
                <div class="flex-1 min-w-[150px]">
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.shift.filter_nationality')}</label>
                    <select bind:value={nationalityFilter} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" style="color:#000!important;background:#fff!important;">
                        <option value="">{$t('hr.shift.all_nationalities')}</option>
                        {#each availableNationalities as nat}
                            <option value={nat.id}>{$locale === 'ar' ? (nat.name_ar || nat.name_en) : (nat.name_en || 'Unnamed')}</option>
                        {/each}
                    </select>
                </div>
                <div class="flex-1 min-w-[150px]">
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('employeeFiles.employmentStatus')}</label>
                    <select bind:value={statusFilter} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" style="color:#000!important;background:#fff!important;">
                        <option value="">{$t('hr.shift.all_statuses') || 'All Statuses'}</option>
                        {#each availableEmploymentStatuses as s}
                            <option value={s.id}>{statusDisplay(s.id).text}</option>
                        {/each}
                    </select>
                </div>
                <div class="flex-1 min-w-[150px]">
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.shift.search_employee')}</label>
                    <input type="text" bind:value={searchQuery} placeholder={$t('hr.shift.search_placeholder')} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                </div>
                {#if activeTab === 'date'}
                    <div class="flex-1 min-w-[130px]">
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.shift.start_date') || 'Start Date'}</label>
                        <input type="date" bind:value={dateFilterStart} on:change={loadDateWise} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                    </div>
                    <div class="flex-1 min-w-[130px]">
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.shift.end_date') || 'End Date'}</label>
                        <input type="date" bind:value={dateFilterEnd} on:change={loadDateWise} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                    </div>
                {/if}
            </div>

            {#if activeTab === 'weekday'}
                <div class="mb-4"><button class="px-5 py-2.5 bg-emerald-600 text-white rounded-xl text-sm font-bold hover:bg-emerald-700 transition shadow-lg" on:click={() => openEmployeeSelect(false)}>➕ {$t('hr.shift.add_special_shift') || 'Add Weekday Shift'}</button></div>
            {:else if activeTab === 'date'}
                <div class="mb-4 flex gap-3">
                    <button class="px-5 py-2.5 bg-emerald-600 text-white rounded-xl text-sm font-bold hover:bg-emerald-700 transition shadow-lg" on:click={() => openEmployeeSelect(false)}>➕ {$t('hr.shift.add_special_shift_date') || 'Add Single Date Shift'}</button>
                    <button class="px-5 py-2.5 bg-orange-600 text-white rounded-xl text-sm font-bold hover:bg-orange-700 transition shadow-lg" on:click={() => openEmployeeSelect(true)}>📅 {$t('hr.shift.add_special_range') || 'Add Date Range'}</button>
                </div>
            {/if}

            <!-- ===================== REGULAR SHIFTS TABLE ===================== -->
            {#if activeTab === 'regular'}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                    <div class="overflow-x-auto flex-1">
                        <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                            <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                <tr>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase">{$t('hr.fullName')}</th>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase">{$t('hr.branch')}</th>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase">{$t('hr.nationality')}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$locale === 'ar' ? 'تاريخ السريان' : 'Effective Date'}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('hr.shift.start')}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('hr.shift.end')}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('hr.shift.working_hours')}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('common.action')}</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-200">
                                {#each filteredRegular as row, index}
                                    {@const slot = row.slots[0]}
                                    <tr class="hover:bg-emerald-50/30 transition-colors {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                        <td class="px-4 py-3 text-sm text-slate-700"><div>{empName(row)}</div><div class="text-xs text-slate-400">{row.employee_id}</div></td>
                                        <td class="px-4 py-3 text-sm text-slate-700">{branchDisplay(row)}</td>
                                        <td class="px-4 py-3 text-sm text-slate-700"><div>{natName(row)}</div><div class="text-xs text-slate-400">{sponsorDisplay(row.sponsorship_status).text}</div></td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            <div class="text-slate-800 font-semibold">{formatDateDisplay(row.date_from || '')}</div>
                                            <div class="text-xs text-slate-400">{row.date_to ? formatDateDisplay(row.date_to) : ($locale === 'ar' ? 'مفتوح' : 'Open-ended')}</div>
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center font-mono">
                                            {#if row.slots.length > 1}
                                                {#each row.slots as s, si}
                                                    <div class="{si > 0 ? 'mt-1 pt-1 border-t border-slate-200' : ''}">
                                                        <span class="text-[10px] bg-purple-100 text-purple-700 px-1 rounded">Slot {si+1}</span>
                                                        <div class="text-slate-800">{fmt12(s.shift_start_time)}</div>
                                                        <div class="text-xs text-slate-400">{$t('hr.shift.start_buffer')}: {s.shift_start_buffer || 0}h</div>
                                                    </div>
                                                {/each}
                                            {:else}
                                                <div class="text-slate-800">{fmt12(slot?.shift_start_time)}</div>
                                                <div class="text-xs text-slate-400">{$t('hr.shift.start_buffer')}: {slot?.shift_start_buffer || 0}h</div>
                                            {/if}
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center font-mono">
                                            {#if row.slots.length > 1}
                                                {#each row.slots as s, si}
                                                    <div class="{si > 0 ? 'mt-1 pt-1 border-t border-slate-200' : ''}">
                                                        <span class="text-[10px] bg-purple-100 text-purple-700 px-1 rounded">Slot {si+1}</span>
                                                        <div class="text-slate-800">{fmt12(s.shift_end_time)}</div>
                                                        <div class="text-xs text-slate-400">{$t('hr.shift.end_buffer')}: {s.shift_end_buffer || 0}h</div>
                                                    </div>
                                                {/each}
                                            {:else}
                                                <div class="text-slate-800">{fmt12(slot?.shift_end_time)}</div>
                                                <div class="text-xs text-slate-400">{$t('hr.shift.end_buffer')}: {slot?.shift_end_buffer || 0}h</div>
                                            {/if}
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            {#if row.slots.length > 1}
                                                {#each row.slots as s, si}
                                                    <div class="{si > 0 ? 'mt-1 pt-1 border-t border-slate-200' : ''}"><div class="font-bold text-emerald-700">{s.working_hours?.toFixed(2) || '—'}h</div></div>
                                                {/each}
                                                <div class="mt-1 pt-1 border-t border-emerald-300 font-black text-emerald-800">Σ {row.slots.reduce((sum, sl) => sum + (sl.working_hours || 0), 0).toFixed(2)}h</div>
                                            {:else}
                                                <div class="font-bold text-emerald-700">{slot?.working_hours ? slot.working_hours.toFixed(2) : '—'} {$t('common.hrs')}</div>
                                                <div class="text-xs mt-0.5"><span class="inline-block px-2 py-0.5 rounded-full text-[10px] font-black {slot?.is_shift_overlapping_next_day ? 'bg-orange-200 text-orange-800' : 'bg-slate-200 text-slate-800'}">{$t('hr.shift.overlaps')}: {slot?.is_shift_overlapping_next_day ? $t('common.yes') : $t('common.no')}</span></div>
                                            {/if}
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            {#if slot}
                                                <div class="flex gap-1 justify-center">
                                                    <button class="px-3 py-2 rounded-lg bg-orange-600 text-white text-xs font-bold hover:bg-orange-700 transition" on:click={() => openRegularModal(row)}>🔄 {$locale === 'ar' ? 'تغيير' : 'Change'}</button>
                                                    <button class="px-3 py-2 rounded-lg bg-red-500 text-white text-xs font-bold hover:bg-red-600 transition" on:click={() => openDeletePicker(row)}>🗑</button>
                                                </div>
                                            {:else}
                                                <button class="w-8 h-8 rounded-lg bg-emerald-600 text-white font-bold hover:bg-emerald-700 transition" on:click={() => openRegularModal(row)}>+</button>
                                            {/if}
                                        </td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    </div>
                    <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">{$t('hr.shift.showing_employees', { count: filteredRegular.length })}</div>
                </div>

            <!-- ===================== WEEKDAY SHIFTS TABLE ===================== -->
            {:else if activeTab === 'weekday'}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                    <div class="overflow-x-auto flex-1">
                        <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                            <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                <tr>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase">{$t('hr.fullName')}</th>
                                    {#each activeWeekdays as day}
                                        <th class="px-3 py-3 text-center text-xs font-black uppercase">{day.name}</th>
                                    {/each}
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('common.action')}</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-200">
                                {#each filteredWeekday as row, index}
                                    {#if Object.values(row.weekdaySlots).some(v => v != null)}
                                        <tr class="hover:bg-emerald-50/30 transition-colors {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm text-slate-700"><div>{empName(row)}</div><div class="text-xs text-slate-400">{row.employee_id}</div></td>
                                            {#each activeWeekdays as day}
                                                {@const entry = row.weekdaySlots[day.index]}
                                                <td class="px-3 py-3 text-center text-xs">
                                                    {#if entry}
                                                        {@const s = entry.slots[0]}
                                                        <div class="text-slate-700 font-mono">{fmt12(s?.shift_start_time)}</div>
                                                        <div class="text-slate-500 font-mono">{fmt12(s?.shift_end_time)}</div>
                                                        <div class="text-emerald-700 font-bold">{s?.working_hours?.toFixed(1) || '—'}h</div>
                                                        {#if entry.slots.length > 1}<span class="text-[9px] bg-purple-100 text-purple-700 px-1 rounded">{entry.slots.length} slots</span>{/if}
                                                        <div class="mt-1 flex gap-1 justify-center">
                                                            <button class="px-1.5 py-0.5 rounded bg-orange-500 text-white text-[10px] font-bold hover:bg-orange-600" on:click={() => openWeekdayModal(row, day.index)}>🔄</button>
                                                            <button class="px-1.5 py-0.5 rounded bg-red-400 text-white text-[10px] font-bold hover:bg-red-500" on:click={() => { if (confirm($t('hr.shift.confirm_delete_shift') || 'Delete?')) deleteVersion(entry.version_id, 'weekday'); }}>🗑</button>
                                                        </div>
                                                    {:else}<span class="text-slate-300">—</span>{/if}
                                                </td>
                                            {/each}
                                            <td class="px-4 py-3 text-sm text-center">
                                                <button class="px-3 py-1.5 rounded-lg bg-orange-600 text-white text-xs font-bold hover:bg-orange-700 transition" on:click={() => openWeekdayModal(row)}>🔄 {$locale === 'ar' ? 'تغيير' : 'Change'}</button>
                                            </td>
                                        </tr>
                                    {/if}
                                {/each}
                            </tbody>
                        </table>
                    </div>
                    <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">{$t('hr.shift.showing_employees', { count: filteredWeekday.filter(r => Object.values(r.weekdaySlots).some(v => v != null)).length })}</div>
                </div>

            <!-- ===================== DATE-WISE SHIFTS TABLE ===================== -->
            {:else if activeTab === 'date'}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                    <div class="overflow-x-auto flex-1">
                        <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                            <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                <tr>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase">{$t('hr.fullName')}</th>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase">{$t('hr.branch')}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('hr.shift.shift_date') || 'Date'}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('hr.shift.start')}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('hr.shift.end')}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('hr.shift.working_hours')}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase">{$t('common.action')}</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-200">
                                {#each filteredDateWise as row, index}
                                    {@const slot = row.slots[0]}
                                    <tr class="hover:bg-emerald-50/30 transition-colors {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                        <td class="px-4 py-3 text-sm text-slate-700"><div>{empName(row)}</div><div class="text-xs text-slate-400">{row.employee_id}</div></td>
                                        <td class="px-4 py-3 text-sm text-slate-700">{branchDisplay(row)}</td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            {#if row._grouped}
                                                <span class="px-2 py-1 bg-orange-100 text-orange-800 rounded-full text-xs font-bold">{row._dayCount} days</span>
                                                <div class="text-xs text-slate-500 mt-1">{formatDateDisplay(row._dateFrom || '')} → {formatDateDisplay(row._dateTo || '')}</div>
                                            {:else}<div>{formatDateDisplay(row.date_from)}</div>{/if}
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center font-mono">
                                            <div class="text-slate-800">{fmt12(slot?.shift_start_time)}</div>
                                            <div class="text-xs text-slate-400">{$t('hr.shift.start_buffer')}: {slot?.shift_start_buffer || 0}h</div>
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center font-mono">
                                            <div class="text-slate-800">{fmt12(slot?.shift_end_time)}</div>
                                            <div class="text-xs text-slate-400">{$t('hr.shift.end_buffer')}: {slot?.shift_end_buffer || 0}h</div>
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center"><div class="font-bold text-emerald-700">{slot?.working_hours ? slot.working_hours.toFixed(2) : '—'} {$t('common.hrs')}</div></td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            {#if row._grouped && row._allVersionIds}
                                                <button class="px-3 py-1.5 rounded-lg bg-red-600 text-white text-xs font-bold hover:bg-red-700 transition" on:click={() => { if (confirm($t('hr.shift.confirm_delete_shift') || 'Delete all?')) deleteGroupedDateWise(row._allVersionIds || []); }}>🗑 {$t('common.delete')} ({row._dayCount})</button>
                                            {:else}
                                                <button class="px-3 py-1.5 rounded-lg bg-red-500 text-white text-xs font-bold hover:bg-red-600 transition" on:click={() => { if (confirm($t('hr.shift.confirm_delete_shift') || 'Delete?')) deleteVersion(row.version_id, 'date'); }}>🗑 {$t('common.delete')}</button>
                                            {/if}
                                        </td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    </div>
                    <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">{$t('hr.shift.showing_employees', { count: filteredDateWise.length })} {$t('common.records') || 'records'}</div>
                </div>
            {/if}
        {/if}
    </div>
</div>

<!-- Notification -->
{#if showNotification}
    <div class="fixed top-4 right-4 z-[999] px-6 py-4 rounded-2xl shadow-2xl text-white font-bold text-sm {notificationType === 'success' ? 'bg-emerald-600' : 'bg-red-600'}">
        {notificationType === 'success' ? '✅' : '❌'} {notificationMessage}
    </div>
{/if}

<!-- Employee Select Modal -->
{#if showEmployeeSelectModal}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50">
        <div class="bg-white rounded-3xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden">
            <div class="bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-4">
                <h3 class="text-xl font-black text-white">{$t('hr.shift.select_employee') || 'Select Employee'}</h3>
                <p class="text-emerald-100 text-sm mt-1">{isRangeMode ? ($t('hr.shift.add_special_range') || 'Date Range Mode') : ($t('hr.shift.add_special_shift_date') || 'Single Date Mode')}</p>
            </div>
            <div class="p-4">
                <input type="text" bind:value={employeeSearchQuery} placeholder={$t('hr.shift.search_placeholder') || 'Search...'} class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                <div class="max-h-80 overflow-y-auto space-y-1">
                    {#each filteredEmployeesForSelect as emp}
                        <button class="w-full text-left px-4 py-3 rounded-xl hover:bg-emerald-50 transition flex justify-between items-center" on:click={() => openDateWiseAddModal(emp)}>
                            <div>
                                <div class="font-semibold text-sm">{$locale === 'ar' ? emp.employee_name_ar : emp.employee_name_en}</div>
                                <div class="text-xs text-slate-400">{emp.id} · {$locale === 'ar' ? emp.branch_name_ar : emp.branch_name_en}</div>
                            </div>
                            <span class="text-emerald-600 text-xl">→</span>
                        </button>
                    {/each}
                </div>
            </div>
            <div class="px-6 py-3 bg-slate-50 border-t flex justify-end">
                <button class="px-4 py-2 text-sm font-bold text-slate-600 hover:text-slate-800" on:click={() => showEmployeeSelectModal = false}>{$t('common.cancel') || 'Cancel'}</button>
            </div>
        </div>
    </div>
{/if}

<!-- Delete Version Picker Modal -->
{#if showDeletePickerModal && deletePickerEmployee}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50">
        <div class="bg-white rounded-3xl shadow-2xl max-w-md w-full mx-4 overflow-hidden">
            <div class="bg-gradient-to-r from-red-600 to-red-500 px-6 py-4">
                <h3 class="text-xl font-black text-white">{$locale === 'ar' ? 'حذف وردية' : 'Delete Shift'}</h3>
                <p class="text-red-100 text-sm mt-1">{empName(deletePickerEmployee)} ({deletePickerEmployee.employee_id})</p>
            </div>
            <div class="p-6 space-y-3 max-h-[60vh] overflow-y-auto">
                {#if deletePickerEmployee.allVersions.length === 0}
                    <p class="text-slate-500 text-center">{$locale === 'ar' ? 'لا توجد ورديات' : 'No shift versions found'}</p>
                {:else}
                    <p class="text-sm text-slate-600 mb-3">{$locale === 'ar' ? 'اختر الورديات المراد حذفها:' : 'Select shift version(s) to delete:'}</p>
                    {#each deletePickerEmployee.allVersions as v}
                        {@const active = isVersionActive(v)}
                        {@const s = v.slots[0]}
                        <label class="flex items-start gap-3 p-3 rounded-xl border-2 cursor-pointer transition-all {deletePickerChecked[v.version_id] ? 'border-red-400 bg-red-50' : 'border-slate-200 hover:border-slate-300'}">
                            <input type="checkbox" bind:checked={deletePickerChecked[v.version_id]} class="w-5 h-5 mt-0.5 rounded" />
                            <div class="flex-1">
                                <div class="flex items-center gap-2">
                                    <span class="text-xs font-black px-2 py-0.5 rounded-full {active ? 'bg-green-100 text-green-800' : 'bg-slate-200 text-slate-600'}">{active ? ($locale === 'ar' ? 'نشط' : 'Active') : ($locale === 'ar' ? 'غير نشط' : 'Inactive')}</span>
                                </div>
                                <div class="text-sm text-slate-700 mt-1">
                                    <span class="font-semibold">{formatDateDisplay(v.date_from)}</span>
                                    <span class="text-slate-400 mx-1">→</span>
                                    <span class="font-semibold">{v.date_to ? formatDateDisplay(v.date_to) : ($locale === 'ar' ? 'مفتوح' : 'Open-ended')}</span>
                                </div>
                                {#if s}
                                    <div class="text-xs text-slate-500 mt-1">
                                        {fmt12(s.shift_start_time)} - {fmt12(s.shift_end_time)} · {s.working_hours?.toFixed(1)}h
                                        {#if v.slots.length > 1}<span class="text-purple-600 font-bold"> ({v.slots.length} slots)</span>{/if}
                                    </div>
                                {/if}
                            </div>
                        </label>
                    {/each}
                {/if}
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t flex justify-between items-center">
                <span class="text-xs text-slate-400">{Object.values(deletePickerChecked).filter(Boolean).length} {$locale === 'ar' ? 'محدد' : 'selected'}</span>
                <div class="flex gap-3">
                    <button class="px-5 py-2.5 text-sm font-bold text-slate-600 hover:text-slate-800 rounded-xl hover:bg-slate-200 transition" on:click={() => showDeletePickerModal = false}>{$t('common.cancel') || 'Cancel'}</button>
                    <button class="px-5 py-2.5 bg-red-600 text-white rounded-xl text-sm font-bold hover:bg-red-700 transition shadow-lg disabled:opacity-50"
                        disabled={isDeletingVersions || !Object.values(deletePickerChecked).some(Boolean)}
                        on:click={deleteSelectedVersions}>
                        {#if isDeletingVersions}<span class="animate-spin inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full mr-2"></span>{/if}
                        🗑 {$locale === 'ar' ? 'حذف المحدد' : 'Delete Selected'}
                    </button>
                </div>
            </div>
        </div>
    </div>
{/if}

<!-- Shift Form Modal -->
{#if showModal}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50">
        <div class="bg-white rounded-3xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden">
            <div class="bg-gradient-to-r from-emerald-600 to-emerald-500 px-6 py-4">
                <h3 class="text-xl font-black text-white">
                    {activeTab === 'regular' ? ($t('hr.shift.configure_regular_shift') || 'Configure Regular Shift') : activeTab === 'weekday' ? ($t('hr.shift.configure_special_shift_weekday') || 'Configure Weekday Shift') : ($t('hr.shift.configure_special_shift_date') || 'Configure Date-Wise Shift')}
                </h3>
                <p class="text-emerald-100 text-sm mt-1">{$t('hr.employeeId')}: {selectedEmployeeId}</p>
            </div>
            <div class="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
                {#if activeTab === 'regular' || activeTab === 'weekday'}
                    <div class="grid grid-cols-2 gap-3">
                        <div>
                            <label class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.start_date') || 'Effective From'}</label>
                            <input type="date" bind:value={modalDateFrom} class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                        </div>
                        <div>
                            <label class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.end_date') || 'Effective To'}</label>
                            <input type="date" bind:value={modalDateTo} class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                            <p class="text-xs text-slate-400 mt-1">{$locale === 'ar' ? 'اتركه فارغاً إذا كان مفتوحاً' : 'Leave empty if open-ended'}</p>
                        </div>
                    </div>
                {/if}
                {#if activeTab === 'weekday'}
                    <div>
                        <label class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.select_weekday')}</label>
                        <select bind:value={modalWeekday} class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500" style="color:#000!important;background:#fff!important;">
                            {#each weekdayNames as day, i}<option value={i}>{day}</option>{/each}
                        </select>
                    </div>
                {/if}
                {#if activeTab === 'date'}
                    {#if isRangeMode}
                        <div class="grid grid-cols-2 gap-3">
                            <div><label class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.start_date') || 'Start Date'}</label><input type="date" bind:value={modalDateFrom} class="w-full px-3 py-2 border border-slate-300 rounded-lg" /></div>
                            <div><label class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.end_date') || 'End Date'}</label><input type="date" bind:value={modalDateTo} class="w-full px-3 py-2 border border-slate-300 rounded-lg" /></div>
                        </div>
                    {:else}
                        <div><label class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.shift_date') || 'Date'}</label><input type="date" bind:value={modalDateFrom} class="w-full px-3 py-2 border border-slate-300 rounded-lg" /></div>
                    {/if}
                {/if}

                {#each modalSlots as slot, si}
                    <div class="border border-slate-200 rounded-xl p-4 {modalSlots.length > 1 ? 'bg-purple-50/50' : ''}">
                        {#if modalSlots.length > 1}
                            <div class="flex justify-between items-center mb-3">
                                <span class="text-xs font-black text-purple-700 uppercase">Slot {si + 1}</span>
                                <button class="text-red-500 hover:text-red-700 text-xs font-bold" on:click={() => removeSlot(si)}>✕ Remove</button>
                            </div>
                        {/if}
                        <div class="mb-3">
                            <label class="block text-sm font-bold text-slate-700 mb-1">{$t('hr.shift.shift_start_time')}</label>
                            <div class="flex gap-2">
                                <select bind:value={slotTime12[si].startHour} on:change={() => updateSlotStartTime(si)} class="flex-1 px-2 py-2 border border-slate-300 rounded-lg">
                                    {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}<option value={h}>{h}</option>{/each}
                                </select>
                                <select bind:value={slotTime12[si].startMinute} on:change={() => updateSlotStartTime(si)} class="flex-1 px-2 py-2 border border-slate-300 rounded-lg">
                                    {#each Array.from({length: 60}, (_, i) => String(i).padStart(2, '0')) as m}<option value={m}>{m}</option>{/each}
                                </select>
                                <select bind:value={slotTime12[si].startPeriod} on:change={() => updateSlotStartTime(si)} class="w-20 px-2 py-2 border border-slate-300 rounded-lg">
                                    <option value="AM">{$t('common.am') || 'AM'}</option><option value="PM">{$t('common.pm') || 'PM'}</option>
                                </select>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="block text-sm font-bold text-slate-700 mb-1">{$t('hr.shift.start_buffer_hours')}</label>
                            <input type="number" bind:value={slot.shift_start_buffer} step="0.5" min="0" max="24" class="w-full px-3 py-2 border border-slate-300 rounded-lg" />
                        </div>
                        <div class="mb-3">
                            <label class="block text-sm font-bold text-slate-700 mb-1">{$locale === 'ar' ? 'التأخير المسموح (دقائق)' : 'Allowed Late Start (min)'}</label>
                            <input type="number" bind:value={slot.allowed_late_start_minutes} min="0" max="120" class="w-full px-3 py-2 border border-slate-300 rounded-lg" placeholder="0" />
                        </div>
                        <div class="mb-3">
                            <label class="block text-sm font-bold text-slate-700 mb-1">{$t('hr.shift.shift_end_time')}</label>
                            <div class="flex gap-2">
                                <select bind:value={slotTime12[si].endHour} on:change={() => updateSlotEndTime(si)} class="flex-1 px-2 py-2 border border-slate-300 rounded-lg">
                                    {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}<option value={h}>{h}</option>{/each}
                                </select>
                                <select bind:value={slotTime12[si].endMinute} on:change={() => updateSlotEndTime(si)} class="flex-1 px-2 py-2 border border-slate-300 rounded-lg">
                                    {#each Array.from({length: 60}, (_, i) => String(i).padStart(2, '0')) as m}<option value={m}>{m}</option>{/each}
                                </select>
                                <select bind:value={slotTime12[si].endPeriod} on:change={() => updateSlotEndTime(si)} class="w-20 px-2 py-2 border border-slate-300 rounded-lg">
                                    <option value="AM">{$t('common.am') || 'AM'}</option><option value="PM">{$t('common.pm') || 'PM'}</option>
                                </select>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="block text-sm font-bold text-slate-700 mb-1">{$t('hr.shift.end_buffer_hours')}</label>
                            <input type="number" bind:value={slot.shift_end_buffer} step="0.5" min="0" max="24" class="w-full px-3 py-2 border border-slate-300 rounded-lg" />
                        </div>
                        <div class="mb-3">
                            <label class="block text-sm font-bold text-slate-700 mb-1">{$locale === 'ar' ? 'الانصراف المبكر المسموح (دقائق)' : 'Allowed Early End (min)'}</label>
                            <input type="number" bind:value={slot.allowed_early_end_minutes} min="0" max="120" class="w-full px-3 py-2 border border-slate-300 rounded-lg" placeholder="0" />
                        </div>
                        <div class="flex items-center gap-3">
                            <input type="checkbox" bind:checked={slot.is_shift_overlapping_next_day} on:change={() => recalcSlotHours(si)} class="w-5 h-5 rounded" id="overlap-{si}" />
                            <label for="overlap-{si}" class="text-sm font-semibold text-slate-700">{$t('hr.shift.overlaps_next_day')}</label>
                        </div>
                        <div class="mt-2 text-right text-sm font-bold text-emerald-700">{slot.working_hours?.toFixed(2) || '0.00'} {$t('common.hrs')}</div>
                    </div>
                {/each}

                {#if modalSlots.length < 4}
                    <button class="w-full py-2 border-2 border-dashed border-purple-300 rounded-xl text-purple-600 font-bold text-sm hover:bg-purple-50 transition" on:click={addSlot}>➕ Add Shift Slot (Multi-Shift)</button>
                {/if}
                {#if modalSlots.length > 1}
                    <div class="text-right font-black text-emerald-800">Total: {totalHours.toFixed(2)} {$t('common.hrs')}</div>
                {/if}
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t flex justify-end gap-3">
                <button class="px-5 py-2.5 text-sm font-bold text-slate-600 hover:text-slate-800 rounded-xl hover:bg-slate-200 transition" on:click={closeModal}>{$t('common.cancel') || 'Cancel'}</button>
                <button class="px-5 py-2.5 bg-emerald-600 text-white rounded-xl text-sm font-bold hover:bg-emerald-700 transition shadow-lg disabled:opacity-50" disabled={isSaving} on:click={saveShift}>
                    {#if isSaving}<span class="animate-spin inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full mr-2"></span>{/if}
                    {$t('common.save') || 'Save'}
                </button>
            </div>
        </div>
    </div>
{/if}
