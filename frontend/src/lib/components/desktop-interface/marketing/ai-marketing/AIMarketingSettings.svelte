<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    let supabase: any = null;
    let loading = true;
    let saving = false;
    let saveMessage = '';
    let saveError = '';

    // Settings fields
    let googleApiKey = '';
    let googleProjectId = '';
    let googleLocation = 'europe-west4';
    let autoRetry = true;
    let speedModeDefault: 'fast' | 'quality' = 'quality';
    let defaultDurationSeconds = 15;
    let defaultPlatform = 'instagram';
    let defaultLanguage = 'ar';
    let baseInstructions = '';
    let maxClarificationQs = 10;

    // Test connection state
    let testing = false;
    let testResult: {
        ok: boolean;
        stage?: string;
        message?: string;
        reply?: string;
        elapsedMs?: number;
        model?: string;
        location?: string;
    } | null = null;

    const platforms = [
        { value: 'whatsapp',  labelEn: 'WhatsApp',  labelAr: 'واتساب' },
        { value: 'instagram', labelEn: 'Instagram', labelAr: 'إنستغرام' },
        { value: 'tiktok',    labelEn: 'TikTok',    labelAr: 'تيك توك' },
        { value: 'snapchat',  labelEn: 'Snapchat',  labelAr: 'سناب شات' },
        { value: 'facebook',  labelEn: 'Facebook',  labelAr: 'فيسبوك' }
    ];

    const languages = [
        { value: 'ar', labelEn: 'Arabic',  labelAr: 'العربية' },
        { value: 'en', labelEn: 'English', labelAr: 'الإنجليزية' }
    ];

    const locations = [
        { value: 'europe-west4',    labelEn: 'Europe (Netherlands)',  labelAr: 'أوروبا (هولندا)' },
        { value: 'us-central1',     labelEn: 'US Central (Iowa)',     labelAr: 'الولايات المتحدة الوسطى' },
        { value: 'asia-southeast1', labelEn: 'Asia Southeast (Singapore)', labelAr: 'جنوب شرق آسيا (سنغافورة)' }
    ];

    const durations = [10, 15, 20, 30];

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadSettings();
    });

    async function loadSettings() {
        loading = true;
        try {
            const { data, error } = await supabase
                .from('ai_marketing_settings')
                .select('*')
                .eq('id', 1)
                .maybeSingle();
            if (error) throw error;
            if (data) {
                googleApiKey            = data.google_api_key || '';
                googleProjectId         = data.google_project_id || '';
                googleLocation          = data.google_location || 'europe-west4';
                autoRetry               = data.auto_retry ?? true;
                speedModeDefault        = data.speed_mode_default || 'quality';
                defaultDurationSeconds  = data.default_duration_seconds || 15;
                defaultPlatform         = data.default_platform || 'instagram';
                defaultLanguage         = data.default_language || 'ar';
                baseInstructions        = data.base_instructions || '';
                maxClarificationQs      = data.max_clarification_qs || 10;
            }
        } catch (err: any) {
            saveError = err?.message ?? String(err);
        } finally {
            loading = false;
        }
    }

    async function saveSettings() {
        saving = true;
        saveMessage = '';
        saveError = '';
        try {
            const { error } = await supabase
                .from('ai_marketing_settings')
                .upsert({
                    id: 1,
                    google_api_key: googleApiKey || null,
                    google_project_id: googleProjectId || null,
                    google_location: googleLocation,
                    auto_retry: autoRetry,
                    speed_mode_default: speedModeDefault,
                    default_duration_seconds: defaultDurationSeconds,
                    default_platform: defaultPlatform,
                    default_language: defaultLanguage,
                    base_instructions: baseInstructions,
                    max_clarification_qs: maxClarificationQs,
                    updated_at: new Date().toISOString()
                });
            if (error) throw error;
            saveMessage = $locale === 'ar' ? 'تم الحفظ بنجاح' : 'Saved successfully';
            setTimeout(() => (saveMessage = ''), 3000);
        } catch (err: any) {
            saveError = err?.message ?? String(err);
        } finally {
            saving = false;
        }
    }

    async function testConnection() {
        testing = true;
        testResult = null;
        try {
            const res = await fetch('/api/ai-marketing/test-connection', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ prompt: 'Reply with exactly: Aqura AI Marketing connection OK' })
            });
            testResult = await res.json();
        } catch (err: any) {
            testResult = { ok: false, message: err?.message ?? String(err) };
        } finally {
            testing = false;
        }
    }

    function pickLabel(item: { labelEn: string; labelAr: string }) {
        return $locale === 'ar' ? item.labelAr : item.labelEn;
    }
