<script lang="ts">
	import { createEventDispatcher, onDestroy } from 'svelte';
	import { iconUrlMap } from '$lib/stores/iconStore';

	// Portal action: moves element to document.body so it escapes all stacking contexts
	function portal(node: HTMLElement) {
		document.body.appendChild(node);
		return {
			destroy() {
				if (node.parentNode) node.parentNode.removeChild(node);
			}
		};
	}

	export let isVisible = false;
	export let qrDataUrl = '';
	export let scrollTexts: string[] = [];

	// Single-item ticker: show one text, scroll out, show next
	let tickerIndex = 0;
	let tickerInterval: ReturnType<typeof setInterval> | null = null;
	$: currentTickerText = scrollTexts.length > 0 ? scrollTexts[tickerIndex % scrollTexts.length] : '';

	function tickerAction(node: HTMLElement) {
		// Inject styles into the portal-moved DOM
		const style = document.createElement('style');
		style.textContent = `
			@keyframes scTickerSlideIn {
				0% { transform: perspective(600px) rotateY(90deg) translateX(-100%); opacity: 0; }
				8% { transform: perspective(600px) rotateY(0deg) translateX(0); opacity: 1; }
				92% { transform: perspective(600px) rotateY(0deg) translateX(0); opacity: 1; }
				100% { transform: perspective(600px) rotateY(-90deg) translateX(100%); opacity: 0; }
			}
			@keyframes scHeartbeat {
				0%, 100% { transform: perspective(600px) scale(1); }
				15% { transform: perspective(600px) scale(1.08); }
				30% { transform: perspective(600px) scale(1); }
				45% { transform: perspective(600px) scale(1.05); }
				60% { transform: perspective(600px) scale(1); }
			}
			.sc-ticker-text {
				display: inline-block;
				white-space: nowrap;
				animation: scTickerSlideIn 8s ease-in-out, scHeartbeat 2s ease-in-out infinite;
				text-shadow: 
					0 1px 0 #ccc,
					0 2px 0 #bbb,
					0 3px 0 #aaa,
					0 4px 0 #999,
					0 5px 0 #888,
					0 6px 3px rgba(0,0,0,0.15),
					0 8px 8px rgba(0,0,0,0.1),
					0 12px 16px rgba(0,0,0,0.08);
				letter-spacing: 1px;
			}
		`;
		node.appendChild(style);

		// Cycle to next text every 8 seconds
		tickerIndex = 0;
		tickerInterval = setInterval(() => {
			tickerIndex = (tickerIndex + 1) % (scrollTexts.length || 1);
		}, 8000);

		return {
			destroy() {
				if (tickerInterval) clearInterval(tickerInterval);
				tickerInterval = null;
				if (style.parentNode) style.parentNode.removeChild(style);
			}
		};
	}

	const dispatch = createEventDispatcher();

	// Live clock
	let now = new Date();
	let clockInterval: ReturnType<typeof setInterval> | null = null;

	$: if (isVisible) {
		if (!clockInterval) {
			now = new Date();
			clockInterval = setInterval(() => { now = new Date(); }, 1000);
		}
	} else {
		if (clockInterval) { clearInterval(clockInterval); clockInterval = null; }
	}

	onDestroy(() => {
		if (clockInterval) clearInterval(clockInterval);
	});

	// Format time in 12-hour format
	function formatTimeEn(d: Date): string {
		let h = d.getHours();
		const m = d.getMinutes().toString().padStart(2, '0');
		const s = d.getSeconds().toString().padStart(2, '0');
		const ampm = h >= 12 ? 'PM' : 'AM';
		h = h % 12 || 12;
		return `${h}:${m}:${s} ${ampm}`;
	}

	function formatTimeAr(d: Date): string {
		let h = d.getHours();
		const m = d.getMinutes().toString().padStart(2, '0');
		const s = d.getSeconds().toString().padStart(2, '0');
		const ampm = h >= 12 ? 'م' : 'ص';
		h = h % 12 || 12;
		const toAr = (str: string) => str.replace(/[0-9]/g, (c) => '٠١٢٣٤٥٦٧٨٩'[parseInt(c)]);
		return `${toAr(String(h))}:${toAr(m)}:${toAr(s)} ${ampm}`;
	}

	// Format date dd-mm-yyyy
	function formatDateEn(d: Date): string {
		const dd = d.getDate().toString().padStart(2, '0');
		const mm = (d.getMonth() + 1).toString().padStart(2, '0');
		const yyyy = d.getFullYear();
		return `${dd}-${mm}-${yyyy}`;
	}

	function formatDateAr(d: Date): string {
		const toAr = (str: string) => str.replace(/[0-9]/g, (c) => '٠١٢٣٤٥٦٧٨٩'[parseInt(c)]);
		const dd = d.getDate().toString().padStart(2, '0');
		const mm = (d.getMonth() + 1).toString().padStart(2, '0');
		const yyyy = d.getFullYear().toString();
		return `${toAr(dd)}-${toAr(mm)}-${toAr(yyyy)}`;
	}

	$: timeEn = formatTimeEn(now);
	$: timeAr = formatTimeAr(now);
	$: dateEn = formatDateEn(now);
	$: dateAr = formatDateAr(now);

	function closeOverlay() {
		isVisible = false;
		dispatch('close');
		if (typeof document !== 'undefined') {
			document.body.style.overflow = 'auto';
			document.body.classList.remove('overlay-active');
		}
	}

	function handleBackdropClick() {
		closeOverlay();
	}

	function handleContentClick(event: Event) {
		event.stopPropagation();
	}
