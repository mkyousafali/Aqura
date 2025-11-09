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
    goto('/customer/start');
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
  {#if cartItems.length === 0}
    <!-- Empty Cart -->
    <div class="empty-cart">
      <div class="empty-cart-icon">🛒</div>
      <h2 class="empty-cart-title">{texts.emptyCart}</h2>
      <p class="empty-cart-message">{texts.emptyCartMessage}</p>
      <button class="continue-shopping-btn" on:click={continueShopping} on:touchend|preventDefault={continueShopping}>
        {texts.continueShopping}
      </button>
    </div>
  {:else}
    <!-- Cart Items -->
    <div class="cart-items-section">
      <h2 class="section-title">{texts.cart}</h2>
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
            </div>

            <!-- Item Actions -->
            <div class="item-actions">
              <!-- Quantity Controls -->
              <div class="quantity-controls">
                <button 
                  class="quantity-btn decrease" 
                  on:click={() => updateItemQuantity(item, -1)}
                >
                  −
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

              <!-- Remove Button -->
              <button class="remove-btn" on:click={() => removeItem(item)}>
                🗑️
              </button>
            </div>
          </div>
        {/each}
      </div>
    </div>

      <!-- Cart Summary -->
      <div class="cart-summary">
        <h2 class="section-title">{texts.subtotal}</h2>
        
        <!-- Delivery Incentive Message -->
        {#if !isFreeDelivery && total > 0}
          <div class="delivery-incentive">
            🚚 {texts.almostFreeDelivery}
          </div>
        {:else if isFreeDelivery}
          <div class="delivery-achieved">
            {texts.freeDeliveryReached}
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
  {/if}
</div>

<style>
  /* Brand colors */
  .cart-container {
    --brand-green: #16a34a;
    --brand-green-dark: #15803d;
    --brand-green-light: #22c55e;
    --brand-orange: #f59e0b;
    --brand-orange-dark: #d97706;
    --brand-orange-light: #fbbf24;
  }

  .cart-container {
    width: 100%;
    min-height: 100vh;
    margin: 0 auto;
    padding: 0.7rem;
    padding-bottom: 84px;
    max-width: 420px;
    position: relative;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    touch-action: pan-y;
    box-sizing: border-box;
    
    /* Gradient background matching home page */
    background: linear-gradient(180deg, #7ce5a5 0%, #5edda0 40%, #4dd99b 100%);
  }

  /* Orange wave - bottom layer with animation */
  .cart-container::before {
    content: '';
    position: fixed;
    width: 200%;
    height: 150px;
    bottom: 0;
    left: -50%;
    z-index: 0;
    background: #FF5C00;
    border-radius: 50% 50% 0 0 / 100% 100% 0 0;
    animation: wave 8s ease-in-out infinite;
    pointer-events: none;
  }

  /* Second wave - lighter orange */
  .cart-container::after {
    content: '';
    position: fixed;
    width: 200%;
    height: 120px;
    bottom: 0;
    left: -50%;
    z-index: 1;
    background: rgba(255, 140, 0, 0.5);
    border-radius: 50% 50% 0 0 / 80% 80% 0 0;
    animation: wave 6s ease-in-out infinite reverse;
    pointer-events: none;
  }

  @keyframes wave {
    0%, 100% {
      transform: translateX(0) translateY(0);
    }
    50% {
      transform: translateX(-25%) translateY(-10px);
    }
  }

  .section-title {
    font-size: 0.77rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 0.7rem 0;
  }

  /* Empty Cart Styles */
  .empty-cart {
    text-align: center;
    padding: 2.1rem 0.7rem;
    position: relative;
    z-index: 10;
  }

  .empty-cart-icon {
    font-size: 2.8rem;
    margin-bottom: 0.7rem;
  }

  .empty-cart-title {
    font-size: 0.84rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 0.7rem 0;
  }

  .empty-cart-message {
    font-size: 0.7rem;
    color: var(--color-ink-light);
    margin: 0 0 1.4rem 0;
    line-height: 1.5;
  }

  .continue-shopping-btn {
    background: var(--brand-green);
    color: white;
    border: none;
    padding: 0.7rem 1.4rem;
    border-radius: 8px;
    font-size: 0.7rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    position: relative;
    z-index: 100;
    touch-action: manipulation;
    pointer-events: auto;
    user-select: none;
  }

  .continue-shopping-btn:hover {
    background: var(--brand-green-dark);
  }

  /* Cart Items Section */
  .cart-items-section, .cart-summary {
    background: white;
    border: 1px solid var(--color-border-light);
    border-radius: 11px;
    padding: 1.05rem;
    margin-bottom: 1.05rem;
    box-shadow: 0 1.4px 5.6px rgba(0, 0, 0, 0.1);
    position: relative;
    z-index: 10;
  }

  .cart-items {
    display: flex;
    flex-direction: column;
    gap: 0.7rem;
  }

  .cart-item {
    display: flex;
    gap: 0.7rem;
    padding: 0.7rem;
    border: 1px solid var(--color-border-light);
    border-radius: 8px;
    background: var(--color-background);
  }

  .item-image {
    flex-shrink: 0;
    width: 42px;
    height: 42px;
    border-radius: 6px;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    background: white;
    border: 1px solid var(--color-border-light);
  }

  .item-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .image-placeholder {
    font-size: 1.05rem;
    color: var(--color-ink-light);
  }

  .item-details {
    flex: 1;
  }

  .item-name {
    font-size: 0.67rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 0.18rem 0;
    line-height: 1.3;
  }

  .item-unit {
    font-size: 0.56rem;
    color: var(--color-ink-light);
    margin-bottom: 0.18rem;
  }

  .item-price {
    font-size: 0.63rem;
    font-weight: 600;
    color: var(--brand-green);
  }

  .item-actions {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.35rem;
    justify-content: space-between;
  }

  .quantity-controls {
    display: flex;
    align-items: center;
    gap: 0.35rem;
  }

  .quantity-btn {
    width: 20px;
    height: 20px;
    border: 1px solid var(--color-border);
    background: white;
    border-radius: 4.2px;
    font-size: 0.7rem;
    font-weight: bold;
    color: var(--color-ink);
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .quantity-btn:hover {
    border-color: var(--brand-green);
    background: var(--brand-green);
    color: white;
  }

  .quantity-display {
    font-size: 0.63rem;
    font-weight: 600;
    color: var(--color-ink);
    min-width: 17px;
    text-align: center;
    padding: 0.18rem;
  }

  .item-total {
    font-size: 0.63rem;
    font-weight: 700;
    color: var(--color-ink);
  }

  .remove-btn {
    background: none;
    border: none;
    color: var(--color-danger);
    font-size: 0.84rem;
    cursor: pointer;
    padding: 0.18rem;
    border-radius: 2.8px;
    transition: all 0.2s ease;
  }

  .remove-btn:hover {
    background: var(--color-danger);
    color: white;
  }

  /* Cart Summary */
  .delivery-incentive {
    background: #fff3cd;
    border: 1px solid #ffc107;
    border-radius: 6px;
    padding: 0.7rem;
    margin-bottom: 1.05rem;
    font-size: 0.63rem;
    color: #856404;
    text-align: center;
  }

  .delivery-achieved {
    background: #d1f4e0;
    border: 1px solid var(--brand-green);
    border-radius: 6px;
    padding: 0.7rem;
    margin-bottom: 1.05rem;
    font-size: 0.63rem;
    color: var(--brand-green);
    text-align: center;
    font-weight: 600;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.53rem 0;
    border-bottom: 1px solid var(--color-border-light);
  }

  .summary-row:last-of-type {
    border-bottom: none;
  }

  .summary-label {
    font-size: 0.7rem;
    color: var(--color-ink);
  }

  .summary-value {
    font-size: 0.7rem;
    font-weight: 600;
    color: var(--color-ink);
  }

  .summary-value.free {
    color: var(--brand-green);
  }

  .total-row {
    font-size: 0.77rem;
    font-weight: 700;
    border-top: 2px solid var(--color-border-light);
    padding-top: 0.7rem;
    margin-top: 0.35rem;
  }

  .total-value {
    color: var(--brand-green) !important;
  }

  .cart-actions {
    display: flex;
    gap: 0.7rem;
    margin-top: 1.05rem;
  }

  .clear-cart-btn {
    flex: 1;
    background: rgba(239, 68, 68, 0.1);
    color: #ef4444;
    border: 1px solid rgba(239, 68, 68, 0.3);
    padding: 0.7rem;
    border-radius: 8px;
    font-size: 0.7rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .clear-cart-btn:hover {
    background: rgba(239, 68, 68, 0.2);
  }

  .checkout-btn {
    flex: 2;
    background: var(--brand-green);
    color: white;
    border: none;
    padding: 0.7rem;
    border-radius: 8px;
    font-size: 0.7rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
  }

  .checkout-btn:hover {
    background: var(--brand-green-dark);
  }
</style>