<script>
  import { onMount, onDestroy } from 'svelte';
  import { supabase } from '$lib/utils/supabase';
  
  let currentLanguage = 'ar';
  let notifications = [];
  let loading = true;
  let subscription;

  function getLocalCustomerSession() {
    try {
      const customerSessionRaw = localStorage.getItem('customer_session');
      if (customerSessionRaw) {
        const customerSession = JSON.parse(customerSessionRaw);
        if (customerSession?.customer_id && customerSession?.registration_status === 'approved') {
          return { customerId: customerSession.customer_id };
        }
      }
      const raw = localStorage.getItem('aqura-device-session');
      if (!raw) return { customerId: null };
      const session = JSON.parse(raw);
      const currentId = session?.currentUserId;
      const user = Array.isArray(session?.users)
        ? session.users.find((u) => u.id === currentId && u.isActive)
        : null;
      return { customerId: user?.customerId || null };
    } catch (e) {
      return { customerId: null };
    }
  }

  onMount(async () => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) currentLanguage = savedLanguage;

    window.addEventListener('storage', handleStorageChange);
    window.addEventListener('languageChanged', handleLanguageEvent);

    await loadNotifications();
    setupRealtime();
  });

  onDestroy(() => {
    if (subscription) supabase.removeChannel(subscription);
    if (typeof window !== 'undefined') {
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('languageChanged', handleLanguageEvent);
    }
  });

  function handleStorageChange(event) {
    if (event.key === 'language' && event.newValue) {
      currentLanguage = event.newValue;
    }
  }

  function handleLanguageEvent(event) {
    currentLanguage = event.detail || localStorage.getItem('language') || 'ar';
  }

  function setupRealtime() {
    const { customerId } = getLocalCustomerSession();
    if (!customerId) return;

    subscription = supabase
      .channel('customer-notifications')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'order_audit_logs' },
        (payload) => {
          // Reload to get the full joined data
          loadNotifications();
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'orders' },
        () => {
          loadNotifications();
        }
      )
      .subscribe();
  }

  async function loadNotifications() {
    const { customerId } = getLocalCustomerSession();
    if (!customerId) {
      loading = false;
      notifications = [];
      return;
    }

    try {
      // Get the customer's orders
      const { data: orders, error: ordersError } = await supabase
        .from('orders')
        .select('id, order_number')
        .eq('customer_id', customerId);

      if (ordersError || !orders || orders.length === 0) {
        notifications = [];
        loading = false;
        return;
      }

      const orderIds = orders.map(o => o.id);
      const orderMap = {};
      orders.forEach(o => { orderMap[o.id] = o.order_number; });

      // Get audit logs for customer's orders (only status changes are customer-relevant)
      const { data: logs, error: logsError } = await supabase
        .from('order_audit_logs')
        .select('id, order_id, action_type, from_status, to_status, notes, created_at')
        .in('order_id', orderIds)
        .eq('action_type', 'status_change')
        .order('created_at', { ascending: false })
        .limit(50);

      if (logsError) {
        console.error('Error loading notifications:', logsError);
        notifications = [];
      } else {
        // Read notifications from localStorage
        const readIds = getReadNotificationIds();
        
        notifications = (logs || []).map(log => ({
          id: log.id,
          orderId: log.order_id,
          orderNumber: orderMap[log.order_id] || '',
          type: mapActionToType(log.action_type, log.to_status),
          titleAr: getNotificationTitleAr(log, orderMap[log.order_id]),
          titleEn: getNotificationTitleEn(log, orderMap[log.order_id]),
          messageAr: getNotificationMessageAr(log),
          messageEn: getNotificationMessageEn(log),
          time: log.created_at,
          read: readIds.has(log.id)
        })).filter(n => !n.read);
      }
    } catch (err) {
      console.error('Error:', err);
      notifications = [];
    } finally {
      loading = false;
    }
  }

  function getReadNotificationIds() {
    try {
      const raw = localStorage.getItem('customer_read_notifications');
      return new Set(raw ? JSON.parse(raw) : []);
    } catch { return new Set(); }
  }

  function saveReadNotificationId(id) {
    const readIds = getReadNotificationIds();
    readIds.add(id);
    localStorage.setItem('customer_read_notifications', JSON.stringify([...readIds]));
  }

  function mapActionToType(actionType, toStatus) {
    if (actionType === 'status_change') {
      switch (toStatus) {
        case 'accepted': return 'order_confirmed';
        case 'in_picking': return 'order_picking';
        case 'ready': return 'order_ready';
        case 'out_for_delivery': return 'order_pickup';
        case 'delivered': return 'order_delivered';
        case 'picked_up': return 'order_delivered';
        case 'cancelled': return 'order_cancelled';
        default: return 'order_update';
      }
    }
    if (actionType === 'order_created') return 'order_created';
    if (actionType === 'picker_assigned' || actionType === 'delivery_assigned') return 'order_update';
    return 'order_update';
  }

  function getNotificationTitleAr(log, orderNumber) {
    const num = orderNumber || '';
    if (log.action_type === 'order_created') return `تم إنشاء الطلب #${num}`;
    if (log.action_type === 'status_change') {
      switch (log.to_status) {
        case 'accepted': return `تم قبول طلبك #${num}`;
        case 'in_picking': return `جاري تحضير طلبك #${num}`;
        case 'ready': return `طلبك #${num} جاهز`;
        case 'out_for_delivery': return `طلبك #${num} في الطريق`;
        case 'delivered': return `تم تسليم طلبك #${num}`;
        case 'picked_up': return `تم استلام طلبك #${num}`;
        case 'cancelled': return `تم إلغاء طلبك #${num}`;
        default: return `تحديث على طلبك #${num}`;
      }
    }
    if (log.action_type === 'picker_assigned') return `تم تعيين محضّر لطلبك #${num}`;
    if (log.action_type === 'delivery_assigned') return `تم تعيين سائق لطلبك #${num}`;
    return `تحديث على طلبك #${num}`;
  }

  function getNotificationTitleEn(log, orderNumber) {
    const num = orderNumber || '';
    if (log.action_type === 'order_created') return `Order #${num} created`;
    if (log.action_type === 'status_change') {
      switch (log.to_status) {
        case 'accepted': return `Order #${num} accepted`;
        case 'in_picking': return `Order #${num} is being prepared`;
        case 'ready': return `Order #${num} is ready`;
        case 'out_for_delivery': return `Order #${num} out for delivery`;
        case 'delivered': return `Order #${num} delivered`;
        case 'picked_up': return `Order #${num} picked up`;
        case 'cancelled': return `Order #${num} cancelled`;
        default: return `Order #${num} updated`;
      }
    }
    if (log.action_type === 'picker_assigned') return `Picker assigned for order #${num}`;
    if (log.action_type === 'delivery_assigned') return `Driver assigned for order #${num}`;
    return `Order #${num} updated`;
  }

  function getNotificationMessageAr(log) {
    if (log.action_type === 'order_created') return 'تم استلام طلبك وبانتظار التأكيد';
    if (log.action_type === 'status_change') {
      switch (log.to_status) {
        case 'accepted': return 'تم قبول طلبك وسيتم تحضيره قريباً';
        case 'in_picking': return 'فريقنا يقوم بتحضير طلبك الآن';
        case 'ready': return 'طلبك جاهز للتسليم أو الاستلام';
        case 'out_for_delivery': return 'السائق في طريقه إليك';
        case 'delivered': return 'تم تسليم طلبك بنجاح';
        case 'picked_up': return 'تم استلام طلبك من الفرع';
        case 'cancelled': return 'تم إلغاء طلبك';
        default: return 'تم تحديث حالة طلبك';
      }
    }
    if (log.action_type === 'picker_assigned') return 'تم تعيين محضّر لتجهيز طلبك';
    if (log.action_type === 'delivery_assigned') return 'تم تعيين سائق توصيل لطلبك';
    return log.notes || 'تحديث على الطلب';
  }

  function getNotificationMessageEn(log) {
    if (log.action_type === 'order_created') return 'Your order has been received and is awaiting confirmation';
    if (log.action_type === 'status_change') {
      switch (log.to_status) {
        case 'accepted': return 'Your order has been accepted and will be prepared soon';
        case 'in_picking': return 'Our team is preparing your order now';
        case 'ready': return 'Your order is ready for delivery or pickup';
        case 'out_for_delivery': return 'Driver is on the way to you';
        case 'delivered': return 'Your order has been delivered successfully';
        case 'picked_up': return 'Your order has been picked up from the branch';
        case 'cancelled': return 'Your order has been cancelled';
        default: return 'Your order status has been updated';
      }
    }
    if (log.action_type === 'picker_assigned') return 'A picker has been assigned to prepare your order';
    if (log.action_type === 'delivery_assigned') return 'A delivery driver has been assigned to your order';
    return log.notes || 'Order update';
  }

  $: texts = currentLanguage === 'ar' ? {
    title: 'الإشعارات',
    markAllRead: 'تعيين الكل كمقروء',
    noNotifications: 'لا توجد إشعارات',
    noNotificationsDesc: 'ستظهر جميع إشعاراتك هنا',
    viewOrder: 'عرض الطلب',
    loading: 'جاري التحميل...'
  } : {
    title: 'Notifications',
    markAllRead: 'Mark All Read',
    noNotifications: 'No notifications',
    noNotificationsDesc: 'All your notifications will appear here',
    viewOrder: 'View Order',
    loading: 'Loading...'
  };

  async function markAllAsRead() {
    const ids = notifications.map(n => n.id);
    notifications = [];
    // Delete from database
    if (ids.length > 0) {
      await supabase.from('order_audit_logs').delete().in('id', ids);
    }
  }

  async function markAsRead(notificationId) {
    notifications = notifications.filter(n => n.id !== notificationId);
    // Delete from database
    await supabase.from('order_audit_logs').delete().eq('id', notificationId);
  }

  function formatTime(timeString) {
    if (!timeString) return '';
    const time = new Date(timeString);
    const now = new Date();
    const diff = now - time;
    const minutes = Math.floor(diff / (1000 * 60));
    const hours = Math.floor(diff / (1000 * 60 * 60));
    
    if (minutes < 1) {
      return currentLanguage === 'ar' ? 'الآن' : 'Just now';
    } else if (minutes < 60) {
      return currentLanguage === 'ar' ? `منذ ${minutes} دقيقة` : `${minutes}m ago`;
    } else if (hours < 24) {
      return currentLanguage === 'ar' ? `منذ ${hours} ساعة` : `${hours}h ago`;
    } else {
      const days = Math.floor(hours / 24);
      return currentLanguage === 'ar' ? `منذ ${days} يوم` : `${days}d ago`;
    }
  }

  function getNotificationIcon(type) {
    switch(type) {
      case 'order_created': return '🛒';
      case 'order_confirmed': return '✅';
      case 'order_picking': return '📦';
      case 'order_ready': return '✨';
      case 'order_pickup': return '🚚';
      case 'order_delivered': return '🏠';
      case 'order_cancelled': return '❌';
      case 'order_update': return '🔔';
      default: return '🔔';
    }
  }
