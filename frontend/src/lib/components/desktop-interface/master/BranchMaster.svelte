<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, locale } from '$lib/i18n';
	import { type Branch } from '$lib/utils/supabase';
	import { supabase } from '$lib/utils/supabase';
	// import { goAPI } from '$lib/utils/goAPI'; // Removed - Go backend no longer used

	// Tab management
	let activeTab: 'branches' | 'approvers' = 'branches';

	// State management
	let branches: Branch[] = [];
	let showCreateBranchPopup = false;
	let showEditBranchPopup = false;
	let currentBranch: Partial<Branch> = {
		name_en: '',
		name_ar: '',
		location_en: '',
		location_ar: '',
		is_active: true,
		is_main_branch: false,
		vat_number: ''
	};
	let editingBranch: Branch | null = null;
	let isLoading = false;
	let errorMessage = '';
	let cacheHit = false; // Track if data came from cache

	// Approvers state
	let approvers: any[] = [];
	let showCreateApproverPopup = false;
	let showEditApproverPopup = false;
	let currentApprover: any = {
		user_id: '',
		can_approve_leave_requests: true,
		visibility_type: 'global',
		assigned_branches: []
	};
	let editingApproverId: string | null = null;
	let editingApprover: any = null;
	let allUsers: any[] = [];
	let visibilityType: 'global' | 'branch_specific' | 'multiple_branches' = 'global';
	let assignedBranches: any[] = [];
	let approverVisibilityMap: Map<string, any> = new Map();

	// Load branches on component mount
	onMount(async () => {
		await loadBranches();
		await loadApprovers();
	});

	// Load branches from Supabase
	async function loadBranches() {
		const startTime = performance.now();
		isLoading = true;
		errorMessage = '';
		
		try {
			const { data, error } = await supabase
				.from('branches')
				.select('*')
				.order('created_at', { ascending: false });
			
			const loadTime = Math.round(performance.now() - startTime);
			
			if (error) {
				errorMessage = error.message || 'Failed to load branches';
				console.error('Failed to load branches:', error);
			} else if (data) {
				branches = data;
				cacheHit = loadTime < 50; // If loaded in under 50ms, likely from cache
				console.log(`✅ Loaded ${data.length} branches in ${loadTime}ms ${cacheHit ? '(cached)' : ''}`);
			}
		} catch (error) {
			errorMessage = 'Failed to connect to server';
			console.error('Error loading branches:', error);
		} finally {
			isLoading = false;
		}
	}

	// Load approvers with user details and visibility config
	async function loadApprovers() {
		isLoading = true;
		errorMessage = '';

		try {
			const { data: approvingData, error: appError } = await supabase
				.from('approval_permissions')
				.select('*')
				.eq('can_approve_leave_requests', true)
				.eq('is_active', true);

			if (appError && appError.code !== 'PGRST116') {
				throw appError;
			}

			// Load users to get names
			const { data: usersData, error: usersError } = await supabase
				.from('users')
				.select('id, username');

			if (usersError && usersError.code !== 'PGRST116') {
				throw usersError;
			}

			allUsers = usersData || [];

			// Load visibility configs for all approvers
			const { data: visibilityData } = await supabase
				.from('approver_visibility_config')
				.select('*');

			approverVisibilityMap.clear();
			(visibilityData || []).forEach((vis: any) => {
				approverVisibilityMap.set(vis.user_id, vis);
			});

			// Load branch access data
			const { data: branchAccessData } = await supabase
				.from('approver_branch_access')
				.select('*')
				.eq('is_active', true);

			const branchAccessByUser = new Map<string, any[]>();
			(branchAccessData || []).forEach((access: any) => {
				if (!branchAccessByUser.has(access.user_id)) {
					branchAccessByUser.set(access.user_id, []);
				}
				branchAccessByUser.get(access.user_id)!.push(access);
			});

			const userMap = new Map(allUsers.map((u: any) => [u.id, u]));

			approvers = (approvingData || []).map((app: any) => {
				const vis = approverVisibilityMap.get(app.user_id);
				const branchAccess = branchAccessByUser.get(app.user_id) || [];
				
				return {
					...app,
					username: userMap.get(app.user_id)?.username || 'Unknown',
					visibility_type: vis?.visibility_type || 'global',
					branch_access: branchAccess
				};
			});

			console.log(`✅ Loaded ${approvers.length} leave approvers with visibility config`);
		} catch (error) {
			errorMessage = 'Failed to load approvers';
			console.error('Error loading approvers:', error);
		} finally {
			isLoading = false;
		}
	}

	// Functions for branches
	function openCreateBranchPopup() {
		currentBranch = {
			name_en: '',
			name_ar: '',
			location_en: '',
			location_ar: '',
			is_active: true,
			is_main_branch: false,
			vat_number: ''
		};
		showCreateBranchPopup = true;
	}

	function closeCreateBranchPopup() {
		showCreateBranchPopup = false;
		currentBranch = {
			name_en: '',
			name_ar: '',
			location_en: '',
			location_ar: '',
			is_active: true,
			is_main_branch: false
		};
	}

	function openEditBranchPopup(branch: Branch) {
		editingBranch = branch;
		currentBranch = { ...branch };
		showEditBranchPopup = true;
	}

	function closeEditBranchPopup() {
		showEditBranchPopup = false;
		editingBranch = null;
		currentBranch = {
			name_en: '',
			name_ar: '',
			location_en: '',
			location_ar: '',
			is_active: true,
			is_main_branch: false
		};
	}

	async function saveBranch() {
		if (!currentBranch.name_en || !currentBranch.name_ar || !currentBranch.location_en || !currentBranch.location_ar) {
			alert('Please fill in all fields');
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			const branchData = {
				name_en: currentBranch.name_en!,
				name_ar: currentBranch.name_ar!,
				location_en: currentBranch.location_en!,
				location_ar: currentBranch.location_ar!,
				is_active: currentBranch.is_active || true,
				is_main_branch: currentBranch.is_main_branch || false,
				vat_number: currentBranch.vat_number || null
			};

			let result;
			if (showCreateBranchPopup) {
				const { data, error } = await supabase
					.from('branches')
					.insert([branchData])
					.select();
				result = { error };
				
				if (result.error) {
					errorMessage = result.error.message || 'Failed to create branch';
					alert('Error creating branch: ' + errorMessage);
				} else {
					await loadBranches();
					closeCreateBranchPopup();
				}
			} else if (showEditBranchPopup && editingBranch) {
				const { error } = await supabase
					.from('branches')
					.update(branchData)
					.eq('id', editingBranch.id);
				result = { error };
				
				if (result.error) {
					errorMessage = result.error.message || 'Failed to update branch';
					alert('Error updating branch: ' + errorMessage);
				} else {
					await loadBranches();
					closeEditBranchPopup();
				}
			}
		} catch (error) {
			errorMessage = 'Failed to save branch';
			alert('Error saving branch: ' + errorMessage);
			console.error('Error saving branch:', error);
		} finally {
			isLoading = false;
		}
	}

	async function toggleBranchActive(branch: Branch) {
		isLoading = true;
		errorMessage = '';
		
		try {
			const { error } = await supabase
				.from('branches')
				.update({ is_active: !branch.is_active })
				.eq('id', branch.id);
			
			if (error) {
				errorMessage = error.message || `Failed to ${branch.is_active ? 'deactivate' : 'activate'} branch`;
				alert('Error: ' + errorMessage);
			} else {
				await loadBranches();
			}
		} catch (error) {
			errorMessage = `Failed to ${branch.is_active ? 'deactivate' : 'activate'} branch`;
			alert('Error: ' + errorMessage);
			console.error('Error toggling branch status:', error);
		} finally {
			isLoading = false;
		}
	}

	async function deleteBranch(id: string) {
		if (confirm('Are you sure you want to delete this branch?')) {
			isLoading = true;
			errorMessage = '';

			try {
				const { error } = await supabase
					.from('branches')
					.delete()
					.eq('id', id);
				
				if (error) {
					errorMessage = error.message || 'Failed to delete branch';
					alert('Error deleting branch: ' + errorMessage);
				} else {
					// Refresh the branches list
					await loadBranches();
				}
			} catch (error) {
				errorMessage = 'Failed to delete branch';
				alert('Error deleting branch: ' + errorMessage);
				console.error('Error deleting branch:', error);
			} finally {
				isLoading = false;
			}
		}
	}

	// Functions for approvers
	function openCreateApproverPopup() {
		currentApprover = {
			user_id: '',
			can_approve_leave_requests: true,
			visibility_type: 'global',
			assigned_branches: []
		};
		visibilityType = 'global';
		assignedBranches = [];
		showCreateApproverPopup = true;
	}

	function closeCreateApproverPopup() {
		showCreateApproverPopup = false;
		currentApprover = {
			user_id: '',
			can_approve_leave_requests: true,
			visibility_type: 'global',
			assigned_branches: []
		};
		visibilityType = 'global';
		assignedBranches = [];
	}

	function openEditApproverPopup(approver: any) {
		editingApproverId = approver.user_id;
		editingApprover = approver;
		currentApprover = { ...approver };
		visibilityType = approver.visibility_type || 'global';
		assignedBranches = approver.branch_access?.map((b: any) => b.branch_id) || [];
		showEditApproverPopup = true;
	}

	function closeEditApproverPopup() {
		showEditApproverPopup = false;
		editingApproverId = null;
		currentApprover = {
			user_id: '',
			can_approve_leave_requests: true,
			visibility_type: 'global',
			assigned_branches: []
		};
		visibilityType = 'global';
		assignedBranches = [];
	}

	async function saveApprover() {
		if (!currentApprover.user_id) {
			alert('Please select a user');
			return;
		}

		if (visibilityType !== 'global' && assignedBranches.length === 0) {
			alert(`Please select at least one branch for ${visibilityType === 'branch_specific' ? 'single' : 'multiple'} branch assignment`);
			return;
		}

		isLoading = true;
		errorMessage = '';

		try {
			if (editingApproverId) {
				// Update approver permissions
				const { error: updateError } = await supabase
					.from('approval_permissions')
					.update({
						can_approve_leave_requests: currentApprover.can_approve_leave_requests,
						is_active: currentApprover.is_active || true
					})
					.eq('user_id', editingApproverId);

				if (updateError) {
					errorMessage = updateError.message || 'Failed to update approver';
					alert('Error updating approver: ' + errorMessage);
					return;
				}

				// Update visibility config
				const { error: visError } = await supabase
					.from('approver_visibility_config')
					.upsert({
						user_id: editingApproverId,
						visibility_type: visibilityType,
						is_active: true
					}, {
						onConflict: 'user_id'
					});

				if (visError) {
					console.error('Error updating visibility config:', visError);
					alert('Error updating visibility config: ' + visError.message);
					return;
				}

				// Delete old branch access records and insert new ones
				if (visibilityType !== 'global') {
					// Delete existing records
					const { error: deleteError } = await supabase
						.from('approver_branch_access')
						.delete()
						.eq('user_id', editingApproverId);

					if (deleteError) {
						console.error('Error deleting old branch access:', deleteError);
					}

					// Insert new records
					const branchAccessRecords = assignedBranches.map((branchId: any) => ({
						user_id: editingApproverId,
						branch_id: branchId,
						is_active: true
					}));

					if (branchAccessRecords.length > 0) {
						const { error: insertError } = await supabase
							.from('approver_branch_access')
							.insert(branchAccessRecords);

						if (insertError) {
							console.error('Error inserting branch access:', insertError);
							alert('Error assigning branches: ' + insertError.message);
							return;
						}
					}
				}

				await loadApprovers();
				closeEditApproverPopup();
			} else {
				// Check if already exists
				const { data: existing } = await supabase
					.from('approval_permissions')
					.select('*')
					.eq('user_id', currentApprover.user_id)
					.single();

				if (existing) {
					errorMessage = 'User already has approval permissions';
					alert('Error: ' + errorMessage);
					return;
				}

				// Create approval permission record
				const { error: createError } = await supabase
					.from('approval_permissions')
					.insert([{
						user_id: currentApprover.user_id,
						can_approve_leave_requests: true,
						can_approve_requisitions: false,
						can_approve_single_bill: false,
						can_approve_multiple_bill: false,
						can_approve_recurring_bill: false,
						can_approve_vendor_payments: false,
						is_active: true
					}]);

				if (createError) {
					errorMessage = createError.message || 'Failed to create approver';
					alert('Error creating approver: ' + errorMessage);
					return;
				}

				// Create visibility config
				const { error: visError } = await supabase
					.from('approver_visibility_config')
					.insert({
						user_id: currentApprover.user_id,
						visibility_type: visibilityType,
						is_active: true
					});

				if (visError) {
					console.error('Error creating visibility config:', visError);
					alert('Error creating visibility config: ' + visError.message);
					return;
				}

				// Insert branch access if not global
				if (visibilityType !== 'global') {
					const branchAccessRecords = assignedBranches.map((branchId: any) => ({
						user_id: currentApprover.user_id,
						branch_id: branchId,
						is_active: true
					}));

					if (branchAccessRecords.length > 0) {
						const { error: insertError } = await supabase
							.from('approver_branch_access')
							.insert(branchAccessRecords);

						if (insertError) {
							console.error('Error inserting branch access:', insertError);
							alert('Error assigning branches: ' + insertError.message);
							return;
						}
					}
				}

				await loadApprovers();
				closeCreateApproverPopup();
			}
		} catch (error) {
			errorMessage = 'Failed to save approver';
			alert('Error saving approver: ' + errorMessage);
			console.error('Error saving approver:', error);
		} finally {
			isLoading = false;
		}
	}

	async function deleteApprover(userId: string) {
		if (confirm('Are you sure you want to remove this approver?')) {
			isLoading = true;
			errorMessage = '';

			try {
				// Delete branch access records
				const { error: accessError } = await supabase
					.from('approver_branch_access')
					.delete()
					.eq('user_id', userId);

				if (accessError) {
					console.error('Error deleting branch access:', accessError);
				}

				// Delete visibility config
				const { error: visError } = await supabase
					.from('approver_visibility_config')
					.delete()
					.eq('user_id', userId);

				if (visError) {
					console.error('Error deleting visibility config:', visError);
				}

				// Delete approval permissions (note: not hard delete, should set is_active = false)
				const { error } = await supabase
					.from('approval_permissions')
					.update({ is_active: false, can_approve_leave_requests: false })
					.eq('user_id', userId);
				
				if (error) {
					errorMessage = error.message || 'Failed to delete approver';
					alert('Error deleting approver: ' + errorMessage);
				} else {
					await loadApprovers();
				}
			} catch (error) {
				errorMessage = 'Failed to delete approver';
				alert('Error deleting approver: ' + errorMessage);
				console.error('Error deleting approver:', error);
			} finally {
				isLoading = false;
			}
		}
	}

	function formatDate(dateString: string) {
		return new Date(dateString).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}
