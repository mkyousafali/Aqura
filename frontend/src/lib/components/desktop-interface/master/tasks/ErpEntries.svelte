<script lang="ts">
	import { onMount } from 'svelte';
	import { currentLocale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface ErpEntryRow {
		id: string;
		status: 'pending' | 'completed' | 'cancelled';
		branch_id: number | null;
		branch_name_en: string | null;
		branch_name_ar: string | null;
		ledger_name: string;
		bill_number: string | null;
		voucher_number: string;
		bill_amount: number;
		original_bill_amount: number | null;
		payment_type: 'cash' | 'bank' | 'jv';
		bank_ledger_name: string | null;
		created_by: string;
		created_by_name: string | null;
		created_at: string;
		payment_voucher_number: string | null;
		completed_by: string | null;
		completed_by_name: string | null;
		completed_at: string | null;
	}

	let rows: ErpEntryRow[] = [];
	let loading = true;
	let errorMessage = '';
	// Pending entries are shown as voucher cards; completed ones leave that view and live in the
	// Completed tab (a table).
	let view: 'pending' | 'completed' = 'pending';
	let successMessage = '';

	$: isArabic = $currentLocale === 'ar';
	$: L = (en: string, ar: string) => (isArabic ? ar : en);

	async function loadRows() {
		const requestedView = view;
		loading = true;
		errorMessage = '';
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data, error } = await supabase.rpc('get_erp_entry_tasks', {
				p_branch_id: null,
				p_status: requestedView,
				p_limit: 500
			});
			if (error) throw error;
			if (requestedView !== view) return;
			const list: ErpEntryRow[] = data || [];
			rows = requestedView === 'completed'
				? list.sort((a, b) => (b.completed_at || '').localeCompare(a.completed_at || ''))
				: list;
		} catch (err: any) {
			console.error('Error loading ERP entry tasks:', err);
			errorMessage = err.message || 'Failed to load ERP entry tasks';
			rows = [];
		} finally {
			if (requestedView === view) loading = false;
		}
	}

	function switchView(next: 'pending' | 'completed') {
		if (next === view) return;
		view = next;
		rows = [];
		successMessage = '';
		loadRows();
	}

	function branchName(row: ErpEntryRow): string {
		const name = isArabic ? (row.branch_name_ar || row.branch_name_en) : (row.branch_name_en || row.branch_name_ar);
		return name || '-';
	}

	function formatAmount(n: number): string {
		return (n || 0).toFixed(2);
	}

	// ERP voucher type that settles this entry: BP for bank, CP for cash, JV for a journal voucher.
	function voucherCode(row: ErpEntryRow): 'BP' | 'CP' | 'JV' {
		return row.payment_type === 'bank' ? 'BP' : row.payment_type === 'jv' ? 'JV' : 'CP';
	}

	// Credit side of the voucher: the bank ledger (bank) or the chosen credit account (JV) picked
	// in the Send popup, or Cash.
	function creditAccount(row: ErpEntryRow): string {
		if (row.payment_type !== 'cash') return row.bank_ledger_name || '-';
		return isArabic ? 'نقد' : 'Cash';
	}

	// Text to paste into the ERP voucher's narration field: bill number, PI voucher number, the
	// PI's original amount, and how it was paid. Rows created before original_bill_amount existed fall back
	// to bill_amount.
	function narration(row: ErpEntryRow): string {
		const paid = row.payment_type === 'jv' ? 'Paid by JV' : `Paid from ${row.payment_type === 'bank' ? 'Bank' : 'Cash'}`;
		return `Bill No: ${row.bill_number || '-'} | PI No: ${row.voucher_number} | PI Amount: ${formatAmount(row.original_bill_amount ?? row.bill_amount)} | ${paid}`;
	}

	let copiedId = '';
	let copiedTimer: ReturnType<typeof setTimeout> | null = null;

	async function copyNarration(row: ErpEntryRow) {
		try {
			await navigator.clipboard.writeText(narration(row));
			copiedId = row.id;
			if (copiedTimer) clearTimeout(copiedTimer);
			copiedTimer = setTimeout(() => (copiedId = ''), 1500);
		} catch (err) {
			console.error('Failed to copy narration:', err);
		}
	}

	// Completing an entry: called automatically once "Check match" passes. Saves the verified ERP
	// reference (e.g. BP-2722) on the entry and closes its linked task via complete_erp_entry_task(),
	// so the task leaves My Tasks (desktop + mobile) and the entry moves to the Completed tab.
	let refDrafts: Record<string, string> = {};
	let rowErrors: Record<string, string> = {};
	let savingId = '';

	async function completeEntry(row: ErpEntryRow, reference: string) {
		const user = $currentUser;
		if (!user) {
			rowErrors = { ...rowErrors, [row.id]: L('Not logged in', 'غير مسجل الدخول') };
			return;
		}

		savingId = row.id;
		rowErrors = { ...rowErrors, [row.id]: '' };
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { error } = await supabase.rpc('complete_erp_entry_task', {
				p_erp_entry_task_id: row.id,
				p_voucher_number: reference,
				p_completed_by: user.id,
				p_completed_by_name: user.employeeName || user.username
			});
			if (error) throw error;
			successMessage = L(
				`✓ Matched and completed: ${reference} for ${row.ledger_name.trim()}`,
				`✓ تمت المطابقة والإكمال: ${reference} لـ ${row.ledger_name.trim()}`
			);
			await loadRows();
		} catch (err: any) {
			console.error('Error completing ERP entry:', err);
			rowErrors = { ...rowErrors, [row.id]: err.message || L('Matched, but failed to save', 'تمت المطابقة لكن فشل الحفظ') };
		} finally {
			savingId = '';
		}
	}

	// "Check match & complete": looks the typed CP/BP voucher up in the ERP and checks that it has a debit line
	// on this entry's supplier ledger AND a matching credit on the bank ledger (or a cash ledger), both
	// for the amount entered when the task was created (bill_amount -- deliberately not the original
	// PI amount). The ERP lookup is read-only; a pass completes the entry, anything else changes nothing.
	interface MatchResult { ok: boolean; message: string }
	let matchResults: Record<string, MatchResult | undefined> = {};
	let checkingId = '';
	const erpBranchIds = new Map<number, number>();

	function clearMatch(id: string) {
		if (matchResults[id]) matchResults = { ...matchResults, [id]: undefined };
	}

	async function checkMatch(row: ErpEntryRow) {
		const setResult = (ok: boolean, message: string) => {
			matchResults = { ...matchResults, [row.id]: { ok, message } };
		};

		const reference = (refDrafts[row.id] || '').trim();
		if (!reference) return setResult(false, L('Enter the ERP reference number first', 'أدخل رقم مرجع ERP أولاً'));

		const parsed = /^(CP|BP|JV)?[\s\-#]*(\d+)$/i.exec(reference);
		if (!parsed) {
			return setResult(false, L('Enter a voucher number like BP-2891 or 2891', 'أدخل رقم سند مثل BP-2891 أو 2891'));
		}
		const expectedType = voucherCode(row);
		const typedType = parsed[1]?.toUpperCase();
		const voucherNo = parsed[2].replace(/^0+(?=\d)/, '');
		if (typedType && typedType !== expectedType) {
			return setResult(
				false,
				L(
					`This is a ${row.payment_type === 'jv' ? 'JV' : row.payment_type} entry, so it needs a ${expectedType} voucher, but ${typedType} was entered`,
					`هذا إدخال ${row.payment_type === 'bank' ? 'بنكي' : row.payment_type === 'jv' ? 'قيد يومية' : 'نقدي'} ويحتاج سند ${expectedType} لكن تم إدخال ${typedType}`
				)
			);
		}
		if (row.branch_id == null) return setResult(false, L('This entry has no branch', 'هذا الإدخال بلا فرع'));

		checkingId = row.id;
		try {
			let erpBranchId = erpBranchIds.get(row.branch_id);
			if (erpBranchId == null) {
				const { supabase } = await import('$lib/utils/supabase');
				const { data, error } = await supabase
					.from('erp_connections')
					.select('erp_branch_id')
					.eq('branch_id', row.branch_id)
					.eq('is_active', true)
					.single();
				if (error || data?.erp_branch_id == null) throw new Error(L('No ERP connection for this branch', 'لا يوجد اتصال ERP لهذا الفرع'));
				erpBranchId = Number(data.erp_branch_id);
				erpBranchIds.set(row.branch_id, erpBranchId);
			}

			// expectedType is CP/BP/JV and voucherNo is digits-only (both validated above), so this is safe to inline.
			const sql = `
				SELECT l.LedgerName, g.AccGroupName, ad.Debit, ad.Credit
				FROM AccTransactionMaster m
				INNER JOIN AccTransactionDetails ad ON ad.AccTransactionMasterID = m.AccTransactionMasterID AND ad.BranchID = m.BranchID
				LEFT JOIN AccLedgers l ON l.LedgerID = ad.LedgerID AND l.BranchID = ad.BranchID
				LEFT JOIN AccGroups g ON g.AccGroupID = l.AccGroupID AND g.BranchID = l.BranchID
				WHERE m.BranchID = ${erpBranchId} AND m.VoucherType = '${expectedType}' AND m.VoucherNumber = '${voucherNo}' AND m.IsActive = 1
			`;
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'query', branchId: row.branch_id, sql })
			});
			const result = await response.json();
			if (!result.success) throw new Error(result.error || L('ERP query failed', 'فشل استعلام ERP'));

			const lines: { LedgerName: string | null; AccGroupName: string | null; Debit: number; Credit: number }[] = result.recordset || [];
			const label = `${expectedType} ${voucherNo}`;
			if (lines.length === 0) {
				return setResult(false, L(`${label} was not found in the ERP for this branch`, `السند ${label} غير موجود في ERP لهذا الفرع`));
			}

			const amount = formatAmount(row.bill_amount);
			const supplierDebits = lines
				.filter((l) => (l.LedgerName || '').trim() === row.ledger_name.trim() && Number(l.Debit) > 0)
				.map((l) => Number(l.Debit));

			if (supplierDebits.some((d) => Math.abs(d - row.bill_amount) < 0.005)) {
				// Credit side: the bank ledger (bank) or credit account (JV) picked in the Send popup, or --
				// for cash, where no specific cash ledger was recorded -- any ledger in the ERP's
				// "Cash In hand" group.
				const bankName = (row.bank_ledger_name || '').trim();
				const creditOk = lines.some(
					(l) =>
						Number(l.Credit) > 0 &&
						Math.abs(Number(l.Credit) - row.bill_amount) < 0.005 &&
						(row.payment_type === 'cash'
							? (l.AccGroupName || '').toLowerCase().includes('cash')
							: (l.LedgerName || '').trim() === bankName)
				);
				const creditLabel = row.payment_type === 'cash' ? L('Cash', 'نقد') : bankName || '-';
				if (creditOk) {
					setResult(
						true,
						L(
							`Matched: ${label} has ${amount} for this supplier, credited to ${creditLabel}`,
							`مطابق: السند ${label} يحتوي ${amount} لهذا المورد، دائن ${creditLabel}`
						)
					);
				} else {
					setResult(
						false,
						L(
							`Supplier line matches, but ${label} has no ${amount} credit on ${creditLabel}`,
							`سطر المورد مطابق، لكن السند ${label} لا يحتوي دائن ${amount} على ${creditLabel}`
						)
					);
				}
			} else if (supplierDebits.length > 0) {
				setResult(
					false,
					L(
						`Not matched: task amount is ${amount}, but ${label} has ${supplierDebits.map(formatAmount).join(', ')} for this supplier`,
						`غير مطابق: مبلغ المهمة ${amount} لكن السند ${label} يحتوي ${supplierDebits.map(formatAmount).join('، ')} لهذا المورد`
					)
				);
			} else {
				setResult(false, L(`Not matched: this supplier is not on ${label}`, `غير مطابق: هذا المورد غير موجود في السند ${label}`));
			}
			// A pass completes the entry right away (no separate confirm step).
			if (matchResults[row.id]?.ok) await completeEntry(row, `${expectedType}-${voucherNo}`);
		} catch (err: any) {
			console.error('Error checking ERP voucher match:', err);
			setResult(false, err.message || L('Failed to check', 'فشل التحقق'));
		} finally {
			checkingId = '';
		}
	}

	function formatDateTime(iso: string | null): string {
		if (!iso) return '-';
		const d = new Date(iso);
		if (isNaN(d.getTime())) return '-';
		const day = String(d.getDate()).padStart(2, '0');
		const month = String(d.getMonth() + 1).padStart(2, '0');
		const time = d.toLocaleTimeString(isArabic ? 'ar' : 'en', { hour: '2-digit', minute: '2-digit' });
		return `${day}-${month}-${d.getFullYear()} ${time}`;
	}

	onMount(loadRows);
