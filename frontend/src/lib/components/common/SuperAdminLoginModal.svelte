<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { goto } from '$app/navigation';
	import { SUPER_ADMIN_CREDENTIALS, SUPER_ADMIN_SESSION } from '$lib/utils/superAdminAuth';
	import { currentUser, isAuthenticated, persistentAuthService } from '$lib/utils/persistentAuth';

	export let show = false;

	const dispatch = createEventDispatcher();

	let username = '';
	let password = '';
	let securityAnswer = '';
	let errorMessage = '';
	let isLoading = false;

	$: isValid =
		username.trim() === SUPER_ADMIN_CREDENTIALS.username &&
		password === SUPER_ADMIN_CREDENTIALS.password &&
		securityAnswer.trim() === SUPER_ADMIN_CREDENTIALS.securityAnswer;

	function closeWindow() {
		show = false;
		username = '';
		password = '';
		securityAnswer = '';
		errorMessage = '';
		dispatch('close');
	}

	async function handleSuperAdminLogin() {
		if (!isValid) {
			errorMessage = 'Invalid credentials or security answer.';
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			// Set super admin session in persistentAuth memory/stores & localStorage without DB check
			await persistentAuthService.saveUserSession(SUPER_ADMIN_SESSION);
			await persistentAuthService.setCurrentUser(SUPER_ADMIN_SESSION);

			// Redirect to main desktop interface
			goto('/');
			closeWindow();
		} catch (err: any) {
			errorMessage = err?.message || 'Failed to initialize Super Admin session.';
		} finally {
			isLoading = false;
		}
	}
</script>

{#if show}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div class="super-admin-modal-backdrop" on:click|self={closeWindow}>
		<div class="super-admin-modal">
			<div class="modal-header">
				<div class="header-title">
					<span class="shield-icon">🛡️</span>
					<h3>Super Admin Authentication</h3>
				</div>
				<button class="close-btn" on:click={closeWindow}>&times;</button>
			</div>

			<div class="modal-body">
				<p class="description">
					System deployment & recovery access mode. Credentials are validated locally and bypass database authentication.
				</p>

				{#if errorMessage}
					<div class="error-banner">
						⚠️ {errorMessage}
					</div>
				{/if}

				<form on:submit|preventDefault={handleSuperAdminLogin}>
					<div class="form-group">
						<label for="sa-username">Super Admin Username</label>
						<input
							id="sa-username"
							type="text"
							bind:value={username}
							placeholder="Enter super admin username"
							autocomplete="off"
						/>
					</div>

					<div class="form-group">
						<label for="sa-password">Super Admin Password</label>
						<input
							id="sa-password"
							type="password"
							bind:value={password}
							placeholder="Enter password"
							autocomplete="off"
						/>
					</div>

					<div class="form-group security-box">
						<label for="sa-question">Security Question</label>
						<div class="question-text">{SUPER_ADMIN_CREDENTIALS.securityQuestion}</div>
						<input
							id="sa-question"
							type="text"
							bind:value={securityAnswer}
							placeholder="Enter answer"
							autocomplete="off"
						/>
					</div>

					<div class="modal-actions">
						<button type="button" class="btn-cancel" on:click={closeWindow}>Cancel</button>
						<button
							type="submit"
							class="btn-login"
							disabled={!isValid || isLoading}
						>
							{#if isLoading}
								Authenticating...
							{:else}
								Login as Super Admin
							{/if}
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

<style>
	.super-admin-modal-backdrop {
		position: fixed;
		top: 0;
		left: 0;
		width: 100vw;
		height: 100vh;
		background: rgba(15, 23, 42, 0.75);
		backdrop-filter: blur(8px);
		z-index: 999999;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 16px;
		box-sizing: border-box;
	}

	.super-admin-modal {
		background: #ffffff;
		width: 100%;
		max-width: 480px;
		border-radius: 16px;
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35);
		overflow: hidden;
		border: 1px solid rgba(226, 232, 240, 0.8);
		animation: modalPop 0.25s cubic-bezier(0.16, 1, 0.3, 1);
	}

	@keyframes modalPop {
		from {
			opacity: 0;
			transform: scale(0.92) translateY(10px);
		}
		to {
			opacity: 1;
			transform: scale(1) translateY(0);
		}
	}

	.modal-header {
		background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
		color: #ffffff;
		padding: 18px 24px;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.header-title {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.shield-icon {
		font-size: 1.4rem;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 1.15rem;
		font-weight: 700;
		color: #f8fafc;
	}

	.close-btn {
		background: transparent;
		border: none;
		color: #94a3b8;
		font-size: 1.8rem;
		line-height: 1;
		cursor: pointer;
		padding: 0;
		transition: color 0.15s;
	}

	.close-btn:hover {
		color: #ffffff;
	}

	.modal-body {
		padding: 24px;
	}

	.description {
		font-size: 0.875rem;
		color: #64748b;
		margin: 0 0 20px 0;
		line-height: 1.45;
	}

	.error-banner {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 10px 14px;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 500;
		margin-bottom: 18px;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group label {
		display: block;
		font-size: 0.825rem;
		font-weight: 600;
		color: #334155;
		margin-bottom: 6px;
	}

	.form-group input {
		width: 100%;
		padding: 10px 14px;
		border: 1px solid #cbd5e1;
		border-radius: 8px;
		font-size: 0.9rem;
		color: #0f172a;
		outline: none;
		box-sizing: border-box;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.form-group input:focus {
		border-color: #2563eb;
		box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.15);
	}

	.security-box {
		background: #f8fafc;
		border: 1px solid #e2e8f0;
		padding: 14px;
		border-radius: 10px;
	}

	.question-text {
		font-weight: 700;
		font-size: 0.9rem;
		color: #1e293b;
		margin-bottom: 10px;
	}

	.modal-actions {
		display: flex;
		align-items: center;
		justify-content: flex-end;
		gap: 12px;
		margin-top: 24px;
	}

	.btn-cancel {
		background: #f1f5f9;
		border: 1px solid #cbd5e1;
		color: #475569;
		padding: 10px 18px;
		border-radius: 8px;
		font-weight: 600;
		font-size: 0.875rem;
		cursor: pointer;
		transition: background 0.15s;
	}

	.btn-cancel:hover {
		background: #e2e8f0;
	}

	.btn-login {
		background: linear-gradient(135deg, #16a34a 0%, #15803d 100%);
		border: none;
		color: #ffffff;
		padding: 10px 22px;
		border-radius: 8px;
		font-weight: 700;
		font-size: 0.875rem;
		cursor: pointer;
		box-shadow: 0 4px 12px rgba(22, 163, 74, 0.3);
		transition: transform 0.15s, opacity 0.15s, box-shadow 0.15s;
	}

	.btn-login:hover:not(:disabled) {
		transform: translateY(-1px);
		box-shadow: 0 6px 16px rgba(22, 163, 74, 0.4);
	}

	.btn-login:disabled {
		background: #94a3b8;
		box-shadow: none;
		cursor: not-allowed;
		opacity: 0.7;
	}
</style>
