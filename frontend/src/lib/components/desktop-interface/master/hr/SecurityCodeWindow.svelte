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

	// Scroll texts management
	interface ScrollText {
		id: string;
		text_content: string;
		sort_order: number;
		is_active: boolean;
	}
	let scrollTexts: ScrollText[] = [];
	let newTextInput = '';
	let addingText = false;
	let loadingTexts = false;
	let deletingId: string | null = null;

	$: isRTL = $locale === 'ar';
	$: activeScrollTexts = scrollTexts.filter(st => st.is_active).map(st => st.text_content);

	onMount(async () => {
		// Load QR code library
		try {
			const mod = await import('qrcode');
			QRCode = mod.default || mod;
		} catch (e) {
			console.error('QRCode library load error:', e);
		}

		await fetchSecurityCode();
		await fetchScrollTexts();
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

	async function fetchScrollTexts() {
		loadingTexts = true;
		try {
			console.log('[ScrollTexts] Fetching from security_code_scroll_texts...');
			const { data, error } = await supabase
				.from('security_code_scroll_texts')
				.select('*')
				.order('sort_order', { ascending: true });
			console.log('[ScrollTexts] Result:', { data, error, count: data?.length });
			if (error) {
				console.error('[ScrollTexts] Supabase error:', error);
			}
			if (!error && data) {
				scrollTexts = data;
				console.log('[ScrollTexts] Set scrollTexts:', scrollTexts.length, 'items');
			}
		} catch (err) {
			console.error('[ScrollTexts] Exception:', err);
		} finally {
			loadingTexts = false;
		}
	}

	async function addScrollText() {
		if (!newTextInput.trim()) return;
		addingText = true;
		try {
			const maxOrder = scrollTexts.length > 0 ? Math.max(...scrollTexts.map(st => st.sort_order)) : 0;
			const { error } = await supabase
				.from('security_code_scroll_texts')
				.insert({ text_content: newTextInput.trim(), sort_order: maxOrder + 1, is_active: true });
			if (!error) {
				newTextInput = '';
				await fetchScrollTexts();
			}
		} catch (err) {
			console.error('Error adding scroll text:', err);
		} finally {
			addingText = false;
		}
	}

	async function deleteScrollText(id: string) {
		deletingId = id;
		try {
			const { error } = await supabase
				.from('security_code_scroll_texts')
				.delete()
				.eq('id', id);
			if (!error) {
				await fetchScrollTexts();
			}
		} catch (err) {
			console.error('Error deleting scroll text:', err);
		} finally {
			deletingId = null;
		}
	}

	async function toggleTextActive(id: string, currentActive: boolean) {
		try {
			const { error } = await supabase
				.from('security_code_scroll_texts')
				.update({ is_active: !currentActive })
				.eq('id', id);
			if (!error) {
				await fetchScrollTexts();
			}
		} catch (err) {
			console.error('Error toggling text:', err);
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

	<!-- Scroll Texts Management -->
	<div class="scroll-texts-section">
		<div class="section-header">
			<span class="text-lg">📜</span>
			<h3 class="section-title">{isRTL ? 'نصوص التمرير' : 'Scroll Texts'}</h3>
		</div>

		<!-- Add new text -->
		<div class="add-text-row">
			<input
				type="text"
				class="text-input"
				bind:value={newTextInput}
				placeholder={isRTL ? 'أضف نص جديد...' : 'Add new text...'}
				dir="auto"
				on:keydown={(e) => e.key === 'Enter' && addScrollText()}
			/>
			<button
				class="add-btn"
				on:click={addScrollText}
				disabled={addingText || !newTextInput.trim()}
			>
				{addingText ? '...' : '+'}
			</button>
		</div>

		<!-- Texts list -->
		<div class="texts-list">
			{#if loadingTexts}
				<p class="texts-loading">{isRTL ? 'جاري التحميل...' : 'Loading...'}</p>
			{:else if scrollTexts.length === 0}
				<p class="texts-empty">{isRTL ? 'لا توجد نصوص' : 'No texts added'}</p>
			{:else}
				{#each scrollTexts as st (st.id)}
					<div class="text-item" class:inactive={!st.is_active}>
						<button
							class="toggle-btn"
							class:active={st.is_active}
							on:click={() => toggleTextActive(st.id, st.is_active)}
							title={st.is_active ? 'Disable' : 'Enable'}
						>
							{st.is_active ? '✅' : '⬜'}
						</button>
						<span class="text-content" dir="auto">{st.text_content}</span>
						<button
							class="delete-btn"
							on:click={() => deleteScrollText(st.id)}
							disabled={deletingId === st.id}
							title={isRTL ? 'حذف' : 'Delete'}
						>
							{deletingId === st.id ? '...' : '🗑️'}
						</button>
					</div>
				{/each}
			{/if}
		</div>
	</div>
</div>

<!-- Separate Overlay Component -->
<SecurityCodeOverlay 
	isVisible={showOverlay} 
	qrDataUrl={qrDataUrl}
	scrollTexts={activeScrollTexts}
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
		overflow-y: auto;
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

	/* Scroll Texts Section */
	.scroll-texts-section {
		width: 100%;
		border-top: 2px solid #e2e8f0;
		padding-top: 20px;
		display: flex;
		flex-direction: column;
		gap: 12px;
		max-height: 300px;
		overflow: hidden;
	}

	.section-header {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.section-title {
		font-size: 15px;
		font-weight: 700;
		color: #334155;
	}

	.add-text-row {
		display: flex;
		gap: 8px;
	}

	.text-input {
		flex: 1;
		padding: 10px 14px;
		border: 2px solid #e2e8f0;
		border-radius: 10px;
		font-size: 14px;
		outline: none;
		transition: border-color 0.2s;
		background: white;
	}

	.text-input:focus {
		border-color: #f97316;
	}

	.add-btn {
		width: 42px;
		height: 42px;
		border: none;
		border-radius: 10px;
		background: linear-gradient(135deg, #f97316, #ea580c);
		color: white;
		font-size: 22px;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.2s;
		flex-shrink: 0;
	}

	.add-btn:hover:not(:disabled) {
		transform: scale(1.05);
		box-shadow: 0 4px 12px rgba(249, 115, 22, 0.4);
	}

	.add-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.texts-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
		overflow-y: auto;
		max-height: 200px;
		padding-right: 4px;
	}

	.texts-loading, .texts-empty {
		color: #94a3b8;
		font-size: 13px;
		text-align: center;
		padding: 12px;
	}

	.text-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 12px;
		background: white;
		border: 1px solid #e2e8f0;
		border-radius: 10px;
		transition: all 0.2s;
	}

	.text-item:hover {
		border-color: #f97316;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
	}

	.text-item.inactive {
		opacity: 0.5;
		background: #f8fafc;
	}

	.toggle-btn {
		background: none;
		border: none;
		cursor: pointer;
		font-size: 16px;
		padding: 2px;
		flex-shrink: 0;
	}

	.text-content {
		flex: 1;
		font-size: 14px;
		color: #1e293b;
		line-height: 1.4;
		word-break: break-word;
	}

	.delete-btn {
		background: none;
		border: none;
		cursor: pointer;
		font-size: 14px;
		padding: 4px;
		opacity: 0.6;
		transition: opacity 0.2s;
		flex-shrink: 0;
	}

	.delete-btn:hover:not(:disabled) {
		opacity: 1;
	}

	.delete-btn:disabled {
		cursor: not-allowed;
	}
</style>
