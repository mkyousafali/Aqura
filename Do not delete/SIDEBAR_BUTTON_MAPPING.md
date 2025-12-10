# Sidebar Button Mapping Report

**Generated:** 10/12/2025, 6:10:04 am  
**Total Sidebar Menu Items:** 69  
**Items With Permission Checks:** 8  
**Items Without Permission Checks:** 61

---

## 📊 Summary by Function Code

| Function Code | Menu Items Count |
|---------------|------------------|
| BRANCH_MASTER | 1 |
| BUDGET_TRACKING | 1 |
| COUPON_MGMT | 5 |
| CUSTOMER_MGMT | 2 |
| EXPENSE_MGMT | 1 |
| FINANCIAL_REPORTS | 6 |
| HR_MASTER | 12 |
| NOTIFICATION_CENTER | 2 |
| OFFER_MGMT | 8 |
| PAYMENT_SCHEDULER | 2 |
| PRICE_MGMT | 1 |
| PRODUCT_MGMT | 3 |
| RECEIVING_MGMT | 4 |
| SALES_REPORTS | 1 |
| SETTINGS | 6 |
| TASK_MASTER | 8 |
| USER_MGMT | 3 |
| VENDOR_MGMT | 3 |

---

## 📋 Complete Sidebar Menu Mapping

