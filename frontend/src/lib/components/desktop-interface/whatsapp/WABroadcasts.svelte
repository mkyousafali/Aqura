<script lang="ts">
    import { onMount } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface Broadcast {
        id: string;
        name: string;
        template_name: string;
        template_language: string;
        status: string;
        total_recipients: number;
        sent_count: number;
        delivered_count: number;
        read_count: number;
        failed_count: number;
        scheduled_at: string | null;
        sent_at: string | null;
        created_at: string;
    }

    interface Recipient {
        id: string;
        phone: string;
        customer_name: string;
        status: string;
        sent_at: string | null;
    }

    interface WATemplate {
        id: string;
        name: string;
        body_text: string;
        header_type: string;
        header_content: string;
        footer_text: string;
        buttons: any[];
        language: string;
        status: string;
    }

    interface ContactGroup {
        id: string;
        name: string;
        description: string;
    }

    let supabase: any = null;
    let accountId = '';
    let broadcasts: Broadcast[] = [];
    let templates: WATemplate[] = [];
    let contactGroups: ContactGroup[] = [];
    let loading = true;
    let sending = false;
    let activeTab = 'list'; // list, create, details
    let selectedBroadcast: Broadcast | null = null;
    let recipients: Recipient[] = [];

    // Create form
    let broadcastName = '';
    let selectedTemplate: WATemplate | null = null;
    let recipientSource = 'all'; // all, 24hr, group, import
    let selectedGroupId = '';
    let importedPhones: string[] = [];
    let importFileName = '';
    let scheduleType = 'now'; // now, schedule
    let scheduledAt = '';
    let recipientFilter24hr = false;

    // Preview
    let showPreview = true;

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
                await Promise.all([loadBroadcasts(), loadTemplates(), loadContactGroups()]);
            }
        } catch {} finally { loading = false; }
    }

    async function loadBroadcasts() {
        const { data } = await supabase.from('wa_broadcasts').select('*').eq('wa_account_id', accountId).order('created_at', { ascending: false });
        broadcasts = data || [];
    }

    async function loadTemplates() {
        const { data } = await supabase.from('wa_templates').select('*').eq('wa_account_id', accountId).eq('status', 'APPROVED');
        templates = data || [];
    }

    async function loadContactGroups() {
        const { data } = await supabase.from('wa_contact_groups').select('id, name, description').eq('wa_account_id', accountId);
        contactGroups = data || [];
    }

    function startCreateBroadcast() {
        activeTab = 'create';
        broadcastName = '';
        selectedTemplate = null;
        recipientSource = 'all';
        selectedGroupId = '';
        importedPhones = [];
        importFileName = '';
        scheduleType = 'now';
        scheduledAt = '';
    }

    async function viewBroadcastDetails(bc: Broadcast) {
        selectedBroadcast = bc;
        activeTab = 'details';
        const { data } = await supabase.from('wa_broadcast_recipients').select('*').eq('broadcast_id', bc.id).order('sent_at', { ascending: false });
        recipients = data || [];
    }

    function handleFileImport(e: Event) {
        const input = e.target as HTMLInputElement;
        if (!input.files?.length) return;
        const file = input.files[0];
        importFileName = file.name;
        const reader = new FileReader();
        reader.onload = (ev) => {
            const text = ev.target?.result as string;
            const lines = text.split(/[\r\n]+/).filter(l => l.trim());
            const phones: string[] = [];
            for (const line of lines) {
                // Try to extract phone numbers from CSV/Excel data
                const parts = line.split(/[,\t;]+/);
                for (const part of parts) {
                    const cleaned = part.replace(/[^0-9+]/g, '').trim();
                    if (cleaned.length >= 10) phones.push(cleaned);
                }
            }
            importedPhones = [...new Set(phones)];
        };
        reader.readAsText(file);
    }

    async function sendBroadcast() {
        if (!selectedTemplate || !broadcastName.trim() || sending) return;
        sending = true;
        try {
            // Get recipients
            let recipientList: { phone: string; name: string }[] = [];

            if (recipientSource === 'all' || recipientSource === '24hr') {
                const query = supabase.from('wa_conversations').select('customer_phone, customer_name').eq('wa_account_id', accountId).eq('status', 'active');
                const { data } = await query;
                const now = new Date();
                recipientList = (data || []).filter((c: any) => {
                    if (recipientSource === '24hr') {
                        const lastMsg = c.last_message_at ? new Date(c.last_message_at) : null;
                        const hrs = lastMsg ? (now.getTime() - lastMsg.getTime()) / 3600000 : Infinity;
                        return hrs <= 24;
                    }
                    return true;
                }).map((c: any) => ({ phone: c.customer_phone, name: c.customer_name }));
            } else if (recipientSource === 'group' && selectedGroupId) {
                const { data } = await supabase.from('wa_contact_group_members').select('phone, customer_name').eq('group_id', selectedGroupId);
                recipientList = (data || []).map((m: any) => ({ phone: m.phone, name: m.customer_name }));
            } else if (recipientSource === 'import') {
                recipientList = importedPhones.map(p => ({ phone: p, name: '' }));
            }

            if (recipientList.length === 0) {
                alert('No recipients found');
                sending = false;
                return;
            }

            // Create broadcast
            const { data: bc, error: err } = await supabase.from('wa_broadcasts').insert({
                wa_account_id: accountId,
                name: broadcastName,
                template_name: selectedTemplate.name,
                template_language: selectedTemplate.language,
                template_data: selectedTemplate,
                total_recipients: recipientList.length,
                status: scheduleType === 'schedule' ? 'scheduled' : 'sending',
                scheduled_at: scheduleType === 'schedule' ? scheduledAt : null
            }).select().single();
            if (err) throw err;

            // Create recipient records
            const recipientInserts = recipientList.map(r => ({
                broadcast_id: bc.id,
                phone: r.phone,
                customer_name: r.name,
                status: 'pending'
            }));
            await supabase.from('wa_broadcast_recipients').insert(recipientInserts);

            if (scheduleType === 'now') {
                // Send immediately via WhatsApp API
                const { data: accData } = await supabase.from('wa_accounts').select('phone_number_id, access_token').eq('id', accountId).single();
                if (accData) {
                    let sentCount = 0, failedCount = 0;
                    for (const recipient of recipientList) {
                        try {
                            const cleanPhone = recipient.phone.replace(/[\s\-()]/g, '');
                            const phone = cleanPhone.startsWith('+') ? cleanPhone.substring(1) : cleanPhone;

                            await fetch(`https://graph.facebook.com/v22.0/${accData.phone_number_id}/messages`, {
                                method: 'POST',
                                headers: {
                                    'Authorization': `Bearer ${accData.access_token}`,
                                    'Content-Type': 'application/json'
                                },
                                body: JSON.stringify({
                                    messaging_product: 'whatsapp',
                                    to: phone,
                                    type: 'template',
                                    template: {
                                        name: selectedTemplate!.name,
                                        language: { code: selectedTemplate!.language }
                                    }
                                })
                            });
                            sentCount++;
                            await supabase.from('wa_broadcast_recipients').update({ status: 'sent', sent_at: new Date().toISOString() })
                                .eq('broadcast_id', bc.id).eq('phone', recipient.phone);
                        } catch {
                            failedCount++;
                            await supabase.from('wa_broadcast_recipients').update({ status: 'failed' })
                                .eq('broadcast_id', bc.id).eq('phone', recipient.phone);
                        }
                    }
                    await supabase.from('wa_broadcasts').update({
                        status: 'completed',
                        sent_count: sentCount,
                        failed_count: failedCount,
                        sent_at: new Date().toISOString()
                    }).eq('id', bc.id);
                }
            }

            await loadBroadcasts();
            activeTab = 'list';
        } catch (e: any) {
            console.error('Broadcast error:', e);
            alert('Failed to send broadcast: ' + e.message);
        } finally {
            sending = false;
        }
    }

    function getStatusBadge(status: string) {
        const map: Record<string, { bg: string; text: string; label: string }> = {
            draft: { bg: 'bg-slate-100', text: 'text-slate-600', label: '📝 Draft' },
            scheduled: { bg: 'bg-blue-100', text: 'text-blue-600', label: '📅 Scheduled' },
            sending: { bg: 'bg-amber-100', text: 'text-amber-600', label: '⏳ Sending' },
            completed: { bg: 'bg-emerald-100', text: 'text-emerald-600', label: '✅ Completed' },
            failed: { bg: 'bg-red-100', text: 'text-red-600', label: '❌ Failed' },
            cancelled: { bg: 'bg-slate-100', text: 'text-slate-500', label: '🚫 Cancelled' }
        };
        return map[status] || map.draft;
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4">
        <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
                <span class="text-2xl">📣</span>
                <h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappBroadcasts')}</h1>
            </div>
            {#if activeTab !== 'create'}
                <button class="px-6 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700 shadow-lg shadow-emerald-200 transition-all"
                    on:click={startCreateBroadcast}>
                    + New Broadcast
                </button>
            {/if}
        </div>
        <!-- Tabs -->
        {#if activeTab !== 'list'}
            <div class="flex gap-2 mt-3">
                <button class="px-4 py-1.5 text-xs font-bold rounded-lg transition-all
                    {activeTab === 'list' ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
                    on:click={() => activeTab = 'list'}>
                    ← Back to List
                </button>
            </div>
        {/if}
    </div>

    <!-- Content -->
    <div class="flex-1 overflow-hidden">
        {#if loading}
            <div class="flex justify-center items-center h-full">
                <div class="animate-spin w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
            </div>

        {:else if activeTab === 'list'}
            <!-- Broadcast List -->
            <div class="p-6 overflow-y-auto h-full">
                {#if broadcasts.length === 0}
                    <div class="flex flex-col items-center justify-center py-20">
                        <div class="text-5xl mb-4">📣</div>
                        <h3 class="text-lg font-bold text-slate-600">No Broadcasts Yet</h3>
                        <p class="text-sm text-slate-400 mt-1">Create your first broadcast campaign</p>
                        <button class="mt-4 px-6 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl hover:bg-emerald-700"
                            on:click={startCreateBroadcast}>
                            + Create Broadcast
                        </button>
                    </div>
                {:else}
                    <div class="grid gap-4">
                        {#each broadcasts as bc}
                            {@const badge = getStatusBadge(bc.status)}
                            <button class="w-full text-left bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5 hover:shadow-lg transition-all"
                                on:click={() => viewBroadcastDetails(bc)}>
                                <div class="flex items-start justify-between">
                                    <div>
                                        <h3 class="font-bold text-slate-800">{bc.name}</h3>
                                        <p class="text-xs text-slate-500 mt-1">📝 Template: <b>{bc.template_name}</b> ({bc.template_language?.toUpperCase()})</p>
                                    </div>
                                    <span class="px-3 py-1 text-xs font-bold rounded-full {badge.bg} {badge.text}">{badge.label}</span>
                                </div>
                                <div class="flex items-center gap-6 mt-4">
                                    <div class="text-center">
                                        <p class="text-lg font-black text-slate-700">{bc.total_recipients}</p>
                                        <p class="text-[10px] text-slate-400 uppercase font-bold">Recipients</p>
                                    </div>
                                    <div class="text-center">
                                        <p class="text-lg font-black text-emerald-600">{bc.sent_count || 0}</p>
                                        <p class="text-[10px] text-slate-400 uppercase font-bold">Sent</p>
                                    </div>
                                    <div class="text-center">
                                        <p class="text-lg font-black text-blue-600">{bc.delivered_count || 0}</p>
                                        <p class="text-[10px] text-slate-400 uppercase font-bold">Delivered</p>
                                    </div>
                                    <div class="text-center">
                                        <p class="text-lg font-black text-purple-600">{bc.read_count || 0}</p>
                                        <p class="text-[10px] text-slate-400 uppercase font-bold">Read</p>
                                    </div>
                                    {#if bc.failed_count}
                                        <div class="text-center">
                                            <p class="text-lg font-black text-red-600">{bc.failed_count}</p>
                                            <p class="text-[10px] text-slate-400 uppercase font-bold">Failed</p>
                                        </div>
                                    {/if}
                                    <div class="ml-auto text-xs text-slate-400">
                                        {bc.sent_at ? new Date(bc.sent_at).toLocaleDateString() : bc.scheduled_at ? `📅 ${new Date(bc.scheduled_at).toLocaleDateString()}` : new Date(bc.created_at).toLocaleDateString()}
                                    </div>
                                </div>
                            </button>
                        {/each}
                    </div>
                {/if}
            </div>

        {:else if activeTab === 'create'}
            <!-- Create Broadcast -->
            <div class="flex h-full overflow-hidden">
                <!-- Form -->
                <div class="flex-1 overflow-y-auto p-6 space-y-6">
                    <!-- Broadcast Name -->
                    <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                        <label class="block text-xs font-bold text-slate-600 uppercase mb-2">Broadcast Name</label>
                        <input type="text" bind:value={broadcastName} placeholder="e.g., Ramadan Offer 2025"
                            class="w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                    </div>

                    <!-- Template Selection -->
                    <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                        <label class="block text-xs font-bold text-slate-600 uppercase mb-3">Select Template</label>
                        {#if templates.length === 0}
                            <p class="text-xs text-slate-400">No approved templates available</p>
                        {:else}
                            <div class="grid grid-cols-2 gap-3">
                                {#each templates as tmpl}
                                    <button class="text-left p-3 rounded-xl border-2 transition-all
                                        {selectedTemplate?.id === tmpl.id ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 hover:border-emerald-300'}"
                                        on:click={() => selectedTemplate = tmpl}>
                                        <p class="text-xs font-bold text-slate-700">{tmpl.name}</p>
                                        <p class="text-[10px] text-slate-500 mt-1 line-clamp-2">{tmpl.body_text}</p>
                                        <span class="text-[9px] text-blue-500 mt-1">{tmpl.language === 'ar' ? '🇸🇦' : '🇺🇸'} {tmpl.language?.toUpperCase()}</span>
                                    </button>
                                {/each}
                            </div>
                        {/if}
                    </div>

                    <!-- Recipient Selection -->
                    <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                        <label class="block text-xs font-bold text-slate-600 uppercase mb-3">Recipients</label>
                        <div class="grid grid-cols-2 gap-3">
                            {#each [
                                { id: 'all', label: '🌐 All Contacts', desc: 'Send to all WhatsApp contacts' },
                                { id: '24hr', label: '🟢 Inside 24hr', desc: 'Only contacts within 24hr window' },
                                { id: 'group', label: '👥 Contact Group', desc: 'Select a specific group' },
                                { id: 'import', label: '📂 Import File', desc: 'Import from Excel/CSV' }
                            ] as src}
                                <button class="text-left p-3 rounded-xl border-2 transition-all
                                    {recipientSource === src.id ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 hover:border-emerald-300'}"
                                    on:click={() => recipientSource = src.id}>
                                    <p class="text-sm font-bold text-slate-700">{src.label}</p>
                                    <p class="text-[10px] text-slate-500">{src.desc}</p>
                                </button>
                            {/each}
                        </div>

                        {#if recipientSource === 'group'}
                            <div class="mt-3">
                                <select bind:value={selectedGroupId}
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm">
                                    <option value="">Select group...</option>
                                    {#each contactGroups as grp}
                                        <option value={grp.id}>{grp.name}</option>
                                    {/each}
                                </select>
                            </div>
                        {/if}

                        {#if recipientSource === 'import'}
                            <div class="mt-3">
                                <label class="flex items-center gap-3 p-4 border-2 border-dashed border-slate-300 rounded-xl cursor-pointer hover:border-emerald-400 transition-colors">
                                    <span class="text-2xl">📎</span>
                                    <div>
                                        <p class="text-xs font-bold text-slate-600">{importFileName || 'Click to upload CSV/Excel'}</p>
                                        {#if importedPhones.length > 0}
                                            <p class="text-[10px] text-emerald-600 font-bold">{importedPhones.length} phone numbers found</p>
                                        {:else}
                                            <p class="text-[10px] text-slate-400">Supports CSV with phone numbers</p>
                                        {/if}
                                    </div>
                                    <input type="file" accept=".csv,.txt,.xlsx" on:change={handleFileImport} class="hidden" />
                                </label>
                            </div>
                        {/if}
                    </div>

                    <!-- Schedule -->
                    <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                        <label class="block text-xs font-bold text-slate-600 uppercase mb-3">When to Send</label>
                        <div class="flex gap-3">
                            <button class="flex-1 p-3 rounded-xl border-2 transition-all
                                {scheduleType === 'now' ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 hover:border-emerald-300'}"
                                on:click={() => scheduleType = 'now'}>
                                <p class="text-sm font-bold text-slate-700">🚀 Send Now</p>
                                <p class="text-[10px] text-slate-500">Send immediately</p>
                            </button>
                            <button class="flex-1 p-3 rounded-xl border-2 transition-all
                                {scheduleType === 'schedule' ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 hover:border-emerald-300'}"
                                on:click={() => scheduleType = 'schedule'}>
                                <p class="text-sm font-bold text-slate-700">📅 Schedule</p>
                                <p class="text-[10px] text-slate-500">Pick date & time</p>
                            </button>
                        </div>
                        {#if scheduleType === 'schedule'}
                            <input type="datetime-local" bind:value={scheduledAt}
                                class="mt-3 w-full px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500" />
                        {/if}
                    </div>

                    <!-- Send Button -->
                    <button class="w-full py-3.5 bg-emerald-600 text-white font-black text-sm rounded-2xl hover:bg-emerald-700 shadow-lg shadow-emerald-200 transition-all disabled:opacity-50"
                        on:click={sendBroadcast}
                        disabled={sending || !broadcastName.trim() || !selectedTemplate}>
                        {sending ? '⏳ Sending...' : scheduleType === 'schedule' ? '📅 Schedule Broadcast' : '🚀 Send Broadcast'}
                    </button>
                </div>

                <!-- Live Preview -->
                {#if showPreview && selectedTemplate}
                    <div class="w-80 border-l border-slate-200 bg-slate-50 p-6 overflow-y-auto">
                        <h3 class="text-xs font-bold text-slate-600 uppercase mb-4">📱 Message Preview</h3>
                        <!-- Phone Frame -->
                        <div class="bg-[#1a1a2e] rounded-[2rem] p-3 shadow-2xl mx-auto w-64">
                            <div class="bg-[#ECE5DD] rounded-[1.5rem] overflow-hidden">
                                <!-- Header -->
                                <div class="bg-emerald-700 text-white px-4 py-3 flex items-center gap-2">
                                    <span class="text-xs">◀</span>
                                    <div class="w-7 h-7 bg-white/20 rounded-full flex items-center justify-center text-[10px]">📣</div>
                                    <div>
                                        <p class="text-[10px] font-bold">Broadcast</p>
                                        <p class="text-[8px] text-emerald-200">Template Message</p>
                                    </div>
                                </div>
                                <!-- Message -->
                                <div class="p-3 min-h-[200px]">
                                    <div class="bg-white rounded-xl rounded-tl-none px-3 py-2 shadow-sm max-w-[200px]">
                                        {#if selectedTemplate.header_type === 'text' && selectedTemplate.header_content}
                                            <p class="text-[10px] font-bold text-slate-800 mb-1">{selectedTemplate.header_content}</p>
                                        {:else if selectedTemplate.header_type === 'image'}
                                            <div class="bg-slate-200 rounded-lg h-20 flex items-center justify-center text-lg mb-1">🖼️</div>
                                        {/if}
                                        <p class="text-[10px] text-slate-700 whitespace-pre-wrap">{selectedTemplate.body_text || 'Template body text'}</p>
                                        {#if selectedTemplate.footer_text}
                                            <p class="text-[9px] text-slate-400 mt-1 italic">{selectedTemplate.footer_text}</p>
                                        {/if}
                                        {#if selectedTemplate.buttons?.length}
                                            <div class="mt-2 border-t border-slate-100 pt-1.5 space-y-1">
                                                {#each selectedTemplate.buttons as btn}
                                                    <div class="text-center py-1 text-[9px] text-blue-600 font-bold border border-blue-100 rounded-md bg-blue-50/50">
                                                        {btn.type === 'PHONE_NUMBER' ? '📞' : btn.type === 'URL' ? '🔗' : '↩️'} {btn.text}
                                                    </div>
                                                {/each}
                                            </div>
                                        {/if}
                                        <p class="text-[8px] text-slate-400 text-right mt-1">12:00</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                {/if}
            </div>

        {:else if activeTab === 'details' && selectedBroadcast}
            <!-- Broadcast Details -->
            <div class="p-6 overflow-y-auto h-full">
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-6 mb-6">
                    <div class="flex items-start justify-between mb-4">
                        <div>
                            <h2 class="text-lg font-black text-slate-800">{selectedBroadcast.name}</h2>
                            <p class="text-xs text-slate-500 mt-1">📝 Template: <b>{selectedBroadcast.template_name}</b></p>
                        </div>
                        <span class="px-3 py-1 text-xs font-bold rounded-full {getStatusBadge(selectedBroadcast.status).bg} {getStatusBadge(selectedBroadcast.status).text}">{getStatusBadge(selectedBroadcast.status).label}</span>
                    </div>
                    <div class="grid grid-cols-5 gap-4">
                        <div class="bg-slate-50 rounded-xl p-3 text-center">
                            <p class="text-xl font-black text-slate-700">{selectedBroadcast.total_recipients}</p>
                            <p class="text-[10px] text-slate-400 uppercase font-bold">Total</p>
                        </div>
                        <div class="bg-emerald-50 rounded-xl p-3 text-center">
                            <p class="text-xl font-black text-emerald-600">{selectedBroadcast.sent_count || 0}</p>
                            <p class="text-[10px] text-emerald-500 uppercase font-bold">Sent</p>
                        </div>
                        <div class="bg-blue-50 rounded-xl p-3 text-center">
                            <p class="text-xl font-black text-blue-600">{selectedBroadcast.delivered_count || 0}</p>
                            <p class="text-[10px] text-blue-500 uppercase font-bold">Delivered</p>
                        </div>
                        <div class="bg-purple-50 rounded-xl p-3 text-center">
                            <p class="text-xl font-black text-purple-600">{selectedBroadcast.read_count || 0}</p>
                            <p class="text-[10px] text-purple-500 uppercase font-bold">Read</p>
                        </div>
                        <div class="bg-red-50 rounded-xl p-3 text-center">
                            <p class="text-xl font-black text-red-600">{selectedBroadcast.failed_count || 0}</p>
                            <p class="text-[10px] text-red-500 uppercase font-bold">Failed</p>
                        </div>
                    </div>
                </div>

                <!-- Recipients Table -->
                <div class="bg-white/60 backdrop-blur-xl border border-white/40 rounded-2xl p-5">
                    <h3 class="text-xs font-bold text-slate-600 uppercase mb-3">Recipients ({recipients.length})</h3>
                    <div class="overflow-x-auto">
                        <table class="w-full text-sm">
                            <thead>
                                <tr class="text-left text-xs text-slate-400 uppercase">
                                    <th class="py-2 px-3">Phone</th>
                                    <th class="py-2 px-3">Name</th>
                                    <th class="py-2 px-3">Status</th>
                                    <th class="py-2 px-3">Sent At</th>
                                </tr>
                            </thead>
                            <tbody>
                                {#each recipients as r}
                                    <tr class="border-t border-slate-100 hover:bg-slate-50">
                                        <td class="py-2 px-3 font-mono text-xs">{r.phone}</td>
                                        <td class="py-2 px-3 text-xs">{r.customer_name || '-'}</td>
                                        <td class="py-2 px-3">
                                            <span class="px-2 py-0.5 text-[10px] font-bold rounded-full
                                                {r.status === 'sent' ? 'bg-emerald-100 text-emerald-600' :
                                                 r.status === 'delivered' ? 'bg-blue-100 text-blue-600' :
                                                 r.status === 'read' ? 'bg-purple-100 text-purple-600' :
                                                 r.status === 'failed' ? 'bg-red-100 text-red-600' :
                                                 'bg-slate-100 text-slate-500'}">
                                                {r.status}
                                            </span>
                                        </td>
                                        <td class="py-2 px-3 text-xs text-slate-400">{r.sent_at ? new Date(r.sent_at).toLocaleString() : '-'}</td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        {/if}
    </div>
</div>
