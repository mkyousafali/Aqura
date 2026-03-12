<script lang="ts">
	import { _ as t } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { get } from 'svelte/store';
	import { onMount } from 'svelte';

	let supabase: any = null;
	let deploying = false;
	let deploymentLog: string[] = [];
	let deploymentStatus = 'idle'; // idle | running | success | error
	let errorMessage = '';

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
	});

	async function startBackup() {
		deploying = true;
		deploymentStatus = 'running';
		deploymentLog = [];
		errorMessage = '';

		try {
			// Get current user from store
			const user = get(currentUser);

			if (!user) {
				throw new Error('User not authenticated');
			}

			const response = await fetch('/api/deployment', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ user })
			});

			const data = await response.json();

			if (!response.ok) {
				throw new Error(data.error || 'Deployment failed');
			}

			// Connect to SSE for real-time updates
			const sessionId = data.sessionId;
			const eventSource = new EventSource(`/api/deployment?sessionId=${sessionId}`);
			
			eventSource.onmessage = (event) => {
				const message = event.data.trim();
				
				if (message) {
					deploymentLog = [...deploymentLog, message];
					
					// Auto-scroll log to bottom (in component's reactive statement)
					setTimeout(() => {
						const logContent = document.querySelector('.log-content');
						if (logContent) {
							logContent.scrollTop = logContent.scrollHeight;
						}
					}, 0);
					
					if (message.includes('[COMPLETE]')) {
						eventSource.close();
						deploymentStatus = 'success';
						deploying = false;
					}
				}
			};

			eventSource.onerror = () => {
				eventSource.close();
				deploymentStatus = 'error';
				errorMessage = 'Connection lost during deployment';
				deploying = false;
			};
		} catch (error) {
			console.error('Deployment error:', error);
			errorMessage = error instanceof Error ? error.message : 'Unknown error';
			deploymentStatus = 'error';
			deploying = false;
		}
	}

	function clearLog() {
		deploymentLog = [];
		deploymentStatus = 'idle';
		errorMessage = '';
	}
</script>

