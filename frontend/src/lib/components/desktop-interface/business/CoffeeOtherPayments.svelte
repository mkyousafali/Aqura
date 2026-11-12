<script lang="ts">
	import { onMount, onDestroy, createEventDispatcher, tick } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { currentUser } from '$lib/utils/persistentAuth';
	import type { CoffeeOtherPayment, CoffeeOtherPaymentsResponse } from '$lib/types/coffeeOtherPayments';
	import type { CoffeeExpensePaidFrom } from '$lib/types/coffeeOtherExpenses';

	import { COFFEE_COUNTER, type BusinessCounterProfile } from '$lib/types/businessCounter';

	export let profile: BusinessCounterProfile = COFFEE_COUNTER;
	export let windowId: string;
	export let mode: 'withdrawal' | 'expense' = 'withdrawal';
	const isExpense = mode === 'expense';
	const reportKey = isExpense ? 'otherExpensesReport' : 'otherPaymentsReport';
	const endpoint = `/api/${profile.id}-other-${isExpense ? 'expenses' : 'payments'}`;
	type Entry = CoffeeOtherPayment & { paidFrom?: CoffeeExpensePaidFrom };
	let paidFrom: '' | CoffeeExpensePaidFrom = '';
	const dispatch = createEventDispatcher<{ saved: CoffeeOtherPayment }>();
	let payments: Entry[] = [];
	let loading = true;
	let failed = false;
	let showForm = false;
	let amount = '';
	let narration = '';
	let requestId = '';
	let saving = false;
	let saveError = '';
	let saved = false;
	let editing: Entry | null = null;
	let updated = false;
	let controller: AbortController | null = null;
	$: canEdit = $currentUser?.isMasterAdmin === true;
	$: total = payments.reduce((sum, payment) => sum + Math.round(payment.amount * 100), 0) / 100;
	$: money = new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

	async function openForm() {
		editing = null;
		amount = '';
		narration = '';
		paidFrom = '';
		requestId = crypto.randomUUID();
		saveError = '';
		showForm = true;
		saved = false;
		await tick();
		document.getElementById(`${windowId}-other-payment-amount`)?.focus();
	}

	async function editPayment(payment: Entry) {
		if (!canEdit || saving) return;
		if (!Number.isSafeInteger(payment.version) || payment.version < 1) { void loadPayments(); return; }
		editing = payment;
		amount = payment.amount.toFixed(2);
		narration = payment.narration;
		paidFrom = payment.paidFrom || '';
		requestId = '';
		saveError = '';
		saved = false;
		showForm = true;
		await tick();
		document.getElementById(`${windowId}-other-payment-amount`)?.focus();
	}

	function changeRequest() {
		if (!editing) requestId = crypto.randomUUID();
		saveError = '';
		saved = false;
	}

	async function loadPayments() {
		controller?.abort();
		const pending = new AbortController();
		controller = pending;
		loading = true;
		failed = false;
		try {
			const response = await authenticatedFetch(endpoint, { signal: pending.signal });
			const result: CoffeeOtherPaymentsResponse = await response.json();
			if (!response.ok || !result.success || !Array.isArray(result.payments)) throw new Error('Unable to load other payments');
			if (!pending.signal.aborted) payments = result.payments;
		} catch {
			if (!pending.signal.aborted) failed = true;
		} finally {
			if (!pending.signal.aborted) loading = false;
		}
	}

	async function savePayment() {
		if (saving || loading || failed) return;
		if (editing && !canEdit) { saveError = $t(`${profile.localeKey}.paymentEditing.masterOnly`); return; }
		const paymentAmount = amount.trim();
		const paymentNarration = narration.trim();
		if (!/^\d{1,12}(\.\d{1,2})?$/.test(paymentAmount) || Number(paymentAmount) <= 0 || !paymentNarration || (isExpense && !['sales', 'operator'].includes(paidFrom))) {
			saveError = $t(`${profile.localeKey}.${reportKey}.invalid`);
			return;
		}
		if (!editing && !requestId) requestId = crypto.randomUUID();
		const editedEntry = editing;
		saving = true;
		saveError = '';
		try {
			const response = await authenticatedFetch(endpoint, {
				method: editedEntry ? 'PATCH' : 'POST', headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ id: editedEntry?.id || requestId, amount: paymentAmount, narration: paymentNarration,
					...(editedEntry ? { expectedVersion: editedEntry.version } : {}), ...(isExpense ? { paidFrom } : {}) })
			});
			const result: { success: boolean; payment?: Entry } = await response.json();
			if (editedEntry && response.status === 409) { saveError = $t(`${profile.localeKey}.paymentEditing.conflict`); return; }
			if (editedEntry && response.status === 403) { saveError = $t(`${profile.localeKey}.paymentEditing.masterOnly`); return; }
			if (!response.ok || !result.success || !result.payment) throw new Error('Unable to save other payment');
			const payment = result.payment;
			payments = [payment, ...payments.filter(row => row.id !== payment.id)]
				.sort((a, b) => b.createdAt.localeCompare(a.createdAt) || a.id.localeCompare(b.id));
			amount = '';
			narration = '';
			paidFrom = '';
			requestId = '';
			showForm = false;
			editing = null;
			updated = editedEntry !== null;
			saved = true;
			dispatch('saved', payment);
		} catch {
			saveError = $t(`${profile.localeKey}.${reportKey}.saveFailed`);
		} finally {
			saving = false;
		}
	}

	onMount(() => { void loadPayments(); });
	onDestroy(() => controller?.abort());
