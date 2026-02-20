<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import { _ as t, locale } from '$lib/i18n';
    import { getEdgeFunctionUrl } from '$lib/utils/supabase';

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
        status: string;
        is_inside_24hr: boolean;
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
        created_at: string;
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

    onMount(async () => {
        const mod = await import('$lib/utils/supabase');
        supabase = mod.supabase;
        await loadAccount();
        refreshInterval = setInterval(refreshData, 5000);
    });

    onDestroy(() => {
        if (refreshInterval) clearInterval(refreshInterval);
    });

    async function loadAccount() {
        try {
            const { data } = await supabase.from('wa_accounts').select('id').eq('is_default', true).single();
            if (data) {
                accountId = data.id;
                await Promise.all([loadConversations(), loadTemplates()]);
            } else {
                loading = false;
            }
        } catch { loading = false; }
    }

    async function loadConversations() {
        try {
            const { data, error: err } = await supabase
                .from('wa_conversations')
                .select('*')
                .eq('wa_account_id', accountId)
                .eq('status', 'active')
                .order('last_message_at', { ascending: false });
            if (err) throw err;

            const now = new Date();
            conversations = (data || []).map((c: any) => {
                const lastMsg = c.last_message_at ? new Date(c.last_message_at) : null;
                const hrs = lastMsg ? (now.getTime() - lastMsg.getTime()) / 3600000 : Infinity;
                return { ...c, is_inside_24hr: hrs <= 24 };
            });
            applyFilters();

            // Auto-select conversation by initialPhone
            if (initialPhone && !selectedConv) {
                const match = conversations.find(c => c.customer_phone === initialPhone);
                if (match) {
                    await selectConversation(match);
                    initialPhone = ''; // only auto-select once
                }
            }
        } catch (e: any) {
            console.error(e);
        } finally {
            loading = false;
        }
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

    async function refreshData() {
        await loadConversations();
        if (selectedConv) {
            await loadMessages(selectedConv.id, true);
        }
    }

    function applyFilters() {
        let result = [...conversations];
        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            result = result.filter(c => c.customer_name?.toLowerCase().includes(q) || c.customer_phone.includes(q));
        }
        if (chatFilter === 'unread') result = result.filter(c => c.unread_count > 0);
        else if (chatFilter === 'ai') result = result.filter(c => c.is_bot_handling && c.bot_type === 'ai');
        else if (chatFilter === 'bot') result = result.filter(c => c.is_bot_handling && c.bot_type === 'auto_reply');
        else if (chatFilter === 'human') result = result.filter(c => !c.is_bot_handling);
        filteredConversations = result;
    }

    $: searchQuery, chatFilter, applyFilters();

    async function selectConversation(conv: Conversation) {
        selectedConv = conv;
        await loadMessages(conv.id);
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
            const { data } = await supabase
                .from('wa_messages')
                .select('id, direction, message_type, content, media_url, media_mime_type, template_name, status, sent_by, created_at')
                .eq('conversation_id', convId)
                .order('created_at', { ascending: true })
                .limit(200);
            messages = data || [];
            if (!silent) {
                setTimeout(() => scrollToBottom(), 100);
            }
        } catch {}
        if (!silent) loadingMessages = false;
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
            const { error: err } = await supabase.from('wa_messages').insert({
                conversation_id: selectedConv.id,
                wa_account_id: accountId,
                direction: 'outbound',
                message_type: 'text',
                content: messageInput.trim(),
                status: 'sending',
                sent_by: 'user'
            });
            if (err) throw err;

            // Call edge function to send via WhatsApp API
            const { data: accData } = await supabase.from('wa_accounts').select('phone_number_id, access_token').eq('id', accountId).single();
            if (accData) {
                const cleanPhone = selectedConv.customer_phone.replace(/[\s\-()]/g, '');
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
                        type: 'text',
                        text: { body: messageInput.trim() }
                    })
                });
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
            if (accData) {
                const cleanPhone = selectedConv.customer_phone.replace(/[\s\-()]/g, '');
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
                            name: template.name,
                            language: { code: template.language }
                        }
                    })
                });
            }

            // Save message record
            await supabase.from('wa_messages').insert({
                conversation_id: selectedConv.id,
                wa_account_id: accountId,
                direction: 'outbound',
                message_type: 'template',
                content: template.body_text,
                template_name: template.name,
                status: 'sent',
                sent_by: 'user'
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
            bot_type: null
        }).eq('id', selectedConv.id);
        selectedConv.is_bot_handling = false;
        selectedConv.bot_type = null;
        conversations = [...conversations];
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

            await fetch(`https://graph.facebook.com/v22.0/${accData.phone_number_id}/messages`, {
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
                status: 'sent',
                sent_by: 'user'
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

            await fetch(`https://graph.facebook.com/v22.0/${accData.phone_number_id}/messages`, {
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

            // 3. Save message to DB
            await supabase.from('wa_messages').insert({
                conversation_id: selectedConv.id,
                wa_account_id: accountId,
                direction: 'outbound',
                message_type: 'audio',
                content: '',
                media_url: publicUrl,
                media_mime_type: 'audio/ogg; codecs=opus',
                status: 'sent',
                sent_by: 'user'
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
</script>

<div class="h-full flex bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
    <!-- Left Panel: Conversation List -->
    <div class="w-96 flex flex-col border-r border-slate-200 bg-white">
        <!-- Search & Filters -->
        <div class="p-4 border-b border-slate-200 bg-emerald-600">
            <div class="flex items-center gap-2 mb-3">
                <span class="text-xl text-white">💬</span>
                <h2 class="text-sm font-black text-white uppercase tracking-wide">{$t('nav.whatsappLiveChat')}</h2>
            </div>
            <input type="text" bind:value={searchQuery} placeholder="Search conversations..."
                class="w-full px-3 py-2 bg-white/20 text-white placeholder-white/60 border border-white/20 rounded-xl text-xs focus:outline-none focus:bg-white/30" />
            <div class="flex gap-1 mt-2">
                {#each [
                    { id: 'all', label: 'All' },
                    { id: 'unread', label: '🔵 Unread' },
                    { id: 'ai', label: '🤖 AI' },
                    { id: 'bot', label: '🔧 Bot' },
                    { id: 'human', label: '👤 Human' }
                ] as f}
                    <button class="px-2 py-1 text-[9px] font-bold uppercase rounded-md transition-all
                        {chatFilter === f.id ? 'bg-white text-emerald-700' : 'text-white/80 hover:bg-white/20'}"
                        on:click={() => chatFilter = f.id}>
                        {f.label}
                    </button>
                {/each}
            </div>
        </div>

        <!-- Conversation List -->
        <div class="flex-1 overflow-y-auto">
            {#if loading}
                <div class="flex justify-center py-12">
                    <div class="animate-spin w-8 h-8 border-3 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                </div>
            {:else if filteredConversations.length === 0}
                <div class="text-center py-12 text-slate-400">
                    <div class="text-3xl mb-2">💬</div>
                    <p class="text-sm">No conversations yet</p>
                </div>
            {:else}
                {#each filteredConversations as conv}
                    <button class="w-full px-4 py-3 flex items-center gap-3 hover:bg-emerald-50/50 transition-colors border-b border-slate-100 text-left
                        {selectedConv?.id === conv.id ? 'bg-emerald-50 border-l-4 border-l-emerald-500' : ''}"
                        on:click={() => selectConversation(conv)}>
                        <!-- Avatar -->
                        <div class="relative flex-shrink-0">
                            <div class="w-12 h-12 bg-slate-100 rounded-full flex items-center justify-center text-lg font-bold text-slate-500">
                                {(conv.customer_name || '?')[0].toUpperCase()}
                            </div>
                            <span class="absolute -bottom-0.5 -right-0.5 text-sm">{conv.is_inside_24hr ? '🟢' : '🔴'}</span>
                        </div>
                        <!-- Info -->
                        <div class="flex-1 min-w-0">
                            <div class="flex items-center justify-between">
                                <span class="font-bold text-sm text-slate-800 truncate">{conv.customer_name || conv.customer_phone}</span>
                                <span class="text-[10px] text-slate-400 flex-shrink-0">{conv.last_message_at ? formatTime(conv.last_message_at) : ''}</span>
                            </div>
                            <div class="flex items-center justify-between mt-0.5">
                                <p class="text-xs text-slate-500 truncate">{conv.last_message_preview || 'No messages'}</p>
                                <div class="flex items-center gap-1 flex-shrink-0">
                                    {#if conv.is_bot_handling}
                                        <span class="text-[10px] px-1 py-0.5 rounded bg-purple-100 text-purple-600 font-bold">
                                            {conv.bot_type === 'ai' ? '🤖' : '🔧'}
                                        </span>
                                    {/if}
                                    {#if conv.unread_count > 0}
                                        <span class="w-5 h-5 bg-emerald-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
                                            {conv.unread_count}
                                        </span>
                                    {/if}
                                </div>
                            </div>
                        </div>
                    </button>
                {/each}
            {/if}
        </div>
    </div>

    <!-- Right Panel: Chat Area -->
    <div class="flex-1 flex flex-col bg-[#ECE5DD]">
        {#if selectedConv}
            <!-- Chat Header -->
            <div class="bg-emerald-600 text-white px-5 py-3 flex items-center justify-between shadow-sm">
                <div class="flex items-center gap-3">
                    <div class="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center font-bold">
                        {(selectedConv.customer_name || '?')[0].toUpperCase()}
                    </div>
                    <div>
                        <h3 class="font-bold text-sm">{selectedConv.customer_name || 'Unknown'}</h3>
                        <p class="text-emerald-100 text-xs font-mono">{selectedConv.customer_phone}</p>
                    </div>
                </div>
                <div class="flex items-center gap-2">
                    <span class="px-2 py-1 text-[10px] font-bold rounded-full {selectedConv.is_inside_24hr ? 'bg-emerald-500 text-white' : 'bg-red-500 text-white'}">
                        {selectedConv.is_inside_24hr ? '🟢 24hr Window' : '🔴 Templates Only'}
                    </span>
                    {#if selectedConv.is_bot_handling}
                        <button class="px-3 py-1.5 bg-white/20 text-white text-xs font-bold rounded-lg hover:bg-white/30"
                            on:click={takeOverFromBot}>
                            👤 Take Over
                        </button>
                    {/if}
                </div>
            </div>

            <!-- Messages Area -->
            <div class="flex-1 overflow-y-auto p-4 space-y-2" bind:this={messagesContainer}>
                {#if loadingMessages}
                    <div class="flex justify-center py-12">
                        <div class="animate-spin w-8 h-8 border-3 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                    </div>
                {:else if messages.length === 0}
                    <div class="text-center py-12">
                        <div class="text-4xl mb-3">💬</div>
                        <p class="text-slate-500 text-sm">No messages in this conversation</p>
                    </div>
                {:else}
                    {#each messages as msg}
                        <div class="flex {msg.direction === 'outbound' ? 'justify-end' : 'justify-start'}">
                            <div class="max-w-[65%] px-3 py-2 rounded-xl text-sm shadow-sm
                                {msg.direction === 'outbound'
                                    ? 'bg-[#DCF8C6] text-slate-800 rounded-tr-none'
                                    : 'bg-white text-slate-800 rounded-tl-none'}">
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
                                {#if msg.template_name}
                                    <span class="text-[10px] text-slate-400 italic">📝 {msg.template_name}</span>
                                {/if}
                                <div class="flex items-center justify-end gap-1 mt-1">
                                    <span class="text-[9px] text-slate-400">{formatMsgTime(msg.created_at)}</span>
                                    {#if msg.direction === 'outbound'}
                                        <span class="text-[10px] {msg.status === 'read' ? 'text-blue-500' : 'text-slate-400'}">{getStatusTick(msg.status)}</span>
                                    {/if}
                                    {#if msg.sent_by === 'ai_bot'}
                                        <span class="text-[9px] bg-purple-100 text-purple-600 px-1 rounded ml-1">🤖</span>
                                    {:else if msg.sent_by === 'auto_reply_bot'}
                                        <span class="text-[9px] bg-blue-100 text-blue-600 px-1 rounded ml-1">🔧</span>
                                    {/if}
                                </div>
                            </div>
                        </div>
                    {/each}
                {/if}
            </div>

            <!-- Input Area -->
            <div class="bg-white border-t border-slate-200 px-4 py-3">
                {#if !selectedConv.is_inside_24hr}
                    <!-- Outside 24hr — Templates only -->
                    <div class="flex items-center gap-3">
                        <p class="text-xs text-red-500 font-semibold">🔴 Outside 24-hour window. You can only send templates.</p>
                        <button class="px-4 py-2 bg-emerald-600 text-white text-xs font-bold rounded-xl hover:bg-emerald-700"
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
                            <button class="w-10 h-10 bg-emerald-500 text-white rounded-full flex items-center justify-center hover:bg-emerald-600 transition-colors"
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
                                <button class="w-10 h-10 bg-slate-100 rounded-full flex items-center justify-center text-lg hover:bg-slate-200 transition-colors"
                                    on:click={() => showAttachMenu = !showAttachMenu} title="Attach">
                                    📎
                                </button>
                                {#if showAttachMenu}
                                    <div class="absolute bottom-12 left-0 bg-white border border-slate-200 rounded-xl shadow-xl p-2 flex flex-col gap-1 min-w-[140px] z-50">
                                        <button class="flex items-center gap-2 px-3 py-2 text-xs text-slate-700 hover:bg-emerald-50 rounded-lg transition-colors"
                                            on:click={() => { imageInput.click(); showAttachMenu = false; }}>
                                            <span>📷</span> Photo
                                        </button>
                                        <button class="flex items-center gap-2 px-3 py-2 text-xs text-slate-700 hover:bg-emerald-50 rounded-lg transition-colors"
                                            on:click={() => { fileInput.click(); showAttachMenu = false; }}>
                                            <span>📄</span> Document / Video
                                        </button>
                                        <button class="flex items-center gap-2 px-3 py-2 text-xs text-slate-700 hover:bg-emerald-50 rounded-lg transition-colors"
                                            on:click={() => { showTemplatePicker = !showTemplatePicker; showAttachMenu = false; }}>
                                            <span>📝</span> Template
                                        </button>
                                    </div>
                                {/if}
                            </div>

                            <textarea bind:value={messageInput} rows="1"
                                placeholder="Type a message..."
                                class="flex-1 px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-2xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none max-h-24"
                                on:keydown={handleKeydown}></textarea>
                            {#if messageInput.trim()}
                                <button class="w-10 h-10 bg-emerald-500 text-white rounded-full flex items-center justify-center hover:bg-emerald-600 transition-colors disabled:opacity-50"
                                    on:click={sendMessage} disabled={sending}>
                                    {sending ? '⏳' : '➤'}
                                </button>
                            {:else}
                                <button class="w-10 h-10 bg-slate-100 rounded-full flex items-center justify-center text-lg hover:bg-slate-200 transition-colors"
                                    on:click={startRecording} title="Record voice message">
                                    🎤
                                </button>
                            {/if}
                        </div>
                    {/if}
                {/if}

                <!-- Template Picker Popup -->
                {#if showTemplatePicker}
                    <div class="mt-3 bg-white border border-slate-200 rounded-xl shadow-xl p-4 max-h-64 overflow-y-auto">
                        <div class="flex items-center justify-between mb-3">
                            <h4 class="text-xs font-bold text-slate-700 uppercase">Select Template</h4>
                            <button class="text-slate-400 hover:text-slate-600 text-sm" on:click={() => showTemplatePicker = false}>✕</button>
                        </div>
                        {#if templates.length === 0}
                            <p class="text-xs text-slate-400 text-center py-4">No approved templates available</p>
                        {:else}
                            <div class="space-y-2">
                                {#each templates as tmpl}
                                    <button class="w-full text-left px-3 py-2 bg-slate-50 rounded-lg hover:bg-emerald-50 transition-colors border border-slate-100"
                                        on:click={() => sendTemplate(tmpl)}>
                                        <p class="text-xs font-bold text-slate-700">{tmpl.name}</p>
                                        <p class="text-[10px] text-slate-500 truncate mt-0.5">{tmpl.body_text}</p>
                                        <span class="text-[9px] text-blue-500">{tmpl.language === 'ar' ? '🇸🇦' : '🇺🇸'} {tmpl.language.toUpperCase()}</span>
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
                    <div class="text-6xl mb-4">💬</div>
                    <h3 class="text-lg font-bold text-slate-600">WhatsApp Live Chat</h3>
                    <p class="text-sm text-slate-400 mt-1">Select a conversation to start chatting</p>
                </div>
            </div>
        {/if}
    </div>
</div>
