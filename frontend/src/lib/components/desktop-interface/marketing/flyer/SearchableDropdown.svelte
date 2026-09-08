<script lang="ts">
	// Lightweight searchable dropdown for {id, name_en, name_ar} option lists
	// (product categories, units). Shows both English and Arabic names in
	// each option and lets the user type to filter by either.
	import { createEventDispatcher } from 'svelte';

	export let options: { id: string; name_en: string; name_ar?: string }[] = [];
	export let value: string = '';
	export let placeholder: string = 'Search...';

	const dispatch = createEventDispatcher();

	let query = '';
	let open = false;
	let containerEl: HTMLDivElement;

	$: selectedOption = options.find(o => o.id === value) || null;
	$: displayText = open ? query : (selectedOption ? formatLabel(selectedOption) : '');
	$: filtered = (() => {
		const q = query.trim().toLowerCase();
		if (!q) return options;
		return options.filter(o =>
			o.name_en?.toLowerCase().includes(q) ||
			o.name_ar?.includes(query.trim())
		);
	})();

	function formatLabel(o: { name_en: string; name_ar?: string }) {
		return o.name_ar ? `${o.name_en} - ${o.name_ar}` : o.name_en;
	}

	function openDropdown() {
		open = true;
		query = '';
	}

	function pick(o: { id: string; name_en: string; name_ar?: string }) {
		value = o.id;
		open = false;
		query = '';
		dispatch('change', { id: o.id });
	}

	function clear() {
		value = '';
		open = false;
		query = '';
		dispatch('change', { id: '' });
	}

	function handleWindowClick(e: MouseEvent) {
		if (containerEl && !containerEl.contains(e.target as Node)) {
			open = false;
			query = '';
		}
	}
</script>

<svelte:window on:click={handleWindowClick} />

<div class="relative" bind:this={containerEl}>
	<input
		type="text"
		value={displayText}
		on:focus={openDropdown}
		on:input={(e) => { query = e.currentTarget.value; open = true; }}
		{placeholder}
		class="field-border w-full px-2 py-2 text-sm border-2 border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
	/>
	{#if selectedOption && !open}
		<button
			type="button"
			on:click={clear}
			class="absolute right-1.5 top-1/2 -translate-y-1/2 w-5 h-5 flex items-center justify-center text-gray-400 hover:text-gray-600"
			title="Clear"
			aria-label="Clear selection"
		>
			&times;
		</button>
	{/if}

	{#if open}
		<div class="absolute z-30 mt-1 w-full max-h-52 overflow-auto bg-white border-2 border-gray-200 rounded-lg shadow-lg">
			{#if filtered.length === 0}
				<p class="px-3 py-2 text-sm text-gray-400">No matches</p>
			{:else}
				{#each filtered as option (option.id)}
					<button
						type="button"
						on:click={() => pick(option)}
						class="w-full text-left px-3 py-2 text-sm hover:bg-blue-50 {option.id === value ? 'bg-blue-50 font-semibold text-blue-700' : 'text-gray-700'}"
					>
						{option.name_en}
						{#if option.name_ar}
							<span class="text-gray-500" dir="rtl"> - {option.name_ar}</span>
						{/if}
					</button>
				{/each}
			{/if}
		</div>
	{/if}
</div>

<style>
	/* mobile-interface/+layout.svelte has an app-wide, unlayered
	   `:global(input) { border: none; }` reset. Because it's unlayered, it
	   beats Tailwind's border-* utilities (those live in @layer utilities —
	   any unlayered CSS wins over layered CSS regardless of selector
	   specificity), so this input loses its border on the mobile route.
	   !important is the only thing that reliably wins that fight. Width/
	   style only, so the existing border-gray-300 utility still sets color. */
	.field-border {
		border-width: 2px !important;
		border-style: solid !important;
	}
</style>
