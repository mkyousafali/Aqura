<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { openWindow } from '$lib/utils/windowManagerUtils';
    import WALiveChat from './WALiveChat.svelte';

    interface Contact {
        id: string;
        name: string;
        whatsapp_number: string;
        registration_status: string;
        whatsapp_available: boolean | null;
        last_message_at: string | null;
        last_interaction_at: string | null;
        approved_at: string | null;
        last_login_at: string | null;
        unread_count: number;
        is_inside_24hr: boolean;
        conversation_id: string | null;
        created_at: string;
    }

    interface MessageHistory {
        id: string;
        direction: string;
        message_type: string;
        content: string;
        media_url: string | null;
        status: string;
        sent_by: string;
        created_at: string;
        template_name?: string;
    }

    let supabase: any = null;
    let contacts: Contact[] = [];
    let filteredContacts: Contact[] = [];
    let loading = true;
    let error = '';
    let searchQuery = '';
    let statusFilter = 'all'; // all, inside_24hr, outside_24hr, unread
    let selectedContact: Contact | null = null;
    let messageHistory: MessageHistory[] = [];
    let loadingHistory = false;
    let realtimeChannel: any = null;
    let realtimeConvChannel: any = null;
    let realtimeCodeChannel: any = null;
    let realtimeMsgChannel: any = null;

    // Pagination
    const PAGE_SIZE = 100;
    let currentOffset = 0;
    let totalCount = 0;
    let loadingMore = false;
    let searchTimeout: any;
    let realtimeDebounce: any;

    // Import state
    let importing = false;
    let importMessage = '';
    let fileInput: HTMLInputElement;

    /** Debounced refresh — coalesces rapid realtime events into a single reload */
    function scheduleRefresh() {
        if (realtimeDebounce) clearTimeout(realtimeDebounce);
        realtimeDebounce = setTimeout(() => loadContacts(), 500);
    }

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadContacts();

        // Realtime: customers table changes
        realtimeChannel = supabase
            .channel('wa-contacts-customers')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'customers' }, () => {
                scheduleRefresh();
            })
            .subscribe();

        // Realtime: wa_conversations changes (unread count, last message)
        realtimeConvChannel = supabase
            .channel('wa-contacts-conversations')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'wa_conversations' }, () => {
                scheduleRefresh();
            })
            .subscribe();

        // Realtime: access code history changes (registration, forgot code)
        realtimeCodeChannel = supabase
            .channel('wa-contacts-codes')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'customer_access_code_history' }, () => {
                scheduleRefresh();
            })
            .subscribe();

        // Realtime: wa_messages changes (new messages sent/received)
        realtimeMsgChannel = supabase
            .channel('wa-contacts-messages')
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'wa_messages' }, () => {
                scheduleRefresh();
            })
            .subscribe();
    });

    onDestroy(() => {
        if (realtimeChannel) supabase?.removeChannel(realtimeChannel);
        if (realtimeConvChannel) supabase?.removeChannel(realtimeConvChannel);
        if (realtimeCodeChannel) supabase?.removeChannel(realtimeCodeChannel);
        if (realtimeMsgChannel) supabase?.removeChannel(realtimeMsgChannel);
        if (realtimeDebounce) clearTimeout(realtimeDebounce);
    });

    async function loadContacts(append = false) {
        try {
            if (!append) {
                currentOffset = 0;
                contacts = [];
            }

            const { data, error: err } = await supabase.rpc('get_wa_contacts', {
                p_limit: PAGE_SIZE,
                p_offset: currentOffset,
                p_search: searchQuery.trim() || null
            });

            if (err) throw err;

            const mapped = (data || []).map((c: any) => ({
                id: c.id,
                name: c.name || 'Unknown',
                whatsapp_number: c.whatsapp_number,
                registration_status: c.registration_status,
                whatsapp_available: c.whatsapp_available,
                last_message_at: c.last_message_at || null,
                last_interaction_at: c.last_interaction_at || null,
                approved_at: c.approved_at || null,
                last_login_at: c.last_login_at || null,
                unread_count: c.unread_count || 0,
                is_inside_24hr: c.is_inside_24hr || false,
                conversation_id: c.conversation_id || null,
                created_at: c.created_at
            }));

            if (data?.length > 0) {
                totalCount = Number(data[0].total_count) || 0;
            } else if (!append) {
                totalCount = 0;
            }

            if (append) {
                contacts = [...contacts, ...mapped];
            } else {
                contacts = mapped;
            }

            applyFilters();
        } catch (e: any) {
            error = e.message;
        } finally {
            loading = false;
        }
    }

    function applyFilters() {
        let result = [...contacts];

        // Status filter (search is done server-side)
        if (statusFilter === 'inside_24hr') {
            result = result.filter(c => c.is_inside_24hr);
        } else if (statusFilter === 'outside_24hr') {
            result = result.filter(c => !c.is_inside_24hr);
        } else if (statusFilter === 'unread') {
            result = result.filter(c => c.unread_count > 0);
        }

        filteredContacts = result;
    }

    // Debounced server-side search
    function handleSearchInput() {
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
            loading = true;
            loadContacts();
        }, 400);
    }

    async function loadMore() {
        loadingMore = true;
        currentOffset += PAGE_SIZE;
        await loadContacts(true);
        loadingMore = false;
    }

    $: statusFilter, applyFilters();

    function openLiveChat(contact: Contact) {
        const windowId = `wa-live-chat-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
        const label = contact.name || contact.whatsapp_number;
        openWindow({
            id: windowId,
            title: `💬 Chat — ${label}`,
            component: WALiveChat,
            componentName: 'WALiveChat',
            props: { initialPhone: contact.whatsapp_number },
            icon: '💬',
            size: { width: 1400, height: 800 },
            position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) },
            resizable: true, minimizable: true, maximizable: true, closable: true, popOutEnabled: true
        });
    }

    async function viewHistory(contact: Contact) {
        selectedContact = contact;
        loadingHistory = true;
        messageHistory = [];
        try {
            if (contact.conversation_id) {
                const { data } = await supabase
                    .from('wa_messages')
                    .select('id, direction, message_type, content, media_url, status, sent_by, created_at')
                    .eq('conversation_id', contact.conversation_id)
                    .order('created_at', { ascending: true })
                    .limit(100);
                messageHistory = data || [];
            }
        } catch (e: any) {
            error = e.message;
        } finally {
            loadingHistory = false;
        }
    }

    function closeHistory() {
        selectedContact = null;
        messageHistory = [];
    }

    function formatTime(dateStr: string | null) {
        if (!dateStr) return '—';
        const d = new Date(dateStr);
        const now = new Date();
        const diffMs = now.getTime() - d.getTime();
        const diffMins = Math.floor(diffMs / 60000);
        const diffHrs = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHrs < 24) return `${diffHrs}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;
        return d.toLocaleDateString();
    }

    function formatMessageTime(dateStr: string) {
        const d = new Date(dateStr);
        return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + ' · ' + d.toLocaleDateString();
    }

    function getStatusIcon(status: string) {
        switch (status) {
            case 'sent': return '✓';
            case 'delivered': return '✓✓';
            case 'read': return '✓✓';
            case 'failed': return '✕';
            default: return '•';
        }
    }

    function downloadTemplate() {
        const csvContent = 'Phone Number\n966501234567\n966559876543';
        const BOM = '\uFEFF';
        const blob = new Blob([BOM + csvContent], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'contacts_template.csv';
        a.click();
        URL.revokeObjectURL(url);
    }

    function triggerFileInput() {
        fileInput?.click();
    }

    async function handleFileImport(event: Event) {
        const input = event.target as HTMLInputElement;
        const file = input.files?.[0];
        if (!file) return;

        importing = true;
        importMessage = '';

        try {
            const text = await file.text();
            const lines = text.split(/\r?\n/).filter(l => l.trim());
            if (lines.length < 2) throw new Error('File is empty or has no data rows');

            // Parse header — expect single "Phone Number" column
            const header = lines[0].split(',').map(h => h.trim().toLowerCase().replace(/['"]/g, ''));
            const phoneIdx = header.findIndex(h => h.includes('phone') || h === 'whatsapp_number' || h === 'number' || h === 'رقم' || h === 'الجوال' || h === 'whatsapp');

            // If no matching header, treat first column as phone (or entire file as phone list)
            const useIdx = phoneIdx >= 0 ? phoneIdx : 0;
            const startRow = phoneIdx >= 0 ? 1 : (isNaN(Number(lines[0].trim().replace(/[\s\-\+,'"]/g, ''))) ? 1 : 0);

            const rows: { whatsapp_number: string }[] = [];
            for (let i = startRow; i < lines.length; i++) {
                const cols = lines[i].split(',').map(c => c.trim().replace(/['"]/g, ''));
                let phone = cols[useIdx] || '';

                // Clean phone: remove spaces, dashes, plus
                phone = phone.replace(/[\s\-\+]/g, '');
                if (!phone) continue;

                // Ensure starts with country code
                if (phone.startsWith('05')) phone = '966' + phone.substring(1);
                if (phone.startsWith('5') && phone.length === 9) phone = '966' + phone;

                rows.push({ whatsapp_number: phone });
            }

            // Deduplicate within the file
            const uniquePhones = [...new Set(rows.map(r => r.whatsapp_number))];
            if (uniquePhones.length === 0) throw new Error('No valid rows found');

            // Batch upsert — 5000 at a time (skip duplicates via onConflict)
            const BATCH_SIZE = 5000;
            let inserted = 0;
            let skipped = 0;
            const totalBatches = Math.ceil(uniquePhones.length / BATCH_SIZE);

            for (let b = 0; b < totalBatches; b++) {
                const batch = uniquePhones.slice(b * BATCH_SIZE, (b + 1) * BATCH_SIZE);
                const records = batch.map(phone => ({
                    whatsapp_number: phone,
                    registration_status: 'pre_registered'
                }));

                const { data, error: upsertErr } = await supabase
                    .from('customers')
                    .upsert(records, {
                        onConflict: 'whatsapp_number',
                        ignoreDuplicates: true
                    })
                    .select('id');

                if (upsertErr) {
                    console.error(`Batch ${b + 1} error:`, upsertErr);
                    skipped += batch.length;
                } else {
                    inserted += data?.length || 0;
                    skipped += batch.length - (data?.length || 0);
                }

                // Update progress
                importMessage = `⏳ Processing batch ${b + 1}/${totalBatches}... (${inserted} inserted)`;
            }

            importMessage = `✅ Imported ${inserted} new contacts, ${skipped} skipped (duplicates). Total: ${uniquePhones.length}`;
            await loadContacts();
        } catch (e: any) {
            importMessage = `❌ ${e.message}`;
        } finally {
            importing = false;
            input.value = '';
            setTimeout(() => importMessage = '', 8000);
        }
    }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-3">
            <span class="text-2xl">👥</span>
            <div>
                <h2 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappContacts')}</h2>
                <p class="text-xs text-slate-500">{contacts.length} / {totalCount} contacts</p>
            </div>
        </div>
        <div class="flex items-center gap-3">
            <!-- Import/Download buttons -->
            <input type="file" accept=".csv,.xlsx,.xls" bind:this={fileInput} on:change={handleFileImport} class="hidden" />
            <button class="px-3 py-2 bg-slate-100 text-slate-600 text-xs font-bold rounded-xl hover:bg-slate-200 transition-all border border-slate-200 flex items-center gap-1.5"
                on:click={downloadTemplate}>
                📥 Template
            </button>
            <button class="px-3 py-2 bg-emerald-100 text-emerald-700 text-xs font-bold rounded-xl hover:bg-emerald-200 transition-all border border-emerald-200 flex items-center gap-1.5 disabled:opacity-50"
                on:click={triggerFileInput} disabled={importing}>
                {#if importing}
                    <span class="animate-spin">⏳</span> Importing...
                {:else}
                    📤 Import CSV
                {/if}
            </button>

            <!-- Status Filter -->
            <div class="flex gap-1 bg-slate-100 p-1 rounded-xl">
                {#each [
                    { id: 'all', label: 'All', icon: '📋' },
                    { id: 'inside_24hr', label: '24hr', icon: '🟢' },
                    { id: 'outside_24hr', label: 'Outside', icon: '🔴' },
                    { id: 'unread', label: 'Unread', icon: '🔵' }
                ] as f}
                    <button
                        class="px-3 py-1.5 text-[10px] font-bold uppercase rounded-lg transition-all
                        {statusFilter === f.id ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-500 hover:bg-white'}"
                        on:click={() => statusFilter = f.id}
                    >
                        {f.icon} {f.label}
                    </button>
                {/each}
            </div>
            <!-- Search -->
            <input type="text" bind:value={searchQuery} on:input={handleSearchInput} placeholder="Search name or number..."
                class="px-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm w-64 focus:outline-none focus:ring-2 focus:ring-emerald-500" />
        </div>
    </div>

    <!-- Import Status -->
    {#if importMessage}
        <div class="px-6 py-2 text-sm font-bold text-center {importMessage.startsWith('✅') ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'}">
            {importMessage}
        </div>
    {/if}

    <!-- Main Content -->
    <div class="flex-1 flex relative overflow-hidden">
        <!-- Decorative -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/10 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse pointer-events-none"></div>

        <!-- Contact List -->
        <div class="flex-1 overflow-y-auto p-6 {selectedContact ? 'w-1/2' : 'w-full'} transition-all">
            {#if loading}
                <div class="flex items-center justify-center h-64">
                    <div class="text-center">
                        <div class="animate-spin inline-block">
                            <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                        </div>
                        <p class="mt-4 text-slate-600 font-semibold">{$t('common.loading')}</p>
                    </div>
                </div>
            {:else if error}
                <div class="bg-red-50 border border-red-200 rounded-2xl p-4 text-center">
                    <p class="text-red-700 font-semibold text-sm">{error}</p>
                </div>
            {:else if filteredContacts.length === 0}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-dashed border-2 border-slate-200 p-12 text-center">
                    <div class="text-5xl mb-4">📭</div>
                    <p class="text-slate-600 font-semibold">{searchQuery ? 'No contacts match your search' : 'No contacts found'}</p>
                </div>
            {:else}
                <div class="bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.06)] overflow-hidden">
                    <table class="w-full">
                        <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                            <tr>
                                <th class="px-3 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider">24hr</th>
                                <th class="px-3 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider">Name</th>
                                <th class="px-3 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider">Number</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Reg.</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Registered</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Approved</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Last Activity</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Unread</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Action</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-100">
                            {#each filteredContacts as contact, index}
                                <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {selectedContact?.id === contact.id ? 'bg-emerald-50/50' : ''}">
                                    <td class="px-3 py-2.5">
                                        <span class="text-base">{contact.is_inside_24hr ? '🟢' : '🔴'}</span>
                                    </td>
                                    <td class="px-3 py-2.5">
                                        <span class="font-bold text-xs text-slate-800">{contact.name || '—'}</span>
                                    </td>
                                    <td class="px-3 py-2.5 text-xs text-slate-600 font-mono">{contact.whatsapp_number}</td>
                                    <td class="px-3 py-2.5 text-center">
                                        {#if contact.registration_status === 'approved'}
                                            <span class="inline-flex items-center px-1.5 py-0.5 bg-emerald-100 text-emerald-700 text-[9px] font-bold rounded-full">✓ Approved</span>
                                        {:else if contact.registration_status === 'pre_registered'}
                                            <span class="inline-flex items-center px-1.5 py-0.5 bg-amber-100 text-amber-700 text-[9px] font-bold rounded-full">Pre-Reg</span>
                                        {:else if contact.registration_status === 'pending'}
                                            <span class="inline-flex items-center px-1.5 py-0.5 bg-blue-100 text-blue-700 text-[9px] font-bold rounded-full">Pending</span>
                                        {:else}
                                            <span class="inline-flex items-center px-1.5 py-0.5 bg-slate-100 text-slate-500 text-[9px] font-bold rounded-full">{contact.registration_status}</span>
                                        {/if}
                                    </td>
                                    <td class="px-3 py-2.5 text-center text-[10px] text-slate-500">{formatTime(contact.created_at)}</td>
                                    <td class="px-3 py-2.5 text-center text-[10px] text-slate-500">{formatTime(contact.approved_at)}</td>
                                    <td class="px-3 py-2.5 text-center text-[10px] text-slate-500">{formatTime(contact.last_interaction_at)}</td>
                                    <td class="px-4 py-3 text-center">
                                        {#if contact.unread_count > 0}
                                            <span class="inline-flex items-center justify-center w-6 h-6 bg-emerald-500 text-white text-[10px] font-bold rounded-full">
                                                {contact.unread_count}
                                            </span>
                                        {:else}
                                            <span class="text-slate-300">—</span>
                                        {/if}
                                    </td>
                                    <td class="px-4 py-3 text-center space-x-1">
                                        <button class="px-2.5 py-1.5 bg-blue-50 text-blue-700 text-xs font-bold rounded-lg hover:bg-blue-100 transition-all border border-blue-200"
                                            on:click={() => openLiveChat(contact)}>
                                            💬 Chat
                                        </button>
                                        <button class="px-2.5 py-1.5 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-100 transition-all border border-emerald-200"
                                            on:click={() => viewHistory(contact)}>
                                            📋 History
                                        </button>
                                    </td>
                                </tr>
                            {/each}
                        </tbody>
                    </table>
                </div>
                {#if contacts.length < totalCount}
                    <div class="flex justify-center py-4">
                        <button class="px-6 py-2 bg-emerald-600 text-white text-xs font-bold rounded-xl hover:bg-emerald-700 transition-all disabled:opacity-50"
                            on:click={loadMore} disabled={loadingMore}>
                            {#if loadingMore}
                                <span class="animate-spin inline-block mr-1">⏳</span> Loading...
                            {:else}
                                Load More ({contacts.length} / {totalCount})
                            {/if}
                        </button>
                    </div>
                {/if}
            {/if}
        </div>

        <!-- Message History Panel -->
        {#if selectedContact}
            <div class="w-1/2 border-l border-slate-200 bg-white/80 backdrop-blur-xl flex flex-col overflow-hidden">
                <!-- Panel Header -->
                <div class="bg-emerald-600 text-white px-5 py-4 flex items-center justify-between">
                    <div class="flex items-center gap-3">
                        <span class="text-xl">{selectedContact.is_inside_24hr ? '🟢' : '🔴'}</span>
                        <div>
                            <h3 class="font-bold text-sm">{selectedContact.name}</h3>
                            <p class="text-emerald-100 text-xs font-mono">{selectedContact.whatsapp_number}</p>
                        </div>
                    </div>
                    <button class="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center transition-colors text-sm"
                        on:click={closeHistory}>✕</button>
                </div>

                <!-- 24hr Status Banner -->
                <div class="px-4 py-2 text-xs font-bold text-center {selectedContact.is_inside_24hr ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'}">
                    {selectedContact.is_inside_24hr
                        ? '🟢 Inside 24-hour window — Free-form messages allowed'
                        : '🔴 Outside 24-hour window — Templates only'}
                </div>

                <!-- Messages -->
                <div class="flex-1 overflow-y-auto p-4 space-y-3 bg-[#ECE5DD]">
                    {#if loadingHistory}
                        <div class="flex justify-center py-12">
                            <div class="animate-spin w-8 h-8 border-3 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                        </div>
                    {:else if messageHistory.length === 0}
                        <div class="text-center py-12">
                            <div class="text-3xl mb-2">💬</div>
                            <p class="text-slate-500 text-sm">No messages yet</p>
                        </div>
                    {:else}
                        {#each messageHistory as msg}
                            <div class="flex {msg.direction === 'outbound' ? 'justify-end' : 'justify-start'}">
                                <div class="max-w-[75%] px-3 py-2 rounded-xl text-sm shadow-sm
                                    {msg.direction === 'outbound'
                                        ? 'bg-[#DCF8C6] text-slate-800 rounded-tr-none'
                                        : 'bg-white text-slate-800 rounded-tl-none'}">
                                    {#if msg.message_type === 'image' && msg.media_url}
                                        <img src={msg.media_url} alt="media" class="rounded-lg max-w-full mb-1" />
                                    {/if}
                                    {#if msg.content}
                                        <p class="whitespace-pre-wrap">{msg.content}</p>
                                    {/if}
                                    {#if msg.template_name}
                                        <p class="text-[10px] text-slate-400 italic mt-1">📝 Template: {msg.template_name}</p>
                                    {/if}
                                    <div class="flex items-center justify-end gap-1 mt-1">
                                        <span class="text-[10px] text-slate-400">{formatMessageTime(msg.created_at)}</span>
                                        {#if msg.direction === 'outbound'}
                                            <span class="text-[10px] {msg.status === 'read' ? 'text-blue-500' : 'text-slate-400'}">{getStatusIcon(msg.status)}</span>
                                        {/if}
                                        {#if msg.sent_by === 'ai_bot'}
                                            <span class="text-[10px] bg-purple-100 text-purple-600 px-1 rounded">🤖 AI</span>
                                        {:else if msg.sent_by === 'auto_reply_bot'}
                                            <span class="text-[10px] bg-blue-100 text-blue-600 px-1 rounded">🔧 Bot</span>
                                        {/if}
                                    </div>
                                </div>
                            </div>
                        {/each}
                    {/if}
                </div>
            </div>
        {/if}
    </div>
</div>
