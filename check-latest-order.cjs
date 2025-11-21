const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables
const envPath = './frontend/.env';
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabase = createClient(
  envVars.VITE_SUPABASE_URL,
  envVars.VITE_SUPABASE_SERVICE_ROLE_KEY
);

(async () => {
  console.log('Checking latest orders...\n');
  
  // Get latest orders
  const { data: orders, error: ordersError } = await supabase
    .from('orders')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(5);
  
  if (ordersError) {
    console.error('❌ Error fetching orders:', ordersError.message);
  } else if (orders && orders.length > 0) {
    console.log(`✅ Found ${orders.length} orders:\n`);
    orders.forEach((order, i) => {
      console.log(`${i + 1}. Order #${order.order_number}`);
      console.log(`   ID: ${order.id}`);
      console.log(`   Customer: ${order.customer_name}`);
      console.log(`   Status: ${order.order_status}`);
      console.log(`   Total: ${order.total_amount} SAR`);
      console.log(`   Created: ${order.created_at}`);
      console.log('');
    });
  } else {
    console.log('⚠️ No orders found in database');
  }
  
  console.log('='.repeat(80) + '\n');
  
  // Check order items for latest order
  if (orders && orders.length > 0) {
    const latestOrderId = orders[0].id;
    console.log(`Checking order items for order ${orders[0].order_number}...\n`);
    
    const { data: items, error: itemsError } = await supabase
      .from('order_items')
      .select('*')
      .eq('order_id', latestOrderId);
    
    if (itemsError) {
      console.error('❌ Error fetching order items:', itemsError.message);
    } else if (items && items.length > 0) {
      console.log(`✅ Found ${items.length} items:\n`);
      items.forEach((item, i) => {
        console.log(`${i + 1}. ${item.product_name_ar} (${item.product_name_en})`);
        console.log(`   Quantity: ${item.quantity}`);
        console.log(`   Price: ${item.final_price} SAR`);
        console.log(`   Total: ${item.line_total} SAR`);
        console.log('');
      });
    } else {
      console.log('⚠️ No items found for this order');
    }
  }
  
  console.log('='.repeat(80) + '\n');
  
  // Check notifications
  console.log('Checking latest notifications...\n');
  
  const { data: notifications, error: notifError } = await supabase
    .from('notifications')
    .select('*')
    .eq('type', 'order_new')
    .order('created_at', { ascending: false })
    .limit(5);
  
  if (notifError) {
    console.error('❌ Error fetching notifications:', notifError.message);
  } else if (notifications && notifications.length > 0) {
    console.log(`✅ Found ${notifications.length} order notifications:\n`);
    notifications.forEach((notif, i) => {
      console.log(`${i + 1}. ${notif.title}`);
      console.log(`   Message: ${notif.message}`);
      console.log(`   Status: ${notif.status}`);
      console.log(`   Target: ${notif.target_type}`);
      console.log(`   Created: ${notif.created_at}`);
      console.log('');
    });
  } else {
    console.log('⚠️ No order notifications found');
  }
})();
