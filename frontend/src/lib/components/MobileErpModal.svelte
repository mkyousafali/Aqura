<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { localeData } from '$lib/i18n';
	import QRCode from 'qrcode';

	// ── Props ──────────────────────────────────────────────────
	export let userId: string;
	export let onClose: () => void;

	// ── Types ─────────────────────────────────────────────────
	interface ErpCredential {
		id: string;
		branchId: number;
		branchName: string;
		erpUsername: string;
		erpPassword: string;
	}

	// ── State ─────────────────────────────────────────────────
	let credentials: ErpCredential[] = [];
	let loading = true;
	let loadError = '';

	// View: 'list' (branch selector) | 'qr' (QR display)
	let view: 'list' | 'qr' = 'list';
	let selectedCredential: ErpCredential | null = null;
	let qrDataUrl = '';
	let qrLoading = false;
	let qrError = '';

	// ── Translations helper ───────────────────────────────────
	function t(key: string): string {
		const keys = key.split('.');
		let value: any = $localeData.translations;
		for (const k of keys) {
			if (value && typeof value === 'object' && k in value) {
				value = value[k];
			} else {
				return key;
			}
		}
		return typeof value === 'string' ? value : key;
	}

	$: isAr = $localeData.code === 'ar';

	// ── QR payload builder ────────────────────────────────────
	/**
	 * Build keyboard-wedge QR payload.
	 * Format: trimmedUsername + TAB (0x09) + password + CR (0x0D)
	 *
	 * Examples:
	 *   buildErpQrPayload('user1', 'pass!')  → 'user1\tpass!\r'
	 *   buildErpQrPayload('  john  ', 'abc') → 'john\tabc\r'
	 *   buildErpQrPayload('u', 'p\t')        → [FLAG: password contains Tab]
	 *
	 * SECURITY: password is never logged or sent to third-party services.
	 */
	function buildErpQrPayload(username: string, password: string): string {
		return username.trim() + '\t' + password + '\r';
	}

	// ── Load credentials ──────────────────────────────────────
	onMount(async () => {
		await loadCredentials();
	});

	async function loadCredentials() {
		loading = true;
		loadError = '';
		try {
			const { data, error } = await supabase
				.from('user_erp_credentials')
				.select(`
					id,
					branch_id,
					erp_username,
					erp_password,
					branches!inner(id, name_en, name_ar)
				`)
				.eq('user_id', userId);

			if (error) throw error;

			credentials = (data || []).map((row: any) => ({
				id: row.id,
				branchId: row.branch_id,
				branchName: isAr
					? (row.branches?.name_ar || row.branches?.name_en || `Branch ${row.branch_id}`)
					: (row.branches?.name_en || `Branch ${row.branch_id}`),
				erpUsername: row.erp_username,
				erpPassword: row.erp_password
			}));

			// If exactly one credential, skip list and go straight to QR
			if (credentials.length === 1) {
				await selectCredential(credentials[0]);
			}
		} catch (err: any) {
			loadError = err.message || 'Failed to load credentials';
		} finally {
			loading = false;
		}
	}

	// ── QR generation ─────────────────────────────────────────
	async function selectCredential(cred: ErpCredential) {
		selectedCredential = cred;
		view = 'qr';
		qrDataUrl = '';
		qrError = '';
		qrLoading = true;
		try {
			const payload = buildErpQrPayload(cred.erpUsername, cred.erpPassword);
			// EC level M, generous quiet zone — password never leaves the client
			qrDataUrl = await QRCode.toDataURL(payload, {
				errorCorrectionLevel: 'M',
				margin: 2,
				width: 280,
				color: { dark: '#1e293b', light: '#ffffff' }
			});
		} catch (err: any) {
			console.error('QR generation error (no credential values logged)');
			qrError = 'Failed to generate QR code.';
		} finally {
			qrLoading = false;
		}
	}

	function goBackToList() {
		view = 'list';
		selectedCredential = null;
		qrDataUrl = '';

		// If only one credential, close instead of showing empty list
		if (credentials.length <= 1) {
			onClose();
		}
	}

	// ── Keyboard handler ──────────────────────────────────────
	function handleOverlayKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
	}
</script>

<!-- ── Modal Overlay ──────────────────────────────────────── -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div
	class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-end justify-center z-[9999]"
	on:click|self={onClose}
	on:keydown={handleOverlayKeydown}
	role="dialog"
	aria-modal="true"
	aria-label={t('mobile.erp.qrTitle')}
	tabindex="-1"
	dir={isAr ? 'rtl' : 'ltr'}
