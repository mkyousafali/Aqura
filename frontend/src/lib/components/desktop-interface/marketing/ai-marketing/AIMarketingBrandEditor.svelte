<script lang="ts">
    import { createEventDispatcher, onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    export let brand: any = null;  // null = create new
    export let supabase: any;
    export let userId: string;

    const dispatch = createEventDispatcher();

    const isEdit = !!brand?.id;

    // ── Form state ──────────────────────────────────────────────
    let name             = brand?.name            || '';
    let description      = brand?.description     || '';
    let primaryColor     = brand?.primary_color   || '#059669';
    let secondaryColor   = brand?.secondary_color || '#0f172a';
    let accentColor      = brand?.accent_color    || '#f97316';
    let brandTone        = brand?.brand_tone       || '';
    let marketingStyle   = brand?.marketing_style  || '';
    let rulesText        = brand?.rules?.text      || '';

    // ── Logo ─────────────────────────────────────────────────────
    let logoFile: File | null = null;
    let logoPreviewUrl   = '';
    let existingLogoPath = brand?.logo_url || '';

    // ── Characters ───────────────────────────────────────────────
    let characters: any[] = (brand?.ai_brand_characters || []).map((c: any) => ({ ...c, _isNew: false, _deleted: false }));
    // Signed URLs for existing character images (storage path → signed URL)
    let charSignedUrls: Record<number, string> = {};

    onMount(async () => {
        // Generate signed URL for existing logo
        if (existingLogoPath && !existingLogoPath.startsWith('http')) {
            const { data } = await supabase.storage
                .from('ai-marketing-files')
                .createSignedUrl(existingLogoPath, 3600);
            if (data?.signedUrl) logoPreviewUrl = data.signedUrl;
        }

        // Generate signed URLs for any existing character images
        const toSign = characters.filter(c => c.image_url && !c.image_url.startsWith('http') && !c.image_url.startsWith('blob:'));
        if (!toSign.length) return;
        const entries = await Promise.all(
            toSign.map(async c => {
                const { data } = await supabase.storage
                    .from('ai-marketing-files')
                    .createSignedUrl(c.image_url, 3600);
                return [c.id, data?.signedUrl || ''] as [number, string];
            })
        );
        charSignedUrls = Object.fromEntries(entries.filter(([, url]) => url));
    });

    function getCharDisplayUrl(char: any): string {
        // For new chars with a local blob preview, or edited chars with new file
        if (char._blobPreview) return char._blobPreview;
        // For existing chars, use signed URL if available
        if (char.id && charSignedUrls[char.id]) return charSignedUrls[char.id];
        // Fallback: only return if it's already a full URL (http/blob)
        if (char.image_url && (char.image_url.startsWith('http') || char.image_url.startsWith('blob:'))) return char.image_url;
        return '';
    }

    // ── Tabs ─────────────────────────────────────────────────────
    type TabId = 'info' | 'assets' | 'characters' | 'rules';
    let activeTab: TabId = 'info';

    // ── Save state ───────────────────────────────────────────────
    let saving    = false;
    let saveError = '';

    // ── Character form state ──────────────────────────────────────
    let showCharForm    = false;
    let charEditing: any = null;
    let charName         = '';
    let charRole         = 'custom';
    let charDescription  = '';
    let charVoiceId      = '';
    let charImageFile: File | null = null;
    let charImagePreview = '';

    const charRoles = [
        { value: 'father',      en: 'Dad',         ar: 'أب' },
        { value: 'mother',      en: 'Mom',         ar: 'أم' },
        { value: 'boy',         en: 'Boy',         ar: 'ولد' },
        { value: 'girl',        en: 'Girl',        ar: 'بنت' },
        { value: 'infant',      en: 'Infant',      ar: 'رضيع' },
        { value: 'grandfather', en: 'Grandfather', ar: 'جد' },
        { value: 'grandmother', en: 'Grandmother', ar: 'جدة' },
        { value: 'custom',      en: 'Custom',      ar: 'مخصص' }
    ];

    $: visibleChars = characters.filter(c => !c._deleted);

    function pickLabel(item: { en: string; ar: string }) {
        return $locale === 'ar' ? item.ar : item.en;
    }

    // ── Logo helpers ──────────────────────────────────────────────
    function handleLogoChange(e: Event) {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (!file) return;
        logoFile = file;
        logoPreviewUrl = URL.createObjectURL(file);
    }

    function clearLogo() {
        logoFile = null;
        logoPreviewUrl = '';
        existingLogoPath = '';
    }

    // ── Character helpers ─────────────────────────────────────────
    function handleCharImageChange(e: Event) {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (!file) return;
        charImageFile = file;
        charImagePreview = URL.createObjectURL(file);
    }

    // Store blob preview on character object so list thumbnail updates immediately
    function applyBlobPreviewToChar(char: any, blobUrl: string) {
        characters = characters.map(c => c === char ? { ...c, _blobPreview: blobUrl } : c);
    }

    function openNewChar() {
        charEditing = null;
        charName = ''; charRole = 'custom'; charDescription = ''; charVoiceId = '';
        charImageFile = null; charImagePreview = '';
        showCharForm = true;
    }

    function openEditChar(char: any) {
        charEditing = char;
        charName        = char.name;
        charRole        = char.role || 'custom';
        charDescription = char.description || '';
        charVoiceId     = char.voice_id || '';
        charImageFile   = null;
        // Use blob preview (if already replaced), then signed URL, then nothing
        charImagePreview = char._blobPreview
            || (char.id && charSignedUrls[char.id])
            || (char.image_url?.startsWith('http') ? char.image_url : '')
            || '';
        showCharForm    = true;
    }

    function cancelCharForm() { showCharForm = false; charEditing = null; }

    function saveCharLocal() {
        if (!charName.trim()) return;
        if (charEditing) {
            const blobPreview = charImageFile ? charImagePreview : (charEditing._blobPreview || '');
            characters = characters.map(c =>
                c === charEditing
                    ? { ...c, name: charName, role: charRole, description: charDescription, voice_id: charVoiceId, _imageFile: charImageFile, _blobPreview: blobPreview }
                    : c
            );
        } else {
            characters = [...characters, {
                _isNew: true, name: charName, role: charRole,
                description: charDescription, voice_id: charVoiceId,
                _imageFile: charImageFile,
                image_url: charImagePreview,
                display_order: characters.length
            }];
        }
        showCharForm = false;
        charEditing = null;
    }

    function removeChar(char: any) {
        if (char._isNew) {
            characters = characters.filter(c => c !== char);
        } else {
            characters = characters.map(c => c === char ? { ...c, _deleted: true } : c);
        }
    }

    // ── Storage upload ────────────────────────────────────────────
    async function uploadToStorage(path: string, file: File): Promise<string | null> {
        const { error } = await supabase.storage.from('ai-marketing-files').upload(path, file, { upsert: true });
        if (error) { console.error('[upload]', error); return null; }
        return path;
    }

    // ── Main save ────────────────────────────────────────────────
    async function save() {
        if (!name.trim()) {
            saveError = $locale === 'ar' ? 'الاسم مطلوب' : 'Name is required';
            return;
        }
        saving = true; saveError = '';

        try {
            const payload: Record<string, any> = {
                name:            name.trim(),
                description:     description.trim() || null,
                primary_color:   primaryColor,
                secondary_color: secondaryColor,
                accent_color:    accentColor,
                brand_tone:      brandTone || null,
                marketing_style: marketingStyle || null,
                rules:           rulesText ? { text: rulesText } : null,
                updated_at:      new Date().toISOString()
            };

            let brandId: number;

            if (isEdit) {
                brandId = brand.id;
                const { error } = await supabase.from('ai_brand_libraries').update(payload).eq('id', brandId);
                if (error) throw error;
            } else {
                const { data, error } = await supabase
                    .from('ai_brand_libraries')
                    .insert({ ...payload, created_by: userId })
                    .select('id').single();
                if (error) throw error;
                brandId = data.id;
            }

            // Handle logo
            if (logoFile) {
                const ext = logoFile.name.split('.').pop() || 'png';
                const path = `brand-assets/${brandId}/logo.${ext}`;
                const storagePath = await uploadToStorage(path, logoFile);
                if (storagePath) {
                    await supabase.from('ai_brand_libraries').update({ logo_url: storagePath }).eq('id', brandId);
                }
            } else if (!existingLogoPath && isEdit && brand?.logo_url) {
                await supabase.from('ai_brand_libraries').update({ logo_url: null }).eq('id', brandId);
            }

            // Handle characters — delete removed ones
            const deletedIds = characters.filter(c => !c._isNew && c._deleted).map(c => c.id);
            if (deletedIds.length) {
                await supabase.from('ai_brand_characters').delete().in('id', deletedIds);
            }

            // Upsert remaining + new ones
            for (let i = 0; i < characters.length; i++) {
                const c = characters[i];
                if (c._deleted) continue;

                let imageUrl = c.image_url || null;
                if (c._imageFile) {
                    const ext = c._imageFile.name.split('.').pop() || 'jpg';
                    const path = `brand-assets/${brandId}/char-${Date.now()}-${i}.${ext}`;
                    const uploaded = await uploadToStorage(path, c._imageFile);
                    if (uploaded) imageUrl = uploaded;
                }

                const charPayload: Record<string, any> = {
                    brand_id:     brandId,
                    name:         c.name,
                    role:         c.role || null,
                    description:  c.description || null,
                    voice_id:     c.voice_id || null,
                    image_url:    imageUrl,
                    display_order: i
                };

                if (c._isNew) {
                    await supabase.from('ai_brand_characters').insert(charPayload);
                } else {
                    await supabase.from('ai_brand_characters').update(charPayload).eq('id', c.id);
                }
            }

            dispatch('save');
        } catch (err: any) {
            saveError = err?.message ?? String(err);
        } finally {
            saving = false;
        }
    }

    const modalTabs = [
        { id: 'info',       icon: '📝', en: 'Info',       ar: 'المعلومات' },
        { id: 'assets',     icon: '🎨', en: 'Assets',     ar: 'الأصول' },
        { id: 'characters', icon: '👥', en: 'Characters', ar: 'الشخصيات' },
        { id: 'rules',      icon: '📋', en: 'Rules',      ar: 'القواعد' }
    ] as const;
</script>

<!-- Modal backdrop -->
<div
    class="fixed inset-0 z-50 flex items-center justify-center p-4"
    dir={$locale === 'ar' ? 'rtl' : 'ltr'}
>
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" on:click={() => dispatch('close')}></div>

    <div class="relative bg-white rounded-[2rem] shadow-[0_32px_80px_-8px_rgba(0,0,0,0.25)]
                w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden">

        <!-- Modal Header -->
        <div class="flex items-center justify-between px-6 py-4 border-b border-slate-200 bg-slate-50">
            <div>
                <h2 class="text-lg font-black text-slate-800 tracking-tight">
                    {isEdit
                        ? ($locale === 'ar' ? `تعديل: ${brand.name}` : `Edit: ${brand.name}`)
                        : ($locale === 'ar' ? '🎨 مكتبة علامة تجارية جديدة' : '🎨 New Brand Library')}
                </h2>
                <p class="text-xs text-slate-500 font-semibold mt-0.5">
                    {$locale === 'ar'
                        ? 'الشعار، الألوان، الشخصيات، قواعد العلامة'
                        : 'Logo, colors, characters, brand rules'}
                </p>
            </div>
            <button
                on:click={() => dispatch('close')}
                class="w-8 h-8 rounded-xl bg-slate-200 hover:bg-slate-300 flex items-center justify-center text-slate-600 font-black transition-colors"
            >✕</button>
        </div>

        <!-- Tabs row -->
        <div class="flex gap-1 px-6 pt-3 bg-slate-50 border-b border-slate-200 overflow-x-auto">
            {#each modalTabs as tab}
                <button
                    on:click={() => (activeTab = tab.id as TabId)}
                    class="flex items-center gap-1.5 px-4 py-2 text-xs font-black uppercase tracking-wide rounded-t-xl transition-all whitespace-nowrap
                           {activeTab === tab.id
                               ? 'bg-white text-emerald-700 border-b-2 border-emerald-600 -mb-px'
                               : 'text-slate-500 hover:text-slate-800 hover:bg-slate-100'}"
                >
                    <span>{tab.icon}</span>
                    <span>{$locale === 'ar' ? tab.ar : tab.en}</span>
                    {#if tab.id === 'characters' && visibleChars.length > 0}
                        <span class="px-1.5 py-0.5 bg-emerald-100 text-emerald-700 rounded-full text-[10px] font-black">{visibleChars.length}</span>
                    {/if}
                </button>
            {/each}
        </div>

        <!-- Tab content (scrollable) -->
        <div class="flex-1 overflow-y-auto p-6">

            <!-- ── INFO TAB ── -->
            {#if activeTab === 'info'}
                <div class="space-y-4">
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="b-name">
                            {$locale === 'ar' ? 'اسم المكتبة *' : 'Library Name *'}
                        </label>
                        <input
                            id="b-name" type="text" bind:value={name}
                            placeholder={$locale === 'ar' ? 'مثال: Urban Market الرئيسية' : 'e.g. Urban Market Main'}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm
                                   focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black"
                        />
                    </div>
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="b-desc">
                            {$locale === 'ar' ? 'الوصف' : 'Description'}
                        </label>
                        <textarea
                            id="b-desc" bind:value={description} rows="4"
                            placeholder={$locale === 'ar' ? 'وصف مختصر لهذه المكتبة...' : 'Short description of this brand library...'}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm
                                   focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black resize-none"
                        ></textarea>
                    </div>
                </div>

            <!-- ── ASSETS TAB ── -->
            {:else if activeTab === 'assets'}
                <div class="space-y-6">
                    <!-- Logo upload -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-3 uppercase tracking-wide">
                            {$locale === 'ar' ? 'شعار العلامة (Logo)' : 'Brand Logo'}
                        </label>
                        <div class="flex items-center gap-4">
                            <!-- Preview circle -->
                            <div class="w-20 h-20 rounded-2xl flex items-center justify-center overflow-hidden shadow-md flex-shrink-0"
                                 style="background-color: {primaryColor}">
                                {#if logoPreviewUrl}
                                    <img src={logoPreviewUrl} alt="Logo preview" class="w-full h-full object-cover" />
                                {:else if existingLogoPath}
                                    <span class="text-white text-[10px] font-bold opacity-80 px-1 text-center">
                                        {$locale === 'ar' ? 'شعار موجود' : 'Existing logo'}
                                    </span>
                                {:else}
                                    <span class="text-white font-black text-2xl select-none">{name ? name[0].toUpperCase() : '?'}</span>
                                {/if}
                            </div>
                            <div class="flex-1 space-y-2">
                                <input
                                    type="file" accept="image/*" on:change={handleLogoChange}
                                    class="block w-full text-sm text-slate-500
                                           file:mr-3 file:py-2 file:px-4 file:rounded-xl file:border-0
                                           file:text-xs file:font-bold file:bg-emerald-600 file:text-white hover:file:bg-emerald-700"
                                />
                                {#if existingLogoPath || logoPreviewUrl}
                                    <button on:click={clearLogo} class="text-xs font-bold text-red-500 hover:text-red-700">
                                        {$locale === 'ar' ? '✕ إزالة الشعار' : '✕ Remove logo'}
                                    </button>
                                {/if}
                                <p class="text-[10px] text-slate-400">
                                    {$locale === 'ar' ? 'PNG أو JPG، يُفضّل مربع الشكل' : 'PNG or JPG, square preferred'}
                                </p>
                            </div>
                        </div>
                    </div>

                    <!-- Colors -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-3 uppercase tracking-wide">
                            {$locale === 'ar' ? 'ألوان العلامة التجارية' : 'Brand Colors'}
                        </label>
                        <div class="grid grid-cols-3 gap-4">
                            {#each [
                                { id: 'primary',   labelEn: 'Primary',   labelAr: 'الرئيسي',   bind: 'primaryColor' },
                                { id: 'secondary', labelEn: 'Secondary', labelAr: 'الثانوي',   bind: 'secondaryColor' },
                                { id: 'accent',    labelEn: 'Accent',    labelAr: 'التمييز',   bind: 'accentColor' }
                            ] as colorItem}
                                <div>
                                    <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase" for="c-{colorItem.id}">
                                        {$locale === 'ar' ? colorItem.labelAr : colorItem.labelEn}
                                    </label>
                                    <div class="flex items-center gap-2">
                                        {#if colorItem.id === 'primary'}
                                            <input id="c-{colorItem.id}" type="color" bind:value={primaryColor}
                                                class="w-10 h-10 rounded-xl border border-slate-200 cursor-pointer p-0.5 bg-white" />
                                            <input type="text" bind:value={primaryColor}
                                                class="flex-1 px-2 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-mono text-black focus:outline-none focus:ring-1 focus:ring-emerald-500" />
                                        {:else if colorItem.id === 'secondary'}
                                            <input id="c-{colorItem.id}" type="color" bind:value={secondaryColor}
                                                class="w-10 h-10 rounded-xl border border-slate-200 cursor-pointer p-0.5 bg-white" />
                                            <input type="text" bind:value={secondaryColor}
                                                class="flex-1 px-2 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-mono text-black focus:outline-none focus:ring-1 focus:ring-emerald-500" />
                                        {:else}
                                            <input id="c-{colorItem.id}" type="color" bind:value={accentColor}
                                                class="w-10 h-10 rounded-xl border border-slate-200 cursor-pointer p-0.5 bg-white" />
                                            <input type="text" bind:value={accentColor}
                                                class="flex-1 px-2 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-mono text-black focus:outline-none focus:ring-1 focus:ring-emerald-500" />
                                        {/if}
                                    </div>
                                </div>
                            {/each}
                        </div>
                        <!-- Color preview bar -->
                        <div class="mt-4 h-8 rounded-xl overflow-hidden flex shadow-inner">
                            <div class="flex-1" style="background:{primaryColor}"></div>
                            <div class="flex-1" style="background:{secondaryColor}"></div>
                            <div class="flex-1" style="background:{accentColor}"></div>
                        </div>
                    </div>
                </div>

            <!-- ── CHARACTERS TAB ── -->
            {:else if activeTab === 'characters'}
                <div class="space-y-3">
                    {#if !showCharForm}
                        <!-- List -->
                        {#each visibleChars as char (char._isNew ? char.name + char.display_order : char.id)}
                            <div class="flex items-center gap-3 p-3 bg-slate-50 rounded-2xl border border-slate-200">
                                <div class="w-10 h-10 rounded-xl flex items-center justify-center overflow-hidden flex-shrink-0 shadow-sm"
                                     style="background:{primaryColor}">
                                    {#if getCharDisplayUrl(char)}
                                        <img src={getCharDisplayUrl(char)} alt={char.name} class="w-full h-full object-cover" />
                                    {:else}
                                        <span class="text-white font-black text-sm select-none">{char.name[0]}</span>
                                    {/if}
                                </div>
                                <div class="flex-1 min-w-0">
                                    <div class="font-black text-slate-800 text-sm">{char.name}</div>
                                    <div class="text-xs text-slate-500 font-semibold capitalize">
                                        {charRoles.find(r => r.value === char.role)?.[($locale === 'ar' ? 'ar' : 'en')] ?? char.role ?? '—'}
                                    </div>
                                </div>
                                <button
                                    on:click={() => openEditChar(char)}
                                    class="px-3 py-1.5 rounded-xl text-xs font-black bg-emerald-100 text-emerald-700 hover:bg-emerald-200 transition-colors"
                                >✏️</button>
                                <button
                                    on:click={() => removeChar(char)}
                                    class="px-3 py-1.5 rounded-xl text-xs font-black bg-red-50 text-red-600 hover:bg-red-100 transition-colors"
                                >🗑️</button>
                            </div>
                        {/each}

                        {#if visibleChars.length === 0}
                            <div class="py-8 text-center text-slate-500 text-sm font-semibold">
                                {$locale === 'ar' ? 'لا توجد شخصيات بعد — أضف شخصيتك الأولى' : 'No characters yet — add your first one'}
                            </div>
                        {/if}

                        <button
                            on:click={openNewChar}
                            class="w-full py-3 rounded-2xl border-2 border-dashed border-emerald-300
                                   text-emerald-700 text-sm font-black hover:bg-emerald-50 transition-colors"
                        >
                            + {$locale === 'ar' ? 'إضافة شخصية' : 'Add Character'}
                        </button>

                    {:else}
                        <!-- Character form -->
                        <div class="bg-emerald-50/60 rounded-2xl border border-emerald-200 p-5 space-y-4">
                            <h4 class="font-black text-slate-700 text-sm">
                                {charEditing
                                    ? ($locale === 'ar' ? 'تعديل الشخصية' : 'Edit Character')
                                    : ($locale === 'ar' ? 'شخصية جديدة' : 'New Character')}
                            </h4>
                            <div class="grid grid-cols-2 gap-3">
                                <div>
                                    <label class="block text-[10px] font-bold text-slate-500 mb-1 uppercase" for="ch-name">
                                        {$locale === 'ar' ? 'الاسم *' : 'Name *'}
                                    </label>
                                    <input
                                        id="ch-name" type="text" bind:value={charName}
                                        placeholder={$locale === 'ar' ? 'محمد، ليلى، سارة...' : 'Mohammed, Layla, Sara...'}
                                        class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm
                                               focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black"
                                    />
                                </div>
                                <div>
                                    <label class="block text-[10px] font-bold text-slate-500 mb-1 uppercase" for="ch-role">
                                        {$locale === 'ar' ? 'الدور' : 'Role'}
                                    </label>
                                    <select
                                        id="ch-role" bind:value={charRole}
                                        class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm
                                               focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                        style="color:#000 !important; background-color:#fff !important;"
                                    >
                                        {#each charRoles as r}
                                            <option value={r.value} style="color:#000 !important;">{pickLabel(r)}</option>
                                        {/each}
                                    </select>
                                </div>
                            </div>

                            <div>
                                <label class="block text-[10px] font-bold text-slate-500 mb-1 uppercase" for="ch-desc">
                                    {$locale === 'ar' ? 'الوصف (صفات، شخصية)' : 'Description (traits, personality)'}
                                </label>
                                <textarea
                                    id="ch-desc" bind:value={charDescription} rows="2"
                                    class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm
                                           focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black resize-none"
                                ></textarea>
                            </div>

                            <div class="grid grid-cols-2 gap-3">
                                <div>
                                    <label class="block text-[10px] font-bold text-slate-500 mb-1 uppercase" for="ch-voice">
                                        {$locale === 'ar' ? 'معرف الصوت (TTS)' : 'Voice ID (TTS)'}
                                    </label>
                                    <input
                                        id="ch-voice" type="text" bind:value={charVoiceId}
                                        placeholder="ar-XA-Wavenet-A"
                                        class="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-sm
                                               focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black font-mono"
                                    />
                                </div>
                                <div>
                                    <label class="block text-[10px] font-bold text-slate-500 mb-1 uppercase" for="ch-image">
                                        {$locale === 'ar' ? 'صورة الشخصية' : 'Character Image'}
                                    </label>
                                    <input
                                        id="ch-image" type="file" accept="image/*" on:change={handleCharImageChange}
                                        class="w-full text-xs text-slate-500
                                               file:mr-2 file:py-1.5 file:px-3 file:rounded-lg file:border-0
                                               file:text-xs file:font-bold file:bg-emerald-600 file:text-white hover:file:bg-emerald-700"
                                    />
                                    {#if charImagePreview}
                                        <img src={charImagePreview} alt="preview" class="mt-2 w-10 h-10 rounded-xl object-cover border border-slate-200" />
                                    {/if}
                                </div>
                            </div>

                            <div class="flex justify-end gap-2 pt-1">
                                <button
                                    on:click={cancelCharForm}
                                    class="px-4 py-2 rounded-xl text-xs font-black bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors"
                                >
                                    {$locale === 'ar' ? 'إلغاء' : 'Cancel'}
                                </button>
                                <button
                                    on:click={saveCharLocal}
                                    disabled={!charName.trim()}
                                    class="px-4 py-2 rounded-xl text-xs font-black bg-emerald-600 text-white hover:bg-emerald-700 transition-colors disabled:opacity-50"
                                >
                                    {$locale === 'ar' ? 'حفظ الشخصية' : 'Save Character'}
                                </button>
                            </div>
                        </div>
                    {/if}
                </div>

            <!-- ── RULES TAB ── -->
            {:else if activeTab === 'rules'}
                <div class="space-y-4">
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="b-tone">
                            {$locale === 'ar' ? 'نبرة العلامة' : 'Brand Tone'}
                        </label>
                        <input
                            id="b-tone" type="text" bind:value={brandTone}
                            placeholder={$locale === 'ar' ? 'مثال: ودية، عائلية، موثوقة' : 'e.g. Friendly, family-oriented, trustworthy'}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm
                                   focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black"
                        />
                    </div>
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="b-style">
                            {$locale === 'ar' ? 'أسلوب التسويق' : 'Marketing Style'}
                        </label>
                        <input
                            id="b-style" type="text" bind:value={marketingStyle}
                            placeholder={$locale === 'ar' ? 'مثال: مُركّز على القيمة، عروض واضحة' : 'e.g. Value-focused, clear and concise offers'}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm
                                   focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black"
                        />
                    </div>
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="b-rules">
                            {$locale === 'ar'
                                ? 'قواعد ثابتة (تُرسل للذكاء الاصطناعي في كل عملية إنشاء)'
                                : 'Fixed Rules (sent to AI with every generation for this brand)'}
                        </label>
                        <textarea
                            id="b-rules" bind:value={rulesText} rows="10"
                            placeholder={$locale === 'ar'
                                ? 'مثال:\n- لا تستخدم شعار المنافسين\n- دائماً اذكر "Urban Market"\n- تجنّب الكلمات المحظورة'
                                : 'Example:\n- Never use competitor logos\n- Always mention "Urban Market"\n- No forbidden content'}
                            class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-sm
                                   focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black font-mono resize-none leading-relaxed"
                        ></textarea>
                    </div>
                </div>
            {/if}
        </div>

        <!-- Modal footer -->
        <div class="px-6 py-4 border-t border-slate-200 bg-slate-50 flex items-center gap-3">
            {#if saveError}
                <span class="text-xs font-bold text-red-700 flex-1">❌ {saveError}</span>
            {:else}
                <span class="flex-1"></span>
            {/if}
            <button
                on:click={() => dispatch('close')}
                class="px-5 py-2.5 rounded-xl text-sm font-black bg-slate-200 text-slate-700 hover:bg-slate-300 transition-colors"
            >
                {$locale === 'ar' ? 'إلغاء' : 'Cancel'}
            </button>
            <button
                on:click={save}
                disabled={saving || !name.trim()}
                class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-black
                       bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700
                       transition-all disabled:opacity-50 disabled:cursor-not-allowed transform hover:scale-105"
            >
                {#if saving}
                    <span class="inline-block w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin"></span>
                    <span>{$locale === 'ar' ? 'جارٍ الحفظ...' : 'Saving...'}</span>
                {:else}
                    <span>💾</span>
                    <span>{isEdit
                        ? ($locale === 'ar' ? 'حفظ التعديلات' : 'Save Changes')
                        : ($locale === 'ar' ? 'إنشاء المكتبة' : 'Create Library')}</span>
                {/if}
            </button>
        </div>
    </div>
</div>
