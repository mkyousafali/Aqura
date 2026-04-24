<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';
    import AIMarketingBrandEditor from './AIMarketingBrandEditor.svelte';

    let supabase: any = null;
    let loading = true;
    let brands: any[] = [];
    let favoriteBrandIds: number[] = [];
    let logoUrls: Record<number, string> = {};

    // Modal
    let showEditor = false;
    let editingBrand: any = null;

    // Filter
    let searchQuery = '';
    let showArchived = false;

    $: filteredBrands = brands
        .filter(b => showArchived || !b.is_archived)
        .filter(b => !searchQuery || b.name.toLowerCase().includes(searchQuery.toLowerCase()))
        .sort((a, b) => (b.is_default ? 1 : 0) - (a.is_default ? 1 : 0));

    $: isMasterAdmin = $currentUser?.isMasterAdmin;
    $: userId = $currentUser?.id;

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await Promise.all([loadBrands(), loadUserPrefs()]);
    });

    async function loadBrands() {
        loading = true;
        const { data } = await supabase
            .from('ai_brand_libraries')
            .select('*, ai_brand_characters(*)')
            .order('created_at', { ascending: false });
        if (data) {
            brands = data;
            await loadLogoUrls(data);
        }
        loading = false;
    }

    async function loadLogoUrls(brandList: any[]) {
        const urls: Record<number, string> = {};
        await Promise.all(
            brandList
                .filter(b => b.logo_url)
                .map(async b => {
                    if (b.logo_url.startsWith('http')) {
                        urls[b.id] = b.logo_url;
                    } else {
                        const { data } = await supabase.storage
                            .from('ai-marketing-files')
                            .createSignedUrl(b.logo_url, 3600);
                        if (data?.signedUrl) urls[b.id] = data.signedUrl;
                    }
                })
        );
        logoUrls = urls;
    }

    async function loadUserPrefs() {
        if (!userId) return;
        const { data } = await supabase
            .from('ai_marketing_user_prefs')
            .select('favorite_brand_ids')
            .eq('user_id', userId)
            .maybeSingle();
        favoriteBrandIds = data?.favorite_brand_ids || [];
    }

    function isFavorite(brandId: number) { return favoriteBrandIds.includes(brandId); }

    async function toggleFavorite(brandId: number) {
        const newFavs = isFavorite(brandId)
            ? favoriteBrandIds.filter(f => f !== brandId)
            : [...favoriteBrandIds, brandId];
        favoriteBrandIds = newFavs;
        await supabase.from('ai_marketing_user_prefs').upsert({
            user_id: userId,
            favorite_brand_ids: newFavs,
            updated_at: new Date().toISOString()
        });
    }

    async function setDefault(brandId: number) {
        await supabase.from('ai_brand_libraries').update({ is_default: true }).eq('id', brandId);
        brands = brands.map(b => ({ ...b, is_default: b.id === brandId }));
    }

    async function toggleArchive(brand: any) {
        const newVal = !brand.is_archived;
        await supabase.from('ai_brand_libraries').update({ is_archived: newVal }).eq('id', brand.id);
        brands = brands.map(b => b.id === brand.id ? { ...b, is_archived: newVal } : b);
    }

    async function deleteBrand(brand: any) {
        const { count } = await supabase
            .from('ai_marketing_files')
            .select('id', { count: 'exact', head: true })
            .eq('brand_id', brand.id);
        if ((count || 0) > 0) {
            alert($locale === 'ar'
                ? `لا يمكن الحذف — مرتبطة بـ ${count} إنشاء. استخدم "أرشفة" بدلاً من ذلك.`
                : `Cannot delete — linked to ${count} creation(s). Archive instead.`);
            return;
        }
        const msg = $locale === 'ar' ? `حذف "${brand.name}" نهائياً؟` : `Permanently delete "${brand.name}"?`;
        if (!confirm(msg)) return;
        await supabase.from('ai_brand_libraries').delete().eq('id', brand.id);
        brands = brands.filter(b => b.id !== brand.id);
    }

    async function duplicateBrand(brand: any) {
        const { data: nb } = await supabase
            .from('ai_brand_libraries')
            .insert({
                name: brand.name + ($locale === 'ar' ? ' (نسخة)' : ' (Copy)'),
                description: brand.description,
                logo_url: brand.logo_url,
                primary_color: brand.primary_color,
                secondary_color: brand.secondary_color,
                accent_color: brand.accent_color,
                extra_colors: brand.extra_colors,
                brand_tone: brand.brand_tone,
                marketing_style: brand.marketing_style,
                rules: brand.rules,
                is_default: false,
                is_archived: false,
                created_by: userId
            })
            .select('id').single();
        if (nb && brand.ai_brand_characters?.length) {
            const chars = brand.ai_brand_characters.map((c: any) => ({
                brand_id: nb.id, name: c.name, role: c.role,
                image_url: c.image_url, description: c.description,
                voice_id: c.voice_id, display_order: c.display_order
            }));
            await supabase.from('ai_brand_characters').insert(chars);
        }
        await loadBrands();
    }

    function openCreate() { editingBrand = null; showEditor = true; }
    function openEdit(brand: any) { editingBrand = { ...brand }; showEditor = true; }

    async function onEditorSaved() { showEditor = false; await loadBrands(); }

    function getInitials(name: string) {
        return name.split(' ').map((w: string) => w[0]).join('').slice(0, 2).toUpperCase();
    }
