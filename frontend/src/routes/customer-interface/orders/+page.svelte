<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/utils/supabase';
  
  let currentLanguage = 'ar';
  let orders = [];
  let loading = true;

  // Get customer session
  function getLocalCustomerSession() {
    try {
      // Try customer_session first
      const customerSessionRaw = localStorage.getItem('customer_session');
      if (customerSessionRaw) {
        const customerSession = JSON.parse(customerSessionRaw);
        if (customerSession?.customer_id && customerSession?.registration_status === 'approved') {
          return { customerId: customerSession.customer_id };
        }
      }

      // Fallback to aqura-device-session
      const raw = localStorage.getItem('aqura-device-session');
      if (!raw) return { customerId: null };
      
      const session = JSON.parse(raw);
      const currentId = session?.currentUserId;
      const user = Array.isArray(session?.users)
        ? session.users.find((u) => u.id === currentId && u.isActive)
        : null;
      
      return { customerId: user?.customerId || null };
    } catch (e) {
      console.error('Error reading session:', e);
      return { customerId: null };
    }
  }

  $: texts = currentLanguage === 'ar' ? {
    title: 'سجل الطلبات - أكوا إكسبرس',
    orderHistory: 'سجل الطلبات',
    noOrders: 'لا توجد طلبات حالياً',
    startShopping: 'ابدأ التسوق',
    orderNumber: 'رقم الطلب',
    date: 'التاريخ',
    total: 'المجموع',
    status: 'الحالة',
    items: 'منتج',
    sar: 'ر.س',
    new: 'جديد',
    accepted: 'مقبول',
    in_picking: 'قيد التحضير',
    ready: 'جاهز',
    out_for_delivery: 'قيد التوصيل',
    delivered: 'تم التوصيل',
    cancelled: 'ملغي',
    viewDetails: 'عرض التفاصيل',
    backToProfile: 'العودة للملف الشخصي'
  } : {
    title: 'Order History - Aqua Express',
    orderHistory: 'Order History',
    noOrders: 'No orders yet',
    startShopping: 'Start Shopping',
    orderNumber: 'Order Number',
    date: 'Date',
    total: 'Total',
    status: 'Status',
    items: 'items',
    sar: 'SAR',
    new: 'New',
    accepted: 'Accepted',
    in_picking: 'In Picking',
    ready: 'Ready',
    out_for_delivery: 'Out for Delivery',
    delivered: 'Delivered',
    cancelled: 'Cancelled',
    viewDetails: 'View Details',
    backToProfile: 'Back to Profile'
  };

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }

    // Load real orders from database
    const { customerId } = getLocalCustomerSession();
    
    if (!customerId) {
      console.log('No customer ID found');
      loading = false;
      orders = [];
      return;
    }

    try {
      const { data, error } = await supabase
        .from('orders')
        .select(`
          id,
          order_number,
          order_status,
          total_amount,
          created_at,
          branch:branches(name_ar, name_en)
        `)
        .eq('customer_id', customerId)
        .order('created_at', { ascending: false });

      if (error) {
        console.error('Error loading orders:', error);
        orders = [];
      } else {
        // Transform data to match UI expectations
        orders = (data || []).map(order => ({
          id: order.id,
          orderNumber: order.order_number,
          status: order.order_status,
          total: order.total_amount,
          date: new Date(order.created_at).toLocaleDateString(currentLanguage === 'ar' ? 'ar-SA' : 'en-US'),
          itemCount: 0, // Would need to join order_items for accurate count
          branch: order.branch
        }));
      }
    } catch (err) {
      console.error('Error fetching orders:', err);
      orders = [];
    } finally {
      loading = false;
    }
  });

  function goToProfile() {
    goto('/customer-interface/profile');
  }

  function goToProducts() {
    console.log('Going to start page...');
    goto('/customer-interface/start');
  }

  function handleStartShopping(event) {
    event?.preventDefault();
    event?.stopPropagation();
    console.log('Start shopping clicked/touched');
    goto('/customer-interface/start');
  }

  function getStatusClass(status) {
    const statusMap = {
      'new': 'status-pending',
      'accepted': 'status-confirmed',
      'in_picking': 'status-preparing',
      'ready': 'status-ready',
      'out_for_delivery': 'status-delivery',
      'delivered': 'status-delivered',
      'cancelled': 'status-cancelled'
    };
    return statusMap[status] || 'status-pending';
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="orders-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <div class="header">
    <button class="back-button" on:click={goToProfile} type="button">
      ← {texts.backToProfile}
    </button>
    <h1>{texts.orderHistory}</h1>
  </div>

  {#if loading}
    <div class="loading-container">
      <div class="spinner"></div>
      <p>Loading...</p>
    </div>
  {:else if orders.length === 0}
    <div class="empty-state">
      <div class="empty-icon">📦</div>
      <h2>{texts.noOrders}</h2>
      <p>You haven't placed any orders yet</p>
      <button 
        class="start-shopping-btn" 
        on:click={handleStartShopping}
        on:touchend={handleStartShopping}
        type="button"
      >
        🛒 {texts.startShopping}
      </button>
    </div>
  {:else}
    <div class="orders-list">
      {#each orders as order}
        <div class="order-card">
          <div class="order-header">
            <div class="order-number">
              <strong>{texts.orderNumber}:</strong> {order.orderNumber}
            </div>
            <div class="order-status {getStatusClass(order.status)}">
              {texts[order.status] || order.status}
            </div>
          </div>
          <div class="order-details">
            <div class="detail-row">
              <span class="detail-label">{texts.date}:</span>
              <span class="detail-value">{order.date}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">{texts.items}:</span>
              <span class="detail-value">{order.itemCount} {texts.items}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">{texts.total}:</span>
              <span class="detail-value total-amount">{order.total.toFixed(2)} {texts.sar}</span>
            </div>
          </div>
          <button class="view-details-btn">
            {texts.viewDetails}
          </button>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .orders-container {
    min-height: 100vh;
    background: var(--color-surface);
    padding: 1rem;
    padding-bottom: 100px; /* Account for bottom nav */
  }

  .header {
    margin-bottom: 1.5rem;
  }

  .back-button {
    background: none;
    border: none;
    color: var(--color-primary);
    font-size: 1rem;
    cursor: pointer;
    padding: 0.5rem 0;
    margin-bottom: 0.5rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .back-button:hover {
    text-decoration: underline;
  }

  h1 {
    font-size: 1.5rem;
    color: var(--color-ink);
    margin: 0;
  }

  .loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 50vh;
    gap: 1rem;
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 4px solid var(--color-border);
    border-top: 4px solid var(--color-primary);
    border-radius: 50%;
    animation: spin 1s linear infinite;
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
    min-height: 50vh;
    text-align: center;
    padding: 2rem;
    position: relative;
    z-index: 1;
  }

  .empty-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
    opacity: 0.5;
    pointer-events: none;
  }

  .empty-state h2 {
    font-size: 1.5rem;
    color: var(--color-ink);
    margin-bottom: 0.5rem;
    pointer-events: none;
  }

  .empty-state p {
    color: var(--color-ink-light);
    margin-bottom: 1.5rem;
    pointer-events: none;
  }

  .start-shopping-btn {
    background: #16a34a;
    color: white;
    border: none;
    padding: 1rem 2rem;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    pointer-events: auto;
    position: relative;
    z-index: 10;
  }

  .start-shopping-btn:active {
    transform: scale(0.95);
  }

  .start-shopping-btn:hover {
    background: #15803d;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(22, 163, 74, 0.3);
  }

  .orders-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .order-card {
    background: white;
    border: 1px solid var(--color-border);
    border-radius: 12px;
    padding: 1.25rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  }

  .order-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid var(--color-border-light);
  }

  .order-number {
    font-size: 0.95rem;
    color: var(--color-ink);
  }

  .order-status {
    padding: 0.4rem 0.8rem;
    border-radius: 20px;
    font-size: 0.85rem;
    font-weight: 600;
  }

  .status-pending {
    background: #fef3c7;
    color: #92400e;
  }

  .status-confirmed {
    background: #dbeafe;
    color: #1e40af;
  }

  .status-preparing {
    background: #fed7aa;
    color: #9a3412;
  }

  .status-ready {
    background: #d1fae5;
    color: #065f46;
  }

  .status-delivered {
    background: #d1fae5;
    color: #065f46;
  }

  .status-cancelled {
    background: #fee2e2;
    color: #991b1b;
  }

  .order-details {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-bottom: 1rem;
  }

  .detail-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.9rem;
  }

  .detail-label {
    color: var(--color-ink-light);
  }

  .detail-value {
    color: var(--color-ink);
    font-weight: 500;
  }

  .total-amount {
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--color-primary);
  }

  .view-details-btn {
    width: 100%;
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 0.75rem;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .view-details-btn:hover {
    background: var(--color-primary-dark);
    transform: translateY(-1px);
  }

  @media (max-width: 480px) {
    .orders-container {
      padding: 0.75rem;
    }

    h1 {
      font-size: 1.25rem;
    }

    .order-card {
      padding: 1rem;
    }
  }
</style>
