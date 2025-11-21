# 📋 Complete Order System Implementation Plan

## Overview
This document outlines the complete implementation plan for the order management system in Aqura, covering both the customer mobile app and the admin desktop interface.

---

## 🛒 CUSTOMER APP SIDE (Mobile Interface)

### 1. **Checkout Flow Enhancement**
**Current State:** Order saved to localStorage only  
**New Implementation:** Save to database when "Place Order" clicked

**Process Flow:**
1. Customer reviews cart → clicks "Place Order"
2. Generate unique order_number (e.g., "AQE202511201234")
3. Create record in `orders` table with:
   - Customer info, branch, selected location
   - Subtotal, delivery fee, discounts, total
   - Payment method, status = "pending"
4. Create records in `order_items` table for each cart item
5. Record offer usage in `offer_usage_logs` (with order_id)
6. Update `offers.current_total_uses` counters
7. Clear cart from localStorage
8. Show order confirmation with order number
9. Redirect to order tracking page

### 2. **Order Tracking Page** (`/customer/orders`)
**Current State:** Shows localStorage orders only  
**New Implementation:** Query from database

**Features:**
- List all customer's orders (newest first)
- Filter by status (Active, Completed, Cancelled)
- Each order shows:
  - Order number
  - Date/time
  - Total amount
  - Status badge (color-coded)
  - Items count
- Tap to view details

### 3. **Order Detail Page** (`/customer/orders/[id]`)
**New page needed**

**Sections:**
- **Order Header:** Number, date, status
- **Timeline:** Visual progress (New → Accepted → Preparing → Ready → Out for Delivery → Delivered)
- **Items List:** Products with quantities, prices, offers applied
- **Price Breakdown:** Subtotal, discounts, delivery, total
- **Delivery Info:** Selected address, estimated time
- **Actions:** 
  - Cancel order (if status = New/Accepted, within time limit)
  - Contact support
  - Reorder button

### 4. **Real-time Order Updates**
**Features:**
- Subscribe to order status changes (Supabase realtime)
- Push notifications when status changes:
  - "Order Accepted" → show picker assigned
  - "Out for Delivery" → show delivery person info
  - "Delivered" → ask for rating/feedback
- Visual indicators (badge count on orders tab)

### 5. **Order Cancellation**
**Rules:**
- Can cancel within X minutes of placing (e.g., 5 minutes)
- Cannot cancel if status = "In Picking" or later
- Customer cancellation: No reason required (simple cancel button)
- Refund status tracked (if paid online)

---

## 🖥️ ADMIN SIDE (Desktop Interface)

### 1. **Orders Manager Section** (New Window)
**Location:** Under "Customer App" section in sidebar

**Main Components:**
- Order list table
- Order detail panel
- Quick actions toolbar
- Filter/search bar

### 2. **Order List View**
**Table Columns:**
- Order Number (clickable)
- Customer Name (with WhatsApp)
- Date & Time
- Branch
- Total Amount
- Payment Method
- Status (color badge)
- Assigned Picker
- Delivery Person
- Actions (Quick buttons)

**Filters:**
- Status dropdown (All, New, Accepted, In Picking, Ready, Out for Delivery, Completed, Cancelled)
- Date range picker
- Branch filter
- Payment method filter
- Search by order number / customer name / phone

**Sorting:**
- Default: newest first
- Can sort by time, total, status

**Real-time Updates:**
- New orders auto-appear with notification sound
- Badge count on sidebar shows pending orders
- Status changes update live

### 3. **Order Detail Panel** (Opens on click)
**Sections:**

#### A. Customer Information
- Name, WhatsApp number (clickable to open WhatsApp)
- Selected delivery address (with map button)
- Order history count (how many orders this customer placed)

#### B. Order Items
- Product name, unit, quantity
- Unit price, discounts, subtotal per item
- Offers applied (shown with badges)
- Total items count

#### C. Order Summary
- Subtotal
- Product discounts
- Cart discounts
- Delivery fee
- Final total
- Total savings (highlighted)

#### D. Order Timeline
- Created at
- Accepted at (by whom)
- Picker assigned at (who)
- Ready at
- Out for delivery at (by whom)
- Delivered at
- Status change history

