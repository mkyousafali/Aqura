<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface AIBotConfig {
        id: string;
        is_enabled: boolean;
        system_prompt: string;
        tone: string;
        max_tokens: number;
        temperature: number;
        handoff_keywords: string[];
        handoff_message: string;
        training_data: TrainingItem[];
        response_language: string;
        max_messages_before_handoff: number;
    }

    interface TrainingItem {
        id: string;
        question: string;
        answer: string;
        category: string;
    }

    interface ConversationLog {
        id: string;
        customer_phone: string;
        customer_name: string;
        message_count: number;
        last_message_at: string;
        was_handed_off: boolean;
    }

    let supabase: any = null;
    let accountId = '';
    let loading = true;
    let saving = false;
    let config: AIBotConfig = {
        id: '',
        is_enabled: false,
        system_prompt: 'You are a helpful customer service assistant for our business. Answer questions politely and professionally. If you cannot help, offer to connect them with a human agent.',
        tone: 'professional',
        max_tokens: 500,
        temperature: 0.7,
        handoff_keywords: ['agent', 'human', 'person', 'manager', 'support', 'وكيل', 'شخص', 'مدير'],
        handoff_message: 'I\'ll connect you with a human agent right away. Please hold on.',
        training_data: [],
        response_language: 'auto',
        max_messages_before_handoff: 10
    };

    let activeTab = 'settings'; // settings, training, logs
    let apiKeyStatus = 'unknown'; // unknown, configured, missing
    let conversationLogs: ConversationLog[] = [];

    // Training data editor
    let newTraining: TrainingItem = { id: '', question: '', answer: '', category: 'general' };
    let editingTrainingIdx = -1;

    // Handoff keyword input
    let handoffKeywordInput = '';

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccount();
    });

    async function loadAccount() {
        try {
            const { data } = await supabase.from('wa_accounts').select('id').eq('is_default', true).single();
            if (data) {
                accountId = data.id;
                await Promise.all([loadConfig(), checkApiKey(), loadLogs()]);
            }
        } catch {} finally { loading = false; }
    }

    async function loadConfig() {
        const { data } = await supabase.from('wa_ai_bot_config').select('*').single();
        if (data) {
            config = {
                ...config,
                ...data,
                handoff_keywords: data.handoff_keywords || config.handoff_keywords,
                training_data: data.training_data || []
            };
        }
    }

    async function checkApiKey() {
        // Check if OPENAI_API_KEY is set by testing the edge function
        try {
            const { data: settings } = await supabase.from('wa_settings').select('value').eq('key', 'openai_api_configured').single();
            apiKeyStatus = settings?.value === 'true' ? 'configured' : 'missing';
        } catch {
            apiKeyStatus = 'unknown';
        }
    }

    async function loadLogs() {
        try {
            const { data } = await supabase
                .from('wa_conversations')
                .select('id, customer_phone, customer_name, unread_count, last_message_at, is_bot_handling, bot_type')
                .eq('wa_account_id', accountId)
                .eq('bot_type', 'ai')
                .order('last_message_at', { ascending: false })
                .limit(50);
            conversationLogs = (data || []).map((c: any) => ({
                id: c.id,
                customer_phone: c.customer_phone,
                customer_name: c.customer_name,
                message_count: c.unread_count || 0,
                last_message_at: c.last_message_at,
                was_handed_off: !c.is_bot_handling
            }));
        } catch {}
    }

    async function saveConfig() {
        saving = true;
        try {
            const payload = {
                is_enabled: config.is_enabled,
                system_prompt: config.system_prompt,
                tone: config.tone,
                max_tokens: config.max_tokens,
                temperature: config.temperature,
                handoff_keywords: config.handoff_keywords,
                handoff_message: config.handoff_message,
                training_data: config.training_data,
                response_language: config.response_language,
                max_messages_before_handoff: config.max_messages_before_handoff
            };

            if (config.id) {
                await supabase.from('wa_ai_bot_config').update(payload).eq('id', config.id);
            } else {
                const { data } = await supabase.from('wa_ai_bot_config').insert({ ...payload, wa_account_id: accountId }).select().single();
                if (data) config.id = data.id;
            }
        } catch (e: any) {
            alert('Error: ' + e.message);
        } finally { saving = false; }
    }

    async function toggleBot() {
        config.is_enabled = !config.is_enabled;
        await saveConfig();
    }

    function addTrainingItem() {
        if (!newTraining.question.trim() || !newTraining.answer.trim()) return;
        config.training_data = [...config.training_data, {
            id: crypto.randomUUID(),
            question: newTraining.question,
            answer: newTraining.answer,
            category: newTraining.category
        }];
        newTraining = { id: '', question: '', answer: '', category: 'general' };
    }

    function removeTrainingItem(idx: number) {
        config.training_data = config.training_data.filter((_, i) => i !== idx);
    }

    function addHandoffKeyword() {
        if (!handoffKeywordInput.trim()) return;
        config.handoff_keywords = [...config.handoff_keywords, handoffKeywordInput.trim()];
        handoffKeywordInput = '';
    }

    function removeHandoffKeyword(idx: number) {
        config.handoff_keywords = config.handoff_keywords.filter((_, i) => i !== idx);
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
                <!-- API Key Status -->
                <span class="px-3 py-1.5 text-xs font-bold rounded-lg
                    {apiKeyStatus === 'configured' ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-600'}">
                    {apiKeyStatus === 'configured' ? '🔑 API Key Set' : '⚠️ API Key Not Set'}
                </span>
                <!-- Bot Toggle -->
                <button class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs transition-all
                    {config.is_enabled ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'}"
                    on:click={toggleBot}>
                    <span class="w-3 h-3 rounded-full {config.is_enabled ? 'bg-emerald-500' : 'bg-slate-400'}"></span>
                    {config.is_enabled ? 'AI Bot Active' : 'AI Bot Inactive'}
                </button>
            </div>
        </div>

        <!-- Tabs -->
        <div class="flex gap-1 mt-3 bg-slate-100 p-1.5 rounded-2xl w-fit">
            {#each [
                { id: 'settings', label: '⚙️ Settings' },
                { id: 'training', label: '📚 Training Data' },
                { id: 'logs', label: '📊 Conversation Logs' }
            ] as tab}
                <button class="px-5 py-2 text-xs font-bold rounded-xl transition-all
                    {activeTab === tab.id ? 'bg-emerald-600 text-white shadow-lg' : 'text-slate-600 hover:text-slate-800'}"
                    on:click={() => activeTab = tab.id}>
                    {tab.label}
                </button>
            {/each}
        </div>
    </div>

    <div class="flex-1 overflow-y-auto p-6">
        {#if loading}
            <div class="flex justify-center items-center h-full">
                <div class="animate-spin w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
            </div>

        {:else if activeTab === 'settings'}
            <div class="max-w-3xl space-y-5">
                <!-- API Key Info -->
                {#if apiKeyStatus !== 'configured'}
                    <div class="bg-amber-50 border border-amber-200 rounded-2xl p-5">
                        <h3 class="text-sm font-bold text-amber-700 mb-2">⚠️ OpenAI API Key Required</h3>
                        <p class="text-xs text-amber-600">The OpenAI API key must be set as an environment variable on the server. Add <code class="bg-amber-100 px-1 rounded">OPENAI_API_KEY</code> to:</p>
                        <ul class="text-xs text-amber-600 mt-2 space-y-1 list-disc list-inside">
                            <li>Vercel Environment Variables (for edge functions)</li>
                            <li>Server .env file (for Supabase edge functions)</li>
                        </ul>
                    </div>
                {/if}

                <!-- System Prompt / Personality -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <label class="block text-xs font-bold text-slate-600 uppercase mb-3">System Prompt / Personality</label>
                    <textarea bind:value={config.system_prompt} rows="6"
                        placeholder="Define the bot's personality, role, and behavior..."
                        class="w-full px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none"></textarea>
                </div>

                <!-- Tone & Language -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <div class="grid grid-cols-2 gap-6">
                        <div>
                            <label class="block text-xs font-bold text-slate-600 uppercase mb-2">Tone</label>
                            <div class="flex flex-wrap gap-2">
                                {#each [
                                    { id: 'professional', label: '👔 Professional' },
                                    { id: 'friendly', label: '😊 Friendly' },
                                    { id: 'casual', label: '💬 Casual' },
                                    { id: 'formal', label: '📜 Formal' }
                                ] as tone}
                                    <button class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
                                        {config.tone === tone.id ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                                        on:click={() => config.tone = tone.id}>
                                        {tone.label}
                                    </button>
                                {/each}
                            </div>
                        </div>
                        <div>
                            <label class="block text-xs font-bold text-slate-600 uppercase mb-2">Response Language</label>
                            <div class="flex flex-wrap gap-2">
                                {#each [
                                    { id: 'auto', label: '🌐 Auto-detect' },
                                    { id: 'en', label: '🇺🇸 English' },
                                    { id: 'ar', label: '🇸🇦 Arabic' },
                                    { id: 'both', label: '🔄 Bilingual' }
                                ] as lang}
                                    <button class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
                                        {config.response_language === lang.id ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                                        on:click={() => config.response_language = lang.id}>
                                        {lang.label}
                                    </button>
                                {/each}
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Model Parameters -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <label class="block text-xs font-bold text-slate-600 uppercase mb-3">Model Parameters</label>
                    <div class="grid grid-cols-2 gap-6">
                        <div>
                            <label class="text-[10px] text-slate-400 font-bold">Max Tokens (response length)</label>
                            <input type="number" bind:value={config.max_tokens} min="50" max="2000"
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm mt-1" />
                            <input type="range" bind:value={config.max_tokens} min="50" max="2000" step="50" class="w-full mt-1" />
                        </div>
                        <div>
                            <label class="text-[10px] text-slate-400 font-bold">Temperature (creativity: 0=precise, 1=creative)</label>
                            <input type="number" bind:value={config.temperature} min="0" max="1" step="0.1"
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm mt-1" />
                            <input type="range" bind:value={config.temperature} min="0" max="1" step="0.1" class="w-full mt-1" />
                        </div>
                    </div>
                </div>

                <!-- Handoff Rules -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <label class="block text-xs font-bold text-slate-600 uppercase mb-3">Human Handoff Rules</label>
                    
                    <div class="mb-4">
                        <label class="text-[10px] text-slate-400 font-bold">Max messages before auto-handoff</label>
                        <input type="number" bind:value={config.max_messages_before_handoff} min="1" max="50"
                            class="w-32 px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm mt-1" />
                    </div>

                    <div class="mb-4">
                        <label class="text-[10px] text-slate-400 font-bold mb-1 block">Handoff Trigger Keywords</label>
                        <div class="flex gap-2">
                            <input type="text" bind:value={handoffKeywordInput} placeholder="Add keyword..."
                                class="flex-1 px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs"
                                on:keydown={(e) => { if(e.key === 'Enter') { e.preventDefault(); addHandoffKeyword(); } }} />
                            <button class="px-3 py-2 bg-emerald-100 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-200"
                                on:click={addHandoffKeyword}>Add</button>
                        </div>
                        <div class="flex flex-wrap gap-1 mt-2">
                            {#each config.handoff_keywords as kw, idx}
                                <span class="px-2 py-1 bg-amber-100 text-amber-700 text-xs rounded-full font-bold flex items-center gap-1">
                                    {kw}
                                    <button class="text-amber-500 hover:text-red-500" on:click={() => removeHandoffKeyword(idx)}>✕</button>
                                </span>
                            {/each}
                        </div>
                    </div>

                    <div>
                        <label class="text-[10px] text-slate-400 font-bold">Handoff Message</label>
                        <input type="text" bind:value={config.handoff_message} placeholder="Message sent when handing off..."
                            class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs mt-1" />
                    </div>
                </div>

                <!-- Save -->
                <button class="w-full py-3.5 bg-emerald-600 text-white font-black text-sm rounded-2xl hover:bg-emerald-700 shadow-lg shadow-emerald-200 transition-all disabled:opacity-50"
                    on:click={saveConfig} disabled={saving}>
                    {saving ? '⏳ Saving...' : '💾 Save Configuration'}
                </button>
            </div>

        {:else if activeTab === 'training'}
            <div class="max-w-4xl space-y-5">
                <!-- Add Training Data -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <h3 class="text-xs font-bold text-slate-600 uppercase mb-3">Add Training Data</h3>
                    <p class="text-[10px] text-slate-400 mb-4">Add Q&A pairs to help the AI answer common questions accurately.</p>
                    <div class="space-y-3">
                        <div>
                            <label class="text-[10px] text-slate-400 font-bold">Category</label>
                            <select bind:value={newTraining.category}
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs mt-1">
                                <option value="general">General</option>
                                <option value="products">Products & Services</option>
                                <option value="pricing">Pricing</option>
                                <option value="support">Support</option>
                                <option value="policies">Policies</option>
                                <option value="hours">Business Hours</option>
                                <option value="location">Location & Contact</option>
                            </select>
                        </div>
                        <div>
                            <label class="text-[10px] text-slate-400 font-bold">Question / Customer might ask</label>
                            <input type="text" bind:value={newTraining.question} placeholder="e.g., What are your working hours?"
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs mt-1" />
                        </div>
                        <div>
                            <label class="text-[10px] text-slate-400 font-bold">Answer / Bot should respond</label>
                            <textarea bind:value={newTraining.answer} rows="3" placeholder="e.g., Our working hours are Sunday to Thursday, 9 AM to 6 PM."
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs mt-1 resize-none"></textarea>
                        </div>
                        <button class="px-6 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700 disabled:opacity-50"
                            on:click={addTrainingItem} disabled={!newTraining.question.trim() || !newTraining.answer.trim()}>
                            ➕ Add Training Item
                        </button>
                    </div>
                </div>

                <!-- Training Data List -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <div class="flex items-center justify-between mb-4">
                        <h3 class="text-xs font-bold text-slate-600 uppercase">Training Data ({config.training_data.length} items)</h3>
                    </div>
                    {#if config.training_data.length === 0}
                        <div class="text-center py-8">
                            <div class="text-3xl mb-2">📚</div>
                            <p class="text-xs text-slate-400">No training data yet. Add Q&A pairs above.</p>
                        </div>
                    {:else}
                        <div class="space-y-3">
                            {#each config.training_data as item, idx}
                                <div class="bg-slate-50 rounded-xl p-4 border border-slate-100">
                                    <div class="flex items-start justify-between">
                                        <div class="flex-1">
                                            <span class="px-2 py-0.5 text-[9px] font-bold bg-blue-100 text-blue-600 rounded-full">{item.category}</span>
                                            <p class="text-xs font-bold text-slate-700 mt-1">Q: {item.question}</p>
                                            <p class="text-xs text-slate-500 mt-1">A: {item.answer}</p>
                                        </div>
                                        <button class="text-red-400 hover:text-red-600 text-sm ml-3" on:click={() => removeTrainingItem(idx)}>🗑️</button>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    {/if}
                </div>

                <!-- Save Training Data -->
                <button class="w-full py-3.5 bg-emerald-600 text-white font-black text-sm rounded-2xl hover:bg-emerald-700 shadow-lg shadow-emerald-200 disabled:opacity-50"
                    on:click={saveConfig} disabled={saving}>
                    {saving ? '⏳ Saving...' : '💾 Save Training Data'}
                </button>
            </div>

        {:else if activeTab === 'logs'}
            <div class="max-w-4xl">
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <h3 class="text-xs font-bold text-slate-600 uppercase mb-4">AI Bot Conversation Log</h3>
                    {#if conversationLogs.length === 0}
                        <div class="text-center py-12">
                            <div class="text-3xl mb-2">📊</div>
                            <p class="text-xs text-slate-400">No AI bot conversations yet</p>
                        </div>
                    {:else}
                        <div class="overflow-x-auto">
                            <table class="w-full text-sm">
                                <thead>
                                    <tr class="text-left text-xs text-slate-400 uppercase border-b border-slate-200">
                                        <th class="py-2 px-3">Customer</th>
                                        <th class="py-2 px-3">Phone</th>
                                        <th class="py-2 px-3">Messages</th>
                                        <th class="py-2 px-3">Status</th>
                                        <th class="py-2 px-3">Last Activity</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {#each conversationLogs as log}
                                        <tr class="border-b border-slate-100 hover:bg-slate-50">
                                            <td class="py-2.5 px-3 text-xs font-bold text-slate-700">{log.customer_name || 'Unknown'}</td>
                                            <td class="py-2.5 px-3 text-xs font-mono text-slate-500">{log.customer_phone}</td>
                                            <td class="py-2.5 px-3 text-xs">{log.message_count}</td>
                                            <td class="py-2.5 px-3">
                                                <span class="px-2 py-0.5 text-[10px] font-bold rounded-full
                                                    {log.was_handed_off ? 'bg-amber-100 text-amber-600' : 'bg-emerald-100 text-emerald-600'}">
                                                    {log.was_handed_off ? '👤 Handed Off' : '🤖 AI Handling'}
                                                </span>
                                            </td>
                                            <td class="py-2.5 px-3 text-xs text-slate-400">{log.last_message_at ? new Date(log.last_message_at).toLocaleString() : '-'}</td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                    {/if}
                </div>
            </div>
        {/if}
    </div>
</div>
