# 🎁 COUPON MANAGEMENT SYSTEM - IMPLEMENTATION PLAN

**Created:** November 26, 2025  
**Status:** Planning Complete - Ready for Implementation

---

## 📋 SYSTEM OVERVIEW

A comprehensive coupon management system that allows administrators to create promotional campaigns with special-priced products. Customers receive printed coupons with a shared campaign code, validate their eligibility via mobile number at checkout, and receive a randomly selected gift product with controlled stock limits.

---

## ✅ REQUIREMENTS SUMMARY

### **System Architecture**
- **Coupon Strategy:** One shared campaign code per promotion (e.g., "GIFT2025")
- **Customer Validation:** Via unique mobile numbers imported from Excel
- **Product Selection:** Random selection with stock limit controls
- **Cashier Access:** Any user from the users table can log in
- **Excel Import:** Single column format (mobile numbers only) with downloadable template
- **Print Output:** 80mm thermal receipt with full product details

### **Key Features**
- Campaign-based system supporting multiple simultaneous promotions
- Stock management with real-time inventory tracking
- One-time redemption per customer per campaign
- Full audit trail of all transactions
- Bilingual support (English/Arabic)
- Thermal printer integration for coupon receipts

---

## 🗄️ DATABASE ARCHITECTURE

### **1. coupon_campaigns**
Master table for managing promotional campaigns.

```sql
CREATE TABLE coupon_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_name VARCHAR(255) NOT NULL,
  campaign_code VARCHAR(50) UNIQUE NOT NULL,
  description TEXT,
  validity_start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  validity_end_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  terms_conditions_en TEXT,
  terms_conditions_ar TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE
);
```

**Purpose:** Stores all campaign configurations  
**Indexes:** campaign_code, is_active, validity dates  
**Example:** "Summer Gift 2025" with code "GIFT2025"

---

### **2. coupon_eligible_customers**
Tracks which customers are eligible for each campaign.

```sql
CREATE TABLE coupon_eligible_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES coupon_campaigns(id) ON DELETE CASCADE,
  mobile_number VARCHAR(20) NOT NULL,
  customer_name VARCHAR(255),
  import_batch_id UUID,
  imported_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  imported_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT unique_customer_campaign UNIQUE(campaign_id, mobile_number)
);
```

**Purpose:** Lists all customers eligible to claim gifts from specific campaigns  
**Indexes:** mobile_number + campaign_id (unique composite), campaign_id  
**Data Source:** Excel import (single column format)

---

### **3. coupon_products**
Products available as gifts with stock control.

```sql
CREATE TABLE coupon_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES coupon_campaigns(id) ON DELETE CASCADE,
  product_name_en VARCHAR(255) NOT NULL,
  product_name_ar VARCHAR(255) NOT NULL,
  product_image_url TEXT,
  original_price DECIMAL(10, 2) NOT NULL,
  offer_price DECIMAL(10, 2) NOT NULL,
  special_barcode VARCHAR(50) UNIQUE NOT NULL,
  stock_limit INTEGER NOT NULL DEFAULT 0,
  stock_remaining INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  deleted_at TIMESTAMP WITH TIME ZONE
);
```

**Purpose:** Gift products with pricing and inventory management  
**Indexes:** campaign_id, special_barcode (unique), stock_remaining  
**Stock Control:** Decremented automatically on claim  
**Image Storage:** coupon-product-images bucket

---

### **4. coupon_claims**
Audit trail of all coupon redemptions.

```sql
CREATE TABLE coupon_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES coupon_campaigns(id) ON DELETE CASCADE,
  customer_mobile VARCHAR(20) NOT NULL,
  product_id UUID REFERENCES coupon_products(id) ON DELETE SET NULL,
  claimed_by_user UUID REFERENCES users(id) ON DELETE SET NULL,
  claimed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  print_count INTEGER DEFAULT 1,
  barcode_scanned BOOLEAN DEFAULT false,
  validity_date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'claimed',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CONSTRAINT unique_customer_claim UNIQUE(campaign_id, customer_mobile)
);
```

