<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { localeData, t, switchLocale } from '$lib/i18n';
	import HRMaster from '$lib/components/admin/HRMaster.svelte';
	import BranchMaster from '$lib/components/admin/BranchMaster.svelte';
	import VendorMaster from '$lib/components/admin/VendorMaster.svelte';
	import WelcomeWindow from '$lib/components/WelcomeWindow.svelte';

	let mounted = false;

	onMount(() => {
		mounted = true;
		
		// Auto-open welcome window on first visit
		const hasVisited = localStorage.getItem('aqura-visited');
		if (!hasVisited) {
			setTimeout(() => {
				openWelcomeWindow();
				localStorage.setItem('aqura-visited', 'true');
			}, 1000);
		}
	});

	// Sample windows for demonstration
	function openWelcomeWindow() {
		windowManager.openWindow({
			id: 'welcome',
			title: $localeData ? t('welcome.title') : 'Welcome to Aqura',
			component: WelcomeWindow,
			size: { width: 600, height: 400 },
			icon: '🎉',
			resizable: true,
			minimizable: true,
			maximizable: true,
			closable: true
		});
	}

	// Language toggle
	function toggleLanguage() {
		const newLocale = $localeData?.code === 'ar' ? 'en' : 'ar';
		switchLocale(newLocale);
	}
</script>

<svelte:head>
	<title>{$localeData ? t('app.name') : 'Aqura Management System'}</title>
	<meta name="description" content={$localeData ? t('app.description') : 'PWA-first windowed management platform'} />
</svelte:head>

<div class="desktop-content">
	{#if mounted}
		<!-- Top Bar -->
		<div class="top-bar">
			<div class="top-bar-spacer"></div>
			
			<div class="top-bar-actions">
				<button class="top-bar-btn" on:click={toggleLanguage} title="Switch Language">
					🌐 {$localeData?.code === 'ar' ? 'EN' : 'العربية'}
				</button>
			</div>
		</div>

		<!-- Welcome Screen -->
		<div class="welcome-screen">
			<div class="welcome-card">
				<div class="logo-section">
					<div class="logo">
						<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
					</div>
					<h1 class="app-title">Aqura</h1>
					<p class="app-subtitle">Your AI management system</p>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.top-bar {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		height: 60px;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		backdrop-filter: blur(10px);
		border-bottom: 2px solid rgba(245, 158, 11, 0.3);
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 2rem;
		z-index: 1000;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
	}

	.top-bar-spacer {
		flex: 1;
	}

	.top-bar-actions {
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.top-bar-btn {
		padding: 0.5rem 1rem;
		background: rgba(255, 255, 255, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.3);
		border-radius: 8px;
		color: white;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.top-bar-btn:hover {
		background: rgba(245, 158, 11, 0.9);
		border-color: #F59E0B;
		color: #0B1220;
		transform: translateY(-1px);
	}

	.desktop-content {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		padding-top: 6rem; /* Account for top bar */
	}

	.welcome-screen {
		max-width: 800px;
		width: 100%;
	}

	.welcome-card {
		background: #FFFFFF;
		backdrop-filter: blur(10px);
		border-radius: 16px;
		box-shadow: 0 25px 50px rgba(11, 18, 32, 0.1), 0 8px 32px rgba(107, 114, 128, 0.08);
		border: 1px solid rgba(229, 231, 235, 0.8);
		overflow: hidden;
		animation: fadeIn 0.6s ease-out;
	}

	.logo-section {
		text-align: center;
		padding: 3rem 2rem 2rem;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		color: white;
		position: relative;
	}

	.logo-section::after {
		content: '';
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		height: 4px;
		background: linear-gradient(90deg, #F59E0B 0%, #FBBF24 100%);
	}

	.logo {
		width: 120px;
		height: 120px;
		margin: 0 auto 1.5rem;
		background: #FFFFFF;
		border: 6px solid #F59E0B;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 
			0 0 25px rgba(245, 158, 11, 0.5),
			0 0 50px rgba(245, 158, 11, 0.3),
			inset 0 0 15px rgba(245, 158, 11, 0.15);
		animation: ledGlow 2s ease-in-out infinite alternate;
	}

	@keyframes ledGlow {
		from {
			box-shadow: 
				0 0 25px rgba(245, 158, 11, 0.5),
				0 0 50px rgba(245, 158, 11, 0.3),
				inset 0 0 15px rgba(245, 158, 11, 0.15);
		}
		to {
			box-shadow: 
				0 0 40px rgba(245, 158, 11, 0.7),
				0 0 80px rgba(245, 158, 11, 0.4),
				inset 0 0 25px rgba(245, 158, 11, 0.25);
		}
	}

	.logo-text {
		font-size: 2.5rem;
		font-weight: 700;
		color: white;
	}

	.app-title {
		font-size: 2.5rem;
		font-weight: 700;
		margin-bottom: 0.5rem;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.app-subtitle {
		font-size: 1.1rem;
		opacity: 0.9;
		font-weight: 300;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
			transform: translateY(20px) scale(0.95);
		}
		to {
			opacity: 1;
			transform: translateY(0) scale(1);
		}
	}

	/* Responsive design */
	@media (max-width: 768px) {
		.desktop-content {
			padding: 1rem;
		}

		.action-grid {
			grid-template-columns: 1fr;
		}

		.logo-section {
			padding: 2rem 1rem 1.5rem;
		}

		.app-title {
			font-size: 2rem;
		}

		.footer-actions {
			flex-direction: column;
			gap: 1rem;
		}
	}
</style>
