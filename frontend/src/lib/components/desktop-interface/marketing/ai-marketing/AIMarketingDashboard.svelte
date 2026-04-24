<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';

    let supabase: any = null;

    // ── Stats ──────────────────────────────────────────────────────
    let statsLoading = true;
    let stats = {
        videosToday:    0,
        postersToday:   0,
        videosMonth:    0,
        postersMonth:   0,
        queuePending:   0,
        totalFiles:     0,
        brands:         0
    };

    // ── Recent files ───────────────────────────────────────────────
    let recentFiles: any[] = [];
    let recentLoading = true;
    let recentSignedUrls: Record<number, string> = {};

    // ── Most used brands ──────────────────────────────────────────
    let topBrands: any[] = [];

    // ── Queue items ───────────────────────────────────────────────
    let queueItems: any[] = [];
    let queueLoading = true;

    $: isMasterAdmin = $currentUser?.isMasterAdmin;

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await Promise.all([loadStats(), loadRecentFiles(), loadQueue()]);
    });

    async function loadStats() {
        statsLoading = true;
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
        const todayIso  = today.toISOString();
        const monthIso  = monthStart.toISOString();

        const [
            { count: vToday },
            { count: pToday },
            { count: vMonth },
            { count: pMonth },
            { count: queued },
            { count: totalF },
            { count: brandsC }
        ] = await Promise.all([
            supabase.from('ai_marketing_files').select('id', { count: 'exact', head: true }).eq('file_type', 'video').gte('created_at', todayIso),
            supabase.from('ai_marketing_files').select('id', { count: 'exact', head: true }).eq('file_type', 'poster').gte('created_at', todayIso),
            supabase.from('ai_marketing_files').select('id', { count: 'exact', head: true }).eq('file_type', 'video').gte('created_at', monthIso),
            supabase.from('ai_marketing_files').select('id', { count: 'exact', head: true }).eq('file_type', 'poster').gte('created_at', monthIso),
            supabase.from('ai_generation_queue').select('id', { count: 'exact', head: true }).in('status', ['pending', 'processing']),
            supabase.from('ai_marketing_files').select('id', { count: 'exact', head: true }),
            supabase.from('ai_brand_libraries').select('id', { count: 'exact', head: true }).eq('is_archived', false)
        ]);

        stats = {
            videosToday:  vToday  || 0,
            postersToday: pToday  || 0,
            videosMonth:  vMonth  || 0,
            postersMonth: pMonth  || 0,
            queuePending: queued  || 0,
            totalFiles:   totalF  || 0,
            brands:       brandsC || 0
        };
        statsLoading = false;

        // Top brands by file count
        const { data: brandData } = await supabase
            .from('ai_marketing_files')
            .select('brand_id, ai_brand_libraries(name, primary_color)')
            .not('brand_id', 'is', null)
            .limit(200);

        if (brandData) {
            const counts: Record<number, { name: string; color: string; count: number }> = {};
            for (const row of brandData) {
                const bid = row.brand_id;
                if (!counts[bid]) counts[bid] = { name: row.ai_brand_libraries?.name || '—', color: row.ai_brand_libraries?.primary_color || '#059669', count: 0 };
                counts[bid].count++;
            }
            topBrands = Object.values(counts).sort((a, b) => b.count - a.count).slice(0, 3);
        }
    }

    async function loadRecentFiles() {
        recentLoading = true;
        const { data } = await supabase
            .from('ai_marketing_files')
            .select('id, title, file_type, thumbnail_url, storage_path, created_at, ai_brand_libraries(name, primary_color)')
            .order('created_at', { ascending: false })
            .limit(6);

        if (data) {
            recentFiles = data;
            // Sign thumbnail URLs
            const urls: Record<number, string> = {};
            await Promise.all(
                data
                    .filter((f: any) => f.thumbnail_url && !f.thumbnail_url.startsWith('http'))
                    .map(async (f: any) => {
                        const { data: sd } = await supabase.storage
                            .from('ai-marketing-files')
                            .createSignedUrl(f.thumbnail_url, 3600);
                        if (sd?.signedUrl) urls[f.id] = sd.signedUrl;
                    })
            );
            // Also sign storage_path for items with no separate thumbnail
            await Promise.all(
                data
                    .filter((f: any) => !f.thumbnail_url && f.storage_path && !f.storage_path.startsWith('http'))
                    .map(async (f: any) => {
                        const { data: sd } = await supabase.storage
                            .from('ai-marketing-files')
                            .createSignedUrl(f.storage_path, 3600);
                        if (sd?.signedUrl) urls[f.id] = sd.signedUrl;
                    })
            );
            recentSignedUrls = urls;
        }
        recentLoading = false;
    }

    async function loadQueue() {
        queueLoading = true;
        const { data } = await supabase
            .from('ai_generation_queue')
            .select('id, job_type, status, created_at, ai_brand_libraries(name)')
            .in('status', ['pending', 'processing'])
            .order('created_at', { ascending: true })
            .limit(5);
        queueItems = data || [];
        queueLoading = false;
    }

    function formatDate(iso: string) {
        if (!iso) return '';
        const d = new Date(iso);
        return d.toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
    }

    async function refreshAll() {
        await Promise.all([loadStats(), loadRecentFiles(), loadQueue()]);
    }

    const statCards = [
        { keyEn: 'Videos Today',   keyAr: 'فيديو اليوم',    icon: '🎬', statKey: 'videosToday',  color: 'emerald' },
        { keyEn: 'Posters Today',  keyAr: 'ملصق اليوم',     icon: '🖼️', statKey: 'postersToday', color: 'orange'  },
        { keyEn: 'Videos/Month',   keyAr: 'فيديو/شهر',      icon: '📹', statKey: 'videosMonth',  color: 'blue'    },
        { keyEn: 'Posters/Month',  keyAr: 'ملصق/شهر',       icon: '🪧', statKey: 'postersMonth', color: 'purple'  },
        { keyEn: 'In Queue',       keyAr: 'في الطابور',      icon: '⏳', statKey: 'queuePending', color: 'amber'   },
        { keyEn: 'Total Files',    keyAr: 'إجمالي الملفات', icon: '📚', statKey: 'totalFiles',   color: 'teal'    },
        { keyEn: 'Active Brands',  keyAr: 'علامات نشطة',    icon: '🎨', statKey: 'brands',       color: 'rose'    }
    ] as const;

    type StatColor = typeof statCards[number]['color'];

    const colorMap: Record<StatColor, { bg: string; text: string; badge: string }> = {
        emerald: { bg: 'bg-emerald-50',  text: 'text-emerald-700', badge: 'bg-emerald-100' },
        orange:  { bg: 'bg-orange-50',   text: 'text-orange-700',  badge: 'bg-orange-100'  },
        blue:    { bg: 'bg-blue-50',     text: 'text-blue-700',    badge: 'bg-blue-100'    },
        purple:  { bg: 'bg-purple-50',   text: 'text-purple-700',  badge: 'bg-purple-100'  },
        amber:   { bg: 'bg-amber-50',    text: 'text-amber-700',   badge: 'bg-amber-100'   },
        teal:    { bg: 'bg-teal-50',     text: 'text-teal-700',    badge: 'bg-teal-100'    },
        rose:    { bg: 'bg-rose-50',     text: 'text-rose-700',    badge: 'bg-rose-100'    }
    };
