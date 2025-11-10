<script>
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { cartStore, cartTotal, cartCount, cartActions } from '$lib/stores/cart.js';
  import { deliveryActions, deliveryTiers, freeDeliveryThreshold as freeDeliveryThresholdStore } from '$lib/stores/delivery.js';
  import { orderFlow, orderFlowActions } from '$lib/stores/orderFlow.js';
  import { currentUser } from '$lib/utils/persistentAuth';
  import { supabase } from '$lib/utils/supabase';
  import LocationMapDisplay from '$lib/components/LocationMapDisplay.svelte';
  import LocationPicker from '$lib/components/LocationPicker.svelte';
  
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
  let locationOptions = [];
  let currentBranchId = null; // Track branch ID locally
  let selectedLocationKey = '';
  let selectedLocationIndex = 0;
  let loadingLocations = true;
  let showLocationPickerModal = false;
  let editingLocationSlot = 1;
  let pickedLocation = null;
  let customLocationName = '';
  let savingLocation = false;
  let customerRecord = null;
  let showSlotSelector = false;
  let showMapPopup = false;
  let mapPopupLocation = null;

  // Get customer session from localStorage (faster than waiting for store)
  function getLocalCustomerSession() {
    try {
      console.log('🔍 [Checkout] Checking localStorage for customer session...');
      
      // Try customer_session first (direct customer login)
      const customerSessionRaw = localStorage.getItem('customer_session');
      console.log('🔍 [Checkout] customer_session raw:', customerSessionRaw);
      
      if (customerSessionRaw) {
        const customerSession = JSON.parse(customerSessionRaw);
        console.log('🔍 [Checkout] Parsed customer session:', customerSession);
        console.log('🔍 [Checkout] customer_id:', customerSession?.customer_id);
        console.log('🔍 [Checkout] registration_status:', customerSession?.registration_status);
        
        // Check if it's a valid approved customer session
        if (customerSession?.customer_id && customerSession?.registration_status === 'approved') {
          console.log('✅ [Checkout] Found approved customer with ID:', customerSession.customer_id);
          return { 
            customerId: customerSession.customer_id, 
            customer: customerSession 
          };
        }
      }

      // Fallback to aqura-device-session (employee with customer access)
      console.log('🔍 [Checkout] Checking aqura-device-session...');
      const raw = localStorage.getItem('aqura-device-session');
      console.log('🔍 [Checkout] aqura-device-session raw:', raw);
      
      if (!raw) {
        console.log('⚠️ [Checkout] No device session found');
        return { customerId: null };
      }
      
      const session = JSON.parse(raw);
      console.log('🔍 [Checkout] Parsed device session:', session);
      
      const currentId = session?.currentUserId;
      console.log('🔍 [Checkout] currentUserId:', currentId);
      
      const user = Array.isArray(session?.users)
        ? session.users.find((u) => u.id === currentId && u.isActive)
        : null;
      console.log('🔍 [Checkout] Found user:', user);
      
      const customerId = user?.customerId || null;
      console.log('🔍 [Checkout] Extracted customerId:', customerId);
      
      return { customerId, customer: user?.customer };
    } catch (e) {
      console.error('❌ [Checkout] Error reading session:', e);
      return { customerId: null };
    }
  }

  // Branch-aware delivery fee will be computed from delivery tiers store

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
    newOrder: 'طلب جديد',
    trackOrder: 'تتبع الطلب',
    orderSuccess: 'تم تأكيد طلبك بنجاح!',
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
    chooseLocation: 'اختر موقع التوصيل',
    selectLocationFirst: 'اختر موقع التوصيل أولاً'
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
    newOrder: 'New Order',
    trackOrder: 'Track Order',
    orderSuccess: 'Your order has been confirmed successfully!',
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
    chooseLocation: 'Choose Delivery Location',
    selectLocationFirst: 'Please select a delivery location first'
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

  // Load language and cart data
  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }

    // Initialize branchId from orderFlow
    const orderFlowData = orderFlowActions.get();
    currentBranchId = orderFlowData?.branchId || null;
    console.log('🏢 [Checkout] Initialized branchId:', currentBranchId);

    // Load delivery tiers for the selected branch
    if (currentBranchId) {
      console.log('🏢 [Checkout] Loading delivery tiers for branch:', currentBranchId);
      deliveryActions.loadTiers(currentBranchId).then(() => {
        console.log('✅ [Checkout] Delivery tiers loaded');
      }).catch(err => {
        console.error('❌ [Checkout] Error loading delivery tiers:', err);
      });
    }

    // Get fulfillment method from URL parameters (or orderFlow)
    const urlParams = new URLSearchParams(window.location.search);
    const fulfillmentParam = urlParams.get('fulfillment');
    if (fulfillmentParam === 'pickup' || fulfillmentParam === 'delivery') {
      fulfillmentMethod = fulfillmentParam;
    } else {
      const flow = JSON.parse(localStorage.getItem('orderFlow') || '{}');
      if (flow?.fulfillment) {
        fulfillmentMethod = flow.fulfillment;
      }
    }

    // Subscribe to cart store
    const unsubscribeCart = cartStore.subscribe(items => {
      cartItems = items;
    });

    const unsubscribeTotal = cartTotal.subscribe(value => {
      total = value;
    });

    // Load customer saved locations
    (async () => {
      // 1) Try fast local session first
      const local = getLocalCustomerSession();
      console.log('📍 [Checkout] Local session:', local);
      
      if (local.customerId) {
        console.log('📍 [Checkout] Loading locations from local session for customer:', local.customerId);
        const { data, error } = await supabase
          .from('customers')
          .select('location1_name, location1_url, location1_lat, location1_lng, location2_name, location2_url, location2_lat, location2_lng, location3_name, location3_url, location3_lat, location3_lng')
          .eq('id', local.customerId)
          .single();
        
        if (!error && data) {
          locationOptions = [];
          console.log('📍 [Checkout] Customer location data:', data);
          for (let i=1;i<=3;i++) {
            const name = data[`location${i}_name`];
            const url = data[`location${i}_url`];
            const lat = data[`location${i}_lat`];
            const lng = data[`location${i}_lng`];
            console.log(`📍 [Checkout] Location ${i}:`, { name, url, lat, lng });
            if (lat && lng) {
              locationOptions.push({ 
                key: `location${i}`, 
                name: name || `Location ${i}`, 
                url: url||'', 
                lat: Number(lat), 
                lng: Number(lng) 
              });
            }
          }
          console.log('📍 [Checkout] Final locationOptions:', locationOptions);
          // Don't auto-select - require user to check the box
          selectedLocationKey = '';
          selectedLocationIndex = -1;
        } else if (error) {
          console.error('❌ [Checkout] Error loading locations:', error);
        }
        loadingLocations = false;
      }
    })();
    
    // 2) Also subscribe to currentUser store for updates
    const unsubUser = currentUser.subscribe(async (cu) => {
      // Skip if we already loaded from local session
      if (locationOptions.length > 0) return;
      
      console.log('👤 [Checkout] Current user from store:', cu);
      
      if (!cu) {
        console.log('⚠️ [Checkout] No current user in store');
        loadingLocations = false;
        return;
      }
      
      // Try customerId first, then fall back to id
      const customerIdToUse = cu.customerId || cu.id;
      
      if (!customerIdToUse) { 
        console.log('⚠️ [Checkout] No customerId or id found in store');
        loadingLocations = false; 
        return; 
      }
      console.log('📍 [Checkout] Loading locations from store for customer:', customerIdToUse);
      const { data, error } = await supabase
        .from('customers')
        .select('location1_name, location1_url, location1_lat, location1_lng, location2_name, location2_url, location2_lat, location2_lng, location3_name, location3_url, location3_lat, location3_lng')
        .eq('id', customerIdToUse)
        .single();
      if (!error && data) {
        locationOptions = [];
        console.log('📍 [Checkout] Customer location data:', data);
        for (let i=1;i<=3;i++) {
          const name = data[`location${i}_name`];
          const url = data[`location${i}_url`];
          const lat = data[`location${i}_lat`];
          const lng = data[`location${i}_lng`];
          console.log(`📍 [Checkout] Location ${i}:`, { name, url, lat, lng });
          if (lat && lng) {
            locationOptions.push({ 
              key: `location${i}`, 
              name: name || `Location ${i}`, 
              url: url||'', 
              lat: Number(lat), 
              lng: Number(lng) 
            });
          }
        }
        console.log('📍 [Checkout] Final locationOptions:', locationOptions);
        // Don't auto-select - require user to check the box
        selectedLocationKey = '';
        selectedLocationIndex = -1;
      } else if (error) {
        console.error('❌ [Checkout] Error loading locations:', error);
      }
      loadingLocations = false;
    });

    return () => {
      unsubscribeCart();
      unsubscribeTotal();
      unsubUser && unsubUser();
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

  // Location Picker Functions
  function openLocationPicker(slotNumber) {
    editingLocationSlot = slotNumber;
    pickedLocation = null;
    customLocationName = '';
    showLocationPickerModal = true;
  }

  function closeLocationPickerModal() {
    showLocationPickerModal = false;
    pickedLocation = null;
    customLocationName = '';
    savingLocation = false;
  }

  function handleLocationPicked(location) {
    pickedLocation = location;
  }

  async function savePickedLocation() {
    if (!pickedLocation) return;
    
    // Get customer ID
    const local = getLocalCustomerSession();
    if (!local.customerId) {
      alert(currentLanguage === 'ar' ? 'فشل تحديد العميل' : 'Failed to identify customer');
      return;
    }
    
    // Use custom name if provided, otherwise use the address from geocoding
    const locationName = customLocationName.trim() || pickedLocation.name;
    
    try {
      savingLocation = true;
      const updates = {
        [`location${editingLocationSlot}_name`]: locationName,
        [`location${editingLocationSlot}_url`]: pickedLocation.url,
        [`location${editingLocationSlot}_lat`]: pickedLocation.lat,
        [`location${editingLocationSlot}_lng`]: pickedLocation.lng,
      };

      const { error } = await supabase
        .from('customers')
        .update(updates)
        .eq('id', local.customerId);

      if (error) {
        console.error('❌ [Checkout] Failed to save location:', error);
        alert(currentLanguage === 'ar' ? 'فشل حفظ الموقع' : 'Failed to save location');
      } else {
        // Reload locations
        const { data } = await supabase
          .from('customers')
          .select('location1_name, location1_url, location1_lat, location1_lng, location2_name, location2_url, location2_lat, location2_lng, location3_name, location3_url, location3_lat, location3_lng')
          .eq('id', local.customerId)
          .single();
        
        if (data) {
          locationOptions = [];
          for (let i=1;i<=3;i++) {
            const name = data[`location${i}_name`];
            const url = data[`location${i}_url`];
            const lat = data[`location${i}_lat`];
            const lng = data[`location${i}_lng`];
            if (lat && lng) {
              locationOptions.push({ 
                key: `location${i}`, 
                name: name || `Location ${i}`, 
                url: url||'', 
                lat: Number(lat), 
                lng: Number(lng) 
              });
            }
          }
        }
        
        closeLocationPickerModal();
        
        // Show success message
        const successMsg = currentLanguage === 'ar' ? 'تم حفظ الموقع بنجاح!' : 'Location saved successfully!';
        alert(successMsg);
      }
    } catch (e) {
      console.error('❌ [Checkout] Exception saving location:', e);
      alert(currentLanguage === 'ar' ? 'حدث خطأ غير متوقع' : 'Unexpected error');
    } finally {
      savingLocation = false;
    }
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
  
  function confirmOrder() {
    confirmOrderImmediately();
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

  function closeOrderConfirmation() {
    showOrderConfirmation = false;
    
    // Clear timer if still running
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
    }
    
    // Reset cancellation states
    canCancelOrder = false;
    orderPlacedTime = null;
    timeRemaining = 60;
    
    // Clear cart and go home
    cartActions.clearCart();
    goto('/customer');
  }

  function goToNewOrder() {
    showOrderConfirmation = false;
    
    // Clear timer
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
    }
    
    // Clear cart and go to start page
    cartActions.clearCart();
    goto('/customer/start');
  }

  function goToTrackOrder() {
    showOrderConfirmation = false;
    
    // Clear timer
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
    }
    
    // Go to track order page
    goto('/customer/track-order');
  }

  function goBackToCart() {
    try {
      goto('/customer/cart');
    } catch (error) {
      console.error('❌ [Checkout] Back navigation error:', error);
    }
  }

  function goToProducts() {
    // If there's an active order confirmation, clear the timer
    if (cancellationTimer) {
      clearInterval(cancellationTimer);
      canCancelOrder = false;
    }
    
    // Close confirmation modal
    showOrderConfirmation = false;
    
    // If cart is empty, go to start page to set up order flow
    if (cartItems.length === 0) {
      goto('/customer/start');
    } else {
      // If cart has items, go to products to continue shopping
      goto('/customer/products');
    }
  }

  function selectPaymentMethod(method) {
    selectedPaymentMethod = method;
    // Place order immediately after selecting payment method
    setTimeout(() => {
      placeOrder();
    }, 100);
  }

  // Calculate delivery fee (branch-aware)
  $: freeDeliveryThreshold = $freeDeliveryThresholdStore;
  $: isFreeDelivery = total >= freeDeliveryThreshold;
  
  // Sync currentBranchId with orderFlow store
  $: if ($orderFlow?.branchId && $orderFlow.branchId !== currentBranchId) {
    currentBranchId = $orderFlow.branchId;
    console.log('🏢 [Checkout] BranchId updated from store:', currentBranchId);
    // Reload tiers when branch changes
    deliveryActions.loadTiers(currentBranchId).then(() => {
      console.log('✅ [Checkout] Delivery tiers reloaded for branch:', currentBranchId);
    });
  }
  
  $: finalDeliveryFee = (() => {
    if (fulfillmentMethod === 'pickup') return 0;
    if (!currentBranchId) {
      console.log('⚠️ [Checkout] No branchId available for delivery fee calculation');
      return 0;
    }
    console.log('🔍 [Checkout] Delivery tiers available:', $deliveryTiers);
    console.log('🔍 [Checkout] Calculating fee for branchId:', currentBranchId, 'total:', total);
    const fee = deliveryActions.getDeliveryFeeLocal(total || 0, currentBranchId);
    console.log('💰 [Checkout] Calculated delivery fee:', fee, 'for total:', total, 'branchId:', currentBranchId);
    return fee;
  })();
  $: finalTotal = (total || 0) + finalDeliveryFee;
  $: amountForFreeDelivery = freeDeliveryThreshold > 0 ? (freeDeliveryThreshold - (total || 0)) : 0;
  $: canProceedToPayment = !!selectedLocationKey || fulfillmentMethod === 'pickup' || locationOptions.length === 0; // allow if pickup or no saved locations
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="checkout-container">
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
      <button 
        class="shop-now-btn" 
        type="button"
        on:click={goToProducts}
        on:touchend|preventDefault={goToProducts}
      >
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
                <span class="price-display" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
                  {#if currentLanguage === 'ar'}
                    {formatPrice(item.price || 0)}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                  {:else}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                    {formatPrice(item.price || 0)}
                  {/if}
                </span>
                {#if item.originalPrice && item.originalPrice > item.price}
                  <span class="original-price">
                    <span class="price-display" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
                      {#if currentLanguage === 'ar'}
                        {formatPrice(item.originalPrice || 0)}
                        <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                      {:else}
                        <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                        {formatPrice(item.originalPrice || 0)}
                      {/if}
                    </span>
                  </span>
                {/if}
              </div>
            </div>
            
            <div class="item-actions">
              <div class="quantity-controls">
                <button class="quantity-btn" on:click={() => decreaseQuantity(item)}>−</button>
                <span class="quantity-display">{toArabicNumerals(item.quantity)}</span>
                <button class="quantity-btn" on:click={() => increaseQuantity(item)}>+</button>
              </div>
              
              <div class="item-total">
                <span class="price-display" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
                  {#if currentLanguage === 'ar'}
                    {formatPrice((item.price || 0) * (item.quantity || 1))}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                  {:else}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                    {formatPrice((item.price || 0) * (item.quantity || 1))}
                  {/if}
                </span>
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
        <span class="price-display" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
          {#if currentLanguage === 'ar'}
            {formatPrice(total || 0)}
            <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
          {:else}
            <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
            {formatPrice(total || 0)}
          {/if}
        </span>
      </div>
      {#if fulfillmentMethod === 'delivery'}
        <div class="summary-row">
          <span>{texts.deliveryFee}</span>
          <div class="delivery-fee-container">
            {#if isFreeDelivery}
              <span>{texts.free}</span>
            {:else}
              <span class="price-display" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
                {#if currentLanguage === 'ar'}
                  {formatPrice(finalDeliveryFee)}
                  <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                {:else}
                  <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                  {formatPrice(finalDeliveryFee)}
                {/if}
              </span>
            {/if}
            {#if !isFreeDelivery && amountForFreeDelivery > 0}
              <small class="delivery-hint" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
                {#if currentLanguage === 'ar'}
                  أضف {formatPrice(amountForFreeDelivery)} <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-tiny" /> للحصول على التوصيل المجاني
                {:else}
                  Add <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-tiny" /> {formatPrice(amountForFreeDelivery)} for free delivery
                {/if}
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
        <span class="price-display" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
          {#if currentLanguage === 'ar'}
            {formatPrice(finalTotal)}
            <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
          {:else}
            <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
            {formatPrice(finalTotal)}
          {/if}
        </span>
      </div>
    </div>

    <!-- Delivery Location Selection (only for delivery) -->
    {#if fulfillmentMethod === 'delivery'}
      <div class="location-section">
        <h2>{texts.chooseLocation}</h2>
        {#if loadingLocations}
          <div class="location-loading">Loading locations…</div>
        {:else}
          {#if locationOptions.length > 0}
            <div class="location-options">
              {#each locationOptions as loc, index}
                <label 
                  class="location-option" 
                  class:selected={selectedLocationKey === loc.key}
                  on:click|preventDefault={() => {
                    if (selectedLocationKey === loc.key) {
                      selectedLocationKey = '';
                      selectedLocationIndex = -1;
                    } else {
                      selectedLocationKey = loc.key;
                      selectedLocationIndex = index;
                      // Show payment methods directly
                      showPaymentMethods = true;
                      // Scroll to payment section
                      setTimeout(() => {
                        const paymentSection = document.querySelector('.payment-section');
                        if (paymentSection) {
                          paymentSection.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        }
                      }, 150);
                    }
                  }}
                >
                  <div class="location-icon-wrapper">
                    <svg class="location-icon-svg" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z" fill="currentColor"/>
                    </svg>
                  </div>
                  <div class="location-info">
                    <span class="location-name">{loc.name}</span>
                  </div>
                  <div class="custom-checkbox" class:checked={selectedLocationKey === loc.key}>
                    {#if selectedLocationKey === loc.key}
                      <span class="checkmark">✓</span>
                    {/if}
                  </div>
                </label>
              {/each}
            </div>
            
            <!-- Add New Location Button (if slots available) or Change Location Button (if all full) -->
            {#if locationOptions.length < 3}
              <button class="add-location-btn" on:click={() => {
                // Find first empty slot
                let emptySlot = null;
                for (let i = 1; i <= 3; i++) {
                  const existing = locationOptions.find(loc => loc.key === `location${i}`);
                  if (!existing) {
                    emptySlot = i;
                    break;
                  }
                }
                openLocationPicker(emptySlot || 1);
              }}>
                <span class="add-icon">+</span>
                {currentLanguage === 'ar' ? 'إضافة موقع جديد' : 'Add New Location'}
              </button>
            {:else}
              <button class="change-location-btn" on:click={() => {
                showSlotSelector = true;
              }}>
                <span class="change-icon">🔄</span>
                {currentLanguage === 'ar' ? 'تغيير موقع' : 'Change Location'}
              </button>
            {/if}
          {:else}
            <div class="location-empty">
              {currentLanguage === 'ar' ? 'لا توجد مواقع محفوظة. سيتم التنسيق معك بعد تأكيد الطلب.' : 'No saved locations. We will coordinate your location after order confirmation.'}
            </div>
          {/if}
        {/if}
      </div>
    {/if}

    <!-- Payment Method Options - Show directly when location is selected OR for pickup -->
    {#if canProceedToPayment}
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
    {/if}
  {/if}
</div>

<!-- Order Confirmation Popup -->
{#if showOrderConfirmation}
  <div class="popup-overlay" on:click|stopPropagation>
    <div class="popup-content" on:click|stopPropagation>
      <div class="popup-icon">✅</div>
      <h2>{texts.orderConfirmed}</h2>
      <div class="order-number-display">
        <strong>{texts.orderNumber}:</strong>
        <span class="order-number-value">{orderNumber}</span>
      </div>
      <p class="thank-you-message">{texts.thankYou}</p>
      
      <!-- Cancellation Section with Timer -->
      {#if canCancelOrder && timeRemaining > 0}
        <div class="cancellation-section">
          <div class="timer-display">
            <span class="timer-label">{texts.timeRemaining}:</span>
            <div class="timer-countdown">{timeRemaining}s</div>
          </div>
          <div class="order-actions-buttons">
            <button class="cancel-order-btn" on:click={cancelOrder}>
              {texts.cancelOrder}
            </button>
            <button class="confirm-order-btn" on:click={confirmOrder}>
              {texts.confirmOrder}
            </button>
          </div>
        </div>
      {/if}
      
      <div class="popup-actions">
        <button class="new-order-btn" on:click={goToNewOrder}>
          🛒 {texts.newOrder}
        </button>
        <button class="track-order-btn" on:click={goToTrackOrder}>
          📦 {texts.trackOrder}
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

<!-- Slot Selector Modal (when all 3 slots are full) -->
{#if showSlotSelector}
  <div class="modal-overlay" on:click={() => { showSlotSelector = false; }}>
    <div class="slot-selector-content" on:click|stopPropagation>
      <div class="modal-header">
        <h3>{currentLanguage === 'ar' ? 'اختر الموقع المراد تغييره' : 'Select Location to Replace'}</h3>
        <button class="close-modal-btn" on:click={() => { showSlotSelector = false; }}>✕</button>
      </div>
      <div class="slot-selector-body">
        {#each locationOptions as loc, index}
          <button 
            class="slot-option" 
            on:click={() => {
              const slotNumber = parseInt(loc.key.replace('location', ''));
              showSlotSelector = false;
              openLocationPicker(slotNumber);
            }}
          >
            <div class="slot-map-preview">
              <LocationMapDisplay 
                locations={[loc]}
                selectedIndex={0}
                language={currentLanguage}
                height="80px"
              />
            </div>
            <div class="slot-info">
              <span class="slot-number">{index + 1}</span>
              <span class="slot-name">{loc.name}</span>
            </div>
            <span class="replace-arrow">→</span>
          </button>
        {/each}
      </div>
    </div>
  </div>
{/if}

<!-- Location Picker Modal -->
{#if showLocationPickerModal}
  <div class="modal-overlay" on:click={closeLocationPickerModal}>
    <div class="modal-content" on:click|stopPropagation>
      <div class="modal-header">
        <h3>📍 {currentLanguage === 'ar' ? `اختر الموقع ${editingLocationSlot}` : `Pick Location ${editingLocationSlot}`}</h3>
        <button class="close-modal-btn" on:click={closeLocationPickerModal}>✕</button>
      </div>
      <div class="modal-body">
        <LocationPicker
          initialLat={24.7136}
          initialLng={46.6753}
          onLocationSelect={handleLocationPicked}
          language={currentLanguage}
        />
        {#if pickedLocation}
          <div class="picked-location-info">
            <label for="location-name-input" class="location-name-label">
              {currentLanguage === 'ar' ? 'اسم الموقع (اختياري)' : 'Location Name (optional)'}
            </label>
            <input 
              id="location-name-input"
              type="text" 
              bind:value={customLocationName}
              placeholder={currentLanguage === 'ar' ? 'مثل: المنزل، المكتب' : 'e.g. Home, Office'}
              class="location-name-input"
            />
            <p class="location-address-label"><strong>{currentLanguage === 'ar' ? 'العنوان:' : 'Address:'}</strong></p>
            <p class="location-address">{pickedLocation.name}</p>
            <p class="location-coords">{pickedLocation.lat.toFixed(6)}, {pickedLocation.lng.toFixed(6)}</p>
          </div>
        {/if}
      </div>
      <div class="modal-footer">
        <button class="cancel-modal-btn" on:click={closeLocationPickerModal}>{currentLanguage === 'ar' ? 'إلغاء' : 'Cancel'}</button>
        <button class="save-modal-btn" disabled={!pickedLocation || savingLocation} on:click={savePickedLocation}>
          {savingLocation ? (currentLanguage === 'ar' ? 'جاري الحفظ...' : 'Saving...') : (currentLanguage === 'ar' ? 'حفظ الموقع' : 'Save Location')}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Map View Popup -->
{#if showMapPopup && mapPopupLocation}
  <div class="map-popup-overlay" on:click={() => { showMapPopup = false; mapPopupLocation = null; }}>
    <div class="map-popup-content" on:click|stopPropagation>
      <div class="map-popup-header">
        <h3>📍 {mapPopupLocation.name}</h3>
        <button class="close-map-popup-btn" on:click={() => { showMapPopup = false; mapPopupLocation = null; }}>✕</button>
      </div>
      <div class="map-popup-body">
        <LocationMapDisplay 
          locations={[mapPopupLocation]}
          selectedIndex={0}
          language={currentLanguage}
          height="400px"
        />
      </div>
    </div>
  </div>
{/if}

<style>
  /* Currency icon styles */
  .price-display {
    display: inline-block;
    white-space: nowrap;
  }
  
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

  .currency-icon-tiny {
    height: 0.45rem;
    width: auto;
    display: inline-block;
    vertical-align: middle;
    margin: 0 0.1rem;
  }

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
    padding: 0.5rem;
    padding-bottom: 84px;
    max-width: 100%;
    width: 100%;
    margin: 0 auto;
    position: relative;
    z-index: 1;
    overflow-y: auto;
    overflow-x: hidden;
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

  .notice-banner {
    background: #fff3cd;
    border: 1px solid #ffeeba;
    border-radius: 6px;
    padding: 0.53rem;
    margin-bottom: 1.05rem;
    text-align: center;
    position: relative;
    z-index: 10;
  }

  .notice-text {
    color: #856404;
    font-size: 0.63rem;
    font-weight: 500;
  }

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

  .empty-cart h2 {
    color: var(--color-ink-light);
    margin-bottom: 1.4rem;
    font-size: 0.84rem;
  }

  .shop-now-btn {
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 0.7rem 1.4rem;
    border-radius: 8px;
    font-size: 0.7rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    pointer-events: auto;
    touch-action: manipulation;
    -webkit-tap-highlight-color: transparent;
    user-select: none;
    position: relative;
    z-index: 100;
  }

  .shop-now-btn:hover {
    background: var(--color-primary-dark);
  }
  
  .shop-now-btn:active {
    transform: scale(0.98);
  }

  .cart-section, .payment-section, .summary-section {
    background: white;
    border: 1px solid var(--color-border-light);
    border-radius: 11px;
    padding: 0.75rem;
    margin-bottom: 0.75rem;
    box-shadow: 0 1.4px 5.6px rgba(0, 0, 0, 0.1);
    position: relative;
    z-index: 10;
    width: 100%;
    box-sizing: border-box;
    overflow: hidden;
  }

  .location-section {
    background: white;
    border: 1px solid var(--color-border-light);
    border-radius: 11px;
    padding: 0.75rem;
    margin-bottom: 0.75rem;
    box-shadow: 0 1.4px 5.6px rgba(0, 0, 0, 0.1);
    position: relative;
    z-index: 10;
    width: 100%;
    box-sizing: border-box;
    overflow: hidden;
  }

  .location-section h2 { font-size: 0.77rem; font-weight:600; margin:0 0 0.7rem 0; color: var(--color-ink); }
  .location-loading, .location-empty { font-size:0.63rem; color: var(--color-ink-light); }
  
  .location-options { display:flex; flex-direction:column; gap:0.5rem; margin-top: 1rem; }
  .location-option { 
    display:flex; 
    align-items:flex-start; 
    gap:0.75rem; 
    border: 2px solid var(--color-border-light); 
    border-radius:10px; 
    padding:0.75rem; 
    cursor:pointer;
    transition: all 0.2s ease;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.02) 0%, transparent 100%);
    flex-direction: row;
    position: relative;
  }
  .location-option .location-icon-wrapper {
    flex-shrink: 0;
    width: 60px;
    height: 60px;
    border-radius: 50%;
    overflow: hidden;
    border: 2px solid rgba(22, 163, 74, 0.2);
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.1) 0%, rgba(34, 197, 94, 0.05) 100%);
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }
  .location-option .location-icon-svg {
    width: 32px;
    height: 32px;
    color: #16a34a;
  }
  .location-option.selected .location-icon-wrapper {
    border-color: rgba(255, 255, 255, 0.5);
    background: rgba(255, 255, 255, 0.2);
  }
  .location-option.selected .location-icon-svg {
    color: white;
  }
  .location-option .location-info {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-width: 0;
    padding-right: 2rem;
  }
  .location-option .custom-checkbox {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    flex-shrink: 0;
  }
  .location-option:hover {
    border-color: rgba(22, 163, 74, 0.4);
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.08) 0%, rgba(34, 197, 94, 0.05) 100%);
    transform: translateX(-3px);
  }
  .location-option.selected { 
    border-color: var(--color-primary); 
    background: linear-gradient(135deg, #16a34a 0%, #22c55e 100%);
    box-shadow: 0 4px 12px rgba(22, 163, 74, 0.25);
  }
  .location-option.selected .location-icon-wrapper {
    border-color: rgba(255, 255, 255, 0.5);
    background: rgba(255, 255, 255, 0.2);
  }
  .location-option.selected .location-icon-svg {
    color: white;
  }
  .location-option.selected .location-name {
    color: white;
    font-weight: 600;
  }
  .location-option.selected .location-number {
    background: rgba(255, 255, 255, 0.3);
    color: white;
  }
  .custom-checkbox {
    width: 24px;
    height: 24px;
    border: 2.5px solid #16a34a;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: all 0.2s ease;
    background: white;
  }
  .custom-checkbox.checked {
    background: #16a34a;
    border-color: #16a34a;
  }
  .custom-checkbox .checkmark {
    color: white;
    font-size: 16px;
    font-weight: bold;
    line-height: 1;
  }
  .location-option.selected .custom-checkbox {
    border-color: white;
    background: white;
  }
  .location-option.selected .custom-checkbox.checked {
    background: rgba(255, 255, 255, 0.95);
  }
  .location-option.selected .custom-checkbox .checkmark {
    color: #16a34a;
  }
  .location-number {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    background: rgba(22, 163, 74, 0.15);
    border-radius: 50%;
    font-size: 0.75rem;
    font-weight: 700;
    color: #16a34a;
    flex-shrink: 0;
  }
  .location-name { 
    font-size:0.85rem; 
    color: var(--color-ink); 
    font-weight: 500; 
    word-wrap: break-word;
    overflow-wrap: break-word;
    line-height: 1.4;
  }
  .location-link { 
    font-size:1rem; 
    text-decoration:none;
    padding: 0.25rem;
    transition: transform 0.2s ease;
  }
  .location-link:hover {
    transform: scale(1.2);
  }
  .payment-hint { display:block; margin-top:0.4rem; font-size:0.6rem; color:#dc2626; }

  /* Add Location Button */
  .add-location-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    width: 100%;
    margin-top: 0.75rem;
    padding: 0.875rem;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.1) 0%, rgba(34, 197, 94, 0.05) 100%);
    border: 2px dashed #16a34a;
    border-radius: 10px;
    color: #16a34a;
    font-size: 0.8rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .add-location-btn:hover {
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.15) 0%, rgba(34, 197, 94, 0.1) 100%);
    border-color: #22c55e;
    transform: translateY(-2px);
  }
  .add-location-btn .add-icon {
    font-size: 1.2rem;
    font-weight: bold;
  }

  /* Change Location Button */
  .change-location-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    width: 100%;
    margin-top: 0.75rem;
    padding: 0.875rem;
    background: linear-gradient(135deg, rgba(245, 158, 11, 0.1) 0%, rgba(251, 191, 36, 0.05) 100%);
    border: 2px dashed #f59e0b;
    border-radius: 10px;
    color: #f59e0b;
    font-size: 0.8rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .change-location-btn:hover {
    background: linear-gradient(135deg, rgba(245, 158, 11, 0.15) 0%, rgba(251, 191, 36, 0.1) 100%);
    border-color: #fbbf24;
    transform: translateY(-2px);
  }
  .change-location-btn .change-icon {
    font-size: 1.1rem;
  }

  /* Slot Selector Modal */
  .slot-selector-content {
    background: white;
    border-radius: 16px;
    width: 100%;
    max-width: 400px;
    max-height: 80vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
  }
  .slot-selector-body {
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    overflow-y: auto;
  }
  .slot-option {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem;
    border: 2px solid #e5e7eb;
    border-radius: 10px;
    background: white;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .slot-option:hover {
    border-color: #16a34a;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.05) 0%, transparent 100%);
    transform: translateX(4px);
  }
  .slot-map-preview {
    flex-shrink: 0;
    width: 80px;
    height: 80px;
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid #e5e7eb;
  }
  .slot-info {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    flex: 1;
  }
  .slot-number {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    background: rgba(22, 163, 74, 0.15);
    border-radius: 50%;
    font-size: 0.7rem;
    font-weight: 700;
    color: #16a34a;
  }
  .slot-name {
    font-size: 0.85rem;
    color: #374151;
    font-weight: 500;
  }
  .replace-arrow {
    font-size: 1.25rem;
    color: #f59e0b;
    font-weight: bold;
  }

  /* Location Picker Modal */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 9999;
    padding: 1rem;
  }
  .modal-content {
    background: white;
    border-radius: 16px;
    width: 100%;
    max-width: 500px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
  }
  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #e5e7eb;
  }
  .modal-header h3 {
    margin: 0;
    font-size: 1rem;
    color: #16a34a;
    font-weight: 600;
  }
  .close-modal-btn {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: #f3f4f6;
    color: #6b7280;
    font-size: 1.25rem;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
  }
  .close-modal-btn:hover {
    background: #e5e7eb;
    color: #374151;
  }
  .modal-body {
    flex: 1;
    overflow-y: auto;
    padding: 1.25rem;
  }
  .picked-location-info {
    margin-top: 1rem;
    padding: 1rem;
    background: #f0fdf4;
    border-radius: 8px;
    border: 1px solid #bbf7d0;
  }
  .location-name-label {
    display: block;
    font-size: 0.75rem;
    font-weight: 600;
    color: #16a34a;
    margin-bottom: 0.5rem;
  }
  .location-name-input {
    width: 100%;
    padding: 0.625rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 0.875rem;
    margin-bottom: 0.75rem;
  }
  .location-name-input:focus {
    outline: none;
    border-color: #16a34a;
    box-shadow: 0 0 0 3px rgba(22, 163, 74, 0.1);
  }
  .location-address-label {
    font-size: 0.75rem;
    margin: 0 0 0.25rem 0;
    color: #16a34a;
  }
  .location-address {
    font-size: 0.8rem;
    color: #374151;
    margin: 0 0 0.5rem 0;
  }
  .location-coords {
    font-size: 0.7rem;
    color: #6b7280;
    margin: 0;
    font-family: monospace;
  }
  .modal-footer {
    display: flex;
    gap: 0.75rem;
    padding: 1rem 1.25rem;
    border-top: 1px solid #e5e7eb;
  }
  .cancel-modal-btn, .save-modal-btn {
    flex: 1;
    padding: 0.75rem;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    transition: all 0.2s ease;
  }
  .cancel-modal-btn {
    background: #f3f4f6;
    color: #6b7280;
  }
  .cancel-modal-btn:hover {
    background: #e5e7eb;
    color: #374151;
  }
  .save-modal-btn {
    background: linear-gradient(135deg, #16a34a 0%, #22c55e 100%);
    color: white;
  }
  .save-modal-btn:hover:not(:disabled) {
    background: linear-gradient(135deg, #15803d 0%, #16a34a 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(22, 163, 74, 0.3);
  }
  .save-modal-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* Map Popup */
  .map-popup-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.75);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10000;
    padding: 1rem;
  }
  .map-popup-content {
    background: white;
    border-radius: 16px;
    width: 100%;
    max-width: 600px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.4);
  }
  .map-popup-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #e5e7eb;
  }
  .map-popup-header h3 {
    margin: 0;
    font-size: 1.1rem;
    color: #16a34a;
    font-weight: 600;
  }
  .close-map-popup-btn {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: #f3f4f6;
    color: #6b7280;
    font-size: 1.5rem;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
  }
  .close-map-popup-btn:hover {
    background: #e5e7eb;
    color: #374151;
    transform: rotate(90deg);
  }
  .map-popup-body {
    flex: 1;
    overflow: hidden;
    padding: 0;
    border-radius: 0 0 16px 16px;
  }



  .cart-section h2, .payment-section h2, .summary-section h2 {
    font-size: 0.77rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 0.7rem 0;
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

  .item-placeholder {
    font-size: 1.05rem;
    color: var(--color-ink-light);
  }

  .item-details {
    flex: 1;
  }

  .item-details h3 {
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
    color: var(--color-primary);
  }

  .original-price {
    font-size: 0.56rem;
    color: var(--color-ink-light);
    text-decoration: line-through;
    font-weight: 400;
    margin-left: 0.35rem;
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
    border-color: var(--color-primary);
    background: var(--color-primary);
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

  .payment-options {
    display: flex;
    gap: 0.7rem;
  }

  .payment-option {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.35rem;
    padding: 0.7rem;
    border: 2px solid var(--color-border);
    border-radius: 8.4px;
    cursor: pointer;
    transition: all 0.2s ease;
    background: white;
    pointer-events: auto;
    touch-action: manipulation;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    min-height: 56px;
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
    font-size: 1.4rem;
  }

  .payment-option span {
    font-weight: 500;
    color: var(--color-ink);
    text-align: center;
    font-size: 0.63rem;
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

  .total-row {
    font-size: 0.77rem;
    font-weight: 700;
    border-top: 2px solid var(--color-border-light);
    padding-top: 0.7rem;
    margin-top: 0.35rem;
  }

  .delivery-fee-container {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.18rem;
  }

  .delivery-hint {
    font-size: 0.53rem;
    color: var(--color-primary);
    font-weight: 500;
    text-align: right;
    line-height: 1.2;
  }

  .delivery-hint.free-delivery {
    color: var(--color-success);
  }

  .delivery-info {
    margin-top: 0.7rem;
    padding-top: 0.7rem;
    border-top: 1px solid var(--color-border-light);
  }

  .delivery-info p {
    margin: 0;
    color: var(--color-ink-light);
    font-size: 0.6rem;
    text-align: center;
  }

  .payment-button-section, .order-button-section {
    background: white;
    border: 1px solid var(--color-border-light);
    border-radius: 11px;
    padding: 1.05rem;
    margin-bottom: 1.05rem;
    box-shadow: 0 1.4px 5.6px rgba(0, 0, 0, 0.1);
    position: relative;
    z-index: 10;
  }

  .payment-method-btn, .place-order-btn {
    width: 100%;
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 0.7rem;
    border-radius: 8.4px;
    font-size: 0.7rem;
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
    padding: 0.7rem;
  }

  .popup-content {
    background: white;
    border-radius: 11px;
    padding: 1.4rem;
    text-align: center;
    max-width: 280px;
    width: 100%;
    box-shadow: 0 7px 21px rgba(0, 0, 0, 0.3);
  }

  .popup-icon {
    font-size: 2.1rem;
    margin-bottom: 0.7rem;
  }

  .popup-content h2 {
    color: var(--color-ink);
    margin-bottom: 0.7rem;
  }

  .popup-content p {
    color: var(--color-ink-light);
    margin-bottom: 0.7rem;
    line-height: 1.5;
  }

  .cancellation-section {
    background: #fff3cd;
    border: 1px solid #ffeeba;
    border-radius: 5.6px;
    padding: 0.7rem;
    margin: 1.05rem 0;
    text-align: center;
  }

  .timer-display {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.35rem;
    margin-bottom: 0.7rem;
  }

  .timer-label {
    font-size: 0.63rem;
    color: var(--color-ink);
    font-weight: 600;
  }

  .timer-countdown {
    font-size: 1.05rem;
    font-weight: bold;
    color: #dc3545;
    background: white;
    padding: 0.35rem 0.7rem;
    border-radius: 4.2px;
    border: 2px solid #dc3545;
    min-width: 42px;
    font-family: monospace;
  }

  .order-actions-buttons {
    display: flex;
    gap: 0.7rem;
    justify-content: center;
    align-items: center;
    flex-wrap: wrap;
  }

  .cancel-order-btn {
    background: var(--color-danger);
    color: white;
    border: none;
    padding: 0.53rem 1.05rem;
    border-radius: 5.6px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    flex: 1;
    min-width: 98px;
  }

  .cancel-order-btn:hover {
    background: #dc2626;
  }

  .confirm-order-btn {
    background: #10b981;
    color: white;
    border: none;
    padding: 0.53rem 1.05rem;
    border-radius: 5.6px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    flex: 1;
    min-width: 98px;
  }

  .confirm-order-btn:hover {
    background: #059669;
  }

  .order-number-display {
    background: #f0fdf4;
    border: 2px solid #16a34a;
    border-radius: 8.4px;
    padding: 0.7rem;
    margin: 0.7rem 0;
    text-align: center;
  }

  .order-number-value {
    display: block;
    font-size: 1.05rem;
    font-weight: bold;
    color: #16a34a;
    margin-top: 0.35rem;
    letter-spacing: 0.7px;
  }

  .thank-you-message {
    margin: 0.7rem 0;
    line-height: 1.6;
  }

  .popup-actions {
    margin-top: 1.05rem;
    display: flex;
    flex-direction: column;
    gap: 0.53rem;
  }

  .new-order-btn,
  .track-order-btn,
  .close-btn {
    width: 100%;
    border: none;
    padding: 0.7rem 1.4rem;
    border-radius: 5.6px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 0.7rem;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.35rem;
  }

  .new-order-btn {
    background: #16a34a;
    color: white;
  }

  .new-order-btn:hover {
    background: #15803d;
    transform: translateY(-0.7px);
    box-shadow: 0 2.8px 8.4px rgba(22, 163, 74, 0.3);
  }

  .track-order-btn {
    background: #f59e0b;
    color: white;
  }

  .track-order-btn:hover {
    background: #d97706;
    transform: translateY(-0.7px);
    box-shadow: 0 2.8px 8.4px rgba(245, 158, 11, 0.3);
  }

  .close-btn {
    background: #6b7280;
    color: white;
  }

  .close-btn:hover {
    background: #4b5563;
    transform: translateY(-0.7px);
  }

  /* Mobile optimizations */
  @media (max-width: 480px) {
    .checkout-container {
      padding: 0.53rem;
    }
    
    /* Smaller bubbles on mobile */
    .bubble {
      transform: scale(0.6);
      box-shadow: 
        inset -3px -3px 6px rgba(255, 255, 255, 0.4),
        inset 3px 3px 6px rgba(0, 0, 0, 0.1),
        0 0 8px rgba(255, 255, 255, 0.3);
    }
    
    .payment-button-section, .order-button-section {
      padding: 0.7rem;
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
    padding: 0.7rem;
    animation: fadeIn 0.2s ease-out;
  }

  .success-popup-content {
    background: white;
    border-radius: 11px;
    padding: 1.4rem;
    text-align: center;
    max-width: 210px;
    width: 100%;
    box-shadow: 0 7px 21px rgba(0, 0, 0, 0.3);
    animation: slideUp 0.3s ease-out;
  }

  .success-icon {
    font-size: 2.1rem;
    margin-bottom: 0.7rem;
    animation: scaleIn 0.3s ease-out 0.1s both;
  }

  .success-popup-content h3 {
    color: var(--color-ink);
    margin: 0;
    font-size: 0.77rem;
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
      transform: translateY(14px);
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



