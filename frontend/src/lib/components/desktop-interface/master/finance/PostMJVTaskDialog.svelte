<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	export let branchId: number;
	export let payload: any;
	const dispatch = createEventDispatcher();
	let defaultUser: any = null;
	let loading = true;
	let posting = false;
	let error = '';
	onMount(async () => {
		const { data: defaults, error: defaultsError } = await supabase.from('branch_default_positions').select('entry_task_user_id').eq('branch_id', branchId).maybeSingle();
		if (defaultsError) error = defaultsError.message;
		else if (!defaults?.entry_task_user_id) error = 'No default Entry Task User is configured for this branch.';
		else {
			const { data: employee, error: employeeError } = await supabase.from('hr_employee_master').select('user_id,name_en,name_ar').eq('user_id', defaults.entry_task_user_id).eq('current_branch_id', branchId).eq('is_removed', false).maybeSingle();
			if (employeeError) error = employeeError.message;
			else if (!employee) error = 'The default Entry Task User is not active in this branch.';
			else defaultUser = employee;
		}
		loading = false;
	});

	async function postTask() {
		if (!defaultUser) return;
		posting = true; error = '';
		try {
			const response = await fetch('/api/assistant-tasks', {
				method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ task_type: 'cash_closing_mjv', branch_id: branchId, payload })
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Task creation failed');
			dispatch('posted');
		} catch (postError: any) {
			error = postError.message || 'Task creation failed';
		} finally {
			posting = false;
		}
	}
</script>

<div class="overlay" role="presentation" on:click={() => dispatch('close')}>
	<div class="dialog" role="dialog" aria-modal="true" on:click|stopPropagation>
		<h3>Post Cash Closing MJV Task</h3>
		<p>The task will be assigned automatically to the branch's Default Entry Task User.</p>
		<div class="users">
			{#if loading}<div class="empty">Loading default user...</div>{:else if defaultUser}<div class="default-user"><b>{defaultUser.name_en || defaultUser.name_ar}</b>{#if defaultUser.name_ar && defaultUser.name_ar !== defaultUser.name_en}<small>{defaultUser.name_ar}</small>{/if}</div>{/if}
		</div>
		{#if error}<div class="error">{error}</div>{/if}
		<div class="actions"><button on:click={() => dispatch('close')}>Cancel</button><button class="post" disabled={!defaultUser || posting} on:click={postTask}>{posting ? 'Posting...' : 'Post Task'}</button></div>
	</div>
</div>

<style>
	.overlay{position:fixed;inset:0;background:#0b365580;display:flex;align-items:center;justify-content:center;z-index:10000}.dialog{width:480px;max-height:75vh;background:white;border-radius:10px;padding:18px;box-shadow:0 18px 55px #0004;color:#0b3655}h3,p{margin:0 0 10px}.users{overflow:hidden;margin:10px 0;border:1px solid #d6e3eb;border-radius:6px}.default-user{display:flex;justify-content:space-between;padding:12px;background:#dff7fa;color:#08788c}.users small{color:#668395}.actions{display:flex;justify-content:flex-end;gap:8px}.actions button{border:0;border-radius:6px;padding:9px 15px;cursor:pointer}.actions .post{background:#12839c;color:white;font-weight:700}.actions .post:disabled{opacity:.5}.error{color:#b42318;margin:8px 0}.empty{padding:20px;text-align:center;color:#71899a}
</style>
