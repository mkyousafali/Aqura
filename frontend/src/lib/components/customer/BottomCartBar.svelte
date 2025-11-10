<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { cartCount, cartTotal } from '$lib/stores/cart.js';
  import { deliveryTiers, deliveryActions, freeDeliveryThreshold } from '$lib/stores/delivery.js';
  import { orderFlow } from '$lib/stores/orderFlow.js';
  
  let currentLanguage = 'ar';
  let showFireworks = false;
  let showSadMessage = false;
  let showTierMessage = false;
  let previousTotal = 0;
  let previousDeliveryFee = null;
  let hasReachedFreeDelivery = false;
  let currentDeliveryFee = 0;
  let nextTierInfo = null;
  let highestDeliveryFeeInTier = 0; // Track highest fee while in current tier
  let tierSavingsAmount = 0; // Store the savings when tier activates
  let nextTierAtActivation = null; // Store next tier info when tier activates

  // Function to convert numbers to Arabic numerals
  function toArabicNumerals(num) {
    const arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return num.toString().replace(/\d/g, (digit) => arabicNumerals[digit]);
  }

  // Function to format price based on language
  function formatPrice(price) {
    // Only show decimals if there's a fractional part
    const formatted = price % 1 === 0 ? price.toFixed(0) : price.toFixed(2);
    return currentLanguage === 'ar' ? toArabicNumerals(formatted) : formatted;
  }

  // Subscribe to cart updates using reactive syntax
  $: itemCount = $cartCount;
  $: total = $cartTotal;
  $: freeDeliveryMin = $freeDeliveryThreshold;
  
  // Calculate delivery fee reactively
  $: {
    const branchId = $orderFlow?.branchId;
    if (branchId && total > 0 && $deliveryTiers.length > 0) {
      currentDeliveryFee = deliveryActions.getDeliveryFeeLocal(total, branchId);
      nextTierInfo = deliveryActions.getNextTierLocal(total, branchId);
      
      // Track highest delivery fee while in current tier
      if (currentDeliveryFee > highestDeliveryFeeInTier) {
        highestDeliveryFeeInTier = currentDeliveryFee;
      }
      
      console.log('Cart bar update:', {total, currentDeliveryFee, nextTierInfo, highestDeliveryFeeInTier});
    } else {
      currentDeliveryFee = 0;
      nextTierInfo = null;
    }
  }
  
  // Reactive statement for total changes
  $: {
    const branchId = $orderFlow?.branchId;
    
    // Track if user has ever reached free delivery
    if (currentDeliveryFee === 0 && total >= freeDeliveryMin) {
      hasReachedFreeDelivery = true;
    }
    
    // Calculate previous fee with branchId
    const prevFee = (previousTotal > 0 && branchId) 
      ? deliveryActions.getDeliveryFeeLocal(previousTotal, branchId) 
      : currentDeliveryFee;
    
    // Trigger fireworks when crossing threshold upward
    if (prevFee > 0 && currentDeliveryFee === 0 && total >= freeDeliveryMin) {
      triggerFireworks();
    }
    
    // Trigger sad message when falling below threshold after reaching it
    if (hasReachedFreeDelivery && prevFee === 0 && currentDeliveryFee > 0) {
      triggerSadMessage();
    }
    
    // Trigger tier message when activating a new tier (fee decreased)
    // Must have valid previous fee and current fee must be lower but not zero
    if (previousDeliveryFee !== null && previousDeliveryFee > currentDeliveryFee && currentDeliveryFee > 0) {
      // Calculate savings from the highest fee user had in previous tier
      tierSavingsAmount = highestDeliveryFeeInTier - currentDeliveryFee;
      
      // Capture next tier info at activation moment
      nextTierAtActivation = nextTierInfo;
      
      console.log('Tier activated!', {
        highestDeliveryFeeInTier, 
        currentDeliveryFee, 
        tierSavingsAmount, 
        nextTierAtActivation
      });
      
      // Reset highest fee tracker for new tier
      highestDeliveryFeeInTier = currentDeliveryFee;
      
      triggerTierMessage();
    }
    
    // Update previous values
    previousTotal = total;
    previousDeliveryFee = currentDeliveryFee;
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
  
  // Reload tiers when branch selection changes
  $: if ($orderFlow?.branchId) {
    deliveryActions.loadTiers($orderFlow.branchId);
  } else {
    deliveryTiers.set([]);
  }

  // Listen for language changes
  function handleStorageChange(event) {
    if (event.key === 'language') {
      currentLanguage = event.newValue || 'ar';
    }
  }

  function handleLanguageChange(event) {
    currentLanguage = event.detail || 'ar';
  }

  onMount(() => {
    window.addEventListener('storage', handleStorageChange);
    window.addEventListener('languagechange', handleLanguageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('languagechange', handleLanguageChange);
    };
  });

  // Steps placeholder state
  let showSteps = false;
  $: flow = $orderFlow;

  $: texts = currentLanguage === 'ar' ? {
    items: 'منتج',
    total: 'المجموع',
    checkout: 'الدفع',
    sar: 'ر.س',
    freeDelivery: 'توصيل مجاني!',
    freeDeliveryUnlocked: 'تم فتح التوصيل المجاني! 🎉',
    sadMessage: '😢 أوه لا! فقدت التوصيل المجاني',
    delivery: 'توصيل'
  } : {
    items: 'items',
    total: 'Total',
    checkout: 'Checkout',
    sar: 'SAR',
    freeDelivery: 'Free Delivery!',
    freeDeliveryUnlocked: 'Free Delivery Unlocked! 🎉',
    sadMessage: '😢 Oh no! You lost free delivery',
    delivery: 'delivery'
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

  function triggerTierMessage() {
    console.log('Triggering tier message, nextTierAtActivation:', nextTierAtActivation);
    showTierMessage = true;
    setTimeout(() => {
      showTierMessage = false;
      nextTierAtActivation = null; // Reset after showing
    }, 4000);
  }

  function openSteps() { showSteps = true; }
  function closeSteps() { showSteps = false; }

  function goToCart() {
    goto('/customer/cart');
  }

  function goToCheckout() {
    goto('/customer/checkout');
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
      </div>
    </div>
  {/if}
  
  <!-- Tier Activated Message -->
  {#if showTierMessage}
    <div class="tier-message-container">
      <div class="tier-emoji">🎉</div>
      <div class="tier-message">
        <div class="tier-title">
          {currentLanguage === 'ar' 
            ? `رائع! وفرت ${formatPrice(tierSavingsAmount)} ر.س على التوصيل` 
            : `Great! Saved ${formatPrice(tierSavingsAmount)} SAR on delivery`}
        </div>
        {#if nextTierAtActivation}
          <div class="next-tier-info">
            {currentLanguage === 'ar'
              ? `المستوى التالي عند ${formatPrice(nextTierAtActivation.nextTierMinAmount)} ر.س - وفر ${formatPrice(nextTierAtActivation.potentialSavings)} ر.س إضافية`
              : `Next tier at ${formatPrice(nextTierAtActivation.nextTierMinAmount)} SAR - Save ${formatPrice(nextTierAtActivation.potentialSavings)} SAR more`}
          </div>
        {/if}
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
      <span class="total-amount">
        {#if currentLanguage === 'ar'}
          {formatPrice(total)}
          <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
        {:else}
          <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
          {formatPrice(total)}
        {/if}
      </span>
      {#if isFreeDelivery}
        <span class="free-delivery-badge">{texts.freeDelivery}</span>
      {:else if currentDeliveryFee > 0}
        {#key currentLanguage}
          <small class="delivery-hint">
            +{formatPrice(currentDeliveryFee)} {texts.delivery}
          </small>
        {/key}
      {/if}
    </div>
  </div>
  
  <button class="checkout-btn" on:click={goToCheckout}>
    {texts.checkout}
  </button>
</div>
{/if}

{#if showSteps}
<div class="steps-overlay" on:click={closeSteps}>
  <div class="steps-modal" on:click|stopPropagation>
    <div class="steps-header">
      <h3>{currentLanguage === 'ar' ? 'مراحل الطلب' : 'Order Steps'}</h3>
      <button class="close" on:click={closeSteps}>×</button>
    </div>
    <ol class="steps-list" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
      <li class="step-item {flow.branchId && flow.fulfillment ? 'done' : ''}">
        <span class="index">1</span>
        <span class="label">{currentLanguage === 'ar' ? 'اختر الفرع والخدمة' : 'Select branch & service'}</span>
        <small class="hint">{flow.branchId && flow.fulfillment ? (currentLanguage === 'ar' ? 'تم الاختيار' : 'Selected') : (currentLanguage === 'ar' ? 'ابدأ من الرئيسية' : 'Start from Home')}</small>
      </li>
      <li class="step-item current">
        <span class="index">2</span>
        <span class="label">{currentLanguage === 'ar' ? 'إضافة المنتجات' : 'Add products'}</span>
      </li>
      <li class="step-item">
        <span class="index">3</span>
        <span class="label">{currentLanguage === 'ar' ? 'مراجعة و الدفع' : 'Review & pay'}</span>
      </li>
    </ol>
    <div class="steps-footer">
      <button class="btn-secondary" on:click={closeSteps}>{currentLanguage === 'ar' ? 'إغلاق' : 'Close'}</button>
    </div>
  </div>
</div>
{/if}

<style>
  .bottom-cart-bar {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: white;
    border-top: 1px solid var(--color-border);
    box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.1);
    padding: 0.5rem 0.75rem;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.6rem;
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
    gap: 0.1rem;
  }

  .cart-items {
    display: flex;
    align-items: center;
    gap: 0.3rem;
  }

  .cart-icon {
    font-size: 0.85rem;
  }

  .item-count {
    font-size: 0.7rem;
    color: var(--color-ink);
    font-weight: 600;
  }

  .cart-total {
    display: flex;
    align-items: center;
    gap: 0.3rem;
    flex-wrap: wrap;
  }

  .total-label {
    font-size: 0.65rem;
    color: var(--color-ink-light);
  }

  .total-amount {
    font-size: 0.8rem;
    font-weight: 700;
    color: var(--color-primary);
    display: flex;
    align-items: center;
    gap: 0.2rem;
  }

  .currency-icon {
    height: 0.55rem;
    width: auto;
    display: inline-block;
    vertical-align: middle;
  }

  .currency-icon-tiny {
    height: 0.45rem;
    width: auto;
    display: inline-block;
    vertical-align: middle;
    margin: 0 0.1rem;
  }

  .delivery-hint {
    font-size: 0.6rem;
    color: #ef4444;
    margin-left: 0.2rem;
    font-style: italic;
    font-weight: 600;
  }

  .free-delivery-badge {
    font-size: 0.6rem;
    color: #4CAF50;
    background: rgba(76, 175, 80, 0.1);
    padding: 0.1rem 0.3rem;
    border-radius: 8px;
    font-weight: 600;
    margin-left: 0.2rem;
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
    padding: 0.45rem 0.9rem;
    border-radius: 6px;
    font-size: 0.75rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    white-space: nowrap;
  }

  .checkout-btn:hover {
    background: var(--color-primary-dark);
  }

  /* Steps modal */
  .steps-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 2000; }
  .steps-modal { background: #fff; width: 92%; max-width: 480px; border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); overflow: hidden; }
  .steps-header { display: flex; justify-content: space-between; align-items: center; padding: 1rem 1.25rem; border-bottom: 1px solid var(--color-border-light); }
  .steps-header h3 { margin: 0; font-size: 1.1rem; color: var(--color-ink); }
  .steps-header .close { background: none; border: none; font-size: 1.25rem; cursor: pointer; }
  .steps-list { list-style: none; margin: 0; padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: 0.75rem; }
  .step-item { display: flex; align-items: center; gap: 0.75rem; }
  .step-item .index { width: 28px; height: 28px; border-radius: 50%; background: var(--color-surface); display: inline-flex; align-items: center; justify-content: center; font-weight: 700; color: var(--color-ink); }
  .step-item.done .index { background: #d1fae5; color: #065f46; }
  .step-item.current .index { background: #dbeafe; color: #1e40af; }
  .step-item .label { font-weight: 600; color: var(--color-ink); }
  .step-item .hint { margin-inline-start: auto; color: var(--color-ink-light); }
  .steps-footer { border-top: 1px solid var(--color-border-light); padding: 0.75rem 1.25rem; display: flex; justify-content: flex-end; }

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

  .tier-title {
    font-size: 1.1rem;
    font-weight: bold;
    margin-bottom: 0.5rem;
  }

  .next-tier-info {
    font-size: 0.85rem;
    opacity: 0.9;
    line-height: 1.4;
    margin-top: 0.5rem;
    padding-top: 0.5rem;
    border-top: 1px solid rgba(255, 255, 255, 0.3);
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

  /* Tier Activated Message Styles */
  .tier-message-container {
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

  .tier-emoji {
    position: absolute;
    font-size: 4rem;
    animation: tierEmojiFloat 4s ease-out forwards;
    top: 20%;
    left: 50%;
    transform: translateX(-50%);
  }

  @keyframes tierEmojiFloat {
    0% {
      transform: translateX(-50%) translateY(-100px) scale(0) rotate(-180deg);
      opacity: 0;
    }
    20% {
      transform: translateX(-50%) translateY(0) scale(1.2) rotate(0deg);
      opacity: 1;
    }
    30% {
      transform: translateX(-50%) translateY(10px) scale(1) rotate(0deg);
      opacity: 1;
    }
    80% {
      transform: translateX(-50%) translateY(0) scale(1) rotate(0deg);
      opacity: 1;
    }
    100% {
      transform: translateX(-50%) translateY(-50px) scale(0.8) rotate(0deg);
      opacity: 0;
    }
  }

  .tier-message {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: linear-gradient(45deg, #4CAF50, #66BB6A);
    color: white;
    padding: 1.5rem 2rem;
    border-radius: 20px;
    text-align: center;
    box-shadow: 0 4px 20px rgba(76, 175, 80, 0.4);
    animation: tierMessageSlide 4s ease-out forwards;
    border: 2px solid rgba(255, 255, 255, 0.3);
    max-width: 300px;
  }

  .tier-title {
    font-size: 1.1rem;
    font-weight: bold;
    margin-bottom: 0.5rem;
  }

  @keyframes tierMessageSlide {
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
      padding: 0.4rem 0.6rem;
    }

    .cart-info {
      gap: 0.05rem;
    }

    .item-count, .total-label {
      font-size: 0.65rem;
    }

    .total-amount {
      font-size: 0.75rem;
    }

    .checkout-btn {
      padding: 0.4rem 0.75rem;
      font-size: 0.7rem;
    }
  }
</style>