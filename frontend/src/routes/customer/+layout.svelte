<script>
  import '../../app.css';
  import { page } from '$app/stores';
  import TopBar from '$lib/components/customer/TopBar.svelte';
  import BottomNav from '$lib/components/customer/BottomNav.svelte';
  import BottomCartBar from '$lib/components/customer/BottomCartBar.svelte';

  // Show navigation on all customer pages except auth pages
  $: showNavigation = !$page.url.pathname.includes('/auth/') && 
                      !$page.url.pathname.includes('/customer-login') &&
                      !$page.url.pathname.includes('/login');
  
  // Hide cart bar on cart, checkout, and finalize pages
  $: showCartBar = showNavigation && 
                   !$page.url.pathname.includes('/cart') && 
                   !$page.url.pathname.includes('/checkout') && 
                   !$page.url.pathname.includes('/finalize');
</script>

{#if showNavigation}
  <TopBar />
{/if}

<main class="customer-main" class:with-nav={showNavigation}>
  <slot />
</main>

{#if showCartBar}
  <BottomCartBar />
{/if}
{#if showNavigation}
  <BottomNav />
{/if}

<style>
  .customer-main {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    background: var(--color-surface);
  }

  .customer-main.with-nav {
    padding-top: 60px;
    padding-bottom: 80px;
  }
</style>