| Menu Text | Function Code | Handler | Line | Has Permission Check |
|-----------|---------------|---------|------|---------------------|
| New Start Receiving | RECEIVING_MGMT | openNewStartReceiving | 1899 | ❌ |
| Customer Master | CUSTOMER_MGMT | openCustomerMaster | 1972 | ✅ |
| Ad Manager | NOTIFICATION_CENTER | openAdManager | 1978 | ✅ |
| Products Manager | PRODUCT_MGMT | openProductsManager | 1984 | ❌ |
| Delivery Settings | SETTINGS | openDeliverySettings | 1990 | ❌ |
| Orders Manager | CUSTOMER_MGMT | openOrdersManager | 2023 | ✅ |
| Offer Management | OFFER_MGMT | openOfferManagement | 2029 | ✅ |
| Receiving | RECEIVING_MGMT | openReceiving | 2104 | ❌ |
| Upload Vendor | VENDOR_MGMT | openUploadVendor | 2135 | ❌ |
| Create Vendor | VENDOR_MGMT | openCreateVendor | 2141 | ❌ |
| Manage Vendor | VENDOR_MGMT | openManageVendor | 2147 | ❌ |
| Start Receiving | RECEIVING_MGMT | openStartReceiving | 2178 | ❌ |
| Receiving Records | RECEIVING_MGMT | openReceivingRecords | 2184 | ❌ |
| Vendor Records | FINANCIAL_REPORTS | openVendorRecords | 2215 | ❌ |
| Vendor Payments | FINANCIAL_REPORTS | openVendorPendingPayments | 2221 | ❌ |
| Flyer Master | OFFER_MGMT | openFlyerMaster | 2269 | ❌ |
| Product Master | PRODUCT_MGMT | openProductMaster | 2300 | ❌ |
| Variation Manager | PRODUCT_MGMT | openVariationManager | 2306 | ❌ |
| Offer Manager | OFFER_MGMT | openOfferManager | 2312 | ❌ |
| Flyer Templates | OFFER_MGMT | openFlyerTemplates | 2318 | ❌ |
| Settings | SETTINGS | openFlyerSettings | 2324 | ❌ |
| Offer Product Editor | OFFER_MGMT | openOfferProductEditor | 2355 | ❌ |
| Create New Offer | OFFER_MGMT | openCreateNewOffer | 2361 | ❌ |
| Pricing Manager | PRICE_MGMT | openPricingManager | 2367 | ❌ |
| Generate Flyers | OFFER_MGMT | openGenerateFlyers | 2373 | ❌ |
| Shelf Paper Manager | OFFER_MGMT | openShelfPaperManager | 2379 | ❌ |
| Coupon Dashboard | COUPON_MGMT | openCouponDashboardPromo | 2447 | ❌ |
| Manage Campaigns | COUPON_MGMT | openCampaignManager | 2478 | ❌ |
| Import Customers | COUPON_MGMT | openCustomerImporter | 2509 | ❌ |
| Manage Products | COUPON_MGMT | openProductManagerPromo | 2515 | ❌ |
| Reports & Stats | COUPON_MGMT | openCouponReports | 2546 | ❌ |
| Manual Scheduling | PAYMENT_SCHEDULER | openManualScheduling | 2644 | ❌ |
| Day Budget Planner | BUDGET_TRACKING | openDayBudgetPlanner | 2650 | ❌ |
| Monthly Manager | FINANCIAL_REPORTS | openMonthlyManager | 2656 | ❌ |
| Expense Manager | EXPENSE_MGMT | openExpenseManager | 2662 | ❌ |
| Paid Manager | PAYMENT_SCHEDULER | openPaidManager | 2668 | ❌ |
| Expense Tracker | FINANCIAL_REPORTS | openExpenseTracker | 2695 | ❌ |
| Sales Report | SALES_REPORTS | openSalesReport | 2701 | ❌ |
| Monthly Breakdown | FINANCIAL_REPORTS | openMonthlyBreakdown | 2707 | ❌ |
| Over dues | FINANCIAL_REPORTS | openOverduesReport | 2713 | ❌ |
| Upload Employees | HR_MASTER | openUploadEmployees | 2787 | ❌ |
| Create Department | HR_MASTER | openCreateDepartment | 2793 | ❌ |
| Create Level | HR_MASTER | openCreateLevel | 2799 | ❌ |
| Create Position | HR_MASTER | openCreatePosition | 2805 | ❌ |
| Reporting Map | HR_MASTER | openReportingMap | 2811 | ❌ |
| Assign Positions | HR_MASTER | openAssignPositions | 2817 | ❌ |
| Contact Management | HR_MASTER | openContactManagement | 2823 | ❌ |
| Document Management | HR_MASTER | openDocumentManagement | 2829 | ❌ |
| Salary & Wage Management | HR_MASTER | openSalaryManagement | 2835 | ❌ |
| Warning Master | HR_MASTER | openWarningMaster | 2841 | ❌ |
| Biometric Data | HR_MASTER | openBiometricData | 2898 | ❌ |
| Export Biometric Data | HR_MASTER | openExportBiometricData | 2904 | ❌ |
| Task Master | TASK_MASTER | openTaskMaster | 2952 | ❌ |
| Create Task Template | TASK_MASTER | openCreateTask | 2981 | ❌ |
| View Task Templates | TASK_MASTER | openViewTasks | 2987 | ❌ |
| Assign Tasks | TASK_MASTER | openAssignTasks | 3018 | ❌ |
| View My Tasks | TASK_MASTER | openMyTasks | 3045 | ❌ |
| View My Assignments | TASK_MASTER | openMyAssignments | 3051 | ❌ |
| Task Status | TASK_MASTER | openTaskStatus | 3057 | ❌ |
| Branch Performance | TASK_MASTER | openBranchPerformanceWindow | 3063 | ❌ |
| Com Center | NOTIFICATION_CENTER | openCommunicationCenter | 3111 | ❌ |
| Branch Master | BRANCH_MASTER | openBranches | 3216 | ✅ |
| Users | USER_MGMT | openUserManagement | 3222 | ✅ |
| Sound Settings | SETTINGS | openSettings | 3228 | ❌ |
| ERP Connections | SETTINGS | openERPConnections | 3234 | ❌ |
| Interface Access | SETTINGS | openInterfaceAccessManager | 3240 | ❌ |
| Approval Permissions | USER_MGMT | openApprovalPermissions | 3246 | ❌ |
| User Permissions | USER_MGMT | openUserPermissions | 3254 | ✅ |
| Clear Tables | SETTINGS | openClearTables | 3260 | ✅ |

