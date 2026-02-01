<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { openWindow } from '$lib/utils/windowManagerUtils';
    import ReportIncident from './ReportIncident.svelte';
    import IssueWarning from './IssueWarning.svelte';
    
    let activeTab = 'Warning Categories Manager';
    let loading = false;
    let error: string | null = null;

    // Data lists
    let violations: any[] = [];
    let mainCategories: any[] = [];
    let subCategories: any[] = [];
    let branches: any[] = [];

    // Filters
    let mainCategoryFilter = '';
    let subCategoryFilter = '';
    let violationSearchQuery = '';

    // Modal Visibility
    let showMainModal = false;
    let showSubModal = false;
    let showViolationModal = false;
    let isSaving = false;

    // Employee data
    let employees: any[] = [];
    let selectedEmployee = '';
    let selectedViolation: any = null;

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
        await loadWarningCategories();
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

            // Fetch employees
            const { data: employeeData, error: empErr } = await supabase
                .from('hr_employee_master')
                .select('id, name_en, name_ar, employee_id_mapping')
                .order('name_en');
            if (empErr) throw empErr;
            employees = employeeData || [];

            // Load branches
            const { data: branchData, error: branchErr } = await supabase
                .from('branches')
                .select('id, name_en, name_ar, location_en, location_ar')
                .eq('is_active', true)
                .order('name_en');
            if (branchErr) throw branchErr;
            branches = branchData || [];
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

    function openReportModal(violation: any) {
        selectedViolation = violation;
        selectedEmployee = '';
        const windowId = `report-incident-${Date.now()}`;
        openWindow({
            id: windowId,
            title: `Report Incident - ${violation.name_en}`,
            component: ReportIncident,
            icon: '📝',
            size: { width: 900, height: 600 },
            position: { 
                x: 100 + (Math.random() * 50),
                y: 100 + (Math.random() * 50) 
            },
            resizable: true,
            minimizable: true,
            maximizable: true,
            closable: true,
            props: {
                violation: violation,
                employees: employees,
                branches: branches
            }
        });
    }

    function openWarningModal(violation: any) {
        selectedViolation = violation;
        selectedEmployee = '';
        const windowId = `issue-warning-${Date.now()}`;
        openWindow({
            id: windowId,
            title: `Issue Warning - ${violation.name_en}`,
            component: IssueWarning,
            icon: '⚠️',
            size: { width: 900, height: 600 },
            position: { 
                x: 150 + (Math.random() * 50),
                y: 150 + (Math.random() * 50) 
            },
            resizable: true,
            minimizable: true,
            maximizable: true,
            closable: true,
            props: {
                violation: violation,
                employees: employees
            }
        });
    }

    async function handleTabChange() {
        await loadWarningCategories();
    }