</script>

<div class="w-full space-y-6" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>

    <!-- ── Header row ─────────────────────────────────────── -->
    <div class="flex items-center justify-between">
        <div>
            <h2 class="text-2xl font-black text-slate-800 tracking-tight">
                {$locale === 'ar' ? '📊 لوحة التحكم' : '📊 Dashboard'}
            </h2>
            <p class="text-xs font-semibold text-slate-500 mt-0.5">
                {$locale === 'ar' ? 'نظرة عامة على التسويق بالذكاء الاصطناعي' : 'AI Marketing at a glance'}
            </p>
        </div>
        <button
            on:click={refreshAll}
            class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-black bg-white border border-slate-200
                   text-slate-600 hover:bg-emerald-50 hover:border-emerald-300 hover:text-emerald-700 transition-all shadow-sm"
        >
            🔄 {$locale === 'ar' ? 'تحديث' : 'Refresh'}
        </button>
    </div>

    <!-- ── Stat cards ──────────────────────────────────────── -->
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7 gap-3">
        {#each statCards as card}
            {@const colors = colorMap[card.color]}
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 flex flex-col gap-2">
                <div class="flex items-center justify-between">
                    <span class="text-xl">{card.icon}</span>
                    <span class="px-2 py-0.5 rounded-full text-[10px] font-black {colors.badge} {colors.text} uppercase">
                        {$locale === 'ar' ? 'AI' : 'AI'}
                    </span>
                </div>
                {#if statsLoading}
                    <div class="h-8 bg-slate-100 rounded-lg animate-pulse"></div>
                {:else}
                    <div class="text-3xl font-black {colors.text}">{stats[card.statKey]}</div>
                {/if}
                <div class="text-[10px] font-bold text-slate-500 uppercase tracking-wide leading-tight">
                    {$locale === 'ar' ? card.keyAr : card.keyEn}
                </div>
            </div>
        {/each}
    </div>

    <!-- ── Middle row: Recent + Queue + Top Brands ─────────── -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">

        <!-- Recent files (spans 2 cols) -->
        <div class="lg:col-span-2 bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-5">
            <div class="flex items-center justify-between mb-4">
                <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide">
                    {$locale === 'ar' ? '🕒 آخر الإنشاءات' : '🕒 Recent Creations'}
                </h3>
                <span class="text-[10px] font-bold text-slate-400 uppercase">
                    {$locale === 'ar' ? 'آخر 6' : 'Latest 6'}
                </span>
            </div>

            {#if recentLoading}
                <div class="grid grid-cols-3 gap-3">
                    {#each [1,2,3,4,5,6] as _}
                        <div class="aspect-video bg-slate-100 rounded-2xl animate-pulse"></div>
                    {/each}
                </div>
            {:else if recentFiles.length === 0}
                <div class="flex flex-col items-center justify-center py-10 text-slate-400">
                    <span class="text-4xl mb-2">🎬</span>
                    <p class="text-sm font-semibold">
                        {$locale === 'ar' ? 'لا توجد ملفات بعد' : 'No files generated yet'}
                    </p>
                    <p class="text-xs mt-1 text-slate-300">
                        {$locale === 'ar' ? 'ابدأ بإنشاء فيديو أو ملصق' : 'Start by creating a video or poster'}
                    </p>
                </div>
            {:else}
                <div class="grid grid-cols-3 gap-3">
                    {#each recentFiles as file (file.id)}
                        {@const thumbUrl = recentSignedUrls[file.id]}
                        <div class="group relative rounded-2xl overflow-hidden bg-slate-100 aspect-video shadow-sm hover:shadow-md transition-shadow cursor-default">
                            {#if thumbUrl}
                                <img src={thumbUrl} alt={file.title || ''} class="w-full h-full object-cover" />
                            {:else}
                                <div class="w-full h-full flex items-center justify-center bg-gradient-to-br
                                            {file.file_type === 'video' ? 'from-emerald-100 to-teal-100' : 'from-orange-100 to-amber-100'}">
                                    <span class="text-3xl">{file.file_type === 'video' ? '🎬' : '🖼️'}</span>
                                </div>
                            {/if}
                            <!-- Hover overlay -->
                            <div class="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-end p-2">
                                <p class="text-white text-[10px] font-black line-clamp-1">{file.title || (file.file_type === 'video' ? 'Video' : 'Poster')}</p>
                                <p class="text-white/70 text-[9px] font-semibold">{formatDate(file.created_at)}</p>
                                {#if file.ai_brand_libraries?.name}
                                    <span class="mt-1 inline-block px-1.5 py-0.5 rounded-full text-[8px] font-black text-white"
                                          style="background: {file.ai_brand_libraries.primary_color || '#059669'}">
                                        {file.ai_brand_libraries.name}
                                    </span>
                                {/if}
                            </div>
                            <!-- Type badge -->
                            <div class="absolute top-1.5 {$locale === 'ar' ? 'left-1.5' : 'right-1.5'}">
                                <span class="px-1.5 py-0.5 rounded-lg text-[8px] font-black uppercase
                                             {file.file_type === 'video' ? 'bg-emerald-600 text-white' : 'bg-orange-600 text-white'}">
                                    {file.file_type}
                                </span>
                            </div>
                        </div>
                    {/each}
                </div>
            {/if}
        </div>

        <!-- Right column: Queue + Top Brands -->
        <div class="flex flex-col gap-4">

            <!-- Active Queue -->
            <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-5 flex-1">
                <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide mb-3">
                    ⏳ {$locale === 'ar' ? 'طابور الإنشاء' : 'Generation Queue'}
                </h3>
                {#if queueLoading}
                    <div class="space-y-2">
                        {#each [1,2] as _}
                            <div class="h-10 bg-slate-100 rounded-xl animate-pulse"></div>
                        {/each}
                    </div>
                {:else if queueItems.length === 0}
                    <div class="flex flex-col items-center justify-center py-6 text-slate-300">
                        <span class="text-3xl mb-1">✅</span>
                        <p class="text-xs font-semibold text-slate-400">
                            {$locale === 'ar' ? 'الطابور فارغ' : 'Queue is empty'}
                        </p>
                    </div>
                {:else}
                    <div class="space-y-2">
                        {#each queueItems as item (item.id)}
                            <div class="flex items-center gap-2 px-3 py-2 rounded-xl bg-amber-50 border border-amber-100">
                                <span class="text-sm">{item.job_type === 'video' ? '🎬' : '🖼️'}</span>
                                <div class="flex-1 min-w-0">
                                    <div class="text-xs font-black text-slate-700 truncate">
                                        {item.ai_brand_libraries?.name || '—'}
                                    </div>
                                    <div class="text-[10px] font-semibold text-amber-600 capitalize">{item.status}</div>
                                </div>
                                <div class="w-2 h-2 rounded-full bg-amber-400 animate-pulse flex-shrink-0"></div>
                            </div>
                        {/each}
                    </div>
                {/if}
            </div>

            <!-- Top Brands -->
            <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-5">
                <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide mb-3">
                    🏆 {$locale === 'ar' ? 'أكثر العلامات استخداماً' : 'Most Used Brands'}
                </h3>
                {#if statsLoading}
                    <div class="space-y-2">
                        {#each [1,2,3] as _}
                            <div class="h-8 bg-slate-100 rounded-xl animate-pulse"></div>
                        {/each}
                    </div>
                {:else if topBrands.length === 0}
                    <div class="text-center py-4 text-xs font-semibold text-slate-400">
                        {$locale === 'ar' ? 'لا توجد بيانات بعد' : 'No data yet'}
                    </div>
                {:else}
                    <div class="space-y-2">
                        {#each topBrands as b, i}
                            <div class="flex items-center gap-2">
                                <span class="text-sm font-black text-slate-400 w-4">{i + 1}</span>
                                <div class="w-3 h-3 rounded-full flex-shrink-0" style="background:{b.color}"></div>
                                <span class="flex-1 text-xs font-black text-slate-700 truncate">{b.name}</span>
                                <span class="px-2 py-0.5 rounded-full text-[10px] font-black bg-slate-100 text-slate-600">{b.count}</span>
                            </div>
                        {/each}
                    </div>
                {/if}
            </div>
        </div>
    </div>

    <!-- ── Quick Actions ───────────────────────────────────── -->
    <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-5">
        <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide mb-4">
            ⚡ {$locale === 'ar' ? 'إجراءات سريعة' : 'Quick Actions'}
        </h3>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {#each [
                { icon: '🎬', en: 'Create Video',  ar: 'إنشاء فيديو',   color: 'emerald', tab: 'create-video'     },
                { icon: '🖼️', en: 'Create Poster', ar: 'إنشاء ملصق',   color: 'orange',  tab: 'create-poster'    },
                { icon: '🎨', en: 'Brand Libraries',ar: 'مكتبات العلامات', color: 'blue', tab: 'brand-libraries' },
                { icon: '📚', en: 'Library',        ar: 'المكتبة',       color: 'purple',  tab: 'library'         }
            ] as action}
                <button
                    on:click={() => {
                        // Dispatch event so parent AIMarketing can switch tab
                        const event = new CustomEvent('switchtab', { detail: action.tab, bubbles: true });
                        document.dispatchEvent(event);
                    }}
                    class="flex flex-col items-center gap-2 p-4 rounded-2xl border-2 border-dashed transition-all
                           {action.color === 'emerald' ? 'border-emerald-200 hover:bg-emerald-50 hover:border-emerald-400' :
                            action.color === 'orange'  ? 'border-orange-200  hover:bg-orange-50  hover:border-orange-400'  :
                            action.color === 'blue'    ? 'border-blue-200    hover:bg-blue-50    hover:border-blue-400'    :
                                                         'border-purple-200  hover:bg-purple-50  hover:border-purple-400'}"
                >
                    <span class="text-3xl">{action.icon}</span>
                    <span class="text-xs font-black text-slate-600 text-center leading-tight">
                        {$locale === 'ar' ? action.ar : action.en}
                    </span>
                </button>
            {/each}
        </div>
    </div>
</div>