<div class="local-update-container">
	<!-- Header -->
	<div class="update-header">
		<h2>🚀 Local Branch Update</h2>
		<p class="subtitle">Deploy latest code and database to local branch server (192.168.0.101:3001)</p>
	</div>

	<!-- Info Panel -->
	<div class="info-panel">
		<div class="info-section">
			<h3>What this does:</h3>
			<ul class="steps-list">
				<li>✓ Creates database dump on cloud server</li>
				<li>✓ Downloads to PC and uploads to branch</li>
				<li>✓ Restores database on branch</li>
				<li>✓ Resets database sequences</li>
				<li>✓ Verifies HTTP 200 response</li>
			</ul>
		</div>
		<div class="info-section warning">
			<h3>⚠️ Important:</h3>
			<p>This syncs the database only (no code rebuild). Database will be briefly reset.</p>
			<p><strong>Estimated time:</strong> 2-3 minutes</p>
		</div>
	</div>

	<!-- Deployment Status -->
	{#if deploymentStatus !== 'idle'}
		<div class="status-panel" class:success={deploymentStatus === 'success'} class:error={deploymentStatus === 'error'} class:running={deploymentStatus === 'running'}>
			<div class="status-header">
				{#if deploymentStatus === 'running'}
					<span class="spinner"></span>
					<span>Deployment in progress...</span>
				{:else if deploymentStatus === 'success'}
					<span class="checkmark">✓</span>
					<span>Deployment successful!</span>
				{:else if deploymentStatus === 'error'}
					<span class="error-icon">✕</span>
					<span>Deployment failed</span>
				{/if}
			</div>

			<!-- Error Message -->
			{#if errorMessage}
				<div class="error-message">
					<strong>Error:</strong> {errorMessage}
				</div>
			{/if}

			<!-- Deployment Log -->
			{#if deploymentLog.length > 0}
				<div class="deployment-log">
					<div class="log-header">
						<strong>Deployment Log:</strong>
						<button class="clear-btn" on:click={clearLog} disabled={deploying}>Clear</button>
					</div>
					<div class="log-content">
						{#each deploymentLog as line, idx (idx)}
							<div class="log-line">{line}</div>
						{/each}
					</div>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Action Button -->
	<div class="button-container">
		<button 
			class="start-backup-btn"
			on:click={startBackup}
			disabled={deploying}
		>
			{#if deploying}
				<span class="spinner-small"></span>
				Deployment in progress...
			{:else}
				🚀 Start Backup & Deploy
			{/if}
		</button>
	</div>
</div>

<style>
	.local-update-container {
		padding: 2rem;
		max-width: 900px;
		margin: 0 auto;
		color: #e2e8f0;
	}

	.update-header {
		margin-bottom: 2rem;
		text-align: center;
		border-bottom: 2px solid #334155;
		padding-bottom: 1rem;
	}

	.update-header h2 {
		font-size: 1.75rem;
		margin: 0 0 0.5rem 0;
		color: #f1f5f9;
	}

	.subtitle {
		font-size: 0.95rem;
		color: #cbd5e1;
		margin: 0;
	}

	.info-panel {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1.5rem;
		margin-bottom: 2rem;
	}

	.info-section {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 8px;
		padding: 1.5rem;
	}

	.info-section h3 {
		margin: 0 0 1rem 0;
		font-size: 1rem;
		color: #f1f5f9;
	}

	.info-section.warning {
		background: rgba(234, 179, 8, 0.08);
		border-color: #ea971655;
	}

	.info-section.warning h3 {
		color: #fbbf24;
	}

	.info-section p {
		margin: 0.5rem 0;
		font-size: 0.9rem;
		line-height: 1.6;
	}

	.steps-list {
		list-style: none;
		padding: 0;
		margin: 0;
	}

	.steps-list li {
		padding: 0.5rem 0;
		font-size: 0.9rem;
		color: #cbd5e1;
	}

	.status-panel {
		background: #1e293b;
		border: 2px solid #334155;
		border-radius: 8px;
		padding: 1.5rem;
		margin-bottom: 2rem;
	}

	.status-panel.success {
		border-color: #10b981;
		background: rgba(16, 185, 129, 0.08);
	}

	.status-panel.error {
		border-color: #ef4444;
		background: rgba(239, 68, 68, 0.08);
	}

	.status-panel.running {
		border-color: #3b82f6;
	}

	.status-header {
		display: flex;
		align-items: center;
		gap: 1rem;
		font-size: 1.1rem;
		margin-bottom: 1rem;
		font-weight: 600;
	}

	.spinner {
		display: inline-block;
		width: 20px;
		height: 20px;
		border: 3px solid #334155;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	.spinner-small {
		display: inline-block;
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-right: 0.5rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.checkmark {
		color: #10b981;
		font-size: 1.5rem;
	}

	.error-icon {
		color: #ef4444;
		font-size: 1.5rem;
	}

	.error-message {
		background: rgba(239, 68, 68, 0.1);
		border: 1px solid #ef4444;
		border-radius: 4px;
		padding: 1rem;
		margin-bottom: 1rem;
		color: #fca5a5;
		font-size: 0.9rem;
	}

	.deployment-log {
		background: #0f172a;
		border: 1px solid #334155;
		border-radius: 6px;
		overflow: hidden;
	}

	.log-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: #1e293b;
		padding: 0.75rem 1rem;
		border-bottom: 1px solid #334155;
	}

	.clear-btn {
		background: #334155;
		border: none;
		color: #e2e8f0;
		padding: 0.4rem 0.8rem;
		border-radius: 4px;
		cursor: pointer;
		font-size: 0.85rem;
		transition: background 0.2s;
	}

	.clear-btn:hover:not(:disabled) {
		background: #475569;
	}

	.clear-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.log-content {
		max-height: 300px;
		overflow-y: auto;
		padding: 1rem;
		font-family: 'Courier New', monospace;
		font-size: 0.85rem;
		line-height: 1.5;
	}

	.log-line {
		padding: 0.3rem 0;
		color: #cbd5e1;
		word-break: break-all;
	}

	.button-container {
		display: flex;
		justify-content: center;
		gap: 1rem;
	}

	.start-backup-btn {
		background: linear-gradient(135deg, #3b82f6, #2563eb);
		border: none;
		color: white;
		padding: 1rem 2rem;
		border-radius: 8px;
		font-size: 1.1rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.3s;
		display: flex;
		align-items: center;
		gap: 0.5rem;
		min-width: 250px;
		justify-content: center;
	}

	.start-backup-btn:hover:not(:disabled) {
		background: linear-gradient(135deg, #2563eb, #1d4ed8);
		transform: translateY(-2px);
		box-shadow: 0 8px 16px rgba(59, 130, 246, 0.4);
	}

	.start-backup-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}

	@media (max-width: 768px) {
		.info-panel {
			grid-template-columns: 1fr;
		}

		.local-update-container {
			padding: 1rem;
		}
	}
</style>
