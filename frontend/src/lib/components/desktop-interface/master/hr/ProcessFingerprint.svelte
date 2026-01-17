<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';

	interface Employee {
		id: string;
		name_en: string;
		name_ar: string;
		current_branch_id: string;
		branch_name_en?: string;
		branch_name_ar?: string;
		nationality_id: string;
		nationality_name_en?: string;
		nationality_name_ar?: string;
		employment_status: string;
		sponsorship_status?: string;
	}

	interface Branch {
		id: string;
		name_en: string;
		name_ar: string;
	}

	interface Nationality {
		id: string;
		name_en: string;
		name_ar: string;
	}

	let loading = false;
	let error: string | null = null;
	let employees: Employee[] = [];
	let showTable = false;
	let activeView = ''; // 'with_data', 'without_data', 'result'
	let processedCount = 0;
	let isProcessing = false;
	
	// Search and Filters
	let searchQuery = '';
	let selectedBranchFilter = '';
	let selectedNationalityFilter = '';
	let availableBranches: Branch[] = [];
	let availableNationalities: Nationality[] = [];

	let supabase: any;

	$: filteredEmployees = employees.filter(emp => {
		const matchesSearch = !searchQuery || 
			emp.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
			emp.name_en.toLowerCase().includes(searchQuery.toLowerCase()) ||
			(emp.name_ar && emp.name_ar.includes(searchQuery));
		
		const matchesBranch = !selectedBranchFilter || emp.current_branch_id === selectedBranchFilter;
		const matchesNationality = !selectedNationalityFilter || emp.nationality_id === selectedNationalityFilter;

		return matchesSearch && matchesBranch && matchesNationality;
	});

	onMount(async () => {
		const { supabase: client } = await import('$lib/utils/supabase');
		supabase = client;
	});

	async function loadEmployeesWithFinger() {
		loading = true;
		error = null;
		try {
			const { data: employeeData, error: empError } = await supabase
				.from('hr_employee_master')
				.select(`
					id,
					name_en,
					name_ar,
					current_branch_id,
					nationality_id,
					employment_status,
					sponsorship_status
				`)
				.eq('employment_status', 'Job (With Finger)');

			if (empError) throw empError;

			if (!employeeData || employeeData.length === 0) {
				employees = [];
				return;
			}

			// Get branches
			const branchIds = [...new Set(employeeData.map(e => e.current_branch_id).filter(Boolean))];
			const { data: branches, error: branchError } = await supabase
				.from('branches')
				.select('id, name_en, name_ar')
				.in('id', branchIds);

			if (branchError) throw branchError;

			// Get nationalities
			const nationalityIds = [...new Set(employeeData.map(e => e.nationality_id).filter(Boolean))];
			const { data: nationalities, error: natError } = await supabase
				.from('nationalities')
				.select('id, name_en, name_ar')
				.in('id', nationalityIds);

			if (natError) throw natError;

			const branchMap = new Map<string, Branch>((branches as Branch[] || []).map(b => [String(b.id), b]));
			const nationalityMap = new Map<string, Nationality>((nationalities as Nationality[] || []).map(n => [String(n.id), n]));

			// Populate available branches and nationalities for filter
			availableBranches = branches as Branch[] || [];
			availableNationalities = nationalities as Nationality[] || [];

			const combinedData = employeeData.map(emp => {
				const branch = branchMap.get(String(emp.current_branch_id));
				const nationality = nationalityMap.get(String(emp.nationality_id));
				return {
					...emp,
					branch_name_en: branch?.name_en || 'N/A',
					branch_name_ar: branch?.name_ar || 'N/A',
					nationality_name_en: nationality?.name_en || 'N/A',
					nationality_name_ar: nationality?.name_ar || 'N/A'
				};
			});

			// Sort using the same logic as ShiftAndDayOff
			employees = sortEmployees(combinedData);

		} catch (err) {
			console.error('Error loading employees:', err);
			error = err instanceof Error ? err.message : String(err);
		} finally {
			loading = false;
		}
	}

	function sortEmployees(employees: any[]): any[] {
		const employmentStatusOrder: { [key: string]: number } = {
			'Job (With Finger)': 1,
			'Job (No Finger)': 2,
			'Remote Job': 3,
			'Vacation': 4,
			'Resigned': 5,
			'Terminated': 6,
			'Run Away': 7
		};

		return employees.sort((a, b) => {
			// 1. Sort by employment status
			const statusOrderA = employmentStatusOrder[a.employment_status] || 99;
			const statusOrderB = employmentStatusOrder[b.employment_status] || 99;
			if (statusOrderA !== statusOrderB) return statusOrderA - statusOrderB;

			// 2. Sort by nationality (Saudi Arabia first)
			const nationalityNameA = a.nationality_name_en || '';
			const nationalityNameB = b.nationality_name_en || '';
			const isSaudiA = nationalityNameA.toLowerCase().includes('saudi') ? 0 : 1;
			const isSaudiB = nationalityNameB.toLowerCase().includes('saudi') ? 0 : 1;
			if (isSaudiA !== isSaudiB) return isSaudiA - isSaudiB;

			// 3. Sort by sponsorship status
			const isSponsoredA = a.sponsorship_status === true || a.sponsorship_status === 'true' || a.sponsorship_status === 'yes' || a.sponsorship_status === 'Yes' || a.sponsorship_status === '1' ? 0 : 1;
			const isSponsoredB = b.sponsorship_status === true || b.sponsorship_status === 'true' || b.sponsorship_status === 'yes' || b.sponsorship_status === 'Yes' || b.sponsorship_status === '1' ? 0 : 1;
			if (isSponsoredA !== isSponsoredB) return isSponsoredA - isSponsoredB;

			// 4. Sort by numeric employee ID
			const numA = parseInt(a.id?.toString().replace(/\D/g, '') || '0') || 0;
			const numB = parseInt(b.id?.toString().replace(/\D/g, '') || '0') || 0;
			if (numA !== numB) return numA - numB;

			return nationalityNameA.localeCompare(nationalityNameB);
		});
	}

	function handleProcessWithData() {
		activeView = 'with_data';
		showTable = true;
		loadEmployeesWithFinger();
	}

	function handleProcessWithoutData() {
		activeView = 'without_data';
		showTable = false;
		// Logic for later
	}

	function handleProcessResult() {
		activeView = 'result';
		showTable = false;
		// Logic for later
	}

	function handleStartProcess(employeeId: string) {
		const selectedEmployee = employees.find(e => e.id === employeeId);
		if (selectedEmployee) {
			processEmployeeFingerprints(selectedEmployee);
		}
	}

	async function initSupabase() {
		if (!supabase) {
			const { supabase: client } = await import('$lib/utils/supabase');
			supabase = client;
		}
	}

	async function processEmployeeFingerprints(employee: Employee) {
		isProcessing = true;
		error = null;
		processedCount = 0;

		try {
			await initSupabase();

			// Step 1: Get the complete employee record with employee_id_mapping
			const { data: employeeRecord, error: empRecordError } = await supabase
				.from('hr_employee_master')
				.select('id, employee_id_mapping')
				.eq('id', employee.id)
				.single();

			if (empRecordError) throw empRecordError;
			if (!employeeRecord) throw new Error('Employee record not found');

			// Step 2: Extract employee IDs from the JSONB field
			let employeeIds: string[] = [];
			if (employeeRecord.employee_id_mapping) {
				try {
					// Handle both object and array formats
					const mapping = typeof employeeRecord.employee_id_mapping === 'string' 
						? JSON.parse(employeeRecord.employee_id_mapping) 
						: employeeRecord.employee_id_mapping;

					if (Array.isArray(mapping)) {
						employeeIds = mapping.map(item => item.employee_id || item.id || String(item)).filter(Boolean);
					} else if (typeof mapping === 'object') {
						// If it's an object, extract all employee_id values
						employeeIds = Object.values(mapping).map(item => {
							if (typeof item === 'object' && item !== null && 'employee_id' in item) {
								return (item as any).employee_id;
							}
							return String(item);
						}).filter(Boolean);
					}
				} catch (parseError) {
					console.warn('Failed to parse employee_id_mapping:', parseError);
					employeeIds = [employee.id]; // Fallback to current employee ID
				}
			} else {
				employeeIds = [employee.id]; // Use the center employee ID if mapping is empty
			}

			// Remove duplicates
			employeeIds = [...new Set(employeeIds)];

			if (employeeIds.length === 0) {
				throw new Error('No employee IDs found in mapping');
			}

			// Step 3: Get unprocessed fingerprint transactions for all extracted employee IDs
			const { data: fingerprintTransactions, error: fingerprintError } = await supabase
				.from('hr_fingerprint_transactions')
				.select('employee_id, branch_id, date, time, status, id')
				.in('employee_id', employeeIds)
				.eq('processed', false);

			if (fingerprintError) throw fingerprintError;

			if (!fingerprintTransactions || fingerprintTransactions.length === 0) {
				error = 'No unprocessed fingerprint transactions found';
				return;
			}

			// Step 4: Get the maximum sequence number from existing records
			const { data: maxRecord, error: maxError } = await supabase
				.from('processed_fingerprint_transactions')
				.select('id')
				.order('id', { ascending: false })
				.limit(1)
				.single();

			let startSeq = 1;
			if (maxRecord && maxRecord.id) {
				// Extract number from PFxxx format
				const match = maxRecord.id.match(/\d+/);
				if (match) {
					startSeq = parseInt(match[0]) + 1;
				}
			}

			// Step 5: Prepare records for insertion
			const recordsToInsert = fingerprintTransactions.map((transaction, index) => {
				const seqNum = startSeq + index;
				return {
					id: `PF${seqNum}`,
					center_id: employee.id,
					employee_id: transaction.employee_id,
					branch_id: transaction.branch_id,
					punch_date: transaction.date,
					punch_time: transaction.time,
					status: transaction.status || 'check-in'
				};
			});

			// Step 6: Insert records into processed_fingerprint_transactions
			const { error: insertError } = await supabase
				.from('processed_fingerprint_transactions')
				.insert(recordsToInsert);

			if (insertError) throw insertError;

			// Step 7: Mark the source records as processed
			const transactionIds = fingerprintTransactions.map(t => t.id);
			const { error: updateError } = await supabase
				.from('hr_fingerprint_transactions')
				.update({ processed: true })
				.in('id', transactionIds);

			if (updateError) throw updateError;

			processedCount = recordsToInsert.length;
			alert($t('common.success') + `: ${processedCount} transactions processed successfully!`);
		} catch (err) {
			console.error('Error processing fingerprints:', err);
			error = err instanceof Error ? err.message : 'Failed to process fingerprints';
		} finally {
			isProcessing = false;
		}
	}</script>

