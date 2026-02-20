<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface Contact {
        id: string;
        name: string;
        whatsapp_number: string;
        registration_status: string;
        last_message_at: string | null;
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
    let refreshInterval: any;

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadContacts();
        refreshInterval = setInterval(loadContacts, 30000); // Refresh every 30s
    });

    onDestroy(() => {
        if (refreshInterval) clearInterval(refreshInterval);
    });

    async function loadContacts() {
        try {
            // Load all customers with WhatsApp numbers
            const { data: customers, error: err } = await supabase
                .from('customers')
                .select('id, name, whatsapp_number, registration_status, created_at')
                .not('whatsapp_number', 'is', null)
                .not('whatsapp_number', 'eq', '')
                .order('name', { ascending: true });

            if (err) throw err;

            // Load conversations for 24hr status
            const { data: conversations } = await supabase
                .from('wa_conversations')
                .select('id, customer_id, last_message_at, unread_count');

            const convMap = new Map();
            (conversations || []).forEach((c: any) => {
                convMap.set(c.customer_id, c);
            });

            const now = new Date();
            contacts = (customers || []).map((c: any) => {
                const conv = convMap.get(c.id);
                const lastMsg = conv?.last_message_at ? new Date(conv.last_message_at) : null;
                const hoursDiff = lastMsg ? (now.getTime() - lastMsg.getTime()) / (1000 * 60 * 60) : Infinity;

                return {
                    id: c.id,
                    name: c.name || 'Unknown',
                    whatsapp_number: c.whatsapp_number,
                    registration_status: c.registration_status,
                    last_message_at: conv?.last_message_at || null,
                    unread_count: conv?.unread_count || 0,
                    is_inside_24hr: hoursDiff <= 24,
                    conversation_id: conv?.id || null,
                    created_at: c.created_at
                };
            });

            applyFilters();
        } catch (e: any) {
            error = e.message;
        } finally {
            loading = false;
        }
    }

    function applyFilters() {
        let result = [...contacts];

        // Search filter
        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            result = result.filter(c =>
                c.name.toLowerCase().includes(q) ||
                c.whatsapp_number.includes(q)
            );
        }

        // Status filter
        if (statusFilter === 'inside_24hr') {
            result = result.filter(c => c.is_inside_24hr);
        } else if (statusFilter === 'outside_24hr') {
            result = result.filter(c => !c.is_inside_24hr);
        } else if (statusFilter === 'unread') {
            result = result.filter(c => c.unread_count > 0);
        }

        filteredContacts = result;
    }

    $: searchQuery, statusFilter, applyFilters();

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
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-3">
            <span class="text-2xl">👥</span>
            <div>
                <h2 class="text-lg font-black text-slate-800 uppercase tracking-wide">{$t('nav.whatsappContacts')}</h2>
                <p class="text-xs text-slate-500">{contacts.length} {$t('whatsapp.contacts.totalContacts')}</p>
            </div>
        </div>
        <div class="flex items-center gap-3">
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
            <input type="text" bind:value={searchQuery} placeholder="Search name or number..."
                class="px-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm w-64 focus:outline-none focus:ring-2 focus:ring-emerald-500" />
        </div>
    </div>

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
                                <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider">Status</th>
                                <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider">{$t('whatsapp.contacts.name')}</th>
                                <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider">{$t('whatsapp.contacts.number')}</th>
                                <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider">{$t('whatsapp.contacts.lastMessage')}</th>
                                <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider">{$t('whatsapp.contacts.unread')}</th>
                                <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider">{$t('common.action')}</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-100">
                            {#each filteredContacts as contact, index}
                                <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {selectedContact?.id === contact.id ? 'bg-emerald-50/50' : ''}">
                                    <td class="px-4 py-3">
                                        <div class="flex items-center gap-2">
                                            <span class="text-lg">{contact.is_inside_24hr ? '🟢' : '🔴'}</span>
                                            <span class="text-[10px] font-bold uppercase {contact.is_inside_24hr ? 'text-emerald-600' : 'text-red-500'}">
                                                {contact.is_inside_24hr ? '24hr' : 'Outside'}
                                            </span>
                                        </div>
                                    </td>
                                    <td class="px-4 py-3">
                                        <div class="flex items-center gap-2">
                                            <span class="font-bold text-sm text-slate-800">{contact.name}</span>
                                        </div>
                                    </td>
                                    <td class="px-4 py-3 text-sm text-slate-600 font-mono">{contact.whatsapp_number}</td>
                                    <td class="px-4 py-3 text-center text-xs text-slate-500">{formatTime(contact.last_message_at)}</td>
                                    <td class="px-4 py-3 text-center">
                                        {#if contact.unread_count > 0}
                                            <span class="inline-flex items-center justify-center w-6 h-6 bg-emerald-500 text-white text-[10px] font-bold rounded-full">
                                                {contact.unread_count}
                                            </span>
                                        {:else}
                                            <span class="text-slate-300">—</span>
                                        {/if}
                                    </td>
                                    <td class="px-4 py-3 text-center">
                                        <button class="px-3 py-1.5 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-100 transition-all border border-emerald-200"
                                            on:click={() => viewHistory(contact)}>
                                            💬 {$t('whatsapp.contacts.viewHistory')}
                                        </button>
                                    </td>
                                </tr>
                            {/each}
                        </tbody>
                    </table>
                </div>
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
