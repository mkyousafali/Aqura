<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import WAFlowBuilder from './WAFlowBuilder.svelte';

    interface Trigger {
        id: string;
        name: string;
        trigger_words: string[];
        trigger_words_ar: string[];
        match_type: string; // exact, contains, starts_with, regex
        response_type: string; // text, image, document, template, buttons, interactive
        response_content: string;
        response_media_url: string;
        response_template_name: string;
        response_buttons: any[];
        follow_up_delay_seconds: number;
        follow_up_content: string;
        priority: number;
        is_active: boolean;
        created_at: string;
    }

    let supabase: any = null;
    let accountId = '';
    let loading = true;
    let saving = false;
    let triggers: Trigger[] = [];
    let botEnabled = false;
    let activeTab = 'list'; // list, create, test, flows
    let editingTrigger: Partial<Trigger> | null = null;
    let testInput = '';
    let testResult: string | null = null;
    let testMatchedTrigger: Trigger | null = null;
    let testMatchedFlow: any = null;
    let flows: any[] = [];
    let chatMessages: { type: 'user' | 'bot'; text: string; time: string; media?: string; mediaType?: string; buttons?: any[]; followUp?: string; followUpDelay?: number; flowSteps?: any[]; matchInfo?: string }[] = [];
    let chatContainer: HTMLDivElement;

    // Templates for template-type responses
    let templates: { id: string; name: string; language: string }[] = [];

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
                await Promise.all([loadTriggers(), loadBotStatus(), loadTemplates(), loadFlows()]);
            }
        } catch {} finally { loading = false; }
    }

    async function loadTriggers() {
        const { data } = await supabase.from('wa_auto_reply_triggers').select('*').eq('wa_account_id', accountId).order('priority', { ascending: true });
        triggers = data || [];
    }

    async function loadBotStatus() {
        const { data } = await supabase.from('wa_settings').select('auto_reply_enabled').eq('wa_account_id', accountId).maybeSingle();
        botEnabled = data?.auto_reply_enabled === true;
    }

    async function loadFlows() {
        const { data } = await supabase.from('wa_bot_flows').select('*').eq('wa_account_id', accountId).order('priority', { ascending: true });
        flows = data || [];
    }

    async function loadTemplates() {
        const { data } = await supabase.from('wa_templates').select('id, name, language').eq('wa_account_id', accountId).eq('status', 'APPROVED');
        templates = data || [];
    }

    async function toggleBotEnabled() {
        botEnabled = !botEnabled;
        await supabase.from('wa_settings').update({
            auto_reply_enabled: botEnabled
        }).eq('wa_account_id', accountId);
    }

    function startCreateTrigger() {
        editingTrigger = {
            name: '',
            trigger_words: [],
            trigger_words_ar: [],
            match_type: 'contains',
            response_type: 'text',
            response_content: '',
            response_media_url: '',
            response_template_name: '',
            response_buttons: [],
            follow_up_delay_seconds: 0,
            follow_up_content: '',
            priority: triggers.length + 1,
            is_active: true
        };
        activeTab = 'create';
    }

    function editTrigger(trigger: Trigger) {
        editingTrigger = { ...trigger };
        activeTab = 'create';
    }

    let triggerWordInput = '';
    let triggerWordArInput = '';

    function addTriggerWord(lang: 'en' | 'ar') {
        if (!editingTrigger) return;
        const input = lang === 'en' ? triggerWordInput : triggerWordArInput;
        if (!input.trim()) return;
        if (lang === 'en') {
            editingTrigger.trigger_words = [...(editingTrigger.trigger_words || []), input.trim()];
            triggerWordInput = '';
        } else {
            editingTrigger.trigger_words_ar = [...(editingTrigger.trigger_words_ar || []), input.trim()];
            triggerWordArInput = '';
        }
    }

    function removeTriggerWord(lang: 'en' | 'ar', idx: number) {
        if (!editingTrigger) return;
        if (lang === 'en') {
            editingTrigger.trigger_words = editingTrigger.trigger_words!.filter((_, i) => i !== idx);
        } else {
            editingTrigger.trigger_words_ar = editingTrigger.trigger_words_ar!.filter((_, i) => i !== idx);
        }
    }

    function addButton() {
        if (!editingTrigger) return;
        editingTrigger.response_buttons = [...(editingTrigger.response_buttons || []),
            { type: 'reply', title: '' }
        ];
    }

    function removeButton(idx: number) {
        if (!editingTrigger) return;
        editingTrigger.response_buttons = editingTrigger.response_buttons!.filter((_, i) => i !== idx);
    }

    async function saveTrigger() {
        if (!editingTrigger || !editingTrigger.name?.trim() || saving) return;
        saving = true;
        try {
            const payload = {
                wa_account_id: accountId,
                name: editingTrigger.name,
                trigger_words: editingTrigger.trigger_words || [],
                trigger_words_en: editingTrigger.trigger_words || [],
                trigger_words_ar: editingTrigger.trigger_words_ar || [],
                match_type: editingTrigger.match_type,
                response_type: editingTrigger.response_type,
                response_content: editingTrigger.response_content,
                response_media_url: editingTrigger.response_media_url,
                response_template_name: editingTrigger.response_template_name,
                response_buttons: editingTrigger.response_buttons,
                reply_type: editingTrigger.response_type,
                reply_text: editingTrigger.response_content,
                reply_media_url: editingTrigger.response_media_url,
                reply_buttons: editingTrigger.response_buttons,
                follow_up_delay_seconds: editingTrigger.follow_up_delay_seconds || 0,
                follow_up_content: editingTrigger.follow_up_content,
                priority: editingTrigger.priority,
                sort_order: editingTrigger.priority,
                is_active: editingTrigger.is_active
            };

            if (editingTrigger.id) {
                await supabase.from('wa_auto_reply_triggers').update(payload).eq('id', editingTrigger.id);
            } else {
                await supabase.from('wa_auto_reply_triggers').insert(payload);
            }
            await loadTriggers();
            activeTab = 'list';
            editingTrigger = null;
        } catch (e: any) {
            console.error(e);
            alert('Error: ' + e.message);
        } finally { saving = false; }
    }

    async function deleteTrigger(id: string) {
        if (!confirm('Delete this trigger?')) return;
        await supabase.from('wa_auto_reply_triggers').delete().eq('id', id);
        await loadTriggers();
    }

    async function toggleTrigger(trigger: Trigger) {
        await supabase.from('wa_auto_reply_triggers').update({ is_active: !trigger.is_active }).eq('id', trigger.id);
        trigger.is_active = !trigger.is_active;
        triggers = [...triggers];
    }

    function testAutoReply() {
        if (!testInput.trim()) return;
        const input = testInput.trim();
        const now = new Date();
        const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        
        // Add user message
        chatMessages = [...chatMessages, { type: 'user', text: input, time: timeStr }];
        
        const inputLower = input.toLowerCase();
        testMatchedFlow = null;
        testMatchedTrigger = null;
        testResult = null;
        
        // Combine triggers and flows into a single sorted list by priority
        const allItems: { type: 'trigger' | 'flow'; priority: number; item: any }[] = [];
        
        for (const trigger of triggers.filter(t => t.is_active)) {
            allItems.push({ type: 'trigger', priority: trigger.priority, item: trigger });
        }
        for (const flow of flows.filter(f => f.is_active)) {
            allItems.push({ type: 'flow', priority: flow.priority, item: flow });
        }
        allItems.sort((a, b) => a.priority - b.priority);
        
        let matched = false;
        for (const entry of allItems) {
            let words: string[] = [];
            let matchType = '';
            if (entry.type === 'trigger') {
                words = [...(entry.item.trigger_words || []), ...(entry.item.trigger_words_ar || [])];
                matchType = entry.item.match_type;
            } else {
                words = [...(entry.item.trigger_words_en || []), ...(entry.item.trigger_words_ar || [])];
                matchType = entry.item.match_type;
            }
            for (const word of words) {
                const w = word.toLowerCase();
                let isMatch = false;
                if (matchType === 'exact') isMatch = inputLower === w;
                else if (matchType === 'contains') isMatch = inputLower.includes(w);
                else if (matchType === 'starts_with') isMatch = inputLower.startsWith(w);
                else if (matchType === 'regex') {
                    try { isMatch = new RegExp(w, 'i').test(inputLower); } catch {}
                }
                if (isMatch) {
                    matched = true;
                    if (entry.type === 'trigger') {
                        testMatchedTrigger = entry.item;
                        const trigger = entry.item;
                        const botMsg: typeof chatMessages[0] = {
                            type: 'bot',
                            text: trigger.response_content || '',
                            time: timeStr,
                            matchInfo: `Trigger: "${trigger.name}" (#${trigger.priority}, ${trigger.match_type})`,
                            buttons: trigger.response_buttons || [],
                            followUp: trigger.follow_up_content || '',
                            followUpDelay: trigger.follow_up_delay_seconds || 0,
                        };
                        if (trigger.response_type === 'image' || trigger.response_type === 'document' || trigger.response_type === 'video') {
                            botMsg.media = trigger.response_media_url;
                            botMsg.mediaType = trigger.response_type;
                        }
                        if (trigger.response_type === 'template') {
                            botMsg.text = `📝 Template: ${trigger.response_template_name}`;
                        }
                        chatMessages = [...chatMessages, botMsg];
                    } else {
                        testMatchedFlow = entry.item;
                        const flow = entry.item;
                        const nodes = flow.nodes || [];
                        const flowSteps = nodes.filter((n: any) => n.type !== 'start').map((n: any) => {
                            if (n.type === 'text') return { type: 'text', text: n.data?.text || 'Text message' };
                            if (n.type === 'image') return { type: 'image', url: n.data?.mediaUrl, caption: n.data?.caption };
                            if (n.type === 'video') return { type: 'video', url: n.data?.mediaUrl, caption: n.data?.caption };
                            if (n.type === 'document') return { type: 'document', url: n.data?.mediaUrl, filename: n.data?.filename || 'file' };
                            if (n.type === 'buttons') return { type: 'buttons', text: n.data?.text || '', buttons: n.data?.buttons || [] };
                            if (n.type === 'delay') return { type: 'delay', seconds: n.data?.delaySeconds || 0 };
                            if (n.type === 'subscribe') return { type: 'action', text: '📥 Subscribe action' };
                            if (n.type === 'unsubscribe') return { type: 'action', text: '📤 Unsubscribe action' };
                            return { type: 'other', text: n.type };
                        });
                        chatMessages = [...chatMessages, {
                            type: 'bot',
                            text: '',
                            time: timeStr,
                            matchInfo: `Flow: "${flow.name}" (#${flow.priority}, ${flow.match_type}, ${nodes.length} nodes)`,
                            flowSteps
                        }];
                    }
                    break;
                }
            }
            if (matched) break;
        }
        
        if (!matched) {
            chatMessages = [...chatMessages, { type: 'bot', text: '❌ No matching trigger or flow found for this message.', time: timeStr }];
        }
        
        testInput = '';
        // Scroll to bottom
        setTimeout(() => { if (chatContainer) chatContainer.scrollTop = chatContainer.scrollHeight; }, 50);
    }
    
    function clearChat() {
        chatMessages = [];
        testResult = null;
        testMatchedTrigger = null;
        testMatchedFlow = null;
    }

    function handleTriggerWordKeydown(e: KeyboardEvent, lang: 'en' | 'ar') {
        if (e.key === 'Enter') {
            e.preventDefault();
            addTriggerWord(lang);
        }
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4">
        <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
                <span class="text-2xl">🔧</span>
                <h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappAutoReply')}</h1>
            </div>
            <div class="flex items-center gap-3">
                <!-- Bot Toggle -->
                <button class="flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs transition-all
                    {botEnabled ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500'}"
                    on:click={toggleBotEnabled}>
                    <span class="w-3 h-3 rounded-full {botEnabled ? 'bg-emerald-500' : 'bg-slate-400'}"></span>
                    {botEnabled ? 'Bot Active' : 'Bot Inactive'}
                </button>
                {#if activeTab === 'list'}
                    <button class="px-6 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700 shadow-lg shadow-emerald-200"
                        on:click={startCreateTrigger}>
                        + New Trigger
                    </button>
                {/if}
            </div>
        </div>
        <!-- Tabs -->
        <div class="flex gap-1 mt-3 bg-slate-100 p-1.5 rounded-2xl w-fit">
            {#each [
                { id: 'list', label: '📋 Triggers', icon: '' },
                { id: 'flows', label: '🔀 Flow Builder', icon: '' },
                { id: 'test', label: '🧪 Test Area', icon: '' }
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

        {:else if activeTab === 'list'}
            {#if triggers.length === 0}
                <div class="flex flex-col items-center justify-center py-20">
                    <div class="text-5xl mb-4">🔧</div>
                    <h3 class="text-lg font-bold text-slate-600">No Auto-Reply Triggers</h3>
                    <p class="text-sm text-slate-400 mt-1">Create keyword-based auto-reply rules</p>
                    <button class="mt-4 px-6 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700"
                        on:click={startCreateTrigger}>+ Create Trigger</button>
                </div>
            {:else}
                <div class="space-y-3">
                    {#each triggers as trigger, idx}
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5 hover:shadow-lg transition-all
                            {!trigger.is_active ? 'opacity-60' : ''}">
                            <div class="flex items-start justify-between">
                                <div class="flex-1">
                                    <div class="flex items-center gap-2">
                                        <span class="text-xs text-slate-400 font-mono">#{trigger.priority}</span>
                                        <h3 class="font-bold text-sm text-slate-800">{trigger.name}</h3>
                                        <span class="px-2 py-0.5 text-[10px] font-bold rounded-full
                                            {trigger.match_type === 'exact' ? 'bg-blue-100 text-blue-600' :
                                             trigger.match_type === 'contains' ? 'bg-amber-100 text-amber-600' :
                                             trigger.match_type === 'starts_with' ? 'bg-purple-100 text-purple-600' :
                                             'bg-pink-100 text-pink-600'}">
                                            {trigger.match_type}
                                        </span>
                                        <span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-slate-100 text-slate-600">
                                            {trigger.response_type}
                                        </span>
                                    </div>
                                    <!-- Trigger Words -->
                                    <div class="flex flex-wrap gap-1 mt-2">
                                        {#each (trigger.trigger_words || []) as word}
                                            <span class="px-2 py-0.5 text-[10px] bg-emerald-100 text-emerald-700 rounded-full font-bold">🇺🇸 {word}</span>
                                        {/each}
                                        {#each (trigger.trigger_words_ar || []) as word}
                                            <span class="px-2 py-0.5 text-[10px] bg-blue-100 text-blue-700 rounded-full font-bold">🇸🇦 {word}</span>
                                        {/each}
                                    </div>
                                    <!-- Response Preview -->
                                    <p class="text-xs text-slate-500 mt-2 line-clamp-1">
                                        {trigger.response_type === 'template' ? `📝 Template: ${trigger.response_template_name}` : trigger.response_content || ''}
                                    </p>
                                </div>
                                <div class="flex items-center gap-2 ml-4">
                                    <button class="w-8 h-8 rounded-lg flex items-center justify-center text-sm transition-colors
                                        {trigger.is_active ? 'bg-emerald-100 text-emerald-600 hover:bg-emerald-200' : 'bg-slate-100 text-slate-400 hover:bg-slate-200'}"
                                        on:click={() => toggleTrigger(trigger)} title={trigger.is_active ? 'Deactivate' : 'Activate'}>
                                        {trigger.is_active ? '✅' : '⏸️'}
                                    </button>
                                    <button class="w-8 h-8 bg-blue-100 text-blue-600 rounded-lg flex items-center justify-center text-sm hover:bg-blue-200"
                                        on:click={() => editTrigger(trigger)} title="Edit">
                                        ✏️
                                    </button>
                                    <button class="w-8 h-8 bg-red-100 text-red-600 rounded-lg flex items-center justify-center text-sm hover:bg-red-200"
                                        on:click={() => deleteTrigger(trigger.id)} title="Delete">
                                        🗑️
                                    </button>
                                </div>
                            </div>
                        </div>
                    {/each}
                </div>
            {/if}

        {:else if activeTab === 'create' && editingTrigger}
            <!-- Create/Edit Trigger Form -->
            <div class="max-w-3xl space-y-5">
                <!-- Name & Priority -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <div class="grid grid-cols-3 gap-4">
                        <div class="col-span-2">
                            <label class="block text-xs font-bold text-slate-600 uppercase mb-1.5">Trigger Name</label>
                            <input type="text" bind:value={editingTrigger.name} placeholder="e.g., Welcome Greeting"
                                class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                        </div>
                        <div>
                            <label class="block text-xs font-bold text-slate-600 uppercase mb-1.5">Priority</label>
                            <input type="number" bind:value={editingTrigger.priority} min="1"
                                class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                        </div>
                    </div>
                </div>

                <!-- Trigger Words -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <label class="block text-xs font-bold text-slate-600 uppercase mb-3">Trigger Keywords</label>
                    
                    <!-- Match Type -->
                    <div class="flex gap-2 mb-4">
                        {#each [
                            { id: 'contains', label: 'Contains' },
                            { id: 'exact', label: 'Exact Match' },
                            { id: 'starts_with', label: 'Starts With' },
                            { id: 'regex', label: 'Regex' }
                        ] as mt}
                            <button class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
                                {editingTrigger.match_type === mt.id ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                                on:click={() => { if(editingTrigger) editingTrigger.match_type = mt.id; }}>
                                {mt.label}
                            </button>
                        {/each}
                    </div>

                    <!-- English Keywords -->
                    <div class="mb-3">
                        <label class="text-[10px] text-slate-400 font-bold">🇺🇸 English Keywords</label>
                        <div class="flex gap-2 mt-1">
                            <input type="text" bind:value={triggerWordInput} placeholder="Type keyword and press Enter"
                                class="flex-1 px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                on:keydown={(e) => handleTriggerWordKeydown(e, 'en')} />
                            <button class="px-3 py-2 bg-emerald-100 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-200"
                                on:click={() => addTriggerWord('en')}>Add</button>
                        </div>
                        <div class="flex flex-wrap gap-1 mt-2">
                            {#each (editingTrigger.trigger_words || []) as word, idx}
                                <span class="px-2 py-1 bg-emerald-100 text-emerald-700 text-xs rounded-full font-bold flex items-center gap-1">
                                    {word}
                                    <button class="text-emerald-500 hover:text-red-500" on:click={() => removeTriggerWord('en', idx)}>✕</button>
                                </span>
                            {/each}
                        </div>
                    </div>

                    <!-- Arabic Keywords -->
                    <div>
                        <label class="text-[10px] text-slate-400 font-bold">🇸🇦 Arabic Keywords</label>
                        <div class="flex gap-2 mt-1">
                            <input type="text" bind:value={triggerWordArInput} placeholder="اكتب كلمة واضغط Enter" dir="rtl"
                                class="flex-1 px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-2 focus:ring-emerald-500"
                                on:keydown={(e) => handleTriggerWordKeydown(e, 'ar')} />
                            <button class="px-3 py-2 bg-blue-100 text-blue-700 text-xs font-bold rounded-lg hover:bg-blue-200"
                                on:click={() => addTriggerWord('ar')}>Add</button>
                        </div>
                        <div class="flex flex-wrap gap-1 mt-2">
                            {#each (editingTrigger.trigger_words_ar || []) as word, idx}
                                <span class="px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded-full font-bold flex items-center gap-1">
                                    {word}
                                    <button class="text-blue-500 hover:text-red-500" on:click={() => removeTriggerWord('ar', idx)}>✕</button>
                                </span>
                            {/each}
                        </div>
                    </div>
                </div>

                <!-- Response -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <label class="block text-xs font-bold text-slate-600 uppercase mb-3">Response</label>
                    
                    <!-- Response Type -->
                    <div class="flex flex-wrap gap-2 mb-4">
                        {#each [
                            { id: 'text', label: '💬 Text', icon: '' },
                            { id: 'image', label: '🖼️ Image', icon: '' },
                            { id: 'document', label: '📎 Document', icon: '' },
                            { id: 'template', label: '📝 Template', icon: '' },
                            { id: 'interactive', label: '🔘 Buttons & Links', icon: '' }
                        ] as rt}
                            <button class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
                                {editingTrigger.response_type === rt.id ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                                on:click={() => { if(editingTrigger) editingTrigger.response_type = rt.id; }}>
                                {rt.label}
                            </button>
                        {/each}
                    </div>

                    {#if editingTrigger.response_type === 'text' || editingTrigger.response_type === 'interactive'}
                        <textarea bind:value={editingTrigger.response_content} rows="4" placeholder="Type response message..."
                            class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none"></textarea>
                    {/if}

                    {#if editingTrigger.response_type === 'image' || editingTrigger.response_type === 'document'}
                        <input type="url" bind:value={editingTrigger.response_media_url} placeholder="Media URL (https://...)"
                            class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 mb-3" />
                        <textarea bind:value={editingTrigger.response_content} rows="2" placeholder="Caption (optional)"
                            class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none"></textarea>
                    {/if}

                    {#if editingTrigger.response_type === 'template'}
                        <select bind:value={editingTrigger.response_template_name}
                            class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500">
                            <option value="">Select template...</option>
                            {#each templates as tmpl}
                                <option value={tmpl.name}>{tmpl.name} ({tmpl.language.toUpperCase()})</option>
                            {/each}
                        </select>
                    {/if}

                    {#if editingTrigger.response_type === 'interactive'}
                        <!-- Buttons Builder -->
                        <div class="mt-4 border-t border-slate-200 pt-4">
                            <div class="flex items-center justify-between mb-3">
                                <label class="text-xs font-bold text-slate-600">Buttons (max 3)</label>
                                {#if (editingTrigger.response_buttons || []).length < 3}
                                    <button class="px-3 py-1 bg-emerald-100 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-200"
                                        on:click={addButton}>+ Add Button</button>
                                {/if}
                            </div>
                            <div class="space-y-2">
                                {#each (editingTrigger.response_buttons || []) as btn, idx}
                                    <div class="flex items-center gap-2 bg-slate-50 rounded-xl p-3">
                                        <select bind:value={btn.type}
                                            class="px-2 py-1.5 bg-white border border-slate-200 rounded-lg text-xs">
                                            <option value="reply">↩️ Quick Reply</option>
                                            <option value="url">🔗 URL Link</option>
                                            <option value="phone">📞 Call</option>
                                        </select>
                                        <input type="text" bind:value={btn.title} placeholder="Button text"
                                            class="flex-1 px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs" />
                                        {#if btn.type === 'url'}
                                            <input type="url" bind:value={btn.url} placeholder="https://..."
                                                class="flex-1 px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs" />
                                        {/if}
                                        {#if btn.type === 'phone'}
                                            <input type="text" bind:value={btn.phone} placeholder="+966..."
                                                class="w-36 px-3 py-1.5 bg-white border border-slate-200 rounded-lg text-xs" />
                                        {/if}
                                        <button class="text-red-400 hover:text-red-600 text-sm" on:click={() => removeButton(idx)}>✕</button>
                                    </div>
                                {/each}
                            </div>
                        </div>
                    {/if}
                </div>

                <!-- Follow-up -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <label class="block text-xs font-bold text-slate-600 uppercase mb-3">Follow-up Message (Optional)</label>
                    <div class="grid grid-cols-4 gap-4">
                        <div>
                            <label class="text-[10px] text-slate-400 font-bold">Delay (seconds)</label>
                            <input type="number" bind:value={editingTrigger.follow_up_delay_seconds} min="0" max="3600" placeholder="0"
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs mt-1" />
                        </div>
                        <div class="col-span-3">
                            <label class="text-[10px] text-slate-400 font-bold">Follow-up content</label>
                            <input type="text" bind:value={editingTrigger.follow_up_content} placeholder="Second message after delay..."
                                class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs mt-1" />
                        </div>
                    </div>
                </div>

                <!-- Active Toggle + Save -->
                <div class="flex items-center justify-between">
                    <label class="flex items-center gap-2 cursor-pointer">
                        <input type="checkbox" bind:checked={editingTrigger.is_active} class="w-4 h-4 rounded text-emerald-600" />
                        <span class="text-sm font-bold text-slate-700">{editingTrigger.is_active ? '✅ Active' : '⏸️ Inactive'}</span>
                    </label>
                    <div class="flex gap-3">
                        <button class="px-6 py-2.5 bg-slate-200 text-slate-700 font-bold text-xs rounded-xl hover:bg-slate-300"
                            on:click={() => { activeTab = 'list'; editingTrigger = null; }}>
                            Cancel
                        </button>
                        <button class="px-8 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700 shadow-lg shadow-emerald-200 disabled:opacity-50"
                            on:click={saveTrigger} disabled={saving || !editingTrigger.name?.trim()}>
                            {saving ? '⏳ Saving...' : editingTrigger.id ? '💾 Update Trigger' : '➕ Create Trigger'}
                        </button>
                    </div>
                </div>
            </div>

        {:else if activeTab === 'flows'}
            <!-- Flow Builder -->
            <div class="-m-6 h-[calc(100%+3rem)]">
                <WAFlowBuilder />
            </div>

        {:else if activeTab === 'test'}
            <!-- Test Area - Mobile Phone Preview -->
            <div class="flex gap-6 h-full max-w-5xl mx-auto">
                <!-- Phone Mockup -->
                <div class="flex-shrink-0 flex flex-col items-center">
                    <div class="phone-frame">
                        <!-- Phone Notch -->
                        <div class="phone-notch"></div>
                        <!-- WhatsApp Header -->
                        <div class="wa-header">
                            <div class="flex items-center gap-2">
                                <div class="w-8 h-8 rounded-full bg-emerald-600 flex items-center justify-center text-white text-xs font-bold">🤖</div>
                                <div>
                                    <p class="text-white text-xs font-bold">Auto-Reply Bot</p>
                                    <p class="text-emerald-200 text-[10px]">{botEnabled ? 'online' : 'offline'}</p>
                                </div>
                            </div>
                            <button class="text-white/60 hover:text-white text-[10px] px-2 py-1 rounded-lg hover:bg-white/10 transition-all" on:click={clearChat}>Clear</button>
                        </div>
                        <!-- Chat Area -->
                        <div class="wa-chat-area" bind:this={chatContainer}>
                            <!-- WhatsApp-like wallpaper pattern -->
                            <div class="wa-wallpaper"></div>
                            
                            {#if chatMessages.length === 0}
                                <div class="flex flex-col items-center justify-center h-full text-center px-6 relative z-10">
                                    <div class="w-14 h-14 rounded-full bg-emerald-100 flex items-center justify-center mb-3">
                                        <span class="text-2xl">🧪</span>
                                    </div>
                                    <p class="text-[11px] font-bold text-slate-500">Test Your Bot</p>
                                    <p class="text-[10px] text-slate-400 mt-1">Send a message to see how the bot responds</p>
                                </div>
                            {:else}
                                <div class="flex flex-col gap-1 relative z-10 py-2">
                                    {#each chatMessages as msg, i}
                                        {#if msg.type === 'user'}
                                            <!-- User Message (right side, green) -->
                                            <div class="flex justify-end px-2">
                                                <div class="wa-bubble-user">
                                                    <p class="text-[12px] text-white leading-relaxed">{msg.text}</p>
                                                    <div class="flex justify-end gap-1 mt-0.5">
                                                        <span class="text-[9px] text-emerald-200">{msg.time}</span>
                                                        <span class="text-[9px] text-emerald-200">✓✓</span>
                                                    </div>
                                                </div>
                                            </div>
                                        {:else}
                                            <!-- Bot Response (left side, white) -->
                                            <div class="flex justify-start px-2">
                                                <div class="wa-bubble-bot">
                                                    {#if msg.matchInfo}
                                                        <div class="px-2 py-1 mb-1.5 rounded-md bg-emerald-50 border border-emerald-100">
                                                            <p class="text-[9px] text-emerald-600 font-bold">✅ {msg.matchInfo}</p>
                                                        </div>
                                                    {/if}
                                                    
                                                    {#if msg.flowSteps && msg.flowSteps.length > 0}
                                                        <!-- Flow Steps Preview -->
                                                        {#each msg.flowSteps as step, si}
                                                            {#if step.type === 'text'}
                                                                <div class="mb-1.5 {si > 0 ? 'border-t border-slate-100 pt-1.5' : ''}">
                                                                    <p class="text-[12px] text-slate-800 leading-relaxed">{step.text}</p>
                                                                </div>
                                                            {:else if step.type === 'image'}
                                                                <div class="mb-1.5 {si > 0 ? 'border-t border-slate-100 pt-1.5' : ''}">
                                                                    <div class="w-full h-24 bg-slate-100 rounded-lg flex items-center justify-center">
                                                                        <span class="text-2xl">🖼️</span>
                                                                    </div>
                                                                    {#if step.caption}<p class="text-[11px] text-slate-600 mt-1">{step.caption}</p>{/if}
                                                                </div>
                                                            {:else if step.type === 'video'}
                                                                <div class="mb-1.5 {si > 0 ? 'border-t border-slate-100 pt-1.5' : ''}">
                                                                    <div class="w-full h-24 bg-slate-800 rounded-lg flex items-center justify-center">
                                                                        <span class="text-2xl">▶️</span>
                                                                    </div>
                                                                    {#if step.caption}<p class="text-[11px] text-slate-600 mt-1">{step.caption}</p>{/if}
                                                                </div>
                                                            {:else if step.type === 'document'}
                                                                <div class="mb-1.5 {si > 0 ? 'border-t border-slate-100 pt-1.5' : ''}">
                                                                    <div class="flex items-center gap-2 px-3 py-2 bg-slate-50 rounded-lg border border-slate-200">
                                                                        <span class="text-lg">📄</span>
                                                                        <span class="text-[11px] text-slate-700 font-medium">{step.filename}</span>
                                                                    </div>
                                                                </div>
                                                            {:else if step.type === 'buttons'}
                                                                <div class="mb-1.5 {si > 0 ? 'border-t border-slate-100 pt-1.5' : ''}">
                                                                    {#if step.text}<p class="text-[12px] text-slate-800 mb-1.5">{step.text}</p>{/if}
                                                                    <div class="flex flex-col gap-1">
                                                                        {#each step.buttons as btn}
                                                                            <div class="wa-quick-reply-btn">
                                                                                {btn.type === 'phone' ? '📞' : btn.type === 'url' ? '🔗' : '↩️'} {btn.title}
                                                                            </div>
                                                                        {/each}
                                                                    </div>
                                                                </div>
                                                            {:else if step.type === 'delay'}
                                                                <div class="flex items-center gap-1 mb-1.5 px-2 py-1 bg-amber-50 rounded-md {si > 0 ? 'border-t border-slate-100' : ''}">
                                                                    <span class="text-[10px]">⏱️</span>
                                                                    <span class="text-[10px] text-amber-600 font-medium">Wait {step.seconds}s</span>
                                                                </div>
                                                            {:else}
                                                                <div class="mb-1.5 px-2 py-1 bg-slate-50 rounded-md text-[10px] text-slate-500">{step.text || step.type}</div>
                                                            {/if}
                                                        {/each}
                                                    {:else if msg.media}
                                                        <!-- Media message -->
                                                        {#if msg.mediaType === 'image'}
                                                            <div class="w-full h-28 bg-slate-100 rounded-lg flex items-center justify-center mb-1.5 overflow-hidden">
                                                                <img src={msg.media} alt="Preview" class="w-full h-full object-cover" on:error={(e) => { const el = e.currentTarget; if (el instanceof HTMLImageElement) { el.style.display = 'none'; if (el.parentElement) el.parentElement.innerHTML = '<span class=\"text-2xl\">🖼️</span>'; } }} />
                                                            </div>
                                                        {:else if msg.mediaType === 'video'}
                                                            <div class="w-full h-28 bg-slate-800 rounded-lg flex items-center justify-center mb-1.5">
                                                                <span class="text-2xl">▶️</span>
                                                            </div>
                                                        {:else}
                                                            <div class="flex items-center gap-2 px-3 py-2 bg-slate-50 rounded-lg border border-slate-200 mb-1.5">
                                                                <span class="text-lg">📄</span>
                                                                <span class="text-[11px] text-slate-700 font-medium">Document</span>
                                                            </div>
                                                        {/if}
                                                        {#if msg.text}<p class="text-[12px] text-slate-800">{msg.text}</p>{/if}
                                                    {:else}
                                                        <!-- Text message -->
                                                        <p class="text-[12px] text-slate-800 leading-relaxed">{msg.text}</p>
                                                    {/if}
                                                    
                                                    {#if msg.buttons && msg.buttons.length > 0 && !msg.flowSteps}
                                                        <div class="flex flex-col gap-1 mt-2 border-t border-slate-100 pt-2">
                                                            {#each msg.buttons as btn}
                                                                <div class="wa-quick-reply-btn">
                                                                    {btn.type === 'phone' ? '📞' : btn.type === 'url' ? '🔗' : '↩️'} {btn.title}
                                                                </div>
                                                            {/each}
                                                        </div>
                                                    {/if}
                                                    
                                                    {#if msg.followUp}
                                                        <div class="mt-2 pt-1.5 border-t border-slate-100">
                                                            <p class="text-[9px] text-amber-500 font-medium">⏱️ Follow-up after {msg.followUpDelay}s:</p>
                                                            <p class="text-[11px] text-slate-600 mt-0.5 italic">"{msg.followUp}"</p>
                                                        </div>
                                                    {/if}
                                                    
                                                    <div class="flex justify-end mt-0.5">
                                                        <span class="text-[9px] text-slate-400">{msg.time}</span>
                                                    </div>
                                                </div>
                                            </div>
                                        {/if}
                                    {/each}
                                </div>
                            {/if}
                        </div>
                        <!-- Message Input Bar -->
                        <div class="wa-input-bar">
                            <div class="flex items-center gap-1.5 flex-1">
                                <span class="text-sm text-slate-400">😊</span>
                                <input type="text" bind:value={testInput} placeholder="Type a message"
                                    class="flex-1 bg-transparent text-[12px] text-slate-700 placeholder-slate-400 outline-none"
                                    on:keydown={(e) => { if(e.key === 'Enter') testAutoReply(); }} />
                                <span class="text-sm text-slate-400">📎</span>
                            </div>
                            <button class="w-8 h-8 rounded-full bg-emerald-500 flex items-center justify-center flex-shrink-0 hover:bg-emerald-600 transition-colors"
                                on:click={testAutoReply}>
                                <span class="text-white text-sm">➤</span>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Side Panel: Active Triggers & Flows -->
                <div class="flex-1 overflow-y-auto space-y-4 min-w-0">
                    <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                        <h4 class="text-xs font-bold text-slate-600 uppercase mb-3">📋 Active Triggers ({triggers.filter(t => t.is_active).length})</h4>
                        {#each triggers.filter(t => t.is_active) as trigger}
                            <div class="flex items-center gap-3 py-2 border-b border-slate-100 last:border-0">
                                <span class="text-[10px] text-slate-400 font-mono">#{trigger.priority}</span>
                                <span class="text-xs font-bold text-slate-700 truncate">{trigger.name}</span>
                                <span class="px-1.5 py-0.5 text-[9px] bg-amber-100 text-amber-600 rounded font-bold flex-shrink-0">Trigger</span>
                                <div class="flex gap-0.5 ml-auto flex-shrink-0">
                                    {#each [...(trigger.trigger_words || []).slice(0, 2), ...(trigger.trigger_words_ar || []).slice(0, 1)] as word}
                                        <span class="px-1.5 py-0.5 text-[9px] bg-slate-100 text-slate-500 rounded">{word}</span>
                                    {/each}
                                </div>
                            </div>
                        {/each}
                        {#if triggers.filter(t => t.is_active).length === 0}
                            <p class="text-[10px] text-slate-400 text-center py-3">No active triggers</p>
                        {/if}
                    </div>

                    {#if flows.filter(f => f.is_active).length > 0}
                        <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                            <h4 class="text-xs font-bold text-slate-600 uppercase mb-3">🔀 Active Flows ({flows.filter(f => f.is_active).length})</h4>
                            {#each flows.filter(f => f.is_active) as flow}
                                <div class="flex items-center gap-3 py-2 border-b border-slate-100 last:border-0">
                                    <span class="text-[10px] text-slate-400 font-mono">#{flow.priority}</span>
                                    <span class="text-xs font-bold text-slate-700 truncate">{flow.name}</span>
                                    <span class="px-1.5 py-0.5 text-[9px] bg-purple-100 text-purple-600 rounded font-bold flex-shrink-0">Flow</span>
                                    <span class="text-[10px] text-slate-400 flex-shrink-0">{(flow.nodes || []).length} nodes</span>
                                    <div class="flex gap-0.5 ml-auto flex-shrink-0">
                                        {#each [...(flow.trigger_words_en || []).slice(0, 2), ...(flow.trigger_words_ar || []).slice(0, 1)] as word}
                                            <span class="px-1.5 py-0.5 text-[9px] bg-slate-100 text-slate-500 rounded">{word}</span>
                                        {/each}
                                    </div>
                                </div>
                            {/each}
                        </div>
                    {/if}
                    
                    <div class="bg-slate-50 border border-slate-200 rounded-2xl p-4">
                        <p class="text-[10px] text-slate-500 leading-relaxed">
                            💡 <b>Tip:</b> Type a message in the phone to test which trigger or flow matches. Bot responses, buttons, media, and flow steps will render exactly as they would appear on a real WhatsApp conversation.
                        </p>
                    </div>
                </div>
            </div>
        {/if}
    </div>
</div>

<style>
    /* Phone Frame - Realistic iPhone-style mockup */
    .phone-frame {
        width: 320px;
        height: 620px;
        background: #ffffff;
        border-radius: 36px;
        border: 3px solid #1a1a2e;
        box-shadow: 
            0 0 0 2px #2d2d44,
            0 20px 60px rgba(0,0,0,0.3),
            inset 0 0 0 1px rgba(255,255,255,0.1);
        display: flex;
        flex-direction: column;
        overflow: hidden;
        position: relative;
    }

    .phone-notch {
        width: 100px;
        height: 22px;
        background: #1a1a2e;
        border-radius: 0 0 16px 16px;
        margin: 0 auto;
        position: relative;
        z-index: 10;
    }
    .phone-notch::after {
        content: '';
        width: 8px;
        height: 8px;
        background: #2d2d44;
        border-radius: 50%;
        position: absolute;
        right: 22px;
        top: 7px;
    }

    /* WhatsApp Header */
    .wa-header {
        background: #075e54;
        padding: 8px 12px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        flex-shrink: 0;
    }

    /* Chat Area */
    .wa-chat-area {
        flex: 1;
        overflow-y: auto;
        position: relative;
        background: #ece5dd;
    }
    .wa-chat-area::-webkit-scrollbar {
        width: 3px;
    }
    .wa-chat-area::-webkit-scrollbar-thumb {
        background: rgba(0,0,0,0.15);
        border-radius: 3px;
    }

    .wa-wallpaper {
        position: absolute;
        inset: 0;
        opacity: 0.05;
        background-image: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23000000' fill-opacity='0.8'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
    }

    /* Chat Bubbles */
    .wa-bubble-user {
        background: #dcf8c6;
        max-width: 80%;
        padding: 6px 10px;
        border-radius: 8px 2px 8px 8px;
        position: relative;
        box-shadow: 0 1px 1px rgba(0,0,0,0.08);
    }
    .wa-bubble-user::after {
        content: '';
        position: absolute;
        top: 0;
        right: -6px;
        border-width: 0 0 8px 8px;
        border-style: solid;
        border-color: transparent transparent transparent #dcf8c6;
    }
    .wa-bubble-user p {
        color: #303030 !important;
    }

    .wa-bubble-bot {
        background: #ffffff;
        max-width: 85%;
        padding: 6px 10px;
        border-radius: 2px 8px 8px 8px;
        position: relative;
        box-shadow: 0 1px 1px rgba(0,0,0,0.08);
    }
    .wa-bubble-bot::after {
        content: '';
        position: absolute;
        top: 0;
        left: -6px;
        border-width: 0 8px 8px 0;
        border-style: solid;
        border-color: transparent #ffffff transparent transparent;
    }

    /* Quick Reply Buttons */
    .wa-quick-reply-btn {
        text-align: center;
        padding: 6px 8px;
        border: 1px solid #25d366;
        border-radius: 8px;
        font-size: 11px;
        font-weight: 600;
        color: #25d366;
        cursor: default;
        background: #f0fdf4;
        transition: all 0.15s;
    }

    /* Input Bar */
    .wa-input-bar {
        background: #f0f0f0;
        padding: 6px 8px;
        display: flex;
        align-items: center;
        gap: 6px;
        flex-shrink: 0;
        border-top: 1px solid #e0e0e0;
    }
    .wa-input-bar > div:first-child {
        flex: 1;
        background: #ffffff;
        border-radius: 20px;
        padding: 6px 10px;
        display: flex;
        align-items: center;
        gap: 6px;
    }
</style>