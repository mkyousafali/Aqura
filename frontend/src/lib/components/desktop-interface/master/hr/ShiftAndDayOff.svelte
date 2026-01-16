<script lang="ts">
    import { onMount } from 'svelte';
    import { t } from '$lib/i18n';
    
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

    interface EmployeeForSelection {
        id: string;
        employee_name_en: string;
        employee_name_ar: string;
        branch_name_en: string;
        branch_name_ar: string;
    }

    let activeTab = 'Regular Shift';
    let employees: EmployeeShift[] = [];
    let employeesForDateWiseSelection: EmployeeForSelection[] = [];
    let allEmployeesForDateWise: EmployeeForSelection[] = [];
    let dateWiseShifts: (EmployeeShift & {shift_date?: string})[] = [];
    let dayOffs: (EmployeeShift & {day_off_date?: string})[] = [];
    let dayOffsWeekday: (EmployeeShift & {day_off_weekday?: number})[] = [];
    let loading = false;
    let error: string | null = null;
    let showModal = false;
    let showDeleteModal = false;
    let showEmployeeSelectModal = false;
    let showDayOffEmployeeSelectModal = false;
    let showDayOffWeekdayEmployeeSelectModal = false;
    let selectedEmployeeId: string | null = null;
    let selectedDeleteWeekday: number = 0;
    let selectedDayOffWeekday: number = 0;
    let isSaving = false;
    let employeeSearchQuery = '';
    let selectedDayOffDate: string = new Date().toISOString().split('T')[0];
    let regularShiftSearchQuery = '';
    let selectedBranchFilter = '';
    let selectedNationalityFilter = '';
    let specialWeekdaySearchQuery = '';
    let specialWeekdayBranchFilter = '';
    let specialWeekdayNationalityFilter = '';
    let specialDateSearchQuery = '';
    let specialDateBranchFilter = '';
    let specialDateNationalityFilter = '';
    let dayOffSearchQuery = '';
    let dayOffBranchFilter = '';
    let dayOffNationalityFilter = '';
    let dayOffWeekdaySearchQuery = '';
    let dayOffWeekdayBranchFilter = '';
    let dayOffWeekdayNationalityFilter = '';
    let availableBranches: {id: string, name_en: string, name_ar: string}[] = [];
    let availableNationalities: {id: string, name_en: string, name_ar: string}[] = []

    const weekdayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    // Form data for modal
    let formData: RegularShiftData | SpecialShiftWeekdayData | SpecialShiftDateWiseData = {
        id: '',
        shift_start_time: '09:00',
        shift_start_buffer: 0,
        shift_end_time: '17:00',
        shift_end_buffer: 0,
        is_shift_overlapping_next_day: false
    } as RegularShiftData;

    const tabs = [
        { id: 'Regular Shift', icon: '🕒', color: 'green' },
        { id: 'Special Shift (weekday-wise)', icon: '📅', color: 'orange' },
        { id: 'Special Shift (date-wise)', icon: '📆', color: 'orange' },
        { id: 'Day Off (date-wise)', icon: '🏖️', color: 'green' },
        { id: 'Day Off (weekday-wise)', icon: '📋', color: 'green' }
    ];

    onMount(async () => {
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
        }
    });

    async function loadEmployeeShiftData() {
        loading = true;
        error = null;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id
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

            const branchMap = new Map(branches?.map(b => [b.id, b]) || []);
            const nationalityMap = new Map(nationalities?.map(n => [n.id, n]) || []);
            const shiftMap = new Map(shifts?.map(s => [s.id, s]) || []);

            // Populate available branches for filter
            availableBranches = branches || [];
            availableNationalities = nationalities || [];

            // Combine data
            employees = employeeData.map(emp => {
                const branch = branchMap.get(emp.current_branch_id);
                const nationality = nationalityMap.get(emp.nationality_id);
                const shift = shiftMap.get(emp.id);

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
                    shift_start_time: shift?.shift_start_time,
                    shift_start_buffer: shift?.shift_start_buffer,
                    shift_end_time: shift?.shift_end_time,
                    shift_end_buffer: shift?.shift_end_buffer,
                    is_shift_overlapping_next_day: shift?.is_shift_overlapping_next_day,
                    working_hours: shift?.working_hours
                };
            }).sort((a, b) => {
                // Extract numeric part from employee ID (e.g., "EMP1" -> 1)
                const numA = parseInt(a.id.replace(/\D/g, '')) || 0;
                const numB = parseInt(b.id.replace(/\D/g, '')) || 0;
                return numA - numB;
            });
        } catch (err) {
            console.error('Error loading employee shift data:', err);
            error = err instanceof Error ? err.message : 'Failed to load data';
        } finally {
            loading = false;
        }
    }

    async function loadSpecialShiftWeekdayData() {
        loading = true;
        error = null;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id
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

            const branchMap = new Map(branches?.map(b => [b.id, b]) || []);
            const nationalityMap = new Map(nationalities?.map(n => [n.id, n]) || []);

            // Populate available branches and nationalities for filter
            availableBranches = branches || [];
            availableNationalities = nationalities || [];

            // Group shifts by employee_id and weekday
            const shiftMap = new Map<string, Map<number, any>>();
            shifts?.forEach(shift => {
                if (!shiftMap.has(shift.employee_id)) {
                    shiftMap.set(shift.employee_id, new Map());
                }
                shiftMap.get(shift.employee_id)!.set(shift.weekday, shift);
            });

            // Combine data
            employees = employeeData.map(emp => {
                const branch = branchMap.get(emp.current_branch_id);
                const nationality = nationalityMap.get(emp.nationality_id);
                const empShifts = shiftMap.get(emp.id) || new Map();

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
                    shifts: shiftsObj
                };
            }).sort((a, b) => {
                // Extract numeric part from employee ID (e.g., "EMP1" -> 1)
                const numA = parseInt(a.id.replace(/\D/g, '')) || 0;
                const numB = parseInt(b.id.replace(/\D/g, '')) || 0;
                return numA - numB;
            });
        } catch (err) {
            console.error('Error loading employee special shift data:', err);
            error = err instanceof Error ? err.message : 'Failed to load data';
        } finally {
            loading = false;
        }
    }

    async function loadSpecialShiftDateWiseData() {
        loading = true;
        error = null;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            // Get all employees for selection
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id
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

            const branchMap = new Map(branches?.map(b => [b.id, b]) || []);

            // Populate available branches for filter
            availableBranches = branches || [];

            // Build employee selection list
            allEmployeesForDateWise = employeeData.map(emp => {
                const branch = branchMap.get(emp.current_branch_id);
                return {
                    id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A'
                };
            }).sort((a, b) => {
                const numA = parseInt(a.id.replace(/\D/g, '')) || 0;
                const numB = parseInt(b.id.replace(/\D/g, '')) || 0;
                return numA - numB;
            });

            employeesForDateWiseSelection = [...allEmployeesForDateWise];

            // Get nationality information
            const nationalityIds = [...new Set(employeeData.map(e => e.nationality_id).filter(Boolean))];
            let nationalities: any[] = [];
            if (nationalityIds.length > 0) {
                const { data: nat, error: natError } = await supabase
                    .from('nationalities')
                    .select('id, name_en, name_ar')
                    .in('id', nationalityIds);
                if (natError) throw natError;
                nationalities = nat || [];
            }

            const nationalityMap = new Map(nationalities.map(n => [n.id, n]) || []);

            // Populate available nationalities for filter
            availableNationalities = nationalities || [];

            // Get special shift date-wise data
            const { data: shifts, error: shiftError } = await supabase
                .from('special_shift_date_wise')
                .select('*')
                .order('shift_date', { ascending: false });

            if (shiftError && shiftError.code !== 'PGRST116') throw shiftError; // 404 is OK

            // Map shifts with employee details
            dateWiseShifts = (shifts || []).map(shift => {
                const emp = employeeData.find(e => e.id === shift.employee_id);
                const branch = emp ? branchMap.get(emp.current_branch_id) : null;
                const nationality = emp ? nationalityMap.get(emp.nationality_id) : null;

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
                    shift_date: shift.shift_date,
                    shift_start_time: shift.shift_start_time,
                    shift_start_buffer: shift.shift_start_buffer,
                    shift_end_time: shift.shift_end_time,
                    shift_end_buffer: shift.shift_end_buffer,
                    is_shift_overlapping_next_day: shift.is_shift_overlapping_next_day,
                    working_hours: shift.working_hours
                };
            });
        } catch (err) {
            console.error('Error loading special shift date-wise data:', err);
            error = err instanceof Error ? err.message : 'Failed to load data';
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
            const { supabase } = await import('$lib/utils/supabase');
            
            // Get all employees for selection
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id
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
                nationalities = nat || [];
            }

            const branchMap = new Map(branches?.map(b => [b.id, b]) || []);
            const nationalityMap = new Map(nationalities.map(n => [n.id, n]) || []);

            // Populate available branches and nationalities for filter
            availableBranches = branches || [];
            availableNationalities = nationalities || [];

            // Build employee selection list
            allEmployeesForDateWise = employeeData.map(emp => {
                const branch = branchMap.get(emp.current_branch_id);
                return {
                    id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A'
                };
            }).sort((a, b) => {
                const numA = parseInt(a.id.replace(/\D/g, '')) || 0;
                const numB = parseInt(b.id.replace(/\D/g, '')) || 0;
                return numA - numB;
            });

            employeesForDateWiseSelection = [...allEmployeesForDateWise];

            // Get day off data
            const { data: dayOffData, error: dayOffError } = await supabase
                .from('day_off')
                .select('*')
                .order('day_off_date', { ascending: false });

            if (dayOffError && dayOffError.code !== 'PGRST116') throw dayOffError; // 404 is OK

            // Map day offs with employee details
            dayOffs = (dayOffData || []).map(dayOff => {
                const emp = employeeData.find(e => e.id === dayOff.employee_id);
                const branch = emp ? branchMap.get(emp.current_branch_id) : null;
                const nationality = emp ? nationalityMap.get(emp.nationality_id) : null;

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
                    day_off_date: dayOff.day_off_date
                };
            });
        } catch (err) {
            console.error('Error loading day off data:', err);
            error = err instanceof Error ? err.message : 'Failed to load data';
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
        selectedDayOffDate = new Date().toISOString().split('T')[0];
        showModal = true;
    }

    async function loadDayOffWeekdayData() {
        loading = true;
        error = null;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            const { data: employeeData, error: empError } = await supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    current_branch_id,
                    nationality_id
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

            const branchMap = new Map(branches?.map(b => [b.id, b]) || []);
            const nationalityMap = new Map(nationalities?.map(n => [n.id, n]) || []);

            // Populate available branches and nationalities for filter
            availableBranches = branches || [];
            availableNationalities = nationalities || [];

            // Build employee selection list
            allEmployeesForDateWise = employeeData.map(emp => {
                const branch = branchMap.get(emp.current_branch_id);
                return {
                    id: emp.id,
                    employee_name_en: emp.name_en,
                    employee_name_ar: emp.name_ar,
                    branch_name_en: branch?.name_en || 'N/A',
                    branch_name_ar: branch?.name_ar || 'N/A'
                };
            }).sort((a, b) => {
                const numA = parseInt(a.id.replace(/\D/g, '')) || 0;
                const numB = parseInt(b.id.replace(/\D/g, '')) || 0;
                return numA - numB;
            });

            employeesForDateWiseSelection = [...allEmployeesForDateWise];

            // Get day off weekday data
            const { data: dayOffWeekdayData, error: dayOffError } = await supabase
                .from('day_off_weekday')
                .select('*')
                .order('weekday', { ascending: true });

            if (dayOffError && dayOffError.code !== 'PGRST116') throw dayOffError;

            // Map day offs with employee details
            dayOffsWeekday = (dayOffWeekdayData || []).map(dayOff => {
                const emp = employeeData.find(e => e.id === dayOff.employee_id);
                const branch = emp ? branchMap.get(emp.current_branch_id) : null;
                const nationality = emp ? nationalityMap.get(emp.nationality_id) : null;

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
                    day_off_weekday: dayOff.weekday
                };
            });
        } catch (err) {
            console.error('Error loading day off weekday data:', err);
            error = err instanceof Error ? err.message : 'Failed to load data';
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
        specialWeekdaySearchQuery = '';
        specialWeekdayBranchFilter = '';
        specialWeekdayNationalityFilter = '';
        specialDateSearchQuery = '';
        specialDateBranchFilter = '';
        specialDateNationalityFilter = '';
        dayOffSearchQuery = '';
        dayOffBranchFilter = '';
        dayOffNationalityFilter = '';
        dayOffWeekdaySearchQuery = '';
        dayOffWeekdayBranchFilter = '';
        dayOffWeekdayNationalityFilter = '';
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
        if (!confirm(`Delete shift for ${weekdayNames[weekdayNum]}?`)) return;
        
        try {
            const { supabase } = await import('$lib/utils/supabase');
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
            alert('Failed to delete shift data: ' + (err instanceof Error ? err.message : 'Unknown error'));
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
            const { supabase } = await import('$lib/utils/supabase');
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
            alert('Failed to delete shift data: ' + (err instanceof Error ? err.message : 'Unknown error'));
        }
    }

    async function deleteSpecialShiftDateWise(shiftId: string, employeeId: string, shiftDate: string) {
        if (!confirm('Are you sure you want to delete this shift?')) return;

        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { error } = await supabase
                .from('special_shift_date_wise')
                .delete()
                .eq('id', shiftId);

            if (error) throw error;

            // Update local data
            dateWiseShifts = dateWiseShifts.filter(s => !(s.employee_id === employeeId && s.shift_date === shiftDate));
        } catch (err) {
            console.error('Error deleting shift:', err);
            alert('Failed to delete: ' + (err instanceof Error ? err.message : 'Unknown error'));
        }
    }

    async function saveDayOff() {
        if (!selectedEmployeeId || !selectedDayOffDate) {
            alert('Please select an employee and date');
            return;
        }

        isSaving = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
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
            alert('Failed to save day off: ' + (err instanceof Error ? err.message : 'Unknown error'));
        } finally {
            isSaving = false;
        }
    }

    async function deleteDayOff(dayOffId: string, employeeId: string, dayOffDate: string) {
        if (!confirm('Are you sure you want to delete this day off?')) return;

        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { error } = await supabase
                .from('day_off')
                .delete()
                .eq('id', dayOffId);

            if (error) throw error;

            // Update local data
            dayOffs = dayOffs.filter(d => !(d.employee_id === employeeId && d.day_off_date === dayOffDate));
        } catch (err) {
            console.error('Error deleting day off:', err);
            alert('Failed to delete: ' + (err instanceof Error ? err.message : 'Unknown error'));
        }
    }

    async function saveDayOffWeekday() {
        if (!selectedEmployeeId || selectedDayOffWeekday === null) {
            alert('Please select an employee and weekday');
            return;
        }

        isSaving = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
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
            alert('Failed to save day off: ' + (err instanceof Error ? err.message : 'Unknown error'));
        } finally {
            isSaving = false;
        }
    }

    async function deleteDayOffWeekday(dayOffId: string, employeeId: string, weekday: number) {
        if (!confirm('Are you sure you want to delete this day off?')) return;

        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { error } = await supabase
                .from('day_off_weekday')
                .delete()
                .eq('id', dayOffId);

            if (error) throw error;

            // Update local data
            dayOffsWeekday = dayOffsWeekday.filter(d => !(d.employee_id === employeeId && d.day_off_weekday === weekday));
        } catch (err) {
            console.error('Error deleting day off weekday:', err);
            alert('Failed to delete: ' + (err instanceof Error ? err.message : 'Unknown error'));
        }
    }

    async function saveShiftData() {
        isSaving = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
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
            alert('Failed to save shift data: ' + (err instanceof Error ? err.message : 'Unknown error'));
        } finally {
            isSaving = false;
        }
    }

    function formatTimeDisplay(time: string | undefined): string {
        return formatTimeTo12Hour(time);
    }

    function formatBranchDisplay(emp: EmployeeShift): string {
        const parts = [emp.branch_name_en];
        if (emp.branch_name_ar) parts.push(emp.branch_name_ar);
        if (emp.branch_location_en) parts.push(`(${emp.branch_location_en})`);
        if (emp.branch_location_ar) parts.push(`(${emp.branch_location_ar})`);
        return parts.join(' ');
    }

    function formatEmployeeNameDisplay(emp: EmployeeShift): string {
        const parts = [emp.employee_name_en];
        if (emp.employee_name_ar) parts.push(emp.employee_name_ar);
        return parts.join(' / ');
    }

    function formatNationalityDisplay(emp: EmployeeShift): string {
        const parts = [emp.nationality_name_en];
        if (emp.nationality_name_ar) parts.push(emp.nationality_name_ar);
        return parts.join(' / ');
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

    function getFilteredEmployees(): EmployeeShift[] {
        let filtered = employees;

        // Filter by branch
        if (selectedBranchFilter) {
            filtered = filtered.filter(emp => emp.branch_id === selectedBranchFilter);
        }

        // Filter by nationality
        if (selectedNationalityFilter) {
            filtered = filtered.filter(emp => emp.nationality_id === selectedNationalityFilter);
        }

        // Filter by search query
        if (regularShiftSearchQuery.trim()) {
            const query = regularShiftSearchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                emp.id?.toLowerCase().includes(query)
            );
        }

        return filtered;
    }

    function getFilteredSpecialWeekdayEmployees(): EmployeeShift[] {
        let filtered = employees;

        if (specialWeekdayBranchFilter) {
            filtered = filtered.filter(emp => emp.branch_id === specialWeekdayBranchFilter);
        }

        if (specialWeekdayNationalityFilter) {
            filtered = filtered.filter(emp => emp.nationality_id === specialWeekdayNationalityFilter);
        }

        if (specialWeekdaySearchQuery.trim()) {
            const query = specialWeekdaySearchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                emp.id?.toLowerCase().includes(query)
            );
        }

        return filtered;
    }

    function getFilteredSpecialDateShifts() {
        let filtered = dateWiseShifts;

        if (specialDateBranchFilter) {
            filtered = filtered.filter(emp => emp.branch_id === specialDateBranchFilter);
        }

        if (specialDateNationalityFilter) {
            filtered = filtered.filter(emp => emp.nationality_id === specialDateNationalityFilter);
        }

        if (specialDateSearchQuery.trim()) {
            const query = specialDateSearchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                emp.id?.toLowerCase().includes(query)
            );
        }

        return filtered;
    }

    function getFilteredDayOffs() {
        let filtered = dayOffs;

        if (dayOffBranchFilter) {
            filtered = filtered.filter(emp => emp.branch_id === dayOffBranchFilter);
        }

        if (dayOffNationalityFilter) {
            filtered = filtered.filter(emp => emp.nationality_id === dayOffNationalityFilter);
        }

        if (dayOffSearchQuery.trim()) {
            const query = dayOffSearchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                emp.id?.toLowerCase().includes(query)
            );
        }

        return filtered;
    }

    function getFilteredDayOffsWeekday() {
        let filtered = dayOffsWeekday;

        if (dayOffWeekdayBranchFilter) {
            filtered = filtered.filter(emp => emp.branch_id === dayOffWeekdayBranchFilter);
        }

        if (dayOffWeekdayNationalityFilter) {
            filtered = filtered.filter(emp => emp.nationality_id === dayOffWeekdayNationalityFilter);
        }

        if (dayOffWeekdaySearchQuery.trim()) {
            const query = dayOffWeekdaySearchQuery.toLowerCase();
            filtered = filtered.filter(emp =>
                emp.employee_name_en?.toLowerCase().includes(query) ||
                (emp.employee_name_ar && emp.employee_name_ar.toLowerCase().includes(query)) ||
                emp.id?.toLowerCase().includes(query)
            );
        }

        return filtered;
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
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
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
                    <span class="relative z-10">{tab.id}</span>
                    
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
                            <p class="mt-4 text-slate-600 font-semibold">Loading employee shift data...</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">Error: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadEmployeeShiftData}
                        >
                            Retry
                        </button>
                    </div>
                {:else if employees.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📭</div>
                        <p class="text-slate-600 font-semibold">No employees found</p>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Branch</label>
                            <select 
                                bind:value={selectedBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Branches</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id}>{branch.name_en} {branch.name_ar ? `/ ${branch.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Nationality</label>
                            <select 
                                bind:value={selectedNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Nationalities</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id}>{nationality.name_en} {nationality.name_ar ? `/ ${nationality.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Search Employee</label>
                            <input 
                                type="text"
                                bind:value={regularShiftSearchQuery}
                                placeholder="Search by name or ID..."
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
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Employee ID</th>
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Employee Name</th>
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Branch</th>
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Nationality</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Shift Start</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Start Buffer (hrs)</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Shift End</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">End Buffer (hrs)</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Overlaps Next Day</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Working Hours</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Action</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each getFilteredEmployees() as employee, index}
                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm font-semibold text-slate-800">{employee.id}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(employee)}</td>
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
                                                {employee.working_hours ? employee.working_hours.toFixed(2) : '—'} hrs
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                {#if employee.shift_start_time}
                                                    <button 
                                                        class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
                                                        on:click={() => openModal(employee.id)}
                                                        title="Edit shift details"
                                                    >
                                                        ✏️ Edit
                                                    </button>
                                                {:else}
                                                    <button 
                                                        class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-emerald-600 text-white font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                        on:click={() => openModal(employee.id)}
                                                        title="Add shift details"
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
                            Showing {employees.length} employee(s)
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
                            <p class="mt-4 text-slate-600 font-semibold">Loading employee special shift data...</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">Error: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadSpecialShiftWeekdayData}
                        >
                            Retry
                        </button>
                    </div>
                {:else if employees.length === 0}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                        <div class="text-5xl mb-4">📭</div>
                        <p class="text-slate-600 font-semibold">No employees found</p>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Branch</label>
                            <select 
                                bind:value={specialWeekdayBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Branches</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id}>{branch.name_en} {branch.name_ar ? `/ ${branch.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Nationality</label>
                            <select 
                                bind:value={specialWeekdayNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Nationalities</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id}>{nationality.name_en} {nationality.name_ar ? `/ ${nationality.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Search Employee</label>
                            <input 
                                type="text"
                                bind:value={specialWeekdaySearchQuery}
                                placeholder="Search by name or ID..."
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
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Employee ID</th>
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Employee Name</th>
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Branch</th>
                                        <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Nationality</th>
                                        {#each weekdayNames as weekday}
                                            <th colspan="3" class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400 bg-orange-500/50">
                                                {weekday}
                                            </th>
                                        {/each}
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Action</th>
                                    </tr>
                                    <tr>
                                        <th colspan="4" class="text-xs"></th>
                                    {#each weekdayNames as weekday}
                                            <th class="px-2 py-2 text-center text-[10px] font-bold text-slate-600 border-b border-orange-300">Start</th>
                                            <th class="px-2 py-2 text-center text-[10px] font-bold text-slate-600 border-b border-orange-300">End</th>
                                            <th class="px-2 py-2 text-center text-[10px] font-bold text-slate-600 border-b border-orange-300">Hours</th>
                                        {/each}
                                        <th class="text-xs"></th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each getFilteredSpecialWeekdayEmployees() as employee, index}
                                        <tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                            <td class="px-4 py-3 text-sm font-semibold text-slate-800">{employee.id}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(employee)}</td>
                                            <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(employee)}</td>
                                            {#each renderShiftColumns(employee) as shiftCol}
                                                <td class="px-2 py-3 text-xs text-center font-mono text-slate-800">{shiftCol.startTime}</td>
                                                <td class="px-2 py-3 text-xs text-center font-mono text-slate-800">{shiftCol.endTime}</td>
                                                <td class="px-2 py-3 text-xs text-center font-mono font-bold text-orange-700">
                                                    {shiftCol.workingHours} {shiftCol.workingHours !== '—' ? 'hrs' : ''}
                                                </td>
                                            {/each}
                                            <td class="px-4 py-3 text-sm text-center flex gap-2 justify-center">
                                                <button 
                                                    class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-orange-600 text-white font-bold hover:bg-orange-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                    on:click={() => openModal(employee.id)}
                                                    title="Add/Edit special shift"
                                                >
                                                    +
                                                </button>
                                                <button 
                                                    class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                    on:click={() => openDeleteModal(employee.id)}
                                                    title="Delete special shift"
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
                            Showing {getFilteredSpecialWeekdayEmployees().length} of {employees.length} employee(s)
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
                            <p class="mt-4 text-slate-600 font-semibold">Loading special shift date-wise data...</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">Error: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadSpecialShiftDateWiseData}
                        >
                            Retry
                        </button>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Branch</label>
                            <select 
                                bind:value={specialDateBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Branches</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id}>{branch.name_en} {branch.name_ar ? `/ ${branch.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Nationality</label>
                            <select 
                                bind:value={specialDateNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Nationalities</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id}>{nationality.name_en} {nationality.name_ar ? `/ ${nationality.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Search Employee</label>
                            <input 
                                type="text"
                                bind:value={specialDateSearchQuery}
                                placeholder="Search by name or ID..."
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
                                Special Shift
                            </button>
                            <p class="text-xs text-slate-500 font-semibold">Click to add new special shift for a specific date</p>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if dateWiseShifts.length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">No special shifts configured</p>
                                        <p class="text-slate-400 text-sm mt-2">Click the "Special Shift" button above to add one</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse">
                                    <thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Employee ID</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Employee Name</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Branch</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Nationality</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Date</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Start Time</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Start Buffer</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">End Time</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">End Buffer</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Overlaps</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Working Hrs</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Action</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each getFilteredSpecialDateShifts() as shift, index}
                                            <tr class="hover:bg-orange-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{shift.employee_id}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(shift)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(shift)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(shift)}</td>
                                                <td class="px-4 py-3 text-sm font-mono text-slate-800">{shift.shift_date}</td>
                                                <td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatTimeTo12Hour(shift.shift_start_time || '')}</td>
                                                <td class="px-4 py-3 text-sm text-center font-mono text-slate-700">{shift.shift_start_buffer || 0} hrs</td>
                                                <td class="px-4 py-3 text-sm text-center font-mono text-slate-800">{formatTimeTo12Hour(shift.shift_end_time || '')}</td>
                                                <td class="px-4 py-3 text-sm text-center font-mono text-slate-700">{shift.shift_end_buffer || 0} hrs</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <span class="inline-block px-2 py-1 rounded-full text-xs font-black {shift.is_shift_overlapping_next_day ? 'bg-orange-200 text-orange-800' : 'bg-slate-200 text-slate-800'}">
                                                        {shift.is_shift_overlapping_next_day ? 'Yes' : 'No'}
                                                    </span>
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center font-bold text-orange-700">
                                                    {shift.working_hours} hrs
                                                </td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <button 
                                                        class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                        on:click={() => deleteSpecialShiftDateWise(shift.id, shift.employee_id, shift.shift_date)}
                                                        title="Delete this shift"
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
                            Showing {getFilteredSpecialDateShifts().length} of {dateWiseShifts.length} shift(s)
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
                            <p class="mt-4 text-slate-600 font-semibold">Loading day off data...</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">Error: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadDayOffData}
                        >
                            Retry
                        </button>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Branch</label>
                            <select 
                                bind:value={dayOffBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Branches</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id}>{branch.name_en} {branch.name_ar ? `/ ${branch.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Nationality</label>
                            <select 
                                bind:value={dayOffNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Nationalities</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id}>{nationality.name_en} {nationality.name_ar ? `/ ${nationality.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Search Employee</label>
                            <input 
                                type="text"
                                bind:value={dayOffSearchQuery}
                                placeholder="Search by name or ID..."
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
                                Add Day Off (Date-wise)
                            </button>
                            <p class="text-xs text-slate-500 font-semibold">Click to assign a specific day off</p>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if getFilteredDayOffs().length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">No day offs found</p>
                                        <p class="text-slate-400 text-sm mt-2">{dayOffs.length === 0 ? 'Click the button above to assign one' : 'Try adjusting your filters'}</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse">
                                    <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Employee ID</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Employee Name</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Branch</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Nationality</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Day Off Date</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Action</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each getFilteredDayOffs() as dayOff, index}
                                            <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{dayOff.employee_id}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm font-mono text-slate-800">{dayOff.day_off_date}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <button 
                                                        class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                        on:click={() => deleteDayOff(dayOff.id, dayOff.employee_id, dayOff.day_off_date)}
                                                        title="Delete this day off"
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
                            Showing {getFilteredDayOffs().length} of {dayOffs.length} day off(s)
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
                            <p class="mt-4 text-slate-600 font-semibold">Loading day off weekday data...</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">Error: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadDayOffWeekdayData}
                        >
                            Retry
                        </button>
                    </div>
                {:else}
                    <!-- Filter Controls -->
                    <div class="mb-4 flex gap-3">
                        <!-- Branch Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Branch</label>
                            <select 
                                bind:value={dayOffWeekdayBranchFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Branches</option>
                                {#each availableBranches as branch}
                                    <option value={branch.id}>{branch.name_en} {branch.name_ar ? `/ ${branch.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Nationality Filter -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Filter by Nationality</label>
                            <select 
                                bind:value={dayOffWeekdayNationalityFilter}
                                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            >
                                <option value="">All Nationalities</option>
                                {#each availableNationalities as nationality}
                                    <option value={nationality.id}>{nationality.name_en} {nationality.name_ar ? `/ ${nationality.name_ar}` : ''}</option>
                                {/each}
                            </select>
                        </div>

                        <!-- Employee Search -->
                        <div class="flex-1">
                            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Search Employee</label>
                            <input 
                                type="text"
                                bind:value={dayOffWeekdaySearchQuery}
                                placeholder="Search by name or ID..."
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
                                Add Day Off (Weekday-wise)
                            </button>
                            <p class="text-xs text-slate-500 font-semibold">Click to assign recurring day offs</p>
                        </div>

                        <!-- Table Wrapper -->
                        <div class="overflow-x-auto flex-1">
                            {#if getFilteredDayOffsWeekday().length === 0}
                                <div class="flex items-center justify-center h-64">
                                    <div class="text-center">
                                        <div class="text-5xl mb-4">📭</div>
                                        <p class="text-slate-600 font-semibold">No day offs found</p>
                                        <p class="text-slate-400 text-sm mt-2">{dayOffsWeekday.length === 0 ? 'Click the button above to assign one' : 'Try adjusting your filters'}</p>
                                    </div>
                                </div>
                            {:else}
                                <table class="w-full border-collapse">
                                    <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                        <tr>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Employee ID</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Employee Name</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Branch</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Nationality</th>
                                            <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Day Off Weekday</th>
                                            <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Action</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-slate-200">
                                        {#each getFilteredDayOffsWeekday() as dayOff, index}
                                            <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{dayOff.employee_id}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatEmployeeNameDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatBranchDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm text-slate-700">{formatNationalityDisplay(dayOff)}</td>
                                                <td class="px-4 py-3 text-sm font-semibold text-slate-800">{weekdayNames[dayOff.day_off_weekday]}</td>
                                                <td class="px-4 py-3 text-sm text-center">
                                                    <button 
                                                        class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-110"
                                                        on:click={() => deleteDayOffWeekday(dayOff.id, dayOff.employee_id, dayOff.day_off_weekday)}
                                                        title="Delete this day off"
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
                            Showing {getFilteredDayOffsWeekday().length} of {dayOffsWeekday.length} day off(s)
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
                    {activeTab === 'Regular Shift' ? 'Configure Regular Shift' : activeTab === 'Special Shift (weekday-wise)' ? 'Configure Special Shift (Weekday-wise)' : activeTab === 'Special Shift (date-wise)' ? 'Configure Special Shift (Date-wise)' : activeTab === 'Day Off (date-wise)' ? 'Assign Day Off (Date-wise)' : 'Assign Day Off (Weekday-wise)'}
                </h3>
                <p class="{activeTab === 'Regular Shift' || activeTab === 'Day Off (date-wise)' || activeTab === 'Day Off (weekday-wise)' ? 'text-emerald-100' : 'text-orange-100'} text-sm mt-1">Employee ID: {selectedEmployeeId}</p>
            </div>

            <!-- Modal Body -->
            <div class="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
                {#if activeTab === 'Special Shift (weekday-wise)' && 'weekday' in formData}
                    <!-- Weekday Selection -->
                    <div>
                        <label for="weekday-select" class="block text-sm font-bold text-slate-700 mb-2">Select Weekday</label>
                        <select 
                            id="weekday-select"
                            bind:value={formData.weekday}
                            on:change={onWeekdayChange}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                        >
                            {#each weekdayNames as day, index}
                                <option value={index}>{day}</option>
                            {/each}
                        </select>
                    </div>
                {/if}

                {#if activeTab === 'Special Shift (date-wise)' && 'shift_date' in formData}
                    <!-- Date Selection -->
                    <div>
                        <label for="shift-date-input" class="block text-sm font-bold text-slate-700 mb-2">Shift Date</label>
                        <input 
                            id="shift-date-input"
                            type="date" 
                            bind:value={formData.shift_date}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                        />
                    </div>
                {/if}

                {#if activeTab === 'Day Off (date-wise)'}
                    <!-- Day Off Date Selection -->
                    <div>
                        <label for="dayoff-date-input" class="block text-sm font-bold text-slate-700 mb-2">Day Off Date</label>
                        <input 
                            id="dayoff-date-input"
                            type="date" 
                            bind:value={selectedDayOffDate}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                        />
                    </div>
                {/if}

                {#if activeTab === 'Day Off (weekday-wise)'}
                    <!-- Day Off Weekday Selection -->
                    <div>
                        <label for="dayoff-weekday-select" class="block text-sm font-bold text-slate-700 mb-2">Day Off Weekday</label>
                        <select 
                            id="dayoff-weekday-select"
                            bind:value={selectedDayOffWeekday}
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                        >
                            {#each weekdayNames as day, index}
                                <option value={index}>{day}</option>
                            {/each}
                        </select>
                    </div>
                {/if}

                {#if activeTab !== 'Day Off (date-wise)' && activeTab !== 'Day Off (weekday-wise)'}
                    <!-- Shift Start Time -->
                    <div>
                        <label for="start-time-input" class="block text-sm font-bold text-slate-700 mb-2">Shift Start Time</label>
                        {#if activeTab === 'Regular Shift'}
                            <input 
                                id="start-time-input"
                                type="time" 
                                bind:value={formData.shift_start_time}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                            />
                        {:else}
                            <input 
                                id="start-time-input"
                                type="time" 
                                bind:value={formData.shift_start_time}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                            />
                        {/if}
                    </div>

                    <!-- Start Time Buffer -->
                    <div>
                        <label for="start-buffer-input" class="block text-sm font-bold text-slate-700 mb-2">Start Time Buffer (Hours)</label>
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
                        <label for="end-time-input" class="block text-sm font-bold text-slate-700 mb-2">Shift End Time</label>
                        {#if activeTab === 'Regular Shift'}
                            <input 
                                id="end-time-input"
                                type="time" 
                                bind:value={formData.shift_end_time}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                            />
                        {:else}
                            <input 
                                id="end-time-input"
                                type="time" 
                                bind:value={formData.shift_end_time}
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                            />
                        {/if}
                    </div>

                    <!-- End Time Buffer -->
                    <div>
                        <label for="end-buffer-input" class="block text-sm font-bold text-slate-700 mb-2">End Time Buffer (Hours)</label>
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
                            Shift Overlaps to Next Day
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
                    Cancel
                </button>
                {#if activeTab === 'Regular Shift' || activeTab === 'Day Off (date-wise)' || activeTab === 'Day Off (weekday-wise)'}
                    <button 
                        class="px-6 py-2 rounded-lg font-black text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                        on:click={activeTab === 'Day Off (date-wise)' ? saveDayOff : activeTab === 'Day Off (weekday-wise)' ? saveDayOffWeekday : saveShiftData}
                        disabled={isSaving}
                    >
                        {isSaving ? 'Saving...' : 'Save'}
                    </button>
                {:else}
                    <button 
                        class="px-6 py-2 rounded-lg font-black text-white bg-orange-600 hover:bg-orange-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                        on:click={saveShiftData}
                        disabled={isSaving}
                    >
                        {isSaving ? 'Saving...' : 'Save'}
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
                <h3 class="text-lg font-bold">Select Employee</h3>
                <p class="text-orange-100 text-sm mt-1">Choose an employee to assign a special shift date</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Search Input -->
                <div>
                    <label for="employee-search-input" class="block text-sm font-bold text-slate-700 mb-2">Search Employee</label>
                    <input 
                        id="employee-search-input"
                        type="text" 
                        placeholder="Search by name, ID, or branch..."
                        bind:value={employeeSearchQuery}
                        on:input={onEmployeeSearchChange}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                    />
                </div>

                <!-- Employee List -->
                <div class="border border-slate-200 rounded-lg max-h-96 overflow-y-auto">
                    {#if employeesForDateWiseSelection.length === 0}
                        <div class="px-4 py-6 text-center text-slate-500 text-sm">
                            No employees found
                        </div>
                    {:else}
                        {#each employeesForDateWiseSelection as employee}
                            <button 
                                class="w-full text-left px-4 py-3 hover:bg-orange-50 border-b border-slate-100 last:border-b-0 transition-colors duration-200"
                                on:click={() => selectEmployeeForDateWise(employee.id)}
                            >
                                <div class="flex items-center justify-between">
                                    <div>
                                        <p class="font-semibold text-slate-900">{employee.employee_name_en}</p>
                                        <p class="text-xs text-slate-500">{employee.id} • {employee.branch_name_en}</p>
                                        {#if employee.employee_name_ar}
                                            <p class="text-xs text-slate-600 mt-1">{employee.employee_name_ar}</p>
                                        {/if}
                                    </div>
                                    <div class="text-orange-600 font-bold">→</div>
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
                    Cancel
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
                <h3 class="text-lg font-bold">Select Employee</h3>
                <p class="text-emerald-100 text-sm mt-1">Choose an employee to assign a day off</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Search Input -->
                <div>
                    <label for="dayoff-employee-search-input" class="block text-sm font-bold text-slate-700 mb-2">Search Employee</label>
                    <input 
                        id="dayoff-employee-search-input"
                        type="text" 
                        placeholder="Search by name, ID, or branch..."
                        bind:value={employeeSearchQuery}
                        on:input={onEmployeeSearchChange}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                    />
                </div>

                <!-- Employee List -->
                <div class="border border-slate-200 rounded-lg max-h-96 overflow-y-auto">
                    {#if employeesForDateWiseSelection.length === 0}
                        <div class="px-4 py-6 text-center text-slate-500 text-sm">
                            No employees found
                        </div>
                    {:else}
                        {#each employeesForDateWiseSelection as employee}
                            <button 
                                class="w-full text-left px-4 py-3 hover:bg-emerald-50 border-b border-slate-100 last:border-b-0 transition-colors duration-200"
                                on:click={() => selectEmployeeForDayOff(employee.id)}
                            >
                                <div class="flex items-center justify-between">
                                    <div>
                                        <p class="font-semibold text-slate-900">{employee.employee_name_en}</p>
                                        <p class="text-xs text-slate-500">{employee.id} • {employee.branch_name_en}</p>
                                        {#if employee.employee_name_ar}
                                            <p class="text-xs text-slate-600 mt-1">{employee.employee_name_ar}</p>
                                        {/if}
                                    </div>
                                    <div class="text-emerald-600 font-bold">→</div>
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
                    Cancel
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
                <h3 class="text-lg font-bold">Select Employee</h3>
                <p class="text-emerald-100 text-sm mt-1">Choose an employee to assign a recurring day off</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Search Input -->
                <div>
                    <label for="dayoff-weekday-employee-search-input" class="block text-sm font-bold text-slate-700 mb-2">Search Employee</label>
                    <input 
                        id="dayoff-weekday-employee-search-input"
                        type="text" 
                        placeholder="Search by name, ID, or branch..."
                        bind:value={employeeSearchQuery}
                        on:input={onEmployeeSearchChange}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500"
                    />
                </div>

                <!-- Employee List -->
                <div class="border border-slate-200 rounded-lg max-h-96 overflow-y-auto">
                    {#if employeesForDateWiseSelection.length === 0}
                        <div class="px-4 py-6 text-center text-slate-500 text-sm">
                            No employees found
                        </div>
                    {:else}
                        {#each employeesForDateWiseSelection as employee}
                            <button 
                                class="w-full text-left px-4 py-3 hover:bg-emerald-50 border-b border-slate-100 last:border-b-0 transition-colors duration-200"
                                on:click={() => selectEmployeeForDayOffWeekday(employee.id)}
                            >
                                <div class="flex items-center justify-between">
                                    <div>
                                        <p class="font-semibold text-slate-900">{employee.employee_name_en}</p>
                                        <p class="text-xs text-slate-500">{employee.id} • {employee.branch_name_en}</p>
                                        {#if employee.employee_name_ar}
                                            <p class="text-xs text-slate-600 mt-1">{employee.employee_name_ar}</p>
                                        {/if}
                                    </div>
                                    <div class="text-emerald-600 font-bold">→</div>
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
                    Cancel
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
                <h3 class="text-lg font-bold">Delete Shift</h3>
                <p class="text-orange-100 text-sm mt-1">Select which day to delete</p>
            </div>

            <!-- Modal Body -->
            <div class="px-6 py-4 space-y-4">
                <!-- Weekday Selector -->
                <div>
                    <label for="delete-weekday-select" class="block text-sm font-bold text-slate-700 mb-2">Select Weekday to Delete</label>
                    <select 
                        id="delete-weekday-select"
                        bind:value={selectedDeleteWeekday}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-orange-500"
                    >
                        {#each weekdayNames as day, index}
                            {#if employees.find(e => e.id === selectedEmployeeId)?.shifts?.[index]}
                                <option value={index}>{day}</option>
                            {/if}
                        {/each}
                    </select>
                </div>

                <p class="text-sm text-red-600 font-semibold">
                    ⚠️ This action cannot be undone.
                </p>
            </div>

            <!-- Modal Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button 
                    class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
                    on:click={closeDeleteModal}
                    disabled={isSaving}
                >
                    Cancel
                </button>
                <button 
                    class="px-6 py-2 rounded-lg font-black text-white bg-red-600 hover:bg-red-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
                    on:click={confirmDelete}
                    disabled={isSaving}
                >
                    {isSaving ? 'Deleting...' : 'Delete'}
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
</style>
