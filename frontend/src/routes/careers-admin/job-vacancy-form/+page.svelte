<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { supabase } from '$lib/utils/supabase';

	let vacancyId: string | null = null;
	let loading = true;
	let saving = false;
	let errorMsg = '';

	let title_en = '';
	let title_ar = '';
	let department_en = '';
	let department_ar = '';
	let employment_type_en = '';
	let employment_type_ar = '';
	let location_en = '';
	let location_ar = '';
	let short_desc_en = '';
	let short_desc_ar = '';
	let full_desc_en = '';
	let full_desc_ar = '';
	let requirements_en = '';
	let requirements_ar = '';
	let responsibilities_en = '';
	let responsibilities_ar = '';
	let experience_en = '';
	let experience_ar = '';
	let salary_en = '';
	let salary_ar = '';
	let closing_date = '';
	let button_text_en = 'Apply';
	let button_text_ar = 'تقديم';
	let enabled = true;
	let display_order = 0;

	onMount(async () => {
		vacancyId = $page.url.searchParams.get('id');
		if (vacancyId) {
			try {
				const { data, error } = await supabase
					.from('career_job_vacancies')
					.select('*')
					.eq('id', vacancyId)
					.single();
				if (error) throw error;
				if (data) {
					title_en = data.title_en ?? '';
					title_ar = data.title_ar ?? '';
					department_en = data.department_en ?? '';
					department_ar = data.department_ar ?? '';
					employment_type_en = data.employment_type_en ?? '';
					employment_type_ar = data.employment_type_ar ?? '';
					location_en = data.location_en ?? '';
					location_ar = data.location_ar ?? '';
					short_desc_en = data.short_desc_en ?? '';
					short_desc_ar = data.short_desc_ar ?? '';
					full_desc_en = data.full_desc_en ?? '';
					full_desc_ar = data.full_desc_ar ?? '';
					requirements_en = data.requirements_en ?? '';
					requirements_ar = data.requirements_ar ?? '';
					responsibilities_en = data.responsibilities_en ?? '';
					responsibilities_ar = data.responsibilities_ar ?? '';
					experience_en = data.experience_en ?? '';
					experience_ar = data.experience_ar ?? '';
					salary_en = data.salary_en ?? '';
					salary_ar = data.salary_ar ?? '';
					closing_date = data.closing_date ?? '';
					button_text_en = data.button_text_en ?? button_text_en;
					button_text_ar = data.button_text_ar ?? button_text_ar;
					enabled = data.enabled ?? true;
					display_order = data.display_order ?? 0;
				}
			} catch (e: any) {
				errorMsg = `Failed to load vacancy: ${e?.message ?? 'unknown error'}`;
			}
		}
		loading = false;
	});

	async function handleSave() {
		if (!title_en.trim()) {
			errorMsg = 'English job title is required.';
			return;
		}
		saving = true;
		errorMsg = '';
		try {
			const payload = {
				title_en,
				title_ar,
				department_en,
				department_ar,
				employment_type_en,
				employment_type_ar,
				location_en,
				location_ar,
				short_desc_en,
				short_desc_ar,
				full_desc_en,
				full_desc_ar,
				requirements_en,
				requirements_ar,
				responsibilities_en,
				responsibilities_ar,
				experience_en,
				experience_ar,
				salary_en,
				salary_ar,
				closing_date: closing_date || null,
				button_text_en,
				button_text_ar,
				enabled,
				display_order,
				updated_at: new Date().toISOString()
			};
			if (vacancyId) {
				const { error } = await supabase.from('career_job_vacancies').update(payload).eq('id', vacancyId);
				if (error) throw error;
			} else {
				const { error } = await supabase.from('career_job_vacancies').insert(payload);
				if (error) throw error;
			}
			if (window.opener) {
				window.close();
			} else {
				errorMsg = '';
				alert('Vacancy saved.');
			}
		} catch (e: any) {
			errorMsg = `Failed to save vacancy: ${e?.message ?? 'unknown error'}`;
		} finally {
			saving = false;
		}
	}

	function handleCancel() {
		window.close();
	}
</script>

<svelte:head>
	<title>{vacancyId ? 'Edit' : 'Add'} Job Vacancy</title>
</svelte:head>