#### E. Action Buttons (Status-based)

**If Status = "New":**
- ✅ Accept Order
- 🖨️ Print Order
- ❌ Cancel Order (requires reason input)

**If Status = "Accepted":**
- 👤 Assign Picker (dropdown of warehouse users)
- 🖨️ Print Order
- ❌ Cancel Order (requires reason input)

**If Status = "In Picking":**
- ✓ Mark as Ready for Delivery
- 🖨️ Print Order

**If Status = "Ready":**
- 🚚 Assign Delivery Person (dropdown)
- 🖨️ Print Delivery Note

**If Status = "Out for Delivery":**
- ✓ Mark as Delivered
- 📞 Contact Delivery Person

**If Status = "Delivered":**
- 🖨️ Print Invoice
- 📄 View Receipt

### 4. **Quick Actions (Top Toolbar)**
**Bulk Operations:**
- Accept multiple orders at once
- Assign picker to multiple orders
- Print multiple order slips
- Export orders to Excel (filtered list)

**Stats Cards:**
- New Orders (count)
- In Progress (count)
- Completed Today (count)
- Total Revenue Today

### 5. **Order Status Flow Management**
**Status Transitions:**
```
New → Accepted → In Picking → Ready → Out for Delivery → Delivered ✓

New/Accepted → Cancelled ❌
```

**Status Rules:**
- Cannot skip statuses (must follow flow)
- Cancelled orders cannot be reopened
- Status changes require user confirmation
- Optional: add reason field for status changes

### 6. **User Assignment System**

#### Picker Assignment:
- Dropdown shows users with role = "Warehouse" or "Picker"
- Shows current workload (how many orders assigned)
- Can reassign to different picker
- Picker gets notification when assigned

#### Delivery Person Assignment:
- Dropdown shows users with role = "Delivery"
- Shows current deliveries count
- Shows location/zone match (if implemented)
- Can reassign if needed
- Delivery person gets notification with order details and map

### 7. **Printing Features**
**Print Templates:**

#### Order Slip (Kitchen/Warehouse):
- Order number (large)
- Customer name
- Items list with quantities
- Special notes
- Barcode for scanning

#### Delivery Note:
- Order number
- Customer name, phone
- Delivery address with map
- Items list (simplified)
- Total amount
- Payment method
- Signature line

#### Invoice/Receipt:
- Full order details
- Items with prices
- Discounts breakdown
- Company info
- QR code for verification

### 8. **Permissions & Roles**
**Role-based Access:**

**Admin/Manager:**
- View all orders
- Accept/cancel orders
- Assign picker/delivery
- Change any status
- View all branches

**Supervisor:**
- View orders for their branch
- Accept orders
- Assign picker/delivery
- Cannot cancel after acceptance

**Picker:**
- View only assigned orders
- Mark as "Picked" or "Ready"
- Cannot see other orders

**Delivery Person:**
- View only assigned deliveries
- Update status (Out/Delivered)
- Upload proof of delivery photo

### 9. **Notifications System**
**When to Notify:**

#### New Order Placed:
- Notify all admins/managers
- Desktop notification + sound
- Show popup with order summary

#### Order Assigned to Picker:
- Notify that specific picker
- Show order details in their tasks

#### Order Ready for Delivery:
- Notify available delivery persons
- Show in delivery queue

#### Order Assigned to Delivery Person:
- Notify that specific delivery person
- Push order details, map, customer info

#### Status Changed:
- Notify customer (push notification to mobile app)
- Log in notification center

### 10. **Audit & Logging**
**Track Everything:**
- Who created the order (customer)
- Who accepted the order (admin user)
- When picker assigned (timestamp + by whom)
- When delivery assigned (timestamp + by whom)
- All status changes (from → to, user, timestamp)
- Cancellation details (who cancelled, type: customer/admin, reason if admin)
- Store in `order_audit_logs` table

### 11. **Analytics Dashboard** (Future Enhancement)
**Metrics:**
- Orders per day/week/month
- Average order value
- Popular products
- Peak ordering times
- Picker performance (orders/hour)
- Delivery times (average)
- Offer usage statistics
- Customer repeat rate

