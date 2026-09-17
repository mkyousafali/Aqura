<script lang="ts">
	import { createEventDispatcher } from 'svelte';

	export let value = ''; // 'YYYY-MM-DD' or ''
	export let isRtl = false;
	export let minYear = new Date().getFullYear() - 5;
	export let maxYear = new Date().getFullYear() + 1;
	export let accentClass = 'focus:ring-emerald-500';

	const dispatch = createEventDispatcher<{ change: string }>();

	let year = '';
	let month = '';
	let day = '';
	let lastEmitted = '';

	// Sync internal dropdowns whenever `value` changes from outside (e.g. quick filters)
	$: if (value !== lastEmitted) {
		const parts = value ? value.split('-') : [];
		year = parts[0] || '';
		month = parts[1] || '';
		day = parts[2] || '';
		lastEmitted = value;
	}

	$: years = Array.from({ length: maxYear - minYear + 1 }, (_, i) => minYear + i);
	$: months = Array.from({ length: 12 }, (_, i) => i + 1);
	$: daysInMonth = year && month ? new Date(Number(year), Number(month), 0).getDate() : 31;
	$: days = Array.from({ length: daysInMonth }, (_, i) => i + 1);
	$: monthLabel = (m: number) => new Date(2000, m - 1, 1).toLocaleDateString(isRtl ? 'ar-EG' : 'en-US', { month: 'short' });

	function commit() {
		if (year && month && day) {
			const clampedDay = Math.min(Number(day), daysInMonth);
			const next = `${year}-${String(month).padStart(2, '0')}-${String(clampedDay).padStart(2, '0')}`;
			if (next !== value) {
				value = next;
				lastEmitted = next;
				dispatch('change', next);
			}
		} else if (value !== '') {
			value = '';
			lastEmitted = '';
			dispatch('change', '');
		}
	}
</script>

<div class="flex gap-1.5">
	<select
		bind:value={year}
		on:change={commit}
		class="min-w-0 flex-1 px-2 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 {accentClass} focus:border-transparent transition-all"
		style="color: #000000 !important; background-color: #ffffff !important;"
	>
		<option value="" style="color: #000000 !important;">{isRtl ? 'سنة' : 'Year'}</option>
		{#each years as y}
			<option value={String(y)} style="color: #000000 !important;">{y}</option>
		{/each}
	</select>
	<select
		bind:value={month}
		on:change={commit}
		class="min-w-0 flex-1 px-2 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 {accentClass} focus:border-transparent transition-all"
		style="color: #000000 !important; background-color: #ffffff !important;"
	>
		<option value="" style="color: #000000 !important;">{isRtl ? 'شهر' : 'Month'}</option>
		{#each months as m}
			<option value={String(m).padStart(2, '0')} style="color: #000000 !important;">{monthLabel(m)}</option>
		{/each}
	</select>
	<select
		bind:value={day}
		on:change={commit}
		class="min-w-0 flex-1 px-2 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 {accentClass} focus:border-transparent transition-all"
		style="color: #000000 !important; background-color: #ffffff !important;"
	>
		<option value="" style="color: #000000 !important;">{isRtl ? 'يوم' : 'Day'}</option>
		{#each days as d}
			<option value={String(d).padStart(2, '0')} style="color: #000000 !important;">{d}</option>
		{/each}
	</select>
</div>
