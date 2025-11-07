<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { cartCount, cartTotal } from '$lib/stores/cart.js';
  import { deliveryTiers, deliveryActions, freeDeliveryThreshold } from '$lib/stores/delivery.js';
  
  let currentLanguage = 'ar';
  let showFireworks = false;
  let showSadMessage = false;
  let previousTotal = 0;
  let hasReachedFreeDelivery = false;
  let currentDeliveryFee = 0;
  let nextTierInfo = null;

  // Subscribe to cart updates using reactive syntax
  $: itemCount = $cartCount;
  $: total = $cartTotal;
  $: freeDeliveryMin = $freeDeliveryThreshold;
  
  // Calculate delivery fee reactively
  $: {
    if (total > 0 && $deliveryTiers.length > 0) {
      currentDeliveryFee = deliveryActions.getDeliveryFeeLocal(total);
      nextTierInfo = deliveryActions.getNextTierLocal(total);
    }
  }
  
  // Reactive statement for total changes
  $: {
    // Track if user has ever reached free delivery
    if (currentDeliveryFee === 0 && total >= freeDeliveryMin) {
      hasReachedFreeDelivery = true;
    }
    
    // Trigger fireworks when crossing threshold upward
    const prevFee = previousTotal > 0 ? deliveryActions.getDeliveryFeeLocal(previousTotal) : currentDeliveryFee;
    if (prevFee > 0 && currentDeliveryFee === 0 && total >= freeDeliveryMin) {
      triggerFireworks();
    }
    
    // Trigger sad message when falling below threshold after reaching it
    if (hasReachedFreeDelivery && prevFee === 0 && currentDeliveryFee > 0) {
      triggerSadMessage();
    }
    
    // Update previous total
    previousTotal = total;
  }

  $: isFreeDelivery = currentDeliveryFee === 0;
  $: finalTotal = total + currentDeliveryFee;

  // Load language from localStorage
  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }
    
    // Initialize delivery data
    await deliveryActions.initialize();
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
    items: 'منتج',
    total: 'المجموع',
    checkout: 'إنهاء طلبك',
    sar: 'ر.س',
    freeDelivery: 'توصيل مجاني!',
    freeDeliveryUnlocked: 'تم فتح التوصيل المجاني! 🎉',
    sadMessage: '😢 أوه لا! فقدت التوصيل المجاني',
    encourageMessage: nextTierInfo 
      ? `أضف ${nextTierInfo.amountNeeded.toFixed(2)} ر.س أكثر لتوفير ${nextTierInfo.potentialSavings.toFixed(2)} ر.س على التوصيل!`
      : `أضف ${(freeDeliveryMin - total).toFixed(2)} ر.س أكثر للحصول على توصيل مجاني!`
  } : {
    items: 'items',
    total: 'Total',
    checkout: 'Finalize your order',
    sar: 'SAR',
    freeDelivery: 'Free Delivery!',
    freeDeliveryUnlocked: 'Free Delivery Unlocked! 🎉',
    sadMessage: '😢 Oh no! You lost free delivery',
    encourageMessage: nextTierInfo 
      ? `Add ${nextTierInfo.amountNeeded.toFixed(2)} SAR more to save ${nextTierInfo.potentialSavings.toFixed(2)} SAR on delivery!`
      : `Add ${(freeDeliveryMin - total).toFixed(2)} SAR more for free delivery!`
  };

  function triggerFireworks() {
    showFireworks = true;
    setTimeout(() => {
      showFireworks = false;
    }, 3000);
  }

  function triggerSadMessage() {
    showSadMessage = true;
    setTimeout(() => {
      showSadMessage = false;
    }, 4000);
  }

  function goToCheckout() {
    goto('/customer/finalize');
  }

  function goToCart() {
    goto('/customer/cart');
  }
</script>

