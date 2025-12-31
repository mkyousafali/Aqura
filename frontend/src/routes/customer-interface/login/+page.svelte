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

	onMount(async () => {
		mounted = true;
		setTimeout(() => {
			showContent = true;
		}, 300);

		checkExistingAuth();
	});

	function checkExistingAuth() {
		if ($isAuthenticated && $currentUser) {
			goto('/customer-interface');
		}
	}

	function handleCustomerSuccess(event) {
		const { detail } = event;
		if (detail.type === 'customer_login') {
			goto('/customer-interface');
		}
	}

	function goBackToMain() {
		goto('/login/customer');
	}
</script>

<svelte:head>
	<title>Customer Login - Aqura Management System</title>
	<meta name="description" content="Access your Aqura Customer Interface" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#15A34A" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
	<meta name="google" content="notranslate" />
	<meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="login-page" class:mounted>
	{#if showContent}
		<div class="login-content">
			<div class="customer-login-page">
				<div class="page-header">
					<button 
						class="back-btn"
						on:click={goBackToMain}
						title={$_('common.back')}
					>
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M19 12H5M12 19l-7-7 7-7"/>
						</svg>
						{t('common.back')}
					</button>

					<div class="header-title">
						<h1>{t('customer.login.title') || 'Customer Login'}</h1>
					</div>

					<button 
						class="language-toggle" 
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
						{$currentLocale === 'ar' ? 'EN' : 'AR'}
					</button>
				</div>

				<div class="login-form-container">
					<CustomerLogin 
						initialView="login"
						showMask={false}
						on:success={handleCustomerSuccess}
					/>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.login-page {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #f0f9ff 0%, #f0fdf4 100%);
		padding: 1rem;
		opacity: 0;
		transition: opacity 0.3s ease-out;
	}

	.login-page.mounted {
		opacity: 1;
	}

	.login-content {
		width: 100%;
		max-width: 480px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.customer-login-page {
		width: 100%;
		background: white;
		border-radius: 16px;
		box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1),
			0 10px 20px rgba(139, 92, 246, 0.08);
		overflow: hidden;
		animation: slideUp 0.5s ease-out;
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(20px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.page-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1.5rem;
		background: linear-gradient(135deg, #8B5CF6 0%, #A78BFA 100%);
		color: white;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
	}

	.back-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		color: white;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition: all 0.3s ease;
	}

	.back-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
	}

	.back-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.header-title {
		flex: 1;
		text-align: center;
	}

	.header-title h1 {
		margin: 0;
		font-size: 1.5rem;
		font-weight: 700;
		letter-spacing: -0.5px;
	}

	.language-toggle {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: rgba(255, 255, 255, 0.1);
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 8px;
		color: white;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 600;
		transition: all 0.3s ease;
		min-width: 80px;
		justify-content: center;
	}

	.language-toggle:hover {
		background: rgba(255, 255, 255, 0.2);
		border-color: rgba(255, 255, 255, 0.3);
	}

	.login-form-container {
		padding: 2rem 1.5rem;
	}

	/* Responsive Design */
	@media (max-width: 640px) {
		.login-page {
			padding: 0;
		}

		.customer-login-page {
			border-radius: 0;
			box-shadow: none;
		}

		.page-header {
			padding: 1rem;
			gap: 0.5rem;
		}

		.header-title h1 {
			font-size: 1.25rem;
		}

		.back-btn,
		.language-toggle {
			font-size: 0.75rem;
			padding: 0.4rem 0.8rem;
		}

		.login-form-container {
			padding: 1.5rem 1rem;
		}
	}

	@media (max-width: 480px) {
		.page-header {
			flex-wrap: wrap;
			gap: 0.75rem;
		}

		.header-title {
			width: 100%;
			order: 1;
		}

		.header-title h1 {
			font-size: 1.125rem;
		}

		.back-btn {
			order: 2;
			flex: 1;
		}

		.language-toggle {
			order: 3;
			flex: 1;
		}

		.login-form-container {
			padding: 1.25rem;
		}
	}
</style>
