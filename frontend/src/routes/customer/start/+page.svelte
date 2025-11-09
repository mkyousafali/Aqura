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

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) currentLanguage = savedLanguage;
    await loadBranches();
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
      goto('/customer/products');
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
    title: 'اختر الفرع والخدمة',
    selectBranch: 'اختر الفرع',
    services: 'الخدمات المتاحة',
    delivery: 'التوصيل',
    pickup: 'استلام من المتجر',
    loading: 'جاري التحميل...',
    unavailable: 'لا توجد خدمات متاحة',
    hours24: '⏰ يعمل 24/7',
    deliveryHours: 'ساعات التوصيل',
    pickupHours: 'ساعات الاستلام'
  } : {
    title: 'Select Branch & Service',
    selectBranch: 'Select Branch',
    services: 'Available Services',
    delivery: 'Delivery',
    pickup: 'Store Pickup',
    loading: 'Loading...',
    unavailable: 'No services available',
    hours24: '⏰ Open 24/7',
    deliveryHours: 'Delivery Hours',
    pickupHours: 'Pickup Hours'
  };

  function convertTo12Hour(time24) {
    if (!time24) return '';
    
    // Parse the time string (format: HH:MM:SS or HH:MM)
    const parts = time24.split(':');
    let hours = parseInt(parts[0]);
    const minutes = parts[1];
    
    // Determine AM/PM
    const period = hours >= 12 ? 'PM' : 'AM';
    
    // Convert to 12-hour format
    hours = hours % 12;
    hours = hours ? hours : 12; // 0 should be 12
    
    return `${hours}:${minutes} ${period}`;
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

<svelte:head><title>{texts.title}</title></svelte:head>

<div class="start-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
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

  <h1 class="page-title">{texts.title}</h1>

  {#if loading}
    <div class="loading">{texts.loading}</div>
  {:else}
    <div class="branches-list">
      {#each branches as branch}
        <div class="branch-card {selectedBranch?.branch_id === branch.branch_id ? 'expanded' : ''}">
          <button 
            class="branch-header" 
            on:click|stopPropagation={() => toggleBranch(branch)}
            type="button"
          >
            <div class="branch-info">
              <h3>{currentLanguage === 'ar' ? branch.branch_name_ar : branch.branch_name_en}</h3>
              <div class="service-badges">
                {#if branch.delivery_service_enabled}<span class="badge delivery">🚚 {texts.delivery}</span>{/if}
                {#if branch.pickup_service_enabled}<span class="badge pickup">🏪 {texts.pickup}</span>{/if}
              </div>
            </div>
            <div class="expand">{selectedBranch?.branch_id === branch.branch_id ? '▲' : '▼'}</div>
          </button>
          {#if selectedBranch?.branch_id === branch.branch_id}
            <div class="services">
              {#if branch.delivery_service_enabled}
                <button 
                  class="service-card {!isServiceAvailable(branch, 'delivery') ? 'disabled' : ''}" 
                  on:click|stopPropagation={() => chooseService(branch, 'delivery')}
                  type="button"
                >
                  <div class="icon">🚚</div>
                  <div class="content">
                    <h4>{texts.delivery}</h4>
                    <p class="hours">{formatHours(branch, 'delivery')}</p>
                    {#if !isServiceAvailable(branch, 'delivery')}
                      <p class="closed-msg">{currentLanguage === 'ar' ? '🔒 مغلق الآن' : '🔒 Closed Now'}</p>
                    {/if}
                  </div>
                  <div class="arrow">→</div>
                </button>
              {/if}
              {#if branch.pickup_service_enabled}
                <button 
                  class="service-card {!isServiceAvailable(branch, 'pickup') ? 'disabled' : ''}" 
                  on:click|stopPropagation={() => chooseService(branch, 'pickup')}
                  type="button"
                >
                  <div class="icon">🏪</div>
                  <div class="content">
                    <h4>{texts.pickup}</h4>
                    <p class="hours">{formatHours(branch, 'pickup')}</p>
                    {#if !isServiceAvailable(branch, 'pickup')}
                      <p class="closed-msg">{currentLanguage === 'ar' ? '🔒 مغلق الآن' : '🔒 Closed Now'}</p>
                    {/if}
                  </div>
                  <div class="arrow">→</div>
                </button>
              {/if}
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .start-container {
    /* Brand palette derived from logo */
    --brand-green: #16a34a;
    --brand-green-dark: #15803d;
    --brand-green-light: #22c55e;
    --brand-orange: #f59e0b;
    --brand-orange-dark: #d97706;
    --brand-orange-light: #fbbf24;

    /* Remap app variables */
    --color-primary: var(--brand-green);
    --color-primary-dark: var(--brand-green-dark);
    --color-accent: var(--brand-orange);

    width: 100%;
    margin: 0 auto;
    padding: 0.375rem 0.375rem 75px; /* 25% reduction from 0.5rem 0.5rem 100px */
    min-height: 100vh;
    height: calc(100vh - 45px);
    max-height: calc(100vh - 45px);
    position: relative;
    overflow-x: hidden;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    touch-action: pan-y;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    align-items: center;

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

  /* Individual bubble animations and positions - BIGGER SIZES */
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

  .page-title {
    text-align: center;
    font-size: 0.975rem; /* 25% reduction from 1.3rem */
    margin: 0 0 1.125rem; /* 25% reduction from 1.5rem */
    color: #1f2937 !important; /* Dark gray instead of white/green */
    font-weight: 700;
    text-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
    position: relative;
    z-index: 10;
  }

  .loading {
    text-align: center;
    padding: 2.25rem; /* 25% reduction from 3rem */
    color: #ffffff;
    font-weight: 600;
    position: relative;
    z-index: 10;
  }

  .branches-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem; /* 25% reduction from 1rem */
    position: relative;
    z-index: 10;
    width: 100%;
    max-width: 360px; /* 25% reduction from 480px */
    margin: 0 auto;
  }

  .branch-card {
    background: rgba(255, 255, 255, 0.95);
    border: 1.5px solid rgba(22, 163, 74, 0.2); /* 25% reduction from 2px */
    border-radius: 12px; /* 25% reduction from 16px */
    overflow: hidden;
    transition: all 0.3s ease;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.15); /* 25% reduction from 0 8px 24px */
    backdrop-filter: blur(7.5px); /* 25% reduction from 10px */
    box-sizing: border-box;
    position: relative;
  }

  .branch-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(90deg, var(--brand-green) 0%, var(--brand-orange) 100%);
    opacity: 0;
    transition: opacity 0.3s ease;
  }

  .branch-card:hover::before {
    opacity: 1;
  }

  .branch-card.expanded {
    border-color: var(--brand-green);
    box-shadow: 0 8px 24px rgba(22, 163, 74, 0.25), 0 0 0 3px rgba(22, 163, 74, 0.1);
    transform: translateY(-2px);
  }

  .branch-card.expanded::before {
    opacity: 1;
  }

  .branch-header {
    width: 100%;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 0.9375rem; /* 25% reduction from 1rem 1.25rem */
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.02) 0%, transparent 100%);
    border: none;
    cursor: pointer;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    position: relative;
    z-index: 1;
    transition: all 0.3s ease;
  }

  .branch-header:active {
    background: rgba(22, 163, 74, 0.08);
    transform: scale(0.98);
  }

  .branch-header:hover {
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.05) 0%, rgba(245, 158, 11, 0.02) 100%);
  }

  .branch-info {
    flex: 1;
  }

  .branch-info h3 {
    margin: 0 0 0.375rem; /* 25% reduction from 0.5rem */
    font-size: 0.75rem; /* 25% reduction from 1rem */
    pointer-events: none;
    color: var(--brand-green);
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 0.375rem;
  }

  .branch-info h3::before {
    content: '🏪';
    font-size: 0.9rem;
    filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.1));
  }

  .service-badges {
    display: flex;
    gap: 0.375rem; /* 25% reduction from 0.5rem */
    flex-wrap: wrap;
    pointer-events: none;
  }

  .badge {
    padding: 0.225rem 0.45rem; /* 25% reduction from 0.3rem 0.6rem */
    border-radius: 4.5px; /* 25% reduction from 6px */
    font-size: 0.525rem; /* 25% reduction from 0.7rem */
    font-weight: 600;
    display: inline-flex;
    align-items: center;
    gap: 0.1875rem; /* 25% reduction from 0.25rem */
    pointer-events: none;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    transition: transform 0.2s ease;
  }

  .branch-card:hover .badge {
    transform: translateY(-1px);
  }

  .badge.delivery {
    background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
    color: #1e40af;
    border: 1px solid #93c5fd;
  }

  .badge.pickup {
    background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
    color: #065f46;
    border: 1px solid #6ee7b7;
  }

  .expand {
    font-size: 0.675rem; /* 25% reduction from 0.9rem */
    color: var(--brand-green);
    pointer-events: none;
    font-weight: 700;
    transition: all 0.3s ease;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.1) 0%, rgba(245, 158, 11, 0.1) 100%);
    padding: 0.3rem 0.5rem;
    border-radius: 50%;
    width: 1.2rem;
    height: 1.2rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .branch-card.expanded .expand {
    transform: rotate(180deg);
    background: linear-gradient(135deg, var(--brand-green) 0%, var(--brand-green-light) 100%);
    color: white;
    box-shadow: 0 2px 6px rgba(22, 163, 74, 0.3);
  }

  .services {
    padding: 0 0.75rem 0.75rem; /* 25% reduction from 0 1rem 1rem */
    display: flex;
    flex-direction: column;
    gap: 0.5625rem; /* 25% reduction from 0.75rem */
    animation: fadeIn 0.25s;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(-4.5px); /* 25% reduction from -6px */
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .service-card {
    display: flex;
    align-items: center;
    gap: 0.5625rem; /* 25% reduction from 0.75rem */
    background: linear-gradient(135deg, rgba(255, 255, 255, 0.95), rgba(248, 250, 252, 0.95));
    border: 1.5px solid rgba(22, 163, 74, 0.2); /* 25% reduction from 2px */
    padding: 0.6375rem 0.75rem; /* 25% reduction from 0.85rem 1rem */
    border-radius: 9px; /* 25% reduction from 12px */
    cursor: pointer;
    transition: 0.2s;
    position: relative;
    overflow: hidden;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    z-index: 1;
    box-shadow: 0 3px 7.5px rgba(0, 0, 0, 0.08); /* 25% reduction from 0 4px 10px */
  }

  .service-card.disabled {
    background: linear-gradient(135deg, rgba(200, 200, 200, 0.5), rgba(220, 220, 220, 0.5));
    border-color: rgba(150, 150, 150, 0.3);
    cursor: not-allowed;
    opacity: 0.6;
  }

  .service-card.disabled:hover {
    transform: none;
    box-shadow: 0 3px 7.5px rgba(0, 0, 0, 0.08);
    border-color: rgba(150, 150, 150, 0.3);
  }

  .service-card.disabled .icon {
    opacity: 0.5;
  }

  .service-card.disabled .arrow {
    opacity: 0.3;
  }

  .service-card:active {
    transform: scale(0.98);
    border-color: var(--brand-green);
  }

  .service-card.disabled:active {
    transform: none;
  }

  .service-card:hover {
    border-color: var(--brand-green);
    box-shadow: 0 6px 15px rgba(22, 163, 74, 0.25); /* Enhanced shadow */
    transform: translateY(-1.5px) scale(1.02); /* 25% reduction from -2px with scale */
    background: linear-gradient(135deg, rgba(255, 255, 255, 1), rgba(22, 163, 74, 0.05));
  }

  .icon {
    font-size: 1.5rem; /* 25% reduction from 2rem */
    pointer-events: none;
    transition: transform 0.3s ease;
    filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.1));
  }

  .service-card:hover .icon {
    transform: scale(1.15) rotate(5deg);
  }

  .content {
    flex: 1;
    pointer-events: none;
  }

  .content h4 {
    margin: 0 0 0.1875rem; /* 25% reduction from 0.25rem */
    font-size: 0.7125rem; /* 25% reduction from 0.95rem */
    color: var(--brand-green);
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  .content h4::after {
    content: '✓';
    font-size: 0.6rem;
    color: var(--brand-orange);
    opacity: 0;
    transition: opacity 0.3s ease;
  }

  .service-card:hover .content h4::after {
    opacity: 1;
  }

  .hours {
    margin: 0;
    font-size: 0.525rem; /* 25% reduction from 0.7rem */
    color: var(--color-ink-light);
    font-weight: 500;
  }

  .closed-msg {
    margin: 0.1875rem 0 0 0;
    font-size: 0.5rem;
    color: #dc2626;
    font-weight: 600;
  }

  .arrow {
    font-size: 0.9rem; /* 25% reduction from 1.2rem */
    color: var(--brand-green);
    transition: all 0.3s ease;
    pointer-events: none;
    font-weight: 700;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.1) 0%, transparent 100%);
    padding: 0.3rem;
    border-radius: 50%;
    width: 1.2rem;
    height: 1.2rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .service-card:hover .arrow {
    transform: translateX(3px) scale(1.2); /* Enhanced movement */
    color: white;
    background: linear-gradient(135deg, var(--brand-orange) 0%, var(--brand-orange-light) 100%);
    box-shadow: 0 2px 6px rgba(245, 158, 11, 0.4);
  }

  @media (max-width: 480px) {
    .start-container {
      padding: 0.375rem 0.375rem 60px; /* 25% reduction from 0.5rem 0.5rem 80px */
      height: calc(100vh - 60px);
      max-height: calc(100vh - 60px);
    }

    /* Smaller bubbles on mobile */
    .bubble {
      transform: scale(0.6);
      box-shadow: 
        inset -3px -3px 6px rgba(255, 255, 255, 0.4),
        inset 3px 3px 6px rgba(0, 0, 0, 0.1),
        0 0 8px rgba(255, 255, 255, 0.3);
    }

    .page-title {
      font-size: 0.825rem; /* Further reduction for mobile */
    }

    .branches-list {
      max-width: 100%;
      padding: 0 0.25rem;
    }

    .branch-card {
      border-radius: 10.5px; /* 25% reduction from 14px */
    }

    .branch-header {
      padding: 0.5625rem 0.75rem; /* Further reduction for mobile */
    }

    .branch-info h3 {
      font-size: 0.675rem; /* Further reduction for mobile */
    }
  }

  @media (min-width: 768px) {
    .start-container {
      padding: 1.5rem 1.5rem 90px; /* 25% reduction from 2rem 2rem 120px */
    }

    .page-title {
      font-size: 1.125rem; /* 25% reduction from 1.5rem */
    }

    .branch-card {
      border-radius: 18px; /* 25% reduction from 24px */
    }
  }
</style>
