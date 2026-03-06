<script lang="ts">
	import { onMount, onDestroy, tick } from 'svelte';
	import { goto } from '$app/navigation';
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

	// Pagination for conversations
	const CONV_PAGE_SIZE = 50;
	let convTotalCount = 0;
	let loadingMoreConvs = false;

	// Pagination for messages
	const MSG_PAGE_SIZE = 50;
	let hasMoreMessages = false;
	let loadingOlderMessages = false;

	// Realtime subscriptions
	let msgSubscription: any = null;

	// Debounce for search
	let searchDebounceTimer: any = null;

	// Audio recording
	let isRecording = false;
	let mediaRecorder: MediaRecorder | null = null;
	let audioChunks: Blob[] = [];
	let recordingDuration = 0;
	let recordingTimer: any = null;

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

	// File inputs
	let imageInput: HTMLInputElement;
	let fileInput: HTMLInputElement;
	let showAttachMenu = false;

	// Input text transform & translate
	let isInputTransforming = false;
	let showInputTranslatePicker = false;
	let inputTranslateLangSearch = '';
	let isInputTranslating = false;

	$: filteredInputTranslateLangs = translateLanguages.filter(l =>
		!inputTranslateLangSearch || l.name.toLowerCase().includes(inputTranslateLangSearch.toLowerCase()) || l.code.includes(inputTranslateLangSearch.toLowerCase())
	);

	// WhatsApp account info
	let waAccountName = '';
	let waProfilePicUrl = '';

	// View: 'list' or 'chat'
	let view: 'list' | 'chat' = 'list';

	$: isRTL = $currentLocale === 'ar';

	onMount(async () => {
		await loadAccount();
		// Light poll every 8s (just conversations, not messages)
		refreshInterval = setInterval(refreshConversationsOnly, 8000);
	});

	onDestroy(() => {
		if (refreshInterval) clearInterval(refreshInterval);
		if (recordingTimer) clearInterval(recordingTimer);
		if (msgSubscription) msgSubscription.unsubscribe();
	});

	async function loadAccount() {
		try {
			const { data } = await supabase.from('wa_accounts').select('id, display_name, phone_number_id, access_token').eq('is_default', true).single();
			if (data) {
				accountId = data.id;
				waAccountName = data.display_name || '';
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
				await Promise.all([loadConversations(), loadTemplates()]);
			} else {
				loading = false;
			}
		} catch { loading = false; }
	}

	async function loadConversations(append = false) {
		try {
			const offset = append ? conversations.length : 0;

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
			// Sort with SOS active conversations at the top
			filteredConversations = [...conversations].sort((a, b) => {
				if (a.is_sos && !b.is_sos) return -1;
				if (!a.is_sos && b.is_sos) return 1;
				return 0;
			});
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

	// Light refresh — only reload conversation list (not messages)
	async function refreshConversationsOnly() {
		await loadConversations();
	}

	// Subscribe to realtime for the selected conversation's messages
	function subscribeToMessages(convId: string) {
		if (msgSubscription) msgSubscription.unsubscribe();
		msgSubscription = supabase
			.channel(`wa_messages_mobile_${convId}`)
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
		if (accountId) {
			if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
			searchDebounceTimer = setTimeout(() => loadConversations(), 300);
		}
	}

	async function selectConversation(conv: Conversation) {
		selectedConv = conv;
		view = 'chat';
		await loadMessages(conv.id);
		// Subscribe to realtime messages for this conversation
		subscribeToMessages(conv.id);
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
		if (msgSubscription) { msgSubscription.unsubscribe(); msgSubscription = null; }
	}

	async function loadMessages(convId: string, silent = false) {
		if (!silent) loadingMessages = true;
		try {
			const { data } = await supabase
				.from('wa_messages')
				.select('id, direction, message_type, content, media_url, media_mime_type, template_name, status, sent_by, sent_by_user_id, metadata, created_at')
				.eq('conversation_id', convId)
				.order('created_at', { ascending: false })
				.limit(MSG_PAGE_SIZE + 1);
			const rows = data || [];
			hasMoreMessages = rows.length > MSG_PAGE_SIZE;
			messages = (hasMoreMessages ? rows.slice(0, MSG_PAGE_SIZE) : rows).reverse();
			await loadUserNames(messages);
			if (!silent) {
				loadingMessages = false;
				await tick();
				scrollToBottom();
				setTimeout(() => scrollToBottom(), 100);
			}
		} catch {}
		if (!silent) loadingMessages = false;
	}

	async function loadOlderMessages() {
		if (!selectedConv || loadingOlderMessages || !hasMoreMessages || messages.length === 0) return;
		loadingOlderMessages = true;
		try {
			const oldestMsg = messages[0];
			const { data } = await supabase
				.from('wa_messages')
				.select('id, direction, message_type, content, media_url, media_mime_type, template_name, status, sent_by, sent_by_user_id, metadata, created_at')
				.eq('conversation_id', selectedConv.id)
				.lt('created_at', oldestMsg.created_at)
				.order('created_at', { ascending: false })
				.limit(MSG_PAGE_SIZE + 1);
			const rows = data || [];
			hasMoreMessages = rows.length > MSG_PAGE_SIZE;
			const olderMsgs = (hasMoreMessages ? rows.slice(0, MSG_PAGE_SIZE) : rows).reverse();
			await loadUserNames(olderMsgs);
			const container = messagesContainer;
			const prevHeight = container?.scrollHeight || 0;
			messages = [...olderMsgs, ...messages];
			setTimeout(() => {
				if (container) container.scrollTop = container.scrollHeight - prevHeight;
			}, 50);
		} catch {}
		loadingOlderMessages = false;
	}

	async function loadUserNames(msgs: Message[]) {
		const userIds = [...new Set(msgs.filter((m: Message) => m.sent_by_user_id && !userNameCache[m.sent_by_user_id]).map((m: Message) => m.sent_by_user_id))];
		if (userIds.length > 0) {
			const { data: employees } = await supabase.from('hr_employee_master').select('user_id, name_en, name_ar').in('user_id', userIds);
			if (employees) {
				for (const emp of employees) {
					userNameCache[emp.user_id] = (isRTL ? emp.name_ar : emp.name_en) || emp.name_en || emp.name_ar || 'User';
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
		if (!selectedConv.is_inside_24hr) return;

		sending = true;
		try {
			const { data: insertedMsg, error: insertErr } = await supabase.from('wa_messages').insert({
				conversation_id: selectedConv.id,
				wa_account_id: accountId,
				direction: 'outbound',
				message_type: 'text',
				content: messageInput.trim(),
				status: 'sending',
				sent_by: 'user',
				sent_by_user_id: $currentUser?.id || null
			}).select('id').single();
			if (insertErr) throw insertErr;

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

	function getUnreadTotal() {
		return conversations.reduce((sum, c) => sum + (c.unread_count || 0), 0);
	}

	// Translation functions
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

<div class="wa-mobile" class:rtl={isRTL}>
	{#if view === 'list'}
		<!-- ===== CONVERSATION LIST VIEW (WhatsApp Home) ===== -->
		<div class="wa-list-view">
			<!-- Account Header -->
			{#if waAccountName || waProfilePicUrl}
			<div class="wa-account-header">
				{#if waProfilePicUrl}
					<img src={waProfilePicUrl} alt="" class="wa-account-pic" />
				{:else}
					<div class="wa-account-icon">💬</div>
				{/if}
				{#if waAccountName}
					<span class="wa-account-name">{waAccountName}</span>
				{/if}
			</div>
			{/if}
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
					{ id: 'unread', label: isRTL ? 'غير مقروء' : 'Unread' }
				] as f}
					<button class="wa-filter-chip" class:active={chatFilter === f.id}
						on:click={() => chatFilter = f.id}>
						{f.label}
					</button>
				{/each}
			</div>

			<!-- Conversation List -->
			<div class="wa-conv-list" on:scroll={(e) => {
				const el = e.currentTarget;
				if (el.scrollHeight - el.scrollTop - el.clientHeight < 100) {
					loadMoreConversations();
				}
			}}>
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
						<div role="button" tabindex="0" class="wa-conv-item" on:click={() => selectConversation(conv)} on:keydown={(e) => e.key === 'Enter' && selectConversation(conv)}>
							<!-- Avatar -->
							<div class="wa-avatar" style="background:{avatarColor(conv.customer_name || conv.customer_phone)}">
								<span class="wa-avatar-letter" style="color:#fff">{(conv.customer_name || '?')[0].toUpperCase()}</span>
								<span class="wa-avatar-status" class:online={conv.is_inside_24hr}></span>
							</div>
							<!-- Content -->
							<div class="wa-conv-content">
								<div class="wa-conv-top">
									<span class="wa-conv-name">{conv.customer_name || conv.customer_phone}</span>
									<span class="wa-conv-time">{conv.last_message_at ? formatTime(conv.last_message_at) : ''}</span>
								</div>
								<div class="wa-conv-bottom">
									<p class="wa-conv-preview">{conv.last_message_preview || (isRTL ? 'لا توجد رسائل' : 'No messages')}</p>
									<div class="wa-conv-badges">
										<!-- Badge 1: Last handler -->
										{#if (conv as any).handled_by === 'human'}
											<span class="wa-mbadge wa-mbadge-human">👤</span>
										{:else if (conv as any).handled_by === 'auto_reply'}
											<span class="wa-mbadge wa-mbadge-auto">🔧</span>
										{:else if (conv as any).handled_by === 'bot' || (conv as any).handled_by === 'ai_bot'}
											<span class="wa-mbadge wa-mbadge-ai">🤖</span>
										{/if}
										<!-- Badge 2: AI on/off -->
										{#if conv.is_bot_handling}
											<span role="button" tabindex="0" class="wa-mbadge wa-mbadge-aion" on:click|stopPropagation={() => toggleAI(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleAI(conv)}>🟢</span>
										{:else}
											<span role="button" tabindex="0" class="wa-mbadge wa-mbadge-aioff" on:click|stopPropagation={() => toggleAI(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleAI(conv)}>🔴</span>
										{/if}
										<!-- Badge 3: Needs help -->
										{#if conv.needs_human}
											<span role="button" tabindex="0" class="wa-mbadge wa-mbadge-help" on:click|stopPropagation={() => resolveHelp(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && resolveHelp(conv)}>🆘</span>
										{/if}
										<!-- Badge 4: SOS mode -->
										{#if conv.is_sos}
											<span role="button" tabindex="0" class="wa-mbadge wa-mbadge-sos-active" on:click|stopPropagation={() => toggleSOS(conv)} on:keydown|stopPropagation={(e) => e.key === 'Enter' && toggleSOS(conv)}>SOS</span>
										{/if}
										{#if conv.unread_count > 0}
											<span class="wa-unread-badge">{conv.unread_count > 99 ? '99+' : conv.unread_count}</span>
										{/if}
									</div>
								</div>
							</div>
						</div>
					{/each}
					{#if loadingMoreConvs}
						<div class="wa-loading" style="padding: 12px 0;">
							<div class="wa-spinner" style="width: 20px; height: 20px;"></div>
						</div>
					{:else if conversations.length < convTotalCount}
						<button class="wa-load-more-btn" on:click={loadMoreConversations}>
							{isRTL ? `تحميل المزيد (${convTotalCount - conversations.length} متبقي)` : `Load more (${convTotalCount - conversations.length} remaining)`}
						</button>
					{/if}
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
				<div class="wa-chat-header-avatar" style="background:{avatarColor(selectedConv?.customer_name || selectedConv?.customer_phone || '?')}">
					<span>{(selectedConv?.customer_name || '?')[0].toUpperCase()}</span>
				</div>
				<div class="wa-chat-header-info">
					<h3 class="wa-chat-header-name">{selectedConv?.customer_name || (isRTL ? 'غير معروف' : 'Unknown')}</h3>
					<p class="wa-chat-header-phone">{selectedConv?.customer_phone || ''}</p>
				</div>
				<div class="wa-chat-header-actions">
					{#if selectedConv?.needs_human}
						<button class="wa-header-badge wa-hbadge-help" on:click={() => resolveHelp(selectedConv)} title={isRTL ? 'حل وإعادة الذكاء' : 'Resolve & re-enable AI'}>🆘</button>
					{/if}
					{#if selectedConv?.is_sos}
						<button class="wa-header-badge wa-hbadge-sos-active" on:click={() => toggleSOS(selectedConv)} title={isRTL ? 'إزالة وضع SOS' : 'Remove SOS Mode'}>SOS</button>
					{:else}
						<button class="wa-header-badge wa-hbadge-sos" on:click={() => toggleSOS(selectedConv)} title={isRTL ? 'تفعيل وضع SOS' : 'Enable SOS Mode'}>SOS</button>
					{/if}
					{#if selectedConv?.is_bot_handling}
						<button class="wa-header-badge wa-hbadge-aion" on:click={() => toggleAI(selectedConv)} title={isRTL ? 'إيقاف الذكاء' : 'Pause AI'}>🤖</button>
					{:else}
						<button class="wa-header-badge wa-hbadge-aioff" on:click={() => toggleAI(selectedConv)} title={isRTL ? 'تفعيل الذكاء' : 'Enable AI'}>🤖</button>
					{/if}
					<button class="wa-incident-btn" on:click={() => goto(`/mobile-interface/report-incident?type=IN1&name=${encodeURIComponent(selectedConv?.customer_name || '')}&phone=${encodeURIComponent(selectedConv?.customer_phone || '')}`)} title={isRTL ? 'الإبلاغ عن حادثة' : 'Report Incident'}>
						🚨
					</button>
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
			<div class="wa-messages" bind:this={messagesContainer}
				on:scroll={(e) => {
					const el = e.currentTarget;
					if (el.scrollTop < 80 && hasMoreMessages && !loadingOlderMessages) {
						loadOlderMessages();
					}
				}}>
				{#if loadingMessages}
					<div class="wa-loading">
						<div class="wa-spinner"></div>
					</div>
				{:else}
				{#if hasMoreMessages}
					<div style="display:flex;justify-content:center;padding:8px 0">
						{#if loadingOlderMessages}
							<div class="wa-spinner" style="width:20px;height:20px"></div>
						{:else}
							<button style="padding:4px 12px;border-radius:16px;font-size:11px;font-weight:600;background:#fff;color:#64748b;border:1px solid #e2e8f0" on:click={loadOlderMessages}>⬆️ {isRTL ? 'تحميل رسائل أقدم' : 'Load older messages'}</button>
						{/if}
					</div>
				{/if}
				{#if messages.length === 0}
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
								<!-- Sender label -->
								{#if msg.direction === 'outbound'}
									{#if msg.sent_by === 'ai_bot'}
										<div class="wa-sender-label" style="color: #7c3aed;">🤖 {isRTL ? 'بوت الذكاء الاصطناعي' : 'AI Bot'}</div>
									{:else if msg.sent_by === 'auto_reply' || msg.sent_by === 'auto_reply_bot'}
										<div class="wa-sender-label" style="color: #2563eb;">🔧 {isRTL ? 'بوت الرد التلقائي' : 'Auto Reply Bot'}</div>
									{:else if msg.sent_by === 'user' && msg.sent_by_user_id}
										<div class="wa-sender-label" style="color: #15803d;">👤 {userNameCache[msg.sent_by_user_id] || (isRTL ? 'مستخدم' : 'User')}</div>
									{:else if msg.sent_by === 'user'}
										<div class="wa-sender-label" style="color: #15803d;">👤 {isRTL ? 'مستخدم' : 'User'}</div>
									{/if}
								{/if}
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
								<!-- Interactive buttons -->
								{#if msg.message_type === 'interactive' && msg.metadata}
									{#if msg.metadata.interactive_type === 'button' && msg.metadata.buttons?.length}
										<div class="wa-interactive-buttons">
											{#each msg.metadata.buttons as btn}
												<div class="wa-interactive-btn">{btn.title}</div>
											{/each}
										</div>
									{:else if msg.metadata.interactive_type === 'cta_url' && msg.metadata.url}
										<div class="wa-interactive-buttons">
											<a href={msg.metadata.url} target="_blank" class="wa-interactive-btn wa-cta-link">🔗 {msg.metadata.display_text || 'Open Link'}</a>
										</div>
									{/if}
								{/if}
								{#if msg.template_name}
									<span class="wa-msg-template-tag">📝 {msg.template_name}</span>
								{/if}
								<!-- Translation -->
								{#if translatedMessages[msg.id]}
									<div class="wa-translate-result">
										<div class="wa-translate-result-header">
											<span class="wa-translate-label">🌐 {isRTL ? 'ترجمة' : 'Translation'}</span>
											<button class="wa-translate-clear" on:click={() => clearTranslation(msg.id)}>✕</button>
										</div>
										<p class="wa-translate-text">{translatedMessages[msg.id]}</p>
									</div>
								{/if}
								{#if translatingMsgId === msg.id}
									<div class="wa-translating">
										<span class="wa-translating-spinner"></span>
										{isRTL ? 'جاري الترجمة...' : 'Translating...'}
									</div>
								{/if}
								<!-- Meta -->
								<div class="wa-msg-meta">
									{#if msg.content?.trim() && !translatedMessages[msg.id]}
										<button class="wa-translate-btn" on:click={() => openTranslatePicker(msg.id)} title={isRTL ? 'ترجمة' : 'Translate'}>🌐</button>
									{/if}
									<span class="wa-msg-time">{formatMsgTime(msg.created_at)}</span>
									{#if msg.direction === 'outbound'}
										<span class="wa-msg-tick" class:read={msg.status === 'read'}>{getStatusTick(msg.status)}</span>
									{/if}
								</div>
							</div>
						</div>
					{/each}
				{/if}
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
								on:keydown={handleKeydown}
								on:input={autoResize}></textarea>
						</div>

						<!-- Send or Mic -->
						{#if messageInput.trim()}
							<!-- Transform button -->
							<button class="wa-transform-btn" on:click={transformInputText} disabled={isInputTransforming}
								title={isRTL ? 'إصلاح القواعد والإملاء' : 'Fix grammar & spelling'}>
								{isInputTransforming ? '⏳' : '✨'}
							</button>
							<!-- Translate button -->
							<button class="wa-translate-input-btn" on:click={() => { inputTranslateLangSearch = ''; showInputTranslatePicker = true; }} disabled={isInputTranslating}
								title={isRTL ? 'ترجمة النص' : 'Translate text'}>
								{isInputTranslating ? '⏳' : '🌐'}
							</button>
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

	<!-- Translation Language Picker Popup -->
	{#if showInputTranslatePicker}
		<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
		<div class="wa-translate-overlay" on:click={() => { showInputTranslatePicker = false; }}>
			<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
			<div class="wa-translate-popup" on:click|stopPropagation>
				<div class="wa-translate-popup-header">
					<h4>🌐 {isRTL ? 'ترجم النص إلى' : 'Translate text to'}</h4>
					<button on:click={() => { showInputTranslatePicker = false; }}>✕</button>
				</div>
				<input type="text" bind:value={inputTranslateLangSearch} placeholder={isRTL ? 'بحث عن لغة...' : 'Search language...'}
					class="wa-translate-search" />
				<div class="wa-translate-lang-grid">
					{#each filteredInputTranslateLangs as lang}
						<button class="wa-translate-lang-item" on:click={() => translateInputText(lang.code)}>
							<span class="wa-translate-lang-flag">{lang.flag}</span>
							<span class="wa-translate-lang-name">{lang.name}</span>
						</button>
					{/each}
					{#if filteredInputTranslateLangs.length === 0}
						<p class="wa-translate-no-results">{isRTL ? 'لم يتم العثور على لغات' : 'No languages found'}</p>
					{/if}
				</div>
			</div>
		</div>
	{/if}

	{#if showTranslateLangPicker}
		<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
		<div class="wa-translate-overlay" on:click={() => { showTranslateLangPicker = false; translateTargetMsgId = null; }}>
			<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
			<div class="wa-translate-popup" on:click|stopPropagation>
				<div class="wa-translate-popup-header">
					<h4>🌐 {isRTL ? 'ترجم إلى' : 'Translate to'}</h4>
					<button on:click={() => { showTranslateLangPicker = false; translateTargetMsgId = null; }}>✕</button>
				</div>
				<input type="text" bind:value={translateLangSearch} placeholder={isRTL ? 'بحث عن لغة...' : 'Search language...'}
					class="wa-translate-search" />
				<div class="wa-translate-lang-grid">
					{#each filteredTranslateLangs as lang}
						<button class="wa-translate-lang-item" on:click={() => translateTargetMsgId && translateMessage(translateTargetMsgId, lang.code)}>
							<span class="wa-translate-lang-flag">{lang.flag}</span>
							<span class="wa-translate-lang-name">{lang.name}</span>
						</button>
					{/each}
					{#if filteredTranslateLangs.length === 0}
						<p class="wa-translate-no-results">{isRTL ? 'لم يتم العثور على لغات' : 'No languages found'}</p>
					{/if}
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	/* Override parent layout scroll — this page manages its own scrolling */
	:global(.mobile-layout) {
		overflow-y: hidden !important;
	}
	:global(.mobile-content) {
		overflow-y: hidden !important;
	}

	/* ===== ROOT — WhatsApp Light Theme ===== */
	.wa-mobile {
		display: flex;
		flex-direction: column;
		height: 100vh;
		height: 100dvh;
		width: 100%;
		background: #FFFFFF;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
		overflow: hidden;
		position: relative;
		padding-bottom: 4rem;
	}
	.wa-mobile.rtl { direction: rtl; }

	.hidden { display: none; }

	/* ===== LIST VIEW ===== */
	.wa-list-view {
		display: flex;
		flex-direction: column;
		height: 100vh;
		height: 100dvh;
		overflow: hidden;
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

	/* Account Header */
	.wa-account-header {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 14px;
		background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
		flex-shrink: 0;
	}
	.wa-account-pic {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		object-fit: cover;
		border: 2px solid rgba(255,255,255,0.5);
		box-shadow: 0 2px 8px rgba(0,0,0,0.15);
	}
	.wa-account-icon {
		font-size: 20px;
	}
	.wa-account-name {
		font-size: 14px;
		font-weight: 600;
		color: #FFFFFF;
		text-shadow: 0 1px 2px rgba(0,0,0,0.1);
	}

	/* Search */
	.wa-search-bar {
		padding: 8px 10px;
		background: rgba(255, 255, 255, 0.8);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		flex-shrink: 0;
	}
	.wa-search-input-wrap {
		display: flex;
		align-items: center;
		background: rgba(255, 255, 255, 0.6);
		border: 1px solid rgba(249, 115, 22, 0.1);
		border-radius: 12px;
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
		flex-shrink: 0;
	}
	.wa-filter-chip {
		padding: 5px 14px;
		border-radius: 16px;
		background: rgba(255, 255, 255, 0.6);
		color: #54656F;
		font-size: 12px;
		font-weight: 500;
		border: 1px solid rgba(249, 115, 22, 0.1);
		white-space: nowrap;
		cursor: pointer;
		transition: all 0.15s;
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
	}
	.wa-filter-chip.active {
		background: rgba(249, 115, 22, 0.15);
		color: #ea580c;
		font-weight: 600;
		border-color: rgba(249, 115, 22, 0.3);
	}

	/* Conversation list */
	.wa-conv-list {
		flex: 1;
		overflow-y: auto;
		background: linear-gradient(180deg, rgba(255,255,255,0.9) 0%, rgba(249,115,22,0.03) 100%);
		padding: 6px 8px;
	}
	.wa-load-more-btn {
		width: 100%;
		padding: 10px;
		background: rgba(249, 115, 22, 0.08);
		color: #ea580c;
		border: 1px dashed rgba(249, 115, 22, 0.3);
		border-radius: 10px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		margin-top: 4px;
	}
	.wa-conv-item {
		display: flex;
		align-items: center;
		padding: 10px 12px;
		gap: 12px;
		width: 100%;
		border: 1px solid rgba(255, 255, 255, 0.6);
		background: rgba(255, 255, 255, 0.55);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		cursor: pointer;
		text-align: start;
		border-radius: 12px;
		margin-bottom: 4px;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04), 0 0 0 1px rgba(249, 115, 22, 0.04);
		transition: all 0.2s ease;
	}
	.wa-conv-item:active {
		background: rgba(255, 247, 237, 0.85);
		border-color: rgba(249, 115, 22, 0.3);
		box-shadow: 0 2px 10px rgba(249, 115, 22, 0.15);
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
		background: #f97316;
		color: #FFFFFF;
		font-size: 11px;
		font-weight: 700;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 5px;
		margin-inline-start: 8px;
	}
	.wa-conv-badges {
		display: flex;
		align-items: center;
		gap: 3px;
		flex-shrink: 0;
		margin-inline-start: 4px;
	}
	.wa-mbadge {
		font-size: 11px;
		padding: 1px 4px;
		border-radius: 9999px;
		border: 1px solid transparent;
		font-weight: 700;
		cursor: default;
		display: inline-flex;
		align-items: center;
	}
	.wa-mbadge-human  { background: #fffbeb; color: #d97706; border-color: #fde68a; }
	.wa-mbadge-auto   { background: #eff6ff; color: #2563eb; border-color: #bfdbfe; }
	.wa-mbadge-ai     { background: #f3e8ff; color: #7c3aed; border-color: #ddd6fe; }
	.wa-mbadge-aion   { background: #ede9fe; color: #6d28d9; border-color: #c4b5fd; cursor: pointer; }
	.wa-mbadge-aioff  { background: #f1f5f9; color: #94a3b8; border-color: #e2e8f0; cursor: pointer; }
	.wa-mbadge-help   { background: #fee2e2; color: #b91c1c; border-color: #fca5a5; cursor: pointer; animation: pulse 2s infinite; }
	.wa-mbadge-sos    { background: #22c55e; color: #ffffff; border-color: #16a34a; cursor: pointer; border-radius: 20px; padding: 4px 10px; font-weight: bold; font-size: 9px; }
	.wa-mbadge-sos:hover { background: #16a34a; color: #ffffff; border-color: #15803d; }
	.wa-mbadge-sos-active { background: #ef4444; color: #ffffff; border-color: #dc2626; cursor: pointer; border-radius: 20px; padding: 4px 10px; font-weight: bold; font-size: 9px; animation: pulse 2s infinite; }
	.wa-mbadge-sos-active:hover { background: #dc2626; color: #ffffff; border-color: #b91c1c; }
	/* Header action badges */
	.wa-header-badge {
		width: 34px;
		height: 34px;
		border-radius: 50%;
		border: none;
		font-size: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
	}
	.wa-hbadge-aion  { background: #22c55e; color: #ffffff; font-weight: bold; font-size: 12px; }
	.wa-hbadge-aioff { background: #ef4444; color: #ffffff; font-weight: bold; font-size: 12px; border: 2px solid #ffffff; }
	.wa-hbadge-help  { background: #fee2e2; animation: pulse 2s infinite; }
	.wa-hbadge-sos   { background: #22c55e; color: #ffffff; font-weight: bold; font-size: 12px; border: 2px solid #ffffff; }
	.wa-hbadge-sos-active { background: #ef4444; color: #ffffff; font-weight: bold; font-size: 12px; animation: pulse 2s infinite; border: 2px solid #ffffff; }

	/* Loading / Empty */
	.wa-loading {
		display: flex;
		justify-content: center;
		padding: 60px 0;
	}
	.wa-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid rgba(249, 115, 22, 0.15);
		border-top-color: #f97316;
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
		background: white;
		overflow: hidden;
		z-index: 99;
	}

	/* Chat Header — brand orange */
	.wa-chat-header {
		display: flex;
		align-items: center;
		padding: 6px 6px 6px 4px;
		background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
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
		background: rgba(255,255,255,0.25);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		border: 1px solid rgba(255,255,255,0.3);
		border-radius: 50%;
		width: 36px;
		height: 36px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 18px;
	}
	.wa-incident-btn {
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 50%;
		width: 36px;
		height: 36px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		font-size: 16px;
		box-shadow: 0 1px 3px rgba(0,0,0,0.08);
	}
	.wa-incident-btn:active {
		background: #fef2f2;
		border-color: #fecaca;
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

	/* Messages area — glass background with brand pattern */
	.wa-messages {
		flex: 1;
		overflow-y: auto;
		overflow-x: hidden;
		-webkit-overflow-scrolling: touch;
		padding: 8px 12px;
		min-height: 0;
		background: linear-gradient(135deg, rgba(249, 115, 22, 0.04) 0%, rgba(255, 255, 255, 0.6) 40%, rgba(34, 197, 94, 0.04) 100%);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
		background-image:
			linear-gradient(135deg, rgba(249, 115, 22, 0.04) 0%, rgba(255, 255, 255, 0.6) 40%, rgba(34, 197, 94, 0.04) 100%),
			url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23f97316' fill-opacity='0.03'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
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
		border-radius: 14px;
		position: relative;
		word-break: break-word;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06), 0 0 1px rgba(0, 0, 0, 0.08);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
	}
	.wa-msg-out {
		background: rgba(220, 252, 231, 0.75);
		border: 1px solid rgba(187, 247, 208, 0.6);
		color: #1e293b;
		border-top-right-radius: 4px;
	}
	.rtl .wa-msg-out {
		border-top-right-radius: 14px;
		border-top-left-radius: 4px;
	}
	.wa-msg-in {
		background: rgba(255, 255, 255, 0.8);
		border: 1px solid rgba(226, 232, 240, 0.6);
		color: #1e293b;
		border-top-left-radius: 4px;
	}
	.rtl .wa-msg-in {
		border-top-left-radius: 14px;
		border-top-right-radius: 4px;
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
	.wa-interactive-buttons {
		display: flex;
		flex-direction: column;
		gap: 4px;
		margin-top: 8px;
		border-top: 1px solid rgba(0,0,0,0.08);
		padding-top: 8px;
	}
	.wa-interactive-btn {
		text-align: center;
		font-size: 12px;
		color: #0b84ed;
		font-weight: 500;
		padding: 6px 8px;
		background: rgba(255,255,255,0.6);
		border-radius: 8px;
		border: 1px solid rgba(11,132,237,0.25);
	}
	.wa-cta-link {
		text-decoration: none;
		display: block;
	}
	.wa-cta-link:hover {
		background: rgba(11,132,237,0.08);
	}
	.wa-sender-label {
		font-size: 11px;
		font-weight: 600;
		margin-bottom: 2px;
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
		background: rgba(255, 255, 255, 0.9);
		backdrop-filter: blur(12px);
		-webkit-backdrop-filter: blur(12px);
		padding: 6px 6px;
		padding-bottom: calc(6px + env(safe-area-inset-bottom));
		border-top: 1px solid rgba(226, 232, 240, 0.6);
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
		border: 1.5px solid #fdba74;
		border-radius: 20px;
		padding: 10px 16px;
		color: #111B21;
		font-size: 15px;
		outline: none;
		resize: none;
		line-height: 1.35;
		max-height: 100px;
		transition: border-color 0.2s;
	}
	.wa-text-input:focus {
		border-color: #f97316;
		box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.15);
	}
	.wa-text-input::placeholder {
		color: #667781;
	}

	.wa-transform-btn {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		background: linear-gradient(135deg, #a855f7, #7c3aed);
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		flex-shrink: 0;
		font-size: 16px;
		transition: background 0.15s;
		box-shadow: 0 2px 6px rgba(168, 85, 247, 0.3);
	}
	.wa-transform-btn:active { background: #6d28d9; }
	.wa-transform-btn:disabled { opacity: 0.5; }

	.wa-translate-input-btn {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		flex-shrink: 0;
		font-size: 16px;
		transition: background 0.15s;
		box-shadow: 0 2px 6px rgba(59, 130, 246, 0.3);
	}
	.wa-translate-input-btn:active { background: #1d4ed8; }
	.wa-translate-input-btn:disabled { opacity: 0.5; }

	.wa-send-btn {
		width: 42px;
		height: 42px;
		border-radius: 50%;
		background: linear-gradient(135deg, #f97316, #ea580c);
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		flex-shrink: 0;
		transition: background 0.15s;
		box-shadow: 0 2px 8px rgba(249, 115, 22, 0.3);
	}
	.wa-send-btn:active { background: #c2410c; }
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
		background: linear-gradient(135deg, #f97316, #ea580c);
		border: none;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		box-shadow: 0 2px 8px rgba(249, 115, 22, 0.3);
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
		background: linear-gradient(135deg, #f97316, #ea580c);
		color: #fff;
		font-size: 14px;
		font-weight: 600;
		border: none;
		cursor: pointer;
		box-shadow: 0 2px 8px rgba(249, 115, 22, 0.3);
	}
	.wa-template-only-btn:active {
		background: #c2410c;
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

	/* ===== Translation ===== */
	.wa-translate-btn {
		font-size: 11px;
		padding: 1px 4px;
		border-radius: 5px;
		background: rgba(59, 130, 246, 0.08);
		border: 1px solid rgba(59, 130, 246, 0.15);
		cursor: pointer;
		line-height: 1;
		transition: all 0.2s ease;
	}
	.wa-translate-btn:active {
		background: rgba(59, 130, 246, 0.2);
	}
	.wa-translate-result {
		margin-top: 4px;
		padding: 5px 7px;
		background: rgba(59, 130, 246, 0.06);
		border: 1px solid rgba(59, 130, 246, 0.15);
		border-radius: 6px;
	}
	.wa-translate-result-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 2px;
	}
	.wa-translate-label {
		font-size: 9px;
		font-weight: 600;
		color: #2563EB;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}
	.wa-translate-clear {
		background: none;
		border: none;
		color: #94A3B8;
		font-size: 10px;
		cursor: pointer;
		padding: 0 2px;
	}
	.wa-translate-text {
		white-space: pre-wrap;
		word-break: break-word;
		font-size: 12.5px;
		color: #334155;
		margin: 0;
	}
	.wa-translating {
		display: flex;
		align-items: center;
		gap: 5px;
		margin-top: 4px;
		font-size: 10px;
		color: #3B82F6;
	}
	.wa-translating-spinner {
		display: inline-block;
		width: 12px;
		height: 12px;
		border: 1.5px solid #93C5FD;
		border-top-color: #2563EB;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Translation Language Picker */
	.wa-translate-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0,0,0,0.45);
		display: flex;
		align-items: flex-end;
		justify-content: center;
		z-index: 9999;
	}
	.wa-translate-popup {
		background: #FFFFFF;
		border-radius: 16px 16px 0 0;
		box-shadow: 0 -4px 30px rgba(0,0,0,0.15);
		padding: 16px;
		width: 100%;
		max-width: 420px;
		max-height: 70vh;
		display: flex;
		flex-direction: column;
		animation: slideUp 0.25s ease-out;
	}
	@keyframes slideUp {
		from { transform: translateY(100%); }
		to { transform: translateY(0); }
	}
	.wa-translate-popup-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 10px;
	}
	.wa-translate-popup-header h4 {
		margin: 0;
		font-size: 15px;
		font-weight: 700;
		color: #111B21;
	}
	.wa-translate-popup-header button {
		background: #F0F2F5;
		border: none;
		width: 28px;
		height: 28px;
		border-radius: 50%;
		font-size: 14px;
		color: #667781;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.wa-translate-search {
		width: 100%;
		padding: 8px 12px;
		margin-bottom: 8px;
		background: #F0F2F5;
		border: 1px solid #E9EDEF;
		border-radius: 8px;
		font-size: 13px;
		outline: none;
	}
	.wa-translate-search:focus {
		border-color: #027EB5;
	}
	.wa-translate-lang-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 6px;
		overflow-y: auto;
		max-height: 50vh;
		-webkit-overflow-scrolling: touch;
	}
	.wa-translate-lang-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 10px;
		border-radius: 8px;
		border: 1px solid #E9EDEF;
		background: #FAFBFC;
		cursor: pointer;
		transition: background 0.15s;
	}
	.wa-translate-lang-item:active {
		background: #E3F2FD;
		border-color: #90CAF9;
	}
	.wa-translate-lang-flag {
		font-size: 18px;
	}
	.wa-translate-lang-name {
		font-size: 13px;
		color: #111B21;
		font-weight: 500;
	}
	.wa-translate-no-results {
		grid-column: span 2;
		text-align: center;
		color: #667781;
		font-size: 13px;
		padding: 20px 0;
	}
</style>



