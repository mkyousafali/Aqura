<script lang="ts">
    import { t, locale } from '$lib/i18n';
    
    export let violation: any;
    export let employees: any[] = [];
    export let branches: any[] = [];
    
    let selectedEmployee = '';
    let selectedEmployeeDetails: any = null;
    let selectedBranch = '';
    let isSaving = false;
    let loadingEmployee = false;
    let employeeSearchQuery = '';
    let showEmployeeDropdown = false;
    let whatHappened = '';
    let proofWitness = '';

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

    async function handleReportIncident() {
        if (!selectedEmployee || !violation) return;
        
        isSaving = true;
        try {
            // TODO: Add your logic here to save the incident report
            console.log('Reporting incident for employee:', selectedEmployee, 'violation:', violation.id);
            // After saving, close the window
        } catch (err) {
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }
</script>

<div class="h-full flex flex-col bg-gradient-to-br from-blue-50 to-slate-50 font-sans">
    <div class="p-6 space-y-4 overflow-y-auto flex-1">
        <!-- Violation & Employee Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'المخالفة واختيار الموظف' : 'Violation & Select Employee'}</label>
            <div class="flex items-center gap-3">
                {#if violation}
                    <div class="bg-blue-50 border border-blue-200 rounded px-3 py-1.5 flex items-center gap-2 flex-shrink-0">
                        <div class="w-1 h-6 bg-blue-500 rounded-full"></div>
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
                            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition pr-8"
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
                                        class="w-full px-3 py-2 text-left text-sm hover:bg-blue-50 border-b border-slate-100 last:border-b-0 transition"
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
                    <div class="bg-green-50 border border-green-200 rounded px-3 py-1.5 flex items-center gap-3">
                        <div class="w-1 h-6 bg-green-500 rounded-full flex-shrink-0"></div>
                        <span class="text-xs font-bold text-green-600">{selectedEmployeeDetails.id || '-'}</span>
                        <span class="text-slate-400">|</span>
                        <span class="text-sm font-medium text-slate-900">{$locale === 'ar' ? (selectedEmployeeDetails.name_ar || selectedEmployeeDetails.name_en) : selectedEmployeeDetails.name_en}</span>
                        <span class="text-slate-400">|</span>
                        <span class="text-sm font-bold text-green-700">{selectedEmployeeDetails.id_number || ($locale === 'ar' ? 'لا يوجد' : 'No ID')}</span>
                    </div>
                </div>

                <!-- Branch Selection -->
                <div>
                    <label for="branch-select" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'اختيار الفرع' : 'Select Branch'}</label>
                    <select 
                        id="branch-select"
                        bind:value={selectedBranch}
                        class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm hover:border-slate-300 transition"
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
                </div>

                <div class="space-y-3">
                    <div>
                        <label for="what-happened" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1">{$locale === 'ar' ? 'ماذا حدث؟' : 'What Happened?'}</label>
                        <textarea 
                            id="what-happened"
                            bind:value={whatHappened}
                            placeholder={$locale === 'ar' ? 'صف ما حدث...' : 'Describe what happened...'}
                            rows="3"
                            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm resize-none"
                        ></textarea>
                    </div>
                    <div>
                        <label for="proof-witness" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1">{$locale === 'ar' ? 'الإثبات / الشاهد' : 'Proof / Witness'}</label>
                        <textarea 
                            id="proof-witness"
                            bind:value={proofWitness}
                            placeholder={$locale === 'ar' ? 'أدخل تفاصيل الإثبات أو الشاهد...' : 'Enter proof or witness details...'}
                            rows="2"
                            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none text-sm resize-none"
                        ></textarea>
                    </div>
                </div>
            {/if}
        {/if}
    </div>

    <div class="px-8 py-5 bg-white border-t-2 border-slate-200 flex gap-4 justify-end flex-shrink-0 shadow-lg">
        <button disabled={!selectedEmployee || isSaving} class="px-8 py-2.5 rounded-lg font-bold text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition transform hover:scale-105 active:scale-95">
            {isSaving ? ($locale === 'ar' ? 'جاري الحفظ...' : 'Saving...') : ($locale === 'ar' ? 'الإبلاغ عن الحادثة' : 'Report Incident')}
        </button>
    </div>
</div>

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>
