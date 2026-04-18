<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { getEdgeFunctionUrl } from '$lib/utils/supabase';
    import { currentUser } from '$lib/utils/persistentAuth';
    import ReportIncident from '../../../../routes/mobile-interface/report-incident/+page.svelte';

    export let initialPhone: string = '';

    interface Conversation {
        id: string;
        customer_phone: string;
        customer_name: string;
        last_message_at: string;
        last_message_preview: string;
        unread_count: number;
        is_bot_handling: boolean;
        bot_type: string | null;
        handled_by: string | null;
        needs_human: boolean;
        status: string;
        is_inside_24hr: boolean;
        is_sos: boolean;
    }

    interface Message {
        id: string;
        direction: string;
        message_type: string;
        content: string;
        media_url: string | null;
        media_mime_type: string | null;
        template_name: string | null;
        status: string;
        sent_by: string;
        sent_by_user_id: string | null;
        metadata: any;
        created_at: string;
    }

    // Cache for user display names
    let userNameCache: Record<string, string> = {};

    // Generate a consistent HSL color from a string (name or phone)
    function avatarColor(str: string): string {
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            hash = str.charCodeAt(i) + ((hash << 5) - hash);
        }
        const hue = ((hash % 360) + 360) % 360;
        return `hsl(${hue}, 55%, 45%)`;
    }

    interface WATemplate {
        id: string;
        name: string;
        body_text: string;
        language: string;
        status: string;
    }

    let supabase: any = null;
    let conversations: Conversation[] = [];
    let filteredConversations: Conversation[] = [];
    let priorityConversations: Conversation[] = [];
    let messages: Message[] = [];
    let templates: WATemplate[] = [];
    let loading = true;
    let loadingMessages = false;
    let sending = false;
    let accountId = '';
    let selectedConv: Conversation | null = null;
    let searchQuery = '';
    let chatFilter = 'all'; // all, unread, ai, bot, human
    let messageInput = '';
    let showTemplatePicker = false;
    let refreshInterval: any;
    let messagesContainer: HTMLElement;

    // Pagination for conversations
    const CONV_PAGE_SIZE = 50;
    let convPage = 0;
    let convTotalCount = 0;
    let loadingMoreConvs = false;
    let convListContainer: HTMLElement;

    // Pagination for messages
    const MSG_PAGE_SIZE = 50;
    let hasMoreMessages = false;
    let loadingOlderMessages = false;

    // Realtime subscriptions
    let convSubscription: any = null;
    let msgSubscription: any = null;

    // Debounce for search
    let searchDebounceTimer: any = null;

    // Audio recording
    let isRecording = false;
    let mediaRecorder: MediaRecorder | null = null;
    let audioChunks: Blob[] = [];
    let recordingDuration = 0;
    let recordingTimer: any = null;

    // File inputs
    let imageInput: HTMLInputElement;
    let fileInput: HTMLInputElement;
    let showAttachMenu = false;
    let showIncidentPopup = false;

    // Input text transform & translate
    let isInputTransforming = false;
    let showInputTranslatePicker = false;
    let inputTranslateLangSearch = '';
    let isInputTranslating = false;

    $: filteredInputTranslateLangs = translateLanguages.filter(l =>
        !inputTranslateLangSearch || l.name.toLowerCase().includes(inputTranslateLangSearch.toLowerCase()) || l.code.includes(inputTranslateLangSearch.toLowerCase())
    );

    // Translation
    let translatedMessages: Record<string, string> = {};
    let translatingMsgId: string | null = null;
    let showTranslateLangPicker = false;
    let translateTargetMsgId: string | null = null;
    let translateLangSearch = '';

    const translateLanguages = [
        { code: 'en', name: 'English', flag: '🇺🇸' },
        { code: 'ar', name: 'Arabic', flag: '🇸🇦' },
        { code: 'hi', name: 'Hindi', flag: '🇮🇳' },
        { code: 'ur', name: 'Urdu', flag: '🇵🇰' },
        { code: 'bn', name: 'Bengali', flag: '🇧🇩' },
        { code: 'tl', name: 'Filipino', flag: '🇵🇭' },
        { code: 'ne', name: 'Nepali', flag: '🇳🇵' },
        { code: 'ta', name: 'Tamil', flag: '🇮🇳' },
        { code: 'te', name: 'Telugu', flag: '🇮🇳' },
        { code: 'ml', name: 'Malayalam', flag: '🇮🇳' },
        { code: 'si', name: 'Sinhala', flag: '🇱🇰' },
        { code: 'fr', name: 'French', flag: '🇫🇷' },
        { code: 'es', name: 'Spanish', flag: '🇪🇸' },
        { code: 'de', name: 'German', flag: '🇩🇪' },
        { code: 'pt', name: 'Portuguese', flag: '🇵🇹' },
        { code: 'ru', name: 'Russian', flag: '🇷🇺' },
        { code: 'zh', name: 'Chinese', flag: '🇨🇳' },
        { code: 'ja', name: 'Japanese', flag: '🇯🇵' },
        { code: 'ko', name: 'Korean', flag: '🇰🇷' },
        { code: 'tr', name: 'Turkish', flag: '🇹🇷' },
        { code: 'id', name: 'Indonesian', flag: '🇮🇩' },
        { code: 'ms', name: 'Malay', flag: '🇲🇾' },
        { code: 'th', name: 'Thai', flag: '🇹🇭' },
        { code: 'vi', name: 'Vietnamese', flag: '🇻🇳' },
        { code: 'sw', name: 'Swahili', flag: '🇰🇪' },
        { code: 'am', name: 'Amharic', flag: '🇪🇹' },
        { code: 'it', name: 'Italian', flag: '🇮🇹' },
        { code: 'nl', name: 'Dutch', flag: '🇳🇱' },
        { code: 'pl', name: 'Polish', flag: '🇵🇱' },
        { code: 'uk', name: 'Ukrainian', flag: '🇺🇦' },
        { code: 'fa', name: 'Persian', flag: '🇮🇷' },
        { code: 'he', name: 'Hebrew', flag: '🇮🇱' },
    ];

    $: filteredTranslateLangs = translateLanguages.filter(l =>
        !translateLangSearch || l.name.toLowerCase().includes(translateLangSearch.toLowerCase()) || l.code.includes(translateLangSearch.toLowerCase())
    );

    // WhatsApp account info
    let waAccountName = '';
    let waProfilePicUrl = '';

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccount();
        // Light poll every 8s (just conversations, not messages)
        refreshInterval = setInterval(refreshConversationsOnly, 8000);
    });

    onDestroy(() => {
        if (refreshInterval) clearInterval(refreshInterval);
        if (convSubscription) convSubscription.unsubscribe();
        if (msgSubscription) msgSubscription.unsubscribe();
    });

    async function loadAccount() {
        try {
            console.log('📱 WALiveChat: Loading account...');
            const { data, error: accErr } = await supabase.from('wa_accounts').select('id, display_name, phone_number_id, access_token').eq('is_default', true).single();
            console.log('📱 WALiveChat: Account result:', { data: data ? { id: data.id, display_name: data.display_name } : null, error: accErr });
            if (accErr) console.error('📱 WALiveChat: Account error:', accErr);
            if (data) {
                accountId = data.id;
                waAccountName = data.display_name || '';
                // Load cached profile picture from settings
                const { data: settings } = await supabase.from('wa_settings').select('profile_picture_url').eq('wa_account_id', data.id).maybeSingle();
                waProfilePicUrl = settings?.profile_picture_url || '';
                // Fetch fresh profile from Meta API (non-blocking)
                if (data.phone_number_id && data.access_token) {
                    fetch(`https://graph.facebook.com/v22.0/${data.phone_number_id}/whatsapp_business_profile?fields=profile_picture_url`, {
                        headers: { 'Authorization': `Bearer ${data.access_token}` }
                    }).then(r => r.json()).then(result => {
                        const metaPic = result?.data?.[0]?.profile_picture_url;
                        if (metaPic && metaPic !== waProfilePicUrl) {
                            waProfilePicUrl = metaPic;
                            // Cache in DB
                            supabase.from('wa_settings').upsert({ wa_account_id: data.id, profile_picture_url: metaPic }, { onConflict: 'wa_account_id' });
                        }
                    }).catch(() => {});
                }
                await Promise.all([loadConversations(), loadPriorityConversations(), loadTemplates()]);
            } else {
                loading = false;
            }
        } catch { loading = false; }
    }

    async function loadConversations(append = false) {
        try {
            const offset = append ? conversations.length : 0;
            if (!append) convPage = 0;

            const { data, error: err } = await supabase.rpc('get_wa_conversations_fast', {
                p_account_id: accountId,
                p_limit: CONV_PAGE_SIZE,
                p_offset: offset,
                p_search: searchQuery || null,
                p_filter: chatFilter
            });
            if (err) throw err;

            const rows = data || [];
            if (rows.length > 0) convTotalCount = rows[0].total_count;
            else if (!append) convTotalCount = 0;

            if (append) {
                conversations = [...conversations, ...rows];
            } else {
                conversations = rows;
            }
            // Main list uses RPC order (last_message_at DESC), no client-side re-sorting needed
            filteredConversations = conversations;

            // Auto-select conversation by initialPhone
            if (initialPhone && !selectedConv) {
                const match = conversations.find(c => c.customer_phone === initialPhone);
                if (match) {
                    await selectConversation(match);
                    initialPhone = '';
                }
            }
        } catch (e: any) {
            console.error(e);
        } finally {
            loading = false;
            loadingMoreConvs = false;
        }
    }

    async function loadMoreConversations() {
        if (loadingMoreConvs || conversations.length >= convTotalCount) return;
        loadingMoreConvs = true;
        await loadConversations(true);
    }

    async function loadTemplates() {
        try {
            const { data } = await supabase
                .from('wa_templates')
                .select('id, name, body_text, language, status')
                .eq('wa_account_id', accountId)
                .eq('status', 'APPROVED');
            templates = data || [];
        } catch {}
    }

    // Load priority conversations (SOS + Needs Human) — separate section
    async function loadPriorityConversations() {
        try {
            const { data, error: err } = await supabase.rpc('get_wa_priority_conversations', {
                p_account_id: accountId
            });
            if (err) throw err;
            priorityConversations = data || [];
        } catch (e: any) {
            console.error('Priority conversations error:', e);
        }
    }

    // Light refresh — only reload conversation list (not messages)
    async function refreshConversationsOnly() {
        await Promise.all([loadConversations(), loadPriorityConversations()]);
    }

    // Subscribe to realtime for the selected conversation's messages
    function subscribeToMessages(convId: string) {
        if (msgSubscription) msgSubscription.unsubscribe();
        msgSubscription = supabase
            .channel(`wa_messages_${convId}`)
            .on('postgres_changes', {
                event: 'INSERT',
                schema: 'public',
                table: 'wa_messages',
                filter: `conversation_id=eq.${convId}`
            }, (payload: any) => {
                const newMsg = payload.new;
                if (newMsg && !messages.find(m => m.id === newMsg.id)) {
                    messages = [...messages, newMsg];
                    setTimeout(() => scrollToBottom(), 50);
                }
            })
            .on('postgres_changes', {
                event: 'UPDATE',
                schema: 'public',
                table: 'wa_messages',
                filter: `conversation_id=eq.${convId}`
            }, (payload: any) => {
                const updated = payload.new;
                if (updated) {
                    messages = messages.map(m => m.id === updated.id ? { ...m, ...updated } : m);
                }
            })
            .subscribe();
    }

    // RPC handles search + filter server-side, so applyFilters just assigns
    function applyFilters() {
        filteredConversations = conversations;
    }

    // Debounced search — reload from RPC when search/filter changes
    $: {
        searchQuery;
        chatFilter;
        if (supabase && accountId) {
            if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
            searchDebounceTimer = setTimeout(() => loadConversations(), 300);
        }
    }

    async function selectConversation(conv: Conversation) {
        selectedConv = conv;
        await loadMessages(conv.id);
        // Subscribe to realtime messages for this conversation
        subscribeToMessages(conv.id);
        // Mark as read
        if (conv.unread_count > 0) {
            await supabase.from('wa_conversations').update({ unread_count: 0 }).eq('id', conv.id);
            conv.unread_count = 0;
            conversations = [...conversations];
        }
    }

    async function loadMessages(convId: string, silent = false) {
        if (!silent) loadingMessages = true;
        try {
            const { data, error: msgErr } = await supabase
                .from('wa_messages')
                .select('id, direction, message_type, content, media_url, media_mime_type, template_name, status, sent_by, sent_by_user_id, metadata, created_at')
                .eq('conversation_id', convId)
                .order('created_at', { ascending: false })
                .limit(MSG_PAGE_SIZE + 1);
            if (msgErr) console.error('📨 WALiveChat: Messages error:', msgErr);
            const rows = data || [];
            hasMoreMessages = rows.length > MSG_PAGE_SIZE;
            messages = (hasMoreMessages ? rows.slice(0, MSG_PAGE_SIZE) : rows).reverse();
            // Load employee names for messages sent by users
            await loadUserNames(messages);
            if (!silent) {
                setTimeout(() => scrollToBottom(), 100);
            }
        } catch (e) {
            console.error('📨 WALiveChat: loadMessages CATCH error:', e);
        }
        if (!silent) loadingMessages = false;
    }

    async function loadOlderMessages() {
        if (!selectedConv || loadingOlderMessages || !hasMoreMessages || messages.length === 0) return;
        loadingOlderMessages = true;
        try {
            const oldestMsg = messages[0];
            const { data, error: msgErr } = await supabase
                .from('wa_messages')
                .select('id, direction, message_type, content, media_url, media_mime_type, template_name, status, sent_by, sent_by_user_id, metadata, created_at')
                .eq('conversation_id', selectedConv.id)
                .lt('created_at', oldestMsg.created_at)
                .order('created_at', { ascending: false })
                .limit(MSG_PAGE_SIZE + 1);
            if (msgErr) console.error('📨 WALiveChat: loadOlderMessages error:', msgErr);
            const rows = data || [];
            hasMoreMessages = rows.length > MSG_PAGE_SIZE;
            const olderMsgs = (hasMoreMessages ? rows.slice(0, MSG_PAGE_SIZE) : rows).reverse();
            await loadUserNames(olderMsgs);
            // Preserve scroll position
            const container = messagesContainer;
            const prevHeight = container?.scrollHeight || 0;
            messages = [...olderMsgs, ...messages];
            // After DOM updates, restore scroll so user doesn't jump
            setTimeout(() => {
                if (container) {
                    container.scrollTop = container.scrollHeight - prevHeight;
                }
            }, 50);
        } catch (e) {
            console.error('📨 WALiveChat: loadOlderMessages CATCH error:', e);
        }
        loadingOlderMessages = false;
    }

    async function loadUserNames(msgs: Message[]) {
        const userIds = [...new Set(msgs.filter((m: Message) => m.sent_by_user_id && !userNameCache[m.sent_by_user_id]).map((m: Message) => m.sent_by_user_id))];
        if (userIds.length > 0) {
            const { data: employees } = await supabase.from('hr_employee_master').select('user_id, name_en, name_ar').in('user_id', userIds);
            if (employees) {
                const isAr = $locale === 'ar';
                for (const emp of employees) {
                    userNameCache[emp.user_id] = (isAr ? emp.name_ar : emp.name_en) || emp.name_en || emp.name_ar || 'User';
                }
                userNameCache = { ...userNameCache };
            }
        }
    }

    function scrollToBottom() {
        if (messagesContainer) {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }
    }

    async function sendMessage() {
        if (!messageInput.trim() || !selectedConv || sending) return;
        if (!selectedConv.is_inside_24hr) return; // Can't send free-form outside 24hr

        sending = true;
        try {
            // Save message to DB
            const { data: insertedMsg, error: err } = await supabase.from('wa_messages').insert({
                conversation_id: selectedConv.id,
                wa_account_id: accountId,
                direction: 'outbound',
                message_type: 'text',
                content: messageInput.trim(),
                status: 'sending',
                sent_by: 'user',
                sent_by_user_id: $currentUser?.id || null
            }).select('id').single();
            if (err) throw err;

            // Call edge function to send via WhatsApp API
            const { data: accData } = await supabase.from('wa_accounts').select('phone_number_id, access_token').eq('id', accountId).single();
            if (accData) {
                const cleanPhone = selectedConv.customer_phone.replace(/[\s\-()]/g, '');
                const phone = cleanPhone.startsWith('+') ? cleanPhone.substring(1) : cleanPhone;

                const waResp = await fetch(`https://graph.facebook.com/v22.0/${accData.phone_number_id}/messages`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${accData.access_token}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        messaging_product: 'whatsapp',
                        to: phone,
                        type: 'text',
                        text: { body: messageInput.trim() }
                    })
                });
                const waResult = await waResp.json();
                const wamid = waResult?.messages?.[0]?.id;
                if (wamid && insertedMsg?.id) {
                    await supabase.from('wa_messages').update({ whatsapp_message_id: wamid, status: 'sent' }).eq('id', insertedMsg.id);
                }
            }

            // Update conversation
            await supabase.from('wa_conversations').update({
                last_message_at: new Date().toISOString(),
                last_message_preview: messageInput.trim().substring(0, 100)
            }).eq('id', selectedConv.id);

            messageInput = '';
            await loadMessages(selectedConv.id);
            scrollToBottom();
        } catch (e: any) {
            console.error('Send error:', e);
        } finally {
            sending = false;
        }
    }

    async function sendTemplate(template: WATemplate) {
        if (!selectedConv || sending) return;
        sending = true;
        showTemplatePicker = false;
        try {
            const { data: accData } = await supabase.from('wa_accounts').select('phone_number_id, access_token').eq('id', accountId).single();
            let wamid: string | null = null;
            if (accData) {
                const cleanPhone = selectedConv.customer_phone.replace(/[\s\-()]/g, '');
                const phone = cleanPhone.startsWith('+') ? cleanPhone.substring(1) : cleanPhone;

                const waResp = await fetch(`https://graph.facebook.com/v22.0/${accData.phone_number_id}/messages`, {
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
                            name: template.name,
                            language: { code: template.language }
                        }
                    })
                });
                const waResult = await waResp.json();
                wamid = waResult?.messages?.[0]?.id || null;
            }

            // Save message record
            await supabase.from('wa_messages').insert({
                conversation_id: selectedConv.id,
                wa_account_id: accountId,
                direction: 'outbound',
                message_type: 'template',
                content: template.body_text,
                template_name: template.name,
                whatsapp_message_id: wamid,
                status: 'sent',
                sent_by: 'user',
                sent_by_user_id: $currentUser?.id || null
            });

            await supabase.from('wa_conversations').update({
                last_message_at: new Date().toISOString(),
                last_message_preview: `📝 ${template.name}`
            }).eq('id', selectedConv.id);

            await loadMessages(selectedConv.id);
            scrollToBottom();
        } catch (e: any) {
            console.error('Send template error:', e);
        } finally {
            sending = false;
        }
    }

    async function takeOverFromBot() {
        if (!selectedConv) return;
        await supabase.from('wa_conversations').update({
            is_bot_handling: false,
            bot_type: null,
            handled_by: 'human'
        }).eq('id', selectedConv.id);
        selectedConv.is_bot_handling = false;
        selectedConv.bot_type = null;
        (selectedConv as any).handled_by = 'human';
        conversations = [...conversations];
    }

    async function toggleAI(conv: Conversation) {
        const turnOn = !conv.is_bot_handling;
        const update: any = turnOn
            ? { is_bot_handling: true, bot_type: 'ai', handled_by: 'bot', needs_human: false, is_sos: false }
            : { is_bot_handling: false };
        await supabase.from('wa_conversations').update(update).eq('id', conv.id);
        conv.is_bot_handling = turnOn;
        if (turnOn) { conv.bot_type = 'ai'; (conv as any).handled_by = 'bot'; conv.needs_human = false; conv.is_sos = false; }
        conversations = [...conversations];
        if (selectedConv?.id === conv.id) selectedConv = { ...conv };
    }

    async function resolveHelp(conv: Conversation) {
        await supabase.from('wa_conversations').update({
            needs_human: false,
            is_bot_handling: true,
            bot_type: 'ai',
            handled_by: 'bot'
        }).eq('id', conv.id);
        conv.needs_human = false;
        conv.is_bot_handling = true;
        conv.bot_type = 'ai';
        (conv as any).handled_by = 'bot';
        conversations = [...conversations];
        if (selectedConv?.id === conv.id) selectedConv = { ...conv };
    }

    async function toggleSOS(conv: Conversation) {
        const toggleOn = !conv.is_sos;
        const update: any = toggleOn
            ? { is_sos: true, is_bot_handling: false }
            : { is_sos: false, is_bot_handling: true, bot_type: 'ai', handled_by: 'bot' };
        await supabase.from('wa_conversations').update(update).eq('id', conv.id);
        conv.is_sos = toggleOn;
        if (toggleOn) {
            conv.is_bot_handling = false;
        } else {
            conv.is_bot_handling = true;
            conv.bot_type = 'ai';
            (conv as any).handled_by = 'bot';
        }
        conversations = [...conversations];
        if (selectedConv?.id === conv.id) selectedConv = { ...conv };
    }

    function formatTime(dateStr: string) {
        const d = new Date(dateStr);
        const now = new Date();
        const diffMs = now.getTime() - d.getTime();
        const diffMins = Math.floor(diffMs / 60000);
        if (diffMins < 1) return 'now';
        if (diffMins < 60) return `${diffMins}m`;
        const diffHrs = Math.floor(diffMs / 3600000);
        if (diffHrs < 24) return `${diffHrs}h`;
        return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
    }

    function formatMsgTime(dateStr: string) {
        return new Date(dateStr).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    function formatMsgDate(dateStr: string) {
        return new Date(dateStr).toLocaleDateString([], { year: 'numeric', month: 'long', day: 'numeric' });
    }

    function getMessageDate(dateStr: string): string {
        const d = new Date(dateStr);
        return d.toDateString();
    }

    function getStatusTick(status: string) {
        switch (status) {
            case 'sent': return '✓';
            case 'delivered': return '✓✓';
            case 'read': return '✓✓';
            case 'failed': return '✕';
            default: return '⏳';
        }
    }

    async function handleImageSelect(e: Event) {
        const input = e.target as HTMLInputElement;
        const file = input.files?.[0];
        if (!file || !selectedConv) return;
        await sendMediaMessage(file, 'image');
        input.value = '';
    }

    async function handleFileSelect(e: Event) {
        const input = e.target as HTMLInputElement;
        const file = input.files?.[0];
        if (!file || !selectedConv) return;
        const type = file.type.startsWith('video/') ? 'video' : 'document';
        await sendMediaMessage(file, type);
        input.value = '';
    }

    async function sendMediaMessage(file: File, type: 'image' | 'video' | 'document') {
        if (!selectedConv || sending) return;
        sending = true;
        showAttachMenu = false;
        try {
            const { data: accData } = await supabase.from('wa_accounts').select('phone_number_id, access_token').eq('id', accountId).single();
            if (!accData) throw new Error('No account data');

            // 1. Upload to Supabase Storage
            const ext = file.name.split('.').pop() || 'bin';
            const fileName = `${type}_${Date.now()}.${ext}`;
            const filePath = `${accountId}/${selectedConv.id}/${fileName}`;
            const { error: uploadErr } = await supabase.storage.from('whatsapp-media').upload(filePath, file, {
                contentType: file.type,
                upsert: false
            });
            if (uploadErr) throw uploadErr;

            const { data: urlData } = supabase.storage.from('whatsapp-media').getPublicUrl(filePath);
            const publicUrl = urlData?.publicUrl;

            // 2. Send via WhatsApp API
            const cleanPhone = selectedConv.customer_phone.replace(/[\s\-()]/g, '');
            const phone = cleanPhone.startsWith('+') ? cleanPhone.substring(1) : cleanPhone;

            const mediaPayload: any = { link: publicUrl };
            if (type === 'document') mediaPayload.filename = file.name;

            const waResp = await fetch(`https://graph.facebook.com/v22.0/${accData.phone_number_id}/messages`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accData.access_token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    messaging_product: 'whatsapp',
                    to: phone,
                    type: type,
                    [type]: mediaPayload
                })
            });
            const waResult = await waResp.json();
            const wamid = waResult?.messages?.[0]?.id || null;

            // 3. Save to DB
            const previewMap: Record<string, string> = { image: '📷 Image', video: '🎥 Video', document: `📎 ${file.name}` };
            await supabase.from('wa_messages').insert({
                conversation_id: selectedConv.id,
                wa_account_id: accountId,
                direction: 'outbound',
                message_type: type,
                content: '',
                media_url: publicUrl,
                media_mime_type: file.type,
                whatsapp_message_id: wamid,
                status: 'sent',
                sent_by: 'user',
                sent_by_user_id: $currentUser?.id || null
            });

            await supabase.from('wa_conversations').update({
                last_message_at: new Date().toISOString(),
                last_message_preview: previewMap[type] || '📎 File'
            }).eq('id', selectedConv.id);

            await loadMessages(selectedConv.id);
            scrollToBottom();
        } catch (e: any) {
            console.error(`Send ${type} error:`, e);
        } finally {
            sending = false;
        }
    }

    async function startRecording() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            audioChunks = [];
            mediaRecorder = new MediaRecorder(stream, { mimeType: 'audio/webm;codecs=opus' });
            mediaRecorder.ondataavailable = (e) => {
                if (e.data.size > 0) audioChunks.push(e.data);
            };
            mediaRecorder.onstop = async () => {
                stream.getTracks().forEach(t => t.stop());
                if (audioChunks.length > 0) {
                    const blob = new Blob(audioChunks, { type: 'audio/ogg; codecs=opus' });
                    await sendAudioMessage(blob);
                }
                audioChunks = [];
            };
            mediaRecorder.start();
            isRecording = true;
            recordingDuration = 0;
            recordingTimer = setInterval(() => { recordingDuration++; }, 1000);
        } catch (e: any) {
            console.error('Mic access denied:', e);
        }
    }

    function stopRecording() {
        if (mediaRecorder && mediaRecorder.state !== 'inactive') {
            mediaRecorder.stop();
        }
        isRecording = false;
        if (recordingTimer) { clearInterval(recordingTimer); recordingTimer = null; }
    }

    function cancelRecording() {
        audioChunks = [];
        if (mediaRecorder && mediaRecorder.state !== 'inactive') {
            mediaRecorder.onstop = () => { mediaRecorder?.stream?.getTracks().forEach(t => t.stop()); };
            mediaRecorder.stop();
        }
        isRecording = false;
        if (recordingTimer) { clearInterval(recordingTimer); recordingTimer = null; }
    }

    function formatRecordTime(secs: number) {
        const m = Math.floor(secs / 60).toString().padStart(2, '0');
        const s = (secs % 60).toString().padStart(2, '0');
        return `${m}:${s}`;
    }

    async function sendAudioMessage(blob: Blob) {
        if (!selectedConv || sending) return;
        sending = true;
        try {
            const { data: accData } = await supabase.from('wa_accounts').select('phone_number_id, access_token').eq('id', accountId).single();
            if (!accData) throw new Error('No account data');

            // 1. Upload audio to Supabase Storage
            const fileName = `voice_${Date.now()}.ogg`;
            const filePath = `${accountId}/${selectedConv.id}/${fileName}`;
            const { error: uploadErr } = await supabase.storage.from('whatsapp-media').upload(filePath, blob, {
                contentType: 'audio/ogg; codecs=opus',
                upsert: false
            });
            if (uploadErr) throw uploadErr;

            const { data: urlData } = supabase.storage.from('whatsapp-media').getPublicUrl(filePath);
            const publicUrl = urlData?.publicUrl;

            // 2. Send audio via WhatsApp API
            const cleanPhone = selectedConv.customer_phone.replace(/[\s\-()]/g, '');
            const phone = cleanPhone.startsWith('+') ? cleanPhone.substring(1) : cleanPhone;

            const waResp = await fetch(`https://graph.facebook.com/v22.0/${accData.phone_number_id}/messages`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accData.access_token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    messaging_product: 'whatsapp',
                    to: phone,
                    type: 'audio',
                    audio: { link: publicUrl }
                })
            });
            const waResult = await waResp.json();
            const wamid = waResult?.messages?.[0]?.id || null;

            // 3. Save message to DB
            await supabase.from('wa_messages').insert({
                conversation_id: selectedConv.id,
                wa_account_id: accountId,
                direction: 'outbound',
                message_type: 'audio',
                content: '',
                media_url: publicUrl,
                media_mime_type: 'audio/ogg; codecs=opus',
                whatsapp_message_id: wamid,
                status: 'sent',
                sent_by: 'user',
                sent_by_user_id: $currentUser?.id || null
            });

            await supabase.from('wa_conversations').update({
                last_message_at: new Date().toISOString(),
                last_message_preview: '🎤 Voice message'
            }).eq('id', selectedConv.id);

            await loadMessages(selectedConv.id);
            scrollToBottom();
        } catch (e: any) {
            console.error('Send audio error:', e);
        } finally {
            sending = false;
        }
    }

    function handleKeydown(e: KeyboardEvent) {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    }

    function autoResize(e: Event) {
        const el = e.target as HTMLTextAreaElement;
        el.style.height = 'auto';
        el.style.height = Math.min(el.scrollHeight, 120) + 'px';
    }

    function openTranslatePicker(msgId: string) {
        translateTargetMsgId = msgId;
        translateLangSearch = '';
        showTranslateLangPicker = true;
    }

    async function translateMessage(msgId: string, targetLang: string) {
        const msg = messages.find(m => m.id === msgId);
        if (!msg || !msg.content?.trim()) return;
        showTranslateLangPicker = false;
        translateTargetMsgId = null;
        translatingMsgId = msgId;
        try {
            const resp = await fetch(
                `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${targetLang}&dt=t&q=${encodeURIComponent(msg.content)}`
            );
            const data = await resp.json();
            const translated = (data[0] as any[])?.map((s: any) => s[0]).join('') || '';
            if (translated) {
                translatedMessages = { ...translatedMessages, [msgId]: translated };
            }
        } catch (e) {
            console.error('Translation error:', e);
        } finally {
            translatingMsgId = null;
        }
    }

    function clearTranslation(msgId: string) {
        const { [msgId]: _, ...rest } = translatedMessages;
        translatedMessages = rest;
    }

    async function transformInputText() {
        if (!messageInput.trim() || isInputTransforming) return;
        isInputTransforming = true;
        try {
            const response = await fetch('/api/transform-text', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    text: messageInput,
                    language: 'en',
                    type: 'chat'
                })
            });
            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Failed to transform text');
            }
            const data = await response.json();
            if (data.transformedText) messageInput = data.transformedText;
        } catch (err) {
            console.error('Error transforming input text:', err);
        } finally {
            isInputTransforming = false;
        }
    }

    async function translateInputText(targetLang: string) {
        if (!messageInput.trim() || isInputTranslating) return;
        showInputTranslatePicker = false;
        isInputTranslating = true;
        try {
            const resp = await fetch(
                `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${targetLang}&dt=t&q=${encodeURIComponent(messageInput)}`
            );
            const data = await resp.json();
            const translated = (data[0] as any[])?.map((s: any) => s[0]).join('') || '';
            if (translated) messageInput = translated;
        } catch (e) {
            console.error('Input translation error:', e);
        } finally {
            isInputTranslating = false;
        }
    }