---

## 🔴 Items Needing Permission Checks

| Menu Text | Function Code | Recommended Permission | Line |
|-----------|---------------|------------------------|------|
| New Start Receiving | RECEIVING_MGMT | `canView('RECEIVING_MGMT')` | 1899 |
| Products Manager | PRODUCT_MGMT | `canView('PRODUCT_MGMT')` | 1984 |
| Delivery Settings | SETTINGS | `canView('SETTINGS')` | 1990 |
| Receiving | RECEIVING_MGMT | `canView('RECEIVING_MGMT')` | 2104 |
| Upload Vendor | VENDOR_MGMT | `canView('VENDOR_MGMT')` | 2135 |
| Create Vendor | VENDOR_MGMT | `canView('VENDOR_MGMT')` | 2141 |
| Manage Vendor | VENDOR_MGMT | `canView('VENDOR_MGMT')` | 2147 |
| Start Receiving | RECEIVING_MGMT | `canView('RECEIVING_MGMT')` | 2178 |
| Receiving Records | RECEIVING_MGMT | `canView('RECEIVING_MGMT')` | 2184 |
| Vendor Records | FINANCIAL_REPORTS | `canView('FINANCIAL_REPORTS')` | 2215 |
| Vendor Payments | FINANCIAL_REPORTS | `canView('FINANCIAL_REPORTS')` | 2221 |
| Flyer Master | OFFER_MGMT | `canView('OFFER_MGMT')` | 2269 |
| Product Master | PRODUCT_MGMT | `canView('PRODUCT_MGMT')` | 2300 |
| Variation Manager | PRODUCT_MGMT | `canView('PRODUCT_MGMT')` | 2306 |
| Offer Manager | OFFER_MGMT | `canView('OFFER_MGMT')` | 2312 |
| Flyer Templates | OFFER_MGMT | `canView('OFFER_MGMT')` | 2318 |
| Settings | SETTINGS | `canView('SETTINGS')` | 2324 |
| Offer Product Editor | OFFER_MGMT | `canView('OFFER_MGMT')` | 2355 |
| Create New Offer | OFFER_MGMT | `canView('OFFER_MGMT')` | 2361 |
| Pricing Manager | PRICE_MGMT | `canView('PRICE_MGMT')` | 2367 |
| Generate Flyers | OFFER_MGMT | `canView('OFFER_MGMT')` | 2373 |
| Shelf Paper Manager | OFFER_MGMT | `canView('OFFER_MGMT')` | 2379 |
| Coupon Dashboard | COUPON_MGMT | `canView('COUPON_MGMT')` | 2447 |
| Manage Campaigns | COUPON_MGMT | `canView('COUPON_MGMT')` | 2478 |
| Import Customers | COUPON_MGMT | `canView('COUPON_MGMT')` | 2509 |
| Manage Products | COUPON_MGMT | `canView('COUPON_MGMT')` | 2515 |
| Reports & Stats | COUPON_MGMT | `canView('COUPON_MGMT')` | 2546 |
| Manual Scheduling | PAYMENT_SCHEDULER | `canView('PAYMENT_SCHEDULER')` | 2644 |
| Day Budget Planner | BUDGET_TRACKING | `canView('BUDGET_TRACKING')` | 2650 |
| Monthly Manager | FINANCIAL_REPORTS | `canView('FINANCIAL_REPORTS')` | 2656 |
| Expense Manager | EXPENSE_MGMT | `canView('EXPENSE_MGMT')` | 2662 |
| Paid Manager | PAYMENT_SCHEDULER | `canView('PAYMENT_SCHEDULER')` | 2668 |
| Expense Tracker | FINANCIAL_REPORTS | `canView('FINANCIAL_REPORTS')` | 2695 |
| Sales Report | SALES_REPORTS | `canView('SALES_REPORTS')` | 2701 |
| Monthly Breakdown | FINANCIAL_REPORTS | `canView('FINANCIAL_REPORTS')` | 2707 |
| Over dues | FINANCIAL_REPORTS | `canView('FINANCIAL_REPORTS')` | 2713 |
| Upload Employees | HR_MASTER | `canView('HR_MASTER')` | 2787 |
| Create Department | HR_MASTER | `canView('HR_MASTER')` | 2793 |
| Create Level | HR_MASTER | `canView('HR_MASTER')` | 2799 |
| Create Position | HR_MASTER | `canView('HR_MASTER')` | 2805 |
| Reporting Map | HR_MASTER | `canView('HR_MASTER')` | 2811 |
| Assign Positions | HR_MASTER | `canView('HR_MASTER')` | 2817 |
| Contact Management | HR_MASTER | `canView('HR_MASTER')` | 2823 |
| Document Management | HR_MASTER | `canView('HR_MASTER')` | 2829 |
| Salary & Wage Management | HR_MASTER | `canView('HR_MASTER')` | 2835 |
| Warning Master | HR_MASTER | `canView('HR_MASTER')` | 2841 |
| Biometric Data | HR_MASTER | `canView('HR_MASTER')` | 2898 |
| Export Biometric Data | HR_MASTER | `canView('HR_MASTER')` | 2904 |
| Task Master | TASK_MASTER | `canView('TASK_MASTER')` | 2952 |
| Create Task Template | TASK_MASTER | `canView('TASK_MASTER')` | 2981 |
| View Task Templates | TASK_MASTER | `canView('TASK_MASTER')` | 2987 |
| Assign Tasks | TASK_MASTER | `canView('TASK_MASTER')` | 3018 |
| View My Tasks | TASK_MASTER | `canView('TASK_MASTER')` | 3045 |
| View My Assignments | TASK_MASTER | `canView('TASK_MASTER')` | 3051 |
| Task Status | TASK_MASTER | `canView('TASK_MASTER')` | 3057 |
| Branch Performance | TASK_MASTER | `canView('TASK_MASTER')` | 3063 |
| Com Center | NOTIFICATION_CENTER | `canView('NOTIFICATION_CENTER')` | 3111 |
| Sound Settings | SETTINGS | `canView('SETTINGS')` | 3228 |
| ERP Connections | SETTINGS | `canView('SETTINGS')` | 3234 |
| Interface Access | SETTINGS | `canView('SETTINGS')` | 3240 |
| Approval Permissions | USER_MGMT | `canView('USER_MGMT')` | 3246 |

