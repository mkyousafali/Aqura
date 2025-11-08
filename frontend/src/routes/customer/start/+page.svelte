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
    orderFlowActions.setSelection(branch.branch_id, service);
    setTimeout(() => {
      goto('/customer/products');
    }, 100);
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

  function formatHours(branch, type) {
    if (type === 'delivery') {
      if (branch.delivery_is_24_hours) return texts.hours24;
      if (branch.delivery_start_time && branch.delivery_end_time) return `${branch.delivery_start_time} - ${branch.delivery_end_time}`;
    } else {
      if (branch.pickup_is_24_hours) return texts.hours24;
      if (branch.pickup_start_time && branch.pickup_end_time) return `${branch.pickup_start_time} - ${branch.pickup_end_time}`;
    }
    return '';
  }
</script>

<svelte:head><title>{texts.title}</title></svelte:head>

<div class="start-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
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
                  class="service-card" 
                  on:click|stopPropagation={() => chooseService(branch, 'delivery')}
                  type="button"
                >
                  <div class="icon">🚚</div>
                  <div class="content">
                    <h4>{texts.delivery}</h4>
                    <p class="hours">{formatHours(branch, 'delivery')}</p>
                  </div>
                  <div class="arrow">→</div>
                </button>
              {/if}
              {#if branch.pickup_service_enabled}
                <button 
                  class="service-card" 
                  on:click|stopPropagation={() => chooseService(branch, 'pickup')}
                  type="button"
                >
                  <div class="icon">🏪</div>
                  <div class="content">
                    <h4>{texts.pickup}</h4>
                    <p class="hours">{formatHours(branch, 'pickup')}</p>
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
  .start-container { max-width:600px; margin:0 auto; padding:1rem 1rem 140px; }
  .page-title { text-align:center; font-size:1.3rem; margin:0 0 1.5rem; }
  .loading { text-align:center; padding:3rem; color: var(--color-ink-light); }
  .branches-list { display:flex; flex-direction:column; gap:1rem; }
  .branch-card { background:#fff; border:2px solid var(--color-border); border-radius:16px; overflow:hidden; transition:0.3s; }
  .branch-card.expanded { border-color: var(--color-primary); box-shadow:0 4px 12px rgba(0,0,0,0.08); }
  .branch-header { 
    width:100%; 
    display:flex; 
    justify-content:space-between; 
    align-items:center; 
    padding:1rem 1.25rem; 
    background:none; 
    border:none; 
    cursor:pointer;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    position: relative;
    z-index: 1;
  }
  .branch-header:active {
    background: var(--color-surface);
    transform: scale(0.98);
  }
  .branch-header:hover { background: var(--color-surface); }
  .branch-info h3 { margin:0 0 0.5rem; font-size:1rem; pointer-events: none; }
  .service-badges { display:flex; gap:0.5rem; flex-wrap:wrap; pointer-events: none; }
  .badge { padding:0.3rem 0.6rem; border-radius:6px; font-size:0.7rem; font-weight:600; display:inline-flex; align-items:center; gap:0.25rem; pointer-events: none; }
  .badge.delivery { background:#dbeafe; color:#1e40af; }
  .badge.pickup { background:#d1fae5; color:#065f46; }
  .expand { font-size:0.9rem; color: var(--color-ink-light); pointer-events: none; }
  .services { padding:0 1rem 1rem; display:flex; flex-direction:column; gap:0.75rem; animation:fadeIn .25s; }
  @keyframes fadeIn { from { opacity:0; transform: translateY(-6px);} to { opacity:1; transform: translateY(0);} }
  .service-card { 
    display:flex; 
    align-items:center; 
    gap:0.75rem; 
    background: linear-gradient(135deg,#f8fafc,#fff); 
    border:2px solid var(--color-border-light); 
    padding:0.85rem 1rem; 
    border-radius:12px; 
    cursor:pointer; 
    transition: .2s; 
    position:relative; 
    overflow:hidden;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    z-index: 1;
  }
  .service-card:active {
    transform: scale(0.98);
    border-color: var(--color-primary);
  }
  .service-card:hover { border-color: var(--color-primary); box-shadow:0 4px 10px rgba(0,0,0,0.08); transform: translateY(-2px); }
  .icon { font-size:2rem; pointer-events: none; }
  .content { flex:1; pointer-events: none; }
  .content h4 { margin:0 0 .25rem; font-size:0.95rem; }
  .hours { margin:0; font-size:0.7rem; color: var(--color-ink-light); }
  .arrow { font-size:1.2rem; color: var(--color-ink-light); transition:.2s; pointer-events: none; }
  .service-card:hover .arrow { transform: translateX(3px); color: var(--color-primary); }
  @media (max-width:480px){ .start-container{ padding:0.75rem 0.75rem 140px;} }
</style>
