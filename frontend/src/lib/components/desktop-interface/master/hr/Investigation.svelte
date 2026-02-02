<script lang="ts">
    import { t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { onMount } from 'svelte';
    
    export let violation: any;
    export let employees: any[] = [];
    export let employeeId: string | null = null;
    export let branchId: string | null = null;
    export let branchName: string | null = null;
    export let incident: any = null;
    export let viewMode: boolean = false;
    
    let incidentDescription = '';
    let witnessDetails = '';
    let selectedEmployee = employeeId || '';
    let selectedBranch = branchId || '';
    let employeeSearchQuery = '';
    let showEmployeeDropdown = false;
    let selectedEmployeeDetails: any = null;
    let isSaving = false;
    let loadingEmployee = false;
    let investigationReport = '';
    let branches: any[] = [];
    let isTransforming = false;
    let selectedLanguage = 'en';
    
    const availableLanguages = [
        { code: 'ar', name: 'Arabic', nameAr: 'العربية' },
        { code: 'en', name: 'English', nameAr: 'الإنجليزية' },
        { code: 'ml', name: 'Malayalam', nameAr: 'الملايالامية' },
        { code: 'bn', name: 'Bengali', nameAr: 'البنغالية' },
        { code: 'hi', name: 'Hindi', nameAr: 'الهندية' },
        { code: 'ur', name: 'Urdu', nameAr: 'الأردية' },
        { code: 'ta', name: 'Tamil', nameAr: 'التاميلية' }
    ];

    async function transformReport() {
        if (!investigationReport.trim()) {
            alert($locale === 'ar' ? 'يرجى إدخال تقرير التحقيق أولاً' : 'Please enter investigation report first');
            return;
        }

        isTransforming = true;
        try {
            const response = await fetch('/api/transform-text', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    text: investigationReport,
                    language: selectedLanguage,
                    type: 'investigation'
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to transform text');
            }

            const data = await response.json();
            investigationReport = data.transformedText || investigationReport;
            
        } catch (err) {
            console.error('Error transforming text:', err);
            alert($locale === 'ar' 
                ? `خطأ في تحويل النص: ${err instanceof Error ? err.message : 'فشل التحويل'}` 
                : `Error transforming text: ${err instanceof Error ? err.message : 'Transform failed'}`);
        } finally {
            isTransforming = false;
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

    function getBranchDisplayName(): string {
        if (!selectedBranch) return '';
        const branch = branches.find(b => b.id == selectedBranch);
        if (!branch) return '';
        const name = $locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en;
        const location = $locale === 'ar' ? (branch.location_ar || branch.location_en) : branch.location_en;
        return `${name} - ${location}`;
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
        // Load existing investigation report if any
        if (incident.investigation_report) {
            const report = incident.investigation_report;
            investigationReport = typeof report === 'string' 
                ? report 
                : report.content || '';
        }
    }

    onMount(async () => {
        await loadBranches();
    });

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

    async function handleSaveInvestigation() {
        if (!investigationReport.trim()) {
            alert($locale === 'ar' ? 'الرجاء إدخال تقرير التحقيق' : 'Please enter investigation report');
            return;
        }
        
        if (!incident?.id) {
            alert($locale === 'ar' ? 'خطأ: لا توجد حادثة محددة' : 'Error: No incident selected');
            return;
        }
        
        isSaving = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            const investigationData = {
                content: investigationReport,
                investigated_by: $currentUser?.id,
                investigated_by_name: ($currentUser as any)?.name || $currentUser?.email,
                investigated_at: new Date().toISOString(),
                employee_id: selectedEmployee,
                employee_name: selectedEmployeeDetails?.name_en || '',
                employee_name_ar: selectedEmployeeDetails?.name_ar || ''
            };
            
            const { error } = await supabase
                .from('incidents')
                .update({ investigation_report: investigationData })
                .eq('id', incident.id);
            
            if (error) throw error;
            
            alert($locale === 'ar' ? '✅ تم حفظ التحقيق بنجاح' : '✅ Investigation saved successfully');
        } catch (err) {
            console.error('Error saving investigation:', err);
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }
</script>

<div class="h-full flex flex-col bg-gradient-to-br from-indigo-50 to-slate-50 font-sans">
    <div class="p-6 space-y-4 overflow-y-auto flex-1">
        <!-- Language Selection for Transform -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'اختر لغة التحويل' : 'Select Transform Language'}</label>
            <div class="flex flex-wrap gap-2">
                {#each availableLanguages as lang}
                    <button
                        type="button"
                        on:click={() => selectedLanguage = lang.code}
                        class="px-3 py-1.5 text-xs font-semibold rounded-lg transition border-2 {selectedLanguage === lang.code ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-slate-700 border-slate-200 hover:border-indigo-400'}"
                    >
                        {$locale === 'ar' ? lang.nameAr : lang.name}
                    </button>
                {/each}
            </div>
        </div>

        <!-- Violation & Employee Selection -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'المخالفة واختيار الموظف' : 'Violation & Select Employee'}</label>
            <div class="flex items-center gap-3">
                {#if violation}
                    <div class="bg-indigo-50 border border-indigo-200 rounded px-3 py-1.5 flex items-center gap-2 flex-shrink-0">
                        <div class="w-1 h-6 bg-indigo-500 rounded-full"></div>
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
                            class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none text-sm hover:border-slate-300 transition pr-8"
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
                                        class="w-full px-3 py-2 text-left text-sm hover:bg-indigo-50 border-b border-slate-100 last:border-b-0 transition"
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
                    <div class="bg-indigo-50 border border-indigo-200 rounded px-3 py-1.5 flex items-center gap-3">
                        <div class="w-1 h-6 bg-indigo-500 rounded-full flex-shrink-0"></div>
                        <span class="text-xs font-bold text-indigo-600">{selectedEmployeeDetails.id || '-'}</span>
                        <span class="text-slate-400">|</span>
                        <span class="text-sm font-medium text-slate-900">{$locale === 'ar' ? (selectedEmployeeDetails.name_ar || selectedEmployeeDetails.name_en) : selectedEmployeeDetails.name_en}</span>
                        <span class="text-slate-400">|</span>
                        <span class="text-sm font-bold text-indigo-700">{selectedEmployeeDetails.id_number || ($locale === 'ar' ? 'لا يوجد' : 'No ID')}</span>
                    </div>
                </div>
            {/if}
        {/if}

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

        <!-- Branch -->
        <div>
            <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'الفرع *' : 'Select Branch *'}</label>
            <select 
                bind:value={selectedBranch}
                class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none text-sm hover:border-slate-300 transition bg-white"
            >
                <option value="">{$locale === 'ar' ? 'اختر الفرع...' : 'Select branch...'}</option>
                {#each branches as branch}
                    <option value={branch.id}>
                        {$locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en} - {$locale === 'ar' ? (branch.location_ar || branch.location_en) : branch.location_en}
                    </option>
                {/each}
            </select>
        </div>

        <!-- Investigation Report -->
        <div>
            <label for="investigation-report" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'تقرير التحقيق *' : 'Investigation Report *'}</label>
            <textarea 
                id="investigation-report"
                bind:value={investigationReport}
                placeholder={$locale === 'ar' ? 'أدخل تقرير التحقيق...' : 'Enter investigation report...'}
                rows={Math.max(8, investigationReport.split('\n').length + 2)}
                readonly={viewMode}
                class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none text-sm hover:border-slate-300 transition resize-y min-h-[200px] max-h-[500px] {viewMode ? 'bg-slate-50 cursor-default' : ''}"
            ></textarea>
        </div>

        <!-- Action Buttons -->
        <div class="flex justify-end gap-3 pt-4 border-t border-slate-200">
            <button 
                type="button"
                on:click={transformReport}
                disabled={isTransforming || !investigationReport.trim()}
                class="px-4 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed font-semibold text-sm flex items-center gap-2"
            >
                {#if isTransforming}
                    <span class="animate-spin">⏳</span>
                    {$locale === 'ar' ? 'جاري التحويل...' : 'Transforming...'}
                {:else}
                    <span>✨</span>
                    {$locale === 'ar' ? 'تحويل النص' : 'Transform'}
                {/if}
            </button>
            {#if !viewMode}
                <button 
                    type="button"
                    on:click={handleSaveInvestigation}
                    disabled={isSaving || !investigationReport.trim()}
                    class="px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed font-semibold text-sm flex items-center gap-2"
                >
                    {#if isSaving}
                        <span class="animate-spin">⏳</span>
                        {$locale === 'ar' ? 'جاري الحفظ...' : 'Saving...'}
                    {:else}
                        <span>💾</span>
                        {$locale === 'ar' ? 'حفظ التحقيق' : 'Save Investigation'}
                    {/if}
                </button>
            {/if}
        </div>
    </div>
</div>
