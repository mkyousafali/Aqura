<script lang="ts">
	import { _ as t, locale } from '$lib/i18n';
	import { onMount } from 'svelte';

	interface BucketInfo {
		id: string;
		name: string;
		public: boolean;
		created_at: string;
		updated_at: string;
		file_size_limit: number | null;
		allowed_mime_types: string[] | null;
		fileCount: number;
		totalSize: number;
	}

	let supabase: any = null;
	let buckets: BucketInfo[] = [];
	let loading = true;
	let error = '';
	let totalStorageUsed = 0;
	let totalFileCount = 0;
	let clearingBucket = '';
	let downloadingBucket = '';
	let confirmClear = '';
	let actionProgress = '';
	let activeTab = 'storage';
	let showFilesPopup = false;
	let filesPopupBucket = '';
	let filesPopupLoading = false;
	let filesPopupList: { name: string; fullPath: string; size: number; created_at: string }[] = [];
	let filesPopupError = '';

	// Tables tab state
	interface TableInfo {
		table_name: string;
		column_count: number;
		row_estimate: number;
		table_size: string;
		total_size: string;
		schema_ddl: string;
	}
	let tables: TableInfo[] = [];
	let tablesLoading = false;
	let tablesError = '';
	let tablesSearch = '';
	let copiedTable = '';

	$: filteredTables = tablesSearch
		? tables.filter(t => t.table_name.toLowerCase().includes(tablesSearch.toLowerCase()))
		: tables;

	async function loadTables() {
		tablesLoading = true;
		tablesError = '';
		try {
			const { data, error: rpcErr } = await supabase.rpc('get_table_schemas');
			if (rpcErr) {
				tablesError = rpcErr.message;
			} else {
				tables = (data || []).map((r: any) => ({
					table_name: r.table_name,
					column_count: Number(r.column_count) || 0,
					row_estimate: Number(r.row_estimate) || 0,
					table_size: r.table_size,
					total_size: r.total_size,
					schema_ddl: r.schema_ddl
				}));
			}
		} catch (e: any) {
			tablesError = e.message;
		}
		tablesLoading = false;
	}

	async function copySchema(tableName: string, ddl: string) {
		try {
			await navigator.clipboard.writeText(ddl);
			copiedTable = tableName;
			setTimeout(() => { copiedTable = ''; }, 2000);
		} catch (e) {
			alert('Failed to copy to clipboard');
		}
	}

	// Functions tab state
	interface FuncInfo {
		func_name: string;
		func_args: string;
		return_type: string;
		func_language: string;
		func_type: string;
		is_security_definer: boolean;
		func_definition: string;
	}
	let functions: FuncInfo[] = [];
	let funcsLoading = false;
	let funcsError = '';
	let funcsSearch = '';
	let copiedFunc = '';

	$: filteredFuncs = funcsSearch
		? functions.filter(f => f.func_name.toLowerCase().includes(funcsSearch.toLowerCase()))
		: functions;

	async function loadFunctions() {
		funcsLoading = true;
		funcsError = '';
		try {
			const { data, error: rpcErr } = await supabase.rpc('get_database_functions');
			if (rpcErr) {
				funcsError = rpcErr.message;
			} else {
				functions = (data || []).map((r: any) => ({
					func_name: r.func_name,
					func_args: r.func_args || '',
					return_type: r.return_type || '',
					func_language: r.func_language || '',
					func_type: r.func_type || 'FUNCTION',
					is_security_definer: r.is_security_definer || false,
					func_definition: r.func_definition || ''
				}));
			}
		} catch (e: any) {
			funcsError = e.message;
		}
		funcsLoading = false;
	}

	async function copyFunction(funcName: string, ddl: string) {
		try {
			await navigator.clipboard.writeText(ddl);
			copiedFunc = funcName;
			setTimeout(() => { copiedFunc = ''; }, 2000);
		} catch (e) {
			alert('Failed to copy to clipboard');
		}
	}

	// Edge Functions tab state
	interface EdgeFuncInfo {
		func_name: string;
		func_size: string;
		file_count: number;
		last_modified: string;
		has_index: boolean;
		func_code: string;
	}
	let edgeFunctions: EdgeFuncInfo[] = [];
	let edgeFuncsLoading = false;
	let edgeFuncsError = '';
	let copiedEdgeFunc = '';
	let showEdgeCodePopup = false;

	// Server disk usage
	interface DiskUsage {
		filesystem: string;
		total_size: string;
		used_size: string;
		available_size: string;
		use_percent: number;
		mount_point: string;
	}
	let diskUsage: DiskUsage | null = null;
	let diskLoading = false;
	let restarting = false;
	let restartStatus = '';

	async function restartServer() {
		if (restarting) return;
		if (!confirm('⚠️ This will restart ALL Supabase services (database, auth, storage, etc.).\n\nThe system will be unavailable for ~30-60 seconds.\n\nAre you sure?')) return;
		restarting = true;
		restartStatus = 'Sending restart request...';
		try {
			const { data, error: rpcErr } = await supabase.rpc('request_server_restart');
			if (rpcErr) {
				restartStatus = '❌ Failed: ' + rpcErr.message;
				setTimeout(() => { restartStatus = ''; }, 5000);
			} else {
				restartStatus = '✅ ' + (data || 'Restart requested. Services will restart shortly.');
				setTimeout(() => { restartStatus = ''; }, 15000);
			}
		} catch (e: any) {
			restartStatus = '❌ Error: ' + e.message;
			setTimeout(() => { restartStatus = ''; }, 5000);
		}
		restarting = false;
	}

	async function loadDiskUsage() {
		diskLoading = true;
		try {
			const { data, error: rpcErr } = await supabase.rpc('get_server_disk_usage');
			if (!rpcErr && data && data.length > 0) {
				diskUsage = data[0];
			}
		} catch (e) { /* ignore */ }
		diskLoading = false;
	}
	let edgeCodePopupName = '';
	let edgeCodePopupCode = '';

	async function loadEdgeFunctions() {
		edgeFuncsLoading = true;
		edgeFuncsError = '';
		try {
			const { data, error: rpcErr } = await supabase.rpc('get_edge_functions');
			if (rpcErr) {
				edgeFuncsError = rpcErr.message;
			} else {
				edgeFunctions = (data || []).map((r: any) => ({
					func_name: r.func_name,
					func_size: r.func_size || '0B',
					file_count: Number(r.file_count) || 0,
					last_modified: r.last_modified || '',
					has_index: r.has_index || false,
					func_code: r.func_code || ''
				}));
			}
		} catch (e: any) {
			edgeFuncsError = e.message;
		}
		edgeFuncsLoading = false;
	}

	async function copyEdgeCode(funcName: string, code: string) {
		try {
			await navigator.clipboard.writeText(code);
			copiedEdgeFunc = funcName;
			setTimeout(() => { copiedEdgeFunc = ''; }, 2000);
		} catch (e) {
			alert('Failed to copy to clipboard');
		}
	}

	function viewEdgeCode(funcName: string, code: string) {
		edgeCodePopupName = funcName;
		edgeCodePopupCode = code;
		showEdgeCodePopup = true;
	}

	function closeEdgeCodePopup() {
		showEdgeCodePopup = false;
		edgeCodePopupName = '';
		edgeCodePopupCode = '';
	}

	function formatEdgeDate(dateStr: string): string {
		if (!dateStr) return '-';
		try {
			return new Date(dateStr).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
		} catch { return dateStr; }
	}

	async function browseBucket(bucketName: string) {
		showFilesPopup = true;
		filesPopupBucket = bucketName;
		filesPopupLoading = true;
		filesPopupError = '';
		filesPopupList = [];

		try {
			const { data, error: rpcErr } = await supabase.rpc('get_bucket_files', { p_bucket_id: bucketName });
			if (rpcErr) {
				filesPopupError = rpcErr.message;
			} else {
				filesPopupList = (data || []).map((f: any) => ({
					name: f.file_name,
					fullPath: f.full_path,
					size: Number(f.file_size) || 0,
					created_at: f.created_at || ''
				}));
			}
		} catch (e: any) {
			filesPopupError = e.message;
		}

		filesPopupLoading = false;
	}

	function closeFilesPopup() {
		showFilesPopup = false;
		filesPopupBucket = '';
		filesPopupList = [];
		filesPopupError = '';
	}

	$: tabs = [
		{ id: 'storage', label: 'Storage', icon: '\u{1F5C4}\uFE0F', color: 'green' },
		{ id: 'tables', label: 'Tables', icon: '\u{1F5C3}\uFE0F', color: 'orange' },
		{ id: 'functions', label: 'Functions', icon: '\u{2699}\uFE0F', color: 'purple' },
		{ id: 'edge', label: 'Edge Functions', icon: '\u{26A1}', color: 'cyan' }
	];

	function getTabActiveClass(color: string): string {
		const map: Record<string, string> = {
			green: 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]',
			orange: 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]',
			purple: 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]',
			cyan: 'bg-cyan-600 text-white shadow-lg shadow-cyan-200 scale-[1.02]',
			blue: 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]'
		};
		return map[color] || map.orange;
	}

	function formatBytes(bytes: number): string {
		if (bytes === 0) return '0 B';
		const k = 1024;
		const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
		const i = Math.floor(Math.log(bytes) / Math.log(k));
		return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
	}

	function getStorageColor(bytes: number): string {
		if (bytes >= 10 * 1024 * 1024 * 1024) return '#ef4444';
		if (bytes >= 1 * 1024 * 1024 * 1024) return '#f59e0b';
		if (bytes >= 100 * 1024 * 1024) return '#3b82f6';
		return '#10b981';
	}

	function getPercentage(bytes: number): number {
		if (totalStorageUsed === 0) return 0;
		return (bytes / totalStorageUsed) * 100;
	}

	function getBucketIcon(name: string): string {
		const iconMap: Record<string, string> = {
			'completion-photos': '\u{1F4F8}',
			'original-bills': '\u{1F9FE}',
			'flyer-product-images': '\u{1F5BC}\uFE0F',
			'clearance-certificates': '\u{1F4DC}',
			'quick-task-files': '\u{1F4CB}',
			'product-request-photos': '\u{1F4E6}',
			'pr-excel-files': '\u{1F4CA}',
			'flyer-templates': '\u{1F3A8}',
			'offer-pdfs': '\u{1F4C4}',
			'expense-scheduler-bills': '\u{1F4B3}',
			'requisition-images': '\u{1F4DD}',
			'employee-documents': '\u{1F464}',
			'custom-fonts': '\u{1F524}',
			'documents': '\u{1F4C1}',
			'shelf-paper-templates': '\u{1F3F7}\uFE0F',
			'purchase-voucher-receipts': '\u{1F9FE}',
			'pos-before': '\u{1F3EA}',
			'task-images': '\u2705',
			'asset-invoices': '\u{1F3E2}',
			'stock-documents': '\u{1F4E6}',
			'category-images': '\u{1F5C2}\uFE0F',
			'product-images': '\u{1F6D2}',
			'notification-images': '\u{1F514}'
		};
		return iconMap[name] || '\u{1F4C2}';
	}

	async function loadBuckets() {
		loading = true;
		error = '';

		try {
			const { data, error: rpcError } = await supabase.rpc('get_storage_buckets_info');

			if (rpcError) {
				error = `Failed to load storage info: ${rpcError.message}`;
				loading = false;
				return;
			}

			buckets = (data || []).map((row: any) => ({
				id: row.bucket_id,
				name: row.bucket_name,
				public: row.is_public,
				created_at: row.created_at,
				updated_at: row.updated_at,
				file_size_limit: row.file_size_limit,
				allowed_mime_types: row.allowed_mime_types,
				fileCount: Number(row.file_count) || 0,
				totalSize: Number(row.total_size) || 0
			}));

			totalStorageUsed = buckets.reduce((sum, b) => sum + b.totalSize, 0);
			totalFileCount = buckets.reduce((sum, b) => sum + b.fileCount, 0);
		} catch (e: any) {
			error = `Error: ${e.message}`;
		}

		loading = false;
	}

	async function listAllFiles(bucketName: string, folder = ''): Promise<any[]> {
		let allFiles: any[] = [];
		let offset = 0;
		const limit = 100;

		while (true) {
			const { data, error } = await supabase.storage
				.from(bucketName)
				.list(folder, { limit, offset });

			if (error || !data || data.length === 0) break;

			for (const item of data) {
				const path = folder ? `${folder}/${item.name}` : item.name;
				if (item.id === null) {
					const subFiles = await listAllFiles(bucketName, path);
					allFiles = [...allFiles, ...subFiles];
				} else {
					allFiles.push({ ...item, fullPath: path });
				}
			}

			if (data.length < limit) break;
			offset += limit;
		}

		return allFiles;
	}

	async function clearBucket(bucketName: string) {
		if (confirmClear !== bucketName) {
			confirmClear = bucketName;
			return;
		}

		clearingBucket = bucketName;
		confirmClear = '';
		actionProgress = 'Listing files...';

		try {
			const allFiles = await listAllFiles(bucketName);

			if (allFiles.length === 0) {
				actionProgress = '';
				clearingBucket = '';
				alert('Bucket is already empty.');
				return;
			}

			const paths = allFiles.map((f: any) => f.fullPath);
			let deleted = 0;

			for (let i = 0; i < paths.length; i += 100) {
				const batch = paths.slice(i, i + 100);
				const { error: delError } = await supabase.storage
					.from(bucketName)
					.remove(batch);

				if (delError) {
					console.error('Delete error:', delError);
				}
				deleted += batch.length;
				actionProgress = `Deleting... ${deleted}/${paths.length}`;
			}

			actionProgress = '';
			clearingBucket = '';
			await loadBuckets();
		} catch (e: any) {
			console.error('Clear bucket error:', e);
			actionProgress = '';
			clearingBucket = '';
			alert(`Error clearing bucket: ${e.message}`);
		}
	}

	async function downloadBucket(bucketName: string) {
		downloadingBucket = bucketName;
		actionProgress = 'Listing files...';

		try {
			const allFiles = await listAllFiles(bucketName);

			if (allFiles.length === 0) {
				actionProgress = '';
				downloadingBucket = '';
				alert('Bucket is empty, nothing to download.');
				return;
			}

			const JSZip = (await import('jszip')).default;
			const zip = new JSZip();
			const folder = zip.folder(bucketName)!;

			let downloaded = 0;
			for (const file of allFiles) {
				try {
					const { data, error: dlError } = await supabase.storage
						.from(bucketName)
						.download(file.fullPath);

					if (!dlError && data) {
						folder.file(file.fullPath, data);
					}
				} catch (e) {
					console.warn(`Skipping file ${file.fullPath}:`, e);
				}

				downloaded++;
				actionProgress = `Downloading... ${downloaded}/${allFiles.length}`;
			}

			actionProgress = 'Creating ZIP...';
			const blob = await zip.generateAsync({ type: 'blob' });

			const url = URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = `${bucketName}.zip`;
			document.body.appendChild(a);
			a.click();
			document.body.removeChild(a);
			URL.revokeObjectURL(url);

			actionProgress = '';
			downloadingBucket = '';
		} catch (e: any) {
			console.error('Download bucket error:', e);
			actionProgress = '';
			downloadingBucket = '';
			alert(`Error downloading bucket: ${e.message}`);
		}
	}

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		await Promise.all([loadBuckets(), loadDiskUsage()]);
	});

	// Load tables every time user switches to the tab (fresh data)
	let lastTabLoad = '';
	$: if (activeTab === 'tables' && !tablesLoading && supabase && lastTabLoad !== 'tables') {
		lastTabLoad = 'tables';
		loadTables();
	}
	$: if (activeTab !== 'tables' && activeTab !== 'functions' && activeTab !== 'edge') {
		lastTabLoad = '';
	}
	$: if (activeTab === 'functions' && !funcsLoading && supabase && lastTabLoad !== 'functions') {
		lastTabLoad = 'functions';
		loadFunctions();
	}
	$: if (activeTab === 'edge' && !edgeFuncsLoading && supabase && lastTabLoad !== 'edge') {
		lastTabLoad = 'edge';
		loadEdgeFunctions();
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header / Tab Navigation -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			{#each tabs as tab}
				<button
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
					{activeTab === tab.id
						? getTabActiveClass(tab.color)
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={() => { activeTab = tab.id; }}
				>
					<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{tab.icon}</span>
					<span class="relative z-10">{tab.label}</span>
					{#if activeTab === tab.id}
						<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
					{/if}
				</button>
			{/each}
		</div>

		<button
			class="flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl font-bold text-sm transition-all shadow-lg shadow-emerald-200 hover:scale-[1.02] disabled:opacity-50 disabled:cursor-not-allowed"
			on:click={loadBuckets}
			disabled={loading}
		>
			<span class="transition-transform" class:animate-spin={loading}>{'\u{1F504}'}</span>
			Refresh
		</button>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-6 relative overflow-hidden bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col overflow-hidden">
			{#if activeTab === 'storage'}
				<!-- Server Disk Usage Card -->
				{#if diskUsage}
					<div class="mb-5 bg-gradient-to-r from-slate-800 to-slate-900 rounded-2xl border border-slate-700 shadow-xl p-5">
						<div class="flex items-center justify-between mb-3">
							<div class="flex items-center gap-3">
								<div class="w-10 h-10 rounded-xl bg-emerald-500/20 flex items-center justify-center text-xl">{"\u{1F5A5}\uFE0F"}</div>
								<div>
									<div class="text-sm font-black text-white">Server Storage</div>
									<div class="text-xs text-slate-400">8.213.42.21 &bull; {diskUsage.filesystem}</div>
								</div>
							</div>
							<div class="flex items-center gap-4">
								<button
									on:click={restartServer}
									disabled={restarting}
									class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all {restarting ? 'bg-amber-500/30 text-amber-300 cursor-wait' : 'bg-red-500/20 text-red-400 hover:bg-red-500/30 hover:text-red-300 border border-red-500/30 hover:border-red-400/50'}"
								>
									{#if restarting}
										<span class="animate-spin">{"\u{23F3}"}</span>
										Restarting...
									{:else}
										<span>{"\u{1F504}"}</span>
										Restart Server
									{/if}
								</button>
							</div>
							<div class="flex items-center gap-6">
								<div class="text-center">
									<div class="text-lg font-black text-white">{diskUsage.used_size}</div>
									<div class="text-xs text-slate-400">Used</div>
								</div>
								<div class="text-center">
									<div class="text-lg font-black text-emerald-400">{diskUsage.available_size}</div>
									<div class="text-xs text-slate-400">Free</div>
								</div>
								<div class="text-center">
									<div class="text-lg font-black text-slate-300">{diskUsage.total_size}</div>
									<div class="text-xs text-slate-400">Total</div>
								</div>
								<div class="w-16 h-16 relative">
									<svg viewBox="0 0 36 36" class="w-16 h-16 -rotate-90">
										<circle cx="18" cy="18" r="15.5" fill="none" stroke="#334155" stroke-width="3" />
										<circle cx="18" cy="18" r="15.5" fill="none"
											stroke={diskUsage.use_percent >= 80 ? '#ef4444' : diskUsage.use_percent >= 60 ? '#f59e0b' : '#10b981'}
											stroke-width="3" stroke-dasharray="{diskUsage.use_percent * 97.5 / 100} 97.5"
											stroke-linecap="round" />
									</svg>
									<div class="absolute inset-0 flex items-center justify-center">
										<span class="text-sm font-black {diskUsage.use_percent >= 80 ? 'text-red-400' : diskUsage.use_percent >= 60 ? 'text-amber-400' : 'text-emerald-400'}">{diskUsage.use_percent}%</span>
									</div>
								</div>
							</div>
						</div>
						<!-- Progress bar -->
						<div class="w-full bg-slate-700 rounded-full h-2.5">
							<div
								class="h-2.5 rounded-full transition-all duration-500"
								style="width: {diskUsage.use_percent}%; background-color: {diskUsage.use_percent >= 80 ? '#ef4444' : diskUsage.use_percent >= 60 ? '#f59e0b' : '#10b981'}"
							></div>
						</div>
						{#if restartStatus}
							<div class="mt-3 text-xs font-semibold {restartStatus.startsWith('\u274c') ? 'text-red-400' : 'text-emerald-400'} animate-pulse">
								{restartStatus}
							</div>
						{/if}
					</div>
				{/if}

				<!-- Summary Stats Row -->
				<div class="flex gap-4 mb-5">
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-emerald-100 flex items-center justify-center text-2xl">{'\u{1F4E6}'}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{buckets.length}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Buckets</div>
						</div>
					</div>
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-blue-100 flex items-center justify-center text-2xl">{'\u{1F4C4}'}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{totalFileCount.toLocaleString()}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Total Files</div>
						</div>
					</div>
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-amber-100 flex items-center justify-center text-2xl">{'\u{1F4BE}'}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{formatBytes(totalStorageUsed)}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Total Size</div>
						</div>
					</div>
				</div>

				{#if loading}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">Loading storage buckets...</p>
						</div>
					</div>
				{:else if error}
					<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
						<p class="text-red-700 font-semibold">{error}</p>
						<button
							class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
							on:click={loadBuckets}
						>
							Retry
						</button>
					</div>
				{:else}
					<!-- Storage Table -->
					<div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex-1 flex flex-col min-h-0">
						<div class="overflow-x-auto overflow-y-auto flex-1">
							<table class="w-full">
								<thead class="sticky top-0 z-10">
									<tr class="bg-slate-50 border-b border-slate-200">
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">#</th>
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">Bucket</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Status</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Files</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Size</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">% Used</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Created</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Actions</th>
									</tr>
								</thead>
								<tbody>
									{#each buckets as bucket, i}
										<tr class="border-b border-slate-100 hover:bg-emerald-50/50 transition-colors group">
											<td class="px-4 py-3 text-sm text-slate-500 font-bold">{i + 1}</td>
											<td class="px-4 py-3">
												<button
													class="flex items-center gap-3 hover:bg-slate-100 rounded-lg px-2 py-1 -mx-2 -my-1 transition-all cursor-pointer group/name"
													on:click={() => browseBucket(bucket.name)}
													title="Click to browse files"
												>
													<span class="text-xl">{getBucketIcon(bucket.name)}</span>
													<span class="text-sm font-bold text-slate-800 group-hover/name:text-emerald-700 group-hover/name:underline transition-colors">{bucket.name}</span>
												</button>
											</td>
											<td class="px-4 py-3 text-center">
												{#if bucket.public}
													<span class="inline-flex items-center gap-1 px-2.5 py-1 bg-emerald-100 text-emerald-700 rounded-full text-xs font-bold">
														{'\u{1F310}'} Public
													</span>
												{:else}
													<span class="inline-flex items-center gap-1 px-2.5 py-1 bg-amber-100 text-amber-700 rounded-full text-xs font-bold">
														{'\u{1F512}'} Private
													</span>
												{/if}
											</td>
											<td class="px-4 py-3 text-center text-sm font-bold text-slate-700">{bucket.fileCount.toLocaleString()}</td>
											<td class="px-4 py-3 text-center">
												<span class="text-sm font-black" style="color: {getStorageColor(bucket.totalSize)}">
													{formatBytes(bucket.totalSize)}
												</span>
											</td>
											<td class="px-4 py-3 text-center">
												<div class="flex items-center gap-2 justify-center">
													<div class="w-16 h-2 bg-slate-200 rounded-full overflow-hidden">
														<div class="h-full rounded-full transition-all" style="width: {getPercentage(bucket.totalSize)}%; background: {getStorageColor(bucket.totalSize)};"></div>
													</div>
													<span class="text-xs font-bold text-slate-500">{getPercentage(bucket.totalSize).toFixed(1)}%</span>
												</div>
											</td>
											<td class="px-4 py-3 text-center text-xs text-slate-500 font-semibold">{new Date(bucket.created_at).toLocaleDateString()}</td>
											<td class="px-4 py-3 text-center">
												<div class="flex items-center justify-center gap-2">
													<button
														class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
														{downloadingBucket === bucket.name ? 'bg-blue-100 text-blue-600' : 'bg-blue-50 text-blue-600 hover:bg-blue-100 hover:shadow'}
														disabled:opacity-40 disabled:cursor-not-allowed"
														on:click={() => downloadBucket(bucket.name)}
														disabled={downloadingBucket === bucket.name || bucket.fileCount === 0}
														title="Download as ZIP"
													>
														{#if downloadingBucket === bucket.name}
															<span class="animate-spin inline-block">{'\u2B07\uFE0F'}</span> {actionProgress}
														{:else}
															{'\u2B07\uFE0F'} Download
														{/if}
													</button>
													<button
														class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
														{confirmClear === bucket.name ? 'bg-red-600 text-white animate-pulse' : 'bg-red-50 text-red-600 hover:bg-red-100 hover:shadow'}
														disabled:opacity-40 disabled:cursor-not-allowed"
														on:click={() => clearBucket(bucket.name)}
														disabled={clearingBucket === bucket.name || bucket.fileCount === 0}
														title="Delete all files"
													>
														{#if clearingBucket === bucket.name}
															<span class="animate-spin inline-block">{'\u{1F5D1}\uFE0F'}</span> {actionProgress}
														{:else if confirmClear === bucket.name}
															{'\u26A0\uFE0F'} Confirm?
														{:else}
															{'\u{1F5D1}\uFE0F'} Clear
														{/if}
													</button>
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					</div>
				{/if}

			{:else if activeTab === 'tables'}
				<!-- Tables Tab Header -->
				<div class="flex gap-4 mb-5 items-center">
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-orange-100 flex items-center justify-center text-2xl">{"\u{1F5C3}\uFE0F"}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{tables.length}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Tables</div>
						</div>
					</div>
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-blue-100 flex items-center justify-center text-2xl">{"\u{1F4CA}"}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{tables.reduce((s, t) => s + t.row_estimate, 0).toLocaleString()}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Total Rows</div>
						</div>
					</div>
					<div class="flex-[2] bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-3 flex items-center gap-3">
						<span class="text-xl">{"\u{1F50D}"}</span>
						<input
							type="text"
							placeholder="Search tables..."
							bind:value={tablesSearch}
							class="w-full bg-transparent outline-none text-sm font-semibold text-slate-700 placeholder-slate-400"
						/>
					</div>
					<button
						class="px-5 py-3 bg-orange-600 hover:bg-orange-700 text-white rounded-xl font-bold text-sm transition-all shadow-lg shadow-orange-200 hover:scale-[1.02] disabled:opacity-50"
						on:click={loadTables}
						disabled={tablesLoading}
					>
						<span class:animate-spin={tablesLoading}>{"\u{1F504}"}</span> Refresh
					</button>
				</div>

				{#if tablesLoading}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-orange-200 border-t-orange-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">Loading table schemas...</p>
						</div>
					</div>
				{:else if tablesError}
					<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
						<p class="text-red-700 font-semibold">{tablesError}</p>
						<button class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition" on:click={loadTables}>Retry</button>
					</div>
				{:else}
					<div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex-1 flex flex-col min-h-0">
						<div class="overflow-x-auto overflow-y-auto flex-1">
							<table class="w-full">
								<thead class="sticky top-0 z-10">
									<tr class="bg-slate-50 border-b border-slate-200">
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">#</th>
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">Table Name</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Columns</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Rows (est.)</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Data Size</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Total Size</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Actions</th>
									</tr>
								</thead>
								<tbody>
									{#each filteredTables as tbl, i}
										<tr class="border-b border-slate-100 hover:bg-orange-50/50 transition-colors">
											<td class="px-4 py-3 text-sm text-slate-500 font-bold">{i + 1}</td>
											<td class="px-4 py-3">
												<span class="text-sm font-bold text-slate-800">{tbl.table_name}</span>
											</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-flex items-center px-2.5 py-1 bg-blue-100 text-blue-700 rounded-full text-xs font-bold">{tbl.column_count}</span>
											</td>
											<td class="px-4 py-3 text-center text-sm font-bold text-slate-700">{tbl.row_estimate.toLocaleString()}</td>
											<td class="px-4 py-3 text-center text-sm font-semibold text-slate-600">{tbl.table_size}</td>
											<td class="px-4 py-3 text-center text-sm font-semibold text-slate-600">{tbl.total_size}</td>
											<td class="px-4 py-3 text-center">
												<button
													class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
													{copiedTable === tbl.table_name ? 'bg-green-600 text-white' : 'bg-orange-50 text-orange-600 hover:bg-orange-100 hover:shadow'}"
													on:click={() => copySchema(tbl.table_name, tbl.schema_ddl)}
													title="Copy CREATE TABLE schema"
												>
													{#if copiedTable === tbl.table_name}
														{"\u2705"} Copied!
													{:else}
														{"\u{1F4CB}"} Copy Schema
													{/if}
												</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					</div>
				{/if}
			{:else if activeTab === 'functions'}
				<!-- Functions Tab Header -->
				<div class="flex gap-4 mb-5 items-center">
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-purple-100 flex items-center justify-center text-2xl">{"\u2699\uFE0F"}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{functions.length}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Functions</div>
						</div>
					</div>
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-indigo-100 flex items-center justify-center text-2xl">{"\u{1F6E1}\uFE0F"}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{functions.filter(f => f.is_security_definer).length}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Security Definer</div>
						</div>
					</div>
					<div class="flex-[2] bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-3 flex items-center gap-3">
						<span class="text-xl">{"\u{1F50D}"}</span>
						<input
							type="text"
							placeholder="Search functions..."
							bind:value={funcsSearch}
							class="w-full bg-transparent outline-none text-sm font-semibold text-slate-700 placeholder-slate-400"
						/>
					</div>
					<button
						class="px-5 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-xl font-bold text-sm transition-all shadow-lg shadow-purple-200 hover:scale-[1.02] disabled:opacity-50"
						on:click={loadFunctions}
						disabled={funcsLoading}
					>
						<span class:animate-spin={funcsLoading}>{"\u{1F504}"}</span> Refresh
					</button>
				</div>

				{#if funcsLoading}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-purple-200 border-t-purple-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">Loading functions...</p>
						</div>
					</div>
				{:else if funcsError}
					<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
						<p class="text-red-700 font-semibold">{funcsError}</p>
						<button class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition" on:click={loadFunctions}>Retry</button>
					</div>
				{:else}
					<div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex-1 flex flex-col min-h-0">
						<div class="overflow-x-auto overflow-y-auto flex-1">
							<table class="w-full">
								<thead class="sticky top-0 z-10">
									<tr class="bg-slate-50 border-b border-slate-200">
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">#</th>
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">Function Name</th>
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">Arguments</th>
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">Returns</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Language</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Security</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Actions</th>
									</tr>
								</thead>
								<tbody>
									{#each filteredFuncs as fn, i}
										<tr class="border-b border-slate-100 hover:bg-purple-50/50 transition-colors">
											<td class="px-4 py-3 text-sm text-slate-500 font-bold">{i + 1}</td>
											<td class="px-4 py-3">
												<span class="text-sm font-bold text-slate-800">{fn.func_name}</span>
											</td>
											<td class="px-4 py-3">
												<span class="text-xs font-mono text-slate-600 max-w-[200px] truncate inline-block" title={fn.func_args}>
													{fn.func_args || '(none)'}
												</span>
											</td>
											<td class="px-4 py-3">
												<span class="text-xs font-mono text-slate-600 max-w-[200px] truncate inline-block" title={fn.return_type}>
													{fn.return_type}
												</span>
											</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold
													{fn.func_language === 'plpgsql' ? 'bg-blue-100 text-blue-700' : fn.func_language === 'sql' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'}">
													{fn.func_language}
												</span>
											</td>
											<td class="px-4 py-3 text-center">
												{#if fn.is_security_definer}
													<span class="inline-flex items-center px-2.5 py-1 bg-red-100 text-red-700 rounded-full text-xs font-bold">{"\u{1F6E1}\uFE0F"} DEFINER</span>
												{:else}
													<span class="inline-flex items-center px-2.5 py-1 bg-slate-100 text-slate-500 rounded-full text-xs font-bold">INVOKER</span>
												{/if}
											</td>
											<td class="px-4 py-3 text-center">
												<button
													class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
													{copiedFunc === fn.func_name ? 'bg-green-600 text-white' : 'bg-purple-50 text-purple-600 hover:bg-purple-100 hover:shadow'}"
													on:click={() => copyFunction(fn.func_name, fn.func_definition)}
													title="Copy function definition"
												>
													{#if copiedFunc === fn.func_name}
														{"\u2705"} Copied!
													{:else}
														{"\u{1F4CB}"} Copy
													{/if}
												</button>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					</div>
				{/if}
			{:else if activeTab === 'edge'}
				<!-- Edge Functions Tab Header -->
				<div class="flex gap-4 mb-5 items-center">
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-cyan-100 flex items-center justify-center text-2xl">{"\u{26A1}"}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{edgeFunctions.length}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Edge Functions</div>
						</div>
					</div>
					<div class="flex-1 bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg p-4 flex items-center gap-4">
						<div class="w-12 h-12 rounded-xl bg-teal-100 flex items-center justify-center text-2xl">{"\u{1F4C4}"}</div>
						<div>
							<div class="text-2xl font-black text-slate-900">{edgeFunctions.reduce((s, f) => s + f.file_count, 0)}</div>
							<div class="text-xs font-bold text-slate-500 uppercase tracking-wide">Total Files</div>
						</div>
					</div>
					<button
						class="px-5 py-3 bg-cyan-600 hover:bg-cyan-700 text-white rounded-xl font-bold text-sm transition-all shadow-lg shadow-cyan-200 hover:scale-[1.02] disabled:opacity-50"
						on:click={loadEdgeFunctions}
						disabled={edgeFuncsLoading}
					>
						<span class:animate-spin={edgeFuncsLoading}>{"\u{1F504}"}</span> Refresh
					</button>
				</div>

				{#if edgeFuncsLoading}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-cyan-200 border-t-cyan-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">Loading edge functions...</p>
						</div>
					</div>
				{:else if edgeFuncsError}
					<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
						<p class="text-red-700 font-semibold">{edgeFuncsError}</p>
						<button class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition" on:click={loadEdgeFunctions}>Retry</button>
					</div>
				{:else}
					<div class="bg-white/80 backdrop-blur-xl rounded-2xl border border-white shadow-lg overflow-hidden flex-1 flex flex-col min-h-0">
						<div class="overflow-x-auto overflow-y-auto flex-1">
							<table class="w-full">
								<thead class="sticky top-0 z-10">
									<tr class="bg-slate-50 border-b border-slate-200">
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">#</th>
										<th class="px-4 py-3 text-left text-xs font-black text-slate-600 uppercase tracking-wide">Function Name</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Status</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Files</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Size</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Last Modified</th>
										<th class="px-4 py-3 text-center text-xs font-black text-slate-600 uppercase tracking-wide">Actions</th>
									</tr>
								</thead>
								<tbody>
									{#each edgeFunctions as ef, i}
										<tr class="border-b border-slate-100 hover:bg-cyan-50/50 transition-colors">
											<td class="px-4 py-3 text-sm text-slate-500 font-bold">{i + 1}</td>
											<td class="px-4 py-3">
												<div class="flex items-center gap-2">
													<span class="text-lg">{"\u{26A1}"}</span>
													<span class="text-sm font-bold text-slate-800">{ef.func_name}</span>
												</div>
											</td>
											<td class="px-4 py-3 text-center">
												{#if ef.has_index}
													<span class="inline-flex items-center px-2.5 py-1 bg-green-100 text-green-700 rounded-full text-xs font-bold">{"\u2705"} Deployed</span>
												{:else}
													<span class="inline-flex items-center px-2.5 py-1 bg-yellow-100 text-yellow-700 rounded-full text-xs font-bold">{"\u26A0\uFE0F"} No index.ts</span>
												{/if}
											</td>
											<td class="px-4 py-3 text-center">
												<span class="inline-flex items-center px-2.5 py-1 bg-slate-100 text-slate-700 rounded-full text-xs font-bold">{ef.file_count}</span>
											</td>
											<td class="px-4 py-3 text-center text-sm font-semibold text-slate-600">{ef.func_size}</td>
											<td class="px-4 py-3 text-center text-sm font-semibold text-slate-600">{formatEdgeDate(ef.last_modified)}</td>
											<td class="px-4 py-3 text-center">
												<div class="flex items-center justify-center gap-2">
													<button
														class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all bg-cyan-50 text-cyan-600 hover:bg-cyan-100 hover:shadow"
														on:click={() => viewEdgeCode(ef.func_name, ef.func_code)}
														title="View source code"
														disabled={!ef.func_code}
													>
														{"\u{1F441}\uFE0F"} View
													</button>
													<button
														class="px-3 py-1.5 text-xs font-bold rounded-lg transition-all
														{copiedEdgeFunc === ef.func_name ? 'bg-green-600 text-white' : 'bg-cyan-50 text-cyan-600 hover:bg-cyan-100 hover:shadow'}"
														on:click={() => copyEdgeCode(ef.func_name, ef.func_code)}
														title="Copy source code"
														disabled={!ef.func_code}
													>
														{#if copiedEdgeFunc === ef.func_name}
															{"\u2705"} Copied!
														{:else}
															{"\u{1F4CB}"} Copy
														{/if}
													</button>
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					</div>
				{/if}
			{/if}

		</div>
	</div>
</div>

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	.tracking-fast {
		letter-spacing: 0.05em;
	}

	@keyframes fadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.95); }
		to { opacity: 1; transform: scale(1); }
	}

	.animate-in {
		animation: fadeIn 0.2s ease-out;
	}

	.scale-in {
		animation: scaleIn 0.3s ease-out;
	}
</style>
