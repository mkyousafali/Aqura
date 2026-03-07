<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { notificationService } from '$lib/utils/notificationManagement';
    import { get } from 'svelte/store';
    import LeaveRequestPrint from './LeaveRequestPrint.svelte';
    
    interface EmployeeShift {
        id: string;
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
        employment_status?: string;
        shift_start_time?: string;
        shift_start_buffer?: number;
        shift_end_time?: string;
        shift_end_buffer?: number;
        is_shift_overlapping_next_day?: boolean;
        working_hours?: number;
        shifts?: {[key: number]: any};
    }

    interface RegularShiftData {
        id: string;
        shift_start_time: string;
        shift_start_buffer: number;
        shift_end_time: string;
        shift_end_buffer: number;
        is_shift_overlapping_next_day: boolean;
    }

    interface SpecialShiftWeekdayData {
        id: string;
        employee_id: string;
        weekday: number;
        shift_start_time: string;
        shift_start_buffer: number;
        shift_end_time: string;
        shift_end_buffer: number;
        is_shift_overlapping_next_day: boolean;
    }

    interface SpecialShiftDateWiseData {
        id: string;
        employee_id: string;
        shift_date: string;
        shift_start_time: string;
        shift_start_buffer: number;
        shift_end_time: string;
        shift_end_buffer: number;
        is_shift_overlapping_next_day: boolean;
    }

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

    // Update deduction status for a day off
    async function updateDayOffDeduction(dayOffId: string, isDeductible: boolean) {
        try {
            const { error } = await supabase
                .from('day_off')
                .update({ is_deductible_on_salary: isDeductible })
                .eq('id', dayOffId);

            if (error) throw error;

            // Update local state
            dayOffs = dayOffs.map(d => 
                d.id === dayOffId ? { ...d, is_deductible_on_salary: isDeductible } : d
            );

            showSuccessNotification(
                isDeductible ? 
                    $t('hr.shift.deduction_enabled') : 
                    $t('hr.shift.deduction_disabled')
            );
        } catch (err: any) {
            console.error('Error updating deduction status:', err);
            showErrorNotification($t('hr.shift.deduction_update_error'));
        }
    }

    interface DayOffReason {
        id: string;
        reason_en: string;
        reason_ar: string;
        is_deductible: boolean;
        is_document_mandatory: boolean;
    }

    interface OfficialHoliday {
        id: string;
        holiday_date: string;
        name_en: string;
        name_ar: string;
        assigned_count?: number;
        assigned_employees?: string[];
    }

    let activeTab = 'Regular Shift';
    let employees: EmployeeShift[] = [];
    let employeesForDateWiseSelection: EmployeeForSelection[] = [];
    let allEmployeesForDateWise: EmployeeForSelection[] = [];
    let dateWiseShifts: (EmployeeShift & {shift_date?: string})[] = [];
    let dayOffs: (EmployeeShift & {day_off_date?: string, approval_status?: string, reason_en?: string, reason_ar?: string, is_deductible_on_salary?: boolean, approval_requested_at?: string, day_off_reason_id?: string, _grouped?: boolean, _allIds?: string[], _allDates?: string[], _dateFrom?: string, _dateTo?: string, _dayCount?: number})[] = [];
    let dayOffsWeekday: (EmployeeShift & {day_off_weekday?: number})[] = [];
    let dayOffReasons: DayOffReason[] = [];
    let officialHolidays: OfficialHoliday[] = [];
    let showOfficialHolidayModal = false;
    let editingOfficialHolidayId: string | null = null;
    let officialHolidayFormData: OfficialHoliday = { id: '', holiday_date: new Date().toISOString().split('T')[0], name_en: '', name_ar: '' };
    let officialHolidaySearchQuery = '';
    let showAssignEmployeesModal = false;
    let assigningHolidayId: string | null = null;
    let assigningHolidayName = '';
    let assignEmployeeSearchQuery = '';
    let assignAllEmployees: EmployeeForSelection[] = [];
    let assignFilteredEmployees: EmployeeForSelection[] = [];
    let assignSelectedEmployeeIds: Set<string> = new Set();
    let isAssignSaving = false;
    let loading = false;
    let error: string | null = null;
    let showModal = false;
    let showDeleteModal = false;
    let showEmployeeSelectModal = false;
    let showDayOffEmployeeSelectModal = false;
    let showDayOffWeekdayEmployeeSelectModal = false;
    let showReasonModal = false;
    let showReasonDeleteModal = false;
    let editingReasonId: string | null = null;
    let showReasonSearchModal = false;
    let selectedDayOffReason: DayOffReason | null = null;
    let reasonSearchQuery = '';
    let dayOffDescription: string = '';
    let documentFile: File | null = null;
    let existingDocumentUrl: string | null = null; // Track already-uploaded document when editing
    let documentUploadProgress = 0;
    let isUploadingDocument = false;
    let selectedEmployeeId: string | null = null;
    let selectedDeleteWeekday: number = 0;
    let selectedDayOffWeekday: number = 0;
    let isSaving = false;
    let employeeSearchQuery = '';
    let selectedDayOffDate: string = new Date().toISOString().split('T')[0];
    let selectedDayOffStartDate: string = new Date().toISOString().split('T')[0];
    let selectedDayOffEndDate: string = new Date().toISOString().split('T')[0];
    let isRangeSpecialShift = false;
    let specialShiftStartDate: string = new Date().toISOString().split('T')[0];
    let specialShiftEndDate: string = new Date().toISOString().split('T')[0];
    let regularShiftSearchQuery = '';
    let selectedBranchFilter = '';
    let selectedNationalityFilter = '';
    let selectedEmploymentStatusFilter = '';
    let specialWeekdaySearchQuery = '';
    let specialWeekdayBranchFilter = '';
    let specialWeekdayNationalityFilter = '';
    let specialWeekdayEmploymentStatusFilter = '';
    let specialDateSearchQuery = '';
    let specialDateBranchFilter = '';
    let specialDateNationalityFilter = '';
    let specialDateEmploymentStatusFilter = '';
    let dayOffSearchQuery = '';
    let dayOffBranchFilter = '';
    let dayOffNationalityFilter = '';
    let dayOffEmploymentStatusFilter = '';
    let dayOffApprovalStatusFilter = '';
    let dayOffWeekdaySearchQuery = '';
    let dayOffWeekdayBranchFilter = '';
    let dayOffWeekdayNationalityFilter = '';
    let dayOffWeekdayEmploymentStatusFilter = '';
    let specialDateFilterStart = '';
    let specialDateFilterEnd = '';
    let dayOffFilterStart = '';
    let dayOffFilterEnd = '';
    let availableBranches: Branch[] = [];
    let availableNationalities: Nationality[] = [];
    
    // Grouped day-off action modal state
    let showGroupedDeductionModal = false;
    let showGroupedDeleteModal = false;
    let groupedModalDayOff: any = null;
    let groupedCheckedDates: Record<string, boolean> = {};
    let groupedDeductionStates: Record<string, boolean> = {};
    let isGroupedProcessing = false;

    // Grouped Shift Delete state
    let showGroupedShiftDeleteModal = false;
    let groupedShiftModalData: any = null;
    let groupedShiftCheckedDates: Record<string, boolean> = {};
    let isGroupedShiftProcessing = false;

    // View Dates popup state
    let showViewDatesPopup = false;
    let viewDatesData: any = null;
    let viewDatesSearch = '';
    let viewDatesMonthFilter = '';
    let viewDatesYearFilter = '';

    // View Description popup state
    let showDescriptionPopup = false;
    let descriptionPopupText = '';
    let descriptionPopupEmployee = '';

    // Leave Request Print Dialog state
    let showLeaveRequestPrintDialog = false;
    let selectedDayOffForPrint: any = null;

    function openViewDatesPopup(dayOff: any) {
        viewDatesData = dayOff;
        viewDatesSearch = '';
        viewDatesMonthFilter = '';
        viewDatesYearFilter = '';
        showViewDatesPopup = true;
    }

    function openLeaveRequestPrint(dayOff: any) {
        selectedDayOffForPrint = dayOff;
        showLeaveRequestPrintDialog = true;
    }

    // Format date from yyyy-mm-dd to dd-mm-yyyy with full day name
    function formatDateDisplay(dateStr: string): string {
        if (!dateStr) return '';
        const parts = dateStr.split('-');
        if (parts.length === 3 && parts[0].length === 4) {
            const date = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
            const dayName = date.toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US', { weekday: 'long' });
            return `${dayName} ${parts[2]}-${parts[1]}-${parts[0]}`;
        }
        return dateStr;
    }

    // Smart date search: normalize input so "02122024" or "02-12-2024" matches "2024-12-02"
    function normalizeDateSearch(input: string): string {
        return input.replace(/[\-\/\.\s]/g, '');
    }

    function dateMatchesSearch(dateStr: string, search: string): boolean {
        if (!search.trim()) return true;
        const normalized = normalizeDateSearch(search);
        // Try matching against multiple date representations
        const d = dateStr; // format: YYYY-MM-DD
        const parts = d.split('-');
        if (parts.length !== 3) return d.includes(search);
        const [y, m, dd] = parts;
        // Build candidate strings the user might type
        const candidates = [
            `${dd}${m}${y}`,    // DDMMYYYY  e.g. 02122024
            `${m}${dd}${y}`,    // MMDDYYYY
            `${y}${m}${dd}`,    // YYYYMMDD
            `${dd}-${m}-${y}`,  // DD-MM-YYYY
            `${m}-${dd}-${y}`,  // MM-DD-YYYY
            `${y}-${m}-${dd}`,  // YYYY-MM-DD
            `${dd}/${m}/${y}`,  // DD/MM/YYYY
            `${m}/${dd}/${y}`,  // MM/DD/YYYY
            d,                  // original
        ];
        return candidates.some(c => normalizeDateSearch(c).includes(normalized) || normalized.includes(normalizeDateSearch(c)));
    }

    $: viewDatesFiltered = (() => {
        if (!viewDatesData) return [];
        const allDates: string[] = viewDatesData._allDates || [viewDatesData.day_off_date || viewDatesData.shift_date];
        return allDates.filter(dateStr => {
            if (!dateStr) return false;
            // Month/Year filter
            if (viewDatesMonthFilter || viewDatesYearFilter) {
                const parts = dateStr.split('-');
                if (parts.length === 3) {
                    if (viewDatesYearFilter && parts[0] !== viewDatesYearFilter) return false;
                    if (viewDatesMonthFilter && parts[1] !== viewDatesMonthFilter) return false;
                }
            }
            // Search filter
            if (viewDatesSearch.trim()) {
                return dateMatchesSearch(dateStr, viewDatesSearch);
            }
            return true;
        });
    })();

    $: viewDatesAvailableYears = (() => {
        if (!viewDatesData) return [];
        const allDates: string[] = viewDatesData._allDates || [viewDatesData.day_off_date || viewDatesData.shift_date];
        const years = new Set(allDates.map(d => d?.split('-')[0]).filter(Boolean));
        return [...years].sort();
    })();

    $: viewDatesAvailableMonths = (() => {
        if (!viewDatesData) return [];
        const allDates: string[] = viewDatesData._allDates || [viewDatesData.day_off_date || viewDatesData.shift_date];
        const months = new Set(allDates.map(d => d?.split('-')[1]).filter(Boolean));
        return [...months].sort();
    })();

    const monthNames: Record<string, { en: string, ar: string }> = {
        '01': { en: 'Jan', ar: 'يناير' }, '02': { en: 'Feb', ar: 'فبراير' }, '03': { en: 'Mar', ar: 'مارس' },
        '04': { en: 'Apr', ar: 'أبريل' }, '05': { en: 'May', ar: 'مايو' }, '06': { en: 'Jun', ar: 'يونيو' },
        '07': { en: 'Jul', ar: 'يوليو' }, '08': { en: 'Aug', ar: 'أغسطس' }, '09': { en: 'Sep', ar: 'سبتمبر' },
        '10': { en: 'Oct', ar: 'أكتوبر' }, '11': { en: 'Nov', ar: 'نوفمبر' }, '12': { en: 'Dec', ar: 'ديسمبر' }
    };

    // Notification state
    let showNotification = false;
    let notificationMessage = '';
    let notificationType: 'success' | 'error' | 'warning' = 'success';
    let notificationTimeout: NodeJS.Timeout | null = null;
    
    // Alert modal state
    let showAlertModal = false;
    let alertMessage = '';
    let alertTitle = 'Alert';
    
    // 12-hour format UI state
    let startHour12 = '09';
    let startMinute12 = '00';
    let startPeriod12 = 'AM';
    let endHour12 = '05';
    let endMinute12 = '00';
    let endPeriod12 = 'PM';

    function updateStartTime24h() {
        let h = parseInt(startHour12);
        if (startPeriod12 === 'PM' && h < 12) h += 12;
        if (startPeriod12 === 'AM' && h === 12) h = 0;
        if (formData) (formData as any).shift_start_time = `${String(h).padStart(2, '0')}:${startMinute12}`;
    }

    function updateEndTime24h() {
        let h = parseInt(endHour12);
        if (endPeriod12 === 'PM' && h < 12) h += 12;
        if (endPeriod12 === 'AM' && h === 12) h = 0;
        if (formData) (formData as any).shift_end_time = `${String(h).padStart(2, '0')}:${endMinute12}`;
    }

    function syncTimeTo12h() {
        if (formData) {
            if ((formData as any).shift_start_time) {
                const [h, m] = (formData as any).shift_start_time.split(':').map(Number);
                startPeriod12 = h >= 12 ? 'PM' : 'AM';
                startHour12 = String(h % 12 || 12).padStart(2, '0');
                startMinute12 = String(m || 0).padStart(2, '0');
            }
            if ((formData as any).shift_end_time) {
                const [h, m] = (formData as any).shift_end_time.split(':').map(Number);
                endPeriod12 = h >= 12 ? 'PM' : 'AM';
                endHour12 = String(h % 12 || 12).padStart(2, '0');
                endMinute12 = String(m || 0).padStart(2, '0');
            }
        }
    }

    function showSuccessNotification(message: string) {
        notificationMessage = message;
        notificationType = 'success';
        showNotification = true;
        
        if (notificationTimeout) clearTimeout(notificationTimeout);
        notificationTimeout = setTimeout(() => {
            showNotification = false;
        }, 3000);
    }

    function showErrorNotification(message: string) {
        notificationMessage = message;
        notificationType = 'error';
        showNotification = true;
        
        if (notificationTimeout) clearTimeout(notificationTimeout);
        notificationTimeout = setTimeout(() => {
            showNotification = false;
        }, 4000);
    }

    function openAlertModal(message: string, title: string = $t('common.alert')) {
        alertMessage = message;
        alertTitle = title;
        showAlertModal = true;
    }

    function closeAlertModal() {
        showAlertModal = false;
    }

    // Form data for Leave reason modal
    let reasonFormData: DayOffReason = {
        id: '',
        reason_en: '',
        reason_ar: '',
        is_deductible: false,
        is_document_mandatory: false
    };

    $: if (showModal) {
        syncTimeTo12h();
    }

    $: filteredRegularEmployees = getFilteredEmployees(employees, selectedBranchFilter, selectedNationalityFilter, selectedEmploymentStatusFilter, regularShiftSearchQuery);
    $: filteredSpecialWeekdayEmployees = getFilteredSpecialWeekdayEmployees(employees, specialWeekdayBranchFilter, specialWeekdayNationalityFilter, specialWeekdayEmploymentStatusFilter, specialWeekdaySearchQuery);
    $: groupedSpecialDateShifts = groupSpecialShiftDateWise(dateWiseShifts);
    $: filteredSpecialDateEmployees = getFilteredSpecialDateShifts(groupedSpecialDateShifts, specialDateBranchFilter, specialDateNationalityFilter, specialDateEmploymentStatusFilter, specialDateSearchQuery);
    $: groupedDayOffs = groupDayOffRequests(dayOffs);
    $: filteredDayOffsEmployees = getFilteredDayOffs(groupedDayOffs, dayOffBranchFilter, dayOffNationalityFilter, dayOffEmploymentStatusFilter, dayOffSearchQuery, dayOffApprovalStatusFilter);
    $: filteredDayOffsWeekdayEmployees = getFilteredDayOffsWeekday(dayOffsWeekday, dayOffWeekdayBranchFilter, dayOffWeekdayNationalityFilter, dayOffWeekdayEmploymentStatusFilter, dayOffWeekdaySearchQuery);

    $: availableEmploymentStatuses = [
        { id: 'Job (With Finger)', label: $t('employeeFiles.statuses.jobWithFinger') },
        { id: 'Job (No Finger)', label: $t('employeeFiles.statuses.jobNoFinger') },
        { id: 'Remote Job', label: $t('employeeFiles.statuses.remoteJob') },
        { id: 'Vacation', label: $t('employeeFiles.statuses.vacation') },
        { id: 'Resigned', label: $t('employeeFiles.statuses.resigned') },
        { id: 'Terminated', label: $t('employeeFiles.statuses.terminated') },
        { id: 'Run Away', label: $t('employeeFiles.statuses.escape') }
    ];
    
    let supabase: any;
    let realtimeChannel: any;

    $: weekdayNames = [
        $t('common.days.sunday'),
        $t('common.days.monday'),
        $t('common.days.tuesday'),
        $t('common.days.wednesday'),
        $t('common.days.thursday'),
        $t('common.days.friday'),
        $t('common.days.saturday')
    ];

    // Only show weekday columns that have at least one employee with a shift
    $: activeWeekdays = (() => {
        const days: {index: number, name: string}[] = [];
        for (let i = 0; i < 7; i++) {
            const hasShift = filteredSpecialWeekdayEmployees.some(emp => emp.shifts?.[i] != null);
            if (hasShift) {
                days.push({ index: i, name: weekdayNames[i] });
            }
        }
        return days;
    })();

    // Reload data when tab changes
    $: if (supabase && activeTab) {
        (async () => {
            await refreshCurrentTabData();
        })();
    }

    // Form data for modal
    let formData: RegularShiftData | SpecialShiftWeekdayData | SpecialShiftDateWiseData = {
        id: '',
        shift_start_time: '09:00',
        shift_start_buffer: 3,
        shift_end_time: '17:00',
        shift_end_buffer: 3,
        is_shift_overlapping_next_day: false
    } as RegularShiftData;

    $: tabs = [
        { id: 'Regular Shift', label: $t('hr.shift.tabs.regular'), icon: '🕒', color: 'green' },
        { id: 'Special Shift (weekday-wise)', label: $t('hr.shift.tabs.special_weekday'), icon: '📅', color: 'orange' },
        { id: 'Special Shift (date-wise)', label: $t('hr.shift.tabs.special_date'), icon: '📆', color: 'orange' },
        { id: 'Multi-Shift Setup', label: $t('hr.shift.multiShift.setup_title'), icon: '🔀', color: 'purple' },
        { id: 'Leave (date-wise)', label: $t('hr.shift.tabs.day_off_date'), icon: '🏖️', color: 'green' },
        { id: 'Leave (weekday-wise)', label: $t('hr.shift.tabs.day_off_weekday'), icon: '📋', color: 'green' },
        { id: 'Leave Reasons', label: $t('hr.shift.tabs.day_off_reasons'), icon: '📌', color: 'blue' },
        { id: 'Official Holidays', label: $t('hr.shift.tabs.official_holidays'), icon: '🏛️', color: 'blue' }
    ];

    // Reactive statement to handle tab changes
    $: if (activeTab) {
        refreshCurrentTabData();
    }

    onMount(async () => {
        const { supabase: client } = await import('$lib/utils/supabase');
        supabase = client;
        
        setupRealtime();

        if (activeTab === 'Regular Shift') {
            await loadEmployeeShiftData();
        } else if (activeTab === 'Special Shift (weekday-wise)') {
            await loadSpecialShiftWeekdayData();
        } else if (activeTab === 'Special Shift (date-wise)') {
            const dateRange = getDefaultDateRange();
            specialDateFilterStart = dateRange.start;
            specialDateFilterEnd = dateRange.end;
            await loadSpecialShiftDateWiseData();
        } else if (activeTab === 'Leave (date-wise)') {
            const dateRange = getDefaultDateRange();
            dayOffFilterStart = dateRange.start;
            dayOffFilterEnd = dateRange.end;
            await loadDayOffData();
        } else if (activeTab === 'Leave (weekday-wise)') {
            await loadDayOffWeekdayData();
        } else if (activeTab === 'Leave Reasons') {
            await loadDayOffReasons();
        } else if (activeTab === 'Official Holidays') {
            await loadOfficialHolidays();
        }
    });

    onDestroy(() => {
        if (realtimeChannel && supabase) {
            supabase.removeChannel(realtimeChannel);
        }
    });

    function setupRealtime() {
        if (!supabase) return;

        realtimeChannel = supabase.channel('shift-and-day-off-realtime')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'hr_employee_master' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'regular_shift' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'special_shift_weekday' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'special_shift_date_wise' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'day_off' }, async (payload: any) => {
                console.log('🔄 Real-time day_off change detected:', payload);
                // Only reload if we're on the Leave tab to ensure immediate updates
                if (activeTab === 'Leave (date-wise)') {
                    await loadDayOffData();
                    console.log('✅ Leave data reloaded from real-time event');
                } else if (activeTab === 'Leave (weekday-wise)') {
                    await loadDayOffWeekdayData();
                } else {
                    await refreshCurrentTabData();
                }
            })
            .on('postgres_changes', { event: '*', schema: 'public', table: 'day_off_weekday' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'day_off_reasons' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'branches' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'nationalities' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'official_holidays' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'employee_official_holidays' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'multi_shift_regular' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'multi_shift_date_wise' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'multi_shift_weekday' }, () => refreshCurrentTabData())
            .subscribe();
    }

    async function refreshCurrentTabData() {
        if (activeTab === 'Regular Shift') {
            await loadEmployeeShiftData();
        } else if (activeTab === 'Special Shift (weekday-wise)') {
            await loadSpecialShiftWeekdayData();
        } else if (activeTab === 'Special Shift (date-wise)') {
            const dateRange = getDefaultDateRange();
            specialDateFilterStart = dateRange.start;
            specialDateFilterEnd = dateRange.end;
            await loadSpecialShiftDateWiseData();
        } else if (activeTab === 'Leave (date-wise)') {
            const dateRange = getDefaultDateRange();
            dayOffFilterStart = dateRange.start;
            dayOffFilterEnd = dateRange.end;
            await loadDayOffData();
        } else if (activeTab === 'Leave (weekday-wise)') {
            await loadDayOffWeekdayData();
        } else if (activeTab === 'Leave Reasons') {
            await loadDayOffReasons();
        } else if (activeTab === 'Official Holidays') {
            await loadOfficialHolidays();
        } else if (activeTab === 'Multi-Shift Setup') {
            await loadMultiShiftData();
        }
    }

    async function initSupabase() {
        if (!supabase) {
            const { supabase: client } = await import('$lib/utils/supabase');
            supabase = client;
        }
    }

    async function loadEmployeeShiftData() {
        loading = true;
        error = null;
        try {
            await initSupabase();
            
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id,
                    employment_status,
                    sponsorship_status
                `);

            if (empError) throw empError;

            if (!employeeData || employeeData.length === 0) {
                employees = [];
                loading = false;
                return;
            }

            // Get branch information
            const branchIds = [...new Set(employeeData.map(e => e.current_branch_id).filter(Boolean))];
            const { data: branches, error: branchError } = await supabase
                .from('branches')
                .select('id, name_en, name_ar, location_en, location_ar')
                .in('id', branchIds);

            if (branchError) throw branchError;

            // Get nationality information
            const nationalityIds = [...new Set(employeeData.map(e => e.nationality_id).filter(Boolean))];
            const { data: nationalities, error: natError } = await supabase
                .from('nationalities')
                .select('id, name_en, name_ar')
                .in('id', nationalityIds);

            if (natError) throw natError;

            // Get regular shift data
            const { data: shifts, error: shiftError } = await supabase
                .from('regular_shift')
                .select('*');

            if (shiftError && shiftError.code !== 'PGRST116') throw shiftError; // 404 is OK

            const branchMap = new Map<string, Branch>((branches as Branch[] | null)?.map(b => [String(b.id), b]) || []);
            const nationalityMap = new Map<string, Nationality>((nationalities as Nationality[] | null)?.map(n => [String(n.id), n]) || []);
            const shiftMap = new Map<string, any>((shifts as any[] | null)?.map(s => [String(s.id), s]) || []);

            // Populate available branches for filter
            availableBranches = (branches as Branch[] | null) || [];
            availableNationalities = (nationalities as Nationality[] | null) || [];

            // Combine data
            employees = (employeeData as EmployeeMaster[]).map(emp => {
                const branch = branchMap.get(String(emp.current_branch_id));
                const nationality = nationalityMap.get(String(emp.nationality_id));
                const shift = shiftMap.get(String(emp.id));

                return {
                    id: emp.id,
                    employee_id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_id: emp.current_branch_id,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A',
                    branch_location_en: branch?.location_en || '',
                    branch_location_ar: branch?.location_ar || '',
                    nationality_id: emp.nationality_id,
                    nationality_name_en: nationality?.name_en || 'N/A',
                    nationality_name_ar: nationality?.name_ar || 'N/A',
                    sponsorship_status: emp.sponsorship_status,
                    employment_status: emp.employment_status,
                    shift_start_time: shift?.shift_start_time,
                    shift_start_buffer: shift?.shift_start_buffer,
                    shift_end_time: shift?.shift_end_time,
                    shift_end_buffer: shift?.shift_end_buffer,
                    is_shift_overlapping_next_day: shift?.is_shift_overlapping_next_day,
                    working_hours: shift?.working_hours
                };
            });
            
            // Sort and create new array reference for Svelte reactivity
            employees = [...sortEmployees(employees)];
        } catch (err) {
            console.error('Error loading employee shift data:', err);
            error = err instanceof Error ? err.message : $t('hr.shift.error_failed_load');
        } finally {
            loading = false;
        }
    }

    async function loadSpecialShiftWeekdayData() {
        loading = true;
        error = null;
        try {
            await initSupabase();
            
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id,
                    employment_status,
                    sponsorship_status
                `);

            if (empError) throw empError;

            if (!employeeData || employeeData.length === 0) {
                employees = [];
                loading = false;
                return;
            }

            // Get branch information
            const branchIds = [...new Set(employeeData.map(e => e.current_branch_id).filter(Boolean))];
            const { data: branches, error: branchError } = await supabase
                .from('branches')
                .select('id, name_en, name_ar, location_en, location_ar')
                .in('id', branchIds);

            if (branchError) throw branchError;

            // Get nationality information
            const nationalityIds = [...new Set(employeeData.map(e => e.nationality_id).filter(Boolean))];
            const { data: nationalities, error: natError } = await supabase
                .from('nationalities')
                .select('id, name_en, name_ar')
                .in('id', nationalityIds);

            if (natError) throw natError;

            // Get special shift weekday data
            const { data: shifts, error: shiftError } = await supabase
                .from('special_shift_weekday')
                .select('*');

            if (shiftError && shiftError.code !== 'PGRST116') throw shiftError; // 404 is OK

            const branchMap = new Map<string, Branch>((branches as Branch[] | null)?.map(b => [String(b.id), b]) || []);
            const nationalityMap = new Map<string, Nationality>((nationalities as Nationality[] | null)?.map(n => [String(n.id), n]) || []);

            // Populate available branches and nationalities for filter
            availableBranches = (branches as Branch[] | null) || [];
            availableNationalities = (nationalities as Nationality[] | null) || [];

            // Group shifts by employee_id and weekday
            const shiftMap = new Map<string, Map<number, any>>();
            (shifts as any[] | null)?.forEach(shift => {
                const empId = String(shift.employee_id);
                if (!shiftMap.has(empId)) {
                    shiftMap.set(empId, new Map());
                }
                shiftMap.get(empId)!.set(shift.weekday, shift);
            });

            // Combine data
            employees = (employeeData as EmployeeMaster[]).map(emp => {
                const empId = String(emp.id);
                const branch = branchMap.get(String(emp.current_branch_id));
                const nationality = nationalityMap.get(String(emp.nationality_id));
                const empShifts = shiftMap.get(empId) || new Map();

                const shiftsObj: {[key: number]: any} = {};
                Array.from({length: 7}, (_, i) => i).forEach(dayNum => {
                    shiftsObj[dayNum] = empShifts.get(dayNum) || null;
                });

                return {
                    id: emp.id,
                    employee_id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_id: emp.current_branch_id,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A',
                    branch_location_en: branch?.location_en || '',
                    branch_location_ar: branch?.location_ar || '',
                    nationality_id: emp.nationality_id,
                    nationality_name_en: nationality?.name_en || 'N/A',
                    nationality_name_ar: nationality?.name_ar || 'N/A',
                    sponsorship_status: emp.sponsorship_status,
                    employment_status: emp.employment_status,
                    shifts: shiftsObj
                };
            });
            
            employees = [...sortEmployees(employees)];
        } catch (err) {
            console.error('Error loading employee special shift data:', err);
            error = err instanceof Error ? err.message : $t('hr.shift.error_failed_load');
        } finally {
            loading = false;
        }
    }

    async function loadSpecialShiftDateWiseData() {
        loading = true;
        error = null;
        try {
            await initSupabase();
            
            // Get all employees for selection
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id,
                    employment_status,
                    sponsorship_status
                `);

            if (empError) throw empError;

            if (!employeeData || employeeData.length === 0) {
                allEmployeesForDateWise = [];
                dateWiseShifts = [];
                loading = false;
                return;
            }

            // Get branch information
            const branchIds = [...new Set(employeeData.map(e => e.current_branch_id).filter(Boolean))];
            const { data: branches, error: branchError } = await supabase
                .from('branches')
                .select('id, name_en, name_ar, location_en, location_ar')
                .in('id', branchIds);

            if (branchError) throw branchError;

            const branchMap = new Map<string, Branch>((branches as Branch[] | null)?.map(b => [String(b.id), b]) || []);

            // Populate available branches for filter
            availableBranches = (branches as Branch[] | null) || [];

            // Build employee selection list
            allEmployeesForDateWise = (employeeData as EmployeeMaster[]).map(emp => {
                const branch = branchMap.get(String(emp.current_branch_id));
                return {
                    id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A'
                };
            });
            
            allEmployeesForDateWise = [...sortEmployees(allEmployeesForDateWise)];

            employeesForDateWiseSelection = [...allEmployeesForDateWise];

            // Get nationality information
            const nationalityIds = [...new Set((employeeData as EmployeeMaster[]).map(e => e.nationality_id).filter(Boolean))];
            let nationalities: Nationality[] = [];
            if (nationalityIds.length > 0) {
                const { data: nat, error: natError } = await supabase
                    .from('nationalities')
                    .select('id, name_en, name_ar')
                    .in('id', nationalityIds);
                if (natError) throw natError;
                nationalities = (nat as Nationality[]) || [];
            }

            const nationalityMap = new Map<string, Nationality>(nationalities.map(n => [String(n.id), n]) || []);

            // Populate available nationalities for filter
            availableNationalities = nationalities || [];

            // Get special shift date-wise data
            const { data: shifts, error: shiftError } = await supabase
                .from('special_shift_date_wise')
                .select('*')
                .gte('shift_date', specialDateFilterStart)
                .lte('shift_date', specialDateFilterEnd)
                .order('shift_date', { ascending: false });

            if (shiftError && shiftError.code !== 'PGRST116') throw shiftError; // 404 is OK

            // Map shifts with employee details
            dateWiseShifts = ((shifts as any[]) || []).map(shift => {
                const emp = (employeeData as EmployeeMaster[]).find(e => String(e.id) === String(shift.employee_id));
                const branch = emp ? branchMap.get(String(emp.current_branch_id)) : null;
                const nationality = emp ? nationalityMap.get(String(emp.nationality_id)) : null;

                return {
                    id: shift.id,
                    employee_id: shift.employee_id,
                    employee_name_en: emp?.name_en || 'N/A',
                    employee_name_ar: emp?.name_ar || 'N/A',
                    branch_id: emp?.current_branch_id,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A',
                    branch_location_en: branch?.location_en || '',
                    branch_location_ar: branch?.location_ar || '',
                    nationality_id: emp?.nationality_id,
                    nationality_name_en: nationality?.name_en || 'N/A',
                    nationality_name_ar: nationality?.name_ar || 'N/A',
                    sponsorship_status: emp?.sponsorship_status,
                    employment_status: emp?.employment_status,
                    shift_date: shift.shift_date,
                    shift_start_time: shift.shift_start_time,
                    shift_start_buffer: shift.shift_start_buffer,
                    shift_end_time: shift.shift_end_time,
                    shift_end_buffer: shift.shift_end_buffer,
                    is_shift_overlapping_next_day: shift.is_shift_overlapping_next_day,
                    working_hours: shift.working_hours
                };
            });
            
            dateWiseShifts = [...sortEmployees(dateWiseShifts)];
        } catch (err) {
            console.error('Error loading special shift date-wise data:', err);
            error = err instanceof Error ? err.message : $t('hr.shift.error_failed_load');
        } finally {
            loading = false;
        }
    }

    function openEmployeeSelectModal() {
        showEmployeeSelectModal = true;
        isRangeSpecialShift = false;
        employeeSearchQuery = '';
        employeesForDateWiseSelection = [...allEmployeesForDateWise];
    }

    function openSpecialShiftRangeModal() {
        showEmployeeSelectModal = true;
        isRangeSpecialShift = true;
        employeeSearchQuery = '';
        employeesForDateWiseSelection = [...allEmployeesForDateWise];
    }

    function closeEmployeeSelectModal() {
        showEmployeeSelectModal = false;
        employeeSearchQuery = '';
        selectedEmployeeId = null;
    }

    function selectEmployeeForDateWise(employeeId: string) {
        selectedEmployeeId = employeeId;
        showEmployeeSelectModal = false;
        
        const today = new Date().toISOString().split('T')[0];
        if (isRangeSpecialShift) {
            specialShiftStartDate = today;
            specialShiftEndDate = today;
        }

        (formData as SpecialShiftDateWiseData) = {
            id: `${employeeId}-${today}`,
            employee_id: employeeId,
            shift_date: today,
            shift_start_time: '09:00',
            shift_start_buffer: 3,
            shift_end_time: '17:00',
            shift_end_buffer: 3,
            is_shift_overlapping_next_day: false
        };

        showModal = true;
    }

    function filterEmployees(query: string) {
        if (!query.trim()) {
            employeesForDateWiseSelection = [...allEmployeesForDateWise];
            return;
        }

        const lowerQuery = query.toLowerCase();
        employeesForDateWiseSelection = allEmployeesForDateWise.filter(emp => 
            emp.employee_name_en.toLowerCase().includes(lowerQuery) ||
            emp.employee_name_ar.includes(query) ||
            emp.id.toLowerCase().includes(lowerQuery)
        );
    }

    async function loadDayOffData() {
        loading = true;
        error = null;
        try {
            await initSupabase();
            
            const t0 = performance.now();
            
            // Load employees, branches, and day offs ALL in parallel
            const [empResult, branchResult, rpcResult] = await Promise.all([
                supabase.from('hr_employee_master').select('id, name_en, name_ar, current_branch_id').order('name_en'),
                supabase.from('branches').select('id, name_en, name_ar, location_en, location_ar').eq('is_active', true),
                supabase.rpc('get_day_offs_with_details', {
                    p_date_from: dayOffFilterStart,
                    p_date_to: dayOffFilterEnd
                })
            ]);

            console.log(`⚡ All 3 queries completed in ${(performance.now() - t0).toFixed(0)}ms`);

            if (empResult.error) throw empResult.error;
            if (rpcResult.error) throw rpcResult.error;

            const employeeData = empResult.data || [];
            const dayOffData = (rpcResult.data || []) as any[];
            const branches = branchResult.data || [];

            // Build maps
            const branchMap = new Map<string, Branch>((branches as Branch[]).map(b => [String(b.id), b]));
            availableBranches = branches as Branch[];

            // Build employee selection list
            allEmployeesForDateWise = employeeData.map((emp: any) => {
                const branch = branchMap.get(String(emp.current_branch_id));
                return {
                    id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A'
                };
            });
            allEmployeesForDateWise = [...sortEmployees(allEmployeesForDateWise)];
            employeesForDateWiseSelection = [...allEmployeesForDateWise];

            // Populate available nationalities from RPC results
            const natMap = new Map<string, Nationality>();
            for (const d of dayOffData) {
                if (d.nationality_id && !natMap.has(String(d.nationality_id))) {
                    natMap.set(String(d.nationality_id), { id: d.nationality_id, name_en: d.nationality_name_en, name_ar: d.nationality_name_ar });
                }
            }
            availableNationalities = [...natMap.values()];

            // RPC already returns fully joined data — assign directly (no mapping needed)
            dayOffs = dayOffData;
            dayOffs = [...sortEmployees(dayOffs)];
            
            console.log(`⚡ Total loadDayOffData: ${(performance.now() - t0).toFixed(0)}ms, ${dayOffs.length} records`);
        } catch (err) {
            console.error('Error loading Leave data:', err);
            error = err instanceof Error ? err.message : $t('hr.shift.error_failed_load');
        } finally {
            loading = false;
        }
    }

    function openDayOffEmployeeSelectModal() {
        showDayOffEmployeeSelectModal = true;
        employeeSearchQuery = '';
        employeesForDateWiseSelection = [...allEmployeesForDateWise];
    }

    function closeDayOffEmployeeSelectModal() {
        showDayOffEmployeeSelectModal = false;
        employeeSearchQuery = '';
        selectedEmployeeId = null;
    }

    function selectEmployeeForDayOff(employeeId: string) {
        selectedEmployeeId = employeeId;
        showDayOffEmployeeSelectModal = false;
        const today = new Date().toISOString().split('T')[0];
        selectedDayOffStartDate = today;
        selectedDayOffEndDate = today;
        showModal = true;
    }

    async function loadDayOffWeekdayData() {
        loading = true;
        error = null;
        try {
            await initSupabase();
            
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id,
                    sponsorship_status,
                    employment_status
                `);

            if (empError) throw empError;

            if (!employeeData || employeeData.length === 0) {
                dayOffsWeekday = [];
                loading = false;
                return;
            }

            // Get branch information
            const branchIds = [...new Set(employeeData.map(e => e.current_branch_id).filter(Boolean))];
            const { data: branches, error: branchError } = await supabase
                .from('branches')
                .select('id, name_en, name_ar, location_en, location_ar')
                .in('id', branchIds);

            if (branchError) throw branchError;

            // Get nationality information
            const nationalityIds = [...new Set(employeeData.map(e => e.nationality_id).filter(Boolean))];
            const { data: nationalities, error: natError } = await supabase
                .from('nationalities')
                .select('id, name_en, name_ar')
                .in('id', nationalityIds);

            if (natError) throw natError;

            const branchMap = new Map<string, Branch>((branches as Branch[] | null)?.map(b => [String(b.id), b]) || []);
            const nationalityMap = new Map<string, Nationality>((nationalities as Nationality[] | null)?.map(n => [String(n.id), n]) || []);

            // Populate available branches and nationalities for filter
            availableBranches = (branches as Branch[] | null) || [];
            availableNationalities = (nationalities as Nationality[] | null) || [];

            // Build employee selection list
            allEmployeesForDateWise = (employeeData as EmployeeMaster[]).map(emp => {
                const branch = branchMap.get(String(emp.current_branch_id));
                return {
                    id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A'
                };
            });
            
            allEmployeesForDateWise = [...sortEmployees(allEmployeesForDateWise)];

            employeesForDateWiseSelection = [...allEmployeesForDateWise];

            // Get Leave weekday data
            const { data: dayOffWeekdayData, error: dayOffError } = await supabase
                .from('day_off_weekday')
                .select('*')
                .order('weekday', { ascending: true });

            if (dayOffError && dayOffError.code !== 'PGRST116') throw dayOffError;

            // Map Leaves with employee details
            dayOffsWeekday = ((dayOffWeekdayData as any[]) || []).map(dayOff => {
                const emp = (employeeData as EmployeeMaster[]).find(e => String(e.id) === String(dayOff.employee_id));
                const branch = emp ? branchMap.get(String(emp.current_branch_id)) : null;
                const nationality = emp ? nationalityMap.get(String(emp.nationality_id)) : null;

                return {
                    id: dayOff.id,
                    employee_id: dayOff.employee_id,
                    employee_name_en: emp?.name_en || 'N/A',
                    employee_name_ar: emp?.name_ar || 'N/A',
                    branch_id: emp?.current_branch_id,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A',
                    branch_location_en: branch?.location_en || '',
                    branch_location_ar: branch?.location_ar || '',
                    nationality_id: emp?.nationality_id,
                    nationality_name_en: nationality?.name_en || 'N/A',
                    nationality_name_ar: nationality?.name_ar || 'N/A',
                    sponsorship_status: emp?.sponsorship_status,
                    employment_status: emp?.employment_status,
                    day_off_weekday: dayOff.weekday
                };
            });
            
            dayOffsWeekday = [...sortEmployees(dayOffsWeekday)];
        } catch (err) {
            console.error('Error loading Leave weekday data:', err);
            error = err instanceof Error ? err.message : $t('hr.shift.error_failed_load');
        } finally {
            loading = false;
        }
    }

    function openDayOffWeekdayEmployeeSelectModal() {
        showDayOffWeekdayEmployeeSelectModal = true;
        employeeSearchQuery = '';
        employeesForDateWiseSelection = [...allEmployeesForDateWise];
    }

    function closeDayOffWeekdayEmployeeSelectModal() {
        showDayOffWeekdayEmployeeSelectModal = false;
        employeeSearchQuery = '';
        selectedEmployeeId = null;
    }

    function selectEmployeeForDayOffWeekday(employeeId: string) {
        selectedEmployeeId = employeeId;
        showDayOffWeekdayEmployeeSelectModal = false;
        selectedDayOffWeekday = 0;
        showModal = true;
    }

    function onEmployeeSearchChange() {
        // Filter employees based on search query
        if (activeTab === 'Special Shift (date-wise)') {
            const query = employeeSearchQuery.toLowerCase();
            employeesForDateWiseSelection = allEmployeesForDateWise.filter(emp =>
                emp.employee_name_en.toLowerCase().includes(query) ||
                emp.employee_name_ar?.toLowerCase().includes(query) ||
                emp.id.toLowerCase().includes(query) ||
                emp.branch_name_en.toLowerCase().includes(query)
            );
        } else if (activeTab === 'Leave (date-wise)' || activeTab === 'Leave (weekday-wise)') {
            const query = employeeSearchQuery.toLowerCase();
            employeesForDateWiseSelection = allEmployeesForDateWise.filter(emp =>
                emp.employee_name_en.toLowerCase().includes(query) ||
                emp.employee_name_ar?.toLowerCase().includes(query) ||
                emp.id.toLowerCase().includes(query) ||
                emp.branch_name_en.toLowerCase().includes(query)
            );
        }
    }

    function handleTabChange() {
        employees = [];
        dateWiseShifts = [];
        dayOffs = [];
        dayOffsWeekday = [];
        employeesForDateWiseSelection = [];
        regularShiftSearchQuery = '';
        selectedBranchFilter = '';
        selectedNationalityFilter = '';
        selectedEmploymentStatusFilter = '';
        specialWeekdaySearchQuery = '';
        specialWeekdayBranchFilter = '';
        specialWeekdayNationalityFilter = '';
        specialWeekdayEmploymentStatusFilter = '';
        specialDateSearchQuery = '';
        specialDateBranchFilter = '';
        specialDateNationalityFilter = '';
        specialDateEmploymentStatusFilter = '';
        dayOffSearchQuery = '';
        dayOffBranchFilter = '';
        dayOffNationalityFilter = '';
        dayOffEmploymentStatusFilter = '';
        dayOffWeekdaySearchQuery = '';
        dayOffWeekdayBranchFilter = '';
        dayOffWeekdayNationalityFilter = '';
        dayOffWeekdayEmploymentStatusFilter = '';
        showModal = false;
    }

    function getDefaultDateRange() {
        const today = new Date();
        const currentYear = today.getFullYear();
        const currentMonth = today.getMonth();
        
        // Start date: 25th of previous month
        const startDate = new Date(currentYear, currentMonth - 1, 25);
        
        // End date: 24th of current month
        const endDate = new Date(currentYear, currentMonth, 24);
        
        // Format as YYYY-MM-DD using local time
        const formatDate = (date: Date) => {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
        };
        
        return {
            start: formatDate(startDate),
            end: formatDate(endDate)
        };
    }

    function openModal(employeeId: string) {
        selectedEmployeeId = employeeId;
        
        if (activeTab === 'Regular Shift') {
            const employee = employees.find(e => e.id === employeeId);
            
            if (employee && employee.shift_start_time) {
                (formData as RegularShiftData) = {
                    id: employeeId,
                    shift_start_time: employee.shift_start_time,
                    shift_start_buffer: employee.shift_start_buffer ?? 3,
                    shift_end_time: employee.shift_end_time || '17:00',
                    shift_end_buffer: employee.shift_end_buffer ?? 3,
                    is_shift_overlapping_next_day: employee.is_shift_overlapping_next_day || false
                };
            } else {
                (formData as RegularShiftData) = {
                    id: employeeId,
                    shift_start_time: '09:00',
                    shift_start_buffer: 3,
                    shift_end_time: '17:00',
                    shift_end_buffer: 3,
                    is_shift_overlapping_next_day: false
                };
            }
        } else if (activeTab === 'Special Shift (weekday-wise)') {
            (formData as SpecialShiftWeekdayData) = {
                id: `${employeeId}-1`,
                employee_id: employeeId,
                weekday: 1,
                shift_start_time: '09:00',
                shift_start_buffer: 3,
                shift_end_time: '17:00',
                shift_end_buffer: 3,
                is_shift_overlapping_next_day: false
            };
        }
        
        showModal = true;
    }

    function closeModal() {
        showModal = false;
        selectedEmployeeId = null;
        selectedDayOffReason = null;
        dayOffDescription = '';
        documentFile = null;
        existingDocumentUrl = null;
    }

    function onWeekdayChange() {
        // Regenerate ID based on selected weekday (for Special Shift weekday-wise)
        if ('weekday' in formData && 'employee_id' in formData) {
            (formData as SpecialShiftWeekdayData).id = `${formData.employee_id}-${(formData as SpecialShiftWeekdayData).weekday}`;
        }
    }

    async function deleteShiftData(employeeId: string, weekdayNum: number) {
        if (!confirm($t('hr.shift.confirm_delete_shift_for', { day: weekdayNames[weekdayNum] }))) return;
        
        try {
            await initSupabase();
            const shiftId = `${employeeId}-${weekdayNum}`;
            
            const { error } = await supabase
                .from('special_shift_weekday')
                .delete()
                .eq('id', shiftId);

            if (error) throw error;

            // Update local data
            const employeeIndex = employees.findIndex(e => e.id === employeeId);
            if (employeeIndex !== -1) {
                employees[employeeIndex].shifts[weekdayNum] = null;
                employees = [...employees]; // Trigger reactivity
            }
        } catch (err) {
            console.error('Error deleting shift data:', err);
            alert($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        }
    }

    function openDeleteModal(employeeId: string) {
        selectedEmployeeId = employeeId;
        selectedDeleteWeekday = 0; // Default to Sunday
        showDeleteModal = true;
    }

    function closeDeleteModal() {
        showDeleteModal = false;
        selectedEmployeeId = null;
    }

    async function confirmDelete() {
        if (!selectedEmployeeId) return;
        
        try {
            await initSupabase();
            const shiftId = `${selectedEmployeeId}-${selectedDeleteWeekday}`;
            
            const { error } = await supabase
                .from('special_shift_weekday')
                .delete()
                .eq('id', shiftId);

            if (error) throw error;

            // Update local data
            const employeeIndex = employees.findIndex(e => e.id === selectedEmployeeId);
            if (employeeIndex !== -1) {
                employees[employeeIndex].shifts[selectedDeleteWeekday] = null;
                employees = [...employees]; // Trigger reactivity
            }

            closeDeleteModal();
        } catch (err) {
            console.error('Error deleting shift data:', err);
            alert($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        }
    }

    async function deleteSpecialShiftDateWise(shiftId: string, employeeId: string, shiftDate: string) {
        if (!confirm($t('hr.shift.confirm_delete_shift'))) return;

        try {
            await initSupabase();
            const { error } = await supabase
                .from('special_shift_date_wise')
                .delete()
                .eq('id', shiftId);

            if (error) throw error;

            // Update local data
            dateWiseShifts = dateWiseShifts.filter(s => !(s.employee_id === employeeId && s.shift_date === shiftDate));
        } catch (err) {
            console.error('Error deleting shift:', err);
            alert($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        }
    }

    async function saveDayOff() {
        if (!selectedEmployeeId || !selectedDayOffDate) {
            alert($t('hr.shift.error_select_employee_date'));
            return;
        }

        isSaving = true;
        try {
            await initSupabase();
            const dayOffId = `${selectedEmployeeId}-${selectedDayOffDate}`;

            const { error } = await supabase
                .from('day_off')
                .upsert({
                    id: dayOffId,
                    employee_id: selectedEmployeeId,
                    day_off_date: selectedDayOffDate,
                    updated_at: new Date().toISOString()
                }, {
                    onConflict: 'id'
                });

            if (error) throw error;

            // Update local data
            const dayOffIndex = dayOffs.findIndex(d => d.employee_id === selectedEmployeeId && d.day_off_date === selectedDayOffDate);
            if (dayOffIndex === -1) {
                // Add new Leave
                const emp = allEmployeesForDateWise.find(e => e.id === selectedEmployeeId);
                if (emp) {
                    dayOffs = [{
                        id: dayOffId,
                        employee_id: selectedEmployeeId,
                        employee_name_en: emp.employee_name_en,
                        employee_name_ar: emp.employee_name_ar,
                        branch_id: '',
                        branch_name_en: emp.branch_name_en,
                        branch_name_ar: emp.branch_name_ar,
                        branch_location_en: '',
                        branch_location_ar: '',
                        nationality_id: '',
                        nationality_name_en: 'N/A',
                        nationality_name_ar: 'N/A',
                        day_off_date: selectedDayOffDate
                    }, ...dayOffs];
                }
            }

            showModal = false;
            selectedEmployeeId = null;
        } catch (err) {
            console.error('Error saving Leave:', err);
            alert($t('hr.shift.error_failed_save_day_off') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        } finally {
            isSaving = false;
        }
    }

    async function deleteDayOff(dayOffId: string, employeeId: string, dayOffDate: string) {
        if (!confirm($t('hr.shift.confirm_delete_day_off'))) return;

        try {
            await initSupabase();
            const { error } = await supabase
                .from('day_off')
                .delete()
                .eq('id', dayOffId);

            if (error) throw error;

            // Update local data
            dayOffs = dayOffs.filter(d => !(d.employee_id === employeeId && d.day_off_date === dayOffDate));
        } catch (err) {
            console.error('Error deleting Leave:', err);
            alert($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        }
    }

    // Delete all day off records in a grouped leave request
    async function deleteGroupedDayOff(allIds: string[], employeeId: string, dayCount: number) {
        const confirmMsg = dayCount > 1 
            ? `${$t('hr.shift.confirm_delete_day_off')} (${dayCount} ${$locale === 'ar' ? 'أيام' : 'days'})`
            : $t('hr.shift.confirm_delete_day_off');
        if (!confirm(confirmMsg)) return;

        try {
            await initSupabase();
            const { error } = await supabase
                .from('day_off')
                .delete()
                .in('id', allIds);

            if (error) throw error;

            // Update local data - remove all records with matching IDs
            const idSet = new Set(allIds);
            dayOffs = dayOffs.filter(d => !idSet.has(d.id));
        } catch (err) {
            console.error('Error deleting grouped Leave:', err);
            alert($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        }
    }

    // Open grouped deduction modal — shows all dates with checkboxes for deduction status
    function openGroupedDeductionModal(dayOff: any) {
        groupedModalDayOff = dayOff;
        groupedDeductionStates = {};
        const allDeductions = dayOff._allDeductions || [{ id: dayOff.id, date: dayOff.day_off_date, is_deductible: dayOff.is_deductible_on_salary || false }];
        for (const item of allDeductions) {
            groupedDeductionStates[item.id] = item.is_deductible;
        }
        showGroupedDeductionModal = true;
    }

    // Confirm grouped deduction update
    async function confirmGroupedDeduction() {
        if (!groupedModalDayOff || isGroupedProcessing) return;
        try {
            isGroupedProcessing = true;
            await initSupabase();

            const allDeductions = groupedModalDayOff._allDeductions || [{ id: groupedModalDayOff.id, date: groupedModalDayOff.day_off_date, is_deductible: groupedModalDayOff.is_deductible_on_salary || false }];

            // Update each record's deduction status
            for (const item of allDeductions) {
                const newVal = groupedDeductionStates[item.id] || false;
                if (newVal !== item.is_deductible) {
                    const { error } = await supabase
                        .from('day_off')
                        .update({ is_deductible_on_salary: newVal })
                        .eq('id', item.id);
                    if (error) throw error;
                }
            }

            // Update local state
            dayOffs = dayOffs.map(d => {
                if (groupedDeductionStates.hasOwnProperty(d.id)) {
                    return { ...d, is_deductible_on_salary: groupedDeductionStates[d.id] || false };
                }
                return d;
            });

            showGroupedDeductionModal = false;
            groupedModalDayOff = null;
            showSuccessNotification($t('hr.shift.deduction_updated') || 'Deduction updated successfully');
        } catch (err) {
            console.error('Error updating grouped deduction:', err);
            showErrorNotification($t('hr.shift.deduction_update_error') || 'Failed to update deduction');
        } finally {
            isGroupedProcessing = false;
        }
    }

    // Open grouped delete modal — shows all dates with checkboxes (all checked by default)
    function openGroupedDeleteModal(dayOff: any) {
        groupedModalDayOff = dayOff;
        groupedCheckedDates = {};
        const allIds = dayOff._allIds || [dayOff.id];
        for (const id of allIds) {
            groupedCheckedDates[id] = true; // all checked by default
        }
        showGroupedDeleteModal = true;
    }

    // Confirm grouped delete — only deletes checked dates
    async function confirmGroupedDelete() {
        if (!groupedModalDayOff || isGroupedProcessing) return;
        const idsToDelete = Object.entries(groupedCheckedDates).filter(([_, v]) => v).map(([id]) => id);
        if (idsToDelete.length === 0) return;

        try {
            isGroupedProcessing = true;
            await initSupabase();

            const { error } = await supabase
                .from('day_off')
                .delete()
                .in('id', idsToDelete);

            if (error) throw error;

            // Update local data
            const idSet = new Set(idsToDelete);
            dayOffs = dayOffs.filter(d => !idSet.has(d.id));

            showGroupedDeleteModal = false;
            groupedModalDayOff = null;
            showSuccessNotification(`${$locale === 'ar' ? 'تم حذف' : 'Deleted'} ${idsToDelete.length} ${$locale === 'ar' ? 'يوم/أيام' : 'day(s)'}`);
        } catch (err) {
            console.error('Error deleting selected days:', err);
            showErrorNotification($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        } finally {
            isGroupedProcessing = false;
        }
    }

    // Open grouped shift delete modal
    function openGroupedShiftDeleteModal(shift: any) {
        groupedShiftModalData = shift;
        groupedShiftCheckedDates = {};
        const allIds = shift._allIds || [shift.id];
        for (const id of allIds) {
            groupedShiftCheckedDates[id] = true;
        }
        showGroupedShiftDeleteModal = true;
    }

    // Confirm grouped shift delete
    async function confirmGroupedShiftDelete() {
        if (!groupedShiftModalData || isGroupedShiftProcessing) return;
        const idsToDelete = Object.entries(groupedShiftCheckedDates).filter(([_, v]) => v).map(([id]) => id);
        if (idsToDelete.length === 0) return;

        try {
            isGroupedShiftProcessing = true;
            await initSupabase();

            const { error } = await supabase
                .from('special_shift_date_wise')
                .delete()
                .in('id', idsToDelete);

            if (error) throw error;

            const idSet = new Set(idsToDelete);
            dateWiseShifts = dateWiseShifts.filter(s => !idSet.has(s.id));

            showGroupedShiftDeleteModal = false;
            groupedShiftModalData = null;
            showSuccessNotification(`${$locale === 'ar' ? 'تم حذف' : 'Deleted'} ${idsToDelete.length} ${$locale === 'ar' ? 'نوبة/نوبات' : 'shift(s)'}`);
        } catch (err) {
            console.error('Error deleting selected shifts:', err);
            showErrorNotification($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        } finally {
            isGroupedShiftProcessing = false;
        }
    }

    async function saveDayOffWeekday() {
        if (!selectedEmployeeId || selectedDayOffWeekday === null) {
            alert($t('hr.shift.error_select_employee_weekday'));
            return;
        }

        isSaving = true;
        try {
            await initSupabase();
            const dayOffId = `${selectedEmployeeId}-${selectedDayOffWeekday}`;

            const { error } = await supabase
                .from('day_off_weekday')
                .upsert({
                    id: dayOffId,
                    employee_id: selectedEmployeeId,
                    weekday: selectedDayOffWeekday,
                    updated_at: new Date().toISOString()
                }, {
                    onConflict: 'id'
                });

            if (error) throw error;

            // Update local data
            const dayOffIndex = dayOffsWeekday.findIndex(d => d.employee_id === selectedEmployeeId && d.day_off_weekday === selectedDayOffWeekday);
            if (dayOffIndex === -1) {
                // Add new Leave
                const emp = allEmployeesForDateWise.find(e => e.id === selectedEmployeeId);
                if (emp) {
                    dayOffsWeekday = [{
                        id: dayOffId,
                        employee_id: selectedEmployeeId,
                        employee_name_en: emp.employee_name_en,
                        employee_name_ar: emp.employee_name_ar,
                        branch_id: '',
                        branch_name_en: emp.branch_name_en,
                        branch_name_ar: emp.branch_name_ar,
                        branch_location_en: '',
                        branch_location_ar: '',
                        nationality_id: '',
                        nationality_name_en: 'N/A',
                        nationality_name_ar: 'N/A',
                        day_off_weekday: selectedDayOffWeekday
                    }, ...dayOffsWeekday];
                }
            }

            showModal = false;
            selectedEmployeeId = null;
        } catch (err) {
            console.error('Error saving Leave weekday:', err);
            alert($t('hr.shift.error_failed_save_day_off') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        } finally {
            isSaving = false;
        }
    }

    async function deleteDayOffWeekday(dayOffId: string, employeeId: string, weekday: number) {
        if (!confirm($t('hr.shift.confirm_delete_day_off'))) return;

        try {
            await initSupabase();
            const { error } = await supabase
                .from('day_off_weekday')
                .delete()
                .eq('id', dayOffId);

            if (error) throw error;

            // Update local data
            dayOffsWeekday = dayOffsWeekday.filter(d => !(d.employee_id === employeeId && d.day_off_weekday === weekday));
        } catch (err) {
            console.error('Error deleting Leave weekday:', err);
            alert($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        }
    }

    async function saveShiftData() {
        isSaving = true;
        try {
            await initSupabase();
            
            if (activeTab === 'Regular Shift') {
                // Calculate working hours from the popup form data
                const workingHours = calculateWorkingHours(
                    formData.shift_start_time,
                    formData.shift_end_time,
                    formData.is_shift_overlapping_next_day
                );
                
                const { error } = await supabase
                    .from('regular_shift')
                    .upsert({
                        id: formData.id,
                        shift_start_time: formData.shift_start_time,
                        shift_start_buffer: formData.shift_start_buffer,
                        shift_end_time: formData.shift_end_time,
                        shift_end_buffer: formData.shift_end_buffer,
                        is_shift_overlapping_next_day: formData.is_shift_overlapping_next_day,
                        working_hours: workingHours,
                        updated_at: new Date().toISOString()
                    }, {
                        onConflict: 'id'
                    });

                if (error) throw error;

                // Update local data
                const employeeIndex = employees.findIndex(e => e.id === formData.id);
                if (employeeIndex !== -1) {
                    employees[employeeIndex] = {
                        ...employees[employeeIndex],
                        shift_start_time: formData.shift_start_time,
                        shift_start_buffer: formData.shift_start_buffer,
                        shift_end_time: formData.shift_end_time,
                        shift_end_buffer: formData.shift_end_buffer,
                        is_shift_overlapping_next_day: formData.is_shift_overlapping_next_day,
                        working_hours: workingHours
                    };
                }
            } else if (activeTab === 'Special Shift (weekday-wise)') {
                const data = formData as SpecialShiftWeekdayData;
                
                // Calculate working hours
                const workingHours = calculateWorkingHours(
                    data.shift_start_time,
                    data.shift_end_time,
                    data.is_shift_overlapping_next_day
                );
                
                const { error } = await supabase
                    .from('special_shift_weekday')
                    .upsert({
                        id: data.id,
                        employee_id: data.employee_id,
                        weekday: data.weekday,
                        shift_start_time: data.shift_start_time,
                        shift_start_buffer: data.shift_start_buffer,
                        shift_end_time: data.shift_end_time,
                        shift_end_buffer: data.shift_end_buffer,
                        is_shift_overlapping_next_day: data.is_shift_overlapping_next_day,
                        working_hours: workingHours,
                        updated_at: new Date().toISOString()
                    }, {
                        onConflict: 'id'
                    });

                if (error) throw error;

                // Update local data
                const employeeIndex = employees.findIndex(e => e.id === data.employee_id);
                if (employeeIndex !== -1) {
                    employees[employeeIndex].shifts[data.weekday] = {
                        weekday: data.weekday,
                        shift_start_time: data.shift_start_time,
                        shift_start_buffer: data.shift_start_buffer,
                        shift_end_time: data.shift_end_time,
                        shift_end_buffer: data.shift_end_buffer,
                        is_shift_overlapping_next_day: data.is_shift_overlapping_next_day,
                        working_hours: workingHours
                    };
                }
            } else if (activeTab === 'Special Shift (date-wise)') {
                const data = formData as SpecialShiftDateWiseData;
                
                // Calculate working hours
                const workingHours = calculateWorkingHours(
                    data.shift_start_time,
                    data.shift_end_time,
                    data.is_shift_overlapping_next_day
                );
                
                if (isRangeSpecialShift) {
                    const start = new Date(specialShiftStartDate);
                    const end = new Date(specialShiftEndDate);
                    
                    if (start > end) {
                        showErrorNotification('Start date cannot be after end date');
                        isSaving = false;
                        return;
                    }

                    const dateArray: string[] = [];
                    let dt = new Date(start);
                    while (dt <= end) {
                        dateArray.push(new Date(dt).toISOString().split('T')[0]);
                        dt.setDate(dt.getDate() + 1);
                    }

                    const upsertData = dateArray.map(date => ({
                        id: `${data.employee_id}-${date}`,
                        employee_id: data.employee_id,
                        shift_date: date,
                        shift_start_time: data.shift_start_time,
                        shift_start_buffer: data.shift_start_buffer,
                        shift_end_time: data.shift_end_time,
                        shift_end_buffer: data.shift_end_buffer,
                        is_shift_overlapping_next_day: data.is_shift_overlapping_next_day,
                        working_hours: workingHours,
                        updated_at: new Date().toISOString()
                    }));

                    const { error } = await supabase
                        .from('special_shift_date_wise')
                        .upsert(upsertData, {
                            onConflict: 'id'
                        });

                    if (error) throw error;

                    await loadSpecialShiftDateWiseData();
                    showSuccessNotification(`Special shifts assigned for ${dateArray.length} days!`);
                } else {
                    // Update ID with date
                    const newId = `${data.employee_id}-${data.shift_date}`;
                    
                    const { error } = await supabase
                        .from('special_shift_date_wise')
                        .upsert({
                            id: newId,
                            employee_id: data.employee_id,
                            shift_date: data.shift_date,
                            shift_start_time: data.shift_start_time,
                            shift_start_buffer: data.shift_start_buffer,
                            shift_end_time: data.shift_end_time,
                            shift_end_buffer: data.shift_end_buffer,
                            is_shift_overlapping_next_day: data.is_shift_overlapping_next_day,
                            working_hours: workingHours,
                            updated_at: new Date().toISOString()
                        }, {
                            onConflict: 'id'
                        });

                    if (error) throw error;

                    // Update local data
                    const shiftIndex = dateWiseShifts.findIndex(s => s.employee_id === data.employee_id && s.shift_date === data.shift_date);
                    if (shiftIndex !== -1) {
                        dateWiseShifts[shiftIndex] = {
                            ...dateWiseShifts[shiftIndex],
                            shift_date: data.shift_date,
                            shift_start_time: data.shift_start_time,
                            shift_start_buffer: data.shift_start_buffer,
                            shift_end_time: data.shift_end_time,
                            shift_end_buffer: data.shift_end_buffer,
                            is_shift_overlapping_next_day: data.is_shift_overlapping_next_day,
                            working_hours: workingHours
                        };
                    } else {
                        // Add new shift entry
                        const emp = allEmployeesForDateWise.find(e => e.id === data.employee_id);
                        if (emp) {
                            dateWiseShifts = [{
                                id: newId,
                                employee_id: data.employee_id,
                                employee_name_en: emp.employee_name_en,
                                employee_name_ar: emp.employee_name_ar,
                                branch_id: '',
                                branch_name_en: emp.branch_name_en,
                                branch_name_ar: emp.branch_name_ar,
                                branch_location_en: '',
                                branch_location_ar: '',
                                nationality_id: '',
                                nationality_name_en: 'N/A',
                                nationality_name_ar: 'N/A',
                                shift_date: data.shift_date,
                                shift_start_time: data.shift_start_time,
                                shift_start_buffer: data.shift_start_buffer,
                                shift_end_time: data.shift_end_time,
                                shift_end_buffer: data.shift_end_buffer,
                                is_shift_overlapping_next_day: data.is_shift_overlapping_next_day,
                                working_hours: workingHours
                            }, ...dateWiseShifts];
                        }
                    }
                }
            }

            closeModal();
        } catch (err) {
            console.error('Error saving shift data:', err);
            alert($t('hr.shift.error_failed_save') + (err instanceof Error ? err.message : $t('common.unknown_error')));
        } finally {
            isSaving = false;
        }
    }

    function getEmploymentStatusDisplay(status: string | undefined): { color: string; text: string } {
        switch (status) {
            case 'Job (With Finger)':
                return { color: 'bg-green-100 text-green-800', text: $t('employeeFiles.inJob') || 'Job (With Finger)' };
            case 'Job (No Finger)':
                return { color: 'bg-emerald-100 text-emerald-800', text: $t('employeeFiles.jobNoFinger') || 'Job (No Finger)' };
            case 'Remote Job':
                return { color: 'bg-cyan-100 text-cyan-800', text: $t('employeeFiles.remoteJob') || 'Remote Job' };
            case 'Vacation':
                return { color: 'bg-blue-100 text-blue-800', text: $t('employeeFiles.vacation') || 'Vacation' };
            case 'Terminated':
                return { color: 'bg-red-100 text-red-800', text: $t('employeeFiles.terminated') || 'Terminated' };
            case 'Run Away':
                return { color: 'bg-purple-100 text-purple-800', text: $t('employeeFiles.runAway') || 'Run Away' };
            case 'Resigned':
            default:
                return { color: 'bg-gray-100 text-gray-800', text: $t('employeeFiles.resigned') || 'Resigned' };
        }
    }

    function getApprovalStatusDisplay(status: string | undefined): { color: string; text: string } {
        switch (status) {
            case 'approved':
                return { color: 'bg-emerald-100 text-emerald-800', text: $t('common.approved') };
            case 'rejected':
                return { color: 'bg-red-100 text-red-800', text: $t('common.rejected') };
            case 'sent_for_approval':
                return { color: 'bg-blue-100 text-blue-800', text: $t('common.sent_for_approval') || 'Sent for Approval' };
            case 'pending':
            default:
                return { color: 'bg-orange-100 text-orange-800', text: $t('common.pending') };
        }
    }

    function getSponsorshipStatusDisplay(status: string | boolean | null | undefined): { color: string; text: string } {
        // Handle both boolean and string values
        const isSponsored = status === true || status === 'true' || status === 'yes' || status === 'Yes' || status === '1';
        
        if (isSponsored) {
            return { color: 'bg-green-100 text-green-800', text: $locale === 'ar' ? 'على الكفالة' : 'On Sponsorship' };
        } else {
            return { color: 'bg-red-100 text-red-800', text: $locale === 'ar' ? 'ليس على الكفالة' : 'Not On Sponsorship' };
        }
    }

    function formatTimeDisplay(time: string | undefined): string {
        return formatTimeTo12Hour(time);
    }

    function formatBranchDisplay(emp: EmployeeShift): string {
        if ($locale === 'ar') {
            const name = emp.branch_name_ar || emp.branch_name_en;
            const location = emp.branch_location_ar || emp.branch_location_en;
            return location ? `${name} (${location})` : name;
        } else {
            const name = emp.branch_name_en;
            const location = emp.branch_location_en;
            return location ? `${name} (${location})` : name;
        }
    }

    function sortEmployees(employees: any[]): any[] {
        const employmentStatusOrder: { [key: string]: number } = {
            'Job (With Finger)': 1,
            'Job (No Finger)': 2,
            'Remote Job': 3,
            'Vacation': 4,
            'Resigned': 5,
            'Terminated': 6,
            'Run Away': 7
        };

        const sorted = employees.sort((a, b) => {
            // 1. Sort by employment status (Job > Vacation > Resigned > Terminated > Run Away)
            const statusOrderA = employmentStatusOrder[a.employment_status] || 99;
            const statusOrderB = employmentStatusOrder[b.employment_status] || 99;
            if (statusOrderA !== statusOrderB) return statusOrderA - statusOrderB;

            // 2. Sort by nationality (Saudi Arabia first, then others)
            const nationalityNameA = a.nationality_name_en || '';
            const nationalityNameB = b.nationality_name_en || '';
            const isSaudiA = nationalityNameA.toLowerCase().includes('saudi') ? 0 : 1;
            const isSaudiB = nationalityNameB.toLowerCase().includes('saudi') ? 0 : 1;
            if (isSaudiA !== isSaudiB) return isSaudiA - isSaudiB;

            // 3. Sort by sponsorship status (yes/true first, then no/false)
            const isSponsoredA = a.sponsorship_status === true || a.sponsorship_status === 'true' || a.sponsorship_status === 'yes' || a.sponsorship_status === 'Yes' || a.sponsorship_status === '1' ? 0 : 1;
            const isSponsoredB = b.sponsorship_status === true || b.sponsorship_status === 'true' || b.sponsorship_status === 'yes' || b.sponsorship_status === 'Yes' || b.sponsorship_status === '1' ? 0 : 1;
            if (isSponsoredA !== isSponsoredB) return isSponsoredA - isSponsoredB;

            // 4. Sort by numeric employee ID
            const numA = parseInt(a.id?.toString().replace(/\D/g, '') || '0') || 0;
            const numB = parseInt(b.id?.toString().replace(/\D/g, '') || '0') || 0;
            if (numA !== numB) return numA - numB;

            // If all else is equal, sort alphabetically by nationality
            return nationalityNameA.localeCompare(nationalityNameB);
        });
        
        return sorted;
    }

    function formatEmployeeNameDisplay(emp: EmployeeShift): string {
        if ($locale === 'ar') {
            return emp.employee_name_ar || emp.employee_name_en;
        } else {
            return emp.employee_name_en;
        }
    }

    function formatNationalityDisplay(emp: EmployeeShift): string {
        if ($locale === 'ar') {
            return emp.nationality_name_ar || emp.nationality_name_en;
        } else {
            return emp.nationality_name_en;
        }
    }

    function calculateWorkingHours(startTime: string, endTime: string, overlapsNextDay: boolean): number {
        // Parse times to minutes
        const [startHour, startMin] = startTime.split(':').map(Number);
        const [endHour, endMin] = endTime.split(':').map(Number);
        
        const startMinutes = startHour * 60 + startMin;
        const endMinutes = endHour * 60 + endMin;

        let totalMinutes: number;
        
        if (overlapsNextDay) {
            // If shift overlaps to next day: (1440 - start_minutes + end_minutes)
            totalMinutes = (1440 - startMinutes) + endMinutes;
        } else {
            // If shift doesn't overlap: (end_minutes - start_minutes)
            totalMinutes = endMinutes - startMinutes;
        }

        // Convert to hours and round to 2 decimal places
        return Math.round((totalMinutes / 60) * 100) / 100;
    }

    function formatTimeTo12Hour(time: string | undefined): string {
        if (!time) return '—';
        
        const [hours, minutes] = time.split(':').map(Number);
        const period = hours >= 12 ? 'PM' : 'AM';
        const displayHours = hours % 12 || 12; // Convert 0 to 12
        const displayMinutes = String(minutes).padStart(2, '0');
        
        return `${displayHours}:${displayMinutes} ${period}`;
    }

    function getFilteredEmployees(itemList: EmployeeShift[], branchFilter: string, nationalityFilter: string, statusFilter: string, searchQuery: string): EmployeeShift[] {
        let filtered = [...itemList];

        // Filter by branch
        if (branchFilter) {
            filtered = filtered.filter(emp => String(emp.branch_id) === String(branchFilter));
        }

        // Filter by nationality
        if (nationalityFilter) {
            filtered = filtered.filter(emp => String(emp.nationality_id) === String(nationalityFilter));
        }

        // Filter by employment status
        if (statusFilter) {
            filtered = filtered.filter(emp => emp.employment_status === statusFilter);
        }

        // Filter by search query
        if (searchQuery.trim()) {
            const query = searchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                String(emp.id).toLowerCase().includes(query)
            );
        }

        return sortEmployees(filtered);
    }

    function getFilteredSpecialWeekdayEmployees(itemList: EmployeeShift[], branchFilter: string, nationalityFilter: string, statusFilter: string, searchQuery: string): EmployeeShift[] {
        let filtered = [...itemList];

        if (branchFilter) {
            filtered = filtered.filter(emp => String(emp.branch_id) === String(branchFilter));
        }

        if (nationalityFilter) {
            filtered = filtered.filter(emp => String(emp.nationality_id) === String(nationalityFilter));
        }

        if (statusFilter) {
            filtered = filtered.filter(emp => emp.employment_status === statusFilter);
        }

        if (searchQuery.trim()) {
            const query = searchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                String(emp.id).toLowerCase().includes(query)
            );
        }

        return sortEmployees(filtered);
    }

    function getFilteredSpecialDateShifts(itemList: any[], branchFilter: string, nationalityFilter: string, statusFilter: string, searchQuery: string) {
        let filtered = [...itemList];

        if (branchFilter) {
            filtered = filtered.filter(emp => String(emp.branch_id) === String(branchFilter));
        }

        if (nationalityFilter) {
            filtered = filtered.filter(emp => String(emp.nationality_id) === String(nationalityFilter));
        }

        if (statusFilter) {
            filtered = filtered.filter(emp => emp.employment_status === statusFilter);
        }

        if (searchQuery.trim()) {
            const query = searchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                String(emp.id).toLowerCase().includes(query)
            );
        }

        return sortEmployees(filtered);
    }

    // Group day-off requests by employee + submission time + reason (same batch) — same logic as ApprovalCenter
    function groupDayOffRequests(dayOffsList: any[]) {
        const groups = new Map();
        for (const d of dayOffsList) {
            // Truncate timestamp to minute level so batch inserts with slightly different seconds still group together
            let approvalMinute = '';
            if (d.approval_requested_at) {
                const dt = new Date(d.approval_requested_at);
                approvalMinute = `${dt.getFullYear()}-${dt.getMonth()}-${dt.getDate()}-${dt.getHours()}-${dt.getMinutes()}`;
            }
            // Group by employee_id + approval time (minute) + reason (same batch submission)
            const key = `${d.employee_id}_${approvalMinute}_${d.day_off_reason_id || ''}`;
            if (!groups.has(key)) {
                groups.set(key, []);
            }
            groups.get(key).push(d);
        }

        const grouped: any[] = [];
        for (const [key, records] of groups) {
            // Sort records by date
            records.sort((a: any, b: any) => (a.day_off_date || '').localeCompare(b.day_off_date || ''));

            const first = records[0];
            const last = records[records.length - 1];

            // Count approval statuses
            const statusCounts: Record<string, number> = {};
            for (const r of records) {
                const s = r.approval_status || 'pending';
                statusCounts[s] = (statusCounts[s] || 0) + 1;
            }

            grouped.push({
                ...first,
                _grouped: true,
                _allIds: records.map((r: any) => r.id),
                _allDates: records.map((r: any) => r.day_off_date),
                _allDeductions: records.map((r: any) => ({ id: r.id, date: r.day_off_date, is_deductible: r.is_deductible_on_salary || false })),
                _allStatuses: records.map((r: any) => ({ id: r.id, date: r.day_off_date, status: r.approval_status || 'pending' })),
                _statusCounts: statusCounts,
                _dateFrom: first.day_off_date,
                _dateTo: last.day_off_date,
                _dayCount: records.length
            });
        }

        return grouped;
    }

    // Group special shift date-wise records by employee + same shift settings
    function groupSpecialShiftDateWise(shiftsList: any[]) {
        const groups = new Map();
        for (const s of shiftsList) {
            const key = `${s.employee_id}_${s.shift_start_time}_${s.shift_end_time}_${s.shift_start_buffer}_${s.shift_end_buffer}_${s.is_shift_overlapping_next_day}`;
            if (!groups.has(key)) {
                groups.set(key, []);
            }
            groups.get(key).push(s);
        }

        const grouped: any[] = [];
        for (const [key, records] of groups) {
            records.sort((a: any, b: any) => (a.shift_date || '').localeCompare(b.shift_date || ''));
            const first = records[0];
            const last = records[records.length - 1];

            if (records.length === 1) {
                grouped.push({ ...first, _grouped: false, _dayCount: 1 });
            } else {
                grouped.push({
                    ...first,
                    _grouped: true,
                    _allIds: records.map((r: any) => r.id),
                    _allDates: records.map((r: any) => r.shift_date),
                    _dateFrom: first.shift_date,
                    _dateTo: last.shift_date,
                    _dayCount: records.length
                });
            }
        }

        return grouped;
    }

    function getFilteredDayOffs(itemList: any[], branchFilter: string, nationalityFilter: string, statusFilter: string, searchQuery: string, approvalStatusFilter: string = '') {
        let filtered = [...itemList];

        if (branchFilter) {
            filtered = filtered.filter(emp => String(emp.branch_id) === String(branchFilter));
        }

        if (nationalityFilter) {
            filtered = filtered.filter(emp => String(emp.nationality_id) === String(nationalityFilter));
        }

        if (statusFilter) {
            filtered = filtered.filter(emp => emp.employment_status === statusFilter);
        }

        if (approvalStatusFilter) {
            filtered = filtered.filter(emp => emp.approval_status === approvalStatusFilter);
        }

        if (searchQuery.trim()) {
            const query = searchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                String(emp.id).toLowerCase().includes(query)
            );
        }

        return sortEmployees(filtered);
    }

    function getFilteredDayOffsWeekday(itemList: any[], branchFilter: string, nationalityFilter: string, statusFilter: string, searchQuery: string) {
        let filtered = [...itemList];

        if (branchFilter) {
            filtered = filtered.filter(emp => String(emp.branch_id) === String(branchFilter));
        }

        if (nationalityFilter) {
            filtered = filtered.filter(emp => String(emp.nationality_id) === String(nationalityFilter));
        }

        if (statusFilter) {
            filtered = filtered.filter(emp => emp.employment_status === statusFilter);
        }

        if (searchQuery.trim()) {
            const query = searchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                String(emp.id).toLowerCase().includes(query)
            );
        }

        return sortEmployees(filtered);
    }

    function renderShiftColumns(employee: EmployeeShift) {
        return Array.from({length: 7}, (_, i) => i).map(dayNum => {
            const shift = employee.shifts?.[dayNum];
            return shift ? {
                day: weekdayNames[dayNum],
                dayNum,
                startTime: formatTimeTo12Hour(shift.shift_start_time),
                endTime: formatTimeTo12Hour(shift.shift_end_time),
                workingHours: shift.working_hours?.toFixed(2)
            } : {
                day: weekdayNames[dayNum],
                dayNum,
                startTime: '—',
                endTime: '—',
                workingHours: '—'
            };
        });
    }

    // Leave Reasons Functions
    async function loadDayOffReasons() {
        loading = true;
        error = null;
        try {
            await initSupabase();

            console.log('Loading Leave reasons...');
            const { data: reasons, error: reasonError } = await supabase
                .from('day_off_reasons')
                .select('*')
                .order('id', { ascending: true });

            console.log('Leave reasons data:', reasons);
            console.log('Leave reasons error:', reasonError);

            if (reasonError && reasonError.code !== 'PGRST116') throw reasonError;

            dayOffReasons = (reasons as DayOffReason[]) || [];
            console.log('Leave reasons loaded:', dayOffReasons.length);
        } catch (err) {
            console.error('Error loading Leave reasons:', err);
            error = err instanceof Error ? err.message : 'Failed to load reasons';
        } finally {
            loading = false;
        }
    }

    function openReasonModal(reason?: DayOffReason) {
        if (reason) {
            editingReasonId = reason.id;
            reasonFormData = { ...reason };
        } else {
            editingReasonId = null;
            reasonFormData = {
                id: '',
                reason_en: '',
                reason_ar: '',
                is_deductible: false,
                is_document_mandatory: false
            };
        }
        showReasonModal = true;
    }

    function closeReasonModal() {
        showReasonModal = false;
        editingReasonId = null;
    }

    async function saveReason() {
        if (!reasonFormData.reason_en.trim() || !reasonFormData.reason_ar.trim()) {
            openAlertModal($t('hr.shift.errors.fill_reason_names'), $t('common.requiredFields'));
            return;
        }

        // Generate ID if new
        if (!reasonFormData.id) {
            const maxNum = dayOffReasons
                .map(r => parseInt(r.id.replace('DRS', '')) || 0)
                .reduce((a, b) => Math.max(a, b), 0);
            reasonFormData.id = `DRS${String(maxNum + 1).padStart(3, '0')}`;
        }

        isSaving = true;
        try {
            await initSupabase();

            const { error: err } = await supabase
                .from('day_off_reasons')
                .upsert([reasonFormData], { onConflict: 'id' });

            if (err) throw err;

            await loadDayOffReasons();
            closeReasonModal();
        } catch (err) {
            console.error('Error saving reason:', err);
            openAlertModal($t('common.saveError') + ': ' + (err instanceof Error ? err.message : $t('common.unknown_error')), $t('common.saveError'));
        } finally {
            isSaving = false;
        }
    }

    async function deleteReason(id: string) {
        if (!confirm($t('common.confirmDelete'))) return;

        try {
            await initSupabase();

            const { error: err } = await supabase
                .from('day_off_reasons')
                .delete()
                .eq('id', id);

            if (err) throw err;

            await loadDayOffReasons();
        } catch (err) {
            console.error('Error deleting reason:', err);
            openAlertModal($t('common.deleteError') + ': ' + (err instanceof Error ? err.message : $t('common.unknown_error')), $t('common.deleteError'));
        }
    }

    // ====== Official Holidays Functions ======

    $: filteredOfficialHolidays = (() => {
        if (!officialHolidaySearchQuery.trim()) return officialHolidays;
        const query = officialHolidaySearchQuery.toLowerCase();
        return officialHolidays.filter(h =>
            h.name_en?.toLowerCase().includes(query) ||
            h.name_ar?.toLowerCase().includes(query) ||
            h.holiday_date?.includes(query) ||
            dateMatchesSearch(h.holiday_date, officialHolidaySearchQuery)
        );
    })();

    async function loadOfficialHolidays() {
        loading = true;
        error = null;
        try {
            await initSupabase();
            const { data, error: err } = await supabase
                .from('official_holidays')
                .select('*')
                .order('holiday_date', { ascending: true });

            if (err && err.code !== 'PGRST116') throw err;

            // Load assigned employee counts for each holiday
            const holidays = (data as OfficialHoliday[]) || [];
            if (holidays.length > 0) {
                const holidayIds = holidays.map(h => h.id);
                const { data: assignments, error: assignErr } = await supabase
                    .from('employee_official_holidays')
                    .select('official_holiday_id, employee_id')
                    .in('official_holiday_id', holidayIds);

                if (!assignErr && assignments) {
                    const countMap = new Map<string, string[]>();
                    for (const a of assignments) {
                        if (!countMap.has(a.official_holiday_id)) countMap.set(a.official_holiday_id, []);
                        countMap.get(a.official_holiday_id)!.push(a.employee_id);
                    }
                    for (const h of holidays) {
                        const empIds = countMap.get(h.id) || [];
                        h.assigned_count = empIds.length;
                        h.assigned_employees = empIds;
                    }
                }
            }

            officialHolidays = holidays;
        } catch (err) {
            console.error('Error loading official holidays:', err);
            error = err instanceof Error ? err.message : 'Failed to load official holidays';
        } finally {
            loading = false;
        }
    }

    function openOfficialHolidayModal(holiday?: OfficialHoliday) {
        if (holiday) {
            editingOfficialHolidayId = holiday.id;
            officialHolidayFormData = { ...holiday };
        } else {
            editingOfficialHolidayId = null;
            officialHolidayFormData = { id: '', holiday_date: new Date().toISOString().split('T')[0], name_en: '', name_ar: '' };
        }
        showOfficialHolidayModal = true;
    }

    function closeOfficialHolidayModal() {
        showOfficialHolidayModal = false;
        editingOfficialHolidayId = null;
    }

    async function saveOfficialHoliday() {
        if (!officialHolidayFormData.holiday_date || (!officialHolidayFormData.name_en.trim() && !officialHolidayFormData.name_ar.trim())) {
            openAlertModal($t('hr.shift.error_fill_holiday_fields'), $t('common.requiredFields'));
            return;
        }

        isSaving = true;
        try {
            await initSupabase();

            if (editingOfficialHolidayId) {
                // Update existing
                const { error: err } = await supabase
                    .from('official_holidays')
                    .update({
                        holiday_date: officialHolidayFormData.holiday_date,
                        name_en: officialHolidayFormData.name_en.trim(),
                        name_ar: officialHolidayFormData.name_ar.trim(),
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', editingOfficialHolidayId);
                if (err) throw err;
            } else {
                // Insert new
                const { error: err } = await supabase
                    .from('official_holidays')
                    .insert({
                        holiday_date: officialHolidayFormData.holiday_date,
                        name_en: officialHolidayFormData.name_en.trim(),
                        name_ar: officialHolidayFormData.name_ar.trim()
                    });
                if (err) throw err;
            }

            showOfficialHolidayModal = false;
            editingOfficialHolidayId = null;
            await loadOfficialHolidays();
            showSuccessNotification(editingOfficialHolidayId ? ($locale === 'ar' ? 'تم تحديث الإجازة الرسمية' : 'Official holiday updated') : ($locale === 'ar' ? 'تم إضافة الإجازة الرسمية' : 'Official holiday added'));
        } catch (err) {
            console.error('Error saving official holiday:', err);
            showErrorNotification((err instanceof Error ? err.message : $t('common.unknown_error')));
        } finally {
            isSaving = false;
        }
    }

    async function deleteOfficialHoliday(id: string) {
        if (!confirm($t('hr.shift.confirm_delete_official_holiday'))) return;
        try {
            await initSupabase();
            const { error: err } = await supabase
                .from('official_holidays')
                .delete()
                .eq('id', id);
            if (err) throw err;
            await loadOfficialHolidays();
            showSuccessNotification($locale === 'ar' ? 'تم حذف الإجازة الرسمية' : 'Official holiday deleted');
        } catch (err) {
            console.error('Error deleting official holiday:', err);
            showErrorNotification((err instanceof Error ? err.message : $t('common.unknown_error')));
        }
    }

    // ====== Employee Assignment for Official Holidays ======

    async function openAssignEmployeesModal(holiday: OfficialHoliday) {
        assigningHolidayId = holiday.id;
        assigningHolidayName = $locale === 'ar' ? (holiday.name_ar || holiday.name_en) : holiday.name_en;
        assignEmployeeSearchQuery = '';
        isAssignSaving = false;

        try {
            await initSupabase();
            // Load all employees
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select('id, name_en, name_ar, current_branch_id, employment_status');
            if (empError) throw empError;

            // Load branches for display
            const branchIds = [...new Set((employeeData || []).map((e: any) => e.current_branch_id).filter(Boolean))];
            const { data: branches } = await supabase
                .from('branches')
                .select('id, name_en, name_ar')
                .in('id', branchIds);
            const branchMap = new Map((branches || []).map((b: any) => [String(b.id), b]));

            assignAllEmployees = (employeeData || []).map((emp: any) => {
                const branch = branchMap.get(String(emp.current_branch_id)) as any;
                return {
                    id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A'
                };
            }).sort((a: EmployeeForSelection, b: EmployeeForSelection) => a.employee_name_en.localeCompare(b.employee_name_en));
            assignFilteredEmployees = [...assignAllEmployees];

            // Load currently assigned employees
            const { data: existing } = await supabase
                .from('employee_official_holidays')
                .select('employee_id')
                .eq('official_holiday_id', holiday.id);
            assignSelectedEmployeeIds = new Set((existing || []).map((e: any) => e.employee_id));

            showAssignEmployeesModal = true;
        } catch (err) {
            console.error('Error loading employees for assignment:', err);
            showErrorNotification(err instanceof Error ? err.message : $t('common.unknown_error'));
        }
    }

    function closeAssignEmployeesModal() {
        showAssignEmployeesModal = false;
        assigningHolidayId = null;
        assignEmployeeSearchQuery = '';
    }

    function filterAssignEmployees() {
        if (!assignEmployeeSearchQuery.trim()) {
            assignFilteredEmployees = [...assignAllEmployees];
        } else {
            const query = assignEmployeeSearchQuery.toLowerCase();
            assignFilteredEmployees = assignAllEmployees.filter(emp =>
                emp.employee_name_en.toLowerCase().includes(query) ||
                emp.employee_name_ar?.toLowerCase().includes(query) ||
                emp.id.toLowerCase().includes(query) ||
                emp.branch_name_en.toLowerCase().includes(query)
            );
        }
    }

    function toggleEmployeeAssignment(employeeId: string) {
        if (assignSelectedEmployeeIds.has(employeeId)) {
            assignSelectedEmployeeIds.delete(employeeId);
        } else {
            assignSelectedEmployeeIds.add(employeeId);
        }
        assignSelectedEmployeeIds = new Set(assignSelectedEmployeeIds); // trigger reactivity
    }

    function selectAllAssignEmployees() {
        for (const emp of assignFilteredEmployees) {
            assignSelectedEmployeeIds.add(emp.id);
        }
        assignSelectedEmployeeIds = new Set(assignSelectedEmployeeIds);
    }

    function deselectAllAssignEmployees() {
        for (const emp of assignFilteredEmployees) {
            assignSelectedEmployeeIds.delete(emp.id);
        }
        assignSelectedEmployeeIds = new Set(assignSelectedEmployeeIds);
    }

    async function saveEmployeeAssignments() {
        if (!assigningHolidayId) return;
        isAssignSaving = true;
        try {
            await initSupabase();

            // Delete all existing assignments for this holiday
            const { error: delErr } = await supabase
                .from('employee_official_holidays')
                .delete()
                .eq('official_holiday_id', assigningHolidayId);
            if (delErr) throw delErr;

            // Insert new assignments
            if (assignSelectedEmployeeIds.size > 0) {
                const rows = [...assignSelectedEmployeeIds].map(empId => ({
                    employee_id: empId,
                    official_holiday_id: assigningHolidayId
                }));
                const { error: insErr } = await supabase
                    .from('employee_official_holidays')
                    .insert(rows);
                if (insErr) throw insErr;
            }

            showAssignEmployeesModal = false;
            assigningHolidayId = null;
            await loadOfficialHolidays();
            showSuccessNotification($locale === 'ar' ? 'تم تحديث تعيين الموظفين' : 'Employee assignments updated');
        } catch (err) {
            console.error('Error saving employee assignments:', err);
            showErrorNotification(err instanceof Error ? err.message : $t('common.unknown_error'));
        } finally {
            isAssignSaving = false;
        }
    }

    function openReasonSearchModal() {
        showReasonSearchModal = true;
        reasonSearchQuery = '';
        selectedDayOffReason = null;
        // Load reasons if not already loaded
        if (dayOffReasons.length === 0) {
            loadDayOffReasons();
        }
    }

    function closeReasonSearchModal() {
        showReasonSearchModal = false;
        reasonSearchQuery = '';
    }

    function selectReason(reason: DayOffReason) {
        selectedDayOffReason = reason;
        closeReasonSearchModal();
    }

    function handleDocumentSelect(event: Event) {
        const target = event.target as HTMLInputElement;
        documentFile = target.files?.[0] || null;
    }

    async function uploadDocument() {
        if (!documentFile || !selectedEmployeeId || !selectedDayOffDate) {
            openAlertModal($t('hr.shift.errors.select_employee_date_doc'), $t('common.requiredFields'));
            return;
        }

        isUploadingDocument = true;
        documentUploadProgress = 0;

        try {
            await initSupabase();

            const fileExt = documentFile.name.split('.').pop();
            const fileName = `day_off_docs/${selectedEmployeeId}/${Date.now()}.${fileExt}`;

            const { data, error: uploadError } = await supabase.storage
                .from('employee-documents')
                .upload(fileName, documentFile);

            if (uploadError) throw uploadError;

            // Get public URL
            const { data: publicUrlData } = supabase.storage
                .from('employee-documents')
                .getPublicUrl(fileName);

            documentUploadProgress = 100;
            return publicUrlData.publicUrl;
        } catch (err) {
            console.error('Error uploading document:', err);
            openAlertModal($t('common.uploadError') + ': ' + (err instanceof Error ? err.message : $t('common.unknown_error')), $t('common.uploadError'));
            return null;
        } finally {
            isUploadingDocument = false;
        }
    }

    async function saveDayOffWithApproval() {
        if (!selectedEmployeeId || !selectedDayOffStartDate || !selectedDayOffEndDate) {
            openAlertModal($t('hr.shift.errors.select_employee_date'), $t('common.invalidSelection'));
            return;
        }

        // Validate date range
        if (selectedDayOffStartDate > selectedDayOffEndDate) {
            openAlertModal($t('hr.shift.errors.start_before_end'), $t('common.invalidDateRange'));
            return;
        }

        if (!selectedDayOffReason) {
            openAlertModal($t('hr.shift.errors.select_day_off_reason'), $t('common.invalidSelection'));
            return;
        }

        // Check if document is mandatory (allow if document already exists OR newly selected)
        if (selectedDayOffReason.is_document_mandatory && !documentFile && !existingDocumentUrl) {
            openAlertModal($t('hr.shift.errors.doc_mandatory'), $t('common.documentRequired'));
            return;
        }

        isSaving = true;
        try {
            let documentUrl = existingDocumentUrl || null; // Preserve existing document if editing

            // Upload document if provided (only once for entire range)
            if (documentFile) {
                documentUrl = await uploadDocument();
            }

            await initSupabase();

            // Get current user for approval request tracking
            const currentUserData = get(currentUser);
            if (!currentUserData?.id) {
                throw new Error('No user logged in');
            }

            const requestedByUserId = currentUserData.id;
            console.log('✅ Leave request from current user:', { user_id: requestedByUserId });

            // Generate array of dates between start and end date (inclusive)
            const dateArray: string[] = [];
            let currentDate = new Date(selectedDayOffStartDate);
            const endDate = new Date(selectedDayOffEndDate);
            
            while (currentDate <= endDate) {
                const dateStr = currentDate.toISOString().split('T')[0];
                dateArray.push(dateStr);
                currentDate.setDate(currentDate.getDate() + 1);
            }

            console.log(`Creating ${dateArray.length} day-off entries from ${selectedDayOffStartDate} to ${selectedDayOffEndDate}`);

            // Create Leave records for each date in range
            const dayOffRecords = dateArray.map(dateStr => {
                const dateStrFormatted = dateStr.replace(/-/g, ''); // Remove dashes: 20260118
                const dayOffId = `${selectedEmployeeId}_${dateStrFormatted}`;
                
                return {
                    id: dayOffId,
                    employee_id: selectedEmployeeId,
                    day_off_date: dateStr,
                    day_off_reason_id: selectedDayOffReason.id,
                    approval_status: 'pending',
                    approval_requested_by: requestedByUserId,
                    approval_requested_at: new Date().toISOString(),
                    document_url: documentUrl,
                    description: dayOffDescription || null,
                    is_deductible_on_salary: selectedDayOffReason.is_deductible
                };
            });

            // Upsert all records (insert or update if already exists)
            const { data: dayOffData, error: dayOffError } = await supabase
                .from('day_off')
                .upsert(dayOffRecords)
                .select();

            if (dayOffError) throw dayOffError;

            console.log(`✅ Created ${dayOffData?.length || 0} day-off records`);

            // Send approval request notifications
            if (dayOffData && dayOffData.length > 0) {
                try {
                    // Find approvers with permission
                    const { data: approvers, error: approvingError } = await supabase
                        .from('approval_permissions')
                        .select('user_id')
                        .eq('can_approve_leave_requests', true)
                        .eq('is_active', true);

                    if (!approvingError && approvers && approvers.length > 0) {
                        const approverUserIds = approvers.map((a: any) => a.user_id);

                        // Create notification using direct database insert
                        try {
                            const { error: notifError } = await supabase
                                .from('notifications')
                                .insert({
                                    title: 'طلب موافقة على إجازة | Leave Request Approval',
                                    message: `طلب إجازة للموظف ${allEmployeesForDateWise.find(e => e.id === selectedEmployeeId)?.employee_name_ar || allEmployeesForDateWise.find(e => e.id === selectedEmployeeId)?.employee_name_en || selectedEmployeeId} (${selectedEmployeeId}) من ${selectedDayOffStartDate} إلى ${selectedDayOffEndDate} (${dateArray.length} أيام) يتطلب موافقة\n\nLeave request for ${allEmployeesForDateWise.find(e => e.id === selectedEmployeeId)?.employee_name_en || allEmployeesForDateWise.find(e => e.id === selectedEmployeeId)?.employee_name_ar || selectedEmployeeId} (${selectedEmployeeId}) from ${selectedDayOffStartDate} to ${selectedDayOffEndDate} (${dateArray.length} days) requires approval`,
                                    type: 'approval_request',
                                    priority: 'high',
                                    target_type: 'specific_users',
                                    target_users: approverUserIds,
                                    created_by: $currentUser?.username || $currentUser?.id || 'system',
                                    created_by_name: $currentUser?.username || 'System',
                                    created_by_role: $currentUser?.role || 'User',
                                    status: 'published'
                                });

                            if (notifError) {
                                console.error('Error creating notification:', notifError);
                            } else {
                                console.log('✅ Notification sent to', approverUserIds.length, 'approvers');
                                // Database trigger will automatically create notification_recipients
                            }
                        } catch (notificationError) {
                            console.warn('⚠️ Warning: Could not send approval notifications:', notificationError);
                            // Don't fail the entire operation if notifications fail
                        }
                    }
                } catch (approvalError) {
                    console.warn('⚠️ Warning: Could not send approvals:', approvalError);
                }
            }

            // Clear form
            selectedDayOffStartDate = new Date().toISOString().split('T')[0];
            selectedDayOffEndDate = new Date().toISOString().split('T')[0];
            selectedDayOffReason = null;
            dayOffDescription = '';
            documentFile = null;
            existingDocumentUrl = null;
            documentUploadProgress = 0;

            // Reload Leave data immediately to show new entries in real-time
            console.log('🔄 Reloading Leave data after save...');
            await loadDayOffData();
            console.log('✅ Leave data refreshed, current count:', dayOffs.length);
            
            // Close modal and show success notification
            showModal = false;
            showSuccessNotification(`Leave request submitted for ${dateArray.length} day${dateArray.length !== 1 ? 's' : ''}!`);
        } catch (err) {
            console.error('Error saving Leave:', err);
            showErrorNotification('Error: ' + (err instanceof Error ? err.message : 'Failed to save Leave'));
        } finally {
            isSaving = false;
        }
    }

    // ========================================================================
    // MULTI-SHIFT SECTION
    // ========================================================================

    interface MultiShiftRecord {
        id?: number;
        employee_id: string;
        employee_name_en?: string;
        employee_name_ar?: string;
        branch_name_en?: string;
        branch_name_ar?: string;
        shift_start_time: string;
        shift_start_buffer: number;
        shift_end_time: string;
        shift_end_buffer: number;
        is_shift_overlapping_next_day: boolean;
        working_hours: number;
        // For date-wise
        date_from?: string;
        date_to?: string;
        // For weekday
        weekday?: number;
    }

    let multiShiftRegularData: MultiShiftRecord[] = [];
    let multiShiftDateData: MultiShiftRecord[] = [];
    let multiShiftWeekdayData: MultiShiftRecord[] = [];
    let multiShiftActiveSubTab: 'regular' | 'date' | 'day' = 'regular';
    let showMultiShiftModal = false;
    let multiShiftModalType: 'regular' | 'date' | 'day' = 'regular';
    let showMultiShiftEmployeeSelectModal = false;
    let multiShiftEmployeeSearchQuery = '';
    let multiShiftSelectedEmployeeId: string | null = null;
    let multiShiftSelectedEmployeeName = '';
    let isMultiShiftSaving = false;
    let multiShiftFormData: MultiShiftRecord = {
        employee_id: '',
        shift_start_time: '09:00',
        shift_start_buffer: 0,
        shift_end_time: '17:00',
        shift_end_buffer: 0,
        is_shift_overlapping_next_day: false,
        working_hours: 8,
        date_from: new Date().toISOString().split('T')[0],
        date_to: new Date().toISOString().split('T')[0],
        weekday: 0
    };
    let editingMultiShiftId: number | null = null;

    // 12-hour format for multi-shift modal
    let msStartHour12 = '09';
    let msStartMinute12 = '00';
    let msStartPeriod12 = 'AM';
    let msEndHour12 = '05';
    let msEndMinute12 = '00';
    let msEndPeriod12 = 'PM';

    function updateMsStartTime24h() {
        let h = parseInt(msStartHour12);
        if (msStartPeriod12 === 'PM' && h < 12) h += 12;
        if (msStartPeriod12 === 'AM' && h === 12) h = 0;
        multiShiftFormData.shift_start_time = `${String(h).padStart(2, '0')}:${msStartMinute12}`;
    }

    function updateMsEndTime24h() {
        let h = parseInt(msEndHour12);
        if (msEndPeriod12 === 'PM' && h < 12) h += 12;
        if (msEndPeriod12 === 'AM' && h === 12) h = 0;
        multiShiftFormData.shift_end_time = `${String(h).padStart(2, '0')}:${msEndMinute12}`;
    }

    function syncMsTimeTo12h() {
        if (multiShiftFormData.shift_start_time) {
            const [h, m] = multiShiftFormData.shift_start_time.split(':').map(Number);
            msStartPeriod12 = h >= 12 ? 'PM' : 'AM';
            msStartHour12 = String(h % 12 || 12).padStart(2, '0');
            msStartMinute12 = String(m || 0).padStart(2, '0');
        }
        if (multiShiftFormData.shift_end_time) {
            const [h, m] = multiShiftFormData.shift_end_time.split(':').map(Number);
            msEndPeriod12 = h >= 12 ? 'PM' : 'AM';
            msEndHour12 = String(h % 12 || 12).padStart(2, '0');
            msEndMinute12 = String(m || 0).padStart(2, '0');
        }
    }

    function openMultiShiftEmployeeSelect(type: 'regular' | 'date' | 'day') {
        multiShiftModalType = type;
        multiShiftEmployeeSearchQuery = '';
        multiShiftSelectedEmployeeId = null;
        multiShiftSelectedEmployeeName = '';
        showMultiShiftEmployeeSelectModal = true;
    }

    function selectMultiShiftEmployee(emp: EmployeeForSelection) {
        multiShiftSelectedEmployeeId = emp.id;
        multiShiftSelectedEmployeeName = $locale === 'ar' ? emp.employee_name_ar : emp.employee_name_en;
        showMultiShiftEmployeeSelectModal = false;
        editingMultiShiftId = null;
        multiShiftFormData = {
            employee_id: emp.id,
            shift_start_time: '09:00',
            shift_start_buffer: 0,
            shift_end_time: '17:00',
            shift_end_buffer: 0,
            is_shift_overlapping_next_day: false,
            working_hours: 8,
            date_from: new Date().toISOString().split('T')[0],
            date_to: new Date().toISOString().split('T')[0],
            weekday: 0
        };
        syncMsTimeTo12h();
        showMultiShiftModal = true;
    }

    function openEditMultiShift(record: MultiShiftRecord, type: 'regular' | 'date' | 'day') {
        multiShiftModalType = type;
        editingMultiShiftId = record.id || null;
        multiShiftSelectedEmployeeId = record.employee_id;
        multiShiftSelectedEmployeeName = $locale === 'ar' ? (record.employee_name_ar || '') : (record.employee_name_en || '');
        multiShiftFormData = { ...record };
        syncMsTimeTo12h();
        showMultiShiftModal = true;
    }

    function closeMultiShiftModal() {
        showMultiShiftModal = false;
        editingMultiShiftId = null;
    }

    $: multiShiftFilteredEmployees = (() => {
        if (!allEmployeesForDateWise || allEmployeesForDateWise.length === 0) return [];
        const q = multiShiftEmployeeSearchQuery.toLowerCase().trim();
        if (!q) return allEmployeesForDateWise;
        return allEmployeesForDateWise.filter(e =>
            e.id.toLowerCase().includes(q) ||
            e.employee_name_en.toLowerCase().includes(q) ||
            e.employee_name_ar.toLowerCase().includes(q)
        );
    })();

    async function loadMultiShiftData() {
        loading = true;
        error = null;
        try {
            await initSupabase();

            // Load all employees for selection (reuse existing)
            if (allEmployeesForDateWise.length === 0) {
                const { data: empData } = await supabase
                    .from('hr_employee_master')
                    .select('id, name_en, name_ar, current_branch_id');
                const { data: branchData } = await supabase
                    .from('branches')
                    .select('id, name_en, name_ar');
                const branchMap = new Map((branchData || []).map((b: any) => [String(b.id), b]));

                allEmployeesForDateWise = (empData || []).map((e: any) => {
                    const branch = branchMap.get(String(e.current_branch_id)) as any;
                    return {
                        id: e.id,
                        employee_name_en: e.name_en,
                        employee_name_ar: e.name_ar,
                        branch_name_en: branch?.name_en || 'N/A',
                        branch_name_ar: branch?.name_ar || 'N/A'
                    };
                });
            }

            // Load all three categories
            const [regRes, dateRes, dayRes] = await Promise.all([
                supabase.from('multi_shift_regular').select('*').order('employee_id'),
                supabase.from('multi_shift_date_wise').select('*').order('employee_id'),
                supabase.from('multi_shift_weekday').select('*').order('employee_id')
            ]);

            // Enrich with employee names
            const enrichRecords = (records: any[]): MultiShiftRecord[] => {
                return (records || []).map((r: any) => {
                    const emp = allEmployeesForDateWise.find(e => e.id === r.employee_id);
                    return {
                        ...r,
                        employee_name_en: emp?.employee_name_en || r.employee_id,
                        employee_name_ar: emp?.employee_name_ar || r.employee_id,
                        branch_name_en: emp?.branch_name_en || '',
                        branch_name_ar: emp?.branch_name_ar || ''
                    };
                });
            };

            multiShiftRegularData = enrichRecords(regRes.data || []);
            multiShiftDateData = enrichRecords(dateRes.data || []);
            multiShiftWeekdayData = enrichRecords(dayRes.data || []);
        } catch (err) {
            console.error('Error loading multi-shift data:', err);
            error = err instanceof Error ? err.message : 'Failed to load multi-shift data';
        } finally {
            loading = false;
        }
    }

    async function saveMultiShift() {
        if (!multiShiftFormData.employee_id) {
            showErrorNotification($t('hr.shift.multiShift.error_select_employee'));
            return;
        }
        if (!multiShiftFormData.working_hours || multiShiftFormData.working_hours <= 0) {
            showErrorNotification($t('hr.shift.multiShift.error_working_hours'));
            return;
        }
        if (multiShiftModalType === 'date' && multiShiftFormData.date_from && multiShiftFormData.date_to) {
            if (multiShiftFormData.date_from > multiShiftFormData.date_to) {
                showErrorNotification($t('hr.shift.multiShift.error_date_range'));
                return;
            }
        }

        isMultiShiftSaving = true;
        try {
            await initSupabase();

            const tableName = multiShiftModalType === 'regular' ? 'multi_shift_regular'
                : multiShiftModalType === 'date' ? 'multi_shift_date_wise'
                : 'multi_shift_weekday';

            const payload: any = {
                employee_id: multiShiftFormData.employee_id,
                shift_start_time: multiShiftFormData.shift_start_time,
                shift_start_buffer: multiShiftFormData.shift_start_buffer,
                shift_end_time: multiShiftFormData.shift_end_time,
                shift_end_buffer: multiShiftFormData.shift_end_buffer,
                is_shift_overlapping_next_day: multiShiftFormData.is_shift_overlapping_next_day,
                working_hours: multiShiftFormData.working_hours
            };

            if (multiShiftModalType === 'date') {
                payload.date_from = multiShiftFormData.date_from;
                payload.date_to = multiShiftFormData.date_to;
            }
            if (multiShiftModalType === 'day') {
                payload.weekday = multiShiftFormData.weekday;
            }

            if (editingMultiShiftId) {
                const { error: err } = await supabase
                    .from(tableName)
                    .update(payload)
                    .eq('id', editingMultiShiftId);
                if (err) throw err;
            } else {
                const { error: err } = await supabase
                    .from(tableName)
                    .insert(payload);
                if (err) throw err;
            }

            showMultiShiftModal = false;
            editingMultiShiftId = null;
            showSuccessNotification($t('hr.shift.multiShift.success_saved'));
            await loadMultiShiftData();
        } catch (err) {
            console.error('Error saving multi-shift:', err);
            showErrorNotification($t('hr.shift.multiShift.error_save') + ': ' + (err instanceof Error ? err.message : 'Unknown'));
        } finally {
            isMultiShiftSaving = false;
        }
    }

    async function deleteMultiShift(id: number, type: 'regular' | 'date' | 'day') {
        if (!confirm($t('hr.shift.multiShift.delete_confirm'))) return;

        try {
            await initSupabase();
            const tableName = type === 'regular' ? 'multi_shift_regular'
                : type === 'date' ? 'multi_shift_date_wise'
                : 'multi_shift_weekday';

            const { error: err } = await supabase
                .from(tableName)
                .delete()
                .eq('id', id);

            if (err) throw err;
            showSuccessNotification($t('hr.shift.multiShift.success_deleted'));
            await loadMultiShiftData();
        } catch (err) {
            console.error('Error deleting multi-shift:', err);
            showErrorNotification($t('hr.shift.multiShift.error_delete'));
        }
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm">
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button 
                    class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id 
                        ? (tab.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]')
                        : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                    on:click={async () => {
                        activeTab = tab.id;
                        handleTabChange();
                    }}
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
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Futuristic background decorative elements -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col">
            {#if activeTab === 'Regular Shift'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('hr.shift.loading_employees')}</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadEmployeeShiftData}
                        >
                            {$t('common.retry')}
                        </button>
                    </div>
                {:else if employees.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📭</div>
                        <p class="text-slate-600 font-semibold">{$t('hr.shift.no_employees')}</p>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="reg-branch-filter">{$t('hr.shift.filter_branch')}</label>
                            <select 
                                id="reg-branch-filter"
                                bind:value={selectedBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_branches')}</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' 
                                            ? `${branch.name_ar || branch.name_en}${branch.location_ar ? ' (' + branch.location_ar + ')' : ''}`
                                            : `${branch.name_en || branch.name || 'Unnamed'}${branch.location_en ? ' (' + branch.location_en + ')' : ''}`}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="reg-nationality-filter">{$t('hr.shift.filter_nationality')}</label>
                            <select 
                                id="reg-nationality-filter"
                                bind:value={selectedNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_nationalities')}</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' ? (nationality.name_ar || nationality.name_en) : (nationality.name_en || nationality.name || 'Unnamed')}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employment Status Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="reg-status-filter">{$t('employeeFiles.employmentStatus')}</label>
                            <select 
                                id="reg-status-filter"
                                bind:value={selectedEmploymentStatusFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_statuses') || 'All Statuses'}</option>
                                {#each availableEmploymentStatuses as status}
                                    <option value={status.id} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status.id).text}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="reg-employee-search">{$t('hr.shift.search_employee')}</label>
                            <input 
                                id="reg-employee-search"
                                type="text"
                                bind:value={regularShiftSearchQuery}
                                placeholder={$t('hr.shift.search_placeholder')}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            />
                        </div>
                    </div>

                    <!-- Regular Shift Table Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <!-- Table Wrapper with horizontal scroll -->
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.fullName')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.branch')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.nationality')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.start')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.end')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.working_hours')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.action')}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each filteredRegularEmployees as employee, index}
                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm text-slate-700">
                                                <div>{formatEmployeeNameDisplay(employee)}</div>
                                                <div class="text-xs text-slate-400">{employee.id}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-slate-700">
                                                <div>{$locale === 'ar' ? (employee.branch_name_ar || employee.branch_name_en) : employee.branch_name_en}</div>
                                                {#if ($locale === 'ar' ? (employee.branch_location_ar || employee.branch_location_en) : employee.branch_location_en)}
                                                    <div class="text-xs text-slate-400">{$locale === 'ar' ? (employee.branch_location_ar || employee.branch_location_en) : employee.branch_location_en}</div>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm text-slate-700">
                                                <div>{formatNationalityDisplay(employee)}</div>
                                                <div class="text-xs text-slate-400">{getSponsorshipStatusDisplay(employee.sponsorship_status).text}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center font-mono">
                                                <div class="text-slate-800">{formatTimeTo12Hour(employee.shift_start_time)}</div>
                                                <div class="text-xs text-slate-400">{$t('hr.shift.start_buffer')}: {employee.shift_start_buffer || 0} {$t('common.hrs')}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center font-mono">
                                                <div class="text-slate-800">{formatTimeTo12Hour(employee.shift_end_time)}</div>
                                                <div class="text-xs text-slate-400">{$t('hr.shift.end_buffer')}: {employee.shift_end_buffer || 0} {$t('common.hrs')}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <div class="font-bold text-emerald-700">{employee.working_hours ? employee.working_hours.toFixed(2) : '—'} {$t('common.hrs')}</div>
                                                <div class="text-xs mt-0.5">
                                                    <span class="inline-block px-2 py-0.5 rounded-full text-[10px] font-black {employee.is_shift_overlapping_next_day ? 'bg-orange-200 text-orange-800' : 'bg-slate-200 text-slate-800'}">
                                                        {$t('hr.shift.overlaps')}: {employee.is_shift_overlapping_next_day ? $t('common.yes') : $t('common.no')}
                                                    </span>
                                                </div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                {#if employee.shift_start_time}
                                                    <button 
                                                        class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
                                                        on:click={() => openModal(employee.id)}
                                                        title={$t('hr.shift.edit_tooltip')}
                                                    >
                                                        ✏️ {$t('common.edit')}
                                                    </button>
                                                {:else}
                                                    <button 
                                                        class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-emerald-600 text-white font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                        on:click={() => openModal(employee.id)}
                                                        title={$t('hr.shift.add_tooltip')}
                                                    >
                                                        +
                                                    </button>
                                                {/if}
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('hr.shift.showing_employees', { count: filteredRegularEmployees.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Special Shift (weekday-wise)'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('hr.shift.loading_special_shifts')}</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadSpecialShiftWeekdayData}
                        >
                            {$t('common.retry')}
                        </button>
                    </div>
                {:else if employees.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📭</div>
                        <p class="text-slate-600 font-semibold">{$t('hr.shift.no_employees')}</p>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-w-branch-filter">{$t('hr.shift.filter_branch')}</label>
                            <select 
                                id="spec-w-branch-filter"
                                bind:value={specialWeekdayBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_branches')}</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' 
                                            ? `${branch.name_ar || branch.name_en}${branch.location_ar ? ' (' + branch.location_ar + ')' : ''}`
                                            : `${branch.name_en || branch.name || 'Unnamed'}${branch.location_en ? ' (' + branch.location_en + ')' : ''}`}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-w-nationality-filter">{$t('hr.shift.filter_nationality')}</label>
                            <select 
                                id="spec-w-nationality-filter"
                                bind:value={specialWeekdayNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_nationalities')}</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' ? (nationality.name_ar || nationality.name_en) : (nationality.name_en || nationality.name || 'Unnamed')}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employment Status Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-w-status-filter">{$t('employeeFiles.employmentStatus')}</label>
                            <select 
                                id="spec-w-status-filter"
                                bind:value={specialWeekdayEmploymentStatusFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_statuses') || 'All Statuses'}</option>
                                {#each availableEmploymentStatuses as status}
                                    <option value={status.id} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status.id).text}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-w-employee-search">{$t('hr.shift.search_employee')}</label>
                            <input 
                                id="spec-w-employee-search"
                                type="text"
                                bind:value={specialWeekdaySearchQuery}
                                placeholder={$t('hr.shift.search_placeholder')}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            />
                        </div>
                    </div>

                    <!-- Special Shift Weekday-wise Table Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <!-- Table Wrapper with horizontal scroll -->
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse [&_th]:border-x [&_th]:border-orange-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                <thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.fullName')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.branch')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.nationality')}</th>
                                        {#each activeWeekdays as wd}
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 bg-orange-500/50">
                                                {wd.name}
                                            </th>
                                        {/each}
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('common.action')}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each filteredSpecialWeekdayEmployees as employee, index}
                                        <tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm text-slate-700">
                                                <div>{formatEmployeeNameDisplay(employee)}</div>
                                                <div class="text-xs text-slate-400">{employee.id}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-slate-700">
                                                <div>{$locale === 'ar' ? (employee.branch_name_ar || employee.branch_name_en) : employee.branch_name_en}</div>
                                                {#if ($locale === 'ar' ? (employee.branch_location_ar || employee.branch_location_en) : employee.branch_location_en)}
                                                    <div class="text-xs text-slate-400">{$locale === 'ar' ? (employee.branch_location_ar || employee.branch_location_en) : employee.branch_location_en}</div>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm text-slate-700">
                                                <div>{formatNationalityDisplay(employee)}</div>
                                                <div class="text-xs text-slate-400">{getSponsorshipStatusDisplay(employee.sponsorship_status).text}</div>
                                            </td>
                                            {#each activeWeekdays as wd}
                                                {@const shift = employee.shifts?.[wd.index]}
                                                <td class="px-3 py-2 text-center font-mono">
                                                    {#if shift}
                                                        <div class="text-xs text-slate-800"><span class="text-[10px] text-slate-400 font-sans">{$t('hr.shift.start')}:</span> {formatTimeTo12Hour(shift.shift_start_time)}</div>
                                                        <div class="text-xs text-slate-800"><span class="text-[10px] text-slate-400 font-sans">{$t('hr.shift.end')}:</span> {formatTimeTo12Hour(shift.shift_end_time)}</div>
                                                        <div class="text-xs font-bold text-orange-700">{shift.working_hours?.toFixed(2)} {$t('common.hrs')}</div>
                                                    {:else}
                                                        <span class="text-xs text-slate-300">—</span>
                                                    {/if}
                                                </td>
                                            {/each}
                                            <td class="px-4 py-3 text-sm text-center flex gap-2 justify-center">
                                                <button 
                                                    class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-orange-600 text-white font-bold hover:bg-orange-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                    on:click={() => openModal(employee.id)}
                                                    title={$t('hr.shift.add_edit_special_tooltip')}
                                                >
                                                    +
                                                </button>
                                                <button 
                                                    class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                    on:click={() => openDeleteModal(employee.id)}
                                                    title={$t('hr.shift.delete_special_tooltip')}
                                                >
                                                    🗑️
                                                </button>
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('hr.shift.showing_employees_filter', { current: filteredSpecialWeekdayEmployees.length, total: employees.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Special Shift (date-wise)'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('hr.shift.loading_special_date_wise')}</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadSpecialShiftDateWiseData}
                        >
                            {$t('common.retry')}
                        </button>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-d-branch-filter">{$t('hr.shift.filter_branch')}</label>
                            <select 
                                id="spec-d-branch-filter"
                                bind:value={specialDateBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_branches')}</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' 
                                            ? `${branch.name_ar || branch.name_en}${branch.location_ar ? ' (' + branch.location_ar + ')' : ''}`
                                            : `${branch.name_en || branch.name || 'Unnamed'}${branch.location_en ? ' (' + branch.location_en + ')' : ''}`}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-d-nationality-filter">{$t('hr.shift.filter_nationality')}</label>
                            <select 
                                id="spec-d-nationality-filter"
                                bind:value={specialDateNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_nationalities')}</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' ? (nationality.name_ar || nationality.name_en) : (nationality.name_en || nationality.name || 'Unnamed')}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employment Status Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-d-status-filter">{$t('employeeFiles.employmentStatus')}</label>
                            <select 
                                id="spec-d-status-filter"
                                bind:value={specialDateEmploymentStatusFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_statuses') || 'All Statuses'}</option>
                                {#each availableEmploymentStatuses as status}
                                    <option value={status.id} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status.id).text}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-d-employee-search">{$t('hr.shift.search_employee')}</label>
                            <input 
                                id="spec-d-employee-search"
                                type="text"
                                bind:value={specialDateSearchQuery}
                                placeholder={$t('hr.shift.search_placeholder')}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            />
                        </div>

                        <!-- Date Range Selection -->
                        <div class="flex gap-2">
                            <div class="w-36">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-d-start-date">{$t('hr.startDate')}</label>
                                <input 
                                    type="date" 
                                    id="spec-d-start-date"
                                    bind:value={specialDateFilterStart}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 transition-all"
                                />
                            </div>
                            <div class="w-36">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="spec-d-end-date">{$t('hr.endDate')}</label>
                                <input 
                                    type="date" 
                                    id="spec-d-end-date"
                                    bind:value={specialDateFilterEnd}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 transition-all"
                                />
                            </div>
                        </div>

                        <!-- Load Button -->
                        <div class="self-end pb-0.5">
                            <button 
                                on:click={loadSpecialShiftDateWiseData}
                                class="px-6 py-2.5 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 shadow-lg shadow-orange-200 transition-all flex items-center gap-2 h-[42px]"
                            >
                                <span class="text-sm">🔄</span>
                                Load Data
                            </button>
                        </div>
                    </div>

                    <!-- Special Shift Date-wise Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <!-- Action Button -->
                        <div class="px-6 py-4 border-b border-slate-200 flex items-center gap-3">
                            <button 
                                class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-orange-600 hover:bg-orange-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                                on:click={openEmployeeSelectModal}
                            >
                                <span>⭐</span>
                                {$t('hr.shift.add_special_date')}
                            </button>
                            <button 
                                class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-indigo-600 hover:bg-indigo-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                                on:click={openSpecialShiftRangeModal}
                            >
                                <span>📅</span>
                                {$t('hr.shift.add_special_range') || 'Add Special Range'}
                            </button>
                            <p class="text-xs text-slate-500 font-semibold">{$t('hr.shift.click_to_add_special')}</p>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if dateWiseShifts.length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">{$t('hr.shift.no_special_shifts')}</p>
                                        <p class="text-slate-400 text-sm mt-2">{$t('hr.shift.click_button_to_add')}</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse [&_th]:border-x [&_th]:border-orange-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                    <thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.fullName')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.branch')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.nationality')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('common.date')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.start')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.end')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.working_hours')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('common.action')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each filteredSpecialDateEmployees as shift, index}
                                            <tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{formatEmployeeNameDisplay(shift)}</div>
                                                    <div class="text-xs text-slate-400">{shift.employee_id}</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{$locale === 'ar' ? (shift.branch_name_ar || shift.branch_name_en) : shift.branch_name_en}</div>
                                                    {#if ($locale === 'ar' ? (shift.branch_location_ar || shift.branch_location_en) : shift.branch_location_en)}
                                                        <div class="text-xs text-slate-400">{$locale === 'ar' ? (shift.branch_location_ar || shift.branch_location_en) : shift.branch_location_en}</div>
                                                    {/if}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{formatNationalityDisplay(shift)}</div>
                                                    <div class="text-xs text-slate-400">{getSponsorshipStatusDisplay(shift.sponsorship_status).text}</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm font-mono text-slate-800">
                                                    {#if shift._dayCount && shift._dayCount > 1}
                                                        <div class="flex flex-col gap-1">
                                                            <span class="font-semibold">{formatDateDisplay(shift._dateFrom)} → {formatDateDisplay(shift._dateTo)}</span>
                                                            <button
                                                                class="inline-flex items-center gap-1 mt-1 px-2.5 py-1 rounded-lg text-[11px] font-bold bg-blue-50 text-blue-600 border border-blue-200 hover:bg-blue-100 hover:shadow transition-all"
                                                                on:click={() => openViewDatesPopup(shift)}
                                                            >
                                                                📅 {$locale === 'ar' ? 'عرض التواريخ' : 'View Dates'} ({shift._dayCount})
                                                            </button>
                                                        </div>
                                                    {:else}
                                                        {formatDateDisplay(shift.shift_date)}
                                                    {/if}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center font-mono">
                                                    <div class="text-slate-800">{formatTimeTo12Hour(shift.shift_start_time || '')}</div>
                                                    <div class="text-xs text-slate-400">{$t('hr.shift.start_buffer')}: {shift.shift_start_buffer || 0} {$t('common.hrs')}</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center font-mono">
                                                    <div class="text-slate-800">{formatTimeTo12Hour(shift.shift_end_time || '')}</div>
                                                    <div class="text-xs text-slate-400">{$t('hr.shift.end_buffer')}: {shift.shift_end_buffer || 0} {$t('common.hrs')}</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <div class="font-bold text-orange-700">{shift.working_hours} {$t('common.hrs')}</div>
                                                    <div class="text-xs mt-0.5">
                                                        <span class="inline-block px-2 py-0.5 rounded-full text-[10px] font-black {shift.is_shift_overlapping_next_day ? 'bg-orange-200 text-orange-800' : 'bg-slate-200 text-slate-800'}">
                                                            {$t('hr.shift.overlaps')}: {shift.is_shift_overlapping_next_day ? $t('common.yes') : $t('common.no')}
                                                        </span>
                                                    </div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <div class="flex justify-center gap-2">
                                                        <button 
                                                            class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-blue-600 text-white font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                            on:click={() => {
                                                                selectedEmployeeId = shift.employee_id;
                                                                if (shift._dayCount && shift._dayCount > 1) {
                                                                    isRangeSpecialShift = true;
                                                                    specialShiftStartDate = shift._dateFrom || shift.shift_date;
                                                                    specialShiftEndDate = shift._dateTo || shift.shift_date;
                                                                } else {
                                                                    isRangeSpecialShift = false;
                                                                }
                                                                (formData) = {
                                                                    id: shift.id,
                                                                    employee_id: shift.employee_id,
                                                                    shift_date: shift.shift_date,
                                                                    shift_start_time: shift.shift_start_time || '09:00',
                                                                    shift_start_buffer: shift.shift_start_buffer || 3,
                                                                    shift_end_time: shift.shift_end_time || '17:00',
                                                                    shift_end_buffer: shift.shift_end_buffer || 3,
                                                                    is_shift_overlapping_next_day: shift.is_shift_overlapping_next_day || false
                                                                };
                                                                showModal = true;
                                                            }}
                                                            title={$t('common.edit')}
                                                        >
                                                            ✎️
                                                        </button>
                                                        <button 
                                                            class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                            on:click={() => {
                                                                if (shift._dayCount && shift._dayCount > 1) {
                                                                    openGroupedShiftDeleteModal(shift);
                                                                } else {
                                                                    deleteSpecialShiftDateWise(shift.id, shift.employee_id, shift.shift_date);
                                                                }
                                                            }}
                                                            title={$t('hr.shift.delete_tooltip')}
                                                        >
                                                            🗑️
                                                        </button>
                                                    </div>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            {/if}
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('hr.shift.showing_shifts', { current: filteredSpecialDateEmployees.length, total: groupedSpecialDateShifts.length })} ({dateWiseShifts.length} {$locale === 'ar' ? 'سجل' : 'records'})
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Leave (date-wise)'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('hr.shift.loading_day_off_data')}</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadDayOffData}
                        >
                            {$t('common.retry')}
                        </button>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-d-branch-filter">{$t('hr.shift.filter_branch')}</label>
                            <select 
                                id="do-d-branch-filter"
                                bind:value={dayOffBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_branches')}</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' 
                                            ? `${branch.name_ar || branch.name_en}${branch.location_ar ? ' (' + branch.location_ar + ')' : ''}`
                                            : `${branch.name_en || branch.name || 'Unnamed'}${branch.location_en ? ' (' + branch.location_en + ')' : ''}`}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-d-nationality-filter">{$t('hr.shift.filter_nationality')}</label>
                            <select 
                                id="do-d-nationality-filter"
                                bind:value={dayOffNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_nationalities')}</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' ? (nationality.name_ar || nationality.name_en) : (nationality.name_en || nationality.name || 'Unnamed')}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employment Status Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-d-status-filter">{$t('employeeFiles.employmentStatus')}</label>
                            <select 
                                id="do-d-status-filter"
                                bind:value={dayOffEmploymentStatusFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_statuses') || 'All Statuses'}</option>
                                {#each availableEmploymentStatuses as status}
                                    <option value={status.id} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status.id).text}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Approval Status Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-d-approval-filter">{$t('hr.shift.approval_status') || 'Approval Status'}</label>
                            <select 
                                id="do-d-approval-filter"
                                bind:value={dayOffApprovalStatusFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_statuses') || 'All Statuses'}</option>
                                <option value="approved" style="color: #000000 !important; background-color: #ffffff !important;">✅ {$locale === 'ar' ? 'موافق' : 'Approved'}</option>
                                <option value="rejected" style="color: #000000 !important; background-color: #ffffff !important;">❌ {$locale === 'ar' ? 'مرفوض' : 'Rejected'}</option>
                                <option value="pending" style="color: #000000 !important; background-color: #ffffff !important;">⏳ {$locale === 'ar' ? 'معلق' : 'Pending'}</option>
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-d-employee-search">{$t('hr.shift.search_employee')}</label>
                            <input 
                                id="do-d-employee-search"
                                type="text"
                                bind:value={dayOffSearchQuery}
                                placeholder={$t('hr.shift.search_placeholder')}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            />
                        </div>

                        <!-- Date Range Selection -->
                        <div class="flex gap-2">
                            <div class="w-36">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-d-start-date">{$t('hr.startDate')}</label>
                                <input 
                                    type="date" 
                                    id="do-d-start-date"
                                    bind:value={dayOffFilterStart}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 transition-all"
                                />
                            </div>
                            <div class="w-36">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-d-end-date">{$t('hr.endDate')}</label>
                                <input 
                                    type="date" 
                                    id="do-d-end-date"
                                    bind:value={dayOffFilterEnd}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 transition-all"
                                />
                            </div>
                        </div>

                        <!-- Load Button -->
                        <div class="self-end pb-0.5">
                            <button 
                                on:click={loadDayOffData}
                                class="px-6 py-2.5 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 shadow-lg shadow-emerald-200 transition-all flex items-center gap-2 h-[42px]"
                            >
                                <span class="text-sm">🔄</span>
                                Load Data
                            </button>
                        </div>
                    </div>

                    <!-- Leave Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <!-- Action Button -->
                        <div class="px-6 py-4 border-b border-slate-200 flex items-center gap-3">
                            <button 
                                class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                                on:click={openDayOffEmployeeSelectModal}
                            >
                                <span>🏖️</span>
                                {$t('hr.shift.add_day_off_date')}
                            </button>
                            <p class="text-xs text-slate-500 font-semibold">{$t('hr.shift.click_to_assign_day_off')}</p>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if filteredDayOffsEmployees.length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">{$t('hr.shift.no_day_offs')}</p>
                                        <p class="text-slate-400 text-sm mt-2">{dayOffs.length === 0 ? $t('hr.shift.click_button_to_assign') : $t('hr.shift.try_adjusting_filters')}</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                    <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.fullName')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.branch')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.nationality')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.day_off_date')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">📝 {$t('common.description') || 'Description'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.document') || 'Document'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">✅ {$locale === 'ar' ? 'موافق' : 'Approved'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">❌ {$locale === 'ar' ? 'مرفوض' : 'Rejected'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">⏳ {$locale === 'ar' ? 'معلق' : 'Pending'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400"> {$t('hr.shift.deduction') || 'Deduction'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">🖨️ {$locale === 'ar' ? 'طباعة' : 'Print'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.action')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each filteredDayOffsEmployees as dayOff, index (dayOff.id)}
                                            <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{formatEmployeeNameDisplay(dayOff)}</div>
                                                    <div class="text-xs text-slate-400">{dayOff.employee_id}</div>
                                                    <div class="text-xs text-slate-700 mt-0.5">{$locale === 'ar' ? (dayOff.reason_ar || dayOff.reason_en) : (dayOff.reason_en || dayOff.reason_ar)}</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{$locale === 'ar' ? (dayOff.branch_name_ar || dayOff.branch_name_en) : dayOff.branch_name_en}</div>
                                                    {#if ($locale === 'ar' ? (dayOff.branch_location_ar || dayOff.branch_location_en) : dayOff.branch_location_en)}
                                                        <div class="text-xs text-slate-400">{$locale === 'ar' ? (dayOff.branch_location_ar || dayOff.branch_location_en) : dayOff.branch_location_en}</div>
                                                    {/if}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{formatNationalityDisplay(dayOff)}</div>
                                                    <div class="text-xs text-slate-400">{getSponsorshipStatusDisplay(dayOff.sponsorship_status).text}</div>
                                                </td>
                                                <!-- Date column: show range + View Dates button for grouped, single date otherwise -->
                                                <td class="px-4 py-3 text-sm font-mono text-slate-800">
                                                    {#if dayOff._dayCount && dayOff._dayCount > 1}
                                                        <div class="flex flex-col gap-1">
                                                            <span class="font-semibold">{formatDateDisplay(dayOff._dateFrom)} → {formatDateDisplay(dayOff._dateTo)}</span>
                                                            <button
                                                                class="inline-flex items-center gap-1 mt-1 px-2.5 py-1 rounded-lg text-[11px] font-bold bg-blue-50 text-blue-600 border border-blue-200 hover:bg-blue-100 hover:shadow transition-all"
                                                                on:click={() => openViewDatesPopup(dayOff)}
                                                            >
                                                                📅 {$locale === 'ar' ? 'عرض التواريخ' : 'View Dates'} ({dayOff._dayCount})
                                                            </button>
                                                        </div>
                                                    {:else}
                                                        {formatDateDisplay(dayOff.day_off_date)}
                                                    {/if}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    {#if dayOff.description}
                                                        <button
                                                            class="inline-flex items-center justify-center gap-1 px-3 py-1 bg-indigo-100 text-indigo-700 rounded-lg hover:bg-indigo-200 transition-all font-bold text-xs"
                                                            on:click={() => { descriptionPopupText = dayOff.description; descriptionPopupEmployee = ($locale === 'ar' ? (dayOff.employee_name_ar || dayOff.employee_name_en) : dayOff.employee_name_en); showDescriptionPopup = true; }}
                                                        >
                                                            <span>📝</span>
                                                            {$t('common.view') || 'View'}
                                                        </button>
                                                    {:else}
                                                        <span class="text-slate-300">-</span>
                                                    {/if}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    {#if dayOff.document_url}
                                                        <button 
                                                            class="inline-flex items-center justify-center gap-1 px-3 py-1 bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 transition-all font-bold text-xs"
                                                            on:click={() => window.open(dayOff.document_url, '_blank')}
                                                        >
                                                            <span>📄</span>
                                                            {$t('common.view') || 'View'}
                                                        </button>
                                                    {:else}
                                                        <span class="text-slate-400 text-xs italic">{$t('common.no_document') || 'No Document'}</span>
                                                    {/if}
                                                </td>
                                                <!-- Approved column -->
                                                <td class="px-4 py-3 text-sm text-center">
                                                    {#if dayOff._dayCount && dayOff._dayCount > 1 && dayOff._statusCounts}
                                                        {#if dayOff._statusCounts['approved']}
                                                            <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-800">{dayOff._statusCounts['approved']}</span>
                                                        {:else}
                                                            <span class="text-slate-300">-</span>
                                                        {/if}
                                                    {:else}
                                                        {#if dayOff.approval_status === 'approved'}
                                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-800">1</span>
                                                        {:else}
                                                            <span class="text-slate-300">-</span>
                                                        {/if}
                                                    {/if}
                                                </td>
                                                <!-- Rejected column -->
                                                <td class="px-4 py-3 text-sm text-center">
                                                    {#if dayOff._dayCount && dayOff._dayCount > 1 && dayOff._statusCounts}
                                                        {#if dayOff._statusCounts['rejected']}
                                                            <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold bg-red-100 text-red-800">{dayOff._statusCounts['rejected']}</span>
                                                        {:else}
                                                            <span class="text-slate-300">-</span>
                                                        {/if}
                                                    {:else}
                                                        {#if dayOff.approval_status === 'rejected'}
                                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-red-100 text-red-800">1</span>
                                                        {:else}
                                                            <span class="text-slate-300">-</span>
                                                        {/if}
                                                    {/if}
                                                </td>
                                                <!-- Pending column -->
                                                <td class="px-4 py-3 text-sm text-center">
                                                    {#if dayOff._dayCount && dayOff._dayCount > 1 && dayOff._statusCounts}
                                                        {#if dayOff._statusCounts['pending']}
                                                            <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold bg-orange-100 text-orange-800">{dayOff._statusCounts['pending']}</span>
                                                        {:else}
                                                            <span class="text-slate-300">-</span>
                                                        {/if}
                                                    {:else}
                                                        {#if dayOff.approval_status === 'pending'}
                                                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-bold bg-orange-100 text-orange-800">1</span>
                                                        {:else}
                                                            <span class="text-slate-300">-</span>
                                                        {/if}
                                                    {/if}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    {#if dayOff._dayCount && dayOff._dayCount > 1 && dayOff._allDeductions}
                                                        <!-- Grouped: show deduction counts + button to manage -->
                                                        {@const deductCount = dayOff._allDeductions.filter((d) => d.is_deductible).length}
                                                        {@const noDeductCount = dayOff._allDeductions.length - deductCount}
                                                        <div class="flex justify-center">
                                                            <button 
                                                                class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-bold transition-all duration-200 hover:shadow-md bg-slate-50 border border-slate-200 hover:bg-slate-100"
                                                                on:click={() => openGroupedDeductionModal(dayOff)}
                                                                title={$t('hr.shift.toggle_deduction') || 'Manage Deduction'}
                                                            >
                                                                {#if deductCount > 0}
                                                                    <span class="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded-full text-[11px] font-bold bg-green-100 text-green-700">✅ {deductCount}</span>
                                                                {/if}
                                                                {#if noDeductCount > 0}
                                                                    <span class="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded-full text-[11px] font-bold bg-red-100 text-red-600">❌ {noDeductCount}</span>
                                                                {/if}
                                                            </button>
                                                        </div>
                                                    {:else}
                                                        <!-- Single: clickable green tick or red X -->
                                                        <button
                                                            class="text-lg font-bold cursor-pointer hover:scale-125 transition-transform"
                                                            on:click={() => updateDayOffDeduction(dayOff.id, !dayOff.is_deductible_on_salary)}
                                                            title={$t('hr.shift.toggle_deduction') || 'Toggle Deduction'}
                                                        >
                                                            {#if dayOff.is_deductible_on_salary}
                                                                <span class="text-green-600">✅</span>
                                                            {:else}
                                                                <span class="text-red-500">❌</span>
                                                            {/if}
                                                        </button>
                                                    {/if}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <!-- Print Button -->
                                                    <button 
                                                        class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-amber-500 text-white font-bold hover:bg-amber-600 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                        on:click={() => openLeaveRequestPrint(dayOff)}
                                                        title={$locale === 'ar' ? 'طباعة طلب الإجازة' : 'Print Leave Request'}
                                                    >
                                                        🖨️
                                                    </button>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <div class="flex items-center justify-center gap-2">
                                                        <!-- Edit Button -->
                                                        <button 
                                                            class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-blue-600 text-white font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                            on:click={() => {
                                                                selectedEmployeeId = dayOff.employee_id;
                                                                selectedDayOffStartDate = dayOff._dateFrom || dayOff.day_off_date;
                                                                selectedDayOffEndDate = dayOff._dateTo || dayOff.day_off_date;
                                                                // Load the leave reason from dayOffReasons array
                                                                if (dayOff.day_off_reason_id) {
                                                                    selectedDayOffReason = dayOffReasons.find(r => r.id === dayOff.day_off_reason_id) || null;
                                                                } else {
                                                                    selectedDayOffReason = null;
                                                                }
                                                                // Load existing document URL if present
                                                                existingDocumentUrl = dayOff.document_url || null;
                                                                showModal = true;
                                                            }}
                                                            title={$t('common.edit')}
                                                        >
                                                            ✎️
                                                        </button>
                                                        
                                                        <!-- Delete Button — opens modal for grouped, confirm for single -->
                                                        <button 
                                                            class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                            on:click={() => {
                                                                if (dayOff._dayCount && dayOff._dayCount > 1) {
                                                                    openGroupedDeleteModal(dayOff);
                                                                } else {
                                                                    deleteDayOff(dayOff.id, dayOff.employee_id, dayOff.day_off_date);
                                                                }
                                                            }}
                                                            title={$t('hr.shift.delete_day_off_tooltip')}
                                                        >
                                                            🗑️
                                                        </button>
                                                    </div>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            {/if}
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('hr.shift.showing_day_offs', { current: filteredDayOffsEmployees.length, total: groupedDayOffs.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Leave (weekday-wise)'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('hr.shift.loading_day_off_weekday_data')}</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadDayOffWeekdayData}
                        >
                            {$t('common.retry')}
                        </button>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-w-branch-filter">{$t('hr.shift.filter_branch')}</label>
                            <select 
                                id="do-w-branch-filter"
                                bind:value={dayOffWeekdayBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_branches')}</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' 
                                            ? `${branch.name_ar || branch.name_en}${branch.location_ar ? ' (' + branch.location_ar + ')' : ''}`
                                            : `${branch.name_en || branch.name || 'Unnamed'}${branch.location_en ? ' (' + branch.location_en + ')' : ''}`}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-w-nationality-filter">{$t('hr.shift.filter_nationality')}</label>
                            <select 
                                id="do-w-nationality-filter"
                                bind:value={dayOffWeekdayNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_nationalities')}</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id} style="color: #000000 !important; background-color: #ffffff !important;">
                                        {$locale === 'ar' ? (nationality.name_ar || nationality.name_en) : (nationality.name_en || nationality.name || 'Unnamed')}
                                    </option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employment Status Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-w-status-filter">{$t('employeeFiles.employmentStatus')}</label>
                            <select 
                                id="do-w-status-filter"
                                bind:value={dayOffWeekdayEmploymentStatusFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                                style="color: #000000 !important; background-color: #ffffff !important;"
                            >
                                <option value="" style="color: #000000 !important; background-color: #ffffff !important;">{$t('hr.shift.all_statuses') || 'All Statuses'}</option>
                                {#each availableEmploymentStatuses as status}
                                    <option value={status.id} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status.id).text}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="do-w-employee-search">{$t('hr.shift.search_employee')}</label>
                            <input 
                                id="do-w-employee-search"
                                type="text"
                                bind:value={dayOffWeekdaySearchQuery}
                                placeholder={$t('hr.shift.search_placeholder')}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            />
                        </div>
                    </div>

                    <!-- Leave Weekday Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <!-- Action Button -->
                        <div class="px-6 py-4 border-b border-slate-200 flex items-center gap-3">
                            <button 
                                class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                                on:click={openDayOffWeekdayEmployeeSelectModal}
                            >
                                <span>📋</span>
                                {$t('hr.shift.add_day_off_weekday')}
                            </button>
                            <p class="text-xs text-slate-500 font-semibold">{$t('hr.shift.click_to_assign_recurring')}</p>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if filteredDayOffsWeekdayEmployees.length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">{$t('hr.shift.no_day_offs')}</p>
                                        <p class="text-slate-400 text-sm mt-2">{dayOffsWeekday.length === 0 ? $t('hr.shift.click_button_to_assign') : $t('hr.shift.try_adjusting_filters')}</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                    <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.fullName')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.branch')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.nationality')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.day_off_weekday')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.action')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each filteredDayOffsWeekdayEmployees as dayOff, index}
                                            <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{formatEmployeeNameDisplay(dayOff)}</div>
                                                    <div class="text-xs text-slate-400">{dayOff.employee_id}</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{$locale === 'ar' ? (dayOff.branch_name_ar || dayOff.branch_name_en) : dayOff.branch_name_en}</div>
                                                    {#if ($locale === 'ar' ? (dayOff.branch_location_ar || dayOff.branch_location_en) : dayOff.branch_location_en)}
                                                        <div class="text-xs text-slate-400">{$locale === 'ar' ? (dayOff.branch_location_ar || dayOff.branch_location_en) : dayOff.branch_location_en}</div>
                                                    {/if}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{formatNationalityDisplay(dayOff)}</div>
                                                    <div class="text-xs text-slate-400">{getSponsorshipStatusDisplay(dayOff.sponsorship_status).text}</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{weekdayNames[dayOff.day_off_weekday]}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <button 
                                                        class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                        on:click={() => deleteDayOffWeekday(dayOff.id, dayOff.employee_id, dayOff.day_off_weekday)}
                                                        title={$t('hr.shift.delete_day_off_tooltip')}
                                                    >
                                                        🗑️
                                                    </button>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            {/if}
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('hr.shift.showing_day_offs', { current: filteredDayOffsWeekdayEmployees.length, total: dayOffsWeekday.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Leave Reasons'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('hr.shift.loading_day_off_reasons')}</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadDayOffReasons}
                        >
                            {$t('common.retry')}
                        </button>
                    </div>
                {:else}
                    <!-- Leave Reasons Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <!-- Action Button -->
                        <div class="px-6 py-4 border-b border-slate-200 flex items-center gap-3">
                            <button 
                                class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                                on:click={() => openReasonModal()}
                            >
                                <span>➕</span>
                                {$t('hr.shift.add_reason')}
                            </button>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if dayOffReasons.length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">{$t('hr.shift.no_day_off_reasons')}</p>
                                        <p class="text-slate-400 text-sm mt-2">{$t('hr.shift.click_button_to_add')}</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                    <thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('hr.employeeId')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('hr.shift.reason_name_en')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('hr.shift.reason_name_ar')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('hr.shift.deductible')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('common.documentRequired')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('common.action')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each dayOffReasons as reason, index}
                                            <tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{reason.id}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{reason.reason_en}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700" dir="rtl">{reason.reason_ar}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {reason.is_deductible ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
                                                        {reason.is_deductible ? '✓ ' + $t('common.yes') : '✗ ' + $t('common.no')}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {reason.is_document_mandatory ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'}">
                                                        {reason.is_document_mandatory ? '✓ ' + $t('common.yes') : '✗ ' + $t('common.no')}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <div class="flex gap-2 justify-center">
                                                        <button 
                                                            class="px-3 py-1 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition text-xs font-semibold"
                                                            on:click={() => openReasonModal(reason)}
                                                        >
                                                            ✏️ {$t('common.edit')}
                                                        </button>
                                                        <button 
                                                            class="px-3 py-1 bg-red-600 text-white rounded-lg hover:bg-red-700 transition text-xs font-semibold"
                                                            on:click={() => deleteReason(reason.id)}
                                                        >
                                                            🗑️ {$t('common.delete')}
                                                        </button>
                                                    </div>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            {/if}
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('hr.shift.showing_total_reasons', { count: dayOffReasons.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Official Holidays'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('hr.shift.loading_official_holidays')}</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadOfficialHolidays}
                        >
                            {$t('common.retry')}
                        </button>
                    </div>
                {:else}
                    <!-- Search -->
                    <div class="mb-4 flex gap-3">
                        <div class="flex-1 max-w-md">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="oh-search">{$t('hr.shift.search_employee')}</label>
                            <input 
                                id="oh-search"
                                type="text"
                                bind:value={officialHolidaySearchQuery}
                                placeholder={$t('hr.shift.official_holidays_search')}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                            />
                        </div>
                    </div>

                    <!-- Official Holidays Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <!-- Action Button -->
                        <div class="px-6 py-4 border-b border-slate-200 flex items-center gap-3">
                            <button 
                                class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                                on:click={() => openOfficialHolidayModal()}
                            >
                                <span>🏛️</span>
                                {$t('hr.shift.add_official_holiday')}
                            </button>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if filteredOfficialHolidays.length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">{$t('hr.shift.no_official_holidays')}</p>
                                        <p class="text-slate-400 text-sm mt-2">{officialHolidays.length === 0 ? $t('hr.shift.click_to_add_official_holiday') : $t('hr.shift.try_adjusting_filters')}</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                    <thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('hr.shift.holiday_date')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('hr.shift.official_holiday_name_en')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('hr.shift.official_holiday_name_ar')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('hr.shift.assigned_employees_col')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('common.action')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each filteredOfficialHolidays as holiday, index}
                                            <tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{formatDateDisplay(holiday.holiday_date)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{holiday.name_en}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700" dir="rtl">{holiday.name_ar}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <button 
                                                        class="inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-bold transition {holiday.assigned_count ? 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}"
                                                        on:click={() => openAssignEmployeesModal(holiday)}
                                                    >
                                                        👥 {holiday.assigned_count || 0}
                                                    </button>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <div class="flex gap-2 justify-center">
                                                        <button 
                                                            class="px-3 py-1 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition text-xs font-semibold"
                                                            on:click={() => openAssignEmployeesModal(holiday)}
                                                        >
                                                            👥 {$t('hr.shift.assign_employees')}
                                                        </button>
                                                        <button 
                                                            class="px-3 py-1 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition text-xs font-semibold"
                                                            on:click={() => openOfficialHolidayModal(holiday)}
                                                        >
                                                            ✏️ {$t('common.edit')}
                                                        </button>
                                                        <button 
                                                            class="px-3 py-1 bg-red-600 text-white rounded-lg hover:bg-red-700 transition text-xs font-semibold"
                                                            on:click={() => deleteOfficialHoliday(holiday.id)}
                                                        >
                                                            🗑️ {$t('common.delete')}
                                                        </button>
                                                    </div>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            {/if}
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('hr.shift.showing_official_holidays', { current: filteredOfficialHolidays.length, total: officialHolidays.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Multi-Shift Setup'}
                <!-- Multi-Shift Setup Tab -->
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-purple-200 border-t-purple-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('hr.shift.loading_employees')}</p>
                        </div>
                    </div>
                {:else}
                    <!-- Action Buttons -->
                    <div class="mb-4 flex flex-wrap gap-3">
                        <button
                            class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl font-black text-sm text-white bg-purple-600 hover:bg-purple-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                            on:click={() => openMultiShiftEmployeeSelect('regular')}
                        >
                            <span>🔁</span>
                            {$t('hr.shift.multiShift.add_regular')}
                        </button>
                        <button
                            class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl font-black text-sm text-white bg-indigo-600 hover:bg-indigo-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                            on:click={() => openMultiShiftEmployeeSelect('date')}
                        >
                            <span>📆</span>
                            {$t('hr.shift.multiShift.add_special_date')}
                        </button>
                        <button
                            class="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl font-black text-sm text-white bg-violet-600 hover:bg-violet-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                            on:click={() => openMultiShiftEmployeeSelect('day')}
                        >
                            <span>📅</span>
                            {$t('hr.shift.multiShift.add_special_day')}
                        </button>
                    </div>

                    <!-- Sub-tabs for Regular / Date-wise / Day-wise -->
                    <div class="mb-4 flex gap-2">
                        <button
                            class="px-4 py-2 rounded-lg font-bold text-sm transition-all {multiShiftActiveSubTab === 'regular' ? 'bg-purple-600 text-white shadow-lg' : 'bg-white text-slate-600 border border-slate-200 hover:bg-purple-50'}"
                            on:click={() => multiShiftActiveSubTab = 'regular'}
                        >
                            🔁 {$t('hr.shift.multiShift.regular_tab')} ({multiShiftRegularData.length})
                        </button>
                        <button
                            class="px-4 py-2 rounded-lg font-bold text-sm transition-all {multiShiftActiveSubTab === 'date' ? 'bg-indigo-600 text-white shadow-lg' : 'bg-white text-slate-600 border border-slate-200 hover:bg-indigo-50'}"
                            on:click={() => multiShiftActiveSubTab = 'date'}
                        >
                            📆 {$t('hr.shift.multiShift.date_tab')} ({multiShiftDateData.length})
                        </button>
                        <button
                            class="px-4 py-2 rounded-lg font-bold text-sm transition-all {multiShiftActiveSubTab === 'day' ? 'bg-violet-600 text-white shadow-lg' : 'bg-white text-slate-600 border border-slate-200 hover:bg-violet-50'}"
                            on:click={() => multiShiftActiveSubTab = 'day'}
                        >
                            📅 {$t('hr.shift.multiShift.day_tab')} ({multiShiftWeekdayData.length})
                        </button>
                    </div>

                    <!-- Multi-Shift Table -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        {#if (multiShiftActiveSubTab === 'regular' ? multiShiftRegularData : multiShiftActiveSubTab === 'date' ? multiShiftDateData : multiShiftWeekdayData).length === 0}
                            <div class="flex items-center justify-center h-64">
                                <div class="text-center">
                                    <div class="text-5xl mb-4">📭</div>
                                    <p class="text-slate-600 font-semibold">{$t('hr.shift.multiShift.no_multi_shifts')}</p>
                                    <p class="text-slate-400 text-sm mt-2">{$t('hr.shift.multiShift.click_to_add')}</p>
                                </div>
                            </div>
                        {:else}
                            <div class="overflow-x-auto flex-1">
                                <table class="w-full border-collapse [&_th]:border-x [&_th]:border-purple-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                    <thead class="sticky top-0 bg-purple-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.employee')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.start')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.end')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.hours')}</th>
                                            {#if multiShiftActiveSubTab === 'date'}
                                                <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.date_from')}</th>
                                                <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.date_to')}</th>
                                            {/if}
                                            {#if multiShiftActiveSubTab === 'day'}
                                                <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.select_day')}</th>
                                            {/if}
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.overlap')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.shift.multiShift.actions')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each (multiShiftActiveSubTab === 'regular' ? multiShiftRegularData : multiShiftActiveSubTab === 'date' ? multiShiftDateData : multiShiftWeekdayData) as record, index}
                                            <tr class="hover:bg-purple-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm text-slate-700">
                                                    <div>{$locale === 'ar' ? (record.employee_name_ar || record.employee_name_en) : (record.employee_name_en || record.employee_id)}</div>
                                                    <div class="text-xs text-slate-400">{record.employee_id}</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center font-mono">
                                                    <div class="text-slate-800">{formatTimeTo12Hour(record.shift_start_time)}</div>
                                                    <div class="text-xs text-slate-400">{$t('hr.shift.multiShift.buffer')}: {record.shift_start_buffer}h</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center font-mono">
                                                    <div class="text-slate-800">{formatTimeTo12Hour(record.shift_end_time)}</div>
                                                    <div class="text-xs text-slate-400">{$t('hr.shift.multiShift.buffer')}: {record.shift_end_buffer}h</div>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="font-bold text-purple-700">{record.working_hours}h</span>
                                                </td>
                                                {#if multiShiftActiveSubTab === 'date'}
                                                    <td class="px-4 py-3 text-sm text-center font-mono text-slate-700">{record.date_from}</td>
                                                    <td class="px-4 py-3 text-sm text-center font-mono text-slate-700">{record.date_to}</td>
                                                {/if}
                                                {#if multiShiftActiveSubTab === 'day'}
                                                    <td class="px-4 py-3 text-sm text-center font-semibold text-slate-700">{weekdayNames[record.weekday || 0]}</td>
                                                {/if}
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-block px-2 py-0.5 rounded-full text-[10px] font-black {record.is_shift_overlapping_next_day ? 'bg-purple-200 text-purple-800' : 'bg-slate-200 text-slate-800'}">
                                                        {record.is_shift_overlapping_next_day ? '✓ Yes' : '✗ No'}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <div class="flex items-center justify-center gap-2">
                                                        <button
                                                            class="p-1.5 rounded-lg bg-blue-50 hover:bg-blue-100 text-blue-600 transition-all"
                                                            on:click={() => openEditMultiShift(record, multiShiftActiveSubTab)}
                                                            title={$t('hr.shift.edit_tooltip')}
                                                        >✏️</button>
                                                        <button
                                                            class="p-1.5 rounded-lg bg-red-50 hover:bg-red-100 text-red-600 transition-all"
                                                            on:click={() => deleteMultiShift(record.id || 0, multiShiftActiveSubTab)}
                                                            title={$t('hr.shift.delete_tooltip')}
                                                        >🗑️</button>
                                                    </div>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            </div>
                        {/if}
                    </div>
                {/if}
            {:else}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200 transition-all duration-700 hover:bg-white/60">
                    <div class="relative mb-10">
                        <div class="absolute inset-0 rounded-full blur-2xl {tabs.find(t => t.id === activeTab)?.color === 'green' ? 'bg-emerald-400/30' : 'bg-orange-400/30'}"></div>
                        <div class="w-32 h-32 relative rounded-full flex items-center justify-center bg-white border border-slate-100 shadow-[inset_0_2px_4px_rgba(0,0,0,0.05),0_10px_20px_rgba(0,0,0,0.05)]">
                             <span class="text-5xl transform transition-all duration-700 hover:scale-110">
                                 {tabs.find(t => t.id === activeTab)?.icon}
                             </span>
                        </div>
                    </div>

                    <h2 class="text-4xl font-black text-slate-900 mb-4 tracking-tight">
                        {tabs.find(t => t.id === activeTab)?.label}
                    </h2>
                    
                    <div class="flex items-center gap-4 mb-12">
                        <div class="h-[3px] w-16 rounded-full {tabs.find(t => t.id === activeTab)?.color === 'green' ? 'bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]' : 'bg-orange-500 shadow-[0_0_10px_rgba(249,115,22,0.5)]'}"></div>
                        <p class="text-slate-400 font-black text-[10px] uppercase tracking-[0.4em]">{$t('hr.shift.ready_for_config')}</p>
                        <div class="h-[3px] w-16 rounded-full {tabs.find(t => t.id === activeTab)?.color === 'green' ? 'bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]' : 'bg-orange-500 shadow-[0_0_10px_rgba(249,115,22,0.5)]'}"></div>
                    </div>
                </div>
            {/if}
        </div>
    </div>
</div>

<!-- Modal Overlay and Popup -->
{#if showModal}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50 animate-in fade-in duration-200">
        <div class="bg-white rounded-3xl shadow-2xl max-w-md w-full mx-4 overflow-hidden animate-in scale-in duration-300 origin-center">
            <!-- Modal Header -->
            <div class="bg-gradient-to-r {activeTab === 'Regular Shift' ? 'from-emerald-600 to-emerald-500' : activeTab === 'Leave (date-wise)' || activeTab === 'Leave (weekday-wise)' ? 'from-emerald-600 to-emerald-500' : 'from-orange-600 to-orange-500'} px-6 py-4">
                <h3 class="text-xl font-black text-white">
                    {activeTab === 'Regular Shift' ? $t('hr.shift.configure_regular_shift') : activeTab === 'Special Shift (weekday-wise)' ? $t('hr.shift.configure_special_shift_weekday') : activeTab === 'Special Shift (date-wise)' ? $t('hr.shift.configure_special_shift_date') : activeTab === 'Leave (date-wise)' ? $t('hr.shift.assign_day_off_date') : $t('hr.shift.assign_day_off_weekday')}
                </h3>
                <p class="{activeTab === 'Regular Shift' || activeTab === 'Leave (date-wise)' || activeTab === 'Leave (weekday-wise)' ? 'text-emerald-100' : 'text-orange-100'} text-sm mt-1">{$t('hr.employeeId')}: {selectedEmployeeId}</p>
            </div>

            <!-- Modal Body -->
            <div class="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
                {#if activeTab === 'Special Shift (weekday-wise)' && 'weekday' in formData}
                    <!-- Weekday Selection -->
                    <div>
                        <label for="weekday-select" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.select_weekday')}</label>
                        <select 
                            id="weekday-select"
                            bind:value={formData.weekday}
                            on:change={onWeekdayChange}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                            style="color: #000000 !important; background-color: #ffffff !important;"
                        >
                            {#each weekdayNames as day, index}
                                <option value={index} style="color: #000000 !important; background-color: #ffffff !important;">{day}</option>
                            {/each}
                        </select>
                    </div>
                {/if}

                {#if activeTab === 'Special Shift (date-wise)' && 'shift_date' in formData}
                    {#if isRangeSpecialShift}
                        <!-- Special Shift Start Date Selection -->
                        <div>
                            <label for="spec-shift-start-date-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.start_date')}</label>
                            <input 
                                id="spec-shift-start-date-input"
                                type="date" 
                                bind:value={specialShiftStartDate}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                            />
                        </div>

                        <!-- Special Shift End Date Selection -->
                        <div>
                            <label for="spec-shift-end-date-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.end_date')}</label>
                            <input 
                                id="spec-shift-end-date-input"
                                type="date" 
                                bind:value={specialShiftEndDate}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                            />
                        </div>
                    {:else}
                        <!-- Date Selection (Single) -->
                        <div>
                            <label for="shift-date-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.shift_date')}</label>
                            <input 
                                id="shift-date-input"
                                type="date" 
                                bind:value={formData.shift_date}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                            />
                        </div>
                    {/if}
                {/if}

                {#if activeTab === 'Leave (date-wise)'}
                    <!-- Leave Start Date Selection -->
                    <div>
                        <label for="dayoff-start-date-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.start_date')}</label>
                        <input 
                            id="dayoff-start-date-input"
                            type="date" 
                            bind:value={selectedDayOffStartDate}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                        />
                    </div>

                    <!-- Leave End Date Selection -->
                    <div>
                        <label for="dayoff-end-date-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.end_date')}</label>
                        <input 
                            id="dayoff-end-date-input"
                            type="date" 
                            bind:value={selectedDayOffEndDate}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                        />
                    </div>

                    <!-- Search Reason Button -->
                    <div>
                        <button 
                            type="button"
                            on:click={openReasonSearchModal}
                            class="w-full px-4 py-3 bg-blue-600 text-white rounded-lg font-bold hover:bg-blue-700 transition"
                        >
                            🔍 {$t('hr.shift.search_reason')}
                        </button>
                    </div>

                    <!-- Selected Reason Display -->
                    {#if selectedDayOffReason}
                        <div class="bg-blue-50 border-2 border-blue-200 rounded-lg p-4">
                            <p class="text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.selected_reason')}:</p>
                            <p class="text-base font-semibold text-slate-800">{selectedDayOffReason.reason_en}</p>
                            <p class="text-base font-semibold text-slate-700" dir="rtl">{selectedDayOffReason.reason_ar}</p>
                            
                            <!-- Deductible Status -->
                            <div class="mt-3 flex gap-2 flex-wrap">
                                <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {selectedDayOffReason.is_deductible ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
                                    {selectedDayOffReason.is_deductible ? '✓ ' + $t('hr.shift.deductible_yes') : '✗ ' + $t('hr.shift.deductible_no')}
                                </span>
                                <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {selectedDayOffReason.is_document_mandatory ? 'bg-orange-100 text-orange-800' : 'bg-gray-100 text-gray-800'}">
                                    {selectedDayOffReason.is_document_mandatory ? '📄 ' + $t('hr.shift.document_required_short') : $t('hr.shift.document_optional')}
                                </span>
                            </div>
                        </div>

                        <!-- Document Upload -->
                        {#if selectedDayOffReason.is_document_mandatory || true}
                            <div>
                                <label for="doc-upload" class="block text-sm font-bold text-slate-700 mb-2">
                                    {selectedDayOffReason.is_document_mandatory ? '📄 ' + $t('hr.shift.upload_document_required') : '📄 ' + $t('hr.shift.upload_document_optional')}
                                </label>
                                <input 
                                    id="doc-upload"
                                    type="file" 
                                    on:change={handleDocumentSelect}
                                    class="w-full px-3 py-2 border-2 border-dashed border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                />
                                {#if documentFile}
                                    <p class="text-xs text-slate-600 mt-2">{$t('hr.shift.selected_file')}: {documentFile.name}</p>
                                    {#if isUploadingDocument}
                                        <div class="w-full bg-slate-200 rounded-lg h-2 mt-2">
                                            <div class="bg-emerald-600 h-2 rounded-lg transition-all" style="width: {documentUploadProgress}%"></div>
                                        </div>
                                    {/if}
                                {/if}
                            </div>
                        {/if}
                    {/if}

                    <!-- Description Field (Optional) -->
                    {#if selectedDayOffReason}
                        <div>
                            <label for="day-off-description" class="block text-sm font-bold text-slate-700 mb-2">📝 {$t('hr.shift.description_optional')}</label>
                            <textarea 
                                id="day-off-description"
                                bind:value={dayOffDescription}
                                placeholder={$t('hr.shift.enter_description')}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                rows="4"
                            ></textarea>
                            <p class="text-xs text-slate-500 mt-1">{$t('hr.shift.description_info')}</p>
                        </div>
                    {/if}
                {/if}

                {#if activeTab === 'Leave (weekday-wise)'}
                    <!-- Leave Weekday Selection -->
                    <div>
                        <label for="dayoff-weekday-select" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.day_off_weekday')}</label>
                        <select 
                            id="dayoff-weekday-select"
                            bind:value={selectedDayOffWeekday}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                            style="color: #000000 !important; background-color: #ffffff !important;"
                        >
                            {#each weekdayNames as day, index}
                                <option value={index} style="color: #000000 !important; background-color: #ffffff !important;">{day}</option>
                            {/each}
                        </select>
                    </div>
                {/if}

                {#if activeTab !== 'Leave (date-wise)' && activeTab !== 'Leave (weekday-wise)'}
                    <!-- Shift Start Time -->
                    <div>
                        <label for="start-time-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.shift_start_time')}</label>
                        <div class="flex gap-2">
                            <select 
                                bind:value={startHour12}
                                on:change={updateStartTime24h}
                                class="flex-1 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 {activeTab === 'Regular Shift' ? 'focus:ring-emerald-500' : 'focus:ring-orange-500'}"
                            >
                                {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                                    <option value={h}>{h}</option>
                                {/each}
                            </select>
                            <select 
                                bind:value={startMinute12}
                                on:change={updateStartTime24h}
                                class="flex-1 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 {activeTab === 'Regular Shift' ? 'focus:ring-emerald-500' : 'focus:ring-orange-500'}"
                            >
                                {#each Array.from({length: 60}, (_, i) => String(i).padStart(2, '0')) as m}
                                    <option value={m}>{m}</option>
                                {/each}
                            </select>
                            <select 
                                bind:value={startPeriod12}
                                on:change={updateStartTime24h}
                                class="w-20 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 {activeTab === 'Regular Shift' ? 'focus:ring-emerald-500' : 'focus:ring-orange-500'}"
                            >
                                <option value="AM">{$t('common.am')}</option>
                                <option value="PM">{$t('common.pm')}</option>
                            </select>
                        </div>
                    </div>

                    <!-- Start Time Buffer -->
                    <div>
                        <label for="start-buffer-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.start_buffer_hours')}</label>
                        {#if activeTab === 'Regular Shift'}
                            <input 
                                id="start-buffer-input"
                                type="number" 
                                bind:value={formData.shift_start_buffer}
                                step="0.5"
                                min="0"
                                max="24"
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                            />
                        {:else}
                            <input 
                                id="start-buffer-input"
                                type="number" 
                                bind:value={formData.shift_start_buffer}
                                step="0.5"
                                min="0"
                                max="24"
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                            />
                        {/if}
                    </div>

                    <!-- Shift End Time -->
                    <div>
                        <label for="end-time-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.shift_end_time')}</label>
                        <div class="flex gap-2">
                            <select 
                                bind:value={endHour12}
                                on:change={updateEndTime24h}
                                class="flex-1 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 {activeTab === 'Regular Shift' ? 'focus:ring-emerald-500' : 'focus:ring-orange-500'}"
                            >
                                {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                                    <option value={h}>{h}</option>
                                {/each}
                            </select>
                            <select 
                                bind:value={endMinute12}
                                on:change={updateEndTime24h}
                                class="flex-1 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 {activeTab === 'Regular Shift' ? 'focus:ring-emerald-500' : 'focus:ring-orange-500'}"
                            >
                                {#each Array.from({length: 60}, (_, i) => String(i).padStart(2, '0')) as m}
                                    <option value={m}>{m}</option>
                                {/each}
                            </select>
                            <select 
                                bind:value={endPeriod12}
                                on:change={updateEndTime24h}
                                class="w-20 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 {activeTab === 'Regular Shift' ? 'focus:ring-emerald-500' : 'focus:ring-orange-500'}"
                            >
                                <option value="AM">{$t('common.am')}</option>
                                <option value="PM">{$t('common.pm')}</option>
                            </select>
                        </div>
                    </div>

                    <!-- End Time Buffer -->
                    <div>
                        <label for="end-buffer-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.end_buffer_hours')}</label>
                        {#if activeTab === 'Regular Shift'}
                            <input 
                                id="end-buffer-input"
                                type="number" 
                                bind:value={formData.shift_end_buffer}
                                step="0.5"
                                min="0"
                                max="24"
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                            />
                        {:else}
                            <input 
                                id="end-buffer-input"
                                type="number" 
                                bind:value={formData.shift_end_buffer}
                                step="0.5"
                                min="0"
                                max="24"
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                            />
                        {/if}
                    </div>

                    <!-- Overlapping Checkbox -->
                    <div class="flex items-center gap-3 py-2">
                        {#if activeTab === 'Regular Shift'}
                            <input 
                                type="checkbox" 
                                bind:checked={formData.is_shift_overlapping_next_day}
                                id="overlapping"
                                class="w-5 h-5 rounded border-slate-300 text-emerald-600 focus:ring-2 focus:ring-emerald-500 cursor-pointer"
                            />
                        {:else}
                            <input 
                                type="checkbox" 
                                bind:checked={formData.is_shift_overlapping_next_day}
                                id="overlapping"
                                class="w-5 h-5 rounded border-slate-300 text-orange-600 focus:ring-2 focus:ring-orange-500 cursor-pointer"
                            />
                        {/if}
                        <label for="overlapping" class="text-sm font-bold text-slate-700 cursor-pointer">
                            {$t('hr.shift.shift_overlaps_next_day')}
                        </label>
                    </div>
                {/if}
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button 
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={closeModal}
                    disabled={isSaving}
                >
                    {$t('common.cancel')}
                </button>
                {#if activeTab === 'Regular Shift' || activeTab === 'Leave (date-wise)' || activeTab === 'Leave (weekday-wise)'}
                    <button 
                        class="px-6 py-2 rounded-lg font-black text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                        on:click={activeTab === 'Leave (date-wise)' ? saveDayOffWithApproval : activeTab === 'Leave (weekday-wise)' ? saveDayOffWeekday : saveShiftData}
                        disabled={isSaving}
                    >
                        {isSaving ? $t('common.saving') : $t('common.save')}
                    </button>
                {:else}
                    <button 
                        class="px-6 py-2 rounded-lg font-black text-white bg-orange-600 hover:bg-orange-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                        on:click={saveShiftData}
                        disabled={isSaving}
                    >
                        {isSaving ? $t('common.saving') : $t('common.save')}
                    </button>
                {/if}
            </div>
        </div>
    </div>
{/if}

<!-- Employee Select Modal for Special Shift (date-wise) -->
{#if showEmployeeSelectModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center">
        <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden">
            <!-- Modal Header -->
            <div class="px-6 py-4 bg-gradient-to-r from-orange-600 to-orange-500 text-white">
                <h3 class="text-lg font-bold">{$t('hr.shift.select_employee')}</h3>
                <p class="text-orange-100 text-sm mt-1">{$t('hr.shift.choose_employee_special_shift_date')}</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Search Input -->
                <div>
                    <label for="employee-search-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.search_employee')}</label>
                    <input 
                        id="employee-search-input"
                        type="text" 
                        placeholder={$t('hr.shift.search_placeholder')}
                        bind:value={employeeSearchQuery}
                        on:input={onEmployeeSearchChange}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                    />
                </div>

                <!-- Employee List -->
                <div class="border border-slate-200 rounded-lg max-h-96 overflow-y-auto">
                    {#if employeesForDateWiseSelection.length === 0}
                        <div class="px-4 py-6 text-center text-slate-500 text-sm">
                            {$t('hr.shift.no_employees_found')}
                        </div>
                    {:else}
                        {#each employeesForDateWiseSelection as employee}
                            <button 
                                class="w-full text-left px-4 py-3 hover:bg-orange-50 border-b border-slate-100 last:border-b-0 transition-colors duration-200"
                                on:click={() => selectEmployeeForDateWise(employee.id)}
                            >
                                <div class="flex items-center justify-between">
                                    <div class="{$locale === 'ar' ? 'text-right' : 'text-left'}">
                                        <p class="font-semibold text-slate-900">{$locale === 'ar' ? (employee.employee_name_ar || employee.employee_name_en) : employee.employee_name_en}</p>
                                        <p class="text-xs text-slate-500">{employee.id} • {$locale === 'ar' ? (employee.branch_name_ar || employee.branch_name_en) : employee.branch_name_en}</p>
                                    </div>
                                    <div class="text-orange-600 font-bold">{$locale === 'ar' ? '←' : '→'}</div>
                                </div>
                            </button>
                        {/each}
                    {/if}
                </div>
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button 
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={closeEmployeeSelectModal}
                >
                    {$t('common.cancel')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Employee Select Modal for Leave -->
{#if showDayOffEmployeeSelectModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center">
        <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden">
            <!-- Modal Header -->
            <div class="px-6 py-4 bg-gradient-to-r from-emerald-600 to-emerald-500 text-white">
                <h3 class="text-lg font-bold">{$t('hr.shift.select_employee')}</h3>
                <p class="text-emerald-100 text-sm mt-1">{$t('hr.shift.choose_employee_day_off')}</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Search Input -->
                <div>
                    <label for="dayoff-employee-search-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.search_employee')}</label>
                    <input 
                        id="dayoff-employee-search-input"
                        type="text" 
                        placeholder={$t('hr.shift.search_placeholder')}
                        bind:value={employeeSearchQuery}
                        on:input={onEmployeeSearchChange}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                    />
                </div>

                <!-- Employee List -->
                <div class="border border-slate-200 rounded-lg max-h-96 overflow-y-auto">
                    {#if employeesForDateWiseSelection.length === 0}
                        <div class="px-4 py-6 text-center text-slate-500 text-sm">
                            {$t('hr.shift.no_employees_found')}
                        </div>
                    {:else}
                        {#each employeesForDateWiseSelection as employee}
                            <button 
                                class="w-full text-left px-4 py-3 hover:bg-emerald-50 border-b border-slate-100 last:border-b-0 transition-colors duration-200"
                                on:click={() => selectEmployeeForDayOff(employee.id)}
                            >
                                <div class="flex items-center justify-between">
                                    <div class="{$locale === 'ar' ? 'text-right' : 'text-left'}">
                                        <p class="font-semibold text-slate-900">{$locale === 'ar' ? (employee.employee_name_ar || employee.employee_name_en) : employee.employee_name_en}</p>
                                        <p class="text-xs text-slate-500">{employee.id} • {$locale === 'ar' ? (employee.branch_name_ar || employee.branch_name_en) : employee.branch_name_en}</p>
                                    </div>
                                    <div class="text-emerald-600 font-bold">{$locale === 'ar' ? '←' : '→'}</div>
                                </div>
                            </button>
                        {/each}
                    {/if}
                </div>
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button 
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={closeDayOffEmployeeSelectModal}
                >
                    {$t('common.cancel')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Employee Select Modal for Leave Weekday -->
{#if showDayOffWeekdayEmployeeSelectModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center">
        <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden">
            <!-- Modal Header -->
            <div class="px-6 py-4 bg-gradient-to-r from-emerald-600 to-emerald-500 text-white">
                <h3 class="text-lg font-bold">{$t('hr.shift.select_employee')}</h3>
                <p class="text-emerald-100 text-sm mt-1">{$t('hr.shift.choose_employee_recurring_day_off')}</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Search Input -->
                <div>
                    <label for="dayoff-weekday-employee-search-input" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.search_employee')}</label>
                    <input 
                        id="dayoff-weekday-employee-search-input"
                        type="text" 
                        placeholder={$t('hr.shift.search_placeholder')}
                        bind:value={employeeSearchQuery}
                        on:input={onEmployeeSearchChange}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                    />
                </div>

                <!-- Employee List -->
                <div class="border border-slate-200 rounded-lg max-h-96 overflow-y-auto">
                    {#if employeesForDateWiseSelection.length === 0}
                        <div class="px-4 py-6 text-center text-slate-500 text-sm">
                            {$t('hr.shift.no_employees_found')}
                        </div>
                    {:else}
                        {#each employeesForDateWiseSelection as employee}
                            <button 
                                class="w-full text-left px-4 py-3 hover:bg-emerald-50 border-b border-slate-100 last:border-b-0 transition-colors duration-200"
                                on:click={() => selectEmployeeForDayOffWeekday(employee.id)}
                            >
                                <div class="flex items-center justify-between">
                                    <div class="{$locale === 'ar' ? 'text-right' : 'text-left'}">
                                        <p class="font-semibold text-slate-900">{$locale === 'ar' ? (employee.employee_name_ar || employee.employee_name_en) : employee.employee_name_en}</p>
                                        <p class="text-xs text-slate-500">{employee.id} • {$locale === 'ar' ? (employee.branch_name_ar || employee.branch_name_en) : employee.branch_name_en}</p>
                                    </div>
                                    <div class="text-emerald-600 font-bold">{$locale === 'ar' ? '←' : '→'}</div>
                                </div>
                            </button>
                        {/each}
                    {/if}
                </div>
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button 
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={closeDayOffWeekdayEmployeeSelectModal}
                >
                    {$t('common.cancel')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Delete Modal for Special Shift (weekday-wise) -->
{#if showDeleteModal && selectedEmployeeId}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center">
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden">
            <!-- Modal Header -->
            <div class="px-6 py-4 bg-gradient-to-r from-orange-600 to-orange-500 text-white">
                <h3 class="text-lg font-bold">{$t('hr.shift.delete_shift')}</h3>
                <p class="text-orange-100 text-sm mt-1">{$t('hr.shift.select_day_to_delete')}</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Weekday Selector -->
                <div>
                    <label for="delete-weekday-select" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.select_weekday_to_delete')}</label>
                    <select 
                        id="delete-weekday-select"
                        bind:value={selectedDeleteWeekday}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                        style="color: #000000 !important; background-color: #ffffff !important;"
                    >
                        {#each weekdayNames as day, index}
                            {#if employees.find(e => e.id === selectedEmployeeId)?.shifts?.[index]}
                                <option value={index} style="color: #000000 !important; background-color: #ffffff !important;">{day}</option>
                            {/if}
                        {/each}
                    </select>
                </div>

                <p class="text-sm text-red-600 font-semibold">
                    ⚠️ {$t('common.action_cannot_be_undone')}
                </p>
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button 
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={closeDeleteModal}
                    disabled={isSaving}
                >
                    {$t('common.cancel')}
                </button>
                <button 
                    class="px-6 py-2 rounded-lg font-black text-white bg-red-600 hover:bg-red-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                    on:click={confirmDelete}
                    disabled={isSaving}
                >
                    {isSaving ? $t('common.deleting') : $t('common.delete')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Reason Search Modal -->
{#if showReasonSearchModal}
    <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h2 class="text-2xl font-bold text-slate-900">{$t('hr.shift.select_day_off_reason_title')}</h2>
                <button 
                    class="text-slate-400 hover:text-slate-600 text-2xl"
                    on:click={closeReasonSearchModal}
                >
                    ✕
                </button>
            </div>

            <!-- Search Input -->
            <input 
                type="text"
                bind:value={reasonSearchQuery}
                placeholder={$t('hr.shift.search_by_reason')}
                class="w-full px-4 py-2 border border-slate-300 rounded-lg mb-4 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />

            <!-- Reasons List -->
            <div class="space-y-2 max-h-[60vh] overflow-y-auto">
                {#each dayOffReasons.filter(r => 
                    r.reason_en.toLowerCase().includes(reasonSearchQuery.toLowerCase()) ||
                    r.reason_ar.toLowerCase().includes(reasonSearchQuery.toLowerCase()) ||
                    r.id.toLowerCase().includes(reasonSearchQuery.toLowerCase())
                ) as reason (reason.id)}
                    <button 
                        class="w-full p-4 border border-slate-200 rounded-lg hover:bg-blue-50 hover:border-blue-300 transition text-left"
                        on:click={() => selectReason(reason)}
                    >
                        <div class="flex justify-between items-start">
                            <div class="flex-1 {$locale === 'ar' ? 'text-right' : 'text-left'}">
                                <p class="font-bold text-slate-800">{reason.reason_en}</p>
                                <p class="text-sm text-slate-600 font-semibold">{reason.reason_ar}</p>
                                <p class="text-xs text-slate-500 mt-1">{$t('hr.employeeId')}: {reason.id}</p>
                            </div>
                            <div class="flex gap-2 ml-4">
                                <span class="inline-flex items-center px-2 py-1 rounded text-xs font-bold {reason.is_deductible ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
                                    {reason.is_deductible ? '✓ ' + $t('hr.shift.deductible') : '✗'}
                                </span>
                                <span class="inline-flex items-center px-2 py-1 rounded text-xs font-bold {reason.is_document_mandatory ? 'bg-orange-100 text-orange-800' : 'bg-gray-100 text-gray-800'}">
                                    {reason.is_document_mandatory ? '📄' : '✓'}
                                </span>
                            </div>
                        </div>
                    </button>
                {/each}
            </div>

            <div class="flex gap-3 mt-6">
                <button 
                    type="button"
                    on:click={closeReasonSearchModal}
                    class="flex-1 px-4 py-2 rounded-lg font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                >
                    {$t('common.cancel')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Leave Reason Modal -->
{#if showReasonModal}
    <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h2 class="text-2xl font-bold text-slate-900">
                    {editingReasonId ? $t('hr.shift.edit_day_off_reason') : $t('hr.shift.add_day_off_reason')}
                </h2>
                <button 
                    class="text-slate-400 hover:text-slate-600 text-2xl"
                    on:click={closeReasonModal}
                >
                    ✕
                </button>
            </div>

            <form on:submit|preventDefault={saveReason} class="space-y-4">
                <!-- ID Field (Read-only) -->
                <!-- svelte-ignore a11y_label_has_associated_control -->
                <div>
                    <label for="reason-id" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.employeeId')}</label>
                    <input 
                        id="reason-id"
                        type="text"
                        value={reasonFormData.id}
                        disabled
                        class="w-full px-4 py-2 bg-slate-100 border border-slate-300 rounded-lg text-slate-600 cursor-not-allowed"
                        placeholder={$t('common.autoDetected')}
                    />
                </div>

                <!-- English Reason -->
                <div>
                    <label for="reason-en" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.reason_name_en')}</label>
                    <input 
                        id="reason-en"
                        type="text"
                        bind:value={reasonFormData.reason_en}
                        placeholder={$t('hr.shift.enter_reason_en')}
                        class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                </div>

                <!-- Arabic Reason -->
                <!-- svelte-ignore a11y_label_has_associated_control -->
                <div>
                    <label for="reason-ar" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.reason_name_ar')}</label>
                    <input 
                        id="reason-ar"
                        type="text"
                        bind:value={reasonFormData.reason_ar}
                        placeholder={$t('hr.shift.enter_reason_ar')}
                        dir="rtl"
                        class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
                    />
                </div>

                <!-- Is Deductible Toggle -->
                <!-- svelte-ignore a11y_label_has_associated_control -->
                <div>
                    <label for="deductible-toggle" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.is_deductible')}</label>
                    <button 
                        id="deductible-toggle"
                        type="button"
                        on:click={() => reasonFormData.is_deductible = !reasonFormData.is_deductible}
                        class="w-full px-4 py-3 rounded-lg font-bold text-white transition-all {reasonFormData.is_deductible ? 'bg-green-600 hover:bg-green-700' : 'bg-red-600 hover:bg-red-700'}"
                    >
                        {reasonFormData.is_deductible ? '✓ ' + $t('hr.shift.yes_deductible') : '✗ ' + $t('hr.shift.no_not_deductible')}
                    </button>
                </div>

                <!-- Is Document Mandatory Toggle -->
                <!-- svelte-ignore a11y_label_has_associated_control -->
                <div>
                    <label for="document-toggle" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.document_required')}</label>
                    <button 
                        id="document-toggle"
                        type="button"
                        on:click={() => reasonFormData.is_document_mandatory = !reasonFormData.is_document_mandatory}
                        class="w-full px-4 py-3 rounded-lg font-bold text-white transition-all {reasonFormData.is_document_mandatory ? 'bg-blue-600 hover:bg-blue-700' : 'bg-gray-600 hover:bg-gray-700'}"
                    >
                        {reasonFormData.is_document_mandatory ? '✓ ' + $t('hr.shift.yes_document_required') : '✗ ' + $t('hr.shift.no_document_not_required')}
                    </button>
                </div>

                <!-- Buttons -->
                <div class="flex gap-3 mt-6">
                    <button 
                        type="submit"
                        disabled={isSaving}
                        class="flex-1 px-4 py-2 rounded-lg font-bold text-white bg-blue-600 hover:bg-blue-700 transition disabled:opacity-50"
                    >
                        {isSaving ? $t('common.saving') : $t('common.save')}
                    </button>
                    <button 
                        type="button"
                        on:click={closeReasonModal}
                        class="flex-1 px-4 py-2 rounded-lg font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    >
                        {$t('common.cancel')}
                    </button>
                </div>
            </form>
        </div>
    </div>
{/if}

<!-- Official Holiday Add/Edit Modal -->
{#if showOfficialHolidayModal}
    <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h2 class="text-2xl font-bold text-slate-900">
                    {editingOfficialHolidayId ? $t('hr.shift.edit_official_holiday') : $t('hr.shift.add_official_holiday')}
                </h2>
                <button 
                    class="text-slate-400 hover:text-slate-600 text-2xl"
                    on:click={closeOfficialHolidayModal}
                >
                    ✕
                </button>
            </div>

            <form on:submit|preventDefault={saveOfficialHoliday} class="space-y-4">
                <!-- Holiday Date -->
                <div>
                    <label for="holiday-date" class="block text-sm font-bold text-slate-700 mb-2">📅 {$t('hr.shift.holiday_date')}</label>
                    <input 
                        id="holiday-date"
                        type="date"
                        bind:value={officialHolidayFormData.holiday_date}
                        class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                </div>

                <!-- English Name -->
                <div>
                    <label for="holiday-name-en" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.official_holiday_name_en')}</label>
                    <input 
                        id="holiday-name-en"
                        type="text"
                        bind:value={officialHolidayFormData.name_en}
                        placeholder={$t('hr.shift.enter_holiday_name_en')}
                        class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                </div>

                <!-- Arabic Name -->
                <div>
                    <label for="holiday-name-ar" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.official_holiday_name_ar')}</label>
                    <input 
                        id="holiday-name-ar"
                        type="text"
                        bind:value={officialHolidayFormData.name_ar}
                        placeholder={$t('hr.shift.enter_holiday_name_ar')}
                        dir="rtl"
                        class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
                    />
                </div>

                <!-- Buttons -->
                <div class="flex gap-3 mt-6">
                    <button 
                        type="submit"
                        disabled={isSaving}
                        class="flex-1 px-4 py-2 rounded-lg font-bold text-white bg-blue-600 hover:bg-blue-700 transition disabled:opacity-50"
                    >
                        {isSaving ? $t('common.saving') : $t('common.save')}
                    </button>
                    <button 
                        type="button"
                        on:click={closeOfficialHolidayModal}
                        class="flex-1 px-4 py-2 rounded-lg font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    >
                        {$t('common.cancel')}
                    </button>
                </div>
            </form>
        </div>
    </div>
{/if}

<!-- Employee Assignment Modal for Official Holidays -->
{#if showAssignEmployeesModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center">
        <div class="bg-white rounded-2xl shadow-2xl max-w-2xl w-full mx-4 overflow-hidden max-h-[85vh] flex flex-col" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <!-- Modal Header -->
            <div class="px-6 py-4 bg-gradient-to-r from-emerald-600 to-emerald-500 text-white flex-shrink-0">
                <h3 class="text-lg font-bold">{$t('hr.shift.assign_employees')}</h3>
                <p class="text-emerald-100 text-sm mt-1">🏛️ {assigningHolidayName}</p>
            </div>

            <!-- Search + Select All/None -->
            <div class="px-6 py-4 border-b border-slate-200 flex-shrink-0 space-y-3">
                <div>
                    <input 
                        type="text"
                        bind:value={assignEmployeeSearchQuery}
                        on:input={filterAssignEmployees}
                        placeholder={$t('hr.shift.search_placeholder')}
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                    />
                </div>
                <div class="flex gap-2 items-center">
                    <button 
                        class="px-3 py-1 bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 transition text-xs font-bold"
                        on:click={selectAllAssignEmployees}
                    >
                        ✓ {$t('hr.shift.select_all')}
                    </button>
                    <button 
                        class="px-3 py-1 bg-slate-100 text-slate-600 rounded-lg hover:bg-slate-200 transition text-xs font-bold"
                        on:click={deselectAllAssignEmployees}
                    >
                        ✗ {$t('hr.shift.deselect_all')}
                    </button>
                    <span class="text-xs text-slate-500 font-semibold {$locale === 'ar' ? 'mr-auto' : 'ml-auto'}">
                        {$t('hr.shift.selected_count', { count: assignSelectedEmployeeIds.size, total: assignAllEmployees.length })}
                    </span>
                </div>
            </div>

            <!-- Employee List -->
            <div class="flex-1 overflow-y-auto px-2">
                {#if assignFilteredEmployees.length === 0}
                    <div class="px-4 py-8 text-center text-slate-500 text-sm">
                        {$t('hr.shift.no_employees_found')}
                    </div>
                {:else}
                    {#each assignFilteredEmployees as employee}
                        <button 
                            class="w-full text-left px-4 py-3 border-b border-slate-100 last:border-b-0 transition-colors duration-200 flex items-center gap-3 {assignSelectedEmployeeIds.has(employee.id) ? 'bg-emerald-50' : 'hover:bg-slate-50'}"
                            on:click={() => toggleEmployeeAssignment(employee.id)}
                        >
                            <div class="w-6 h-6 rounded-md border-2 flex items-center justify-center flex-shrink-0 transition-all {assignSelectedEmployeeIds.has(employee.id) ? 'bg-emerald-600 border-emerald-600 text-white' : 'border-slate-300'}">
                                {#if assignSelectedEmployeeIds.has(employee.id)}
                                    <span class="text-xs font-bold">✓</span>
                                {/if}
                            </div>
                            <div class="flex-1 {$locale === 'ar' ? 'text-right' : 'text-left'}">
                                <p class="font-semibold text-slate-900 text-sm">{$locale === 'ar' ? (employee.employee_name_ar || employee.employee_name_en) : employee.employee_name_en}</p>
                                <p class="text-xs text-slate-500">{employee.id} • {$locale === 'ar' ? (employee.branch_name_ar || employee.branch_name_en) : employee.branch_name_en}</p>
                            </div>
                        </button>
                    {/each}
                {/if}
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end flex-shrink-0">
                <button 
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={closeAssignEmployeesModal}
                    disabled={isAssignSaving}
                >
                    {$t('common.cancel')}
                </button>
                <button 
                    class="px-6 py-2 rounded-lg font-black text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                    on:click={saveEmployeeAssignments}
                    disabled={isAssignSaving}
                >
                    {isAssignSaving ? $t('common.saving') : $t('common.save')} ({assignSelectedEmployeeIds.size})
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- View Dates Popup -->
{#if showViewDatesPopup && viewDatesData}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[10000]" on:click={() => { showViewDatesPopup = false; viewDatesData = null; }} on:keydown={(e) => { if (e.key === 'Escape') { showViewDatesPopup = false; viewDatesData = null; }}} role="dialog" aria-modal="true">
        <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 animate-in scale-in overflow-hidden" on:click|stopPropagation on:keydown|stopPropagation role="document">
            <!-- Header -->
            <div class="bg-slate-800 px-6 py-4">
                <h3 class="font-black text-lg" style="color: #ffffff !important;">📅 {$locale === 'ar' ? 'تواريخ الإجازة' : 'Leave Dates'}</h3>
                <p class="text-sm mt-1 font-semibold" style="color: #ffffff !important;">{formatEmployeeNameDisplay(viewDatesData)} ({viewDatesData.employee_id})</p>
                <p class="text-xs mt-0.5 font-medium" style="color: #ffffff !important;">{formatDateDisplay(viewDatesData._dateFrom)} → {formatDateDisplay(viewDatesData._dateTo)} &middot; {viewDatesData._dayCount} {$locale === 'ar' ? 'أيام' : 'days'}</p>
            </div>
            <!-- Filters -->
            <div class="px-6 pt-4 pb-2 flex flex-wrap gap-2">
                <!-- Search -->
                <div class="flex-1 min-w-[140px]">
                    <input
                        type="text"
                        bind:value={viewDatesSearch}
                        placeholder={$locale === 'ar' ? 'بحث تاريخ... مثل 02122024' : 'Search date... e.g. 02122024'}
                        class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                    />
                </div>
                <!-- Month filter -->
                <div class="w-28">
                    <select
                        bind:value={viewDatesMonthFilter}
                        class="w-full px-2 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
                        style="color: #000 !important; background-color: #fff !important;"
                    >
                        <option value="" style="color: #000 !important;">{$locale === 'ar' ? 'كل الأشهر' : 'All Months'}</option>
                        {#each viewDatesAvailableMonths as m}
                            <option value={m}>{m} - {$locale === 'ar' ? monthNames[m]?.ar : monthNames[m]?.en}</option>
                        {/each}
                    </select>
                </div>
                <!-- Year filter -->
                <div class="w-24">
                    <select
                        bind:value={viewDatesYearFilter}
                        class="w-full px-2 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
                        style="color: #000 !important; background-color: #fff !important;"
                    >
                        <option value="" style="color: #000 !important;">{$locale === 'ar' ? 'كل السنوات' : 'All Years'}</option>
                        {#each viewDatesAvailableYears as yr}
                            <option value={yr}>{yr}</option>
                        {/each}
                    </select>
                </div>
            </div>
            <!-- Dates list -->
            <div class="px-6 pb-2">
                <div class="text-xs text-slate-500 font-semibold mb-2">
                    {$locale === 'ar' ? 'عرض' : 'Showing'} {viewDatesFiltered.length} / {(viewDatesData._allDates || [viewDatesData.day_off_date]).length} {$locale === 'ar' ? 'تواريخ' : 'dates'}
                </div>
                <div class="max-h-[320px] overflow-y-auto border border-slate-200 rounded-xl">
                    {#if viewDatesFiltered.length === 0}
                        <div class="py-8 text-center text-slate-400 text-sm">
                            📭 {$locale === 'ar' ? 'لا توجد تواريخ مطابقة' : 'No matching dates'}
                        </div>
                    {:else}
                        {#each viewDatesFiltered as dateItem, i}
                            <div class="flex items-center gap-3 px-4 py-2.5 {i > 0 ? 'border-t border-slate-100' : ''} hover:bg-blue-50/50 transition-colors">
                                <span class="w-7 h-7 rounded-full bg-blue-100 text-blue-700 text-xs font-bold flex items-center justify-center">{i + 1}</span>
                                <span class="flex-1 font-mono text-sm font-semibold text-slate-800">{formatDateDisplay(dateItem)}</span>
                            </div>
                        {/each}
                    {/if}
                </div>
            </div>
            <!-- Footer -->
            <div class="px-6 py-3 bg-slate-50 border-t border-slate-200 flex justify-end">
                <button
                    class="px-5 py-2 rounded-xl font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={() => { showViewDatesPopup = false; viewDatesData = null; }}
                >
                    {$t('common.close') || 'Close'}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Description Popup -->
{#if showDescriptionPopup}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[10000]" on:click={() => { showDescriptionPopup = false; }} on:keydown={(e) => { if (e.key === 'Escape') showDescriptionPopup = false; }} role="dialog" aria-modal="true">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 overflow-hidden" on:click|stopPropagation>
            <div class="bg-indigo-600 text-white px-6 py-4 flex items-center justify-between">
                <h3 class="text-lg font-bold flex items-center gap-2">
                    📝 {$locale === 'ar' ? 'الوصف' : 'Description'}
                </h3>
                <button class="text-white/80 hover:text-white text-2xl font-bold" on:click={() => { showDescriptionPopup = false; }}>&times;</button>
            </div>
            {#if descriptionPopupEmployee}
                <div class="px-6 pt-4">
                    <span class="text-xs font-semibold text-slate-500">{$locale === 'ar' ? 'الموظف' : 'Employee'}:</span>
                    <span class="text-sm font-bold text-slate-800 {$locale === 'ar' ? 'mr-2' : 'ml-2'}">{descriptionPopupEmployee}</span>
                </div>
            {/if}
            <div class="px-6 py-5">
                <div class="bg-slate-50 rounded-xl p-4 text-sm text-slate-800 leading-relaxed whitespace-pre-wrap break-words max-h-[60vh] overflow-y-auto">
                    {descriptionPopupText}
                </div>
            </div>
            <div class="px-6 pb-5 flex justify-end">
                <button
                    class="px-5 py-2 rounded-xl font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={() => { showDescriptionPopup = false; }}
                >
                    {$t('common.close') || 'Close'}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Grouped Deduction Modal -->
{#if showGroupedDeductionModal && groupedModalDayOff}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[10000]" on:click={() => { showGroupedDeductionModal = false; groupedModalDayOff = null; }}>
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 animate-in scale-in overflow-hidden" on:click|stopPropagation>
            <div class="bg-gradient-to-r from-amber-500 to-amber-600 px-6 py-4">
                <h3 class="text-white font-black text-lg">💰 {$t('hr.shift.manage_deduction') || 'Manage Deduction'}</h3>
                <p class="text-amber-100 text-sm mt-1">{formatEmployeeNameDisplay(groupedModalDayOff)} ({groupedModalDayOff.employee_id})</p>
            </div>
            <div class="px-6 py-4">
                <p class="text-slate-600 text-sm mb-3">{$locale === 'ar' ? 'حدد الأيام التي يتم خصمها من الراتب' : 'Check the days that should be deducted from salary'}</p>
                <!-- Select All / Deselect All -->
                <div class="flex gap-2 mb-3">
                    <button 
                        class="px-3 py-1 rounded-lg text-xs font-bold bg-amber-100 text-amber-700 hover:bg-amber-200 transition"
                        on:click={() => {
                            const allDeductions = groupedModalDayOff._allDeductions || [{ id: groupedModalDayOff.id }];
                            for (const item of allDeductions) { groupedDeductionStates[item.id] = true; }
                            groupedDeductionStates = { ...groupedDeductionStates };
                        }}
                    >
                        ✅ {$locale === 'ar' ? 'تحديد الكل' : 'Select All'}
                    </button>
                    <button 
                        class="px-3 py-1 rounded-lg text-xs font-bold bg-slate-100 text-slate-600 hover:bg-slate-200 transition"
                        on:click={() => {
                            const allDeductions = groupedModalDayOff._allDeductions || [{ id: groupedModalDayOff.id }];
                            for (const item of allDeductions) { groupedDeductionStates[item.id] = false; }
                            groupedDeductionStates = { ...groupedDeductionStates };
                        }}
                    >
                        ⬜ {$locale === 'ar' ? 'إلغاء الكل' : 'Deselect All'}
                    </button>
                </div>
                <div class="max-h-[300px] overflow-y-auto border border-slate-200 rounded-xl">
                    {#each (groupedModalDayOff._allDeductions || [{ id: groupedModalDayOff.id, date: groupedModalDayOff.day_off_date, is_deductible: groupedModalDayOff.is_deductible_on_salary || false }]) as item, i}
                        {@const dayDate = (groupedModalDayOff._allDates || [groupedModalDayOff.day_off_date])[i]}
                        <label class="flex items-center gap-3 px-4 py-3 cursor-pointer transition-colors hover:bg-amber-50 {!groupedDeductionStates[item.id] ? 'opacity-60' : ''} {i > 0 ? 'border-t border-slate-100' : ''}">
                            <input 
                                type="checkbox" 
                                bind:checked={groupedDeductionStates[item.id]}
                                class="w-5 h-5 text-amber-600 border-gray-300 rounded focus:ring-amber-500 cursor-pointer"
                            />
                            <span class="flex-1 font-mono text-sm font-semibold text-slate-800">{formatDateDisplay(dayDate)}</span>
                            {#if groupedDeductionStates[item.id]}
                                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-700">💰 {$locale === 'ar' ? 'خصم' : 'Deduct'}</span>
                            {:else}
                                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 text-slate-400">{$locale === 'ar' ? 'بدون خصم' : 'No Deduct'}</span>
                            {/if}
                        </label>
                    {/each}
                </div>
                <div class="text-xs text-slate-500 mt-2 font-semibold">
                    {Object.values(groupedDeductionStates).filter(v => v).length} / {Object.values(groupedDeductionStates).length} {$locale === 'ar' ? 'أيام محددة للخصم' : 'days selected for deduction'}
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-center gap-3">
                <button 
                    class="flex-1 px-4 py-2.5 rounded-xl font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={() => { showGroupedDeductionModal = false; groupedModalDayOff = null; }}
                >
                    {$t('common.cancel')}
                </button>
                <button 
                    class="flex-1 px-4 py-2.5 rounded-xl font-bold text-white bg-amber-600 hover:bg-amber-700 transition disabled:opacity-50"
                    on:click={confirmGroupedDeduction}
                    disabled={isGroupedProcessing}
                >
                    {isGroupedProcessing ? ($t('common.saving') || 'Saving...') : ($t('common.save') || 'Save')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Grouped Delete Modal -->
{#if showGroupedDeleteModal && groupedModalDayOff}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[10000]" on:click={() => { showGroupedDeleteModal = false; groupedModalDayOff = null; }}>
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 animate-in scale-in overflow-hidden" on:click|stopPropagation>
            <div class="bg-gradient-to-r from-red-500 to-red-600 px-6 py-4">
                <h3 class="text-white font-black text-lg">🗑️ {$t('hr.shift.delete_day_off') || 'Delete Leave Days'}</h3>
                <p class="text-red-100 text-sm mt-1">{formatEmployeeNameDisplay(groupedModalDayOff)} ({groupedModalDayOff.employee_id})</p>
            </div>
            <div class="px-6 py-4">
                <p class="text-slate-600 text-sm mb-3">{$locale === 'ar' ? 'قم بإلغاء تحديد الأيام التي تريد الاحتفاظ بها. الأيام المحددة سيتم حذفها.' : 'Uncheck days you want to keep. Checked days will be deleted.'}</p>
                <!-- Select All / Deselect All -->
                <div class="flex gap-2 mb-3">
                    <button 
                        class="px-3 py-1 rounded-lg text-xs font-bold bg-red-100 text-red-700 hover:bg-red-200 transition"
                        on:click={() => {
                            const allIds = groupedModalDayOff._allIds || [groupedModalDayOff.id];
                            for (const id of allIds) { groupedCheckedDates[id] = true; }
                            groupedCheckedDates = { ...groupedCheckedDates };
                        }}
                    >
                        ✅ {$locale === 'ar' ? 'تحديد الكل' : 'Select All'}
                    </button>
                    <button 
                        class="px-3 py-1 rounded-lg text-xs font-bold bg-slate-100 text-slate-600 hover:bg-slate-200 transition"
                        on:click={() => {
                            const allIds = groupedModalDayOff._allIds || [groupedModalDayOff.id];
                            for (const id of allIds) { groupedCheckedDates[id] = false; }
                            groupedCheckedDates = { ...groupedCheckedDates };
                        }}
                    >
                        ⬜ {$locale === 'ar' ? 'إلغاء الكل' : 'Deselect All'}
                    </button>
                </div>
                <div class="max-h-[300px] overflow-y-auto border border-slate-200 rounded-xl">
                    {#each (groupedModalDayOff._allIds || [groupedModalDayOff.id]) as dayId, i}
                        {@const dayDate = (groupedModalDayOff._allDates || [groupedModalDayOff.day_off_date])[i]}
                        <label class="flex items-center gap-3 px-4 py-3 cursor-pointer transition-colors hover:bg-red-50 {groupedCheckedDates[dayId] ? 'bg-red-50/50' : 'opacity-60'} {i > 0 ? 'border-t border-slate-100' : ''}">
                            <input 
                                type="checkbox" 
                                bind:checked={groupedCheckedDates[dayId]}
                                class="w-5 h-5 text-red-600 border-gray-300 rounded focus:ring-red-500 cursor-pointer"
                            />
                            <span class="flex-1 font-mono text-sm font-semibold text-slate-800 {groupedCheckedDates[dayId] ? 'line-through text-red-500' : ''}">{formatDateDisplay(dayDate)}</span>
                            {#if groupedCheckedDates[dayId]}
                                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-red-100 text-red-600">🗑️ {$locale === 'ar' ? 'حذف' : 'Delete'}</span>
                            {:else}
                                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-600">✅ {$locale === 'ar' ? 'احتفاظ' : 'Keep'}</span>
                            {/if}
                        </label>
                    {/each}
                </div>
                <div class="text-xs text-slate-500 mt-2 font-semibold">
                    {Object.values(groupedCheckedDates).filter(v => v).length} / {Object.values(groupedCheckedDates).length} {$locale === 'ar' ? 'أيام سيتم حذفها' : 'days will be deleted'}
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3">
                <button 
                    class="flex-1 px-4 py-2.5 rounded-xl font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={() => { showGroupedDeleteModal = false; groupedModalDayOff = null; }}
                >
                    {$t('common.cancel')}
                </button>
                <button 
                    class="flex-1 px-4 py-2.5 rounded-xl font-bold text-white bg-red-600 hover:bg-red-700 transition disabled:opacity-50"
                    on:click={confirmGroupedDelete}
                    disabled={isGroupedProcessing || Object.values(groupedCheckedDates).every(v => !v)}
                >
                    {#if isGroupedProcessing}
                        {$t('common.deleting') || 'Deleting...'}
                    {:else}
                        🗑️ {$locale === 'ar' ? 'حذف' : 'Delete'} ({Object.values(groupedCheckedDates).filter(v => v).length})
                    {/if}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Grouped Shift Delete Modal -->
{#if showGroupedShiftDeleteModal && groupedShiftModalData}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[10000]" on:click={() => { showGroupedShiftDeleteModal = false; groupedShiftModalData = null; }}>
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 animate-in scale-in overflow-hidden" on:click|stopPropagation>
            <div class="bg-gradient-to-r from-red-500 to-orange-500 px-6 py-4">
                <h3 class="text-white font-black text-lg">🗑️ {$locale === 'ar' ? 'حذف نوبات خاصة' : 'Delete Special Shifts'}</h3>
                <p class="text-orange-100 text-sm mt-1">{formatEmployeeNameDisplay(groupedShiftModalData)} ({groupedShiftModalData.employee_id})</p>
            </div>
            <div class="px-6 py-4">
                <p class="text-slate-600 text-sm mb-3">{$locale === 'ar' ? 'قم بإلغاء تحديد الأيام التي تريد الاحتفاظ بها. الأيام المحددة سيتم حذفها.' : 'Uncheck days you want to keep. Checked days will be deleted.'}</p>
                <div class="flex gap-2 mb-3">
                    <button 
                        class="px-3 py-1 rounded-lg text-xs font-bold bg-red-100 text-red-700 hover:bg-red-200 transition"
                        on:click={() => {
                            const allIds = groupedShiftModalData._allIds || [groupedShiftModalData.id];
                            for (const id of allIds) { groupedShiftCheckedDates[id] = true; }
                            groupedShiftCheckedDates = { ...groupedShiftCheckedDates };
                        }}
                    >
                        ✅ {$locale === 'ar' ? 'تحديد الكل' : 'Select All'}
                    </button>
                    <button 
                        class="px-3 py-1 rounded-lg text-xs font-bold bg-slate-100 text-slate-600 hover:bg-slate-200 transition"
                        on:click={() => {
                            const allIds = groupedShiftModalData._allIds || [groupedShiftModalData.id];
                            for (const id of allIds) { groupedShiftCheckedDates[id] = false; }
                            groupedShiftCheckedDates = { ...groupedShiftCheckedDates };
                        }}
                    >
                        ⬜ {$locale === 'ar' ? 'إلغاء الكل' : 'Deselect All'}
                    </button>
                </div>
                <div class="max-h-[300px] overflow-y-auto border border-slate-200 rounded-xl">
                    {#each (groupedShiftModalData._allIds || [groupedShiftModalData.id]) as shiftId, i}
                        {@const shiftDate = (groupedShiftModalData._allDates || [groupedShiftModalData.shift_date])[i]}
                        <label class="flex items-center gap-3 px-4 py-3 cursor-pointer transition-colors hover:bg-red-50 {groupedShiftCheckedDates[shiftId] ? 'bg-red-50/50' : 'opacity-60'} {i > 0 ? 'border-t border-slate-100' : ''}">
                            <input 
                                type="checkbox" 
                                bind:checked={groupedShiftCheckedDates[shiftId]}
                                class="w-5 h-5 text-red-600 border-gray-300 rounded focus:ring-red-500 cursor-pointer"
                            />
                            <span class="flex-1 font-mono text-sm font-semibold text-slate-800 {groupedShiftCheckedDates[shiftId] ? 'line-through text-red-500' : ''}">{formatDateDisplay(shiftDate)}</span>
                            {#if groupedShiftCheckedDates[shiftId]}
                                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-red-100 text-red-600">🗑️ {$locale === 'ar' ? 'حذف' : 'Delete'}</span>
                            {:else}
                                <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-600">✅ {$locale === 'ar' ? 'احتفاظ' : 'Keep'}</span>
                            {/if}
                        </label>
                    {/each}
                </div>
                <div class="text-xs text-slate-500 mt-2 font-semibold">
                    {Object.values(groupedShiftCheckedDates).filter(v => v).length} / {Object.values(groupedShiftCheckedDates).length} {$locale === 'ar' ? 'نوبات سيتم حذفها' : 'shifts will be deleted'}
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3">
                <button 
                    class="flex-1 px-4 py-2.5 rounded-xl font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={() => { showGroupedShiftDeleteModal = false; groupedShiftModalData = null; }}
                >
                    {$t('common.cancel')}
                </button>
                <button 
                    class="flex-1 px-4 py-2.5 rounded-xl font-bold text-white bg-red-600 hover:bg-red-700 transition disabled:opacity-50"
                    on:click={confirmGroupedShiftDelete}
                    disabled={isGroupedShiftProcessing || Object.values(groupedShiftCheckedDates).every(v => !v)}
                >
                    {#if isGroupedShiftProcessing}
                        {$t('common.deleting') || 'Deleting...'}
                    {:else}
                        🗑️ {$locale === 'ar' ? 'حذف' : 'Delete'} ({Object.values(groupedShiftCheckedDates).filter(v => v).length})
                    {/if}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Alert Modal (Centered) -->
{#if showAlertModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[10000]">
        <div class="bg-white rounded-2xl shadow-2xl p-8 max-w-sm w-full mx-4 animate-in scale-in">
            <div class="text-center">
                <div class="text-5xl mb-4">⚠️</div>
                <h2 class="text-2xl font-bold text-slate-900 mb-2">{alertTitle}</h2>
                <p class="text-slate-600 text-base leading-relaxed mb-6">{alertMessage}</p>
                <button 
                    on:click={closeAlertModal}
                    class="px-6 py-2.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors duration-200"
                >
                    {$t('common.ok')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Notification Popup (Centered Confirmation Style) -->
{#if showNotification}
    <div class="fixed inset-0 bg-black/30 backdrop-blur-sm flex items-center justify-center z-[10001]" on:click={() => showNotification = false} on:keydown={(e) => { if (e.key === 'Escape') showNotification = false; }} role="dialog" aria-modal="true">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm mx-4 overflow-hidden animate-in scale-in" on:click|stopPropagation>
            <div class="flex flex-col items-center justify-center px-6 py-8 gap-4">
                {#if notificationType === 'success'}
                    <div class="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center">
                        <span class="text-4xl">✅</span>
                    </div>
                {:else if notificationType === 'error'}
                    <div class="w-16 h-16 rounded-full bg-red-100 flex items-center justify-center">
                        <span class="text-4xl">❌</span>
                    </div>
                {:else}
                    <div class="w-16 h-16 rounded-full bg-amber-100 flex items-center justify-center">
                        <span class="text-4xl">⚠️</span>
                    </div>
                {/if}
                <p class="text-slate-800 font-bold text-lg text-center leading-relaxed">{notificationMessage}</p>
            </div>
            <div class="px-6 pb-6 flex justify-center">
                <button 
                    class="px-8 py-2.5 rounded-xl font-bold text-white transition-all {notificationType === 'success' ? 'bg-green-600 hover:bg-green-700' : notificationType === 'error' ? 'bg-red-600 hover:bg-red-700' : 'bg-amber-600 hover:bg-amber-700'}"
                    on:click={() => showNotification = false}
                >
                    {$t('common.ok') || 'OK'}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ======================================================================== -->
<!-- MULTI-SHIFT EMPLOYEE SELECT MODAL -->
<!-- ======================================================================== -->
{#if showMultiShiftEmployeeSelectModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center">
        <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden">
            <!-- Modal Header -->
            <div class="px-6 py-4 bg-gradient-to-r from-purple-600 to-purple-500 text-white">
                <h3 class="text-lg font-bold">{$t('hr.shift.multiShift.select_employee')}</h3>
                <p class="text-purple-100 text-sm mt-1">{$t('hr.shift.multiShift.choose_employee')}</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Search Input -->
                <div>
                    <label for="ms-employee-search" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.search_employee')}</label>
                    <input
                        id="ms-employee-search"
                        type="text"
                        placeholder={$t('hr.shift.multiShift.search_employee')}
                        bind:value={multiShiftEmployeeSearchQuery}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                    />
                </div>

                <!-- Employee List -->
                <div class="max-h-80 overflow-y-auto border border-slate-200 rounded-lg divide-y divide-slate-100">
                    {#each multiShiftFilteredEmployees as emp}
                        <button
                            class="w-full px-4 py-3 text-left hover:bg-purple-50 transition-colors flex items-center justify-between"
                            on:click={() => selectMultiShiftEmployee(emp)}
                        >
                            <div>
                                <div class="font-semibold text-slate-800">{$locale === 'ar' ? emp.employee_name_ar : emp.employee_name_en}</div>
                                <div class="text-xs text-slate-500">{emp.id} • {$locale === 'ar' ? emp.branch_name_ar : emp.branch_name_en}</div>
                            </div>
                            <span class="text-purple-500 text-lg">→</span>
                        </button>
                    {:else}
                        <div class="p-4 text-center text-slate-400">{$t('hr.shift.multiShift.no_employees_found')}</div>
                    {/each}
                </div>
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-end">
                <button
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={() => showMultiShiftEmployeeSelectModal = false}
                >
                    {$t('common.cancel')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- ======================================================================== -->
<!-- MULTI-SHIFT CONFIGURATION MODAL -->
<!-- ======================================================================== -->
{#if showMultiShiftModal}
    <div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50 animate-in fade-in duration-200">
        <div class="bg-white rounded-3xl shadow-2xl max-w-md w-full mx-4 overflow-hidden animate-in scale-in duration-300 origin-center">
            <!-- Modal Header -->
            <div class="bg-gradient-to-r {multiShiftModalType === 'regular' ? 'from-purple-600 to-purple-500' : multiShiftModalType === 'date' ? 'from-indigo-600 to-indigo-500' : 'from-violet-600 to-violet-500'} px-6 py-4">
                <h3 class="text-xl font-black text-white">
                    {multiShiftModalType === 'regular' ? $t('hr.shift.multiShift.configure_regular') : multiShiftModalType === 'date' ? $t('hr.shift.multiShift.configure_special_date') : $t('hr.shift.multiShift.configure_special_day')}
                </h3>
                <p class="text-purple-100 text-sm mt-1">{$t('hr.employeeId')}: {multiShiftSelectedEmployeeId} — {multiShiftSelectedEmployeeName}</p>
            </div>

            <!-- Modal Body -->
            <div class="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
                <!-- Date From / Date To (for date type) -->
                {#if multiShiftModalType === 'date'}
                    <div class="grid grid-cols-2 gap-3">
                        <div>
                            <label for="ms-date-from" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.multiShift.date_from')}</label>
                            <input
                                id="ms-date-from"
                                type="date"
                                bind:value={multiShiftFormData.date_from}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
                            />
                        </div>
                        <div>
                            <label for="ms-date-to" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.multiShift.date_to')}</label>
                            <input
                                id="ms-date-to"
                                type="date"
                                bind:value={multiShiftFormData.date_to}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500"
                            />
                        </div>
                    </div>
                {/if}

                <!-- Select Day (for day type) -->
                {#if multiShiftModalType === 'day'}
                    <div>
                        <label for="ms-weekday-select" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.multiShift.select_day')}</label>
                        <select
                            id="ms-weekday-select"
                            bind:value={multiShiftFormData.weekday}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-violet-500"
                            style="color: #000000 !important; background-color: #ffffff !important;"
                        >
                            {#each weekdayNames as day, index}
                                <option value={index} style="color: #000000 !important; background-color: #ffffff !important;">{day}</option>
                            {/each}
                        </select>
                    </div>
                {/if}

                <!-- Start Time -->
                <div>
                    <label for="ms-start-time" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.multiShift.shift_start_time')}</label>
                    <div class="flex gap-2">
                        <select
                            bind:value={msStartHour12}
                            on:change={updateMsStartTime24h}
                            class="flex-1 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                        >
                            {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                                <option value={h}>{h}</option>
                            {/each}
                        </select>
                        <select
                            bind:value={msStartMinute12}
                            on:change={updateMsStartTime24h}
                            class="flex-1 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                        >
                            {#each Array.from({length: 60}, (_, i) => String(i).padStart(2, '0')) as m}
                                <option value={m}>{m}</option>
                            {/each}
                        </select>
                        <select
                            bind:value={msStartPeriod12}
                            on:change={updateMsStartTime24h}
                            class="w-20 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                        >
                            <option value="AM">{$t('common.am')}</option>
                            <option value="PM">{$t('common.pm')}</option>
                        </select>
                    </div>
                </div>

                <!-- Start Buffer Hours -->
                <div>
                    <label for="ms-start-buffer" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.multiShift.start_buffer_hours')}</label>
                    <input
                        id="ms-start-buffer"
                        type="number"
                        bind:value={multiShiftFormData.shift_start_buffer}
                        step="0.5"
                        min="0"
                        max="24"
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                    />
                </div>

                <!-- Last Punch Time (End Time) -->
                <div>
                    <label for="ms-end-time" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.multiShift.last_punch_time')}</label>
                    <div class="flex gap-2">
                        <select
                            bind:value={msEndHour12}
                            on:change={updateMsEndTime24h}
                            class="flex-1 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                        >
                            {#each Array.from({length: 12}, (_, i) => String(i + 1).padStart(2, '0')) as h}
                                <option value={h}>{h}</option>
                            {/each}
                        </select>
                        <select
                            bind:value={msEndMinute12}
                            on:change={updateMsEndTime24h}
                            class="flex-1 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                        >
                            {#each Array.from({length: 60}, (_, i) => String(i).padStart(2, '0')) as m}
                                <option value={m}>{m}</option>
                            {/each}
                        </select>
                        <select
                            bind:value={msEndPeriod12}
                            on:change={updateMsEndTime24h}
                            class="w-20 px-2 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                        >
                            <option value="AM">{$t('common.am')}</option>
                            <option value="PM">{$t('common.pm')}</option>
                        </select>
                    </div>
                </div>

                <!-- End Buffer Hours -->
                <div>
                    <label for="ms-end-buffer" class="block text-sm font-bold text-slate-700 mb-2">{$t('hr.shift.multiShift.end_buffer_hours')}</label>
                    <input
                        id="ms-end-buffer"
                        type="number"
                        bind:value={multiShiftFormData.shift_end_buffer}
                        step="0.5"
                        min="0"
                        max="24"
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                    />
                </div>

                <!-- Overlapping Next Day -->
                <div class="flex items-center gap-3 py-2">
                    <input
                        type="checkbox"
                        bind:checked={multiShiftFormData.is_shift_overlapping_next_day}
                        id="ms-overlapping"
                        class="w-5 h-5 rounded border-slate-300 text-purple-600 focus:ring-2 focus:ring-purple-500 cursor-pointer"
                    />
                    <label for="ms-overlapping" class="text-sm font-bold text-slate-700 cursor-pointer">
                        {$t('hr.shift.multiShift.overlapping_next_day')}
                    </label>
                </div>

                <!-- Working Hours (Required) -->
                <div>
                    <label for="ms-working-hours" class="block text-sm font-bold text-slate-700 mb-2">
                        {$t('hr.shift.multiShift.working_hours')} <span class="text-red-500">*</span>
                    </label>
                    <input
                        id="ms-working-hours"
                        type="number"
                        bind:value={multiShiftFormData.working_hours}
                        step="0.5"
                        min="0.5"
                        max="24"
                        placeholder={$t('hr.shift.multiShift.working_hours_placeholder')}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                        required
                    />
                </div>
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={closeMultiShiftModal}
                    disabled={isMultiShiftSaving}
                >
                    {$t('common.cancel')}
                </button>
                <button
                    class="px-6 py-2 rounded-lg font-black text-white {multiShiftModalType === 'regular' ? 'bg-purple-600 hover:bg-purple-700' : multiShiftModalType === 'date' ? 'bg-indigo-600 hover:bg-indigo-700' : 'bg-violet-600 hover:bg-violet-700'} hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                    on:click={saveMultiShift}
                    disabled={isMultiShiftSaving}
                >
                    {isMultiShiftSaving ? $t('hr.shift.multiShift.saving') : $t('hr.shift.multiShift.save')}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Leave Request Print Dialog -->
{#if showLeaveRequestPrintDialog && selectedDayOffForPrint}
    <LeaveRequestPrint 
        dayOff={selectedDayOffForPrint}
        onClose={() => {
            showLeaveRequestPrintDialog = false;
            selectedDayOffForPrint = null;
        }}
    />
{/if}

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    
    .tracking-fast {
        letter-spacing: 0.05em;
    }

    /* Animate in effects */
    @keyframes fadeIn {
        from {
            opacity: 0;
        }
        to {
            opacity: 1;
        }
    }

    @keyframes scaleIn {
        from {
            opacity: 0;
            transform: scale(0.95);
        }
        to {
            opacity: 1;
            transform: scale(1);
        }
    }

    .animate-in {
        animation: fadeIn 0.2s ease-out;
    }

    .scale-in {
        animation: scaleIn 0.3s ease-out;
    }

    /* RTL fixes for dropdown arrows */
    :global([dir="rtl"] select) {
        background-position: left 0.75rem center !important;
        padding-left: 2.5rem !important;
        padding-right: 1rem !important;
    }

    /* Ensure search inputs also respect RTL padding if they have icons, 
       but here we just focus on the selects as requested */

    /* Notification Toast Styles */
    .notification {
        display: flex;
        align-items: center;
        border-radius: 8px;
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255, 255, 255, 0.2);
    }

    .notification-success {
        background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    }

    .notification-error {
        background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
    }

    .notification-warning {
        background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
    }
</style>
