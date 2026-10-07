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
	import IncidentUsersManager from '$lib/components/desktop-interface/settings/IncidentUsersManager.svelte';
	import InterfaceAccessManager from '$lib/components/desktop-interface/settings/InterfaceAccessManager.svelte';
	import SupportAppAccess from '$lib/components/desktop-interface/settings/SupportAppAccess.svelte';
	import DefaultEntryTaskUsers from '$lib/components/desktop-interface/settings/DefaultEntryTaskUsers.svelte';
	import SafeBoxControl from '$lib/components/desktop-interface/settings/SafeBoxControl.svelte';
	import BreakPermissionManager from '$lib/components/desktop-interface/master/hr/BreakPermissionManager.svelte';
	import DenominationPermissionManager from '$lib/components/desktop-interface/master/finance/DenominationPermissionManager.svelte';
	import ReceivingRecordsPermissionsModal from '$lib/components/desktop-interface/master/operations/receiving/ReceivingRecordsPermissionsModal.svelte';
	import SalaryStatementPermissionsModal from '$lib/components/desktop-interface/master/hr/SalaryStatementPermissionsModal.svelte';
	import BranchMaster from '$lib/components/desktop-interface/master/BranchMaster.svelte';
	import AquraVoiceControl from '$lib/components/desktop-interface/settings/AquraVoiceControl.svelte';
	import AttendanceNotifiersManager from '$lib/components/desktop-interface/settings/AttendanceNotifiersManager.svelte';
	import DefaultPositions from '$lib/components/desktop-interface/master/vendor/DefaultPositions.svelte';

	type TabId =
		| 'buttonAccess'
		| 'leaveApprovers'
		| 'approval'
		| 'defaultIncidentUsers'
		| 'defaultEntryTaskUsers'
		| 'interface'
		| 'breakRegister'
		| 'denomination'
		| 'boxApprovers'
		| 'boxClosure'
		| 'receiving'
		| 'salaryStatement'
		| 'camChecker'
		| 'safeBoxControl'
		| 'aquraVoice'
		| 'branchDefaultPositions'
		| 'attendanceNotifiers';

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
		group: 'approvals' | 'defaults' | 'access' | 'services';
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
		{ id: 'leaveApprovers', icon: '✅', labelKey: 'nav.defaultLeaveApprovers', fallback: 'Leave Approvers', locked: !isMasterAdmin, group: 'approvals' },
		{ id: 'approval', icon: '✅', labelKey: 'nav.approvalPermissions', fallback: 'Approval Permissions', locked: !isMasterAdmin, group: 'approvals' },
		{ id: 'boxApprovers', icon: '👥', labelKey: 'nav.completeBoxApprovers', fallback: 'Complete Box Approvers', locked: !isMasterAdmin, group: 'approvals' },
		{ id: 'boxClosure', icon: '📦', labelKey: 'nav.completeBoxClosure', fallback: 'Complete Box Closure', locked: !isMasterAdmin, group: 'approvals' },
		{ id: 'receiving', icon: '📥', labelKey: 'nav.receivingRecords', fallback: 'Receiving Records', locked: !isMasterAdmin, group: 'approvals' },
		{ id: 'salaryStatement', icon: '💰', labelKey: 'nav.salaryStatement', fallback: 'Salary Statement', locked: !isMasterAdmin, group: 'approvals' },
		{ id: 'defaultIncidentUsers', icon: '🚨', labelKey: 'nav.incidentManager', fallback: 'Incident Manager', locked: !isMasterAdmin, group: 'defaults' },
		{ id: 'defaultEntryTaskUsers', icon: '🧾', labelKey: 'nav.defaultEntryTaskUsers', fallback: 'Default Entry Task Users', locked: !isMasterAdmin, group: 'defaults' },
		{ id: 'branchDefaultPositions', icon: '👥', labelKey: 'nav.branchDefaultPositions', fallback: 'Branch Default Positions', locked: !isMasterAdmin, group: 'defaults' },
		{ id: 'buttonAccess', icon: '🔘', labelKey: 'nav.buttonAccessControl', fallback: 'Button Access Control', locked: !canButtonAccess, group: 'access' },
		{ id: 'interface', icon: '🖥️', labelKey: 'nav.interfaceAccess', fallback: 'Interface Permissions', locked: !canInterfaceAccess, group: 'access' },
		{ id: 'breakRegister', icon: '☕', labelKey: 'nav.breakRegister', fallback: 'Break Register', locked: !isAdminOrMaster, group: 'access' },
		{ id: 'denomination', icon: '💵', labelKey: 'nav.denomination', fallback: 'Denomination', locked: !isMasterAdmin, group: 'access' },
		{ id: 'camChecker', icon: '🎥', labelKey: 'nav.camCheckerAccess', fallback: 'External Apps Access', locked: false, group: 'access' },
		{ id: 'safeBoxControl', icon: '🔐', labelKey: 'nav.safeBoxControl', fallback: 'Safe Box Control', locked: !isMasterAdmin, group: 'access' },
		{ id: 'aquraVoice', icon: '🎙️', labelKey: 'nav.aquraVoice', fallback: 'Aqura Voice', locked: !isMasterAdmin, group: 'services' },
		{ id: 'attendanceNotifiers', icon: '⏰', labelKey: 'nav.attendanceNotifiers', fallback: 'Attendance Notifiers', locked: !isMasterAdmin, group: 'services' }
	] as TabDef[];

	const groupOrder: TabDef['group'][] = ['approvals', 'defaults', 'access', 'services'];
	$: groupedTabs = groupOrder.map((group) => ({ group, tabs: tabDefs.filter((tab) => tab.group === group) }));

	function groupLabel(group: TabDef['group']) {
		const labels = $locale === 'ar'
			? { approvals: 'الموافقات', defaults: 'التعيينات الافتراضية', access: 'ضوابط الوصول', services: 'الإشعارات والخدمات' }
			: { approvals: 'Approvals', defaults: 'Default Assignments', access: 'Access Controls', services: 'Notifications & Services' };
		return labels[group];
	}

	function selectTab(tab: TabDef) {
		if (tab.locked) return;
		activeTab = tab.id;
	}
