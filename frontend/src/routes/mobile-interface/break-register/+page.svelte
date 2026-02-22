<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { localeData } from '$lib/i18n';

	let loading = true;
	let reasons: any[] = [];
	let selectedReason: any = null;
	let reasonNote = '';
	let isSubmitting = false;
	let activeBreak: any = null;
	let elapsedSeconds = 0;
	let timerInterval: ReturnType<typeof setInterval> | null = null;

	// QR Scanner state
	let showScanner = false;
	let scanError = '';
	let videoEl: HTMLVideoElement;
	let scanCanvas: HTMLCanvasElement;
	let scanCtx: CanvasRenderingContext2D | null = null;
	let barcodeDetector: any = null;
	let scanInterval: ReturnType<typeof setInterval> | null = null;
	let mediaStream: MediaStream | null = null;

	$: isRtl = $localeData.code === 'ar';

	function t(en: string, ar: string): string {
		return isRtl ? ar : en;
	}

	function formatTimer(seconds: number): string {
		const h = Math.floor(seconds / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		const s = seconds % 60;
		return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
	}

	function startTimer(startTime: string) {
		if (timerInterval) clearInterval(timerInterval);
		const start = new Date(startTime).getTime();
		function tick() {
			elapsedSeconds = Math.floor((Date.now() - start) / 1000);
		}
		tick();
		timerInterval = setInterval(tick, 1000);
	}

	onMount(async () => {
		if (!$currentUser?.id) {
			goto('/mobile-interface');
			return;
		}

		// Load reasons + check active break in parallel
		const [reasonsRes, activeRes] = await Promise.all([
			supabase.from('break_reasons').select('*').eq('is_active', true).order('sort_order'),
			supabase.rpc('get_active_break', { p_user_id: $currentUser.id })
		]);

		if (!reasonsRes.error && reasonsRes.data) {
			reasons = reasonsRes.data;
		}

		if (!activeRes.error && activeRes.data?.active) {
			activeBreak = activeRes.data;
			startTimer(activeBreak.start_time);
		}

		loading = false;
	});

	onDestroy(() => {
		if (timerInterval) clearInterval(timerInterval);
		stopScanner();
	});

	async function startBreak() {
		if (!selectedReason || isSubmitting) return;
		if (selectedReason.requires_note && !reasonNote.trim()) return;

		isSubmitting = true;
		const { data, error } = await supabase.rpc('start_break', {
			p_user_id: $currentUser.id,
			p_reason_id: selectedReason.id,
			p_reason_note: selectedReason.requires_note ? reasonNote.trim() : null
		});

		if (error || !data?.success) {
			alert(data?.error || error?.message || 'Failed to start break');
			isSubmitting = false;
			return;
		}

		// Refresh active break
		const { data: active } = await supabase.rpc('get_active_break', { p_user_id: $currentUser.id });
		if (active?.active) {
			activeBreak = active;
			startTimer(activeBreak.start_time);
		}
		selectedReason = null;
		reasonNote = '';
		isSubmitting = false;
	}

	function openScanner() {
		scanError = '';
		showScanner = true;
		setTimeout(startScanner, 100);
	}

	async function startScanner() {
		try {
			// Initialize barcode detector
			if (!barcodeDetector) {
				if ('BarcodeDetector' in window) {
					try {
						barcodeDetector = new (window as any).BarcodeDetector({ formats: ['qr_code'] });
					} catch (e) {
						console.warn('[scan] Native BarcodeDetector failed:', e);
					}
				}
				if (!barcodeDetector) {
					const { BarcodeDetector: Polyfill } = await import('barcode-detector');
					barcodeDetector = new Polyfill({ formats: ['qr_code'] });
				}
			}

			// Start camera - check secure context
			if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
				scanError = isRtl 
					? 'الكاميرا غير متاحة. يرجى استخدام HTTPS أو localhost' 
					: 'Camera not available. Please use HTTPS or localhost';
				return;
			}

			mediaStream = await navigator.mediaDevices.getUserMedia({
				video: { facingMode: 'environment', width: { ideal: 640 }, height: { ideal: 480 } }
			});
			if (videoEl) {
				videoEl.srcObject = mediaStream;
				await videoEl.play();
			}

			// Start scanning loop
			scanInterval = setInterval(scanFrame, 300);
		} catch (e: any) {
			scanError = e?.message || 'Camera access denied';
			console.error('[scan] Error:', e);
		}
	}

	async function scanFrame() {
		if (!videoEl || videoEl.readyState < 2 || !barcodeDetector) return;
		try {
			if (!scanCanvas) return;
			if (!scanCtx) scanCtx = scanCanvas.getContext('2d');
			scanCanvas.width = videoEl.videoWidth;
			scanCanvas.height = videoEl.videoHeight;
			scanCtx?.drawImage(videoEl, 0, 0);

			const barcodes = await barcodeDetector.detect(scanCanvas);
			if (barcodes.length > 0) {
				const code = barcodes[0].rawValue;
				if (code) {
					stopScanner();
					await endBreakWithCode(code);
				}
			}
		} catch (e) {
			// Ignore scan frame errors, keep trying
		}
	}

	function stopScanner() {
		if (scanInterval) { clearInterval(scanInterval); scanInterval = null; }
		if (mediaStream) { mediaStream.getTracks().forEach(t => t.stop()); mediaStream = null; }
		showScanner = false;
	}

	async function endBreakWithCode(code: string) {
		if (isSubmitting) return;
		isSubmitting = true;
		scanError = '';

		const { data, error } = await supabase.rpc('end_break', {
			p_user_id: $currentUser.id,
			p_security_code: code
		});

		if (error || !data?.success) {
			const msg = data?.error || error?.message || 'Failed to end break';
			scanError = msg;
			showScanner = true;
			setTimeout(startScanner, 500);
			isSubmitting = false;
			return;
		}

		if (timerInterval) clearInterval(timerInterval);
		activeBreak = null;
		elapsedSeconds = 0;
		isSubmitting = false;
	}
