<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';

	interface EmailAccount {
		id: string;
		account_name: string;
		email_address: string;
		from_name: string;
		provider_name: string;
		provider_code: string;
		smtp_host: string;
		smtp_port: number;
		smtp_encryption: string;
		smtp_username: string;
		imap_host: string;
		imap_port: number;
		imap_encryption: string;
		imap_username: string;
		send_enabled: boolean;
		sync_enabled: boolean;
		hourly_send_limit: number;
		daily_send_limit: number;
		last_smtp_test_status: string;
		last_imap_test_status: string;
		last_sync_at: string;
		sent_this_hour: number;
		sent_today: number;
		is_active: boolean;
		default_for_manual: boolean;
		default_for_transactional: boolean;
		default_for_otp: boolean;
		default_for_broadcast: boolean;
		default_for_incoming: boolean;
	}

	interface ProviderPreset {
		id: string;
		provider_code: string;
		provider_name: string;
		smtp_host: string;
		smtp_port: number;
		smtp_encryption: string;
		imap_host: string;
		imap_port: number;
		imap_encryption: string;
	}

	let supabase: any = null;
	let loading = true;
	let accounts: EmailAccount[] = [];
	let presets: ProviderPreset[] = [];
	let showForm = false;
	let editingAccount: EmailAccount | null = null;
	let saving = false;
	let testing = false;
	let testResult = '';

	// Form fields
	let form = resetForm();

	function resetForm() {
		return {
			account_name: '', email_address: '', provider_preset_id: '',
			from_name: '', reply_to_address: '',
			smtp_host: '', smtp_port: 587, smtp_encryption: 'tls', smtp_username: '', smtp_password: '',
			imap_host: '', imap_port: 993, imap_encryption: 'ssl', imap_username: '', imap_password: '',
			send_enabled: true, sync_enabled: false,
			hourly_send_limit: 100, daily_send_limit: 2000,
			maximum_recipients_per_message: 50, reserve_critical_per_hour: 10,
			queue_batch_size: 10, minimum_delay_seconds: 2,
			maximum_concurrent_sends: 3, maximum_retry_count: 3,
			default_for_manual: false, default_for_transactional: false,
			default_for_otp: false, default_for_broadcast: false, default_for_incoming: false,
			notes: ''
		};
	}

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadData();
	});

	async function loadData() {
		loading = true;
		try {
			const [accountsRes, presetsRes] = await Promise.all([
				supabase.rpc('get_email_accounts'),
				supabase.rpc('get_email_provider_presets')
			]);
			if (accountsRes.data) accounts = accountsRes.data;
			if (presetsRes.data) presets = presetsRes.data;
		} catch (err) {
			console.error('Error loading accounts:', err);
		} finally {
			loading = false;
		}
	}

	function openCreate() {
		form = resetForm();
		editingAccount = null;
		showForm = true;
	}

	function openEdit(account: EmailAccount) {
		editingAccount = account;
		form = {
			...resetForm(),
			account_name: account.account_name,
			email_address: account.email_address,
			from_name: account.from_name || '',
			smtp_host: account.smtp_host || '',
			smtp_port: account.smtp_port || 587,
			smtp_encryption: account.smtp_encryption || 'tls',
			smtp_username: account.smtp_username || '',
			imap_host: account.imap_host || '',
			imap_port: account.imap_port || 993,
			imap_encryption: account.imap_encryption || 'ssl',
			imap_username: account.imap_username || '',
			send_enabled: account.send_enabled,
			sync_enabled: account.sync_enabled,
			hourly_send_limit: account.hourly_send_limit,
			daily_send_limit: account.daily_send_limit,
			default_for_manual: account.default_for_manual,
			default_for_transactional: account.default_for_transactional,
			default_for_otp: account.default_for_otp,
			default_for_broadcast: account.default_for_broadcast,
			default_for_incoming: account.default_for_incoming,
		};
		showForm = true;
	}

	function onPresetChange() {
		const preset = presets.find(p => p.id === form.provider_preset_id);
		if (preset) {
			form.smtp_host = preset.smtp_host || '';
			form.smtp_port = preset.smtp_port || 587;
			form.smtp_encryption = preset.smtp_encryption || 'tls';
			form.imap_host = preset.imap_host || '';
			form.imap_port = preset.imap_port || 993;
			form.imap_encryption = preset.imap_encryption || 'ssl';
		}
	}

	async function saveAccount() {
		saving = true;
		try {
			let accountId = editingAccount?.id;
			if (editingAccount) {
				const { error } = await supabase.rpc('update_email_account', {
					p_id: editingAccount.id,
					p_data: { ...form, smtp_password: undefined, imap_password: undefined }
				});
				if (error) throw error;
			} else {
				const { data, error } = await supabase.rpc('create_email_account', {
					p_account_name: form.account_name,
					p_email_address: form.email_address,
					p_provider_preset_id: form.provider_preset_id || null,
					p_from_name: form.from_name || null,
					p_smtp_host: form.smtp_host || null,
					p_smtp_port: form.smtp_port,
					p_smtp_encryption: form.smtp_encryption,
					p_smtp_username: form.smtp_username || null,
					p_imap_host: form.imap_host || null,
					p_imap_port: form.imap_port,
					p_imap_encryption: form.imap_encryption,
					p_imap_username: form.imap_username || null,
					p_hourly_send_limit: form.hourly_send_limit,
					p_daily_send_limit: form.daily_send_limit,
					p_sync_enabled: form.sync_enabled,
					p_send_enabled: form.send_enabled,
					p_notes: form.notes || null
				});
				if (error) throw error;
				accountId = data?.id;
			}

			// Save credentials if provided
			if (accountId && (form.smtp_password || form.imap_password)) {
				const { error: credError } = await supabase.rpc('store_email_credentials', {
					p_account_id: accountId,
					p_smtp_password: form.smtp_password || null,
					p_imap_password: form.imap_password || null
				});
				if (credError) console.error('Credential save error:', credError);
			}

			showForm = false;
			await loadData();
		} catch (err: any) {
			alert('Error saving account: ' + (err.message || err));
		} finally {
			saving = false;
		}
	}

	async function deleteAccount(id: string) {
		if (!confirm('Deactivate this email account?')) return;
		try {
			const { error } = await supabase.rpc('delete_email_account', { p_id: id });
			if (error) throw error;
			await loadData();
		} catch (err: any) {
			alert('Error: ' + err.message);
		}
	}

	async function testSmtp(accountId: string) {
		testing = true;
		testResult = '';
		try {
			const { data, error } = await supabase.functions.invoke('email-account-test', {
				body: { account_id: accountId, test_type: 'smtp' }
			});
			if (error) throw error;
			testResult = data?.success ? '✅ SMTP connection successful' : '❌ SMTP failed: ' + (data?.error || 'Unknown');
		} catch (err: any) {
			testResult = '❌ SMTP test failed: ' + err.message;
		} finally {
			testing = false;
			await loadData();
		}
	}

	async function testImap(accountId: string) {
		testing = true;
		testResult = '';
		try {
			const { data, error } = await supabase.functions.invoke('email-account-test', {
				body: { account_id: accountId, test_type: 'imap' }
			});
			if (error) throw error;
			testResult = data?.success ? '✅ IMAP connection successful' : '❌ IMAP failed: ' + (data?.error || 'Unknown');
		} catch (err: any) {
			testResult = '❌ IMAP test failed: ' + err.message;
		} finally {
			testing = false;
			await loadData();
		}
	}

	async function testBoth(accountId: string) {
		testing = true;
		testResult = '⏳ Testing SMTP...';
		let smtpOk = false;
		let imapOk = false;
		let smtpMsg = '';
		let imapMsg = '';

		try {
			const { data: smtpData, error: smtpErr } = await supabase.functions.invoke('email-account-test', {
				body: { account_id: accountId, test_type: 'smtp' }
			});
			if (smtpErr) throw smtpErr;
			smtpOk = smtpData?.success;
			smtpMsg = smtpOk ? '✅ SMTP OK' : '❌ SMTP: ' + (smtpData?.error || 'Failed');
		} catch (err: any) {
			smtpMsg = '❌ SMTP: ' + err.message;
		}

		testResult = smtpMsg + '  |  ⏳ Testing IMAP...';

		try {
			const { data: imapData, error: imapErr } = await supabase.functions.invoke('email-account-test', {
				body: { account_id: accountId, test_type: 'imap' }
			});
			if (imapErr) throw imapErr;
			imapOk = imapData?.success;
			imapMsg = imapOk ? '✅ IMAP OK' : '❌ IMAP: ' + (imapData?.error || 'Failed');
		} catch (err: any) {
			imapMsg = '❌ IMAP: ' + err.message;
		}

		testResult = smtpMsg + '  |  ' + imapMsg;
		testing = false;
		await loadData();
	}
