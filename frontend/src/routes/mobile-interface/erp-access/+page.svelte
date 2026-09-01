<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';

	interface BranchCredential {
		branch_id: number;
		branch_name: string;
		branch_location: string;
		erp_username: string | null;
		erp_login_password: string | null;
		erp_password: string | null;
	}

	// Login shows two codes at once (username + its own login password);
	// Authorization shows one (its own, separate password). Each slot keeps
	// its own generated code so both can render simultaneously on Login.
	type Slot = 'username' | 'password';

	let isLoading = true;
	let loadError = false;
	let activeTab: 'login' | 'authorization' = 'login';

	let credentials: BranchCredential[] = [];
	let defaultBranchId: number | null = null;
	// Temporary — changing this never writes back to hr_employee_master.
	let selectedBranchId: number | null = null;

	let QRCode: any = null;
	let JsBarcode: any = null;

	let usernameQrDataUrl = '';
	let usernameQrGenerating = false;
	let usernameBarcodeCanvas: HTMLCanvasElement;
	let usernameBarcodeError = '';

	let passwordQrDataUrl = '';
	let passwordQrGenerating = false;
	let passwordBarcodeCanvas: HTMLCanvasElement;
	let passwordBarcodeError = '';

	// Which visual format to render both codes as.
	let codeType: 'qr' | 'barcode' = 'qr';
	// Login tab shows one code at a time — this switches which.
	let loginField: 'username' | 'password' = 'username';

	$: isArabic = $currentLocale === 'ar';
	$: selectedCredential = credentials.find((c) => c.branch_id === selectedBranchId) || null;
	$: usernameValue = activeTab === 'login' ? selectedCredential?.erp_username : null;
	$: passwordValue = activeTab === 'login' ? selectedCredential?.erp_login_password : selectedCredential?.erp_password;
	// Referencing the values/codeType/loginField here (rather than inside the
	// async fns) is what makes Svelte re-run these blocks whenever any of
	// them change — loginField matters for barcode mode specifically, since
	// the canvas only exists in the DOM once its panel becomes visible.
	$: { usernameValue; codeType; loginField; regenerateCode('username'); }
	$: { passwordValue; codeType; loginField; regenerateCode('password'); }

	onMount(async () => {
		try {
			const mod = await import('qrcode');
			QRCode = mod.default || mod;
		} catch (e) {
			console.error('QRCode library load error:', e);
		}
		try {
			const mod = await import('jsbarcode');
			JsBarcode = mod.default || mod;
		} catch (e) {
			console.error('JsBarcode library load error:', e);
		}
		await loadCredentials();
	});

	async function loadCredentials() {
		const userId = $currentUser?.id;
		if (!userId) {
			loadError = true;
			isLoading = false;
			return;
		}

		try {
			const [masterRes, credsRes] = await Promise.all([
				supabase
					.from('hr_employee_master')
					.select('current_branch_id')
					.eq('user_id', userId)
					.maybeSingle(),
				supabase
					.from('user_erp_credentials')
					.select('aqura_branch_id, erp_username, erp_login_password, erp_password, branches!user_erp_credentials_aqura_branch_id_fkey(name_en, name_ar, location_en, location_ar)')
					.eq('user_id', userId)
			]);

			if (credsRes.error) throw credsRes.error;

			defaultBranchId = masterRes.data?.current_branch_id ?? null;
			credentials = (credsRes.data || []).map((row: any) => ({
				branch_id: row.aqura_branch_id,
				branch_name: (isArabic ? row.branches?.name_ar : row.branches?.name_en) || `Branch ${row.aqura_branch_id}`,
				branch_location: (isArabic ? row.branches?.location_ar : row.branches?.location_en) || '',
				erp_username: row.erp_username,
				erp_login_password: row.erp_login_password,
				erp_password: row.erp_password
			}));

			// Default to the employee's actual branch when credentials exist for
			// it; otherwise fall back to whichever branch does have credentials.
			selectedBranchId = credentials.some((c) => c.branch_id === defaultBranchId)
				? defaultBranchId
				: credentials[0]?.branch_id ?? null;
		} catch (error) {
			console.error('Failed to load ERP credentials:', error);
			loadError = true;
		} finally {
			isLoading = false;
		}
	}

	async function regenerateCode(slot: Slot) {
		const value = slot === 'username' ? usernameValue : passwordValue;
		if (slot === 'username') usernameBarcodeError = ''; else passwordBarcodeError = '';
		if (!value) {
			if (slot === 'username') usernameQrDataUrl = ''; else passwordQrDataUrl = '';
			return;
		}
		if (codeType === 'qr') {
			await regenerateQr(slot, value);
		} else {
			await renderBarcode(slot, value);
		}
	}

	async function regenerateQr(slot: Slot, value: string) {
		if (!QRCode) return;
		if (slot === 'username') usernameQrGenerating = true; else passwordQrGenerating = true;
		try {
			const url = await QRCode.toDataURL(value, {
				width: 220,
				margin: 2,
				color: { dark: '#1e293b', light: '#ffffff' }
			});
			if (slot === 'username') usernameQrDataUrl = url; else passwordQrDataUrl = url;
		} catch (e) {
			console.error('QR generation error:', e);
			if (slot === 'username') usernameQrDataUrl = ''; else passwordQrDataUrl = '';
		} finally {
			if (slot === 'username') usernameQrGenerating = false; else passwordQrGenerating = false;
		}
	}

	async function renderBarcode(slot: Slot, value: string) {
		if (!JsBarcode) return;
		// The <canvas> only exists once the {#if codeType === 'barcode'} branch
		// has rendered — wait for that DOM update before drawing into it.
		await tick();
		const canvas = slot === 'username' ? usernameBarcodeCanvas : passwordBarcodeCanvas;
		if (!canvas) return;
		try {
			JsBarcode(canvas, value, {
				format: 'CODE128',
				width: 2,
				height: 90,
				displayValue: false,
				margin: 8
			});
		} catch (e) {
			console.error('Barcode generation error:', e);
			const msg = isArabic ? 'تعذر إنشاء الباركود لهذه القيمة' : 'Could not generate a barcode for this value.';
			if (slot === 'username') usernameBarcodeError = msg; else passwordBarcodeError = msg;
		}
	}
