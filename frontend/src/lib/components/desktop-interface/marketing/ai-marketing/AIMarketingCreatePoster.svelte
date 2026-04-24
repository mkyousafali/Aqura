<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';

    let supabase: any = null;

    // ── Brand selection ───────────────────────────────────────────────────
    let brands: any[] = [];
    let selectedBrandId: number | null = null;
    $: selectedBrand = brands.find(b => b.id === selectedBrandId) || null;

    // ── Product selection (max 3) ──────────────────────────────────────────
    let productSearch = '';
    let productResults: any[] = [];
    let productSearching = false;
    let selectedProducts: any[] = [];
    let productSearchTimeout: any;

    // ── Product picker popup ────────────────────────────────────────────────
    let showProductPicker = false;

    function openProductPicker() { showProductPicker = true; productSearch = ''; productResults = []; }
    function closeProductPicker() { showProductPicker = false; productSearch = ''; productResults = []; }

    // ── Platform / Format ─────────────────────────────────────────────────
    const platforms = [
        { id: 'instagram_feed',  icon: '📸', en: 'Instagram Feed',  ar: 'إنستغرام فيد',  ratio: '1:1'  },
        { id: 'instagram_story', icon: '📱', en: 'Insta Story',     ar: 'قصة إنستغرام',   ratio: '9:16' },
        { id: 'facebook',        icon: '👤', en: 'Facebook',        ar: 'فيسبوك',          ratio: '16:9' },
        { id: 'twitter',         icon: '🐦', en: 'Twitter / X',    ar: 'تويتر / X',       ratio: '16:9' },
        { id: 'whatsapp',        icon: '💬', en: 'WhatsApp Status', ar: 'حالة واتساب',     ratio: '9:16' },
        { id: 'tiktok',          icon: '🎵', en: 'TikTok',          ar: 'تيك توك',         ratio: '9:16' },
        { id: 'custom',          icon: '⚙️', en: 'Custom',          ar: 'مخصص',            ratio: '1:1'  }
    ];

    let selectedPlatformId = 'instagram_feed';
    $: selectedPlatform = platforms.find(p => p.id === selectedPlatformId) || platforms[0];

    // Aspect ratio follows platform, but user can override on 'custom'
    const ratioOptions = ['1:1', '9:16', '16:9', '4:5', '3:4'];
    let aspectRatio = '1:1';
    $: if (selectedPlatformId !== 'custom') aspectRatio = selectedPlatform.ratio;

    // ── Content options ───────────────────────────────────────────────────
    let language: 'ar' | 'en' = 'ar';
    let headline = '';
    let extraPrompt = '';

    // ── Generation state ──────────────────────────────────────────────────
    let generating = false;
    let errorMessage = '';
    let generatedUrl: string | null = null;
    let generatedPrompt: string | null = null;
    let generatedFileId: number | null = null;

    // ── History (last 5 in session) ───────────────────────────────────────
    let history: Array<{ url: string; title: string; fileId: number | null }> = [];

    $: userId = $currentUser?.id;

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadBrands();
    });

    async function loadBrands() {
        const { data } = await supabase
            .from('ai_brand_libraries')
            .select('id, name, primary_color, is_default')
            .eq('is_archived', false)
            .order('is_default', { ascending: false });
        brands = data || [];
        const def = brands.find(b => b.is_default);
        if (def) selectedBrandId = def.id;
        else if (brands.length) selectedBrandId = brands[0].id;
    }

    function debounceSearchProducts(q: string) {
        clearTimeout(productSearchTimeout);
        if (!q.trim()) { productResults = []; return; }
        productSearchTimeout = setTimeout(() => searchProducts(q), 300);
    }

    $: debounceSearchProducts(productSearch);

    async function searchProducts(q: string) {
        if (!supabase || !q.trim()) return;
        productSearching = true;
        const { data } = await supabase
            .from('products')
            .select('id, product_name_en, product_name_ar, image_url, barcode')
            .eq('is_active', true)
            .or(`product_name_en.ilike.%${q}%,product_name_ar.ilike.%${q}%,barcode.ilike.%${q}%`)
            .limit(8);
        productResults = (data || []).filter(p => !selectedProducts.some(s => s.id === p.id));
        productSearching = false;
    }

    function addProduct(p: any) {
        if (selectedProducts.length >= 3) return;
        if (selectedProducts.some(s => s.id === p.id)) return;
        // Attach manual price fields (not from DB)
        selectedProducts = [...selectedProducts, { ...p, priceBeforeOffer: '', priceAfterOffer: '' }];
        productResults = productResults.filter(r => r.id !== p.id);
        productSearch = '';
    }

    function removeProduct(id: string) {
        selectedProducts = selectedProducts.filter(p => p.id !== id);
    }

    function updateProductPrice(id: string, field: 'priceBeforeOffer' | 'priceAfterOffer', value: string) {
        selectedProducts = selectedProducts.map(p => p.id === id ? { ...p, [field]: value } : p);
    }

    function getProductName(p: any) {
        return $locale === 'ar' ? (p.product_name_ar || p.product_name_en) : (p.product_name_en || p.product_name_ar);
    }

    // ── Generate ──────────────────────────────────────────────────────────
    async function generate() {
        if (generating) return;
        generating  = true;
        errorMessage = '';
        generatedUrl = null;
        generatedPrompt = null;

        try {
            const res = await fetch('/api/ai-marketing/generate-poster', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    brandId:  selectedBrandId,
                    products: selectedProducts.map(p => ({
                        id:               p.id,
                        product_name_en:  p.product_name_en,
                        product_name_ar:  p.product_name_ar,
                        image_url:        p.image_url || null,
                        barcode:          p.barcode || null,
                        priceBeforeOffer: p.priceBeforeOffer || null,
                        priceAfterOffer:  p.priceAfterOffer  || null
                    })),
                    platform:    selectedPlatformId,
                    aspectRatio,
                    language,
                    headline:    headline.trim(),
                    extraPrompt: extraPrompt.trim(),
                    userId
                })
            });
            const data = await res.json();
            if (!data.ok) {
                errorMessage = `[${data.stage ?? 'error'}] ${data.message}`;
                if (data.imagePrompt) generatedPrompt = data.imagePrompt;
                return;
            }
            generatedUrl    = data.signedUrl;
            generatedPrompt = data.imagePrompt;
            generatedFileId = data.fileId;

            // Add to session history
            const title = headline.trim() ||
                (selectedProducts.length ? selectedProducts.map(p => getProductName(p)).join(', ') : (selectedBrand?.name || 'Poster'));
            history = [{ url: data.signedUrl, title, fileId: data.fileId }, ...history].slice(0, 5);

        } catch (err: any) {
            errorMessage = err?.message ?? String(err);
        } finally {
            generating = false;
        }
    }

    async function downloadImage() {
        if (!generatedUrl) return;
        const a = document.createElement('a');
        a.href = generatedUrl;
        a.download = `poster-${Date.now()}.png`;
        a.click();
    }

    // ── Drag-to-reposition in preview ─────────────────────────────────────
    let imgOffsetX = 0;
    let imgOffsetY = 0;
    let dragging = false;
    let dragStartX = 0;
    let dragStartY = 0;
    let dragStartOffX = 0;
    let dragStartOffY = 0;

    // Reset position when a new image is generated
    $: if (generatedUrl) { imgOffsetX = 0; imgOffsetY = 0; }

    function onDragStart(e: MouseEvent | TouchEvent) {
        dragging = true;
        const pt = 'touches' in e ? e.touches[0] : e;
        dragStartX = pt.clientX;
        dragStartY = pt.clientY;
        dragStartOffX = imgOffsetX;
        dragStartOffY = imgOffsetY;
        e.preventDefault();
    }
    function onDragMove(e: MouseEvent | TouchEvent) {
        if (!dragging) return;
        const pt = 'touches' in e ? e.touches[0] : e;
        imgOffsetX = dragStartOffX + (pt.clientX - dragStartX);
        imgOffsetY = dragStartOffY + (pt.clientY - dragStartY);
    }
    function onDragEnd() { dragging = false; }

    function copyPrompt() {
        if (generatedPrompt) navigator.clipboard.writeText(generatedPrompt);
    }

    // Aspect ratio → preview CSS
    $: previewAspect = {
        '1:1':  'aspect-square',
        '9:16': 'aspect-[9/16]',
        '16:9': 'aspect-video',
        '4:5':  'aspect-[4/5]',
        '3:4':  'aspect-[3/4]'
    }[aspectRatio] || 'aspect-square';

    $: canGenerate = !!selectedBrandId && !generating;