**Purpose:** Permanent record of all claims (no updates/deletes)  
**Indexes:** customer_mobile + campaign_id (unique), campaign_id, claimed_at  
**Status Values:** 'claimed', 'redeemed', 'expired'  
**Validity Date:** Set to print date (same day expiry)

---

## 🪣 STORAGE BUCKET

### **coupon-product-images**

**Configuration:**
```sql
- Bucket ID: coupon-product-images
- Public: true (read access)
- File Size Limit: 5MB
- Allowed MIME Types: image/jpeg, image/png, image/webp
- Upload Access: Admins only
```

**Purpose:** Store product images for display and printing  
**Usage:** Referenced in coupon_products.product_image_url

---

## ⚙️ DATABASE FUNCTIONS

### **1. validate_coupon_eligibility()**

```sql
CREATE FUNCTION validate_coupon_eligibility(
  p_campaign_code VARCHAR,
  p_mobile_number VARCHAR
)
RETURNS JSONB
```

**Purpose:** Validates if a customer can claim a coupon  
**Returns:**
```json
{
  "eligible": true/false,
  "campaign_id": "uuid",
  "campaign_name": "string",
  "already_claimed": true/false,
  "error_message": "string"
}
```

**Checks:**
- Campaign exists and is active
- Current date within validity period
- Customer mobile number in eligible list
- No existing claim for this customer

---

### **2. select_random_product()**

```sql
CREATE FUNCTION select_random_product(
  p_campaign_id UUID
)
RETURNS SETOF coupon_products
```

**Purpose:** Randomly selects an available product from campaign  
**Logic:**
- Filters by campaign_id and stock_remaining > 0
- Uses ORDER BY RANDOM() for fair distribution
- Locks row for update (prevents race conditions)
- Returns full product details

---

### **3. claim_coupon()**

```sql
CREATE FUNCTION claim_coupon(
  p_campaign_id UUID,
  p_mobile_number VARCHAR,
  p_product_id UUID,
  p_user_id UUID
)
RETURNS JSONB
```

**Purpose:** Processes coupon claim in atomic transaction  
**Transaction Steps:**
1. Validate eligibility (double-check)
2. Insert record into coupon_claims
3. Decrement stock_remaining in coupon_products
4. Return complete claim details with product info

**Returns:**
```json
{
  "success": true/false,
  "claim_id": "uuid",
  "product_details": {...},
  "barcode": "string",
  "validity_date": "date"
}
```

---

### **4. get_campaign_statistics()**

```sql
CREATE FUNCTION get_campaign_statistics(
  p_campaign_id UUID
)
RETURNS JSONB
```

**Purpose:** Dashboard analytics for campaigns  
**Returns:**
```json
{
  "total_eligible_customers": 1000,
  "total_claims": 450,
  "remaining_claims": 550,
  "claim_percentage": 45.0,
  "products": [
    {
      "product_name": "Product A",
      "stock_limit": 200,
      "stock_remaining": 75,
      "claims_count": 125
    }
  ]
}
```

---

### **5. generate_campaign_code()**

```sql
CREATE FUNCTION generate_campaign_code()
RETURNS VARCHAR
```

**Purpose:** Auto-generate unique campaign codes  
**Format:** 8 uppercase alphanumeric characters (e.g., "GF2K5M8P")  
**Collision Check:** Ensures uniqueness in database

---

## 🎨 ADMIN INTERFACE

### **Navigation**
**Location:** Sidebar → "🎁 Coupon Management"  
**Route:** `/admin/coupons`  
**Access:** Admin and Master Admin roles only

---

### **Dashboard Layout**

```
┌─────────────────────────────────────────────────┐
│  🎁 Coupon Management System                    │
├─────────────────────────────────────────────────┤
│                                                 │
│  [📋 Manage Campaigns]  [👥 Import Customers]  │
│  [🎁 Manage Products]   [📊 Reports & Stats]   │
│                                                 │
├─────────────────────────────────────────────────┤
│  Active Campaigns Overview                      │
│  ┌──────────────────────────────────────────┐  │
│  │ Summer Gift 2025 | GIFT2025             │  │
│  │ Claims: 450/1000 | Active | Ends: ...   │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

### **1. Campaign Manager**

**Features:**
- List all campaigns with status indicators
- Create new campaign (modal form)
- Edit campaign details
- Activate/deactivate campaigns
- View campaign statistics

**Create Campaign Form:**
```
Campaign Name: [________________]
Campaign Code: [________] [🎲 Generate]
Description: [_________________]

