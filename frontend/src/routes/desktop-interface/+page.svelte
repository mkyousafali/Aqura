<script lang="ts">
	import { onMount } from 'svelte';
	import { windowManager } from '$lib/stores/windowManager';
	import { openWindow } from '$lib/utils/windowManagerUtils';
	import { localeData, t } from '$lib/i18n';
	import BranchMaster from '$lib/components/desktop-interface/master/BranchMaster.svelte';
	import WelcomeWindow from '$lib/components/common/WelcomeWindow.svelte';

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
		openWindow({
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
</script>

<svelte:head>
	<title>{$localeData ? t('app.name') : 'Aqura Management System'}</title>
	<meta name="description" content={$localeData ? t('app.description') : 'PWA-first windowed management platform'} />
</svelte:head>

<div class="desktop-content">
	{#if mounted}
		<!-- Welcome Screen -->
		<div class="welcome-screen">
			<div class="welcome-card">
				<div class="logo-section">
					<div class="logo">
						<img src="/icons/Aqura logo.png" alt="Aqura Logo" class="logo-image" />
					</div>
					<p class="app-subtitle">{$localeData ? t('app.description') : 'AI-powered management system'}</p>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	:global(.desktop) {
		background: transparent !important;
	}
	
	:global(.app::before) {
		display: none !important;
	}

	.desktop-content {
		position: fixed;
		left: var(--sidebar-width, 86px);
		right: 0;
		top: 0;
		bottom: 56px;
		padding: 0;
		margin: 0;
		z-index: 10;
	}

	.welcome-screen {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
		margin: 0;
	}

	.welcome-card {
		background: #FFFFFF;
		width: 600px;
		max-width: 90%;
		height: auto;
		display: block;
		padding: 0;
		margin: 0;
		border-radius: 24px;
		box-shadow: 0 25px 50px rgba(11, 18, 32, 0.1);
		overflow: hidden;
	}

	.logo-section {
		text-align: center;
		padding: 3rem 2rem 2rem;
		background: linear-gradient(135deg, #15A34A 0%, #22C55E 100%);
		color: white;
		position: relative;
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
	}

	.logo {
		width: 200px;
		height: 120px;
		margin: 0 auto 1.5rem;
		background: #FFFFFF;
		border: 6px solid #F59E0B;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
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

	.logo-image {
		width: 840px;
		height: 450px;
		border-radius: 12px;
		object-fit: contain;
		display: block;
		margin: 20px auto 0;
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

		.logo-section {
			padding: 2rem 1rem 1.5rem;
		}

		.app-title {
			font-size: 2rem;
		}
	}
</style>
