<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';

    let supabase: any = null;

    // ── Brand ────────────────────────────────────────────────────────────
    let brands: any[] = [];
    let selectedBrandId: number | null = null;
    $: selectedBrand = brands.find(b => b.id === selectedBrandId) || null;

    // ── Platform ──────────────────────────────────────────────────────────
    const platforms = [
        { id: 'instagram_feed',  icon: '📸', en: 'Instagram Feed',  ar: 'إنستغرام',       ratio: '1:1'  },
        { id: 'instagram_story', icon: '📱', en: 'Insta Story',     ar: 'قصة إنستغرام',   ratio: '9:16' },
        { id: 'facebook',        icon: '👤', en: 'Facebook',        ar: 'فيسبوك',          ratio: '16:9' },
        { id: 'twitter',         icon: '🐦', en: 'Twitter / X',     ar: 'تويتر',           ratio: '16:9' },
        { id: 'whatsapp',        icon: '💬', en: 'WhatsApp Status', ar: 'واتساب',          ratio: '9:16' },
        { id: 'tiktok',          icon: '🎵', en: 'TikTok',          ar: 'تيك توك',         ratio: '9:16' },
        { id: 'custom',          icon: '⚙️', en: 'Custom',          ar: 'مخصص',            ratio: '1:1'  }
    ];
    const ratioOptions = ['1:1', '9:16', '16:9', '4:5', '3:4'];
    let selectedPlatformId = 'instagram_feed';
    $: selectedPlatform = platforms.find(p => p.id === selectedPlatformId) || platforms[0];
    let aspectRatio = '1:1';
    $: if (selectedPlatformId !== 'custom') aspectRatio = selectedPlatform.ratio;

    // ── Characters ────────────────────────────────────────────────────────
    let characters: any[] = [];
    let selectedCharacterIds: Set<number> = new Set();
    let charSignedUrls: Record<number, string> = {};

    async function loadCharacters(brandId: number | null) {
        characters = []; selectedCharacterIds = new Set(); charSignedUrls = {};
        if (!brandId || !supabase) return;
        const { data } = await supabase
            .from('ai_brand_characters')
            .select('id, name, role, description, ai_prompt, image_url')
            .eq('brand_id', brandId)
            .order('display_order', { ascending: true });
        characters = data || [];
        // Generate signed URLs for character images
        for (const c of characters) {
            if (c.image_url && !c.image_url.startsWith('http') && !c.image_url.startsWith('blob:')) {
                const { data: signed } = await supabase.storage.from('ai-marketing-files').createSignedUrl(c.image_url, 300);
                if (signed?.signedUrl) charSignedUrls[c.id] = signed.signedUrl;
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

    // ── Language ──────────────────────────────────────────────────────────
    let language: 'ar' | 'en' = 'ar';

    // ── Prompt ────────────────────────────────────────────────────────────
    let prompt = '';

    // ── Background image upload ──────────────────────────────────────────
    let bgFile: File | null = null;
    let bgPreviewUrl: string | null = null;
    let bgDescription: string = '';
    let bgDescribing = false;
    let bgError = '';

    async function fileToBase64(file: File): Promise<{ b64: string; mimeType: string }> {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const dataUrl = String(reader.result || '');
                const comma = dataUrl.indexOf(',');
                const meta = dataUrl.substring(5, comma); // e.g. image/jpeg;base64
                const mimeType = meta.split(';')[0] || 'image/jpeg';
                const b64 = dataUrl.substring(comma + 1);
                resolve({ b64, mimeType });
            };
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    async function onBgChange(e: Event) {
        const input = e.target as HTMLInputElement;
        const file = input.files?.[0];
        if (!file) return;
        bgFile = file;
        bgError = '';
        bgDescription = '';
        if (bgPreviewUrl) URL.revokeObjectURL(bgPreviewUrl);
        bgPreviewUrl = URL.createObjectURL(file);
        bgDescribing = true;
        try {
            const { b64, mimeType } = await fileToBase64(file);
            const res = await fetch('https://supabase.urbanaqura.com/functions/v1/describe-image', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ imageB64: b64, mimeType, language })
            });
            const data = await res.json();
            if (!data.ok) throw new Error(data.error || 'Describe failed');
            bgDescription = String(data.description || '').trim();
        } catch (err: any) {
            bgError = err?.message ?? String(err);
            bgFile = null;
            if (bgPreviewUrl) { URL.revokeObjectURL(bgPreviewUrl); bgPreviewUrl = null; }
        } finally {
            bgDescribing = false;
        }
    }

    function clearBg() {
        bgFile = null;
        if (bgPreviewUrl) { URL.revokeObjectURL(bgPreviewUrl); bgPreviewUrl = null; }
        bgDescription = '';
        bgError = '';
    }

    // ── State ─────────────────────────────────────────────────────────────
    let generating = false;
    let errorMessage = '';
    let generatedUrl: string | null = null;
    let generatedPrompt: string | null = null;

    // ── Drag reposition ───────────────────────────────────────────────────
    let imgOffsetX = 0; let imgOffsetY = 0;
    let dragging = false;
    let dragStartX = 0; let dragStartY = 0;
    let dragStartOffX = 0; let dragStartOffY = 0;
    $: if (generatedUrl) { imgOffsetX = 0; imgOffsetY = 0; }
    function onDragStart(e: MouseEvent | TouchEvent) {
        dragging = true;
        const pt = 'touches' in e ? e.touches[0] : e;
        dragStartX = pt.clientX; dragStartY = pt.clientY;
        dragStartOffX = imgOffsetX; dragStartOffY = imgOffsetY;
        e.preventDefault();
    }
    function onDragMove(e: MouseEvent | TouchEvent) {
        if (!dragging) return;
        const pt = 'touches' in e ? e.touches[0] : e;
        imgOffsetX = dragStartOffX + (pt.clientX - dragStartX);
        imgOffsetY = dragStartOffY + (pt.clientY - dragStartY);
    }
    function onDragEnd() { dragging = false; }

    // ── History ───────────────────────────────────────────────────────────
    let history: Array<{ url: string; prompt: string }> = [];

    $: userId = $currentUser?.id;

    $: previewAspect = ({
        '1:1': 'aspect-square', '9:16': 'aspect-[9/16]', '16:9': 'aspect-video',
        '4:5': 'aspect-[4/5]', '3:4': 'aspect-[3/4]'
    } as Record<string,string>)[aspectRatio] || 'aspect-square';

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        const { data } = await supabase
            .from('ai_brand_libraries')
            .select('id, name, primary_color, accent_color, brand_tone, rules, logo_url, is_default')
            .eq('is_archived', false)
            .order('is_default', { ascending: false });
        brands = data || [];
        const def = brands.find((b: any) => b.is_default);
        if (def) selectedBrandId = def.id;
        else if (brands.length) selectedBrandId = brands[0].id;
    });

    $: if (supabase && selectedBrandId !== undefined) loadCharacters(selectedBrandId);

    async function generate() {
        if (generating || !prompt.trim()) return;
        generating = true; errorMessage = ''; generatedUrl = null; generatedPrompt = null;
        try {
            // Send character prompts (NOT images) for consistent design every time
            const characterPayload = selectedCharacters.map((c: any) => ({
                name: c.name,
                role: c.role,
                description: c.description,
                ai_prompt: c.ai_prompt
            }));

            const brandPayload = selectedBrand ? {
                id: selectedBrand.id,
                name: selectedBrand.name,
                primary_color: selectedBrand.primary_color,
                accent_color: selectedBrand.accent_color,
                brand_tone: selectedBrand.brand_tone,
                rules: selectedBrand.rules
            } : null;

            const res = await fetch('https://supabase.urbanaqura.com/functions/v1/ai-generate-poster', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    extraPrompt: prompt.trim(),
                    language,
                    aspectRatio,
                    platform: selectedPlatformId,
                    brand: brandPayload,
                    characters: characterPayload,
                    backgroundDescription: bgDescription.trim() || null
                })
            });
            const data = await res.json();
            if (!data.ok) {
                errorMessage = `[${data.stage ?? 'error'}] ${data.error}`;
                return;
            }
            // Composite brand logo on top using Canvas (so logo is exact, not AI-redrawn)
            const finalDataUrl = await compositeLogo(
                `data:image/png;base64,${data.imageB64}`,
                selectedBrand?.logo_url ?? null,
                language
            );
            generatedUrl = finalDataUrl;
            generatedPrompt = data.imagePrompt ?? prompt.trim();
            history = [{ url: finalDataUrl, prompt: prompt.trim() }, ...history].slice(0, 5);
        } catch (err: any) {
            errorMessage = err?.message ?? String(err);
        } finally {
            generating = false;
        }
    }

    async function compositeLogo(
        baseImageDataUrl: string,
        logoStoragePath: string | null,
        lang: 'ar' | 'en'
    ): Promise<string> {
        if (!logoStoragePath || !supabase) return baseImageDataUrl;
        try {
            // Resolve logo URL
            let logoUrl: string;
            if (logoStoragePath.startsWith('http') || logoStoragePath.startsWith('blob:')) {
                logoUrl = logoStoragePath;
            } else {
                const { data: signed } = await supabase.storage
                    .from('ai-marketing-files')
                    .createSignedUrl(logoStoragePath, 300);
                if (!signed?.signedUrl) return baseImageDataUrl;
                logoUrl = signed.signedUrl;
            }

            // Load both images
            const [baseImg, logoImg] = await Promise.all([
                loadImage(baseImageDataUrl),
                loadImage(logoUrl)
            ]);

            // Draw to canvas
            const canvas = document.createElement('canvas');
            canvas.width = baseImg.width;
            canvas.height = baseImg.height;
            const ctx = canvas.getContext('2d');
            if (!ctx) return baseImageDataUrl;

            ctx.drawImage(baseImg, 0, 0);

            // Logo sizing/position (matches original Vercel API logic)
            const W = canvas.width;
            const logoSize = Math.round(W * 0.13);
            const logoPad = Math.round(W * 0.025);
            const bgPadding = Math.round(logoSize * 0.18);
            const bgSize = logoSize + bgPadding * 2;
            const logoLeft = lang === 'ar' ? W - logoSize - logoPad : logoPad;
            const logoTop = logoPad;
            const bgLeft = Math.max(0, logoLeft - bgPadding);
            const bgTop = Math.max(0, logoTop - bgPadding);
            const bgRadius = Math.round(bgSize * 0.16);

            // White rounded backing
            ctx.fillStyle = '#ffffff';
            roundRect(ctx, bgLeft, bgTop, bgSize, bgSize, bgRadius);
            ctx.fill();

            // Logo image (preserve aspect ratio, fit inside logoSize x logoSize)
            const ratio = Math.min(logoSize / logoImg.width, logoSize / logoImg.height);
            const drawW = logoImg.width * ratio;
            const drawH = logoImg.height * ratio;
            const drawL = logoLeft + (logoSize - drawW) / 2;
            const drawT = logoTop + (logoSize - drawH) / 2;
            ctx.drawImage(logoImg, drawL, drawT, drawW, drawH);

            return canvas.toDataURL('image/png');
        } catch (err) {
            console.warn('[compositeLogo] failed:', err);
            return baseImageDataUrl;
        }
    }

    function loadImage(src: string): Promise<HTMLImageElement> {
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.crossOrigin = 'anonymous';
            img.onload = () => resolve(img);
            img.onerror = reject;
            img.src = src;
        });
    }

    function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + r);
        ctx.lineTo(x + w, y + h - r);
        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
        ctx.lineTo(x + r, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - r);
        ctx.lineTo(x, y + r);
        ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.closePath();
    }

    async function downloadImage() {
        if (!generatedUrl) return;
        try {
            const res = await fetch(generatedUrl);
            const blob = await res.blob();
            const blobUrl = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = blobUrl; a.download = `image-${Date.now()}.png`; a.click();
            setTimeout(() => URL.revokeObjectURL(blobUrl), 5000);
        } catch {
            window.open(generatedUrl, '_blank');
        }
    }
