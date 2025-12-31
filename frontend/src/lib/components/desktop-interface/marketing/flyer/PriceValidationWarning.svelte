<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	
	export let priceIssues: PriceIssue[] = [];
	
	interface PriceIssue {
		groupName: string;
		variations: {
			barcode: string;
			name: string;
			offerPrice: number | null;
		}[];
	}
	
	const dispatch = createEventDispatcher();
	
	let selectedAction: 'continue' | 'fix' | 'remove' = 'fix';
	let uniformPrice: number | null = null;
	
	// Calculate recommended price (most common or average)
	$: {
		if (priceIssues.length > 0 && priceIssues[0].variations.length > 0) {
			const prices = priceIssues[0].variations
				.map(v => v.offerPrice)
				.filter(p => p !== null) as number[];
			
			if (prices.length > 0) {
				// Use the most common price
				const priceMap = new Map<number, number>();
				prices.forEach(p => {
					priceMap.set(p, (priceMap.get(p) || 0) + 1);
				});
				
				let maxCount = 0;
				let mostCommonPrice = prices[0];
				priceMap.forEach((count, price) => {
					if (count > maxCount) {
						maxCount = count;
						mostCommonPrice = price;
					}
				});
				
				uniformPrice = mostCommonPrice;
			}
		}
	}
	
	function handleContinueAnyway() {
		dispatch('continue');
	}
	
	function handleSetUniformPrice() {
		if (uniformPrice === null) {
			alert('Please enter a valid price');
			return;
		}
		dispatch('setUniformPrice', { price: uniformPrice });
	}
	
	function handleRemoveMismatches() {
		dispatch('removeMismatches');
	}
	
	function cancel() {
		dispatch('cancel');
	}
</script>

<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
	<div class="bg-white rounded-xl shadow-2xl max-w-3xl w-full max-h-[90vh] overflow-hidden flex flex-col">
		<!-- Header -->
		<div class="bg-gradient-to-r from-yellow-500 to-orange-500 p-6 text-white">
			<div class="flex items-center gap-3">
				<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
				</svg>
				<div>
					<h2 class="text-2xl font-bold">Price Validation Warning</h2>
					<p class="text-yellow-100 text-sm mt-1">Some variation groups have inconsistent offer prices</p>
				</div>
			</div>
		</div>
		
		<!-- Content -->
		<div class="flex-1 overflow-y-auto p-6">
			<div class="space-y-6">
				{#each priceIssues as issue, idx (idx)}
					<div class="border-2 border-yellow-300 rounded-lg p-4 bg-yellow-50">
						<h3 class="font-bold text-lg text-gray-800 mb-3 flex items-center gap-2">
							<svg class="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
							</svg>
							{issue.groupName}
						</h3>
						
						<div class="space-y-2">
							{#each issue.variations as variation (variation.barcode)}
								<div class="flex items-center justify-between bg-white p-3 rounded border border-yellow-200">
									<div class="flex-1">
										<p class="font-semibold text-gray-800">{variation.name}</p>
										<p class="text-xs text-gray-500 font-mono">{variation.barcode}</p>
									</div>
									<div class="text-right">
										<p class="text-lg font-bold" class:text-red-600={variation.offerPrice === null}>
											{variation.offerPrice !== null ? `${variation.offerPrice.toFixed(2)} SAR` : 'No Price Set'}
										</p>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/each}
			</div>
			
			<!-- Action Selection -->
			<div class="mt-6 p-4 bg-blue-50 rounded-lg border-2 border-blue-200">
				<h4 class="font-bold text-gray-800 mb-4">How would you like to proceed?</h4>
				
				<div class="space-y-3">
					<!-- Option 1: Set Uniform Price -->
					<label class="flex items-start gap-3 p-3 rounded-lg border-2 cursor-pointer hover:bg-blue-100 transition-colors" class:bg-blue-100={selectedAction === 'fix'} class:border-blue-500={selectedAction === 'fix'}>
						<input type="radio" bind:group={selectedAction} value="fix" class="mt-1">
						<div class="flex-1">
							<p class="font-semibold text-gray-800">Set Uniform Price</p>
							<p class="text-sm text-gray-600 mb-2">Apply the same offer price to all variations in the group</p>
							{#if selectedAction === 'fix'}
								<div class="flex items-center gap-2 mt-2">
									<label class="text-sm font-medium text-gray-700">Price (SAR):</label>
									<input 
										type="number" 
										bind:value={uniformPrice}
										step="0.01"
										min="0"
										class="px-3 py-2 border-2 border-blue-300 rounded-lg focus:border-blue-500 focus:ring-2 focus:ring-blue-200 outline-none"
										placeholder="0.00"
									/>
								</div>
							{/if}
						</div>
					</label>
					
					<!-- Option 2: Remove Mismatches -->
					<label class="flex items-start gap-3 p-3 rounded-lg border-2 cursor-pointer hover:bg-yellow-100 transition-colors" class:bg-yellow-100={selectedAction === 'remove'} class:border-yellow-500={selectedAction === 'remove'}>
						<input type="radio" bind:group={selectedAction} value="remove" class="mt-1">
						<div class="flex-1">
							<p class="font-semibold text-gray-800">Remove Products with Different Prices</p>
							<p class="text-sm text-gray-600">Keep only variations with the most common price and remove others from the offer</p>
						</div>
					</label>
					
					<!-- Option 3: Continue Anyway -->
					<label class="flex items-start gap-3 p-3 rounded-lg border-2 cursor-pointer hover:bg-red-100 transition-colors" class:bg-red-100={selectedAction === 'continue'} class:border-red-500={selectedAction === 'continue'}>
						<input type="radio" bind:group={selectedAction} value="continue" class="mt-1">
						<div class="flex-1">
							<p class="font-semibold text-gray-800">Continue Anyway</p>
							<p class="text-sm text-gray-600">Proceed with different prices (not recommended - may confuse customers)</p>
						</div>
					</label>
				</div>
			</div>
		</div>
		
		<!-- Footer -->
		<div class="bg-gray-50 p-4 flex justify-between items-center border-t">
			<button 
				on:click={cancel}
				class="px-6 py-2 bg-gray-200 text-gray-700 font-semibold rounded-lg hover:bg-gray-300 transition-colors"
			>
				Cancel
			</button>
			
			<button 
				on:click={() => {
					if (selectedAction === 'continue') handleContinueAnyway();
					else if (selectedAction === 'fix') handleSetUniformPrice();
					else if (selectedAction === 'remove') handleRemoveMismatches();
				}}
				class="px-8 py-2 font-bold rounded-lg transition-colors"
				class:bg-blue-600={selectedAction === 'fix'}
				class:hover:bg-blue-700={selectedAction === 'fix'}
				class:bg-yellow-600={selectedAction === 'remove'}
				class:hover:bg-yellow-700={selectedAction === 'remove'}
				class:bg-red-600={selectedAction === 'continue'}
				class:hover:bg-red-700={selectedAction === 'continue'}
				class:text-white={true}
			>
				{#if selectedAction === 'fix'}
					Apply Uniform Price
				{:else if selectedAction === 'remove'}
					Remove Mismatches
				{:else}
					Continue Anyway
				{/if}
			</button>
		</div>
	</div>
</div>
