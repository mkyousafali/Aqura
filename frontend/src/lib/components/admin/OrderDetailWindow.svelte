<script lang="ts">
  import { onMount } from 'svelte';
  import { supabaseAdmin } from '$lib/utils/supabase';
  import { notifications } from '$lib/stores/notifications';
  import { t, currentLocale } from '$lib/i18n';
  import { currentUser } from '$lib/utils/persistentAuth';
  import JsBarcode from 'jsbarcode';

  export let orderId: string;
  export let orderNumber: string = '';

  // Reactive RTL check
  $: isRTL = $currentLocale === 'ar';

  let order: any = null;
  let loading = true;

  // User assignment
  let availablePickers: any[] = [];
  let availableDelivery: any[] = [];
  let pickerWorkload: { [key: string]: number } = {};
  let deliveryWorkload: { [key: string]: number } = {};
  let selectedPickerId: string = '';
  let selectedDeliveryId: string = '';
  let showPickerDropdown = false;
  let showDeliveryDropdown = false;
  let pickerSearchQuery: string = '';
  let deliverySearchQuery: string = '';

  // Filtered user lists based on search
  $: filteredPickers = availablePickers.filter(picker => 
    picker.username.toLowerCase().includes(pickerSearchQuery.toLowerCase())
  );

  $: filteredDelivery = availableDelivery.filter(delivery => 
    delivery.username.toLowerCase().includes(deliverySearchQuery.toLowerCase())
  );

  // Print modal state
  let showPrintOrderModal = false;

  // Location modal state
  let showLocationModal = false;

  // Barcode canvas refs for each product
  let productBarcodeCanvases: { [key: number]: HTMLCanvasElement } = {};

  // User's current location for distance calculation
  let userLat: number | null = null;
  let userLng: number | null = null;
  let locationPermissionDenied = false;

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
    new: isRTL ? 'جديد' : 'New',
    accepted: isRTL ? 'مقبول' : 'Accepted',
    in_picking: isRTL ? 'قيد التحضير' : 'In Picking',
    ready: isRTL ? 'جاهز' : 'Ready',
    out_for_delivery: isRTL ? 'قيد التوصيل' : 'Out for Delivery',
    delivered: isRTL ? 'تم التوصيل' : 'Delivered',
    cancelled: isRTL ? 'ملغي' : 'Cancelled'
  };

  onMount(async () => {
    getUserLocation();
    await loadUsers();
    await loadOrderDetails();
  });

  // Get user's current location
  function getUserLocation() {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          userLat = position.coords.latitude;
          userLng = position.coords.longitude;
          console.log('📍 User location:', userLat, userLng);
        },
        (error) => {
          console.warn('⚠️ Location permission denied or unavailable:', error.message);
          locationPermissionDenied = true;
        }
      );
    }
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

  // Get distance to delivery location
  function getDistanceToLocation(location: any): string {
    if (!location?.lat || !location?.lng || userLat === null || userLng === null) {
      return isRTL ? 'غير متوفر' : 'N/A';
    }
    const distance = calculateDistance(userLat, userLng, location.lat, location.lng);
    return `${distance.toFixed(2)} ${isRTL ? 'كم' : 'km'}`;
  }

  async function loadUsers() {
    try {
      const { data, error } = await supabaseAdmin.from('users')
        .select('id, username')
        .eq('status', 'active')
        .order('username');

      if (error) throw error;

      availablePickers = data || [];
      availableDelivery = data || [];

      // Calculate workload for each user
      const { data: workloadData, error: workloadError } = await supabaseAdmin.from('orders')
        .select('picker_id, delivery_person_id')
        .in('order_status', ['accepted', 'in_picking', 'ready', 'out_for_delivery']);

      if (!workloadError && workloadData) {
        workloadData.forEach((order: any) => {
          if (order.picker_id) {
            pickerWorkload[order.picker_id] = (pickerWorkload[order.picker_id] || 0) + 1;
          }
          if (order.delivery_person_id) {
            deliveryWorkload[order.delivery_person_id] = (deliveryWorkload[order.delivery_person_id] || 0) + 1;
          }
        });
      }
    } catch (error: any) {
      console.error('Error loading users:', error);
    }
  }

  async function loadOrderDetails() {
    try {
      loading = true;
      const { data: orderData, error: orderError } = await supabaseAdmin.from('orders')
        .select(`
          *,
          customer:customers(id, name, whatsapp_number, location1_name, location1_url, location2_name, location2_url, location3_name, location3_url),
          branch:branches(id, name_ar, name_en),
          picker:users!picker_id(id, username),
          delivery:users!delivery_person_id(id, username),
          items:order_items(
            *,
            product:products(barcode, image_url)
          ),
          audit_logs:order_audit_logs(*)
        `)
        .eq('id', orderId)
        .single();

      if (orderError) throw orderError;

      order = orderData;
      selectedPickerId = orderData.picker_id || '';
      selectedDeliveryId = orderData.delivery_person_id || '';
    } catch (error: any) {
      console.error('Error loading order details:', error);
      notifications.add({
        message: isRTL ? 'فشل تحميل تفاصيل الطلب' : 'Failed to load order details',
        type: 'error'
      });
    } finally {
      loading = false;
    }
  }

  // Location modal handlers
  function openLocationModal() {
    showLocationModal = true;
  }

  function closeLocationModal() {
    showLocationModal = false;
  }

  // Print order slip
  function printOrder() {
    // Convert canvas barcodes to base64 images
    const barcodeImages: { [key: number]: string } = {};
    order.items.forEach((item: any, index: number) => {
      if (item.product?.barcode && productBarcodeCanvases[index]) {
        try {
          barcodeImages[index] = productBarcodeCanvases[index].toDataURL('image/png');
        } catch (error) {
          console.error('Error converting barcode to image:', error);
        }
      }
    });

    // Build table rows
    let tableRows = '';
    order.items.forEach((item: any, index: number) => {
      const imageHtml = item.product?.image_url 
        ? `<img src="${item.product.image_url}" alt="${item.product_name_en}" class="product-print-image" />`
        : `<div class="product-image-placeholder">📦</div>`;

      const barcodeHtml = barcodeImages[index]
        ? `<img src="${barcodeImages[index]}" alt="Barcode" style="max-width: 120px; height: auto;" /><div class="barcode-text">${item.product.barcode}</div>`
        : `<span style="color: #9ca3af;">-</span>`;

      tableRows += `
        <tr>
          <td>${index + 1}</td>
          <td><div class="product-image-cell">${imageHtml}</div></td>
          <td>
            <div class="product-name">${item.product_name_en}</div>
            <div class="product-name-ar">${item.product_name_ar}</div>
          </td>
          <td><div class="product-barcode-cell">${barcodeHtml}</div></td>
          <td>
            <div>${item.quantity}</div>
            <div class="unit-names">
              <div>${item.unit_name_en}</div>
              <div class="unit-name-ar">${item.unit_name_ar}</div>
            </div>
          </td>
          <td>${item.unit_price.toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</td>
          <td>${item.line_total.toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</td>
        </tr>
      `;
    });

    // Build summary rows
    let summaryRows = `
      <div class="summary-row">
        <span>${isRTL ? 'المجموع الفرعي:' : 'Subtotal:'}</span>
        <span>${order.subtotal_amount.toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</span>
      </div>
    `;
    
    if (order.delivery_fee > 0) {
      summaryRows += `
        <div class="summary-row">
          <span>${isRTL ? 'رسوم التوصيل:' : 'Delivery Fee:'}</span>
          <span>${order.delivery_fee.toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</span>
        </div>
      `;
    }
    
    if (order.discount_amount > 0) {
      summaryRows += `
        <div class="summary-row discount">
          <span>${isRTL ? 'الخصم:' : 'Discount:'}</span>
          <span>-${order.discount_amount.toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</span>
        </div>
      `;
    }
    
    if (order.tax_amount > 0) {
      summaryRows += `
        <div class="summary-row">
          <span>${isRTL ? 'الضريبة:' : 'Tax:'}</span>
          <span>${order.tax_amount.toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</span>
        </div>
      `;
    }
    
    summaryRows += `
      <div class="summary-row total">
        <span><strong>${isRTL ? 'الإجمالي النهائي:' : 'Total Amount:'}</strong></span>
        <span><strong>${order.total_amount.toFixed(2)} ${isRTL ? 'ريال' : 'SAR'}</strong></span>
      </div>
    `;

    const pickerInfo = order.picker ? `
      <div class="print-section">
        <div class="print-info-grid">
          <div><strong>${isRTL ? 'المحضّر:' : 'Picker:'}</strong> ${order.picker.username}</div>
          <div><strong>${isRTL ? 'تاريخ التعيين:' : 'Assigned:'}</strong> ${new Date(order.picker_assigned_at).toLocaleString()}</div>
        </div>
      </div>
    ` : '';

    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>Order Slip - ${order.order_number}</title>
        <style>
          @page { size: A4; margin: 1cm; }
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            padding: 1cm;
            background: white;
          }
          .print-order-header { text-align: center; margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 2px solid #e5e7eb; }
          .print-order-header h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
          .order-info-row { display: flex; justify-content: space-between; font-size: 0.875rem; color: #6b7280; }
          .print-section { margin-bottom: 1.5rem; }
          .print-section-title { font-size: 1.125rem; font-weight: 600; color: #1f2937; margin: 0 0 1rem 0; padding-bottom: 0.5rem; border-bottom: 2px solid #e5e7eb; }
          .print-info-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.75rem; font-size: 0.875rem; }
          .print-table { width: 100%; border-collapse: collapse; font-size: 0.875rem; margin-top: 1rem; }
          .print-table thead { background: #f9fafb; }
          .print-table th { padding: 0.75rem; text-align: left; font-weight: 600; color: #374151; border: 1px solid #e5e7eb; }
          .print-table td { padding: 0.75rem; border: 1px solid #e5e7eb; color: #6b7280; }
          .product-name { font-weight: 500; color: #374151; font-size: 0.875rem; }
          .product-name-ar { font-size: 0.75rem; color: #6b7280; margin-top: 0.125rem; direction: rtl; }
          .unit-names { margin-top: 0.25rem; font-size: 0.75rem; color: #6b7280; }
          .unit-name-ar { direction: rtl; color: #9ca3af; font-size: 0.7rem; }
          .product-image-cell { display: flex; align-items: center; justify-content: center; padding: 0.25rem; }
          .product-print-image { width: 60px; height: 60px; object-fit: cover; border-radius: 0.375rem; border: 1px solid #e5e7eb; }
          .product-image-placeholder { width: 60px; height: 60px; display: flex; align-items: center; justify-content: center; background: #f3f4f6; border-radius: 0.375rem; border: 1px solid #e5e7eb; font-size: 1.5rem; }
          .product-barcode-cell { display: flex; flex-direction: column; align-items: center; gap: 0.25rem; }
          .barcode-text { font-size: 0.75rem; color: #6b7280; font-family: monospace; }
          .print-summary { margin-top: 1.5rem; padding: 1rem; background: #f9fafb; border-radius: 0.5rem; }
          .summary-row { display: flex; justify-content: space-between; padding: 0.5rem 0; font-size: 0.875rem; }
          .summary-row.discount { color: #059669; }
          .summary-row.total { font-size: 1.125rem; border-top: 2px solid #10b981; padding-top: 1rem; margin-top: 0.5rem; font-weight: bold; }
          .print-footer { text-align: center; margin-top: 3rem; padding-top: 1.5rem; border-top: 2px solid #e5e7eb; color: #9ca3af; font-size: 0.875rem; }
        </style>
      </head>
      <body>
        <!-- Header -->
        <div class="print-order-header">
          <h1>${isRTL ? 'بوليصة الطلب' : 'Order Slip'}</h1>
          <div class="order-info-row">
            <div><strong>${isRTL ? 'رقم الطلب:' : 'Order #:'}</strong> <span>${order.order_number}</span></div>
            <div><strong>${isRTL ? 'التاريخ:' : 'Date:'}</strong> <span>${new Date(order.created_at).toLocaleDateString()}</span></div>
          </div>
        </div>

        <!-- Customer Details -->
        <div class="print-section">
          <h3 class="print-section-title">${isRTL ? 'معلومات العميل' : 'Customer Information'}</h3>
          <div class="print-info-grid">
            <div><strong>${isRTL ? 'الاسم:' : 'Name:'}</strong> ${order.customer_name}</div>
            <div><strong>${isRTL ? 'الهاتف:' : 'Phone:'}</strong> ${order.customer_phone}</div>
          </div>
        </div>

        <!-- Order Items -->
        <div class="print-section">
          <h3 class="print-section-title">${isRTL ? 'المنتجات' : 'Order Items'}</h3>
          <table class="print-table">
            <thead>
              <tr>
                <th>${isRTL ? '#' : '#'}</th>
                <th>${isRTL ? 'الصورة' : 'Image'}</th>
                <th>${isRTL ? 'المنتج' : 'Product'}</th>
                <th>${isRTL ? 'الباركود' : 'Barcode'}</th>
                <th>${isRTL ? 'الكمية' : 'Qty'}</th>
                <th>${isRTL ? 'السعر' : 'Price'}</th>
                <th>${isRTL ? 'الإجمالي' : 'Total'}</th>
              </tr>
            </thead>
            <tbody>
              ${tableRows}
            </tbody>
          </table>
        </div>

        <!-- Order Summary -->
        <div class="print-section">
          <div class="print-summary">
            ${summaryRows}
          </div>
        </div>

        <!-- Picker Info -->
        ${pickerInfo}

        <!-- Footer -->
        <div class="print-footer">
          <p>${isRTL ? 'شكراً لتعاملكم معنا' : 'Thank you for your business'}</p>
        </div>
      </body>
      </html>
    `;

    // Create a new window for printing
    const printWindow = window.open('', '_blank', 'width=800,height=600');
    if (!printWindow) return;

    printWindow.document.write(htmlContent);
    printWindow.document.close();
    
    // Wait for images to load, then print
    setTimeout(() => {
      printWindow.focus();
      printWindow.print();
      printWindow.close();
    }, 500);
  }

  // Generate barcodes for products when modal opens
  $: if (showPrintOrderModal && order && order.items) {
    setTimeout(() => {
      order.items.forEach((item: any, index: number) => {
        if (item.product?.barcode && productBarcodeCanvases[index]) {
          try {
            JsBarcode(productBarcodeCanvases[index], item.product.barcode, {
              format: 'CODE128',
              width: 1.5,
              height: 40,
              displayValue: false,
              margin: 5
            });
          } catch (error) {
            console.error(`Error generating barcode for product ${item.product.barcode}:`, error);
          }
        }
      });
    }, 100);
  }

  // Convert Google Maps URL to embeddable format
  function getEmbedMapUrl(location: any): string {
    if (!location?.lat || !location?.lng) return '';
    
    // Use Google Maps Embed API with coordinates
    // Format: https://maps.google.com/maps?q=lat,lng&output=embed
    return `https://maps.google.com/maps?q=${location.lat},${location.lng}&output=embed&z=15`;
  }

  // Assignment handlers
  async function assignPicker(pickerId: string) {
    // Validate: Order must be accepted before assigning picker
    if (order.order_status === 'new') {
      notifications.add({
        message: isRTL ? 'يجب قبول الطلب أولاً قبل تعيين المحضّر' : 'Order must be accepted before assigning picker',
        type: 'error'
      });
      showPickerDropdown = false;
      return;
    }

    try {
      const { error } = await supabaseAdmin.from('orders')
        .update({ 
          picker_id: pickerId,
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id);

      if (error) throw error;

      // Get picker details
      const pickerUser = availablePickers.find(p => p.id === pickerId);

      // Create a quick task for the picker to start picking
      const { data: taskData, error: taskError } = await supabaseAdmin
        .from('quick_tasks')
        .insert({
          title: isRTL ? `تحضير طلب #${order.order_number}` : `Pick Order #${order.order_number}`,
          description: isRTL 
            ? `قم بتحضير المنتجات للطلب رقم ${order.order_number}\nالعميل: ${order.customer_name}\nعنوان التوصيل: ${order.customer_address}`
            : `Pick products for order #${order.order_number}\nCustomer: ${order.customer_name}\nDelivery Address: ${order.customer_address}`,
          priority: 'high',
          issue_type: 'order-picking',
          price_tag: 'high',
          assigned_by: $currentUser?.id,
          assigned_to_branch_id: order.branch_id,
          deadline_datetime: new Date(Date.now() + 10 * 60 * 1000).toISOString(), // 10 minutes from now
          require_task_finished: true,
          require_photo_upload: false,
          require_erp_reference: false
        })
        .select()
        .single();

      if (taskError) {
        console.error('Error creating picker task:', taskError);
        // Continue even if task creation fails
      } else if (taskData) {
        // Assign the task to the picker
        const { error: assignmentError } = await supabaseAdmin
          .from('quick_task_assignments')
          .insert({
            quick_task_id: taskData.id,
            assigned_to_user_id: pickerId,
            require_task_finished: true,
            require_photo_upload: false,
            require_erp_reference: false
          });

        if (assignmentError) {
          console.error('Error assigning picker task:', assignmentError);
        } else {
          console.log('✅ Picker task created and assigned successfully');
        }
      }

      // Log the assignment in audit_logs
      await supabaseAdmin.from('order_audit_logs').insert({
        order_id: order.id,
        action_type: 'assignment',
        assignment_type: 'picker',
        assigned_user_id: pickerId,
        assigned_user_name: pickerUser?.username,
        performed_by: $currentUser?.id,
        performed_by_name: $currentUser?.username,
        performed_by_role: $currentUser?.role,
        notes: `Picker assigned: ${pickerUser?.username}`
      });

      notifications.add({
        message: isRTL ? 'تم تعيين المحضّر بنجاح' : 'Picker assigned successfully',
        type: 'success'
      });

      await loadOrderDetails();
      showPickerDropdown = false;
      pickerSearchQuery = '';
    } catch (error: any) {
      console.error('Error assigning picker:', error);
      notifications.add({
        message: isRTL ? 'فشل تعيين المحضّر' : 'Failed to assign picker',
        type: 'error'
      });
    }
  }

  async function assignDelivery(deliveryId: string) {
    // Validate: Picker must be assigned before assigning delivery person
    if (!order.picker_id) {
      notifications.add({
        message: isRTL ? 'يجب تعيين المحضّر أولاً قبل تعيين مندوب التوصيل' : 'Picker must be assigned before assigning delivery person',
        type: 'error'
      });
      showDeliveryDropdown = false;
      return;
    }

    try {
      const { error } = await supabaseAdmin.from('orders')
        .update({ 
          delivery_person_id: deliveryId,
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id);

      if (error) throw error;

      // Get delivery person details
      const deliveryUser = availableDelivery.find(d => d.id === deliveryId);

      // Create a quick task for the delivery person
      const { data: taskData, error: taskError } = await supabaseAdmin
        .from('quick_tasks')
        .insert({
          title: isRTL ? `توصيل طلب #${order.order_number}` : `Deliver Order #${order.order_number}`,
          description: isRTL 
            ? `قم بتوصيل الطلب رقم ${order.order_number}\nالعميل: ${order.customer_name}\nرقم الهاتف: ${order.customer_phone}\nعنوان التوصيل: ${order.customer_address}\n\nملاحظة: يجب تحميل صورة إثبات التسليم لإكمال المهمة`
            : `Deliver order #${order.order_number}\nCustomer: ${order.customer_name}\nPhone: ${order.customer_phone}\nDelivery Address: ${order.customer_address}\n\nNote: Photo proof of delivery is required to complete this task`,
          priority: 'high',
          issue_type: 'order-delivery',
          price_tag: 'high',
          assigned_by: $currentUser?.id,
          assigned_to_branch_id: order.branch_id,
          deadline_datetime: new Date(Date.now() + 15 * 60 * 1000).toISOString(), // 15 minutes from now
          require_task_finished: true,
          require_photo_upload: true,
          require_erp_reference: false
        })
        .select()
        .single();

      if (taskError) {
        console.error('Error creating delivery task:', taskError);
        // Continue even if task creation fails
      } else if (taskData) {
        // Assign the task to the delivery person
        const { error: assignmentError } = await supabaseAdmin
          .from('quick_task_assignments')
          .insert({
            quick_task_id: taskData.id,
            assigned_to_user_id: deliveryId,
            require_task_finished: true,
            require_photo_upload: true,
            require_erp_reference: false
          });

        if (assignmentError) {
          console.error('Error assigning delivery task:', assignmentError);
        } else {
          console.log('✅ Delivery task created and assigned successfully');
        }
      }

      // Log the assignment in audit_logs
      await supabaseAdmin.from('order_audit_logs').insert({
        order_id: order.id,
        action_type: 'assignment',
        assignment_type: 'delivery',
        assigned_user_id: deliveryId,
        assigned_user_name: deliveryUser?.username,
        performed_by: $currentUser?.id,
        performed_by_name: $currentUser?.username,
        performed_by_role: $currentUser?.role,
        notes: `Delivery person assigned: ${deliveryUser?.username}`
      });

      notifications.add({
        message: isRTL ? 'تم تعيين مندوب التوصيل بنجاح' : 'Delivery person assigned successfully',
        type: 'success'
      });

      await loadOrderDetails();
      showDeliveryDropdown = false;
      deliverySearchQuery = '';
    } catch (error: any) {
      console.error('Error assigning delivery:', error);
      notifications.add({
        message: isRTL ? 'فشل تعيين مندوب التوصيل' : 'Failed to assign delivery person',
        type: 'error'
      });
    }
  }

  // Status update handlers
  async function acceptOrder() {
    try {
      const { error } = await supabaseAdmin.from('orders')
        .update({ 
          order_status: 'accepted',
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id);

      if (error) throw error;

      await supabaseAdmin.from('order_audit_logs').insert({
        order_id: order.id,
        action_type: 'status_change',
        from_status: order.order_status,
        to_status: 'accepted',
        performed_by: $currentUser?.id,
        performed_by_name: $currentUser?.username,
        performed_by_role: $currentUser?.role,
        notes: 'Order accepted'
      });

      notifications.add({
        message: isRTL ? 'تم قبول الطلب بنجاح' : 'Order accepted successfully',
        type: 'success'
      });

      await loadOrderDetails();
    } catch (error: any) {
      console.error('Error accepting order:', error);
      notifications.add({
        message: isRTL ? 'فشل قبول الطلب' : 'Failed to accept order',
        type: 'error'
      });
    }
  }

  async function cancelOrder() {
    if (!confirm(isRTL ? 'هل أنت متأكد من إلغاء هذا الطلب؟' : 'Are you sure you want to cancel this order?')) {
      return;
    }

    try {
      const { error } = await supabaseAdmin.from('orders')
        .update({ 
          order_status: 'cancelled',
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id);

      if (error) throw error;

      await supabaseAdmin.from('order_audit_logs').insert({
        order_id: order.id,
        action_type: 'status_change',
        from_status: order.order_status,
        to_status: 'cancelled',
        performed_by: $currentUser?.id,
        performed_by_name: $currentUser?.username,
        performed_by_role: $currentUser?.role,
        notes: 'Order cancelled'
      });

      notifications.add({
        message: isRTL ? 'تم إلغاء الطلب' : 'Order cancelled',
        type: 'info'
      });

      await loadOrderDetails();
    } catch (error: any) {
      console.error('Error cancelling order:', error);
      notifications.add({
        message: isRTL ? 'فشل إلغاء الطلب' : 'Failed to cancel order',
        type: 'error'
      });
    }
  }

  function openPrintModal(type: 'slip' | 'delivery' | 'invoice') {
    printType = type;
    showPrintModal = true;
  }

  function print() {
    if (!printType) return;
    
    // TODO: Implement actual printing functionality
    console.log(`Printing ${printType} for order ${order.order_number}`);
    
    notifications.add({
      message: isRTL ? 'سيتم تنفيذ الطباعة قريباً' : 'Printing will be implemented soon',
      type: 'info'
    });
    
    showPrintModal = false;
    printType = null;
  }
</script>

<div class="order-detail-window" dir={isRTL ? 'rtl' : 'ltr'}>
  {#if loading}
    <div class="loading-state">
      <div class="spinner"></div>
      <p>{t('common.loading', 'Loading...')}</p>
    </div>
  {:else if order}
    <div class="order-layout">
      <!-- Main Content Area -->
      <div class="order-main-content">
        <!-- Status Badge -->
        <div class="mb-4">
          <span class="status-badge {statusColors[order.order_status]} text-lg px-4 py-2">
            {statusLabels[order.order_status]}
          </span>
        </div>

        <!-- 1. Customer Info Section -->
        <div class="detail-section">
          <h3 class="section-title">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
            </svg>
            {t('orders.detail.customer', 'Customer Information')}
          </h3>
          <div class="detail-grid">
            <div class="detail-item">
              <span class="detail-label">{t('orders.detail.name', 'Name')}</span>
              <span class="detail-value">{order.customer_name}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">{t('orders.detail.phone', 'Phone Number')}</span>
              <span class="detail-value">{order.customer_phone}</span>
            </div>
            <div class="detail-item col-span-2">
              <span class="detail-label">{t('orders.detail.address', 'Delivery Address')}</span>
              <span class="detail-value">{order.customer_address}</span>
            </div>
            {#if order.selected_location}
              <div class="detail-item col-span-2">
                <span class="detail-label">{isRTL ? 'موقع التوصيل' : 'Delivery Location'}</span>
                <div class="location-buttons">
                  <button class="view-location-btn" on:click={openLocationModal}>
                    📍 {order.selected_location.name || (isRTL ? 'عرض الموقع' : 'View Location')}
                  </button>
                  <span class="location-distance">
                    {#if userLat !== null && userLng !== null}
                      🚗 {getDistanceToLocation(order.selected_location)}
                    {:else if locationPermissionDenied}
                      <span class="text-gray-400 text-xs">{isRTL ? '(اسمح بالوصول للموقع)' : '(Allow location access)'}</span>
                    {:else}
                      <span class="text-gray-400 text-xs">{isRTL ? '(جارٍ تحديد الموقع...)' : '(Detecting location...)'}</span>
                    {/if}
                  </span>
                </div>
              </div>
            {/if}
          </div>
        </div>
        <!-- 2. Order Items Section -->
      <div class="detail-section">
        <h3 class="section-title">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/>
          </svg>
          {t('orders.detail.items', 'Order Items')}
        </h3>
        <div class="items-list">
          {#each order.items as item}
            <div class="item-card">
              <!-- Product Image -->
              <div class="item-image-container">
                {#if item.product?.image_url}
                  <img src={item.product.image_url} alt={isRTL ? item.product_name_ar : item.product_name_en} class="item-image" />
                {:else}
                  <div class="item-image-placeholder">
                    <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                    </svg>
                  </div>
                {/if}
              </div>

              <!-- Product Details -->
              <div class="item-details-container">
                <div class="item-header">
                  <h4 class="item-name">{isRTL ? item.product_name_ar : item.product_name_en}</h4>
                  <span class="item-total">{item.line_total} {t('common.sar', 'SAR')}</span>
                </div>

                <div class="item-info-grid">
                  <!-- Barcode -->
                  {#if item.product?.barcode}
                    <div class="item-info-item">
                      <svg class="item-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                      </svg>
                      <span class="item-label">{isRTL ? 'الباركود:' : 'Barcode:'}</span>
                      <span class="item-value">{item.product.barcode}</span>
                    </div>
                  {/if}

                  <!-- Unit Info -->
                  <div class="item-info-item">
                    <svg class="item-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
                    </svg>
                    <span class="item-label">{isRTL ? 'الوحدة:' : 'Unit:'}</span>
                    <span class="item-value">{isRTL ? item.unit_name_ar : item.unit_name_en}</span>
                  </div>

                  <!-- Quantity -->
                  <div class="item-info-item">
                    <svg class="item-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14"/>
                    </svg>
                    <span class="item-label">{isRTL ? 'الكمية:' : 'Quantity:'}</span>
                    <span class="item-value font-semibold">{item.quantity}</span>
                  </div>

                  <!-- Unit Price -->
                  <div class="item-info-item">
                    <svg class="item-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                    <span class="item-label">{isRTL ? 'سعر الوحدة:' : 'Unit Price:'}</span>
                    <span class="item-value">{item.unit_price} {t('common.sar', 'SAR')}</span>
                  </div>

                  <!-- Discount if applicable -->
                  {#if item.discount_amount > 0}
                    <div class="item-info-item text-green-600">
                      <svg class="item-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
                      </svg>
                      <span class="item-label">{isRTL ? 'الخصم:' : 'Discount:'}</span>
                      <span class="item-value font-semibold">-{item.discount_amount} {t('common.sar', 'SAR')}</span>
                    </div>
                  {/if}
                </div>

                <!-- Offer Badge -->
                {#if item.has_offer}
                  <div class="offer-badge">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                    </svg>
                    <span>{isRTL ? (item.offer_name_ar || 'عرض خاص') : (item.offer_name_en || 'Special Offer')}</span>
                  </div>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>

        <!-- 3. Order Summary Section -->
        <div class="detail-section">
        <h3 class="section-title">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z"/>
          </svg>
          {t('orders.detail.summary', 'Order Summary')}
        </h3>
        <div class="summary-grid">
          <div class="summary-row">
            <span>{t('orders.detail.subtotal', 'Subtotal')}</span>
            <span>{order.subtotal_amount} {t('common.sar', 'SAR')}</span>
          </div>
          <div class="summary-row">
            <span>{t('orders.detail.deliveryFee', 'Delivery Fee')}</span>
            <span>{order.delivery_fee} {t('common.sar', 'SAR')}</span>
          </div>
          {#if order.discount_amount > 0}
            <div class="summary-row text-green-600">
              <span>Discount</span>
              <span>-{order.discount_amount} {t('common.sar', 'SAR')}</span>
            </div>
          {/if}
          <div class="summary-row text-lg font-bold border-t pt-2">
            <span>{t('orders.detail.total', 'Total')}</span>
            <span>{order.total_amount} {t('common.sar', 'SAR')}</span>
          </div>
          <div class="summary-row mt-4">
            <span>{t('orders.detail.paymentMethod', 'Payment Method')}</span>
            <span class="capitalize">{order.payment_method}</span>
          </div>
          <div class="summary-row">
            <span>{t('orders.detail.fulfillment', 'Fulfillment Method')}</span>
            <span class="capitalize">{order.fulfillment_method}</span>
          </div>
        </div>
        </div>

        <!-- 4. Order Actions Section -->
        <div class="detail-section">
        <h3 class="section-title">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
          </svg>
          {t('orders.detail.actions', 'Order Actions')}
        </h3>
        <div class="actions-grid">
          {#if order.order_status === 'new'}
            <button on:click={acceptOrder} class="action-button accept">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
              </svg>
              {t('orders.detail.accept', 'Accept Order')}
            </button>
          {/if}

          {#if order.order_status !== 'cancelled' && order.order_status !== 'delivered'}
            <button on:click={cancelOrder} class="action-button cancel">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
              {t('orders.detail.cancel', 'Cancel Order')}
            </button>
          {/if}
        </div>
        </div>

        <!-- 5. Picker Assignment Section - Only show if order is accepted -->
        {#if order.order_status !== 'new' && order.order_status !== 'cancelled'}
          <div class="detail-section">
            <h3 class="section-title">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
              </svg>
              {t('orders.detail.picker', 'Assign Picker')}
            </h3>
            <div class="assignment-item">
              <label class="assignment-label">{t('orders.detail.picker', 'Picker')}</label>
              <div class="relative">
                <button 
                  on:click={() => showPickerDropdown = !showPickerDropdown}
                  class="assignment-select"
                  disabled={order.order_status === 'delivered' || order.order_status === 'cancelled'}
                >
                  <span>{order.picker?.username || t('orders.detail.selectPicker', 'Select Picker')}</span>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>

                {#if showPickerDropdown}
                  <div class="dropdown-menu">
                    <div class="dropdown-search">
                      <svg class="search-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                      </svg>
                      <input 
                        type="text" 
                        bind:value={pickerSearchQuery}
                        placeholder={isRTL ? 'بحث عن المحضّر...' : 'Search picker...'}
                        class="search-input"
                        on:click|stopPropagation
                      />
                    </div>
                    <div class="dropdown-items">
                      {#if filteredPickers.length > 0}
                        {#each filteredPickers as picker}
                          <button
                            on:click={() => assignPicker(picker.id)}
                            class="dropdown-item"
                            class:selected={selectedPickerId === picker.id}
                          >
                            {picker.username}
                            {#if pickerWorkload[picker.id]}
                              <span class="workload-badge">{pickerWorkload[picker.id]}</span>
                            {/if}
                          </button>
                        {/each}
                      {:else}
                        <div class="dropdown-empty">
                          {isRTL ? 'لا توجد نتائج' : 'No results'}
                        </div>
                      {/if}
                    </div>
                  </div>
                {/if}
              </div>
            </div>
          </div>
          
          <!-- Print Order Button (shown when picker is assigned) -->
          {#if order.picker_id}
            <div class="detail-section">
              <button class="print-order-btn" on:click={() => showPrintOrderModal = true}>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                </svg>
                {isRTL ? 'طباعة الطلب' : 'Print Order'}
              </button>
            </div>
          {/if}
        {/if}

        <!-- 6. Delivery Person Assignment Section - Only show if picker is assigned -->
        {#if order.picker_id}
          <div class="detail-section">
            <h3 class="section-title">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"/>
              </svg>
              {t('orders.detail.delivery', 'Assign Delivery Person')}
            </h3>
            <div class="assignment-item">
              <label class="assignment-label">{t('orders.detail.delivery', 'Delivery Person')}</label>
              <div class="relative">
                <button 
                  on:click={() => showDeliveryDropdown = !showDeliveryDropdown}
                  class="assignment-select"
                  disabled={order.order_status === 'delivered' || order.order_status === 'cancelled'}
                >
                  <span>{order.delivery?.username || t('orders.detail.selectDelivery', 'Select Delivery')}</span>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>

                {#if showDeliveryDropdown}
                  <div class="dropdown-menu">
                    <div class="dropdown-search">
                      <svg class="search-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                      </svg>
                      <input 
                        type="text" 
                        bind:value={deliverySearchQuery}
                        placeholder={isRTL ? 'بحث عن مندوب التوصيل...' : 'Search delivery person...'}
                        class="search-input"
                        on:click|stopPropagation
                      />
                    </div>
                    <div class="dropdown-items">
                      {#if filteredDelivery.length > 0}
                        {#each filteredDelivery as delivery}
                          <button
                            on:click={() => assignDelivery(delivery.id)}
                            class="dropdown-item"
                            class:selected={selectedDeliveryId === delivery.id}
                          >
                            {delivery.username}
                            {#if deliveryWorkload[delivery.id]}
                              <span class="workload-badge">{deliveryWorkload[delivery.id]}</span>
                            {/if}
                          </button>
                        {/each}
                      {:else}
                        <div class="dropdown-empty">
                          {isRTL ? 'لا توجد نتائج' : 'No results'}
                        </div>
                      {/if}
                    </div>
                  </div>
                {/if}
              </div>
            </div>
          </div>
        {/if}
      </div>
      <!-- End of Main Content -->

      <!-- Timeline Sidebar -->
      <div class="timeline-sidebar">
        <div class="timeline-sidebar-header">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <h3>{t('orders.detail.timeline', 'Order Timeline')}</h3>
        </div>
        <div class="timeline">
          <!-- 1. Order Created by Customer -->
          <div class="timeline-item">
            <div class="timeline-dot bg-blue-500"></div>
            <div class="timeline-content">
              <p class="timeline-title">{isRTL ? 'تم إنشاء الطلب من قبل العميل' : 'Order Created by Customer'}</p>
              <p class="timeline-time">{new Date(order.created_at).toLocaleString()}</p>
            </div>
          </div>

          <!-- 2. Order Accepted/Rejected -->
          {#if order.order_status !== 'new'}
            {@const acceptLog = order.audit_logs?.find(log => log.action_type === 'status_change' && log.to_status === 'accepted')}
            {@const cancelLog = order.audit_logs?.find(log => log.action_type === 'status_change' && log.to_status === 'cancelled')}
            {#if acceptLog}
              <div class="timeline-item">
                <div class="timeline-dot bg-green-500"></div>
                <div class="timeline-content">
                  <p class="timeline-title">{isRTL ? 'تم قبول الطلب' : 'Order Accepted'}</p>
                  <p class="timeline-time">{new Date(acceptLog.created_at).toLocaleString()}</p>
                  {#if acceptLog.performed_by_name}
                    <p class="timeline-performer">{isRTL ? 'بواسطة:' : 'By:'} {acceptLog.performed_by_name}</p>
                  {/if}
                </div>
              </div>
            {:else if cancelLog}
              <div class="timeline-item">
                <div class="timeline-dot bg-red-500"></div>
                <div class="timeline-content">
                  <p class="timeline-title">{isRTL ? 'تم رفض/إلغاء الطلب' : 'Order Rejected/Cancelled'}</p>
                  <p class="timeline-time">{new Date(cancelLog.created_at).toLocaleString()}</p>
                  {#if cancelLog.performed_by_name}
                    <p class="timeline-performer">{isRTL ? 'بواسطة:' : 'By:'} {cancelLog.performed_by_name}</p>
                  {/if}
                  {#if cancelLog.notes}
                    <p class="timeline-notes">{cancelLog.notes}</p>
                  {/if}
                </div>
              </div>
            {/if}
          {:else}
            <div class="timeline-item timeline-pending">
              <div class="timeline-dot bg-gray-300"></div>
              <div class="timeline-content">
                <p class="timeline-title text-gray-400">{isRTL ? 'في انتظار القبول/الرفض' : 'Pending Accept/Reject'}</p>
              </div>
            </div>
          {/if}

          <!-- 3. Picker Assigned -->
          {#if order.picker_id}
            {@const pickerLog = order.audit_logs?.find(log => log.action_type === 'assignment' && log.assignment_type === 'picker')}
            <div class="timeline-item">
              <div class="timeline-dot bg-purple-500"></div>
              <div class="timeline-content">
                <p class="timeline-title">{isRTL ? 'تم تعيين المحضّر' : 'Picker Assigned'}</p>
                <p class="timeline-performer">{order.picker?.username || pickerLog?.assigned_user_name || ''}</p>
                {#if pickerLog}
                  <p class="timeline-time">{new Date(pickerLog.created_at).toLocaleString()}</p>
                  {#if pickerLog.performed_by_name}
                    <p class="timeline-performer">{isRTL ? 'تعيين بواسطة:' : 'Assigned by:'} {pickerLog.performed_by_name}</p>
                  {/if}
                {/if}
              </div>
            </div>
          {:else if order.order_status === 'accepted' || ['in_picking', 'ready', 'out_for_delivery', 'delivered'].includes(order.order_status)}
            <div class="timeline-item timeline-pending">
              <div class="timeline-dot bg-gray-300"></div>
              <div class="timeline-content">
                <p class="timeline-title text-gray-400">{isRTL ? 'في انتظار تعيين المحضّر' : 'Pending Picker Assignment'}</p>
              </div>
            </div>
          {/if}

          <!-- 4. Delivery Person Assigned -->
          {#if order.delivery_person_id}
            {@const deliveryLog = order.audit_logs?.find(log => log.action_type === 'assignment' && log.assignment_type === 'delivery')}
            <div class="timeline-item">
              <div class="timeline-dot bg-orange-500"></div>
              <div class="timeline-content">
                <p class="timeline-title">{isRTL ? 'تم تعيين مندوب التوصيل' : 'Delivery Person Assigned'}</p>
                <p class="timeline-performer">{order.delivery?.username || deliveryLog?.assigned_user_name || ''}</p>
                {#if deliveryLog}
                  <p class="timeline-time">{new Date(deliveryLog.created_at).toLocaleString()}</p>
                  {#if deliveryLog.performed_by_name}
                    <p class="timeline-performer">{isRTL ? 'تعيين بواسطة:' : 'Assigned by:'} {deliveryLog.performed_by_name}</p>
                  {/if}
                {/if}
              </div>
            </div>
          {:else if order.picker_id && ['ready', 'out_for_delivery', 'delivered'].includes(order.order_status)}
            <div class="timeline-item timeline-pending">
              <div class="timeline-dot bg-gray-300"></div>
              <div class="timeline-content">
                <p class="timeline-title text-gray-400">{isRTL ? 'في انتظار تعيين مندوب التوصيل' : 'Pending Delivery Assignment'}</p>
              </div>
            </div>
          {/if}

          <!-- 5. Out for Delivery -->
          {#if order.order_status === 'out_for_delivery' || order.order_status === 'delivered'}
            {@const outForDeliveryLog = order.audit_logs?.find(log => log.action_type === 'status_change' && log.to_status === 'out_for_delivery')}
            <div class="timeline-item">
              <div class="timeline-dot bg-teal-500"></div>
              <div class="timeline-content">
                <p class="timeline-title">{isRTL ? 'خرج للتوصيل' : 'Out for Delivery'}</p>
                {#if outForDeliveryLog}
                  <p class="timeline-time">{new Date(outForDeliveryLog.created_at).toLocaleString()}</p>
                  {#if outForDeliveryLog.performed_by_name}
                    <p class="timeline-performer">{isRTL ? 'بواسطة:' : 'By:'} {outForDeliveryLog.performed_by_name}</p>
                  {/if}
                {/if}
              </div>
            </div>
          {:else if order.delivery_person_id && order.order_status === 'ready'}
            <div class="timeline-item timeline-pending">
              <div class="timeline-dot bg-gray-300"></div>
              <div class="timeline-content">
                <p class="timeline-title text-gray-400">{isRTL ? 'في انتظار الخروج للتوصيل' : 'Pending Out for Delivery'}</p>
              </div>
            </div>
          {/if}

          <!-- 6. Order Delivered -->
          {#if order.order_status === 'delivered'}
            {@const deliveredLog = order.audit_logs?.find(log => log.action_type === 'status_change' && log.to_status === 'delivered')}
            <div class="timeline-item">
              <div class="timeline-dot bg-green-700"></div>
              <div class="timeline-content">
                <p class="timeline-title">{isRTL ? 'تم توصيل الطلب' : 'Order Delivered'}</p>
                {#if deliveredLog}
                  <p class="timeline-time">{new Date(deliveredLog.created_at).toLocaleString()}</p>
                  {#if deliveredLog.performed_by_name}
                    <p class="timeline-performer">{isRTL ? 'بواسطة:' : 'By:'} {deliveredLog.performed_by_name}</p>
                  {/if}
                {/if}
              </div>
            </div>
          {:else if order.order_status === 'out_for_delivery'}
            <div class="timeline-item timeline-pending">
              <div class="timeline-dot bg-gray-300"></div>
              <div class="timeline-content">
                <p class="timeline-title text-gray-400">{isRTL ? 'في انتظار التوصيل' : 'Pending Delivery'}</p>
              </div>
            </div>
          {/if}
        </div>
      </div>
      <!-- End of Timeline Sidebar -->
    </div>
  {:else}
    <div class="error-state">
      <p>{t('orders.error', 'Failed to load order details')}</p>
    </div>
  {/if}

  <!-- Location Modal -->
  {#if showLocationModal && order?.selected_location}
    <div class="modal-overlay" on:click={closeLocationModal}>
      <div class="location-modal-content" on:click|stopPropagation>
        <div class="location-modal-header">
          <h3>📍 {isRTL ? 'موقع التوصيل' : 'Delivery Location'}</h3>
          <button class="close-btn" on:click={closeLocationModal}>✕</button>
        </div>
        <div class="location-modal-body">
          <div class="location-info">
            <p class="location-name">
              <strong>{isRTL ? 'العنوان:' : 'Address:'}</strong> 
              {order.selected_location.name || (isRTL ? 'موقع التوصيل' : 'Delivery Location')}
            </p>
            <p class="location-coordinates">
              <strong>{isRTL ? 'الإحداثيات:' : 'Coordinates:'}</strong> 
              {order.selected_location.lat.toFixed(6)}, {order.selected_location.lng.toFixed(6)}
            </p>
          </div>
          <div class="map-container">
            <iframe 
              src={getEmbedMapUrl(order.selected_location)}
              width="100%" 
              height="400"
              style="border:0; border-radius: 8px;"
              allowfullscreen="" 
              loading="lazy" 
              referrerpolicy="no-referrer-when-downgrade"
            ></iframe>
          </div>
        </div>
      </div>
    </div>
  {/if}

  <!-- Print Order Modal -->
  {#if showPrintOrderModal && order}
    <div class="modal-overlay print-modal-overlay" on:click={() => showPrintOrderModal = false}>
      <div class="print-modal-content" on:click|stopPropagation>
        <div class="print-header no-print">
          <h3>{isRTL ? 'طباعة الطلب' : 'Print Order'}</h3>
          <div class="print-actions">
            <button class="print-btn" on:click={printOrder}>
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
              </svg>
              {isRTL ? 'طباعة' : 'Print'}
            </button>
            <button class="close-print-btn" on:click={() => showPrintOrderModal = false}>
              ✕
            </button>
          </div>
        </div>
        
        <!-- A4 Print Content -->
        <div class="print-content a4-page">
          <!-- Header -->
          <div class="print-order-header">
            <h1>{isRTL ? 'بوليصة الطلب' : 'Order Slip'}</h1>
            <div class="order-info-row">
              <div>
                <strong>{isRTL ? 'رقم الطلب:' : 'Order #:'}</strong>
                <span>{order.order_number}</span>
              </div>
              <div>
                <strong>{isRTL ? 'التاريخ:' : 'Date:'}</strong>
                <span>{new Date(order.created_at).toLocaleDateString()}</span>
              </div>
            </div>
          </div>

          <!-- Customer Details -->
          <div class="print-section">
            <h3 class="print-section-title">{isRTL ? 'معلومات العميل' : 'Customer Information'}</h3>
            <div class="print-info-grid">
              <div><strong>{isRTL ? 'الاسم:' : 'Name:'}</strong> {order.customer_name}</div>
              <div><strong>{isRTL ? 'الهاتف:' : 'Phone:'}</strong> {order.customer_phone}</div>
            </div>
          </div>

          <!-- Order Items -->
          <div class="print-section">
            <h3 class="print-section-title">{isRTL ? 'المنتجات' : 'Order Items'}</h3>
            <table class="print-table">
              <thead>
                <tr>
                  <th>{isRTL ? '#' : '#'}</th>
                  <th>{isRTL ? 'الصورة' : 'Image'}</th>
                  <th>{isRTL ? 'المنتج' : 'Product'}</th>
                  <th>{isRTL ? 'الباركود' : 'Barcode'}</th>
                  <th>{isRTL ? 'الكمية' : 'Qty'}</th>
                  <th>{isRTL ? 'السعر' : 'Price'}</th>
                  <th>{isRTL ? 'الإجمالي' : 'Total'}</th>
                </tr>
              </thead>
              <tbody>
                {#each order.items as item, index}
                  <tr>
                    <td>{index + 1}</td>
                    <td>
                      <div class="product-image-cell">
                        {#if item.product?.image_url}
                          <img src={item.product.image_url} alt={isRTL ? item.product_name_ar : item.product_name_en} class="product-print-image" />
                        {:else}
                          <div class="product-image-placeholder">
                            <svg class="placeholder-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                            </svg>
                          </div>
                        {/if}
                      </div>
                    </td>
                    <td>
                      <div class="product-name">{item.product_name_en}</div>
                      <div class="product-name-ar">{item.product_name_ar}</div>
                    </td>
                    <td>
                      {#if item.product?.barcode}
                        <div class="product-barcode-cell">
                          <canvas bind:this={productBarcodeCanvases[index]} class="product-barcode-canvas"></canvas>
                          <div class="barcode-text">{item.product.barcode}</div>
                        </div>
                      {:else}
                        <span class="text-gray-400">-</span>
                      {/if}
                    </td>
                    <td>
                      <div>{item.quantity}</div>
                      <div class="unit-names">
                        <div>{item.unit_name_en}</div>
                        <div class="unit-name-ar">{item.unit_name_ar}</div>
                      </div>
                    </td>
                    <td>{item.unit_price.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</td>
                    <td>{item.line_total.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>

          <!-- Order Summary -->
          <div class="print-section">
            <div class="print-summary">
              <div class="summary-row">
                <span>{isRTL ? 'المجموع الفرعي:' : 'Subtotal:'}</span>
                <span>{order.subtotal_amount.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
              </div>
              {#if order.delivery_fee > 0}
                <div class="summary-row">
                  <span>{isRTL ? 'رسوم التوصيل:' : 'Delivery Fee:'}</span>
                  <span>{order.delivery_fee.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
                </div>
              {/if}
              {#if order.discount_amount > 0}
                <div class="summary-row discount">
                  <span>{isRTL ? 'الخصم:' : 'Discount:'}</span>
                  <span>-{order.discount_amount.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
                </div>
              {/if}
              {#if order.tax_amount > 0}
                <div class="summary-row">
                  <span>{isRTL ? 'الضريبة:' : 'Tax:'}</span>
                  <span>{order.tax_amount.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</span>
                </div>
              {/if}
              <div class="summary-row total">
                <span><strong>{isRTL ? 'الإجمالي النهائي:' : 'Total Amount:'}</strong></span>
                <span><strong>{order.total_amount.toFixed(2)} {isRTL ? 'ريال' : 'SAR'}</strong></span>
              </div>
            </div>
          </div>

          <!-- Picker Info -->
          {#if order.picker}
            <div class="print-section">
              <div class="print-info-grid">
                <div><strong>{isRTL ? 'المحضّر:' : 'Picker:'}</strong> {order.picker.username}</div>
                <div><strong>{isRTL ? 'تاريخ التعيين:' : 'Assigned:'}</strong> {new Date(order.picker_assigned_at).toLocaleString()}</div>
              </div>
            </div>
          {/if}

          <!-- Footer -->
          <div class="print-footer">
            <p>{isRTL ? 'شكراً لتعاملكم معنا' : 'Thank you for your business'}</p>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .order-detail-window {
    height: 100%;
    overflow-y: auto;
    background: #f9fafb;
  }

  .loading-state, .error-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    gap: 1rem;
  }

  .spinner {
    border: 3px solid #f3f4f6;
    border-top: 3px solid #3b82f6;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }

  .order-layout {
    display: flex;
    height: 100%;
    gap: 0;
  }

  .order-main-content {
    flex: 1;
    padding: 1.5rem;
    overflow-y: auto;
  }

  .timeline-sidebar {
    width: 320px;
    background: white;
    border-left: 1px solid #e5e7eb;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .timeline-sidebar-header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1.25rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    background: #f9fafb;
    font-weight: 600;
    font-size: 1rem;
    color: #1f2937;
  }

  .timeline-sidebar-header svg {
    width: 1.25rem;
    height: 1.25rem;
    flex-shrink: 0;
  }

  .timeline-sidebar-header h3 {
    margin: 0;
    font-size: 1rem;
    font-weight: 600;
  }

  .status-badge {
    display: inline-flex;
    align-items: center;
    padding: 0.5rem 1rem;
    border-radius: 0.5rem;
    color: white;
    font-weight: 600;
  }

  .detail-section {
    background: white;
    border-radius: 0.5rem;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .section-title {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.125rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: #1f2937;
  }

  .detail-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 1rem;
  }

  .detail-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .detail-item.col-span-2 {
    grid-column: span 2;
  }

  .detail-label {
    font-size: 0.875rem;
    color: #6b7280;
  }

  .detail-value {
    font-weight: 500;
    color: #1f2937;
  }

  .assignment-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 1rem;
  }

  .assignment-item {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .assignment-label {
    font-size: 0.875rem;
    font-weight: 500;
    color: #374151;
  }

  .assignment-select {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 0.625rem 1rem;
    background: white;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    cursor: pointer;
    transition: all 0.2s;
  }

  .assignment-select:hover:not(:disabled) {
    border-color: #3b82f6;
  }

  .assignment-select:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .dropdown-menu {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    margin-top: 0.25rem;
    background: white;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    z-index: 10;
  }

  .dropdown-search {
    position: relative;
    padding: 0.5rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .search-icon {
    position: absolute;
    left: 1rem;
    top: 50%;
    transform: translateY(-50%);
    width: 1rem;
    height: 1rem;
    color: #9ca3af;
    pointer-events: none;
  }

  [dir="rtl"] .search-icon {
    left: auto;
    right: 1rem;
  }

  .search-input {
    width: 100%;
    padding: 0.5rem 0.75rem 0.5rem 2.25rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    outline: none;
    transition: border-color 0.2s;
  }

  [dir="rtl"] .search-input {
    padding: 0.5rem 2.25rem 0.5rem 0.75rem;
  }

  .search-input:focus {
    border-color: #3b82f6;
  }

  .dropdown-items {
    max-height: 200px;
    overflow-y: auto;
  }

  .dropdown-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 0.625rem 1rem;
    text-align: left;
    border: none;
    background: none;
    cursor: pointer;
    transition: background 0.2s;
  }

  [dir="rtl"] .dropdown-item {
    text-align: right;
  }

  .dropdown-item:hover {
    background: #f3f4f6;
  }

  .dropdown-item.selected {
    background: #eff6ff;
    color: #3b82f6;
  }

  .dropdown-empty {
    padding: 1rem;
    text-align: center;
    color: #9ca3af;
    font-size: 0.875rem;
  }

  .workload-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 0.125rem 0.5rem;
    background: #fee2e2;
    color: #991b1b;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .items-list {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .item-card {
    display: flex;
    gap: 1rem;
    padding: 1rem;
    background: #f9fafb;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
    transition: box-shadow 0.2s;
  }

  .item-card:hover {
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  }

  .item-image-container {
    flex-shrink: 0;
    width: 80px;
    height: 80px;
  }

  .item-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 0.375rem;
    background: white;
  }

  .item-image-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: white;
    border: 2px dashed #e5e7eb;
    border-radius: 0.375rem;
  }

  .item-details-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .item-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
  }

  .item-name {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
    line-height: 1.4;
  }

  .item-total {
    font-size: 1.125rem;
    font-weight: 700;
    color: #059669;
    white-space: nowrap;
  }

  .item-info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.5rem;
  }

  .item-info-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .item-icon {
    width: 1rem;
    height: 1rem;
    color: #6b7280;
    flex-shrink: 0;
  }

  .item-label {
    color: #6b7280;
    font-weight: 500;
  }

  .item-value {
    color: #1f2937;
    font-weight: 500;
  }

  .offer-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.375rem 0.75rem;
    background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%);
    color: white;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
    width: fit-content;
  }

  .summary-grid {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .timeline {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .timeline-item {
    display: flex;
    gap: 0.75rem;
    position: relative;
    padding-left: 1.5rem;
    border-left: 2px solid #e5e7eb;
  }

  .timeline-item:last-child {
    border-left-color: transparent;
  }

  .timeline-item.timeline-pending {
    opacity: 0.6;
  }

  .timeline-item.timeline-pending .timeline-dot {
    border: 2px dashed #d1d5db;
    background: transparent;
  }

  .timeline-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    position: absolute;
    left: -6px;
    top: 6px;
    border: 2px solid white;
  }

  .timeline-content {
    flex: 1;
  }

  .timeline-title {
    font-weight: 500;
    color: #1f2937;
    margin-bottom: 0.25rem;
  }

  .timeline-title.text-gray-400 {
    color: #9ca3af;
    font-style: italic;
  }

  .timeline-time {
    font-size: 0.875rem;
    color: #6b7280;
    margin-top: 0.25rem;
  }

  .timeline-performer {
    font-size: 0.75rem;
    color: #9ca3af;
    margin-top: 0.25rem;
    font-style: italic;
  }

  .timeline-notes {
    font-size: 0.875rem;
    color: #6b7280;
    margin-top: 0.5rem;
    padding: 0.5rem;
    background: #f9fafb;
    border-radius: 0.25rem;
    border-left: 3px solid #ef4444;
  }

  .actions-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 1rem;
  }

  .action-button {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.75rem 1.5rem;
    border: none;
    border-radius: 0.375rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }

  .action-button.accept {
    background: #10b981;
    color: white;
  }

  .action-button.accept:hover {
    background: #059669;
  }

  .action-button.cancel {
    background: #ef4444;
    color: white;
  }

  .action-button.cancel:hover {
    background: #dc2626;
  }

  .action-button.print {
    background: #6366f1;
    color: white;
  }

  .action-button.print:hover {
    background: #4f46e5;
  }

  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .modal {
    background: white;
    padding: 2rem;
    border-radius: 0.5rem;
    max-width: 400px;
    width: 90%;
  }

  .modal-title {
    font-size: 1.25rem;
    font-weight: 600;
    margin-bottom: 1rem;
  }

  .modal-text {
    color: #6b7280;
    margin-bottom: 1.5rem;
  }

  .modal-actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
  }

  .modal-btn {
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
  }

  .modal-btn.primary {
    background: #3b82f6;
    color: white;
    border: none;
  }

  .modal-btn.primary:hover {
    background: #2563eb;
  }

  .modal-btn.secondary {
    background: white;
    color: #374151;
    border: 1px solid #d1d5db;
  }

  .modal-btn.secondary:hover {
    background: #f9fafb;
  }

  /* Location Modal Styles */
  .location-modal-content {
    background: white;
    border-radius: 1rem;
    width: 90%;
    max-width: 700px;
    max-height: 90vh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  }

  .location-modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.25rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.05) 0%, rgba(147, 197, 253, 0.05) 100%);
  }

  .location-modal-header h3 {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
    color: #1f2937;
  }

  .close-btn {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: #f3f4f6;
    border: none;
    color: #6b7280;
    font-size: 1.25rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
  }

  .close-btn:hover {
    background: #e5e7eb;
    color: #374151;
    transform: rotate(90deg);
  }

  .location-modal-body {
    padding: 1.5rem;
    overflow-y: auto;
  }

  .location-info {
    margin-bottom: 1rem;
    padding: 0.75rem 1rem;
    background: linear-gradient(135deg, rgba(16, 185, 129, 0.05) 0%, rgba(52, 211, 153, 0.05) 100%);
    border: 2px solid rgba(16, 185, 129, 0.2);
    border-radius: 0.75rem;
  }

  .location-name {
    margin: 0;
    font-size: 1rem;
    color: #1f2937;
  }

  .location-coordinates {
    margin: 0.5rem 0 0 0;
    font-size: 0.875rem;
    color: #6b7280;
  }

  .map-container {
    border-radius: 0.75rem;
    overflow: hidden;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  }

  .no-location-message {
    padding: 3rem;
    text-align: center;
    color: #9ca3af;
  }

  /* Location Buttons in Customer Section */
  .location-buttons {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    align-items: center;
  }

  .view-location-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.05) 0%, rgba(147, 197, 253, 0.05) 100%);
    border: 2px solid rgba(59, 130, 246, 0.3);
    border-radius: 0.5rem;
    font-size: 0.875rem;
    font-weight: 500;
    color: #2563eb;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .view-location-btn:hover {
    background: linear-gradient(135deg, rgba(59, 130, 246, 0.1) 0%, rgba(147, 197, 253, 0.1) 100%);
    border-color: rgba(59, 130, 246, 0.5);
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(59, 130, 246, 0.15);
  }

  .location-distance {
    display: inline-flex;
    align-items: center;
    padding: 0.5rem 1rem;
    background: linear-gradient(135deg, rgba(16, 185, 129, 0.05) 0%, rgba(52, 211, 153, 0.05) 100%);
    border: 2px solid rgba(16, 185, 129, 0.2);
    border-radius: 0.5rem;
    font-size: 0.875rem;
    font-weight: 600;
    color: #059669;
  }

  /* Print Order Button */
  .print-order-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    width: 100%;
    padding: 0.875rem 1.5rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border: none;
    border-radius: 0.5rem;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .print-order-btn:hover {
    background: linear-gradient(135deg, #059669 0%, #047857 100%);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  }

  /* Print Modal Styles */
  .print-modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.75);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 10000;
    padding: 1rem;
  }

  .print-modal-content {
    background: white;
    border-radius: 1rem;
    width: 100%;
    max-width: 900px;
    max-height: 95vh;
    overflow-y: auto;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.2);
  }

  .print-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.25rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    background: linear-gradient(135deg, rgba(16, 185, 129, 0.05) 0%, rgba(52, 211, 153, 0.05) 100%);
  }

  .print-header h3 {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
    color: #1f2937;
  }

  .print-actions {
    display: flex;
    gap: 0.75rem;
    align-items: center;
  }

  .print-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.625rem 1.25rem;
    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
    color: white;
    border: none;
    border-radius: 0.5rem;
    font-size: 0.875rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .print-btn:hover {
    background: linear-gradient(135deg, #059669 0%, #047857 100%);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
  }

  .close-print-btn {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: #f3f4f6;
    border: none;
    color: #6b7280;
    font-size: 1.25rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
  }

  .close-print-btn:hover {
    background: #e5e7eb;
    color: #374151;
    transform: rotate(90deg);
  }

  /* A4 Print Content */
  .print-content {
    padding: 2rem;
  }

  .a4-page {
    width: 21cm;
    min-height: 29.7cm;
    margin: 0 auto;
    background: white;
  }

  .print-order-header {
    text-align: center;
    margin-bottom: 2rem;
    border-bottom: 3px solid #10b981;
    padding-bottom: 1rem;
  }

  .print-order-header h1 {
    margin: 0 0 1rem 0;
    font-size: 2rem;
    color: #1f2937;
  }

  .order-info-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.875rem;
    color: #6b7280;
  }

  .print-section {
    margin-bottom: 1.5rem;
  }

  .print-section-title {
    font-size: 1.125rem;
    font-weight: 600;
    color: #1f2937;
    margin: 0 0 1rem 0;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid #e5e7eb;
  }

  .print-info-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 0.75rem;
    font-size: 0.875rem;
  }

  .print-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.875rem;
  }

  .print-table thead {
    background: #f9fafb;
  }

  .print-table th {
    padding: 0.75rem;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 2px solid #e5e7eb;
  }

  .print-table td {
    padding: 0.75rem;
    border-bottom: 1px solid #e5e7eb;
    color: #6b7280;
  }

  .print-table tbody tr:last-child td {
    border-bottom: none;
  }

  .product-name {
    font-weight: 500;
    color: #374151;
    font-size: 0.875rem;
  }

  .product-name-ar {
    font-size: 0.75rem;
    color: #6b7280;
    margin-top: 0.125rem;
    direction: rtl;
  }

  .unit-names {
    margin-top: 0.25rem;
    font-size: 0.75rem;
    color: #6b7280;
  }

  .unit-name-ar {
    direction: rtl;
    color: #9ca3af;
    font-size: 0.7rem;
  }

  .product-image-cell {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0.25rem;
  }

  .product-print-image {
    width: 60px;
    height: 60px;
    object-fit: cover;
    border-radius: 0.375rem;
    border: 1px solid #e5e7eb;
  }

  .product-image-placeholder {
    width: 60px;
    height: 60px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f3f4f6;
    border-radius: 0.375rem;
    border: 1px solid #e5e7eb;
  }

  .placeholder-icon {
    width: 24px;
    height: 24px;
    color: #9ca3af;
  }

  .product-barcode-cell {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
  }

  .product-barcode-canvas {
    max-width: 120px;
    height: auto;
  }

  .barcode-text {
    font-size: 0.75rem;
    color: #6b7280;
    font-family: monospace;
  }

  .print-summary {
    margin-top: 1.5rem;
    padding: 1rem;
    background: #f9fafb;
    border-radius: 0.5rem;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    padding: 0.5rem 0;
    font-size: 0.875rem;
  }

  .summary-row.discount {
    color: #059669;
  }

  .summary-row.total {
    font-size: 1.125rem;
    border-top: 2px solid #10b981;
    padding-top: 1rem;
    margin-top: 0.5rem;
  }

  .print-footer {
    text-align: center;
    margin-top: 3rem;
    padding-top: 1.5rem;
    border-top: 2px solid #e5e7eb;
    color: #9ca3af;
    font-size: 0.875rem;
  }

  /* Print-specific styles */
  @media print {
    @page {
      size: A4;
      margin: 0;
    }

    html, body {
      width: 210mm;
      height: 297mm;
      margin: 0;
      padding: 0;
      overflow: visible;
    }

    /* Hide everything */
    body > * {
      display: none !important;
    }

    /* Show only the print modal */
    .print-modal-overlay {
      display: block !important;
      position: static !important;
      width: 210mm !important;
      height: 297mm !important;
      margin: 0 !important;
      padding: 0 !important;
      background: white !important;
      overflow: visible !important;
    }

    .no-print {
      display: none !important;
    }

    .print-modal-content {
      display: block !important;
      position: static !important;
      width: 100% !important;
      max-width: none !important;
      height: auto !important;
      margin: 0 !important;
      padding: 0 !important;
      box-shadow: none !important;
      border-radius: 0 !important;
      overflow: visible !important;
      background: white !important;
    }

    .print-content {
      display: block !important;
      width: 100% !important;
      padding: 0 !important;
      margin: 0 !important;
      background: white !important;
      overflow: visible !important;
    }

    .a4-page {
      display: block !important;
      width: 100% !important;
      height: auto !important;
      padding: 1cm !important;
      margin: 0 !important;
      background: white !important;
      overflow: visible !important;
    }

    .print-order-header,
    .print-section,
    .print-footer {
      display: block !important;
      page-break-inside: avoid;
    }

    .print-table {
      width: 100% !important;
      border-collapse: collapse !important;
      display: table !important;
      page-break-inside: auto;
    }

    .print-table thead {
      display: table-header-group !important;
    }

    .print-table tbody {
      display: table-row-group !important;
    }

    .print-table tr {
      display: table-row !important;
      page-break-inside: avoid;
      page-break-after: auto;
    }

    .print-table th,
    .print-table td {
      display: table-cell !important;
      padding: 0.5rem !important;
      border: 1px solid #e5e7eb !important;
    }

    img {
      display: block !important;
      max-width: 100% !important;
    }

    canvas {
      display: block !important;
    }

    * {
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
      color-adjust: exact !important;
    }
  }

  @page {
    size: A4;
    margin: 1cm;
  }
</style>
