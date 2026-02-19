<script lang="ts">
	import { onMount, tick } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { currentLocale } from '$lib/i18n';
	import { initiateCall, sendTextMessage } from '$lib/stores/callStore';

	let employees: any[] = [];
	let searchQuery = '';
	let loading = true;

	// Text input state
	let textTarget: any = null;
	let textValue = '';
	let textRef: HTMLTextAreaElement;

	$: filteredEmployees = searchQuery.trim()
		? employees.filter(e =>
			(e.name_en || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
			(e.name_ar || '').includes(searchQuery)
		)
		: employees;

	onMount(async () => {
		await loadEmployees();
	});

	async function loadEmployees() {
		loading = true;
		try {
			const { data, error } = await supabase
				.from('hr_employee_master')
				.select('id, user_id, name_en, name_ar, employment_status')
				.in('employment_status', ['Job (With Finger)', 'Job (No Finger)', 'Remote Job'])
				.order('name_en', { ascending: true });
			if (error) throw error;
			employees = data || [];
		} catch (err) {
			console.error('Failed to load employees:', err);
		} finally {
			loading = false;
		}
	}

	function handleCall(employee: any) {
		if (!employee.user_id) return;
		const caller = $currentUser;
		const callerName = caller?.employeeName || caller?.username || 'Someone';
		const callerEmp = employees.find(e => e.user_id === caller?.id);
		const callerNameAr = callerEmp?.name_ar || '';
		initiateCall({
			targetUserId: employee.user_id,
			targetName: employee.name_en || employee.name_ar || 'Employee',
			targetNameAr: employee.name_ar || '',
			callerName,
			callerNameAr
		});
	}

	async function handleText(employee: any) {
		if (!employee.user_id) return;
		textTarget = employee;
		textValue = '';
		await tick();
		textRef?.focus();
	}

	function sendText() {
		if (!textValue.trim() || !textTarget?.user_id) return;
		const caller = $currentUser;
		const senderName = caller?.employeeName || caller?.username || 'Someone';
		const senderEmp = employees.find(e => e.user_id === caller?.id);
		const senderNameAr = senderEmp?.name_ar || '';
		sendTextMessage({
			targetUserId: textTarget.user_id,
			targetName: textTarget.name_en || textTarget.name_ar || 'Employee',
			targetNameAr: textTarget.name_ar || '',
			senderName,
			senderNameAr,
			message: textValue.trim()
		});
		textTarget = null;
		textValue = '';
	}

	function cancelText() {
		textTarget = null;
		textValue = '';
	}
</script>

<div class="comm-page">
	<!-- Search bar -->
	<div class="comm-search-bar">
		<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="2">
			<circle cx="11" cy="11" r="8"/>
			<path d="M21 21l-4.35-4.35"/>
		</svg>
		<input
			type="text"
			class="comm-search-input"
			placeholder={$currentLocale === 'ar' ? 'بحث عن موظف...' : 'Search employee...'}
			bind:value={searchQuery}
		/>
		{#if searchQuery}
			<button class="comm-search-clear" on:click={() => searchQuery = ''} aria-label="Clear search">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="2">
					<path d="M18 6L6 18M6 6l12 12"/>
				</svg>
			</button>
		{/if}
	</div>

	<!-- Employee list -->
	<div class="comm-list">
		{#if loading}
			<div class="comm-empty">
				<div class="comm-spinner"></div>
				<span>{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading employees...'}</span>
			</div>
		{:else if filteredEmployees.length === 0}
			<div class="comm-empty">
				<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#D1D5DB" stroke-width="1.5">
					<circle cx="11" cy="11" r="8"/>
					<path d="M21 21l-4.35-4.35"/>
				</svg>
				<span>{$currentLocale === 'ar' ? 'لم يتم العثور على موظفين' : 'No employees found'}</span>
			</div>
		{:else}
			{#each filteredEmployees as emp (emp.id)}
				<div class="comm-card">
					<div class="comm-card-info">
						<div class="comm-avatar">
							{(emp.name_en || emp.name_ar || '?')[0].toUpperCase()}
						</div>
						<div class="comm-name-col">
							<span class="comm-name-en">{emp.name_en || '—'}</span>
							{#if emp.name_ar}
								<span class="comm-name-ar">{emp.name_ar}</span>
							{/if}
						</div>
					</div>
					<div class="comm-actions">
						<button class="comm-btn comm-btn-call" on:click={() => handleCall(emp)} title={$currentLocale === 'ar' ? 'اتصال' : 'Call'} disabled={!emp.user_id}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" stroke="none">
								<path d="M20.01 15.38c-1.23 0-2.42-.2-3.53-.56a.977.977 0 0 0-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z"/>
							</svg>
						</button>
						<button class="comm-btn comm-btn-msg" on:click={() => handleText(emp)} title={$currentLocale === 'ar' ? 'رسالة' : 'Message'} disabled={!emp.user_id}>
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
							</svg>
						</button>
					</div>

					<!-- Inline text input for this employee -->
					{#if textTarget?.id === emp.id}
						<div class="comm-text-input-area">
							<textarea
								bind:this={textRef}
								bind:value={textValue}
								class="comm-textarea"
								placeholder={$currentLocale === 'ar' ? 'اكتب رسالتك...' : 'Type your message...'}
								rows="2"
							></textarea>
							<div class="comm-text-btns">
								<button class="comm-text-cancel" on:click={cancelText}>
									{$currentLocale === 'ar' ? 'إلغاء' : 'Cancel'}
								</button>
								<button class="comm-text-send" on:click={sendText} disabled={!textValue.trim()}>
									<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" stroke="none">
										<path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/>
									</svg>
									{$currentLocale === 'ar' ? 'إرسال' : 'Send'}
								</button>
							</div>
						</div>
					{/if}
				</div>
			{/each}
		{/if}
	</div>
</div>

<style>
	.comm-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #F8FAFC;
		padding: 12px;
		gap: 12px;
		overflow: hidden;
	}

	/* ── Search bar ── */
	.comm-search-bar {
		display: flex;
		align-items: center;
		gap: 10px;
		background: #fff;
		border: 1px solid #E5E7EB;
		border-radius: 12px;
		padding: 10px 14px;
		flex-shrink: 0;
	}
	.comm-search-input {
		flex: 1;
		border: none;
		outline: none;
		font-size: 15px;
		color: #374151;
		background: transparent;
	}
	.comm-search-input::placeholder { color: #9CA3AF; }
	.comm-search-clear {
		background: none; border: none; cursor: pointer;
		padding: 4px; border-radius: 6px;
		display: flex; align-items: center; justify-content: center;
	}
	.comm-search-clear:active { background: #F3F4F6; }

	/* ── Employee list ── */
	.comm-list {
		flex: 1;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 8px;
		padding-bottom: 20px;
		-webkit-overflow-scrolling: touch;
	}

	.comm-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 12px;
		padding: 48px 16px;
		color: #9CA3AF;
		font-size: 14px;
	}
	.comm-spinner {
		width: 28px; height: 28px;
		border: 3px solid #E5E7EB;
		border-top-color: #3B82F6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	/* ── Employee card ── */
	.comm-card {
		background: #fff;
		border: 1px solid #E5E7EB;
		border-radius: 12px;
		padding: 12px 14px;
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: 10px;
	}
	.comm-card-info {
		display: flex;
		align-items: center;
		gap: 10px;
		flex: 1;
		min-width: 0;
	}
	.comm-avatar {
		width: 38px; height: 38px;
		border-radius: 50%;
		background: linear-gradient(135deg, #6366F1, #8B5CF6);
		color: #fff;
		font-size: 15px;
		font-weight: 700;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}
	.comm-name-col {
		display: flex;
		flex-direction: column;
		gap: 1px;
		min-width: 0;
	}
	.comm-name-en {
		font-size: 14px;
		font-weight: 600;
		color: #1F2937;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.comm-name-ar {
		font-size: 12px;
		color: #6B7280;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* ── Action buttons ── */
	.comm-actions {
		display: flex;
		gap: 8px;
		flex-shrink: 0;
	}
	.comm-btn {
		width: 40px; height: 40px;
		border-radius: 50%;
		border: none;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: transform 0.12s, opacity 0.15s;
	}
	.comm-btn:active { transform: scale(0.9); }
	.comm-btn:disabled { opacity: 0.3; cursor: not-allowed; }
	.comm-btn-call {
		background: #ECFDF5;
		color: #10B981;
	}
	.comm-btn-call:active:not(:disabled) { background: #D1FAE5; }
	.comm-btn-msg {
		background: #EFF6FF;
		color: #3B82F6;
	}
	.comm-btn-msg:active:not(:disabled) { background: #DBEAFE; }

	/* ── Inline text input ── */
	.comm-text-input-area {
		width: 100%;
		margin-top: 8px;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.comm-textarea {
		width: 100%;
		padding: 10px 12px;
		border: 1px solid #D1D5DB;
		border-radius: 10px;
		font-size: 14px;
		color: #374151;
		resize: none;
		font-family: inherit;
		outline: none;
		min-height: 56px;
		background: #F9FAFB;
	}
	.comm-textarea:focus {
		border-color: #3B82F6;
		box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.15);
		background: #fff;
	}
	.comm-textarea::placeholder { color: #9CA3AF; }
	.comm-text-btns {
		display: flex;
		justify-content: flex-end;
		gap: 8px;
	}
	.comm-text-cancel {
		padding: 7px 14px;
		border: 1px solid #D1D5DB;
		background: #fff;
		color: #374151;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 500;
		cursor: pointer;
	}
	.comm-text-cancel:active { background: #F3F4F6; }
	.comm-text-send {
		padding: 7px 14px;
		border: none;
		background: #3B82F6;
		color: #fff;
		border-radius: 8px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
	}
	.comm-text-send:active:not(:disabled) { background: #2563EB; }
	.comm-text-send:disabled { opacity: 0.4; cursor: not-allowed; }
</style>
