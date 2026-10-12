<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';

	export let windowId = '';
	export let branchId: number;
	export let branchName = '';

	type AccountKey = 'branch_cash' | 'pos_cash' | 'pos_bank' | 'pos_short' | 'pos_excess';
	type Ledger = { LedgerID: number; LedgerCode: string | number; LedgerName: string };
	type Mapping = {
		id: string;
		account_key: AccountKey;
		pos_number: number | null;
		erp_ledger_id: number | null;
		ledger_code: string;
		ledger_name: string;
	};

	const accountTypes: { key: AccountKey; label: string }[] = [
		{ key: 'branch_cash', label: 'Branch Cash Account' },
		{ key: 'pos_cash', label: 'POS Cash' },
		{ key: 'pos_bank', label: 'POS Bank' },
		{ key: 'pos_short', label: 'POS Short' },
		{ key: 'pos_excess', label: 'POS Excess' }
	];

	let mappings: Mapping[] = [];
	let accountKey: AccountKey = 'branch_cash';
	let posNumber = 1;
	let searchText = '';
	let results: Ledger[] = [];
	let selectedLedger: Ledger | null = null;
	let loading = true;
	let searching = false;
	let saving = false;
	let message = '';
	let isError = false;

	$: existing = mappings.find((item) => item.account_key === accountKey && (accountKey !== 'pos_cash' || item.pos_number === posNumber));

	onMount(loadMappings);

	function accountLabel(mapping: Mapping) {
		const base = accountTypes.find((item) => item.key === mapping.account_key)?.label || mapping.account_key;
		return mapping.account_key === 'pos_cash' ? `${base} ${mapping.pos_number}` : base;
	}

	function setMessage(text: string, error = false) {
		message = text;
		isError = error;
	}

	async function loadMappings() {
		loading = true;
		const { data, error } = await supabase
			.from('erp_posting_ledger_links')
			.select('id, account_key, pos_number, erp_ledger_id, ledger_code, ledger_name')
			.eq('branch_id', branchId)
			.order('account_key')
			.order('pos_number');
		if (error) setMessage(error.message.includes('erp_posting_ledger_links') ? 'Ledger-link database migration has not been deployed yet.' : error.message, true);
		else mappings = (data || []) as Mapping[];
		loading = false;
	}

	async function searchLedgers() {
		searching = true;
		selectedLedger = null;
		setMessage('');
		try {
			const response = await fetch(`/api/erp-ledger-search?branchId=${branchId}&query=${encodeURIComponent(searchText)}`);
			const data = await response.json();
			if (!response.ok || !data.success) throw new Error(data.error || 'Ledger search failed');
			results = data.ledgers || [];
			if (!results.length) setMessage('No matching active ERP ledgers were found.', true);
		} catch (error: any) {
			results = [];
			setMessage(error.message || 'Ledger search failed', true);
		} finally {
			searching = false;
		}
	}

	function chooseLedger(ledger: Ledger) {
		selectedLedger = ledger;
		searchText = `${ledger.LedgerCode} - ${ledger.LedgerName}`;
		results = [];
	}

	function editMapping(mapping: Mapping) {
		accountKey = mapping.account_key;
		posNumber = mapping.pos_number || 1;
		selectedLedger = { LedgerID: mapping.erp_ledger_id || 0, LedgerCode: mapping.ledger_code, LedgerName: mapping.ledger_name };
		searchText = `${mapping.ledger_code} - ${mapping.ledger_name}`;
		results = [];
		setMessage('');
	}

	async function saveMapping() {
		if (!selectedLedger) return setMessage('Search for and select an ERP ledger first.', true);
		if (accountKey === 'pos_cash' && (!Number.isInteger(posNumber) || posNumber <= 0)) return setMessage('Enter a valid POS number.', true);
		saving = true;
		setMessage('');
		const payload = {
			branch_id: branchId,
			account_key: accountKey,
			pos_number: accountKey === 'pos_cash' ? posNumber : null,
			erp_ledger_id: Number(selectedLedger.LedgerID) || null,
			ledger_code: String(selectedLedger.LedgerCode),
			ledger_name: selectedLedger.LedgerName
		};
		const operation = existing
			? supabase.from('erp_posting_ledger_links').update(payload).eq('id', existing.id)
			: supabase.from('erp_posting_ledger_links').insert(payload);
		const { error } = await operation;
		if (error) setMessage(error.message, true);
		else {
			setMessage('ERP ledger link saved.');
			selectedLedger = null;
			searchText = '';
			results = [];
			await loadMappings();
		}
		saving = false;
	}

	async function removeMapping(mapping: Mapping) {
		if (!confirm(`Remove the link for ${accountLabel(mapping)}?`)) return;
		const { error } = await supabase.from('erp_posting_ledger_links').delete().eq('id', mapping.id);
		if (error) setMessage(error.message, true);
		else {
			setMessage('ERP ledger link removed.');
			await loadMappings();
		}
	}
</script>

