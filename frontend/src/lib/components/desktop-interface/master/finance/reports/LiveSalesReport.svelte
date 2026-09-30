<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentLocale } from '$lib/i18n';

	export let mobile = false;

	interface BranchSales {
		branch_id: number;
		branch_name: string;
		total_amount: number;
		total_bills: number;
		total_return: number;
		status: 'online' | 'unavailable';
		error?: string;
	}

	let loading = true;
	let todaySales: BranchSales[] = [];
	let yesterdaySales: BranchSales[] = [];
	$: todayTotal = todaySales.filter((branch) => branch.status === 'online').reduce((sum, branch) => sum + branch.total_amount, 0);
	$: todayBills = todaySales.filter((branch) => branch.status === 'online').reduce((sum, branch) => sum + branch.total_bills, 0);
	$: yesterdayTotal = yesterdaySales.filter((branch) => branch.status === 'online').reduce((sum, branch) => sum + branch.total_amount, 0);
	$: yesterdayBills = yesterdaySales.filter((branch) => branch.status === 'online').reduce((sum, branch) => sum + branch.total_bills, 0);

	$: isArabic = $currentLocale === 'ar';
	const ui = (english: string, arabic: string) => isArabic ? arabic : english;
	const money = (value: number) => new Intl.NumberFormat(
		isArabic ? 'ar-SA-u-nu-arab' : 'en-SA',
		{ maximumFractionDigits: 2 }
	).format(value || 0);

	function saudiDate(offsetDays = 0) {
		const now = new Date();
		const saudi = new Date(now.getTime() + (3 * 60 + now.getTimezoneOffset()) * 60_000);
		saudi.setDate(saudi.getDate() + offsetDays);
		const year = saudi.getFullYear();
		const month = String(saudi.getMonth() + 1).padStart(2, '0');
		const day = String(saudi.getDate()).padStart(2, '0');
		return `${year}-${month}-${day}`;
	}

	function numberValue(row: any, ...keys: string[]) {
		for (const key of keys) {
			if (row?.[key] !== undefined && row?.[key] !== null) return Number(row[key]) || 0;
		}
		return 0;
	}

	async function queryBranch(branch: any, today: string, yesterday: string) {
		const sql = `
			SELECT
				CONVERT(varchar(10), CAST(TransactionDate AS date), 23) AS SaleDate,
				SUM(CASE WHEN VoucherType = 'SI' THEN GrandTotal ELSE 0 END) AS GrossSales,
				SUM(CASE WHEN VoucherType = 'SI' THEN 1 ELSE 0 END) AS GrossBills,
				SUM(CASE WHEN VoucherType = 'SR' THEN GrandTotal ELSE 0 END) AS ReturnAmount,
				SUM(CASE WHEN VoucherType = 'SR' THEN 1 ELSE 0 END) AS ReturnBills
			FROM InvTransactionMaster
			WHERE CAST(TransactionDate AS date) IN ('${yesterday}', '${today}')
			  AND VoucherType IN ('SI', 'SR')
			GROUP BY CAST(TransactionDate AS date)
			ORDER BY CAST(TransactionDate AS date);
		`;

		const response = await fetch('/api/erp-bridge-proxy', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ branchId: branch.branch_id, sql })
		});
		if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
		const payload = await response.json();
		return payload.recordset || payload.records || payload || [];
	}

	function salesRow(branch: any, records: any[], date: string): BranchSales {
		const row = records.find((item) => String(item.SaleDate ?? item.saleDate ?? item.saledate ?? '').slice(0, 10) === date) || {};
		const gross = numberValue(row, 'GrossSales', 'grossSales', 'grosssales');
		const returns = numberValue(row, 'ReturnAmount', 'returnAmount', 'returnamount');
		const grossBills = numberValue(row, 'GrossBills', 'grossBills', 'grossbills');
		const returnBills = numberValue(row, 'ReturnBills', 'returnBills', 'returnbills');
		return {
			branch_id: Number(branch.branch_id),
			branch_name: branch.branch_name || `Branch ${branch.branch_id}`,
			total_amount: gross - returns,
			total_bills: grossBills - returnBills,
			total_return: returns,
			status: 'online'
		};
	}

	function unavailableRow(branch: any, error: unknown): BranchSales {
		return {
			branch_id: Number(branch.branch_id),
			branch_name: branch.branch_name || `Branch ${branch.branch_id}`,
			total_amount: 0,
			total_bills: 0,
			total_return: 0,
			status: 'unavailable',
			error: error instanceof Error ? error.message : String(error)
		};
	}

	async function loadLiveSales() {
		const today = saudiDate();
		const yesterday = saudiDate(-1);
		const { data: connections, error } = await supabase
			.from('erp_connections')
			.select('branch_id, branch_name')
			.eq('is_active', true)
			.order('branch_id');
		if (error) throw error;

		const results = await Promise.all((connections || []).map(async (branch: any) => {
			try {
				const records = await queryBranch(branch, today, yesterday);
				return {
					today: salesRow(branch, records, today),
					yesterday: salesRow(branch, records, yesterday)
				};
			} catch (queryError) {
				return {
					today: unavailableRow(branch, queryError),
					yesterday: unavailableRow(branch, queryError)
				};
			}
		}));
		todaySales = results.map((result) => result.today);
		yesterdaySales = results.map((result) => result.yesterday);
	}

	async function refresh() {
		loading = true;
		try {
			await loadLiveSales();
		} catch (error) {
			console.error('Unable to load sales report:', error);
		} finally {
			loading = false;
		}
	}

	onMount(refresh);
</script>

