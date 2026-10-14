<script>
	import { onMount } from 'svelte';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';

	let tasks = [];
	let loading = true;
	let error = '';
	let message = '';
	let deletingId = '';

	async function loadTasks() {
		loading = true;
		error = '';
		try {
			const response = await authenticatedFetch('/api/assistant-tasks?manage_ai_tasks=1', {
				headers: { 'x-aqura-interface': 'desktop' }
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to load AI tasks.');
			tasks = result.tasks || [];
		} catch (loadError) {
			error = loadError.message || 'Unable to load AI tasks.';
		} finally {
			loading = false;
		}
	}

	async function deleteTask(task) {
		if (deletingId || !confirm(`Delete “${task.title}”? The assigned AI Assistant will no longer be able to post it.`)) return;
		deletingId = task.id;
		error = '';
		message = '';
		try {
			const response = await authenticatedFetch('/api/assistant-tasks', {
				method: 'DELETE',
				headers: { 'Content-Type': 'application/json', 'x-aqura-interface': 'desktop' },
				body: JSON.stringify({ id: task.id })
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to delete the AI task.');
			tasks = tasks.filter((item) => item.id !== task.id);
			message = 'AI task deleted.';
		} catch (deleteError) {
			error = deleteError.message || 'Unable to delete the AI task.';
		} finally {
			deletingId = '';
		}
	}

	function formatDate(value) {
		if (!value) return '—';
		return new Date(value).toLocaleString('en-GB');
	}

	function typeLabel(value) {
		return String(value || '').replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
	}

	onMount(loadTasks);
</script>

<section class="h-full overflow-auto bg-slate-50 p-4 text-slate-800">
	<div class="mb-4 flex items-center justify-between gap-3">
		<div>
			<h1 class="text-lg font-semibold">AI Agent Tasks</h1>
			<p class="text-xs text-slate-500">Pending and failed tasks waiting for an Aqura AI Assistant user.</p>
		</div>
		<button type="button" on:click={loadTasks} disabled={loading || !!deletingId} class="rounded border border-slate-300 bg-white px-3 py-2 text-sm disabled:opacity-50">
			{loading ? 'Loading…' : 'Refresh'}
		</button>
	</div>

	{#if error}<p role="alert" class="mb-3 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>{/if}
	{#if message}<p role="status" class="mb-3 rounded border border-green-200 bg-green-50 px-3 py-2 text-sm text-green-700">{message}</p>{/if}

	<div class="overflow-x-auto rounded border border-slate-200 bg-white">
		<table class="w-full text-left text-sm">
			<thead class="bg-slate-100 text-xs text-slate-600">
				<tr><th>Task</th><th>Type</th><th>Branch</th><th>Assigned user</th><th>Status</th><th>Created</th><th class="text-center">Action</th></tr>
			</thead>
			<tbody>
				{#each tasks as task (task.id)}
					<tr class="border-t border-slate-200">
						<td><span class="block font-medium">{task.title}</span>{#if task.payload?.entry}<span class="text-xs text-slate-500">{task.payload.entry}</span>{/if}</td>
						<td>{typeLabel(task.task_type)}</td>
						<td>{task.branch_name}</td>
						<td>{task.assigned_to_name}</td>
						<td><span class="rounded px-2 py-1 text-xs {task.status === 'failed' ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'}">{task.status}</span></td>
						<td class="whitespace-nowrap">{formatDate(task.created_at)}</td>
						<td class="text-center"><button type="button" on:click={() => deleteTask(task)} disabled={!!deletingId} class="rounded border border-red-300 px-2 py-1 text-xs text-red-700 disabled:opacity-50">{deletingId === task.id ? 'Deleting…' : 'Delete'}</button></td>
					</tr>
				{:else}
					<tr><td colspan="7" class="px-4 py-10 text-center text-slate-500">No pending or failed AI tasks.</td></tr>
				{/each}
			</tbody>
		</table>
	</div>
</section>

<style>
	th, td { padding: 0.65rem 0.75rem; vertical-align: top; }
</style>
