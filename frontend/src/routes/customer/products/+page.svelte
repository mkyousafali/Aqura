<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { cartActions, cartStore } from '$lib/stores/cart.js';
  import { scrollingContent, scrollingContentActions } from '$lib/stores/scrollingContent.js';
  import { orderFlow } from '$lib/stores/orderFlow.js';
  import { supabase } from '$lib/utils/supabase';

  let currentLanguage = 'ar';
  $: flow = $orderFlow;

  let searchQuery = '';
  let showSearch = false;

  let selectedCategory = 'all';
  let selectedUnits = new Map();
  let categoryTabsContainer;

  let products = [];
  let categories = [];
  let loading = true;

  let showCategoryMenu = false;

  onMount(async () => {
    const saved = flow;
    if (!saved?.branchId || !saved?.fulfillment) {
      try { goto('/customer/start'); } catch (e) { console.error(e); }
    }
    await loadCategories();
    await loadProducts();
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) currentLanguage = savedLanguage;
    const onStorage = (e) => { if (e.key === 'language') currentLanguage = e.newValue || 'ar'; };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  });

  // cart
  $: cartItems = $cartStore;
  $: cartItemsMap = new Map(cartItems.map(item => [
    `${item.id}-${item.selectedUnit?.id || 'base'}`,
    item.quantity
  ]));
  
  // Create a reactive key that changes when any quantity changes
  $: cartKey = cartItems.map(item => `${item.id}-${item.selectedUnit?.id}-${item.quantity}`).join(',');
  
  function getItemQuantity(product) {
    const u = getSelectedUnit(product);
    return cartItemsMap.get(`${product.id}-${u.id}`) || 0;
  }

  // banners
  $: currentScrollingContent = $scrollingContent;
  $: activeScrollingTexts = scrollingContentActions.getActiveContent(currentScrollingContent, currentLanguage);

  // categories
  async function loadCategories() {
    try {
      const { data, error } = await supabase
        .from('product_categories')
        .select('id, name_en, name_ar')
        .eq('is_active', true)
        .order('name_en');
      if (error) throw error;
      categories = [{ id: 'all', name_en: 'All', name_ar: 'الكل' }, ...(data || [])];
    } catch {
      categories = [{ id: 'all', name_en: 'All', name_ar: 'الكل' }];
    }
  }

  // products
  async function loadProducts() {
    loading = true;
    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .eq('is_active', true)
        .order('product_name_en');
      if (error) throw error;

      const productMap = new Map();
      (data || []).forEach(row => {
        if (!productMap.has(row.product_serial)) {
          productMap.set(row.product_serial, {
            id: row.product_serial,
            nameEn: row.product_name_en,
            nameAr: row.product_name_ar,
            category: row.category_id,
            categoryNameEn: row.category_name_en,
            categoryNameAr: row.category_name_ar,
            image: row.image_url,
            units: []
          });
        }
        const p = productMap.get(row.product_serial);
        p.units.push({
          id: row.id,
          nameEn: `${row.unit_qty} ${row.unit_name_en}`,
          nameAr: `${row.unit_qty} ${row.unit_name_ar}`,
          unitEn: row.unit_name_en,
          unitAr: row.unit_name_ar,
          basePrice: parseFloat(row.sale_price),
          originalPrice: row.cost > 0 ? parseFloat(row.cost) : null,
          stock: row.current_stock,
          lowStockThreshold: row.minimum_qty_alert,
          barcode: row.barcode,
          unitQty: row.unit_qty,
          image: row.image_url
        });
      });

      products = Array.from(productMap.values()).map(product => {
        const sorted = product.units.sort((a, b) => a.unitQty - b.unitQty);
        return { ...product, baseUnit: sorted[0], additionalUnits: sorted.slice(1) };
      });

      products.forEach(p => selectedUnits.set(p.id, p.baseUnit));
      selectedUnits = selectedUnits;
    } catch {
      products = [];
    } finally {
      loading = false;
    }
  }

  function selectCategory(id) {
    selectedCategory = id;
    showCategoryMenu = false;
    if (categoryTabsContainer) {
      const activeTab = categoryTabsContainer.querySelector('.category-tab.active');
      if (activeTab) activeTab.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
    }
  }

  function getSelectedUnit(product) { return selectedUnits.get(product.id) || product.baseUnit; }

  // filters
  $: filteredProducts = products.filter(p => {
    const q = (searchQuery || '').toLowerCase();
    const matchesSearch = !q || p.nameAr.toLowerCase().includes(q) || p.nameEn.toLowerCase().includes(q);
    const matchesCat = selectedCategory === 'all' || p.category === selectedCategory;
    return matchesSearch && matchesCat;
  });

  // cart ops
  function addToCart(product) {
    const u = getSelectedUnit(product);
    cartActions.addToCart(product, u, 1);
  }
  function updateQuantity(product, d) {
    const u = getSelectedUnit(product);
    const cur = cartActions.getItemQuantity(product.id, u.id);
    const next = Math.max(0, cur + d);
    if (next === 0) cartActions.removeFromCart(product.id, u.id);
    else cartActions.updateQuantity(product.id, u.id, next);
  }

  // i18n
  $: texts = currentLanguage === 'ar' ? {
    title: 'المنتجات - أكوا إكسبرس',
    search: 'ابحث عن منتج...',
    categories: 'الفئات',
    close: 'إغلاق',
    addToCart: 'أضف للسلة',
    sar: 'ر.س',
    inStock: 'متوفر',
    lowStock: 'كمية قليلة',
    outOfStock: 'نفد المخزون',
    unit: 'وحدة'
  } : {
    title: 'Products - Aqua Express',
    search: 'Search products...',
    categories: 'Categories',
    close: 'Close',
    addToCart: 'Add to Cart',
    sar: 'SAR',
    inStock: 'In Stock',
    lowStock: 'Low Stock',
    outOfStock: 'Out of Stock',
    unit: 'Unit'
  };
