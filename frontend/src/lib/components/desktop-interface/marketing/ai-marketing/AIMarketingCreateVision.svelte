<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';

    let supabase: any = null;

    // ── Brand ────────────────────────────────────────────────────────────
    let brands: any[] = [];
    let selectedBrandId: number | null = null;
    $: selectedBrand = brands.find(b => b.id === selectedBrandId) || null;

    // ── Characters ────────────────────────────────────────────────────────
    let characters: any[] = [];
    let selectedCharacterIds: Set<number> = new Set();
    let charSignedUrls: Record<number, string> = {};

    async function loadCharacters(brandId: number | null) {
        characters = []; selectedCharacterIds = new Set(); charSignedUrls = {};
        if (!brandId || !supabase) return;
        const { data } = await supabase
            .from('ai_brand_characters')
            .select('id, name, role, description, image_url')
            .eq('brand_id', brandId)
            .order('display_order', { ascending: true });
        characters = data || [];
        for (const c of characters) {
            if (c.image_url && !c.image_url.startsWith('http') && !c.image_url.startsWith('blob:')) {
                const { data: s } = await supabase.storage.from('ai-marketing-files').createSignedUrl(c.image_url, 300);
                if (s?.signedUrl) charSignedUrls[c.id] = s.signedUrl;
            } else if (c.image_url) {
                charSignedUrls[c.id] = c.image_url;
            }
        }
        charSignedUrls = { ...charSignedUrls };
    }

    function toggleCharacter(id: number) {
        const s = new Set(selectedCharacterIds);
        s.has(id) ? s.delete(id) : s.add(id);
        selectedCharacterIds = s;
    }

    $: selectedCharacters = characters.filter(c => selectedCharacterIds.has(c.id));
    $: if (supabase && selectedBrandId !== undefined) loadCharacters(selectedBrandId);

    // ── Platform ──────────────────────────────────────────────────────────
    const platforms = [
        { id: 'instagram_story', icon: '📱', en: 'Insta Story',     ar: 'قصة إنستغرام',   ratio: '9:16' },
        { id: 'tiktok',          icon: '🎵', en: 'TikTok',          ar: 'تيك توك',         ratio: '9:16' },
        { id: 'whatsapp',        icon: '💬', en: 'WhatsApp Status', ar: 'واتساب',          ratio: '9:16' },
        { id: 'instagram_feed',  icon: '📸', en: 'Instagram Feed',  ar: 'إنستغرام',        ratio: '1:1'  },
        { id: 'facebook',        icon: '👤', en: 'Facebook',        ar: 'فيسبوك',          ratio: '16:9' },
        { id: 'twitter',         icon: '🐦', en: 'Twitter / X',     ar: 'تويتر',           ratio: '16:9' },
    ];
    let selectedPlatformId = 'instagram_story';
    $: selectedPlatform = platforms.find(p => p.id === selectedPlatformId) || platforms[0];
    $: aspectRatio = selectedPlatform.ratio;

    // ── Language ──────────────────────────────────────────────────────────
    let language: 'ar' | 'en' = 'ar';

    // ── Duration ──────────────────────────────────────────────────────────
    let durationSeconds = 8;

    // ── Prompt ────────────────────────────────────────────────────────────
    let prompt = '';

    // ── State ─────────────────────────────────────────────────────────────
    let generating = false;
    let errorMessage = '';
    let generatedUrl: string | null = null;
    let generatedPrompt: string | null = null;    let logoUrl: string | null = null;    let elapsedSeconds = 0;
    let elapsedTimer: ReturnType<typeof setInterval> | null = null;

    $: userId = $currentUser?.id;

    $: previewAspect = ({
        '1:1': 'aspect-square', '9:16': 'aspect-[9/16]', '16:9': 'aspect-video'
    } as Record<string, string>)[aspectRatio] || 'aspect-[9/16]';

    // ── History ───────────────────────────────────────────────────────────
    let history: Array<{ url: string; prompt: string }> = [];

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        const { data } = await supabase
            .from('ai_brand_libraries')
            .select('id, name, primary_color, accent_color, is_default')
            .eq('is_archived', false)
            .order('is_default', { ascending: false });
        brands = data || [];
        const def = brands.find((b: any) => b.is_default);
        if (def) selectedBrandId = def.id;
        else if (brands.length) selectedBrandId = brands[0].id;
    });

    async function generate() {
        if (generating || !prompt.trim()) return;
        generating = true; errorMessage = ''; generatedUrl = null; generatedPrompt = null; logoUrl = null;
        elapsedSeconds = 0;
        elapsedTimer = setInterval(() => { elapsedSeconds++; }, 1000);
        try {
            const res = await fetch('/api/ai-marketing/generate-video', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    brandId:         selectedBrandId,
                    platform:        selectedPlatformId,
                    aspectRatio,
                    language,
                    extraPrompt:     prompt.trim(),
                    characters:      selectedCharacters.map(c => ({ name: c.name, role: c.role, description: c.description })),
                    durationSeconds,
                    userId
                })
            });
            const data = await res.json();
            if (!data.ok) {
                errorMessage = `[${data.stage ?? 'error'}] ${data.message}`;
                if (data.videoPrompt) generatedPrompt = data.videoPrompt;
                return;
            }
            generatedUrl    = data.signedUrl;
            generatedPrompt = data.videoPrompt;
            logoUrl         = data.logoSignedUrl ?? null;
            history = [{ url: data.signedUrl, prompt: prompt.trim() }, ...history].slice(0, 5);
        } catch (err: any) {
            errorMessage = err?.message ?? String(err);
        } finally {
            generating = false;
            if (elapsedTimer) { clearInterval(elapsedTimer); elapsedTimer = null; }
        }
    }

    async function downloadVideo() {
        if (!generatedUrl) return;
        const a = document.createElement('a');
        a.href = generatedUrl; a.download = `video-${Date.now()}.mp4`; a.click();
    }
