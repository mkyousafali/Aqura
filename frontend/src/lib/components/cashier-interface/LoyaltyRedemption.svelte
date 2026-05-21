<script lang="ts">
	import { onMount } from 'svelte';
	import { cashierUser } from '$lib/stores/cashierAuth';
	import { _ as t } from '$lib/i18n';

	export let user: any;
	export let branch: any;

	let supabase: any = null;
	let logoUrl = '';

	// ─── Section ────────────────────────────────────────────────────────
	type Section = 'check' | 'redeem';
	let activeSection: Section = 'check';

	// ─── Point Check state ───────────────────────────────────────────────
	let checkPhone = '';
	type CheckStep = 'idle' | 'loading' | 'found' | 'not_found' | 'error';
	let checkStep: CheckStep = 'idle';
	let checkResult: any = null;
	let checkError = '';

	// ─── Redemption state ────────────────────────────────────────────────
	let redeemPhone = '';
	type RedeemStep =
		| 'idle'
		| 'loading'
		| 'found'
		| 'partial_input'
		| 'sending_otp'
		| 'otp_entry'
		| 'verifying'
		| 'success'
		| 'error';
	let redeemStep: RedeemStep = 'idle';
	let redeemCustomer: any = null;
	let redeemError = '';
	let redeemType: 'partial' | 'full' = 'full';
	let partialPoints = '';
	let pointsToRedeem = 0;
	let redemptionId = '';
	let otpInput = '';
	let otpError = '';
	let successData: any = null;

	// ─── Autocomplete ────────────────────────────────────────────────────
	let checkSuggestions: any[] = [];
	let showCheckDropdown = false;
	let checkSearchTimer: ReturnType<typeof setTimeout>;

	let redeemSuggestions: any[] = [];
	let showRedeemDropdown = false;
	let redeemSearchTimer: ReturnType<typeof setTimeout>;

	// ─── Lifecycle ───────────────────────────────────────────────────────
	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		try {
			const { data } = await supabase
				.from('app_icons')
				.select('storage_path')
				.eq('id', 'c1004e65-4484-464c-8a7f-9b0cbc5b6246')
				.single();
			if (data?.storage_path) {
				const { data: urlData } = supabase.storage
					.from('app-icons')
					.getPublicUrl(data.storage_path);
				logoUrl = urlData?.publicUrl || '';
			}
		} catch {
			/* logo optional */
		}
	});

	// ─── Helpers ─────────────────────────────────────────────────────────
	function normalisePhone(raw: string): string {
		const digits = raw.replace(/\D/g, '');
		if (digits.startsWith('966')) return digits;
		if (digits.startsWith('0')) return '966' + digits.slice(1);
		return '966' + digits;
	}

	function validatePhone(raw: string): boolean {
		const d = raw.replace(/\D/g, '');
		return d.length >= 9 && d.length <= 15;
	}

	function errorMsg(code: string, extra?: any): string {
		const msgs: Record<string, string> = {
			customer_not_found:    $t('coupon.loyaltyErrNotFound'),
			customer_not_approved: $t('coupon.loyaltyErrNotApproved'),
			no_points_available:   $t('coupon.loyaltyErrNoPoints'),
			below_minimum:         $t('coupon.loyaltyErrBelowMin') + (extra?.min_required != null ? ` (${extra.min_required} ${$t('coupon.loyaltyMinRedeemUnit')})` : ''),
			exceeds_available:     $t('coupon.loyaltyErrExceeds') + (extra?.available != null ? ` (${extra.available} ${$t('coupon.loyaltyMinRedeemUnit')})` : ''),
			invalid_points_amount: $t('coupon.loyaltyErrInvalidAmt'),
			redemption_not_found:  $t('coupon.loyaltyErrRedeemNotFound'),
			redemption_not_pending:$t('coupon.loyaltyErrNotPending'),
			otp_expired:           $t('coupon.loyaltyErrOtpExpired'),
			invalid_otp:           $t('coupon.loyaltyErrInvalidOtp') + (extra?.attempts_remaining != null ? ` (${extra.attempts_remaining})` : ''),
			max_otp_attempts:      $t('coupon.loyaltyErrMaxAttempts')
		};
		return msgs[code] || code || $t('coupon.loyaltyErrUnknown');
	}

	// ─── Point Check ─────────────────────────────────────────────────────
	async function doCheckPoints() {
		if (!validatePhone(checkPhone)) {
			checkError = $t('coupon.loyaltyErrPhoneInvalid');
			return;
		}
		checkStep = 'loading';
		checkError = '';
		try {
			const { data, error } = await supabase.rpc('check_loyalty_points', {
				p_phone: normalisePhone(checkPhone)
			});
			if (error) throw error;
			if (!data?.success) {
				checkError = errorMsg(data?.error, data);
				checkStep = 'not_found';
				return;
			}
			checkResult = data;
			checkStep = 'found';
		} catch (e: any) {
			checkError = e?.message || $t('coupon.loyaltyErrUnknown');
			checkStep = 'error';
		}
	}

	async function searchCustomers(query: string): Promise<any[]> {
		if (!supabase || !query.trim()) return [];
		const q = query.trim();
		const digits = q.replace(/\D/g, '');

		// Normalise local format → stored format (e.g. 054… → 96654…)
		let phoneQ = digits;
		if (digits.startsWith('0')) phoneQ = '966' + digits.slice(1);
		else if (digits && !digits.startsWith('966')) phoneQ = '966' + digits;

		const orFilter = phoneQ
			? `whatsapp_number.ilike.${phoneQ}%,name.ilike.${q}%`
			: `name.ilike.${q}%`;

		const { data } = await supabase
			.from('customers')
			.select('id, name, whatsapp_number, loyalty_tier_name')
			.eq('is_deleted', false)
			.eq('registration_status', 'approved')
			.or(orFilter)
			.limit(7);
		return data || [];
	}

	function onCheckPhoneInput() {
		clearTimeout(checkSearchTimer);
		if (!checkPhone.trim()) {
			checkSuggestions = [];
			showCheckDropdown = false;
			return;
		}
		checkSearchTimer = setTimeout(async () => {
			checkSuggestions = await searchCustomers(checkPhone);
			showCheckDropdown = checkSuggestions.length > 0;
		}, 250);
	}

	function selectCheckSuggestion(c: any) {
		checkPhone = c.whatsapp_number;
		checkSuggestions = [];
		showCheckDropdown = false;
	}

	function onRedeemPhoneInput() {
		clearTimeout(redeemSearchTimer);
		if (!redeemPhone.trim()) {
			redeemSuggestions = [];
			showRedeemDropdown = false;
			return;
		}
		redeemSearchTimer = setTimeout(async () => {
			redeemSuggestions = await searchCustomers(redeemPhone);
			showRedeemDropdown = redeemSuggestions.length > 0;
		}, 250);
	}

	function selectRedeemSuggestion(c: any) {
		redeemPhone = c.whatsapp_number;
		redeemSuggestions = [];
		showRedeemDropdown = false;
	}

	function resetCheck() {
		checkPhone = '';
		checkStep = 'idle';
		checkResult = null;
		checkError = '';
		checkSuggestions = [];
		showCheckDropdown = false;
	}

	// ─── Redemption ───────────────────────────────────────────────────────
	async function doLookupForRedeem() {
		if (!validatePhone(redeemPhone)) {
			redeemError = $t('coupon.loyaltyErrPhoneInvalid');
			return;
		}
		redeemStep = 'loading';
		redeemError = '';
		try {
			const { data, error } = await supabase.rpc('check_loyalty_points', {
				p_phone: normalisePhone(redeemPhone)
			});
			if (error) throw error;
			if (!data?.success) {
				redeemError = errorMsg(data?.error, data);
				redeemStep = 'idle';
				return;
			}
			redeemCustomer = data;
			redeemStep = 'found';
		} catch (e: any) {
			redeemError = e?.message || $t('coupon.loyaltyErrUnknown');
			redeemStep = 'idle';
		}
	}

	function selectRedeemFull() {
		redeemType = 'full';
		pointsToRedeem = Number(redeemCustomer.available_points);
		initiateRedeem();
	}

	function selectRedeemPartial() {
		redeemType = 'partial';
		partialPoints = '';
		redeemError = '';
		redeemStep = 'partial_input';
	}

	function confirmPartialPoints() {
		const n = Number(partialPoints);
		if (!n || n <= 0 || !Number.isFinite(n)) {
			redeemError = $t('coupon.loyaltyErrPartialInvalid');
			return;
		}
		if (n > redeemCustomer.available_points) {
			redeemError = `${$t('coupon.loyaltyErrPartialMax')} ${redeemCustomer.available_points} ${$t('coupon.loyaltyErrPartialMaxUnit')}`;
			return;
		}
		pointsToRedeem = n;
		initiateRedeem();
	}

	async function initiateRedeem() {
		redeemStep = 'sending_otp';
		redeemError = '';
		const currentUser = $cashierUser || user;
		try {
			const { data, error } = await supabase.rpc('initiate_loyalty_redemption', {
				p_phone: normalisePhone(redeemPhone),
				p_points_to_redeem: pointsToRedeem,
				p_redemption_type: redeemType,
				p_cashier_id: currentUser?.id ? String(currentUser.id) : (currentUser?.username || null),
				p_branch_id: branch?.id ? String(branch.id) : null,
				p_erp_branch_id: branch?.erp_branch_id ? String(branch.erp_branch_id) : null
			});
			if (error) throw error;
			if (!data?.success) {
				redeemError = errorMsg(data?.error, data);
				redeemStep = 'found';
				return;
			}
			redemptionId = data.redemption_id;
			await sendWhatsAppOtp(data.whatsapp_number, data.otp_code, data.customer_name);
			otpInput = '';
			otpError = '';
			redeemStep = 'otp_entry';
		} catch (e: any) {
			redeemError = e?.message || $t('coupon.loyaltyErrUnknown');
			redeemStep = 'found';
		}
	}

	async function sendWhatsAppOtp(phone: string, otp: string, name: string) {
		try {
			const { getEdgeFunctionUrl } = await import('$lib/utils/supabase');
			const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
			const formattedPhone = phone.startsWith('+') ? phone : '+' + phone;
			await fetch(getEdgeFunctionUrl('send-whatsapp'), {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					Authorization: `Bearer ${supabaseAnonKey}`
				},
				body: JSON.stringify({
					action: 'send_loyalty_otp',
					phone_number: formattedPhone,
					access_code: otp,
					customer_name: name
				})
			});
		} catch (e) {
			console.warn('WhatsApp OTP send failed (non-blocking):', e);
		}
	}

	async function doConfirmOtp() {
		const code = otpInput.trim();
		if (!code || code.length !== 6 || !/^\d{6}$/.test(code)) {
			otpError = $t('coupon.loyaltyOtpLabel');
			return;
		}
		redeemStep = 'verifying';
		otpError = '';
		try {
			const { data, error } = await supabase.rpc('confirm_loyalty_redemption', {
				p_redemption_id: redemptionId,
				p_otp_code: code
			});
			if (error) throw error;
			if (!data?.success) {
				otpError = errorMsg(data?.error, data);
				redeemStep = 'otp_entry';
				return;
			}
			successData = data;
			redeemStep = 'success';
		} catch (e: any) {
			otpError = e?.message || $t('coupon.loyaltyErrUnknown');
			redeemStep = 'otp_entry';
		}
	}

	function resetRedeem() {
		redeemPhone = '';
		redeemStep = 'idle';
		redeemCustomer = null;
		redeemError = '';
		redeemType = 'full';
		partialPoints = '';
		pointsToRedeem = 0;
		redemptionId = '';
		otpInput = '';
		otpError = '';
		successData = null;
	}

	// ─── Print Coupon ─────────────────────────────────────────────────────
	function printCoupon() {
		if (!successData) return;
		const today = new Date();
		const dateStr = today.toLocaleDateString('ar-SA', {
			year: 'numeric',
			month: 'long',
			day: 'numeric'
		});
		const timeStr = today.toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' });
		const logoTag = logoUrl
			? `<img class="logo" src="${logoUrl}" alt="شعار أهل ايربن" />`
			: '<div style="height:8mm"></div>';

		const html = `<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
<meta charset="UTF-8">
<title>قسيمة الولاء — أهل ايربن</title>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
body {
  font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
  width: 80mm;
  background: #fff;
  color: #111;
  direction: rtl;
  text-align: center;
}
@page { size: 80mm auto; margin: 4mm; }
.logo { width: 55mm; height: auto; display: block; margin: 4mm auto 2mm; }
.prog-label { font-size: 8pt; color: #555; margin-top: 3mm; letter-spacing: 0.5px; }
.prog-name { font-size: 18pt; font-weight: bold; color: #5b21b6; margin: 1mm 0 3mm; }
.divider { border: none; border-top: 1px dashed #bbb; margin: 3mm 3mm; }
.divider-solid { border: none; border-top: 2px solid #1e1b4b; margin: 3mm 3mm; }
.section-label { font-size: 7.5pt; color: #666; margin-top: 2mm; }
.coupon-code { font-size: 15pt; font-weight: bold; color: #1e1b4b; letter-spacing: 2px; margin: 1.5mm 0; }
.value-row { margin: 2mm 0 1mm; }
.value-amount { font-size: 22pt; font-weight: bold; color: #15803d; }
.value-currency { font-size: 10pt; color: #555; margin-right: 1mm; }
.points-used { font-size: 8pt; color: #888; margin-bottom: 2mm; }
.badge {
  display: inline-block;
  background: #ede9fe;
  color: #5b21b6;
  border: 1px solid #c4b5fd;
  border-radius: 3mm;
  padding: 1mm 4mm;
  font-size: 8.5pt;
  margin: 2mm 0;
}
.thanks { font-size: 9.5pt; color: #1e1b4b; margin: 4mm 3mm 2mm; line-height: 1.7; }
.footer { font-size: 7pt; color: #aaa; margin: 3mm 0 2mm; }
.datetime { font-size: 7.5pt; color: #888; margin: 1.5mm 0; }
.stars { font-size: 10pt; color: #f59e0b; margin: 2mm 0; letter-spacing: 2px; }
.qr-wrap { margin: 3mm auto 2mm; text-align: center; }
.qr-img { width: 35mm; height: 35mm; display: block; margin: 0 auto; }
.qr-label { font-size: 7pt; color: #888; margin-top: 1.5mm; letter-spacing: 0.5px; }
</style>
</head>
<body>
${logoTag}
<div class="prog-label">برنامج الولاء</div>
<div class="prog-name">أهل ايربن</div>
<hr class="divider-solid" />
<div class="stars">⭐ ⭐ ⭐</div>
<div class="badge">قسيمة استرداد نقاط</div>
<hr class="divider" />
<div class="section-label">رمز القسيمة</div>
<div class="coupon-code">${successData.coupon_code}</div>
<div class="qr-wrap">
  <img class="qr-img" src="https://api.qrserver.com/v1/create-qr-code/?size=140x140&data=${encodeURIComponent(successData.coupon_code)}&bgcolor=ffffff&color=1e1b4b&margin=4" alt="QR" />
  <div class="qr-label">امسح للتحقق من الرمز</div>
</div>
<hr class="divider" />
<div class="section-label">قيمة القسيمة</div>
<div class="value-row">
  <span class="value-amount">${Number(successData.coupon_value).toFixed(2)}</span>
  <span class="value-currency">ريال سعودي</span>
</div>
<div class="points-used">النقاط المستردة: ${Number(successData.points_redeemed).toFixed(2)} نقطة</div>
<hr class="divider" />
<div class="thanks">
  شكراً جزيلاً على ولاءك لبرنامج أهل ايربن<br/>
  نقدّر ثقتك ونسعد بخدمتك دائماً
</div>
<hr class="divider" />
<div class="datetime">${dateStr} — ${timeStr}</div>
<div class="footer">أهل ايربن | Urban Aqura</div>
<div style="height:5mm"></div>
</body>
</html>`;

		const pw = window.open('', '', 'height=750,width=420');
		if (pw) {
			pw.document.write(html);
			pw.document.close();
			setTimeout(() => {
				pw.print();
				pw.close();
			}, 1000);
		}
	}
