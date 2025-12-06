<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { currentLocale } from '$lib/i18n';
  import { supabase } from '$lib/utils/supabase';
  import { notifications } from '$lib/stores/notifications';

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
  let percentageOffers: any[] = [];
  let editingOfferId: number | null = null;
  let productsInOtherOffers: Set<string> = new Set();

  $: isRTL = $currentLocale === 'ar';
  
  // Filter products: exclude those already in this offer and in other active offers, sort by product_serial
  $: filteredProducts = products.filter(p => {
    const matchesSearch = !productSearchTerm ||
      p.barcode?.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
      p.name_ar.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
      p.name_en.toLowerCase().includes(productSearchTerm.toLowerCase()) ||
      p.product_serial?.toLowerCase().includes(productSearchTerm.toLowerCase());
    
    const notInCurrentOffer = !percentageOffers.some(o => o.product.id === p.id);
    const notUsedInOtherOffers = !productsInOtherOffers.has(p.id);
    
    return matchesSearch && notInCurrentOffer && notUsedInOtherOffers;
  }).sort((a, b) => {
    const serialA = a.product_serial || '';
    const serialB = b.product_serial || '';
    return serialA.localeCompare(serialB);
  });

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
    const { data, error: err } = await supabase
      .from('products')
      .select('id, product_name_ar, product_name_en, barcode, product_serial, sale_price, cost, unit_name_en, unit_name_ar, unit_qty, image_url, current_stock, minim_qty, minimum_qty_alert')
      .eq('is_active', true)
      .order('product_serial');

    if (!err && data) {
      products = data.map(p => ({
        id: p.id,
        name_ar: p.product_name_ar,
        name_en: p.product_name_en,
        barcode: p.barcode,
        product_serial: p.product_serial || '',
        price: parseFloat(p.sale_price) || 0,
        cost: parseFloat(p.cost) || 0,
        unit_name_en: p.unit_name_en || '',
        unit_name_ar: p.unit_name_ar || '',
        unit_qty: p.unit_qty || 1,
        image_url: p.image_url,
        stock: p.current_stock || 0,
        minim_qty: p.minim_qty || 1,
        minimum_qty_alert: p.minimum_qty_alert || 0
      }));
    }

    await loadProductsInOtherOffers();
  }

  async function loadProductsInOtherOffers() {
    const { data: offerProducts } = await supabase
      .from('offer_products')
      .select(`
        product_id,
        offers!inner(id, is_active, end_date, type)
      `)
      .eq('offers.is_active', true)
      .gte('offers.end_date', new Date().toISOString())
      .neq('offers.id', offerId || 0);

    const { data: bundleData } = await supabase
      .from('offer_bundles')
      .select(`
        required_products,
        offers!inner(id, is_active, end_date)
      `)
      .eq('offers.is_active', true)
      .gte('offers.end_date', new Date().toISOString())
      .neq('offers.id', offerId || 0);

    // Load products from BOGO offers
    let bogoQuery = supabase
      .from('bogo_offer_rules')
      .select(`
        buy_product_id,
        get_product_id,
        offers!inner(id, is_active, end_date)
      `)
      .eq('offers.is_active', true)
      .gte('offers.end_date', new Date().toISOString());
    
    if (editMode && offerId) {
      bogoQuery = bogoQuery.neq('offers.id', offerId);
    }

    const { data: bogoData } = await bogoQuery;

    productsInOtherOffers = new Set();
    
    offerProducts?.forEach(op => {
      productsInOtherOffers.add(op.product_id);
    });

    bundleData?.forEach(bundle => {
      if (bundle.required_products && Array.isArray(bundle.required_products)) {
        bundle.required_products.forEach((p: any) => {
          productsInOtherOffers.add(p.product_id);
        });
      }
    });

    bogoData?.forEach((rule: any) => {
      if (rule.buy_product_id) {
        productsInOtherOffers.add(rule.buy_product_id);
      }
      if (rule.get_product_id) {
        productsInOtherOffers.add(rule.get_product_id);
      }
    });
  }

  function toSaudiTimeInput(utcDateString: string) {
    const date = new Date(utcDateString);
    const saudiTime = new Date(date.toLocaleString('en-US', { timeZone: 'Asia/Riyadh' }));
    const year = saudiTime.getFullYear();
    const month = String(saudiTime.getMonth() + 1).padStart(2, '0');
    const day = String(saudiTime.getDate()).padStart(2, '0');
    const hours = String(saudiTime.getHours()).padStart(2, '0');
    const minutes = String(saudiTime.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  }

  function toUTCFromSaudiInput(saudiTimeString: string) {
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
      
      await loadOfferProducts();
    }
  }

  async function loadOfferProducts() {
    if (!offerId) return;

    const { data: offerProducts, error: err } = await supabase
      .from('offer_products')
      .select('*')
      .eq('offer_id', offerId)
      .not('offer_percentage', 'is', null);

    if (err || !offerProducts) {
      console.error('Error loading offer products:', err);
      return;
    }

    percentageOffers = [];

    for (const op of offerProducts) {
      const product = products.find(p => p.id === op.product_id);
      if (!product) continue;

      percentageOffers = [...percentageOffers, {
        id: op.id,
        product: product,
        offer_qty: op.offer_qty,
        offer_percentage: op.offer_percentage,
        max_uses: op.max_uses || null
      }];
    }

    // Don't auto-skip to step 2 in edit mode - let user review step 1 first
  }

  function validateStep1(): boolean {
    error = null;

    if (!offerData.name_ar.trim() || !offerData.name_en.trim()) {
      error = isRTL
        ? 'يرجى إدخال اسم العرض بالعربية والإنجليزية'
        : 'Please enter offer name in both Arabic and English';
      return false;
    }

    if (!offerData.start_date || !offerData.end_date) {
      error = isRTL
        ? 'يرجى تحديد تاريخ البدء والانتهاء'
        : 'Please specify start and end dates';
      return false;
    }

    if (new Date(offerData.end_date) <= new Date(offerData.start_date)) {
      error = isRTL
        ? 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء'
        : 'End date must be after start date';
      return false;
    }

    return true;
  }

  function nextStep() {
    if (currentStep === 1 && !validateStep1()) {
      return;
    }
    currentStep = 2;
  }

  function prevStep() {
    currentStep = 1;
  }

  function addPercentageOffer(product: any) {
    const newOffer = {
      id: Date.now(),
      product: product,
      offer_qty: 1,
      offer_percentage: 10,
      max_uses: 1,
      isEditing: true
    };
    percentageOffers = [newOffer, ...percentageOffers];
    editingOfferId = newOffer.id;
  }

  function savePercentageOffer(offer: any) {
    offer.isEditing = false;
    editingOfferId = null;
    percentageOffers = [...percentageOffers];
  }

  function editPercentageOffer(offerId: number) {
    percentageOffers = percentageOffers.map(o => ({
      ...o,
      isEditing: o.id === offerId
    }));
    editingOfferId = offerId;
  }

  function deletePercentageOffer(offerId: number) {
    percentageOffers = percentageOffers.filter(o => o.id !== offerId);
  }

  function calculateOfferPrice(salePrice: number, offerQty: number, offerPercentage: number): number {
    const totalPrice = salePrice * offerQty;
    const discount = (totalPrice * offerPercentage) / 100;
    return totalPrice - discount;
  }

  async function saveOffer() {
    loading = true;
    error = null;

    try {
      if (!offerData.name_ar || !offerData.name_en) {
        error = isRTL ? 'يرجى إدخال اسم العرض' : 'Please enter offer name';
        loading = false;
        return;
      }

      if (percentageOffers.length === 0) {
        error = isRTL ? 'يرجى إضافة منتج واحد على الأقل' : 'Please add at least one product';
        loading = false;
        return;
      }

      const offerPayload = {
        type: 'product',
        name_ar: offerData.name_ar,
        name_en: offerData.name_en,
        description_ar: offerData.description_ar || '',
        description_en: offerData.description_en || '',
        start_date: toUTCFromSaudiInput(offerData.start_date),
        end_date: toUTCFromSaudiInput(offerData.end_date),
        is_active: true,
        branch_id: offerData.branch_id || null,
        service_type: offerData.service_type,
        show_on_product_page: true,
        show_in_carousel: true,
        send_push_notification: false,
        created_by: null
      };

      let savedOfferId: number;

      if (editMode && offerId) {
        const { error: updateError } = await supabase
          .from('offers')
          .update(offerPayload)
          .eq('id', offerId);

        if (updateError) throw updateError;
        savedOfferId = offerId;

        await supabase
          .from('offer_products')
          .delete()
          .eq('offer_id', savedOfferId);
      } else {
        const { data: newOffer, error: insertError } = await supabase
          .from('offers')
          .insert(offerPayload)
          .select()
          .single();

        if (insertError) throw insertError;
        savedOfferId = newOffer.id;
      }

      const offerProductsData = percentageOffers.map(offer => {
        const calculatedPrice = calculateOfferPrice(
          offer.product.price, 
          offer.offer_qty, 
          offer.offer_percentage
        );
        
        return {
          offer_id: savedOfferId,
          product_id: offer.product.id,
          offer_qty: offer.offer_qty,
          offer_percentage: offer.offer_percentage,
          offer_price: calculatedPrice,
          max_uses: offer.max_uses || null
        };
      });

      const { error: productsError } = await supabase
        .from('offer_products')
        .insert(offerProductsData);

      if (productsError) throw productsError;

      notifications.add({
        message: isRTL 
          ? `✅ تم حفظ العرض بنجاح! (${percentageOffers.length} ${percentageOffers.length === 1 ? 'منتج' : 'منتجات'})`
          : `✅ Offer saved successfully! (${percentageOffers.length} product${percentageOffers.length === 1 ? '' : 's'})`,
        type: 'success',
        duration: 3000
      });

      dispatch('save', { offerId: savedOfferId });
      
      setTimeout(() => {
        cancel();
      }, 500);
    } catch (err: any) {
      console.error('Error saving offer:', err);
      error = isRTL 
        ? `خطأ في حفظ العرض: ${err.message}` 
        : `Error saving offer: ${err.message}`;
    } finally {
      loading = false;
    }
  }

  function cancel() {
    dispatch('close');
  }
