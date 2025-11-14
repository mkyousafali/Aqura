<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { cartActions, cartStore } from '$lib/stores/cart.js';
  import { scrollingContent, scrollingContentActions } from '$lib/stores/scrollingContent.js';
  import { orderFlow } from '$lib/stores/orderFlow.js';
  import { supabase } from '$lib/utils/supabase';
  import OfferBadge from '$lib/components/customer/OfferBadge.svelte';

  let currentLanguage = 'ar';
  $: flow = $orderFlow;

  // Function to convert numbers to Arabic numerals
  function toArabicNumerals(num) {
    const arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return num.toString().replace(/\d/g, (digit) => arabicNumerals[digit]);
  }

  // Function to format price based on language
  function formatPrice(price) {
    // Handle null or undefined prices
    if (price == null) return currentLanguage === 'ar' ? '٠' : '0';
    // Only show decimals if there's a fractional part
    const formatted = price % 1 === 0 ? price.toFixed(0) : price.toFixed(2);
    return currentLanguage === 'ar' ? toArabicNumerals(formatted) : formatted;
  }

  let searchQuery = '';
  let showSearch = false;

  let selectedCategory = 'all';
  let selectedUnits = new Map();
  let categoryTabsContainer;

  let products = [];
  let categories = [];
  let loading = true;

  let showCategoryMenu = false;
  let showBogoModal = false;
  let selectedBogoOffer = null;
  let bogoGetProduct = null;

  // Check if a product qualifies for FREE based on cart state
  function shouldShowFree(product, unit) {
    if (!unit.hasOffer || unit.offerType !== 'bogo_get') return false;
    
    // Find the buy product in cart
    const buyProduct = $cartStore.find(item => 
      item.offerType === 'bogo' && 
      item.bogoGetProductId === unit.id
    );
    
    if (!buyProduct) return false;
    
    // Calculate how many free items customer is entitled to
    const buyQuantity = buyProduct.quantity || 0;
    const getQuantityPerBuy = buyProduct.bogoGetQuantity || 1;
    const maxFreeQuantity = buyQuantity * getQuantityPerBuy;
    
    // Check how many get products are already in cart
    const getProduct = $cartStore.find(item => 
      item.selectedUnit?.id === unit.id && 
      item.offerType === 'bogo_get'
    );
    
    const currentQuantity = getProduct?.quantity || 0;
    
    // Show FREE badge only if customer hasn't reached the free limit
    return currentQuantity < maxFreeQuantity;
  }

  async function showBogoDetails(unit) {
    if (!unit.hasOffer || unit.offerType !== 'bogo') return;
    
    selectedBogoOffer = unit;
    showBogoModal = true; // Show modal immediately
    bogoGetProduct = null; // Reset
    
    console.log('BOGO Unit:', unit);
    console.log('Get Product ID:', unit.bogoGetProductId);
    
    // Fetch the "get" product details
    if (unit.bogoGetProductId) {
      const { data, error } = await supabase
        .from('products')
        .select('id, product_name_en, product_name_ar, image_url, sale_price, unit_name_en, unit_name_ar, unit_qty')
        .eq('id', unit.bogoGetProductId)
        .single();
      
      console.log('Get Product Query Result:', { data, error });
      
      if (!error && data) {
        bogoGetProduct = data;
      } else if (error) {
        console.error('Error fetching get product:', error);
      }
    }
  }

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

    // Real-time subscriptions for offers and products
    const offersChannel = supabase
      .channel('offers-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offers' }, () => {
        console.log('📊 Offers table changed, reloading products...');
        loadProducts();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offer_products' }, () => {
        console.log('📦 Offer products changed, reloading products...');
        loadProducts();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bogo_offer_rules' }, () => {
        console.log('🎁 BOGO rules changed, reloading products...');
        loadProducts();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'products' }, () => {
        console.log('🛍️ Products changed, reloading products...');
        loadProducts();
      })
      .subscribe();

    return () => {
      window.removeEventListener('storage', onStorage);
      supabase.removeChannel(offersChannel);
    };
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
      // Use new API endpoint that includes offer data
      const apiUrl = `/api/customer/products-with-offers?branchId=${flow.branchId}&serviceType=${flow.fulfillment}`;
      
      const response = await fetch(apiUrl);
      
      if (!response.ok) {
        throw new Error('Failed to fetch products');
      }

      const data = await response.json();
      
      if (data.error) {
        throw new Error(data.error);
      }

      console.log(`📦 Loaded ${data.products?.length || 0} products (${data.offersCount} offers active)`);

      // Group products by serial (for multi-unit products)
      const productMap = new Map();
      (data.products || []).forEach(product => {
        if (!productMap.has(product.product_serial)) {
          productMap.set(product.product_serial, {
            id: product.product_serial,
            nameEn: product.nameEn,
            nameAr: product.nameAr,
            category: product.category,
            categoryNameEn: product.categoryNameEn,
            categoryNameAr: product.categoryNameAr,
            image: product.image,
            units: []
          });
        }
        
        const p = productMap.get(product.product_serial);
        p.units.push({
          id: product.id,
          nameEn: `${product.unitQty} ${product.unitEn}`,
          nameAr: `${product.unitQty} ${product.unitAr}`,
          unitEn: product.unitEn,
          unitAr: product.unitAr,
          basePrice: (product.hasOffer && product.offerPrice && product.offerType !== 'bogo_get') ? product.offerPrice : product.originalPrice,
          originalPrice: (product.hasOffer && product.offerPrice && product.offerType !== 'bogo_get') ? product.originalPrice : null,
          stock: product.stock,
          lowStockThreshold: product.lowStockThreshold,
          barcode: product.barcode,
          unitQty: product.unitQty,
          image: product.image,
          
          // Offer data
          hasOffer: product.hasOffer || false,
          offerType: product.offerType || null,
          offerId: product.offerId || null,
          offerNameEn: product.offerNameEn || null,
          offerNameAr: product.offerNameAr || null,
          offerQty: product.offerQty || null,
          savings: product.savings || 0,
          discountPercentage: product.discountPercentage || 0,
          maxUses: product.maxUses || null,
          offerEndDate: product.offerEndDate || null,
          isExpiringSoon: product.isExpiringSoon || false,
          
          // BOGO specific data (for buy products)
          bogoGetProductId: product.bogoGetProductId || null,
          bogoGetQuantity: product.bogoGetQuantity || null,
          bogoDiscountType: product.bogoDiscountType || null,
          bogoDiscountValue: product.bogoDiscountValue || null,
          
          // BOGO get product data (for get products)
          bogoBuyProductId: product.bogoBuyProductId || null,
          bogoBuyQuantity: product.bogoBuyQuantity || null
        });
      });

      products = Array.from(productMap.values()).map(product => {
        // Sort units: prioritize units with offers first, then by unit quantity
        const sorted = product.units.sort((a, b) => {
          // If one has offer and other doesn't, prioritize the one with offer
          if (a.hasOffer && !b.hasOffer) return -1;
          if (!a.hasOffer && b.hasOffer) return 1;
          // If both have offers or both don't, sort by unit quantity (smallest first)
          return a.unitQty - b.unitQty;
        });
        return { ...product, baseUnit: sorted[0], additionalUnits: sorted.slice(1) };
      });

      products.forEach(p => selectedUnits.set(p.id, p.baseUnit));
      selectedUnits = selectedUnits;
    } catch (error) {
      console.error('Error loading products:', error);
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
    
    // If BOGO free item was added, enrich it with product details
    enrichBOGOFreeItems();
  }
  
  function updateQuantity(product, d) {
    const u = getSelectedUnit(product);
    const cur = cartActions.getItemQuantity(product.id, u.id);
    const next = Math.max(0, cur + d);
    if (next === 0) cartActions.removeFromCart(product.id, u.id);
    else cartActions.updateQuantity(product.id, u.id, next);
    
    // Update BOGO free items if needed
    enrichBOGOFreeItems();
  }
  
  // Enrich BOGO free items with product details from loaded products
  function enrichBOGOFreeItems() {
    cartStore.update(cart => {
      cart.forEach(item => {
        if (item.isBOGOFreeItem && item.name === 'BOGO Free Item') {
          // Find the product in our loaded products
          const foundProduct = products.find(p => {
            const unit = p.units?.find(u => u.id === item.id);
            return unit !== undefined;
          });
          
          if (foundProduct) {
            const unit = foundProduct.units.find(u => u.id === item.id);
            if (unit) {
              item.name = foundProduct.nameAr;
              item.nameEn = foundProduct.nameEn;
              item.image = unit.image || foundProduct.image;
              item.selectedUnit = {
                id: unit.id,
                nameAr: unit.nameAr,
                nameEn: unit.nameEn
              };
            }
          }
        }
      });
      return cart;
    });
    cartActions.saveToStorage();
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
    unit: 'وحدة',
    save: 'وفر'
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
    unit: 'Unit',
    save: 'Save'
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
        {@const isFree = shouldShowFree(product, u)}
        {@const hasDiscount = u.hasOffer && u.savings > 0 && u.offerType !== 'bogo_get'}
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
            
            <!-- Percentage Discount Badge (Top-Right Corner) -->
            {#if u.hasOffer && u.offerType === 'percentage' && u.discountPercentage > 0}
              <div class="discount-badge-corner">
                <span class="discount-percentage">{Math.round(u.discountPercentage)}%</span>
              </div>
            {/if}
            
            <!-- Offer Badge for Special Price -->
            {#if u.hasOffer && u.offerType === 'special_price'}
              <div class="offer-badge-overlay">
                <OfferBadge 
                  offerType="special_price" 
                  discountValue={u.discountPercentage}
                  size="small"
                  showIcon={false}
                />
              </div>
            {/if}

            <!-- BOGO Offer Badge (Buy Product) -->
            {#if u.hasOffer && u.offerType === 'bogo'}
              <div class="offer-badge-overlay">
                <OfferBadge 
                  offerType="bogo" 
                  size="small"
                  showIcon={true}
                />
              </div>
            {/if}

            <!-- BOGO Get - FREE Badge (shown when buy product is in cart) -->
            {#if shouldShowFree(product, u)}
              <div class="bogo-free-badge">
                {#if u.discountPercentage === 100}
                  <span class="free-text">{currentLanguage === 'ar' ? 'مجاناً!' : 'FREE!'}</span>
                {:else if u.discountPercentage > 0}
                  <span class="discount-text">{Math.round(u.discountPercentage)}% {currentLanguage === 'ar' ? 'خصم' : 'OFF'}</span>
                {/if}
              </div>
            {/if}

            <!-- Expiring Soon Badge -->
            {#if u.isExpiringSoon}
              <div class="expiring-badge">
                <span>⏰</span>
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
              <div class="price-now" class:rtl={currentLanguage === 'ar'} class:offer-price={hasDiscount || isFree}>
                {#if isFree}
                  {#if currentLanguage === 'ar'}
                    {currentLanguage === 'ar' ? 'مجاناً' : 'FREE'}
                  {:else}
                    {currentLanguage === 'ar' ? 'مجاناً' : 'FREE'}
                  {/if}
                {:else if currentLanguage === 'ar'}
                  {formatPrice(u.basePrice)}
                  <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                {:else}
                  <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon" />
                  {formatPrice(u.basePrice)}
                {/if}
              </div>
              {#if hasDiscount || isFree}
                <div class="price-old" class:rtl={currentLanguage === 'ar'}>
                  {#if currentLanguage === 'ar'}
                    <span class="price-old-number">{formatPrice(isFree ? u.basePrice : u.originalPrice)}</span>
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                  {:else}
                    <img src="/icons/saudi-currency.png" alt="SAR" class="currency-icon-small" />
                    <span class="price-old-number">{formatPrice(isFree ? u.basePrice : u.originalPrice)}</span>
                  {/if}
                </div>
              {/if}
            </div>

            <div class="stock-line">
              {#if out}<span class="stock out">{texts.outOfStock}</span>
              {:else if isLow}<span class="stock low">{texts.lowStock}</span>
              {:else}<span class="stock in">{texts.inStock}</span>{/if}
            </div>

            {#if u.hasOffer && u.offerType === 'bogo'}
              <button class="bogo-info-btn" on:click={() => showBogoDetails(u)} type="button">
                <span class="bogo-icon">🎁</span>
                <span>{currentLanguage === 'ar' ? 'تفاصيل العرض' : 'Offer Details'}</span>
              </button>
            {/if}

            <div class="cart-controls">
              {#if qty === 0}
                <button class="fab-add" on:click={() => addToCart(product)} disabled={out} type="button" aria-label={texts.addToCart} title={texts.addToCart}>+</button>
              {:else}
                <div class="qty-pill">
                  <button class="pill-btn" on:click={() => updateQuantity(product, -1)} aria-label="Decrease">−</button>
                  <span class="pill-q">{currentLanguage === 'ar' ? toArabicNumerals(qty) : qty}</span>
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

  <!-- BOGO Offer Details Modal -->
  {#if showBogoModal && selectedBogoOffer}
    <div class="modal-backdrop" role="dialog" aria-modal="true" on:click={() => { showBogoModal = false; selectedBogoOffer = null; bogoGetProduct = null; }}>
      <div class="bogo-modal" on:click|stopPropagation>
        <div class="bogo-modal-header">
          <h3>{currentLanguage === 'ar' ? 'عرض اشتري واحصل' : 'Buy & Get Offer'}</h3>
          <button class="modal-close" on:click={() => { showBogoModal = false; selectedBogoOffer = null; bogoGetProduct = null; }} aria-label={texts.close}>✕</button>
        </div>
        <div class="bogo-modal-body">
          <div class="bogo-offer-name">
            {currentLanguage === 'ar' ? selectedBogoOffer.offerNameAr : selectedBogoOffer.offerNameEn}
          </div>
          
          <div class="bogo-details">
            <div class="bogo-step">
              <div class="step-badge buy">{currentLanguage === 'ar' ? 'اشتري' : 'Buy'}</div>
              <div class="step-content">
                {#if selectedBogoOffer.image}
                  <div class="step-product-image">
                    <img src={selectedBogoOffer.image} alt={currentLanguage === 'ar' ? selectedBogoOffer.nameAr : selectedBogoOffer.nameEn} />
                  </div>
                {:else}
                  <div class="step-product-image placeholder">📦</div>
                {/if}
                <div class="step-quantity">{selectedBogoOffer.offerQty}x</div>
                <div class="step-product-name">{currentLanguage === 'ar' ? selectedBogoOffer.nameAr : selectedBogoOffer.nameEn}</div>
                <div class="step-unit-info">{currentLanguage === 'ar' ? selectedBogoOffer.unitAr : selectedBogoOffer.unitEn}</div>
              </div>
            </div>
            
            <div class="bogo-arrow">→</div>
            
            <div class="bogo-step">
              <div class="step-badge get">{currentLanguage === 'ar' ? 'احصل على' : 'Get'}</div>
              <div class="step-content">
                {#if bogoGetProduct}
                  {#if bogoGetProduct.image_url}
                    <div class="step-product-image">
                      <img src={bogoGetProduct.image_url} alt={currentLanguage === 'ar' ? bogoGetProduct.product_name_ar : bogoGetProduct.product_name_en} />
                    </div>
                  {:else}
                    <div class="step-product-image placeholder">📦</div>
                  {/if}
                  <div class="step-quantity">{selectedBogoOffer.bogoGetQuantity}x</div>
                  <div class="step-product-name">{currentLanguage === 'ar' ? bogoGetProduct.product_name_ar : bogoGetProduct.product_name_en}</div>
                  <div class="step-unit-info">{bogoGetProduct.unit_qty} {currentLanguage === 'ar' ? bogoGetProduct.unit_name_ar : bogoGetProduct.unit_name_en}</div>
                  
                  {#if selectedBogoOffer.bogoDiscountType === 'free'}
                    <div class="free-badge">{currentLanguage === 'ar' ? 'مجاناً!' : 'FREE!'}</div>
                  {:else if selectedBogoOffer.bogoDiscountType === 'percentage' && selectedBogoOffer.bogoDiscountValue && selectedBogoOffer.bogoDiscountValue > 0}
                    <div class="discount-badge-small">{selectedBogoOffer.bogoDiscountValue}% {currentLanguage === 'ar' ? 'خصم' : 'OFF'}</div>
                  {/if}
                {:else}
                  <div class="loading-text">{currentLanguage === 'ar' ? 'جاري التحميل...' : 'Loading...'}</div>
                {/if}
              </div>
            </div>
          </div>
          
          <div class="bogo-note">
            <span class="note-icon">ℹ️</span>
            <span>{currentLanguage === 'ar' ? 'أضف المنتج إلى السلة للاستفادة من العرض' : 'Add product to cart to apply this offer'}</span>
          </div>
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

  /* Filter and Sort Row */
  .filter-sort-row{ 
    display:flex; 
    gap:.5rem; 
    margin-top:.5rem; 
    align-items:center; 
  }

  .filter-btn{ 
    display:flex; 
    align-items:center; 
    gap:.4rem; 
    padding:.5rem .85rem; 
    background:var(--surface); 
    border:1.5px solid var(--border); 
    border-radius:999px; 
    cursor:pointer; 
    font-weight:600; 
    font-size:.85rem; 
    color:var(--ink-2); 
    transition:.2s; 
    white-space:nowrap;
  }

  .filter-btn:hover{ 
    border-color:#f59e0b; 
    color:#f59e0b; 
  }

  .filter-btn.active{ 
    background:linear-gradient(135deg, #f59e0b 0%, #ea580c 100%); 
    color:#fff; 
    border-color:#f59e0b; 
  }

  .filter-icon{ 
    font-size:1rem; 
  }

  .sort-select{ 
    padding:.5rem .85rem; 
    background:var(--surface); 
    border:1.5px solid var(--border); 
    border-radius:999px; 
    font-weight:600; 
    font-size:.85rem; 
    color:var(--ink-2); 
    cursor:pointer; 
    appearance:none;
    -webkit-appearance:none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23666' d='M6 9L1 4h10z'/%3E%3C/svg%3E");
    background-repeat:no-repeat; 
    background-position:right .65rem center; 
    padding-right:2rem;
    min-width:120px;
  }

  .sort-select:focus{ 
    outline:none; 
    border-color:var(--primary); 
  }

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

  /* Percentage Discount Badge - Top Right Corner */
  .discount-badge-corner {
    position: absolute;
    top: 0;
    inset-inline-end: 0;
    background: linear-gradient(135deg, #EF4444 0%, #DC2626 100%);
    color: #fff;
    padding: .5rem .6rem;
    border-radius: 0 0 0 12px;
    box-shadow: 0 2px 8px rgba(239, 68, 68, 0.4);
    z-index: 5;
    animation: pulse-discount 2s ease-in-out infinite;
  }

  .discount-percentage {
    font-size: .95rem;
    font-weight: 900;
    display: block;
    line-height: 1;
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
  }

  @keyframes pulse-discount {
    0%, 100% { 
      transform: scale(1); 
      box-shadow: 0 2px 8px rgba(239, 68, 68, 0.4);
    }
    50% { 
      transform: scale(1.05); 
      box-shadow: 0 4px 12px rgba(239, 68, 68, 0.6);
    }
  }

  /* Offer Badge Overlay */
  .offer-badge-overlay{ 
    position: absolute; 
    top: .5rem; 
    inset-inline-start: .5rem; 
    z-index: 2;
  }

  /* BOGO GET - FREE Badge */
  .bogo-free-badge {
    position: absolute;
    top: .5rem;
    inset-inline-start: .5rem;
    background: linear-gradient(135deg, #EF4444 0%, #DC2626 100%);
    color: #fff;
    padding: .4rem .7rem;
    border-radius: 8px;
    font-size: .85rem;
    font-weight: 900;
    box-shadow: 0 3px 10px rgba(239, 68, 68, 0.5);
    z-index: 3;
    animation: pulse-free-badge 2s ease-in-out infinite;
    text-transform: uppercase;
  }

  @keyframes pulse-free-badge {
    0%, 100% {
      transform: scale(1);
      box-shadow: 0 3px 10px rgba(239, 68, 68, 0.5);
    }
    50% {
      transform: scale(1.05);
      box-shadow: 0 5px 15px rgba(239, 68, 68, 0.7);
    }
  }

  .free-text, .discount-text {
    display: block;
    line-height: 1;
    letter-spacing: 0.5px;
  }

  /* Expiring Soon Badge */
  .expiring-badge{ 
    position: absolute; 
    top: .5rem; 
    inset-inline-end: .5rem; 
    background: #EF4444; 
    color: #fff; 
    padding: .25rem .4rem; 
    border-radius: 6px; 
    font-size: .8rem; 
    animation: pulse-badge 1.5s ease-in-out infinite;
    z-index: 3;
  }

  @keyframes pulse-badge {
    0%, 100% { opacity: 1; transform: scale(1); }
    50% { opacity: 0.8; transform: scale(1.05); }
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

  .price-row{ display:flex; align-items:center; gap:.35rem; flex-wrap:wrap; }
  .price-now{ font-weight:900; font-size:1.1rem; color:var(--ink); display:flex; align-items:center; gap:.25rem; }
  .price-now.offer-price{ color:#10b981; }
  .currency-icon{ height:0.65rem; width:auto; display:inline-block; vertical-align:middle; }
  .currency-icon-small{ height:0.45rem; width:auto; display:inline-block; vertical-align:middle; margin-inline-start:.15rem; }
  .price-old{ 
    font-size:.72rem; 
    color:#ef4444; 
    display:flex; 
    align-items:center; 
    gap:.15rem; 
  }
  
  .price-old-number {
    position: relative;
    display: inline-block;
  }
  
  .price-old-number::before {
    content: '';
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    left: 0;
    background: linear-gradient(to bottom right, transparent 49%, #ef4444 49%, #ef4444 51%, transparent 51%);
    pointer-events: none;
  }

  /* Savings Display */
  .savings-row{ 
    display:flex; 
    align-items:center; 
    gap:.3rem; 
    background:linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%); 
    padding:.25rem .5rem; 
    border-radius:6px; 
    margin-top:.1rem;
  }

  .savings-icon{ 
    font-size:.9rem; 
  }

  .savings-text{ 
    font-size:.72rem; 
    font-weight:700; 
    color:#065f46; 
  }

  .stock-line{ min-height:.9rem; }
  .stock{ font-size:.7rem; font-weight:600; }
  .stock.in{ color:var(--ok); } .stock.low{ color:var(--warn); } .stock.out{ color:var(--danger); }

  /* BOGO Info Button */
  .bogo-info-btn {
    width: 100%;
    margin-top: .5rem;
    padding: .5rem;
    background: linear-gradient(135deg, #ec4899 0%, #db2777 100%);
    color: #fff;
    border: none;
    border-radius: 8px;
    font-size: .75rem;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: .4rem;
    cursor: pointer;
    transition: all .2s;
    box-shadow: 0 2px 6px rgba(236, 72, 153, 0.3);
  }

  .bogo-info-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 10px rgba(236, 72, 153, 0.4);
  }

  .bogo-info-btn:active {
    transform: translateY(0);
  }

  .bogo-icon {
    font-size: 1rem;
  }

  /* BOGO Modal */
  .bogo-modal {
    width: 100%;
    max-width: 480px;
    background: var(--surface);
    border-radius: 16px 16px 0 0;
    overflow: hidden;
    box-shadow: 0 20px 40px rgba(0,0,0,.3);
  }

  @media (min-width:640px) {
    .bogo-modal {
      border-radius: 16px;
    }
  }

  .bogo-modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.2rem;
    background: linear-gradient(135deg, #ec4899 0%, #db2777 100%);
    color: #fff;
  }

  .bogo-modal-header h3 {
    margin: 0;
    font-size: 1.1rem;
    font-weight: 700;
  }

  .bogo-modal-body {
    padding: 1.5rem 1.2rem;
  }

  .bogo-offer-name {
    font-size: 1rem;
    font-weight: 700;
    color: var(--ink);
    margin-bottom: 1.5rem;
    text-align: center;
  }

  .bogo-details {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 1.5rem;
  }

  .bogo-step {
    flex: 1;
    background: #f8f9fb;
    border-radius: 12px;
    padding: 1rem;
    border: 2px solid #e6e7ea;
  }

  .step-badge {
    display: inline-block;
    padding: .3rem .6rem;
    border-radius: 6px;
    font-size: .65rem;
    font-weight: 800;
    text-transform: uppercase;
    margin-bottom: .5rem;
  }

  .step-badge.buy {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: #fff;
  }

  .step-badge.get {
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: #fff;
  }

  .step-content {
    margin-top: .5rem;
  }

  .step-product-image {
    width: 100%;
    aspect-ratio: 1 / 1;
    border-radius: 10px;
    overflow: hidden;
    margin-bottom: .8rem;
    background: #f5f5f5;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .step-product-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .step-product-image.placeholder {
    font-size: 2.5rem;
    color: #d1d5db;
  }

  .step-quantity {
    font-size: 1.5rem;
    font-weight: 900;
    color: var(--ink);
    margin-bottom: .3rem;
  }

  .step-product-name {
    font-size: .85rem;
    font-weight: 600;
    color: var(--ink-2);
    line-height: 1.3;
    margin-bottom: .3rem;
  }

  .step-unit-info {
    font-size: .7rem;
    color: var(--ink-3);
    background: #f5f6f7;
    padding: .2rem .4rem;
    border-radius: 6px;
    display: inline-block;
    margin-bottom: .5rem;
  }

  .free-badge {
    display: inline-block;
    margin-top: .5rem;
    padding: .3rem .6rem;
    background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
    color: #fff;
    font-size: .7rem;
    font-weight: 800;
    border-radius: 6px;
    animation: pulse-free 1.5s ease-in-out infinite;
  }

  @keyframes pulse-free {
    0%, 100% {
      transform: scale(1);
      opacity: 1;
    }
    50% {
      transform: scale(1.05);
      opacity: 0.9;
    }
  }

  .discount-badge-small {
    display: inline-block;
    margin-top: .5rem;
    padding: .3rem .6rem;
    background: linear-gradient(135deg, #f59e0b 0%, #ea580c 100%);
    color: #fff;
    font-size: .7rem;
    font-weight: 800;
    border-radius: 6px;
  }

  .bogo-arrow {
    font-size: 1.5rem;
    color: var(--ink-3);
    font-weight: 900;
  }

  .bogo-note {
    display: flex;
    align-items: flex-start;
    gap: .6rem;
    padding: .8rem;
    background: #eff6ff;
    border: 1px solid #bfdbfe;
    border-radius: 10px;
    font-size: .75rem;
    color: #1e40af;
    line-height: 1.4;
  }

  .note-icon {
    font-size: 1rem;
    flex-shrink: 0;
  }

  .loading-text {
    font-size: .8rem;
    color: var(--ink-3);
    font-style: italic;
  }

  .cart-controls{ margin-top:auto; position:relative; min-height:32px; display:flex; justify-content:flex-end; align-items:center; }
  .fab-add{ width:32px; height:32px; border-radius:50%; background:#f59e0b; color:#fff; border:none; font-size:1.1rem; line-height:1; display:flex; align-items:center; justify-content:center; cursor:pointer; box-shadow:0 2px 8px rgba(245,158,11,.3); }
  .fab-add:disabled{ background:#cbd5e1; color:#fff; box-shadow:none; cursor:not-allowed; }

  .qty-pill{ display:flex; align-items:center; gap:.3rem; background:#f7f8f9; border:1px solid var(--border); border-radius:999px; padding:.2rem .3rem; box-shadow:0 2px 6px rgba(0,0,0,.08); }
  .pill-btn{ width:26px; height:26px; border-radius:50%; border:none; background:#f59e0b; color:#fff; font-weight:800; font-size:.9rem; display:flex; align-items:center; justify-content:center; cursor:pointer; }
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
