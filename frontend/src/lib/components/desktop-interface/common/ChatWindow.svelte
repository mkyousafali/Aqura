<script lang="ts">
	import { currentLocale } from '$lib/i18n';
	import { sendChatMessage, type ChatMessage } from '$lib/utils/chatService';
	import { speakWithGoogleTTS, stopSpeaking, getVoicesForLocale, getSelectedVoiceId, setSelectedVoiceId, loadVoicePreferences, type VoiceOption } from '$lib/utils/ttsService';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { createEventDispatcher, onMount, onDestroy, tick } from 'svelte';
	import { fly, fade } from 'svelte/transition';

	const dispatch = createEventDispatcher();

	let messages: ChatMessage[] = [];
	let inputText = '';
	let isLoading = false;
	let messagesContainer: HTMLDivElement;
	let inputEl: HTMLTextAreaElement;
	let inactivityTimer: ReturnType<typeof setTimeout> | null = null;
	let closingCountdown = false;
	let countdownSeconds = 30;
	let countdownInterval: ReturnType<typeof setInterval> | null = null;

	// Quick action buttons permission
	let hasSalesPermission = false;
	let salesLoading = false;

	// Voice input (speech recognition)
	let isListening = false;
	let recognition: any = null;

	// Read aloud state
	let readAloud = false;
	let showVoiceMenu = false;
	let availableVoices: VoiceOption[] = [];
	let selectedVoice = '';

	$: {
		availableVoices = getVoicesForLocale($currentLocale);
		selectedVoice = getSelectedVoiceId($currentLocale);
	}

	// Dragging state
	let isDragging = false;
	let dragOffsetX = 0;
	let dragOffsetY = 0;
	let windowX = window.innerWidth - 460;
	let windowY = Math.max(20, (window.innerHeight - 660) / 2);
	let chatWindowEl: HTMLDivElement;

	const INACTIVITY_LIMIT = 3 * 60 * 1000; // 3 minutes

	$: isArabic = $currentLocale === 'ar';
	$: placeholder = isArabic ? 'اكتب رسالتك هنا...' : 'Type your message here...';
	$: sendLabel = isArabic ? 'إرسال' : 'Send';
	$: titleText = isArabic ? 'أكورا' : 'Aqura';
	$: welcomeMsg = isArabic
		? 'مرحبًا! أنا أكورا 👋\nكيف يمكنني مساعدتك اليوم؟'
		: 'Hi! I\'m Aqura 👋\nHow can I help you today?';
	$: goodbyeMsg = isArabic
		? '⏰ لم يتم إرسال أي رسالة منذ 3 دقائق.\nسيتم إغلاق المحادثة تلقائيًا خلال 30 ثانية.\nأتمنى لك يومًا سعيدًا! 👋'
		: '⏰ No messages for 3 minutes.\nChat will close automatically in 30 seconds.\nHave a great day! 👋';

	function resetInactivityTimer() {
		if (closingCountdown) return; // don't reset during countdown
		if (inactivityTimer) clearTimeout(inactivityTimer);
		inactivityTimer = setTimeout(() => startClosingCountdown(), INACTIVITY_LIMIT);
	}

	async function startClosingCountdown() {
		closingCountdown = true;
		countdownSeconds = 30;
		messages = [...messages, { role: 'assistant', content: goodbyeMsg }];
		await scrollToBottom();

		countdownInterval = setInterval(() => {
			countdownSeconds--;
			if (countdownSeconds <= 0) {
				if (countdownInterval) clearInterval(countdownInterval);
				close();
			}
		}, 1000);
	}

	function cancelCountdown() {
		if (countdownInterval) clearInterval(countdownInterval);
		closingCountdown = false;
		countdownSeconds = 30;
		resetInactivityTimer();
	}

	onMount(async () => {
		// Load saved voice preferences before speaking
		await loadVoicePreferences();
		selectedVoice = getSelectedVoiceId($currentLocale);

		messages = [{ role: 'assistant', content: welcomeMsg }];
		inputEl?.focus();
		resetInactivityTimer();
		// Always read welcome message aloud
		readAloud = true;
		speakWithGoogleTTS(welcomeMsg, $currentLocale);

		// Check button permissions
		try {
			const user = $currentUser;
			if (user?.isMasterAdmin) {
				hasSalesPermission = true;
			} else if (user?.id) {
				const { data: perms } = await supabase
					.from('button_permissions')
					.select('button_id, sidebar_buttons!inner(button_code)')
					.eq('user_id', user.id)
					.eq('is_enabled', true);
				const codes = perms?.map((p: any) => p.sidebar_buttons?.button_code) || [];
				hasSalesPermission = codes.includes('SALES_REPORT');
			}
		} catch (e) {
			console.error('Error checking permissions:', e);
		}
	});

	onDestroy(() => {
		if (inactivityTimer) clearTimeout(inactivityTimer);
		if (countdownInterval) clearInterval(countdownInterval);
		stopSpeaking();
		window.speechSynthesis?.cancel();
	});

	function speakText(text: string) {
		if (!readAloud) return;
		speakWithGoogleTTS(text, $currentLocale);
	}

	function toggleReadAloud() {
		readAloud = !readAloud;
		if (!readAloud) {
			stopSpeaking();
			window.speechSynthesis?.cancel();
			showVoiceMenu = false;
		}
	}

	function toggleVoiceMenu() {
		showVoiceMenu = !showVoiceMenu;
	}

	function selectVoice(voiceId: string) {
		setSelectedVoiceId($currentLocale, voiceId);
		selectedVoice = voiceId;
		showVoiceMenu = false;
	}

	async function testVoice(voice: VoiceOption) {
		stopSpeaking();
		const testText = voice.languageCode.startsWith('ar')
			? 'مرحبًا، هذا اختبار للصوت'
			: 'Hello, this is a voice test';
		const prev = getSelectedVoiceId($currentLocale);
		setSelectedVoiceId($currentLocale, voice.id);
		selectedVoice = voice.id;
		await speakWithGoogleTTS(testText, $currentLocale);
		setSelectedVoiceId($currentLocale, prev);
		selectedVoice = prev;
	}

	function toggleVoiceInput() {
		if (isListening && recognition) {
			recognition.stop();
			return;
		}

		const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
		if (!SpeechRecognition) {
			alert(isArabic ? 'المتصفح لا يدعم التعرف على الصوت' : 'Browser does not support speech recognition');
			return;
		}

		recognition = new SpeechRecognition();
		recognition.lang = isArabic ? 'ar-SA' : 'en-US';
		recognition.continuous = true;
		recognition.interimResults = true;

		recognition.onstart = () => {
			isListening = true;
		};

		recognition.onresult = (event: any) => {
			let transcript = '';
			for (let i = 0; i < event.results.length; i++) {
				transcript += event.results[i][0].transcript;
			}
			inputText = transcript;
		};

		recognition.onerror = (event: any) => {
			console.error('[Voice Input] Error:', event.error);
			isListening = false;
			recognition = null;
		};

		recognition.onend = () => {
			isListening = false;
			recognition = null;
		};

		recognition.start();
	}

	async function handleSend() {
		const text = inputText.trim();
		if (!text || isLoading) return;

		// Cancel countdown if user sends message during it
		if (closingCountdown) cancelCountdown();
		resetInactivityTimer();

		inputText = '';
		messages = [...messages, { role: 'user', content: text }];
		await scrollToBottom();

		isLoading = true;
		try {
			const reply = await sendChatMessage(
				messages.filter((m) => m.role !== 'system'),
				$currentLocale
			);
			messages = [...messages, { role: 'assistant', content: reply }];
			speakText(reply);
		} catch (err: any) {
			messages = [
				...messages,
				{
					role: 'assistant',
					content: isArabic
						? `عذرًا، حدث خطأ: ${err.message}`
						: `Sorry, an error occurred: ${err.message}`
				}
			];
		}
		isLoading = false;
		resetInactivityTimer();
		await scrollToBottom();
	}

	async function handleSalesReport() {
		if (salesLoading) return;
		if (closingCountdown) cancelCountdown();
		resetInactivityTimer();

		const requestMsg = isArabic ? '📊 تقرير مبيعات أمس' : '📊 Yesterday\'s Sales Report';
		messages = [...messages, { role: 'user', content: requestMsg }];
		await scrollToBottom();

		salesLoading = true;
		isLoading = true;

		try {
			// Use Saudi timezone (UTC+3)
			const now = new Date();
			const saudiNow = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
			saudiNow.setDate(saudiNow.getDate() - 1);
			const dateStr = `${saudiNow.getFullYear()}-${String(saudiNow.getMonth() + 1).padStart(2, '0')}-${String(saudiNow.getDate()).padStart(2, '0')}`;

			const { data: salesData, error } = await supabase
				.from('erp_daily_sales')
				.select('*')
				.eq('sale_date', dateStr)
				.order('branch_id', { ascending: true });

			if (error) throw error;

			// Get branch names
			const branchIds = [...new Set(salesData?.map(s => s.branch_id) || [])];
			let branchMap: Record<number, string> = {};
			if (branchIds.length > 0) {
				const { data: branches } = await supabase
					.from('branches')
					.select('id, location_en, location_ar')
					.in('id', branchIds);
				branches?.forEach(b => {
					branchMap[b.id] = isArabic ? (b.location_ar || b.location_en) : b.location_en;
				});
			}

			if (!salesData || salesData.length === 0) {
				const noDataMsg = isArabic
					? `📊 لا توجد بيانات مبيعات ليوم ${dateStr}`
					: `📊 No sales data found for ${dateStr}`;
				messages = [...messages, { role: 'assistant', content: noDataMsg }];
				speakText(noDataMsg);
			} else {
				// Group by branch
				const byBranch: Record<number, { net_amount: number; net_bills: number; return_amount: number }> = {};
				salesData.forEach(s => {
					if (!byBranch[s.branch_id]) byBranch[s.branch_id] = { net_amount: 0, net_bills: 0, return_amount: 0 };
					byBranch[s.branch_id].net_amount += (s.net_amount || 0);
					byBranch[s.branch_id].net_bills += (s.net_bills || 0);
					byBranch[s.branch_id].return_amount += (s.return_amount || 0);
				});

				let totalSales = 0;
				let lines: string[] = [];
				lines.push(isArabic ? `📊 مبيعات أمس (${dateStr})` : `📊 Yesterday's Sales (${dateStr})`);

				Object.entries(byBranch).forEach(([bid, data]) => {
					const name = branchMap[Number(bid)] || (isArabic ? `فرع ${bid}` : `Branch ${bid}`);
					lines.push(isArabic
						? `🏪 ${name}: ${data.net_amount.toLocaleString()} ر.س`
						: `🏪 ${name}: ${data.net_amount.toLocaleString()} SAR`);
					totalSales += data.net_amount;
				});

				lines.push(isArabic
					? `\n📈 الإجمالي: ${totalSales.toLocaleString()} ر.س`
					: `\n📈 Total: ${totalSales.toLocaleString()} SAR`);

				const reply = lines.join('\n');
				messages = [...messages, { role: 'assistant', content: reply }];
				speakText(reply);
			}
		} catch (err: any) {
			messages = [...messages, {
				role: 'assistant',
				content: isArabic ? `عذرًا، حدث خطأ: ${err.message}` : `Sorry, an error occurred: ${err.message}`
			}];
		}

		salesLoading = false;
		isLoading = false;
		resetInactivityTimer();
		await scrollToBottom();
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.altKey && !e.shiftKey) {
			e.preventDefault();
			handleSend();
		}
		// Alt+Enter or Shift+Enter = new line (default textarea behavior)
	}

	async function scrollToBottom() {
		await tick();
		if (messagesContainer) {
			messagesContainer.scrollTop = messagesContainer.scrollHeight;
		}
	}

	function close() {
		dispatch('close');
	}

	function clearChat() {
		messages = [{ role: 'assistant', content: welcomeMsg }];
	}

	function onDragStart(e: MouseEvent) {
		isDragging = true;
		dragOffsetX = e.clientX - windowX;
		dragOffsetY = e.clientY - windowY;
		window.addEventListener('mousemove', onDragMove);
		window.addEventListener('mouseup', onDragEnd);
	}

	function onDragMove(e: MouseEvent) {
		if (!isDragging) return;
		windowX = Math.max(0, Math.min(e.clientX - dragOffsetX, window.innerWidth - 400));
		windowY = Math.max(0, Math.min(e.clientY - dragOffsetY, window.innerHeight - 100));
	}

	function onDragEnd() {
		isDragging = false;
		window.removeEventListener('mousemove', onDragMove);
		window.removeEventListener('mouseup', onDragEnd);
	}
