<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';

	type Branch = { id: number; name_en: string; location_en?: string | null };
	type Ledger = { ledgerId: number; ledgerName: string; groupName: string };
	type Mapping = {
		id: string;
		source_branch_id: number;
		source_branch_name: string;
		target_branch_id: number;
		target_branch_name: string;
		target_ledger_id: number;
		target_ledger_name: string;
	};

	let branches: Branch[] = [];
	let mappings: Mapping[] = [];
	let loading = true;
	let errorMessage = '';
	let showEntry = false;
	let sourceBranchId = '';
	let targetBranchId = '';
	let ledgers: Ledger[] = [];
	let ledgerSearch = '';
	let selectedLedgerId: number | null = null;
	let loadingLedgers = false;
	let saving = false;
	let removingId = '';

	$: filteredLedgers = ledgers.filter((ledger) => {
		const search = ledgerSearch.trim().toLowerCase();
		return !search
			|| ledger.ledgerName.toLowerCase().includes(search)
			|| ledger.groupName.toLowerCase().includes(search)
			|| String(ledger.ledgerId).includes(search);
	});

	onMount(loadPage);

	async function loadPage() {
		loading = true;
		errorMessage = '';
		const [branchResult, mappingResult] = await Promise.all([
			supabase.from('branches').select('id, name_en, location_en').eq('is_active', true).order('name_en'),
			supabase.rpc('list_default_accounts_other_branches')
		]);
		if (branchResult.error) errorMessage = branchResult.error.message;
		else branches = (branchResult.data || []).map((branch) => ({ ...branch, id: Number(branch.id) }));
		if (mappingResult.error) errorMessage = mappingResult.error.message;
		else mappings = mappingResult.data || [];
		loading = false;
	}

	function branchLabel(branch: Branch) {
		return `${branch.name_en}${branch.location_en ? ` - ${branch.location_en}` : ''}`;
	}

	function openEntry() {
		showEntry = true;
		sourceBranchId = '';
		targetBranchId = '';
		ledgers = [];
		ledgerSearch = '';
		selectedLedgerId = null;
		errorMessage = '';
	}

	function changeSourceBranch(value: string) {
		sourceBranchId = value;
		if (targetBranchId === value) changeTargetBranch('');
	}

	async function changeTargetBranch(value: string) {
		targetBranchId = value;
		ledgers = [];
		ledgerSearch = '';
		selectedLedgerId = null;
		errorMessage = '';
		if (value) await loadTargetLedgers(Number(value));
	}

	async function loadTargetLedgers(branchId: number) {
		loadingLedgers = true;
		try {
			const { data: connection, error } = await supabase.from('erp_connections')
				.select('erp_branch_id').eq('branch_id', branchId).eq('is_active', true).maybeSingle();
			if (error) throw error;
			if (!connection?.erp_branch_id) throw new Error('No active ERP connection for the target branch.');

			const sql = `SELECT l.LedgerID, l.LedgerName, g.AccGroupName FROM AccLedgers l LEFT JOIN AccGroups g ON g.AccGroupID = l.AccGroupID AND g.BranchID = l.BranchID WHERE l.BranchID = ${Number(connection.erp_branch_id)} AND l.IsActive = 1 ORDER BY l.LedgerName`;
			const response = await authenticatedFetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'query', branchId, sql })
			});
			const result = await response.json();
			if (!result.success) throw new Error(result.error || 'Failed to load target branch ledgers.');
			ledgers = (result.recordset || []).map((row: Record<string, unknown>) => ({
				ledgerId: Number(row.LedgerID),
				ledgerName: String(row.LedgerName || '').trim(),
				groupName: String(row.AccGroupName || '').trim()
			}));
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Failed to load target branch ledgers.';
		} finally {
			loadingLedgers = false;
		}
	}

	function selectLedger(ledger: Ledger) {
		selectedLedgerId = ledger.ledgerId;
		ledgerSearch = ledger.ledgerName;
	}

	async function saveMapping() {
		if (!sourceBranchId || !targetBranchId || selectedLedgerId == null) return;
		const ledger = ledgers.find((item) => item.ledgerId === selectedLedgerId);
		if (!ledger) {
			errorMessage = 'Select a ledger from the target branch results.';
			return;
		}
		saving = true;
		errorMessage = '';
		const { error } = await supabase.rpc('save_default_account_other_branch', {
			p_source_branch_id: Number(sourceBranchId),
			p_target_branch_id: Number(targetBranchId),
			p_target_ledger_id: ledger.ledgerId,
			p_target_ledger_name: ledger.ledgerName
		});
		if (error) errorMessage = error.message;
		else {
			showEntry = false;
			await loadPage();
		}
		saving = false;
	}

	async function removeMapping(mapping: Mapping) {
		if (removingId || !confirm(`Remove the mapping from ${mapping.source_branch_name} to ${mapping.target_branch_name}?`)) return;
		removingId = mapping.id;
		errorMessage = '';
		const { data, error } = await supabase.rpc('remove_default_account_other_branch', { p_id: mapping.id });
		if (error) errorMessage = error.message;
		else if (!data) errorMessage = 'The mapping was not found.';
		else mappings = mappings.filter((item) => item.id !== mapping.id);
		removingId = '';
	}
</script>

