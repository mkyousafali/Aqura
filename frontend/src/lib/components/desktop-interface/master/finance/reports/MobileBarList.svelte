<script lang="ts">
	import { _ as t, currentLocale } from '$lib/i18n';
	import { iconUrlMap } from '$lib/stores/iconStore';

	interface BarItem {
		label: string;
		amount: number;
		bills?: number | null;
		totalReturn?: number | null;
		previousAvg?: number | null;
		currentAvg?: number | null;
	}

	export let items: BarItem[] = [];
	/** Show the bills / basket / return sub-line under each bar */
	export let showDetails = true;
	/** Show the previous / current month average chips under each bar */
	export let showAverages = false;

	// One hue for every bar: length already encodes magnitude, so colouring by
	// rank would double-encode it and repaint rows whenever the ranking shifts.
	const BAR_COLOR = '#059669';

	$: max = items.reduce((m, i) => Math.max(m, i.amount || 0), 0);

	function pct(amount: number): number {
		if (!max || max <= 0) return 0;
		return Math.max((amount / max) * 100, 1.5); // keep a sliver visible at zero
	}

	function formatCurrency(amount: number): string {
		return new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA-u-nu-arab' : 'en-US', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		}).format(amount || 0);
	}

	function formatInteger(amount: number): string {
		return new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA-u-nu-arab' : 'en-US').format(amount || 0);
	}

	function returnPct(item: BarItem): string {
		const ret = item.totalReturn || 0;
		const gross = (item.amount || 0) + ret;
		return new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA-u-nu-arab' : 'en-US', {
			minimumFractionDigits: 1,
			maximumFractionDigits: 1
		}).format(gross > 0 ? (ret / gross) * 100 : 0);
	}

	function basket(item: BarItem): number {
		return item.bills && item.bills > 0 ? item.amount / item.bills : 0;
	}
</script>

<div class="bar-list">
	{#each items as item}
		<div class="bar-row">
			<div class="row-top">
				<span class="row-label">{item.label}</span>
				<span class="row-value">
					<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="cur-icon" />
					{formatCurrency(item.amount)}
				</span>
			</div>

			<div class="track">
				<div class="fill" style="width: {pct(item.amount)}%; background-color: {BAR_COLOR};"></div>
			</div>

			{#if showDetails}
				<div class="row-meta">
					{#if item.bills != null}
						<span class="meta-item">{formatInteger(item.bills)} {$t('reports.bills')}</span>
						<span class="meta-sep">·</span>
						<span class="meta-item">
							{$t('reports.basket')}
							<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="cur-icon-xs" />
							{formatCurrency(basket(item))}
						</span>
					{/if}
					{#if item.totalReturn != null}
						<span class="meta-sep">·</span>
						<span class="meta-item meta-return">{$t('reports.return')} {returnPct(item)}%</span>
					{/if}
				</div>
			{/if}

			{#if showAverages && (item.previousAvg != null || item.currentAvg != null)}
				<div class="row-chips">
					{#if item.previousAvg != null}
						<span class="chip chip-prev">
							{$t('reports.previous')}
							<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="cur-icon-xs" />
							{formatCurrency(item.previousAvg)}
						</span>
					{/if}
					{#if item.currentAvg != null}
						<span class="chip chip-curr">
							{$t('reports.current')}
							<img src={$iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png'} alt="SAR" class="cur-icon-xs" />
							{formatCurrency(item.currentAvg)}
						</span>
					{/if}
				</div>
			{/if}
		</div>
	{/each}
</div>

<style>
	.bar-list {
		display: flex;
		flex-direction: column;
		gap: 0.7rem;
	}

	.bar-row {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.row-top {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: 0.5rem;
	}

	.row-label {
		font-size: 0.72rem;
		font-weight: 600;
		color: #374151;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.row-value {
		display: flex;
		align-items: center;
		gap: 0.15rem;
		font-size: 0.78rem;
		font-weight: 700;
		color: #111827;
		white-space: nowrap;
		font-variant-numeric: tabular-nums;
	}

	/* Recessive track; the fill is the only data ink */
	.track {
		height: 10px;
		width: 100%;
		background: #f1f5f9;
		border-radius: 5px;
		overflow: hidden;
	}

	.fill {
		height: 100%;
		/* square at the baseline, rounded at the data end */
		border-radius: 0 4px 4px 0;
		transition: width 0.3s ease;
	}

	.row-meta {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.25rem;
		font-size: 0.6rem;
		color: #6b7280;
	}

	.meta-item {
		display: inline-flex;
		align-items: center;
		gap: 0.15rem;
	}

	.meta-sep {
		color: #d1d5db;
	}

	.meta-return {
		color: #b91c1c;
	}

	.row-chips {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
		margin-top: 0.1rem;
	}

	.chip {
		display: inline-flex;
		align-items: center;
		gap: 0.15rem;
		padding: 0.1rem 0.35rem;
		border-radius: 999px;
		font-size: 0.55rem;
		font-weight: 600;
		white-space: nowrap;
	}

	.chip-prev {
		background: #eef2ff;
		color: #4338ca;
	}

	.chip-curr {
		background: #ecfdf5;
		color: #047857;
	}

	.cur-icon {
		width: 11px;
		height: 11px;
		object-fit: contain;
	}

	.cur-icon-xs {
		width: 8px;
		height: 8px;
		object-fit: contain;
	}
</style>
