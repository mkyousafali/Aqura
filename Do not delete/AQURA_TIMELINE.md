# Aqura Development Timeline

> **Total Commits: 232** | December 31, 2025 → February 12, 2026  
> Repository: `mkyousafali/Aqura`

---

## 📅 December 2025

### December 31, 2025 (3 commits)
- 🚀 **Initial commit** — Clean repository (AQ32.12.7.7)
- 🔒 Remove remaining hardcoded keys and deprecated function
- 🐛 Fix date range calculation for last day of month in PaidManager

---

## 📅 January 2026

### January 1, 2026 (5 commits)
- 🧾 Fix voucher issue receipt: bilingual template, table format, total value, print popup window, PV code format
- 🔧 Fix Supabase env vars in API endpoint for Vercel build
- 🗑️ Remove unused purchase-vouchers API endpoint
- 📝 Add better error logging for user creation
- 💰 Update finance voucher components and add receipts bucket migration

### January 2, 2026 (1 commit)
- 📦 **Purchase Voucher Manager improvements:** Status cards with stats, branch selection for internal stock transfer, PV ID exact match search, book-wise and voucher-wise views with pagination

### January 3, 2026 (3 commits)
- 🔄 Fix stock transfer workflow and add realtime updates to purchase voucher components
- 🔍 Purchase voucher improvements: close gift with expense, search by PV ID/serial, closed stats card
- 🐛 Fix fetch errors and race conditions in PurchaseVoucher components

### January 4, 2026 (3 commits)
- 📱 Add mobile PV Manager with i18n, permission control, RTL support, and currency icon sizing
- 📊 Add book count display to mobile purchase voucher manager
- 💵 **Denomination feature:** ERP balance comparison, Suspends panel with Paid/Received sections

### January 6, 2026 (6 commits)
- 🐛 Fix box_operations status constraint to support `pending_close` status
- ⏰ Add recharge card transaction date/time saving to CloseBox and ClosingDetails
- 📸 Add POS before closing image save feature, logo to thermal receipt, auto-save to storage bucket
- 🐛 Fix Supabase client initialization error in deployed version
- 🐛 Restore missing upload logic to `saveA4AsPNG` function
- 🐛 Fix import supabase client from utils instead of creating new instance

### January 7, 2026 (5 commits)
- 🎨 Fix CloseBox and ClosingDetails layout/styling — reduce spacing, add orange borders, optimize card sizes, make fields readonly, display supervisor name
- 🐛 Fix: Logout button in cashier taskbar now works
- 🐛 Fix: Include purchase vouchers in autosave for close box details
- 🎨 Optimize electronic signature card layout and spacing
- ✅ Add voucher status check feature to CompleteBox and fix denomination loading

### January 8, 2026 (3 commits)
- 📋 **Closed Boxes viewer** with completed operations tracking and imperial green styling
- 🔒 RLS policies for `hr_employee_master` table and save all users in LinkID
- 💰 **Denomination transaction system** with modals, tables, delete confirmation, and notification popups

### January 9, 2026 (5 commits)
- 🐛 Fix CompleteBox and CompletedBoxDetails: Update base values immediately on edit, load complete_details properly
- ➕ Add 3 new POS advance boxes (E1, E2, E3) — boxes 10, 11, 12
- 🎨 Add special styling for extra cash boxes (E1-E3)
- ✨ Progressive disclosure workflow with numbered checkboxes, ERP popup modal, and green checkmarks
- 👤 **Employee ID mapping:** Double-click edit, clear button, EMP ID format, batch save for 100k+ users

### January 10, 2026 (5 commits)
- 🐛 Fix EMP ID duplicate issue, add status column, auto-load users, highlight inactive users in red
- 🎨 Replace browser alerts with custom success modal + Arabic translations
- 🎨 Adjust CloseBox UI: reduce recharge card height, increase time input width
- 🐛 Fix time loading in CompleteBox: parse recharge_transaction times
- ⏰ Add recharge card section to CounterCheck with start date, time, and opening balance

### January 11, 2026 (3 commits)
- 🖼️ Add PA logo to CompleteBox print header and fix cashier name reactive parsing
- 🎨 Restructure denomination layout: moved branch selector and completed ops cards
- 🎨 Optimize branch selector: move button to same line as dropdown