<div class="relative h-full overflow-auto bg-slate-50 p-5">
	<div class="mx-auto max-w-6xl">
		<div class="mb-4 flex items-center justify-between">
			<div>
				<h2 class="text-lg font-bold text-slate-800">Default Accounts of Other Branches</h2>
				<p class="mt-1 text-xs text-slate-500">Map each source branch to its ledger inside each target branch.</p>
			</div>
			<button type="button" on:click={openEntry} class="rounded bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700">+ Add</button>
		</div>

		{#if errorMessage && !showEntry}
			<p class="mb-3 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{errorMessage}</p>
		{/if}

		<div class="overflow-hidden rounded border border-slate-200 bg-white">
			<table class="w-full text-left text-sm">
				<thead class="bg-slate-100 text-xs text-slate-600">
					<tr><th>Source branch</th><th>Target branch</th><th>Source branch ledger in target branch</th><th>Ledger ID</th><th class="text-center">Action</th></tr>
				</thead>
				<tbody>
					{#if loading}
						<tr><td colspan="5" class="p-5 text-center text-slate-500">Loading…</td></tr>
					{:else if mappings.length === 0}
						<tr><td colspan="5" class="p-5 text-center text-slate-500">No default accounts added.</td></tr>
					{:else}
						{#each mappings as mapping (mapping.id)}
							<tr class="border-t border-slate-200">
								<td>{mapping.source_branch_name}</td>
								<td>{mapping.target_branch_name}</td>
								<td class="font-medium text-slate-800">{mapping.target_ledger_name}</td>
								<td>{mapping.target_ledger_id}</td>
								<td class="text-center"><button type="button" on:click={() => removeMapping(mapping)} disabled={!!removingId} class="rounded border border-red-300 px-3 py-1 text-xs font-medium text-red-600 hover:bg-red-50 disabled:opacity-50">{removingId === mapping.id ? 'Removing…' : 'Remove'}</button></td>
							</tr>
						{/each}
					{/if}
				</tbody>
			</table>
		</div>
	</div>

	{#if showEntry}
		<div class="absolute inset-0 z-20 flex items-center justify-center bg-slate-900/40 p-4" role="presentation" on:click={() => { if (!saving) showEntry = false; }}>
			<div class="w-full max-w-xl rounded-lg bg-white p-5 shadow-xl" role="dialog" aria-modal="true" aria-labelledby="account-entry-title" on:click|stopPropagation>
				<h3 id="account-entry-title" class="text-base font-bold text-slate-800">Add Default Account</h3>

				<div class="mt-4 grid grid-cols-2 gap-3">
					<label class="text-sm font-medium text-slate-700">Source branch
						<select value={sourceBranchId} on:change={(event) => changeSourceBranch(event.currentTarget.value)} disabled={saving} class="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2">
							<option value="">Select source branch</option>
							{#each branches as branch}<option value={String(branch.id)} disabled={targetBranchId === String(branch.id)}>{branchLabel(branch)}</option>{/each}
						</select>
					</label>
					<label class="text-sm font-medium text-slate-700">Target branch
						<select value={targetBranchId} on:change={(event) => changeTargetBranch(event.currentTarget.value)} disabled={!sourceBranchId || saving || loadingLedgers} class="mt-1 w-full rounded border border-slate-300 bg-white px-3 py-2 disabled:bg-slate-100">
							<option value="">Select target branch</option>
							{#each branches as branch}<option value={String(branch.id)} disabled={sourceBranchId === String(branch.id)}>{branchLabel(branch)}</option>{/each}
						</select>
					</label>
				</div>

				<label class="mt-4 block text-sm font-medium text-slate-700">Source branch ledger in target branch
					<input type="search" bind:value={ledgerSearch} on:input={() => selectedLedgerId = null} disabled={!targetBranchId || loadingLedgers || saving} placeholder={targetBranchId ? 'Search ledger name or ID' : 'Select the target branch first'} class="mt-1 w-full rounded border border-slate-300 px-3 py-2 disabled:bg-slate-100" />
				</label>

				{#if loadingLedgers}
					<p class="mt-2 text-xs text-slate-500">Loading ledgers directly from the target branch SQL Server…</p>
				{:else if targetBranchId}
					<div class="mt-2 max-h-56 overflow-y-auto rounded border border-slate-200">
						{#each filteredLedgers as ledger (ledger.ledgerId)}
							<button type="button" on:click={() => selectLedger(ledger)} class="block w-full border-b border-slate-100 px-3 py-2 text-left last:border-0 hover:bg-blue-50" class:bg-blue-100={selectedLedgerId === ledger.ledgerId}>
								<span class="block text-sm font-medium text-slate-800">{ledger.ledgerName}</span>
								<span class="block text-xs text-slate-500">{ledger.groupName || 'No group'} · Ledger {ledger.ledgerId}</span>
							</button>
						{:else}
							<p class="p-3 text-xs text-slate-500">No matching ledgers found.</p>
						{/each}
					</div>
				{/if}

				{#if errorMessage}
					<p class="mt-3 rounded border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">{errorMessage}</p>
				{/if}

				<div class="mt-5 flex justify-end gap-2">
					<button type="button" on:click={() => showEntry = false} disabled={saving} class="rounded border border-slate-300 px-4 py-2 text-sm">Cancel</button>
					<button type="button" on:click={saveMapping} disabled={!sourceBranchId || !targetBranchId || selectedLedgerId == null || saving || loadingLedgers} class="rounded bg-blue-600 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">{saving ? 'Saving…' : 'Save'}</button>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	th, td { padding: 0.65rem 0.75rem; }
</style>
