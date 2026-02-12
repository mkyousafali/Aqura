<script lang="ts">
	import { getTranslation } from '$lib/i18n';
	import { currentLocale } from '$lib/i18n';
	import { onDestroy } from 'svelte';

	let barcode = '';
	let quantity = 1;
	let scanning = false;
	let videoEl: HTMLVideoElement;
	let stream: MediaStream | null = null;
	let scanInterval: ReturnType<typeof setInterval> | null = null;

	async function startScan() {
		scanning = true;
		try {
			stream = await navigator.mediaDevices.getUserMedia({
				video: { facingMode: 'environment' }
			});
			// Wait for DOM to update with the video element
			await new Promise(r => setTimeout(r, 50));
			if (videoEl) {
				videoEl.srcObject = stream;
				await videoEl.play();
				detectBarcode();
			}
		} catch (err) {
			console.error('Camera access error:', err);
			scanning = false;
		}
	}

	function detectBarcode() {
		// @ts-ignore - BarcodeDetector may not be in TS types yet
		if ('BarcodeDetector' in window) {
			// @ts-ignore
			const detector = new BarcodeDetector({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128', 'code_39', 'qr_code'] });
			scanInterval = setInterval(async () => {
				if (!videoEl || videoEl.readyState < 2) return;
				try {
					const barcodes = await detector.detect(videoEl);
					if (barcodes.length > 0) {
						barcode = barcodes[0].rawValue;
						stopScan();
					}
				} catch (_) {}
			}, 300);
		} else {
			// Fallback: no BarcodeDetector support, just keep camera open
			// User can manually type after seeing the barcode
		}
	}

	function stopScan() {
		if (scanInterval) {
			clearInterval(scanInterval);
			scanInterval = null;
		}
		if (stream) {
			stream.getTracks().forEach(t => t.stop());
			stream = null;
		}
		scanning = false;
	}

	onDestroy(() => {
		stopScan();
	});
</script>

<div class="product-request-page" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<div class="form-section">
		<div class="form-row">
			<div class="form-group barcode-group">
				<label for="barcode">{getTranslation('mobile.productRequestContent.barcode')}</label>
				<div class="barcode-input-row">
					<input
						id="barcode"
						type="text"
						bind:value={barcode}
						class="form-input"
						placeholder={getTranslation('mobile.productRequestContent.barcodePlaceholder')}
						inputmode="numeric"
					/>
					<button type="button" class="scan-btn" on:click={scanning ? stopScan : startScan} title={getTranslation('mobile.productRequestContent.scan')}>
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M3 7V5a2 2 0 0 1 2-2h2"/>
							<path d="M17 3h2a2 2 0 0 1 2 2v2"/>
							<path d="M21 17v2a2 2 0 0 1-2 2h-2"/>
							<path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
							<line x1="7" y1="12" x2="17" y2="12"/>
						</svg>
					</button>
				</div>
			</div>

			<div class="form-group qty-group">
				<label for="quantity">{getTranslation('mobile.productRequestContent.quantity')}</label>
				<input
					id="quantity"
					type="number"
					bind:value={quantity}
					class="form-input"
					min="1"
					placeholder="1"
				/>
			</div>
		</div>
	</div>

	{#if scanning}
		<div class="scanner-overlay" on:click={stopScan} role="button" tabindex="-1" on:keydown={(e) => e.key === 'Escape' && stopScan()}>
			<div class="scanner-container" on:click|stopPropagation role="none">
				<div class="scanner-header">
					<span>{getTranslation('mobile.productRequestContent.scanTitle')}</span>
					<button type="button" class="scanner-close" on:click={stopScan}>&times;</button>
				</div>
				<div class="scanner-video-wrapper">
					<!-- svelte-ignore a11y-media-has-caption -->
					<video bind:this={videoEl} playsinline autoplay muted class="scanner-video"></video>
					<div class="scan-line"></div>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.product-request-page {
		padding: 1rem;
		min-height: 100%;
		background: #F8FAFC;
	}

	.form-section {
		background: white;
		border-radius: 12px;
		padding: 1.5rem;
		margin-bottom: 1rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
	}

	.form-row {
		display: flex;
		gap: 0.75rem;
		align-items: flex-start;
	}

	.form-group {
		margin-bottom: 0;
	}

	.barcode-group {
		flex: 1;
	}

	.qty-group {
		width: 5rem;
		flex-shrink: 0;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 600;
		color: #374151;
		font-size: 0.875rem;
	}

	.form-input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #D1D5DB;
		border-radius: 0.5rem;
		font-size: 1rem;
		box-sizing: border-box;
	}

	.form-input:focus {
		outline: none;
		border-color: #007bff;
		box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
	}

	.barcode-input-row {
		display: flex;
		gap: 0.5rem;
		align-items: stretch;
	}

	.barcode-input-row .form-input {
		flex: 1;
	}

	.scan-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0 0.75rem;
		background: #007bff;
		color: white;
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		flex-shrink: 0;
	}

	.scan-btn:active {
		background: #0056b3;
	}

	/* Scanner overlay */
	.scanner-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.8);
		z-index: 1000;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}

	.scanner-container {
		background: #111;
		border-radius: 12px;
		overflow: hidden;
		width: 100%;
		max-width: 400px;
	}

	.scanner-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0.75rem 1rem;
		color: white;
		font-weight: 600;
		font-size: 0.95rem;
	}

	.scanner-close {
		background: none;
		border: none;
		color: white;
		font-size: 1.5rem;
		cursor: pointer;
		line-height: 1;
		padding: 0 0.25rem;
	}

	.scanner-video-wrapper {
		position: relative;
		width: 100%;
		aspect-ratio: 4/3;
		background: #000;
	}

	.scanner-video {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.scan-line {
		position: absolute;
		left: 10%;
		right: 10%;
		height: 2px;
		background: #ff3b30;
		box-shadow: 0 0 8px rgba(255, 59, 48, 0.6);
		top: 50%;
		animation: scanMove 2s ease-in-out infinite;
	}

	@keyframes scanMove {
		0%, 100% { top: 30%; }
		50% { top: 70%; }
	}
</style>