### January 12, 2026 (11 commits)
- ⏰ Auto-fill recharge card date/time and remove opening balance field
- 📊 Auto-load denomination counts and make specific boxes read-only
- 🎨 Fix balance cards layout — display side by side
- 🔒 Make all fields read-only and disable Add to Denomination in CompletedBoxDetails
- 🐛 Fix difference calculation formula — update labels to Real Cash is Excess/Short
- 🐛 Fix recharge card sales calculation formula (closing-opening)
- ✅ Removed bulk approval, added inline accept/reject buttons (desktop + mobile)
- 📱 Updated mobile: added button names to dropdown, reorganized navigation, fixed fingerprint display
- 🎨 Updated mobile dashboard: button colors, Active POS card with purple styling
- 🔍 Added amount filter to POS Report
- 🏦 **Bank Reconciliation** with 8 bank/card buttons and XLSX import

### January 13, 2026 (6 commits)
- 📋 Update receiving task completion and vendor payment schedule migrations
- 📱 Update mobile: change box labels to POS, conditionally display cards
- ✏️ Add edit functionality to VendorPendingPayments with modal
- 💰 Fix petty cash real-time updates: add +/- buttons, improve subscriptions
- 🗑️ Remove manual HR management components (replaced by automatic sync)
- 🗑️ Complete warning system removal: delete all warning components

### January 14, 2026 (5 commits)
- 👆 **Fingerprint Transactions viewer** with real-time updates, pagination, and advanced filtering
- 💰 **HR Salary and Wage management** with basic salary, other allowance, and payment modes
- 👤 Add sponsorship status toggle to EmployeeFiles
- 🐛 Fix edit buttons and bank info loading in EmployeeFiles
- 📋 Add health educational renewal date, personal information card (DOB/join date), work permit expiry

### January 15, 2026 (3 commits)
- ✅ Add probation period finished badge and update expiry message
- 🎨 Change color scheme to orange, green, and white throughout
- 📅 **Day Off (weekday-wise)** feature and UI improvements

### January 16, 2026 (7 commits)
- 💼 Add position name column and filter to employee search table
- 🔄 Update Sidebar and parse-sidebar-code API endpoint
- 💳 **POS Deduction Transfer** with filters and pagination
- 💳 POS deduction transfers system with status tracking
- ✏️ Add voucher edit and add functionality to CompleteBox
- ⚖️ **Discipline HR module** with auto-generated IDs
- 🍽️ Add food allowance to salary management system

### January 17, 2026 (7 commits)
- 🐛 Fix employee sorting priority and reactivity in ShiftAndDayOff
- 🌐 Add missing translation keys for employee files
- 👤 Update employment statuses: Remote Job, Job (No Finger), Job (With Finger)
- 🐛 Implement reactive filtering and robust ID handling for shift management
- 🌍 Add nationality creation and highlight missing master records in LinkID
- 🐛 Complete fingerprint processing workflow with sequence ID generation
- 🐛 Implement date-aware shift validation with dynamic buffers

### January 18, 2026 (9 commits)
- 👆 **Employee fingerprint analysis** with overnight shift support, early/late/overtime badges, sticky header
- 📋 Add Leave Request button to HR Operations section
- 🐛 Fix overnight shift logic: load `is_shift_overlapping_next_day`
- ⏰ Update ShiftAndDayOff UI to 12h format and fix RTL dropdown arrows
- 🌐 Implement i18n for Discipline page
- ✅ Display selected employee name in day-off approval requests
- 🔄 Implement real-time synchronization for analysis, shift, and salary modules
- 📝 Add description field to day off requests
- 📱 Add Human Resources menu to mobile bottom navigation

### January 19, 2026 (12 commits)
- 📱 Mobile Fingerprint Analysis: day off, leave status, missing punch indicators
- 📊 **Bulk Fingerprint Analysis (Analyze All)** with RTL support
- 🏢 Update cashier login branch dropdown for locale
- 🐛 Bulk fingerprint analysis fixes and localized cashier selection
- 📝 Comprehensive VersionChangelog update for AQ34.13.8.8
- 📝 Create Versioning and Changelog Update Guide
- 🐛 Fix sync status with proper pairing logic for 'Other' punch classification
- 📝 Update changelog with punch sync fix details
- 📝 Update version workflow guide
- 🐛 Fix close div in VersionChangelog
- 🐛 Fix changelog version display to AQ36.14.9.9
- 💰 **Net Salary, Net Bank, Net Cash** calculation columns in salary statement

