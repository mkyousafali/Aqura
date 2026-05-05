<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';

    interface Broadcast {
        id: string;
        name: string;
        template_id: string;
        status: string;
        total_recipients: number;
        sent_count: number;
        delivered_count: number;
        read_count: number;
        failed_count: number;
        scheduled_at: string | null;
        completed_at: string | null;
        created_at: string;
        retry_attempted: boolean;
        last_activity: string | null;
        // Joined from wa_templates
        wa_templates?: { name: string; language: string } | null;
    }

    interface Recipient {
        id: string;
        phone_number: string;
        customer_name: string;
        status: string;
        sent_at: string | null;
        error_details: string | null;
    }

    interface WATemplate {
        id: string;
        name: string;
        category: string;
        body_text: string;
        header_type: string;
        header_content: string;
        footer_text: string;
        buttons: any[];
        language: string;
        status: string;
    }

    interface CustomerContact {
        phone: string;
        name: string;
        last_message_at: string | null;
        selected: boolean;
    }

    let supabase: any = null;
    let accountId = '';
    let broadcasts: Broadcast[] = [];
    let templates: WATemplate[] = [];
    let loading = true;
    let sending = false;
    let activeTab = 'list'; // list, create, details
    let selectedBroadcast: Broadcast | null = null;
    let detailRecipients: Recipient[] = [];
    let detailSummary = { total_count: 0, pending_count: 0, sent_count: 0, delivered_count: 0, read_count: 0, failed_count: 0 };
    let detailPage = 0;
    let detailPageSize = 100;
    let detailStatusFilter: string | null = null;
    let detailLoading = false;
    let detailTotalFiltered = 0;

    // Refresh state
    let refreshingBroadcastId: string | null = null;

    // Retry state
    let retryingBroadcastId: string | null = null;
    let retryCooldowns: Record<string, number> = {}; // broadcastId -> cooldown expiry timestamp
    let retryCooldownTimers: Record<string, NodeJS.Timeout> = {};

    // Eco retry state
    let ecoRetryingBroadcastId: string | null = null;

    // Analytics state
    interface AnalyticsResult {
        totalRecipients: number;
        visitedCount: number;
        notVisitedCount: number;
        conversionPct: number;
        branchCount: number;
        perPhone: Record<string, { billCount: number; totalAmount: number; lastBillDate: string | null }>;
    }
    let analyticsModal = false;
    let analyticsBroadcast: Broadcast | null = null;
    let analyticsDateTo = new Date().toISOString().split('T')[0]; // default today
    let analyticsLoading = false;
    let analyticsResult: AnalyticsResult | null = null;
    let analyticsError = '';
    let analyticsRecipientPhones: string[] = [];

    // Stall detection: track sent_count snapshots to detect stuck broadcasts
    let stallSnapshots: Record<string, { count: number; since: number }> = {};
    $: {
        // Update stall detection whenever broadcasts change
        for (const bc of broadcasts) {
            if (bc.status === 'sending') {
                const totalDone = (bc.sent_count || 0) + (bc.delivered_count || 0) + (bc.read_count || 0) + (bc.failed_count || 0);
                const snap = stallSnapshots[bc.id];
                if (!snap || snap.count !== totalDone) {
                    stallSnapshots = { ...stallSnapshots, [bc.id]: { count: totalDone, since: Date.now() } };
                }
            } else {
                if (stallSnapshots[bc.id]) {
                    const { [bc.id]: _, ...rest } = stallSnapshots;
                    stallSnapshots = rest;
                }
            }
        }
    }
    function isBroadcastStalled(bcId: string): boolean {
        const snap = stallSnapshots[bcId];
        if (!snap) return false;
        return Date.now() - snap.since > 3 * 60 * 1000; // 3 minutes with no progress
    }

    // Realtime channel
    let broadcastChannel: any = null;
    let autoRefreshInterval: any = null;
    let realtimeDebounceTimer: any = null;
    let realtimeDetailDebounceTimer: any = null;
    let loadBroadcastsInFlight = false;

    // Wizard steps
    let wizardStep = 1; // 1=Template, 2=Recipients, 3=Send

    // Step 1: Template
    let selectedTemplate: WATemplate | null = null;
    let selectedTemplateId = '';
    let templateSearchQuery = '';
    let templateDropdownOpen = false;

    // Step 2: Recipients
    let recipientMode: 'customers' | 'import' = 'customers';
    let allCustomers: CustomerContact[] = [];
    let loadingCustomers = false;
    let customerSearch = '';
    let filterPeriod = 'all'; // all, 24hr, 7days, 30days
    let selectAll = false;

    // Import
    let importedPhones: string[] = [];
    let importFileName = '';

    // Step 3: Send
    let broadcastName = '';
    let scheduleType: 'now' | 'schedule' = 'now';
    let scheduledAt = '';

    // Reactive: selected customer count
    $: selectedCustomers = allCustomers.filter(c => c.selected);
    $: filteredCustomers = filterCustomersList(allCustomers, customerSearch, filterPeriod);
    $: totalSelected = recipientMode === 'customers'
        ? selectedCustomers.length
        : importedPhones.length;

    // When template dropdown changes
    $: if (selectedTemplateId && templates.length > 0) {
        selectedTemplate = templates.find(t => t.id === selectedTemplateId) || null;
    }

    $: filteredTemplatesList = templates.filter(t => {
        if (!templateSearchQuery.trim()) return true;
        const q = templateSearchQuery.toLowerCase();
        return t.name.toLowerCase().includes(q) || t.category.toLowerCase().includes(q) || t.language.includes(q);
    });

    function selectTemplate(tmpl: WATemplate) {
        selectedTemplateId = tmpl.id;
        selectedTemplate = tmpl;
        templateSearchQuery = '';
        templateDropdownOpen = false;
    }

    function filterCustomersList(customers: CustomerContact[], search: string, period: string): CustomerContact[] {
        let result = customers;
        // Filter by search
        if (search.trim()) {
            const q = search.toLowerCase();
            result = result.filter(c => c.name.toLowerCase().includes(q) || c.phone.includes(q));
        }
        // Filter by period
        if (period !== 'all') {
            const now = Date.now();
            const hours: Record<string, number> = { '24hr': 24, '7days': 168, '30days': 720 };
            const maxMs = (hours[period] || 24) * 3600000;
            result = result.filter(c => {
                if (!c.last_message_at) return false;
                return (now - new Date(c.last_message_at).getTime()) <= maxMs;
            });
        }
        return result;
    }

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccount();
        setupRealtimeSubscription();
    });

    onDestroy(() => {
        if (broadcastChannel && supabase) {
            supabase.removeChannel(broadcastChannel);
        }
        if (autoRefreshInterval) clearInterval(autoRefreshInterval);
        if (realtimeDebounceTimer) clearTimeout(realtimeDebounceTimer);
        if (realtimeDetailDebounceTimer) clearTimeout(realtimeDetailDebounceTimer);
        // Clear cooldown timers
        Object.values(retryCooldownTimers).forEach(t => clearTimeout(t));
    });

    function debouncedLoadBroadcasts() {
        if (realtimeDebounceTimer) clearTimeout(realtimeDebounceTimer);
        realtimeDebounceTimer = setTimeout(() => {
            if (!loadBroadcastsInFlight) loadBroadcasts();
        }, 3000);
    }

    function debouncedRefreshDetails() {
        if (realtimeDetailDebounceTimer) clearTimeout(realtimeDetailDebounceTimer);
        realtimeDetailDebounceTimer = setTimeout(() => {
            if (activeTab === 'details' && selectedBroadcast) {
                loadDetailPage();
            }
        }, 5000);
    }

    function setupRealtimeSubscription() {
        if (!supabase) return;
        broadcastChannel = supabase.channel('wa-broadcasts-realtime')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'wa_broadcasts' }, () => {
                debouncedLoadBroadcasts();
            })
            .on('postgres_changes', { event: '*', schema: 'public', table: 'wa_broadcast_recipients' }, () => {
                debouncedLoadBroadcasts();
                debouncedRefreshDetails();
            })
            .subscribe();
    }

    function pct(count: number, total: number): string {
        if (!total) return '0%';
        return Math.round((count / total) * 100) + '%';
    }

    async function loadAccount() {
        try {
            const { data } = await supabase.from('wa_accounts').select('id').eq('is_default', true).single();
            if (data) {
                accountId = data.id;
                await Promise.all([loadBroadcasts(), loadTemplates()]);
                // Auto-refresh recent broadcasts to get latest status from webhooks
                autoRefreshRecentBroadcasts();
                // Poll every 8 seconds — faster for active broadcasts
                autoRefreshInterval = setInterval(() => autoRefreshRecentBroadcasts(), 8000);
            }
        } catch {} finally { loading = false; }
    }

    // Track per-broadcast watchdog invocations to prevent duplicate auto-resumes
    const watchdogInFlight = new Set<string>();

    async function autoRefreshRecentBroadcasts() {
        if (!broadcasts.length || refreshingBroadcastId) return;
        const oneHourAgo = Date.now() - 60 * 60 * 1000;
        const recentActive = broadcasts.filter(bc =>
            bc.status === 'sending' || 
            (bc.status === 'completed' && new Date(bc.created_at).getTime() > oneHourAgo)
        );
        for (const bc of recentActive) {
            await refreshBroadcastStatus(bc);
        }

        // Silent watchdog: if a 'sending' broadcast is stalled (no progress for 3 min),
        // auto-resume it without any user action
        for (const bc of broadcasts) {
            if (bc.status !== 'sending') continue;
            if (watchdogInFlight.has(bc.id)) continue;
            if (!isBroadcastStalled(bc.id)) continue;

            // Check if there are actually pending recipients
            const { count: pendingCount } = await supabase.from('wa_broadcast_recipients')
                .select('*', { count: 'exact', head: true })
                .eq('broadcast_id', bc.id)
                .eq('status', 'pending');

            if (!pendingCount || pendingCount === 0) continue;

            console.log(`[Watchdog] Broadcast ${bc.id} stalled with ${pendingCount} pending. Auto-resuming...`);
            watchdogInFlight.add(bc.id);
            // Fire and forget — no await, no alert
            autoResumeBroadcast(bc).finally(() => watchdogInFlight.delete(bc.id));
        }
    }

    async function autoResumeBroadcast(bc: Broadcast) {
        try {
            const { data: tmpl } = await supabase.from('wa_templates')
                .select('*').eq('id', bc.template_id).single();
            if (!tmpl) return;

            let templateComponents: any[] | undefined = undefined;
            if (tmpl.header_type && tmpl.header_type !== 'none' && tmpl.header_type !== 'text') {
                const headerType = tmpl.header_type.toLowerCase();
                const mediaUrl = tmpl.header_content;
                if (mediaUrl) {
                    const mediaParam: any = {};
                    if (headerType === 'image') { mediaParam.type = 'image'; mediaParam.image = { link: mediaUrl }; }
                    else if (headerType === 'video') { mediaParam.type = 'video'; mediaParam.video = { link: mediaUrl }; }
                    else if (headerType === 'document') {
                        mediaParam.type = 'document';
                        const fn = mediaUrl.split('/').pop()?.split('?')[0] || 'document.pdf';
                        mediaParam.document = { link: mediaUrl, filename: decodeURIComponent(fn) };
                    }
                    templateComponents = [{ type: 'header', parameters: [mediaParam] }];
                }
            }

            await supabase.functions.invoke('whatsapp-manage', {
                body: {
                    action: 'send_broadcast',
                    account_id: accountId,
                    broadcast_id: bc.id,
                    template_name: tmpl.name,
                    language: tmpl.language,
                    components: templateComponents,
                }
            });
        } catch (e: any) {
            console.warn(`[Watchdog] Auto-resume failed for ${bc.id}:`, e?.message);
        }
    }

    async function loadBroadcasts() {
        if (loadBroadcastsInFlight) return;
        loadBroadcastsInFlight = true;
        try {
            const { data, error } = await supabase.from('wa_broadcasts')
                .select('*, wa_templates(name, language)')
                .eq('wa_account_id', accountId)
                .order('created_at', { ascending: false });
            if (!error) broadcasts = data || [];
        } catch (e) {
            console.error('loadBroadcasts failed:', e);
        } finally {
            loadBroadcastsInFlight = false;
        }
    }

    async function loadTemplates() {
        const { data } = await supabase.from('wa_templates').select('*').eq('wa_account_id', accountId).eq('status', 'APPROVED').order('created_at', { ascending: false });
        templates = data || [];
    }

    async function loadCustomers() {
        loadingCustomers = true;
        try {
            const { data } = await supabase.from('wa_conversations')
                .select('customer_phone, customer_name, last_message_at')
                .eq('wa_account_id', accountId)
                .eq('status', 'active')
                .order('last_message_at', { ascending: false });
            allCustomers = (data || []).map((c: any) => ({
                phone: c.customer_phone,
                name: c.customer_name || '',
                last_message_at: c.last_message_at,
                selected: false
            }));
        } catch (e) {
            console.error('Failed to load customers:', e);
        } finally {
            loadingCustomers = false;
        }
    }

    function startCreateBroadcast() {
        activeTab = 'create';
        wizardStep = 1;
        selectedTemplate = null;
        selectedTemplateId = '';
        recipientMode = 'customers';
        allCustomers = [];
        importedPhones = [];
        importFileName = '';
        customerSearch = '';
        filterPeriod = 'all';
        selectAll = false;
        broadcastName = '';
        scheduleType = 'now';
        scheduledAt = '';
    }

    async function goToStep(step: number) {
        if (step === 2 && !selectedTemplate) return;
        if (step === 2 && allCustomers.length === 0) {
            await loadCustomers();
        }
        if (step === 3 && totalSelected === 0) return;
        wizardStep = step;
    }

    async function viewBroadcastDetails(bc: Broadcast) {
        selectedBroadcast = bc;
        activeTab = 'details';
        detailPage = 0;
        detailStatusFilter = null;
        await loadDetailPage();
    }

    async function loadDetailPage() {
        if (!selectedBroadcast || detailLoading) return;
        detailLoading = true;
        try {
            // Load summary counts + page of recipients in parallel
            const [summaryRes, recipientsRes] = await Promise.all([
                supabase.rpc('get_broadcast_summary', { p_broadcast_id: selectedBroadcast.id }),
                supabase.rpc('get_broadcast_recipients', {
                    p_broadcast_id: selectedBroadcast.id,
                    p_limit: detailPageSize,
                    p_offset: detailPage * detailPageSize,
                    p_status_filter: detailStatusFilter
                })
            ]);
            if (summaryRes.data && summaryRes.data.length > 0) {
                detailSummary = summaryRes.data[0];
            }
            detailRecipients = recipientsRes.data || [];
            // Calculate total for current filter
            if (!detailStatusFilter) {
                detailTotalFiltered = detailSummary.total_count;
            } else {
                detailTotalFiltered = (detailSummary as any)[detailStatusFilter + '_count'] || 0;
            }
        } catch (e) {
            console.error('Failed to load broadcast details:', e);
        } finally {
            detailLoading = false;
        }
    }

    function detailNextPage() {
        if ((detailPage + 1) * detailPageSize < detailTotalFiltered) {
            detailPage++;
            loadDetailPage();
        }
    }

    function detailPrevPage() {
        if (detailPage > 0) {
            detailPage--;
            loadDetailPage();
        }
    }

    function setDetailStatusFilter(status: string | null) {
        detailStatusFilter = status;
        detailPage = 0;
        loadDetailPage();
    }

    function toggleSelectAll() {
        selectAll = !selectAll;
        // Only toggle filtered customers
        const filteredPhones = new Set(filteredCustomers.map(c => c.phone));
        allCustomers = allCustomers.map(c => ({
            ...c,
            selected: filteredPhones.has(c.phone) ? selectAll : c.selected
        }));
    }

    function toggleCustomer(phone: string) {
        allCustomers = allCustomers.map(c =>
            c.phone === phone ? { ...c, selected: !c.selected } : c
        );
        // Update selectAll state
        const allFilteredSelected = filteredCustomers.length > 0 && filteredCustomers.every(c => c.selected);
        selectAll = allFilteredSelected;
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

    function removeImportedPhone(phone: string) {
        importedPhones = importedPhones.filter(p => p !== phone);
    }

    function getTimeSince(dateStr: string | null): string {
        if (!dateStr) return 'Never';
        const diff = Date.now() - new Date(dateStr).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 60) return `${mins}m ago`;
        const hrs = Math.floor(mins / 60);
        if (hrs < 24) return `${hrs}h ago`;
        const days = Math.floor(hrs / 24);
        if (days < 30) return `${days}d ago`;
        return `${Math.floor(days / 30)}mo ago`;
    }

    function isWithin24hr(dateStr: string | null): boolean {
        if (!dateStr) return false;
        return (Date.now() - new Date(dateStr).getTime()) <= 86400000;
    }

    async function sendBroadcast() {
        if (!selectedTemplate || !broadcastName.trim() || sending) return;
        sending = true;
        try {
            // Build recipient list
            let recipientList: { phone: string; name: string }[] = [];

            if (recipientMode === 'customers') {
                recipientList = selectedCustomers.map(c => ({ phone: c.phone, name: c.name }));
            } else {
                recipientList = importedPhones.map(p => ({ phone: p, name: '' }));
            }

            if (recipientList.length === 0) {
                alert('No recipients selected');
                sending = false;
                return;
            }

            // Create broadcast record
            const { data: bc, error: err } = await supabase.from('wa_broadcasts').insert({
                wa_account_id: accountId,
                name: broadcastName,
                template_id: selectedTemplate.id,
                total_recipients: recipientList.length,
                status: scheduleType === 'schedule' ? 'scheduled' : 'sending',
                scheduled_at: scheduleType === 'schedule' ? scheduledAt : null
            }).select().single();
            if (err) throw err;

            // Create recipient records
            const recipientInserts = recipientList.map(r => ({
                broadcast_id: bc.id,
                phone_number: r.phone,
                customer_name: r.name,
                status: 'pending'
            }));
            const { error: recipErr } = await supabase.from('wa_broadcast_recipients').insert(recipientInserts);
            if (recipErr) throw recipErr;

            if (scheduleType === 'now') {
                // Send via edge function (server-side, keeps access_token secure)
                // The edge function reads recipients directly from DB — no need to pass them
                // This avoids huge request bodies for 20k+ broadcasts
                
                // Build template components (header media if needed)
                let templateComponents: any[] | undefined = undefined;
                if (selectedTemplate!.header_type && selectedTemplate!.header_type !== 'none' && selectedTemplate!.header_type !== 'text') {
                    const headerType = selectedTemplate!.header_type.toLowerCase();
                    const mediaUrl = selectedTemplate!.header_content;
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
                            // Extract filename from URL so customers see the real name instead of 'untitled'
                            const docFilename = mediaUrl.split('/').pop()?.split('?')[0] || 'document.pdf';
                            mediaParam.document = { link: mediaUrl, filename: decodeURIComponent(docFilename) };
                        }
                        templateComponents = [{
                            type: 'header',
                            parameters: [mediaParam]
                        }];
                    }
                }

                const { data: result, error: fnErr } = await supabase.functions.invoke('whatsapp-manage', {
                    body: {
                        action: 'send_broadcast',
                        account_id: accountId,
                        broadcast_id: bc.id,
                        template_name: selectedTemplate!.name,
                        language: selectedTemplate!.language,
                        components: templateComponents
                        // recipients omitted — edge function reads from DB directly
                    }
                });
                if (fnErr) {
                    console.error('Edge function error:', fnErr);
                    alert('Broadcast created but sending failed: ' + (fnErr.message || JSON.stringify(fnErr)));
                } else {
                    alert('Broadcast started! It is processing in the background. Use the Refresh Status button to track progress.');
                }
            } else {
                alert('Broadcast scheduled successfully!');
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

    function isRetryCoolingDown(broadcastId: string): boolean {
        const expiry = retryCooldowns[broadcastId];
        if (!expiry) return false;
        return Date.now() < expiry;
    }

    function getRetryCooldownRemaining(broadcastId: string): string {
        const expiry = retryCooldowns[broadcastId];
        if (!expiry) return '';
        const remaining = Math.max(0, Math.ceil((expiry - Date.now()) / 60000));
        return `${remaining}m`;
    }

    async function retryFailedRecipients(bc: Broadcast) {
        if (retryingBroadcastId) return;  // Prevent double-click
        retryingBroadcastId = bc.id;

        try {
            // Get the template info for this broadcast
            const { data: tmpl } = await supabase.from('wa_templates')
                .select('*')
                .eq('id', bc.template_id)
                .single();
            if (!tmpl) throw new Error('Template not found');

            // Get count of failed recipients
            const { count: failedCount } = await supabase.from('wa_broadcast_recipients')
                .select('*', { count: 'exact', head: true })
                .eq('broadcast_id', bc.id)
                .eq('status', 'failed');

            if (!failedCount || failedCount === 0) {
                retryingBroadcastId = null;
                return;
            }

            // Mark retry as attempted immediately (hides the button)
            await supabase.from('wa_broadcasts')
                .update({ retry_attempted: true })
                .eq('id', bc.id);
            // Update local state so button disappears right away
            broadcasts = broadcasts.map(b => b.id === bc.id ? { ...b, retry_attempted: true } : b);

            // Reset failed recipients to pending
            await supabase.from('wa_broadcast_recipients')
                .update({ status: 'pending', error_details: null })
                .eq('broadcast_id', bc.id)
                .eq('status', 'failed');

            // Update broadcast status back to sending
            await supabase.from('wa_broadcasts')
                .update({ status: 'sending' })
                .eq('id', bc.id);

            // Build template components (header media if needed)
            let templateComponents: any[] | undefined = undefined;
            if (tmpl.header_type && tmpl.header_type !== 'none' && tmpl.header_type !== 'text') {
                const headerType = tmpl.header_type.toLowerCase();
                const mediaUrl = tmpl.header_content;
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
                        const docFilename = mediaUrl.split('/').pop()?.split('?')[0] || 'document.pdf';
                        mediaParam.document = { link: mediaUrl, filename: decodeURIComponent(docFilename) };
                    }
                    templateComponents = [{ type: 'header', parameters: [mediaParam] }];
                }
            }

            // Call edge function — slow mode to avoid ecosystem blocks
            console.log(`[Retry Failed] Retrying ${failedCount} failed recipients for broadcast ${bc.id}`);
            const { error: fnErr } = await supabase.functions.invoke('whatsapp-manage', {
                body: {
                    action: 'send_broadcast',
                    account_id: accountId,
                    broadcast_id: bc.id,
                    template_name: tmpl.name,
                    language: tmpl.language,
                    components: templateComponents,
                    slow_mode: true
                }
            });

            if (fnErr) {
                console.error('[Retry Failed] Edge function error:', fnErr);
            }

            await loadBroadcasts();
        } catch (e: any) {
            console.error('[Retry Failed] Error:', e);
        } finally {
            retryingBroadcastId = null;
        }
    }

    async function resumePendingRecipients(bc: Broadcast) {
        if (!accountId || !bc?.id) throw new Error('Missing broadcast or account');
        retryingBroadcastId = bc.id;

        try {
            const { data: tmpl } = await supabase.from('wa_templates')
                .select('*')
                .eq('id', bc.template_id)
                .single();
            if (!tmpl) throw new Error('Template not found');

            // Get count of pending recipients (those never sent)
            const { count: pendingCount } = await supabase.from('wa_broadcast_recipients')
                .select('*', { count: 'exact', head: true })
                .eq('broadcast_id', bc.id)
                .eq('status', 'pending');

            if (!pendingCount || pendingCount === 0) {
                alert('No pending recipients to resume');
                retryingBroadcastId = null;
                return;
            }

            // Update broadcast status to sending if needed
            const { error: statusErr } = await supabase.from('wa_broadcasts')
                .update({ status: 'sending' })
                .eq('id', bc.id);
            if (statusErr) console.warn('[Resume] Status update failed (non-blocking):', statusErr.message);

            // Build template components
            let templateComponents: any[] | undefined = undefined;
            if (tmpl.header_type && tmpl.header_type !== 'none' && tmpl.header_type !== 'text') {
                const headerType = tmpl.header_type.toLowerCase();
                const mediaUrl = tmpl.header_content;
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
                        const docFilename = mediaUrl.split('/').pop()?.split('?')[0] || 'document.pdf';
                        mediaParam.document = { link: mediaUrl, filename: decodeURIComponent(docFilename) };
                    }
                    templateComponents = [{ type: 'header', parameters: [mediaParam] }];
                }
            }

            console.log(`[Resume Pending] Resuming ${pendingCount} pending recipients for broadcast ${bc.id}`);
            const { error: fnErr } = await supabase.functions.invoke('whatsapp-manage', {
                body: {
                    action: 'send_broadcast',
                    account_id: accountId,
                    broadcast_id: bc.id,
                    template_name: tmpl.name,
                    language: tmpl.language,
                    components: templateComponents
                }
            });

            if (fnErr) {
                console.error('Resume pending error:', fnErr);
                alert('Resume started in background. Check Refresh Status. Error: ' + (fnErr.message || ''));
            } else {
                alert(`✅ Resuming ${pendingCount} pending recipients! Check Refresh Status for progress.`);
            }

            await loadBroadcasts();
        } catch (e: any) {
            console.error('Resume pending error:', e);
            alert('Error: ' + e.message);
        } finally {
            retryingBroadcastId = null;
        }
    }

    async function retryEcosystemFailed(bc: Broadcast) {
        if (ecoRetryingBroadcastId) return;
        ecoRetryingBroadcastId = bc.id;

        try {
            // Get the template info for this broadcast
            const { data: tmpl } = await supabase.from('wa_templates')
                .select('*')
                .eq('id', bc.template_id)
                .single();
            if (!tmpl) throw new Error('Template not found');

            // Build template components (header media if needed)
            let templateComponents: any[] | undefined = undefined;
            if (tmpl.header_type && tmpl.header_type !== 'none' && tmpl.header_type !== 'text') {
                const headerType = tmpl.header_type.toLowerCase();
                const mediaUrl = tmpl.header_content;
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
                        const docFilename = mediaUrl.split('/').pop()?.split('?')[0] || 'document.pdf';
                        mediaParam.document = { link: mediaUrl, filename: decodeURIComponent(docFilename) };
                    }
                    templateComponents = [{ type: 'header', parameters: [mediaParam] }];
                }
            }

            // Call edge function with eco_retry action
            const { data: result, error: fnErr } = await supabase.functions.invoke('whatsapp-manage', {
                body: {
                    action: 'send_eco_retry',
                    account_id: accountId,
                    broadcast_id: bc.id,
                    template_name: tmpl.name,
                    language: tmpl.language,
                    components: templateComponents
                }
            });

            if (fnErr) {
                console.error('Eco retry error:', fnErr);
                alert('Eco retry failed: ' + (fnErr.message || JSON.stringify(fnErr)));
            } else {
                alert('Ecosystem retry started! Sending slowly (~3 msg/s) in the background.');
            }

            await loadBroadcasts();
        } catch (e: any) {
            console.error('Eco retry error:', e);
            alert('Eco retry failed: ' + e.message);
        } finally {
            ecoRetryingBroadcastId = null;
        }
    }

    async function refreshBroadcastStatus(bc: Broadcast) {
        if (refreshingBroadcastId) return;
        refreshingBroadcastId = bc.id;
        try {
            // Use server-side RPC to refresh statuses in bulk (avoids URL length limits)
            const { data, error: rpcError } = await supabase
                .rpc('refresh_broadcast_status', { p_broadcast_id: bc.id });
            if (rpcError) throw rpcError;

            console.log('Broadcast status refreshed:', data);

            // Refresh local data
            await loadBroadcasts();
        } catch (e: any) {
            console.error('Failed to refresh broadcast status:', e);
        } finally {
            refreshingBroadcastId = null;
        }
    }

    async function openAnalyticsModal(bc: Broadcast) {
        analyticsBroadcast = bc;
        analyticsResult = null;
        analyticsError = '';
        analyticsLoading = false;
        // Default "up to date" to today
        analyticsDateTo = new Date().toISOString().split('T')[0];
        analyticsModal = true;

        // Pre-load the recipient phones (we need them for the query)
        analyticsRecipientPhones = [];
        try {
            // Fetch all successfully sent recipients (sent/delivered/read)
            const { data: rows } = await supabase
                .from('wa_broadcast_recipients')
                .select('phone_number')
                .eq('broadcast_id', bc.id)
                .in('status', ['sent', 'delivered', 'read']);
            analyticsRecipientPhones = (rows || []).map((r: any) => r.phone_number);
        } catch (e) {
            console.error('Failed to load recipient phones:', e);
        }
    }

    async function runBroadcastAnalytics() {
        if (!analyticsBroadcast) return;
        const broadcastDate = (analyticsBroadcast.created_at || '').split('T')[0];
        if (!analyticsDateTo) {
            analyticsError = 'Please select an end date.';
            return;
        }
        if (analyticsDateTo < broadcastDate) {
            analyticsError = `End date must be on or after broadcast date (${broadcastDate}).`;
            return;
        }
        analyticsError = '';
        analyticsLoading = true;
        analyticsResult = null;

        try {
            const resp = await fetch('/api/broadcast-analytics', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    phoneNumbers: analyticsRecipientPhones,
                    afterDate: broadcastDate,
                    beforeDate: analyticsDateTo
                })
            });
            const data = await resp.json();
            if (!data.success) throw new Error(data.error || 'Analytics request failed');

            const perPhone = data.results as Record<string, { billCount: number; totalAmount: number; lastBillDate: string | null }>;
            let visitedCount = 0;
            for (const phone of analyticsRecipientPhones) {
                if (perPhone[phone]?.billCount > 0) visitedCount++;
            }
            const totalRecipients = analyticsRecipientPhones.length;
            const notVisitedCount = totalRecipients - visitedCount;
            const conversionPct = totalRecipients > 0 ? Math.round((visitedCount / totalRecipients) * 100) : 0;

            analyticsResult = {
                totalRecipients,
                visitedCount,
                notVisitedCount,
                conversionPct,
                branchCount: data.branchCount || 0,
                perPhone
            };
        } catch (e: any) {
            analyticsError = e.message || 'Failed to load analytics';
        } finally {
            analyticsLoading = false;
        }
    }

    function fmtAnalyticsDate(d: string | null) {
        if (!d) return '—';
        return new Date(d).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
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

    function handleWindowClick(e: MouseEvent) {
        const target = e.target as HTMLElement;
        if (templateDropdownOpen && !target.closest('.template-select-row')) {
            templateDropdownOpen = false;
        }
    }
</script>

<svelte:window on:click={handleWindowClick} />

<div class="wa-broadcasts" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Header -->
    <div class="header">
        <div class="header-row">
            <div class="header-left">
                <span class="header-icon">📣</span>
                <h1 class="header-title">{$t('nav.whatsappBroadcasts')}</h1>
            </div>
            {#if activeTab === 'list'}
                <button class="btn-primary" on:click={startCreateBroadcast}>
                    + New Broadcast
                </button>
            {:else}
                <button class="btn-back" on:click={() => activeTab = 'list'}>
                    ← Back to List
                </button>
            {/if}
        </div>

        <!-- Wizard Steps (only in create mode) -->
        {#if activeTab === 'create'}
            <div class="wizard-steps">
                <button class="wizard-step" class:active={wizardStep === 1} class:completed={wizardStep > 1}
                    on:click={() => { wizardStep = 1; }}>
                    <span class="step-num">{wizardStep > 1 ? '✓' : '1'}</span>
                    <span class="step-label">Select Template</span>
                </button>
                <div class="step-connector" class:active={wizardStep > 1}></div>
                <button class="wizard-step" class:active={wizardStep === 2} class:completed={wizardStep > 2}
                    on:click={() => { if (selectedTemplate) goToStep(2); }}
                    disabled={!selectedTemplate}>
                    <span class="step-num">{wizardStep > 2 ? '✓' : '2'}</span>
                    <span class="step-label">Select Recipients</span>
                </button>
                <div class="step-connector" class:active={wizardStep > 2}></div>
                <button class="wizard-step" class:active={wizardStep === 3}
                    on:click={() => { if (totalSelected > 0) goToStep(3); }}
                    disabled={totalSelected === 0}>
                    <span class="step-num">3</span>
                    <span class="step-label">Send</span>
                </button>
            </div>
        {/if}
    </div>

    <!-- Content -->
    <div class="content">
        {#if loading}
            <div class="center-loader">
                <div class="spinner"></div>
            </div>

        {:else if activeTab === 'list'}
            <!-- ==================== BROADCAST LIST ==================== -->
            <div class="list-container">
                {#if broadcasts.length === 0}
                    <div class="empty-state">
                        <div class="empty-icon">📣</div>
                        <h3 class="empty-title">No Broadcasts Yet</h3>
                        <p class="empty-desc">Create your first broadcast campaign</p>
                        <button class="btn-primary" on:click={startCreateBroadcast}>+ Create Broadcast</button>
                    </div>
                {:else}
                    <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                        <div class="overflow-x-auto flex-1">
                            <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                                <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                    <tr>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400 w-12">SL</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Broadcast Name</th>
                                        <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Template</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Status</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Recipients</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Pending</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">ETA</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Sent</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Delivered</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Failed</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Date</th>
                                        <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Action</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-200">
                                    {#each broadcasts as bc, index}
                                        {@const badge = getStatusBadge(bc.status)}
                                        {@const sentTotal = (bc.sent_count || 0) + (bc.delivered_count || 0) + (bc.read_count || 0)}
                                        {@const deliveredTotal = (bc.delivered_count || 0) + (bc.read_count || 0)}
                                        {@const pendingCount = bc.total_recipients - sentTotal - (bc.failed_count || 0)}
                                        {@const etaSeconds = pendingCount > 0 ? Math.ceil(pendingCount / 5) : 0}
                                        {@const etaMin = Math.floor(etaSeconds / 60)}
                                        {@const etaSec = etaSeconds % 60}
                                        {@const retryAllowed = (Date.now() - new Date(bc.created_at).getTime()) < 24 * 60 * 60 * 1000}
                                        {@const displayDate = new Date(bc.completed_at || bc.scheduled_at || bc.created_at)}
                                        <tr class="hover:bg-emerald-50/30 transition-colors duration-200 cursor-pointer {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}" on:click={() => viewBroadcastDetails(bc)}>
                                            <td class="px-4 py-3 text-sm text-center font-bold text-slate-500">{index + 1}</td>
                                            <td class="px-4 py-3 text-sm">
                                                <div class="font-bold text-slate-800">{bc.name}</div>
                                                {#if bc.last_activity}
                                                    <div class="text-[10px] mt-0.5 {bc.status === 'sending' ? 'text-orange-500 font-semibold' : bc.status === 'completed' ? 'text-emerald-500' : 'text-slate-400'}"
                                                        title="{bc.last_activity}">
                                                        {#if bc.status === 'sending'}<span class="inline-block animate-pulse mr-0.5">⚡</span>{/if}{bc.last_activity}
                                                    </div>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm">
                                                <div class="text-slate-700">{bc.wa_templates?.name || '—'}</div>
                                                <div class="text-[10px] text-slate-400 mt-0.5">{bc.wa_templates?.language?.toUpperCase() || ''}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase {badge.bg} {badge.text}">{badge.label}</span>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center font-bold text-slate-700">{bc.total_recipients}</td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <div class="font-bold {pendingCount > 0 ? 'text-amber-600' : 'text-slate-300'}">{pendingCount > 0 ? pendingCount : 0}</div>
                                                {#if pendingCount > 0}
                                                    <div class="text-[10px] text-amber-400 font-semibold">{pct(pendingCount, bc.total_recipients)}</div>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                {#if pendingCount > 0 && bc.status === 'sending'}
                                                    <div class="font-bold text-orange-600">{etaMin > 0 ? `${etaMin}m ${etaSec}s` : `${etaSec}s`}</div>
                                                    <div class="text-[10px] text-orange-400 font-semibold">~5 msg/s</div>
                                                {:else if pendingCount > 0}
                                                    <div class="font-bold text-slate-400">{etaMin > 0 ? `~${etaMin}m` : `~${etaSec}s`}</div>
                                                {:else}
                                                    <div class="font-bold text-slate-300">—</div>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <div class="font-bold text-emerald-600">{sentTotal}</div>
                                                <div class="text-[10px] text-emerald-400 font-semibold">{pct(sentTotal, bc.total_recipients)}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <div class="font-bold text-blue-600">{deliveredTotal}</div>
                                                <div class="text-[10px] text-blue-400 font-semibold">{pct(deliveredTotal, bc.total_recipients)}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <div class="font-bold {bc.failed_count ? 'text-red-600' : 'text-slate-300'}">{bc.failed_count || 0}</div>
                                                {#if bc.failed_count > 0}
                                                    <div class="text-[10px] text-red-400 font-semibold">{pct(bc.failed_count, bc.total_recipients)}</div>
                                                {/if}
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center text-slate-500">
                                                <div class="font-semibold">{String(displayDate.getDate()).padStart(2,'0')}-{String(displayDate.getMonth()+1).padStart(2,'0')}-{displayDate.getFullYear()}</div>
                                                <div class="text-[10px] text-slate-400">{bc.scheduled_at && !bc.completed_at ? '📅 ' : ''}{displayDate.toLocaleTimeString('en-US', {hour:'2-digit', minute:'2-digit', hour12:true})}</div>
                                            </td>
                                            <td class="px-4 py-3 text-sm text-center">
                                                <div class="flex items-center justify-center gap-1.5">
                                                    
                                                    <button
                                                        class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
                                                        on:click|stopPropagation={() => viewBroadcastDetails(bc)}
                                                        title="View Details"
                                                    >
                                                        👁️
                                                    </button>
                                                    <button
                                                        class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg text-xs font-bold transition-all duration-200 transform hover:scale-105
                                                            {refreshingBroadcastId === bc.id ? 'bg-blue-200 text-blue-600 cursor-wait' : 'bg-blue-500 text-white hover:bg-blue-600 hover:shadow-lg'}"
                                                        on:click|stopPropagation={() => refreshBroadcastStatus(bc)}
                                                        disabled={refreshingBroadcastId === bc.id}
                                                        title="Refresh status counts"
                                                    >
                                                        <span class={refreshingBroadcastId === bc.id ? 'animate-spin inline-block' : ''}>🔄</span>
                                                    </button>
                                                    
                                                    {#if bc.status === 'completed' && bc.failed_count > 0 && !bc.retry_attempted && (Date.now() - new Date(bc.created_at).getTime()) < 1 * 24 * 60 * 60 * 1000}
                                                        <button
                                                            class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg text-xs font-bold transition-all duration-200 transform hover:scale-105
                                                                {retryingBroadcastId === bc.id ? 'bg-amber-400 text-amber-900 cursor-wait' :
                                                                 'bg-red-500 text-white hover:bg-red-600 hover:shadow-lg'}"
                                                            on:click|stopPropagation={() => {
                                                                if (confirm(`Retry ${bc.failed_count} failed messages for "${bc.name}"?`)) retryFailedRecipients(bc);
                                                            }}
                                                            disabled={retryingBroadcastId === bc.id}
                                                            title="Retry {bc.failed_count} failed messages"
                                                        >
                                                            {#if retryingBroadcastId === bc.id}
                                                                ⏳ Retrying...
                                                            {:else}
                                                                🔁 Retry Failed ({bc.failed_count})
                                                            {/if}
                                                        </button>
                                                    {/if}

                                                    {#if bc.status === 'completed' || bc.status === 'sending'}
                                                        <button
                                                            class="inline-flex items-center justify-center px-3 py-1.5 rounded-lg text-xs font-bold transition-all duration-200 transform hover:scale-105 bg-purple-600 text-white hover:bg-purple-700 hover:shadow-lg"
                                                            on:click|stopPropagation={() => openAnalyticsModal(bc)}
                                                            title="Campaign Analytics — see how many recipients visited after this broadcast"
                                                        >
                                                            📊
                                                        </button>
                                                    {/if}
                                                </div>
                                            </td>
                                        </tr>
                                    {/each}
                                </tbody>
                            </table>
                        </div>
                        <!-- Footer with count -->
                        <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
                            📊 Showing {broadcasts.length} broadcast{broadcasts.length !== 1 ? 's' : ''}
                        </div>
                    </div>
                {/if}
            </div>

        {:else if activeTab === 'create'}
            <!-- ==================== WIZARD ==================== -->
            <div class="wizard-content">

                <!-- ===== STEP 1: SELECT TEMPLATE ===== -->
                {#if wizardStep === 1}
                    <div class="step-panel">
                        <div class="step-card">
                            <h2 class="step-title">📝 Select Template</h2>
                            <p class="step-desc">Choose an approved WhatsApp template for your broadcast message</p>

                            {#if templates.length === 0}
                                <div class="no-templates">
                                    <p class="text-slate-500 text-sm">No approved templates available.</p>
                                    <p class="text-slate-400 text-xs mt-1">Go to WA Templates to create and get templates approved by Meta.</p>
                                </div>
                            {:else}
                                <div class="template-select-row">
                                    <span class="field-label">Template</span>
                                    <div class="relative w-full">
                                        <!-- Search input -->
                                        <div class="flex items-center gap-2 border border-slate-200 rounded-xl bg-white px-3 py-2 cursor-pointer"
                                            on:click={() => templateDropdownOpen = !templateDropdownOpen}
                                            on:keydown={(e) => { if (e.key === 'Enter') templateDropdownOpen = !templateDropdownOpen; }}
                                            role="button" tabindex="0">
                                            {#if selectedTemplate && !templateDropdownOpen}
                                                <span class="text-sm text-slate-800 font-semibold flex-1">
                                                    {selectedTemplate.name}
                                                    <span class="text-[10px] ml-1 text-slate-400">({selectedTemplate.language === 'ar' ? '🇸🇦 AR' : '🇺🇸 EN'})</span>
                                                </span>
                                                <button class="text-slate-400 hover:text-red-500 text-xs" on:click|stopPropagation={() => { selectedTemplateId = ''; selectedTemplate = null; templateDropdownOpen = true; }}>✕</button>
                                            {:else}
                                                <span class="text-lg">🔍</span>
                                                <input type="text" bind:value={templateSearchQuery}
                                                    placeholder="Search templates by name..."
                                                    class="flex-1 text-sm bg-transparent outline-none border-none"
                                                    on:focus={() => templateDropdownOpen = true}
                                                    on:click|stopPropagation />
                                            {/if}
                                            <span class="text-slate-400 text-xs">{templateDropdownOpen ? '▲' : '▼'}</span>
                                        </div>

                                        <!-- Dropdown list -->
                                        {#if templateDropdownOpen}
                                            <div class="absolute z-50 w-full mt-1 bg-white border border-slate-200 rounded-xl shadow-2xl max-h-64 overflow-y-auto">
                                                {#if filteredTemplatesList.length === 0}
                                                    <div class="px-4 py-3 text-sm text-slate-400 text-center">No templates found</div>
                                                {:else}
                                                    {#each filteredTemplatesList as tmpl}
                                                        <button class="w-full text-left px-4 py-2.5 hover:bg-emerald-50 transition-colors flex items-center justify-between gap-2 border-b border-slate-50 last:border-0"
                                                            class:bg-emerald-50={selectedTemplateId === tmpl.id}
                                                            on:click={() => selectTemplate(tmpl)}>
                                                            <div class="flex-1 min-w-0">
                                                                <div class="text-sm font-bold text-slate-800 truncate">{tmpl.name}</div>
                                                                <div class="text-[10px] text-slate-400 truncate mt-0.5">{tmpl.body_text?.substring(0, 60)}...</div>
                                                            </div>
                                                            <div class="flex items-center gap-1.5 flex-shrink-0">
                                                                <span class="px-1.5 py-0.5 text-[9px] font-bold uppercase rounded-full bg-slate-100 text-slate-500">{tmpl.category}</span>
                                                                <span class="text-[10px]">{tmpl.language === 'ar' ? '🇸🇦' : '🇺🇸'}</span>
                                                            </div>
                                                        </button>
                                                    {/each}
                                                {/if}
                                            </div>
                                        {/if}
                                    </div>
                                </div>
                            {/if}

                            <!-- Template Preview -->
                            {#if selectedTemplate}
                                <div class="template-preview-box">
                                    <h3 class="preview-label">📱 Preview</h3>
                                    <div class="phone-frame">
                                        <div class="phone-screen">
                                            <div class="phone-header">
                                                <div class="phone-avatar">📣</div>
                                                <div>
                                                    <p class="phone-name">{selectedTemplate.name}</p>
                                                    <p class="phone-sub">Template Message</p>
                                                </div>
                                            </div>
                                            <div class="phone-body">
                                                <div class="msg-bubble">
                                                    {#if selectedTemplate.header_type === 'text' && selectedTemplate.header_content}
                                                        <p class="msg-header">{selectedTemplate.header_content}</p>
                                                    {:else if selectedTemplate.header_type === 'image'}
                                                        {#if selectedTemplate.header_content}
                                                            <img src={selectedTemplate.header_content} alt="Header" style="width:100%;border-radius:8px;max-height:120px;object-fit:cover;margin-bottom:6px" />
                                                        {:else}
                                                            <div class="msg-image">🖼️</div>
                                                        {/if}
                                                    {:else if selectedTemplate.header_type === 'video'}
                                                        {#if selectedTemplate.header_content}
                                                            <video src={selectedTemplate.header_content} style="width:100%;border-radius:8px;max-height:120px;object-fit:cover;margin-bottom:6px" controls muted></video>
                                                        {:else}
                                                            <div class="msg-image">🎥</div>
                                                        {/if}
                                                    {:else if selectedTemplate.header_type === 'document'}
                                                        <div style="background:#f1f5f9;border-radius:8px;padding:8px 10px;display:flex;align-items:center;gap:8px;margin-bottom:6px">
                                                            <span style="font-size:20px">📎</span>
                                                            <span style="font-size:11px;color:#475569;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
                                                                {selectedTemplate.header_content ? selectedTemplate.header_content.split('/').pop() : 'Document'}
                                                            </span>
                                                        </div>
                                                    {/if}
                                                    <p class="msg-body">{selectedTemplate.body_text || 'Template body text'}</p>
                                                    {#if selectedTemplate.footer_text}
                                                        <p class="msg-footer">{selectedTemplate.footer_text}</p>
                                                    {/if}
                                                    {#if selectedTemplate.buttons?.length}
                                                        <div class="msg-buttons">
                                                            {#each selectedTemplate.buttons as btn}
                                                                <div class="msg-btn">
                                                                    {btn.type === 'PHONE_NUMBER' ? '📞' : btn.type === 'URL' ? '🔗' : '↩️'} {btn.text}
                                                                </div>
                                                            {/each}
                                                        </div>
                                                    {/if}
                                                    <p class="msg-time">12:00</p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            {/if}
                        </div>

                        <!-- Next Button -->
                        <div class="step-actions">
                            <div></div>
                            <button class="btn-primary btn-lg" disabled={!selectedTemplate} on:click={() => goToStep(2)}>
                                Next: Select Recipients →
                            </button>
                        </div>
                    </div>

                <!-- ===== STEP 2: SELECT RECIPIENTS ===== -->
                {:else if wizardStep === 2}
                    <div class="step-panel full-height">
                        <div class="step-card flex-1">
                            <div class="recipients-header">
                                <div>
                                    <h2 class="step-title">👥 Select Recipients</h2>
                                    <p class="step-desc">Choose contacts from your customer list or import from Excel/CSV</p>
                                </div>
                                <div class="selected-count-badge">
                                    {totalSelected} selected
                                </div>
                            </div>

                            <!-- Mode Tabs -->
                            <div class="mode-tabs">
                                <button class="mode-tab" class:active={recipientMode === 'customers'}
                                    on:click={() => recipientMode = 'customers'}>
                                    👥 Customers
                                </button>
                                <button class="mode-tab" class:active={recipientMode === 'import'}
                                    on:click={() => recipientMode = 'import'}>
                                    📂 Import from Excel
                                </button>
                            </div>

                            {#if recipientMode === 'customers'}
                                <!-- Filters Bar -->
                                <div class="filters-bar">
                                    <div class="search-box">
                                        <span class="search-icon">🔍</span>
                                        <input type="text" bind:value={customerSearch} placeholder="Search by name or phone..."
                                            class="search-input" />
                                    </div>
                                    <div class="filter-group">
                                        <span class="filter-label">Last Interaction:</span>
                                        <select bind:value={filterPeriod} class="filter-select">
                                            <option value="all">All Time</option>
                                            <option value="24hr">Inside 24 Hours</option>
                                            <option value="7days">Last 7 Days</option>
                                            <option value="30days">Last 30 Days</option>
                                        </select>
                                    </div>
                                </div>

                                <!-- Customer Table -->
                                {#if loadingCustomers}
                                    <div class="center-loader mini">
                                        <div class="spinner"></div>
                                        <p class="text-xs text-slate-400 mt-2">Loading customers...</p>
                                    </div>
                                {:else}
                                    <div class="table-wrapper">
                                        <table class="recipients-table">
                                            <thead>
                                                <tr>
                                                    <th class="th-check">
                                                        <label class="checkbox-wrap">
                                                            <input type="checkbox" checked={selectAll} on:change={toggleSelectAll} />
                                                            <span class="checkmark"></span>
                                                        </label>
                                                    </th>
                                                    <th>Name</th>
                                                    <th>Phone</th>
                                                    <th>Last Interaction</th>
                                                    <th>24hr Window</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {#each filteredCustomers as c}
                                                    <tr class:selected={c.selected} on:click={() => toggleCustomer(c.phone)}>
                                                        <td class="td-check">
                                                            <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_noninteractive_element_interactions -->
                                                            <label class="checkbox-wrap" on:click|stopPropagation>
                                                                <input type="checkbox" checked={c.selected} on:change={() => toggleCustomer(c.phone)} />
                                                                <span class="checkmark"></span>
                                                            </label>
                                                        </td>
                                                        <td class="td-name">{c.name || 'Unknown'}</td>
                                                        <td class="td-phone">{c.phone}</td>
                                                        <td class="td-time">{getTimeSince(c.last_message_at)}</td>
                                                        <td class="td-window">
                                                            {#if isWithin24hr(c.last_message_at)}
                                                                <span class="window-badge inside">🟢 Inside</span>
                                                            {:else}
                                                                <span class="window-badge outside">🔴 Outside</span>
                                                            {/if}
                                                        </td>
                                                    </tr>
                                                {/each}
                                                {#if filteredCustomers.length === 0}
                                                    <tr>
                                                        <td colspan="5" class="td-empty">
                                                            {allCustomers.length === 0 ? 'No customers found' : 'No customers match filters'}
                                                        </td>
                                                    </tr>
                                                {/if}
                                            </tbody>
                                        </table>
                                    </div>
                                    <div class="table-footer">
                                        <span class="text-xs text-slate-400">
                                            Showing {filteredCustomers.length} of {allCustomers.length} customers
                                            · {selectedCustomers.length} selected
                                        </span>
                                    </div>
                                {/if}

                            {:else}
                                <!-- Import Mode -->
                                <div class="import-section">
                                    <label class="import-dropzone">
                                        <span class="import-icon">📎</span>
                                        <div>
                                            <p class="import-title">{importFileName || 'Click to upload Excel/CSV file'}</p>
                                            {#if importedPhones.length > 0}
                                                <p class="import-count">{importedPhones.length} phone numbers found</p>
                                            {:else}
                                                <p class="import-hint">Supports CSV, TXT, Excel with phone numbers</p>
                                            {/if}
                                        </div>
                                        <input type="file" accept=".csv,.txt,.xlsx" on:change={handleFileImport} class="hidden" />
                                    </label>

                                    {#if importedPhones.length > 0}
                                        <div class="imported-list">
                                            <h4 class="imported-title">Imported Numbers ({importedPhones.length})</h4>
                                            <div class="imported-grid">
                                                {#each importedPhones as phone}
                                                    <div class="imported-chip">
                                                        <span class="chip-phone">{phone}</span>
                                                        <button class="chip-remove" on:click={() => removeImportedPhone(phone)}>✕</button>
                                                    </div>
                                                {/each}
                                            </div>
                                        </div>
                                    {/if}
                                </div>
                            {/if}
                        </div>

                        <!-- Step Actions -->
                        <div class="step-actions">
                            <button class="btn-secondary" on:click={() => { wizardStep = 1; }}>
                                ← Back
                            </button>
                            <button class="btn-primary btn-lg" disabled={totalSelected === 0} on:click={() => goToStep(3)}>
                                Next: Send ({totalSelected} recipients) →
                            </button>
                        </div>
                    </div>

                <!-- ===== STEP 3: SEND / SCHEDULE ===== -->
                {:else if wizardStep === 3}
                    <div class="step-panel">
                        <div class="step-card">
                            <h2 class="step-title">🚀 Send Broadcast</h2>
                            <p class="step-desc">Name your broadcast and choose when to send</p>

                            <!-- Summary -->
                            <div class="summary-grid">
                                <div class="summary-item">
                                    <span class="summary-label">Template</span>
                                    <span class="summary-value">📝 {selectedTemplate?.name} ({selectedTemplate?.language?.toUpperCase()})</span>
                                </div>
                                <div class="summary-item">
                                    <span class="summary-label">Recipients</span>
                                    <span class="summary-value">👥 {totalSelected} contacts</span>
                                </div>
                            </div>

                            <!-- Broadcast Name -->
                            <div class="field-row">
                                <span class="field-label">Broadcast Name *</span>
                                <input type="text" bind:value={broadcastName} placeholder="e.g., Ramadan Offer 2025"
                                    class="text-input" />
                            </div>

                            <!-- Schedule -->
                            <div class="field-row">
                                <span class="field-label">When to Send</span>
                                <div class="schedule-options">
                                    <button class="schedule-btn" class:active={scheduleType === 'now'}
                                        on:click={() => scheduleType = 'now'}>
                                        <span class="schedule-icon">🚀</span>
                                        <span class="schedule-text">Send Now</span>
                                    </button>
                                    <button class="schedule-btn" class:active={scheduleType === 'schedule'}
                                        on:click={() => scheduleType = 'schedule'}>
                                        <span class="schedule-icon">📅</span>
                                        <span class="schedule-text">Schedule</span>
                                    </button>
                                </div>
                                {#if scheduleType === 'schedule'}
                                    <input type="datetime-local" bind:value={scheduledAt} class="text-input mt-3" />
                                {/if}
                            </div>
                        </div>

                        <!-- Step Actions -->
                        <div class="step-actions">
                            <button class="btn-secondary" on:click={() => { wizardStep = 2; }}>
                                ← Back
                            </button>
                            <button class="btn-send" on:click={() => sendBroadcast()}
                                disabled={sending || !broadcastName.trim() || !selectedTemplate || (scheduleType === 'schedule' && !scheduledAt)}>
                                {#if sending}
                                    ⏳ Sending...
                                {:else if scheduleType === 'schedule'}
                                    📅 Schedule Broadcast
                                {:else}
                                    🚀 Send Broadcast Now
                                {/if}
                            </button>
                        </div>
                    </div>
                {/if}
            </div>

        {:else if activeTab === 'details' && selectedBroadcast}
            <!-- ==================== BROADCAST DETAILS ==================== -->
            <div class="details-container">
                <div class="details-header-card">
                    <div class="details-top">
                        <div>
                            <h2 class="details-name">{selectedBroadcast.name}</h2>
                            <p class="details-template">📝 Template: <b>{selectedBroadcast.wa_templates?.name || '—'}</b></p>
                        </div>
                        <span class="status-badge {getStatusBadge(selectedBroadcast.status).bg} {getStatusBadge(selectedBroadcast.status).text}">
                            {getStatusBadge(selectedBroadcast.status).label}
                        </span>
                    </div>
                    <div class="details-stats">
                        <div class="detail-stat bg-slate-50"><p class="ds-num text-slate-700">{detailSummary.total_count || selectedBroadcast.total_recipients}</p><p class="ds-label">Total</p></div>
                        <div class="detail-stat bg-emerald-50"><p class="ds-num text-emerald-600">{detailSummary.sent_count}</p><p class="ds-label">Sent</p></div>
                        <div class="detail-stat bg-blue-50"><p class="ds-num text-blue-600">{detailSummary.delivered_count}</p><p class="ds-label">Delivered</p></div>
                        <div class="detail-stat bg-purple-50"><p class="ds-num text-purple-600">{detailSummary.read_count}</p><p class="ds-label">Read</p></div>
                        <div class="detail-stat bg-red-50"><p class="ds-num text-red-600">{detailSummary.failed_count}</p><p class="ds-label">Failed</p></div>
                        <div class="detail-stat bg-amber-50"><p class="ds-num text-amber-600">{detailSummary.pending_count}</p><p class="ds-label">Pending</p></div>
                    </div>
                </div>

                <!-- Status Filter Tabs -->
                <div class="flex flex-wrap gap-2 mb-3 px-1">
                    <button class="px-3 py-1.5 rounded-full text-xs font-bold transition-all {detailStatusFilter === null ? 'bg-emerald-600 text-white shadow' : 'bg-white text-slate-600 hover:bg-slate-100'}" on:click={() => setDetailStatusFilter(null)}>
                        All ({detailSummary.total_count})
                    </button>
                    <button class="px-3 py-1.5 rounded-full text-xs font-bold transition-all {detailStatusFilter === 'pending' ? 'bg-slate-600 text-white shadow' : 'bg-white text-slate-500 hover:bg-slate-100'}" on:click={() => setDetailStatusFilter('pending')}>
                        ⏳ Pending ({detailSummary.pending_count})
                    </button>
                    <button class="px-3 py-1.5 rounded-full text-xs font-bold transition-all {detailStatusFilter === 'sent' ? 'bg-emerald-600 text-white shadow' : 'bg-white text-emerald-600 hover:bg-emerald-50'}" on:click={() => setDetailStatusFilter('sent')}>
                        ✅ Sent ({detailSummary.sent_count})
                    </button>
                    <button class="px-3 py-1.5 rounded-full text-xs font-bold transition-all {detailStatusFilter === 'delivered' ? 'bg-blue-600 text-white shadow' : 'bg-white text-blue-600 hover:bg-blue-50'}" on:click={() => setDetailStatusFilter('delivered')}>
                        📬 Delivered ({detailSummary.delivered_count})
                    </button>
                    <button class="px-3 py-1.5 rounded-full text-xs font-bold transition-all {detailStatusFilter === 'read' ? 'bg-purple-600 text-white shadow' : 'bg-white text-purple-600 hover:bg-purple-50'}" on:click={() => setDetailStatusFilter('read')}>
                        👁️ Read ({detailSummary.read_count})
                    </button>
                    <button class="px-3 py-1.5 rounded-full text-xs font-bold transition-all {detailStatusFilter === 'failed' ? 'bg-red-600 text-white shadow' : 'bg-white text-red-600 hover:bg-red-50'}" on:click={() => setDetailStatusFilter('failed')}>
                        ❌ Failed ({detailSummary.failed_count})
                    </button>
                </div>

                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
                    {#if detailLoading}
                        <div class="flex items-center justify-center py-12">
                            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"></div>
                            <span class="ml-3 text-slate-500 text-sm">Loading recipients...</span>
                        </div>
                    {:else}
                    <div class="overflow-x-auto flex-1">
                        <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                            <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                <tr>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Phone</th>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Name</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Status</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Sent At</th>
                                    <th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">Error Details</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-200">
                                {#each detailRecipients as r, index}
                                    <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                        <td class="px-4 py-3 text-sm font-mono text-slate-700">{r.phone_number}</td>
                                        <td class="px-4 py-3 text-sm text-slate-700">{r.customer_name || '-'}</td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            <span class="inline-block px-2.5 py-1 rounded-full text-[10px] font-black uppercase
                                                {r.status === 'sent' ? 'bg-emerald-100 text-emerald-600' :
                                                 r.status === 'delivered' ? 'bg-blue-100 text-blue-600' :
                                                 r.status === 'read' ? 'bg-purple-100 text-purple-600' :
                                                 r.status === 'failed' ? 'bg-red-100 text-red-600' :
                                                 'bg-slate-100 text-slate-500'}">
                                                {r.status === 'sent' ? '✅ Sent' :
                                                 r.status === 'delivered' ? '📬 Delivered' :
                                                 r.status === 'read' ? '👁️ Read' :
                                                 r.status === 'failed' ? '❌ Failed' :
                                                 '⏳ ' + r.status}
                                            </span>
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center text-slate-500">{r.sent_at ? new Date(r.sent_at).toLocaleString() : '-'}</td>
                                        <td class="px-4 py-3 text-sm">
                                            {#if r.status === 'failed' && r.error_details}
                                                <span class="text-red-600 text-xs font-semibold">⚠️ {r.error_details}</span>
                                            {:else}
                                                <span class="text-slate-300">—</span>
                                            {/if}
                                        </td>
                                    </tr>
                                {/each}
                                {#if detailRecipients.length === 0}
                                    <tr><td colspan="5" class="px-4 py-8 text-center text-slate-400 text-sm">No recipients found</td></tr>
                                {/if}
                            </tbody>
                        </table>
                    </div>
                    {/if}
                    <!-- Pagination Footer -->
                    <div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 flex items-center justify-between text-xs text-slate-600 font-semibold">
                        <span>
                            📊 Showing {detailPage * detailPageSize + 1}–{Math.min((detailPage + 1) * detailPageSize, detailTotalFiltered)} of {detailTotalFiltered}
                            {#if detailStatusFilter}
                                ({detailStatusFilter})
                            {/if}
                        </span>
                        <div class="flex gap-2">
                            <button class="px-3 py-1 rounded bg-white border border-slate-300 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                                disabled={detailPage === 0} on:click={detailPrevPage}>
                                ← Prev
                            </button>
                            <span class="px-2 py-1 text-slate-500">Page {detailPage + 1} / {Math.max(1, Math.ceil(detailTotalFiltered / detailPageSize))}</span>
                            <button class="px-3 py-1 rounded bg-white border border-slate-300 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                                disabled={(detailPage + 1) * detailPageSize >= detailTotalFiltered} on:click={detailNextPage}>
                                Next →
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        {/if}
    </div>

    <!-- ==================== ANALYTICS MODAL ==================== -->
    {#if analyticsModal && analyticsBroadcast}
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="analytics-overlay" on:click|self={() => { analyticsModal = false; }}>
            <div class="analytics-modal">
                <!-- Header -->
                <div class="analytics-header">
                    <div>
                        <div class="analytics-title">📊 Campaign Analytics</div>
                        <div class="analytics-subtitle">{analyticsBroadcast.name}</div>
                    </div>
                    <button class="analytics-close" on:click={() => { analyticsModal = false; }}>✕</button>
                </div>

                <!-- Date selector -->
                <div class="analytics-body">
                    <div class="analytics-info-row">
                        <div class="analytics-info-item">
                            <span class="analytics-info-label">📅 Broadcast Date</span>
                            <span class="analytics-info-value">{fmtAnalyticsDate(analyticsBroadcast.created_at)}</span>
                        </div>
                        <div class="analytics-info-item">
                            <span class="analytics-info-label">👥 Reached Recipients</span>
                            <span class="analytics-info-value">{analyticsRecipientPhones.length === 0 ? '⏳ Loading...' : analyticsRecipientPhones.length.toLocaleString()}</span>
                        </div>
                    </div>

                    <div class="analytics-date-row">
                        <!-- svelte-ignore a11y-label-has-associated-control -->
                        <label class="analytics-date-label">Measure visits/purchases up to:</label>
                        <div class="analytics-date-inputs">
                            <input
                                type="date"
                                class="analytics-date-input"
                                bind:value={analyticsDateTo}
                                min={analyticsBroadcast.created_at?.split('T')[0] || ''}
                                max={new Date().toISOString().split('T')[0]}
                            />
                            <button
                                class="analytics-run-btn"
                                disabled={analyticsLoading || analyticsRecipientPhones.length === 0}
                                on:click={runBroadcastAnalytics}
                            >
                                {analyticsLoading ? '⏳ Analyzing...' : '🔍 Analyze'}
                            </button>
                        </div>
                    </div>

                    {#if analyticsError}
                        <div class="analytics-error">{analyticsError}</div>
                    {/if}

                    {#if analyticsLoading}
                        <div class="analytics-loading">
                            <div class="spinner"></div>
                            <p class="mt-4 text-slate-500 text-sm">Querying ERP branches for bill activity...</p>
                        </div>
                    {/if}

                    {#if analyticsResult && !analyticsLoading}
                        <!-- Summary cards -->
                        <div class="analytics-summary-grid">
                            <div class="analytics-card analytics-card-total">
                                <div class="analytics-card-icon">👥</div>
                                <div class="analytics-card-value">{analyticsResult.totalRecipients.toLocaleString()}</div>
                                <div class="analytics-card-label">Total Recipients</div>
                            </div>
                            <div class="analytics-card analytics-card-visited">
                                <div class="analytics-card-icon">🛍️</div>
                                <div class="analytics-card-value">{analyticsResult.visitedCount.toLocaleString()}</div>
                                <div class="analytics-card-label">Visited &amp; Purchased</div>
                            </div>
                            <div class="analytics-card analytics-card-notvisited">
                                <div class="analytics-card-icon">💤</div>
                                <div class="analytics-card-value">{analyticsResult.notVisitedCount.toLocaleString()}</div>
                                <div class="analytics-card-label">No Purchase</div>
                            </div>
                            <div class="analytics-card analytics-card-conversion">
                                <div class="analytics-card-icon">🎯</div>
                                <div class="analytics-card-value">{analyticsResult.conversionPct}%</div>
                                <div class="analytics-card-label">Conversion Rate</div>
                            </div>
                        </div>

                        <!-- Conversion bar -->
                        <div class="analytics-bar-wrap">
                            <div class="analytics-bar-track">
                                <div
                                    class="analytics-bar-fill"
                                    style="width: {analyticsResult.conversionPct}%"
                                ></div>
                            </div>
                            <div class="analytics-bar-labels">
                                <span class="text-emerald-600 font-bold text-xs">{analyticsResult.visitedCount} purchased</span>
                                <span class="text-slate-400 text-xs">{analyticsResult.branchCount} branch{analyticsResult.branchCount !== 1 ? 'es' : ''} checked</span>
                                <span class="text-slate-500 font-bold text-xs">{analyticsResult.notVisitedCount} no purchase</span>
                            </div>
                        </div>

                        <!-- Per-customer detail table (visitors only) -->
                        {#if analyticsResult.visitedCount > 0}
                            <div class="analytics-detail-section">
                                <div class="analytics-detail-title">🛍️ Customers Who Purchased</div>
                                <div class="analytics-detail-table-wrap">
                                    <table class="analytics-detail-table">
                                        <thead>
                                            <tr>
                                                <th>#</th>
                                                <th>Phone</th>
                                                <th>Bills in Period</th>
                                                <th>Total Spent</th>
                                                <th>Last Visit</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {#each analyticsRecipientPhones.filter(p => analyticsResult && analyticsResult.perPhone[p]?.billCount > 0) as phone, idx}
                                                {@const row = analyticsResult.perPhone[phone]}
                                                <tr>
                                                    <td class="text-slate-400">{idx + 1}</td>
                                                    <td class="font-mono text-sm">{phone}</td>
                                                    <td class="text-emerald-600 font-bold">{row.billCount}</td>
                                                    <td class="text-emerald-700 font-bold">{row.totalAmount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</td>
                                                    <td class="text-slate-500 text-xs">{fmtAnalyticsDate(row.lastBillDate)}</td>
                                                </tr>
                                            {/each}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        {/if}
                    {/if}
                </div>
            </div>
        </div>
    {/if}
</div>

<style>
    /* ===== Base Layout ===== */
    .wa-broadcasts {
        height: 100%;
        display: flex;
        flex-direction: column;
        background: #f8fafc;
        overflow: hidden;
        font-family: system-ui, -apple-system, sans-serif;
    }

    /* ===== Header ===== */
    .header {
        background: white;
        border-bottom: 1px solid #e2e8f0;
        padding: 16px 24px;
    }
    .header-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
    }
    .header-left {
        display: flex;
        align-items: center;
        gap: 12px;
    }
    .header-icon { font-size: 1.5rem; }
    .header-title {
        font-size: 1.1rem;
        font-weight: 900;
        color: #1e293b;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    /* ===== Buttons ===== */
    .btn-primary {
        padding: 10px 24px;
        background: #059669;
        color: white;
        font-weight: 700;
        font-size: 0.75rem;
        border-radius: 12px;
        border: none;
        cursor: pointer;
        transition: all 0.2s;
        box-shadow: 0 4px 12px rgba(5, 150, 105, 0.2);
    }
    .btn-primary:hover { background: #047857; }
    .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
    .btn-lg { padding: 14px 32px; font-size: 0.8rem; }

    .btn-secondary {
        padding: 10px 24px;
        background: #f1f5f9;
        color: #475569;
        font-weight: 700;
        font-size: 0.75rem;
        border-radius: 12px;
        border: none;
        cursor: pointer;
        transition: all 0.2s;
    }
    .btn-secondary:hover { background: #e2e8f0; }

    .btn-back {
        padding: 8px 16px;
        background: #f1f5f9;
        color: #475569;
        font-weight: 700;
        font-size: 0.7rem;
        border-radius: 10px;
        border: none;
        cursor: pointer;
    }
    .btn-back:hover { background: #e2e8f0; }

    .btn-send {
        padding: 14px 40px;
        background: linear-gradient(135deg, #059669, #10b981);
        color: white;
        font-weight: 900;
        font-size: 0.85rem;
        border-radius: 14px;
        border: none;
        cursor: pointer;
        transition: all 0.2s;
        box-shadow: 0 6px 20px rgba(5, 150, 105, 0.3);
    }
    .btn-send:hover { transform: translateY(-1px); box-shadow: 0 8px 25px rgba(5, 150, 105, 0.4); }
    .btn-send:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }

    /* ===== Wizard Steps ===== */
    .wizard-steps {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0;
        margin-top: 16px;
        padding: 0 20px;
    }
    .wizard-step {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px 16px;
        background: none;
        border: 2px solid #e2e8f0;
        border-radius: 10px;
        cursor: pointer;
        transition: all 0.2s;
        color: #94a3b8;
    }
    .wizard-step:disabled { cursor: not-allowed; opacity: 0.5; }
    .wizard-step.active {
        border-color: #059669;
        background: #ecfdf5;
        color: #059669;
    }
    .wizard-step.completed {
        border-color: #059669;
        background: #059669;
        color: white;
    }
    .step-num {
        width: 24px;
        height: 24px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 50%;
        font-size: 0.7rem;
        font-weight: 900;
        background: #e2e8f0;
        color: #64748b;
    }
    .wizard-step.active .step-num { background: #059669; color: white; }
    .wizard-step.completed .step-num { background: white; color: #059669; }
    .step-label { font-size: 0.7rem; font-weight: 700; }
    .step-connector {
        width: 40px;
        height: 2px;
        background: #e2e8f0;
        transition: background 0.3s;
    }
    .step-connector.active { background: #059669; }

    /* ===== Content ===== */
    .content { flex: 1; overflow: hidden; }
    .center-loader {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        height: 100%;
    }
    .center-loader.mini { height: 200px; }
    .spinner {
        width: 40px;
        height: 40px;
        border: 4px solid #d1fae5;
        border-top-color: #059669;
        border-radius: 50%;
        animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }

    /* ===== List View ===== */
    .list-container { padding: 24px; overflow-y: auto; height: 100%; }
    .empty-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 80px 0;
    }
    .empty-icon { font-size: 3rem; margin-bottom: 16px; }
    .empty-title { font-size: 1.1rem; font-weight: 700; color: #475569; }
    .empty-desc { font-size: 0.8rem; color: #94a3b8; margin-top: 4px; }

    .card-date { font-size: 0.75rem; color: #94a3b8; }

    .status-badge {
        padding: 4px 12px;
        font-size: 0.7rem;
        font-weight: 700;
        border-radius: 9999px;
    }
    .status-badge-sm {
        padding: 2px 8px;
        font-size: 0.6rem;
        font-weight: 700;
        border-radius: 9999px;
    }

    /* ===== Wizard Content ===== */
    .wizard-content {
        height: 100%;
        overflow: hidden;
    }
    .step-panel {
        display: flex;
        flex-direction: column;
        height: 100%;
        padding: 24px;
        overflow-y: auto;
        gap: 20px;
    }
    .step-panel.full-height { padding-bottom: 0; }
    .step-card {
        background: rgba(255,255,255,0.6);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255,255,255,0.4);
        border-radius: 16px;
        padding: 24px;
    }
    .step-card.flex-1 { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
    .step-title { font-size: 1rem; font-weight: 900; color: #1e293b; }
    .step-desc { font-size: 0.75rem; color: #64748b; margin-top: 4px; }

    .step-actions {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 16px 0;
        flex-shrink: 0;
    }

    /* ===== Step 1: Templates ===== */
    .no-templates { padding: 40px 0; text-align: center; }
    .template-select-row { margin-top: 20px; }
    .field-label {
        display: block;
        font-size: 0.7rem;
        font-weight: 700;
        color: #475569;
        text-transform: uppercase;
        margin-bottom: 8px;
    }
    .select-input {
        width: 100%;
        padding: 12px 16px;
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        font-size: 0.85rem;
        color: #1e293b;
        cursor: pointer;
        appearance: auto;
    }
    .select-input:focus { outline: none; border-color: #059669; box-shadow: 0 0 0 3px rgba(5, 150, 105, 0.15); }

    .template-preview-box {
        margin-top: 24px;
        padding-top: 20px;
        border-top: 1px solid #e2e8f0;
    }
    .preview-label { font-size: 0.7rem; font-weight: 700; color: #475569; text-transform: uppercase; margin-bottom: 12px; }

    .phone-frame {
        background: #1a1a2e;
        border-radius: 2rem;
        padding: 12px;
        max-width: 280px;
        margin: 0 auto;
        box-shadow: 0 10px 40px rgba(0,0,0,0.15);
    }
    .phone-screen {
        background: #ECE5DD;
        border-radius: 1.5rem;
        overflow: hidden;
    }
    .phone-header {
        background: #128C7E;
        color: white;
        padding: 10px 16px;
        display: flex;
        align-items: center;
        gap: 8px;
    }
    .phone-avatar {
        width: 28px;
        height: 28px;
        background: rgba(255,255,255,0.2);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 0.65rem;
    }
    .phone-name { font-size: 0.65rem; font-weight: 700; }
    .phone-sub { font-size: 0.5rem; opacity: 0.7; }
    .phone-body { padding: 12px; min-height: 160px; }
    .msg-bubble {
        background: white;
        border-radius: 12px;
        border-top-left-radius: 0;
        padding: 10px 12px;
        box-shadow: 0 1px 2px rgba(0,0,0,0.05);
        max-width: 220px;
    }
    .msg-header { font-size: 0.65rem; font-weight: 700; color: #1e293b; margin-bottom: 4px; }
    .msg-image {
        background: #e2e8f0;
        border-radius: 8px;
        height: 80px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 1.2rem;
        margin-bottom: 4px;
    }
    .msg-body { font-size: 0.65rem; color: #334155; white-space: pre-wrap; }
    .msg-footer { font-size: 0.55rem; color: #94a3b8; margin-top: 4px; font-style: italic; }
    .msg-buttons { margin-top: 8px; border-top: 1px solid #f1f5f9; padding-top: 6px; display: flex; flex-direction: column; gap: 4px; }
    .msg-btn {
        text-align: center;
        padding: 4px;
        font-size: 0.55rem;
        color: #3b82f6;
        font-weight: 700;
        border: 1px solid #dbeafe;
        border-radius: 6px;
        background: rgba(59, 130, 246, 0.03);
    }
    .msg-time { font-size: 0.5rem; color: #94a3b8; text-align: right; margin-top: 4px; }

    /* ===== Step 2: Recipients ===== */
    .recipients-header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        margin-bottom: 16px;
    }
    .selected-count-badge {
        padding: 6px 16px;
        background: #059669;
        color: white;
        font-size: 0.75rem;
        font-weight: 800;
        border-radius: 9999px;
    }

    .mode-tabs {
        display: flex;
        gap: 4px;
        background: #f1f5f9;
        padding: 4px;
        border-radius: 12px;
        margin-bottom: 16px;
    }
    .mode-tab {
        flex: 1;
        padding: 8px 16px;
        font-size: 0.75rem;
        font-weight: 700;
        border: none;
        border-radius: 10px;
        background: transparent;
        color: #64748b;
        cursor: pointer;
        transition: all 0.2s;
    }
    .mode-tab.active {
        background: white;
        color: #1e293b;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
    }

    .filters-bar {
        display: flex;
        gap: 12px;
        align-items: center;
        margin-bottom: 12px;
        flex-wrap: wrap;
    }
    .search-box {
        flex: 1;
        min-width: 200px;
        position: relative;
    }
    .search-icon {
        position: absolute;
        left: 12px;
        top: 50%;
        transform: translateY(-50%);
        font-size: 0.8rem;
    }
    .search-input {
        width: 100%;
        padding: 10px 12px 10px 36px;
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        border-radius: 10px;
        font-size: 0.8rem;
        color: #1e293b;
    }
    .search-input:focus { outline: none; border-color: #059669; }

    .filter-group { display: flex; align-items: center; gap: 8px; }
    .filter-label { font-size: 0.7rem; font-weight: 600; color: #64748b; white-space: nowrap; }
    .filter-select {
        padding: 10px 12px;
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        border-radius: 10px;
        font-size: 0.8rem;
        color: #1e293b;
        cursor: pointer;
    }
    .filter-select:focus { outline: none; border-color: #059669; }

    /* Table */
    .table-wrapper {
        flex: 1;
        overflow-y: auto;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        background: white;
    }
    .recipients-table {
        width: 100%;
        font-size: 0.8rem;
        border-collapse: collapse;
    }
    .recipients-table thead {
        position: sticky;
        top: 0;
        z-index: 1;
    }
    .recipients-table th {
        padding: 10px 14px;
        text-align: left;
        font-size: 0.65rem;
        font-weight: 700;
        text-transform: uppercase;
        color: #94a3b8;
        background: #f8fafc;
        border-bottom: 1px solid #e2e8f0;
    }
    .recipients-table td {
        padding: 10px 14px;
        border-bottom: 1px solid #f1f5f9;
    }
    .recipients-table tbody tr {
        cursor: pointer;
        transition: background 0.15s;
    }
    .recipients-table tbody tr:hover { background: #f0fdf4; }
    .recipients-table tbody tr.selected { background: #ecfdf5; }

    .th-check, .td-check { width: 40px; text-align: center; }
    .td-name { font-weight: 600; color: #1e293b; }
    .td-phone { font-family: monospace; font-size: 0.75rem; color: #475569; }
    .td-time { font-size: 0.75rem; color: #94a3b8; }
    .td-empty { text-align: center; padding: 40px 14px !important; color: #94a3b8; font-size: 0.8rem; }

    .window-badge {
        padding: 2px 10px;
        font-size: 0.6rem;
        font-weight: 700;
        border-radius: 9999px;
    }
    .window-badge.inside { background: #d1fae5; color: #065f46; }
    .window-badge.outside { background: #fee2e2; color: #991b1b; }

    .checkbox-wrap {
        position: relative;
        display: inline-block;
        width: 18px;
        height: 18px;
        cursor: pointer;
    }
    .checkbox-wrap input {
        position: absolute;
        opacity: 0;
        width: 100%;
        height: 100%;
        top: 0;
        left: 0;
        cursor: pointer;
        z-index: 1;
    }
    .checkmark {
        position: absolute;
        top: 0; left: 0;
        width: 18px;
        height: 18px;
        background: white;
        border: 2px solid #cbd5e1;
        border-radius: 5px;
        transition: all 0.15s;
    }
    .checkbox-wrap input:checked ~ .checkmark {
        background: #059669;
        border-color: #059669;
    }
    .checkbox-wrap input:checked ~ .checkmark::after {
        content: '✓';
        position: absolute;
        top: 50%; left: 50%;
        transform: translate(-50%, -50%);
        color: white;
        font-size: 0.6rem;
        font-weight: 900;
    }

    .table-footer {
        padding: 8px 14px;
        border-top: 1px solid #e2e8f0;
        flex-shrink: 0;
    }

    /* Import */
    .import-section { margin-top: 8px; }
    .import-dropzone {
        display: flex;
        align-items: center;
        gap: 16px;
        padding: 20px;
        border: 2px dashed #cbd5e1;
        border-radius: 14px;
        cursor: pointer;
        transition: border-color 0.2s;
    }
    .import-dropzone:hover { border-color: #059669; }
    .import-icon { font-size: 1.5rem; }
    .import-title { font-size: 0.8rem; font-weight: 700; color: #475569; }
    .import-count { font-size: 0.65rem; font-weight: 700; color: #059669; }
    .import-hint { font-size: 0.65rem; color: #94a3b8; }

    .imported-list { margin-top: 20px; }
    .imported-title { font-size: 0.75rem; font-weight: 700; color: #475569; margin-bottom: 12px; }
    .imported-grid {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        max-height: 300px;
        overflow-y: auto;
    }
    .imported-chip {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 6px 12px;
        background: #f1f5f9;
        border-radius: 8px;
    }
    .chip-phone { font-size: 0.75rem; font-family: monospace; color: #334155; }
    .chip-remove {
        background: none;
        border: none;
        color: #94a3b8;
        font-size: 0.65rem;
        cursor: pointer;
        padding: 0;
    }
    .chip-remove:hover { color: #ef4444; }

    /* ===== Step 3: Send ===== */
    .summary-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 12px;
        margin: 20px 0;
    }
    .summary-item {
        background: #f8fafc;
        border-radius: 12px;
        padding: 14px 18px;
    }
    .summary-label { font-size: 0.6rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; }
    .summary-value { display: block; margin-top: 4px; font-size: 0.85rem; font-weight: 700; color: #1e293b; }

    .field-row { margin-top: 20px; }
    .text-input {
        width: 100%;
        padding: 12px 16px;
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        font-size: 0.85rem;
        color: #1e293b;
    }
    .text-input:focus { outline: none; border-color: #059669; box-shadow: 0 0 0 3px rgba(5, 150, 105, 0.15); }

    .schedule-options { display: flex; gap: 12px; }
    .schedule-btn {
        flex: 1;
        padding: 14px;
        border: 2px solid #e2e8f0;
        border-radius: 14px;
        background: none;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        transition: all 0.2s;
    }
    .schedule-btn.active { border-color: #059669; background: #ecfdf5; }
    .schedule-btn:hover { border-color: #a7f3d0; }
    .schedule-icon { font-size: 1.2rem; }
    .schedule-text { font-size: 0.8rem; font-weight: 700; color: #334155; }

    .mt-3 { margin-top: 12px; }

    /* ===== Details View ===== */
    .details-container { padding: 24px; overflow-y: auto; height: 100%; }
    .details-header-card {
        background: rgba(255,255,255,0.6);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255,255,255,0.4);
        border-radius: 16px;
        padding: 24px;
        margin-bottom: 24px;
    }
    .details-top { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 16px; }
    .details-name { font-size: 1.1rem; font-weight: 900; color: #1e293b; }
    .details-template { font-size: 0.75rem; color: #64748b; margin-top: 4px; }
    .details-stats { display: grid; grid-template-columns: repeat(5, 1fr); gap: 16px; }
    .detail-stat { border-radius: 12px; padding: 12px; text-align: center; }
    .ds-num { font-size: 1.2rem; font-weight: 900; }
    .ds-label { font-size: 0.6rem; text-transform: uppercase; font-weight: 700; color: #64748b; }

    .details-recipients-card {
        background: rgba(255,255,255,0.6);
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255,255,255,0.4);
        border-radius: 16px;
        padding: 20px;
    }
    .details-recipients-title { font-size: 0.7rem; font-weight: 700; color: #475569; text-transform: uppercase; margin-bottom: 12px; }

    /* Tailwind-like utility classes used in template */
    .hidden { display: none; }
    .bg-slate-50 { background-color: #f8fafc; }
    .bg-slate-100 { background-color: #f1f5f9; }
    .bg-emerald-50 { background-color: #ecfdf5; }
    .bg-emerald-100 { background-color: #d1fae5; }
    .bg-blue-50 { background-color: #eff6ff; }
    .bg-blue-100 { background-color: #dbeafe; }
    .bg-purple-50 { background-color: #faf5ff; }
    .bg-purple-100 { background-color: #f3e8ff; }
    .bg-red-50 { background-color: #fef2f2; }
    .bg-red-100 { background-color: #fee2e2; }
    .bg-amber-100 { background-color: #fef3c7; }

    .text-slate-500 { color: #64748b; }
    .text-slate-600 { color: #475569; }
    .text-slate-700 { color: #334155; }
    .text-emerald-600 { color: #059669; }
    .text-blue-600 { color: #2563eb; }
    .text-purple-600 { color: #9333ea; }
    .text-red-600 { color: #dc2626; }
    .text-amber-600 { color: #d97706; }

    /* ===== Analytics Modal ===== */
    .analytics-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.55);
        backdrop-filter: blur(4px);
        z-index: 9999;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
    }
    .analytics-modal {
        background: #fff;
        border-radius: 20px;
        width: 100%;
        max-width: 860px;
        max-height: 88vh;
        display: flex;
        flex-direction: column;
        box-shadow: 0 30px 80px rgba(0,0,0,0.25);
        overflow: hidden;
    }
    .analytics-header {
        padding: 20px 24px;
        background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
        color: white;
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        flex-shrink: 0;
    }
    .analytics-title { font-size: 1.1rem; font-weight: 900; }
    .analytics-subtitle { font-size: 0.8rem; opacity: 0.85; margin-top: 2px; }
    .analytics-close {
        background: rgba(255,255,255,0.2);
        border: none;
        color: white;
        width: 32px; height: 32px;
        border-radius: 50%;
        font-size: 1rem;
        cursor: pointer;
        display: flex; align-items: center; justify-content: center;
        transition: background 0.2s;
        flex-shrink: 0;
    }
    .analytics-close:hover { background: rgba(255,255,255,0.35); }

    .analytics-body {
        padding: 24px;
        overflow-y: auto;
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 20px;
    }
    .analytics-info-row {
        display: flex;
        gap: 16px;
        flex-wrap: wrap;
    }
    .analytics-info-item {
        flex: 1;
        min-width: 160px;
        background: #f8fafc;
        border-radius: 12px;
        padding: 12px 16px;
    }
    .analytics-info-label { display: block; font-size: 0.7rem; color: #64748b; font-weight: 600; text-transform: uppercase; margin-bottom: 4px; }
    .analytics-info-value { font-size: 1rem; font-weight: 900; color: #1e293b; }

    .analytics-date-row {
        display: flex;
        align-items: center;
        gap: 12px;
        flex-wrap: wrap;
    }
    .analytics-date-label { font-size: 0.8rem; font-weight: 700; color: #475569; white-space: nowrap; }
    .analytics-date-inputs { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
    .analytics-date-input {
        padding: 8px 14px;
        border: 2px solid #e2e8f0;
        border-radius: 10px;
        font-size: 0.85rem;
        color: #1e293b;
        background: #f8fafc;
        transition: border-color 0.2s;
    }
    .analytics-date-input:focus { outline: none; border-color: #7c3aed; }
    .analytics-run-btn {
        padding: 9px 22px;
        background: linear-gradient(135deg, #4f46e5, #7c3aed);
        color: white;
        font-weight: 700;
        font-size: 0.8rem;
        border: none;
        border-radius: 10px;
        cursor: pointer;
        transition: all 0.2s;
        box-shadow: 0 4px 12px rgba(124, 58, 237, 0.3);
        white-space: nowrap;
    }
    .analytics-run-btn:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 6px 18px rgba(124, 58, 237, 0.4); }
    .analytics-run-btn:disabled { opacity: 0.5; cursor: not-allowed; }

    .analytics-error {
        background: #fef2f2;
        border: 1px solid #fecaca;
        color: #dc2626;
        border-radius: 10px;
        padding: 10px 16px;
        font-size: 0.8rem;
        font-weight: 600;
    }
    .analytics-loading {
        display: flex;
        flex-direction: column;
        align-items: center;
        padding: 40px;
    }

    .analytics-summary-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 14px;
    }
    @media (max-width: 560px) {
        .analytics-summary-grid { grid-template-columns: repeat(2, 1fr); }
    }
    .analytics-card {
        border-radius: 14px;
        padding: 18px 14px;
        text-align: center;
        border: 2px solid transparent;
    }
    .analytics-card-icon { font-size: 1.5rem; margin-bottom: 6px; }
    .analytics-card-value { font-size: 1.5rem; font-weight: 900; line-height: 1; margin-bottom: 4px; }
    .analytics-card-label { font-size: 0.65rem; font-weight: 700; text-transform: uppercase; color: #64748b; }
    .analytics-card-total { background: #f1f5f9; border-color: #cbd5e1; }
    .analytics-card-total .analytics-card-value { color: #1e293b; }
    .analytics-card-visited { background: #ecfdf5; border-color: #6ee7b7; }
    .analytics-card-visited .analytics-card-value { color: #059669; }
    .analytics-card-notvisited { background: #fff7ed; border-color: #fed7aa; }
    .analytics-card-notvisited .analytics-card-value { color: #c2410c; }
    .analytics-card-conversion { background: #ede9fe; border-color: #c4b5fd; }
    .analytics-card-conversion .analytics-card-value { color: #7c3aed; }

    .analytics-bar-wrap { display: flex; flex-direction: column; gap: 6px; }
    .analytics-bar-track {
        height: 12px;
        background: #f1f5f9;
        border-radius: 999px;
        overflow: hidden;
    }
    .analytics-bar-fill {
        height: 100%;
        background: linear-gradient(90deg, #059669, #10b981);
        border-radius: 999px;
        transition: width 0.6s ease;
    }
    .analytics-bar-labels {
        display: flex;
        justify-content: space-between;
        flex-wrap: wrap;
        gap: 4px;
    }

    .analytics-detail-section { display: flex; flex-direction: column; gap: 10px; }
    .analytics-detail-title { font-size: 0.85rem; font-weight: 800; color: #1e293b; }
    .analytics-detail-table-wrap {
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        overflow: hidden;
        max-height: 280px;
        overflow-y: auto;
    }
    .analytics-detail-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 0.8rem;
    }
    .analytics-detail-table th {
        padding: 8px 12px;
        background: #f8fafc;
        border-bottom: 1px solid #e2e8f0;
        font-size: 0.65rem;
        font-weight: 700;
        text-transform: uppercase;
        color: #64748b;
        text-align: left;
        position: sticky;
        top: 0;
    }
    .analytics-detail-table td {
        padding: 8px 12px;
        border-bottom: 1px solid #f1f5f9;
        color: #334155;
    }
    .analytics-detail-table tbody tr:hover { background: #f0fdf4; }
    .analytics-detail-table tbody tr:last-child td { border-bottom: none; }
</style>