---

## ✅ Implementation Guide

### Step 1: Add Permission Utility Import

```typescript
import { canView } from '$lib/utils/permissions';
```

### Step 2: Replace Role Checks with Permission Checks

**OLD PATTERN:**
```svelte
{#if $currentUser?.roleType === 'Master Admin' || $currentUser?.roleType === 'Admin'}
  <button on:click={openCustomerMaster}>
    Customer Master
  </button>
{/if}
```

**NEW PATTERN:**
```svelte
{#if canView('CUSTOMER_MGMT')}
  <button on:click={openCustomerMaster}>
    Customer Master
  </button>
{/if}
```

### Step 3: Menu Items by Function Code

#### BRANCH_MASTER
- **Permission Check:** `canView('BRANCH_MASTER')`
- **Menu Items:**
  - Branch Master (line 3216)

#### BUDGET_TRACKING
- **Permission Check:** `canView('BUDGET_TRACKING')`
- **Menu Items:**
  - Day Budget Planner (line 2650)

#### COUPON_MGMT
- **Permission Check:** `canView('COUPON_MGMT')`
- **Menu Items:**
  - Coupon Dashboard (line 2447)
  - Manage Campaigns (line 2478)
  - Import Customers (line 2509)
  - Manage Products (line 2515)
  - Reports & Stats (line 2546)

#### CUSTOMER_MGMT
- **Permission Check:** `canView('CUSTOMER_MGMT')`
- **Menu Items:**
  - Customer Master (line 1972)
  - Orders Manager (line 2023)