<div class:mobile class="live-report" dir={isArabic ? 'rtl' : 'ltr'}>
	<header>
		<div>
			<h2>{ui('Sales Report', 'تقرير المبيعات')}</h2>
			<p>{ui('Live ERP tunnel data for today and yesterday', 'بيانات مباشرة من نظام ERP لليوم والأمس')}</p>
		</div>
		<button on:click={refresh} disabled={loading}>{loading ? ui('Loading…', 'جارٍ التحميل…') : ui('Refresh', 'تحديث')}</button>
	</header>

	{#if loading}
		<div class="loading">{ui('Loading live branch data…', 'جارٍ تحميل بيانات الفروع المباشرة…')}</div>
	{:else}
		<section>
			<h3>{ui('Today — ERP Sales', 'اليوم — مبيعات ERP')}</h3>
			<div class="total-card">
				<span>{ui('Total sales — all branches', 'إجمالي المبيعات — جميع الفروع')}</span>
				<strong>{money(todayTotal)} <small>{ui('SAR', 'ر.س')}</small></strong>
				<em>{todayBills} {ui('bills', 'فاتورة')}</em>
			</div>
			<h4>{ui('Branch breakdown', 'تفصيل الفروع')}</h4>
			<div class="grid">
				{#each todaySales as branch}{@render BranchCard(branch)}{/each}
			</div>
		</section>
		<section>
			<h3>{ui('Yesterday — ERP Sales', 'الأمس — مبيعات ERP')}</h3>
			<div class="total-card">
				<span>{ui('Total sales — all branches', 'إجمالي المبيعات — جميع الفروع')}</span>
				<strong>{money(yesterdayTotal)} <small>{ui('SAR', 'ر.س')}</small></strong>
				<em>{yesterdayBills} {ui('bills', 'فاتورة')}</em>
			</div>
			<h4>{ui('Branch breakdown', 'تفصيل الفروع')}</h4>
			<div class="grid">
				{#each yesterdaySales as branch}{@render BranchCard(branch)}{/each}
			</div>
		</section>
	{/if}
</div>

{#snippet BranchCard(branch: BranchSales)}
	<article class:offline={branch.status === 'unavailable'}>
		<div class="branch-head">
			<strong>{branch.branch_name}</strong>
			<span class:bad={branch.status === 'unavailable'}>{branch.status === 'online' ? ui('Live', 'مباشر') : ui('Unavailable', 'غير متاح')}</span>
		</div>
		<div class="amount">{money(branch.total_amount)} <small>{ui('SAR', 'ر.س')}</small></div>
		{#if branch.status === 'online'}
			<div class="details">
				<span>{branch.total_bills} {ui('bills', 'فاتورة')}</span>
				<span>{ui('Returns', 'المرتجعات')}: {money(branch.total_return)}</span>
				<span>{ui('Basket', 'المتوسط')}: {money(branch.total_bills > 0 ? branch.total_amount / branch.total_bills : 0)}</span>
			</div>
		{/if}
		{#if branch.error}<p class="error" title={branch.error}>{ui('Branch connection failed', 'فشل اتصال الفرع')}</p>{/if}
	</article>
{/snippet}

<style>
	.live-report { padding: 1.25rem; min-height: 100%; background: #f5f8fb; color: #16324a; }
	header { display: flex; justify-content: space-between; align-items: center; gap: 1rem; margin-bottom: 1.25rem; }
	h2 { margin: 0; font-size: 1.5rem; }
	header p { margin: .3rem 0 0; color: #64748b; }
	button { border: 0; border-radius: .65rem; padding: .7rem 1.2rem; background: #0787a8; color: white; font-weight: 700; cursor: pointer; }
	button:disabled { opacity: .6; cursor: wait; }
	section { background: white; border: 1px solid #dbe5ed; border-radius: 1rem; padding: 1rem; margin-bottom: 1rem; box-shadow: 0 4px 14px rgba(15, 48, 73, .06); }
	h3 { margin: 0 0 1rem; font-size: 1rem; }
	h4 { margin: 1rem 0 .65rem; color: #475569; font-size: .82rem; text-transform: uppercase; letter-spacing: .04em; }
	.total-card { display: grid; grid-template-columns: 1fr auto; align-items: center; gap: .25rem 1rem; padding: 1rem; border-radius: .85rem; background: linear-gradient(135deg, #073b5c, #0787a8); color: white; }
	.total-card span { font-size: .85rem; opacity: .85; }
	.total-card strong { grid-row: span 2; font-size: 1.8rem; }
	.total-card strong small { font-size: .75rem; opacity: .75; }
	.total-card em { font-size: .75rem; opacity: .8; font-style: normal; }
	.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .8rem; }
	article { border: 1px solid #cfe8df; border-inline-start: 4px solid #0ca678; border-radius: .8rem; padding: .9rem; background: #f8fffc; }
	article.offline { border-color: #f2c7c7; border-inline-start-color: #dc2626; background: #fff8f8; }
	.branch-head { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
	.branch-head span { padding: .18rem .45rem; border-radius: 999px; background: #d7f7e9; color: #087f5b; font-size: .7rem; font-weight: 700; }
	.branch-head span.bad { background: #fee2e2; color: #b91c1c; }
	.amount { margin: .7rem 0; font-size: 1.45rem; font-weight: 800; color: #0f766e; }
	.amount small { font-size: .7rem; color: #64748b; }
	.details { display: flex; flex-wrap: wrap; gap: .65rem; color: #64748b; font-size: .78rem; }
	.error { margin: .5rem 0 0; color: #b91c1c; font-size: .75rem; }
	.loading { display: grid; place-items: center; min-height: 240px; color: #64748b; }
	.mobile { padding: .7rem; }
	.mobile header { align-items: flex-start; }
	.mobile .grid { grid-template-columns: 1fr; }
	@media (max-width: 640px) { header { align-items: flex-start; } .grid { grid-template-columns: 1fr; } }
</style>
