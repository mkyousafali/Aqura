<script lang="ts">
	export let onClose: () => void;
</script>

<div class="version-changelog-window">
	<div class="window-content">
		<div class="version-format">
			<p class="version-title">Version AQ34.13.8.8</p>
			<p class="version-details">Desktop: 34 | Mobile: 13 | Cashier: 8 | Customer: 8</p>
			<p class="version-note">Format: AQ[Desktop].[Mobile].[Cashier].[Customer]</p>
		</div>

		<div class="latest-change">
			<h3>✨ Bulk Employee Analysis + HR Module Redesign</h3>
			<p class="change-description">Implemented massive bulk fingerprint analysis engine, redesigned mobile HR experience, and enhanced cashier localization.</p>
			<div class="change-details">
				<h4>January 19, 2026:</h4>
				<ul>
					<li>✅ <b>Desktop HR:</b> Implemented "Analyze All" bulk report engine with logic parity (midpoint detection, overnight shift support).</li>
					<li>✅ <b>UI/UX:</b> Added sticky columns for RTL/LTR layouts ensuring ID/Name visibility during horizontal scrolling.</li>
					<li>✅ <b>Cashier:</b> Localized branch selection dropdown to show "Name - Location" in both Arabic and English.</li>
					<li>✅ <b>Mobile:</b> Fully redesigned Fingerprint Analysis with a modern futuristic theme (Orange/Green/Purple).</li>
					<li>✅ <b>Mobile:</b> Integrated visual indicators for "Day Off", "Leave", and "Missing Punch" in employee analysis.</li>
				</ul>
			</div>
			
			<div class="change-details" style="margin-top: 15px; border-top: 1px dashed #e2e8f0; pt-4">
				<h4>January 18, 2026:</h4>
				<ul>
					<li>✅ <b>Mobile HR:</b> Added "Leave Request" module to bottom navigation with photo upload capability.</li>
					<li>✅ <b>HR Operations:</b> Implemented real-time synchronization between Analysis, Shift, and Salary modules.</li>
					<li>✅ <b>Employee Master:</b> Added description field to Day Off requests and improved Approval Center display logic.</li>
					<li>✅ <b>UI Fixes:</b> Standardized 12-hour time format across all HR configuration windows and fixed RTL arrow directions.</li>
				</ul>
			</div>

			<div class="change-details" style="margin-top: 15px; border-top: 1px dashed #e2e8f0; pt-4">
				<h4>January 17, 2026:</h4>
				<ul>
					<li>✅ <b>HR Engine:</b> Implemented date-aware shift validation with dynamic buffers for overnight fingerprint pairing.</li>
					<li>✅ <b>Employee Links:</b> Enhanced LinkID module to highlight missing master records and branch synchronization.</li>
					<li>✅ <b>Data Schema:</b> Updated employment statuses (Remote, No Finger, With Finger) and added Nationality management.</li>
				</ul>
			</div>
			<p class="date">Current Version</p>
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