</script>

<div class="w-full" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <div class="grid grid-cols-1 xl:grid-cols-[420px_1fr] gap-6">

        <!-- ══ LEFT PANEL — Controls ══════════════════════════════════════ -->
        <div class="space-y-4">

            <!-- Header -->
            <div>
                <h2 class="text-xl font-black text-slate-800 tracking-tight">
                    🖼️ {$locale === 'ar' ? 'إنشاء ملصق تسويقي' : 'Create Marketing Poster'}
                </h2>
                <p class="text-xs font-semibold text-slate-500 mt-0.5">
                    {$locale === 'ar'
                        ? 'اختر العلامة، المنتجات، المنصة ثم اضغط إنشاء'
                        : 'Pick brand, products, platform then hit Generate'}
                </p>
            </div>

            <!-- ── Brand ───────────────────────────────────────────── -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-2">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">
                    🎨 {$locale === 'ar' ? 'العلامة التجارية' : 'Brand'}
                </label>
                <select
                    bind:value={selectedBrandId}
                    class="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-emerald-500"
                    style="color:#000 !important; background-color:#fff !important;"
                >
                    <option value={null} style="color:#000 !important;">
                        {$locale === 'ar' ? '— اختر علامة —' : '— Select Brand —'}
                    </option>
                    {#each brands as b}
                        <option value={b.id} style="color:#000 !important;">{b.name}{b.is_default ? ' ⭐' : ''}</option>
                    {/each}
                </select>
                {#if selectedBrand}
                    <div class="flex items-center gap-2 mt-1">
                        <div class="w-4 h-4 rounded-full border-2 border-white shadow-sm" style="background:{selectedBrand.primary_color}"></div>
                        <span class="text-[10px] font-bold text-slate-500">{selectedBrand.primary_color}</span>
                    </div>
                {/if}
            </div>

            <!-- ── Products ────────────────────────────────────────── -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-3">
                <div class="flex items-center justify-between">
                    <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">
                        🛍️ {$locale === 'ar' ? 'المنتجات (حتى 3)' : 'Products (up to 3)'}
                    </label>
                    <span class="px-2 py-0.5 rounded-full text-[10px] font-black
                                 {selectedProducts.length >= 3 ? 'bg-red-100 text-red-600' : 'bg-slate-100 text-slate-500'}">
                        {selectedProducts.length}/3
                    </span>
                </div>

                <!-- Selected product cards -->
                {#if selectedProducts.length > 0}
                    <div class="space-y-3">
                        {#each selectedProducts as p (p.id)}
                            <div class="px-3 py-3 bg-emerald-50 border border-emerald-200 rounded-2xl space-y-2">
                                <!-- Product row: image + name + remove -->
                                <div class="flex items-center gap-3">
                                    <div class="w-10 h-10 rounded-xl bg-white overflow-hidden flex-shrink-0 shadow-sm border border-emerald-100">
                                        {#if p.image_url}
                                            <img src={p.image_url} alt="" class="w-full h-full object-cover" />
                                        {:else}
                                            <div class="w-full h-full flex items-center justify-center text-slate-400 text-base">🛍</div>
                                        {/if}
                                    </div>
                                    <div class="flex-1 min-w-0">
                                        <div class="text-xs font-black text-emerald-800 truncate">{getProductName(p)}</div>
                                        {#if $locale !== 'ar' && p.product_name_ar}
                                            <div class="text-[10px] text-slate-400 truncate">{p.product_name_ar}</div>
                                        {:else if $locale === 'ar' && p.product_name_en}
                                            <div class="text-[10px] text-slate-400 truncate">{p.product_name_en}</div>
                                        {/if}
                                    </div>
                                    <button
                                        on:click={() => removeProduct(p.id)}
                                        class="w-6 h-6 rounded-lg bg-red-100 hover:bg-red-200 text-red-500 flex items-center justify-center font-black text-xs flex-shrink-0 transition-colors"
                                    >✕</button>
                                </div>
                                <!-- Price inputs -->
                                <div class="grid grid-cols-2 gap-2">
                                    <div>
                                        <label class="block text-[9px] font-black text-slate-400 uppercase mb-1">
                                            {$locale === 'ar' ? 'السعر قبل العرض (ر.س)' : 'Price Before Offer (SAR)'}
                                        </label>
                                        <input
                                            type="number"
                                            min="0"
                                            step="0.01"
                                            placeholder="0.00"
                                            value={p.priceBeforeOffer}
                                            on:input={(e) => updateProductPrice(p.id, 'priceBeforeOffer', (e.target as HTMLInputElement).value)}
                                            class="w-full px-2.5 py-1.5 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-800
                                                   focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent"
                                        />
                                    </div>
                                    <div>
                                        <label class="block text-[9px] font-black text-slate-400 uppercase mb-1">
                                            {$locale === 'ar' ? 'السعر بعد العرض (ر.س)' : 'Offer Price (SAR)'}
                                        </label>
                                        <input
                                            type="number"
                                            min="0"
                                            step="0.01"
                                            placeholder="0.00"
                                            value={p.priceAfterOffer}
                                            on:input={(e) => updateProductPrice(p.id, 'priceAfterOffer', (e.target as HTMLInputElement).value)}
                                            class="w-full px-2.5 py-1.5 bg-white border border-orange-200 rounded-xl text-xs font-bold text-orange-700
                                                   focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-transparent"
                                        />
                                    </div>
                                </div>
                            </div>
                        {/each}
                    </div>
                {:else}
                    <p class="text-[11px] text-slate-400 font-semibold">
                        {$locale === 'ar' ? 'لم يتم اختيار أي منتج (اختياري)' : 'No product selected (optional)'}
                    </p>
                {/if}

                <!-- Open picker button -->
                {#if selectedProducts.length < 3}
                    <button
                        on:click={openProductPicker}
                        class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl border-2 border-dashed border-emerald-300
                               text-emerald-700 text-xs font-black hover:bg-emerald-50 hover:border-emerald-400 transition-all"
                    >
                        <span>+</span>
                        <span>{$locale === 'ar' ? 'إضافة منتج' : 'Add Product'}</span>
                    </button>
                {/if}
            </div>

            <!-- ── Platform grid ───────────────────────────────────── -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-3">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">
                    📲 {$locale === 'ar' ? 'المنصة' : 'Platform'}
                </label>
                <div class="grid grid-cols-4 gap-2">
                    {#each platforms as pl}
                        <button
                            on:click={() => (selectedPlatformId = pl.id)}
                            class="flex flex-col items-center gap-1 p-2 rounded-xl border-2 transition-all text-center
                                   {selectedPlatformId === pl.id
                                       ? 'border-emerald-500 bg-emerald-50'
                                       : 'border-slate-200 bg-white hover:border-emerald-300 hover:bg-emerald-50/50'}"
                        >
                            <span class="text-xl">{pl.icon}</span>
                            <span class="text-[9px] font-black text-slate-600 leading-tight">
                                {$locale === 'ar' ? pl.ar : pl.en}
                            </span>
                            <span class="text-[8px] font-bold text-slate-400">{pl.ratio}</span>
                        </button>
                    {/each}
                </div>
                {#if selectedPlatformId === 'custom'}
                    <div>
                        <label class="block text-[10px] font-black text-slate-400 mb-1 uppercase">
                            {$locale === 'ar' ? 'نسبة الأبعاد' : 'Aspect Ratio'}
                        </label>
                        <div class="flex gap-2 flex-wrap">
                            {#each ratioOptions as r}
                                <button
                                    on:click={() => (aspectRatio = r)}
                                    class="px-3 py-1 rounded-lg text-xs font-black border-2 transition-all
                                           {aspectRatio === r ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-500 hover:border-emerald-300'}"
                                >{r}</button>
                            {/each}
                        </div>
                    </div>
                {/if}
            </div>

            <!-- ── Content options ─────────────────────────────────── -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-3">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">
                    ✍️ {$locale === 'ar' ? 'خيارات المحتوى' : 'Content Options'}
                </label>

                <!-- Language toggle -->
                <div class="flex items-center gap-2">
                    <span class="text-[10px] font-bold text-slate-500 uppercase">{$locale === 'ar' ? 'لغة الملصق:' : 'Poster language:'}</span>
                    <div class="flex gap-1">
                        <button
                            on:click={() => (language = 'ar')}
                            class="px-3 py-1 rounded-lg text-xs font-black border-2 transition-all
                                   {language === 'ar' ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-500 hover:border-slate-300'}"
                        >🇸🇦 عربي</button>
                        <button
                            on:click={() => (language = 'en')}
                            class="px-3 py-1 rounded-lg text-xs font-black border-2 transition-all
                                   {language === 'en' ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-500 hover:border-slate-300'}"
                        >🇬🇧 English</button>
                    </div>
                </div>

                <!-- Headline -->
                <div>
                    <label class="block text-[10px] font-bold text-slate-400 mb-1" for="headline">
                        {$locale === 'ar' ? 'العنوان الرئيسي (اختياري)' : 'Headline (optional)'}
                    </label>
                    <input
                        id="headline" type="text" bind:value={headline}
                        placeholder={$locale === 'ar' ? 'مثال: عروض نهاية الأسبوع!' : 'e.g. Weekend Special Offers!'}
                        class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black"
                    />
                </div>

                <!-- Extra prompt -->
                <div>
                    <label class="block text-[10px] font-bold text-slate-400 mb-1" for="extra-prompt">
                        {$locale === 'ar' ? 'تعليمات إضافية للذكاء الاصطناعي (اختياري)' : 'Extra AI instructions (optional)'}
                    </label>
                    <textarea
                        id="extra-prompt" bind:value={extraPrompt} rows="3"
                        placeholder={$locale === 'ar'
                            ? 'مثال: أضف نجوماً ذهبية، خلفية ناعمة زرقاء...'
                            : 'e.g. Add golden stars, soft blue background...'}
                        class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black resize-none"
                    ></textarea>
                </div>
            </div>

            <!-- ── Generate button ─────────────────────────────────── -->
            <button
                on:click={generate}
                disabled={!canGenerate}
                class="w-full py-4 rounded-2xl text-sm font-black uppercase tracking-widest transition-all transform
                       {canGenerate
                           ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 hover:scale-[1.02] active:scale-[0.98]'
                           : 'bg-slate-200 text-slate-400 cursor-not-allowed'}"
            >
                {#if generating}
                    <span class="flex items-center justify-center gap-3">
                        <span class="inline-block w-5 h-5 border-3 border-white/40 border-t-white rounded-full animate-spin" style="border-width:3px"></span>
                        <span>{$locale === 'ar' ? 'جارٍ الإنشاء...' : 'Generating...'}</span>
                    </span>
                {:else}
                    ✨ {$locale === 'ar' ? 'إنشاء الملصق' : 'Generate Poster'}
                {/if}
            </button>
        </div>

        <!-- ══ RIGHT PANEL — Preview & History ═══════════════════════════ -->
        <div class="space-y-4">

            <!-- Preview area -->
            <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-6">
                <div class="flex items-center justify-between mb-4">
                    <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide">
                        🖼️ {$locale === 'ar' ? 'معاينة الملصق' : 'Poster Preview'}
                    </h3>
                    {#if generatedUrl}
                        <div class="flex gap-2">
                            <button
                                on:click={copyPrompt}
                                title={$locale === 'ar' ? 'نسخ البرومبت' : 'Copy prompt'}
                                class="px-3 py-1.5 rounded-xl text-xs font-black bg-slate-100 text-slate-600 hover:bg-slate-200 transition-colors"
                            >📋 {$locale === 'ar' ? 'نسخ البرومبت' : 'Copy Prompt'}</button>
                            <button
                                on:click={downloadImage}
                                class="px-3 py-1.5 rounded-xl text-xs font-black bg-emerald-600 text-white hover:bg-emerald-700 transition-colors shadow-sm"
                            >⬇️ {$locale === 'ar' ? 'تنزيل' : 'Download'}</button>
                        </div>
                    {/if}
                </div>

                <!-- Poster preview box -->
                <div class="flex items-center justify-center bg-slate-50 rounded-2xl overflow-hidden min-h-[320px] p-4">
                    {#if generating}
                        <div class="flex flex-col items-center gap-4">
                            <div class="relative w-16 h-16">
                                <div class="absolute inset-0 border-4 border-emerald-200 rounded-full animate-ping opacity-30"></div>
                                <div class="absolute inset-0 border-4 border-emerald-300 border-t-emerald-600 rounded-full animate-spin"></div>
                                <div class="absolute inset-0 flex items-center justify-center text-2xl">🎨</div>
                            </div>
                            <div class="text-center">
                                <p class="font-black text-slate-700 text-sm">
                                    {$locale === 'ar' ? 'الذكاء الاصطناعي يرسم ملصقك...' : 'AI is painting your poster...'}
                                </p>
                                <p class="text-xs text-slate-400 font-semibold mt-1">
                                    {$locale === 'ar' ? 'قد يستغرق من 15 إلى 45 ثانية' : 'May take 15–45 seconds'}
                                </p>
                            </div>
                        </div>
                    {:else if errorMessage}
                        <div class="flex flex-col items-center gap-3 text-center max-w-sm">
                            <span class="text-4xl">❌</span>
                            <p class="text-sm font-black text-red-700">{$locale === 'ar' ? 'حدث خطأ' : 'Generation Error'}</p>
                            <p class="text-xs text-red-600 font-semibold bg-red-50 rounded-xl p-3 text-left break-words">{errorMessage}</p>
                            {#if generatedPrompt}
                                <details class="w-full text-left">
                                    <summary class="text-xs font-bold text-slate-400 cursor-pointer">
                                        {$locale === 'ar' ? 'البرومبت المُنشأ' : 'Generated prompt'}
                                    </summary>
                                    <p class="text-xs text-slate-600 mt-2 bg-slate-50 rounded-xl p-3 break-words font-mono leading-relaxed">{generatedPrompt}</p>
                                </details>
                            {/if}
                        </div>
                    {:else if generatedUrl}
                        <div class="flex flex-col items-center gap-3 w-full">
                            <!-- Draggable poster preview -->
                            <div
                                class="rounded-2xl overflow-hidden shadow-xl max-w-md w-full mx-auto {previewAspect} relative select-none"
                                style="cursor:{dragging ? 'grabbing' : 'grab'};"
                                on:mousedown={onDragStart}
                                on:mousemove={onDragMove}
                                on:mouseup={onDragEnd}
                                on:mouseleave={onDragEnd}
                                on:touchstart={onDragStart}
                                on:touchmove={onDragMove}
                                on:touchend={onDragEnd}
                            >
                                <img
                                    src={generatedUrl}
                                    alt="Generated poster"
                                    class="w-full h-full object-contain bg-white pointer-events-none"
                                    style="transform: translate({imgOffsetX}px, {imgOffsetY}px); transition:{dragging ? 'none' : 'transform 0.15s ease'};"
                                    draggable="false"
                                />
                                <div class="absolute bottom-2 left-1/2 -translate-x-1/2 px-2 py-0.5 rounded-full bg-black/40 text-white text-[9px] font-bold pointer-events-none">
                                    {$locale === 'ar' ? 'اسحب لإعادة التموضع' : 'Drag to reposition'}
                                </div>
                            </div>
                            {#if generatedPrompt}
                                <details class="w-full text-left max-w-md">
                                    <summary class="text-xs font-bold text-slate-400 cursor-pointer hover:text-slate-600 transition-colors">
                                        {$locale === 'ar' ? '📝 البرومبت المُستخدم' : '📝 Prompt used'}
                                    </summary>
                                    <p class="text-xs text-slate-600 mt-2 bg-slate-50 rounded-xl p-3 break-words font-mono leading-relaxed">{generatedPrompt}</p>
                                </details>
                            {/if}
                        </div>
                    {:else}
                        <div class="flex flex-col items-center gap-3 text-center">
                            <div class="text-6xl opacity-20">🖼️</div>
                            <p class="text-sm font-black text-slate-400">
                                {$locale === 'ar' ? 'سيظهر الملصق هنا بعد الإنشاء' : 'Poster will appear here after generation'}
                            </p>
                            <p class="text-xs text-slate-300 font-semibold max-w-xs">
                                {$locale === 'ar'
                                    ? 'اختر العلامة التجارية والمنتجات والمنصة ثم اضغط إنشاء'
                                    : 'Select brand, products, platform and click Generate'}
                            </p>
                        </div>
                    {/if}
                </div>
            </div>

            <!-- Session history -->
            {#if history.length > 0}
                <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-5">
                    <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide mb-3">
                        🕒 {$locale === 'ar' ? 'التاريخ (هذه الجلسة)' : 'History (this session)'}
                    </h3>
                    <div class="grid grid-cols-3 sm:grid-cols-5 gap-3">
                        {#each history as item}
                            <div class="group relative rounded-2xl overflow-hidden bg-slate-100 aspect-square shadow-sm cursor-pointer hover:shadow-md transition-shadow"
                                 on:click={() => { generatedUrl = item.url; generatedFileId = item.fileId; }}
                                 on:keypress={() => {}}
                                 role="button" tabindex="0"
                            >
                                <img src={item.url} alt={item.title} class="w-full h-full object-cover" />
                                <div class="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                                    <span class="text-white text-xs font-black text-center px-1 line-clamp-2">{item.title}</span>
                                </div>
                            </div>
                        {/each}
                    </div>
                </div>
            {/if}
        </div>
    </div>
</div>

<!-- ══ PRODUCT PICKER POPUP ══════════════════════════════════════════════ -->
{#if showProductPicker}
    <div
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
        dir={$locale === 'ar' ? 'rtl' : 'ltr'}
    >
        <!-- Backdrop -->
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" on:click={closeProductPicker}></div>

        <!-- Modal -->
        <div class="relative bg-white rounded-[2rem] shadow-[0_32px_80px_-8px_rgba(0,0,0,0.25)]
                    w-full max-w-lg flex flex-col overflow-hidden max-h-[80vh]">

            <!-- Header -->
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-200 bg-slate-50 flex-shrink-0">
                <div>
                    <h3 class="font-black text-slate-800 text-base">
                        🛍️ {$locale === 'ar' ? 'اختيار منتج' : 'Select Product'}
                    </h3>
                    <p class="text-[10px] font-semibold text-slate-400 mt-0.5">
                        {$locale === 'ar'
                            ? `يمكنك اختيار حتى 3 منتجات — مختار حالياً: ${selectedProducts.length}`
                            : `Up to 3 products — currently selected: ${selectedProducts.length}`}
                    </p>
                </div>
                <button
                    on:click={closeProductPicker}
                    class="w-8 h-8 rounded-xl bg-slate-200 hover:bg-slate-300 flex items-center justify-center text-slate-600 font-black transition-colors"
                >✕</button>
            </div>

            <!-- Search bar -->
            <div class="px-6 py-3 border-b border-slate-100 flex-shrink-0">
                <div class="relative">
                    <span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm">🔍</span>
                    <input
                        type="text"
                        bind:value={productSearch}
                        autofocus
                        placeholder={$locale === 'ar' ? 'ابحث باسم المنتج أو الباركود...' : 'Search by product name or barcode...'}
                        class="w-full {$locale === 'ar' ? 'pr-9 pl-4' : 'pl-9 pr-4'} py-2.5 bg-white border border-slate-200 rounded-xl text-sm
                               focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black"
                    />
                    {#if productSearching}
                        <div class="absolute {$locale === 'ar' ? 'left-3' : 'right-3'} top-1/2 -translate-y-1/2">
                            <div class="w-4 h-4 border-2 border-emerald-300 border-t-emerald-600 rounded-full animate-spin"></div>
                        </div>
                    {/if}
                </div>
            </div>

            <!-- Results list -->
            <div class="flex-1 overflow-y-auto">
                {#if productResults.length === 0 && !productSearching && productSearch.trim()}
                    <div class="flex flex-col items-center justify-center py-12 text-slate-400">
                        <span class="text-3xl mb-2">🔍</span>
                        <p class="text-sm font-semibold">{$locale === 'ar' ? 'لا توجد نتائج' : 'No results found'}</p>
                    </div>
                {:else if productResults.length === 0 && !productSearch.trim()}
                    <div class="flex flex-col items-center justify-center py-12 text-slate-300">
                        <span class="text-4xl mb-2">🛍️</span>
                        <p class="text-sm font-semibold text-slate-400">
                            {$locale === 'ar' ? 'اكتب للبحث عن منتج' : 'Type to search for a product'}
                        </p>
                    </div>
                {:else}
                    <div class="divide-y divide-slate-100">
                        {#each productResults as p (p.id)}
                            <button
                                on:click={() => { addProduct(p); if (selectedProducts.length >= 3) closeProductPicker(); }}
                                class="w-full flex items-center gap-4 px-6 py-3.5 hover:bg-emerald-50 transition-colors text-left group"
                            >
                                <!-- Product image -->
                                <div class="w-14 h-14 rounded-2xl bg-slate-100 flex-shrink-0 overflow-hidden shadow-sm border border-slate-200 group-hover:border-emerald-200 transition-colors">
                                    {#if p.image_url}
                                        <img src={p.image_url} alt="" class="w-full h-full object-cover" />
                                    {:else}
                                        <div class="w-full h-full flex items-center justify-center text-slate-300 text-2xl">🛍</div>
                                    {/if}
                                </div>
                                <!-- Info -->
                                <div class="flex-1 min-w-0">
                                    <div class="font-black text-slate-800 text-sm truncate">
                                        {getProductName(p)}
                                    </div>
                                    {#if $locale === 'ar' && p.product_name_en}
                                        <div class="text-[10px] text-slate-400 font-semibold truncate">{p.product_name_en}</div>
                                    {:else if $locale !== 'ar' && p.product_name_ar}
                                        <div class="text-[10px] text-slate-400 font-semibold truncate">{p.product_name_ar}</div>
                                    {/if}
                                    {#if p.barcode}
                                        <div class="text-[10px] text-slate-300 font-mono">{p.barcode}</div>
                                    {/if}
                                </div>
                                <!-- Add icon -->
                                <div class="flex flex-col items-end gap-1 flex-shrink-0">
                                    <span class="text-xl opacity-0 group-hover:opacity-100 transition-opacity">➕</span>
                                </div>
                            </button>
                        {/each}
                    </div>
                {/if}
            </div>

            <!-- Footer: selected + done -->
            <div class="px-6 py-4 border-t border-slate-200 bg-slate-50 flex-shrink-0">
                {#if selectedProducts.length > 0}
                    <div class="flex flex-wrap gap-2 mb-3">
                        {#each selectedProducts as p (p.id)}
                            <div class="flex items-center gap-1.5 px-2.5 py-1 bg-emerald-100 border border-emerald-300 rounded-full">
                                <span class="text-xs font-black text-emerald-800 max-w-[100px] truncate">{getProductName(p)}</span>
                                <button on:click={() => removeProduct(p.id)} class="text-emerald-500 hover:text-red-500 font-black text-xs">✕</button>
                            </div>
                        {/each}
                    </div>
                {/if}
                <button
                    on:click={closeProductPicker}
                    class="w-full py-2.5 rounded-xl text-sm font-black bg-emerald-600 text-white hover:bg-emerald-700 transition-colors shadow-sm"
                >
                    ✓ {$locale === 'ar' ? `تأكيد (${selectedProducts.length} منتج)` : `Done (${selectedProducts.length} selected)`}
                </button>
            </div>
        </div>
    </div>
{/if}