### 12. **Integration Points**
**With Existing Systems:**
- **Task System:** Auto-create task for picker when assigned
- **Notification Center:** Order updates appear in admin notifications
- **HR System:** Pull user list for picker/delivery assignment
- **Branch System:** Filter orders by branch
- **Offer System:** Validate and track offer usage
- **Customer System:** Link to customer profile, order history

---

## 🗄️ DATABASE REQUIREMENTS

### Tables Needed:

#### 1. `orders` - Main Order Records
**Columns:**
- `id` (UUID, primary key)
- `order_number` (TEXT, unique) - "AQE202511201234"
- `customer_id` (UUID, FK to customers)
- `branch_id` (UUID, FK to branches)
- `selected_location` (INTEGER) - 1, 2, or 3 (which customer address)
- `order_status` (TEXT) - new/accepted/in_picking/ready/out_for_delivery/delivered/cancelled
- `fulfillment_method` (TEXT) - delivery/pickup
- `subtotal` (DECIMAL)
- `delivery_fee` (DECIMAL)
- `product_discount_total` (DECIMAL)
- `cart_discount_total` (DECIMAL)
- `total_amount` (DECIMAL)
- `total_savings` (DECIMAL)
- `payment_method` (TEXT) - cash/card/online
- `payment_status` (TEXT) - pending/paid/refunded
- `accepted_by` (UUID, FK to users) - admin who accepted
- `accepted_at` (TIMESTAMP)
- `picker_id` (UUID, FK to users) - assigned picker
- `picker_assigned_at` (TIMESTAMP)
- `ready_at` (TIMESTAMP)
- `delivery_person_id` (UUID, FK to users) - assigned delivery
- `delivery_assigned_at` (TIMESTAMP)
- `delivered_at` (TIMESTAMP)
- `cancelled_by` (UUID, FK to users or customers) - who cancelled
- `cancelled_by_type` (TEXT) - customer/admin
- `cancelled_at` (TIMESTAMP)
- `cancellation_reason` (TEXT, nullable) - required only if cancelled by admin
- `special_notes` (TEXT)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

**Indexes:**
- order_number (unique)
- customer_id
- branch_id
- order_status
- created_at

#### 2. `order_items` - Items in Each Order
**Columns:**
- `id` (UUID, primary key)
- `order_id` (UUID, FK to orders)
- `product_id` (UUID, FK to products)
- `unit_id` (UUID, FK to product_units)
- `product_name_ar` (TEXT) - snapshot for history
- `product_name_en` (TEXT)
- `unit_name_ar` (TEXT)
- `unit_name_en` (TEXT)
- `quantity` (INTEGER)
- `unit_price` (DECIMAL) - original price
- `offer_id` (UUID, FK to offers, nullable)
- `offer_type` (TEXT) - percentage/special_price/bogo/bundle/cart/null
- `discount_amount` (DECIMAL)
- `total_price` (DECIMAL) - after discount
- `item_type` (TEXT) - regular/bogo_buy/bogo_get/bundle_item
- `bundle_id` (UUID, nullable) - if part of bundle
- `created_at` (TIMESTAMP)

**Indexes:**
- order_id
- product_id
- offer_id

#### 3. `order_audit_logs` - Status Changes & Actions
**Columns:**
- `id` (UUID, primary key)
- `order_id` (UUID, FK to orders)
- `action_type` (TEXT) - status_change/picker_assigned/delivery_assigned/cancelled/printed
- `from_status` (TEXT, nullable)
- `to_status` (TEXT, nullable)
- `performed_by` (UUID, FK to users)
- `notes` (TEXT)
- `created_at` (TIMESTAMP)

**Indexes:**
- order_id
- created_at

#### 4. Extend `offer_usage_logs` Table
**Add Column:**
- `order_id` (UUID, FK to orders, nullable)

---

### Database Functions Needed:

