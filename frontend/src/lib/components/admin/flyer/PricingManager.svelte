<script lang="ts">
	import { supabaseAdmin } from '\$lib/utils/supabase';
	import { onMount, tick } from 'svelte';
	import * as XLSX from 'xlsx';
	import JsBarcode from 'jsbarcode';
	import ExcelJS from 'exceljs';
	
	let activeOffers: any[] = [];
	let selectedOfferId: string | null = null;
	let selectedProducts: any[] = [];
	let productsVersion = 0; // Force reactivity counter
	let isLoading: boolean = true;
	let isLoadingProducts: boolean = false;
	let isSavingPrices: boolean = false;
	let hasUnsavedChanges: boolean = false;
	let fileInput: HTMLInputElement;
	let targetProfitPercent: number = 16;
	
	// Button execution tracking
	let b1Executed: boolean = false;
	let b2Executed: boolean = false;
	let b3Executed: boolean = false;
	let b4Executed: boolean = false;
	let b5Executed: boolean = false;
	
	// Success message modal
	let showSuccessModal: boolean = false;
	let successMessage: string = '';
	
	// Update price function - now saves all products at once
	async function saveAllPrices() {
		if (!selectedProducts.length) return;
		
		isSavingPrices = true;
		
		try {
			// Update all products
			for (const product of selectedProducts) {
				const profitAmount = calculateProfitAmount(product.cost, product.sales_price, product.offer_qty);
				const profitPercent = calculateProfitPercentage(product.cost, product.sales_price);
				const profitAfterOffer = calculateProfitAfterOffer(product.cost, product.offer_price, product.offer_qty);
				const decreaseAmount = calculateDecreaseAmount(product.sales_price, product.offer_price, product.offer_qty);
				
				const { error } = await supabaseAdmin
					.from('flyer_offer_products')
					.update({
						cost: product.cost,
						sales_price: product.sales_price,
						profit_amount: profitAmount,
						profit_percent: profitPercent,
						offer_qty: product.offer_qty,
						limit_qty: product.limit_qty,
						free_qty: product.free_qty,
						offer_price: product.offer_price,
						profit_after_offer: profitAfterOffer,
						decrease_amount: decreaseAmount
					})
					.eq('id', product.offer_product_id);
				
				if (error) {
					console.error('Error updating product:', error);
					alert(`Error updating product ${product.barcode}. Please try again.`);
					isSavingPrices = false;
					return;
				}
			}
			
			hasUnsavedChanges = false;
			alert('All prices saved successfully!');
		} catch (error) {
			console.error('Error saving prices:', error);
			alert('Error saving prices. Please try again.');
		}
		
		isSavingPrices = false;
	}
	
	// Mark as changed when user edits
	function markAsChanged() {
		hasUnsavedChanges = true;
	}
	
	// Recalculate offer price when quantity changes
	function recalculateOfferPriceForQty(product: any, newQty: number) {
		const cost = product.cost || 0;
		const priceUnit = product.sales_price || 0;
		
		// Validation
		if (cost <= 0 || priceUnit <= 0 || newQty <= 0) {
			return product;
		}
		
		if (cost >= priceUnit) {
			return product;
		}
		
		// Try all possible offer prices ending in .95 for this quantity
		const candidates: any[] = [];
		
		for (let offerInt = Math.floor(cost); offerInt < Math.floor(priceUnit); offerInt++) {
			const testOfferPrice = offerInt + 0.95;
			
			// Must be above cost
			if (testOfferPrice <= cost) continue;
			
			// Must be below price
			if (testOfferPrice >= priceUnit) continue;
			
			// Calculate totals
			const costTotal = cost * newQty;
			const offerTotal = testOfferPrice * newQty;
			const priceTotal = priceUnit * newQty;
			
			// Calculate metrics
			const decrease = priceTotal - offerTotal;
			const profitPercent = ((offerTotal - costTotal) / costTotal) * 100;
			
			// Must have profit (no loss)
			if (profitPercent >= 0) {
				candidates.push({
					offerPrice: testOfferPrice,
					decrease: decrease,
					profit: profitPercent
				});
			}
		}
		
		// Select the one with best profit that has at least 1.55 decrease per unit
		// Or if none, just pick the best profit
		if (candidates.length > 0) {
			// Try to find candidates with at least 1.55 decrease per unit
			const minDecreasePerUnit = 1.55;
			const goodCandidates = candidates.filter(c => (c.decrease / newQty) >= minDecreasePerUnit);
			
			if (goodCandidates.length > 0) {
				// Pick the one with highest profit among good candidates
				goodCandidates.sort((a, b) => b.profit - a.profit);
				product.offer_price = goodCandidates[0].offerPrice;
			} else {
				// No candidate meets 1.55 per unit, pick the one with best profit
				candidates.sort((a, b) => b.profit - a.profit);
				product.offer_price = candidates[0].offerPrice;
			}
		}
		
		return product;
	}
	
	// Export to Excel with Barcode Images
	async function exportToExcel() {
		if (!selectedProducts.length) {
			alert('No products to export');
			return;
		}
		
		const selectedOffer = getSelectedOffer();
		
		// Create a new workbook
		const workbook = new ExcelJS.Workbook();
		const worksheet = workbook.addWorksheet('Products');
		
		// Define columns
		worksheet.columns = [
			{ header: 'Barcode', key: 'barcode', width: 15 },
			{ header: 'Barcode Image', key: 'barcodeImage', width: 30 },
			{ header: 'Product Name (EN)', key: 'productName', width: 40 },
			{ header: 'Unit', key: 'unit', width: 15 },
			{ header: 'Cost (Unit)', key: 'cost', width: 12 },
			{ header: 'Price (Unit)', key: 'price', width: 12 }
		];
		
		// Style header row
		worksheet.getRow(1).font = { bold: true };
		worksheet.getRow(1).fill = {
			type: 'pattern',
			pattern: 'solid',
			fgColor: { argb: 'FFE0E0E0' }
		};
		
		// Add data rows and barcode images
		for (let i = 0; i < selectedProducts.length; i++) {
			const product = selectedProducts[i];
			const barcode = product.barcode || '';
			const rowIndex = i + 2; // +2 because Excel is 1-indexed and row 1 is header
			
			// Add row data
			worksheet.addRow({
				barcode: barcode,
				barcodeImage: '', // We'll add image separately
				productName: product.product_name_en || '',
				unit: product.unit_name || '',
				cost: product.cost || '',
				price: product.sales_price || ''
			});
			
			// Generate barcode image
			const canvas = document.createElement('canvas');
			try {
				JsBarcode(canvas, barcode, {
					format: 'CODE128',
					width: 2,
					height: 60,
					displayValue: true,
					fontSize: 14,
					margin: 5
				});
				
				// Convert canvas to blob
				const imageBase64 = canvas.toDataURL('image/png').split(',')[1];
				
				// Add image to workbook
				const imageId = workbook.addImage({
					base64: imageBase64,
					extension: 'png'
				});
				
				// Embed image in cell
				worksheet.addImage(imageId, {
					tl: { col: 1, row: rowIndex - 1 }, // Top-left position (0-indexed for position)
					ext: { width: 200, height: 60 }
				});
				
				// Set row height to accommodate image
				worksheet.getRow(rowIndex).height = 50;
				
			} catch (error) {
				console.error('Error generating barcode:', error);
			}
		}
		
		// Generate file
		const buffer = await workbook.xlsx.writeBuffer();
		const blob = new Blob([buffer], { 
			type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' 
		});
		
		// Download file
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		const date = new Date().toISOString().split('T')[0];
		const offerName = selectedOffer?.template_name.replace(/[^a-z0-9]/gi, '_') || 'offer';
		const filename = `${offerName}_${date}.xlsx`;
		
		a.href = url;
		a.download = filename;
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);
		URL.revokeObjectURL(url);
	}
	
	// Import from Excel
	function handleImportClick() {
		fileInput.click();
	}
	
	async function handleFileImport(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (!file) return;
		
		const reader = new FileReader();
		
		reader.onload = async (e) => {
			try {
				const data = e.target?.result;
				const workbook = XLSX.read(data, { type: 'binary' });
				const sheetName = workbook.SheetNames[0];
				const worksheet = workbook.Sheets[sheetName];
				const jsonData = XLSX.utils.sheet_to_json(worksheet);
				
				// Update products with imported data (only Cost and Price)
				let updatedCount = 0;
				
				jsonData.forEach((row: any) => {
					const barcode = String(row['Barcode'] || '').trim();
					if (!barcode) return;
					
					// Find matching product
					const productIndex = selectedProducts.findIndex(p => p.barcode === barcode);
					if (productIndex !== -1) {
						// Update only Cost (Unit) and Price (Unit)
						if (row['Cost (Unit)'] !== undefined && row['Cost (Unit)'] !== '') {
							selectedProducts[productIndex].cost = row['Cost (Unit)'];
						}
						if (row['Price (Unit)'] !== undefined && row['Price (Unit)'] !== '') {
							selectedProducts[productIndex].sales_price = row['Price (Unit)'];
						}
						updatedCount++;
					}
				});
				
				// Trigger reactivity
				selectedProducts = [...selectedProducts];
				hasUnsavedChanges = true;
				
				alert(`Successfully imported cost and price data for ${updatedCount} products. Click "Save All Changes" to update the database.`);
			} catch (error) {
				console.error('Error importing file:', error);
				alert('Error importing file. Please make sure it\'s a valid Excel file.');
			}
		};
		
		reader.readAsBinaryString(file);
		
		// Reset file input
		target.value = '';
	}
	
	// Calculate profit amount (multiplied by offer_qty)
	function calculateProfitAmount(cost: number | null, salesPrice: number | null, offerQty: number = 1): number {
		if (!cost || !salesPrice) return 0;
		return (salesPrice - cost) * offerQty;
	}
	
	// Calculate profit percentage (not affected by qty)
	function calculateProfitPercentage(cost: number | null, salesPrice: number | null): number {
		if (!cost || cost === 0 || !salesPrice) return 0;
		return ((salesPrice - cost) / cost) * 100;
	}
	
	// Calculate total cost (cost * offer_qty)
	function calculateTotalCost(cost: number | null, offerQty: number = 1): number {
		if (!cost) return 0;
		return cost * offerQty;
	}
	
	// Calculate total sales price (sales_price * offer_qty)
	function calculateTotalSalesPrice(salesPrice: number | null, offerQty: number = 1): number {
		if (!salesPrice) return 0;
		return salesPrice * offerQty;
	}
	
	// Determine offer type based on qty, limit, and free qty
	function getOfferType(offerQty: number = 1, limitQty: number | null, freeQty: number = 0, offerPrice: number = 0): string {
		// If offer price is 0 or not set, it's not applicable
		if (!offerPrice || offerPrice === 0) {
			return 'Not Applicable';
		}
		
		// If there's free quantity, it's FOC (Free of Charge)
		if (freeQty > 0) {
			return `FOC ${offerQty}+${freeQty}`;
		}
		
		// If offer quantity is 1
		if (offerQty === 1) {
			if (!limitQty) {
				return 'Single No Limit';
			} else {
				return `Single ${limitQty} pcs Limit`;
			}
		}
		
		// If offer quantity is more than 1
		if (offerQty > 1) {
			if (!limitQty) {
				return `${offerQty} pcs No Limit`;
			} else {
				return `${offerQty} pcs ${limitQty} Limit`;
			}
		}
		
		return 'Unknown';
	}
	
	// Calculate average profit percentage based on offer price
	function calculateAvgProfitOnOfferPrice(): number {
		if (!selectedProducts.length) return 0;
		
		let totalProfit = 0;
		let validCount = 0;
		
		for (const product of selectedProducts) {
			const offerPrice = product.offer_price || 0;
			const cost = product.cost || 0;
			
			if (offerPrice > 0 && cost > 0) {
				const profitPercent = ((offerPrice - cost) / cost) * 100;
				totalProfit += profitPercent;
				validCount++;
			}
		}
		
		return validCount > 0 ? totalProfit / validCount : 0;
	}
	
	// Calculate average profit percentage based on normal price (sales_price)
	function calculateAvgProfitOnNormalPrice(): number {
		if (!selectedProducts.length) return 0;
		
		let totalProfit = 0;
		let validCount = 0;
		
		for (const product of selectedProducts) {
			const salesPrice = product.sales_price || 0;
			const cost = product.cost || 0;
			
			if (salesPrice > 0 && cost > 0) {
				const profitPercent = ((salesPrice - cost) / cost) * 100;
				totalProfit += profitPercent;
				validCount++;
			}
		}
		
		return validCount > 0 ? totalProfit / validCount : 0;
	}
	
	// Calculate profit percentage after offer (based on cost total and offer price)
	function calculateProfitAfterOffer(cost: number | null, offerPrice: number | null, offerQty: number = 1): number {
		if (!cost || cost === 0 || !offerPrice || offerPrice === 0) return 0;
		const costTotal = cost * offerQty;
		const offerTotal = offerPrice * offerQty; // offerPrice is per unit, multiply by qty
		return ((offerTotal - costTotal) / costTotal) * 100;
	}
	
	// Calculate decrease amount (difference between price total and offer total)
	function calculateDecreaseAmount(salesPrice: number | null, offerPrice: number | null, offerQty: number = 1): number {
		if (!salesPrice || !offerPrice) return 0;
		const priceTotal = salesPrice * offerQty;
		const offerTotal = offerPrice * offerQty; // offerPrice is per unit, multiply by qty
		return priceTotal - offerTotal;
	}
	
	// Helper: Round down to nearest .95
	function roundDownTo95(value: number): number {
		const intPart = Math.floor(value);
		return intPart + 0.95;
	}
	
	// Helper: Get allowed quantities based on price
	function getAllowedQuantities(priceUnit: number): number[] {
		if (priceUnit < 6) return [1, 2, 3, 4];
		if (priceUnit <= 10) return [1, 2, 3];
		return [1, 2];
	}
	
	// BUTTON 1: Check if current profit > target, then set offer = cost + target profit %
	function generateOfferPriceButton1(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.sales_price || 0;
		
		// Validation
		if (cost <= 0 || priceUnit <= 0) {
			return {
				...product,
				offer_qty: 1,
				offer_price: 0,
				free_qty: 0,
				limit_qty: null,
				generation_status: 'No offer (invalid cost/price)'
			};
		}
		
		if (cost >= priceUnit) {
			return {
				...product,
				offer_qty: 1,
				offer_price: 0,
				free_qty: 0,
				limit_qty: null,
				generation_status: 'No offer (cost >= price)'
			};
		}
		
		// Calculate current profit %
		const currentProfitPercent = ((priceUnit - cost) / cost) * 100;
		
		// Check if current profit is MORE than target profit
		if (currentProfitPercent > targetProfit) {
			// Calculate offer price = cost + target profit % amount
			const targetProfitAmount = cost * (targetProfit / 100);
			const offerPrice = cost + targetProfitAmount;
			
			// Round to .95 ending
			let offerPriceRounded = roundDownTo95(offerPrice);
			
			// Make sure rounded price still gives profit and is less than sales price
			if (offerPriceRounded <= cost) {
				offerPriceRounded = Math.floor(cost) + 1.95;
			}
			
			// If rounded price is >= sales price, try one level down
			if (offerPriceRounded >= priceUnit) {
				offerPriceRounded = Math.floor(offerPriceRounded - 1) + 0.95;
				
				// Check again - if still invalid, no offer possible
				if (offerPriceRounded <= cost || offerPriceRounded >= priceUnit) {
					return {
						...product,
						offer_qty: 1,
						offer_price: 0,
						free_qty: 0,
						limit_qty: null,
						generation_status: 'B1 Not Applicable (cannot round to valid .95 price)'
					};
				}
			}
			
			// Calculate actual profit after rounding
			const actualProfit = ((offerPriceRounded - cost) / cost) * 100;
			
			return {
				...product,
				offer_qty: 1,
				offer_price: offerPriceRounded,
				free_qty: 0,
				limit_qty: null,
				generation_status: `B1 Success (${actualProfit.toFixed(2)}%)`
			};
		} else {
			// Current profit is NOT more than target - no offer
			return {
				...product,
				offer_qty: 1,
				offer_price: 0,
				free_qty: 0,
				limit_qty: null,
				generation_status: `Not Applicable (Current ${currentProfitPercent.toFixed(2)}% ≤ Target ${targetProfit}%)`
			};
		}
	}
	
	// BUTTON 2: Increase quantity for low profit products (< 5% profit AND price < 10)
	function generateOfferPriceButton2(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.sales_price || 0;
		const offerPrice = product.offer_price || 0;
		const currentQty = product.offer_qty || 1;
		
		// Only process products that have an offer
		if (offerPrice <= 0) {
			return product; // Return unchanged if no offer exists
		}
		
		// Check conditions: Profit % After Offer < 5% AND Unit Price < 10
		const currentCostTotal = cost * currentQty;
		const currentOfferTotal = offerPrice * currentQty;
		const currentProfitPercent = ((currentOfferTotal - currentCostTotal) / currentCostTotal) * 100;
		
		// Only apply if profit < 5% AND price < 10
		if (currentProfitPercent >= 5 || priceUnit >= 10) {
			// Keep existing status if it exists, otherwise set B2 Skip
			const existingStatus = product.generation_status || '';
			return {
				...product,
				generation_status: existingStatus ? existingStatus : `B2 Skip (Profit: ${currentProfitPercent.toFixed(2)}%, Price: ${priceUnit})`
			};
		}
		
		// Calculate maximum quantity allowed (total price < 20)
		const maxQtyAllowed = Math.floor(20 / priceUnit);
		
		// Try increasing quantity - can increase until total price reaches 20 SAR
		const candidates: any[] = [];
		
		for (let newQty = currentQty + 1; newQty <= maxQtyAllowed; newQty++) {
			// Stop if total price would exceed 20
			if (priceUnit * newQty >= 20) break;
			
			// Try different offer prices ending in .95
			for (let offerInt = Math.floor(cost); offerInt < Math.floor(priceUnit); offerInt++) {
				const testOfferPrice = offerInt + 0.95;
				
				// Safety checks
				if (testOfferPrice <= cost) continue;
				if (testOfferPrice >= priceUnit) continue;
				
				const testCostTotal = cost * newQty;
				const testOfferTotal = testOfferPrice * newQty;
				const testPriceTotal = priceUnit * newQty;
				const testProfitPercent = ((testOfferTotal - testCostTotal) / testCostTotal) * 100;
				const testDecreaseAmount = testPriceTotal - testOfferTotal;
				
				// Must still give a discount
				if (testDecreaseAmount > 0 && testProfitPercent >= 0) {
					candidates.push({
						qty: newQty,
						offerPrice: testOfferPrice,
						profitPercent: testProfitPercent,
						decreaseAmount: testDecreaseAmount
					});
				}
			}
		}
		
		// Select the candidate with maximum profit
		if (candidates.length > 0) {
			candidates.sort((a, b) => b.profitPercent - a.profitPercent); // Highest profit first
			const best = candidates[0];
			
			// Debug log
			console.log(`B2 for ${product.barcode}: Found ${candidates.length} candidates, best: Qty=${best.qty}, Offer=${best.offerPrice}, Profit=${best.profitPercent.toFixed(2)}%`);
			
			return {
				...product,
				offer_qty: best.qty,
				offer_price: best.offerPrice,
				generation_status: `B2 Adjusted (Qty: ${best.qty}, Offer: ${best.offerPrice}, Profit: ${best.profitPercent.toFixed(2)}%)`
			};
		} else {
			// No better option found
			console.log(`B2 for ${product.barcode}: No candidates found`);
			return {
				...product,
				generation_status: `B2 Not Applicable (no better option found)`
			};
		}
	}
	
	// BUTTON 3: Adjust offers to ensure minimum 2.05 SAR decrease amount
	function generateOfferPriceButton3(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.sales_price || 0;
		const offerPrice = product.offer_price || 0;
		const offerQty = product.offer_qty || 1;
		
		// Validation
		if (cost <= 0 || priceUnit <= 0) {
			return product;
		}
		
		if (cost >= priceUnit) {
			return product;
		}
		
		// Case 1: No offer exists (offer_price = 0) - create offer with minimum 1.55 difference
		if (offerPrice <= 0) {
			// Try all possible offer prices ending in .95
			const candidates: any[] = [];
			
			for (let offerInt = Math.floor(cost); offerInt < Math.floor(priceUnit); offerInt++) {
				const testOfferPrice = offerInt + 0.95;
				
				// Must be above cost
				if (testOfferPrice <= cost) continue;
				
				// Must be below price
				if (testOfferPrice >= priceUnit) continue;
				
				// Calculate actual decrease
				const actualDecrease = priceUnit - testOfferPrice;
				
				// Must have at least 1.55 decrease
				if (actualDecrease >= 1.55) {
					const profitPercent = ((testOfferPrice - cost) / cost) * 100;
					
					// Must have profit (no loss)
					if (profitPercent >= 0) {
						candidates.push({
							offerPrice: testOfferPrice,
							decrease: actualDecrease,
							profit: profitPercent
						});
					}
				}
			}
			
			// Select the one with minimum decrease (closest to 1.55 but >= 1.55)
			if (candidates.length > 0) {
				candidates.sort((a, b) => a.decrease - b.decrease); // Smallest decrease first
				const best = candidates[0];
				
				return {
					...product,
					offer_qty: 1,
					offer_price: best.offerPrice,
					generation_status: `B3 Created (Decrease: ${best.decrease.toFixed(2)}, Profit: ${best.profit.toFixed(2)}%)`
				};
			} else {
				// Cannot achieve 1.55 decrease above cost
				return {
					...product,
					offer_qty: 1,
					offer_price: 0,
					generation_status: `B3 Not Applicable (cannot achieve 1.55 decrease above cost)`
				};
			}
		}
		
		// Case 2: Offer exists - check if decrease amount is less than 2.05
		const priceTotal = priceUnit * offerQty;
		const offerTotal = offerPrice * offerQty;
		const currentDecreaseAmount = priceTotal - offerTotal;
		
		// Check if decrease amount is less than 2.05
		if (currentDecreaseAmount < 2.05) {
			// Need to adjust offer price to get at least 2.05 decrease
			const targetOfferTotal = priceTotal - 2.05;
			const targetOfferUnit = targetOfferTotal / offerQty;
			
			// Round to .95 ending
			let newOfferPrice = roundDownTo95(targetOfferUnit);
			
			// Make sure it's still above cost
			if (newOfferPrice <= cost) {
				// Can't achieve 2.05 decrease without going below cost - mark as B3 Not Applicable
				return {
					...product,
					generation_status: `B3 Not Applicable (would go below cost)`
				};
			}
			
			// Calculate actual decrease amount and profit with new price
			const newOfferTotal = newOfferPrice * offerQty;
			const newDecreaseAmount = priceTotal - newOfferTotal;
			const newProfitPercent = ((newOfferTotal - (cost * offerQty)) / (cost * offerQty)) * 100;
			
			return {
				...product,
				offer_price: newOfferPrice,
				generation_status: `B3 Adjusted (Decrease: ${newDecreaseAmount.toFixed(2)}, Profit: ${newProfitPercent.toFixed(2)}%)`
			};
		} else {
			// Already has at least 2.05 decrease - no change needed
			return {
				...product,
				generation_status: `B3 Skip (Already ${currentDecreaseAmount.toFixed(2)} decrease)`
			};
		}
	}
	
	// Auto-generate offer price for a single product with target profit percentage
	function generateOfferPrice(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.sales_price || 0;
		
		// Step 0: Quick no-offer check
		if (cost >= priceUnit || cost === 0 || priceUnit === 0) {
			return {
				...product,
				offer_qty: 1,
				offer_price: 0,
				free_qty: 0,
				limit_qty: null
			};
		}
		
		const allowedQtys = getAllowedQuantities(priceUnit);
		const allCandidates: any[] = [];
		
		// STEP 1: PRIMARY GOAL - Try to achieve target profit for each quantity
		for (const qty of allowedQtys) {
			const priceTotal = priceUnit * qty;
			const costTotal = cost * qty;
			
			// Calculate offer price needed for EXACT target profit
			const targetOfferTotal = costTotal * (1 + targetProfit / 100);
			const targetOfferUnit = targetOfferTotal / qty;
			
			// Round down to .95 ending
			let offerPriceUnit = roundDownTo95(targetOfferUnit);
			if (offerPriceUnit > targetOfferUnit) {
				offerPriceUnit = roundDownTo95(targetOfferUnit - 1);
			}
			
			// Safety checks
			if (offerPriceUnit < cost) continue;
			if (offerPriceUnit >= priceUnit) continue;
			
			const offerTotal = offerPriceUnit * qty;
			const discountActual = priceTotal - offerTotal;
			const profitPercent = ((offerTotal - costTotal) / costTotal) * 100;
			
			// Must give some discount
			if (discountActual > 0) {
				allCandidates.push({
					qty,
					offerPriceUnit,
					discountActual,
					offerTotal,
					priceTotal,
					profitPercent,
					distanceFromTarget: Math.abs(profitPercent - targetProfit) // How close to target
				});
			}
		}
		
		// Step 3: Fallback mode - accept any profit (no loss)
		// Try to find the lowest price ending in .95 that still gives profit
		
		// Start from just above cost and find the first .95 ending
		let offerPriceUnit = roundDownTo95(cost + 0.1);
		
		// Make sure it's actually above cost
		if (offerPriceUnit <= cost) {
			offerPriceUnit = Math.floor(cost) + 1.95;
		}
		
		// Check if this price is still below normal price (gives discount)
		if (offerPriceUnit < priceUnit) {
			return {
				...product,
				offer_qty: 1,
				offer_price: offerPriceUnit, // For qty=1, unit price = total price
				free_qty: 0,
				limit_qty: null
			};
		}
		
		// If even the lowest profitable price is >= normal price, no offer possible
		return {
			...product,
			offer_qty: 1,
			offer_price: 0,
			free_qty: 0,
			limit_qty: null
		};
	}
	
	// Check if all products have cost and price
	function allProductsHaveCostAndPrice(): boolean {
		if (!selectedProducts.length) return false;
		return selectedProducts.every(product => {
			const cost = product.cost || 0;
			const price = product.sales_price || 0;
			return cost > 0 && price > 0;
		});
	}
	
	// Generate offer prices for all products - BUTTON 1
	function generateAllOfferPricesButton1() {
		if (!selectedProducts.length) {
			alert('No products to generate offers for');
			return;
		}
		
		if (!allProductsHaveCostAndPrice()) {
			alert('Please ensure all products have Cost (Unit) and Price (Unit) before generating offers.');
			return;
		}
		
		if (!targetProfitPercent || targetProfitPercent < 0) {
			alert('Please enter a valid target profit percentage');
			return;
		}
		
		selectedProducts = selectedProducts.map(product => generateOfferPriceButton1(product, targetProfitPercent));
		hasUnsavedChanges = true;
		b1Executed = true; // Mark B1 as executed
		
		// Count successes and failures
		const successful = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('Success')).length;
		const failed = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('No Step 1 possible')).length;
		
		// alert(`Button 1 Complete!\nSuccessful: ${successful}\nNo Step 1 possible: ${failed}\n\nReview and click "Save All Changes" to save.`);
		console.log(`B1 Complete - Successful: ${successful}, Failed: ${failed}`);
	}
	
	// Generate offer prices for all products - BUTTON 2 (Increase quantity for low profit)
	function generateAllOfferPricesButton2() {
		if (!selectedProducts.length) {
			// alert('No products to adjust');
			console.log('B2: No products to adjust');
			return;
		}
		
		// Check if any products have offers
		const productsWithOffers = selectedProducts.filter(p => p.offer_price && p.offer_price > 0);
		if (productsWithOffers.length === 0) {
			// alert('No products have offers yet. Please run B1 first.');
			console.log('B2: No products have offers yet');
			return;
		}
		
		selectedProducts = selectedProducts.map(product => generateOfferPriceButton2(product, targetProfitPercent));
		hasUnsavedChanges = true;
		b2Executed = true; // Mark B2 as executed
		
		// Count adjustments
		const adjusted = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('B2 Adjusted')).length;
		const skipped = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('B2 Skip')).length;
		const notApplicable = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('B2 Not Applicable')).length;
		
		// alert(`Button 2 Complete (Increase Qty)!\nAdjusted: ${adjusted}\nSkipped: ${skipped}\nNot Applicable: ${notApplicable}\n\nReview and click "Save All Changes" to save.`);
		console.log(`B2 Complete - Adjusted: ${adjusted}, Skipped: ${skipped}, Not Applicable: ${notApplicable}`);
	}
	
	// Generate offer prices for all products - BUTTON 3 (Minimum 2.05 decrease)
	function generateAllOfferPricesButton3() {
		if (!selectedProducts.length) {
			// alert('No products to adjust');
			console.log('B3: No products to adjust');
			return;
		}
		
		if (!allProductsHaveCostAndPrice()) {
			// alert('Please ensure all products have Cost (Unit) and Price (Unit) before running B3.');
			console.log('B3: Not all products have Cost and Price');
			return;
		}
		
		selectedProducts = selectedProducts.map(product => generateOfferPriceButton3(product, targetProfitPercent));
		hasUnsavedChanges = true;
		b3Executed = true; // Mark B3 as executed
		
		// Count adjustments
		const created = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('B3 Created')).length;
		const adjusted = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('B3 Adjusted')).length;
		const skipped = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('B3 Skip')).length;
		const notApplicable = selectedProducts.filter(p => p.generation_status && p.generation_status.includes('B3 Not Applicable')).length;
		
		// alert(`Button 3 Complete (Min 2.05 Decrease)!\nCreated: ${created}\nAdjusted: ${adjusted}\nSkipped (already ≥2.05): ${skipped}\nNot Applicable: ${notApplicable}\n\nReview and click "Save All Changes" to save.`);
		console.log(`B3 Complete - Created: ${created}, Adjusted: ${adjusted}, Skipped: ${skipped}, Not Applicable: ${notApplicable}`);
	}
	
	// Generate offer prices for all products - BUTTON 4 (Increase qty if offer price < 10)
	async function generateAllOfferPricesButton4() {
		if (!selectedProducts.length) {
			// alert('No products to adjust');
			console.log('B4: No products to adjust');
			return;
		}
		
		if (!allProductsHaveCostAndPrice()) {
			// alert('Please ensure all products have Cost (Unit) and Price (Unit) before running B4.');
			console.log('B4: Not all products have Cost and Price');
			return;
		}
		
		console.log('B4: Starting quantity adjustment for', selectedProducts.length, 'products');
		
		const updatedProducts = selectedProducts.map(product => {
			const cost = product.cost || 0;
			const priceUnit = product.sales_price || 0;
			const currentQty = product.offer_qty || 1;
			const offerPricePerUnit = product.offer_price || 0;
			
			// Calculate current total offer price
			const currentTotalOfferPrice = offerPricePerUnit * currentQty;
			
			console.log(`B4: Processing ${product.barcode}`, {
				cost,
				priceUnit,
				currentQty,
				offerPricePerUnit,
				currentTotalOfferPrice
			});
			
			// Skip if no valid offer price or if total offer price is already >= 10
			if (offerPricePerUnit <= 0 || currentTotalOfferPrice >= 10) {
				console.log(`B4: Skipping ${product.barcode} - total offer price >= 10 or no offer price`);
				return { ...product, generation_status: 'B4 Skip (>= 10 SAR)' };
			}
			
			// Skip if cost/price invalid
			if (cost <= 0 || priceUnit <= 0 || cost >= priceUnit) {
				console.log(`B4: Skipping ${product.barcode} - invalid cost/price`);
				return { ...product, generation_status: 'B4 Not Applicable' };
			}
			
			// Calculate maximum quantity where total offer price <= 19.95
			const maxQty = Math.floor(19.95 / offerPricePerUnit);
			
			// Don't decrease quantity
			if (maxQty <= currentQty) {
				console.log(`B4: Skipping ${product.barcode} - already at max qty`);
				return { ...product, generation_status: 'B4 Skip (Max Qty)' };
			}
			
			// Set new quantity
			const newQty = maxQty;
			const newTotalOfferPrice = offerPricePerUnit * newQty;
			
			console.log(`B4: ${product.barcode}`, {
				oldQty: currentQty,
				newQty: newQty,
				offerPricePerUnit: offerPricePerUnit.toFixed(2),
				oldTotal: currentTotalOfferPrice.toFixed(2),
				newTotal: newTotalOfferPrice.toFixed(2)
			});
			
			return {
				...product,
				offer_qty: newQty,
				generation_status: `B4 Adjusted (Qty: ${currentQty}→${newQty}, Total: ${newTotalOfferPrice.toFixed(2)})`
			};
		});
		
		console.log('B4: Adjustment complete, updating products');
		selectedProducts = updatedProducts;
		productsVersion++; // Increment version to force reactivity
		
		// Wait for DOM to update
		await tick();
		console.log('B4: DOM updated, triggering reactivity, version:', productsVersion);
		
		hasUnsavedChanges = true;
		b4Executed = true; // Mark B4 as executed
		
		// Count results
		const adjusted = updatedProducts.filter(p => p.generation_status && p.generation_status.includes('B4 Adjusted')).length;
		const skipped = updatedProducts.filter(p => p.generation_status && p.generation_status.includes('B4 Skip')).length;
		const notApplicable = updatedProducts.filter(p => p.generation_status && p.generation_status.includes('B4 Not Applicable')).length;
		
		// alert(`Button 4 Complete (Increase Qty for Offers < 10)!\nAdjusted: ${adjusted}\nSkipped: ${skipped}\nNot Applicable: ${notApplicable}\n\nReview and click "Save All Changes" to save.`);
		console.log(`B4 Complete - Adjusted: ${adjusted}, Skipped: ${skipped}, Not Applicable: ${notApplicable}`);
	}
	
	// Generate offer prices for all products - BUTTON 5 (Recalculate based on current quantity)
	async function generateAllOfferPricesButton5() {
		if (!selectedProducts.length) {
			// alert('No products to recalculate');
			console.log('B5: No products to recalculate');
			return;
		}
		
		if (!allProductsHaveCostAndPrice()) {
			// alert('Please ensure all products have Cost (Unit) and Price (Unit) before running B5.');
			console.log('B5: Not all products have Cost and Price');
			return;
		}
		
		console.log('B5: Starting recalculation for', selectedProducts.length, 'products');
		
		const updatedProducts = selectedProducts.map(product => {
			const cost = product.cost || 0;
			const priceUnit = product.sales_price || 0;
			const currentQty = product.offer_qty || 1;
			const oldOfferPrice = product.offer_price || 0;
			
			console.log(`B5: Processing ${product.barcode}`, {
				cost,
				priceUnit,
				currentQty,
				oldOfferPrice
			});
			
			// Skip if quantity is 1 or less
			if (currentQty <= 1) {
				console.log(`B5: Skipping ${product.barcode} - qty is 1 or less`);
				return { ...product, generation_status: 'B5 Skip (Qty ≤ 1)' };
			}
			
			// Skip if no valid cost/price
			if (cost <= 0 || priceUnit <= 0 || cost >= priceUnit) {
				console.log(`B5: Skipping ${product.barcode} - invalid cost/price`);
				return { ...product, generation_status: 'B5 Not Applicable' };
			}
			
			// Calculate total sales price
			const totalSalesPrice = priceUnit * currentQty;
			
			// Target total decrease of at least 2.05 SAR
			const minTotalDecrease = 2.05;
			const targetTotalOfferPrice = totalSalesPrice - minTotalDecrease;
			
			// Round TOTAL offer price to .95 (not per-unit)
			let totalOfferPriceRounded = Math.floor(targetTotalOfferPrice) + 0.95;
			
			// Calculate per-unit offer price from rounded total
			let offerPricePerUnit = totalOfferPriceRounded / currentQty;
			
			// Validate: per-unit must be above cost and below sales price
			const costTotal = cost * currentQty;
			
			if (offerPricePerUnit <= cost) {
				// Try one level up
				totalOfferPriceRounded = Math.floor(targetTotalOfferPrice) + 1 + 0.95;
				offerPricePerUnit = totalOfferPriceRounded / currentQty;
			}
			
			if (offerPricePerUnit >= priceUnit) {
				// Try one level down
				totalOfferPriceRounded = Math.floor(targetTotalOfferPrice) - 1 + 0.95;
				offerPricePerUnit = totalOfferPriceRounded / currentQty;
			}
			
			// Final validation
			if (offerPricePerUnit <= cost || offerPricePerUnit >= priceUnit) {
				console.log(`B5: No valid price for ${product.barcode}`);
				return { ...product, generation_status: 'B5 No Valid Price' };
			}
			
			// Calculate actual decrease to verify
			const actualTotalDecrease = totalSalesPrice - totalOfferPriceRounded;
			const profitPercent = ((offerPricePerUnit - cost) / cost) * 100;
			
			console.log(`B5: ${product.barcode}`, {
				totalSalesPrice: totalSalesPrice.toFixed(2),
				targetTotalOfferPrice: targetTotalOfferPrice.toFixed(2),
				totalOfferPriceRounded: totalOfferPriceRounded.toFixed(2),
				offerPricePerUnit: offerPricePerUnit.toFixed(4),
				actualTotalDecrease: actualTotalDecrease.toFixed(2),
				profitPercent: profitPercent.toFixed(2) + '%',
				oldOfferPrice,
				newOfferPrice: offerPricePerUnit
			});
			
			return {
				...product,
				offer_price: offerPricePerUnit,
				generation_status: `B5 Recalculated (Total: ${totalOfferPriceRounded.toFixed(2)}, Decrease: ${actualTotalDecrease.toFixed(2)} SAR)`
			};
		});
		
		console.log('B5: Recalculation complete, updating products');
		selectedProducts = updatedProducts;
		productsVersion++; // Increment version to force reactivity
		
		// Wait for DOM to update
		await tick();
		console.log('B5: DOM updated, triggering reactivity, version:', productsVersion);
		
		hasUnsavedChanges = true;
		b5Executed = true;
		
		// Count results
		const recalculated = updatedProducts.filter(p => p.generation_status && p.generation_status.includes('B5 Recalculated')).length;
		const noValidPrice = updatedProducts.filter(p => p.generation_status && p.generation_status.includes('B5 No Valid Price')).length;
		const notApplicable = updatedProducts.filter(p => p.generation_status && p.generation_status.includes('B5 Not Applicable')).length;
		
		// alert(`Button 5 Complete (Recalculate for Current Qty)!\nRecalculated: ${recalculated}\nNo Valid Price: ${noValidPrice}\nNot Applicable: ${notApplicable}\n\nReview and click "Save All Changes" to save.`);
		console.log(`B5 Complete - Recalculated: ${recalculated}, No Valid Price: ${noValidPrice}, Not Applicable: ${notApplicable}`);
	}
	
	// NEW: Single button to run all steps B1→B2→B3→B4→B5 in sequence
	async function generateOffersAllSteps() {
		if (!selectedProducts.length) {
			alert('No products to generate offers for');
			return;
		}
		
		if (!allProductsHaveCostAndPrice()) {
			alert('Please ensure all products have Cost (Unit) and Price (Unit) before generating offers.');
			return;
		}
		
		if (!targetProfitPercent || targetProfitPercent < 0) {
			alert('Please enter a valid target profit percentage');
			return;
		}
		
		try {
			// Run B1
			await generateAllOfferPricesButton1();
			
			// Run B2
			await generateAllOfferPricesButton2();
			
			// Run B3
			await generateAllOfferPricesButton3();
			
			// Run B4
			await generateAllOfferPricesButton4();
			
			// Run B5
			await generateAllOfferPricesButton5();
			
			// Wait for all updates to complete
			await tick();
			
			// Show success modal instead of alert
			successMessage = 'All offer generation steps completed successfully!';
			showSuccessModal = true;
		} catch (error) {
			console.error('Error during offer generation:', error);
			alert('An error occurred during offer generation. Please try again.');
		}
	}
	
	// Generate offer prices for all products - ORIGINAL
	function generateAllOfferPrices() {
		if (!selectedProducts.length) {
			alert('No products to generate offers for');
			return;
		}
		
		if (!allProductsHaveCostAndPrice()) {
			alert('Please ensure all products have Cost (Unit) and Price (Unit) before generating offers.');
			return;
		}
		
		if (!targetProfitPercent || targetProfitPercent < 0) {
			alert('Please enter a valid target profit percentage');
			return;
		}
		
		selectedProducts = selectedProducts.map(product => generateOfferPrice(product, targetProfitPercent));
		hasUnsavedChanges = true;
		alert(`Offer prices generated with ${targetProfitPercent}% target profit! Review and click "Save All Changes" to save.`);
	}
	
	// Load all active offers
	async function loadActiveOffers() {
		isLoading = true;
		
		try {
			const { data, error } = await supabaseAdmin
				.from('flyer_offers')
				.select('*')
				.eq('is_active', true)
				.order('created_at', { ascending: false });
			
			if (error) {
				console.error('Error loading active offers:', error);
				alert('Error loading active offers. Please try again.');
			} else {
				activeOffers = data || [];
			}
		} catch (error) {
			console.error('Error loading active offers:', error);
			alert('Error loading active offers. Please try again.');
		}
		
		isLoading = false;
	}
	
	// Load products for selected offer
	async function loadOfferProducts(offerId: string) {
		isLoadingProducts = true;
		selectedOfferId = offerId;
		selectedProducts = [];
		hasUnsavedChanges = false; // Reset unsaved changes flag
		
		// Reset execution flags when loading new offer
		b1Executed = false;
		b2Executed = false;
		b3Executed = false;
		b4Executed = false;
		b5Executed = false;
		
		try {
			// Get offer products with product details, cost, sales_price, qty, limit, free_qty, offer_price, profit_after_offer, decrease_amount
			const { data, error } = await supabaseAdmin
				.from('flyer_offer_products')
				.select(`
					id,
					product_barcode,
					cost,
					sales_price,
					profit_amount,
					profit_percent,
					offer_qty,
					limit_qty,
					free_qty,
					offer_price,
					profit_after_offer,
					decrease_amount,
					flyer_products (
						barcode,
						product_name_en,
						product_name_ar,
						unit_name,
						image_url,
						parent_category,
						parent_sub_category,
						sub_category
					)
				`)
				.eq('offer_id', offerId);
			
			if (error) {
				console.error('Error loading offer products:', error);
				alert('Error loading products. Please try again.');
			} else {
				selectedProducts = data?.map(item => ({
					...item.flyer_products,
					offer_product_id: item.id,
					cost: item.cost,
					sales_price: item.sales_price,
					profit_amount: item.profit_amount,
					profit_percent: item.profit_percent,
					offer_qty: item.offer_qty || 1,
					limit_qty: item.limit_qty,
					free_qty: item.free_qty || 0,
					offer_price: item.offer_price,
					profit_after_offer: item.profit_after_offer,
					decrease_amount: item.decrease_amount
				})) || [];
			}
		} catch (error) {
			console.error('Error loading offer products:', error);
			alert('Error loading products. Please try again.');
		}
		
		isLoadingProducts = false;
	}
	
	// Get selected offer details
	function getSelectedOffer() {
		return activeOffers.find(o => o.id === selectedOfferId);
	}
	
	onMount(() => {
		loadActiveOffers();
	});
