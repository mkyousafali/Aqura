<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/utils/supabase';
  import { loadStoreOpeningHours, storeOpeningHoursSummary } from '$lib/utils/storeOpeningHours';
  
  let currentLanguage = 'ar';
  let adminWhatsAppNumber = '+966548357066'; // Aqura admin WhatsApp
  let supportEmail = 'support@aquaexpress.sa';
  let storeBranches = [];
  $: currentStoreHours = storeOpeningHoursSummary(storeBranches, currentLanguage);
  onMount(() => {
    loadStoreOpeningHours(supabase).then(rows => { storeBranches = rows; })
      .catch(error => console.error('Failed to load store hours:', error));
  });

  // Load language from localStorage
  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
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

  $: texts = currentLanguage === 'ar' ? {
    title: 'الدعم والمساعدة - أكوا إكسبرس',
    subtitle: 'نحن هنا لمساعدتك',
    whatsappSupport: 'دعم الواتساب',
    whatsappDesc: 'تواصل معنا مباشرة عبر الواتساب للحصول على مساعدة فورية',
    emailSupport: 'الدعم عبر الإيميل',
    emailDesc: 'أرسل لنا رسالة وسنرد عليك في أقرب وقت ممكن',
    faq: 'الأسئلة الشائعة',
    faqDesc: 'ابحث عن إجابات لأكثر الأسئلة شيوعاً',
    orderHelp: 'مساعدة في الطلبات',
    orderHelpDesc: 'مشاكل في الطلب، التتبع، أو التسليم',
    accountHelp: 'مساعدة الحساب',
    accountHelpDesc: 'مشاكل في تسجيل الدخول أو إدارة الحساب',
    productHelp: 'استفسارات المنتجات',
    productHelpDesc: 'أسئلة حول المنتجات والأسعار',
    technicalHelp: 'الدعم التقني',
    technicalHelpDesc: 'مشاكل في التطبيق أو الموقع',
    contactUs: 'اتصل بنا',
    openWhatsApp: 'فتح الواتساب',
    sendEmail: 'إرسال إيميل',
    backToHome: 'العودة للرئيسية',
    businessHours: 'ساعات العمل',
    businessHoursDesc: [currentStoreHours, 'الدعم البشري: 12:00 م - 8:00 م', 'جميع الأوقات بتوقيت السعودية.'].filter(Boolean).join('\n'),
    quickActions: 'إجراءات سريعة',
    reportProblem: 'إبلاغ عن مشكلة',
    requestRefund: 'طلب استرداد',
    trackOrder: 'تتبع الطلب',
    changeAddress: 'تغيير العنوان'
  } : {
    title: 'Support & Help - Aqua Express',
    subtitle: 'We\'re here to help you',
    whatsappSupport: 'WhatsApp Support',
    whatsappDesc: 'Contact us directly via WhatsApp for instant help',
    emailSupport: 'Email Support',
    emailDesc: 'Send us a message and we\'ll get back to you soon',
    faq: 'Frequently Asked Questions',
    faqDesc: 'Find answers to the most common questions',
    orderHelp: 'Order Help',
    orderHelpDesc: 'Issues with orders, tracking, or delivery',
    accountHelp: 'Account Help',
    accountHelpDesc: 'Login issues or account management',
    productHelp: 'Product Inquiries',
    productHelpDesc: 'Questions about products and pricing',
    technicalHelp: 'Technical Support',
    technicalHelpDesc: 'App or website issues',
    contactUs: 'Contact Us',
    openWhatsApp: 'Open WhatsApp',
    sendEmail: 'Send Email',
    backToHome: 'Back to Home',
    businessHours: 'Business Hours',
    businessHoursDesc: [currentStoreHours, 'Human support: 12:00 PM - 8:00 PM', 'All times are Saudi time.'].filter(Boolean).join('\n'),
    quickActions: 'Quick Actions',
    reportProblem: 'Report a Problem',
    requestRefund: 'Request Refund',
    trackOrder: 'Track Order',
    changeAddress: 'Change Address'
  };

  function openWhatsAppSupport(topic = '') {
    let message = currentLanguage === 'ar' 
      ? 'مرحباً، أحتاج إلى مساعدة في أكوا إكسبرس'
      : 'Hello, I need help with Aqua Express';
    
    if (topic) {
      message += (currentLanguage === 'ar' ? ' - ' : ' - ') + topic;
    }
    
    const encodedMessage = encodeURIComponent(message);
    const whatsappUrl = `https://wa.me/${adminWhatsAppNumber.replace(/[^0-9]/g, '')}?text=${encodedMessage}`;
    
    window.open(whatsappUrl, '_blank');
  }

  function openEmail(topic = '') {
    const subject = currentLanguage === 'ar' 
      ? 'طلب مساعدة - أكوا إكسبرس'
      : 'Help Request - Aqua Express';
    
    let body = currentLanguage === 'ar' 
      ? 'مرحباً،\n\nأحتاج إلى مساعدة في:\n\n'
      : 'Hello,\n\nI need help with:\n\n';
    
    if (topic) {
      body += topic + '\n\n';
    }

    body += currentLanguage === 'ar' 
      ? 'التفاصيل:\n\n\nشكراً لكم'
      : 'Details:\n\n\nThank you';

    const mailtoUrl = `mailto:${supportEmail}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    window.location.href = mailtoUrl;
  }

  function goToProducts() {
    goto('/customer-interface/products');
  }

  function goToCart() {
    goto('/customer-interface/cart');
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="support-container">
  <header class="page-header">
    <button class="back-btn" on:click={goToProducts}>
      ← {texts.backToHome}
    </button>
    <h1>{texts.title}</h1>
    <p class="subtitle">{texts.subtitle}</p>
  </header>

  <!-- Quick Contact Options -->
  <div class="contact-options">
    <div class="contact-card whatsapp-card">
      <div class="contact-icon">📱</div>
      <div class="contact-info">
        <h3>{texts.whatsappSupport}</h3>
        <p>{texts.whatsappDesc}</p>
      </div>
      <button class="contact-btn whatsapp-btn" on:click={() => openWhatsAppSupport()}>
        {texts.openWhatsApp}
      </button>
    </div>

    <div class="contact-card email-card">
      <div class="contact-icon">📧</div>
      <div class="contact-info">
        <h3>{texts.emailSupport}</h3>
        <p>{texts.emailDesc}</p>
      </div>
      <button class="contact-btn email-btn" on:click={() => openEmail()}>
        {texts.sendEmail}
      </button>
    </div>
  </div>

  <!-- Support Categories -->
  <div class="support-categories">
    <h2>{texts.quickActions}</h2>
    
    <div class="category-grid">
      <button class="category-card" on:click={() => openWhatsAppSupport(texts.orderHelp)}>
        <div class="category-icon">📦</div>
        <h4>{texts.orderHelp}</h4>
        <p>{texts.orderHelpDesc}</p>
      </button>

      <button class="category-card" on:click={() => openWhatsAppSupport(texts.accountHelp)}>
        <div class="category-icon">👤</div>
        <h4>{texts.accountHelp}</h4>
        <p>{texts.accountHelpDesc}</p>
      </button>

      <button class="category-card" on:click={() => openWhatsAppSupport(texts.productHelp)}>
        <div class="category-icon">🛍️</div>
        <h4>{texts.productHelp}</h4>
        <p>{texts.productHelpDesc}</p>
      </button>

      <button class="category-card" on:click={() => openWhatsAppSupport(texts.technicalHelp)}>
        <div class="category-icon">⚙️</div>
        <h4>{texts.technicalHelp}</h4>
        <p>{texts.technicalHelpDesc}</p>
      </button>
    </div>
  </div>

  <!-- Quick Actions -->
  <div class="quick-actions">
    <div class="action-grid">
      <button class="action-btn" on:click={() => openWhatsAppSupport(texts.reportProblem)}>
        <span class="action-icon">⚠️</span>
        {texts.reportProblem}
      </button>

      <button class="action-btn" on:click={() => openWhatsAppSupport(texts.requestRefund)}>
        <span class="action-icon">💳</span>
        {texts.requestRefund}
      </button>

      <button class="action-btn" on:click={goToCart}>
        <span class="action-icon">📍</span>
        {texts.trackOrder}
      </button>

      <button class="action-btn" on:click={() => openWhatsAppSupport(texts.changeAddress)}>
        <span class="action-icon">🏠</span>
        {texts.changeAddress}
      </button>
    </div>
  </div>

  <!-- Business Hours -->
  <div class="business-hours">
    <h3>{texts.businessHours}</h3>
    <p class="hours-text">{texts.businessHoursDesc}</p>
  </div>

  <!-- Contact Information -->
  <div class="contact-info-card">
    <h3>{texts.contactUs}</h3>
    <div class="contact-details">
      <div class="contact-item">
        <span class="contact-label">📱 واتساب:</span>
        <a href="https://wa.me/{adminWhatsAppNumber.replace(/[^0-9]/g, '')}" 
           target="_blank"
           rel="noopener noreferrer">
          {adminWhatsAppNumber}
        </a>
      </div>
      <div class="contact-item">
        <span class="contact-label">📧 الإيميل:</span>
        <a href="mailto:{supportEmail}">{supportEmail}</a>
      </div>
    </div>
  </div>
</div>

<style>
  .support-container {
    padding: 1rem;
    min-height: 100vh;
    background: var(--color-background);
    max-width: 600px;
    margin: 0 auto;
    padding-bottom: 120px; /* Space for bottom nav */
  }

  .page-header {
    text-align: center;
    margin-bottom: 2rem;
  }

  .back-btn {
    background: none;
    border: 1px solid var(--color-border);
    color: var(--color-primary);
    padding: 0.5rem 1rem;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.9rem;
    margin-bottom: 1rem;
    transition: all 0.2s ease;
  }

  .back-btn:hover {
    background: var(--color-primary);
    color: white;
  }

  .page-header h1 {
    margin: 0 0 0.5rem 0;
    color: var(--color-ink);
    font-size: 1.5rem;
  }

  .subtitle {
    margin: 0;
    color: var(--color-ink-light);
    font-size: 1rem;
  }

  .contact-options {
    margin-bottom: 2rem;
  }

  .contact-card {
    display: flex;
    align-items: center;
    gap: 1rem;
    background: white;
    padding: 1.5rem;
    border-radius: 16px;
    margin-bottom: 1rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid var(--color-border-light);
  }

  .contact-icon {
    font-size: 2.5rem;
    flex-shrink: 0;
  }

  .contact-info {
    flex: 1;
  }

  .contact-info h3 {
    margin: 0 0 0.5rem 0;
    color: var(--color-ink);
    font-size: 1.1rem;
  }

  .contact-info p {
    margin: 0;
    color: var(--color-ink-light);
    font-size: 0.9rem;
    line-height: 1.4;
  }

  .contact-btn {
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    border: none;
    cursor: pointer;
    font-weight: 500;
    font-size: 0.9rem;
    transition: all 0.2s ease;
    flex-shrink: 0;
  }

  .whatsapp-btn {
    background: #25d366;
    color: white;
  }

  .whatsapp-btn:hover {
    background: #1da851;
  }

  .email-btn {
    background: var(--color-primary);
    color: white;
  }

  .email-btn:hover {
    background: var(--color-primary-dark);
  }

  .support-categories {
    margin-bottom: 2rem;
  }

  .support-categories h2 {
    margin: 0 0 1.5rem 0;
    color: var(--color-ink);
    font-size: 1.2rem;
  }

  .category-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }

  .category-card {
    background: white;
    padding: 1.5rem;
    border-radius: 16px;
    border: 1px solid var(--color-border-light);
    cursor: pointer;
    transition: all 0.2s ease;
    text-align: center;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .category-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }

  .category-icon {
    font-size: 2rem;
    margin-bottom: 0.75rem;
  }

  .category-card h4 {
    margin: 0 0 0.5rem 0;
    color: var(--color-ink);
    font-size: 0.95rem;
  }

  .category-card p {
    margin: 0;
    color: var(--color-ink-light);
    font-size: 0.8rem;
    line-height: 1.3;
  }

  .quick-actions {
    margin-bottom: 2rem;
  }

  .action-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }

  .action-btn {
    background: white;
    border: 1px solid var(--color-border-light);
    padding: 1rem;
    border-radius: 12px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--color-ink);
    transition: all 0.2s ease;
  }

  .action-btn:hover {
    background: var(--color-primary);
    color: white;
    transform: translateY(-1px);
  }

  .action-icon {
    font-size: 1.1rem;
  }

  .business-hours {
    background: white;
    padding: 1.5rem;
    border-radius: 16px;
    margin-bottom: 1rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid var(--color-border-light);
    text-align: center;
  }

  .business-hours h3 {
    margin: 0 0 1rem 0;
    color: var(--color-ink);
    font-size: 1.1rem;
  }

  .hours-text {
    margin: 0;
    color: var(--color-ink-light);
    font-size: 0.9rem;
    line-height: 1.5;
    white-space: pre-line;
  }

  .contact-info-card {
    background: white;
    padding: 1.5rem;
    border-radius: 16px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid var(--color-border-light);
  }

  .contact-info-card h3 {
    margin: 0 0 1rem 0;
    color: var(--color-ink);
    font-size: 1.1rem;
  }

  .contact-details {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .contact-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .contact-label {
    color: var(--color-ink-light);
    font-weight: 500;
    font-size: 0.9rem;
  }

  .contact-item a {
    color: var(--color-primary);
    text-decoration: none;
    font-weight: 500;
  }

  .contact-item a:hover {
    text-decoration: underline;
  }

  /* Responsive adjustments */
  @media (max-width: 480px) {
    .support-container {
      padding: 0.75rem;
    }

    .category-grid {
      grid-template-columns: 1fr;
    }

    .contact-card {
      flex-direction: column;
      text-align: center;
    }

    .contact-info {
      margin-bottom: 1rem;
    }

    .action-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
