<script>
	import { onMount } from 'svelte';
	import { componentDiscovery, discoverAndSyncComponents, getComponentStructure, analyzeLocalComponents } from '$lib/utils/componentDiscovery.js';
	
	let localComponents = null;
	let isAnalyzing = false;
	let showDetails = false;
	let selectedCategory = 'all';
	
	onMount(() => {
		analyzeComponents();
	});
	
	async function analyzeComponents() {
		isAnalyzing = true;
		try {
			localComponents = getComponentStructure();
		} catch (error) {
			console.error('Error analyzing components:', error);
		} finally {
			isAnalyzing = false;
		}
	}
	
	async function syncToDatabase() {
		try {
			await discoverAndSyncComponents();
			// Show success message
		} catch (error) {
			console.error('Error syncing to database:', error);
		}
	}
	
	function getFilteredComponents() {
		if (!localComponents) return [];
		if (selectedCategory === 'all') {
			return Object.values(localComponents.categories).flat();
		}
		return localComponents.categories[selectedCategory] || [];
	}
</script>

<div class="p-6 bg-white rounded-lg shadow-sm">
	<div class="flex items-center justify-between mb-6">
		<div>
			<h2 class="text-xl font-semibold text-gray-900">App Functions Discovery</h2>
			<p class="text-sm text-gray-600 mt-1">
				Automatically discover and register application functions from component structure
			</p>
		</div>
		<div class="flex gap-3">
			<button
				on:click={analyzeComponents}
				disabled={isAnalyzing}
				class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
			>
				{#if isAnalyzing}
					<svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					Analyzing...
				{:else}
					🔍 Analyze Components
				{/if}
			</button>
			
			<button
				on:click={syncToDatabase}
				disabled={!localComponents || $componentDiscovery.isDiscovering}
				class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
			>
				{#if $componentDiscovery.isDiscovering}
					<svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					Syncing...
				{:else}
					🔄 Sync to Database
				{/if}
			</button>
		</div>
	</div>

	{#if localComponents}
		<!-- Summary Statistics -->
		<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
			<div class="bg-blue-50 p-4 rounded-lg">
				<div class="text-2xl font-bold text-blue-700">{localComponents.totalCount}</div>
				<div class="text-sm text-blue-600">Total Functions</div>
			</div>
			<div class="bg-green-50 p-4 rounded-lg">
				<div class="text-2xl font-bold text-green-700">{Object.keys(localComponents.categories).length}</div>
				<div class="text-sm text-green-600">Categories</div>
			</div>
			<div class="bg-purple-50 p-4 rounded-lg">
				<div class="text-2xl font-bold text-purple-700">{localComponents.summary['HR'] || 0}</div>
				<div class="text-sm text-purple-600">HR Functions</div>
			</div>
			<div class="bg-orange-50 p-4 rounded-lg">
				<div class="text-2xl font-bold text-orange-700">{localComponents.summary['Administration'] || 0}</div>
				<div class="text-sm text-orange-600">Admin Functions</div>
			</div>
		</div>

		<!-- Category Filter -->
		<div class="mb-4">
			<div class="flex flex-wrap gap-2">
				<button
					on:click={() => selectedCategory = 'all'}
					class={`px-3 py-1 text-sm rounded-full transition-colors ${
						selectedCategory === 'all' 
							? 'bg-blue-100 text-blue-700 border-blue-200' 
							: 'bg-gray-100 text-gray-600 hover:bg-gray-200'
					} border`}
				>
					All ({localComponents.totalCount})
				</button>
				{#each Object.entries(localComponents.categories) as [category, functions]}
					<button
						on:click={() => selectedCategory = category}
						class={`px-3 py-1 text-sm rounded-full transition-colors ${
							selectedCategory === category 
								? 'bg-blue-100 text-blue-700 border-blue-200' 
								: 'bg-gray-100 text-gray-600 hover:bg-gray-200'
						} border`}
					>
						{category} ({functions.length})
					</button>
				{/each}
			</div>
		</div>

		<!-- Functions List -->
		<div class="border rounded-lg overflow-hidden">
			<table class="w-full">
				<thead class="bg-gray-50">
					<tr>
						<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Function Name</th>
						<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Code</th>
						<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Category</th>
						<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Description</th>
						<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
					</tr>
				</thead>
				<tbody class="bg-white divide-y divide-gray-200">
					{#each getFilteredComponents() as func}
						<tr class="hover:bg-gray-50">
							<td class="px-4 py-3">
								<div class="font-medium text-gray-900">{func.name}</div>
							</td>
							<td class="px-4 py-3">
								<code class="text-xs bg-gray-100 px-2 py-1 rounded">{func.code}</code>
							</td>
							<td class="px-4 py-3">
								<span class={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
									func.category === 'HR' ? 'bg-purple-100 text-purple-800' :
									func.category === 'Administration' ? 'bg-blue-100 text-blue-800' :
									func.category === 'Master Data' ? 'bg-green-100 text-green-800' :
									func.category === 'Operations' ? 'bg-orange-100 text-orange-800' :
									func.category === 'Reporting' ? 'bg-yellow-100 text-yellow-800' :
									'bg-gray-100 text-gray-800'
								}`}>
									{func.category}
								</span>
							</td>
							<td class="px-4 py-3 text-sm text-gray-600">
								{func.description}
							</td>
							<td class="px-4 py-3">
								<span class="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
									🔍 Discovered
								</span>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>

		<!-- Instructions -->
		<div class="mt-6 p-4 bg-blue-50 rounded-lg">
			<h3 class="text-sm font-medium text-blue-900 mb-2">How App Functions Discovery Works:</h3>
			<ul class="text-sm text-blue-800 space-y-1">
				<li>• <strong>Analyze Components:</strong> Scans the Svelte component structure to identify functional modules</li>
				<li>• <strong>Auto-Detection:</strong> Discovers functions from dashboard buttons, component names, and navigation structure</li>
				<li>• <strong>Sync to Database:</strong> Registers discovered functions in the app_functions table for permissions management</li>
				<li>• <strong>Dynamic Updates:</strong> New components are automatically detected when added to the application</li>
			</ul>
		</div>
	{:else}
		<div class="text-center py-8">
			<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
			</svg>
			<h3 class="mt-4 text-lg font-medium text-gray-900">Component Analysis</h3>
			<p class="mt-2 text-sm text-gray-500">
				Click "Analyze Components" to discover app functions from your Svelte application structure.
			</p>
		</div>
	{/if}
</div>

<style>
	/* Add any custom styles if needed */
</style>