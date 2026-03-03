<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    
    let activeTab = 'Documents Expiry';
    let loading = false;
    let documentsExpiryData: any[] = [];
    let searchTerm = '';
    let selectedBranch = '';
    let selectedNationality = '';
    let supabase: any = null;
    let showColumnDropdown = false;
    
    // Column visibility state
    let columnVisibility = {
        id: true,
        name: true,
        nationality: true,
        branch: true,
        doc_id: true,
        doc_health_card: true,
        doc_driving_licence: true,
        doc_contract: true,
        doc_work_permit: true,
        doc_insurance: true,
        doc_health_educational: true
    };
    
    // Modal state for editing dates
    let showDateModal = false;
    let modalEmployeeId = '';
    let modalEmployeeName = '';
    let modalDocumentType = '';
    let modalDocumentKey = '';
    let modalCurrentDate = '';
    let modalNewDate = '';
    let isSaving = false;
    
    $: uniqueBranches = [
        ...new Map(
            documentsExpiryData.map(emp => [
                emp.current_branch_id,
                { id: emp.current_branch_id, name_en: emp.branch_name_en, name_ar: emp.branch_name_ar }
            ])
        ).values()
    ].sort((a, b) => a.name_en.localeCompare(b.name_en));

    $: uniqueNationalities = [
        ...new Map(
            documentsExpiryData.map(emp => [
                emp.nationality_id,
                { id: emp.nationality_id, name_en: emp.nationality_name_en, name_ar: emp.nationality_name_ar }
            ])
        ).values()
    ].sort((a, b) => a.name_en.localeCompare(b.name_en));

    $: filteredData = documentsExpiryData.filter(emp => {
        const matchesSearch = !searchTerm || (
            emp.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
            emp.name_en.toLowerCase().includes(searchTerm.toLowerCase()) ||
            emp.name_ar.includes(searchTerm)
        );
        const matchesBranch = !selectedBranch || emp.current_branch_id === parseInt(selectedBranch);
        const matchesNationality = !selectedNationality || emp.nationality_id === selectedNationality;
        return matchesSearch && matchesBranch && matchesNationality;
    });

    function getMostUrgentDaysRemaining(emp: any): number {
        let mostUrgent = 999999;
        
        // Check all documents to find the most overdue/expiring soon
        if (emp.documents && typeof emp.documents === 'object') {
            for (const docKey in emp.documents) {
                const doc = emp.documents[docKey];
                if (doc && typeof doc === 'object') {
                    const daysRemaining = doc.daysRemaining;
                    // Exclude -999 (no expiry date set) and check for valid numbers
                    if (daysRemaining !== undefined && daysRemaining !== null && !isNaN(daysRemaining) && daysRemaining !== -999) {
                        const daysNum = Number(daysRemaining);
                        if (daysNum < mostUrgent) {
                            mostUrgent = daysNum;
                        }
                    }
                }
            }
        }
        
        return mostUrgent === 999999 ? 999999 : mostUrgent;
    }

    function getUrgencyScore(emp: any): { score: number; days: number } {
        const mostUrgent = getMostUrgentDaysRemaining(emp);
        const days = Number(mostUrgent);
        
        // Expired documents (negative) get highest priority
        // More negative = more overdue = higher priority (smaller score = comes first)
        if (days < 0) {
            return { score: days, days: days };
        }
        
        // Expiring soon (0-30 days)
        if (days <= 30) {
            return { score: 1000 + days, days: days };
        }
        
        // Warning (31-90 days)
        if (days <= 90) {
            return { score: 2000 + days, days: days };
        }
        
        // Active (>90 days)
        return { score: 3000 + days, days: days };
    }

    $: sortedFilteredData = (() => {
        const sorted = [...filteredData].sort((a, b) => {
            const scoreA = getUrgencyScore(a).score;
            const scoreB = getUrgencyScore(b).score;
            return scoreA - scoreB;
        });
        return sorted;
    })();
    
    interface DocumentExpiry {
        id: string;
        name_en: string;
        name_ar: string;
        nationality_id: string;
        nationality_name_en: string;
        nationality_name_ar: string;
        current_branch_id: number;
        branch_name_en: string;
        branch_name_ar: string;
        branch_location_en: string;
        branch_location_ar: string;
        documents: {
            [key: string]: {
                label: string;
                expiryDate: string | null;
                daysRemaining: number;
                status: string;
            };
        };
    }
    
    const COLUMN_LABELS = [
        { key: 'id', label: 'Employee ID' },
        { key: 'name', label: 'Full Name' },
        { key: 'nationality', label: 'Nationality' },
        { key: 'branch', label: 'Current Branch' },
        { key: 'doc_id', label: 'ID Expiry' },
        { key: 'doc_health_card', label: 'Health Card' },
        { key: 'doc_driving_licence', label: 'Driving Licence' },
        { key: 'doc_contract', label: 'Contract' },
        { key: 'doc_work_permit', label: 'Work Permit' },
        { key: 'doc_insurance', label: 'Insurance' },
        { key: 'doc_health_educational', label: 'Health Educational Renewal' }
    ];
    
    const DOCUMENT_TYPES = [
        { key: 'id_expiry_date', label: 'ID', type: 'id' },
        { key: 'health_card_expiry_date', label: 'Health Card', type: 'health_card' },
        { key: 'driving_licence_expiry_date', label: 'Driving Licence', type: 'driving_licence' },
        { key: 'contract_expiry_date', label: 'Contract', type: 'contract' },
        { key: 'work_permit_expiry_date', label: 'Work Permit', type: 'work_permit' },
        { key: 'insurance_expiry_date', label: 'Insurance', type: 'insurance' },
        { key: 'health_educational_renewal_date', label: 'Health Educational Renewal', type: 'health_educational' },
    ];

    const ACTIVE_EMPLOYMENT_STATUSES = [
        'Job (With Finger)',
        'Job (No Finger)',
        'Remote Job',
        'Vacation'
    ];
    
    $: tabs = [
        { id: 'Documents Expiry', label: $t('hr.dashboard.documents_expiry') || 'Documents Expiry', icon: '📄', color: 'blue' },
        { id: 'Performance', label: $t('hr.dashboard.performance') || 'Performance', icon: '📊', color: 'indigo' }
    ];

    async function initSupabase() {
        if (!supabase) {
            const mod = await import('$lib/utils/supabase');
            supabase = mod.supabase;
        }
    }

    function calculateDaysRemaining(expiryDate: string | null): number {
        if (!expiryDate) return -999;
        const expiry = new Date(expiryDate);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const daysMs = expiry.getTime() - today.getTime();
        return Math.ceil(daysMs / (1000 * 60 * 60 * 24));
    }

    function getStatusDisplay(daysRemaining: number): { color: string; text: string } {
        if (daysRemaining < 0) {
            return { color: 'bg-red-100 text-red-800', text: $t('hr.dashboard.expired') || 'Expired' };
        } else if (daysRemaining <= 30) {
            return { color: 'bg-orange-100 text-orange-800', text: $t('hr.dashboard.expiring_soon') || 'Expiring Soon' };
        } else if (daysRemaining <= 90) {
            return { color: 'bg-yellow-100 text-yellow-800', text: $t('hr.dashboard.warning') || 'Warning' };
        } else {
            return { color: 'bg-green-100 text-green-800', text: $t('common.active') || 'Active' };
        }
    }

    function getNationalityDisplay(name_en: string, name_ar: string): string {
        return $locale === 'ar' ? (name_ar || name_en) : (name_en || name_ar);
    }

    function getEmployeeNameDisplay(name_en: string, name_ar: string): string {
        return $locale === 'ar' ? (name_ar || name_en) : (name_en || name_ar);
    }

    function openDateModal(empId: string, empName: string, docType: string, docKey: string, currentDate: string) {
        modalEmployeeId = empId;
        modalEmployeeName = empName;
        modalDocumentType = docType;
        modalDocumentKey = docKey;
        modalCurrentDate = currentDate || '';
        modalNewDate = currentDate || '';
        showDateModal = true;
    }

    function closeDateModal() {
        showDateModal = false;
        isSaving = false;
    }

    async function saveDateChange() {
        if (!supabase || !modalEmployeeId || !modalDocumentKey) return;
        
        isSaving = true;
        try {
            const updateData: any = {};
            updateData[modalDocumentKey] = modalNewDate || null;
            
            const { error } = await supabase
                .from('hr_employee_master')
                .update(updateData)
                .eq('id', modalEmployeeId);
            
            if (error) throw error;
            
            // Refresh data
            await loadDocumentsExpiryData();
            closeDateModal();
        } catch (err) {
            console.error('Error updating date:', err);
            alert('Failed to update date');
        } finally {
            isSaving = false;
        }
    }

    async function loadDocumentsExpiryData() {
        loading = true;
        try {
            await initSupabase();
            
            let query = supabase
                .from('hr_employee_master')
                .select(`
                    id,
                    name_en,
                    name_ar,
                    nationality_id,
                    current_branch_id,
                    employment_status,
                    id_expiry_date,
                    health_card_expiry_date,
                    driving_licence_expiry_date,
                    contract_expiry_date,
                    work_permit_expiry_date,
                    insurance_expiry_date,
                    health_educational_renewal_date,
                    branches(name_en, name_ar, location_en, location_ar)
                `)
                .in('employment_status', ACTIVE_EMPLOYMENT_STATUSES)
                .order('name_en', { ascending: true });

            const { data: employees, error } = await query;

            if (error) throw error;

            // Get nationalities
            const { data: nationalities } = await supabase
                .from('nationalities')
                .select('id, name_en, name_ar');

            const nationalityMap = new Map();
            if (nationalities) {
                nationalities.forEach((n: any) => {
                    nationalityMap.set(n.id, { name_en: n.name_en, name_ar: n.name_ar });
                });
            }

            // Group by employee
            const groupedData: DocumentExpiry[] = [];
            
            if (employees) {
                employees.forEach((emp: any) => {
                    const nationality = nationalityMap.get(emp.nationality_id) || { name_en: 'N/A', name_ar: 'N/A' };
                    const branch = emp.branches || { name_en: 'N/A', name_ar: 'N/A', location_en: 'N/A', location_ar: 'N/A' };
                    const documents: any = {};
                    
                    // Build documents object for this employee
                    DOCUMENT_TYPES.forEach((docType) => {
                        const expiryDate = emp[docType.key];
                        const daysRemaining = calculateDaysRemaining(expiryDate);
                        const status = getStatusDisplay(daysRemaining);
                        
                        documents[docType.type] = {
                            label: docType.label,
                            expiryDate,
                            daysRemaining,
                            status: status.text
                        };
                    });
                    
                    groupedData.push({
                        id: emp.id,
                        name_en: emp.name_en || 'N/A',
                        name_ar: emp.name_ar || 'N/A',
                        nationality_id: emp.nationality_id || 'N/A',
                        nationality_name_en: nationality.name_en,
                        nationality_name_ar: nationality.name_ar,
                        current_branch_id: emp.current_branch_id,
                        branch_name_en: branch.name_en || 'N/A',
                        branch_name_ar: branch.name_ar || 'N/A',
                        branch_location_en: branch.location_en || 'N/A',
                        branch_location_ar: branch.location_ar || 'N/A',
                        documents
                    });
                });
            }

            documentsExpiryData = groupedData;
        } catch (err) {
            console.error('Error loading documents expiry data:', err);
        } finally {
            loading = false;
        }
    }

    function handleTabChange() {
        if (activeTab === 'Documents Expiry' && documentsExpiryData.length === 0) {
            loadDocumentsExpiryData();
        }
    }

    onMount(() => {
        loadDocumentsExpiryData();
    });
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm">
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button 
                    class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id 
                        ? (tab.color === 'blue' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]' : 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]')
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
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-purple-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col">
            {#if activeTab === 'Documents Expiry'}
                <!-- Documents Expiry Tab Content -->
                <div>
                    <!-- Header with decorative line -->
                    <div class="mb-6 flex items-center gap-4">
                        <div class="absolute inset-0 rounded-full blur-2xl bg-blue-400/30"></div>
                        <h1 class="text-3xl font-black text-slate-800 tracking-tight relative z-10">
                            📄 {$t('hr.dashboard.documents_expiry') || 'Documents Expiry'}
                        </h1>
                        <div class="flex-1 flex gap-3 items-center">
                            <div class="h-[3px] w-16 rounded-full bg-blue-500 shadow-[0_0_10px_rgba(59,130,246,0.5)]"></div>
                            <div class="h-[3px] w-16 rounded-full bg-blue-500 shadow-[0_0_10px_rgba(59,130,246,0.5)]"></div>
                        </div>
                    </div>

                    <!-- Search Bar and Filters (Same Row) -->
                    <div class="mb-4 flex items-center gap-2 flex-wrap">
                        <div class="relative flex-1 max-w-md">
                            <input
                                type="text"
                                placeholder="🔍 Search by Employee ID or Name..."
                                bind:value={searchTerm}
                                class="w-full px-4 py-2.5 rounded-lg border border-blue-200 bg-white/60 backdrop-blur-sm text-sm text-slate-700 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                            />
                            {#if searchTerm}
                                <button
                                    on:click={() => searchTerm = ''}
                                    class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 text-lg"
                                >
                                    ✕
                                </button>
                            {/if}
                        </div>

                        <!-- Branch Filter -->
                        <select
                            bind:value={selectedBranch}
                            class="px-4 py-2.5 rounded-lg border border-blue-200 bg-white/60 backdrop-blur-sm text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all cursor-pointer"
                        >
                            <option value="">All Branches</option>
                            {#each uniqueBranches as branch}
                                <option value={branch.id}>
                                    {$locale === 'ar' ? branch.name_ar : branch.name_en}
                                </option>
                            {/each}
                        </select>

                        <!-- Nationality Filter -->
                        <select
                            bind:value={selectedNationality}
                            class="px-4 py-2.5 rounded-lg border border-blue-200 bg-white/60 backdrop-blur-sm text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all cursor-pointer min-w-56"
                        >
                            <option value="">All Nationalities</option>
                            {#each uniqueNationalities as nationality}
                                <option value={nationality.id}>
                                    {$locale === 'ar' ? nationality.name_ar : nationality.name_en}
                                </option>
                            {/each}
                        </select>

                        <!-- Clear Filters Button -->
                        {#if selectedBranch || selectedNationality}
                            <button
                                on:click={() => {
                                    selectedBranch = '';
                                    selectedNationality = '';
                                }}
                                class="px-3 py-2.5 rounded-lg border border-slate-300 bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors text-sm font-semibold"
                            >
                                Clear
                            </button>
                        {/if}

                        <!-- Column Selector Dropdown -->
                        <div class="relative">
                            <button
                                on:click={() => showColumnDropdown = !showColumnDropdown}
                                class="px-3 py-2.5 rounded-lg border border-blue-200 bg-white/60 backdrop-blur-sm text-slate-700 hover:bg-white transition-colors text-sm font-semibold flex items-center gap-1"
                            >
                                ⚙️ Columns
                                <span class="text-xs ml-1">{showColumnDropdown ? '▼' : '▶'}</span>
                            </button>

                            {#if showColumnDropdown}
                                <div class="absolute top-full mt-1 left-0 bg-white border border-slate-300 rounded-lg shadow-lg z-50 min-w-max p-3 max-h-96 overflow-y-auto">
                                    {#each COLUMN_LABELS as col}
                                        <label class="flex items-center gap-2 px-3 py-2 hover:bg-slate-100 rounded cursor-pointer whitespace-nowrap">
                                            <input
                                                type="checkbox"
                                                checked={columnVisibility[col.key]}
                                                on:change={(e) => {
                                                    columnVisibility[col.key] = e.target.checked;
                                                    columnVisibility = columnVisibility;
                                                }}
                                                class="w-4 h-4 rounded border-slate-300 text-blue-600 focus:ring-2 focus:ring-blue-500"
                                            />
                                            <span class="text-sm text-slate-700">{col.label}</span>
                                        </label>
                                    {/each}
                                </div>
                            {/if}
                        </div>

                        <div class="text-sm text-slate-600 font-semibold ml-auto">
                            {filteredData.length} of {documentsExpiryData.length}
                        </div>
                    </div>

                    <!-- Table Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col h-full">
                        <!-- Table with sticky header and scrollable content -->
                        <div class="overflow-x-auto overflow-y-auto flex-1 max-h-[60vh]">
                            <table class="w-full border-collapse">
                                <thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
                                    <tr>
                                        {#if columnVisibility.id}
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-r border-blue-400 min-w-fit">{$t('hr.employeeId') || 'ID'}</th>
                                        {/if}
                                        {#if columnVisibility.name}
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-r border-blue-400 min-w-fit">{$t('hr.fullName') || 'Full Name'}</th>
                                        {/if}
                                        {#if columnVisibility.nationality}
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-r border-blue-400 min-w-fit">{$t('hr.nationality') || 'Nationality'}</th>
                                        {/if}
                                        {#if columnVisibility.branch}
                                            <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-r border-blue-400 min-w-fit">{$t('hr.currentBranch') || 'Current Branch'}</th>
                                        {/if}
                                        {#each DOCUMENT_TYPES as docType}
                                            {#if columnVisibility[`doc_${docType.type}`]}
                                                <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-r border-blue-400 min-w-fit bg-blue-500/30">
                                                    {docType.label}
                                                </th>
                                            {/if}
                                        {/each}
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#if loading}
                                        <tr>
                                            <td colspan={4 + DOCUMENT_TYPES.length} class="px-4 py-8 text-center">
                                                <div class="flex items-center justify-center">
                                                    <div class="animate-spin">
                                                        <div class="w-8 h-8 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
                                                    </div>
                                                    <p class="ml-3 text-slate-600">{$t('common.loading') || 'Loading...'}</p>
                                                </div>
                                            </td>
                                        </tr>
                                    {:else if documentsExpiryData.length === 0}
                                        <tr>
                                            <td colspan={4 + DOCUMENT_TYPES.length} class="px-4 py-8 text-center text-slate-500">
                                                {$t('hr.dashboard.no_data') || 'No data available'}
                                            </td>
                                        </tr>
                                    {:else if filteredData.length === 0}
                                        <tr>
                                            <td colspan={4 + DOCUMENT_TYPES.length} class="px-4 py-8 text-center text-slate-500">
                                                No employees match your search
                                            </td>
                                        </tr>
                                    {:else}
                                        {#each sortedFilteredData as emp, index}
                                            <tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                                {#if columnVisibility.id}
                                                    <td class="px-4 py-3 text-sm text-slate-600 font-mono min-w-fit border-r border-slate-200">
                                                        {emp.id}
                                                    </td>
                                                {/if}
                                                {#if columnVisibility.name}
                                                    <td class="px-4 py-3 text-sm text-slate-700 font-semibold min-w-fit border-r border-slate-200">
                                                        {getEmployeeNameDisplay(emp.name_en, emp.name_ar)}
                                                    </td>
                                                {/if}
                                                {#if columnVisibility.nationality}
                                                    <td class="px-4 py-3 text-sm text-slate-700 min-w-fit border-r border-slate-200">
                                                        {getNationalityDisplay(emp.nationality_name_en, emp.nationality_name_ar)}
                                                    </td>
                                                {/if}
                                                {#if columnVisibility.branch}
                                                    <td class="px-4 py-3 text-sm text-slate-700 min-w-fit border-r border-slate-200">
                                                        <div class="flex flex-col gap-0.5">
                                                            <div class="font-semibold">{$locale === 'ar' ? emp.branch_name_ar : emp.branch_name_en}</div>
                                                            <div class="text-xs text-slate-500 font-normal">{$locale === 'ar' ? emp.branch_location_ar : emp.branch_location_en}</div>
                                                        </div>
                                                    </td>
                                                {/if}
                                                {#each DOCUMENT_TYPES as docType}
                                                    {#if columnVisibility[`doc_${docType.type}`]}
                                                        {@const doc = emp.documents[docType.type]}
                                                        <td 
                                                            class="px-4 py-3 text-center text-xs min-w-fit border-r border-slate-200 cursor-pointer hover:bg-blue-50"
                                                            on:dblclick={() => openDateModal(emp.id, getEmployeeNameDisplay(emp.name_en, emp.name_ar), docType.label, docType.key, doc?.expiryDate || '')}
                                                        >
                                                            {#if doc && doc.expiryDate}
                                                                <div class="flex flex-col gap-1 items-center">
                                                                    <div class="font-mono text-slate-600 text-[10px]">{doc.expiryDate}</div>
                                                                    <div class="font-bold {doc.daysRemaining < 0 ? 'text-red-700' : doc.daysRemaining <= 30 ? 'text-orange-700' : doc.daysRemaining <= 90 ? 'text-yellow-700' : 'text-green-700'}">
                                                                        {#if doc.daysRemaining < 0}
                                                                            <span class="text-red-600">
                                                                                -{Math.abs(doc.daysRemaining)}d
                                                                            </span>
                                                                        {:else}
                                                                            <span>{doc.daysRemaining}d</span>
                                                                        {/if}
                                                                    </div>
                                                                    {#if doc.daysRemaining < 0}
                                                                        <span class="inline-block px-2 py-0.5 rounded text-[9px] font-black bg-red-100 text-red-800 truncate max-w-[80px]">
                                                                            Expired
                                                                        </span>
                                                                    {:else if doc.daysRemaining <= 30}
                                                                        <span class="inline-block px-2 py-0.5 rounded text-[9px] font-black bg-orange-100 text-orange-800 truncate max-w-[80px]">
                                                                            Soon
                                                                        </span>
                                                                    {:else if doc.daysRemaining <= 90}
                                                                        <span class="inline-block px-2 py-0.5 rounded text-[9px] font-black bg-yellow-100 text-yellow-800 truncate max-w-[80px]">
                                                                            Warning
                                                                        </span>
                                                                    {:else}
                                                                        <span class="inline-block px-2 py-0.5 rounded text-[9px] font-black bg-green-100 text-green-800 truncate max-w-[80px]">
                                                                            Active
                                                                        </span>
                                                                    {/if}
                                                                </div>
                                                            {:else}
                                                                <div class="text-slate-300 text-sm">—</div>
                                                            {/if}
                                                        </td>
                                                    {/if}
                                                {/each}
                                            </tr>
                                        {/each}
                                    {/if}
                                </tbody>
                            </table>
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {searchTerm ? `${filteredData.length} of ${documentsExpiryData.length}` : `${documentsExpiryData.length}`} {$t('hr.dashboard.employees') || 'employee(s)'}
                        </div>
                    </div>
                </div>

            {:else if activeTab === 'Performance'}
                <!-- Performance Tab Content -->
                <div>
                    <!-- Header with decorative line -->
                    <div class="mb-6 flex items-center gap-4">
                        <div class="absolute inset-0 rounded-full blur-2xl bg-indigo-400/30"></div>
                        <h1 class="text-3xl font-black text-slate-800 tracking-tight relative z-10">
                            📊 {$t('hr.dashboard.performance') || 'Performance'}
                        </h1>
                        <div class="flex-1 flex gap-3 items-center">
                            <div class="h-[3px] w-16 rounded-full bg-purple-500 shadow-[0_0_10px_rgba(147,51,234,0.5)]"></div>
                            <div class="h-[3px] w-16 rounded-full bg-purple-500 shadow-[0_0_10px_rgba(147,51,234,0.5)]"></div>
                        </div>
                    </div>

                    <!-- Table Container -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col h-full">
                        <!-- Table Wrapper with horizontal scroll -->
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse">
                                <thead class="sticky top-0 bg-purple-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.fullName') || 'Full Name'}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.currentPosition') || 'Current Position'}</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('hr.promotedPosition') || 'Promoted Position'}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('common.promotionDate') || 'Promotion Date'}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('common.status') || 'Status'}</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-purple-400">{$t('common.action') || 'Action'}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    <!-- Empty table body - to be populated later -->
                                </tbody>
                            </table>
                        </div>

                        <!-- Footer with row count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            {$t('hr.dashboard.no_data') || 'No data available'}
                        </div>
                    </div>
                </div>
            {/if}
        </div>
    </div>
</div>

<!-- Date Edit Modal -->
{#if showDateModal}
    <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" on:click={closeDateModal}>
        <div class="bg-white rounded-lg shadow-2xl max-w-md w-full mx-4 p-6" on:click|stopPropagation>
            <h2 class="text-2xl font-bold text-slate-800 mb-4">Edit Document Date</h2>
            
            <div class="space-y-4">
                <div>
                    <label class="block text-sm font-semibold text-slate-700 mb-2">Employee</label>
                    <div class="px-3 py-2 bg-slate-100 rounded border border-slate-200 text-slate-600">
                        {modalEmployeeName}
                    </div>
                </div>
                
                <div>
                    <label class="block text-sm font-semibold text-slate-700 mb-2">Document Type</label>
                    <div class="px-3 py-2 bg-slate-100 rounded border border-slate-200 text-slate-600">
                        {modalDocumentType}
                    </div>
                </div>
                
                <div>
                    <label class="block text-sm font-semibold text-slate-700 mb-2">Current Date</label>
                    <div class="px-3 py-2 bg-slate-100 rounded border border-slate-200 text-slate-600">
                        {modalCurrentDate || 'No date set'}
                    </div>
                </div>
                
                <div>
                    <label class="block text-sm font-semibold text-slate-700 mb-2">New Expiry Date</label>
                    <input
                        type="date"
                        bind:value={modalNewDate}
                        class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                </div>
            </div>
            
            <div class="flex gap-3 mt-6">
                <button
                    on:click={closeDateModal}
                    disabled={isSaving}
                    class="flex-1 px-4 py-2 bg-slate-200 text-slate-800 rounded-lg font-semibold hover:bg-slate-300 transition-colors disabled:opacity-50"
                >
                    Cancel
                </button>
                <button
                    on:click={saveDateChange}
                    disabled={isSaving}
                    class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 transition-colors disabled:opacity-50"
                >
                    {isSaving ? 'Saving...' : 'Save'}
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
