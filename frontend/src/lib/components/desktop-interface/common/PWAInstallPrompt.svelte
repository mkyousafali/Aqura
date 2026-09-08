<script lang="ts">
	import { onMount } from 'svelte';
	import { writable } from 'svelte/store';

	// Store for PWA installation state
	const showInstallPrompt = writable(false);
	const deferredPrompt = writable<any>(null);

	let installPromptVisible = false;
	let promptEvent: any = null;

	onMount(() => {
		// Listen for beforeinstallprompt event
		window.addEventListener('beforeinstallprompt', (e) => {
			console.log('PWA install prompt available');
			// Prevent the mini-infobar from appearing on mobile
			e.preventDefault();
			// Store the event so it can be triggered later
			promptEvent = e;
			deferredPrompt.set(e);
			installPromptVisible = true;
			showInstallPrompt.set(true);
		});

		// Listen for app installed event
		window.addEventListener('appinstalled', () => {
			console.log('PWA was installed');
			installPromptVisible = false;
			showInstallPrompt.set(false);
			// Track installation for analytics
			trackInstallation();
		});

		// Check if already installed
		if (window.matchMedia('(display-mode: standalone)').matches) {
			console.log('PWA is already installed');
			installPromptVisible = false;
		}

		// Check for iOS Safari
		const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
		const isInStandaloneMode = ('standalone' in window.navigator) && (window.navigator as any).standalone;
		
		if (isIOS && !isInStandaloneMode) {
			// Show iOS installation instructions after a delay
			setTimeout(() => {
				if (!installPromptVisible) {
					installPromptVisible = true;
					showInstallPrompt.set(true);
				}
			}, 3000);
		}
	});

	async function handleInstall() {
		if (!promptEvent) {
			// For iOS, show instructions
			showIOSInstructions();
			return;
		}

		// Show the install prompt
		promptEvent.prompt();
		
		// Wait for the user to respond
		const { outcome } = await promptEvent.userChoice;
		
		if (outcome === 'accepted') {
			console.log('User accepted the install prompt');
		} else {
			console.log('User dismissed the install prompt');
		}
		
		// Clear the prompt
		promptEvent = null;
		deferredPrompt.set(null);
		installPromptVisible = false;
		showInstallPrompt.set(false);
	}

	function dismissPrompt() {
		installPromptVisible = false;
		showInstallPrompt.set(false);
		
		// Don't show again for this session
		sessionStorage.setItem('pwa-prompt-dismissed', 'true');
	}

	function showIOSInstructions() {
		// Create modal with iOS installation instructions
		const modal = document.createElement('div');
		modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4';
		modal.innerHTML = `
			<div class="bg-white rounded-lg p-6 max-w-sm mx-auto">
				<h3 class="text-lg font-semibold mb-4">Install Aqura App</h3>
				<div class="space-y-3 text-sm">
					<div class="flex items-center">
						<span class="text-blue-500 mr-2">1.</span>
						<span>Tap the Share button</span>
						<svg class="ml-2 w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
							<path d="M15 8a3 3 0 10-2.977-2.63l-4.94 2.47a3 3 0 100 4.319l4.94 2.47a3 3 0 10.895-1.789l-4.94-2.47a3.027 3.027 0 000-.74l4.94-2.47C13.456 7.68 14.19 8 15 8z"/>
						</svg>
					</div>
					<div class="flex items-center">
						<span class="text-blue-500 mr-2">2.</span>
						<span>Tap "Add to Home Screen"</span>
					</div>
					<div class="flex items-center">
						<span class="text-blue-500 mr-2">3.</span>
						<span>Tap "Add" to install</span>
					</div>
				</div>
				<button onclick="this.parentElement.parentElement.remove()" 
						class="mt-4 w-full bg-blue-500 text-white py-2 px-4 rounded-lg">
					Got it
				</button>
			</div>
		`;
		document.body.appendChild(modal);
	}

	function trackInstallation() {
		// Track PWA installation for analytics
		if (window.gtag) {
			window.gtag('event', 'pwa_install', {
				event_category: 'PWA',
				event_label: 'Aqura Management System'
			});
		}
	}

	// Check if prompt was already dismissed this session
	onMount(() => {
		if (sessionStorage.getItem('pwa-prompt-dismissed')) {
			installPromptVisible = false;
			showInstallPrompt.set(false);
		}
	});
</script>

{#if installPromptVisible}
	<div class="fixed bottom-4 right-4 bg-white border border-gray-200 rounded-lg shadow-lg p-4 max-w-sm z-40 animate-slide-up">
		<div class="flex items-start space-x-3">
			<!-- App icon -->
			<div class="w-12 h-12 bg-gradient-to-br from-aqua-500 to-orange-500 rounded-lg flex items-center justify-center text-white font-bold text-xl">
				A
			</div>
			
			<div class="flex-1">
				<h3 class="font-semibold text-gray-900 text-sm">Install Aqura App</h3>
				<p class="text-gray-600 text-xs mt-1">
					Add to your home screen for faster access and offline support
				</p>
				
				<div class="flex space-x-2 mt-3">
					<button 
						on:click={handleInstall}
						class="bg-gradient-to-r from-aqua-500 to-orange-500 text-white text-xs px-3 py-1.5 rounded-md font-medium hover:opacity-90 transition-opacity"
					>
						Install
					</button>
					<button 
						on:click={dismissPrompt}
						class="text-gray-500 text-xs px-3 py-1.5 rounded-md hover:bg-gray-100 transition-colors"
					>
						Later
					</button>
				</div>
			</div>
			
			<!-- Close button -->
			<button 
				on:click={dismissPrompt}
				class="text-gray-400 hover:text-gray-600 transition-colors"
				aria-label="Close install prompt"
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
				</svg>
			</button>
		</div>
	</div>
{/if}

<style>
	@keyframes slide-up {
		from {
			transform: translateY(100%);
			opacity: 0;
		}
		to {
			transform: translateY(0);
			opacity: 1;
		}
	}
	
	.animate-slide-up {
		animation: slide-up 0.3s ease-out;
	}
</style>
