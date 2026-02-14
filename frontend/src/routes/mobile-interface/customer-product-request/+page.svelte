<script lang="ts">
	import { getTranslation } from '$lib/i18n';
	import { currentLocale } from '$lib/i18n';
	import { onDestroy } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { currentUser } from '$lib/utils/persistentAuth';

	interface ProductItem {
		product_name: string;
		image_url: string | null;
		photo: string | null;
	}

	let items: ProductItem[] = [];
	let showModal = false;
	let modalProductName = '';
	let modalImageUrl: string | null = null;
	let modalPhoto: string | null = null;
	let fileInput: HTMLInputElement;
	let cameraInput: HTMLInputElement;

	// Purchasing Manager selection
	let purchasingManagers: { user_id: string; name: string; branch_name: string }[] = [];
	let selectedManagerId: string | null = null;
	let selectedManagerName: string = '';
	let loadingManagers = true;

	// Google Image Search
	let searchQuery = '';
	let searchResults: { url: string; thumbnail: string; title: string }[] = [];
	let searching = false;
	let searchError = '';

	// Send state
	let sending = false;
	let sendSuccess = false;
	let sendError = '';

	let showCustomerSearchPopup = false;

	// Photo state
	let showCamera = false;
	let videoEl: HTMLVideoElement;
	let stream: MediaStream | null = null;

	const t = getTranslation;

	// Load purchasing managers from all branches on mount
	loadPurchasingManagers();

	async function loadPurchasingManagers() {
		loadingManagers = true;
		try {
			const { data, error } = await supabase
				.from('branch_default_positions')
				.select('branch_id, purchasing_manager_user_id');
			
			if (error) throw error;
			if (!data || data.length === 0) {
				loadingManagers = false;
				return;
			}

			// Get unique manager user IDs
			const managerIds = [...new Set(data.filter(d => d.purchasing_manager_user_id).map(d => d.purchasing_manager_user_id))];
			const branchIds = [...new Set(data.map(d => d.branch_id))];

			if (managerIds.length === 0) {
				loadingManagers = false;
				return;
			}

			// Fetch employee names
			const { data: employees } = await supabase
				.from('hr_employee_master')
				.select('user_id, name_en, name_ar')
				.in('user_id', managerIds);

			// Fetch branch names
			const { data: branches } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.in('id', branchIds);

			const empMap: Record<string, { name_en: string; name_ar: string }> = {};
			for (const e of employees || []) {
				empMap[e.user_id] = { name_en: e.name_en || '', name_ar: e.name_ar || '' };
			}

			const branchMap: Record<number, { name_en: string; name_ar: string }> = {};
			for (const b of branches || []) {
				branchMap[b.id] = { name_en: b.name_en || '', name_ar: b.name_ar || '' };
			}

			purchasingManagers = data
				.filter(d => d.purchasing_manager_user_id)
				.map(d => {
					const emp = empMap[d.purchasing_manager_user_id] || { name_en: '', name_ar: '' };
					const branch = branchMap[d.branch_id] || { name_en: '', name_ar: '' };
					return {
						user_id: d.purchasing_manager_user_id,
						name: $currentLocale === 'ar' 
							? (emp.name_ar || emp.name_en || d.purchasing_manager_user_id)
							: (emp.name_en || emp.name_ar || d.purchasing_manager_user_id),
						branch_name: $currentLocale === 'ar'
							? (branch.name_ar || branch.name_en || '')
							: (branch.name_en || branch.name_ar || '')
					};
				});

			// De-duplicate by user_id (same manager could be in multiple branches)
			const seen = new Set<string>();
			const unique: typeof purchasingManagers = [];
			for (const m of purchasingManagers) {
				if (!seen.has(m.user_id)) {
					seen.add(m.user_id);
					unique.push(m);
				}
			}
			purchasingManagers = unique;

			// Auto-select if only one
			if (purchasingManagers.length === 1) {
				selectedManagerId = purchasingManagers[0].user_id;
				selectedManagerName = purchasingManagers[0].name;
			}
		} catch (err) {
			console.error('Error loading purchasing managers:', err);
		} finally {
			loadingManagers = false;
		}
	}

	function openModal() {
		modalProductName = '';
		modalImageUrl = null;
		modalPhoto = null;
		showModal = true;
	}

	function closeModal() {
		showModal = false;
		modalProductName = '';
		modalImageUrl = null;
		modalPhoto = null;
	}

	function addItem() {
		if (!modalProductName.trim()) return;
		items = [...items, {
			product_name: modalProductName.trim(),
			image_url: modalImageUrl,
			photo: modalPhoto
		}];
		closeModal();
	}

	function removeItem(index: number) {
		items = items.filter((_, i) => i !== index);
	}

	// Camera
	async function openCamera() {
		showCamera = true;
		try {
			stream = await navigator.mediaDevices.getUserMedia({ 
				video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } } 
			});
			await new Promise(r => setTimeout(r, 100));
			if (videoEl) {
				videoEl.srcObject = stream;
				await videoEl.play();
			}
		} catch (err) {
			console.error('Camera error:', err);
			showCamera = false;
		}
	}

	function capturePhoto() {
		if (!videoEl) return;
		const canvas = document.createElement('canvas');
		canvas.width = videoEl.videoWidth;
		canvas.height = videoEl.videoHeight;
		const ctx = canvas.getContext('2d');
		if (ctx) {
			ctx.drawImage(videoEl, 0, 0);
			modalPhoto = canvas.toDataURL('image/jpeg', 0.8);
		}
		closeCamera();
	}

	function closeCamera() {
		if (stream) {
			stream.getTracks().forEach(t => t.stop());
			stream = null;
		}
		showCamera = false;
	}

	function handleFileSelect(e: Event) {
		const input = e.target as HTMLInputElement;
		if (input.files && input.files[0]) {
			const reader = new FileReader();
			reader.onload = (ev) => {
				modalPhoto = ev.target?.result as string;
			};
			reader.readAsDataURL(input.files[0]);
		}
	}

	// Google Image Search
	function openSearchPopup() {
		if (!modalProductName.trim()) return;
		searchQuery = modalProductName.trim();
		searchResults = [];
		searchError = '';
		searchImages();
	}

	async function searchImages() {
		if (!searchQuery.trim()) return;
		searching = true;
		searchError = '';
		searchResults = [];
		try {
			const resp = await fetch('/api/google-search', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ query: searchQuery.trim() })
			});
			const data = await resp.json();
			if (!resp.ok) throw new Error(data.error || 'Search failed');
			if (data.images && data.images.length > 0) {
				searchResults = data.images;
			} else {
				searchError = $currentLocale === 'ar' ? 'لا توجد نتائج' : 'No results found';
			}
		} catch (err: any) {
			console.error('Search error:', err);
			searchError = err.message || 'Search failed';
		} finally {
			searching = false;
		}
	}

	function selectSearchImage(url: string) {
		modalImageUrl = url;
		searchResults = [];
	}

	// Upload photo to storage
	async function uploadPhoto(photo: string, index: number): Promise<string | null> {
		try {
			const res = await fetch(photo);
			const blob = await res.blob();
			const ext = blob.type.split('/')[1] || 'jpg';
			const fileName = `customer-request/${$currentUser?.id}/${Date.now()}_${index}.${ext}`;
			const { error } = await supabase.storage
				.from('product-request-photos')
				.upload(fileName, blob, { contentType: blob.type, upsert: true });
			if (error) throw error;
			const { data: urlData } = supabase.storage
				.from('product-request-photos')
				.getPublicUrl(fileName);
			return urlData?.publicUrl || null;
		} catch (err) {
			console.error('Upload error:', err);
			return null;
		}
	}

	// Send request
	async function sendRequest() {
		if (items.length === 0 || !selectedManagerId) return;
		sending = true;
		sendError = '';
		sendSuccess = false;
		try {
			// Upload photos
			const itemsData = await Promise.all(items.map(async (item, i) => {
				let photoUrl: string | null = item.image_url;
				if (item.photo) {
					const uploaded = await uploadPhoto(item.photo, i);
					if (uploaded) photoUrl = uploaded;
				}
				return {
					product_name: item.product_name,
					image_url: photoUrl
				};
			}));

			const branchId = $currentUser?.branch_id ? Number($currentUser.branch_id) : null;

			const { data: reqData, error } = await supabase
				.from('customer_product_requests')
				.insert({
					requester_user_id: $currentUser?.id,
					branch_id: branchId,
					target_user_id: selectedManagerId,
					status: 'pending',
					items: itemsData
				})
				.select('id')
				.single();

			if (error) throw error;

			// Create quick tasks
			if (reqData?.id) {
				try {
					const requesterName = $currentUser?.username || 'User';
					const { data: receiverTask } = await supabase
						.from('quick_tasks')
						.insert({
							title: `Customer Product Request | طلب منتج عميل`,
							description: `Customer product request from ${requesterName}. Review and process.\n---\nطلب منتج عميل من ${requesterName}. راجع وعالج.`,
							priority: 'high',
							issue_type: 'product_request_process',
							assigned_by: $currentUser?.id,
							assigned_to_branch_id: branchId,
							product_request_id: reqData.id,
							product_request_type: 'CUSTOMER'
						})
						.select('id')
						.single();

					if (receiverTask) {
						await supabase.from('quick_task_assignments').insert({
							quick_task_id: receiverTask.id,
							assigned_to_user_id: selectedManagerId,
							require_task_finished: true
						});
					}

					// Notification
					await supabase.from('notifications').insert({
						title: `New Customer Product Request | طلب منتج عميل جديد`,
						message: `${requesterName} submitted a customer product request with ${itemsData.length} item(s).\n---\n${requesterName} أرسل طلب منتج عميل يحتوي على ${itemsData.length} منتج(ات).`,
						type: 'info',
						priority: 'normal',
						target_type: 'specific_users',
						target_users: [selectedManagerId],
						status: 'published',
						total_recipients: 1,
						created_at: new Date().toISOString()
					});
				} catch (taskErr) {
					console.warn('Failed to create quick tasks:', taskErr);
				}
			}

			sendSuccess = true;
			setTimeout(() => {
				items = [];
				sendSuccess = false;
			}, 1500);
		} catch (err: any) {
			console.error('Error sending:', err);
			sendError = err?.message || 'Failed to send';
		} finally {
			sending = false;
		}
	}

	onDestroy(() => {
		if (stream) {
			stream.getTracks().forEach(t => t.stop());
		}
	});

	$: canAdd = modalProductName.trim().length > 0 || !!modalPhoto || !!modalImageUrl;
	$: canSend = items.length > 0 && selectedManagerId;
