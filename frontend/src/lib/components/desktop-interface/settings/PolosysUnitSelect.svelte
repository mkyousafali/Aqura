<script lang="ts">
	import { createEventDispatcher, tick } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import SearchableDropdown from '$lib/components/desktop-interface/marketing/flyer/SearchableDropdown.svelte';
	import PolosysGroupSelect from './PolosysGroupSelect.svelte';

	type Unit = { id: string; name: string; name_ar?: string | null };
	export let units: Unit[] = [];
	export let value = '';
	export let label = 'Unit name';
	export let disabled = false;
	export let mobile = false;
	export let excludedIds: string[] = [];
	const dispatch = createEventDispatcher<{ saved: Unit; change: void; saving: boolean }>();
	let open = false;
	let newName = '';
	let newArabicName = '';
	let saving = false;
	let error = '';
	let message = '';
	let nameInput: HTMLInputElement;
	let arabicNameInput: HTMLInputElement;
	let addButton: HTMLButtonElement;
	const preferredUnits = ['Pcs', 'Packet', 'Ctn'];
	const unitPriority = (name: string) => {
		const index = preferredUnits.findIndex(unit => unit.toLowerCase() === name.toLowerCase());
		return index < 0 ? preferredUnits.length : index;
	};
	$: availableUnits = units.filter(unit => !excludedIds.includes(unit.id) || unit.id === value)
		.sort((a, b) => unitPriority(a.name) - unitPriority(b.name) || a.name.localeCompare(b.name, 'en', { numeric: true }));
	$: options = availableUnits.map(unit => ({ id: unit.id, name_en: unit.name }));

	async function openPopup() {
		newName = ''; newArabicName = ''; error = ''; message = ''; open = true;
		await tick();
		nameInput?.focus();
	}

	async function closePopup() {
		open = false;
		await tick();
		addButton?.focus();
	}

	async function save() {
		if (!$currentUser?.id || saving || disabled) return;
		const name = newName.trim();
		const nameAr = newArabicName.trim();
		if (!name) {
			error = 'Enter the unit name.';
			nameInput?.focus();
			return;
		}
		if (!nameAr) {
			error = 'Enter the Arabic unit name.';
			arabicNameInput?.focus();
			return;
		}
		saving = true;
		dispatch('saving', true);
		error = '';
		try {
			let saved = units.find(unit => unit.name === name);
			let existing = !!saved;
			if (!saved) {
				const result = await supabase.from('Polosys_units').insert({ name, name_ar: nameAr }).select('id, name, name_ar').single();
				if (result.error?.code === '23505') {
					const found = await supabase.from('Polosys_units').select('id, name, name_ar').eq('name', name).single();
					if (found.error) throw found.error;
					saved = found.data;
					existing = true;
				} else {
					if (result.error) throw result.error;
					saved = result.data;
				}
			}
			if (!saved) throw new Error('The saved unit could not be loaded.');
			if (excludedIds.includes(saved.id)) throw new Error('This unit is already used for this product. Select a different unit.');
			if (saved.name_ar !== nameAr) {
				const updated = await supabase.from('Polosys_units').update({ name_ar: nameAr }).eq('id', saved.id).select('id, name, name_ar').single();
				if (updated.error) throw updated.error;
				if (!updated.data) throw new Error('The updated unit could not be loaded.');
				saved = updated.data;
			}
			value = saved.id;
			dispatch('saved', saved);
			dispatch('change');
			message = existing ? 'Existing unit selected.' : 'Unit saved in Aqura and selected.';
			open = false;
		} catch (failure) {
			error = (failure as { message?: string })?.message || 'Unable to save the unit. Try again.';
		} finally {
			saving = false;
			dispatch('saving', false);
		}
		if (!open) await closePopup();
	}
</script>

<div class="unit-picker">
	<span>{label}</span>
	<fieldset disabled={disabled || saving} aria-label={label}>
		<div class="selector">
			{#if mobile}<PolosysGroupSelect groups={availableUnits} bind:value disabled={disabled || saving} title={`Select ${label.toLowerCase()}`} placeholder="Select unit" searchLabel="Search units" emptyMessage="No matching units." on:change={() => { message = ''; dispatch('change'); }} />
			{:else}<SearchableDropdown {options} bind:value placeholder="Search and select unit" on:change={() => { message = ''; dispatch('change'); }} />{/if}
		</div>
		<button type="button" class="add" bind:this={addButton} aria-label="Create unit" aria-expanded={open} on:click={openPopup}>+</button>
	</fieldset>
	{#if message}<span class="message" role="status">{message}</span>{/if}
	{#if open}
		<div class="popup" role="dialog" aria-label="Create unit">
			<h3>Create unit</h3>
			<label>Unit name (English)<input bind:this={nameInput} bind:value={newName} disabled={disabled || saving} placeholder="Exact unit name in Polosys" on:keydown={(event) => { if (event.key === 'Enter') { event.preventDefault(); event.stopPropagation(); arabicNameInput?.focus(); } else if (event.key === 'Escape' && !saving) { event.preventDefault(); event.stopPropagation(); closePopup(); } }} /></label>
			<label class="arabic-label">Unit name (Arabic)<input bind:this={arabicNameInput} bind:value={newArabicName} disabled={disabled || saving} lang="ar" dir="rtl" placeholder="اسم الوحدة بالعربية" on:keydown={(event) => { if (event.key === 'Enter') { event.preventDefault(); event.stopPropagation(); save(); } else if (event.key === 'Escape' && !saving) { event.preventDefault(); event.stopPropagation(); closePopup(); } }} /></label>
			{#if error}<div class="error" role="alert">{error}</div>{/if}
			<div class="actions"><button type="button" disabled={saving} on:click={closePopup}>Cancel</button><button type="button" class="primary" disabled={disabled || saving} on:click={save}>{saving ? 'Saving…' : 'Save unit'}</button></div>
		</div>
	{/if}
</div>

<style>
	.arabic-label{margin-top:14px}
	.unit-picker{position:relative;display:flex;flex-direction:column;gap:8px;min-width:0}fieldset{display:flex;gap:8px;min-width:0;margin:0;padding:0;border:0}.selector{flex:1;min-width:0}button{border:1px solid #cbd5e1;border-radius:6px;padding:9px 14px;background:white;color:#334155;font:inherit;cursor:pointer}button:disabled,input:disabled{opacity:.55;cursor:default}.add{flex:none;font-size:20px;padding:5px 14px;color:#0e7490}.message{font-size:12px;color:#047857}.popup{position:absolute;top:100%;left:0;z-index:40;width:max(100%,260px);max-width:calc(100vw - 64px);box-sizing:border-box;margin-top:6px;padding:16px;border:1px solid #cbd5e1;border-radius:8px;background:white;box-shadow:0 8px 24px #0f172a26}h3{font-size:15px;margin:0 0 14px}label{display:flex;flex-direction:column;gap:8px}input{box-sizing:border-box;width:100%;min-width:0;border:1px solid #cbd5e1;border-radius:6px;padding:10px 12px;background:white;color:#0f172a;font:inherit}input:focus{outline:2px solid #0891b2;outline-offset:1px}.error{background:#fef2f2;color:#b91c1c;padding:12px;border-radius:6px;margin-top:14px}.actions{display:flex;justify-content:flex-end;gap:8px;margin-top:14px;flex-wrap:wrap}.primary{background:#0e7490;border-color:#0e7490;color:white}
</style>
