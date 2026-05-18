<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { _, locale, switchLocale } from '$lib/i18n';
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { isAuthenticated as persistentAuthState, currentUser } from '$lib/utils/persistentAuth';
	import { interfacePreferenceService } from '$lib/utils/interfacePreference';

	$: showBackToInterface = $persistentAuthState && !!$currentUser;
	function goBackToInterface() {
		const route = interfacePreferenceService.getAppropriateRoute($currentUser?.id);
		goto(route || '/');
	}

	// ── State ─────────────────────────────────────────────────────────────────
	type Step = 'loading' | 'inactive' | 'capture' | 'validating' | 'ready' | 'revealing' | 'result';
	let step: Step = 'loading';
	let errorReason = '';
	let statusInfo: any = null;
	let validationMinimum: number | null = null;

	// ── Bill ──────────────────────────────────────────────────────────────────
	let billNumber = '';
	let billAmount: number | null = null;
	let billDate = '';
	let billImageFile: File | null = null;
	let billImagePreview = '';
	let ocrProcessing = false;
	let ocrDone = false;

	// ── Box reveal ────────────────────────────────────────────────────────────
	let boxCount = 6;
	let selectedBox: number | null = null;
	let isRevealing = false;
	let spinResult: any = null;

	// ── Manual entry (hidden: tap title 5×) ───────────────────────────────────
	let manualTapCount = 0;
	let showManualFields = false;
	let showAccessCodePopup = false;
	let accessCodeInput = '';
	let accessCodeError = '';
	let accessCodeLoading = false;
	let manualEntryUserId: string | null = null;
	let manualEntryUsername: string | null = null;

	// ── Logo ────────────────────────────────────────────────────────────────────
	let logoUrl = '';

	// ── Win fireworks ─────────────────────────────────────────────────────────
	let winCanvas: HTMLCanvasElement;
	let winLottieInit = false;

	// ── Background fireworks (always on) ───────────────────────────────
	let bgFireworksCanvas: HTMLCanvasElement;
	let realtimeChannel: any = null;

	// ── Terms ─────────────────────────────────────────────────────────────────
	const englishTerms = [
		'A valid sales bill is required.',
		'One play per bill only.',
		'One voucher issued per eligible bill.',
		'Voucher code is valid until the printed expiry date.',
		'Voucher cannot be exchanged for cash.',
		'Fraudulent, duplicate, or reused bills are not accepted.',
		'Offer valid while daily limit lasts.',
		'Management reserves the right to modify or stop the promotion at any time.'
	];
	const arabicTerms = [
		'مطلوب فاتورة بيع صحيحة.',
		'لعبة واحدة فقط لكل فاتورة.',
		'قسيمة واحدة لكل فاتورة مؤهلة.',
		'رمز القسيمة صالح حتى تاريخ انتهاء الصلاحية.',
		'لا يمكن استبدال القسيمة بنقد.',
		'لا تقبل الفواتير الاحتيالية أو المكررة أو المستخدمة مسبقاً.',
		'العرض سارٍ طالما الحد اليومي قائماً.',
		'تحتفظ الإدارة بالحق في تعديل أو إيقاف العرض في أي وقت.'
	];

	onMount(async () => {
		if ($locale !== 'ar') switchLocale('ar');

		// Fetch logo from app_icons
		try {
			const { data: iconData } = await supabase
				.from('app_icons')
				.select('storage_path')
				.eq('icon_key', 'aqura-logo')
				.eq('is_active', true)
				.single();
			if (iconData?.storage_path) {
				const { data: urlData } = supabase.storage.from('app-icons').getPublicUrl(iconData.storage_path);
				logoUrl = urlData.publicUrl;
			}
		} catch { /* logo is optional */ }

		await checkStatus();
		setupRealtime();

		// Background fireworks (always running)
		if (bgFireworksCanvas) {
			try {
				const { DotLottie } = await import('@lottiefiles/dotlottie-web');
				new DotLottie({
					autoplay: true,
					loop: true,
					canvas: bgFireworksCanvas,
					src: 'https://assets-v2.lottiefiles.com/a/d601a13e-1151-11ee-b2e2-73fdc183ef8e/eHMKup59WG.lottie'
				});
			} catch (e) { console.warn('Background fireworks failed', e); }
		}
	});

	onDestroy(() => {
		if (realtimeChannel) supabase.removeChannel(realtimeChannel);
	});

	// ── Win fireworks (re-run when canvas appears) ─────────────────────────────
	$: if (winCanvas && !winLottieInit) {
		winLottieInit = true;
		initWinFireworks();
	}
	function initWinFireworks() {
		import('@lottiefiles/dotlottie-web').then(({ DotLottie }) => {
			new DotLottie({
				autoplay: true,
				loop: true,
				canvas: winCanvas,
				src: 'https://assets-v2.lottiefiles.com/a/d601a13e-1151-11ee-b2e2-73fdc183ef8e/eHMKup59WG.lottie'
			});
		}).catch(e => console.warn('Fireworks failed', e));
	}

	function setupRealtime() {
		realtimeChannel = supabase
			.channel('surprise-box-customer-rt')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'surprise_box_settings' }, () => {
				if (step !== 'revealing' && step !== 'result') checkStatus();
			})
			.subscribe();
	}

	async function checkStatus() {
		step = 'loading';
		try {
			const { data, error } = await supabase.rpc('surprise_box_check_status');
			if (error) throw error;
			statusInfo = data;
			if (!data.active) {
				errorReason = data.reason || 'disabled';
				step = 'inactive';
			} else {
				boxCount = data.box_count || 6;
				step = 'capture';
				errorReason = '';
			}
		} catch {
			errorReason = 'connection_error';
			step = 'inactive';
		}
	}

	// ── OCR ───────────────────────────────────────────────────────────────────
	function handleFileCapture(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input?.files?.[0];
		if (!file) return;
		billImageFile = file;
		const reader = new FileReader();
		reader.onload = e => { billImagePreview = e.target?.result as string; };
		reader.readAsDataURL(file);
		processOCR(file);
	}

	async function processOCR(file: File) {
		ocrProcessing = true;
		ocrDone = false;
		try {
			const compressedBase64 = await new Promise<string>((resolve, reject) => {
				const img = new Image();
				const url = URL.createObjectURL(file);
				img.onload = () => {
					URL.revokeObjectURL(url);
					const canvas = document.createElement('canvas');
					const maxW = 1200, maxH = 1200;
					let w = img.naturalWidth, h = img.naturalHeight;
					if (w > maxW) { h = Math.round(h * maxW / w); w = maxW; }
					if (h > maxH) { w = Math.round(w * maxH / h); h = maxH; }
					canvas.width = w; canvas.height = h;
					canvas.getContext('2d')!.drawImage(img, 0, 0, w, h);
					const b64 = canvas.toDataURL('image/jpeg', 0.75).split(',')[1];
					resolve(b64);
				};
				img.onerror = reject;
				img.src = url;
			});

			// Get Google API key
			const { data: keyRow } = await supabase
				.from('system_api_keys')
				.select('api_key')
				.eq('service_name', 'google')
				.eq('is_active', true)
				.limit(1)
				.single();
			const apiKey = keyRow?.api_key;
			if (!apiKey) throw new Error('No API key');

			// Google Vision OCR
			const visionRes = await fetch(
				`https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
				{
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						requests: [{
							image: { content: compressedBase64 },
							features: [{ type: 'TEXT_DETECTION', maxResults: 1 }]
						}]
					})
				}
			);
			const visionData = await visionRes.json();
			const ocrText = visionData?.responses?.[0]?.fullTextAnnotation?.text || '';

			// Gemini parse
			const geminiRes = await fetch(
				`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
				{
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						contents: [{
							parts: [{
								text: `Extract bill info from this receipt text. Return JSON: {"bill_number":"...","bill_amount":number,"bill_date":"YYYY-MM-DD"}. If not found use null. Text:\n${ocrText}`
							}]
						}],
						generationConfig: { temperature: 0, responseMimeType: 'application/json' }
					})
				}
			);
			const geminiData = await geminiRes.json();
			const raw = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
			let parsed: any = {};
			try { parsed = JSON.parse(raw); } catch { /* fallback below */ }

			if (parsed.bill_number) billNumber = String(parsed.bill_number).trim();
			if (parsed.bill_amount != null) billAmount = Number(parsed.bill_amount);
			if (parsed.bill_date) billDate = String(parsed.bill_date).trim();
		} catch {
			// Regex fallback
			if (billImageFile) {
				const text = await billImageFile.text().catch(() => '');
				const numMatch = text.match(/\b\d{4,}\b/);
				if (numMatch) billNumber = numMatch[0];
				const amtMatch = text.match(/(\d+(?:\.\d{1,2})?)/);
				if (amtMatch) billAmount = parseFloat(amtMatch[1]);
			}
		} finally {
			ocrProcessing = false;
			ocrDone = true;
		}
	}

	// ── Validate & proceed to box screen ─────────────────────────────────────
	async function validateAndProceed() {
		if (!billNumber.trim() || !billAmount || billAmount <= 0) return;
		step = 'validating';
		try {
			const { data, error } = await supabase.rpc('surprise_box_validate_bill', {
				p_bill_number: billNumber.trim(),
				p_bill_amount: billAmount,
				p_bill_date: billDate || null
			});
			if (error) throw error;
			if (!data.valid) {
				errorReason = data.reason || 'unknown';
				if (data.minimum != null) validationMinimum = data.minimum;
				step = 'capture';
				return;
			}
			selectedBox = null;
			step = 'ready';
		} catch {
			errorReason = 'connection_error';
			step = 'capture';
		}
	}

	// ── Play (choose a box) ────────────────────────────────────────────────────
	async function chooseBox(boxIndex: number) {
		if (isRevealing || selectedBox !== null) return;
		selectedBox = boxIndex;
		isRevealing = true;
		step = 'revealing';

		try {
			const { data, error } = await supabase.rpc('surprise_box_play', {
				p_bill_number: billNumber.trim(),
				p_bill_amount: billAmount,
				p_bill_date: billDate || null,
				p_box_selected: boxIndex,
				p_manual_entry: showManualFields,
				p_manual_entry_by: manualEntryUserId ? manualEntryUserId : null,
				p_manual_entry_username: manualEntryUsername || null
			});
			if (error) throw error;
			spinResult = data;
		} catch {
			spinResult = { success: false, reason: 'connection_error' };
		} finally {
			// Short delay so the lid-open animation can play
			await new Promise(r => setTimeout(r, 1400));
			isRevealing = false;
			winLottieInit = false;
			step = 'result';
		}
	}

	// ── Canvas voucher download ───────────────────────────────────────────────
	async function downloadVoucher() {
		const reward = spinResult?.reward;
		if (!reward || !spinResult?.voucher_code) return;

		const { downloadVoucherPNG } = await import('$lib/utils/voucherCanvas');
		const rewardLabel = $locale === 'ar'
			? (reward.label_ar || reward.label_en || 'قسيمة مشتريات')
			: (reward.label_en || reward.label_ar || 'Shopping Voucher');

		await downloadVoucherPNG(
			{
				voucherCode:  spinResult.voucher_code,
				voucherValue: reward.voucher_value ?? 0,
				rewardLabel,
				expiresAt:    spinResult.expires_at,
				billNumber:   billNumber
			},
			`surprise-box-${spinResult.voucher_code}.png`
		);
	}

	// ── Manual entry helpers ──────────────────────────────────────────────────
	function handleTitleTap() {
		manualTapCount++;
		if (manualTapCount >= 5) {
			manualTapCount = 0;
			showAccessCodePopup = true;
		}
	}

	async function submitAccessCode() {
		if (accessCodeInput.trim().length !== 6) {
			accessCodeError = $locale === 'ar' ? 'يجب أن يكون الرمز 6 أرقام' : 'Code must be 6 digits';
			return;
		}
		accessCodeLoading = true;
		accessCodeError = '';
		try {
			const { data, error } = await supabase.rpc('verify_quick_access_code', { p_code: accessCodeInput.trim() });
			if (error || !data?.success) {
				accessCodeError = $locale === 'ar' ? 'رمز الدخول غير صحيح' : 'Invalid access code';
			} else {
				manualEntryUserId = data.user?.id || null;
				manualEntryUsername = data.user?.username || null;
				showManualFields = true;
				showAccessCodePopup = false;
				accessCodeInput = '';
				accessCodeError = '';
			}
		} catch {
			accessCodeError = $locale === 'ar' ? 'خطأ في الاتصال' : 'Connection error';
		} finally {
			accessCodeLoading = false;
		}
	}

	// ── Helpers ───────────────────────────────────────────────────────────────
	function reset() {
		step = 'capture';
		billNumber = '';
		billAmount = null;
		billDate = '';
		billImageFile = null;
		billImagePreview = '';
		ocrDone = false;
		selectedBox = null;
		spinResult = null;
		showManualFields = false;
		errorReason = '';
		validationMinimum = null;
		winLottieInit = false;
	}

	$: inactiveMessage = (() => {
		const msgs: Record<string, { en: string; ar: string }> = {
			disabled:            { en: 'Surprise Box is currently inactive.', ar: 'صندوق المفاجآت غير نشط حالياً.' },
			not_configured:      { en: 'Surprise Box is not configured yet.', ar: 'لم يتم إعداد صندوق المفاجآت بعد.' },
			not_started:         { en: 'Promotion has not started yet.', ar: 'لم يبدأ العرض بعد.' },
			ended:               { en: 'Promotion has ended.', ar: 'انتهى العرض.' },
			daily_limit_reached: { en: 'Daily limit reached. Come back tomorrow!', ar: 'تم الوصول للحد اليومي. عودوا غداً!' },
			connection_error:    { en: 'Connection error. Please try again.', ar: 'خطأ في الاتصال. حاول مجدداً.' }
		};
		const m = msgs[errorReason] || { en: 'Surprise Box is currently unavailable.', ar: 'صندوق المفاجآت غير متاح حالياً.' };
		return $locale === 'ar' ? m.ar : m.en;
	})();

	$: validationError = (() => {
		if (!errorReason) return '';
		const msgs: Record<string, { en: string; ar: string }> = {
			below_minimum:    { en: `Minimum bill amount is ${validationMinimum ?? statusInfo?.minimum_bill_amount} SAR.`, ar: `الحد الأدنى للفاتورة ${validationMinimum ?? statusInfo?.minimum_bill_amount} ريال.` },
			already_played:   { en: 'This bill has already been played.', ar: 'هذه الفاتورة استُخدمت مسبقاً.' },
			wrong_bill_date:  { en: "Bill must be from today's date only.", ar: 'يجب أن تكون الفاتورة من تاريخ اليوم فقط.' },
			connection_error: { en: 'Connection error. Please try again.', ar: 'خطأ في الاتصال. حاول مجدداً.' }
		};
		const m = msgs[errorReason] || { en: 'Validation failed. Please check your bill.', ar: 'فشل التحقق. يرجى مراجعة الفاتورة.' };
		return $locale === 'ar' ? m.ar : m.en;
	})();
