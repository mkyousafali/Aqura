<script lang="ts">
	import { createEventDispatcher } from 'svelte';

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

	const dispatch = createEventDispatcher();

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
					<img src="/icons/logo.png" alt="Aqura Logo" class="sc-popup-logo" />
				</div>

				<!-- QR Code -->
				<img src={qrDataUrl} alt="Break Security QR Code" class="sc-overlay-qr-image" />
			</div>

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
		animation: scOverlayFadeIn 0.3s ease;
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
		align-items: center;
		justify-content: center;
		animation: scOverlaySlideIn 0.3s ease;
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

	@keyframes scOverlayFadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes scOverlaySlideIn {
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
	}
</style>