#### 1. `create_customer_order()`
**Purpose:** Validate and create order with all items
**Parameters:**
- customer_id
- branch_id
- selected_location
- cart_items (JSON array)
- payment_method
- fulfillment_method
**Logic:**
1. Validate customer exists and is approved
2. Validate all products and offers are still active
3. Calculate totals and verify against passed values
4. Create order record
5. Create order_items records
6. Create offer_usage_logs records
7. Update offer usage counters
8. Return order_id and order_number

#### 2. `accept_order(order_id, user_id)`
**Purpose:** Accept order and change status
**Logic:**
1. Validate order status is "new"
2. Update status to "accepted"
3. Set accepted_by and accepted_at
4. Create audit log entry
5. Trigger notification to customer

#### 3. `assign_order_picker(order_id, picker_id, user_id)`
**Purpose:** Assign picker to order
**Logic:**
1. Validate order status is "accepted"
2. Validate picker_id is valid user with picker role
3. Update picker_id and picker_assigned_at
4. Change status to "in_picking"
5. Create audit log entry
6. Create task for picker (optional)
7. Send notification to picker

#### 4. `assign_order_delivery(order_id, delivery_person_id, user_id)`
**Purpose:** Assign delivery person to order
**Logic:**
1. Validate order status is "ready"
2. Validate delivery_person_id is valid user with delivery role
3. Update delivery_person_id and delivery_assigned_at
4. Change status to "out_for_delivery"
5. Create audit log entry
6. Send notification to delivery person with map/details

#### 5. `update_order_status(order_id, new_status, user_id, notes)`
**Purpose:** Change order status with validation
**Logic:**
1. Get current status
2. Validate status transition is allowed
3. Update order status and relevant timestamps
4. Create audit log entry
5. Trigger appropriate notifications

#### 6. `cancel_order(order_id, cancelled_by_id, cancelled_by_type, reason)`
**Purpose:** Cancel order (customer or admin)
**Parameters:**
- order_id
- cancelled_by_id (customer_id or user_id)
- cancelled_by_type ("customer" or "admin")
- reason (required if cancelled_by_type = "admin", optional if "customer")
**Logic:**
1. Validate order can be cancelled (status check)
2. If cancelled_by_type = "admin", validate reason is provided
3. If cancelled_by_type = "customer", validate within time limit (e.g., 5 minutes)
4. Update status to "cancelled"
5. Set cancelled_by, cancelled_by_type, cancelled_at, cancellation_reason
6. Rollback offer usage counters
7. Delete offer_usage_logs for this order
8. Create audit log entry
9. Send notification to customer (if cancelled by admin) or admins (if cancelled by customer)

#### 7. `get_orders_for_branch(branch_id, status_filter, date_from, date_to)`
**Purpose:** Query orders by branch with filters
**Returns:** Order list with customer info, item counts, totals

#### 8. `get_user_assigned_orders(user_id)`
**Purpose:** Get picker/delivery tasks for specific user
**Returns:** Orders assigned to this user as picker or delivery person

---

### Database Triggers Needed:

#### 1. `on_order_status_change`
**Table:** orders
**Event:** UPDATE (when order_status changes)
**Action:**
- Create audit log entry automatically
- Queue notification to customer
- Update related timestamps

#### 2. `on_order_created`
**Table:** orders
**Event:** INSERT
**Action:**
- Queue notification to admins/managers
- Create initial audit log entry

#### 3. `update_updated_at`
**Table:** orders, order_items
**Event:** UPDATE
**Action:**
- Update updated_at timestamp

---

### RLS (Row Level Security) Policies:

#### `orders` Table:
**SELECT:**
- Customers: `customer_id = auth.uid()`
- Admins: All orders for their branches
- Pickers: Orders where `picker_id = auth.uid()`
- Delivery: Orders where `delivery_person_id = auth.uid()`

**INSERT:**
- Customers only (when placing order)

**UPDATE:**
- Admins for their branches
- Pickers for assigned orders (limited fields)
- Delivery for assigned orders (limited fields)

**DELETE:**
- No one (orders never deleted, only cancelled)

#### `order_items` Table:
**SELECT:**
- Same as orders (based on order_id)

**INSERT:**
- System only (via create_customer_order function)

**UPDATE/DELETE:**
- No one (items are immutable once created)

