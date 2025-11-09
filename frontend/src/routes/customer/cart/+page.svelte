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
  <!-- Individual floating bubbles -->
  <div class="floating-bubbles">
    <div class="bubble bubble-orange bubble-1"></div>
    <div class="bubble bubble-blue bubble-2"></div>
    <div class="bubble bubble-green bubble-3"></div>
    <div class="bubble bubble-pink bubble-4"></div>
    <div class="bubble bubble-orange bubble-5"></div>
    <div class="bubble bubble-blue bubble-6"></div>
    <div class="bubble bubble-green bubble-7"></div>
    <div class="bubble bubble-pink bubble-8"></div>
    <div class="bubble bubble-orange bubble-9"></div>
    <div class="bubble bubble-blue bubble-10"></div>
    <div class="bubble bubble-green bubble-11"></div>
    <div class="bubble bubble-pink bubble-12"></div>
    <div class="bubble bubble-orange bubble-13"></div>
    <div class="bubble bubble-blue bubble-14"></div>
    <div class="bubble bubble-green bubble-15"></div>
    <div class="bubble bubble-pink bubble-16"></div>
    <div class="bubble bubble-orange bubble-17"></div>
    <div class="bubble bubble-blue bubble-18"></div>
    <div class="bubble bubble-green bubble-19"></div>
    <div class="bubble bubble-pink bubble-20"></div>
  </div>
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
    
    /* Simple neutral background with bubbles */
    background: #f8fafc;
    position: relative;
    overflow: hidden;
  }

  /* Floating bubbles container */
  .floating-bubbles {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    pointer-events: none;
    z-index: 1;
  }

  /* Individual bubble styles */
  .bubble {
    position: absolute;
    border-radius: 50%;
    pointer-events: none;
    animation-timing-function: ease-in-out;
    animation-iteration-count: infinite;
    animation-fill-mode: both;
    /* Water bubble effects */
    backdrop-filter: blur(2px);
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.4),
      inset 5px 5px 10px rgba(0, 0, 0, 0.1),
      0 0 15px rgba(255, 255, 255, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.5);
  }

  /* Water bubble colors with transparency */
  .bubble-orange { 
    background: radial-gradient(circle at 30% 30%, rgba(255, 200, 100, 0.8), rgba(255, 165, 0, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(255, 100, 0, 0.2),
      0 0 20px rgba(255, 165, 0, 0.4);
  }
  
  .bubble-blue { 
    background: radial-gradient(circle at 30% 30%, rgba(150, 200, 255, 0.8), rgba(0, 123, 255, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(0, 50, 200, 0.2),
      0 0 20px rgba(0, 123, 255, 0.4);
  }
  
  .bubble-green { 
    background: radial-gradient(circle at 30% 30%, rgba(150, 255, 150, 0.8), rgba(40, 167, 69, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(0, 100, 20, 0.2),
      0 0 20px rgba(40, 167, 69, 0.4);
  }
  
  .bubble-pink { 
    background: radial-gradient(circle at 30% 30%, rgba(255, 180, 200, 0.8), rgba(255, 20, 147, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(200, 0, 100, 0.2),
      0 0 20px rgba(255, 20, 147, 0.4);
  }

  /* Individual bubble animations and positions */
  .bubble-1 {
    width: 25px; height: 25px;
    left: 10%; top: 20%;
    animation: float1 8s infinite;
  }

  .bubble-2 {
    width: 18px; height: 18px;
    left: 80%; top: 15%;
    animation: float2 10s infinite;
  }

  .bubble-3 {
    width: 32px; height: 32px;
    left: 25%; top: 60%;
    animation: float3 12s infinite;
  }

  .bubble-4 {
    width: 22px; height: 22px;
    left: 90%; top: 45%;
    animation: float4 9s infinite;
  }

  .bubble-5 {
    width: 15px; height: 15px;
    left: 15%; top: 80%;
    animation: float5 11s infinite;
  }

  .bubble-6 {
    width: 28px; height: 28px;
    left: 70%; top: 25%;
    animation: float6 7s infinite;
  }

  .bubble-7 {
    width: 20px; height: 20px;
    left: 45%; top: 10%;
    animation: float7 13s infinite;
  }

  .bubble-8 {
    width: 24px; height: 24px;
    left: 60%; top: 75%;
    animation: float8 8s infinite;
  }

  .bubble-9 {
    width: 16px; height: 16px;
    left: 5%; top: 50%;
    animation: float9 10s infinite;
  }

  .bubble-10 {
    width: 30px; height: 30px;
    left: 85%; top: 70%;
    animation: float10 9s infinite;
  }

  .bubble-11 {
    width: 19px; height: 19px;
    left: 35%; top: 30%;
    animation: float11 11s infinite;
  }

  .bubble-12 {
    width: 35px; height: 35px;
    left: 75%; top: 55%;
    animation: float12 7s infinite;
  }

  .bubble-13 {
    width: 12px; height: 12px;
    left: 20%; top: 40%;
    animation: float13 14s infinite;
  }

  .bubble-14 {
    width: 26px; height: 26px;
    left: 95%; top: 20%;
    animation: float14 8s infinite;
  }

  .bubble-15 {
    width: 21px; height: 21px;
    left: 50%; top: 85%;
    animation: float15 12s infinite;
  }

  .bubble-16 {
    width: 17px; height: 17px;
    left: 30%; top: 5%;
    animation: float16 10s infinite;
  }

  .bubble-17 {
    width: 14px; height: 14px;
    left: 65%; top: 90%;
    animation: float17 9s infinite;
  }

  .bubble-18 {
    width: 29px; height: 29px;
    left: 40%; top: 65%;
    animation: float18 11s infinite;
  }

  .bubble-19 {
    width: 13px; height: 13px;
    left: 55%; top: 35%;
    animation: float19 13s infinite;
  }

  .bubble-20 {
    width: 23px; height: 23px;
    left: 12%; top: 70%;
    animation: float20 8s infinite;
  }

  /* Floating animations - each unique */
  @keyframes float1 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(20px, -30px) scale(1.1); }
    50% { transform: translate(-15px, -10px) scale(0.9); }
    75% { transform: translate(10px, -25px) scale(1.05); }
  }

  @keyframes float2 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    33% { transform: translate(-25px, 20px) scale(0.85); }
    66% { transform: translate(15px, -15px) scale(1.15); }
  }

  @keyframes float3 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    20% { transform: translate(30px, 10px) scale(1.2); }
    40% { transform: translate(-20px, -20px) scale(0.8); }
    60% { transform: translate(25px, 15px) scale(1.1); }
    80% { transform: translate(-10px, -5px) scale(0.95); }
  }

  @keyframes float4 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(-30px, -40px) scale(1.3); }
  }

  @keyframes float5 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(15px, -25px) scale(0.7); }
    70% { transform: translate(-20px, 10px) scale(1.4); }
  }

  @keyframes float6 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(-15px, 25px) scale(1.1); }
    75% { transform: translate(20px, -15px) scale(0.9); }
  }

  @keyframes float7 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    40% { transform: translate(25px, 30px) scale(1.2); }
    80% { transform: translate(-15px, -20px) scale(0.8); }
  }

  @keyframes float8 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    35% { transform: translate(-20px, -30px) scale(1.15); }
    65% { transform: translate(30px, 20px) scale(0.85); }
  }

  @keyframes float9 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    45% { transform: translate(35px, -15px) scale(1.3); }
    90% { transform: translate(-25px, 25px) scale(0.7); }
  }

  @keyframes float10 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(-30px, 15px) scale(0.9); }
    60% { transform: translate(20px, -25px) scale(1.2); }
  }

  @keyframes float11 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(10px, 35px) scale(1.1); }
  }

  @keyframes float12 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(-35px, -10px) scale(0.8); }
    75% { transform: translate(15px, 30px) scale(1.25); }
  }

  @keyframes float13 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    40% { transform: translate(20px, -35px) scale(1.4); }
    80% { transform: translate(-30px, 20px) scale(0.6); }
  }

  @keyframes float14 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    33% { transform: translate(25px, 25px) scale(1.1); }
    66% { transform: translate(-20px, -30px) scale(0.9); }
  }

  @keyframes float15 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    20% { transform: translate(-25px, -20px) scale(1.2); }
    80% { transform: translate(30px, 10px) scale(0.8); }
  }

  @keyframes float16 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(-10px, 40px) scale(1.3); }
  }

  @keyframes float17 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    35% { transform: translate(30px, -25px) scale(0.85); }
    70% { transform: translate(-20px, 15px) scale(1.15); }
  }

  @keyframes float18 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(15px, -30px) scale(1.05); }
    75% { transform: translate(-25px, 20px) scale(0.95); }
  }

  @keyframes float19 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    45% { transform: translate(-15px, 30px) scale(1.25); }
    90% { transform: translate(35px, -15px) scale(0.75); }
  }

  @keyframes float20 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(20px, 20px) scale(1.1); }
    70% { transform: translate(-30px, -25px) scale(0.9); }
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

  /* Mobile optimizations for bubbles */
  @media (max-width: 480px) {
    .bubble {
      transform: scale(0.6);
      box-shadow: 
        inset -3px -3px 6px rgba(255, 255, 255, 0.4),
        inset 3px 3px 6px rgba(0, 0, 0, 0.1),
        0 0 8px rgba(255, 255, 255, 0.3);
    }
  }
</style>