Validity Period:
  Start Date: [📅 __/__/____]
  End Date:   [📅 __/__/____]

Terms & Conditions (English):
[_____________________________]

Terms & Conditions (Arabic):
[_____________________________]

[Cancel] [Create Campaign]
```

---

### **2. Customer Importer**

**Features:**
- Select target campaign from dropdown
- Download Excel template button
- Upload Excel file (drag & drop)
- Real-time validation preview
- Import summary with success/error counts

**Excel Template:**
```
| Mobile Number  |
|----------------|
| +966501234567  |
| 0501234567     |
| 966501234567   |
```

**Validation Rules:**
- Saudi mobile format (+966... or 05...)
- Duplicate detection (within upload and existing data)
- Format cleaning and standardization
- Batch processing for large files

**Import Summary:**
```
✅ Successfully imported: 950 customers
⚠️  Duplicates skipped: 45 customers
❌ Invalid format: 5 customers

[Download Error Report] [Close]
```

---

### **3. Product Manager**

**Features:**
- Filter by campaign
- Add new product (modal)
- Edit product details
- Adjust stock levels
- Deactivate products
- View product performance

**Add Product Form:**
```
Campaign: [Select Campaign ▼]

Product Name (English): [________________]
Product Name (Arabic):  [________________]

Product Image: [📷 Upload Image]

Pricing:
  Original Price: [______] SAR
  Offer Price:    [______] SAR
  Savings:        [______] SAR (auto-calc)

Special Barcode: [____________] [🎲 Generate]
Stock Limit:     [______] units

[Cancel] [Add Product]
```

---

### **4. Reports & Analytics**

**Available Reports:**

**Campaign Performance:**
- Total campaigns (active/inactive)
- Overall claim rate
- Most popular products
- Peak claim times

**Claims Analysis:**
- Claims by date (chart)
- Claims by product (pie chart)
- Customer participation rate
- Geographic distribution (if phone prefix tracked)

**Stock Management:**
- Low stock alerts
- Products out of stock
- Projected depletion dates

**Export Options:**
- CSV export of claims
- Excel report with analytics
- PDF summary report

---

## 💼 CASHIER INTERFACE

### **Route:** `/cashier`
**Access:** Any authenticated user (Supabase auth)  
**Device:** Optimized for desktop/tablet with thermal printer

---

### **Workflow Screens**

#### **Screen 1: Login**
```
┌─────────────────────────────┐
│   🎁 Coupon Claim System   │
├─────────────────────────────┤
│                             │
│   Username: [____________]  │
│   Password: [____________]  │
│                             │
│       [Login to Start]      │
│                             │
└─────────────────────────────┘
```

---

#### **Screen 2: Enter Customer Mobile**
```
┌─────────────────────────────────────┐
│  Step 1: Customer Mobile Number     │
├─────────────────────────────────────┤
│                                     │
│    Enter Customer Mobile Number:    │
│                                     │
│    ┌───────────────────────────┐   │
│    │ +966 5__ ___ ____         │   │
│    └───────────────────────────┘   │
│                                     │
│          [Next →]                   │
│                                     │
└─────────────────────────────────────┘
```

**Validation:**
- Format check (Saudi mobile)
- Real-time formatting (+966...)

---

#### **Screen 3: Enter Campaign Code**
```
┌─────────────────────────────────────┐
│  Step 2: Campaign Code              │
├─────────────────────────────────────┤
│                                     │
│  Customer: +966 501234567           │
│                                     │
│    Enter Campaign Code:             │
│                                     │
│    ┌───────────────────────────┐   │
│    │ GIFT2025                  │   │
│    └───────────────────────────┘   │
│                                     │
│    [← Back]    [Verify →]          │
│                                     │
└─────────────────────────────────────┘
```

**Validation:**
- Campaign exists and active
- Customer is eligible
- Not already claimed

---

#### **Screen 4: Product Display**
```
┌─────────────────────────────────────────────┐
│  🎉 Congratulations!                        │
├─────────────────────────────────────────────┤
│                                             │
│         ┌─────────────────┐                 │
│         │                 │                 │
│         │  [Product Img]  │                 │
│         │                 │                 │
│         └─────────────────┘                 │
│                                             │
│  Premium Coffee Maker                       │
│  صانع القهوة الفاخر                         │
│                                             │
│  Original Price:  SR 299.00                 │
│  Special Price:   SR 99.00                  │
│  ─────────────────────────                  │
│  YOU SAVE:        SR 200.00                 │
│                                             │
│         ┌─────────────────┐                 │
│         │ ╔═══╗ ╔═══╗     │                 │
│         │ ║   ║ ║   ║     │ (Barcode)       │
│         │ ╚═══╝ ╚═══╝     │                 │
│         │  1234567890123  │                 │
│         └─────────────────┘                 │
│                                             │
│  Valid Until: 26/11/2025                    │
│  Customer: +966 501234567                   │
│                                             │
│    [Cancel]      [🖨️ Print Coupon]         │
│                                             │
└─────────────────────────────────────────────┘
```

---

#### **Screen 5: Success Confirmation**
```
┌─────────────────────────────────────┐
│  ✅ Coupon Printed Successfully!    │
├─────────────────────────────────────┤
│                                     │
│    Customer: +966 501234567         │
│    Product: Premium Coffee Maker    │
│    Claimed at: 10:45 AM             │
│                                     │
│    [Process Another Customer]       │
│                                     │
└─────────────────────────────────────┘
```

---

## 🖨️ THERMAL RECEIPT LAYOUT (80mm)

```
================================
      [APP LOGO - Centered]
      (Base64 or Image URL)
