<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

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
    let activeTab = 'list'; // list, create, test
    let editingTrigger: Partial<Trigger> | null = null;
    let testInput = '';
    let testResult: string | null = null;
    let testMatchedTrigger: Trigger | null = null;

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
                await Promise.all([loadTriggers(), loadBotStatus(), loadTemplates()]);
            }
        } catch {} finally { loading = false; }
    }

    async function loadTriggers() {
        const { data } = await supabase.from('wa_auto_reply_triggers').select('*').eq('wa_account_id', accountId).order('priority', { ascending: true });
        triggers = data || [];
    }

    async function loadBotStatus() {
        const { data } = await supabase.from('wa_settings').select('value').eq('wa_account_id', accountId).eq('key', 'auto_reply_enabled').single();
        botEnabled = data?.value === 'true';
    }

    async function loadTemplates() {
        const { data } = await supabase.from('wa_templates').select('id, name, language').eq('wa_account_id', accountId).eq('status', 'APPROVED');
        templates = data || [];
    }

    async function toggleBotEnabled() {
        botEnabled = !botEnabled;
        await supabase.from('wa_settings').upsert({
            wa_account_id: accountId,
            key: 'auto_reply_enabled',
            value: botEnabled ? 'true' : 'false'
        }, { onConflict: 'wa_account_id,key' });
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
                trigger_words: editingTrigger.trigger_words,
                trigger_words_ar: editingTrigger.trigger_words_ar,
                match_type: editingTrigger.match_type,
                response_type: editingTrigger.response_type,
                response_content: editingTrigger.response_content,
                response_media_url: editingTrigger.response_media_url,
                response_template_name: editingTrigger.response_template_name,
                response_buttons: editingTrigger.response_buttons,
                follow_up_delay_seconds: editingTrigger.follow_up_delay_seconds || 0,
                follow_up_content: editingTrigger.follow_up_content,
                priority: editingTrigger.priority,
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
        if (!testInput.trim()) { testResult = null; testMatchedTrigger = null; return; }
        const input = testInput.toLowerCase().trim();
        
        for (const trigger of triggers.filter(t => t.is_active)) {
            const allWords = [...(trigger.trigger_words || []), ...(trigger.trigger_words_ar || [])];
            for (const word of allWords) {
                const w = word.toLowerCase();
                let match = false;
                if (trigger.match_type === 'exact') match = input === w;
                else if (trigger.match_type === 'contains') match = input.includes(w);
                else if (trigger.match_type === 'starts_with') match = input.startsWith(w);
                else if (trigger.match_type === 'regex') {
                    try { match = new RegExp(w, 'i').test(input); } catch {}
                }
                if (match) {
                    testMatchedTrigger = trigger;
                    testResult = trigger.response_content || `📝 Template: ${trigger.response_template_name}`;
                    return;
                }
            }
        }
        testMatchedTrigger = null;
        testResult = '❌ No matching trigger found';
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

        {:else if activeTab === 'test'}
            <!-- Test Area -->
            <div class="max-w-2xl mx-auto space-y-6">
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6">
                    <h3 class="text-sm font-bold text-slate-700 mb-4">🧪 Test Auto-Reply Bot</h3>
                    <p class="text-xs text-slate-500 mb-4">Type a message to see which trigger matches and what response would be sent.</p>
                    
                    <div class="flex gap-3">
                        <input type="text" bind:value={testInput} placeholder="Type a test message..."
                            class="flex-1 px-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                            on:keydown={(e) => { if(e.key === 'Enter') testAutoReply(); }} />
                        <button class="px-6 py-3 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700"
                            on:click={testAutoReply}>
                            Test →
                        </button>
                    </div>

                    {#if testResult !== null}
                        <div class="mt-4 p-4 rounded-xl {testMatchedTrigger ? 'bg-emerald-50 border border-emerald-200' : 'bg-red-50 border border-red-200'}">
                            {#if testMatchedTrigger}
                                <p class="text-xs font-bold text-emerald-700 mb-1">✅ Matched: "{testMatchedTrigger.name}" (Priority #{testMatchedTrigger.priority})</p>
                                <p class="text-xs text-slate-600">Match type: <b>{testMatchedTrigger.match_type}</b></p>
                                <div class="mt-3 bg-white rounded-xl p-3">
                                    <p class="text-xs text-slate-500 font-bold mb-1">Response ({testMatchedTrigger.response_type}):</p>
                                    <p class="text-sm text-slate-700">{testResult}</p>
                                    {#if testMatchedTrigger.response_buttons?.length}
                                        <div class="flex flex-wrap gap-1 mt-2">
                                            {#each testMatchedTrigger.response_buttons as btn}
                                                <span class="px-3 py-1 bg-blue-100 text-blue-600 text-xs font-bold rounded-full">
                                                    {btn.type === 'phone' ? '📞' : btn.type === 'url' ? '🔗' : '↩️'} {btn.title}
                                                </span>
                                            {/each}
                                        </div>
                                    {/if}
                                    {#if testMatchedTrigger.follow_up_content}
                                        <p class="text-[10px] text-amber-600 mt-2">⏱️ Follow-up after {testMatchedTrigger.follow_up_delay_seconds}s: "{testMatchedTrigger.follow_up_content}"</p>
                                    {/if}
                                </div>
                            {:else}
                                <p class="text-xs font-bold text-red-600">{testResult}</p>
                            {/if}
                        </div>
                    {/if}
                </div>

                <!-- Active Triggers Summary -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <h4 class="text-xs font-bold text-slate-600 uppercase mb-3">Active Triggers ({triggers.filter(t => t.is_active).length})</h4>
                    {#each triggers.filter(t => t.is_active) as trigger}
                        <div class="flex items-center gap-3 py-2 border-b border-slate-100 last:border-0">
                            <span class="text-[10px] text-slate-400 font-mono">#{trigger.priority}</span>
                            <span class="text-xs font-bold text-slate-700">{trigger.name}</span>
                            <div class="flex gap-0.5 ml-auto">
                                {#each [...(trigger.trigger_words || []).slice(0, 3), ...(trigger.trigger_words_ar || []).slice(0, 2)] as word}
                                    <span class="px-1.5 py-0.5 text-[9px] bg-slate-100 text-slate-500 rounded">{word}</span>
                                {/each}
                            </div>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}
    </div>
</div>
