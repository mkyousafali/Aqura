<script>
	import { onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { loadSchedulerVendors } from '$lib/utils/schedulerVendor';
	export let branchId;
	export let selectedVendor = null;
	export let valid = true;
	let vendorExpense = Boolean(selectedVendor);
	let vendors = [];
	let query = '';
	let loading = false;
	let error = '';
	let loadedBranch;
	let generation = 0;
	$: if (String(branchId) !== loadedBranch) {
		loadedBranch = String(branchId);
		if (selectedVendor && Number(selectedVendor.branch_id) !== Number(branchId)) selectedVendor = null;
		load(branchId);
	}
	$: if (!vendorExpense) selectedVendor = null;
	$: valid = !vendorExpense || Boolean(selectedVendor && Number(selectedVendor.branch_id) === Number(branchId));
	$: filtered = vendors.filter(v => `${v.vendor_name} ${v.erp_vendor_id}`.toLowerCase().includes(query.trim().toLowerCase()));
	async function load(branch) {
		const request = ++generation;
		vendors = []; error = ''; loading = true;
		try {
			const rows = await loadSchedulerVendors(supabase, branch);
			if (request === generation) vendors = rows;
		} catch (e) {
			if (request === generation) error = 'Unable to load vendors. Retry before scheduling a vendor expense.';
		} finally { if (request === generation) loading = false; }
	}
	onDestroy(() => { generation++; });
</script>

<section class="vendor-picker">
	<h4>Expense recipient</h4>
	<div class="recipient-options">
		<label><input type="radio" bind:group={vendorExpense} value={false} /> General expense</label>
		<label><input type="radio" bind:group={vendorExpense} value={true} /> Vendor expense</label>
	</div>
	{#if vendorExpense}
		<label>Find vendor in the selected branch
			<input type="search" bind:value={query} placeholder="Search vendor name or code…" />
		</label>
		{#if loading}<p>Loading vendors…</p>
		{:else if error}<p role="alert">{error}</p><button type="button" on:click={() => load(branchId)}>Retry</button>
		{:else if selectedVendor}
			<p class="selected">{selectedVendor.vendor_name} · Code {selectedVendor.erp_vendor_id}
				<button type="button" on:click={() => selectedVendor = null}>Change</button>
			</p>
		{:else}
			<div class="vendor-results">
				{#each filtered.slice(0, 50) as vendor}
					<button type="button" on:click={() => selectedVendor = vendor}>{vendor.vendor_name} · {vendor.erp_vendor_id}</button>
				{:else}<p>No matching vendors in this branch.</p>{/each}
			</div>
			{#if filtered.length > 50}<p>Showing 50 matches. Refine your search.</p>{/if}
		{/if}
	{/if}
</section>

<style>
	.vendor-picker { margin-bottom: 1.5rem; padding: 1rem; border: 1px solid #dbe3ef; border-radius: .75rem; background: #f8fafc; }
	h4 { margin: 0 0 .75rem; font-size: 1rem; color: #24334b; }
	.recipient-options { display:flex; flex-wrap:wrap; gap:1.5rem; margin-bottom:.75rem; }
	label { font-size:.875rem; color:#334155; }
	input[type=search] { display:block; width:100%; padding:.65rem; margin-top:.4rem; border:1px solid #cbd5e1; border-radius:.4rem; box-sizing:border-box; }
	.vendor-results { max-height: 220px; overflow:auto; margin-top:.6rem; }
	.vendor-results button { display:block; width:100%; text-align:start; padding:.6rem; background:white; border:1px solid #e2e8f0; cursor:pointer; }
	button { border-radius:.3rem; padding:.3rem .6rem; cursor:pointer; }
	.selected { color:#166534; }
	p { font-size:.85rem; }
	[role=alert] { color:#b91c1c; }
</style>