================================

   🎁 SPECIAL OFFER COUPON 🎁
      
Premium Coffee Maker
صانع القهوة الفاخر

Original Price: SR 299.00
Offer Price:    SR 99.00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
YOU SAVE:       SR 200.00 ✨

================================
    [BARCODE - Large Center]
    ║║ ║║║ ║ ║║║ ║║ ║ ║║║║
         1234567890123
================================

Customer: +966 501234567
Valid Until: 26/11/2025
Campaign: Summer Gift 2025

--------------------------------
Terms & Conditions:
• Present this coupon at checkout
• Valid for one-time use only
• Cannot be exchanged for cash
• Terms apply as per campaign

• قدم هذا الكوبون عند الدفع
• صالح لاستخدام واحد فقط
• لا يمكن استبداله نقداً
• تطبق الشروط والأحكام
--------------------------------

  Thank you for shopping with us!
       شكراً لتسوقكم معنا

Printed: 26/11/2025 10:45 AM
Cashier: John Doe (#1234)
================================
```

**Printing Library:** `escpos` or `react-thermal-printer`  
**Barcode Format:** EAN-13 or Code128  
**Paper Width:** 80mm (standard thermal)  
**Character Width:** 48 characters per line

---

## 🔒 SECURITY & RLS POLICIES

### **coupon_campaigns**

```sql
-- SELECT: All authenticated users (cashiers need visibility)
CREATE POLICY "authenticated_view_active_campaigns"
  ON coupon_campaigns FOR SELECT TO authenticated
  USING (is_active = true AND deleted_at IS NULL);

-- SELECT: Admins see all (including inactive/deleted)
CREATE POLICY "admins_view_all_campaigns"
  ON coupon_campaigns FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- INSERT/UPDATE/DELETE: Admins only
CREATE POLICY "admins_manage_campaigns"
  ON coupon_campaigns FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );
```

---

### **coupon_eligible_customers**

```sql
-- SELECT: Authenticated (for eligibility checks)
CREATE POLICY "authenticated_check_eligibility"
  ON coupon_eligible_customers FOR SELECT TO authenticated
  USING (true);

-- INSERT: Admins only (via import function)
CREATE POLICY "admins_import_customers"
  ON coupon_eligible_customers FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- No UPDATE/DELETE policies (immutable audit trail)
