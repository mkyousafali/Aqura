<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { cartStore, cartCount, cartTotal } from '$lib/stores/cart.js';
  import { supabase } from '$lib/utils/supabase';
  import { deliverySettings } from '$lib/stores/delivery.js';
  
  let currentLanguage = 'ar';
  let cartItems = [];
  let branches = [];
  let selectedBranch = null;
  let loadingBranches = false;
  
  // Use reactive declarations for store values
  $: total = $cartTotal;
  $: itemCount = $cartCount;

  // Load language from localStorage and listen for changes
  onMount(async () => {
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
    
    // Load branches
    await loadBranches();
    
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
  
  // Load branches with at least one service enabled
  async function loadBranches() {
    loadingBranches = true;
    try {
      // Use the new function to get branches with delivery settings
      const { data, error } = await supabase.rpc('get_all_branches_delivery_settings');
      
      if (error) throw error;
      
      // Filter to only show branches with at least one service enabled
      branches = (data || []).filter(b => 
        b.delivery_service_enabled || b.pickup_service_enabled
      );
      
      console.log('📦 [Finalize] Loaded branches with settings:', branches);
    } catch (error) {
      console.error('❌ [Finalize] Error loading branches:', error);
      alert('Failed to load branches');
    } finally {
      loadingBranches = false;
    }
  }

  // Language text
  $: texts = currentLanguage === 'ar' ? {
    title: 'إنهاء طلبك',
    selectBranch: 'اختر الفرع',
    selectBranchSubtitle: 'اختر الفرع الذي تريد الطلب منه',
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
    backToBranches: 'العودة للفروع',
    serviceUnavailable: 'الخدمة غير متاحة حالياً',
    minimumOrder: 'الحد الأدنى للطلب',
    pickupBenefits: ['دفع في المكان', 'لا رسوم توصيل', 'استلام فوري'],
    storeLocation: 'الموقع',
    estimatedTime: 'جاهز للاستلام خلال 15-30 دقيقة',
    deliveryOnly: 'التوصيل فقط',
    pickupOnly: 'الاستلام فقط',
    bothAvailable: 'التوصيل والاستلام',
    noBranches: 'لا توجد فروع متاحة حالياً'
  } : {
    title: 'Finalize Your Order',
    selectBranch: 'Select Branch',
    selectBranchSubtitle: 'Choose the branch you want to order from',
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
    backToBranches: 'Back to Branches',
    serviceUnavailable: 'Service currently unavailable',
    minimumOrder: 'Minimum order',
    pickupBenefits: ['Pay at location', 'No delivery fees', 'Instant pickup'],
    storeLocation: 'Location',
    estimatedTime: 'Ready for pickup in 15-30 minutes',
    deliveryOnly: 'Delivery Only',
    pickupOnly: 'Pickup Only',
    bothAvailable: 'Delivery & Pickup',
    noBranches: 'No branches available'
  };
  
  function getBranchServicesText(branch) {
    if (branch.delivery_service_enabled && branch.pickup_service_enabled) {
      return texts.bothAvailable;
    } else if (branch.delivery_service_enabled) {
      return texts.deliveryOnly;
    } else if (branch.pickup_service_enabled) {
      return texts.pickupOnly;
    }
    return '';
  }

  function getOperatingHoursText(branch, serviceType) {
    if (serviceType === 'delivery') {
      if (branch.delivery_is_24_hours) {
        return currentLanguage === 'ar' ? '⏰ 24/7 على مدار الساعة' : '⏰ 24/7 Open';
      } else if (branch.delivery_start_time && branch.delivery_end_time) {
        return `⏰ ${branch.delivery_start_time} - ${branch.delivery_end_time}`;
      }
    } else if (serviceType === 'pickup') {
      if (branch.pickup_is_24_hours) {
        return currentLanguage === 'ar' ? '⏰ 24/7 على مدار الساعة' : '⏰ 24/7 Open';
      } else if (branch.pickup_start_time && branch.pickup_end_time) {
        return `⏰ ${branch.pickup_start_time} - ${branch.pickup_end_time}`;
      }
    }
    return '';
  }

  function selectBranchForService(branch, serviceType) {
    selectedBranch = branch;
    console.log(`🔄 [Finalize] ${serviceType} selected for branch:`, branch.branch_id);
    try {
      goto(`/customer/checkout?fulfillment=${serviceType}&branch=${branch.branch_id}`);
    } catch (error) {
      console.error('❌ [Finalize] Navigation error:', error);
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

  <p class="subtitle">{texts.selectBranchSubtitle}</p>
    
    <!-- Order Summary -->
    <div class="order-summary-card">
      <div class="order-summary">
        <h3>{texts.orderSummary}</h3>
        <div class="summary-details">
          <div class="summary-row">
            <span>{itemCount} {texts.items}</span>
            <span>{total.toFixed(2)} {texts.sar}</span>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Branch List -->
    <div class="branches-section">
      <h2>{texts.selectBranch}</h2>
      
      {#if loadingBranches}
        <div class="loading">
          <div class="spinner"></div>
          <p>Loading branches...</p>
        </div>
      {:else if branches.length === 0}
        <div class="empty-state">
          <p>{texts.noBranches}</p>
        </div>
      {:else}
        <div class="branches-list">
          {#each branches as branch}
            <div class="branch-item {selectedBranch?.branch_id === branch.branch_id ? 'expanded' : ''}">
              <!-- Branch Header (Always Visible) -->
              <button 
                class="branch-header" 
                on:click={() => selectedBranch?.branch_id === branch.branch_id ? selectedBranch = null : selectedBranch = branch}
                type="button"
              >
                <div class="branch-header-content">
                  <div class="branch-icon">🏢</div>
                  <div class="branch-info">
                    <h3>{currentLanguage === 'ar' ? branch.branch_name_ar : branch.branch_name_en}</h3>
                    <div class="branch-services-inline">
                      {#if branch.delivery_service_enabled}
                        <span class="service-badge-sm delivery">🚚 {currentLanguage === 'ar' ? 'توصيل' : 'Delivery'}</span>
                      {/if}
                      {#if branch.pickup_service_enabled}
                        <span class="service-badge-sm pickup">🏪 {currentLanguage === 'ar' ? 'استلام' : 'Pickup'}</span>
                      {/if}
                    </div>
                  </div>
                  <div class="expand-icon">{selectedBranch?.branch_id === branch.branch_id ? '▲' : '▼'}</div>
                </div>
              </button>
              
              <!-- Expanded Services (Show when selected) -->
              {#if selectedBranch?.branch_id === branch.branch_id}
                <div class="services-detail">
                  <!-- Delivery Service Card -->
                  {#if branch.delivery_service_enabled}
                    <button class="service-card delivery-card" on:click={() => selectBranchForService(branch, 'delivery')} type="button">
                      <div class="service-card-icon">🚚</div>
                      <div class="service-card-content">
                        <h4>{currentLanguage === 'ar' ? 'خدمة التوصيل' : 'Delivery Service'}</h4>
                        <p class="service-timing">{getOperatingHoursText(branch, 'delivery')}</p>
                        <p class="service-description">{currentLanguage === 'ar' ? 'سنوصل طلبك إلى موقعك' : 'We deliver to your location'}</p>
                      </div>
                      <div class="service-arrow">→</div>
                    </button>
                  {/if}
                  
                  <!-- Pickup Service Card -->
                  {#if branch.pickup_service_enabled}
                    <button class="service-card pickup-card" on:click={() => selectBranchForService(branch, 'pickup')} type="button">
                      <div class="service-card-icon">🏪</div>
                      <div class="service-card-content">
                        <h4>{currentLanguage === 'ar' ? 'الاستلام من المتجر' : 'Store Pickup'}</h4>
                        <p class="service-timing">{getOperatingHoursText(branch, 'pickup')}</p>
                        <p class="service-description">{currentLanguage === 'ar' ? 'استلم طلبك من الفرع' : 'Pickup from the branch'}</p>
                      </div>
                      <div class="service-arrow">→</div>
                    </button>
                  {/if}
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
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

  /* Branch Selection Styles */
  .branches-section {
    margin: 2rem 0;
  }

  .branches-section h2 {
    margin: 0 0 1.5rem 0;
    color: var(--color-ink);
    font-size: 1.3rem;
  }

  .branches-grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  .branch-card {
    background: white;
    border: 2px solid var(--color-border);
    border-radius: 16px;
    padding: 1.5rem;
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: center;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
    width: 100%;
  }

  .branch-card:hover {
    border-color: var(--color-primary);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .branch-icon {
    font-size: 2.5rem;
    margin-bottom: 0.75rem;
  }

  .branch-card h3 {
    margin: 0 0 0.5rem 0;
    color: var(--color-ink);
    font-size: 1.1rem;
    font-weight: 600;
  }

  .branch-services {
    margin: 0 0 0.5rem 0;
    color: var(--color-ink-light);
    font-size: 0.9rem;
  }

  .branch-hours {
    margin: 0 0 1rem 0;
    color: #059669;
    font-size: 0.85rem;
    font-weight: 500;
  }

  .branch-badges {
    display: flex;
    justify-content: center;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .service-badge {
    padding: 0.4rem 0.8rem;
    border-radius: 8px;
    font-size: 0.85rem;
    font-weight: 500;
  }

  .service-badge.delivery {
    background: #dbeafe;
    color: #1e40af;
  }

  .service-badge.pickup {
    background: #d1fae5;
    color: #065f46;
  }

  .selected-branch-info {
    background: var(--color-surface);
    padding: 1rem;
    border-radius: 12px;
    margin-bottom: 1.5rem;
    text-align: center;
    border: 2px solid var(--color-primary);
  }

  .selected-branch-info h3 {
    margin: 0;
    color: var(--color-primary);
    font-size: 1.1rem;
  }

  .loading {
    text-align: center;
    padding: 3rem;
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 4px solid var(--color-border);
    border-top: 4px solid var(--color-primary);
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin: 0 auto 1rem;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .empty-state {
    text-align: center;
    padding: 3rem;
    color: var(--color-ink-light);
  }

  .no-services-message {
    text-align: center;
    padding: 2rem;
    background: #fef2f2;
    border: 1px solid #ef4444;
    border-radius: 12px;
    color: #7f1d1d;
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
    
    .branches-grid {
      gap: 0.75rem;
    }
    
    .branch-card {
      padding: 1.25rem;
    }
  }

  /* New Expandable Branch List Styles */
  .branches-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .branch-item {
    background: white;
    border: 2px solid var(--color-border);
    border-radius: 16px;
    overflow: hidden;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  }

  .branch-item.expanded {
    border-color: var(--color-primary);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .branch-header {
    width: 100%;
    padding: 1.25rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: none;
    border: none;
    cursor: pointer;
    transition: background 0.2s ease;
    text-align: left;
    gap: 1rem;
  }

  .branch-header:hover {
    background: var(--color-surface);
  }

  .branch-header:active {
    transform: scale(0.99);
  }

  .branch-header-content {
    display: flex;
    align-items: center;
    gap: 1rem;
    flex: 1;
  }

  .branch-icon-large {
    font-size: 2.5rem;
    flex-shrink: 0;
  }

  .branch-info {
    flex: 1;
    min-width: 0;
  }

  .branch-info h3 {
    margin: 0 0 0.5rem 0;
    color: var(--color-ink);
    font-size: 1.15rem;
    font-weight: 600;
  }

  .branch-services-inline {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .service-badge-sm {
    padding: 0.25rem 0.6rem;
    border-radius: 6px;
    font-size: 0.75rem;
    font-weight: 500;
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
  }

  .service-badge-sm.delivery {
    background: #dbeafe;
    color: #1e40af;
  }

  .service-badge-sm.pickup {
    background: #d1fae5;
    color: #065f46;
  }

  .expand-icon {
    color: var(--color-ink-light);
    font-size: 1.25rem;
    transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    flex-shrink: 0;
  }

  .branch-item.expanded .expand-icon {
    transform: rotate(180deg);
  }

  .services-detail {
    padding: 0 1.25rem 1.25rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
    animation: slideDown 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }

  @keyframes slideDown {
    from {
      opacity: 0;
      transform: translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .service-card {
    width: 100%;
    background: linear-gradient(135deg, var(--color-surface) 0%, white 100%);
    border: 2px solid var(--color-border-light);
    border-radius: 12px;
    padding: 1.25rem;
    display: flex;
    align-items: center;
    gap: 1rem;
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: left;
    position: relative;
    overflow: hidden;
  }

  .service-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(135deg, var(--color-primary) 0%, var(--color-primary-dark) 100%);
    opacity: 0;
    transition: opacity 0.2s ease;
    z-index: 0;
  }

  .service-card:hover::before {
    opacity: 0.05;
  }

  .service-card:active {
    transform: scale(0.98);
    border-color: var(--color-primary);
  }

  .service-card:hover {
    border-color: var(--color-primary);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    transform: translateY(-2px);
  }

  .service-card-icon {
    font-size: 2.5rem;
    flex-shrink: 0;
    position: relative;
    z-index: 1;
  }

  .service-card-content {
    flex: 1;
    position: relative;
    z-index: 1;
  }

  .service-card-content h4 {
    margin: 0 0 0.5rem 0;
    color: var(--color-ink);
    font-size: 1.1rem;
    font-weight: 600;
  }

  .service-timing {
    margin: 0;
    color: var(--color-ink-light);
    font-size: 0.9rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .service-timing::before {
    content: '';
    font-size: 1rem;
  }

  .service-arrow {
    color: var(--color-ink-light);
    font-size: 1.5rem;
    flex-shrink: 0;
    transition: transform 0.2s ease;
    position: relative;
    z-index: 1;
  }

  .service-card:hover .service-arrow {
    transform: translateX(4px);
    color: var(--color-primary);
  }

  .service-card.delivery-service {
    border-left: 4px solid #3b82f6;
  }

  .service-card.pickup-service {
    border-left: 4px solid #10b981;
  }

  @media (max-width: 480px) {
    .branch-header {
      padding: 1rem;
    }
    .branch-header-content {
      gap: 0.75rem;
    }
    .branch-icon-large {
      font-size: 2rem;
    }
    .branch-info h3 {
      font-size: 1rem;
    }
    .services-detail {
      padding: 0 1rem 1rem 1rem;
    }
    .service-card {
      padding: 1rem;
    }
    .service-card-icon {
      font-size: 2rem;
    }
    .service-card-content h4 {
      font-size: 1rem;
    }
    .service-timing {
      font-size: 0.85rem;
    }
  }
</style>


