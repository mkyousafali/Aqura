<script>
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { cartStore, cartActions, cartTotal, cartCount } from '$lib/stores/cart.js';
  import { supabase } from '$lib/utils/supabase';
  
  let currentLanguage = 'ar';
  let customerId = null;
  let offersChannel = null;
  
  // Delivery fee calculation
  const deliveryFee = 15.00; // SAR
  const freeDeliveryThreshold = 500.00; // SAR

  // Subscribe to cart updates using reactive syntax
  $: cartItems = $cartStore;
  $: total = $cartTotal;
  $: itemCount = $cartCount;

  // Create display items that combine BOGO pairs and Bundle items
  $: displayItems = (() => {
    const items = [];
    const processedGetIds = new Set();
    const processedBundleIds = new Set();
    
    $cartStore.forEach(item => {
      // Skip if this is a get product that's already been combined
      if ((item.offerType === 'bogo_get' || item.isAutoAdded) && processedGetIds.has(item.selectedUnit?.id)) {
        return;
      }
      
      // Skip if this is a bundle item that's already been combined
      if (item.offerType === 'bundle' && item.bundleId && processedBundleIds.has(item.bundleId)) {
        return;
      }
      
      // If this is a BOGO buy product, find and combine with get product
      if (item.offerType === 'bogo' && item.bogoGetProductId) {
        const getProduct = $cartStore.find(i => 
          i.selectedUnit?.id === item.bogoGetProductId && 
          (i.offerType === 'bogo_get' || i.isAutoAdded)
        );
        
        if (getProduct) {
          // Mark this get product as processed
          processedGetIds.add(getProduct.selectedUnit?.id);
          
          // Create combined BOGO item
          items.push({
            ...item,
            isCombinedBOGO: true,
            buyProduct: item,
            getProduct: getProduct,
            combinedPrice: (item.price * item.quantity) + (getProduct.price * getProduct.quantity)
          });
        } else {
          // Buy product without get product (shouldn't happen, but handle it)
          items.push(item);
        }
      } else if (item.offerType === 'bundle' && item.bundleId) {
        // Find all products in this bundle
        const bundleProducts = $cartStore.filter(i => 
          i.offerType === 'bundle' && i.bundleId === item.bundleId
        );
        
        if (bundleProducts.length > 0) {
          // Mark this bundle as processed
          processedBundleIds.add(item.bundleId);
          
          // Calculate total price for all bundle items
          const combinedPrice = bundleProducts.reduce((sum, prod) => 
            sum + (prod.price * prod.quantity), 0
          );
          
          // Create combined bundle item (use first item as base)
          items.push({
            ...item,
            isCombinedBundle: true,
            bundleProducts: bundleProducts,
            combinedPrice: combinedPrice
          });
        }
      } else if (item.offerType !== 'bogo_get' && !item.isAutoAdded && item.offerType !== 'bundle') {
        // Regular product
        items.push(item);
      }
    });
    
    return items;
  })();

  // Calculate final totals
  $: isFreeDelivery = total >= freeDeliveryThreshold;
  $: finalDeliveryFee = isFreeDelivery ? 0 : deliveryFee;
  $: finalTotal = total + finalDeliveryFee;

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }

    // Get customer ID if logged in
    try {
      const customerSessionRaw = localStorage.getItem('aqura-customer-session');
      if (customerSessionRaw) {
        const customerSession = JSON.parse(customerSessionRaw);
        if (customerSession?.customer_id && customerSession?.registration_status === 'approved') {
          customerId = customerSession.customer_id;
        }
      }
    } catch (error) {
      console.error('Error getting customer session:', error);
    }

    // Real-time subscriptions for offers and products
    offersChannel = supabase
      .channel('cart-offers-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offers' }, () => {
        console.log('📊 [Cart] Offers table changed, cleaning up cart...');
        cleanupExpiredOffers();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offer_products' }, () => {
        console.log('📦 [Cart] Offer products changed, cleaning up cart...');
        cleanupExpiredOffers();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bogo_offer_rules' }, () => {
        console.log('🎁 [Cart] BOGO rules changed, cleaning up cart...');
        cleanupExpiredOffers();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'products' }, () => {
        console.log('🛍️ [Cart] Products changed, cleaning up cart...');
        cleanupExpiredOffers();
      })
      .subscribe();
  });

  onDestroy(() => {
    if (offersChannel) {
      supabase.removeChannel(offersChannel);
    }
  });

  // Function to cleanup expired offers from cart
  async function cleanupExpiredOffers() {
    try {
      // Get branchId from orderFlow
      const orderFlowData = JSON.parse(localStorage.getItem('orderFlow') || '{}');
      const branchId = orderFlowData?.branchId;
      const serviceType = orderFlowData?.fulfillment || 'delivery';
      
      if (!branchId) {
        console.log('⚠️ [Cart] No branchId found, skipping cleanup');
        return;
      }
      
      // Get current active offers from API
      const response = await fetch(`/api/customer/products-with-offers?branchId=${branchId}&serviceType=${serviceType}`);
      if (!response.ok) return;
      
      const data = await response.json();
      const activeProducts = data.products || [];
      
      // Find all auto-added BOGO items in cart
      const autoAddedItems = $cartStore.filter(item => item.isAutoAdded);
      
      for (const autoItem of autoAddedItems) {
        // Find the buy product in active products
        const buyProduct = activeProducts.find(p => p.id === autoItem.bogoBuyProductId);
        
        // If buy product not found or no longer has BOGO offer, remove the auto-added item
        if (!buyProduct || buyProduct.offerType !== 'bogo' || !buyProduct.hasOffer) {
          console.log(`🧹 [Cart] Removing expired BOGO item: ${autoItem.name_en}`);
          cartActions.removeFromCart(autoItem.id, autoItem.selectedUnit?.id, true);
        }
      }
    } catch (error) {
      console.error('❌ [Cart] Error cleaning up expired offers:', error);
    }
  }

  function updateItemQuantity(item, change) {
    // Prevent quantity changes for BOGO bundle items
    if (item.offerType === 'bogo' || item.offerType === 'bogo_get') {
      return;
    }
    
    const newQuantity = Math.max(0, item.quantity + change);
    
    if (newQuantity === 0) {
      removeItem(item);
    } else {
      cartActions.updateQuantity(item.id, item.selectedUnit?.id, newQuantity);
    }
  }

  function removeItem(item) {
    // If this is a combined BOGO item, remove both buy and get products
    if (item.isCombinedBOGO) {
      if (item.buyProduct) {
        cartActions.removeFromCart(item.buyProduct.id, item.buyProduct.selectedUnit?.id, 'bogo');
      }
      if (item.getProduct) {
        cartActions.removeFromCart(item.getProduct.id, item.getProduct.selectedUnit?.id, 'bogo_get');
      }
      return;
    }
    
    // If this is a combined bundle item, remove all bundle products
    if (item.isCombinedBundle && item.bundleProducts) {
      item.bundleProducts.forEach(bundleProduct => {
        cartActions.removeFromCart(bundleProduct.id, bundleProduct.selectedUnit?.id, 'bundle');
      });
      return;
    }
    
    // If this is a BOGO buy product, also remove the linked get product
    if (item.offerType === 'bogo' && item.bogoGetProductId) {
      const getProduct = $cartStore.find(i => 
        i.selectedUnit?.id === item.bogoGetProductId && 
        (i.offerType === 'bogo_get' || i.isAutoAdded)
      );
      if (getProduct) {
        cartActions.removeFromCart(getProduct.id, getProduct.selectedUnit?.id, 'bogo_get');
      }
    }
    
    // If this is a BOGO get product, also remove the linked buy product
    if ((item.offerType === 'bogo_get' || item.isAutoAdded) && item.bogoBuyProductId) {
      const buyProduct = $cartStore.find(i => 
        i.selectedUnit?.id === item.bogoBuyProductId && 
        i.offerType === 'bogo'
      );
      if (buyProduct) {
        cartActions.removeFromCart(buyProduct.id, buyProduct.selectedUnit?.id, 'bogo');
      }
    }
    
    // Remove the item itself
    cartActions.removeFromCart(item.id, item.selectedUnit?.id, item.offerType);
  }

  function clearCart() {
    cartActions.clearCart();
  }

  function proceedToCheckout() {
    // Navigate to checkout page (to be implemented)
    goto('/customer-interface/checkout');
  }

  function continueShopping() {
    goto('/customer-interface/start');
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

  // Helper function to convert numbers to Arabic numerals
  function toArabicNumerals(num) {
    if (currentLanguage !== 'ar') return num.toString();
    const arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return num.toString().replace(/\d/g, (digit) => arabicNumerals[parseInt(digit)]);
  }

  // Helper function to format price with proper decimal handling
  function formatPrice(price) {
    const hasDecimals = price % 1 !== 0;
    const formatted = hasDecimals ? price.toFixed(2) : price.toFixed(0);
    return toArabicNumerals(formatted);
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
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
        {#each displayItems as item}
          <div class="cart-item">
            {#if item.isCombinedBOGO}
              <!-- Combined BOGO Display -->
              <div class="bogo-combined-images">
                <div class="bogo-image-wrapper">
                  {#if item.buyProduct.image}
                    <img src={item.buyProduct.image} alt={item.buyProduct.name} class="bogo-image" />
                  {:else}
                    <div class="image-placeholder">📦</div>
                  {/if}
                  <div class="bogo-quantity-badge">{item.buyProduct.quantity}</div>
                </div>
                <div class="bogo-plus">+</div>
                <div class="bogo-image-wrapper">
                  {#if item.getProduct.image}
                    <img src={item.getProduct.image} alt={item.getProduct.name} class="bogo-image" />
                  {:else}
                    <div class="image-placeholder">📦</div>
                  {/if}
                  <div class="bogo-quantity-badge">{item.getProduct.quantity}</div>
                  {#if item.getProduct.price === 0}
                    <div class="bogo-free-badge">{currentLanguage === 'ar' ? 'مجاناً' : 'FREE'}</div>
                  {/if}
                </div>
              </div>
              
              <div class="item-details">
                <h3 class="item-name bogo-title">
                  🎁 {currentLanguage === 'ar' ? 'عرض اشترِ واحصل' : 'BOGO Offer'}
                </h3>
                <div class="bogo-products-info">
                  <div class="bogo-product-line">
                    {currentLanguage === 'ar' ? item.buyProduct.name : (item.buyProduct.nameEn || item.buyProduct.name)}
                    <span class="bogo-unit-inline">
                      ({currentLanguage === 'ar' ? item.buyProduct.selectedUnit?.nameAr : item.buyProduct.selectedUnit?.nameEn})
                    </span>
                  </div>
                  <div class="bogo-product-line">
                    + {currentLanguage === 'ar' ? item.getProduct.name : (item.getProduct.nameEn || item.getProduct.name)}
                    <span class="bogo-unit-inline">
                      ({currentLanguage === 'ar' ? item.getProduct.selectedUnit?.nameAr : item.getProduct.selectedUnit?.nameEn})
                    </span>
                  </div>
                </div>
                <div class="item-price">
                  {#if currentLanguage === 'ar'}
                    {formatPrice(item.combinedPrice)}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                  {:else}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                    {formatPrice(item.combinedPrice)}
                  {/if}
                </div>
              </div>
              
              <div class="item-actions">
                <button class="remove-btn bogo-remove" on:click={() => removeItem(item)}>
                  ✕
                </button>
              </div>
            {:else if item.isCombinedBundle}
              <!-- Combined Bundle Display -->
              <div class="bundle-combined-images grid-{item.bundleProducts.length}">
                {#each item.bundleProducts as bundleProduct, idx}
                  <div class="bundle-image-wrapper">
                    {#if bundleProduct.image}
                      <img src={bundleProduct.image} alt={bundleProduct.name} class="bundle-image" />
                    {:else}
                      <div class="image-placeholder">📦</div>
                    {/if}
                    <div class="bundle-quantity-badge">{bundleProduct.quantity}</div>
                  </div>
                {/each}
              </div>
              
              <div class="item-details">
                <h3 class="item-name bundle-title">
                  📦 {currentLanguage === 'ar' ? 'عرض حزمة' : 'Bundle Offer'}
                </h3>
                <div class="bundle-products-info">
                  {#each item.bundleProducts as bundleProduct, idx}
                    <div class="bundle-product-line">
                      {#if idx > 0}+ {/if}
                      {currentLanguage === 'ar' ? bundleProduct.name : (bundleProduct.nameEn || bundleProduct.name)}
                      <span class="bundle-unit-inline">
                        ({currentLanguage === 'ar' ? bundleProduct.selectedUnit?.nameAr : bundleProduct.selectedUnit?.nameEn})
                      </span>
                    </div>
                  {/each}
                </div>
                <div class="item-price">
                  {#if currentLanguage === 'ar'}
                    {formatPrice(item.combinedPrice)}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                  {:else}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                    {formatPrice(item.combinedPrice)}
                  {/if}
                </div>
              </div>
              
              <div class="item-actions">
                <button class="remove-btn bundle-remove" on:click={() => removeItem(item)}>
                  ✕
                </button>
              </div>
            {:else}
              <!-- Regular Product Display -->
              <div class="item-image">
                {#if item.image}
                  <img src={item.image} alt={item.name} />
                {:else}
                  <div class="image-placeholder">📦</div>
                {/if}
              </div>

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
                  {#if currentLanguage === 'ar'}
                    {formatPrice(item.price)}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                  {:else}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                    {formatPrice(item.price)}
                  {/if}
                </div>
              </div>

              <div class="item-actions">
                <!-- Quantity Controls -->
                <div class="quantity-controls">
                  <button 
                    class="quantity-btn decrease" 
                    on:click={() => updateItemQuantity(item, -1)}
                  >
                    −
                  </button>
                  <span class="quantity-display">{toArabicNumerals(item.quantity)}</span>
                  <button 
                    class="quantity-btn increase" 
                    on:click={() => updateItemQuantity(item, 1)}
                  >
                    +
                  </button>
                </div>

                <!-- Item Total -->
                <div class="item-total">
                  {#if currentLanguage === 'ar'}
                    {formatPrice(item.price * item.quantity)}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                  {:else}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                    {formatPrice(item.price * item.quantity)}
                  {/if}
                </div>

                <!-- Remove Button -->
                <button class="remove-btn" on:click={() => removeItem(item)}>
                  ✕
                </button>
              </div>
            {/if}
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
            {#if currentLanguage === 'ar'}
              🚚 أضف {formatPrice(freeDeliveryThreshold - total)} <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" /> أكثر للحصول على توصيل مجاني!
            {:else}
              🚚 Add <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" /> {formatPrice(freeDeliveryThreshold - total)} more for free delivery!
            {/if}
          </div>
        {:else if isFreeDelivery}
          <div class="delivery-achieved">
            {texts.freeDeliveryReached}
          </div>
        {/if}

        <!-- Summary Breakdown -->
        <div class="summary-row">
          <span class="summary-label">{texts.subtotal}</span>
          <span class="summary-value">
            {#if currentLanguage === 'ar'}
              {formatPrice(total)}
              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
            {:else}
              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
              {formatPrice(total)}
            {/if}
          </span>
        </div>

        <div class="summary-row">
          <span class="summary-label">{texts.delivery}</span>
          <span class="summary-value" class:free={isFreeDelivery}>
            {#if isFreeDelivery}
              {texts.freeDelivery}
            {:else}
              {#if currentLanguage === 'ar'}
                {formatPrice(finalDeliveryFee)}
                <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
              {:else}
                <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                {formatPrice(finalDeliveryFee)}
              {/if}
            {/if}
          </span>
        </div>

        <div class="summary-row total-row">
          <span class="summary-label">{texts.total}</span>
          <span class="summary-value total-value">
            {#if currentLanguage === 'ar'}
              {formatPrice(finalTotal)}
              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
            {:else}
              <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
              {formatPrice(finalTotal)}
            {/if}
          </span>
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
  /* Currency icon styles */
  .currency-icon {
    height: 0.55rem;
    width: auto;
    display: inline-block;
    vertical-align: middle;
    margin: 0 0.15rem;
  }

  .currency-icon-small {
    height: 0.45rem;
    width: auto;
    display: inline-block;
    vertical-align: middle;
    margin: 0 0.1rem;
  }

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

  .quantity-btn:hover:not(:disabled) {
    border-color: var(--brand-green);
    background: var(--brand-green);
    color: white;
  }
  
  .quantity-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
    background: #f3f4f6;
    border-color: #e5e7eb;
    color: #9ca3af;
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
  }

  .remove-btn:hover {
    background: rgba(239, 68, 68, 0.1);
  }

  /* Combined BOGO Item Styles */
  .bogo-combined-images {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.35rem;
  }

  .bogo-image-wrapper {
    position: relative;
    width: 50px;
    height: 50px;
  }

  .bogo-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 8px;
    border: 2px solid #f59e0b;
  }

  .bogo-quantity-badge {
    position: absolute;
    top: -5px;
    right: -5px;
    background: #16a34a;
    color: white;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.65rem;
    font-weight: 700;
    border: 2px solid white;
  }

  .bogo-free-badge {
    position: absolute;
    bottom: -5px;
    left: 50%;
    transform: translateX(-50%);
    background: #10b981;
    color: white;
    padding: 1px 6px;
    border-radius: 8px;
    font-size: 0.55rem;
    font-weight: 700;
    white-space: nowrap;
  }

  .bogo-plus {
    font-size: 0.9rem;
    font-weight: 700;
    color: #f59e0b;
  }

  .bogo-title {
    color: #f59e0b;
    font-size: 0.75rem !important;
  }

  .bogo-products-info {
    font-size: 0.65rem;
    color: #64748b;
    margin-top: 0.2rem;
    line-height: 1.4;
  }

  .bogo-product-line {
    margin-bottom: 0.15rem;
  }

  .bogo-unit-inline {
    font-size: 0.6rem;
    color: #94a3b8;
  }

  .bogo-remove {
    margin-top: auto;
  }

  /* Bundle Offer Styles */
  .bundle-combined-images {
    display: flex;
    gap: 0.4rem;
    flex-wrap: nowrap;
    width: auto;
    min-width: 0;
    flex-shrink: 0;
    align-items: center;
  }

  .bundle-combined-images.grid-1 {
    /* Single image */
  }

  .bundle-combined-images.grid-2 {
    /* Two images */
  }

  .bundle-combined-images.grid-3 {
    /* Three images */
  }

  .bundle-combined-images.grid-4 {
    /* Four images */
  }

  .bundle-combined-images.grid-5,
  .bundle-combined-images.grid-6 {
    /* Five or six images */
  }

  .bundle-image-wrapper {
    position: relative;
    width: 65px;
    height: 65px;
    flex-shrink: 0;
  }

  .bundle-image {
    width: 100%;
    height: 100%;
    object-fit: contain;
    border-radius: 6px;
    border: 1px solid #ddd;
    background: #f9f9f9;
  }

  .bundle-quantity-badge {
    position: absolute;
    top: -5px;
    right: -5px;
    background: #10b981;
    color: white;
    border-radius: 50%;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.65rem;
    font-weight: 700;
    border: 2px solid white;
  }

  .bundle-title {
    color: #10b981;
    font-size: 0.75rem !important;
  }

  .bundle-products-info {
    font-size: 0.65rem;
    color: #64748b;
    margin-top: 0.2rem;
    line-height: 1.4;
  }

  .bundle-product-line {
    margin-bottom: 0.15rem;
  }

  .bundle-unit-inline {
    font-size: 0.6rem;
    color: #94a3b8;
  }

  .bundle-remove {
    margin-top: auto;
  }

  .remove-btn {
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
