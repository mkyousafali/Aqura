<script lang="ts">
	import { supabase } from '$lib/utils/supabase';

	// Props
	export let user: any;            // The user row from UserManagement
	export let branches: any[];      // All branches array [{id, name_en, name_ar, ...}]
	export let onClose: () => void;  // Callback to close modal

	// ── Types ─────────────────────────────────────────────────
	interface UserErpCredential {
		id: string;
		userId: string;
		branchId: number;
		erpUsername: string;
		erpPassword: string;
		createdAt: string;
		updatedAt: string;
		branchName?: string;
	}

	// ── State ─────────────────────────────────────────────────
	let credentials: UserErpCredential[] = [];
	let loadingList = true;
	let listError = '';

	// Form state
	let formMode: 'add' | 'edit' = 'add';
	let editingId: string | null = null;
	let formBranchId = '';
	let formUsername = '';
	let formPassword = '';
	let formShowPassword = false;
	let formSaving = false;
	let formError = '';
	let fieldErrors: { branch?: string; username?: string; password?: string } = {};

	// Per-row show/hide password state
	let rowShowPassword: Record<string, boolean> = {};

	// Delete confirmation
	let deleteConfirmId: string | null = null;
	let deleteConfirmName = '';
	let deleting = false;

	// Toast
	let toast: { message: string; type: 'success' | 'error' } | null = null;
	let toastTimer: ReturnType<typeof setTimeout>;

	function showToast(message: string, type: 'success' | 'error' = 'success') {
		clearTimeout(toastTimer);
		toast = { message, type };
		toastTimer = setTimeout(() => (toast = null), 3500);
	}

	// ── Load credentials ──────────────────────────────────────
	async function loadCredentials() {
		loadingList = true;
		listError = '';
		try {
			const { data, error } = await supabase
				.from('user_erp_credentials')
				.select('id, user_id, branch_id, erp_username, erp_password, created_at, updated_at')
				.eq('user_id', user.id)
				.order('created_at', { ascending: true });

			if (error) throw error;

			// Map to typed objects and attach branch names
			credentials = (data || []).map((row: any) => {
				const branch = branches.find((b: any) => b.id === row.branch_id);
				return {
					id: row.id,
					userId: row.user_id,
					branchId: row.branch_id,
					erpUsername: row.erp_username,
					erpPassword: row.erp_password,
					createdAt: row.created_at,
					updatedAt: row.updated_at,
					branchName: branch ? branch.name_en : `Branch ${row.branch_id}`
				};
			});
		} catch (err: any) {
			listError = err.message || 'Failed to load credentials';
		} finally {
			loadingList = false;
		}
	}

	// ── Computed: branches already used ───────────────────────
	$: usedBranchIds = new Set(credentials.map((c) => c.branchId));

	// ── Form helpers ──────────────────────────────────────────
	function resetForm() {
		formMode = 'add';
		editingId = null;
		formBranchId = '';
		formUsername = '';
		formPassword = '';
		formShowPassword = false;
		formError = '';
		fieldErrors = {};
	}

	function startEdit(cred: UserErpCredential) {
		formMode = 'edit';
		editingId = cred.id;
		formBranchId = cred.branchId.toString();
		formUsername = cred.erpUsername;
		formPassword = cred.erpPassword;
		formShowPassword = false;
		formError = '';
		fieldErrors = {};
	}

	function validateForm(): boolean {
		fieldErrors = {};
		let valid = true;
		if (!formBranchId) {
			fieldErrors.branch = 'Branch is required.';
			valid = false;
		}
		if (!formUsername.trim()) {
			fieldErrors.username = 'ERP Username is required.';
			valid = false;
		}
		if (!formPassword) {
			fieldErrors.password = 'ERP Password is required.';
			valid = false;
		}
		// Warn if password contains Tab or CR (would break QR wedge format)
		if (formPassword.includes('\t') || formPassword.includes('\r')) {
			fieldErrors.password =
				'⚠️ Password contains a Tab or Enter character which conflicts with the keyboard-wedge QR format. Please use a different password.';
			valid = false;
		}
		return valid;
	}

	async function saveForm() {
		if (!validateForm()) return;
		formSaving = true;
		formError = '';

		// Do NOT log password values
		const payload = {
			user_id: user.id,
			branch_id: parseInt(formBranchId),
			erp_username: formUsername.trim(),
			erp_password: formPassword   // password: preserve as-is, no trim
		};

		try {
			if (formMode === 'add') {
				const { error } = await supabase
					.from('user_erp_credentials')
					.insert(payload);
				if (error) {
					if (error.code === '23505') {
						formError = 'A credential for this branch already exists.';
					} else {
						formError = error.message;
					}
					return;
				}
				showToast('ERP credentials added successfully.', 'success');
			} else {
				if (!editingId) return;
				const { error } = await supabase
					.from('user_erp_credentials')
					.update({
						erp_username: payload.erp_username,
						erp_password: payload.erp_password
					})
					.eq('id', editingId);
				if (error) {
					formError = error.message;
					return;
				}
				showToast('ERP credentials updated successfully.', 'success');
			}
			resetForm();
			await loadCredentials();
		} catch (err: any) {
			// Log only the operation name, never credential values
			console.error('ERP credentials save error for user_id=' + user.id, err?.code);
			formError = 'An unexpected error occurred. Please try again.';
		} finally {
			formSaving = false;
		}
	}

	// ── Delete ────────────────────────────────────────────────
	function askDelete(cred: UserErpCredential) {
		deleteConfirmId = cred.id;
		deleteConfirmName = cred.branchName || '';
		// If currently editing this row, cancel edit
		if (editingId === cred.id) resetForm();
	}

	async function confirmDelete() {
		if (!deleteConfirmId) return;
		deleting = true;
		try {
			const { error } = await supabase
				.from('user_erp_credentials')
				.delete()
				.eq('id', deleteConfirmId);
			if (error) throw error;
			showToast('Credential deleted.', 'success');
			await loadCredentials();
		} catch (err: any) {
			console.error('ERP credentials delete error for user_id=' + user.id, err?.code);
			showToast('Delete failed: ' + (err.message || 'Unknown error'), 'error');
		} finally {
			deleting = false;
			deleteConfirmId = null;
			deleteConfirmName = '';
		}
	}

	function cancelDelete() {
		deleteConfirmId = null;
		deleteConfirmName = '';
	}

	// ── Keyboard handler ──────────────────────────────────────
	function handleOverlayKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') onClose();
	}

	function handleFormKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			saveForm();
		}
	}

	// ── Display helper ────────────────────────────────────────
	function getUserDisplayName(): string {
		const empData = user._empData; // if passed through; fallback to username
		return user.username || 'Unknown';
	}

	// ── Init ──────────────────────────────────────────────────
	loadCredentials();
