<script>
	import { onMount } from 'svelte';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';

	let requests = [];
	let loading = true;
	let deletingId = '';
	let selectedIds = [];
	let error = '';
	let message = '';

	const typeLabels = {
		pos_reconciliation: 'Cashier / POS reconciliation',
		receiving_bank_slip: 'Receiving Records bank slip',
		pay_to_credit_slip: 'Pay to Credit bank slip'
	};

	async function loadRequests() {
		loading = true;
		error = '';
		try {
			const response = await authenticatedFetch('/api/pending-scan-requests', {
				headers: { 'x-aqura-interface': 'desktop' }
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to load pending scan requests.');
			requests = result.requests || [];
			selectedIds = selectedIds.filter((id) => requests.some((item) => item.id === id));
		} catch (loadError) {
			error = loadError?.message || 'Unable to load pending scan requests.';
		} finally {
			loading = false;
		}
	}

	async function deleteRequest(item) {
		if (deletingId || !confirm(`Delete this pending scan request?\n\n${typeLabels[item.request_type] || item.request_type}\n${item.request_label || ''}\n\nThe request will disappear from the user's mobile screen.`)) return;
		await deleteRequests([item.id], item.id);
	}

	async function deleteSelected() {
		if (deletingId || !selectedIds.length || !confirm(`Delete ${selectedIds.length} selected pending scan request${selectedIds.length === 1 ? '' : 's'}?\n\nThe requests will disappear from the users' mobile screens.`)) return;
		await deleteRequests(selectedIds, 'bulk');
	}

	async function deleteRequests(ids, progressId) {
		deletingId = progressId;
		error = '';
		message = '';
		try {
			const response = await authenticatedFetch('/api/pending-scan-requests', {
				method: 'DELETE',
				headers: { 'Content-Type': 'application/json', 'x-aqura-interface': 'desktop' },
				body: JSON.stringify({ ids })
			});
			const result = await response.json();
			if (!response.ok || !result.success) throw new Error(result.error || 'Unable to delete the scan request.');
			const deletedIds = result.ids || [];
			requests = requests.filter((request) => !deletedIds.includes(request.id));
			selectedIds = selectedIds.filter((id) => !deletedIds.includes(id));
			message = `${result.deleted_count || deletedIds.length} pending scan request${(result.deleted_count || deletedIds.length) === 1 ? '' : 's'} deleted.`;
		} catch (deleteError) {
			error = deleteError?.message || 'Unable to delete the scan request.';
		} finally {
			deletingId = '';
		}
	}

	function toggleSelection(id) {
		selectedIds = selectedIds.includes(id) ? selectedIds.filter((item) => item !== id) : [...selectedIds, id];
	}

	function toggleAll() {
		selectedIds = selectedIds.length === requests.length && requests.length
			? []
			: requests.map((item) => item.id);
	}

	function formatDate(value) {
		if (!value) return '—';
		return new Date(value).toLocaleString('en-GB');
	}

	function details(item) {
		const parts = [];
		if (item.request_label) parts.push(item.request_label);
		if (item.box_number != null) parts.push(`Box ${item.box_number}`);
		if (item.pos_number != null) parts.push(`POS ${item.pos_number}`);
		if (item.receiving_record_id) parts.push(`Receiving record ${item.receiving_record_id}`);
		return parts.join(' · ') || '—';
	}

	$: counts = {
		pos_reconciliation: requests.filter((item) => item.request_type === 'pos_reconciliation').length,
		receiving_bank_slip: requests.filter((item) => item.request_type === 'receiving_bank_slip').length,
		pay_to_credit_slip: requests.filter((item) => item.request_type === 'pay_to_credit_slip').length
	};

	onMount(loadRequests);
</script>

<section class="h-full overflow-auto bg-slate-50 p-4 text-slate-800">
	<div class="mb-4 flex items-start justify-between gap-3">
		<div>
			<h1 class="text-lg font-semibold">Pending Scan Requests</h1>
			<p class="text-xs text-slate-500">All pending mobile scan requests across users and branches. Master Admin only.</p>
		</div>
		<div class="flex items-center gap-2">
			{#if selectedIds.length}
				<span class="text-xs font-medium text-slate-600">{selectedIds.length} selected</span>
				<button type="button" on:click={deleteSelected} disabled={!!deletingId} class="rounded border border-red-300 bg-red-50 px-3 py-2 text-sm font-medium text-red-700 hover:bg-red-100 disabled:opacity-50">
					{deletingId === 'bulk' ? 'Deleting…' : 'Delete Selected'}
				</button>
			{/if}
			<button type="button" on:click={loadRequests} disabled={loading || !!deletingId} class="rounded border border-slate-300 bg-white px-3 py-2 text-sm disabled:opacity-50">
				{loading ? 'Loading…' : 'Refresh'}
			</button>
		</div>
	</div>

	<div class="mb-4 grid grid-cols-1 gap-2 sm:grid-cols-4">
		<div class="rounded border border-slate-200 bg-white p-3"><span class="block text-xs text-slate-500">All pending</span><strong class="text-lg">{requests.length}</strong></div>
		<div class="rounded border border-slate-200 bg-white p-3"><span class="block text-xs text-slate-500">POS reconciliation</span><strong class="text-lg">{counts.pos_reconciliation}</strong></div>
		<div class="rounded border border-slate-200 bg-white p-3"><span class="block text-xs text-slate-500">Receiving slips</span><strong class="text-lg">{counts.receiving_bank_slip}</strong></div>
		<div class="rounded border border-slate-200 bg-white p-3"><span class="block text-xs text-slate-500">Pay to Credit slips</span><strong class="text-lg">{counts.pay_to_credit_slip}</strong></div>
	</div>

	{#if error}<p role="alert" class="mb-3 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>{/if}
	{#if message}<p role="status" class="mb-3 rounded border border-green-200 bg-green-50 px-3 py-2 text-sm text-green-700">{message}</p>{/if}

	<div class="overflow-x-auto rounded border border-slate-200 bg-white">
		<table class="w-full text-left text-sm">
			<thead class="bg-slate-100 text-xs text-slate-600">
				<tr><th class="w-10 text-center"><input type="checkbox" aria-label="Select all pending scan requests" checked={requests.length > 0 && selectedIds.length === requests.length} on:change={toggleAll} /></th><th>Request type</th><th>Details</th><th>Branch</th><th>Requested by</th><th>Account</th><th>Created</th><th class="text-center">Action</th></tr>
			</thead>
			<tbody>
				{#each requests as item (item.id)}
					<tr class="border-t border-slate-200">
						<td class="text-center"><input type="checkbox" aria-label={`Select ${typeLabels[item.request_type] || item.request_type}`} checked={selectedIds.includes(item.id)} on:change={() => toggleSelection(item.id)} /></td>
						<td><span class="rounded bg-amber-100 px-2 py-1 text-xs font-medium text-amber-800">{typeLabels[item.request_type] || item.request_type}</span></td>
						<td class="max-w-md"><span class="block font-medium">{details(item)}</span><span class="text-[11px] text-slate-400">{item.id}</span></td>
						<td>{item.branch_name}</td>
						<td>{item.requester_name}</td>
						<td>{item.payment_account_type ? item.payment_account_type.replaceAll('_', ' ') : '—'}</td>
						<td class="whitespace-nowrap">{formatDate(item.created_at)}</td>
						<td class="text-center"><button type="button" on:click={() => deleteRequest(item)} disabled={!!deletingId} class="rounded border border-red-300 bg-white px-2 py-1 text-xs font-medium text-red-700 hover:bg-red-50 disabled:opacity-50">{deletingId === item.id ? 'Deleting…' : 'Delete'}</button></td>
					</tr>
				{:else}
					<tr><td colspan="8" class="px-4 py-10 text-center text-slate-500">No pending scan requests.</td></tr>
				{/each}
			</tbody>
		</table>
	</div>
</section>

<style>
	th, td { padding: 0.65rem 0.75rem; vertical-align: top; }
</style>
