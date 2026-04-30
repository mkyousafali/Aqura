<script lang="ts">
    import { locale } from '$lib/i18n';
    import { currentUser } from '$lib/utils/persistentAuth';

    const platforms = [
        { id: 'instagram_feed',  icon: '📸', en: 'Instagram Feed',  ar: 'إنستغرام فيد',  ratio: '1:1'  },
        { id: 'instagram_story', icon: '📱', en: 'Insta Story',     ar: 'قصة إنستغرام',  ratio: '9:16' },
        { id: 'facebook',        icon: '👤', en: 'Facebook',        ar: 'فيسبوك',         ratio: '16:9' },
        { id: 'twitter',         icon: '🐦', en: 'Twitter / X',    ar: 'تويتر',           ratio: '16:9' },
        { id: 'whatsapp',        icon: '💬', en: 'WhatsApp',        ar: 'واتساب',          ratio: '9:16' },
        { id: 'tiktok',          icon: '🎵', en: 'TikTok',          ar: 'تيك توك',         ratio: '9:16' },
    ];

    let selectedPlatformId = 'instagram_feed';
    $: selectedPlatform = platforms.find(p => p.id === selectedPlatformId) || platforms[0];
    $: aspectRatio = selectedPlatform.ratio;
    $: previewAspect = ({ '1:1': 'aspect-square', '9:16': 'aspect-[9/16]', '16:9': 'aspect-video' } as Record<string, string>)[aspectRatio] || 'aspect-square';

    let prompt = '';
    let generating = false;
    let errorMessage = '';
    let generatedUrl: string | null = null;
    let generatedDialogue = '';

    $: userId = $currentUser?.id;

    async function generate() {
        if (generating || !prompt.trim()) return;
        generating = true;
        errorMessage = '';
        generatedUrl = null;
        generatedDialogue = '';
        try {
            const res = await fetch('/api/ai-marketing/generate-poster', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ prompt: prompt.trim(), platform: selectedPlatformId, aspectRatio, userId })
            });
            const data = await res.json();
            if (!data.ok) { errorMessage = data.message || 'Generation failed'; return; }
            generatedUrl = data.signedUrl;
            generatedDialogue = data.dialogueOverlay ?? '';
        } catch (err: any) {
            errorMessage = err?.message ?? String(err);
        } finally {
            generating = false;
        }
    }

    async function downloadImage() {
        if (!generatedUrl) return;
        try {
            const res  = await fetch(generatedUrl);
            const blob = await res.blob();
            const a    = document.createElement('a');
            a.href     = URL.createObjectURL(blob);
            a.download = `poster-${Date.now()}.png`;
            a.click();
            setTimeout(() => URL.revokeObjectURL(a.href), 5000);
        } catch {
            window.open(generatedUrl, '_blank');
        }
    }
</script>