</script>

<div class="erp-entries">
	<div class="header">
		<h2>{isArabic ? 'مهام إدخال ERP' : 'ERP Entries'}</h2>
		<div class="header-actions">
			<div class="tabs">
				<button type="button" class="tab-btn" class:active={view === 'pending'} on:click={() => switchView('pending')}>
					{L('Pending', 'قيد الانتظار')}
				</button>
				<button type="button" class="tab-btn" class:active={view === 'completed'} on:click={() => switchView('completed')}>
					{L('Completed', 'المكتملة')}
				</button>
			</div>
			<button class="refresh-btn" type="button" on:click={loadRows} disabled={loading}>
				{loading ? (isArabic ? 'جارٍ التحميل...' : 'Loading...') : (isArabic ? 'تحديث' : 'Refresh')}
			</button>
		</div>
	</div>

	{#if errorMessage}
		<div class="error-banner">{errorMessage}</div>
	{/if}
	{#if successMessage}
		<div class="success-banner">{successMessage}</div>
	{/if}

	{#if loading && rows.length === 0}
		<div class="empty-state">{isArabic ? 'جارٍ التحميل...' : 'Loading...'}</div>
	{:else if rows.length === 0}
		<div class="empty-state">
			{view === 'pending'
				? L('No pending ERP entries', 'لا توجد إدخالات ERP معلقة')
				: L('No completed ERP entries yet', 'لا توجد إدخالات ERP مكتملة بعد')}
		</div>
	{:else if view === 'completed'}
		<div class="table-wrapper">
			<table class="completed-table">
				<thead>
					<tr>
						<th>{L('Branch', 'الفرع')}</th>
						<th>{L('Ledger Name', 'اسم الحساب')}</th>
						<th>{L('Bill No', 'رقم الفاتورة')}</th>
						<th>{L('PI Voucher', 'سند الشراء')}</th>
						<th class="num">{L('Amount', 'المبلغ')}</th>
						<th>{L('Payment', 'الدفع')}</th>
						<th>{L('Credit Account', 'الحساب الدائن')}</th>
						<th>{L('Created By', 'أنشأها')}</th>
						<th>{L('Created', 'تاريخ الإنشاء')}</th>
						<th>{L('ERP Reference', 'مرجع ERP')}</th>
						<th>{L('Completed By', 'أكملها')}</th>
						<th>{L('Completed', 'تاريخ الإكمال')}</th>
					</tr>
				</thead>
				<tbody>
					{#each rows as row (row.id)}
						<tr>
							<td>{branchName(row)}</td>
							<td dir="auto">{row.ledger_name}</td>
							<td>{row.bill_number || '-'}</td>
							<td>{row.voucher_number}</td>
							<td class="num">{formatAmount(row.bill_amount)}</td>
							<td>{row.payment_type === 'bank' ? L('Bank', 'بنك') : row.payment_type === 'jv' ? 'JV' : L('Cash', 'نقد')}</td>
							<td dir="auto">{row.bank_ledger_name || '-'}</td>
							<td>{row.created_by_name || '-'}</td>
							<td>{formatDateTime(row.created_at)}</td>
							<td class="ref-cell">{row.payment_voucher_number || '-'}</td>
							<td>{row.completed_by_name || '-'}</td>
							<td>{formatDateTime(row.completed_at)}</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{:else}
		<div class="voucher-list">
			{#each rows as row (row.id)}
				<div class="voucher-card">
					<div class="voucher-head">
						<div class="voucher-title">
							<span class="voucher-type">{voucherCode(row)}</span>
							<span>
								{row.payment_type === 'bank'
									? L('Bank Payment Voucher', 'سند صرف بنكي')
									: row.payment_type === 'jv'
										? L('Journal Voucher', 'قيد يومية')
										: L('Cash Payment Voucher', 'سند صرف نقدي')}
							</span>
						</div>
						<span class="status-badge status-{row.status}">{row.status}</span>
					</div>

					<div class="voucher-meta">
						<span><b>{L('Branch', 'الفرع')}:</b> {branchName(row)}</span>
						<span><b>{L('PI Voucher', 'سند الشراء')}:</b> {row.voucher_number}</span>
						<span><b>{L('Bill No', 'رقم الفاتورة')}:</b> {row.bill_number || '-'}</span>
						<span><b>{L('Created', 'أنشئت')}:</b> {row.created_by_name || '-'} · {formatDateTime(row.created_at)}</span>
					</div>

					<table class="entry-lines">
						<thead>
							<tr>
								<th>{L('Account', 'الحساب')}</th>
								<th class="num">{L('Dr', 'مدين')}</th>
								<th class="num">{L('Cr', 'دائن')}</th>
							</tr>
						</thead>
						<tbody>
							<tr>
								<td dir="auto">{row.ledger_name}</td>
								<td class="num">{formatAmount(row.bill_amount)}</td>
								<td class="num"></td>
							</tr>
							<tr>
								<td dir="auto" class="cr-account">{creditAccount(row)}</td>
								<td class="num"></td>
								<td class="num">{formatAmount(row.bill_amount)}</td>
							</tr>
						</tbody>
						<tfoot>
							<tr>
								<td>{L('Total', 'الإجمالي')}</td>
								<td class="num">{formatAmount(row.bill_amount)}</td>
								<td class="num">{formatAmount(row.bill_amount)}</td>
							</tr>
						</tfoot>
					</table>

					<div class="voucher-narration">
						<span class="narration-label">{L('Narration', 'البيان')}</span>
						<span class="narration-text">{narration(row)}</span>
						<button class="copy-btn" type="button" on:click={() => copyNarration(row)}>
							{copiedId === row.id ? L('Copied', 'تم النسخ') : L('Copy', 'نسخ')}
						</button>
					</div>

					{#if row.status === 'pending'}
						<div class="voucher-ref">
							<label class="ref-label" for="ref-{row.id}">{L('ERP Reference No.', 'رقم مرجع ERP')}</label>
							<input
								id="ref-{row.id}"
								class="ref-input"
								type="text"
								placeholder={L(`${voucherCode(row)} voucher no.`, `رقم سند ${voucherCode(row)}`)}
								bind:value={refDrafts[row.id]}
								on:input={() => clearMatch(row.id)}
								disabled={savingId === row.id}
							/>
							<button
								class="check-btn"
								type="button"
								on:click={() => checkMatch(row)}
								disabled={checkingId === row.id || savingId === row.id}
							>
								{checkingId === row.id
									? L('Checking...', 'جارٍ التحقق...')
									: savingId === row.id
										? L('Completing...', 'جارٍ الإكمال...')
										: L('Check match & complete', 'تحقق وأكمل')}
							</button>
							{#if rowErrors[row.id]}
								<span class="ref-error">{rowErrors[row.id]}</span>
							{/if}
							{#if matchResults[row.id]}
								<span class="match-result" class:match-ok={matchResults[row.id]?.ok} class:match-bad={!matchResults[row.id]?.ok}>
									{matchResults[row.id]?.ok ? '✓' : '✗'} {matchResults[row.id]?.message}
								</span>
							{/if}
						</div>
					{/if}
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.erp-entries {
		width: 100%;
		height: 100%;
		overflow: hidden;
		padding: 1.25rem;
		background: linear-gradient(135deg, #f0f7ff 0%, #eef2ff 50%, #f5f7fa 100%);
		display: flex;
		flex-direction: column;
		gap: 1rem;
		box-sizing: border-box;
	}

	.header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		flex-wrap: wrap;
		gap: 0.75rem;
	}
	.header h2 {
		margin: 0;
		font-size: 1.1rem;
		font-weight: 700;
		color: #1e3a8a;
	}
	.header-actions {
		display: flex;
		align-items: center;
		gap: 0.6rem;
	}
	.tabs {
		display: flex;
		border: 1px solid rgba(147, 197, 253, 0.9);
		border-radius: 8px;
		overflow: hidden;
		background: #fff;
	}
	.tab-btn {
		padding: 0.4rem 1rem;
		border: none;
		background: transparent;
		color: #1e3a8a;
		font-size: 0.78rem;
		font-weight: 700;
		cursor: pointer;
	}
	.tab-btn.active { background: linear-gradient(135deg, #2563eb, #1d4ed8); color: #fff; }
	.refresh-btn {
		padding: 0.4rem 0.9rem;
		border: none;
		border-radius: 8px;
		background: linear-gradient(135deg, #2563eb, #1d4ed8);
		color: #fff;
		font-weight: 700;
		font-size: 0.78rem;
		cursor: pointer;
	}
	.refresh-btn:disabled { opacity: 0.6; cursor: not-allowed; }

	.error-banner {
		padding: 0.6rem 0.9rem;
		border-radius: 8px;
		background: #fee2e2;
		color: #991b1b;
		font-size: 0.82rem;
		font-weight: 600;
	}

	.success-banner {
		padding: 0.6rem 0.9rem;
		border-radius: 8px;
		background: #dcfce7;
		color: #166534;
		font-size: 0.82rem;
		font-weight: 700;
	}

	.table-wrapper { flex: 1; min-height: 0; overflow: auto; border-radius: 12px; border: 1px solid rgba(191, 219, 254, 0.9); background: #fff; }
	.completed-table { width: 100%; border-collapse: collapse; font-size: 0.8rem; }
	.completed-table thead th {
		position: sticky;
		top: 0;
		z-index: 2;
		text-align: left;
		padding: 0.55rem 0.7rem;
		background: #dbeafe;
		color: #1e3a8a;
		font-weight: 700;
		text-transform: uppercase;
		font-size: 0.66rem;
		letter-spacing: 0.3px;
		border-bottom: 1px solid rgba(147, 197, 253, 0.7);
		white-space: nowrap;
	}
	.completed-table tbody td {
		padding: 0.5rem 0.7rem;
		border-bottom: 1px solid rgba(226, 232, 240, 0.8);
		color: #1e293b;
		white-space: nowrap;
	}
	.completed-table tbody tr:hover { background: #f8fafc; }
	.completed-table .num { text-align: right; font-weight: 700; }
	.completed-table .ref-cell { font-weight: 700; color: #166534; }

	.empty-state {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		color: #64748b;
		font-size: 0.9rem;
	}

	.voucher-list {
		flex: 1;
		min-height: 0;
		overflow: auto;
		display: flex;
		flex-direction: column;
		gap: 0.9rem;
		padding-right: 0.25rem;
	}
	.voucher-card {
		background: #fff;
		border: 1px solid rgba(191, 219, 254, 0.9);
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(30, 58, 138, 0.06);
		overflow: hidden;
		flex-shrink: 0;
	}
	.voucher-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.6rem 0.9rem;
		background: #dbeafe;
		color: #1e3a8a;
		font-weight: 700;
		font-size: 0.85rem;
	}
	.voucher-title { display: flex; align-items: center; gap: 0.5rem; }
	.voucher-type {
		padding: 0.1rem 0.5rem;
		border-radius: 6px;
		background: #1e3a8a;
		color: #fff;
		font-size: 0.72rem;
		letter-spacing: 0.5px;
	}
	.voucher-meta {
		display: flex;
		flex-wrap: wrap;
		gap: 0.3rem 1.4rem;
		padding: 0.6rem 0.9rem;
		font-size: 0.76rem;
		color: #334155;
		border-bottom: 1px solid rgba(226, 232, 240, 0.9);
	}
	.voucher-meta b { color: #1e3a8a; }

	.entry-lines { width: 100%; border-collapse: collapse; font-size: 0.82rem; }
	.entry-lines th {
		text-align: left;
		padding: 0.4rem 0.9rem;
		font-size: 0.68rem;
		text-transform: uppercase;
		letter-spacing: 0.3px;
		color: #64748b;
		border-bottom: 1px solid rgba(226, 232, 240, 0.9);
	}
	.entry-lines td { padding: 0.45rem 0.9rem; color: #1e293b; }
	.entry-lines tbody tr + tr td { border-top: 1px dashed rgba(226, 232, 240, 0.9); }
	.entry-lines .cr-account { padding-left: 2.2rem; }
	.entry-lines .num { text-align: right; width: 130px; font-variant-numeric: tabular-nums; font-weight: 700; }
	.entry-lines tfoot td {
		border-top: 2px solid rgba(147, 197, 253, 0.9);
		font-weight: 700;
		color: #1e3a8a;
		background: #f8fafc;
	}

	.voucher-narration {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		padding: 0.6rem 0.9rem;
		background: #f8fafc;
		border-top: 1px solid rgba(226, 232, 240, 0.9);
		font-size: 0.8rem;
	}
	.narration-label { font-weight: 700; color: #1e3a8a; }
	.narration-text { flex: 1; color: #1e293b; user-select: text; }

	.voucher-ref {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.6rem;
		padding: 0.6rem 0.9rem;
		border-top: 1px solid rgba(226, 232, 240, 0.9);
		font-size: 0.8rem;
	}
	.ref-label { font-weight: 700; color: #1e3a8a; }
	.ref-input {
		width: 200px;
		padding: 0.3rem 0.6rem;
		border-radius: 6px;
		border: 1px solid rgba(147, 197, 253, 0.9);
		font-size: 0.8rem;
		color: #1e293b;
	}
	.ref-input:focus { outline: none; border-color: #2563eb; }
	.ref-error { color: #dc2626; font-weight: 600; font-size: 0.76rem; }
	.check-btn {
		padding: 0.3rem 0.8rem;
		border: 1px solid rgba(147, 197, 253, 0.9);
		border-radius: 6px;
		background: #eff6ff;
		color: #1d4ed8;
		font-size: 0.74rem;
		font-weight: 700;
		cursor: pointer;
	}
	.check-btn:hover:not(:disabled) { background: #dbeafe; }
	.check-btn:disabled { opacity: 0.6; cursor: not-allowed; }
	.match-result { flex-basis: 100%; font-size: 0.78rem; font-weight: 700; }
	.match-ok { color: #166534; }
	.match-bad { color: #b91c1c; }
	.copy-btn {
		padding: 0.2rem 0.6rem;
		border: 1px solid rgba(147, 197, 253, 0.9);
		border-radius: 6px;
		background: #eff6ff;
		color: #1d4ed8;
		font-size: 0.68rem;
		font-weight: 700;
		cursor: pointer;
	}
	.copy-btn:hover { background: #dbeafe; }

	.status-badge {
		display: inline-block;
		padding: 0.2rem 0.6rem;
		border-radius: 999px;
		font-size: 0.7rem;
		font-weight: 700;
		text-transform: capitalize;
	}
	.status-pending { background: #fef3c7; color: #92400e; }
	.status-completed { background: #dcfce7; color: #166534; }
	.status-cancelled { background: #fee2e2; color: #991b1b; }
</style>
