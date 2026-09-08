<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  
  let currentLanguage = 'ar';

  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }
  });

  $: texts = currentLanguage === 'ar' ? {
    title: 'الاستلام من المتجر - أكوا إكسبرس',
    subtitle: 'سيكون طلبك جاهز خلال 15-30 دقيقة',
    storeInfo: 'معلومات المتجر',
    address: 'الرياض، المملكة العربية السعودية',
    phone: 'هاتف: +966 XX XXX XXXX',
    hours: 'ساعات العمل: 8:00 ص - 11:00 م',
    instructions: 'تعليمات الاستلام',
    instruction1: '• سيتم إشعارك عند جاهزية طلبك',
    instruction2: '• أحضر هويتك عند الاستلام',
    instruction3: '• الدفع نقداً أو بالبطاقة',
    orderSummary: 'ملخص الطلب',
    completeOrder: 'تأكيد الطلب',
    backToFinalize: 'العودة للخيارات'
  } : {
    title: 'Pick Up From Store - Aqua Express',
    subtitle: 'Your order will be ready in 15-30 minutes',
    storeInfo: 'Store Information',
    address: 'Riyadh, Saudi Arabia',
    phone: 'Phone: +966 XX XXX XXXX',
    hours: 'Hours: 8:00 AM - 11:00 PM',
    instructions: 'Pickup Instructions',
    instruction1: '• You will be notified when your order is ready',
    instruction2: '• Bring your ID for pickup',
    instruction3: '• Payment accepted in cash or card',
    orderSummary: 'Order Summary',
    completeOrder: 'Complete Order',
    backToFinalize: 'Back to Options'
  };

  function completeOrder() {
    // Here you would normally process the pickup order
    // For now, we'll just show a success message and redirect
    alert(currentLanguage === 'ar' ? 'تم تأكيد طلبك! ستتلقى إشعار عند جاهزية الطلب.' : 'Order confirmed! You will receive a notification when your order is ready.');
    goto('/customer-interface/products');
  }

  function goBack() {
    goto('/customer-interface/cart');
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="pickup-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Header -->
  <header class="page-header">
    <button class="back-button" on:click={goBack}>
      ← {texts.backToFinalize}
    </button>
    <h1>{texts.title.split(' - ')[0]}</h1>
    <div></div> <!-- Spacer for flexbox -->
  </header>

  <p class="subtitle">{texts.subtitle}</p>

  <!-- Store Information -->
  <div class="info-card">
    <h2>{texts.storeInfo}</h2>
    <div class="store-details">
      <div class="detail-item">
        <span class="icon">📍</span>
        <span>{texts.address}</span>
      </div>
      <div class="detail-item">
        <span class="icon">📞</span>
        <span>{texts.phone}</span>
      </div>
      <div class="detail-item">
        <span class="icon">🕐</span>
        <span>{texts.hours}</span>
      </div>
    </div>
  </div>

  <!-- Pickup Instructions -->
  <div class="info-card">
    <h2>{texts.instructions}</h2>
    <div class="instructions-list">
      <p>{texts.instruction1}</p>
      <p>{texts.instruction2}</p>
      <p>{texts.instruction3}</p>
    </div>
  </div>

  <!-- Action Buttons -->
  <div class="action-buttons">
    <button class="complete-button" on:click={completeOrder}>
      {texts.completeOrder}
    </button>
  </div>
</div>

<style>
  .pickup-container {
    min-height: 100vh;
    background: var(--color-background);
    padding: 1rem;
    padding-bottom: 120px; /* Space for bottom nav */
    max-width: 600px;
    margin: 0 auto;
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
  }

  .back-button:hover {
    background: var(--color-primary);
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
    font-weight: 500;
    background: #e6f3ff;
    padding: 1rem;
    border-radius: 12px;
    border: 1px solid #b3d9ff;
  }

  .info-card {
    background: white;
    border-radius: 16px;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid var(--color-border-light);
  }

  .info-card h2 {
    margin: 0 0 1rem 0;
    color: var(--color-ink);
    font-size: 1.2rem;
    font-weight: 600;
  }

  .store-details {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .detail-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.5rem 0;
  }

  .detail-item .icon {
    font-size: 1.2rem;
    width: 24px;
    text-align: center;
  }

  .instructions-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .instructions-list p {
    margin: 0;
    color: var(--color-ink-light);
    line-height: 1.5;
    padding: 0.5rem 0;
  }

  .action-buttons {
    display: flex;
    gap: 1rem;
    margin-top: 2rem;
  }

  .complete-button {
    flex: 1;
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 1rem 1.5rem;
    border-radius: 12px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .complete-button:hover {
    background: var(--color-primary-dark);
    transform: translateY(-1px);
  }

  /* Mobile optimizations */
  @media (max-width: 480px) {
    .pickup-container {
      padding: 0.75rem;
    }

    .action-buttons {
      flex-direction: column;
    }
  }
</style>