</script>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans" dir={$locale === 'ar' ? 'rtl' : 'ltr'}>
	<!-- Header with Tab Navigation -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-end shadow-sm">
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner">
			<!-- Tab 1: Branches -->
			<button 
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
				{activeTab === 'branches' 
					? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]' 
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => activeTab = 'branches'}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">🏢</span>
				<span class="relative z-10">Branches</span>
				
				{#if activeTab === 'branches'}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>

			<!-- Tab 2: Default Approvers (Leaves) -->
			<button 
				class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
				{activeTab === 'approvers' 
					? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' 
					: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
				on:click={() => activeTab = 'approvers'}
			>
				<span class="text-base filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">✅</span>
				<span class="relative z-10">Default Approvers (Leaves)</span>
				
				{#if activeTab === 'approvers'}
					<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
				{/if}
			</button>
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-gradient-to-br from-white via-slate-50 to-slate-100">
		<!-- Decorative elements -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-emerald-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			<!-- BRANCHES TAB -->
			{#if activeTab === 'branches'}
				{#if isLoading && branches.length === 0}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">Loading branches...</p>
						</div>
					</div>
				{:else if errorMessage && activeTab === 'branches'}
					<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center mb-4">
						<p class="text-red-700 font-semibold">Error: {errorMessage}</p>
						<button 
							class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
							on:click={loadBranches}
						>
							Retry
						</button>
					</div>
				{/if}

				<!-- Branches Table Card -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
					<!-- Branches Header with Create Button -->
					<div class="bg-white border-b border-slate-100 px-8 py-6 flex items-center justify-between">
						<h2 class="text-2xl font-bold text-slate-800">🏢 Branches</h2>
						<button 
							class="flex items-center gap-2.5 px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-all duration-300 shadow-md hover:shadow-lg"
							on:click={openCreateBranchPopup}
							disabled={isLoading}
						>
							<span class="text-lg">+</span>
							Create Branch
						</button>
					</div>

					<!-- Branches Table -->
					<div class="overflow-x-auto flex-1">
						<table class="w-full text-sm">
							<thead class="bg-slate-50 border-b border-slate-200 sticky top-0">
								<tr>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Branch ID</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Name (EN)</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Name (AR)</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Location (EN)</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Location (AR)</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">VAT</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Status</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Main</th>
									<th class="px-6 py-4 text-center font-bold text-slate-700">Actions</th>
								</tr>
							</thead>
							<tbody>
								{#each branches as branch (branch.id)}
									<tr class="border-b border-slate-200 hover:bg-blue-50/50 transition">
										<td class="px-6 py-4 text-slate-700 font-mono text-xs">{branch.id}</td>
										<td class="px-6 py-4 text-slate-700 font-medium">{branch.name_en}</td>
										<td class="px-6 py-4 text-slate-700 font-medium text-right">{branch.name_ar}</td>
										<td class="px-6 py-4 text-slate-600">{branch.location_en}</td>
										<td class="px-6 py-4 text-slate-600 text-right">{branch.location_ar}</td>
										<td class="px-6 py-4">
											{#if branch.vat_number}
												<span class="inline-block px-3 py-1 bg-amber-100 text-amber-800 rounded-full text-xs font-semibold">{branch.vat_number}</span>
											{:else}
												<span class="text-slate-400">—</span>
											{/if}
										</td>
										<td class="px-6 py-4">
											<span class="inline-block px-3 py-1 rounded-full text-xs font-bold
											{branch.is_active 
												? 'bg-emerald-100 text-emerald-800' 
												: 'bg-red-100 text-red-800'}">
												{branch.is_active ? '✓ Active' : '✗ Inactive'}
											</span>
										</td>
										<td class="px-6 py-4">
											{#if branch.is_main_branch}
												<span class="text-lg">⭐</span>
											{:else}
												<span class="text-slate-400">—</span>
											{/if}
										</td>
										<td class="px-6 py-4">
											<div class="flex gap-2 justify-center">
												<button 
													class="px-2.5 py-1.5 rounded text-xs font-bold transition {branch.is_active ? 'bg-orange-100 text-orange-700 hover:bg-orange-200' : 'bg-green-100 text-green-700 hover:bg-green-200'}"
													on:click={() => toggleBranchActive(branch)}
													disabled={isLoading}
												>
													{branch.is_active ? 'Deactivate' : 'Activate'}
												</button>
												<button 
													class="px-2.5 py-1.5 rounded text-xs font-bold bg-blue-100 text-blue-700 hover:bg-blue-200 transition"
													on:click={() => openEditBranchPopup(branch)}
													disabled={isLoading}
												>
													Edit
												</button>
												<button 
													class="px-2.5 py-1.5 rounded text-xs font-bold bg-red-100 text-red-700 hover:bg-red-200 transition"
													on:click={() => deleteBranch(branch.id)}
													disabled={isLoading}
												>
													Delete
												</button>
											</div>
										</td>
									</tr>
								{/each}
								{#if branches.length === 0 && !isLoading}
									<tr>
										<td colspan="9" class="px-6 py-12 text-center">
											<div class="text-slate-400 font-semibold text-lg">📭 No branches found</div>
										</td>
									</tr>
								{/if}
							</tbody>
						</table>
					</div>
				</div>
			{/if}

			<!-- APPROVERS TAB -->
			{#if activeTab === 'approvers'}
				{#if isLoading && approvers.length === 0}
					<div class="flex items-center justify-center h-full">
						<div class="text-center">
							<div class="animate-spin inline-block">
								<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
							</div>
							<p class="mt-4 text-slate-600 font-semibold">Loading approvers...</p>
						</div>
					</div>
				{:else if errorMessage && activeTab === 'approvers'}
					<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center mb-4">
						<p class="text-red-700 font-semibold">Error: {errorMessage}</p>
						<button 
							class="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
							on:click={loadApprovers}
						>
							Retry
						</button>
					</div>
				{/if}

				<!-- Approvers Table Card -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
					<!-- Approvers Header with Create Button -->
					<div class="bg-white border-b border-slate-100 px-8 py-6 flex items-center justify-between">
						<h2 class="text-2xl font-bold text-slate-800">✅ Default Approvers (Leaves)</h2>
						<button 
							class="flex items-center gap-2.5 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg font-semibold transition-all duration-300 shadow-md hover:shadow-lg"
							on:click={openCreateApproverPopup}
							disabled={isLoading}
						>
							<span class="text-lg">+</span>
							Add Approver
						</button>
					</div>

					<!-- Approvers Table -->
					<div class="overflow-x-auto flex-1">
						<table class="w-full text-sm">
							<thead class="bg-slate-50 border-b border-slate-200 sticky top-0">
								<tr>
									<th class="px-6 py-4 text-left font-bold text-slate-700">User</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Can Approve Leaves</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Visibility</th>
									<th class="px-6 py-4 text-left font-bold text-slate-700">Status</th>
									<th class="px-6 py-4 text-center font-bold text-slate-700">Actions</th>
								</tr>
							</thead>
							<tbody>
								{#each approvers as approver (approver.user_id)}
									<tr class="border-b border-slate-200 hover:bg-emerald-50/50 transition">
										<td class="px-6 py-4 text-slate-700 font-medium">{approver.username}</td>
										<td class="px-6 py-4">
											<span class="inline-block px-3 py-1 {approver.can_approve_leave_requests ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-600'} rounded-full text-xs font-bold">
												{approver.can_approve_leave_requests ? '✓ Yes' : '✗ No'}
											</span>
										</td>
										<td class="px-6 py-4">
											{#if approver.visibility_type === 'global'}
												<span class="inline-block px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-xs font-bold">
													🌍 Global
												</span>
											{:else if approver.visibility_type === 'branch_specific' && approver.branch_access.length > 0}
												<span class="inline-block px-3 py-1 bg-orange-100 text-orange-800 rounded-full text-xs font-bold">
													🏢 {approver.branch_access[0]?.branch_id}
												</span>
											{:else if approver.visibility_type === 'multiple_branches' && approver.branch_access.length > 0}
												<span class="inline-block px-3 py-1 bg-purple-100 text-purple-800 rounded-full text-xs font-bold">
													📊 {approver.branch_access.length} Branches
												</span>
											{:else}
												<span class="inline-block px-3 py-1 bg-slate-100 text-slate-600 rounded-full text-xs font-bold">
													— None
												</span>
											{/if}
										</td>
										<td class="px-6 py-4">
											<span class="inline-block px-3 py-1 {approver.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'} rounded-full text-xs font-bold">
												{approver.is_active ? '🟢 Active' : '🔴 Inactive'}
											</span>
										</td>
										<td class="px-6 py-4">
											<div class="flex gap-2 justify-center">
												<button 
													class="px-2.5 py-1.5 rounded text-xs font-bold bg-blue-100 text-blue-700 hover:bg-blue-200 transition"
													on:click={() => openEditApproverPopup(approver)}
													disabled={isLoading}
												>
													Edit
												</button>
												<button 
													class="px-2.5 py-1.5 rounded text-xs font-bold bg-red-100 text-red-700 hover:bg-red-200 transition"
													on:click={() => deleteApprover(approver.user_id)}
													disabled={isLoading}
												>
													Remove
												</button>
											</div>
										</td>
									</tr>
								{/each}
								{#if approvers.length === 0 && !isLoading}
									<tr>
										<td colspan="5" class="px-6 py-12 text-center">
											<div class="text-slate-400 font-semibold text-lg">👤 No approvers configured</div>
										</td>
									</tr>
								{/if}
							</tbody>
						</table>
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- CREATE/EDIT BRANCH POPUPS -->
{#if showCreateBranchPopup}
	<div class="popup-overlay" role="presentation" on:click={closeCreateBranchPopup} on:keydown={() => {}}>
		<div class="popup" role="dialog" aria-labelledby="create-branch-title" tabindex="-1" on:click|stopPropagation={() => {}} on:keydown={(e) => e.key === 'Escape' && closeCreateBranchPopup()}>
			<div class="popup-header">
				<h2 id="create-branch-title">Create Branch</h2>
				<button class="close-btn" on:click={closeCreateBranchPopup}>×</button>
			</div>
			
			<div class="popup-content">
				<form on:submit|preventDefault={saveBranch}>
					<div class="form-row">
						<div class="form-group">
							<label for="name-en">Name (English)</label>
							<input
								id="name-en"
								type="text"
								bind:value={currentBranch.name_en}
								placeholder="Enter branch name in English"
								required
							/>
						</div>
						<div class="form-group">
							<label for="name-ar">Name (Arabic)</label>
							<input
								id="name-ar"
								type="text"
								bind:value={currentBranch.name_ar}
								placeholder="أدخل اسم الفرع بالعربية"
								class="arabic"
								dir="rtl"
								required
							/>
						</div>
					</div>
					
					<div class="form-row">
						<div class="form-group">
							<label for="location-en">Location (English)</label>
							<input
								id="location-en"
								type="text"
								bind:value={currentBranch.location_en}
								placeholder="Enter location in English"
								required
							/>
						</div>
						<div class="form-group">
							<label for="location-ar">Location (Arabic)</label>
							<input
								id="location-ar"
								type="text"
								bind:value={currentBranch.location_ar}
								placeholder="أدخل الموقع بالعربية"
								class="arabic"
								dir="rtl"
								required
							/>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="vat-number-create">VAT Number (Optional)</label>
							<input
								id="vat-number-create"
								type="text"
								bind:value={currentBranch.vat_number}
								placeholder="Enter VAT registration number"
							/>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={currentBranch.is_active} />
								Active
							</label>
						</div>
						<div class="form-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={currentBranch.is_main_branch} />
								Main Branch
							</label>
						</div>
					</div>
					
					<div class="form-actions">
						<button type="button" class="cancel-btn" on:click={closeCreateBranchPopup}>
							Cancel
						</button>
						<button type="submit" class="save-btn">
							Save
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

{#if showEditBranchPopup}
	<div class="popup-overlay" role="presentation" on:click={closeEditBranchPopup} on:keydown={() => {}}>
		<div class="popup" role="dialog" aria-labelledby="edit-branch-title" tabindex="-1" on:click|stopPropagation={() => {}} on:keydown={(e) => e.key === 'Escape' && closeEditBranchPopup()}>
			<div class="popup-header">
				<h2 id="edit-branch-title">Edit Branch</h2>
				<button class="close-btn" on:click={closeEditBranchPopup}>×</button>
			</div>
			
			<div class="popup-content">
				<form on:submit|preventDefault={saveBranch}>
					<div class="form-row">
						<div class="form-group">
							<label for="edit-name-en">Name (English)</label>
							<input
								id="edit-name-en"
								type="text"
								bind:value={currentBranch.name_en}
								placeholder="Enter branch name in English"
								required
							/>
						</div>
						<div class="form-group">
							<label for="edit-name-ar">Name (Arabic)</label>
							<input
								id="edit-name-ar"
								type="text"
								bind:value={currentBranch.name_ar}
								placeholder="أدخل اسم الفرع بالعربية"
								class="arabic"
								dir="rtl"
								required
							/>
						</div>
					</div>
					
					<div class="form-row">
						<div class="form-group">
							<label for="edit-location-en">Location (English)</label>
							<input
								id="edit-location-en"
								type="text"
								bind:value={currentBranch.location_en}
								placeholder="Enter location in English"
								required
							/>
						</div>
						<div class="form-group">
							<label for="edit-location-ar">Location (Arabic)</label>
							<input
								id="edit-location-ar"
								type="text"
								bind:value={currentBranch.location_ar}
								placeholder="أدخل الموقع بالعربية"
								class="arabic"
								dir="rtl"
								required
							/>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label for="vat-number-edit">VAT Number (Optional)</label>
							<input
								id="vat-number-edit"
								type="text"
								bind:value={currentBranch.vat_number}
								placeholder="Enter VAT registration number"
							/>
						</div>
					</div>

					<div class="form-row">
						<div class="form-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={currentBranch.is_active} />
								Active
							</label>
						</div>
						<div class="form-group">
							<label class="checkbox-label">
								<input type="checkbox" bind:checked={currentBranch.is_main_branch} />
								Main Branch
							</label>
						</div>
					</div>
					
					<div class="form-actions">
						<button type="button" class="cancel-btn" on:click={closeEditBranchPopup}>
							Cancel
						</button>
						<button type="submit" class="save-btn">
							Update
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

<!-- CREATE APPROVER POPUP -->
{#if showCreateApproverPopup}
	<div class="popup-overlay" role="presentation" on:click={closeCreateApproverPopup} on:keydown={() => {}}>
		<div class="popup" role="dialog" aria-labelledby="create-approver-title" tabindex="-1" on:click|stopPropagation={() => {}} on:keydown={(e) => e.key === 'Escape' && closeCreateApproverPopup()}>
			<div class="popup-header">
				<h2 id="create-approver-title">✅ Add Default Approver (Leaves)</h2>
				<button class="close-btn" on:click={closeCreateApproverPopup}>×</button>
			</div>
			
			<div class="popup-content">
				<form on:submit|preventDefault={saveApprover}>
					<div class="form-group">
						<label for="user-select">Select User</label>
						<select
							id="user-select"
							bind:value={currentApprover.user_id}
							required
							style="padding: 12px; border: 1px solid #d1d5db; border-radius: 6px; font-size: 14px;"
						>
							<option value="">-- Choose a user --</option>
							{#each allUsers as user (user.id)}
								<option value={user.id}>
									{user.username}
								</option>
							{/each}
						</select>
					</div>

					<div class="form-group">
						<label class="checkbox-label">
							<input type="checkbox" bind:checked={currentApprover.can_approve_leave_requests} />
							Can Approve Leave Requests
						</label>
					</div>

					<div class="form-group">
						<label class="checkbox-label">
							<input type="checkbox" bind:checked={currentApprover.is_active} />
							Active
						</label>
					</div>

					<!-- Visibility Configuration Section -->
					<div style="border-top: 2px solid #e5e7eb; padding-top: 16px; margin-top: 16px;">
					<div style="display: block; margin-bottom: 12px; font-weight: 600; color: #374151;">
						📊 Visibility Scope (Who can see requests?)
					</div>

					<div class="form-group">
						<label class="checkbox-label">
							<input 
								type="radio" 
								name="visibility" 
								value="global" 
								bind:group={visibilityType}
								on:change={() => assignedBranches = []}
							/>
							🌍 Global (See requests from all branches)
						</label>
					</div>

					<div class="form-group">
						<label class="checkbox-label">
							<input 
								type="radio" 
								name="visibility" 
								value="branch_specific"
								bind:group={visibilityType}
							/>
							🏢 Single Branch (Select one branch only)
						</label>
					</div>

					<div class="form-group">
						<label class="checkbox-label">
							<input 
								type="radio" 
								name="visibility" 
								value="multiple_branches"
								bind:group={visibilityType}
							/>
							📊 Multiple Branches (Select multiple branches)
						</label>
					</div>

					{#if visibilityType !== 'global'}
						<div style="margin-top: 16px; padding: 12px; background-color: #f3f4f6; border-radius: 8px;">
							<div style="display: block; margin-bottom: 8px; font-weight: 500; color: #374151;">
								{visibilityType === 'branch_specific' ? 'Select Branch:' : 'Select Branches:'}
							</div>
							<div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 8px;">
								{#each branches as branch (branch.id)}
									<label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
										<input 
											type="checkbox" 
											value={branch.id}
											checked={assignedBranches.includes(branch.id)}
											on:change={(e) => {
												if (e.target.checked) {
													if (visibilityType === 'branch_specific') {
														assignedBranches = [branch.id];
													} else {
														assignedBranches = [...assignedBranches, branch.id];
													}
												} else {
													assignedBranches = assignedBranches.filter(b => b !== branch.id);
												}
											}}
										/>
										<span style="font-size: 13px; color: #374151;">{branch.name_en}</span>
									</label>
								{/each}
							</div>
						</div>
					{/if}
					
					<div class="form-actions">
						<button type="button" class="cancel-btn" on:click={closeCreateApproverPopup}>
							Cancel
						</button>
						<button type="submit" class="save-btn">
							Add Approver
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

<!-- EDIT APPROVER POPUP -->
{#if showEditApproverPopup}
	<div class="popup-overlay" role="presentation" on:click={closeEditApproverPopup} on:keydown={() => {}}>
		<div class="popup" role="dialog" aria-labelledby="edit-approver-title" tabindex="-1" on:click|stopPropagation={() => {}} on:keydown={(e) => e.key === 'Escape' && closeEditApproverPopup()}>
			<div class="popup-header">
				<h2 id="edit-approver-title">✅ Edit Approver</h2>
				<button class="close-btn" on:click={closeEditApproverPopup}>×</button>
			</div>
			
			<div class="popup-content">
				<form on:submit|preventDefault={saveApprover}>
					<div class="form-group">
						<label for="edit-user">User</label>
						<input
							id="edit-user"
							type="text"
							value={editingApprover?.username || ''}
							disabled
							style="background-color: #f3f4f6; cursor: not-allowed;"
						/>
					</div>

					<div class="form-group">
						<label class="checkbox-label">
							<input type="checkbox" bind:checked={currentApprover.can_approve_leave_requests} />
							Can Approve Leave Requests
						</label>
					</div>

					<div class="form-group">
						<label class="checkbox-label">
							<input type="checkbox" bind:checked={currentApprover.is_active} />
							Active
						</label>
					</div>

					<!-- Visibility Configuration Section -->
					<div style="border-top: 2px solid #e5e7eb; padding-top: 16px; margin-top: 16px;">
						<div style="display: block; margin-bottom: 12px; font-weight: 600; color: #374151;">
							📊 Visibility Scope (Who can see requests?)
						</div>

						<div class="form-group">
							<label class="checkbox-label">
								<input 
									type="radio" 
									name="edit-visibility" 
									value="global" 
									bind:group={visibilityType}
									on:change={() => assignedBranches = []}
								/>
								🌍 Global (See requests from all branches)
							</label>
						</div>

						<div class="form-group">
							<label class="checkbox-label">
								<input 
									type="radio" 
									name="edit-visibility" 
									value="branch_specific"
									bind:group={visibilityType}
								/>
								🏢 Single Branch (Select one branch only)
							</label>
						</div>

						<div class="form-group">
							<label class="checkbox-label">
								<input 
									type="radio" 
									name="edit-visibility" 
									value="multiple_branches"
									bind:group={visibilityType}
								/>
								📊 Multiple Branches (Select multiple branches)
							</label>
						</div>

						{#if visibilityType !== 'global'}
							<div style="margin-top: 16px; padding: 12px; background-color: #f3f4f6; border-radius: 8px;">
								<div style="display: block; margin-bottom: 8px; font-weight: 500; color: #374151;">
									{visibilityType === 'branch_specific' ? 'Select Branch:' : 'Select Branches:'}
								</div>
								<div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 8px;">
									{#each branches as branch (branch.id)}
										<label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
											<input 
												type="checkbox" 
												value={branch.id}
												checked={assignedBranches.includes(branch.id)}
												on:change={(e) => {
													const target = e.target as HTMLInputElement;
													if (target.checked) {
														if (visibilityType === 'branch_specific') {
															assignedBranches = [branch.id];
														} else {
															assignedBranches = [...assignedBranches, branch.id];
														}
													} else {
														assignedBranches = assignedBranches.filter(b => b !== branch.id);
													}
												}}
											/>
											<span style="font-size: 13px; color: #374151;">{branch.name_en}</span>
										</label>
									{/each}
								</div>
							</div>
						{/if}
					</div>
					
					<div class="form-actions">
						<button type="button" class="cancel-btn" on:click={closeEditApproverPopup}>
							Cancel
						</button>
						<button type="submit" class="save-btn">
							Update Approver
						</button>
					</div>
				</form>
			</div>
		</div>
	</div>
{/if}

<style>
	.branch-master {
		padding: 24px;
		height: 100%;
		display: flex;
		flex-direction: column;
		background: white;
		gap: 24px;
	}

	.header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding-bottom: 16px;
		border-bottom: 1px solid #e5e7eb;
	}

	.title {
		font-size: 24px;
		font-weight: 600;
		color: #111827;
		margin: 0;
	}

	.create-btn {
		background: #10b981;
		color: white;
		border: none;
		border-radius: 8px;
		padding: 12px 20px;
		font-weight: 500;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 8px;
		transition: all 0.2s;
	}

	.create-btn:hover {
		background: #059669;
		transform: translateY(-1px);
	}

	.create-btn .icon {
		font-size: 18px;
		font-weight: bold;
	}

	.table-container {
		flex: 1;
		overflow: auto;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
	}

	.branches-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.branches-table th {
		background: #f9fafb;
		padding: 12px 16px;
		text-align: left;
		font-weight: 600;
		color: #374151;
		border-bottom: 1px solid #e5e7eb;
		white-space: nowrap;
	}

	.branches-table td {
		padding: 12px 16px;
		border-bottom: 1px solid #f3f4f6;
		color: #111827;
	}

	.branches-table tr:hover {
		background: #f9fafb;
	}

	.branches-table tr.inactive {
		opacity: 0.6;
	}

	.arabic {
		font-family: 'Tajawal', 'Cairo', Arial, sans-serif;
		direction: rtl;
		text-align: right;
	}

	.status-badge {
		padding: 4px 12px;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 500;
		text-transform: uppercase;
	}

	.status-badge.active {
		background: #d1fae5;
		color: #065f46;
	}

	.status-badge.inactive {
		background: #fee2e2;
		color: #991b1b;
	}

	.main-branch-badge {
		background: #dbeafe;
		color: #1d4ed8;
		padding: 4px 8px;
		border-radius: 4px;
		font-weight: 500;
	}

	.actions {
		display: flex;
		gap: 8px;
	}

	.edit-btn, .delete-btn {
		padding: 6px 12px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
	}

	.edit-btn {
		background: #eff6ff;
		color: #1d4ed8;
		border-color: #3b82f6;
	}

	.edit-btn:hover {
		background: #dbeafe;
	}

	.delete-btn {
		background: #fef2f2;
		color: #dc2626;
		border-color: #ef4444;
	}

	.delete-btn:hover {
		background: #fee2e2;
	}

	.toggle-btn {
		padding: 6px 12px;
		border-radius: 4px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
	}

	.toggle-btn.active {
		background: #fef3c7;
		color: #92400e;
		border-color: #fcd34d;
	}

	.toggle-btn.active:hover {
		background: #fde68a;
	}

	.toggle-btn.inactive {
		background: #d1fae5;
		color: #065f46;
		border-color: #6ee7b7;
	}

	.toggle-btn.inactive:hover {
		background: #a7f3d0;
	}

	.empty-state {
		padding: 48px;
		text-align: center;
		color: #6b7280;
	}

	.empty-state .create-btn {
		margin-top: 16px;
		background: #3b82f6;
	}

	.empty-state .create-btn:hover {
		background: #2563eb;
	}

	/* Loading and Error States */
	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 48px;
		color: #6b7280;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f4f6;
		border-top: 4px solid #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin-bottom: 16px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.error-message {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #dc2626;
		padding: 12px 16px;
		border-radius: 8px;
		margin-bottom: 16px;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.retry-btn {
		background: #dc2626;
		color: white;
		border: none;
		border-radius: 4px;
		padding: 6px 12px;
		font-size: 12px;
		cursor: pointer;
		font-weight: 500;
	}

	.retry-btn:hover {
		background: #b91c1c;
	}

	button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	/* Popup Styles */
	.popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.popup {
		background: white;
		border-radius: 12px;
		box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
		max-width: 600px;
		width: 90%;
		max-height: 90vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.popup-header {
		padding: 20px 24px;
		border-bottom: 1px solid #e5e7eb;
		display: flex;
		justify-content: space-between;
		align-items: center;
		background: #f9fafb;
	}

	.popup-header h2 {
		margin: 0;
		font-size: 18px;
		font-weight: 600;
		color: #111827;
	}

	.close-btn {
		background: none;
		border: none;
		font-size: 24px;
		color: #6b7280;
		cursor: pointer;
		padding: 0;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 4px;
	}

	.close-btn:hover {
		background: #f3f4f6;
		color: #374151;
	}

	.popup-content {
		padding: 24px;
		flex: 1;
		overflow-y: auto;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin-bottom: 16px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
	}

	.form-group label {
		margin-bottom: 6px;
		font-weight: 500;
		color: #374151;
	}

	.form-group input {
		padding: 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s;
	}

	.form-group input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-group select {
		padding: 12px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 14px;
		transition: border-color 0.2s;
		background-color: white;
		cursor: pointer;
	}

	.form-group select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.checkbox-label {
		display: flex !important;
		flex-direction: row !important;
		align-items: center;
		gap: 8px;
		margin-top: 8px;
	}

	.checkbox-label input {
		width: auto;
		margin: 0;
	}

	.form-actions {
		display: flex;
		justify-content: flex-end;
		gap: 12px;
		padding-top: 20px;
		border-top: 1px solid #e5e7eb;
		margin-top: 20px;
	}

	.cancel-btn, .save-btn {
		padding: 12px 20px;
		border-radius: 6px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid;
		transition: all 0.2s;
	}

	.cancel-btn {
		background: white;
		color: #6b7280;
		border-color: #d1d5db;
	}

	.cancel-btn:hover {
		background: #f9fafb;
	}

	.save-btn {
		background: #10b981;
		color: white;
		border-color: #10b981;
	}

	.save-btn:hover {
		background: #059669;
	}

	@media (max-width: 768px) {
		.form-row {
			grid-template-columns: 1fr;
		}
		
		.popup {
			width: 95%;
			margin: 20px;
		}
		
		.branches-table {
			font-size: 12px;
		}
		
		.branches-table th,
		.branches-table td {
			padding: 8px 12px;
		}
	}

	/* VAT Number Styles */
	.vat-number {
		text-align: center;
	}

	.vat-badge {
		background-color: #eff6ff;
		color: #1d4ed8;
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		border: 1px solid #bfdbfe;
		font-family: monospace;
		font-weight: 600;
		font-size: 0.875rem;
	}

	.no-vat {
		color: #9ca3af;
		font-style: italic;
	}
</style>