#### `order_audit_logs` Table:
**SELECT:**
- Admins/Managers only

**INSERT:**
- System only (via triggers/functions)

**UPDATE/DELETE:**
- No one (audit logs are immutable)

---

## 🎨 UI/UX DESIGN GUIDELINES

### Color Coding for Order Status:
- **New:** Blue (`#3b82f6`) - Fresh order
- **Accepted:** Green (`#10b981`) - Being processed
- **In Picking:** Orange (`#f97316`) - Active work
- **Ready:** Purple (`#a855f7`) - Waiting for delivery
- **Out for Delivery:** Teal (`#14b8a6`) - On the way
- **Delivered:** Dark Green (`#059669`) - Completed
- **Cancelled:** Red (`#dc2626`) - Cancelled

### Notification Sounds:
- New order: "order-bell.mp3" (pleasant chime)
- Status update: "notification-pop.mp3" (subtle)
- Urgent: "alert-urgent.mp3" (for cancellations)

### Mobile Customer UI:
- Large, touch-friendly buttons
- Swipeable order cards
- Pull-to-refresh order list
- Bottom sheet for order details
- Timeline with icons and colors
- Easy reorder button

### Desktop Admin UI:
- Compact table view for many orders
- Side panel for details (no full-page navigation)
- Keyboard shortcuts (Accept: Ctrl+A, Print: Ctrl+P)
- Drag-and-drop for picker/delivery assignment (future)
- Color-coded status badges
- Sound + desktop notification for new orders

---

## 📝 IMPLEMENTATION PHASES

### Phase 1: Database Setup (Week 1)
- Create tables (orders, order_items, order_audit_logs)
- Add order_id to offer_usage_logs
- Create all database functions
- Set up triggers
- Configure RLS policies
- Test with sample data

### Phase 2: Customer App - Checkout (Week 2)
- Update checkout flow to save to database
- Implement order creation API endpoint
- Test offer usage recording
- Clear cart after successful order
- Show order confirmation with number

### Phase 3: Customer App - Order Tracking (Week 3)
- Create order list page (query from DB)
- Create order detail page
- Implement status timeline UI
- Add real-time status updates (Supabase realtime)
- Implement order cancellation

### Phase 4: Admin - Orders Manager View (Week 4)
- Create Orders Manager window component
- Build order list table with filters
- Implement real-time order updates
- Add search and sorting
- Show stats cards (new, in progress, completed)

### Phase 5: Admin - Order Actions (Week 5)
- Accept order functionality
- Assign picker dropdown and logic
- Assign delivery dropdown and logic
- Status update buttons and validation
- Order cancellation with reason

### Phase 6: Printing & Notifications (Week 6)
- Design print templates (order slip, delivery note, invoice)
- Implement print functionality
- Set up push notifications for customers
- Desktop notifications for admins
- Sound alerts for new orders

### Phase 7: Audit & Permissions (Week 7)
- Implement audit logging UI
- Role-based permission checks
- Picker task view (assigned orders only)
- Delivery person view (assigned deliveries only)
- Test all permission scenarios

### Phase 8: Testing & Polish (Week 8)
- End-to-end testing (customer places order → delivered)
- Test all status transitions
- Test cancellation flows
- Test offer usage tracking
- Performance optimization
- Bug fixes and UI polish

---

## 🚀 SUCCESS CRITERIA

### Customer App:
- ✅ Orders persist in database (not lost on browser clear)
- ✅ Real-time status updates work
- ✅ Can view order history
- ✅ Can cancel orders within time limit
- ✅ Offer usage correctly recorded
- ✅ Push notifications received for status changes

### Admin Desktop:
- ✅ New orders appear instantly with sound
- ✅ Can accept and assign orders smoothly
- ✅ Status flow validation works (no skipping)
- ✅ Printing works correctly
- ✅ Role-based access working
- ✅ Audit trail complete and accurate

### Database:
- ✅ All data relationships correct
- ✅ RLS policies secure
- ✅ Functions perform validations
- ✅ Triggers fire correctly
- ✅ Performance acceptable (queries < 100ms)

---

## 📞 SUPPORT & MAINTENANCE

