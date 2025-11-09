<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  
  import { currentUser } from '$lib/utils/persistentAuth';
  import { supabase } from '$lib/utils/supabase';
  import LocationMapDisplay from '$lib/components/LocationMapDisplay.svelte';
  import LocationPicker from '$lib/components/LocationPicker.svelte';

  let currentLanguage = 'ar';
  let adminWhatsAppNumber = '+966548357066'; // Aqura admin WhatsApp
  let currentLocation = ''; // Will be loaded from database
  interface CustomerRow {
    id: string;
    name?: string;
    customer_name?: string; // from customer_session
    whatsapp_number?: string;
    created_at?: string;
    total_orders?: number;
    location1_name?: string; location1_url?: string; location1_lat?: number; location1_lng?: number;
    location2_name?: string; location2_url?: string; location2_lat?: number; location2_lng?: number;
    location3_name?: string; location3_url?: string; location3_lat?: number; location3_lng?: number;
  }
  let customerRecord: CustomerRow | null = null;
  let loadingCustomer = true;
  let loadError = '';
  let locationOptions: Array<{ key: string; name: string; url: string; lat: number; lng: number }> = [];
  let selectedLocationKey: string | null = null;
  let selectedLocationIndex = 0;
  
  // Location picker modal state
  let showLocationPickerModal = false;
  let editingLocationSlot = 1; // Which location slot (1, 2, or 3) is being edited
  let pickedLocation: { name: string; lat: number; lng: number; url: string } | null = null;
  let savingLocation = false;

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
  
  // Derived reactive profile data from DB row
  interface ProfileData {
    name: string;
    nameEn: string;
    whatsapp: string;
    joinDate: string;
    totalOrders: number;
    preferredLanguage: string;
  }
  let userProfile: ProfileData = {
    name: '',
    nameEn: '',
    whatsapp: '',
    joinDate: '',
    totalOrders: 0,
    preferredLanguage: 'ar'
  };

  function getLocalCustomerSession(): { customerId: string | null; customer?: any } {
    try {
      // Try customer_session first (direct customer login)
      const customerSessionRaw = localStorage.getItem('customer_session');
      if (customerSessionRaw) {
        const customerSession = JSON.parse(customerSessionRaw);
        if (customerSession?.customer_id && customerSession?.registration_status === 'approved') {
          return { 
            customerId: customerSession.customer_id, 
            customer: customerSession 
          };
        }
      }

      // Fallback to aqura-device-session (employee with customer access)
      const raw = localStorage.getItem('aqura-device-session');
      if (!raw) return { customerId: null };
      const session = JSON.parse(raw);
      const currentId = session?.currentUserId;
      const user = Array.isArray(session?.users)
        ? session.users.find((u: any) => u.id === currentId && u.isActive)
        : null;
      const customerId = user?.customerId || null;
      return { customerId, customer: user?.customer };
    } catch (e) {
      return { customerId: null };
    }
  }

  async function fetchCustomerById(customerId: string, primeFrom?: any) {
    // Use cached details first
    if (primeFrom) {
      customerRecord = primeFrom;
      hydrateProfile(customerRecord as CustomerRow);
    }
    const { data, error } = await supabase
      .from('customers')
      .select('*')
      .eq('id', customerId)
      .single();
    if (error) {
      console.error('❌ [Profile] Failed loading customer:', error);
      loadError = currentLanguage === 'ar' ? 'تعذر تحميل بيانات العميل' : 'Failed to load customer data';
    } else if (data) {
      customerRecord = data as CustomerRow;
      hydrateProfile(customerRecord);
    }
  }

  async function loadCustomer() {
    try {
      loadingCustomer = true;
      let navigated = false;

      // 1) Try fast local session
      const local = getLocalCustomerSession();
      if (local.customerId) {
        await fetchCustomerById(local.customerId, local.customer);
        loadingCustomer = false;
        // Still keep listening in case of later updates (access code refresh etc.)
      }

      // 2) Wait briefly for store to populate, then fallback to login
      let resolved = !!local.customerId; // already resolved if local session worked
      const unsubscribe = currentUser.subscribe(async (cu) => {
        if (resolved) return; // already have data
        if (cu?.customerId) {
          resolved = true;
          await fetchCustomerById(cu.customerId, cu.customer);
          loadingCustomer = false;
          unsubscribe();
        }
      });

      // Extend timeout to allow slower network/device hydration (e.g. service worker warm-up)
      const MAX_WAIT_MS = 5000;
      setTimeout(() => {
        if (!resolved && !navigated) {
          // Instead of immediate navigation, show error and keep page available
          loadError = currentLanguage === 'ar' ? 'لم يتم العثور على جلسة العميل. الرجاء تسجيل الدخول.' : 'Customer session not found. Please login.';
          loadingCustomer = false;
          navigated = true;
          unsubscribe();
          // Provide a gentle redirect after short delay so user can read message
          setTimeout(() => {
            if (!customerRecord) goto('/customer-login');
          }, 1500);
        }
      }, MAX_WAIT_MS);
    } catch (err) {
      console.error('❌ [Profile] loadCustomer exception:', err);
      loadError = currentLanguage === 'ar' ? 'خطأ غير متوقع' : 'Unexpected error';
      loadingCustomer = false;
    }
  }

  function hydrateProfile(row: CustomerRow) {
    console.log('🔍 [Profile] Customer data received:', row);
    userProfile = {
      name: row.name || row.customer_name || '',
      nameEn: row.name || row.customer_name || '', // If multilingual names implemented later
      whatsapp: row.whatsapp_number || '',
      joinDate: row.created_at || '',
      totalOrders: row.total_orders || 0, // If denormalized field exists; else remains 0
      preferredLanguage: currentLanguage
    };
    buildLocationOptions(row);
  }

  function buildLocationOptions(row: CustomerRow) {
    console.log('📍 [Profile] Building location options from row:', {
      location1_name: row.location1_name,
      location1_url: row.location1_url,
      location1_lat: row.location1_lat,
      location1_lng: row.location1_lng,
      location2_name: row.location2_name,
      location2_url: row.location2_url,
      location2_lat: row.location2_lat,
      location2_lng: row.location2_lng,
      location3_name: row.location3_name,
      location3_url: row.location3_url,
      location3_lat: row.location3_lat,
      location3_lng: row.location3_lng
    });
    locationOptions = [];
    for (let i = 1; i <= 3; i++) {
      const name = row[`location${i}_name`];
      const url = row[`location${i}_url`];
      const lat = row[`location${i}_lat`];
      const lng = row[`location${i}_lng`];
      if ((name || url) && lat && lng) {
        locationOptions.push({ 
          key: `location${i}`, 
          name: name || (currentLanguage === 'ar' ? `الموقع ${i}` : `Location ${i}`), 
          url: url || '',
          lat,
          lng
        });
      }
    }
    console.log('📍 [Profile] Location options built:', locationOptions);
    if (locationOptions.length > 0) {
      // Default to first non-empty location
      if (!selectedLocationKey) {
        selectedLocationKey = locationOptions[0].key;
        selectedLocationIndex = 0;
      }
      const sel = locationOptions.find(l => l.key === selectedLocationKey) || locationOptions[0];
      currentLocation = sel.name;
    } else {
      // No saved locations
      currentLocation = currentLanguage === 'ar' ? 'لا توجد مواقع محفوظة' : 'No saved locations';
    }
    console.log('📍 [Profile] Current location set to:', currentLocation);
  }

  function selectLocation(key: string) {
    selectedLocationKey = key;
    const index = locationOptions.findIndex(l => l.key === key);
    if (index >= 0) {
      selectedLocationIndex = index;
      currentLocation = locationOptions[index].name;
    }
  }

  function handleMapLocationClick(index: number) {
    if (index >= 0 && index < locationOptions.length) {
      selectLocation(locationOptions[index].key);
    }
  }

  function openLocationPicker(slotNumber: number) {
    editingLocationSlot = slotNumber;
    pickedLocation = null;
    showLocationPickerModal = true;
  }

  function closeLocationPickerModal() {
    showLocationPickerModal = false;
    pickedLocation = null;
    savingLocation = false;
  }

  function handleLocationPicked(location: { name: string; lat: number; lng: number; url: string }) {
    pickedLocation = location;
  }

  async function savePickedLocation() {
    if (!pickedLocation || !customerRecord) return;
    
    try {
      savingLocation = true;
      const updates = {
        [`location${editingLocationSlot}_name`]: pickedLocation.name,
        [`location${editingLocationSlot}_url`]: pickedLocation.url,
        [`location${editingLocationSlot}_lat`]: pickedLocation.lat,
        [`location${editingLocationSlot}_lng`]: pickedLocation.lng,
      };

      const { error } = await supabase
        .from('customers')
        .update(updates)
        .eq('id', customerRecord.id);

      if (error) {
        console.error('❌ [Profile] Failed to save location:', error);
        alert(currentLanguage === 'ar' ? 'فشل حفظ الموقع' : 'Failed to save location');
      } else {
        // Update local customer record
        Object.assign(customerRecord, updates);
        buildLocationOptions(customerRecord);
        closeLocationPickerModal();
        
        // Show success message
        const successMsg = currentLanguage === 'ar' ? 'تم حفظ الموقع بنجاح!' : 'Location saved successfully!';
        alert(successMsg);
      }
    } catch (e) {
      console.error('❌ [Profile] Exception saving location:', e);
      alert(currentLanguage === 'ar' ? 'حدث خطأ غير متوقع' : 'Unexpected error');
    } finally {
      savingLocation = false;
    }
  }

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
    addLocation: 'إضافة موقع جديد',
    editLocation: 'تعديل الموقع',
    pickLocation: 'اختر الموقع على الخريطة',
    saveLocation: 'حفظ الموقع',
    cancel: 'إلغاء',
    saving: 'جاري الحفظ...',
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
    addLocation: 'Add New Location',
    editLocation: 'Edit Location',
    pickLocation: 'Pick Location on Map',
    saveLocation: 'Save Location',
    cancel: 'Cancel',
    saving: 'Saving...',
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

  function goToProducts() { goto('/customer/products'); }

  function goToCart() { goto('/customer/cart'); }

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

  // Initial load
  onMount(loadCustomer);
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="profile-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Personal Information -->
  <div class="profile-card">
    <div class="section">
      <h2>{texts.personalInfo}</h2>
      <div class="profile-info">
        <div class="avatar-large">
          {loadingCustomer ? '…' : (currentLanguage === 'ar' ? userProfile.name : userProfile.nameEn).charAt(0) || '؟'}
        </div>
        <div class="info-details">
          <div class="info-item">
            <label>{texts.name}:</label>
            <span>{loadingCustomer ? '...' : (currentLanguage === 'ar' ? userProfile.name : userProfile.nameEn) || (currentLanguage === 'ar' ? 'غير متوفر' : 'Not set')}</span>
          </div>
          <div class="info-item">
            <label>{texts.whatsapp}:</label>
            <span>{loadingCustomer ? '...' : userProfile.whatsapp || (currentLanguage === 'ar' ? 'غير متوفر' : 'Not set')}</span>
          </div>
          <div class="info-item">
            <label>{texts.memberSince}:</label>
            <span>{loadingCustomer ? '...' : (userProfile.joinDate ? formatDate(userProfile.joinDate) : (currentLanguage === 'ar' ? 'غير متوفر' : 'Not set'))}</span>
          </div>
          <div class="info-item">
            <label>{texts.totalOrders}:</label>
            <span>{loadingCustomer ? '...' : userProfile.totalOrders}</span>
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
        
        {#if locationOptions.length > 0}
          <div class="map-display-container">
            <LocationMapDisplay 
              locations={locationOptions}
              selectedIndex={selectedLocationIndex}
              onLocationClick={handleMapLocationClick}
              language={currentLanguage}
              height="250px"
            />
          </div>
          
          <div class="saved-locations">
            {#each locationOptions as loc, index}
              <div class="saved-location-item">
                <button type="button" class="saved-location-btn {selectedLocationKey === loc.key ? 'active' : ''}" on:click={() => selectLocation(loc.key)}>
                  <span class="location-number">{index + 1}</span>
                  {loc.name}
                </button>
                <button class="edit-location-btn" on:click={() => openLocationPicker(index + 1)} title={texts.editLocation}>
                  ✏️
                </button>
              </div>
            {/each}
          </div>
        {/if}
        
        <!-- Add location buttons for empty slots -->
        <div class="add-locations">
          {#each [1, 2, 3] as slotNum}
            {#if !locationOptions.find(loc => loc.key === `location${slotNum}`)}
              <button class="add-location-btn" on:click={() => openLocationPicker(slotNum)}>
                <span class="add-icon">➕</span>
                {texts.addLocation} {slotNum}
              </button>
            {/if}
          {/each}
        </div>
        
        <div class="location-note">
          <p>{currentLanguage === 'ar' 
            ? 'يمكنك حفظ حتى 3 مواقع توصيل. انقر على "إضافة موقع جديد" لاختيار موقع على الخريطة.'
            : 'You can save up to 3 delivery locations. Click "Add New Location" to pick a location on the map.'
          }</p>
          {#if loadError}
            <p class="error-text">{loadError}</p>
          {/if}
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

<!-- Location Picker Modal -->
{#if showLocationPickerModal}
  <div class="modal-overlay" on:click={closeLocationPickerModal}>
    <div class="modal-content" on:click|stopPropagation>
      <div class="modal-header">
        <h3>📍 {texts.pickLocation} {editingLocationSlot}</h3>
        <button class="close-btn" on:click={closeLocationPickerModal}>✕</button>
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
            <p><strong>{currentLanguage === 'ar' ? 'الموقع المحدد:' : 'Selected Location:'}</strong></p>
            <p class="location-address">{pickedLocation.name}</p>
            <p class="location-coords">{pickedLocation.lat.toFixed(6)}, {pickedLocation.lng.toFixed(6)}</p>
          </div>
        {/if}
      </div>
      <div class="modal-footer">
        <button class="cancel-btn" on:click={closeLocationPickerModal}>{texts.cancel}</button>
        <button class="save-btn" disabled={!pickedLocation || savingLocation} on:click={savePickedLocation}>
          {savingLocation ? texts.saving : texts.saveLocation}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .profile-container {
    /* Brand palette derived from logo */
    --brand-green: #16a34a; /* primary */
    --brand-green-dark: #15803d;
    --brand-green-light: #22c55e;
    --brand-orange: #f59e0b; /* accent */
    --brand-orange-dark: #d97706;
    --brand-orange-light: #fbbf24;

    /* Remap app variables for this page to brand colors */
    --color-primary: var(--brand-green);
    --color-primary-dark: var(--brand-green-dark);
    --color-accent: var(--brand-orange);

    width: 100%;
    min-height: 100vh;
    height: calc(100vh - 45px);
    max-height: calc(100vh - 45px);
    margin: 0 auto;
    padding: 0.375rem; /* 25% reduction from 0.5rem */
    padding-bottom: 75px; /* 25% reduction from 100px */
    padding-top: 0.375rem; /* 25% reduction from 0.5rem */
    position: relative;
    overflow-x: hidden;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    touch-action: pan-y;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    align-items: center;

    /* Base background - Bright mint green matching home page */
    background: linear-gradient(180deg, #7ce5a5 0%, #5edda0 40%, #4dd99b 100%);
  }

  /* Orange wave - bottom layer with realistic wave animation */
  .profile-container::before {
    content: '';
    position: fixed;
    width: 200%;
    height: 150px;
    bottom: 0;
    left: -50%;
    z-index: 0;
    background: #FF5C00;
    border-radius: 50% 50% 0 0 / 100% 100% 0 0;
    animation: wave 8s ease-in-out infinite;
  }

  /* Second wave layer - faster animation */
  .profile-container::after {
    content: '';
    position: fixed;
    width: 200%;
    height: 120px;
    bottom: 0;
    left: -50%;
    z-index: 1;
    background: rgba(255, 92, 0, 0.8);
    border-radius: 50% 50% 0 0 / 100% 100% 0 0;
    animation: wave2 6s ease-in-out infinite;
  }

  @keyframes wave {
    0%, 100% {
      transform: translateX(0) translateY(0) rotate(0deg);
    }
    25% {
      transform: translateX(5%) translateY(-10px) rotate(1deg);
    }
    50% {
      transform: translateX(0) translateY(0) rotate(0deg);
    }
    75% {
      transform: translateX(-5%) translateY(-10px) rotate(-1deg);
    }
  }

  @keyframes wave2 {
    0%, 100% {
      transform: translateX(-5%) translateY(0) rotate(0deg);
    }
    25% {
      transform: translateX(0) translateY(-8px) rotate(-0.8deg);
    }
    50% {
      transform: translateX(-5%) translateY(0) rotate(0deg);
    }
    75% {
      transform: translateX(-10%) translateY(-8px) rotate(0.8deg);
    }
  }

  /* Ensure full-width background coverage */
  :global(body) {
    background: linear-gradient(180deg, #7ce5a5 0%, #5edda0 40%, #4dd99b 100%) !important;
  }

  .profile-card {
    background: rgba(255, 255, 255, 0.95);
    border-radius: 12px; /* 25% reduction from 16px */
    margin-bottom: 0.75rem; /* 25% reduction from 1rem */
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.15); /* 25% reduction from 0 8px 24px */
    border: 1.5px solid rgba(255, 255, 255, 0.9); /* 25% reduction from 2px */
    position: relative;
    z-index: 10;
    backdrop-filter: blur(7.5px); /* 25% reduction from 10px */
    width: 100%;
    max-width: 360px; /* 25% reduction from 480px */
    box-sizing: border-box;
  }

  .section {
    padding: 0.75rem; /* 25% reduction from 1rem */
    position: relative;
    z-index: 10;
    box-sizing: border-box;
  }

  .section h2 {
    margin: 0 0 1.125rem 0; /* 25% reduction from 1.5rem */
    color: var(--brand-green);
    font-size: 0.9rem; /* 25% reduction from 1.2rem */
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 0.375rem; /* 25% reduction from 0.5rem */
  }

  .section h2::before {
    content: '●';
    color: var(--brand-orange);
    font-size: 0.6rem; /* 25% reduction from 0.8rem */
  }

  .profile-info {
    display: flex;
    gap: 1.125rem; /* 25% reduction from 1.5rem */
    align-items: center;
  }

  .avatar-large {
    width: 67.5px; /* 25% reduction from 90px */
    height: 67.5px; /* 25% reduction from 90px */
    border-radius: 50%;
    background: linear-gradient(135deg, var(--brand-green) 0%, var(--brand-green-light) 100%);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.875rem; /* 25% reduction from 2.5rem */
    font-weight: 700;
    flex-shrink: 0;
    box-shadow: 0 6px 15px rgba(22, 163, 74, 0.3); /* 25% reduction from 0 8px 20px */
    border: 3px solid rgba(255, 255, 255, 0.9); /* 25% reduction from 4px */
  }

  .info-details {
    flex: 1;
  }

  .info-item {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0.5625rem; /* 25% reduction from 0.75rem */
    padding: 0.5625rem; /* 25% reduction from 0.75rem */
    border-bottom: 1px solid rgba(22, 163, 74, 0.1);
    background: linear-gradient(90deg, rgba(22, 163, 74, 0.02) 0%, transparent 100%);
    border-radius: 6px; /* 25% reduction from 8px */
  }

  .info-item:last-child {
    border-bottom: none;
    margin-bottom: 0;
  }

  .info-item label {
    color: var(--brand-green);
    font-weight: 600;
    font-size: 0.675rem; /* 25% reduction from 0.9rem */
  }

  .info-item span {
    color: var(--color-ink);
    font-weight: 600;
    font-size: 0.7125rem; /* 25% reduction from 0.95rem */
  }

  /* Location Section Styles */
  .location-section {
    margin-top: 0.75rem; /* 25% reduction from 1rem */
    position: relative;
    z-index: 10;
  }

  .current-location {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.9375rem; /* 25% reduction from 1.25rem */
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.05) 0%, rgba(245, 158, 11, 0.05) 100%);
    border-radius: 12px; /* 25% reduction from 16px */
    margin-bottom: 0.75rem; /* 25% reduction from 1rem */
    border: 1.5px solid rgba(22, 163, 74, 0.15); /* 25% reduction from 2px */
  }

  .location-info {
    display: flex;
    align-items: center;
    gap: 0.75rem; /* 25% reduction from 1rem */
    flex: 1;
  }

  .location-icon {
    font-size: 1.5rem; /* 25% reduction from 2rem */
    color: var(--brand-green);
    filter: drop-shadow(0 1.5px 3px rgba(22, 163, 74, 0.3)); /* 25% reduction from 0 2px 4px */
  }

  .location-details {
    flex: 1;
  }

  .location-details label {
    display: block;
    color: var(--brand-green);
    font-weight: 600;
    font-size: 0.675rem; /* 25% reduction from 0.9rem */
    margin-bottom: 0.1875rem; /* 25% reduction from 0.25rem */
  }

  .location-text {
    color: var(--color-ink);
    font-size: 0.7125rem; /* 25% reduction from 0.95rem */
    line-height: 1.4;
    font-weight: 500;
  }

  .change-location-btn {
    background: linear-gradient(135deg, var(--brand-green) 0%, var(--brand-green-light) 100%);
    color: white;
    border: none;
    padding: 0.525rem 0.9rem; /* 25% reduction from 0.7rem 1.2rem */
    border-radius: 9px; /* 25% reduction from 12px */
    cursor: pointer;
    font-size: 0.675rem; /* 25% reduction from 0.9rem */
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 0.375rem; /* 25% reduction from 0.5rem */
    transition: all 0.3s ease;
    box-shadow: 0 3px 9px rgba(22, 163, 74, 0.25); /* 25% reduction from 0 4px 12px */
  }

  .change-location-btn:hover {
    background: linear-gradient(135deg, var(--brand-green-light) 0%, var(--brand-green) 100%);
    transform: translateY(-1.5px); /* 25% reduction from -2px */
    box-shadow: 0 4.5px 15px rgba(22, 163, 74, 0.35); /* 25% reduction from 0 6px 20px */
  }

  .location-note {
    padding: 0.75rem 0.9375rem; /* 25% reduction from 1rem 1.25rem */
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.08) 0%, rgba(147, 197, 253, 0.08) 100%);
    border: 1.5px solid rgba(59, 130, 246, 0.2); /* 25% reduction from 2px */
    border-radius: 9px; /* 25% reduction from 12px */
  }

  .location-note p {
    margin: 0;
    color: #1e40af;
    font-size: 0.6375rem; /* 25% reduction from 0.85rem */
    line-height: 1.5;
    font-weight: 500;
  }

  .whatsapp-icon {
    font-size: 0.825rem; /* 25% reduction from 1.1rem */
  }

  .map-display-container {
    margin: 1rem 0;
    border-radius: 12px;
    overflow: hidden;
    border: 2px solid rgba(22, 163, 74, 0.15);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .saved-locations {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-top: 1rem;
  }

  .saved-location-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .saved-location-btn {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.875rem 1rem;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.05) 0%, rgba(34, 197, 94, 0.05) 100%);
    border: 2px solid rgba(22, 163, 74, 0.2);
    border-radius: 12px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 600;
    color: #374151;
    transition: all 0.3s ease;
    text-align: left;
    flex: 1;
  }

  .saved-location-btn:hover {
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.1) 0%, rgba(34, 197, 94, 0.1) 100%);
    border-color: rgba(22, 163, 74, 0.4);
    transform: translateX(-3px);
  }

  .saved-location-btn.active {
    background: linear-gradient(135deg, #16a34a 0%, #22c55e 100%);
    border-color: #16a34a;
    color: white;
    box-shadow: 0 4px 12px rgba(22, 163, 74, 0.3);
  }

  .edit-location-btn {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.1) 0%, rgba(147, 197, 253, 0.1) 100%);
    border: 2px solid rgba(59, 130, 246, 0.2);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    transition: all 0.2s ease;
    flex-shrink: 0;
  }

  .edit-location-btn:hover {
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.2) 0%, rgba(147, 197, 253, 0.2) 100%);
    border-color: rgba(59, 130, 246, 0.4);
    transform: scale(1.05);
  }

  .add-locations {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    margin-top: 1rem;
  }

  .add-location-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.875rem 1rem;
    background: linear-gradient(135deg, rgba(245, 158, 11, 0.05) 0%, rgba(251, 191, 36, 0.05) 100%);
    border: 2px dashed rgba(245, 158, 11, 0.4);
    border-radius: 12px;
    cursor: pointer;
    font-size: 0.85rem;
    font-weight: 600;
    color: #d97706;
    transition: all 0.3s ease;
  }

  .add-location-btn:hover {
    background: linear-gradient(135deg, rgba(245, 158, 11, 0.1) 0%, rgba(251, 191, 36, 0.1) 100%);
    border-color: rgba(245, 158, 11, 0.6);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(245, 158, 11, 0.2);
  }

  .add-icon {
    font-size: 1.1rem;
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

  .saved-location-btn.active .location-number {
    background: rgba(255, 255, 255, 0.3);
    color: white;
  }

  .menu-items {
    display: flex;
    flex-direction: column;
    position: relative;
    z-index: 10;
  }

  .menu-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.9375rem 0.75rem; /* 25% reduction from 1.25rem 1rem */
    border: none;
    background: linear-gradient(90deg, rgba(22, 163, 74, 0.02) 0%, transparent 100%);
    cursor: pointer;
    border-bottom: 1px solid rgba(22, 163, 74, 0.1);
    color: var(--color-ink);
    transition: all 0.3s ease;
    text-align: left;
    font-size: 0.75rem; /* 25% reduction from 1rem */
    font-weight: 600;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    position: relative;
    z-index: 10;
    border-radius: 9px; /* 25% reduction from 12px */
    margin-bottom: 0.375rem; /* 25% reduction from 0.5rem */
  }

  .menu-item:hover {
    color: var(--brand-green);
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.1) 0%, rgba(245, 158, 11, 0.05) 100%);
    transform: translateX(3.75px); /* 25% reduction from 5px */
    box-shadow: 0 3px 9px rgba(22, 163, 74, 0.15); /* 25% reduction from 0 4px 12px */
  }

  .menu-item:active {
    transform: scale(0.98);
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.15) 0%, rgba(245, 158, 11, 0.08) 100%);
  }

  .menu-item:last-child {
    border-bottom: none;
  }

  .arrow {
    color: var(--brand-green);
    font-size: 1.35rem; /* 25% reduction from 1.8rem */
    transition: all 0.3s ease;
    font-weight: 700;
  }

  .menu-item:hover .arrow {
    color: var(--brand-orange);
    transform: translateX(6px) scale(1.2); /* 25% reduction from 8px */
  }

  .logout-section {
    margin-top: 1.5rem; /* 25% reduction from 2rem */
    position: relative;
    z-index: 10;
    width: 100%;
    max-width: 360px; /* 25% reduction from 480px */
  }

  .logout-btn {
    width: 100%;
    background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
    color: white;
    border: none;
    padding: 0.9375rem; /* 25% reduction from 1.25rem */
    border-radius: 12px; /* 25% reduction from 16px */
    cursor: pointer;
    font-size: 0.7875rem; /* 25% reduction from 1.05rem */
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5625rem; /* 25% reduction from 0.75rem */
    transition: all 0.3s ease;
    pointer-events: auto;
    touch-action: manipulation;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    min-height: 42px; /* 25% reduction from 56px */
    position: relative;
    z-index: 10;
    box-shadow: 0 6px 18px rgba(239, 68, 68, 0.3); /* 25% reduction from 0 8px 24px */
  }

  .logout-btn:hover {
    background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
    transform: translateY(-1.5px); /* 25% reduction from -2px */
    box-shadow: 0 9px 21px rgba(239, 68, 68, 0.4); /* 25% reduction from 0 12px 28px */
  }

  .logout-btn:active {
    transform: scale(0.98);
    background: linear-gradient(135deg, #b91c1c 0%, #991b1b 100%);
  }

  /* Responsive adjustments */
  @media (max-width: 480px) {
    .profile-container {
      padding: 0.375rem; /* 25% reduction from 0.5rem */
      padding-bottom: 60px; /* 25% reduction from 80px */
      padding-top: 0.375rem; /* 25% reduction from 0.5rem */
      height: calc(100vh - 60px);
      max-height: calc(100vh - 60px);
      min-height: calc(100vh - 60px); /* 25% reduction from 60px */
    }

    .profile-container::before {
      height: 90px; /* 25% reduction from 120px */
    }

    .profile-container::after {
      height: 75px; /* 25% reduction from 100px */
    }

    .profile-card {
      max-width: 100%;
      padding: 0 0.25rem;
    }

    .logout-section {
      max-width: 100%;
      padding: 0 0.25rem;
    }

    .profile-info {
      gap: 0.5625rem; /* 25% reduction from 0.75rem */
      flex-direction: column;
      align-items: center;
      text-align: center;
    }

    .avatar-large {
      width: 52.5px; /* 25% reduction from 70px */
      height: 52.5px; /* 25% reduction from 70px */
      font-size: 1.5rem; /* 25% reduction from 2rem */
    }

    .info-details {
      width: 100%;
    }

    .current-location {
      flex-direction: column;
      gap: 0.75rem; /* 25% reduction from 1rem */
      align-items: stretch;
    }

    .change-location-btn {
      justify-content: center;
      width: 100%;
    }

    .section {
      padding: 0.75rem; /* 25% reduction from 1rem */
    }

    .section h2 {
      font-size: 0.75rem; /* 25% reduction from 1rem */
    }

    .profile-card {
      border-radius: 10.5px; /* 25% reduction from 14px */
      box-shadow: 0 4.5px 15px rgba(0, 0, 0, 0.12); /* 25% reduction from 0 6px 20px */
      margin-bottom: 0.5625rem; /* 25% reduction from 0.75rem */
    }

    .menu-item {
      padding: 0.65625rem 0.5625rem; /* 25% reduction from 0.875rem 0.75rem */
      font-size: 0.675rem; /* 25% reduction from 0.9rem */
    }

    .logout-btn {
      padding: 0.75rem; /* 25% reduction from 1rem */
      font-size: 0.7125rem; /* 25% reduction from 0.95rem */
    }
  }

  /* Tablet and larger screens */
  @media (min-width: 768px) {
    .profile-container {
      padding: 1.5rem; /* 25% reduction from 2rem */
      padding-bottom: 90px; /* 25% reduction from 120px */
    }

    .profile-container::before {
      height: 135px; /* 25% reduction from 180px */
    }

    .profile-container::after {
      height: 112.5px; /* 25% reduction from 150px */
    }

    .avatar-large {
      width: 75px; /* 25% reduction from 100px */
      height: 75px; /* 25% reduction from 100px */
      font-size: 2.25rem; /* 25% reduction from 3rem */
    }

    .section h2 {
      font-size: 0.975rem; /* 25% reduction from 1.3rem */
    }

    .profile-card {
      border-radius: 18px; /* 25% reduction from 24px */
    }
  }

  /* Modal Styles */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.7);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 1rem;
  }

  .modal-content {
    background: white;
    border-radius: 16px;
    max-width: 800px;
    width: 100%;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.5rem;
    border-bottom: 2px solid rgba(22, 163, 74, 0.1);
  }

  .modal-header h3 {
    margin: 0;
    color: #16a34a;
    font-size: 1.25rem;
    font-weight: 700;
  }

  .close-btn {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: rgba(239, 68, 68, 0.1);
    border: none;
    color: #dc2626;
    font-size: 1.5rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
  }

  .close-btn:hover {
    background: rgba(239, 68, 68, 0.2);
    transform: scale(1.1);
  }

  .modal-body {
    padding: 1.5rem;
  }

  .picked-location-info {
    margin-top: 1rem;
    padding: 1rem;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.05) 0%, rgba(34, 197, 94, 0.05) 100%);
    border: 2px solid rgba(22, 163, 74, 0.2);
    border-radius: 12px;
  }

  .picked-location-info p {
    margin: 0.5rem 0;
  }

  .location-address {
    font-size: 1rem;
    font-weight: 600;
    color: #16a34a;
  }

  .location-coords {
    font-size: 0.85rem;
    color: #6b7280;
    font-family: monospace;
  }

  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
    padding: 1.5rem;
    border-top: 2px solid rgba(22, 163, 74, 0.1);
  }

  .cancel-btn {
    padding: 0.75rem 1.5rem;
    background: white;
    border: 2px solid #d1d5db;
    border-radius: 10px;
    color: #6b7280;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .cancel-btn:hover {
    background: #f3f4f6;
    border-color: #9ca3af;
  }

  .save-btn {
    padding: 0.75rem 1.5rem;
    background: linear-gradient(135deg, #16a34a 0%, #22c55e 100%);
    border: none;
    border-radius: 10px;
    color: white;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 4px 12px rgba(22, 163, 74, 0.3);
  }

  .save-btn:hover:not(:disabled) {
    background: linear-gradient(135deg, #15803d 0%, #16a34a 100%);
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(22, 163, 74, 0.4);
  }

  .save-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>