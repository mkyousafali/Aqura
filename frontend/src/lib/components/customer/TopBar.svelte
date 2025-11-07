<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { cartCount } from '$lib/stores/cart.js';
  import { t } from '$lib/i18n';

  let currentLanguage = 'ar';
  let notificationCount = 0;

  // Subscribe to cart count updates using reactive syntax
  $: cartItemCount = $cartCount;

  // Load language from localStorage
  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }
  });

  // Listen for language changes
  function handleStorageChange(event) {
    if (event.key === 'language') {
      currentLanguage = event.newValue || 'ar';
    }
  }

  function toggleLanguage() {
    const newLanguage = currentLanguage === 'ar' ? 'en' : 'ar';
    currentLanguage = newLanguage;
    localStorage.setItem('language', newLanguage);
    
    // Update document direction
    document.documentElement.dir = newLanguage === 'ar' ? 'rtl' : 'ltr';
    document.documentElement.lang = newLanguage;
    
    // Dispatch storage event for other components
    window.dispatchEvent(new StorageEvent('storage', {
      key: 'language',
      newValue: newLanguage
    }));
  }

  function goToNotifications() {
    goto('/customer/notifications');
  }

  function goToCart() {
    goto('/customer/cart');
  }

  onMount(() => {
    window.addEventListener('storage', handleStorageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  });

  $: texts = currentLanguage === 'ar' ? {
    appName: 'أكوا إكسبرس',
    currentLang: 'العربية',
    otherLang: 'English'
  } : {
    appName: 'Aqua Express',
    currentLang: 'English',
    otherLang: 'العربية'
  };
</script>

<header class="top-bar">
  <div class="top-bar-content">
    <!-- Right side actions -->
    <div class="top-actions">
      <!-- Language Switch -->
      <div class="language-switch">
        <span class="lang-label" class:active={currentLanguage === 'ar'}>العربية</span>
        <label class="switch">
          <input 
            type="checkbox" 
            checked={currentLanguage === 'en'} 
            on:change={toggleLanguage}
          />
          <span class="slider"></span>
        </label>
        <span class="lang-label" class:active={currentLanguage === 'en'}>English</span>
      </div>

      <!-- Cart -->
      <button class="action-btn" on:click={goToCart}>
        <div class="icon-container">
          <span class="action-icon">🛒</span>
          {#if cartItemCount > 0}
            <span class="action-badge">{cartItemCount}</span>
          {/if}
        </div>
      </button>

      <!-- Notifications -->
      <button class="action-btn" on:click={goToNotifications}>
        <div class="icon-container">
          <span class="action-icon">🔔</span>
          {#if notificationCount > 0}
            <span class="action-badge">{notificationCount}</span>
          {/if}
        </div>
      </button>
    </div>
  </div>
</header>

<style>
  .top-bar {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    background: white;
    border-bottom: 1px solid var(--color-border-light);
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
    z-index: 1000;
    height: 60px;
  }

  .top-bar-content {
    display: flex;
    height: 100%;
    padding: 0;
  }

  .top-actions {
    display: flex;
    width: 100%;
    align-items: center;
  }

  .language-switch {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.5rem;
  }

  .lang-label {
    font-size: 0.75rem;
    font-weight: 500;
    color: var(--color-ink-light);
    transition: color 0.2s ease;
  }

  .lang-label.active {
    color: var(--color-primary);
    font-weight: 600;
  }

  .switch {
    position: relative;
    display: inline-block;
    width: 40px;
    height: 20px;
  }

  .switch input {
    opacity: 0;
    width: 0;
    height: 0;
  }

  .slider {
    position: absolute;
    cursor: pointer;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: var(--color-border);
    transition: 0.3s;
    border-radius: 20px;
  }

  .slider:before {
    position: absolute;
    content: "";
    height: 16px;
    width: 16px;
    left: 2px;
    bottom: 2px;
    background-color: white;
    transition: 0.3s;
    border-radius: 50%;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  input:checked + .slider {
    background-color: var(--color-primary);
  }

  input:checked + .slider:before {
    transform: translateX(20px);
  }

  .action-btn {
    flex: 1;
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-2);
    background: none;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
    color: var(--color-ink-light);
  }

  .action-btn:hover {
    color: var(--color-primary);
  }

  .icon-container {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .action-icon {
    font-size: 1.2rem;
    display: block;
  }

  .action-badge {
    position: absolute;
    top: -0.25rem;
    right: -0.25rem;
    background: var(--color-primary);
    color: white;
    font-size: 0.7rem;
    font-weight: 600;
    padding: 0.15rem 0.4rem;
    border-radius: 10px;
    min-width: 16px;
    text-align: center;
    line-height: 1;
    z-index: 1;
  }

  /* Responsive adjustments */
  @media (max-width: 480px) {
    .action-btn {
      padding: var(--space-1);
    }

    .action-icon {
      font-size: 1.1rem;
    }

    .language-switch {
      gap: 0.3rem;
      padding: 0.3rem;
    }

    .lang-label {
      font-size: 0.7rem;
    }

    .switch {
      width: 35px;
      height: 18px;
    }

    .slider:before {
      height: 14px;
      width: 14px;
    }

    input:checked + .slider:before {
      transform: translateX(17px);
    }
  }
</style>