<div class="process-fingerprint-container">
	<!-- Top Buttons -->
	<div class="flex flex-wrap gap-4 mb-8">
		<button 
			class="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-black text-sm text-white bg-emerald-600 hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md {activeView === 'with_data' ? 'ring-4 ring-emerald-200' : ''}"
			on:click={handleProcessWithData}
		>
			<span>📊</span>
			{$t('hr.processFingerprint.process_with_data')}
		</button>

		<button 
			class="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-black text-sm text-white bg-orange-600 hover:bg-orange-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md {activeView === 'without_data' ? 'ring-4 ring-orange-200' : ''}"
			on:click={handleProcessWithoutData}
		>
			<span>📉</span>
			{$t('hr.processFingerprint.process_without_data')}
		</button>

		<button 
			class="inline-flex items-center gap-2 px-6 py-3 rounded-xl font-black text-sm text-white bg-blue-600 hover:bg-blue-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 shadow-md {activeView === 'result' ? 'ring-4 ring-blue-200' : ''}"
			on:click={handleProcessResult}
		>
			<span>📝</span>
			{$t('hr.processFingerprint.process_result')}
		</button>
	</div>

	{#if activeView === 'with_data'}
		<!-- Filter Controls -->
		<div class="mb-6 flex flex-wrap gap-4">
			<!-- Branch Filter -->
			<div class="flex-1 min-w-[200px]">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="branch-filter">{$t('hr.shift.filter_branch')}</label>
				<select 
					id="branch-filter"
					bind:value={selectedBranchFilter}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
				>
					<option value="">{$t('hr.shift.all_branches')}</option>
					{#each availableBranches as branch}
						<option value={branch.id}>
							{$locale === 'ar' ? (branch.name_ar || branch.name_en) : branch.name_en}
						</option>
					{/each}
				</select>
			</div>

			<!-- Nationality Filter -->
			<div class="flex-1 min-w-[200px]">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="nationality-filter">{$t('hr.shift.filter_nationality')}</label>
				<select 
					id="nationality-filter"
					bind:value={selectedNationalityFilter}
					class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all"
				>
					<option value="">{$t('hr.shift.all_nationalities')}</option>
					{#each availableNationalities as nationality}
						<option value={nationality.id}>
							{$locale === 'ar' ? (nationality.name_ar || nationality.name_en) : nationality.name_en}
						</option>
					{/each}
				</select>
			</div>

			<!-- Search -->
			<div class="flex-[2] min-w-[300px]">
				<label class="block text-xs font-bold text-slate-600 mb-2 uppercase tracking-wide" for="search">{$t('hr.shift.search_employee')}</label>
				<div class="relative">
					<input 
						id="search"
						type="text"
						bind:value={searchQuery}
						placeholder={$t('hr.shift.search_placeholder')}
						class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent transition-all pl-10"
					/>
					<span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400">🔍</span>
				</div>
			</div>
		</div>

		{#if loading}
			<div class="flex-1 flex items-center justify-center">
				<div class="text-center">
					<div class="animate-spin inline-block">
						<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
					</div>
					<p class="mt-4 text-slate-600 font-semibold">{$t('hr.processFingerprint.loading_employees')}</p>
				</div>
			</div>
		{:else if error}
			<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
				<p class="text-red-700 font-semibold">{$t('common.error')}: {error}</p>
				<button 
					class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
					on:click={loadEmployeesWithFinger}
				>
					{$t('common.retry')}
				</button>
			</div>
		{:else if employees.length === 0}
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
				<div class="text-5xl mb-4">📭</div>
				<p class="text-slate-600 font-semibold">{$t('hr.processFingerprint.no_employees_with_finger')}</p>
			</div>
		{:else}
			<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
				<div class="overflow-x-auto">
					<table class="w-full border-collapse">
						<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
							<tr>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employeeId')}</th>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.fullName')}</th>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.branch')}</th>
								<th class="px-6 py-4 {$locale === 'ar' ? 'text-right' : 'text-left'} text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.nationality')}</th>
								<th class="px-6 py-4 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('hr.employmentStatus')}</th>
								<th class="px-6 py-4 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400">{$t('common.action')}</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-slate-200">
							{#each filteredEmployees as employee, index}
								<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
									<td class="px-6 py-4 text-sm font-semibold text-slate-800">{employee.id}</td>
									<td class="px-6 py-4 text-sm text-slate-700">
										{$locale === 'ar' ? employee.name_ar || employee.name_en : employee.name_en}
									</td>
									<td class="px-6 py-4 text-sm text-slate-700">
										{$locale === 'ar' ? employee.branch_name_ar || employee.branch_name_en : employee.branch_name_en}
									</td>
									<td class="px-6 py-4 text-sm text-slate-700">
										{$locale === 'ar' ? employee.nationality_name_ar || employee.nationality_name_en : employee.nationality_name_en}
									</td>
									<td class="px-6 py-4 text-sm text-center">
										<span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
											{$t('employeeFiles.inJob') || 'Job (With Finger)'}
										</span>
									</td>
									<td class="px-6 py-4 text-sm text-center">
										<button 
											class="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-emerald-600 text-white text-xs font-bold hover:bg-emerald-700 hover:shadow-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
											on:click={() => handleStartProcess(employee.id)}
											disabled={isProcessing}
										>
											{#if isProcessing}
												<span class="animate-spin inline-block mr-2">⚡</span>
												{$t('common.processing')}
											{:else}
												⚡ {$t('hr.processFingerprint.start_process')}
											{/if}
										</button>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
				<div class="px-6 py-4 bg-slate-100/50 border-t border-slate-200 text-xs text-slate-600 font-semibold">
					{$t('hr.shift.showing_employees', { count: filteredEmployees.length })}
				</div>
			</div>
		{/if}
	{:else if activeView === 'without_data'}
		<div class="flex-1 flex items-center justify-center">
			<p class="text-slate-500 font-medium">Process Without Data view will be implemented here.</p>
		</div>
	{:else if activeView === 'result'}
		<div class="flex-1 flex items-center justify-center">
			<p class="text-slate-500 font-medium">Process Result view will be implemented here.</p>
		</div>
	{:else}
		<div class="flex-1 flex flex-col items-center justify-center text-slate-400">
			<div class="text-6xl mb-4">👆</div>
			<p class="text-lg font-medium">Select a process type to begin</p>
		</div>
	{/if}
</div>

<style>
	.process-fingerprint-container {
		padding: 2rem;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: #f8fafc;
	}
</style>
