<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { onMount } from 'svelte';
	import { icons, loading, loadIcons, type AppIcon } from '$lib/stores/iconStore';

	let supabase: any = null;
	let supabaseUrl = '';
	let allIcons: AppIcon[] = [];
	let filteredIcons: AppIcon[] = [];
	let searchQuery = '';
	let selectedCategory = 'all';
	let categories: string[] = [];
	let copiedKey = '';
	
	// Upload state
	let showUploadModal = false;
	let uploadName = '';
	let uploadKey = '';
	let uploadCategory = 'general';
	let uploadDescription = '';
	let uploadFile: File | null = null;
	let uploading = false;
	let uploadError = '';
	let uploadSuccess = '';
	
	// Edit state
	let editingIcon: AppIcon | null = null;
	let editName = '';
	let editCategory = '';
	let editDescription = '';
	let editFile: File | null = null;
	
	// Delete state
	let deletingIcon: AppIcon | null = null;
	let deleting = false;

	// Preview state
	let previewIcon: AppIcon | null = null;

	const CATEGORY_OPTIONS = ['logo', 'currency', 'social', 'pwa', 'misc', 'general'];
	const CATEGORY_EMOJIS: Record<string, string> = {
		logo: '🏷️',
		currency: '💰',
		social: '📱',
		pwa: '📲',
		misc: '🔧',
		general: '📦'
	};

	$: allIcons = $icons;
	$: {
		let list = allIcons;
		if (selectedCategory !== 'all') {
			list = list.filter(i => i.category === selectedCategory);
		}
		if (searchQuery.trim()) {
			const q = searchQuery.toLowerCase();
			list = list.filter(i => 
				i.name.toLowerCase().includes(q) || 
				i.icon_key.toLowerCase().includes(q) ||
				(i.description || '').toLowerCase().includes(q)
			);
		}
		filteredIcons = list;
	}
	$: {
		const cats = new Set(allIcons.map(i => i.category));
		categories = Array.from(cats).sort();
	}

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		supabaseUrl = mod.supabaseUrl || import.meta.env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
		await loadIcons(true);
	});

	let cacheBuster = Date.now();

	function buildUrl(storagePath: string): string {
		const base = supabaseUrl || 'https://supabase.urbanaqura.com';
		return `${base}/storage/v1/object/public/app-icons/${encodeURIComponent(storagePath)}?t=${cacheBuster}`;
	}

	function formatFileSize(bytes: number): string {
		if (!bytes) return 'N/A';
		if (bytes < 1024) return bytes + ' B';
		if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
		return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
	}

	function generateKey(name: string): string {
		return name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
	}

	function handleNameInput() {
		if (!editingIcon) {
			uploadKey = generateKey(uploadName);
		}
	}

	function handleFileSelect(e: Event) {
		const input = e.target as HTMLInputElement;
		if (input.files && input.files[0]) {
			uploadFile = input.files[0];
		}
	}

	function handleEditFileSelect(e: Event) {
		const input = e.target as HTMLInputElement;
		if (input.files && input.files[0]) {
			editFile = input.files[0];
		}
	}

	async function uploadIcon() {
		if (!uploadFile || !uploadName || !uploadKey) {
			uploadError = 'Please fill in all required fields and select a file';
			return;
		}

		uploading = true;
		uploadError = '';
		uploadSuccess = '';

		try {
			const ext = uploadFile.name.split('.').pop() || 'png';
			const storagePath = `${uploadKey}.${ext}`;

			const { error: storageErr } = await supabase.storage
				.from('app-icons')
				.upload(storagePath, uploadFile, { 
					upsert: true,
					contentType: uploadFile.type 
				});

			if (storageErr) throw storageErr;

			const { error: rpcErr } = await supabase.rpc('upsert_app_icon', {
				p_icon_key: uploadKey,
				p_name: uploadName,
				p_category: uploadCategory,
				p_storage_path: storagePath,
				p_mime_type: uploadFile.type,
				p_file_size: uploadFile.size,
				p_description: uploadDescription || null
			});

			if (rpcErr) throw rpcErr;

			uploadSuccess = `Icon "${uploadName}" uploaded successfully!`;
			showUploadModal = false;
			cacheBuster = Date.now();
			resetUploadForm();
			await loadIcons(true);
			
			setTimeout(() => { uploadSuccess = ''; }, 4000);
		} catch (e: any) {
			uploadError = e.message || 'Upload failed';
		} finally {
			uploading = false;
		}
	}

	function resetUploadForm() {
		uploadName = '';
		uploadKey = '';
		uploadCategory = 'general';
		uploadDescription = '';
		uploadFile = null;
		const input = document.getElementById('icon-file-input') as HTMLInputElement;
		if (input) input.value = '';
	}

	function startEdit(icon: AppIcon) {
		editingIcon = icon;
		editName = icon.name;
		editCategory = icon.category;
		editDescription = icon.description || '';
		editFile = null;
		showUploadModal = false;
	}

	async function saveEdit() {
		if (!editingIcon || !supabase) return;
		uploading = true;
		uploadError = '';

		try {
			let storagePath = editingIcon.storage_path;

			if (editFile) {
				const ext = editFile.name.split('.').pop() || 'png';
				storagePath = `${editingIcon.icon_key}.${ext}`;

				if (storagePath !== editingIcon.storage_path) {
					await supabase.storage.from('app-icons').remove([editingIcon.storage_path]);
				}

				const { error: storageErr } = await supabase.storage
					.from('app-icons')
					.upload(storagePath, editFile, { 
						upsert: true,
						contentType: editFile.type 
					});

				if (storageErr) throw storageErr;
			}

			const { error: rpcErr } = await supabase.rpc('upsert_app_icon', {
				p_icon_key: editingIcon.icon_key,
				p_name: editName,
				p_category: editCategory,
				p_storage_path: storagePath,
				p_mime_type: editFile ? editFile.type : editingIcon.mime_type,
				p_file_size: editFile ? editFile.size : editingIcon.file_size,
				p_description: editDescription || null
			});

			if (rpcErr) throw rpcErr;

			editingIcon = null;
			cacheBuster = Date.now();
			uploadSuccess = 'Icon updated successfully!';
			await loadIcons(true);
			setTimeout(() => { uploadSuccess = ''; }, 4000);
		} catch (e: any) {
			uploadError = e.message || 'Update failed';
		} finally {
			uploading = false;
		}
	}

	function confirmDelete(icon: AppIcon) {
		deletingIcon = icon;
	}

	async function deleteIcon() {
		if (!deletingIcon || !supabase) return;
		deleting = true;

		try {
			await supabase.storage.from('app-icons').remove([deletingIcon.storage_path]);

			const { error: rpcErr } = await supabase.rpc('delete_app_icon', {
				p_icon_key: deletingIcon.icon_key
			});

			if (rpcErr) throw rpcErr;

			deletingIcon = null;
			cacheBuster = Date.now();
			uploadSuccess = 'Icon deleted successfully!';
			await loadIcons(true);
			setTimeout(() => { uploadSuccess = ''; }, 4000);
		} catch (e: any) {
			uploadError = e.message || 'Delete failed';
		} finally {
			deleting = false;
		}
	}

	function copyUrl(icon: AppIcon) {
		const url = buildUrl(icon.storage_path);
		navigator.clipboard.writeText(url);
		copiedKey = 'url-' + icon.icon_key;
		setTimeout(() => { copiedKey = ''; }, 2000);
	}

	function copyKey(icon: AppIcon) {
		navigator.clipboard.writeText(icon.icon_key);
		copiedKey = 'key-' + icon.icon_key;
		setTimeout(() => { copiedKey = ''; }, 2000);
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-2xl">🎨</span>
			<h2 class="text-lg font-black text-slate-800 m-0">{$t('iconManager.title') || 'Icon Manager'}</h2>
			<span class="inline-block px-3 py-0.5 rounded-full text-xs font-black bg-blue-100 text-blue-700">{allIcons.length} {$t('iconManager.icons') || 'icons'}</span>
		</div>
		<div class="flex gap-2">
			<button 
				class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-bold bg-slate-100 text-slate-600 border border-slate-200 hover:bg-slate-200 hover:shadow transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
				on:click={() => loadIcons(true)} 
				disabled={$loading}
			>
				<span class="text-base" class:animate-spin={$loading}>🔄</span>
				{$t('common.refresh') || 'Refresh'}
			</button>
			<button 
				class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl text-xs font-black bg-blue-600 text-white shadow-lg shadow-blue-200 hover:bg-blue-700 hover:shadow-xl transition-all duration-200 transform hover:scale-105"
				on:click={() => { showUploadModal = true; editingIcon = null; }}
			>
				➕ {$t('iconManager.uploadNew') || 'Upload New Icon'}
			</button>
		</div>
	</div>

	<!-- Alerts -->
	{#if uploadSuccess}
		<div class="mx-6 mt-3 px-4 py-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-700 text-sm font-semibold flex items-center justify-between">
			<span>✅ {uploadSuccess}</span>
			<button class="text-emerald-500 hover:text-emerald-700 bg-transparent border-none cursor-pointer text-lg px-1" on:click={() => uploadSuccess = ''}>✕</button>
		</div>
	{/if}
	{#if uploadError}
		<div class="mx-6 mt-3 px-4 py-3 rounded-xl bg-red-50 border border-red-200 text-red-700 text-sm font-semibold flex items-center justify-between">
			<span>❌ {uploadError}</span>
			<button class="text-red-400 hover:text-red-700 bg-transparent border-none cursor-pointer text-lg px-1" on:click={() => uploadError = ''}>✕</button>
		</div>
	{/if}

	<!-- Main Content Area -->
	<div class="flex-1 p-6 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative background blurs -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-indigo-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if $loading && allIcons.length === 0}
				<!-- Loading State -->
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">{$t('common.loading') || 'Loading...'}</p>
					</div>
				</div>
			{:else if filteredIcons.length === 0 && allIcons.length === 0}
				<!-- Empty State -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-5xl mb-4">📭</div>
					<p class="text-slate-600 font-semibold">{$t('iconManager.noIcons') || 'No icons found'}</p>
				</div>
			{:else}
				<!-- Filters -->
				<div class="mb-4 flex gap-3">
					<!-- Search -->
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="icon-search">{$t('iconManager.searchPlaceholder') || 'Search'}</label>
						<input 
							id="icon-search"
							type="text" 
							placeholder={$t('iconManager.searchPlaceholder') || 'Search by name, key, or description...'}
							bind:value={searchQuery}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
						/>
					</div>
					<!-- Category Filter -->
					<div class="flex-1">
						<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="icon-category-filter">{$t('iconManager.category') || 'Category'}</label>
						<select 
							id="icon-category-filter"
							bind:value={selectedCategory}
							class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
							style="color: #000000 !important; background-color: #ffffff !important;"
						>
							<option value="all" style="color: #000000 !important; background-color: #ffffff !important;">📋 {$t('iconManager.all') || 'All Categories'}</option>
							{#each categories as cat}
								<option value={cat} style="color: #000000 !important; background-color: #ffffff !important;">{CATEGORY_EMOJIS[cat] || '📦'} {cat}</option>
							{/each}
						</select>
					</div>
				</div>

				<!-- Table Container -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col flex-1">
					<!-- Table Wrapper -->
					<div class="overflow-auto flex-1">
						{#if filteredIcons.length === 0}
							<div class="flex flex-col items-center justify-center py-16 text-slate-400">
								<div class="text-4xl mb-3">🔍</div>
								<p class="text-sm font-semibold">{$t('iconManager.noIcons') || 'No icons found'}</p>
							</div>
						{:else}
							<table class="w-full border-collapse [&_th]:border-x [&_th]:border-blue-500/30 [&_td]:border-x [&_td]:border-slate-200">
								<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
									<tr>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 w-16">{$t('iconManager.icons') || 'Preview'}</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('iconManager.iconName') || 'Name'}</th>
										<th class="px-4 py-3 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('iconManager.iconKey') || 'Key'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('iconManager.category') || 'Category'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('iconManager.file') || 'Size'}</th>
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">{$t('common.action') || 'Actions'}</th>
									</tr>
								</thead>
								<tbody class="divide-y divide-slate-200">
									{#each filteredIcons as icon, index (icon.id)}
										<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
											<!-- Preview -->
											<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
											<td class="px-4 py-3 text-center cursor-pointer" on:click={() => previewIcon = icon}>
												<div class="inline-flex items-center justify-center w-12 h-12 rounded-xl bg-white border border-slate-200 shadow-sm overflow-hidden p-1 checkerboard-bg">
													<img 
														src={buildUrl(icon.storage_path)} 
														alt={icon.name}
														class="max-w-full max-h-full object-contain" 
														loading="lazy"
														on:error={(e) => { (e.target as HTMLImageElement).src = '/icons/' + icon.storage_path; }}
													/>
												</div>
											</td>
											<!-- Name -->
											<td class="px-4 py-3 text-sm text-slate-700">
												<div class="font-semibold">{icon.name}</div>
												{#if icon.description}
													<div class="text-xs text-slate-400 mt-0.5 truncate max-w-[200px]">{icon.description}</div>
												{/if}
											</td>
											<!-- Key -->
											<td class="px-4 py-3 text-sm">
												<code class="inline-block px-2 py-1 rounded-lg bg-slate-100 text-slate-600 text-xs font-mono border border-slate-200">{icon.icon_key}</code>
											</td>
											<!-- Category -->
											<td class="px-4 py-3 text-sm text-center">
												<span class="inline-block px-3 py-1 rounded-full text-[11px] font-black capitalize
													{icon.category === 'logo' ? 'bg-purple-100 text-purple-700' : 
													icon.category === 'currency' ? 'bg-amber-100 text-amber-700' : 
													icon.category === 'social' ? 'bg-sky-100 text-sky-700' :
													icon.category === 'pwa' ? 'bg-emerald-100 text-emerald-700' :
													icon.category === 'misc' ? 'bg-orange-100 text-orange-700' : 'bg-slate-100 text-slate-700'}">
													{CATEGORY_EMOJIS[icon.category] || '📦'} {icon.category}
												</span>
											</td>
											<!-- Size -->
											<td class="px-4 py-3 text-sm text-center">
												<div class="text-slate-700 font-medium">{formatFileSize(icon.file_size)}</div>
												<div class="text-xs text-slate-400">{icon.mime_type || 'N/A'}</div>
											</td>
											<!-- Actions -->
											<td class="px-4 py-3 text-sm text-center">
												<div class="flex items-center justify-center gap-1.5">
													<button 
														class="inline-flex items-center justify-center w-8 h-8 rounded-lg text-xs transition-all duration-200 transform hover:scale-110
															{copiedKey === 'url-' + icon.icon_key ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-600 hover:bg-blue-100 hover:text-blue-700'}"
														on:click={() => copyUrl(icon)}
														title="Copy URL"
													>
														{copiedKey === 'url-' + icon.icon_key ? '✅' : '🔗'}
													</button>
													<button 
														class="inline-flex items-center justify-center w-8 h-8 rounded-lg text-xs transition-all duration-200 transform hover:scale-110
															{copiedKey === 'key-' + icon.icon_key ? 'bg-emerald-100 text-emerald-600' : 'bg-slate-100 text-slate-600 hover:bg-blue-100 hover:text-blue-700'}"
														on:click={() => copyKey(icon)}
														title="Copy Key"
													>
														{copiedKey === 'key-' + icon.icon_key ? '✅' : '📋'}
													</button>
													<button 
														class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white hover:shadow-lg transition-all duration-200 transform hover:scale-110"
														on:click={() => startEdit(icon)}
														title="Edit"
													>
														✏️
													</button>
													<button 
														class="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-red-50 text-red-500 hover:bg-red-600 hover:text-white hover:shadow-lg transition-all duration-200 transform hover:scale-110"
														on:click={() => confirmDelete(icon)}
														title="Delete"
													>
														🗑️
													</button>
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						{/if}
					</div>

					<!-- Footer with row count -->
					<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
						{$t('iconManager.icons') || 'Showing'}: {filteredIcons.length} / {allIcons.length}
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- Upload Modal -->
{#if showUploadModal}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50" on:click|self={() => showUploadModal = false}>
		<div class="bg-white rounded-3xl shadow-2xl max-w-md w-full mx-4 overflow-hidden">
			<!-- Modal Header -->
			<div class="bg-gradient-to-r from-blue-600 to-blue-500 px-6 py-4">
				<h3 class="text-xl font-black text-white m-0">➕ {$t('iconManager.uploadNew') || 'Upload New Icon'}</h3>
				<p class="text-blue-100 text-sm mt-1">{$t('iconManager.iconKeyHint') || 'Upload a new icon to the system'}</p>
			</div>

			<!-- Modal Body -->
			<!-- svelte-ignore a11y-label-has-associated-control -->
			<div class="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.iconName') || 'Icon Name'} *</label>
					<input 
						type="text" 
						bind:value={uploadName} 
						on:input={handleNameInput}
						placeholder="e.g. WhatsApp Logo"
						class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
					/>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.iconKey') || 'Icon Key'} *</label>
					<input 
						type="text" 
						bind:value={uploadKey}
						placeholder="e.g. whatsapp-logo"
						class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
					/>
					<p class="text-xs text-slate-400 mt-1">{$t('iconManager.iconKeyHint') || 'Unique identifier used in code. Auto-generated from name.'}</p>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.category') || 'Category'}</label>
					<select 
						bind:value={uploadCategory}
						class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
						style="color: #000000 !important; background-color: #ffffff !important;"
					>
						{#each CATEGORY_OPTIONS as cat}
							<option value={cat} style="color: #000000 !important; background-color: #ffffff !important;">{CATEGORY_EMOJIS[cat] || '📦'} {cat}</option>
						{/each}
					</select>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.description') || 'Description'}</label>
					<input 
						type="text" 
						bind:value={uploadDescription}
						placeholder="Optional description"
						class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
					/>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.file') || 'Icon File'} *</label>
					<input 
						type="file" 
						id="icon-file-input" 
						accept="image/*" 
						on:change={handleFileSelect}
						class="w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
					/>
					{#if uploadFile}
						<div class="flex items-center gap-3 mt-3 p-3 bg-slate-50 rounded-xl border border-slate-200">
							<img src={URL.createObjectURL(uploadFile)} alt="Preview" class="w-12 h-12 object-contain rounded-lg border border-slate-200" />
							<span class="text-xs text-slate-500">{uploadFile.name} ({formatFileSize(uploadFile.size)})</span>
						</div>
					{/if}
				</div>
			</div>

			<!-- Modal Footer -->
			<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
				<button 
					class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
					on:click={() => showUploadModal = false}
				>
					{$t('common.cancel') || 'Cancel'}
				</button>
				<button 
					class="px-6 py-2 rounded-lg font-black text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
					on:click={uploadIcon}
					disabled={uploading || !uploadFile || !uploadName || !uploadKey}
				>
					{#if uploading}
						<span class="inline-block animate-spin">⏳</span> {$t('common.uploading') || 'Uploading...'}
					{:else}
						⬆️ {$t('iconManager.upload') || 'Upload'}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Edit Modal -->
{#if editingIcon}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center z-50" on:click|self={() => editingIcon = null}>
		<div class="bg-white rounded-3xl shadow-2xl max-w-md w-full mx-4 overflow-hidden">
			<!-- Modal Header -->
			<div class="bg-gradient-to-r from-blue-600 to-blue-500 px-6 py-4">
				<h3 class="text-xl font-black text-white m-0">✏️ {$t('iconManager.editIcon') || 'Edit Icon'}</h3>
				<p class="text-blue-100 text-sm mt-1">{editingIcon.icon_key}</p>
			</div>

			<!-- Modal Body -->
			<!-- svelte-ignore a11y-label-has-associated-control -->
			<div class="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
				<!-- Current Icon Preview -->
				<div class="flex flex-col items-center gap-2 p-4 bg-slate-50 rounded-xl border border-slate-200">
					<div class="w-20 h-20 flex items-center justify-center rounded-xl bg-white border border-slate-200 shadow-sm p-2 checkerboard-bg">
						<img src={buildUrl(editingIcon.storage_path)} alt={editingIcon.name} class="max-w-full max-h-full object-contain" />
					</div>
					<span class="text-xs text-slate-400 font-medium">{$t('iconManager.currentIcon') || 'Current icon'}</span>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.iconName') || 'Icon Name'}</label>
					<input 
						type="text" 
						bind:value={editName}
						class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
					/>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.category') || 'Category'}</label>
					<select 
						bind:value={editCategory}
						class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
						style="color: #000000 !important; background-color: #ffffff !important;"
					>
						{#each CATEGORY_OPTIONS as cat}
							<option value={cat} style="color: #000000 !important; background-color: #ffffff !important;">{CATEGORY_EMOJIS[cat] || '📦'} {cat}</option>
						{/each}
					</select>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.description') || 'Description'}</label>
					<input 
						type="text" 
						bind:value={editDescription}
						class="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
					/>
				</div>
				<div>
					<label class="block text-sm font-bold text-slate-700 mb-2">{$t('iconManager.replaceFile') || 'Replace File (optional)'}</label>
					<input 
						type="file" 
						accept="image/*" 
						on:change={handleEditFileSelect}
						class="w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
					/>
					{#if editFile}
						<div class="flex items-center gap-3 mt-3 p-3 bg-slate-50 rounded-xl border border-slate-200">
							<img src={URL.createObjectURL(editFile)} alt="Preview" class="w-12 h-12 object-contain rounded-lg border border-slate-200" />
							<span class="text-xs text-slate-500">{editFile.name} ({formatFileSize(editFile.size)})</span>
						</div>
					{/if}
				</div>
			</div>

			<!-- Modal Footer -->
			<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
				<button 
					class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
					on:click={() => editingIcon = null}
				>
					{$t('common.cancel') || 'Cancel'}
				</button>
				<button 
					class="px-6 py-2 rounded-lg font-black text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
					on:click={saveEdit}
					disabled={uploading}
				>
					{#if uploading}
						<span class="inline-block animate-spin">⏳</span> {$t('common.saving') || 'Saving...'}
					{:else}
						💾 {$t('common.save') || 'Save'}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Delete Confirm Modal -->
{#if deletingIcon}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center" on:click|self={() => deletingIcon = null}>
		<div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden">
			<!-- Modal Header -->
			<div class="px-6 py-4 bg-gradient-to-r from-red-600 to-red-500 text-white">
				<h3 class="text-lg font-bold m-0">🗑️ {$t('iconManager.confirmDelete') || 'Confirm Delete'}</h3>
			</div>

			<!-- Modal Body -->
			<div class="px-6 py-6 space-y-4">
				<div class="flex flex-col items-center gap-3">
					<div class="w-20 h-20 flex items-center justify-center rounded-xl bg-slate-50 border border-slate-200 p-2 checkerboard-bg">
						<img src={buildUrl(deletingIcon.storage_path)} alt={deletingIcon.name} class="max-w-full max-h-full object-contain" />
					</div>
					<p class="text-center text-slate-700 text-sm">
						{$t('iconManager.deleteWarning') || 'Are you sure you want to delete'} <strong>{deletingIcon.name}</strong>?
					</p>
					<p class="text-sm text-red-600 font-semibold text-center">
						⚠️ {$t('iconManager.deleteWarningDetail') || 'This will remove the icon from storage. Components using this icon will show broken images.'}
					</p>
				</div>
			</div>

			<!-- Modal Footer -->
			<div class="px-6 py-4 bg-slate-50 border-t border-slate-200 flex gap-3 justify-end">
				<button 
					class="px-4 py-2 rounded-lg font-semibold text-slate-700 bg-slate-200 hover:bg-slate-300 transition"
					on:click={() => deletingIcon = null}
					disabled={deleting}
				>
					{$t('common.cancel') || 'Cancel'}
				</button>
				<button 
					class="px-6 py-2 rounded-lg font-black text-white bg-red-600 hover:bg-red-700 hover:shadow-lg transition transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
					on:click={deleteIcon}
					disabled={deleting}
				>
					{#if deleting}
						<span class="inline-block animate-spin">⏳</span> {$t('common.deleting') || 'Deleting...'}
					{:else}
						🗑️ {$t('common.delete') || 'Delete'}
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Preview Modal -->
{#if previewIcon}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center" on:click|self={() => previewIcon = null}>
		<div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden">
			<!-- Modal Header -->
			<div class="px-6 py-4 bg-gradient-to-r from-blue-600 to-indigo-500 text-white flex items-center justify-between">
				<div>
					<h3 class="text-lg font-bold m-0">🔍 {previewIcon.name}</h3>
					<p class="text-blue-100 text-sm mt-0.5">{previewIcon.icon_key}</p>
				</div>
				<button 
					class="w-8 h-8 rounded-lg bg-white/20 hover:bg-white/30 text-white border-none cursor-pointer text-lg flex items-center justify-center transition"
					on:click={() => previewIcon = null}
				>✕</button>
			</div>

			<!-- Modal Body -->
			<div class="p-6 space-y-4">
				<!-- Large Preview -->
				<div class="flex items-center justify-center p-8 bg-slate-50 rounded-xl border border-slate-200 checkerboard-bg">
					<img src={buildUrl(previewIcon.storage_path)} alt={previewIcon.name} class="max-w-full max-h-[250px] object-contain" />
				</div>

				<!-- Details Table -->
				<div class="divide-y divide-slate-200 rounded-xl border border-slate-200 overflow-hidden">
					<div class="flex items-center px-4 py-2.5 bg-slate-50">
						<span class="text-xs font-bold text-slate-500 uppercase w-24">Key</span>
						<code class="text-sm font-mono text-slate-700 bg-white px-2 py-0.5 rounded border border-slate-200">{previewIcon.icon_key}</code>
					</div>
					<div class="flex items-center px-4 py-2.5">
						<span class="text-xs font-bold text-slate-500 uppercase w-24">Category</span>
						<span class="text-sm text-slate-700 capitalize">{CATEGORY_EMOJIS[previewIcon.category] || '📦'} {previewIcon.category}</span>
					</div>
					<div class="flex items-center px-4 py-2.5 bg-slate-50">
						<span class="text-xs font-bold text-slate-500 uppercase w-24">Size</span>
						<span class="text-sm text-slate-700">{formatFileSize(previewIcon.file_size)}</span>
					</div>
					<div class="flex items-center px-4 py-2.5">
						<span class="text-xs font-bold text-slate-500 uppercase w-24">Type</span>
						<span class="text-sm text-slate-700">{previewIcon.mime_type || 'N/A'}</span>
					</div>
					{#if previewIcon.description}
						<div class="flex items-center px-4 py-2.5 bg-slate-50">
							<span class="text-xs font-bold text-slate-500 uppercase w-24">Description</span>
							<span class="text-sm text-slate-700">{previewIcon.description}</span>
						</div>
					{/if}
				</div>

				<!-- URL Copy -->
				<div class="flex items-center gap-2">
					<code class="flex-1 text-xs text-slate-500 bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 truncate">{buildUrl(previewIcon.storage_path)}</code>
					<button 
						class="px-4 py-2 rounded-lg font-semibold text-sm bg-blue-600 text-white hover:bg-blue-700 transition border-none cursor-pointer"
						on:click={() => previewIcon && copyUrl(previewIcon)}
					>
						📋 Copy URL
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	:global(.checkerboard-bg) {
		background-image: 
			linear-gradient(45deg, #f1f5f9 25%, transparent 25%),
			linear-gradient(-45deg, #f1f5f9 25%, transparent 25%),
			linear-gradient(45deg, transparent 75%, #f1f5f9 75%),
			linear-gradient(-45deg, transparent 75%, #f1f5f9 75%);
		background-size: 12px 12px;
		background-position: 0 0, 0 6px, 6px -6px, -6px 0px;
	}
</style>
