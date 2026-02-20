<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { openWindow } from '$lib/utils/windowManagerUtils';
    import WALiveChat from './WALiveChat.svelte';
    import WABroadcasts from './WABroadcasts.svelte';
    import { billCountCache, contactsCache, contactsTotalCount } from '$lib/stores/billCountCache';
    import type { BillDetail } from '$lib/stores/billCountCache';
    import { get } from 'svelte/store';

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
        bill_count?: number;
        bill_total?: number;
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
    let sortBy = 'default'; // default, bills_desc, bills_asc
    let selectedContact: Contact | null = null;
    let messageHistory: MessageHistory[] = [];
    let loadingHistory = false;
    let realtimeChannel: any = null;
    let realtimeConvChannel: any = null;
    let realtimeCodeChannel: any = null;
    let realtimeMsgChannel: any = null;
    // Bill count data is stored in a Svelte store so it persists across window open/close within the same session

    // Total count for display
    let totalCount = 0;
    let realtimeDebounce: any;

    // Checkbox selection
    let selectedIds: Set<string> = new Set();
    $: allVisibleSelected = visibleContacts.length > 0 && visibleContacts.every(c => selectedIds.has(c.id));

    function toggleSelectAll() {
        if (allVisibleSelected) {
            // Deselect all visible
            for (const c of visibleContacts) selectedIds.delete(c.id);
        } else {
            // Select all visible
            for (const c of visibleContacts) selectedIds.add(c.id);
        }
        selectedIds = new Set(selectedIds);
    }

    function toggleSelect(id: string) {
        if (selectedIds.has(id)) {
            selectedIds.delete(id);
        } else {
            selectedIds.add(id);
        }
        selectedIds = new Set(selectedIds);
    }

    // Virtual rendering - only render visible rows to prevent DOM freeze
    const RENDER_BATCH = 100;
    let visibleCount = RENDER_BATCH;
    let scrollSentinel: HTMLDivElement;
    let scrollObserver: IntersectionObserver;
    $: visibleContacts = filteredContacts.slice(0, visibleCount);

    function setupScrollObserver() {
        if (scrollObserver) scrollObserver.disconnect();
        scrollObserver = new IntersectionObserver((entries) => {
            if (entries[0]?.isIntersecting && visibleCount < filteredContacts.length) {
                visibleCount = Math.min(visibleCount + RENDER_BATCH, filteredContacts.length);
            }
        }, { rootMargin: '200px' });
        if (scrollSentinel) scrollObserver.observe(scrollSentinel);
    }

    // Svelte action to auto-observe the sentinel element
    function observeSentinel(node: HTMLElement) {
        if (scrollObserver) scrollObserver.disconnect();
        scrollObserver = new IntersectionObserver((entries) => {
            if (entries[0]?.isIntersecting && visibleCount < filteredContacts.length) {
                visibleCount = Math.min(visibleCount + RENDER_BATCH, filteredContacts.length);
            }
        }, { rootMargin: '200px' });
        scrollObserver.observe(node);
        return {
            destroy() {
                scrollObserver?.disconnect();
            }
        };
    }

    // Import state
    let importing = false;
    let importMessage = '';
    let fileInput: HTMLInputElement;

    // Bill loading state
    let loadingBills = false;
    let billLoadMessage = '';
    let selectedBillContact: Contact | null = null; // For bill breakdown popup

    // Bill details state (individual bills for a contact)
    let detailsContact: Contact | null = null;
    let detailsBills: BillDetail[] = [];
    let loadingDetails = false;

    // Last N days filter
    let lastNDays: string = ''; // empty = no filter

    // Broadcast generation
    let showBroadcastPopup = false;
    let bcTemplates: any[] = [];
    let bcSelectedTemplate: any = null;
    let bcTemplateSearch = '';
    let bcDateFrom = '';
    let bcDateTo = '';
    let bcMaxCount: string = '';
    let bcFilterHasBills = false;     // filter: has bill count > 0
    let bcFilterDelivered = false;    // filter: has delivered broadcast
    let bcFilterApproved = false;     // filter: approved customers (registration_status = 'approved')
    let bcGenerating = false;
    let bcGeneratedCount = 0;
    let bcAccountId = '';
    let bcSending = false;
    let bcBroadcastName = '';
    let bcSendResult = '';
    let bcHasGenerated = false;
    let bcFilterLog = '';  // shows filter step breakdown

    $: bcFilteredTemplates = bcTemplates.filter(t => 
        !bcTemplateSearch || t.name?.toLowerCase().includes(bcTemplateSearch.toLowerCase())
    );

    /** Debounced refresh — coalesces rapid realtime events into a single reload */
    function scheduleRefresh() {
        if (realtimeDebounce) clearTimeout(realtimeDebounce);
        realtimeDebounce = setTimeout(() => loadContacts(), 500);
    }

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;

        // Load from cache first if available
        const cached = get(contactsCache);
        if (cached.length > 0) {
            contacts = cached;
            totalCount = get(contactsTotalCount);
            loading = false;
            applyFilters();
        } else {
            await loadContacts();
        }
        // Auto-load bill counts if not already cached
        const cachedBills = get(billCountCache);
        if (cachedBills.size === 0) {
            loadBillCounts();
        }

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
        if (scrollObserver) scrollObserver.disconnect();
    });

    async function loadContacts() {
        try {
            contacts = [];

            const { data, error: err } = await supabase.rpc('get_wa_contacts', {
                p_limit: 100000,
                p_offset: 0,
                p_search: null
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
            } else {
                totalCount = 0;
            }

            contacts = mapped;
            // Save to cache
            contactsCache.set(mapped);
            contactsTotalCount.set(totalCount);
            applyFilters();
        } catch (e: any) {
            error = e.message;
        } finally {
            loading = false;
        }
    }

    function applyFilters() {
        let result = [...contacts];

        // Client-side search filter (all contacts are loaded)
        const query = searchQuery.trim().toLowerCase();
        if (query) {
            result = result.filter(c =>
                (c.name && c.name.toLowerCase().includes(query)) ||
                (c.whatsapp_number && c.whatsapp_number.includes(query))
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

        // Last N days filter — only show contacts with bills in the last N days
        const days = parseInt(lastNDays);
        if (days > 0) {
            const cache = get(billCountCache);
            const cutoff = new Date();
            cutoff.setDate(cutoff.getDate() - days);
            cutoff.setHours(0, 0, 0, 0);
            result = result.filter(c => {
                const billData = cache.get(c.id);
                if (!billData?.lastBillDate) return false;
                return new Date(billData.lastBillDate) >= cutoff;
            });
        }

        // Sort by bill count if selected
        if (sortBy === 'bills_desc') {
            const cache = get(billCountCache);
            result.sort((a, b) => {
                const aBills = cache.get(a.id)?.totalCount || 0;
                const bBills = cache.get(b.id)?.totalCount || 0;
                return bBills - aBills;
            });
        } else if (sortBy === 'bills_asc') {
            const cache = get(billCountCache);
            result.sort((a, b) => {
                const aBills = cache.get(a.id)?.totalCount || 0;
                const bBills = cache.get(b.id)?.totalCount || 0;
                return aBills - bBills;
            });
        }

        filteredContacts = result;
        // Reset visible count when filters change
        visibleCount = RENDER_BATCH;
    }

    // Client-side search — just re-apply filters (no server call needed)
    function handleSearchInput() {
        applyFilters();
    }

    // Re-run filters whenever statusFilter changes
    $: if (statusFilter) { applyFilters(); } else { applyFilters(); }

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

    async function clearCacheAndReload() {
        // Clear both caches
        billCountCache.set(new Map());
        contactsCache.set([]);
        contactsTotalCount.set(0);
        // Reset local state
        contacts = [];
        filteredContacts = [];
        totalCount = 0;
        visibleCount = RENDER_BATCH;
        selectedBillContact = null;
        selectedContact = null;
        // Reload fresh
        loading = true;
        await loadContacts();
    }

    async function loadBillCounts() {
        loadingBills = true;
        billLoadMessage = '⏳ Loading bill counts for all contacts...';

        // Use contacts array (always has all data), fallback to filtered if needed
        const targetContacts = contacts.length > 0 ? contacts : filteredContacts;
        if (targetContacts.length === 0) {
            billLoadMessage = '⚠️ No contacts to load bills for';
            loadingBills = false;
            return;
        }

        try {
            // Collect all phone numbers
            const phoneNumbers = targetContacts.map(c => c.whatsapp_number);
            console.log(`📊 Sending batch request for ${phoneNumbers.length} contacts`);

            // ONE single API call for ALL contacts × ALL branches
            const response = await fetch('/api/batch-bill-counts', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ phoneNumbers })
            });

            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error || 'Batch bill counts failed');
            }

            // Map results back to contacts and update the store
            billCountCache.update(map => {
                for (const contact of targetContacts) {
                    const result = data.results[contact.whatsapp_number];
                    if (result) {
                        map.set(contact.id, {
                            branchResults: result.branchResults,
                            totalCount: result.totalCount,
                            totalAmount: result.totalAmount,
                            lastBillDate: result.lastBillDate || null,
                            broadcastStats: result.broadcastStats
                        });
                    } else {
                        map.set(contact.id, {
                            branchResults: [],
                            totalCount: 0,
                            totalAmount: 0,
                            lastBillDate: null,
                            broadcastStats: { sent: 0, delivered: 0, read: 0 }
                        });
                    }
                }
                return new Map(map);
            });
            
            billLoadMessage = `✅ Loaded bill counts for ${targetContacts.length} contacts`;
            // Re-apply filters/sort so sorted view updates with new bill data
            applyFilters();
        } catch (e: any) {
            console.error('❌ Batch bill count error:', e);
            billLoadMessage = `❌ ${e.message}`;
        } finally {
            loadingBills = false;
            setTimeout(() => billLoadMessage = '', 5000);
        }
    }

    async function loadBillDetails(contact: Contact) {
        detailsContact = contact;
        loadingDetails = true;
        detailsBills = [];

        // Check if we already have details cached
        const cached = get(billCountCache).get(contact.id);
        if (cached?.billDetails && cached.billDetails.length > 0) {
            detailsBills = cached.billDetails;
            loadingDetails = false;
            return;
        }

        try {
            const response = await fetch('/api/contact-bill-details', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ phoneNumber: contact.whatsapp_number })
            });
            const data = await response.json();
            if (data.success) {
                detailsBills = data.bills || [];
                // Cache the details
                billCountCache.update(map => {
                    const existing = map.get(contact.id);
                    if (existing) {
                        existing.billDetails = detailsBills;
                        map.set(contact.id, existing);
                    }
                    return new Map(map);
                });
            }
        } catch (e: any) {
            console.error('❌ Bill details error:', e);
        } finally {
            loadingDetails = false;
        }
    }

    function formatBillDate(dateStr: string) {
        if (!dateStr) return '—';
        const d = new Date(dateStr);
        return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
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

    async function openBroadcastPopup() {
        showBroadcastPopup = true;
        bcSelectedTemplate = null;
        bcTemplateSearch = '';
        bcDateFrom = '';
        bcDateTo = '';
        bcMaxCount = '';
        bcFilterHasBills = false;
        bcFilterDelivered = false;
        bcFilterApproved = false;
        bcBroadcastName = '';
        bcSendResult = '';
        bcSending = false;
        bcFilterLog = '';

        // If customers already selected from table, preserve them
        if (selectedIds.size > 0) {
            bcGeneratedCount = selectedIds.size;
            bcHasGenerated = true;
        } else {
            bcGeneratedCount = 0;
            bcHasGenerated = false;
        }

        // Load WA account and templates
        if (!supabase) return;
        try {
            const { data: acc } = await supabase.from('wa_accounts').select('id').eq('is_default', true).single();
            if (acc) {
                bcAccountId = acc.id;
                const { data: tmpl } = await supabase.from('wa_templates')
                    .select('*')
                    .eq('wa_account_id', acc.id)
                    .eq('status', 'APPROVED')
                    .order('created_at', { ascending: false });
                bcTemplates = tmpl || [];
            }
        } catch (e) {
            console.error('Failed to load broadcast data:', e);
        }
    }

    function generateBroadcastList() {
        bcGenerating = true;
        bcSendResult = '';
        bcFilterLog = '';
        const cache = get(billCountCache);
        let candidates = [...filteredContacts];
        let log = `Starting: ${candidates.length} contacts`;

        // Filter by date range (based on lastBillDate)
        if (bcDateFrom) {
            const from = new Date(bcDateFrom);
            from.setHours(0, 0, 0, 0);
            candidates = candidates.filter(c => {
                const bd = cache.get(c.id);
                if (!bd?.lastBillDate) return false;
                return new Date(bd.lastBillDate) >= from;
            });
            log += ` → Date From: ${candidates.length}`;
        }
        if (bcDateTo) {
            const to = new Date(bcDateTo);
            to.setHours(23, 59, 59, 999);
            candidates = candidates.filter(c => {
                const bd = cache.get(c.id);
                if (!bd?.lastBillDate) return false;
                return new Date(bd.lastBillDate) <= to;
            });
            log += ` → Date To: ${candidates.length}`;
        }

        // Build active filters and apply OR logic when multiple selected
        const activeFilters: ((c: Contact) => boolean)[] = [];
        const filterNames: string[] = [];

        if (bcFilterHasBills) {
            activeFilters.push(c => {
                const bd = cache.get(c.id);
                return bd ? bd.totalCount > 0 : false;
            });
            filterNames.push('Has Bills');
        }
        if (bcFilterDelivered) {
            activeFilters.push(c => {
                const bd = cache.get(c.id);
                return bd?.broadcastStats ? (bd.broadcastStats.delivered > 0 || bd.broadcastStats.read > 0) : false;
            });
            filterNames.push('Delivered');
        }
        if (bcFilterApproved) {
            activeFilters.push(c => c.registration_status === 'approved');
            filterNames.push('Approved');
        }

        if (activeFilters.length > 0) {
            candidates = candidates.filter(c => activeFilters.some(fn => fn(c)));
            log += ` → ${filterNames.join(' OR ')}: ${candidates.length}`;
        }

        // Limit by max count
        const max = parseInt(bcMaxCount);
        if (!isNaN(max) && max > 0 && candidates.length > max) {
            candidates = candidates.slice(0, max);
            log += ` → Max ${max}: ${candidates.length}`;
        }

        // Select all matching contacts (tick checkboxes)
        selectedIds = new Set(candidates.map(c => c.id));
        bcGeneratedCount = candidates.length;
        bcGenerating = false;
        bcHasGenerated = true;
        bcFilterLog = log;
        console.log('📡 Generate:', log);
    }

    function selectAllContacts() {
        bcGenerating = true;
        bcSendResult = '';
        const cache = get(billCountCache);
        let candidates = [...filteredContacts];
        let log = `Starting: ${candidates.length}`;

        // Apply date range if set
        if (bcDateFrom) {
            const from = new Date(bcDateFrom);
            from.setHours(0, 0, 0, 0);
            candidates = candidates.filter(c => {
                const bd = cache.get(c.id);
                if (!bd?.lastBillDate) return true;
                return new Date(bd.lastBillDate) >= from;
            });
            log += ` \u2192 Date From: ${candidates.length}`;
        }
        if (bcDateTo) {
            const to = new Date(bcDateTo);
            to.setHours(23, 59, 59, 999);
            candidates = candidates.filter(c => {
                const bd = cache.get(c.id);
                if (!bd?.lastBillDate) return true;
                return new Date(bd.lastBillDate) <= to;
            });
            log += ` \u2192 Date To: ${candidates.length}`;
        }

        const max = parseInt(bcMaxCount);
        if (!isNaN(max) && max > 0 && candidates.length > max) {
            candidates = candidates.slice(0, max);
            log += ` \u2192 Max ${max}: ${candidates.length}`;
        }

        selectedIds = new Set(candidates.map(c => c.id));
        bcGeneratedCount = candidates.length;
        bcGenerating = false;
        bcHasGenerated = true;
        bcFilterLog = log;
        console.log('\ud83d\udce1 Select All:', log);
    }

    function selectAllApproved() {
        bcGenerating = true;
        bcSendResult = '';
        const cache = get(billCountCache);
        let candidates = filteredContacts.filter(c => c.registration_status === 'approved');
        let log = `Starting: ${filteredContacts.length} → Approved: ${candidates.length}`;

        // Apply date range if set
        if (bcDateFrom) {
            const from = new Date(bcDateFrom);
            from.setHours(0, 0, 0, 0);
            candidates = candidates.filter(c => {
                const bd = cache.get(c.id);
                if (!bd?.lastBillDate) return true; // keep approved even without bill date
                return new Date(bd.lastBillDate) >= from;
            });
            log += ` → Date From: ${candidates.length}`;
        }
        if (bcDateTo) {
            const to = new Date(bcDateTo);
            to.setHours(23, 59, 59, 999);
            candidates = candidates.filter(c => {
                const bd = cache.get(c.id);
                if (!bd?.lastBillDate) return true;
                return new Date(bd.lastBillDate) <= to;
            });
            log += ` → Date To: ${candidates.length}`;
        }

        // Apply max count
        const max = parseInt(bcMaxCount);
        if (!isNaN(max) && max > 0 && candidates.length > max) {
            candidates = candidates.slice(0, max);
            log += ` → Max ${max}: ${candidates.length}`;
        }

        selectedIds = new Set(candidates.map(c => c.id));
        bcGeneratedCount = candidates.length;
        bcGenerating = false;
        bcHasGenerated = true;
        bcFilterLog = log;
        console.log('📡 Select All Approved:', log);
    }

    async function sendBroadcastFromContacts() {
        if (!bcSelectedTemplate || !bcBroadcastName.trim() || selectedIds.size === 0 || bcSending) return;
        bcSending = true;
        bcSendResult = '';

        try {
            // Build recipient list from selected contacts
            const recipientList = contacts
                .filter(c => selectedIds.has(c.id))
                .map(c => ({ phone: c.whatsapp_number, name: c.name || '' }));

            if (recipientList.length === 0) {
                bcSendResult = '⚠️ No recipients selected';
                bcSending = false;
                return;
            }

            // Create broadcast record
            const { data: bc, error: bcErr } = await supabase.from('wa_broadcasts').insert({
                wa_account_id: bcAccountId,
                name: bcBroadcastName,
                template_id: bcSelectedTemplate.id,
                total_recipients: recipientList.length,
                status: 'sending'
            }).select().single();
            if (bcErr) throw bcErr;

            // Create recipient records
            const recipientInserts = recipientList.map(r => ({
                broadcast_id: bc.id,
                phone_number: r.phone,
                customer_name: r.name,
                status: 'pending'
            }));
            const { error: recipErr } = await supabase.from('wa_broadcast_recipients').insert(recipientInserts);
            if (recipErr) throw recipErr;

            // Fetch inserted recipients with their IDs
            const { data: insertedRecipients } = await supabase.from('wa_broadcast_recipients')
                .select('id, phone_number, customer_name')
                .eq('broadcast_id', bc.id);

            // Build template components (header media if needed)
            let templateComponents: any[] | undefined = undefined;
            if (bcSelectedTemplate.header_type && bcSelectedTemplate.header_type !== 'none' && bcSelectedTemplate.header_type !== 'text') {
                const headerType = bcSelectedTemplate.header_type.toLowerCase();
                const mediaUrl = bcSelectedTemplate.header_content;
                if (mediaUrl) {
                    const mediaParam: any = {};
                    if (headerType === 'image') {
                        mediaParam.type = 'image';
                        mediaParam.image = { link: mediaUrl };
                    } else if (headerType === 'video') {
                        mediaParam.type = 'video';
                        mediaParam.video = { link: mediaUrl };
                    } else if (headerType === 'document') {
                        mediaParam.type = 'document';
                        mediaParam.document = { link: mediaUrl };
                    }
                    templateComponents = [{ type: 'header', parameters: [mediaParam] }];
                }
            }

            // Send via edge function
            const { data: result, error: fnErr } = await supabase.functions.invoke('whatsapp-manage', {
                body: {
                    action: 'send_broadcast',
                    account_id: bcAccountId,
                    broadcast_id: bc.id,
                    template_name: bcSelectedTemplate.name,
                    language: bcSelectedTemplate.language,
                    components: templateComponents,
                    recipients: (insertedRecipients || []).map((r: any) => ({
                        id: r.id,
                        phone: r.phone_number
                    }))
                }
            });

            if (fnErr) {
                bcSendResult = `❌ Sending failed: ${fnErr.message || JSON.stringify(fnErr)}`;
            } else {
                // Success — close popup and open Broadcasts window
                showBroadcastPopup = false;
                bcSending = false;
                selectedIds = new Set();

                const windowId = `wa-broadcasts-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
                openWindow({
                    id: windowId,
                    title: `📣 ${$t('nav.whatsappBroadcasts')}`,
                    component: WABroadcasts,
                    componentName: 'WABroadcasts',
                    icon: '📣',
                    size: { width: 1300, height: 750 },
                    position: { x: 130 + (Math.random() * 100), y: 90 + (Math.random() * 100) },
                    resizable: true, minimizable: true, maximizable: true, closable: true
                });
                return;
            }
        } catch (e: any) {
            console.error('Broadcast send error:', e);
            bcSendResult = `❌ ${e.message}`;
        } finally {
            bcSending = false;
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
            <button class="px-3 py-2 bg-red-100 text-red-700 text-xs font-bold rounded-xl hover:bg-red-200 transition-all border border-red-200 flex items-center gap-1.5 disabled:opacity-50"
                on:click={clearCacheAndReload} disabled={loading}>
                {#if loading}
                    <span class="animate-spin">⏳</span> Refreshing...
                {:else}
                    🔄 Clear Cache
                {/if}
            </button>

            <!-- Generate Broadcast List -->
            <button class="px-3 py-2 bg-indigo-50 text-indigo-700 text-xs font-bold rounded-xl hover:bg-indigo-100 transition-all border border-indigo-200 flex items-center gap-1.5"
                on:click={openBroadcastPopup}>
                📡 Generate Broadcast
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
            <!-- Sort by Bills -->
            <button
                class="px-3 py-2 text-xs font-bold rounded-xl transition-all flex items-center gap-1.5 border
                {sortBy !== 'default' ? 'bg-purple-600 text-white border-purple-600' : 'bg-purple-50 text-purple-700 border-purple-200 hover:bg-purple-100'}"
                on:click={() => {
                    if (sortBy === 'default') sortBy = 'bills_desc';
                    else if (sortBy === 'bills_desc') sortBy = 'bills_asc';
                    else sortBy = 'default';
                    applyFilters();
                }}
                title={sortBy === 'default' ? 'Sort by bill count (high to low)' : sortBy === 'bills_desc' ? 'Sort by bill count (low to high)' : 'Reset sort order'}
            >
                {#if sortBy === 'bills_desc'}
                    📊 Bills ↓
                {:else if sortBy === 'bills_asc'}
                    📊 Bills ↑
                {:else}
                    📊 Sort Bills
                {/if}
            </button>
            <!-- Last N Days Filter -->
            <div class="flex items-center gap-1.5">
                <span class="text-xs text-slate-500 font-bold">Last</span>
                <input 
                    type="number" 
                    bind:value={lastNDays} 
                    on:input={() => applyFilters()}
                    placeholder="∞" 
                    min="1" 
                    max="3650"
                    class="w-14 px-2 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs text-center font-bold focus:outline-none focus:ring-2 focus:ring-orange-400 focus:border-orange-400"
                    title="Filter contacts with bills in the last N days"
                />
                <span class="text-xs text-slate-500 font-bold">days</span>
                {#if lastNDays && parseInt(lastNDays) > 0}
                    <button 
                        class="px-1.5 py-1 text-[10px] text-red-500 hover:text-red-700 font-bold"
                        on:click={() => { lastNDays = ''; applyFilters(); }}
                        title="Clear days filter">✕</button>
                {/if}
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

    <!-- Bill Load Status -->
    {#if billLoadMessage}
        <div class="px-6 py-2 text-sm font-bold text-center {billLoadMessage.startsWith('✅') ? 'bg-amber-50 text-amber-700' : 'bg-red-50 text-red-700'}">
            {billLoadMessage}
        </div>
    {/if}

    <!-- Main Content -->
    <div class="flex-1 flex relative overflow-hidden">
        <!-- Decorative -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/10 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse pointer-events-none"></div>

        <!-- Contact List -->
        <div class="flex-1 flex flex-col p-6 overflow-hidden {selectedContact ? 'w-1/2' : 'w-full'} transition-all">
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
                <div class="flex-1 bg-white/60 backdrop-blur-xl rounded-[2rem] border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.06)] overflow-y-auto">
                    <table class="w-full">
                        <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                            <tr>
                                <th class="px-2 py-3 text-center">
                                    <input type="checkbox" checked={allVisibleSelected} on:change={toggleSelectAll}
                                        class="w-4 h-4 rounded border-white/50 text-emerald-300 focus:ring-emerald-300 cursor-pointer" />
                                </th>
                                <th class="px-3 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider">24hr</th>
                                <th class="px-3 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider">Name</th>
                                <th class="px-3 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-[10px] font-black uppercase tracking-wider">Number</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Reg.</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Registered</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Approved</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Last Activity</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Unread</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Bills</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Last Bill</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Check Boss</th>
                                <th class="px-3 py-3 text-center text-[10px] font-black uppercase tracking-wider">Action</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-slate-100">
                            {#each visibleContacts as contact, index}
                                <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {selectedContact?.id === contact.id ? 'bg-emerald-50/50' : ''} {selectedIds.has(contact.id) ? 'bg-emerald-50/40' : ''}">
                                    <td class="px-2 py-2.5 text-center">
                                        <input type="checkbox" checked={selectedIds.has(contact.id)} on:change={() => toggleSelect(contact.id)}
                                            class="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer" />
                                    </td>
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
                                    <td class="px-4 py-3 text-center">
                                        {#if $billCountCache.has(contact.id)}
                                            {@const bills = $billCountCache.get(contact.id)}
                                            <button 
                                                class="flex flex-col items-center cursor-pointer hover:bg-emerald-50 p-1 rounded transition-colors"
                                                on:click={() => selectedBillContact = contact}
                                                title="Click to see branch breakdown">
                                                <span class="text-xs font-bold text-slate-800">{bills.totalCount || 0}</span>
                                                {#if bills.totalAmount}
                                                    <span class="text-[9px] text-slate-500">{(bills.totalAmount / 1000).toFixed(1)}k</span>
                                                {/if}
                                            </button>
                                        {:else}
                                            <span class="text-slate-300 text-xs">—</span>
                                        {/if}
                                    </td>
                                    <td class="px-3 py-2.5 text-center">
                                        {#if $billCountCache.has(contact.id)}
                                            {@const bills = $billCountCache.get(contact.id)}
                                            {#if bills.lastBillDate}
                                                <button 
                                                    class="text-[10px] font-bold text-orange-700 bg-orange-50 hover:bg-orange-100 px-2 py-1 rounded-lg transition-colors border border-orange-200 cursor-pointer"
                                                    on:click={() => loadBillDetails(contact)}
                                                    title="Click to view all bills">
                                                    {formatBillDate(bills.lastBillDate)}
                                                </button>
                                            {:else}
                                                <span class="text-slate-300 text-[10px]">—</span>
                                            {/if}
                                        {:else}
                                            <span class="text-slate-300 text-[10px]">—</span>
                                        {/if}
                                    </td>
                                    <td class="px-3 py-2.5 text-center">
                                        <span class="text-slate-300 text-xs">—</span>
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
                                        {#if $billCountCache.has(contact.id) && $billCountCache.get(contact.id).totalCount > 0}
                                            <button class="px-2.5 py-1.5 bg-orange-50 text-orange-700 text-xs font-bold rounded-lg hover:bg-orange-100 transition-all border border-orange-200"
                                                on:click={() => loadBillDetails(contact)}>
                                                📄 Details
                                            </button>
                                        {/if}
                                    </td>
                                </tr>
                            {/each}
                        </tbody>
                    </table>
                    <!-- Scroll sentinel for loading more rows -->
                    {#if visibleCount < filteredContacts.length}
                        <div bind:this={scrollSentinel} use:observeSentinel class="flex items-center justify-center py-3 text-xs text-slate-400">
                            Showing {visibleCount} of {filteredContacts.length} contacts...
                        </div>
                    {/if}
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

    <!-- Bill Breakdown Modal -->
    {#if selectedBillContact && $billCountCache.has(selectedBillContact.id)}
        {@const billData = $billCountCache.get(selectedBillContact.id)}
        <div 
            class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" 
            on:click={() => selectedBillContact = null}
            on:keydown={(e) => e.key === 'Escape' && (selectedBillContact = null)}
            role="dialog"
            aria-modal="true"
            aria-labelledby="bill-modal-title"
            tabindex="-1">
            <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full overflow-hidden" on:click|stopPropagation role="document">
                <!-- Modal Header -->
                <div class="bg-gradient-to-r from-emerald-600 to-emerald-700 text-white px-6 py-5 flex items-center justify-between">
                    <div class="flex items-center gap-3">
                        <span class="text-2xl">📊</span>
                        <div>
                            <h3 class="font-bold text-sm" id="bill-modal-title">{selectedBillContact.name}</h3>
                            <p class="text-emerald-100 text-xs font-mono">{selectedBillContact.whatsapp_number}</p>
                        </div>
                    </div>
                    <button 
                        class="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center transition-colors text-lg font-bold"
                        on:click={() => selectedBillContact = null}
                        aria-label="Close bill breakdown">×</button>
                </div>

                <!-- Modal Content -->
                <div class="p-6 space-y-4 max-h-96 overflow-y-auto">
                    {#if billData.branchResults.length === 0}
                        <div class="text-center py-8">
                            <p class="text-slate-500 text-sm">No branch data available</p>
                        </div>
                    {:else}
                        <!-- Branch List -->
                        <div class="space-y-3">
                            {#each billData.branchResults as branch}
                                <div class="border border-slate-200 rounded-lg p-4 hover:border-emerald-300 hover:bg-emerald-50/30 transition-all">
                                    <div class="mb-3 pb-3 border-b border-slate-100">
                                        <div class="flex items-start gap-2">
                                            <span class="text-lg">📍</span>
                                            <div class="flex-1">
                                                <h4 class="font-bold text-base text-slate-900">{branch.branchName}</h4>
                                                <p class="text-xs text-slate-600 mt-1 mb-2">{$locale === 'ar' ? branch.locationAr : branch.locationEn}</p>
                                                <span class="text-[10px] bg-slate-100 text-slate-600 px-2 py-1 rounded-full font-mono inline-block">Branch #{branch.branchId}</span>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="flex items-baseline justify-between">
                                        <span class="text-2xl font-black text-emerald-600">{branch.count}</span>
                                        <span class="text-xs text-slate-500">
                                            {#if branch.total > 0}
                                                SAR {(branch.total / 1000).toFixed(1)}k
                                            {:else}
                                                No transactions
                                            {/if}
                                        </span>
                                    </div>
                                </div>
                            {/each}
                        </div>

                        <!-- Divider -->
                        <div class="border-t-2 border-slate-200 my-2"></div>

                        <!-- Total Summary -->
                        <div class="bg-gradient-to-r from-emerald-50 to-emerald-100/50 rounded-lg p-4 border border-emerald-200">
                            <div class="flex items-center justify-between">
                                <span class="font-bold text-slate-700">Total Across All Branches:</span>
                                <div class="text-right">
                                    <div class="text-3xl font-black text-emerald-600">{billData.totalCount}</div>
                                    <div class="text-sm text-slate-600">SAR {(billData.totalAmount / 1000).toFixed(1)}k</div>
                                </div>
                            </div>
                        </div>

                        <!-- Broadcast Message Stats -->
                        {#if billData.broadcastStats}
                            <div class="bg-gradient-to-r from-blue-50 to-blue-100/50 rounded-lg p-4 border border-blue-200">
                                <div class="space-y-2">
                                    <!-- Top Row: Sent & Delivered -->
                                    <div class="flex items-center justify-between">
                                        <div class="flex items-center gap-3">
                                            <span class="text-lg">📤</span>
                                            <div>
                                                <p class="text-xs text-slate-600">Sent</p>
                                                <p class="text-xl font-black text-blue-600">{billData.broadcastStats.sent}</p>
                                            </div>
                                        </div>
                                        <div class="flex items-center gap-3">
                                            <span class="text-lg">✓✓</span>
                                            <div>
                                                <p class="text-xs text-slate-600">Delivered</p>
                                                <p class="text-xl font-black text-blue-600">{billData.broadcastStats.delivered}</p>
                                            </div>
                                        </div>
                                    </div>
                                    <!-- Bottom Row: Read -->
                                    <div class="flex items-center gap-3 pt-2 border-t border-blue-200">
                                        <span class="text-lg">👁️</span>
                                        <div>
                                            <p class="text-xs text-slate-600">Read</p>
                                            <p class="text-xl font-black text-blue-600">{billData.broadcastStats.read}</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        {/if}
                    {/if}
                </div>

                <!-- Modal Footer -->
                <div class="bg-slate-50 px-6 py-4 border-t border-slate-200 flex justify-end">
                    <button class="px-4 py-2 bg-slate-200 text-slate-800 text-sm font-bold rounded-lg hover:bg-slate-300 transition-all"
                        on:click={() => selectedBillContact = null}>
                        Close
                    </button>
                </div>
            </div>
        </div>
    {/if}

    <!-- Bill Details Modal -->
    {#if detailsContact}
        <div 
            class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" 
            on:click={() => { detailsContact = null; detailsBills = []; }}
            on:keydown={(e) => e.key === 'Escape' && (detailsContact = null, detailsBills = [])}
            role="dialog"
            aria-modal="true"
            aria-labelledby="details-modal-title"
            tabindex="-1">
            <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full overflow-hidden" on:click|stopPropagation on:keydown|stopPropagation role="document">
                <!-- Modal Header -->
                <div class="bg-gradient-to-r from-orange-500 to-orange-600 text-white px-6 py-5 flex items-center justify-between">
                    <div class="flex items-center gap-3">
                        <span class="text-2xl">📄</span>
                        <div>
                            <h3 class="font-bold text-sm" id="details-modal-title">{detailsContact.name}</h3>
                            <p class="text-orange-100 text-xs font-mono">{detailsContact.whatsapp_number}</p>
                        </div>
                    </div>
                    <button 
                        class="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center transition-colors text-lg font-bold"
                        on:click={() => { detailsContact = null; detailsBills = []; }}
                        aria-label="Close bill details">×</button>
                </div>

                <!-- Modal Content -->
                <div class="p-4 max-h-[60vh] overflow-y-auto">
                    {#if loadingDetails}
                        <div class="flex items-center justify-center py-12">
                            <div class="text-center">
                                <div class="animate-spin inline-block mb-2">
                                    <div class="w-8 h-8 border-3 border-orange-200 border-t-orange-600 rounded-full"></div>
                                </div>
                                <p class="text-slate-500 text-sm">Loading bill details...</p>
                            </div>
                        </div>
                    {:else if detailsBills.length === 0}
                        <div class="text-center py-8">
                            <p class="text-slate-500 text-sm">No individual bills found</p>
                        </div>
                    {:else}
                        <!-- Summary -->
                        <div class="mb-4 bg-orange-50 rounded-xl p-3 border border-orange-200">
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-orange-800">Total Bills: {detailsBills.length}</span>
                                <span class="text-xs font-bold text-orange-800">SAR {detailsBills.reduce((s, b) => s + b.amount, 0).toLocaleString('en', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
                            </div>
                        </div>

                        <!-- Bills Table -->
                        <table class="w-full text-xs">
                            <thead class="sticky top-0 bg-slate-100">
                                <tr>
                                    <th class="px-3 py-2 text-left font-bold text-slate-600 text-[10px] uppercase">#</th>
                                    <th class="px-3 py-2 text-left font-bold text-slate-600 text-[10px] uppercase">Date</th>
                                    <th class="px-3 py-2 text-right font-bold text-slate-600 text-[10px] uppercase">Amount (SAR)</th>
                                    <th class="px-3 py-2 text-left font-bold text-slate-600 text-[10px] uppercase">Branch</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-100">
                                {#each detailsBills as bill, i}
                                    <tr class="hover:bg-orange-50/50 transition-colors {i % 2 === 0 ? 'bg-white' : 'bg-slate-50/30'}">
                                        <td class="px-3 py-2 text-slate-400 font-mono">{i + 1}</td>
                                        <td class="px-3 py-2 text-slate-700 font-semibold">{formatBillDate(bill.date)}</td>
                                        <td class="px-3 py-2 text-right font-bold text-slate-800">{bill.amount.toLocaleString('en', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                                        <td class="px-3 py-2 text-slate-500">{bill.branchName}</td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    {/if}
                </div>

                <!-- Modal Footer -->
                <div class="bg-slate-50 px-6 py-4 border-t border-slate-200 flex justify-end">
                    <button class="px-4 py-2 bg-slate-200 text-slate-800 text-sm font-bold rounded-lg hover:bg-slate-300 transition-all"
                        on:click={() => { detailsContact = null; detailsBills = []; }}>
                        Close
                    </button>
                </div>
            </div>
        </div>
    {/if}

    <!-- Broadcast Popup Modal -->
    {#if showBroadcastPopup}
        <div class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-[9999]" on:click|self={() => showBroadcastPopup = false}>
            <div class="bg-white rounded-2xl shadow-2xl w-[560px] max-h-[85vh] flex flex-col overflow-hidden border border-slate-200">
                <!-- Header -->
                <div class="bg-gradient-to-r from-indigo-600 to-purple-600 px-6 py-4 flex items-center justify-between">
                    <h3 class="text-white font-bold text-base flex items-center gap-2">📡 Generate Broadcast List</h3>
                    <button class="text-white/80 hover:text-white text-xl font-bold transition-colors" on:click={() => showBroadcastPopup = false}>×</button>
                </div>

                <div class="p-6 space-y-5 overflow-y-auto flex-1">
                    <!-- Template Selection -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wider">Template</label>
                        <input type="text" bind:value={bcTemplateSearch} placeholder="Search templates..."
                            class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 mb-2" />
                        <div class="max-h-40 overflow-y-auto border border-slate-200 rounded-lg divide-y divide-slate-100">
                            {#each bcFilteredTemplates as tmpl}
                                <button
                                    class="w-full text-left px-3 py-2 text-sm hover:bg-indigo-50 transition-colors flex items-center gap-2
                                    {bcSelectedTemplate?.id === tmpl.id ? 'bg-indigo-100 text-indigo-800 font-bold' : 'text-slate-700'}"
                                    on:click={() => bcSelectedTemplate = tmpl}
                                >
                                    <span class="text-xs">
                                        {#if tmpl.header_type === 'image'}📷
                                        {:else if tmpl.header_type === 'video'}🎬
                                        {:else if tmpl.header_type === 'document'}📄
                                        {:else}💬
                                        {/if}
                                    </span>
                                    <span class="truncate">{tmpl.name}</span>
                                    <span class="ml-auto text-[10px] text-slate-400 uppercase">{tmpl.language}</span>
                                </button>
                            {:else}
                                <p class="px-3 py-4 text-sm text-slate-400 text-center">No templates found</p>
                            {/each}
                        </div>
                        {#if bcSelectedTemplate}
                            <div class="mt-2 px-3 py-2 bg-indigo-50 rounded-lg text-xs text-indigo-700 font-semibold">
                                ✅ Selected: {bcSelectedTemplate.name}
                            </div>
                        {/if}
                    </div>

                    <!-- Date Range -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wider">Date Range (Last Bill Date)</label>
                        <div class="flex gap-3">
                            <div class="flex-1">
                                <label class="text-[10px] text-slate-400 font-bold">From</label>
                                <input type="date" bind:value={bcDateFrom}
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400" />
                            </div>
                            <div class="flex-1">
                                <label class="text-[10px] text-slate-400 font-bold">To</label>
                                <input type="date" bind:value={bcDateTo}
                                    class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400" />
                            </div>
                        </div>
                    </div>

                    <!-- Max Customer Count -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wider">Maximum Customers</label>
                        <input type="number" bind:value={bcMaxCount} placeholder="No limit" min="1"
                            class="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400" />
                    </div>

                    <!-- Filters -->
                    <div>
                        <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wider">Filters</label>
                        <div class="space-y-2">
                            <label class="flex items-center gap-3 px-3 py-2.5 bg-slate-50 rounded-lg cursor-pointer hover:bg-slate-100 transition-colors border border-slate-200">
                                <input type="checkbox" bind:checked={bcFilterHasBills}
                                    class="w-4 h-4 text-indigo-600 rounded border-slate-300 focus:ring-indigo-500" />
                                <div>
                                    <span class="text-sm font-bold text-slate-700">📊 Has Bills</span>
                                    <p class="text-[10px] text-slate-400">Only include contacts with bill count &gt; 0</p>
                                </div>
                            </label>
                            <label class="flex items-center gap-3 px-3 py-2.5 bg-slate-50 rounded-lg cursor-pointer hover:bg-slate-100 transition-colors border border-slate-200">
                                <input type="checkbox" bind:checked={bcFilterDelivered}
                                    class="w-4 h-4 text-indigo-600 rounded border-slate-300 focus:ring-indigo-500" />
                                <div>
                                    <span class="text-sm font-bold text-slate-700">✅ Delivered Broadcast</span>
                                    <p class="text-[10px] text-slate-400">Only include contacts with delivered/read broadcast status</p>
                                </div>
                            </label>
                            <label class="flex items-center gap-3 px-3 py-2.5 bg-slate-50 rounded-lg cursor-pointer hover:bg-slate-100 transition-colors border border-slate-200">
                                <input type="checkbox" bind:checked={bcFilterApproved}
                                    class="w-4 h-4 text-indigo-600 rounded border-slate-300 focus:ring-indigo-500" />
                                <div>
                                    <span class="text-sm font-bold text-slate-700">🔑 Approved Customer</span>
                                    <p class="text-[10px] text-slate-400">Only include contacts with approved registration</p>
                                </div>
                            </label>
                        </div>
                    </div>

                    <!-- Action Buttons -->
                    <div class="flex gap-2">
                        <button
                            class="flex-1 py-3 bg-gradient-to-r from-indigo-600 to-purple-600 text-white text-sm font-bold rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                            on:click={generateBroadcastList}
                            disabled={bcGenerating}
                        >
                            {#if bcGenerating}
                                <span class="animate-spin">⏳</span> Generating...
                            {:else}
                                🎯 Generate List
                            {/if}
                        </button>
                        <button
                            class="flex-1 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white text-sm font-bold rounded-xl hover:from-green-700 hover:to-emerald-700 transition-all shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                            on:click={selectAllApproved}
                            disabled={bcGenerating}
                        >
                            🔑 All Approved
                        </button>
                        <button
                            class="flex-1 py-3 bg-gradient-to-r from-slate-600 to-slate-700 text-white text-sm font-bold rounded-xl hover:from-slate-700 hover:to-slate-800 transition-all shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                            on:click={selectAllContacts}
                            disabled={bcGenerating}
                        >
                            📋 Select All
                        </button>
                    </div>

                    {#if bcHasGenerated && bcGeneratedCount === 0 && !bcGenerating && bcSendResult === ''}
                        <div class="bg-amber-50 border border-amber-200 rounded-xl p-3 space-y-1">
                            <p class="text-sm font-bold text-amber-700">⚠️ No contacts matched your criteria.</p>
                            {#if bcFilterLog}
                                <p class="text-xs text-amber-600 font-mono">{bcFilterLog}</p>
                            {/if}
                            <p class="text-xs text-amber-500">Try adjusting filters or date range.</p>
                        </div>
                    {/if}

                    {#if bcGeneratedCount > 0}
                        <div class="bg-emerald-50 border border-emerald-200 rounded-xl p-4 space-y-3">
                            <p class="text-sm font-bold text-emerald-700">✅ {bcGeneratedCount} contacts selected</p>
                            
                            <!-- Broadcast Name -->
                            <div>
                                <label class="block text-xs font-bold text-slate-600 mb-1 uppercase tracking-wider">Broadcast Name</label>
                                <input type="text" bind:value={bcBroadcastName} placeholder="e.g. January Promo Blast"
                                    class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400" />
                            </div>

                            <!-- Send Button -->
                            <button
                                class="w-full py-3 bg-gradient-to-r from-emerald-600 to-green-600 text-white text-sm font-bold rounded-xl hover:from-emerald-700 hover:to-green-700 transition-all shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                                on:click={sendBroadcastFromContacts}
                                disabled={bcSending || !bcSelectedTemplate || !bcBroadcastName.trim()}
                            >
                                {#if bcSending}
                                    <span class="animate-spin">⏳</span> Sending...
                                {:else}
                                    🚀 Send Broadcast
                                {/if}
                            </button>
                        </div>
                    {/if}

                    {#if bcSendResult}
                        <div class="px-4 py-3 rounded-xl text-sm font-bold {bcSendResult.startsWith('✅') ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-red-50 text-red-700 border border-red-200'}">
                            {bcSendResult}
                        </div>
                    {/if}
                </div>
            </div>
        </div>
    {/if}
</div>
