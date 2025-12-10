<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import { cartCount } from '$lib/stores/cart.js';
  import { t } from '$lib/i18n';

  let currentLanguage = 'ar';
  let notificationCount = 0;
  
  // Customer interface version
  let customerVersion = 'AQ7';

  // Subscribe to cart count updates using reactive syntax
  $: cartItemCount = $cartCount;
  
  // Determine if we should show back button (not on home page)
  $: showBackButton = $page.url.pathname !== '/customer-interface' && $page.url.pathname !== '/customer-interface/';

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
    goto('/customer-interface/notifications');
  }

  function goToCart() {
    goto('/customer-interface/cart');
  }
  
  function goToProfile() {
    goto('/customer-interface/profile');
  }
  
  function goBack() {
    // If coming from checkout, always go to home
    if ($page.url.pathname === '/customer-interface/checkout') {
      goto('/customer-interface');
    } else {
      window.history.back();
    }
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
    <!-- Left side - Back button and version -->
    <div class="left-section">
      {#if showBackButton}
        <button class="back-btn" on:click={goBack}>
          <span class="back-icon">←</span>
        </button>
      {/if}
      <span class="version-badge">{customerVersion}</span>
    </div>
    
    <!-- Right side actions -->
    <div class="top-actions" class:full-width={!showBackButton}>
      <!-- Language Toggle -->
      <button class="action-btn lang-btn" on:click={toggleLanguage} on:touchend|preventDefault={toggleLanguage}>
        <div class="icon-container">
          <svg class="action-icon-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
            <path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zm6.93 6h-2.95c-.32-1.25-.78-2.45-1.38-3.56 1.84.63 3.37 1.91 4.33 3.56zM12 4.04c.83 1.2 1.48 2.53 1.91 3.96h-3.82c.43-1.43 1.08-2.76 1.91-3.96zM4.26 14C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2 0 .68.06 1.34.14 2H4.26zm.82 2h2.95c.32 1.25.78 2.45 1.38 3.56-1.84-.63-3.37-1.9-4.33-3.56zm2.95-8H5.08c.96-1.66 2.49-2.93 4.33-3.56C8.81 5.55 8.35 6.75 8.03 8zM12 19.96c-.83-1.2-1.48-2.53-1.91-3.96h3.82c-.43 1.43-1.08 2.76-1.91 3.96zM14.34 14H9.66c-.09-.66-.16-1.32-.16-2 0-.68.07-1.35.16-2h4.68c.09.65.16 1.32.16 2 0 .68-.07 1.34-.16 2zm.25 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95c-.96 1.65-2.49 2.93-4.33 3.56zM16.36 14c.08-.66.14-1.32.14-2 0-.68-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2h-3.38z"/>
          </svg>
        </div>
      </button>

      <!-- Profile -->
      <button class="action-btn profile-btn" on:click={goToProfile} on:touchend|preventDefault={goToProfile}>
        <div class="icon-container">
          <svg class="action-icon-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
          </svg>
        </div>
      </button>

      <!-- Cart -->
      <button class="action-btn cart-btn" on:click={goToCart} on:touchend|preventDefault={goToCart}>
        <div class="icon-container">
          <svg class="action-icon-svg" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
            <path d="M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.08-.14.12-.31.12-.48 0-.55-.45-1-1-1H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z"/>
          </svg>
          {#if cartItemCount > 0}
            <span class="action-badge">{cartItemCount}</span>
          {/if}
        </div>
      </button>

      <!-- Notifications -->
      <button class="action-btn" on:click={goToNotifications} on:touchend|preventDefault={goToNotifications}>
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
    height: 45px;
  }

  .top-bar-content {
    display: flex;
    height: 100%;
    padding: 0;
    align-items: center;
    gap: 0.38rem;
  }
  
  .back-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    border: none;
    cursor: pointer;
    padding: 0.5rem 0.75rem;
    color: white;
    transition: all 0.2s ease;
    border-radius: 8px;
    margin: 0 0.5rem;
    box-shadow: 0 2px 6px rgba(59, 130, 246, 0.3);
  }
  
  .back-btn:hover {
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
    transform: translateX(-2px);
    box-shadow: 0 3px 8px rgba(59, 130, 246, 0.4);
  }

  .back-btn:active {
    transform: scale(0.95);
  }
  
  .back-icon {
    font-size: 1.2rem;
    font-weight: bold;
    line-height: 1;
  }
  
  .left-section {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .version-badge {
    font-size: 0.7rem;
    font-weight: 600;
    color: #64748b;
    background: #f1f5f9;
    padding: 0.25rem 0.5rem;
    border-radius: 6px;
    letter-spacing: 0.5px;
  }
  
  .top-actions {
    display: flex;
    align-items: center;
    gap: 0.19rem;
    margin-left: auto;
    padding-right: 0.38rem;
  }
  
  .top-actions.full-width {
    margin-left: auto;
  }

  .action-btn {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.15rem;
    padding: 0.4rem 0.5rem;
    background: none;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
    color: var(--color-ink-light);
    touch-action: manipulation;
    -webkit-tap-highlight-color: transparent;
    user-select: none;
  }

  .action-btn:hover {
    color: var(--color-primary);
    transform: scale(1.1);
  }

  .action-btn:active {
    transform: scale(0.95);
  }

  .profile-btn {
    color: #16a34a;
  }

  .profile-btn:hover {
    color: #22c55e;
  }

  .cart-btn {
    color: #f59e0b;
  }

  .cart-btn:hover {
    color: #fbbf24;
  }

  .lang-btn {
    color: #d4af37;
  }

  .lang-btn:hover {
    color: #f1c40f;
  }

  .action-icon-svg {
    width: 1.8rem;
    height: 1.8rem;
    display: block;
  }

  .icon-container {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .action-icon {
    font-size: 1.3rem;
    display: block;
    line-height: 1;
  }

  .action-badge {
    position: absolute;
    top: -0.3rem;
    right: -0.3rem;
    background: var(--color-primary);
    color: white;
    font-size: 0.6rem;
    font-weight: 600;
    padding: 0.15rem 0.35rem;
    border-radius: 10px;
    min-width: 16px;
    text-align: center;
    line-height: 1;
    z-index: 1;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }

  /* Responsive adjustments */
  @media (max-width: 480px) {
    .action-btn {
      padding: 0.35rem 0.45rem;
    }

    .action-icon {
      font-size: 1.2rem;
    }

    .action-badge {
      font-size: 0.55rem;
      padding: 0.12rem 0.3rem;
      min-width: 14px;
    }
  }
</style>