>
	<!-- Sheet panel — slides up from bottom -->
	<div class="bg-white w-full max-w-md rounded-t-3xl shadow-2xl overflow-hidden" style="max-height: 92vh; overflow-y: auto;">

		<!-- Loading state -->
		{#if loading}
			<div class="flex flex-col items-center justify-center py-16 gap-4">
				<div class="w-10 h-10 border-4 border-violet-200 border-t-violet-600 rounded-full animate-spin"></div>
				<p class="text-slate-500 text-sm font-semibold">Loading…</p>
			</div>

		{:else if loadError}
			<!-- Error state -->
			<div class="p-6 text-center space-y-4">
				<div class="text-4xl">⚠️</div>
				<p class="text-red-700 font-semibold text-sm">{loadError}</p>
				<button class="px-4 py-2 rounded-xl bg-slate-200 text-slate-700 font-bold text-sm" on:click={onClose}>Close</button>
			</div>

		{:else if view === 'list'}
			<!-- ── Branch selector view ── -->
			<div class="flex flex-col">
				<!-- Header -->
				<div class="flex items-center justify-between px-5 pt-5 pb-4 border-b border-slate-100">
					<h2 class="text-base font-black text-slate-800">{t('mobile.erp.selectBranch')}</h2>
					<button
						class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-slate-500 hover:bg-slate-200 transition"
						on:click={onClose}
						aria-label="Close"
					>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
							<line x1="18" y1="6" x2="6" y2="18"/>
							<line x1="6" y1="6" x2="18" y2="18"/>
						</svg>
					</button>
				</div>

				<!-- Branch list -->
				<div class="p-4 space-y-2">
					{#each credentials as cred (cred.id)}
						<button
							class="w-full flex items-center justify-between px-4 py-3.5 bg-slate-50 hover:bg-violet-50 rounded-2xl border border-slate-200 hover:border-violet-300 transition-all duration-200 group"
							on:click={() => selectCredential(cred)}
						>
							<div class="flex items-center gap-3">
								<div class="w-9 h-9 rounded-xl bg-violet-100 flex items-center justify-center text-lg flex-shrink-0">🏢</div>
								<span class="text-sm font-bold text-slate-700 group-hover:text-violet-700">{cred.branchName}</span>
							</div>
							<svg class="text-slate-400 group-hover:text-violet-500" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								{#if isAr}
									<polyline points="15 18 9 12 15 6"/>
								{:else}
									<polyline points="9 18 15 12 9 6"/>
								{/if}
							</svg>
						</button>
					{/each}
				</div>
			</div>

		{:else if view === 'qr' && selectedCredential}
			<!-- ── QR view ── -->
			<div class="flex flex-col">
				<!-- Header -->
				<div class="flex items-center justify-between px-5 pt-5 pb-4 border-b border-slate-100">
					<div class="flex items-center gap-2">
						{#if credentials.length > 1}
							<button
								class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-slate-500 hover:bg-slate-200 transition"
								on:click={goBackToList}
								aria-label="Back"
							>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
									{#if isAr}
										<polyline points="9 18 15 12 9 6"/>
									{:else}
										<polyline points="15 18 9 12 15 6"/>
									{/if}
								</svg>
							</button>
						{/if}
						<div>
							<h2 class="text-base font-black text-slate-800">{t('mobile.erp.qrTitle')}</h2>
							<p class="text-xs text-slate-500 font-semibold">{selectedCredential.branchName}</p>
						</div>
					</div>
					<button
						class="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center text-slate-500 hover:bg-slate-200 transition"
						on:click={onClose}
						aria-label="Close"
					>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
							<line x1="18" y1="6" x2="6" y2="18"/>
							<line x1="6" y1="6" x2="18" y2="18"/>
						</svg>
					</button>
				</div>

				<!-- QR content -->
				<div class="p-5 flex flex-col items-center gap-5">

					<!-- QR code -->
					{#if qrLoading}
						<div class="w-[240px] h-[240px] rounded-2xl bg-slate-100 flex items-center justify-center">
							<div class="w-8 h-8 border-4 border-violet-200 border-t-violet-600 rounded-full animate-spin"></div>
						</div>
					{:else if qrError}
						<div class="w-[240px] h-[240px] rounded-2xl bg-red-50 border border-red-200 flex items-center justify-center text-center px-4">
							<p class="text-sm text-red-700 font-semibold">{qrError}</p>
						</div>
					{:else if qrDataUrl}
						<div class="p-3 bg-white rounded-2xl border border-slate-200 shadow-sm">
							<img src={qrDataUrl} alt="ERP login QR code" width="240" height="240" class="block rounded-xl" />
						</div>
					{/if}

					<!-- Username display (LTR-wrapped, password never shown) -->
					<div class="w-full bg-slate-50 rounded-2xl border border-slate-200 px-4 py-3 text-center">
						<p class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1">{t('mobile.erp.usernameCaption')}</p>
						<span class="text-base font-black text-slate-800 break-all" dir="ltr">{selectedCredential.erpUsername.trim()}</span>
					</div>

					<!-- Helper text -->
					<div class="w-full bg-violet-50 rounded-2xl border border-violet-100 px-4 py-3">
						<p class="text-xs text-violet-700 font-medium leading-relaxed text-center">{t('mobile.erp.scanHelper')}</p>
					</div>
				</div>
			</div>
		{/if}

	</div>
</div>
