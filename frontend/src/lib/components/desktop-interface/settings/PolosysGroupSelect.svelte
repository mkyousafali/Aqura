<script lang="ts">
	import { createEventDispatcher, tick } from 'svelte';
	type Group = { id: string; name: string; name_ar?: string | null };
	export let groups: Group[] = [];
	export let value = '';
	export let disabled = false;
	export let title = 'Select product group';
	export let placeholder = 'Select product group';
	export let searchLabel = 'Search groups';
	export let emptyMessage = 'No matching product groups.';
	const dispatch = createEventDispatcher<{ change: void }>();
	let dialog: HTMLDialogElement;
	let searchInput: HTMLInputElement;
	let query = '';
	let open = false;
	$: selected = groups.find(group => group.id === value);
	$: filtered = groups.filter(group => `${group.name} ${group.name_ar || ''}`.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()));

	async function showPicker() {
		if (disabled) return;
		query = '';
		dialog.showModal();
		open = true;
		await tick();
		searchInput?.focus();
	}

	function selectGroup(id: string) {
		value = id;
		dispatch('change');
		dialog.close();
	}
</script>

<button class="picker-trigger" type="button" {disabled} aria-haspopup="dialog" aria-expanded={open} on:click={showPicker}>
	<span>{selected?.name || placeholder}</span><span aria-hidden="true">▾</span>
</button>

<dialog bind:this={dialog} aria-label={title} on:close={() => open = false}>
	<header><h3>{title}</h3><button type="button" on:click={() => dialog.close()}>Close</button></header>
	<label>{searchLabel}
		<input type="search" bind:this={searchInput} bind:value={query} placeholder="Search by English or Arabic name" autocomplete="off" />
	</label>
	<div class="group-list">
		{#each filtered as group (group.id)}
			<button class="group-option" class:selected={value === group.id} type="button" aria-pressed={value === group.id} on:click={() => selectGroup(group.id)}>
				<span>{group.name}</span>{#if group.name_ar}<small lang="ar" dir="rtl">{group.name_ar}</small>{/if}
			</button>
		{:else}<p>{emptyMessage}</p>{/each}
	</div>
	{#if value}<button class="clear-selection" type="button" on:click={() => selectGroup('')}>Clear selection</button>{/if}
</dialog>

<style>
	button,input{box-sizing:border-box;border:1px solid #cbd5e1;border-radius:6px;background:white;color:#1e293b;font:inherit}
	button{min-height:44px;padding:8px 10px;cursor:pointer}button:disabled{opacity:.55;cursor:default}
	button:focus-visible,input:focus{outline:2px solid #0891b2;outline-offset:2px}
	.picker-trigger{display:flex;align-items:center;justify-content:space-between;gap:6px;width:100%;text-align:left;font-size:13px}
	.picker-trigger>span:first-child{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
	dialog{position:fixed;inset:0;margin:auto;box-sizing:border-box;width:min(480px,calc(100vw - 24px));max-height:calc(100dvh - 24px);padding:12px;border:1px solid #cbd5e1;border-radius:12px;background:#f8fafc;color:#1e293b;font-size:14px}
	dialog[open]{display:flex;flex-direction:column;gap:8px}
	dialog::backdrop{background:#0f172a80}
	header{display:flex;justify-content:space-between;align-items:center;gap:8px;flex-shrink:0}
	h3{margin:0;font-size:15px}label{display:flex;flex-direction:column;gap:8px;font-size:13px;flex-shrink:0}
	input{width:100%;min-height:44px;padding:8px 10px;font-size:16px;flex-shrink:0}
	.group-list{min-height:0;overflow:auto;overscroll-behavior:contain;display:flex;flex-direction:column;gap:4px}
	.group-option{display:flex;justify-content:space-between;align-items:center;gap:8px;flex-shrink:0;text-align:left;overflow-wrap:anywhere}
	.group-option small{color:#64748b}
	.group-option.selected{background:#ecfeff;border-color:#0891b2;color:#0e7490}
	.clear-selection{flex-shrink:0}
	p{margin:8px;color:#64748b}
</style>
