<script lang="ts">
    import { t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    
    export let violation: any;
    export let employees: any[] = [];
    export let employeeId: string | null = null;
    export let branchId: string | null = null;
    export let branchName: string | null = null;
    export let incident: any = null;
    
    let incidentDescription = '';
    let witnessDetails = '';
    let selectedEmployee = employeeId || '';
    let selectedBranch = branchId || '';
    let employeeSearchQuery = '';
    let showEmployeeDropdown = false;
    let selectedEmployeeDetails: any = null;
    let isSaving = false;
    let loadingEmployee = false;
    let warningNotes = '';
    let branches: any[] = [];
    let selectedLanguages: string[] = [];
    let selectedRecourse = '';
    let fineAmount = '';
    
    const availableLanguages = [
        { code: 'ar', name: 'Arabic', nameAr: 'العربية' },
        { code: 'en', name: 'English', nameAr: 'الإنجليزية' },
        { code: 'ml', name: 'Malayalam', nameAr: 'الملايالامية' },
        { code: 'bn', name: 'Bengali', nameAr: 'البنغالية' },
        { code: 'hi', name: 'Hindi', nameAr: 'الهندية' },
        { code: 'ur', name: 'Urdu', nameAr: 'الأردية' },
        { code: 'ta', name: 'Tamil', nameAr: 'التاميلية' }
    ];

    const recourseOptions = [
        { id: 'warning', label: 'Just Warning', labelAr: 'تحذير فقط' },
        { id: 'warning_fine', label: 'Warning with Fine', labelAr: 'تحذير مع غرامة' },
        { id: 'warning_fine_threat', label: 'Warning with Fine Threat', labelAr: 'تحذير مع غرامة وتهديد' }
    ];

    function toggleLanguage(langCode: string) {
        if (selectedLanguages.includes(langCode)) {
            selectedLanguages = selectedLanguages.filter(l => l !== langCode);
        } else {
            selectedLanguages = [...selectedLanguages, langCode];
        }
    }

    async function loadBranches() {
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { data, error } = await supabase
                .from('branches')
                .select('id, name_en, name_ar, location_en, location_ar')
                .eq('is_active', true)
                .order('name_en');
            
            if (error) throw error;
            branches = data || [];
        } catch (err) {
            console.error('Error loading branches:', err);
            branches = [];
        }
    }

    // Auto-populate incident details
    $: if (incident) {
        if (incident.what_happened) {
            const whatHappened = incident.what_happened;
            incidentDescription = typeof whatHappened === 'string' 
                ? whatHappened 
                : whatHappened.description || '';
        }
        if (incident.witness_details) {
            const witnesses = incident.witness_details;
            witnessDetails = typeof witnesses === 'string' 
                ? witnesses 
                : witnesses.details || '';
        }
    }

    onMount(async () => {
        await loadBranches();
    });

    import { onMount } from 'svelte';

    $: filteredEmployees = employees.filter(emp => {
        if (!employeeSearchQuery.trim()) return true;
        const query = employeeSearchQuery.toLowerCase();
        return (emp.name_en?.toLowerCase().includes(query) || 
                emp.name_ar?.toLowerCase().includes(query) ||
                emp.id?.toLowerCase().includes(query) ||
                emp.employee_id?.toLowerCase().includes(query));
    });

    function selectEmployee(emp: any) {
        selectedEmployee = emp.id;
        employeeSearchQuery = `${emp.name_en}${emp.name_ar ? ' / ' + emp.name_ar : ''}`;
        showEmployeeDropdown = false;
    }

    function clearEmployee() {
        selectedEmployee = '';
        employeeSearchQuery = '';
        selectedEmployeeDetails = null;
    }

    async function loadEmployeeDetails() {
        if (!selectedEmployee) {
            selectedEmployeeDetails = null;
            return;
        }

        loadingEmployee = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { data, error } = await supabase
                .from('hr_employee_master')
                .select('id, name_en, name_ar, id_number, id_expiry_date')
                .eq('id', selectedEmployee)
                .single();
            
            if (error) throw error;
            selectedEmployeeDetails = data;
            
            // Update search query to show selected employee name
            if (data && !employeeSearchQuery) {
                employeeSearchQuery = `${data.name_en}${data.name_ar ? ' / ' + data.name_ar : ''}`;
            }
        } catch (err) {
            console.error('Error loading employee details:', err);
            selectedEmployeeDetails = null;
        } finally {
            loadingEmployee = false;
        }
    }

    $: if (selectedEmployee) {
        loadEmployeeDetails();
    }

    async function handleIssueWarning() {
        // Validate required fields
        const needsFineAmount = selectedRecourse === 'warning_fine' || selectedRecourse === 'warning_fine_threat';
        
        if (!selectedLanguages.length || !selectedRecourse || !selectedEmployee || !selectedBranch || !violation || !warningNotes.trim()) {
            alert($locale === 'ar' ? 'الرجاء ملء جميع الحقول المطلوبة' : 'Please fill all required fields');
            return;
        }
        
        if (needsFineAmount && !fineAmount) {
            alert($locale === 'ar' ? 'الرجاء إدخال مبلغ الغرامة' : 'Please enter fine amount');
            return;
        }
        
        isSaving = true;
        try {
            // TODO: Save warning logic - will be implemented later
            console.log('Issuing warning:', {
                employee: selectedEmployee,
                branch: selectedBranch,
                violation: violation.id,
                languages: selectedLanguages,
                recourse: selectedRecourse,
                fineAmount: needsFineAmount ? fineAmount : null,
                reportAndAction: warningNotes
            });
            
            // Clear form
            selectedEmployee = '';
            selectedEmployeeDetails = null;
            selectedBranch = '';
            employeeSearchQuery = '';
            warningNotes = '';
            selectedLanguages = [];
            selectedRecourse = '';
            fineAmount = '';
            
            alert($locale === 'ar' ? '✅ تم إصدار التحذير بنجاح' : '✅ Warning issued successfully');
        } catch (err) {
            console.error('Error issuing warning:', err);
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }
</script>

<div class="h-full flex flex-col bg-gradient-to-br from-orange-50 to-slate-50 font-sans">
    <div class="p-6 space-y-4 overflow-y-auto flex-1">
        <!-- Language Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'اختر اللغات' : 'Select Languages'}</label>
            <div class="flex flex-wrap gap-2">
                {#each availableLanguages as lang}
                    <button
                        type="button"
                        on:click={() => toggleLanguage(lang.code)}
                        class="px-3 py-1.5 text-xs font-semibold rounded-lg transition border-2 {selectedLanguages.includes(lang.code) ? 'bg-orange-600 text-white border-orange-600' : 'bg-white text-slate-700 border-slate-200 hover:border-orange-400'}"
                    >
                        {$locale === 'ar' ? lang.nameAr : lang.name}
                    </button>
                {/each}
            </div>
            {#if selectedLanguages.length === 0}
                <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'يجب تحديد لغة واحدة على الأقل' : 'Select at least one language'}</p>
            {/if}
        </div>

        <!-- Recourse Type Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'نوع الإجراء *' : 'Recourse Type *'}</label>
            <div class="flex flex-wrap gap-2">
                {#each recourseOptions as option}
                    <button
                        type="button"
                        on:click={() => { selectedRecourse = option.id; fineAmount = ''; }}
                        class="px-3 py-1.5 text-xs font-semibold rounded-lg transition border-2 {selectedRecourse === option.id ? 'bg-orange-600 text-white border-orange-600' : 'bg-white text-slate-700 border-slate-200 hover:border-orange-400'}"
                    >
                        {$locale === 'ar' ? option.labelAr : option.label}
                    </button>
                {/each}
            </div>
            {#if !selectedRecourse}
                <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'يجب تحديد نوع الإجراء' : 'Select a recourse type'}</p>
            {/if}
        </div>

        <!-- Fine Amount (if applicable) -->
        {#if selectedRecourse === 'warning_fine' || selectedRecourse === 'warning_fine_threat'}
            <div>
                <label for="fine-amount" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'مبلغ الغرامة *' : 'Fine Amount *'}</label>
                <input 
                    id="fine-amount"
                    type="number"
                    bind:value={fineAmount}
                    placeholder={$locale === 'ar' ? 'أدخل مبلغ الغرامة...' : 'Enter fine amount...'}
                    min="0"
                    step="0.01"
                    class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition"
                />
                {#if !fineAmount}
                    <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                {/if}
            </div>
        {/if}

        <!-- Violation & Employee Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'المخالفة واختيار الموظف' : 'Violation & Select Employee'}</label>
            <div class="flex items-center gap-3">
                {#if violation}
                    <div class="bg-orange-50 border border-orange-200 rounded px-3 py-1.5 flex items-center gap-2 flex-shrink-0">
                        <div class="w-1 h-6 bg-orange-500 rounded-full"></div>
                        <div class="text-xs">
                            <span class="font-medium text-slate-900">{$locale === 'ar' ? violation.name_ar : violation.name_en}</span>
                        </div>
                    </div>
                {/if}
                <div class="flex-1 relative">
                    <div class="relative">
                        <input 
                            type="text" 
                            bind:value={employeeSearchQuery}
                            on:focus={() => showEmployeeDropdown = true}
                            placeholder={$locale === 'ar' ? 'بحث موظف...' : 'Search employee...'}
                            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition pr-8"
                        />
                        {#if selectedEmployee}
                            <button 
                                type="button"
                                on:click={clearEmployee}
                                class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 text-lg"
                            >×</button>
                        {:else}
                            <span class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 text-sm">🔍</span>
                        {/if}
                    </div>
                    {#if showEmployeeDropdown && !selectedEmployee}
                        <div class="absolute z-50 top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                            {#if filteredEmployees.length === 0}
                                <div class="px-3 py-2 text-sm text-slate-500">{$locale === 'ar' ? 'لم يتم العثور على موظفين' : 'No employees found'}</div>
                            {:else}
                                {#each filteredEmployees.slice(0, 10) as emp}
                                    <button 
                                        type="button"
                                        on:click={() => selectEmployee(emp)}
                                        class="w-full px-3 py-2 text-left text-sm hover:bg-orange-50 border-b border-slate-100 last:border-b-0 transition"
                                    >
                                        <span class="font-medium text-slate-900">{$locale === 'ar' ? (emp.name_ar || emp.name_en) : emp.name_en}</span>
                                    </button>
                                {/each}
                            {/if}
                        </div>
                    {/if}
                </div>
            </div>
        </div>

        {#if selectedEmployee}
            {#if loadingEmployee}
                <div class="bg-slate-100 border border-slate-200 rounded px-3 py-1.5 flex items-center gap-2">
                    <div class="animate-spin w-4 h-4 border-2 border-slate-300 border-t-slate-600 rounded-full"></div>
                    <span class="text-xs text-slate-500">{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</span>
                </div>
            {:else if selectedEmployeeDetails}
                <!-- Employee Details -->
                <div>
                    <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'تفاصيل الموظف' : 'Employee Details'}</label>
                    <div class="bg-orange-50 border border-orange-200 rounded px-3 py-1.5 flex items-center gap-3">
                        <div class="w-1 h-6 bg-orange-500 rounded-full flex-shrink-0"></div>
                        <span class="text-xs font-bold text-orange-600">{selectedEmployeeDetails.id || '-'}</span>
                        <span class="text-slate-400">|</span>
                        <span class="text-sm font-medium text-slate-900">{$locale === 'ar' ? (selectedEmployeeDetails.name_ar || selectedEmployeeDetails.name_en) : selectedEmployeeDetails.name_en}</span>
                        <span class="text-slate-400">|</span>
                        <span class="text-sm font-bold text-orange-700">{selectedEmployeeDetails.id_number || ($locale === 'ar' ? 'لا يوجد' : 'No ID')}</span>
                    </div>
                </div>

                <!-- Incident: What Happened -->
                {#if incidentDescription}
                    <div>
                        <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'ماذا حدث (من التقرير)' : 'What Happened (from Report)'}</label>
                        <div class="bg-blue-50 border border-blue-200 rounded px-3 py-2 text-sm text-slate-700">
                            {incidentDescription}
                        </div>
                    </div>
                {/if}

                <!-- Incident: Witness Details -->
                {#if witnessDetails}
                    <div>
                        <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'تفاصيل الشهود (من التقرير)' : 'Witness Details (from Report)'}</label>
                        <div class="bg-blue-50 border border-blue-200 rounded px-3 py-2 text-sm text-slate-700">
                            {witnessDetails}
                        </div>
                    </div>
                {/if}

                <!-- Branch Selection -->
                <div>
                    <label for="branch-select" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'اختيار الفرع *' : 'Select Branch *'}</label>
                    <select 
                        id="branch-select"
                        bind:value={selectedBranch}
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition"
                    >
                        <option value="">{$locale === 'ar' ? 'اختر الفرع...' : 'Select Branch...'}</option>
                        {#each branches as branch}
                            <option value={branch.id}>
                                {$locale === 'ar' 
                                    ? `${branch.name_ar || branch.name_en} - ${branch.location_ar || branch.location_en}` 
                                    : `${branch.name_en} - ${branch.location_en}`}
                            </option>
                        {/each}
                    </select>
                    {#if !selectedBranch}
                        <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                    {/if}
                </div>

                <!-- Report and Action -->
                <div>
                    <label for="warning-notes" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'التقرير والإجراء *' : 'Report and Action *'}</label>
                    <textarea 
                        id="warning-notes"
                        bind:value={warningNotes}
                        placeholder={$locale === 'ar' ? 'أدخل التقرير والإجراء المطلوب...' : 'Enter report and action required...'}
                        rows="4"
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-sm hover:border-slate-300 transition resize-none"
                    ></textarea>
                    {#if !warningNotes.trim()}
                        <p class="text-xs text-red-600 mt-1">{$locale === 'ar' ? 'هذا الحقل مطلوب' : 'This field is required'}</p>
                    {/if}
                    <button
                        type="button"
                        class="mt-2 px-4 py-1.5 text-xs font-semibold rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition"
                    >
                        {$locale === 'ar' ? 'إنشاء' : 'Generate'}
                    </button>
                </div>
            {/if}
        {/if}
    </div>

    <div class="px-6 py-4 bg-white border-t border-slate-200 flex gap-3 justify-end flex-shrink-0 shadow-lg">
        <!-- Buttons will be added here later -->
    </div>
</div>

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>
