<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { cartStore, cartActions, cartTotal, cartCount } from '$lib/stores/cart.js';
  
  let currentLanguage = 'ar';
  
  // Delivery fee calculation
  const deliveryFee = 15.00; // SAR
  const freeDeliveryThreshold = 500.00; // SAR

  // Subscribe to cart updates using reactive syntax
  $: cartItems = $cartStore;
  $: total = $cartTotal;
  $: itemCount = $cartCount;

  // Calculate final totals
  $: isFreeDelivery = total >= freeDeliveryThreshold;
  $: finalDeliveryFee = isFreeDelivery ? 0 : deliveryFee;
  $: finalTotal = total + finalDeliveryFee;

  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }
  });

  function updateItemQuantity(item, change) {
    const newQuantity = Math.max(0, item.quantity + change);
    
    if (newQuantity === 0) {
      cartActions.removeFromCart(item.id, item.selectedUnit?.id);
    } else {
      cartActions.updateQuantity(item.id, item.selectedUnit?.id, newQuantity);
    }
  }

  function removeItem(item) {
    cartActions.removeFromCart(item.id, item.selectedUnit?.id);
  }

  function clearCart() {
    cartActions.clearCart();
  }

  function proceedToCheckout() {
    // Navigate to checkout page (to be implemented)
    goto('/customer/checkout');
  }

  function continueShopping() {
    goto('/customer/products');
  }

  // Language texts
  $: texts = currentLanguage === 'ar' ? {
    title: 'سلة التسوق - أكوا إكسبرس',
    cart: 'السلة',
    emptyCart: 'السلة فارغة',
    emptyCartMessage: 'لم تقم بإضافة أي منتجات بعد',
    continueShopping: 'متابعة التسوق',
    item: 'منتج',
    items: 'منتجات',
    subtotal: 'المجموع الفرعي',
    delivery: 'التوصيل',
    freeDelivery: 'توصيل مجاني!',
    total: 'المجموع النهائي',
    checkout: 'إنهاء الطلب',
    clearCart: 'إفراغ السلة',
    remove: 'إزالة',
    sar: 'ر.س',
    almostFreeDelivery: `أضف ${(freeDeliveryThreshold - total).toFixed(2)} ر.س أكثر للحصول على توصيل مجاني!`,
    freeDeliveryReached: 'تم الوصول للتوصيل المجاني! 🎉'
  } : {
    title: 'Shopping Cart - Aqua Express',
    cart: 'Cart',
    emptyCart: 'Cart is Empty',
    emptyCartMessage: 'You haven\'t added any products yet',
    continueShopping: 'Continue Shopping',
    item: 'item',
    items: 'items',
    subtotal: 'Subtotal',
    delivery: 'Delivery',
    freeDelivery: 'Free Delivery!',
    total: 'Total',
    checkout: 'Checkout',
    clearCart: 'Clear Cart',
    remove: 'Remove',
    sar: 'SAR',
    almostFreeDelivery: `Add ${(freeDeliveryThreshold - total).toFixed(2)} SAR more for free delivery!`,
    freeDeliveryReached: 'Free delivery achieved! 🎉'
  };
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="cart-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <div class="cart-header">
    <h1 class="cart-title">{texts.cart}</h1>
    {#if itemCount > 0}
      <span class="item-count">
        {itemCount} {itemCount === 1 ? texts.item : texts.items}
      </span>
    {/if}
  </div>

  {#if cartItems.length === 0}
    <!-- Empty Cart -->
    <div class="empty-cart">
      <div class="empty-cart-icon">🛒</div>
      <h2 class="empty-cart-title">{texts.emptyCart}</h2>
      <p class="empty-cart-message">{texts.emptyCartMessage}</p>
      <button class="continue-shopping-btn" on:click={continueShopping}>
        {texts.continueShopping}
      </button>
    </div>
  {:else}
    <!-- Cart Items -->
    <div class="cart-content">
      <div class="cart-items">
        {#each cartItems as item}
          <div class="cart-item">
            <!-- Product Image -->
            <div class="item-image">
              {#if item.image}
                <img src={item.image} alt={item.name} />
              {:else}
                <div class="image-placeholder">📦</div>
              {/if}
            </div>

            <!-- Product Details -->
            <div class="item-details">
              <h3 class="item-name">
                {currentLanguage === 'ar' ? item.name : (item.nameEn || item.name)}
              </h3>
              
              {#if item.selectedUnit}
                <div class="item-unit">
                  {currentLanguage === 'ar' ? item.selectedUnit.nameAr : item.selectedUnit.nameEn}
                </div>
              {/if}

              <div class="item-price">
                {item.price.toFixed(2)} {texts.sar}
              </div>

              <!-- Quantity Controls -->
              <div class="quantity-controls">
                <button 
                  class="quantity-btn decrease" 
                  on:click={() => updateItemQuantity(item, -1)}
                >
                  -
                </button>
                <span class="quantity-display">{item.quantity}</span>
                <button 
                  class="quantity-btn increase" 
                  on:click={() => updateItemQuantity(item, 1)}
                >
                  +
                </button>
              </div>

              <!-- Item Total -->
              <div class="item-total">
                {(item.price * item.quantity).toFixed(2)} {texts.sar}
              </div>
            </div>

            <!-- Remove Button -->
            <button class="remove-btn" on:click={() => removeItem(item)}>
              <span class="remove-icon">🗑️</span>
            </button>
          </div>
        {/each}
      </div>

      <!-- Cart Summary -->
      <div class="cart-summary">
        <!-- Delivery Incentive Message -->
        {#if !isFreeDelivery && total > 0}
          <div class="delivery-incentive">
            <div class="incentive-icon">🚚</div>
            <div class="incentive-text">
              {texts.almostFreeDelivery}
            </div>
          </div>
        {:else if isFreeDelivery}
          <div class="delivery-achieved">
            <div class="achieved-icon">🎉</div>
            <div class="achieved-text">
              {texts.freeDeliveryReached}
            </div>
          </div>
        {/if}

        <!-- Summary Breakdown -->
        <div class="summary-row">
          <span class="summary-label">{texts.subtotal}</span>
          <span class="summary-value">{total.toFixed(2)} {texts.sar}</span>
        </div>

        <div class="summary-row">
          <span class="summary-label">{texts.delivery}</span>
          <span class="summary-value" class:free={isFreeDelivery}>
            {#if isFreeDelivery}
              {texts.freeDelivery}
            {:else}
              {finalDeliveryFee.toFixed(2)} {texts.sar}
            {/if}
          </span>
        </div>

        <div class="summary-divider"></div>

        <div class="summary-row total-row">
          <span class="summary-label">{texts.total}</span>
          <span class="summary-value total-value">{finalTotal.toFixed(2)} {texts.sar}</span>
        </div>

        <!-- Action Buttons -->
        <div class="cart-actions">
          <button class="clear-cart-btn" on:click={clearCart}>
            {texts.clearCart}
          </button>
          <button class="checkout-btn" on:click={proceedToCheckout}>
            {texts.checkout}
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .cart-container {
    padding: 1rem;
    max-width: 800px;
    margin: 0 auto;
    min-height: 100vh;
  }

  .cart-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid var(--color-border);
  }

  .cart-title {
    font-size: 1.75rem;
    font-weight: 700;
    color: var(--color-ink);
    margin: 0;
  }

  .item-count {
    font-size: 1rem;
    color: var(--color-ink-light);
    background: var(--color-background);
    padding: 0.5rem 1rem;
    border-radius: 20px;
  }

  /* Empty Cart Styles */
  .empty-cart {
    text-align: center;
    padding: 4rem 2rem;
  }

  .empty-cart-icon {
    font-size: 5rem;
    margin-bottom: 2rem;
    opacity: 0.5;
  }

  .empty-cart-title {
    font-size: 1.5rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 1rem 0;
  }

  .empty-cart-message {
    font-size: 1rem;
    color: var(--color-ink-light);
    margin: 0 0 2rem 0;
    line-height: 1.5;
  }

  .continue-shopping-btn {
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 1rem 2rem;
    border-radius: 12px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
  }

  .continue-shopping-btn:hover {
    background: var(--color-primary-dark);
  }

  /* Cart Content */
  .cart-content {
    display: flex;
    flex-direction: column;
    gap: 2rem;
  }

  .cart-items {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .cart-item {
    display: flex;
    gap: 1rem;
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid var(--color-border);
    position: relative;
  }

  .item-image {
    width: 80px;
    height: 80px;
    background: var(--color-background);
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .item-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 8px;
  }

  .image-placeholder {
    font-size: 2rem;
    color: var(--color-ink-light);
    opacity: 0.5;
  }

  .item-details {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .item-name {
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0;
    line-height: 1.3;
  }

  .item-unit {
    font-size: 0.9rem;
    color: var(--color-ink-light);
    background: var(--color-background);
    padding: 0.25rem 0.75rem;
    border-radius: 15px;
    align-self: flex-start;
  }

  .item-price {
    font-size: 1rem;
    color: var(--color-primary);
    font-weight: 600;
  }

  .quantity-controls {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-top: 0.5rem;
  }

  .quantity-btn {
    width: 32px;
    height: 32px;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 50%;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s ease;
  }

  .quantity-btn:hover {
    background: var(--color-primary-dark);
  }

  .quantity-display {
    font-size: 1rem;
    font-weight: 600;
    color: var(--color-ink);
    min-width: 30px;
    text-align: center;
  }

  .item-total {
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--color-primary);
    margin-top: auto;
  }

  .remove-btn {
    position: absolute;
    top: 1rem;
    right: 1rem;
    background: rgba(239, 68, 68, 0.1);
    color: #ef4444;
    border: none;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s ease;
  }

  .remove-btn:hover {
    background: rgba(239, 68, 68, 0.2);
  }

  .remove-icon {
    font-size: 1rem;
  }

  /* Cart Summary */
  .cart-summary {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    border: 1px solid var(--color-border);
    position: sticky;
    top: 1rem;
  }

  .delivery-incentive {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    background: var(--color-warning-light);
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1.5rem;
    border: 1px solid var(--color-warning);
  }

  .incentive-icon {
    font-size: 1.5rem;
  }

  .incentive-text {
    font-size: 0.9rem;
    color: var(--color-warning);
    font-weight: 500;
    line-height: 1.3;
  }

  .delivery-achieved {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    background: var(--color-success-light);
    padding: 1rem;
    border-radius: 8px;
    margin-bottom: 1.5rem;
    border: 1px solid var(--color-success);
  }

  .achieved-icon {
    font-size: 1.5rem;
  }

  .achieved-text {
    font-size: 0.9rem;
    color: var(--color-success);
    font-weight: 500;
    line-height: 1.3;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.75rem;
  }

  .summary-label {
    font-size: 1rem;
    color: var(--color-ink);
  }

  .summary-value {
    font-size: 1rem;
    font-weight: 600;
    color: var(--color-ink);
  }

  .summary-value.free {
    color: var(--color-success);
  }

  .summary-divider {
    height: 1px;
    background: var(--color-border);
    margin: 1rem 0;
  }

  .total-row {
    margin-bottom: 1.5rem;
  }

  .total-row .summary-label {
    font-size: 1.25rem;
    font-weight: 600;
  }

  .total-value {
    font-size: 1.5rem !important;
    font-weight: 700 !important;
    color: var(--color-primary) !important;
  }

  .cart-actions {
    display: flex;
    gap: 1rem;
  }

  .clear-cart-btn {
    flex: 1;
    background: rgba(239, 68, 68, 0.1);
    color: #ef4444;
    border: 1px solid rgba(239, 68, 68, 0.3);
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .clear-cart-btn:hover {
    background: rgba(239, 68, 68, 0.2);
  }

  .checkout-btn {
    flex: 2;
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
  }

  .checkout-btn:hover {
    background: var(--color-primary-dark);
  }

  /* Mobile Responsive */
  @media (max-width: 768px) {
    .cart-container {
      padding: 1rem 0.75rem;
    }

    .cart-header {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
    }

    .cart-content {
      flex-direction: column;
    }

    .cart-item {
      padding: 1rem;
    }

    .item-image {
      width: 60px;
      height: 60px;
    }

    .cart-actions {
      flex-direction: column;
    }

    .checkout-btn {
      order: -1; /* Put checkout button first on mobile */
    }
  }
</style>