</script>

<svelte:head><title>{texts.title}</title></svelte:head>

<div class="page" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
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
  <!-- sticky, touch-scroll categories + left menu button + search button -->
  <div class="top">
    <div class="category-row">
      <button class="cat-menu-btn" type="button" aria-haspopup="dialog" aria-expanded={showCategoryMenu}
        on:click={() => (showCategoryMenu = true)} title={texts.categories}>☰</button>

      <div class="category-tabs" bind:this={categoryTabsContainer}>
        {#each categories as category}
          <button
            class="category-tab"
            class:active={selectedCategory === category.id}
            on:click={() => selectCategory(category.id)}
            type="button"
            role="tab"
            aria-selected={selectedCategory === category.id}
          >
            {currentLanguage === 'ar' ? category.name_ar : category.name_en}
          </button>
        {/each}
      </div>

      <button class="search-btn" aria-expanded={showSearch} on:click={() => (showSearch = !showSearch)} aria-label="Search" title="Search">🔎</button>
    </div>
  </div>

  <!-- PRODUCTS: Grid 2-up on phones -->
  <div class="products-wrap">
    {#each filteredProducts as product}
      {#key `${cartKey}-${selectedUnits.get(product.id)?.id || 'default'}`}
        {@const u = getSelectedUnit(product)}
        {@const qty = getItemQuantity(product)}
        {@const hasDiscount = u.originalPrice && u.originalPrice > u.basePrice}
        {@const isLow = u.stock <= u.lowStockThreshold}
        {@const out = u.stock === 0}

        <div class="product-card">
          <div class="product-image">
            {#if u.image}
              <img src={u.image} alt={currentLanguage === 'ar' ? product.nameAr : product.nameEn} />
            {:else if product.image}
              <img src={product.image} alt={currentLanguage === 'ar' ? product.nameAr : product.nameEn} />
            {:else}
              <div class="image-placeholder">📦</div>
            {/if}
            {#if hasDiscount}
              <div class="discount-badge">
                -{Math.round(((u.originalPrice - u.basePrice) / u.originalPrice) * 100)}%
              </div>
            {/if}
          </div>

          <div class="product-info">
            <h3 class="product-name">{currentLanguage === 'ar' ? product.nameAr : product.nameEn}</h3>

            {#if product.additionalUnits && product.additionalUnits.length > 0}
              <div class="unit-selector">
                <select
                  class="unit-dropdown"
                  value={u.id}
                  on:change={(e) => {
                    const all = [product.baseUnit, ...product.additionalUnits];
                    const nu = all.find(x => x.id === e.target.value);
                    if (nu) { 
                      selectedUnits.set(product.id, nu); 
                      selectedUnits = selectedUnits; 
                    }
                  }}
                >
                  <option value={product.baseUnit.id}>{currentLanguage === 'ar' ? product.baseUnit.nameAr : product.baseUnit.nameEn}</option>
                  {#each product.additionalUnits as unit}
                    <option value={unit.id}>{currentLanguage === 'ar' ? unit.nameAr : unit.nameEn}</option>
                  {/each}
                </select>
              </div>
            {:else}
              <div class="unit-info"><span class="unit-size">{currentLanguage === 'ar' ? u.nameAr : u.nameEn}</span></div>
            {/if}

            <div class="price-row">
              <div class="price-now">{u.basePrice.toFixed(2)} <span class="currency">{texts.sar}</span></div>
              {#if hasDiscount}<div class="price-old">{u.originalPrice.toFixed(2)} {texts.sar}</div>{/if}
            </div>

            <div class="stock-line">
              {#if out}<span class="stock out">{texts.outOfStock}</span>
              {:else if isLow}<span class="stock low">{texts.lowStock}</span>
              {:else}<span class="stock in">{texts.inStock}</span>{/if}
            </div>

            <div class="cart-controls">
              {#if qty === 0}
                <button class="fab-add" on:click={() => addToCart(product)} disabled={out} type="button" aria-label={texts.addToCart} title={texts.addToCart}>+</button>
              {:else}
                <div class="qty-pill">
                  <button class="pill-btn" on:click={() => updateQuantity(product, -1)} aria-label="Decrease">−</button>
                  <span class="pill-q">{qty}</span>
                  <button class="pill-btn" on:click={() => updateQuantity(product, 1)} aria-label="Increase" disabled={out}>+</button>
                </div>
              {/if}
            </div>
          </div>
        </div>
      {/key}
    {/each}
  </div>

  {#if !loading && filteredProducts.length === 0}
    <div class="no-products">
      <div class="no-products-icon">📦</div>
      <div class="no-products-text">{currentLanguage === 'ar' ? 'لا توجد منتجات مطابقة' : 'No matching products found'}</div>
    </div>
  {/if}

  <!-- Search slide -->
  <div class="search-slide" class:open={showSearch}>
    <input type="text" class="search-input" placeholder={texts.search} bind:value={searchQuery} autofocus={showSearch} />
    <button class="close-search" on:click={() => (showSearch = false)} aria-label={texts.close}>✕</button>
  </div>

  <!-- Category modal -->
  {#if showCategoryMenu}
    <div class="modal-backdrop" role="dialog" aria-modal="true" on:click={() => (showCategoryMenu = false)}>
      <div class="modal-panel" on:click|stopPropagation>
        <div class="modal-header">
          <strong>{texts.categories}</strong>
          <button class="modal-close" on:click={() => (showCategoryMenu = false)} aria-label={texts.close}>✕</button>
        </div>
        <div class="modal-body">
          {#each categories as category}
            <button class="modal-cat" class:active={selectedCategory === category.id} on:click={() => selectCategory(category.id)}>
              {currentLanguage === 'ar' ? category.name_ar : category.name_en}
            </button>
          {/each}
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  :root{
    --surface:#ffffff; --bg:#f7f7f8; --ink:#1a1a1a; --ink-2:#5a5a5a; --ink-3:#9aa0a6;
    --primary:#16a34a; --primary-700:#15803d; --danger:#e11d48; --warn:#f59e0b; --ok:#10b981; --border:#e6e7ea;
  }

  .page{ 
    max-width: 1200px; 
    width: 100%;
    margin: 0 auto; 
    padding: .5rem .5rem 120px; 
    min-height: 100vh; 
    background: #f8fafc; 
    box-sizing: border-box;
    overflow-x: hidden;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    touch-action: pan-y;
    position: relative;
  }

  /* Floating bubbles container */
  .floating-bubbles {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    pointer-events: none;
    z-index: 0;
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

  /* Individual bubble animations and positions */
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

  .top{ position:sticky; top:0; z-index:20; background:#f8fafc; padding:.25rem 0 .5rem; }
  .category-row{ display:flex; align-items:center; gap:.5rem; }
  .cat-menu-btn{ width:34px; height:34px; flex:0 0 34px; border-radius:10px; border:1.5px solid var(--border); background:var(--surface); cursor:pointer; font-weight:700; font-size:1rem; }
  .search-btn{ width:34px; height:34px; flex:0 0 34px; border-radius:10px; border:1.5px solid var(--border); background:var(--surface); cursor:pointer; font-size:1rem; }

  .category-tabs{ display:flex; gap:.4rem; overflow-x:auto; scrollbar-width:none; -ms-overflow-style:none; padding:.2rem 0; flex:1; }
  .category-tabs::-webkit-scrollbar{ display:none; }
  .category-tab{ padding:.45rem .85rem; background:var(--surface); border:1.5px solid var(--border); border-radius:999px; white-space:nowrap; color:var(--ink); cursor:pointer; transition:.2s; font-weight:600; font-size:.85rem; flex-shrink:0; }
  .category-tab:hover{ border-color:var(--primary); color:var(--primary); }
  .category-tab.active{ background:var(--primary); color:#fff; border-color:var(--primary); }

  /* ===== GRID LAYOUT (2-up on phones like Al Baik) ===== */
  .products-wrap{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    width: 100%;
    max-width: 100%;
    box-sizing: border-box;
    position: relative;
    z-index: 5;
  }
  
  .product-card{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    overflow: visible;
    display: flex;
    flex-direction: column;
    box-shadow: 0 1px 3px rgba(0,0,0,.08);
    width: 100%;
    max-width: 100%;
    box-sizing: border-box;
    position: relative;
    z-index: 10;
  }

  /* Responsive column counts */
  @media (min-width:600px){ .products-wrap{ grid-template-columns: 1fr 1fr 1fr; gap: 12px; } }
  @media (min-width:900px){ .products-wrap{ grid-template-columns: 1fr 1fr 1fr 1fr; } }
  @media (min-width:1200px){ .products-wrap{ grid-template-columns: 1fr 1fr 1fr 1fr 1fr; } }

  /* Image area */
  .product-image{ 
    position: relative;
    width: 100%;
    max-width: 100%;
    aspect-ratio: 1 / 1;
    background: #f5f5f5;
    overflow: hidden;
    box-sizing: border-box;
  }
  .product-image img{ 
    display: block;
    width: 100%;
    height: 100%;
    max-width: 100%;
    object-fit: cover;
  }

  .image-placeholder{ 
    position: absolute; 
    inset: 0; 
    display: flex; 
    align-items: center; 
    justify-content: center; 
    font-size: 2.5rem; 
    color: #d1d5db; 
  }
  .discount-badge{ 
    position: absolute; 
    top: .5rem; 
    inset-inline-end: .5rem; 
    background: var(--danger); 
    color: #fff; 
    padding: .2rem .4rem; 
    border-radius: 6px; 
    font-size: .7rem; 
    font-weight: 700; 
  }

  .product-info{ 
    padding: .6rem .65rem .7rem; 
    display: flex; 
    flex-direction: column; 
    gap: .4rem; 
    flex: 1;
    position: relative;
    z-index: 1;
  }
  .product-name{ 
    margin: 0; 
    color: var(--ink); 
    font-weight: 700; 
    font-size: .875rem; 
    line-height: 1.25; 
    display: -webkit-box; 
    -webkit-line-clamp: 2; 
    -webkit-box-orient: vertical; 
    overflow: hidden; 
    min-height: 2.5em; 
  }

  .unit-info{ margin-top: .02rem; }
  .unit-size{ 
    font-size: .7rem; 
    color: var(--ink-2); 
    background: #f5f6f7; 
    padding: .15rem .35rem; 
    border-radius: 999px; 
    display: inline-block; 
  }
  .unit-selector{ 
    margin-top: .02rem; 
    position: relative;
    z-index: 1;
  }
  .unit-dropdown{
    width: 100%; 
    padding: .4rem .65rem; 
    font-size: .75rem; 
    color: var(--ink);
    background: #fff; 
    border: 1px solid var(--border); 
    border-radius: 8px; 
    appearance: none;
    -webkit-appearance: none;
    -moz-appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23666' d='M6 9L1 4h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat; 
    background-position: right .5rem center; 
    padding-right: 1.5rem;
    cursor: pointer;
    touch-action: manipulation;
    pointer-events: auto;
    position: relative;
    z-index: 2;
  }
  .unit-dropdown:focus{
    outline: none;
    border-color: var(--primary);
    box-shadow: 0 0 0 2px rgba(22, 163, 74, 0.1);
  }
  .unit-dropdown:active{
    background: #f0f0f0;
  }

  .price-row{ display:flex; align-items:center; gap:.35rem; }
  .price-now{ font-weight:800; font-size:.9rem; color:var(--ink); }
  .currency{ font-weight:600; font-size:.72rem; color:var(--ink-2); margin-inline-start:.15rem; }
  .price-old{ font-size:.72rem; color:var(--ink-3); text-decoration:line-through; }

  .stock-line{ min-height:.9rem; }
  .stock{ font-size:.7rem; font-weight:600; }
  .stock.in{ color:var(--ok); } .stock.low{ color:var(--warn); } .stock.out{ color:var(--danger); }

  .cart-controls{ margin-top:auto; position:relative; min-height:32px; display:flex; justify-content:flex-end; align-items:center; }
  .fab-add{ width:32px; height:32px; border-radius:50%; background:var(--primary); color:#fff; border:none; font-size:1.1rem; line-height:1; display:flex; align-items:center; justify-content:center; cursor:pointer; box-shadow:0 2px 8px rgba(22,163,74,.3); }
  .fab-add:disabled{ background:#cbd5e1; color:#fff; box-shadow:none; cursor:not-allowed; }

  .qty-pill{ display:flex; align-items:center; gap:.3rem; background:#f7f8f9; border:1px solid var(--border); border-radius:999px; padding:.2rem .3rem; box-shadow:0 2px 6px rgba(0,0,0,.08); }
  .pill-btn{ width:26px; height:26px; border-radius:50%; border:none; background:var(--primary); color:#fff; font-weight:800; font-size:.9rem; display:flex; align-items:center; justify-content:center; cursor:pointer; }
  .pill-btn:disabled{ background:#cbd5e1; cursor:not-allowed; }
  .pill-q{ min-width:24px; text-align:center; font-weight:800; color:var(--ink); font-size:.85rem; }

  .no-products{ text-align:center; padding:3rem 2rem; color:var(--ink-3); }
  .no-products-icon{ font-size:3.6rem; margin-bottom:.6rem; }
  .no-products-text{ font-size:1.05rem; }

  /* Search slide */
  .search-slide{ position:fixed; left:0; right:0; top:-64px; z-index:25; transition:transform .25s ease; transform: translateY(-100%); display:flex; align-items:center; gap:.4rem; background:var(--bg); padding:.4rem .6rem; border-bottom:1px solid var(--border); }
  .search-slide.open{ transform: translateY(0); top:45px; }
  .search-input{ flex:1; padding:.7rem .9rem; border:2px solid var(--border); border-radius:12px; background:var(--surface); font-size:.95rem; }
  .search-input:focus{ outline:none; border-color:var(--primary); box-shadow:0 0 0 3px rgba(22,163,74,.12); }
  .close-search{ border:none; background:var(--surface); border:2px solid var(--border); border-radius:10px; padding:.55rem .7rem; cursor:pointer; }

  /* Category modal */
  .modal-backdrop{ position:fixed; inset:0; background:rgba(0,0,0,.38); display:flex; align-items:flex-end; justify-content:center; z-index:40; }
  @media (min-width:640px){ .modal-backdrop{ align-items:center; } }
  .modal-panel{ width:100%; max-width:420px; max-height:70vh; background:var(--surface); border-radius:14px 14px 0 0; overflow:hidden; box-shadow:0 20px 40px rgba(0,0,0,.25); }
  @media (min-width:640px){ .modal-panel{ border-radius:16px; } }
  .modal-header{ display:flex; align-items:center; justify-content:space-between; padding:.8rem 1rem; border-bottom:1px solid var(--border); }
  .modal-close{ border:none; background:transparent; font-size:1.1rem; cursor:pointer; }
  .modal-body{ padding:.4rem; overflow:auto; max-height:60vh; }
  .modal-cat{ width:100%; text-align:start; padding:.7rem .9rem; margin:.25rem 0; background:#f8f9fb; border:1px solid var(--border); border-radius:10px; cursor:pointer; font-weight:600; }
  .modal-cat.active{ background:var(--primary); color:#fff; border-color:var(--primary); }

  /* Mobile optimizations for bubbles */
  @media (max-width: 480px) {
    .bubble {
      transform: scale(0.6);
      box-shadow: 
        inset -3px -3px 6px rgba(255, 255, 255, 0.4),
        inset 3px 3px 6px rgba(0, 0, 0, 0.1),
        0 0 8px rgba(255, 255, 255, 0.3);
    }
  }
</style>
