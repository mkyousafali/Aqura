<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { orderFlow } from '$lib/stores/orderFlow.js';
  import { supabase } from '$lib/utils/supabase';
  import { iconUrlMap } from '$lib/stores/iconStore';

  let currentLanguage = 'ar';
  $: flow = $orderFlow;

  let categories = [];
  let loading = true;

  // Language texts
  $: texts = currentLanguage === 'ar' ? {
    title: 'الأقسام',
    subtitle: 'اختر القسم لتصفح المنتجات',
    allProducts: 'جميع المنتجات',
    back: 'رجوع',
    loading: 'جاري التحميل...',
    noCategories: 'لا توجد أقسام حالياً',
  } : {
    title: 'Categories',
    subtitle: 'Choose a category to browse products',
    allProducts: 'All Products',
    back: 'Back',
    loading: 'Loading...',
    noCategories: 'No categories available',
  };

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) currentLanguage = savedLanguage;

    // Ensure branch is selected
    if (!flow?.branchId || !flow?.fulfillment) {
      goto('/customer-interface/start');
      return;
    }

    await loadCategories();

    const onStorage = (e) => { if (e.key === 'language') currentLanguage = e.newValue || 'ar'; };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  });

  async function loadCategories() {
    loading = true;
    try {
      // First get distinct category IDs that have customer-enabled products
      const { data: products, error: pErr } = await supabase
        .from('products')
        .select('category_id')
        .eq('is_active', true)
        .eq('is_customer_product', true);
      if (pErr) throw pErr;

      const activeCategoryIds = [...new Set((products || []).map(p => p.category_id).filter(Boolean))];
      if (activeCategoryIds.length === 0) {
        categories = [];
        return;
      }

      const { data, error } = await supabase
        .from('product_categories')
        .select('id, name_en, name_ar, image_url')
        .eq('is_active', true)
        .in('id', activeCategoryIds)
        .order('display_order')
        .order('name_en');
      if (error) throw error;
      categories = data || [];
    } catch (err) {
      console.error('Failed to load categories:', err);
      categories = [];
    } finally {
      loading = false;
    }
  }

  function selectCategory(categoryId) {
    goto(`/customer-interface/products?category=${categoryId}`);
  }

  function viewAllProducts() {
    goto('/customer-interface/products');
  }

  function goBack() {
    goto('/customer-interface/start');
  }
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="categories-page" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Soft ambient background shapes -->
  <div class="ambient-bg">
    <div class="ambient-shape shape-1"></div>
    <div class="ambient-shape shape-2"></div>
    <div class="ambient-shape shape-3"></div>
  </div>

  <!-- Hero Header -->
  <header class="hero-header">
    <button class="back-btn" on:click={goBack} type="button" aria-label={texts.back}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
        <path d="M19 12H5M12 19l-7-7 7-7" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </button>
    <div class="logo-container">
      <img src={$iconUrlMap['logo'] || '/icons/logo.png'} alt="Urban Market" class="hero-logo" />
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
    <div class="content-wrapper">
      <!-- All Products Button -->
      <button class="all-products-btn" on:click={viewAllProducts} type="button">
        <span class="btn-icon">🛍️</span>
        <span>{texts.allProducts}</span>
        <svg class="btn-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <path d="M5 12h14M12 5l7 7-7 7" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>

      <!-- Categories Grid -->
      {#if categories.length > 0}
        <div class="categories-grid">
          {#each categories as category}
            <button
              class="category-card"
              on:click={() => selectCategory(category.id)}
              type="button"
            >
              {#if category.image_url}
                <img src={category.image_url} alt="" class="category-img" />
              {:else}
                <span class="category-icon">📦</span>
              {/if}
              <h3>{currentLanguage === 'ar' ? category.name_ar : category.name_en}</h3>
            </button>
          {/each}
        </div>
      {:else}
        <div class="empty-state">
          <span class="empty-icon">📭</span>
          <p>{texts.noCategories}</p>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  /* ===== Brand ===== */
  :root {
    --green: #16a34a;
    --green-dark: #15803d;
    --green-light: #22c55e;
  }

  /* ===== Page Container ===== */
  .categories-page {
    position: relative;
    width: 100%;
    min-height: calc(100vh - 45px);
    overflow-x: hidden;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    background: #f8fafc;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding-bottom: 2rem;
  }

  /* ===== Ambient Background ===== */
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
    opacity: 0.18;
    filter: blur(60px);
  }

  .shape-1 { width: 260px; height: 260px; background: #4ade80; top: -80px; right: -40px; animation: drift 20s ease-in-out infinite alternate; }
  .shape-2 { width: 220px; height: 220px; background: #fbbf24; bottom: 10%; left: -60px; animation: drift 25s ease-in-out infinite alternate-reverse; }
  .shape-3 { width: 200px; height: 200px; background: #86efac; top: 40%; right: 20%; animation: drift 18s ease-in-out infinite alternate; }

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
    padding: 1.75rem 1.5rem 1.25rem;
    background: linear-gradient(170deg, var(--green) 0%, var(--green-dark) 100%);
    border-radius: 0 0 32px 32px;
    box-shadow: 0 8px 32px rgba(22, 163, 74, 0.3);
  }

  .back-btn {
    position: absolute;
    top: 1rem;
    left: 1rem;
    width: 36px;
    height: 36px;
    background: rgba(255, 255, 255, 0.2);
    border: none;
    border-radius: 10px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
    z-index: 20;
  }

  [dir="rtl"] .back-btn {
    left: auto;
    right: 1rem;
  }

  [dir="rtl"] .back-btn svg {
    transform: scaleX(-1);
  }

  .back-btn svg {
    width: 20px;
    height: 20px;
    color: white;
  }

  .back-btn:active { background: rgba(255, 255, 255, 0.35); }

  .logo-container {
    width: 64px;
    height: 64px;
    background: white;
    border-radius: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.15);
    margin-bottom: 0.6rem;
    animation: logoEntry 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  @keyframes logoEntry {
    0% { opacity: 0; transform: scale(0.5) translateY(20px); }
    100% { opacity: 1; transform: scale(1) translateY(0); }
  }

  .hero-logo {
    width: 46px;
    height: 46px;
    object-fit: contain;
  }

  .hero-title {
    margin: 0;
    font-size: 1.35rem;
    font-weight: 800;
    color: white;
    text-align: center;
    line-height: 1.3;
  }

  .hero-subtitle {
    margin: 0.3rem 0 0;
    font-size: 0.82rem;
    color: rgba(255, 255, 255, 0.85);
    font-weight: 500;
    text-align: center;
  }

  /* ===== Loading ===== */
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

  @keyframes spin { to { transform: rotate(360deg); } }

  /* ===== Content ===== */
  .content-wrapper {
    position: relative;
    z-index: 10;
    width: 100%;
    max-width: 420px;
    padding: 1rem 1rem 0;
  }

  /* ===== All Products Button ===== */
  .all-products-btn {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.6rem;
    padding: 0.9rem 1.5rem;
    background: linear-gradient(135deg, var(--green) 0%, var(--green-light) 100%);
    color: white;
    border: none;
    border-radius: 14px;
    font-size: 1.05rem;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 4px 16px rgba(22, 163, 74, 0.25);
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    margin-bottom: 1rem;
    position: relative;
    overflow: hidden;
  }

  .all-products-btn::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.25), transparent);
    animation: shimmer 3s infinite;
  }

  @keyframes shimmer {
    0% { left: -100%; }
    100% { left: 100%; }
  }

  .all-products-btn:active { transform: scale(0.97); }
  .all-products-btn:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(22, 163, 74, 0.35); }

  .btn-icon { font-size: 1.3rem; }

  .btn-arrow {
    width: 18px;
    height: 18px;
    flex-shrink: 0;
  }

  /* ===== Categories Grid ===== */
  .categories-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }

  .category-card {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1.25rem 0.75rem;
    background: white;
    border: 1.5px solid transparent;
    border-radius: 18px;
    cursor: pointer;
    transition: all 0.25s ease;
    text-decoration: none;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.06);
    min-height: 110px;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
    -webkit-tap-highlight-color: transparent;
    position: relative;
    overflow: hidden;
  }

  .category-card::before {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(135deg, rgba(22, 163, 74, 0.04) 0%, rgba(245, 158, 11, 0.04) 100%);
    opacity: 0;
    transition: opacity 0.25s ease;
    border-radius: 18px;
  }

  .category-card:hover::before,
  .category-card:active::before { opacity: 1; }

  .category-card:hover {
    border-color: var(--green);
    transform: translateY(-3px);
    box-shadow: 0 6px 20px rgba(22, 163, 74, 0.15);
  }

  .category-card:active { transform: translateY(-1px) scale(0.98); }

  .category-icon {
    font-size: 2.75rem;
    margin-bottom: 0.5rem;
    filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.08));
    transition: transform 0.25s ease;
  }

  .category-img {
    width: 56px;
    height: 56px;
    object-fit: contain;
    margin-bottom: 0.5rem;
    border-radius: 10px;
    transition: transform 0.25s ease;
  }

  .category-card:hover .category-icon,
  .category-card:hover .category-img { transform: scale(1.12) rotate(3deg); }

  .category-card h3 {
    font-size: 0.85rem;
    font-weight: 600;
    color: #1f2937;
    text-align: center;
    line-height: 1.3;
    margin: 0;
  }

  /* ===== Empty State ===== */
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.75rem;
    padding: 3rem 1rem;
    text-align: center;
  }

  .empty-icon { font-size: 3rem; opacity: 0.5; }
  .empty-state p { margin: 0; color: #9ca3af; font-weight: 500; font-size: 0.9rem; }

  /* ===== Mobile ===== */
  @media (max-width: 480px) {
    .hero-header {
      padding: 1.25rem 1rem 1rem;
      border-radius: 0 0 24px 24px;
    }

    .logo-container { width: 56px; height: 56px; border-radius: 16px; }
    .hero-logo { width: 40px; height: 40px; }
    .hero-title { font-size: 1.15rem; }

    .content-wrapper { padding: 0.75rem 0.75rem 0; }

    .category-card { min-height: 100px; padding: 1rem 0.5rem; }
    .category-icon { font-size: 2.25rem; }
    .category-card h3 { font-size: 0.8rem; }
  }

  /* ===== Tablet+ ===== */
  @media (min-width: 768px) {
    .categories-page { max-width: 600px; margin: 0 auto; }

    .hero-header {
      border-radius: 0 0 40px 40px;
      padding: 2rem 2rem 1.5rem;
    }

    .categories-grid {
      grid-template-columns: repeat(3, 1fr);
      gap: 1rem;
    }

    .category-card { min-height: 130px; padding: 1.5rem 1rem; }
    .category-icon { font-size: 3rem; }
    .category-card h3 { font-size: 0.95rem; }
  }

  @media (min-width: 1024px) {
    .categories-grid { grid-template-columns: repeat(4, 1fr); }
  }
</style>
