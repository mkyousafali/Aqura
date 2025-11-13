<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';
  import { currentLocale } from '$lib/i18n';
  import { supabase, supabaseAdmin } from '$lib/utils/supabase';
  
  // Props
  export let editMode = false;
  export let offerId: number | null = null;
  
  const dispatch = createEventDispatcher();
  
  let currentStep = 1;
  let loading = false;
  let error: string | null = null;
  
  // Form data for Step 1
  let offerData = {
    name_ar: '',
    name_en: '',
    description_ar: '',
    description_en: '',
    start_date: new Date().toISOString().slice(0, 16),
    end_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 16),
    branch_id: null as number | null,
    service_type: 'both' as 'delivery' | 'pickup' | 'both',
    is_active: true
  };
  
  let branches: any[] = [];
  let products: any[] = [];
  let productSearchTerm = '';
  let showProductModal = false;
  let selectingFor: 'buy' | 'get' = 'buy';
  let showRuleForm = false;
  let usedProductIds: Set<string> = new Set();
  
  // Step 2: Buy X Get Y Rules
  let bogoRules: any[] = [];
  let currentRule = {
    buyProduct: null as any,
    buyQuantity: 1,
    getProduct: null as any,
    getQuantity: 1,
    discountType: 'free' as 'free' | 'percentage' | 'amount',
    discountValue: 0
  };
  
  // Reactive locale
  $: locale = $currentLocale;
  $: isRTL = locale === 'ar';
  
  // Calculate offer price
  $: calculatedOfferPrice = (() => {
    if (!currentRule.buyProduct || !currentRule.getProduct) return 0;
    
    const buyTotal = currentRule.buyProduct.price * currentRule.buyQuantity;
    const getTotal = currentRule.getProduct.price * currentRule.getQuantity;
    
    let discount = 0;
    if (currentRule.discountType === 'free') {
      discount = getTotal;
    } else if (currentRule.discountType === 'percentage') {
      discount = (getTotal * currentRule.discountValue) / 100;
    } else if (currentRule.discountType === 'amount') {
      discount = currentRule.discountValue;
    }
    
    const finalPrice = buyTotal + getTotal - discount;
    return Math.max(0, finalPrice);
  })();
  
  $: filteredProducts = products.filter(p => {
    // Filter by search term
    const matchesSearch = !productSearchTerm ||
      p.barcode?.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
      p.name_ar.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
      p.name_en.toLowerCase().includes(productSearchTerm.toLowerCase());
    
    // Exclude products used in OTHER offers
    const notUsedInOtherOffers = !usedProductIds.has(p.id);
    
    // Debug log for Butter Croissant products
    if (p.name_en.includes('Butter Croissant')) {
      console.log(`🥐 ${p.name_en} (${p.barcode}):`, {
        productId: p.id,
        isInUsedSet: usedProductIds.has(p.id),
        matchesSearch,
        notUsedInOtherOffers,
        willShow: matchesSearch && notUsedInOtherOffers
      });
    }
    
    return matchesSearch && notUsedInOtherOffers;
  });
  
  onMount(async () => {
    await loadBranches();
    await loadProducts();
    await loadUsedProductIds(); // Load products from other BOGO offers
    if (editMode && offerId) {
      await loadOfferData();
    }
  });
  
  // Load product IDs used in OTHER offers (exclude current offer if editing)
  async function loadUsedProductIds() {
    try {
      const tempSet = new Set<string>();
      
      // 1. Load products from BOGO offers
      let bogoQuery = supabaseAdmin
        .from('bogo_offer_rules')
        .select('buy_product_id, get_product_id, offer_id');
      
      // If editing, exclude rules from the current offer
      if (editMode && offerId) {
        bogoQuery = bogoQuery.neq('offer_id', offerId);
      }
      
      const { data: bogoData, error: bogoError } = await bogoQuery;
      
      if (bogoError) {
        console.error('Error loading BOGO rules:', bogoError);
      } else {
        console.log('BOGO rules loaded:', bogoData);
        bogoData?.forEach((rule: any) => {
          if (rule.buy_product_id) {
            console.log('Adding BOGO buy product:', rule.buy_product_id);
            tempSet.add(rule.buy_product_id);
          }
          if (rule.get_product_id) {
            console.log('Adding BOGO get product:', rule.get_product_id);
            tempSet.add(rule.get_product_id);
          }
        });
      }
      
      // 2. Load products from Bundle offers
      let bundleQuery = supabaseAdmin
        .from('offer_bundles')
        .select('required_products, offer_id, bundle_name_en');
      
      // If editing, exclude bundles from the current offer
      if (editMode && offerId) {
        bundleQuery = bundleQuery.neq('offer_id', offerId);
      }
      
      const { data: bundleData, error: bundleError } = await bundleQuery;
      
      if (bundleError) {
        console.error('Error loading bundles:', bundleError);
      } else {
        console.log('Bundles loaded:', bundleData);
        bundleData?.forEach((bundle: any) => {
          console.log(`Processing bundle: ${bundle.bundle_name_en}`, bundle.required_products);
          if (Array.isArray(bundle.required_products)) {
            bundle.required_products.forEach((item: any) => {
              if (item.product_id) {
                console.log('Adding bundle product:', item.product_id);
                tempSet.add(item.product_id);
              }
            });
          }
        });
      }
      
      // 3. Load products from offer_products table (Percentage & Special Price offers)
      let offerProductsQuery = supabaseAdmin
        .from('offer_products')
        .select(`
          product_id,
          offers!inner(id, is_active, end_date, type)
        `)
        .eq('offers.is_active', true)
        .gte('offers.end_date', new Date().toISOString());
      
      // If editing, exclude products from the current offer
      if (editMode && offerId) {
        offerProductsQuery = offerProductsQuery.neq('offers.id', offerId);
      }
      
      const { data: offerProducts, error: offerProductsError } = await offerProductsQuery;
      
      if (offerProductsError) {
        console.error('Error loading offer products:', offerProductsError);
      } else {
        console.log('Offer products loaded:', offerProducts);
        offerProducts?.forEach((op: any) => {
          console.log('Adding product from offer_products:', op.product_id);
          tempSet.add(op.product_id);
        });
      }
      
      console.log('✅ Final used product IDs:', Array.from(tempSet));
      
      // Reassign to trigger reactivity
      usedProductIds = tempSet;
    } catch (err) {
      console.error('Error loading used product IDs:', err);
    }
  }
  
  async function loadBranches() {
    const { data, error: err } = await supabase
      .from('branches')
      .select('id, name_ar, name_en')
      .eq('is_active', true)
      .order('name_en');
    
    if (!err && data) {
      branches = data;
    }
  }
  
  async function loadProducts() {
    const { data, error: err } = await supabaseAdmin
      .from('products')
      .select('id, product_name_ar, product_name_en, barcode, sale_price, image_url, current_stock')
      .eq('is_active', true)
      .order('product_name_en');
    
    if (!err && data) {
      products = data.map(p => ({
        id: p.id,
        name_ar: p.product_name_ar,
        name_en: p.product_name_en,
        barcode: p.barcode,
        price: parseFloat(p.sale_price) || 0,
        image_url: p.image_url,
        stock: p.current_stock || 0
      }));
    }
  }
  
  // Convert UTC datetime to Saudi timezone for datetime-local input
  function toSaudiTimeInput(utcDateString) {
    const date = new Date(utcDateString);
    // Convert to Saudi timezone (UTC+3)
    const saudiTime = new Date(date.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
    // Format for datetime-local input (YYYY-MM-DDTHH:mm)
    const year = saudiTime.getFullYear();
    const month = String(saudiTime.getMonth() + 1).padStart(2, '0');
    const day = String(saudiTime.getDate()).padStart(2, '0');
    const hours = String(saudiTime.getHours()).padStart(2, '0');
    const minutes = String(saudiTime.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  }
  
  async function loadOfferData() {
    if (!offerId) return;
    
    const { data, error: err } = await supabase
      .from('offers')
      .select('*')
      .eq('id', offerId)
      .single();
    
    if (!err && data) {
      offerData = {
        name_ar: data.name_ar || '',
        name_en: data.name_en || '',
        description_ar: data.description_ar || '',
        description_en: data.description_en || '',
        start_date: toSaudiTimeInput(data.start_date),
        end_date: toSaudiTimeInput(data.end_date),
        branch_id: data.branch_id,
        service_type: data.service_type || 'both',
        is_active: data.is_active
      };
      
      // Load existing BOGO rules
      await loadBogoRules();
    }
  }

  async function loadBogoRules() {
    if (!offerId) return;

    const { data: rules, error: err } = await supabaseAdmin
      .from('bogo_offer_rules')
      .select('*')
      .eq('offer_id', offerId);

    if (err || !rules) {
      console.error('Error loading BOGO rules:', err);
      return;
    }

    // Clear existing rules
    bogoRules = [];

    // Load each rule with product details
    for (const rule of rules) {
      const buyProduct = products.find(p => p.id === rule.buy_product_id);
      const getProduct = products.find(p => p.id === rule.get_product_id);

      if (!buyProduct || !getProduct) {
        console.warn('Product not found for rule:', rule);
        continue;
      }

      bogoRules = [...bogoRules, {
        id: rule.id,
        buyProduct: buyProduct,
        buyQuantity: rule.buy_quantity,
        getProduct: getProduct,
        getQuantity: rule.get_quantity,
        discountType: rule.discount_type,
        discountValue: rule.discount_value
      }];
    }

    // Move to step 2 if we have loaded rules
    if (bogoRules.length > 0) {
      currentStep = 2;
    }
  }
  
  function nextStep() {
    // Validate Step 1
    if (!offerData.name_ar.trim() || !offerData.name_en.trim()) {
      error = isRTL
        ? 'يرجى ملء اسم العرض بالعربية والإنجليزية'
        : 'Please fill offer name in both Arabic and English';
      return;
    }
    
    if (new Date(offerData.end_date) <= new Date(offerData.start_date)) {
      error = isRTL
        ? 'يجب أن يكون تاريخ الانتهاء بعد تاريخ البدء'
        : 'End date must be after start date';
      return;
    }
    
    error = null;
    currentStep = 2;
  }
  
  function prevStep() {
    currentStep = 1;
    error = null;
  }
  
  function openProductModal(type: 'buy' | 'get') {
    selectingFor = type;
    showProductModal = true;
    productSearchTerm = '';
  }
  
  function closeProductModal() {
    showProductModal = false;
  }
  
  function selectProduct(product: any) {
    if (selectingFor === 'buy') {
      currentRule.buyProduct = product;
    } else {
      currentRule.getProduct = product;
    }
    closeProductModal();
  }
  
  function startNewRule() {
    showRuleForm = true;
  }
  
  function cancelRule() {
    showRuleForm = false;
    currentRule = {
      buyProduct: null,
      buyQuantity: 1,
      getProduct: null,
      getQuantity: 1,
      discountType: 'free',
      discountValue: 0
    };
    error = null;
  }
  
  function addRule() {
    // Validation
    if (!currentRule.buyProduct) {
      error = isRTL ? 'يرجى اختيار منتج الشراء (X)' : 'Please select Buy product (X)';
      return;
    }
    
    if (currentRule.buyQuantity < 1) {
      error = isRTL ? 'كمية الشراء يجب أن تكون 1 على الأقل' : 'Buy quantity must be at least 1';
      return;
    }
    
    if (!currentRule.getProduct) {
      error = isRTL ? 'يرجى اختيار منتج الحصول (Y)' : 'Please select Get product (Y)';
      return;
    }
    
    if (currentRule.getQuantity < 1) {
      error = isRTL ? 'كمية الحصول يجب أن تكون 1 على الأقل' : 'Get quantity must be at least 1';
      return;
    }
    
    if (currentRule.discountType !== 'free' && currentRule.discountValue <= 0) {
      error = isRTL ? 'يرجى إدخال قيمة الخصم' : 'Please enter discount value';
      return;
    }
    
    // Add rule
    bogoRules = [...bogoRules, {
      ...JSON.parse(JSON.stringify(currentRule)),
      id: Date.now()
    }];
    
    // Reset form and hide it
    showRuleForm = false;
    currentRule = {
      buyProduct: null,
      buyQuantity: 1,
      getProduct: null,
      getQuantity: 1,
      discountType: 'free',
      discountValue: 0
    };
    
    error = null;
  }
  
  function editRule(rule: any) {
    // Load the rule data into the form
    currentRule = {
      buyProduct: rule.buyProduct,
      buyQuantity: rule.buyQuantity,
      getProduct: rule.getProduct,
      getQuantity: rule.getQuantity,
      discountType: rule.discountType,
      discountValue: rule.discountValue
    };
    
    // Remove the rule from the list (will be re-added when saved)
    bogoRules = bogoRules.filter(r => r.id !== rule.id);
    
    // Show the form
    showRuleForm = true;
  }
  
  function deleteRule(id: number) {
    bogoRules = bogoRules.filter(r => r.id !== id);
  }
  
  async function saveOffer() {
    if (bogoRules.length === 0) {
      error = isRTL 
        ? 'يرجى إضافة قاعدة واحدة على الأقل'
        : 'Please add at least one rule';
      return;
    }
    
    loading = true;
    error = null;
    
    try {
      // Step 1: Create the offer
      const offerPayload = {
        type: 'bogo',
        name_ar: offerData.name_ar,
        name_en: offerData.name_en,
        description_ar: offerData.description_ar,
        description_en: offerData.description_en,
        start_date: offerData.start_date,
        end_date: offerData.end_date,
        branch_id: offerData.branch_id,
        service_type: offerData.service_type,
        is_active: offerData.is_active,
        discount_type: 'percentage', // Not used for BOGO but required
        discount_value: 0,
        bogo_buy_quantity: 1,  // Dummy value to satisfy constraint
        bogo_get_quantity: 1   // Dummy value to satisfy constraint
      };
      
      const { data: offer, error: offerError } = await supabaseAdmin
        .from('offers')
        .insert(offerPayload)
        .select()
        .single();
      
      if (offerError) throw offerError;
      
      // Step 2: Create BOGO rules
      const rulesPayload = bogoRules.map(rule => ({
        offer_id: offer.id,
        buy_product_id: rule.buyProduct.id,
        buy_quantity: rule.buyQuantity,
        get_product_id: rule.getProduct.id,
        get_quantity: rule.getQuantity,
        discount_type: rule.discountType,
        discount_value: rule.discountValue
      }));
      
      const { error: rulesError } = await supabaseAdmin
        .from('bogo_offer_rules')
        .insert(rulesPayload);
      
      if (rulesError) throw rulesError;
      
      // Success!
      alert(isRTL 
        ? '✅ تم إنشاء عرض اشتري واحصل بنجاح!'
        : '✅ Buy X Get Y offer created successfully!'
      );
      
      // Dispatch success event to close window
      dispatch('success');
      
    } catch (err) {
      console.error('Error saving BOGO offer:', err);
      error = isRTL
        ? 'حدث خطأ أثناء حفظ العرض. يرجى المحاولة مرة أخرى.'
        : 'Error saving offer. Please try again.';
    } finally {
      loading = false;
    }
  }
</script>

<div class="buy-x-get-y-window" class:rtl={isRTL}>
  <!-- Header with Steps -->
  <div class="window-header">
    <h2 class="window-title">
      {editMode
        ? isRTL
          ? '🎁 تعديل عرض اشتري واحصل'
          : '🎁 Edit Buy X Get Y Offer'
        : isRTL
          ? '🎁 إنشاء عرض اشتري واحصل'
          : '🎁 Create Buy X Get Y Offer'}
    </h2>
    <div class="step-indicator">
      <div class="step-item" class:active={currentStep === 1} class:completed={currentStep > 1}>
        <div class="step-circle">1</div>
        <span class="step-label">{isRTL ? 'تفاصيل العرض' : 'Offer Details'}</span>
      </div>
      <div class="step-divider"></div>
      <div class="step-item" class:active={currentStep === 2}>
        <div class="step-circle">2</div>
        <span class="step-label">{isRTL ? 'إعدادات العرض' : 'Offer Configuration'}</span>
      </div>
    </div>
  </div>

  {#if error}
    <div class="error-banner">
      <span class="error-icon">⚠️</span>
      <span class="error-text">{error}</span>
    </div>
  {/if}

  <!-- Step Content -->
  <div class="window-content">
    {#if currentStep === 1}
      <!-- Step 1: Offer Details -->
      <div class="step-content">
        <h3 class="section-title">
          {isRTL ? 'معلومات العرض الأساسية' : 'Basic Offer Information'}
        </h3>

        <!-- Offer Names -->
        <div class="form-row">
          <div class="form-group">
            <label for="name_ar">
              {isRTL ? 'اسم العرض (عربي)' : 'Offer Name (Arabic)'}
              <span class="required">*</span>
            </label>
            <input
              id="name_ar"
              type="text"
              bind:value={offerData.name_ar}
              placeholder={isRTL
                ? 'أدخل اسم العرض بالعربية'
                : 'Enter offer name in Arabic'}
              required
            />
          </div>
          <div class="form-group">
            <label for="name_en">
              {isRTL ? 'اسم العرض (إنجليزي)' : 'Offer Name (English)'}
              <span class="required">*</span>
            </label>
            <input
              id="name_en"
              type="text"
              bind:value={offerData.name_en}
              placeholder={isRTL
                ? 'أدخل اسم العرض بالإنجليزية'
                : 'Enter offer name in English'}
              required
            />
          </div>
        </div>

        <!-- Descriptions -->
        <div class="form-row">
          <div class="form-group">
            <label for="desc_ar">
              {isRTL ? 'الوصف (عربي)' : 'Description (Arabic)'}
            </label>
            <textarea
              id="desc_ar"
              bind:value={offerData.description_ar}
              placeholder={isRTL
                ? 'أدخل وصف العرض بالعربية'
                : 'Enter description in Arabic'}
              rows="3"
            ></textarea>
          </div>
          <div class="form-group">
            <label for="desc_en">
              {isRTL ? 'الوصف (إنجليزي)' : 'Description (English)'}
            </label>
            <textarea
              id="desc_en"
              bind:value={offerData.description_en}
              placeholder={isRTL
                ? 'أدخل وصف العرض بالإنجليزية'
                : 'Enter description in English'}
              rows="3"
            ></textarea>
          </div>
        </div>

        <h3 class="section-title">
          {isRTL ? 'الفترة الزمنية' : 'Time Period'}
        </h3>

        <!-- Date Range -->
        <div class="form-row">
          <div class="form-group">
            <label for="start_date">
              {isRTL ? 'تاريخ البدء' : 'Start Date & Time'}
              <span class="required">*</span>
              <span class="timezone-hint">({isRTL ? 'التوقيت السعودي' : 'Saudi Time Zone'})</span>
            </label>
            <input
              id="start_date"
              type="datetime-local"
              bind:value={offerData.start_date}
              required
            />
          </div>
          <div class="form-group">
            <label for="end_date">
              {isRTL ? 'تاريخ الانتهاء' : 'End Date & Time'}
              <span class="required">*</span>
              <span class="timezone-hint">({isRTL ? 'التوقيت السعودي' : 'Saudi Time Zone'})</span>
            </label>
            <input
              id="end_date"
              type="datetime-local"
              bind:value={offerData.end_date}
              required
            />
          </div>
        </div>

        <h3 class="section-title">
          {isRTL ? 'النطاق والاستهداف' : 'Scope & Targeting'}
        </h3>

        <!-- Branch & Service Type -->
        <div class="form-row">
          <div class="form-group">
            <label for="branch">
              {isRTL ? 'الفرع المستهدف' : 'Target Branch'}
            </label>
            <select id="branch" bind:value={offerData.branch_id}>
              <option value={null}>{isRTL ? 'جميع الفروع' : 'All Branches'}</option>
              {#each branches as branch}
                <option value={branch.id}>
                  {isRTL ? branch.name_ar : branch.name_en}
                </option>
              {/each}
            </select>
          </div>
          <div class="form-group">
            <label for="service_type">
              {isRTL ? 'نوع الخدمة' : 'Service Type'}
            </label>
            <select id="service_type" bind:value={offerData.service_type}>
              <option value="both">{isRTL ? 'التوصيل والاستلام' : 'Delivery & Pickup'}</option>
              <option value="delivery">{isRTL ? 'التوصيل فقط' : 'Delivery Only'}</option>
              <option value="pickup">{isRTL ? 'الاستلام فقط' : 'Pickup Only'}</option>
            </select>
          </div>
        </div>
      </div>
    {:else if currentStep === 2}
      <!-- Step 2: Buy X Get Y Configuration -->
      <div class="step-content">
        <h3 class="section-title">
          {isRTL ? 'إعدادات اشتري واحصل' : 'Buy X Get Y Configuration'}
        </h3>

        <!-- Add Rule Form -->
        {#if !showRuleForm}
          <button type="button" class="btn-add-new-rule" on:click={startNewRule}>
            <span class="plus-icon">+</span>
            {isRTL ? 'إضافة قاعدة جديدة' : 'Add New Rule'}
          </button>
        {/if}
        
        {#if showRuleForm}
        <div class="bogo-form">
          <div class="rule-form-container">
          <h4 class="form-subtitle">{isRTL ? 'إضافة قاعدة جديدة' : 'Add New Rule'}</h4>
          
          <!-- Buy Product (X) -->
          <div class="form-section">
            <label class="section-label">{isRTL ? 'اشتري منتج X' : 'Buy Product X'}</label>
            
            <div class="product-row">
              <button 
                type="button" 
                class="btn-select-product"
                on:click={() => openProductModal('buy')}
              >
                {currentRule.buyProduct 
                  ? (isRTL ? currentRule.buyProduct.name_ar : currentRule.buyProduct.name_en)
                  : (isRTL ? 'اختر المنتج' : 'Select Product')
                }
              </button>
              
              <div class="qty-group">
                <label>{isRTL ? 'الكمية' : 'Qty'}</label>
                <input 
                  type="number" 
                  min="1" 
                  bind:value={currentRule.buyQuantity}
                  class="qty-input"
                />
              </div>
            </div>
            
            {#if currentRule.buyProduct}
              <div class="product-info">
                <span class="info-label">{isRTL ? 'السعر:' : 'Price:'}</span>
                <span class="info-value">{currentRule.buyProduct.price.toFixed(2)} {isRTL ? 'ر.س' : 'SAR'}</span>
                <span class="info-divider">|</span>
                <span class="info-label">{isRTL ? 'باركود:' : 'Barcode:'}</span>
                <span class="info-value">{currentRule.buyProduct.barcode || '-'}</span>
              </div>
            {/if}
          </div>

          <!-- Get Product (Y) -->
          <div class="form-section">
            <label class="section-label">{isRTL ? 'احصل على منتج Y' : 'Get Product Y'}</label>
            
            <div class="product-row">
              <button 
                type="button" 
                class="btn-select-product"
                on:click={() => openProductModal('get')}
              >
                {currentRule.getProduct 
                  ? (isRTL ? currentRule.getProduct.name_ar : currentRule.getProduct.name_en)
                  : (isRTL ? 'اختر المنتج' : 'Select Product')
                }
              </button>
              
              <div class="qty-group">
                <label>{isRTL ? 'الكمية' : 'Qty'}</label>
                <input 
                  type="number" 
                  min="1" 
                  bind:value={currentRule.getQuantity}
                  class="qty-input"
                />
              </div>
            </div>
            
            {#if currentRule.getProduct}
              <div class="product-info">
                <span class="info-label">{isRTL ? 'السعر:' : 'Price:'}</span>
                <span class="info-value">{currentRule.getProduct.price.toFixed(2)} {isRTL ? 'ر.س' : 'SAR'}</span>
                <span class="info-divider">|</span>
                <span class="info-label">{isRTL ? 'باركود:' : 'Barcode:'}</span>
                <span class="info-value">{currentRule.getProduct.barcode || '-'}</span>
              </div>
            {/if}
          </div>

          <!-- Discount Configuration -->
          <div class="form-section">
            <label class="section-label">{isRTL ? 'نوع الخصم' : 'Discount Type'}</label>
            
            <div class="discount-row">
              <div class="discount-type-wrapper">
                <select class="discount-select" bind:value={currentRule.discountType}>
                  <option value="free">{isRTL ? 'مجاني' : 'Free'}</option>
                  <option value="percentage">{isRTL ? 'نسبة مئوية' : 'Percentage'}</option>
                  <option value="amount">{isRTL ? 'مبلغ ثابت' : 'Fixed Amount'}</option>
                </select>
              </div>
              
              {#if currentRule.discountType !== 'free'}
                <div class="discount-value-wrapper">
                  <input 
                    type="number" 
                    min="0"
                    step="0.01"
                    bind:value={currentRule.discountValue}
                    placeholder={isRTL ? 'القيمة' : 'Value'}
                    class="value-input"
                  />
                  <span class="value-suffix">
                    {currentRule.discountType === 'percentage' ? '%' : (isRTL ? 'ر.س' : 'SAR')}
                  </span>
                </div>
              {/if}
            </div>
          </div>

          <!-- Offer Price Summary -->
          {#if currentRule.buyProduct && currentRule.getProduct}
          <div class="offer-price-summary">
            <div class="summary-row">
              <span class="summary-label">{isRTL ? 'سعر الشراء:' : 'Buy Price:'}</span>
              <span class="summary-value">{(currentRule.buyProduct.price * currentRule.buyQuantity).toFixed(2)} {isRTL ? 'ر.س' : 'SAR'}</span>
            </div>
            <div class="summary-row">
              <span class="summary-label">{isRTL ? 'سعر المنتج Y:' : 'Get Product Price:'}</span>
              <span class="summary-value">{(currentRule.getProduct.price * currentRule.getQuantity).toFixed(2)} {isRTL ? 'ر.س' : 'SAR'}</span>
            </div>
            {#if currentRule.discountType !== 'free' || (currentRule.discountType === 'free')}
            <div class="summary-row discount-row-summary">
              <span class="summary-label">{isRTL ? 'الخصم:' : 'Discount:'}</span>
              <span class="summary-value discount-value">
                {#if currentRule.discountType === 'free'}
                  -{(currentRule.getProduct.price * currentRule.getQuantity).toFixed(2)} {isRTL ? 'ر.س' : 'SAR'} ({isRTL ? 'مجاني' : 'Free'})
                {:else if currentRule.discountType === 'percentage'}
                  -{((currentRule.getProduct.price * currentRule.getQuantity * currentRule.discountValue) / 100).toFixed(2)} {isRTL ? 'ر.س' : 'SAR'} ({currentRule.discountValue}%)
                {:else if currentRule.discountType === 'amount'}
                  -{currentRule.discountValue.toFixed(2)} {isRTL ? 'ر.س' : 'SAR'}
                {/if}
              </span>
            </div>
            {/if}
            <div class="summary-row total-row">
              <span class="summary-label">{isRTL ? 'السعر النهائي للعرض:' : 'Final Offer Price:'}</span>
              <span class="summary-value total-value">{calculatedOfferPrice.toFixed(2)} {isRTL ? 'ر.س' : 'SAR'}</span>
            </div>
          </div>
          {/if}

          <!-- Form Actions -->
          <div class="form-actions">
            <button type="button" class="btn-cancel" on:click={cancelRule}>
              {isRTL ? 'إلغاء' : 'Cancel'}
            </button>
            <button type="button" class="btn-save-rule" on:click={addRule}>
              {isRTL ? 'حفظ القاعدة' : 'Save Rule'}
            </button>
          </div>
        </div>
        </div>
        {/if}

        <!-- Saved Rules -->
        {#if bogoRules.length > 0}
          <h3 class="section-title" style="margin-top: 2rem;">
            {isRTL ? 'القواعد المحفوظة' : 'Saved Rules'}
          </h3>
          
          <div class="rules-list">
            {#each bogoRules as rule}
              <div class="rule-card">
                <div class="rule-content">
                  <!-- Buy Section -->
                  <div class="rule-part buy-part">
                    <div class="part-header">
                      <span class="part-icon">🛒</span>
                      <span class="part-title">{isRTL ? 'اشتري' : 'Buy'}</span>
                    </div>
                    <div class="part-details">
                      <div class="product-name">
                        {isRTL ? rule.buyProduct.name_ar : rule.buyProduct.name_en}
                      </div>
                      <div class="product-meta">
                        <span class="qty-badge">× {rule.buyQuantity}</span>
                        <span class="price-text">{rule.buyProduct.price.toFixed(2)} {isRTL ? 'ر.س' : 'SAR'}</span>
                      </div>
                    </div>
                  </div>

                  <!-- Arrow -->
                  <div class="rule-arrow">→</div>

                  <!-- Get Section -->
                  <div class="rule-part get-part">
                    <div class="part-header">
                      <span class="part-icon">🎁</span>
                      <span class="part-title">{isRTL ? 'احصل' : 'Get'}</span>
                    </div>
                    <div class="part-details">
                      <div class="product-name">
                        {isRTL ? rule.getProduct.name_ar : rule.getProduct.name_en}
                      </div>
                      <div class="product-meta">
                        <span class="qty-badge">× {rule.getQuantity}</span>
                        <span class="discount-badge">
                          {#if rule.discountType === 'free'}
                            {isRTL ? 'مجاني' : 'Free'}
                          {:else if rule.discountType === 'percentage'}
                            {rule.discountValue}% {isRTL ? 'خصم' : 'OFF'}
                          {:else}
                            {rule.discountValue} {isRTL ? 'ر.س خصم' : 'SAR OFF'}
                          {/if}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Action Buttons -->
                <div class="rule-actions">
                  <button 
                    type="button"
                    class="btn-edit"
                    on:click={() => editRule(rule)}
                    title={isRTL ? 'تعديل' : 'Edit'}
                  >
                    ✏️
                  </button>
                  <button 
                    type="button"
                    class="btn-delete"
                    on:click={() => deleteRule(rule.id)}
                    title={isRTL ? 'حذف' : 'Delete'}
                  >
                    🗑️
                  </button>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    {/if}
  </div>

  <!-- Product Selection Modal -->
  {#if showProductModal}
    <div class="modal-overlay" on:click={closeProductModal}>
      <div class="modal-content" on:click|stopPropagation>
        <div class="modal-header">
          <h3>
            {isRTL 
              ? (selectingFor === 'buy' ? 'اختر منتج الشراء (X)' : 'اختر منتج الحصول (Y)')
              : (selectingFor === 'buy' ? 'Select Buy Product (X)' : 'Select Get Product (Y)')
            }
          </h3>
          <button type="button" class="btn-close" on:click={closeProductModal}>✕</button>
        </div>
        
        <div class="modal-search">
          <input 
            type="text" 
            bind:value={productSearchTerm}
            placeholder={isRTL ? 'ابحث عن منتج...' : 'Search products...'}
            class="search-input"
          />
        </div>
        
        <div class="modal-body">
          <table class="products-table">
            <thead>
              <tr>
                <th>{isRTL ? 'المنتج' : 'Product'}</th>
                <th>{isRTL ? 'الباركود' : 'Barcode'}</th>
                <th>{isRTL ? 'السعر' : 'Price'}</th>
                <th>{isRTL ? 'المخزون' : 'Stock'}</th>
                <th>{isRTL ? 'اختيار' : 'Select'}</th>
              </tr>
            </thead>
            <tbody>
              {#each filteredProducts as product}
                <tr>
                  <td>
                    <div class="product-cell">
                      {#if product.image_url}
                        <img src={product.image_url} alt="" class="product-img" />
                      {/if}
                      <span>{isRTL ? product.name_ar : product.name_en}</span>
                    </div>
                  </td>
                  <td>{product.barcode || '-'}</td>
                  <td>{product.price.toFixed(2)} {isRTL ? 'ر.س' : 'SAR'}</td>
                  <td>{product.stock}</td>
                  <td>
                    <button 
                      type="button"
                      class="btn-select"
                      disabled={
                        (currentRule.buyProduct && currentRule.buyProduct.id === product.id) ||
                        (currentRule.getProduct && currentRule.getProduct.id === product.id)
                      }
                      on:click={() => selectProduct(product)}
                    >
                      {isRTL ? 'اختيار' : 'Select'}
                    </button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  {/if}

  <!-- Footer Actions -->
  <div class="window-footer">
    {#if currentStep === 1}
      <button type="button" class="btn btn-next" on:click={nextStep}>
        {isRTL ? 'التالي' : 'Next'} →
      </button>
    {:else}
      <button type="button" class="btn btn-secondary" on:click={prevStep}>
        ← {isRTL ? 'السابق' : 'Previous'}
      </button>
      <button 
        type="button" 
        class="btn btn-primary" 
        disabled={bogoRules.length === 0 || loading}
        on:click={saveOffer}
      >
        {loading ? (isRTL ? 'جاري الحفظ...' : 'Saving...') : (isRTL ? 'حفظ العرض' : 'Save Offer')}
      </button>
    {/if}
  </div>
</div>

<style>
  .buy-x-get-y-window {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #f8fafc;
    overflow: hidden;
  }
  
  .buy-x-get-y-window.rtl {
    direction: rtl;
  }
  
  .window-header {
    padding: 1.5rem 2rem;
    background: white;
    border-bottom: 2px solid #e5e7eb;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.04);
  }
  
  .window-title {
    margin: 0 0 1rem 0;
    font-size: 1.5rem;
    font-weight: 700;
    color: #1e293b;
  }
  
  .step-indicator {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .step-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    opacity: 0.4;
    transition: opacity 0.2s;
  }
  
  .step-item.active {
    opacity: 1;
  }
  
  .step-item.completed {
    opacity: 0.7;
  }
  
  .step-circle {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: #e2e8f0;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    font-size: 0.9rem;
    color: #64748b;
    transition: all 0.2s;
  }
  
  .step-item.active .step-circle {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
  }
  
  .step-item.completed .step-circle {
    background: #10b981;
    color: white;
  }
  
  .step-label {
    font-size: 0.9rem;
    font-weight: 600;
    color: #475569;
  }
  
  .step-divider {
    width: 40px;
    height: 2px;
    background: #e2e8f0;
    margin: 0 0.25rem;
  }
  
  .error-banner {
    padding: 1rem 2rem;
    background: #fee2e2;
    border-bottom: 2px solid #ef4444;
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }
  
  .error-icon {
    font-size: 1.25rem;
  }
  
  .error-text {
    color: #991b1b;
    font-weight: 500;
  }
  
  .window-content {
    flex: 1;
    overflow-y: auto;
    padding: 2rem;
  }
  
  .step-content {
    width: 100%;
    margin: 0;
    max-width: none;
  }
  
  .section-title {
    font-size: 1.25rem;
    font-weight: 700;
    color: #1e293b;
    margin: 0 0 1.5rem 0;
    padding-bottom: 0.75rem;
    border-bottom: 2px solid #e5e7eb;
  }
  
  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    margin-bottom: 1.5rem;
  }
  
  .form-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  
  .form-group label {
    font-weight: 600;
    color: #475569;
    font-size: 0.95rem;
  }
  
  .required {
    color: #ef4444;
    margin-left: 0.25rem;
  }
  
  .rtl .required {
    margin-left: 0;
    margin-right: 0.25rem;
  }
  
  .timezone-hint {
    font-weight: 400;
    color: #94a3b8;
    font-size: 0.85rem;
  }
  
  .form-group input,
  .form-group textarea,
  .form-group select {
    padding: 0.75rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.95rem;
    transition: all 0.2s;
    background: white;
  }
  
  .form-group input:focus,
  .form-group textarea:focus,
  .form-group select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  .form-group textarea {
    resize: vertical;
    min-height: 80px;
    font-family: inherit;
  }
  
  .placeholder {
    text-align: center;
    padding: 4rem 2rem;
  }
  
  .placeholder-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
    animation: float 3s ease-in-out infinite;
  }
  
  @keyframes float {
    0%, 100% {
      transform: translateY(0);
    }
    50% {
      transform: translateY(-10px);
    }
  }
  
  .placeholder h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1.5rem;
    font-weight: 600;
    color: #475569;
  }
  
  .placeholder p {
    margin: 0;
    font-size: 1rem;
    color: #94a3b8;
  }
  
  .window-footer {
    padding: 1.5rem 2rem;
    background: white;
    border-top: 2px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
    gap: 1rem;
    box-shadow: 0 -2px 4px rgba(0, 0, 0, 0.04);
  }
  
  .rtl .window-footer {
    flex-direction: row-reverse;
  }
  
  .btn {
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 8px;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .btn-next,
  .btn-primary {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
  }
  
  .btn-next:hover,
  .btn-primary:hover {
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
  }
  
  .btn-secondary {
    background: #f1f5f9;
    color: #475569;
  }
  
  .btn-secondary:hover {
    background: #e2e8f0;
  }
  
  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .btn:disabled:hover {
    transform: none;
    box-shadow: none;
  }
  
  /* Step 2 Styles */
  .btn-add-new-rule {
    padding: 0.875rem 1.5rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
    margin-bottom: 1.5rem;
  }
  
  .btn-add-new-rule:hover {
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
  }
  
  .plus-icon {
    font-size: 1.125rem;
    font-weight: 700;
  }
  
  .bogo-form {
    background: white;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    padding: 2rem;
    width: 100%;
  }
  
  .rule-form-container {
    animation: slideDown 0.3s ease-out;
  }
  
  @keyframes slideDown {
    from {
      opacity: 0;
      transform: translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
  
  .form-subtitle {
    margin: 0 0 1.5rem 0;
    font-size: 1.125rem;
    font-weight: 600;
    color: #1e293b;
  }
  
  .form-section {
    margin-bottom: 1.5rem;
    padding-bottom: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .form-section:last-of-type {
    border-bottom: none;
  }
  
  .section-label {
    display: block;
    font-weight: 600;
    color: #475569;
    margin-bottom: 0.75rem;
    font-size: 0.95rem;
  }
  
  .product-row {
    display: grid;
    grid-template-columns: 1fr 180px;
    gap: 1rem;
    align-items: flex-end;
  }
  
  .btn-select-product {
    padding: 1rem 1.25rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    background: white;
    font-size: 0.95rem;
    text-align: left;
    cursor: pointer;
    transition: all 0.2s;
    color: #1e293b;
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    height: 52px;
    display: flex;
    align-items: center;
  }
  
  .rtl .btn-select-product {
    text-align: right;
  }
  
  .btn-select-product:hover {
    border-color: #3b82f6;
    background: #f0f9ff;
  }
  
  .qty-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    width: 100%;
  }
  
  .qty-group label {
    font-size: 0.875rem;
    font-weight: 600;
    color: #64748b;
  }
  
  .qty-input {
    width: 100%;
    padding: 1rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.95rem;
    text-align: center;
    font-weight: 600;
    height: 52px;
  }
  
  .qty-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  .product-info {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-top: 0.75rem;
    padding: 0.75rem;
    background: #f8fafc;
    border-radius: 6px;
    font-size: 0.875rem;
  }
  
  .info-label {
    color: #64748b;
    font-weight: 500;
  }
  
  .info-value {
    color: #1e293b;
    font-weight: 600;
  }
  
  .info-divider {
    color: #cbd5e1;
    margin: 0 0.25rem;
  }
  
  .discount-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
    align-items: flex-start;
  }
  
  .discount-type-wrapper {
    width: 100%;
  }
  
  .discount-select {
    width: 100%;
    padding: 1rem 1.25rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.95rem;
    background: white;
    cursor: pointer;
    font-weight: 500;
  }
  
  .discount-select:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  .discount-value-wrapper {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    width: 100%;
  }
  
  .value-input {
    flex: 1;
    padding: 1rem 1.25rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.95rem;
    font-weight: 500;
  }
  
  .value-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  .value-suffix {
    font-weight: 700;
    color: #64748b;
    min-width: 50px;
    text-align: center;
    font-size: 1rem;
  }
  
  /* Offer Price Summary */
  .offer-price-summary {
    background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
    border: 2px solid #3b82f6;
    border-radius: 12px;
    padding: 1.5rem;
    margin: 1.5rem 0;
  }
  
  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 0;
    border-bottom: 1px solid #bae6fd;
  }
  
  .summary-row:last-child {
    border-bottom: none;
  }
  
  .summary-label {
    font-size: 0.95rem;
    color: #475569;
    font-weight: 500;
  }
  
  .summary-value {
    font-size: 1rem;
    color: #1e293b;
    font-weight: 600;
  }
  
  .discount-row-summary .summary-value {
    color: #10b981;
  }
  
  .total-row {
    margin-top: 0.5rem;
    padding-top: 1rem;
    border-top: 2px solid #3b82f6;
    border-bottom: none;
  }
  
  .total-row .summary-label {
    font-size: 1.125rem;
    font-weight: 700;
    color: #1e293b;
  }
  
  .total-row .total-value {
    font-size: 1.5rem;
    font-weight: 800;
    color: #3b82f6;
  }
  
  .form-actions {
    display: grid;
    grid-template-columns: 1fr 2fr;
    gap: 1rem;
    margin-top: 2rem;
    padding-top: 2rem;
    border-top: 2px solid #e5e7eb;
  }
  
  .btn-cancel {
    padding: 1rem 1.5rem;
    background: white;
    color: #64748b;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .btn-cancel:hover {
    background: #f8fafc;
    border-color: #cbd5e1;
    color: #475569;
  }
  
  .btn-save-rule {
    padding: 1rem 1.5rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .btn-save-rule:hover {
    background: linear-gradient(135deg, #059669 0%, #047857 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  }
  
  /* Rules List */
  .rules-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  
  .rule-card {
    background: white;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    padding: 1.5rem;
    position: relative;
    transition: all 0.2s;
  }
  
  .rule-card:hover {
    border-color: #3b82f6;
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.1);
  }
  
  .rule-content {
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    gap: 1.5rem;
    align-items: center;
  }
  
  .rule-part {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  
  .part-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .part-icon {
    font-size: 1.25rem;
  }
  
  .part-title {
    font-weight: 700;
    color: #64748b;
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  
  .part-details {
    padding: 1rem;
    background: #f8fafc;
    border-radius: 8px;
  }
  
  .buy-part .part-details {
    background: #fef3c7;
    border: 1px solid #fbbf24;
  }
  
  .get-part .part-details {
    background: #dcfce7;
    border: 1px solid #86efac;
  }
  
  .product-name {
    font-weight: 600;
    color: #1e293b;
    margin-bottom: 0.5rem;
  }
  
  .product-meta {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }
  
  .qty-badge {
    padding: 0.25rem 0.75rem;
    background: white;
    border-radius: 6px;
    font-weight: 700;
    color: #3b82f6;
    font-size: 0.875rem;
  }
  
  .price-text {
    font-weight: 600;
    color: #64748b;
    font-size: 0.875rem;
  }
  
  .discount-badge {
    padding: 0.25rem 0.75rem;
    background: #15803d;
    color: white;
    border-radius: 6px;
    font-weight: 700;
    font-size: 0.875rem;
  }
  
  .rule-arrow {
    font-size: 2rem;
    color: #3b82f6;
    font-weight: 700;
  }
  
  .rule-actions {
    position: absolute;
    top: 1rem;
    right: 1rem;
    display: flex;
    gap: 0.5rem;
  }
  
  .rtl .rule-actions {
    right: auto;
    left: 1rem;
  }
  
  .btn-edit,
  .btn-delete {
    background: white;
    border: 2px solid #3b82f6;
    border-radius: 8px;
    padding: 0.5rem 0.75rem;
    cursor: pointer;
    font-size: 1.125rem;
    transition: all 0.2s;
  }
  
  .btn-edit {
    border-color: #3b82f6;
  }
  
  .btn-delete {
    border-color: #ef4444;
  }
  
  .btn-edit:hover {
    background: #3b82f6;
    transform: scale(1.1);
  }
  
  .btn-delete:hover {
    background: #ef4444;
    transform: scale(1.1);
  }
  
  /* Modal Styles */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 2rem;
  }
  
  .modal-content {
    background: white;
    border-radius: 12px;
    width: 100%;
    max-width: 1200px;
    max-height: 85vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  }
  
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.5rem;
    border-bottom: 2px solid #e5e7eb;
  }
  
  .modal-header h3 {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 700;
    color: #1e293b;
  }
  
  .btn-close {
    background: transparent;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #64748b;
    padding: 0.25rem 0.5rem;
    transition: all 0.2s;
  }
  
  .btn-close:hover {
    color: #ef4444;
    transform: scale(1.1);
  }
  
  .modal-search {
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .search-input {
    width: 100%;
    padding: 0.875rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.95rem;
  }
  
  .search-input:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }
  
  .modal-body {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
  }
  
  .products-table {
    width: 100%;
    border-collapse: collapse;
  }
  
  .products-table th {
    padding: 0.875rem;
    text-align: left;
    font-weight: 600;
    color: #475569;
    background: #f8fafc;
    border-bottom: 2px solid #e5e7eb;
    font-size: 0.875rem;
    position: sticky;
    top: 0;
  }
  
  .rtl .products-table th {
    text-align: right;
  }
  
  .products-table td {
    padding: 1rem 0.875rem;
    border-bottom: 1px solid #e5e7eb;
    font-size: 0.9rem;
  }
  
  .products-table tr:hover {
    background: #f8fafc;
  }
  
  .product-cell {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }
  
  .product-img {
    width: 40px;
    height: 40px;
    object-fit: cover;
    border-radius: 6px;
    border: 1px solid #e5e7eb;
  }
  
  .btn-select {
    padding: 0.5rem 1.25rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .btn-select:hover:not(:disabled) {
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
  }
  
  .btn-select:disabled {
    background: #e5e7eb;
    color: #9ca3af;
    cursor: not-allowed;
    opacity: 0.6;
  }
</style>

