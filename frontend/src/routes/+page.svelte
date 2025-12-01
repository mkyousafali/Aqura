<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { currentUser } from '$lib/utils/persistentAuth';

		onMount(() => {
		// Redirect to appropriate interface based on user type
		if ($currentUser) {
			// Default to desktop interface for logged-in users
			goto('/desktop-interface');
		} else {
			// Redirect to login for unauthenticated users
			goto('/login');
		}
	});
</script>

<!-- Loading state while redirecting -->
<div class="loading-container">
	<div class="spinner"></div>
	<p>Loading...</p>
</div>

<style>
	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100vh;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		color: white;
	}

	.spinner {
		width: 50px;
		height: 50px;
		border: 4px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	p {
		margin-top: 1rem;
		font-size: 1.2rem;
	}
</style>