</script>

<div class="email-accounts">
	{#if loading}
		<div class="loading-container">
			<div class="loading-spinner"></div>
			<p>Loading accounts...</p>
		</div>
	{:else if showForm}
		<!-- Account Form -->
		<div class="form-container">
			<div class="form-header">
				<h3>{editingAccount ? 'Edit' : 'Create'} Email Account</h3>
				<button class="glass-btn" on:click={() => showForm = false}>← Back</button>
			</div>

			<div class="form-sections">
				<!-- General -->
				<div class="form-section">
					<h4>General</h4>
					<div class="form-grid">
						<label>
							<span>Account Name *</span>
							<input type="text" bind:value={form.account_name} placeholder="My Email Account" />
						</label>
						<label>
							<span>Provider</span>
							<select bind:value={form.provider_preset_id} on:change={onPresetChange}>
								<option value="">Select provider...</option>
								{#each presets as preset}
									<option value={preset.id}>{preset.provider_name}</option>
								{/each}
							</select>
						</label>
						<label>
							<span>Email Address *</span>
							<input type="email" bind:value={form.email_address} placeholder="user@domain.com" />
						</label>
						<label>
							<span>From Name</span>
							<input type="text" bind:value={form.from_name} placeholder="Display Name" />
						</label>
					</div>
				</div>

				<!-- SMTP -->
				<div class="form-section">
					<h4>SMTP (Sending)</h4>
					<div class="form-grid">
						<label>
							<span>SMTP Host</span>
							<input type="text" bind:value={form.smtp_host} placeholder="smtp.example.com" />
						</label>
						<label>
							<span>Port</span>
							<input type="number" bind:value={form.smtp_port} />
						</label>
						<label>
							<span>Encryption</span>
							<select bind:value={form.smtp_encryption}>
								<option value="tls">TLS (587)</option>
								<option value="ssl">SSL (465)</option>
								<option value="none">None (25)</option>
							</select>
						</label>
						<label>
							<span>Username</span>
							<input type="text" bind:value={form.smtp_username} placeholder="username" />
						</label>
						<label>
							<span>Password {editingAccount ? '(leave blank to keep)' : ''}</span>
							<input type="password" bind:value={form.smtp_password} placeholder="••••••••" />
						</label>
						<label class="checkbox-label">
							<input type="checkbox" bind:checked={form.send_enabled} />
							<span>Sending Enabled</span>
						</label>
					</div>
				</div>

				<!-- IMAP -->
				<div class="form-section">
					<h4>IMAP (Receiving)</h4>
					<div class="form-grid">
						<label>
							<span>IMAP Host</span>
							<input type="text" bind:value={form.imap_host} placeholder="imap.example.com" />
						</label>
						<label>
							<span>Port</span>
							<input type="number" bind:value={form.imap_port} />
						</label>
						<label>
							<span>Encryption</span>
							<select bind:value={form.imap_encryption}>
								<option value="ssl">SSL (993)</option>
								<option value="tls">TLS (143)</option>
								<option value="none">None</option>
							</select>
						</label>
						<label>
							<span>Username</span>
							<input type="text" bind:value={form.imap_username} placeholder="username" />
						</label>
						<label>
							<span>Password {editingAccount ? '(leave blank to keep)' : ''}</span>
							<input type="password" bind:value={form.imap_password} placeholder="••••••••" />
						</label>
						<label class="checkbox-label">
							<input type="checkbox" bind:checked={form.sync_enabled} />
							<span>Sync Enabled</span>
						</label>
					</div>
				</div>

				<!-- Limits -->
				<div class="form-section">
					<h4>Limits & Queue</h4>
					<div class="form-grid">
						<label>
							<span>Hourly Limit</span>
							<input type="number" bind:value={form.hourly_send_limit} />
						</label>
						<label>
							<span>Daily Limit</span>
							<input type="number" bind:value={form.daily_send_limit} />
						</label>
						<label>
							<span>Max Recipients/Message</span>
							<input type="number" bind:value={form.maximum_recipients_per_message} />
						</label>
						<label>
							<span>Critical Reserve/Hour</span>
							<input type="number" bind:value={form.reserve_critical_per_hour} />
						</label>
						<label>
							<span>Batch Size</span>
							<input type="number" bind:value={form.queue_batch_size} />
						</label>
						<label>
							<span>Min Delay (sec)</span>
							<input type="number" bind:value={form.minimum_delay_seconds} />
						</label>
					</div>
				</div>

				<!-- Defaults -->
				<div class="form-section">
					<h4>Default Purposes</h4>
					<div class="form-grid checkboxes">
						<label class="checkbox-label"><input type="checkbox" bind:checked={form.default_for_manual} /><span>Manual Email</span></label>
						<label class="checkbox-label"><input type="checkbox" bind:checked={form.default_for_transactional} /><span>Transactional</span></label>
						<label class="checkbox-label"><input type="checkbox" bind:checked={form.default_for_otp} /><span>OTP</span></label>
						<label class="checkbox-label"><input type="checkbox" bind:checked={form.default_for_broadcast} /><span>Broadcast</span></label>
						<label class="checkbox-label"><input type="checkbox" bind:checked={form.default_for_incoming} /><span>Incoming Sync</span></label>
					</div>
				</div>

				<!-- Notes -->
				<div class="form-section">
					<label>
						<span>Notes</span>
						<textarea bind:value={form.notes} rows="3" placeholder="Optional notes..."></textarea>
					</label>
				</div>
			</div>

			<div class="form-actions">
				<button class="glass-btn" on:click={() => showForm = false}>Cancel</button>
				<button class="glass-btn primary" on:click={saveAccount} disabled={saving || !form.account_name || !form.email_address}>
					{saving ? 'Saving...' : (editingAccount ? 'Update' : 'Create')}
				</button>
			</div>
		</div>
	{:else}
		<!-- Account List -->
		<div class="list-header">
			<h3>📱 Email Accounts</h3>
			<button class="glass-btn primary" on:click={openCreate}>+ Add Account</button>
		</div>

		{#if testResult}
			<div class="test-result" class:success={testResult.startsWith('✅')} class:error={testResult.startsWith('❌')}>
				{testResult}
				<button class="dismiss-btn" on:click={() => testResult = ''}>×</button>
			</div>
		{/if}

		<div class="accounts-table-container">
			<table class="accounts-table">
				<thead>
					<tr>
						<th>Account</th>
						<th>Email</th>
						<th>Provider</th>
						<th>Sending</th>
						<th>Receiving</th>
						<th>SMTP</th>
						<th>IMAP</th>
						<th>Usage</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
					{#each accounts as account}
						<tr>
							<td class="name-cell">{account.account_name}</td>
							<td>{account.email_address}</td>
							<td>{account.provider_name || '—'}</td>
							<td>
								<span class="badge" class:active={account.send_enabled} class:inactive={!account.send_enabled}>
									{account.send_enabled ? 'ON' : 'OFF'}
								</span>
							</td>
							<td>
								<span class="badge" class:active={account.sync_enabled} class:inactive={!account.sync_enabled}>
									{account.sync_enabled ? 'ON' : 'OFF'}
								</span>
							</td>
							<td>
								<span class="status-dot" class:ok={account.last_smtp_test_status === 'success'} class:fail={account.last_smtp_test_status === 'failed'}></span>
								{account.last_smtp_test_status || '—'}
							</td>
							<td>
								<span class="status-dot" class:ok={account.last_imap_test_status === 'success'} class:fail={account.last_imap_test_status === 'failed'}></span>
								{account.last_imap_test_status || '—'}
							</td>
							<td class="usage-cell">
								{account.sent_this_hour}/{account.hourly_send_limit}/hr
							</td>
							<td class="actions-cell">
								<button class="action-btn" on:click={() => openEdit(account)} title="Edit">✏️</button>
								<button class="action-btn" on:click={() => testBoth(account.id)} title="Test SMTP & IMAP" disabled={testing}>🔌</button>
								<button class="action-btn danger" on:click={() => deleteAccount(account.id)} title="Deactivate">🗑️</button>
							</td>
						</tr>
					{/each}
					{#if accounts.length === 0}
						<tr><td colspan="9" class="empty-cell">No email accounts configured. Click "+ Add Account" to get started.</td></tr>
					{/if}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<style>
	.email-accounts { padding: 20px; height: 100%; overflow-y: auto; background: #f8fafc; }
	.loading-container { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 300px; gap: 12px; color: #64748b; }
	.loading-spinner { width: 36px; height: 36px; border: 3px solid #e2e8f0; border-top-color: #f08300; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }

	.list-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.list-header h3 { font-size: 16px; font-weight: 600; color: #1e293b; }

	.test-result {
		padding: 10px 16px; border-radius: 8px; margin-bottom: 12px; font-size: 13px;
		display: flex; justify-content: space-between; align-items: center;
	}
	.test-result.success { background: #dcfce7; color: #166534; border: 1px solid #bbf7d0; }
	.test-result.error { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; }
	.dismiss-btn { background: none; border: none; font-size: 18px; cursor: pointer; opacity: 0.6; }

	.accounts-table-container { overflow-x: auto; }
	.accounts-table {
		width: 100%; border-collapse: collapse; background: white; border-radius: 10px;
		overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,0.06);
	}
	.accounts-table th { padding: 10px 12px; text-align: left; font-size: 12px; font-weight: 600; color: #64748b; background: #f8fafc; border-bottom: 1px solid #e2e8f0; }
	.accounts-table td { padding: 10px 12px; font-size: 13px; color: #334155; border-bottom: 1px solid #f1f5f9; }
	.name-cell { font-weight: 600; }
	.usage-cell { font-size: 12px; color: #64748b; }
	.empty-cell { text-align: center; color: #94a3b8; padding: 40px !important; }

	.badge { font-size: 11px; padding: 2px 8px; border-radius: 4px; font-weight: 500; }
	.badge.active { background: #dcfce7; color: #166534; }
	.badge.inactive { background: #f1f5f9; color: #64748b; }

	.status-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 4px; background: #cbd5e1; }
	.status-dot.ok { background: #22c55e; }
	.status-dot.fail { background: #ef4444; }

	.actions-cell { white-space: nowrap; }
	.action-btn { background: none; border: none; cursor: pointer; padding: 4px; font-size: 14px; border-radius: 4px; }
	.action-btn:hover { background: #f1f5f9; }
	.action-btn.danger:hover { background: #fee2e2; }
	.action-btn:disabled { opacity: 0.4; cursor: not-allowed; }

	/* Form Styles */
	.form-container { max-width: 800px; }
	.form-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
	.form-header h3 { font-size: 16px; font-weight: 600; color: #1e293b; }
	.form-sections { display: flex; flex-direction: column; gap: 20px; }
	.form-section { background: white; padding: 16px; border-radius: 10px; border: 1px solid #e2e8f0; }
	.form-section h4 { font-size: 14px; font-weight: 600; color: #334155; margin-bottom: 12px; }
	.form-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 12px; }
	.form-grid.checkboxes { grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); }
	.form-section label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; color: #64748b; }
	.form-section label span { font-weight: 500; }
	.form-section input[type="text"], .form-section input[type="email"], .form-section input[type="number"], .form-section input[type="password"], .form-section select, .form-section textarea {
		padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: 6px; font-size: 13px;
		background: #f8fafc; transition: border-color 0.15s;
	}
	.form-section input:focus, .form-section select:focus, .form-section textarea:focus { border-color: #f08300; outline: none; }
	.checkbox-label { flex-direction: row !important; align-items: center; gap: 8px !important; }
	.checkbox-label input[type="checkbox"] { width: 16px; height: 16px; }
	.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; }

	.glass-btn {
		padding: 8px 18px; border-radius: 8px; font-size: 13px; font-weight: 500;
		border: 1px solid rgba(255,255,255,0.3); cursor: pointer;
		background: rgba(255,255,255,0.7); backdrop-filter: blur(8px);
		box-shadow: 0 2px 8px rgba(0,0,0,0.06); transition: all 0.15s; color: #334155;
	}
	.glass-btn:hover { background: rgba(255,255,255,0.9); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
	.glass-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.glass-btn.primary { background: rgba(240,131,0,0.1); border-color: rgba(240,131,0,0.3); color: #c2410c; }
	.glass-btn.primary:hover { background: rgba(240,131,0,0.2); }
</style>
