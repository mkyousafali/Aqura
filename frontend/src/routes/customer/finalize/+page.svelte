<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { cartStore, cartCount, cartTotal } from '$lib/stores/cart.js';
  
  let currentLanguage = 'ar';
  let cartItems = [];
  
  // Delivery service configuration  
  const deliveryService = {
    isActive: true,
    operatingHours: {
      startTime: "00:00", 
      endTime: "23:59"
    },
    minimumOrder: 15,
    is24Hours: true,
    deliveryFee: 15.00,
    displayAr: "التوصيل متاح على مدار الساعة (24/7)",
    displayEn: "Delivery available 24/7"
  };
  
  // Use reactive declarations for store values
  $: total = $cartTotal;
  $: itemCount = $cartCount;

  // Load language from localStorage and listen for changes
  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
      document.documentElement.dir = currentLanguage === 'ar' ? 'rtl' : 'ltr';
      document.documentElement.lang = currentLanguage;
    }

    // Listen for language changes from other tabs/pages
    function handleStorageChange(event) {
      if (event.key === 'language') {
        currentLanguage = event.newValue || 'ar';
        document.documentElement.dir = currentLanguage === 'ar' ? 'rtl' : 'ltr';
        document.documentElement.lang = currentLanguage;
      }
    }

    window.addEventListener('storage', handleStorageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  });

  // Subscribe to cart store
  onMount(() => {
    const unsubscribe = cartStore.subscribe(items => {
      cartItems = items;
      // If cart is empty, redirect to products
      if (items.length === 0) {
        goto('/customer/products');
      }
    });

    return () => {
      unsubscribe();
    };
  });

  // Language text
  $: texts = currentLanguage === 'ar' ? {
    title: 'إنهاء طلبك',
    subtitle: 'اختر طريقة استلام طلبك',
    pickupFromStore: 'الاستلام من المتجر',
    pickupDescription: 'ادفع في المتجر',
    delivery: 'التوصيل',
    deliveryDescription: 'سنوصل طلبك إلى موقعك',
    deliveryBenefits: ['توصيل لباب منزلك', 'دفع عند الاستلام', 'تتبع الطلب'],
    orderSummary: 'ملخص الطلب',
    items: 'منتج',
    total: 'المجموع',
    sar: 'ر.س',
    backToCart: 'العودة إلى السلة',
    serviceUnavailable: 'الخدمة غير متاحة حالياً',
    minimumOrder: 'الحد الأدنى للطلب',
    operatingHours: 'ساعات العمل',
    currentTime: 'الوقت الحالي',
    pickupBenefits: ['دفع في المكان', 'لا رسوم توصيل', 'استلام فوري'],
    storeLocation: 'الموقع: الرياض، المملكة العربية السعودية',
    estimatedTime: 'جاهز للاستلام خلال 15-30 دقيقة'
  } : {
    title: 'Finalize Your Order',
    subtitle: 'Choose how you want to receive your order', 
    pickupFromStore: 'Pick Up From Store',
    pickupDescription: 'Pay at store',
    delivery: 'Delivery',
    deliveryDescription: 'We will deliver your order to your location',
    deliveryBenefits: ['Door-to-door delivery', 'Cash on delivery', 'Track your order'],
    orderSummary: 'Order Summary',
    items: 'items',
    total: 'Total',
    sar: 'SAR',
    backToCart: 'Back to Cart',
    serviceUnavailable: 'Service currently unavailable',
    minimumOrder: 'Minimum order',
    operatingHours: 'Operating hours',
    currentTime: 'Current time',
    pickupBenefits: ['Pay at location', 'No delivery fees', 'Instant pickup'],
    storeLocation: 'Location: Riyadh, Saudi Arabia',
    estimatedTime: 'Ready for pickup in 15-30 minutes'
  };

  // Check if current time is within delivery hours
  function isDeliveryServiceAvailable() {
    if (!deliveryService.isActive) return false;
    if (deliveryService.is24Hours) return true;
    
    const now = new Date();
    const currentTime = now.getHours() * 100 + now.getMinutes();
    const startTime = parseInt(deliveryService.operatingHours.startTime.replace(':', ''));
    const endTime = parseInt(deliveryService.operatingHours.endTime.replace(':', ''));
    
    return currentTime >= startTime && currentTime <= endTime;
  }

  // Check if order meets minimum requirement
  function meetsFulfillmentRequirements() {
    return total >= deliveryService.minimumOrder;
  }

  // Get delivery status message
  function getDeliveryStatusMessage() {
    if (!meetsFulfillmentRequirements()) {
      return currentLanguage === 'ar'
        ? `${texts.minimumOrder}: ${deliveryService.minimumOrder} ${texts.sar}`
        : `${texts.minimumOrder}: ${deliveryService.minimumOrder} ${texts.sar}`;
    }
    
    if (!isDeliveryServiceAvailable()) {
      return currentLanguage === 'ar' 
        ? 'خدمة التوصيل مغلقة حالياً'
        : 'Delivery service is currently closed';
    }
    
    return null; // Service is available
  }

  function choosePickup() {
    console.log('🔄 [Finalize] Pickup button clicked');
    try {
      goto('/customer/checkout?fulfillment=pickup');
    } catch (error) {
      console.error('❌ [Finalize] Pickup navigation error:', error);
    }
  }

  function chooseDelivery() {
    console.log('🔄 [Finalize] Delivery button clicked');
    try {
      const statusMessage = getDeliveryStatusMessage();
      if (statusMessage) {
        console.log('⚠️ [Finalize] Delivery blocked:', statusMessage);
        alert(statusMessage);
        return;
      }
      goto('/customer/checkout?fulfillment=delivery');
    } catch (error) {
      console.error('❌ [Finalize] Delivery navigation error:', error);
    }
  }

  function goBack() {
    console.log('🔄 [Finalize] Back button clicked');
    try {
      goto('/customer/cart');
    } catch (error) {
      console.error('❌ [Finalize] Back navigation error:', error);
    }
  }
