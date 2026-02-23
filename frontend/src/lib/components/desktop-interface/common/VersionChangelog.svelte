<script lang="ts">
export let onClose: () => void;
</script>

<div class="version-changelog-window">
<div class="window-content">
<div class="version-format">
<p class="version-title">Version AQ2.2.2.2</p>
<p class="version-details">Desktop: 2 | Mobile: 2 | Cashier: 2 | Customer: 2</p>
</div>

<div class="latest-change">
<h3>🎉 Phase One — Complete</h3>
<p class="change-description">Aqura Phase One development has been successfully completed. The full ERP-integrated business management platform is now live across all four interfaces — Desktop, Mobile, Cashier, and Customer.</p>
<div class="change-details">
<h4>Development Summary:</h4>
<ul>
<li>�‍💻 <b>Developed by:</b> Yousafali — mk.yousafali@gmail.com</li>
<li>�📅 <b>Development Period:</b> July 1, 2025 — February 23, 2026</li>
<li>⏱️ <b>Total Duration:</b> 238 days</li>
<li>🕐 <b>Average Daily Development:</b> 18 hours/day</li>
<li>⚡ <b>Total Development Hours:</b> 4,284 hours</li>
</ul>
</div>
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
