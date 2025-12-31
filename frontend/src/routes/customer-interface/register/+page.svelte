<script lang="ts">
  import CustomerLogin from '$lib/components/customer-interface/common/CustomerLogin.svelte';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { isAuthenticated } from '$lib/utils/persistentAuth';

  // Redirect if already logged in
  onMount(() => {
    if ($isAuthenticated) {
      goto('/');
    }
  });
</script>

<svelte:head>
  <title>Customer Registration - Aqura</title>
  <meta name="description" content="Register for Aqura Customer Portal access" />
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="registration-page">
  <div class="registration-container">
    <div class="registration-header">
      <div class="company-logo">
        <h1>أیکورا</h1>
        <span class="logo-subtitle">AQURA</span>
      </div>
      <button class="lang-toggle">العربية</button>
    </div>

    <div class="registration-content">
      <CustomerLogin initialView="register" />
    </div>

    <div class="registration-footer">
      <p>Already have an account? <a href="/login">Sign in here</a></p>
    </div>
  </div>
</div>

<style>
  .registration-page {
    min-height: 100vh;
    background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem;
  }

  .registration-container {
    background: white;
    border-radius: 20px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    width: 100%;
    max-width: 500px;
    animation: fadeInUp 0.6s ease-out;
  }

  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(30px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .registration-header {
    background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
    color: white;
    padding: 2rem;
    text-align: center;
    position: relative;
  }

  .company-logo {
    background: #ffc107;
    color: #2d3748;
    padding: 1rem 1.5rem;
    border-radius: 12px;
    display: inline-block;
    margin-bottom: 1rem;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .company-logo h1 {
    font-size: 1.8rem;
    font-weight: 700;
    margin: 0;
    font-family: 'Arial', sans-serif;
  }

  .logo-subtitle {
    font-size: 0.9rem;
    font-weight: 500;
    display: block;
    margin-top: 0.25rem;
  }

  .lang-toggle {
    position: absolute;
    top: 1rem;
    right: 1rem;
    background: rgba(255, 255, 255, 0.2);
    color: white;
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 8px;
    padding: 0.5rem 1rem;
    font-size: 0.85rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .lang-toggle:hover {
    background: rgba(255, 255, 255, 0.3);
  }

  .registration-content {
    padding: 0;
  }

  .registration-footer {
    background: #f8fafc;
    padding: 1.5rem 2rem;
    text-align: center;
    border-top: 1px solid #e2e8f0;
  }

  .registration-footer p {
    margin: 0;
    color: #64748b;
    font-size: 0.9rem;
  }

  .registration-footer a {
    color: #48bb78;
    text-decoration: none;
    font-weight: 500;
  }

  .registration-footer a:hover {
    text-decoration: underline;
  }

  /* Responsive Design */
  @media (max-width: 768px) {
    .registration-page {
      padding: 1rem;
    }

    .registration-container {
      border-radius: 12px;
    }

    .registration-header {
      padding: 1.5rem;
    }

    .company-logo h1 {
      font-size: 1.5rem;
    }

    .registration-footer {
      padding: 1rem 1.5rem;
    }
  }
</style>
