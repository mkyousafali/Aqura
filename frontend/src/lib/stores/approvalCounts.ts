import { writable } from 'svelte/store';
import { supabaseAdmin } from '$lib/utils/supabase';
import { currentUser } from '$lib/utils/persistentAuth';
import { get } from 'svelte/store';

interface ApprovalCounts {
	pending: number;
	total: number;
}

// Create writable store
export const approvalCounts = writable<ApprovalCounts>({
	pending: 0,
	total: 0
});

let refreshInterval: ReturnType<typeof setInterval> | null = null;

/**
 * Fetch approval counts for the current user
 */
export async function fetchApprovalCounts(): Promise<void> {
	try {
		const user = get(currentUser);
		
		if (!user?.id) {
			console.warn('⚠️ No user logged in, skipping approval counts fetch');
			approvalCounts.set({ pending: 0, total: 0 });
			return;
		}

		// Count pending requisitions where user is the approver
		const { count: requisitionCount, error: reqError } = await supabaseAdmin
			.from('expense_requisitions')
			.select('*', { count: 'exact', head: true })
			.eq('approver_id', user.id)
			.eq('status', 'pending');

		if (reqError) {
			console.error('❌ Error fetching requisition counts:', reqError);
		}

		// Count pending payment schedules where user is the approver
		const { count: scheduleCount, error: schedError } = await supabaseAdmin
			.from('non_approved_payment_scheduler')
			.select('*', { count: 'exact', head: true })
			.eq('approver_id', user.id)
			.eq('approval_status', 'pending')
			.in('schedule_type', ['single_bill', 'multiple_bill']);

		if (schedError) {
			console.error('❌ Error fetching schedule counts:', schedError);
		}

		const pendingCount = (requisitionCount || 0) + (scheduleCount || 0);
		
		approvalCounts.set({
			pending: pendingCount,
			total: pendingCount
		});

		console.log('✅ Approval counts updated:', { pending: pendingCount });
	} catch (error) {
		console.error('❌ Error in fetchApprovalCounts:', error);
		approvalCounts.set({ pending: 0, total: 0 });
	}
}

/**
 * Refresh approval counts (can be called manually)
 */
export async function refreshApprovalCounts(): Promise<void> {
	console.log('🔄 Refreshing approval counts...');
	await fetchApprovalCounts();
}

/**
 * Initialize approval count monitoring with periodic refresh
 */
export function initApprovalCountMonitoring(intervalMs: number = 30000): void {
	// Clear any existing interval
	if (refreshInterval) {
		clearInterval(refreshInterval);
	}

	// Fetch immediately
	fetchApprovalCounts();

	// Set up periodic refresh
	refreshInterval = setInterval(() => {
		fetchApprovalCounts();
	}, intervalMs);

	console.log('✅ Approval count monitoring initialized (refresh every', intervalMs / 1000, 'seconds)');
}

/**
 * Stop approval count monitoring
 */
export function stopApprovalCountMonitoring(): void {
	if (refreshInterval) {
		clearInterval(refreshInterval);
		refreshInterval = null;
		console.log('⏹️ Approval count monitoring stopped');
	}
}
