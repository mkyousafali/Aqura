<script>
  import { onMount, onDestroy } from 'svelte';
  import { currentLocale } from '$lib/i18n';
  import { supabase } from '$lib/utils/supabase';
  import { openWindow } from '$lib/utils/windowManagerUtils';
  import BundleOfferWindow from '$lib/components/desktop-interface/admin-customer-app/offers/BundleOfferWindow.svelte';
  import BuyXGetYOfferWindow from '$lib/components/desktop-interface/admin-customer-app/offers/BuyXGetYOfferWindow.svelte';
  import PercentageOfferWindow from '$lib/components/desktop-interface/admin-customer-app/offers/PercentageOfferWindow.svelte';
  import SpecialPriceOfferWindow from '$lib/components/desktop-interface/admin-customer-app/offers/SpecialPriceOfferWindow.svelte';
  import CartDiscountWindow from '$lib/components/desktop-interface/admin-customer-app/offers/CartDiscountWindow.svelte';
  
  let loading = true;
  let offers = [];
  let filteredOffers = [];
  let branches = [];
  let searchQuery = '';
  let statusFilter = 'all'; // all | active | scheduled | expired | paused
  let typeFilter = 'all'; // all | product | bundle | cart | bogo
  let branchFilter = 'all'; // all | branch_id
  let serviceFilter = 'all'; // all | delivery | pickup | both
  
  // Stats
  let stats = {
    activeOffers: 0,
    totalSavings: 0,
    mostUsed: '',
    expiringSoon: 0
  };
  
  // Reactive locale
  $: locale = $currentLocale;
  $: isRTL = locale === 'ar';
  
  // i18n texts
  $: texts = locale === 'ar' ? {
    title: 'إدارة العروض',
    createNew: 'إنشاء عرض جديد',
    refresh: 'تحديث',
    search: 'بحث عن عرض...',
    filterStatus: 'تصفية حسب الحالة',
    filterType: 'تصفية حسب النوع',
    filterBranch: 'تصفية حسب الفرع',
    filterService: 'تصفية حسب الخدمة',
    all: 'الكل',
    globalOffers: 'عروض عامة',
    active: 'نشط',
    scheduled: 'مجدول',
    expired: 'منتهي',
    paused: 'متوقف',
    product: 'خصم منتج',
    bundle: 'عرض حزمة',
    customer: 'عرض خاص',
    cart: 'عرض سلة',
    bogo: 'اشتري واحصل',
    minPurchase: 'حد أدنى للشراء',
    delivery: 'توصيل',
    pickup: 'استلام',
    both: 'كلاهما',
    statsActive: 'العروض النشطة',
    statsSavings: 'إجمالي التوفير هذا الشهر',
    statsMostUsed: 'العرض الأكثر استخداماً',
    statsExpiring: 'تنتهي قريباً',
    sar: 'ر.س',
    noOffers: 'لا توجد عروض',
    noOffersDesc: 'ابدأ بإنشاء عرض جديد',
    edit: 'تعديل',
    analytics: 'الإحصائيات',
    pause: 'إيقاف',
    resume: 'استئناف',
    delete: 'حذف',
    duplicate: 'نسخ',
    usedTimes: 'مرة استخدام',
    savedCustomers: 'وفر العملاء',
    applicableTo: 'ينطبق على',
    products: 'منتجات',
    allProducts: 'جميع المنتجات',
    allCustomers: 'جميع العملاء',
    vipCustomers: 'عملاء VIP',
    specificCustomers: 'عملاء محددين',
    dateRange: 'من {start} إلى {end}',
    loadingError: 'حدث خطأ أثناء تحميل البيانات',
    deleteConfirm: 'هل أنت متأكد من حذف هذا العرض؟',
    global: 'عام',
    branchSpecific: 'خاص بالفرع'
  } : {
    title: 'Offer Management',
    createNew: 'Create New Offer',
    refresh: 'Refresh',
    search: 'Search offers...',
    filterStatus: 'Filter by Status',
    filterType: 'Filter by Type',
    filterBranch: 'Filter by Branch',
    filterService: 'Filter by Service',
    all: 'All',
    globalOffers: 'Global Offers',
    active: 'Active',
    scheduled: 'Scheduled',
    expired: 'Expired',
    paused: 'Paused',
    product: 'Product Discount',
    bundle: 'Bundle Offer',
    customer: 'Customer-Specific',
    cart: 'Cart-Level',
    bogo: 'BOGO',
    minPurchase: 'Min Purchase',
    delivery: 'Delivery',
    pickup: 'Pickup',
    both: 'Both',
    statsActive: 'Active Offers',
    statsSavings: 'Total Savings This Month',
    statsMostUsed: 'Most Used Offer',
    statsExpiring: 'Expiring Soon',
    sar: 'SAR',
    noOffers: 'No Offers Yet',
    noOffersDesc: 'Start by creating a new offer',
    edit: 'Edit',
    analytics: 'Analytics',
    pause: 'Pause',
    resume: 'Resume',
    delete: 'Delete',
    duplicate: 'Duplicate',
    usedTimes: 'times used',
    savedCustomers: 'saved customers',
    applicableTo: 'Applicable to',
    products: 'products',
    allProducts: 'All Products',
    allCustomers: 'All Customers',
    vipCustomers: 'VIP Customers',
    specificCustomers: 'Specific Customers',
    dateRange: '{start} to {end}',
    loadingError: 'Error loading data',
    deleteConfirm: 'Are you sure you want to delete this offer?',
    global: 'Global',
    branchSpecific: 'Branch-Specific'
  };
  
  onMount(async () => {
    await loadBranches();
    await loadOffers();
    await loadStats();
    
    // Set up real-time subscriptions for offers
    const offersChannel = supabase
      .channel('offers-management-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offers' }, (payload) => {
        console.log('📊 Offers table changed:', payload.eventType);
        loadOffers();
        loadStats();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offer_products' }, (payload) => {
        console.log('📦 Offer products changed:', payload.eventType);
        loadOffers();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offer_bundles' }, (payload) => {
        console.log('🎁 Offer bundles changed:', payload.eventType);
        loadOffers();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bogo_offer_rules' }, (payload) => {
        console.log('🎯 BOGO rules changed:', payload.eventType);
        loadOffers();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offer_cart_tiers' }, (payload) => {
        console.log('🛒 Cart tiers changed:', payload.eventType);
        loadOffers();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'offer_usage_logs' }, (payload) => {
        console.log('📈 Usage logs changed:', payload.eventType);
        loadStats();
      })
      .subscribe();
    
    return () => {
      supabase.removeChannel(offersChannel);
    };
  });
  
  async function loadBranches() {
    try {
      const { data, error } = await supabase
        .from('branches')
        .select('id, name_ar, name_en')
        .order('id');
      
      if (error) throw error;
      branches = data || [];
    } catch (error) {
      console.error('Error loading branches:', error);
    }
  }
  
  async function loadOffers() {
    loading = true;
    try {
      const { data, error } = await supabase
        .from('offers')
        .select(`
          *,
          offer_products (
            id,
            product_id,
            offer_percentage,
            offer_price
          ),
          offer_cart_tiers (
            id,
            tier_number,
            min_amount,
            max_amount,
            discount_type,
            discount_value
          )
        `)
        .order('created_at', { ascending: false });
      
      if (error) throw error;
      
      // Load bundle data separately (not directly joinable in Supabase)
      const offerIds = data?.map(o => o.id) || [];
      const { data: bundlesData } = await supabase
        .from('offer_bundles')
        .select('*')
        .in('offer_id', offerIds);
      
      // Load BOGO rules data separately
      const { data: bogoRulesData } = await supabase
        .from('bogo_offer_rules')
        .select('*')
        .in('offer_id', offerIds);
      
      // Create a map of offer_id to bundles
      const bundlesMap = new Map();
      bundlesData?.forEach(bundle => {
        if (!bundlesMap.has(bundle.offer_id)) {
          bundlesMap.set(bundle.offer_id, []);
        }
        bundlesMap.get(bundle.offer_id).push(bundle);
      });
      
      // Create a map of offer_id to BOGO rules
      const bogoRulesMap = new Map();
      bogoRulesData?.forEach(rule => {
        if (!bogoRulesMap.has(rule.offer_id)) {
          bogoRulesMap.set(rule.offer_id, []);
        }
        bogoRulesMap.get(rule.offer_id).push(rule);
      });
      
      // Transform data and determine status
      offers = (data || []).map(offer => {
        const now = new Date();
        const startDate = new Date(offer.start_date);
        const endDate = new Date(offer.end_date);
        
        let status = 'active';
        if (!offer.is_active) {
          status = 'paused';
        } else if (now < startDate) {
          status = 'scheduled';
        } else if (now > endDate) {
          status = 'expired';
        }
        
        const bundles = bundlesMap.get(offer.id) || [];
        const bogoRules = bogoRulesMap.get(offer.id) || [];
        
        return {
          ...offer,
          status,
          productCount: offer.offer_products?.length || 0,
          tierCount: offer.offer_cart_tiers?.length || 0,
          tiers: offer.offer_cart_tiers || [],
          bundleCount: bundles.length,
          bundles: bundles,
          bogoRulesCount: bogoRules.length,
          bogoRules: bogoRules
        };
      });
      
      console.log('Loaded offers:', offers.length, offers);
      applyFilters();
      console.log('Filtered offers:', filteredOffers.length, filteredOffers);
    } catch (error) {
      console.error('Error loading offers:', error);
      alert(texts.loadingError);
    } finally {
      loading = false;
    }
  }
  
  async function loadStats() {
    try {
      const now = new Date();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      
      // Get active offers count
      const { count: activeCount } = await supabase
        .from('offers')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)
        .lte('start_date', now.toISOString())
        .gte('end_date', now.toISOString());
      
      // Get total savings this month from usage logs
      const { data: usageLogs } = await supabase
        .from('offer_usage_logs')
        .select('discount_applied')
        .gte('used_at', startOfMonth.toISOString());
      
      const totalSavings = usageLogs?.reduce((sum, log) => sum + (parseFloat(log.discount_applied) || 0), 0) || 0;
      
      // Get most used offer
      const { data: mostUsedData } = await supabase
        .from('offers')
        .select('name_ar, name_en, current_total_uses')
        .order('current_total_uses', { ascending: false })
        .limit(1)
        .single();
      
      // Get expiring soon count (within 7 days)
      const sevenDaysLater = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      const { count: expiringCount } = await supabase
        .from('offers')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)
        .gte('end_date', now.toISOString())
        .lte('end_date', sevenDaysLater.toISOString());
      
      stats = {
        activeOffers: activeCount || 0,
        totalSavings: Math.round(totalSavings),
        mostUsed: mostUsedData ? (locale === 'ar' ? mostUsedData.name_ar : mostUsedData.name_en) : '-',
        expiringSoon: expiringCount || 0
      };
    } catch (error) {
      console.error('Error loading stats:', error);
      stats = {
        activeOffers: 0,
        totalSavings: 0,
        mostUsed: '-',
        expiringSoon: 0
      };
    }
  }
  
  async function refreshData() {
    await loadBranches();
    await loadOffers();
    await loadStats();
  }
  
  function applyFilters() {
    console.log('🔍 applyFilters() called');
    console.log('  - Total offers:', offers.length);
    console.log('  - Status filter:', statusFilter);
    console.log('  - Type filter:', typeFilter);
    
    filteredOffers = offers.filter(offer => {
      const matchesSearch = !searchQuery || 
        (offer.name_ar && offer.name_ar.toLowerCase().includes(searchQuery.toLowerCase())) ||
        (offer.name_en && offer.name_en.toLowerCase().includes(searchQuery.toLowerCase()));
      
      const matchesStatus = statusFilter === 'all' || offer.status === statusFilter;
      const matchesType = typeFilter === 'all' || offer.type === typeFilter;
      const matchesBranch = branchFilter === 'all' || 
        (branchFilter === 'global' && !offer.branch_id) ||
        (offer.branch_id && offer.branch_id.toString() === branchFilter);
      const matchesService = serviceFilter === 'all' || offer.service_type === serviceFilter;
      
      const passes = matchesSearch && matchesStatus && matchesType && matchesBranch && matchesService;
      
      if (!passes) {
        console.log(`  ❌ Offer ${offer.id} (${offer.name_en}) filtered out:`, {
          matchesSearch,
          matchesStatus: `${matchesStatus} (status: ${offer.status}, filter: ${statusFilter})`,
          matchesType,
          matchesBranch,
          matchesService
        });
      }
      
      return passes;
    });
    
    console.log('  - Filtered result:', filteredOffers.length, 'offers');
  }
  
  function createOfferWithType(type) {
    // Check if cart discount and if there's already an active one
    if (type === 'cart') {
      const hasActiveCart = offers.some(offer => 
        offer.type === 'cart' && 
        offer.status === 'active' && 
        offer.is_active
      );
      
      if (hasActiveCart) {
        alert(locale === 'ar' 
          ? 'يوجد بالفعل خصم سلة نشط. لا يمكن إنشاء أكثر من خصم سلة نشط في نفس الوقت. يرجى إيقاف الخصم الحالي أولاً.'
          : 'There is already an active cart discount. You cannot create more than one active cart discount at a time. Please pause the current one first.'
        );
        return;
      }
    }
    
    // Open percentage offer in a window
    if (type === 'percentage') {
      openWindow({
        id: `percentage-offer-create-${Date.now()}`,
        title: locale === 'ar' ? '📊 إنشاء خصم بالنسبة' : '📊 Create Percentage Offer',
        component: PercentageOfferWindow,
        props: {
          editMode: false,
          offerId: null
        },
        width: 1000,
        height: 700,
        onClose: async () => {
          await loadOffers();
          await loadStats();
        }
      });
    } else if (type === 'special_price') {
      // Open special price offer in a window
      openWindow({
        id: `special-price-offer-create-${Date.now()}`,
        title: locale === 'ar' ? '💰 إنشاء سعر خاص' : '💰 Create Special Price Offer',
        component: SpecialPriceOfferWindow,
        props: {
          editMode: false,
          offerId: null
        },
        width: 1000,
        height: 700,
        onClose: async () => {
          await loadOffers();
          await loadStats();
        }
      });
    } else if (type === 'bundle') {
      // Open bundle offers in a window
      openWindow({
        id: `bundle-offer-create-${Date.now()}`,
        title: locale === 'ar' ? '📦 إنشاء عرض حزمة' : '📦 Create Bundle Offer',
        component: BundleOfferWindow,
        props: {
          editMode: false,
          offerId: null
        },
        width: 1000,
        height: 700,
        onClose: async () => {
          await loadOffers();
          await loadStats();
        }
      });
    } else if (type === 'bogo') {
      // Open Buy X Get Y offers in a window
      openWindow({
        id: `buy-x-get-y-create-${Date.now()}`,
        title: locale === 'ar' ? '🎁 إنشاء عرض اشتري واحصل' : '🎁 Create Buy X Get Y Offer',
        component: BuyXGetYOfferWindow,
        props: {
          editMode: false,
          offerId: null
        },
        width: 1000,
        height: 700,
        onClose: async () => {
          await loadOffers();
          await loadStats();
        }
      });
    } else if (type === 'cart') {
      // Open Cart Discount in a window
      openWindow({
        id: `cart-discount-create-${Date.now()}`,
        title: locale === 'ar' ? '🛒 إنشاء خصم السلة' : '🛒 Create Cart Discount',
        component: CartDiscountWindow,
        props: {
          editMode: false,
          offerId: null
        },
        width: 1000,
        height: 700,
        onClose: async () => {
          await loadOffers();
          await loadStats();
        }
      });
    }
  }
  
  async function editOffer(offerId) {
    // Find the offer to check its type
    const offer = offers.find(o => o.id === offerId);
    
    // Open product discount offers - need to check offer_products to determine percentage vs special price
    if (offer && offer.type === 'product') {
      // Query offer_products to determine if it's percentage or special price
      const { data: offerProducts, error } = await supabase
        .from('offer_products')
        .select('offer_percentage')
        .eq('offer_id', offerId)
        .limit(1)
        .single();
      
      if (error) {
        console.error('Error loading offer products:', error);
        return;
      }
      
      // Check if it's percentage (offer_percentage is not null) or special price
      if (offerProducts && offerProducts.offer_percentage !== null) {
        // Percentage offer
        openWindow({
          id: `percentage-offer-edit-${offerId}`,
          title: locale === 'ar' ? '📊 تعديل خصم بالنسبة' : '📊 Edit Percentage Offer',
          component: PercentageOfferWindow,
          props: {
            editMode: true,
            offerId: offerId
          },
          width: 1000,
          height: 700,
          onClose: async () => {
            await loadOffers();
            await loadStats();
          }
        });
      } else {
        // Special price offer
        openWindow({
          id: `special-price-offer-edit-${offerId}`,
          title: locale === 'ar' ? '💰 تعديل سعر خاص' : '💰 Edit Special Price Offer',
          component: SpecialPriceOfferWindow,
          props: {
            editMode: true,
            offerId: offerId
          },
          width: 1000,
          height: 700,
          onClose: async () => {
            await loadOffers();
            await loadStats();
          }
        });
      }
    } else if (offer && offer.type === 'bundle') {
      // Open bundle offers in a window
      openWindow({
        id: `bundle-offer-edit-${offerId}`,
        title: locale === 'ar' ? '📦 تعديل عرض حزمة' : '📦 Edit Bundle Offer',
        component: BundleOfferWindow,
        props: {
          editMode: true,
          offerId: offerId
        },
        width: 1000,
        height: 700,
        onClose: async () => {
          await loadOffers();
          await loadStats();
        }
      });
    } else if (offer && offer.type === 'bogo') {
      // Open Buy X Get Y offers in a window
      openWindow({
        id: `buy-x-get-y-edit-${offerId}`,
        title: locale === 'ar' ? '🎁 تعديل عرض اشتري واحصل' : '🎁 Edit Buy X Get Y Offer',
        component: BuyXGetYOfferWindow,
        props: {
          editMode: true,
          offerId: offerId
        },
        width: 1000,
        height: 700,
        onClose: async () => {
          await loadOffers();
          await loadStats();
        }
      });
    } else if (offer && offer.type === 'cart') {
      // Open Cart Discount in a window
      openWindow({
        id: `cart-discount-edit-${offerId}`,
        title: locale === 'ar' ? '🛒 تعديل خصم السلة' : '🛒 Edit Cart Discount',
        component: CartDiscountWindow,
        props: {
          editMode: true,
          offerId: offerId
        },
        width: 1000,
        height: 700,
        onClose: async () => {
          await loadOffers();
          await loadStats();
        }
      });
    } else {
      // Other offer types - log warning
      console.warn('Unknown offer type:', offer?.type);
    }
  }
  
  async function updateOfferStatus(offerId, isActive) {
    try {
      const { error } = await supabase
        .from('offers')
        .update({ is_active: isActive })
        .eq('id', offerId);
      
      if (error) throw error;
      
      // Refresh offers
      await loadOffers();
      await loadStats();
      
      // If pausing an offer, reset status filter to 'all' so user can see the paused offer
      if (!isActive && statusFilter === 'active') {
        statusFilter = 'all';
        applyFilters();
      }
    } catch (error) {
      console.error('Error updating offer status:', error);
      alert(locale === 'ar' ? 'حدث خطأ أثناء تحديث حالة العرض' : 'Error updating offer status');
    }
  }
  
  function deleteOffer(offerId) {
    if (confirm(texts.deleteConfirm)) {
      performDeleteOffer(offerId);
    }
  }
  
  async function performDeleteOffer(offerId) {
    try {
      // Debug: Log the offerId
      console.log('Deleting offer with ID:', offerId, 'Type:', typeof offerId);
      
      // 1. Get current user
      const { data: { user } } = await supabase.auth.getUser();
      console.log('Current user ID:', user?.id, 'Type:', typeof user?.id);
      
      // 2. Get the offer data
      const { data: offerData, error: offerError } = await supabase
        .from('offers')
        .select('*')
        .eq('id', offerId)
        .single();
      
      if (offerError) throw offerError;
      
      console.log('Offer data:', offerData);
      
      // 3. Get all associated bundles
      const { data: bundlesData, error: bundlesError } = await supabase
        .from('offer_bundles')
        .select('*')
        .eq('offer_id', offerId);
      
      if (bundlesError) throw bundlesError;
      
      console.log('Bundles data:', bundlesData);
      
      // 4. Prepare archive data - offerId is INTEGER, not UUID
      const archiveData = {
        original_offer_id: offerId, // Keep as integer
        offer_data: offerData,
        bundles_data: bundlesData || [],
        deleted_by: user?.id || null, // This IS a UUID
        deletion_reason: 'Deleted by admin'
      };
      
      console.log('Archive data to insert:', archiveData);
      
      // 5. Archive to deleted_bundle_offers table
      const { data: insertedData, error: archiveError } = await supabase
        .from('deleted_bundle_offers')
        .insert(archiveData)
        .select();
      
      if (archiveError) {
        console.error('Error archiving offer:', archiveError);
        throw new Error(isRTL 
          ? `فشل في أرشفة العرض: ${archiveError.message}` 
          : `Failed to archive offer: ${archiveError.message}`
        );
      }
      
      console.log('Archive successful:', insertedData);
      
      // 6. Delete bundles from offer_bundles
      if (bundlesData && bundlesData.length > 0) {
        console.log('Deleting bundles from offer_bundles...');
        const { error: bundleDeleteError } = await supabase
          .from('offer_bundles')
          .delete()
          .eq('offer_id', offerId);
        
        if (bundleDeleteError) {
          console.error('Error deleting bundles:', bundleDeleteError);
          throw bundleDeleteError;
        }
        console.log('Bundles deleted successfully');
      }
      
      // 7. Delete the offer from offers table
      console.log('Deleting offer from offers table...');
      const { data: deletedOffer, error: deleteError } = await supabase
        .from('offers')
        .delete()
        .eq('id', offerId)
        .select();
      
      if (deleteError) {
        console.error('Error deleting offer:', deleteError);
        throw deleteError;
      }
      
      console.log('Offer deleted successfully:', deletedOffer);
      
      // 8. Show success message
      alert(isRTL 
        ? '✅ تم نقل العرض إلى الأرشيف بنجاح!' 
        : '✅ Offer archived successfully!'
      );
      
      // 9. Broadcast to customer displays to refresh offers
      if (typeof BroadcastChannel !== 'undefined') {
        const channel = new BroadcastChannel('aqura-offers-update');
        channel.postMessage('refresh-offers');
        channel.close();
      }
      
      // 10. Refresh offers
      console.log('Refreshing offers list...');
      await loadOffers();
      await loadStats();
      console.log('Refresh complete');
    } catch (error) {
      console.error('Error deleting offer:', error);
      alert(isRTL 
        ? `❌ حدث خطأ أثناء حذف العرض: ${error.message}` 
        : `❌ Error deleting offer: ${error.message}`
      );
    }
  }
  
  async function toggleOfferStatus(offerId, currentStatus) {
    try {
      const newStatus = !currentStatus;
      
      // Update offer status in database
      const { error } = await supabase
        .from('offers')
        .update({ is_active: newStatus })
        .eq('id', offerId);
      
      if (error) throw error;
      
      // Show success message
      const message = newStatus
        ? (isRTL ? '✅ تم تفعيل العرض بنجاح!' : '✅ Offer activated successfully!')
        : (isRTL ? '⏸️ تم إيقاف العرض مؤقتاً!' : '⏸️ Offer paused successfully!');
      
      alert(message);
      
      // Broadcast to customer displays to refresh offers
      if (typeof BroadcastChannel !== 'undefined') {
        const channel = new BroadcastChannel('aqura-offers-update');
        channel.postMessage('refresh-offers');
        channel.close();
      }
      
      // Refresh offers list
      await loadOffers();
      await loadStats();
    } catch (error) {
      console.error('Error toggling offer status:', error);
      alert(isRTL 
        ? `❌ حدث خطأ أثناء تغيير حالة العرض: ${error.message}` 
        : `❌ Error toggling offer status: ${error.message}`
      );
    }
  }
  
  async function duplicateOffer(offerId) {
    try {
      // 1. Get the original offer data
      const { data: originalOffer, error: offerError } = await supabase
        .from('offers')
        .select('*')
        .eq('id', offerId)
        .single();
      
      if (offerError) throw offerError;
      
      // 2. Get all associated bundles if it's a bundle offer
      let originalBundles = [];
      if (originalOffer.type === 'bundle') {
        const { data: bundlesData, error: bundlesError } = await supabase
          .from('offer_bundles')
          .select('*')
          .eq('offer_id', offerId);
        
        if (bundlesError) throw bundlesError;
        originalBundles = bundlesData || [];
      }
      
      // 3. Create duplicate offer with modified name
      const duplicateOfferData = {
        ...originalOffer,
        name_ar: `${originalOffer.name_ar} (نسخة)`,
        name_en: `${originalOffer.name_en} (Copy)`,
        is_active: false, // Duplicate starts as inactive
        current_total_uses: 0,
        current_limit_per_user: 0
      };
      
      // Remove id and timestamps
      delete duplicateOfferData.id;
      delete duplicateOfferData.created_at;
      delete duplicateOfferData.updated_at;
      
      // 4. Insert the duplicate offer
      const { data: newOffer, error: insertError } = await supabase
        .from('offers')
        .insert(duplicateOfferData)
        .select()
        .single();
      
      if (insertError) throw insertError;
      
      // 5. Duplicate bundles if it's a bundle offer
      if (originalBundles.length > 0) {
        const duplicateBundles = originalBundles.map(bundle => ({
          offer_id: newOffer.id,
          bundle_name_ar: bundle.bundle_name_ar,
          bundle_name_en: bundle.bundle_name_en,
          discount_type: bundle.discount_type,
          discount_value: bundle.discount_value,
          required_products: bundle.required_products
        }));
        
        const { error: bundlesInsertError } = await supabase
          .from('offer_bundles')
          .insert(duplicateBundles);
        
        if (bundlesInsertError) throw bundlesInsertError;
      }
      
      // 6. Show success message
      alert(isRTL 
        ? '✅ تم نسخ العرض بنجاح!' 
        : '✅ Offer duplicated successfully!'
      );
      
      // 7. Broadcast to customer displays to refresh offers
      if (typeof BroadcastChannel !== 'undefined') {
        const channel = new BroadcastChannel('aqura-offers-update');
        channel.postMessage('refresh-offers');
        channel.close();
      }
      
      // 8. Refresh offers
      await loadOffers();
      await loadStats();
    } catch (error) {
      console.error('Error duplicating offer:', error);
      alert(isRTL 
        ? `❌ حدث خطأ أثناء نسخ العرض: ${error.message}` 
        : `❌ Error duplicating offer: ${error.message}`
      );
    }
  }
  
  function getOfferTypeBadge(offer) {
    // For product offers, determine if it's percentage or special price
    if (offer.type === 'product' && offer.offer_products && offer.offer_products.length > 0) {
      const firstProduct = offer.offer_products[0];
      if (firstProduct.offer_percentage !== null && firstProduct.offer_percentage !== undefined) {
        // Percentage offer
        return {
          color: '#22c55e',
          icon: '📊',
          label: locale === 'ar' ? 'خصم بالنسبة' : 'Percentage Offer'
        };
      } else {
        // Special price offer
        return {
          color: '#10b981',
          icon: '💰',
          label: locale === 'ar' ? 'سعر خاص' : 'Special Price Offer'
        };
      }
    }
    
    // Other offer types
    const badges = {
      product: { color: '#22c55e', icon: '🏷️', label: texts.product },
      bundle: { color: '#3b82f6', icon: '📦', label: texts.bundle },
      cart: { color: '#eab308', icon: '🛒', label: texts.cart },
      bogo: { color: '#ef4444', icon: '🎁', label: texts.bogo }
    };
    return badges[offer.type] || badges.product;
  }
  
  function getServiceTypeBadge(serviceType) {
    const badges = {
      delivery: { icon: '🚚', label: texts.delivery },
      pickup: { icon: '🏪', label: texts.pickup },
      both: { icon: '🔄', label: texts.both }
    };
    return badges[serviceType] || badges.both;
  }
  
  function getBranchName(branchId) {
    if (!branchId) return texts.global;
    const branch = branches.find(b => b.id === branchId);
    return branch ? (locale === 'ar' ? branch.name_ar : branch.name_en) : `Branch ${branchId}`;
  }
  
  function getStatusBadge(status) {
    const badges = {
      active: { color: '#22c55e', icon: '🟢', label: texts.active },
      scheduled: { color: '#eab308', icon: '🟡', label: texts.scheduled },
      expired: { color: '#ef4444', icon: '🔴', label: texts.expired },
      paused: { color: '#6b7280', icon: '⏸️', label: texts.paused }
    };
    return badges[status] || badges.active;
  }
  
  function formatDate(dateString) {
    const date = new Date(dateString);
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const year = date.getFullYear();
    
    // Get time in 12-hour format
    let hours = date.getHours();
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12;
    hours = hours ? hours : 12; // 0 should be 12
    const formattedHours = String(hours).padStart(2, '0');
    
    return `${day}-${month}-${year} ${formattedHours}:${minutes} ${ampm}`;
  }
  
  // Watch for filter changes and offers data changes
  $: {
    searchQuery;
    statusFilter;
    typeFilter;
    branchFilter;
    serviceFilter;
    offers; // Also trigger when offers array changes
    if (offers.length >= 0) {
      applyFilters();
    }
  }
