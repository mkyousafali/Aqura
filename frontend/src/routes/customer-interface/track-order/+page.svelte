<script>
  import { onMount, onDestroy } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/utils/supabase';
  
  let currentLanguage = 'ar';
  let orders = [];
  let loading = true;
  let selectedOrder = null;
  let orderItems = [];
  let loadingItems = false;
  let subscription;
  let itemsSubscription;
  let pollInterval;

  // Order status flow based on fulfillment method
  const DELIVERY_FLOW = ['new', 'accepted', 'in_picking', 'ready', 'out_for_delivery', 'delivered'];
  const PICKUP_FLOW = ['new', 'accepted', 'in_picking', 'ready', 'picked_up'];

  function getStatusFlow(fulfillmentMethod) {
    return fulfillmentMethod === 'pickup' ? PICKUP_FLOW : DELIVERY_FLOW;
  }

  const STATUS_ICONS = {
    new: '🛒',
    accepted: '✅',
    in_picking: '📦',
    ready: '✨',
    out_for_delivery: '🚚',
    delivered: '🏠',
    picked_up: '🏪',
    cancelled: '❌'
  };

  $: texts = currentLanguage === 'ar' ? {
    title: 'تتبع طلباتي - أكوا إكسبرس',
    trackOrder: 'تتبع طلباتي',
    backToProfile: 'العودة للملف الشخصي',
    noActiveOrders: 'لا توجد طلبات نشطة',
    noActiveOrdersDesc: 'ستظهر طلباتك هنا بعد الطلب',
    startShopping: 'تسوّق الآن',
    orderNumber: 'رقم الطلب',
    orderDate: 'تاريخ الطلب',
    totalAmount: 'المبلغ الإجمالي',
    items: 'المنتجات',
    sar: 'ر.س',
    quantity: 'الكمية',
    unitPrice: 'سعر الوحدة',
    lineTotal: 'الإجمالي',
    fulfillment: 'طريقة الاستلام',
    delivery: 'توصيل',
    pickup: 'استلام من الفرع',
    paymentMethod: 'طريقة الدفع',
    cash: 'نقداً',
    card: 'بطاقة',
    customerNotes: 'ملاحظات',
    orderTimeline: 'مراحل الطلب',
    viewDetails: 'عرض التفاصيل',
    hideDetails: 'إخفاء التفاصيل',
    estimatedDelivery: 'التوصيل المتوقع',
    placedAt: 'تم الطلب',
    acceptedAt: 'تم القبول',
    pickingAt: 'قيد التحضير',
    readyAt: 'جاهز للتوصيل',
    outForDeliveryAt: 'خارج للتوصيل',
    deliveredAt: 'تم التوصيل',
    pickedUpAt: 'تم الاستلام',
    cancelledAt: 'تم الإلغاء',
    new: 'تم الطلب',
    accepted: 'تم القبول',
    in_picking: 'قيد التحضير',
    ready: 'جاهز',
    out_for_delivery: 'قيد التوصيل',
    delivered: 'تم التوصيل',
    picked_up: 'تم الاستلام',
    cancelled: 'ملغي',
    liveTracking: 'تتبع مباشر',
    refreshing: 'جاري التحديث...'
  } : {
    title: 'Track My Orders - Aqua Express',
    trackOrder: 'Track My Orders',
    backToProfile: 'Back to Profile',
    noActiveOrders: 'No Active Orders',
    noActiveOrdersDesc: 'Your orders will appear here after you place one',
    startShopping: 'Start Shopping',
    orderNumber: 'Order Number',
    orderDate: 'Order Date',
    totalAmount: 'Total Amount',
    items: 'Items',
    sar: 'SAR',
    quantity: 'Qty',
    unitPrice: 'Unit Price',
    lineTotal: 'Total',
    fulfillment: 'Fulfillment',
    delivery: 'Delivery',
    pickup: 'Pickup',
    paymentMethod: 'Payment',
    cash: 'Cash',
    card: 'Card',
    customerNotes: 'Notes',
    orderTimeline: 'Order Timeline',
    viewDetails: 'View Details',
    hideDetails: 'Hide Details',
    estimatedDelivery: 'Estimated Delivery',
    placedAt: 'Order Placed',
    acceptedAt: 'Accepted',
    pickingAt: 'Being Prepared',
    readyAt: 'Ready for Delivery',
    outForDeliveryAt: 'Out for Delivery',
    deliveredAt: 'Delivered',
    pickedUpAt: 'Picked Up',
    cancelledAt: 'Cancelled',
    new: 'Order Placed',
    accepted: 'Accepted',
    in_picking: 'Preparing',
    ready: 'Ready',
    out_for_delivery: 'Out for Delivery',
    delivered: 'Delivered',
    picked_up: 'Picked Up',
    cancelled: 'Cancelled',
    liveTracking: 'Live Tracking',
    refreshing: 'Refreshing...'
  };

  function getLocalCustomerSession() {
    try {
      const customerSessionRaw = localStorage.getItem('customer_session');
      if (customerSessionRaw) {
        const customerSession = JSON.parse(customerSessionRaw);
        if (customerSession?.customer_id && customerSession?.registration_status === 'approved') {
          return { customerId: customerSession.customer_id };
        }
      }
      const raw = localStorage.getItem('aqura-device-session');
      if (!raw) return { customerId: null };
      const session = JSON.parse(raw);
      const currentId = session?.currentUserId;
      const user = Array.isArray(session?.users)
        ? session.users.find((u) => u.id === currentId && u.isActive)
        : null;
      return { customerId: user?.customerId || null };
    } catch (e) {
      return { customerId: null };
    }
  }

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) currentLanguage = savedLanguage;

    // Listen for language changes
    window.addEventListener('storage', handleStorageChange);
    window.addEventListener('languageChanged', handleLanguageEvent);

    await loadOrders();
    setupRealtime();

    // Auto-poll every 10s as fallback for missed realtime events
    pollInterval = setInterval(() => {
      silentRefreshOrders();
    }, 10000);
  });

  function handleStorageChange(event) {
    if (event.key === 'language' && event.newValue) {
      currentLanguage = event.newValue;
    }
  }

  function handleLanguageEvent(event) {
    currentLanguage = event.detail || localStorage.getItem('language') || 'ar';
  }

  onDestroy(() => {
    if (pollInterval) clearInterval(pollInterval);
    if (subscription) {
      supabase.removeChannel(subscription);
    }
    if (itemsSubscription) {
      supabase.removeChannel(itemsSubscription);
    }
    if (typeof window !== 'undefined') {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('languageChanged', handleLanguageEvent);
    }
  });

  function setupRealtime() {
    const { customerId } = getLocalCustomerSession();
    if (!customerId) return;

    // Subscribe to orders changes (INSERT + UPDATE)
    subscription = supabase
      .channel('customer-orders-tracking')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'orders',
          filter: `customer_id=eq.${customerId}`
        },
        (payload) => {
          console.log('📡 New order received:', payload);
          const newOrder = payload.new;
          // Add new order to list if not already there
          if (!orders.find(o => o.id === newOrder.id)) {
            orders = [newOrder, ...orders];
          }
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'orders',
          filter: `customer_id=eq.${customerId}`
        },
        (payload) => {
          console.log('📡 Order update received:', payload);
          const updated = payload.new;
          // If order is now delivered/cancelled/picked_up, remove from active list
          if (updated.order_status === 'delivered' || updated.order_status === 'cancelled' || updated.order_status === 'picked_up') {
            orders = orders.filter(o => o.id !== updated.id);
            if (selectedOrder && selectedOrder.id === updated.id) {
              selectedOrder = { ...selectedOrder, ...updated };
              // Keep it visible for a moment so user sees final status
              setTimeout(() => {
                if (selectedOrder?.id === updated.id) {
                  selectedOrder = null;
                  orderItems = [];
                }
              }, 5000);
            }
          } else {
            orders = orders.map(o => o.id === updated.id ? { ...o, ...updated } : o);
            if (selectedOrder && selectedOrder.id === updated.id) {
              selectedOrder = { ...selectedOrder, ...updated };
            }
          }
        }
      )
      .subscribe((status) => {
        console.log('📡 Orders realtime status:', status);
      });

    // Subscribe to order_items changes
    itemsSubscription = supabase
      .channel('customer-order-items-tracking')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'order_items'
        },
        (payload) => {
          console.log('📡 Order items change:', payload);
          const changedItem = payload.new || payload.old;
          // If currently viewing this order's items, reload them
          if (selectedOrder && changedItem && changedItem.order_id === selectedOrder.id) {
            reloadOrderItems(selectedOrder.id);
          }
        }
      )
      .subscribe((status) => {
        console.log('📡 Order items realtime status:', status);
      });
  }

  async function silentRefreshOrders() {
    const { customerId } = getLocalCustomerSession();
    if (!customerId) return;

    try {
      const { data, error } = await supabase
        .from('orders')
        .select(`
          id,
          order_number,
          order_status,
          total_amount,
          subtotal_amount,
          delivery_fee,
          discount_amount,
          tax_amount,
          total_items,
          total_quantity,
          fulfillment_method,
          payment_method,
          customer_notes,
          created_at,
          accepted_at,
          ready_at,
          delivered_at,
          cancelled_at,
          picked_up_at,
          estimated_delivery_time,
          actual_delivery_time,
          picker_assigned_at,
          delivery_assigned_at
        `)
        .eq('customer_id', customerId)
        .not('order_status', 'in', '("delivered","cancelled","picked_up")')
        .order('created_at', { ascending: false });

      if (!error && data) {
        orders = data;
        // Update selectedOrder if still in the list
        if (selectedOrder) {
          const updated = data.find(o => o.id === selectedOrder.id);
          if (updated) {
            selectedOrder = updated;
          } else {
            // Order was delivered/cancelled/picked_up - removed from active
            selectedOrder = null;
            orderItems = [];
          }
        }
      }
    } catch (err) {
      console.error('Silent refresh error:', err);
    }
  }

  async function loadOrders() {
    loading = true;
    const { customerId } = getLocalCustomerSession();
    
    if (!customerId) {
      loading = false;
      orders = [];
      return;
    }

    try {
      // Load undelivered orders (not delivered, not cancelled)
      const { data, error } = await supabase
        .from('orders')
        .select(`
          id,
          order_number,
          order_status,
          total_amount,
          subtotal_amount,
          delivery_fee,
          discount_amount,
          tax_amount,
          total_items,
          total_quantity,
          fulfillment_method,
          payment_method,
          customer_notes,
          created_at,
          accepted_at,
          ready_at,
          delivered_at,
          cancelled_at,
          picked_up_at,
          estimated_delivery_time,
          actual_delivery_time,
          picker_assigned_at,
          delivery_assigned_at
        `)
        .eq('customer_id', customerId)
        .not('order_status', 'in', '("delivered","cancelled","picked_up")')
        .order('created_at', { ascending: false });

      if (error) {
        console.error('Error loading orders:', error);
        orders = [];
      } else {
        orders = data || [];
        // Auto-select if only one order
        if (orders.length === 1) {
          selectOrder(orders[0]);
        }
      }
    } catch (err) {
      console.error('Error fetching orders:', err);
      orders = [];
    } finally {
      loading = false;
    }
  }

  async function selectOrder(order) {
    if (selectedOrder?.id === order.id) {
      selectedOrder = null;
      orderItems = [];
      return;
    }
    selectedOrder = order;
    await reloadOrderItems(order.id);
  }

  async function reloadOrderItems(orderId) {
    loadingItems = true;
    
    try {
      const { data, error } = await supabase
        .from('order_items')
        .select('id, product_name_ar, product_name_en, quantity, unit_price, line_total, unit_name_ar, unit_name_en, unit_size, has_offer, offer_name_ar, offer_name_en, is_bogo_free, item_type')
        .eq('order_id', orderId)
        .order('created_at', { ascending: true });

      if (error) {
        console.error('Error loading items:', error);
        orderItems = [];
      } else {
        orderItems = data || [];
      }
    } catch (err) {
      console.error('Error:', err);
      orderItems = [];
    } finally {
      loadingItems = false;
    }
  }

  // Map actual DB status to the step in the flow for a given fulfillment method
  // For pickup: DB status 'delivered' maps to 'picked_up' step
  function mapStatusToStep(orderStatus, fulfillmentMethod) {
    if (fulfillmentMethod === 'pickup' && orderStatus === 'delivered') return 'picked_up';
    return orderStatus;
  }

  function getStatusStepIndex(status, flow) {
    return flow.indexOf(status);
  }

  function isStepCompleted(orderStatus, stepStatus, fulfillmentMethod) {
    if (orderStatus === 'cancelled') return false;
    const flow = getStatusFlow(fulfillmentMethod);
    const mappedStatus = mapStatusToStep(orderStatus, fulfillmentMethod);
    return getStatusStepIndex(mappedStatus, flow) >= getStatusStepIndex(stepStatus, flow);
  }

  function isStepActive(orderStatus, stepStatus, fulfillmentMethod) {
    if (orderStatus === 'cancelled') return false;
    const flow = getStatusFlow(fulfillmentMethod);
    const mappedStatus = mapStatusToStep(orderStatus, fulfillmentMethod);
    const currentIndex = getStatusStepIndex(mappedStatus, flow);
    const stepIndex = getStatusStepIndex(stepStatus, flow);
    // Active = the NEXT step after the current status (the one we're waiting for)
    return stepIndex === currentIndex + 1;
  }

  function getStepTime(order, step) {
    const timeMap = {
      new: order.created_at,
      accepted: order.accepted_at,
      in_picking: order.picker_assigned_at,
      ready: order.ready_at,
      out_for_delivery: order.delivery_assigned_at,
      delivered: order.delivered_at,
      picked_up: order.picked_up_at
    };
    return timeMap[step];
  }

  function formatTime(dateStr) {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    return d.toLocaleTimeString(currentLanguage === 'ar' ? 'ar-SA' : 'en-US', { hour: '2-digit', minute: '2-digit' });
  }

  function formatDate(dateStr) {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    return d.toLocaleDateString(currentLanguage === 'ar' ? 'ar-SA' : 'en-US', { year: 'numeric', month: 'short', day: 'numeric' });
  }

  function getProductName(item) {
    return currentLanguage === 'ar' ? item.product_name_ar : item.product_name_en;
  }

  function goToProfile() {
    goto('/customer-interface/profile');
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="track-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Header -->
  <div class="header">
    <button class="back-button" on:click={goToProfile} type="button">
      {currentLanguage === 'ar' ? '→' : '←'} {texts.backToProfile}
    </button>
    <div class="header-row">
      <h1>📍 {texts.trackOrder}</h1>
      <span class="live-badge">
        <span class="live-dot"></span>
        {texts.liveTracking}
      </span>
    </div>
  </div>

  {#if loading}
    <div class="loading-container">
      <div class="spinner"></div>
      <p>{texts.refreshing}</p>
    </div>
  {:else if orders.length === 0}
    <div class="empty-state">
      <div class="empty-icon">📦</div>
      <h2>{texts.noActiveOrders}</h2>
      <p>{texts.noActiveOrdersDesc}</p>
      <a href="/customer-interface/start" class="start-shopping-btn" data-sveltekit-preload-data="hover">
        🛒 {texts.startShopping}
      </a>
    </div>
  {:else}
    <div class="orders-list">
      {#each orders as order (order.id)}
        {@const isCancelled = order.order_status === 'cancelled'}
        <div class="order-card" class:cancelled={isCancelled} class:expanded={selectedOrder?.id === order.id}>
          <!-- Order Header -->
          <div class="order-card-header">
            <div class="order-info-top">
              <span class="order-num">{order.order_number}</span>
              <span class="order-date">{formatDate(order.created_at)}</span>
            </div>
            <div class="order-info-bottom">
              <span class="order-amount">{Number(order.total_amount).toFixed(2)} {texts.sar}</span>
              <span class="items-count">{order.total_items} {texts.items} · {order.fulfillment_method === 'delivery' ? texts.delivery : texts.pickup}</span>
            </div>
          </div>

          <!-- Status Timeline -->
          {#if !isCancelled}
            {@const flow = getStatusFlow(order.fulfillment_method)}
            <div class="timeline">
              {#each flow as step, i}
                {@const completed = isStepCompleted(order.order_status, step, order.fulfillment_method)}
                {@const active = isStepActive(order.order_status, step, order.fulfillment_method)}
                {@const stepTime = getStepTime(order, step)}
                <div class="timeline-step" class:completed class:active>
                  <div class="step-indicator">
                    <div class="step-dot">
                      {#if completed}
                        <span class="check">✓</span>
                      {:else}
                        <span class="step-icon">{STATUS_ICONS[step]}</span>
                      {/if}
                    </div>
                    {#if i < flow.length - 1}
                      <div class="step-line" class:completed={isStepCompleted(order.order_status, flow[i + 1], order.fulfillment_method)}></div>
                    {/if}
                  </div>
                  <div class="step-label">
                    <span class="step-name">{texts[step]}</span>
                    {#if stepTime}
                      <span class="step-time">{formatTime(stepTime)}</span>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          {:else}
            <div class="cancelled-banner">
              ❌ {texts.cancelled}
              {#if order.cancelled_at}
                <span class="cancel-time">{formatDate(order.cancelled_at)} {formatTime(order.cancelled_at)}</span>
              {/if}
            </div>
          {/if}

          <!-- Expand/Collapse Details -->
          <button class="details-toggle" on:click={() => selectOrder(order)} type="button">
            {selectedOrder?.id === order.id ? texts.hideDetails : texts.viewDetails}
            <span class="toggle-arrow" class:open={selectedOrder?.id === order.id}>▼</span>
          </button>

          <!-- Expanded Details -->
          {#if selectedOrder?.id === order.id}
            <div class="order-details">
              <!-- Order Info -->
              <div class="detail-section">
                <div class="detail-row">
                  <span class="detail-label">{texts.orderNumber}</span>
                  <span class="detail-value">{order.order_number}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">{texts.orderDate}</span>
                  <span class="detail-value">{formatDate(order.created_at)} {formatTime(order.created_at)}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">{texts.fulfillment}</span>
                  <span class="detail-value">{order.fulfillment_method === 'delivery' ? texts.delivery : texts.pickup}</span>
                </div>
                <div class="detail-row">
                  <span class="detail-label">{texts.paymentMethod}</span>
                  <span class="detail-value">{order.payment_method === 'cash' ? texts.cash : texts.card}</span>
                </div>
                {#if order.customer_notes}
                  <div class="detail-row">
                    <span class="detail-label">{texts.customerNotes}</span>
                    <span class="detail-value notes">{order.customer_notes}</span>
                  </div>
                {/if}
              </div>

              <!-- Items List -->
              <div class="items-section">
                <h3>{texts.items}</h3>
                {#if loadingItems}
                  <div class="items-loading">
                    <div class="spinner small"></div>
                  </div>
                {:else}
                  {#each orderItems as item}
                    <div class="item-row" class:free-item={item.is_bogo_free}>
                      <div class="item-info">
                        <span class="item-name">
                          {getProductName(item)}
                          {#if item.is_bogo_free}
                            <span class="free-badge">{currentLanguage === 'ar' ? 'مجاني' : 'FREE'}</span>
                          {/if}
                          {#if item.has_offer && !item.is_bogo_free}
                            <span class="offer-badge">🏷️</span>
                          {/if}
                        </span>
                        <span class="item-meta">
                          {texts.quantity}: {item.quantity}
                          {#if item.unit_size}
                            · {currentLanguage === 'ar' ? item.unit_name_ar : item.unit_name_en} {item.unit_size}
                          {/if}
                        </span>
                      </div>
                      <span class="item-total">{Number(item.line_total).toFixed(2)}</span>
                    </div>
                  {/each}
                {/if}
              </div>

              <!-- Totals -->
              <div class="totals-section">
                {#if Number(order.subtotal_amount) !== Number(order.total_amount)}
                  <div class="total-row">
                    <span>{currentLanguage === 'ar' ? 'المجموع الفرعي' : 'Subtotal'}</span>
                    <span>{Number(order.subtotal_amount).toFixed(2)} {texts.sar}</span>
                  </div>
                {/if}
                {#if Number(order.delivery_fee) > 0}
                  <div class="total-row">
                    <span>{currentLanguage === 'ar' ? 'رسوم التوصيل' : 'Delivery Fee'}</span>
                    <span>{Number(order.delivery_fee).toFixed(2)} {texts.sar}</span>
                  </div>
                {/if}
                {#if Number(order.discount_amount) > 0}
                  <div class="total-row discount">
                    <span>{currentLanguage === 'ar' ? 'الخصم' : 'Discount'}</span>
                    <span>-{Number(order.discount_amount).toFixed(2)} {texts.sar}</span>
                  </div>
                {/if}
                {#if Number(order.tax_amount) > 0}
                  <div class="total-row">
                    <span>{currentLanguage === 'ar' ? 'الضريبة' : 'Tax'}</span>
                    <span>{Number(order.tax_amount).toFixed(2)} {texts.sar}</span>
                  </div>
                {/if}
                <div class="total-row grand-total">
                  <span>{texts.totalAmount}</span>
                  <span>{Number(order.total_amount).toFixed(2)} {texts.sar}</span>
                </div>
              </div>
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .track-container {
    min-height: 100vh;
    background: linear-gradient(180deg, #f0fdf4 0%, #f8fafc 50%);
    padding: 1rem;
    padding-bottom: 100px;
    max-width: 600px;
    margin: 0 auto;
  }

  .header {
    margin-bottom: 1.5rem;
  }

  .back-button {
    background: none;
    border: none;
    color: #16a34a;
    font-size: 0.9rem;
    cursor: pointer;
    padding: 0.25rem 0;
    margin-bottom: 0.5rem;
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  .header-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  h1 {
    font-size: 1.35rem;
    color: #111827;
    margin: 0;
    font-weight: 700;
  }

  .live-badge {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    background: #ecfdf5;
    color: #16a34a;
    font-size: 0.7rem;
    font-weight: 600;
    padding: 0.3rem 0.6rem;
    border-radius: 12px;
    border: 1px solid #bbf7d0;
  }

  .live-dot {
    width: 6px;
    height: 6px;
    background: #16a34a;
    border-radius: 50%;
    animation: pulse 2s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.5; transform: scale(0.8); }
  }

  /* Loading & Empty */
  .loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 50vh;
    gap: 1rem;
  }

  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid #e5e7eb;
    border-top: 3px solid #16a34a;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  .spinner.small {
    width: 20px;
    height: 20px;
    border-width: 2px;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 55vh;
    text-align: center;
    padding: 2rem;
  }

  .empty-icon {
    font-size: 3.5rem;
    margin-bottom: 1rem;
    opacity: 0.5;
  }

  .empty-state h2 {
    font-size: 1.25rem;
    color: #374151;
    margin-bottom: 0.5rem;
  }

  .empty-state p {
    color: #9ca3af;
    margin-bottom: 1.5rem;
    font-size: 0.9rem;
  }

  .start-shopping-btn {
    background: #16a34a;
    color: white;
    border: none;
    padding: 0.8rem 1.5rem;
    border-radius: 10px;
    font-weight: 600;
    cursor: pointer;
    font-size: 0.95rem;
    transition: all 0.2s ease;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    position: relative;
    z-index: 10;
    -webkit-tap-highlight-color: rgba(22, 163, 74, 0.3);
  }

  .start-shopping-btn:hover {
    background: #15803d;
    transform: translateY(-1px);
  }

  /* Orders List */
  .orders-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .order-card {
    background: white;
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.06);
    border: 1px solid #e5e7eb;
    transition: all 0.3s ease;
  }

  .order-card.expanded {
    box-shadow: 0 4px 20px rgba(22, 163, 74, 0.12);
    border-color: #86efac;
  }

  .order-card.cancelled {
    opacity: 0.75;
  }

  /* Order Header */
  .order-card-header {
    padding: 1rem 1.25rem;
  }

  .order-info-top {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.35rem;
  }

  .order-num {
    font-weight: 700;
    font-size: 0.85rem;
    color: #16a34a;
    font-family: monospace;
  }

  .order-date {
    font-size: 0.75rem;
    color: #9ca3af;
  }

  .order-info-bottom {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .order-amount {
    font-weight: 700;
    font-size: 1.1rem;
    color: #111827;
  }

  .items-count {
    font-size: 0.75rem;
    color: #6b7280;
  }

  /* Timeline */
  .timeline {
    display: flex;
    align-items: flex-start;
    padding: 0.5rem 1rem 0.75rem;
    gap: 0;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }

  .timeline-step {
    display: flex;
    flex-direction: column;
    align-items: center;
    flex: 1;
    min-width: 0;
    position: relative;
  }

  .step-indicator {
    display: flex;
    align-items: center;
    width: 100%;
    position: relative;
  }

  .step-dot {
    width: 32px;
    height: 32px;
    min-width: 32px;
    border-radius: 50%;
    background: #f3f4f6;
    border: 2px solid #e5e7eb;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
    z-index: 2;
    transition: all 0.3s ease;
    font-size: 0.75rem;
  }

  .timeline-step.completed .step-dot {
    background: #16a34a;
    border-color: #16a34a;
    color: white;
  }

  .timeline-step.active .step-dot {
    background: white;
    border-color: #2563eb;
    border-width: 3px;
    box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.18);
    animation: activePulse 2s ease-in-out infinite;
  }

  @keyframes activePulse {
    0%, 100% { box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.18); }
    50% { box-shadow: 0 0 0 8px rgba(37, 99, 235, 0.08); }
  }

  .check {
    font-size: 0.65rem;
    font-weight: 700;
    color: white;
  }

  .step-icon {
    font-size: 0.8rem;
    line-height: 1;
  }

  .timeline-step.completed .step-icon {
    filter: grayscale(1) brightness(10);
  }

  .step-line {
    flex: 1;
    height: 3px;
    background: #e5e7eb;
    position: absolute;
    top: 50%;
    left: 32px;
    right: -32px;
    transform: translateY(-50%);
    z-index: 1;
    transition: background 0.3s ease;
  }

  [dir="rtl"] .step-line {
    left: auto;
    right: 32px;
    left: -32px;
  }

  .step-line.completed {
    background: #16a34a;
  }

  .step-label {
    display: flex;
    flex-direction: column;
    align-items: center;
    margin-top: 0.3rem;
    width: 100%;
  }

  .step-name {
    font-size: 0.55rem;
    font-weight: 600;
    color: #9ca3af;
    text-align: center;
    line-height: 1.2;
    white-space: nowrap;
  }

  .timeline-step.completed .step-name,
  .timeline-step.active .step-name {
    color: #16a34a;
  }

  .step-time {
    font-size: 0.5rem;
    color: #6b7280;
    margin-top: 0.1rem;
  }

  /* Cancelled */
  .cancelled-banner {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.75rem;
    background: #fef2f2;
    color: #991b1b;
    font-weight: 600;
    font-size: 0.85rem;
  }

  .cancel-time {
    font-size: 0.75rem;
    font-weight: 400;
    color: #b91c1c;
  }

  /* Details Toggle */
  .details-toggle {
    width: 100%;
    background: #f9fafb;
    border: none;
    border-top: 1px solid #f3f4f6;
    padding: 0.65rem;
    color: #6b7280;
    font-size: 0.8rem;
    font-weight: 500;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.4rem;
    transition: all 0.2s ease;
  }

  .details-toggle:hover {
    background: #f3f4f6;
    color: #374151;
  }

  .toggle-arrow {
    font-size: 0.65rem;
    transition: transform 0.3s ease;
  }

  .toggle-arrow.open {
    transform: rotate(180deg);
  }

  /* Order Details */
  .order-details {
    border-top: 1px solid #f3f4f6;
    animation: slideDown 0.3s ease;
  }

  @keyframes slideDown {
    from { opacity: 0; max-height: 0; }
    to { opacity: 1; max-height: 2000px; }
  }

  .detail-section {
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #f3f4f6;
  }

  .detail-row {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 0.4rem 0;
    font-size: 0.85rem;
  }

  .detail-label {
    color: #9ca3af;
    font-weight: 500;
  }

  .detail-value {
    color: #374151;
    font-weight: 500;
    text-align: end;
  }

  .detail-value.notes {
    font-style: italic;
    max-width: 60%;
  }

  /* Items */
  .items-section {
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #f3f4f6;
  }

  .items-section h3 {
    font-size: 0.85rem;
    color: #374151;
    margin: 0 0 0.75rem;
    font-weight: 600;
  }

  .items-loading {
    display: flex;
    justify-content: center;
    padding: 1rem;
  }

  .item-row {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 0.5rem 0;
    border-bottom: 1px dashed #f3f4f6;
  }

  .item-row:last-child {
    border-bottom: none;
  }

  .item-row.free-item {
    background: #f0fdf4;
    margin: 0 -0.5rem;
    padding: 0.5rem;
    border-radius: 6px;
  }

  .item-info {
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
    flex: 1;
    min-width: 0;
  }

  .item-name {
    font-size: 0.8rem;
    color: #374151;
    font-weight: 500;
    display: flex;
    align-items: center;
    gap: 0.3rem;
    flex-wrap: wrap;
  }

  .item-meta {
    font-size: 0.7rem;
    color: #9ca3af;
  }

  .item-total {
    font-size: 0.85rem;
    font-weight: 600;
    color: #111827;
    white-space: nowrap;
    margin-inline-start: 0.75rem;
  }

  .free-badge {
    background: #16a34a;
    color: white;
    font-size: 0.55rem;
    padding: 0.1rem 0.35rem;
    border-radius: 4px;
    font-weight: 700;
  }

  .offer-badge {
    font-size: 0.7rem;
  }

  /* Totals */
  .totals-section {
    padding: 0.75rem 1.25rem 1rem;
  }

  .total-row {
    display: flex;
    justify-content: space-between;
    padding: 0.3rem 0;
    font-size: 0.85rem;
    color: #6b7280;
  }

  .total-row.discount {
    color: #16a34a;
  }

  .total-row.grand-total {
    font-weight: 700;
    font-size: 1rem;
    color: #111827;
    border-top: 2px solid #e5e7eb;
    padding-top: 0.5rem;
    margin-top: 0.25rem;
  }

  /* Mobile adjustments */
  @media (max-width: 480px) {
    .track-container {
      padding: 0.75rem;
    }

    h1 {
      font-size: 1.15rem;
    }

    .step-dot {
      width: 26px;
      height: 26px;
      min-width: 26px;
    }

    .step-icon {
      font-size: 0.65rem;
    }

    .step-line {
      left: 26px;
      right: -26px;
    }

    [dir="rtl"] .step-line {
      right: 26px;
      left: -26px;
    }

    .step-name {
      font-size: 0.5rem;
    }
  }
</style>
