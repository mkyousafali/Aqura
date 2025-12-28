<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { localeData, _, switchLocale, currentLocale } from '$lib/i18n';
	import { currentUser, isAuthenticated } from '$lib/utils/persistentAuth';
	import CustomerLogin from '$lib/components/customer-interface/common/CustomerLogin.svelte';

	function t(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath;
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	let mounted = false;
	let showContent = false;
	let showMask = true; // Mask for login form only
	let loginMode: 'selection' | 'customer' | 'team' = 'selection'; // 'selection' | 'customer' | 'team'

	onMount(async () => {
		mounted = true;
		setTimeout(() => {
			showContent = true;
		}, 300);

		checkExistingAuth();
	});

	function checkExistingAuth() {
		if ($isAuthenticated && $currentUser) {
			goto('/');
		}
	}

	function handleCustomerSuccess(event) {
		const { detail } = event;
		if (detail.type === 'customer_login') {
			goto('/customer-interface');
		}
	}

	function goToEmployeeLogin() {
		goto('/login/employee');
	}

	function selectLoginMode(mode: 'customer' | 'team') {
		loginMode = mode;
		if (mode === 'team') {
			goToEmployeeLogin();
		}
	}

	function goBack() {
		loginMode = 'selection';
	}
</script>

<svelte:head>
	<title>Login - Aqura Management System</title>
	<meta name="description" content="Access your Aqura Management System" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#15A34A" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

<div class="login-page" class:mounted>
	{#if showContent}
		<div class="login-content">
			{#if loginMode === 'selection'}
				<!-- Login Mode Selection Screen -->
				<div class="customer-login-card login-selection">
					<div class="logo-section">
						<div class="logo">
							<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
						</div>
						<button 
							class="language-toggle-main" 
							on:click={() => {
								switchLocale($currentLocale === 'ar' ? 'en' : 'ar');
								setTimeout(() => {
									window.location.reload();
								}, 100);
							}}
							title={$_('nav.languageToggle')}
						>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<circle cx="12" cy="12" r="10"/>
								<path d="M8 12h8"/>
								<path d="M12 8v8"/>
							</svg>
							{$currentLocale === 'ar' ? 'English' : 'العربية'}
						</button>
					</div>

					<div class="selection-section">
						<h2 class="selection-title">{$_('common.selectLoginType') || 'Select Login Type'}</h2>
						<p class="selection-subtitle">{$_('common.chooseAccountType') || 'Choose your account type to continue'}</p>
						
						<div class="selection-buttons">
							<button class="login-selection-btn customer-btn" on:click={() => selectLoginMode('customer')}>
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
									<circle cx="12" cy="7" r="4"/>
								</svg>
								<span>{$_('common.customerLogin') || 'Customer Login'}</span>
							</button>

							<button class="login-selection-btn team-btn" on:click={() => selectLoginMode('team')}>
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
									<circle cx="9" cy="7" r="4"/>
									<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
									<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
								</svg>
								<span>{$_('common.teamLogin') || 'Team Login'}</span>
							</button>
						</div>
					</div>
				</div>
			{:else if loginMode === 'customer'}
				<!-- Customer Login Screen -->
				<div class="customer-login-card">
					<div class="logo-section">
						<button class="back-button" on:click={goBack} title="Go back">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M19 12H5M12 19l-7-7 7-7"/>
							</svg>
						</button>
						<div class="logo">
							<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
						</div>
						<button 
							class="language-toggle-main" 
							on:click={() => {
								switchLocale($currentLocale === 'ar' ? 'en' : 'ar');
								setTimeout(() => {
									window.location.reload();
								}, 100);
							}}
							title={$_('nav.languageToggle')}
						>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<circle cx="12" cy="12" r="10"/>
								<path d="M8 12h8"/>
								<path d="M12 8v8"/>
							</svg>
							{$currentLocale === 'ar' ? 'English' : 'العربية'}
						</button>
					</div>

					<div class="auth-section">
						<div class="customer-login-wrapper">
							{#if showMask}
								<div class="login-mask"></div>
							{/if}
							<CustomerLogin on:success={handleCustomerSuccess} />
						</div>
					</div>
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	:global(html) {
		touch-action: manipulation;
		-webkit-text-size-adjust: 100%;
		overflow-x: hidden;
		height: 100%;
	}

	:global(body) {
		margin: 0;
		padding: 0;
		overflow-x: hidden;
		min-height: 100vh;
		min-height: 100dvh;
		height: 100%;
		-webkit-overflow-scrolling: touch;
		position: relative;
	}

	:global(input, select, textarea) {
		font-size: 16px !important;
	}

	.login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		align-items: flex-start;
		justify-content: center;
		padding: 1rem;
		padding-top: 2rem;
		background: linear-gradient(135deg, #FF8C00 0%, #22C55E 50%, #FFFFFF 100%);
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		opacity: 0;
		transition: opacity 0.8s ease;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
	}

	.login-page::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: 
			radial-gradient(circle at 25% 25%, rgba(255, 255, 255, 0.1) 0%, transparent 50%),
			radial-gradient(circle at 75% 75%, rgba(255, 255, 255, 0.08) 0%, transparent 50%),
			url("data:image/svg+xml,%3Csvg width='40' height='40' viewBox='0 0 40 40' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23FFFFFF' fill-opacity='0.04'%3E%3Ccircle cx='20' cy='20' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
		z-index: 0;
	}

	.login-page.mounted {
		opacity: 1;
	}

	.login-content {
		width: 100%;
		max-width: 500px;
		position: relative;
		z-index: 1;
		margin: 1rem 0;
		min-height: 0;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.customer-login-card {
		background: rgba(255, 255, 255, 0.95);
		backdrop-filter: blur(20px);
		border-radius: 20px;
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.2);
		overflow: hidden;
		animation: slideInUp 0.8s ease-out;
	}

	@keyframes slideInUp {
		from {
			opacity: 0;
			transform: translateY(40px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.logo-section {
		text-align: center;
		padding: 2.5rem 2rem;
		background: linear-gradient(135deg, #FF8C00 0%, #22C55E 100%);
		color: white;
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
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
		width: 160px;
		height: 100px;
		background: white;
		border: 5px solid #F59E0B;
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 
			0 0 20px rgba(245, 158, 11, 0.6),
			0 0 40px rgba(245, 158, 11, 0.4);
	}

	.logo-image {
		width: 120px;
		height: 70px;
		border-radius: 12px;
		object-fit: contain;
	}

	.logo-content {
		width: 100%;
	}

	.app-title {
		font-size: 2rem;
		font-weight: 700;
		margin: 0 0 0.5rem 0;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.app-subtitle {
		font-size: 1rem;
		opacity: 0.9;
		font-weight: 300;
		margin: 0;
	}

	.language-toggle-main {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: rgba(255, 255, 255, 0.15);
		border: 1px solid rgba(255, 255, 255, 0.3);
		color: white;
		border-radius: 8px;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
		white-space: nowrap;
	}

	.language-toggle-main:hover {
		background: rgba(255, 255, 255, 0.25);
		border-color: rgba(255, 255, 255, 0.4);
	}

	.auth-section {
		padding: 2rem;
	}

	.auth-section :global(.customer-login-container) {
		padding: 0;
		margin: 0;
		background: transparent;
		border: none;
		box-shadow: none;
	}

	.login-selection {
		display: flex;
		flex-direction: column;
	}

	.selection-section {
		padding: 2.5rem 2rem;
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	.selection-title {
		font-size: 1.75rem;
		font-weight: 700;
		margin: 0;
		color: #1f2937;
		text-align: center;
	}

	.selection-subtitle {
		font-size: 1rem;
		color: #6b7280;
		text-align: center;
		margin: 0;
	}

	.selection-buttons {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.login-selection-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 2rem 1.5rem;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		background: white;
		color: #374151;
		font-size: 1.125rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		position: relative;
		overflow: hidden;
	}

	.login-selection-btn::before {
		content: '';
		position: absolute;
		top: 0;
		left: -100%;
		width: 100%;
		height: 100%;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.3) 0%, transparent 100%);
		transition: left 0.3s ease;
	}

	.login-selection-btn:hover {
		border-color: #d1d5db;
		box-shadow: 0 4px 15px rgba(0, 0, 0, 0.08);
		transform: translateY(-2px);
	}

	.login-selection-btn:active {
		transform: translateY(0);
	}

	.login-selection-btn.customer-btn {
		border-color: #22c55e;
		background: linear-gradient(135deg, #f0fdf4 0%, #ffffff 100%);
		color: #15a34a;
	}

	.login-selection-btn.customer-btn:hover {
		border-color: #15a34a;
		background: linear-gradient(135deg, #dcfce7 0%, #ffffff 100%);
		box-shadow: 0 4px 15px rgba(34, 197, 94, 0.2);
	}

	.login-selection-btn.customer-btn svg {
		color: #22c55e;
	}

	.login-selection-btn.team-btn {
		border-color: #667eea;
		background: linear-gradient(135deg, #f0f4ff 0%, #ffffff 100%);
		color: #4f46e5;
	}

	.login-selection-btn.team-btn:hover {
		border-color: #4f46e5;
		background: linear-gradient(135deg, #e0e7ff 0%, #ffffff 100%);
		box-shadow: 0 4px 15px rgba(102, 126, 234, 0.2);
	}

	.login-selection-btn.team-btn svg {
		color: #667eea;
	}

	.back-button {
		position: absolute;
		top: 1rem;
		left: 1rem;
		width: 40px;
		height: 40px;
		background: rgba(255, 255, 255, 0.15);
		border: 1px solid rgba(255, 255, 255, 0.3);
		color: white;
		border-radius: 8px;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.3s ease;
		z-index: 10;
	}

	.back-button:hover {
		background: rgba(255, 255, 255, 0.25);
		border-color: rgba(255, 255, 255, 0.4);
	}

	.back-button:active {
		transform: scale(0.95);
	}

	.employee-login-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		padding: 1rem 2rem;
		background: rgba(255, 255, 255, 0.95);
		border: 2px solid rgba(255, 255, 255, 0.5);
		border-radius: 12px;
		color: #667eea;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s ease;
		box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
		backdrop-filter: blur(10px);
	}

	.employee-login-btn:hover {
		background: white;
		border-color: white;
		box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
		transform: translateY(-2px);
	}

	.employee-login-btn:active {
		transform: translateY(0);
	}

	@media (max-width: 768px) {
		.login-page {
			padding: 1rem;
			padding-top: 1rem;
			padding-bottom: 3rem;
		}

		.login-content {
			max-width: 100%;
		}

		.customer-login-card {
			border-radius: 16px;
		}

		.logo-section {
			padding: 2rem 1.5rem;
			position: relative;
		}

		.logo {
			width: 140px;
			height: 85px;
		}

		.logo-image {
			width: 95px;
			height: 55px;
		}

		.app-title {
			font-size: 1.75rem;
		}

		.app-subtitle {
			font-size: 0.95rem;
		}

		.auth-section {
			padding: 1.5rem;
		}

		.selection-section {
			padding: 2rem 1.5rem;
		}

		.selection-title {
			font-size: 1.5rem;
		}

		.selection-subtitle {
			font-size: 0.95rem;
		}

		.login-selection-btn {
			padding: 1.5rem 1.25rem;
			font-size: 1rem;
		}

		.employee-login-btn {
			padding: 0.875rem 1.5rem;
			font-size: 0.95rem;
		}

		.back-button {
			width: 36px;
			height: 36px;
			top: 0.75rem;
			left: 0.75rem;
		}
	}

	@media (max-width: 480px) {
		.login-page {
			padding: 0.75rem;
			padding-top: 0.75rem;
			padding-bottom: 4rem;
		}

		.login-content {
			gap: 1rem;
		}

		.logo-section {
			padding: 1.5rem 1rem;
			gap: 0.75rem;
		}

		.logo {
			width: 120px;
			height: 75px;
		}

		.logo-image {
			width: 85px;
			height: 50px;
		}

		.app-title {
			font-size: 1.5rem;
		}

		.app-subtitle {
			font-size: 0.9rem;
		}

		.auth-section {
			padding: 1.25rem 1rem;
		}

		.selection-section {
			padding: 1.5rem 1rem;
			gap: 1.5rem;
		}

		.selection-title {
			font-size: 1.35rem;
		}

		.selection-subtitle {
			font-size: 0.9rem;
		}

		.login-selection-btn {
			padding: 1.25rem 1rem;
			font-size: 0.95rem;
		}

		.employee-login-btn {
			padding: 0.75rem 1.25rem;
			font-size: 0.9rem;
			gap: 0.5rem;
		}

		.back-button {
			width: 32px;
			height: 32px;
			top: 0.5rem;
			left: 0.5rem;
		}
	}

	@media (max-width: 320px) {
		.login-page {
			padding: 0.5rem;
			padding-bottom: 5rem;
		}

		.logo {
			width: 100px;
			height: 65px;
		}

		.logo-image {
			width: 70px;
			height: 40px;
		}

		.app-title {
			font-size: 1.25rem;
		}

		.app-subtitle {
			font-size: 0.85rem;
		}

		.selection-title {
			font-size: 1.2rem;
		}

		.selection-subtitle {
			font-size: 0.85rem;
		}

		.login-selection-btn {
			padding: 1rem 0.75rem;
			font-size: 0.9rem;
		}

		.back-button {
			width: 30px;
			height: 30px;
			top: 0.5rem;
			left: 0.5rem;
		}
	}

	@media (orientation: landscape) and (max-height: 500px) {
		.login-page {
			padding: 0.75rem;
			align-items: flex-start;
		}

		.login-content {
			max-width: 600px;
		}

		.customer-login-card {
			display: flex;
		}

		.login-selection {
			flex-direction: row;
		}

		.logo-section {
			flex: 0 0 280px;
			padding: 1.5rem 1rem;
		}

		.logo {
			width: 100px;
			height: 60px;
		}

		.logo-image {
			width: 70px;
			height: 40px;
		}

		.app-title {
			font-size: 1.25rem;
			margin-bottom: 0.25rem;
		}

		.app-subtitle {
			font-size: 0.85rem;
		}

		.auth-section {
			flex: 1;
			padding: 1.5rem;
		}

		.selection-section {
			flex: 1;
			padding: 1.5rem;
		}

		.selection-title {
			font-size: 1.35rem;
		}

		.selection-buttons {
			flex-direction: row;
		}

		.login-selection-btn {
			flex: 1;
			padding: 1rem 0.75rem;
		}

		.customer-login-wrapper {
			position: relative;
			width: 100%;
		}

		.login-mask {
			position: absolute;
			top: 0;
			left: 0;
			right: 0;
			bottom: 0;
			background: rgba(0, 0, 0, 0.75);
			z-index: 10;
			backdrop-filter: blur(3px);
		}

		.employee-login-btn {
			padding: 0.75rem 1.25rem;
			font-size: 0.9rem;
		}

		.back-button {
			width: 32px;
			height: 32px;
		}
	}
</style>
