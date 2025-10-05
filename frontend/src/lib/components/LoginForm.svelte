<script lang="ts">
	import { onMount } from 'svelte';
	import { auth } from '$lib/utils/supabase';

	let email = '';
	let password = '';
	let loading = false;
	let error = '';

	async function handleLogin() {
		if (!email || !password) return;

		loading = true;
		error = '';

		const { data, error: authError } = await auth.signIn(email, password);

		if (authError) {
			error = authError.message;
		} else {
			// Successful login - reload page to get authenticated state
			window.location.reload();
		}

		loading = false;
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter') {
			handleLogin();
		}
	}
</script>

<div class="login-container">
	<div class="login-card">
		<div class="logo">
			<img src="/icons/logo.png" alt="Aqura" />
			<h1>Aqura</h1>
		</div>

		<form on:submit|preventDefault={handleLogin}>
			<div class="form-group">
				<label for="email">Email</label>
				<input
					id="email"
					type="email"
					bind:value={email}
					on:keydown={handleKeydown}
					placeholder="Enter your email"
					required
				/>
			</div>

			<div class="form-group">
				<label for="password">Password</label>
				<input
					id="password"
					type="password"
					bind:value={password}
					on:keydown={handleKeydown}
					placeholder="Enter your password"
					required
				/>
			</div>

			{#if error}
				<div class="error-message">
					{error}
				</div>
			{/if}

			<button type="submit" class="login-btn" disabled={loading}>
				{loading ? 'Signing in...' : 'Sign In'}
			</button>
		</form>

		<p class="signup-text">
			Need an account? Contact your administrator.
		</p>
	</div>
</div>

<style>
	.login-container {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		padding: 1rem;
	}

	.login-card {
		background: white;
		padding: 2rem;
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
		width: 100%;
		max-width: 400px;
	}

	.logo {
		display: flex;
		flex-direction: column;
		align-items: center;
		margin-bottom: 2rem;
	}

	.logo img {
		width: 64px;
		height: 64px;
		margin-bottom: 0.5rem;
	}

	.logo h1 {
		margin: 0;
		font-size: 1.5rem;
		font-weight: 700;
		color: #1f2937;
	}

	.form-group {
		margin-bottom: 1rem;
	}

	.form-group label {
		display: block;
		margin-bottom: 0.5rem;
		font-weight: 500;
		color: #374151;
	}

	.form-group input {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 1rem;
		transition: border-color 0.15s ease;
		box-sizing: border-box;
	}

	.form-group input:focus {
		outline: none;
		border-color: #6366f1;
		box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
	}

	.error-message {
		background: #fee2e2;
		color: #dc2626;
		padding: 0.75rem;
		border-radius: 6px;
		margin-bottom: 1rem;
		font-size: 0.875rem;
		border: 1px solid #fecaca;
	}

	.login-btn {
		width: 100%;
		padding: 0.75rem;
		border: none;
		border-radius: 6px;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s ease;
		margin-bottom: 0.5rem;
		background: #6366f1;
		color: white;
	}

	.login-btn:hover:not(:disabled) {
		background: #5b21b6;
		transform: translateY(-1px);
	}

	.login-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
		transform: none;
	}

	.signup-text {
		text-align: center;
		margin-top: 1.5rem;
		color: #6b7280;
		font-size: 0.875rem;
	}
</style>