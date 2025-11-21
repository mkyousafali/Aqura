<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { supabase, supabaseAdmin } from '$lib/utils/supabase'; // Use admin client for RLS bypass
  import { currentUser } from '$lib/utils/persistentAuth';
  import { notifications } from '$lib/stores/notifications';
  import { t, currentLocale } from '$lib/i18n';
  import { openWindow } from '$lib/utils/windowManagerUtils';
  import OrderDetailWindow from './OrderDetailWindow.svelte';
  
  // Reactive RTL check
  $: isRTL = $currentLocale === 'ar';

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
  let statusFilter = 'all';
  let branchFilter = 'all';
  let paymentMethodFilter = 'all';
  let searchTerm = '';
  let dateFrom = '';
  let dateTo = '';

  // Branches for filter
  let branches: any[] = [];

  // Real-time subscription
  let ordersChannel: any = null;

  // Status colors
  const statusColors: { [key: string]: string } = {
    new: 'bg-blue-500',
    accepted: 'bg-green-500',
    in_picking: 'bg-orange-500',
    ready: 'bg-purple-500',
    out_for_delivery: 'bg-teal-500',
    delivered: 'bg-green-700',
    cancelled: 'bg-red-600'
  };

  // Status labels - reactive based on locale
  $: statusLabels = {
    new: isRTL ? 'Ø¬Ø¯ÙŠØ¯' : 'New',
    accepted: isRTL ? 'Ù…Ù‚Ø¨ÙˆÙ„' : 'Accepted',
    in_picking: isRTL ? 'Ù‚ÙŠØ¯ Ø§Ù„ØªØ­Ø¶ÙŠØ±' : 'In Picking',
    ready: isRTL ? 'Ø¬Ø§Ù‡Ø²' : 'Ready',
    out_for_delivery: isRTL ? 'Ù‚ÙŠØ¯ Ø§Ù„ØªÙˆØµÙŠÙ„' : 'Out for Delivery',
    delivered: isRTL ? 'ØªÙ… Ø§Ù„ØªÙˆØµÙŠÙ„' : 'Delivered',
    cancelled: isRTL ? 'Ù…Ù„ØºÙŠ' : 'Cancelled'
  };

  onMount(async () => {
    await loadBranches();
    await loadOrders();
    await loadStatistics();
    setupRealtimeSubscription();
  });

  onDestroy(() => {
    if (ordersChannel) {
      supabaseAdmin.removeChannel(ordersChannel);
    }
  });

  async function loadBranches() {
    try {
      const { data, error } = await supabaseAdmin.from('branches')
        .select('id, name_ar, name_en')
        .order('name_ar');

      if (error) throw error;
      branches = data || [];
    } catch (error) {
      console.error('Error loading branches:', error);
    }
  }



  async function loadOrders() {
    loading = true;
    try {
      console.log('ðŸ“¦ Loading orders...');
      console.log('Current user:', $currentUser);
      
      const { data, error } = await supabaseAdmin.from('orders')
        .select(`
          *,
          branch:branches(name_en, name_ar),
          picker:users!picker_id(username),
          delivery_person:users!delivery_person_id(username)
        `)
        .order('created_at', { ascending: false });

      if (error) {
        console.error('âŒ Error loading orders:', error);
        console.error('Error code:', error.code);
        console.error('Error details:', error.details);
        console.error('Error hint:', error.hint);
        throw error;
      }

      console.log(`âœ… Loaded ${data?.length || 0} orders`);
      console.log('Orders data:', data);

      orders = (data || []).map(order => ({
        ...order,
        branch_name: order.branch?.name_en || 'Branch ' + order.branch_id,
        picker_name: order.picker?.username || null,
        delivery_person_name: order.delivery_person?.username || null
      }));

      filteredOrders = orders;
      console.log('ðŸ“‹ Filtered orders:', filteredOrders.length);
    } catch (error: any) {
      console.error('âŒ Caught error loading orders:', error);
      notifications.add({
        message: isRTL ? `ÙØ´Ù„ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø·Ù„Ø¨Ø§Øª: ${error.message}` : `Failed to load orders: ${error.message}`,
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

      // Count new orders
      const { count: newCount } = await supabaseAdmin.from('orders')
        .select('*', { count: 'exact', head: true })
        .eq('order_status', 'new');

      // Count in-progress orders
      const { count: progressCount } = await supabaseAdmin.from('orders')
        .select('*', { count: 'exact', head: true })
        .in('order_status', ['accepted', 'in_picking', 'ready', 'out_for_delivery']);

      // Count completed today
      const { count: completedCount } = await supabaseAdmin.from('orders')
        .select('*', { count: 'exact', head: true })
        .eq('order_status', 'delivered')
        .gte('updated_at', today.toISOString());

      // Calculate revenue today
      const { data: revenueData } = await supabaseAdmin.from('orders')
        .select('total_amount')
        .eq('order_status', 'delivered')
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
    console.log('📡 Setting up realtime subscription for orders...');
    ordersChannel = supabaseAdmin
      .channel('orders_changes')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'orders'
      }, payload => {
        console.log('Order change detected:', payload);
        loadOrders();
        loadStatistics();
        
        // Play notification sound for new orders
        if (payload.eventType === 'INSERT') {
          playNotificationSound();
          notifications.add({
            message: isRTL ? `Ø·Ù„Ø¨ Ø¬Ø¯ÙŠØ¯: ${payload.new.order_number}` : `New order: ${payload.new.order_number}`,
            type: 'info',
            duration: 5000
          });
        }
      })
      .subscribe();
  }

  function playNotificationSound() {
    try {
      const audio = new Audio('/sounds/notification.mp3');
      audio.volume = 0.5;
      audio.play().catch(err => console.log('Could not play sound:', err));
    } catch (err) {
      console.log('Notification sound not available');
    }
  }

  function filterOrders() {
    filteredOrders = orders.filter(order => {
      // Status filter
      if (statusFilter !== 'all' && order.order_status !== statusFilter) {
        return false;
      }

      // Branch filter
      if (branchFilter !== 'all' && order.branch_id !== branchFilter) {
        return false;
      }

      // Payment method filter
      if (paymentMethodFilter !== 'all' && order.payment_method !== paymentMethodFilter) {
        return false;
      }

      // Search term
      if (searchTerm) {
        const term = searchTerm.toLowerCase();
        const matchesOrderNumber = order.order_number?.toLowerCase().includes(term);
        const matchesCustomer = order.customer_name?.toLowerCase().includes(term);
        const matchesPhone = order.customer_phone?.toLowerCase().includes(term);
        
        if (!matchesOrderNumber && !matchesCustomer && !matchesPhone) {
          return false;
        }
      }

      // Date range
      if (dateFrom && new Date(order.created_at) < new Date(dateFrom)) {
        return false;
      }
      if (dateTo && new Date(order.created_at) > new Date(dateTo)) {
        return false;
      }

      return true;
    });
  }

  function clearFilters() {
    statusFilter = 'all';
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
      icon: '🛒'
    });
  }



  // Apply filters when they change
  $: if (orders.length > 0) {
    filterOrders();
  }