</script>

<!-- ── Modal Overlay ──────────────────────────────────────── -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div
	class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 animate-in fade-in duration-200 p-4"
	on:click|self={onClose}
	on:keydown={handleOverlayKeydown}
	role="dialog"
	aria-modal="true"
	aria-labelledby="erp-modal-title"
	tabindex="-1"
>
	<!-- Modal Panel -->
	<div class="bg-white rounded-3xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col overflow-hidden scale-in">

		<!-- Header -->
		<div class="bg-gradient-to-r from-violet-600 to-purple-500 px-6 py-4 flex items-center justify-between flex-shrink-0">
			<div>
				<h3 id="erp-modal-title" class="text-lg font-black text-white">🔑 ERP Credentials</h3>
				<p class="text-violet-100 text-xs mt-0.5 font-semibold">
					{user.username}
				</p>
			</div>
			<button
				class="text-white/70 hover:text-white text-2xl leading-none transition"
				on:click={onClose}
				aria-label="Close"
			>✕</button>
		</div>

		<!-- Toast -->
		{#if toast}
			<div class="px-6 pt-3">
				<div class="rounded-xl px-4 py-2.5 text-sm font-bold
					{toast.type === 'success' ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-red-50 text-red-800 border border-red-200'}">
					{toast.type === 'success' ? '✅' : '⚠️'} {toast.message}
				</div>
			</div>
		{/if}

		<!-- Body: scrollable -->
		<div class="flex-1 overflow-y-auto p-6 space-y-6">

			<!-- ── Existing credentials list ── -->
			<div>
				<h4 class="text-xs font-black text-slate-500 uppercase tracking-wider mb-3">Existing Credentials</h4>

				{#if loadingList}
					<div class="text-center py-6 text-slate-400 font-semibold text-sm">Loading...</div>
				{:else if listError}
					<div class="bg-red-50 border border-red-200 rounded-xl px-4 py-3 text-sm text-red-700 font-semibold">
						⚠️ {listError}
					</div>
				{:else if credentials.length === 0}
					<div class="text-center py-6 text-slate-400 font-semibold text-sm bg-slate-50 rounded-2xl border border-dashed border-slate-200">
						No ERP credentials set for this user yet.
					</div>
				{:else}
					<div class="space-y-2">
						{#each credentials as cred (cred.id)}
							<div class="bg-slate-50 rounded-2xl border border-slate-200 px-4 py-3 flex flex-col gap-2">
								<div class="flex items-center justify-between gap-3">
									<div class="flex-1 min-w-0">
										<div class="text-xs font-bold text-slate-500 uppercase tracking-wide mb-1">
											🏢 {cred.branchName}
										</div>
										<div class="flex items-center gap-3 flex-wrap">
											<span class="text-sm font-semibold text-slate-800" dir="ltr">{cred.erpUsername}</span>
											<div class="flex items-center gap-1">
												<span class="text-sm font-mono text-slate-500" dir="ltr">
													{rowShowPassword[cred.id] ? cred.erpPassword : '••••••••'}
												</span>
												<button
													class="text-slate-400 hover:text-slate-700 text-xs px-1 py-0.5 rounded transition"
													on:click={() => (rowShowPassword[cred.id] = !rowShowPassword[cred.id])}
													title={rowShowPassword[cred.id] ? 'Hide password' : 'Show password'}
													aria-label={rowShowPassword[cred.id] ? 'Hide password' : 'Show password'}
												>
													{rowShowPassword[cred.id] ? '🙈' : '👁️'}
												</button>
											</div>
										</div>
									</div>
									<div class="flex items-center gap-1.5 flex-shrink-0">
										<button
											class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-blue-600 text-white text-sm font-bold hover:bg-blue-700 hover:shadow transition-all duration-200 transform hover:scale-105 disabled:opacity-50"
											on:click={() => startEdit(cred)}
											disabled={formSaving || deleting}
											title="Edit"
											aria-label="Edit credential for {cred.branchName}"
										>✏️</button>
										<button
											class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-600 text-white text-sm font-bold hover:bg-red-700 hover:shadow transition-all duration-200 transform hover:scale-105 disabled:opacity-50"
											on:click={() => askDelete(cred)}
											disabled={formSaving || deleting}
											title="Delete"
											aria-label="Delete credential for {cred.branchName}"
										>🗑️</button>
									</div>
								</div>

								<!-- Inline delete confirmation -->
								{#if deleteConfirmId === cred.id}
									<div class="bg-red-50 border border-red-200 rounded-xl px-3 py-2 flex items-center justify-between gap-3">
										<span class="text-sm text-red-700 font-semibold">Delete credential for <b>{deleteConfirmName}</b>?</span>
										<div class="flex gap-2">
											<button
												class="px-3 py-1 rounded-lg text-xs font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
												on:click={cancelDelete}
												disabled={deleting}
											>Cancel</button>
											<button
												class="px-3 py-1 rounded-lg text-xs font-bold text-white bg-red-600 hover:bg-red-700 transition disabled:opacity-50"
												on:click={confirmDelete}
												disabled={deleting}
											>{deleting ? 'Deleting…' : 'Delete'}</button>
										</div>
									</div>
								{/if}
							</div>
						{/each}
					</div>
				{/if}
			</div>

			<!-- ── Add / Edit form ── -->
			<!-- svelte-ignore a11y-no-static-element-interactions -->
			<div on:keydown={handleFormKeydown}>
				<h4 class="text-xs font-black text-slate-500 uppercase tracking-wider mb-3">
					{formMode === 'edit' ? '✏️ Edit Credential' : '➕ Add New Credential'}
				</h4>
				<div class="bg-slate-50 rounded-2xl border border-slate-200 p-4 space-y-4">

					<!-- Branch Dropdown -->
					<div>
						<label class="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide" for="erp-branch-select">
							Branch <span class="text-red-500">*</span>
						</label>
						{#if formMode === 'edit'}
							<!-- In edit mode: branch is locked -->
							<input
								type="text"
								class="w-full px-3 py-2.5 bg-slate-100 border border-slate-200 rounded-xl text-sm font-semibold text-slate-600 cursor-not-allowed"
								value={branches.find((b: any) => b.id.toString() === formBranchId)?.name_en ?? formBranchId}
								readonly
								aria-readonly="true"
							/>
							<p class="text-xs text-slate-400 mt-1">Branch cannot be changed in edit mode. Delete and re-add to change branch.</p>
						{:else}
							<select
								id="erp-branch-select"
								bind:value={formBranchId}
								class="w-full px-3 py-2.5 bg-white border {fieldErrors.branch ? 'border-red-400' : 'border-slate-300'} rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all"
								style="color: #000000 !important; background-color: #ffffff !important;"
								aria-describedby={fieldErrors.branch ? 'erp-branch-error' : undefined}
							>
								<option value="">-- Select Branch --</option>
								{#each branches as branch (branch.id)}
									<option value={branch.id.toString()} disabled={usedBranchIds.has(branch.id)}>
										{branch.name_en}{usedBranchIds.has(branch.id) ? ' (already set)' : ''}
									</option>
								{/each}
							</select>
							{#if fieldErrors.branch}
								<p id="erp-branch-error" class="text-xs text-red-600 font-semibold mt-1">{fieldErrors.branch}</p>
							{/if}
						{/if}
					</div>

					<!-- ERP Username -->
					<div>
						<label class="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide" for="erp-username">
							ERP Username <span class="text-red-500">*</span>
						</label>
						<input
							id="erp-username"
							type="text"
							bind:value={formUsername}
							placeholder="Enter ERP username"
							class="w-full px-3 py-2.5 bg-white border {fieldErrors.username ? 'border-red-400' : 'border-slate-300'} rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all"
							dir="ltr"
							autocomplete="off"
							aria-describedby={fieldErrors.username ? 'erp-username-error' : undefined}
						/>
						{#if fieldErrors.username}
							<p id="erp-username-error" class="text-xs text-red-600 font-semibold mt-1">{fieldErrors.username}</p>
						{/if}
					</div>

					<!-- ERP Password -->
					<div>
						<label class="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide" for="erp-password">
							ERP Password <span class="text-red-500">*</span>
						</label>
						<div class="relative">
							<input
								id="erp-password"
								type={formShowPassword ? 'text' : 'password'}
								bind:value={formPassword}
								placeholder="Enter ERP password"
								class="w-full px-3 py-2.5 pr-10 bg-white border {fieldErrors.password ? 'border-red-400' : 'border-slate-300'} rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent transition-all"
								dir="ltr"
								autocomplete="new-password"
								aria-describedby={fieldErrors.password ? 'erp-password-error' : undefined}
							/>
							<button
								type="button"
								class="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700 transition text-sm px-1"
								on:click={() => (formShowPassword = !formShowPassword)}
								aria-label={formShowPassword ? 'Hide password' : 'Show password'}
								tabindex="-1"
							>{formShowPassword ? '🙈' : '👁️'}</button>
						</div>
						{#if fieldErrors.password}
							<p id="erp-password-error" class="text-xs text-red-600 font-semibold mt-1">{fieldErrors.password}</p>
						{/if}
					</div>

					<!-- Form error -->
					{#if formError}
						<div class="bg-red-50 border border-red-200 rounded-xl px-3 py-2 text-sm text-red-700 font-semibold">
							⚠️ {formError}
						</div>
					{/if}

					<!-- Form buttons -->
					<div class="flex gap-2 justify-end pt-1">
						{#if formMode === 'edit'}
							<button
								class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition text-sm"
								on:click={resetForm}
								disabled={formSaving}
							>Cancel</button>
						{/if}
						<button
							class="px-6 py-2 rounded-lg font-black text-white bg-violet-600 hover:bg-violet-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
							on:click={saveForm}
							disabled={formSaving}
						>
							{formSaving ? '⏳ Saving…' : formMode === 'edit' ? '✅ Update' : '✅ Save'}
						</button>
					</div>
				</div>
			</div>

		</div>

		<!-- Footer -->
		<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex justify-end flex-shrink-0">
			<button
				class="px-5 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition text-sm"
				on:click={onClose}
			>Close</button>
		</div>

	</div>
</div>

<style>
	@keyframes fadeIn {
		from { opacity: 0; }
		to   { opacity: 1; }
	}
	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.95); }
		to   { opacity: 1; transform: scale(1); }
	}
	.animate-in { animation: fadeIn 0.2s ease-out; }
	.scale-in   { animation: scaleIn 0.3s ease-out; }
</style>