### January 20, 2026 (3 commits)
- 💰 **POS Shortage Deduction Logic** in salary statement with forgive checkboxes
- 🐛 Fix HR menu popup positioning for RTL (Arabic)
- 🌐 Fix missing translation keys and add special shift date range feature

### January 21, 2026 (7 commits)
- 🐛 Fix mobile notification center auto-loading
- 🐛 Remove limit(100) from markAllAsRead
- 🐛 Fix Tasks section button permissions and mobile branch performance
- 👤 Display employee names/IDs from `hr_employee_master` in user management
- 🐛 Fix LinkID employee editing bug — Use user ID instead of array index
- ✏️ Add comprehensive edit functionality and status management
- 🔔 **Push notification system** with desktop and mobile support

### January 22, 2026 (1 commit)
- 🐛 Fix day-off request handlers in mobile approval center

### January 23, 2026 (1 commit)
- 🔀 Move FINGERPRINT_TRANSACTIONS to HR Reports, remove LEAVES_AND_VACATIONS from Operations

### January 27, 2026 (3 commits)
- 🐛 Fix reconciliation entries: show POS number and cashier name
- 🐛 Fix reconciliation transfer logic for all scenarios
- 🐛 Update excess entries to always transfer to POS Excess account

### January 30, 2026 (2 commits)
- 📅 Add employment status effective date and worked duration calculation
- 🐛 Fix product schema, optimize offer editor performance

### January 31, 2026 (2 commits)
- 🔍 Add search bar to PricingManager, fix VariationManager references
- 🔄 Add realtime subscriptions for PricingManager, ProductMaster, VariationManager

---

## 📅 February 2026

### February 1, 2026 (3 commits)
- 🔢 Add invalid product count badge to Generate Offers button
- 📊 **Overdues Report:** Vendor/Expense tables with export, branch+location display
- 🚨 Add incident report permission and ReportIncident improvements

### February 2, 2026 (3 commits)
- 🔄 Allow resending rejected approval requests with Resend button
- 🔐 Add Finance and Customer/POS incident permissions with dynamic routing
- 🐛 Fix branch dropdown in ReportIncident sidebar mode

### February 3, 2026 (3 commits)
- 📱 Mobile UI: Add Tasks menu with submenu, move Home to top bar, add Incident Manager with badge
- 🐛 Fix mobile submenu positioning — center all bottom nav submenus
- ✅ Incident follow-up task completion blocked until resolved, bilingual notifications

### February 4, 2026 (8 commits)
- 🐛 Fix vendor payment approval: Only send to selected approver
- 🔄 Add refresh button to MonthlyManager
- 🐛 Fix file upload: Sanitize Arabic filenames for expense bills
- 🏷️ Display selected offer name in Step 3 review
- 📋 **Page/order tracking** for flyer offer products with multi-category filter
- 🤖 **AI group name generator**, category filter in VariationManager
- 🐛 Fix variant modal only includes group products
- ✨ Create variant group from OfferProductSelector with AI naming

### February 5, 2026 (6 commits)
- 📊 **View All Paid** windows with filters and Excel export for vendor/expense payments
- 📊 Add sticky header, filters, and Excel export to AllVendorPaid/AllExpensePaid
- 🖼️ **Update app logo** to new Aqura logo across all interfaces
- 🐛 Fix pnpm-lock.yaml
- 🎨 Hide columns and update header in ERP Entry Manager
- 🖨️ Automatic grid layout for variant images in shelf paper PDFs

### February 6, 2026 (3 commits)
- 🖨️ Add page/order columns and print to shelf paper manager
- 📋 Add double-click copy with formatted date for offer types
- 🔍 Add search bar, B8-B11 pricing buttons, fix field name handling

### February 7, 2026 (5 commits)
- 🐛 Fix: Sync total_offer_price and total_sales_price for variant products
- 🎨 Add color coding to offer decrease column
- 📊 Add serial numbers, reorder columns, format dates, color-code offer end dates in export
- 🎨 **Custom font upload** and per-field font selection for shelf paper templates
- 🖼️ Improve flyer generator with image handling, Arabic text, and export fixes

### February 8, 2026 (9 commits)
- 🖼️ Add individual image movement for offer_qty products
- 🐛 Preserve individual image positions/sizes in PNG export
- ✨ Add `variant_icon` field type for flyer templates
- ✨ Add `expiry_date_label` field type
- 🗑️ Remove SVG/PDF/Print export, update price strikethrough, add dates to PNG filename
- 📄 Add page numbers and rotation support to flyer system
- 🎨 Match page number button design with action buttons
- 🔧 Update pnpm-lock.yaml
- 📄 **Normal Paper Manager** with template download, Excel import, table display, and scannable barcode printing

