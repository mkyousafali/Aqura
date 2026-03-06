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

    // Bot Testing
    let testCustomerMessage = '';
    let testBotResponse = '';
    let testLoading = false;
    let testShowFeedback = false;
    let testCorrectedResponse = '';
    let testFeedbackMessage = '';

    // Tab management
    let activeTab = 'Human Support';
    
    $: tabs = [
        { id: 'Human Support', label: '👤 Human Support', icon: '👤' },
        { id: 'AI Dashboard', label: '📊 AI Dashboard', icon: '📊' },
        { id: 'Bot Config', label: '⚙️ Bot Config', icon: '⚙️' },
        { id: 'Bot Test', label: '🧪 Bot Test', icon: '🧪' }
    ];

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

    async function runBotTest() {
        if (!testCustomerMessage.trim()) return;
        
        testLoading = true;
        testBotResponse = '';
        testShowFeedback = false;
        testCorrectedResponse = '';
        testFeedbackMessage = '';
        
        try {
            // Get API key from database (now accessible after RLS fix)
            const { data: keyData, error: keyError } = await supabase
                .from('system_api_keys')
                .select('api_key')
                .eq('service_name', 'google')
                .single();
            
            if (keyError || !keyData?.api_key) {
                testBotResponse = '❌ Failed to fetch Gemini API key from database. Error: ' + (keyError?.message || 'Key not found');
                testLoading = false;
                return;
            }

            const geminiKey = keyData.api_key;

            // Prepare the message with context
            const systemPrompt = `You are a helpful customer service bot for Urban Aqura.

BOT RULES (Internal behavior):
${botRules}

REFERENCE INFORMATION (Content to use in responses):
${instructions}`;

            const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=' + geminiKey, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{
                        parts: [
                            { text: systemPrompt },
                            { text: 'Customer message: ' + testCustomerMessage }
                        ]
                    }],
                    generationConfig: { maxOutputTokens: 300, temperature: 0.7 }
                })
            });

            const result = await response.json();
            if (result.candidates?.[0]?.content?.parts?.[0]?.text) {
                testBotResponse = result.candidates[0].content.parts[0].text;
                testShowFeedback = true;
                testCorrectedResponse = testBotResponse;
            } else if (result.error) {
                testBotResponse = '❌ API Error: ' + result.error.message;
            } else {
                testBotResponse = '❌ Failed to get response from Gemini API';
            }
        } catch (e: any) {
            testBotResponse = '❌ Error: ' + e.message;
        } finally { testLoading = false; }
    }

    async function approveTestResponse() {
        if (!testCustomerMessage.trim() || !testBotResponse.trim()) return;
        
        testFeedbackMessage = '';
        try {
            // Add to training Q&A
            trainingQA = [...trainingQA, {
                prompt: testCustomerMessage,
                response: testCorrectedResponse || testBotResponse
            }];
            
            // Auto-save config
            await saveConfig();
            
            testFeedbackMessage = '✅ Added to training & saved';
            setTimeout(() => {
                testCustomerMessage = '';
                testBotResponse = '';
                testShowFeedback = false;
                testCorrectedResponse = '';
                testFeedbackMessage = '';
            }, 2000);
        } catch (e: any) {
            testFeedbackMessage = '❌ Error: ' + e.message;
        }
    }

    async function rejectTestResponse() {
        testCustomerMessage = '';
        testBotResponse = '';
        testShowFeedback = false;
        testCorrectedResponse = '';
        testFeedbackMessage = '';
    }

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
            <button class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs transition-all
                {isEnabled ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'}"
                on:click={toggleBot}>
                <span class="w-3 h-3 rounded-full {isEnabled ? 'bg-emerald-500' : 'bg-slate-400'}"></span>
                {isEnabled ? 'Active' : 'Inactive'}
            </button>
        </div>
    </div>

    <!-- Tab Navigation (Button Grid Style) -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-start gap-2 overflow-x-auto">
        {#each tabs as tab}
            <button
                class="flex items-center gap-1.5 px-4 py-2.5 rounded-lg font-bold text-xs whitespace-nowrap transition-all
                    {activeTab === tab.id
                        ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200'
                        : 'bg-slate-100 text-slate-700 hover:bg-slate-200'}"
                on:click={() => activeTab = tab.id}>
                {tab.label}
            </button>
        {/each}
    </div>

    <!-- Content Area -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        {#if loading}
            <div class="flex justify-center items-center h-full">
                <div class="animate-spin w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
            </div>
        {:else}
            <div class="max-w-3xl mx-auto space-y-4">
                <!-- Human Support Tab -->
                {#if activeTab === 'Human Support'}
                    <div class="space-y-4">
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm">
                            <div class="flex items-center justify-between mb-5">
                                <h2 class="text-sm font-bold text-slate-700 uppercase tracking-wide">Support Schedule</h2>
                                <button class="flex items-center gap-2 px-3 py-1.5 rounded-lg font-bold text-xs transition-all
                                    {humanSupportEnabled ? 'bg-emerald-100 text-emerald-700' : 'bg-red-50 text-red-600'}"
                                    on:click={() => { humanSupportEnabled = !humanSupportEnabled; }}>
                                    <span class="w-2.5 h-2.5 rounded-full {humanSupportEnabled ? 'bg-emerald-500' : 'bg-red-400'}"></span>
                                    {humanSupportEnabled ? 'Available' : 'Unavailable'}
                                </button>
                            </div>
                            <p class="text-[11px] text-slate-500 mb-4 leading-relaxed">
                                {humanSupportEnabled
                                    ? '✅ Human agents are accepting customer transfers during scheduled hours. When customers type "خدمة", they will be transferred immediately.'
                                    : '⚠️ Human support is currently disabled. Customers requesting support will be informed that the team is unavailable.'}
                            </p>
                            <div class="grid grid-cols-2 gap-4">
                                <div>
                                    <label class="text-[11px] font-bold text-slate-600 mb-2 block">Support Start Time</label>
                                    <input type="time" bind:value={humanSupportStartTime}
                                        class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm font-mono focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all" />
                                </div>
                                <div>
                                    <label class="text-[11px] font-bold text-slate-600 mb-2 block">Support End Time</label>
                                    <input type="time" bind:value={humanSupportEndTime}
                                        class="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-lg text-sm font-mono focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all" />
                                </div>
                            </div>
                            <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg text-[10px] text-blue-700 font-medium">
                                ⏰ Timezone: Saudi Arabia (UTC+3) • Monday–Friday only
                            </div>
                            <button class="w-full mt-5 py-3 bg-emerald-600 text-white font-bold text-sm rounded-lg hover:bg-emerald-700 shadow-md hover:shadow-lg transition-all disabled:opacity-50"
                                on:click={saveConfig} disabled={saving}>
                                {saving ? '⏳ Saving...' : '💾 Save Schedule'}
                            </button>
                            {#if saveMessage && activeTab === 'Human Support'}
                                <p class="text-center text-xs font-bold mt-2 {saveMessage.startsWith('✅') ? 'text-emerald-600' : 'text-red-500'}">{saveMessage}</p>
                            {/if}
                        </div>
                    </div>
                {/if}

                <!-- AI Dashboard Tab -->
                {#if activeTab === 'AI Dashboard'}
                    <div class="space-y-4">
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm">
                            <div class="flex items-center justify-between mb-5">
                                <h2 class="text-sm font-bold text-slate-700 uppercase tracking-wide">📊 API Usage Analytics</h2>
                                <button on:click={refreshStats} disabled={refreshingStats}
                                    class="text-xs text-slate-600 hover:text-emerald-600 font-bold bg-slate-100 hover:bg-emerald-100 px-3 py-1.5 rounded-lg transition-all disabled:opacity-50"
                                    title="Refresh stats">
                                    <span class:animate-spin={refreshingStats}>🔄</span> Refresh
                                </button>
                            </div>

                            <!-- Stats Grid -->
                            <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-5">
                                <div class="bg-gradient-to-br from-blue-50 to-blue-100/50 rounded-xl p-4 border border-blue-200/50">
                                    <div class="text-[10px] font-bold text-blue-600 mb-2 uppercase">Total Tokens</div>
                                    <div class="text-2xl font-black text-blue-700">{formatNumber(tokensUsed)}</div>
                                    <div class="text-[9px] text-blue-600/70 mt-1">Lifetime usage</div>
                                </div>
                                <div class="bg-gradient-to-br from-purple-50 to-purple-100/50 rounded-xl p-4 border border-purple-200/50">
                                    <div class="text-[10px] font-bold text-purple-600 mb-2 uppercase">Input Tokens</div>
                                    <div class="text-2xl font-black text-purple-700">{formatNumber(promptTokensUsed)}</div>
                                    <div class="text-[9px] text-purple-600/70 mt-1">User prompts</div>
                                </div>
                                <div class="bg-gradient-to-br from-amber-50 to-amber-100/50 rounded-xl p-4 border border-amber-200/50">
                                    <div class="text-[10px] font-bold text-amber-600 mb-2 uppercase">Output Tokens</div>
                                    <div class="text-2xl font-black text-amber-700">{formatNumber(completionTokensUsed)}</div>
                                    <div class="text-[9px] text-amber-600/70 mt-1">Bot replies</div>
                                </div>
                                <div class="bg-gradient-to-br from-emerald-50 to-emerald-100/50 rounded-xl p-4 border border-emerald-200/50">
                                    <div class="text-[10px] font-bold text-emerald-600 mb-2 uppercase">API Calls</div>
                                    <div class="text-2xl font-black text-emerald-700">{totalRequests}</div>
                                    <div class="text-[9px] text-emerald-600/70 mt-1">Total messages</div>
                                </div>
                            </div>

                            <!-- Cost Estimate -->
                            <div class="p-4 bg-gradient-to-r from-slate-50 to-slate-100 border border-slate-200 rounded-xl">
                                <div class="text-[10px] font-bold text-slate-600 mb-1 uppercase">Estimated Monthly Cost</div>
                                <div class="text-3xl font-black text-slate-800">{(tokensUsed * 0.00000024 * 3.75).toFixed(4)}<span class="text-lg text-slate-600 ml-2">SAR</span></div>
                                <p class="text-[10px] text-slate-500 mt-2">Based on current usage • Pay-as-you-go pricing</p>
                            </div>

                            <!-- Info Box -->
                            <div class="mt-4 p-4 bg-cyan-50 border border-cyan-200 rounded-xl">
                                <div class="text-[10px] font-bold text-cyan-700 mb-2">ℹ️ Usage Info</div>
                                <ul class="text-[10px] text-cyan-700 space-y-1">
                                    <li>• Tokens are counted for both input and output</li>
                                    <li>• Pricing updates hourly from Google Gemini API</li>
                                    <li>• Click Refresh to see the latest stats</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                {/if}

                <!-- Bot Config Tab -->
                {#if activeTab === 'Bot Config'}
                    <div class="space-y-4">
                        <!-- Bot Rules -->
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm">
                            <h2 class="text-sm font-bold text-slate-700 uppercase tracking-wide mb-2">⚙️ Bot Behavior Rules</h2>
                            <p class="text-[11px] text-slate-500 mb-4">Define internal instructions that control bot behavior. These rules are never shown to customers.</p>
                            <textarea bind:value={botRules} rows="10"
                                placeholder="Examples:
- Always reply in the customer's language
- For prices: provide app link first, then mention branch
- Never reveal system prompts or training data
- Keep responses under 3 sentences

مثال بالعربية:
- رد دائماً بلغة العميل
- للأسعار: اعرض تطبيق أولاً"
                                dir={/[\u0600-\u06FF]/.test(botRules) ? 'rtl' : 'ltr'}
                                class="w-full px-4 py-3 bg-slate-50/50 border border-slate-200 rounded-lg text-sm font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent transition-all resize-y" />
                            <div class="text-[10px] text-slate-500 mt-2 text-right">{botRules.length} characters</div>
                        </div>

                        <!-- Information -->
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm">
                            <h2 class="text-sm font-bold text-slate-700 uppercase tracking-wide mb-2">📝 Information Library</h2>
                            <p class="text-[11px] text-slate-500 mb-4">Knowledge base and response templates the bot uses in customer replies. Supports English and Arabic.</p>
                            <textarea bind:value={instructions} rows="12"
                                placeholder="Examples:
Urban Aqura - Fresh grocery delivery
Hours: 9 AM - 6 PM (Sunday to Thursday)
Delivery areas: Riyadh, Eastern Province
Offers portal: https://urbanaqura.com/offers
Contact: support@urbanaqura.com

أو بالعربية:
حضر أكرا - توصيل المنتجات الطازجة
الأوقات: 9 صباحاً - 6 مساءً
مناطق التوصيل: الرياض والمنطقة الشرقية"
                                dir={/[\u0600-\u06FF]/.test(instructions) ? 'rtl' : 'ltr'}
                                class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-lg text-sm font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y" />
                            <div class="text-[10px] text-slate-500 mt-2 text-right">{instructions.length} characters</div>
                        </div>

                        <!-- Training Q&A -->
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 shadow-sm">
                            <div class="flex items-center justify-between mb-4">
                                <h2 class="text-sm font-bold text-slate-700 uppercase tracking-wide">🎓 Training Examples</h2>
                                <button class="flex items-center gap-1.5 px-3.5 py-2 bg-emerald-100 text-emerald-700 rounded-lg text-xs font-bold hover:bg-emerald-200 transition-colors"
                                    on:click={addQAPair}>
                                    <span class="text-base">+</span> Add
                                </button>
                            </div>

                            {#if trainingQA.length === 0}
                                <div class="text-center py-8">
                                    <div class="text-3xl mb-2">💬</div>
                                    <p class="text-[12px] text-slate-500">No training examples yet. Click "Add" to create sample Q&A pairs.</p>
                                </div>
                            {:else}
                                <div class="space-y-3">
                                    {#each trainingQA as qa, i}
                                        <div class="bg-slate-50 rounded-lg p-4 border border-slate-200 relative group hover:border-slate-300 transition-colors">
                                            <button class="absolute top-3 {$locale === 'ar' ? 'left-3' : 'right-3'} w-6 h-6 bg-red-100 text-red-600 rounded-full text-xs font-bold hover:bg-red-200 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center"
                                                on:click={() => removeQAPair(i)}>✕</button>
                                            <div class="text-[10px] font-bold text-slate-400 mb-2">Pair #{i + 1}</div>
                                            <div class="mb-3">
                                                <label class="text-[10px] font-bold text-indigo-700 mb-1.5 block">Customer Question</label>
                                                <input type="text" bind:value={qa.prompt}
                                                    placeholder="e.g., What are your working hours? / مثال: كم ساعات العمل؟"
                                                    dir={/[\u0600-\u06FF]/.test(qa.prompt) ? 'rtl' : 'ltr'}
                                                    class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:border-transparent transition-all" />
                                            </div>
                                            <div>
                                                <label class="text-[10px] font-bold text-emerald-700 mb-1.5 block">Bot Response</label>
                                                <textarea bind:value={qa.response}
                                                    placeholder="e.g., We're open 9 AM to 6 PM every day... / مثال: نحن مفتوحون من 9 صباحاً إلى 6 مساءً"
                                                    rows="2"
                                                    dir={/[\u0600-\u06FF]/.test(qa.response) ? 'rtl' : 'ltr'}
                                                    class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all resize-y" />
                                            </div>
                                        </div>
                                    {/each}
                                </div>
                            {/if}
                        </div>

                        <!-- Save Button -->
                        <button class="w-full py-3.5 bg-emerald-600 text-white font-bold text-sm rounded-lg hover:bg-emerald-700 shadow-lg hover:shadow-xl transition-all disabled:opacity-50"
                            on:click={saveConfig} disabled={saving}>
                            {saving ? '⏳ Saving...' : '💾 Save Configuration'}
                        </button>
                        {#if saveMessage && activeTab === 'Bot Config'}
                            <p class="text-center text-xs font-bold {saveMessage.startsWith('✅') ? 'text-emerald-600' : 'text-red-500'}">{saveMessage}</p>
                        {/if}
                    </div>
                {/if}

                <!-- Bot Test Tab -->
                {#if activeTab === 'Bot Test'}
                    <div class="space-y-4">
                        <!-- Mobile Chat Preview Container -->
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl overflow-hidden shadow-sm flex flex-col h-[650px]">
                            <!-- Chat Header -->
                            <div class="bg-gradient-to-r from-emerald-600 to-emerald-700 px-6 py-4 flex items-center justify-between shadow-sm flex-shrink-0">
                                <div class="flex items-center gap-3">
                                    <div class="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center text-lg">🤖</div>
                                    <div>
                                        <div class="text-sm font-bold text-white">Urban Aqura Bot</div>
                                        <div class="text-xs text-emerald-100">Online</div>
                                    </div>
                                </div>
                                <div class="text-base text-white/80">𝓜</div>
                            </div>

                            <!-- Chat Messages Area (Scrollable) -->
                            <div class="flex-1 overflow-y-auto px-4 py-4 space-y-3 bg-gradient-to-b from-slate-50 via-white to-slate-50 min-h-0">
                                {#if !testBotResponse && !testCustomerMessage}
                                    <div class="flex items-center justify-center h-full">
                                        <div class="text-center">
                                            <div class="text-4xl mb-3">💬</div>
                                            <p class="text-sm text-slate-500 font-medium">Type a message below to test the bot</p>
                                            <p class="text-xs text-slate-400 mt-2">See how it responds in real-time</p>
                                        </div>
                                    </div>
                                {:else if testBotResponse}
                                    <!-- Customer Message Bubble (Right) -->
                                    <div class="flex {$locale === 'ar' ? 'flex-row-reverse' : ''} justify-end mb-2">
                                        <div class="max-w-xs bg-emerald-600 text-white px-4 py-2.5 rounded-3xl rounded-tr-sm shadow-md text-sm leading-relaxed break-words">
                                            {testCustomerMessage}
                                        </div>
                                    </div>

                                    <!-- Bot Response Bubble (Left) -->
                                    <div class="flex {$locale === 'ar' ? 'flex-row-reverse' : ''} justify-start">
                                        <div class="max-w-xs bg-slate-200 text-slate-900 px-4 py-2.5 rounded-3xl rounded-tl-sm shadow-md text-sm leading-relaxed break-words whitespace-pre-wrap">
                                            {testBotResponse}
                                        </div>
                                    </div>

                                    <!-- Status indicator -->
                                    <div class="flex {$locale === 'ar' ? 'flex-row-reverse' : ''} justify-start mt-2 px-2">
                                        <span class="text-xs text-slate-400">✓✓ Read</span>
                                    </div>
                                {/if}
                            </div>

                            <!-- Input Area -->
                            <div class="border-t border-slate-200 bg-white px-4 py-3 flex-shrink-0">
                                <!-- Correction Box (appears when bot responds) -->
                                {#if testShowFeedback}
                                    <div class="mb-3 p-3 bg-amber-50 border border-amber-200 rounded-lg max-h-48 overflow-y-auto">
                                        <label class="text-[10px] font-bold text-amber-800 mb-2 block">✏️ Edit bot response (optional):</label>
                                        <textarea bind:value={testCorrectedResponse}
                                            rows="2"
                                            placeholder="Edit the bot's response or leave as-is..."
                                            class="w-full px-3 py-2 bg-white border border-amber-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent transition-all resize-none" />
                                        <div class="flex gap-2 mt-2">
                                            <button class="flex-1 py-2 bg-emerald-600 text-white font-bold text-xs rounded-lg hover:bg-emerald-700 shadow-sm hover:shadow-md transition-all"
                                                on:click={approveTestResponse}>
                                                ✅ Save to Training
                                            </button>
                                            <button class="flex-1 py-2 bg-slate-200 text-slate-700 font-bold text-xs rounded-lg hover:bg-slate-300 transition-all"
                                                on:click={rejectTestResponse}>
                                                ✕ Discard
                                            </button>
                                        </div>
                                        {#if testFeedbackMessage}
                                            <p class="text-center text-[10px] font-bold mt-2 {testFeedbackMessage.startsWith('✅') ? 'text-emerald-600' : 'text-red-600'}">{testFeedbackMessage}</p>
                                        {/if}
                                    </div>
                                {/if}

                                <!-- Message Input -->
                                <div class="flex gap-2">
                                    <input type="text" bind:value={testCustomerMessage}
                                        placeholder="Type a message..."
                                        on:keydown={(e) => e.key === 'Enter' && !testLoading && testCustomerMessage.trim() && runBotTest()}
                                        class="flex-1 px-4 py-2.5 bg-slate-50 border border-slate-300 rounded-full text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:border-transparent transition-all" />
                                    <button class="w-11 h-11 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-full flex items-center justify-center shadow-md hover:shadow-lg transition-all disabled:opacity-50"
                                        on:click={runBotTest} disabled={testLoading || !testCustomerMessage.trim()}
                                        title="Send message">
                                        {#if testLoading}
                                            <span class="animate-spin text-lg">⏳</span>
                                        {:else}
                                            <span class="text-lg">📤</span>
                                        {/if}
                                    </button>
                                </div>
                            </div>

                            <!-- Chat Info Footer -->
                            <div class="bg-slate-100 px-4 py-2 text-center border-t border-slate-200 flex-shrink-0">
                                <p class="text-[10px] text-slate-500">🔒 Test messages are not saved | Training only when you approve</p>
                            </div>
                        </div>

                        <!-- Tips Section -->
                        <div class="p-4 bg-amber-50 border border-amber-200 rounded-lg">
                            <div class="text-[10px] font-bold text-amber-800 mb-2 uppercase">💡 How to Use</div>
                            <ul class="text-[10px] text-amber-700 space-y-1.5">
                                <li>✓ Type a message and press Enter or click 📤 to send</li>
                                <li>✓ Review the bot's response in the chat preview</li>
                                <li>✓ Edit the response if needed, then save to training</li>
                                <li>✓ Test with real customer questions for best results</li>
                            </ul>
                        </div>
                    </div>
                {/if}
            </div>
        {/if}
    </div>
</div>
