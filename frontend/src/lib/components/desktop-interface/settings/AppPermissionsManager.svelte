<script lang="ts">
	// Stage 1 of the centralized permission dashboard (see
	// `Do not delete/PERMISSION_SYSTEMS_AUDIT.md` and the approved plan for
	// context). Purely additive: every tab embeds an existing permission
	// manager component whole and unmodified — this file adds no new
	// permission logic of its own, it only aggregates.
	//
	// Known Stage 1 limitation: opening one of these tabs and the matching
	// old standalone window (e.g. Approval Permissions) at the same time
	// creates two independent component instances with independent local
	// state/queries. Same class of situation as opening any window twice
	// via the taskbar today — not solved here, not a new problem.
	//
	// Stage 4 update: the old standalone entry points for Button Access
	// Control, Interface Permissions, and Approval Permissions have been
	// removed from Sidebar.svelte — this window is now the ONLY way to
	// reach them. Button Access Control and Interface Permissions were
	// originally gated by button_permissions codes (BUTTON_ACCESS_CONTROL /
	// INTERFACE_ACCESS_MANAGER), not by isMasterAdmin, so this file loads
	// and checks those codes itself now (mirroring Sidebar.svelte's own
	// loadButtonPermissions()/isButtonAllowed(), which is duplicated
	// per-component in this codebase, not a shared utility — see
	// Taskbar.svelte for the same pattern) to preserve the exact same
	// access control rather than silently loosening it to "anyone who can
	// open App Permissions at all."
	// Each tab's component is only mounted while it is the active tab
	// ({#if activeTab === 'x'}), since every one of these components fires
	// its own Supabase queries in onMount with no lazy-load support —
	// mounting all ten at once would fire ten times the queries for
	// nothing.

	import { onMount } from 'svelte';
	import { t, locale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

	import ButtonAccessControl from '$lib/components/desktop-interface/settings/ButtonAccessControl.svelte';
	import ApprovalPermissionsManager from '$lib/components/desktop-interface/settings/ApprovalPermissionsManager.svelte';
	import InterfaceAccessManager from '$lib/components/desktop-interface/settings/InterfaceAccessManager.svelte';
	import SupportAppAccess from '$lib/components/desktop-interface/settings/SupportAppAccess.svelte';
	import BreakPermissionManager from '$lib/components/desktop-interface/master/hr/BreakPermissionManager.svelte';
	import DenominationPermissionManager from '$lib/components/desktop-interface/master/finance/DenominationPermissionManager.svelte';
	import ReceivingRecordsPermissionsModal from '$lib/components/desktop-interface/master/operations/receiving/ReceivingRecordsPermissionsModal.svelte';
	import SalaryStatementPermissionsModal from '$lib/components/desktop-interface/master/hr/SalaryStatementPermissionsModal.svelte';

	type TabId =
		| 'buttonAccess'
		| 'approval'
		| 'defaultIncidentUsers'
		| 'interface'
		| 'breakRegister'
		| 'denomination'
		| 'boxApprovers'
		| 'boxClosure'
		| 'receiving'
		| 'salaryStatement'
		| 'camChecker';

	let activeTab: TabId = 'buttonAccess';

	$: isMasterAdmin = $currentUser?.isMasterAdmin ?? false;
	$: isAdminOrMaster = isMasterAdmin || ($currentUser?.isAdmin ?? false);

	let allowedButtonCodes: Set<string> = new Set();
	let buttonPermissionsLoaded = false;

	onMount(loadButtonPermissions);

	async function loadButtonPermissions() {
		if (!$currentUser?.id) {
			allowedButtonCodes = new Set();
			buttonPermissionsLoaded = false;
			return;
		}
		try {
			const { data, error } = await supabase
				.from('button_permissions')
				.select('button_code')
				.eq('user_id', $currentUser.id)
				.eq('is_enabled', true);
			allowedButtonCodes = error ? new Set() : new Set((data || []).map((p) => p.button_code));
		} catch {
			allowedButtonCodes = new Set();
		} finally {
			buttonPermissionsLoaded = true;
		}
	}

	interface TabDef {
		id: TabId;
		icon: string;
		labelKey: string;
		fallback: string;
		locked: boolean;
	}

	// Gate mirrors each system's existing gate at its current entry point —
	// see the plan / audit for the citation behind each one. Button Access
	// Control and Interface Permissions are button_permissions-code gates
	// (their old sidebar entries never used isMasterAdmin), so they check
	// allowedButtonCodes/buttonPermissionsLoaded directly here — Master
	// Admin still bypasses, matching isButtonAllowed()'s own behavior.
	$: canButtonAccess = buttonPermissionsLoaded && (isMasterAdmin || allowedButtonCodes.has('BUTTON_ACCESS_CONTROL'));
	$: canInterfaceAccess = buttonPermissionsLoaded && (isMasterAdmin || allowedButtonCodes.has('INTERFACE_ACCESS_MANAGER'));

	$: tabDefs = [
		{ id: 'buttonAccess', icon: '🔘', labelKey: 'nav.buttonAccessControl', fallback: 'Button Access Control', locked: !canButtonAccess },
		{ id: 'approval', icon: '✅', labelKey: 'nav.approvalPermissions', fallback: 'Approval Permissions', locked: !isMasterAdmin },
		{ id: 'defaultIncidentUsers', icon: '🏢', labelKey: 'nav.defaultIncidentUsers', fallback: 'Default Incident Users', locked: !isMasterAdmin },
		{ id: 'interface', icon: '🖥️', labelKey: 'nav.interfaceAccess', fallback: 'Interface Permissions', locked: !canInterfaceAccess },
		{ id: 'breakRegister', icon: '☕', labelKey: 'nav.breakRegister', fallback: 'Break Register', locked: !isAdminOrMaster },
		{ id: 'denomination', icon: '💵', labelKey: 'nav.denomination', fallback: 'Denomination', locked: !isMasterAdmin },
		{ id: 'boxApprovers', icon: '👥', labelKey: 'nav.completeBoxApprovers', fallback: 'Complete Box Approvers', locked: !isMasterAdmin },
		{ id: 'boxClosure', icon: '📦', labelKey: 'nav.completeBoxClosure', fallback: 'Complete Box Closure', locked: !isMasterAdmin },
		{ id: 'receiving', icon: '📥', labelKey: 'nav.receivingRecords', fallback: 'Receiving Records', locked: !isMasterAdmin },
		{ id: 'salaryStatement', icon: '💰', labelKey: 'nav.salaryStatement', fallback: 'Salary Statement', locked: !isMasterAdmin },
		{ id: 'camChecker', icon: '🎥', labelKey: 'nav.camCheckerAccess', fallback: 'External Apps Access', locked: false }
	] as TabDef[];

	function selectTab(tab: TabDef) {
		if (tab.locked) return;
		activeTab = tab.id;
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Tabs -->
	<div class="flex items-center gap-2 px-4 pt-4 pb-2 bg-white border-b border-slate-200 flex-wrap">
		{#each tabDefs as tab (tab.id)}
			<button
				type="button"
				class="px-4 py-2 rounded-full text-sm font-bold transition-all flex items-center gap-1.5 {tab.locked ? 'bg-slate-50 text-slate-300 cursor-not-allowed' : activeTab === tab.id ? 'bg-red-500 text-white shadow' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}"
				disabled={tab.locked}
				title={tab.locked ? (t('nav.tabAccessRequired') || "You don't have access to this") : ''}
				on:click={() => selectTab(tab)}
			>
				<span>{tab.icon}</span>
				<span>{t(tab.labelKey) || tab.fallback}</span>
				{#if tab.locked}
					<span class="text-xs">🔒</span>
				{/if}
			</button>
		{/each}
	</div>

	<!-- Content -->
	<div class="flex-1 min-h-0 overflow-hidden">
		{#if activeTab === 'buttonAccess' && canButtonAccess}
			<ButtonAccessControl />
		{/if}
		{#if activeTab === 'approval' && isMasterAdmin}
			<ApprovalPermissionsManager initialTab="permissions" hideTabSwitcher={true} />
		{/if}
		{#if activeTab === 'defaultIncidentUsers' && isMasterAdmin}
			<ApprovalPermissionsManager initialTab="default-users" hideTabSwitcher={true} />
		{/if}
		{#if activeTab === 'interface' && canInterfaceAccess}
			<InterfaceAccessManager />
		{/if}
		{#if activeTab === 'breakRegister' && isAdminOrMaster}
			<BreakPermissionManager />
		{/if}
		{#if activeTab === 'denomination' && isMasterAdmin}
			<DenominationPermissionManager initialTab="permission" hideTabSwitcher={true} />
		{/if}
		{#if activeTab === 'boxApprovers' && isMasterAdmin}
			<DenominationPermissionManager initialTab="approvers" hideTabSwitcher={true} />
		{/if}
		{#if activeTab === 'boxClosure' && isMasterAdmin}
			<DenominationPermissionManager initialTab="closures" hideTabSwitcher={true} />
		{/if}
		{#if activeTab === 'receiving' && isMasterAdmin}
			<ReceivingRecordsPermissionsModal show={true} embedded={true} />
		{/if}
		{#if activeTab === 'salaryStatement' && isMasterAdmin}
			<SalaryStatementPermissionsModal show={true} embedded={true} currentUserId={$currentUser?.id || null} />
		{/if}
		{#if activeTab === 'camChecker'}
			<SupportAppAccess />
		{/if}
	</div>
</div>
