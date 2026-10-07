<script lang="ts">
	import ApprovalPermissionsManager from './ApprovalPermissionsManager.svelte';

	let activeView: 'defaults' | 'receivers' = 'defaults';
</script>

<div class="flex h-full min-h-0 flex-col bg-slate-50">
	<div class="flex flex-shrink-0 items-center gap-2 border-b border-slate-200 bg-white px-4 py-3">
		<button
			type="button"
			class="rounded-lg px-4 py-2 text-sm font-bold transition {activeView === 'defaults' ? 'bg-emerald-600 text-white shadow-sm' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
			on:click={() => activeView = 'defaults'}
		>
			🏢 Default Incident Users
		</button>
		<button
			type="button"
			class="rounded-lg px-4 py-2 text-sm font-bold transition {activeView === 'receivers' ? 'bg-orange-600 text-white shadow-sm' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}"
			on:click={() => activeView = 'receivers'}
		>
			🚨 Incident Receivers
		</button>
	</div>

	<div class="min-h-0 flex-1 overflow-hidden">
		{#if activeView === 'defaults'}
			<ApprovalPermissionsManager initialTab="default-users" hideTabSwitcher={true} />
		{:else}
			<ApprovalPermissionsManager initialTab="permissions" hideTabSwitcher={true} permissionScope="incidents" />
		{/if}
	</div>
</div>
