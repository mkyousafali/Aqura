<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { get } from 'svelte/store';
    
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

    interface DayOffReason {
        id: string;
        reason_en: string;
        reason_ar: string;
        is_deductible: boolean;
        is_document_mandatory: boolean;
    }

    let activeTab = 'Regular Shift';
    let employees: EmployeeShift[] = [];
    let employeesForDateWiseSelection: EmployeeForSelection[] = [];
    let allEmployeesForDateWise: EmployeeForSelection[] = [];
    let dateWiseShifts: (EmployeeShift & {shift_date?: string})[] = [];
    let dayOffs: (EmployeeShift & {day_off_date?: string, approval_status?: string, reason_en?: string, reason_ar?: string})[] = [];
    let dayOffsWeekday: (EmployeeShift & {day_off_weekday?: number})[] = [];
    let dayOffReasons: DayOffReason[] = [];
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
    let documentFile: File | null = null;
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
    let dayOffWeekdaySearchQuery = '';
    let dayOffWeekdayBranchFilter = '';
    let dayOffWeekdayNationalityFilter = '';
    let dayOffWeekdayEmploymentStatusFilter = '';
    let availableBranches: Branch[] = [];
    let availableNationalities: Nationality[] = [];
    
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

    function openAlertModal(message: string, title: string = 'Alert') {
        alertMessage = message;
        alertTitle = title;
        showAlertModal = true;
    }

    function closeAlertModal() {
        showAlertModal = false;
    }

    // Form data for day off reason modal
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
    $: filteredSpecialDateEmployees = getFilteredSpecialDateShifts(dateWiseShifts, specialDateBranchFilter, specialDateNationalityFilter, specialDateEmploymentStatusFilter, specialDateSearchQuery);
    $: filteredDayOffsEmployees = getFilteredDayOffs(dayOffs, dayOffBranchFilter, dayOffNationalityFilter, dayOffEmploymentStatusFilter, dayOffSearchQuery);
    $: filteredDayOffsWeekdayEmployees = getFilteredDayOffsWeekday(dayOffsWeekday, dayOffWeekdayBranchFilter, dayOffWeekdayNationalityFilter, dayOffWeekdayEmploymentStatusFilter, dayOffWeekdaySearchQuery);

    $: availableEmploymentStatuses = [
        'Job (With Finger)',
        'Job (No Finger)',
        'Remote Job',
        'Vacation',
        'Resigned',
        'Terminated',
        'Run Away'
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

    // Form data for modal
    let formData: RegularShiftData | SpecialShiftWeekdayData | SpecialShiftDateWiseData = {
        id: '',
        shift_start_time: '09:00',
        shift_start_buffer: 0,
        shift_end_time: '17:00',
        shift_end_buffer: 0,
        is_shift_overlapping_next_day: false
    } as RegularShiftData;

    $: tabs = [
        { id: 'Regular Shift', label: $t('hr.shift.tabs.regular'), icon: '🕒', color: 'green' },
        { id: 'Special Shift (weekday-wise)', label: $t('hr.shift.tabs.special_weekday'), icon: '📅', color: 'orange' },
        { id: 'Special Shift (date-wise)', label: $t('hr.shift.tabs.special_date'), icon: '📆', color: 'orange' },
        { id: 'Day Off (date-wise)', label: $t('hr.shift.tabs.day_off_date'), icon: '🏖️', color: 'green' },
        { id: 'Day Off (weekday-wise)', label: $t('hr.shift.tabs.day_off_weekday'), icon: '📋', color: 'green' },
        { id: 'Day Off Reasons', label: 'Day Off Reasons', icon: '📌', color: 'blue' }
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
            await loadSpecialShiftDateWiseData();
        } else if (activeTab === 'Day Off (date-wise)') {
            await loadDayOffData();
        } else if (activeTab === 'Day Off (weekday-wise)') {
            await loadDayOffWeekdayData();
        } else if (activeTab === 'Day Off Reasons') {
            await loadDayOffReasons();
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
            .on('postgres_changes', { event: '*', schema: 'public', table: 'day_off' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'day_off_weekday' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'day_off_reasons' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'branches' }, () => refreshCurrentTabData())
            .on('postgres_changes', { event: '*', schema: 'public', table: 'nationalities' }, () => refreshCurrentTabData())
            .subscribe();
    }

    async function refreshCurrentTabData() {
        if (activeTab === 'Regular Shift') {
            await loadEmployeeShiftData();
        } else if (activeTab === 'Special Shift (weekday-wise)') {
            await loadSpecialShiftWeekdayData();
        } else if (activeTab === 'Special Shift (date-wise)') {
            await loadSpecialShiftDateWiseData();
        } else if (activeTab === 'Day Off (date-wise)') {
            await loadDayOffData();
        } else if (activeTab === 'Day Off (weekday-wise)') {
            await loadDayOffWeekdayData();
        } else if (activeTab === 'Day Off Reasons') {
            await loadDayOffReasons();
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
        
        (formData as SpecialShiftDateWiseData) = {
            id: `${employeeId}-${new Date().toISOString().split('T')[0]}`,
            employee_id: employeeId,
            shift_date: new Date().toISOString().split('T')[0],
            shift_start_time: '09:00',
            shift_start_buffer: 0,
            shift_end_time: '17:00',
            shift_end_buffer: 0,
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
                dayOffs = [];
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
            let nationalities: any[] = [];
            if (nationalityIds.length > 0) {
                const { data: nat, error: natError } = await supabase
                    .from('nationalities')
                    .select('id, name_en, name_ar')
                    .in('id', nationalityIds);
                if (natError) throw natError;
                nationalities = (nat as Nationality[]) || [];
            }

            const branchMap = new Map<string, Branch>((branches as Branch[] | null)?.map(b => [String(b.id), b]) || []);
            const nationalityMap = new Map<string, Nationality>(nationalities.map(n => [String(n.id), n]) || []);

            // Populate available branches and nationalities for filter
            availableBranches = (branches as Branch[] | null) || [];
            availableNationalities = nationalities || [];

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

            // Get day off data
            const { data: dayOffData, error: dayOffError } = await supabase
                .from('day_off')
                .select('*, day_off_reasons(*)')
                .order('day_off_date', { ascending: false });

            if (dayOffError && dayOffError.code !== 'PGRST116') throw dayOffError; // 404 is OK

            // Map day offs with employee details
            dayOffs = ((dayOffData as any[]) || []).map(dayOff => {
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
                    day_off_date: dayOff.day_off_date,
                    approval_status: dayOff.approval_status,
                    reason_en: dayOff.day_off_reasons?.reason_en || 'N/A',
                    reason_ar: dayOff.day_off_reasons?.reason_ar || 'N/A',
                    document_url: dayOff.document_url
                };
            });
            
            dayOffs = [...sortEmployees(dayOffs)];
        } catch (err) {
            console.error('Error loading day off data:', err);
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

            // Get day off weekday data
            const { data: dayOffWeekdayData, error: dayOffError } = await supabase
                .from('day_off_weekday')
                .select('*')
                .order('weekday', { ascending: true });

            if (dayOffError && dayOffError.code !== 'PGRST116') throw dayOffError;

            // Map day offs with employee details
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
            console.error('Error loading day off weekday data:', err);
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
        } else if (activeTab === 'Day Off (date-wise)' || activeTab === 'Day Off (weekday-wise)') {
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
        showDeleteModal = false;
        showEmployeeSelectModal = false;
        showDayOffEmployeeSelectModal = false;
        showDayOffWeekdayEmployeeSelectModal = false;
        selectedEmployeeId = null;
        employeeSearchQuery = '';
        selectedDayOffDate = new Date().toISOString().split('T')[0];
        selectedDayOffWeekday = 0;

        if (activeTab === 'Regular Shift') {
            loadEmployeeShiftData();
        } else if (activeTab === 'Special Shift (weekday-wise)') {
            loadSpecialShiftWeekdayData();
        } else if (activeTab === 'Special Shift (date-wise)') {
            loadSpecialShiftDateWiseData();
        } else if (activeTab === 'Day Off (date-wise)') {
            loadDayOffData();
        } else if (activeTab === 'Day Off (weekday-wise)') {
            loadDayOffWeekdayData();
        }
    }

    function openModal(employeeId: string) {
        selectedEmployeeId = employeeId;
        
        if (activeTab === 'Regular Shift') {
            const employee = employees.find(e => e.id === employeeId);
            
            if (employee && employee.shift_start_time) {
                (formData as RegularShiftData) = {
                    id: employeeId,
                    shift_start_time: employee.shift_start_time,
                    shift_start_buffer: employee.shift_start_buffer || 0,
                    shift_end_time: employee.shift_end_time || '17:00',
                    shift_end_buffer: employee.shift_end_buffer || 0,
                    is_shift_overlapping_next_day: employee.is_shift_overlapping_next_day || false
                };
            } else {
                (formData as RegularShiftData) = {
                    id: employeeId,
                    shift_start_time: '09:00',
                    shift_start_buffer: 0,
                    shift_end_time: '17:00',
                    shift_end_buffer: 0,
                    is_shift_overlapping_next_day: false
                };
            }
        } else if (activeTab === 'Special Shift (weekday-wise)') {
            (formData as SpecialShiftWeekdayData) = {
                id: `${employeeId}-1`,
                employee_id: employeeId,
                weekday: 1,
                shift_start_time: '09:00',
                shift_start_buffer: 0,
                shift_end_time: '17:00',
                shift_end_buffer: 0,
                is_shift_overlapping_next_day: false
            };
        }
        
        showModal = true;
    }

    function closeModal() {
        showModal = false;
        selectedEmployeeId = null;
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
                // Add new day off
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
            console.error('Error saving day off:', err);
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
            console.error('Error deleting day off:', err);
            alert($t('hr.shift.error_failed_delete') + (err instanceof Error ? err.message : $t('common.unknown_error')));
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
                // Add new day off
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
            console.error('Error saving day off weekday:', err);
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
            console.error('Error deleting day off weekday:', err);
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
            return { color: 'bg-green-100 text-green-800', text: $t('common.yes') || 'Yes' };
        } else {
            return { color: 'bg-red-100 text-red-800', text: $t('common.no') || 'No' };
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

    function getFilteredDayOffs(itemList: any[], branchFilter: string, nationalityFilter: string, statusFilter: string, searchQuery: string) {
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

    // Day Off Reasons Functions
    async function loadDayOffReasons() {
        loading = true;
        error = null;
        try {
            await initSupabase();

            console.log('Loading day off reasons...');
            const { data: reasons, error: reasonError } = await supabase
                .from('day_off_reasons')
                .select('*')
                .order('id', { ascending: true });

            console.log('Day off reasons data:', reasons);
            console.log('Day off reasons error:', reasonError);

            if (reasonError && reasonError.code !== 'PGRST116') throw reasonError;

            dayOffReasons = (reasons as DayOffReason[]) || [];
            console.log('Day off reasons loaded:', dayOffReasons.length);
        } catch (err) {
            console.error('Error loading day off reasons:', err);
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
            openAlertModal('Please fill in both English and Arabic reason names', 'Required Fields');
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
            openAlertModal('Error saving reason: ' + (err instanceof Error ? err.message : 'Unknown error'), 'Save Error');
        } finally {
            isSaving = false;
        }
    }

    async function deleteReason(id: string) {
        if (!confirm('Are you sure you want to delete this reason?')) return;

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
            openAlertModal('Error deleting reason: ' + (err instanceof Error ? err.message : 'Unknown error'), 'Delete Error');
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
            openAlertModal('Please select employee, date, and document', 'Required Fields');
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
            openAlertModal('Error uploading document: ' + (err instanceof Error ? err.message : 'Unknown error'), 'Upload Error');
            return null;
        } finally {
            isUploadingDocument = false;
        }
    }

    async function saveDayOffWithApproval() {
        if (!selectedEmployeeId || !selectedDayOffStartDate || !selectedDayOffEndDate) {
            openAlertModal('Please select employee, start date, and end date', 'Invalid Selection');
            return;
        }

        // Validate date range
        if (selectedDayOffStartDate > selectedDayOffEndDate) {
            openAlertModal('Start date must be before or equal to end date', 'Invalid Date Range');
            return;
        }

        if (!selectedDayOffReason) {
            openAlertModal('Please select a day off reason', 'Invalid Selection');
            return;
        }

        // Check if document is mandatory
        if (selectedDayOffReason.is_document_mandatory && !documentFile) {
            openAlertModal('Document is mandatory for this reason. Please upload a document', 'Document Required');
            return;
        }

        isSaving = true;
        try {
            let documentUrl = null;

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
            console.log('✅ Day off request from current user:', { user_id: requestedByUserId });

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

            // Create day off records for each date in range
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
                    is_deductible_on_salary: selectedDayOffReason.is_deductible
                };
            });

            // Insert all records at once
            const { data: dayOffData, error: dayOffError } = await supabase
                .from('day_off')
                .insert(dayOffRecords)
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

                        // Create notification for approvers - wrap in try-catch in case it fails
                        try {
                            for (const approverId of approverUserIds) {
                                await supabase
                                    .from('notifications')
                                    .insert({
                                        type: 'approval_request',
                                        title: 'Leave Request Approval',
                                        message: `Leave request for ${selectedEmployeeId} from ${selectedDayOffStartDate} to ${selectedDayOffEndDate} (${dateArray.length} days) requires approval`,
                                        target_user_id: approverId,
                                        related_id: dayOffData[0].id,
                                        read: false,
                                        created_at: new Date().toISOString()
                                    });
                            }
                            console.log('✅ Approval notifications sent to', approverUserIds.length, 'approvers');
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
            documentFile = null;
            documentUploadProgress = 0;

            await loadDayOffData();
            
            // Close modal and show success notification
            showModal = false;
            showSuccessNotification(`Day off request submitted for ${dateArray.length} day${dateArray.length !== 1 ? 's' : ''}!`);
        } catch (err) {
            console.error('Error saving day off:', err);
            showErrorNotification('Error: ' + (err instanceof Error ? err.message : 'Failed to save day off'));
        } finally {
            isSaving = false;
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
                                    <option value={status} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status).text}</option>
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
                            <table class="w-full border-collapse">
                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employeeId')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.fullName')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.branch')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.nationality')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employmentStatus')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.sponsorshipStatus')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.start')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.start_buffer')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.end')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.end_buffer')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.overlaps')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.working_hours')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.action')}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each filteredRegularEmployees as employee, index}
                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm font-semibold text-slate-800">{employee.id}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getEmploymentStatusDisplay(employee.employment_status).color}">
                                                    {getEmploymentStatusDisplay(employee.employment_status).text}
                                                </span>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getSponsorshipStatusDisplay(employee.sponsorship_status).color}">
                                                    {getSponsorshipStatusDisplay(employee.sponsorship_status).text}
                                                </span>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatTimeTo12Hour(employee.shift_start_time)}</td>
                                            <td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{employee.shift_start_buffer ?? '—'}</td>
                                            <td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatTimeTo12Hour(employee.shift_end_time)}</td>
                                            <td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{employee.shift_end_buffer ?? '—'}</td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <span class="inline-flex items-center justify-center w-6 h-6 rounded-full {employee.is_shift_overlapping_next_day ? 'bg-orange-200 text-orange-700 font-black' : 'bg-gray-200 text-gray-700'}">
                                                    {employee.is_shift_overlapping_next_day ? '✓' : '×'}
                                                </span>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center font-mono font-bold text-emerald-700">
                                                {employee.working_hours ? employee.working_hours.toFixed(2) : '—'} {$t('common.hrs')}
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
                                    <option value={status} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status).text}</option>
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
                            <table class="w-full border-collapse">
                                <thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.employeeId')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.fullName')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.branch')}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.nationality')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.employmentStatus')}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.sponsorshipStatus')}</th>
                                        {#each weekdayNames as weekday}
                                            <th colspan="3" class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 bg-orange-500/50">
                                                {weekday}
                                            </th>
                                        {/each}
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('common.action')}</th>
                                    </tr>
                                    <tr>
                                        <th colspan="6" class="text-xs"></th>
                                    {#each weekdayNames as weekday}
                                            <th class="px-2 py-2 text-center text-[10px] font-bold text-slate-600 border-b border-orange-300">{$t('hr.shift.start')}</th>
                                            <th class="px-2 py-2 text-center text-[10px] font-bold text-slate-600 border-b border-orange-300">{$t('hr.shift.end')}</th>
                                            <th class="px-2 py-2 text-center text-[10px] font-bold text-slate-600 border-b border-orange-300">{$t('hr.shift.hours')}</th>
                                        {/each}
                                        <th class="text-xs"></th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each filteredSpecialWeekdayEmployees as employee, index}
                                        <tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm font-semibold text-slate-800">{employee.id}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getEmploymentStatusDisplay(employee.employment_status).color}">
                                                    {getEmploymentStatusDisplay(employee.employment_status).text}
                                                </span>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getSponsorshipStatusDisplay(employee.sponsorship_status).color}">
                                                    {getSponsorshipStatusDisplay(employee.sponsorship_status).text}
                                                </span>
                                            </td>
                                            {#each renderShiftColumns(employee) as shiftCol}
                                                <td class="px-2 py-3 text-xs text-center font-mono text-slate-800">{shiftCol.startTime}</td>
                                                <td class="px-2 py-3 text-xs text-center font-mono text-slate-800">{shiftCol.endTime}</td>
                                                <td class="px-2 py-3 text-xs text-center font-mono font-bold text-orange-700">
                                                    {shiftCol.workingHours} {shiftCol.workingHours !== '—' ? $t('common.hrs') : ''}
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
                                    <option value={status} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status).text}</option>
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
                                <table class="w-full border-collapse">
                                    <thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.employeeId')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.fullName')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.branch')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.nationality')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.employmentStatus')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.sponsorshipStatus')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('common.date')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.start')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.start_buffer')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.end')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.end_buffer')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.overlaps')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.shift.working_hours')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('common.action')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each filteredSpecialDateEmployees as shift, index}
                                            <tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{shift.employee_id}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(shift)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(shift)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(shift)}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getEmploymentStatusDisplay(shift.employment_status).color}">
                                                        {getEmploymentStatusDisplay(shift.employment_status).text}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getSponsorshipStatusDisplay(shift.sponsorship_status).color}">
                                                        {getSponsorshipStatusDisplay(shift.sponsorship_status).text}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm font-mono text-slate-800">{shift.shift_date}</td>
                                                <td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatTimeTo12Hour(shift.shift_start_time || '')}</td>
                                                <td class="px-4 py-3 text-sm text-center font-mono text-slate-700">{shift.shift_start_buffer || 0} {$t('common.hrs')}</td>
                                                <td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatTimeTo12Hour(shift.shift_end_time || '')}</td>
                                                <td class="px-4 py-3 text-sm text-center font-mono text-slate-700">{shift.shift_end_buffer || 0} {$t('common.hrs')}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-block px-2 py-1 rounded-full text-xs font-black {shift.is_shift_overlapping_next_day ? 'bg-orange-200 text-orange-800' : 'bg-slate-200 text-slate-800'}">
                                                        {shift.is_shift_overlapping_next_day ? $t('common.yes') : $t('common.no')}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center font-bold text-orange-700">
                                                    {shift.working_hours} {$t('common.hrs')}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <button 
                                                        class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                        on:click={() => deleteSpecialShiftDateWise(shift.id, shift.employee_id, shift.shift_date)}
                                                        title={$t('hr.shift.delete_tooltip')}
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
                            {$t('hr.shift.showing_shifts', { current: filteredSpecialDateEmployees.length, total: dateWiseShifts.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Day Off (date-wise)'}
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
                                    <option value={status} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status).text}</option>
                                {/each}
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
                    </div>

                    <!-- Day Off Container -->
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
                                <table class="w-full border-collapse">
                                    <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employeeId')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.fullName')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.branch')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.nationality')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employmentStatus')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.sponsorshipStatus')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.day_off_date')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.reason') || 'Reason'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.document') || 'Document'}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.status')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.action')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each filteredDayOffsEmployees as dayOff, index}
                                            <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{dayOff.employee_id}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getEmploymentStatusDisplay(dayOff.employment_status).color}">
                                                        {getEmploymentStatusDisplay(dayOff.employment_status).text}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getSponsorshipStatusDisplay(dayOff.sponsorship_status).color}">
                                                        {getSponsorshipStatusDisplay(dayOff.sponsorship_status).text}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm font-mono text-slate-800">{dayOff.day_off_date}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{$locale === 'ar' ? (dayOff.reason_ar || dayOff.reason_en) : (dayOff.reason_en || dayOff.reason_ar)}</td>
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
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getApprovalStatusDisplay(dayOff.approval_status).color}">
                                                        {getApprovalStatusDisplay(dayOff.approval_status).text}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <div class="flex items-center justify-center gap-2">
                                                        <!-- Edit Button -->
                                                        <button 
                                                            class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-blue-600 text-white font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                            on:click={() => {
                                                                selectedEmployeeId = dayOff.employee_id;
                                                                selectedDayOffStartDate = dayOff.day_off_date;
                                                                selectedDayOffEndDate = dayOff.day_off_date;
                                                                showModal = true;
                                                            }}
                                                            title="Edit day off"
                                                        >
                                                            ✎️
                                                        </button>
                                                        
                                                        <!-- Delete Button -->
                                                        <button 
                                                            class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                            on:click={() => deleteDayOff(dayOff.id, dayOff.employee_id, dayOff.day_off_date)}
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
                            {$t('hr.shift.showing_day_offs', { current: filteredDayOffsEmployees.length, total: dayOffs.length })}
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Day Off (weekday-wise)'}
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
                                    <option value={status} style="color: #000000 !important; background-color: #ffffff !important;">{getEmploymentStatusDisplay(status).text}</option>
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

                    <!-- Day Off Weekday Container -->
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
                                <table class="w-full border-collapse">
                                    <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employeeId')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.fullName')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.branch')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.nationality')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employmentStatus')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.sponsorshipStatus')}</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.shift.day_off_weekday')}</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.action')}</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each filteredDayOffsWeekdayEmployees as dayOff, index}
                                            <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{dayOff.employee_id}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getEmploymentStatusDisplay(dayOff.employment_status).color}">
                                                        {getEmploymentStatusDisplay(dayOff.employment_status).text}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold {getSponsorshipStatusDisplay(dayOff.sponsorship_status).color}">
                                                        {getSponsorshipStatusDisplay(dayOff.sponsorship_status).text}
                                                    </span>
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
            {:else if activeTab === 'Day Off Reasons'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">Loading day off reasons...</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">Error: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadDayOffReasons}
                        >
                            Retry
                        </button>
                    </div>
                {:else}
                    <!-- Day Off Reasons Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <!-- Action Button -->
                        <div class="px-6 py-4 border-b border-slate-200 flex items-center gap-3">
                            <button 
                                class="inline-flex items-center gap-2 px-6 py-2 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md"
                                on:click={() => openReasonModal()}
                            >
                                <span>➕</span>
                                Add Reason
                            </button>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if dayOffReasons.length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">No day off reasons found</p>
                                        <p class="text-slate-400 text-sm mt-2">Click the button above to add one</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse">
                                    <thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">ID</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Reason (English)</th>
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Reason (Arabic)</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Deductible</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Document Required</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Actions</th>
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
                                                        {reason.is_deductible ? '✓ Yes' : '✗ No'}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {reason.is_document_mandatory ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'}">
                                                        {reason.is_document_mandatory ? '✓ Yes' : '✗ No'}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <div class="flex gap-2 justify-center">
                                                        <button 
                                                            class="px-3 py-1 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition text-xs font-semibold"
                                                            on:click={() => openReasonModal(reason)}
                                                        >
                                                            ✏️ Edit
                                                        </button>
                                                        <button 
                                                            class="px-3 py-1 bg-red-600 text-white rounded-lg hover:bg-red-700 transition text-xs font-semibold"
                                                            on:click={() => deleteReason(reason.id)}
                                                        >
                                                            🗑️ Delete
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
                            Showing {dayOffReasons.length} day off reason{dayOffReasons.length !== 1 ? 's' : ''}
                        </div>
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

                    <h2 class="text-4xl font-black text-slate-900 mb-4 tracking-tight">{activeTab}</h2>
                    
                    <div class="flex items-center gap-4 mb-12">
                        <div class="h-[3px] w-16 rounded-full {tabs.find(t => t.id === activeTab)?.color === 'green' ? 'bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]' : 'bg-orange-500 shadow-[0_0_10px_rgba(249,115,22,0.5)]'}"></div>
                        <p class="text-slate-400 font-black text-[10px] uppercase tracking-[0.4em]">Ready for configuration</p>
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
            <div class="bg-gradient-to-r {activeTab === 'Regular Shift' ? 'from-emerald-600 to-emerald-500' : activeTab === 'Day Off (date-wise)' || activeTab === 'Day Off (weekday-wise)' ? 'from-emerald-600 to-emerald-500' : 'from-orange-600 to-orange-500'} px-6 py-4">
                <h3 class="text-xl font-black text-white">
                    {activeTab === 'Regular Shift' ? $t('hr.shift.configure_regular_shift') : activeTab === 'Special Shift (weekday-wise)' ? $t('hr.shift.configure_special_shift_weekday') : activeTab === 'Special Shift (date-wise)' ? $t('hr.shift.configure_special_shift_date') : activeTab === 'Day Off (date-wise)' ? $t('hr.shift.assign_day_off_date') : $t('hr.shift.assign_day_off_weekday')}
                </h3>
                <p class="{activeTab === 'Regular Shift' || activeTab === 'Day Off (date-wise)' || activeTab === 'Day Off (weekday-wise)' ? 'text-emerald-100' : 'text-orange-100'} text-sm mt-1">{$t('hr.employeeId')}: {selectedEmployeeId}</p>
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
                    <!-- Date Selection -->
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

                {#if activeTab === 'Day Off (date-wise)'}
                    <!-- Day Off Start Date Selection -->
                    <div>
                        <label for="dayoff-start-date-input" class="block text-sm font-bold text-slate-700 mb-2">Start Date</label>
                        <input 
                            id="dayoff-start-date-input"
                            type="date" 
                            bind:value={selectedDayOffStartDate}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                        />
                    </div>

                    <!-- Day Off End Date Selection -->
                    <div>
                        <label for="dayoff-end-date-input" class="block text-sm font-bold text-slate-700 mb-2">End Date</label>
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
                            🔍 Search Day Off Reason
                        </button>
                    </div>

                    <!-- Selected Reason Display -->
                    {#if selectedDayOffReason}
                        <div class="bg-blue-50 border-2 border-blue-200 rounded-lg p-4">
                            <p class="text-sm font-bold text-slate-700 mb-2">Selected Reason:</p>
                            <p class="text-base font-semibold text-slate-800">{selectedDayOffReason.reason_en}</p>
                            <p class="text-base font-semibold text-slate-700" dir="rtl">{selectedDayOffReason.reason_ar}</p>
                            
                            <!-- Deductible Status -->
                            <div class="mt-3 flex gap-2 flex-wrap">
                                <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {selectedDayOffReason.is_deductible ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
                                    {selectedDayOffReason.is_deductible ? '✓ Deductible' : '✗ Not Deductible'}
                                </span>
                                <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold {selectedDayOffReason.is_document_mandatory ? 'bg-orange-100 text-orange-800' : 'bg-gray-100 text-gray-800'}">
                                    {selectedDayOffReason.is_document_mandatory ? '📄 Document Required' : 'Optional Document'}
                                </span>
                            </div>
                        </div>

                        <!-- Document Upload -->
                        {#if selectedDayOffReason.is_document_mandatory || true}
                            <div>
                                <label for="doc-upload" class="block text-sm font-bold text-slate-700 mb-2">
                                    {selectedDayOffReason.is_document_mandatory ? '📄 Upload Document (Required)' : '📄 Upload Document (Optional)'}
                                </label>
                                <input 
                                    id="doc-upload"
                                    type="file" 
                                    on:change={handleDocumentSelect}
                                    class="w-full px-3 py-2 border-2 border-dashed border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                />
                                {#if documentFile}
                                    <p class="text-xs text-slate-600 mt-2">Selected: {documentFile.name}</p>
                                    {#if isUploadingDocument}
                                        <div class="w-full bg-slate-200 rounded-lg h-2 mt-2">
                                            <div class="bg-emerald-600 h-2 rounded-lg transition-all" style="width: {documentUploadProgress}%"></div>
                                        </div>
                                    {/if}
                                {/if}
                            </div>
                        {/if}
                    {/if}
                {/if}

                {#if activeTab === 'Day Off (weekday-wise)'}
                    <!-- Day Off Weekday Selection -->
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

                {#if activeTab !== 'Day Off (date-wise)' && activeTab !== 'Day Off (weekday-wise)'}
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
                                <option value="AM">AM</option>
                                <option value="PM">PM</option>
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
                                <option value="AM">AM</option>
                                <option value="PM">PM</option>
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
                {#if activeTab === 'Regular Shift' || activeTab === 'Day Off (date-wise)' || activeTab === 'Day Off (weekday-wise)'}
                    <button 
                        class="px-6 py-2 rounded-lg font-black text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                        on:click={activeTab === 'Day Off (date-wise)' ? saveDayOffWithApproval : activeTab === 'Day Off (weekday-wise)' ? saveDayOffWeekday : saveShiftData}
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

<!-- Employee Select Modal for Day Off -->
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

<!-- Employee Select Modal for Day Off Weekday -->
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
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div class="flex items-center justify-between mb-6">
                <h2 class="text-2xl font-bold text-slate-900">Select Day Off Reason</h2>
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
                placeholder="Search by reason name..."
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
                            <div class="flex-1">
                                <p class="font-bold text-slate-800">{reason.reason_en}</p>
                                <p class="text-sm text-slate-600 font-semibold" dir="rtl">{reason.reason_ar}</p>
                                <p class="text-xs text-slate-500 mt-1">ID: {reason.id}</p>
                            </div>
                            <div class="flex gap-2 ml-4">
                                <span class="inline-flex items-center px-2 py-1 rounded text-xs font-bold {reason.is_deductible ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
                                    {reason.is_deductible ? '✓ Ded' : '✗ Non-Ded'}
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
                    Cancel
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Day Off Reason Modal -->
{#if showReasonModal}
    <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
        <div class="bg-white rounded-2xl shadow-2xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            <div class="flex items-center justify-between mb-6">
                <h2 class="text-2xl font-bold text-slate-900">
                    {editingReasonId ? 'Edit Day Off Reason' : 'Add Day Off Reason'}
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
                    <label for="reason-id" class="block text-sm font-bold text-slate-700 mb-2">ID</label>
                    <input 
                        id="reason-id"
                        type="text"
                        value={reasonFormData.id}
                        disabled
                        class="w-full px-4 py-2 bg-slate-100 border border-slate-300 rounded-lg text-slate-600 cursor-not-allowed"
                        placeholder="Auto-generated"
                    />
                </div>

                <!-- English Reason -->
                <div>
                    <label for="reason-en" class="block text-sm font-bold text-slate-700 mb-2">Reason (English)</label>
                    <input 
                        id="reason-en"
                        type="text"
                        bind:value={reasonFormData.reason_en}
                        placeholder="Enter English reason"
                        class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                </div>

                <!-- Arabic Reason -->
                <!-- svelte-ignore a11y_label_has_associated_control -->
                <div>
                    <label for="reason-ar" class="block text-sm font-bold text-slate-700 mb-2">السبب (Arabic)</label>
                    <input 
                        id="reason-ar"
                        type="text"
                        bind:value={reasonFormData.reason_ar}
                        placeholder="أدخل السبب بالعربية"
                        dir="rtl"
                        class="w-full px-4 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-right"
                    />
                </div>

                <!-- Is Deductible Toggle -->
                <!-- svelte-ignore a11y_label_has_associated_control -->
                <div>
                    <label for="deductible-toggle" class="block text-sm font-bold text-slate-700 mb-2">Is Deductible?</label>
                    <button 
                        id="deductible-toggle"
                        type="button"
                        on:click={() => reasonFormData.is_deductible = !reasonFormData.is_deductible}
                        class="w-full px-4 py-3 rounded-lg font-bold text-white transition-all {reasonFormData.is_deductible ? 'bg-green-600 hover:bg-green-700' : 'bg-red-600 hover:bg-red-700'}"
                    >
                        {reasonFormData.is_deductible ? '✓ Yes - Deductible' : '✗ No - Not Deductible'}
                    </button>
                </div>

                <!-- Is Document Mandatory Toggle -->
                <!-- svelte-ignore a11y_label_has_associated_control -->
                <div>
                    <label for="document-toggle" class="block text-sm font-bold text-slate-700 mb-2">Document Required?</label>
                    <button 
                        id="document-toggle"
                        type="button"
                        on:click={() => reasonFormData.is_document_mandatory = !reasonFormData.is_document_mandatory}
                        class="w-full px-4 py-3 rounded-lg font-bold text-white transition-all {reasonFormData.is_document_mandatory ? 'bg-blue-600 hover:bg-blue-700' : 'bg-gray-600 hover:bg-gray-700'}"
                    >
                        {reasonFormData.is_document_mandatory ? '✓ Yes - Document Required' : '✗ No - Document Not Required'}
                    </button>
                </div>

                <!-- Buttons -->
                <div class="flex gap-3 mt-6">
                    <button 
                        type="submit"
                        disabled={isSaving}
                        class="flex-1 px-4 py-2 rounded-lg font-bold text-white bg-blue-600 hover:bg-blue-700 transition disabled:opacity-50"
                    >
                        {isSaving ? 'Saving...' : 'Save'}
                    </button>
                    <button 
                        type="button"
                        on:click={closeReasonModal}
                        class="flex-1 px-4 py-2 rounded-lg font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    >
                        Cancel
                    </button>
                </div>
            </form>
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
                    OK
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Notification Toast -->
{#if showNotification}
    <div class="fixed bottom-6 right-6 z-[9999] animate-in">
        <div class="notification notification-{notificationType} shadow-2xl rounded-lg p-4 min-w-[300px] max-w-[500px]">
            <div class="flex items-start gap-3">
                {#if notificationType === 'success'}
                    <span class="text-2xl">✅</span>
                {:else if notificationType === 'error'}
                    <span class="text-2xl">❌</span>
                {:else}
                    <span class="text-2xl">⚠️</span>
                {/if}
                <div class="flex-1">
                    <p class="text-white font-semibold text-sm leading-relaxed">{notificationMessage}</p>
                </div>
                <button 
                    on:click={() => showNotification = false}
                    class="text-white hover:text-gray-300 transition text-lg leading-none"
                >
                    ✕
                </button>
            </div>
        </div>
    </div>
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
