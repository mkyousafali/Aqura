<script lang="ts">
	import { onMount } from 'svelte';
	import { locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';

	type Employee = { id: string; name_en: string; name_ar: string; branch_id: number; branch_name_en: string; branch_name_ar: string; enabled: boolean };
	type Branch = { id: number; name_en: string; name_ar: string; location_en: string; location_ar: string };
	type Recipient = { id: string; username: string; name_en: string; name_ar: string; whatsapp_number: string; email: string; contact_ready: boolean; enabled: boolean; delivery_mode: 'whatsapp_only' | 'whatsapp_and_email'; all_branches: boolean; branch_ids: number[] };

	let employees: Employee[] = [];
	let recipients: Recipient[] = [];
	let branches: Branch[] = [];
	let loading = true;
	let savingKey = '';
	let testingKey = '';
	let runningToday = false;
	let errorMessage = '';
	let successMessage = '';
	let employeeSearch = '';
	let recipientSearch = '';
	let activeSection: 'employees' | 'recipients' = 'employees';

	$: ar = $locale === 'ar';
	$: filteredEmployees = employees
		.filter((row) => !employeeSearch.trim() || JSON.stringify(row).toLowerCase().includes(employeeSearch.trim().toLowerCase()))
		.sort((a, b) => Number(b.enabled) - Number(a.enabled));
	$: filteredRecipients = recipients
		.filter((row) => row.contact_ready && (!recipientSearch.trim() || JSON.stringify(row).toLowerCase().includes(recipientSearch.trim().toLowerCase())))
		.sort((a, b) => Number(b.enabled) - Number(a.enabled));

	onMount(loadData);

	async function loadData() {
		loading = true; errorMessage = '';
		try {
			const { data, error } = await supabase.rpc('get_attendance_notification_admin_data');
			if (error) throw error;
			employees = data?.employees || [];
			recipients = (data?.users || []).map((row: Recipient) => ({ ...row, branch_ids: (row.branch_ids || []).map(Number) }));
			branches = data?.branches || [];
		} catch (error: any) { errorMessage = error?.message || 'Unable to load settings.'; }
		finally { loading = false; }
	}

	function success(message: string) { successMessage = message; setTimeout(() => successMessage = '', 2500); }

	function employeeBranchLocation(employee: Employee) {
		const branch = branches.find((item) => Number(item.id) === Number(employee.branch_id));
		return ar ? branch?.location_ar || branch?.location_en : branch?.location_en || branch?.location_ar;
	}

	async function setEmployee(employee: Employee, enabled: boolean) {
		savingKey = `employee:${employee.id}`; errorMessage = '';
		try {
			const { error } = await supabase.rpc('set_attendance_monitored_employee', { p_employee_id: employee.id, p_enabled: enabled });
			if (error) throw error;
			employee.enabled = enabled; employees = [...employees];
			success(ar ? 'تم حفظ إعداد المراقبة' : 'Monitoring setting saved');
		} catch (error: any) { errorMessage = error?.message || 'Unable to save.'; }
		finally { savingKey = ''; }
	}

	function toggleBranch(recipient: Recipient, branchId: number) {
		const selected = new Set(recipient.branch_ids);
		selected.has(branchId) ? selected.delete(branchId) : selected.add(branchId);
		recipient.branch_ids = [...selected]; recipients = [...recipients];
	}

	async function saveRecipient(recipient: Recipient) {
		if (recipient.enabled && !recipient.contact_ready) { errorMessage = ar ? 'يجب توفر رقم واتساب وبريد إلكتروني.' : 'WhatsApp and email are required.'; return; }
		if (recipient.enabled && !recipient.all_branches && recipient.branch_ids.length === 0) { errorMessage = ar ? 'اختر فرعاً واحداً على الأقل.' : 'Select at least one branch.'; return; }
		savingKey = `recipient:${recipient.id}`; errorMessage = '';
		try {
			const { error } = await supabase.rpc('set_attendance_notification_recipient', {
				p_user_id: recipient.id, p_enabled: recipient.enabled, p_delivery_mode: recipient.delivery_mode,
				p_all_branches: recipient.all_branches, p_branch_ids: recipient.all_branches ? [] : recipient.branch_ids
			});
			if (error) throw error;
			success(ar ? 'تم حفظ إعدادات المستلم' : 'Recipient settings saved');
			await loadData();
		} catch (error: any) { errorMessage = error?.message || 'Unable to save.'; }
		finally { savingKey = ''; }
	}

	async function testRecipient(recipient: Recipient, channel: 'whatsapp' | 'email' | 'in_app') {
		if (!recipient.enabled) {
			errorMessage = ar ? 'احفظ المستلم كمفعّل قبل الاختبار.' : 'Save and enable the recipient before testing.';
			return;
		}
		testingKey = `${recipient.id}:${channel}`;
		errorMessage = '';
		try {
			const { data, error } = await supabase.functions.invoke('attendance-notification-test', {
				body: { recipient_user_id: recipient.id, channel }
			});
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || 'Test failed.');
			const label = channel === 'whatsapp' ? 'WhatsApp' : channel === 'email' ? 'Email' : (ar ? 'داخل التطبيق' : 'In-app');
			success(ar ? `تم إرسال اختبار ${label} بنجاح` : `${label} test sent successfully`);
		} catch (error: any) {
			errorMessage = error?.message || (ar ? 'تعذر إرسال الاختبار.' : 'Unable to send test.');
		} finally {
			testingKey = '';
		}
	}

	async function runTodayReport() {
		const confirmed = window.confirm(ar
			? 'سيتم إعادة إرسال تقرير اليوم حتى لو تم إرساله سابقاً، ولكن فقط للموظفين الذين يؤكد الفحص الجديد أنهم لم يسجلوا الحضور. هل تريد المتابعة؟'
			: "This will resend today's report even if it was sent before, but only for employees who still have no check-in after a fresh verification. Continue?");
		if (!confirmed) return;
		runningToday = true;
		errorMessage = '';
		try {
			const { data, error } = await supabase.functions.invoke('attendance-notification-test', {
				body: { action: 'run_today' }
			});
			if (error) throw error;
			if (!data?.success) throw new Error(data?.error || "Today's attendance check failed.");
			const result = data.result || {};
			success(ar
				? `اكتمل فحص اليوم: تم التقييم ${result.evaluated || 0}، قيد الانتظار ${result.pending || 0}، التنبيهات ${result.alerted || 0}، الإرسالات ${result.deliveries || 0}`
				: `Today's check completed: ${result.evaluated || 0} evaluated, ${result.pending || 0} pending, ${result.alerted || 0} alerts, ${result.deliveries || 0} deliveries.`);
		} catch (error: any) {
			errorMessage = error?.message || (ar ? 'تعذر تشغيل تقرير اليوم.' : "Unable to run today's report.");
		} finally {
			runningToday = false;
		}
	}