</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
    <!-- Main Content Area -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Futuristic background decorative elements -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
            {#if loading}
                    <div class="flex items-center justify-center h-full">
                        <div class="text-center">
                            <div class="animate-spin inline-block">
                                <div class="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full"></div>
                            </div>
                            <p class="mt-4 text-slate-600 font-semibold">{$t('common.loading')}</p>
                        </div>
                    </div>
                {:else if error}
                    <div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
                        <p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
                        <button 
                            class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
                            on:click={loadWarningCategories}
                        >
                            {$t('common.retry')}
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
                                {$t('hr.discipline.addMainCategory')}
                            </button>
                            <button 
                                class="flex items-center gap-2 px-5 py-2.5 bg-orange-500 text-white rounded-xl font-bold text-xs uppercase tracking-wider hover:bg-orange-600 hover:shadow-lg transition-all active:scale-95"
                                on:click={openAddSubModal}
                            >
                                <span class="text-base">➕</span>
                                {$t('hr.discipline.addSubCategory')}
                            </button>
                            <button 
                                class="flex items-center gap-2 px-5 py-2.5 bg-orange-400 text-white rounded-xl font-bold text-xs uppercase tracking-wider hover:bg-orange-500 hover:shadow-lg transition-all active:scale-95"
                                on:click={openAddViolationModal}
                            >
                                <span class="text-base">➕</span>
                                {$t('hr.discipline.addViolation')}
                            </button>
                        </div>

                        <!-- Filters Row -->
                        <div class="flex gap-4">
                            <!-- Main Category Filter -->
                            <div class="flex-1">
                                <label for="main-category-filter" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.discipline.mainCategory')}</label>
                                <select 
                                    id="main-category-filter"
                                    bind:value={mainCategoryFilter}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all shadow-sm"
                                >
                                    <option value="">{$t('hr.discipline.allMain')}</option>
                                    {#each mainCategories as cat}
                                        <option value={cat.id}>{$locale === 'ar' ? (cat.name_ar || cat.name_en) : cat.name_en}</option>
                                    {/each}
                                </select>
                            </div>

                            <!-- Sub Category Filter -->
                            <div class="flex-1">
                                <label for="sub-category-filter" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('hr.discipline.subCategory')}</label>
                                <select 
                                    id="sub-category-filter"
                                    bind:value={subCategoryFilter}
                                    class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all shadow-sm"
                                >
                                    <option value="">{$t('hr.discipline.allSub')}</option>
                                    {#each subCategories as sub}
                                        {#if !mainCategoryFilter || sub.main_category_id === mainCategoryFilter}
                                            <option value={sub.id}>{$locale === 'ar' ? (sub.name_ar || sub.name_en) : sub.name_en}</option>
                                        {/if}
                                    {/each}
                                </select>
                            </div>

                            <!-- Search -->
                            <div class="flex-1">
                                <label for="violation-search" class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('actions.search')}</label>
                                <input 
                                    id="violation-search"
                                    type="text"
                                    bind:value={violationSearchQuery}
                                    placeholder={$t('hr.discipline.searchViolations')}
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
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.discipline.id')}</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.discipline.mainCategory')}</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.discipline.subCategory')}</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.discipline.nameEn')}</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.discipline.nameAr')}</th>
                                        <th class="px-6 py-4 text-left text-xs font-black uppercase tracking-wider border-b-2 border-orange-400">{$t('hr.discipline.actions')}</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-100">
                                    {#each getFilteredViolations() as violation}
                                        <tr class="hover:bg-orange-50/50 transition-colors duration-200 group">
                                            <td class="px-6 py-4 text-sm font-bold text-slate-500 uppercase">{violation.id}</td>
                                            <td class="px-6 py-4">
                                                <div class="text-sm font-semibold text-slate-900">{$locale === 'ar' ? (violation.main?.name_ar || violation.main?.name_en || 'N/A') : (violation.main?.name_en || 'N/A')}</div>
                                                {#if $locale === 'en' && violation.main?.name_ar}
                                                    <div class="text-xs text-slate-500 mt-0.5">{violation.main.name_ar}</div>
                                                {:else if $locale === 'ar' && violation.main?.name_en}
                                                    <div class="text-xs text-slate-500 mt-0.5">{violation.main.name_en}</div>
                                                {/if}
                                            </td>
                                            <td class="px-6 py-4">
                                                <div class="text-sm font-semibold text-slate-900">{$locale === 'ar' ? (violation.sub?.name_ar || violation.sub?.name_en || 'N/A') : (violation.sub?.name_en || 'N/A')}</div>
                                                {#if $locale === 'en' && violation.sub?.name_ar}
                                                    <div class="text-xs text-slate-500 mt-0.5">{violation.sub.name_ar}</div>
                                                {:else if $locale === 'ar' && violation.sub?.name_en}
                                                    <div class="text-xs text-slate-500 mt-0.5">{violation.sub.name_en}</div>
                                                {/if}
                                            </td>
                                            <td class="px-6 py-4 text-sm font-medium text-slate-800">{violation.name_en}</td>
                                            <td class="px-6 py-4 text-sm font-medium text-slate-800 text-right" dir="rtl">{violation.name_ar}</td>
                                            <td class="px-6 py-4 flex gap-2">
                                                <button
                                                    class="flex items-center gap-1 px-3 py-1.5 bg-blue-600 text-white rounded-lg text-xs font-bold hover:bg-blue-700 transition-all active:scale-95"
                                                    on:click={() => openReportModal(violation)}
                                                >
                                                    <span>📝</span>
                                                    {$t('hr.discipline.reportIncident')}
                                                </button>
                                                <button
                                                    class="flex items-center gap-1 px-3 py-1.5 bg-yellow-600 text-white rounded-lg text-xs font-bold hover:bg-yellow-700 transition-all active:scale-95"
                                                    on:click={() => openWarningModal(violation)}
                                                >
                                                    <span>⚠️</span>
                                                    {$t('hr.discipline.issueWarning')}
                                                </button>
                                            </td>
                                        </tr>
                                    {/each}
                                    {#if getFilteredViolations().length === 0}
                                        <tr>
                                            <td colspan="6" class="px-6 py-12 text-center text-slate-500 italic">{$t('hr.discipline.noViolations')}</td>
                                        </tr>
                                    {/if}
                                </tbody>
                            </table>
                        </div>
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
                <h3 class="text-lg font-bold">{$t('hr.discipline.addMainCategory')}</h3>
                <button on:click={() => showMainModal = false} class="text-2xl font-light hover:rotate-90 transition-transform">&times;</button>
            </div>
            <div class="p-6 space-y-4">
                <div>
                    <label for="main-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.idAutoGenerated')}</label>
                    <input id="main-id" type="text" bind:value={mainFormData.id} readonly class="w-full px-4 py-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-0 outline-none cursor-not-allowed" placeholder={$t('hr.discipline.idAutoGenerated')} />
                </div>
                <div>
                    <label for="main-name-en" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.nameEn')}</label>
                    <input id="main-name-en" type="text" bind:value={mainFormData.name_en} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none" placeholder={$t('hr.discipline.enterEnName')} />
                </div>
                <div>
                    <label for="main-name-ar" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.nameAr')}</label>
                    <input id="main-name-ar" type="text" bind:value={mainFormData.name_ar} dir="rtl" class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none font-semibold" placeholder={$t('hr.discipline.enterArName')} />
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button on:click={() => showMainModal = false} class="px-4 py-2 rounded-lg font-semibold text-slate-600 hover:bg-slate-200 transition">{$t('actions.cancel')}</button>
                <button on:click={saveMainCategory} disabled={isSaving} class="px-6 py-2 rounded-lg font-black text-white bg-orange-600 hover:bg-orange-700 disabled:opacity-50 transition transform hover:scale-105">
                    {isSaving ? $t('common.saving') : $t('actions.save')}
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
                <h3 class="text-lg font-bold">{$t('hr.discipline.addSubCategory')}</h3>
                <button on:click={() => showSubModal = false} class="text-2xl font-light hover:rotate-90 transition-transform">&times;</button>
            </div>
            <div class="p-6 space-y-4">
                <div>
                    <label for="sub-main-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.mainCategory')}</label>
                    <select id="sub-main-id" bind:value={subFormData.main_id} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none">
                        <option value="">{$t('hr.discipline.selectMain')}</option>
                        {#each mainCategories as cat}
                            <option value={cat.id}>{$locale === 'ar' ? (cat.name_ar || cat.name_en) : cat.name_en}</option>
                        {/each}
                    </select>
                </div>
                <div>
                    <label for="sub-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.idAutoGenerated')}</label>
                    <input id="sub-id" type="text" bind:value={subFormData.id} readonly class="w-full px-4 py-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-0 outline-none cursor-not-allowed" placeholder={$t('hr.discipline.idAutoGenerated')} />
                </div>
                <div>
                    <label for="sub-name-en" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.nameEn')}</label>
                    <input id="sub-name-en" type="text" bind:value={subFormData.name_en} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none" placeholder={$t('hr.discipline.enterEnName')} />
                </div>
                <div>
                    <label for="sub-name-ar" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.nameAr')}</label>
                    <input id="sub-name-ar" type="text" bind:value={subFormData.name_ar} dir="rtl" class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none font-semibold" placeholder={$t('hr.discipline.enterArName')} />
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button on:click={() => showSubModal = false} class="px-4 py-2 rounded-lg font-semibold text-slate-600 hover:bg-slate-200 transition">{$t('actions.cancel')}</button>
                <button on:click={saveSubCategory} disabled={isSaving} class="px-6 py-2 rounded-lg font-black text-white bg-orange-600 hover:bg-orange-700 disabled:opacity-50 transition transform hover:scale-105">
                    {isSaving ? $t('common.saving') : $t('actions.save')}
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
                <h3 class="text-lg font-bold">{$t('hr.discipline.addViolation')}</h3>
                <button on:click={() => showViolationModal = false} class="text-2xl font-light hover:rotate-90 transition-transform">&times;</button>
            </div>
            <div class="p-6 space-y-4">
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label for="viol-main-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.mainCategory')}</label>
                        <select id="viol-main-id" bind:value={violationFormData.main_id} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none text-xs">
                            <option value="">{$t('hr.discipline.selectMain')}</option>
                            {#each mainCategories as cat}
                                <option value={cat.id}>{$locale === 'ar' ? (cat.name_ar || cat.name_en) : cat.name_en}</option>
                            {/each}
                        </select>
                    </div>
                    <div>
                        <label for="viol-sub-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.subCategory')}</label>
                        <select id="viol-sub-id" bind:value={violationFormData.sub_id} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none text-xs">
                            <option value="">{$t('hr.discipline.selectSub')}</option>
                            {#each subCategories as sub}
                                {#if !violationFormData.main_id || sub.main_category_id === violationFormData.main_id}
                                    <option value={sub.id}>{$locale === 'ar' ? (sub.name_ar || sub.name_en) : sub.name_en}</option>
                                    {/if}
                            {/each}
                        </select>
                    </div>
                </div>
                <div>
                    <label for="viol-id" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.idAutoGenerated')}</label>
                    <input id="viol-id" type="text" bind:value={violationFormData.id} readonly class="w-full px-4 py-2 border border-slate-200 rounded-lg bg-slate-50 focus:ring-0 outline-none cursor-not-allowed" placeholder={$t('hr.discipline.idAutoGenerated')} />
                </div>
                <div>
                    <label for="viol-name-en" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.nameEn')}</label>
                    <textarea id="viol-name-en" bind:value={violationFormData.name_en} class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none h-20" placeholder={$t('hr.discipline.enterEnName')}></textarea>
                </div>
                <div>
                    <label for="viol-name-ar" class="block text-xs font-bold text-slate-500 uppercase mb-1">{$t('hr.discipline.nameAr')}</label>
                    <textarea id="viol-name-ar" bind:value={violationFormData.name_ar} dir="rtl" class="w-full px-4 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-orange-500 outline-none h-20 font-semibold" placeholder={$t('hr.discipline.enterArName')}></textarea>
                </div>
            </div>
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
                <button on:click={() => showViolationModal = false} class="px-4 py-2 rounded-lg font-semibold text-slate-600 hover:bg-slate-200 transition">{$t('actions.cancel')}</button>
                <button on:click={saveViolation} disabled={isSaving} class="px-6 py-2 rounded-lg font-black text-white bg-orange-600 hover:bg-orange-700 disabled:opacity-50 transition transform hover:scale-105">
                    {isSaving ? $t('common.saving') : $t('actions.save')}
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    :global(.font-sans) {
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
    
    /* RTL Adjustments for Select Arrows */
    :global([dir="rtl"] select) {
        background-position: left 0.75rem center !important;
        padding-left: 2.5rem !important;
        padding-right: 0.75rem !important;
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