</script>

<div class="wa-live-chat absolute inset-0 flex overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Left Panel: Conversation List -->
    <div class="w-[300px] flex flex-col border-r border-slate-200/80 bg-gradient-to-b from-orange-50/40 via-white to-orange-50/20">
        <!-- Brand Header -->
        <!-- Account Header -->
        <div class="left-panel-header">
            <div class="flex items-center gap-2.5">
                {#if waProfilePicUrl}
                    <img src={waProfilePicUrl} alt="" class="w-9 h-9 rounded-full object-cover ring-2 ring-orange-300/40 flex-shrink-0" />
                {:else}
                    <div class="w-9 h-9 rounded-full bg-orange-500 flex items-center justify-center text-white text-sm font-bold flex-shrink-0">💬</div>
                {/if}
                <div class="flex-1 min-w-0">
                    <h2 class="text-slate-800 font-semibold text-[13px] truncate">{waAccountName || 'Live Chat'}</h2>
                    <p class="text-slate-400 text-[10px]">WhatsApp Business</p>
                </div>
            </div>
        </div>
        <!-- Search & Filters -->
        <div class="px-3 py-2 border-b border-slate-100">
            <div class="relative">
                <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 text-xs">🔍</span>
                <input type="text" bind:value={searchQuery} placeholder="Search conversations..."
                    class="w-full pl-8 pr-3 py-1.5 bg-slate-50 text-slate-700 placeholder-slate-400 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-1 focus:ring-orange-300 focus:border-orange-300 transition-all" />
            </div>
            <div class="flex gap-1 mt-2">
                {#each [
                    { id: 'all', label: 'All' },
                    { id: 'unread', label: 'Unread' }
                ] as f}
                    <button class="px-3 py-1 text-[10px] font-medium rounded-md transition-all
                        {chatFilter === f.id ? 'bg-orange-500 text-white' : 'text-slate-500 hover:bg-slate-100'}"
                        on:click={() => chatFilter = f.id}>
                        {f.label}
                    </button>
                {/each}
            </div>
        </div>

        <!-- Conversation List -->
        <div class="flex-1 overflow-y-auto px-2 py-2 space-y-1.5" bind:this={convListContainer}
            on:scroll={(e) => {
                const el = e.currentTarget;
                if (el.scrollHeight - el.scrollTop - el.clientHeight < 100) {
                    loadMoreConversations();
                }
            }}>
            {#if loading}
                <div class="flex justify-center py-12">
                    <div class="animate-spin w-8 h-8 border-2 border-orange-200 border-t-orange-500 rounded-full"></div>
                </div>
            {:else}
                <!-- Priority Section: SOS & Needs Human -->
                {#if priorityConversations.length > 0}
                    <!-- SOS Section -->
                    {#if priorityConversations.some(c => c.is_sos)}
                        <div class="priority-section-header sos-header">
                            <span class="priority-section-icon">🚨</span>
                            <span class="priority-section-title">{$locale === 'ar' ? 'طوارئ SOS' : 'SOS'}</span>
                            <span class="priority-section-count">{priorityConversations.filter(c => c.is_sos).length}</span>
                        </div>
                        {#each priorityConversations.filter(c => c.is_sos) as conv}
                            <div role="button" tabindex="0"
                                class="conv-card conv-card-sos w-full px-3 py-2.5 flex items-center gap-2.5 transition-all text-left
                                {selectedConv?.id === conv.id ? 'conv-card-active' : ''}"
                                on:click={() => selectConversation(conv)}
                                on:keydown={(e) => e.key === 'Enter' && selectConversation(conv)}>
                                <div class="relative flex-shrink-0">
                                    <div class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold text-white" style="background:{avatarColor(conv.customer_name || conv.customer_phone)}">
                                        {(conv.customer_name || '?')[0].toUpperCase()}
                                    </div>
                                    <span class="absolute -bottom-0.5 -right-0.5 text-[9px]">{conv.is_inside_24hr ? '🟢' : '🔴'}</span>
                                </div>
                                <div class="flex-1 min-w-0">
                                    <div class="flex items-center justify-between">
                                        <span class="font-semibold text-[13px] text-slate-800 truncate">{conv.customer_name || conv.customer_phone}</span>
                                        <span class="text-[10px] text-slate-400 flex-shrink-0">{conv.last_message_at ? formatTime(conv.last_message_at) : ''}</span>
                                    </div>
                                    <div class="flex items-center justify-between mt-0.5">
                                        <p class="text-[11px] text-slate-500 truncate">{conv.last_message_preview || 'No messages'}</p>
                                        <div class="flex items-center gap-1 flex-shrink-0">
                                            <span role="button" tabindex="0" class="conv-badge badge-sos-active" on:click|stopPropagation={() => toggleSOS(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleSOS(conv)} title={$locale === 'ar' ? 'إلغاء SOS' : 'Remove SOS'}>SOS</span>
                                            {#if conv.unread_count > 0}
                                                <span class="unread-badge">{conv.unread_count}</span>
                                            {/if}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        {/each}
                    {/if}

                    <!-- Needs Human Section -->
                    {#if priorityConversations.some(c => c.needs_human && !c.is_sos)}
                        <div class="priority-section-header help-header">
                            <span class="priority-section-icon">🆘</span>
                            <span class="priority-section-title">{$locale === 'ar' ? 'يحتاج مساعدة' : 'Needs Help'}</span>
                            <span class="priority-section-count">{priorityConversations.filter(c => c.needs_human && !c.is_sos).length}</span>
                        </div>
                        {#each priorityConversations.filter(c => c.needs_human && !c.is_sos) as conv}
                            <div role="button" tabindex="0"
                                class="conv-card conv-card-help w-full px-3 py-2.5 flex items-center gap-2.5 transition-all text-left
                                {selectedConv?.id === conv.id ? 'conv-card-active' : ''}"
                                on:click={() => selectConversation(conv)}
                                on:keydown={(e) => e.key === 'Enter' && selectConversation(conv)}>
                                <div class="relative flex-shrink-0">
                                    <div class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold text-white" style="background:{avatarColor(conv.customer_name || conv.customer_phone)}">
                                        {(conv.customer_name || '?')[0].toUpperCase()}
                                    </div>
                                    <span class="absolute -bottom-0.5 -right-0.5 text-[9px]">{conv.is_inside_24hr ? '🟢' : '🔴'}</span>
                                </div>
                                <div class="flex-1 min-w-0">
                                    <div class="flex items-center justify-between">
                                        <span class="font-semibold text-[13px] text-slate-800 truncate">{conv.customer_name || conv.customer_phone}</span>
                                        <span class="text-[10px] text-slate-400 flex-shrink-0">{conv.last_message_at ? formatTime(conv.last_message_at) : ''}</span>
                                    </div>
                                    <div class="flex items-center justify-between mt-0.5">
                                        <p class="text-[11px] text-slate-500 truncate">{conv.last_message_preview || 'No messages'}</p>
                                        <div class="flex items-center gap-1 flex-shrink-0">
                                            <span role="button" tabindex="0" class="conv-badge badge-needshelp" on:click|stopPropagation={() => resolveHelp(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && resolveHelp(conv)} title={$locale === 'ar' ? 'حل وإعادة الذكاء' : 'Resolve & re-enable AI'}>🆘 {$locale === 'ar' ? 'حل' : 'Resolve'}</span>
                                            {#if conv.unread_count > 0}
                                                <span class="unread-badge">{conv.unread_count}</span>
                                            {/if}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        {/each}
                    {/if}

                    <!-- Separator between priority and main list -->
                    {#if filteredConversations.length > 0}
                        <div class="priority-separator">
                            <span class="priority-separator-label">{$locale === 'ar' ? 'جميع المحادثات' : 'All Chats'}</span>
                        </div>
                    {/if}
                {/if}

                <!-- Main conversation list -->
                {#if filteredConversations.length === 0 && priorityConversations.length === 0}
                    <div class="text-center py-12 text-slate-400">
                        <div class="text-4xl mb-3 opacity-40">💬</div>
                        <p class="text-xs font-medium">No conversations yet</p>
                    </div>
                {/if}
                {#each filteredConversations as conv}
                    <div role="button" tabindex="0"
                        class="conv-card w-full px-3 py-2.5 flex items-center gap-2.5 transition-all text-left
                        {selectedConv?.id === conv.id ? 'conv-card-active' : ''}"
                        on:click={() => selectConversation(conv)}
                        on:keydown={(e) => e.key === 'Enter' && selectConversation(conv)}>
                        <!-- Avatar -->
                        <div class="relative flex-shrink-0">
                            <div class="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold text-white" style="background:{avatarColor(conv.customer_name || conv.customer_phone)}">
                                {(conv.customer_name || '?')[0].toUpperCase()}
                            </div>
                            <span class="absolute -bottom-0.5 -right-0.5 text-[9px]">{conv.is_inside_24hr ? '🟢' : '🔴'}</span>
                        </div>
                        <!-- Info -->
                        <div class="flex-1 min-w-0">
                            <div class="flex items-center justify-between">
                                <span class="font-semibold text-[13px] text-slate-800 truncate">{conv.customer_name || conv.customer_phone}</span>
                                <span class="text-[10px] text-slate-400 flex-shrink-0">{conv.last_message_at ? formatTime(conv.last_message_at) : ''}</span>
                            </div>
                            <div class="flex items-center justify-between mt-0.5">
                                <p class="text-[11px] text-slate-500 truncate">{conv.last_message_preview || 'No messages'}</p>
                                <div class="flex items-center gap-1 flex-shrink-0">
                                    <!-- Badge 1: Last handler -->
                                    {#if (conv as any).handled_by === 'human'}
                                        <span class="conv-badge badge-human">👤 {$locale === 'ar' ? 'بشري' : 'Human'}</span>
                                    {:else if (conv as any).handled_by === 'auto_reply'}
                                        <span class="conv-badge badge-autoreply">🔧 {$locale === 'ar' ? 'تلقائي' : 'Auto'}</span>
                                    {:else if (conv as any).handled_by === 'flow'}
                                        <span class="conv-badge badge-flow">🌊 {$locale === 'ar' ? 'تدفق' : 'Flow'}</span>
                                    {:else if (conv as any).handled_by === 'bot' || (conv as any).handled_by === 'ai_bot'}
                                        <span class="conv-badge badge-ai">🤖 {$locale === 'ar' ? 'ذكاء' : 'AI'}</span>
                                    {/if}
                                    <!-- Badge 2: AI on/off (clickable) -->
                                    {#if conv.is_bot_handling}
                                        <span role="button" tabindex="0" class="conv-badge badge-aion" on:click|stopPropagation={() => toggleAI(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleAI(conv)} title={$locale === 'ar' ? 'إيقاف الذكاء' : 'Pause AI'}>🤖🟢 {$locale === 'ar' ? 'مفعّل' : 'On'}</span>
                                    {:else}
                                        <span role="button" tabindex="0" class="conv-badge badge-aioff" on:click|stopPropagation={() => toggleAI(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleAI(conv)} title={$locale === 'ar' ? 'تفعيل الذكاء' : 'Enable AI'}>🤖🔴 {$locale === 'ar' ? 'معطّل' : 'Off'}</span>
                                    {/if}
                                    <!-- Badge 3: Needs human (clickable = resolve) -->
                                    {#if conv.needs_human}
                                        <span role="button" tabindex="0" class="conv-badge badge-needshelp" on:click|stopPropagation={() => resolveHelp(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && resolveHelp(conv)} title={$locale === 'ar' ? 'اضغط لتأكيد الحل وإعادة الذكاء' : 'Click to resolve & re-enable AI'}>🆘 {$locale === 'ar' ? 'يحتاج مساعدة' : 'Needs Help'}</span>
                                    {/if}
                                    <!-- Badge 4: SOS Mode (clickable = toggle SOS) -->
                                    {#if conv.is_sos}
                                        <span role="button" tabindex="0" class="conv-badge badge-sos-active" on:click|stopPropagation={() => toggleSOS(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleSOS(conv)} title={$locale === 'ar' ? 'اضغط لإلغاء وضع SOS' : 'Click to remove SOS mode'}>SOS</span>
                                    {/if}
                                    {#if conv.unread_count > 0}
                                        <span class="unread-badge">{conv.unread_count}</span>
                                    {/if}
                                </div>
                            </div>
                        </div>
                    </div>
                {/each}
                {#if loadingMoreConvs}
                    <div class="flex justify-center py-3">
                        <div class="animate-spin w-5 h-5 border-2 border-orange-200 border-t-orange-500 rounded-full"></div>
                    </div>
                {:else if conversations.length < convTotalCount}
                    <button class="w-full py-2 text-xs text-orange-500 font-medium hover:bg-orange-50 rounded-lg transition-colors"
                        on:click={loadMoreConversations}>
                        Load more ({convTotalCount - conversations.length} remaining)
                    </button>
                {/if}
            {/if}
        </div>
    </div>

    <!-- Right Panel: Chat Area -->
    <div class="flex-1 flex flex-col bg-slate-50 min-h-0 overflow-hidden">
        {#if selectedConv}
            <!-- Chat Header -->
            <div class="chat-header">
                <div class="flex items-center gap-3">
                    <div class="w-9 h-9 rounded-full flex items-center justify-center font-bold text-white text-sm" style="background:{avatarColor(selectedConv.customer_name || selectedConv.customer_phone)}">
                        {(selectedConv.customer_name || '?')[0].toUpperCase()}
                    </div>
                    <div>
                        <h3 class="font-semibold text-sm text-slate-800">{selectedConv.customer_name || 'Unknown'}</h3>
                        <p class="text-slate-400 text-[11px] font-mono">{selectedConv.customer_phone}</p>
                    </div>
                </div>
                <div class="flex items-center gap-2">
                    <span class="px-2.5 py-1 rounded-full text-[10px] font-semibold {selectedConv.is_inside_24hr ? 'bg-green-50 text-green-600 border border-green-200' : 'bg-red-50 text-red-500 border border-red-200'}">
                        {selectedConv.is_inside_24hr ? '● 24hr Window' : '● Templates Only'}
                    </span>
                    <!-- Badge 1: Last handler -->
                    {#if (selectedConv as any).handled_by === 'human'}
                        <span class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-amber-50 text-amber-600 border border-amber-200">👤 {$locale === 'ar' ? 'وكيل بشري' : 'Human'}</span>
                    {:else if (selectedConv as any).handled_by === 'auto_reply'}
                        <span class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-blue-50 text-blue-600 border border-blue-200">🔧 {$locale === 'ar' ? 'رد تلقائي' : 'Auto Reply'}</span>
                    {:else if (selectedConv as any).handled_by === 'flow'}
                        <span class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-indigo-50 text-indigo-600 border border-indigo-200">🌊 {$locale === 'ar' ? 'تدفق بوت' : 'Bot Flow'}</span>
                    {:else if (selectedConv as any).handled_by === 'bot' || (selectedConv as any).handled_by === 'ai_bot'}
                        <span class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-violet-50 text-violet-600 border border-violet-200">🤖 {$locale === 'ar' ? 'بوت ذكاء' : 'AI Bot'}</span>
                    {/if}
                    <!-- Badge 2: AI on/off (clickable) -->
                    {#if selectedConv.is_bot_handling}
                        <button class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-violet-100 text-violet-700 border border-violet-300 hover:bg-violet-200 transition-colors cursor-pointer" on:click={() => toggleAI(selectedConv)} title={$locale === 'ar' ? 'إيقاف الذكاء مؤقتاً' : 'Pause AI'}>🤖🟢 {$locale === 'ar' ? 'ذكاء مفعّل' : 'AI On'}</button>
                    {:else}
                        <button class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-slate-100 text-slate-400 border border-slate-200 hover:bg-violet-50 hover:text-violet-600 hover:border-violet-200 transition-colors cursor-pointer" on:click={() => toggleAI(selectedConv)} title={$locale === 'ar' ? 'تفعيل الذكاء' : 'Enable AI'}>🤖🔴 {$locale === 'ar' ? 'ذكاء معطّل' : 'AI Off'}</button>
                    {/if}
                    <!-- Badge 3: Needs human help (clickable = resolve) -->
                    {#if selectedConv.needs_human}
                        <button class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-red-100 text-red-700 border border-red-300 hover:bg-green-100 hover:text-green-700 hover:border-green-300 transition-colors cursor-pointer animate-pulse" on:click={() => resolveHelp(selectedConv)} title={$locale === 'ar' ? 'اضغط للحل وإعادة الذكاء' : 'Click to resolve & re-enable AI'}>🆘 {$locale === 'ar' ? 'يحتاج مساعدة' : 'Needs Help'}</button>
                    {/if}
                    <!-- Badge 4: SOS Toggle -->
                    {#if selectedConv.is_sos}
                        <button class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-red-100 text-red-700 border border-red-300 hover:bg-green-100 hover:text-green-700 hover:border-green-300 transition-colors cursor-pointer animate-pulse" on:click={() => toggleSOS(selectedConv)} title={$locale === 'ar' ? 'اضغط لإزالة وضع SOS وتشغيل الذكاء' : 'Click to remove SOS & enable AI'}>� {$locale === 'ar' ? 'وضع SOS' : 'SOS Mode'}</button>
                    {:else}
                        <button class="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-slate-100 text-slate-600 border border-slate-200 hover:bg-red-100 hover:text-red-700 hover:border-red-300 transition-colors cursor-pointer" on:click={() => toggleSOS(selectedConv)} title={$locale === 'ar' ? 'اضغط لتفعيل وضع SOS' : 'Click to enable SOS mode'}>🛑 {$locale === 'ar' ? 'تفعيل SOS' : 'Enable SOS'}</button>
                    {/if}
                    <button class="w-8 h-8 bg-white rounded-full flex items-center justify-center shadow-sm border border-slate-200 hover:bg-red-50 hover:border-red-200 transition-colors text-sm"
                        on:click={() => showIncidentPopup = true}
                        title="Report Incident">
                        🚨
                    </button>
                    {#if selectedConv.is_bot_handling}
                        <button class="px-3 py-1.5 bg-orange-50 text-orange-600 text-[11px] font-medium rounded-lg border border-orange-200 hover:bg-orange-100 transition-colors"
                            on:click={takeOverFromBot}>
                            👤 Take Over
                        </button>
                    {/if}
                </div>
            </div>

            <!-- Messages Area -->
            <div class="flex-1 overflow-y-auto p-5 space-y-2 chat-messages-area min-h-0" bind:this={messagesContainer}
                on:scroll={(e) => {
                    const el = e.currentTarget;
                    if (el.scrollTop < 80 && hasMoreMessages && !loadingOlderMessages) {
                        loadOlderMessages();
                    }
                }}>
                {#if loadingMessages}
                    <div class="flex justify-center py-12">
                        <div class="animate-spin w-8 h-8 border-2 border-orange-200 border-t-orange-500 rounded-full"></div>
                    </div>
                {:else}
                {#if hasMoreMessages}
                    <div class="flex justify-center py-2">
                        {#if loadingOlderMessages}
                            <div class="animate-spin w-5 h-5 border-2 border-orange-200 border-t-orange-500 rounded-full"></div>
                        {:else}
                            <button class="px-3 py-1 rounded-full text-xs font-semibold bg-white text-slate-500 border border-slate-200 hover:bg-orange-50 hover:text-orange-600 hover:border-orange-200 transition-all shadow-sm"
                                on:click={loadOlderMessages}>⬆️ Load older messages</button>
                        {/if}
                    </div>
                {/if}
                {#if messages.length === 0}
                    <div class="text-center py-16">
                        <div class="text-5xl mb-3 opacity-30">💬</div>
                        <p class="text-slate-400 text-sm font-medium">No messages in this conversation</p>
                    </div>
                {:else}
                    {#each messages as msg, idx}
                        {#if idx === 0 || getMessageDate(messages[idx - 1].created_at) !== getMessageDate(msg.created_at)}
                            <div class="flex justify-center my-4">
                                <div class="px-4 py-1.5 bg-slate-100 text-slate-500 rounded-full text-xs font-medium">
                                    {formatMsgDate(msg.created_at)}
                                </div>
                            </div>
                        {/if}
                        <div class="flex {msg.direction === 'outbound' ? 'justify-end' : 'justify-start'}">
                            <div class="msg-bubble max-w-[65%] px-3.5 py-2.5 text-sm
                                {msg.direction === 'outbound'
                                    ? 'msg-outbound'
                                    : 'msg-inbound'}">
                                <!-- Sender label at top of bubble -->
                                {#if msg.direction === 'outbound'}
                                    {#if msg.sent_by === 'ai_bot'}
                                        <div class="text-[10px] font-semibold text-purple-500 mb-1">🤖 {$locale === 'ar' ? 'بوت الذكاء الاصطناعي' : 'AI Bot'}</div>
                                    {:else if msg.sent_by === 'auto_reply' || msg.sent_by === 'auto_reply_bot'}
                                        <div class="text-[10px] font-semibold text-blue-500 mb-1">🔧 {$locale === 'ar' ? 'بوت الرد التلقائي' : 'Auto Reply Bot'}</div>
                                    {:else if msg.sent_by === 'system'}
                                        <div class="text-[10px] font-semibold text-slate-400 mb-1">⚙️ {$locale === 'ar' ? 'نظام' : 'System'}</div>
                                    {:else if msg.sent_by === 'user' && msg.sent_by_user_id}
                                        <div class="text-[10px] font-semibold text-orange-600 mb-1">👤 {userNameCache[msg.sent_by_user_id] || ($locale === 'ar' ? 'مستخدم' : 'User')}</div>
                                    {:else}
                                        <div class="text-[10px] font-semibold text-orange-600 mb-1">👤 {$locale === 'ar' ? 'مستخدم' : 'User'}</div>
                                    {/if}
                                {:else if msg.direction === 'inbound'}
                                    <div class="text-[10px] font-semibold text-slate-500 mb-1">💬 {$locale === 'ar' ? 'العميل' : 'Customer'}</div>
                                {/if}
                                {#if msg.message_type === 'image' && msg.media_url}
                                    <img src={msg.media_url} alt="media" class="rounded-lg max-w-[280px] w-auto h-auto mb-1 cursor-pointer" on:click={() => window.open(msg.media_url, '_blank')} />
                                {/if}
                                {#if (msg.message_type === 'audio' || msg.message_type === 'voice') && msg.media_url}
                                    <audio controls preload="metadata" class="max-w-[250px] h-10 mb-1">
                                        <source src={msg.media_url} type={msg.media_mime_type || 'audio/ogg'} />
                                        Your browser does not support audio.
                                    </audio>
                                {/if}
                                {#if msg.message_type === 'video' && msg.media_url}
                                    <video controls preload="metadata" class="rounded-lg max-w-[280px] max-h-[200px] mb-1">
                                        <source src={msg.media_url} type={msg.media_mime_type || 'video/mp4'} />
                                        Your browser does not support video.
                                    </video>
                                {/if}
                                {#if msg.message_type === 'sticker' && msg.media_url}
                                    <img src={msg.media_url} alt="sticker" class="max-w-[120px] h-auto mb-1" />
                                {/if}
                                {#if msg.message_type === 'document' && msg.media_url}
                                    <div class="bg-slate-100 rounded-lg p-2 flex items-center gap-2 mb-1">
                                        <span>📎</span>
                                        <a href={msg.media_url} target="_blank" class="text-blue-600 text-xs underline">Document</a>
                                    </div>
                                {/if}
                                {#if msg.content && !(['image','audio','voice','video','sticker'].includes(msg.message_type) && msg.media_url && /^\[.+\]$/.test(msg.content.trim()))}
                                    <p class="whitespace-pre-wrap break-words">{msg.content}</p>
                                {/if}
                                <!-- Interactive buttons -->
                                {#if msg.message_type === 'interactive' && msg.metadata}
                                    {#if msg.metadata.interactive_type === 'button' && msg.metadata.buttons?.length}
                                        <div class="flex flex-col gap-1 mt-2 border-t border-slate-200 pt-2">
                                            {#each msg.metadata.buttons as btn}
                                                <div class="text-center text-xs text-blue-600 font-medium py-1.5 bg-white/60 rounded-lg border border-blue-200">
                                                    {btn.title}
                                                </div>
                                            {/each}
                                        </div>
                                    {:else if msg.metadata.interactive_type === 'cta_url' && msg.metadata.url}
                                        <div class="mt-2 border-t border-slate-200 pt-2">
                                            <a href={msg.metadata.url} target="_blank" class="flex items-center justify-center gap-1 text-xs text-blue-600 font-medium py-1.5 bg-white/60 rounded-lg border border-blue-200 hover:bg-blue-50">
                                                🔗 {msg.metadata.display_text || 'Open Link'}
                                            </a>
                                        </div>
                                    {/if}
                                {/if}
                                {#if msg.template_name}
                                    <span class="text-[10px] text-slate-400/80 italic">📝 {msg.template_name}</span>
                                {/if}
                                <!-- Translation -->
                                {#if translatedMessages[msg.id]}
                                    <div class="translate-result">
                                        <div class="flex items-center justify-between mb-1">
                                            <span class="text-[9px] font-semibold text-blue-600 uppercase tracking-wider">🌐 {$locale === 'ar' ? 'ترجمة' : 'Translation'}</span>
                                            <button class="text-[9px] text-slate-400 hover:text-red-500 transition-colors" on:click={() => clearTranslation(msg.id)}>✕</button>
                                        </div>
                                        <p class="whitespace-pre-wrap break-words text-[12.5px]">{translatedMessages[msg.id]}</p>
                                    </div>
                                {/if}
                                {#if translatingMsgId === msg.id}
                                    <div class="flex items-center gap-1.5 mt-1.5 text-[10px] text-blue-500">
                                        <span class="animate-spin inline-block w-3 h-3 border border-blue-300 border-t-blue-600 rounded-full"></span>
                                        {$locale === 'ar' ? 'جاري الترجمة...' : 'Translating...'}
                                    </div>
                                {/if}
                                <div class="flex items-center justify-end gap-1.5 mt-1.5">
                                    {#if msg.content?.trim() && !translatedMessages[msg.id]}
                                        <button class="translate-btn" on:click={() => openTranslatePicker(msg.id)} title={$locale === 'ar' ? 'ترجمة' : 'Translate'}>🌐</button>
                                    {/if}
                                    <span class="text-[9px] text-slate-400/70">{formatMsgTime(msg.created_at)}</span>
                                    {#if msg.direction === 'outbound'}
                                        <span class="text-[10px] {msg.status === 'read' ? 'text-blue-500' : 'text-slate-400/60'}">{getStatusTick(msg.status)}</span>
                                    {/if}
                                </div>
                            </div>
                        </div>
                    {/each}
                {/if}
                {/if}
            </div>

            <!-- Input Area -->
            <div class="input-area">
                {#if !selectedConv.is_inside_24hr}
                    <!-- Outside 24hr — Templates only -->
                    <div class="flex items-center gap-3">
                        <p class="text-xs text-red-500 font-semibold">● Outside 24-hour window. Templates only.</p>
                        <button class="px-4 py-2 bg-gradient-to-r from-orange-500 to-orange-600 text-white text-xs font-bold rounded-xl hover:from-orange-600 hover:to-orange-700 shadow-sm transition-all"
                            on:click={() => showTemplatePicker = !showTemplatePicker}>
                            📝 Send Template
                        </button>
                    </div>
                {:else}
                    {#if isRecording}
                        <!-- Recording UI -->
                        <div class="flex items-center gap-3">
                            <button class="w-10 h-10 bg-red-100 text-red-500 rounded-full flex items-center justify-center hover:bg-red-200 transition-colors"
                                on:click={cancelRecording} title="Cancel">
                                🗑️
                            </button>
                            <div class="flex-1 flex items-center gap-2 bg-red-50 border border-red-200 rounded-2xl px-4 py-2.5">
                                <span class="w-2.5 h-2.5 bg-red-500 rounded-full animate-pulse"></span>
                                <span class="text-sm text-red-600 font-mono">{formatRecordTime(recordingDuration)}</span>
                                <span class="text-xs text-red-400">Recording...</span>
                            </div>
                            <button class="w-10 h-10 bg-gradient-to-br from-green-500 to-green-600 text-white rounded-full flex items-center justify-center hover:from-green-600 hover:to-green-700 shadow-md transition-all"
                                on:click={stopRecording} title="Send voice message">
                                ➤
                            </button>
                        </div>
                    {:else}
                        <div class="flex items-center gap-2">
                            <!-- Hidden file inputs -->
                            <input type="file" accept="image/*" capture="environment" class="hidden" bind:this={imageInput} on:change={handleImageSelect} />
                            <input type="file" accept="image/*,video/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip,.rar" class="hidden" bind:this={fileInput} on:change={handleFileSelect} />

                            <!-- Attach menu -->
                            <div class="relative">
                                <button class="w-10 h-10 bg-orange-50 border border-orange-200/60 rounded-full flex items-center justify-center text-lg hover:bg-orange-100 transition-all"
                                    on:click={() => showAttachMenu = !showAttachMenu} title="Attach">
                                    📎
                                </button>
                                {#if showAttachMenu}
                                    <div class="attach-menu">
                                        <button class="attach-menu-item"
                                            on:click={() => { imageInput.click(); showAttachMenu = false; }}>
                                            <span class="text-base">📷</span> <span>Photo</span>
                                        </button>
                                        <button class="attach-menu-item"
                                            on:click={() => { fileInput.click(); showAttachMenu = false; }}>
                                            <span class="text-base">📄</span> <span>Document / Video</span>
                                        </button>
                                        <button class="attach-menu-item"
                                            on:click={() => { showTemplatePicker = !showTemplatePicker; showAttachMenu = false; }}>
                                            <span class="text-base">📝</span> <span>Template</span>
                                        </button>
                                    </div>
                                {/if}
                            </div>

                            <textarea bind:value={messageInput} rows="1"
                                placeholder="Type a message..."
                                class="flex-1 px-4 py-2.5 bg-white/80 border border-orange-300 rounded-2xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-400/40 focus:border-orange-400 resize-none max-h-24 backdrop-blur-sm transition-all"
                                on:keydown={handleKeydown}
                                on:input={autoResize}></textarea>
                            {#if messageInput.trim()}
                                <!-- Transform button (fix grammar/spelling) -->
                                <button
                                    class="w-10 h-10 rounded-full flex items-center justify-center text-lg transition-all {isInputTransforming ? 'bg-purple-100 border border-purple-300 animate-pulse' : 'bg-purple-50 border border-purple-200/60 hover:bg-purple-100'}"
                                    on:click={transformInputText}
                                    disabled={isInputTransforming}
                                    title={$locale === 'ar' ? 'إصلاح القواعد والإملاء' : 'Fix grammar & spelling'}
                                >
                                    {isInputTransforming ? '⏳' : '✨'}
                                </button>
                                <!-- Translate button -->
                                <button
                                    class="w-10 h-10 rounded-full flex items-center justify-center text-lg transition-all {isInputTranslating ? 'bg-blue-100 border border-blue-300 animate-pulse' : 'bg-blue-50 border border-blue-200/60 hover:bg-blue-100'}"
                                    on:click={() => { inputTranslateLangSearch = ''; showInputTranslatePicker = true; }}
                                    disabled={isInputTranslating}
                                    title={$locale === 'ar' ? 'ترجمة النص' : 'Translate text'}
                                >
                                    {isInputTranslating ? '⏳' : '🌐'}
                                </button>
                                <button class="w-10 h-10 bg-gradient-to-br from-green-500 to-green-600 text-white rounded-full flex items-center justify-center hover:from-green-600 hover:to-green-700 shadow-md transition-all disabled:opacity-50"
                                    on:click={sendMessage} disabled={sending}>
                                    {sending ? '⏳' : '➤'}
                                </button>
                            {:else}
                                <button class="w-10 h-10 bg-orange-50 border border-orange-200/60 rounded-full flex items-center justify-center text-lg hover:bg-orange-100 transition-all"
                                    on:click={startRecording} title="Record voice message">
                                    🎤
                                </button>
                            {/if}
                        </div>
                    {/if}
                {/if}

                <!-- Template Picker Popup -->
                {#if showTemplatePicker}
                    <div class="template-picker">
                        <div class="flex items-center justify-between mb-3">
                            <h4 class="text-xs font-bold text-orange-600 uppercase tracking-wider">Select Template</h4>
                            <button class="w-6 h-6 rounded-full bg-slate-100 hover:bg-slate-200 flex items-center justify-center text-slate-500 text-xs transition-colors" on:click={() => showTemplatePicker = false}>✕</button>
                        </div>
                        {#if templates.length === 0}
                            <p class="text-xs text-slate-400 text-center py-4">No approved templates available</p>
                        {:else}
                            <div class="space-y-1.5">
                                {#each templates as tmpl}
                                    <button class="w-full text-left px-3 py-2.5 bg-white/60 rounded-xl hover:bg-orange-50 transition-all border border-orange-100/50 hover:border-orange-200"
                                        on:click={() => sendTemplate(tmpl)}>
                                        <p class="text-xs font-bold text-slate-700">{tmpl.name}</p>
                                        <p class="text-[10px] text-slate-500 truncate mt-0.5">{tmpl.body_text}</p>
                                        <span class="text-[9px] text-orange-500 font-medium">{tmpl.language === 'ar' ? '🇸🇦' : '🇺🇸'} {tmpl.language.toUpperCase()}</span>
                                    </button>
                                {/each}
                            </div>
                        {/if}
                    </div>
                {/if}
            </div>
        {:else}
            <!-- No conversation selected -->
            <div class="flex-1 flex items-center justify-center">
                <div class="text-center">
                    <div class="w-20 h-20 mx-auto rounded-2xl bg-orange-50 flex items-center justify-center mb-4 border border-orange-100">
                        <span class="text-3xl">💬</span>
                    </div>
                    <h3 class="text-base font-semibold text-slate-700">WhatsApp Live Chat</h3>
                    <p class="text-sm text-slate-400 mt-1">Select a conversation to start chatting</p>
                </div>
            </div>
        {/if}
    </div>

    <!-- Translation Language Picker Popup -->
    {#if showTranslateLangPicker}
        <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
        <div class="fixed inset-0 bg-black/40 flex items-center justify-center" style="z-index: 99998;" on:click={() => { showTranslateLangPicker = false; translateTargetMsgId = null; }}>
            <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
            <div class="translate-lang-popup" on:click|stopPropagation>
                <div class="flex items-center justify-between mb-3">
                    <h4 class="text-sm font-bold text-slate-700 flex items-center gap-1.5">🌐 {$locale === 'ar' ? 'ترجم إلى' : 'Translate to'}</h4>
                    <button class="w-6 h-6 rounded-full bg-slate-100 hover:bg-slate-200 flex items-center justify-center text-slate-500 text-xs transition-colors" on:click={() => { showTranslateLangPicker = false; translateTargetMsgId = null; }}>✕</button>
                </div>
                <input type="text" bind:value={translateLangSearch} placeholder={$locale === 'ar' ? 'بحث عن لغة...' : 'Search language...'}
                    class="w-full px-3 py-2 mb-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-1 focus:ring-blue-400 focus:border-blue-400" />
                <div class="grid grid-cols-2 gap-1 max-h-[300px] overflow-y-auto">
                    {#each filteredTranslateLangs as lang}
                        <button class="translate-lang-item" on:click={() => translateTargetMsgId && translateMessage(translateTargetMsgId, lang.code)}>
                            <span class="text-base">{lang.flag}</span>
                            <span class="text-xs text-slate-700 font-medium">{lang.name}</span>
                        </button>
                    {/each}
                    {#if filteredTranslateLangs.length === 0}
                        <p class="col-span-2 text-xs text-slate-400 text-center py-4">{$locale === 'ar' ? 'لم يتم العثور على لغات' : 'No languages found'}</p>
                    {/if}
                </div>
            </div>
        </div>
    {/if}

    <!-- Input Translate Language Picker Popup -->
    {#if showInputTranslatePicker}
        <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
        <div class="fixed inset-0 bg-black/40 flex items-center justify-center" style="z-index: 99998;" on:click={() => showInputTranslatePicker = false}>
            <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
            <div class="translate-lang-popup" on:click|stopPropagation>
                <div class="flex items-center justify-between mb-3">
                    <h4 class="text-sm font-bold text-slate-700 flex items-center gap-1.5">🌐 {$locale === 'ar' ? 'ترجم النص إلى' : 'Translate text to'}</h4>
                    <button class="w-6 h-6 rounded-full bg-slate-100 hover:bg-slate-200 flex items-center justify-center text-slate-500 text-xs transition-colors" on:click={() => showInputTranslatePicker = false}>✕</button>
                </div>
                <input type="text" bind:value={inputTranslateLangSearch} placeholder={$locale === 'ar' ? 'بحث عن لغة...' : 'Search language...'}
                    class="w-full px-3 py-2 mb-2 bg-slate-50 border border-slate-200 rounded-lg text-xs focus:outline-none focus:ring-1 focus:ring-blue-400 focus:border-blue-400" />
                <div class="grid grid-cols-2 gap-1 max-h-[300px] overflow-y-auto">
                    {#each filteredInputTranslateLangs as lang}
                        <button class="translate-lang-item" on:click={() => translateInputText(lang.code)}>
                            <span class="text-base">{lang.flag}</span>
                            <span class="text-xs text-slate-700 font-medium">{lang.name}</span>
                        </button>
                    {/each}
                    {#if filteredInputTranslateLangs.length === 0}
                        <p class="col-span-2 text-xs text-slate-400 text-center py-4">{$locale === 'ar' ? 'لم يتم العثور على لغات' : 'No languages found'}</p>
                    {/if}
                </div>
            </div>
        </div>
    {/if}

    <!-- Report Incident Popup -->
    {#if showIncidentPopup}
        <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
        <div class="fixed inset-0 bg-black/60 flex items-center justify-center p-6" style="z-index: 99999;" on:click={() => showIncidentPopup = false}>
            <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
            <div class="bg-white rounded-2xl w-[520px] max-h-[85vh] flex flex-col overflow-hidden shadow-2xl relative" on:click|stopPropagation>
                <!-- Header -->
                <div class="flex items-center justify-between px-5 py-3 border-b border-slate-200 bg-gradient-to-r from-red-600 to-orange-500 flex-shrink-0">
                    <div class="flex items-center gap-2">
                        <span class="text-lg">🚨</span>
                        <h3 class="text-white font-bold text-sm">Report Incident</h3>
                        {#if selectedConv}
                            <span class="text-white/70 text-xs">— {selectedConv.customer_name || selectedConv.customer_phone}</span>
                        {/if}
                    </div>
                    <button class="w-7 h-7 bg-white/20 rounded-full flex items-center justify-center text-white hover:bg-white/30 text-sm transition-colors"
                        on:click={() => showIncidentPopup = false}>
                        ✕
                    </button>
                </div>
                <!-- Report Incident Form (reusing mobile component) -->
                <div class="flex-1 overflow-y-auto incident-popup-body">
                    <ReportIncident presetTypeId="IN1" presetCustomerName={selectedConv?.customer_name || ''} presetCustomerPhone={selectedConv?.customer_phone || ''} />
                </div>
            </div>
        </div>
    {/if}
</div>

<style>
    /* === Clean Integrated Theme === */

    .wa-live-chat {
        background: white;
    }

    /* --- Left Panel Header --- */
    .left-panel-header {
        padding: 12px 14px;
        border-bottom: 1px solid #f1f5f9;
        background: white;
    }

    /* --- Chat Header --- */
    .chat-header {
        background: white;
        padding: 10px 16px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        border-bottom: 1px solid #e2e8f0;
    }

    /* --- Conversation Cards (Glass) --- */
    .conv-card {
        background: rgba(255, 255, 255, 0.55);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        border: 1px solid rgba(255, 255, 255, 0.6);
        cursor: pointer;
        border-radius: 12px;
        box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04), 0 0 0 1px rgba(249, 115, 22, 0.04);
        transition: all 0.2s ease;
    }
    .conv-card:hover {
        background: rgba(255, 255, 255, 0.8);
        box-shadow: 0 2px 8px rgba(249, 115, 22, 0.1), 0 0 0 1px rgba(249, 115, 22, 0.1);
        transform: translateY(-1px);
    }
    .conv-card-active {
        background: rgba(255, 247, 237, 0.85) !important;
        border: 1px solid rgba(249, 115, 22, 0.3) !important;
        box-shadow: 0 2px 10px rgba(249, 115, 22, 0.15), inset 0 0 0 1px rgba(249, 115, 22, 0.1) !important;
    }

    /* --- Priority Section Cards --- */
    .conv-card-sos {
        border-left: 3px solid #ef4444;
        background: rgba(254, 226, 226, 0.4);
    }
    .conv-card-sos:hover {
        background: rgba(254, 226, 226, 0.7);
        border-left-color: #dc2626;
    }
    .conv-card-help {
        border-left: 3px solid #f59e0b;
        background: rgba(255, 251, 235, 0.4);
    }
    .conv-card-help:hover {
        background: rgba(255, 251, 235, 0.7);
        border-left-color: #d97706;
    }

    /* --- Priority Section Headers --- */
    .priority-section-header {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 6px 10px;
        margin: 4px 0 2px;
        border-radius: 8px;
        font-size: 11px;
        font-weight: 700;
    }
    .sos-header {
        background: linear-gradient(135deg, #fee2e2, #fecaca);
        color: #b91c1c;
    }
    .help-header {
        background: linear-gradient(135deg, #fef3c7, #fde68a);
        color: #92400e;
    }
    .priority-section-icon { font-size: 12px; }
    .priority-section-title { flex: 1; }
    .priority-section-count {
        min-width: 18px;
        height: 18px;
        padding: 0 5px;
        border-radius: 9999px;
        font-size: 10px;
        font-weight: 700;
        display: flex;
        align-items: center;
        justify-content: center;
    }
    .sos-header .priority-section-count { background: #ef4444; color: white; }
    .help-header .priority-section-count { background: #f59e0b; color: white; }

    /* --- Priority Separator --- */
    .priority-separator {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px 0 4px;
        margin: 4px 6px;
    }
    .priority-separator::before,
    .priority-separator::after {
        content: '';
        flex: 1;
        height: 1px;
        background: #e2e8f0;
    }
    .priority-separator-label {
        font-size: 10px;
        font-weight: 600;
        color: #94a3b8;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        white-space: nowrap;
    }

    /* --- Unread Badge --- */
    .unread-badge {
        min-width: 18px;
        height: 18px;
        padding: 0 5px;
        background: #f97316;
        color: white;
        font-size: 10px;
        font-weight: 700;
        border-radius: 9999px;
        display: flex;
        align-items: center;
        justify-content: center;
    }

    /* --- Conversation List Badges --- */
    .conv-badge {
        font-size: 9px;
        font-weight: 700;
        padding: 2px 5px;
        border-radius: 9999px;
        white-space: nowrap;
        border: 1px solid transparent;
        cursor: default;
        display: inline-flex;
        align-items: center;
        gap: 1px;
    }
    .badge-ai        { background: #f3e8ff; color: #7c3aed; border-color: #ddd6fe; }
    .badge-autoreply { background: #eff6ff; color: #2563eb; border-color: #bfdbfe; }
    .badge-flow      { background: #eef2ff; color: #4338ca; border-color: #c7d2fe; }
    .badge-human     { background: #fffbeb; color: #d97706; border-color: #fde68a; }
    .badge-aion      { background: #ede9fe; color: #6d28d9; border-color: #c4b5fd; cursor: pointer; }
    .badge-aion:hover { background: #ddd6fe; }
    .badge-aioff     { background: #f1f5f9; color: #94a3b8; border-color: #e2e8f0; cursor: pointer; }
    .badge-aioff:hover { background: #ede9fe; color: #6d28d9; border-color: #c4b5fd; }
    .badge-needshelp { background: #fee2e2; color: #b91c1c; border-color: #fca5a5; cursor: pointer; animation: pulse 2s infinite; }
    .badge-needshelp:hover { background: #dcfce7; color: #15803d; border-color: #86efac; }
    .badge-sos       { background: #22c55e; color: #ffffff; border: 2px solid #ffffff; cursor: pointer; border-radius: 20px; padding: 4px 10px; font-weight: bold; font-size: 9px; }
    .badge-sos:hover { background: #16a34a; color: #ffffff; border: 2px solid #ffffff; }
    .badge-sos-active { background: #ef4444; color: #ffffff; border: 2px solid #ffffff; cursor: pointer; border-radius: 20px; padding: 4px 10px; font-weight: bold; font-size: 9px; animation: pulse 2s infinite; }
    .badge-sos-active:hover { background: #dc2626; color: #ffffff; border: 2px solid #ffffff; }

    /* --- Chat Messages Area (Glass BG) --- */
    .chat-messages-area {
        background: linear-gradient(135deg, rgba(249, 115, 22, 0.04) 0%, rgba(255, 255, 255, 0.6) 40%, rgba(34, 197, 94, 0.04) 100%);
        backdrop-filter: blur(8px);
        -webkit-backdrop-filter: blur(8px);
        background-image:
            linear-gradient(135deg, rgba(249, 115, 22, 0.04) 0%, rgba(255, 255, 255, 0.6) 40%, rgba(34, 197, 94, 0.04) 100%),
            url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23f97316' fill-opacity='0.03'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
    }

    /* --- Date Separator --- */
    .date-separator {
        display: flex;
        justify-content: center;
        align-items: center;
        margin: 16px 0;
        font-size: 13px;
        font-weight: 500;
        color: #64748b;
    }

    .date-separator > div {
        background: #f1f5f9;
        padding: 6px 14px;
        border-radius: 16px;
        white-space: nowrap;
    }

    /* --- Message Bubbles (Glass) --- */
    .msg-bubble {
        border-radius: 14px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06), 0 0 1px rgba(0, 0, 0, 0.08);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
    }
    .msg-outbound {
        background: rgba(220, 252, 231, 0.75);
        border: 1px solid rgba(187, 247, 208, 0.6);
        color: #1e293b;
        border-top-right-radius: 4px;
    }
    .msg-inbound {
        background: rgba(255, 255, 255, 0.8);
        border: 1px solid rgba(226, 232, 240, 0.6);
        color: #1e293b;
        border-top-left-radius: 4px;
    }

    /* --- Input Area --- */
    .input-area {
        background: white;
        border-top: 1px solid #e2e8f0;
        padding: 10px 14px;
    }

    /* --- Attach Menu --- */
    .attach-menu {
        position: absolute;
        bottom: 48px;
        left: 0;
        background: white;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
        padding: 4px;
        display: flex;
        flex-direction: column;
        gap: 1px;
        min-width: 160px;
        z-index: 50;
    }
    .attach-menu-item {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        font-size: 12px;
        color: #475569;
        border-radius: 8px;
        transition: all 0.15s;
        cursor: pointer;
        border: none;
        background: none;
        width: 100%;
        text-align: left;
    }
    .attach-menu-item:hover {
        background: #f8fafc;
        color: #ea580c;
    }

    /* --- Template Picker --- */
    .template-picker {
        margin-top: 10px;
        background: white;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.06);
        padding: 14px;
        max-height: 260px;
        overflow-y: auto;
    }

    /* --- Scrollbar Styling --- */
    .wa-live-chat ::-webkit-scrollbar {
        width: 4px;
    }
    .wa-live-chat ::-webkit-scrollbar-track {
        background: transparent;
    }
    .wa-live-chat ::-webkit-scrollbar-thumb {
        background: #cbd5e1;
        border-radius: 10px;
    }
    .wa-live-chat ::-webkit-scrollbar-thumb:hover {
        background: #94a3b8;
    }

    /* --- Incident Popup --- */
    .incident-popup-body :global(.mobile-page) {
        min-height: auto;
        background: white;
    }
    .incident-popup-body :global(.popup-overlay) {
        z-index: 999999 !important;
        bottom: 0 !important;
        position: absolute !important;
        top: 0 !important;
        left: 0 !important;
        right: 0 !important;
    }
    .incident-popup-body :global(.popup-panel) {
        max-width: 100% !important;
        border-radius: 8px !important;
    }
    .incident-popup-body :global(.modal-overlay) {
        z-index: 999999 !important;
        position: absolute !important;
        top: 0 !important;
        left: 0 !important;
        right: 0 !important;
        bottom: 0 !important;
    }
    .incident-popup-body :global(.modal-content) {
        max-width: 90% !important;
    }

    /* --- Translate Button --- */
    .translate-btn {
        font-size: 11px;
        padding: 2px 5px;
        border-radius: 6px;
        background: rgba(59, 130, 246, 0.08);
        border: 1px solid rgba(59, 130, 246, 0.15);
        cursor: pointer;
        opacity: 1;
        transition: all 0.2s ease;
        line-height: 1;
    }
    .translate-btn:hover {
        background: rgba(59, 130, 246, 0.18);
        border-color: rgba(59, 130, 246, 0.3);
        transform: scale(1.15);
    }

    /* --- Translation Result --- */
    .translate-result {
        margin-top: 6px;
        padding: 6px 8px;
        background: rgba(59, 130, 246, 0.06);
        border: 1px solid rgba(59, 130, 246, 0.15);
        border-radius: 8px;
        color: #334155;
    }

    /* --- Translation Language Picker --- */
    .translate-lang-popup {
        background: white;
        border-radius: 16px;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(0, 0, 0, 0.05);
        padding: 16px;
        width: 340px;
        max-height: 440px;
        display: flex;
        flex-direction: column;
    }
    .translate-lang-item {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px 10px;
        border-radius: 8px;
        border: 1px solid #f1f5f9;
        background: #fafbfc;
        cursor: pointer;
        transition: all 0.15s ease;
    }
    .translate-lang-item:hover {
        background: #eff6ff;
        border-color: #bfdbfe;
        transform: scale(1.02);
    }
</style>