<div class="w-full" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <div class="grid grid-cols-1 xl:grid-cols-[400px_1fr] gap-6">

        <!-- ══ LEFT: Controls ══ -->
        <div class="space-y-4">

            <div>
                <h2 class="text-xl font-black text-slate-800 tracking-tight">🎨 {$locale === 'ar' ? 'إنشاء صورة بالذكاء الاصطناعي' : 'AI Image Generator'}</h2>
                <p class="text-xs font-semibold text-slate-500 mt-0.5">
                    {$locale === 'ar' ? 'اكتب وصف الصورة، اختر المنصة، ثم اضغط إنشاء' : 'Write a prompt, pick a platform, then generate'}
                </p>
            </div>

            <!-- Prompt -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider mb-2" for="ai-prompt">
                    ✍️ {$locale === 'ar' ? 'وصف الصورة' : 'Image Prompt'}
                </label>
                <textarea
                    id="ai-prompt"
                    bind:value={prompt}
                    rows="7"
                    placeholder={$locale === 'ar'
                        ? 'مثال: عائلة سعيدة في سوبرماركت حديث، ألوان دافئة، جودة احترافية عالية...'
                        : 'e.g. Happy family in a modern supermarket, warm lighting, photorealistic quality...'}
                    class="w-full px-3 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 text-black resize-none leading-relaxed"
                ></textarea>
            </div>

            <!-- Platform -->
            <div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.08)] p-4 space-y-3">
                <label class="block text-[10px] font-black text-slate-500 uppercase tracking-wider">
                    📲 {$locale === 'ar' ? 'المنصة / الحجم' : 'Platform / Size'}
                </label>
                <div class="grid grid-cols-3 gap-2">
                    {#each platforms as pl}
                        <button
                            on:click={() => (selectedPlatformId = pl.id)}
                            class="flex flex-col items-center gap-1 p-2.5 rounded-xl border-2 transition-all text-center
                                   {selectedPlatformId === pl.id
                                       ? 'border-emerald-500 bg-emerald-50'
                                       : 'border-slate-200 bg-white hover:border-emerald-300 hover:bg-emerald-50/50'}"
                        >
                            <span class="text-xl">{pl.icon}</span>
                            <span class="text-[9px] font-black text-slate-600 leading-tight">{$locale === 'ar' ? pl.ar : pl.en}</span>
                            <span class="text-[8px] font-bold text-slate-400">{pl.ratio}</span>
                        </button>
                    {/each}
                </div>
            </div>

            <!-- Generate -->
            <button
                on:click={generate}
                disabled={!prompt.trim() || generating}
                class="w-full py-4 rounded-2xl text-sm font-black uppercase tracking-widest transition-all
                       {prompt.trim() && !generating
                           ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 active:scale-[0.98]'
                           : 'bg-slate-200 text-slate-400 cursor-not-allowed'}"
            >
                {#if generating}
                    <span class="flex items-center justify-center gap-3">
                        <span class="inline-block w-5 h-5 rounded-full border-[3px] border-white/40 border-t-white animate-spin"></span>
                        <span>{$locale === 'ar' ? 'جارٍ الإنشاء...' : 'Generating...'}</span>
                    </span>
                {:else}
                    ✨ {$locale === 'ar' ? 'إنشاء الصورة' : 'Generate Image'}
                {/if}
            </button>

        </div>

        <!-- ══ RIGHT: Preview ══ -->
        <div class="bg-white/80 backdrop-blur-xl rounded-3xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.10)] p-6 flex flex-col gap-4">

            <div class="flex items-center justify-between">
                <h3 class="font-black text-slate-700 text-sm uppercase tracking-wide">🖼️ {$locale === 'ar' ? 'معاينة' : 'Preview'}</h3>
                {#if generatedUrl}
                    <button
                        on:click={downloadImage}
                        class="px-4 py-2 rounded-xl text-xs font-black bg-emerald-600 text-white hover:bg-emerald-700 transition-colors shadow-sm"
                    >⬇️ {$locale === 'ar' ? 'تنزيل' : 'Download'}</button>
                {/if}
            </div>

            <div class="flex-1 flex items-center justify-center bg-slate-50 rounded-2xl overflow-hidden min-h-[320px] p-4">
                {#if generating}
                    <div class="flex flex-col items-center gap-4">
                        <div class="relative w-16 h-16">
                            <div class="absolute inset-0 border-4 border-emerald-200 rounded-full animate-ping opacity-30"></div>
                            <div class="absolute inset-0 border-4 border-emerald-300 border-t-emerald-600 rounded-full animate-spin"></div>
                            <div class="absolute inset-0 flex items-center justify-center text-2xl">🎨</div>
                        </div>
                        <p class="font-black text-slate-700 text-sm text-center">
                            {$locale === 'ar' ? 'الذكاء الاصطناعي يرسم صورتك...' : 'AI is generating your image...'}
                        </p>
                        <p class="text-xs text-slate-400 font-semibold">{$locale === 'ar' ? 'قد يستغرق 15–30 ثانية' : 'May take 15–30 seconds'}</p>
                    </div>
                {:else if errorMessage}
                    <div class="flex flex-col items-center gap-3 text-center max-w-sm">
                        <span class="text-4xl">❌</span>
                        <p class="text-sm font-black text-red-700">{$locale === 'ar' ? 'حدث خطأ' : 'Error'}</p>
                        <p class="text-xs text-red-600 font-semibold bg-red-50 rounded-xl p-3 text-left break-words">{errorMessage}</p>
                    </div>
                {:else if generatedUrl}
                    <div class="w-full flex flex-col items-center gap-3">
                        <div class="rounded-2xl overflow-hidden shadow-xl max-w-md w-full {previewAspect} relative">
                            <img src={generatedUrl} alt="Generated" class="w-full h-full object-contain bg-white" />
                            {#if generatedDialogue}
                                <!-- Arabic speech bubble overlaid as HTML — model cannot render Arabic -->
                                <div class="absolute bottom-[12%] right-[6%] w-[52%] pointer-events-none z-10">
                                    <div class="relative bg-white rounded-2xl px-4 py-3 text-gray-900 text-center font-bold leading-snug shadow-lg border border-gray-100"
                                         style="direction:rtl; font-family:'Tahoma','Arial',sans-serif; font-size:clamp(11px,2.8vw,16px);">
                                        {generatedDialogue}
                                        <div class="absolute bottom-[-13px] right-[22%] w-0 h-0"
                                             style="border-left:11px solid transparent; border-right:11px solid transparent; border-top:13px solid white;"></div>
                                    </div>
                                </div>
                            {/if}
                        </div>
                    </div>
                {:else}
                    <div class="flex flex-col items-center gap-3 text-center">
                        <div class="text-6xl opacity-20">🖼️</div>
                        <p class="text-sm font-black text-slate-400">
                            {$locale === 'ar' ? 'ستظهر الصورة هنا بعد الإنشاء' : 'Image will appear here after generation'}
                        </p>
                    </div>
                {/if}
            </div>

        </div>
    </div>
</div>