</script>

<div class="w-full" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <div class="grid grid-cols-1 xl:grid-cols-[380px_1fr] gap-6">

        <!-- ══ LEFT — Controls ══════════════════════════════════════════════ -->
        <div class="space-y-4">

            <div>
                <h2 class="text-xl font-black text-slate-800 tracking-tight">🎬 {$locale === 'ar' ? 'إنشاء فيديو' : 'Create Vision'}</h2>
                <p class="text-xs font-semibold text-slate-500 mt-0.5">{$locale === 'ar' ? 'أنشئ مقطع فيديو تسويقياً بالذكاء الاصطناعي' : 'AI-generated marketing video with your branding'}</p>
            </div>

            <!-- Brand -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-2">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">🎨 {$locale === 'ar' ? 'الهوية التجارية' : 'Branding Profile'}</label>
                <select bind:value={selectedBrandId}
                    class="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-orange-500"
                    style="color:#000 !important;">
                    <option value={null}>{$locale === 'ar' ? '— اختر هوية —' : '— Select Profile —'}</option>
                    {#each brands as b}
                        <option value={b.id} style="color:#000 !important;">{b.name}{b.is_default ? ' ⭐' : ''}</option>
                    {/each}
                </select>
                {#if selectedBrand}
                    <div class="flex items-center gap-2 mt-1">
                        <div class="w-4 h-4 rounded-full border-2 border-white shadow-sm" style="background:{selectedBrand.primary_color}"></div>
                        <div class="w-4 h-4 rounded-full border-2 border-white shadow-sm" style="background:{selectedBrand.accent_color}"></div>
                        <span class="text-[10px] font-bold text-slate-400">{selectedBrand.name}</span>
                    </div>
                {/if}
            </div>

            <!-- Characters -->
            {#if characters.length > 0}
                <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-3">
                    <div class="flex items-center justify-between">
                        <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">👤 {$locale === 'ar' ? 'الشخصيات' : 'Characters'}</label>
                        {#if selectedCharacterIds.size > 0}
                            <button on:click={() => (selectedCharacterIds = new Set())}
                                class="text-[9px] font-black text-slate-400 hover:text-red-500 transition-colors uppercase tracking-wider">
                                {$locale === 'ar' ? 'إلغاء الكل' : 'Clear all'}
                            </button>
                        {/if}
                    </div>
                    <div class="grid grid-cols-2 gap-2">
                        {#each characters as char}
                            {@const isSelected = selectedCharacterIds.has(char.id)}
                            <button on:click={() => toggleCharacter(char.id)}
                                class="flex items-center gap-2.5 p-2.5 rounded-xl border-2 transition-all text-left
                                       {isSelected ? 'border-orange-500 bg-orange-50' : 'border-slate-200 bg-white hover:border-orange-300'}">
                                <div class="relative flex-shrink-0 w-10 h-10 rounded-lg overflow-hidden bg-slate-100 border border-slate-200">
                                    {#if charSignedUrls[char.id]}
                                        <img src={charSignedUrls[char.id]} alt={char.name} class="w-full h-full object-cover"/>
                                    {:else}
                                        <div class="w-full h-full flex items-center justify-center text-xl">🧑</div>
                                    {/if}
                                    {#if isSelected}
                                        <div class="absolute inset-0 flex items-center justify-center bg-orange-600/70 rounded-lg">
                                            <span class="text-white text-sm font-black">✓</span>
                                        </div>
                                    {/if}
                                </div>
                                <div class="min-w-0 flex-1">
                                    <p class="text-xs font-black text-slate-700 truncate leading-tight">{char.name}</p>
                                    {#if char.role}<p class="text-[9px] font-bold text-slate-400 truncate">{char.role}</p>{/if}
                                    {#if char.description}<p class="text-[9px] text-slate-400 leading-snug line-clamp-2 mt-0.5">{char.description}</p>{/if}
                                </div>
                            </button>
                        {/each}
                    </div>
                    {#if selectedCharacterIds.size > 0}
                        <p class="text-[9px] font-black text-orange-600 bg-orange-50 rounded-lg px-2 py-1.5">
                            ✓ {$locale === 'ar' ? `${selectedCharacterIds.size} شخصية محددة` : `${selectedCharacterIds.size} character(s) selected`}
                        </p>
                    {/if}
                </div>
            {/if}

            <!-- Language -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-2">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">🌐 {$locale === 'ar' ? 'لغة الفيديو' : 'Video Language'}</label>
                <div class="flex gap-2">
                    <button on:click={() => (language = 'ar')}
                        class="flex-1 py-2 rounded-xl text-xs font-black border-2 transition-all {language === 'ar' ? 'border-orange-500 bg-orange-50 text-orange-700' : 'border-slate-200 text-slate-500 hover:border-slate-300'}">
                        🇸🇦 عربي</button>
                    <button on:click={() => (language = 'en')}
                        class="flex-1 py-2 rounded-xl text-xs font-black border-2 transition-all {language === 'en' ? 'border-orange-500 bg-orange-50 text-orange-700' : 'border-slate-200 text-slate-500 hover:border-slate-300'}">
                        🇬🇧 English</button>
                </div>
            </div>

            <!-- Platform -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-3">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">📲 {$locale === 'ar' ? 'المنصة' : 'Platform'}</label>
                <div class="grid grid-cols-3 gap-2">
                    {#each platforms as pl}
                        <button on:click={() => (selectedPlatformId = pl.id)}
                            class="flex flex-col items-center gap-1 p-2 rounded-xl border-2 transition-all text-center
                                   {selectedPlatformId === pl.id ? 'border-orange-500 bg-orange-50' : 'border-slate-200 bg-white hover:border-orange-300'}">
                            <span class="text-xl">{pl.icon}</span>
                            <span class="text-[9px] font-black text-slate-600 leading-tight">{$locale === 'ar' ? pl.ar : pl.en}</span>
                            <span class="text-[8px] font-bold text-slate-400">{pl.ratio}</span>
                        </button>
                    {/each}
                </div>
            </div>

            <!-- Duration -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-2">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">⏱️ {$locale === 'ar' ? 'مدة الفيديو' : 'Duration'}</label>
                <div class="flex gap-2">
                    {#each [5, 8] as dur}
                        <button on:click={() => (durationSeconds = dur)}
                            class="flex-1 py-2 rounded-xl text-xs font-black border-2 transition-all
                                   {durationSeconds === dur ? 'border-orange-500 bg-orange-50 text-orange-700' : 'border-slate-200 text-slate-500 hover:border-slate-300'}">
                            {dur}{$locale === 'ar' ? ' ثانية' : 's'}
                        </button>
                    {/each}
                </div>
            </div>

            <!-- Prompt -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-2">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">✍️ {$locale === 'ar' ? 'فكرتك' : 'Your Idea'}</label>
                <textarea bind:value={prompt} rows="5"
                    placeholder={$locale === 'ar'
                        ? 'مثال: مشهد داخل سوبرماركت، شخصية ترحب بالزوار، إضاءة ناعمة...'
                        : 'e.g. Supermarket scene, character welcoming customers, warm lighting...'}
                    class="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 text-black resize-none leading-relaxed"
                ></textarea>
                <p class="text-[10px] text-amber-600 font-semibold bg-amber-50 rounded-lg px-2 py-1">
                    ⏳ {$locale === 'ar' ? 'إنشاء الفيديو يستغرق 1–3 دقائق' : 'Video generation takes 1–3 minutes'}
                </p>
            </div>

            <!-- Generate -->
            <button on:click={generate}
                disabled={generating || !prompt.trim() || !selectedBrandId}
                class="w-full py-4 rounded-2xl text-sm font-black uppercase tracking-widest transition-all transform
                       {(!generating && prompt.trim() && selectedBrandId)
                           ? 'bg-orange-600 text-white shadow-lg shadow-orange-200 hover:bg-orange-700 hover:scale-[1.02] active:scale-[0.98]'
                           : 'bg-slate-200 text-slate-400 cursor-not-allowed'}">
                {#if generating}
                    <span class="flex items-center justify-center gap-3">
                        <span class="inline-block w-5 h-5 border-t-white rounded-full animate-spin" style="border:3px solid rgba(255,255,255,0.35); border-top-color:#fff;"></span>
                        <span>{$locale === 'ar' ? `جارٍ الإنشاء... ${elapsedSeconds}ث` : `Generating... ${elapsedSeconds}s`}</span>
                    </span>
                {:else}
                    🎬 {$locale === 'ar' ? 'إنشاء الفيديو' : 'Generate Video'}
                {/if}
            </button>
        </div>

        <!-- ══ RIGHT — Preview ══════════════════════════════════════════════ -->
        <div class="space-y-4">
            <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-6">
                <div class="flex items-center justify-between mb-4">
                    <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide">🎬 {$locale === 'ar' ? 'معاينة الفيديو' : 'Video Preview'}</h3>
                    {#if generatedUrl}
                        <button on:click={downloadVideo}
                            class="px-4 py-2 rounded-xl text-xs font-black bg-orange-600 text-white hover:bg-orange-700 transition-colors shadow-sm">
                            ⬇️ {$locale === 'ar' ? 'تنزيل' : 'Download'}
                        </button>
                    {/if}
                </div>

                <div class="flex items-center justify-center bg-slate-50 rounded-2xl overflow-hidden min-h-[340px] p-4">
                    {#if generating}
                        <div class="flex flex-col items-center gap-5 text-center">
                            <div class="relative w-20 h-20">
                                <div class="absolute inset-0 border-4 border-orange-200 rounded-full animate-ping opacity-30"></div>
                                <div class="absolute inset-0 border-4 border-orange-300 border-t-orange-600 rounded-full animate-spin"></div>
                                <div class="absolute inset-0 flex items-center justify-center text-3xl">🎬</div>
                            </div>
                            <div class="text-center">
                                <p class="font-black text-slate-700 text-sm">{$locale === 'ar' ? 'الذكاء الاصطناعي يصنع فيديوك...' : 'AI is creating your video...'}</p>
                                <p class="text-xs text-slate-400 font-semibold mt-1">{$locale === 'ar' ? '1–3 دقائق' : '1–3 minutes'}</p>
                                <div class="mt-3 px-4 py-1.5 bg-orange-50 rounded-xl border border-orange-100">
                                    <p class="text-xs font-black text-orange-600">{elapsedSeconds}s</p>
                                    <div class="mt-1 w-32 h-1.5 bg-orange-100 rounded-full overflow-hidden">
                                        <div class="h-full bg-orange-400 rounded-full transition-all duration-1000"
                                             style="width:{Math.min(100, (elapsedSeconds / 180) * 100)}%"></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    {:else if errorMessage}
                        <div class="flex flex-col items-center gap-3 text-center max-w-sm">
                            <span class="text-4xl">❌</span>
                            <p class="text-sm font-black text-red-700">{$locale === 'ar' ? 'حدث خطأ' : 'Error'}</p>
                            <p class="text-xs text-red-600 font-semibold bg-red-50 rounded-xl p-3 text-left break-words">{errorMessage}</p>
                            {#if generatedPrompt}
                                <details class="w-full text-left">
                                    <summary class="text-xs font-bold text-slate-400 cursor-pointer">Prompt used</summary>
                                    <p class="text-xs text-slate-600 mt-2 bg-slate-50 rounded-xl p-3 break-words font-mono">{generatedPrompt}</p>
                                </details>
                            {/if}
                        </div>
                    {:else if generatedUrl}
                        <div class="flex flex-col items-center gap-3 w-full">
                            <div class="relative rounded-2xl overflow-hidden shadow-xl max-w-sm w-full mx-auto {previewAspect} bg-black">
                                <!-- svelte-ignore a11y-media-has-caption -->
                                <video src={generatedUrl} class="w-full h-full object-contain" controls autoplay loop playsinline></video>
                                {#if logoUrl}
                                    <img src={logoUrl} alt="brand logo"
                                         class="absolute top-3 right-3 h-10 w-auto object-contain drop-shadow-lg pointer-events-none"
                                         style="max-width:80px;" />
                                {/if}
                            </div>
                            {#if generatedPrompt}
                                <details class="w-full text-left max-w-sm">
                                    <summary class="text-xs font-bold text-slate-400 cursor-pointer hover:text-slate-600">📝 {$locale === 'ar' ? 'البرومبت' : 'Prompt used'}</summary>
                                    <p class="text-xs text-slate-600 mt-2 bg-slate-50 rounded-xl p-3 break-words font-mono leading-relaxed">{generatedPrompt}</p>
                                </details>
                            {/if}
                        </div>
                    {:else}
                        <div class="flex flex-col items-center gap-3 text-center">
                            <div class="w-20 h-20 rounded-full bg-gradient-to-br from-orange-400 to-amber-500 flex items-center justify-center shadow-xl shadow-orange-200 opacity-40">
                                <span class="text-4xl">🎬</span>
                            </div>
                            <p class="text-sm font-black text-slate-400">{$locale === 'ar' ? 'سيظهر الفيديو هنا' : 'Video will appear here'}</p>
                            <p class="text-xs text-slate-300 font-semibold max-w-xs">{$locale === 'ar' ? 'اختر هوية وأدخل فكرتك ثم اضغط إنشاء' : 'Pick a brand profile, enter your idea and hit Generate'}</p>
                        </div>
                    {/if}
                </div>
            </div>

            <!-- History -->
            {#if history.length > 0}
                <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-5">
                    <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide mb-3">🕒 {$locale === 'ar' ? 'السابقة' : 'Recent'}</h3>
                    <div class="grid grid-cols-5 gap-3">
                        {#each history as item}
                            <button class="rounded-xl overflow-hidden bg-slate-900 aspect-square shadow-sm hover:shadow-md transition-shadow flex items-center justify-center"
                                    on:click={() => { generatedUrl = item.url; generatedPrompt = item.prompt; }}>
                                <span class="text-2xl">🎬</span>
                            </button>
                        {/each}
                    </div>
                </div>
            {/if}
        </div>
    </div>
</div>
