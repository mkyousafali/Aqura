import { writable, get } from 'svelte/store';
import { browser } from '$app/environment';

// PWA installation state
export const showInstallPrompt = writable(false);
export const deferredPrompt = writable<any>(null);
export const isInstalled = writable(false);

// Check if PWA is already installed
export function checkPWAInstalled(): boolean {
	if (!browser) return false;
	
	// Check if running in standalone mode (already installed)
	const isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
		   ('standalone' in window.navigator && (window.navigator as any).standalone);
	
	// Check if it's a desktop browser that might not show install prompt
	const isDesktop = !(/Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent));
	
	return isStandalone;
}

// Initialize PWA install prompt detection
export function initPWAInstall() {
	if (!browser) return;

	// Check if already installed
	const installed = checkPWAInstalled();
	isInstalled.set(installed);

	// Always show the install button initially (it will adapt based on browser support)
	showInstallPrompt.set(!installed);

	// Listen for beforeinstallprompt event
	window.addEventListener('beforeinstallprompt', (e) => {
		console.log('PWA install prompt available');
		// Prevent the mini-infobar from appearing on mobile
		e.preventDefault();
		// Store the event so it can be triggered later
		deferredPrompt.set(e);
		showInstallPrompt.set(true);
		isInstalled.set(false);
	});

	// Listen for app installed event
	window.addEventListener('appinstalled', () => {
		console.log('PWA was installed');
		showInstallPrompt.set(false);
		deferredPrompt.set(null);
		isInstalled.set(true);
	});

	// Check periodically if the app was installed (for desktop browsers)
	const checkInstallStatus = () => {
		const nowInstalled = checkPWAInstalled();
		if (nowInstalled && !installed) {
			console.log('PWA installation detected');
			isInstalled.set(true);
			showInstallPrompt.set(false);
		}
	};

	// Check every 5 seconds for installation status
	setInterval(checkInstallStatus, 5000);
}

// Trigger PWA installation
export async function installPWA(): Promise<boolean> {
	if (!browser) return false;

	// Get the current value of deferredPrompt using get()
	const prompt = get(deferredPrompt);

	if (!prompt) {
		// Check if it's a desktop browser
		const isDesktop = !(/Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent));
		
		if (isDesktop) {
			// For desktop browsers, show desktop installation instructions
			showDesktopInstallInstructions();
		} else {
			// For mobile browsers, show mobile installation instructions
			showIOSInstallInstructions();
		}
		return false;
	}

	try {
		// Show the install prompt
		prompt.prompt();
		
		// Wait for the user to respond
		const { outcome } = await prompt.userChoice;
		
		if (outcome === 'accepted') {
			console.log('User accepted the install prompt');
			// Clear the prompt after successful installation
			deferredPrompt.set(null);
			showInstallPrompt.set(false);
			isInstalled.set(true);
			return true;
		} else {
			console.log('User dismissed the install prompt');
			return false;
		}
	} catch (error) {
		console.error('Error installing PWA:', error);
		// Fallback to instructions if prompt fails
		const isDesktop = !(/Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent));
		if (isDesktop) {
			showDesktopInstallInstructions();
		} else {
			showIOSInstallInstructions();
		}
		return false;
	}
}

// Show iOS installation instructions
function showIOSInstallInstructions() {
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

// Show desktop installation instructions
function showDesktopInstallInstructions() {
	// Create modal with desktop installation instructions
	const modal = document.createElement('div');
	modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4';
	modal.innerHTML = `
		<div class="bg-white rounded-lg p-6 max-w-md mx-auto">
			<h3 class="text-lg font-semibold mb-4">Install Aqura App</h3>
			<div class="space-y-3 text-sm">
				<div class="flex items-start">
					<span class="text-blue-500 mr-2 mt-0.5">Chrome:</span>
					<div>
						<div>• Click the install icon in the address bar</div>
						<div>• Or go to Settings → More tools → Create shortcut</div>
					</div>
				</div>
				<div class="flex items-start">
					<span class="text-blue-500 mr-2 mt-0.5">Edge:</span>
					<div>
						<div>• Click the install icon in the address bar</div>
						<div>• Or go to Settings → Apps → Install this site as an app</div>
					</div>
				</div>
				<div class="flex items-start">
					<span class="text-blue-500 mr-2 mt-0.5">Firefox:</span>
					<div>
						<div>• Bookmark this page and access from bookmarks</div>
						<div>• Or create a desktop shortcut manually</div>
					</div>
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