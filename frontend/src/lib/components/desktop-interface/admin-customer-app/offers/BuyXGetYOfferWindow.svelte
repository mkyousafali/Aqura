<script lang="ts">
  import { onMount, createEventDispatcher } from 'svelte';
  import { currentLocale } from '$lib/i18n';
  import { supabase } from '$lib/utils/supabase';
  
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
    start_date: getSaudiLocalDateTime(),
    end_date: getSaudiLocalDateTime(30),
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
  let previewImageUrl: string | null = null;
  
  // Get current Saudi local time in datetime-local format
  function getSaudiLocalDateTime(daysToAdd: number = 0): string {
    const now = new Date();
    // Add days if specified
    now.setDate(now.getDate() + daysToAdd);
    
    // Convert to Saudi time (UTC+3)
    const saudiTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
    
    // Format as datetime-local (YYYY-MM-DDTHH:mm)
    const year = saudiTime.getFullYear();
    const month = String(saudiTime.getMonth() + 1).padStart(2, '0');
    const day = String(saudiTime.getDate()).padStart(2, '0');
    const hours = String(saudiTime.getHours()).padStart(2, '0');
    const minutes = String(saudiTime.getMinutes()).padStart(2, '0');
    
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  }
  
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
      p.name_en.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
      p.product_serial?.toLowerCase().includes(productSearchTerm.toLowerCase());
    
    // Exclude products used in OTHER offers
    const notUsedInOtherOffers = !usedProductIds.has(p.id);
    
    return matchesSearch && notUsedInOtherOffers;
  }).sort((a, b) => {
    const serialA = a.product_serial || '';
    const serialB = b.product_serial || '';
    return serialA.localeCompare(serialB);
  });
  
  onMount(async () => {
    await loadBranches();
    await loadProductsData();
    if (editMode && offerId) {
      await loadOfferData();
    }
  });
  
  // Load all products + used product IDs via single RPC
  async function loadProductsData() {
    loading = true;
    try {
      const { data, error: err } = await supabase.rpc('get_offer_products_data', {
        p_exclude_offer_id: offerId || 0
      });
      
      if (err) {
        console.error('Error loading products data:', err);
        return;
      }
      
      if (data) {
        products = (data.products || []).map((p: any) => ({
          id: p.id,
          name_ar: p.product_name_ar,
          name_en: p.product_name_en,
          barcode: p.barcode,
          product_serial: p.barcode || '',
          price: parseFloat(p.sale_price) || 0,
          cost: parseFloat(p.cost) || 0,
          unit_name_en: p.unit_name_en || '',
          unit_name_ar: p.unit_name_ar || '',
          unit_qty: p.unit_qty || 1,
          image_url: p.image_url,
          stock: p.current_stock || 0
        }));
        
        usedProductIds = new Set(data.products_in_other_offers || []);
      }
    } finally {
      loading = false;
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
  
  // Convert Saudi time from datetime-local input to UTC for database storage
  function toUTCFromSaudiInput(saudiTimeString) {
    // Parse the datetime-local input (assumed to be Saudi time)
    const [datePart, timePart] = saudiTimeString.split('T');
    const [year, month, day] = datePart.split('-').map(Number);
    const [hours, minutes] = timePart.split(':').map(Number);
    
    // Create ISO string for Saudi timezone and parse it
    const saudiISOString = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`;
    
    // Parse as if it's UTC, then subtract 3 hours (Saudi is UTC+3)
    const tempDate = new Date(saudiISOString + 'Z');
    const utcDate = new Date(tempDate.getTime() - (3 * 60 * 60 * 1000));
    
    return utcDate.toISOString();
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

    const { data: rules, error: err } = await supabase
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

    // Don't auto-skip to step 2 in edit mode - let user review step 1 first
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
      const offerPayload = {
        type: 'bogo',
        name_ar: offerData.name_ar,
        name_en: offerData.name_en,
        description_ar: offerData.description_ar,
        description_en: offerData.description_en,
        start_date: toUTCFromSaudiInput(offerData.start_date),
        end_date: toUTCFromSaudiInput(offerData.end_date),
        branch_id: offerData.branch_id,
        service_type: offerData.service_type,
        is_active: offerData.is_active,
        show_on_product_page: true,
        show_in_carousel: true,
        send_push_notification: false
      };
      
      let offer;
      
      if (editMode && offerId) {

        // Update existing offer
        const { data, error: offerError } = await supabase
          .from('offers')
          .update(offerPayload)
          .eq('id', offerId)
          .select()
          .single();
        
        if (offerError) throw offerError;
        offer = data;
        
        // Delete existing BOGO rules before creating new ones
        const { error: deleteError } = await supabase
          .from('bogo_offer_rules')
          .delete()
          .eq('offer_id', offerId);
        
        if (deleteError) throw deleteError;
      } else {
        // Create new offer
        const { data, error: offerError } = await supabase
          .from('offers')
          .insert(offerPayload)
          .select()
          .single();
        
        if (offerError) throw offerError;
        offer = data;
      }
      
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
      
      const { error: rulesError } = await supabase
        .from('bogo_offer_rules')
        .insert(rulesPayload);
      
      if (rulesError) throw rulesError;
      
      // Success!
      alert(editMode
        ? (isRTL 
          ? '✅ تم تحديث عرض اشتري واحصل بنجاح!'
          : '✅ Buy X Get Y offer updated successfully!')
        : (isRTL 
          ? '✅ تم إنشاء عرض اشتري واحصل بنجاح!'
          : '✅ Buy X Get Y offer created successfully!')
      );
      
      // Broadcast to customer displays to refresh offers
      if (typeof BroadcastChannel !== 'undefined') {
        const channel = new BroadcastChannel('aqura-offers-update');
        channel.postMessage('refresh-offers');
        channel.close();
      }
      
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

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRTL ? 'rtl' : 'ltr'}>
  <!-- Header -->
  <div class="bg-gradient-to-r from-violet-500 to-purple-600 px-6 py-4 text-white relative overflow-hidden">
    <div class="absolute inset-0 bg-[radial-gradient(circle_at_30%_50%,rgba(255,255,255,0.1),transparent_70%)]"></div>
    <div class="relative flex items-center justify-between">
      <div>
        <h2 class="text-lg font-black tracking-wide">
          {editMode
            ? isRTL ? '🎁 تعديل عرض اشتري واحصل' : '🎁 Edit Buy X Get Y Offer'
            : isRTL ? '🎁 إنشاء عرض اشتري واحصل' : '🎁 Create Buy X Get Y Offer'}
        </h2>
      </div>
      <!-- Step Indicator -->
      <div class="flex items-center gap-3">
        <button class="flex items-center gap-2 transition-opacity" class:opacity-100={currentStep === 1} class:opacity-50={currentStep !== 1} on:click={() => { if (currentStep > 1) prevStep(); }}>
          <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all {currentStep >= 1 ? 'bg-white text-violet-600' : 'bg-white/20 text-white'}">1</div>
          <span class="text-xs font-semibold hidden sm:inline">{isRTL ? 'تفاصيل العرض' : 'Details'}</span>
        </button>
        <div class="w-8 h-0.5 {currentStep >= 2 ? 'bg-white' : 'bg-white/30'}"></div>
        <div class="flex items-center gap-2 transition-opacity" class:opacity-100={currentStep === 2} class:opacity-50={currentStep !== 2}>
          <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all {currentStep >= 2 ? 'bg-white text-violet-600' : 'bg-white/20 text-white'}">2</div>
          <span class="text-xs font-semibold hidden sm:inline">{isRTL ? 'الإعدادات' : 'Config'}</span>
        </div>
      </div>
    </div>
  </div>

  {#if error}
    <div class="px-6 py-3 bg-red-50 border-b border-red-200 text-red-700 text-sm font-semibold flex items-center gap-2">
      <span>⚠️</span> {error}
    </div>
  {/if}

  {#if currentStep === 1}
    <!-- Step 1: Offer Details -->
    <div class="flex-1 overflow-y-auto p-6">
      <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-6 max-w-3xl mx-auto space-y-5">
        <h3 class="text-sm font-black text-slate-700 uppercase tracking-wider">{isRTL ? 'معلومات العرض الأساسية' : 'Basic Offer Information'}</h3>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-1.5">
            <label for="name_ar" class="text-xs font-bold text-slate-600">{isRTL ? 'اسم العرض (عربي)' : 'Offer Name (Arabic)'} <span class="text-red-500">*</span></label>
            <input type="text" id="name_ar" bind:value={offerData.name_ar} placeholder={isRTL ? 'أدخل اسم العرض بالعربية' : 'Enter offer name in Arabic'} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label for="name_en" class="text-xs font-bold text-slate-600">{isRTL ? 'اسم العرض (إنجليزي)' : 'Offer Name (English)'} <span class="text-red-500">*</span></label>
            <input type="text" id="name_en" bind:value={offerData.name_en} placeholder={isRTL ? 'أدخل اسم العرض بالإنجليزية' : 'Enter offer name in English'} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-1.5">
            <label for="desc_ar" class="text-xs font-bold text-slate-600">{isRTL ? 'وصف العرض (عربي)' : 'Description (Arabic)'}</label>
            <textarea id="desc_ar" bind:value={offerData.description_ar} placeholder={isRTL ? 'أدخل وصف العرض بالعربية (اختياري)' : 'Enter description in Arabic (optional)'} rows="3" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80 resize-y font-sans"></textarea>
          </div>
          <div class="flex flex-col gap-1.5">
            <label for="desc_en" class="text-xs font-bold text-slate-600">{isRTL ? 'وصف العرض (إنجليزي)' : 'Description (English)'}</label>
            <textarea id="desc_en" bind:value={offerData.description_en} placeholder={isRTL ? 'أدخل وصف العرض بالإنجليزية (اختياري)' : 'Enter description in English (optional)'} rows="3" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80 resize-y font-sans"></textarea>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-1.5">
            <label for="start_date" class="text-xs font-bold text-slate-600">{isRTL ? 'تاريخ البدء' : 'Start Date'} <span class="text-red-500">*</span></label>
            <input type="datetime-local" id="start_date" bind:value={offerData.start_date} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label for="end_date" class="text-xs font-bold text-slate-600">{isRTL ? 'تاريخ الانتهاء' : 'End Date'} <span class="text-red-500">*</span></label>
            <input type="datetime-local" id="end_date" bind:value={offerData.end_date} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-1.5">
            <label for="branch" class="text-xs font-bold text-slate-600">{isRTL ? 'الفرع المستهدف' : 'Target Branch'}</label>
            <select id="branch" bind:value={offerData.branch_id} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80">
              <option value={null}>{isRTL ? 'جميع الفروع' : 'All Branches'}</option>
              {#each branches as branch}
                <option value={branch.id}>{isRTL ? branch.name_ar : branch.name_en}</option>
              {/each}
            </select>
          </div>
          <div class="flex flex-col gap-1.5">
            <label for="service_type" class="text-xs font-bold text-slate-600">{isRTL ? 'نوع الخدمة' : 'Service Type'}</label>
            <select id="service_type" bind:value={offerData.service_type} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80">
              <option value="both">{isRTL ? 'التوصيل والاستلام' : 'Delivery & Pickup'}</option>
              <option value="delivery">{isRTL ? 'التوصيل فقط' : 'Delivery Only'}</option>
              <option value="pickup">{isRTL ? 'الاستلام فقط' : 'Pickup Only'}</option>
            </select>
          </div>
        </div>
      </div>
    </div>
  {:else if currentStep === 2}
    <!-- Step 2: Buy X Get Y Configuration -->
    <div class="flex-1 overflow-y-auto p-6 space-y-4">
      <h3 class="text-sm font-black text-slate-700 uppercase tracking-wider px-1">🎁 {isRTL ? 'إعدادات اشتري واحصل' : 'Buy X Get Y Configuration'}</h3>

      <!-- Add Rule Button -->
      {#if !showRuleForm}
        <button type="button" class="px-5 py-2.5 bg-violet-500 text-white rounded-xl text-xs font-bold hover:bg-violet-600 transition-all active:scale-95 shadow-md inline-flex items-center gap-2" on:click={startNewRule}>
          <span class="text-base font-bold">+</span> {isRTL ? 'إضافة قاعدة جديدة' : 'Add New Rule'}
        </button>
      {/if}

      <!-- Rule Form -->
      {#if showRuleForm}
        <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-6 space-y-5">
          <h4 class="text-sm font-bold text-slate-700">{isRTL ? 'إضافة قاعدة جديدة' : 'Add New Rule'}</h4>

          <!-- Buy Product (X) -->
          <div class="space-y-3 pb-4 border-b border-slate-200">
            <span class="text-xs font-bold text-violet-700 uppercase tracking-wider">{isRTL ? '🛒 اشتري منتج X' : '🛒 Buy Product X'}</span>
            <div class="grid grid-cols-[1fr_140px] gap-3">
              <button type="button" class="px-4 py-2.5 border-2 border-slate-200 rounded-xl text-sm {isRTL ? 'text-right' : 'text-left'} bg-white/80 hover:border-violet-400 hover:bg-violet-50/50 transition-all truncate font-medium" on:click={() => openProductModal('buy')}>
                {currentRule.buyProduct ? (isRTL ? currentRule.buyProduct.name_ar : currentRule.buyProduct.name_en) : (isRTL ? 'اختر المنتج' : 'Select Product')}
              </button>
              <div class="flex flex-col gap-1">
                <span class="text-[10px] font-bold text-slate-500">{isRTL ? 'الكمية' : 'Qty'}</span>
                <input type="number" min="1" bind:value={currentRule.buyQuantity} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm text-center font-bold focus:ring-2 focus:ring-violet-500 outline-none bg-white/80" />
              </div>
            </div>
            {#if currentRule.buyProduct}
              <div class="flex items-center gap-3 text-xs bg-violet-50/60 rounded-lg px-3 py-2">
                <span class="text-slate-500">{isRTL ? 'السعر:' : 'Price:'}</span>
                <span class="font-bold text-slate-800">{currentRule.buyProduct.price.toFixed(2)}</span>
                <span class="text-slate-300">|</span>
                <span class="text-slate-500">{isRTL ? 'باركود:' : 'Barcode:'}</span>
                <span class="font-bold text-slate-800">{currentRule.buyProduct.barcode || '-'}</span>
              </div>
            {/if}
          </div>

          <!-- Get Product (Y) -->
          <div class="space-y-3 pb-4 border-b border-slate-200">
            <span class="text-xs font-bold text-emerald-700 uppercase tracking-wider">{isRTL ? '🎁 احصل على منتج Y' : '🎁 Get Product Y'}</span>
            <div class="grid grid-cols-[1fr_140px] gap-3">
              <button type="button" class="px-4 py-2.5 border-2 border-slate-200 rounded-xl text-sm {isRTL ? 'text-right' : 'text-left'} bg-white/80 hover:border-emerald-400 hover:bg-emerald-50/50 transition-all truncate font-medium" on:click={() => openProductModal('get')}>
                {currentRule.getProduct ? (isRTL ? currentRule.getProduct.name_ar : currentRule.getProduct.name_en) : (isRTL ? 'اختر المنتج' : 'Select Product')}
              </button>
              <div class="flex flex-col gap-1">
                <span class="text-[10px] font-bold text-slate-500">{isRTL ? 'الكمية' : 'Qty'}</span>
                <input type="number" min="1" bind:value={currentRule.getQuantity} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm text-center font-bold focus:ring-2 focus:ring-emerald-500 outline-none bg-white/80" />
              </div>
            </div>
            {#if currentRule.getProduct}
              <div class="flex items-center gap-3 text-xs bg-emerald-50/60 rounded-lg px-3 py-2">
                <span class="text-slate-500">{isRTL ? 'السعر:' : 'Price:'}</span>
                <span class="font-bold text-slate-800">{currentRule.getProduct.price.toFixed(2)}</span>
                <span class="text-slate-300">|</span>
                <span class="text-slate-500">{isRTL ? 'باركود:' : 'Barcode:'}</span>
                <span class="font-bold text-slate-800">{currentRule.getProduct.barcode || '-'}</span>
              </div>
            {/if}
          </div>

          <!-- Discount Type -->
          <div class="space-y-3">
            <span class="text-xs font-bold text-slate-600 uppercase tracking-wider">{isRTL ? 'نوع الخصم' : 'Discount Type'}</span>
            <div class="grid grid-cols-2 gap-3">
              <select bind:value={currentRule.discountType} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 outline-none bg-white/80 font-medium">
                <option value="free">{isRTL ? 'مجاني' : 'Free'}</option>
                <option value="percentage">{isRTL ? 'نسبة مئوية' : 'Percentage'}</option>
                <option value="amount">{isRTL ? 'مبلغ ثابت' : 'Fixed Amount'}</option>
              </select>
              {#if currentRule.discountType !== 'free'}
                <div class="flex items-center gap-2">
                  <input type="number" min="0" step="0.01" bind:value={currentRule.discountValue} placeholder={isRTL ? 'القيمة' : 'Value'} class="flex-1 px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 outline-none bg-white/80 font-medium" />
                  <span class="text-sm font-bold text-slate-500 min-w-[40px] text-center">
                    {currentRule.discountType === 'percentage' ? '%' : (isRTL ? 'ر.س' : 'SAR')}
                  </span>
                </div>
              {/if}
            </div>
          </div>

          <!-- Price Summary -->
          {#if currentRule.buyProduct && currentRule.getProduct}
            <div class="bg-gradient-to-r from-violet-50 to-purple-50 border-2 border-violet-200 rounded-xl p-4 space-y-2">
              <div class="flex justify-between items-center text-sm py-1.5 border-b border-violet-100">
                <span class="text-slate-600">{isRTL ? 'سعر الشراء:' : 'Buy Price:'}</span>
                <span class="font-bold text-slate-800">{(currentRule.buyProduct.price * currentRule.buyQuantity).toFixed(2)}</span>
              </div>
              <div class="flex justify-between items-center text-sm py-1.5 border-b border-violet-100">
                <span class="text-slate-600">{isRTL ? 'سعر المنتج Y:' : 'Get Product Price:'}</span>
                <span class="font-bold text-slate-800">{(currentRule.getProduct.price * currentRule.getQuantity).toFixed(2)}</span>
              </div>
              <div class="flex justify-between items-center text-sm py-1.5 border-b border-violet-100">
                <span class="text-slate-600">{isRTL ? 'الخصم:' : 'Discount:'}</span>
                <span class="font-bold text-emerald-600">
                  {#if currentRule.discountType === 'free'}
                    -{(currentRule.getProduct.price * currentRule.getQuantity).toFixed(2)} ({isRTL ? 'مجاني' : 'Free'})
                  {:else if currentRule.discountType === 'percentage'}
                    -{((currentRule.getProduct.price * currentRule.getQuantity * currentRule.discountValue) / 100).toFixed(2)} ({currentRule.discountValue}%)
                  {:else if currentRule.discountType === 'amount'}
                    -{currentRule.discountValue.toFixed(2)}
                  {/if}
                </span>
              </div>
              <div class="flex justify-between items-center pt-2 border-t-2 border-violet-300">
                <span class="text-base font-black text-slate-800">{isRTL ? 'السعر النهائي:' : 'Final Price:'}</span>
                <span class="text-xl font-black text-violet-600">{calculatedOfferPrice.toFixed(2)}</span>
              </div>
            </div>
          {/if}

          <!-- Form Actions -->
          <div class="grid grid-cols-[1fr_2fr] gap-3 pt-4 border-t border-slate-200">
            <button type="button" class="px-4 py-2.5 bg-slate-100 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-200 transition-all active:scale-95" on:click={cancelRule}>
              {isRTL ? 'إلغاء' : 'Cancel'}
            </button>
            <button type="button" class="px-4 py-2.5 bg-emerald-500 text-white rounded-xl text-xs font-bold hover:bg-emerald-600 transition-all active:scale-95 shadow-md" on:click={addRule}>
              ✓ {isRTL ? 'حفظ القاعدة' : 'Save Rule'}
            </button>
          </div>
        </div>
      {/if}

      <!-- Saved Rules -->
      {#if bogoRules.length > 0}
        <h4 class="text-xs font-bold text-violet-700 uppercase tracking-wider px-1 mt-4">{isRTL ? 'القواعد المحفوظة' : 'Saved Rules'} ({bogoRules.length})</h4>
        <div class="flex flex-col gap-3">
          {#each bogoRules as rule}
            <div class="bg-white/60 backdrop-blur-xl rounded-2xl border border-white shadow-sm p-4 relative hover:shadow-md transition-all group">
              <div class="grid grid-cols-[1fr_auto_1fr] gap-4 items-center">
                <!-- Buy Section -->
                <div class="space-y-2">
                  <div class="flex items-center gap-1.5">
                    <span class="text-base">🛒</span>
                    <span class="text-[10px] font-black text-slate-500 uppercase tracking-widest">{isRTL ? 'اشتري' : 'Buy'}</span>
                  </div>
                  <div class="bg-amber-50 border border-amber-200 rounded-xl p-3">
                    <p class="text-sm font-bold text-slate-800 truncate">{isRTL ? rule.buyProduct.name_ar : rule.buyProduct.name_en}</p>
                    <div class="flex items-center gap-2 mt-1.5">
                      <span class="px-2 py-0.5 bg-white rounded-lg text-xs font-bold text-violet-600">× {rule.buyQuantity}</span>
                      <span class="text-xs font-semibold text-slate-500">{rule.buyProduct.price.toFixed(2)}</span>
                    </div>
                  </div>
                </div>

                <!-- Arrow -->
                <div class="text-2xl font-black text-violet-400">→</div>

                <!-- Get Section -->
                <div class="space-y-2">
                  <div class="flex items-center gap-1.5">
                    <span class="text-base">🎁</span>
                    <span class="text-[10px] font-black text-slate-500 uppercase tracking-widest">{isRTL ? 'احصل' : 'Get'}</span>
                  </div>
                  <div class="bg-emerald-50 border border-emerald-200 rounded-xl p-3">
                    <p class="text-sm font-bold text-slate-800 truncate">{isRTL ? rule.getProduct.name_ar : rule.getProduct.name_en}</p>
                    <div class="flex items-center gap-2 mt-1.5">
                      <span class="px-2 py-0.5 bg-white rounded-lg text-xs font-bold text-violet-600">× {rule.getQuantity}</span>
                      <span class="px-2 py-0.5 bg-emerald-600 text-white rounded-lg text-[10px] font-bold">
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
              <div class="absolute top-3 {isRTL ? 'left-3' : 'right-3'} flex gap-1.5 opacity-0 group-hover:opacity-100 transition-opacity">
                <button type="button" class="px-2 py-1 bg-blue-500 text-white rounded-lg text-xs hover:bg-blue-600 transition-colors" on:click={() => editRule(rule)} title={isRTL ? 'تعديل' : 'Edit'}>✏️</button>
                <button type="button" class="px-2 py-1 bg-red-500 text-white rounded-lg text-xs hover:bg-red-600 transition-colors" on:click={() => deleteRule(rule.id)} title={isRTL ? 'حذف' : 'Delete'}>🗑️</button>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  {/if}

  <!-- Product Selection Modal -->
  {#if showProductModal}
    <button class="fixed inset-0 z-[999] bg-black/50 backdrop-blur-sm" on:click={closeProductModal} aria-label="Close modal"></button>
    <div class="fixed inset-4 z-[1000] flex items-center justify-center pointer-events-none">
      <div class="bg-white/95 backdrop-blur-xl rounded-2xl shadow-2xl w-full max-w-5xl max-h-[85vh] flex flex-col pointer-events-auto border border-white">
        <!-- Modal Header -->
        <div class="flex items-center justify-between px-5 py-4 border-b border-slate-200 bg-gradient-to-r from-violet-500 to-purple-600 rounded-t-2xl">
          <h3 class="text-sm font-bold text-white">
            {isRTL
              ? (selectingFor === 'buy' ? '🛒 اختر منتج الشراء (X)' : '🎁 اختر منتج الحصول (Y)')
              : (selectingFor === 'buy' ? '🛒 Select Buy Product (X)' : '🎁 Select Get Product (Y)')
            }
          </h3>
          <button type="button" class="w-7 h-7 bg-white/20 hover:bg-white/30 rounded-full flex items-center justify-center text-white font-bold text-sm transition-colors" on:click={closeProductModal}>✕</button>
        </div>

        <!-- Modal Search -->
        <div class="px-5 py-3 border-b border-slate-100">
          <input type="text" bind:value={productSearchTerm} placeholder={isRTL ? 'ابحث بالتسلسل أو الباركود أو اسم المنتج...' : 'Search by serial, barcode or product name...'} class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-violet-500 focus:border-violet-500 outline-none transition-all bg-white/80 placeholder:text-slate-400" />
        </div>

        <!-- Modal Body -->
        <div class="flex-1 overflow-auto">
          <table class="w-full border-collapse text-xs">
            <thead class="sticky top-0 z-10">
              <tr class="bg-gradient-to-r from-slate-700 to-slate-600 text-white">
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'التسلسل' : 'Serial'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'الباركود' : 'Barcode'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'الصورة' : 'Img'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'المنتج (EN)' : 'Product (EN)'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'المنتج (AR)' : 'Product (AR)'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'المخزون' : 'Stock'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'الوحدة' : 'Unit'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'كمية' : 'U.Qty'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'التكلفة' : 'Cost'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'السعر' : 'Price'}</th>
                <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'اختيار' : 'Select'}</th>
              </tr>
            </thead>
            <tbody>
              {#each filteredProducts as product}
                <tr class="hover:bg-violet-50/50 transition-colors border-b border-slate-100">
                  <td class="px-2 py-2">{product.product_serial}</td>
                  <td class="px-2 py-2 font-mono text-[10px]">{product.barcode || '-'}</td>
                  <td class="px-2 py-2">
                    {#if product.image_url}
                      <button class="cursor-pointer hover:opacity-80 transition-opacity" on:click|stopPropagation={() => previewImageUrl = product.image_url}>
                        <img src={product.image_url} alt="" class="w-8 h-8 object-cover rounded ring-1 ring-slate-200 hover:ring-violet-400" />
                      </button>
                    {:else}
                      <span class="text-[9px] text-slate-400 font-semibold">No Image</span>
                    {/if}
                  </td>
                  <td class="px-2 py-2">{product.name_en}</td>
                  <td class="px-2 py-2">{product.name_ar}</td>
                  <td class="px-2 py-2 text-center">{product.stock}</td>
                  <td class="px-2 py-2">{isRTL ? product.unit_name_ar : product.unit_name_en}</td>
                  <td class="px-2 py-2 text-center">{product.unit_qty}</td>
                  <td class="px-2 py-2 font-semibold">{product.cost.toFixed(2)}</td>
                  <td class="px-2 py-2 font-semibold">{product.price.toFixed(2)}</td>
                  <td class="px-2 py-2">
                    <button type="button" class="px-2.5 py-1 bg-violet-500 text-white rounded-lg text-[10px] font-bold hover:bg-violet-600 transition-all active:scale-95 shadow-sm disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:bg-violet-500" disabled={(currentRule.buyProduct && currentRule.buyProduct.id === product.id) || (currentRule.getProduct && currentRule.getProduct.id === product.id)} on:click={() => selectProduct(product)}>
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

  <!-- Footer -->
  <div class="flex items-center justify-between px-6 py-3 bg-white border-t border-slate-200 shadow-[0_-4px_12px_rgba(0,0,0,0.04)]">
    {#if currentStep === 1}
      <div></div>
      <button type="button" class="px-5 py-2.5 bg-violet-500 text-white rounded-xl text-xs font-bold hover:bg-violet-600 transition-all active:scale-95 shadow-md hover:shadow-lg disabled:opacity-50" on:click={nextStep} disabled={loading}>
        {isRTL ? 'التالي' : 'Next'} →
      </button>
    {:else if currentStep === 2}
      <button type="button" class="px-5 py-2.5 bg-slate-100 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-200 transition-all active:scale-95" on:click={prevStep} disabled={loading}>
        ← {isRTL ? 'السابق' : 'Previous'}
      </button>
      <button type="button" class="px-5 py-2.5 bg-violet-500 text-white rounded-xl text-xs font-bold hover:bg-violet-600 transition-all active:scale-95 shadow-md hover:shadow-lg disabled:opacity-50" on:click={saveOffer} disabled={bogoRules.length === 0 || loading}>
        {#if loading}
          <span class="animate-spin inline-block mr-1">⏳</span> {isRTL ? 'جارٍ الحفظ...' : 'Saving...'}
        {:else}
          ✓ {isRTL ? 'حفظ العرض' : 'Save Offer'}
        {/if}
      </button>
    {/if}
  </div>

  <!-- Image Preview Overlay -->
  {#if previewImageUrl}
    <button class="fixed inset-0 z-[9999] bg-black/70 backdrop-blur-sm flex items-center justify-center cursor-pointer" on:click={() => previewImageUrl = null}>
      <div class="relative">
        <img src={previewImageUrl} alt="Preview" class="max-w-[80vw] max-h-[80vh] rounded-2xl shadow-2xl object-contain" />
        <span class="absolute -top-3 -right-3 w-8 h-8 bg-white rounded-full flex items-center justify-center text-slate-600 font-bold shadow-lg text-sm">✕</span>
      </div>
    </button>
  {/if}
</div>

<style>
  /* Tailwind handles all styling */
</style>