</script>

<div class="lr-wrap">
	<!-- Animated background blobs -->
	<div class="lr-blob lr-blob-1" aria-hidden="true"></div>
	<div class="lr-blob lr-blob-2" aria-hidden="true"></div>
	<div class="lr-blob lr-blob-3" aria-hidden="true"></div>

<div class="lr-container">
	<!-- Glass Sidebar -->
	<nav class="lr-sidebar">
		<div class="lr-logo-wrap">
			{#if logoUrl}
				<img src={logoUrl} alt={$t('coupon.loyaltyProgramName')} class="lr-logo" />
			{:else}
				<div class="lr-logo-placeholder">⭐</div>
			{/if}
			<div class="lr-program-name">{$t('coupon.loyaltyProgramName')}</div>
			<div class="lr-program-sub">{$t('coupon.loyaltyProgramLabel')}</div>
		</div>
		<div class="lr-nav-items">
			<button
				class="lr-nav-btn"
				class:active={activeSection === 'check'}
				on:click={() => (activeSection = 'check')}
			>
				<span class="lr-nav-icon">🔍</span>
				<span>{$t('coupon.loyaltySidebarCheck')}</span>
			</button>
			<button
				class="lr-nav-btn"
				class:active={activeSection === 'redeem'}
				on:click={() => (activeSection = 'redeem')}
			>
				<span class="lr-nav-icon">🎁</span>
				<span>{$t('coupon.loyaltySidebarRedeem')}</span>
			</button>
		</div>
	</nav>

	<!-- Main panel -->
	<main class="lr-main">
		<!-- ══════════════════════════════ CHECK SECTION ══════════════════════════════ -->
		{#if activeSection === 'check'}
			<div class="lr-panel">
				<div class="lr-panel-header">
					<div class="lr-panel-icon-wrap">
						<span class="lr-panel-icon">🔍</span>
					</div>
					<div>
						<h2 class="lr-panel-title">{$t('coupon.loyaltyCheckTitle')}</h2>
						<p class="lr-panel-sub">{$t('coupon.loyaltyCheckSub')}</p>
					</div>
				</div>

				{#if checkStep !== 'found'}
					<div class="lr-glass-card lr-search-card">
						<label class="lr-label" for="check-phone">{$t('coupon.loyaltyPhoneLabel')}</label>
						<div class="lr-input-row">
							<div class="lr-input-wrap">
								<span class="lr-input-icon lr-input-icon-wa">
									<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="18" height="18"><circle cx="16" cy="16" r="16" fill="#25D366"/><path d="M23.5 19.9c-.3-.2-1.8-.9-2.1-1s-.5-.2-.7.2-.8 1-1 1.2-.4.2-.7.1a8.6 8.6 0 0 1-4.2-3.7c-.3-.5.3-.5.9-1.6.1-.2 0-.4-.1-.6s-.7-1.8-1-2.4c-.2-.6-.5-.5-.7-.5h-.6c-.2 0-.6.1-.9.4a3.9 3.9 0 0 0-1.2 2.9 6.8 6.8 0 0 0 1.4 3.6c1.7 2.3 3.7 3.5 6.5 4.4.9.3 1.7.2 2.3.1.7-.1 2.1-.9 2.4-1.7.3-.8.3-1.5.2-1.6-.1-.1-.3-.2-.6-.3z" fill="#fff"/></svg>
								</span>
								<input
									id="check-phone"
									class="lr-input"
									type="tel"
									placeholder={$t('coupon.loyaltyPhonePlaceholder')}
									bind:value={checkPhone}
									autocomplete="off"
									on:input={onCheckPhoneInput}
									on:keydown={(e) => { if (e.key === 'Enter') { showCheckDropdown = false; doCheckPoints(); } if (e.key === 'Escape') { showCheckDropdown = false; } }}
									on:blur={() => setTimeout(() => { showCheckDropdown = false; }, 180)}
								/>
								{#if showCheckDropdown}
									<div class="lr-suggestions">
										{#each checkSuggestions as c (c.id)}
											<button class="lr-suggestion-item" on:mousedown|preventDefault={() => selectCheckSuggestion(c)}>
												<span class="lr-sug-name">{c.name || '—'}</span>
												<span class="lr-sug-phone">{c.whatsapp_number}</span>
												{#if c.loyalty_tier_name}<span class="lr-sug-tier">{c.loyalty_tier_name}</span>{/if}
											</button>
										{/each}
									</div>
								{/if}
							</div>
							<button
								class="lr-btn lr-btn-primary"
								on:click={doCheckPoints}
								disabled={checkStep === 'loading'}
							>
								{#if checkStep === 'loading'}
									<span class="lr-btn-spinner"></span>
									{$t('coupon.loyaltySearching')}
								{:else}
									{$t('coupon.loyaltySearchBtn')}
								{/if}
							</button>
						</div>
						{#if checkError}
							<div class="lr-error-card">{checkError}</div>
						{/if}
					</div>
				{/if}

				{#if checkStep === 'found' && checkResult}
					<div class="lr-glass-card lr-result-card">
						<div class="lr-result-header">
							<div class="lr-avatar">
								{checkResult.customer_name?.charAt(0)?.toUpperCase() || '?'}
							</div>
							<div class="lr-customer-info">
								<div class="lr-result-name">{checkResult.customer_name}</div>
								<div class="lr-result-phone">{checkResult.whatsapp_number}</div>
							</div>
							<div class="lr-tier-badge lr-tier-{(checkResult.tier_name || 'bronze').toLowerCase()}">
								<span class="lr-tier-icon">{checkResult.tier_name === 'Crown' ? '👑' : checkResult.tier_name === 'Diamond' ? '💎' : checkResult.tier_name === 'Platinum' ? '🔮' : checkResult.tier_name === 'Gold' ? '🥇' : checkResult.tier_name === 'Silver' ? '🥈' : '🥉'}</span>
								<span>{checkResult.tier_name || '—'}</span>
								{#if checkResult.tier_name_ar}<span class="lr-tier-ar"> / {checkResult.tier_name_ar}</span>{/if}
							</div>
						</div>

						<div class="lr-hero-balance">
							<div class="lr-hero-label">{$t('coupon.loyaltyAvailable')}</div>
							<div class="lr-hero-amount">{Number(checkResult.available_points).toFixed(2)}</div>
							<div class="lr-hero-sub">{$t('coupon.loyaltyPointsEq')}</div>
							<div class="lr-eligible-pill" class:eligible={checkResult.is_eligible}>
								{checkResult.is_eligible ? $t('coupon.loyaltyEligibleYes') : $t('coupon.loyaltyEligibleNo')}
							</div>
						</div>

						<div class="lr-stats-grid">
							<div class="lr-stat-card lr-stat-blue">
								<div class="lr-stat-label">{$t('coupon.loyaltyTotalEarned')}</div>
								<div class="lr-stat-value">{Number(checkResult.total_points_earned).toFixed(2)}</div>
							</div>
							<div class="lr-stat-card lr-stat-orange">
								<div class="lr-stat-label">{$t('coupon.loyaltyTotalRedeemed')}</div>
								<div class="lr-stat-value">{Number(checkResult.total_redemptions).toFixed(2)}</div>
							</div>
							<div class="lr-stat-card lr-stat-muted">
								<div class="lr-stat-label">{$t('coupon.loyaltyMinRedeem')}</div>
								<div class="lr-stat-value">{Number(checkResult.min_redeem_points).toFixed(0)} <small>{$t('coupon.loyaltyMinRedeemUnit')}</small></div>
							</div>
						</div>

						<button class="lr-btn lr-btn-ghost lr-btn-sm" on:click={resetCheck}>
							{$t('coupon.loyaltyNewInquiry')}
						</button>
					</div>
				{/if}
			</div>
		{/if}

		<!-- ══════════════════════════════ REDEEM SECTION ══════════════════════════════ -->
		{#if activeSection === 'redeem'}
			<div class="lr-panel">
				<div class="lr-panel-header">
					<div class="lr-panel-icon-wrap lr-icon-orange">
						<span class="lr-panel-icon">🎁</span>
					</div>
					<div>
						<h2 class="lr-panel-title">{$t('coupon.loyaltyRedeemTitle')}</h2>
						<p class="lr-panel-sub">{$t('coupon.loyaltyRedeemSub')}</p>
					</div>
				</div>

				<!-- ── IDLE / LOOKUP ── -->
				{#if redeemStep === 'idle' || redeemStep === 'loading'}
					<div class="lr-glass-card lr-search-card">
						<label class="lr-label" for="redeem-phone">{$t('coupon.loyaltyPhoneLabel')}</label>
						<div class="lr-input-row">
							<div class="lr-input-wrap">
								<span class="lr-input-icon lr-input-icon-wa">
									<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="18" height="18"><circle cx="16" cy="16" r="16" fill="#25D366"/><path d="M23.5 19.9c-.3-.2-1.8-.9-2.1-1s-.5-.2-.7.2-.8 1-1 1.2-.4.2-.7.1a8.6 8.6 0 0 1-4.2-3.7c-.3-.5.3-.5.9-1.6.1-.2 0-.4-.1-.6s-.7-1.8-1-2.4c-.2-.6-.5-.5-.7-.5h-.6c-.2 0-.6.1-.9.4a3.9 3.9 0 0 0-1.2 2.9 6.8 6.8 0 0 0 1.4 3.6c1.7 2.3 3.7 3.5 6.5 4.4.9.3 1.7.2 2.3.1.7-.1 2.1-.9 2.4-1.7.3-.8.3-1.5.2-1.6-.1-.1-.3-.2-.6-.3z" fill="#fff"/></svg>
								</span>
								<input
									id="redeem-phone"
									class="lr-input"
									type="tel"
									placeholder={$t('coupon.loyaltyPhonePlaceholder')}
									bind:value={redeemPhone}
									autocomplete="off"
									on:input={onRedeemPhoneInput}
									on:keydown={(e) => { if (e.key === 'Enter') { showRedeemDropdown = false; doLookupForRedeem(); } if (e.key === 'Escape') { showRedeemDropdown = false; } }}
									on:blur={() => setTimeout(() => { showRedeemDropdown = false; }, 180)}
									disabled={redeemStep === 'loading'}
								/>
								{#if showRedeemDropdown}
									<div class="lr-suggestions">
										{#each redeemSuggestions as c (c.id)}
											<button class="lr-suggestion-item" on:mousedown|preventDefault={() => selectRedeemSuggestion(c)}>
												<span class="lr-sug-name">{c.name || '—'}</span>
												<span class="lr-sug-phone">{c.whatsapp_number}</span>
												{#if c.loyalty_tier_name}<span class="lr-sug-tier">{c.loyalty_tier_name}</span>{/if}
											</button>
										{/each}
									</div>
								{/if}
							</div>
							<button
								class="lr-btn lr-btn-primary"
								on:click={doLookupForRedeem}
								disabled={redeemStep === 'loading'}
							>
								{#if redeemStep === 'loading'}
									<span class="lr-btn-spinner"></span>
									{$t('coupon.loyaltySearching')}
								{:else}
									{$t('coupon.loyaltySearchBtn')}
								{/if}
							</button>
						</div>
						{#if redeemError}
							<div class="lr-error-card">{redeemError}</div>
						{/if}
					</div>
				{/if}

				<!-- ── CUSTOMER FOUND ── -->
				{#if (redeemStep === 'found' || redeemStep === 'partial_input') && redeemCustomer}
					<div class="lr-glass-card lr-result-card">
						<div class="lr-result-header">
							<div class="lr-avatar">
								{redeemCustomer.customer_name?.charAt(0)?.toUpperCase() || '?'}
							</div>
							<div class="lr-customer-info">
								<div class="lr-result-name">{redeemCustomer.customer_name}</div>
								<div class="lr-result-phone">{redeemCustomer.whatsapp_number}</div>
							</div>
							<div class="lr-tier-badge lr-tier-{(redeemCustomer.tier_name || 'bronze').toLowerCase()}">
								<span class="lr-tier-icon">{redeemCustomer.tier_name === 'Crown' ? '👑' : redeemCustomer.tier_name === 'Diamond' ? '💎' : redeemCustomer.tier_name === 'Platinum' ? '🔮' : redeemCustomer.tier_name === 'Gold' ? '🥇' : redeemCustomer.tier_name === 'Silver' ? '🥈' : '🥉'}</span>
								<span>{redeemCustomer.tier_name || '—'}</span>
								{#if redeemCustomer.tier_name_ar}<span class="lr-tier-ar"> / {redeemCustomer.tier_name_ar}</span>{/if}
							</div>
						</div>

						<div class="lr-hero-balance">
							<div class="lr-hero-label">{$t('coupon.loyaltyAvailableWide')}</div>
							<div class="lr-hero-amount">{Number(redeemCustomer.available_points).toFixed(2)}</div>
							<div class="lr-hero-sub">{$t('coupon.loyaltyPointsEq')}</div>
						</div>

						<div class="lr-stats-grid">
							<div class="lr-stat-card lr-stat-blue">
								<div class="lr-stat-label">{$t('coupon.loyaltyTotalEarned')}</div>
								<div class="lr-stat-value">{Number(redeemCustomer.total_points_earned).toFixed(2)}</div>
							</div>
							<div class="lr-stat-card lr-stat-orange">
								<div class="lr-stat-label">{$t('coupon.loyaltyTotalRedeemed')}</div>
								<div class="lr-stat-value">{Number(redeemCustomer.total_redemptions).toFixed(2)}</div>
							</div>
						</div>

						{#if redeemError}
							<div class="lr-error-card">{redeemError}</div>
						{/if}

						{#if redeemCustomer.is_eligible}
							{#if redeemStep === 'found'}
								<div class="lr-actions">
									<button class="lr-btn lr-btn-success lr-btn-lg" on:click={selectRedeemFull}>
										{$t('coupon.loyaltyRedeemFull')}
										<span class="lr-btn-sub">({Number(redeemCustomer.available_points).toFixed(2)} {$t('coupon.loyaltyCouponCurrency')})</span>
									</button>
									<button class="lr-btn lr-btn-secondary lr-btn-lg" on:click={selectRedeemPartial}>
										{$t('coupon.loyaltyRedeemPartial')}
									</button>
								</div>
							{/if}

							{#if redeemStep === 'partial_input'}
								<div class="lr-partial-form">
									<label class="lr-label" for="partial-pts">{$t('coupon.loyaltyPartialLabel')}</label>
									<div class="lr-input-row">
										<div class="lr-input-wrap" style="flex:1">
											<span class="lr-input-icon">✏️</span>
											<input
												id="partial-pts"
												class="lr-input"
												type="number"
												min="1"
												max={redeemCustomer.available_points}
												placeholder={$t('coupon.loyaltyPartialPlaceholder')}
												bind:value={partialPoints}
												on:keydown={(e) => e.key === 'Enter' && confirmPartialPoints()}
											/>
										</div>
										<button class="lr-btn lr-btn-success" on:click={confirmPartialPoints}>
											{$t('coupon.loyaltyPartialConfirm')}
										</button>
									</div>
									<p class="lr-hint">
										{$t('coupon.loyaltyPartialMax')} {Number(redeemCustomer.available_points).toFixed(2)} {$t('coupon.loyaltyMinRedeemUnit')}
									</p>
									<button
										class="lr-btn lr-btn-ghost lr-btn-sm"
										on:click={() => (redeemStep = 'found')}
										style="margin-top:0.5rem"
									>
										{$t('coupon.loyaltyBack')}
									</button>
								</div>
							{/if}
						{:else}
							<div class="lr-warning-card">
								<div class="lr-warning-icon">⚠️</div>
								<div class="lr-warning-text">
									{$t('coupon.loyaltyNotEligible')}
									<small>{$t('coupon.loyaltyIneligibleMin')} {Number(redeemCustomer.min_redeem_points).toFixed(0)} {$t('coupon.loyaltyIneligiblePoints')} — {$t('coupon.loyaltyIneligibleAvail')} {Number(redeemCustomer.available_points).toFixed(2)} {$t('coupon.loyaltyIneligiblePoints')}</small>
								</div>
							</div>
						{/if}

						<button
							class="lr-btn lr-btn-ghost lr-btn-sm"
							on:click={resetRedeem}
							style="margin-top:1rem"
						>
							{$t('coupon.loyaltyNewSearch')}
						</button>
					</div>
				{/if}

				<!-- ── SENDING OTP ── -->
				{#if redeemStep === 'sending_otp'}
					<div class="lr-glass-card lr-loading-card">
						<div class="lr-spinner"></div>
						<p class="lr-loading-text">{$t('coupon.loyaltySendingOtp')}</p>
					</div>
				{/if}

				<!-- ── OTP ENTRY ── -->
				{#if redeemStep === 'otp_entry' || redeemStep === 'verifying'}
					<div class="lr-glass-card lr-otp-card">
						<span class="lr-otp-icon">📱</span>
						<h3 class="lr-otp-title">{$t('coupon.loyaltyOtpTitle')}</h3>
						<p class="lr-otp-desc">{$t('coupon.loyaltyOtpDesc')}</p>
						<div class="lr-otp-form">
							<label class="lr-label" for="otp-input">{$t('coupon.loyaltyOtpLabel')}</label>
							<input
								id="otp-input"
								class="lr-input lr-otp-input"
								type="text"
								maxlength="6"
								placeholder="------"
								bind:value={otpInput}
								on:keydown={(e) => e.key === 'Enter' && doConfirmOtp()}
								disabled={redeemStep === 'verifying'}
							/>
							{#if otpError}
								<div class="lr-error-card">{otpError}</div>
							{/if}
							<button
								class="lr-btn lr-btn-success lr-btn-full"
								on:click={doConfirmOtp}
								disabled={redeemStep === 'verifying'}
							>
								{#if redeemStep === 'verifying'}
									<span class="lr-btn-spinner"></span>
									{$t('coupon.loyaltyOtpVerifying')}
								{:else}
									{$t('coupon.loyaltyOtpConfirm')}
								{/if}
							</button>
							<button
								class="lr-btn lr-btn-ghost lr-btn-full lr-btn-sm"
								on:click={resetRedeem}
								disabled={redeemStep === 'verifying'}
							>
								{$t('coupon.loyaltyOtpCancel')}
							</button>
						</div>
					</div>
				{/if}

				<!-- ── SUCCESS ── -->
				{#if redeemStep === 'success' && successData}
					<div class="lr-glass-card lr-success-card">
						<span class="lr-success-confetti">🎉</span>
						<h3 class="lr-success-title">{$t('coupon.loyaltySuccessTitle')}</h3>

						<div class="lr-coupon-box">
							<div class="lr-coupon-label">{$t('coupon.loyaltyCouponCode')}</div>
							<div class="lr-coupon-code">{successData.coupon_code}</div>
							<div class="lr-coupon-divider"></div>
							<div class="lr-coupon-label">{$t('coupon.loyaltyCouponValue')}</div>
							<div class="lr-coupon-value">
								{Number(successData.coupon_value).toFixed(2)}
								<span class="lr-coupon-currency">{$t('coupon.loyaltyCouponCurrency')}</span>
							</div>
							<div class="lr-coupon-pts">
								{$t('coupon.loyaltyCouponPoints')} {Number(successData.points_redeemed).toFixed(2)} {$t('coupon.loyaltyMinRedeemUnit')}
							</div>
						</div>

						<div class="lr-success-actions">
							<button class="lr-btn lr-btn-primary lr-btn-lg" on:click={printCoupon}>
								{$t('coupon.loyaltyPrintCoupon')}
							</button>
							<button class="lr-btn lr-btn-ghost" on:click={resetRedeem}>
								{$t('coupon.loyaltyNewRedemption')}
							</button>
						</div>
					</div>
				{/if}
			</div>
		{/if}
	</main>
</div>
</div>

<style>
	/* ─── Wrapper + gradient background ────────────────── */
	.lr-wrap {
		position: relative;
		height: 100%;
		background: linear-gradient(135deg, #F8FAFC 0%, #EDE9FE 45%, #F0F9FF 100%);
		overflow: hidden;
	}

	/* ─── Animated background blobs ────────────────────── */
	.lr-blob {
		position: absolute;
		border-radius: 50%;
		filter: blur(70px);
		opacity: 0.3;
		animation: blob-float 9s ease-in-out infinite alternate;
		pointer-events: none;
		z-index: 0;
	}
	.lr-blob-1 {
		width: 320px; height: 320px;
		background: #A78BFA;
		top: -80px; right: -60px;
		animation-delay: 0s;
	}
	.lr-blob-2 {
		width: 220px; height: 220px;
		background: #F9A8D4;
		bottom: 8%; left: 3%;
		animation-delay: 2.5s;
	}
	.lr-blob-3 {
		width: 260px; height: 260px;
		background: #67E8F9;
		bottom: -60px; right: 28%;
		animation-delay: 5s;
		opacity: 0.18;
	}
	@keyframes blob-float {
		0%   { transform: translate(0, 0) scale(1); }
		100% { transform: translate(28px, -28px) scale(1.08); }
	}

	/* ─── Container ─────────────────────────────────────── */
	.lr-container {
		position: relative;
		z-index: 1;
		display: flex;
		height: 100%;
		font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
		color: #1E293B;
		direction: rtl;
		overflow: hidden;
	}

	/* ─── Glass Sidebar ─────────────────────────────────── */
	.lr-sidebar {
		width: 200px;
		min-width: 200px;
		background: rgba(255, 255, 255, 0.72);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border-left: 1px solid rgba(148, 163, 184, 0.22);
		display: flex;
		flex-direction: column;
		padding: 1.25rem 0.875rem;
		gap: 0.5rem;
		box-shadow: 4px 0 24px rgba(167, 139, 250, 0.07);
	}
	.lr-logo-wrap {
		text-align: center;
		padding-bottom: 1.25rem;
		border-bottom: 1px solid rgba(148, 163, 184, 0.18);
		margin-bottom: 0.75rem;
	}
	.lr-logo {
		width: 60px;
		height: auto;
		margin: 0 auto 0.5rem;
		display: block;
		border-radius: 12px;
		box-shadow: 0 4px 16px rgba(167, 139, 250, 0.22);
	}
	.lr-logo-placeholder {
		font-size: 2.5rem;
		margin-bottom: 0.5rem;
		filter: drop-shadow(0 2px 8px rgba(167, 139, 250, 0.4));
	}
	.lr-program-name {
		font-size: 0.95rem;
		font-weight: 700;
		color: #5B21B6;
	}
	.lr-program-sub {
		font-size: 0.7rem;
		color: #64748B;
		margin-top: 2px;
	}
	.lr-nav-items {
		display: flex;
		flex-direction: column;
		gap: 0.375rem;
	}
	.lr-nav-btn {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		padding: 0.7rem 0.875rem;
		border-radius: 12px;
		border: none;
		background: transparent;
		color: #64748B;
		font-size: 0.875rem;
		cursor: pointer;
		width: 100%;
		text-align: right;
		transition: all 0.2s ease;
		font-weight: 500;
	}
	.lr-nav-btn:hover {
		background: rgba(167, 139, 250, 0.12);
		color: #5B21B6;
		transform: translateX(-2px);
	}
	.lr-nav-btn.active {
		background: linear-gradient(135deg, #A78BFA 0%, #FF8A1F 100%);
		color: #fff;
		font-weight: 700;
		box-shadow: 0 4px 16px rgba(167, 139, 250, 0.35);
	}
	.lr-nav-icon { font-size: 1.1rem; }

	/* ─── Main ──────────────────────────────────────────── */
	.lr-main {
		flex: 1;
		overflow-y: auto;
		padding: 1.75rem;
		scrollbar-width: thin;
		scrollbar-color: rgba(167, 139, 250, 0.3) transparent;
	}

	/* ─── Panel ─────────────────────────────────────────── */
	.lr-panel { max-width: 620px; margin: 0 auto; }
	.lr-panel-header {
		display: flex;
		align-items: center;
		gap: 0.875rem;
		margin-bottom: 1.5rem;
	}
	.lr-panel-icon-wrap {
		width: 48px;
		height: 48px;
		border-radius: 14px;
		background: linear-gradient(135deg, rgba(167, 139, 250, 0.18), rgba(167, 139, 250, 0.04));
		border: 1px solid rgba(167, 139, 250, 0.22);
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1.4rem;
		flex-shrink: 0;
		transition: transform 0.2s;
	}
	.lr-panel-icon-wrap:hover { transform: scale(1.05); }
	.lr-icon-orange {
		background: linear-gradient(135deg, rgba(255, 138, 31, 0.18), rgba(255, 138, 31, 0.04));
		border-color: rgba(255, 138, 31, 0.22);
	}
	.lr-panel-icon { line-height: 1; }
	.lr-panel-title {
		font-size: 1.3rem;
		font-weight: 700;
		color: #1E293B;
		margin: 0 0 0.15rem;
	}
	.lr-panel-sub {
		font-size: 0.82rem;
		color: #64748B;
		margin: 0;
	}

	/* ─── Glass Cards ───────────────────────────────────── */
	.lr-glass-card {
		background: rgba(255, 255, 255, 0.70);
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(148, 163, 184, 0.25);
		border-radius: 20px;
		padding: 1.5rem;
		box-shadow:
			0 8px 32px rgba(167, 139, 250, 0.09),
			0 1px 0 rgba(255, 255, 255, 0.85) inset;
		margin-bottom: 1rem;
		transition: box-shadow 0.25s ease, transform 0.25s ease;
	}
	.lr-glass-card:hover {
		box-shadow:
			0 14px 40px rgba(167, 139, 250, 0.15),
			0 1px 0 rgba(255, 255, 255, 0.85) inset;
		transform: translateY(-2px);
	}

	/* ─── Form ──────────────────────────────────────────── */
	.lr-label {
		display: block;
		font-size: 0.82rem;
		color: #64748B;
		margin-bottom: 0.5rem;
		font-weight: 500;
	}
	.lr-input-row { display: flex; gap: 0.625rem; }
	.lr-input-wrap { position: relative; flex: 1; }
	.lr-suggestions {
		position: absolute;
		top: calc(100% + 4px);
		left: 0; right: 0;
		background: rgba(255, 255, 255, 0.98);
		border: 1.5px solid rgba(167, 139, 250, 0.3);
		border-radius: 12px;
		box-shadow: 0 8px 28px rgba(124, 58, 237, 0.13);
		z-index: 200;
		max-height: 230px;
		overflow-y: auto;
		backdrop-filter: blur(12px);
	}
	.lr-suggestion-item {
		display: flex;
		align-items: center;
		gap: 0.625rem;
		width: 100%;
		padding: 0.6rem 0.875rem;
		background: none;
		border: none;
		border-bottom: 1px solid rgba(148, 163, 184, 0.12);
		cursor: pointer;
		text-align: right;
		transition: background 0.15s;
		direction: rtl;
	}
	.lr-suggestion-item:last-child { border-bottom: none; }
	.lr-suggestion-item:hover { background: rgba(167, 139, 250, 0.08); }
	.lr-sug-name {
		font-weight: 600;
		color: #1e293b;
		flex: 1;
		font-size: 0.9rem;
	}
	.lr-sug-phone {
		color: #64748b;
		font-size: 0.82rem;
		font-family: monospace;
		direction: ltr;
	}
	.lr-sug-tier {
		font-size: 0.72rem;
		background: rgba(167, 139, 250, 0.15);
		color: #7c3aed;
		padding: 2px 8px;
		border-radius: 20px;
		white-space: nowrap;
	}
	.lr-input-icon {
		position: absolute;
		right: 0.875rem;
		top: 50%;
		transform: translateY(-50%);
		font-size: 0.9rem;
		pointer-events: none;
		display: flex;
		align-items: center;
	}
	.lr-input-icon-wa { line-height: 0; }
	.lr-input {
		width: 100%;
		background: rgba(255, 255, 255, 0.85);
		border: 1.5px solid rgba(148, 163, 184, 0.32);
		border-radius: 12px;
		color: #1E293B;
		padding: 0.7rem 2.5rem 0.7rem 0.875rem;
		font-size: 0.95rem;
		outline: none;
		direction: ltr;
		text-align: left;
		transition: border-color 0.2s, box-shadow 0.2s;
		font-family: inherit;
	}
	.lr-input:focus {
		border-color: #A78BFA;
		box-shadow: 0 0 0 3px rgba(167, 139, 250, 0.14);
	}
	.lr-input:disabled { opacity: 0.5; cursor: not-allowed; }
	.lr-otp-input {
		font-size: 2rem;
		letter-spacing: 0.5rem;
		text-align: center;
		direction: ltr;
		padding: 0.75rem;
		font-family: monospace;
	}
	.lr-hint {
		font-size: 0.78rem;
		color: #64748B;
		margin-top: 0.4rem;
	}

	/* ─── Error / Warning cards ─────────────────────────── */
	.lr-error-card {
		background: rgba(254, 226, 226, 0.7);
		border: 1px solid rgba(252, 165, 165, 0.45);
		border-radius: 10px;
		padding: 0.7rem 1rem;
		color: #991B1B;
		font-size: 0.82rem;
		margin-top: 0.75rem;
		backdrop-filter: blur(8px);
	}
	.lr-warning-card {
		display: flex;
		align-items: flex-start;
		gap: 0.75rem;
		background: rgba(255, 237, 213, 0.75);
		border: 1px solid rgba(253, 186, 116, 0.45);
		border-radius: 14px;
		padding: 1rem 1.25rem;
		color: #92400E;
		font-size: 0.875rem;
		margin: 0.75rem 0;
	}
	.lr-warning-icon { font-size: 1.25rem; flex-shrink: 0; margin-top: 1px; }
	.lr-warning-text small {
		display: block;
		margin-top: 0.3rem;
		color: #B45309;
		font-size: 0.78rem;
	}

	/* ─── Buttons ───────────────────────────────────────── */
	.lr-btn {
		padding: 0.6rem 1.25rem;
		border-radius: 12px;
		border: none;
		font-size: 0.875rem;
		cursor: pointer;
		font-weight: 600;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		transition: all 0.2s ease;
		white-space: nowrap;
		font-family: inherit;
	}
	.lr-btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none !important; box-shadow: none !important; }
	.lr-btn-primary {
		background: linear-gradient(135deg, #A78BFA, #8B5CF6);
		color: #fff;
		box-shadow: 0 4px 14px rgba(167, 139, 250, 0.38);
	}
	.lr-btn-primary:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 7px 20px rgba(167, 139, 250, 0.5);
	}
	.lr-btn-success {
		background: linear-gradient(135deg, #22C55E, #16A34A);
		color: #fff;
		box-shadow: 0 4px 14px rgba(34, 197, 94, 0.32);
	}
	.lr-btn-success:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 7px 20px rgba(34, 197, 94, 0.42);
	}
	.lr-btn-secondary {
		background: rgba(255, 138, 31, 0.1);
		color: #C2410C;
		border: 1.5px solid rgba(255, 138, 31, 0.28);
	}
	.lr-btn-secondary:hover:not(:disabled) {
		background: rgba(255, 138, 31, 0.18);
		transform: translateY(-2px);
	}
	.lr-btn-ghost {
		background: rgba(255, 255, 255, 0.65);
		color: #64748B;
		border: 1px solid rgba(148, 163, 184, 0.32);
		backdrop-filter: blur(8px);
	}
	.lr-btn-ghost:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.95);
		color: #1E293B;
		transform: translateY(-1px);
	}
	.lr-btn-lg {
		padding: 0.875rem 1.5rem;
		font-size: 0.95rem;
		flex-direction: column;
		gap: 0.2rem;
		border-radius: 14px;
	}
	.lr-btn-sm { font-size: 0.78rem; padding: 0.4rem 0.875rem; border-radius: 8px; }
	.lr-btn-sub { font-size: 0.75rem; font-weight: 400; opacity: 0.85; }
	.lr-btn-full { width: 100%; margin-top: 0.75rem; }
	.lr-btn-spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.4);
		border-top-color: #fff;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}

	/* ─── Result card ───────────────────────────────────── */
	.lr-result-card { padding: 1.5rem; }
	.lr-result-header {
		display: flex;
		align-items: center;
		gap: 0.875rem;
		margin-bottom: 1.25rem;
		flex-wrap: wrap;
	}
	.lr-avatar {
		width: 48px;
		height: 48px;
		border-radius: 50%;
		background: linear-gradient(135deg, #A78BFA, #8B5CF6);
		color: #fff;
		font-size: 1.25rem;
		font-weight: 700;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		box-shadow: 0 4px 12px rgba(167, 139, 250, 0.38);
	}
	.lr-customer-info { flex: 1; }
	.lr-result-name { font-size: 1rem; font-weight: 700; color: #1E293B; }
	.lr-result-phone { font-size: 0.8rem; color: #64748B; direction: ltr; margin-top: 1px; }

	/* ─── Tier Badge ────────────────────────────────────── */
	.lr-tier-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.875rem;
		border-radius: 20px;
		font-size: 0.78rem;
		font-weight: 700;
		white-space: nowrap;
	}
	.lr-tier-bronze  { background: linear-gradient(135deg,#FEF3C7,#FDE68A); color:#92400E; border:1px solid rgba(217,119,6,0.22); }
	.lr-tier-silver  { background: linear-gradient(135deg,#F1F5F9,#E2E8F0); color:#475569; border:1px solid rgba(148,163,184,0.38); }
	.lr-tier-gold    { background: linear-gradient(135deg,#FEF9C3,#FDE047); color:#713F12; border:1px solid rgba(234,179,8,0.32); }
	.lr-tier-platinum{ background: linear-gradient(135deg,#EDE9FE,#C4B5FD); color:#4C1D95; border:1px solid rgba(139,92,246,0.28); }
	.lr-tier-diamond { background: linear-gradient(135deg,#E0F2FE,#BAE6FD); color:#0C4A6E; border:1px solid rgba(14,165,233,0.28); }
	.lr-tier-crown   { background: linear-gradient(135deg,#FDF4FF,#E9D5FF); color:#581C87; border:1px solid rgba(168,85,247,0.32); }
	.lr-tier-icon { font-size: 0.9rem; }
	.lr-tier-ar { opacity: 0.7; font-weight: 400; }

	/* ─── Hero Balance ──────────────────────────────────── */
	.lr-hero-balance {
		background: linear-gradient(135deg, rgba(34,197,94,0.09), rgba(34,197,94,0.04));
		border: 1.5px solid rgba(34, 197, 94, 0.2);
		border-radius: 18px;
		padding: 1.5rem 1.25rem;
		text-align: center;
		margin-bottom: 1rem;
		position: relative;
		overflow: hidden;
	}
	.lr-hero-balance::before {
		content: '';
		position: absolute;
		top: -40px; right: -40px;
		width: 120px; height: 120px;
		background: radial-gradient(circle, rgba(34,197,94,0.14) 0%, transparent 70%);
		pointer-events: none;
	}
	.lr-hero-label {
		font-size: 0.75rem;
		color: #64748B;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin-bottom: 0.25rem;
	}
	.lr-hero-amount {
		font-size: 3rem;
		font-weight: 800;
		color: #16A34A;
		line-height: 1;
		margin: 0.25rem 0;
		letter-spacing: -1px;
	}
	.lr-hero-sub { font-size: 0.78rem; color: #64748B; margin-top: 0.25rem; }
	.lr-eligible-pill {
		display: inline-block;
		margin-top: 0.75rem;
		padding: 0.3rem 1rem;
		border-radius: 20px;
		font-size: 0.8rem;
		font-weight: 700;
		background: rgba(252,165,165,0.28);
		color: #B91C1C;
		border: 1px solid rgba(252,165,165,0.45);
	}
	.lr-eligible-pill.eligible {
		background: rgba(34,197,94,0.14);
		color: #15803D;
		border-color: rgba(34,197,94,0.28);
	}

	/* ─── Stats Grid ────────────────────────────────────── */
	.lr-stats-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 1rem;
	}
	.lr-stats-grid > :last-child:nth-child(odd) { grid-column: 1 / -1; }
	.lr-stat-card {
		background: rgba(255, 255, 255, 0.65);
		border-radius: 12px;
		padding: 0.875rem;
		text-align: center;
		border: 1px solid rgba(148, 163, 184, 0.18);
		transition: transform 0.2s;
	}
	.lr-stat-card:hover { transform: translateY(-2px); }
	.lr-stat-label { font-size: 0.72rem; color: #64748B; margin-bottom: 0.3rem; font-weight: 500; }
	.lr-stat-value { font-size: 1.2rem; font-weight: 700; }
	.lr-stat-value small { font-size: 0.72rem; font-weight: 400; color: #64748B; }
	.lr-stat-blue   .lr-stat-value { color: #2563EB; }
	.lr-stat-orange .lr-stat-value { color: #EA580C; }
	.lr-stat-muted  .lr-stat-value { color: #64748B; }

	/* ─── Actions ───────────────────────────────────────── */
	.lr-actions { display: flex; gap: 0.75rem; margin-top: 1rem; flex-wrap: wrap; }
	.lr-partial-form {
		background: rgba(255, 255, 255, 0.55);
		border: 1px solid rgba(148, 163, 184, 0.2);
		border-radius: 14px;
		padding: 1rem;
		margin-top: 1rem;
	}

	/* ─── Loading ───────────────────────────────────────── */
	.lr-loading-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.25rem;
		padding: 3rem;
		text-align: center;
	}
	.lr-loading-text { color: #64748B; font-size: 0.9rem; }
	.lr-spinner {
		width: 44px; height: 44px;
		border: 3px solid rgba(167, 139, 250, 0.18);
		border-top-color: #A78BFA;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	/* ─── OTP Card ──────────────────────────────────────── */
	.lr-otp-card { text-align: center; padding: 2rem 1.5rem; }
	.lr-otp-icon {
		font-size: 3.5rem;
		display: block;
		margin-bottom: 0.75rem;
		filter: drop-shadow(0 4px 8px rgba(167,139,250,0.28));
	}
	.lr-otp-title { font-size: 1.2rem; font-weight: 700; color: #1E293B; margin-bottom: 0.5rem; }
	.lr-otp-desc { font-size: 0.875rem; color: #64748B; line-height: 1.6; margin: 0; }
	.lr-otp-form { max-width: 280px; margin: 1.5rem auto 0; text-align: right; }

	/* ─── Success Card ──────────────────────────────────── */
	.lr-success-card { text-align: center; padding: 2rem 1.5rem; }
	.lr-success-confetti {
		font-size: 3.5rem;
		display: block;
		margin-bottom: 0.5rem;
		animation: pop 0.5s ease;
	}
	@keyframes pop {
		0%   { transform: scale(0.5); opacity: 0; }
		70%  { transform: scale(1.15); }
		100% { transform: scale(1); opacity: 1; }
	}
	.lr-success-title { font-size: 1.3rem; font-weight: 700; color: #15803D; margin-bottom: 1.25rem; }
	.lr-coupon-box {
		background: linear-gradient(135deg, rgba(167,139,250,0.06), rgba(255,138,31,0.04));
		border: 2px dashed rgba(167, 139, 250, 0.32);
		border-radius: 18px;
		padding: 1.5rem;
		margin-bottom: 1.5rem;
	}
	.lr-coupon-label {
		font-size: 0.72rem;
		color: #64748B;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		margin-bottom: 0.35rem;
		font-weight: 500;
	}
	.lr-coupon-code {
		font-size: 1.7rem;
		font-weight: 800;
		color: #1E293B;
		letter-spacing: 3px;
		font-family: monospace;
	}
	.lr-coupon-divider {
		border: none;
		border-top: 1px dashed rgba(148, 163, 184, 0.38);
		margin: 0.875rem 0;
	}
	.lr-coupon-value { font-size: 2.25rem; font-weight: 800; color: #15803D; line-height: 1; }
	.lr-coupon-currency { font-size: 1rem; color: #64748B; font-weight: 500; }
	.lr-coupon-pts { font-size: 0.78rem; color: #64748B; margin-top: 0.5rem; }
	.lr-success-actions { display: flex; gap: 0.75rem; justify-content: center; flex-wrap: wrap; }
</style>
