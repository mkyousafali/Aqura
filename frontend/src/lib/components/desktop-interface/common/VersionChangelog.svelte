<script lang="ts">
	export let onClose: () => void;
</script>

<div class="version-changelog-window">
	<div class="window-content">
		<div class="version-format">
		<p class="version-title">Version AQ46.20.12.13</p>
		<p class="version-details">Desktop: 46 | Mobile: 20 | Cashier: 12 | Customer: 13</p>
		</div>

		<div class="latest-change">
		<h3>✨ Comprehensive Arabic Translation for Mobile Interface</h3>
		<p class="change-description">Full Arabic (RTL) translation across 20+ mobile pages including approval center, notifications, assignments, tasks, POS closed boxes, receiving tasks, and more. Bilingual helpers, relative time display, status badge translations, and employee name localization.</p>
		<div class="change-details">
			<h4>February 15, 2026 (Latest):</h4>
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
