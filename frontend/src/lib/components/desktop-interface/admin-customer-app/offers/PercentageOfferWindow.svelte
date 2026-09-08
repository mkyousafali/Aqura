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
    start_date: getSaudiLocalDateTime(),
    end_date: getSaudiLocalDateTime(30),
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
    loading = true;
    try {
      const { data, error: err } = await supabase.rpc('get_offer_products_data', {
        p_exclude_offer_id: offerId || 0
      });

      if (err) {
        console.error('❌ Error loading products:', err);
        return;
      }

      products = (data?.products || []).map((p: any) => ({
        ...p,
        price: parseFloat(p.price) || 0,
        cost: parseFloat(p.cost) || 0,
        unit_qty: parseFloat(p.unit_qty) || 1,
        stock: p.stock || 0,
        minim_qty: p.minim_qty || 1
      }));

      productsInOtherOffers = new Set(data?.products_in_other_offers || []);
    } catch (e) {
      console.error('❌ Error loading products:', e);
    } finally {
      loading = false;
    }
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

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRTL ? 'rtl' : 'ltr'}>
  <!-- Header -->
  <div class="bg-gradient-to-r from-emerald-600 to-green-500 px-6 py-4 text-white relative overflow-hidden">
    <div class="absolute inset-0 bg-[radial-gradient(circle_at_30%_50%,rgba(255,255,255,0.1),transparent_70%)]"></div>
    <div class="relative flex items-center justify-between">
      <div>
        <h2 class="text-lg font-black tracking-wide">
          {editMode
            ? isRTL ? '📊 تعديل خصم بالنسبة' : '📊 Edit Percentage Offer'
            : isRTL ? '📊 إنشاء خصم بالنسبة' : '📊 Create Percentage Offer'}
        </h2>
      </div>
      <!-- Step Indicator -->
      <div class="flex items-center gap-3">
        <button class="flex items-center gap-2 transition-opacity" class:opacity-100={currentStep === 1} class:opacity-50={currentStep !== 1} on:click={() => { if (currentStep > 1) prevStep(); }}>
          <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all {currentStep >= 1 ? 'bg-white text-emerald-600' : 'bg-white/20 text-white'}">1</div>
          <span class="text-xs font-semibold hidden sm:inline">{isRTL ? 'تفاصيل العرض' : 'Details'}</span>
        </button>
        <div class="w-8 h-0.5 {currentStep >= 2 ? 'bg-white' : 'bg-white/30'}"></div>
        <div class="flex items-center gap-2 transition-opacity" class:opacity-100={currentStep === 2} class:opacity-50={currentStep !== 2}>
          <div class="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all {currentStep >= 2 ? 'bg-white text-emerald-600' : 'bg-white/20 text-white'}">2</div>
          <span class="text-xs font-semibold hidden sm:inline">{isRTL ? 'المنتجات' : 'Products'}</span>
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
            <input type="text" id="name_ar" bind:value={offerData.name_ar} placeholder={isRTL ? 'أدخل اسم العرض بالعربية' : 'Enter offer name in Arabic'} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label for="name_en" class="text-xs font-bold text-slate-600">{isRTL ? 'اسم العرض (إنجليزي)' : 'Offer Name (English)'} <span class="text-red-500">*</span></label>
            <input type="text" id="name_en" bind:value={offerData.name_en} placeholder={isRTL ? 'أدخل اسم العرض بالإنجليزية' : 'Enter offer name in English'} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-1.5">
            <label for="description_ar" class="text-xs font-bold text-slate-600">{isRTL ? 'وصف العرض (عربي)' : 'Description (Arabic)'}</label>
            <textarea id="description_ar" bind:value={offerData.description_ar} placeholder={isRTL ? 'أدخل وصف العرض بالعربية (اختياري)' : 'Enter description in Arabic (optional)'} rows="3" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80 resize-y font-sans"></textarea>
          </div>
          <div class="flex flex-col gap-1.5">
            <label for="description_en" class="text-xs font-bold text-slate-600">{isRTL ? 'وصف العرض (إنجليزي)' : 'Description (English)'}</label>
            <textarea id="description_en" bind:value={offerData.description_en} placeholder={isRTL ? 'أدخل وصف العرض بالإنجليزية (اختياري)' : 'Enter description in English (optional)'} rows="3" class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80 resize-y font-sans"></textarea>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-1.5">
            <label for="start_date" class="text-xs font-bold text-slate-600">{isRTL ? 'تاريخ البدء' : 'Start Date'} <span class="text-red-500">*</span></label>
            <input type="datetime-local" id="start_date" bind:value={offerData.start_date} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label for="end_date" class="text-xs font-bold text-slate-600">{isRTL ? 'تاريخ الانتهاء' : 'End Date'} <span class="text-red-500">*</span></label>
            <input type="datetime-local" id="end_date" bind:value={offerData.end_date} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div class="flex flex-col gap-1.5">
            <label for="branch" class="text-xs font-bold text-slate-600">{isRTL ? 'الفرع المستهدف' : 'Target Branch'}</label>
            <select id="branch" bind:value={offerData.branch_id} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80">
              <option value={null}>{isRTL ? 'جميع الفروع' : 'All Branches'}</option>
              {#each branches as branch}
                <option value={branch.id}>{isRTL ? branch.name_ar : branch.name_en}</option>
              {/each}
            </select>
          </div>
          <div class="flex flex-col gap-1.5">
            <label for="service_type" class="text-xs font-bold text-slate-600">{isRTL ? 'نوع الخدمة' : 'Service Type'}</label>
            <select id="service_type" bind:value={offerData.service_type} class="px-3 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80">
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
    <div class="flex-1 flex flex-col overflow-hidden">
      <div class="flex-1 flex flex-col overflow-hidden p-4 gap-4">
        <h3 class="text-sm font-black text-slate-700 uppercase tracking-wider px-2">💯 {isRTL ? 'منتجات الخصم بالنسبة' : 'Percentage Discount Products'}</h3>

        <!-- Saved Offers -->
        {#if percentageOffers.length > 0}
          <div class="flex flex-col gap-2">
            <h4 class="text-xs font-bold text-emerald-700 uppercase tracking-wider px-2">{isRTL ? 'المنتجات المحفوظة' : 'Saved Offers'} ({percentageOffers.length})</h4>
            <div class="overflow-auto rounded-xl border border-emerald-200 shadow-sm" style="max-height: 280px;">
              <table class="w-full border-collapse text-xs">
                <thead class="sticky top-0 z-10">
                  <tr class="bg-gradient-to-r from-emerald-600 to-green-500 text-white">
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
                    <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'كمية العرض' : 'Offer Qty'}</th>
                    <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'نسبة %' : 'Offer %'}</th>
                    <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'سعر العرض' : 'Offer $'}</th>
                    <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'الربح' : 'Profit'}</th>
                    <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'الاستخدام' : 'Uses'}</th>
                    <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'إجراء' : 'Action'}</th>
                  </tr>
                </thead>
                <tbody>
                  {#each percentageOffers as offer (offer.id)}
                    {@const offerPrice = calculateOfferPrice(offer.product.price, offer.offer_qty, offer.offer_percentage)}
                    {@const profitAfterOffer = offerPrice - (offer.product.cost * offer.offer_qty)}
                    <tr class="bg-emerald-50/60 hover:bg-emerald-100/60 transition-colors border-b border-emerald-100">
                      <td class="px-2 py-2">{offer.product.product_serial}</td>
                      <td class="px-2 py-2 font-mono text-[10px]">{offer.product.barcode}</td>
                      <td class="px-2 py-2">{#if offer.product.image_url}<button class="cursor-pointer hover:opacity-80 transition-opacity" on:click={() => previewImageUrl = offer.product.image_url}><img src={offer.product.image_url} alt={offer.product.name_en} class="w-8 h-8 object-cover rounded ring-1 ring-emerald-200 hover:ring-emerald-400" /></button>{:else}<span class="text-[9px] text-slate-400 font-semibold">No Image</span>{/if}</td>
                      <td class="px-2 py-2">{offer.product.name_en}</td>
                      <td class="px-2 py-2">{offer.product.name_ar}</td>
                      <td class="px-2 py-2 text-center">{offer.product.stock}</td>
                      <td class="px-2 py-2">{isRTL ? offer.product.unit_name_ar : offer.product.unit_name_en}</td>
                      <td class="px-2 py-2 text-center">{offer.product.unit_qty}</td>
                      <td class="px-2 py-2 font-semibold">{offer.product.cost.toFixed(2)}</td>
                      <td class="px-2 py-2 font-semibold">{offer.product.price.toFixed(2)}</td>
                      <td class="px-2 py-2">
                        {#if offer.isEditing}
                          <input type="number" min="1" bind:value={offer.offer_qty} on:input={() => percentageOffers = [...percentageOffers]} class="w-16 px-1.5 py-1 border border-emerald-300 rounded-lg text-xs text-center focus:ring-1 focus:ring-emerald-500 outline-none" />
                        {:else}
                          <span class="font-bold text-emerald-700">{offer.offer_qty}</span>
                        {/if}
                      </td>
                      <td class="px-2 py-2">
                        {#if offer.isEditing}
                          <input type="number" min="0" max="100" bind:value={offer.offer_percentage} on:input={() => percentageOffers = [...percentageOffers]} class="w-16 px-1.5 py-1 border border-emerald-300 rounded-lg text-xs text-center focus:ring-1 focus:ring-emerald-500 outline-none" />
                        {:else}
                          <span class="font-bold text-emerald-700">{offer.offer_percentage}%</span>
                        {/if}
                      </td>
                      <td class="px-2 py-2 font-bold text-emerald-700">{offerPrice.toFixed(2)}</td>
                      <td class="px-2 py-2 font-bold {profitAfterOffer >= 0 ? 'text-emerald-700' : 'text-red-600'}">{profitAfterOffer.toFixed(2)}</td>
                      <td class="px-2 py-2">
                        {#if offer.isEditing}
                          <input type="number" min="1" bind:value={offer.max_uses} class="w-14 px-1.5 py-1 border border-emerald-300 rounded-lg text-xs text-center focus:ring-1 focus:ring-emerald-500 outline-none" />
                        {:else}
                          {offer.max_uses || '—'}
                        {/if}
                      </td>
                      <td class="px-2 py-2">
                        <div class="flex items-center gap-1">
                          {#if offer.isEditing}
                            <button class="px-2 py-1 bg-emerald-500 text-white rounded-lg text-[10px] font-bold hover:bg-emerald-600 transition-colors" on:click={() => savePercentageOffer(offer)}>✓</button>
                          {:else}
                            <button class="px-1.5 py-1 bg-blue-500 text-white rounded-lg text-[10px] hover:bg-blue-600 transition-colors" on:click={() => editPercentageOffer(offer.id)}>✏️</button>
                            <button class="px-1.5 py-1 bg-red-500 text-white rounded-lg text-[10px] hover:bg-red-600 transition-colors" on:click={() => deletePercentageOffer(offer.id)}>🗑️</button>
                          {/if}
                        </div>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        {/if}

        <!-- Available Products -->
        <div class="flex-1 flex flex-col gap-2 min-h-0">
          <h4 class="text-xs font-bold text-slate-600 uppercase tracking-wider px-2">{isRTL ? 'المنتجات المتاحة' : 'Available Products'} ({filteredProducts.length})</h4>
          <div class="px-2">
            <input type="text" bind:value={productSearchTerm} placeholder={isRTL ? 'ابحث بالتسلسل أو الباركود أو اسم المنتج...' : 'Search by serial, barcode or product name...'} class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all bg-white/80 placeholder:text-slate-400" />
          </div>
          <div class="flex-1 overflow-auto rounded-xl border border-slate-200 shadow-sm mx-2">
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
                  <th class="px-2 py-2 {isRTL ? 'text-right' : 'text-left'} font-bold">{isRTL ? 'إجراء' : 'Action'}</th>
                </tr>
              </thead>
              <tbody>
                {#each filteredProducts as product}
                  <tr class="hover:bg-emerald-50/50 transition-colors border-b border-slate-100">
                    <td class="px-2 py-2">{product.product_serial}</td>
                    <td class="px-2 py-2 font-mono text-[10px]">{product.barcode}</td>
                    <td class="px-2 py-2">{#if product.image_url}<button class="cursor-pointer hover:opacity-80 transition-opacity" on:click={() => previewImageUrl = product.image_url}><img src={product.image_url} alt={product.name_en} class="w-8 h-8 object-cover rounded ring-1 ring-slate-200 hover:ring-emerald-400" /></button>{:else}<span class="text-[9px] text-slate-400 font-semibold">No Image</span>{/if}</td>
                    <td class="px-2 py-2">{product.name_en}</td>
                    <td class="px-2 py-2">{product.name_ar}</td>
                    <td class="px-2 py-2 text-center">{product.stock}</td>
                    <td class="px-2 py-2">{isRTL ? product.unit_name_ar : product.unit_name_en}</td>
                    <td class="px-2 py-2 text-center">{product.unit_qty}</td>
                    <td class="px-2 py-2 font-semibold">{product.cost.toFixed(2)}</td>
                    <td class="px-2 py-2 font-semibold">{product.price.toFixed(2)}</td>
                    <td class="px-2 py-2">
                      {#if product.stock < product.minim_qty}
                        <span class="text-red-500 text-[10px] font-bold">{isRTL ? 'مخزون غير كافٍ' : 'Low stock'}</span>
                      {:else}
                        <button class="px-2.5 py-1 bg-emerald-500 text-white rounded-lg text-[10px] font-bold hover:bg-emerald-600 transition-all active:scale-95 shadow-sm" on:click={() => addPercentageOffer(product)}>
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

  <!-- Footer -->
  <div class="flex items-center justify-between px-6 py-3 bg-white border-t border-slate-200 shadow-[0_-4px_12px_rgba(0,0,0,0.04)]">
    {#if currentStep === 1}
      <button type="button" class="px-5 py-2.5 bg-slate-100 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-200 transition-all active:scale-95" on:click={cancel} disabled={loading}>
        {isRTL ? 'إلغاء' : 'Cancel'}
      </button>
      <button type="button" class="px-5 py-2.5 bg-emerald-500 text-white rounded-xl text-xs font-bold hover:bg-emerald-600 transition-all active:scale-95 shadow-md hover:shadow-lg disabled:opacity-50" on:click={nextStep} disabled={loading}>
        {isRTL ? 'التالي' : 'Next'} →
      </button>
    {:else if currentStep === 2}
      <button type="button" class="px-5 py-2.5 bg-slate-100 text-slate-700 rounded-xl text-xs font-bold hover:bg-slate-200 transition-all active:scale-95" on:click={prevStep} disabled={loading}>
        ← {isRTL ? 'السابق' : 'Previous'}
      </button>
      <button type="button" class="px-5 py-2.5 bg-emerald-500 text-white rounded-xl text-xs font-bold hover:bg-emerald-600 transition-all active:scale-95 shadow-md hover:shadow-lg disabled:opacity-50" on:click={saveOffer} disabled={loading}>
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
