<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { notifications } from '$lib/stores/notifications';
	import { t } from '$lib/i18n';

	let notificationCount = 0;
	let isLoading = true;
	let isClearing = false;

	onMount(async () => {
		await loadCount();
	});

	async function loadCount() {
		isLoading = true;
		try {
			// Get count for notifications table only
			const { count, error } = await supabase
				.from('notifications')
				.select('*', { count: 'exact', head: true });

			if (error) throw error;
			notificationCount = count || 0;
		} catch (error) {
			console.error('Error loading count:', error);
			notifications.add({
				message: 'Failed to load notification count',
				type: 'error',
				duration: 3000
			});
		} finally {
			isLoading = false;
		}
	}

	async function clearNotificationTables() {
		if (!confirm('⚠️ WARNING: This will permanently delete ALL notification data and related records. Are you sure?')) {
			return;
		}

		isClearing = true;
		try {
			// Delete in correct order to handle foreign key constraints
			
			// Step 1: Delete notification_recipients
			await supabase
				.from('notification_recipients')
				.delete()
				.neq('id', '00000000-0000-0000-0000-000000000000');

			// Step 2: Delete notification_read_states
			await supabase
				.from('notification_read_states')
				.delete()
				.neq('id', '00000000-0000-0000-0000-000000000000');

			// Step 3: Delete notification_attachments
			await supabase
				.from('notification_attachments')
				.delete()
				.neq('id', '00000000-0000-0000-0000-000000000000');

			// Step 4: Delete task_reminder_logs
			await supabase
				.from('task_reminder_logs')
				.delete()
				.neq('id', '00000000-0000-0000-0000-000000000000');

			// Step 5: Finally delete all notifications
			const { error: notificationsError } = await supabase
				.from('notifications')
				.delete()
				.neq('id', '00000000-0000-0000-0000-000000000000');
			
			if (notificationsError) throw notificationsError;

			notifications.add({
				message: 'All notification data cleared successfully!',
				type: 'success',
				duration: 3000
			});

			// Reload count
			await loadCount();

		} catch (error) {
			console.error('Error clearing tables:', error);
			notifications.add({
				message: `Failed to clear tables: ${error.message}`,
				type: 'error',
				duration: 5000
			});
		} finally {
			isClearing = false;
		}
	}
</script>

<div class="clear-tables-container">
	{#if isLoading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>Loading...</p>
		</div>
	{:else}
		<!-- Compact Notification Card -->
		<div class="notification-card">
			<div class="card-header">
				<div class="card-title">
					<span class="card-icon">📬</span>
					<h3>Notifications</h3>
				</div>
				<div class="card-actions">
					<button 
						class="btn-icon" 
						on:click={loadCount}
						disabled={isClearing}
						title="Refresh count"
					>
						🔄
					</button>
					<button 
						class="btn-icon btn-danger" 
						on:click={clearNotificationTables}
						disabled={isClearing || notificationCount === 0}
						title="Clear all"
					>
						{#if isClearing}
							<span class="spinner-small"></span>
						{:else}
							🗑️
						{/if}
					</button>
				</div>
			</div>
			<div class="card-body">
				<p class="count">{notificationCount.toLocaleString()}</p>
				<p class="label">total records</p>
			</div>
		</div>

		{#if notificationCount === 0}
			<div class="empty-state">
				✅ All tables are empty
			</div>
		{:else}
			<div class="info-box">
				<strong>⚠️ Will also clear:</strong>
				<ul>
					<li>Recipients</li>
					<li>Read states</li>
					<li>Attachments</li>
					<li>Reminder logs</li>
				</ul>
			</div>
		{/if}
	{/if}
</div>

<style>
	.clear-tables-container {
		padding: 0.75rem;
		height: 100%;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		gap: 0.75rem;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	.spinner-small {
		display: inline-block;
		width: 12px;
		height: 12px;
		border: 2px solid #ffffff40;
		border-top-color: #ffffff;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.notification-card {
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		border-radius: 10px;
		padding: 0.75rem;
		color: white;
		box-shadow: 0 3px 12px rgba(102, 126, 234, 0.3);
		margin-bottom: 0.75rem;
		width: 240px;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
		padding-bottom: 0.4rem;
		border-bottom: 1px solid rgba(255, 255, 255, 0.2);
	}

	.card-title {
		display: flex;
		align-items: center;
		gap: 0.4rem;
	}

	.card-icon {
		font-size: 1rem;
		opacity: 0.9;
	}

	.card-title h3 {
		font-size: 0.75rem;
		font-weight: 600;
		margin: 0;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		opacity: 0.95;
	}

	.card-actions {
		display: flex;
		gap: 0.3rem;
	}

	.btn-icon {
		width: 28px;
		height: 28px;
		border: none;
		border-radius: 5px;
		font-size: 0.9rem;
		cursor: pointer;
		background: rgba(255, 255, 255, 0.2);
		color: white;
		transition: all 0.2s;
		display: flex;
		align-items: center;
		justify-content: center;
		backdrop-filter: blur(10px);
	}

	.btn-icon:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.3);
		transform: scale(1.1);
	}

	.btn-icon.btn-danger:hover:not(:disabled) {
		background: rgba(239, 68, 68, 0.3);
	}

	.btn-icon:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
	}

	.card-body {
		text-align: center;
		padding: 0.4rem 0;
	}

	.count {
		font-size: 2rem;
		font-weight: 700;
		margin: 0;
		line-height: 1;
	}

	.label {
		font-size: 0.7rem;
		opacity: 0.85;
		margin: 0.3rem 0 0 0;
	}

	.empty-state {
		padding: 0.65rem;
		background: linear-gradient(135deg, #10b981 0%, #059669 100%);
		color: white;
		border-radius: 8px;
		font-size: 0.75rem;
		font-weight: 600;
		margin-bottom: 0.5rem;
		width: 240px;
	}

	.info-box {
		background: #fef3c7;
		border: 2px solid #fbbf24;
		border-radius: 8px;
		padding: 0.65rem;
		color: #78350f;
		font-size: 0.7rem;
		width: 240px;
	}

	.info-box strong {
		color: #92400e;
		display: block;
		margin-bottom: 0.35rem;
		font-size: 0.75rem;
	}

	.info-box ul {
		margin: 0.3rem 0 0 0.85rem;
		padding: 0;
	}

	.info-box li {
		margin: 0.1rem 0;
	}
</style>
