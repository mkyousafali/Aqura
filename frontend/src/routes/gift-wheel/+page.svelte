<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { _, locale, switchLocale } from '$lib/i18n';
	import { onMount, onDestroy } from 'svelte';
	import { iconUrlMap } from '$lib/stores/iconStore';

	// State
	let step: 'loading' | 'inactive' | 'capture' | 'validating' | 'ready' | 'spinning' | 'result' = 'loading';
	let errorMessage = '';
	let errorReason = ''; // Store error reason for reactive translation
	let statusInfo: any = null;

	// Bill
	let billNumber = '';
	let billAmount: number | null = null;
	let billDate = '';
	let billImageFile: File | null = null;
	let billImagePreview = '';
	let ocrProcessing = false;

	// Wheel
	let wheelRotation = 0;
	let isSpinning = false;
	let spinResult: any = null;
	let rewards: any[] = [];
	let wheelSegments: { label: string; color: string }[] = [];

	// Terms
	const englishTerms = [
		'Valid sales bill is required.',
		'Bill photo must be uploaded for verification.',
		'One spin allowed per bill only.',
		'One coupon issued per eligible bill.',
		'Coupon must be printed by cashier to be valid.',
		'Discounts can be used on the next purchase only.',
		'Percentage discount or maximum discount amount will apply, whichever is lower.',
		'Coupon cannot be exchanged for cash.',
		'Coupon is valid until the printed expiry date.',
		'Lost printed coupon cannot be redeemed or replaced.',
		'Fraudulent, duplicate, or reused bills are not accepted.',
		'Offer valid while daily limit lasts.',
		'Management reserves the right to modify or stop the promotion at any time.'
	];

	const arabicTerms = [
		'مطلوب فاتورة بيع صحيحة.',
		'يجب تحميل صورة الفاتورة للتحقق.',
		'دورة واحدة فقط لكل فاتورة.',
		'كوبون واحد لكل فاتورة مؤهلة.',
		'يجب طباعة الكوبون من قبل الكاشير ليكون صحيحاً.',
		'يمكن استخدام الخصومات على الشراء التالي فقط.',
		'سيتم تطبيق الخصم النسبي أو الحد الأقصى للخصم، أيهما أقل.',
		'لا يمكن استبدال الكوبون بنقد.',
		'الكوبون صحيح حتى تاريخ انتهاء الصلاحية المطبوع.',
		'لا يمكن استرجاع أو استبدال الكوبون المطبوع المفقود.',
		'لا يتم قبول الفواتير الاحتيالية أو المكررة أو المستخدمة.',
		'العرض صحيح طالما الحد اليومي قائماً.',
		'تحتفظ الإدارة بالحق في تعديل أو إيقاف الترويج في أي وقت.'
	];

	// Realtime
	let realtimeChannel: any = null;

	// Hidden manual entry (tap wheel 5 times to unlock)
	let manualTapCount = 0;
	let showManualFields = false;
	let showAccessCodePopup = false;
	let accessCodeInput = '';
	let accessCodeError = '';
	let accessCodeLoading = false;
	let manualEntryUserId: string | null = null;
	let manualEntryUsername: string | null = null;
	let ocrDone = false;

	const WHEEL_COLORS = [
		'#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
		'#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F',
		'#BB8FCE', '#85C1E9', '#F0B27A', '#82E0AA'
	];

	onMount(async () => {
		await checkStatus();
		await loadRewards();
		setupRealtime();
	});

	onDestroy(() => {
		if (realtimeChannel) {
			supabase.removeChannel(realtimeChannel);
		}
	});

	function setupRealtime() {
		realtimeChannel = supabase.channel('gift-wheel-customer-realtime')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_settings' }, () => {
				// Re-check if wheel is still active
				if (step !== 'spinning' && step !== 'result') {
					checkStatus();
				}
			})
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_rewards' }, () => {
				// Reload rewards/segments if not mid-spin
				if (step !== 'spinning' && step !== 'result') {
					loadRewards();
				}
			})
			.subscribe();
	}

	// Reactive error message translation - removed to prevent initialization issues
	// Translation happens in template instead

	async function checkStatus() {
		try {
			const { data, error } = await supabase.rpc('gift_wheel_check_status');
			if (error) throw error;
			statusInfo = data;
			if (!data.active) {
				step = 'inactive';
				errorReason = data.reason || 'default';
			} else {
				step = 'capture';
				errorReason = '';
			}
		} catch (err) {
			step = 'inactive';
			errorReason = 'connection_error';
		}
	}

	async function loadRewards() {
		try {
			const { data, error } = await supabase
				.from('gift_wheel_rewards')
				.select('id, label, reward_label_en, reward_label_ar, reward_type, value, max_discount, min_bill, weight')
				.eq('active', true)
				.order('weight', { ascending: false });

			if (error) throw error;
			rewards = data || [];
			buildWheelSegments();
		} catch (err) {
			console.error('Failed to load rewards:', err);
		}
	}

	function buildWheelSegments() {
		wheelSegments = rewards.map((r, i) => {
			let label: string;
			if (r.reward_type === 'no_reward') {
				label = $locale === 'ar' ? 'حظ أوفر' : 'Better Luck';
			} else {
				label = $locale === 'ar'
					? (r.reward_label_ar || `${r.value}%`)
					: (r.reward_label_en || `${r.value}%`);
			}
			return { label, color: WHEEL_COLORS[i % WHEEL_COLORS.length], max_discount: r.max_discount };
		});
	}

	// Rebuild wheel segments when locale changes
	$: if (rewards.length > 0 && $locale) {
		buildWheelSegments();
	}

	function handleFileCapture(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input?.files?.[0];
		if (!file) return;

		billImageFile = file;
		const reader = new FileReader();
		reader.onload = (e) => {
			billImagePreview = e.target?.result as string;
		};
		reader.readAsDataURL(file);

		// Run OCR
		processOCR(file);
	}

	async function processOCR(file: File) {
		ocrProcessing = true;
		try {
			// Compress image first
			const compressedBase64 = await new Promise<string>((resolve, reject) => {
				const reader = new FileReader();
				reader.onload = (e) => {
					const img = new Image();
					img.onload = () => {
						// Scale down to max 1200px width, maintain aspect ratio
						const maxWidth = 1200;
						const scale = Math.min(1, maxWidth / img.width);
						const canvas = document.createElement('canvas');
						canvas.width = img.width * scale;
						canvas.height = img.height * scale;
						const ctx = canvas.getContext('2d');
						if (ctx) ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
						
						// Convert to JPEG with quality 0.8 for faster upload
						canvas.toBlob(
							(blob) => {
								if (blob) {
									const compReader = new FileReader();
									compReader.onload = () => {
										resolve((compReader.result as string).split(',')[1]);
									};
									compReader.readAsDataURL(blob);
								}
							},
							'image/jpeg',
							0.8
						);
					};
					img.onerror = reject;
					img.src = e.target?.result as string;
				};
				reader.readAsDataURL(file);
			});

			const base64 = compressedBase64;

			// Get Google API key from DB
			let apiKey = '';
			try {
				const { data: keyRow } = await supabase
					.from('system_api_keys')
					.select('api_key')
					.eq('service_name', 'google')
					.eq('is_active', true)
					.single();
				if (keyRow?.api_key) apiKey = keyRow.api_key;
			} catch (_) { /* fallback */ }

			if (!apiKey) {
				console.error('No Google API key configured for Vision');
				ocrProcessing = false;
				return;
			}

			// Call Google Vision OCR
			const visionRes = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					requests: [{
						image: { content: base64 },
						features: [{ type: 'TEXT_DETECTION', maxResults: 50 }]
					}]
				})
			});
			const visionData = await visionRes.json();

			if (visionData.error) {
				console.error('Vision API error:', visionData.error);
				ocrProcessing = false;
				return;
			}

			const annotations = visionData.responses?.[0]?.textAnnotations || [];
			if (annotations.length === 0) {
				ocrProcessing = false;
				return;
			}

			const fullText = annotations[0]?.description || '';
			console.log('[GIFT WHEEL OCR] Text length:', fullText.length);

			// Use Gemini to parse bill number and amount
			const geminiRes = await fetch(
				`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
				{
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({
						contents: [{ role: 'user', parts: [{ text: `Extract from this bill:
1. billNumber: Look for "Invoice Number", "Bill Number", or similar
2. totalAmount: The FINAL amount to pay - look for:
   - Lines with "SAR" or "ر.س"
   - Arabic: "إجمالي", "المستحق", "إجمالي المبلغ المستحق"
   - English: "Total", "Total Amount", "Amount Due", "Grand Total"
   - Take the LAST/LARGEST amount value shown

Return ONLY valid JSON (no markdown, no code blocks):
{"billNumber":"289717","totalAmount":7.45}

Bill text:
${fullText.substring(0, 900)}` }] }],
						generationConfig: { temperature: 0, maxOutputTokens: 1000 }
					})
				}
			);
			const geminiData = await geminiRes.json();
			console.log('[GIFT WHEEL OCR] Full Gemini response object:', JSON.stringify(geminiData).substring(0, 500));
			const geminiText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text || '';
			console.log('[GIFT WHEEL OCR] Gemini text length:', geminiText.length);
			console.log('[GIFT WHEEL OCR] Gemini raw response:', geminiText);
			console.log('[GIFT WHEEL OCR] Gemini response (encoded):', JSON.stringify(geminiText));

			// Parse Gemini response - extract JSON from response
			try {
				// Clean up code blocks and whitespace
				let cleanedText = geminiText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
				
				// Handle incomplete JSON responses
				if (cleanedText.includes('{') && !cleanedText.includes('}')) {
					cleanedText = cleanedText + '}'; // Complete incomplete JSON
				}
				
				// Try parsing directly first
				let parsed;
				try {
					parsed = JSON.parse(cleanedText);
				} catch {
					// Try finding JSON object with proper brace matching
					const jsonStart = cleanedText.indexOf('{');
					if (jsonStart !== -1) {
						let braceCount = 0;
						let jsonEnd = -1;
						for (let i = jsonStart; i < cleanedText.length; i++) {
							if (cleanedText[i] === '{') braceCount++;
							if (cleanedText[i] === '}') braceCount--;
							if (braceCount === 0) {
								jsonEnd = i + 1;
								break;
							}
						}
						if (jsonEnd > jsonStart) {
							const jsonStr = cleanedText.substring(jsonStart, jsonEnd);
							try {
								parsed = JSON.parse(jsonStr);
							} catch {
								// Incomplete JSON - try to salvage it
								const billMatch = jsonStr.match(/"billNumber"\s*:\s*"([^"]+)"/);
								const amountMatch = jsonStr.match(/"totalAmount"\s*:\s*([\d.]+)/);
								if (billMatch || amountMatch) {
									parsed = {};
									if (billMatch) parsed.billNumber = billMatch[1];
									if (amountMatch) parsed.totalAmount = Number(amountMatch[1]);
								}
							}
						}
					}
				}
				
				if (parsed) {
					if (parsed.billNumber) billNumber = String(parsed.billNumber);
					if (parsed.totalAmount) billAmount = Number(parsed.totalAmount);
					if (parsed.billDate) billDate = String(parsed.billDate);
				}
			} catch (parseErr) {
				console.error('[GIFT WHEEL OCR] Failed to parse Gemini response:', geminiText, parseErr);
				// Fallback: try regex extraction from OCR text directly
				const numMatch = fullText.match(/(?:invoice|bill|receipt|voucher|فاتورة|رقم الفاتورة|رقم الإيصال)[^\d]*(\d+)/i);
				if (numMatch) billNumber = numMatch[1];
				
				// Look for amount - try multiple patterns with priority
				const amountPatterns = [
					// Pattern 1: SAR currency suffix (highest priority for most bills)
					/([\d,]+\.?\d*)\s*(?:SAR|ر\.س|ريال)(?:\s|$)/i,
					// Pattern 2: Arabic total indicators
					/(?:إجمالي المبلغ المستحق|إجمالي المبلغ|المبلغ المستحق|الإجمالي)[^\d]*([\d,]+\.?\d*)/i,
					// Pattern 3: English total indicators  
					/(?:total amount|amount due|grand total|net total|total)[^\d:]*[:\s]*([\d,]+\.?\d*)/i,
					// Pattern 4: Just look for numbers with SAR on same line
					/(\d+\.?\d*)\s*SAR/i,
					// Pattern 5: Last number that looks like an amount (fallback)
					/([\d]{1,2}\.[\d]{2})/
				];
				
				for (const pattern of amountPatterns) {
					const match = fullText.match(pattern);
					if (match && match[1]) {
						const amount = Number(match[1].replace(/,/g, ''));
						if (amount > 0 && amount < 10000) { // Reasonable bill amount
							billAmount = amount;
							console.log('[GIFT WHEEL OCR] Fallback found amount:', amount, 'from pattern:', pattern);
							break;
						}
					}
				}
			}

			ocrDone = !!(billNumber || billAmount);
			ocrProcessing = false;
		} catch (err) {
			console.error('[GIFT WHEEL OCR] Error:', err);
			ocrProcessing = false;
		}
	}

	function retakeBill() {
		billNumber = '';
		billAmount = null;
		billDate = '';
		billImageFile = null;
		billImagePreview = '';
		ocrDone = false;
		ocrProcessing = false;
		showManualFields = false;
		manualTapCount = 0;
		errorMessage = '';
	}

	async function validateAndPrepare() {
		// Check if all terms are accepted
		if (!billNumber.trim()) {
			errorMessage = $locale === 'ar' ? 'أدخل رقم الفاتورة' : 'Please enter bill number';
			return;
		}
		if (!billAmount || billAmount <= 0) {
			errorMessage = $locale === 'ar' ? 'أدخل مبلغ الفاتورة' : 'Please enter bill amount';
			return;
		}

		errorMessage = '';
		step = 'validating';

		// Quick validation - check if same bill number and amount already used
		try {
			const { data, error } = await supabase
				.from('gift_wheel_spins')
				.select('id')
				.eq('bill_number', billNumber.trim())
				.eq('bill_amount', billAmount)
				.eq('rejected', false)
				.limit(1);

			if (error) throw error;
			if (data && data.length > 0) {
				errorMessage = $locale === 'ar' ? 'هذه الفاتورة بنفس المبلغ مستخدمة بالفعل' : 'This bill with the same amount has already been used';
				step = 'capture';
				return;
			}

			step = 'ready';
		} catch (err) {
			errorMessage = $locale === 'ar' ? 'حدث خطأ في التحقق' : 'Validation error occurred';
			step = 'capture';
		}
	}

	async function startSpin() {
		if (isSpinning) return;
		
		// Validate bill date is today
		const today = new Date().toISOString().split('T')[0];
		if (billDate && billDate !== today) {
			errorMessage = $locale === 'ar' 
				? 'يجب أن تكون الفاتورة من تاريخ اليوم فقط' 
				: 'Bill must be from today only';
			step = 'capture';
			return;
		}
		
		isSpinning = true;
		step = 'spinning';
		errorMessage = '';

		// Call the spin RPC
		try {
			const { data, error } = await supabase.rpc('gift_wheel_spin', {
				p_bill_number: billNumber.trim(),
				p_bill_amount: billAmount,
				p_bill_image_url: null,
				p_bill_date: billDate.trim() || null,
				p_manual_entry: showManualFields,
				p_manual_entry_by: manualEntryUserId,
				p_manual_entry_username: manualEntryUsername
			});

			if (error) throw error;

			if (!data.success) {
				if (data.error_code === 'bill_date_expired') {
					errorMessage = $locale === 'ar' ? 'انتهت فترة الفرصة' : 'Chance expired';
				} else {
					errorMessage = data.error;
				}
				step = 'capture';
				isSpinning = false;
				return;
			}

			spinResult = data;

			// Find the winning segment index
			let winIndex = 0;
			if (data.is_winner) {
				winIndex = rewards.findIndex(r =>
					r.reward_type !== 'no_reward' && r.value === data.reward_value
				);
			} else {
				winIndex = rewards.findIndex(r => r.reward_type === 'no_reward');
			}
			if (winIndex < 0) winIndex = 0;

			// Calculate rotation to land on that segment
			const segmentAngle = 360 / wheelSegments.length;
			const targetAngle = 360 - (winIndex * segmentAngle + segmentAngle / 2);
			const extraSpins = 5 + Math.floor(Math.random() * 3); // 5-7 full rotations
			const finalRotation = extraSpins * 360 + targetAngle;

			wheelRotation = finalRotation;

			// Show result after animation
			setTimeout(() => {
				isSpinning = false;
				step = 'result';
			}, 4500);

		} catch (err) {
			errorMessage = $locale === 'ar' ? 'حدث خطأ في الدوران' : 'Spin error occurred';
			step = 'capture';
			isSpinning = false;
		}
	}

	function resetWheel() {
		step = 'capture';
		billNumber = '';
		billAmount = null;
		billDate = '';
		billImageFile = null;
		billImagePreview = '';
		wheelRotation = 0;
		spinResult = null;
		errorMessage = '';
		ocrDone = false;
		ocrProcessing = false;
		showManualFields = false;
		manualTapCount = 0;
		manualEntryUserId = null;
		manualEntryUsername = null;
		checkStatus();
	}

	function switchLang() {
		const newLocale = $locale === 'en' ? 'ar' : 'en';
		switchLocale(newLocale);
		buildWheelSegments();
	}
</script>

<svelte:head>
	<title>{$locale === 'ar' ? 'عجلة الهدايا' : 'Gift Wheel'}</title>
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
</svelte:head>

<div class="gift-wheel-page" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Language Toggle -->
	<button class="lang-toggle" on:click={switchLang}>
		{$locale === 'ar' ? 'English' : 'العربية'}
	</button>

	<!-- Header -->
	<div class="header">
		<div class="logo">🎡</div>
		<h1>{$locale === 'ar' ? 'عجلة الهدايا' : 'Gift Wheel'}</h1>
		<p class="subtitle">
			{$locale === 'ar' ? 'ادر العجلة واربح جائزتك' : 'Spin the wheel and win your prize'}
		</p>
	</div>

	<!-- Loading -->
	{#if step === 'loading'}
		<div class="loading-state">
			<div class="spinner-large"></div>
			<p>{$locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</p>
		</div>

	<!-- Inactive -->
	{:else if step === 'inactive'}
		<div class="inactive-state">
			<div class="inactive-icon">🔒</div>
			<p class="inactive-message">
				{#if errorReason === 'daily_limit_reached'}
					{$locale === 'ar' ? 'تم الوصول للحد اليومي. يرجى المحاولة غداً' : 'Daily limit reached. Please try again tomorrow'}
				{:else if errorReason === 'not_started'}
					{$locale === 'ar' ? 'عجلة الهدايا لم تبدأ بعد' : 'Gift Wheel has not started yet'}
				{:else if errorReason === 'ended'}
					{$locale === 'ar' ? 'انتهت عجلة الهدايا' : 'Gift Wheel has ended'}
				{:else if errorReason === 'connection_error'}
					{$locale === 'ar' ? 'خطأ في الاتصال' : 'Connection error'}
				{:else}
					{$locale === 'ar' ? 'عجلة الهدايا غير نشطة' : 'Gift Wheel is not active'}
				{/if}
			</p>
		</div>

	{:else}
		<!-- Wheel Display -->
		<div class="wheel-container" on:click={() => { if (!showManualFields && !showAccessCodePopup) { manualTapCount++; if (manualTapCount >= 5) { showAccessCodePopup = true; manualTapCount = 0; } } }}>
			<div class="wheel-pointer">▼</div>
			<div
				class="wheel"
				class:spinning={isSpinning}
				style="transform: rotate({wheelRotation}deg)"
			>
				{#if wheelSegments.length > 0}
					<svg viewBox="0 0 300 300" class="wheel-svg">
						<defs>
							<clipPath id="center-clip">
								<circle cx="150" cy="150" r="19" />
							</clipPath>
						</defs>
						{#each wheelSegments as segment, i}
							{@const angle = 360 / wheelSegments.length}
							{@const startAngle = i * angle - 90}
							{@const endAngle = startAngle + angle}
							{@const startRad = (startAngle * Math.PI) / 180}
							{@const endRad = (endAngle * Math.PI) / 180}
							{@const x1 = 150 + 140 * Math.cos(startRad)}
							{@const y1 = 150 + 140 * Math.sin(startRad)}
							{@const x2 = 150 + 140 * Math.cos(endRad)}
							{@const y2 = 150 + 140 * Math.sin(endRad)}
							{@const largeArc = angle > 180 ? 1 : 0}
							{@const midAngle = ((startAngle + endAngle) / 2) * Math.PI / 180}
							{@const textX = 150 + 90 * Math.cos(midAngle)}
							{@const textY = 150 + 90 * Math.sin(midAngle)}
							{@const textRotation = (startAngle + endAngle) / 2 + 90}
							<path
								d="M150,150 L{x1},{y1} A140,140 0 {largeArc},1 {x2},{y2} Z"
								fill={segment.color}
								stroke="#fff"
								stroke-width="2"
							/>
							<text
								x={textX}
								y={textY}
								text-anchor="middle"
								dominant-baseline="middle"
								transform="rotate({textRotation}, {textX}, {textY})"
								fill="#fff"
								font-size="12"
								font-weight="bold"
								style="text-shadow: 1px 1px 2px rgba(0,0,0,0.5)"
							>
								{segment.label}
							</text>
							{#if segment.max_discount}
								{@const subX = 150 + 70 * Math.cos(midAngle)}
								{@const subY = 150 + 70 * Math.sin(midAngle)}
								<text
									x={subX}
									y={subY - 4}
									text-anchor="middle"
									dominant-baseline="middle"
									transform="rotate({textRotation}, {subX}, {subY})"
									fill="rgba(255,255,255,0.85)"
									font-size="8"
									font-weight="bold"
									style="text-shadow: 1px 1px 2px rgba(0,0,0,0.3)"
								>
									{$locale === 'ar' ? `أقصى ${segment.max_discount}` : `max ${segment.max_discount}`}
								</text>
								<image
									href="https://supabase.urbanaqura.com/storage/v1/object/public/app-icons/saudi-currency.png"
									x={subX - 4}
									y={subY + 2}
									width="8"
									height="8"
									transform="rotate({textRotation}, {subX}, {subY})"
								/>
							{/if}
						{/each}
						<!-- Center circle -->
						<circle cx="150" cy="150" r="22" fill="#ffffff" stroke="#13A538" stroke-width="3" />
						<image href="https://supabase.urbanaqura.com/storage/v1/object/public/app-icons/logo.png" x="131" y="131" width="38" height="38" clip-path="url(#center-clip)" />
					</svg>
				{/if}
			</div>
		</div>

		<!-- Bill Capture Step -->
		{#if step === 'capture' || step === 'validating'}
			<div class="capture-section">
				{#if errorMessage}
					<div class="error-banner">{errorMessage}</div>
				{/if}

				<!-- Camera / Upload -->
				{#if !ocrDone}
				<div class="bill-upload">
					<label class="upload-btn">
						<span>📷 {$locale === 'ar' ? 'صور الفاتورة' : 'Take Photo of Bill'}</span>
						<input
							type="file"
							accept="image/*"
							capture="environment"
							on:change={handleFileCapture}
							style="display: none"
						/>
					</label>
					{#if billImagePreview}
						<div class="bill-preview">
							<img src={billImagePreview} alt="Bill" />
						</div>
					{/if}
				</div>
				{/if}

				{#if ocrProcessing}
					<div class="ocr-loading">
						<div class="spinner-small"></div>
						<span>{$locale === 'ar' ? 'جاري قراءة الفاتورة...' : 'Reading bill...'}</span>
					</div>
				{/if}

				<!-- OCR Results Display -->
				{#if ocrDone && !ocrProcessing}
				<div class="ocr-results">
					<div class="ocr-results-header">
						<span>✅ {$locale === 'ar' ? 'تم قراءة الفاتورة' : 'Bill Read Successfully'}</span>
					</div>
					<div class="ocr-detail">
						<span class="ocr-label">{$locale === 'ar' ? 'رقم الفاتورة' : 'Bill Number'}</span>
						<span class="ocr-value">{billNumber || '—'}</span>
					</div>
					<div class="ocr-detail">
						<span class="ocr-label">{$locale === 'ar' ? 'المبلغ' : 'Amount'}</span>
						<span class="ocr-value">{billAmount ? '' : '—'}{#if billAmount}<span class="currency-amount"><img src="https://supabase.urbanaqura.com/storage/v1/object/public/app-icons/saudi-currency.png" alt="SAR" class="currency-icon" />{billAmount}</span>{/if}</span>
					</div>
					{#if billDate}
					<div class="ocr-detail">
						<span class="ocr-label">{$locale === 'ar' ? 'التاريخ' : 'Date'}</span>
						<span class="ocr-value">{billDate}</span>
					</div>
					{/if}
					<button class="btn-retake" on:click={retakeBill}>
						📷 {$locale === 'ar' ? 'إعادة التصوير' : 'Retake Photo'}
					</button>
				</div>
				{/if}

				<!-- Bill Fields (hidden unless tapped wheel 5 times) -->
				{#if showManualFields}
				<div class="bill-fields">
					<div class="field">
						<label>{$locale === 'ar' ? 'رقم الفاتورة' : 'Bill Number'}</label>
						<input
							type="text"
							bind:value={billNumber}
							placeholder={$locale === 'ar' ? 'أدخل رقم الفاتورة' : 'Enter bill number'}
							disabled={step === 'validating'}
						/>
					</div>
					<div class="field">
						<label>{$locale === 'ar' ? 'مبلغ الفاتورة' : 'Bill Amount'} <img src="https://supabase.urbanaqura.com/storage/v1/object/public/app-icons/saudi-currency.png" alt="SAR" class="currency-icon" /></label>
						<input
							type="number"
							bind:value={billAmount}
							placeholder={$locale === 'ar' ? 'أدخل المبلغ' : 'Enter amount'}
							min="0"
							step="0.01"
							disabled={step === 'validating'}
						/>
					</div>
					<div class="field">
						<label>{$locale === 'ar' ? 'تاريخ الفاتورة' : 'Bill Date'}</label>
						<input
							type="date"
							bind:value={billDate}
							disabled={step === 'validating'}
						/>
					</div>
				</div>
				{/if}

				<button
					class="btn-primary"
					on:click={validateAndPrepare}
					disabled={step === 'validating' || !billNumber || !billAmount}
				>
					{#if step === 'validating'}
						<span class="spinner-small"></span>
						{$locale === 'ar' ? 'جاري التحقق...' : 'Validating...'}
					{:else}
						{$locale === 'ar' ? 'تحقق وادخل' : 'Validate & Enter'}
					{/if}
				</button>

				<!-- Remaining Spins -->
				{#if statusInfo && statusInfo.remaining != null}
					<div class="remaining-spins">
						<span class="remaining-icon">🎯</span>
						<span class="remaining-text">
							{$locale === 'ar'
								? 'المحاولات المتبقية لهذا اليوم: '
								: 'Spins remaining today: '}<span class="remaining-count">{statusInfo.remaining}</span>
						</span>
					</div>
				{/if}

				<!-- Terms and Conditions -->
				<div class="terms-section">
					<h4 class="terms-title">
						{$locale === 'ar' ? '📋 الشروط والأحكام' : '📋 Terms and Conditions'}
					</h4>
					<div class="terms-content">
						<div class="terms-list">
							{#each ($locale === 'ar' ? arabicTerms : englishTerms) as term, i}
								<div class="term-item">
									<span class="term-number">⭐</span>
									<span class="term-text">{term}</span>
								</div>
							{/each}
						</div>
					</div>
				</div>
			</div>

		<!-- Ready to Spin -->
		{:else if step === 'ready'}
			<div class="ready-section">
				<div class="bill-summary">
					<p><strong>{$locale === 'ar' ? 'الفاتورة:' : 'Bill:'}</strong> #{billNumber}</p>
					<p><strong>{$locale === 'ar' ? 'المبلغ:' : 'Amount:'}</strong> <span class="currency-amount"><img src="https://supabase.urbanaqura.com/storage/v1/object/public/app-icons/saudi-currency.png" alt="SAR" class="currency-icon" />{billAmount}</span></p>
					{#if billDate}
						<p><strong>{$locale === 'ar' ? 'التاريخ:' : 'Date:'}</strong> {billDate}</p>
					{/if}
				</div>
				<button class="btn-spin" on:click={startSpin}>
					🎰 {$locale === 'ar' ? 'ابدأ الدوران' : 'Start Spinning'}
				</button>
			</div>

		<!-- Spinning -->
		{:else if step === 'spinning'}
			<div class="spinning-section">
				<p class="spinning-text">
					{$locale === 'ar' ? '🎡 العجلة تدور...' : '🎡 Spinning...'}
				</p>
			</div>

		<!-- Result -->
		{:else if step === 'result'}
			<div class="result-section" class:winner={spinResult?.is_winner}>
				{#if spinResult?.is_winner}
					<!-- Fireworks Animation -->
					<div class="fireworks-container">
						<div class="firework" style="--x: 20%; --delay: 0s;"></div>
						<div class="firework" style="--x: 30%; --delay: 0.1s;"></div>
						<div class="firework" style="--x: 40%; --delay: 0.2s;"></div>
						<div class="firework" style="--x: 50%; --delay: 0.3s;"></div>
						<div class="firework" style="--x: 60%; --delay: 0.4s;"></div>
						<div class="firework" style="--x: 70%; --delay: 0.5s;"></div>
						<div class="firework" style="--x: 80%; --delay: 0.6s;"></div>
						<div class="firework" style="--x: 90%; --delay: 0.7s;"></div>
					</div>
					
					<div class="confetti">🎉</div>
					<h2>{$locale === 'ar' ? 'مبروك' : 'Congratulations'}</h2>
					<div class="reward-display">
						<div class="reward-value">
						{#if $locale === 'ar'}
							{#if spinResult.reward_label_ar}
								{spinResult.reward_label_ar.replace(/خصم (%\d+)/g, '$1 خصم')}
							{:else}
								{spinResult.reward_label?.replace(/(%\d+)/g, '$1 خصم')}
							{/if}
						{:else}
							{spinResult.reward_label_en || spinResult.reward_label}
						{/if}
					</div>
						{#if spinResult.max_discount}
							<p class="discount-note">
								{$locale === 'ar' ? 'أو الحد الأقصى' : 'or maximum'} <span class="currency-amount"><img src="https://supabase.urbanaqura.com/storage/v1/object/public/app-icons/saudi-currency.png" alt="SAR" class="currency-icon" />{spinResult.max_discount}</span> {$locale === 'ar' ? 'على الفاتورة التالية أيهما أقل' : 'on next bill which ever is lowest'}
							</p>
						{/if}
						<p class="expiry">
							{$locale === 'ar' ? 'صالح حتى:' : 'Valid Until:'} {spinResult.expiry_date}
						</p>
					</div>
					<div class="coupon-display">
						<label>{$locale === 'ar' ? 'رمز الكوبون:' : 'Coupon Code:'}</label>
						<div class="coupon-code">{spinResult.coupon_code}</div>
						<p class="coupon-hint">
							{$locale === 'ar' ? 'أرِ هذا الرمز للكاشير للحصول على كوبون مطبوع، وقدّم الكوبون المطبوع للكاشير عند الشراء القادم. بدون الكوبون المطبوع يكون العرض غير صالح' : 'Show this code to the cashier to get a printed coupon, and give the printed coupon to the cashier on your next purchase. Without the printed coupon, the offer will be invalid'}
						</p>
					</div>
				{:else}
					<div class="no-win-icon">😔</div>
					<h2>{$locale === 'ar' ? 'حظ أوفر في المرة القادمة' : 'Better luck next time'}</h2>
					<p>{$locale === 'ar' ? 'جرب مرة أخرى مع فاتورة جديدة' : 'Try again with a new bill'}</p>
				{/if}

				<button class="btn-primary" on:click={resetWheel}>
					{$locale === 'ar' ? 'حاول مرة أخرى' : 'Try Again'}
				</button>
			</div>
		{/if}
	{/if}
</div>

{#if showAccessCodePopup}
	<div class="access-overlay" on:click|self={() => { showAccessCodePopup = false; accessCodeInput = ''; accessCodeError = ''; }}>
		<div class="access-popup">
			<h3>{$locale === 'ar' ? 'رمز الدخول' : 'Access Code'}</h3>
			<p>{$locale === 'ar' ? 'أدخل رمز الموظف لتفعيل الإدخال اليدوي' : 'Enter employee code to enable manual entry'}</p>
			<input
				type="password"
				inputmode="numeric"
				maxlength="6"
				placeholder="******"
				bind:value={accessCodeInput}
				class="access-input"
				on:input={() => { accessCodeError = ''; }}
			/>
			{#if accessCodeError}
				<p class="access-error">{accessCodeError}</p>
			{/if}
			<div class="access-buttons">
				<button class="access-btn confirm" disabled={accessCodeLoading} on:click={async () => {
					if (accessCodeInput.length !== 6) {
						accessCodeError = $locale === 'ar' ? 'يجب أن يكون الرمز 6 أرقام' : 'Code must be 6 digits';
						return;
					}
					accessCodeLoading = true;
					try {
						const { data, error } = await supabase.rpc('verify_quick_access_code', { p_code: accessCodeInput });
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
					} catch (err) {
						accessCodeError = $locale === 'ar' ? 'حدث خطأ' : 'An error occurred';
					}
					accessCodeLoading = false;
				}}>
					{accessCodeLoading ? ($locale === 'ar' ? 'جاري التحقق...' : 'Verifying...') : ($locale === 'ar' ? 'تأكيد' : 'Confirm')}
				</button>
				<button class="access-btn cancel" on:click={() => { showAccessCodePopup = false; accessCodeInput = ''; accessCodeError = ''; }}>
					{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	:global(html) {
		height: 100%;
		overflow-y: auto;
	}

	:global(body) {
		margin: 0;
		padding: 0;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
		background: linear-gradient(160deg, #ffffff 0%, #f0faf2 40%, #fff8f0 100%);
		min-height: auto;
		overflow-y: auto;
	}

	.access-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0,0,0,0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.access-popup {
		background: white;
		border-radius: 16px;
		padding: 24px;
		width: 300px;
		text-align: center;
		box-shadow: 0 10px 40px rgba(0,0,0,0.3);
	}

	.access-popup h3 {
		margin: 0 0 8px;
		color: #1a1a2e;
		font-size: 1.3rem;
	}

	.access-popup p {
		margin: 0 0 16px;
		color: #666;
		font-size: 0.9rem;
	}

	.access-input {
		width: 100%;
		padding: 14px;
		font-size: 1.5rem;
		text-align: center;
		letter-spacing: 8px;
		border: 2px solid #ddd;
		border-radius: 10px;
		outline: none;
		box-sizing: border-box;
		font-weight: bold;
	}

	.access-input:focus {
		border-color: #4CAF50;
	}

	.access-error {
		color: #e74c3c;
		font-size: 0.85rem;
		margin: 8px 0 0;
	}

	.access-buttons {
		display: flex;
		gap: 10px;
		margin-top: 16px;
	}

	.access-btn {
		flex: 1;
		padding: 12px;
		border: none;
		border-radius: 10px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
	}

	.access-btn.confirm {
		background: #4CAF50;
		color: white;
	}

	.access-btn.cancel {
		background: #e0e0e0;
		color: #333;
	}

	.gift-wheel-page {
		max-width: 480px;
		margin: 0 auto;
		padding: 16px;
		min-height: auto;
		color: #1a1a1a;
		position: relative;
		height: 100%;
		overflow-y: auto;
		overflow-x: hidden;
		-webkit-overflow-scrolling: touch;
	}

	.lang-toggle {
		position: absolute;
		top: 12px;
		right: 12px;
		background: #ffffff;
		border: 1px solid #e0e0e0;
		color: #333;
		padding: 6px 14px;
		border-radius: 20px;
		cursor: pointer;
		font-size: 13px;
		z-index: 10;
		box-shadow: 0 1px 4px rgba(0,0,0,0.08);
	}

	[dir='rtl'] .lang-toggle {
		right: auto;
		left: 12px;
	}

	.header {
		text-align: center;
		padding: 24px 0 8px;
	}

	.logo {
		font-size: 48px;
		margin-bottom: 8px;
	}

	.header h1 {
		margin: 0;
		font-size: 28px;
		background: linear-gradient(135deg, #13A538, #0d8a2d);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}

	.subtitle {
		margin: 4px 0 0;
		color: #666;
		font-size: 14px;
	}

	/* Loading */
	.loading-state, .inactive-state {
		text-align: center;
		padding: 60px 20px;
	}

	.inactive-icon {
		font-size: 64px;
		margin-bottom: 16px;
	}

	.inactive-message {
		font-size: 18px;
		color: #666;
	}

	/* Wheel */
	.wheel-container {
		position: relative;
		width: 280px;
		height: 280px;
		margin: 16px auto;
	}

	.wheel-pointer {
		position: absolute;
		top: -12px;
		left: 50%;
		transform: translateX(-50%);
		font-size: 28px;
		color: #f08300;
		z-index: 10;
		filter: drop-shadow(0 2px 4px rgba(240, 131, 0, 0.5));
	}

	.wheel {
		width: 100%;
		height: 100%;
		border-radius: 50%;
		transition: transform 4s cubic-bezier(0.17, 0.67, 0.12, 0.99);
		box-shadow: 0 0 0 8px #13A538, 0 0 30px rgba(19, 165, 56, 0.25), 0 0 60px rgba(240, 131, 0, 0.1);
		animation: heartbeat-border 1.5s ease-in-out infinite;
	}

	@keyframes heartbeat-border {
		0%, 100% { box-shadow: 0 0 0 8px #13A538, 0 0 30px rgba(19, 165, 56, 0.25); }
		25% { box-shadow: 0 0 0 12px #13A538, 0 0 40px rgba(19, 165, 56, 0.4); }
		50% { box-shadow: 0 0 0 8px #13A538, 0 0 30px rgba(19, 165, 56, 0.25); }
		75% { box-shadow: 0 0 0 11px #13A538, 0 0 35px rgba(19, 165, 56, 0.35); }
	}

	.wheel.spinning {
		/* Animation handled by inline style transform */
	}

	.wheel-svg {
		width: 100%;
		height: 100%;
	}

	/* Bill Capture */
	.capture-section {
		padding: 16px 0;
	}

	.error-banner {
		background: #fff0f0;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 10px 16px;
		border-radius: 8px;
		margin-bottom: 16px;
		text-align: center;
		font-size: 14px;
	}

	/* OCR Results */
	.ocr-results {
		background: #ffffff;
		border: 1px solid #d1fae5;
		border-radius: 12px;
		padding: 16px;
		margin-bottom: 16px;
		box-shadow: 0 1px 4px rgba(0,0,0,0.06);
	}

	.ocr-results-header {
		font-size: 14px;
		font-weight: 700;
		color: #13A538;
		margin-bottom: 12px;
		text-align: center;
	}

	.ocr-detail {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 0;
		border-bottom: 1px solid #f0f0f0;
	}

	.ocr-detail:last-of-type {
		border-bottom: none;
	}

	.ocr-label {
		font-size: 13px;
		color: #666;
		font-weight: 500;
	}

	.ocr-value {
		font-size: 14px;
		font-weight: 700;
		color: #1a1a1a;
	}

	.btn-retake {
		width: 100%;
		margin-top: 12px;
		padding: 10px;
		background: #fff;
		border: 1px solid #ddd;
		border-radius: 10px;
		color: #f08300;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn-retake:hover {
		background: rgba(240, 131, 0, 0.06);
		border-color: #f08300;
	}

	.bill-upload {
		margin-bottom: 16px;
	}

	.upload-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		width: 100%;
		padding: 14px;
		background: rgba(240, 131, 0, 0.08);
		border: 2px dashed rgba(240, 131, 0, 0.4);
		border-radius: 12px;
		color: #f08300;
		font-size: 16px;
		cursor: pointer;
		transition: all 0.2s;
		animation: heartbeat-upload 1.5s ease-in-out infinite;
	}

	@keyframes heartbeat-upload {
		0%, 100% { transform: scale(1); border-color: rgba(240, 131, 0, 0.4); }
		25% { transform: scale(1.03); border-color: rgba(240, 131, 0, 0.8); }
		50% { transform: scale(1); border-color: rgba(240, 131, 0, 0.4); }
		75% { transform: scale(1.02); border-color: rgba(240, 131, 0, 0.6); }
	}

	.upload-btn:hover {
		background: rgba(240, 131, 0, 0.15);
	}

	.bill-preview {
		margin-top: 12px;
		border-radius: 8px;
		overflow: hidden;
		max-height: 150px;
	}

	.bill-preview img {
		width: 100%;
		height: auto;
		max-height: 150px;
		object-fit: cover;
		border-radius: 8px;
	}

	.ocr-loading {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 12px;
		color: #666;
		font-size: 14px;
	}

	.bill-fields {
		display: flex;
		flex-direction: column;
		gap: 12px;
		margin-bottom: 16px;
	}

	.field label {
		display: block;
		font-size: 13px;
		color: #555;
		margin-bottom: 4px;
	}

	.field input {
		width: 100%;
		padding: 12px 14px;
		background: #ffffff;
		border: 1px solid #ddd;
		border-radius: 8px;
		color: #1a1a1a;
		font-size: 16px;
		outline: none;
		box-sizing: border-box;
	}

	.field input:focus {
		border-color: #13A538;
		box-shadow: 0 0 0 2px rgba(19, 165, 56, 0.2);
	}

	.field input::placeholder {
		color: #aaa;
	}

	.field input:disabled {
		opacity: 0.5;
		background: #f5f5f5;
	}

	/* Buttons */
	.btn-primary {
		width: 100%;
		padding: 14px;
		background: linear-gradient(135deg, #f08300, #d97200);
		color: #ffffff;
		border: none;
		border-radius: 12px;
		font-size: 16px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
	}

	.btn-primary:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 4px 12px rgba(240, 131, 0, 0.4);
	}

	.btn-primary:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-spin {
		width: 100%;
		padding: 18px;
		background: linear-gradient(135deg, #13A538, #0d8a2d);
		color: #fff;
		border: none;
		border-radius: 16px;
		font-size: 20px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		animation: pulse-glow 2s infinite;
	}

	.btn-spin:hover {
		transform: scale(1.02);
	}

	@keyframes pulse-glow {
		0%, 100% { box-shadow: 0 0 20px rgba(19, 165, 56, 0.3); }
		50% { box-shadow: 0 0 40px rgba(19, 165, 56, 0.6); }
	}

	/* Ready */
	.ready-section {
		text-align: center;
		padding: 16px 0;
	}

	.bill-summary {
		background: #ffffff;
		border: 1px solid #e8e8e8;
		border-radius: 12px;
		padding: 16px;
		margin-bottom: 20px;
		font-size: 15px;
		box-shadow: 0 1px 4px rgba(0,0,0,0.06);
	}

	.bill-summary p {
		margin: 4px 0;
	}

	/* Spinning */
	.spinning-section {
		text-align: center;
		padding: 20px;
	}

	.spinning-text {
		font-size: 20px;
		color: #f08300;
		animation: pulse 1s ease-in-out infinite;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	/* Result */
	.result-section {
		text-align: center;
		padding: 20px 0;
	}

	.result-section.winner {
		animation: celebrate 0.5s ease-out;
	}

	@keyframes celebrate {
		0% { transform: scale(0.8); opacity: 0; }
		100% { transform: scale(1); opacity: 1; }
	}

	.confetti {
		font-size: 64px;
		animation: bounce 1s ease infinite;
	}

	@keyframes bounce {
		0%, 100% { transform: translateY(0); }
		50% { transform: translateY(-10px); }
	}

	.result-section h2 {
		margin: 8px 0;
		font-size: 26px;
	}

	.result-section.winner h2 {
		color: #13A538;
	}

	.no-win-icon {
		font-size: 64px;
	}

	.reward-display {
		background: rgba(19, 165, 56, 0.08);
		border: 1px solid rgba(19, 165, 56, 0.25);
		border-radius: 16px;
		padding: 20px;
		margin: 16px 0;
	}

	.reward-value {
		font-size: 32px;
		font-weight: 800;
		color: #13A538;
	}

	.max-discount, .discount-note, .expiry {
		margin: 6px 0 0;
		color: #666;
		font-size: 14px;
	}

	.discount-note {
		font-size: 14px;
		color: #555;
		font-weight: 500;
	}

	.coupon-display {
		background: #ffffff;
		border: 1px solid #e8e8e8;
		border-radius: 12px;
		padding: 16px;
		margin: 16px 0;
		box-shadow: 0 1px 4px rgba(0,0,0,0.06);
	}

	.coupon-display label {
		font-size: 13px;
		color: #666;
	}

	.coupon-code {
		font-size: 28px;
		font-weight: 800;
		color: #13A538;
		letter-spacing: 3px;
		margin: 8px 0;
		padding: 12px;
		background: rgba(19, 165, 56, 0.06);
		border: 2px dashed rgba(19, 165, 56, 0.3);
		border-radius: 8px;
		user-select: all;
	}

	.coupon-hint {
		font-size: 13px;
		color: #666;
		margin: 8px 0 0;
	}

	/* Fireworks Animation */
	.fireworks-container {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		pointer-events: none;
		z-index: 9999;
	}

	.firework {
		position: absolute;
		width: 8px;
		height: 8px;
		background: radial-gradient(circle, #f08300 0%, #ff6b9d 40%, #ffd93d 70%, #00d4ff 100%);
		border-radius: 50%;
		top: -20px;
		left: var(--x);
		animation: fireworkBurst 1.5s ease-out forwards;
		animation-delay: var(--delay);
		box-shadow: 0 0 6px rgba(240, 131, 0, 0.6);
	}

	@keyframes fireworkBurst {
		0% {
			transform: translate(0, 0) scale(1);
			opacity: 1;
		}
		20% {
			opacity: 1;
		}
		100% {
			transform: translate(var(--tx, 0px), var(--ty, 300px)) scale(0);
			opacity: 0;
		}
	}

	.firework:nth-child(1) { --tx: -80px; --ty: 250px; }
	.firework:nth-child(2) { --tx: -60px; --ty: 280px; }
	.firework:nth-child(3) { --tx: -30px; --ty: 320px; }
	.firework:nth-child(4) { --tx: 0px; --ty: 300px; }
	.firework:nth-child(5) { --tx: 30px; --ty: 320px; }
	.firework:nth-child(6) { --tx: 60px; --ty: 280px; }
	.firework:nth-child(7) { --tx: 80px; --ty: 250px; }
	.firework:nth-child(8) { --tx: 100px; --ty: 300px; }

	/* Spinners */
	.spinner-large, .spinner-small {
		border: 3px solid rgba(0, 0, 0, 0.08);
		border-top-color: #f08300;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	.spinner-large {
		width: 40px;
		height: 40px;
		margin: 0 auto 16px;
	}

	.spinner-small {
		width: 18px;
		height: 18px;
		display: inline-block;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	/* Remaining Spins */
	.remaining-spins {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		margin-top: 12px;
		padding: 10px 16px;
		background: linear-gradient(135deg, rgba(59, 130, 246, 0.08), rgba(99, 102, 241, 0.08));
		border: 1px solid rgba(59, 130, 246, 0.2);
		border-radius: 12px;
	}

	.remaining-icon {
		font-size: 1.2em;
	}

	.remaining-text {
		font-size: 0.85rem;
		font-weight: 600;
		color: #3b82f6;
	}

	.remaining-count {
		color: #dc2626;
		font-weight: 800;
		font-size: 1rem;
	}

	/* Currency Icon */
	.currency-icon {
		display: inline-block;
		width: 0.6em;
		height: 0.6em;
		vertical-align: middle;
		margin: 0 2px;
	}

	.currency-amount {
		direction: ltr;
		unicode-bidi: embed;
		display: inline-block;
	}

	/* Terms and Conditions */
	.terms-section {
		background: rgba(240, 131, 0, 0.06);
		border: 1px solid rgba(240, 131, 0, 0.2);
		border-radius: 12px;
		padding: 16px;
		margin-top: 20px;
	}

	.terms-title {
		margin: 0 0 12px;
		font-size: 14px;
		font-weight: 600;
		color: #333;
	}

	.terms-content {
		font-size: 13px;
		line-height: 1.6;
		color: #555;
	}

	.terms-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.term-item {
		display: flex;
		align-items: flex-start;
		gap: 12px;
		padding: 10px;
		background: rgba(240, 131, 0, 0.08);
		border-radius: 8px;
		border-left: 3px solid #f08300;
	}

	.term-number {
		font-weight: 700;
		color: #f08300;
		font-size: 14px;
		flex-shrink: 0;
		min-width: 35px;
	}

	.term-text {
		flex: 1;
		line-height: 1.5;
		color: #444;
	}

	/* Responsive */
	@media (min-width: 768px) {
		.gift-wheel-page {
			max-width: 520px;
			padding: 24px;
		}

		.wheel-container {
			width: 340px;
			height: 340px;
		}

		.header h1 {
			font-size: 36px;
		}
	}
</style>