</script>

<svelte:head>
  <title>{texts.title} - أكوا إكسبرس</title>
</svelte:head>

<div class="finalize-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Header -->
  <header class="page-header">
    <button class="back-button" on:click={goBack} type="button">
      ← {texts.backToCart}
    </button>
    <h1>{texts.title}</h1>
    <div></div> <!-- Spacer for flexbox -->
  </header>

  <p class="subtitle">{texts.subtitle}</p>

  <!-- Order Summary -->
  <div class="order-summary-card">
    <div class="order-summary">
      <h3>{texts.orderSummary}</h3>
      <div class="summary-details">
        <div class="summary-row">
          <span>{itemCount} {texts.items}</span>
          <span>{total.toFixed(2)} {texts.sar}</span>
        </div>
        <div class="summary-row total-row">
          <span>{texts.total}</span>
          <span>{total.toFixed(2)} {texts.sar}</span>
        </div>
      </div>
    </div>
  </div>

  <!-- Fulfillment Options -->
  <div class="options-section">
    <!-- Pick Up From Store -->
    <div class="option-card-container">
      <button class="option-card pickup" on:click={choosePickup} type="button">
        <div class="option-icon">🏪</div>
        <div class="option-content">
          <h3>{texts.pickupFromStore}</h3>
          <p class="option-description">{texts.pickupDescription}</p>
          <ul class="benefits-list">
            {#each texts.pickupBenefits as benefit}
              <li>✓ {benefit}</li>
            {/each}
          </ul>
          <div class="store-info">
            <p class="store-location">{texts.storeLocation}</p>
            <p class="estimated-time">{texts.estimatedTime}</p>
          </div>
        </div>
        <div class="option-arrow">›</div>
      </button>
    </div>

    <!-- Delivery -->
    <div class="option-card-container">
      <button 
        class="option-card delivery {getDeliveryStatusMessage() ? 'unavailable' : ''}" 
        on:click={chooseDelivery} 
        type="button"
        disabled={!!getDeliveryStatusMessage()}
      >
        <div class="option-icon">🚚</div>
        <div class="option-content">
          <h3>{texts.delivery}</h3>
          <p class="option-description">{texts.deliveryDescription}</p>
          <ul class="benefits-list">
            {#each texts.deliveryBenefits as benefit}
              <li>✓ {benefit}</li>
            {/each}
          </ul>
          
          <!-- Service Status -->
          {#if getDeliveryStatusMessage()}
            <div class="service-status unavailable">
              <p>⚠️ {getDeliveryStatusMessage()}</p>
            </div>
          {:else}
            <div class="service-status available">
              <p>✅ {currentLanguage === 'ar' ? deliveryService.displayAr : deliveryService.displayEn}</p>
              <small>{texts.minimumOrder}: {deliveryService.minimumOrder} {texts.sar}</small>
            </div>
          {/if}
        </div>
        <div class="option-arrow">›</div>
      </button>
    </div>
  </div>
</div>

<style>
  * {
    box-sizing: border-box;
  }

  button {
    -webkit-appearance: none;
    -moz-appearance: none;
    appearance: none;
    background: none;
    border: none;
    cursor: pointer;
  }

  .finalize-container {
    min-height: 100vh;
    background: var(--color-background);
    padding: 1rem;
    padding-bottom: 120px; /* Space for bottom nav */
    max-width: 600px;
    margin: 0 auto;
    position: relative;
    z-index: 1;
  }

  .page-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 1.5rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid var(--color-border-light);
  }

  .back-button {
    background: none;
    border: 1px solid var(--color-border);
    color: var(--color-primary);
    font-size: 0.9rem;
    cursor: pointer;
    padding: 0.5rem 1rem;
    border-radius: 8px;
    transition: all 0.2s ease;
    pointer-events: auto;
    touch-action: manipulation;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    min-height: 44px;
    min-width: 44px;
  }

  .back-button:hover {
    background: var(--color-primary);
    color: white;
  }

  .back-button:active {
    transform: scale(0.98);
    background: var(--color-primary-dark);
    color: white;
  }

  .page-header h1 {
    font-size: 1.3rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0;
    text-align: center;
  }

  .subtitle {
    text-align: center;
    color: var(--color-ink-light);
    margin-bottom: 2rem;
    font-size: 1rem;
  }

  .order-summary-card {
    background: white;
    border-radius: 16px;
    padding: 1.5rem;
    margin-bottom: 2rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid var(--color-border-light);
  }

  .order-summary h3 {
    margin: 0 0 1rem 0;
    color: var(--color-ink);
    font-size: 1.1rem;
    font-weight: 600;
  }

  .summary-details {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--color-border-light);
  }

  .summary-row:last-child {
    border-bottom: none;
  }

  .total-row {
    font-weight: 600;
    font-size: 1.1rem;
    color: var(--color-ink);
    border-top: 2px solid var(--color-border-light);
    padding-top: 0.75rem;
    margin-top: 0.5rem;
  }

  .options-section {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .option-card-container {
    background: white;
    border-radius: 16px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid var(--color-border-light);
    overflow: hidden;
    position: relative;
    z-index: 1;
  }

  .option-card {
    width: 100%;
    background: none;
    border: none;
    padding: 1.5rem;
    display: flex;
    align-items: flex-start;
    gap: 1rem;
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: left;
    pointer-events: auto;
    touch-action: manipulation;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    min-height: 80px;
  }

  .option-card:hover:not(.unavailable) {
    background: var(--color-primary-light);
    transform: translateY(-1px);
  }

  .option-card:active:not(.unavailable) {
    transform: scale(0.98);
    background: var(--color-primary-light);
  }

  .option-card.unavailable {
    opacity: 0.6;
    cursor: not-allowed;
    background: #f8f9fa;
    pointer-events: none;
  }

  .option-icon {
    font-size: 2.5rem;
    flex-shrink: 0;
  }

  .option-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .option-content h3 {
    margin: 0;
    color: var(--color-ink);
    font-size: 1.2rem;
    font-weight: 600;
  }

  .option-description {
    margin: 0;
    color: var(--color-ink-light);
    font-size: 0.9rem;
  }

  .benefits-list {
    list-style: none;
    padding: 0;
    margin: 0.5rem 0;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .benefits-list li {
    color: var(--color-success);
    font-size: 0.85rem;
    font-weight: 500;
  }

  .store-info p {
    margin: 0.25rem 0;
    color: var(--color-ink-light);
    font-size: 0.85rem;
  }

  .service-status {
    margin-top: 0.5rem;
    padding: 0.75rem;
    border-radius: 8px;
    font-size: 0.85rem;
  }

  .service-status.available {
    background: #d1fae5;
    border: 1px solid #10b981;
    color: #065f46;
  }

  .service-status.unavailable {
    background: #fef2f2;
    border: 1px solid #ef4444;
    color: #7f1d1d;
  }

  .service-status p {
    margin: 0 0 0.25rem 0;
    font-weight: 500;
  }

  .service-status small {
    color: inherit;
    opacity: 0.8;
  }

  .option-arrow {
    color: var(--color-ink-light);
    font-size: 1.5rem;
    flex-shrink: 0;
    align-self: center;
  }

  /* Mobile optimizations */
  @media (max-width: 480px) {
    .finalize-container {
      padding: 0.75rem;
    }

    .option-card {
      flex-direction: column;
      text-align: center;
    }

    .option-arrow {
      align-self: center;
      transform: rotate(90deg);
    }
  }
</style>