</script>

<div class="other-payments">
	<div class="toolbar">
		<h2>{$t(isExpense ? `${profile.localeKey}.otherExpenses` : `${profile.localeKey}.otherPayments`)}</h2>
		<div class="actions">
			<button type="button" on:click={loadPayments} disabled={loading || saving}>{$t(`${profile.localeKey}.refresh`)}</button>
			<button class="add" type="button" on:click={openForm} disabled={saving || loading || failed} aria-expanded={showForm} aria-controls={`${windowId}-other-payment-form`}>
				<span aria-hidden="true">+</span> {$t(`${profile.localeKey}.${reportKey}.add`)}
			</button>
		</div>
	</div>
	<p class="note">{$t(`${profile.localeKey}.${reportKey}.note`)}</p>
	{#if showForm && (!editing || canEdit)}
		<form id={`${windowId}-other-payment-form`} on:submit|preventDefault={savePayment}>
			{#if editing}<h3>{$t(isExpense ? `${profile.localeKey}.paymentEditing.editExpense` : `${profile.localeKey}.paymentEditing.editWithdrawal`)}</h3>{/if}
			<label for={`${windowId}-other-payment-amount`}>{$t(`${profile.localeKey}.${reportKey}.amount`)}</label>
			<input id={`${windowId}-other-payment-amount`} type="text" inputmode="decimal" maxlength="15" required bind:value={amount} on:input={changeRequest} disabled={saving} autocomplete="off" />
			{#if isExpense}
				<label for={`${windowId}-expense-paid-from`}>{$t(`${profile.localeKey}.otherExpensesReport.paidFrom`)}</label>
				<select id={`${windowId}-expense-paid-from`} bind:value={paidFrom} on:change={changeRequest} required disabled={saving}>
					<option value="" disabled>{$t(`${profile.localeKey}.otherExpensesReport.chooseSource`)}</option>
					<option value="sales">{$t(`${profile.localeKey}.otherExpensesReport.sales`)}</option>
					<option value="operator">{$t(`${profile.localeKey}.otherExpensesReport.operator`)}</option>
				</select>
			{/if}
			<label for={`${windowId}-other-payment-narration`}>{$t(`${profile.localeKey}.narration`)}</label>
			<textarea id={`${windowId}-other-payment-narration`} rows="3" maxlength="2000" required bind:value={narration} on:input={changeRequest} disabled={saving}></textarea>
			{#if saveError}<p class="message error" role="alert">{saveError}</p>{/if}
			<div class="actions">
				<button class="add" type="submit" disabled={saving || loading || failed}>{$t(saving ? `${profile.localeKey}.${reportKey}.saving` : editing ? `${profile.localeKey}.paymentEditing.saveChanges` : `${profile.localeKey}.${reportKey}.save`)}</button>
				<button type="button" disabled={saving} on:click={() => showForm = false}>{$t(`${profile.localeKey}.${reportKey}.cancel`)}</button>
			</div>
		</form>
	{/if}
	{#if saved}<p class="message success" role="status">{$t(updated ? `${profile.localeKey}.paymentEditing.updated` : `${profile.localeKey}.${reportKey}.saved`)}</p>{/if}
	{#if loading}
		<p class="message" role="status">{$t(`${profile.localeKey}.${reportKey}.loading`)}</p>
	{:else if failed}
		<p class="message error" role="alert">{$t(`${profile.localeKey}.${reportKey}.failed`)}</p>
	{:else}
		<div class="total"><span>{$t(`${profile.localeKey}.${reportKey}.total`)}</span><strong><bdi>{money.format(total)}</bdi></strong></div>
		{#if payments.length === 0}
			<p class="message">{$t(`${profile.localeKey}.${reportKey}.empty`)}</p>
		{:else}
			<div class="table-scroll">
				<table>
					<thead><tr>
						<th scope="col">{$t(`${profile.localeKey}.rowNumber`)}</th>
						<th scope="col">{$t(`${profile.localeKey}.date`)}</th>
						<th scope="col">{$t(`${profile.localeKey}.narration`)}</th>
						{#if isExpense}<th scope="col">{$t(`${profile.localeKey}.otherExpensesReport.paidFrom`)}</th>{/if}
						<th scope="col" class="number">{$t(`${profile.localeKey}.${reportKey}.amount`)}</th>
						{#if canEdit}<th scope="col">{$t(`${profile.localeKey}.paymentEditing.actions`)}</th>{/if}
					</tr></thead>
					<tbody>
						{#each payments as payment, index (payment.id)}<tr>
							<td>{index + 1}</td>
							<td class="date"><bdi>{payment.paymentDate}</bdi></td>
							<td class="narration">{payment.narration}</td>
							{#if isExpense}<td>{$t(`${profile.localeKey}.otherExpensesReport.${payment.paidFrom}`)}</td>{/if}
							<td class="number"><bdi>{money.format(payment.amount)}</bdi></td>
							{#if canEdit}<td><button type="button" disabled={saving || loading} on:click={() => editPayment(payment)}>{$t(`${profile.localeKey}.paymentEditing.edit`)}</button></td>{/if}
						</tr>{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{/if}
</div>

<style>
	.other-payments { display: flex; flex-direction: column; height: 100%; min-height: 0; overflow: auto; }
	.toolbar, .actions { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
	.toolbar { justify-content: space-between; flex-shrink: 0; }
	h2 { margin: 0; font-size: 20px; font-weight: 600; }
	h3 { margin: 0 0 4px; font-size: 16px; font-weight: 600; }
	.note { color: #64748b; font-size: 12px; flex-shrink: 0; }
	button, input, textarea, select { padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: white; color: #1e293b; font: inherit; }
	button { cursor: pointer; color: #047857; font-size: 13px; font-weight: 600; }
	button.add { background: #047857; color: white; border-color: #047857; }
	button.add span { font-size: 20px; line-height: 1; }
	button:disabled { opacity: 0.6; cursor: wait; }
	button:focus-visible, input:focus-visible, textarea:focus-visible, select:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
	form { display: grid; gap: 10px; padding: 16px; border: 1px solid #e2e8f0; border-radius: 8px; margin: 0 0 16px; background: #f8fafc; flex-shrink: 0; }
	form label { font-size: 13px; font-weight: 600; }
	input { width: min(260px, 100%); box-sizing: border-box; }
	textarea { resize: vertical; min-height: 70px; }
	.message { padding: 12px; border-radius: 8px; background: #f8fafc; color: #64748b; flex-shrink: 0; }
	.error { color: #9a3412; background: #fff7ed; }
	.success { color: #047857; background: #ecfdf5; }
	.total { margin-bottom: 16px; padding: 16px; border: 1px solid #e2e8f0; border-radius: 8px; background: #f8fafc; flex-shrink: 0; }
	.total span { display: block; font-size: 12px; color: #64748b; }
	.total strong { display: block; margin-top: 8px; font-size: 22px; font-variant-numeric: tabular-nums; }
	.table-scroll { flex: 1; min-height: 150px; overflow: auto; border: 1px solid #e2e8f0; border-radius: 8px; }
	table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
	th, td { padding: 12px; text-align: start; border-bottom: 1px solid #e2e8f0; }
	th:not(:last-child), td:not(:last-child) { border-inline-end: 1px solid #e2e8f0; }
	th { position: sticky; top: 0; z-index: 1; background: #f1f5f9; white-space: nowrap; }
	.number { text-align: end; white-space: nowrap; font-variant-numeric: tabular-nums; }
	.date { white-space: nowrap; }
	.narration { white-space: pre-wrap; min-width: 180px; }
</style>