</script>

<svelte:head>
	<title>{$locale === 'ar' ? 'صندوق المفاجآت' : 'Surprise Box'}</title>
</svelte:head>

<canvas bind:this={bgFireworksCanvas} class="sb-bg-fireworks" width="1200" height="1200"></canvas>

<div class="sb-page" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>

	<!-- Logo at top -->
	<div class="sb-logo-wrapper">
		<div class="sb-logo-container" role="button" tabindex="0" on:click={handleTitleTap} on:keydown={() => {}} title="" style="cursor: default;">
			{#if logoUrl}
				<img src={logoUrl} alt="Aqura" class="sb-logo-img" />
			{:else}
				<div class="sb-logo">🎁</div>
			{/if}
		</div>
	</div>

	<!-- Header -->
	<header class="sb-header">
		<button class="lang-btn" on:click={() => switchLocale($locale === 'ar' ? 'en' : 'ar')}>
			{$locale === 'ar' ? 'EN' : 'عربي'}
		</button>
		{#if showBackToInterface}
			<button class="back-btn" on:click={goBackToInterface}>
				{$locale === 'ar' ? '← العودة' : '← Back'}
			</button>
		{/if}
	</header>

	<!-- Gift box icon spacer -->
	<div class="sb-gift-icon">🎁</div>

	<!-- Title -->
	<div class="sb-title-area">
		<h1 class="sb-title">{$locale === 'ar' ? 'صندوق المفاجآت' : 'Surprise Box'}</h1>
		<p class="sb-subtitle">{$locale === 'ar' ? 'اختر صندوقاً واكتشف مفاجأتك!' : 'Pick a box and discover your surprise!'}</p>
	</div>

	<!-- ── LOADING ─────────────────────────────────────────────────────────── -->
	{#if step === 'loading'}
		<div class="sb-center">
			<div class="sb-spinner"></div>
			<p class="sb-loading-text">{$locale === 'ar' ? 'جار التحميل…' : 'Loading…'}</p>
		</div>

	<!-- ── INACTIVE ────────────────────────────────────────────────────────── -->
	{:else if step === 'inactive'}
		<div class="sb-inactive-card">
			<div class="sb-inactive-icon">😔</div>
			<p class="sb-inactive-msg">{inactiveMessage}</p>
		</div>

	<!-- ── CAPTURE (bill scan) ─────────────────────────────────────────────── -->
	{:else if step === 'capture'}
		<div class="sb-card">
			<h2 class="sb-card-title">
			{showManualFields
				? ($locale === 'ar' ? '✏️ إدخال يدوي' : '✏️ Manual Entry')
				: ($locale === 'ar' ? '📸 صورة الفاتورة' : '📸 Bill Photo')}
		</h2>

			<!-- File capture (hidden in manual mode) -->
			{#if !showManualFields}
			<label class="sb-upload-label">
				{#if billImagePreview}
					<img src={billImagePreview} alt="Bill preview" class="sb-img-preview" />
					<span class="sb-re-capture">{$locale === 'ar' ? 'التقاط من جديد' : 'Retake'}</span>
				{:else}
					<div class="sb-upload-icon">📷</div>
					<span class="sb-upload-text">
						{$locale === 'ar' ? 'انقر لالتقاط صورة الفاتورة' : 'Tap to capture bill photo'}
					</span>
				{/if}
				<input type="file" accept="image/*" capture="environment" class="sb-file-input" on:change={handleFileCapture} />
			</label>

			{#if ocrProcessing}
				<div class="sb-ocr-status">
					<div class="sb-spinner sb-spinner--sm"></div>
					<span>{$locale === 'ar' ? 'يتم قراءة الفاتورة تلقائياً…' : 'Reading bill automatically…'}</span>
				</div>
			{/if}
			{/if}

			<!-- Bill fields: shown in manual mode or after OCR fills data -->
			{#if showManualFields || billNumber || billAmount}
			<div class="sb-fields">
				<div class="sb-field">
					<label class="sb-label">{$locale === 'ar' ? 'رقم الفاتورة' : 'Bill Number'} *</label>
					<input
						class="sb-input"
						type="text"
						bind:value={billNumber}
						placeholder={$locale === 'ar' ? 'أدخل رقم الفاتورة' : 'Enter bill number'}
						disabled={!showManualFields}
					/>
				</div>
				<div class="sb-field">
					<label class="sb-label">{$locale === 'ar' ? 'إجمالي الفاتورة (ريال)' : 'Bill Total (SAR)'} *</label>
					<input
						class="sb-input"
						type="number"
						min="0"
						step="0.01"
						bind:value={billAmount}
						placeholder={$locale === 'ar' ? 'أدخل المبلغ' : 'Enter amount'}
						disabled={!showManualFields}
					/>
				</div>
				<div class="sb-field">
					<label class="sb-label">{$locale === 'ar' ? 'تاريخ الفاتورة' : 'Bill Date'}</label>
					<input class="sb-input" type="date" bind:value={billDate} disabled={!showManualFields} />
				</div>

				{#if showManualFields}
					<div class="sb-manual-badge">
						✏️ {$locale === 'ar' ? `إدخال يدوي بواسطة: ${manualEntryUsername}` : `Manual entry by: ${manualEntryUsername}`}
					</div>
				{/if}
			</div>
			{/if}

			{#if validationError}
				<div class="sb-error">{validationError}</div>
			{/if}

			{#if statusInfo?.minimum_bill_amount > 0}
				<p class="sb-min-hint">
					{$locale === 'ar'
						? `الحد الأدنى للفاتورة: ${statusInfo.minimum_bill_amount} ريال`
						: `Minimum bill amount: ${statusInfo.minimum_bill_amount} SAR`}
				</p>
			{/if}

			{#if errorReason}
				<button class="sb-btn sb-btn--primary" on:click={reset}>
					{$locale === 'ar' ? '← جرّب بفاتورة جديدة' : 'Try with New Bill →'}
				</button>
			{:else}
				<button
					class="sb-btn sb-btn--primary"
					disabled={!billNumber.trim() || !billAmount || billAmount <= 0 || ocrProcessing}
					on:click={validateAndProceed}
				>
					{$locale === 'ar' ? 'التالي ← اختر صندوقك' : 'Next → Pick Your Box'}
				</button>
			{/if}

			<!-- Terms -->
			<details class="sb-terms" open>
				<summary class="sb-terms-summary">
					{$locale === 'ar' ? 'الشروط والأحكام' : 'Terms & Conditions'}
				</summary>
				<ul class="sb-terms-list">
					{#each ($locale === 'ar' ? arabicTerms : englishTerms) as term}
						<li>{term}</li>
					{/each}
				</ul>
			</details>
		</div>

	<!-- ── VALIDATING ──────────────────────────────────────────────────────── -->
	{:else if step === 'validating'}
		<div class="sb-center">
			<div class="sb-spinner"></div>
			<p class="sb-loading-text">{$locale === 'ar' ? 'جار التحقق…' : 'Validating…'}</p>
		</div>

	<!-- ── READY (choose a box) ────────────────────────────────────────────── -->
	{:else if step === 'ready'}
		<div class="sb-card sb-card--wide">
			<h2 class="sb-card-title">
				{$locale === 'ar' ? '🎁 اختر صندوقاً!' : '🎁 Pick a Box!'}
			</h2>
			<p class="sb-pick-hint">
				{$locale === 'ar' ? 'انقر على أي صندوق لاكتشاف مفاجأتك' : 'Tap any box to reveal your surprise'}
			</p>
			<div class="sb-boxes" style="--cols: {Math.min(boxCount, 4)}">
				{#each Array(boxCount) as _, i}
					<button
						class="sb-box"
						style="animation-delay: {i * 0.18}s"
						on:click={() => chooseBox(i + 1)}
					>
						<div class="sb-box-lid">🎁</div>
						<span class="sb-box-num">{i + 1}</span>
					</button>
				{/each}
			</div>
			<div class="sb-bill-summary">
				{$locale === 'ar' ? `فاتورة: ${billNumber} | المبلغ: ${billAmount} ريال` : `Bill: ${billNumber} | Amount: ${billAmount} SAR`}
			</div>
		</div>

	<!-- ── REVEALING ──────────────────────────────────────────────────────── -->
	{:else if step === 'revealing'}
		<div class="sb-center">
			<div class="sb-reveal-animation">
				<div class="sb-box-opening">
					<span class="sb-box-big">🎁</span>
					<div class="sb-sparkles">✨ ✨ ✨</div>
				</div>
			</div>
			<p class="sb-loading-text">
				{$locale === 'ar' ? 'جار فتح الصندوق…' : 'Opening box…'}
			</p>
		</div>

	<!-- ── RESULT ──────────────────────────────────────────────────────────── -->
	{:else if step === 'result'}
		{#if spinResult?.success && spinResult?.is_winner}
			<!-- WIN -->
			<div class="sb-result-card sb-result--win">
				<canvas bind:this={winCanvas} class="sb-fireworks"></canvas>
				<div class="sb-win-icon">🎉</div>
				<h2 class="sb-win-title">{$locale === 'ar' ? 'مبروك! ربحت!' : 'Congratulations! You Won!'}</h2>

				<div class="sb-voucher-card">
					<div class="sb-voucher-label">
						{$locale === 'ar'
							? (spinResult.reward?.label_ar || spinResult.reward?.label_en)
							: (spinResult.reward?.label_en || spinResult.reward?.label_ar)}
					</div>
					<div class="sb-voucher-value">{spinResult.reward?.voucher_value} SAR</div>
					<div class="sb-voucher-code-box">
						<span class="sb-voucher-code">{spinResult.voucher_code}</span>
					</div>
					<div class="sb-voucher-expiry">
						{$locale === 'ar' ? `صالح حتى: ${spinResult.expires_at}` : `Valid until: ${spinResult.expires_at}`}
					</div>
				</div>

				<div class="sb-result-actions">
					<button class="sb-btn sb-btn--gold" on:click={downloadVoucher}>
						{$locale === 'ar' ? '⬇ تحميل القسيمة' : '⬇ Download Voucher'}
					</button>
					<button class="sb-btn sb-btn--ghost" on:click={reset}>
						{$locale === 'ar' ? 'العودة للرئيسية' : 'Back to Home'}
					</button>
				</div>

				<p class="sb-cashier-hint">
					{$locale === 'ar'
						? '* اعرض هذا الكود للكاشير لاستخدام القسيمة'
						: '* Show this code to the cashier to redeem your voucher'}
				</p>
			</div>

		{:else if spinResult?.success && !spinResult?.is_winner}
			<!-- NO WIN -->
			<div class="sb-result-card sb-result--nowin">
				<div class="sb-nowin-icon">😊</div>
				<h2 class="sb-nowin-title">{$locale === 'ar' ? 'حظ أوفر المرة القادمة!' : 'Better Luck Next Time!'}</h2>
				<p class="sb-nowin-sub">
					{$locale === 'ar' ? 'شكراً لمشاركتك! تابع تسوقك معنا.' : 'Thank you for participating! Keep shopping with us.'}
				</p>
				<button class="sb-btn sb-btn--ghost" on:click={reset}>
					{$locale === 'ar' ? 'العودة' : 'Back'}
				</button>
			</div>

		{:else}
			<!-- ERROR -->
			<div class="sb-result-card sb-result--error">
				<div class="sb-error-icon">⚠️</div>
				<h2>{$locale === 'ar' ? 'حدث خطأ' : 'Something Went Wrong'}</h2>
				<p>
					{$locale === 'ar'
						? 'يرجى مراجعة الكاشير للمساعدة.'
						: 'Please see the cashier for assistance.'}
				</p>
				<button class="sb-btn sb-btn--ghost" on:click={reset}>
					{$locale === 'ar' ? 'المحاولة مجدداً' : 'Try Again'}
				</button>
			</div>
		{/if}
	{/if}

	<!-- Access code popup -->
	{#if showAccessCodePopup}
		<div class="sb-overlay">
			<div class="sb-popup">
				<h3>{$locale === 'ar' ? 'رمز الوصول' : 'Access Code'}</h3>
				<input
					class="sb-input"
					type="password"
					bind:value={accessCodeInput}
					placeholder={$locale === 'ar' ? 'أدخل الرمز' : 'Enter code'}
					on:keydown={e => e.key === 'Enter' && submitAccessCode()}
				/>
				{#if accessCodeError}
					<p class="sb-error">{accessCodeError}</p>
				{/if}
				<div class="sb-popup-btns">
					<button class="sb-btn sb-btn--primary" disabled={accessCodeLoading} on:click={submitAccessCode}>
						{accessCodeLoading ? '…' : ($locale === 'ar' ? 'تأكيد' : 'Confirm')}
					</button>
					<button class="sb-btn sb-btn--ghost" on:click={() => { showAccessCodePopup = false; accessCodeInput = ''; accessCodeError = ''; }}>
						{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
					</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	:global(body) {
		margin: 0;
		background: #1E0033;
		font-family: 'Segoe UI', Arial, sans-serif;
	}

	.sb-page {
		min-height: 100dvh;
		width: 100%;
		background: linear-gradient(160deg, #2D0052 0%, #4A0E8F 50%, #1E0033 100%);
		color: #fff;
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 0 1rem 3rem;
		position: relative;
		z-index: 2;
		box-sizing: border-box;
	}

	/* ── Header ─────────────────────────────────────────────────────────────── */
	.sb-header {
		width: 100%;
		max-width: 680px;
		display: flex;
		justify-content: flex-end;
		gap: 0.5rem;
		padding: 0.25rem 0;
	}
	.lang-btn, .back-btn {
		background: rgba(255,255,255,0.12);
		border: 1px solid rgba(255,255,255,0.25);
		color: #fff;
		padding: 0.35rem 0.85rem;
		border-radius: 20px;
		font-size: 0.85rem;
		cursor: pointer;
		transition: background 0.2s;
	}
	.lang-btn:hover, .back-btn:hover { background: rgba(255,255,255,0.22); }

	/* ── Logo wrapper ───────────────────────────────────────────────────────── */
	.sb-logo-wrapper {
		width: 100%;
		display: flex;
		justify-content: center;
		align-items: center;
		padding: 0.5rem 0 0;
	}
	.sb-logo-container {
		background: #ffffff;
		border: 2.5px solid #F59E0B;
		border-radius: 18px;
		padding: 0.75rem 1.75rem;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 24px rgba(245, 158, 11, 0.28), 0 1px 4px rgba(0,0,0,0.18);
	}
	.sb-logo { font-size: 2.5rem; }

	/* ── Gift icon ───────────────────────────────────────────────────────────── */
	.sb-gift-icon {
		font-size: 3.5rem;
		text-align: center;
		padding: 0;
		margin-top: -2.5rem;
		filter: drop-shadow(0 4px 12px rgba(245, 158, 11, 0.4));
		animation: sb-bounce 2s ease-in-out infinite;
	}
	@keyframes sb-bounce {
		0%, 100% { transform: translateY(0); }
		50% { transform: translateY(-6px); }
	}

	/* ── Title ───────────────────────────────────────────────────────────────── */
	.sb-title-area {
		text-align: center;
		padding: 0.75rem 0 1rem;
		cursor: default;
	}
	.sb-title {
		font-size: 2rem;
		font-weight: 900;
		background: linear-gradient(90deg, #F59E0B, #FDE68A, #F59E0B);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		margin: 0 0 0.25rem;
	}
	.sb-subtitle { color: #D4B3FF; font-size: 1rem; margin: 0; }

	/* ── Card ────────────────────────────────────────────────────────────────── */
	.sb-card {
		width: 100%;
		max-width: 480px;
		background: rgba(255,255,255,0.07);
		backdrop-filter: blur(10px);
		border: 1px solid rgba(245,158,11,0.3);
		border-radius: 20px;
		padding: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1rem;
		margin-top: 0.5rem;
	}
	.sb-card--wide { max-width: 680px; }
	.sb-card-title {
		font-size: 1.3rem;
		font-weight: 800;
		color: #F59E0B;
		margin: 0;
		text-align: center;
	}

	/* ── Upload ──────────────────────────────────────────────────────────────── */
	.sb-upload-label {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		border: 2px dashed rgba(245,158,11,0.4);
		border-radius: 14px;
		padding: 1.5rem;
		cursor: pointer;
		gap: 0.5rem;
		transition: border-color 0.2s;
		position: relative;
		overflow: hidden;
		min-height: 130px;
	}
	.sb-upload-label:hover { border-color: #F59E0B; }
	.sb-upload-icon { font-size: 2.5rem; }
	.sb-upload-text { color: #D4B3FF; font-size: 0.95rem; text-align: center; }
	.sb-file-input { position: absolute; inset: 0; opacity: 0; cursor: pointer; }
	.sb-img-preview { width: 100%; max-height: 200px; object-fit: contain; border-radius: 8px; }
	.sb-re-capture { color: #F59E0B; font-size: 0.85rem; }

	/* ── OCR status ──────────────────────────────────────────────────────────── */
	.sb-ocr-status {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		color: #D4B3FF;
		font-size: 0.9rem;
	}

	/* ── Fields ──────────────────────────────────────────────────────────────── */
	.sb-fields { display: flex; flex-direction: column; gap: 0.75rem; }
	.sb-field { display: flex; flex-direction: column; gap: 0.3rem; }
	.sb-label { font-size: 0.85rem; color: #D4B3FF; }
	.sb-input {
		background: rgba(255,255,255,0.1);
		border: 1px solid rgba(245,158,11,0.3);
		border-radius: 10px;
		color: #fff;
		padding: 0.7rem 0.9rem;
		font-size: 1rem;
		outline: none;
		width: 100%;
		box-sizing: border-box;
		transition: border-color 0.2s;
	}
	.sb-input:focus { border-color: #F59E0B; }
	.sb-input::placeholder { color: rgba(255,255,255,0.35); }

	.sb-manual-badge {
		background: rgba(245,158,11,0.15);
		border: 1px solid rgba(245,158,11,0.4);
		border-radius: 8px;
		padding: 0.5rem 0.75rem;
		font-size: 0.85rem;
		color: #F59E0B;
	}

	.sb-min-hint { color: #D4B3FF; font-size: 0.85rem; margin: 0; text-align: center; }

	/* ── Buttons ─────────────────────────────────────────────────────────────── */
	.sb-btn {
		width: 100%;
		padding: 0.85rem 1.5rem;
		border-radius: 12px;
		border: none;
		font-size: 1rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
	}
	.sb-btn:disabled { opacity: 0.4; cursor: not-allowed; }
	.sb-btn--primary {
		background: linear-gradient(90deg, #7C3AED, #9333EA);
		color: #fff;
		box-shadow: 0 4px 20px rgba(124,58,237,0.4);
	}
	.sb-btn--primary:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 6px 24px rgba(124,58,237,0.55); }
	.sb-btn--gold {
		background: linear-gradient(90deg, #D97706, #F59E0B);
		color: #1E0033;
		box-shadow: 0 4px 20px rgba(245,158,11,0.4);
	}
	.sb-btn--gold:hover:not(:disabled) { transform: translateY(-2px); }
	.sb-btn--ghost {
		background: rgba(255,255,255,0.1);
		border: 1px solid rgba(255,255,255,0.25);
		color: #fff;
	}
	.sb-btn--ghost:hover:not(:disabled) { background: rgba(255,255,255,0.18); }

	/* ── Error ───────────────────────────────────────────────────────────────── */
	.sb-error {
		background: rgba(239,68,68,0.15);
		border: 1px solid rgba(239,68,68,0.4);
		border-radius: 8px;
		padding: 0.6rem 0.9rem;
		color: #FCA5A5;
		font-size: 0.9rem;
	}

	/* ── Terms ───────────────────────────────────────────────────────────────── */
	.sb-terms { margin-top: 0.5rem; }
	.sb-terms-summary {
		cursor: pointer;
		color: #D4B3FF;
		font-size: 0.9rem;
		font-weight: 600;
		list-style: none;
	}
	.sb-terms-list {
		margin: 0.5rem 0 0;
		padding: 0 1rem;
		list-style: disc;
	}
	.sb-terms-list li {
		color: rgba(255,255,255,0.65);
		font-size: 0.8rem;
		line-height: 1.7;
	}

	/* ── Centre ──────────────────────────────────────────────────────────────── */
	.sb-center {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		padding: 3rem 0;
	}
	.sb-loading-text { color: #D4B3FF; font-size: 1rem; }

	/* ── Spinner ─────────────────────────────────────────────────────────────── */
	.sb-spinner {
		width: 48px;
		height: 48px;
		border: 4px solid rgba(245,158,11,0.2);
		border-top-color: #F59E0B;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	.sb-spinner--sm { width: 22px; height: 22px; border-width: 3px; }
	@keyframes spin { to { transform: rotate(360deg); } }

	/* ── Inactive ────────────────────────────────────────────────────────────── */
	.sb-inactive-card {
		background: rgba(255,255,255,0.06);
		border: 1px solid rgba(255,255,255,0.12);
		border-radius: 20px;
		padding: 2.5rem 2rem;
		text-align: center;
		max-width: 400px;
		width: 100%;
		margin-top: 1rem;
	}
	.sb-inactive-icon { font-size: 3rem; margin-bottom: 1rem; }
	.sb-inactive-msg { color: #D4B3FF; font-size: 1.1rem; line-height: 1.6; }

	/* ── Boxes ───────────────────────────────────────────────────────────────── */
	.sb-pick-hint { text-align: center; color: #D4B3FF; font-size: 0.95rem; margin: 0; }
	.sb-boxes {
		display: grid;
		grid-template-columns: repeat(var(--cols, 3), 1fr);
		gap: 0.75rem;
		padding: 0.5rem 0;
	}
	@keyframes sb-heartbeat {
		0%   { transform: scale(1);    }
		14%  { transform: scale(1.12); }
		28%  { transform: scale(1);    }
		42%  { transform: scale(1.08); }
		70%  { transform: scale(1);    }
		100% { transform: scale(1);    }
	}
	.sb-box {
		background: linear-gradient(135deg, #5B21B6, #7C3AED);
		border: 2px solid rgba(245,158,11,0.4);
		border-radius: 16px;
		padding: 1.25rem 0.5rem 0.75rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.4rem;
		cursor: pointer;
		transition: border-color 0.2s, box-shadow 0.2s;
		width: 100%;
		min-width: 0;
		box-shadow: 0 4px 20px rgba(124,58,237,0.3);
		animation: sb-heartbeat 1.4s ease-in-out infinite;
	}
	.sb-box:hover {
		transform: translateY(-6px) scale(1.05);
		border-color: #F59E0B;
		box-shadow: 0 10px 30px rgba(245,158,11,0.35);
	}
	.sb-box-lid { font-size: 2.5rem; }
	.sb-box-num { font-size: 0.8rem; color: rgba(255,255,255,0.6); font-weight: 600; }

	.sb-bill-summary {
		text-align: center;
		color: #D4B3FF;
		font-size: 0.85rem;
		margin-top: 0.25rem;
	}

	/* ── Revealing animation ─────────────────────────────────────────────────── */
	.sb-reveal-animation { text-align: center; }
	.sb-box-opening { animation: bounceOpen 1.4s ease-in-out; }
	.sb-box-big { font-size: 5rem; display: block; }
	.sb-sparkles {
		font-size: 1.5rem;
		letter-spacing: 0.5rem;
		animation: sparkle 0.5s alternate infinite;
	}
	@keyframes bounceOpen {
		0%   { transform: scale(1); }
		30%  { transform: scale(1.15) rotate(-5deg); }
		60%  { transform: scale(0.95) rotate(5deg); }
		80%  { transform: scale(1.1); }
		100% { transform: scale(1); }
	}
	@keyframes sparkle { from { opacity: 0.4; } to { opacity: 1; } }

	/* ── Result cards ────────────────────────────────────────────────────────── */
	.sb-result-card {
		width: 100%;
		max-width: 520px;
		border-radius: 24px;
		padding: 2rem 1.5rem;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.25rem;
		margin-top: 0.5rem;
		position: relative;
		overflow: hidden;
	}
	.sb-result--win {
		background: linear-gradient(135deg, #14532D, #166534);
		border: 2px solid #22C55E;
		box-shadow: 0 8px 40px rgba(34,197,94,0.3);
	}
	.sb-result--nowin {
		background: rgba(255,255,255,0.06);
		border: 1px solid rgba(255,255,255,0.15);
	}
	.sb-result--error {
		background: rgba(239,68,68,0.08);
		border: 1px solid rgba(239,68,68,0.3);
	}

	.sb-fireworks {
		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;
		pointer-events: none;
		z-index: 9999;
	}

	.sb-win-icon { font-size: 3.5rem; position: relative; }
	.sb-win-title {
		font-size: 1.6rem;
		font-weight: 900;
		color: #4ADE80;
		text-align: center;
		margin: 0;
		position: relative;
	}

	/* ── Voucher card ────────────────────────────────────────────────────────── */
	.sb-voucher-card {
		background: linear-gradient(135deg, #3B0764, #6B21A8);
		border: 2px solid #F59E0B;
		border-radius: 16px;
		padding: 1.25rem;
		width: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.6rem;
		position: relative;
	}
	.sb-voucher-label { color: #FDE68A; font-size: 1.1rem; font-weight: 700; text-align: center; }
	.sb-voucher-value { color: #F59E0B; font-size: 2rem; font-weight: 900; }
	.sb-voucher-code-box {
		background: rgba(245,158,11,0.12);
		border: 1px dashed #F59E0B;
		border-radius: 10px;
		padding: 0.6rem 1.5rem;
		width: 100%;
		text-align: center;
		box-sizing: border-box;
	}
	.sb-voucher-code { font-family: monospace; font-size: 1.4rem; font-weight: 900; color: #F5E6FF; letter-spacing: 0.1rem; }
	.sb-voucher-expiry { color: #D4B3FF; font-size: 0.85rem; }

	.sb-result-actions { display: flex; flex-direction: column; gap: 0.75rem; width: 100%; position: relative; }
	.sb-cashier-hint { color: rgba(255,255,255,0.55); font-size: 0.8rem; text-align: center; margin: 0; position: relative; }

	.sb-nowin-icon { font-size: 3rem; }
	.sb-nowin-title { font-size: 1.5rem; font-weight: 800; color: #FDE68A; margin: 0; text-align: center; }
	.sb-nowin-sub { color: #D4B3FF; font-size: 0.95rem; text-align: center; margin: 0; }
	.sb-error-icon { font-size: 2.5rem; }

	/* ── Overlay / popup ─────────────────────────────────────────────────────── */
	.sb-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0,0,0,0.7);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 100;
		padding: 1rem;
	}
	.sb-popup {
		background: #2D0052;
		border: 2px solid #F59E0B;
		border-radius: 20px;
		padding: 2rem;
		width: 100%;
		max-width: 380px;
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
	.sb-popup h3 { color: #F59E0B; margin: 0; text-align: center; }
	.sb-popup-btns { display: flex; gap: 0.75rem; }

	/* ── Logo image ─────────────────────────────────────────────────────────────── */
	.sb-logo-img {
		height: 52px;
		max-width: 180px;
		object-fit: contain;
	}

	/* ── Background fireworks ───────────────────────────────────────────────────── */
	:global(.sb-bg-fireworks) {
		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;
		pointer-events: none;
		z-index: 3;
		opacity: 0.8;
	}

	/* ── Responsive ──────────────────────────────────────────────────────────── */
	@media (max-width: 480px) {
		.sb-page { padding: 0 0.75rem 3rem; }
		.sb-title { font-size: 1.6rem; }
		.sb-card { padding: 1.1rem; }
		.sb-card--wide { padding: 1.1rem; }
		.sb-box-lid { font-size: 2rem; }
		.sb-result-card { padding: 1.5rem 1rem; }
	}
	@media (max-width: 360px) {
		.sb-title { font-size: 1.3rem; }
		.sb-logo-img { height: 38px; }
		.sb-logo-container { padding: 0.6rem 1.25rem; border-radius: 14px; }
		.sb-boxes { grid-template-columns: repeat(3, 1fr); gap: 0.5rem; }
		.sb-box-lid { font-size: 1.75rem; }
		.sb-box-num { font-size: 0.7rem; }
	}
</style>
