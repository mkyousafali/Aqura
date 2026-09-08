<script lang="ts">
  import { onMount } from "svelte";
  import { browser } from '$app/environment';
  import { supabase } from "$lib/utils/supabase";
  import { currentUser } from "$lib/utils/persistentAuth";
  import { notificationManagement } from '$lib/utils/notificationManagement';
  import { t } from "$lib/i18n";
  import { openWindow } from '$lib/utils/windowManagerUtils';
  import CustomerAccountRecoveryManager from '$lib/components/desktop-interface/admin-customer-app/CustomerAccountRecoveryManager.svelte';
  import LocationMapDisplay from '$lib/components/desktop-interface/admin-customer-app/LocationMapDisplay.svelte';

  interface Customer {
    id: string;
    name: string;
    access_code: string;
    whatsapp_number: string;
    registration_status: "pending" | "approved" | "rejected" | "suspended";
    registration_notes: string;
    approved_by: string;
    approved_at: string;
    access_code_generated_at: string;
    last_login_at: string;
    created_at: string;
    updated_at: string;
    location1_name?: string;
    location1_url?: string;
    location1_lat?: number;
    location1_lng?: number;
    location2_name?: string;
    location2_url?: string;
    location2_lat?: number;
    location2_lng?: number;
    location3_name?: string;
    location3_url?: string;
    location3_lat?: number;
    location3_lng?: number;
    is_deleted?: boolean;
  }

  let customers: Customer[] = [];
  let loading = true;
  let searchTerm = "";
  let statusFilter = "all";
  let selectedCustomer: Customer | null = null;
  let showApprovalModal = false;
  let approvalNotes = "";
  let actionType: "approve" | "reject" = "approve";
  let generatedAccessCode = "";
  let showAccessCodeInput = false;
  let showWhatsAppButton = false;
  let isGeneratingCode = false;
  let isSavingApproval = false;
  // Import customers state
  let showImportModal = false;
  let importFile: File | null = null;
  let importPhoneNumbers: string[] = [];
  let importing = false;
  let importResult: { success: boolean; total: number; inserted: number; skipped: number; message: string } | null = null;
  let preRegisteredCount = 0;
  // Location management state
  let showLocationModal = false;
  let locationCustomer: Customer | null = null;
  let loc1_name = '';
  let loc1_url = '';
  let loc1_lat: number | null = null;
  let loc1_lng: number | null = null;
  let loc2_name = '';
  let loc2_url = '';
  let loc2_lat: number | null = null;
  let loc2_lng: number | null = null;
  let loc3_name = '';
  let loc3_url = '';
  let loc3_lat: number | null = null;
  let loc3_lng: number | null = null;
  let savingLocations = false;
  let currentEditingLocation = 1; // Which location is being edited in the map
  
  // Current user location for distance calculation
  let userLat: number = 24.7136; // Initialize with Riyadh center as default
  let userLng: number = 46.6753;
  
  // Statistics
  let pendingRegistrations = 0;
  let pendingRecoveryRequests = 0;

  // Pagination (server-side)
  let currentPage = 1;
  let pageSize = 50;
  let pageSizeOptions = [25, 50, 100, 200];
  let totalCustomers = 0;
  let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

  onMount(() => {
    loadCustomers();
    loadStatistics();
    getUserLocation();
  });

  // Get user's current location
  function getUserLocation() {
    if (browser && navigator.geolocation) {
      console.log('📍 [CustomerMaster] Requesting user location...');
      navigator.geolocation.getCurrentPosition(
        (position) => {
          userLat = position.coords.latitude;
          userLng = position.coords.longitude;
          console.log('✅ [CustomerMaster] Got user location:', userLat, userLng);
        },
        (error) => {
          console.warn('⚠️ [CustomerMaster] Could not get user location:', error.message);
          console.log('📍 [CustomerMaster] Using default location (Riyadh center)');
        },
        {
          timeout: 5000,
          enableHighAccuracy: false,
          maximumAge: 300000
        }
      );
    } else {
      console.log('📍 [CustomerMaster] Geolocation not available, using Riyadh center');
    }
  }

  async function loadCustomers() {
    try {
      loading = true;
      const offset = (currentPage - 1) * pageSize;
      console.log(`🔍 [CustomerMaster] Loading page ${currentPage} (offset=${offset}, limit=${pageSize}, search="${searchTerm}", status="${statusFilter}")`);
      
      const { data, error } = await supabase.rpc("get_customers_list_paginated", {
        p_search: searchTerm.trim(),
        p_status: statusFilter,
        p_limit: pageSize,
        p_offset: offset
      });

      if (error) {
        console.error("❌ [CustomerMaster] Error loading customers:", error);
        alert("Error loading customers");
        return;
      }

      const result = data || { data: [], total: 0 };
      customers = result.data || [];
      totalCustomers = result.total || 0;
      console.log(`✅ [CustomerMaster] Loaded ${customers.length} of ${totalCustomers} customers`);
    } catch (error) {
      console.error("❌ [CustomerMaster] Error loading customers:", error);
      alert("Error loading customers");
    } finally {
      loading = false;
    }
  }

  function openLocationModal(customer: Customer) {
    locationCustomer = customer;
    loc1_name = customer.location1_name || '';
    loc1_url = customer.location1_url || '';
    loc1_lat = customer.location1_lat ? Number(customer.location1_lat) : null;
    loc1_lng = customer.location1_lng ? Number(customer.location1_lng) : null;
    loc2_name = customer.location2_name || '';
    loc2_url = customer.location2_url || '';
    loc2_lat = customer.location2_lat ? Number(customer.location2_lat) : null;
    loc2_lng = customer.location2_lng ? Number(customer.location2_lng) : null;
    loc3_name = customer.location3_name || '';
    loc3_url = customer.location3_url || '';
    loc3_lat = customer.location3_lat ? Number(customer.location3_lat) : null;
    loc3_lng = customer.location3_lng ? Number(customer.location3_lng) : null;
    currentEditingLocation = 1;
    showLocationModal = true;
    
    console.log('📍 [CustomerMaster] Opening location modal for:', customer.name);
    console.log('📍 Location 1:', { name: loc1_name, lat: loc1_lat, lng: loc1_lng, type: typeof loc1_lat });
    console.log('📍 Location 2:', { name: loc2_name, lat: loc2_lat, lng: loc2_lng });
    console.log('📍 Location 3:', { name: loc3_name, lat: loc3_lat, lng: loc3_lng });
  }

  function closeLocationModal() {
    showLocationModal = false;
    locationCustomer = null;
    savingLocations = false;
  }

  // Calculate distance between two coordinates using Haversine formula
  function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371; // Radius of the earth in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c; // Distance in km
    return distance;
  }

  // Get current user location and calculate distance
  function getDistanceToLocation(lat: number, lng: number): string {
    const distance = calculateDistance(userLat, userLng, lat, lng);
    return distance.toFixed(2) + ' km';
  }

  async function saveLocations() {
    if (!locationCustomer) return;
    try {
      savingLocations = true;
      const updates = {
        location1_name: loc1_name || null,
        location1_url: loc1_url || null,
        location1_lat: loc1_lat,
        location1_lng: loc1_lng,
        location2_name: loc2_name || null,
        location2_url: loc2_url || null,
        location2_lat: loc2_lat,
        location2_lng: loc2_lng,
        location3_name: loc3_name || null,
        location3_url: loc3_url || null,
        location3_lat: loc3_lat,
        location3_lng: loc3_lng,
      };
      const { error } = await supabase
        .from('customers')
        .update(updates)
        .eq('id', locationCustomer.id);
      if (error) {
        console.error('❌ [CustomerMaster] Location update error:', error);
        alert('Failed to save locations');
      } else {
        // Reflect changes locally
        Object.assign(locationCustomer, updates);
        customers = customers.map(c => c.id === locationCustomer.id ? { ...c, ...updates } : c);
        closeLocationModal();
      }
    } catch (e) {
      console.error('❌ [CustomerMaster] Exception saving locations:', e);
      alert('Unexpected error');
    } finally {
      savingLocations = false;
    }
  }

  function handleLocationSelect(locationNum: number, location: { name: string; lat: number; lng: number; url: string }) {
    if (locationNum === 1) {
      loc1_name = location.name;
      loc1_url = location.url;
      loc1_lat = location.lat;
      loc1_lng = location.lng;
    } else if (locationNum === 2) {
      loc2_name = location.name;
      loc2_url = location.url;
      loc2_lat = location.lat;
      loc2_lng = location.lng;
    } else if (locationNum === 3) {
      loc3_name = location.name;
      loc3_url = location.url;
      loc3_lat = location.lat;
      loc3_lng = location.lng;
    }
  }

  async function loadStatistics() {
    try {
      // Load pending registration count (uses count, doesn't fetch rows)
      const { count: pendingCount, error: regError } = await supabase
        .from("customers")
        .select("id", { count: "exact", head: true })
        .eq("registration_status", "pending");

      if (regError) {
        console.error("Error loading pending registrations:", regError);
      } else {
        pendingRegistrations = pendingCount || 0;
      }

      // Load unresolved account recovery count
      const { count: recoveryCount, error: recoveryError } = await supabase
        .from("customer_recovery_requests")
        .select("id", { count: "exact", head: true })
        .neq("verification_status", "processed");

      if (recoveryError) {
        console.error("Error loading recovery requests:", recoveryError);
      } else {
        pendingRecoveryRequests = recoveryCount || 0;
      }
    } catch (error) {
      console.error("Error loading statistics:", error);
    }
  }

  async function updateCustomerStatus(customerId: string, status: "approved" | "rejected", notes?: string, accessCode?: string) {
    try {
      const user = $currentUser;
      if (!user) {
        alert("Login required");
        return;
      }

      // Check if user has admin privileges
      if (!user.isAdmin && !user.isMasterAdmin) {
        console.error("❌ Access denied: User lacks admin privileges", {
          username: user.username,
          isAdmin: user.isAdmin,
          isMasterAdmin: user.isMasterAdmin
        });
        alert("Access denied. Admin privileges required to approve/reject customers.\n\nYour account does not have admin permissions. Please contact your system administrator.");
        return;
      }

      console.log("✅ Admin check passed:", {
        username: user.username,
        isAdmin: user.isAdmin,
        isMasterAdmin: user.isMasterAdmin
      });

      // First update the access code if provided (for approved customers)
      if (status === "approved" && accessCode) {
        const { error: codeError } = await supabase
          .from("customers")
          .update({ 
            access_code: accessCode,
            access_code_generated_at: new Date().toISOString()
          })
          .eq("id", customerId);

        if (codeError) {
          console.error("Error updating access code:", codeError);
          alert("Failed to update access code");
          return;
        }
      }

      // Then update the customer status
      const { data, error } = await supabase.rpc("approve_customer_account", {
        p_customer_id: customerId,
        p_status: status,
        p_notes: notes || "",
        p_approved_by: user.id,
      });

      if (error) {
        console.error("Error updating customer status:", error);
        alert("Update failed");
        return;
      }

      // Send notification through notification center
      await sendAdminNotification(customerId, status, notes || "", accessCode);
      
      // Reload customers list and statistics
      await loadCustomers();
      await loadStatistics();
      
    } catch (error) {
      console.error("Error updating customer status:", error);
      alert("Update failed");
    }
  }

  async function sendAdminNotification(customerId: string, status: string, notes: string, accessCode?: string) {
    try {
      const customer = customers.find(c => c.id === customerId);
      if (!customer) return;

      const isApproved = status === 'approved';
      
      // Send notification to all admins about the customer approval/rejection
      const adminNotificationData = {
        title: isApproved 
          ? `✅ Customer Approved: ${customer.name}`
          : `❌ Customer Rejected: ${customer.name}`,
        message: isApproved 
          ? `Customer "${customer.name}" has been approved. Access code: ${accessCode || 'Not generated'}. WhatsApp: ${customer.whatsapp_number}`
          : `Customer "${customer.name}" has been rejected. ${notes ? 'Reason: ' + notes : 'No reason provided.'}`,
        type: isApproved ? 'success' : 'warning',
        priority: 'normal',
        target_type: 'all_admins'
      };

      await notificationManagement.createNotification(
        adminNotificationData, 
        $currentUser?.username || 'admin'
      );

      console.log("✅ Admin notification sent successfully");
    } catch (error) {
      console.error("❌ Failed to send admin notification:", error);
      // Don't block the approval process if notification fails
    }
  }

  function shareToWhatsApp() {
    if (!selectedCustomer || !generatedAccessCode) return;

    const loginUrl = window.location.origin + '/login';
    const message = `🎉 *أهلاً بك في بوابة عملاء أكورا!*

عزيزي ${selectedCustomer.name || 'العميل'},

تم *قبول* وتفعيل حساب العميل الخاص بك!

*بيانات تسجيل الدخول:*
👤 اسم العميل: ${selectedCustomer.name}
🔑 رمز الدخول: ${generatedAccessCode}
🌐 البوابة: ${loginUrl}

*كيفية تسجيل الدخول:*
1. قم بزيارة بوابة عملاء أكورا
2. اضغط على "دخول العملاء"
3. أدخل رمز الدخول الخاص بك
4. ادخل إلى لوحة تحكم العميل

أهلاً وسهلاً بك! 🚀

*هذه الرسالة من نظام إدارة أكورا*

---

🎉 *Welcome to Aqura Customer Portal!*

Dear ${selectedCustomer.name || 'Customer'},

Your customer account has been *APPROVED* and activated! 

*Your Login Credentials:*
👤 Customer Name: ${selectedCustomer.name}
🔑 Access Code: ${generatedAccessCode}
🌐 Portal: ${loginUrl}

*How to Login:*
1. Visit the Aqura Customer Portal
2. Click "Customer Login"
3. Enter your access code
4. Access your customer dashboard

Welcome aboard! 🚀

*This message is from Aqura Management System*`;

    // Clean phone number (remove any formatting)
    const phoneNumber = selectedCustomer.whatsapp_number.replace(/[^\d+]/g, '');
    
    // Create WhatsApp URL
    const whatsappUrl = `https://web.whatsapp.com/send?phone=${phoneNumber}&text=${encodeURIComponent(message)}`;
    
    // Open WhatsApp Web
    window.open(whatsappUrl, '_blank');
    
    // Close modal after sharing
    setTimeout(() => {
      closeApprovalModal();
    }, 1000);
  }

  function openApprovalModal(customer: Customer, type: "approve" | "reject") {
    selectedCustomer = customer;
    actionType = type;
    approvalNotes = "";
    generatedAccessCode = "";
    showAccessCodeInput = type === "approve";
    showWhatsAppButton = false;
    showApprovalModal = true;
  }

  function closeApprovalModal() {
    showApprovalModal = false;
    selectedCustomer = null;
    approvalNotes = "";
    generatedAccessCode = "";
    showAccessCodeInput = false;
    showWhatsAppButton = false;
  }

  function generateAccessCode() {
    isGeneratingCode = true;
    // Generate 6-digit access code
    generatedAccessCode = Math.floor(100000 + Math.random() * 900000).toString();
    isGeneratingCode = false;
  }

  async function saveApproval() {
    if (!selectedCustomer) return;
    
    isSavingApproval = true;
    try {
      const finalStatus = actionType === "approve" ? "approved" : "rejected";
      
      // For approval, we need the access code
      if (actionType === "approve" && !generatedAccessCode) {
        alert("Please generate an access code first");
        return;
      }

      await updateCustomerStatus(selectedCustomer.id, finalStatus, approvalNotes, generatedAccessCode);
      
      // After successful save, show WhatsApp button for approved customers
      if (actionType === "approve" && selectedCustomer.whatsapp_number && selectedCustomer.whatsapp_number !== 'Not Provided') {
        showWhatsAppButton = true;
      }
      
    } catch (error) {
      console.error("Error saving approval:", error);
      alert("Failed to save approval");
    } finally {
      isSavingApproval = false;
    }
  }

  // Server-side pagination: totalPages computed from server total
  $: totalPages = Math.max(1, Math.ceil(totalCustomers / pageSize));

  // Ensure currentPage is valid
  $: if (currentPage > totalPages) {
    currentPage = totalPages;
  }

  function goToPage(page: number) {
    if (page >= 1 && page <= totalPages && page !== currentPage) {
      currentPage = page;
      loadCustomers();
    }
  }

  function onPageSizeChange() {
    currentPage = 1;
    loadCustomers();
  }

  function onStatusFilterChange() {
    currentPage = 1;
    loadCustomers();
  }

  function onSearchInput() {
    if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
    searchDebounceTimer = setTimeout(() => {
      currentPage = 1;
      loadCustomers();
    }, 400);
  }

  function getVisiblePages(current: number, total: number): (number | '...')[] {
    if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
    const pages: (number | '...')[] = [];
    if (current <= 4) {
      for (let i = 1; i <= 5; i++) pages.push(i);
      pages.push('...', total);
    } else if (current >= total - 3) {
      pages.push(1, '...');
      for (let i = total - 4; i <= total; i++) pages.push(i);
    } else {
      pages.push(1, '...', current - 1, current, current + 1, '...', total);
    }
    return pages;
  }

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString();
  }

  function getStatusColor(status: string) {
    switch (status) {
      case "approved": return "text-green-600 bg-green-100";
      case "rejected": return "text-red-600 bg-red-100";
      case "pending": return "text-yellow-600 bg-yellow-100";
      case "suspended": return "text-orange-600 bg-orange-100";
      case "pre_registered": return "text-indigo-600 bg-indigo-100";
      default: return "text-gray-600 bg-gray-100";
    }
  }

  // --- Import Customers ---
  function openImportModal() {
    showImportModal = true;
    importFile = null;
    importPhoneNumbers = [];
    importResult = null;
  }

  function closeImportModal() {
    showImportModal = false;
    importFile = null;
    importPhoneNumbers = [];
    importResult = null;
  }

  async function handleFileSelect(e: Event) {
    const input = e.target as HTMLInputElement;
    if (!input.files?.length) return;
    importFile = input.files[0];
    importResult = null;

    // Read file as text (CSV / TXT / Excel-exported CSV)
    const text = await importFile.text();
    const lines = text.split(/[\r\n]+/).filter(l => l.trim());
    const phones: string[] = [];
    for (const line of lines) {
      // Split by comma, tab, semicolon to handle CSV variants
      const parts = line.split(/[,;\t]/);
      for (const part of parts) {
        const cleaned = part.replace(/[^0-9+]/g, '').trim();
        if (cleaned.length >= 9) {
          phones.push(cleaned);
        }
      }
    }
    // Deduplicate
    importPhoneNumbers = [...new Set(phones)];
  }

  async function importCustomers() {
    if (importPhoneNumbers.length === 0) return;
    importing = true;
    importResult = null;
    try {
      const { data, error } = await supabase.rpc('bulk_import_customers', {
        p_phone_numbers: importPhoneNumbers
      });
      if (error) throw error;
      importResult = data;
      // Reload customers list
      await loadCustomers();
      await loadStatistics();
    } catch (e: any) {
      importResult = { success: false, total: importPhoneNumbers.length, inserted: 0, skipped: 0, message: 'Error: ' + e.message };
    } finally {
      importing = false;
    }
  }

  function openAccountRecoveryManager() {
    const windowId = `account-recovery-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const instanceNumber = Math.floor(Math.random() * 1000) + 1;
    
    openWindow({
      id: windowId,
      title: `Customer Account Recovery Manager #${instanceNumber}`,
      component: CustomerAccountRecoveryManager,
      componentName: 'CustomerAccountRecoveryManager',
      icon: '🔐',
      size: { width: 1400, height: 900 },
      position: { 
        x: 50 + (Math.random() * 100), 
        y: 50 + (Math.random() * 100) 
      },
      resizable: true,
      minimizable: true,
      maximizable: true,
      closable: true
    });
  }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
    <!-- Header/Navigation -->
    <div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div>
            <h1 class="text-lg font-black text-slate-800 uppercase tracking-wide">{t('admin.customerManagement') || 'Customer Management'}</h1>
            <p class="text-xs text-slate-500 mt-0.5">{t('admin.customerManagementDesc') || 'Manage customer registrations and access approvals'}</p>
        </div>
        <div class="flex gap-2">
            <button 
                class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-bold uppercase tracking-wide transition-all duration-300 rounded-xl bg-emerald-600 text-white shadow-lg shadow-emerald-200 hover:bg-emerald-700 hover:shadow-xl hover:scale-[1.02] overflow-hidden"
                on:click={openImportModal}
                title="Import customers from Excel/CSV"
            >
                <span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">📥</span>
                <span class="relative z-10">Import Customers</span>
            </button>
            <button 
                class="group relative flex items-center gap-2 px-5 py-2.5 text-xs font-bold uppercase tracking-wide transition-all duration-300 rounded-xl bg-blue-600 text-white shadow-lg shadow-blue-200 hover:bg-blue-700 hover:shadow-xl hover:scale-[1.02] overflow-hidden"
                on:click={openAccountRecoveryManager}
                title="{t('admin.accountRecovery') || 'Open Account Recovery Manager'}"
            >
                <span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">🔐</span>
                <span class="relative z-10">{t('admin.accountRecovery') || 'Account Recovery'}</span>
            </button>
        </div>
    </div>

    <!-- Main Content Area -->
    <div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
        <!-- Futuristic background decorative elements -->
        <div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
        <div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

        <div class="relative max-w-[99%] mx-auto h-full flex flex-col">
            <!-- Status Cards -->
            <div class="flex gap-4 mb-4">
                <div class="flex-1 flex items-center gap-4 p-5 bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] hover:shadow-lg transition-all duration-300 hover:-translate-y-0.5">
                    <span class="text-4xl">👥</span>
                    <div>
                        <div class="text-3xl font-black text-amber-500 leading-none">{pendingRegistrations}</div>
                        <div class="text-xs font-semibold text-slate-500 mt-1 uppercase tracking-wide">{t('admin.pendingRegistrationRequests')}</div>
                    </div>
                </div>
                <div class="flex-1 flex items-center gap-4 p-5 bg-white/40 backdrop-blur-xl rounded-2xl border border-white shadow-[0_8px_32px_-8px_rgba(0,0,0,0.08)] hover:shadow-lg transition-all duration-300 hover:-translate-y-0.5">
                    <span class="text-4xl">🔓</span>
                    <div>
                        <div class="text-3xl font-black text-red-500 leading-none">{pendingRecoveryRequests}</div>
                        <div class="text-xs font-semibold text-slate-500 mt-1 uppercase tracking-wide">{t('admin.unresolvedAccountRecovery')}</div>
                    </div>
                </div>
            </div>

            <!-- Filter Controls -->
            <div class="mb-4 flex gap-3">
                <div class="flex-1">
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{t('admin.searchPlaceholder') || 'Search'}</label>
                    <input
                        type="text"
                        placeholder="{t('admin.searchPlaceholder') || 'Search...'}"
                        bind:value={searchTerm}
                        on:input={onSearchInput}
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                    />
                </div>
                <div class="flex-1">
                    <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{t('admin.status') || 'Status'}</label>
                    <select 
                        bind:value={statusFilter} 
                        on:change={onStatusFilterChange}
                        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
                        style="color: #000000 !important; background-color: #ffffff !important;"
                    >
                        <option value="all" style="color: #000000 !important; background-color: #ffffff !important;">{t('admin.allStatuses') || 'All Statuses'}</option>
                        <option value="pending" style="color: #000000 !important; background-color: #ffffff !important;">{t('admin.pending') || 'Pending'}</option>
                        <option value="approved" style="color: #000000 !important; background-color: #ffffff !important;">{t('admin.approved') || 'Approved'}</option>
                        <option value="rejected" style="color: #000000 !important; background-color: #ffffff !important;">{t('admin.rejected') || 'Rejected'}</option>
                        <option value="suspended" style="color: #000000 !important; background-color: #ffffff !important;">{t('admin.suspended') || 'Suspended'}</option>
                        <option value="pre_registered" style="color: #000000 !important; background-color: #ffffff !important;">Pre-Registered (Imported)</option>
                    </select>
                </div>
            </div>

            {#if loading}
                <div class="flex items-center justify-center h-full">
                    <div class="text-center">
                        <div class="animate-spin inline-block">
                            <div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
                        </div>
                        <p class="mt-4 text-slate-600 font-semibold">{t('admin.loading') || 'Loading...'}</p>
                    </div>
                </div>
            {:else if customers.length === 0}
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
                    <div class="text-5xl mb-4">📭</div>
                    <p class="text-slate-600 font-semibold">{t('admin.noDataFound') || 'No data found'}</p>
                </div>
            {:else}
                <!-- Customer Table Container -->
                <div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
                    <!-- Table Wrapper with scroll -->
                    <div class="overflow-auto flex-1">
                        <table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
                            <thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
                                <tr>
                                    <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{t('admin.customerName') || 'Customer Name'}</th>
                                    <th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{t('admin.whatsappNumber') || 'WhatsApp Number'}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{t('admin.status') || 'Status'}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{t('admin.registrationDate') || 'Registration Date'}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{t('admin.lastLogin') || 'Last Login'}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{t('admin.locations') || 'Locations'}</th>
                                    <th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{t('admin.actions') || 'Actions'}</th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-slate-200">
                                {#each customers as customer, index (customer.id)}
                                    <tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
                                        <td class="px-4 py-3 text-sm text-slate-700 font-medium">{customer.name || 'Unknown Customer'}</td>
                                        <td class="px-4 py-3 text-sm text-slate-700 font-mono">{customer.whatsapp_number || 'Not Provided'}</td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            <span class="inline-block px-3 py-1 rounded-full text-[10px] font-black uppercase tracking-wide {getStatusColor(customer.registration_status)}">
                                                {customer.registration_status === "pending" ? t('admin.pending') || "Pending" : 
                                                 customer.registration_status === "approved" ? t('admin.approved') || "Approved" : 
                                                 customer.registration_status === "rejected" ? t('admin.rejected') || "Rejected" : 
                                                 customer.registration_status === "suspended" ? t('admin.suspended') || "Suspended" : 
                                                 customer.registration_status}
                                            </span>
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center text-slate-600">{formatDate(customer.created_at)}</td>
                                        <td class="px-4 py-3 text-sm text-center text-slate-600">{customer.last_login_at ? formatDate(customer.last_login_at) : t('admin.never') || 'Never'}</td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            <button 
                                                class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-blue-600 text-white text-xs font-bold hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
                                                on:click={() => openLocationModal(customer)}
                                            >
                                                📍 {t('admin.viewLocations') || 'View'}
                                            </button>
                                        </td>
                                        <td class="px-4 py-3 text-sm text-center">
                                            <div class="flex items-center justify-center gap-2">
                                                {#if customer.registration_status === "pending"}
                                                    <button
                                                        class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
                                                        on:click={() => openApprovalModal(customer, "approve")}
                                                    >
                                                        ✅ {t('admin.approve') || 'Approve'}
                                                    </button>
                                                    <button
                                                        class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-red-600 text-white text-xs font-bold hover:bg-red-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105"
                                                        on:click={() => openApprovalModal(customer, "reject")}
                                                    >
                                                        ❌ {t('admin.reject') || 'Reject'}
                                                    </button>
                                                {:else}
                                                    <span class="text-xs text-slate-500 font-semibold">
                                                        {customer.registration_status === "approved" ? t('admin.approved') || "Approved" : 
                                                         customer.registration_status === "rejected" ? t('admin.rejected') || "Rejected" : 
                                                         customer.registration_status === "suspended" ? t('admin.suspended') || "Suspended" : 
                                                         customer.registration_status}
                                                    </span>
                                                    {#if customer.approved_at}
                                                        <small class="text-[10px] text-slate-400">{formatDate(customer.approved_at)}</small>
                                                    {/if}
                                                {/if}
                                            </div>
                                        </td>
                                    </tr>
                                {:else}
                                    <tr>
                                        <td colspan="7" class="px-4 py-12 text-center text-slate-500 italic">{t('admin.noDataFound') || 'No data found'}</td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    </div>

                    <!-- Pagination Controls -->
                    {#if totalCustomers > 0}
                        <div class="flex justify-between items-center px-6 py-3 bg-slate-800 border-t border-slate-700 rounded-b-[2.5rem]">
                            <div class="flex items-center gap-3 text-xs text-slate-400">
                                <span>{t('admin.showing') || 'Showing'} {(currentPage - 1) * pageSize + 1}-{Math.min(currentPage * pageSize, totalCustomers)} {t('admin.of') || 'of'} {totalCustomers} {t('admin.customers') || 'customers'}</span>
                                <select 
                                    bind:value={pageSize} 
                                    class="bg-slate-900 border border-slate-600 text-slate-300 px-2 py-1 rounded-md text-xs cursor-pointer hover:border-emerald-500 transition-colors"
                                    on:change={onPageSizeChange}
                                    style="color: #e2e8f0 !important; background-color: #0f172a !important;"
                                >
                                    {#each pageSizeOptions as size}
                                        <option value={size} style="color: #e2e8f0 !important; background-color: #0f172a !important;">{size} / {t('admin.page') || 'page'}</option>
                                    {/each}
                                </select>
                            </div>
                            <div class="flex items-center gap-1">
                                <button class="min-w-[2rem] h-8 flex items-center justify-center bg-slate-900 border border-slate-600 text-slate-300 rounded-md text-xs cursor-pointer transition-all hover:bg-slate-700 hover:border-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed px-1" disabled={currentPage === 1} on:click={() => goToPage(1)} title="First">«</button>
                                <button class="min-w-[2rem] h-8 flex items-center justify-center bg-slate-900 border border-slate-600 text-slate-300 rounded-md text-xs cursor-pointer transition-all hover:bg-slate-700 hover:border-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed px-1" disabled={currentPage === 1} on:click={() => goToPage(currentPage - 1)} title="Previous">‹</button>
                                {#each getVisiblePages(currentPage, totalPages) as page}
                                    {#if page === '...'}
                                        <span class="min-w-[1.5rem] text-center text-slate-500 text-xs">…</span>
                                    {:else}
                                        <button 
                                            class="min-w-[2rem] h-8 flex items-center justify-center border rounded-md text-xs cursor-pointer transition-all px-1 {page === currentPage ? 'bg-emerald-600 border-emerald-600 text-white font-bold' : 'bg-slate-900 border-slate-600 text-slate-300 hover:bg-slate-700 hover:border-emerald-500'}"
                                            on:click={() => goToPage(page)}
                                        >
                                            {page}
                                        </button>
                                    {/if}
                                {/each}
                                <button class="min-w-[2rem] h-8 flex items-center justify-center bg-slate-900 border border-slate-600 text-slate-300 rounded-md text-xs cursor-pointer transition-all hover:bg-slate-700 hover:border-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed px-1" disabled={currentPage === totalPages} on:click={() => goToPage(currentPage + 1)} title="Next">›</button>
                                <button class="min-w-[2rem] h-8 flex items-center justify-center bg-slate-900 border border-slate-600 text-slate-300 rounded-md text-xs cursor-pointer transition-all hover:bg-slate-700 hover:border-emerald-500 disabled:opacity-40 disabled:cursor-not-allowed px-1" disabled={currentPage === totalPages} on:click={() => goToPage(totalPages)} title="Last">»</button>
                            </div>
                        </div>
                    {/if}
                </div>
            {/if}
        </div>
    </div>
</div>

<!-- Approval Modal -->
{#if showApprovalModal && selectedCustomer}
  <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[1000]" on:click={closeApprovalModal} role="dialog" tabindex="-1">
    <div class="bg-white rounded-2xl max-w-[500px] w-[90vw] max-h-[90vh] overflow-y-auto shadow-[0_32px_64px_-16px_rgba(0,0,0,0.2)] relative z-[1001]" on:click|stopPropagation role="document" tabindex="-1">
      <div class="flex justify-between items-center px-6 py-4 border-b border-slate-200">
        <h3 class="text-base font-bold text-slate-800 m-0">
          {actionType === "approve" ? `✅ ${t('admin.approveCustomer') || 'Approve Customer'}` : `❌ ${t('admin.rejectCustomer') || 'Reject Customer'}`}
        </h3>
        <button class="w-8 h-8 flex items-center justify-center text-slate-400 hover:text-slate-700 text-xl bg-transparent border-none cursor-pointer rounded-lg hover:bg-slate-100 transition-colors" on:click={closeApprovalModal}>✕</button>
      </div>
      
      <div class="p-6">
        <div class="mb-4 p-4 bg-slate-50 rounded-xl border border-slate-200">
          <p class="my-1 text-sm text-slate-700"><strong class="text-slate-900">{t('admin.customerName') || 'Customer Name'}:</strong> {selectedCustomer.name || t('admin.unknownCustomer') || 'Unknown Customer'}</p>
          <p class="my-1 text-sm text-slate-700"><strong class="text-slate-900">{t('admin.whatsappNumber') || 'WhatsApp Number'}:</strong> {selectedCustomer.whatsapp_number || t('admin.notProvided') || 'Not Provided'}</p>
          <p class="my-1 text-sm text-slate-700"><strong class="text-slate-900">{t('admin.registrationDate') || 'Registration Date'}:</strong> {formatDate(selectedCustomer.created_at)}</p>
          {#if selectedCustomer.registration_notes}
            <p class="my-1 text-sm text-slate-700"><strong class="text-slate-900">{t('admin.registrationNotes') || 'Registration Notes'}:</strong> {selectedCustomer.registration_notes}</p>
          {/if}
        </div>

        {#if actionType === "approve" && showAccessCodeInput}
          <div class="my-4 p-4 bg-emerald-50/50 rounded-xl border border-emerald-200">
            <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="accessCode">{t('admin.accessCode') || 'Access Code'}:</label>
            <div class="flex gap-2 mt-2">
              <input
                id="accessCode"
                type="text"
                bind:value={generatedAccessCode}
                placeholder="{t('admin.accessCodePlaceholder') || 'Generate 6-digit access code'}"
                maxlength="6"
                readonly
                class="flex-1 px-4 py-2.5 border border-slate-200 rounded-xl font-mono text-lg text-center tracking-widest bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
              <button 
                class="px-4 py-2.5 bg-emerald-600 text-white border-none rounded-xl cursor-pointer font-bold text-sm hover:bg-emerald-700 transition-colors disabled:bg-slate-400 disabled:cursor-not-allowed"
                on:click={generateAccessCode}
                disabled={isGeneratingCode}
              >
                {#if isGeneratingCode}
                  {t('admin.generating') || 'Generating...'}
                {:else}
                  🎲 {t('admin.generate') || 'Generate'}
                {/if}
              </button>
            </div>
            <p class="mt-2 text-xs text-slate-500 italic">{t('admin.generateAccessCodeHint') || "Click 'Generate' to create a 6-digit access code for the customer"}</p>
          </div>
        {/if}
        
        <div class="mt-4">
          <label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="approvalNotes">{t('admin.notesOptional') || 'Notes (Optional)'}:</label>
          <textarea
            id="approvalNotes"
            bind:value={approvalNotes}
            placeholder={actionType === "approve" ? (t('admin.approvalNotesPlaceholder') || "Add approval notes or special instructions...") : (t('admin.rejectionNotesPlaceholder') || "Provide reason for rejection...")}
            rows="3"
            class="w-full px-4 py-2.5 border border-slate-200 rounded-xl text-sm resize-y font-sans focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
          ></textarea>
        </div>
      </div>
      
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-slate-200">
        {#if showWhatsAppButton}
          <div class="flex flex-col items-center gap-3 w-full">
            <p class="text-emerald-600 font-bold text-sm m-0">✅ {t('admin.customerApprovedSuccess') || 'Customer approved successfully!'}</p>
            <button class="inline-flex items-center gap-2 px-6 py-2.5 bg-[#25d366] text-white border-none rounded-xl cursor-pointer font-bold text-sm hover:bg-[#128c7e] transition-colors" on:click={shareToWhatsApp}>
              📱 {t('admin.shareViaWhatsApp') || 'Share Login via WhatsApp'}
            </button>
            <button class="px-4 py-2 bg-slate-200 text-slate-700 border-none rounded-xl cursor-pointer text-sm hover:bg-slate-300 transition-colors" on:click={closeApprovalModal}>
              {t('admin.done') || 'Done'}
            </button>
          </div>
        {:else}
          <button class="px-5 py-2.5 bg-slate-100 text-slate-700 border-none rounded-xl cursor-pointer font-semibold text-sm hover:bg-slate-200 transition-colors" on:click={closeApprovalModal}>
            {t('admin.cancel') || 'Cancel'}
          </button>
          <button 
            class="px-5 py-2.5 text-white border-none rounded-xl cursor-pointer font-bold text-sm transition-all hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed {actionType === 'approve' ? 'bg-emerald-600 hover:bg-emerald-700' : 'bg-red-600 hover:bg-red-700'}"
            on:click={saveApproval}
            disabled={isSavingApproval || (actionType === 'approve' && !generatedAccessCode)}
          >
            {#if isSavingApproval}
              {t('admin.saving') || 'Saving...'}
            {:else}
              {actionType === "approve" ? (t('admin.saveAndApprove') || 'Save & Approve') : (t('admin.reject') || 'Reject')}
            {/if}
          </button>
        {/if}
      </div>
    </div>
  </div>
{/if}

<!-- Location Management Modal -->
{#if showLocationModal && locationCustomer}
  <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[1000]" on:click={closeLocationModal}>
    <div class="bg-white rounded-2xl max-w-[800px] w-[90vw] max-h-[90vh] overflow-y-auto shadow-[0_32px_64px_-16px_rgba(0,0,0,0.2)] relative z-[1001]" on:click|stopPropagation>
      <div class="flex justify-between items-center px-6 py-4 border-b border-slate-200">
        <h3 class="text-base font-bold text-slate-800 m-0">📍 {t('admin.viewLocations') || 'View Locations'}</h3>
        <button class="w-8 h-8 flex items-center justify-center text-slate-400 hover:text-slate-700 text-xl bg-transparent border-none cursor-pointer rounded-lg hover:bg-slate-100 transition-colors" on:click={closeLocationModal}>✕</button>
      </div>
      <div class="p-6">
        <div class="mb-4 p-4 bg-slate-50 rounded-xl border border-slate-200">
          <p class="my-1 text-sm text-slate-700"><strong class="text-slate-900">{t('admin.customer') || 'Customer'}:</strong> {locationCustomer.name || t('admin.unknownCustomer') || 'Unknown Customer'}</p>
          <p class="my-1 text-sm text-slate-700"><strong class="text-slate-900">{t('admin.whatsapp') || 'WhatsApp'}:</strong> {locationCustomer.whatsapp_number || t('admin.notProvided') || 'Not Provided'}</p>
        </div>
        
        <div class="flex gap-2 mb-4 border-b-2 border-slate-200">
          <button class="flex-1 px-4 py-3 bg-transparent border-none border-b-[3px] cursor-pointer text-sm font-bold transition-all rounded-t-lg {currentEditingLocation === 1 ? 'text-emerald-600 border-b-emerald-600 bg-emerald-50/50' : 'text-slate-500 border-b-transparent hover:text-slate-700 hover:bg-slate-50'}" on:click={() => currentEditingLocation = 1}>
            📍 {t('admin.location') || 'Location'} 1
          </button>
          <button class="flex-1 px-4 py-3 bg-transparent border-none border-b-[3px] cursor-pointer text-sm font-bold transition-all rounded-t-lg {currentEditingLocation === 2 ? 'text-emerald-600 border-b-emerald-600 bg-emerald-50/50' : 'text-slate-500 border-b-transparent hover:text-slate-700 hover:bg-slate-50'}" on:click={() => currentEditingLocation = 2}>
            📍 {t('admin.location') || 'Location'} 2
          </button>
          <button class="flex-1 px-4 py-3 bg-transparent border-none border-b-[3px] cursor-pointer text-sm font-bold transition-all rounded-t-lg {currentEditingLocation === 3 ? 'text-emerald-600 border-b-emerald-600 bg-emerald-50/50' : 'text-slate-500 border-b-transparent hover:text-slate-700 hover:bg-slate-50'}" on:click={() => currentEditingLocation = 3}>
            📍 {t('admin.location') || 'Location'} 3
          </button>
        </div>

        <div class="mt-4">
          {#if currentEditingLocation === 1}
            {#if loc1_lat && loc1_lng}
              <div class="bg-slate-50 p-5 rounded-2xl border-2 border-slate-200">
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.name') || 'Name'}:</strong> {loc1_name || t('admin.notSet') || 'Not set'}</p>
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.distance') || 'Distance'}:</strong> <span class="text-emerald-600 font-bold text-base">{getDistanceToLocation(loc1_lat, loc1_lng)}</span></p>
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.coordinates') || 'Coordinates'}:</strong> {loc1_lat.toFixed(6)}, {loc1_lng.toFixed(6)}</p>
              </div>
              <div class="mt-4 rounded-2xl overflow-hidden border-2 border-emerald-200/50 shadow-lg">
                {#key `loc1-${loc1_lat}-${loc1_lng}`}
                  <LocationMapDisplay 
                    locations={[{
                      name: loc1_name || 'Location 1',
                      lat: loc1_lat,
                      lng: loc1_lng,
                      url: loc1_url || ''
                    }]}
                    selectedIndex={0}
                    height="400px"
                    language="en"
                  />
                {/key}
              </div>
            {:else}
              <p class="text-slate-400 italic text-center p-4 bg-slate-50 rounded-xl mt-4">{t('admin.location') || 'Location'} 1 {t('admin.locationNotSetMessage') || 'is not set by the customer'}.</p>
            {/if}
          {:else if currentEditingLocation === 2}
            {#if loc2_lat && loc2_lng}
              <div class="bg-slate-50 p-5 rounded-2xl border-2 border-slate-200">
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.name') || 'Name'}:</strong> {loc2_name || t('admin.notSet') || 'Not set'}</p>
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.distance') || 'Distance'}:</strong> <span class="text-emerald-600 font-bold text-base">{getDistanceToLocation(loc2_lat, loc2_lng)}</span></p>
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.coordinates') || 'Coordinates'}:</strong> {loc2_lat.toFixed(6)}, {loc2_lng.toFixed(6)}</p>
              </div>
              <div class="mt-4 rounded-2xl overflow-hidden border-2 border-emerald-200/50 shadow-lg">
                {#key `loc2-${loc2_lat}-${loc2_lng}`}
                  <LocationMapDisplay 
                    locations={[{
                      name: loc2_name || 'Location 2',
                      lat: loc2_lat,
                      lng: loc2_lng,
                      url: loc2_url || ''
                    }]}
                    selectedIndex={0}
                    height="400px"
                    language="en"
                  />
                {/key}
              </div>
            {:else}
              <p class="text-slate-400 italic text-center p-4 bg-slate-50 rounded-xl mt-4">{t('admin.location') || 'Location'} 2 {t('admin.locationNotSetMessage') || 'is not set by the customer'}.</p>
            {/if}
          {:else if currentEditingLocation === 3}
            {#if loc3_lat && loc3_lng}
              <div class="bg-slate-50 p-5 rounded-2xl border-2 border-slate-200">
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.name') || 'Name'}:</strong> {loc3_name || t('admin.notSet') || 'Not set'}</p>
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.distance') || 'Distance'}:</strong> <span class="text-emerald-600 font-bold text-base">{getDistanceToLocation(loc3_lat, loc3_lng)}</span></p>
                <p class="my-2 text-sm text-slate-700"><strong class="text-slate-900 mr-2">{t('admin.coordinates') || 'Coordinates'}:</strong> {loc3_lat.toFixed(6)}, {loc3_lng.toFixed(6)}</p>
              </div>
              <div class="mt-4 rounded-2xl overflow-hidden border-2 border-emerald-200/50 shadow-lg">
                {#key `loc3-${loc3_lat}-${loc3_lng}`}
                  <LocationMapDisplay 
                    locations={[{
                      name: loc3_name || 'Location 3',
                      lat: loc3_lat,
                      lng: loc3_lng,
                      url: loc3_url || ''
                    }]}
                    selectedIndex={0}
                    height="400px"
                    language="en"
                  />
                {/key}
              </div>
            {:else}
              <p class="text-slate-400 italic text-center p-4 bg-slate-50 rounded-xl mt-4">{t('admin.location') || 'Location'} 3 {t('admin.locationNotSetMessage') || 'is not set by the customer'}.</p>
            {/if}
          {/if}
        </div>
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-slate-200">
        <button class="px-5 py-2.5 bg-slate-100 text-slate-700 border-none rounded-xl cursor-pointer font-semibold text-sm hover:bg-slate-200 transition-colors" on:click={closeLocationModal}>{t('admin.close') || 'Close'}</button>
      </div>
    </div>
  </div>
{/if}

<!-- Import Customers Modal -->
{#if showImportModal}
  <div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-[1000]" on:click={closeImportModal}>
    <div class="bg-white rounded-2xl max-w-[560px] w-[90vw] max-h-[90vh] overflow-y-auto shadow-[0_32px_64px_-16px_rgba(0,0,0,0.2)] relative z-[1001]" on:click|stopPropagation>
      <div class="flex justify-between items-center px-6 py-4 border-b border-slate-200">
        <h2 class="text-base font-bold text-slate-800 m-0">📥 Import Customers</h2>
        <button class="w-8 h-8 flex items-center justify-center text-slate-400 hover:text-slate-700 text-xl bg-transparent border-none cursor-pointer rounded-lg hover:bg-slate-100 transition-colors" on:click={closeImportModal}>✕</button>
      </div>
      <div class="p-6">
        <p class="text-slate-500 mb-4 text-sm">
          Upload a CSV or text file with phone numbers (one per line or comma-separated).<br/>
          Customers will be saved as <strong>Pre-Registered</strong>. When they register from the app, they'll get their access code automatically.
        </p>
        
        <div class="mb-4">
          <label class="flex items-center gap-3 p-5 border-2 border-dashed border-slate-300 rounded-2xl cursor-pointer transition-all bg-slate-50 text-slate-500 text-sm hover:border-emerald-500 hover:bg-emerald-50/50 hover:text-emerald-600">
            <input type="file" accept=".csv,.txt,.xlsx" on:change={handleFileSelect} class="hidden" />
            <span class="text-2xl">📁</span>
            <span>{importFile ? importFile.name : 'Choose CSV / TXT file...'}</span>
          </label>
        </div>

        {#if importPhoneNumbers.length > 0}
          <div class="bg-emerald-50 border border-emerald-200 rounded-2xl p-4 mb-4">
            <div class="mb-3 text-sm text-emerald-800 font-bold">
              📋 {importPhoneNumbers.length} phone numbers found
            </div>
            <div class="flex flex-wrap gap-2">
              {#each importPhoneNumbers.slice(0, 10) as phone}
                <span class="inline-block px-3 py-1 bg-white border border-slate-200 rounded-full text-xs font-mono text-slate-700">{phone}</span>
              {/each}
              {#if importPhoneNumbers.length > 10}
                <span class="inline-block px-3 py-1 bg-blue-100 border border-blue-300 rounded-full text-xs font-bold text-blue-700">+{importPhoneNumbers.length - 10} more</span>
              {/if}
            </div>
          </div>
        {/if}

        {#if importResult}
          <div class="flex items-start gap-3 p-4 rounded-2xl mb-4 text-sm {importResult.success ? 'bg-emerald-50 border border-emerald-200 text-emerald-800' : 'bg-red-50 border border-red-200 text-red-800'}">
            <span class="text-xl flex-shrink-0">{importResult.success ? '✅' : '❌'}</span>
            <div>
              <strong>{importResult.message}</strong>
              {#if importResult.success}
                <div class="text-xs mt-1 text-slate-500">
                  {importResult.inserted} imported • {importResult.skipped} skipped (duplicates)
                </div>
              {/if}
            </div>
          </div>
        {/if}
      </div>
      <div class="flex justify-end gap-3 px-6 py-4 border-t border-slate-200">
        <button class="px-5 py-2.5 bg-slate-100 text-slate-700 border-none rounded-xl cursor-pointer font-semibold text-sm hover:bg-slate-200 transition-colors" on:click={closeImportModal}>
          {importResult?.success ? 'Done' : 'Cancel'}
        </button>
        {#if !importResult?.success}
          <button 
            class="px-5 py-2.5 bg-emerald-600 text-white border-none rounded-xl cursor-pointer font-bold text-sm hover:bg-emerald-700 transition-all hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
            on:click={importCustomers}
            disabled={importing || importPhoneNumbers.length === 0}
          >
            {#if importing}
              ⏳ Importing...
            {:else}
              📥 Import {importPhoneNumbers.length} Customers
            {/if}
          </button>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  /* ===== ROOT CONTAINER ===== */
  .cm-root {
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #f8fafc;
    overflow: hidden;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }

  /* ===== HEADER BAR ===== */
  .cm-header {
    background: white;
    border-bottom: 1px solid #e2e8f0;
    padding: 1rem 1.5rem;
    display: flex;
    align-items: center;
    justify-content: space-between;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  }
  .cm-header h1 {
    font-size: 1.125rem;
    font-weight: 900;
    color: #1e293b;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin: 0;
  }
  .cm-header p {
    font-size: 0.75rem;
    color: #64748b;
    margin: 0.125rem 0 0 0;
  }
  .cm-header-actions {
    display: flex;
    gap: 0.5rem;
  }

  /* ===== ACTION BUTTONS (Header) ===== */
  .cm-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.625rem 1.25rem;
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: white;
    border: none;
    border-radius: 0.75rem;
    cursor: pointer;
    transition: all 0.3s ease;
    overflow: hidden;
    position: relative;
  }
  .cm-btn:hover {
    transform: scale(1.02);
    box-shadow: 0 10px 25px -5px rgba(0,0,0,0.2);
  }
  .cm-btn-green {
    background: #059669;
    box-shadow: 0 4px 14px -3px rgba(5, 150, 105, 0.4);
  }
  .cm-btn-green:hover { background: #047857; }
  .cm-btn-blue {
    background: #2563eb;
    box-shadow: 0 4px 14px -3px rgba(37, 99, 235, 0.4);
  }
  .cm-btn-blue:hover { background: #1d4ed8; }
  .cm-btn .btn-icon {
    font-size: 1rem;
    filter: drop-shadow(0 1px 1px rgba(0,0,0,0.1));
    transition: transform 0.5s ease;
  }
  .cm-btn:hover .btn-icon { transform: rotate(12deg); }

  /* ===== MAIN CONTENT AREA ===== */
  .cm-content {
    flex: 1;
    padding: 2rem;
    position: relative;
    overflow-y: auto;
    background: radial-gradient(ellipse at top right, white, rgba(248,250,252,0.5), rgba(241,245,249,0.5));
  }
  .cm-content-inner {
    position: relative;
    max-width: 99%;
    margin: 0 auto;
    height: 100%;
    display: flex;
    flex-direction: column;
  }
  /* Decorative blurs */
  .cm-blur-1 {
    position: absolute;
    top: 0; right: 0;
    width: 500px; height: 500px;
    background: rgba(167,243,208,0.2);
    border-radius: 50%;
    filter: blur(120px);
    margin-right: -256px; margin-top: -256px;
    animation: pulse 2s ease-in-out infinite;
    pointer-events: none;
  }
  .cm-blur-2 {
    position: absolute;
    bottom: 0; left: 0;
    width: 500px; height: 500px;
    background: rgba(191,219,254,0.2);
    border-radius: 50%;
    filter: blur(120px);
    margin-left: -256px; margin-bottom: -256px;
    animation: pulse 2s ease-in-out infinite 2s;
    pointer-events: none;
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }

  /* ===== STATUS CARDS ===== */
  .cm-cards {
    display: flex;
    gap: 1rem;
    margin-bottom: 1rem;
  }
  .cm-card {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1.25rem;
    background: rgba(255,255,255,0.4);
    backdrop-filter: blur(24px);
    border-radius: 1rem;
    border: 1px solid white;
    box-shadow: 0 8px 32px -8px rgba(0,0,0,0.08);
    transition: all 0.3s ease;
  }
  .cm-card:hover {
    box-shadow: 0 12px 40px -8px rgba(0,0,0,0.12);
    transform: translateY(-2px);
  }
  .cm-card-icon { font-size: 2.5rem; }
  .cm-card-number {
    font-size: 1.875rem;
    font-weight: 900;
    line-height: 1;
  }
  .cm-card-number.amber { color: #f59e0b; }
  .cm-card-number.red { color: #ef4444; }
  .cm-card-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: #64748b;
    margin-top: 0.25rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  /* ===== FILTER CONTROLS ===== */
  .cm-filters {
    display: flex;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }
  .cm-filter-group {
    flex: 1;
  }
  .cm-filter-label {
    display: block;
    font-size: 0.75rem;
    font-weight: 700;
    color: #475569;
    margin-bottom: 0.5rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .cm-filter-input,
  .cm-filter-select {
    width: 100%;
    padding: 0.625rem 1rem;
    background: white;
    border: 1px solid #e2e8f0;
    border-radius: 0.75rem;
    font-size: 0.875rem;
    transition: all 0.2s ease;
    color: #000 !important;
    background-color: #fff !important;
  }
  .cm-filter-input:focus,
  .cm-filter-select:focus {
    outline: none;
    border-color: transparent;
    box-shadow: 0 0 0 2px #10b981;
  }
  .cm-filter-select option {
    color: #000 !important;
    background-color: #fff !important;
  }

  /* ===== LOADING SPINNER ===== */
  .cm-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
  }
  .cm-spinner {
    width: 3rem; height: 3rem;
    border: 4px solid #a7f3d0;
    border-top-color: #059669;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* ===== TABLE CONTAINER ===== */
  .cm-table-wrap {
    background: rgba(255,255,255,0.4);
    backdrop-filter: blur(24px);
    border-radius: 2.5rem;
    border: 1px solid white;
    box-shadow: 0 32px 64px -16px rgba(0,0,0,0.08);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    flex: 1;
  }
  .cm-table-scroll {
    overflow: auto;
    flex: 1;
  }
  .cm-table {
    width: 100%;
    border-collapse: collapse;
  }
  .cm-table th {
    background: #059669;
    color: white;
    padding: 0.75rem 1rem;
    font-size: 0.75rem;
    font-weight: 900;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    border-bottom: 2px solid #34d399;
    border-left: 1px solid rgba(52,211,153,0.3);
    border-right: 1px solid rgba(52,211,153,0.3);
    position: sticky;
    top: 0;
    z-index: 10;
    box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
  }
  .cm-table th.text-left { text-align: left; }
  .cm-table th.text-center { text-align: center; }
  .cm-table td {
    padding: 0.75rem 1rem;
    font-size: 0.875rem;
    color: #334155;
    border-bottom: 1px solid #e2e8f0;
    border-left: 1px solid #e2e8f0;
    border-right: 1px solid #e2e8f0;
  }
  .cm-table td.text-center { text-align: center; }
  .cm-table td.font-mono { font-family: 'Courier New', monospace; }
  .cm-table tbody tr:nth-child(even) { background: rgba(248,250,252,0.2); }
  .cm-table tbody tr:nth-child(odd) { background: rgba(255,255,255,0.2); }
  .cm-table tbody tr:hover { background: rgba(236,253,245,0.3); }

  /* ===== STATUS BADGES ===== */
  .cm-badge {
    display: inline-block;
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.625rem;
    font-weight: 900;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .cm-badge-approved { color: #16a34a; background: #dcfce7; }
  .cm-badge-rejected { color: #dc2626; background: #fee2e2; }
  .cm-badge-pending { color: #ca8a04; background: #fef9c3; }
  .cm-badge-suspended { color: #ea580c; background: #ffedd5; }
  .cm-badge-pre_registered { color: #4f46e5; background: #e0e7ff; }
  .cm-badge-default { color: #4b5563; background: #f3f4f6; }

  /* ===== TABLE ACTION BUTTONS ===== */
  .cm-table-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.5rem 1rem;
    border-radius: 0.5rem;
    font-size: 0.75rem;
    font-weight: 700;
    color: white;
    border: none;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .cm-table-btn:hover {
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    transform: scale(1.05);
  }
  .cm-table-btn-blue { background: #2563eb; }
  .cm-table-btn-blue:hover { background: #1d4ed8; }
  .cm-table-btn-green { background: #059669; }
  .cm-table-btn-green:hover { background: #047857; }
  .cm-table-btn-red { background: #dc2626; }
  .cm-table-btn-red:hover { background: #b91c1c; }
  .cm-table-actions {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }
  .cm-status-text {
    font-size: 0.75rem;
    color: #64748b;
    font-weight: 600;
  }
  .cm-approval-date {
    font-size: 0.625rem;
    color: #94a3b8;
  }

  /* ===== PAGINATION ===== */
  .cm-pagination {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.75rem 1.5rem;
    background: #1e293b;
    border-top: 1px solid #334155;
    border-radius: 0 0 2.5rem 2.5rem;
    flex-wrap: wrap;
    gap: 0.5rem;
  }
  .cm-pagination-info {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 0.8rem;
    color: #94a3b8;
  }
  .cm-page-size-select {
    background: #0f172a;
    border: 1px solid #334155;
    color: #e2e8f0 !important;
    background-color: #0f172a !important;
    padding: 0.25rem 0.5rem;
    border-radius: 0.375rem;
    font-size: 0.8rem;
    cursor: pointer;
  }
  .cm-page-size-select:hover { border-color: #10b981; }
  .cm-page-size-select option {
    color: #e2e8f0 !important;
    background-color: #0f172a !important;
  }
  .cm-pagination-controls {
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }
  .cm-page-btn {
    min-width: 2rem;
    height: 2rem;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #0f172a;
    border: 1px solid #334155;
    color: #e2e8f0;
    border-radius: 0.375rem;
    font-size: 0.8rem;
    cursor: pointer;
    transition: all 0.15s;
    padding: 0 0.4rem;
  }
  .cm-page-btn:hover:not(:disabled):not(.active) {
    background: #334155;
    border-color: #10b981;
  }
  .cm-page-btn.active {
    background: #059669;
    border-color: #059669;
    color: white;
    font-weight: 700;
  }
  .cm-page-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
  .cm-page-ellipsis {
    min-width: 1.5rem;
    text-align: center;
    color: #64748b;
    font-size: 0.85rem;
  }

  /* ===== EMPTY STATE ===== */
  .cm-empty {
    background: rgba(255,255,255,0.4);
    backdrop-filter: blur(24px);
    border-radius: 2.5rem;
    border: 2px dashed #e2e8f0;
    box-shadow: 0 32px 64px -16px rgba(0,0,0,0.08);
    padding: 3rem;
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }
  .cm-empty-icon { font-size: 3rem; margin-bottom: 1rem; }
  .cm-empty-text { color: #475569; font-weight: 600; }

  /* ===== MODAL OVERLAY ===== */
  .cm-modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.5);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  .cm-modal {
    background: white;
    border-radius: 1rem;
    max-width: 500px;
    width: 90vw;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 32px 64px -16px rgba(0,0,0,0.2);
    position: relative;
    z-index: 1001;
  }
  .cm-modal.wide { max-width: 800px; }
  .cm-modal.medium { max-width: 560px; }
  .cm-modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e2e8f0;
  }
  .cm-modal-header h3 {
    margin: 0;
    font-size: 1rem;
    font-weight: 700;
    color: #1e293b;
  }
  .cm-modal-close {
    width: 2rem; height: 2rem;
    display: flex; align-items: center; justify-content: center;
    background: transparent;
    border: none;
    font-size: 1.25rem;
    color: #94a3b8;
    cursor: pointer;
    border-radius: 0.5rem;
    transition: all 0.2s;
  }
  .cm-modal-close:hover { background: #f1f5f9; color: #334155; }
  .cm-modal-body { padding: 1.5rem; }
  .cm-modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
    padding: 1rem 1.5rem;
    border-top: 1px solid #e2e8f0;
  }

  /* ===== MODAL INFO BOX ===== */
  .cm-info-box {
    margin-bottom: 1rem;
    padding: 1rem;
    background: #f8fafc;
    border-radius: 0.75rem;
    border: 1px solid #e2e8f0;
  }
  .cm-info-box p {
    margin: 0.25rem 0;
    font-size: 0.875rem;
    color: #334155;
  }
  .cm-info-box strong { color: #0f172a; }

  /* ===== MODAL BUTTONS ===== */
  .cm-modal-btn {
    padding: 0.625rem 1.25rem;
    border: none;
    border-radius: 0.75rem;
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .cm-modal-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .cm-modal-btn-cancel { background: #f1f5f9; color: #334155; }
  .cm-modal-btn-cancel:hover { background: #e2e8f0; }
  .cm-modal-btn-green { background: #059669; color: white; }
  .cm-modal-btn-green:hover:not(:disabled) { background: #047857; box-shadow: 0 4px 12px rgba(5,150,105,0.3); }
  .cm-modal-btn-red { background: #dc2626; color: white; }
  .cm-modal-btn-red:hover:not(:disabled) { background: #b91c1c; box-shadow: 0 4px 12px rgba(220,38,38,0.3); }
  .cm-modal-btn-whatsapp { background: #25d366; color: white; font-weight: 700; }
  .cm-modal-btn-whatsapp:hover { background: #128c7e; }
  .cm-modal-btn-secondary { background: #64748b; color: white; }
  .cm-modal-btn-secondary:hover { background: #475569; }

  /* ===== ACCESS CODE SECTION ===== */
  .cm-access-code {
    margin: 1rem 0;
    padding: 1rem;
    background: rgba(236,253,245,0.5);
    border-radius: 0.75rem;
    border: 1px solid #a7f3d0;
  }
  .cm-access-code-group {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.5rem;
  }
  .cm-access-code-input {
    flex: 1;
    padding: 0.625rem;
    border: 1px solid #e2e8f0;
    border-radius: 0.75rem;
    font-family: monospace;
    font-size: 1.1rem;
    text-align: center;
    letter-spacing: 0.2em;
    background: white;
  }
  .cm-access-code-input:focus {
    outline: none;
    box-shadow: 0 0 0 2px #10b981;
    border-color: transparent;
  }
  .cm-access-code-hint {
    margin-top: 0.5rem;
    font-size: 0.75rem;
    color: #64748b;
    font-style: italic;
  }

  /* ===== NOTES TEXTAREA ===== */
  .cm-textarea {
    width: 100%;
    padding: 0.625rem 1rem;
    border: 1px solid #e2e8f0;
    border-radius: 0.75rem;
    font-size: 0.875rem;
    resize: vertical;
    font-family: inherit;
  }
  .cm-textarea:focus {
    outline: none;
    box-shadow: 0 0 0 2px #10b981;
    border-color: transparent;
  }

  /* ===== LOCATION TABS ===== */
  .cm-loc-tabs {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1rem;
    border-bottom: 2px solid #e2e8f0;
  }
  .cm-loc-tab {
    flex: 1;
    padding: 0.75rem 1rem;
    background: transparent;
    border: none;
    border-bottom: 3px solid transparent;
    cursor: pointer;
    font-size: 0.875rem;
    font-weight: 700;
    color: #64748b;
    transition: all 0.2s;
    border-radius: 0.5rem 0.5rem 0 0;
  }
  .cm-loc-tab:hover { color: #334155; background: rgba(248,250,252,0.5); }
  .cm-loc-tab.active {
    color: #059669;
    border-bottom-color: #059669;
    background: rgba(236,253,245,0.5);
  }
  .cm-loc-info {
    background: #f8fafc;
    padding: 1.25rem;
    border-radius: 1rem;
    border: 2px solid #e2e8f0;
  }
  .cm-loc-info p { margin: 0.5rem 0; font-size: 0.875rem; color: #334155; }
  .cm-loc-info strong { color: #0f172a; margin-right: 0.5rem; }
  .cm-loc-distance { color: #059669; font-weight: 700; font-size: 1rem; }
  .cm-loc-map {
    margin-top: 1rem;
    border-radius: 1rem;
    overflow: hidden;
    border: 2px solid rgba(5,150,105,0.2);
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  }
  .cm-loc-notset {
    color: #94a3b8;
    font-style: italic;
    text-align: center;
    padding: 1rem;
    background: #f1f5f9;
    border-radius: 0.5rem;
    margin-top: 1rem;
  }

  /* ===== IMPORT MODAL ===== */
  .cm-import-desc { color: #64748b; margin-bottom: 1rem; font-size: 0.875rem; }
  .cm-file-upload {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1.25rem;
    border: 2px dashed #cbd5e1;
    border-radius: 1rem;
    cursor: pointer;
    transition: all 0.2s;
    background: #f8fafc;
    font-size: 0.875rem;
    color: #64748b;
    margin-bottom: 1rem;
  }
  .cm-file-upload:hover { border-color: #10b981; background: rgba(236,253,245,0.5); color: #059669; }
  .cm-file-upload-icon { font-size: 1.5rem; }
  .cm-import-preview {
    background: #ecfdf5;
    border: 1px solid #a7f3d0;
    border-radius: 1rem;
    padding: 1rem;
    margin-bottom: 1rem;
  }
  .cm-import-preview-header { margin-bottom: 0.5rem; font-size: 0.875rem; color: #065f46; font-weight: 700; }
  .cm-import-preview-list { display: flex; flex-wrap: wrap; gap: 0.5rem; }
  .cm-phone-chip {
    display: inline-block;
    padding: 0.25rem 0.75rem;
    background: white;
    border: 1px solid #e2e8f0;
    border-radius: 999px;
    font-size: 0.75rem;
    font-family: monospace;
    color: #334155;
  }
  .cm-phone-chip-more {
    display: inline-block;
    padding: 0.25rem 0.75rem;
    background: #e0e7ff;
    border: 1px solid #a5b4fc;
    border-radius: 999px;
    font-size: 0.75rem;
    font-weight: 700;
    color: #4338ca;
  }
  .cm-import-result {
    display: flex;
    align-items: flex-start;
    gap: 0.75rem;
    padding: 1rem;
    border-radius: 1rem;
    margin-bottom: 1rem;
    font-size: 0.875rem;
  }
  .cm-import-result.success { background: #ecfdf5; border: 1px solid #6ee7b7; color: #065f46; }
  .cm-import-result.error { background: #fef2f2; border: 1px solid #fca5a5; color: #991b1b; }
  .cm-import-result-icon { font-size: 1.25rem; flex-shrink: 0; }
  .cm-import-result-detail { font-size: 0.75rem; margin-top: 0.25rem; color: #64748b; }

  /* ===== WHATSAPP SECTION ===== */
  .cm-whatsapp-section {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.75rem;
    width: 100%;
  }
  .cm-success-msg { color: #059669; font-weight: 700; font-size: 0.875rem; margin: 0; }
</style>