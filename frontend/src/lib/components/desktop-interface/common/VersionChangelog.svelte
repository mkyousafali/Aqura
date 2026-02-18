<script lang="ts">
export let onClose: () => void;
</script>

<div class="version-changelog-window">
<div class="window-content">
<div class="version-format">
<p class="version-title">Version AQ57.23.15.16</p>
<p class="version-details">Desktop: 57 | Mobile: 23 | Cashier: 15 | Customer: 16</p>
</div>

<div class="latest-change">
<h3>✨ Lease & Rent Finance Module, Receiving Overhaul & Clearance Certificate Improvements</h3>
<p class="change-description">New Lease & Rent property management module, full i18n for the Receiving workflow with multi shelf-stocker selection, and clearance certificate print-only mode for edited bills.</p>
<div class="change-details">
<h4>February 18, 2026 (Latest):</h4>
<ul>
<li>✅ <b>Lease & Rent Module:</b> New finance module for managing properties, spaces, lease/rent parties, and special changes. Full CRUD with tabbed interface, party management (lease & rent), property spaces, and RPC-powered data loading.</li>
<li>✅ <b>Lease & Rent Database:</b> New tables (lease_rent_lease_parties, lease_rent_rent_parties, lease_rent_property_spaces, lease_rent_special_changes) and optimized RPC functions for fast data retrieval.</li>
<li>✅ <b>Receiving i18n:</b> Full English/Arabic translation support across the entire StartReceiving workflow — step labels, branch selection, vendor selection, bill information, and finalization screens.</li>
<li>✅ <b>Multi Shelf-Stocker Selection:</b> Receiving now supports selecting multiple shelf stockers instead of a single one, with keyboard navigation and highlight support.</li>
<li>✅ <b>Clearance Certificate Print-Only Mode:</b> When editing a bill, the certificate can now be printed without re-assigning tasks (printOnly mode). Separate "Print & Assign Tasks" flow for new bills vs re-prints.</li>
<li>✅ <b>Auto-Fill Bill Date:</b> Bill date now auto-fills with today's date in the receiving workflow.</li>
<li>✅ <b>Vendor Search Keyboard Navigation:</b> Added highlight index support for vendor dropdown keyboard navigation.</li>
<li>✅ <b>Branch Location Support:</b> Receiving now fetches and displays both English and Arabic branch locations.</li>
</ul>
</div>
</div>