### Monitoring:
- Track order creation failures
- Monitor notification delivery
- Log printing errors
- Track status transition errors

### Backup:
- Daily database backups
- Order data retention policy (7 years for Saudi law)
- Audit log retention

### Future Enhancements:
- Customer ratings/reviews
- Delivery tracking (live map)
- Estimated delivery time calculation
- SMS notifications (in addition to push)
- Order scheduling (place order for future date)
- Recurring orders
- Loyalty points per order
- Driver route optimization

---

## ✅ IMPLEMENTATION TODOS

### Admin UI Components (Phase 1)
- [ ] **Create Orders Manager Window Component** - Create new Orders Manager window in admin desktop interface under Customer App section. Include window shell, header, and basic layout structure.
- [ ] **Build Order List Table View** - Implement order list table with columns: Order Number, Customer, Date/Time, Branch, Total, Payment Method, Status, Picker, Delivery Person, Actions. Include sorting and real-time updates.
- [ ] **Add Filters and Search Bar** - Implement status dropdown filter, date range picker, branch filter, payment method filter, and search by order number/customer/phone. Include clear filters button.
- [ ] **Create Stats Cards Section** - Add stats cards at top showing: New Orders (count), In Progress (count), Completed Today (count), Total Revenue Today. Update counts in real-time.
- [ ] **Build Order Detail Side Panel** - Create side panel that opens when order clicked. Include sections: Customer Info, Order Items, Order Summary, Timeline, Action Buttons. Make it closable and responsive.
- [ ] **Implement Status-based Action Buttons** - Add conditional action buttons based on order status: Accept, Assign Picker, Mark Ready, Assign Delivery, Mark Delivered, Cancel (with reason for admin). Include confirmation dialogs.
- [ ] **Create User Assignment Dropdowns** - Build dropdown components for Picker and Delivery Person assignment. Filter by role, show current workload, handle reassignment. Include user search/filter.
- [ ] **Add Print Functionality Placeholders** - Create print button handlers for Order Slip, Delivery Note, and Invoice. Implement basic print preview (full templates in later phase).
- [ ] **Implement Real-time Order Updates** - Set up Supabase realtime subscription for orders table. Auto-update list when new orders arrive, status changes, or assignments made. Add notification sound for new orders.
- [ ] **Add Orders Manager to Sidebar Navigation** - Add Orders Manager menu item under Customer App section in desktop sidebar. Include icon, badge count for new orders, and proper navigation.

### Database Setup (Phase 2)
- [ ] **Create Database Migration - orders Table** - Write SQL migration to create orders table with all columns: id, order_number, customer_id, branch_id, selected_location, status, fulfillment_method, amounts, payment info, assignments, timestamps, cancellation fields.
- [ ] **Create Database Migration - order_items Table** - Write SQL migration to create order_items table with columns: id, order_id, product_id, unit_id, product names (snapshot), unit names, quantity, prices, offer info, item_type, bundle_id, created_at.
- [ ] **Create Database Migration - order_audit_logs Table** - Write SQL migration to create order_audit_logs table with columns: id, order_id, action_type, from_status, to_status, performed_by, notes, created_at. Add indexes.
- [ ] **Extend offer_usage_logs Table** - Add order_id column to existing offer_usage_logs table via migration. Make it nullable and add foreign key constraint to orders table.
- [ ] **Create Database Functions - Order Management** - Implement database functions: create_customer_order(), accept_order(), assign_order_picker(), assign_order_delivery(), update_order_status(), cancel_order(). Include validation logic.
- [ ] **Create Database Triggers** - Implement triggers: on_order_status_change (audit log + notifications), on_order_created (notify admins), update_updated_at (timestamp management).
- [ ] **Set Up RLS Policies for Orders Tables** - Configure Row Level Security policies for orders, order_items, and order_audit_logs tables. Define customer, admin, picker, and delivery person access rules.
- [ ] **Test Database Setup with Sample Data** - Create test orders via SQL, verify constraints work, test all functions, verify triggers fire correctly, test RLS policies with different user roles.

---

**Document Version:** 1.0  
**Last Updated:** November 20, 2025  
**Status:** Ready for Implementation