</script>

<div class="w-full" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    {#if loading}
        <div class="flex items-center justify-center py-24">
            <div class="text-center">
                <div class="animate-spin inline-block">
                    <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                </div>
                <p class="mt-4 text-slate-600 font-semibold">
                    {$locale === 'ar' ? 'جارٍ تحميل الإعدادات...' : 'Loading settings...'}
                </p>
            </div>
        </div>
    {:else}
        <div class="space-y-6">
            <!-- ───── SECTION: Google API ───── -->
            <section class="bg-white/60 backdrop-blur-xl rounded-3xl border border-white shadow-[0_16px_40px_-12px_rgba(0,0,0,0.08)] p-6">
                <header class="flex items-center justify-between mb-5">
                    <div>
                        <h3 class="text-lg font-black text-slate-800 tracking-tight">
                            {$locale === 'ar' ? '🔑 إعدادات Google API' : '🔑 Google API'}
                        </h3>
                        <p class="text-xs text-slate-500 font-semibold mt-1">
                            {$locale === 'ar'
                                ? 'مفاتيح Google Cloud المستخدمة في إنشاء الفيديو والملصقات'
                                : 'Google Cloud credentials used for video and poster generation'}
                        </p>
                    </div>
                    <button
                        type="button"
                        on:click={testConnection}
                        disabled={testing}
                        class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-xs font-black uppercase tracking-wide
                               bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 hover:shadow-xl
                               transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed transform hover:scale-105"
                    >
                        {#if testing}
                            <span class="inline-block w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin"></span>
                            <span>{$locale === 'ar' ? 'جارٍ الاختبار...' : 'Testing...'}</span>
                        {:else}
                            <span>🧪</span>
                            <span>{$locale === 'ar' ? 'اختبار الاتصال' : 'Test Connection'}</span>
                        {/if}
                    </button>
                </header>

                {#if testResult}
                    <div class="mb-4 p-4 rounded-2xl border-2 {testResult.ok ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-red-50 border-red-200 text-red-800'}">
                        <div class="flex items-center gap-2 font-black text-sm mb-1">
                            <span>{testResult.ok ? '✅' : '❌'}</span>
                            <span>
                                {testResult.ok
                                    ? ($locale === 'ar' ? 'الاتصال يعمل' : 'Connection working')
                                    : ($locale === 'ar' ? 'فشل الاتصال' : 'Connection failed')}
                            </span>
                            {#if testResult.elapsedMs}
                                <span class="ml-auto text-xs font-semibold opacity-70">{testResult.elapsedMs} ms</span>
                            {/if}
                        </div>
                        {#if testResult.message}
                            <div class="text-xs font-semibold opacity-90">{testResult.message}</div>
                        {/if}
                        {#if testResult.reply}
                            <div class="mt-2 text-xs italic">
                                {$locale === 'ar' ? 'الردّ من Gemini:' : 'Gemini reply:'} <span class="font-mono">"{testResult.reply}"</span>
                            </div>
                        {/if}
                        {#if testResult.model}
                            <div class="mt-1 text-[10px] uppercase tracking-wider opacity-60">
                                {testResult.model} @ {testResult.location}
                            </div>
                        {/if}
                    </div>
                {/if}

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="g-api-key">
                            {$locale === 'ar' ? 'مفتاح Google API (للنص فقط)' : 'Google API Key (text only)'}
                        </label>
                        <input
                            id="g-api-key"
                            type="password"
                            bind:value={googleApiKey}
                            placeholder="AIza..."
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all text-black"
                        />
                        <p class="mt-1 text-[10px] text-slate-500">
                            {$locale === 'ar'
                                ? 'اختياري — يُستخدم للنماذج النصية فقط. الفيديو والصور يستخدمان حساب الخدمة من ملف .env'
                                : 'Optional — used for text-only models. Video & image use the service account from .env'}
                        </p>
                    </div>

                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="g-project-id">
                            {$locale === 'ar' ? 'معرّف المشروع (للعرض فقط)' : 'Project ID (display only)'}
                        </label>
                        <input
                            id="g-project-id"
                            type="text"
                            bind:value={googleProjectId}
                            placeholder="aqura-488113"
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all text-black"
                        />
                    </div>

                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="g-location">
                            {$locale === 'ar' ? 'منطقة Vertex AI' : 'Vertex AI Region'}
                        </label>
                        <select
                            id="g-location"
                            bind:value={googleLocation}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            style="color: #000000 !important; background-color: #ffffff !important;"
                        >
                            {#each locations as l}
                                <option value={l.value} style="color: #000000 !important; background-color: #ffffff !important;">{pickLabel(l)} — {l.value}</option>
                            {/each}
                        </select>
                    </div>
                </div>
            </section>

            <!-- ───── SECTION: Generation Defaults ───── -->
            <section class="bg-white/60 backdrop-blur-xl rounded-3xl border border-white shadow-[0_16px_40px_-12px_rgba(0,0,0,0.08)] p-6">
                <header class="mb-5">
                    <h3 class="text-lg font-black text-slate-800 tracking-tight">
                        {$locale === 'ar' ? '⚙️ الإعدادات الافتراضية للإنشاء' : '⚙️ Generation Defaults'}
                    </h3>
                    <p class="text-xs text-slate-500 font-semibold mt-1">
                        {$locale === 'ar'
                            ? 'القيم الافتراضية المستخدمة عند إنشاء فيديو أو ملصق جديد'
                            : 'Default values applied to new video and poster generations'}
                    </p>
                </header>

                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    <!-- Auto Retry -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="auto-retry">
                            {$locale === 'ar' ? 'إعادة المحاولة تلقائياً' : 'Auto Retry'}
                        </label>
                        <div class="flex items-center gap-3 px-4 py-2.5 bg-white border border-slate-200 rounded-xl">
                            <input id="auto-retry" type="checkbox" bind:checked={autoRetry} class="w-5 h-5 accent-emerald-600" />
                            <span class="text-sm text-slate-700 font-semibold">
                                {autoRetry
                                    ? ($locale === 'ar' ? 'مفعّل' : 'Enabled')
                                    : ($locale === 'ar' ? 'معطّل' : 'Disabled')}
                            </span>
                        </div>
                    </div>

                    <!-- Speed Mode -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="speed-mode">
                            {$locale === 'ar' ? 'وضع السرعة الافتراضي' : 'Speed Mode'}
                        </label>
                        <select
                            id="speed-mode"
                            bind:value={speedModeDefault}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            style="color: #000000 !important; background-color: #ffffff !important;"
                        >
                            <option value="fast"    style="color: #000000 !important; background-color: #ffffff !important;">{$locale === 'ar' ? 'سريع' : 'Fast'}</option>
                            <option value="quality" style="color: #000000 !important; background-color: #ffffff !important;">{$locale === 'ar' ? 'جودة عالية' : 'Quality'}</option>
                        </select>
                    </div>

                    <!-- Default Duration -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="def-duration">
                            {$locale === 'ar' ? 'المدة الافتراضية (ثانية)' : 'Default Duration (sec)'}
                        </label>
                        <select
                            id="def-duration"
                            bind:value={defaultDurationSeconds}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            style="color: #000000 !important; background-color: #ffffff !important;"
                        >
                            {#each durations as d}
                                <option value={d} style="color: #000000 !important; background-color: #ffffff !important;">{d}s</option>
                            {/each}
                        </select>
                    </div>

                    <!-- Default Platform -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="def-platform">
                            {$locale === 'ar' ? 'المنصة الافتراضية' : 'Default Platform'}
                        </label>
                        <select
                            id="def-platform"
                            bind:value={defaultPlatform}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            style="color: #000000 !important; background-color: #ffffff !important;"
                        >
                            {#each platforms as p}
                                <option value={p.value} style="color: #000000 !important; background-color: #ffffff !important;">{pickLabel(p)}</option>
                            {/each}
                        </select>
                    </div>

                    <!-- Default Language -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="def-lang">
                            {$locale === 'ar' ? 'اللغة الافتراضية' : 'Default Language'}
                        </label>
                        <select
                            id="def-lang"
                            bind:value={defaultLanguage}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                            style="color: #000000 !important; background-color: #ffffff !important;"
                        >
                            {#each languages as l}
                                <option value={l.value} style="color: #000000 !important; background-color: #ffffff !important;">{pickLabel(l)}</option>
                            {/each}
                        </select>
                    </div>

                    <!-- Max Clarification Questions -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="max-q">
                            {$locale === 'ar' ? 'أقصى عدد للأسئلة التوضيحية' : 'Max Clarification Questions'}
                        </label>
                        <input
                            id="max-q"
                            type="number"
                            min="0"
                            max="20"
                            bind:value={maxClarificationQs}
                            class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all text-black"
                        />
                        <p class="mt-1 text-[10px] text-slate-500">
                            {$locale === 'ar'
                                ? 'عدد الأسئلة التي يمكن للذكاء الاصطناعي طرحها قبل البدء (الموصى به: 10)'
                                : 'Questions AI may ask before generating (recommended: 10)'}
                        </p>
                    </div>
                </div>
            </section>

            <!-- ───── SECTION: AI Agent Base Instructions ───── -->
            <section class="bg-white/60 backdrop-blur-xl rounded-3xl border border-white shadow-[0_16px_40px_-12px_rgba(0,0,0,0.08)] p-6">
                <header class="mb-5">
                    <h3 class="text-lg font-black text-slate-800 tracking-tight">
                        {$locale === 'ar' ? '🧠 تعليمات أساسية لوكيل الذكاء الاصطناعي' : '🧠 AI Agent Base Instructions'}
                    </h3>
                    <p class="text-xs text-slate-500 font-semibold mt-1">
                        {$locale === 'ar'
                            ? 'تدريب دائم — يُطبَّق على كل عملية إنشاء (نبرة العلامة، صياغة العروض، أسلوب التسويق)'
                            : 'Permanent training — applied to every generation (brand tone, offer wording, marketing style)'}
                    </p>
                </header>

                <textarea
                    bind:value={baseInstructions}
                    rows="10"
                    class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all text-black font-mono leading-relaxed"
                    placeholder={$locale === 'ar'
                        ? 'مثال: نبرة العلامة ودودة وعصرية. صياغة العروض واضحة وموجزة. لا تستخدم لغة عامية. ركّز على القيمة والجودة...'
                        : 'Example: Brand tone is friendly and modern. Offer wording is clear and concise. No slang. Emphasize value and quality...'}
                ></textarea>
            </section>

            <!-- ───── ACTION BAR ───── -->
            <div class="sticky bottom-0 bg-white/80 backdrop-blur-xl rounded-2xl border border-slate-200 shadow-lg p-4 flex items-center gap-4">
                <button
                    type="button"
                    on:click={saveSettings}
                    disabled={saving}
                    class="inline-flex items-center gap-2 px-6 py-3 rounded-xl text-sm font-black uppercase tracking-wide
                           bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 hover:shadow-xl
                           transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed transform hover:scale-105"
                >
                    {#if saving}
                        <span class="inline-block w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin"></span>
                        <span>{$locale === 'ar' ? 'جارٍ الحفظ...' : 'Saving...'}</span>
                    {:else}
                        <span>💾</span>
                        <span>{$locale === 'ar' ? 'حفظ الإعدادات' : 'Save Settings'}</span>
                    {/if}
                </button>

                {#if saveMessage}
                    <span class="text-sm font-bold text-emerald-700">✅ {saveMessage}</span>
                {/if}
                {#if saveError}
                    <span class="text-sm font-bold text-red-700">❌ {saveError}</span>
                {/if}
            </div>
        </div>
    {/if}
</div>