</script>

<div class="w-full" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <div class="grid grid-cols-1 xl:grid-cols-[380px_1fr] gap-6">

        <!-- ══ LEFT — Controls ══════════════════════════════════════════════ -->
        <div class="space-y-4">

            <div>
                <h2 class="text-xl font-black text-slate-800 tracking-tight">🖼️ {$locale === 'ar' ? 'إنشاء صورة' : 'Create Image'}</h2>
                <p class="text-xs font-semibold text-slate-500 mt-0.5">{$locale === 'ar' ? 'اختر الهوية والمنصة واكتب الفكرة' : 'Pick brand, platform and describe your idea'}</p>
            </div>

            <!-- Brand -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-2">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">🎨 {$locale === 'ar' ? 'الهوية التجارية' : 'Branding Profile'}</label>
                <select bind:value={selectedBrandId}
                    class="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-emerald-500"
                    style="color:#000 !important;">
                    <option value={null} style="color:#000 !important;">{$locale === 'ar' ? '— اختر هوية —' : '— Select Profile —'}</option>
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
                    <p class="text-[10px] text-slate-400 font-semibold -mt-1">
                        {$locale === 'ar' ? 'اختر شخصية أو أكثر لتظهر في الصورة' : 'Select one or more characters to appear in the image'}
                    </p>
                    <div class="grid grid-cols-2 gap-2">
                        {#each characters as char}
                            {@const isSelected = selectedCharacterIds.has(char.id)}
                            <button on:click={() => toggleCharacter(char.id)}
                                class="flex items-center gap-2.5 p-2.5 rounded-xl border-2 transition-all text-left
                                       {isSelected ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 bg-white hover:border-emerald-300'}">
                                <div class="relative flex-shrink-0 w-10 h-10 rounded-lg overflow-hidden bg-slate-100 border border-slate-200">
                                    {#if charSignedUrls[char.id]}
                                        <img src={charSignedUrls[char.id]} alt={char.name} class="w-full h-full object-cover"/>
                                    {:else}
                                        <div class="w-full h-full flex items-center justify-center text-xl">🧑</div>
                                    {/if}
                                    {#if isSelected}
                                        <div class="absolute inset-0 flex items-center justify-center bg-emerald-600/70 rounded-lg">
                                            <span class="text-white text-sm font-black">✓</span>
                                        </div>
                                    {/if}
                                </div>
                                <div class="min-w-0 flex-1">
                                    <p class="text-xs font-black text-slate-700 truncate leading-tight">{char.name}</p>
                                    {#if char.role}
                                        <p class="text-[9px] font-bold text-slate-400 truncate">{char.role}</p>
                                    {/if}
                                    {#if char.description}
                                        <p class="text-[9px] text-slate-400 leading-snug line-clamp-2 mt-0.5">{char.description}</p>
                                    {/if}
                                </div>
                            </button>
                        {/each}
                    </div>
                    {#if selectedCharacterIds.size > 0}
                        <p class="text-[9px] font-black text-emerald-600 bg-emerald-50 rounded-lg px-2 py-1.5">
                            ✓ {$locale === 'ar'
                                ? `${selectedCharacterIds.size} شخصية محددة — سيتم تضمين وصفها في الصورة`
                                : `${selectedCharacterIds.size} character(s) selected — their descriptions will guide the AI`}
                        </p>
                    {/if}
                </div>
            {/if}

            <!-- Language -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-2">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">🌐 {$locale === 'ar' ? 'لغة الصورة' : 'Image Language'}</label>
                <div class="flex gap-2">
                    <button on:click={() => (language = 'ar')}
                        class="flex-1 py-2 rounded-xl text-xs font-black border-2 transition-all {language === 'ar' ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-500 hover:border-slate-300'}">
                        🇸🇦 عربي</button>
                    <button on:click={() => (language = 'en')}
                        class="flex-1 py-2 rounded-xl text-xs font-black border-2 transition-all {language === 'en' ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-500 hover:border-slate-300'}">
                        🇬🇧 English</button>
                </div>
            </div>

            <!-- Platform -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-3">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">📲 {$locale === 'ar' ? 'المنصة' : 'Platform'}</label>
                <div class="grid grid-cols-4 gap-2">
                    {#each platforms as pl}
                        <button on:click={() => (selectedPlatformId = pl.id)}
                            class="flex flex-col items-center gap-1 p-2 rounded-xl border-2 transition-all text-center
                                   {selectedPlatformId === pl.id ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 bg-white hover:border-emerald-300'}">
                            <span class="text-xl">{pl.icon}</span>
                            <span class="text-[9px] font-black text-slate-600 leading-tight">{$locale === 'ar' ? pl.ar : pl.en}</span>
                            <span class="text-[8px] font-bold text-slate-400">{pl.ratio}</span>
                        </button>
                    {/each}
                </div>
                {#if selectedPlatformId === 'custom'}
                    <div class="flex gap-2 flex-wrap">
                        {#each ratioOptions as r}
                            <button on:click={() => (aspectRatio = r)}
                                class="px-3 py-1 rounded-lg text-xs font-black border-2 transition-all
                                       {aspectRatio === r ? 'border-emerald-500 bg-emerald-50 text-emerald-700' : 'border-slate-200 text-slate-500'}">
                                {r}</button>
                        {/each}
                    </div>
                {/if}
            </div>

            <!-- Prompt -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-2">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">✍️ {$locale === 'ar' ? 'فكرتك' : 'Your Idea'}</label>
                <textarea bind:value={prompt} rows="5"
                    placeholder={$locale === 'ar'
                        ? 'مثال: ملصق عروض رمضان بألوان ذهبية، نجوم لامعة، أجواء احتفالية...'
                        : 'e.g. Ramadan offers poster with gold colors, shining stars, festive atmosphere...'}
                    class="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black resize-none leading-relaxed"
                ></textarea>
                <p class="text-[10px] text-slate-400 font-semibold">{$locale === 'ar' ? 'اكتب وصفاً للصورة التي تريدها — الذكاء الاصطناعي سيحوّلها إلى تصميم احترافي' : 'Describe the image you want — AI will turn it into a professional design'}</p>
            </div>

            <!-- Background image upload (optional) -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-3">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">🖼️ {$locale === 'ar' ? 'صورة الخلفية (اختياري)' : 'Background Image (optional)'}</label>
                <p class="text-[10px] text-slate-400 font-semibold -mt-1">
                    {$locale === 'ar' ? 'ارفع صورة لاستخدامها كخلفية للمشهد — سيقوم الذكاء الاصطناعي بوصفها وإعادة توليدها' : 'Upload a photo to use as the background scene — AI will describe it and recreate the setting'}
                </p>
                {#if !bgPreviewUrl}
                    <label class="flex flex-col items-center justify-center gap-2 px-3 py-6 border-2 border-dashed border-slate-300 rounded-xl cursor-pointer hover:border-emerald-400 hover:bg-emerald-50/50 transition-all">
                        <span class="text-3xl">📷</span>
                        <span class="text-xs font-black text-slate-500">{$locale === 'ar' ? 'انقر لرفع صورة' : 'Click to upload image'}</span>
                        <span class="text-[10px] text-slate-400 font-semibold">JPG / PNG / WEBP</span>
                        <input type="file" accept="image/jpeg,image/png,image/webp" class="hidden" on:change={onBgChange} />
                    </label>
                {:else}
                    <div class="relative rounded-xl overflow-hidden border-2 border-emerald-500 bg-slate-100">
                        <img src={bgPreviewUrl} alt="Background" class="w-full h-32 object-cover"/>
                        <button on:click={clearBg} class="absolute top-1.5 right-1.5 w-7 h-7 rounded-full bg-red-500/90 text-white text-xs font-black shadow-md hover:bg-red-600 transition-all">✕</button>
                    </div>
                    {#if bgDescribing}
                        <div class="flex items-center gap-2 px-3 py-2 bg-amber-50 rounded-lg">
                            <span class="inline-block w-3 h-3 border-t-amber-600 rounded-full animate-spin" style="border:2px solid rgba(217,119,6,0.3); border-top-color:#d97706;"></span>
                            <span class="text-[10px] font-black text-amber-700">{$locale === 'ar' ? 'جارٍ تحليل الخلفية...' : 'Analyzing background...'}</span>
                        </div>
                    {:else if bgDescription}
                        <div class="px-3 py-2 bg-emerald-50 rounded-lg">
                            <p class="text-[10px] font-black text-emerald-700 mb-1">✓ {$locale === 'ar' ? 'تم التحليل' : 'Analyzed'}</p>
                            <p class="text-[10px] text-slate-600 leading-relaxed line-clamp-3">{bgDescription}</p>
                        </div>
                    {/if}
                    {#if bgError}
                        <p class="text-[10px] font-black text-red-600 bg-red-50 rounded-lg px-2 py-1.5">⚠ {bgError}</p>
                    {/if}
                {/if}
            </div>

            <!-- Generate -->
            <button on:click={generate}
                disabled={generating || !prompt.trim() || !selectedBrandId}
                class="w-full py-4 rounded-2xl text-sm font-black uppercase tracking-widest transition-all transform
                       {(!generating && prompt.trim() && selectedBrandId)
                           ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 hover:scale-[1.02] active:scale-[0.98]'
                           : 'bg-slate-200 text-slate-400 cursor-not-allowed'}">
                {#if generating}
                    <span class="flex items-center justify-center gap-3">
                        <span class="inline-block w-5 h-5 border-t-white rounded-full animate-spin" style="border:3px solid rgba(255,255,255,0.35); border-top-color:#fff;"></span>
                        <span>{$locale === 'ar' ? 'جارٍ الإنشاء...' : 'Generating...'}</span>
                    </span>
                {:else}
                    ✨ {$locale === 'ar' ? 'إنشاء الصورة' : 'Generate Image'}
                {/if}
            </button>
        </div>

        <!-- ══ RIGHT — Preview ══════════════════════════════════════════════ -->
        <div class="space-y-4">
            <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-6">
                <div class="flex items-center justify-between mb-4">
                    <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide">🖼️ {$locale === 'ar' ? 'معاينة' : 'Preview'}</h3>
                    {#if generatedUrl}
                        <button on:click={downloadImage}
                            class="px-4 py-2 rounded-xl text-xs font-black bg-emerald-600 text-white hover:bg-emerald-700 transition-colors shadow-sm">
                            ⬇️ {$locale === 'ar' ? 'تنزيل' : 'Download'}
                        </button>
                    {/if}
                </div>

                <div class="flex items-center justify-center bg-slate-50 rounded-2xl overflow-hidden min-h-[340px] p-4">
                    {#if generating}
                        <div class="flex flex-col items-center gap-4">
                            <div class="relative w-16 h-16">
                                <div class="absolute inset-0 border-4 border-emerald-200 rounded-full animate-ping opacity-30"></div>
                                <div class="absolute inset-0 border-4 border-emerald-300 border-t-emerald-600 rounded-full animate-spin"></div>
                                <div class="absolute inset-0 flex items-center justify-center text-2xl">🎨</div>
                            </div>
                            <div class="text-center">
                                <p class="font-black text-slate-700 text-sm">{$locale === 'ar' ? 'الذكاء الاصطناعي يرسم صورتك...' : 'AI is painting your image...'}</p>
                                <p class="text-xs text-slate-400 font-semibold mt-1">{$locale === 'ar' ? '15–45 ثانية' : '15–45 seconds'}</p>
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
                            <div class="rounded-2xl overflow-hidden shadow-xl max-w-md w-full mx-auto {previewAspect} relative select-none"
                                 style="cursor:{dragging ? 'grabbing' : 'grab'};"
                                 on:mousedown={onDragStart} on:mousemove={onDragMove}
                                 on:mouseup={onDragEnd} on:mouseleave={onDragEnd}
                                 on:touchstart={onDragStart} on:touchmove={onDragMove} on:touchend={onDragEnd}>
                                <img src={generatedUrl} alt="Generated"
                                     class="w-full h-full object-contain bg-white pointer-events-none"
                                     style="transform:translate({imgOffsetX}px,{imgOffsetY}px); transition:{dragging ? 'none' : 'transform 0.15s ease'};"
                                     draggable="false"/>
                                <div class="absolute bottom-2 left-1/2 -translate-x-1/2 px-2 py-0.5 rounded-full bg-black/40 text-white text-[9px] font-bold pointer-events-none whitespace-nowrap">
                                    {$locale === 'ar' ? 'اسحب للتحريك' : 'Drag to reposition'}
                                </div>
                            </div>
                            {#if generatedPrompt}
                                <details class="w-full text-left max-w-md">
                                    <summary class="text-xs font-bold text-slate-400 cursor-pointer hover:text-slate-600">📝 {$locale === 'ar' ? 'البرومبت' : 'Prompt used'}</summary>
                                    <p class="text-xs text-slate-600 mt-2 bg-slate-50 rounded-xl p-3 break-words font-mono leading-relaxed">{generatedPrompt}</p>
                                </details>
                            {/if}
                        </div>
                    {:else}
                        <div class="flex flex-col items-center gap-3 text-center">
                            <div class="text-6xl opacity-20">🖼️</div>
                            <p class="text-sm font-black text-slate-400">{$locale === 'ar' ? 'ستظهر الصورة هنا' : 'Image will appear here'}</p>
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
                            <button class="rounded-xl overflow-hidden bg-slate-100 aspect-square shadow-sm hover:shadow-md transition-shadow"
                                    on:click={() => { generatedUrl = item.url; generatedPrompt = item.prompt; }}>
                                <img src={item.url} alt={item.prompt} class="w-full h-full object-cover"/>
                            </button>
                        {/each}
                    </div>
                </div>
            {/if}
        </div>
    </div>
</div>
