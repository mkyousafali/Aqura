export type ReceivingPaymentSchedule = {
	id: string;
	receiving_record_id: string;
	branch_id: number;
	approval_status: string | null;
	bill_number: string;
	bill_amount: number;
	final_bill_amount: number | null;
	is_paid?: boolean | null;
};

export function receivingPaymentStatus(payments: Pick<ReceivingPaymentSchedule, 'is_paid'>[]) {
	return {
		is_paid: payments.length > 0 && payments.every(payment => payment.is_paid === true),
		is_scheduled: payments.length > 0,
		has_multiple_schedules: payments.length > 1
	};
}

// Paid status is separate from approval, including for on-delivery payments.
export function isReceivingPaymentApproved(payments: ReceivingPaymentSchedule[] = [], branchId: number) {
	return payments.length > 0 && payments.every(payment =>
		Number(payment.branch_id) === Number(branchId) && payment.approval_status === 'approved');
}

export async function loadReceivingPaymentSchedules(client: any, recordIds: string[]): Promise<ReceivingPaymentSchedule[]> {
	const ids = [...new Set(recordIds)];
	const payments: ReceivingPaymentSchedule[] = [];
	// Keep UUID filters below the database proxy's request-size limit.
	for (let index = 0; index < ids.length; index += 20) {
		for (let offset = 0; ; offset += 1000) {
			const { data, error } = await client.from('vendor_payment_schedule')
				.select('id,receiving_record_id,branch_id,approval_status,bill_number,bill_amount,final_bill_amount,is_paid')
				.in('receiving_record_id', ids.slice(index, index + 20))
				.order('id').range(offset, offset + 999);
			if (error) throw error;
			payments.push(...(data || []));
			if (!data || data.length < 1000) break;
		}
	}
	return payments;
}

// Filter loads and realtime refreshes can overlap. A response may only replace
// the records it requested, and only if no newer request refreshed those records.
export type ReceivingPaymentApprovalStatus = 'loading' | 'loaded' | 'error';

export function createReceivingPaymentApprovalLoader(
	loadPayments: (recordIds: string[]) => Promise<ReceivingPaymentSchedule[]>,
	onChange: (payments: Record<string, ReceivingPaymentSchedule[]>, statuses: Record<string, ReceivingPaymentApprovalStatus>) => void
) {
	let request = 0;
	let paymentsByRecord: Record<string, ReceivingPaymentSchedule[]> = {};
	let statuses: Record<string, ReceivingPaymentApprovalStatus> = {};
	const latestRequest = new Map<string, number>();
	return async (recordIds: string[]) => {
		const ids = [...new Set(recordIds.map(String))];
		if (!ids.length) return [];
		const version = ++request;
		const next = { ...paymentsByRecord };
		statuses = { ...statuses };
		for (const id of ids) {
			latestRequest.set(id, version);
			delete next[id];
			statuses[id] = 'loading';
		}
		paymentsByRecord = next;
		onChange(paymentsByRecord, statuses);
		let payments: ReceivingPaymentSchedule[];
		try {
			payments = await loadPayments(ids);
		} catch (error) {
			statuses = { ...statuses };
			for (const id of ids) {
				if (latestRequest.get(id) === version) statuses[id] = 'error';
			}
			onChange(paymentsByRecord, statuses);
			throw error;
		}
		const grouped: Record<string, ReceivingPaymentSchedule[]> = Object.fromEntries(ids.map(id => [id, []]));
		for (const payment of payments) grouped[String(payment.receiving_record_id)]?.push(payment);
		const updated = { ...paymentsByRecord };
		statuses = { ...statuses };
		for (const id of ids) {
			if (latestRequest.get(id) === version) {
				updated[id] = grouped[id];
				statuses[id] = 'loaded';
			}
		}
		paymentsByRecord = updated;
		onChange(paymentsByRecord, statuses);
		return payments;
	};
}