</script>

<div dir={$locale === 'ar' ? 'rtl' : 'ltr'} class="w-full">
    <!-- Toolbar -->
    <div class="flex items-center justify-between gap-4 mb-6 flex-wrap">
        <div class="flex items-center gap-3 flex-1">
            <input
                type="text"
                bind:value={searchQuery}
                placeholder={$locale === 'ar' ? 'البحث عن مكتبة...' : 'Search libraries...'}
                class="flex-1 min-w-0 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black"
            />
            <label class="flex items-center gap-2 text-sm font-semibold text-slate-600 cursor-pointer select-none whitespace-nowrap">
                <input type="checkbox" bind:checked={showArchived} class="w-4 h-4 accent-emerald-600" />
                <span>{$locale === 'ar' ? 'عرض المؤرشف' : 'Show archived'}</span>
            </label>
        </div>
        <button
            on:click={openCreate}
            class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-black uppercase tracking-wide
                   bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700
                   transition-all duration-300 transform hover:scale-105 whitespace-nowrap"
        >
            <span class="text-base">+</span>
            <span>{$locale === 'ar' ? 'مكتبة جديدة' : 'New Library'}</span>
        </button>
    </div>

    {#if loading}
        <div class="flex items-center justify-center py-24">
            <div class="text-center">
                <div class="animate-spin inline-block">
                    <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                </div>
                <p class="mt-4 text-slate-600 font-semibold text-sm">
                    {$locale === 'ar' ? 'جارٍ التحميل...' : 'Loading...'}
                </p>
            </div>
        </div>
    {:else if filteredBrands.length === 0}
        <!-- Empty state -->
        <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border-2 border-dashed border-slate-200
                    shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-16 flex flex-col items-center justify-center">
            <div class="text-6xl mb-4">🎨</div>
            <h3 class="text-xl font-black text-slate-700 mb-2">
                {$locale === 'ar' ? 'لا توجد مكتبات علامات تجارية' : 'No Brand Libraries Yet'}
            </h3>
            <p class="text-sm text-slate-500 font-semibold mb-6 text-center max-w-sm">
                {$locale === 'ar'
                    ? 'أنشئ مكتبتك الأولى لتبدأ إنشاء المحتوى التسويقي بالذكاء الاصطناعي'
                    : 'Create your first brand library to start generating AI marketing content'}
            </p>
            <button
                on:click={openCreate}
                class="inline-flex items-center gap-2 px-6 py-3 rounded-xl text-sm font-black uppercase tracking-wide
                       bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700
                       transition-all transform hover:scale-105"
            >
                <span>+</span>
                <span>{$locale === 'ar' ? 'إنشاء مكتبة' : 'Create Library'}</span>
            </button>
        </div>
    {:else}
        <!-- Card Grid -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {#each filteredBrands as brand (brand.id)}
                <div class="bg-white/70 backdrop-blur-xl rounded-3xl border border-white
                            shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] overflow-hidden
                            transition-all duration-300 hover:shadow-[0_16px_40px_-8px_rgba(0,0,0,0.16)] hover:-translate-y-0.5
                            {brand.is_archived ? 'opacity-60' : ''}">

                    <!-- Card header -->
                    <div class="relative p-5 pb-3">
                        <div class="flex items-start gap-3">
                            <!-- Logo / Initials -->
                            <div class="w-14 h-14 rounded-2xl flex items-center justify-center overflow-hidden flex-shrink-0 shadow-md"
                                 style="background-color: {brand.primary_color || '#059669'}">
                                {#if logoUrls[brand.id]}
                                    <img src={logoUrls[brand.id]} alt={brand.name} class="w-full h-full object-cover" />
                                {:else}
                                    <span class="text-white font-black text-xl select-none">{getInitials(brand.name)}</span>
                                {/if}
                            </div>
                            <!-- Name + badges -->
                            <div class="flex-1 min-w-0">
                                <div class="flex items-center gap-1.5 flex-wrap">
                                    <h3 class="font-black text-slate-800 text-sm leading-tight">{brand.name}</h3>
                                </div>
                                <div class="flex items-center gap-1.5 mt-1 flex-wrap">
                                    {#if brand.is_default}
                                        <span class="px-2 py-0.5 bg-emerald-100 text-emerald-700 text-[10px] font-black rounded-full uppercase tracking-wide">
                                            {$locale === 'ar' ? 'افتراضي' : 'Default'}
                                        </span>
                                    {/if}
                                    {#if isFavorite(brand.id)}
                                        <span class="text-amber-400 text-xs">⭐</span>
                                    {/if}
                                    {#if brand.is_archived}
                                        <span class="px-2 py-0.5 bg-slate-100 text-slate-500 text-[10px] font-black rounded-full uppercase">
                                            {$locale === 'ar' ? 'مؤرشف' : 'Archived'}
                                        </span>
                                    {/if}
                                </div>
                                {#if brand.description}
                                    <p class="text-[11px] text-slate-400 font-semibold mt-1 line-clamp-1">{brand.description}</p>
                                {/if}
                            </div>
                        </div>

                        <!-- Favorite toggle -->
                        <button
                            on:click={() => toggleFavorite(brand.id)}
                            class="absolute top-3 {$locale === 'ar' ? 'left-3' : 'right-3'} text-xl hover:scale-125 transition-transform leading-none"
                            title={isFavorite(brand.id)
                                ? ($locale === 'ar' ? 'إزالة من المفضلة' : 'Remove favorite')
                                : ($locale === 'ar' ? 'إضافة للمفضلة' : 'Add to favorites')}
                        >
                            {isFavorite(brand.id) ? '⭐' : '☆'}
                        </button>
                    </div>

                    <!-- Color swatches + char count -->
                    <div class="px-5 py-2 flex items-center gap-2">
                        {#if brand.primary_color}
                            <div class="w-5 h-5 rounded-full shadow-sm border-2 border-white" style="background:{brand.primary_color}" title="Primary"></div>
                        {/if}
                        {#if brand.secondary_color}
                            <div class="w-5 h-5 rounded-full shadow-sm border-2 border-white" style="background:{brand.secondary_color}" title="Secondary"></div>
                        {/if}
                        {#if brand.accent_color}
                            <div class="w-5 h-5 rounded-full shadow-sm border-2 border-white" style="background:{brand.accent_color}" title="Accent"></div>
                        {/if}
                        <span class="text-[10px] text-slate-400 font-semibold {$locale === 'ar' ? 'mr-auto' : 'ml-auto'}">
                            👥 {(brand.ai_brand_characters || []).length}
                            {$locale === 'ar' ? 'شخصية' : 'chars'}
                        </span>
                    </div>

                    <!-- Actions -->
                    <div class="px-4 py-3 border-t border-slate-100 flex items-center gap-1.5 flex-wrap">
                        <button
                            on:click={() => openEdit(brand)}
                            class="flex-1 px-3 py-1.5 rounded-xl text-xs font-black bg-emerald-600 text-white hover:bg-emerald-700 transition-colors"
                        >
                            ✏️ {$locale === 'ar' ? 'تعديل' : 'Edit'}
                        </button>

                        {#if !brand.is_default && !brand.is_archived}
                            <button
                                on:click={() => setDefault(brand.id)}
                                title={$locale === 'ar' ? 'تعيين كافتراضي' : 'Set as default'}
                                class="px-3 py-1.5 rounded-xl text-xs font-black bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors"
                            >⚡</button>
                        {/if}

                        <button
                            on:click={() => duplicateBrand(brand)}
                            title={$locale === 'ar' ? 'نسخ' : 'Duplicate'}
                            class="px-3 py-1.5 rounded-xl text-xs font-black bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors"
                        >📋</button>

                        <button
                            on:click={() => toggleArchive(brand)}
                            title={brand.is_archived
                                ? ($locale === 'ar' ? 'إلغاء الأرشفة' : 'Unarchive')
                                : ($locale === 'ar' ? 'أرشفة' : 'Archive')}
                            class="px-3 py-1.5 rounded-xl text-xs font-black bg-orange-50 text-orange-600 hover:bg-orange-100 transition-colors"
                        >{brand.is_archived ? '📂' : '🗂️'}</button>

                        {#if isMasterAdmin}
                            <button
                                on:click={() => deleteBrand(brand)}
                                title={$locale === 'ar' ? 'حذف نهائي' : 'Delete permanently'}
                                class="px-3 py-1.5 rounded-xl text-xs font-black bg-red-50 text-red-600 hover:bg-red-100 transition-colors"
                            >🗑️</button>
                        {/if}
                    </div>
                </div>
            {/each}
        </div>
    {/if}
</div>

<!-- Brand Editor Modal -->
{#if showEditor && supabase}
    <AIMarketingBrandEditor
        brand={editingBrand}
        {supabase}
        {userId}
        on:save={onEditorSaved}
        on:close={() => (showEditor = false)}
    />
{/if}
