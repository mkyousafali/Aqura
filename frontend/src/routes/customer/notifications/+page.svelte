<script>
  import { onMount } from 'svelte';
  
  let currentLanguage = 'ar';

  // Load language from localStorage
  onMount(() => {
    const savedLanguage = localStorage.getItem('language');
    if (savedLanguage) {
      currentLanguage = savedLanguage;
    }
  });

  // Listen for language changes
  function handleStorageChange(event) {
    if (event.key === 'language') {
      currentLanguage = event.newValue || 'ar';
    }
  }

  onMount(() => {
    window.addEventListener('storage', handleStorageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  });
  
  let notifications = [
    {
      id: 1,
      type: 'order_delivered',
      titleAr: 'تم تسليم طلبك #2847',
      titleEn: 'Your order #2847 has been delivered',
      messageAr: 'تم تسليم طلبك بنجاح',
      messageEn: 'Your order has been successfully delivered',
      time: '2024-09-28T14:30:00',
      read: false
    },
    {
      id: 2,
      type: 'order_pickup',
      titleAr: 'تم استلام طلبك #2856',
      titleEn: 'Your order #2856 has been picked up',
      messageAr: 'قام السائق باستلام طلبك وهو في طريقه إليك',
      messageEn: 'Driver has picked up your order and is on the way',
      time: '2024-10-01T13:15:00',
      read: false
    },
    {
      id: 3,
      type: 'order_confirmed',
      titleAr: 'تم تأكيد طلبك #2865',
      titleEn: 'Your order #2865 has been confirmed',
      messageAr: 'تم تأكيد طلبك وجاري تحضيره',
      messageEn: 'Your order has been confirmed and is being prepared',
      time: '2024-10-01T12:00:00',
      read: true
    }
  ];

  $: texts = currentLanguage === 'ar' ? {
    title: 'الإشعارات',
    markAllRead: 'تعيين الكل كمقروء',
    noNotifications: 'لا توجد إشعارات',
    noNotificationsDesc: 'ستظهر جميع إشعاراتك هنا',
    viewOrder: 'عرض الطلب'
  } : {
    title: 'Notifications',
    markAllRead: 'Mark All Read',
    noNotifications: 'No notifications',
    noNotificationsDesc: 'All your notifications will appear here',
    viewOrder: 'View Order'
  };

  function markAllAsRead() {
    notifications = notifications.map(n => ({ ...n, read: true }));
  }

  function markAsRead(notificationId) {
    notifications = notifications.map(n => 
      n.id === notificationId ? { ...n, read: true } : n
    );
  }

  function formatTime(timeString) {
    const time = new Date(timeString);
    const now = new Date();
    const diff = now - time;
    const hours = Math.floor(diff / (1000 * 60 * 60));
    
    if (hours < 1) {
      return currentLanguage === 'ar' ? 'منذ قليل' : 'Just now';
    } else if (hours < 24) {
      return currentLanguage === 'ar' ? `منذ ${hours} ساعة` : `${hours}h ago`;
    } else {
      const days = Math.floor(hours / 24);
      return currentLanguage === 'ar' ? `منذ ${days} يوم` : `${days}d ago`;
    }
  }

  function getNotificationIcon(type) {
    switch(type) {
      case 'order_delivered': return '✅';
      case 'order_pickup': return '🚚';
      case 'order_confirmed': return '📦';
      case 'order_cancelled': return '❌';
      case 'promotion': return '🎉';
      default: return '🔔';
    }
  }
</script>

<svelte:head>
  <title>{texts.title} - أكوا إكسبرس | Aqua Express</title>
</svelte:head>

<div class="notifications-container" dir={currentLanguage === 'ar' ? 'rtl' : 'ltr'}>
  <div class="page-header">
    <h1 class="page-title">{texts.title}</h1>
    {#if notifications.some(n => !n.read)}
      <button class="mark-all-btn" on:click={markAllAsRead}>
        {texts.markAllRead}
      </button>
    {/if}
  </div>

  {#if notifications.length === 0}
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
    
    /* Gradient background matching home page */
    background: linear-gradient(180deg, #7ce5a5 0%, #5edda0 40%, #4dd99b 100%);
  }

  /* Orange wave - bottom layer with animation */
  .notifications-container::before {
    content: '';
    position: fixed;
    width: 200%;
    height: 150px;
    bottom: 0;
    left: -50%;
    z-index: 0;
    background: #FF5C00;
    border-radius: 50% 50% 0 0 / 100% 100% 0 0;
    animation: wave 8s ease-in-out infinite;
    pointer-events: none;
  }

  /* Second wave - lighter orange */
  .notifications-container::after {
    content: '';
    position: fixed;
    width: 200%;
    height: 120px;
    bottom: 0;
    left: -50%;
    z-index: 1;
    background: rgba(255, 140, 0, 0.5);
    border-radius: 50% 50% 0 0 / 80% 80% 0 0;
    animation: wave 6s ease-in-out infinite reverse;
    pointer-events: none;
  }

  @keyframes wave {
    0%, 100% {
      transform: translateX(0) translateY(0);
    }
    50% {
      transform: translateX(-25%) translateY(-10px);
    }
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
</style>