```

---

### **coupon_products**

```sql
-- SELECT: All authenticated users
CREATE POLICY "authenticated_view_products"
  ON coupon_products FOR SELECT TO authenticated
  USING (is_active = true AND deleted_at IS NULL);

-- INSERT/UPDATE: Admins only
CREATE POLICY "admins_manage_products"
  ON coupon_products FOR INSERT, UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- DELETE: Admins only (soft delete)
CREATE POLICY "admins_delete_products"
  ON coupon_products FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );
```

---

### **coupon_claims**

```sql
-- SELECT: Users see own claims, admins see all
CREATE POLICY "users_view_own_claims"
  ON coupon_claims FOR SELECT TO authenticated
  USING (
    claimed_by_user = auth.uid() OR
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- INSERT: Via claim_coupon() function only
CREATE POLICY "authenticated_create_claims"
  ON coupon_claims FOR INSERT TO authenticated
  WITH CHECK (claimed_by_user = auth.uid());

-- No UPDATE/DELETE policies (immutable audit trail)
```

---

### **Storage: coupon-product-images**

```sql
-- Public read access
CREATE POLICY "public_view_coupon_images"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'coupon-product-images');

-- Admin upload only
CREATE POLICY "admins_upload_coupon_images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'coupon-product-images' AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );

-- Admin delete/update
CREATE POLICY "admins_manage_coupon_images"
  ON storage.objects FOR UPDATE, DELETE TO authenticated
  USING (
    bucket_id = 'coupon-product-images' AND
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role_type IN ('Admin', 'Master Admin')
    )
  );