{#if itemCount > 0}
<div class="bottom-cart-bar" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Fireworks Animation -->
  {#if showFireworks}
    <div class="fireworks-container">
      <div class="firework firework-1"></div>
      <div class="firework firework-2"></div>
      <div class="firework firework-3"></div>
      <div class="firework firework-4"></div>
      <div class="free-delivery-message">
        {texts.freeDeliveryUnlocked}
      </div>
    </div>
  {/if}
  
  <!-- Sad Message Animation -->
  {#if showSadMessage}
    <div class="sad-message-container">
      <div class="sad-emoji">😢</div>
      <div class="sad-message">
        <div class="sad-title">{texts.sadMessage}</div>
        <div class="encourage-text">{texts.encourageMessage}</div>
      </div>
    </div>
  {/if}
  
  <div class="cart-info" on:click={goToCart}>
    <div class="cart-items">
      <span class="cart-icon">🛒</span>
      <span class="item-count">{itemCount} {texts.items}</span>
    </div>
    <div class="cart-total">
      <span class="total-label">{texts.total}:</span>
      <span class="total-amount">{total.toFixed(2)} {texts.sar}</span>
      {#if isFreeDelivery}
        <span class="free-delivery-badge">{texts.freeDelivery}</span>
      {:else if currentDeliveryFee > 0}
        <small class="delivery-hint">+{currentDeliveryFee.toFixed(2)} {currentLanguage === 'ar' ? 'توصيل' : 'delivery'}</small>
      {/if}
    </div>
  </div>
  
  <button class="checkout-btn" on:click={goToCheckout}>
    {texts.checkout}
  </button>
</div>
{/if}

<style>
  .bottom-cart-bar {
    position: fixed;
    bottom: 80px; /* Above bottom navigation */
    left: 0;
    right: 0;
    background: white;
    border-top: 1px solid var(--color-border);
    box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
    padding: 1rem;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    z-index: 90;
    animation: slideUp 0.3s ease-out;
  }

  @keyframes slideUp {
    from {
      transform: translateY(100%);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  .cart-info {
    flex: 1;
    cursor: pointer;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .cart-items {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .cart-icon {
    font-size: 1.2rem;
  }

  .item-count {
    font-size: 0.9rem;
    color: var(--color-ink);
    font-weight: 600;
  }

  .cart-total {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .total-label {
    font-size: 0.9rem;
    color: var(--color-ink-light);
  }

  .total-amount {
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--color-primary);
  }

  .delivery-hint {
    font-size: 0.75rem;
    color: var(--color-ink-light);
    margin-left: 0.25rem;
    font-style: italic;
    opacity: 0.8;
  }

  .free-delivery-badge {
    font-size: 0.75rem;
    color: #4CAF50;
    background: rgba(76, 175, 80, 0.1);
    padding: 0.2rem 0.5rem;
    border-radius: 12px;
    font-weight: 600;
    margin-left: 0.25rem;
    border: 1px solid rgba(76, 175, 80, 0.3);
    animation: pulseBadge 1.5s ease-in-out infinite;
  }

  @keyframes pulseBadge {
    0%, 100% { transform: scale(1); opacity: 1; }
    50% { transform: scale(1.05); opacity: 0.8; }
  }

  .checkout-btn {
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    white-space: nowrap;
  }

  .checkout-btn:hover {
    background: var(--color-primary-dark);
  }

  /* Fireworks Animation */
  .fireworks-container {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    pointer-events: none;
    z-index: 9999;
    overflow: hidden;
  }

  .firework {
    position: absolute;
    width: 4px;
    height: 4px;
    border-radius: 50%;
    animation: fireworkExplode 2s ease-out forwards;
  }

  .firework-1 {
    top: 30%;
    left: 20%;
    background: #FFD700;
    animation-delay: 0s;
  }

  .firework-2 {
    top: 25%;
    right: 25%;
    background: #FF69B4;
    animation-delay: 0.3s;
  }

  .firework-3 {
    top: 40%;
    left: 50%;
    background: #00BFFF;
    animation-delay: 0.6s;
  }

  .firework-4 {
    top: 35%;
    right: 40%;
    background: #32CD32;
    animation-delay: 0.9s;
  }

  @keyframes fireworkExplode {
    0% {
      transform: scale(0);
      opacity: 1;
      box-shadow: 
        0 0 0 0 currentColor,
        0 0 0 0 currentColor,
        0 0 0 0 currentColor,
        0 0 0 0 currentColor,
        0 0 0 0 currentColor,
        0 0 0 0 currentColor,
        0 0 0 0 currentColor,
        0 0 0 0 currentColor;
    }
    20% {
      transform: scale(1);
      opacity: 1;
    }
    50% {
      transform: scale(3);
      opacity: 0.8;
      box-shadow: 
        30px 0 0 -2px currentColor,
        -30px 0 0 -2px currentColor,
        0 30px 0 -2px currentColor,
        0 -30px 0 -2px currentColor,
        21px 21px 0 -2px currentColor,
        -21px -21px 0 -2px currentColor,
        21px -21px 0 -2px currentColor,
        -21px 21px 0 -2px currentColor;
    }
    100% {
      transform: scale(5);
      opacity: 0;
      box-shadow: 
        60px 0 0 -4px currentColor,
        -60px 0 0 -4px currentColor,
        0 60px 0 -4px currentColor,
        0 -60px 0 -4px currentColor,
        42px 42px 0 -4px currentColor,
        -42px -42px 0 -4px currentColor,
        42px -42px 0 -4px currentColor,
        -42px 42px 0 -4px currentColor;
    }
  }

  .free-delivery-message {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: linear-gradient(45deg, #4CAF50, #66BB6A);
    color: white;
    padding: 1rem 2rem;
    border-radius: 25px;
    font-size: 1.2rem;
    font-weight: bold;
    box-shadow: 0 4px 20px rgba(76, 175, 80, 0.4);
    animation: messageAppear 3s ease-out forwards;
    text-align: center;
    border: 2px solid rgba(255, 255, 255, 0.3);
  }

  @keyframes messageAppear {
    0% {
      transform: translate(-50%, -50%) scale(0) rotate(-180deg);
      opacity: 0;
    }
    20% {
      transform: translate(-50%, -50%) scale(1.2) rotate(10deg);
      opacity: 1;
    }
    30% {
      transform: translate(-50%, -50%) scale(0.9) rotate(-5deg);
      opacity: 1;
    }
    40% {
      transform: translate(-50%, -50%) scale(1) rotate(0deg);
      opacity: 1;
    }
    80% {
      transform: translate(-50%, -50%) scale(1) rotate(0deg);
      opacity: 1;
    }
    100% {
      transform: translate(-50%, -50%) scale(0.8) rotate(0deg);
      opacity: 0;
    }
  }

  /* Sad Message Styles */
  .sad-message-container {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    pointer-events: none;
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  .sad-emoji {
    position: absolute;
    font-size: 4rem;
    animation: sadEmojiFloat 4s ease-out forwards;
    top: 20%;
    left: 50%;
    transform: translateX(-50%);
  }

  @keyframes sadEmojiFloat {
    0% {
      transform: translateX(-50%) translateY(-100px) scale(0);
      opacity: 0;
    }
    20% {
      transform: translateX(-50%) translateY(0) scale(1.2);
      opacity: 1;
    }
    30% {
      transform: translateX(-50%) translateY(10px) scale(1);
      opacity: 1;
    }
    80% {
      transform: translateX(-50%) translateY(0) scale(1);
      opacity: 1;
    }
    100% {
      transform: translateX(-50%) translateY(-50px) scale(0.8);
      opacity: 0;
    }
  }

  .sad-message {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: linear-gradient(45deg, #FF6B6B, #FF8E8E);
    color: white;
    padding: 1.5rem 2rem;
    border-radius: 20px;
    text-align: center;
    box-shadow: 0 4px 20px rgba(255, 107, 107, 0.4);
    animation: sadMessageSlide 4s ease-out forwards;
    border: 2px solid rgba(255, 255, 255, 0.3);
    max-width: 300px;
  }

  .sad-title {
    font-size: 1.1rem;
    font-weight: bold;
    margin-bottom: 0.5rem;
  }

  .encourage-text {
    font-size: 0.9rem;
    opacity: 0.9;
    line-height: 1.4;
  }

  @keyframes sadMessageSlide {
    0% {
      transform: translate(-50%, -50%) translateY(100px) scale(0);
      opacity: 0;
    }
    25% {
      transform: translate(-50%, -50%) translateY(0) scale(1.1);
      opacity: 1;
    }
    35% {
      transform: translate(-50%, -50%) translateY(-5px) scale(1);
      opacity: 1;
    }
    85% {
      transform: translate(-50%, -50%) translateY(0) scale(1);
      opacity: 1;
    }
    100% {
      transform: translate(-50%, -50%) translateY(30px) scale(0.9);
      opacity: 0;
    }
  }

  /* Mobile optimizations */
  @media (max-width: 480px) {
    .bottom-cart-bar {
      padding: 0.75rem;
    }

    .cart-info {
      gap: 0.1rem;
    }

    .item-count, .total-label {
      font-size: 0.85rem;
    }

    .total-amount {
      font-size: 1rem;
    }

    .checkout-btn {
      padding: 0.5rem 1rem;
      font-size: 0.9rem;
    }
  }
</style>