#### EXPENSE_MGMT
- **Permission Check:** `canView('EXPENSE_MGMT')`
- **Menu Items:**
  - Expense Manager (line 2662)

#### FINANCIAL_REPORTS
- **Permission Check:** `canView('FINANCIAL_REPORTS')`
- **Menu Items:**
  - Vendor Records (line 2215)
  - Vendor Payments (line 2221)
  - Monthly Manager (line 2656)
  - Expense Tracker (line 2695)
  - Monthly Breakdown (line 2707)
  - Over dues (line 2713)

#### HR_MASTER
- **Permission Check:** `canView('HR_MASTER')`
- **Menu Items:**
  - Upload Employees (line 2787)
  - Create Department (line 2793)
  - Create Level (line 2799)
  - Create Position (line 2805)
  - Reporting Map (line 2811)
  - Assign Positions (line 2817)
  - Contact Management (line 2823)
  - Document Management (line 2829)
  - Salary & Wage Management (line 2835)
  - Warning Master (line 2841)
  - Biometric Data (line 2898)
  - Export Biometric Data (line 2904)

#### NOTIFICATION_CENTER
- **Permission Check:** `canView('NOTIFICATION_CENTER')`
- **Menu Items:**
  - Ad Manager (line 1978)
  - Com Center (line 3111)

#### OFFER_MGMT
- **Permission Check:** `canView('OFFER_MGMT')`
- **Menu Items:**
  - Offer Management (line 2029)
  - Flyer Master (line 2269)
  - Offer Manager (line 2312)
  - Flyer Templates (line 2318)
  - Offer Product Editor (line 2355)
  - Create New Offer (line 2361)
  - Generate Flyers (line 2373)
  - Shelf Paper Manager (line 2379)

#### PAYMENT_SCHEDULER
- **Permission Check:** `canView('PAYMENT_SCHEDULER')`
- **Menu Items:**
  - Manual Scheduling (line 2644)
  - Paid Manager (line 2668)

#### PRICE_MGMT
- **Permission Check:** `canView('PRICE_MGMT')`
- **Menu Items:**
  - Pricing Manager (line 2367)

#### PRODUCT_MGMT
- **Permission Check:** `canView('PRODUCT_MGMT')`
- **Menu Items:**
  - Products Manager (line 1984)
  - Product Master (line 2300)
  - Variation Manager (line 2306)

#### RECEIVING_MGMT
- **Permission Check:** `canView('RECEIVING_MGMT')`
- **Menu Items:**
  - New Start Receiving (line 1899)
  - Receiving (line 2104)
  - Start Receiving (line 2178)
  - Receiving Records (line 2184)

#### SALES_REPORTS
- **Permission Check:** `canView('SALES_REPORTS')`
- **Menu Items:**
  - Sales Report (line 2701)

#### SETTINGS
- **Permission Check:** `canView('SETTINGS')`
- **Menu Items:**
  - Delivery Settings (line 1990)
  - Settings (line 2324)
  - Sound Settings (line 3228)
  - ERP Connections (line 3234)
  - Interface Access (line 3240)
  - Clear Tables (line 3260)

#### TASK_MASTER
- **Permission Check:** `canView('TASK_MASTER')`
- **Menu Items:**
  - Task Master (line 2952)
  - Create Task Template (line 2981)
  - View Task Templates (line 2987)
  - Assign Tasks (line 3018)
  - View My Tasks (line 3045)
  - View My Assignments (line 3051)
  - Task Status (line 3057)
  - Branch Performance (line 3063)

#### USER_MGMT
- **Permission Check:** `canView('USER_MGMT')`
- **Menu Items:**
  - Users (line 3222)
  - Approval Permissions (line 3246)
  - User Permissions (line 3254)

#### VENDOR_MGMT
- **Permission Check:** `canView('VENDOR_MGMT')`
- **Menu Items:**
  - Upload Vendor (line 2135)
  - Create Vendor (line 2141)
  - Manage Vendor (line 2147)

