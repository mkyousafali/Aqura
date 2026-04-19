<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { onMount, onDestroy } from 'svelte';

	export let user: any;
	export let branch: any;

	let supabase: any = null;
	let activeTab: 'issue' | 'redeem' = 'issue';
	let couponCode = '';
	let step: 'input' | 'validating' | 'details' | 'printing' = 'input';
	let loading = false;
	let error = '';
	let couponData: any = null;

	// Redeem tab state
	let redeemCode = '';
	let redeemStep: 'input' | 'validating' | 'details' | 'redeeming' = 'input';
	let redeemLoading = false;
	let redeemError = '';
	let redeemSuccess = false;
	let redeemCouponData: any = null;
	let redeemBillNumber = '';
	let redeemDiscountAmount = '';

	let realtimeChannel: any = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		setupRealtime();
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
				if (couponData && payload.new && payload.new.code === couponData.code) {
					validateCoupon();
				}
			})
			.subscribe();
	}

	async function validateCoupon() {
		if (!couponCode.trim() || !supabase) return;

		loading = true;
		error = '';
		step = 'validating';

		try {
			const { data, error: rpcError } = await supabase.rpc('gift_wheel_validate_coupon', {
				p_code: couponCode.trim()
			});

			if (rpcError) throw rpcError;

			if (!data.valid) {
				error = data.error || 'Invalid coupon';
				step = 'input';
			} else {
				couponData = data;
				step = 'details';
			}
		} catch (err: any) {
			error = err.message || 'Validation failed';
			step = 'input';
		} finally {
			loading = false;
		}
	}

	async function printCoupon() {
		if (!couponData || !supabase) return;

		step = 'printing';

		try {
			const { data, error: rpcError } = await supabase.rpc('gift_wheel_redeem_coupon', {
				p_code: couponData.code,
				p_action: 'print',
				p_branch_id: branch?.id ? String(branch.id) : null
			});

			if (rpcError) throw rpcError;

			const printWindow = window.open('', '_blank', 'width=400,height=600');
			if (printWindow) {
				const discountText = couponData.reward_type === 'percentage'
					? `${couponData.reward_value}% OFF`
					: `${couponData.reward_value} SAR OFF`;

				const maxDiscountHtml = couponData.max_discount
					? `<p style="font-size:14px;color:#666;">Max Discount: ${couponData.max_discount} SAR</p>`
					: '';

				printWindow.document.write(`
<!DOCTYPE html>
<html>
<head>
	<title>Gift Wheel Coupon</title>
	<style>
		body {
			font-family: 'Courier New', monospace;
			width: 280px;
			margin: 0 auto;
			padding: 20px 10px;
			text-align: center;
		}
		.divider {
			border-top: 1px dashed #000;
			margin: 10px 0;
		}
		.title {
			font-size: 18px;
			font-weight: bold;
			margin: 8px 0;
		}
		.discount {
			font-size: 32px;
			font-weight: bold;
			margin: 16px 0;
			padding: 12px;
			border: 2px dashed #000;
		}
		.code {
			font-size: 20px;
			font-weight: bold;
			letter-spacing: 2px;
			margin: 12px 0;
		}
		.info {
			font-size: 12px;
			color: #666;
			margin: 4px 0;
		}
		.note {
			font-size: 11px;
			color: #999;
			margin-top: 16px;
			font-style: italic;
		}
	</style>
</head>
<body>
	<div class="title">🎡 GIFT WHEEL COUPON</div>
	<div class="divider"></div>
	<div class="discount">${discountText}</div>
	${maxDiscountHtml}
	<div class="divider"></div>
	<p style="font-size:12px;color:#666;">Coupon Code:</p>
	<div class="code">${couponData.code}</div>
	<div class="divider"></div>
	<p class="info">Valid Until: ${couponData.expiry_date || 'N/A'}</p>
	<p class="info">Valid for next purchase only</p>
	<div class="divider"></div>
	<p class="note">Present this coupon at checkout</p>
	<script>window.onload = function() { window.print(); }</` + `script>
</body>
</html>`);
				printWindow.document.close();
			}

			step = 'details';
		} catch (err: any) {
			error = err.message || 'Print failed';
			step = 'details';
		}
	}

	function reset() {
		couponCode = '';
		step = 'input';
		error = '';
		couponData = null;
		redeemCode = '';
		redeemStep = 'input';
		redeemError = '';
		redeemSuccess = false;
		redeemCouponData = null;
		redeemBillNumber = '';
		redeemDiscountAmount = '';
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			if (activeTab === 'issue' && step === 'input') validateCoupon();
			if (activeTab === 'redeem' && redeemStep === 'input') validateForRedeem();
		}
	}

	async function validateForRedeem() {
		if (!redeemCode.trim() || !supabase) return;

		redeemLoading = true;
		redeemError = '';
		redeemSuccess = false;
		redeemStep = 'validating';

		try {
			const { data, error: rpcError } = await supabase.rpc('gift_wheel_validate_coupon', {
				p_code: redeemCode.trim()
			});

			if (rpcError) throw rpcError;

			if (!data.valid) {
				redeemError = data.error || 'Invalid coupon';
				redeemStep = 'input';
			} else if (data.status !== 'printed') {
				redeemError = data.status === 'active' ? 'Coupon has not been issued yet' : 'Coupon cannot be redeemed (status: ' + data.status + ')';
				redeemStep = 'input';
			} else {
				redeemCouponData = data;
				redeemStep = 'details';
			}
		} catch (err: any) {
			redeemError = err.message || 'Validation failed';
			redeemStep = 'input';
		} finally {
			redeemLoading = false;
		}
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
				redeemError = data.error || 'Redemption failed';
				redeemStep = 'details';
			} else {
				redeemSuccess = true;
				redeemStep = 'details';
			}
		} catch (err: any) {
			redeemError = err.message || 'Redemption failed';
			redeemStep = 'details';
		}
	}

	function printRedeemReceipt() {
		if (!redeemCouponData) return;

		const printWindow = window.open('', '_blank', 'width=400,height=600');
		if (printWindow) {
			const discountText = redeemCouponData.reward_type === 'percentage'
				? `${redeemCouponData.reward_value}% OFF`
				: `${redeemCouponData.reward_value} SAR OFF`;

			const maxDiscountHtml = redeemCouponData.max_discount
				? `<p class="info">Max Discount: ${redeemCouponData.max_discount} SAR</p>`
				: '';

			const now = new Date().toLocaleString('en-GB', { dateStyle: 'short', timeStyle: 'short' });

			printWindow.document.write(`
<!DOCTYPE html>
<html>
<head>
	<title>Redemption Receipt</title>
	<style>
		body {
			font-family: 'Courier New', monospace;
			width: 280px;
			margin: 0 auto;
			padding: 20px 10px;
			text-align: center;
		}
		.divider {
			border-top: 1px dashed #000;
			margin: 10px 0;
		}
		.title {
			font-size: 16px;
			font-weight: bold;
			margin: 8px 0;
		}
		.discount {
			font-size: 28px;
			font-weight: bold;
			margin: 12px 0;
			padding: 10px;
			border: 2px solid #000;
		}
		.code {
			font-size: 18px;
			font-weight: bold;
			letter-spacing: 2px;
			margin: 8px 0;
		}
		.info {
			font-size: 12px;
			color: #333;
			margin: 4px 0;
			text-align: left;
		}
		.label {
			font-weight: bold;
		}
		.redeemed-badge {
			font-size: 14px;
			font-weight: bold;
			padding: 6px 16px;
			border: 2px solid #000;
			display: inline-block;
			margin: 8px 0;
			letter-spacing: 2px;
		}
	</style>
</head>
<body>
	<div class="title">🎟️ GIFT WHEEL - REDEMPTION RECEIPT</div>
	<div class="divider"></div>
	<div class="discount">${discountText}</div>
	${maxDiscountHtml}
	<div class="divider"></div>
	<p class="info"><span class="label">Coupon Code:</span> ${redeemCouponData.code}</p>
	<p class="info"><span class="label">Reward:</span> ${redeemCouponData.reward_label}</p>
	${redeemCouponData.bill_number ? `<p class="info"><span class="label">Original Bill #:</span> ${redeemCouponData.bill_number}</p>` : ''}
	${redeemCouponData.bill_amount ? `<p class="info"><span class="label">Original Bill Amount:</span> ${redeemCouponData.bill_amount} SAR</p>` : ''}
	<div class="divider"></div>
	<p class="info"><span class="label">Redeemed on Bill #:</span> ${redeemBillNumber}</p>
	<p class="info"><span class="label">Discount Given:</span> ${redeemDiscountAmount} SAR</p>
	<p class="info"><span class="label">Date/Time:</span> ${now}</p>
	<div class="divider"></div>
	<div class="redeemed-badge">✓ REDEEMED</div>
	<script>window.onload = function() { window.print(); }<` + `/script>
</body>
</html>`);
			printWindow.document.close();
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header with Tab Buttons -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-center shadow-sm">
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			<button
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
				{activeTab === 'issue'
					? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]'
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => { activeTab = 'issue'; reset(); }}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">🎁</span>
				<span class="relative z-10">{$t('giftWheel.issueGift')}</span>
				{#if activeTab === 'issue'}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
			<button
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden
				{activeTab === 'redeem'
					? 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]'
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => { activeTab = 'redeem'; reset(); }}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">🎟️</span>
				<span class="relative z-10">{$t('giftWheel.redeemGift')}</span>
				{#if activeTab === 'redeem'}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background blurs -->
		<div class="absolute top-0 right-0 w-[300px] h-[300px] bg-emerald-100/20 rounded-full blur-[100px] -mr-32 -mt-32 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[300px] h-[300px] bg-orange-100/20 rounded-full blur-[100px] -ml-32 -mb-32 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative max-w-lg mx-auto">
			{#if activeTab === 'issue'}
				<!-- ISSUE GIFT TAB -->
				{#if step === 'input' || step === 'validating'}
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.08)] p-6">
						<div class="flex items-center gap-3 mb-5">
							<div class="w-10 h-10 rounded-xl bg-emerald-100 flex items-center justify-center text-lg">🎁</div>
							<div>
								<h3 class="text-sm font-black text-slate-800 uppercase tracking-wide">{$t('giftWheel.issueGift')}</h3>
								<p class="text-xs text-slate-400 mt-0.5">{$t('giftWheel.issueGiftDesc')}</p>
							</div>
						</div>

						{#if error}
							<div class="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 text-sm text-red-700 font-medium">{error}</div>
						{/if}

						<div class="mb-4">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="coupon-input">{$t('giftWheel.couponCode')}</label>
							<input
								id="coupon-input"
								type="text"
								bind:value={couponCode}
								on:keydown={handleKeydown}
								placeholder={$t('giftWheel.enterCouponCode')}
								disabled={loading}
								autofocus
								class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-base font-mono tracking-widest focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all disabled:opacity-50"
								style="color: #000 !important; background-color: #fff !important;"
							/>
						</div>

						<button
							class="w-full py-3 bg-emerald-600 text-white rounded-xl text-sm font-bold uppercase tracking-wide flex items-center justify-center gap-2 transition-all duration-200 hover:bg-emerald-700 hover:shadow-lg hover:shadow-emerald-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-none"
							on:click={validateCoupon}
							disabled={loading || !couponCode.trim()}
						>
							{#if loading}
								<div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
								{$t('giftWheel.validating')}
							{:else}
								🔍 {$t('giftWheel.validateCoupon')}
							{/if}
						</button>
					</div>

				{:else if step === 'details' || step === 'printing'}
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.08)] overflow-hidden">
						<!-- Discount Badge -->
						<div class="bg-gradient-to-br from-emerald-50 to-emerald-100/50 border-b border-emerald-200/50 p-6 text-center">
							<div class="inline-block">
								{#if couponData.reward_type === 'percentage'}
									<span class="text-4xl font-black text-emerald-700">{couponData.reward_value}%</span>
									<span class="text-lg font-bold text-emerald-600 ml-1">OFF</span>
								{:else}
									<span class="text-4xl font-black text-emerald-700">{couponData.reward_value}</span>
									<span class="text-lg font-bold text-emerald-600 ml-1">SAR OFF</span>
								{/if}
							</div>
							{#if couponData.max_discount}
								<p class="text-xs text-emerald-600/70 mt-1">{$t('giftWheel.maxDiscount')}: {couponData.max_discount} SAR</p>
							{/if}
						</div>

						<!-- Details -->
						<div class="p-5 space-y-3">
							<div class="flex justify-between items-center py-2 border-b border-slate-100">
								<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.couponCode')}</span>
								<span class="text-sm font-bold font-mono text-emerald-600 tracking-widest">{couponData.code}</span>
							</div>
							<div class="flex justify-between items-center py-2 border-b border-slate-100">
								<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.reward')}</span>
								<span class="text-sm font-semibold text-slate-700">{couponData.reward_label}</span>
							</div>
							<div class="flex justify-between items-center py-2 border-b border-slate-100">
								<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.expiry')}</span>
								<span class="text-sm font-semibold text-slate-700">{couponData.expiry_date || 'N/A'}</span>
							</div>
							<div class="flex justify-between items-center py-2">
								<span class="text-xs font-bold text-slate-500 uppercase tracking-wide">{$t('giftWheel.status')}</span>
								<span class="text-xs font-bold uppercase px-2.5 py-1 rounded-lg {couponData.status === 'printed' ? 'bg-blue-100 text-blue-700' : couponData.status === 'redeemed' ? 'bg-purple-100 text-purple-700' : 'bg-emerald-100 text-emerald-700'}">
									{couponData.status}
								</span>
							</div>
						</div>

						<!-- Action buttons -->
						<div class="p-5 pt-0 flex gap-3">
							<button
								class="flex-1 py-3 bg-emerald-600 text-white rounded-xl text-sm font-bold uppercase tracking-wide flex items-center justify-center gap-2 transition-all duration-200 hover:bg-emerald-700 hover:shadow-lg hover:shadow-emerald-200 disabled:opacity-50 disabled:cursor-not-allowed"
								on:click={printCoupon}
								disabled={step === 'printing'}
							>
								{#if step === 'printing'}
									<div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
									{$t('giftWheel.printing')}
								{:else}
									🖨️ {$t('giftWheel.printCoupon')}
								{/if}
							</button>
							<button
								class="px-5 py-3 bg-white border border-slate-200 text-slate-600 rounded-xl text-sm font-bold uppercase tracking-wide transition-all duration-200 hover:bg-slate-50 hover:border-slate-300 hover:shadow-md"
								on:click={reset}
							>
								{$t('giftWheel.newCode')}
							</button>
						</div>

						{#if error}
							<div class="mx-5 mb-5 bg-red-50 border border-red-200 rounded-xl p-3 text-sm text-red-700 font-medium">{error}</div>
						{/if}
					</div>
				{/if}

			{:else}
				<!-- REDEEM GIFT TAB -->
				{#if redeemStep === 'input' || redeemStep === 'validating'}
					<div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-[0_16px_48px_-12px_rgba(0,0,0,0.08)] p-6">
						<div class="flex items-center gap-3 mb-5">
							<div class="w-10 h-10 rounded-xl bg-orange-100 flex items-center justify-center text-lg">🎟️</div>
							<div>
								<h3 class="text-sm font-black text-slate-800 uppercase tracking-wide">{$t('giftWheel.redeemGift')}</h3>
								<p class="text-xs text-slate-400 mt-0.5">{$t('giftWheel.redeemGiftDesc')}</p>
							</div>
						</div>

						{#if redeemError}
							<div class="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 text-sm text-red-700 font-medium">{redeemError}</div>
						{/if}

						<div class="mb-4">
							<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="redeem-input">{$t('giftWheel.couponCode')}</label>
							<input
								id="redeem-input"
								type="text"
								bind:value={redeemCode}
								on:keydown={handleKeydown}
								placeholder={$t('giftWheel.enterCouponCode')}
								disabled={redeemLoading}
								class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-base font-mono tracking-widest focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all disabled:opacity-50"
								style="color: #000 !important; background-color: #fff !important;"
							/>
						</div>

						<button
							class="w-full py-3 bg-orange-600 text-white rounded-xl text-sm font-bold uppercase tracking-wide flex items-center justify-center gap-2 transition-all duration-200 hover:bg-orange-700 hover:shadow-lg hover:shadow-orange-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-none"
							on:click={validateForRedeem}
							disabled={redeemLoading || !redeemCode.trim()}
						>
							{#if redeemLoading}
								<div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
								{$t('giftWheel.validating')}
							{:else}
								🔍 {$t('giftWheel.validateCoupon')}
							{/if}
						</button>
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
								<span class="text-sm font-semibold text-slate-700">{redeemCouponData.reward_label}</span>
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
									<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="redeem-amount">{$t('giftWheel.discountGiven')}</label>
									<input
										id="redeem-amount"
										type="number"
										step="0.01"
										min="0"
										bind:value={redeemDiscountAmount}
										placeholder={$t('giftWheel.enterDiscountAmount')}
										class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
										style="color: #000 !important; background-color: #fff !important;"
									/>
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
			{/if}
		</div>
	</div>
</div>
