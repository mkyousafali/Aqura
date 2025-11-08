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
  let isScrolling = false;
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
  });

  // Reactive cart items for quantity display
  $: cartItems = $cartStore;
  $: cartItemsMap = new Map(cartItems.map(item => [
    `${item.id}-${item.selectedUnit?.id || 'base'}`, 
    item.quantity
  ]));

  // Function to get item quantity from reactive cart
  function getItemQuantity(product) {
    const selectedUnit = getSelectedUnit(product);
    const key = `${product.id}-${selectedUnit.id}`;
    return cartItemsMap.get(key) || 0;
  }

  // Subscribe to scrolling content store
  $: currentScrollingContent = $scrollingContent;
  $: activeScrollingTexts = scrollingContentActions.getActiveContent(currentScrollingContent, currentLanguage);

  // Load categories from database
  async function loadCategories() {
    try {
      const { data, error } = await supabase
        .from('product_categories')
        .select('id, name_en, name_ar')
        .eq('is_active', true)
        .order('name_en');

      if (error) throw error;
      
      // Add "All" category at the beginning
      categories = [
        { id: 'all', name_en: 'All', name_ar: 'الكل' },
        ...(data || [])
      ];
    } catch (error) {
      console.error('Error loading categories:', error);
      categories = [{ id: 'all', name_en: 'All', name_ar: 'الكل' }];
    }
  }

  // Load products from database
  async function loadProducts() {
    loading = true;
    try {
      const { data, error } = await supabase
        .from('products')
        .select('*')
        .eq('is_active', true)
        .order('product_name_en');

      if (error) throw error;
      
      // Group products by product_serial to combine units
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
        
        const product = productMap.get(row.product_serial);
        product.units.push({
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
      
      // Convert map to array and set first unit as baseUnit
      products = Array.from(productMap.values()).map(product => {
        const sortedUnits = product.units.sort((a, b) => a.unitQty - b.unitQty);
        return {
          ...product,
          baseUnit: sortedUnits[0],
          additionalUnits: sortedUnits.slice(1)
        };
      });
      
      // Initialize selected units
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

  // Initialize language and listen for changes
  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }

    // Listen for language changes
    const handleStorageChange = (event) => {
      if (event.key === 'language') {
        currentLanguage = event.newValue || 'ar';
      }
    };
    
    window.addEventListener('storage', handleStorageChange);

    // Check for category parameter in URL
    const urlParams = new URLSearchParams(window.location.search);
    const categoryParam = urlParams.get('category');
    if (categoryParam) {
      selectedCategory = categoryParam;
    }

    // Only log for debugging - no custom handlers
    if (categoryTabsContainer) {
      console.log('Container width:', categoryTabsContainer.clientWidth);
      console.log('Content width:', categoryTabsContainer.scrollWidth);
      console.log('Can scroll:', categoryTabsContainer.scrollWidth > categoryTabsContainer.clientWidth);
      
      // Simple scroll test to verify scrollbar works
      categoryTabsContainer.addEventListener('scroll', () => {
        console.log('Scrolled to position:', categoryTabsContainer.scrollLeft);
      });
    }

    // Cleanup event listener
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  });

  function selectCategory(categoryId) {
    selectedCategory = categoryId;
    
    // Auto-scroll the selected tab into view
    if (categoryTabsContainer) {
      const activeTab = categoryTabsContainer.querySelector('.category-tab.active');
      if (activeTab) {
        activeTab.scrollIntoView({ 
          behavior: 'smooth', 
          block: 'nearest',
          inline: 'center'
        });
      }
    }
  }

  // Navigation functions like Urban-Express
  function scrollLeft() {
    if (categoryTabsContainer) {
      categoryTabsContainer.scrollBy({
        left: -200,
        behavior: 'smooth'
      });
    }
  }

  function scrollRight() {
    if (categoryTabsContainer) {
      categoryTabsContainer.scrollBy({
        left: 200,
        behavior: 'smooth'
      });
    }
  }

  // Get selected unit for a product
  function getSelectedUnit(product) {
    const selectedUnitObj = selectedUnits.get(product.id);
    
    if (!selectedUnitObj) {
      return product.baseUnit;
    }
    
    // Return the selected unit object directly
    return selectedUnitObj;
  }

  // Filter products based on search and category
  $: filteredProducts = products.filter(product => {
    const matchesSearch = !searchQuery || 
      product.nameAr.toLowerCase().includes(searchQuery.toLowerCase()) ||
      product.nameEn.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesCategory = selectedCategory === 'all' || product.category === selectedCategory;
    
    return matchesSearch && matchesCategory;
  });

  function addToCart(product) {
    const selectedUnit = getSelectedUnit(product);
    cartActions.addToCart(product, selectedUnit, 1);
  }

  function updateQuantity(product, change) {
    const selectedUnit = getSelectedUnit(product);
    const currentQuantity = cartActions.getItemQuantity(product.id, selectedUnit.id);
    const newQuantity = Math.max(0, currentQuantity + change);
    
    if (newQuantity === 0) {
      cartActions.removeFromCart(product.id, selectedUnit.id);
    } else {
      cartActions.updateQuantity(product.id, selectedUnit.id, newQuantity);
    }
  }

  // Language texts
  $: texts = currentLanguage === 'ar' ? {
    title: 'المنتجات - أكوا إكسبرس',
    search: 'البحث في المنتجات...',
    addToCart: 'أضف للسلة',
    sar: 'ر.س',
    inStock: 'متوفر',
    lowStock: 'كمية قليلة',
    outOfStock: 'نفد المخزون'
  } : {
    title: 'Products - Aqua Express',
    search: 'Search products...',
    addToCart: 'Add to Cart',
    sar: 'SAR',
    inStock: 'In Stock',
    lowStock: 'Low Stock',
    outOfStock: 'Out of Stock'
  };
</script>

<svelte:head>
  <title>{texts.title}</title>
</svelte:head>

<div class="products-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Search and Filters -->
  <div class="search-section">
    <div class="search-bar">
      <input 
        type="text" 
        placeholder={texts.search}
        bind:value={searchQuery}
        class="search-input"
      />
      <span class="search-icon">🔍</span>
    </div>
    
    <!-- Category Filter -->
    <div class="category-filter">
      <div class="category-container">
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
              on:click={() => {
                console.log('Category clicked:', category.id);
                selectedCategory = category.id;
              }}
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
  </div>

  <!-- Products Grid -->
  <div class="products-grid">
    {#each filteredProducts as product}
      {#key `${$cartStore.length}-${selectedUnits.get(product.id)?.id || 'default'}`}
        {@const selectedUnit = getSelectedUnit(product)}
        {@const quantity = getItemQuantity(product)}
        {@const hasDiscount = selectedUnit.originalPrice && selectedUnit.originalPrice > selectedUnit.basePrice}
        {@const isLowStock = selectedUnit.stock <= selectedUnit.lowStockThreshold}
      {@const isOutOfStock = selectedUnit.stock === 0}
      
      <div class="product-card">
        <!-- Product Image -->
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

        <!-- Product Info -->
        <div class="product-info">
          <h3 class="product-name">
            {currentLanguage === 'ar' ? product.nameAr : product.nameEn}
          </h3>
          
          <!-- Unit Selector -->
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

          <!-- Price -->
          <div class="price-section">
            <div class="current-price">
              {selectedUnit.basePrice.toFixed(2)} {texts.sar}
            </div>
            {#if hasDiscount}
              <div class="original-price">
                {selectedUnit.originalPrice.toFixed(2)} {texts.sar}
              </div>
            {/if}
          </div>

          <!-- Stock Status -->
          <div class="stock-status">
            {#if isOutOfStock}
              <span class="out-of-stock">{texts.outOfStock}</span>
            {:else if isLowStock}
              <span class="low-stock">{texts.lowStock}</span>
            {:else}
              <span class="in-stock">{texts.inStock}</span>
            {/if}
          </div>

          <!-- Add to Cart / Quantity Controls -->
          <div class="cart-controls">
            {#if quantity === 0}
              <button 
                class="add-to-cart-btn" 
                on:click={() => addToCart(product)}
                disabled={isOutOfStock}
                type="button"
              >
                {texts.addToCart}
              </button>
            {:else}
              <div class="quantity-controls">
                <button 
                  class="quantity-btn decrease" 
                  on:click={() => updateQuantity(product, -1)}
                >
                  -
                </button>
                <span class="quantity-display">{quantity}</span>
                <button 
                  class="quantity-btn increase" 
                  on:click={() => updateQuantity(product, 1)}
                  disabled={isOutOfStock}
                >
                  +
                </button>
              </div>
            {/if}
          </div>
        </div>
      </div>
      {/key}
    {/each}
  </div>
  
  {#if filteredProducts.length === 0}
    <div class="no-products">
      <div class="no-products-icon">📦</div>
      <div class="no-products-text">
        {currentLanguage === 'ar' ? 'لا توجد منتجات مطابقة' : 'No matching products found'}
      </div>
    </div>
  {/if}
</div>

<style>
  .products-container {
    padding: 0.75rem;
    max-width: 1200px;
    margin: 0 auto;
    min-height: 100vh;
    width: 100%;
    box-sizing: border-box;
  }
  
  @media (min-width: 768px) {
    .products-container {
      padding: 1rem;
    }
  }

  .search-section {
    margin-bottom: 1.25rem;
  }
  
  @media (min-width: 768px) {
    .search-section {
      margin-bottom: 2rem;
    }
  }

  .search-bar {
    position: relative;
    margin-bottom: 0.75rem;
  }
  
  @media (min-width: 768px) {
    .search-bar {
      margin-bottom: 1rem;
    }
  }

  .search-input {
    width: 100%;
    padding: 0.875rem 2.5rem 0.875rem 1rem;
    border: 2px solid var(--color-border);
    border-radius: 12px;
    font-size: 0.95rem;
    background: white;
    transition: border-color 0.2s ease;
    box-sizing: border-box;
  }
  
  @media (min-width: 768px) {
    .search-input {
      padding: 1rem 3rem 1rem 1rem;
      font-size: 1rem;
    }
  }

  .search-input:focus {
    outline: none;
    border-color: var(--color-primary);
  }

  .search-icon {
    position: absolute;
    right: 0.75rem;
    top: 50%;
    transform: translateY(-50%);
    font-size: 1.1rem;
    color: var(--color-ink-light);
    pointer-events: none;
  }
  
  @media (min-width: 768px) {
    .search-icon {
      right: 1rem;
      font-size: 1.2rem;
    }
  }

  .category-filter {
    margin-bottom: 1.25rem;
  }
  
  @media (min-width: 768px) {
    .category-filter {
      margin-bottom: 2rem;
    }
  }

  .category-container {
    position: relative;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  @media (min-width: 768px) {
    .category-container {
      gap: 1rem;
    }
  }

  .nav-button {
    flex-shrink: 0;
    width: 36px;
    height: 36px;
    background: white;
    border: 2px solid var(--color-border);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s ease;
    color: var(--color-ink);
    z-index: 2;
    -webkit-tap-highlight-color: transparent;
  }
  
  @media (min-width: 768px) {
    .nav-button {
      width: 40px;
      height: 40px;
    }
  }

  .nav-button:hover {
    border-color: var(--color-primary);
    background: var(--color-primary);
    color: white;
  }

  .category-tabs {
    display: flex;
    gap: 0.5rem;
    overflow-x: auto;
    overflow-y: hidden;
    scroll-behavior: smooth;
    -webkit-overflow-scrolling: touch;
    scrollbar-width: none;
    -ms-overflow-style: none;
    padding: 0.5rem 0;
    flex: 1;
  }

  .category-tabs::-webkit-scrollbar {
    display: none;
  }

  .category-tab {
    padding: 0.75rem 1.5rem;
    background: white;
    border: 2px solid var(--color-border);
    border-radius: 25px;
    cursor: pointer;
    transition: all 0.2s ease;
    white-space: nowrap;
    font-weight: 500;
    color: var(--color-ink);
    user-select: none;
    -webkit-user-select: none;
    flex-shrink: 0;
  }

  .category-tab:hover {
    border-color: var(--color-primary);
    color: var(--color-primary);
  }

  .category-tab.active {
    background: var(--color-primary);
    color: white;
    border-color: var(--color-primary);
  }

  .category-tab:active {
    transform: scale(0.98);
  }

  .category-tab.active {
    background: var(--color-primary);
    color: white;
    border-color: var(--color-primary);
  }

  .category-tab:hover:not(.active) {
    border-color: var(--color-primary);
    color: var(--color-primary);
  }

  .products-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 1rem;
  }
  
  @media (min-width: 480px) {
    .products-grid {
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 1.25rem;
    }
  }
  
  @media (min-width: 768px) {
    .products-grid {
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 1.5rem;
    }
  }

  .product-card {
    background: white;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    transition: transform 0.2s ease;
    border: 1px solid var(--color-border-light);
    display: flex;
    flex-direction: column;
  }
  
  @media (min-width: 768px) {
    .product-card {
      border-radius: 16px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    }
  }

  .product-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15);
  }

  .product-image {
    position: relative;
    height: 140px;
    background: var(--color-background);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  
  @media (min-width: 480px) {
    .product-image {
      height: 180px;
    }
  }
  
  @media (min-width: 768px) {
    .product-image {
      height: 200px;
    }
  }

  .product-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .image-placeholder {
    font-size: 4rem;
    color: var(--color-ink-light);
    opacity: 0.5;
  }

  .discount-badge {
    position: absolute;
    top: 0.75rem;
    right: 0.75rem;
    background: var(--color-danger);
    color: white;
    padding: 0.25rem 0.5rem;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .product-info {
    padding: 0.875rem;
    display: flex;
    flex-direction: column;
    flex: 1;
  }
  
  @media (min-width: 480px) {
    .product-info {
      padding: 1.25rem;
    }
  }
  
  @media (min-width: 768px) {
    .product-info {
      padding: 1.5rem;
    }
  }

  .product-name {
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 0.5rem 0;
    line-height: 1.3;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  
  @media (min-width: 480px) {
    .product-name {
      font-size: 1rem;
    }
  }
  
  @media (min-width: 768px) {
    .product-name {
      font-size: 1.1rem;
    }
  }

  .unit-info {
    margin-bottom: 1rem;
  }

  .unit-selector {
    margin-bottom: 1rem;
    position: relative;
    z-index: 1;
  }

  .unit-dropdown {
    width: 100%;
    padding: 0.5rem 0.75rem;
    font-size: 0.85rem;
    color: var(--color-ink);
    background: var(--color-background);
    border: 1px solid var(--color-border-light);
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s ease;
    appearance: none;
    -webkit-appearance: none;
    -moz-appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23666' d='M6 9L1 4h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 0.75rem center;
    padding-right: 2rem;
    -webkit-tap-highlight-color: transparent;
    touch-action: manipulation;
    user-select: none;
    -webkit-user-select: none;
  }

  .unit-dropdown:hover {
    border-color: var(--color-primary);
    background-color: rgba(255, 152, 0, 0.05);
  }

  .unit-dropdown:focus {
    outline: none;
    border-color: var(--color-primary);
    box-shadow: 0 0 0 3px rgba(255, 152, 0, 0.1);
  }

  .unit-dropdown:active {
    transform: scale(0.98);
  }

  @media (min-width: 768px) {
    .unit-dropdown {
      font-size: 0.9rem;
      padding: 0.6rem 0.875rem;
      border-radius: 10px;
    }
  }

  .unit-size {
    font-size: 0.8rem;
    color: var(--color-ink-light);
    background: var(--color-background);
    padding: 0.25rem 0.5rem;
    border-radius: 16px;
    display: inline-block;
  }
  
  @media (min-width: 768px) {
    .unit-size {
      font-size: 0.9rem;
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
    }
  }

  .price-section {
    margin-bottom: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .current-price {
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--color-primary);
  }
  
  @media (min-width: 480px) {
    .current-price {
      font-size: 1.15rem;
    }
  }
  
  @media (min-width: 768px) {
    .current-price {
      font-size: 1.25rem;
    }
  }

  .original-price {
    font-size: 0.85rem;
    color: var(--color-ink-light);
    text-decoration: line-through;
  }
  
  @media (min-width: 768px) {
    .original-price {
      font-size: 1rem;
    }
  }

  .stock-status {
    margin-bottom: 1rem;
  }

  .in-stock {
    color: var(--color-success);
    font-size: 0.875rem;
    font-weight: 500;
  }

  .low-stock {
    color: var(--color-warning);
    font-size: 0.875rem;
    font-weight: 500;
  }

  .out-of-stock {
    color: var(--color-danger);
    font-size: 0.875rem;
    font-weight: 500;
  }

  .cart-controls {
    margin-top: auto;
    position: relative;
    z-index: 10;
    pointer-events: auto;
  }

  .add-to-cart-btn {
    width: 100%;
    padding: 0.625rem;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 0.9rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
    pointer-events: auto;
    position: relative;
    z-index: 10;
    -webkit-tap-highlight-color: transparent;
  }
  
  @media (min-width: 768px) {
    .add-to-cart-btn {
      padding: 0.75rem;
      font-size: 1rem;
    }
  }

  .add-to-cart-btn:hover:not(:disabled) {
    background: var(--color-primary-dark);
  }

  .add-to-cart-btn:disabled {
    background: var(--color-ink-light);
    opacity: 0.5;
    cursor: not-allowed;
  }

  .quantity-controls {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 1rem;
    background: var(--color-background);
    border-radius: 8px;
    padding: 0.5rem;
  }

  .quantity-btn {
    width: 36px;
    height: 36px;
    background: var(--color-primary);
    color: white;
    border: none;
    border-radius: 50%;
    font-size: 1.1rem;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s ease;
    -webkit-tap-highlight-color: transparent;
    flex-shrink: 0;
  }
  
  @media (min-width: 768px) {
    .quantity-btn {
      width: 40px;
      height: 40px;
      font-size: 1.2rem;
    }
  }

  .quantity-btn:hover:not(:disabled) {
    background: var(--color-primary-dark);
  }

  .quantity-btn:disabled {
    background: var(--color-ink-light);
    opacity: 0.5;
    cursor: not-allowed;
  }

  .quantity-display {
    font-size: 1rem;
    font-weight: 600;
    color: var(--color-ink);
    min-width: 35px;
    text-align: center;
  }
  
  @media (min-width: 768px) {
    .quantity-display {
      font-size: 1.1rem;
      min-width: 40px;
    }
  }

  .no-products {
    text-align: center;
    padding: 4rem 2rem;
    color: var(--color-ink-light);
  }

  .no-products-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
    opacity: 0.5;
  }

  .no-products-text {
    font-size: 1.2rem;
  }
</style>
