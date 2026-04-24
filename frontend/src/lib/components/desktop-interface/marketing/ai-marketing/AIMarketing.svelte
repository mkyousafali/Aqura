<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import AIMarketingSettings from './AIMarketingSettings.svelte';
    import AIMarketingBrandLibraries from './AIMarketingBrandLibraries.svelte';
    import AIMarketingDashboard from './AIMarketingDashboard.svelte';
    import AIMarketingCreateImage from './AIMarketingCreateImage.svelte';
    import AIMarketingCreateVision from './AIMarketingCreateVision.svelte';

    type TabId = 'dashboard' | 'settings' | 'brand-libraries' | 'create-image' | 'create-vision' | 'library';

    interface Tab { id: TabId; label: { ar: string; en: string }; icon: string; color: 'green' | 'orange' }

    const tabs: Tab[] = [
        { id: 'dashboard',       label: { ar: 'لوحة التحكم',    en: 'Dashboard'       }, icon: '📊', color: 'green'  },
        { id: 'settings',        label: { ar: 'الإعدادات',       en: 'Settings'        }, icon: '⚙️', color: 'green'  },
        { id: 'brand-libraries', label: { ar: 'الهويات',         en: 'Brand Libraries' }, icon: '🎨', color: 'green'  },
        { id: 'create-image',    label: { ar: 'إنشاء صورة',     en: 'Create Image'    }, icon: '🖼️', color: 'orange' },
        { id: 'create-vision',   label: { ar: 'إنشاء رؤية',     en: 'Create Vision'   }, icon: '🎬', color: 'orange' },
        { id: 'library',         label: { ar: 'المكتبة',          en: 'Library'         }, icon: '📚', color: 'green'  },
    ];

    let activeTab: TabId = 'create-image';
    $: activeTabMeta = tabs.find((x) => x.id === activeTab);

    function onSwitchTab(e: Event) {
        const tab = (e as CustomEvent<string>).detail as TabId;
        if (tabs.some(t => t.id === tab)) activeTab = tab;
    }

    onMount(() => { document.addEventListener('switchtab', onSwitchTab); });
    onDestroy(() => { document.removeEventListener('switchtab', onSwitchTab); });
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header / Tab Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm">
        <div class="flex flex-wrap gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
            {#each tabs as tab}
                <button
                    class="group relative flex items-center gap-2.5 px-5 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
                    {activeTab === tab.id
                        ? (tab.color === 'green'
                            ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
                            : 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]')
                        : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
                    on:click={() => (activeTab = tab.id)}
                >
                    <span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
                    <span class="relative z-10">{$locale === 'ar' ? tab.label.ar : tab.label.en}</span>
                    {#if activeTab === tab.id}
                        <div class="absolute inset-0 bg-white/10 animate-pulse"></div>
                    {/if}
                </button>
            {/each}
        </div>
    </div>

    <!-- Main Content Area -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Decorative blur orbs (matches ShiftAndDayOff) -->
        <div class="absolute top-0 {$locale === 'ar' ? 'left-0 -ml-64' : 'right-0 -mr-64'} w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 {$locale === 'ar' ? 'right-0 -mr-64' : 'left-0 -ml-64'} w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col">
            {#if activeTab === 'dashboard'}
                <AIMarketingDashboard />
            {:else if activeTab === 'settings'}
                <AIMarketingSettings />
            {:else if activeTab === 'brand-libraries'}
                <AIMarketingBrandLibraries />
            {:else if activeTab === 'create-image'}
                <AIMarketingCreateImage />
            {:else if activeTab === 'create-vision'}
                <AIMarketingCreateVision />
            {:else}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border-2 border-dashed border-slate-200 shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center">
                    <div class="text-6xl mb-4 filter drop-shadow-md">{activeTabMeta?.icon ?? ''}</div>
                    <h2 class="text-2xl font-black text-slate-700 mb-2 tracking-tight">
                        {activeTabMeta ? ($locale === 'ar' ? activeTabMeta.label.ar : activeTabMeta.label.en) : ''}
                    </h2>
                    <p class="text-sm text-slate-500 font-semibold">
                        {$locale === 'ar' ? 'هذا القسم قيد الإنشاء' : 'This section is under construction'}
                    </p>
                </div>
            {/if}
        </div>
    </div>
</div>
