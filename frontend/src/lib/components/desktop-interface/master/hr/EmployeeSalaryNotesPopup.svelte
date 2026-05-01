<script lang="ts">
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, locale } from '$lib/i18n';
	import { createEventDispatcher } from 'svelte';

	export let employeeId: string = '';
	export let employeeName: string = '';
	export let show: boolean = false;

	const dispatch = createEventDispatcher();

	type NoteType = 'common' | 'specific_period' | 'until_date';

	interface SalaryNote {
		id: string;
		employee_id: string;
		note_type: NoteType;
		note_text: string;
		from_date: string | null;
		to_date: string | null;
		until_date: string | null;
		created_at: string;
	}

	let notes: SalaryNote[] = [];
	let loading = false;
	let saving = false;
	let error = '';
	let deletingId: string | null = null;

	// Form state
	let selectedType: NoteType = 'common';
	let noteText = '';
	let fromDate = '';
	let toDate = '';
	let untilDate = '';
	let formError = '';

	$: if (show && employeeId) {
		loadNotes();
		resetForm();
	}

	async function loadNotes() {
		loading = true;
		error = '';
		try {
			const { data, error: err } = await supabase.rpc('get_hr_salary_notes', {
				p_employee_id: employeeId
			});
			if (err) throw err;
			notes = data || [];
		} catch (e: any) {
			error = e?.message || String(e);
		} finally {
			loading = false;
		}
	}

	function resetForm() {
		selectedType = 'common';
		noteText = '';
		fromDate = '';
		toDate = '';
		untilDate = '';
		formError = '';
	}

	function selectType(type: NoteType) {
		selectedType = type;
		formError = '';
	}

	async function saveNote() {
		formError = '';
		if (!noteText.trim()) {
			formError = $t('hr.salaryNotes.noteTextRequired');
			return;
		}
		if (selectedType === 'specific_period' && (!fromDate || !toDate)) {
			formError = $t('hr.salaryNotes.bothDatesRequired');
			return;
		}
		if (selectedType === 'until_date' && !untilDate) {
			formError = $t('hr.salaryNotes.untilDateRequired');
			return;
		}

		saving = true;
		try {
			const { data, error: err } = await supabase.rpc('create_hr_salary_note', {
				p_employee_id: employeeId,
				p_note_type: selectedType,
				p_note_text: noteText.trim(),
				p_from_date: selectedType === 'specific_period' ? fromDate : null,
				p_to_date: selectedType === 'specific_period' ? toDate : null,
				p_until_date: selectedType === 'until_date' ? untilDate : null,
			});
			if (err) throw err;
			if (!data?.success) throw new Error(data?.error || 'Failed to save');
			resetForm();
			await loadNotes();
		} catch (e: any) {
			formError = e?.message || String(e);
		} finally {
			saving = false;
		}
	}

	async function deleteNote(id: string) {
		if (deletingId) return;
		deletingId = id;
		try {
			const { data, error: err } = await supabase.rpc('delete_hr_salary_note', { p_id: id });
			if (err) throw err;
			if (!data?.success) throw new Error(data?.error || 'Failed to delete');
			notes = notes.filter(n => n.id !== id);
		} catch (e: any) {
			error = e?.message || String(e);
		} finally {
			deletingId = null;
		}
	}

	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '';
		try {
			return new Date(dateStr).toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-GB', {
				year: 'numeric', month: 'short', day: 'numeric'
			});
		} catch { return dateStr; }
	}

	function formatDateTime(dateStr: string): string {
		if (!dateStr) return '';
		try {
			return new Date(dateStr).toLocaleString($locale === 'ar' ? 'ar-SA' : 'en-GB', {
				year: 'numeric', month: 'short', day: 'numeric',
				hour: '2-digit', minute: '2-digit'
			});
		} catch { return dateStr; }
	}

	function getNoteTypeLabel(type: NoteType): string {
		if (type === 'common') return $t('hr.salaryNotes.typeCommon');
		if (type === 'specific_period') return $t('hr.salaryNotes.typeSpecificPeriod');
		if (type === 'until_date') return $t('hr.salaryNotes.typeUntilDate');
		return type;
	}

	function getNoteTypeBadgeClass(type: NoteType): string {
		if (type === 'common') return 'bg-slate-100 text-slate-600';
		if (type === 'specific_period') return 'bg-blue-100 text-blue-700';
		if (type === 'until_date') return 'bg-amber-100 text-amber-700';
		return '';
	}

	function close() {
		show = false;
		dispatch('close');
	}
</script>