</script>

<div class="flex h-full overflow-hidden bg-[#f8fafc] font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Section navigation -->
	<aside class="w-64 flex-shrink-0 overflow-y-auto border-e border-slate-200 bg-white p-3">
		<div class="mb-3 px-2 text-xs font-black uppercase tracking-wide text-slate-400">
			{t('nav.appPermissions') || 'App Permissions'}
		</div>
		<div class="space-y-4">
		{#each groupedTabs as section (section.group)}
			<section>
				<div class="mb-1.5 px-2 text-[10px] font-black uppercase tracking-wider text-slate-400">{groupLabel(section.group)}</div>
				<div class="space-y-1">
		{#each section.tabs as tab (tab.id)}
			<button
				type="button"
				class="flex w-full items-center gap-2 rounded-lg px-3 py-2.5 text-start text-sm font-bold transition-all {tab.locked ? 'cursor-not-allowed bg-slate-50 text-slate-300' : activeTab === tab.id ? 'bg-red-500 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'}"
				disabled={tab.locked}
				title={tab.locked ? (t('nav.tabAccessRequired') || "You don't have access to this") : ''}
				on:click={() => selectTab(tab)}
			>
				<span class="flex-shrink-0">{tab.icon}</span>
				<span class="min-w-0 flex-1 truncate">{t(tab.labelKey) || tab.fallback}</span>
				{#if tab.locked}
					<span class="flex-shrink-0 text-xs">🔒</span>
				{/if}
			</button>
		{/each}
				</div>
			</section>
		{/each}
		</div>
	</aside>

	<!-- Content -->
	<div class="relative flex-1 min-h-0 overflow-hidden">
		{#if activeTab === 'leaveApprovers' && isMasterAdmin}
			<BranchMaster initialTab="approvers" hideTabSwitcher={true} />
		{/if}
		{#if activeTab === 'buttonAccess' && canButtonAccess}
			<ButtonAccessControl />
		{/if}
		{#if activeTab === 'approval' && isMasterAdmin}
			<ApprovalPermissionsManager initialTab="permissions" hideTabSwitcher={true} />
		{/if}
		{#if activeTab === 'defaultIncidentUsers' && isMasterAdmin}
			<IncidentUsersManager />
		{/if}
		{#if activeTab === 'defaultEntryTaskUsers' && isMasterAdmin}
			<DefaultEntryTaskUsers />
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
		{#if activeTab === 'safeBoxControl' && isMasterAdmin}
			<SafeBoxControl />
		{/if}
		{#if activeTab === 'aquraVoice' && isMasterAdmin}
			<AquraVoiceControl />
		{/if}
		{#if activeTab === 'branchDefaultPositions' && isMasterAdmin}
			<DefaultPositions />
		{/if}
		{#if activeTab === 'attendanceNotifiers' && isMasterAdmin}
			<AttendanceNotifiersManager />
		{/if}
	</div>
</div>
