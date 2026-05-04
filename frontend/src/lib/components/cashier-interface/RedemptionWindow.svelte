<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import GiftWheelCoupon from '$lib/components/cashier-interface/GiftWheelCoupon.svelte';
	import CouponRedemption from '$lib/components/cashier-interface/CouponRedemption.svelte';
	import VipRedemption from '$lib/components/cashier-interface/VipRedemption.svelte';
	import { _ as t } from '$lib/i18n';

	export let user: any;
	export let branch: any;

	type Tab = 'gift-wheel' | 'coupon' | 'vip';
	let activeTab: Tab = 'gift-wheel';

	// ── VIP campaign state (managed here so realtime is always active) ──
	let supabase: any = null;
	let vipActive: boolean | null = null; // null = loading
	let vipPosterPath = '';
	let vipPosterMime = '';
	let vipChannel: any = null;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await loadVipStatus();
		setupVipRealtime();
	});

	onDestroy(() => {
		if (vipChannel && supabase) supabase.removeChannel(vipChannel);
	});

	async function loadVipStatus() {
		try {
			const { data } = await supabase
				.from('vip_campaign_settings')
				.select('is_active, instruction_poster_path, instruction_poster_mime_type')
				.limit(1)
				.single();
			vipActive = data?.is_active ?? false;
			vipPosterPath = data?.instruction_poster_path ?? '';
			vipPosterMime = data?.instruction_poster_mime_type ?? '';
		} catch {
			vipActive = false;
		}
	}

	function setupVipRealtime() {
		if (!supabase) return;
		vipChannel = supabase
			.channel('redemption-window-vip-rt')
			.on(
				'postgres_changes',
				{ event: 'UPDATE', schema: 'public', table: 'vip_campaign_settings' },
				(payload: any) => {
					const row = payload.new;
					vipActive = row.is_active ?? false;
					vipPosterPath = row.instruction_poster_path ?? '';
					vipPosterMime = row.instruction_poster_mime_type ?? '';
					// If campaign deactivated while cashier is on VIP tab, move them away
					if (!row.is_active && activeTab === 'vip') activeTab = 'gift-wheel';
				}
			)
			.subscribe();
	}
</script>

<div class="redemption-window">
	<!-- Tab Bar -->
	<div class="tab-bar">
		<button
			class="tab-btn tab-btn--orange"
			class:active={activeTab === 'gift-wheel'}
			on:click={() => (activeTab = 'gift-wheel')}
		>
			<span class="tab-icon">🎡</span>
			{$t('coupon.giftWheelRedemptionTab')}
		</button>
		<button
			class="tab-btn tab-btn--green"
			class:active={activeTab === 'coupon'}
			on:click={() => (activeTab = 'coupon')}
		>
			<span class="tab-icon">🎁</span>
			{$t('coupon.giftCouponRedemptionTab')}
		</button>
		<button
			class="tab-btn tab-btn--vip"
			class:active={activeTab === 'vip'}
			on:click={() => (activeTab = 'vip')}
			style:display={vipActive ? 'flex' : 'none'}
		>
			<span class="tab-icon">👑</span>
			{$t('coupon.vipRedemptionTab')}
		</button>
	</div>

	<!-- Tab Content -->
	<div class="tab-content">
		{#if activeTab === 'gift-wheel'}
			<GiftWheelCoupon {branch} />
		{:else if activeTab === 'coupon'}
			<CouponRedemption {user} {branch} />
		{:else}
			<VipRedemption {user} {branch} campaignActive={vipActive} posterPath={vipPosterPath} posterMimeType={vipPosterMime} />
		{/if}
	</div>
</div>

<style>
	.redemption-window {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: #f8fafc;
		color: #1e293b;
	}

	.tab-bar {
		display: flex;
		gap: 0.75rem;
		padding: 0.875rem 1rem;
		background: #ffffff;
		border-bottom: 2px solid #e2e8f0;
		flex-shrink: 0;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
	}

	.tab-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem 1rem;
		border-radius: 10px;
		font-size: 0.9rem;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.2s;
		border: 2px solid transparent;
	}

	/* Orange — Gift Wheel */
	.tab-btn--orange {
		background: #fff7ed;
		border-color: #fdba74;
		color: #c2410c;
	}
	.tab-btn--orange:hover {
		background: #ffedd5;
		border-color: #f97316;
		box-shadow: 0 4px 14px rgba(249, 115, 22, 0.25);
		transform: translateY(-1px);
	}
	.tab-btn--orange.active {
		background: #f97316;
		border-color: #ea580c;
		color: #ffffff;
		box-shadow: 0 4px 18px rgba(249, 115, 22, 0.4);
	}

	/* Green — Gift Coupon */
	.tab-btn--green {
		background: #f0fdf4;
		border-color: #86efac;
		color: #15803d;
	}
	.tab-btn--green:hover {
		background: #dcfce7;
		border-color: #22c55e;
		box-shadow: 0 4px 14px rgba(34, 197, 94, 0.25);
		transform: translateY(-1px);
	}
	.tab-btn--green.active {
		background: #22c55e;
		border-color: #16a34a;
		color: #ffffff;
		box-shadow: 0 4px 18px rgba(34, 197, 94, 0.4);
	}

	/* Purple — VIP */
	.tab-btn--vip {
		background: #faf5ff;
		border-color: #d8b4fe;
		color: #7e22ce;
	}
	.tab-btn--vip:hover {
		background: #f3e8ff;
		border-color: #a855f7;
		box-shadow: 0 4px 14px rgba(168, 85, 247, 0.25);
		transform: translateY(-1px);
	}
	.tab-btn--vip.active {
		background: #9333ea;
		border-color: #7e22ce;
		color: #ffffff;
		box-shadow: 0 4px 18px rgba(147, 51, 234, 0.4);
	}

	.tab-icon {
		font-size: 1.1rem;
	}

	.tab-content {
		flex: 1;
		overflow: auto;
		min-height: 0;
	}

	/* Ensure child components fill the available space */
	.tab-content :global(> *) {
		height: 100%;
	}
</style>
