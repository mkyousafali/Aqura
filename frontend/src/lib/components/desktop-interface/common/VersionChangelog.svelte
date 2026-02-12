<script lang="ts">
	export let onClose: () => void;
</script>

<div class="version-changelog-window">
	<div class="window-content">
		<div class="version-format">
		<p class="version-title">Version AQ41.15.9.9</p>
		<p class="version-details">Desktop: 41 | Mobile: 15 | Cashier: 9 | Customer: 9</p>
		</div>

		<div class="latest-change">
		<h3>✨ AI Chat, Receiving Defaults, Theme System & Major Desktop Improvements</h3>
		<p class="change-description">AI-powered chat assistant, branch default positions for receiving, desktop theme management, and many UI/UX improvements across all interfaces.</p>
		<div class="change-details">
			<h4>February 12, 2026 (Latest):</h4>
			<ul>
				<li>✅ <b>AI Chat System:</b> New Aqura bot with TTS voice selection, sales report integration, voice input support, and mobile-optimized interface with icon-only bottom nav.</li>
				<li>✅ <b>Sales Report:</b> Enhanced with comparisons, voice input, and full date display.</li>
				<li>✅ <b>Branch Default Positions:</b> New <code>branch_default_positions</code> table to store 6 default roles per branch (Branch Manager, Purchasing Manager, Inventory Manager, Accountant, Night Supervisors, Warehouse Handler).</li>
				<li>✅ <b>Default Positions Window:</b> New management window in Vendor → Manage → Default Positions for assigning default personnel per branch with search and employee selection.</li>
				<li>✅ <b>Auto-Load Positions:</b> StartReceiving now auto-loads 6 positions from branch defaults when a branch is confirmed, leaving only Shelf Stocker as manual selection.</li>
				<li>✅ <b>Default Branch for Receiving:</b> New <code>receiving_user_defaults</code> table stores the user's preferred branch. "Set as default" checkbox auto-selects the branch on next visit.</li>
				<li>✅ <b>Active Users Filter:</b> Default Positions window filters out inactive users by checking the <code>users.status</code> field, only showing active employees.</li>
				<li>✅ <b>Clearance Certificate Names:</b> Generated tasks now show employee names (ID + Name) next to role badges using a reactive employee name map.</li>
				<li>✅ <b>Clearance Certificate UI:</b> Removed hard blue gradient header, replaced with clean white header. Bill Amount uses SAR currency icon instead of dollar sign.</li>
				<li>✅ <b>Shelf Stocker Search:</b> Rewritten to use <code>hr_employee_master</code> with <code>hr_positions</code> join. Search box stays visible when no results found.</li>
				<li>✅ <b>Employee Data Source:</b> All receiving components now use <code>hr_employee_master</code> table instead of legacy <code>users</code> table for employee names and IDs.</li>
				<li>✅ <b>UI Cleanup:</b> Removed redundant step headings (Step 1-4) since step indicator already shows progress. Removed "Receiving User" info card.</li>
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
