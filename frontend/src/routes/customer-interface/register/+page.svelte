<script lang="ts">
  import CustomerLogin from '$lib/components/customer-interface/common/CustomerLogin.svelte';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { isAuthenticated, currentUser } from '$lib/utils/persistentAuth';
  import { _, switchLocale, currentLocale } from '$lib/i18n';

  let mounted = false;
  let showContent = false;

  onMount(() => {
    mounted = true;
    setTimeout(() => {
      showContent = true;
    }, 300);

    if ($isAuthenticated && $currentUser) {
      goto('/customer-interface');
    }
  });

  function handleRegistrationSuccess(event: CustomEvent) {
    const { detail } = event;
    if (detail.type === 'customer_login' || detail.type === 'customer_register') {
      goto('/customer-interface');
    }
  }

  function goToLogin() {
    goto('/customer-interface/login');
  }
</script>

<svelte:head>
  <title>{$_('customer.login.registerTitle') || 'Customer Registration'} - Aqura</title>
  <meta name="description" content="Register for Aqura Customer Portal access" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
  <meta name="theme-color" content="#059669" />
  <meta name="mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="default" />
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="register-page" class:mounted>
  {#if showContent}
    <div class="register-content">
      <div class="register-card">
        <!-- Header -->
        <div class="page-header">
          <button 
            class="back-btn"
            on:click={goToLogin}
            title={$_('common.back') || 'Back'}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M19 12H5M12 19l-7-7 7-7"/>
            </svg>
            {$_('customer.login.loginButton') || 'Login'}
          </button>

          <div class="header-title">
            <h1>{$_('customer.login.registerTitle') || 'Create Account'}</h1>
          </div>

          <button 
            class="language-toggle" 
            on:click={() => {
              switchLocale($currentLocale === 'ar' ? 'en' : 'ar');
              setTimeout(() => {
                window.location.reload();
              }, 100);
            }}
            title={$_('nav.languageToggle') || 'Switch Language'}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <path d="M8 12h8"/>
              <path d="M12 8v8"/>
            </svg>
            {$currentLocale === 'ar' ? 'EN' : 'AR'}
          </button>
        </div>

        <!-- Registration Form -->
        <div class="register-form-container">
          <CustomerLogin 
            initialView="register"
            showMask={false}
            on:success={handleRegistrationSuccess}
          />
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .register-page {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #ecfdf5 0%, #f0fdf4 100%);
    padding: 1rem;
    opacity: 0;
    transition: opacity 0.3s ease-out;
  }

  .register-page.mounted {
    opacity: 1;
  }

  .register-content {
    width: 100%;
    max-width: 480px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .register-card {
    width: 100%;
    background: white;
    border-radius: 16px;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1),
      0 10px 20px rgba(5, 150, 105, 0.08);
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
    background: linear-gradient(135deg, #059669 0%, #10B981 100%);
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

  .register-form-container {
    padding: 2rem 1.5rem;
  }

  /* Responsive Design */
  @media (max-width: 640px) {
    .register-page {
      padding: 0;
    }

    .register-card {
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

    .register-form-container {
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

    .register-form-container {
      padding: 1.25rem;
    }
  }
</style>