</script>

<!-- Full Screen Overlay -->
{#if isVisible && qrDataUrl}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="security-code-overlay" use:portal on:click={handleBackdropClick} on:contextmenu|preventDefault>
		<div class="sc-overlay-backdrop"></div>
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div class="sc-overlay-container" on:click={handleContentClick}>
			<div class="sc-overlay-popup">
				<!-- Logo -->
				<div class="sc-popup-logo-section">
					<img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Aqura Logo" class="sc-popup-logo" />
				</div>

				<!-- QR Code -->
				<img src={qrDataUrl} alt="Break Security QR Code" class="sc-overlay-qr-image" />
			</div>

			<!-- Time & Date Card -->
			<div class="sc-datetime-card">
				<div class="sc-datetime-row">
					<span class="sc-time-en">{timeEn}</span>
					<span class="sc-time-ar">{timeAr}</span>
				</div>
				<div class="sc-datetime-row">
					<span class="sc-date-en">{dateEn}</span>
					<span class="sc-date-ar">{dateAr}</span>
				</div>
			</div>

			<!-- Scroll Text Card -->
			{#if scrollTexts.length > 0}
			<div class="sc-scroll-card" use:tickerAction>
				<div style="overflow:hidden;width:100%;text-align:center;">
					{#key tickerIndex}
						<span class="sc-ticker-text sc-scroll-item">✦ {currentTickerText} ✦</span>
					{/key}
				</div>
			</div>
			{/if}

			<!-- Close Button -->
			<button class="sc-overlay-close" on:click|stopPropagation={closeOverlay} aria-label="Close">
				<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="18" y1="6" x2="6" y2="18"/>
					<line x1="6" y1="6" x2="18" y2="18"/>
				</svg>
			</button>
		</div>
	</div>
{/if}

<style>
	/* All styles are :global() because portal moves element to document.body, outside component scope */
	:global(.security-code-overlay) {
		position: fixed;
		inset: 0;
		z-index: 99999;
		display: flex;
		align-items: center;
		justify-content: center;
		animation: -global-scOverlayFadeIn 0.3s ease;
		pointer-events: auto;
	}

	:global(.security-code-overlay .sc-overlay-backdrop) {
		position: absolute;
		inset: 0;
		background: rgba(0, 0, 0, 0.95);
		backdrop-filter: blur(8px);
		-webkit-backdrop-filter: blur(8px);
	}

	:global(.security-code-overlay .sc-overlay-container) {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		animation: -global-scOverlaySlideIn 0.3s ease;
		width: 100%;
		height: 100%;
		pointer-events: none;
	}

	:global(.security-code-overlay .sc-overlay-popup) {
		background: white;
		border: 4px solid #f97316;
		border-radius: 20px;
		padding: 32px;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 24px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.4);
		max-width: 90vw;
		max-height: 90vh;
		overflow: auto;
		pointer-events: auto;
	}

	:global(.security-code-overlay .sc-popup-logo-section) {
		display: flex;
		justify-content: center;
	}

	:global(.security-code-overlay .sc-popup-logo) {
		width: 160px;
		height: auto;
		object-fit: contain;
	}

	:global(.security-code-overlay .sc-overlay-qr-image) {
		width: 100%;
		max-width: 500px;
		height: auto;
		max-height: 500px;
		border-radius: 12px;
		background: white;
		padding: 12px;
		border: 2px solid #e2e8f0;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	:global(.security-code-overlay .sc-datetime-card) {
		background: white;
		border: 3px solid #f97316;
		border-radius: 16px;
		padding: 16px 28px;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
		pointer-events: auto;
		margin-top: 12px;
		min-width: 280px;
	}

	:global(.security-code-overlay .sc-datetime-row) {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 20px;
		width: 100%;
	}

	:global(.security-code-overlay .sc-time-en) {
		font-size: 28px;
		font-weight: 700;
		color: #1e293b;
		font-family: 'Segoe UI', monospace;
		letter-spacing: 1px;
	}

	:global(.security-code-overlay .sc-time-ar) {
		font-size: 28px;
		font-weight: 700;
		color: #f97316;
		font-family: 'Segoe UI', monospace;
		direction: rtl;
		letter-spacing: 1px;
	}

	:global(.security-code-overlay .sc-date-en) {
		font-size: 18px;
		font-weight: 600;
		color: #475569;
	}

	:global(.security-code-overlay .sc-date-ar) {
		font-size: 18px;
		font-weight: 600;
		color: #f97316;
		direction: rtl;
	}

	/* Scroll text card */
	:global(.security-code-overlay .sc-scroll-card) {
		background: white;
		border: 3px solid #f97316;
		border-radius: 16px;
		padding: 14px 0;
		overflow: hidden;
		pointer-events: auto;
		margin-top: 12px;
		width: 90vw;
		max-width: 700px;
	}

	:global(.security-code-overlay .sc-scroll-item) {
		font-size: 24px;
		font-weight: 700;
		color: #1e293b;
		direction: rtl;
		flex-shrink: 0;
	}

	:global(.security-code-overlay .sc-overlay-close) {
		position: fixed;
		top: 20px;
		right: 20px;
		width: 48px;
		height: 48px;
		background: #f97316;
		border: none;
		border-radius: 50%;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(249, 115, 22, 0.4);
		z-index: 100000;
		pointer-events: auto;
	}

	:global(.security-code-overlay .sc-overlay-close:hover) {
		transform: scale(1.15) rotate(90deg);
		box-shadow: 0 8px 20px rgba(249, 115, 22, 0.6);
		background: #ea580c;
	}

	:global(.security-code-overlay .sc-overlay-close:active) {
		transform: scale(0.95) rotate(90deg);
	}

	@keyframes -global-scOverlayFadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes -global-scOverlaySlideIn {
		from {
			opacity: 0;
			transform: scale(0.8);
		}
		to {
			opacity: 1;
			transform: scale(1);
		}
	}

	/* Mobile responsiveness */
	@media (max-width: 768px) {
		:global(.security-code-overlay .sc-overlay-popup) {
			max-width: 85vw;
			padding: 24px;
		}

		:global(.security-code-overlay .sc-overlay-qr-image) {
			max-width: 400px;
			max-height: 400px;
		}

		:global(.security-code-overlay .sc-popup-logo) {
			width: 130px;
		}

		:global(.security-code-overlay .sc-overlay-close) {
			width: 44px;
			height: 44px;
			top: 16px;
			right: 16px;
		}

		:global(.security-code-overlay .sc-datetime-card) {
			padding: 12px 20px;
			min-width: 240px;
		}

		:global(.security-code-overlay .sc-time-en),
		:global(.security-code-overlay .sc-time-ar) {
			font-size: 22px;
		}

		:global(.security-code-overlay .sc-date-en),
		:global(.security-code-overlay .sc-date-ar) {
			font-size: 15px;
		}

		:global(.security-code-overlay .sc-scroll-card) {
			max-width: 85vw;
			padding: 10px 0;
		}

		:global(.security-code-overlay .sc-scroll-item) {
			font-size: 20px;
		}
	}

	@media (max-width: 480px) {
		:global(.security-code-overlay) {
			padding: 12px;
		}

		:global(.security-code-overlay .sc-overlay-popup) {
			max-width: 95vw;
			padding: 20px;
			gap: 16px;
			border: 3px solid #f97316;
		}

		:global(.security-code-overlay .sc-overlay-qr-image) {
			max-width: 300px;
			max-height: 300px;
			padding: 8px;
		}

		:global(.security-code-overlay .sc-popup-logo) {
			width: 110px;
		}

		:global(.security-code-overlay .sc-overlay-close) {
			width: 40px;
			height: 40px;
			top: 12px;
			right: 12px;
		}

		:global(.security-code-overlay .sc-datetime-card) {
			padding: 10px 16px;
			min-width: 200px;
			margin-top: 8px;
		}

		:global(.security-code-overlay .sc-time-en),
		:global(.security-code-overlay .sc-time-ar) {
			font-size: 18px;
		}

		:global(.security-code-overlay .sc-date-en),
		:global(.security-code-overlay .sc-date-ar) {
			font-size: 13px;
		}

		:global(.security-code-overlay .sc-datetime-row) {
			gap: 12px;
		}

		:global(.security-code-overlay .sc-scroll-card) {
			max-width: 95vw;
			padding: 8px 0;
			margin-top: 8px;
		}

		:global(.security-code-overlay .sc-scroll-item) {
			font-size: 16px;
		}
	}
</style>
