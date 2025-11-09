<script>
  import '../../app.css';
  import { page } from '$app/stores';
  import TopBar from '$lib/components/customer/TopBar.svelte';
  import BottomCartBar from '$lib/components/customer/BottomCartBar.svelte';

  // Show top bar on all customer pages except auth pages
  $: showTopBar = !$page.url.pathname.includes('/auth/') && 
                  !$page.url.pathname.includes('/customer-login') &&
                  !$page.url.pathname.includes('/login');
  
  // Hide cart bar on cart and checkout pages
  $: showCartBar = !$page.url.pathname.includes('/auth/') && 
                   !$page.url.pathname.includes('/customer-login') &&
                   !$page.url.pathname.includes('/login') &&
                   !$page.url.pathname.includes('/cart') && 
                   !$page.url.pathname.includes('/checkout');

  // Check if we're on the home page
  $: isHomePage = $page.url.pathname === '/customer' || $page.url.pathname === '/customer/';

</script>

{#if showTopBar}
  <TopBar />
{/if}

<main class="customer-main" class:with-top={showTopBar} class:with-cart={showCartBar} class:home-page={isHomePage}>
  <slot />
</main>

{#if showCartBar}
  <BottomCartBar />
{/if}

<style>
  .customer-main {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    background: var(--color-surface);
    width: 100%;
    max-width: 100vw;
    overflow-x: hidden;
    overflow-y: auto;
    box-sizing: border-box;
    -webkit-overflow-scrolling: touch;
    touch-action: pan-y;
  }

  /* Remove background on home page to allow gradient */
  .customer-main.home-page {
    background: transparent;
  }

  .customer-main.with-top {
    padding-top: 45px;
  }

  /* Add bottom padding when cart bar is visible */
  .customer-main.with-cart {
    padding-bottom: 80px;
  }
</style>