</script>

<div class="orders-manager" dir={isRTL ? 'rtl' : 'ltr'}>
  <!-- Header -->
  <div class="header">
    <div class="title-section">
      <div class="flex items-center space-x-3 mb-2">
        <div class="bg-blue-100 p-3 rounded-lg">
          <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/>
          </svg>
        </div>
        <div>
          <h1 class="title">{t('orders.manager.title', 'ðŸ›’ Orders Manager')}</h1>
          <p class="subtitle">{t('orders.manager.subtitle', 'Customer Order Management System')}</p>
        </div>
      </div>
    </div>
  </div>

  <!-- Stats Cards -->
  <div class="stats-grid">
    <div class="stat-card bg-blue-50 border-blue-200">
      <div class="stat-icon bg-blue-500">
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
      </div>
      <div class="stat-content">
        <div class="stat-value">{stats.newOrders}</div>
        <div class="stat-label">{t('orders.stats.new', 'New Orders')}</div>
      </div>
    </div>

    <div class="stat-card bg-orange-50 border-orange-200">
      <div class="stat-icon bg-orange-500">
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
        </svg>
      </div>
      <div class="stat-content">
        <div class="stat-value">{stats.inProgress}</div>
        <div class="stat-label">{t('orders.stats.inProgress', 'In Progress')}</div>
      </div>
    </div>

    <div class="stat-card bg-green-50 border-green-200">
      <div class="stat-icon bg-green-500">
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
        </svg>
      </div>
      <div class="stat-content">
        <div class="stat-value">{stats.completedToday}</div>
        <div class="stat-label">{t('orders.stats.completedToday', 'Completed Today')}</div>
      </div>
    </div>

    <div class="stat-card bg-purple-50 border-purple-200">
      <div class="stat-icon bg-purple-500">
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
      </div>
      <div class="stat-content">
        <div class="stat-value">{stats.totalRevenueToday.toFixed(0)} {t('common.sar', 'SAR')}</div>
        <div class="stat-label">{t('orders.stats.revenue', 'Total Revenue Today')}</div>
      </div>
    </div>
  </div>

  <!-- Filters Bar -->
  <div class="filters-bar">
    <div class="filter-group">
      <label>{t('orders.filters.search', 'Search')}</label>
      <input
        type="text"
        bind:value={searchTerm}
        placeholder={t('orders.filters.searchPlaceholder', 'Order #, Customer, Phone')}
        class="filter-input"
      />
    </div>

    <div class="filter-group">
      <label>{t('orders.filters.status', 'Status')}</label>
      <select bind:value={statusFilter} class="filter-select">
        <option value="all">{t('common.all', 'All')}</option>
        <option value="new">{statusLabels.new}</option>
        <option value="accepted">{statusLabels.accepted}</option>
        <option value="in_picking">{statusLabels.in_picking}</option>
        <option value="ready">{statusLabels.ready}</option>
        <option value="out_for_delivery">{statusLabels.out_for_delivery}</option>
        <option value="delivered">{statusLabels.delivered}</option>
        <option value="cancelled">{statusLabels.cancelled}</option>
      </select>
    </div>

    <div class="filter-group">
      <label>{t('orders.filters.branch', 'Branch')}</label>
      <select bind:value={branchFilter} class="filter-select">
        <option value="all">{t('common.all', 'All Branches')}</option>
        {#each branches as branch}
          <option value={branch.id}>
            {isRTL ? branch.name_ar : branch.name_en}
          </option>
        {/each}
      </select>
    </div>

    <div class="filter-group">
      <label>{t('orders.filters.payment', 'Payment')}</label>
      <select bind:value={paymentMethodFilter} class="filter-select">
        <option value="all">{t('common.all', 'All')}</option>
        <option value="cash">{t('orders.payment.cash', 'Cash')}</option>
        <option value="card">{t('orders.payment.card', 'Card')}</option>
        <option value="online">{t('orders.payment.online', 'Online')}</option>
      </select>
    </div>

    <button on:click={clearFilters} class="clear-filters-btn">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
      </svg>
      {t('orders.filters.clear', 'Clear')}
    </button>
  </div>

  <!-- Orders Table -->
  <div class="orders-table-container">
    {#if loading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>{t('common.loading', 'Loading...')}</p>
      </div>
    {:else if filteredOrders.length === 0}
      <div class="empty-state">
        <svg class="w-16 h-16 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/>
        </svg>
        <h3>{t('orders.empty.title', 'No Orders Found')}</h3>
        <p>{t('orders.empty.message', 'Orders will appear here once customers place them.')}</p>
        <p class="text-sm text-gray-500 mt-2">
          {t('orders.empty.pending', 'Database migration pending. Orders table will be created soon.')}
        </p>
      </div>
    {:else}
      <table class="orders-table">
        <thead>
          <tr>
            <th>{t('orders.table.orderNumber', 'Order #')}</th>
            <th>{t('orders.table.customer', 'Customer')}</th>
            <th>{t('orders.table.dateTime', 'Date & Time')}</th>
            <th>{t('orders.table.branch', 'Branch')}</th>
            <th>{t('orders.table.total', 'Total')}</th>
            <th>{t('orders.table.payment', 'Payment')}</th>
            <th>{t('orders.table.status', 'Status')}</th>
            <th>{t('orders.table.picker', 'Picker')}</th>
            <th>{t('orders.table.delivery', 'Delivery')}</th>
            <th>{t('orders.table.actions', 'Actions')}</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredOrders as order}
            <tr on:click={() => selectOrder(order)} class="cursor-pointer hover:bg-gray-50">
              <td class="font-medium text-blue-600">{order.order_number}</td>
              <td>
                <div>{order.customer_name}</div>
                <div class="text-sm text-gray-500">{order.customer_phone}</div>
              </td>
              <td>{new Date(order.created_at).toLocaleString()}</td>
              <td>{order.branch_name}</td>
              <td>{order.total_amount} {t('common.sar', 'SAR')}</td>
              <td>{order.payment_method}</td>
              <td>
                <span class="status-badge {statusColors[order.order_status]}">
                  {statusLabels[order.order_status]}
                </span>
              </td>
              <td>{order.picker_name || '-'}</td>
              <td>{order.delivery_person_name || '-'}</td>
              <td>
                <button class="action-btn">
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
    {/if}
  </div>
</div>

<style>
  .orders-manager {
    padding: 1.5rem;
    max-width: 100%;
    overflow-x: auto;
  }

  .header {
    margin-bottom: 2rem;
  }

  .title {
    font-size: 1.875rem;
    font-weight: 700;
    color: #1f2937;
    margin: 0;
  }

  .subtitle {
    font-size: 0.875rem;
    color: #6b7280;
    margin: 0;
  }

  /* Stats Grid */
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
  }

  .stat-card {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1.5rem;
    border-radius: 0.75rem;
    border: 2px solid;
    background: white;
  }

  .stat-icon {
    padding: 0.75rem;
    border-radius: 0.5rem;
  }

  .stat-value {
    font-size: 2rem;
    font-weight: 700;
    color: #1f2937;
  }

  .stat-label {
    font-size: 0.875rem;
    color: #6b7280;
  }

  /* Filters Bar */
  .filters-bar {
    display: flex;
    gap: 1rem;
    margin-bottom: 1.5rem;
    padding: 1rem;
    background: white;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
    flex-wrap: wrap;
  }

  .filter-group {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    min-width: 150px;
  }

  .filter-group label {
    font-size: 0.75rem;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
  }

  .filter-input,
  .filter-select {
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
  }

  .filter-input:focus,
  .filter-select:focus {
    outline: none;
    border-color: #3b82f6;
    ring: 2px;
    ring-color: #dbeafe;
  }

  .clear-filters-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    background: #ef4444;
    color: white;
    border: none;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    margin-top: auto;
  }

  .clear-filters-btn:hover {
    background: #dc2626;
  }

  /* Orders Table */
  .orders-table-container {
    background: white;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
    overflow: hidden;
  }

  .orders-table {
    width: 100%;
    border-collapse: collapse;
  }

  .orders-table thead {
    background: #f9fafb;
    border-bottom: 2px solid #e5e7eb;
  }

  .orders-table th {
    padding: 0.75rem 1rem;
    text-align: left;
    font-size: 0.75rem;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
  }

  .orders-table td {
    padding: 1rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .orders-table tbody tr:hover {
    background: #f9fafb;
  }

  .status-badge {
    display: inline-block;
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
    color: white;
  }

  .action-btn {
    padding: 0.5rem;
    background: #f3f4f6;
    border: none;
    border-radius: 0.375rem;
    cursor: pointer;
    color: #6b7280;
  }

  .action-btn:hover {
    background: #e5e7eb;
  }

  /* Loading & Empty States */
  .loading-state,
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem;
    text-align: center;
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 4px solid #e5e7eb;
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .empty-state h3 {
    font-size: 1.25rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 0.5rem;
  }

  .empty-state p {
    color: #6b7280;
  }

  /* Detail Panel Overlay */
  .detail-panel-overlay {
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
  }

  .detail-panel {
    background: white;
    border-radius: 0.75rem;
    width: 90%;
    max-width: 600px;
    max-height: 90vh;
    overflow-y: auto;
  }

  .panel-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .panel-header h2 {
    font-size: 1.5rem;
    font-weight: 700;
    margin: 0;
  }

  .close-btn {
    font-size: 2rem;
    background: none;
    border: none;
    cursor: pointer;
    color: #6b7280;
    padding: 0;
    width: 2rem;
    height: 2rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .close-btn:hover {
    color: #1f2937;
  }

  .panel-content {
    padding: 1.5rem;
  }

  /* Detail Panel Sections */
  .detail-section {
    margin-bottom: 1.5rem;
    padding-bottom: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .detail-section:last-child {
    border-bottom: none;
  }

  .section-title {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.125rem;
    font-weight: 600;
    color: #1f2937;
    margin-bottom: 1rem;
  }

  /* Customer Info Grid */
  .info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
  }

  .info-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .info-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
  }

  .info-value {
    font-size: 0.875rem;
    color: #1f2937;
  }

  .col-span-2 {
    grid-column: span 2;
  }

  /* Order Items List */
  .items-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .item-card {
    padding: 1rem;
    background: #f9fafb;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
  }

  /* Order Summary */
  .summary-list {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    padding: 0.5rem 0;
    font-size: 0.875rem;
  }

  .total-row {
    border-top: 2px solid #e5e7eb;
    padding-top: 1rem;
    margin-top: 0.5rem;
    color: #1f2937;
  }

  /* Timeline */
  .timeline {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .timeline-item {
    display: flex;
    gap: 1rem;
    position: relative;
  }

  .timeline-item::before {
    content: '';
    position: absolute;
    left: 0.5rem;
    top: 1.5rem;
    bottom: -1rem;
    width: 2px;
    background: #e5e7eb;
  }

  .timeline-item:last-child::before {
    display: none;
  }

  .timeline-dot {
    width: 1rem;
    height: 1rem;
    background: #3b82f6;
    border-radius: 50%;
    flex-shrink: 0;
    margin-top: 0.25rem;
  }

  .timeline-content {
    flex: 1;
  }

  /* Action Buttons */
  .action-buttons {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
  }

  .btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.625rem 1.25rem;
    border: none;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .btn-primary {
    background: #3b82f6;
    color: white;
  }

  .btn-primary:hover {
    background: #2563eb;
  }

  .btn-secondary {
    background: #6b7280;
    color: white;
  }

  .btn-secondary:hover {
    background: #4b5563;
  }

  .btn-danger {
    background: #ef4444;
    color: white;
  }

  .btn-danger:hover {
    background: #dc2626;
  }

  /* Assignment Dropdowns */
  .assignment-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
  }

  .assignment-item {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .assignment-label {
    font-size: 0.75rem;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
  }

  .assignment-dropdown-btn {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 0.625rem 1rem;
    background: white;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .assignment-dropdown-btn:hover:not(:disabled) {
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .assignment-dropdown-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
    background: #f3f4f6;
  }

  .assignment-dropdown-menu {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    margin-top: 0.25rem;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0.375rem;
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
    max-height: 300px;
    overflow-y: auto;
    z-index: 50;
  }

  .dropdown-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 0.75rem 1rem;
    text-align: left;
    font-size: 0.875rem;
    border: none;
    background: none;
    cursor: pointer;
    transition: background 0.2s;
  }

  .dropdown-item:hover {
    background: #f3f4f6;
  }

  .dropdown-item.selected {
    background: #dbeafe;
    color: #1e40af;
    font-weight: 600;
  }

  .dropdown-empty {
    padding: 1rem;
    text-align: center;
    color: #6b7280;
    font-size: 0.875rem;
  }

  .workload-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 1.5rem;
    height: 1.5rem;
    padding: 0 0.5rem;
    background: #fef3c7;
    color: #92400e;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .relative {
    position: relative;
  }

  /* Print Buttons */
  .print-buttons {
    display: flex;
    gap: 0.75rem;
    flex-wrap: wrap;
    padding: 1rem 0;
    border-top: 1px solid #e5e7eb;
    border-bottom: 1px solid #e5e7eb;
    margin: 1rem 0;
  }

  .print-buttons .btn {
    flex: 1;
    min-width: 150px;
  }

  /* Print Modal */
  .print-modal {
    position: relative;
    background: white;
    border-radius: 0.75rem;
    width: 90%;
    max-width: 800px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  }

  .print-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .print-header h3 {
    font-size: 1.25rem;
    font-weight: 600;
    margin: 0;
  }

  .print-content {
    flex: 1;
    overflow-y: auto;
    padding: 2rem;
  }

  .print-preview {
    display: flex;
    flex-direction: column;
    gap: 2rem;
  }

  .preview-notice {
    text-align: center;
    padding: 2rem;
    background: #f9fafb;
    border-radius: 0.5rem;
    border: 2px dashed #d1d5db;
  }

  .preview-notice .icon-large {
    width: 4rem;
    height: 4rem;
    margin: 0 auto 1rem;
    color: #9ca3af;
  }

  .preview-notice h4 {
    font-size: 1.125rem;
    font-weight: 600;
    margin: 0 0 0.5rem 0;
    color: #374151;
  }

  .preview-notice p {
    font-size: 0.875rem;
    color: #6b7280;
    margin: 0;
    max-width: 500px;
    margin: 0 auto;
  }

  .print-basic-info {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
    padding: 1.5rem;
  }

  .print-basic-info h4 {
    font-size: 1rem;
    font-weight: 600;
    margin: 0 0 1rem 0;
    color: #111827;
  }

  .info-row {
    display: flex;
    justify-content: space-between;
    padding: 0.75rem 0;
    border-bottom: 1px solid #f3f4f6;
  }

  .info-row:last-child {
    border-bottom: none;
  }

  .info-row .label {
    font-weight: 500;
    color: #6b7280;
  }

  .info-row .value {
    font-weight: 600;
    color: #111827;
  }

  .print-actions {
    display: flex;
    gap: 1rem;
    padding: 1.5rem;
    border-top: 1px solid #e5e7eb;
    justify-content: flex-end;
  }

  /* Responsive */
  @media (max-width: 768px) {
    .detail-panel {
      width: 100%;
      max-width: 100%;
      max-height: 100vh;
      border-radius: 0;
    }

    .info-grid {
      grid-template-columns: 1fr;
    }

    .assignment-grid {
      grid-template-columns: 1fr;
    }

    .action-buttons {
      flex-direction: column;
    }

    .btn {
      width: 100%;
      justify-content: center;
    }

    .print-buttons {
      flex-direction: column;
    }

    .print-buttons .btn {
      width: 100%;
    }

    .print-modal {
      width: 100%;
      max-width: 100%;
      max-height: 100vh;
      border-radius: 0;
    }

    .print-content {
      padding: 1rem;
    }

    .print-actions {
      flex-direction: column-reverse;
    }

    .print-actions .btn {
      width: 100%;
    }
  }
</style>