</script>

<svelte:head>
	<title>{isArabic ? 'دخول ERP' : 'ERP Access'} | Aqura</title>
</svelte:head>

<section class="erp-access-page" dir={isArabic ? 'rtl' : 'ltr'}>
	<div class="erp-access-card">
		<div class="erp-access-icon" aria-hidden="true">
			<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
				<path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/>
			</svg>
		</div>

		{#if isLoading}
			<div class="loading-row" aria-live="polite">
				<span class="spinner"></span>
				<span>{isArabic ? 'جارٍ التحميل...' : 'Loading...'}</span>
			</div>
		{:else if loadError}
			<p class="error-message" role="alert">{isArabic ? 'تعذر تحميل بيانات ERP.' : 'Unable to load ERP credentials.'}</p>
		{:else if credentials.length === 0}
			<div class="empty-state">
				<p>{isArabic ? 'لم يتم ربط أي بيانات دخول ERP بحسابك بعد. يرجى التواصل مع المسؤول.' : 'No ERP credentials are linked to your account yet. Please contact your administrator.'}</p>
			</div>
		{:else}
			<!-- ── Tab Bar ─────────────────────────────────────────────── -->
			<div class="tab-bar">
				<button class="tab-btn" class:active={activeTab === 'login'} on:click={() => activeTab = 'login'}>
					{isArabic ? 'تسجيل الدخول' : 'Login'}
				</button>
				<button class="tab-btn" class:active={activeTab === 'authorization'} on:click={() => activeTab = 'authorization'}>
					{isArabic ? 'التفويض' : 'Authorization'}
				</button>
			</div>

			<!-- ── Branch selector (temporary — does not change your default branch) ── -->
			{#if credentials.length > 1}
				<div class="branch-select-wrap">
					<label for="erp-access-branch">{isArabic ? 'الفرع' : 'Branch'}</label>
					<select id="erp-access-branch" bind:value={selectedBranchId}>
						{#each credentials as c}
							<option value={c.branch_id}>
								{c.branch_name}{c.branch_location ? ` — ${c.branch_location}` : ''}{c.branch_id === defaultBranchId ? (isArabic ? ' (الافتراضي)' : ' (default)') : ''}
							</option>
						{/each}
					</select>
				</div>
			{:else}
				<div class="branch-readonly">
					<span class="branch-readonly-name">{credentials[0].branch_name}</span>
					{#if credentials[0].branch_location}
						<span class="branch-readonly-location">{credentials[0].branch_location}</span>
					{/if}
				</div>
			{/if}

			<!-- ── Code type toggle ────────────────────────────────────── -->
			{#if usernameValue || passwordValue}
				<div class="code-type-toggle">
					<button class="code-type-btn" class:active={codeType === 'qr'} on:click={() => codeType = 'qr'}>
						{isArabic ? 'رمز QR' : 'QR Code'}
					</button>
					<button class="code-type-btn" class:active={codeType === 'barcode'} on:click={() => codeType = 'barcode'}>
						{isArabic ? 'باركود' : 'Barcode'}
					</button>
				</div>
			{/if}

			<!-- ── Username code ────────────────────────────────────────── -->
			{#if activeTab === 'login' && loginField === 'username'}
				<p class="code-label">{isArabic ? 'اسم المستخدم' : 'Username'}</p>
				<div class="qr-panel">
					{#if !usernameValue}
						<p class="qr-empty">{isArabic ? 'لا يوجد اسم مستخدم ERP محفوظ لهذا الفرع.' : 'No ERP username saved for this branch.'}</p>
					{:else if codeType === 'qr'}
						{#if usernameQrDataUrl}
							<img class="qr-image" src={usernameQrDataUrl} alt={isArabic ? 'رمز اسم مستخدم ERP' : 'ERP username QR code'} />
						{:else if usernameQrGenerating}
							<span class="spinner"></span>
						{/if}
					{:else}
						<canvas class="barcode-image" bind:this={usernameBarcodeCanvas}></canvas>
						{#if usernameBarcodeError}
							<p class="qr-empty">{usernameBarcodeError}</p>
						{/if}
					{/if}
				</div>
			{/if}

			<!-- ── Password code — login password on Login (only when that
			     switch is selected), authorization password on Authorization
			     (always, it's the only field there) ──────────────────────── -->
			{#if activeTab === 'authorization' || (activeTab === 'login' && loginField === 'password')}
				<p class="code-label">
					{activeTab === 'login' ? (isArabic ? 'كلمة مرور الدخول' : 'Login Password') : (isArabic ? 'كلمة مرور التفويض' : 'Authorization Password')}
				</p>
				<div class="qr-panel">
					{#if !passwordValue}
						<p class="qr-empty">
							{activeTab === 'login'
								? (isArabic ? 'لا توجد كلمة مرور دخول محفوظة لهذا الفرع.' : 'No login password saved for this branch.')
								: (isArabic ? 'لا توجد كلمة مرور تفويض محفوظة لهذا الفرع.' : 'No authorization password saved for this branch.')}
						</p>
					{:else if codeType === 'qr'}
						{#if passwordQrDataUrl}
							<img class="qr-image" src={passwordQrDataUrl} alt={activeTab === 'login' ? (isArabic ? 'رمز كلمة مرور الدخول' : 'Login password QR code') : (isArabic ? 'رمز كلمة مرور التفويض' : 'Authorization password QR code')} />
						{:else if passwordQrGenerating}
							<span class="spinner"></span>
						{/if}
					{:else}
						<canvas class="barcode-image" bind:this={passwordBarcodeCanvas}></canvas>
						{#if passwordBarcodeError}
							<p class="qr-empty">{passwordBarcodeError}</p>
						{/if}
					{/if}
				</div>
			{/if}

			<!-- ── Username / Password switch (Login tab only — Authorization
			     only ever has the one password) ──────────────────────── -->
			{#if activeTab === 'login'}
				<div class="code-type-toggle">
					<button class="code-type-btn" class:active={loginField === 'username'} on:click={() => loginField = 'username'}>
						{isArabic ? 'اسم المستخدم' : 'Username'}
					</button>
					<button class="code-type-btn" class:active={loginField === 'password'} on:click={() => loginField = 'password'}>
						{isArabic ? 'كلمة مرور الدخول' : 'Login Password'}
					</button>
				</div>
			{/if}
		{/if}
	</div>
</section>

<style>
	.erp-access-page {
		min-height: calc(100vh - 138px);
		padding: 20px 16px 96px;
		background: var(--mobile-bg, #f3f6fb);
	}

	.erp-access-card {
		max-width: 560px;
		margin: 0 auto;
		padding: 28px 20px;
		background: var(--mobile-card-bg, #fff);
		border: 1px solid var(--mobile-border, #e5e7eb);
		border-radius: 20px;
		box-shadow: 0 10px 28px rgb(15 23 42 / 8%);
	}

	.erp-access-icon {
		display: grid;
		place-items: center;
		width: 64px;
		height: 64px;
		margin: 0 auto 24px;
		color: var(--mobile-primary, #2563eb);
		background: color-mix(in srgb, var(--mobile-primary, #2563eb) 12%, white);
		border-radius: 50%;
	}

	.loading-row { display: flex; align-items: center; justify-content: center; gap: 10px; min-height: 124px; color: var(--mobile-text-secondary, #64748b); }
	.spinner { width: 20px; height: 20px; border: 2px solid #dbeafe; border-top-color: var(--mobile-primary, #2563eb); border-radius: 50%; animation: spin .7s linear infinite; }
	.error-message { margin: 0; padding: 11px 12px; color: #b91c1c; background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px; font-size: .88rem; }
	@keyframes spin { to { transform: rotate(360deg); } }

	.empty-state { padding: 20px 4px; text-align: center; color: var(--mobile-text-secondary, #64748b); font-size: .9rem; line-height: 1.6; }

	.tab-bar {
		display: flex;
		gap: 6px;
		padding: 4px;
		margin-bottom: 18px;
		background: var(--mobile-input-bg, #f1f5f9);
		border-radius: 12px;
	}

	.tab-btn {
		flex: 1;
		padding: 10px 12px;
		border: none;
		border-radius: 9px;
		background: transparent;
		color: var(--mobile-text-secondary, #64748b);
		font: inherit;
		font-weight: 600;
		font-size: .88rem;
		cursor: pointer;
		transition: all .15s ease;
	}

	.tab-btn.active {
		background: var(--mobile-card-bg, #fff);
		color: var(--mobile-primary, #2563eb);
		box-shadow: 0 2px 8px rgb(15 23 42 / 10%);
	}

	.branch-select-wrap { margin-bottom: 18px; }
	.branch-select-wrap label { display: block; margin-bottom: 8px; color: var(--mobile-text, #334155); font-size: .86rem; font-weight: 700; }
	.branch-select-wrap select {
		box-sizing: border-box;
		width: 100%;
		min-height: 48px;
		padding: 10px 14px;
		color: var(--mobile-text, #172033);
		background: var(--mobile-input-bg, #f8fafc);
		border: 1px solid var(--mobile-border, #dbe2ea);
		border-radius: 12px;
		font: inherit;
		font-weight: 500;
	}

	.branch-readonly {
		display: flex;
		flex-direction: column;
		gap: 2px;
		margin: 0 0 18px;
		padding: 10px 14px;
		background: var(--mobile-input-bg, #f8fafc);
		border: 1px solid var(--mobile-border, #dbe2ea);
		border-radius: 12px;
		text-align: center;
	}

	.branch-readonly-name {
		color: var(--mobile-text, #334155);
		font-size: .88rem;
		font-weight: 600;
	}

	.branch-readonly-location {
		color: var(--mobile-text-secondary, #64748b);
		font-size: .78rem;
	}

	.code-type-toggle {
		display: flex;
		gap: 6px;
		padding: 4px;
		margin-bottom: 14px;
		background: var(--mobile-input-bg, #f1f5f9);
		border-radius: 10px;
	}

	.code-type-btn {
		flex: 1;
		padding: 8px 10px;
		border: none;
		border-radius: 7px;
		background: transparent;
		color: var(--mobile-text-secondary, #64748b);
		font: inherit;
		font-weight: 600;
		font-size: .82rem;
		cursor: pointer;
		transition: all .15s ease;
	}

	.code-type-btn.active {
		background: var(--mobile-card-bg, #fff);
		color: var(--mobile-primary, #2563eb);
		box-shadow: 0 2px 6px rgb(15 23 42 / 8%);
	}

	.code-label {
		margin: 0 0 8px;
		color: var(--mobile-text, #334155);
		font-size: .82rem;
		font-weight: 700;
		text-align: center;
	}

	.qr-panel {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 12px;
		min-height: 200px;
		margin-bottom: 18px;
		padding: 20px 12px;
		background: var(--mobile-input-bg, #f8fafc);
		border: 1px solid var(--mobile-border, #dbe2ea);
		border-radius: 16px;
	}

	.qr-panel:last-child {
		margin-bottom: 0;
	}

	.qr-image {
		width: 200px;
		height: 200px;
		border-radius: 10px;
	}

	.barcode-image {
		max-width: 100%;
		background: #ffffff;
		border-radius: 10px;
	}

	.qr-empty {
		margin: 0;
		color: var(--mobile-text-secondary, #64748b);
		font-size: .85rem;
		text-align: center;
	}

	@media (max-width: 380px) {
		.erp-access-page { padding-inline: 12px; }
		.erp-access-card { padding-inline: 16px; }
	}
</style>