</script>

<div class="space-y-6">
	<!-- Header - Sticky -->
	<div class="sticky top-0 z-20 bg-gray-50 pb-4">
		<div class="flex items-center justify-between mb-4">
			<div>
				<h1 class="text-3xl font-bold text-gray-800">Pricing Manager</h1>
				<p class="text-gray-600 mt-1">View active offers and their selected products</p>
			</div>
			
			<button 
				on:click={loadActiveOffers}
				disabled={isLoading}
				class="px-4 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
			>
				<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
				</svg>
				Refresh
			</button>
		</div>

		<!-- Active Offers Buttons - Sticky -->
	{#if isLoading}
		<div class="bg-white rounded-lg shadow-lg p-12 text-center">
			<svg class="animate-spin w-12 h-12 mx-auto text-blue-600 mb-4" fill="none" viewBox="0 0 24 24">
				<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
				<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
			</svg>
			<p class="text-gray-600">Loading active offers...</p>
		</div>
	{:else if activeOffers.length === 0}
		<div class="bg-white rounded-lg shadow-lg p-12 text-center">
			<svg class="w-24 h-24 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
			</svg>
			<h3 class="text-xl font-semibold text-gray-800 mb-2">No Active Offers</h3>
			<p class="text-gray-600">Activate offers from the Offer Manager page.</p>
		</div>
	{:else}
		<div class="bg-white rounded-lg shadow-md p-6">
			<h2 class="text-xl font-bold text-gray-800 mb-4">Active Offer Templates</h2>
			<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
				{#each activeOffers as offer (offer.id)}
					<button
						on:click={() => loadOfferProducts(offer.id)}
						class="p-4 border-2 rounded-lg transition-all {selectedOfferId === offer.id ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'}"
					>
						<h3 class="font-semibold text-gray-800 mb-2">{offer.template_name}</h3>
						<p class="text-xs text-gray-500 mb-2 font-mono">{offer.template_id}</p>
						<div class="text-sm text-gray-600 space-y-1">
							<div class="flex items-center gap-1">
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
								</svg>
								<span>{new Date(offer.start_date).toLocaleDateString()}</span>
							</div>
							<div class="flex items-center gap-1">
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
								</svg>
								<span>{new Date(offer.end_date).toLocaleDateString()}</span>
							</div>
						</div>
					</button>
				{/each}
			</div>
		</div>
	{/if}
	</div>
	<!-- End of Sticky Header -->

	<!-- Selected Products Table -->
	{#if selectedOfferId}
		<div class="bg-white rounded-lg shadow-md">
			<div class="flex items-center justify-between p-6 border-b border-gray-200 sticky top-0 bg-white z-10">
				<div>
					<h2 class="text-xl font-bold text-gray-800">Selected Products</h2>
					{#if getSelectedOffer()}
						<p class="text-sm text-gray-600 mt-1">{getSelectedOffer().template_name}</p>
					{/if}
				</div>
				<div class="flex items-center gap-4">
					{#if selectedProducts.length > 0}
						<span class="px-4 py-2 bg-green-100 text-green-800 font-semibold rounded-lg">
							{selectedProducts.length} Products
						</span>
						
						<!-- Average Profit on Offer Price -->
						<div class="px-4 py-2 {calculateAvgProfitOnOfferPrice() >= 0 ? 'bg-blue-100 text-blue-800' : 'bg-red-100 text-red-800'} font-semibold rounded-lg">
							<div class="text-xs font-normal">Avg Profit (Offer)</div>
							<div class="text-sm font-bold">{calculateAvgProfitOnOfferPrice().toFixed(2)}%</div>
						</div>
						
						<!-- Average Profit on Normal Price -->
						<div class="px-4 py-2 {calculateAvgProfitOnNormalPrice() >= 0 ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'} font-semibold rounded-lg">
							<div class="text-xs font-normal">Avg Profit (Normal)</div>
							<div class="text-sm font-bold">{calculateAvgProfitOnNormalPrice().toFixed(2)}%</div>
						</div>
						
						<!-- Target Profit Input -->
						<div class="flex items-center gap-2 px-4 py-2 bg-indigo-100 rounded-lg">
							<label for="targetProfit" class="text-xs font-semibold text-indigo-800 whitespace-nowrap">
								Target Profit:
							</label>
							<div class="relative">
								<input
									id="targetProfit"
									type="number"
									bind:value={targetProfitPercent}
									step="0.5"
									min="0"
									max="100"
									class="w-20 px-2 py-1 text-sm font-bold border-2 border-indigo-300 rounded focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none"
									placeholder="16"
								/>
								<span class="absolute right-2 top-1/2 transform -translate-y-1/2 text-indigo-600 text-xs font-bold">%</span>
							</div>
						</div>
					{/if}
					{#if hasUnsavedChanges}
						<span class="px-3 py-1 bg-yellow-100 text-yellow-800 text-sm font-medium rounded-lg animate-pulse">
							Unsaved Changes
						</span>
					{/if}
					
				
				<!-- Auto-Generation Buttons -->
				<div class="flex items-center gap-2 border-l-2 border-gray-300 pl-4">
					<!-- Single Generate Offers Button (runs B1→B2→B3→B4→B5) -->
					<button
						on:click={generateOffersAllSteps}
						disabled={!selectedProducts.length || !allProductsHaveCostAndPrice()}
						class="px-4 py-2 bg-gradient-to-r from-purple-600 via-blue-600 to-pink-600 text-white font-bold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
						title={!allProductsHaveCostAndPrice() ? 'All products must have Cost (Unit) and Price (Unit)' : 'Generate offers using all 5 steps automatically'}
					>
						Generate Offers
					</button>
					
					<!-- Individual B1-B5 buttons (HIDDEN) -->
					{#if false}
					<!-- Button 1: Discount-based (1.55-1.95 SAR) -->
					<button
						on:click={generateAllOfferPricesButton1}
						disabled={!selectedProducts.length || !allProductsHaveCostAndPrice()}
						class="px-3 py-2 bg-gradient-to-r from-purple-600 to-purple-700 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none text-sm"
						title={!allProductsHaveCostAndPrice() ? 'All products must have Cost (Unit) and Price (Unit)' : 'Button 1: Discount 1.55-1.95 SAR, increase qty to meet target'}
					>
						B1
					</button>					<!-- Button 2: Increase quantity for low profit products -->
					<button
						on:click={generateAllOfferPricesButton2}
						disabled={!selectedProducts.length || !selectedProducts.some(p => p.offer_price > 0) || !b1Executed}
						class="px-3 py-2 bg-gradient-to-r from-blue-600 to-blue-700 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none text-sm"
						title={!b1Executed ? 'Run B1 first' : (!selectedProducts.some(p => p.offer_price > 0) ? 'Run B1 first to generate offers' : 'Button 2: Increase qty for low profit (< 5%) and price < 10')}
					>
						B2
					</button>						<!-- Button 3: Adjust to minimum 2.05 decrease -->
						<button
							on:click={generateAllOfferPricesButton3}
						disabled={!selectedProducts.length || !allProductsHaveCostAndPrice() || !b2Executed}
						class="px-3 py-2 bg-gradient-to-r from-green-600 to-green-700 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none text-sm"
						title={!b2Executed ? 'Run B2 first' : (!allProductsHaveCostAndPrice() ? 'All products must have Cost and Price' : 'Button 3: Creates offers with 1.55 min decrease OR adjusts to 2.05 decrease')}
					>
						B3
					</button>					<!-- Button 4: Increase qty if offer price < 10 -->
					<button
						on:click={generateAllOfferPricesButton4}
						disabled={!selectedProducts.length || !selectedProducts.some(p => p.offer_price > 0) || !b3Executed}
						class="px-3 py-2 bg-gradient-to-r from-orange-600 to-orange-700 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none text-sm"
						title={!b3Executed ? 'Run B3 first' : (!selectedProducts.some(p => p.offer_price > 0) ? 'Run B1/B3 first to generate offers' : 'Button 4: Increase qty if total offer price < 10 (max total 19.95)')}
					>
					B4
				</button>						<!-- Button 5: Recalculate based on current quantity -->
					<button
						on:click={generateAllOfferPricesButton5}
						disabled={!selectedProducts.length || !allProductsHaveCostAndPrice() || !b4Executed}
						class="px-3 py-2 bg-gradient-to-r from-pink-600 to-pink-700 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none text-sm"
						title={!b4Executed ? 'Run B4 first' : (!allProductsHaveCostAndPrice() ? 'All products must have Cost and Price' : 'Button 5: Recalculate offer price for current quantity (total - 2.05)')}
					>
						B5
				</button>
					{/if}
					<!-- End of hidden B1-B5 buttons -->
				</div>
					
				<button
						on:click={exportToExcel}
						disabled={!selectedProducts.length}
						class="px-4 py-2 bg-gradient-to-r from-blue-600 to-cyan-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center gap-2"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
						</svg>
						Export to Excel
					</button>
					<button
						on:click={handleImportClick}
						disabled={!selectedProducts.length}
						class="px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center gap-2"
					>
						<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
						</svg>
						Import from Excel
					</button>
					<button
						on:click={saveAllPrices}
						disabled={isSavingPrices || !hasUnsavedChanges}
						class="px-6 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white font-bold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center gap-2"
					>
						{#if isSavingPrices}
							<svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
								<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
								<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
							</svg>
							Saving...
						{:else}
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
							</svg>
							Save All Changes
						{/if}
					</button>
				</div>
			</div>

			{#if isLoadingProducts}
				<div class="text-center py-8">
					<svg class="animate-spin w-8 h-8 mx-auto text-blue-600 mb-2" fill="none" viewBox="0 0 24 24">
						<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
						<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
					</svg>
					<p class="text-gray-600">Loading products...</p>
				</div>
			{:else if selectedProducts.length === 0}
				<div class="text-center py-8 text-gray-500">
					<svg class="w-16 h-16 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
					</svg>
					<p>No products selected for this offer</p>
				</div>
			{:else}
				<!-- Scrollable table container -->
				<div class="overflow-auto max-h-[600px]">
					<table class="min-w-full table-fixed border-collapse">
						<thead class="bg-gray-100">
							<tr>
								<th class="w-20 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Image
								</th>
								<th class="w-32 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Barcode
								</th>
								<th class="w-48 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Product Name (EN)
								</th>
								<th class="w-48 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Product Name (AR)
								</th>
								<th class="w-24 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Unit
								</th>
								<th class="w-40 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Parent Sub Category
								</th>
								<th class="w-40 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Offer Type
								</th>
								<th class="w-24 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Offer Qty
								</th>
								<th class="w-24 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Free Qty
								</th>
								<th class="w-24 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Limit
								</th>
								<th class="w-28 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Cost (Unit)
								</th>
								<th class="w-28 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Cost (Total)
								</th>
								<th class="w-28 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Price (Unit)
								</th>
								<th class="w-28 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Price (Total)
								</th>
								<th class="w-28 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Offer Price (Total)
								</th>
								<th class="w-28 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Profit (Amount)
								</th>
								<th class="w-24 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Profit %
								</th>
								<th class="w-28 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Profit % After Offer
								</th>
								<th class="w-28 px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b-2 border-gray-200">
									Decrease Amount
								</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each selectedProducts as product (product.barcode)}
								<tr class="hover:bg-gray-50 transition-colors">
									<td class="w-20 px-4 py-4 align-middle">
										<div class="w-14 h-14 bg-gray-100 rounded-lg border-2 border-gray-200 flex items-center justify-center overflow-hidden">
											{#if product.image_url}
												<img 
													src={product.image_url}
													alt={product.product_name_en || product.barcode}
													class="w-full h-full object-contain"
													on:error={(e) => {
														const img = e.target;
														img.src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect fill="%23f3f4f6" width="64" height="64"/><text x="32" y="32" font-size="10" text-anchor="middle" alignment-baseline="middle" fill="%239ca3af">No Image</text></svg>';
													}}
												/>
											{:else}
												<svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
													<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
												</svg>
											{/if}
										</div>
									</td>
									<td class="w-32 px-4 py-4 align-middle text-xs font-medium text-gray-900">
										{product.barcode}
									</td>
									<td class="w-48 px-4 py-4 align-middle text-xs text-gray-900">
										{product.product_name_en || '-'}
									</td>
									<td class="w-48 px-4 py-4 align-middle text-xs text-gray-900" dir="rtl">
										{product.product_name_ar || '-'}
									</td>
									<td class="w-24 px-4 py-4 align-middle text-xs text-gray-900">
										{product.unit_name || '-'}
									</td>
									<td class="w-40 px-4 py-4 align-middle text-xs text-gray-900">
										{product.parent_sub_category || '-'}
									</td>
									<td class="w-40 px-4 py-4 align-middle">
										<span class="px-2 py-1 text-xs font-semibold rounded-full {
											getOfferType(product.offer_qty, product.limit_qty, product.free_qty, product.offer_price).includes('Not Applicable')
												? 'bg-gray-100 text-gray-800'
												: getOfferType(product.offer_qty, product.limit_qty, product.free_qty, product.offer_price).includes('FOC') 
													? 'bg-green-100 text-green-800' 
													: getOfferType(product.offer_qty, product.limit_qty, product.free_qty, product.offer_price).includes('No Limit')
														? 'bg-blue-100 text-blue-800'
														: 'bg-purple-100 text-purple-800'
										}">
											{getOfferType(product.offer_qty, product.limit_qty, product.free_qty, product.offer_price)}
										</span>
									</td>
									<td class="w-24 px-4 py-4 align-middle">
										<input
											type="number"
											bind:value={product.offer_qty}
											on:input={markAsChanged}
											step="1"
											min="1"
											class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
										/>
									</td>
									<td class="w-24 px-4 py-4 align-middle">
										<input
											type="number"
											bind:value={product.free_qty}
											on:input={markAsChanged}
											step="1"
											min="0"
											placeholder="0"
											class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-2 focus:ring-green-500 focus:border-green-500 outline-none"
										/>
									</td>
									<td class="w-24 px-4 py-4 align-middle">
										<input
											type="number"
											bind:value={product.limit_qty}
											on:input={markAsChanged}
											step="1"
											min="1"
											placeholder="No limit"
											class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
										/>
									</td>
									<td class="w-28 px-4 py-4 align-middle">
										<input
											type="number"
											bind:value={product.cost}
											on:input={markAsChanged}
											step="0.01"
											min="0"
											placeholder="0.00"
											class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
										/>
									</td>
									<td class="w-28 px-4 py-4 align-middle text-xs font-medium text-blue-600 bg-blue-50">
										{calculateTotalCost(product.cost, product.offer_qty).toFixed(2)}
									</td>
									<td class="w-28 px-4 py-4 align-middle">
										<input
											type="number"
											bind:value={product.sales_price}
											on:input={markAsChanged}
											step="0.01"
											min="0"
											placeholder="0.00"
											class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
										/>
									</td>
									<td class="w-28 px-4 py-4 align-middle text-xs font-medium text-blue-600 bg-blue-50">
										{calculateTotalSalesPrice(product.sales_price, product.offer_qty).toFixed(2)}
									</td>
									<td class="w-28 px-4 py-4 align-middle">
										{#key `${product.barcode}-${product.offer_price}-${productsVersion}`}
											<input
												type="number"
												value={(product.offer_price * product.offer_qty).toFixed(2)}
												on:blur={(e) => {
													const totalOfferPrice = parseFloat(e.currentTarget.value) || 0;
													const qty = product.offer_qty || 1;
													const perUnitPrice = totalOfferPrice / qty;
													
													// Update per-unit price in the product
													const productIndex = selectedProducts.findIndex(p => p.barcode === product.barcode);
													if (productIndex !== -1) {
														selectedProducts = selectedProducts.map((p, idx) => 
															idx === productIndex 
																? { ...p, offer_price: perUnitPrice }
																: p
														);
														productsVersion++; // Force update
													}
													markAsChanged();
												}}
												step="0.01"
												min="0"
												placeholder="Total offer price"
												class="w-full px-2 py-1 text-xs border border-orange-300 rounded focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none bg-orange-50 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
											/>
										{/key}
									</td>
									<td class="w-28 px-4 py-4 align-middle text-xs font-bold {calculateProfitAmount(product.cost, product.sales_price, product.offer_qty) >= 0 ? 'text-green-600 bg-green-50' : 'text-red-600 bg-red-50'}">
										{calculateProfitAmount(product.cost, product.sales_price, product.offer_qty).toFixed(2)}
									</td>
									<td class="w-24 px-4 py-4 align-middle text-xs font-bold {calculateProfitPercentage(product.cost, product.sales_price) >= 0 ? 'text-green-600 bg-green-50' : 'text-red-600 bg-red-50'}">
										{calculateProfitPercentage(product.cost, product.sales_price).toFixed(2)}%
									</td>
									<td class="w-28 px-4 py-4 align-middle text-xs font-bold {calculateProfitAfterOffer(product.cost, product.offer_price, product.offer_qty) >= 0 ? 'text-green-600 bg-green-50' : 'text-red-600 bg-red-50'}">
										{calculateProfitAfterOffer(product.cost, product.offer_price, product.offer_qty).toFixed(2)}%
									</td>
									<td class="w-28 px-4 py-4 align-middle text-xs font-bold {calculateDecreaseAmount(product.sales_price, product.offer_price, product.offer_qty) >= 0 ? 'text-purple-600 bg-purple-50' : 'text-orange-600 bg-orange-50'}">
										{calculateDecreaseAmount(product.sales_price, product.offer_price, product.offer_qty).toFixed(2)}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	{/if}
	
	<!-- Hidden file input for Excel import -->
	<input
		type="file"
		bind:this={fileInput}
		on:change={handleFileImport}
		accept=".xlsx,.xls"
		class="hidden"
	/>
</div>

<!-- Success Modal -->
{#if showSuccessModal}
	<div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" on:click={() => showSuccessModal = false}>
		<div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 transform transition-all" on:click|stopPropagation>
			<!-- Header -->
			<div class="bg-gradient-to-r from-green-500 to-emerald-600 text-white px-6 py-4 rounded-t-2xl">
				<div class="flex items-center gap-3">
					<svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
					</svg>
					<h3 class="text-xl font-bold">All offer generation steps completed successfully!</h3>
				</div>
			</div>
			
			<!-- Content -->
			<div class="px-6 py-6">
				<div class="mb-6">
					<h4 class="text-sm font-semibold text-gray-700 mb-3 flex items-center gap-2">
						<svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
						</svg>
						Summary:
					</h4>
					<ul class="space-y-2 text-sm text-gray-600">
						<li class="flex items-start gap-2">
							<span class="text-purple-600 font-bold mt-0.5">•</span>
							<span><strong>B1:</strong> Target profit based</span>
						</li>
						<li class="flex items-start gap-2">
							<span class="text-blue-600 font-bold mt-0.5">•</span>
							<span><strong>B2:</strong> Increased qty for low profit</span>
						</li>
						<li class="flex items-start gap-2">
							<span class="text-green-600 font-bold mt-0.5">•</span>
							<span><strong>B3:</strong> Min decrease guarantee</span>
						</li>
						<li class="flex items-start gap-2">
							<span class="text-orange-600 font-bold mt-0.5">•</span>
							<span><strong>B4:</strong> Increased qty for offers &lt; 10</span>
						</li>
						<li class="flex items-start gap-2">
							<span class="text-pink-600 font-bold mt-0.5">•</span>
							<span><strong>B5:</strong> Recalculated for current qty</span>
						</li>
					</ul>
				</div>
				
				<div class="bg-blue-50 border-l-4 border-blue-500 p-4 rounded">
					<p class="text-sm text-blue-800">
						<strong>Next step:</strong> Review the results and click <strong>"Save All Changes"</strong> to save.
					</p>
				</div>
			</div>
			
			<!-- Footer -->
			<div class="px-6 py-4 bg-gray-50 rounded-b-2xl flex justify-end">
				<button
					on:click={() => showSuccessModal = false}
					class="px-6 py-2.5 bg-gradient-to-r from-green-600 to-emerald-600 text-white font-semibold rounded-lg hover:shadow-lg transform hover:-translate-y-0.5 transition-all duration-200"
				>
					OK
				</button>
			</div>
		</div>
	</div>
{/if}