</script>

<div class="h-full overflow-auto bg-slate-50 p-5" dir={ar ? 'rtl' : 'ltr'}>
	<div class="w-full space-y-5">
		{#if errorMessage}<div class="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">{errorMessage}</div>{/if}
		{#if successMessage}<div class="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-semibold text-emerald-700">{successMessage}</div>{/if}

		<nav class="grid grid-cols-2 gap-2 rounded-2xl border border-slate-200 bg-white p-2 shadow-sm" aria-label="Attendance notifier tables">
			<button
				type="button"
				class="rounded-xl px-4 py-3 text-sm font-black transition {activeSection === 'employees' ? 'bg-orange-500 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'}"
				on:click={() => activeSection = 'employees'}
			>
				{ar ? 'الموظفون تحت المراقبة' : 'Monitored Employees'}
				<span class="ms-2 rounded-full bg-black/10 px-2 py-0.5 text-xs">{employees.filter((employee) => employee.enabled).length}</span>
			</button>
			<button
				type="button"
				class="rounded-xl px-4 py-3 text-sm font-black transition {activeSection === 'recipients' ? 'bg-orange-500 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'}"
				on:click={() => activeSection = 'recipients'}
			>
				{ar ? 'مستلمو الإشعارات' : 'Notification Recipients'}
				<span class="ms-2 rounded-full bg-black/10 px-2 py-0.5 text-xs">{recipients.filter((recipient) => recipient.enabled).length}</span>
			</button>
		</nav>

		<div class="flex justify-end">
			<button
				type="button"
				class="rounded-xl bg-slate-800 px-5 py-2.5 text-sm font-black text-white shadow-sm transition hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-50"
				disabled={loading || runningToday || !!savingKey || !!testingKey}
				on:click={runTodayReport}
			>
				{runningToday ? (ar ? 'جاري تشغيل فحص اليوم...' : "Running today's check...") : (ar ? 'إرسال تقرير اليوم' : "Send Today's Report")}
			</button>
		</div>

		{#if loading}
			<div class="rounded-2xl border bg-white p-10 text-center text-slate-500">{ar ? 'جاري التحميل...' : 'Loading settings...'}</div>
		{:else}
			{#if activeSection === 'employees'}
			<section class="rounded-2xl border border-slate-200 bg-white shadow-sm">
				<div class="flex flex-wrap items-center justify-between gap-3 border-b p-4">
					<div><h3 class="font-black">{ar ? 'الموظفون تحت المراقبة' : 'Monitored Employees'}</h3><p class="text-xs text-slate-500">Job (With Finger)</p></div>
					<input class="w-72 rounded-xl border-slate-300 text-sm" bind:value={employeeSearch} placeholder={ar ? 'بحث...' : 'Search...'} />
				</div>
				<div class="max-h-[55vh] overflow-auto overscroll-contain"><table class="w-full text-sm"><thead class="sticky top-0 bg-slate-100 text-xs uppercase text-slate-500"><tr><th class="w-14 p-3 text-center">#</th><th class="p-3 text-start">{ar ? 'الموظف' : 'Employee'}</th><th class="p-3 text-start">{ar ? 'الفرع' : 'Branch'}</th><th class="p-3 text-center">{ar ? 'مراقبة' : 'Monitor'}</th></tr></thead><tbody>
					{#each filteredEmployees as employee, employeeIndex (employee.id)}<tr class="border-t hover:bg-slate-50"><td class="p-3 text-center font-semibold text-slate-500">{employeeIndex + 1}</td><td class="p-3"><b>{ar ? employee.name_ar || employee.name_en : employee.name_en || employee.name_ar}</b><div class="text-xs text-slate-400">{employee.id}</div></td><td class="p-3"><span class="block">{ar ? employee.branch_name_ar || employee.branch_name_en : employee.branch_name_en || employee.branch_name_ar}</span>{#if employeeBranchLocation(employee)}<span class="mt-0.5 block text-xs text-slate-400">{employeeBranchLocation(employee)}</span>{/if}</td><td class="p-3 text-center"><input type="checkbox" checked={employee.enabled} disabled={savingKey === `employee:${employee.id}`} on:change={(event) => setEmployee(employee, event.currentTarget.checked)} /></td></tr>{/each}
				</tbody></table></div>
			</section>
			{/if}

			{#if activeSection === 'recipients'}
			<section class="rounded-2xl border border-slate-200 bg-white shadow-sm">
				<div class="flex flex-wrap items-center justify-between gap-3 border-b p-4"><div><h3 class="font-black">{ar ? 'مستلمو التنبيهات' : 'Notification Recipients'}</h3><p class="text-xs text-slate-500">{ar ? 'الإشعار داخل التطبيق إلزامي دائماً' : 'In-app notification is always mandatory'}</p></div><input class="w-72 rounded-xl border-slate-300 text-sm" bind:value={recipientSearch} placeholder={ar ? 'بحث...' : 'Search...'} /></div>
				<div class="recipient-table max-h-[55vh] overflow-y-auto overscroll-contain">
					<div class="recipient-table-header">
						<span>#</span>
						<span>{ar ? 'المستلم' : 'Recipient'}</span>
						<span>{ar ? 'بيانات الاتصال' : 'Contact'}</span>
						<span>{ar ? 'إعدادات الإشعارات والفروع' : 'Notification & branch settings'}</span>
						<span>{ar ? 'الحالة' : 'Status'}</span>
						<span>{ar ? 'الإجراءات' : 'Actions'}</span>
					</div>
					{#each filteredRecipients as recipient (recipient.id)}
						<article class="recipient-card border-b border-slate-200 bg-white last:border-b-0">
							<div class="recipient-identity-row"><div><b>{ar ? recipient.name_ar || recipient.name_en : recipient.name_en || recipient.name_ar}</b></div><div class="space-y-1 text-xs"><span class="block text-emerald-700">WhatsApp: {recipient.whatsapp_number || '—'}</span><span class="block text-blue-700">Email: {recipient.email || '—'}</span></div><label class="flex items-center gap-2 text-sm font-bold"><input type="checkbox" bind:checked={recipient.enabled} disabled={!recipient.contact_ready} />{ar ? 'مفعّل' : 'Enabled'}</label></div>
							{#if !recipient.contact_ready}<p class="mt-2 text-xs font-bold text-amber-700">{ar ? 'رقم واتساب والبريد الإلكتروني مطلوبان.' : 'WhatsApp and email are both required.'}</p>{/if}
							<div class="mt-4 grid gap-4 lg:grid-cols-2"><label class="text-xs font-bold text-slate-500">{ar ? 'قنوات الإرسال' : 'Delivery channels'}<select class="mt-1 w-full rounded-lg border-slate-300 text-sm" bind:value={recipient.delivery_mode}><option value="whatsapp_only">{ar ? 'واتساب + داخل التطبيق' : 'WhatsApp + in-app'}</option><option value="whatsapp_and_email">{ar ? 'واتساب + بريد + داخل التطبيق' : 'WhatsApp + email + in-app'}</option></select></label><label class="text-xs font-bold text-slate-500">{ar ? 'نطاق الفروع' : 'Branch scope'}<select class="mt-1 w-full rounded-lg border-slate-300 text-sm" bind:value={recipient.all_branches}><option value={true}>{ar ? 'جميع الفروع' : 'All branches'}</option><option value={false}>{ar ? 'فروع محددة' : 'Specific branches'}</option></select></label></div>
							{#if !recipient.all_branches}<div class="mt-3 flex flex-wrap gap-2">{#each branches as branch (branch.id)}<label class="flex items-start gap-2 rounded-lg border bg-slate-50 px-3 py-2 text-xs font-semibold"><input class="mt-0.5" type="checkbox" checked={recipient.branch_ids.includes(Number(branch.id))} on:change={() => toggleBranch(recipient, Number(branch.id))} /><span><span class="block">{ar ? branch.name_ar || branch.name_en : branch.name_en || branch.name_ar}</span>{#if ar ? branch.location_ar || branch.location_en : branch.location_en || branch.location_ar}<span class="mt-0.5 block font-normal text-slate-500">{ar ? branch.location_ar || branch.location_en : branch.location_en || branch.location_ar}</span>{/if}</span></label>{/each}</div>{/if}
							<div class="mt-4 flex flex-wrap items-center justify-between gap-3">
								{#if recipient.enabled}
									<div class="flex flex-wrap gap-2">
										<button class="rounded-lg border border-emerald-300 bg-emerald-50 px-3 py-2 text-xs font-bold text-emerald-700 disabled:opacity-50" disabled={!!testingKey || savingKey === `recipient:${recipient.id}`} on:click={() => testRecipient(recipient, 'whatsapp')}>
											{testingKey === `${recipient.id}:whatsapp` ? (ar ? 'جاري الاختبار...' : 'Testing...') : (ar ? 'اختبار واتساب' : 'Test WhatsApp')}
										</button>
										<button class="rounded-lg border border-blue-300 bg-blue-50 px-3 py-2 text-xs font-bold text-blue-700 disabled:opacity-50" disabled={!!testingKey || savingKey === `recipient:${recipient.id}`} on:click={() => testRecipient(recipient, 'email')}>
											{testingKey === `${recipient.id}:email` ? (ar ? 'جاري الاختبار...' : 'Testing...') : (ar ? 'اختبار البريد' : 'Test Email')}
										</button>
										<button class="rounded-lg border border-violet-300 bg-violet-50 px-3 py-2 text-xs font-bold text-violet-700 disabled:opacity-50" disabled={!!testingKey || savingKey === `recipient:${recipient.id}`} on:click={() => testRecipient(recipient, 'in_app')}>
											{testingKey === `${recipient.id}:in_app` ? (ar ? 'جاري الاختبار...' : 'Testing...') : (ar ? 'اختبار داخل التطبيق' : 'Test In-App')}
										</button>
									</div>
								{:else}
									<span class="text-xs text-slate-400">{ar ? 'فعّل المستلم واحفظه لإظهار أزرار الاختبار.' : 'Enable and save the recipient to use test actions.'}</span>
								{/if}
								<button class="rounded-lg bg-orange-500 px-4 py-2 text-sm font-bold text-white disabled:opacity-50" disabled={savingKey === `recipient:${recipient.id}` || !!testingKey || !recipient.contact_ready} on:click={() => saveRecipient(recipient)}>{savingKey === `recipient:${recipient.id}` ? (ar ? 'جاري الحفظ...' : 'Saving...') : (ar ? 'حفظ' : 'Save')}</button>
							</div>
						</article>
					{/each}
				</div>
			</section>
			{/if}
		{/if}
	</div>
</div>

<style>
	.recipient-table {
		counter-reset: recipient-row;
	}

	.recipient-card {
		display: grid;
		grid-template-columns: 2.5rem minmax(10rem, 1fr) minmax(14rem, 1.25fr) minmax(22rem, 2fr) minmax(7rem, 0.6fr) minmax(13rem, 1fr);
		align-items: start;
		gap: 0.75rem;
		padding: 0.625rem 0.75rem;
		transition: background-color 150ms ease;
		counter-increment: recipient-row;
	}

	.recipient-card::before {
		content: counter(recipient-row);
		grid-column: 1;
		grid-row: 1 / span 2;
		color: rgb(100 116 139);
		font-size: 0.75rem;
		font-weight: 700;
		text-align: center;
	}

	.recipient-table-header {
		position: sticky;
		top: 0;
		z-index: 10;
		display: grid;
		grid-template-columns: 2.5rem minmax(10rem, 1fr) minmax(14rem, 1.25fr) minmax(22rem, 2fr) minmax(7rem, 0.6fr) minmax(13rem, 1fr);
		gap: 0.75rem;
		padding: 0.625rem 0.75rem;
		background: rgb(241 245 249);
		border-bottom: 1px solid rgb(203 213 225);
		color: rgb(71 85 105);
		font-size: 0.6875rem;
		font-weight: 800;
		text-transform: uppercase;
	}

	.recipient-table-header > :global(span + span) {
		border-inline-start: 1px solid rgb(203 213 225);
		padding-inline-start: 0.75rem;
	}

	.recipient-card > :global(div:nth-child(2)) {
		grid-column: 4;
		grid-row: 1;
		margin-top: 0;
	}

	.recipient-card > :global(div:first-child) {
		display: contents;
	}

	.recipient-card > :global(div:first-child > div:first-child) {
		grid-column: 2;
		grid-row: 1 / span 2;
	}

	.recipient-card > :global(div:first-child > div:nth-child(2)) {
		grid-column: 3;
		grid-row: 1 / span 2;
		border-inline-start: 1px solid rgb(226 232 240);
		padding-inline-start: 0.75rem;
	}

	.recipient-card > :global(div:first-child > label) {
		grid-column: 5;
		grid-row: 1;
		border-inline-start: 1px solid rgb(226 232 240);
		padding-inline-start: 0.75rem;
	}

	.recipient-card > :global(div:last-child) {
		grid-column: 6;
		grid-row: 1 / span 2;
		margin-top: 0;
		border-inline-start: 1px solid rgb(226 232 240);
		padding-inline-start: 0.75rem;
	}

	.recipient-card > :global(div:nth-child(2)) {
		border-inline-start: 1px solid rgb(226 232 240);
		padding-inline-start: 0.75rem;
	}

	.recipient-card > :global(div:nth-child(3):not(:last-child)) {
		grid-column: 4;
		grid-row: 2;
		margin-top: 0;
		border-inline-start: 1px solid rgb(226 232 240);
		padding-inline-start: 0.75rem;
	}

	.recipient-card:hover {
		background-color: rgb(248 250 252);
	}

	.recipient-card :global(.mt-4) {
		margin-top: 0.625rem;
	}

	.recipient-card :global(.mt-3) {
		margin-top: 0.5rem;
	}

	.recipient-card :global(select) {
		padding-top: 0.375rem;
		padding-bottom: 0.375rem;
		font-size: 0.75rem;
	}

	.recipient-card :global(button) {
		padding-top: 0.375rem;
		padding-bottom: 0.375rem;
	}

	@media (max-width: 1023px) {
		.recipient-table-header {
			display: none;
		}

		.recipient-card {
			display: block;
		}
	}
</style>
