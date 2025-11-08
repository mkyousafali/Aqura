<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  
  let currentLanguage = 'ar';
  let adminWhatsAppNumber = '+966548357066'; // Aqura admin WhatsApp
  let currentLocation = 'الرياض، المملكة العربية السعودية'; // Default location

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
  
  const userProfile = {
    name: 'يوسف علي',
    nameEn: 'Yousuf Ali',
    whatsapp: '+966548357066',
    joinDate: '2024-01-15',
    totalOrders: 12,
    preferredLanguage: 'ar'
  };

  const recentOrders = [
    {
      id: '#2847',
      status: 'delivered',
      items: 'مياه معدنية وعصائر',
      itemsEn: 'Mineral water and juices',
      date: '2024-10-28',
      amount: 45.50
    },
    {
      id: '#2856',
      status: 'in_transit',
      items: 'مشروبات غازية ومياه',
      itemsEn: 'Soft drinks and water',
      date: '2024-11-01',
      amount: 67.25
    }
  ];

  $: texts = currentLanguage === 'ar' ? {
    title: 'الملف الشخصي - أكوا إكسبرس',
    personalInfo: 'المعلومات الشخصية',
    name: 'الاسم',
    whatsapp: 'رقم الواتساب',
    memberSince: 'عضو منذ',
    totalOrders: 'إجمالي الطلبات',
    addresses: 'العناوين',
    currentLocation: 'الموقع الحالي',
    changeLocation: 'تغيير الموقع',
    locationChangeRequest: 'طلب تغيير الموقع',
    security: 'الأمان',
    legal: 'القوانين',
    support: 'الدعم',
    manageAddresses: 'إدارة العناوين',
    changePassword: 'تغيير كلمة المرور',
    accessCodeSetup: 'إعداد رمز الدخول',
    signOutAll: 'تسجيل الخروج من جميع الأجهزة',
    termsConditions: 'الشروط والأحكام',
    privacyPolicy: 'سياسة الخصوصية',
    contactSupport: 'اتصل بالدعم',
    callSupport: 'اتصال بالدعم',
    chatSupport: 'دردشة مع الدعم',
    logout: 'تسجيل الخروج',
    orders: 'الطلبات',
    trackOrder: 'تتبع الطلب',
    orderHistory: 'سجل الطلبات',
    recentActivity: 'النشاط الأخير',
    viewAllOrders: 'عرض جميع الطلبات',
    orderDelivered: 'تم تسليم الطلب',
    orderInProgress: 'طلب قيد التوصيل',
    orderPickedUp: 'تم تحضير الطلب',
    viewDetails: 'عرض التفاصيل',
    backToHome: 'العودة للرئيسية'
  } : {
    title: 'Profile - Aqua Express',
    personalInfo: 'Personal Information',
    name: 'Name',
    whatsapp: 'WhatsApp Number',
    memberSince: 'Member Since',
    totalOrders: 'Total Orders',
    addresses: 'Addresses',
    currentLocation: 'Current Location',
    changeLocation: 'Change Location',
    locationChangeRequest: 'Location Change Request',
    security: 'Security',
    legal: 'Legal',
    support: 'Support',
    manageAddresses: 'Manage Addresses',
    changePassword: 'Change Password',
    accessCodeSetup: 'Access Code Setup',
    signOutAll: 'Sign Out All Devices',
    termsConditions: 'Terms & Conditions',
    privacyPolicy: 'Privacy Policy',
    contactSupport: 'Contact Support',
    callSupport: 'Call Support',
    chatSupport: 'Chat with Support',
    logout: 'Logout',
    orders: 'Orders',
    trackOrder: 'Track Order',
    orderHistory: 'Order History',
    recentActivity: 'Recent Activity',
    viewAllOrders: 'View All Orders',
    orderDelivered: 'Order Delivered',
    orderInProgress: 'Order In Transit',
    orderPickedUp: 'Order Prepared',
    viewDetails: 'View Details',
    backToHome: 'Back to Home'
  };

  function handleLogout() {
    console.log('🔄 [Profile] Logout button clicked');
    try {
      localStorage.clear();
      console.log('🔄 [Profile] Navigating to customer login page...');
      goto('/customer-login');
    } catch (error) {
      console.error('❌ [Profile] Logout error:', error);
    }
  }

  function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString(currentLanguage === 'ar' ? 'ar-SA' : 'en-US');
  }

  function requestLocationChange() {
    const message = currentLanguage === 'ar' 
      ? 'مرحباً، أريد تغيير موقعي الافتراضي في حساب أكوا إكسبرس. الموقع الحالي: ' + currentLocation
      : 'Hello, I want to change my default location in Aqua Express account. Current location: ' + currentLocation;
    
    const encodedMessage = encodeURIComponent(message);
    const whatsappUrl = `https://wa.me/${adminWhatsAppNumber.replace(/[^0-9]/g, '')}?text=${encodedMessage}`;
    
    // Open WhatsApp in new window
    window.open(whatsappUrl, '_blank');
  }

  function goToProducts() {
    goto('/customer/products');
  }

  function goToCart() {
    goto('/customer/cart');
  }

  function contactSupport() {
    const message = currentLanguage === 'ar' 
      ? 'مرحباً، أحتاج إلى مساعدة في أكوا إكسبرس'
      : 'Hello, I need help with Aqua Express';
    
    const encodedMessage = encodeURIComponent(message);
    const whatsappUrl = `https://wa.me/${adminWhatsAppNumber.replace(/[^0-9]/g, '')}?text=${encodedMessage}`;
    
    window.open(whatsappUrl, '_blank');
  }

  function callSupport() {
    // This will be handled from desktop interface later
    // For now, show an alert or do nothing
    alert(currentLanguage === 'ar' 
      ? 'سيتم تفعيل خدمة المكالمات قريباً'
      : 'Call feature will be available soon');
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="profile-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <header class="page-header">
    <h1>{texts.title}</h1>
    <div class="header-actions">
      <button class="back-btn" on:click={goToProducts} type="button">
        ← {texts.backToHome}
      </button>
    </div>
  </header>

  <!-- Personal Information -->
  <div class="profile-card">
    <div class="section">
      <h2>{texts.personalInfo}</h2>
      <div class="profile-info">
        <div class="avatar-large">
          {(currentLanguage === 'ar' ? userProfile.name : userProfile.nameEn).charAt(0)}
        </div>
        <div class="info-details">
          <div class="info-item">
            <label>{texts.name}:</label>
            <span>{currentLanguage === 'ar' ? userProfile.name : userProfile.nameEn}</span>
          </div>
          <div class="info-item">
            <label>{texts.whatsapp}:</label>
            <span>{userProfile.whatsapp}</span>
          </div>
          <div class="info-item">
            <label>{texts.memberSince}:</label>
            <span>{formatDate(userProfile.joinDate)}</span>
          </div>
          <div class="info-item">
            <label>{texts.totalOrders}:</label>
            <span>{userProfile.totalOrders}</span>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Location Management -->
  <div class="profile-card">
    <div class="section">
      <h2>{texts.addresses}</h2>
      <div class="location-section">
        <div class="current-location">
          <div class="location-info">
            <div class="location-icon">📍</div>
            <div class="location-details">
              <label>{texts.currentLocation}:</label>
              <span class="location-text">{currentLocation}</span>
            </div>
          </div>
          <button class="change-location-btn" on:click={requestLocationChange}>
            <span class="whatsapp-icon">📱</span>
            {texts.changeLocation}
          </button>
        </div>
        
        <div class="location-note">
          <p>{currentLanguage === 'ar' 
            ? 'سيتم إرسال طلب تغيير الموقع عبر الواتساب. سيقوم الفريق بمراجعة طلبك خلال 24 ساعة.'
            : 'Location change request will be sent via WhatsApp. Our team will review your request within 24 hours.'
          }</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Orders Section -->
  <div class="profile-card">
    <div class="section">
      <h2>{texts.orders}</h2>
      <div class="menu-items">
        <button class="menu-item" on:click={() => goto('/customer/track-order')}>
          <span>🔍 {texts.trackOrder}</span>
          <span class="arrow">›</span>
        </button>
        <button class="menu-item" on:click={() => goto('/customer/orders')}>
          <span>📋 {texts.orderHistory}</span>
          <span class="arrow">›</span>
        </button>
      </div>
    </div>
  </div>

  <!-- Support -->
  <div class="profile-card">
    <div class="section">
      <h2>{texts.support}</h2>
      <div class="menu-items">
        <button class="menu-item" on:click={contactSupport}>
          <span>💬 {texts.chatSupport}</span>
          <span class="arrow">›</span>
        </button>
        <button class="menu-item" on:click={callSupport}>
          <span>📞 {texts.callSupport}</span>
          <span class="arrow">›</span>
        </button>
      </div>
    </div>
  </div>

  <!-- Logout -->
  <div class="logout-section">
    <button class="logout-btn" on:click={handleLogout} type="button">
      🚪 {texts.logout}
    </button>
  </div>
</div>

<style>
  .profile-container {
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
    position: relative;
  }

  .page-header h1 {
    margin: 0 0 1rem 0;
    color: var(--color-ink);
    font-size: 1.5rem;
  }

  .header-actions {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 1rem;
  }

  .language-toggle-btn {
    background: var(--color-primary-light);
    border: 1px solid var(--color-primary);
    color: var(--color-primary);
    padding: 0.5rem 1rem;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.9rem;
    font-weight: 500;
    transition: all 0.2s ease;
    pointer-events: auto;
    touch-action: manipulation;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    min-height: 44px;
    min-width: 44px;
  }

  .language-toggle-btn:hover {
    background: var(--color-primary);
    color: white;
  }

  .language-toggle-btn:active {
    transform: scale(0.98);
    background: var(--color-primary-dark);
    color: white;
  }

  .back-btn {
    background: none;
    border: 1px solid var(--color-border);
    color: var(--color-primary);
    padding: 0.5rem 1rem;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.9rem;
    transition: all 0.2s ease;
  }

  .back-btn:hover {
    background: var(--color-primary);
    color: white;
  }

  .profile-card {
    background: white;
    border-radius: 16px;
    margin-bottom: 1rem;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    border: 1px solid var(--color-border-light);
  }

  .section {
    padding: 1.5rem;
  }

  .section h2 {
    margin: 0 0 1.5rem 0;
    color: var(--color-ink);
    font-size: 1.1rem;
    font-weight: 600;
  }

  .profile-info {
    display: flex;
    gap: 1.5rem;
    align-items: center;
  }

  .avatar-large {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    background: var(--color-primary);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 2rem;
    font-weight: 600;
    flex-shrink: 0;
  }

  .info-details {
    flex: 1;
  }

  .info-item {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0.75rem;
    padding: 0.75rem 0;
    border-bottom: 1px solid var(--color-border-light);
  }

  .info-item:last-child {
    border-bottom: none;
    margin-bottom: 0;
  }

  .info-item label {
    color: var(--color-ink-light);
    font-weight: 500;
    font-size: 0.9rem;
  }

  .info-item span {
    color: var(--color-ink);
    font-weight: 500;
  }

  /* Location Section Styles */
  .location-section {
    margin-top: 1rem;
  }

  .current-location {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    background: var(--color-background);
    border-radius: 12px;
    margin-bottom: 1rem;
    border: 1px solid var(--color-border-light);
  }

  .location-info {
    display: flex;
    align-items: center;
    gap: 1rem;
    flex: 1;
  }

  .location-icon {
    font-size: 1.5rem;
    color: var(--color-primary);
  }

  .location-details {
    flex: 1;
  }

  .location-details label {
    display: block;
    color: var(--color-ink-light);
    font-weight: 500;
    font-size: 0.85rem;
    margin-bottom: 0.25rem;
  }

  .location-text {
    color: var(--color-ink);
    font-size: 0.9rem;
    line-height: 1.4;
  }

  .change-location-btn {
    background: var(--color-primary);
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 8px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 500;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    transition: background 0.2s ease;
  }

  .change-location-btn:hover {
    background: var(--color-primary-dark);
  }

  .location-note {
    padding: 1rem;
    background: #f0f9ff;
    border: 1px solid #7dd3fc;
    border-radius: 8px;
  }

  .location-note p {
    margin: 0;
    color: #0c4a6e;
    font-size: 0.85rem;
    line-height: 1.4;
  }

  .whatsapp-icon {
    font-size: 1rem;
  }

  .menu-items {
    display: flex;
    flex-direction: column;
  }

  .menu-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 0;
    border: none;
    background: none;
    cursor: pointer;
    border-bottom: 1px solid var(--color-border-light);
    color: var(--color-ink);
    transition: all 0.3s ease;
    text-align: left;
    font-size: 1rem;
    font-weight: 500;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    position: relative;
    z-index: 10;
  }

  .menu-item:hover {
    color: var(--color-primary);
    background: rgba(22, 163, 74, 0.05);
    padding-left: 0.5rem;
    padding-right: 0.5rem;
    margin-left: -0.5rem;
    margin-right: -0.5rem;
    border-radius: 8px;
  }

  .menu-item:active {
    transform: scale(0.98);
    background: rgba(22, 163, 74, 0.1);
  }

  .menu-item:last-child {
    border-bottom: none;
  }

  .arrow {
    color: var(--color-ink-light);
    font-size: 1.5rem;
    transition: all 0.3s ease;
  }

  .menu-item:hover .arrow {
    color: var(--color-primary);
    transform: translateX(5px);
  }

  .logout-section {
    margin-top: 2rem;
  }

  .logout-btn {
    width: 100%;
    background: var(--color-danger);
    color: white;
    border: none;
    padding: 1rem;
    border-radius: 12px;
    cursor: pointer;
    font-size: 1rem;
    font-weight: 600;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    transition: background 0.2s ease;
    pointer-events: auto;
    touch-action: manipulation;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    min-height: 50px;
    position: relative;
    z-index: 1;
  }

  .logout-btn:hover {
    background: #dc2626;
  }

  .logout-btn:active {
    transform: scale(0.98);
    background: #b91c1c;
  }

  /* Responsive adjustments */
  @media (max-width: 480px) {
    .profile-container {
      padding: 0.75rem;
    }

    .profile-info {
      gap: 1rem;
    }

    .avatar-large {
      width: 60px;
      height: 60px;
      font-size: 1.5rem;
    }

    .current-location {
      flex-direction: column;
      gap: 1rem;
      align-items: stretch;
    }

    .change-location-btn {
      justify-content: center;
    }

    .section {
      padding: 1rem;
    }
  }
</style>