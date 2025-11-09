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
  let selectedCategory = 'all';
  let selectedUnits = new Map();
  let categoryTabsContainer;
  let products = [];
  let categories = [];
  let loading = true;

  // Guard: ensure branch/service selected before shopping
  onMount(async () => {
    const saved = flow;
    if (!saved?.branchId || !saved?.fulfillment) {
      try { goto('/customer/start'); } catch (e) { console.error(e); }
    }
    await loadCategories();
    await loadProducts();
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) currentLanguage = savedLanguage;
    window.addEventListener('storage', (e) => {
      if (e.key === 'language') currentLanguage = e.newValue || 'ar';
    });
    return () => window.removeEventListener('storage', () => {});
  });

  // Reactive cart items for quantity display
  $: cartItems = $cartStore;
  $: cartItemsMap = new Map(cartItems.map(item => [
    `${item.id}-${item.selectedUnit?.id || 'base'}`, 
    item.quantity
  ]));

  function getItemQuantity(product) {
    const selectedUnit = getSelectedUnit(product);
    const key = `${product.id}-${selectedUnit.id}`;
    return cartItemsMap.get(key) || 0;
  }

  // Subscribe to scrolling content store (kept as-is for your banners)
  $: currentScrollingContent = $scrollingContent;
  $: activeScrollingTexts = scrollingContentActions.getActiveContent(currentScrollingContent, currentLanguage);

  // Load categories
  async function loadCategories() {
    try {
      const { data, error } = await supabase
        .from('product_categories')
        .select('id, name_en, name_ar')
        .eq('is_active', true)
        .order('name_en');
      if (error) throw error;
      categories = [{ id: 'all', name_en: 'All', name_ar: 'الكل' }, ...(data || [])];
    } catch (error) {
      console.error('Error loading categories:', error);
      categories = [{ id: 'all', name_en: 'All', name_ar: 'الكل' }];
    }
  }

  // Load products
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
        const sortedUnits = product.units.sort((a, b) => a.unitQty - b.unitQty);
        return {
          ...product,
          baseUnit: sortedUnits[0],
          additionalUnits: sortedUnits.slice(1)
        };
      });

      products.forEach(product => {
        selectedUnits.set(product.id, product.baseUnit);
      });
      selectedUnits = selectedUnits;
    } catch (error) {
      console.error('Error loading products:', error);
      products = [];
    } finally {
      loading = false;
    }
  }

  function selectCategory(categoryId) {
    selectedCategory = categoryId;
    if (categoryTabsContainer) {
      const activeTab = categoryTabsContainer.querySelector('.category-tab.active');
      if (activeTab) activeTab.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
    }
  }

  function scrollLeft() {
    if (categoryTabsContainer) categoryTabsContainer.scrollBy({ left: -220, behavior: 'smooth' });
  }
  function scrollRight() {
    if (categoryTabsContainer) categoryTabsContainer.scrollBy({ left: 220, behavior: 'smooth' });
  }

  function getSelectedUnit(product) {
    return selectedUnits.get(product.id) || product.baseUnit;
  }

  // Search + filter
  $: filteredProducts = products.filter(product => {
    const q = (searchQuery || '').toLowerCase();
    const matchesSearch =
      !q ||
      product.nameAr.toLowerCase().includes(q) ||
      product.nameEn.toLowerCase().includes(q);
    const matchesCategory = selectedCategory === 'all' || product.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  // Cart ops
  function addToCart(product) {
    const selectedUnit = getSelectedUnit(product);
    cartActions.addToCart(product, selectedUnit, 1);
  }
  function updateQuantity(product, change) {
    const selectedUnit = getSelectedUnit(product);
    const currentQuantity = cartActions.getItemQuantity(product.id, selectedUnit.id);
    const newQuantity = Math.max(0, currentQuantity + change);
    if (newQuantity === 0) cartActions.removeFromCart(product.id, selectedUnit.id);
    else cartActions.updateQuantity(product.id, selectedUnit.id, newQuantity);
  }

  // Language texts
  $: texts = currentLanguage === 'ar' ? {
    title: 'المنتجات - أكوا إكسبرس',
    search: 'البحث في المنتجات...',
    addToCart: 'أضف للسلة',
    sar: 'ر.س',
    inStock: 'متوفر',
    lowStock: 'كمية قليلة',
    outOfStock: 'نفد المخزون',
    unit: 'وحدة'
  } : {
    title: 'Products - Aqua Express',
    search: 'Search products...',
    addToCart: 'Add to Cart',
    sar: 'SAR',
    inStock: 'In Stock',
    lowStock: 'Low Stock',
    outOfStock: 'Out of Stock',
    unit: 'Unit'
  };
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="page" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Search + Sticky Categories -->
  <div class="top">
    <div class="search-bar">
      <input 
        type="text" 
        placeholder={texts.search}
        bind:value={searchQuery}
        class="search-input"
      />
      <span class="search-icon">🔎</span>
    </div>

    <div class="category-filter">
      <button class="nav-button nav-left" on:click={scrollLeft} aria-label="Scroll left">
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M12 16L6 10L12 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>

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

      <button class="nav-button nav-right" on:click={scrollRight} aria-label="Scroll right">
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path d="M8 4L14 10L8 16" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </button>
    </div>
  </div>

  <!-- Products -->
  <div class="products-grid">
    {#each filteredProducts as product}
      {#key `${$cartStore.length}-${selectedUnits.get(product.id)?.id || 'default'}`}
        {@const selectedUnit = getSelectedUnit(product)}
        {@const quantity = getItemQuantity(product)}
        {@const hasDiscount = selectedUnit.originalPrice && selectedUnit.originalPrice > selectedUnit.basePrice}
        {@const isLowStock = selectedUnit.stock <= selectedUnit.lowStockThreshold}
        {@const isOutOfStock = selectedUnit.stock === 0}

        <div class="product-card">
          <!-- Image (uniform) -->
          <div class="product-image">
            {#if selectedUnit.image}
              <img src={selectedUnit.image} alt={currentLanguage === 'ar' ? product.nameAr : product.nameEn} />
            {:else if product.image}
              <img src={product.image} alt={currentLanguage === 'ar' ? product.nameAr : product.nameEn} />
            {:else}
              <div class="image-placeholder">📦</div>
            {/if}
            {#if hasDiscount}
              <div class="discount-badge">
                -{Math.round(((selectedUnit.originalPrice - selectedUnit.basePrice) / selectedUnit.originalPrice) * 100)}%
              </div>
            {/if}
          </div>

          <!-- Info -->
          <div class="product-info">
            <h3 class="product-name">
              {currentLanguage === 'ar' ? product.nameAr : product.nameEn}
            </h3>

            <!-- Unit (compact) -->
            {#if product.additionalUnits && product.additionalUnits.length > 0}
              <div class="unit-selector">
                <select 
                  class="unit-dropdown"
                  value={selectedUnit.id}
                  on:change={(e) => {
                    const allUnits = [product.baseUnit, ...product.additionalUnits];
                    const newUnit = allUnits.find(u => u.id === e.target.value);
                    if (newUnit) {
                      selectedUnits.set(product.id, newUnit);
                      selectedUnits = selectedUnits;
                    }
                  }}
                  on:click={(e) => e.stopPropagation()}
                  on:touchstart={(e) => e.stopPropagation()}
                >
                  <option value={product.baseUnit.id}>
                    {currentLanguage === 'ar' ? product.baseUnit.nameAr : product.baseUnit.nameEn}
                  </option>
                  {#each product.additionalUnits as unit}
                    <option value={unit.id}>
                      {currentLanguage === 'ar' ? unit.nameAr : unit.nameEn}
                    </option>
                  {/each}
                </select>
              </div>
            {:else}
              <div class="unit-info">
                <span class="unit-size">
                  {currentLanguage === 'ar' ? selectedUnit.nameAr : selectedUnit.nameEn}
                </span>
              </div>
            {/if}

            <!-- Price only (bold), currency small -->
            <div class="price-row">
              <div class="price-now">
                {selectedUnit.basePrice.toFixed(2)}
                <span class="currency">{texts.sar}</span>
              </div>
              {#if hasDiscount}
                <div class="price-old">
                  {selectedUnit.originalPrice.toFixed(2)} {texts.sar}
                </div>
              {/if}
            </div>

            <!-- Stock (subtle) -->
            <div class="stock-line">
              {#if isOutOfStock}
                <span class="stock out">{texts.outOfStock}</span>
              {:else if isLowStock}
                <span class="stock low">{texts.lowStock}</span>
              {:else}
                <span class="stock in">{texts.inStock}</span>
              {/if}
            </div>

            <!-- Add / Quantity (floating compact) -->
            <div class="cart-controls">
              {#if quantity === 0}
                <button 
                  class="fab-add" 
                  on:click={() => addToCart(product)}
                  disabled={isOutOfStock}
                  type="button"
                  aria-label={texts.addToCart}
                  title={texts.addToCart}
                >+</button>
              {:else}
                <div class="qty-pill">
                  <button class="pill-btn" on:click={() => updateQuantity(product, -1)} aria-label="Decrease">−</button>
                  <span class="pill-q">{quantity}</span>
                  <button class="pill-btn" on:click={() => updateQuantity(product, 1)} aria-label="Increase" disabled={isOutOfStock}>+</button>
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
      <div class="no-products-text">
        {currentLanguage === 'ar' ? 'لا توجد منتجات مطابقة' : 'No matching products found'}
      </div>
    </div>
  {/if}
</div>

<style>
  :root{
    --surface: #ffffff;
    --bg: #f7f7f8;
    --ink: #1a1a1a;
    --ink-2:#5a5a5a;
    --ink-3:#9aa0a6;
    --primary:#16a34a; /* keep your green for actions only */
    --primary-700:#15803d;
    --danger:#e11d48;
    --warn:#f59e0b;
    --ok:#10b981;
    --border:#e6e7ea;
  }

  .page{
    max-width: 1200px;
    margin: 0 auto;
    padding: 0.75rem;
    min-height: 100vh;
    background: var(--bg);
    box-sizing: border-box;
  }
  @media (min-width:768px){ .page{ padding:1rem; } }

  /* Sticky top area (search + categories) */
  .top{
    position: sticky;
    top: 0;
    z-index: 20;
    background: var(--bg);
    padding-top: 0.25rem;
    padding-bottom: 0.5rem;
  }

  /* Search */
  .search-bar{ position: relative; margin-bottom: .5rem; }
  .search-input{
    width: 100%;
    padding: .8rem 2.5rem .8rem 1rem;
    border: 2px solid var(--border);
    border-radius: 14px;
    background: var(--surface);
    font-size: .95rem;
    transition: border-color .2s ease, box-shadow .2s ease;
  }
  .search-input:focus{ outline: none; border-color: var(--primary); box-shadow: 0 0 0 3px rgba(22,163,74,.12); }
  .search-icon{
    position: absolute; right: .8rem; top: 50%; transform: translateY(-50%); font-size: 1.1rem; color: var(--ink-3); pointer-events: none;
  }

  /* Categories */
  .category-filter{ display: flex; align-items: center; gap: .5rem; margin: .5rem 0 1rem; }
  .nav-button{
    width: 36px; height: 36px; border-radius: 50%;
    background: var(--surface); border: 2px solid var(--border); color: var(--ink);
    display:flex; align-items:center; justify-content:center; cursor:pointer; transition: all .2s;
  }
  .nav-button:hover{ border-color: var(--primary); background: var(--primary); color: #fff; }
  .category-tabs{
    display:flex; gap:.5rem; overflow-x:auto; scrollbar-width:none; -ms-overflow-style:none; padding: .25rem 0; flex:1;
  }
  .category-tabs::-webkit-scrollbar{ display:none; }
  .category-tab{
    padding: .6rem 1.1rem; background: var(--surface); border:2px solid var(--border);
    border-radius: 999px; white-space: nowrap; color: var(--ink); cursor:pointer; transition: all .2s;
    font-weight: 600; flex-shrink:0;
  }
  .category-tab:hover{ border-color: var(--primary); color: var(--primary); }
  .category-tab.active{ background: var(--primary); color:#fff; border-color: var(--primary); }

  /* Grid */
  .products-grid{
    display:grid;
    grid-template-columns: repeat(auto-fill, minmax(160px,1fr));
    gap: 1rem;
  }
  @media (min-width:480px){
    .products-grid{ grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap:1.25rem; }
  }
  @media (min-width:768px){
    .products-grid{ grid-template-columns: repeat(auto-fill, minmax(260px,1fr)); gap:1.5rem; }
  }

  /* Card */
  .product-card{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    overflow:hidden;
    display:flex; flex-direction:column;
    box-shadow: 0 2px 8px rgba(0,0,0,.06);
    transition: transform .18s ease, box-shadow .18s ease;
  }
  .product-card:hover{ transform: translateY(-2px); box-shadow: 0 10px 20px rgba(0,0,0,.12); }

  /* Uniform image area (square on phones, roomy on web) */
  .product-image{
    position: relative;
    padding-top: 100%; /* square */
    background: #f1f3f5;
  }
  @media (min-width:768px){ .product-image{ padding-top: 75%; } } /* a bit wider on desktop */
  .product-image img{
    position:absolute; inset:0; width:100%; height:100%; object-fit:cover;
  }
  .image-placeholder{
    position:absolute; inset:0; display:flex; align-items:center; justify-content:center; font-size:3rem; color:#c9cdd3;
  }
  .discount-badge{
    position:absolute; top:.6rem; inset-inline-end:.6rem;
    background: var(--danger); color:#fff; padding:.25rem .5rem; border-radius:10px; font-size:.75rem; font-weight:700;
  }

  .product-info{ padding: .9rem 1rem 1.1rem; display:flex; flex-direction:column; gap:.55rem; flex:1; }
  .product-name{
    margin:0; color: var(--ink); font-weight: 700; font-size: .98rem; line-height: 1.3;
    display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden;
  }

  /* Unit */
  .unit-info{ margin-top:.1rem; }
  .unit-size{
    font-size: .78rem; color: var(--ink-2); background:#f5f6f7; padding:.25rem .55rem; border-radius:999px; display:inline-block;
  }
  .unit-selector{ margin-top:.1rem; }
  .unit-dropdown{
    width:100%; padding:.5rem .9rem; font-size:.85rem; color:var(--ink);
    background:#f7f8f9; border:1px solid var(--border); border-radius:10px; appearance:none;
    background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23666' d='M6 9L1 4h10z'/%3E%3C/svg%3E");
    background-repeat:no-repeat; background-position:right .7rem center; padding-right:2rem;
    transition:border-color .2s, box-shadow .2s;
  }
  .unit-dropdown:hover{ border-color:var(--primary); }
  .unit-dropdown:focus{ outline:none; border-color:var(--primary); box-shadow:0 0 0 3px rgba(22,163,74,.12) }

  /* Price */
  .price-row{ display:flex; align-items:center; gap:.5rem; }
  .price-now{ font-weight:800; font-size:1.06rem; color: var(--ink); }
  .currency{ font-weight:600; font-size:.82rem; color: var(--ink-2); margin-inline-start:.25rem; }
  .price-old{ font-size:.85rem; color: var(--ink-3); text-decoration: line-through; }

  /* Stock */
  .stock-line{ min-height: 1.1rem; }
  .stock{ font-size:.82rem; font-weight:600; }
  .stock.in{ color: var(--ok); }
  .stock.low{ color: var(--warn); }
  .stock.out{ color: var(--danger); }

  /* Cart controls */
  .cart-controls{ margin-top:auto; position:relative; min-height:44px; }
  /* Floating add button (bottom-end) */
  .fab-add{
    position:absolute; inset-inline-end:.25rem; bottom:.25rem;
    width:40px; height:40px; border-radius:50%;
    background: var(--primary); color:#fff; border:none; font-size:1.35rem; line-height:1;
    display:flex; align-items:center; justify-content:center; cursor:pointer;
    box-shadow: 0 6px 14px rgba(22,163,74,.25);
    transition: transform .15s ease, background .15s ease, box-shadow .15s ease;
  }
  .fab-add:hover{ transform: translateY(-1px); background: var(--primary-700); box-shadow: 0 10px 18px rgba(22,163,74,.3); }
  .fab-add:disabled{ background:#cbd5e1; color:#fff; box-shadow:none; cursor:not-allowed; }

  /* Quantity pill */
  .qty-pill{
    position:absolute; inset-inline-end:.25rem; bottom:.25rem;
    display:flex; align-items:center; gap:.5rem;
    background:#f7f8f9; border:1px solid var(--border); border-radius:999px; padding:.3rem .4rem;
    box-shadow: 0 4px 10px rgba(0,0,0,.06);
  }
  .pill-btn{
    width:32px; height:32px; border-radius:50%; border:none; background: var(--primary); color:#fff; font-weight:800;
    display:flex; align-items:center; justify-content:center; cursor:pointer; transition: background .15s ease;
  }
  .pill-btn:hover{ background: var(--primary-700); }
  .pill-btn:disabled{ background:#cbd5e1; cursor:not-allowed; }
  .pill-q{ min-width:28px; text-align:center; font-weight:800; color: var(--ink); }

  /* Empty state */
  .no-products{ text-align:center; padding: 4rem 2rem; color: var(--ink-3); }
  .no-products-icon{ font-size: 4rem; margin-bottom: .75rem; }
  .no-products-text{ font-size:1.1rem; }
</style>