### February 9, 2026 (6 commits)
- 🌐 Add logout confirmation translations and fix nav.cancel key
- 🐛 Preserve pricing data in Offer Product Editor (upsert instead of delete+reinsert)
- 🖨️ Shelf paper: parallel load, template loading indicator, select-all size buttons, offer_qty image grid
- 📝 Changelog update for AQ39 — shelf paper, offer editor, favorites, flyer
- 🏷️ **One Day Offer Manager** with import, pricing, print, and barcode export
- 📝 Changelog update for AQ40

### February 10, 2026 (7 commits)
- 🐛 Fix product creation ID generation and variation group queries
- 🐛 Fix uppercase AI-generated English group name
- 🏷️ Add offer name creation, flyer generator improvements, HR checklist module
- 📋 **HR checklist operations** with View Answers and Report Problem button
- 👆 **Punch display:** Last 2 punches across all branches using `hr_employee_master`
- ⭐ **Drag-and-drop reordering** for favorite buttons with auto-save
- 🐛 Fix/revert SalesReport realtime subscription

### February 11, 2026 (16 commits)
- 📊 Styled **Export Excel** added to AnalyzeAllWindow with i18n keys
- ✅ Remove browser alerts from approval permissions, optimize refresh
- 🔧 Update pnpm lock file (xlsx-js-style)
- 📋 **Daily Checklist fix:** auto-save with persistent auth, hide user ID, fix infinite loop
- 📊 Pending checklists count on home page, enhanced checklist UI
- 📱 Mobile: pending checklists counter and submission tracking
- 📝 Changelog update for AQ40.15
- 🚨 Improve incident management and reporting
- 👁️ Add eye icon to incident reports count
- 🐛 Fix missing MY_DAILY_CHECKLIST button detection
- 🐛 Fix: save logged user branch_id to hr_checklist_operations
- 📦 **Products Dashboard:** modernized UI with search/filter features
- 🏷️ **Shelf Paper:** loading indicators, copy template, font manager, app notifications
- 🏷️ Add Shelf Paper Template Designer button to Media → Manage
- ⏰ **Taskbar:** My Daily Checklist button with pending count badge
- 🌐 **Sidebar:** language switch and compact online indicator

### February 12, 2026 (6 commits)
- 🎨 **Theme System:** desktop interface theme management with CSS variables, persists on reload
- 💃 **Dancing Character:** Lottie animation with bilingual greetings on desktop
- 🤖 **AI Chat System:** Aqura bot with TTS voice selection, sales report integration, voice input
- 📊 **Enhanced Sales Report:** comparisons, voice input, full dates
- 📱 Mobile AI chat: cleanup, icon-only bottom nav
- 📦 **Receiving overhaul:** branch default positions, clearance certificate improvements, default branch for receiving, UI cleanup
- ⚠️ **Info card** on welcome screen, changelog date fix, version badge on login

---

## 📊 Summary

| Month | Commits | Key Features |
|-------|---------|-------------|
| **Dec 2025** | 3 | Initial commit, security cleanup |
| **Jan 2026** | 128 | POS/Finance system, HR modules, Fingerprint analysis, Denomination, Salary management, Push notifications |
| **Feb 2026** | 101 | Flyer system, Shelf paper, Products dashboard, AI chat, Theme system, Receiving defaults, Incident manager |
| **Total** | **232** | |

### Major Milestones
| Version | Date | Highlights |
|---------|------|-----------|
| **AQ32** | Dec 31 | Initial release |
| **AQ33** | Jan 16 | Finance, POS, Denomination, Discipline |
| **AQ34** | Jan 19 | HR Fingerprint Analysis, Salary, Day Off |
| **AQ36** | Jan 19 | Punch sync fix, Salary statement |
| **AQ37** | Jan 21 | User management, Push notifications |
| **AQ38** | Feb 3 | Flyer templates, Incident manager |
| **AQ39** | Feb 9 | Shelf paper, Offer editor, Normal paper |
| **AQ40** | Feb 9 | One Day Offer Manager, Products dashboard |
| **AQ41** | Feb 12 | AI Chat, Theme system, Receiving defaults |