</script>

<div class="percentage-offer-window" class:rtl={isRTL}>
  <!-- Header with Steps -->
  <div class="window-header">
    <h2 class="window-title">
      {editMode
        ? isRTL
          ? '📊 تعديل خصم بالنسبة'
          : '📊 Edit Percentage Offer'
        : isRTL
          ? '📊 إنشاء خصم بالنسبة'
          : '📊 Create Percentage Offer'}
    </h2>
    <div class="step-indicator">
      <div class="step-item" class:active={currentStep === 1} class:completed={currentStep > 1}>
        <div class="step-circle">1</div>
        <span class="step-label">{isRTL ? 'تفاصيل العرض' : 'Offer Details'}</span>
      </div>
      <div class="step-divider"></div>
      <div class="step-item" class:active={currentStep === 2}>
        <div class="step-circle">2</div>
        <span class="step-label">{isRTL ? 'اختيار المنتجات' : 'Product Selection'}</span>
      </div>
    </div>
  </div>

  {#if error}
    <div class="error-message">
      ⚠️ {error}
    </div>
  {/if}

  {#if currentStep === 1}
    <!-- Step 1: Offer Details -->
    <div class="step-content">
      <div class="form-section">
        <h3 class="section-title">{isRTL ? 'معلومات العرض الأساسية' : 'Basic Offer Information'}</h3>
        <div class="form-row">
          <div class="form-group">
            <label for="name_ar">
              {isRTL ? 'اسم العرض (عربي)' : 'Offer Name (Arabic)'}
              <span class="required">*</span>
            </label>
            <input
              type="text"
              id="name_ar"
              bind:value={offerData.name_ar}
              placeholder={isRTL ? 'أدخل اسم العرض بالعربية' : 'Enter offer name in Arabic'}
            />
          </div>
          <div class="form-group">
            <label for="name_en">
              {isRTL ? 'اسم العرض (إنجليزي)' : 'Offer Name (English)'}
              <span class="required">*</span>
            </label>
            <input
              type="text"
              id="name_en"
              bind:value={offerData.name_en}
              placeholder={isRTL ? 'أدخل اسم العرض بالإنجليزية' : 'Enter offer name in English'}
            />
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label for="description_ar">
              {isRTL ? 'وصف العرض (عربي)' : 'Offer Description (Arabic)'}
            </label>
            <textarea
              id="description_ar"
              bind:value={offerData.description_ar}
              placeholder={isRTL ? 'أدخل وصف العرض بالعربية (اختياري)' : 'Enter offer description in Arabic (optional)'}
              rows="3"
            />
          </div>
          <div class="form-group">
            <label for="description_en">
              {isRTL ? 'وصف العرض (إنجليزي)' : 'Offer Description (English)'}
            </label>
            <textarea
              id="description_en"
              bind:value={offerData.description_en}
              placeholder={isRTL ? 'أدخل وصف العرض بالإنجليزية (اختياري)' : 'Enter offer description in English (optional)'}
              rows="3"
            />
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label for="start_date">
              {isRTL ? 'تاريخ البدء' : 'Start Date'}
              <span class="required">*</span>
            </label>
            <input
              type="datetime-local"
              id="start_date"
              bind:value={offerData.start_date}
              placeholder={isRTL ? 'يوم-شهر-سنة ساعة:دقيقة' : 'dd-mm-yyyy hh:mm'}
            />
          </div>
          <div class="form-group">
            <label for="end_date">
              {isRTL ? 'تاريخ الانتهاء' : 'End Date'}
              <span class="required">*</span>
            </label>
            <input
              type="datetime-local"
              id="end_date"
              bind:value={offerData.end_date}
              placeholder={isRTL ? 'يوم-شهر-سنة ساعة:دقيقة' : 'dd-mm-yyyy hh:mm'}
            />
          </div>
        </div>
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
    </div>
  {:else if currentStep === 2}
    <!-- Step 2: Product Selection -->
    <div class="step-content step-content-full">
      <div class="offer-table-container">
        <div class="table-header">
          <h3 class="table-title">
            💯 {isRTL ? 'منتجات الخصم بالنسبة' : 'Percentage Discount Products'}
          </h3>
        </div>

        <!-- Saved Offers -->
        {#if percentageOffers.length > 0}
          <div class="saved-offers-section">
            <h4 class="section-subtitle">{isRTL ? 'المنتجات المحفوظة' : 'Saved Offers'}</h4>
            <div class="table-wrapper">
              <table class="offers-table">
                <thead>
                  <tr>
                    <th>{isRTL ? 'التسلسل' : 'Serial'}</th>
                    <th>{isRTL ? 'الباركود' : 'Barcode'}</th>
                    <th>{isRTL ? 'الصورة' : 'Image'}</th>
                    <th>{isRTL ? 'اسم المنتج (EN)' : 'Product Name (EN)'}</th>
                    <th>{isRTL ? 'اسم المنتج (AR)' : 'Product Name (AR)'}</th>
                    <th>{isRTL ? 'المخزون' : 'Stock'}</th>
                    <th>{isRTL ? 'اسم الوحدة' : 'Unit Name'}</th>
                    <th>{isRTL ? 'كمية الوحدة' : 'Unit Qty'}</th>
                    <th>{isRTL ? 'تكلفة الوحدة' : 'Unit Cost'}</th>
                    <th>{isRTL ? 'سعر البيع' : 'Sale Price'}</th>
                    <th>{isRTL ? 'كمية العرض' : 'Offer Qty'}</th>
                    <th>{isRTL ? 'نسبة العرض %' : 'Offer %'}</th>
                    <th>{isRTL ? 'سعر العرض' : 'Offer Price'}</th>
                    <th>{isRTL ? 'الربح بعد العرض' : 'Profit After Offer'}</th>
                    <th>{isRTL ? 'مرات الاستخدام' : 'Max Uses'}</th>
                    <th>{isRTL ? 'الإجراءات' : 'Actions'}</th>
                  </tr>
                </thead>
                <tbody>
                  {#each percentageOffers as offer (offer.id)}
                    {@const offerPrice = calculateOfferPrice(offer.product.price, offer.offer_qty, offer.offer_percentage)}
                    {@const profitAfterOffer = offerPrice - (offer.product.cost * offer.offer_qty)}
                    <tr class="saved-offer-row">
                      <td>{offer.product.product_serial}</td>
                      <td>{offer.product.barcode}</td>
                      <td>
                        <img src={offer.product.image_url || '/placeholder.png'} alt={offer.product.name_en} class="product-image" />
                      </td>
                      <td>{offer.product.name_en}</td>
                      <td>{offer.product.name_ar}</td>
                      <td>{offer.product.stock}</td>
                      <td>{isRTL ? offer.product.unit_name_ar : offer.product.unit_name_en}</td>
                      <td>{offer.product.unit_qty}</td>
                      <td>{offer.product.cost.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</td>
                      <td>{offer.product.price.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</td>
                      <td>
                        {#if offer.isEditing}
                          <input 
                            type="number" 
                            min="1" 
                            bind:value={offer.offer_qty} 
                            class="input-qty"
                            on:input={() => percentageOffers = [...percentageOffers]}
                          />
                        {:else}
                          {offer.offer_qty}
                        {/if}
                      </td>
                      <td>
                        {#if offer.isEditing}
                          <input 
                            type="number" 
                            min="0" 
                            max="100" 
                            bind:value={offer.offer_percentage} 
                            class="input-percentage"
                            on:input={() => percentageOffers = [...percentageOffers]}
                          />
                        {:else}
                          {offer.offer_percentage}%
                        {/if}
                      </td>
                      <td class="offer-price">
                        {offerPrice.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}
                      </td>
                      <td class={profitAfterOffer >= 0 ? 'profit-positive' : 'profit-negative'}>
                        {profitAfterOffer.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}
                      </td>
                      <td>
                        {#if offer.isEditing}
                          <input type="number" min="1" bind:value={offer.max_uses} class="input-uses" />
                        {:else}
                          {offer.max_uses}
                        {/if}
                      </td>
                      <td>
                        {#if offer.isEditing}
                          <button class="btn-action btn-save" on:click={() => savePercentageOffer(offer)}>
                            ✓
                          </button>
                        {:else}
                          <button class="btn-action btn-edit" on:click={() => editPercentageOffer(offer.id)}>
                            ✏️
                          </button>
                          <button class="btn-action btn-delete" on:click={() => deletePercentageOffer(offer.id)}>
                            🗑️
                          </button>
                        {/if}
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        {/if}

        <!-- Available Products -->
        <div class="available-products-section">
          <h4 class="section-subtitle">{isRTL ? 'المنتجات المتاحة' : 'Available Products'}</h4>
          <div class="search-box">
            <input
              type="text"
              bind:value={productSearchTerm}
              placeholder={isRTL ? 'ابحث بالتسلسل أو الباركود أو اسم المنتج...' : 'Search by serial, barcode or product name...'}
              class="search-input"
            />
          </div>
          <div class="table-wrapper">
            <table class="offers-table">
              <thead>
                <tr>
                  <th>{isRTL ? 'التسلسل' : 'Serial'}</th>
                  <th>{isRTL ? 'الباركود' : 'Barcode'}</th>
                  <th>{isRTL ? 'الصورة' : 'Image'}</th>
                  <th>{isRTL ? 'اسم المنتج (EN)' : 'Product Name (EN)'}</th>
                  <th>{isRTL ? 'اسم المنتج (AR)' : 'Product Name (AR)'}</th>
                  <th>{isRTL ? 'المخزون' : 'Stock'}</th>
                  <th>{isRTL ? 'اسم الوحدة' : 'Unit Name'}</th>
                  <th>{isRTL ? 'كمية الوحدة' : 'Unit Qty'}</th>
                  <th>{isRTL ? 'تكلفة الوحدة' : 'Unit Cost'}</th>
                  <th>{isRTL ? 'سعر البيع' : 'Sale Price'}</th>
                  <th>{isRTL ? 'الإجراءات' : 'Actions'}</th>
                </tr>
              </thead>
              <tbody>
                {#each filteredProducts as product}
                  <tr>
                    <td>{product.product_serial}</td>
                    <td>{product.barcode}</td>
                    <td>
                      <img src={product.image_url || '/placeholder.png'} alt={product.name_en} class="product-image" />
                    </td>
                    <td>{product.name_en}</td>
                    <td>{product.name_ar}</td>
                    <td>{product.stock}</td>
                    <td>{isRTL ? product.unit_name_ar : product.unit_name_en}</td>
                    <td>{product.unit_qty}</td>
                    <td>{product.cost.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</td>
                    <td>{product.price.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</td>
                    <td>
                      {#if product.stock < product.minim_qty}
                        <span class="stock-warning">{isRTL ? 'مخزون غير كافٍ' : 'No enough stock'}</span>
                      {:else}
                        <button class="btn-add" on:click={() => addPercentageOffer(product)}>
                          + {isRTL ? 'إضافة' : 'Add'}
                        </button>
                      {/if}
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
      <button type="button" class="btn-secondary" on:click={cancel} disabled={loading}>
        {isRTL ? 'إلغاء' : 'Cancel'}
      </button>
      <button type="button" class="btn-primary" on:click={nextStep} disabled={loading}>
        {isRTL ? 'التالي' : 'Next'} →
      </button>
    {:else if currentStep === 2}
      <button type="button" class="btn-secondary" on:click={prevStep} disabled={loading}>
        ← {isRTL ? 'السابق' : 'Previous'}
      </button>
      <button type="button" class="btn-primary" on:click={saveOffer} disabled={loading}>
        {#if loading}
          ⏳ {isRTL ? 'جارٍ الحفظ...' : 'Saving...'}
        {:else}
          ✓ {isRTL ? 'حفظ العرض' : 'Save Offer'}
        {/if}
      </button>
    {/if}
  </div>
</div>

<style>
  .percentage-offer-window {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: white;
    border-radius: 12px;
    overflow: hidden;
  }

  .window-header {
    padding: 24px;
    background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
    color: white;
  }

  .window-title {
    font-size: 24px;
    font-weight: 600;
    margin: 0 0 16px 0;
  }

  .step-indicator {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .step-item {
    display: flex;
    align-items: center;
    gap: 8px;
    opacity: 0.6;
  }

  .step-item.active,
  .step-item.completed {
    opacity: 1;
  }

  .step-circle {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.2);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
  }

  .step-item.active .step-circle,
  .step-item.completed .step-circle {
    background: white;
    color: #22c55e;
  }

  .step-label {
    font-size: 14px;
  }

  .step-divider {
    flex: 1;
    height: 2px;
    background: rgba(255, 255, 255, 0.3);
  }

  .error-message {
    padding: 16px;
    background: #fee;
    color: #c33;
    border-bottom: 1px solid #fcc;
  }

  .step-content {
    flex: 1;
    padding: 24px;
    overflow-y: auto;
  }

  .step-content-full {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .form-section {
    background: #f9fafb;
    border-radius: 8px;
    padding: 24px;
  }

  .section-title {
    font-size: 18px;
    font-weight: 600;
    margin: 0 0 16px 0;
    color: #1f2937;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-bottom: 16px;
  }

  .form-group {
    display: flex;
    flex-direction: column;
  }

  .form-group label {
    font-weight: 500;
    margin-bottom: 8px;
    color: #374151;
  }

  .required {
    color: #ef4444;
  }

  .form-group input,
  .form-group select,
  .form-group textarea {
    padding: 10px 12px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 14px;
  }

  .form-group textarea {
    resize: vertical;
    font-family: inherit;
  }

  .offer-table-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    padding: 24px;
  }

  .table-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  .table-title {
    font-size: 20px;
    font-weight: 600;
    margin: 0;
  }

  .saved-offers-section,
  .available-products-section {
    margin-bottom: 24px;
  }

  .section-subtitle {
    font-size: 16px;
    font-weight: 600;
    margin: 0 0 12px 0;
    color: #1f2937;
  }

  .search-box {
    margin-bottom: 12px;
  }

  .search-input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 14px;
  }

  .table-wrapper {
    max-height: calc(100vh - 420px);
    overflow-y: auto;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
  }

  .offers-table {
    width: 100%;
    border-collapse: collapse;
  }

  .offers-table thead {
    position: sticky;
    top: 0;
    background: #f9fafb;
    z-index: 1;
  }

  .offers-table th {
    padding: 12px;
    text-align: left;
    font-weight: 600;
    border-bottom: 2px solid #e5e7eb;
    font-size: 13px;
  }

  .offers-table td {
    padding: 12px;
    border-bottom: 1px solid #e5e7eb;
    font-size: 13px;
  }

  .product-image {
    width: 40px;
    height: 40px;
    object-fit: cover;
    border-radius: 4px;
  }

  .saved-offer-row {
    background: #f0fdf4;
  }

  .input-qty,
  .input-percentage,
  .input-uses {
    width: 80px;
    padding: 6px 8px;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 13px;
  }

  .offer-price {
    font-weight: 600;
    color: #16a34a;
  }

  .profit-positive {
    color: #16a34a;
    font-weight: 600;
  }

  .profit-negative {
    color: #dc2626;
    font-weight: 600;
  }

  .stock-warning {
    color: #dc2626;
    font-size: 12px;
    font-weight: 500;
  }

  .btn-action {
    padding: 6px 10px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
    margin: 0 4px;
  }

  .btn-save {
    background: #22c55e;
    color: white;
  }

  .btn-edit {
    background: #3b82f6;
    color: white;
  }

  .btn-delete {
    background: #ef4444;
    color: white;
  }

  .btn-add {
    padding: 6px 12px;
    background: #22c55e;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
  }

  .btn-add:hover {
    background: #16a34a;
  }

  .window-footer {
    display: flex;
    justify-content: space-between;
    padding: 16px 24px;
    border-top: 1px solid #e5e7eb;
    background: #f9fafb;
  }

  .btn-primary,
  .btn-secondary {
    padding: 10px 20px;
    border: none;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-primary {
    background: #22c55e;
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background: #16a34a;
  }

  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-secondary {
    background: #e5e7eb;
    color: #374151;
  }

  .btn-secondary:hover:not(:disabled) {
    background: #d1d5db;
  }

  .rtl {
    direction: rtl;
  }

  .rtl .offers-table th,
  .rtl .offers-table td {
    text-align: right;
  }
</style>
