<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';

  let currentLanguage = 'ar';

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

  onMount(() => {
    window.addEventListener('storage', handleStorageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  });

  $: texts = currentLanguage === 'ar' ? {
    home: 'الرئيسية',
    products: 'المنتجات', 
    profile: 'الحساب'
  } : {
    home: 'Home',
    products: 'Products',
    profile: 'Profile'
  };

  const navigationItems = [
    { path: '/customer', icon: '🏠', labelKey: 'home' },
    { path: '/customer/products', icon: '📦', labelKey: 'products' },
    { path: '/customer/profile', icon: '👤', labelKey: 'profile' }
  ];

  function isActive(path) {
    if (path === '/customer') {
      return $page.url.pathname === '/customer';
    }
    return $page.url.pathname.startsWith(path);
  }

  function navigate(path) {
    goto(path);
  }
</script>

<nav class="bottom-nav">
  {#each navigationItems as item}
    <button 
      class="nav-item" 
      class:active={isActive(item.path)}
      on:click={() => navigate(item.path)}
    >
      <span class="nav-icon">{item.icon}</span>
      <span class="nav-label">{texts[item.labelKey]}</span>
    </button>
  {/each}
</nav>

<style>
  .bottom-nav {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: white;
    border-top: 1px solid var(--color-border-light);
    display: flex;
    padding: var(--space-2) 0;
    box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
    z-index: 100;
  }

  .nav-item {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-2);
    border: none;
    background: none;
    cursor: pointer;
    transition: all 0.2s ease;
    color: var(--color-ink-light);
  }

  .nav-item.active {
    color: var(--color-primary);
  }

  .nav-item:hover {
    color: var(--color-primary);
  }

  .nav-icon {
    font-size: 1.2rem;
  }

  .nav-label {
    font-size: 0.75rem;
    font-weight: 500;
  }
</style>
