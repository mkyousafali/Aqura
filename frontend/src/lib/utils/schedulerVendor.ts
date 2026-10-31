export function schedulerVendorFields(vendor: any, branchId: unknown, valid = true) {
	if (!valid) throw new Error('Select a vendor for this branch, or choose General expense.');
	if (!vendor) return { vendor_id: null, vendor_name: null };
	const id = Number(vendor.erp_vendor_id);
	if (!Number.isSafeInteger(id) || id <= 0 || Number(vendor.branch_id) !== Number(branchId) || !vendor.vendor_name?.trim()) {
		throw new Error('Select a valid vendor from the selected branch.');
	}
	return { vendor_id: id, vendor_name: vendor.vendor_name.trim() };
}

export async function loadSchedulerVendors(client: any, branchId: unknown) {
	const branch = Number(branchId);
	if (!Number.isSafeInteger(branch) || branch <= 0) return [];
	const vendors = [];
	for (let offset = 0; ; offset += 1000) {
		const { data, error } = await client.from('vendors')
			.select('branch_id,erp_vendor_id,vendor_name').eq('branch_id', branch)
			.order('vendor_name').order('erp_vendor_id').range(offset, offset + 999);
		if (error) throw error;
		vendors.push(...(data || []));
		if (!data || data.length < 1000) return vendors;
	}
}
