<script lang="ts">
	import { onMount } from 'svelte';

	type Row = {
		id: string; request_number: string; requested_at: string; total_amount: number; status: string;
		cashier: { name_en?: string; name_ar?: string }; receiver: { name_en?: string; name_ar?: string };
		branch: { name_en?: string; name_ar?: string } | null;
	};
	let rows: Row[] = [];
	let loading = true;
	let error = '';
	let selected: Row | null = null;
	let action: 'complete' | 'cancel' = 'cancel';
	let reason = '';
	let saving = false;

	async function load() {
		loading = true; error = '';
		try {
			const response = await fetch('/api/finance/change-requests', { cache: 'no-store' });
			const result = await response.json();
			if (!response.ok) throw new Error(result.error || 'Could not load requests.');
			rows = result.requests || [];
		} catch (cause) { error = cause instanceof Error ? cause.message : 'Could not load requests.'; }
		finally { loading = false; }
	}

	function name(value: Row['cashier']) { return value?.name_en || value?.name_ar || '—'; }
	function date(value: string) { return new Date(value).toLocaleString('en-GB', { timeZone: 'Asia/Riyadh' }); }
	function choose(row: Row, nextAction: 'complete' | 'cancel') {
		selected = row; action = nextAction; reason = ''; error = '';
	}
	async function resolveRequest() {
		if (!selected || reason.trim().length < 5) { error = 'Enter a reason of at least 5 characters.'; return; }
		const verb = action === 'complete' ? 'force-complete' : 'cancel';
		if (!confirm(`Are you sure you want to ${verb} request ${selected.request_number}?`)) return;
		saving = true; error = '';
		try {
			const response = await fetch('/api/finance/change-requests', {
				method: 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ requestId: selected.id, action, reason: reason.trim() })
			});
			const result = await response.json();
			if (!response.ok) throw new Error(result.error || 'Could not update request.');
			selected = null; reason = ''; await load();
		} catch (cause) { error = cause instanceof Error ? cause.message : 'Could not update request.'; }
		finally { saving = false; }
	}

	onMount(load);
</script>

<div class="page">
	<header><div><h2>Change Requests</h2><p>Resolve pending and non-completed Aqura POS cashier requests.</p></div><button on:click={load} disabled={loading}>Refresh</button></header>
	{#if error}<div class="error" role="alert">{error}</div>{/if}
	{#if loading}<p class="empty">Loading…</p>
	{:else if !rows.length}<p class="empty">No pending or non-completed requests.</p>
	{:else}
		<div class="table-wrap"><table>
			<thead><tr><th>Request</th><th>Date</th><th>Branch</th><th>Cashier</th><th>Receiver</th><th>Amount</th><th>Status</th><th>Actions</th></tr></thead>
			<tbody>{#each rows as row (row.id)}<tr>
				<td><strong>{row.request_number}</strong></td><td>{date(row.requested_at)}</td><td>{row.branch?.name_en || row.branch?.name_ar || '—'}</td>
				<td>{name(row.cashier)}</td><td>{name(row.receiver)}</td><td>{Number(row.total_amount).toFixed(2)} SAR</td><td><span class="status">{row.status}</span></td>
				<td class="actions"><button class="complete" on:click={() => choose(row, 'complete')}>Force Complete</button><button class="cancel" on:click={() => choose(row, 'cancel')}>Cancel</button></td>
			</tr>{/each}</tbody>
		</table></div>
	{/if}

	{#if selected}
		<div class="backdrop" role="presentation" on:click={() => !saving && (selected = null)}>
			<section class="dialog" role="dialog" aria-modal="true" on:click|stopPropagation>
				<h3>{action === 'complete' ? 'Force Complete' : 'Cancel'} Request {selected.request_number}</h3>
				<p>This administrative action is permanent and will be recorded in the audit log.</p>
				<label for="resolution-reason">Reason</label><textarea id="resolution-reason" bind:value={reason} maxlength="1000" rows="4" placeholder="Enter the reason (required)"></textarea>
				<div class="dialog-actions"><button on:click={() => selected = null} disabled={saving}>Back</button><button class:cancel={action === 'cancel'} class:complete={action === 'complete'} on:click={resolveRequest} disabled={saving || reason.trim().length < 5}>{saving ? 'Saving…' : 'Confirm'}</button></div>
			</section>
		</div>
	{/if}
</div>

<style>
	.page{padding:22px;height:100%;overflow:auto;background:#f8fafc;color:#1e293b;font-family:Segoe UI,sans-serif}header{display:flex;justify-content:space-between;align-items:center;margin-bottom:18px}h2{margin:0 0 4px;font-size:24px}p{margin:0;color:#64748b}button{border:0;border-radius:7px;padding:8px 13px;font-weight:600;cursor:pointer}header button{background:#2563eb;color:white}.table-wrap{overflow:auto;background:white;border:1px solid #e2e8f0;border-radius:10px}table{width:100%;border-collapse:collapse;min-width:1000px}th,td{text-align:left;padding:11px;border-bottom:1px solid #e2e8f0;font-size:13px}th{background:#f1f5f9;color:#475569}.status{padding:4px 8px;border-radius:999px;background:#fef3c7;color:#92400e;white-space:nowrap}.actions{display:flex;gap:7px}.complete{background:#059669;color:white}.cancel{background:#dc2626;color:white}.empty{padding:35px;text-align:center}.error{background:#fee2e2;color:#991b1b;padding:10px 12px;border-radius:8px;margin-bottom:12px}.backdrop{position:fixed;inset:0;background:#0f172a99;display:grid;place-items:center;z-index:10000}.dialog{width:min(480px,calc(100vw - 32px));background:white;border-radius:12px;padding:22px;box-shadow:0 24px 70px #0004}.dialog h3{margin:0 0 8px}.dialog label{display:block;font-weight:700;margin:18px 0 6px}.dialog textarea{width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:8px;padding:10px;resize:vertical}.dialog-actions{display:flex;justify-content:flex-end;gap:8px;margin-top:16px}.dialog-actions button:first-child{background:#e2e8f0;color:#334155}button:disabled{opacity:.55;cursor:not-allowed}
</style>