</script>

<div class="page-container" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Purchasing Manager Selection -->
	<div class="manager-section">
		<label class="section-label">
			{$currentLocale === 'ar' ? '📌 مدير المشتريات' : '📌 Purchasing Manager'}
		</label>
		{#if loadingManagers}
			<div class="loading-bar">{$currentLocale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</div>
		{:else if purchasingManagers.length === 0}
			<div class="warning-bar">⚠️ {$currentLocale === 'ar' ? 'لا يوجد مدير مشتريات' : 'No purchasing manager found'}</div>
		{:else if purchasingManagers.length === 1}
			<div class="manager-auto">
				<span class="manager-name">✅ {purchasingManagers[0].name}</span>
				{#if purchasingManagers[0].branch_name}
					<span class="manager-branch">({purchasingManagers[0].branch_name})</span>
				{/if}
			</div>
		{:else}
			<select class="manager-select" bind:value={selectedManagerId} on:change={() => {
				const m = purchasingManagers.find(p => p.user_id === selectedManagerId);
				selectedManagerName = m?.name || '';
			}}>
				<option value={null}>{$currentLocale === 'ar' ? '-- اختر المدير --' : '-- Select Manager --'}</option>
				{#each purchasingManagers as mgr}
					<option value={mgr.user_id}>{mgr.name} {mgr.branch_name ? `(${mgr.branch_name})` : ''}</option>
				{/each}
			</select>
		{/if}
	</div>

	<!-- Top Add Button -->
	<div class="top-actions">
		<button type="button" class="add-btn" on:click={openModal}>
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
				<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
			</svg>
			<span>{$currentLocale === 'ar' ? 'إضافة منتجات' : 'Add Products'}</span>
		</button>
	</div>

	<!-- Fixed bottom Send button -->
	{#if items.length > 0}
		<div class="fixed-bottom-bar">
			<button type="button" class="save-btn" on:click={sendRequest} disabled={!canSend || sending}>
				{#if sending}
					<span class="spinner"></span>
				{:else if sendSuccess}
					<span>✅</span>
					<span>{$currentLocale === 'ar' ? 'تم الإرسال' : 'Sent!'}</span>
				{:else}
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2Z"/>
					</svg>
					<span>{$currentLocale === 'ar' ? 'إرسال' : 'Send'} ({items.length})</span>
				{/if}
			</button>
		</div>
	{/if}
	{#if sendError}
		<div class="error-msg">❌ {sendError}</div>
	{/if}

	<!-- Items table -->
	{#if items.length > 0}
		<div class="table-wrapper">
			<table class="items-table">
				<thead>
					<tr>
						<th>{$currentLocale === 'ar' ? 'صورة' : 'Img'}</th>
						<th>{$currentLocale === 'ar' ? 'المنتج' : 'Product'}</th>
						<th></th>
					</tr>
				</thead>
			</table>
			<div class="table-scroll">
				<table class="items-table">
					<tbody>
						{#each items as item, i}
							<tr>
								<td>
									{#if item.photo}
										<img src={item.photo} alt="Product" class="table-photo" />
									{:else if item.image_url}
										<img src={item.image_url} alt="Product" class="table-photo" />
									{:else}
										<span style="color:#d1d5db">📷</span>
									{/if}
								</td>
								<td>{item.product_name || '—'}</td>
								<td>
									<button type="button" class="remove-btn" on:click={() => removeItem(i)}>&times;</button>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	{/if}
</div>

<!-- Add Product Modal -->
{#if showModal}
	<div class="modal-overlay" on:click|self={closeModal}>
		<div class="modal-content">
			<div class="modal-header">
				<h3>🛍️ {$currentLocale === 'ar' ? 'إضافة منتج' : 'Add Product'}</h3>
				<button class="modal-close" on:click={closeModal}>✕</button>
			</div>

			<!-- Product Name -->
			<div class="form-group">
				<label>{$currentLocale === 'ar' ? 'اسم المنتج' : 'Product Name'}</label>
				<input type="text" bind:value={modalProductName} placeholder={$currentLocale === 'ar' ? 'أدخل اسم المنتج...' : 'Enter product name...'} class="form-input" />
			</div>

			<!-- Image Preview -->
			{#if modalPhoto || modalImageUrl}
				<div class="image-preview">
					<img src={modalPhoto || modalImageUrl} alt="Product" />
					<button class="preview-remove" on:click={() => { modalPhoto = null; modalImageUrl = null; }}>✕</button>
				</div>
			{/if}

			<!-- Image Buttons -->
			<div class="image-buttons">
				<button class="img-btn camera" on:click={openCamera}>
					<span>📸</span>
					{$currentLocale === 'ar' ? 'كاميرا' : 'Camera'}
				</button>
				<button class="img-btn file" on:click={() => fileInput?.click()}>
					<span>📁</span>
					{$currentLocale === 'ar' ? 'اختر ملف' : 'Choose File'}
				</button>
				<button class="img-btn search" on:click={openSearchPopup} disabled={!modalProductName.trim() || searching}>
					<span>{searching ? '⏳' : '🔍'}</span>
					{$currentLocale === 'ar' ? 'بحث صور' : 'Search'}
				</button>
			</div>
			<input bind:this={fileInput} type="file" accept="image/*" on:change={handleFileSelect} style="display:none" />

			<!-- Search Results (inline) -->
			{#if searchError}
				<div class="search-error">{searchError}</div>
			{/if}
			{#if searchResults.length > 0}
				<div class="search-results">
					{#each searchResults as result}
						<button class="search-result-item" on:click={() => selectSearchImage(result.url)}>
							<img src={result.thumbnail} alt={result.title} loading="lazy" />
						</button>
					{/each}
				</div>
			{/if}

			<!-- Add Button -->
			<button class="btn-add-item" on:click={addItem} disabled={!canAdd}>
				{$currentLocale === 'ar' ? 'إضافة' : 'Add'}
			</button>
		</div>
	</div>
{/if}

<!-- Camera Overlay -->
{#if showCamera}
	<div class="camera-overlay">
		<video bind:this={videoEl} autoplay playsinline muted class="camera-video"></video>
		<div class="camera-controls">
			<button class="camera-cancel" on:click={closeCamera}>✕</button>
			<button class="camera-capture" on:click={capturePhoto}>📸</button>
		</div>
	</div>
{/if}

<!-- Google Image Search - removed separate popup, integrated into modal -->

<style>
	.page-container {
		padding: 0;
		padding-bottom: 4.5rem;
		min-height: 100%;
		background: #F8FAFC;
		display: flex;
		flex-direction: column;
		height: 100vh;
		overflow: hidden;
	}

	/* Manager Section */
	.manager-section {
		background: white;
		border-radius: 0;
		padding: 10px 14px;
		border-bottom: 1px solid #e5e7eb;
	}

	.section-label {
		display: block;
		font-size: 13px;
		font-weight: 700;
		color: #6b21a8;
		margin-bottom: 8px;
	}

	.loading-bar {
		padding: 10px;
		text-align: center;
		color: #9ca3af;
		font-size: 13px;
	}

	.warning-bar {
		padding: 10px;
		text-align: center;
		color: #d97706;
		font-size: 13px;
		background: #fef3c7;
		border-radius: 10px;
	}

	.manager-auto {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 14px;
		background: #f0fdf4;
		border-radius: 10px;
		border: 1px solid #bbf7d0;
	}

	.manager-name {
		font-weight: 700;
		color: #166534;
		font-size: 14px;
	}

	.manager-branch {
		font-size: 12px;
		color: #6b7280;
	}

	.manager-select {
		width: 100%;
		padding: 10px 14px;
		border: 2px solid #e5e7eb;
		border-radius: 10px;
		font-size: 14px;
		font-weight: 600;
		background: white;
		color: #1f2937;
		appearance: auto;
	}

	/* Top actions */
	.top-actions {
		display: flex;
		gap: 0.4rem;
		padding: 0.4rem 0.5rem;
		background: white;
		border-bottom: 1px solid #E5E7EB;
	}

	.add-btn {
		flex: 1;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.35rem;
		padding: 0.5rem 0.6rem;
		background: #a855f7;
		color: white;
		border: none;
		border-radius: 6px;
		font-size: 0.8rem;
		font-weight: 700;
		cursor: pointer;
	}

	/* Fixed bottom bar for Send */
	.fixed-bottom-bar {
		position: fixed;
		bottom: 3.6rem;
		left: 0;
		right: 0;
		display: flex;
		justify-content: center;
		padding: 0.5rem 1rem;
		background: transparent;
		z-index: 999;
	}

	.save-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.4rem;
		padding: 0.65rem 1.4rem;
		background: linear-gradient(135deg, #ec4899, #db2777);
		color: white;
		border: none;
		border-radius: 8px;
		font-size: 0.9rem;
		font-weight: 800;
		cursor: pointer;
		box-shadow: 0 3px 10px rgba(236, 72, 153, 0.3);
	}

	.save-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.error-msg {
		position: fixed;
		bottom: 7.5rem;
		left: 16px;
		right: 16px;
		padding: 10px;
		background: #fee2e2;
		color: #dc2626;
		border-radius: 10px;
		text-align: center;
		font-size: 13px;
		font-weight: 600;
		z-index: 999;
	}

	/* Items table */
	.table-wrapper {
		background: white;
		border-radius: 8px;
		overflow: hidden;
		margin: 0 0.5rem 0.5rem;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.05);
		display: flex;
		flex-direction: column;
	}

	.table-scroll {
		overflow-y: auto;
		flex: 1;
		max-height: calc(100vh - 16rem);
		-webkit-overflow-scrolling: touch;
	}

	.items-table {
		width: 100%;
		border-collapse: collapse;
		table-layout: fixed;
	}

	.items-table thead th {
		background: #F3F4F6;
		padding: 0.4rem 0.3rem;
		font-size: 0.7rem;
		font-weight: 700;
		color: #6B7280;
		text-transform: uppercase;
		text-align: center;
		position: sticky;
		top: 0;
		z-index: 2;
		border-bottom: 1px solid #E5E7EB;
	}

	.items-table thead th:nth-child(1) { width: 50px; }
	.items-table thead th:nth-child(3) { width: 36px; }

	.items-table td {
		padding: 0.35rem 0.3rem;
		font-size: 0.75rem;
		color: #374151;
		text-align: center;
		border-bottom: 1px solid #F3F4F6;
		word-break: break-word;
	}

	.table-photo {
		width: 36px;
		height: 36px;
		object-fit: cover;
		border-radius: 4px;
		border: 1px solid #E5E7EB;
	}

	.remove-btn {
		background: none;
		border: none;
		color: #EF4444;
		font-size: 1.2rem;
		font-weight: 700;
		cursor: pointer;
		padding: 0;
		line-height: 1;
	}

	.spinner {
		width: 18px;
		height: 18px;
		border: 3px solid rgba(255,255,255,0.3);
		border-top: 3px solid white;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		display: inline-block;
	}

	@keyframes spin { to { transform: rotate(360deg); } }

	/* Modal */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0,0,0,0.5);
		backdrop-filter: blur(4px);
		z-index: 1100;
		display: flex;
		align-items: flex-end;
		justify-content: center;
		padding-bottom: 4rem;
	}

	.modal-content {
		background: white;
		border-radius: 24px;
		padding: 24px;
		width: 100%;
		max-height: 80vh;
		overflow-y: auto;
		animation: slideUp 0.3s ease;
	}

	@keyframes slideUp {
		from { transform: translateY(100%); }
		to { transform: translateY(0); }
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
	}

	.modal-header h3 {
		font-size: 18px;
		font-weight: 800;
		color: #1f2937;
		margin: 0;
	}

	.modal-close {
		width: 32px;
		height: 32px;
		border: none;
		background: #f3f4f6;
		border-radius: 50%;
		font-size: 16px;
		cursor: pointer;
		color: #6b7280;
	}

	.form-group {
		margin-bottom: 16px;
	}

	.form-group label {
		display: block;
		font-size: 13px;
		font-weight: 700;
		color: #6b7280;
		margin-bottom: 6px;
	}

	.form-input {
		width: 100%;
		padding: 12px 14px;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		font-size: 15px;
		font-weight: 600;
		color: #1f2937;
		background: #f9fafb;
		outline: none;
		transition: border-color 0.2s;
	}

	.form-input:focus {
		border-color: #a855f7;
		background: white;
	}

	/* Image Preview */
	.image-preview {
		position: relative;
		margin-bottom: 16px;
		border-radius: 14px;
		overflow: hidden;
		border: 2px solid #e5e7eb;
	}

	.image-preview img {
		width: 100%;
		max-height: 200px;
		object-fit: cover;
	}

	.preview-remove {
		position: absolute;
		top: 8px;
		right: 8px;
		width: 28px;
		height: 28px;
		border: none;
		background: rgba(220, 38, 38, 0.9);
		color: white;
		border-radius: 50%;
		font-size: 14px;
		cursor: pointer;
	}

	/* Image Buttons */
	.image-buttons {
		display: flex;
		gap: 8px;
		margin-bottom: 16px;
	}

	.img-btn {
		flex: 1;
		padding: 12px 8px;
		border: 2px solid #e5e7eb;
		border-radius: 12px;
		background: white;
		font-size: 12px;
		font-weight: 700;
		cursor: pointer;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
		transition: all 0.2s;
	}

	.img-btn span:first-child {
		font-size: 20px;
	}

	.img-btn.camera {
		color: #7c3aed;
		border-color: #ddd6fe;
	}

	.img-btn.camera:hover {
		background: #f5f3ff;
	}

	.img-btn.file {
		color: #2563eb;
		border-color: #bfdbfe;
	}

	.img-btn.file:hover {
		background: #eff6ff;
	}

	.img-btn.search {
		color: #059669;
		border-color: #a7f3d0;
	}

	.img-btn.search:hover {
		background: #ecfdf5;
	}

	.btn-add-item {
		width: 100%;
		padding: 14px;
		border: none;
		background: linear-gradient(135deg, #a855f7, #7c3aed);
		color: white;
		font-size: 16px;
		font-weight: 800;
		border-radius: 14px;
		cursor: pointer;
	}

	.btn-add-item:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	/* Camera Overlay */
	.camera-overlay {
		position: fixed;
		inset: 0;
		background: black;
		z-index: 2000;
		display: flex;
		flex-direction: column;
	}

	.camera-video {
		flex: 1;
		object-fit: cover;
	}

	.camera-controls {
		position: absolute;
		bottom: 30px;
		left: 0;
		right: 0;
		display: flex;
		justify-content: center;
		align-items: center;
		gap: 40px;
	}

	.camera-cancel {
		width: 48px;
		height: 48px;
		border: none;
		background: rgba(255,255,255,0.2);
		color: white;
		border-radius: 50%;
		font-size: 20px;
		cursor: pointer;
	}

	.camera-capture {
		width: 64px;
		height: 64px;
		border: 4px solid white;
		background: rgba(255,255,255,0.3);
		border-radius: 50%;
		font-size: 24px;
		cursor: pointer;
	}

	/* Search Popup */
	.search-popup {
		background: white;
		border-radius: 24px;
		padding: 20px;
		width: 100%;
		max-height: 80vh;
		overflow-y: auto;
		animation: slideUp 0.3s ease;
	}

	.search-bar {
		display: flex;
		gap: 8px;
		margin-bottom: 16px;
	}

	.search-bar .form-input {
		flex: 1;
	}

	.btn-search {
		padding: 12px 18px;
		border: none;
		background: #059669;
		color: white;
		border-radius: 12px;
		font-size: 16px;
		font-weight: 700;
		cursor: pointer;
	}

	.btn-search:disabled {
		opacity: 0.5;
	}

	.search-error {
		text-align: center;
		color: #dc2626;
		font-size: 13px;
		padding: 8px;
	}

	.search-results {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 8px;
	}

	.search-result-item {
		border: 2px solid #e5e7eb;
		border-radius: 10px;
		overflow: hidden;
		padding: 0;
		background: white;
		cursor: pointer;
		aspect-ratio: 1;
		transition: border-color 0.2s;
	}

	.search-result-item:hover {
		border-color: #a855f7;
	}

	.search-result-item img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
</style>
