<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { localeData, _, switchLocale, currentLocale } from '$lib/i18n';
	import CustomerLogin from '$lib/components/customer-interface/common/CustomerLogin.svelte';

	// Check if customer is already logged in
	onMount(() => {
		const customerSession = localStorage.getItem('customer_session');
		
		if (customerSession) {
			try {
				const customerData = JSON.parse(customerSession);
				if (customerData.registration_status === 'approved') {
					// Customer is already logged in, redirect to dashboard
					goto('/customer-interface');
					return;
				}
			} catch (error) {
				// Invalid session, clear it
				localStorage.removeItem('customer_session');
			}
		}
	});

	function handleCustomerSuccess(event) {
		const { detail } = event;
		if (detail.type === 'customer_login') {
			// Redirect to customer dashboard
			goto('/customer-interface');
		}
	}
</script>

<svelte:head>
	<title>Customer Login - Aqura Management System</title>
	<meta name="description" content="Customer portal login for Aqura Management System" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
	<meta name="theme-color" content="#15A34A" />
	<meta name="mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="default" />
</svelte:head>

<!-- Customer-focused login page -->
<div class="customer-login-page">
	<div class="login-content">
		<!-- Main Login Card for Customers -->
		<div class="customer-login-card">
		<!-- Logo Section -->
		<div class="logo-section">
			<div class="logo">
				<img src="/icons/logo.png" alt="Aqura Logo" class="logo-image" />
			</div>
			<div class="logo-content">
				<h1 class="app-title">Customer Portal</h1>
				<p class="app-subtitle">Access your account and services</p>
			</div>
		</div>				<!-- Customer Login Section -->
			<div class="auth-section">
				<CustomerLogin on:success={handleCustomerSuccess} />
			</div>
		</div>
	</div>
</div>

