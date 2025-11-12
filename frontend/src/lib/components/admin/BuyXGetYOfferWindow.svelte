<script lang="ts">
  import { onMount } from 'svelte';
  import { currentLocale } from '$lib/i18n';
  import { supabase, supabaseAdmin } from '$lib/utils/supabase';
  
  // Props
  export let editMode = false;
  export let offerId: number | null = null;
  
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
  
  // Step 2: Buy X Get Y Configuration
  let bogoRules: any[] = [];
  let currentRule = {
    buyProduct: null as any,
    buyQuantity: 1,
    getProduct: null as any,
    discountType: 'free' as 'free' | 'percentage' | 'amount',
    discountValue: 0
  };
  
  // Reactive locale
  $: locale = $currentLocale;
  $: isRTL = locale === 'ar';
  
  $: filteredProducts = products.filter(p =>
    !productSearchTerm ||
    p.barcode?.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
    p.name_ar.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
    p.name_en.toLowerCase().includes(productSearchTerm.toLowerCase())
  );
  
  onMount(async () => {
    await loadBranches();
    await loadProducts();
    if (editMode && offerId) {
      await loadOfferData();
    }
  });
  
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
  
  function openProductModal() {
    showProductModal = true;
    productSearchTerm = '';
  }
  
  function closeProductModal() {
    showProductModal = false;
  }
  
  function selectBuyProduct(product: any) {
    currentRule.buyProduct = product;
    closeProductModal();
  }
  
  function selectGetProduct(product: any) {
    currentRule.getProduct = product;
    closeProductModal();
  }
  
  function calculateOfferPrice() {
    if (!currentRule.buyProduct || !currentRule.getProduct) {
      return 0;
    }
    
    const buyTotal = currentRule.buyProduct.price * currentRule.buyQuantity;
    let getPrice = currentRule.getProduct.price;
    
    if (currentRule.discountType === 'free') {
      getPrice = 0;
    } else if (currentRule.discountType === 'percentage') {
      getPrice = getPrice * (1 - currentRule.discountValue / 100);
    } else if (currentRule.discountType === 'amount') {
      getPrice = Math.max(0, getPrice - currentRule.discountValue);
    }
    
    return buyTotal + getPrice;
  }
  
  function addRule() {
    if (!currentRule.buyProduct) {
      error = isRTL ? 'يرجى اختيار منتج الشراء' : 'Please select a buy product';
      return;
    }
    
    if (!currentRule.getProduct) {
      error = isRTL ? 'يرجى اختيار منتج الحصول' : 'Please select a get product';
      return;
    }
    
    if (currentRule.buyQuantity < 1) {
      error = isRTL ? 'الكمية يجب أن تكون 1 على الأقل' : 'Quantity must be at least 1';
      return;
    }
    
    const offerPrice = calculateOfferPrice();
    
    bogoRules = [...bogoRules, {
      ...currentRule,
      offerPrice,
      id: Date.now()
    }];
    
    // Reset form
    currentRule = {
      buyProduct: null,
      buyQuantity: 1,
      getProduct: null,
      discountType: 'free',
      discountValue: 0
    };
    
    error = null;
  }
  
  function deleteRule(id: number) {
    bogoRules = bogoRules.filter(r => r.id !== id);
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
        <div class="bogo-form-card">
          <div class="bogo-form-header">
            <h4>{isRTL ? 'إضافة قاعدة جديدة' : 'Add New Rule'}</h4>
          </div>
          
          <div class="bogo-form-body">
            <!-- Buy Product Selection -->
            <div class="product-selection-group">
              <label class="form-label">
                {isRTL ? 'اشتري منتج N' : 'Buy N Product'}
                <span class="required">*</span>
              </label>
              
              <div class="product-select-row">
                <button 
                  type="button" 
                  class="btn-select-product"
                  on:click={() => {
                    showProductModal = true;
                    productSearchTerm = '';
                  }}
                >
                  {currentRule.buyProduct 
                    ? (isRTL ? currentRule.buyProduct.name_ar : currentRule.buyProduct.name_en)
                    : (isRTL ? 'اختر المنتج' : 'Select Product')
                  }
                </button>
                
                <div class="quantity-input-group">
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
                <div class="product-preview">
                  <span class="product-price">{currentRule.buyProduct.price.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
                  <span class="product-barcode">{currentRule.buyProduct.barcode || '-'}</span>
                </div>
              {/if}
            </div>

            <!-- Get Product Selection -->
            <div class="product-selection-group">
              <label class="form-label">
                {isRTL ? 'احصل على منتج Y' : 'Get Y Product'}
                <span class="required">*</span>
              </label>
              
              <button 
                type="button" 
                class="btn-select-product"
                on:click={() => {
                  showProductModal = true;
                  productSearchTerm = '';
                }}
              >
                {currentRule.getProduct 
                  ? (isRTL ? currentRule.getProduct.name_ar : currentRule.getProduct.name_en)
                  : (isRTL ? 'اختر المنتج' : 'Select Product')
                }
              </button>
              
              {#if currentRule.getProduct}
                <div class="product-preview">
                  <span class="product-price">{currentRule.getProduct.price.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
                  <span class="product-barcode">{currentRule.getProduct.barcode || '-'}</span>
                </div>
              {/if}
            </div>

            <!-- Discount Configuration -->
            <div class="discount-config">
              <label class="form-label">
                {isRTL ? 'نوع الخصم' : 'Discount Type'}
              </label>
              
              <div class="discount-type-options">
                <label class="radio-option">
                  <input 
                    type="radio" 
                    bind:group={currentRule.discountType} 
                    value="free"
                    on:change={() => currentRule.discountValue = 0}
                  />
                  <span>{isRTL ? 'مجاني' : 'Free'}</span>
                </label>
                
                <label class="radio-option">
                  <input 
                    type="radio" 
                    bind:group={currentRule.discountType} 
                    value="percentage"
                  />
                  <span>{isRTL ? 'نسبة مئوية' : 'Percentage'}</span>
                </label>
                
                <label class="radio-option">
                  <input 
                    type="radio" 
                    bind:group={currentRule.discountType} 
                    value="amount"
                  />
                  <span>{isRTL ? 'مبلغ ثابت' : 'Fixed Amount'}</span>
                </label>
              </div>
              
              {#if currentRule.discountType !== 'free'}
                <div class="discount-value-input">
                  <input 
                    type="number" 
                    min="0"
                    max={currentRule.discountType === 'percentage' ? 100 : currentRule.getProduct?.price || 0}
                    step="0.01"
                    bind:value={currentRule.discountValue}
                    placeholder={currentRule.discountType === 'percentage' 
                      ? (isRTL ? 'أدخل النسبة (0-100)' : 'Enter percentage (0-100)')
                      : (isRTL ? 'أدخل المبلغ' : 'Enter amount')
                    }
                  />
                  <span class="input-suffix">
                    {currentRule.discountType === 'percentage' ? '%' : (isRTL ? 'ريال' : 'SAR')}
                  </span>
                </div>
              {/if}
            </div>

            <!-- Calculated Price -->
            {#if currentRule.buyProduct && currentRule.getProduct}
              <div class="calculated-price">
                <span class="price-label">{isRTL ? 'سعر العرض:' : 'Offer Price:'}</span>
                <span class="price-value">{calculateOfferPrice().toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
              </div>
            {/if}

            <!-- Add Button -->
            <button 
              type="button" 
              class="btn btn-add-rule"
              on:click={addRule}
              disabled={!currentRule.buyProduct || !currentRule.getProduct}
            >
              {isRTL ? '+ إضافة القاعدة' : '+ Add Rule'}
            </button>
          </div>
        </div>

        <!-- Saved Rules -->
        {#if bogoRules.length > 0}
          <h3 class="section-title" style="margin-top: 2rem;">
            {isRTL ? 'القواعد المضافة' : 'Added Rules'}
          </h3>
          
          <div class="rules-grid">
            {#each bogoRules as rule}
              <div class="rule-card">
                <div class="rule-header">
                  <h4>{isRTL ? 'اشتري واحصل' : 'Buy & Get'}</h4>
                  <button 
                    type="button"
                    class="btn-delete-rule"
                    on:click={() => deleteRule(rule.id)}
                  >
                    🗑️
                  </button>
                </div>
                
                <div class="rule-content">
                  <div class="rule-section">
                    <span class="rule-label">{isRTL ? 'اشتري:' : 'Buy:'}</span>
                    <div class="rule-product">
                      <span class="product-name">
                        {isRTL ? rule.buyProduct.name_ar : rule.buyProduct.name_en}
                      </span>
                      <span class="product-qty">x{rule.buyQuantity}</span>
                    </div>
                  </div>
                  
                  <div class="rule-arrow">→</div>
                  
                  <div class="rule-section">
                    <span class="rule-label">{isRTL ? 'احصل على:' : 'Get:'}</span>
                    <div class="rule-product">
                      <span class="product-name">
                        {isRTL ? rule.getProduct.name_ar : rule.getProduct.name_en}
                      </span>
                      <span class="discount-badge">
                        {#if rule.discountType === 'free'}
                          {isRTL ? 'مجاني' : 'Free'}
                        {:else if rule.discountType === 'percentage'}
                          {rule.discountValue}%
                        {:else}
                          -{rule.discountValue.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}
                        {/if}
                      </span>
                    </div>
                  </div>
                  
                  <div class="rule-price">
                    <span class="price-label">{isRTL ? 'سعر العرض:' : 'Offer Price:'}</span>
                    <span class="price-value">{rule.offerPrice.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
                  </div>
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
          <h3>{isRTL ? 'اختر المنتج' : 'Select Product'}</h3>
          <button type="button" class="btn-close-modal" on:click={closeProductModal}>✕</button>
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
          <div class="products-table">
            <table>
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
                          <img src={product.image_url} alt="" class="product-thumb" />
                        {/if}
                        <span>{isRTL ? product.name_ar : product.name_en}</span>
                      </div>
                    </td>
                    <td>{product.barcode || '-'}</td>
                    <td>{product.price.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</td>
                    <td>{product.stock}</td>
                    <td>
                      <button 
                        type="button"
                        class="btn-select"
                        on:click={() => {
                          if (!currentRule.buyProduct) {
                            selectBuyProduct(product);
                          } else {
                            selectGetProduct(product);
                          }
                        }}
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
      <button type="button" class="btn btn-primary" disabled>
        {isRTL ? 'حفظ العرض' : 'Save Offer'}
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
    max-width: 1000px;
    margin: 0 auto;
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
  
  /* Step 2: BOGO Configuration Styles */
  .bogo-form-card {
    background: white;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    overflow: hidden;
  }
  
  .bogo-form-header {
    padding: 1rem 1.5rem;
    background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
    border-bottom: 2px solid #e5e7eb;
  }
  
  .bogo-form-header h4 {
    margin: 0;
    font-size: 1.125rem;
    font-weight: 600;
    color: #1e293b;
  }
  
  .bogo-form-body {
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  
  .product-selection-group {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  
  .form-label {
    font-weight: 600;
    color: #475569;
    font-size: 0.95rem;
  }
  
  .product-select-row {
    display: flex;
    gap: 1rem;
    align-items: flex-start;
  }
  
  .btn-select-product {
    flex: 1;
    padding: 0.875rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    background: white;
    font-size: 0.95rem;
    text-align: left;
    cursor: pointer;
    transition: all 0.2s;
    color: #64748b;
  }
  
  .rtl .btn-select-product {
    text-align: right;
  }
  
  .btn-select-product:hover {
    border-color: #3b82f6;
    background: #f0f9ff;
  }
  
  .quantity-input-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
    min-width: 120px;
  }
  
  .quantity-input-group label {
    font-size: 0.85rem;
    font-weight: 600;
    color: #64748b;
  }
  
  .qty-input {
    padding: 0.875rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.95rem;
    text-align: center;
  }
  
  .product-preview {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem;
    background: #f8fafc;
    border-radius: 6px;
  }
  
  .product-price {
    font-weight: 700;
    color: #10b981;
    font-size: 1rem;
  }
  
  .product-barcode {
    font-size: 0.875rem;
    color: #94a3b8;
  }
  
  .discount-config {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  
  .discount-type-options {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
  }
  
  .radio-option {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.75rem 1.25rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .radio-option:hover {
    border-color: #3b82f6;
    background: #f0f9ff;
  }
  
  .radio-option input[type="radio"] {
    cursor: pointer;
  }
  
  .radio-option input[type="radio"]:checked + span {
    color: #3b82f6;
    font-weight: 600;
  }
  
  .discount-value-input {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .discount-value-input input {
    flex: 1;
    padding: 0.875rem;
    border: 2px solid #e2e8f0;
    border-radius: 8px;
    font-size: 0.95rem;
  }
  
  .input-suffix {
    font-weight: 600;
    color: #64748b;
    min-width: 50px;
    text-align: center;
  }
  
  .calculated-price {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem;
    background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
    border-radius: 8px;
    border: 2px solid #86efac;
  }
  
  .price-label {
    font-weight: 600;
    color: #166534;
  }
  
  .price-value {
    font-size: 1.5rem;
    font-weight: 700;
    color: #15803d;
  }
  
  .btn-add-rule {
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
  }
  
  .btn-add-rule:hover:not(:disabled) {
    background: linear-gradient(135deg, #059669 0%, #047857 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  }
  
  /* Rules Grid */
  .rules-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
    gap: 1.5rem;
  }
  
  .rule-card {
    background: white;
    border: 2px solid #e5e7eb;
    border-radius: 12px;
    overflow: hidden;
    transition: all 0.2s;
  }
  
  .rule-card:hover {
    border-color: #3b82f6;
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.1);
  }
  
  .rule-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.25rem;
    background: #f8fafc;
    border-bottom: 2px solid #e5e7eb;
  }
  
  .rule-header h4 {
    margin: 0;
    font-size: 1rem;
    font-weight: 600;
    color: #1e293b;
  }
  
  .btn-delete-rule {
    background: transparent;
    border: 1px solid #ef4444;
    border-radius: 6px;
    padding: 0.375rem 0.75rem;
    cursor: pointer;
    font-size: 1.1rem;
    transition: all 0.2s;
  }
  
  .btn-delete-rule:hover {
    background: #ef4444;
    transform: scale(1.1);
  }
  
  .rule-content {
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  
  .rule-section {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  
  .rule-label {
    font-size: 0.875rem;
    font-weight: 600;
    color: #64748b;
  }
  
  .rule-product {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem;
    background: #f8fafc;
    border-radius: 6px;
  }
  
  .product-name {
    font-weight: 600;
    color: #1e293b;
  }
  
  .product-qty {
    font-weight: 700;
    color: #3b82f6;
  }
  
  .discount-badge {
    padding: 0.25rem 0.75rem;
    background: #dcfce7;
    color: #166534;
    border-radius: 6px;
    font-weight: 700;
    font-size: 0.875rem;
  }
  
  .rule-arrow {
    text-align: center;
    font-size: 1.5rem;
    color: #94a3b8;
  }
  
  .rule-price {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.875rem;
    background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
    border-radius: 6px;
    margin-top: 0.5rem;
  }
  
  .rule-price .price-label {
    font-weight: 600;
    color: #166534;
    font-size: 0.875rem;
  }
  
  .rule-price .price-value {
    font-size: 1.25rem;
    font-weight: 700;
    color: #15803d;
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
    max-width: 900px;
    max-height: 80vh;
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
  
  .btn-close-modal {
    background: transparent;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #64748b;
    padding: 0.25rem 0.5rem;
    transition: all 0.2s;
  }
  
  .btn-close-modal:hover {
    color: #ef4444;
    transform: scale(1.1);
  }
  
  .modal-search {
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .search-input {
    width: 100%;
    padding: 0.75rem;
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
    overflow-x: auto;
  }
  
  .products-table table {
    width: 100%;
    border-collapse: collapse;
  }
  
  .products-table th {
    padding: 0.75rem;
    text-align: left;
    font-weight: 600;
    color: #475569;
    background: #f8fafc;
    border-bottom: 2px solid #e5e7eb;
    font-size: 0.875rem;
  }
  
  .rtl .products-table th {
    text-align: right;
  }
  
  .products-table td {
    padding: 0.875rem 0.75rem;
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
  
  .product-thumb {
    width: 40px;
    height: 40px;
    object-fit: cover;
    border-radius: 6px;
    border: 1px solid #e5e7eb;
  }
  
  .btn-select {
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .btn-select:hover {
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
  }
</style>
