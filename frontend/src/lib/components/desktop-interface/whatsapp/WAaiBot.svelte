<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    let supabase: any = null;
    let loading = true;
    let saving = false;
    let saveMessage = '';

    let configId = '';
    let isEnabled = false;
    let botRules = '';
    let instructions = '';

    // Training Q&A pairs
    let trainingQA: Array<{ prompt: string; response: string }> = [];

    // Token stats
    let refreshingStats = false;
    let tokensUsed = 0;
    let promptTokensUsed = 0;
    let completionTokensUsed = 0;
    let totalRequests = 0;

    // Human support
    let humanSupportEnabled = false;
    let humanSupportStartTime = '12:00';
    let humanSupportEndTime = '20:00';

    function formatNumber(n: number): string {
        if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
        if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
        return n.toString();
    }

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadConfig();
    });

    async function loadConfig() {
        try {
            const { data } = await supabase.from('wa_ai_bot_config').select('*').single();
            if (data) {
                configId = data.id;
                isEnabled = data.is_enabled ?? false;
                botRules = data.bot_rules || '';
                instructions = data.custom_instructions || '';
                trainingQA = Array.isArray(data.training_qa) ? data.training_qa : [];
                tokensUsed = data.tokens_used ?? 0;
                promptTokensUsed = data.prompt_tokens_used ?? 0;
                completionTokensUsed = data.completion_tokens_used ?? 0;
                totalRequests = data.total_requests ?? 0;
                humanSupportEnabled = data.human_support_enabled ?? false;
                humanSupportStartTime = (data.human_support_start_time || '12:00:00').substring(0, 5);
                humanSupportEndTime = (data.human_support_end_time || '20:00:00').substring(0, 5);
            }
        } catch {} finally { loading = false; }
    }

    async function saveConfig() {
        saving = true;
        saveMessage = '';
        try {
            // Filter out empty Q&A pairs
            const cleanQA = trainingQA.filter(qa => qa.prompt.trim() || qa.response.trim());
            const payload = {
                is_enabled: isEnabled,
                bot_rules: botRules,
                custom_instructions: instructions,
                training_qa: cleanQA,
                human_support_enabled: humanSupportEnabled,
                human_support_start_time: humanSupportStartTime + ':00',
                human_support_end_time: humanSupportEndTime + ':00'
            };

            if (configId) {
                const { error } = await supabase.from('wa_ai_bot_config').update(payload).eq('id', configId);
                if (error) throw error;
            } else {
                const { data, error } = await supabase.from('wa_ai_bot_config').insert(payload).select().single();
                if (error) throw error;
                if (data) configId = data.id;
            }
            saveMessage = '✅ Saved';
            setTimeout(() => saveMessage = '', 3000);
        } catch (e: any) {
            saveMessage = '❌ Error: ' + e.message;
        } finally { saving = false; }
    }

    async function toggleBot() {
        isEnabled = !isEnabled;
        await saveConfig();
    }

    function addQAPair() {
        trainingQA = [...trainingQA, { prompt: '', response: '' }];
    }

    function removeQAPair(index: number) {
        trainingQA = trainingQA.filter((_, i) => i !== index);
    }

    async function refreshStats() {
        refreshingStats = true;
        try {
            const { data } = await supabase.from('wa_ai_bot_config').select('tokens_used, prompt_tokens_used, completion_tokens_used, total_requests').single();
            if (data) {
                tokensUsed = data.tokens_used ?? 0;
                promptTokensUsed = data.prompt_tokens_used ?? 0;
                completionTokensUsed = data.completion_tokens_used ?? 0;
                totalRequests = data.total_requests ?? 0;
            }
        } catch {} finally { refreshingStats = false; }
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4">
        <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
                <span class="text-2xl">🤖</span>
                <h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappAIBot')}</h1>
            </div>
            <div class="flex items-center gap-3">
                <button class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs transition-all
                    {isEnabled ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'}"
                    on:click={toggleBot}>
                    <span class="w-3 h-3 rounded-full {isEnabled ? 'bg-emerald-500' : 'bg-slate-400'}"></span>
                    {isEnabled ? 'AI Bot Active' : 'AI Bot Inactive'}
                </button>
            </div>
        </div>
    </div>

    <div class="flex-1 overflow-y-auto p-6">
        {#if loading}
            <div class="flex justify-center items-center h-full">
                <div class="animate-spin w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
            </div>
        {:else}
            <div class="max-w-3xl mx-auto space-y-4">
                <!-- Human Support Schedule -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <div class="flex items-center justify-between mb-4">
                        <div class="text-xs font-bold text-slate-600 uppercase">👤 Human Support</div>
                        <button class="flex items-center gap-2 px-3 py-1.5 rounded-xl font-bold text-xs transition-all
                            {humanSupportEnabled ? 'bg-emerald-100 text-emerald-700' : 'bg-red-50 text-red-500'}"
                            on:click={() => { humanSupportEnabled = !humanSupportEnabled; }}>
                            <span class="w-2.5 h-2.5 rounded-full {humanSupportEnabled ? 'bg-emerald-500' : 'bg-red-400'}"></span>
                            {humanSupportEnabled ? 'Available' : 'Unavailable'}
                        </button>
                    </div>
                    <p class="text-[11px] text-slate-400 mb-3">
                        {humanSupportEnabled
                            ? 'Human agents are accepting chats during the scheduled hours below. Customers who type "خدمة" within these hours will be transferred.'
                            : 'Human support is OFF. Customers who type "خدمة" will be told support is not available right now.'}
                    </p>
                    <div class="flex items-center gap-4">
                        <div class="flex-1">
                            <label class="text-[11px] font-bold text-slate-500 mb-1 block">Start Time</label>
                            <input type="time" bind:value={humanSupportStartTime}
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-emerald-400" />
                        </div>
                        <div class="flex items-center pt-5 text-slate-400 font-bold text-sm">→</div>
                        <div class="flex-1">
                            <label class="text-[11px] font-bold text-slate-500 mb-1 block">End Time</label>
                            <input type="time" bind:value={humanSupportEndTime}
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-emerald-400" />
                        </div>
                    </div>
                    <div class="mt-3 text-[10px] text-slate-400 text-center">
                        Saudi Arabia Time (UTC+3) • Daily schedule
                    </div>
                </div>

                <!-- Token Usage Stats -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <div class="flex items-center justify-between mb-4">
                        <div class="text-xs font-bold text-slate-600 uppercase">📊 Gemini 2.5 Flash — Usage</div>
                        <div class="flex items-center gap-2">
                            <button on:click={refreshStats} disabled={refreshingStats}
                                class="text-[10px] text-slate-500 hover:text-emerald-600 font-bold bg-slate-50 hover:bg-emerald-50 px-2 py-1 rounded-full transition-all disabled:opacity-50"
                                title="Refresh stats">
                                <span class:animate-spin={refreshingStats}>🔄</span>
                            </button>
                            <div class="text-[10px] text-emerald-600 font-bold bg-emerald-50 px-2 py-1 rounded-full">Pay-as-you-go</div>
                        </div>
                    </div>

                    <!-- Stats grid -->
                    <div class="grid grid-cols-4 gap-3">
                        <div class="bg-blue-50 rounded-xl p-3 text-center">
                            <div class="text-lg font-black text-blue-700">{formatNumber(tokensUsed)}</div>
                            <div class="text-[10px] text-blue-500 font-bold">Total Tokens</div>
                        </div>
                        <div class="bg-purple-50 rounded-xl p-3 text-center">
                            <div class="text-lg font-black text-purple-700">{formatNumber(promptTokensUsed)}</div>
                            <div class="text-[10px] text-purple-500 font-bold">Prompt</div>
                        </div>
                        <div class="bg-amber-50 rounded-xl p-3 text-center">
                            <div class="text-lg font-black text-amber-700">{formatNumber(completionTokensUsed)}</div>
                            <div class="text-[10px] text-amber-500 font-bold">Completion</div>
                        </div>
                        <div class="bg-emerald-50 rounded-xl p-3 text-center">
                            <div class="text-lg font-black text-emerald-700">{totalRequests}</div>
                            <div class="text-[10px] text-emerald-500 font-bold">Replies</div>
                        </div>
                    </div>

                    <!-- Cost estimate -->
                    <div class="mt-3 flex items-center justify-center gap-2 text-[10px] text-slate-400">
                        Est. cost: ~{(tokensUsed * 0.00000024 * 3.75).toFixed(4)} SAR
                    </div>
                </div>

                <!-- Bot Rules (Internal behavior - never shown to customer) -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <div class="text-xs font-bold text-slate-600 uppercase mb-3">⚙️ Bot Rules <span class="text-[10px] font-normal normal-case text-slate-400">(internal — never sent to customer)</span></div>
                    <p class="text-[11px] text-slate-400 mb-3">Internal behavior rules that control how the bot acts. These are NEVER included in customer replies.</p>
                    <textarea bind:value={botRules} rows="12"
                        placeholder="Example rules:
- Always reply in the same language the customer uses
- Keep responses under 3 sentences
- Never mention internal policies or competitor names
- If customer asks for human agent, tell them to type خدمة
- Never improvise information not provided in the Information section"
                        class="w-full px-4 py-3 bg-amber-50/50 border border-amber-200/60 rounded-xl text-sm font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-amber-500 resize-y min-h-[200px]"></textarea>
                    <div class="flex items-center justify-between mt-2">
                        <span class="text-[10px] text-slate-400">{botRules.length} characters</span>
                    </div>
                </div>

                <!-- Information (Response templates and content) -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <div class="text-xs font-bold text-slate-600 uppercase mb-3">📝 Information <span class="text-[10px] font-normal normal-case text-slate-400">(response content the bot can use)</span></div>
                    <p class="text-[11px] text-slate-400 mb-3">Reference information, response templates, and content the bot uses when replying to customers.</p>
                    <textarea bind:value={instructions} rows="20"
                        placeholder="Example information:
Urban Aqura is a grocery delivery service.
Working hours: Sun–Thu 9AM to 6PM.
We deliver fresh groceries, meat, and household items.
Offer page: https://urbanaqura.com/offers
Support number: +966..."
                        class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-y min-h-[300px]"></textarea>
                    <div class="flex items-center justify-between mt-2">
                        <span class="text-[10px] text-slate-400">{instructions.length} characters</span>
                    </div>
                </div>

                <!-- Training Q&A -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <div class="flex items-center justify-between mb-4">
                        <div class="text-xs font-bold text-slate-600 uppercase">🎓 Training Q&A</div>
                        <button class="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-100 text-emerald-700 rounded-lg text-xs font-bold hover:bg-emerald-200 transition-colors"
                            on:click={addQAPair}>
                            <span class="text-sm">+</span> Add Pair
                        </button>
                    </div>

                    {#if trainingQA.length === 0}
                        <div class="text-center py-8 text-slate-400">
                            <div class="text-3xl mb-2">💬</div>
                            <p class="text-xs">No training pairs yet. Click "Add Pair" to teach the bot specific responses.</p>
                        </div>
                    {:else}
                        <div class="space-y-3">
                            {#each trainingQA as qa, i}
                                <div class="bg-slate-50 rounded-xl p-4 border border-slate-200 relative group">
                                    <button class="absolute top-2 {$locale === 'ar' ? 'left-2' : 'right-2'} w-6 h-6 bg-red-100 text-red-500 rounded-full text-xs font-bold hover:bg-red-200 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center"
                                        on:click={() => removeQAPair(i)}>✕</button>
                                    <div class="text-[10px] font-bold text-slate-400 mb-1">#{i + 1}</div>
                                    <div class="mb-3">
                                        <label class="text-[11px] font-bold text-indigo-600 mb-1 block">Prompt</label>
                                        <input type="text" bind:value={qa.prompt}
                                            placeholder="When customer asks..."
                                            class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400" />
                                    </div>
                                    <div>
                                        <label class="text-[11px] font-bold text-emerald-600 mb-1 block">Response</label>
                                        <textarea bind:value={qa.response}
                                            placeholder="Bot should reply with..."
                                            rows="3"
                                            class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400 resize-y"></textarea>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    {/if}
                </div>

                <!-- Save -->
                <button class="w-full py-3.5 bg-emerald-600 text-white font-black text-sm rounded-2xl hover:bg-emerald-700 shadow-lg shadow-emerald-200 transition-all disabled:opacity-50"
                    on:click={saveConfig} disabled={saving}>
                    {saving ? '⏳ Saving...' : '💾 Save All'}
                </button>
                {#if saveMessage}
                    <p class="text-center text-sm font-bold {saveMessage.startsWith('✅') ? 'text-emerald-600' : 'text-red-500'}">{saveMessage}</p>
                {/if}
            </div>
        {/if}
    </div>
</div>
