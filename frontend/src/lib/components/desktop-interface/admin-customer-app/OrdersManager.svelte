<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { currentUser } from '$lib/utils/persistentAuth';
  import { notifications } from '$lib/stores/notifications';
  import { t, currentLocale } from '$lib/i18n';
  import { openWindow } from '$lib/utils/windowManagerUtils';
  import OrderDetailWindow from '$lib/components/desktop-interface/admin-customer-app/OrderDetailWindow.svelte';
  
  // Reactive RTL check
  $: isRTL = $currentLocale === 'ar';

  // Print settings - selected printer names stored per paper size (persisted in localStorage)
  let selectedA4Printer = '';
  let selectedThermalPrinter = '';
  let autoPrintNewOrders = false;

  // Load saved print config from localStorage  
  function loadPrintConfig() {
    try {
      const saved = localStorage.getItem('aqura_print_config');
      if (saved) {
        const config = JSON.parse(saved);
        selectedA4Printer = config.a4Printer || '';
        selectedThermalPrinter = config.thermalPrinter || '';
        autoPrintNewOrders = config.autoPrint ?? false;
      }
    } catch (e) { console.error('Error loading print config:', e); }
  }

  // Save print config to localStorage
  function savePrintConfig() {
    try {
      localStorage.setItem('aqura_print_config', JSON.stringify({
        a4Printer: selectedA4Printer,
        thermalPrinter: selectedThermalPrinter,
        autoPrint: autoPrintNewOrders
      }));
    } catch (e) { console.error('Error saving print config:', e); }
  }

  // Auto-save whenever config changes
  $: if (typeof window !== 'undefined') {
    // Trigger save on any config change
    selectedA4Printer, selectedThermalPrinter, autoPrintNewOrders;
    savePrintConfig();
  }

  // Listen for printer name from the test print window
  function handlePrinterMessage(event: MessageEvent) {
    if (event.data?.type === 'printer-selected') {
      const { paperSize, printerName } = event.data;
      if (paperSize === 'A4') selectedA4Printer = printerName;
      else if (paperSize === '80mm') selectedThermalPrinter = printerName;
    }
  }

  // Auto-print a new order when it arrives
  function autoPrintOrder(order: any) {
    if (!autoPrintNewOrders) return;
    console.log('🖨️ Auto-printing order:', order.order_number);
    
    // Build a simple order slip for auto-print
    const s = 'style';
    const printWindow = window.open('', '_blank', 'width=800,height=600');
    if (!printWindow) { console.error('Auto-print: popup blocked'); return; }
    
    const orderDate = new Date(order.created_at).toLocaleString();
    const branchObj = branches.find((b: any) => b.id === order.branch_id);
    const branchName = branchObj ? (isRTL ? branchObj.name_ar : branchObj.name_en) : '';
    
    printWindow.document.write(`<html><head><title>Order ${order.order_number}</title>
      <${s}>
        @page { size: A4; margin: 10mm; }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, sans-serif; padding: 10mm; background: white; }
        .header { text-align: center; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 2px solid #333; }
        .header h1 { font-size: 22px; margin-bottom: 4px; }
        .header .order-num { font-size: 28px; font-weight: bold; color: #2563eb; letter-spacing: 1px; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 13px; margin-bottom: 15px; padding: 10px; background: #f9fafb; border-radius: 8px; }
        .info-grid strong { color: #374151; }
        .summary { margin-top: 15px; padding: 12px; background: #f0fdf4; border: 2px solid #86efac; border-radius: 8px; }
        .summary-row { display: flex; justify-content: space-between; padding: 4px 0; font-size: 14px; }
        .summary-row.total { font-size: 18px; font-weight: bold; border-top: 2px solid #16a34a; padding-top: 8px; margin-top: 4px; }
        .footer { text-align: center; margin-top: 20px; color: #9ca3af; font-size: 12px; }
        .note { margin-top: 10px; padding: 10px; background: #fffbeb; border: 1px solid #fbbf24; border-radius: 8px; font-size: 13px; }
      </${s}></head><body>
        <div class="header">
          <h1>${isRTL ? 'طلب جديد' : 'New Order'}</h1>
          <div class="order-num">${order.order_number || 'N/A'}</div>
        </div>
        <div class="info-grid">
          <div><strong>${isRTL ? 'التاريخ:' : 'Date:'}</strong> ${orderDate}</div>
          <div><strong>${isRTL ? 'الفرع:' : 'Branch:'}</strong> ${branchName}</div>
          <div><strong>${isRTL ? 'العميل:' : 'Customer:'}</strong> ${order.customer_name || 'N/A'}</div>
          <div><strong>${isRTL ? 'الهاتف:' : 'Phone:'}</strong> ${order.customer_phone || 'N/A'}</div>
          <div><strong>${isRTL ? 'نوع الطلب:' : 'Type:'}</strong> ${order.order_type === 'delivery' ? (isRTL ? 'توصيل' : 'Delivery') : (isRTL ? 'استلام' : 'Pickup')}</div>
          <div><strong>${isRTL ? 'الدفع:' : 'Payment:'}</strong> ${order.payment_method || 'N/A'}</div>
          <div><strong>${isRTL ? 'عدد المنتجات:' : 'Items:'}</strong> ${order.item_count || order.total_items || order.total_quantity || '?'}</div>
          <div><strong>${isRTL ? 'الحالة:' : 'Status:'}</strong> ${order.order_status || 'new'}</div>
        </div>
        <div class="summary">
          ${order.subtotal_amount ? `<div class="summary-row"><span>${isRTL ? 'المجموع الفرعي:' : 'Subtotal:'}</span><span>${Number(order.subtotal_amount).toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</span></div>` : ''}
          ${order.delivery_fee > 0 ? `<div class="summary-row"><span>${isRTL ? 'رسوم التوصيل:' : 'Delivery:'}</span><span>${Number(order.delivery_fee).toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</span></div>` : ''}
          ${order.discount_amount > 0 ? `<div class="summary-row"><span>${isRTL ? 'الخصم:' : 'Discount:'}</span><span>-${Number(order.discount_amount).toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</span></div>` : ''}
          <div class="summary-row total"><span>${isRTL ? 'الإجمالي:' : 'Total:'}</span><span>${Number(order.total_amount).toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</span></div>
        </div>
        ${order.customer_notes ? `<div class="note"><strong>${isRTL ? 'ملاحظات:' : 'Notes:'}</strong> ${order.customer_notes}</div>` : ''}
        <div class="footer">
          <p>Urban Market • ${isRTL ? 'ايربن ماركت' : 'Printed automatically'} • ${orderDate}</p>
        </div>
      </body></html>`);
    printWindow.document.close();
    printWindow.focus();
    setTimeout(() => { printWindow.print(); }, 400);
  }

  function printTestPage(paperSize: string) {
    const isA4 = paperSize === 'A4';
    const width = isA4 ? '210mm' : '80mm';
    const title = isA4 ? 'A4 Test Page' : '80mm Thermal Test';
    const color = isA4 ? '#4338ca' : '#d97706';
    const printWindow = window.open('', '_blank', 'width=800,height=600');
    if (!printWindow) { alert('Popup blocked! Please allow popups for this site.'); return; }
    const s = 'style';
    const sc = 'script';
    printWindow.document.write(`<html><head><title>${title}</title>
      <${s}>
        @page { size: ${width} auto; margin: ${isA4 ? '10mm' : '2mm'}; }
        body { font-family: Arial, sans-serif; text-align: center; padding: ${isA4 ? '40px' : '10px'}; margin: 0; }
        h1 { font-size: ${isA4 ? '28px' : '16px'}; margin-bottom: 10px; }
        p { font-size: ${isA4 ? '16px' : '12px'}; color: #666; }
        .box { border: 2px dashed #333; padding: ${isA4 ? '30px' : '10px'}; margin: ${isA4 ? '20px' : '5px'} auto; border-radius: 8px; }
        .size-label { font-size: ${isA4 ? '48px' : '24px'}; font-weight: bold; color: ${color}; }
        .print-btn { display: block; margin: 20px auto 10px; padding: 14px 40px; font-size: 18px; font-weight: bold; color: white; background: ${color}; border: none; border-radius: 12px; cursor: pointer; }
        .print-btn:hover { opacity: 0.9; }
        .hint { font-size: 13px; color: #999; margin-top: 6px; }
        .name-section { display: none; margin-top: 20px; padding: 20px; background: #f0fdf4; border: 2px solid #86efac; border-radius: 12px; }
        .name-input { padding: 10px 16px; font-size: 16px; border: 2px solid #d1d5db; border-radius: 8px; width: 280px; text-align: center; }
        .name-input:focus { outline: none; border-color: ${color}; }
        .save-btn { display: inline-block; margin-top: 12px; padding: 10px 30px; font-size: 16px; font-weight: bold; color: white; background: #16a34a; border: none; border-radius: 10px; cursor: pointer; }
        .save-btn:hover { background: #15803d; }
        @media print { .no-print { display: none !important; } }
      </${s}></head><body>
        <div class="no-print" id="controls" style="padding:20px; background:#f8f8f8; border-bottom:2px solid #eee; margin-bottom:20px;">
          <button class="print-btn" id="printBtn" onclick="doPrint()">🖨️ Print This Test Page</button>
          <p class="hint">Choose your ${paperSize} printer from the dialog, then click Print</p>
          <div class="name-section" id="nameSection">
            <p style="font-size:15px; font-weight:bold; color:#333; margin-bottom:8px;">✅ What printer did you select?</p>
            <p style="font-size:12px; color:#888; margin-bottom:12px;">Type the printer name you chose from the dialog</p>
            <input class="name-input" id="printerNameInput" placeholder="e.g. HP LaserJet Pro" />
            <br/>
            <button class="save-btn" onclick="savePrinterName()">💾 Save Printer Name</button>
          </div>
        </div>
        <div class="box">
          <div class="size-label">${paperSize}</div>
          <h1>🖨️ ${title}</h1>
          <p>Urban Market - Print Test</p>
          <p>${new Date().toLocaleString()}</p>
          <p style="margin-top:15px">✅ If you can read this, your printer is working correctly</p>
        </div>
        <${sc}>
          function doPrint() {
            window.print();
            // After print dialog closes, show the name input
            setTimeout(function() {
              document.getElementById('nameSection').style.display = 'block';
              document.getElementById('printBtn').style.display = 'none';
              document.getElementById('printerNameInput').focus();
            }, 500);
          }
          function savePrinterName() {
            var name = document.getElementById('printerNameInput').value.trim();
            if (!name) { alert('Please enter the printer name'); return; }
            if (window.opener) {
              window.opener.postMessage({ type: 'printer-selected', paperSize: '${paperSize}', printerName: name }, '*');
            }
            document.getElementById('nameSection').innerHTML = '<p style="font-size:18px; color:#16a34a; font-weight:bold;">✅ Saved: ' + name + '</p><p style="font-size:13px; color:#888; margin-top:6px;">You can close this window now</p>';
          }
        </${sc}>
      </body></html>`);
    printWindow.document.close();
    printWindow.focus();
  }

  // Tab system - ShiftAndDayOff style
  let activeTab = 'in_process';
  $: tabs = [
    { id: 'in_process', label: isRTL ? 'قيد التنفيذ' : 'In Process', icon: '🔄', color: 'blue' },
    { id: 'completed', label: isRTL ? 'مكتملة' : 'Completed', icon: '✅', color: 'green' },
    { id: 'deliveries', label: isRTL ? 'التوصيلات' : 'Deliveries', icon: '🚗', color: 'teal' },
    { id: 'incomplete_tasks', label: isRTL ? 'مهام غير مكتملة' : 'Incomplete Tasks', icon: '⏳', color: 'orange' },
    { id: 'completed_tasks', label: isRTL ? 'مهام مكتملة' : 'Completed Tasks', icon: '✔️', color: 'emerald' },
    { id: 'cancelled', label: isRTL ? 'ملغية' : 'Cancelled', icon: '❌', color: 'red' },
    { id: 'rejected', label: isRTL ? 'مرفوضة' : 'Rejected', icon: '🚫', color: 'rose' },
    { id: 'delivery_receivers', label: isRTL ? 'مستلمي التوصيل' : 'Delivery Receivers', icon: '👷', color: 'purple' },
    { id: 'print_settings', label: isRTL ? 'إعدادات الطباعة' : 'Print Settings', icon: '🖨️', color: 'lime' }
  ];

  // Tab color mapping
  const tabColorMap: Record<string, string> = {
    blue: 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]',
    green: 'bg-green-600 text-white shadow-lg shadow-green-200 scale-[1.02]',
    teal: 'bg-teal-600 text-white shadow-lg shadow-teal-200 scale-[1.02]',
    orange: 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]',
    emerald: 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]',
    red: 'bg-red-600 text-white shadow-lg shadow-red-200 scale-[1.02]',
    rose: 'bg-rose-600 text-white shadow-lg shadow-rose-200 scale-[1.02]',
    purple: 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]',
    lime: 'bg-lime-600 text-white shadow-lg shadow-lime-200 scale-[1.02]'
  };

  // Order statistics
  let stats = {
    newOrders: 0,
    inProgress: 0,
    completedToday: 0,
    totalRevenueToday: 0
  };

  // Orders list
  let orders: any[] = [];
  let filteredOrders: any[] = [];
  let loading = true;

  // Filters
  let branchFilter = 'all';
  let paymentMethodFilter = 'all';
  let searchTerm = '';
  let dateFrom = '';
  let dateTo = '';

  // Branches for filter
  let branches: any[] = [];

  // Real-time subscription
  let ordersChannel: any = null;

  // Default Delivery Receivers
  let deliveryReceivers: any[] = [];
  let allUsers: any[] = [];
  let selectedBranchForReceivers = '';
  let selectedUserForReceiver = '';
  let loadingReceivers = false;
  let savingReceiver = false;
  let receiversChannel: any = null;

  // Status colors
  const statusColors: { [key: string]: string } = {
    new: 'bg-blue-500',
    accepted: 'bg-green-500',
    in_picking: 'bg-orange-500',
    ready: 'bg-purple-500',
    out_for_delivery: 'bg-teal-500',
    delivered: 'bg-green-700',
    picked_up: 'bg-green-700',
    cancelled: 'bg-red-600',
    rejected: 'bg-rose-600'
  };

  // Status labels - reactive based on locale
  $: statusLabels = {
    new: isRTL ? 'جديد' : 'New',
    accepted: isRTL ? 'مقبول' : 'Accepted',
    in_picking: isRTL ? 'قيد التحضير' : 'In Picking',
    ready: isRTL ? 'جاهز' : 'Ready',
    out_for_delivery: isRTL ? 'قيد التوصيل' : 'Out for Delivery',
    delivered: isRTL ? 'تم التوصيل' : 'Delivered',
    picked_up: isRTL ? 'تم الاستلام' : 'Picked Up',
    cancelled: isRTL ? 'ملغي' : 'Cancelled',
    rejected: isRTL ? 'مرفوض' : 'Rejected'
  };

  onMount(async () => {
    loadPrintConfig();
    window.addEventListener('message', handlePrinterMessage);
    await loadBranches();
    await loadOrders();
    await loadStatistics();
    setupRealtimeSubscription();
  });

  onDestroy(() => {
    window.removeEventListener('message', handlePrinterMessage);
    if (ordersChannel) {
      supabase.removeChannel(ordersChannel);
    }
    if (receiversChannel) {
      supabase.removeChannel(receiversChannel);
    }
  });

  function handleTabChange() {
    if (activeTab === 'delivery_receivers') {
      loadDeliveryReceivers();
      loadAllUsers();
      setupReceiversRealtime();
    } else {
      filterOrders();
    }
  }

  async function loadBranches() {
    try {
      const { data, error } = await supabase.from('branches')
        .select('id, name_ar, name_en')
        .order('name_ar');

      if (error) throw error;
      branches = data || [];
    } catch (error) {
      console.error('Error loading branches:', error);
    }
  }

  async function loadOrders(showLoading = true) {
    if (showLoading) loading = true;
    try {
      const { data: ordersData, error: ordersError } = await supabase
        .from('orders')
        .select('*')
        .order('created_at', { ascending: false });

      if (ordersError) throw ordersError;

      const branchIds = new Set(ordersData?.map(o => o.branch_id).filter(Boolean) || []);
      const userIds = new Set([
        ...ordersData?.map(o => o.picker_id).filter(Boolean) || [],
        ...ordersData?.map(o => o.delivery_person_id).filter(Boolean) || []
      ]);

      const [branchesResult, usersResult] = await Promise.all([
        branchIds.size > 0 
          ? supabase.from('branches').select('id, name_en, name_ar').in('id', Array.from(branchIds))
          : Promise.resolve({ data: [] }),
        userIds.size > 0
          ? supabase.from('users').select('id, username').in('id', Array.from(userIds))
          : Promise.resolve({ data: [] })
      ]);

      const branchMap = new Map((branchesResult.data || []).map((b: any) => [b.id, b]));
      const userMap = new Map((usersResult.data || []).map((u: any) => [u.id, u]));

      orders = (ordersData || []).map(order => ({
        ...order,
        branch: branchMap.get(order.branch_id),
        picker: userMap.get(order.picker_id),
        delivery_person: userMap.get(order.delivery_person_id),
        branch_name: branchMap.get(order.branch_id)?.[isRTL ? 'name_ar' : 'name_en'] || 'Branch ' + order.branch_id,
        picker_name: userMap.get(order.picker_id)?.username || null,
        delivery_person_name: userMap.get(order.delivery_person_id)?.username || null
      }));

      filterOrders();
    } catch (error: any) {
      console.error('❌ Error loading orders:', error);
      notifications.add({
        message: isRTL ? `فشل تحميل الطلبات: ${error.message}` : `Failed to load orders: ${error.message}`,
        type: 'error'
      });
    } finally {
      loading = false;
    }
  }

  async function loadStatistics() {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const { count: newCount } = await supabase.from('orders')
        .select('*', { count: 'exact', head: true })
        .eq('order_status', 'new');

      const { count: progressCount } = await supabase.from('orders')
        .select('*', { count: 'exact', head: true })
        .in('order_status', ['accepted', 'in_picking', 'ready', 'out_for_delivery']);

      const { count: completedCount } = await supabase.from('orders')
        .select('*', { count: 'exact', head: true })
        .in('order_status', ['delivered', 'picked_up'])
        .gte('updated_at', today.toISOString());

      const { data: revenueData } = await supabase.from('orders')
        .select('total_amount')
        .in('order_status', ['delivered', 'picked_up'])
        .gte('updated_at', today.toISOString());

      const totalRevenue = revenueData?.reduce((sum, order) => sum + (order.total_amount || 0), 0) || 0;

      stats = {
        newOrders: newCount || 0,
        inProgress: progressCount || 0,
        completedToday: completedCount || 0,
        totalRevenueToday: totalRevenue
      };
    } catch (error) {
      console.error('Error loading statistics:', error);
    }
  }

  function setupRealtimeSubscription() {
    ordersChannel = supabase
      .channel('orders_mgr_realtime')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'orders' }, payload => {
        console.log('🆕 OrdersManager: New order INSERT received:', payload);
        // Immediately add the new order to the local array for instant UI
        const newOrder = payload.new as any;
        if (newOrder && newOrder.id) {
          // Find branch name from loaded branches
          const branch = branches.find(b => b.id === newOrder.branch_id);
          const enrichedOrder = {
            ...newOrder,
            branch_name: branch ? (isRTL ? branch.name_ar : branch.name_en) : 'Branch ' + newOrder.branch_id,
            picker_name: null,
            delivery_person_name: null
          };
          orders = [enrichedOrder, ...orders];
          filterOrders();
          console.log('✅ Order added to local array instantly, total:', orders.length);
        }
        // Background reload for complete enriched data (no loading spinner)
        loadOrders(false);
        loadStatistics();
        playNotificationSound(newOrder?.order_number, newOrder?.total_quantity || newOrder?.total_items);
        // Auto-print if enabled
        autoPrintOrder(newOrder);
        notifications.add({
          message: isRTL ? `طلب جديد: ${newOrder?.order_number}` : `New order: ${newOrder?.order_number}`,
          type: 'info',
          duration: 5000
        });
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'orders' }, payload => {
        console.log('🔄 OrdersManager: Order UPDATE received:', payload);
        const updated = payload.new as any;
        const idx = orders.findIndex(o => o.id === updated.id);
        if (idx !== -1) {
          orders[idx] = { ...orders[idx], ...updated };
          orders = orders;
          filterOrders();
          console.log(`✅ Order ${updated.order_number} status → ${updated.order_status}`);
        }
        loadOrders(false);
        loadStatistics();
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'orders' }, () => {
        console.log('🗑️ OrdersManager: Order DELETE received');
        loadOrders(false);
        loadStatistics();
      })
      .subscribe((status: string) => {
        console.log('📡 OrdersManager realtime status:', status);
        if (status === 'CHANNEL_ERROR') {
          console.error('❌ OrdersManager realtime channel error - will retry in 5s');
          setTimeout(() => {
            if (ordersChannel) {
              supabase.removeChannel(ordersChannel);
              ordersChannel = null;
            }
            setupRealtimeSubscription();
          }, 5000);
        }
      });
  }

  function playNotificationSound(orderNumber?: string, totalQuantity?: number) {
    // Play Google TTS announcement for new order (loud)
    const ttsApiKey = import.meta.env.VITE_GOOGLE_TTS_API_KEY;
    
    if (ttsApiKey && orderNumber) {
      const shortNum = orderNumber.replace('ORD-', '').replace(/-/g, ' ');
      const qty = totalQuantity || 0;
      
      // English: "Fresh Order Alert! Delivery Team, Get Ready. Order number 20260219 0010, 3 items."
      const textEn = `Fresh Order Alert! Delivery Team, Get Ready. Order number ${shortNum}, ${qty} ${qty === 1 ? 'item' : 'items'}.`;
      // Arabic: "تنبيه طلب جديد! فريق التوصيل، استعدوا. طلب رقم ... ، ٣ منتجات."
      const textAr = `تنبيه طلب جديد! فريق التوصيل، استعدوا. طلب رقم ${shortNum}، ${qty} ${qty === 1 ? 'منتج' : 'منتجات'}.`;
      
      // Play English first, then Arabic
      playTTS(textEn, 'en-US', 'en-US-Standard-D', ttsApiKey, 1.0)
        .then(() => playTTS(textAr, 'ar-XA', 'ar-XA-Standard-A', ttsApiKey, 1.0))
        .catch(() => {
          playFallbackSound();
        });
    } else {
      playFallbackSound();
    }
  }

  async function playTTS(text: string, langCode: string, voiceName: string, apiKey: string, volume: number = 1.0) {
    const response = await fetch(`https://texttospeech.googleapis.com/v1/text:synthesize?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        input: { text },
        voice: { languageCode: langCode, name: voiceName },
        audioConfig: { 
          audioEncoding: 'MP3',
          speakingRate: 1.0,
          volumeGainDb: 10.0
        }
      })
    });

    if (!response.ok) throw new Error('TTS API error');
    
    const data = await response.json();
    if (!data.audioContent) throw new Error('No audio content');
    
    const audioSrc = `data:audio/mp3;base64,${data.audioContent}`;
    const audio = new Audio(audioSrc);
    audio.volume = volume;
    
    return new Promise<void>((resolve, reject) => {
      audio.onended = () => resolve();
      audio.onerror = () => reject(new Error('Audio playback failed'));
      audio.play().catch(reject);
    });
  }

  function playFallbackSound() {
    try {
      const audio = new Audio('/sounds/notification.mp3');
      audio.volume = 1.0;
      audio.play().catch(() => {});
    } catch {}
  }

  function filterOrders() {
    filteredOrders = orders.filter(order => {
      // Tab-based status filtering
      switch (activeTab) {
        case 'in_process':
          if (!['new', 'accepted', 'in_picking', 'ready', 'out_for_delivery'].includes(order.order_status)) return false;
          break;
        case 'completed':
          if (!['delivered', 'picked_up'].includes(order.order_status)) return false;
          break;
        case 'deliveries':
          if (!['out_for_delivery', 'delivered'].includes(order.order_status)) return false;
          if (order.delivery_type !== 'delivery') return false;
          break;
        case 'incomplete_tasks':
          // Orders that have picker assigned but not yet completed
          if (!['accepted', 'in_picking', 'ready'].includes(order.order_status)) return false;
          if (!order.picker_id) return false;
          break;
        case 'completed_tasks':
          // Orders that had tasks completed (ready or delivered with picker)
          if (!['ready', 'out_for_delivery', 'delivered', 'picked_up'].includes(order.order_status)) return false;
          break;
        case 'cancelled':
          if (order.order_status !== 'cancelled') return false;
          break;
        case 'rejected':
          if (order.order_status !== 'rejected') return false;
          break;
        case 'delivery_receivers':
          return false; // This tab doesn't show orders
      }

      // Branch filter
      if (branchFilter !== 'all' && order.branch_id !== branchFilter) return false;

      // Payment method filter
      if (paymentMethodFilter !== 'all' && order.payment_method !== paymentMethodFilter) return false;

      // Search term
      if (searchTerm) {
        const term = searchTerm.toLowerCase();
        const matchesOrderNumber = order.order_number?.toLowerCase().includes(term);
        const matchesCustomer = order.customer_name?.toLowerCase().includes(term);
        const matchesPhone = order.customer_phone?.toLowerCase().includes(term);
        if (!matchesOrderNumber && !matchesCustomer && !matchesPhone) return false;
      }

      // Date range
      if (dateFrom && new Date(order.created_at) < new Date(dateFrom)) return false;
      if (dateTo && new Date(order.created_at) > new Date(dateTo)) return false;

      return true;
    });
  }

  function clearFilters() {
    branchFilter = 'all';
    paymentMethodFilter = 'all';
    searchTerm = '';
    dateFrom = '';
    dateTo = '';
    filterOrders();
  }

  function selectOrder(order: any) {
    openWindow({
      title: `${isRTL ? 'طلب' : 'Order'} ${order.order_number}`,
      component: OrderDetailWindow,
      props: {
        orderId: order.id,
        orderNumber: order.order_number
      },
      size: { width: 800, height: 600 },
      icon: '📦'
    });
  }

  // ===== DEFAULT DELIVERY RECEIVERS =====
  async function loadDeliveryReceivers() {
    loadingReceivers = true;
    try {
      const { data, error } = await supabase
        .from('branch_default_delivery_receivers')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false });

      if (error) throw error;

      // Enrich with branch and user names
      const branchIds = new Set(data?.map(r => r.branch_id).filter(Boolean) || []);
      const userIds = new Set(data?.map(r => r.user_id).filter(Boolean) || []);

      const [brResult, usResult] = await Promise.all([
        branchIds.size > 0
          ? supabase.from('branches').select('id, name_en, name_ar').in('id', Array.from(branchIds))
          : Promise.resolve({ data: [] }),
        userIds.size > 0
          ? supabase.from('users').select('id, username').in('id', Array.from(userIds))
          : Promise.resolve({ data: [] })
      ]);

      const brMap = new Map((brResult.data || []).map((b: any) => [b.id, b]));
      const usMap = new Map((usResult.data || []).map((u: any) => [u.id, u]));

      deliveryReceivers = (data || []).map(r => ({
        ...r,
        branch_name: brMap.get(r.branch_id)?.[isRTL ? 'name_ar' : 'name_en'] || `Branch ${r.branch_id}`,
        user_name: usMap.get(r.user_id)?.username || 'Unknown'
      }));
    } catch (error) {
      console.error('Error loading delivery receivers:', error);
    } finally {
      loadingReceivers = false;
    }
  }

  async function loadAllUsers() {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('id, username')
        .order('username');

      if (error) throw error;
      allUsers = data || [];
    } catch (error) {
      console.error('Error loading users:', error);
    }
  }

  async function addDeliveryReceiver() {
    if (!selectedBranchForReceivers || !selectedUserForReceiver) {
      notifications.add({
        message: isRTL ? 'يرجى اختيار الفرع والمستخدم' : 'Please select branch and user',
        type: 'warning'
      });
      return;
    }

    savingReceiver = true;
    try {
      const { error } = await supabase
        .from('branch_default_delivery_receivers')
        .insert({
          branch_id: Number(selectedBranchForReceivers),
          user_id: selectedUserForReceiver,
          is_active: true,
          created_by: $currentUser?.id || null
        });

      if (error) {
        if (error.code === '23505') {
          notifications.add({
            message: isRTL ? 'هذا المستخدم مضاف بالفعل لهذا الفرع' : 'This user is already assigned to this branch',
            type: 'warning'
          });
          return;
        }
        throw error;
      }

      notifications.add({
        message: isRTL ? 'تم إضافة مستلم التوصيل بنجاح' : 'Delivery receiver added successfully',
        type: 'success'
      });

      selectedUserForReceiver = '';
      await loadDeliveryReceivers();
    } catch (error: any) {
      console.error('Error adding delivery receiver:', error);
      notifications.add({
        message: isRTL ? `خطأ: ${error.message}` : `Error: ${error.message}`,
        type: 'error'
      });
    } finally {
      savingReceiver = false;
    }
  }

  async function removeDeliveryReceiver(id: string) {
    try {
      const { error } = await supabase
        .from('branch_default_delivery_receivers')
        .update({ is_active: false })
        .eq('id', id);

      if (error) throw error;

      notifications.add({
        message: isRTL ? 'تم إزالة مستلم التوصيل' : 'Delivery receiver removed',
        type: 'success'
      });

      await loadDeliveryReceivers();
    } catch (error: any) {
      console.error('Error removing delivery receiver:', error);
      notifications.add({
        message: isRTL ? `خطأ: ${error.message}` : `Error: ${error.message}`,
        type: 'error'
      });
    }
  }

  function setupReceiversRealtime() {
    if (receiversChannel) return;
    receiversChannel = supabase
      .channel('delivery_receivers_realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'branch_default_delivery_receivers' }, () => {
        loadDeliveryReceivers();
      })
      .subscribe();
  }

  // Get receivers grouped by branch for display
  $: receiversByBranch = deliveryReceivers.reduce((acc: Record<string, any[]>, r: any) => {
    const key = r.branch_id;
    if (!acc[key]) acc[key] = [];
    acc[key].push(r);
    return acc;
  }, {});

  // Computed entries for template iteration
  $: receiversEntries = Object.entries(receiversByBranch) as [string, any[]][];

  // Tab counts for badges
  $: inProcessCount = orders.filter(o => ['new', 'accepted', 'in_picking', 'ready', 'out_for_delivery'].includes(o.order_status)).length;
  $: completedCount = orders.filter(o => ['delivered', 'picked_up'].includes(o.order_status)).length;
  $: deliveriesCount = orders.filter(o => ['out_for_delivery', 'delivered'].includes(o.order_status) && o.delivery_type === 'delivery').length;
  $: incompleteTasksCount = orders.filter(o => ['accepted', 'in_picking', 'ready'].includes(o.order_status) && o.picker_id).length;
  $: completedTasksCount = orders.filter(o => ['ready', 'out_for_delivery', 'delivered', 'picked_up'].includes(o.order_status)).length;
  $: cancelledCount = orders.filter(o => o.order_status === 'cancelled').length;
  $: rejectedCount = orders.filter(o => o.order_status === 'rejected').length;

  $: tabCounts = {
    in_process: inProcessCount,
    completed: completedCount,
    deliveries: deliveriesCount,
    incomplete_tasks: incompleteTasksCount,
    completed_tasks: completedTasksCount,
    cancelled: cancelledCount,
    rejected: rejectedCount,
    delivery_receivers: deliveryReceivers.length
  } as Record<string, number>;

  // Apply filters when tab or data changes
  $: if (activeTab && orders.length >= 0) {
    if (activeTab !== 'delivery_receivers') {
      filterOrders();
    }
  }
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={isRTL ? 'rtl' : 'ltr'}>
  <!-- Tab Navigation - ShiftAndDayOff Style -->
  <div class="bg-white border-b border-slate-200 px-4 py-3 shadow-sm">
    <div class="flex items-center gap-3 mb-3">
      <div class="bg-blue-100 p-2.5 rounded-lg">
        <svg class="w-7 h-7 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/>
        </svg>
      </div>
      <div class="flex-1">
        <h1 class="text-xl font-bold text-gray-800">{isRTL ? '🛒 إدارة الطلبات' : '🛒 Orders Manager'}</h1>
        <p class="text-xs text-gray-500">{isRTL ? 'نظام إدارة طلبات العملاء' : 'Customer Order Management System'}</p>
      </div>
    </div>

    <div class="flex gap-1.5 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner overflow-x-auto">
      {#each tabs as tab}
        <button 
          class="group relative flex items-center gap-2 px-4 py-2 text-[11px] font-black uppercase tracking-wide transition-all duration-500 rounded-xl overflow-hidden whitespace-nowrap
          {activeTab === tab.id 
            ? tabColorMap[tab.color] || 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]'
            : 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
          on:click={() => {
            activeTab = tab.id;
            handleTabChange();
          }}
        >
          <span class="text-sm filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
          <span class="relative z-10">{tab.label}</span>
          {#if tabCounts[tab.id] > 0}
            <span class="min-w-[20px] h-5 flex items-center justify-center px-1.5 rounded-full text-[10px] font-bold
              {activeTab === tab.id ? 'bg-white/30 text-white' : 'bg-slate-200 text-slate-600'}">
              {tabCounts[tab.id]}
            </span>
          {/if}
          {#if activeTab === tab.id}
            <div class="absolute inset-0 bg-white/10 animate-pulse"></div>
          {/if}
        </button>
      {/each}
    </div>
  </div>

  <!-- Main Content -->
  <div class="flex-1 overflow-y-auto p-4">
    {#if activeTab === 'print_settings'}
      <!-- ===== PRINT SETTINGS TAB ===== -->
      <div class="max-w-5xl mx-auto">
        <div class="bg-white rounded-2xl border border-slate-200 shadow-sm p-6 mb-6">
          <h2 class="text-lg font-bold text-gray-800 mb-1 flex items-center gap-2">
            <span>🖨️</span>
            {isRTL ? 'إعدادات الطباعة' : 'Print Settings'}
          </h2>
          <p class="text-sm text-gray-500 mb-6">
            {isRTL ? 'اختر حجم الورق والطابعة لطباعة الطلبات والإيصالات' : 'Select paper size and printer for printing orders and receipts'}
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- A4 Printer Card -->
            <div class="p-6 bg-gradient-to-b from-indigo-50 to-white rounded-xl border-2 border-indigo-200 shadow-sm flex flex-col items-center text-center">
              <div class="w-20 h-24 bg-white border-2 border-indigo-300 rounded-lg flex items-center justify-center shadow-sm mb-4">
                <svg class="w-10 h-10 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
              <h3 class="text-xl font-bold text-indigo-800 mb-1">{isRTL ? 'طابعة A4' : 'A4 Printer'}</h3>
              <p class="text-xs text-indigo-400 mb-4">210 × 297 mm</p>
              {#if selectedA4Printer}
                <div class="w-full flex items-center gap-2 mb-4 px-4 py-2.5 bg-green-50 rounded-lg border border-green-200">
                  <span class="text-green-600 text-sm">✅</span>
                  <span class="text-sm font-semibold text-green-800 truncate flex-1">{selectedA4Printer}</span>
                  <button on:click={() => selectedA4Printer = ''} title="Clear" class="p-1 text-green-400 hover:text-red-500 rounded transition flex-shrink-0">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
                  </button>
                </div>
              {/if}
              <button
                on:click={() => printTestPage('A4')}
                class="w-full flex items-center justify-center gap-2 px-4 py-3.5 bg-indigo-600 text-white rounded-xl font-bold text-base hover:bg-indigo-700 active:scale-[0.98] transition-all shadow-md shadow-indigo-200"
              >
                🖨️ {isRTL ? 'طباعة تجريبية' : 'Test Print'}
              </button>
              <p class="text-[11px] text-indigo-400 mt-3 leading-relaxed">
                {isRTL ? 'سيتم فتح صفحة اختبار — اختر طابعة A4 من القائمة' : 'Opens a test page — pick your A4 printer from the system dialog'}
              </p>
            </div>

            <!-- 80mm Thermal Printer Card -->
            <div class="p-6 bg-gradient-to-b from-amber-50 to-white rounded-xl border-2 border-amber-200 shadow-sm flex flex-col items-center text-center">
              <div class="w-20 h-24 bg-white border-2 border-amber-300 rounded-lg flex items-center justify-center shadow-sm mb-4">
                <svg class="w-10 h-10 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                </svg>
              </div>
              <h3 class="text-xl font-bold text-amber-800 mb-1">{isRTL ? 'طابعة حرارية 80مم' : '80mm Thermal'}</h3>
              <p class="text-xs text-amber-400 mb-4">{isRTL ? 'إيصالات حرارية' : 'Thermal Receipts'}</p>
              {#if selectedThermalPrinter}
                <div class="w-full flex items-center gap-2 mb-4 px-4 py-2.5 bg-green-50 rounded-lg border border-green-200">
                  <span class="text-green-600 text-sm">✅</span>
                  <span class="text-sm font-semibold text-green-800 truncate flex-1">{selectedThermalPrinter}</span>
                  <button on:click={() => selectedThermalPrinter = ''} title="Clear" class="p-1 text-green-400 hover:text-red-500 rounded transition flex-shrink-0">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
                  </button>
                </div>
              {/if}
              <button
                on:click={() => printTestPage('80mm')}
                class="w-full flex items-center justify-center gap-2 px-4 py-3.5 bg-amber-600 text-white rounded-xl font-bold text-base hover:bg-amber-700 active:scale-[0.98] transition-all shadow-md shadow-amber-200"
              >
                🖨️ {isRTL ? 'طباعة تجريبية' : 'Test Print'}
              </button>
              <p class="text-[11px] text-amber-400 mt-3 leading-relaxed">
                {isRTL ? 'سيتم فتح صفحة اختبار — اختر الطابعة الحرارية من القائمة' : 'Opens a test page — pick your thermal printer from the system dialog'}
              </p>
            </div>
          </div>

          <!-- Auto Print Toggle -->
          <div class="mt-6 p-5 rounded-xl border-2 transition-all {autoPrintNewOrders ? 'bg-green-50 border-green-300' : 'bg-slate-50 border-slate-200'}">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <span class="text-2xl">{autoPrintNewOrders ? '🟢' : '⚪'}</span>
                <div>
                  <h3 class="text-sm font-bold {autoPrintNewOrders ? 'text-green-800' : 'text-slate-700'}">
                    {isRTL ? 'طباعة تلقائية للطلبات الجديدة' : 'Auto-Print New Orders'}
                  </h3>
                  <p class="text-xs {autoPrintNewOrders ? 'text-green-600' : 'text-slate-400'}">
                    {isRTL ? 'سيتم طباعة كل طلب جديد تلقائياً عند وصوله' : 'Every new order will be printed automatically when it arrives'}
                  </p>
                </div>
              </div>
              <!-- svelte-ignore a11y_consider_explicit_label -->
              <button 
                on:click={() => autoPrintNewOrders = !autoPrintNewOrders}
                class="relative w-14 h-8 rounded-full transition-all duration-300 {autoPrintNewOrders ? 'bg-green-500' : 'bg-slate-300'}"
              >
                <div class="absolute top-1 w-6 h-6 bg-white rounded-full shadow-md transition-all duration-300 {autoPrintNewOrders ? 'left-7' : 'left-1'}"></div>
              </button>
            </div>
            {#if autoPrintNewOrders && !selectedA4Printer}
              <p class="mt-3 text-xs text-amber-600 bg-amber-50 px-3 py-2 rounded-lg border border-amber-200">
                ⚠️ {isRTL ? 'يرجى اختبار الطابعة أولاً لتحديد اسمها' : 'Please test print first to set your printer name'}
              </p>
            {/if}
          </div>

          <!-- Saved Configuration Summary -->
          {#if selectedA4Printer || selectedThermalPrinter}
            <div class="mt-4 p-4 bg-blue-50 rounded-xl border border-blue-200">
              <h3 class="text-sm font-bold text-blue-700 mb-2 flex items-center gap-2">
                💾 {isRTL ? 'الإعدادات المحفوظة' : 'Saved Configuration'}
                <span class="text-[10px] font-normal text-blue-400">({isRTL ? 'محفوظ محلياً' : 'stored locally'})</span>
              </h3>
              <div class="flex flex-wrap gap-3">
                {#if selectedA4Printer}
                  <span class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-indigo-100 text-indigo-800 rounded-full text-xs font-bold border border-indigo-200">
                    📄 A4: {selectedA4Printer}
                  </span>
                {/if}
                {#if selectedThermalPrinter}
                  <span class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-amber-100 text-amber-800 rounded-full text-xs font-bold border border-amber-200">
                    🧾 80mm: {selectedThermalPrinter}
                  </span>
                {/if}
                {#if autoPrintNewOrders}
                  <span class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-green-100 text-green-800 rounded-full text-xs font-bold border border-green-200">
                    🟢 {isRTL ? 'طباعة تلقائية مفعّلة' : 'Auto-Print ON'}
                  </span>
                {/if}
              </div>
            </div>
          {/if}

          <!-- How it works -->
          <div class="mt-4 p-4 bg-slate-50 rounded-xl border border-slate-200">
            <h3 class="text-sm font-bold text-slate-600 mb-2">{isRTL ? 'كيف يعمل؟' : 'How it works?'}</h3>
            <div class="flex flex-col gap-2 text-xs text-slate-500">
              <p>1️⃣ {isRTL ? 'اضغط "طباعة تجريبية" لفتح صفحة الاختبار' : 'Click "Test Print" to open a test page'}</p>
              <p>2️⃣ {isRTL ? 'اضغط زر الطباعة واختر الطابعة من قائمة النظام' : 'Click Print and choose your printer from the system dialog'}</p>
              <p>3️⃣ {isRTL ? 'اكتب اسم الطابعة لحفظه' : 'Type the printer name to save it'}</p>
              <p>4️⃣ {isRTL ? 'فعّل "الطباعة التلقائية" لطباعة الطلبات الجديدة تلقائياً' : 'Enable "Auto-Print" to print new orders automatically'}</p>
            </div>
          </div>
        </div>
      </div>
    {:else if activeTab === 'delivery_receivers'}
      <!-- ===== DEFAULT DELIVERY RECEIVERS TAB ===== -->
      <div class="max-w-5xl mx-auto">
        <div class="bg-white rounded-2xl border border-slate-200 shadow-sm p-6 mb-6">
          <h2 class="text-lg font-bold text-gray-800 mb-1 flex items-center gap-2">
            <span>👷</span>
            {isRTL ? 'إعداد مستلمي التوصيل الافتراضيين' : 'Default Delivery Receivers Setup'}
          </h2>
          <p class="text-sm text-gray-500 mb-6">
            {isRTL ? 'حدد موظفي التوصيل لكل فرع. الطلبات ستذهب فقط إلى هؤلاء الموظفين' : 'Assign delivery staff per branch. Orders will only go to these users.'}
          </p>

          <!-- Add new receiver form -->
          <div class="flex flex-wrap gap-3 items-end mb-6 p-4 bg-slate-50 rounded-xl border border-slate-200">
            <div class="flex-1 min-w-[200px]">
              <!-- svelte-ignore a11y_label_has_associated_control -->
              <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">
                {isRTL ? 'الفرع' : 'Branch'}
              </label>
              <select bind:value={selectedBranchForReceivers} class="w-full px-3 py-2.5 border border-slate-300 rounded-lg text-sm focus:border-purple-500 focus:ring-2 focus:ring-purple-200 outline-none transition">
                <option value="">{isRTL ? 'اختر الفرع...' : 'Select Branch...'}</option>
                {#each branches as branch}
                  <option value={branch.id}>{isRTL ? branch.name_ar : branch.name_en}</option>
                {/each}
              </select>
            </div>

            <div class="flex-1 min-w-[200px]">
              <!-- svelte-ignore a11y_label_has_associated_control -->
              <label class="block text-xs font-bold text-slate-600 mb-1.5 uppercase tracking-wide">
                {isRTL ? 'موظف التوصيل' : 'Delivery Person'}
              </label>
              <select bind:value={selectedUserForReceiver} class="w-full px-3 py-2.5 border border-slate-300 rounded-lg text-sm focus:border-purple-500 focus:ring-2 focus:ring-purple-200 outline-none transition">
                <option value="">{isRTL ? 'اختر الموظف...' : 'Select User...'}</option>
                {#each allUsers as user}
                  <option value={user.id}>{user.username}</option>
                {/each}
              </select>
            </div>

            <button 
              on:click={addDeliveryReceiver}
              disabled={savingReceiver || !selectedBranchForReceivers || !selectedUserForReceiver}
              class="px-6 py-2.5 bg-purple-600 text-white rounded-lg font-semibold text-sm hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition flex items-center gap-2"
            >
              {#if savingReceiver}
                <div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
              {:else}
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
              {/if}
              {isRTL ? 'إضافة' : 'Add'}
            </button>
          </div>

          <!-- Receivers list grouped by branch -->
          {#if loadingReceivers}
            <div class="flex items-center justify-center py-12">
              <div class="w-10 h-10 border-4 border-purple-200 border-t-purple-600 rounded-full animate-spin"></div>
            </div>
          {:else if deliveryReceivers.length === 0}
            <div class="text-center py-12 text-gray-400">
              <div class="text-4xl mb-3">📭</div>
              <p class="font-semibold">{isRTL ? 'لا يوجد مستلمي توصيل' : 'No delivery receivers configured'}</p>
              <p class="text-sm mt-1">{isRTL ? 'أضف مستلمين لكل فرع أعلاه' : 'Add receivers per branch above'}</p>
            </div>
          {:else}
            <div class="space-y-4">
              {#each receiversEntries as [branchId, receivers] (branchId)}
                <div class="border border-slate-200 rounded-xl overflow-hidden">
                  <div class="bg-gradient-to-r from-purple-50 to-slate-50 px-4 py-3 border-b border-slate-200">
                    <h3 class="font-bold text-purple-800 flex items-center gap-2">
                      <span>🏢</span>
                      {receivers[0].branch_name}
                      <span class="bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full text-xs font-bold">{receivers.length}</span>
                    </h3>
                  </div>
                  <div class="divide-y divide-slate-100">
                    {#each receivers as receiver}
                      <div class="flex items-center justify-between px-4 py-3 hover:bg-slate-50 transition">
                        <div class="flex items-center gap-3">
                          <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center">
                            <span class="text-purple-600 font-bold text-sm">{receiver.user_name?.charAt(0)?.toUpperCase() || '?'}</span>
                          </div>
                          <div>
                            <p class="font-semibold text-gray-800 text-sm">{receiver.user_name}</p>
                            <p class="text-xs text-gray-400">{isRTL ? 'أضيف' : 'Added'}: {new Date(receiver.created_at).toLocaleDateString()}</p>
                          </div>
                        </div>
                        <button 
                          on:click={() => removeDeliveryReceiver(receiver.id)}
                          class="p-2 text-red-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition"
                          title={isRTL ? 'إزالة' : 'Remove'}
                        >
                          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                          </svg>
                        </button>
                      </div>
                    {/each}
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </div>
      </div>

    {:else}
      <!-- ===== ORDERS TABS (all tabs except delivery_receivers) ===== -->
      
      <!-- Stats Cards -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
        <div class="flex items-center gap-3 p-4 bg-white rounded-xl border-2 border-blue-200">
          <div class="p-2.5 bg-blue-500 rounded-lg">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
          </div>
          <div>
            <div class="text-2xl font-bold text-gray-800">{stats.newOrders}</div>
            <div class="text-xs text-gray-500">{isRTL ? 'طلبات جديدة' : 'New Orders'}</div>
          </div>
        </div>
        <div class="flex items-center gap-3 p-4 bg-white rounded-xl border-2 border-orange-200">
          <div class="p-2.5 bg-orange-500 rounded-lg">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
          </div>
          <div>
            <div class="text-2xl font-bold text-gray-800">{stats.inProgress}</div>
            <div class="text-xs text-gray-500">{isRTL ? 'قيد التنفيذ' : 'In Progress'}</div>
          </div>
        </div>
        <div class="flex items-center gap-3 p-4 bg-white rounded-xl border-2 border-green-200">
          <div class="p-2.5 bg-green-500 rounded-lg">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
          </div>
          <div>
            <div class="text-2xl font-bold text-gray-800">{stats.completedToday}</div>
            <div class="text-xs text-gray-500">{isRTL ? 'مكتملة اليوم' : 'Completed Today'}</div>
          </div>
        </div>
        <div class="flex items-center gap-3 p-4 bg-white rounded-xl border-2 border-purple-200">
          <div class="p-2.5 bg-purple-500 rounded-lg">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </div>
          <div>
            <div class="text-2xl font-bold text-gray-800">{stats.totalRevenueToday.toFixed(0)} {isRTL ? 'ر.س' : 'SAR'}</div>
            <div class="text-xs text-gray-500">{isRTL ? 'إيرادات اليوم' : 'Revenue Today'}</div>
          </div>
        </div>
      </div>

      <!-- Filters Bar -->
      <div class="flex flex-wrap gap-3 mb-4 p-3 bg-white rounded-xl border border-slate-200">
        <div class="flex-1 min-w-[150px]">
          <!-- svelte-ignore a11y_label_has_associated_control -->
          <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">{isRTL ? 'بحث' : 'Search'}</label>
          <input
            type="text"
            bind:value={searchTerm}
            placeholder={isRTL ? 'رقم الطلب، العميل، الهاتف' : 'Order #, Customer, Phone'}
            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition"
          />
        </div>

        <div class="min-w-[130px]">
          <!-- svelte-ignore a11y_label_has_associated_control -->
          <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">{isRTL ? 'الفرع' : 'Branch'}</label>
          <select bind:value={branchFilter} class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition">
            <option value="all">{isRTL ? 'كل الفروع' : 'All Branches'}</option>
            {#each branches as branch}
              <option value={branch.id}>{isRTL ? branch.name_ar : branch.name_en}</option>
            {/each}
          </select>
        </div>

        <div class="min-w-[120px]">
          <!-- svelte-ignore a11y_label_has_associated_control -->
          <label class="block text-[10px] font-bold text-slate-500 uppercase mb-1">{isRTL ? 'الدفع' : 'Payment'}</label>
          <select bind:value={paymentMethodFilter} class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none transition">
            <option value="all">{isRTL ? 'الكل' : 'All'}</option>
            <option value="cash">{isRTL ? 'نقدي' : 'Cash'}</option>
            <option value="card">{isRTL ? 'بطاقة' : 'Card'}</option>
            <option value="online">{isRTL ? 'إلكتروني' : 'Online'}</option>
          </select>
        </div>

        <button on:click={clearFilters} class="self-end px-4 py-2 bg-red-500 text-white rounded-lg text-sm font-semibold hover:bg-red-600 transition flex items-center gap-1.5">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
          {isRTL ? 'مسح' : 'Clear'}
        </button>
      </div>

      <!-- Orders Table -->
      <div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
        {#if loading}
          <div class="flex flex-col items-center justify-center py-16">
            <div class="w-10 h-10 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
            <p class="mt-4 text-slate-500 font-semibold text-sm">{isRTL ? 'جاري التحميل...' : 'Loading...'}</p>
          </div>
        {:else if filteredOrders.length === 0}
          <div class="flex flex-col items-center justify-center py-16 text-center">
            <div class="text-5xl mb-3">📭</div>
            <h3 class="text-lg font-bold text-gray-700">{isRTL ? 'لا توجد طلبات' : 'No Orders Found'}</h3>
            <p class="text-sm text-gray-400 mt-1">{isRTL ? 'لا توجد طلبات تطابق هذا التصنيف' : 'No orders match this filter'}</p>
          </div>
        {:else}
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-slate-50 border-b-2 border-slate-200">
                <tr>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'رقم الطلب' : 'Order #'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'العميل' : 'Customer'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'التاريخ' : 'Date'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'الفرع' : 'Branch'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'المبلغ' : 'Total'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'الدفع' : 'Payment'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'الحالة' : 'Status'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'المحضّر' : 'Picker'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'التوصيل' : 'Delivery'}</th>
                  <th class="px-4 py-3 text-left text-[11px] font-bold text-slate-500 uppercase">{isRTL ? 'إجراءات' : 'Actions'}</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                {#each filteredOrders as order}
                  <tr on:click={() => selectOrder(order)} class="cursor-pointer hover:bg-blue-50/50 transition">
                    <td class="px-4 py-3 font-semibold text-blue-600 text-sm">{order.order_number}</td>
                    <td class="px-4 py-3">
                      <div class="text-sm font-medium text-gray-800">{order.customer_name}</div>
                      <div class="text-xs text-gray-400">{order.customer_phone}</div>
                    </td>
                    <td class="px-4 py-3 text-sm text-gray-600">{new Date(order.created_at).toLocaleString()}</td>
                    <td class="px-4 py-3 text-sm text-gray-600">{order.branch_name}</td>
                    <td class="px-4 py-3 text-sm font-semibold text-gray-800">{order.total_amount} {isRTL ? 'ر.س' : 'SAR'}</td>
                    <td class="px-4 py-3 text-sm text-gray-600">{order.payment_method}</td>
                    <td class="px-4 py-3">
                      <span class="inline-block px-3 py-1 rounded-full text-xs font-bold text-white {statusColors[order.order_status] || 'bg-gray-400'}">
                        {statusLabels[order.order_status] || order.order_status}
                      </span>
                    </td>
                    <td class="px-4 py-3 text-sm text-gray-600">{order.picker_name || '-'}</td>
                    <td class="px-4 py-3 text-sm text-gray-600">{order.delivery_person_name || '-'}</td>
                    <td class="px-4 py-3">
                      <!-- svelte-ignore a11y_consider_explicit_label -->
                      <button class="p-2 bg-slate-100 hover:bg-slate-200 rounded-lg transition text-slate-600" title={isRTL ? 'عرض' : 'View'}>
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                        </svg>
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  /* Scrollbar for tab bar */
  :global(.overflow-x-auto::-webkit-scrollbar) {
    height: 4px;
  }
  :global(.overflow-x-auto::-webkit-scrollbar-track) {
    background: transparent;
  }
  :global(.overflow-x-auto::-webkit-scrollbar-thumb) {
    background: #cbd5e1;
    border-radius: 4px;
  }

  /* RTL support for table headers */
  [dir="rtl"] th {
    text-align: right !important;
  }
</style>