<div class="ledger-links">
	<header>
		<div>
			<h2>ERP Ledger Links</h2>
			<p>Connect Aqura posting accounts to real Polosys ledgers.</p>
		</div>
		<div class="branch">{branchName || `Branch ${branchId}`}</div>
	</header>

	<div class="notice"><b>Employee Salary Account</b> is resolved automatically from the cashier's existing ERP Employee Link.</div>

	<section class="form-card">
		<div class="field">
			<label for="account-type">Account Type</label>
			<select id="account-type" bind:value={accountKey} on:change={() => { selectedLedger = null; searchText = ''; results = []; }}>
				{#each accountTypes as account}<option value={account.key}>{account.label}</option>{/each}
			</select>
		</div>
		{#if accountKey === 'pos_cash'}
			<div class="field pos-field"><label for="pos-number">POS Number</label><input id="pos-number" type="number" min="1" step="1" bind:value={posNumber} /></div>
		{/if}
		<div class="field search-field">
			<label for="ledger-search">ERP Ledger Name or Code</label>
			<div class="search-row"><input id="ledger-search" bind:value={searchText} on:keydown={(event) => event.key === 'Enter' && searchLedgers()} placeholder="Search the real ERP ledger..." /><button on:click={searchLedgers} disabled={searching}>{searching ? 'Searching...' : 'Search'}</button></div>
			{#if results.length}
				<div class="results">
					{#each results as ledger}
						<button class="result" on:click={() => chooseLedger(ledger)}><span class="code">{ledger.LedgerCode}</span><span>{ledger.LedgerName}</span></button>
					{/each}
				</div>
			{/if}
		</div>
		<div class="save-wrap"><button class="save" on:click={saveMapping} disabled={saving || !selectedLedger}>{saving ? 'Saving...' : existing ? 'Update Link' : 'Save Link'}</button></div>
	</section>

	{#if message}<div class:error={isError} class="message">{message}</div>{/if}

	<section class="list-card">
		<h3>Current Links</h3>
		{#if loading}<p class="empty">Loading links...</p>
		{:else if !mappings.length}<p class="empty">No ERP posting ledgers have been linked for this branch.</p>
		{:else}
			<table>
				<thead><tr><th>Aqura Account</th><th>Ledger Code</th><th>ERP Ledger Name</th><th>Action</th></tr></thead>
				<tbody>{#each mappings as mapping}<tr><td><b>{accountLabel(mapping)}</b></td><td><span class="code">{mapping.ledger_code}</span></td><td>{mapping.ledger_name}</td><td class="actions"><button on:click={() => editMapping(mapping)}>Edit</button><button class="remove" on:click={() => removeMapping(mapping)}>Remove</button></td></tr>{/each}</tbody>
			</table>
		{/if}
	</section>
</div>

<style>
	.ledger-links{height:100%;box-sizing:border-box;padding:18px;background:#f4f9fc;color:#0b3655;overflow:auto;font-family:Arial,sans-serif}header{display:flex;align-items:center;justify-content:space-between;margin-bottom:12px}h2,h3,p{margin:0}h2{font-size:22px}header p{margin-top:4px;color:#59778d}.branch{background:#0b3655;color:white;padding:9px 14px;border-radius:8px;font-weight:700}.notice{padding:11px 14px;margin-bottom:14px;background:#e7f8fb;border-left:4px solid #0ea5b7;border-radius:7px;color:#17566c}.form-card,.list-card{background:white;border:1px solid #c7dce9;border-radius:10px;padding:15px;box-shadow:0 2px 8px #0b36550d}.form-card{display:flex;align-items:flex-end;gap:12px;position:relative}.field{min-width:210px}.pos-field{min-width:110px;max-width:130px}.search-field{flex:1;position:relative}label{display:block;font-size:12px;font-weight:700;margin-bottom:6px;color:#49687d}input,select{width:100%;box-sizing:border-box;height:38px;border:1px solid #b9cfdd;border-radius:6px;padding:0 10px;background:white;color:#123d59}.search-row{display:flex;gap:7px}.search-row input{flex:1}.search-row button,.save,.actions button{border:0;border-radius:6px;padding:0 16px;font-weight:700;cursor:pointer}.search-row button,.save{height:38px;background:#12839c;color:white}.save:disabled,.search-row button:disabled{opacity:.55;cursor:not-allowed}.results{position:absolute;z-index:5;top:64px;left:0;right:0;max-height:250px;overflow:auto;background:white;border:1px solid #9fc4d7;border-radius:7px;box-shadow:0 8px 24px #0b36552b}.result{width:100%;display:flex;gap:12px;text-align:left;padding:10px;border:0;border-bottom:1px solid #e3edf3;background:white;cursor:pointer}.result:hover{background:#eaf8fb}.code{display:inline-block;background:#e7eef9;color:#254f78;border-radius:4px;padding:3px 7px;font-weight:700;white-space:nowrap}.message{margin:12px 0;padding:9px 12px;border-radius:6px;background:#e7f8ee;color:#14733c}.message.error{background:#fff0f0;color:#b42318}.list-card{margin-top:14px}h3{margin-bottom:11px}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:10px;border-bottom:1px solid #e3edf3}th{font-size:12px;text-transform:uppercase;color:#658093;background:#f3f8fb}.actions{white-space:nowrap}.actions button{height:30px;background:#e2f3f7;color:#11677b;margin-right:6px}.actions .remove{background:#fff0f0;color:#b42318}.empty{text-align:center;color:#71899a;padding:28px}.save-wrap{padding-bottom:0}@media(max-width:800px){.form-card{flex-wrap:wrap}.search-field{min-width:100%}}
</style>
