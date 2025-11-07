<script>
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { cartStore, cartTotal, cartCount, cartActions } from '$lib/stores/cart.js';
  
  let currentLanguage = 'ar';
  let cartItems = [];
  let total = 0;
  let selectedPaymentMethod = '';
  let showOrderConfirmation = false;
  let showCancellationSuccess = false;
  let showOrderSuccess = false;
  let showPaymentMethods = false;
  let orderNumber = '';
  let orderPlacedTime = null;
  let cancellationTimer = null;
  let timeRemaining = 60; // 60 seconds for order cancellation
  let canCancelOrder = false;
  let fulfillmentMethod = 'delivery'; // Default to delivery

  // Delivery fee configuration
  const deliveryFee = 15.00; // SAR
  const freeDeliveryThreshold = 500.00; // SAR

  // Language texts
  $: texts = currentLanguage === 'ar' ? {
    title: fulfillmentMethod === 'pickup' ? 'استلام من المتجر - أكوا إكسبرس' : 'طلب توصيل - أكوا إكسبرس',
    backToFinalize: 'العودة للخيارات',
    yourOrder: 'طلبك',
    emptyCart: 'السلة فارغة',
    shopNow: 'تسوق الآن',
    paymentMethod: 'طريقة الدفع',
    choosePaymentMethod: 'اختر طريقة الدفع',
    cash: fulfillmentMethod === 'pickup' ? 'نقداً في المتجر' : 'نقداً عند الاستلام',
    card: fulfillmentMethod === 'pickup' ? 'بطاقة ائتمان في المتجر' : 'بطاقة ائتمان عند الاستلام',
    orderSummary: 'ملخص الطلب',
    subtotal: 'المجموع الفرعي',
    deliveryFee: 'رسوم التوصيل',
    total: 'المجموع الكلي',
    placeOrder: fulfillmentMethod === 'pickup' ? 'تأكيد طلب الاستلام' : 'تأكيد طلب التوصيل',
    orderConfirmed: 'تم تأكيد الطلب',
    orderNumber: 'رقم الطلب',
    thankYou: fulfillmentMethod === 'pickup' 
      ? 'شكراً لك! سيتم تحضير طلبك وسنتواصل معك عند جاهزيته للاستلام.' 
      : 'شكراً لك! سيتم تحضير طلبك والتواصل معك قريباً.',
    closeOrder: 'إغلاق',
    sar: 'ر.س',
    free: 'مجاني',
    remove: 'حذف',
    quantity: 'الكمية',
    cancellationNotice: 'يمكن إلغاء الطلب خلال دقيقة واحدة فقط من وقت تأكيد الطلب',
    cancelOrder: 'إلغاء الطلب',
    confirmOrder: 'تأكيد الطلب',
    timeRemaining: 'الوقت المتبقي للإلغاء',
    orderCancelled: 'تم إلغاء الطلب بنجاح',
    orderFinalized: 'تم تأكيد طلبك بنجاح!',
    freeDeliveryMsg: 'توصيل مجاني للطلبات أكثر من 500 ر.س',
    addMoreForFreeDelivery: 'أضف {amount} ر.س للحصول على التوصيل المجاني',
    fulfillmentType: fulfillmentMethod === 'pickup' ? 'الاستلام من المتجر' : 'التوصيل',
    readyIn: fulfillmentMethod === 'pickup' ? 'جاهز خلال 15-30 دقيقة' : 'يصل خلال 30-45 دقيقة',
    goToProducts: 'المتابعة للتسوق',
    customerInfo: 'معلومات العميل',
    deliveryInfo: 'معلومات التوصيل',
    estimatedDelivery: 'وقت التوصيل المتوقع: 30-60 دقيقة'
  } : {
    title: fulfillmentMethod === 'pickup' ? 'Store Pickup - Aqua Express' : 'Delivery Checkout - Aqua Express',
    backToFinalize: 'Back to Options',
    yourOrder: 'Your Order',
    emptyCart: 'Your cart is empty',
    shopNow: 'Shop Now',
    paymentMethod: 'Payment Method',
    choosePaymentMethod: 'Choose Payment Method',
    cash: fulfillmentMethod === 'pickup' ? 'Cash at Store' : 'Cash on Delivery',
    card: fulfillmentMethod === 'pickup' ? 'Card at Store' : 'Card on Delivery',
    orderSummary: 'Order Summary',
    subtotal: 'Subtotal',
    deliveryFee: 'Delivery Fee',
    total: 'Total',
    placeOrder: fulfillmentMethod === 'pickup' ? 'Confirm Pickup Order' : 'Confirm Delivery Order',
    orderConfirmed: 'Order Confirmed',
    orderNumber: 'Order Number',
    thankYou: fulfillmentMethod === 'pickup'
      ? 'Thank you! Your order will be prepared and we\'ll contact you when ready for pickup.'
      : 'Thank you! Your order will be prepared and we\'ll contact you shortly.',
    closeOrder: 'Close',
    sar: 'SAR',
    free: 'Free',
    remove: 'Remove',
    quantity: 'Quantity',
    cancellationNotice: 'Orders can be cancelled within 1 minute of confirmation',
    cancelOrder: 'Cancel Order',
    timeRemaining: 'Time remaining to cancel',
    orderCancelled: 'Order cancelled successfully',
    freeDeliveryMsg: 'Free delivery for orders over 500 SAR',
    addMoreForFreeDelivery: 'Add {amount} SAR for free delivery',
    fulfillmentType: fulfillmentMethod === 'pickup' ? 'Store Pickup' : 'Delivery',
    readyIn: fulfillmentMethod === 'pickup' ? 'Ready in 15-30 minutes' : 'Arrives in 30-45 minutes',
    placeOrder: 'Place Order',
    orderConfirmed: 'Order Confirmed',
    orderNumber: 'Order Number',
    thankYou: 'Thank you! Your order is being prepared and we will contact you soon.',
    closeOrder: 'Close',
    sar: 'SAR',
    free: 'Free',
    remove: 'Remove',
    quantity: 'Quantity',
    cancellationNotice: 'Order can only be cancelled within 1 minute of placing the order',
    cancelOrder: 'Cancel Order',
    confirmOrder: 'Place Order',
    timeRemaining: 'Time remaining to cancel',
    orderCancelled: 'Order cancelled successfully',
    orderFinalized: 'Your order has been confirmed successfully!',
    freeDeliveryMsg: 'Free delivery for orders over 500 SAR',
    addMoreForFreeDelivery: 'Add {amount} SAR more for free delivery',
    goToProducts: 'Continue Shopping',
    customerInfo: 'Customer Information',
    deliveryInfo: 'Delivery Information',
    estimatedDelivery: 'Estimated delivery: 30-60 minutes'
  };

  // Load language and cart data
  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }

    // Get fulfillment method from URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const fulfillmentParam = urlParams.get('fulfillment');
    if (fulfillmentParam === 'pickup' || fulfillmentParam === 'delivery') {
      fulfillmentMethod = fulfillmentParam;
    }

    // Subscribe to cart store
    const unsubscribeCart = cartStore.subscribe(items => {
      cartItems = items;
    });

    const unsubscribeTotal = cartTotal.subscribe(value => {
      total = value;
    });

    return () => {
      unsubscribeCart();
      unsubscribeTotal();
    };
  });

  // Cleanup timer on component destroy
  onDestroy(() => {
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
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

  // Cart management functions
  function updateQuantity(productId, unitId, newQuantity) {
    if (newQuantity <= 0) {
      cartActions.removeFromCart(productId, unitId);
    } else {
      cartActions.updateQuantity(productId, unitId, newQuantity);
    }
  }

  function increaseQuantity(item) {
    const newQuantity = (item.quantity || 1) + 1;
    updateQuantity(item.id, item.selectedUnit?.id, newQuantity);
  }

  function decreaseQuantity(item) {
    const newQuantity = (item.quantity || 1) - 1;
    if (newQuantity > 0) {
      updateQuantity(item.id, item.selectedUnit?.id, newQuantity);
    } else {
      cartActions.removeFromCart(item.id, item.selectedUnit?.id);
    }
  }

  function removeItem(item) {
    cartActions.removeFromCart(item.id, item.selectedUnit?.id);
  }

  // Order placement
  function placeOrder() {
    if (cartItems.length === 0) return;
    
    // Generate order number
    orderNumber = 'AQE' + Date.now().toString().slice(-6);
    
    // Record order placed time
    orderPlacedTime = new Date();
    canCancelOrder = true;
    timeRemaining = 60; // 60 seconds
    
    // Save order to active orders for tracking
    const newOrder = {
      orderNumber: orderNumber,
      placedAt: orderPlacedTime.getTime(),
      total: finalTotal,
      items: cartItems.length,
      paymentMethod: selectedPaymentMethod,
      canCancel: canCancelOrder,
      timeRemaining: timeRemaining
    };
    
    // Load existing active orders and add new one
    const existingOrders = JSON.parse(localStorage.getItem('activeOrders') || '[]');
    existingOrders.unshift(newOrder); // Add to beginning
    localStorage.setItem('activeOrders', JSON.stringify(existingOrders));
    
    // Start cancellation timer
    startCancellationTimer();
    
    // Show confirmation popup
    showOrderConfirmation = true;
    
    // Don't clear cart immediately - wait for timer or user action
    // Cart will be cleared when:
    // 1. Timer expires and order is finalized
    // 2. User clicks "Continue Shopping"
    // 3. User cancels the order (cart stays)
  }

  function startCancellationTimer() {
    cancellationTimer = setInterval(() => {
      timeRemaining -= 1;
      
      if (timeRemaining <= 0) {
        clearInterval(cancellationTimer);
        canCancelOrder = false;
        timeRemaining = 0;
        
        // Timer expired - finalize the order and clear cart// Close order confirmation popup
        showOrderConfirmation = false;
        
        // Show success popup
        showOrderSuccess = true;
        
        // Clear cart
        cartActions.clearCart();
        
        // Hide success popup after 2 seconds and redirect
        setTimeout(() => {
          showOrderSuccess = false;
          goto('/customer/products');
        }, 2000);
      }
    }, 1000);
  }

  function cancelOrder() {
    if (!canCancelOrder || timeRemaining <= 0) return;
    
    // Clear timer
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
    }
    
    // Reset states
    canCancelOrder = false;
    showOrderConfirmation = false;
    orderPlacedTime = null;
    timeRemaining = 60;
    
    // Show cancellation success message
    showCancellationSuccess = true;
    
    // Hide success message after 2 seconds
    setTimeout(() => {
      showCancellationSuccess = false;
    }, 2000);
  }

  function confirmOrderImmediately() {// Clear timer
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
    }
    
    // Disable cancellation
    canCancelOrder = false;
    timeRemaining = 0;
    
    // Close order confirmation popup
    showOrderConfirmation = false;
    
    // Show success popup
    showOrderSuccess = true;
    
    // Clear cart
    cartActions.clearCart();
    
    // Hide success popup after 2 seconds and redirect
    setTimeout(() => {
      showOrderSuccess = false;
      goto('/customer/products');
    }, 2000);
  }

  function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  }

  function closeOrderConfirmation() {showOrderConfirmation = false;
    
    // Clear timer if still running (order will be finalized)
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
    }
    
    // Reset cancellation states
    canCancelOrder = false;
    orderPlacedTime = null;
    timeRemaining = 60;
    
    // Clear cart when closing confirmation (order is finalized)
    cartActions.clearCart();
    
    goto('/customer/products');
  }

  function goBackToCart() {try {
      goto('/customer/finalize');
    } catch (error) {
      console.error('❌ [Checkout] Back navigation error:', error);
    }
  }

  function goToProducts() {// If there's an active order confirmation, clear the timer
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
      canCancelOrder = false;
    }
    
    // DO NOT clear the cart - customer should continue shopping with existing items
    // cartActions.clearCart(); // REMOVED - cart should remain intact
    
    // Close confirmation modal
    showOrderConfirmation = false;
    
    // Navigate to products so customer can continue shopping with existing cart
    goto('/customer/products');
  }

  function showPaymentMethodOptions() {showPaymentMethods = true;}

  function selectPaymentMethod(method) {selectedPaymentMethod = method;}

  // Calculate delivery fee
  $: isFreeDelivery = total >= freeDeliveryThreshold;
  $: finalDeliveryFee = fulfillmentMethod === 'pickup' ? 0 : (isFreeDelivery ? 0 : deliveryFee);
  $: finalTotal = (total || 0) + finalDeliveryFee;
  $: amountForFreeDelivery = freeDeliveryThreshold - (total || 0);
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="checkout-container">
  <!-- Header -->
  <div class="header">
    <button class="back-button" on:click={goBackToCart} type="button">
      ← {texts.backToFinalize}
    </button>
    <h1>{texts.title}</h1>
  </div>

  <!-- Cancellation Notice -->
  {#if cartItems.length > 0}
    <div class="notice-banner">
      <div class="notice-text">
        ⚠️ {texts.cancellationNotice}
      </div>
    </div>
  {/if}

  {#if cartItems.length === 0}
    <!-- Empty Cart State -->
    <div class="empty-cart">
      <div class="empty-cart-icon">🛒</div>
      <h2>{texts.emptyCart}</h2>
      <button class="shop-now-btn" on:click={goToProducts}>
        {texts.shopNow}
      </button>
    </div>
  {:else}
    <!-- Cart Items -->
    <div class="cart-section">
      <h2>{texts.yourOrder}</h2>
      <div class="cart-items">
        {#each cartItems as item (item.id + '-' + item.selectedUnit?.id)}
          <div class="cart-item">
            <div class="item-image">
              {#if item.image}
                <img src={item.image} alt={item.name} />
              {:else}
                <div class="item-placeholder">📦</div>
              {/if}
            </div>
            
            <div class="item-details">
              <h3>{currentLanguage === 'ar' ? item.name : item.nameEn}</h3>
              <div class="item-unit">
                {currentLanguage === 'ar' ? item.selectedUnit?.nameAr : item.selectedUnit?.nameEn}
              </div>
              <div class="item-price">
                {(item.price || 0).toFixed(2)} {texts.sar}
                {#if item.originalPrice && item.originalPrice > item.price}
                  <span class="original-price">{(item.originalPrice || 0).toFixed(2)} {texts.sar}</span>
                {/if}
              </div>
            </div>
            
            <div class="item-actions">
              <div class="quantity-controls">
                <button class="quantity-btn" on:click={() => decreaseQuantity(item)}>−</button>
                <span class="quantity-display">{item.quantity}</span>
                <button class="quantity-btn" on:click={() => increaseQuantity(item)}>+</button>
              </div>
              
              <div class="item-total">
                {((item.price || 0) * (item.quantity || 1)).toFixed(2)} {texts.sar}
              </div>
              
              <button class="remove-btn" on:click={() => removeItem(item)}>
                🗑️
              </button>
            </div>
          </div>
        {/each}
      </div>
    </div>

    <!-- Order Summary -->
    <div class="summary-section">
      <h2>{texts.orderSummary}</h2>
      <div class="summary-row">
        <span>{texts.subtotal}</span>
        <span>{(total || 0).toFixed(2)} {texts.sar}</span>
      </div>
      {#if fulfillmentMethod === 'delivery'}
        <div class="summary-row">
          <span>{texts.deliveryFee}</span>
          <div class="delivery-fee-container">
            <span>{isFreeDelivery ? texts.free : `${finalDeliveryFee.toFixed(2)} ${texts.sar}`}</span>
            {#if !isFreeDelivery && amountForFreeDelivery > 0}
              <small class="delivery-hint">
                {texts.addMoreForFreeDelivery.replace('{amount}', amountForFreeDelivery.toFixed(2))}
              </small>
            {:else if isFreeDelivery}
              <small class="delivery-hint free-delivery">
                {texts.freeDeliveryMsg}
              </small>
            {/if}
          </div>
        </div>
      {/if}
      <div class="summary-row total-row">
        <span>{texts.total}</span>
        <span>{finalTotal.toFixed(2)} {texts.sar}</span>
      </div>
      
      <div class="delivery-info">
        <p>{texts.estimatedDelivery}</p>
      </div>
    </div>

    <!-- Choose Payment Method Button -->
    {#if !showPaymentMethods}
      <div class="payment-button-section">
        <button 
          class="payment-method-btn" 
          on:click={showPaymentMethodOptions}
          type="button"
        >
          {texts.choosePaymentMethod}
        </button>
      </div>
    {/if}

    <!-- Payment Method Options -->
    {#if showPaymentMethods}
      <div class="payment-section">
        <h2>{texts.paymentMethod}</h2>
        <div class="payment-options">
          <label class="payment-option" class:selected={selectedPaymentMethod === 'cash'} on:click={() => selectPaymentMethod('cash')}>
            <input type="radio" bind:group={selectedPaymentMethod} value="cash" />
            <div class="payment-icon">💵</div>
            <span>{texts.cash}</span>
          </label>
          
          <label class="payment-option" class:selected={selectedPaymentMethod === 'card'} on:click={() => selectPaymentMethod('card')}>
            <input type="radio" bind:group={selectedPaymentMethod} value="card" />
            <div class="payment-icon">💳</div>
            <span>{texts.card}</span>
          </label>
        </div>
      </div>

      <!-- Place Order Button -->
      {#if selectedPaymentMethod !== ''}
        <div class="order-button-section">
          <button class="place-order-btn" on:click={placeOrder}>
            {texts.placeOrder} • {finalTotal.toFixed(2)} {texts.sar}
          </button>
        </div>
      {/if}
    {/if}
  {/if}
</div>

<!-- Order Confirmation Popup -->
{#if showOrderConfirmation}
  <div class="popup-overlay" on:click={closeOrderConfirmation}>
    <div class="popup-content" on:click|stopPropagation>
      <div class="popup-icon">✅</div>
      <h2>{texts.orderConfirmed}</h2>
      <p><strong>{texts.orderNumber}:</strong> {orderNumber}</p>
      <p>{texts.thankYou}</p>
      
      <!-- Cancellation Timer -->
      {#if canCancelOrder && timeRemaining > 0}
        <div class="cancellation-section">
          <div class="timer-display">
            <span class="timer-label">{texts.timeRemaining}:</span>
            <span class="timer-countdown">{formatTime(timeRemaining)}</span>
          </div>
          <div class="order-actions-buttons">
            <button class="cancel-order-btn" on:click={cancelOrder}>
              {texts.cancelOrder}
            </button>
            <button class="confirm-order-btn" on:click={confirmOrderImmediately}>
              {texts.confirmOrder}
            </button>
          </div>
        </div>
      {/if}
      
      <div class="popup-actions">
        <button class="close-btn" on:click={goToProducts}>
          {texts.goToProducts}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Cancellation Success Popup -->
{#if showCancellationSuccess}
  <div class="success-popup-overlay">
    <div class="success-popup-content">
      <div class="success-icon">✅</div>
      <h3>{texts.orderCancelled}</h3>
    </div>
  </div>
{/if}

<!-- Order Finalized Success Popup -->
{#if showOrderSuccess}
  <div class="success-popup-overlay">
    <div class="success-popup-content">
      <div class="success-icon">✅</div>
      <h3>{texts.orderFinalized}</h3>
    </div>
  </div>
{/if}

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
    font-family: inherit;
  }

  .checkout-container {
    min-height: 100vh;
    background: var(--color-background);
    padding: 1rem;
    padding-bottom: 120px; /* Space for bottom nav */
    max-width: 600px;
    margin: 0 auto;
  }

  .header {
    display: flex;
    align-items: center;
    gap: 1rem;
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
    z-index: 10;
    position: relative;
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

  .header h1 {
    font-size: 1.3rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0;
  }

  .notice-banner {
    background: #fff3cd;
    border: 1px solid #ffeeba;
    border-radius: 8px;
    padding: 0.75rem;
    margin-bottom: 1.5rem;
    text-align: center;
  }

  .notice-text {
    color: #856404;
    font-size: 0.9rem;
    font-weight: 500;
  }

  .empty-cart {
    text-align: center;
    padding: 3rem 1rem;
  }

  .empty-cart-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
  }

  .empty-cart h2 {
    color: var(--color-ink-light);
    margin-bottom: 2rem;
    font-size: 1.2rem;
  }

  .shop-now-btn {
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

  .shop-now-btn:hover {
    background: var(--color-primary-dark);
  }

  .cart-section, .payment-section, .summary-section {
    background: white;
    border: 1px solid var(--color-border-light);
    border-radius: 16px;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .cart-section h2, .payment-section h2, .summary-section h2 {
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 1rem 0;
  }

  .cart-items {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .cart-item {
    display: flex;
    gap: 1rem;
    padding: 1rem;
    border: 1px solid var(--color-border-light);
    border-radius: 12px;
    background: var(--color-background);
  }

  .item-image {
    flex-shrink: 0;
    width: 60px;
    height: 60px;
    border-radius: 8px;
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

  .item-placeholder {
    font-size: 1.5rem;
    color: var(--color-ink-light);
  }

  .item-details {
    flex: 1;
  }

  .item-details h3 {
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 0.25rem 0;
    line-height: 1.3;
  }

  .item-unit {
    font-size: 0.8rem;
    color: var(--color-ink-light);
    margin-bottom: 0.25rem;
  }

  .item-price {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--color-primary);
  }

  .original-price {
    font-size: 0.8rem;
    color: var(--color-ink-light);
    text-decoration: line-through;
    font-weight: 400;
    margin-left: 0.5rem;
  }

  .item-actions {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.5rem;
    justify-content: space-between;
  }

  .quantity-controls {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .quantity-btn {
    width: 28px;
    height: 28px;
    border: 1px solid var(--color-border);
    background: white;
    border-radius: 6px;
    font-size: 1rem;
    font-weight: bold;
    color: var(--color-ink);
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .quantity-btn:hover {
    border-color: var(--color-primary);
    background: var(--color-primary);
    color: white;
  }

  .quantity-display {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--color-ink);
    min-width: 24px;
    text-align: center;
    padding: 0.25rem;
  }

  .item-total {
    font-size: 0.9rem;
    font-weight: 700;
    color: var(--color-ink);
  }

  .remove-btn {
    background: none;
    border: none;
    color: var(--color-danger);
    font-size: 1.2rem;
    cursor: pointer;
    padding: 0.25rem;
    border-radius: 4px;
    transition: all 0.2s ease;
  }

  .remove-btn:hover {
    background: var(--color-danger);
    color: white;
  }

  .payment-options {
    display: flex;
    gap: 1rem;
  }

  .payment-option {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
    padding: 1rem;
    border: 2px solid var(--color-border);
    border-radius: 12px;
    cursor: pointer;
    transition: all 0.2s ease;
    background: white;
    pointer-events: auto;
    touch-action: manipulation;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    min-height: 80px;
    position: relative;
  }

  .payment-option:hover {
    border-color: var(--color-primary);
  }

  .payment-option:active {
    transform: scale(0.98);
    background: var(--color-primary-light);
  }

  .payment-option.selected {
    border-color: var(--color-primary);
    background: var(--color-primary-light);
  }

  .payment-option input {
    position: absolute;
    opacity: 0;
    width: 100%;
    height: 100%;
    top: 0;
    left: 0;
    margin: 0;
    cursor: pointer;
    z-index: 1;
  }

  .payment-icon {
    font-size: 2rem;
  }

  .payment-option span {
    font-weight: 500;
    color: var(--color-ink);
    text-align: center;
    font-size: 0.9rem;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 0;
    border-bottom: 1px solid var(--color-border-light);
  }

  .summary-row:last-of-type {
    border-bottom: none;
  }

  .total-row {
    font-size: 1.1rem;
    font-weight: 700;
    border-top: 2px solid var(--color-border-light);
    padding-top: 1rem;
    margin-top: 0.5rem;
  }

  .delivery-fee-container {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.25rem;
  }

  .delivery-hint {
    font-size: 0.75rem;
    color: var(--color-primary);
    font-weight: 500;
    text-align: right;
    line-height: 1.2;
  }

  .delivery-hint.free-delivery {
    color: var(--color-success);
  }

  .delivery-info {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid var(--color-border-light);
  }

  .delivery-info p {
    margin: 0;
    color: var(--color-ink-light);
    font-size: 0.85rem;
    text-align: center;
  }

  .payment-button-section, .order-button-section {
    background: white;
    border: 1px solid var(--color-border-light);
    border-radius: 16px;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .payment-method-btn, .place-order-btn {
    width: 100%;
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 1rem;
    border-radius: 12px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    pointer-events: auto;
    position: relative;
    z-index: 10;
  }

  .payment-method-btn:hover, .place-order-btn:hover {
    background: var(--color-primary-dark);
  }

  .popup-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 1rem;
  }

  .popup-content {
    background: white;
    border-radius: 16px;
    padding: 2rem;
    text-align: center;
    max-width: 400px;
    width: 100%;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
  }

  .popup-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  .popup-content h2 {
    color: var(--color-ink);
    margin-bottom: 1rem;
  }

  .popup-content p {
    color: var(--color-ink-light);
    margin-bottom: 1rem;
    line-height: 1.5;
  }

  .cancellation-section {
    background: #fff3cd;
    border: 1px solid #ffeeba;
    border-radius: 8px;
    padding: 1rem;
    margin: 1.5rem 0;
    text-align: center;
  }

  .timer-display {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    margin-bottom: 1rem;
  }

  .timer-label {
    font-size: 0.9rem;
    color: var(--color-ink);
    font-weight: 600;
  }

  .timer-countdown {
    font-size: 1.5rem;
    font-weight: bold;
    color: #dc3545;
    background: white;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    border: 2px solid #dc3545;
    min-width: 60px;
    font-family: monospace;
  }

  .order-actions-buttons {
    display: flex;
    gap: 1rem;
    justify-content: center;
    align-items: center;
    flex-wrap: wrap;
  }

  .cancel-order-btn {
    background: var(--color-danger);
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    flex: 1;
    min-width: 140px;
  }

  .cancel-order-btn:hover {
    background: #dc2626;
  }

  .confirm-order-btn {
    background: #10b981;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    flex: 1;
    min-width: 140px;
  }

  .confirm-order-btn:hover {
    background: #059669;
  }

  .popup-actions {
    margin-top: 1.5rem;
  }

  .close-btn {
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 1rem 2rem;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
  }

  .close-btn:hover {
    background: var(--color-primary-dark);
  }

  /* Mobile optimizations */
  @media (max-width: 480px) {
    .checkout-container {
      padding: 0.75rem;
    }

    .cart-item {
      flex-direction: column;
      gap: 1rem;
    }

    .item-actions {
      flex-direction: row;
      justify-content: space-between;
      align-items: center;
    }

    .payment-options {
      flex-direction: column;
    }
    
    .payment-button-section, .order-button-section {
      padding: 1rem;
    }
  }

  /* Cancellation Success Popup */
  .success-popup-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
    padding: 1rem;
    animation: fadeIn 0.2s ease-out;
  }

  .success-popup-content {
    background: white;
    border-radius: 16px;
    padding: 2rem;
    text-align: center;
    max-width: 300px;
    width: 100%;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
    animation: slideUp 0.3s ease-out;
  }

  .success-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
    animation: scaleIn 0.3s ease-out 0.1s both;
  }

  .success-popup-content h3 {
    color: var(--color-ink);
    margin: 0;
    font-size: 1.1rem;
    font-weight: 600;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }

  @keyframes slideUp {
    from {
      opacity: 0;
      transform: translateY(20px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes scaleIn {
    from {
      transform: scale(0);
    }
    to {
      transform: scale(1);
    }
  }
</style>



