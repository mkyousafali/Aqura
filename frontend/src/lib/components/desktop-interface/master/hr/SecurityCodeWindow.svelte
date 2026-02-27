<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, locale } from '$lib/i18n';
	import SecurityCodeOverlay from './SecurityCodeOverlay.svelte';

	let securityCode = '';
	let displayCode = '';
	let codeTtl = 10;
	let loading = false;
	let codeInterval: ReturnType<typeof setInterval> | null = null;
	let QRCode: any = null;
	let qrDataUrl = '';
	let isRTL = false;
	let showOverlay = false;

	$: isRTL = $locale === 'ar';

	onMount(async () => {
		// Load QR code library
		try {
			const mod = await import('qrcode');
			QRCode = mod.default || mod;
		} catch (e) {
			console.error('QRCode library load error:', e);
		}

		await fetchSecurityCode();
	});

	onDestroy(() => {
		if (codeInterval) clearInterval(codeInterval);
	});

	async function fetchSecurityCode() {
		loading = true;
		try {
			const { data, error } = await supabase.rpc('get_break_security_code');
			if (!error && data?.code) {
				securityCode = data.code;
				displayCode = data.code;
				codeTtl = data.ttl || 10;
				
				// Generate QR code image
				if (QRCode) {
					qrDataUrl = await QRCode.toDataURL(data.code, {
						width: 200,
						margin: 2,
						color: { dark: '#1e293b', light: '#ffffff' }
					});
				}
				
				// Start refresh timer
				if (codeInterval) clearInterval(codeInterval);
				codeInterval = setInterval(async () => {
					const { data: freshData } = await supabase.rpc('get_break_security_code');
					if (freshData?.code && QRCode) {
						securityCode = freshData.code;
						displayCode = freshData.code;
						codeTtl = freshData.ttl || 10;
						qrDataUrl = await QRCode.toDataURL(freshData.code, {
							width: 200,
							margin: 2,
							color: { dark: '#1e293b', light: '#ffffff' }
						});
					}
				}, 8000);
			}
		} catch (error) {
			console.error('Error fetching security code:', error);
		} finally {
			loading = false;
		}
	}

	function closeOverlay() {
		showOverlay = false;
		if (typeof document !== 'undefined') {
			document.body.style.overflow = 'auto';
			document.body.classList.remove('overlay-active');
		}
	}

	function openOverlayModal() {
		showOverlay = true;
		if (typeof document !== 'undefined') {
			document.body.style.overflow = 'hidden';
			document.body.classList.add('overlay-active');
		}
	}</script>

<div class="security-window-container">
	<!-- Header -->
	<div class="window-header">
		<div class="flex items-center justify-between w-full">
			<div class="flex items-center gap-3">
				<span class="text-2xl">🔒</span>
				<h2 class="text-lg font-bold text-slate-800">{isRTL ? 'رمز الأمان' : 'Security Code'}</h2>
			</div>
		</div>
	</div>

	<!-- Content -->
	<div class="window-content">
		{#if loading && !qrDataUrl}
			<div class="loading-state">
				<div class="spinner-large"></div>
				<p class="loading-text">{isRTL ? 'جاري تحميل الرمز...' : 'Loading code...'}</p>
			</div>
		{:else if qrDataUrl}
			<div class="code-display-container">
				<div class="qr-box">
					<img src={qrDataUrl} alt="Break Security QR Code" class="qr-image" />
				</div>
			</div>
		{/if}

		<button 
			class="refresh-btn"
			on:click={fetchSecurityCode}
			disabled={loading}
		>
			<span class="btn-icon">🔄</span>
			<span class="btn-text">{isRTL ? 'تحديث' : 'Refresh'}</span>
		</button>

		<button 
			class="overlay-btn"
			on:click={openOverlayModal}
			disabled={!qrDataUrl}
		>
			<span class="btn-icon">📺</span>
			<span class="btn-text">{isRTL ? 'عرض كطبقة علوية' : 'View as Overlay'}</span>
		</button>
	</div>
</div>

<!-- Separate Overlay Component -->
<SecurityCodeOverlay 
	isVisible={showOverlay} 
	qrDataUrl={qrDataUrl}
	on:close={() => {
		showOverlay = false;
		if (typeof document !== 'undefined') {
			document.body.style.overflow = 'auto';
			document.body.classList.remove('overlay-active');
		}
	}}
/>

<style>
	.security-window-container {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: linear-gradient(135deg, #f8fafc 0%, #f0f4f8 100%);
		padding: 24px;
		gap: 24px;
	}

	.window-header {
		padding-bottom: 20px;
		border-bottom: 2px solid #e2e8f0;
	}

	.window-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 20px;
		align-items: center;
		justify-content: center;
	}

	.loading-state {
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 16px;
	}

	.spinner-large {
		width: 60px;
		height: 60px;
		border: 4px solid #e2e8f0;
		border-top-color: #059669;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	.loading-text {
		color: #64748b;
		font-size: 14px;
		font-weight: 500;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.code-display-container {
		width: 100%;
		display: flex;
		justify-content: center;
	}

	.qr-box {
		background: white;
		border: 2px solid #e2e8f0;
		border-radius: 16px;
		padding: 24px;
		text-align: center;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 16px;
	}

	.qr-image {
		width: 200px;
		height: 200px;
		border-radius: 8px;
		background: white;
		padding: 8px;
		border: 2px solid #e2e8f0;
	}

	.refresh-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 20px;
		background: linear-gradient(135deg, #059669 0%, #047857 100%);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 2px 8px rgba(5, 150, 105, 0.3);
		position: relative;
		overflow: hidden;
	}

	.refresh-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(5, 150, 105, 0.4);
		background: linear-gradient(135deg, #047857 0%, #065f46 100%);
	}

	.refresh-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn-icon {
		font-size: 16px;
		display: flex;
		align-items: center;
	}

	.btn-text {
		letter-spacing: 0.3px;
	}

	.overlay-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 20px;
		background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
		position: relative;
		overflow: hidden;
	}

	.overlay-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 6px 16px rgba(59, 130, 246, 0.4);
		background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
	}

	.overlay-btn:active:not(:disabled) {
		transform: translateY(0);
	}

	.overlay-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
