<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { orderFlowActions } from '$lib/stores/orderFlow.js';
  import { deliveryActions } from '$lib/stores/delivery.js';
  import { supabase } from '$lib/utils/supabase';

  let currentLanguage = 'ar';
  let branches = [];
  let loading = true;
  let selectedBranch = null;
  let customerLat = null;
  let customerLng = null;
  let locationLoading = true;
  // Google Maps Distance Matrix results: { [branch_id]: { distance: string, duration: string } }
  let branchDistances = {};

  $: deliveryBranches = branches.filter(b => b.delivery_service_enabled);
  $: pickupBranches = branches.filter(b => b.pickup_service_enabled);

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) currentLanguage = savedLanguage;
    // Load branches and get customer location in parallel
    await Promise.all([loadBranches(), getCustomerLocation()]);
    // After both are ready, calculate driving distances
    if (customerLat != null && customerLng != null && branches.length > 0) {
      await calculateDrivingDistances();
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

  async function loadBranches() {
    loading = true;
    try {
      const { data, error } = await supabase.rpc('get_all_branches_delivery_settings');
      if (error) throw error;
      branches = (data || []).filter(b => b.delivery_service_enabled || b.pickup_service_enabled);
      console.log('Loaded branches:', branches.length);
    } catch (e) {
      console.error('Branch load error', e);
      alert('Failed to load branches');
    } finally {
      loading = false;
    }
  }

  function toggleBranch(branch) {
    console.log('Toggle branch called:', branch.branch_name_en);
    selectedBranch = selectedBranch?.branch_id === branch.branch_id ? null : branch;
  }

  // Get customer's current location
  async function getCustomerLocation() {
    locationLoading = true;
    try {
      if ('geolocation' in navigator) {
        const position = await new Promise((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, {
            enableHighAccuracy: true,
            timeout: 10000,
            maximumAge: 300000 // Cache for 5 mins
          });
        });
        customerLat = position.coords.latitude;
        customerLng = position.coords.longitude;
        console.log('📍 Customer location:', customerLat, customerLng);
      }
    } catch (e) {
      console.log('📍 Location unavailable:', e.message);
    } finally {
      locationLoading = false;
    }
  }

  // Calculate driving distances using Google Routes API (new) with Haversine fallback
  async function calculateDrivingDistances() {
    // Load API key from DB first, fallback to env
    let apiKey = '';
    try {
      const { data: keyRow } = await supabase
        .from('system_api_keys')
        .select('api_key')
        .eq('service_name', 'google')
        .eq('is_active', true)
        .single();
      if (keyRow?.api_key) apiKey = keyRow.api_key;
    } catch (_) { /* fallback to env */ }
    if (!apiKey) apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY || '';
    const branchesWithCoords = branches.filter(b => b.latitude && b.longitude);
    if (branchesWithCoords.length === 0) return;

    const newDistances = {};

    // Try Google Routes API for each branch in parallel
    if (apiKey) {
      const promises = branchesWithCoords.map(async (branch) => {
        try {
          const res = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'routes.localizedValues'
            },
            body: JSON.stringify({
              origin: { location: { latLng: { latitude: customerLat, longitude: customerLng } } },
              destination: { location: { latLng: { latitude: branch.latitude, longitude: branch.longitude } } },
              travelMode: 'DRIVE',
              languageCode: currentLanguage === 'ar' ? 'ar' : 'en'
            })
          });
          const data = await res.json();
          if (data.routes?.[0]?.localizedValues) {
            const lv = data.routes[0].localizedValues;
            newDistances[branch.branch_id] = {
              distance: lv.distance?.text || '',
              duration: lv.duration?.text || ''
            };
          }
        } catch (e) {
          console.warn(`📍 Routes API failed for branch ${branch.branch_id}:`, e.message);
        }
      });
      await Promise.all(promises);
    }

    // Haversine fallback for any branches that didn't get Routes API results
    branchesWithCoords.forEach((branch) => {
      if (!newDistances[branch.branch_id]) {
        const R = 6371;
        const dLat = (branch.latitude - customerLat) * Math.PI / 180;
        const dLon = (branch.longitude - customerLng) * Math.PI / 180;
        const a = Math.sin(dLat / 2) ** 2 +
          Math.cos(customerLat * Math.PI / 180) * Math.cos(branch.latitude * Math.PI / 180) *
          Math.sin(dLon / 2) ** 2;
        const dist = R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distText = dist < 1
          ? `${Math.round(dist * 1000)} ${currentLanguage === 'ar' ? 'م' : 'm'}`
          : `${dist.toFixed(1)} ${currentLanguage === 'ar' ? 'كم' : 'km'}`;
        newDistances[branch.branch_id] = { distance: distText, duration: '' };
      }
    });

    branchDistances = newDistances;
    console.log('📍 Driving distances calculated:', branchDistances);
  }

  // branchDistances is referenced directly in template for proper Svelte reactivity

  // Build Google Maps directions URL from customer location to branch
  function getDirectionsUrl(branch) {
    if (branch.location_url) return branch.location_url;
    if (branch.latitude && branch.longitude) {
      const origin = customerLat != null ? `${customerLat},${customerLng}` : '';
      return `https://www.google.com/maps/dir/${origin}/${branch.latitude},${branch.longitude}`;
    }
    return null;
  }

  function chooseService(branch, service) {
    console.log('Choose service called:', service, 'at', branch.branch_name_en);
    
    // Check if service is available based on working hours
    if (!isServiceAvailable(branch, service)) {
      const message = currentLanguage === 'ar'
        ? 'هذه الخدمة غير متاحة حالياً. يرجى المحاولة خلال ساعات العمل.'
        : 'This service is not available now. Please try during working hours.';
      alert(message);
      return;
    }
    
    orderFlowActions.setSelection(branch.branch_id, service);
    setTimeout(() => {
      goto('/customer-interface/products');
    }, 100);
  }

  // Check if service is available based on Saudi Arabia timezone
  function isServiceAvailable(branch, serviceType) {
    // Get current time in Saudi Arabia timezone (UTC+3)
    const now = new Date();
    const saudiTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
    const currentHour = saudiTime.getHours();
    const currentMinute = saudiTime.getMinutes();
    const currentTimeInMinutes = currentHour * 60 + currentMinute;
    
    if (serviceType === 'delivery') {
      // Check if delivery is 24/7
      if (branch.delivery_is_24_hours) return true;
      
      // Check delivery hours
      if (branch.delivery_start_time && branch.delivery_end_time) {
        const start = branch.delivery_start_time.split(':');
        const end = branch.delivery_end_time.split(':');
        const startMinutes = parseInt(start[0]) * 60 + parseInt(start[1]);
        const endMinutes = parseInt(end[0]) * 60 + parseInt(end[1]);
        
        // Handle overnight hours (e.g., 20:00 - 02:00)
        if (startMinutes > endMinutes) {
          return currentTimeInMinutes >= startMinutes || currentTimeInMinutes < endMinutes;
        } else {
          return currentTimeInMinutes >= startMinutes && currentTimeInMinutes < endMinutes;
        }
      }
    } else if (serviceType === 'pickup') {
      // Check if pickup is 24/7
      if (branch.pickup_is_24_hours) return true;
      
      // Check pickup hours
      if (branch.pickup_start_time && branch.pickup_end_time) {
        const start = branch.pickup_start_time.split(':');
        const end = branch.pickup_end_time.split(':');
        const startMinutes = parseInt(start[0]) * 60 + parseInt(start[1]);
        const endMinutes = parseInt(end[0]) * 60 + parseInt(end[1]);
        
        // Handle overnight hours
        if (startMinutes > endMinutes) {
          return currentTimeInMinutes >= startMinutes || currentTimeInMinutes < endMinutes;
        } else {
          return currentTimeInMinutes >= startMinutes && currentTimeInMinutes < endMinutes;
        }
      }
    }
    
    return true; // Default to available if no hours set
  }

  $: texts = currentLanguage === 'ar' ? {
    title: 'مرحبًا بك في ايربن ماركت',
    subtitle: 'اختر طريقة الطلب والفرع الأقرب إليك',
    selectBranch: 'اختر الفرع',
    services: 'الخدمات المتاحة',
    delivery: 'توصيل للمنزل',
    pickup: 'استلام من الفرع',
    loading: 'جاري التحميل...',
    unavailable: 'لا توجد خدمات متاحة',
    hours24: 'متاح ٢٤ ساعة',
    deliveryHours: 'ساعات التوصيل',
    pickupHours: 'ساعات الاستلام',
    directions: 'الاتجاهات',
    away: 'يبعد',
    orderNow: 'اطلب الآن',
    deliveryDesc: 'نوصّل لباب بيتك',
    pickupDesc: 'جهّز طلبك واستلمه'
  } : {
    title: 'Welcome to Urban Market',
    subtitle: 'Choose your order method and nearest branch',
    selectBranch: 'Select Branch',
    services: 'Available Services',
    delivery: 'Home Delivery',
    pickup: 'Store Pickup',
    loading: 'Loading...',
    unavailable: 'No services available',
    hours24: 'Open 24 Hours',
    deliveryHours: 'Delivery Hours',
    pickupHours: 'Pickup Hours',
    directions: 'Directions',
    away: 'away',
    orderNow: 'Order Now',
    deliveryDesc: 'Delivered to your door',
    pickupDesc: 'Ready when you arrive'
  };

  function convertTo12Hour(time24) {
    if (!time24) return '';
    
    // Parse the time string (format: HH:MM:SS or HH:MM)
    const parts = time24.split(':');
    let hours = parseInt(parts[0]);
    const minutes = parts[1];
    
    // Determine AM/PM with Arabic support
    let period;
    if (currentLanguage === 'ar') {
      period = hours >= 12 ? 'م' : 'ص';
    } else {
      period = hours >= 12 ? 'PM' : 'AM';
    }
    
    // Convert to 12-hour format
    hours = hours % 12;
    hours = hours ? hours : 12; // 0 should be 12
    
    // Use LTR embedding to prevent RTL reversal of time
    return `\u200E${hours}:${minutes} ${period}`;
  }

  function formatHours(branch, type) {
    if (type === 'delivery') {
      if (branch.delivery_is_24_hours) return texts.hours24;
      if (branch.delivery_start_time && branch.delivery_end_time) {
        const start = convertTo12Hour(branch.delivery_start_time);
        const end = convertTo12Hour(branch.delivery_end_time);
        return `${start} - ${end}`;
      }
    } else {
      if (branch.pickup_is_24_hours) return texts.hours24;
      if (branch.pickup_start_time && branch.pickup_end_time) {
        const start = convertTo12Hour(branch.pickup_start_time);
        const end = convertTo12Hour(branch.pickup_end_time);
        return `${start} - ${end}`;
      }
    }
    return '';
  }
