<script lang="ts">
    import { t } from '$lib/i18n';
    
    export let violation: any;
    export let employees: any[] = [];
    
    let selectedEmployee = '';
    let selectedEmployeeDetails: any = null;
    let isSaving = false;
    let loadingEmployee = false;

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

    async function handleIssueWarning() {
        if (!selectedEmployee || !violation) return;
        
        isSaving = true;
        try {
            // TODO: Add your logic here to save the warning
            console.log('Issuing warning for employee:', selectedEmployee, 'violation:', violation.id);
            // After saving, close the window
        } catch (err) {
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }
</script>

<div class="h-full flex flex-col bg-gradient-to-br from-yellow-50 to-slate-50 font-sans">
    <div class="p-8 space-y-6 overflow-y-auto flex-1">
        {#if violation}
            <div class="bg-yellow-50 border-2 border-yellow-200 rounded-lg p-6">
                <p class="text-sm font-bold text-yellow-700 uppercase mb-3 tracking-wide">Selected Violation</p>
                <div class="space-y-3">
                    <div>
                        <p class="text-xs text-slate-500 uppercase tracking-wide mb-1">English</p>
                        <p class="text-lg font-semibold text-slate-900">{violation.name_en}</p>
                    </div>
                    <div>
                        <p class="text-xs text-slate-500 uppercase tracking-wide mb-1">العربية</p>
                        <p class="text-lg font-semibold text-slate-900" dir="rtl">{violation.name_ar}</p>
                    </div>
                    <div class="pt-3 border-t border-yellow-200">
                        <p class="text-xs text-slate-500">
                            <span class="font-semibold">Category:</span> {violation.main?.name_en} / {violation.sub?.name_en}
                        </p>
                    </div>
                </div>
            </div>
        {/if}

        <div class="space-y-3">
            <label for="warning-employee" class="block text-sm font-bold text-slate-700 uppercase tracking-wide">Select Employee</label>
            <select id="warning-employee" bind:value={selectedEmployee} class="w-full px-4 py-3 border-2 border-slate-200 rounded-lg focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 outline-none text-base hover:border-slate-300 transition">
                <option value="">Choose an employee...</option>
                {#each employees as emp}
                    <option value={emp.id}>{emp.name_en} {emp.name_ar ? `/ ${emp.name_ar}` : ''}</option>
                {/each}
            </select>
        </div>

        {#if selectedEmployee}
            {#if loadingEmployee}
                <div class="bg-slate-100 border-2 border-slate-300 rounded-lg p-6 text-center">
                    <div class="animate-spin inline-block mb-3">
                        <div class="w-6 h-6 border-2 border-yellow-200 border-t-yellow-600 rounded-full"></div>
                    </div>
                    <p class="text-sm text-slate-600 font-semibold">Loading employee details...</p>
                </div>
            {:else if selectedEmployeeDetails}
                <div class="bg-green-50 border-2 border-green-200 rounded-lg p-6">
                    <p class="text-sm font-bold text-green-700 uppercase mb-4 tracking-wide">Employee Details</p>
                    <div class="space-y-3">
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <p class="text-xs text-slate-500 uppercase tracking-wide mb-1">Name (English)</p>
                                <p class="text-sm font-semibold text-slate-900">{selectedEmployeeDetails.name_en}</p>
                            </div>
                            <div>
                                <p class="text-xs text-slate-500 uppercase tracking-wide mb-1">Name (Arabic)</p>
                                <p class="text-sm font-semibold text-slate-900" dir="rtl">{selectedEmployeeDetails.name_ar || 'N/A'}</p>
                            </div>
                        </div>
                        <div class="grid grid-cols-2 gap-4 pt-3 border-t border-green-200">
                            <div>
                                <p class="text-xs text-slate-500 uppercase tracking-wide mb-1">Resident/National ID</p>
                                <p class="text-lg font-bold text-green-700">{selectedEmployeeDetails.id_number || 'Not provided'}</p>
                            </div>
                            <div>
                                <p class="text-xs text-slate-500 uppercase tracking-wide mb-1">ID Expiry Date</p>
                                <p class="text-sm font-semibold text-slate-900">{selectedEmployeeDetails.id_expiry_date ? new Date(selectedEmployeeDetails.id_expiry_date).toLocaleDateString() : 'N/A'}</p>
                            </div>
                        </div>
                    </div>
                </div>
            {/if}
        {/if}
    </div>

    <div class="px-8 py-5 bg-white border-t-2 border-slate-200 flex gap-4 justify-end flex-shrink-0 shadow-lg">
        <button disabled={!selectedEmployee || isSaving} class="px-8 py-2.5 rounded-lg font-bold text-white bg-yellow-600 hover:bg-yellow-700 disabled:opacity-50 disabled:cursor-not-allowed transition transform hover:scale-105 active:scale-95">
            {isSaving ? 'Saving...' : 'Issue Warning'}
        </button>
    </div>
</div>

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
</style>