<div class="form-page">
	{#if loading}
		<p class="loading">Loading…</p>
	{:else}
		<h1>{vacancyId ? 'Edit' : 'Add'} Job Vacancy</h1>
		{#if errorMsg}<p class="error">⚠️ {errorMsg}</p>{/if}

		<div class="grid">
			<label><span>Job Title (EN) *</span><input type="text" bind:value={title_en} /></label>
			<label><span>Job Title (AR)</span><input type="text" dir="rtl" bind:value={title_ar} /></label>

			<label><span>Department / Category (EN)</span><input type="text" bind:value={department_en} /></label>
			<label><span>Department / Category (AR)</span><input type="text" dir="rtl" bind:value={department_ar} /></label>

			<label><span>Employment Type (EN)</span><input type="text" placeholder="Full-time, Part-time…" bind:value={employment_type_en} /></label>
			<label><span>Employment Type (AR)</span><input type="text" dir="rtl" bind:value={employment_type_ar} /></label>

			<label><span>Branch / Work Location (EN)</span><input type="text" bind:value={location_en} /></label>
			<label><span>Branch / Work Location (AR)</span><input type="text" dir="rtl" bind:value={location_ar} /></label>

			<label class="full"><span>Short Description (EN)</span><textarea rows="2" bind:value={short_desc_en}></textarea></label>
			<label class="full"><span>Short Description (AR)</span><textarea rows="2" dir="rtl" bind:value={short_desc_ar}></textarea></label>

			<label class="full"><span>Full Job Description (EN)</span><textarea rows="4" bind:value={full_desc_en}></textarea></label>
			<label class="full"><span>Full Job Description (AR)</span><textarea rows="4" dir="rtl" bind:value={full_desc_ar}></textarea></label>

			<label class="full"><span>Requirements (EN)</span><textarea rows="3" bind:value={requirements_en}></textarea></label>
			<label class="full"><span>Requirements (AR)</span><textarea rows="3" dir="rtl" bind:value={requirements_ar}></textarea></label>

			<label class="full"><span>Responsibilities (EN)</span><textarea rows="3" bind:value={responsibilities_en}></textarea></label>
			<label class="full"><span>Responsibilities (AR)</span><textarea rows="3" dir="rtl" bind:value={responsibilities_ar}></textarea></label>

			<label><span>Experience Required (EN)</span><input type="text" bind:value={experience_en} /></label>
			<label><span>Experience Required (AR)</span><input type="text" dir="rtl" bind:value={experience_ar} /></label>

			<label><span>Salary / Benefits (EN) — optional</span><input type="text" bind:value={salary_en} /></label>
			<label><span>Salary / Benefits (AR) — optional</span><input type="text" dir="rtl" bind:value={salary_ar} /></label>

			<label><span>Application Closing Date</span><input type="date" bind:value={closing_date} /></label>
			<label><span>Display Order</span><input type="number" bind:value={display_order} /></label>

			<label><span>Button Text (EN)</span><input type="text" bind:value={button_text_en} /></label>
			<label><span>Button Text (AR)</span><input type="text" dir="rtl" bind:value={button_text_ar} /></label>

			<label class="checkbox-row"><input type="checkbox" bind:checked={enabled} /><span>Enabled (visible on the login page)</span></label>
		</div>

		<div class="actions">
			<button class="btn-cancel" type="button" on:click={handleCancel} disabled={saving}>Cancel</button>
			<button class="btn-save" type="button" on:click={handleSave} disabled={saving}>{saving ? 'Saving…' : '💾 Save Vacancy'}</button>
		</div>
	{/if}
</div>

<style>
	:global(body) {
		background: #f4f2ee;
	}

	.form-page {
		max-width: 900px;
		margin: 0 auto;
		padding: 1.75rem 2rem 3rem;
		font-family: system-ui, sans-serif;
		color: #1f3d2f;
	}

	h1 {
		font-size: 1.3rem;
		margin: 0 0 1rem;
	}

	.loading {
		padding: 2rem;
		text-align: center;
		color: #777;
	}

	.error {
		background: rgba(200, 40, 40, 0.1);
		color: #a12;
		border-radius: 8px;
		padding: 0.6rem 0.9rem;
		font-size: 0.85rem;
		margin-bottom: 1rem;
	}

	.grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.9rem 1.25rem;
	}

	label {
		display: flex;
		flex-direction: column;
		gap: 0.3rem;
		font-size: 0.82rem;
		font-weight: 600;
		color: #444;
	}

	label.full {
		grid-column: 1 / -1;
	}

	label.checkbox-row {
		grid-column: 1 / -1;
		flex-direction: row;
		align-items: center;
		gap: 0.5rem;
	}

	input,
	textarea {
		font-family: inherit;
		font-size: 0.9rem;
		font-weight: 400;
		padding: 0.5rem 0.65rem;
		border: 1px solid #ddd;
		border-radius: 8px;
		color: #1f3d2f;
	}

	textarea {
		resize: vertical;
	}

	.actions {
		display: flex;
		justify-content: flex-end;
		gap: 0.75rem;
		margin-top: 1.5rem;
		border-top: 1px solid #e5e2db;
		padding-top: 1.25rem;
	}

	.btn-cancel,
	.btn-save {
		border: none;
		border-radius: 999px;
		padding: 0.6rem 1.4rem;
		font-size: 0.88rem;
		font-weight: 600;
		cursor: pointer;
	}

	.btn-cancel {
		background: #eee;
		color: #555;
	}

	.btn-save {
		background: #c8912f;
		color: #fff;
	}

	.btn-save:disabled,
	.btn-cancel:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