</script>

<div
	class="chat-window"
	dir={isArabic ? 'rtl' : 'ltr'}
	bind:this={chatWindowEl}
	style="left: {windowX}px; top: {windowY}px;"
	transition:fly={{ y: 100, duration: 300 }}
>
	<!-- Header (draggable) -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="chat-header" on:mousedown={onDragStart}>
		<div class="header-glow"></div>
		<div class="header-content">
			<div class="header-left">
				<div class="ai-avatar">
					<div class="avatar-ring"></div>
					<img src="/icons/Aqura logo.png" alt="Aqura" class="avatar-icon-img" />
				</div>
				<div class="header-info">
					<h3>{titleText}</h3>
					<div class="status-row">
						<span class="status-dot"></span>
						<span class="status-text">{isArabic ? 'متصل الآن' : 'Online now'}</span>
					</div>
				</div>
			</div>
			<div class="header-actions">
				<button
					class="header-btn"
					class:sound-on={readAloud}
					on:click={toggleReadAloud}
					title={isArabic ? (readAloud ? 'إيقاف القراءة' : 'قراءة بصوت عالٍ') : (readAloud ? 'Mute' : 'Read aloud')}
				>
					{#if readAloud}
						<svg viewBox="0 0 24 24" fill="none" width="16" height="16">
							<path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" fill="currentColor"/>
						</svg>
					{:else}
						<svg viewBox="0 0 24 24" fill="none" width="16" height="16">
							<path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z" fill="currentColor"/>
						</svg>
					{/if}
				</button>
				<!-- Voice Selection -->
				{#if readAloud}
					<div class="voice-select-wrapper">
						<button
							class="header-btn voice-btn"
							on:click={toggleVoiceMenu}
							title={isArabic ? 'اختيار الصوت' : 'Select Voice'}
						>
							<svg viewBox="0 0 24 24" fill="none" width="16" height="16">
								<path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.91-3c-.49 0-.9.36-.98.85C16.52 14.2 14.47 16 12 16s-4.52-1.8-4.93-4.15c-.08-.49-.49-.85-.98-.85-.61 0-1.09.54-1 1.14.49 3 2.89 5.35 5.91 5.78V20c0 .55.45 1 1 1s1-.45 1-1v-2.08c3.02-.43 5.42-2.78 5.91-5.78.1-.6-.39-1.14-1-1.14z" fill="currentColor"/>
							</svg>
							<svg viewBox="0 0 24 24" fill="none" width="10" height="10" class="chevron" class:open={showVoiceMenu}>
								<path d="M7 10l5 5 5-5z" fill="currentColor"/>
							</svg>
						</button>
						{#if showVoiceMenu}
							<div class="voice-dropdown" transition:fly={{ y: -10, duration: 200 }}>
								<div class="voice-dropdown-title">
									{isArabic ? '🎙️ اختر الصوت' : '🎙️ Select Voice'}
								</div>
								{#each availableVoices as voice}
									<div class="voice-option-row">
										<button
											class="voice-option"
											class:active={selectedVoice === voice.id}
											on:click={() => selectVoice(voice.id)}
										>
											<span class="voice-name">{isArabic ? voice.nameAr : voice.name}</span>
											{#if selectedVoice === voice.id}
												<svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor">
													<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>
												</svg>
											{/if}
										</button>
										<button
											class="test-voice-btn"
											on:click|stopPropagation={() => testVoice(voice)}
											title={isArabic ? 'اختبار' : 'Test'}
										>
											▶
										</button>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				{/if}
				<button class="header-btn" on:click={clearChat} title={isArabic ? 'مسح المحادثة' : 'Clear chat'}>
					<svg viewBox="0 0 24 24" fill="none" width="16" height="16">
						<path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z" fill="currentColor"/>
					</svg>
				</button>
				<button class="header-btn close-btn" on:click={close} title={isArabic ? 'إغلاق' : 'Close'}>
					<svg viewBox="0 0 24 24" fill="none" width="16" height="16">
						<path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" fill="currentColor"/>
					</svg>
				</button>
			</div>
		</div>
	</div>

	<!-- Quick Action Buttons -->
	<div class="quick-actions">
		<button
			class="quick-action-btn"
			on:click={handleSalesReport}
			disabled={!hasSalesPermission || salesLoading}
			title={hasSalesPermission
				? (isArabic ? 'تقرير مبيعات أمس' : 'Yesterday\'s Sales Report')
				: (isArabic ? 'ليس لديك صلاحية' : 'No permission')}
		>
			<span class="quick-action-icon">📊</span>
			<span class="quick-action-label">{isArabic ? 'مبيعات أمس' : 'Sales Report'}</span>
			{#if !hasSalesPermission}
				<span class="lock-icon">🔒</span>
			{/if}
		</button>
	</div>

	<!-- Messages -->
	<div class="chat-messages" bind:this={messagesContainer}>
		{#each messages as message, i}
			<div class="message {message.role}" in:fly={{ y: 20, duration: 300, delay: i === messages.length - 1 ? 50 : 0 }}>
				{#if message.role === 'assistant'}
					<div class="msg-avatar">
						<img src="/icons/Aqura logo.png" alt="Aqura" class="msg-avatar-img" />
					</div>
				{/if}
				<div class="msg-bubble">
					<p>{message.content}</p>
				</div>
				{#if message.role === 'user'}
					<div class="msg-avatar user-avatar">
						<span>👤</span>
					</div>
				{/if}
			</div>
		{/each}
		{#if isLoading}
			<div class="message assistant" in:fade={{ duration: 200 }}>
				<div class="msg-avatar">
					<img src="/icons/Aqura logo.png" alt="Aqura" class="msg-avatar-img" />
				</div>
				<div class="msg-bubble typing">
					<div class="typing-wave">
						<span class="dot"></span>
						<span class="dot"></span>
						<span class="dot"></span>
					</div>
				</div>
			</div>
		{/if}
	</div>

	<!-- Input -->
	<div class="chat-input-area">
		<div class="input-wrapper">
			<textarea
				bind:this={inputEl}
				bind:value={inputText}
				on:keydown={handleKeydown}
				{placeholder}
				disabled={isLoading}
				class="chat-input"
				rows="1"
				autocomplete="off"
			></textarea>
		</div>
		<button
			class="mic-btn"
			class:listening={isListening}
			on:click={toggleVoiceInput}
			disabled={isLoading}
			title={isListening ? (isArabic ? 'إيقاف الاستماع' : 'Stop listening') : (isArabic ? 'أمر صوتي' : 'Voice command')}
		>
			{#if isListening}
				<svg viewBox="0 0 24 24" fill="none" width="18" height="18">
					<rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor"/>
				</svg>
			{:else}
				<svg viewBox="0 0 24 24" fill="none" width="18" height="18">
					<path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.91-3c-.49 0-.9.36-.98.85C16.52 14.2 14.47 16 12 16s-4.52-1.8-4.93-4.15c-.08-.49-.49-.85-.98-.85-.61 0-1.09.54-1 1.14.49 3 2.89 5.35 5.91 5.78V20c0 .55.45 1 1 1s1-.45 1-1v-2.08c3.02-.43 5.42-2.78 5.91-5.78.1-.6-.39-1.14-1-1.14z" fill="currentColor"/>
				</svg>
			{/if}
		</button>
		<button
			class="send-btn"
			class:active={inputText.trim() && !isLoading}
			on:click={handleSend}
			disabled={!inputText.trim() || isLoading}
			title={sendLabel}
		>
			<svg viewBox="0 0 24 24" fill="none" width="18" height="18">
				<path d="M3.478 2.405a.75.75 0 00-.926.94l2.432 7.905H13.5a.75.75 0 010 1.5H4.984l-2.432 7.905a.75.75 0 00.926.94l18.04-8.25a.75.75 0 000-1.39L3.478 2.405z" fill="currentColor" />
			</svg>
		</button>
	</div>
	<div class="powered-by">
		{isArabic ? 'مدعوم بالذكاء الاصطناعي' : 'Powered by AI'} ⚡
	</div>
</div>

<svelte:window on:keydown={(e) => e.key === 'Escape' && close()} on:click={(e) => { if (showVoiceMenu && !(e.target as HTMLElement)?.closest('.voice-select-wrapper')) showVoiceMenu = false; }} />

<style>
	.chat-window {
		position: fixed;
		width: 420px;
		max-width: 95vw;
		height: 660px;
		max-height: 85vh;
		background: rgba(255, 255, 255, 0.92);
		backdrop-filter: blur(24px) saturate(180%);
		-webkit-backdrop-filter: blur(24px) saturate(180%);
		border-radius: 24px;
		border: 1px solid var(--theme-taskbar-border, rgba(255, 255, 255, 0.2));
		box-shadow:
			0 32px 64px -12px rgba(16, 24, 40, 0.2),
			0 0 0 1px rgba(0, 0, 0, 0.04);
		display: flex;
		flex-direction: column;
		overflow: hidden;
		z-index: 2100;
		animation: windowPop 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
	}

	@keyframes windowPop {
		0% { transform: scale(0.85) translateY(40px); opacity: 0; }
		100% { transform: scale(1) translateY(0); opacity: 1; }
	}

	/* ── Header ── */
	.chat-header {
		position: relative;
		padding: 0;
		flex-shrink: 0;
		cursor: grab;
		user-select: none;
		overflow: visible;
		border-radius: 24px 24px 0 0;
	}

	.chat-header:active {
		cursor: grabbing;
	}

	.header-glow {
		position: absolute;
		inset: 0;
		background: var(--theme-taskbar-bg, rgba(0, 102, 178, 0.75));
		z-index: 0;
	}

	.header-glow::after {
		content: '';
		position: absolute;
		inset: 0;
		background: linear-gradient(135deg, rgba(255,255,255,0.1) 0%, transparent 50%, rgba(255,255,255,0.05) 100%);
		animation: shimmer 3s ease-in-out infinite;
	}

	@keyframes shimmer {
		0%, 100% { opacity: 0.5; }
		50% { opacity: 1; }
	}

	.header-content {
		position: relative;
		z-index: 1;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 20px;
		color: var(--theme-taskbar-btn-active-text, white);
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.ai-avatar {
		position: relative;
		width: 42px;
		height: 42px;
		border-radius: 14px;
		background: var(--theme-taskbar-quick-access-bg, rgba(255, 255, 255, 0.1));
		backdrop-filter: blur(12px);
		display: flex;
		align-items: center;
		justify-content: center;
		transition: transform 0.3s;
	}

	.ai-avatar:hover {
		transform: scale(1.08) rotate(-3deg);
	}

	.avatar-ring {
		position: absolute;
		inset: -2px;
		border-radius: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		animation: ring-pulse 2.5s ease-in-out infinite;
	}

	@keyframes ring-pulse {
		0%, 100% { opacity: 0.4; transform: scale(1); }
		50% { opacity: 0.8; transform: scale(1.05); }
	}

	.avatar-icon-img {
		width: 28px;
		height: 28px;
		object-fit: contain;
		border-radius: 6px;
		filter: drop-shadow(0 2px 4px rgba(0,0,0,0.2));
	}

	.header-info {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.header-info h3 {
		margin: 0;
		font-size: 15px;
		font-weight: 700;
		line-height: 1.2;
		letter-spacing: -0.01em;
		text-shadow: 0 1px 2px rgba(0,0,0,0.15);
	}

	.status-row {
		display: flex;
		align-items: center;
		gap: 5px;
	}

	.status-dot {
		width: 7px;
		height: 7px;
		background: #4ade80;
		border-radius: 50%;
		box-shadow: 0 0 8px rgba(74, 222, 128, 0.6);
		animation: live-pulse 2s infinite;
	}

	@keyframes live-pulse {
		0%, 100% { opacity: 1; box-shadow: 0 0 8px rgba(74, 222, 128, 0.6); }
		50% { opacity: 0.6; box-shadow: 0 0 12px rgba(74, 222, 128, 0.9); }
	}

	.status-text {
		font-size: 11px;
		opacity: 0.8;
		font-weight: 500;
	}

	.header-actions {
		display: flex;
		gap: 6px;
		position: relative;
		overflow: visible;
	}

	.header-btn {
		background: var(--theme-taskbar-quick-access-bg, rgba(255, 255, 255, 0.1));
		border: 1px solid rgba(255, 255, 255, 0.15);
		border-radius: 10px;
		width: 34px;
		height: 34px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		color: var(--theme-taskbar-btn-active-text, white);
		transition: all 0.2s ease;
		backdrop-filter: blur(8px);
	}

	.header-btn:hover {
		background: rgba(255, 255, 255, 0.25);
		transform: scale(1.08);
	}

	.close-btn:hover {
		background: rgba(239, 68, 68, 0.65);
		border-color: rgba(239, 68, 68, 0.3);
	}

	.sound-on {
		background: rgba(255, 255, 255, 0.3) !important;
		box-shadow: inset 0 0 0 1.5px rgba(255, 255, 255, 0.4);
	}

	/* ── Quick Actions ── */
	.quick-actions {
		display: flex;
		gap: 8px;
		padding: 8px 16px;
		flex-shrink: 0;
		flex-wrap: wrap;
		border-bottom: 1px solid rgba(226, 232, 240, 0.5);
	}

	.quick-action-btn {
		display: flex;
		align-items: center;
		gap: 5px;
		padding: 6px 12px;
		border: 1.5px solid rgba(99, 102, 241, 0.25);
		border-radius: 20px;
		background: rgba(99, 102, 241, 0.06);
		color: #4338CA;
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s ease;
		font-family: inherit;
		white-space: nowrap;
	}

	.quick-action-btn:hover:not(:disabled) {
		background: rgba(99, 102, 241, 0.14);
		border-color: rgba(99, 102, 241, 0.4);
		transform: translateY(-1px);
		box-shadow: 0 2px 8px rgba(99, 102, 241, 0.15);
	}

	.quick-action-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.quick-action-btn:disabled {
		opacity: 0.45;
		cursor: not-allowed;
		border-color: rgba(148, 163, 184, 0.3);
		background: rgba(148, 163, 184, 0.08);
		color: #94a3b8;
	}

	.quick-action-icon {
		font-size: 14px;
	}

	.quick-action-label {
		line-height: 1;
	}

	.lock-icon {
		font-size: 10px;
		margin-inline-start: 2px;
	}

	/* ── Messages ── */
	.chat-messages {
		flex: 1;
		overflow-y: auto;
		padding: 20px 16px;
		display: flex;
		flex-direction: column;
		gap: 14px;
		scroll-behavior: smooth;
	}

	.chat-messages::-webkit-scrollbar {
		width: 4px;
	}

	.chat-messages::-webkit-scrollbar-track {
		background: transparent;
	}

	.chat-messages::-webkit-scrollbar-thumb {
		background: rgba(0, 0, 0, 0.1);
		border-radius: 10px;
	}

	.chat-messages::-webkit-scrollbar-thumb:hover {
		background: rgba(0, 0, 0, 0.2);
	}

	.message {
		display: flex;
		gap: 8px;
		max-width: 82%;
		align-items: flex-end;
	}

	.message.user {
		align-self: flex-end;
	}

	.message.assistant {
		align-self: flex-start;
	}

	.msg-avatar {
		flex-shrink: 0;
		width: 30px;
		height: 30px;
		border-radius: 10px;
		background: var(--theme-taskbar-btn-inactive-bg, rgba(255, 255, 255, 0.95));
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 16px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
		overflow: hidden;
	}

	.msg-avatar-img {
		width: 22px;
		height: 22px;
		object-fit: contain;
		border-radius: 4px;
	}

	.msg-avatar.user-avatar {
		background: var(--theme-taskbar-btn-active-bg, linear-gradient(135deg, #4F46E5 0%, #6366F1 100%));
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
	}

	.msg-bubble {
		padding: 12px 16px;
		border-radius: 18px;
		font-size: 13.5px;
		line-height: 1.55;
		word-break: break-word;
		position: relative;
	}

	.msg-bubble p {
		margin: 0;
		white-space: pre-wrap;
	}

	.message.user .msg-bubble {
		background: var(--theme-taskbar-btn-active-bg, linear-gradient(135deg, #4F46E5 0%, #6366F1 100%));
		color: var(--theme-taskbar-btn-active-text, white);
		border-bottom-right-radius: 6px;
		box-shadow: 0 4px 12px -2px rgba(0, 0, 0, 0.15);
	}

	[dir='rtl'] .message.user .msg-bubble {
		border-bottom-right-radius: 18px;
		border-bottom-left-radius: 6px;
	}

	.message.assistant .msg-bubble {
		background: rgba(241, 245, 249, 0.8);
		backdrop-filter: blur(8px);
		color: var(--theme-taskbar-btn-inactive-text, #1e293b);
		border: 1px solid rgba(226, 232, 240, 0.6);
		border-bottom-left-radius: 6px;
		box-shadow: 0 2px 8px -2px rgba(0, 0, 0, 0.06);
	}

	[dir='rtl'] .message.assistant .msg-bubble {
		border-bottom-left-radius: 18px;
		border-bottom-right-radius: 6px;
	}

	/* ── Typing indicator ── */
	.typing {
		padding: 14px 20px;
	}

	.typing-wave {
		display: flex;
		gap: 5px;
		align-items: center;
	}

	.dot {
		width: 7px;
		height: 7px;
		background: var(--theme-taskbar-bg, rgba(0, 102, 178, 0.75));
		border-radius: 50%;
		animation: wave-bounce 1.4s infinite ease-in-out;
	}

	.dot:nth-child(2) { animation-delay: 0.16s; }
	.dot:nth-child(3) { animation-delay: 0.32s; }

	@keyframes wave-bounce {
		0%, 60%, 100% { transform: translateY(0) scale(0.8); opacity: 0.4; }
		30% { transform: translateY(-8px) scale(1); opacity: 1; }
	}

	/* ── Input area ── */
	.chat-input-area {
		display: flex;
		gap: 10px;
		padding: 14px 16px 8px;
		flex-shrink: 0;
	}

	.input-wrapper {
		flex: 1;
		position: relative;
	}

	.chat-input {
		width: 100%;
		border: 1.5px solid rgba(226, 232, 240, 0.8);
		border-radius: 14px;
		padding: 11px 16px;
		font-size: 13.5px;
		outline: none;
		background: rgba(255, 255, 255, 0.7);
		color: #dc2626;
		backdrop-filter: blur(8px);
		transition: all 0.25s ease;
		font-family: inherit;
		box-sizing: border-box;
		resize: none;
		min-height: 44px;
		max-height: 120px;
		overflow-y: auto;
		line-height: 1.4;
	}

	.chat-input:focus {
		border-color: var(--theme-taskbar-btn-hover-border, #4F46E5);
		box-shadow: 0 0 0 3px rgba(0, 0, 0, 0.06), 0 2px 8px rgba(0, 0, 0, 0.04);
		background: white;
	}

	.chat-input:disabled {
		opacity: 0.5;
	}

	.chat-input::placeholder {
		color: #94a3b8;
	}

	.mic-btn {
		width: 44px;
		height: 44px;
		border: none;
		border-radius: 14px;
		background: rgba(226, 232, 240, 0.5);
		color: #94a3b8;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.3s ease;
		flex-shrink: 0;
	}

	.mic-btn:hover {
		background: rgba(226, 232, 240, 0.8);
		color: #64748b;
	}

	.mic-btn.listening {
		background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
		color: white;
		box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.3);
		animation: pulse-mic 1.5s ease-in-out infinite;
	}

	@keyframes pulse-mic {
		0%, 100% { box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.3); }
		50% { box-shadow: 0 0 0 6px rgba(239, 68, 68, 0.15); }
	}

	.mic-btn:disabled {
		cursor: not-allowed;
		opacity: 0.5;
	}

	.send-btn {
		width: 44px;
		height: 44px;
		border: none;
		border-radius: 14px;
		background: rgba(226, 232, 240, 0.5);
		color: #94a3b8;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
		flex-shrink: 0;
	}

	.send-btn.active {
		background: var(--theme-taskbar-btn-active-bg, linear-gradient(135deg, #4F46E5 0%, #6366F1 100%));
		color: var(--theme-taskbar-btn-active-text, white);
		box-shadow: 0 4px 12px -2px rgba(0, 0, 0, 0.2);
	}

	.send-btn.active:hover {
		transform: scale(1.08);
		box-shadow: 0 6px 16px -2px rgba(0, 0, 0, 0.25);
	}

	.send-btn:active:not(:disabled) {
		transform: scale(0.92);
	}

	.send-btn:disabled {
		cursor: not-allowed;
	}

	[dir='rtl'] .send-btn svg {
		transform: scaleX(-1);
	}

	/* ── Powered by ── */
	.powered-by {
		text-align: center;
		font-size: 10px;
		color: #94a3b8;
		padding: 4px 0 10px;
		letter-spacing: 0.03em;
		font-weight: 500;
	}

	/* ── Voice Selection Dropdown ── */
	.voice-select-wrapper {
		position: relative;
	}

	.voice-btn {
		display: flex !important;
		align-items: center;
		gap: 2px;
	}

	.chevron {
		transition: transform 0.2s ease;
	}

	.chevron.open {
		transform: rotate(180deg);
	}

	.voice-dropdown {
		position: absolute;
		top: calc(100% + 8px);
		right: 0;
		width: 260px;
		max-height: 320px;
		overflow-y: auto;
		background: rgba(255, 255, 255, 0.97);
		backdrop-filter: blur(20px);
		border-radius: 14px;
		border: 1px solid rgba(226, 232, 240, 0.8);
		box-shadow: 0 16px 48px -8px rgba(0, 0, 0, 0.18), 0 0 0 1px rgba(0, 0, 0, 0.04);
		z-index: 9999;
		padding: 6px;
	}

	[dir='rtl'] .voice-dropdown {
		right: auto;
		left: 0;
	}

	.voice-dropdown-title {
		padding: 8px 12px 6px;
		font-size: 11px;
		font-weight: 600;
		color: #64748b;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.voice-option-row {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.voice-option {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex: 1;
		padding: 10px 12px;
		border: none;
		background: transparent;
		border-radius: 10px;
		cursor: pointer;
		transition: all 0.15s ease;
		font-family: inherit;
		text-align: start;
	}

	.voice-option:hover {
		background: rgba(99, 102, 241, 0.08);
	}

	.voice-option.active {
		background: rgba(99, 102, 241, 0.1);
	}

	.voice-option.active .voice-name {
		font-weight: 600;
		color: #4338CA;
	}

	.voice-name {
		font-size: 12.5px;
		color: #334155;
	}

	.voice-option svg {
		color: var(--theme-taskbar-btn-hover-border, #4F46E5);
		flex-shrink: 0;
	}

	.test-voice-btn {
		flex-shrink: 0;
		width: 28px;
		height: 28px;
		border: none;
		border-radius: 8px;
		background: rgba(99, 102, 241, 0.08);
		color: #6366F1;
		font-size: 11px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.15s ease;
	}

	.test-voice-btn:hover {
		background: rgba(99, 102, 241, 0.18);
		transform: scale(1.1);
	}

	.voice-dropdown::-webkit-scrollbar {
		width: 4px;
	}

	.voice-dropdown::-webkit-scrollbar-track {
		background: transparent;
	}

	.voice-dropdown::-webkit-scrollbar-thumb {
		background: rgba(148, 163, 184, 0.3);
		border-radius: 4px;
	}

	/* ── Mobile ── */
	@media (max-width: 768px) {
		.chat-window {
			width: 100% !important;
			max-width: 100% !important;
			height: calc(100% - 52px) !important;
			max-height: 100% !important;
			border-radius: 0;
			left: 0 !important;
			top: 0 !important;
			backdrop-filter: none;
			background: #fff;
		}

		.chat-header {
			border-radius: 0;
		}
	}
</style>
