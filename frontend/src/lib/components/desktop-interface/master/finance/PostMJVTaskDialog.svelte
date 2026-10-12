<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	export let branchId: number;
	export let payload: any;
	const dispatch = createEventDispatcher();
	let users: any[] = [];
	let search = '';
	let selectedUser = '';
	let loading = true;
	let posting = false;
	let error = '';
	$: filtered = users.filter((u) => `${u.name_en || ''} ${u.name_ar || ''}`.toLowerCase().includes(search.toLowerCase()));

	onMount(async () => {
		const { data, error: loadError } = await supabase.from('hr_employee_master').select('user_id,name_en,name_ar').eq('current_branch_id', branchId).not('user_id', 'is', null).order('name_en');
		if (loadError) error = loadError.message;
		else users = data || [];
		loading = false;
	});

	async function postTask() {
		if (!selectedUser) return;
		posting = true; error = '';
		try {
			const response = await fetch('/api/assistant-tasks', {
				method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ task_type: 'cash_closing_mjv', branch_id: branchId, assigned_to: selectedUser, payload })
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
		<p>Select an Aqura user from this branch.</p>
		<input bind:value={search} placeholder="Search user..." />
		<div class="users">
			{#if loading}<div class="empty">Loading users...</div>{:else}{#each filtered as user}<button class:selected={selectedUser === user.user_id} on:click={() => selectedUser = user.user_id}><b>{user.name_en || user.name_ar}</b>{#if user.name_ar && user.name_ar !== user.name_en}<small>{user.name_ar}</small>{/if}</button>{/each}{/if}
		</div>
		{#if error}<div class="error">{error}</div>{/if}
		<div class="actions"><button on:click={() => dispatch('close')}>Cancel</button><button class="post" disabled={!selectedUser || posting} on:click={postTask}>{posting ? 'Posting...' : 'Post Task'}</button></div>
	</div>
</div>

<style>
	.overlay{position:fixed;inset:0;background:#0b365580;display:flex;align-items:center;justify-content:center;z-index:10000}.dialog{width:480px;max-height:75vh;background:white;border-radius:10px;padding:18px;box-shadow:0 18px 55px #0004;color:#0b3655}h3,p{margin:0 0 10px}input{width:100%;height:38px;box-sizing:border-box;border:1px solid #b9cfdd;border-radius:6px;padding:0 10px}.users{max-height:300px;overflow:auto;margin:10px 0;border:1px solid #d6e3eb;border-radius:6px}.users button{width:100%;display:flex;justify-content:space-between;border:0;border-bottom:1px solid #e7eef2;background:white;padding:10px;text-align:left;cursor:pointer}.users button.selected{background:#dff7fa;color:#08788c}.users small{color:#668395}.actions{display:flex;justify-content:flex-end;gap:8px}.actions button{border:0;border-radius:6px;padding:9px 15px;cursor:pointer}.actions .post{background:#12839c;color:white;font-weight:700}.actions .post:disabled{opacity:.5}.error{color:#b42318;margin:8px 0}.empty{padding:20px;text-align:center;color:#71899a}
</style>