</script>

<svelte:head>
  <title>{texts.title} - أكوا إكسبرس | Aqua Express</title>
  <meta name="google" content="notranslate" />
  <meta name="notranslate" content="notranslate" />
</svelte:head>

<div class="notifications-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <!-- Individual floating bubbles -->
  <div class="floating-bubbles">
    <div class="bubble bubble-orange bubble-1"></div>
    <div class="bubble bubble-blue bubble-2"></div>
    <div class="bubble bubble-green bubble-3"></div>
    <div class="bubble bubble-pink bubble-4"></div>
    <div class="bubble bubble-orange bubble-5"></div>
    <div class="bubble bubble-blue bubble-6"></div>
    <div class="bubble bubble-green bubble-7"></div>
    <div class="bubble bubble-pink bubble-8"></div>
    <div class="bubble bubble-orange bubble-9"></div>
    <div class="bubble bubble-blue bubble-10"></div>
    <div class="bubble bubble-green bubble-11"></div>
    <div class="bubble bubble-pink bubble-12"></div>
    <div class="bubble bubble-orange bubble-13"></div>
    <div class="bubble bubble-blue bubble-14"></div>
    <div class="bubble bubble-green bubble-15"></div>
    <div class="bubble bubble-pink bubble-16"></div>
    <div class="bubble bubble-orange bubble-17"></div>
    <div class="bubble bubble-blue bubble-18"></div>
    <div class="bubble bubble-green bubble-19"></div>
    <div class="bubble bubble-pink bubble-20"></div>
  </div>
  <div class="page-header">
    <h1 class="page-title">{texts.title}</h1>
    {#if notifications.length > 0}
      <button class="mark-all-btn" on:click={markAllAsRead}>
        {texts.markAllRead}
      </button>
    {/if}
  </div>

  {#if loading}
    <div class="empty-notifications">
      <div class="empty-icon">⏳</div>
      <p>{texts.loading}</p>
    </div>
  {:else if notifications.length === 0}
    <div class="empty-notifications">
      <div class="empty-icon">🔔</div>
      <h2>{texts.noNotifications}</h2>
      <p>{texts.noNotificationsDesc}</p>
    </div>
  {:else}
    <div class="notifications-list">
      {#each notifications as notification}
        <button 
          class="notification-item" 
          class:unread={!notification.read}
          on:click={() => markAsRead(notification.id)}
        >
          <div class="notification-icon">
            {getNotificationIcon(notification.type)}
          </div>
          
          <div class="notification-content">
            <h3 class="notification-title">
              {currentLanguage === 'ar' ? notification.titleAr : notification.titleEn}
            </h3>
            <p class="notification-message">
              {currentLanguage === 'ar' ? notification.messageAr : notification.messageEn}
            </p>
            <span class="notification-time">
              {formatTime(notification.time)}
            </span>
          </div>
          
          {#if !notification.read}
            <div class="unread-indicator"></div>
          {/if}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .notifications-container {
    width: 100%;
    min-height: 100vh;
    margin: 0 auto;
    padding: 0.7rem;
    padding-bottom: 84px;
    max-width: 420px;
    position: relative;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    touch-action: pan-y;
    box-sizing: border-box;
    
    /* Simple neutral background with bubbles */
    background: #f8fafc;
    position: relative;
    overflow: hidden;
  }

  /* Floating bubbles container */
  .floating-bubbles {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    pointer-events: none;
    z-index: 1;
  }

  /* Individual bubble styles */
  .bubble {
    position: absolute;
    border-radius: 50%;
    pointer-events: none;
    animation-timing-function: ease-in-out;
    animation-iteration-count: infinite;
    animation-fill-mode: both;
    /* Water bubble effects */
    backdrop-filter: blur(2px);
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.4),
      inset 5px 5px 10px rgba(0, 0, 0, 0.1),
      0 0 15px rgba(255, 255, 255, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.5);
  }

  /* Water bubble colors with transparency */
  .bubble-orange { 
    background: radial-gradient(circle at 30% 30%, rgba(255, 200, 100, 0.8), rgba(255, 165, 0, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(255, 100, 0, 0.2),
      0 0 20px rgba(255, 165, 0, 0.4);
  }
  
  .bubble-blue { 
    background: radial-gradient(circle at 30% 30%, rgba(150, 200, 255, 0.8), rgba(0, 123, 255, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(0, 50, 200, 0.2),
      0 0 20px rgba(0, 123, 255, 0.4);
  }
  
  .bubble-green { 
    background: radial-gradient(circle at 30% 30%, rgba(150, 255, 150, 0.8), rgba(40, 167, 69, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(0, 100, 20, 0.2),
      0 0 20px rgba(40, 167, 69, 0.4);
  }
  
  .bubble-pink { 
    background: radial-gradient(circle at 30% 30%, rgba(255, 180, 200, 0.8), rgba(255, 20, 147, 0.6));
    box-shadow: 
      inset -5px -5px 10px rgba(255, 255, 255, 0.6),
      inset 5px 5px 10px rgba(200, 0, 100, 0.2),
      0 0 20px rgba(255, 20, 147, 0.4);
  }

  /* Individual bubble animations and positions */
  .bubble-1 {
    width: 25px; height: 25px;
    left: 10%; top: 20%;
    animation: float1 8s infinite;
  }

  .bubble-2 {
    width: 18px; height: 18px;
    left: 80%; top: 15%;
    animation: float2 10s infinite;
  }

  .bubble-3 {
    width: 32px; height: 32px;
    left: 25%; top: 60%;
    animation: float3 12s infinite;
  }

  .bubble-4 {
    width: 22px; height: 22px;
    left: 90%; top: 45%;
    animation: float4 9s infinite;
  }

  .bubble-5 {
    width: 15px; height: 15px;
    left: 15%; top: 80%;
    animation: float5 11s infinite;
  }

  .bubble-6 {
    width: 28px; height: 28px;
    left: 70%; top: 25%;
    animation: float6 7s infinite;
  }

  .bubble-7 {
    width: 20px; height: 20px;
    left: 45%; top: 10%;
    animation: float7 13s infinite;
  }

  .bubble-8 {
    width: 24px; height: 24px;
    left: 60%; top: 75%;
    animation: float8 8s infinite;
  }

  .bubble-9 {
    width: 16px; height: 16px;
    left: 5%; top: 50%;
    animation: float9 10s infinite;
  }

  .bubble-10 {
    width: 30px; height: 30px;
    left: 85%; top: 70%;
    animation: float10 9s infinite;
  }

  .bubble-11 {
    width: 19px; height: 19px;
    left: 35%; top: 30%;
    animation: float11 11s infinite;
  }

  .bubble-12 {
    width: 35px; height: 35px;
    left: 75%; top: 55%;
    animation: float12 7s infinite;
  }

  .bubble-13 {
    width: 12px; height: 12px;
    left: 20%; top: 40%;
    animation: float13 14s infinite;
  }

  .bubble-14 {
    width: 26px; height: 26px;
    left: 95%; top: 20%;
    animation: float14 8s infinite;
  }

  .bubble-15 {
    width: 21px; height: 21px;
    left: 50%; top: 85%;
    animation: float15 12s infinite;
  }

  .bubble-16 {
    width: 17px; height: 17px;
    left: 30%; top: 5%;
    animation: float16 10s infinite;
  }

  .bubble-17 {
    width: 14px; height: 14px;
    left: 65%; top: 90%;
    animation: float17 9s infinite;
  }

  .bubble-18 {
    width: 29px; height: 29px;
    left: 40%; top: 65%;
    animation: float18 11s infinite;
  }

  .bubble-19 {
    width: 13px; height: 13px;
    left: 55%; top: 35%;
    animation: float19 13s infinite;
  }

  .bubble-20 {
    width: 23px; height: 23px;
    left: 12%; top: 70%;
    animation: float20 8s infinite;
  }

  /* Floating animations - each unique */
  @keyframes float1 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(20px, -30px) scale(1.1); }
    50% { transform: translate(-15px, -10px) scale(0.9); }
    75% { transform: translate(10px, -25px) scale(1.05); }
  }

  @keyframes float2 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    33% { transform: translate(-25px, 20px) scale(0.85); }
    66% { transform: translate(15px, -15px) scale(1.15); }
  }

  @keyframes float3 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    20% { transform: translate(30px, 10px) scale(1.2); }
    40% { transform: translate(-20px, -20px) scale(0.8); }
    60% { transform: translate(25px, 15px) scale(1.1); }
    80% { transform: translate(-10px, -5px) scale(0.95); }
  }

  @keyframes float4 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(-30px, -40px) scale(1.3); }
  }

  @keyframes float5 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(15px, -25px) scale(0.7); }
    70% { transform: translate(-20px, 10px) scale(1.4); }
  }

  @keyframes float6 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(-15px, 25px) scale(1.1); }
    75% { transform: translate(20px, -15px) scale(0.9); }
  }

  @keyframes float7 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    40% { transform: translate(25px, 30px) scale(1.2); }
    80% { transform: translate(-15px, -20px) scale(0.8); }
  }

  @keyframes float8 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    35% { transform: translate(-20px, -30px) scale(1.15); }
    65% { transform: translate(30px, 20px) scale(0.85); }
  }

  @keyframes float9 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    45% { transform: translate(35px, -15px) scale(1.3); }
    90% { transform: translate(-25px, 25px) scale(0.7); }
  }

  @keyframes float10 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(-30px, 15px) scale(0.9); }
    60% { transform: translate(20px, -25px) scale(1.2); }
  }

  @keyframes float11 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(10px, 35px) scale(1.1); }
  }

  @keyframes float12 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(-35px, -10px) scale(0.8); }
    75% { transform: translate(15px, 30px) scale(1.25); }
  }

  @keyframes float13 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    40% { transform: translate(20px, -35px) scale(1.4); }
    80% { transform: translate(-30px, 20px) scale(0.6); }
  }

  @keyframes float14 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    33% { transform: translate(25px, 25px) scale(1.1); }
    66% { transform: translate(-20px, -30px) scale(0.9); }
  }

  @keyframes float15 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    20% { transform: translate(-25px, -20px) scale(1.2); }
    80% { transform: translate(30px, 10px) scale(0.8); }
  }

  @keyframes float16 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    50% { transform: translate(-10px, 40px) scale(1.3); }
  }

  @keyframes float17 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    35% { transform: translate(30px, -25px) scale(0.85); }
    70% { transform: translate(-20px, 15px) scale(1.15); }
  }

  @keyframes float18 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    25% { transform: translate(15px, -30px) scale(1.05); }
    75% { transform: translate(-25px, 20px) scale(0.95); }
  }

  @keyframes float19 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    45% { transform: translate(-15px, 30px) scale(1.25); }
    90% { transform: translate(35px, -15px) scale(0.75); }
  }

  @keyframes float20 {
    0%, 100% { transform: translate(0, 0) scale(1); }
    30% { transform: translate(20px, 20px) scale(1.1); }
    70% { transform: translate(-30px, -25px) scale(0.9); }
  }

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.05rem;
    position: relative;
    z-index: 10;
  }

  .page-title {
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--color-ink);
    margin: 0;
  }

  .mark-all-btn {
    background: white;
    color: var(--color-primary);
    border: 1px solid var(--color-primary);
    padding: 0.4rem 0.7rem;
    border-radius: 6px;
    font-size: 0.63rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .mark-all-btn:hover {
    background: var(--color-primary);
    color: white;
  }

  .empty-notifications {
    text-align: center;
    padding: 3.5rem 1.4rem;
    background: white;
    border-radius: 11px;
    box-shadow: 0 1.4px 5.6px rgba(0, 0, 0, 0.1);
    position: relative;
    z-index: 10;
  }

  .empty-icon {
    font-size: 3.5rem;
    margin-bottom: 1.05rem;
    opacity: 0.3;
  }

  .empty-notifications h2 {
    font-size: 0.91rem;
    font-weight: 600;
    color: var(--color-ink);
    margin: 0 0 0.53rem 0;
  }

  .empty-notifications p {
    font-size: 0.7rem;
    color: var(--color-ink-light);
    margin: 0;
    line-height: 1.5;
  }

  .notifications-list {
    display: flex;
    flex-direction: column;
    gap: 0.7rem;
    position: relative;
    z-index: 10;
  }

  .notification-item {
    display: flex;
    gap: 0.7rem;
    padding: 0.88rem;
    background: white;
    border: 1px solid var(--color-border-light);
    border-radius: 11px;
    position: relative;
    transition: all 0.2s ease;
    cursor: pointer;
    text-align: left;
    width: 100%;
    box-shadow: 0 1.4px 5.6px rgba(0, 0, 0, 0.1);
    align-items: flex-start;
  }

  .notification-item:hover {
    transform: translateY(-1px);
    box-shadow: 0 2.8px 8.4px rgba(0, 0, 0, 0.15);
  }

  .notification-item:active {
    transform: translateY(0);
  }

  .notification-item.unread {
    background: linear-gradient(135deg, #ffffff 0%, #f0f9ff 100%);
    border-color: var(--color-primary);
    border-width: 1.5px;
  }

  .notification-icon {
    font-size: 1.75rem;
    flex-shrink: 0;
    line-height: 1;
  }

  .notification-content {
    flex: 1;
    min-width: 0;
  }

  .notification-title {
    margin: 0 0 0.35rem 0;
    color: var(--color-ink);
    font-size: 0.7rem;
    font-weight: 600;
    line-height: 1.3;
  }

  .notification-message {
    margin: 0 0 0.35rem 0;
    color: var(--color-ink-light);
    font-size: 0.63rem;
    line-height: 1.4;
  }

  .notification-time {
    color: var(--color-ink-light);
    font-size: 0.56rem;
    opacity: 0.7;
  }

  .unread-indicator {
    position: absolute;
    top: 0.88rem;
    right: 0.88rem;
    width: 8px;
    height: 8px;
    background: var(--color-primary);
    border-radius: 50%;
    box-shadow: 0 0 0 2px white;
  }

  /* RTL adjustments */
  [dir="rtl"] .unread-indicator {
    right: auto;
    left: 0.88rem;
  }

  /* Mobile optimizations for bubbles */
  @media (max-width: 480px) {
    .bubble {
      transform: scale(0.6);
      box-shadow: 
        inset -3px -3px 6px rgba(255, 255, 255, 0.4),
        inset 3px 3px 6px rgba(0, 0, 0, 0.1),
        0 0 8px rgba(255, 255, 255, 0.3);
    }
  }
</style>
