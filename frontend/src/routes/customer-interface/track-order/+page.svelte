<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/utils/supabase';
  
  let currentLanguage = 'ar';
  let orderNumber = '';
  let trackingResult = null;
  let loading = false;
  let error = '';

  $: texts = currentLanguage === 'ar' ? {
    title: 'تتبع الطلب - أكوا إكسبرس',
    trackOrder: 'تتبع الطلب',
    enterOrderNumber: 'أدخل رقم الطلب',
    orderNumberPlaceholder: 'مثال: ORD-20251120-0001',
    trackButton: 'تتبع',
    backToProfile: 'العودة للملف الشخصي',
    orderNotFound: 'لم يتم العثور على الطلب',
    orderStatus: 'حالة الطلب',
    orderDetails: 'تفاصيل الطلب',
    orderDate: 'تاريخ الطلب',
    totalAmount: 'المبلغ الإجمالي',
    items: 'المنتجات',
    sar: 'ر.س',
    new: 'جديد',
    accepted: 'مقبول',
    in_picking: 'قيد التحضير',
    ready: 'جاهز',
    out_for_delivery: 'قيد التوصيل',
    delivered: 'تم التوصيل',
    cancelled: 'ملغي'
  } : {
    title: 'Track Order - Aqua Express',
    trackOrder: 'Track Order',
    enterOrderNumber: 'Enter Order Number',
    orderNumberPlaceholder: 'e.g., ORD-20251120-0001',
    trackButton: 'Track',
    backToProfile: 'Back to Profile',
    orderNotFound: 'Order not found',
    orderStatus: 'Order Status',
    orderDetails: 'Order Details',
    orderDate: 'Order Date',
    totalAmount: 'Total Amount',
    items: 'Items',
    sar: 'SAR',
    new: 'New',
    accepted: 'Accepted',
    in_picking: 'In Picking',
    ready: 'Ready',
    out_for_delivery: 'Out for Delivery',
    delivered: 'Delivered',
    cancelled: 'Cancelled'
  };

  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }
  });

  function goToProfile() {
    goto('/customer-interface/profile');
  }

  async function trackOrderSubmit() {
    if (!orderNumber.trim()) {
      error = currentLanguage === 'ar' ? 'يرجى إدخال رقم الطلب' : 'Please enter order number';
      return;
    }

    loading = true;
    error = '';
    trackingResult = null;

    try {
      // Query orders table by order_number
      const { data, error: queryError } = await supabase
        .from('orders')
        .select(`
          id,
          order_number,
          order_status,
          total_amount,
          created_at,
          branch:branches(name_ar, name_en),
          customer:customers(name)
        `)
        .eq('order_number', orderNumber.trim())
        .single();

      if (queryError || !data) {
        error = texts.orderNotFound;
        trackingResult = null;
      } else {
        // Transform data to match UI
        trackingResult = {
          orderNumber: data.order_number,
          status: data.order_status,
          date: new Date(data.created_at).toLocaleDateString(currentLanguage === 'ar' ? 'ar-SA' : 'en-US'),
          total: data.total_amount,
          customer: data.customer?.name || '',
          branch: currentLanguage === 'ar' ? data.branch?.name_ar : data.branch?.name_en
        };
      }
    } catch (err) {
      console.error('Error tracking order:', err);
      error = currentLanguage === 'ar' ? 'حدث خطأ أثناء البحث' : 'An error occurred';
      trackingResult = null;
    } finally {
      loading = false;
    }
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

<div class="track-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <div class="header">
    <button class="back-button" on:click={goToProfile} type="button">
      ← {texts.backToProfile}
    </button>
    <h1>{texts.trackOrder}</h1>
  </div>

  <div class="track-form">
    <div class="form-group">
      <label for="orderNumber">{texts.enterOrderNumber}</label>
      <input
        id="orderNumber"
        type="text"
        bind:value={orderNumber}
        placeholder={texts.orderNumberPlaceholder}
        class="order-input"
      />
    </div>

    <button 
      class="track-btn" 
      on:click={trackOrderSubmit}
      disabled={loading}
      type="button"
    >
      {loading ? '...' : `🔍 ${texts.trackButton}`}
    </button>

    {#if error}
      <div class="error-message">
        ❌ {error}
      </div>
    {/if}
  </div>

  {#if trackingResult}
    <div class="tracking-result">
      <div class="status-badge {getStatusClass(trackingResult.status)}">
        {texts[trackingResult.status]}
      </div>
      
      <div class="result-section">
        <h3>{texts.orderDetails}</h3>
        <div class="detail-row">
          <span>{texts.orderDate}:</span>
          <span>{trackingResult.date}</span>
        </div>
        <div class="detail-row">
          <span>{texts.totalAmount}:</span>
          <span>{trackingResult.total} {texts.sar}</span>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .track-container {
    min-height: 100vh;
    background: var(--color-surface);
    padding: 1rem;
    padding-bottom: 100px;
  }

  .header {
    margin-bottom: 2rem;
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

  .track-form {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
    margin-bottom: 2rem;
  }

  .form-group {
    margin-bottom: 1.5rem;
  }

  label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 600;
    color: var(--color-ink);
  }

  .order-input {
    width: 100%;
    padding: 0.875rem;
    border: 2px solid var(--color-border);
    border-radius: 8px;
    font-size: 1rem;
    transition: border-color 0.2s ease;
  }

  .order-input:focus {
    outline: none;
    border-color: var(--color-primary);
  }

  .track-btn {
    width: 100%;
    background: #16a34a;
    color: white;
    border: none;
    padding: 1rem;
    border-radius: 8px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 1rem;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }

  .track-btn:hover:not(:disabled) {
    background: #15803d;
    transform: translateY(-1px);
  }

  .track-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .error-message {
    margin-top: 1rem;
    padding: 1rem;
    background: #fee2e2;
    border: 1px solid #ef4444;
    border-radius: 8px;
    color: #991b1b;
    text-align: center;
  }

  .tracking-result {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  }

  .status-badge {
    padding: 0.75rem 1.25rem;
    border-radius: 25px;
    font-weight: 700;
    text-align: center;
    margin-bottom: 1.5rem;
    font-size: 1.1rem;
  }

  .status-pending { background: #fef3c7; color: #92400e; }
  .status-confirmed { background: #dbeafe; color: #1e40af; }
  .status-preparing { background: #fed7aa; color: #9a3412; }
  .status-ready { background: #d1fae5; color: #065f46; }
  .status-delivery { background: #e0e7ff; color: #3730a3; }
  .status-delivered { background: #d1fae5; color: #065f46; }
  .status-cancelled { background: #fee2e2; color: #991b1b; }

  .result-section {
    margin-top: 1.5rem;
  }

  .result-section h3 {
    margin-bottom: 1rem;
    color: var(--color-ink);
  }

  .detail-row {
    display: flex;
    justify-content: space-between;
    padding: 0.75rem 0;
    border-bottom: 1px solid var(--color-border-light);
  }

  .detail-row:last-child {
    border-bottom: none;
  }

  @media (max-width: 480px) {
    .track-container {
      padding: 0.75rem;
    }

    h1 {
      font-size: 1.25rem;
    }
  }
</style>
