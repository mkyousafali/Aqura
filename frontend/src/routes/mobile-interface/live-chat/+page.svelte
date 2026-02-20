<script lang="ts">
	import { onMount, onDestroy, tick } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { currentLocale } from '$lib/i18n';

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

	let accountId = '';
	let conversations: Conversation[] = [];
	let filteredConversations: Conversation[] = [];
	let messages: Message[] = [];
	let templates: WATemplate[] = [];
	let loading = true;
	let loadingMessages = false;
	let sending = false;
	let selectedConv: Conversation | null = null;
	let searchQuery = '';
	let chatFilter = 'all';
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

	// View: 'list' or 'chat'
	let view: 'list' | 'chat' = 'list';

	$: isRTL = $currentLocale === 'ar';

	onMount(async () => {
		await loadAccount();
		refreshInterval = setInterval(refreshData, 5000);
	});

	onDestroy(() => {
		if (refreshInterval) clearInterval(refreshInterval);
		if (recordingTimer) clearInterval(recordingTimer);
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
		view = 'chat';
		await loadMessages(conv.id);
		if (conv.unread_count > 0) {
			await supabase.from('wa_conversations').update({ unread_count: 0 }).eq('id', conv.id);
			conv.unread_count = 0;
			conversations = [...conversations];
		}
	}

	function goBackToList() {
		view = 'list';
		selectedConv = null;
		messages = [];
		showTemplatePicker = false;
		showAttachMenu = false;
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
				await tick();
				scrollToBottom();
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
		if (!selectedConv.is_inside_24hr) return;

		sending = true;
		try {
			await supabase.from('wa_messages').insert({
				conversation_id: selectedConv.id,
				wa_account_id: accountId,
				direction: 'outbound',
				message_type: 'text',
				content: messageInput.trim(),
				status: 'sending',
				sent_by: 'user'
			});

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
		if (diffMins < 1) return isRTL ? 'الآن' : 'now';
		if (diffMins < 60) return `${diffMins}${isRTL ? 'د' : 'm'}`;
		const diffHrs = Math.floor(diffMs / 3600000);
		if (diffHrs < 24) return `${diffHrs}${isRTL ? 'س' : 'h'}`;
		return d.toLocaleDateString(isRTL ? 'ar-SA' : 'en-US', { month: 'short', day: 'numeric' });
	}

	function formatMsgTime(dateStr: string) {
		return new Date(dateStr).toLocaleTimeString(isRTL ? 'ar-SA' : 'en-US', { hour: '2-digit', minute: '2-digit' });
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

	// Media handling
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

	// Audio recording
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
			mediaRecorder.onstop = () => {
				// @ts-ignore
				mediaRecorder?.stream?.getTracks().forEach((t: MediaStreamTrack) => t.stop());
			};
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

			const fileName = `voice_${Date.now()}.ogg`;
			const filePath = `${accountId}/${selectedConv.id}/${fileName}`;
			const { error: uploadErr } = await supabase.storage.from('whatsapp-media').upload(filePath, blob, {
				contentType: 'audio/ogg; codecs=opus',
				upsert: false
			});
			if (uploadErr) throw uploadErr;

			const { data: urlData } = supabase.storage.from('whatsapp-media').getPublicUrl(filePath);
			const publicUrl = urlData?.publicUrl;

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

	function getUnreadTotal() {
		return conversations.reduce((sum, c) => sum + (c.unread_count || 0), 0);
	}
</script>

<div class="wa-mobile" class:rtl={isRTL}>
	{#if view === 'list'}
		<!-- ===== CONVERSATION LIST VIEW (WhatsApp Home) ===== -->
		<div class="wa-list-view">
			<!-- Top Bar -->
			<div class="wa-top-bar">
				<span class="wa-top-title">WhatsApp</span>
				<div class="wa-top-actions">
					<!-- Search toggle could go here -->
				</div>
			</div>

			<!-- Search Bar -->
			<div class="wa-search-bar">
				<div class="wa-search-input-wrap">
					<svg class="wa-search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="11" cy="11" r="8"/>
						<path d="m21 21-4.35-4.35"/>
					</svg>
					<input type="text" bind:value={searchQuery}
						placeholder={isRTL ? 'ابحث أو ابدأ محادثة جديدة' : 'Search or start a new chat'}
						class="wa-search-input" />
				</div>
			</div>

			<!-- Filter chips -->
			<div class="wa-filter-row">
				{#each [
					{ id: 'all', label: isRTL ? 'الكل' : 'All' },
					{ id: 'unread', label: isRTL ? 'غير مقروء' : 'Unread' },
					{ id: 'ai', label: '🤖 AI' },
					{ id: 'human', label: isRTL ? '👤 بشري' : '👤 Human' }
				] as f}
					<button class="wa-filter-chip" class:active={chatFilter === f.id}
						on:click={() => chatFilter = f.id}>
						{f.label}
					</button>
				{/each}
			</div>

			<!-- Conversation List -->
			<div class="wa-conv-list">
				{#if loading}
					<div class="wa-loading">
						<div class="wa-spinner"></div>
					</div>
				{:else if filteredConversations.length === 0}
					<div class="wa-empty">
						<div class="wa-empty-icon">💬</div>
						<p>{isRTL ? 'لا توجد محادثات' : 'No conversations yet'}</p>
					</div>
				{:else}
					{#each filteredConversations as conv}
						<button class="wa-conv-item" on:click={() => selectConversation(conv)}>
							<!-- Avatar -->
							<div class="wa-avatar">
								<span class="wa-avatar-letter">{(conv.customer_name || '?')[0].toUpperCase()}</span>
								<span class="wa-avatar-status" class:online={conv.is_inside_24hr}></span>
							</div>
							<!-- Content -->
							<div class="wa-conv-content">
								<div class="wa-conv-top">
									<span class="wa-conv-name">{conv.customer_name || conv.customer_phone}</span>
									<span class="wa-conv-time">{conv.last_message_at ? formatTime(conv.last_message_at) : ''}</span>
								</div>
								<div class="wa-conv-bottom">
									<p class="wa-conv-preview">
										{#if conv.is_bot_handling}
											<span class="wa-bot-badge">{conv.bot_type === 'ai' ? '🤖' : '🔧'}</span>
										{/if}
										{conv.last_message_preview || (isRTL ? 'لا توجد رسائل' : 'No messages')}
									</p>
									{#if conv.unread_count > 0}
										<span class="wa-unread-badge">{conv.unread_count > 99 ? '99+' : conv.unread_count}</span>
									{/if}
								</div>
							</div>
						</button>
					{/each}
				{/if}
			</div>
		</div>

	{:else}
		<!-- ===== CHAT VIEW (WhatsApp Chat) ===== -->
		<div class="wa-chat-view">
			<!-- Chat Header -->
			<div class="wa-chat-header">
				<button class="wa-back-btn" on:click={goBackToList}>
					<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
						{#if isRTL}
							<path d="M9 18l6-6-6-6"/>
						{:else}
							<path d="M15 18l-6-6 6-6"/>
						{/if}
					</svg>
				</button>
				<div class="wa-chat-header-avatar">
					<span>{(selectedConv?.customer_name || '?')[0].toUpperCase()}</span>
				</div>
				<div class="wa-chat-header-info">
					<h3 class="wa-chat-header-name">{selectedConv?.customer_name || (isRTL ? 'غير معروف' : 'Unknown')}</h3>
					<p class="wa-chat-header-phone">{selectedConv?.customer_phone || ''}</p>
				</div>
				<div class="wa-chat-header-actions">
					{#if selectedConv?.is_bot_handling}
						<button class="wa-takeover-btn" on:click={takeOverFromBot}>
							👤
						</button>
					{/if}
				</div>
			</div>

			<!-- 24hr Window Status -->
			{#if selectedConv && !selectedConv.is_inside_24hr}
				<div class="wa-window-banner">
					🔒 {isRTL ? 'خارج نافذة 24 ساعة - يمكن إرسال القوالب فقط' : 'Outside 24-hour window — Templates only'}
				</div>
			{/if}

			<!-- Messages -->
			<div class="wa-messages" bind:this={messagesContainer}>
				{#if loadingMessages}
					<div class="wa-loading">
						<div class="wa-spinner"></div>
					</div>
				{:else if messages.length === 0}
					<div class="wa-empty-chat">
						<div class="wa-empty-chat-box">
							<span>🔒</span>
							<p>{isRTL ? 'الرسائل مشفرة من طرف لطرف' : 'Messages are end-to-end encrypted'}</p>
						</div>
					</div>
				{:else}
					{#each messages as msg}
						<div class="wa-msg-row" class:outbound={msg.direction === 'outbound'} class:inbound={msg.direction !== 'outbound'}>
							<div class="wa-msg-bubble" class:wa-msg-out={msg.direction === 'outbound'} class:wa-msg-in={msg.direction !== 'outbound'}>
								<!-- Image -->
								{#if msg.message_type === 'image' && msg.media_url}
									<img src={msg.media_url} alt="" class="wa-msg-image" on:click={() => window.open(msg.media_url || '', '_blank')} />
								{/if}
								<!-- Audio / Voice -->
								{#if (msg.message_type === 'audio' || msg.message_type === 'voice') && msg.media_url}
									<audio controls preload="metadata" class="wa-msg-audio">
										<source src={msg.media_url} type={msg.media_mime_type || 'audio/ogg'} />
									</audio>
								{/if}
								<!-- Video -->
								{#if msg.message_type === 'video' && msg.media_url}
									<video controls preload="metadata" class="wa-msg-video">
										<source src={msg.media_url} type={msg.media_mime_type || 'video/mp4'} />
									</video>
								{/if}
								<!-- Sticker -->
								{#if msg.message_type === 'sticker' && msg.media_url}
									<img src={msg.media_url} alt="" class="wa-msg-sticker" />
								{/if}
								<!-- Document -->
								{#if msg.message_type === 'document' && msg.media_url}
									<a href={msg.media_url} target="_blank" class="wa-msg-doc">
										<span>📎</span>
										<span>{isRTL ? 'مستند' : 'Document'}</span>
									</a>
								{/if}
								<!-- Text content (hide [image], [audio] etc labels) -->
								{#if msg.content && !(['image','audio','voice','video','sticker'].includes(msg.message_type) && msg.media_url && /^\[.+\]$/.test(msg.content.trim()))}
									<p class="wa-msg-text">{msg.content}</p>
								{/if}
								{#if msg.template_name}
									<span class="wa-msg-template-tag">📝 {msg.template_name}</span>
								{/if}
								<!-- Meta -->
								<div class="wa-msg-meta">
									<span class="wa-msg-time">{formatMsgTime(msg.created_at)}</span>
									{#if msg.direction === 'outbound'}
										<span class="wa-msg-tick" class:read={msg.status === 'read'}>{getStatusTick(msg.status)}</span>
									{/if}
									{#if msg.sent_by === 'ai_bot'}
										<span class="wa-msg-bot-tag">🤖</span>
									{:else if msg.sent_by === 'auto_reply_bot'}
										<span class="wa-msg-bot-tag">🔧</span>
									{/if}
								</div>
							</div>
						</div>
					{/each}
				{/if}
			</div>

			<!-- Input Area -->
			<div class="wa-input-area">
				{#if selectedConv && !selectedConv.is_inside_24hr}
					<!-- Template-only mode -->
					<div class="wa-template-only">
						<button class="wa-template-only-btn" on:click={() => showTemplatePicker = !showTemplatePicker}>
							📝 {isRTL ? 'إرسال قالب' : 'Send Template'}
						</button>
					</div>
				{:else if isRecording}
					<!-- Recording UI -->
					<div class="wa-recording-bar">
						<button class="wa-rec-cancel" on:click={cancelRecording}>
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M3 6h18M8 6V4a1 1 0 011-1h6a1 1 0 011 1v2M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/></svg>
						</button>
						<div class="wa-rec-indicator">
							<span class="wa-rec-dot"></span>
							<span class="wa-rec-time">{formatRecordTime(recordingDuration)}</span>
						</div>
						<button class="wa-rec-send" on:click={stopRecording}>
							<svg width="20" height="20" viewBox="0 0 24 24" fill="white"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
						</button>
					</div>
				{:else}
					<div class="wa-input-row">
						<!-- Hidden file inputs -->
						<input type="file" accept="image/*" capture="environment" class="hidden" bind:this={imageInput} on:change={handleImageSelect} />
						<input type="file" accept="image/*,video/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip,.rar" class="hidden" bind:this={fileInput} on:change={handleFileSelect} />

						<!-- Attach -->
						<div class="wa-attach-wrap">
							<button class="wa-icon-btn" on:click={() => showAttachMenu = !showAttachMenu}>
								<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#54656F" stroke-width="2" stroke-linecap="round">
									<path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48"/>
								</svg>
							</button>
							{#if showAttachMenu}
								<div class="wa-attach-overlay" on:click={() => showAttachMenu = false}></div>
								<div class="wa-attach-popup">
									<button class="wa-attach-option" on:click={() => { imageInput.click(); showAttachMenu = false; }}>
										<span class="wa-attach-icon wa-attach-camera">📷</span>
										<span>{isRTL ? 'صورة' : 'Photo'}</span>
									</button>
									<button class="wa-attach-option" on:click={() => { fileInput.click(); showAttachMenu = false; }}>
										<span class="wa-attach-icon wa-attach-doc">📄</span>
										<span>{isRTL ? 'مستند / فيديو' : 'Document / Video'}</span>
									</button>
									<button class="wa-attach-option" on:click={() => { showTemplatePicker = !showTemplatePicker; showAttachMenu = false; }}>
										<span class="wa-attach-icon wa-attach-template">📝</span>
										<span>{isRTL ? 'قالب' : 'Template'}</span>
									</button>
								</div>
							{/if}
						</div>

						<!-- Text input -->
						<div class="wa-text-input-wrap">
							<textarea bind:value={messageInput} rows="1"
								placeholder={isRTL ? 'اكتب رسالة' : 'Type a message'}
								class="wa-text-input"
								on:keydown={handleKeydown}></textarea>
						</div>

						<!-- Send or Mic -->
						{#if messageInput.trim()}
							<button class="wa-send-btn" on:click={sendMessage} disabled={sending}>
								<svg width="20" height="20" viewBox="0 0 24 24" fill="white"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
							</button>
						{:else}
							<button class="wa-mic-btn" on:click={startRecording}>
								<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#54656F" stroke-width="2">
									<rect x="9" y="1" width="6" height="12" rx="3"/>
									<path d="M19 10v2a7 7 0 01-14 0v-2"/>
									<line x1="12" y1="19" x2="12" y2="23"/>
									<line x1="8" y1="23" x2="16" y2="23"/>
								</svg>
							</button>
						{/if}
					</div>
				{/if}

				<!-- Template Picker -->
				{#if showTemplatePicker}
					<div class="wa-template-picker">
						<div class="wa-template-picker-header">
							<span>{isRTL ? 'اختر قالب' : 'Select Template'}</span>
							<button on:click={() => showTemplatePicker = false}>✕</button>
						</div>
						{#if templates.length === 0}
							<p class="wa-template-empty">{isRTL ? 'لا توجد قوالب متاحة' : 'No templates available'}</p>
						{:else}
							<div class="wa-template-list">
								{#each templates as tmpl}
									<button class="wa-template-item" on:click={() => sendTemplate(tmpl)}>
										<p class="wa-template-name">{tmpl.name}</p>
										<p class="wa-template-body">{tmpl.body_text}</p>
										<span class="wa-template-lang">{tmpl.language === 'ar' ? '🇸🇦 AR' : '🇺🇸 EN'}</span>
									</button>
								{/each}
							</div>
						{/if}
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	/* ===== ROOT — WhatsApp Light Theme ===== */
	.wa-mobile {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		min-height: 100dvh;
		width: 100%;
		background: #FFFFFF;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
		overflow-x: hidden;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch;
		position: relative;
		padding-bottom: 4rem;
	}
	.wa-mobile.rtl { direction: rtl; }

	.hidden { display: none; }

	/* ===== LIST VIEW ===== */
	.wa-list-view {
		display: flex;
		flex-direction: column;
		min-height: 100vh;
		min-height: 100dvh;
	}

	/* Top Bar — WhatsApp teal header */
	.wa-top-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 14px 16px 8px;
		background: #008069;
	}
	.wa-top-title {
		font-size: 22px;
		font-weight: 700;
		color: #FFFFFF;
		letter-spacing: -0.3px;
	}

	/* Search */
	.wa-search-bar {
		padding: 8px 10px;
		background: #FFFFFF;
	}
	.wa-search-input-wrap {
		display: flex;
		align-items: center;
		background: #F0F2F5;
		border-radius: 8px;
		padding: 8px 12px;
		gap: 10px;
	}
	.wa-search-icon {
		flex-shrink: 0;
		color: #54656F;
	}
	.wa-search-input {
		flex: 1;
		background: transparent;
		border: none;
		outline: none;
		color: #111B21;
		font-size: 14px;
	}
	.wa-search-input::placeholder {
		color: #667781;
	}

	/* Filter chips */
	.wa-filter-row {
		display: flex;
		gap: 6px;
		padding: 4px 12px 10px;
		background: #FFFFFF;
		overflow-x: auto;
	}
	.wa-filter-chip {
		padding: 5px 14px;
		border-radius: 16px;
		background: #F0F2F5;
		color: #54656F;
		font-size: 12px;
		font-weight: 500;
		border: none;
		white-space: nowrap;
		cursor: pointer;
		transition: all 0.15s;
	}
	.wa-filter-chip.active {
		background: #D9FDD3;
		color: #008069;
		font-weight: 600;
	}

	/* Conversation list */
	.wa-conv-list {
		flex: 1;
		overflow-y: auto;
		background: #FFFFFF;
	}
	.wa-conv-item {
		display: flex;
		align-items: center;
		padding: 10px 16px;
		gap: 14px;
		width: 100%;
		border: none;
		background: transparent;
		cursor: pointer;
		text-align: start;
		border-bottom: 1px solid #F0F2F5;
		transition: background 0.15s;
	}
	.wa-conv-item:active {
		background: #F5F6F6;
	}

	/* Avatar */
	.wa-avatar {
		position: relative;
		flex-shrink: 0;
		width: 50px;
		height: 50px;
		border-radius: 50%;
		background: #DFE5E7;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.wa-avatar-letter {
		font-size: 20px;
		font-weight: 600;
		color: #54656F;
	}
	.wa-avatar-status {
		position: absolute;
		bottom: 1px;
		right: 1px;
		width: 12px;
		height: 12px;
		border-radius: 50%;
		border: 2px solid #FFFFFF;
		background: #D0D5D8;
	}
	.wa-avatar-status.online {
		background: #25D366;
	}

	/* Conv content */
	.wa-conv-content {
		flex: 1;
		min-width: 0;
	}
	.wa-conv-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 2px;
	}
	.wa-conv-name {
		font-size: 16px;
		font-weight: 500;
		color: #111B21;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.wa-conv-time {
		font-size: 12px;
		color: #667781;
		flex-shrink: 0;
		margin-inline-start: 8px;
	}
	.wa-conv-bottom {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}
	.wa-conv-preview {
		font-size: 14px;
		color: #667781;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		margin: 0;
		flex: 1;
	}
	.wa-bot-badge {
		font-size: 12px;
		margin-inline-end: 4px;
	}
	.wa-unread-badge {
		flex-shrink: 0;
		min-width: 20px;
		height: 20px;
		border-radius: 10px;
		background: #25D366;
		color: #FFFFFF;
		font-size: 11px;
		font-weight: 700;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 5px;
		margin-inline-start: 8px;
	}

	/* Loading / Empty */
	.wa-loading {
		display: flex;
		justify-content: center;
		padding: 60px 0;
	}
	.wa-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E9EDEF;
		border-top-color: #25D366;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	.wa-empty {
		text-align: center;
		padding: 60px 20px;
		color: #667781;
	}
	.wa-empty-icon {
		font-size: 48px;
		margin-bottom: 12px;
	}
	.wa-empty p {
		font-size: 14px;
	}

	/* ===== CHAT VIEW ===== */
	.wa-chat-view {
		position: fixed;
		top: calc(1.6rem + 40px + env(safe-area-inset-top));
		left: 0;
		right: 0;
		bottom: 3.6rem;
		display: flex;
		flex-direction: column;
		background: #EFEAE2;
		overflow: hidden;
		z-index: 99;
	}

	/* Chat Header — teal */
	.wa-chat-header {
		display: flex;
		align-items: center;
		padding: 6px 6px 6px 4px;
		background: #008069;
		gap: 8px;
		min-height: 56px;
		flex-shrink: 0;
	}
	.wa-back-btn {
		background: none;
		border: none;
		padding: 6px;
		color: #FFFFFF;
		cursor: pointer;
		display: flex;
		align-items: center;
	}
	.wa-chat-header-avatar {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		background: rgba(255,255,255,0.25);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}
	.wa-chat-header-avatar span {
		font-size: 18px;
		font-weight: 600;
		color: #FFFFFF;
	}
	.wa-chat-header-info {
		flex: 1;
		min-width: 0;
	}
	.wa-chat-header-name {
		font-size: 16px;
		font-weight: 600;
		color: #FFFFFF;
		margin: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.wa-chat-header-phone {
		font-size: 12px;
		color: rgba(255,255,255,0.8);
		margin: 0;
	}
	.wa-chat-header-actions {
		display: flex;
		gap: 4px;
	}
	.wa-takeover-btn {
		background: rgba(255,255,255,0.2);
		border: none;
		border-radius: 50%;
		width: 36px;
		height: 36px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 18px;
	}

	/* 24hr window banner */
	.wa-window-banner {
		padding: 6px 16px;
		background: #FFF3CD;
		color: #856404;
		font-size: 12px;
		text-align: center;
		border-bottom: 1px solid #E9EDEF;
		flex-shrink: 0;
	}

	/* Messages area — WhatsApp beige doodle background */
	.wa-messages {
		flex: 1;
		overflow-y: auto;
		overflow-x: hidden;
		-webkit-overflow-scrolling: touch;
		padding: 8px 12px;
		min-height: 0;
		background-image: url("data:image/svg+xml,%3Csvg width='200' height='200' viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='%23D6CFC4' fill-opacity='0.35'%3E%3Ccircle cx='30' cy='30' r='1.5'/%3E%3Ccircle cx='90' cy='45' r='1'/%3E%3Ccircle cx='150' cy='20' r='1.3'/%3E%3Ccircle cx='50' cy='100' r='1'/%3E%3Ccircle cx='120' cy='90' r='1.5'/%3E%3Ccircle cx='170' cy='120' r='1'/%3E%3Ccircle cx='40' cy='160' r='1.2'/%3E%3Ccircle cx='100' cy='150' r='1'/%3E%3Ccircle cx='160' cy='170' r='1.3'/%3E%3C/g%3E%3C/svg%3E");
		background-color: #EFEAE2;
	}

	.wa-msg-row {
		display: flex;
		margin-bottom: 3px;
	}
	.wa-msg-row.outbound { justify-content: flex-end; }
	.wa-msg-row.inbound { justify-content: flex-start; }

	.wa-msg-bubble {
		max-width: 80%;
		padding: 6px 8px 4px;
		border-radius: 8px;
		position: relative;
		word-break: break-word;
		box-shadow: 0 1px 0.5px rgba(11,20,26,0.13);
	}
	.wa-msg-out {
		background: #D9FDD3;
		color: #111B21;
		border-top-right-radius: 0;
	}
	.rtl .wa-msg-out {
		border-top-right-radius: 8px;
		border-top-left-radius: 0;
	}
	.wa-msg-in {
		background: #FFFFFF;
		color: #111B21;
		border-top-left-radius: 0;
	}
	.rtl .wa-msg-in {
		border-top-left-radius: 8px;
		border-top-right-radius: 0;
	}

	.wa-msg-text {
		margin: 0;
		font-size: 14.5px;
		line-height: 1.4;
		white-space: pre-wrap;
	}

	.wa-msg-image {
		max-width: 220px;
		max-height: 220px;
		border-radius: 6px;
		margin-bottom: 4px;
		cursor: pointer;
		object-fit: cover;
	}
	.wa-msg-audio {
		width: 220px;
		max-width: 100%;
		height: 36px;
		margin-bottom: 2px;
	}
	.wa-msg-video {
		max-width: 100%;
		max-height: 200px;
		border-radius: 6px;
		margin-bottom: 4px;
	}
	.wa-msg-sticker {
		max-width: 120px;
		height: auto;
	}
	.wa-msg-doc {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 12px;
		background: rgba(0,0,0,0.04);
		border-radius: 6px;
		margin-bottom: 4px;
		color: #027EB5;
		font-size: 13px;
		text-decoration: none;
	}

	.wa-msg-template-tag {
		font-size: 11px;
		color: #667781;
		font-style: italic;
		display: block;
		margin-top: 2px;
	}
	.wa-msg-meta {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		gap: 3px;
		margin-top: 1px;
	}
	.wa-msg-time {
		font-size: 11px;
		color: #667781;
	}
	.wa-msg-tick {
		font-size: 12px;
		color: #667781;
	}
	.wa-msg-tick.read {
		color: #53BDEB;
	}
	.wa-msg-bot-tag {
		font-size: 10px;
		background: rgba(0,0,0,0.06);
		padding: 0 3px;
		border-radius: 3px;
		color: #667781;
	}

	.wa-empty-chat {
		display: flex;
		justify-content: center;
		padding: 40px 16px;
	}
	.wa-empty-chat-box {
		background: rgba(255,255,224,0.9);
		border-radius: 8px;
		padding: 10px 20px;
		text-align: center;
		color: #54656F;
		font-size: 12px;
		box-shadow: 0 1px 0.5px rgba(11,20,26,0.13);
	}
	.wa-empty-chat-box span {
		font-size: 18px;
	}
	.wa-empty-chat-box p {
		margin: 4px 0 0;
	}

	/* ===== INPUT AREA ===== */
	.wa-input-area {
		background: #F0F2F5;
		padding: 6px 6px;
		padding-bottom: calc(6px + env(safe-area-inset-bottom));
		border-top: 1px solid #E9EDEF;
		flex-shrink: 0;
	}
	.wa-input-row {
		display: flex;
		align-items: flex-end;
		gap: 4px;
	}

	.wa-icon-btn {
		background: none;
		border: none;
		padding: 8px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
	}
	.wa-icon-btn:active {
		background: rgba(0,0,0,0.06);
	}

	.wa-text-input-wrap {
		flex: 1;
	}
	.wa-text-input {
		width: 100%;
		background: #FFFFFF;
		border: none;
		border-radius: 20px;
		padding: 10px 16px;
		color: #111B21;
		font-size: 15px;
		outline: none;
		resize: none;
		line-height: 1.35;
		max-height: 100px;
	}
	.wa-text-input::placeholder {
		color: #667781;
	}

	.wa-send-btn {
		width: 42px;
		height: 42px;
		border-radius: 50%;
		background: #00A884;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		flex-shrink: 0;
		transition: background 0.15s;
	}
	.wa-send-btn:active { background: #008f72; }
	.wa-send-btn:disabled { opacity: 0.5; }

	.wa-mic-btn {
		width: 42px;
		height: 42px;
		border-radius: 50%;
		background: none;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		flex-shrink: 0;
	}
	.wa-mic-btn:active {
		background: rgba(0,0,0,0.06);
	}

	/* Attach popup */
	.wa-attach-wrap {
		position: relative;
	}
	.wa-attach-overlay {
		position: fixed;
		inset: 0;
		z-index: 40;
	}
	.wa-attach-popup {
		position: absolute;
		bottom: 50px;
		left: 0;
		background: #FFFFFF;
		border-radius: 14px;
		padding: 8px;
		display: flex;
		flex-direction: column;
		gap: 2px;
		min-width: 180px;
		z-index: 50;
		box-shadow: 0 4px 16px rgba(0,0,0,0.15);
	}
	.rtl .wa-attach-popup {
		left: auto;
		right: 0;
	}
	.wa-attach-option {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 10px 14px;
		border: none;
		background: transparent;
		color: #111B21;
		font-size: 14px;
		cursor: pointer;
		border-radius: 8px;
		text-align: start;
	}
	.wa-attach-option:active {
		background: #F0F2F5;
	}
	.wa-attach-icon {
		font-size: 20px;
	}

	/* Recording */
	.wa-recording-bar {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 4px;
	}
	.wa-rec-cancel {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		background: none;
		border: none;
		color: #ef4444;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
	}
	.wa-rec-indicator {
		flex: 1;
		display: flex;
		align-items: center;
		gap: 8px;
		background: #FFFFFF;
		border-radius: 20px;
		padding: 10px 16px;
	}
	.wa-rec-dot {
		width: 10px;
		height: 10px;
		border-radius: 50%;
		background: #ef4444;
		animation: pulse 1s infinite;
	}
	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.3; }
	}
	.wa-rec-time {
		font-size: 15px;
		color: #111B21;
		font-variant-numeric: tabular-nums;
	}
	.wa-rec-send {
		width: 42px;
		height: 42px;
		border-radius: 50%;
		background: #00A884;
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
	}

	/* Template only mode */
	.wa-template-only {
		text-align: center;
		padding: 4px;
	}
	.wa-template-only-btn {
		width: 100%;
		padding: 12px;
		border-radius: 20px;
		background: #00A884;
		color: #fff;
		font-size: 14px;
		font-weight: 600;
		border: none;
		cursor: pointer;
	}
	.wa-template-only-btn:active {
		background: #008f72;
	}

	/* Template picker */
	.wa-template-picker {
		background: #FFFFFF;
		border-radius: 12px;
		margin-top: 6px;
		max-height: 50vh;
		overflow-y: auto;
		box-shadow: 0 4px 16px rgba(0,0,0,0.12);
	}
	.wa-template-picker-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 12px 16px;
		border-bottom: 1px solid #E9EDEF;
		color: #111B21;
		font-size: 14px;
		font-weight: 600;
	}
	.wa-template-picker-header button {
		background: none;
		border: none;
		color: #667781;
		font-size: 18px;
		cursor: pointer;
	}
	.wa-template-empty {
		padding: 24px;
		text-align: center;
		color: #667781;
		font-size: 13px;
	}
	.wa-template-list {
		padding: 4px;
	}
	.wa-template-item {
		width: 100%;
		text-align: start;
		padding: 10px 14px;
		border: none;
		background: transparent;
		border-bottom: 1px solid #E9EDEF;
		cursor: pointer;
	}
	.wa-template-item:active {
		background: #F0F2F5;
	}
	.wa-template-name {
		font-size: 14px;
		font-weight: 600;
		color: #111B21;
		margin: 0;
	}
	.wa-template-body {
		font-size: 12px;
		color: #667781;
		margin: 3px 0 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.wa-template-lang {
		font-size: 11px;
		color: #027EB5;
	}
</style>