</script>

<div class="offer-management" dir={isRTL ? 'rtl' : 'ltr'}>
  <!-- Header -->
  <div class="header">
    <h1 class="title">🎁 {texts.title}</h1>
    <div class="create-buttons">
      <button class="btn-refresh" on:click={refreshData} title={texts.refresh}>
        🔄 {texts.refresh}
      </button>
      <button class="btn-create btn-percentage" on:click={() => createOfferWithType('percentage')}>
        📊 {locale === 'ar' ? 'خصم بالنسبة' : 'Percentage Offer'}
      </button>
      <button class="btn-create btn-special-price" on:click={() => createOfferWithType('special_price')}>
        💰 {locale === 'ar' ? 'سعر خاص' : 'Special Price Offer'}
      </button>
      <button class="btn-create btn-bogo" on:click={() => createOfferWithType('bogo')}>
        🎁 {locale === 'ar' ? 'اشتري واحصل' : 'Buy X Get Y'}
      </button>
      <button class="btn-create btn-bundle" on:click={() => createOfferWithType('bundle')}>
        📦 {locale === 'ar' ? 'عرض حزمة' : 'Bundle Offer'}
      </button>
      <button class="btn-create btn-cart" on:click={() => createOfferWithType('cart')}>
        🛒 {locale === 'ar' ? 'خصم السلة' : 'Cart Discount'}
      </button>
    </div>
  </div>
  
  <!-- Stats Bar -->
  <div class="stats-bar">
    <div class="stat-card">
      <div class="stat-icon" style="background: #dcfce7;">🟢</div>
      <div class="stat-content">
        <div class="stat-label">{texts.statsActive}</div>
        <div class="stat-value">{stats.activeOffers}</div>
      </div>
    </div>
    
    <div class="stat-card">
      <div class="stat-icon" style="background: #dbeafe;">💰</div>
      <div class="stat-content">
        <div class="stat-label">{texts.statsSavings}</div>
        <div class="stat-value">{stats.totalSavings.toLocaleString()} {texts.sar}</div>
      </div>
    </div>
    
    <div class="stat-card">
      <div class="stat-icon" style="background: #fef3c7;">⭐</div>
      <div class="stat-content">
        <div class="stat-label">{texts.statsMostUsed}</div>
        <div class="stat-value" style="font-size: 0.9rem;">{stats.mostUsed}</div>
      </div>
    </div>
    
    <div class="stat-card">
      <div class="stat-icon" style="background: #fee2e2;">⏰</div>
      <div class="stat-content">
        <div class="stat-label">{texts.statsExpiring}</div>
        <div class="stat-value">{stats.expiringSoon}</div>
      </div>
    </div>
  </div>
  
  <!-- Filters -->
  <div class="filters">
    <div class="search-box">
      <span class="search-icon">🔍</span>
      <input
        type="text"
        class="search-input"
        placeholder={texts.search}
        bind:value={searchQuery}
      />
    </div>
    
    <select class="filter-select" bind:value={statusFilter}>
      <option value="all">{texts.filterStatus}: {texts.all}</option>
      <option value="active">{texts.active}</option>
      <option value="scheduled">{texts.scheduled}</option>
      <option value="expired">{texts.expired}</option>
      <option value="paused">{texts.paused}</option>
    </select>
    
    <select class="filter-select" bind:value={typeFilter}>
      <option value="all">{texts.filterType}: {texts.all}</option>
      <option value="product">{texts.product}</option>
      <option value="bundle">{texts.bundle}</option>
      <option value="cart">{texts.cart}</option>
      <option value="bogo">{texts.bogo}</option>
    </select>
    
    <select class="filter-select" bind:value={branchFilter}>
      <option value="all">{texts.filterBranch}: {texts.all}</option>
      <option value="global">{texts.globalOffers}</option>
      {#each branches as branch}
        <option value={branch.id.toString()}>
          {locale === 'ar' ? branch.name_ar : branch.name_en}
        </option>
      {/each}
    </select>
    
    <select class="filter-select" bind:value={serviceFilter}>
      <option value="all">{texts.filterService}: {texts.all}</option>
      <option value="delivery">{texts.delivery}</option>
      <option value="pickup">{texts.pickup}</option>
      <option value="both">{texts.both}</option>
    </select>
  </div>
  
  <!-- Offers Grid -->
  {#if loading}
    <div class="loading">Loading offers...</div>
  {:else if filteredOffers.length === 0}
    <div class="empty-state">
      <div class="empty-icon">🎁</div>
      <h2 class="empty-title">{texts.noOffers}</h2>
      <p class="empty-desc">{texts.noOffersDesc}</p>
      <button class="btn-primary" on:click={createNewOffer}>
        ➕ {texts.createNew}
      </button>
    </div>
  {:else}
    <div class="offers-grid">
      {#each filteredOffers as offer (offer.id)}
        {@const typeBadge = getOfferTypeBadge(offer)}
        {@const statusBadge = getStatusBadge(offer.status)}
        {@const serviceBadge = getServiceTypeBadge(offer.service_type)}
        
        <div class="offer-card">
          {#if offer.type === 'bundle'}
            <!-- Bundle Offer Card - Simplified Layout -->
            <!-- Type Badge -->
            <div class="offer-type-badge" style="background: {typeBadge.color};">
              {typeBadge.icon} {typeBadge.label}
            </div>
            
            <!-- Offer Name -->
            <div class="offer-header">
              <h3 class="offer-name">{locale === 'ar' ? offer.name_ar : offer.name_en}</h3>
            </div>
            
            <!-- Active Status -->
            <div class="offer-status-row">
              <div class="status-badge" style="color: {statusBadge.color};">
                {statusBadge.icon} {statusBadge.label}
              </div>
            </div>
            
            <!-- Branch & Service -->
            <div class="offer-meta">
              <span class="meta-badge">
                {offer.branch_id ? '🏢' : '🌍'} {getBranchName(offer.branch_id)}
              </span>
              <span class="meta-badge">
                {serviceBadge.icon} {serviceBadge.label}
              </span>
            </div>
            
            <!-- Total Bundles -->
            <div class="offer-info-row">
              <span class="info-label">{locale === 'ar' ? 'إجمالي الحزم:' : 'Total Bundles:'}</span>
              <span class="info-value">{offer.bundleCount || 0}</span>
            </div>
            
            <!-- Start Date - End Date -->
            <div class="offer-dates">
              <div class="date-item">
                <span class="date-label">{locale === 'ar' ? 'يبدأ:' : 'Start:'}</span>
                <span class="date-value">📅 {formatDate(offer.start_date)}</span>
              </div>
              <div class="date-item">
                <span class="date-label">{locale === 'ar' ? 'ينتهي:' : 'End:'}</span>
                <span class="date-value">📅 {formatDate(offer.end_date)}</span>
              </div>
            </div>
            
            <!-- Number of Customers Used the Offer -->
            <div class="offer-info-row">
              <span class="info-label">{locale === 'ar' ? 'عدد العملاء:' : 'Customers Used:'}</span>
              <span class="info-value">{offer.current_total_uses || 0}</span>
            </div>
            
            <!-- Actions: Edit, Status Toggle, Delete -->
            <div class="offer-actions">
              <button class="action-btn btn-edit" on:click={() => editOffer(offer.id)} title={texts.edit}>
                ✏️ {locale === 'ar' ? 'تعديل' : 'Edit'}
              </button>
              <button 
                class="action-btn btn-status" 
                on:click={() => toggleOfferStatus(offer.id, offer.is_active)} 
                title={offer.is_active ? (locale === 'ar' ? 'إيقاف' : 'Deactivate') : (locale === 'ar' ? 'تفعيل' : 'Activate')}
              >
                {offer.is_active ? '⏸️' : '▶️'} 
                {offer.is_active ? (locale === 'ar' ? 'إيقاف' : 'Pause') : (locale === 'ar' ? 'تفعيل' : 'Activate')}
              </button>
              <button class="action-btn btn-delete danger" on:click={() => deleteOffer(offer.id)} title={texts.delete}>
                🗑️ {locale === 'ar' ? 'حذف' : 'Delete'}
              </button>
            </div>
          {:else if offer.type === 'bogo'}
            <!-- BOGO Offer Card - Simplified Layout -->
            <!-- Type Badge -->
            <div class="offer-type-badge" style="background: {typeBadge.color};">
              {typeBadge.icon} {typeBadge.label}
            </div>
            
            <!-- Offer Name -->
            <div class="offer-header">
              <h3 class="offer-name">{locale === 'ar' ? offer.name_ar : offer.name_en}</h3>
            </div>
            
            <!-- Active Status -->
            <div class="offer-status-row">
              <div class="status-badge" style="color: {statusBadge.color};">
                {statusBadge.icon} {statusBadge.label}
              </div>
            </div>
            
            <!-- Branch & Service -->
            <div class="offer-meta">
              <span class="meta-badge">
                {offer.branch_id ? '🏢' : '🌍'} {getBranchName(offer.branch_id)}
              </span>
              <span class="meta-badge">
                {serviceBadge.icon} {serviceBadge.label}
              </span>
            </div>
            
            <!-- Total BOGO Rules -->
            <div class="offer-info-row">
              <span class="info-label">{locale === 'ar' ? 'إجمالي قواعد BOGO:' : 'Total BOGO Rules:'}</span>
              <span class="info-value">{offer.bogoRulesCount || 0}</span>
            </div>
            
            <!-- Start Date - End Date -->
            <div class="offer-dates">
              <div class="date-item">
                <span class="date-label">{locale === 'ar' ? 'يبدأ:' : 'Start:'}</span>
                <span class="date-value">📅 {formatDate(offer.start_date)}</span>
              </div>
              <div class="date-item">
                <span class="date-label">{locale === 'ar' ? 'ينتهي:' : 'End:'}</span>
                <span class="date-value">📅 {formatDate(offer.end_date)}</span>
              </div>
            </div>
            
            <!-- Number of Customers Used the Offer -->
            <div class="offer-info-row">
              <span class="info-label">{locale === 'ar' ? 'عدد العملاء:' : 'Customers Used:'}</span>
              <span class="info-value">{offer.current_total_uses || 0}</span>
            </div>
            
            <!-- Actions: Edit, Status Toggle, Delete -->
            <div class="offer-actions">
              <button class="action-btn btn-edit" on:click={() => editOffer(offer.id)} title={texts.edit}>
                ✏️ {locale === 'ar' ? 'تعديل' : 'Edit'}
              </button>
              <button 
                class="action-btn btn-status" 
                on:click={() => toggleOfferStatus(offer.id, offer.is_active)} 
                title={offer.is_active ? (locale === 'ar' ? 'إيقاف' : 'Deactivate') : (locale === 'ar' ? 'تفعيل' : 'Activate')}
              >
                {offer.is_active ? '⏸️' : '▶️'} 
                {offer.is_active ? (locale === 'ar' ? 'إيقاف' : 'Pause') : (locale === 'ar' ? 'تفعيل' : 'Activate')}
              </button>
              <button class="action-btn btn-delete danger" on:click={() => deleteOffer(offer.id)} title={texts.delete}>
                🗑️ {locale === 'ar' ? 'حذف' : 'Delete'}
              </button>
            </div>
          {:else if offer.type === 'product'}
            <!-- Percentage / Special Price Offer Card - Simplified Layout -->
            
            <!-- Type Badge -->
            <div class="offer-type-badge" style="background: {typeBadge.color};">
              {typeBadge.icon} {typeBadge.label}
            </div>
            
            <!-- Offer Name -->
            <div class="offer-header">
              <h3 class="offer-name">{locale === 'ar' ? offer.name_ar : offer.name_en}</h3>
            </div>
            
            <!-- Active Status -->
            <div class="offer-status-row">
              <div class="status-badge" style="color: {statusBadge.color};">
                {statusBadge.icon} {statusBadge.label}
              </div>
            </div>
            
            <!-- Branch & Service -->
            <div class="offer-meta">
              <span class="meta-badge">
                {offer.branch_id ? '🏢' : '🌍'} {getBranchName(offer.branch_id)}
              </span>
              <span class="meta-badge">
                {serviceBadge.icon} {serviceBadge.label}
              </span>
            </div>
            
            <!-- Total Products -->
            <div class="offer-info-row">
              <span class="info-label">{locale === 'ar' ? 'إجمالي المنتجات:' : 'Total Products:'}</span>
              <span class="info-value">{offer.productCount || 0}</span>
            </div>
            
            <!-- Start Date - End Date -->
            <div class="offer-dates">
              <div class="date-item">
                <span class="date-label">{locale === 'ar' ? 'يبدأ:' : 'Start:'}</span>
                <span class="date-value">📅 {formatDate(offer.start_date)}</span>
              </div>
              <div class="date-item">
                <span class="date-label">{locale === 'ar' ? 'ينتهي:' : 'End:'}</span>
                <span class="date-value">📅 {formatDate(offer.end_date)}</span>
              </div>
            </div>
            
            <!-- Number of Customers Used the Offer -->
            <div class="offer-info-row">
              <span class="info-label">{locale === 'ar' ? 'عدد العملاء:' : 'Customers Used:'}</span>
              <span class="info-value">{offer.current_total_uses || 0}</span>
            </div>
            
            <!-- Actions: Edit, Status Toggle, Delete -->
            <div class="offer-actions">
              <button class="action-btn btn-edit" on:click={() => editOffer(offer.id)} title={texts.edit}>
                ✏️ {locale === 'ar' ? 'تعديل' : 'Edit'}
              </button>
              <button 
                class="action-btn btn-status" 
                on:click={() => toggleOfferStatus(offer.id, offer.is_active)} 
                title={offer.is_active ? (locale === 'ar' ? 'إيقاف' : 'Deactivate') : (locale === 'ar' ? 'تفعيل' : 'Activate')}
              >
                {offer.is_active ? '⏸️' : '▶️'} 
                {offer.is_active ? (locale === 'ar' ? 'إيقاف' : 'Pause') : (locale === 'ar' ? 'تفعيل' : 'Activate')}
              </button>
              <button class="action-btn btn-delete danger" on:click={() => deleteOffer(offer.id)} title={texts.delete}>
                🗑️ {locale === 'ar' ? 'حذف' : 'Delete'}
              </button>
            </div>
          {:else}
            <!-- Other Offer Types - Original Layout -->
            <!-- Type Badge -->
            <div class="offer-type-badge" style="background: {typeBadge.color};">
              {typeBadge.icon} {typeBadge.label}
            </div>
            
            <!-- Header -->
            <div class="offer-header">
              <h3 class="offer-name">{locale === 'ar' ? offer.name_ar : offer.name_en}</h3>
              <div class="status-badge" style="color: {statusBadge.color};">
                {statusBadge.icon} {statusBadge.label}
              </div>
            </div>
            
            <!-- Branch & Service Info -->
            <div class="offer-meta">
              <span class="meta-badge">
                {offer.branch_id ? '🏢' : '🌍'} {getBranchName(offer.branch_id)}
              </span>
              <span class="meta-badge">
                {serviceBadge.icon} {serviceBadge.label}
              </span>
            </div>
            
            <!-- Discount Info -->
            <div class="offer-discount">
              {#if offer.tierCount > 0}
                <!-- Tiered discount display -->
                <div class="tiered-discount">
                  <span class="tier-badge">
                    🎯 {offer.tierCount} {locale === 'ar' ? 'مستويات' : 'Tiers'}
                  </span>
                  <span class="tier-range">
                    {#if offer.tiers.length > 0}
                      {@const minTier = offer.tiers[0]}
                      {@const maxTier = offer.tiers[offer.tiers.length - 1]}
                      {minTier.discount_type === 'percentage'
                        ? `${minTier.discount_value}% - ${maxTier.discount_value}%`
                        : `${minTier.discount_value} - ${maxTier.discount_value} ${texts.sar}`}
                      {locale === 'ar' ? 'خصم' : 'OFF'}
                    {/if}
                  </span>
                </div>
              {:else if offer.discount_type === 'percentage'}
                <span class="discount-value">{offer.discount_value}%</span>
                <span class="discount-label">{locale === 'ar' ? 'خصم' : 'OFF'}</span>
              {:else if offer.discount_type === 'fixed'}
                <span class="discount-value">{offer.discount_value} {texts.sar}</span>
                <span class="discount-label">{locale === 'ar' ? 'خصم' : 'OFF'}</span>
              {:else}
                <span class="discount-value">{offer.discount_value}</span>
                <span class="discount-label">{locale === 'ar' ? 'خصم' : 'OFF'}</span>
              {/if}
            </div>
            
            <!-- Date Range -->
            <div class="offer-dates">
              <div class="date-item">
                <span class="date-label">{locale === 'ar' ? 'يبدأ:' : 'Start:'}</span>
                <span class="date-value">📅 {formatDate(offer.start_date)}</span>
              </div>
              <div class="date-item">
                <span class="date-label">{locale === 'ar' ? 'ينتهي:' : 'End:'}</span>
                <span class="date-value">📅 {formatDate(offer.end_date)}</span>
              </div>
            </div>
            
            <!-- Stats -->
            <div class="offer-stats">
              <div class="stat-item">
                <span class="stat-number">{offer.current_total_uses || 0}</span>
                <span class="stat-text">{texts.usedTimes}</span>
              </div>
            </div>
            
            <!-- Applicable To -->
            <div class="offer-applicable">
              {texts.applicableTo}: 
              {#if offer.type === 'product' || offer.type === 'bogo'}
                {offer.productCount > 0 ? `${offer.productCount} ${texts.products}` : texts.allProducts}
              {:else if offer.type === 'cart'}
                {#if offer.tierCount > 0}
                  🎯 {offer.tierCount} {locale === 'ar' ? (offer.tierCount === 1 ? 'مستوى' : 'مستويات') : (offer.tierCount === 1 ? 'Tier' : 'Tiers')}
                  {#if offer.tiers && offer.tiers.length > 0}
                    {@const minTier = offer.tiers.reduce((min, t) => t.discount_value < min.discount_value ? t : min, offer.tiers[0])}
                    {@const maxTier = offer.tiers.reduce((max, t) => t.discount_value > max.discount_value ? t : max, offer.tiers[0])}
                    <span class="tier-range">
                      ({minTier.discount_type === 'percentage' ? `${minTier.discount_value}%` : `${minTier.discount_value} ${locale === 'ar' ? 'ريال' : 'SAR'}`}
                      - 
                      {maxTier.discount_type === 'percentage' ? `${maxTier.discount_value}%` : `${maxTier.discount_value} ${locale === 'ar' ? 'ريال' : 'SAR'}`}
                      {locale === 'ar' ? 'خصم' : 'OFF'})
                    </span>
                  {/if}
                {:else}
                  {locale === 'ar' ? 'السلة بالكامل' : 'Entire Cart'}
                {/if}
              {/if}
            </div>
            
            <!-- Actions -->
            <div class="offer-actions">
              <button class="action-btn" on:click={() => editOffer(offer.id)} title={texts.edit}>
                ✏️
              </button>
              <button class="action-btn" on:click={() => viewAnalytics(offer.id)} title={texts.analytics}>
                📊
              </button>
              <button class="action-btn danger" on:click={() => deleteOffer(offer.id)} title={texts.delete}>
                🗑️
              </button>
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .offer-management {
    padding: 1.5rem;
    height: 100%;
    overflow-y: auto;
    background: #f9fafb;
  }
  
  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
    gap: 1rem;
  }
  
  .title {
    font-size: 1.75rem;
    font-weight: 700;
    color: #1f2937;
    margin: 0;
  }
  
  .create-buttons {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
  }
  
  .btn-refresh {
    border: 2px solid #3b82f6;
    background: white;
    color: #3b82f6;
    padding: 0.625rem 1.25rem;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .btn-refresh:hover {
    background: #3b82f6;
    color: white;
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.3);
  }
  
  .btn-refresh:active {
    transform: scale(0.95);
  }
  
  .btn-create {
    border: none;
    padding: 0.625rem 1.25rem;
    border-radius: 8px;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: white;
  }
  
  .btn-create:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
  }
  
  .btn-percentage {
    background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
  }
  
  .btn-percentage:hover {
    background: linear-gradient(135deg, #16a34a 0%, #15803d 100%);
  }
  
  .btn-special-price {
    background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
  }
  
  .btn-special-price:hover {
    background: linear-gradient(135deg, #d97706 0%, #b45309 100%);
  }
  
  .btn-bogo {
    background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  }
  
  .btn-bogo:hover {
    background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
  }
  
  .btn-bundle {
    background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
  }
  
  .btn-bundle:hover {
    background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
  }
  
  .btn-cart {
    background: linear-gradient(135deg, #eab308 0%, #ca8a04 100%);
  }
  
  .btn-cart:hover {
    background: linear-gradient(135deg, #ca8a04 0%, #a16207 100%);
  }
  
  /* Stats Bar */
  .stats-bar {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 1rem;
    margin-bottom: 1.5rem;
  }
  
  .stat-card {
    background: white;
    border-radius: 12px;
    padding: 1.25rem;
    display: flex;
    align-items: center;
    gap: 1rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    transition: all 0.2s ease;
  }
  
  .stat-card:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    transform: translateY(-2px);
  }
  
  .stat-icon {
    width: 48px;
    height: 48px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.5rem;
  }
  
  .stat-content {
    flex: 1;
  }
  
  .stat-label {
    font-size: 0.85rem;
    color: #6b7280;
    margin-bottom: 0.25rem;
  }
  
  .stat-value {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
  }
  
  /* Filters */
  .filters {
    display: flex;
    gap: 1rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
  }
  
  .search-box {
    flex: 1;
    min-width: 250px;
    position: relative;
  }
  
  .search-icon {
    position: absolute;
    left: 1rem;
    top: 50%;
    transform: translateY(-50%);
    font-size: 1.1rem;
    opacity: 0.5;
  }
  
  .search-input {
    width: 100%;
    padding: 0.75rem 1rem 0.75rem 2.75rem;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    font-size: 0.95rem;
    transition: all 0.2s ease;
  }
  
  .search-input:focus {
    outline: none;
    border-color: #4F46E5;
    box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
  }
  
  .filter-select {
    padding: 0.75rem 1rem;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    font-size: 0.95rem;
    background: white;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  
  .filter-select:focus {
    outline: none;
    border-color: #4F46E5;
    box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
  }
  
  /* Offers Grid */
  .offers-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 1.25rem;
  }
  
  .offer-card {
    background: white;
    border-radius: 12px;
    padding: 1.5rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    transition: all 0.2s ease;
    position: relative;
  }
  
  .offer-card:hover {
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15);
    transform: translateY(-4px);
  }
  
  .offer-type-badge {
    display: inline-block;
    padding: 0.35rem 0.75rem;
    border-radius: 20px;
    font-size: 0.8rem;
    font-weight: 600;
    color: white;
    margin-bottom: 0.75rem;
  }
  
  .offer-header {
    margin-bottom: 0.5rem;
  }
  
  .offer-name {
    font-size: 1.2rem;
    font-weight: 700;
    color: #1f2937;
    margin: 0 0 0.5rem 0;
  }
  
  .status-badge {
    font-size: 0.85rem;
    font-weight: 600;
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
  }
  
  .offer-meta {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
    margin: 0.75rem 0;
  }
  
  .meta-badge {
    font-size: 0.75rem;
    padding: 0.25rem 0.6rem;
    background: #f3f4f6;
    border-radius: 12px;
    color: #4b5563;
    font-weight: 500;
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
  }
  
  .offer-discount {
    background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
    border-radius: 8px;
    padding: 0.75rem;
    margin: 1rem 0;
    text-align: center;
  }
  
  .discount-value {
    font-size: 1.75rem;
    font-weight: 800;
    color: #4F46E5;
    display: block;
  }
  
  .discount-label {
    font-size: 0.9rem;
    color: #6b7280;
    text-transform: uppercase;
    font-weight: 600;
  }
  
  /* Tiered Discount Styles */
  .tiered-discount {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  
  .tier-badge {
    font-size: 0.85rem;
    font-weight: 600;
    color: #4F46E5;
    background: #EEF2FF;
    padding: 0.25rem 0.75rem;
    border-radius: 12px;
    display: inline-block;
    width: fit-content;
    margin: 0 auto;
  }
  
  .tier-range {
    font-size: 1.4rem;
    font-weight: 700;
    color: #4F46E5;
  }
  
  /* Bundle List Styles */
  .bundle-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  
  .bundle-item {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    padding: 0.5rem 0.75rem;
    text-align: left;
  }
  
  .bundle-name {
    font-size: 0.9rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 0.25rem;
  }
  
  .bundle-price {
    font-size: 1.2rem;
    font-weight: 700;
    color: #4F46E5;
  }
  
  .bundle-products-count {
    font-size: 0.75rem;
    color: #6b7280;
    margin-top: 0.25rem;
  }
  
  .offer-dates {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
    font-size: 0.85rem;
    color: #6b7280;
    margin-bottom: 1rem;
    padding: 0.5rem 0;
    border-bottom: 1px solid #f3f4f6;
  }
  
  .date-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  
  .date-label {
    font-weight: 600;
    color: #374151;
  }
  
  .date-value {
    color: #6b7280;
  }
  
  .offer-stats {
    display: flex;
    align-items: center;
    justify-content: space-around;
    margin: 1rem 0;
    padding: 0.75rem;
    background: #f9fafb;
    border-radius: 8px;
  }
  
  .stat-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
  }
  
  .stat-number {
    font-size: 1.1rem;
    font-weight: 700;
    color: #1f2937;
  }
  
  .stat-text {
    font-size: 0.75rem;
    color: #6b7280;
  }
  
  .stat-divider {
    color: #e5e7eb;
    font-size: 1.2rem;
  }
  
  .offer-applicable {
    font-size: 0.85rem;
    color: #6b7280;
    margin: 1rem 0;
    padding: 0.5rem 0;
    border-top: 1px solid #f3f4f6;
  }
  
  /* Bundle Card Specific Styles */
  .offer-status-row {
    margin: 1rem 0 0.75rem 0;
    text-align: center;
  }
  
  .offer-info-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem;
    background: #f9fafb;
    border-radius: 8px;
    margin: 0.5rem 0;
  }
  
  .info-label {
    font-size: 0.9rem;
    color: #6b7280;
    font-weight: 500;
  }
  
  .info-value {
    font-size: 1.1rem;
    color: #1f2937;
    font-weight: 700;
  }
  
  .offer-actions {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
    margin-top: 1rem;
  }
  
  .action-btn {
    flex: 1;
    min-width: 40px;
    padding: 0.5rem;
    border: 1px solid #e5e7eb;
    background: white;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-size: 1.1rem;
  }
  
  .action-btn:hover {
    background: #f3f4f6;
    border-color: #d1d5db;
    transform: scale(1.05);
  }
  
  /* Bundle Card Action Buttons */
  .action-btn.btn-edit {
    background: #EEF2FF;
    color: #4F46E5;
    border-color: #C7D2FE;
    font-size: 0.9rem;
    font-weight: 600;
  }
  
  .action-btn.btn-edit:hover {
    background: #C7D2FE;
    border-color: #A5B4FC;
  }
  
  .action-btn.btn-status {
    background: #F0FDF4;
    color: #16A34A;
    border-color: #BBF7D0;
    font-size: 0.9rem;
    font-weight: 600;
  }
  
  .action-btn.btn-status:hover {
    background: #BBF7D0;
    border-color: #86EFAC;
  }
  
  .action-btn.btn-delete {
    background: #FEF2F2;
    color: #DC2626;
    border-color: #FECACA;
    font-size: 0.9rem;
    font-weight: 600;
  }
  
  .action-btn.btn-delete:hover {
    background: #FEE2E2;
    border-color: #FCA5A5;
  }
  
  .action-btn.danger:hover {
    background: #fee2e2;
    border-color: #fecaca;
    color: #dc2626;
  }
  
  /* Empty State */
  .empty-state {
    text-align: center;
    padding: 4rem 2rem;
    background: white;
    border-radius: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }
  
  .empty-icon {
    font-size: 4rem;
    margin-bottom: 1rem;
  }
  
  .empty-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
    margin: 0 0 0.5rem 0;
  }
  
  .empty-desc {
    font-size: 1rem;
    color: #6b7280;
    margin: 0 0 2rem 0;
  }
  
  /* Loading */
  .loading {
    text-align: center;
    padding: 3rem;
    font-size: 1.1rem;
    color: #6b7280;
  }
  
  /* RTL Adjustments */
  [dir="rtl"] .search-icon {
    left: auto;
    right: 1rem;
  }
  
  [dir="rtl"] .search-input {
    padding: 0.75rem 2.75rem 0.75rem 1rem;
  }
  
  [dir="rtl"] .offer-header {
    padding-right: 0;
    padding-left: 0;
  }
  
  [dir="rtl"] .offer-type-badge {
    /* No changes needed - not absolutely positioned anymore */
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
    padding: 1rem;
  }

  .modal-content {
    background: white;
    border-radius: 16px;
    max-width: 1000px;
    width: 100%;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  }
  
  /* Responsive Design */
  @media (max-width: 768px) {
    .create-buttons {
      width: 100%;
    }
    
    .btn-create {
      flex: 1;
      min-width: 140px;
      justify-content: center;
      font-size: 0.8rem;
      padding: 0.5rem 0.75rem;
    }
    
    .header {
      flex-direction: column;
      align-items: stretch;
    }
    
    .title {
      text-align: center;
      margin-bottom: 0.5rem;
    }
  }
</style>
