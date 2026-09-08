<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  import { currentUser } from '$lib/utils/persistentAuth';
  import { notifications } from '$lib/stores/notifications';
  import { currentLocale } from '$lib/i18n';
  import { goto } from '$app/navigation';
  import { get } from 'svelte/store';

  $: isRTL = $currentLocale === 'ar';

  // State
  let orders: any[] = [];
  let filteredOrders: any[] = [];
  let branches: any[] = [];
  let users: any[] = [];
  let loading = true;
  let activeTab = 'new';
  let searchTerm = '';
  let selectedOrder: any = null;
  let showOrderDetail = false;
  let showPickerModal = false;
  let showDeliveryModal = false;
  let pickerSearch = '';
  let deliverySearch = '';
  let ordersChannel: any = null;

  // Filtered users for modals
  $: filteredPickerUsers = users.filter(u => !pickerSearch || u.username?.toLowerCase().includes(pickerSearch.toLowerCase()));
  $: filteredDeliveryUsers = users.filter(u => !deliverySearch || u.username?.toLowerCase().includes(deliverySearch.toLowerCase()));

  // Stats
  let stats = { newOrders: 0, inProgress: 0, completedToday: 0 };

  // Tabs
  $: tabs = [
    { id: 'new', label: isRTL ? 'جديدة' : 'New', icon: '🆕', color: '#3B82F6', count: 0 },
    { id: 'in_progress', label: isRTL ? 'قيد التنفيذ' : 'In Progress', icon: '🔄', color: '#F59E0B', count: 0 },
    { id: 'ready', label: isRTL ? 'جاهزة' : 'Ready', icon: '✅', color: '#10B981', count: 0 },
    { id: 'delivering', label: isRTL ? 'توصيل' : 'Delivering', icon: '🚗', color: '#8B5CF6', count: 0 },
    { id: 'completed', label: isRTL ? 'مكتملة' : 'Done', icon: '🏁', color: '#059669', count: 0 },
    { id: 'cancelled', label: isRTL ? 'ملغية' : 'Cancelled', icon: '❌', color: '#EF4444', count: 0 }
  ];

  // Status config
  const statusConfig: Record<string, { label_en: string; label_ar: string; color: string; bg: string }> = {
    new:              { label_en: 'New',            label_ar: 'جديد',        color: '#3B82F6', bg: '#EFF6FF' },
    accepted:         { label_en: 'Accepted',       label_ar: 'مقبول',       color: '#10B981', bg: '#ECFDF5' },
    in_picking:       { label_en: 'In Picking',     label_ar: 'قيد التحضير', color: '#F59E0B', bg: '#FFFBEB' },
    ready:            { label_en: 'Ready',          label_ar: 'جاهز',        color: '#8B5CF6', bg: '#F5F3FF' },
    out_for_delivery: { label_en: 'Out for Delivery', label_ar: 'قيد التوصيل', color: '#6366F1', bg: '#EEF2FF' },
    delivered:        { label_en: 'Delivered',      label_ar: 'تم التوصيل',  color: '#059669', bg: '#ECFDF5' },
    picked_up:        { label_en: 'Picked Up',      label_ar: 'تم الاستلام', color: '#059669', bg: '#ECFDF5' },
    cancelled:        { label_en: 'Cancelled',      label_ar: 'ملغي',        color: '#EF4444', bg: '#FEF2F2' },
    rejected:         { label_en: 'Rejected',       label_ar: 'مرفوض',       color: '#DC2626', bg: '#FEF2F2' }
  };

  function getStatusLabel(status: string) {
    const s = statusConfig[status];
    return s ? (isRTL ? s.label_ar : s.label_en) : status;
  }

  onMount(async () => {
    await Promise.all([loadBranches(), loadUsers()]);
    await loadOrders();
    updateTabCounts();
    setupRealtime();
  });

  onDestroy(() => {
    if (ordersChannel) supabase.removeChannel(ordersChannel);
  });

  async function loadBranches() {
    const { data } = await supabase.from('branches').select('id, name_ar, name_en').eq('is_active', true).order('name_ar');
    branches = data || [];
  }

  async function loadUsers() {
    const { data } = await supabase.from('users').select('id, username, user_type').order('username');
    users = data || [];
  }

  async function loadOrders() {
    loading = true;
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*, order_items(id, product_name_en, product_name_ar, quantity, unit_price, line_total, unit_name_en, unit_name_ar, product_id, products(image_url, barcode))')
        .order('created_at', { ascending: false });

      if (error) throw error;

      orders = (data || []).map(order => {
        const branch = branches.find(b => b.id === order.branch_id);
        const picker = users.find(u => u.id === order.picker_id);
        const delivery = users.find(u => u.id === order.delivery_person_id);
        return {
          ...order,
          branch_name: branch ? (isRTL ? branch.name_ar : branch.name_en) : '',
          picker_name: picker?.username || null,
          delivery_person_name: delivery?.username || null,
          items: order.order_items || []
        };
      });

      filterOrders();
      updateTabCounts();
    } catch (err: any) {
      console.error('Error loading orders:', err);
      notifications.add({ message: isRTL ? 'فشل تحميل الطلبات' : 'Failed to load orders', type: 'error' });
    } finally {
      loading = false;
    }
  }

  function filterOrders() {
    filteredOrders = orders.filter(order => {
      // Tab filter
      switch (activeTab) {
        case 'new': if (order.order_status !== 'new') return false; break;
        case 'in_progress': if (!['accepted', 'in_picking'].includes(order.order_status)) return false; break;
        case 'ready': if (!['ready'].includes(order.order_status)) return false; break;
        case 'delivering': if (!['out_for_delivery'].includes(order.order_status)) return false; break;
        case 'completed': if (!['delivered', 'picked_up'].includes(order.order_status)) return false; break;
        case 'cancelled': if (!['cancelled', 'rejected'].includes(order.order_status)) return false; break;
      }
      // Search
      if (searchTerm) {
        const term = searchTerm.toLowerCase();
        if (!order.order_number?.toLowerCase().includes(term) && 
            !order.customer_name?.toLowerCase().includes(term) &&
            !order.customer_phone?.toLowerCase().includes(term)) return false;
      }
      return true;
    });
  }

  function updateTabCounts() {
    tabs = tabs.map(tab => {
      let count = 0;
      switch (tab.id) {
        case 'new': count = orders.filter(o => o.order_status === 'new').length; break;
        case 'in_progress': count = orders.filter(o => ['accepted', 'in_picking'].includes(o.order_status)).length; break;
        case 'ready': count = orders.filter(o => o.order_status === 'ready').length; break;
        case 'delivering': count = orders.filter(o => o.order_status === 'out_for_delivery').length; break;
        case 'completed': count = orders.filter(o => ['delivered', 'picked_up'].includes(o.order_status)).length; break;
        case 'cancelled': count = orders.filter(o => ['cancelled', 'rejected'].includes(o.order_status)).length; break;
      }
      return { ...tab, count };
    });
  }

  function setupRealtime() {
    ordersChannel = supabase
      .channel('mobile_orders_rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        loadOrders();
      })
      .subscribe();
  }

  function openOrder(order: any) {
    selectedOrder = order;
    showOrderDetail = true;
  }

  function closeDetail() {
    showOrderDetail = false;
    selectedOrder = null;
    showPickerModal = false;
    showDeliveryModal = false;
  }

  // ===== Order Actions =====
  async function acceptOrder() {
    if (!selectedOrder) return;
    try {
      const { error } = await supabase.from('orders')
        .update({ order_status: 'accepted', accepted_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', selectedOrder.id);
      if (error) throw error;

      await supabase.from('order_audit_logs').insert({
        order_id: selectedOrder.id, action_type: 'status_change',
        from_status: selectedOrder.order_status, to_status: 'accepted',
        performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
        performed_by_role: get(currentUser)?.role,
        notes: 'Order accepted (mobile)'
      });

      // Send bilingual notification
      await supabase.rpc('send_order_notification', {
        p_order_id: selectedOrder.id,
        p_title: `Order #${selectedOrder.order_number} Accepted|||تم قبول الطلب #${selectedOrder.order_number}`,
        p_message: `Order #${selectedOrder.order_number} has been accepted. Please assign a picker.|||تم قبول الطلب #${selectedOrder.order_number}. يرجى تعيين محضّر.`,
        p_type: 'order_accepted',
        p_priority: 'high',
        p_performed_by: get(currentUser)?.id
      });

      notifications.add({ message: isRTL ? 'تم قبول الطلب' : 'Order accepted', type: 'success' });
      await loadOrders();
      selectedOrder = orders.find(o => o.id === selectedOrder.id) || null;
    } catch (e: any) {
      notifications.add({ message: isRTL ? 'فشل قبول الطلب' : 'Failed to accept', type: 'error' });
    }
  }

  async function rejectOrder() {
    if (!selectedOrder) return;
    if (!confirm(isRTL ? 'هل أنت متأكد من رفض هذا الطلب؟' : 'Reject this order?')) return;
    try {
      const { error } = await supabase.from('orders')
        .update({ order_status: 'rejected', updated_at: new Date().toISOString() })
        .eq('id', selectedOrder.id);
      if (error) throw error;

      await supabase.from('order_audit_logs').insert({
        order_id: selectedOrder.id, action_type: 'status_change',
        from_status: selectedOrder.order_status, to_status: 'rejected',
        performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
        notes: 'Order rejected (mobile)'
      });

      notifications.add({ message: isRTL ? 'تم رفض الطلب' : 'Order rejected', type: 'info' });
      await loadOrders();
      closeDetail();
    } catch (e: any) {
      notifications.add({ message: isRTL ? 'فشل رفض الطلب' : 'Failed to reject', type: 'error' });
    }
  }

  async function cancelOrder() {
    if (!selectedOrder) return;
    if (!confirm(isRTL ? 'هل أنت متأكد من إلغاء هذا الطلب؟' : 'Cancel this order?')) return;
    try {
      const { error } = await supabase.from('orders')
        .update({ order_status: 'cancelled', updated_at: new Date().toISOString() })
        .eq('id', selectedOrder.id);
      if (error) throw error;

      await supabase.from('order_audit_logs').insert({
        order_id: selectedOrder.id, action_type: 'status_change',
        from_status: selectedOrder.order_status, to_status: 'cancelled',
        performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
        notes: 'Order cancelled (mobile)'
      });

      notifications.add({ message: isRTL ? 'تم إلغاء الطلب' : 'Order cancelled', type: 'info' });
      await loadOrders();
      closeDetail();
    } catch (e: any) {
      notifications.add({ message: isRTL ? 'فشل إلغاء الطلب' : 'Failed to cancel', type: 'error' });
    }
  }

  async function assignPicker(userId: string) {
    if (!selectedOrder) return;
    if (selectedOrder.order_status === 'new') {
      notifications.add({ message: isRTL ? 'يجب قبول الطلب أولاً' : 'Accept the order first', type: 'error' });
      return;
    }
    try {
      const pickerUser = users.find(u => u.id === userId);
      const { error } = await supabase.from('orders')
        .update({ picker_id: userId, picker_assigned_at: new Date().toISOString(), order_status: 'in_picking', updated_at: new Date().toISOString() })
        .eq('id', selectedOrder.id);
      if (error) throw error;

      // Create quick task for picker (bilingual EN|||AR)
      const pickTaskTitle = `Start Picking #${selectedOrder.order_number}|||بدء تحضير #${selectedOrder.order_number}`;
      const pickTaskDesc = `Start picking products for order #${selectedOrder.order_number}\nCustomer: ${selectedOrder.customer_name}\nAddress: ${selectedOrder.customer_address || 'N/A'}|||ابدأ بتحضير المنتجات للطلب رقم ${selectedOrder.order_number}\nالعميل: ${selectedOrder.customer_name}\nالعنوان: ${selectedOrder.customer_address || 'غير متوفر'}`;
      
      const { data: taskData, error: taskError } = await supabase
        .from('quick_tasks')
        .insert({
          title: pickTaskTitle,
          description: pickTaskDesc,
          priority: 'high',
          issue_type: 'order-start-picking',
          price_tag: 'high',
          assigned_by: get(currentUser)?.id,
          assigned_to_branch_id: selectedOrder.branch_id,
          order_id: selectedOrder.id,
          deadline_datetime: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
          require_task_finished: true,
          require_photo_upload: false,
          require_erp_reference: false
        })
        .select()
        .single();

      if (!taskError && taskData) {
        await supabase.from('quick_task_assignments').insert({
          quick_task_id: taskData.id,
          assigned_to_user_id: userId,
          status: 'assigned',
          require_task_finished: true,
          require_photo_upload: false,
          require_erp_reference: false
        });
      }

      // Audit log
      await supabase.from('order_audit_logs').insert({
        order_id: selectedOrder.id, action_type: 'assignment',
        assignment_type: 'picker',
        assigned_user_id: userId, assigned_user_name: pickerUser?.username,
        performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
        performed_by_role: get(currentUser)?.role,
        notes: `Picker assigned: ${pickerUser?.username} (mobile)`
      });

      // Send notification to picker
      await supabase.rpc('send_order_notification', {
        p_order_id: selectedOrder.id,
        p_title: `Picking Task: Order #${selectedOrder.order_number}|||مهمة تحضير: طلب #${selectedOrder.order_number}`,
        p_message: `You have been assigned to pick order #${selectedOrder.order_number}. Customer: ${selectedOrder.customer_name}|||تم تعيينك لتحضير الطلب #${selectedOrder.order_number}. العميل: ${selectedOrder.customer_name}`,
        p_type: 'order_picking',
        p_priority: 'high',
        p_performed_by: get(currentUser)?.id,
        p_target_user_id: userId
      });

      notifications.add({ message: isRTL ? 'تم تعيين المحضّر' : 'Picker assigned', type: 'success' });
      showPickerModal = false;
      pickerSearch = '';
      await loadOrders();
      selectedOrder = orders.find(o => o.id === selectedOrder.id) || null;
    } catch (e: any) {
      notifications.add({ message: isRTL ? 'فشل تعيين المحضّر' : 'Failed to assign picker', type: 'error' });
    }
  }

  async function assignDelivery(userId: string) {
    if (!selectedOrder) return;
    if (!selectedOrder.picker_id) {
      notifications.add({ message: isRTL ? 'يجب تعيين المحضّر أولاً' : 'Assign picker first', type: 'error' });
      return;
    }
    try {
      const deliveryUser = users.find(u => u.id === userId);
      const { error } = await supabase.from('orders')
        .update({ delivery_person_id: userId, delivery_assigned_at: new Date().toISOString(), order_status: 'out_for_delivery', updated_at: new Date().toISOString() })
        .eq('id', selectedOrder.id);
      if (error) throw error;

      // Create quick task for delivery (bilingual EN|||AR)
      const deliveryTaskTitle = `Deliver Order #${selectedOrder.order_number}|||توصيل طلب #${selectedOrder.order_number}`;
      const deliveryTaskDesc = `Deliver order #${selectedOrder.order_number}\nCustomer: ${selectedOrder.customer_name}\nPhone: ${selectedOrder.customer_phone}\nAddress: ${selectedOrder.customer_address || 'N/A'}\n\nNote: Photo proof of delivery is required|||قم بتوصيل الطلب رقم ${selectedOrder.order_number}\nالعميل: ${selectedOrder.customer_name}\nرقم الهاتف: ${selectedOrder.customer_phone}\nالعنوان: ${selectedOrder.customer_address || 'غير متوفر'}\n\nملاحظة: يجب تحميل صورة إثبات التسليم`;
      
      const { data: taskData, error: taskError } = await supabase
        .from('quick_tasks')
        .insert({
          title: deliveryTaskTitle,
          description: deliveryTaskDesc,
          priority: 'high',
          issue_type: 'order-delivery',
          price_tag: 'high',
          assigned_by: get(currentUser)?.id,
          assigned_to_branch_id: selectedOrder.branch_id,
          order_id: selectedOrder.id,
          deadline_datetime: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
          require_task_finished: true,
          require_photo_upload: true,
          require_erp_reference: false
        })
        .select()
        .single();

      if (!taskError && taskData) {
        await supabase.from('quick_task_assignments').insert({
          quick_task_id: taskData.id,
          assigned_to_user_id: userId,
          status: 'assigned',
          require_task_finished: true,
          require_photo_upload: true,
          require_erp_reference: false
        });
      }

      // Audit logs (assignment + status change)
      await supabase.from('order_audit_logs').insert([
        {
          order_id: selectedOrder.id, action_type: 'assignment',
          assignment_type: 'delivery',
          assigned_user_id: userId, assigned_user_name: deliveryUser?.username,
          performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
          performed_by_role: get(currentUser)?.role,
          notes: `Delivery assigned: ${deliveryUser?.username} (mobile)`
        },
        {
          order_id: selectedOrder.id, action_type: 'status_change',
          from_status: selectedOrder.order_status, to_status: 'out_for_delivery',
          performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
          performed_by_role: get(currentUser)?.role,
          notes: `Status changed to out_for_delivery (delivery assigned: ${deliveryUser?.username}) (mobile)`
        }
      ]);

      // Send notification to delivery person
      await supabase.rpc('send_order_notification', {
        p_order_id: selectedOrder.id,
        p_title: `Delivery Task: Order #${selectedOrder.order_number}|||مهمة توصيل: طلب #${selectedOrder.order_number}`,
        p_message: `You have been assigned to deliver order #${selectedOrder.order_number} to ${selectedOrder.customer_name}. Address: ${selectedOrder.customer_address || 'N/A'}|||تم تعيينك لتوصيل الطلب #${selectedOrder.order_number} إلى ${selectedOrder.customer_name}. العنوان: ${selectedOrder.customer_address || 'غير متوفر'}`,
        p_type: 'order_delivery',
        p_priority: 'high',
        p_performed_by: get(currentUser)?.id,
        p_target_user_id: userId
      });

      notifications.add({ message: isRTL ? 'تم تعيين مندوب التوصيل' : 'Delivery assigned', type: 'success' });
      showDeliveryModal = false;
      deliverySearch = '';
      await loadOrders();
      selectedOrder = orders.find(o => o.id === selectedOrder.id) || null;
    } catch (e: any) {
      notifications.add({ message: isRTL ? 'فشل تعيين مندوب التوصيل' : 'Failed to assign delivery', type: 'error' });
    }
  }

  async function markAsReady() {
    if (!selectedOrder) return;
    if (!confirm(isRTL ? 'هل أنت متأكد أن الطلب جاهز؟' : 'Confirm order is ready?')) return;
    try {
      const { error } = await supabase.from('orders')
        .update({ order_status: 'ready', ready_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', selectedOrder.id);
      if (error) throw error;

      await supabase.from('order_audit_logs').insert({
        order_id: selectedOrder.id, action_type: 'status_change',
        from_status: selectedOrder.order_status, to_status: 'ready',
        performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
        performed_by_role: get(currentUser)?.role,
        notes: 'Order marked as ready (mobile)'
      });

      notifications.add({ message: isRTL ? 'تم تجهيز الطلب' : 'Order marked as ready', type: 'success' });
      await loadOrders();
      selectedOrder = orders.find(o => o.id === selectedOrder.id) || null;
    } catch (e: any) {
      notifications.add({ message: isRTL ? 'فشل تحديث الحالة' : 'Failed to update status', type: 'error' });
    }
  }

  async function markAsPickedUp() {
    if (!selectedOrder) return;
    if (!confirm(isRTL ? 'هل أنت متأكد أن العميل استلم الطلب؟' : 'Confirm customer has picked up the order?')) return;
    try {
      const { error } = await supabase.from('orders')
        .update({ order_status: 'picked_up', picked_up_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', selectedOrder.id);
      if (error) throw error;

      await supabase.from('order_audit_logs').insert({
        order_id: selectedOrder.id, action_type: 'status_change',
        from_status: selectedOrder.order_status, to_status: 'picked_up',
        performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
        performed_by_role: get(currentUser)?.role,
        notes: 'Order picked up by customer (mobile)'
      });

      await supabase.rpc('send_order_notification', {
        p_order_id: selectedOrder.id,
        p_title: `Order #${selectedOrder.order_number} Picked Up|||تم استلام الطلب #${selectedOrder.order_number}`,
        p_message: `Order #${selectedOrder.order_number} has been picked up by ${selectedOrder.customer_name}|||تم استلام الطلب #${selectedOrder.order_number} من قبل ${selectedOrder.customer_name}`,
        p_type: 'order_picked_up',
        p_priority: 'medium',
        p_performed_by: get(currentUser)?.id
      });

      notifications.add({ message: isRTL ? 'تم تأكيد استلام الطلب' : 'Order marked as picked up', type: 'success' });
      await loadOrders();
      selectedOrder = orders.find(o => o.id === selectedOrder.id) || null;
    } catch (e: any) {
      notifications.add({ message: isRTL ? 'فشل تحديث الحالة' : 'Failed to update status', type: 'error' });
    }
  }

  async function markAsDelivered() {
    if (!selectedOrder) return;
    if (!confirm(isRTL ? 'هل أنت متأكد أن الطلب تم توصيله؟' : 'Confirm order has been delivered?')) return;
    try {
      const { error } = await supabase.from('orders')
        .update({ order_status: 'delivered', delivered_at: new Date().toISOString(), actual_delivery_time: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', selectedOrder.id);
      if (error) throw error;

      await supabase.from('order_audit_logs').insert({
        order_id: selectedOrder.id, action_type: 'status_change',
        from_status: selectedOrder.order_status, to_status: 'delivered',
        performed_by: get(currentUser)?.id, performed_by_name: get(currentUser)?.username,
        performed_by_role: get(currentUser)?.role,
        notes: 'Order manually marked as delivered (mobile)'
      });

      await supabase.rpc('send_order_notification', {
        p_order_id: selectedOrder.id,
        p_title: `Order #${selectedOrder.order_number} Delivered|||تم توصيل الطلب #${selectedOrder.order_number}`,
        p_message: `Order #${selectedOrder.order_number} has been delivered to ${selectedOrder.customer_name}|||تم توصيل الطلب #${selectedOrder.order_number} إلى ${selectedOrder.customer_name}`,
        p_type: 'order_delivered',
        p_priority: 'medium',
        p_performed_by: get(currentUser)?.id
      });

      notifications.add({ message: isRTL ? 'تم تأكيد توصيل الطلب' : 'Order marked as delivered', type: 'success' });
      await loadOrders();
      selectedOrder = orders.find(o => o.id === selectedOrder.id) || null;
    } catch (e: any) {
      notifications.add({ message: isRTL ? 'فشل تحديث الحالة' : 'Failed to update status', type: 'error' });
    }
  }

  function formatDate(dateStr: string) {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    return d.toLocaleDateString(isRTL ? 'ar-SA' : 'en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  function timeAgo(dateStr: string) {
    if (!dateStr) return '';
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return isRTL ? 'الآن' : 'Just now';
    if (mins < 60) return isRTL ? `${mins} دقيقة` : `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return isRTL ? `${hrs} ساعة` : `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return isRTL ? `${days} يوم` : `${days}d ago`;
  }
</script>

<div class="mobile-orders" dir={isRTL ? 'rtl' : 'ltr'}>
  <!-- Header -->
  <div class="orders-header">
    <div class="header-top">
      <button class="back-btn" aria-label="Back" on:click={() => goto('/mobile-interface')}>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <path d="M19 12H5M12 19l-7-7 7-7"/>
        </svg>
      </button>
      <h1>{isRTL ? '📦 إدارة الطلبات' : '📦 Orders Manager'}</h1>
      <button class="refresh-btn" aria-label="Refresh" on:click={() => loadOrders()}>
        <svg class:spinning={loading} width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <path d="M23 4v6h-6M1 20v-6h6"/>
          <path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/>
        </svg>
      </button>
    </div>

    <!-- Search -->
    <div class="search-bar">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="2">
        <circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>
      </svg>
      <input type="text" bind:value={searchTerm} on:input={() => filterOrders()} 
        placeholder={isRTL ? 'بحث برقم الطلب، اسم العميل...' : 'Search order#, customer name...'} />
      {#if searchTerm}
        <button class="clear-search" on:click={() => { searchTerm = ''; filterOrders(); }}>✕</button>
      {/if}
    </div>

    <!-- Status Tabs -->
    <div class="tabs-scroll">
      {#each tabs as tab}
        <button
          class="status-tab"
          class:active={activeTab === tab.id}
          style="--tab-color: {tab.color}"
          on:click={() => { activeTab = tab.id; filterOrders(); }}
        >
          <span class="tab-icon">{tab.icon}</span>
          <span class="tab-label">{tab.label}</span>
          {#if tab.count > 0}
            <span class="tab-count" style="background: {tab.color}">{tab.count}</span>
          {/if}
        </button>
      {/each}
    </div>
  </div>

  <!-- Orders List -->
  <div class="orders-list">
    {#if loading}
      <div class="loading-state">
        <div class="spinner"></div>
        <p>{isRTL ? 'جاري التحميل...' : 'Loading orders...'}</p>
      </div>
    {:else if filteredOrders.length === 0}
      <div class="empty-state">
        <span class="empty-icon">📭</span>
        <p>{isRTL ? 'لا توجد طلبات' : 'No orders found'}</p>
      </div>
    {:else}
      {#each filteredOrders as order}
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div class="order-card" on:click={() => openOrder(order)}>
          <div class="card-header">
            <div class="order-number">#{order.order_number}</div>
            <span class="status-badge" style="color: {statusConfig[order.order_status]?.color}; background: {statusConfig[order.order_status]?.bg}">
              {getStatusLabel(order.order_status)}
            </span>
          </div>

          <div class="card-body">
            <div class="customer-info">
              <span class="customer-name">👤 {order.customer_name || 'N/A'}</span>
              <span class="customer-phone">📱 {order.customer_phone || ''}</span>
            </div>

            <div class="order-meta">
              <span class="meta-item">🏪 {order.branch_name}</span>
              <span class="meta-item">🕐 {timeAgo(order.created_at)}</span>
              <span class="meta-item">{order.delivery_type === 'delivery' ? '🚗' : '🏬'} {order.delivery_type === 'delivery' ? (isRTL ? 'توصيل' : 'Delivery') : (isRTL ? 'استلام' : 'Pickup')}</span>
            </div>

            <div class="card-footer">
              <div class="items-count">
                📦 {order.item_count || order.items?.length || 0} {isRTL ? 'منتج' : 'items'}
              </div>
              <div class="total-amount">
                {Number(order.total_amount || 0).toFixed(2)} <span class="currency">{isRTL ? 'ريال' : 'SAR'}</span>
              </div>
            </div>

            <!-- Assignment badges -->
            {#if order.picker_name || order.delivery_person_name}
              <div class="assignment-badges">
                {#if order.picker_name}
                  <span class="badge picker">👨‍🍳 {order.picker_name}</span>
                {/if}
                {#if order.delivery_person_name}
                  <span class="badge delivery">🚗 {order.delivery_person_name}</span>
                {/if}
              </div>
            {/if}
          </div>
        </div>
      {/each}
    {/if}
  </div>

  <!-- ===== ORDER DETAIL OVERLAY ===== -->
  {#if showOrderDetail && selectedOrder}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="detail-overlay" on:click={closeDetail}>
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="detail-panel" on:click|stopPropagation>
        <!-- Detail Header -->
        <div class="detail-header">
          <button class="close-detail" aria-label="Close" on:click={closeDetail}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
          </button>
          <div class="detail-title">
            <h2>#{selectedOrder.order_number}</h2>
            <span class="status-badge" style="color: {statusConfig[selectedOrder.order_status]?.color}; background: {statusConfig[selectedOrder.order_status]?.bg}">
              {getStatusLabel(selectedOrder.order_status)}
            </span>
          </div>
          <span class="detail-date">{formatDate(selectedOrder.created_at)}</span>
        </div>

        <!-- Action Buttons -->
        {#if selectedOrder.order_status === 'new'}
          <div class="action-buttons">
            <button class="action-btn accept" on:click={acceptOrder}>
              ✅ {isRTL ? 'قبول' : 'Accept'}
            </button>
            <button class="action-btn reject" on:click={rejectOrder}>
              ❌ {isRTL ? 'رفض' : 'Reject'}
            </button>
          </div>
        {:else if ['accepted', 'in_picking'].includes(selectedOrder.order_status)}
          <div class="action-buttons">
            {#if !selectedOrder.picker_id}
              <button class="action-btn assign-picker" on:click={() => showPickerModal = true}>
                👨‍🍳 {isRTL ? 'تعيين محضّر' : 'Assign Picker'}
              </button>
            {/if}
            {#if selectedOrder.picker_id}
              <button class="action-btn mark-ready" on:click={markAsReady}>
                ✅ {isRTL ? 'جاهز' : 'Mark Ready'}
              </button>
            {/if}
            <button class="action-btn cancel-small" on:click={cancelOrder}>
              ❌ {isRTL ? 'إلغاء' : 'Cancel'}
            </button>
          </div>
        {:else if selectedOrder.order_status === 'ready'}
          <div class="action-buttons">
            {#if selectedOrder.delivery_type === 'pickup'}
              <button class="action-btn picked-up" on:click={markAsPickedUp}>
                🏬 {isRTL ? 'تم الاستلام' : 'Picked Up'}
              </button>
            {:else}
              {#if !selectedOrder.delivery_person_id}
                <button class="action-btn assign-delivery" on:click={() => showDeliveryModal = true}>
                  🚗 {isRTL ? 'تعيين مندوب' : 'Assign Delivery'}
                </button>
              {/if}
            {/if}
            <button class="action-btn cancel-small" on:click={cancelOrder}>
              ❌ {isRTL ? 'إلغاء' : 'Cancel'}
            </button>
          </div>
        {:else if selectedOrder.order_status === 'out_for_delivery'}
          <div class="action-buttons">
            <button class="action-btn delivered" on:click={markAsDelivered}>
              📦 {isRTL ? 'تم التوصيل' : 'Mark Delivered'}
            </button>
          </div>
        {/if}

        <!-- Customer Info -->
        <div class="detail-section">
          <h3>👤 {isRTL ? 'معلومات العميل' : 'Customer Info'}</h3>
          <div class="info-grid">
            <div class="info-item">
              <span class="info-label">{isRTL ? 'الاسم' : 'Name'}</span>
              <span class="info-value">{selectedOrder.customer_name || 'N/A'}</span>
            </div>
            <div class="info-item">
              <span class="info-label">{isRTL ? 'الهاتف' : 'Phone'}</span>
              <span class="info-value">{selectedOrder.customer_phone || 'N/A'}</span>
            </div>
            <div class="info-item">
              <span class="info-label">{isRTL ? 'الفرع' : 'Branch'}</span>
              <span class="info-value">{selectedOrder.branch_name}</span>
            </div>
            <div class="info-item">
              <span class="info-label">{isRTL ? 'النوع' : 'Type'}</span>
              <span class="info-value">{selectedOrder.delivery_type === 'delivery' ? (isRTL ? '🚗 توصيل' : '🚗 Delivery') : (isRTL ? '🏬 استلام' : '🏬 Pickup')}</span>
            </div>
            <div class="info-item">
              <span class="info-label">{isRTL ? 'الدفع' : 'Payment'}</span>
              <span class="info-value">{selectedOrder.payment_method || 'N/A'}</span>
            </div>
          </div>
        </div>

        <!-- Assigned Staff -->
        {#if selectedOrder.picker_name || selectedOrder.delivery_person_name}
          <div class="detail-section">
            <h3>👥 {isRTL ? 'الموظفون المعينون' : 'Assigned Staff'}</h3>
            <div class="staff-badges">
              {#if selectedOrder.picker_name}
                <div class="staff-badge picker">
                  <span class="staff-icon">👨‍🍳</span>
                  <div>
                    <span class="staff-role">{isRTL ? 'المحضّر' : 'Picker'}</span>
                    <span class="staff-name">{selectedOrder.picker_name}</span>
                  </div>
                </div>
              {/if}
              {#if selectedOrder.delivery_person_name}
                <div class="staff-badge delivery">
                  <span class="staff-icon">🚗</span>
                  <div>
                    <span class="staff-role">{isRTL ? 'مندوب التوصيل' : 'Delivery'}</span>
                    <span class="staff-name">{selectedOrder.delivery_person_name}</span>
                  </div>
                </div>
              {/if}
            </div>
          </div>
        {/if}

        <!-- Order Items -->
        <div class="detail-section">
          <h3>📦 {isRTL ? 'المنتجات' : 'Products'} ({selectedOrder.items?.length || 0})</h3>
          <div class="items-list">
            {#each selectedOrder.items || [] as item, i}
              <div class="item-row">
                <div class="item-image">
                  {#if item.products?.image_url}
                    <img src={item.products.image_url} alt={item.product_name_en} />
                  {:else}
                    <div class="no-image">📦</div>
                  {/if}
                </div>
                <div class="item-info">
                  <span class="item-name">{isRTL ? item.product_name_ar : item.product_name_en}</span>
                  <span class="item-sub">{isRTL ? item.product_name_en : item.product_name_ar}</span>
                  <span class="item-unit">{item.unit_name_en || ''} {item.unit_name_ar ? `/ ${item.unit_name_ar}` : ''}</span>
                </div>
                <div class="item-qty">×{item.quantity}</div>
                <div class="item-price">{Number(item.line_total || 0).toFixed(2)}</div>
              </div>
            {/each}
          </div>
        </div>

        <!-- Order Summary -->
        <div class="detail-section summary-section">
          <div class="summary-row">
            <span>{isRTL ? 'المجموع الفرعي' : 'Subtotal'}</span>
            <span>{Number(selectedOrder.subtotal_amount || 0).toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
          </div>
          {#if selectedOrder.delivery_fee > 0}
            <div class="summary-row">
              <span>{isRTL ? 'رسوم التوصيل' : 'Delivery Fee'}</span>
              <span>{Number(selectedOrder.delivery_fee).toFixed(2)}</span>
            </div>
          {/if}
          {#if selectedOrder.discount_amount > 0}
            <div class="summary-row discount">
              <span>{isRTL ? 'الخصم' : 'Discount'}</span>
              <span>-{Number(selectedOrder.discount_amount).toFixed(2)}</span>
            </div>
          {/if}
          <div class="summary-row total">
            <span>{isRTL ? 'الإجمالي' : 'Total'}</span>
            <span>{Number(selectedOrder.total_amount || 0).toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
          </div>
        </div>

        <!-- Customer Notes -->
        {#if selectedOrder.customer_notes}
          <div class="detail-section">
            <h3>📝 {isRTL ? 'ملاحظات العميل' : 'Customer Notes'}</h3>
            <p class="notes-text">{selectedOrder.customer_notes}</p>
          </div>
        {/if}
      </div>
    </div>

    <!-- Picker Assignment Modal -->
    {#if showPickerModal}
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="modal-overlay" on:click={() => { showPickerModal = false; pickerSearch = ''; }}>
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div class="user-modal" on:click|stopPropagation>
          <h3>👨‍🍳 {isRTL ? 'اختر المحضّر' : 'Select Picker'}</h3>
          <div class="modal-search">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
            <input type="text" bind:value={pickerSearch} placeholder={isRTL ? 'بحث بالاسم...' : 'Search by name...'} />
            {#if pickerSearch}
              <button class="modal-search-clear" on:click={() => pickerSearch = ''}>✕</button>
            {/if}
          </div>
          <div class="user-list">
            {#each filteredPickerUsers as user}
              <button class="user-option" on:click={() => assignPicker(user.id)}>
                <span class="user-avatar">👤</span>
                <span class="user-name">{user.username}</span>
              </button>
            {/each}
            {#if filteredPickerUsers.length === 0}
              <div class="no-results">😕 {isRTL ? 'لا توجد نتائج' : 'No results'}</div>
            {/if}
          </div>
          <button class="modal-close" on:click={() => { showPickerModal = false; pickerSearch = ''; }}>
            {isRTL ? 'إلغاء' : 'Cancel'}
          </button>
        </div>
      </div>
    {/if}

    <!-- Delivery Assignment Modal -->
    {#if showDeliveryModal}
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="modal-overlay" on:click={() => { showDeliveryModal = false; deliverySearch = ''; }}>
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div class="user-modal" on:click|stopPropagation>
          <h3>🚗 {isRTL ? 'اختر مندوب التوصيل' : 'Select Delivery Person'}</h3>
          <div class="modal-search">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
            <input type="text" bind:value={deliverySearch} placeholder={isRTL ? 'بحث بالاسم...' : 'Search by name...'} />
            {#if deliverySearch}
              <button class="modal-search-clear" on:click={() => deliverySearch = ''}>✕</button>
            {/if}
          </div>
          <div class="user-list">
            {#each filteredDeliveryUsers as user}
              <button class="user-option" on:click={() => assignDelivery(user.id)}>
                <span class="user-avatar">👤</span>
                <span class="user-name">{user.username}</span>
              </button>
            {/each}
            {#if filteredDeliveryUsers.length === 0}
              <div class="no-results">😕 {isRTL ? 'لا توجد نتائج' : 'No results'}</div>
            {/if}
          </div>
          <button class="modal-close" on:click={() => { showDeliveryModal = false; deliverySearch = ''; }}>
            {isRTL ? 'إلغاء' : 'Cancel'}
          </button>
        </div>
      </div>
    {/if}
  {/if}
</div>

<style>
  .mobile-orders {
    min-height: 100vh;
    background: #F1F5F9;
    padding-bottom: 80px;
  }

  /* Header */
  .orders-header {
    background: white;
    border-bottom: 1px solid #E2E8F0;
    position: sticky;
    top: 0;
    z-index: 50;
    box-shadow: 0 2px 8px rgba(0,0,0,0.06);
  }
  .header-top {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px 8px;
  }
  .header-top h1 {
    flex: 1;
    font-size: 18px;
    font-weight: 800;
    color: #1E293B;
  }
  .back-btn, .refresh-btn {
    background: none;
    border: none;
    color: #64748B;
    padding: 6px;
    border-radius: 8px;
    cursor: pointer;
  }
  .back-btn:active, .refresh-btn:active { background: #F1F5F9; }
  .spinning { animation: spin 1s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }

  /* Search */
  .search-bar {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 0 16px 8px;
    padding: 8px 12px;
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 12px;
  }
  .search-bar input {
    flex: 1;
    border: none;
    background: none;
    outline: none;
    font-size: 14px;
    color: #334155;
  }
  .clear-search {
    background: none;
    border: none;
    color: #94A3B8;
    font-size: 16px;
    cursor: pointer;
    padding: 2px 6px;
  }

  /* Tabs */
  .tabs-scroll {
    display: flex;
    gap: 6px;
    padding: 8px 16px 12px;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    scrollbar-width: none;
  }
  .tabs-scroll::-webkit-scrollbar { display: none; }

  .status-tab {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 6px 12px;
    border: 1.5px solid #E2E8F0;
    border-radius: 20px;
    background: white;
    font-size: 12px;
    font-weight: 600;
    color: #64748B;
    white-space: nowrap;
    cursor: pointer;
    transition: all 0.2s;
  }
  .status-tab.active {
    background: var(--tab-color);
    color: white;
    border-color: var(--tab-color);
    box-shadow: 0 2px 8px color-mix(in srgb, var(--tab-color) 30%, transparent);
  }
  .tab-icon { font-size: 14px; }
  .tab-count {
    font-size: 10px;
    font-weight: 700;
    color: white;
    min-width: 18px;
    height: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 9px;
    padding: 0 5px;
  }
  .status-tab.active .tab-count { background: rgba(255,255,255,0.3) !important; }

  /* Orders List */
  .orders-list {
    padding: 12px 16px;
  }

  .loading-state, .empty-state {
    text-align: center;
    padding: 60px 20px;
    color: #94A3B8;
  }
  .empty-icon { font-size: 48px; display: block; margin-bottom: 12px; }
  .spinner {
    width: 32px;
    height: 32px;
    border: 3px solid #E2E8F0;
    border-top-color: #3B82F6;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin: 0 auto 12px;
  }

  /* Order Card */
  .order-card {
    background: white;
    border-radius: 16px;
    padding: 14px 16px;
    margin-bottom: 10px;
    border: 1px solid #E2E8F0;
    box-shadow: 0 1px 3px rgba(0,0,0,0.04);
    cursor: pointer;
    transition: all 0.2s;
  }
  .order-card:active { transform: scale(0.98); background: #F8FAFC; }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }
  .order-number {
    font-size: 15px;
    font-weight: 800;
    color: #1E293B;
  }
  .status-badge {
    font-size: 11px;
    font-weight: 700;
    padding: 3px 10px;
    border-radius: 12px;
    white-space: nowrap;
  }

  .customer-info {
    display: flex;
    gap: 12px;
    font-size: 13px;
    color: #475569;
    margin-bottom: 6px;
  }
  .customer-name { font-weight: 600; }

  .order-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    font-size: 11px;
    color: #94A3B8;
    margin-bottom: 8px;
  }

  .card-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .items-count { font-size: 12px; color: #64748B; }
  .total-amount {
    font-size: 16px;
    font-weight: 800;
    color: #059669;
  }
  .currency { font-size: 11px; font-weight: 600; }

  .assignment-badges {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    margin-top: 8px;
    padding-top: 8px;
    border-top: 1px dashed #E2E8F0;
  }
  .badge {
    font-size: 11px;
    font-weight: 600;
    padding: 3px 8px;
    border-radius: 8px;
  }
  .badge.picker { background: #FEF3C7; color: #92400E; }
  .badge.delivery { background: #EDE9FE; color: #5B21B6; }

  /* Detail Overlay */
  .detail-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.5);
    z-index: 1100;
    display: flex;
    justify-content: center;
    align-items: flex-end;
  }
  .detail-panel {
    background: white;
    width: 100%;
    max-height: 92vh;
    border-radius: 20px 20px 0 0;
    overflow-y: auto;
    animation: slideUp 0.3s ease;
    padding-bottom: 30px;
  }
  @keyframes slideUp {
    from { transform: translateY(100%); }
    to { transform: translateY(0); }
  }

  .detail-header {
    position: sticky;
    top: 0;
    background: white;
    padding: 16px 20px 12px;
    border-bottom: 1px solid #E2E8F0;
    z-index: 10;
  }
  .close-detail {
    position: absolute;
    top: 16px;
    right: 16px;
    background: #F1F5F9;
    border: none;
    border-radius: 10px;
    padding: 6px;
    cursor: pointer;
    color: #64748B;
  }
  :global([dir="rtl"]) .close-detail { right: auto; left: 16px; }

  .detail-title {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .detail-title h2 {
    font-size: 20px;
    font-weight: 800;
    color: #1E293B;
  }
  .detail-date {
    font-size: 12px;
    color: #94A3B8;
    margin-top: 2px;
  }

  /* Action Buttons */
  .action-buttons {
    display: flex;
    gap: 8px;
    padding: 12px 20px;
    overflow-x: auto;
  }
  .action-btn {
    flex: 1;
    padding: 10px 14px;
    border: none;
    border-radius: 12px;
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.2s;
  }
  .action-btn:active { transform: scale(0.96); }
  .action-btn.accept { background: #10B981; color: white; }
  .action-btn.reject { background: #FEE2E2; color: #DC2626; }
  .action-btn.assign-picker { background: #FEF3C7; color: #92400E; }
  .action-btn.assign-delivery { background: #EDE9FE; color: #5B21B6; }
  .action-btn.cancel-small { background: #FEE2E2; color: #DC2626; flex: 0; padding: 10px 16px; }
  .action-btn.mark-ready { background: #D1FAE5; color: #059669; }
  .action-btn.picked-up { background: #D1FAE5; color: #059669; }
  .action-btn.delivered { background: #DBEAFE; color: #1D4ED8; flex: 1; }

  /* Detail Sections */
  .detail-section {
    padding: 14px 20px;
    border-bottom: 1px solid #F1F5F9;
  }
  .detail-section h3 {
    font-size: 14px;
    font-weight: 700;
    color: #334155;
    margin-bottom: 10px;
  }

  .info-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }
  .info-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .info-label { font-size: 11px; color: #94A3B8; font-weight: 600; text-transform: uppercase; }
  .info-value { font-size: 13px; color: #1E293B; font-weight: 600; }

  /* Staff Badges */
  .staff-badges { display: flex; gap: 10px; flex-wrap: wrap; }
  .staff-badge {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    border-radius: 12px;
    flex: 1;
    min-width: 140px;
  }
  .staff-badge.picker { background: #FEF3C7; }
  .staff-badge.delivery { background: #EDE9FE; }
  .staff-icon { font-size: 20px; }
  .staff-role { font-size: 10px; color: #64748B; display: block; text-transform: uppercase; font-weight: 600; }
  .staff-name { font-size: 13px; color: #1E293B; font-weight: 700; }

  /* Items List */
  .items-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .item-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px;
    background: #F8FAFC;
    border-radius: 12px;
    border: 1px solid #E2E8F0;
  }
  .item-image {
    width: 48px;
    height: 48px;
    border-radius: 10px;
    overflow: hidden;
    flex-shrink: 0;
    background: white;
    border: 1px solid #E2E8F0;
  }
  .item-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .no-image {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
    background: #F1F5F9;
  }
  .item-info {
    flex: 1;
    min-width: 0;
  }
  .item-name {
    font-size: 13px;
    font-weight: 600;
    color: #1E293B;
    display: block;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .item-sub {
    font-size: 11px;
    color: #94A3B8;
    display: block;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .item-unit {
    font-size: 10px;
    color: #64748B;
    display: block;
  }
  .item-qty {
    font-size: 14px;
    font-weight: 800;
    color: #3B82F6;
    flex-shrink: 0;
  }
  .item-price {
    font-size: 13px;
    font-weight: 700;
    color: #059669;
    flex-shrink: 0;
  }

  /* Summary */
  .summary-section {
    background: #F8FAFC;
    margin: 0 16px;
    border-radius: 12px;
    border: 1px solid #E2E8F0;
  }
  .summary-row {
    display: flex;
    justify-content: space-between;
    padding: 6px 0;
    font-size: 13px;
    color: #475569;
  }
  .summary-row.discount { color: #059669; }
  .summary-row.total {
    font-size: 16px;
    font-weight: 800;
    color: #1E293B;
    border-top: 2px solid #E2E8F0;
    padding-top: 10px;
    margin-top: 4px;
  }

  .notes-text {
    font-size: 13px;
    color: #475569;
    padding: 10px;
    background: #FFFBEB;
    border-radius: 8px;
    border: 1px solid #FDE68A;
  }

  /* User Selection Modal */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.6);
    z-index: 1200;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  .user-modal {
    background: white;
    border-radius: 20px;
    width: 100%;
    max-width: 360px;
    max-height: 70vh;
    overflow-y: auto;
    padding: 20px;
  }
  .user-modal h3 {
    font-size: 16px;
    font-weight: 800;
    color: #1E293B;
    text-align: center;
    margin-bottom: 16px;
  }
  .user-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .user-option {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    padding: 12px 14px;
    border: 1.5px solid #E2E8F0;
    border-radius: 12px;
    background: white;
    cursor: pointer;
    transition: all 0.2s;
    font-size: 14px;
    font-weight: 600;
    color: #334155;
  }
  .user-option:active { background: #F0F9FF; border-color: #3B82F6; }
  .user-avatar { font-size: 18px; }

  .modal-search {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    background: #F8FAFC;
    border: 1.5px solid #E2E8F0;
    border-radius: 12px;
    margin-bottom: 12px;
  }
  .modal-search input {
    flex: 1;
    border: none;
    background: none;
    outline: none;
    font-size: 14px;
    color: #334155;
  }
  .modal-search-clear {
    background: none;
    border: none;
    color: #94A3B8;
    font-size: 16px;
    cursor: pointer;
    padding: 2px 6px;
  }
  .no-results {
    text-align: center;
    padding: 20px;
    color: #94A3B8;
    font-size: 14px;
  }

  .modal-close {
    width: 100%;
    margin-top: 14px;
    padding: 12px;
    background: #F1F5F9;
    border: none;
    border-radius: 12px;
    font-size: 14px;
    font-weight: 700;
    color: #64748B;
    cursor: pointer;
  }
</style>