{#if show}
	<!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
	<div
		role="dialog"
		aria-modal="true"
		tabindex="-1"
		class="fixed inset-0 z-[10000] flex items-center justify-center bg-black/50 backdrop-blur-sm"
		on:click|self={close}
		on:keydown={(e) => e.key === 'Escape' && close()}
	>
		<div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 flex flex-col max-h-[85vh] overflow-hidden">

			<!-- Header -->
			<div class="flex items-center justify-between px-5 py-3 bg-emerald-50 border-b-2 border-emerald-400 flex-shrink-0">
				<div>
					<p class="text-[10px] font-bold text-emerald-600 uppercase tracking-widest">{$t('hr.salaryNotes.title')}</p>
					<p class="font-bold text-base text-slate-800 leading-tight">{employeeName}</p>
					<p class="text-[10px] text-slate-500">{employeeId}</p>
				</div>
				<button
					class="p-2 hover:bg-emerald-100 rounded-full transition-colors text-emerald-600"
					aria-label="Close"
					on:click={close}
				>
					<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					</svg>
				</button>
			</div>

			<!-- Body -->
			<div class="flex flex-col flex-1 overflow-hidden">

				<!-- Add Note Form -->
				<div class="px-5 pt-4 pb-3 border-b border-slate-100 flex-shrink-0 bg-slate-50/60">
					<!-- Note Type Selector -->
					<div class="flex gap-2 mb-3">
						<button
							type="button"
							class="flex-1 py-1.5 px-2 rounded-lg text-[11px] font-bold border-2 transition-all {selectedType === 'common' ? 'bg-slate-700 text-white border-slate-700' : 'bg-white text-slate-600 border-slate-200 hover:border-slate-400'}"
							on:click={() => selectType('common')}
						>
							📝 {$t('hr.salaryNotes.addCommon')}
						</button>
						<button
							type="button"
							class="flex-1 py-1.5 px-2 rounded-lg text-[11px] font-bold border-2 transition-all {selectedType === 'specific_period' ? 'bg-blue-600 text-white border-blue-600' : 'bg-white text-blue-600 border-blue-200 hover:border-blue-400'}"
							on:click={() => selectType('specific_period')}
						>
							📅 {$t('hr.salaryNotes.addSpecificPeriod')}
						</button>
						<button
							type="button"
							class="flex-1 py-1.5 px-2 rounded-lg text-[11px] font-bold border-2 transition-all {selectedType === 'until_date' ? 'bg-amber-500 text-white border-amber-500' : 'bg-white text-amber-600 border-amber-200 hover:border-amber-400'}"
							on:click={() => selectType('until_date')}
						>
							⏳ {$t('hr.salaryNotes.addUntilDate')}
						</button>
					</div>

					<!-- Text area -->
					<textarea
						bind:value={noteText}
						rows="2"
						placeholder={$t('hr.salaryNotes.notePlaceholder')}
						class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-400 resize-none bg-white mb-2"
					></textarea>

					<!-- Date fields based on type -->
					{#if selectedType === 'specific_period'}
						<div class="flex gap-2 mb-2">
							<div class="flex-1">
								<label class="block text-[10px] font-bold text-blue-600 uppercase tracking-wide mb-1">{$t('hr.salaryNotes.fromDate')}</label>
								<input type="date" bind:value={fromDate} class="w-full px-3 py-1.5 border border-blue-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 bg-white" />
							</div>
							<div class="flex-1">
								<label class="block text-[10px] font-bold text-blue-600 uppercase tracking-wide mb-1">{$t('hr.salaryNotes.toDate')}</label>
								<input type="date" bind:value={toDate} class="w-full px-3 py-1.5 border border-blue-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 bg-white" />
							</div>
						</div>
					{:else if selectedType === 'until_date'}
						<div class="mb-2">
							<label class="block text-[10px] font-bold text-amber-600 uppercase tracking-wide mb-1">{$t('hr.salaryNotes.untilDate')}</label>
							<input type="date" bind:value={untilDate} class="w-full px-3 py-1.5 border border-amber-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-400 bg-white" />
						</div>
					{/if}

					{#if formError}
						<p class="text-xs text-red-600 mb-1">{formError}</p>
					{/if}

					<button
						type="button"
						disabled={saving}
						on:click={saveNote}
						class="w-full py-2 rounded-lg text-sm font-bold bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white transition-colors"
					>
						{saving ? $t('hr.salaryNotes.saving') : $t('hr.salaryNotes.save')}
					</button>
				</div>

				<!-- Notes list -->
				<div class="flex-1 overflow-y-auto px-5 py-3 space-y-2">
					{#if loading}
						<div class="text-center text-sm text-slate-400 py-6">{$t('common.loading')}</div>
					{:else if error}
						<div class="text-center text-sm text-red-500 py-4">{error}</div>
					{:else if notes.length === 0}
						<div class="text-center text-sm text-slate-400 py-8 italic">{$t('hr.salaryNotes.noNotes')}</div>
					{:else}
						{#each notes as note (note.id)}
							<div class="bg-white border border-slate-200 rounded-xl px-4 py-3 shadow-sm hover:shadow transition-shadow">
								<div class="flex items-start justify-between gap-2">
									<p class="text-sm text-slate-800 leading-relaxed flex-1 whitespace-pre-wrap">{note.note_text}</p>
									<button
										type="button"
										disabled={deletingId === note.id}
										on:click={() => deleteNote(note.id)}
										class="flex-shrink-0 p-1 hover:bg-red-100 rounded-full text-slate-300 hover:text-red-500 transition-colors disabled:opacity-40"
										title={$t('hr.salaryNotes.delete')}
									>
										<svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
										</svg>
									</button>
								</div>
								<div class="flex flex-wrap items-center gap-1.5 mt-2">
									<span class="px-2 py-0.5 rounded-full text-[10px] font-bold {getNoteTypeBadgeClass(note.note_type)}">
										{getNoteTypeLabel(note.note_type)}
									</span>
									{#if note.note_type === 'specific_period' && note.from_date && note.to_date}
										<span class="text-[10px] text-blue-600 font-medium">
											{formatDate(note.from_date)} → {formatDate(note.to_date)}
										</span>
									{:else if note.note_type === 'until_date' && note.until_date}
										<span class="text-[10px] text-amber-600 font-medium">
											{$t('hr.salaryNotes.until')} {formatDate(note.until_date)}
										</span>
									{/if}
									<span class="text-[10px] text-slate-400 ml-auto">{formatDateTime(note.created_at)}</span>
								</div>
							</div>
						{/each}
					{/if}
				</div>
			</div>
		</div>
	</div>
{/if}
