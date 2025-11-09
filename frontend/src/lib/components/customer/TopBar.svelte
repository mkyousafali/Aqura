<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { onMount } from 'svelte';
  import { cartCount } from '$lib/stores/cart.js';
  import { t } from '$lib/i18n';

  let currentLanguage = 'ar';
  let notificationCount = 0;
  let showFloatingMenu = false;

  // Subscribe to cart count updates using reactive syntax
  $: cartItemCount = $cartCount;
  
  // Determine if we should show back button (not on home page)
  $: showBackButton = $page.url.pathname !== '/customer' && $page.url.pathname !== '/customer/';

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
  
  function goBack() {
    // If coming from checkout, always go to home
    if ($page.url.pathname === '/customer/checkout') {
      goto('/customer');
    } else {
      window.history.back();
    }
  }
  
  function toggleFloatingMenu() {
    showFloatingMenu = !showFloatingMenu;
  }
  
  function goToHome() {
    showFloatingMenu = false;
    goto('/customer');
  }
  
  function goToProfile() {
    showFloatingMenu = false;
    goto('/customer/profile');
  }
  
  function handleLanguageToggle() {
    toggleLanguage();
    showFloatingMenu = false;
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
    <!-- Left side - Back button -->
    {#if showBackButton}
      <button class="back-btn" on:click={goBack}>
        <span class="back-icon">←</span>
      </button>
    {/if}
    
    <!-- Menu Button -->
    <button class="menu-btn" on:click={toggleFloatingMenu}>
      <span class="menu-icon">☰</span>
    </button>
    
    <!-- Right side actions -->
    <div class="top-actions" class:full-width={!showBackButton}>
      <!-- Cart -->
      <button class="action-btn" on:click={goToCart} on:touchend|preventDefault={goToCart}>
        <div class="icon-container">
          <span class="action-icon">🛒</span>
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

<!-- Floating Menu -->
{#if showFloatingMenu}
  <div class="floating-menu-overlay" on:click={toggleFloatingMenu}></div>
  <div class="floating-menu">
    <button class="floating-menu-btn home" on:click={goToHome}>
      <span class="floating-icon">🏠</span>
      <span class="floating-label">{currentLanguage === 'ar' ? 'الرئيسية' : 'Home'}</span>
    </button>
    
    <button class="floating-menu-btn profile" on:click={goToProfile}>
      <span class="floating-icon">👤</span>
      <span class="floating-label">{currentLanguage === 'ar' ? 'الملف الشخصي' : 'Profile'}</span>
    </button>
    
    <button class="floating-menu-btn language" on:click={handleLanguageToggle}>
      <span class="floating-icon">🌐</span>
      <span class="floating-label">{currentLanguage === 'ar' ? 'English' : 'العربية'}</span>
    </button>
    
    <button class="floating-menu-btn close" on:click={toggleFloatingMenu}>
      <span class="floating-icon">✕</span>
      <span class="floating-label">{currentLanguage === 'ar' ? 'إغلاق' : 'Close'}</span>
    </button>
  </div>
{/if}

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
    background: none;
    border: none;
    cursor: pointer;
    padding: 0.38rem 0.56rem;
    color: var(--color-ink);
    transition: color 0.2s ease;
  }
  
  .back-btn:hover {
    color: var(--color-primary);
  }
  
  .back-icon {
    font-size: 1.13rem;
    font-weight: bold;
    line-height: 1;
  }
  
  .menu-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--color-primary);
    border: none;
    cursor: pointer;
    padding: 0.38rem 0.56rem;
    color: white;
    transition: all 0.2s ease;
    border-radius: 6px;
    margin: 0 0.38rem;
  }
  
  .menu-btn:hover {
    background: var(--color-primary-dark);
    transform: scale(1.05);
  }
  
  .menu-icon {
    font-size: 0.98rem;
    font-weight: bold;
    line-height: 1;
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
  
  /* Floating Menu Styles */
  .floating-menu-overlay {
    position: fixed;
    top: 60px;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.3);
    z-index: 999;
    animation: fadeIn 0.2s ease;
  }
  
  .floating-menu {
    position: fixed;
    top: 70px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    z-index: 1001;
    animation: slideDown 0.3s ease;
  }
  
  .floating-menu-btn {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 1rem;
    padding: 1rem 1.5rem;
    background: white;
    border: 2px solid var(--color-primary);
    border-radius: 16px;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    min-width: 200px;
  }
  
  .floating-menu-btn:hover {
    transform: translateY(-3px);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
    background: var(--color-primary-light);
  }
  
  .floating-menu-btn:active {
    transform: translateY(-1px);
  }
  
  .floating-menu-btn.home {
    border-color: #16a34a;
  }
  
  .floating-menu-btn.profile {
    border-color: #3b82f6;
  }
  
  .floating-menu-btn.language {
    border-color: #f59e0b;
  }
  
  .floating-menu-btn.close {
    border-color: #ef4444;
    background: #fee;
  }
  
  .floating-menu-btn.close:hover {
    background: #ef4444;
  }
  
  .floating-menu-btn.close:hover .floating-label {
    color: white;
  }
  
  .floating-icon {
    font-size: 1.5rem;
    line-height: 1;
  }
  
  .floating-label {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--color-ink);
    text-align: left;
    flex: 1;
  }
  
  @keyframes fadeIn {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }
  
  @keyframes slideDown {
    from {
      opacity: 0;
      transform: translateX(-50%) translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateX(-50%) translateY(0);
    }
  }
  
  @media (max-width: 480px) {
    .floating-menu {
      flex-direction: column;
      gap: 0.5rem;
      padding: 0 1rem;
      max-width: calc(100vw - 2rem);
      left: 50%;
      transform: translateX(-50%);
    }
    
    .floating-menu-btn {
      min-width: auto;
      width: 100%;
      padding: 0.75rem 1rem;
    }
    
    .floating-icon {
      font-size: 1.3rem;
    }
    
    .floating-label {
      font-size: 0.85rem;
    }
  }
</style>