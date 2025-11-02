<script>
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	export let taskId;
	export let receivingRecordId;
	export let onComplete = () => {};

	let loading = false;
	let error = null;
	let success = false;

	async function completeTask() {
		if (!taskId) {
			error = 'Task ID is required';
			return;
		}

		loading = true;
		error = null;

		try {
			const response = await fetch('/api/receiving-tasks/complete', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					receiving_task_id: taskId,
					user_id: $currentUser?.id
				})
			});

			const result = await response.json();

			if (!response.ok || result.error_code) {
				throw new Error(result.error || 'Failed to complete receiving task');
			}

			success = true;
			
			// Wait a moment to show success message
			setTimeout(() => {
				onComplete();
			}, 1000);

		} catch (err) {
			console.error('Error completing receiving task:', err);
			error = err.message || 'Failed to complete task. Please try again.';
		} finally {
			loading = false;
		}
	}
</script>

<div class="completion-dialog">
	{#if success}
		<div class="success-message">
			<div class="success-icon">✅</div>
			<h3>Task Completed Successfully!</h3>
			<p>The receiving task has been marked as completed.</p>
		</div>
	{:else}
		<div class="dialog-content">
			<h2>Complete Receiving Task</h2>
			<p class="confirmation-text">
				Are you sure you want to mark this task as completed? This action confirms that you have finished all required activities for this receiving record.
			</p>

			{#if error}
				<div class="error-message">
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
					</svg>
					{error}
				</div>
			{/if}

			<div class="actions">
				<button 
					class="btn btn-cancel" 
					on:click={onComplete}
					disabled={loading}
				>
					Cancel
				</button>
				<button 
					class="btn btn-complete" 
					on:click={completeTask}
					disabled={loading}
				>
					{#if loading}
						<span class="spinner"></span>
						Completing...
					{:else}
						✅ Complete Task
					{/if}
				</button>
			</div>
		</div>
	{/if}
</div>

<style>
	.completion-dialog {
		padding: 24px;
		min-height: 200px;
	}

	.dialog-content {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	h2 {
		margin: 0;
		font-size: 24px;
		font-weight: 600;
		color: #1f2937;
	}

	.confirmation-text {
		color: #6b7280;
		line-height: 1.6;
		margin: 0;
	}

	.error-message {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px;
		background: #fee2e2;
		border: 1px solid #fca5a5;
		border-radius: 6px;
		color: #991b1b;
		font-size: 14px;
	}

	.error-message svg {
		width: 20px;
		height: 20px;
		flex-shrink: 0;
	}

	.success-message {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		padding: 40px 20px;
		gap: 16px;
	}

	.success-icon {
		font-size: 64px;
		animation: scaleIn 0.3s ease-out;
	}

	@keyframes scaleIn {
		from {
			transform: scale(0);
		}
		to {
			transform: scale(1);
		}
	}

	.success-message h3 {
		margin: 0;
		font-size: 20px;
		font-weight: 600;
		color: #065f46;
	}

	.success-message p {
		margin: 0;
		color: #6b7280;
	}

	.actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		margin-top: 8px;
	}

	.btn {
		padding: 10px 20px;
		border-radius: 6px;
		font-size: 14px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		border: none;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.btn-cancel {
		background: #f3f4f6;
		color: #374151;
	}

	.btn-cancel:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.btn-complete {
		background: #10b981;
		color: white;
	}

	.btn-complete:hover:not(:disabled) {
		background: #059669;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top: 2px solid white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