</script>

<svelte:head><title>{texts.title}</title>
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" /></svelte:head>

<div class="start-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Soft ambient background shapes -->
  <div class="ambient-bg">
    <div class="ambient-shape shape-1"></div>
    <div class="ambient-shape shape-2"></div>
    <div class="ambient-shape shape-3"></div>
  </div>

  <!-- Hero Header with Logo -->
  <header class="hero-header">
    <div class="logo-container">
      <img src="/icons/logo.png" alt="Aqura" class="hero-logo" />
    </div>
    <h1 class="hero-title">{texts.title}</h1>
    <p class="hero-subtitle">{texts.subtitle}</p>
  </header>

  {#if loading}
    <div class="loading-state">
      <div class="loading-spinner"></div>
      <p>{texts.loading}</p>
    </div>
  {:else}
    {#if branches.length === 0}
      <!-- No branches with any service available -->
      <div class="no-service-container">
        <div class="no-service-icon">🚫</div>
        <h2 class="no-service-title">{currentLanguage === 'ar' ? 'الخدمة غير متاحة حالياً' : 'Service Not Available'}</h2>
        <p class="no-service-desc">{currentLanguage === 'ar' ? 'لا توجد فروع متاحة للخدمة في الوقت الحالي. يرجى المحاولة لاحقاً.' : 'No branches are currently available for service. Please try again later.'}</p>
        <button class="retry-btn" on:click={loadBranches}>
          🔄 {currentLanguage === 'ar' ? 'إعادة المحاولة' : 'Retry'}
        </button>
      </div>
    {:else}
    <div class="sections-wrapper">
      <!-- Delivery Service Section -->
      {#if deliveryBranches.length > 0}
        <section class="service-section">
          <div class="section-header delivery-header">
            <div class="section-header-content">
              <span class="section-icon">🚚</span>
              <div>
                <h2 class="section-title">{texts.delivery}</h2>
                <p class="section-desc">{texts.deliveryDesc}</p>
              </div>
            </div>
          </div>
          <div class="branch-list">
            {#each deliveryBranches as branch}
              <button 
                class="branch-card {!isServiceAvailable(branch, 'delivery') ? 'branch-closed' : ''}" 
                on:click={() => chooseService(branch, 'delivery')}
                type="button"
              >
                <div class="branch-card-body">
                  <div class="branch-info">
                    <h3 class="branch-name">{currentLanguage === 'ar' ? branch.branch_name_ar : branch.branch_name_en}</h3>
                    <span class="branch-hours">{formatHours(branch, 'delivery')}</span>
                    {#if !isServiceAvailable(branch, 'delivery')}
                      <span class="status-closed">{currentLanguage === 'ar' ? 'مغلق الآن' : 'Closed Now'}</span>
                    {/if}
                  </div>
                  <div class="branch-action">
                    <span class="action-arrow">
                      {#if currentLanguage === 'ar'}←{:else}→{/if}
                    </span>
                  </div>
                </div>
              </button>
            {/each}
          </div>
        </section>
      {/if}

      <!-- Pickup Service Section -->
      {#if pickupBranches.length > 0}
        <section class="service-section">
          <div class="section-header pickup-header">
            <div class="section-header-content">
              <span class="section-icon">🏪</span>
              <div>
                <h2 class="section-title">{texts.pickup}</h2>
                <p class="section-desc">{texts.pickupDesc}</p>
              </div>
            </div>
          </div>
          <div class="branch-list">
            {#each pickupBranches as branch}
              <button 
                class="branch-card {!isServiceAvailable(branch, 'pickup') ? 'branch-closed' : ''}" 
                on:click={() => chooseService(branch, 'pickup')}
                type="button"
              >
                <div class="branch-card-body">
                  <div class="branch-info">
                    <h3 class="branch-name">{currentLanguage === 'ar' ? branch.branch_name_ar : branch.branch_name_en}</h3>
                    <span class="branch-hours">{formatHours(branch, 'pickup')}</span>
                    {#if !isServiceAvailable(branch, 'pickup')}
                      <span class="status-closed">{currentLanguage === 'ar' ? 'مغلق الآن' : 'Closed Now'}</span>
                    {/if}
                    {#if branchDistances[branch.branch_id]}
                      <span class="branch-distance">
                        📍 {branchDistances[branch.branch_id].distance}{#if branchDistances[branch.branch_id].duration} · {branchDistances[branch.branch_id].duration}{/if}
                      </span>
                    {/if}
                  </div>
                  <div class="branch-action">
                    {#if getDirectionsUrl(branch)}
                      <a
                        class="directions-link"
                        href={getDirectionsUrl(branch)}
                        target="_blank"
                        rel="noopener noreferrer"
                        on:click|stopPropagation
                        title={texts.directions}
                      >
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="directions-icon">
                          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
                          <circle cx="12" cy="10" r="3"/>
                        </svg>
                      </a>
                    {/if}
                    <span class="action-arrow">
                      {#if currentLanguage === 'ar'}←{:else}→{/if}
                    </span>
                  </div>
                </div>
              </button>
            {/each}
          </div>
        </section>
      {/if}
    </div>
    {/if}
  {/if}
</div>

<style>
  /* ===== No Service Available ===== */
  .no-service-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    padding: 3rem 2rem;
    margin: 2rem auto;
    max-width: 400px;
    background: white;
    border-radius: 20px;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
    position: relative;
    z-index: 1;
  }
  .no-service-icon {
    font-size: 3.5rem;
    margin-bottom: 1rem;
    filter: grayscale(0.2);
  }
  .no-service-title {
    font-size: 1.25rem;
    font-weight: 700;
    color: #dc2626;
    margin: 0 0 0.75rem 0;
  }
  .no-service-desc {
    font-size: 0.9rem;
    color: #6b7280;
    margin: 0 0 1.5rem 0;
    line-height: 1.6;
  }
  .retry-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 2rem;
    border-radius: 12px;
    font-size: 0.95rem;
    font-weight: 600;
    background: linear-gradient(135deg, #16a34a 0%, #22c55e 100%);
    color: white;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .retry-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(22, 163, 74, 0.3);
  }

  /* ===== Premium Start Page ===== */
  .start-container {
    --green: #16a34a;
    --green-dark: #15803d;
    --green-light: #22c55e;
    --orange: #f59e0b;
    --orange-light: #fbbf24;

    width: 100%;
    min-height: 100vh;
    height: calc(100vh - 45px);
    max-height: calc(100vh - 45px);
    overflow-y: auto;
    overflow-x: hidden;
    -webkit-overflow-scrolling: touch;
    background: #f0fdf4;
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 0 0 80px;
  }

  /* Ambient background blobs */
  .ambient-bg {
    position: fixed;
    inset: 0;
    pointer-events: none;
    z-index: 0;
    overflow: hidden;
  }

  .ambient-shape {
    position: absolute;
    border-radius: 50%;
    filter: blur(80px);
    opacity: 0.35;
  }

  .shape-1 {
    width: 300px; height: 300px;
    background: var(--green-light);
    top: -60px; right: -80px;
    animation: drift 20s ease-in-out infinite alternate;
  }

  .shape-2 {
    width: 250px; height: 250px;
    background: var(--orange-light);
    bottom: 10%; left: -60px;
    animation: drift 25s ease-in-out infinite alternate-reverse;
  }

  .shape-3 {
    width: 200px; height: 200px;
    background: #86efac;
    top: 40%; right: 20%;
    animation: drift 18s ease-in-out infinite alternate;
  }

  @keyframes drift {
    0% { transform: translate(0, 0) scale(1); }
    100% { transform: translate(30px, 20px) scale(1.08); }
  }

  /* ===== Hero Header ===== */
  .hero-header {
    position: relative;
    z-index: 10;
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2rem 1.5rem 1.5rem;
    background: linear-gradient(170deg, var(--green) 0%, var(--green-dark) 100%);
    border-radius: 0 0 32px 32px;
    box-shadow: 0 8px 32px rgba(22, 163, 74, 0.3);
    margin-bottom: 1.5rem;
  }

  .logo-container {
    width: 72px;
    height: 72px;
    background: white;
    border-radius: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.15);
    margin-bottom: 0.75rem;
    animation: logoEntry 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  @keyframes logoEntry {
    0% { opacity: 0; transform: scale(0.5) translateY(20px); }
    100% { opacity: 1; transform: scale(1) translateY(0); }
  }

  .hero-logo {
    width: 52px;
    height: 52px;
    object-fit: contain;
  }

  .hero-title {
    margin: 0;
    font-size: 1.45rem;
    font-weight: 800;
    color: white;
    text-align: center;
    line-height: 1.3;
    letter-spacing: -0.01em;
  }

  .hero-subtitle {
    margin: 0.35rem 0 0;
    font-size: 0.85rem;
    color: rgba(255, 255, 255, 0.85);
    font-weight: 500;
    text-align: center;
  }

  /* ===== Loading State ===== */
  .loading-state {
    position: relative;
    z-index: 10;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    padding: 3rem 0;
  }

  .loading-state p {
    margin: 0;
    color: #6b7280;
    font-weight: 600;
    font-size: 0.9rem;
  }

  .loading-spinner {
    width: 36px;
    height: 36px;
    border: 3px solid #e5e7eb;
    border-top-color: var(--green);
    border-radius: 50%;
    animation: spin 0.7s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* ===== Sections Wrapper ===== */
  .sections-wrapper {
    position: relative;
    z-index: 10;
    width: 100%;
    max-width: 420px;
    padding: 0 1rem;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
    animation: fadeUp 0.5s ease-out;
  }

  @keyframes fadeUp {
    0% { opacity: 0; transform: translateY(16px); }
    100% { opacity: 1; transform: translateY(0); }
  }

  /* ===== Service Section ===== */
  .service-section {
    background: white;
    border-radius: 20px;
    overflow: hidden;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.06), 0 1px 3px rgba(0, 0, 0, 0.04);
    border: 1px solid rgba(0, 0, 0, 0.04);
  }

  /* Section Headers */
  .section-header {
    padding: 1rem 1.125rem;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .delivery-header {
    background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
    border-bottom: 1px solid #a7f3d0;
  }

  .pickup-header {
    background: linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%);
    border-bottom: 1px solid #fde68a;
  }

  .section-header-content {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .section-icon {
    font-size: 1.75rem;
    line-height: 1;
  }

  .section-title {
    margin: 0;
    font-size: 1.05rem;
    font-weight: 700;
    color: #111827;
  }

  .section-desc {
    margin: 0.1rem 0 0;
    font-size: 0.72rem;
    color: #6b7280;
    font-weight: 500;
  }

  /* ===== Branch Cards ===== */
  .branch-list {
    display: flex;
    flex-direction: column;
  }

  .branch-card {
    width: 100%;
    background: white;
    border: none;
    border-bottom: 1px solid #f3f4f6;
    padding: 0;
    cursor: pointer;
    transition: background 0.2s ease;
    text-align: inherit;
    font-family: inherit;
  }

  .branch-card:last-child {
    border-bottom: none;
  }

  .branch-card:hover {
    background: #f9fafb;
  }

  .branch-card:active {
    background: #f0fdf4;
  }

  .branch-card.branch-closed {
    opacity: 0.55;
    cursor: not-allowed;
  }

  .branch-card.branch-closed:hover {
    background: white;
  }

  .branch-card-body {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.875rem 1.125rem;
    gap: 0.75rem;
  }

  .branch-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
  }

  .branch-name {
    margin: 0;
    font-size: 0.92rem;
    font-weight: 700;
    color: #1f2937;
    line-height: 1.3;
  }

  .branch-hours {
    font-size: 0.73rem;
    color: #6b7280;
    font-weight: 500;
  }

  .status-closed {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    font-size: 0.68rem;
    color: #dc2626;
    font-weight: 600;
    background: #fef2f2;
    padding: 0.15rem 0.5rem;
    border-radius: 6px;
    width: fit-content;
  }

  .status-closed::before {
    content: '🔒';
    font-size: 0.6rem;
  }

  .branch-distance {
    font-size: 0.7rem;
    color: #2563eb;
    font-weight: 600;
  }

  /* ===== Branch Action ===== */
  .branch-action {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-shrink: 0;
  }

  .action-arrow {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: linear-gradient(135deg, var(--green) 0%, var(--green-light) 100%);
    color: white;
    border-radius: 10px;
    font-size: 1.1rem;
    font-weight: 700;
    transition: all 0.25s ease;
    box-shadow: 0 2px 8px rgba(22, 163, 74, 0.25);
  }

  .branch-card:hover .action-arrow {
    transform: scale(1.1);
    box-shadow: 0 4px 12px rgba(22, 163, 74, 0.35);
  }

  .branch-card.branch-closed .action-arrow {
    background: #d1d5db;
    box-shadow: none;
  }

  /* Directions Link */
  .directions-link {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #eff6ff;
    color: #2563eb;
    border-radius: 10px;
    transition: all 0.25s ease;
    text-decoration: none;
    border: 1px solid #bfdbfe;
  }

  .directions-link:hover {
    background: #2563eb;
    color: white;
    transform: scale(1.1);
    box-shadow: 0 3px 10px rgba(37, 99, 235, 0.35);
  }

  .directions-icon {
    width: 16px;
    height: 16px;
  }

  /* ===== Responsive ===== */
  @media (max-width: 480px) {
    .start-container {
      height: calc(100vh - 60px);
      max-height: calc(100vh - 60px);
      padding-bottom: 70px;
    }

    .hero-header {
      padding: 1.5rem 1rem 1.25rem;
      border-radius: 0 0 24px 24px;
    }

    .logo-container {
      width: 60px;
      height: 60px;
      border-radius: 16px;
    }

    .hero-logo {
      width: 42px;
      height: 42px;
    }

    .hero-title {
      font-size: 1.2rem;
    }

    .hero-subtitle {
      font-size: 0.78rem;
    }

    .sections-wrapper {
      max-width: 100%;
      padding: 0 0.75rem;
    }

    .service-section {
      border-radius: 16px;
    }

    .branch-card-body {
      padding: 0.75rem 0.875rem;
    }
  }

  @media (min-width: 768px) {
    .hero-header {
      border-radius: 0 0 40px 40px;
      padding: 2.5rem 2rem 2rem;
    }

    .logo-container {
      width: 84px;
      height: 84px;
      border-radius: 22px;
    }

    .hero-logo {
      width: 60px;
      height: 60px;
    }

    .hero-title {
      font-size: 1.7rem;
    }

    .hero-subtitle {
      font-size: 0.95rem;
    }

    .sections-wrapper {
      max-width: 480px;
    }
  }
</style>
```
