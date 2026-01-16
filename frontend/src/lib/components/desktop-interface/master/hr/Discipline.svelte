<script lang="ts">
    import { onMount } from 'svelte';
    import { t } from '$lib/i18n';
    
    let activeTab = 'Warning Categories Manager';
    let loading = false;
    let error: string | null = null;

    // Data lists
    let violations: any[] = [];
    let mainCategories: any[] = [];
    let subCategories: any[] = [];

    // Filters
    let mainCategoryFilter = '';
    let subCategoryFilter = '';
    let violationSearchQuery = '';

    // Modal Visibility
    let showMainModal = false;
    let showSubModal = false;
    let showViolationModal = false;
    let isSaving = false;

    // Form Data
    let mainFormData = { id: '', name_en: '', name_ar: '' };
    let subFormData = { id: '', main_id: '', name_en: '', name_ar: '' };
    let violationFormData = { id: '', main_id: '', sub_id: '', name_en: '', name_ar: '' };

    function generateNextId(list: any[], prefix: string) {
        if (!list || list.length === 0) return `${prefix}1`;
        const ids = list.map(item => {
            const numPart = item.id.replace(prefix, '');
            const num = parseInt(numPart);
            return isNaN(num) ? 0 : num;
        });
        const maxId = Math.max(0, ...ids);
        return `${prefix}${maxId + 1}`;
    }

    function openAddMainModal() {
        mainFormData = { 
            id: generateNextId(mainCategories, 'wam'), 
            name_en: '', 
            name_ar: '' 
        };
        showMainModal = true;
    }

    function openAddSubModal() {
        subFormData = { 
            id: generateNextId(subCategories, 'was'), 
            main_id: '', 
            name_en: '', 
            name_ar: '' 
        };
        showSubModal = true;
    }

    function openAddViolationModal() {
        violationFormData = { 
            id: generateNextId(violations, 'wav'), 
            main_id: '', 
            sub_id: '', 
            name_en: '', 
            name_ar: '' 
        };
        showViolationModal = true;
    }

    onMount(async () => {
        if (activeTab === 'Warning Categories Manager') {
            await loadWarningCategories();
        }
    });

    async function loadWarningCategories() {
        loading = true;
        error = null;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            // Fetch main categories for filter
            const { data: mainData, error: mainErr } = await supabase
                .from('warning_main_category')
                .select('*')
                .order('name_en');
            if (mainErr) throw mainErr;
            mainCategories = mainData || [];

            // Fetch sub categories for filter
            const { data: subData, error: subErr } = await supabase
                .from('warning_sub_category')
                .select('*')
                .order('name_en');
            if (subErr) throw subErr;
            subCategories = subData || [];

            // Fetch violations with joins
            const { data: violationData, error: vioErr } = await supabase
                .from('warning_violation')
                .select(`
                    *,
                    main:warning_main_category(name_en, name_ar),
                    sub:warning_sub_category(name_en, name_ar)
                `)
                .order('id');
            
            if (vioErr) throw vioErr;
            violations = violationData || [];
        } catch (err) {
            console.error('Error loading warning categories:', err);
            error = err instanceof Error ? err.message : 'Failed to load data';
        } finally {
            loading = false;
        }
    }

    // Save Functions
    async function saveMainCategory() {
        if (!mainFormData.id || !mainFormData.name_en || !mainFormData.name_ar) return;
        isSaving = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { error: err } = await supabase.from('warning_main_category').insert([mainFormData]);
            if (err) throw err;
            showMainModal = false;
            mainFormData = { id: '', name_en: '', name_ar: '' };
            await loadWarningCategories();
        } catch (err) {
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }

    async function saveSubCategory() {
        if (!subFormData.id || !subFormData.main_id || !subFormData.name_en || !subFormData.name_ar) return;
        isSaving = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { error: err } = await supabase.from('warning_sub_category').insert([{
                id: subFormData.id,
                main_category_id: subFormData.main_id,
                name_en: subFormData.name_en,
                name_ar: subFormData.name_ar
            }]);
            if (err) throw err;
            showSubModal = false;
            subFormData = { id: '', main_id: '', name_en: '', name_ar: '' };
            await loadWarningCategories();
        } catch (err) {
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }

    async function saveViolation() {
        if (!violationFormData.id || !violationFormData.sub_id || !violationFormData.main_id || !violationFormData.name_en || !violationFormData.name_ar) return;
        isSaving = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            const { error: err } = await supabase.from('warning_violation').insert([{
                id: violationFormData.id,
                sub_category_id: violationFormData.sub_id,
                main_category_id: violationFormData.main_id,
                name_en: violationFormData.name_en,
                name_ar: violationFormData.name_ar
            }]);
            if (err) throw err;
            showViolationModal = false;
            violationFormData = { id: '', main_id: '', sub_id: '', name_en: '', name_ar: '' };
            await loadWarningCategories();
        } catch (err) {
            alert('Error: ' + (err instanceof Error ? err.message : 'Failed to save'));
        } finally {
            isSaving = false;
        }
    }

    function getFilteredViolations() {
        let filtered = violations;

        if (mainCategoryFilter) {
            filtered = filtered.filter(v => v.main_category_id === mainCategoryFilter);
        }

        if (subCategoryFilter) {
            filtered = filtered.filter(v => v.sub_category_id === subCategoryFilter);
        }

        if (violationSearchQuery.trim()) {
            const query = violationSearchQuery.toLowerCase();
            filtered = filtered.filter(v => 
                v.name_en?.toLowerCase().includes(query) || 
                v.name_ar?.includes(query) ||
                v.id?.toLowerCase().includes(query)
            );
        }

        return filtered;
    }

    async function handleTabChange() {
        if (activeTab === 'Warning Categories Manager') {
            await loadWarningCategories();
        }
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-start shadow-sm">
        <div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            <button 
                class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
                {activeTab === 'Warning Categories Manager' 
                    ? 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]' 
                    : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                on:click={() => { activeTab = 'Warning Categories Manager'; handleTabChange(); }}
            >
                <span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📁</span>
                <span class="relative z-10">Warning Categories Manager</span>
                {#if activeTab === 'Warning Categories Manager'}
                    <div class="absolute inset-0 bg-white/10 animate-pulse"></div>
                {/if}
            </button>

            <button 
                class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
                {activeTab === 'Report an Incident' 
                    ? 'bg-orange-500 text-white shadow-lg shadow-orange-100 scale-[1.02]' 
                    : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                on:click={() => { activeTab = 'Report an Incident'; handleTabChange(); }}
            >
                <span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📝</span>
                <span class="relative z-10">Report an Incident</span>
                {#if activeTab === 'Report an Incident'}
                    <div class="absolute inset-0 bg-white/10 animate-pulse"></div>
                {/if}
            </button>

            <button 
                class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
                {activeTab === 'Issue Warning' 
                    ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' 
                    : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                on:click={() => { activeTab = 'Issue Warning'; handleTabChange(); }}
            >
                <span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">⚠️</span>
                <span class="relative z-10">Issue Warning</span>
                {#if activeTab === 'Issue Warning'}
                    <div class="absolute inset-0 bg-white/10 animate-pulse"></div>
                {/if}
            </button>
        </div>
    </div>

    <!-- Main Content Area -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Futuristic background decorative elements -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col">
            {#if activeTab === 'Warning Categories Manager'}
                {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">Loading categories...</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">Error: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadWarningCategories}
                        >
                            Retry
                        </button>
                    </div>
                {:else}
                    <!-- Action Buttons and Filter Controls -->
                    <div class="mb-6 space-y-4 animate-in">
                        <!-- Create Buttons Row -->
                        <div class="flex gap-3">
                            <button 
                                class="flex items-center gap-2 px-5 py-2.5 bg-orange-600 text-white rounded-xl font-bold text-xs uppercase tracking-wider hover:bg-orange-700 hover:shadow-lg transition-all active:scale-95"
                                on:click={openAddMainModal}
                            >
                                <span class="text-base">➕</span>
                                Add Main Category
                            </button>
                            <button 
                                class="flex items-center gap-2 px-5 py-2.5 bg-orange-500 text-white rounded-xl font-bold text-xs uppercase tracking-wider hover:bg-orange-600 hover:shadow-lg transition-all active:scale-95"
                                on:click={openAddSubModal}
                            >
                                <span class="text-base">➕</span>
                                Add Sub Category
                            </button>
                            <button 
                                class="flex items-center gap-2 px-5 py-2.5 bg-orange-400 text-white rounded-xl font-bold text-xs uppercase tracking-wider hover:bg-orange-500 hover:shadow-lg transition-all active:scale-95"
                                on:click={openAddViolationModal}
                            >
                                <span class="text-base">➕</span>
                                Add Violation
                            </button>
                        </div>

                        <!-- Filters Row -->
                        <div class="flex gap-4">
                            <!-- Main Category Filter -->
                            <div class="flex-1">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Main Category</label>
                                <select 
                                    bind:value={mainCategoryFilter}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all shadow-sm"
                                >
                                    <option value="">All Main Categories</option>
                                    {#each mainCategories as cat}
                                        <option value={cat.id}>{cat.name_en} / {cat.name_ar}</option>
                                    {/each}
                                </select>
                            </div>

                            <!-- Sub Category Filter -->
                            <div class="flex-1">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Sub Category</label>
                                <select 
                                    bind:value={subCategoryFilter}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all shadow-sm"
                                >
                                    <option value="">All Sub Categories</option>
                                    {#each subCategories as sub}
                                        {#if !mainCategoryFilter || sub.main_category_id === mainCategoryFilter}
                                            <option value={sub.id}>{sub.name_en} / {sub.name_ar}</option>
                                        {/if}
                                    {/each}
                                </select>
                            </div>

                            <!-- Search -->
                            <div class="flex-1">
                                <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">Search Violation</label>
                                <input 
                                    type="text"
                                    bind:value={violationSearchQuery}
                                    placeholder="Search violation or ID..."
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all shadow-sm"
                                />
                            </div>
                        </div>
                    </div>

                    <!-- Warning Categories Table -->
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col scale-in">
                        <div class="overflow-x-auto">
                            <table class="w-full border-collapse">
                                <thead class="sticky top-0 bg-orange-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">ID</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Main Category</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Sub Category</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Violation (English)</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">Violation (Arabic)</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each getFilteredViolations() as violation}
                                        <tr class="hover:bg-orange-50/50 transition-colors duration-200 group">
                                            <td class="px-6 py-4 text-sm font-bold text-slate-500 uppercase">{violation.id}</td>
                                            <td class="px-6 py-4">
                                                <div class="text-sm font-semibold text-slate-900">{violation.main?.name_en || 'N/A'}</div>
                                                <div class="text-xs text-slate-500 mt-0.5">{violation.main?.name_ar || ''}</div>
                                            </td>
                                            <td class="px-6 py-4">
                                                <div class="text-sm font-semibold text-slate-900">{violation.sub?.name_en || 'N/A'}</div>
                                                <div class="text-xs text-slate-500 mt-0.5">{violation.sub?.name_ar || ''}</div>
                                            </td>
                                            <td class="px-6 py-4 text-sm font-medium text-slate-800">{violation.name_en}</td>
                                            <td class="px-6 py-4 text-sm font-medium text-slate-800 text-right" dir="rtl">{violation.name_ar}</td>
                                        </tr>
                                    {/each}
                                    {#if getFilteredViolations().length === 0}
                                        <tr>
                                            <td colspan="5" class="px-6 py-12 text-center text-slate-500 italic">No category data found matching your filters.</td>
                                        </tr>
                                    {/if}
                                </tbody>
                            </table>
                        </div>
                    </div>
                {/if}
            {:else if activeTab === 'Report an Incident'}
                <div class="p-8 text-center text-slate-400 font-bold uppercase tracking-widest animate-pulse">
                    Incident Reporting Content
                </div>
            {:else if activeTab === 'Issue Warning'}
                <div class="p-8 text-center text-slate-400 font-bold uppercase tracking-widest animate-pulse">
                    Issue Warning Content
                </div>
            {/if}
        </div>
    </div>
</div>

<!-- Main Category Modal -->
{#if showMainModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-[100] flex items-center justify-center animate-in">
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden scale-in">
            <div class="px-6 py-4 bg-gradient-to-r from-orange-600 to-orange-500 text-white flex justify-between items-center">
                <h3 class="text-lg font-bold">Add Main Category</h3>
                <button on:click={() => showMainModal = false} class="text-2xl font-light hover:rotate-90 transition-transform">&times;</button>
            </div>
            <div class="p-6 space-y-4">
                <div>
                    <label for="main-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">ID (Auto-generated)</label>
                    <input id="main-id" type="text" bind:value={mainFormData.id} readonly class="w-full px-4 py-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-0 outline-none cursor-not-allowed" placeholder="Auto-generated ID" />
                </div>
                <div>
                    <label for="main-name-en" class="block text-xs font-bold text-slate-500 uppercase mb-1">Name (English)</label>
                    <input id="main-name-en" type="text" bind:value={mainFormData.name_en} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none" placeholder="Enter English name" />
                </div>
                <div>
                    <label for="main-name-ar" class="block text-xs font-bold text-slate-500 uppercase mb-1">Name (Arabic)</label>
                    <input id="main-name-ar" type="text" bind:value={mainFormData.name_ar} dir="rtl" class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none font-semibold" placeholder="أدخل الاسم بالعربي" />
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button on:click={() => showMainModal = false} class="px-4 py-2 rounded-lg font-semibold text-slate-600 hover:bg-slate-200 transition">Cancel</button>
                <button on:click={saveMainCategory} disabled={isSaving} class="px-6 py-2 rounded-lg font-black text-white bg-orange-600 hover:bg-orange-700 disabled:opacity-50 transition transform hover:scale-105">
                    {isSaving ? 'Saving...' : 'Save'}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Sub Category Modal -->
{#if showSubModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-[100] flex items-center justify-center animate-in">
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden scale-in">
            <div class="px-6 py-4 bg-gradient-to-r from-orange-600 to-orange-500 text-white flex justify-between items-center">
                <h3 class="text-lg font-bold">Add Sub Category</h3>
                <button on:click={() => showSubModal = false} class="text-2xl font-light hover:rotate-90 transition-transform">&times;</button>
            </div>
            <div class="p-6 space-y-4">
                <div>
                    <label for="sub-main-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">Main Category</label>
                    <select id="sub-main-id" bind:value={subFormData.main_id} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none">
                        <option value="">Select Main Category</option>
                        {#each mainCategories as cat}
                            <option value={cat.id}>{cat.name_en} / {cat.name_ar}</option>
                        {/each}
                    </select>
                </div>
                <div>
                    <label for="sub-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">ID (Auto-generated)</label>
                    <input id="sub-id" type="text" bind:value={subFormData.id} readonly class="w-full px-4 py-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-0 outline-none cursor-not-allowed" placeholder="Auto-generated ID" />
                </div>
                <div>
                    <label for="sub-name-en" class="block text-xs font-bold text-slate-500 uppercase mb-1">Name (English)</label>
                    <input id="sub-name-en" type="text" bind:value={subFormData.name_en} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none" placeholder="Enter English name" />
                </div>
                <div>
                    <label for="sub-name-ar" class="block text-xs font-bold text-slate-500 uppercase mb-1">Name (Arabic)</label>
                    <input id="sub-name-ar" type="text" bind:value={subFormData.name_ar} dir="rtl" class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none font-semibold" placeholder="أدخل الاسم بالعربي" />
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button on:click={() => showSubModal = false} class="px-4 py-2 rounded-lg font-semibold text-slate-600 hover:bg-slate-200 transition">Cancel</button>
                <button on:click={saveSubCategory} disabled={isSaving} class="px-6 py-2 rounded-lg font-black text-white bg-orange-600 hover:bg-orange-700 disabled:opacity-50 transition transform hover:scale-105">
                    {isSaving ? 'Saving...' : 'Save'}
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Violation Modal -->
{#if showViolationModal}
    <div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-[100] flex items-center justify-center animate-in">
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden scale-in">
            <div class="px-6 py-4 bg-gradient-to-r from-orange-600 to-orange-500 text-white flex justify-between items-center">
                <h3 class="text-lg font-bold">Add Violation</h3>
                <button on:click={() => showViolationModal = false} class="text-2xl font-light hover:rotate-90 transition-transform">&times;</button>
            </div>
            <div class="p-6 space-y-4">
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label for="viol-main-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">Main Category</label>
                        <select id="viol-main-id" bind:value={violationFormData.main_id} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none text-xs">
                            <option value="">Select Main</option>
                            {#each mainCategories as cat}
                                <option value={cat.id}>{cat.name_en}</option>
                            {/each}
                        </select>
                    </div>
                    <div>
                        <label for="viol-sub-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">Sub Category</label>
                        <select id="viol-sub-id" bind:value={violationFormData.sub_id} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none text-xs">
                            <option value="">Select Sub</option>
                            {#each subCategories as sub}
                                {#if !violationFormData.main_id || sub.main_category_id === violationFormData.main_id}
                                    <option value={sub.id}>{sub.name_en}</option>
                                    {/if}
                            {/each}
                        </select>
                    </div>
                </div>
                <div>
                    <label for="viol-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">ID (Auto-generated)</label>
                    <input id="viol-id" type="text" bind:value={violationFormData.id} readonly class="w-full px-4 py-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-0 outline-none cursor-not-allowed" placeholder="Auto-generated ID" />
                </div>
                <div>
                    <label for="viol-name-en" class="block text-xs font-bold text-slate-500 uppercase mb-1">Violation (English)</label>
                    <textarea id="viol-name-en" bind:value={violationFormData.name_en} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none h-20" placeholder="Enter violation description"></textarea>
                </div>
                <div>
                    <label for="viol-name-ar" class="block text-xs font-bold text-slate-500 uppercase mb-1">Violation (Arabic)</label>
                    <textarea id="viol-name-ar" bind:value={violationFormData.name_ar} dir="rtl" class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none h-20 font-semibold" placeholder="أدخل وصف المخالفة"></textarea>
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button on:click={() => showViolationModal = false} class="px-4 py-2 rounded-lg font-semibold text-slate-600 hover:bg-slate-200 transition">Cancel</button>
                <button on:click={saveViolation} disabled={isSaving} class="px-6 py-2 rounded-lg font-black text-white bg-orange-600 hover:bg-orange-700 disabled:opacity-50 transition transform hover:scale-105">
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
        from { opacity: 0; transform: translateY(10px); }
        to { opacity: 1; transform: translateY(0); }
    }

    @keyframes scaleIn {
        from { opacity: 0; transform: scale(0.98); }
        to { opacity: 1; transform: scale(1); }
    }

    .animate-in {
        animation: fadeIn 0.4s ease-out forwards;
    }

    .scale-in {
        animation: scaleIn 0.5s ease-out forwards;
    }
</style>
