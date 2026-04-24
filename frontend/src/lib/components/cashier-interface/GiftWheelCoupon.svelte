<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { onMount, onDestroy } from 'svelte';
	import { iconUrlMap } from '$lib/stores/iconStore';

	export let branch: any;

	let supabase: any = null;

	// Redeem state
	let redeemCode = '';
	let redeemStep: 'input' | 'verifying' | 'verification_popup' | 'details' | 'redeeming' = 'input';
	let redeemLoading = false;
	let redeemError = '';
	let redeemSuccess = false;
	let redeemCouponData: any = null;
	let redeemBillNumber = '';
	let redeemBillAmount = '';
	let redeemDiscountAmount = '';
	
	// Verification state
	let verificationStatus = {
		couponFound: false,
		alreadyRedeemed: false,
		isExpired: false,
		isCancelled: false,
		isValid: false,
		errorMessage: ''
	};

	$: maxAllowedDiscount = redeemCouponData ? (() => {
		if (redeemCouponData.reward_type === 'percentage') {
			if (!redeemBillAmount || parseFloat(redeemBillAmount) <= 0) return null;
			let calc = parseFloat(redeemBillAmount) * Number(redeemCouponData.reward_value) / 100;
			if (redeemCouponData.max_discount && Number(redeemCouponData.max_discount) < calc) {
				calc = Number(redeemCouponData.max_discount);
			}
			return Math.round(calc * 100) / 100;
		} else {
			let max = Number(redeemCouponData.reward_value);
			if (redeemCouponData.max_discount && Number(redeemCouponData.max_discount) < max) {
				max = Number(redeemCouponData.max_discount);
			}
			return max;
		}
	})() : null;
	$: discountExceeded = maxAllowedDiscount !== null && redeemDiscountAmount && parseFloat(redeemDiscountAmount) > maxAllowedDiscount;

	let realtimeChannel: any = null;
	let redeemInput: HTMLInputElement;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		setupRealtime();
		setTimeout(() => redeemInput?.focus(), 100);
	});

	onDestroy(() => {
		if (realtimeChannel && supabase) {
			supabase.removeChannel(realtimeChannel);
		}
	});

	function setupRealtime() {
		if (!supabase) return;
		realtimeChannel = supabase.channel('gift-wheel-coupon-cashier-realtime')
			.on('postgres_changes', { event: '*', schema: 'public', table: 'gift_wheel_coupons' }, (payload: any) => {
				if (redeemCouponData && payload.new && payload.new.code === redeemCouponData.code) {
					// Re-validate coupon if data changed
					if (redeemStep === 'verification_popup') {
						checkCouponValidity();
					}
				}
			})
			.subscribe();
	}





	function reset() {
		redeemCode = '';
		redeemStep = 'input';
		redeemError = '';
		redeemSuccess = false;
		redeemCouponData = null;
		redeemBillNumber = '';
		redeemBillAmount = '';
		redeemDiscountAmount = '';
		verificationStatus = {
			couponFound: false,
			alreadyRedeemed: false,
			isExpired: false,
			isCancelled: false,
			isValid: false,
			errorMessage: ''
		};
		setTimeout(() => redeemInput?.focus(), 50);
	}

	async function checkCouponValidity() {
		if (!redeemCode.trim() || !supabase) return;

		redeemLoading = true;
		redeemError = '';
		redeemStep = 'verifying';

		try {
			const { data, error: rpcError } = await supabase.rpc('gift_wheel_validate_coupon', {
				p_code: redeemCode.trim()
			});

			if (rpcError) throw rpcError;

			// Build verification status
			verificationStatus = {
				couponFound: data.valid || data.status === 'redeemed',
				alreadyRedeemed: data.status === 'redeemed',
				isExpired: data.status === 'expired' || (data.error && data.error.includes('expired')),
				isCancelled: data.status === 'cancelled',
				isValid: data.valid,
				errorMessage: data.error || ''
			};

			if (data.valid || data.status === 'redeemed') {
				redeemCouponData = data;
				redeemStep = 'verification_popup';
			} else {
				redeemError = translateError(data.error || 'Invalid coupon');
				redeemStep = 'input';
			}
		} catch (err: any) {
			redeemError = translateError(err.message || 'Validation failed');
			verificationStatus.errorMessage = err.message || 'Validation failed';
			redeemStep = 'input';
		} finally {
			redeemLoading = false;
		}
	}

	function proceedWithRedemption() {
		if (redeemCouponData && redeemCouponData.valid) {
			redeemStep = 'details';
		}
	}

	function cancelVerification() {
		reset();
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			if (redeemStep === 'input') checkCouponValidity();
		}
	}

	const errorTranslations: Record<string, string> = {
		'Coupon not found': 'الكوبون غير موجود',
		'Coupon already redeemed': 'الكوبون مسترد بالفعل',
		'Coupon has expired': 'الكوبون منتهي الصلاحية',
		'Invalid coupon': 'كوبون غير صالح',
		'Validation failed': 'فشل التحقق',
		'Redemption failed': 'فشل الاسترداد',
	};

	function translateError(msg: string): string {
		if ($locale !== 'ar') return msg;
		for (const [en, ar] of Object.entries(errorTranslations)) {
			if (msg.toLowerCase().includes(en.toLowerCase())) return ar;
		}
		if (msg.includes('status:')) {
			const status = msg.match(/status:\s*(\w+)/)?.[1] || '';
			return `لا يمكن استرداد الكوبون (الحالة: ${status})`;
		}
		return msg;
	}

	async function redeemCoupon() {
		if (!redeemCouponData || !supabase || !redeemBillNumber.trim() || !redeemDiscountAmount) return;

		redeemStep = 'redeeming';
		redeemError = '';

		try {
			const { data, error: rpcError } = await supabase.rpc('gift_wheel_redeem_coupon', {
				p_code: redeemCouponData.code,
				p_action: 'redeem',
				p_branch_id: branch?.id ? String(branch.id) : null,
				p_redeemed_bill_number: redeemBillNumber.trim(),
				p_redeemed_amount: parseFloat(redeemDiscountAmount)
			});

			if (rpcError) throw rpcError;

			if (!data.success) {
				redeemError = translateError(data.error || 'Redemption failed');
				redeemStep = 'details';
			} else {
				redeemSuccess = true;
				redeemStep = 'details';
			}
		} catch (err: any) {
			redeemError = translateError(err.message || 'Redemption failed');
			redeemStep = 'details';
		}
	}

	function printRedeemReceipt() {
		if (!redeemCouponData) return;

		const printWindow = window.open('', '_blank', 'width=400,height=600');
		if (printWindow) {
			const logoUrl = $iconUrlMap['logo'] || '/icons/logo.png';
			const branchNameEn = branch?.name_en || branch?.name || '';
			const branchNameAr = branch?.name_ar || '';

			const discountText = redeemCouponData.reward_type === 'percentage'
				? `${redeemCouponData.reward_value}%`
				: `${redeemCouponData.reward_value} SAR`;

			const maxDiscountHtml = redeemCouponData.max_discount
				? `<div class="bi"><span>Max: ${redeemCouponData.max_discount} SAR</span><span>الحد الأقصى: ${redeemCouponData.max_discount} ر.س</span></div>`
				: '';

			const now = new Date().toLocaleString('en-GB', { dateStyle: 'short', timeStyle: 'short' });

			const origBillHtml = redeemCouponData.bill_number
				? `<div class="bi"><span>Original Bill #: ${redeemCouponData.bill_number}</span><span>رقم الفاتورة الأصلية: ${redeemCouponData.bill_number}</span></div>`
				: '';
			const origAmountHtml = redeemCouponData.bill_amount
				? `<div class="bi"><span>Original Amount: ${redeemCouponData.bill_amount} SAR</span><span>المبلغ الأصلي: ${redeemCouponData.bill_amount} ر.س</span></div>`
				: '';
			const origDateHtml = redeemCouponData.bill_date
				? `<div class="bi"><span>Bill Date: ${redeemCouponData.bill_date}</span><span>تاريخ الفاتورة: ${redeemCouponData.bill_date}</span></div>`
				: '';

			printWindow.document.write(`
<!DOCTYPE html>
<html>
<head>
	<meta charset="UTF-8">
	<title>Redemption Receipt</title>
	<style>
		@page { margin: 0; size: 80mm auto; }
		* { margin: 0; padding: 0; box-sizing: border-box; }
		body {
			font-family: 'Tahoma', 'Arial', sans-serif;
			width: 72mm;
			margin: 0 auto;
			padding: 4mm 2mm;
			text-align: center;
			font-size: 11px;
			color: #000;
			font-weight: bold;
		}
		.hdr { font-size: 12px; font-weight: bold; margin: 1mm 0; }
		.hdr-ar { font-size: 11px; font-weight: bold; direction: rtl; margin-bottom: 1mm; }
		.sep { border-top: 1px dashed #000; margin: 2mm 0; }
		.big { font-size: 22px; font-weight: bold; margin: 2mm 0; padding: 2mm; border: 2px solid #000; }
		.big-label { font-size: 10px; font-weight: bold; margin-bottom: 1mm; }
		.bi { display: flex; justify-content: space-between; margin: 1mm 0; font-size: 10px; font-weight: bold; }
		.bi span:last-child { direction: rtl; font-family: 'Tahoma', 'Arial', sans-serif; }
		.code-box { font-size: 16px; font-weight: bold; letter-spacing: 2px; margin: 1mm 0; font-family: 'Courier New', monospace; }
		.badge { font-size: 13px; font-weight: bold; padding: 2mm 4mm; border: 2px solid #000; display: inline-block; margin: 2mm 0; letter-spacing: 2px; }
		.logo { height: 14mm; margin: 0 auto 1mm; display: block; }
		.branch { font-size: 11px; font-weight: bold; margin: 1mm 0; }
		.branch-ar { font-size: 10px; font-weight: bold; direction: rtl; margin-bottom: 1mm; }
	</style>
</head>
<body>
	<img src="${logoUrl}" alt="Logo" class="logo" />
	<div class="branch">${branchNameEn}</div>
	<div class="branch-ar">${branchNameAr}</div>
	<div class="hdr">🎟️ REDEMPTION RECEIPT</div>
	<div class="hdr-ar">إيصال الاسترداد</div>
	<div class="sep"></div>
	<div class="big-label">Discount / الخصم</div>
	<div class="big">${discountText}</div>
	${maxDiscountHtml}
	<div class="sep"></div>
	<div class="bi"><span>Coupon Code / رقم الكوبون</span></div>
	<div class="code-box">${redeemCouponData.code}</div>
	<div class="bi"><span>Reward: ${redeemCouponData.reward_label_en || redeemCouponData.reward_label || ''}</span><span>الجائزة: ${redeemCouponData.reward_label_ar || redeemCouponData.reward_label || ''}</span></div>
	${origBillHtml}
	${origAmountHtml}
	${origDateHtml}
	<div class="sep"></div>
	<div class="bi"><span>Redeemed Bill #: ${redeemBillNumber}</span><span>فاتورة الاسترداد: ${redeemBillNumber}</span></div>
	${redeemBillAmount ? `<div class="bi"><span>Bill Amount: ${redeemBillAmount} SAR</span><span>مبلغ الفاتورة: ${redeemBillAmount} ر.س</span></div>` : ''}
	<div class="bi"><span>Discount Given: ${redeemDiscountAmount} SAR</span><span>الخصم الممنوح: ${redeemDiscountAmount} ر.س</span></div>
	${discountExceeded ? `<div style="margin:2mm 0;padding:2mm;border:2px solid #000;font-size:11px;"><b>⚠ DISCOUNT EXCEEDS MAXIMUM ALLOWED (${maxAllowedDiscount} SAR)</b><br/><b style="direction:rtl;display:block;margin-top:1mm;">⚠ الخصم يتجاوز الحد الأقصى المسموح (${maxAllowedDiscount} ر.س)</b></div>` : ''}
	<div class="bi"><span>Date: ${now}</span><span>التاريخ: ${now}</span></div>
	<div class="sep"></div>
	<div class="badge">✓ REDEEMED / تم الاسترداد</div>
	<script>window.onload = function() { window.print(); }<` + `/script>
</body>
</html>`);
			printWindow.document.close();
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-center shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-xl">🎟️</span>
			<h2 class="text-sm font-black text-slate-800 uppercase tracking-wide">{$t('giftWheel.redeemGift')}</h2>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background blurs -->
		<div class="absolute top-0 right-0 w-[300px] h-[300px] bg-emerald-100/20 rounded-full blur-[100px] -mr-32 -mt-32 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[300px] h-[300px] bg-orange-100/20 rounded-full blur-[100px] -ml-32 -mb-32 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative max-w-lg mx-auto">
			<!-- REDEEM GIFT -->
			{#if redeemStep === 'input' || redeemStep === 'verifying'}
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.08)] p-6">
						<div class="flex items-center gap-3 mb-5">
							<div class="w-10 h-10 rounded-xl bg-orange-100 flex items-center justify-center text-lg">🎟️</div>
							<div>
								<h2 class="text-sm font-black text-slate-800 uppercase tracking-wide">{$locale === 'ar' ? 'التحقق من الكوبون' : 'Check Coupon Validity'}</h2>
								<p class="text-xs text-slate-400 mt-0.5">{$locale === 'ar' ? 'امسح الكود أو أدخل رقم الكوبون' : 'Scan or enter the coupon code'}</p>
							</div>
						</div>

						{#if redeemError}
							<div class="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 text-sm text-red-700 font-medium">{redeemError}</div>
						{/if}

						<div class="mb-4">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="redeem-input">{$t('giftWheel.couponCode')}</label>
							<input
								id="redeem-input"
								type="password"
								bind:this={redeemInput}
								bind:value={redeemCode}
								on:keydown={handleKeydown}
								placeholder={$t('giftWheel.enterCouponCode')}
								disabled={redeemLoading}
								class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-base font-mono tracking-widest focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all disabled:opacity-50"
								style="color: #000 !important; background-color: #fff !important;"
							/>
						</div>

						<div class="flex gap-3">
							<button
								class="flex-1 py-3 bg-orange-600 text-white rounded-xl text-sm font-bold uppercase tracking-wide flex items-center justify-center gap-2 transition-all duration-200 hover:bg-orange-700 hover:shadow-lg hover:shadow-orange-200 disabled:opacity-50 disabled:cursor-not-allowed"
								on:click={checkCouponValidity}
								disabled={redeemLoading || !redeemCode.trim()}
							>
								{#if redeemLoading}
									<div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
									{$locale === 'ar' ? 'جاري التحقق...' : 'Checking...'}
								{:else}
									✓ {$locale === 'ar' ? 'تحقق من الصلاحية' : 'Check Validity'}
								{/if}
							</button>
						</div>
					</div>

			{:else if redeemStep === 'verification_popup'}
				<!-- VERIFICATION POPUP -->
				<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.08)] overflow-hidden">
					<!-- Header -->
					<div class="bg-gradient-to-br from-blue-50 to-blue-100/50 border-b border-blue-200/50 p-6 text-center">
						<div class="inline-block">
							<span class="text-4xl">🔍</span>
						</div>
						<h3 class="text-sm font-black text-blue-900 mt-3 uppercase tracking-wide">{$locale === 'ar' ? 'التحقق من صحة الكوبون' : 'Coupon Validity Check'}</h3>
					</div>

					<!-- Verification Details -->
					<div class="p-6 space-y-4">
						<!-- Coupon Code -->
						<div class="flex items-center justify-between p-3 bg-slate-50 rounded-xl">
							<div>
								<p class="text-xs font-bold text-slate-500 uppercase tracking-wide mb-1">{$locale === 'ar' ? 'رقم الكوبون' : 'Coupon Code'}</p>
								<p class="text-sm font-mono font-bold text-slate-800">{redeemCouponData?.code}</p>
							</div>
						</div>

						<!-- Verification Steps -->
						<div class="space-y-3 mt-5">
							<!-- Step 1: Coupon Found -->
							<div class="flex items-start gap-3 p-3 bg-emerald-50 border border-emerald-200 rounded-xl">
								<div class="text-2xl mt-0.5">✓</div>
								<div class="flex-1">
									<p class="text-sm font-bold text-emerald-800">{$locale === 'ar' ? 'تم العثور على الكوبون' : 'Coupon Found'}</p>
									<p class="text-xs text-emerald-600/70">{$locale === 'ar' ? 'تم إصدار هذا الكوبون بنجاح' : 'This coupon was successfully issued'}</p>
								</div>
							</div>

							<!-- Step 2: Not Redeemed -->
							{#if verificationStatus.alreadyRedeemed}
							<div class="flex items-start gap-3 p-3 bg-amber-50 border border-amber-200 rounded-xl">
								<div class="text-2xl mt-0.5">ℹ️</div>
								<div class="flex-1">
									<p class="text-sm font-bold text-amber-800">{$t('giftWheel.alreadyRedeemed')}</p>
									<p class="text-xs text-amber-600/70">{$t('giftWheel.alreadyRedeemedDesc')}</p>
								</div>
							</div>

							<!-- Redemption Details - Always show when redeemed -->
							<div class="mt-4 p-4 bg-slate-50 border border-slate-200 rounded-xl space-y-3">
								<div class="text-xs font-bold text-slate-600 uppercase tracking-wide">{$t('giftWheel.previousRedemptionDetails')}</div>
								{#if redeemCouponData?.redeemed_bill_number}
									<div class="flex justify-between items-center py-1.5 border-b border-slate-100">
										<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.redeemedBillNumber')}</span>
										<span class="text-sm font-bold font-mono text-slate-700">#{redeemCouponData.redeemed_bill_number}</span>
									</div>
								{/if}
								{#if redeemCouponData?.redeemed_amount}
									<div class="flex justify-between items-center py-1.5 border-b border-slate-100">
										<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.discountGiven')}</span>
										<span class="text-sm font-bold text-slate-700">{redeemCouponData.redeemed_amount} SAR</span>
									</div>
								{/if}
								{#if redeemCouponData?.redeemed_at}
									<div class="flex justify-between items-center py-1.5">
										<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.redeemedOn')}</span>
										<span class="text-sm font-semibold text-slate-700">{new Date(redeemCouponData.redeemed_at).toLocaleString()}</span>
									</div>
								{/if}
								{#if !redeemCouponData?.redeemed_bill_number && !redeemCouponData?.redeemed_amount && !redeemCouponData?.redeemed_at}
									<div class="text-xs text-slate-500 italic">{$locale === 'ar' ? 'لا توجد تفاصيل متاحة' : 'No details available'}</div>
								{/if}
							</div>
						{:else}
							<div class="flex items-start gap-3 p-3 bg-emerald-50 border border-emerald-200 rounded-xl">
								<div class="text-2xl mt-0.5">✓</div>
								<div class="flex-1">
									<p class="text-sm font-bold text-emerald-800">{$t('giftWheel.notYetRedeemed')}</p>
									<p class="text-xs text-emerald-600/70">{$t('giftWheel.notYetRedeemedDesc')}</p>
								</div>
							</div>
						{/if}
							{#if verificationStatus.isExpired}
								<div class="flex items-start gap-3 p-3 bg-red-50 border border-red-200 rounded-xl">
									<div class="text-2xl mt-0.5">✗</div>
									<div class="flex-1">
										<p class="text-sm font-bold text-red-800">{$locale === 'ar' ? 'الكوبون منتهي الصلاحية' : 'Coupon Expired'}</p>
										<p class="text-xs text-red-600/70">{$locale === 'ar' ? 'انتهت صلاحية هذا الكوبون' : 'This coupon has expired'}</p>
									</div>
								</div>
							{:else}
								<div class="flex items-start gap-3 p-3 bg-emerald-50 border border-emerald-200 rounded-xl">
									<div class="text-2xl mt-0.5">✓</div>
									<div class="flex-1">
										<p class="text-sm font-bold text-emerald-800">{$locale === 'ar' ? 'سارية المفعول' : 'Valid'}</p>
										<p class="text-xs text-emerald-600/70">{$locale === 'ar' ? 'صلاحية الكوبون صحيحة' : 'Coupon is still valid'}</p>
										{#if redeemCouponData?.expiry_date}
											<p class="text-xs text-emerald-600 mt-1">{$locale === 'ar' ? 'تاريخ الانتهاء' : 'Expires'}: {redeemCouponData.expiry_date}</p>
										{/if}
									</div>
								</div>
							{/if}
						</div>

						<!-- Reward Info -->
						{#if redeemCouponData}
							<div class="mt-6 p-4 bg-gradient-to-br from-orange-50 to-orange-100/50 border border-orange-200/50 rounded-xl text-center">
								<p class="text-xs font-bold text-orange-600 uppercase tracking-wide mb-2">{$locale === 'ar' ? 'قيمة الجائزة' : 'Reward Value'}</p>
								<div>
									{#if redeemCouponData.reward_type === 'percentage'}
										<span class="text-3xl font-black text-orange-700">{redeemCouponData.reward_value}%</span>
										<span class="text-base font-bold text-orange-600 ml-1">{$locale === 'ar' ? 'خصم' : 'OFF'}</span>
									{:else}
										<span class="text-3xl font-black text-orange-700">{redeemCouponData.reward_value}</span>
										<span class="text-base font-bold text-orange-600 ml-1">SAR {$locale === 'ar' ? 'خصم' : 'OFF'}</span>
									{/if}
								</div>
								{#if redeemCouponData.max_discount}
									<p class="text-xs text-orange-600/70 mt-2">{$locale === 'ar' ? 'الحد الأقصى' : 'Max Discount'}: {redeemCouponData.max_discount} SAR</p>
								{/if}
								<p class="text-xs text-orange-600/70 mt-1">{redeemCouponData.reward_label_en || redeemCouponData.reward_label}</p>
								{#if redeemCouponData.reward_label_ar}
									<p class="text-xs text-orange-600/70">{redeemCouponData.reward_label_ar}</p>
								{/if}
							</div>
						{/if}
					</div>

					<!-- Action Buttons -->
					<div class="flex gap-3 p-6 border-t border-slate-100 bg-slate-50">
						{#if !verificationStatus.alreadyRedeemed && !verificationStatus.isExpired && !verificationStatus.isCancelled}
							<button
								class="flex-1 py-3 bg-emerald-600 text-white rounded-xl text-sm font-bold uppercase tracking-wide flex items-center justify-center gap-2 transition-all duration-200 hover:bg-emerald-700 hover:shadow-lg hover:shadow-emerald-200"
								on:click={proceedWithRedemption}
							>
								→ {$locale === 'ar' ? 'متابعة الاسترجاع' : 'Proceed to Redemption'}
							</button>
						{/if}
						<button
							class="px-6 py-3 bg-white border border-slate-200 text-slate-600 rounded-xl text-sm font-bold uppercase tracking-wide transition-all duration-200 hover:bg-slate-50 hover:border-slate-300 hover:shadow-md"
							on:click={cancelVerification}
						>
							{$locale === 'ar' ? 'إلغاء' : 'Cancel'}
						</button>
					</div>
				</div>

				{:else if redeemStep === 'details' || redeemStep === 'redeeming'}
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.08)] overflow-hidden">
						<!-- Discount Badge -->
						<div class="bg-gradient-to-br from-orange-50 to-orange-100/50 border-b border-orange-200/50 p-5 text-center">
							<div class="inline-block">
								{#if redeemCouponData.reward_type === 'percentage'}
									<span class="text-3xl font-black text-orange-700">{redeemCouponData.reward_value}%</span>
									<span class="text-base font-bold text-orange-600 ml-1">OFF</span>
								{:else}
									<span class="text-3xl font-black text-orange-700">{redeemCouponData.reward_value}</span>
									<span class="text-base font-bold text-orange-600 ml-1">SAR OFF</span>
								{/if}
							</div>
							{#if redeemCouponData.max_discount}
								<p class="text-xs text-orange-600/70 mt-1">{$t('giftWheel.maxDiscount')}: {redeemCouponData.max_discount} SAR</p>
							{/if}
						</div>

						<!-- Gift Details -->
						<div class="p-4 space-y-2">
							<div class="flex justify-between items-center py-1.5 border-b border-slate-100">
								<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.couponCode')}</span>
								<span class="text-sm font-bold font-mono text-orange-600 tracking-widest">{redeemCouponData.code}</span>
							</div>
							<div class="flex justify-between items-center py-1.5 border-b border-slate-100">
								<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.reward')}</span>
								<span class="text-sm font-semibold text-slate-700">{redeemCouponData.reward_label_en || redeemCouponData.reward_label || ''}{redeemCouponData.reward_label_ar ? ` / ${redeemCouponData.reward_label_ar}` : ''}</span>
							</div>
							{#if redeemCouponData.bill_number}
								<div class="flex justify-between items-center py-1.5 border-b border-slate-100">
									<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.originalBill')}</span>
									<span class="text-sm font-semibold text-slate-700">#{redeemCouponData.bill_number}</span>
								</div>
							{/if}
							{#if redeemCouponData.bill_amount}
								<div class="flex justify-between items-center py-1.5 border-b border-slate-100">
									<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.originalAmount')}</span>
									<span class="text-sm font-semibold text-slate-700">{redeemCouponData.bill_amount} SAR</span>
								</div>
							{/if}
							{#if redeemCouponData.bill_date}
								<div class="flex justify-between items-center py-1.5 border-b border-slate-100">
									<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.billDate')}</span>
									<span class="text-sm font-semibold text-slate-700">{redeemCouponData.bill_date}</span>
								</div>
							{/if}
							<div class="flex justify-between items-center py-1.5">
								<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.expiry')}</span>
								<span class="text-sm font-semibold text-slate-700">{redeemCouponData.expiry_date || 'N/A'}</span>
							</div>
						</div>

						{#if redeemSuccess}
							<!-- Success state -->
							<div class="p-5">
								<div class="bg-emerald-50 border border-emerald-200 rounded-xl p-4 text-center">
									<div class="text-3xl mb-2">✅</div>
									<p class="text-sm font-bold text-emerald-700">{$t('giftWheel.redeemSuccessMsg')}</p>
									<p class="text-xs text-emerald-600/70 mt-1">{$t('giftWheel.redeemBillNumber')}: #{redeemBillNumber} &bull; {$t('giftWheel.discountGiven')}: {redeemDiscountAmount} SAR</p>
								</div>
								<div class="flex gap-3 mt-4">
									<button
										class="flex-1 py-3 bg-orange-600 text-white rounded-xl text-sm font-bold uppercase tracking-wide flex items-center justify-center gap-2 transition-all duration-200 hover:bg-orange-700 hover:shadow-lg hover:shadow-orange-200"
										on:click={printRedeemReceipt}
									>
										🖨️ {$t('giftWheel.printReceipt')}
									</button>
									<button
										class="px-5 py-3 bg-white border border-slate-200 text-slate-600 rounded-xl text-sm font-bold uppercase tracking-wide transition-all duration-200 hover:bg-slate-50 hover:border-slate-300 hover:shadow-md"
										on:click={reset}
									>
										{$t('giftWheel.newCode')}
									</button>
								</div>
							</div>
						{:else}
							<!-- Redeem form -->
							<div class="p-5 border-t border-slate-100 space-y-4">
								<div>
									<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="redeem-bill">{$t('giftWheel.redeemBillNumber')}</label>
									<input
										id="redeem-bill"
										type="text"
										bind:value={redeemBillNumber}
										placeholder={$t('giftWheel.enterBillNumber')}
										class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
										style="color: #000 !important; background-color: #fff !important;"
									/>
								</div>
								<div>
									<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="redeem-bill-amount">
										{$locale === 'ar' ? 'مبلغ الفاتورة' : 'Bill Amount'} (SAR)
									</label>
									<input
										id="redeem-bill-amount"
										type="number"
										step="0.01"
										min="0"
										bind:value={redeemBillAmount}
										placeholder={$locale === 'ar' ? 'أدخل مبلغ الفاتورة' : 'Enter bill amount'}
										class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
										style="color: #000 !important; background-color: #fff !important;"
									/>
								</div>
								<div>
<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="redeem-amount">
									{$t('giftWheel.discountGiven')}
									{#if maxAllowedDiscount !== null}
										<span class="text-orange-500 font-normal normal-case tracking-normal">({$locale === 'ar' ? 'الحد الأقصى' : 'Max'}: {maxAllowedDiscount} SAR)</span>
									{/if}
								</label>
								<input
									id="redeem-amount"
									type="number"
									step="0.01"
									min="0"
									bind:value={redeemDiscountAmount}
									placeholder={$t('giftWheel.enterDiscountAmount')}
									class="w-full px-4 py-3 bg-white border rounded-xl text-sm focus:outline-none focus:ring-2 focus:border-transparent transition-all {discountExceeded ? 'border-red-400 focus:ring-red-500 bg-red-50' : 'border-slate-200 focus:ring-orange-500'}"
									style="color: #000 !important;"
								/>
								{#if discountExceeded}
									<div class="mt-2 bg-amber-50 border border-amber-300 rounded-lg p-2.5 text-xs">
										<div class="flex items-center gap-1.5 text-amber-700 font-bold">⚠️ Discount exceeds maximum allowed ({maxAllowedDiscount} SAR)</div>
										<div class="text-amber-600 font-bold mt-1" dir="rtl">⚠️ الخصم يتجاوز الحد الأقصى المسموح ({maxAllowedDiscount} ر.س)</div>
									</div>
								{/if}
								</div>

								{#if redeemError}
									<div class="bg-red-50 border border-red-200 rounded-xl p-3 text-sm text-red-700 font-medium">{redeemError}</div>
								{/if}

								<div class="flex gap-3">
									<button
										class="flex-1 py-3 bg-orange-600 text-white rounded-xl text-sm font-bold uppercase tracking-wide flex items-center justify-center gap-2 transition-all duration-200 hover:bg-orange-700 hover:shadow-lg hover:shadow-orange-200 disabled:opacity-50 disabled:cursor-not-allowed"
										on:click={redeemCoupon}
										disabled={redeemStep === 'redeeming' || !redeemBillNumber.trim() || !redeemDiscountAmount}
									>
										{#if redeemStep === 'redeeming'}
											<div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
											{$t('giftWheel.redeeming')}
										{:else}
											🎟️ {$t('giftWheel.redeemNow')}
										{/if}
									</button>
									<button
										class="px-5 py-3 bg-white border border-slate-200 text-slate-600 rounded-xl text-sm font-bold uppercase tracking-wide transition-all duration-200 hover:bg-slate-50 hover:border-slate-300 hover:shadow-md"
										on:click={reset}
									>
										{$t('giftWheel.newCode')}
									</button>
								</div>
							</div>
						{/if}
					</div>
				{/if}
		</div>
	</div>
</div>
