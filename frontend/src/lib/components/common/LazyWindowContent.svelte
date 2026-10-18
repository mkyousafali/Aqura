<script lang="ts">
	import { _ as t } from '$lib/i18n';
	import type { LazyWindowComponent } from '$lib/utils/lazyWindowComponent';

	export let component: LazyWindowComponent;
	export let componentProps: Record<string, any> = {};

	let componentPromise = component.load();

	function retry() {
		componentPromise = component.load();
	}
</script>

{#await componentPromise}
	<div class="load-state" role="status" aria-live="polite">
		{$t('common.loading')}
	</div>
{:then LoadedComponent}
	<svelte:component this={LoadedComponent} {...componentProps} />
{:catch}
	<div class="load-state" role="alert">
		<p>{$t('common.windowLoadError')}</p>
		<button type="button" on:click={retry}>{$t('common.retry')}</button>
	</div>
{/await}

<style>
	.load-state {
		display: flex;
		min-height: 160px;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 12px;
		padding: 24px;
		color: #475569;
		text-align: center;
	}

	.load-state p {
		margin: 0;
	}

	.load-state button {
		padding: 8px 16px;
		border: 1px solid #cbd5e1;
		border-radius: 6px;
		background: #fff;
		color: #0f172a;
		cursor: pointer;
	}
</style>
