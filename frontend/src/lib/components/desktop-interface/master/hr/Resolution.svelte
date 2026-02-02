<script lang="ts">
    import { t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    import { onMount } from 'svelte';
    
    export let incident: any = null;
    export let viewMode: boolean = false;
    export let onResolved: (() => void) | null = null;
    
    let resolutionReport = '';
    let isSaving = false;
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

    // Load existing resolution report if any
    onMount(() => {
        if (incident?.resolution_report) {
            const report = incident.resolution_report;
            resolutionReport = typeof report === 'string' 
                ? report 
                : report.content || '';
        }
    });

    async function transformReport() {
        if (!resolutionReport.trim()) {
            alert($locale === 'ar' ? 'يرجى إدخال تقرير الحل أولاً' : 'Please enter resolution report first');
            return;
        }

        isTransforming = true;
        try {
            const response = await fetch('/api/transform-text', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    text: resolutionReport,
                    language: selectedLanguage,
                    type: 'resolution'
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to transform text');
            }

            const data = await response.json();
            resolutionReport = data.transformedText || resolutionReport;
            
        } catch (err) {
            console.error('Error transforming text:', err);
            alert($locale === 'ar' 
                ? `خطأ في تحويل النص: ${err instanceof Error ? err.message : 'فشل التحويل'}` 
                : `Error transforming text: ${err instanceof Error ? err.message : 'Transform failed'}`);
        } finally {
            isTransforming = false;
        }
    }

    async function handleResolveIncident() {
        if (!resolutionReport.trim()) {
            alert($locale === 'ar' ? 'الرجاء إدخال تقرير الحل' : 'Please enter resolution report');
            return;
        }
        
        if (!incident?.id) {
            alert($locale === 'ar' ? 'خطأ: لا توجد حادثة محددة' : 'Error: No incident selected');
            return;
        }
        
        isSaving = true;
        try {
            const { supabase } = await import('$lib/utils/supabase');
            
            const resolutionData = {
                content: resolutionReport,
                resolved_by: $currentUser?.id,
                resolved_by_name: ($currentUser as any)?.name || $currentUser?.email,
                resolved_at: new Date().toISOString()
            };
            
            // Update incident with resolution report and status
            const { error } = await supabase
                .from('incidents')
                .update({
                    resolution_report: resolutionData,
                    resolution_status: 'resolved',
                    updated_by: $currentUser?.id
                })
                .eq('id', incident.id);
            
            if (error) throw error;
            
            alert($locale === 'ar' ? '✅ تم حل الحادثة بنجاح' : '✅ Incident resolved successfully');
            
            // Call callback to refresh incident list
            if (onResolved) {
                onResolved();
            }
            
        } catch (err) {
            console.error('Error resolving incident:', err);
            alert($locale === 'ar' ? 'خطأ في حل الحادثة' : 'Error resolving incident');
        } finally {
            isSaving = false;
        }
    }
</script>

<div class="h-full flex flex-col bg-gradient-to-br from-purple-50 to-slate-50 font-sans">
    <div class="p-6 space-y-4 overflow-y-auto flex-1">
        <!-- Header -->
        <div class="flex items-center gap-3 pb-4 border-b border-slate-200">
            <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center">
                <span class="text-xl">✅</span>
            </div>
            <div>
                <h2 class="text-lg font-bold text-slate-800">
                    {viewMode 
                        ? ($locale === 'ar' ? 'عرض تقرير الحل' : 'View Resolution Report')
                        : ($locale === 'ar' ? 'حل الحادثة' : 'Resolve Incident')}
                </h2>
                <p class="text-sm text-slate-500">
                    {$locale === 'ar' ? `حادثة رقم: ${incident?.id}` : `Incident ID: ${incident?.id}`}
                </p>
            </div>
        </div>

        <!-- Incident Summary -->
        {#if incident}
            <div class="bg-slate-100 rounded-lg p-4 space-y-2">
                <div class="flex items-center gap-2">
                    <span class="text-xs font-bold text-slate-500 uppercase">{$locale === 'ar' ? 'نوع الحادثة' : 'Incident Type'}:</span>
                    <span class="text-sm text-slate-700">{$locale === 'ar' ? incident.incident_types?.incident_type_ar : incident.incident_types?.incident_type_en}</span>
                </div>
                {#if incident.employeeName && incident.employeeName !== 'Unknown'}
                    <div class="flex items-center gap-2">
                        <span class="text-xs font-bold text-slate-500 uppercase">{$locale === 'ar' ? 'الموظف' : 'Employee'}:</span>
                        <span class="text-sm text-slate-700">{incident.employeeName}</span>
                    </div>
                {/if}
                {#if incident.branchName}
                    <div class="flex items-center gap-2">
                        <span class="text-xs font-bold text-slate-500 uppercase">{$locale === 'ar' ? 'الفرع' : 'Branch'}:</span>
                        <span class="text-sm text-slate-700">{incident.branchName}</span>
                    </div>
                {/if}
                {#if incident.warning_violation}
                    <div class="flex items-center gap-2">
                        <span class="text-xs font-bold text-slate-500 uppercase">{$locale === 'ar' ? 'المخالفة' : 'Violation'}:</span>
                        <span class="text-sm text-slate-700">{$locale === 'ar' ? incident.warning_violation.name_ar : incident.warning_violation.name_en}</span>
                    </div>
                {/if}
            </div>
        {/if}

        <!-- Investigation Report (Read-only) -->
        {#if incident?.investigation_report}
            <div>
                <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'تقرير التحقيق' : 'Investigation Report'}</label>
                <div class="bg-indigo-50 border border-indigo-200 rounded-lg p-3 text-sm text-slate-700 max-h-32 overflow-y-auto whitespace-pre-wrap">
                    {typeof incident.investigation_report === 'string' ? incident.investigation_report : incident.investigation_report.content || ''}
                </div>
            </div>
        {/if}

        <!-- Language Selection for Transform -->
        {#if !viewMode}
            <div>
                <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'لغة التحويل' : 'Transform Language'}</label>
                <div class="flex flex-wrap gap-2">
                    {#each availableLanguages as lang}
                        <button
                            type="button"
                            on:click={() => selectedLanguage = lang.code}
                            class="px-3 py-1 text-xs rounded-full transition {selectedLanguage === lang.code ? 'bg-purple-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                        >
                            {$locale === 'ar' ? lang.nameAr : lang.name}
                        </button>
                    {/each}
                </div>
            </div>
        {/if}

        <!-- Resolution Report -->
        <div>
            <label for="resolution-report" class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'تقرير الحل *' : 'Resolution Report *'}</label>
            <textarea 
                id="resolution-report"
                bind:value={resolutionReport}
                placeholder={$locale === 'ar' ? 'أدخل تقرير الحل وكيف تم حل المشكلة...' : 'Enter resolution report and how the issue was resolved...'}
                rows={Math.max(8, resolutionReport.split('\n').length + 2)}
                readonly={viewMode}
                class="w-full px-3 py-2 border border-slate-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 outline-none text-sm hover:border-slate-300 transition resize-y min-h-[200px] max-h-[500px] {viewMode ? 'bg-slate-50 cursor-default' : ''}"
            ></textarea>
        </div>

        <!-- Action Buttons -->
        <div class="flex justify-end gap-3 pt-4 border-t border-slate-200">
            {#if !viewMode}
                <button 
                    type="button"
                    on:click={transformReport}
                    disabled={isTransforming || !resolutionReport.trim()}
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
                <button 
                    type="button"
                    on:click={handleResolveIncident}
                    disabled={isSaving || !resolutionReport.trim()}
                    class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition disabled:bg-gray-400 disabled:cursor-not-allowed font-semibold text-sm flex items-center gap-2"
                >
                    {#if isSaving}
                        <span class="animate-spin">⏳</span>
                        {$locale === 'ar' ? 'جاري الحل...' : 'Resolving...'}
                    {:else}
                        <span>✅</span>
                        {$locale === 'ar' ? 'حل وإغلاق الحادثة' : 'Resolve & Close Incident'}
                    {/if}
                </button>
            {/if}
        </div>
    </div>
</div>