</script>

<svelte:head>
	<title>{t('Break Register', 'سجل الاستراحة')} - Aqura</title>
</svelte:head>

<div class="break-page" dir={isRtl ? 'rtl' : 'ltr'}>
	{#if loading}
		<div class="loading">
			<div class="spinner"></div>
			<p>{t('Loading...', 'جاري التحميل...')}</p>
		</div>
	{:else if activeBreak}
		<!-- Active Break View -->
		<div class="active-break">
			<div class="timer-circle">
				<div class="timer-ring">
					<svg viewBox="0 0 120 120">
						<circle cx="60" cy="60" r="54" fill="none" stroke="#E5E7EB" stroke-width="6"/>
						<circle cx="60" cy="60" r="54" fill="none" stroke="#EF4444" stroke-width="6"
							stroke-dasharray="339.29" stroke-dashoffset={339.29 - (339.29 * Math.min(elapsedSeconds / 3600, 1))}
							stroke-linecap="round" transform="rotate(-90 60 60)"/>
					</svg>
					<div class="timer-text">
						<span class="timer-value">{formatTimer(elapsedSeconds)}</span>
						<span class="timer-label">{t('Break Duration', 'مدة الاستراحة')}</span>
					</div>
				</div>
			</div>

			<div class="break-reason-display">
				<span class="reason-label">{t('Reason', 'السبب')}</span>
				<span class="reason-value">{isRtl ? activeBreak.reason_ar : activeBreak.reason_en}</span>
				{#if activeBreak.reason_note}
					<span class="reason-note">"{activeBreak.reason_note}"</span>
				{/if}
			</div>

			<button class="end-break-btn" on:click={openScanner} disabled={isSubmitting}>
				{#if isSubmitting}
					<div class="btn-spinner"></div>
				{:else}
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
						<circle cx="12" cy="13" r="4"/>
					</svg>
				{/if}
				{t('Scan QR to End Break', 'امسح رمز QR لإنهاء الاستراحة')}
			</button>

			<p class="scan-hint">{t('Scan the QR code displayed on the office screen to end your break', 'امسح رمز QR المعروض على شاشة المكتب لإنهاء استراحتك')}</p>
		</div>

		<!-- QR Scanner Overlay -->
		{#if showScanner}
			<div class="scanner-overlay">
				<div class="scanner-header">
					<button class="scanner-close" on:click={stopScanner} aria-label="Close scanner">
						<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
							<line x1="18" y1="6" x2="6" y2="18"/>
							<line x1="6" y1="6" x2="18" y2="18"/>
						</svg>
					</button>
					<span class="scanner-title">{t('Scan Break QR Code', 'امسح رمز QR الاستراحة')}</span>
				</div>

				<div class="scanner-viewport">
					<!-- svelte-ignore a11y-media-has-caption -->
					<video bind:this={videoEl} playsinline autoplay muted class="scanner-video"></video>
					<canvas bind:this={scanCanvas} class="scanner-canvas-hidden"></canvas>
					<div class="scanner-frame">
						<div class="corner tl"></div>
						<div class="corner tr"></div>
						<div class="corner bl"></div>
						<div class="corner br"></div>
					</div>
				</div>

				{#if scanError}
					<div class="scanner-error">
						<span>⚠️</span>
						<span>{scanError}</span>
					</div>
				{/if}

				<p class="scanner-instructions">{t('Point your camera at the QR code on the office screen', 'وجّه الكاميرا نحو رمز QR على شاشة المكتب')}</p>
			</div>
		{/if}
	{:else}
		<!-- Reason Selection View -->
		<div class="reason-selection">
			<p class="select-label">{t('Select break reason:', 'اختر سبب الاستراحة:')}</p>

			<div class="reasons-list">
				{#each reasons as reason}
					<button
						class="reason-item"
						class:selected={selectedReason?.id === reason.id}
						on:click={() => { selectedReason = reason; if (!reason.requires_note) reasonNote = ''; }}
					>
						<div class="reason-icon">
						{#if reason.sort_order === 0}🕌
						{:else if reason.sort_order === 1}🚻
							{:else if reason.sort_order === 2}🍽️
							{:else if reason.sort_order === 3}🌙
							{:else if reason.sort_order === 4}☀️
							{:else if reason.sort_order === 5}🍵
							{:else}📝
							{/if}
						</div>
						<div class="reason-text">
							<span class="reason-name">{isRtl ? reason.name_ar : reason.name_en}</span>
						</div>
						<div class="reason-check">
							{#if selectedReason?.id === reason.id}
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#22C55E" stroke-width="3">
									<polyline points="20 6 9 17 4 12"/>
								</svg>
							{/if}
						</div>
					</button>
				{/each}
			</div>

			{#if selectedReason?.requires_note}
				<div class="note-input">
					<label>{t('Please specify:', 'يرجى التحديد:')}</label>
					<textarea
						bind:value={reasonNote}
						placeholder={t('Enter reason...', 'أدخل السبب...')}
						rows="2"
					></textarea>
				</div>
			{/if}

			<button
				class="start-break-btn"
				on:click={startBreak}
				disabled={!selectedReason || isSubmitting || (selectedReason?.requires_note && !reasonNote.trim())}
			>
				{#if isSubmitting}
					<div class="btn-spinner"></div>
				{:else}
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<polygon points="5 3 19 12 5 21 5 3"/>
					</svg>
				{/if}
				{t('Start Break', 'بدء الاستراحة')}
			</button>
		</div>
	{/if}
</div>

<style>
	.break-page {
		padding: 1rem;
		padding-bottom: 5rem;
	}

	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		color: #6B7280;
	}
	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 1rem;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	/* Active Break View */
	.active-break {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 2rem 1.5rem;
		gap: 1.5rem;
	}

	.timer-circle {
		position: relative;
		width: 200px;
		height: 200px;
	}
	.timer-ring {
		position: relative;
		width: 100%;
		height: 100%;
	}
	.timer-ring svg {
		width: 100%;
		height: 100%;
	}
	.timer-ring circle:last-child {
		transition: stroke-dashoffset 1s linear;
	}
	.timer-text {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		text-align: center;
	}
	.timer-value {
		display: block;
		font-size: 1.8rem;
		font-weight: 700;
		color: #EF4444;
		font-variant-numeric: tabular-nums;
		font-family: 'Courier New', monospace;
	}
	.timer-label {
		display: block;
		font-size: 0.7rem;
		color: #9CA3AF;
		margin-top: 0.25rem;
	}

	.break-reason-display {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.25rem;
		background: white;
		padding: 1rem 1.5rem;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
		width: 100%;
		max-width: 320px;
	}
	.reason-label {
		font-size: 0.75rem;
		color: #9CA3AF;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}
	.reason-value {
		font-size: 1rem;
		font-weight: 600;
		color: #111827;
	}
	.reason-note {
		font-size: 0.85rem;
		color: #6B7280;
		font-style: italic;
	}

	.end-break-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		width: 100%;
		max-width: 320px;
		padding: 1rem;
		background: #EF4444;
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}
	.end-break-btn:active { background: #DC2626; }
	.end-break-btn:disabled { opacity: 0.6; cursor: not-allowed; }

	/* Reason Selection */
	.reason-selection {
		padding: 0.5rem 0;
	}
	.select-label {
		font-size: 0.95rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 1rem;
	}

	.reasons-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.reason-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.875rem 1rem;
		background: white;
		border: 2px solid #E5E7EB;
		border-radius: 12px;
		cursor: pointer;
		transition: all 0.15s;
		text-align: inherit;
		width: 100%;
	}
	.reason-item:active { transform: scale(0.98); }
	.reason-item.selected {
		border-color: #22C55E;
		background: #F0FDF4;
	}

	.reason-icon {
		font-size: 1.5rem;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #F3F4F6;
		border-radius: 10px;
		flex-shrink: 0;
	}
	.reason-item.selected .reason-icon {
		background: #DCFCE7;
	}

	.reason-text {
		flex: 1;
	}
	.reason-name {
		font-size: 0.95rem;
		font-weight: 500;
		color: #111827;
	}

	.reason-check {
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.note-input {
		margin-bottom: 1rem;
	}
	.note-input label {
		display: block;
		font-size: 0.85rem;
		font-weight: 500;
		color: #374151;
		margin-bottom: 0.5rem;
	}
	.note-input textarea {
		width: 100%;
		padding: 0.75rem;
		border: 2px solid #E5E7EB;
		border-radius: 10px;
		font-size: 0.9rem;
		resize: none;
		font-family: inherit;
		direction: inherit;
	}
	.note-input textarea:focus {
		outline: none;
		border-color: #3B82F6;
	}

	.start-break-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		width: 100%;
		padding: 1rem;
		background: #22C55E;
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}
	.start-break-btn:active { background: #16A34A; }
	.start-break-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	.btn-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255,255,255,0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	.scan-hint {
		text-align: center;
		font-size: 0.8rem;
		color: #9CA3AF;
		margin-top: 0.75rem;
		line-height: 1.4;
		max-width: 280px;
		margin-left: auto;
		margin-right: auto;
	}

	/* Scanner Overlay */
	.scanner-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: #000;
		z-index: 9999;
		display: flex;
		flex-direction: column;
	}

	.scanner-header {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		background: rgba(0, 0, 0, 0.8);
	}

	.scanner-close {
		background: rgba(255, 255, 255, 0.15);
		border: none;
		border-radius: 50%;
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		flex-shrink: 0;
	}

	.scanner-title {
		color: white;
		font-size: 1rem;
		font-weight: 600;
	}

	.scanner-viewport {
		flex: 1;
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
	}

	.scanner-video {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.scanner-canvas-hidden {
		display: none;
	}

	.scanner-frame {
		position: absolute;
		width: 220px;
		height: 220px;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
	}

	.corner {
		position: absolute;
		width: 30px;
		height: 30px;
		border-color: #22C55E;
		border-style: solid;
		border-width: 0;
	}
	.corner.tl { top: 0; left: 0; border-top-width: 4px; border-left-width: 4px; border-top-left-radius: 8px; }
	.corner.tr { top: 0; right: 0; border-top-width: 4px; border-right-width: 4px; border-top-right-radius: 8px; }
	.corner.bl { bottom: 0; left: 0; border-bottom-width: 4px; border-left-width: 4px; border-bottom-left-radius: 8px; }
	.corner.br { bottom: 0; right: 0; border-bottom-width: 4px; border-right-width: 4px; border-bottom-right-radius: 8px; }

	.scanner-error {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem;
		background: #FEE2E2;
		color: #DC2626;
		font-size: 0.85rem;
		font-weight: 500;
	}

	.scanner-instructions {
		text-align: center;
		color: rgba(255, 255, 255, 0.7);
		font-size: 0.85rem;
		padding: 1rem;
		background: rgba(0, 0, 0, 0.8);
	}
</style>