<style>
	/* Global mobile fixes */
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

	/* Prevent iOS zoom on input focus */
	:global(input, select, textarea) {
		font-size: 16px !important;
	}

	.customer-login-page {
		width: 100%;
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		align-items: flex-start;
		justify-content: center;
		padding: 1rem;
		padding-top: 2rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		position: relative;
		overflow-x: hidden;
		overflow-y: auto;
		font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
		box-sizing: border-box;
	}

	/* Background pattern */
	.customer-login-page::before {
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

	.login-content {
		width: 100%;
		max-width: 500px;
		position: relative;
		z-index: 1;
		margin: 1rem 0;
		min-height: 0;
	}

	.customer-login-card {
		background: rgba(255, 255, 255, 0.95);
		backdrop-filter: blur(20px);
		border-radius: 20px;
		box-shadow: 0 25px 50px rgba(0, 0, 0, 0.2);
		border: 1px solid rgba(255, 255, 255, 0.2);
		overflow: hidden;
		margin-bottom: 2rem;
	}

	/* Logo section specifically for customers */
	.logo-section {
		text-align: center;
		padding: 3rem 2rem 2rem;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
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
		width: 180px;
		height: 110px;
		margin: 0 auto 1.5rem;
		background: #FFFFFF;
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
		border-radius: 10px;
		object-fit: contain;
	}

	.logo-content .app-title {
		font-size: 2.25rem;
		font-weight: 700;
		margin-bottom: 0.5rem;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
	}

	.logo-content .app-subtitle {
		font-size: 1.1rem;
		opacity: 0.9;
		font-weight: 300;
		margin: 0;
	}

	/* Authentication section */
	.auth-section {
		padding: 2.5rem;
	}

	/* Override CustomerLogin component styles to match */
	.auth-section :global(.customer-login-container) {
		padding: 0;
		margin: 0;
		background: transparent;
		border: none;
		box-shadow: none;
	}

	.auth-section :global(.customer-header) {
		margin-top: 0;
		text-align: center;
	}

	.auth-section :global(.customer-header h2) {
		color: #374151;
		font-size: 1.5rem;
		margin-bottom: 0.5rem;
	}

	.auth-section :global(.customer-header p) {
		color: #6B7280;
		font-size: 1rem;
	}

	/* Help section */
	.help-section {
		background: #F8FAFC;
		padding: 2rem 2.5rem;
		border-top: 1px solid #E5E7EB;
	}

	.help-content h3 {
		color: #374151;
		font-size: 1.25rem;
		font-weight: 600;
		margin-bottom: 1rem;
	}

	.help-content p {
		color: #6B7280;
		margin-bottom: 1rem;
		line-height: 1.6;
	}

	.help-content ul {
		color: #6B7280;
		margin-bottom: 1.5rem;
		padding-left: 1.5rem;
		line-height: 1.6;
	}

	.help-content li {
		margin-bottom: 0.5rem;
	}

	.contact-info {
		text-align: center;
	}

	.whatsapp-link {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.75rem 1.5rem;
		background: #25D366;
		color: white;
		text-decoration: none;
		border-radius: 10px;
		font-weight: 500;
		transition: all 0.3s ease;
		box-shadow: 0 4px 12px rgba(37, 211, 102, 0.3);
	}

	.whatsapp-link:hover {
		background: #128C7E;
		transform: translateY(-2px);
		box-shadow: 0 6px 20px rgba(37, 211, 102, 0.4);
	}

	/* Mobile responsive */
	@media (max-width: 768px) {
		.customer-login-page {
			padding: 1rem;
			padding-top: 1rem;
			padding-bottom: 4rem;
		}

		.login-content {
			max-width: 100%;
			margin: 0;
		}

		.logo-section {
			padding: 2rem 1.5rem 1.5rem;
		}

		.logo {
			width: 140px;
			height: 85px;
			margin-bottom: 1rem;
		}

		.logo-image {
			width: 95px;
			height: 55px;
		}

		.logo-content .app-title {
			font-size: 1.875rem;
		}

		.logo-content .app-subtitle {
			font-size: 1rem;
		}

		.auth-section {
			padding: 2rem 1.5rem;
		}

		.help-section {
			padding: 1.5rem;
		}
	}

	@media (max-width: 480px) {
		.customer-login-page {
			padding: 0.75rem;
			padding-top: 0.5rem;
			padding-bottom: 3rem;
		}

		.customer-login-card {
			border-radius: 16px;
		}

		.logo-section {
			padding: 1.5rem 1rem;
		}

		.logo {
			width: 120px;
			height: 75px;
		}

		.logo-image {
			width: 85px;
			height: 50px;
		}

		.logo-content .app-title {
			font-size: 1.625rem;
		}

		.logo-content .app-subtitle {
			font-size: 0.9rem;
		}

		.auth-section {
			padding: 1.5rem 1rem;
		}

		.help-section {
			padding: 1.25rem 1rem;
		}

		.help-content h3 {
			font-size: 1.125rem;
		}

		.help-content ul {
			padding-left: 1rem;
		}
	}

	@media (max-width: 320px) {
		.customer-login-page {
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

		.logo-content .app-title {
			font-size: 1.5rem;
		}

		.help-content h3 {
			font-size: 1rem;
		}
	}

	/* Landscape mobile fixes */
	@media (orientation: landscape) and (max-height: 500px) {
		.customer-login-page {
			padding: 0.75rem;
			align-items: flex-start;
		}

		.customer-login-card {
			display: flex;
			flex-direction: row;
		}

		.logo-section {
			flex: 0 0 250px;
			padding: 1.5rem 1rem;
		}

		.logo {
			width: 80px;
			height: 50px;
			margin-bottom: 0.75rem;
		}

		.logo-image {
			width: 60px;
			height: 35px;
		}

		.logo-content .app-title {
			font-size: 1.25rem;
		}

		.logo-content .app-subtitle {
			font-size: 0.825rem;
		}

		.auth-section {
			flex: 1;
			padding: 1.5rem;
		}

		.help-section {
			display: none; /* Hide help section in landscape mobile */
		}
	}
</style>