```

---

## 📁 FILE STRUCTURE

```
Aqura/
├── supabase/
│   └── migrations/
│       └── 20251126_create_coupon_system.sql
│
├── frontend/src/
│   ├── lib/
│   │   ├── components/
│   │   │   ├── admin/
│   │   │   │   └── coupon/
│   │   │   │       ├── CouponDashboard.svelte
│   │   │   │       ├── CampaignManager.svelte
│   │   │   │       ├── CampaignForm.svelte
│   │   │   │       ├── CustomerImporter.svelte
│   │   │   │       ├── ProductManager.svelte
│   │   │   │       ├── ProductForm.svelte
│   │   │   │       ├── CouponReports.svelte
│   │   │   │       └── CampaignStatistics.svelte
│   │   │   │
│   │   │   └── cashier/
│   │   │       ├── CashierLayout.svelte
│   │   │       ├── CashierLogin.svelte
│   │   │       ├── MobileInput.svelte
│   │   │       ├── CampaignCodeInput.svelte
│   │   │       ├── ProductDisplay.svelte
│   │   │       ├── ThermalReceipt.svelte
│   │   │       └── ClaimSuccess.svelte
│   │   │
│   │   ├── services/
│   │   │   ├── couponService.ts
│   │   │   ├── campaignService.ts
│   │   │   ├── productService.ts
│   │   │   └── claimService.ts
│   │   │
│   │   └── utils/
│   │       ├── excelTemplate.ts
│   │       ├── mobileValidator.ts
│   │       ├── barcodeGenerator.ts
│   │       └── thermalPrinter.ts
│   │
│   └── routes/
│       ├── admin/
│       │   └── coupons/
│       │       └── +page.svelte
│       │
│       └── cashier/
│           └── +page.svelte
│
└── COUPON_MANAGEMENT_SYSTEM_PLAN.md (this file)
```

---

## 🚀 IMPLEMENTATION PHASES

### **Phase 1: Database & Backend** ⚡ (Priority 1)
**Estimated Time:** 4-6 hours

**Tasks:**
1. ✅ Create migration file: `20251126_create_coupon_system.sql`
2. ✅ Create all 4 tables with proper constraints
3. ✅ Create storage bucket: coupon-product-images
4. ✅ Implement 5 database functions
5. ✅ Set up RLS policies for all tables
6. ✅ Create triggers for stock management
7. ✅ Add indexes for performance
8. ✅ Test with sample data

**Deliverables:**
- Complete SQL migration file
- Tested database functions
- RLS policies verified
- Sample data for testing

---

### **Phase 2: Admin Interface** 📊 (Priority 2)
**Estimated Time:** 8-10 hours

**Tasks:**
1. ✅ Add "Coupon Management" to sidebar
2. ✅ Create main dashboard component
3. ✅ Implement Campaign Manager
   - List view with filters
   - Create/edit campaign forms
   - Campaign code generator
   - Activate/deactivate functionality
4. ✅ Implement Customer Importer
   - Excel template generator
   - File upload with drag-drop
   - Mobile number validation
   - Import preview and summary
5. ✅ Implement Product Manager
   - Product list with campaign filter
   - Add/edit product forms
   - Image upload to storage
   - Stock adjustment interface
   - Barcode generator
6. ✅ Implement Reports & Analytics
   - Campaign statistics
   - Claims charts
   - Product performance
   - Export functionality

**Deliverables:**
- Fully functional admin interface
- Excel template download
- Image upload system
- Analytics dashboard

---

### **Phase 3: Cashier Interface** 💼 (Priority 3)
**Estimated Time:** 6-8 hours

**Tasks:**
1. ✅ Create cashier route and layout
2. ✅ Implement login screen
3. ✅ Build multi-step claim workflow
   - Mobile number input with validation
   - Campaign code verification
   - Random product selection
   - Product display with barcode
4. ✅ Integrate thermal printer library
5. ✅ Design 80mm receipt layout
6. ✅ Implement print functionality
7. ✅ Add success confirmation screen
8. ✅ Error handling and user feedback

**Deliverables:**
- Complete cashier interface
- Working claim process
- Thermal print integration
- User-friendly error messages

---

### **Phase 4: Testing & Polish** ✨ (Priority 4)
**Estimated Time:** 4-5 hours

**Tasks:**
1. ✅ End-to-end workflow testing
2. ✅ Mobile number validation refinement
3. ✅ Stock control stress testing
4. ✅ Print layout verification on actual printer
5. ✅ Arabic RTL support testing
6. ✅ Error handling improvements
7. ✅ Performance optimization
8. ✅ Security audit
9. ✅ Documentation updates
10. ✅ User acceptance testing

**Deliverables:**
- Fully tested system
- Optimized performance
- Complete documentation
- Production-ready deployment

---

## ✅ VALIDATION RULES

### **Mobile Numbers**
- **Format:** Saudi Arabia mobile numbers
- **Accepted Formats:**
  - `+966501234567` (international)
  - `966501234567` (without +)
  - `0501234567` (local)
- **Normalization:** All stored as `+966XXXXXXXXX`
- **Validation:** 9 digits after country code (5XXXXXXXX)

### **Campaign Codes**
- **Length:** 6-12 characters
- **Characters:** Alphanumeric only (A-Z, 0-9)
- **Case:** Uppercase (auto-converted)
- **Uniqueness:** Database constraint
- **Examples:** `GIFT2025`, `SUMMER24`, `VIP2025`

### **Barcodes**
- **Format:** EAN-13 or Code128
- **Uniqueness:** Database constraint
- **Generation:** Auto or manual entry
- **Validation:** Check digit verification

### **Stock Limits**
- **Minimum:** 0 units
- **Maximum:** 999,999 units
- **Claim Validation:** Cannot claim if stock_remaining = 0
- **Update:** Atomic transaction during claim

### **Dates**
- **Campaign Validity:** End date must be after start date
- **Claim Validation:** Current date must be within campaign validity
- **Coupon Validity:** Set to claim date (same day expiry)

### **Duplicate Prevention**
- **Campaign Level:** One claim per customer per campaign
- **Database Constraint:** UNIQUE(campaign_id, customer_mobile)
- **Check:** Validated before random product selection

---

## 📊 SAMPLE DATA SCENARIOS

### **Scenario 1: Summer Gift Campaign**
```
Campaign: "Summer Gift 2025"
Code: GIFT2025
Validity: June 1 - August 31, 2025
Eligible Customers: 5,000
Products: 10 different items
Total Stock: 1,000 units
```

### **Scenario 2: VIP Exclusive**
```
Campaign: "VIP Appreciation"
Code: VIP2025
Validity: December 1-31, 2025
Eligible Customers: 500 (premium customers)
Products: 5 luxury items
Total Stock: 250 units
```

### **Scenario 3: New Store Opening**
```
Campaign: "Grand Opening Gifts"
Code: OPENING25
Validity: March 15-17, 2025 (3 days)
Eligible Customers: 10,000 (first visitors)
Products: 3 welcome gifts
Total Stock: 2,000 units
```

---

## 🔧 TECHNICAL CONSIDERATIONS

### **Performance Optimization**
- Database indexes on frequently queried columns
- Connection pooling for high traffic
- Caching active campaigns
- Lazy loading for product images
- Pagination for large datasets

### **Scalability**
- Batch processing for Excel imports (chunked)
- Queue system for claim processing if needed
- CDN for product images
- Database read replicas for reports

### **Error Handling**
- Network failure recovery
- Transaction rollback on errors
- User-friendly error messages (EN/AR)
- Detailed error logging for admins

### **Monitoring**
- Claim rate tracking
- Stock depletion alerts
- System health checks
- Performance metrics

---

## 📚 DEPENDENCIES

### **Backend**
- Supabase PostgreSQL
- Supabase Storage
- Supabase Auth

### **Frontend**
- SvelteKit
- TypeScript
- Tailwind CSS
- `@supabase/supabase-js`
- `xlsx` or `exceljs` (Excel handling)
- `jsbarcode` or `bwip-js` (barcode generation)
- `escpos` or `react-thermal-printer` (thermal printing)

### **Development**
- Vite
- PostCSS
- ESLint
- Prettier

---

## 🎯 SUCCESS CRITERIA

### **Functional Requirements**
- ✅ Admins can create and manage campaigns
- ✅ Admins can import customer lists via Excel
- ✅ Admins can add products with stock limits
- ✅ Cashiers can validate customers and campaign codes
- ✅ System randomly selects available products
- ✅ Stock decrements automatically on claim
- ✅ Customers cannot claim twice in same campaign
- ✅ Thermal receipts print correctly with all details
- ✅ Full audit trail of all transactions

### **Non-Functional Requirements**
- ✅ Response time < 2 seconds for claims
- ✅ Support for 10+ simultaneous cashiers
- ✅ 99.9% uptime during campaign periods
- ✅ Mobile number validation accuracy > 99%
- ✅ Zero duplicate claims (database constraint)

---

## 📝 NOTES & ASSUMPTIONS

1. **Thermal Printer:** Assumes standard 80mm ESC/POS compatible printer
2. **Excel Format:** Single column format prioritized for simplicity
3. **Mobile Format:** Saudi Arabia (+966) only initially, expandable
4. **Barcode Scanning:** POS system integration assumed external
5. **User Roles:** Uses existing users table role_type field
6. **Timezone:** All timestamps in UTC, displayed in local time
7. **Language:** Bilingual (EN/AR) throughout interface
8. **Coupon Validity:** Same-day expiry (print date = validity date)
9. **Stock Control:** Real-time, no overbooking allowed
10. **Audit Trail:** All claims are immutable (no edits/deletes)

---

## 🤝 SUPPORT & MAINTENANCE

### **Post-Launch Tasks**
- Monitor claim rates and system performance
- Gather user feedback (admins and cashiers)
- Fix bugs and edge cases
- Optimize based on usage patterns
- Add requested features

### **Future Enhancements**
- SMS notifications to customers
- QR code generation for coupons
- Multi-country mobile support
- Advanced analytics and ML predictions
- Mobile app for cashiers
- Integration with existing POS systems
- Multi-language support (beyond EN/AR)
- Customer self-service portal

---

## 📞 CONTACT & FEEDBACK

For questions, issues, or feature requests regarding this coupon management system, please contact the development team.

---

**Document Version:** 1.0  
**Last Updated:** November 26, 2025  
**Status:** ✅ Ready for Implementation

---

## 🎉 READY TO START IMPLEMENTATION!

All requirements gathered, architecture designed, and plan documented. Proceed with Phase 1 (Database & Backend) when ready.
