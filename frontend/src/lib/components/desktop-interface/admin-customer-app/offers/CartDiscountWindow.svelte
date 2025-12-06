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
  let cartTiers: any[] = [];
  let editingTierId: number | null = null;

  $: isRTL = $currentLocale === 'ar';

  onMount(async () => {
    await loadBranches();
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
    const [datePart, timePart] = saudiTimeString.split('T');
    const [year, month, day] = datePart.split('-').map(Number);
    const [hours, minutes] = timePart.split(':').map(Number);
    const saudiDate = new Date(year, month - 1, day, hours, minutes);
    const utcDate = new Date(saudiDate.getTime() - (3 * 60 * 60 * 1000));
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

      await loadCartTiers();
    }
  }

  async function loadCartTiers() {
    if (!offerId) return;

    const { data, error: err } = await supabase
      .from('offer_cart_tiers')
      .select('*')
      .eq('offer_id', offerId)
      .order('tier_number');

    if (!err && data) {
      cartTiers = data.map(tier => ({
        id: tier.id,
        tier_number: tier.tier_number,
        min_amount: parseFloat(tier.min_amount) || 0,
        max_amount: tier.max_amount ? parseFloat(tier.max_amount) : null,
        discount_type: tier.discount_type || 'percentage',
        discount_value: parseFloat(tier.discount_value) || 0,
        isEditing: false
      }));
    }
  }

  function validateStep1() {
    if (!offerData.name_ar || !offerData.name_en) {
      error = isRTL
        ? 'يرجى إدخال اسم العرض بالعربية والإنجليزية'
        : 'Please enter offer name in both Arabic and English';
      return false;
    }

    if (!offerData.start_date || !offerData.end_date) {
      error = isRTL
        ? 'يرجى تحديد تاريخ البدء والانتهاء'
        : 'Please select start and end dates';
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

  function addTier() {
    const newTier = {
      id: Date.now(),
      tier_number: cartTiers.length + 1,
      min_amount: cartTiers.length > 0 ? (cartTiers[cartTiers.length - 1].max_amount || 0) : 0,
      max_amount: null,
      discount_type: 'percentage' as 'percentage' | 'amount',
      discount_value: 0,
      isEditing: true
    };
    cartTiers = [...cartTiers, newTier];
    editingTierId = newTier.id;
  }

  function saveTier(tier: any) {
    tier.isEditing = false;
    editingTierId = null;
    cartTiers = [...cartTiers];
  }

  function editTier(tierId: number) {
    cartTiers = cartTiers.map(t => ({
      ...t,
      isEditing: t.id === tierId
    }));
    editingTierId = tierId;
  }

  function deleteTier(tierId: number) {
    cartTiers = cartTiers.filter(t => t.id !== tierId);
    // Renumber tiers
    cartTiers = cartTiers.map((t, index) => ({
      ...t,
      tier_number: index + 1
    }));
  }

  async function saveOffer() {
    loading = true;
    error = null;

    try {
      if (!offerData.name_ar || !offerData.name_en) {
        error = isRTL ? 'يرجى إدخال اسم العرض' : 'Please enter offer name';
        return;
      }

      if (cartTiers.length === 0) {
        error = isRTL ? 'يرجى إضافة مستوى واحد على الأقل' : 'Please add at least one tier';
        return;
      }

      const offerPayload = {
        type: 'cart',
        name_ar: offerData.name_ar,
        name_en: offerData.name_en,
        description_ar: offerData.description_ar,
        description_en: offerData.description_en,
        start_date: toUTCFromSaudiInput(offerData.start_date),
        end_date: toUTCFromSaudiInput(offerData.end_date),
        branch_id: offerData.branch_id,
        service_type: offerData.service_type,
        is_active: offerData.is_active
      };

      let savedOfferId = offerId;

      if (editMode && offerId) {
        const { error: updateError } = await supabase
          .from('offers')
          .update(offerPayload)
          .eq('id', offerId);

        if (updateError) throw updateError;
        savedOfferId = offerId;

        await supabase
          .from('offer_cart_tiers')
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

      const tierInserts = cartTiers.map(tier => ({
        offer_id: savedOfferId,
        tier_number: tier.tier_number,
        min_amount: tier.min_amount,
        max_amount: tier.max_amount,
        discount_type: tier.discount_type,
        discount_value: tier.discount_value
      }));

      const { error: tiersError } = await supabase
        .from('offer_cart_tiers')
        .insert(tierInserts);

      if (tiersError) throw tiersError;

      notifications.add({
        message: isRTL 
          ? '✅ تم حفظ عرض خصم السلة بنجاح!' 
          : '✅ Cart discount offer saved successfully!',
        type: 'success'
      });

      dispatch('close');
    } catch (err: any) {
      console.error('Error saving cart discount:', err);
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

<div class="cart-discount-window" class:rtl={isRTL}>
  <!-- Header with Steps -->
  <div class="window-header">
    <h2 class="window-title">
      {editMode
        ? isRTL
          ? '🛒 تعديل خصم السلة'
          : '🛒 Edit Cart Discount'
        : isRTL
          ? '🛒 إنشاء خصم السلة'
          : '🛒 Create Cart Discount'}
    </h2>
    <div class="step-indicator">
      <div class="step-item" class:active={currentStep === 1} class:completed={currentStep > 1}>
        <div class="step-circle">1</div>
        <span class="step-label">{isRTL ? 'تفاصيل العرض' : 'Offer Details'}</span>
      </div>
      <div class="step-divider"></div>
      <div class="step-item" class:active={currentStep === 2}>
        <div class="step-circle">2</div>
        <span class="step-label">{isRTL ? 'مستويات الخصم' : 'Discount Tiers'}</span>
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
            <label>
              {isRTL ? 'اسم العرض (عربي)' : 'Offer Name (Arabic)'}
              <span class="required">*</span>
            </label>
            <input type="text" bind:value={offerData.name_ar} required />
          </div>
          <div class="form-group">
            <label>
              {isRTL ? 'اسم العرض (إنجليزي)' : 'Offer Name (English)'}
              <span class="required">*</span>
            </label>
            <input type="text" bind:value={offerData.name_en} required />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>{isRTL ? 'الوصف (عربي)' : 'Description (Arabic)'}</label>
            <textarea bind:value={offerData.description_ar} rows="3"></textarea>
          </div>
          <div class="form-group">
            <label>{isRTL ? 'الوصف (إنجليزي)' : 'Description (English)'}</label>
            <textarea bind:value={offerData.description_en} rows="3"></textarea>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>
              {isRTL ? 'تاريخ البدء' : 'Start Date'}
              <span class="required">*</span>
            </label>
            <input type="datetime-local" bind:value={offerData.start_date} required />
          </div>
          <div class="form-group">
            <label>
              {isRTL ? 'تاريخ الانتهاء' : 'End Date'}
              <span class="required">*</span>
            </label>
            <input type="datetime-local" bind:value={offerData.end_date} required />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label>{isRTL ? 'الفرع' : 'Branch'}</label>
            <select bind:value={offerData.branch_id}>
              <option value={null}>{isRTL ? 'جميع الفروع' : 'All Branches'}</option>
              {#each branches as branch}
                <option value={branch.id}>
                  {isRTL ? branch.name_ar : branch.name_en}
                </option>
              {/each}
            </select>
          </div>
          <div class="form-group">
            <label>{isRTL ? 'نوع الخدمة' : 'Service Type'}</label>
            <select bind:value={offerData.service_type}>
              <option value="both">{isRTL ? 'توصيل واستلام' : 'Delivery & Pickup'}</option>
              <option value="delivery">{isRTL ? 'توصيل فقط' : 'Delivery Only'}</option>
              <option value="pickup">{isRTL ? 'استلام فقط' : 'Pickup Only'}</option>
            </select>
          </div>
        </div>

        <div class="form-group">
          <label class="checkbox-label">
            <input type="checkbox" bind:checked={offerData.is_active} />
            <span>{isRTL ? 'العرض نشط' : 'Offer is Active'}</span>
          </label>
        </div>
      </div>
    </div>
  {:else if currentStep === 2}
    <!-- Step 2: Discount Tiers -->
    <div class="step-content step-content-full">
      <div class="tier-table-container">
        <div class="table-header">
          <h3 class="table-title">
            🛒 {isRTL ? 'مستويات خصم السلة' : 'Cart Discount Tiers'}
          </h3>
          <button type="button" class="btn-add-tier" on:click={addTier}>
            + {isRTL ? 'إضافة مستوى' : 'Add Tier'}
          </button>
        </div>

        {#if cartTiers.length > 0}
          <div class="tiers-section">
            <div class="table-wrapper">
              <table class="tiers-table">
                <thead>
                  <tr>
                    <th>{isRTL ? 'المستوى' : 'Tier'}</th>
                    <th>{isRTL ? 'الحد الأدنى' : 'Min Amount'}</th>
                    <th>{isRTL ? 'الحد الأقصى' : 'Max Amount'}</th>
                    <th>{isRTL ? 'نوع الخصم' : 'Discount Type'}</th>
                    <th>{isRTL ? 'قيمة الخصم' : 'Discount Value'}</th>
                    <th>{isRTL ? 'الإجراءات' : 'Actions'}</th>
                  </tr>
                </thead>
                <tbody>
                  {#each cartTiers as tier (tier.id)}
                    <tr class="tier-row">
                      <td>{tier.tier_number}</td>
                      <td>
                        {#if tier.isEditing}
                          <input 
                            type="number" 
                            min="0" 
                            step="0.01"
                            bind:value={tier.min_amount} 
                            class="input-amount"
                          />
                        {:else}
                          {tier.min_amount.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}
                        {/if}
                      </td>
                      <td>
                        {#if tier.isEditing}
                          <input 
                            type="number" 
                            min="0" 
                            step="0.01"
                            bind:value={tier.max_amount} 
                            placeholder={isRTL ? 'غير محدود' : 'Unlimited'}
                            class="input-amount"
                          />
                        {:else}
                          {tier.max_amount ? `${tier.max_amount.toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}` : (isRTL ? 'غير محدود' : 'Unlimited')}
                        {/if}
                      </td>
                      <td>
                        {#if tier.isEditing}
                          <select bind:value={tier.discount_type} class="input-select">
                            <option value="percentage">{isRTL ? 'نسبة مئوية %' : 'Percentage %'}</option>
                            <option value="amount">{isRTL ? 'مبلغ ثابت' : 'Fixed Amount'}</option>
                          </select>
                        {:else}
                          {tier.discount_type === 'percentage' ? (isRTL ? 'نسبة مئوية' : 'Percentage') : (isRTL ? 'مبلغ ثابت' : 'Fixed Amount')}
                        {/if}
                      </td>
                      <td>
                        {#if tier.isEditing}
                          <input 
                            type="number" 
                            min="0" 
                            max={tier.discount_type === 'percentage' ? 100 : undefined}
                            step="0.01"
                            bind:value={tier.discount_value} 
                            class="input-value"
                          />
                        {:else}
                          <span class="discount-value">
                            {tier.discount_value.toFixed(2)}{tier.discount_type === 'percentage' ? '%' : ` ${isRTL ? 'ريال' : 'SAR'}`}
                          </span>
                        {/if}
                      </td>
                      <td>
                        {#if tier.isEditing}
                          <button class="btn-action btn-save" on:click={() => saveTier(tier)}>
                            ✓
                          </button>
                        {:else}
                          <button class="btn-action btn-edit" on:click={() => editTier(tier.id)}>
                            ✏️
                          </button>
                          <button class="btn-action btn-delete" on:click={() => deleteTier(tier.id)}>
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
        {:else}
          <div class="empty-state">
            <div class="empty-icon">🛒</div>
            <p>{isRTL ? 'لم يتم إضافة مستويات خصم بعد' : 'No discount tiers added yet'}</p>
            <p class="empty-hint">{isRTL ? 'انقر على "إضافة مستوى" لبدء إنشاء مستويات الخصم' : 'Click "Add Tier" to start creating discount tiers'}</p>
          </div>
        {/if}
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
  .cart-discount-window {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: white;
    border-radius: 12px;
    overflow: hidden;
  }

  .window-header {
    padding: 24px;
    background: linear-gradient(135deg, #eab308 0%, #ca8a04 100%);
    color: white;
    border-bottom: 4px solid #a16207;
  }

  .window-title {
    margin: 0 0 16px 0;
    font-size: 24px;
    font-weight: 700;
  }

  .step-indicator {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .step-item {
    display: flex;
    align-items: center;
    gap: 8px;
    opacity: 0.6;
    transition: opacity 0.3s;
  }

  .step-item.active,
  .step-item.completed {
    opacity: 1;
  }

  .step-circle {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    font-size: 14px;
  }

  .step-item.active .step-circle {
    background: white;
    color: #ca8a04;
  }

  .step-item.completed .step-circle {
    background: white;
    color: #16a34a;
  }

  .step-label {
    font-size: 14px;
    font-weight: 500;
  }

  .step-divider {
    flex: 1;
    height: 2px;
    background: rgba(255, 255, 255, 0.3);
  }

  .error-message {
    padding: 16px 24px;
    background: #fee2e2;
    border-bottom: 2px solid #fecaca;
    color: #dc2626;
    font-size: 14px;
  }

  .step-content {
    flex: 1;
    overflow-y: auto;
    padding: 24px;
  }

  .step-content-full {
    padding: 0;
  }

  .form-section {
    max-width: 900px;
    margin: 0 auto;
  }

  .section-title {
    font-size: 18px;
    font-weight: 600;
    color: #1f2937;
    margin: 0 0 20px 0;
    padding-bottom: 12px;
    border-bottom: 2px solid #f3f4f6;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
    margin-bottom: 20px;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .form-group label {
    font-size: 14px;
    font-weight: 500;
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

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
  }

  .checkbox-label input[type="checkbox"] {
    width: 18px;
    height: 18px;
    cursor: pointer;
  }

  .tier-table-container {
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
    margin-bottom: 20px;
  }

  .table-title {
    font-size: 20px;
    font-weight: 600;
    margin: 0;
  }

  .btn-add-tier {
    padding: 10px 20px;
    background: linear-gradient(135deg, #eab308 0%, #ca8a04 100%);
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
  }

  .btn-add-tier:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(234, 179, 8, 0.3);
  }

  .tiers-section {
    flex: 1;
    overflow: hidden;
  }

  .table-wrapper {
    max-height: calc(100vh - 400px);
    overflow-y: auto;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
  }

  .tiers-table {
    width: 100%;
    border-collapse: collapse;
  }

  .tiers-table thead {
    position: sticky;
    top: 0;
    background: #f9fafb;
    z-index: 1;
  }

  .tiers-table th {
    padding: 12px;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 2px solid #e5e7eb;
    font-size: 13px;
  }

  .tiers-table td {
    padding: 12px;
    border-bottom: 1px solid #e5e7eb;
    font-size: 13px;
  }

  .tier-row {
    background: white;
    transition: background 0.2s;
  }

  .tier-row:hover {
    background: #f9fafb;
  }

  .input-amount,
  .input-value,
  .input-select {
    width: 100%;
    padding: 6px 8px;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 13px;
  }

  .discount-value {
    font-weight: 600;
    color: #16a34a;
  }

  .btn-action {
    padding: 6px 12px;
    border: none;
    border-radius: 4px;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.2s;
    margin-right: 4px;
  }

  .btn-save {
    background: #16a34a;
    color: white;
  }

  .btn-save:hover {
    background: #15803d;
  }

  .btn-edit {
    background: #3b82f6;
    color: white;
  }

  .btn-edit:hover {
    background: #2563eb;
  }

  .btn-delete {
    background: #ef4444;
    color: white;
  }

  .btn-delete:hover {
    background: #dc2626;
  }

  .empty-state {
    text-align: center;
    padding: 60px 20px;
    color: #6b7280;
  }

  .empty-icon {
    font-size: 64px;
    margin-bottom: 16px;
  }

  .empty-hint {
    font-size: 14px;
    margin-top: 8px;
  }

  .window-footer {
    padding: 20px 24px;
    border-top: 2px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
    gap: 12px;
    background: #f9fafb;
  }

  .btn-primary,
  .btn-secondary {
    padding: 10px 24px;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-primary {
    background: linear-gradient(135deg, #eab308 0%, #ca8a04 100%);
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(234, 179, 8, 0.3);
  }

  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-secondary {
    background: white;
    color: #374151;
    border: 1px solid #d1d5db;
  }

  .btn-secondary:hover:not(:disabled) {
    background: #f9fafb;
  }

  .rtl {
    direction: rtl;
  }

  .rtl .tiers-table th,
  .rtl .tiers-table td {
    text-align: right;
  }

  .rtl .btn-action {
    margin-right: 0;
    margin-left: 4px;
  }
</style>