<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
<h3>✨ Mobile Assignments — Completed Tasks View, Completion Photos & Image Compression</h3>
<p class="change-description">New completed assignments page with task/completion photo separation, View buttons for all photos, and automatic image compression for quick task file uploads.</p>
<div class="change-details">
<h4>February 17, 2026:</h4>
<ul>
<li>✅ <b>Completed Assignments Page:</b> New dedicated page at /assignments/completed showing all completed task assignments with search, green-bordered cards, completion date, and attachment support.</li>
<li>✅ <b>Completion Photos & Notes:</b> Both assignments and completed assignments pages now load and display completion photos separately from original task attachments.</li>
<li>✅ <b>Quick Task Image Compression:</b> Images uploaded via QuickTaskModal are now automatically compressed before upload — reducing 5-10MB phone photos to ~100-300KB.</li>
<li>✅ <b>i18n Support:</b> Full English and Arabic translations for all completed assignments page strings.</li>
</ul>
</div>
</div>
<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
<h3>✨ Marketing Module — Shelf Paper & Flyer Template Improvements</h3>
<p class="change-description">Arabic unit names on shelf paper, flyer page number zero-padding, single-line expiry date labels, and rename/delete template management for both Shelf Paper and Flyer Template Designers.</p>
<div class="change-details">
<h4>February 17, 2026 (Latest):</h4>
<ul>
<li>✅ <b>Shelf Paper — Arabic Unit Names:</b> Unit names on shelf paper now display in Arabic only (<code>unit_name_ar</code>) with RTL direction, across print table, PDF generation (single & batch), and the product table UI.</li>
<li>✅ <b>Flyer Generator — Zero-Padded Page Numbers:</b> Page numbers now display as 01, 02, 03 instead of 1, 2, 3 for cleaner visual presentation on both first page and sub pages.</li>
<li>✅ <b>Flyer Generator — Single-Line Expiry Labels:</b> Expiry date labels now wrap naturally on a single line instead of splitting across two lines, applied to both first page and sub page sections.</li>
<li>✅ <b>Shelf Paper Template Designer — Rename & Delete:</b> Added rename and delete buttons next to the template selector. Rename opens a modal to update template name. Delete uses a confirmation dialog and performs a soft-delete (sets <code>is_active: false</code>).</li>
<li>✅ <b>Flyer Template Designer — Rename & Delete:</b> Same rename/delete functionality added for flyer templates with confirmation dialogs and soft-delete mechanism.</li>
</ul>
</div>
</div>
<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
<h3>✨ Remote Branch Frontend Deployment System</h3>
<p class="change-description">New remote frontend deployment pipeline enabling one-click branch updates through Cloudflare tunnel. Builds are uploaded to cloud storage and branches pull updates automatically via the StorageManager UI.</p>
<div class="change-details">
<h4>February 17, 2026 (Latest):</h4>
<ul>
<li>✅ <b>Remote Frontend Update Service:</b> Node.js service running on branch VMs (port 3002) that handles downloading, extracting, and deploying new frontend builds. Endpoints: /health, /status (version info), and /update (deploy new build). Preserves .env during deployments.</li>
<li>✅ <b>Cloud Build Storage:</b> New <code>frontend_builds</code> database table and <code>frontend-builds</code> Supabase Storage bucket for storing versioned build ZIPs (up to 100MB). Includes <code>get_latest_frontend_build()</code> RPC function.</li>
<li>✅ <b>StorageManager — Frontend Deployment UI:</b> New "Frontend Deployment" section in Branch Sync tab with build upload button, latest build info card, and per-branch "Check Version" / "Update Frontend" controls with real-time status indicators.</li>
<li>✅ <b>Version Script — --deploy Flag:</b> The <code>simple-push.js</code> version script now supports a <code>--deploy</code> flag that automatically builds the frontend with adapter-node, creates a ZIP, uploads to cloud storage, and registers in the database — all in one command.</li>
<li>✅ <b>Branch Proxy Enhancement:</b> Made apiKey optional in branch-proxy for non-Supabase endpoints (update service). Increased timeout from 60s to 120s for large build transfers.</li>
<li>✅ <b>Cloudflare Tunnel Integration:</b> Update service accessible via <code>branch3-update.urbanaqura.com</code> tunnel route using HTTP/2 protocol.</li>
</ul>
</div>
</div>
<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
<h3>✨ Expiry Control System, Product Claim Manager & Enhanced Update Badge</h3>
<p class="change-description">Complete Expiry Control management with multi-select bulk operations, new Product Claim Manager for branch inventory assignments, grouped day-off approvals, shelf paper enhancements, and a persistent update notification system.</p>
<div class="change-details">
<h4>February 16, 2026:</h4>
<ul>
<li>✅ <b>Expiry Control — New Module:</b> High-performance expiry date management using materialized views. Four interactive tabs: <b>Quick Report</b> (15-day critical), <b>Near Expiry</b> (60-day warning), <b>All Products</b> (server-side searchable), and <b>Deleted Items</b> (with undo support).</li>
<li>✅ <b>Multi-Select Bulk Tasks:</b> Added checkbox selection system to Quick Report and Near Expiry tables. Select all or individual items to send multiple tasks at once. Features a sticky floating action bar with selected count and clear/send buttons.</li>
<li>✅ <b>Bulk Send Logic:</b> Updated task dispatcher to loop through selected products, creating individual localized Quick Tasks for assigned employees with priority auto-scaling based on days left.</li>
<li>✅ <b>Product Claim Manager:</b> New tool for managing branch product assignments. Supports unclaiming, transferring between branches, and high-speed employee assignment workflows.</li>
<li>✅ <b>Grouped Day-off Approvals:</b> Desktop Approval Center now groups day-off requests by date range, matching the mobile interface logic for consistent oversight.</li>
<li>✅ <b>Shelf Paper — Lazy Loading:</b> Templates now lazy-load data on selection to improve performance. Added Arabic unit names to limit_qty displays.</li>
<li>✅ <b>Global Update Badge:</b> New always-visible orange/red update badge in the sidebar across all interfaces. Auto-detects manual cache refreshes and service worker updates.</li>
<li>✅ <b>PWA Update Reliability:</b> Removed high-friction modal popups. Added <code>userClickedUpdate</code> safety flag to prevent automatic reloads while users are in the middle of a task.</li>
<li>✅ <b>UI/UX Enhancements:</b> Added info hints to Expiry tabs explaining the checkbox workflow. Corrected product name localization (EN/AR fallback) in task descriptions and popup info cards.</li>
</ul>
</div>
</div>
<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
		<h3>✨ Offer Cost Manager with Price Comparison, Mobile Price Checker & ERP Bridge Enhancements</h3>
		<p class="change-description">New Offer Cost Manager for desktop with multi-branch ERP price comparison, barcode/name search, editable compared prices, and Quick Task price change workflow. New mobile Price Checker page with barcode scanning and offer detection. ERP Bridge enhanced with query and price-check endpoints plus service control panel.</p>
		<div class="change-details">
			<h4>February 16, 2026:</h4>
			<ul>
				<li>✅ <b>Offer Cost Manager — New Component:</b> Full-featured Price Comparison table that loads offer products and fetches cost/sales prices from all ERP branches in parallel. 6-location barcode search across ProductUnits, ProductBatches (Manual, Auto, Unit2, Unit3), and ProductBarcodes tables with ROW_NUMBER deduplication.</li>
				<li>✅ <b>Search by Barcode:</b> Dedicated barcode search input (violet themed, mono font) — enter comma/space-separated barcodes to look up prices across all selected branches without needing an offer.</li>
				<li>✅ <b>Search by Name:</b> Dedicated name search input (sky blue themed) — ILIKE search on product_name_en and product_name_ar in Supabase, limited to 100 results, then fetches ERP prices for matches.</li>
				<li>✅ <b>Compared Prices Column:</b> Auto-calculates highest cost (with VAT) and highest sales price across branches. Double-click to edit and override values. Reactivity fix: creates new row object references so Svelte properly re-renders branch cells when overrides change.</li>
				<li>✅ <b>Bidirectional Price Arrows:</b> Branch cells show ↓ red background when cost is lower than compared, ↑ orange background when higher. Sales price cells show ↓ yellow when lower, ↑ light yellow when higher. Green ✓ checkmark when prices match.</li>
				<li>✅ <b>Send Price — Quick Tasks:</b> Per-row and Send All buttons create Quick Tasks assigned to each branch's inventory manager with barcode, product name, current vs. target price, and 24-hour deadline.</li>
				<li>✅ <b>Branch Selector:</b> Checkbox dropdown to select which branches to compare. VAT percentage input (default 15%). All branches selected by default on mount.</li>
				<li>✅ <b>Mobile Price Checker:</b> New mobile page at /mobile-interface/price-checker with branch selection, connection testing, barcode camera scanning (BarcodeDetector API), manual barcode entry, and rich product display with offer detection (Cash Discount, Buy N Get M Free, Gift on Billing, Qty offers). Scan history with up to 20 items.</li>
				<li>✅ <b>ERP Bridge — Query Endpoint:</b> New /query endpoint on bridge server accepts read-only SELECT queries with safety validation. Proxied through /api/erp-products with query action.</li>
				<li>✅ <b>ERP Bridge — Price-Check Endpoint:</b> New /price-check endpoint performs barcode lookup + active offer detection in a single round-trip. Searches ProductUnits → ProductBarcodes → ProductBatches, then checks SpecialPriceScheme, QuantityDiscountScheme, and GiftOnBilling tables in parallel.</li>
				<li>✅ <b>Setup Wizard — Service Controls:</b> New Service Status panel with Start/Stop/Restart buttons for both Bridge API and Cloudflare Tunnel services. Real-time status indicators with running/stopped states. HTTP/2 fallback when QUIC protocol is blocked by network.</li>
				<li>✅ <b>i18n Updates:</b> Added searchByBarcode and searchByName translation keys in both English and Arabic locale files.</li>
			</ul>
		</div>
		</div>

		<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
		<h3>✨ Comprehensive Arabic Translation for Mobile Interface</h3>
		<p class="change-description">Full Arabic (RTL) translation across 20+ mobile pages including approval center, notifications, assignments, tasks, POS closed boxes, receiving tasks, and more. Bilingual helpers, relative time display, status badge translations, and employee name localization.</p>
		<div class="change-details">
			<h4>February 15, 2026:</h4>
			<ul>
				<li>✅ <b>Approval Center — Full Arabic:</b> All labels, badges, buttons, modals, toasts, empty states translated. Status badges (Pending/Approved/Rejected) show in Arabic. Requester and employee names display Arabic names from hr_employee_master. Day-off reasons show in correct language. Relative time display ("3 days ago" / "منذ 3 يوم") for date fields.</li>
				<li>✅ <b>Notifications — Full Arabic:</b> Notification list page, detail page, and create notification page fully translated with RTL support. Date formatting, empty states, and action buttons all bilingual.</li>
				<li>✅ <b>Assignments Page — Arabic:</b> Task assignments page with translated headers, status indicators, and action buttons.</li>
				<li>✅ <b>Tasks System — Arabic:</b> Tasks list, task detail, and task completion pages translated. Camera/file upload buttons, done confirmations, and status labels all bilingual.</li>
				<li>✅ <b>POS Closed Boxes — Arabic:</b> Closed box details page with translated financial labels, date formatting, and branch information.</li>
				<li>✅ <b>Mobile Layout — Arabic:</b> Navigation, header, bottom bar, and menu items translated. RTL direction attribute applied globally based on locale.</li>
				<li>✅ <b>i18n Locale Files:</b> 133+ new translation keys added to both en.ts and ar.ts locale files covering all mobile interface strings.</li>
				<li>✅ <b>Date Formatting Fix:</b> Changed Arabic date locale from ar-SA (Hijri calendar) to ar-EG (Gregorian) across all mobile pages. Saudi timezone (Asia/Riyadh) applied consistently.</li>
				<li>✅ <b>Notification Management:</b> Updated notificationManagement.ts utility with bilingual support for push notification text and notification handling.</li>
				<li>✅ <b>Additional Pages:</b> Quick tasks, receiving tasks, my-checklist, my-products, incident manager, AI chat, and POS pending pages updated with i18n support.</li>
			</ul>
		</div>
		</div>

		<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
		<h3>✨ ERP Auto-Sync Edge Function, Setup Wizard Enhancements & Security Fix</h3>
		<p class="change-description">Automated ERP product synchronization via Supabase Edge Function with pg_cron scheduling, enhanced setup wizard with edit/reinstall capability, ERP Product Manager UI cleanup, and hardcoded API key removal.</p>
		<div class="change-details">
			<h4>February 14, 2026 (Latest):</h4>
			<ul>
				<li>✅ <b>ERP Auto-Sync Edge Function:</b> New <code>auto-sync-erp</code> Supabase Edge Function that automatically syncs ERP products from branch servers to Supabase. Syncs one branch per invocation using round-robin selection (picks branch with oldest last sync). Handles 74K+ products per branch in ~46 seconds with batch upserts of 200.</li>
				<li>✅ <b>pg_cron Scheduling:</b> Three cron jobs running every 20 minutes (:00, :20, :40) — each branch synced approximately once per hour. Self-healing: failed branches (offline servers) are gracefully skipped and retried on next cycle.</li>
				<li>✅ <b>Sync Logging:</b> New <code>erp_sync_logs</code> table tracks every sync invocation with branch details, product counts (fetched/inserted/updated), duration, and trigger source (pg_cron vs manual).</li>
				<li>✅ <b>Setup Wizard — Edit & Reinstall:</b> Existing branch configurations can now be edited without starting from scratch. Wizard detects <code>config.json</code> on startup and pre-fills all fields (database name, server IP, SQL password, tunnel token). Uninstalls old services before reinstalling with new config.</li>
				<li>✅ <b>ERP Product Manager UI Cleanup:</b> Removed 10 statistics cards grid (Products, Batches, Barcodes, etc.) from the ERP Product Manager dashboard. Simplified saved connection cards to show only branch name.</li>
				<li>✅ <b>Security Fix:</b> Removed hardcoded Google API key and Search Engine ID from customer product request page. Now reads from <code>VITE_GOOGLE_API_KEY</code> and <code>VITE_GOOGLE_SEARCH_ENGINE_ID</code> environment variables.</li>
				<li>✅ <b>Database Migrations:</b> 4 SQL migrations — erp_synced_products table, expiry_dates column addition, tunnel_url column for erp_connections, and erp_sync_logs table with RLS.</li>
			</ul>
		</div>
		</div>

		<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
		<h3>✨ Customer Product Requests, Near Expiry Reports & Notification Auto-Cleanup</h3>
		<p class="change-description">New customer product request and near expiry reporting systems with mobile submission pages, desktop management dashboards, OCR scanning, and automatic notification lifecycle management.</p>
		<div class="change-details">
			<h4>February 13, 2026:</h4>
			<ul>
				<li>✅ <b>Mobile — Customer Product Request:</b> New mobile page for staff to submit customer product requests. Includes product name input, camera photo capture, file upload, Google Image Search integration, purchasing manager auto-selection from branch_default_positions, and item list with send functionality.</li>
				<li>✅ <b>Mobile — Near Expiry Reports:</b> New mobile page for reporting near-expiry products. Features barcode scanner (BarcodeDetector API), OCR date scanning via Google Cloud Vision API, step-by-step date picker (Year → Month → Day), photo capture, report title with auto-generation, branch selection with inventory manager lookup, and Save & Send workflow.</li>
				<li>✅ <b>Desktop — Customer Requests List:</b> New CustomerProductRequestsList component with flat item table view, product image thumbnails with lightbox, status filter dropdown, Review/Resolve/Dismiss action buttons, "Mark as Arrived" with notification to requester, Excel export and Print functionality.</li>
				<li>✅ <b>Desktop — Near Expiry Reports List:</b> New NearExpiryRequestsList component with master-detail view. List view shows report title, branch, reporter, manager, item count, status, and date. Detail view with items table (barcode, expiry date DD-MM-YYYY, photos), branch/reporter/manager info cards, notes section, Excel export and Print.</li>
				<li>✅ <b>OCR Text Recognition:</b> Added camera-based OCR scanning to product request page for product name recognition using Google Cloud Vision TEXT_DETECTION. Amber scan button, camera overlay with guide box, selectable detected text lines popup with rescan option.</li>
				<li>✅ <b>Quick Task Integration:</b> Both customer requests and near expiry reports auto-create quick tasks for assigned managers. Tasks auto-complete when request is reviewed/resolved/dismissed.</li>
				<li>✅ <b>Notifications:</b> Status change notifications sent to requester/reporter with bilingual EN/AR messages. Arrived product notifications with product name and image URL.</li>
				<li>✅ <b>Notification Auto-Cleanup:</b> When a user marks a notification as read, their notification_recipients row is deleted. When ALL recipients have read (zero remaining), the entire notification is auto-deleted from notifications, notification_read_states, and notification_attachments tables — keeping the database clean.</li>
				<li>✅ <b>Database:</b> 3 SQL migrations — customer_product_requests table with RLS and indexes, near_expiry_reports table with RLS, indexes, and updated_at trigger, and title column addition to near_expiry_reports.</li>
				<li>✅ <b>UI/UX:</b> Products dashboard modernized with barcode/name search bars, serial numbers, green/orange color scheme, progressive loading. Sidebar language switch (EN/AR electric toggle). Checklist branch_id fix for both mobile and desktop.</li>
			</ul>
		</div>
		</div>

		<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
		<h3>✨ Product Request System — PO/ST/BT with Approval Workflow</h3>
		<p class="change-description">Complete product request system for Purchase Orders (PO), Stock Transfers (ST), and Branch Transfers (BT) with mobile creation, desktop management, quick task integration, notifications, and document management.</p>
		<div class="change-details">
			<h4>February 13, 2026:</h4>
			<ul>
				<li>✅ <b>Mobile — Product Request Creation:</b> Full mobile form with PO/ST/BT tabs, barcode scanning, product photo capture, branch and manager selection, item list with quantities, and XLSX import/export support.</li>
				<li>✅ <b>Desktop — Product Request Management:</b> Three dedicated list views (PORequestsList, StockRequestsList, BTRequestsList) integrated into sidebar. Table view with From/To Branch, Requester, Manager, Items, Status, Date, Docs, and Approve/Reject columns.</li>
				<li>✅ <b>Desktop — Request Detail View:</b> Expandable detail panel with item table, product photos with lightbox, availability checkboxes, and available quantity editing.</li>
				<li>✅ <b>BT Approval Workflow:</b> Approval popup with Inventory Manager (IM) selector. Auto-preselects default IM from branch_default_positions table. Creates a Quick Task for the selected IM to upload the transfer document.</li>
				<li>✅ <b>Document Upload Restriction:</b> Only the assigned Inventory Manager can upload/update BT documents. All other users see View-only access. IM assignment tracked via quick_task_assignments.</li>
				<li>✅ <b>Task Completion Blocking:</b> IM cannot complete BT quick task until document_url exists in product_request_bt table. Enforced on both desktop and mobile completion flows.</li>
				<li>✅ <b>Notifications:</b> Accept/reject sends real-time notification to the requester with status: 'published' for immediate visibility. DB trigger auto-creates notification_recipients from target_users array.</li>
				<li>✅ <b>Quick Task Integration:</b> Auto-creates follow-up and process quick tasks on request creation. Auto-completes related quick tasks when request is accepted or rejected.</li>
				<li>✅ <b>Authorization:</b> Accept/reject buttons visible only to the target_user_id (assigned receiver), preventing unauthorized actions.</li>
				<li>✅ <b>Database:</b> 10 migration files — product_request_po/st/bt tables with RLS, product-request-photos storage bucket, stock-documents storage bucket, document_url columns, and quick_tasks linkage columns (product_request_id, product_request_type).</li>
			</ul>
		</div>
		</div>

		<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
		<h3>✨ Finance — Asset Manager (Complete Feature)</h3>
		<p class="change-description">Full asset management system with 5 tabs: Add Asset, Download Template, Import Assets, Manage Assets, and Manage Categories/Sub Categories.</p>
		<div class="change-details">
			<h4>February 13, 2026 (Latest):</h4>
			<ul>
				<li>✅ <b>Finance — Add Asset:</b> Form with auto-generated Asset ID (editable), sub category selection, asset name EN/AR, purchase date, purchase value, branch selection with location, and invoice upload.</li>
				<li>✅ <b>Finance — Manage Assets Table:</b> Full table with Asset ID, Asset Name, Category, Sub Category, Purchase Date, Asset Value (with SAR currency icon), Branch + Location, Invoice, and Actions columns. Search bar with total asset value display.</li>
				<li>✅ <b>Finance — Edit Asset Popup:</b> Edit all asset fields including auto-regenerating Asset ID on sub category change. Invoice section with View/Update/Upload buttons matching manage table style.</li>
				<li>✅ <b>Finance — Delete Asset:</b> Delete button in actions column, visible only for Master Admins with confirmation dialog.</li>
				<li>✅ <b>Finance — Manage Categories:</b> CRUD for main categories and sub categories with group codes, depreciation rates, useful life years. Search bars and sticky headers.</li>
				<li>✅ <b>Finance — Download Template:</b> Excel template with sample data and styled headers for bulk import.</li>
				<li>✅ <b>Finance — Import Assets:</b> File chooser with preview table, bulk import from Excel files.</li>
				<li>✅ <b>Finance — Inline Invoice Management:</b> View, Update, and Upload invoice buttons directly in the table. File upload to Supabase storage.</li>
				<li>✅ <b>UI/UX:</b> Locale-aware display (Arabic-only or English-only based on language), dd-mm-yyyy date format, column and row borders, currency symbol from static icons, sticky headers, search filtering across all tables.</li>
				<li>✅ <b>Database:</b> 4 migration files for asset_main_categories (18 seeded), asset_sub_categories (68+ seeded with depreciation), assets table, and asset-invoices storage bucket.</li>
			</ul>
		</div>
		</div>

		<div class="latest-change" style="margin-top: 20px; opacity: 0.9;">
		<h3>✨ Automated Attendance Analysis, Mobile Dashboard & Edge Functions</h3>
		<p class="change-description">Server-side attendance analysis with Edge Functions, mobile dashboard attendance cards, smart "Not yet" status logic, and pg_cron automated scheduling.</p>
		<div class="change-details">
			<h4>February 12, 2026 (Latest):</h4>
			<ul>
				<li>✅ <b>HR Module — Analyze Attendance Edge Function:</b> New <code>analyze-attendance</code> server-side Edge Function replaces client-side analysis. Runs via pg_cron 6x/day (6AM, 8:30AM, 1PM, 6PM, 8:30PM, 12:30AM Saudi time). Results stored in <code>hr_analysed_attendance_data</code> table.</li>
				<li>✅ <b>HR Module — Process Fingerprints Edge Function:</b> New <code>process-fingerprints</code> Edge Function copies raw device punches to processed transactions. Runs hourly via pg_cron.</li>
				<li>✅ <b>HR Module — AnalyzeAllWindow Refactored:</b> Now reads pre-computed data from <code>hr_analysed_attendance_data</code> instead of running analysis client-side. Added "Refresh Data" button to manually trigger Edge Function, and "Last Updated" timestamp badge.</li>
				<li>✅ <b>HR Module — Process Fingerprint Button:</b> Replaced client-side auto-processing with server-side Edge Function trigger. Added ⚡ Process Fingerprints button and auto-trigger on window open.</li>
				<li>✅ <b>HR Module — Auto Re-analyze on Punch Save:</b> EmployeeAnalysisWindow now triggers Edge Function after saving a manual punch, keeping analysis data up-to-date.</li>
				<li>✅ <b>Mobile Dashboard — Attendance Cards:</b> Replaced raw punch display with Today/Yesterday attendance cards showing status, check-in/out times, and late minutes from analyzed data.</li>
				<li>✅ <b>Mobile Dashboard — Smart "Not Yet" Status:</b> When today's status is Absent/Missing but shift hasn't ended, shows "Not yet" instead. Looks up shift tables directly (special_shift_date_wise → special_shift_weekday → regular_shift) with overlapping shift support.</li>
				<li>✅ <b>Mobile Dashboard — Locale-Aware Formatting:</b> 12-hour time format, Arabic/English day names, DD-MM-YYYY dates, and translated status labels (حاضر, غائب, etc.).</li>
				<li>✅ <b>AI Chat:</b> Voice narration prompt on open instead of auto-play. TTS voice selection and Google TTS integration.</li>
				<li>✅ <b>Desktop:</b> Dancing character lazy-loaded, removed What's New info card from welcome screen.</li>
				<li>✅ <b>Edge Function Deployment Guide:</b> New comprehensive guide with Kong wildcard routing, pg_cron schedule reference, and troubleshooting.</li>
			</ul>
		</div>
		<div class="change-details" style="margin-top: 15px; border-top: 1px dashed #e2e8f0; pt-4">
			<h4>February 11, 2026:</h4>
			<ul>
				<li>✅ <b>Dancing Character:</b> Lottie animation with bilingual greetings on desktop welcome screen.</li>
				<li>✅ <b>Theme System:</b> Desktop interface theme management with CSS variables for subsection buttons and backgrounds, persists on reload.</li>
				<li>✅ <b>Sidebar:</b> Language switch and compact online indicator added.</li>
				<li>✅ <b>Taskbar:</b> My Daily Checklist button with pending count badge.</li>
				<li>✅ <b>Shelf Paper:</b> Template Designer button in Media → Manage, with loading indicators, copy template, font manager, and app notifications.</li>
				<li>✅ <b>Products Dashboard:</b> Modernized UI with search/filter features.</li>
				<li>✅ <b>Incident Manager:</b> Eye icon for report counts, improved incident management and reporting.</li>
				<li>✅ <b>Mobile Checklist:</b> Pending checklists counter, submission tracking, enhanced checklist UI with larger checkboxes.</li>
				<li>✅ <b>Daily Checklist Fix:</b> Auto-save using persistent auth store, hidden user ID column, fixed infinite loop in frequency/day selects.</li>
				<li>✅ <b>Approval Permissions:</b> Removed browser alerts, optimized refresh to only update changed rows.</li>
				<li>✅ <b>Export Excel:</b> Styled Excel export added to AnalyzeAllWindow with i18n keys.</li>
			</ul>
		</div>
		<div class="change-details" style="margin-top: 15px; border-top: 1px dashed #e2e8f0; pt-4">
			<h4>February 10, 2026:</h4>
			<ul>
				<li>✅ <b>Favorites:</b> Drag-and-drop reordering for favorite buttons with auto-save.</li>
				<li>✅ <b>Punch Display:</b> Shows last 2 punches across all branches using <code>hr_employee_master</code> with multi-employee real-time subscription.</li>
				<li>✅ <b>HR Checklist:</b> Checklist operations with View Answers and Report Problem button.</li>
				<li>✅ <b>Flyer Generator:</b> Offer name creation, flyer generator improvements.</li>
				<li>✅ <b>Bug Fixes:</b> Uppercase AI-generated English group names, product creation ID generation, variation group queries, SalesReport realtime subscription fix.</li>
			</ul>
		</div>
		<div class="change-details" style="margin-top: 15px; border-top: 1px dashed #e2e8f0; pt-4">
			<h4>February 9, 2026:</h4>
			<ul>
				<li>✅ <b>One Day Offer Manager:</b> Import, pricing, print, and barcode export for one-day marketing offers.</li>
				<li>✅ <b>Shelf Paper:</b> Parallel load, template loading indicator, select-all size buttons, offer_qty image grid.</li>
				<li>✅ <b>Sidebar Favorites:</b> Desktop sidebar favorites system, normal paper manager.</li>
				<li>✅ <b>Offer Editor Fix:</b> Preserve pricing data with upsert instead of delete+reinsert.</li>
			</ul>
		</div>
		<p class="date">Current Version (AQ41)</p>
	</div>

	<div class="previous-change">
		<h3>✨ Daily Checklist Mobile Interface - Submission Tracking & Enhanced UI</h3>
		<p class="change-description">New mobile interface for daily checklist submissions with pending counter, completion tracking, and improved form usability with larger checkboxes.</p>
		<div class="change-details">
			<h4>February 11, 2026:</h4>
			<ul>
				<li>✅ <b>Mobile Checklist Page:</b> New full-page mobile interface at /mobile-interface/my-checklist for submitting daily and weekly checklists with question forms.</li>
				<li>✅ <b>Pending Checklists Counter:</b> Home dashboard shows count of pending checklists due for submission, with three states: pending count, all submitted with date (dd-mm-yyyy), or no checklists assigned.</li>
				<li>✅ <b>Submission Type Tracking:</b> Database schema extended with submission_type_en/ar columns to track Daily (يومي), Weekly (أسبوعي), or POS (نقاط البيع) submissions.</li>
				<li>✅ <b>Form Validation:</b> Submit button disabled until all checklist questions are answered, preventing incomplete submissions.</li>
				<li>✅ <b>Checkbox Styling:</b> Increased checkbox size from 1rem to 1.25rem with orange (#f97316) border for better visibility and usability on mobile.</li>
				<li>✅ <b>Completion Display:</b> When all checklists submitted, shows green checkmark with today's date and 'All Checklists Submitted' message.</li>
				<li>✅ <b>No Assignment State:</b> Shows 'No Checklists Assigned' when user has no checklist assignments (with dash icon).</li>
				<li>✅ <b>Global Top Bar Integration:</b> Added my-checklist route to getPageTitle function in layout for consistent page title display in mobile header.</li>
				<li>✅ <b>Saudi Timezone Support:</b> Checklist filtering respects Saudi Arabia (Asia/Riyadh) timezone for daily eligibility checks.</li>
				<li>✅ <b>HR Reporting:</b> DailyChecklistManager admin tool now displays submission type in reports (Daily/Weekly/POS with Arabic equivalents).</li>
			</ul>
		</div>
		<div class="change-details" style="margin-top: 15px; border-top: 1px dashed #e2e8f0; pt-4">
			<h4>February 3–8, 2026:</h4>
			<ul>
				<li>✅ <b>Flyer System:</b> Page numbers, rotation support, custom fonts per field, variant icon field type, expiry date labels, improved image handling and PNG export.</li>
				<li>✅ <b>Variant Groups:</b> Create variant groups from Offer Product Selector with AI naming, proper page/order tracking, and automatic grid image layout.</li>
				<li>✅ <b>Finance:</b> View All Paid windows with filters and Excel export for vendor/expense payments with sticky headers.</li>
				<li>✅ <b>Branding:</b> Updated app logo to new Aqura logo across all interfaces.</li>
				<li>✅ <b>Bug Fixes:</b> Vendor payment approval routing fix, Arabic filename sanitization for uploads, ERP Entry Manager column cleanup, price field strikethrough positioning.</li>
			</ul>
		</div>
		<p class="date">February 11, 2026 (AQ40)</p>
	</div>

	<div class="previous-change">
		<h3>✨ Flyer Offer Templates - Product Variations & Barcode Support</h3>
		<p class="change-description">Enhanced flyer offer templates with comprehensive product variation management, barcode display options, and improved product selection interface.</p>
		<div class="change-details">
			<h4>February 3, 2026:</h4>
			<ul>
				<li>✅ <b>Product Variations:</b> Complete variation management system with size, color, and specification tracking for offer products.</li>
				<li>✅ <b>Barcode Display:</b> Added configurable barcode display in offer templates with uppercase formatting and proper font styling.</li>
				<li>✅ <b>Offer Product Selector:</b> Enhanced product selection interface with variation support, search functionality, and multi-select capabilities.</li>
				<li>✅ <b>Template Rendering:</b> Improved offer template rendering to handle product variations and display barcodes when configured.</li>
				<li>✅ <b>Product Master:</b> Enhanced Product Master component to manage product variations with proper CRUD operations and validation.</li>
				<li>✅ <b>Variation Manager:</b> Implemented dedicated variation management interface with dynamic form fields and bulk operations.</li>
				<li>✅ <b>UI/UX:</b> Improved visual hierarchy and spacing in offer templates for better readability across all product display modes.</li>
			</ul>
		</div>
		<p class="date">February 3, 2026 (AQ38)</p>
	</div>

	<div class="previous-change">
		<h3>✨ User Management Enhancement - HR Master Employee Integration</h3>
		<p class="change-description">Enhanced User Management to display employee data from hr_employee_master table with bilingual name support and accurate employee IDs.</p>
		<div class="change-details">
			<h4>January 21, 2026:</h4>
			<ul>
				<li>✅ <b>Data Source Migration:</b> User Management now fetches employee names from hr_employee_master table (mapped by user_id) with automatic fallback to hr_employees for backward compatibility.</li>
				<li>✅ <b>Bilingual Display:</b> Employee names now display both English (name_en) and Arabic (name_ar) with proper RTL formatting for Arabic text.</li>
				<li>✅ <b>Employee ID Accuracy:</b> Employee ID column now shows the hr_employee_master.id (primary key) instead of the legacy employee_code, with fallback support.</li>
				<li>✅ <b>Search Enhancement:</b> Search functionality updated to filter by both English and Arabic employee names simultaneously.</li>
				<li>✅ <b>UI Polish:</b> Added distinct styling for bilingual names with English in bold (primary) and Arabic in lighter color with RTL direction.</li>
			</ul>
		</div>
		<p class="date">January 21, 2026 (AQ37)</p>
	</div>

	<div class="previous-change">
		<h3>✨ HR Status Sync & Punch Pair Classification Fix</h3>
		<p class="change-description">Fixed critical punch classification logic to properly sync status based on pairing context, ensuring "Other" punches are reclassified to "Check Out" when paired with Check Ins.</p>
		<div class="change-details">
			<h4>January 19, 2026:</h4>
			<ul>
				<li>✅ <b>HR Module:</b> Fixed updateTransactionStatuses() to load ALL transactions for pairing context, not just null-status ones.</li>
				<li>✅ <b>Punch Classification:</b> Implemented 3-step status sync: classify → group → reclassify based on pairing logic.</li>
				<li>✅ <b>Bug Fix:</b> Punches classified as "Other" (outside buffer window) now correctly reclassified to "Check Out" when paired with Check Ins.</li>
				<li>✅ <b>Data Persistence:</b> Status synced to database only after confirming valid pairing context, eliminating false "Other" classifications.</li>
				<li>✅ <b>Debugging:</b> Added comprehensive console logging for troubleshooting punch classification mismatches between display and database.</li>
			</ul>
		</div>

		<div class="change-details" style="margin-top: 15px; border-top: 1px dashed #e2e8f0; pt-4">
			<h4>January 18-19, 2026:</h4>
			<ul>
				<li>✅ <b>Add Missing Punch:</b> Complete modal implementation with deduction % field and shift auto-fill.</li>
				<li>✅ <b>Permissions:</b> Added can_add_missing_punches permission to approval_permissions table with admin controls.</li>
				<li>✅ <b>Deep-linking:</b> AnalyzeAllWindow → EmployeeAnalysisWindow now auto-loads date range (25th prev month to yesterday).</li>
				<li>✅ <b>Sort & Display:</b> Punch pairs now sorted newest-first (latest date first) for better UX.</li>
				<li>✅ <b>Modal UI:</b> Replaced browser alerts with professional in-app modals (success/error/info) with proper z-indexing.</li>
			</ul>
		</div>

		<div class="change-details" style="margin-top: 15px; border-top: 1px dashed #e2e8f0; pt-4">
			<h4>January 17, 2026:</h4>
			<ul>
				<li>✅ <b>Bulk Employee Analysis:</b> Implemented "Analyze All" feature with matching logic to EmployeeAnalysisWindow.</li>
				<li>✅ <b>Mobile Parity:</b> Updated mobile fingerprint analysis to match desktop punch classification logic exactly.</li>
				<li>✅ <b>Status Persistence:</b> Changed ProcessFingerprint import to save status as NULL, calculate dynamically on frontend.</li>
			</ul>
		</div>
		<p class="date">January 19, 2026 (AQ36)</p>
	</div>

	<div class="previous-change">
		<h3>✨ HR Module Enhancements + i18n Cleanup</h3>
		<p class="change-description">Implemented full bilingual support for HR Shift management and standardized i18n implementation</p>
		<div class="change-details">
			<h4>January 16, 2026:</h4>
			<ul>
				<li>✅ <b>HR Discipline:</b> Added "Discipline Warnings" management with Incident Reporting and Warning Issuance.</li>
				<li>✅ <b>Finance:</b> Added Food Allowance to salary management and POS Deduction Transfer system with status tracking.</li>
				<li>✅ <b>Bilingual:</b> Standardized $t store usage across all 300+ translation keys for HR modules.</li>
			</ul>
		</div>
		<p class="date">January 16, 2026</p>
	</div>

		<div class="interface-info">
			<div class="interface-card">
				<h4>🖥️ Desktop Interface</h4>
				<p>Admin and manager features for full business management</p>
			</div>

			<div class="interface-card">
				<h4>📱 Mobile Interface</h4>
				<p>Employee app for tasks and time tracking</p>
			</div>

			<div class="interface-card">
				<h4>🏪 Cashier Interface</h4>
				<p>Internal checkout operations manager</p>
			</div>

			<div class="interface-card">
				<h4>🛒 Customer Interface</h4>
				<p>Shopping app for customers</p>
			</div>
		</div>
	</div>
</div>

<style>
	.version-changelog-window {
		width: 100%;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #ffffff;
		font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
	}

	.window-content {
		flex: 1;
		overflow-y: auto;
		padding: 24px;
		background: #f8fafc;
	}

	.version-format {
		background: white;
		padding: 20px;
		border-radius: 6px;
		border: 3px solid #f97316;
		margin-bottom: 20px;
	}

	.version-title {
		margin: 0 0 12px 0;
		color: #22c55e;
		font-size: 24px;
		font-weight: 700;
	}

	.version-details {
		margin: 0 0 8px 0;
		color: #22c55e;
		font-size: 16px;
		font-weight: 600;
	}

	.version-note {
		margin: 0;
		color: #22c55e;
		font-size: 13px;
		font-weight: 500;
	}

	.latest-change {
		background: white;
		padding: 20px;
		border-radius: 6px;
		border: 1px solid #e2e8f0;
		margin-bottom: 20px;
	}

	.latest-change h3 {
		margin: 0 0 12px 0;
		font-size: 18px;
		color: #1e293b;
		font-weight: 600;
	}

	.change-description {
		margin: 0 0 16px 0;
		color: #475569;
		font-size: 15px;
		line-height: 1.6;
		font-weight: 500;
	}

	.change-details {
		background: #f8fafc;
		padding: 16px;
		border-radius: 4px;
		margin-bottom: 16px;
		border-left: 3px solid #3b82f6;
	}

	.change-details h4 {
		margin: 0 0 8px 0;
		font-size: 14px;
		color: #1e293b;
		font-weight: 600;
	}

	.change-details ul {
		margin: 0;
		padding-left: 20px;
		color: #475569;
	}

	.change-details li {
		margin: 4px 0;
		font-size: 13px;
		line-height: 1.5;
	}

	.previous-change {
		background: white;
		padding: 20px;
		border-radius: 6px;
		border: 1px solid #e2e8f0;
		margin-bottom: 20px;
	}

	.previous-change h3 {
		margin: 0 0 12px 0;
		font-size: 18px;
		color: #1e293b;
		font-weight: 600;
	}

	.previous-change .change-description {
		margin: 0 0 16px 0;
		color: #475569;
		font-size: 15px;
		line-height: 1.6;
		font-weight: 500;
	}

	.previous-change .change-details {
		background: #f8fafc;
		padding: 16px;
		border-radius: 4px;
		margin-bottom: 16px;
		border-left: 3px solid #3b82f6;
	}

	.previous-change .change-details h4 {
		margin: 0 0 8px 0;
		font-size: 14px;
		color: #1e293b;
		font-weight: 600;
	}

	.previous-change .change-details ul {
		margin: 0;
		padding-left: 20px;
		color: #475569;
	}

	.previous-change .change-details li {
		margin: 4px 0;
		font-size: 13px;
		line-height: 1.5;
	}

	.previous-change .date {
		margin: 0;
		font-size: 13px;
		color: #94a3b8;
	}

	.interface-info {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 12px;
	}

	.interface-card {
		background: white;
		padding: 16px;
		border-radius: 6px;
		border: 1px solid #e2e8f0;
		transition: all 0.2s;
	}

	.interface-card:hover {
		border-color: #cbd5e1;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
	}

	.interface-card h4 {
		margin: 0 0 8px 0;
		font-size: 15px;
		color: #1e293b;
		font-weight: 600;
	}

	.interface-card p {
		margin: 0;
		font-size: 13px;
		color: #64748b;
		line-height: 1.5;
	}
</style>
