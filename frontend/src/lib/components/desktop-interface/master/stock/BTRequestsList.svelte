<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';
	import XLSX from 'xlsx-js-style';

	interface BTRequest {
		id: string;
		requester_user_id: string;
		from_branch_id: number;
		to_branch_id: number;
		target_user_id: string;
		status: string;
		items: { barcode: string; product_name: string; quantity: number; photo_url: string | null; is_available?: boolean; available_qty?: number }[];
		document_url?: string | null;
		created_at: string;
		updated_at: string;
		// Joined
		requester_name?: string;
		target_name?: string;
		from_branch_name?: string;
		to_branch_name?: string;
	}

	let requests: BTRequest[] = [];
	let loading = true;
	let error = '';

	// Caches
	let imageCache: Record<string, string> = {};

	// Detail view
	let selectedRequest: BTRequest | null = null;
	let highlightedRequestId: string | null = null;

	// Photo lightbox
	let lightboxUrl: string | null = null;

	// Document upload
	let uploadingDoc: string | null = null;
	let btAssignedIM: Record<string, string> = {}; // reqId -> assigned IM user_id

	// Approval modal
	let showApprovalModal = false;
	let approvalRequestId: string | null = null;
	let approvalBranchId: number | null = null;
	let approvalBranchUsers: { id: string; username: string; name_en: string; name_ar: string }[] = [];
	let selectedIMUserId: string | null = null;
	let defaultIMUserId: string | null = null;
	let loadingIMUsers = false;
	let approvingRequest = false;

	// Editable availability items for detail view
	let editableItems: { barcode: string; product_name: string; quantity: number; photo_url: string | null; is_available: boolean; available_qty: number }[] = [];
	let savingAvailability = false;

	// Scroll position preservation
	let listScrollTop = 0;
	let listScrollContainer: HTMLElement | null = null;

	function openDetail(req: BTRequest) {
		// Save scroll position before switching to detail view
		if (listScrollContainer) {
			listScrollTop = listScrollContainer.scrollTop;
		}
		highlightedRequestId = req.id;
		selectedRequest = req;
	}

	function goBackToList() {
		selectedRequest = null;
		// Restore scroll position after Svelte re-renders the list
		requestAnimationFrame(() => {
			requestAnimationFrame(() => {
				if (listScrollContainer) {
					listScrollContainer.scrollTop = listScrollTop;
				}
			});
		});
	}

	// Search & Filters
	let searchQuery = '';
	let filterStatus = '';
	let filterBranch = '';
	let filterDateFrom = '';
	let filterDateTo = '';

	// Derived: unique branches for dropdown
	$: branchOptions = [...new Set([...requests.map(r => r.from_branch_name), ...requests.map(r => r.to_branch_name)].filter(Boolean))] as string[];

	// Derived: filtered requests
	$: filteredRequests = requests.filter(r => {
		if (filterStatus && r.status !== filterStatus) return false;
		if (filterBranch && r.from_branch_name !== filterBranch && r.to_branch_name !== filterBranch) return false;
		if (filterDateFrom) {
			const from = new Date(filterDateFrom);
			if (new Date(r.created_at) < from) return false;
		}
		if (filterDateTo) {
			const to = new Date(filterDateTo);
			to.setHours(23, 59, 59, 999);
			if (new Date(r.created_at) > to) return false;
		}
		if (searchQuery.trim()) {
			const q = searchQuery.trim().toLowerCase();
			const items = getItemsList(r.items);
			const matchesItems = items.some(item =>
				(item.barcode && item.barcode.toLowerCase().includes(q)) ||
				(item.product_name && item.product_name.toLowerCase().includes(q))
			);
			if (
				!(r.requester_name?.toLowerCase().includes(q)) &&
				!(r.target_name?.toLowerCase().includes(q)) &&
				!(r.from_branch_name?.toLowerCase().includes(q)) &&
				!(r.to_branch_name?.toLowerCase().includes(q)) &&
				!(r.status?.toLowerCase().includes(q)) &&
				!matchesItems
			) return false;
		}
		return true;
	});

	function clearFilters() {
		searchQuery = '';
		filterStatus = '';
		filterBranch = '';
		filterDateFrom = '';
		filterDateTo = '';
	}

	$: hasActiveFilters = searchQuery || filterStatus || filterBranch || filterDateFrom || filterDateTo;

	function getCachedImage(url: string | null): string | null {
		if (!url) return null;
		return imageCache[url] || url;
	}

	async function cacheImages(rows: BTRequest[]) {
		const urls = new Set<string>();
		for (const r of rows) {
			const items = Array.isArray(r.items) ? r.items : [];
			for (const item of items) {
				if (item.photo_url && !imageCache[item.photo_url]) urls.add(item.photo_url);
			}
		}
		const promises = [...urls].map(async (url) => {
			try {
				const resp = await fetch(url);
				if (resp.ok) {
					const blob = await resp.blob();
					imageCache[url] = URL.createObjectURL(blob);
				}
			} catch { /* skip failed images */ }
		});
		await Promise.all(promises);
		imageCache = imageCache; // trigger reactivity
	}

	function exportToExcel() {
		if (!selectedRequest) return;
		const items = getItemsList(selectedRequest.items);
		const headerStyle = { font: { bold: true, color: { rgb: 'FFFFFF' } }, fill: { fgColor: { rgb: '2563EB' } }, alignment: { horizontal: 'center' } };
		const wsData = [
			[{ v: '#', s: headerStyle }, { v: 'Barcode', s: headerStyle }, { v: 'Product Name', s: headerStyle }, { v: 'Quantity', s: headerStyle }],
			...items.map((item, i) => [i + 1, item.barcode || '', item.product_name || '', item.quantity])
		];
		const ws = XLSX.utils.aoa_to_sheet(wsData);
		ws['!cols'] = [{ wch: 5 }, { wch: 20 }, { wch: 35 }, { wch: 12 }];
		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, 'BT Request');
		XLSX.writeFile(wb, `BT_Request_${formatDate(selectedRequest.created_at).replace(/[^a-zA-Z0-9]/g, '_')}.xlsx`);
	}

	function printRequest() {
		if (!selectedRequest) return;
		const items = getItemsList(selectedRequest.items);
		const printWindow = window.open('', '_blank', 'width=800,height=600');
		if (!printWindow) return;
		printWindow.document.write(`
			<html><head><title>BT Request</title>
			<style>
				body { font-family: Arial, sans-serif; padding: 30px; }
				h2 { color: #2563EB; margin-bottom: 5px; }
				.info { display: flex; gap: 30px; margin: 15px 0; font-size: 14px; }
				.info div { background: #f8fafc; padding: 10px 15px; border-radius: 8px; }
				.info label { font-weight: bold; color: #64748b; font-size: 11px; text-transform: uppercase; display: block; }
				table { width: 100%; border-collapse: collapse; margin-top: 15px; }
				th { background: #2563EB; color: white; padding: 8px 12px; text-align: left; font-size: 12px; }
				td { padding: 8px 12px; border-bottom: 1px solid #e2e8f0; font-size: 13px; }
				tr:nth-child(even) { background: #f8fafc; }
				img { width: 50px; height: 50px; object-fit: cover; border-radius: 6px; }
				@media print { body { padding: 10px; } }
			</style></head><body>
			<h2>🔄 Branch Transfer Request</h2>
			<p style="color:#64748b;font-size:12px;">${formatDate(selectedRequest.created_at)} &bull; Status: ${selectedRequest.status.toUpperCase()}</p>
			<div class="info">
				<div><label>From Branch</label>${selectedRequest.from_branch_name}</div>
				<div><label>To Branch</label>${selectedRequest.to_branch_name}</div>
				<div><label>Requester</label>${selectedRequest.requester_name}</div>
				<div><label>Manager</label>${selectedRequest.target_name}</div>
			</div>
			<table><thead><tr><th>#</th><th>Barcode</th><th>Product Name</th><th>Quantity</th><th>Photo</th></tr></thead>
			<tbody>${items.map((item, i) => `<tr><td>${i+1}</td><td>${item.barcode||'—'}</td><td>${item.product_name||'—'}</td><td>${item.quantity}</td><td>${item.photo_url ? `<img src="${item.photo_url}"/>` : '—'}</td></tr>`).join('')}</tbody></table>
			</body></html>
		`);
		printWindow.document.close();
		setTimeout(() => { printWindow.print(); }, 500);
	}

	onMount(() => {
		loadRequests();
	});

	onDestroy(() => {
		for (const blobUrl of Object.values(imageCache)) {
			if (blobUrl.startsWith('blob:')) URL.revokeObjectURL(blobUrl);
		}
	});

	async function loadRequests() {
		loading = true;
		error = '';
		try {
			// Single RPC call replaces 3 separate queries (requests + employees + branches)
			const { data, error: err } = await supabase.rpc('get_bt_requests_with_details');

			if (err) throw err;

			const rows = data || [];
			const isAr = $locale === 'ar';

			// Map RPC results to component format
			requests = rows.map((r: any) => {
				const fromName = isAr ? (r.from_branch_name_ar || r.from_branch_name_en) : (r.from_branch_name_en || r.from_branch_name_ar);
				const fromLoc = isAr ? (r.from_branch_location_ar || r.from_branch_location_en) : (r.from_branch_location_en || r.from_branch_location_ar);
				const fromDisplay = fromName ? (fromLoc ? `${fromName} — ${fromLoc}` : fromName) : '—';
				const toName = isAr ? (r.to_branch_name_ar || r.to_branch_name_en) : (r.to_branch_name_en || r.to_branch_name_ar);
				const toLoc = isAr ? (r.to_branch_location_ar || r.to_branch_location_en) : (r.to_branch_location_en || r.to_branch_location_ar);
				const toDisplay = toName ? (toLoc ? `${toName} — ${toLoc}` : toName) : '—';
				return {
					id: r.id,
					requester_user_id: r.requester_user_id,
					from_branch_id: r.from_branch_id,
					to_branch_id: r.to_branch_id,
					target_user_id: r.target_user_id,
					status: r.status,
					items: r.items,
					document_url: r.document_url,
					created_at: r.created_at,
					updated_at: r.updated_at,
					requester_name: isAr ? (r.requester_name_ar || r.requester_name_en) : (r.requester_name_en || r.requester_name_ar),
					target_name: isAr ? (r.target_name_ar || r.target_name_en) : (r.target_name_en || r.target_name_ar),
					from_branch_name: fromDisplay,
					to_branch_name: toDisplay
				};
			});
			// Pre-cache images as blob URLs
			cacheImages(requests);

			// Load assigned IM for each BT request via RPC (avoids URL length limit with many IDs)
			const reqIds = rows.map((r: any) => r.id);
			if (reqIds.length > 0) {
				try {
					const { data: imData, error: imErr } = await supabase.rpc('get_bt_assigned_ims', { p_request_ids: reqIds });
					if (imErr) throw imErr;
					if (imData) {
						for (const row of imData) {
							btAssignedIM[row.product_request_id] = row.assigned_to_user_id;
						}
					}
				} catch (err) {
					console.error('Error loading BT assigned IMs:', err);
				}
			}
		} catch (err: any) {
			console.error('Error loading BT requests:', err);
			error = err?.message || 'Failed to load requests';
		} finally {
			loading = false;
		}
	}

	async function openApprovalModal(reqId: string) {
		const req = requests.find(r => r.id === reqId);
		if (!req) return;
		approvalRequestId = reqId;
		approvalBranchId = req.to_branch_id;
		selectedIMUserId = null;
		defaultIMUserId = null;
		approvalBranchUsers = [];
		showApprovalModal = true;
		loadingIMUsers = true;

		try {
			// 1) Load default IM for the to_branch
			const { data: defaults, error: defaultsErr } = await supabase
				.from('branch_default_positions')
				.select('inventory_manager_user_id')
				.eq('branch_id', req.to_branch_id)
				.maybeSingle();

			console.log('🔍 [BT Approval] branch_id:', req.to_branch_id);
			console.log('🔍 [BT Approval] branch_default_positions result:', defaults, 'error:', defaultsErr);

			const defaultIMId = defaults?.inventory_manager_user_id || null;
			defaultIMUserId = defaultIMId;
			console.log('🔍 [BT Approval] defaultIMId:', defaultIMId);

			// 2) Load all users in the to_branch
			const { data: employees } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar')
				.eq('branch_id', req.to_branch_id);

			console.log('🔍 [BT Approval] employees found:', employees?.length);

			// 3) Also load the default IM user info if not in employees
			let defaultIMUser: { id: string; username: string; name_en: string; name_ar: string } | null = null;
			if (defaultIMId) {
				const alreadyInEmployees = employees?.some(e => e.user_id === defaultIMId);
				if (!alreadyInEmployees) {
					// Fetch the IM user separately
					const { data: imUserData } = await supabase
						.from('users')
						.select('id, username')
						.eq('id', defaultIMId)
						.single();
					const { data: imEmpData } = await supabase
						.from('hr_employee_master')
						.select('name_en, name_ar')
						.eq('user_id', defaultIMId)
						.maybeSingle();
					if (imUserData) {
						defaultIMUser = {
							id: imUserData.id,
							username: imUserData.username,
							name_en: imEmpData?.name_en || '',
							name_ar: imEmpData?.name_ar || ''
						};
						console.log('🔍 [BT Approval] Default IM loaded separately:', defaultIMUser);
					}
				}
			}

			if (employees && employees.length > 0) {
				const userIds = employees.map(e => e.user_id).filter(Boolean);
				const { data: users } = await supabase
					.from('users')
					.select('id, username')
					.in('id', userIds)
					.eq('status', 'active')
					.order('username', { ascending: true });

				approvalBranchUsers = (users || []).map(u => {
					const emp = employees.find(e => e.user_id === u.id);
					return { id: u.id, username: u.username, name_en: emp?.name_en || '', name_ar: emp?.name_ar || '' };
				});
			}

			// 4) Add default IM to the list if not already there
			if (defaultIMUser && !approvalBranchUsers.some(u => u.id === defaultIMUser!.id)) {
				approvalBranchUsers = [defaultIMUser, ...approvalBranchUsers];
			}

			// 5) Preselect default IM
			if (defaultIMId && approvalBranchUsers.some(u => u.id === defaultIMId)) {
				selectedIMUserId = defaultIMId;
			}

			console.log('🔍 [BT Approval] approvalBranchUsers:', approvalBranchUsers.length, 'selectedIMUserId:', selectedIMUserId);
		} catch (err) {
			console.error('Error loading branch users for approval:', err);
		} finally {
			loadingIMUsers = false;
		}
	}

	function closeApprovalModal() {
		showApprovalModal = false;
		approvalRequestId = null;
		approvalBranchId = null;
		approvalBranchUsers = [];
		selectedIMUserId = null;
		defaultIMUserId = null;
		approvingRequest = false;
	}

	async function confirmApproval() {
		if (!approvalRequestId || !selectedIMUserId) return;
		approvingRequest = true;
		try {
			await updateStatus(approvalRequestId, 'approved');

			// Create Quick Task for the Inventory Manager to upload document
			const req = requests.find(r => r.id === approvalRequestId);
			if (req) {
				const imUser = approvalBranchUsers.find(u => u.id === selectedIMUserId);
				const imName = imUser ? ($locale === 'ar' ? imUser.name_ar || imUser.name_en : imUser.name_en || imUser.username) : 'Inventory Manager';
				try {
					const { data: imTask } = await supabase
						.from('quick_tasks')
						.insert({
							title: 'Upload BT Document | رفع مستند النقل الفرعي',
							description: `Branch Transfer approved. Upload the transfer document for this request.\n---\nتم قبول النقل الفرعي. قم برفع مستند النقل لهذا الطلب.`,
							priority: 'high',
							issue_type: 'product_request_process',
							assigned_by: $currentUser?.id,
							assigned_to_branch_id: req.to_branch_id,
							product_request_id: req.id,
							product_request_type: 'BT'
						})
						.select('id')
						.single();

					if (imTask) {
						await supabase.from('quick_task_assignments').insert({
							quick_task_id: imTask.id,
							assigned_to_user_id: selectedIMUserId,
							require_task_finished: true
						});
						// Track assigned IM so upload button appears immediately
						btAssignedIM[req.id] = selectedIMUserId!;
						btAssignedIM = btAssignedIM;
						console.log('✅ [BT] Quick task created for Inventory Manager:', imName);
					}
				} catch (taskErr) {
					console.warn('⚠️ [BT] Failed to create IM quick task:', taskErr);
				}
			}

			closeApprovalModal();
		} catch (err) {
			console.error('Error in confirmApproval:', err);
			approvingRequest = false;
		}
	}

	async function updateStatus(id: string, newStatus: 'approved' | 'rejected') {
		console.log('🔵 [BT] updateStatus called — id:', id, 'newStatus:', newStatus);
		try {
			const { error: err } = await supabase
				.from('product_request_bt')
				.update({ status: newStatus, updated_at: new Date().toISOString() })
				.eq('id', id);
			if (err) throw err;
			console.log('🟢 [BT] Status updated in DB successfully');
			requests = requests.map(r => r.id === id ? { ...r, status: newStatus } : r);
			if (selectedRequest?.id === id) selectedRequest = { ...selectedRequest, status: newStatus };

			// Auto-complete linked quick tasks & send notification to requester
			const req = requests.find(r => r.id === id);
			console.log('🟡 [BT] Found request object:', req ? 'YES' : 'NO');
			console.log('🟡 [BT] req.requester_user_id:', req?.requester_user_id);
			console.log('🟡 [BT] Full req keys:', req ? Object.keys(req) : 'N/A');
			if (req) {
				// 1) Auto-complete linked quick tasks (non-blocking)
				try {
					console.log('🔵 [BT] Querying linked quick tasks...');
					const { data: linkedTasks, error: qtErr } = await supabase
						.from('quick_tasks')
						.select('id')
						.eq('product_request_id', id)
						.eq('product_request_type', 'BT');
					console.log('🔵 [BT] Quick tasks query result:', { linkedTasks, qtErr });

					if (linkedTasks && linkedTasks.length > 0) {
						const taskIds = linkedTasks.map(t => t.id);
						await supabase.from('quick_task_assignments')
							.update({ status: 'completed', completed_at: new Date().toISOString() })
							.in('quick_task_id', taskIds);
						await supabase.from('quick_tasks')
							.update({ status: 'completed', completed_at: new Date().toISOString() })
							.in('id', taskIds);
						console.log('✅ [BT] Quick tasks auto-completed');
					}
				} catch (taskErr) {
					console.warn('⚠️ [BT] Failed to complete quick tasks:', taskErr);
				}

				// 2) Send notification to requester (independent - always runs)
				console.log('🔵 [BT] === NOTIFICATION BLOCK START ===');
				try {
					const statusLabel = newStatus === 'approved' ? 'Accepted ✅' : 'Rejected ❌';
					const statusLabelAr = newStatus === 'approved' ? 'مقبول ✅' : 'مرفوض ❌';
					const notifPayload = {
						title: `BT Request ${statusLabel} | طلب BT ${statusLabelAr}`,
						message: `Your Branch Transfer request has been ${newStatus}.\n---\nطلب النقل الفرعي الخاص بك تم ${newStatus === 'approved' ? 'قبوله' : 'رفضه'}.`,
						type: newStatus === 'approved' ? 'success' : 'error',
						priority: 'normal',
						target_type: 'specific_users',
						target_users: [req.requester_user_id],
						status: 'published',
						total_recipients: 1,
						created_at: new Date().toISOString()
					};
					console.log('📨 [BT] Notification payload:', JSON.stringify(notifPayload, null, 2));
					const { data: notifData, error: notifErr } = await supabase.from('notifications').insert(notifPayload).select();
					console.log('📨 [BT] Notification insert result — data:', notifData, 'error:', notifErr);
					if (notifErr) {
						console.error('❌ [BT] Notification insert failed:', notifErr);
					} else {
						console.log('✅ [BT] Notification sent successfully');
					}
				} catch (notifCatchErr) {
					console.error('⚠️ [BT] Notification CATCH error:', notifCatchErr);
				}
				console.log('🔵 [BT] === NOTIFICATION BLOCK END ===');
			} else {
				console.warn('🔴 [BT] req is falsy — cannot send notification! requests array length:', requests.length);
			}
		} catch (err: any) {
			console.error('🔴 [BT] OUTER catch — Error updating status:', err);
			alert('Failed to update status: ' + (err?.message || 'Unknown error'));
		}
	}

	function formatDate(dateStr: string) {
		if (!dateStr) return '—';
		const d = new Date(dateStr);
		return d.toLocaleDateString($locale === 'ar' ? 'ar-SA' : 'en-US', {
			year: 'numeric', month: 'short', day: 'numeric',
			hour: '2-digit', minute: '2-digit'
		});
	}

	function getStatusColor(status: string) {
		switch (status) {
			case 'pending': return 'bg-amber-100 text-amber-700 border-amber-200';
			case 'approved': return 'bg-emerald-100 text-emerald-700 border-emerald-200';
			case 'rejected': return 'bg-red-100 text-red-700 border-red-200';
			case 'completed': return 'bg-blue-100 text-blue-700 border-blue-200';
			default: return 'bg-slate-100 text-slate-600 border-slate-200';
		}
	}

	function getItemsCount(items: any): number {
		if (Array.isArray(items)) return items.length;
		try {
			const parsed = JSON.parse(items);
			return Array.isArray(parsed) ? parsed.length : 0;
		} catch { return 0; }
	}

	function getItemsList(items: any): { barcode: string; product_name: string; quantity: number; photo_url: string | null; is_available?: boolean; available_qty?: number }[] {
		if (Array.isArray(items)) return items;
		try {
			const parsed = JSON.parse(items);
			return Array.isArray(parsed) ? parsed : [];
		} catch { return []; }
	}

	function initEditableItems() {
		if (!selectedRequest) return;
		const items = getItemsList(selectedRequest.items);
		editableItems = items.map(item => ({
			...item,
			is_available: item.is_available ?? false,
			available_qty: item.available_qty ?? 0
		}));
	}

	$: if (selectedRequest) initEditableItems();

	async function toggleAvailability(index: number) {
		editableItems[index].is_available = !editableItems[index].is_available;
		if (!editableItems[index].is_available) {
			editableItems[index].available_qty = 0;
		} else {
			editableItems[index].available_qty = editableItems[index].quantity;
		}
		editableItems = editableItems;
		await saveAvailability();
	}

	async function uploadDocForRequest(reqId: string, event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input?.files?.[0];
		if (!file) return;
		uploadingDoc = reqId;
		try {
			const path = `bt/${reqId}/${Date.now()}_${file.name}`;
			const { error: upErr } = await supabase.storage.from('stock-documents').upload(path, file);
			if (upErr) throw upErr;
			const { data: urlData } = supabase.storage.from('stock-documents').getPublicUrl(path);
			const docUrl = urlData.publicUrl;
			const { error: dbErr } = await supabase.from('product_request_bt').update({ document_url: docUrl, updated_at: new Date().toISOString() }).eq('id', reqId);
			if (dbErr) throw dbErr;
			requests = requests.map(r => r.id === reqId ? { ...r, document_url: docUrl } : r);
			if (selectedRequest?.id === reqId) selectedRequest = { ...selectedRequest, document_url: docUrl };
		} catch (err: any) {
			console.error('Upload error:', err);
			alert('Upload failed: ' + (err?.message || 'Unknown error'));
		} finally {
			uploadingDoc = null;
			if (input) input.value = '';
		}
	}

	async function saveAvailability() {
		if (!selectedRequest) return;
		savingAvailability = true;
		try {
			const updatedItems = editableItems.map(item => ({
				barcode: item.barcode,
				product_name: item.product_name,
				quantity: item.quantity,
				photo_url: item.photo_url,
				is_available: item.is_available,
				available_qty: item.available_qty
			}));
			const { error: err } = await supabase
				.from('product_request_bt')
				.update({ items: updatedItems, updated_at: new Date().toISOString() })
				.eq('id', selectedRequest.id);
			if (err) throw err;
			selectedRequest.items = updatedItems;
			requests = requests.map(r => r.id === selectedRequest!.id ? { ...r, items: updatedItems } : r);
		} catch (err: any) {
			console.error('Error saving availability:', err);
			alert('Failed to save: ' + (err?.message || 'Unknown error'));
		} finally {
			savingAvailability = false;
		}
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">🔄</span>
			<h2 class="text-lg font-bold text-slate-800">{$t('nav.btRequests') || 'BT Requests'}</h2>
			<span class="text-xs font-semibold bg-blue-100 text-blue-600 px-3 py-1 rounded-full">{requests.length}</span>
		</div>
		<button
			class="flex items-center gap-2 px-4 py-2.5 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-xs"
			on:click={loadRequests}
		>
			<span>🔄</span>
			{$t('finance.assets.refresh')}
		</button>
	</div>

	<!-- Content -->
	<div class="flex-1 overflow-hidden p-6">
		{#if selectedRequest}
			<!-- Detail View -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
				<div class="flex items-center justify-between mb-6">
					<div class="flex items-center gap-3">
						<button
							class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600"
						on:click={goBackToList}
						>←</button>
						<h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
							<span>🔄</span> Branch Transfer Request
						</h3>
						<span class="text-xs px-3 py-1 rounded-full border font-bold {getStatusColor(selectedRequest.status)}">{selectedRequest.status.toUpperCase()}</span>
					</div>
					<div class="flex items-center gap-2">
						<span class="text-xs text-slate-400">{formatDate(selectedRequest.created_at)}</span>
						<button
							class="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all text-xs shadow-lg shadow-emerald-200"
							on:click={exportToExcel}
						>
							<span>📥</span> Export Excel
						</button>
						<button
							class="flex items-center gap-1.5 px-4 py-2 bg-slate-600 text-white font-bold rounded-xl hover:bg-slate-700 transition-all text-xs shadow-lg shadow-slate-200"
							on:click={printRequest}
						>
							<span>🖨️</span> Print
						</button>
				</div>
			</div>

				<!-- Request Info -->
				<div class="grid grid-cols-4 gap-4 mb-6">
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">From Branch</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.from_branch_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">To Branch</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.to_branch_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">Requester</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.requester_name}</p>
					</div>
					<div class="bg-slate-50 rounded-xl p-4">
						<span class="text-xs text-slate-400 font-bold uppercase">{$t('mobile.productRequestContent.manager') || 'Manager'}</span>
						<p class="text-sm font-bold text-slate-800 mt-1">{selectedRequest.target_name}</p>
					</div>
				</div>

				<!-- Items Table -->
				<div class="flex-1 overflow-auto">
					<table class="w-full text-xs border-collapse border border-slate-300">
						<thead class="sticky top-0 z-10">
							<tr class="bg-blue-600 text-white">
								<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">#</th>
								<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.barcode')}</th>
								<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.productName')}</th>
								<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.quantity')}</th>
								<th class="border-r border-blue-500 py-2.5 px-3 text-center font-bold">Availability</th>
								<th class="py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.photo')}</th>
							</tr>
						</thead>
						<tbody>
							{#each editableItems as item, i}
								<tr class="border-b border-slate-300 hover:bg-slate-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
									<td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-bold text-emerald-700 font-mono">{item.barcode || '—'}</td>
									<td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800">{item.product_name || '—'}</td>
									<td class="border-r border-slate-300 py-2 px-3 text-slate-600 font-mono">{item.quantity}</td>
									<td class="border-r border-slate-300 py-2 px-3">
										<div class="flex items-center gap-2 justify-center">
											<input type="checkbox" checked={item.is_available} on:change={() => toggleAvailability(i)} class="w-4 h-4 accent-emerald-600 cursor-pointer" />
											<input type="number" bind:value={item.available_qty} min="0" max={item.quantity} on:change={saveAvailability} class="w-14 px-1.5 py-0.5 border border-slate-300 rounded-lg text-center text-xs font-mono focus:outline-none focus:ring-2 focus:ring-blue-400" />
										</div>
									</td>
									<td class="py-2 px-3">
										{#if item.photo_url}
										<img src={getCachedImage(item.photo_url)} alt="Product" class="w-14 h-14 object-cover rounded-lg border border-slate-200 cursor-pointer hover:opacity-80 transition-all hover:shadow-lg" on:click|stopPropagation={() => lightboxUrl = getCachedImage(item.photo_url)} />
										{:else}
											<span class="text-slate-400">—</span>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{:else}
			<!-- List View -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 h-full flex flex-col overflow-hidden">
				<!-- Search & Filters Bar -->
				<div class="flex flex-wrap items-center gap-2 mb-4">
					<div class="relative flex-1 min-w-[180px] max-w-[320px]">
						<span class="absolute {$locale === 'ar' ? 'right-3' : 'left-3'} top-1/2 -translate-y-1/2 text-slate-400 text-sm pointer-events-none">🔍</span>
						<input type="text" bind:value={searchQuery} placeholder={$locale === 'ar' ? 'بحث بالاسم، الفرع، الباركود...' : 'Search name, branch, barcode...'} class="w-full {$locale === 'ar' ? 'pr-9 pl-3' : 'pl-9 pr-3'} py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-400 focus:border-transparent transition-all" />
					</div>
					<select bind:value={filterStatus} class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-400 cursor-pointer min-w-[110px]">
						<option value="">{$locale === 'ar' ? 'كل الحالات' : 'All Status'}</option>
						<option value="pending">{$locale === 'ar' ? 'قيد الانتظار' : 'Pending'}</option>
						<option value="approved">{$locale === 'ar' ? 'مقبول' : 'Approved'}</option>
						<option value="rejected">{$locale === 'ar' ? 'مرفوض' : 'Rejected'}</option>
						<option value="completed">{$locale === 'ar' ? 'مكتمل' : 'Completed'}</option>
					</select>
					<select bind:value={filterBranch} class="px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-400 cursor-pointer min-w-[120px]">
						<option value="">{$locale === 'ar' ? 'كل الفروع' : 'All Branches'}</option>
						{#each branchOptions as branch}
							<option value={branch}>{branch}</option>
						{/each}
					</select>
					<div class="flex items-center gap-1">
						<span class="text-[10px] text-slate-400 font-bold">{$locale === 'ar' ? 'من' : 'From'}</span>
						<input type="date" bind:value={filterDateFrom} class="px-2 py-1.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-400 cursor-pointer" />
					</div>
					<div class="flex items-center gap-1">
						<span class="text-[10px] text-slate-400 font-bold">{$locale === 'ar' ? 'إلى' : 'To'}</span>
						<input type="date" bind:value={filterDateTo} class="px-2 py-1.5 bg-white border border-slate-200 rounded-xl text-xs text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-400 cursor-pointer" />
					</div>
					{#if hasActiveFilters}
						<button on:click={clearFilters} class="px-3 py-2 bg-red-50 hover:bg-red-100 text-red-600 rounded-xl text-xs font-bold transition-all">✕ {$locale === 'ar' ? 'مسح' : 'Clear'}</button>
					{/if}
					<span class="text-[10px] text-slate-400 font-semibold {$locale === 'ar' ? 'mr-auto' : 'ml-auto'}">{filteredRequests.length} / {requests.length}</span>
				</div>

				{#if loading}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4 animate-bounce">🔄</div>
						<p class="text-slate-500 font-semibold">{$t('mobile.productRequestContent.loading')}</p>
					</div>
				{:else if error}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">❌</div>
						<p class="text-red-500 font-semibold">{error}</p>
					</div>
				{:else if requests.length === 0}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">📭</div>
						<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد طلبات نقل' : 'No branch transfer requests found'}</p>
					</div>
				{:else if filteredRequests.length === 0}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">🔍</div>
						<p class="text-slate-500 font-semibold">{$locale === 'ar' ? 'لا توجد نتائج مطابقة' : 'No matching results'}</p>
						<button on:click={clearFilters} class="mt-2 px-4 py-2 bg-blue-50 text-blue-600 rounded-xl text-xs font-bold hover:bg-blue-100 transition-all">{$locale === 'ar' ? 'مسح الفلاتر' : 'Clear Filters'}</button>
					</div>
				{:else}
					<div class="flex-1 overflow-auto" bind:this={listScrollContainer}>
						<table class="w-full text-xs border-collapse border border-slate-300">
							<thead class="sticky top-0 z-10">
								<tr class="bg-blue-600 text-white">
									<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">#</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">From Branch</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">To Branch</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">Requester</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">{$t('mobile.productRequestContent.manager') || 'Manager'}</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">Items</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">Status</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-left font-bold">Date</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-center font-bold">Docs</th>
									<th class="border-r border-blue-500 py-2.5 px-3 text-center font-bold">Approve</th>
									<th class="py-2.5 px-3 text-center font-bold">Reject</th>
								</tr>
							</thead>
							<tbody>
								{#each filteredRequests as req, i}
									<tr class="border-b border-slate-300 hover:bg-slate-50/50 cursor-pointer {highlightedRequestId === req.id ? 'bg-blue-100/80 ring-1 ring-blue-300' : i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}" on:click={() => openDetail(req)}>
										<td class="border-r border-slate-300 py-2.5 px-3 text-slate-400 font-mono">{i + 1}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-slate-800">{req.from_branch_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-blue-700">{req.to_branch_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-slate-700">{req.requester_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 font-semibold text-emerald-700">{req.target_name}</td>
										<td class="border-r border-slate-300 py-2.5 px-3">
											<button
												class="px-2.5 py-1 bg-blue-50 hover:bg-blue-100 rounded-lg transition-all text-blue-700 hover:text-blue-900 text-[10px] font-bold whitespace-nowrap"
												on:click|stopPropagation={() => openDetail(req)}
											>
												{getItemsCount(req.items)} — View
											</button>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3">
											<span class="text-[10px] px-2.5 py-1 rounded-full border font-bold {getStatusColor(req.status)}">{req.status.toUpperCase()}</span>
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-slate-500 text-[10px]">{formatDate(req.created_at)}</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-center" on:click|stopPropagation>
											{#if req.document_url}
												<div class="flex items-center gap-1 justify-center">
													<a href={req.document_url} target="_blank" rel="noopener" class="px-2 py-0.5 bg-blue-50 hover:bg-blue-100 rounded-lg text-blue-600 hover:text-blue-800 text-[10px] font-bold" title="View Document">📄 View</a>
													{#if btAssignedIM[req.id] === $currentUser?.id}
														<label class="px-2 py-0.5 bg-slate-100 hover:bg-slate-200 rounded-lg text-slate-600 hover:text-slate-800 text-[10px] font-bold cursor-pointer {uploadingDoc === req.id ? 'opacity-50 pointer-events-none' : ''}">
															🔄 {uploadingDoc === req.id ? '...' : 'Update'}
															<input type="file" class="hidden" on:change={(e) => uploadDocForRequest(req.id, e)} />
														</label>
													{/if}
												</div>
											{:else if btAssignedIM[req.id] === $currentUser?.id}
												<label class="px-2 py-1 bg-blue-50 hover:bg-blue-100 rounded-lg transition-all text-blue-700 text-[10px] font-bold cursor-pointer whitespace-nowrap {uploadingDoc === req.id ? 'opacity-50 pointer-events-none' : ''}">
													📎 {uploadingDoc === req.id ? '...' : 'Upload'}
													<input type="file" class="hidden" on:change={(e) => uploadDocForRequest(req.id, e)} on:click|stopPropagation />
												</label>
											{:else}
												<span class="text-[10px] text-slate-400">—</span>
											{/if}
										</td>
										<td class="border-r border-slate-300 py-2.5 px-3 text-center">
											{#if req.status === 'pending' && req.target_user_id === $currentUser?.id}
												<button
													class="p-1.5 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition-all text-emerald-600 hover:text-emerald-800"
													on:click|stopPropagation={() => openApprovalModal(req.id)}
													title="Approve"
												>
													✅
												</button>
											{/if}
										</td>
										<td class="py-2.5 px-3 text-center">
											{#if req.status === 'pending' && req.target_user_id === $currentUser?.id}
												<button
													class="p-1.5 bg-red-50 hover:bg-red-100 rounded-lg transition-all text-red-600 hover:text-red-800"
													on:click|stopPropagation={() => updateStatus(req.id, 'rejected')}
													title="Reject"
												>
													❌
												</button>
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>

<!-- Photo Lightbox -->
{#if lightboxUrl}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/70 backdrop-blur-sm" on:click={() => lightboxUrl = null} role="button" tabindex="-1">
		<div class="relative max-w-[80vw] max-h-[80vh]">
			<img src={lightboxUrl} alt="Product" class="max-w-full max-h-[80vh] object-contain rounded-2xl shadow-2xl" />
			<button
				class="absolute -top-3 -right-3 w-8 h-8 bg-white text-slate-600 rounded-full text-sm font-bold flex items-center justify-center hover:bg-red-50 hover:text-red-600 transition-all shadow-lg"
				on:click|stopPropagation={() => lightboxUrl = null}
			>✕</button>
		</div>
	</div>
{/if}

<!-- BT Approval Modal -->
{#if showApprovalModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<div class="fixed inset-0 z-[9998] flex items-center justify-center bg-black/50 backdrop-blur-sm" on:click={closeApprovalModal} role="button" tabindex="-1">
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<div class="bg-white rounded-2xl shadow-2xl w-[440px] max-h-[80vh] overflow-hidden" on:click|stopPropagation role="dialog" tabindex="-1">
			<!-- Header -->
			<div class="bg-gradient-to-r from-blue-500 to-blue-600 text-white px-6 py-4 flex items-center justify-between">
				<h3 class="font-bold text-base flex items-center gap-2">✅ Approve BT Request</h3>
				<button class="text-white/80 hover:text-white text-lg" on:click={closeApprovalModal}>✕</button>
			</div>
			<!-- Body -->
			<div class="p-6 space-y-4">
				<div>
					<label for="im-select" class="block text-sm font-semibold text-slate-700 mb-2">
						📦 Select Inventory Manager
						<span class="text-xs text-slate-400 font-normal">| اختر مدير المخزون</span>
					</label>
					{#if loadingIMUsers}
						<div class="flex items-center gap-2 text-sm text-slate-500 py-3">
							<div class="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
							Loading users...
						</div>
					{:else if approvalBranchUsers.length === 0}
						<p class="text-sm text-red-500 py-2">⚠️ No users found for this branch</p>
					{:else}
						<select
							id="im-select"
							bind:value={selectedIMUserId}
							class="w-full px-3 py-2.5 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all bg-white"
						>
							<option value={null}>-- Select Inventory Manager --</option>
							{#each approvalBranchUsers as user}
								<option value={user.id}>
									{$locale === 'ar' ? (user.name_ar || user.name_en || user.username) : (user.name_en || user.username)}
									{user.id === defaultIMUserId ? ' ⭐ Default' : ''}
								</option>
							{/each}
						</select>
						{#if selectedIMUserId}
							<p class="mt-2 text-xs text-slate-500">
								A Quick Task will be created for this user to upload the transfer document.
							</p>
						{/if}
					{/if}
				</div>
			</div>
			<!-- Footer -->
			<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex items-center justify-end gap-3">
				<button
					class="px-4 py-2 text-sm font-semibold text-slate-600 bg-white border border-slate-300 rounded-xl hover:bg-slate-100 transition-all"
					on:click={closeApprovalModal}
					disabled={approvingRequest}
				>Cancel</button>
				<button
					class="px-5 py-2 text-sm font-bold text-white bg-emerald-500 rounded-xl hover:bg-emerald-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
					on:click={confirmApproval}
					disabled={!selectedIMUserId || approvingRequest}
				>
					{#if approvingRequest}
						<div class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
						Approving...
					{:else}
						✅ Approve
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}
