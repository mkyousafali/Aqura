<script>
	// Scheduler Component
</script>

<div class="scheduler">
	<div class="header">
		<h1 class="title">📅 Scheduler</h1>
		<p class="subtitle">Schedule and track expense payments</p>
	</div>

	<div class="content">
		<div class="placeholder">
			<div class="placeholder-icon">🚧</div>
			<h2>Coming Soon</h2>
			<p>Scheduling features are under development</p>
		</div>
	</div>
</div>

<style>
	.scheduler {
		padding: 2rem;
		background: #f8fafc;
		height: 100%;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	}

	.header {
		margin-bottom: 2rem;
		text-align: center;
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #64748b;
		font-size: 1rem;
		margin: 0;
	}

	.content {
		flex: 1;
		background: white;
		border-radius: 12px;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
		padding: 2rem;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.placeholder {
		text-align: center;
		color: #64748b;
	}

	.placeholder-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.placeholder h2 {
		font-size: 1.5rem;
		color: #1e293b;
		margin-bottom: 0.5rem;
	}

	.placeholder p {
		font-size: 1rem;
		margin: 0;
	}
</style>
