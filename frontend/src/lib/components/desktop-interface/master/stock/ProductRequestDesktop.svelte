<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';
	import XLSX from 'xlsx-js-style';

	onMount(() => {
		loadPurchasingManagers();
	});

	// ─── Types ───
	interface ProductItem {
		barcode: string;
		productName: string;
		quantity: number;
		photo: string | null;
	}

	interface BranchOption {
		id: number;
		name_en: string;
		name_ar: string;
		location_en: string;
		location_ar: string;
	}

	interface UserOption {
		id: string;
		username: string;
		name_en?: string;
		name_ar?: string;
	}

	type RequestType = 'BT' | 'ST' | 'PO';

	// ─── Tab / View State ───
	let activeTab: RequestType = 'PO';

	// ─── Items (per-tab) ───
	let itemsByTab: Record<RequestType, ProductItem[]> = { BT: [], ST: [], PO: [] };
	$: items = itemsByTab[activeTab];

	// ─── Add Item Modal ───
	let showModal = false;
	let modalBarcode = '';
	let modalProductName = '';
	let modalQuantity = 1;
	let modalPhoto: string | null = null;
	let fileInput: HTMLInputElement;

	// ─── Branch / User State ───
	let branches: BranchOption[] = [];
	let selectedBranchId: number | null = null;
	let selectedUserId: string | null = null;
	let selectedUserName: string = '';
	let branchUsers: UserOption[] = [];
	let loadingBranches = false;
	let loadingUsers = false;
	let noDefaultPosition = false;
	let sending = false;
	let sendSuccess = false;
	let sendError = '';

	// ─── Import State (per-tab) ───
	let importFileInput: HTMLInputElement;
	let importPreviewByTab: Record<RequestType, { barcode: string; productName: string; quantity: number }[]> = { BT: [], ST: [], PO: [] };
	let importFileNameByTab: Record<RequestType, string> = { BT: '', ST: '', PO: '' };
	$: importPreview = importPreviewByTab[activeTab];
	$: importFileName = importFileNameByTab[activeTab];

	// ─── Tabs config ───
	$: tabs = [
		{ id: 'PO' as RequestType, label: `PO - ${$t('mobile.productRequestContent.purchaseOrder')}`, icon: '🛒', color: 'orange' },
		{ id: 'ST' as RequestType, label: `ST - ${$t('mobile.productRequestContent.inBranch')}`, icon: '📦', color: 'green' },
		{ id: 'BT' as RequestType, label: `BT - ${$t('mobile.productRequestContent.branchTransfer')}`, icon: '🔄', color: 'orange' },
	];

	// ─── Branch / User Logic (same as mobile) ───

	async function loadBranches() {
		loadingBranches = true;
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.eq('is_active', true)
				.order('name_en', { ascending: true });
			if (error) throw error;
			branches = data || [];
		} catch (err) {
			console.error('Error loading branches:', err);
		} finally {
			loadingBranches = false;
		}
	}

	async function loadBranchManager(branchId: number) {
		noDefaultPosition = false;
		try {
			const { data, error } = await supabase
				.from('branch_default_positions')
				.select('branch_manager_user_id')
				.eq('branch_id', branchId)
				.single();
			if (error) {
				noDefaultPosition = true;
				selectedUserId = null;
				selectedUserName = '';
				return;
			}
			if (data?.branch_manager_user_id) {
				selectedUserId = data.branch_manager_user_id;
				const { data: userData, error: userError } = await supabase
					.from('users')
					.select('username')
					.eq('id', data.branch_manager_user_id)
					.single();
				if (!userError && userData) {
					selectedUserName = userData.username;
				}
			} else {
				noDefaultPosition = true;
				selectedUserId = null;
				selectedUserName = '';
			}
		} catch (err) {
			console.error('Error loading branch manager:', err);
			noDefaultPosition = true;
			selectedUserId = null;
			selectedUserName = '';
		}
	}

	const PURCHASING_MANAGER_POSITION_ID = '540c129e-79b4-4100-b645-086ef2485449';

	async function loadPurchasingManagers() {
		loadingUsers = true;
		try {
			const { data: employees, error: empError } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar')
				.eq('current_position_id', PURCHASING_MANAGER_POSITION_ID);
			if (empError) throw empError;
			if (!employees || employees.length === 0) {
				branchUsers = [];
				return;
			}
			const userIds = employees.map(e => e.user_id);
			const { data: users, error: userError } = await supabase
				.from('users')
				.select('id, username')
				.in('id', userIds)
				.eq('status', 'active')
				.order('username', { ascending: true });
			if (userError) throw userError;
			branchUsers = (users || []).map(u => {
				const emp = employees.find(e => e.user_id === u.id);
				return { id: u.id, username: u.username, name_en: emp?.name_en || '', name_ar: emp?.name_ar || '' };
			});
			if (branchUsers.length === 1) {
				selectedUserId = branchUsers[0].id;
				selectedUserName = branchUsers[0].name_en || branchUsers[0].username;
			}
		} catch (err) {
			console.error('Error loading purchasing managers:', err);
		} finally {
			loadingUsers = false;
		}
	}

	async function selectTab(type: RequestType) {
		activeTab = type;
		selectedBranchId = null;
		selectedUserId = null;
		selectedUserName = '';
		branchUsers = [];
		noDefaultPosition = false;
		sendError = '';
		sendSuccess = false;

		if (type === 'BT') {
			await loadBranches();
		} else if (type === 'ST') {
			await loadBranches();
			const userBranchId = $currentUser?.branch_id;
			if (userBranchId) {
				selectedBranchId = Number(userBranchId);
				await loadBranchManager(selectedBranchId);
			}
		} else if (type === 'PO') {
			await loadPurchasingManagers();
		}
	}

	async function onBranchSelected() {
		if (!selectedBranchId) return;
		selectedUserId = null;
		selectedUserName = '';
		branchUsers = [];
		await loadBranchManager(selectedBranchId);
	}

	function onUserSelected() {
		const user = branchUsers.find(u => u.id === selectedUserId);
		selectedUserName = user ? (user.name_en || user.username) : '';
	}

	// ─── Download Template ───

	function downloadTemplate() {
		const isAr = $locale === 'ar';
		const headers = [
			[isAr ? 'الباركود' : 'Barcode', isAr ? 'اسم المنتج' : 'Product Name', isAr ? 'الكمية' : 'Quantity'],
			['6281000000001', isAr ? 'حليب المراعي 1 لتر' : 'Almarai Milk 1L', 5],
			['6281000000002', isAr ? 'أرز بسمتي 5 كجم' : 'Basmati Rice 5kg', 10],
		];

		const ws = XLSX.utils.aoa_to_sheet(headers);

		const headerStyle = {
			font: { bold: true, color: { rgb: 'FFFFFF' }, sz: 12 },
			fill: { fgColor: { rgb: 'EA580C' } },
			alignment: { horizontal: 'center', vertical: 'center' },
			border: {
				top: { style: 'thin', color: { rgb: '000000' } },
				bottom: { style: 'thin', color: { rgb: '000000' } },
				left: { style: 'thin', color: { rgb: '000000' } },
				right: { style: 'thin', color: { rgb: '000000' } },
			}
		};

		for (let c = 0; c < 3; c++) {
			const ref = XLSX.utils.encode_cell({ r: 0, c });
			if (ws[ref]) ws[ref].s = headerStyle;
		}

		ws['!cols'] = [{ wch: 20 }, { wch: 35 }, { wch: 12 }];

		const wb = XLSX.utils.book_new();
		XLSX.utils.book_append_sheet(wb, ws, 'Product Request');
		XLSX.writeFile(wb, `Product_Request_Template_${activeTab}.xlsx`);
	}

	// ─── Import from XLSX ───

	function handleImportFile(e: Event) {
		const target = e.target as HTMLInputElement;
		const file = target.files?.[0];
		if (!file) return;
		importFileNameByTab[activeTab] = file.name;

		const tab = activeTab; // capture current tab
		const reader = new FileReader();
		reader.onload = (evt) => {
			const data = new Uint8Array(evt.target?.result as ArrayBuffer);
			const wb = XLSX.read(data, { type: 'array' });
			const ws = wb.Sheets[wb.SheetNames[0]];
			const rows: any[][] = XLSX.utils.sheet_to_json(ws, { header: 1 });

			const preview: { barcode: string; productName: string; quantity: number }[] = [];
			for (let i = 1; i < rows.length; i++) {
				const row = rows[i];
				if (!row || (!row[0] && !row[1])) continue;
				preview.push({
					barcode: String(row[0] || '').trim(),
					productName: String(row[1] || '').trim(),
					quantity: parseInt(row[2]) || 1
				});
			}
			importPreviewByTab[tab] = preview;
		};
		reader.readAsArrayBuffer(file);
	}

	function confirmImport() {
		for (const row of importPreviewByTab[activeTab]) {
			itemsByTab[activeTab] = [...itemsByTab[activeTab], { barcode: row.barcode, productName: row.productName, quantity: row.quantity, photo: null }];
		}
		importPreviewByTab[activeTab] = [];
		importFileNameByTab[activeTab] = '';
		if (importFileInput) importFileInput.value = '';
	}

	function cancelImport() {
		importPreviewByTab[activeTab] = [];
		importFileNameByTab[activeTab] = '';
		if (importFileInput) importFileInput.value = '';
	}

	// ─── Add Item Modal ───

	function openModal() {
		// Auto-confirm any pending import so manually added items join the same table
		if (importPreview.length > 0) {
			confirmImport();
		}
		modalBarcode = '';
		modalProductName = '';
		modalQuantity = 1;
		modalPhoto = null;
		showModal = true;
	}

	function closeModal() {
		showModal = false;
	}

	function addItem() {
		if (!modalProductName.trim() && !modalBarcode.trim()) return;
		itemsByTab[activeTab] = [...itemsByTab[activeTab], { barcode: modalBarcode, productName: modalProductName, quantity: modalQuantity, photo: modalPhoto }];
		closeModal();
	}

	function removeItem(index: number) {
		itemsByTab[activeTab] = itemsByTab[activeTab].filter((_, i) => i !== index);
	}

	function handlePhoto(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (file) {
			const reader = new FileReader();
			reader.onload = (e) => {
				modalPhoto = e.target?.result as string;
			};
			reader.readAsDataURL(file);
		}
	}

	function removePhoto() {
		modalPhoto = null;
		if (fileInput) fileInput.value = '';
	}

	// ─── Photo Upload & Send ───

	async function uploadPhoto(photo: string, index: number): Promise<string | null> {
		try {
			const res = await fetch(photo);
			const blob = await res.blob();
			const ext = blob.type.split('/')[1] || 'jpg';
			const fileName = `pr-${activeTab}-${Date.now()}-${index}.${ext}`;

			const { error } = await supabase.storage
				.from('product-request-photos')
				.upload(fileName, blob, { cacheControl: '3600', upsert: false });

			if (error) {
				console.error('Photo upload error:', error);
				return null;
			}

			const { data: urlData } = supabase.storage
				.from('product-request-photos')
				.getPublicUrl(fileName);

			return urlData.publicUrl;
		} catch (err) {
			console.error('Error uploading photo:', err);
			return null;
		}
	}

	async function handleSend() {
		if (!selectedUserId || !$currentUser?.id) return;
		sending = true;
		sendError = '';
		sendSuccess = false;

		try {
			const itemsData = await Promise.all(items.map(async (item, i) => {
				let photoUrl: string | null = null;
				if (item.photo) {
					photoUrl = await uploadPhoto(item.photo, i);
				}
				return {
					barcode: item.barcode,
					product_name: item.productName,
					quantity: item.quantity,
					photo_url: photoUrl
				};
			}));

			let error;
			let requestId: string | null = null;

			if (activeTab === 'BT') {
				const fromBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
				const result = await supabase
					.from('product_request_bt')
					.insert({
						requester_user_id: $currentUser.id,
						from_branch_id: fromBranchId,
						to_branch_id: selectedBranchId,
						target_user_id: selectedUserId,
						status: 'pending',
						items: itemsData
					})
					.select('id')
					.single();
				error = result.error;
				requestId = result.data?.id || null;
			} else if (activeTab === 'ST') {
				const result = await supabase
					.from('product_request_st')
					.insert({
						requester_user_id: $currentUser.id,
						branch_id: selectedBranchId,
						target_user_id: selectedUserId,
						status: 'pending',
						items: itemsData
					})
					.select('id')
					.single();
				error = result.error;
				requestId = result.data?.id || null;
			} else if (activeTab === 'PO') {
				const fromBranchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
				const result = await supabase
					.from('product_request_po')
					.insert({
						requester_user_id: $currentUser.id,
						from_branch_id: fromBranchId,
						target_user_id: selectedUserId,
						status: 'pending',
						items: itemsData
					})
					.select('id')
					.single();
				error = result.error;
				requestId = result.data?.id || null;
			}

			if (error) throw error;

			// Create Quick Tasks for requester (follow up) and receiver (process)
			if (requestId && selectedUserId) {
				try {
					const requesterName = $currentUser?.username || 'User';
					const receiverName = selectedUserName || 'Receiver';
					const branchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;
					const typeLabel = activeTab === 'BT' ? 'Branch Transfer' : activeTab === 'ST' ? 'Stock Request' : 'Purchase Order';
					const typeLabelAr = activeTab === 'BT' ? 'نقل فرعي' : activeTab === 'ST' ? 'طلب مخزون' : 'أمر شراء';

					// Task for requester: follow up
					const { data: requesterTask } = await supabase
						.from('quick_tasks')
						.insert({
							title: `Follow up ${activeTab} Request | متابعة طلب ${activeTab}`,
							description: `${typeLabel} request sent to ${receiverName}. Follow up until processed.\n---\nطلب ${typeLabelAr} مرسل إلى ${receiverName}. تابع حتى تتم المعالجة.`,
							priority: 'medium',
							issue_type: 'product_request_follow_up',
							assigned_by: $currentUser.id,
							assigned_to_branch_id: branchId,
							product_request_id: requestId,
							product_request_type: activeTab
						})
						.select('id')
						.single();

					if (requesterTask) {
						await supabase.from('quick_task_assignments').insert({
							quick_task_id: requesterTask.id,
							assigned_to_user_id: $currentUser.id,
							require_task_finished: true
						});
					}

					// Task for receiver: process request
					const { data: receiverTask } = await supabase
						.from('quick_tasks')
						.insert({
							title: `Process ${activeTab} Request | معالجة طلب ${activeTab}`,
							description: `${typeLabel} request from ${requesterName}. Review and accept or reject.\n---\nطلب ${typeLabelAr} من ${requesterName}. راجع واقبل أو ارفض.`,
							priority: 'high',
							issue_type: 'product_request_process',
							assigned_by: $currentUser.id,
							assigned_to_branch_id: selectedBranchId,
							product_request_id: requestId,
							product_request_type: activeTab
						})
						.select('id')
						.single();

					if (receiverTask) {
						await supabase.from('quick_task_assignments').insert({
							quick_task_id: receiverTask.id,
							assigned_to_user_id: selectedUserId,
							require_task_finished: true
						});
					}

					console.log('✅ Quick tasks created for product request:', requestId);
				} catch (taskErr) {
					console.warn('⚠️ Failed to create quick tasks:', taskErr);
				}
			}

			sendSuccess = true;
			setTimeout(() => {
				itemsByTab[activeTab] = [];
				sendSuccess = false;
			}, 1500);
		} catch (err: any) {
			console.error('Error sending request:', err);
			sendError = err?.message || 'Failed to send request';
		} finally {
			sending = false;
		}
	}

	// ─── Helpers ───
	$: canSend = items.length > 0 && selectedUserId && (
		(activeTab === 'BT' && selectedBranchId) ||
		(activeTab === 'ST' && selectedUserId) ||
		(activeTab === 'PO' && selectedUserId)
	);
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header/Navigation -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<button
			class="flex items-center gap-2 px-4 py-2.5 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-xs"
			on:click={() => { itemsByTab[activeTab] = []; importPreviewByTab[activeTab] = []; importFileNameByTab[activeTab] = ''; selectedBranchId = null; selectedUserId = null; selectedUserName = ''; branchUsers = []; noDefaultPosition = false; sendError = ''; sendSuccess = false; selectTab(activeTab); }}
		>
			<span>🔄</span>
			{$t('finance.assets.refresh')}
		</button>
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			{#each tabs as tab}
				<button
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
					{activeTab === tab.id
						? (tab.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' : 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]')
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={() => selectTab(tab.id)}
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
					<span class="relative z-10">{tab.label}</span>

					{#if activeTab === tab.id}
						<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
					{/if}
				</button>
			{/each}
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col gap-6">

			<!-- Top row: Request config + Add item -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8">
				<h3 class="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2">
					<span>{activeTab === 'PO' ? '🛒' : activeTab === 'ST' ? '📦' : '🔄'}</span>
					{activeTab === 'PO' ? $t('mobile.productRequestContent.purchaseOrder') : activeTab === 'ST' ? $t('mobile.productRequestContent.inBranch') : $t('mobile.productRequestContent.branchTransfer')}
				</h3>

				<div class="grid grid-cols-3 gap-6 max-w-5xl">
					<!-- Branch Selection (BT & ST) -->
					{#if activeTab === 'BT' || activeTab === 'ST'}
						<div class="form-group">
							<span class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('mobile.productRequestContent.selectBranch')}</span>
							{#if loadingBranches}
								<div class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-400 flex items-center gap-2">
									<span class="animate-spin">⏳</span> {$t('mobile.productRequestContent.loading')}
								</div>
							{:else}
								<select
									bind:value={selectedBranchId}
									on:change={onBranchSelected}
									class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
								>
									<option value={null}>{$t('mobile.productRequestContent.chooseBranch')}</option>
									{#each branches as branch}
										<option value={branch.id}>{$locale === 'ar' ? branch.name_ar : branch.name_en} - {$locale === 'ar' ? branch.location_ar : branch.location_en}</option>
									{/each}
								</select>
							{/if}
						</div>
					{/if}

					<!-- Manager (auto-selected for BT/ST) -->
					{#if (activeTab === 'BT' || activeTab === 'ST') && selectedUserId}
						<div class="form-group">
							<span class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('mobile.productRequestContent.manager')}</span>
							<div class="w-full px-4 py-2.5 bg-emerald-50 border border-emerald-200 rounded-xl text-sm font-bold text-emerald-700 flex items-center gap-2">
								<span>👤</span> {selectedUserName}
							</div>
						</div>
					{/if}

					<!-- No default position warning -->
					{#if (activeTab === 'BT' || activeTab === 'ST') && noDefaultPosition && selectedBranchId}
						<div class="form-group col-span-2">
							<div class="w-full px-4 py-2.5 bg-amber-50 border border-amber-200 rounded-xl text-sm font-semibold text-amber-700 flex items-center gap-2">
								<span>⚠️</span> {$t('mobile.productRequestContent.noDefaultPosition')}
							</div>
						</div>
					{/if}

					<!-- Purchasing Manager Dropdown (PO) -->
					{#if activeTab === 'PO'}
						<div class="form-group">
							<span class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('mobile.productRequestContent.selectUser')}</span>
							{#if loadingUsers}
								<div class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-400 flex items-center gap-2">
									<span class="animate-spin">⏳</span> {$t('mobile.productRequestContent.loading')}
								</div>
							{:else}
								<select
									bind:value={selectedUserId}
									on:change={onUserSelected}
									class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
								>
									<option value={null}>{$t('mobile.productRequestContent.chooseUser')}</option>
									{#each branchUsers as user}
										<option value={user.id}>{$locale === 'ar' ? (user.name_ar || user.username) : (user.name_en || user.username)}</option>
									{/each}
								</select>
							{/if}
						</div>
					{/if}

					<!-- Action Buttons -->
					<div class="form-group flex items-end gap-2">
						<button
							class="flex items-center gap-2 px-8 py-2.5 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 text-sm whitespace-nowrap"
							on:click={openModal}
						>
							<span>➕</span>
							{$t('mobile.productRequestContent.addItem')}
						</button>
						<button
							class="flex items-center gap-2 px-8 py-2.5 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 text-sm whitespace-nowrap"
							on:click={downloadTemplate}
						>
							<span>📥</span>
							{$t('finance.assets.downloadTemplate')}
						</button>
						<button
							class="flex items-center gap-2 px-8 py-2.5 bg-slate-600 text-white font-bold rounded-xl hover:bg-slate-700 transition-all shadow-lg shadow-slate-200 text-sm whitespace-nowrap"
							on:click={() => { if (importFileInput) importFileInput.value = ''; importFileInput?.click(); }}
						>
							<span>📤</span>
							{$t('finance.assets.importAssets')}
						</button>
						<input type="file" accept=".xlsx,.xls" on:change={handleImportFile} class="hidden" bind:this={importFileInput} />
					</div>
				</div>
			</div>

			<!-- Import Preview (shown when file is loaded) -->
			{#if importPreview.length > 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 flex flex-col overflow-hidden max-h-[300px]">
					<div class="flex items-center justify-between mb-4">
						<h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
							<span>📂</span>
							{importFileName}
							<span class="text-xs font-normal bg-orange-100 px-3 py-1 rounded-full text-orange-600">{importPreview.length} rows</span>
						</h3>
						<div class="flex items-center gap-2">
							<button
								class="px-5 py-2 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-xs"
								on:click={cancelImport}
							>
								{$t('mobile.productRequestContent.close')}
							</button>
							<button
								class="px-5 py-2 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 text-xs flex items-center gap-2"
								on:click={confirmImport}
							>
								<span>✅</span>
								{$t('finance.assets.importAndSave')}
							</button>
						</div>
					</div>
					<div class="flex-1 overflow-auto">
						<table class="w-full text-xs border-collapse border border-slate-300">
							<thead class="sticky top-0 z-10">
								<tr class="bg-orange-600 text-white">
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">#</th>
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('mobile.productRequestContent.barcode')}</th>
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('mobile.productRequestContent.productName')}</th>
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('mobile.productRequestContent.quantity')}</th>
								</tr>
							</thead>
							<tbody>
								{#each importPreview as row, i}
									<tr class="border-b border-slate-300 hover:bg-slate-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
										<td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
										<td class="border-r border-slate-300 py-2 px-3 font-bold text-emerald-700 font-mono">{row.barcode || '—'}</td>
										<td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800">{row.productName}</td>
										<td class="border-r border-slate-300 py-2 px-3 text-slate-600 font-mono">{row.quantity}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}

			<!-- Items Table -->
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-8 flex-1 flex flex-col overflow-hidden">
				<div class="flex items-center justify-between mb-4">
					<h3 class="text-lg font-bold text-slate-800 flex items-center gap-2">
						<span>📋</span>
						{$t('mobile.productRequestContent.addItem')}
						<span class="text-xs font-normal bg-slate-100 px-3 py-1 rounded-full text-slate-500">{items.length}</span>
					</h3>
					<div class="flex items-center gap-3">
						{#if sendSuccess}
							<div class="px-4 py-2 bg-emerald-50 border border-emerald-200 rounded-xl text-xs font-bold text-emerald-700 flex items-center gap-2">
								<span>✅</span> {$t('mobile.productRequestContent.sendSuccess')}
							</div>
						{/if}
						{#if sendError}
							<div class="px-4 py-2 bg-red-50 border border-red-200 rounded-xl text-xs font-bold text-red-700 flex items-center gap-2">
								<span>❌</span> {sendError}
							</div>
						{/if}
						{#if canSend}
							<button
								class="flex items-center gap-2 px-6 py-2.5 bg-emerald-600 text-white font-bold rounded-xl hover:bg-emerald-700 transition-all shadow-lg shadow-emerald-200 text-sm disabled:opacity-50 disabled:cursor-not-allowed"
								on:click={handleSend}
								disabled={sending}
							>
								{#if sending}
									<span class="animate-spin">⏳</span>
								{:else}
									<span>📤</span>
								{/if}
								{$t('mobile.productRequestContent.send')}
							</button>
						{/if}
					</div>
				</div>

				{#if items.length === 0}
					<div class="flex-1 flex flex-col items-center justify-center">
						<div class="text-5xl mb-4">📦</div>
						<p class="text-slate-500 font-semibold">{$t('mobile.productRequestContent.addItem')}</p>
						<p class="text-slate-400 text-sm mt-1">{$t('mobile.productRequestContent.barcodePlaceholder')}</p>
					</div>
				{:else}
					<div class="flex-1 overflow-auto">
						<table class="w-full text-xs border-collapse border border-slate-300">
							<thead class="sticky top-0 z-10">
								<tr class="bg-emerald-600 text-white">
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">#</th>
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('mobile.productRequestContent.barcode')}</th>
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('mobile.productRequestContent.productName')}</th>
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('mobile.productRequestContent.quantity')}</th>
									<th class="border-r border-slate-300 py-2 px-3 text-left font-bold">{$t('mobile.productRequestContent.photo')}</th>
									<th class="border-r border-slate-300 py-2 px-3 text-center font-bold">{$t('finance.assets.actions')}</th>
								</tr>
							</thead>
							<tbody>
								{#each items as item, i}
									<tr class="border-b border-slate-300 hover:bg-slate-50/50 {i % 2 === 0 ? 'bg-white/30' : 'bg-slate-50/30'}">
										<td class="border-r border-slate-300 py-2 px-3 text-slate-400 font-mono">{i + 1}</td>
										<td class="border-r border-slate-300 py-2 px-3 font-bold text-emerald-700 font-mono">{item.barcode || '—'}</td>
										<td class="border-r border-slate-300 py-2 px-3 font-semibold text-slate-800">{item.productName || '—'}</td>
										<td class="border-r border-slate-300 py-2 px-3 text-slate-600 font-mono">{item.quantity}</td>
										<td class="border-r border-slate-300 py-2 px-3">
											{#if item.photo}
												<img src={item.photo} alt="Product" class="w-8 h-8 object-cover rounded-lg border border-slate-200" />
											{:else}
												<span class="text-slate-400">—</span>
											{/if}
										</td>
										<td class="border-r border-slate-300 py-2 px-3 text-center">
											<button
												class="p-1.5 bg-red-50 hover:bg-red-100 rounded-lg transition-all text-red-600 hover:text-red-800"
												on:click={() => removeItem(i)}
												title="Remove"
											>
												🗑️
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		</div>
	</div>
</div>

<!-- Add Item Modal -->
{#if showModal}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/40 backdrop-blur-sm" on:click={closeModal} role="button" tabindex="-1">
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<div class="bg-white rounded-[2rem] shadow-2xl w-[520px] max-h-[90vh] overflow-y-auto" on:click|stopPropagation role="none">
			<!-- Modal Header -->
			<div class="px-8 py-5 border-b border-slate-100 flex items-center justify-between">
				<h3 class="text-base font-bold text-slate-800 flex items-center gap-2">
					<span>➕</span> {$t('mobile.productRequestContent.addItem')}
				</h3>
				<button class="p-2 hover:bg-slate-100 rounded-xl transition-all text-slate-400 hover:text-slate-600" on:click={closeModal}>✕</button>
			</div>

			<!-- Modal Body -->
			<div class="px-8 py-6 flex flex-col gap-5">
				<!-- Barcode -->
				<div>
					<span class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('mobile.productRequestContent.barcode')}</span>
					<input
						type="text"
						bind:value={modalBarcode}
						placeholder={$t('mobile.productRequestContent.barcodePlaceholder')}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all font-mono"
					/>
				</div>

				<!-- Product Name -->
				<div>
					<span class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('mobile.productRequestContent.productName')}</span>
					<input
						type="text"
						bind:value={modalProductName}
						placeholder={$t('mobile.productRequestContent.productNamePlaceholder')}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
					/>
				</div>

				<!-- Quantity -->
				<div>
					<span class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('mobile.productRequestContent.quantity')}</span>
					<input
						type="number"
						bind:value={modalQuantity}
						min="1"
						placeholder="1"
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition-all"
					/>
				</div>

				<!-- Photo -->
				<div>
					<span class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide">{$t('mobile.productRequestContent.photo')}</span>
					{#if modalPhoto}
						<div class="relative inline-block">
							<img src={modalPhoto} alt="Preview" class="w-24 h-24 object-cover rounded-xl border border-slate-200" />
							<button
								class="absolute -top-2 -right-2 w-6 h-6 bg-red-500 text-white rounded-full text-xs font-bold flex items-center justify-center hover:bg-red-600 transition-all shadow-md"
								on:click={removePhoto}
							>✕</button>
						</div>
					{:else}
						<div class="flex items-center gap-3">
							<button
								class="flex items-center gap-2 px-4 py-2.5 bg-orange-50 border border-orange-200 rounded-xl text-sm text-orange-700 font-semibold cursor-pointer hover:bg-orange-100 transition-all"
								on:click={() => fileInput?.click()}
							>
								<span>📷</span>
								<span>{$t('mobile.productRequestContent.choosePhoto')}</span>
							</button>
							<input bind:this={fileInput} type="file" accept="image/*" class="hidden" on:change={handlePhoto} />
						</div>
					{/if}
				</div>
			</div>

			<!-- Modal Footer -->
			<div class="px-8 py-5 border-t border-slate-100 flex items-center justify-end gap-3">
				<button
					class="px-6 py-2.5 bg-slate-100 text-slate-600 font-bold rounded-xl hover:bg-slate-200 transition-all text-sm"
					on:click={closeModal}
				>
					{$t('mobile.productRequestContent.close')}
				</button>
				<button
					class="px-8 py-2.5 bg-orange-600 text-white font-bold rounded-xl hover:bg-orange-700 transition-all shadow-lg shadow-orange-200 text-sm flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
					on:click={addItem}
					disabled={!modalProductName.trim() && !modalBarcode.trim()}
				>
					<span>➕</span>
					{$t('mobile.productRequestContent.add')}
				</button>
			</div>
		</div>
	</div>
{/if}
