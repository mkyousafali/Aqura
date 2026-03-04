<script lang="ts">
	import ExcelJS from 'exceljs';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { iconUrlMap } from '$lib/stores/iconStore';
	import { currentUser } from '$lib/utils/persistentAuth';

	// Branch & ERP Types
	interface BranchErp {
		branch_id: number;
		branch_name_en: string;
		branch_name_ar: string;
		location_en: string;
		location_ar: string;
		tunnel_url: string;
		erp_branch_id: number | null;
	}

	// Near Expiry Manager Component
	// Placeholder functions for buttons - to be implemented
	let activeButton: string | null = null;
	let importedData: any[] = [];
	let filteredData: any[] = [];
	let searchQuery: string = '';
	let fileInput: HTMLInputElement;
	let targetPrice: number | string = 16;
	let offerInputs: Map<number, any> = new Map();
	let vatPercent: number = 15; // VAT percentage (default 15%)

	// Send Task Modal State
	let showSendTaskModal: boolean = false;
	let taskToSendBarcode: string | null = null;
	let taskToSendProduct: any | null = null;
	let taskSelectedUser: string | null = null;
	let taskSelectedUserName: string | null = null;
	let availableUsers: any[] = [];
	let taskUserSearchQuery: string = ''; // Search filter for users
	let loadingUsers: boolean = false;
	let sendingTask: boolean = false;
	let foundBarcodes: Set<string> = new Set(); // Track found barcodes

	// Branch selection
	let branches: BranchErp[] = [];
	let selectedBranchId: number | null = null;
	let loadingBranches = false;
	let fetchingProductNames = false;
	let showBranchDropdown = false;

	// Edit mode for price fields
	let editingRowIndex: number | null = null;
	let editingField: string | null = null; // 'salesPrice' or 'cost'
	let editingValue: string = '';

	// Column visibility management
	let visibleColumns: Record<string, boolean> = {
		delete: true,
		sNo: true,
		barcode: true,
		systemExpiryDate: true,
		productName: true,
		salesPrice: true,
		totalSalesPrice: true,
		unit: true,
		cost: true,
		totalCost: true,
		expiryDate: true,
		offerEndDate: true,
		daysLeft: true,
		remainingDays: true,
		toDo: true,
		offerPrice: true,
		totalOfferPrice: true,
		offerDecrease: true,
		profitPercent: true,
		offerType: true,
		offerQty: true,
		free: true,
		limit: true,
		sendTask: false
	};

	const columnList = [
		{ key: 'delete', label: 'Delete' },
		{ key: 'sNo', label: 'S.No' },
		{ key: 'barcode', label: 'Barcode' },
		{ key: 'systemExpiryDate', label: 'System Expiry Date' },
		{ key: 'productName', label: 'Product Name' },
		{ key: 'salesPrice', label: 'Sales Price' },
		{ key: 'totalSalesPrice', label: 'Total Sales Price' },
		{ key: 'unit', label: 'Unit' },
		{ key: 'cost', label: 'Cost (VAT)' },
		{ key: 'totalCost', label: 'Total Cost' },
		{ key: 'expiryDate', label: 'Expiry Date' },
		{ key: 'offerEndDate', label: 'Offer End Date' },
		{ key: 'daysLeft', label: 'Days Left' },
		{ key: 'remainingDays', label: 'Remaining Days' },
		{ key: 'toDo', label: 'To Do' },
		{ key: 'offerPrice', label: 'Offer Price' },
		{ key: 'totalOfferPrice', label: 'Total Offer Price' },
		{ key: 'offerDecrease', label: 'Offer Decrease' },
		{ key: 'profitPercent', label: 'Profit %' },
		{ key: 'offerType', label: 'Offer Type' },
		{ key: 'offerQty', label: 'Offer Qty' },
		{ key: 'free', label: 'Free' },
		{ key: 'limit', label: 'Limit' },
		{ key: 'sendTask', label: 'Send Task' }
	];

	// Print functionality
	interface ShelfPaperTemplate {
		id: string;
		name: string;
		description: string | null;
		template_image_url: string;
		field_configuration: any[];
		metadata: any;
	}

	let templates: ShelfPaperTemplate[] = [];
	let selectedTemplateId: string | null = null;
	let isLoadingTemplates = false;

	interface CustomFont {
		id: string;
		name: string;
		font_url: string;
	}
	let customFonts: CustomFont[] = [];

	function buildFontFaceCss(): string {
		return customFonts.map(f => "@font-face{font-family:'" + f.name + "';src:url('" + f.font_url + "');font-display:swap;}").join('');
	}

	// Load templates on component mount
	onMount(() => {
		loadTemplates();
		loadCustomFonts();
		loadBranches();
	});

	// Load templates on component mount
	onMount(() => {
		loadTemplates();
		loadCustomFonts();
		loadBranches();
	});

	async function loadBranches() {
		loadingBranches = true;
		try {
			// Get active ERP connections
			const { data: erpConns, error: erpErr } = await supabase
				.from('erp_connections')
				.select('branch_id, tunnel_url, erp_branch_id')
				.eq('is_active', true)
				.order('branch_id');

			if (erpErr || !erpConns || erpConns.length === 0) {
				console.error('Error loading ERP connections:', erpErr);
				return;
			}

			// Get branch names
			const branchIds = erpConns.map((c: any) => c.branch_id);
			const { data: branchData, error: brErr } = await supabase
				.from('branches')
				.select('id, name_en, name_ar, location_en, location_ar')
				.in('id', branchIds);

			if (brErr) {
				console.error('Error loading branches:', brErr);
				return;
			}

			const branchMap = new Map((branchData || []).map((b: any) => [Number(b.id), b]));

			branches = erpConns
				.filter((c: any) => c.tunnel_url)
				.map((c: any) => {
					const info = branchMap.get(Number(c.branch_id)) as {name_en?: string; name_ar?: string; location_en?: string; location_ar?: string} | undefined;
					return {
						branch_id: c.branch_id,
						branch_name_en: info?.name_en || `Branch ${c.branch_id}`,
						branch_name_ar: info?.name_ar || `فرع ${c.branch_id}`,
						location_en: info?.location_en || '',
						location_ar: info?.location_ar || '',
						tunnel_url: c.tunnel_url,
						erp_branch_id: c.erp_branch_id
					};
				});
		} catch (err) {
			console.error('Error loading branches:', err);
		} finally {
			loadingBranches = false;
		}
	}

	async function fetchProductNamesFromBranch() {
		if (!selectedBranchId || importedData.length === 0) {
			console.warn('No branch selected or no data imported');
			return;
		}

		fetchingProductNames = true;
		try {
			const branch = branches.find(b => b.branch_id === selectedBranchId);
			if (!branch) return;

			const barcodes = importedData.map(row => row.barcode).filter(bc => bc);

			// Fetch product names AND sales price from price-check
			const batchSize = 10;
			const productData = new Map<string, {en: string; ar: string; salesPrice: number; cost: number; unit: string; batchId?: number}>();

			for (let i = 0; i < barcodes.length; i += batchSize) {
				const batch = barcodes.slice(i, i + batchSize);
				const batchPromises = batch.map(async (bc) => {
					try {
						const response = await fetch('/api/erp-products', {
							method: 'POST',
							headers: { 'Content-Type': 'application/json' },
							body: JSON.stringify({
								action: 'price-check',
								tunnelUrl: branch.tunnel_url,
								barcode: bc,
								erpBranchId: branch.erp_branch_id
							})
						});
						const result = await response.json();
						// Extract product names and sales price from price-check
						if (result.success && result.productName && result.prices && result.prices.length > 0) {
							const price = result.prices[0];
							productData.set(bc, {
								en: result.productName || '',
								ar: result.productNameAr || '',
								salesPrice: price.sprice ?? 0,
								cost: 0, // Will be populated by cost SQL query below
								unit: price.unit_name || '' // Use price-check unit as initial, will be overridden by batch query if available
							});
						}
					} catch (err) {
						console.debug(`Error fetching price for barcode ${bc}:`, err);
					}
				});
				await Promise.all(batchPromises);
			}

			// Now fetch BATCH DETAILS including unit names (exact same as PriceVerifier)
			const barcodeList = barcodes.map(bc => `'${bc.replace(/'/g, "''")}'`).join(',');
			const branchFilter = branch.erp_branch_id != null ? `AND pb.BranchID = ${branch.erp_branch_id}` : '';
			
			const costSql = `
			SELECT SearchBarcode, Cost AS LandingCost, MultiFactor,
				ProductBatchID AS BatchID
			FROM (
				SELECT SearchBarcode, Cost, MultiFactor,
					ROW_NUMBER() OVER (PARTITION BY SearchBarcode ORDER BY ProductBatchID DESC) AS rn,
					ProductBatchID
				FROM (
					-- ProductUnit barcodes: USE MultiFactor of that specific unit
					SELECT pu.BarCode AS SearchBarcode,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) * pu.MultiFactor AS Cost,
						pu.MultiFactor,
						pb.ProductBatchID
					FROM ProductUnits pu
					INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
					WHERE pu.BarCode IN (${barcodeList}) ${branchFilter}

					UNION ALL

					-- MannualBarcode: NO multiplication (alternative barcode for same product)
					SELECT pb.MannualBarcode AS SearchBarcode,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						1 AS MultiFactor,
						pb.ProductBatchID
					FROM ProductBatches pb
					WHERE pb.MannualBarcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))

					UNION ALL

					-- AutoBarcode: NO multiplication (alternative barcode for same product)
					SELECT CAST(pb.AutoBarcode AS NVARCHAR(100)) AS SearchBarcode,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						1 AS MultiFactor,
						pb.ProductBatchID
					FROM ProductBatches pb
					WHERE CAST(pb.AutoBarcode AS NVARCHAR(100)) IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
					AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))

					UNION ALL

					-- Unit2Barcode: NO multiplication (alternative barcode for same product)
					SELECT pb.Unit2Barcode AS SearchBarcode,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						1 AS MultiFactor,
						pb.ProductBatchID
					FROM ProductBatches pb
					WHERE pb.Unit2Barcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
					AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))
					AND (CAST(pb.AutoBarcode AS NVARCHAR(100)) IS NULL OR CAST(pb.AutoBarcode AS NVARCHAR(100)) NOT IN (${barcodeList}))

					UNION ALL

					-- Unit3Barcode: NO multiplication (alternative barcode for same product)
					SELECT pb.Unit3Barcode AS SearchBarcode,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						1 AS MultiFactor,
						pb.ProductBatchID
					FROM ProductBatches pb
					WHERE pb.Unit3Barcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
					AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))
					AND (CAST(pb.AutoBarcode AS NVARCHAR(100)) IS NULL OR CAST(pb.AutoBarcode AS NVARCHAR(100)) NOT IN (${barcodeList}))
					AND (pb.Unit2Barcode IS NULL OR pb.Unit2Barcode NOT IN (${barcodeList}))

					UNION ALL

					-- ProductBarcodes: NO multiplication (alternative barcode for same product)
					SELECT pbc.Barcode AS SearchBarcode,
						COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
						1 AS MultiFactor,
						pbc.ProductBatchID
					FROM ProductBarcodes pbc
					INNER JOIN ProductBatches pb ON pbc.ProductBatchID = pb.ProductBatchID
					WHERE pbc.Barcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pbc.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
				) AS Combined
			) AS Ranked
			WHERE rn = 1
			`;

			try {
				const costResponse = await fetch('/api/erp-products', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify({ action: 'query', tunnelUrl: branch.tunnel_url, sql: costSql })
				});
				const costResult = await costResponse.json();
				
				// DEBUG: Log cost result
				console.log('💰 Cost SQL Result:', costResult);
				if (costResult.recordset) {
					console.log(`Found ${costResult.recordset.length} cost records`);
					costResult.recordset.forEach((r: any) => {
						console.log(`  Barcode: ${r.SearchBarcode}, Cost: ${r.LandingCost}, MultiFactor: ${r.MultiFactor}`);
					});
				}
				
				const batchIds = new Set<number>();
				const barcodeToSearchBarcode = new Map<string, string>(); // Map input barcode to SearchBarcode
				const barcodeToSearchBarcodeList: Array<{ inputBarcode: string; searchBarcode: string; batchId: number }> = [];
				
				// DEBUG: Log input barcodes
				console.log('🔍 Imported barcodes:', barcodes);
				
				if (costResult.success && costResult.recordset) {
					console.log(`Processing ${costResult.recordset.length} cost records...`);
					for (const row of costResult.recordset) {
						const searchBc = String(row.SearchBarcode).trim();
						console.log(`  Checking returned barcode: "${searchBc}" (length: ${searchBc.length})`);
						
						// Try to find a matching input barcode
						let found = false;
						for (const inputBc of barcodes) {
							const inputBcTrimmed = inputBc.trim().toLowerCase();
							const searchBcLower = searchBc.toLowerCase();
							console.log(`    Compare: "${inputBc}" (trim: "${inputBcTrimmed}") === "${searchBc}" (lower: "${searchBcLower}") ? ${inputBcTrimmed === searchBcLower}`);
							
							if (inputBcTrimmed === searchBcLower) {
								batchIds.add(row.BatchID);
								barcodeToSearchBarcode.set(inputBc, searchBc);
								barcodeToSearchBarcodeList.push({ 
									inputBarcode: inputBc,
									searchBarcode: searchBc,
									batchId: row.BatchID 
								});
								foundBarcodes.add(inputBc); // Track found barcode
								// Apply cost to productData
								const existing = productData.get(inputBc);
								if (existing) {
									existing.cost = row.LandingCost ?? 0;
									console.log(`✅ MATCHED & Applied cost ${row.LandingCost} to barcode ${inputBc}`);
									found = true;
									break;
								} else {
									console.warn(`⚠️ Matched but NOT in productData: ${inputBc}`);
									found = true;
									break;
								}
							}
						}
						if (!found) {
							console.warn(`❌ NO MATCH for returned barcode: "${searchBc}"`);
						}
					}
				}

				// Now fetch unit names using batch IDs (exact same as PriceVerifier)
				if (batchIds.size > 0) {
					const batchIdList = Array.from(batchIds).join(',');
					const detailSql = `
						SELECT pu.ProductBatchID, pu.MultiFactor,
							(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um WHERE um.UnitID = pu.UnitID) AS UnitName
						FROM ProductUnits pu
						INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
						WHERE pu.ProductBatchID IN (${batchIdList}) ${branchFilter}
						ORDER BY pu.ProductBatchID, pu.MultiFactor ASC
					`;

					try {
						const detailResp = await fetch('/api/erp-products', {
							method: 'POST',
							headers: { 'Content-Type': 'application/json' },
							body: JSON.stringify({ action: 'query', tunnelUrl: branch.tunnel_url, sql: detailSql })
						});
						const detailResult = await detailResp.json();
						if (detailResult.success && detailResult.recordset) {
							// Map BatchID -> UnitName (use first result per batch = lowest multiplier)
							const batchToUnit = new Map<number, string>();
							for (const d of detailResult.recordset) {
								const batchId = d.ProductBatchID;
								if (batchId && d.UnitName && !batchToUnit.has(batchId)) {
									batchToUnit.set(batchId, d.UnitName);
								}
							}
							
							// Now apply units to products using the mapping
							for (const mapping of barcodeToSearchBarcodeList) {
								const unitName = batchToUnit.get(mapping.batchId);
								if (unitName) {
									const existing = productData.get(mapping.inputBarcode);
									if (existing) {
										existing.unit = unitName;
									}
								}
							}
						}
					} catch (err) {
						console.error(`Error fetching unit details:`, err);
					}
				}
			} catch (err) {
				console.error(`Error fetching batch details:`, err);
			}

			// Update imported data with fetched product data
			console.log('📊 ProductData Map before update:', Array.from(productData.entries()));
			
			importedData = importedData.map(row => {
				const data = productData.get(row.barcode);
				if (data) {
					console.log(`Updating row ${row.barcode}: cost before=${row.cost}, cost after=${data.cost}`);
					return {
						...row,
						englishName: data.en || row.englishName,
						arabicName: data.ar || row.arabicName,
						salesPrice: data.salesPrice || row.salesPrice,
						cost: data.cost || row.cost,
						unit: data.unit || row.unit,
						notFound: false
					};
				}
				// Mark barcode as not found if it wasn't in the cost query results
				const isNotFound = !foundBarcodes.has(row.barcode);
				if (isNotFound) {
					console.log(`⚠️ Barcode NOT FOUND: ${row.barcode}`);
				}
				return {
					...row,
					notFound: isNotFound
				};
			});
			console.log('✅ ImportedData after update:', importedData);
			
			// Fetch system expiry dates from Supabase
			await fetchSystemExpiryDates();
		} catch (err) {
			console.error('Error fetching product data:', err);
		} finally {
			fetchingProductNames = false;
		}
	}

	async function loadCustomFonts() {
		try {
			const { data, error } = await supabase
				.from('shelf_paper_fonts')
				.select('id, name, font_url')
				.order('name', { ascending: true });
			if (error) throw error;
			customFonts = data || [];
		} catch (e) {
			console.error('Error loading custom fonts:', e);
		}
	}

	// Load available employees for task assignment (all users + reporters of THIS barcode)
	async function loadTaskAssignmentUsers() {
		loadingUsers = true;
		try {
			// Get all employees
			const { data: allEmployees, error: empError } = await supabase
				.from('hr_employee_master')
				.select('id, user_id, name_en, name_ar, current_branch_id')
				.order('name_en', { ascending: true });
			
			if (empError) throw empError;

			// Get reporter_user_ids who reported THIS SPECIFIC barcode
			let reporterUserIds = new Set<string>();
			
			if (taskToSendBarcode) {
				const { data: barcodeReports, error: reportError } = await supabase
					.from('near_expiry_reports')
					.select('reporter_user_id, items')
					.not('reporter_user_id', 'is', null);
				
				if (reportError && reportError.code !== 'PGRST116') {
					console.warn('Warning loading barcode reports:', reportError);
				}

				// Filter for reports containing THIS barcode
				(barcodeReports || []).forEach((report: any) => {
					if (report.items && Array.isArray(report.items)) {
						const hasBarcodeInItems = report.items.some((item: any) => 
							item.barcode === taskToSendBarcode
						);
						if (hasBarcodeInItems && report.reporter_user_id) {
							reporterUserIds.add(report.reporter_user_id);
						}
					}
				});
				
				console.log(`🔍 Found ${reporterUserIds.size} users who reported barcode ${taskToSendBarcode}`);
			}

			// Combine: all employees + mark those who reported THIS barcode
			const userMap = new Map<string, any>();
			
			// Add all employees
			(allEmployees || []).forEach((emp: any) => {
				userMap.set(emp.user_id, {
					...emp,
					isHighlighted: reporterUserIds.has(emp.user_id)
				});
			});

			// Convert to array and sort (highlighted first, then by name)
			availableUsers = Array.from(userMap.values()).sort((a, b) => {
				if (a.isHighlighted && !b.isHighlighted) return -1;
				if (!a.isHighlighted && b.isHighlighted) return 1;
				return (a.name_en || a.id).localeCompare(b.name_en || b.id);
			});

			console.log('📋 Available users loaded:', availableUsers.length, '(highlighted:', reporterUserIds.size, ')');
		} catch (err) {
			console.error('Error loading users:', err);
			availableUsers = [];
		} finally {
			loadingUsers = false;
		}
	}

	// Open send task modal for a specific barcode
	async function openSendTaskModal(barcode: string, product: any) {
		taskToSendBarcode = barcode;
		taskToSendProduct = product;
		taskSelectedUser = null;
		taskSelectedUserName = null;
		taskUserSearchQuery = ''; // Clear search
		showSendTaskModal = true;
		
		// Fetch photo from near_expiry_reports
		try {
			const { data: reports } = await supabase
				.from('near_expiry_reports')
				.select('items')
				.not('items', 'is', null);

			if (reports) {
				for (const report of reports) {
					if (report.items && Array.isArray(report.items)) {
						const item = report.items.find((i: any) => i.barcode === barcode);
						if (item && item.photo_url) {
							taskToSendProduct = { ...taskToSendProduct, photo_url: item.photo_url };
							break;
						}
					}
				}
			}
		} catch (err) {
			console.warn('⚠️ Failed to fetch photo from near_expiry_reports:', err);
		}
		
		// Load users when modal opens
		if (availableUsers.length === 0) {
			await loadTaskAssignmentUsers();
		}
	}

	// Send quick task for unfound barcode or system date mismatch
	async function sendQuickTask() {
		if (!taskSelectedUser || !taskToSendBarcode) {
			alert('Please select a user');
			return;
		}

		sendingTask = true;
		try {
			// Use current user from auth store
			if (!$currentUser) throw new Error('Not authenticated - please login again');
			
			const userId = $currentUser.id;

			// Fetch photo_url from near_expiry_reports for this barcode
			let photoUrl = null;
			const { data: reports, error: reportError } = await supabase
				.from('near_expiry_reports')
				.select('items')
				.not('items', 'is', null);

			if (!reportError && reports) {
				for (const report of reports) {
					if (report.items && Array.isArray(report.items)) {
						const item = report.items.find((i: any) => i.barcode === taskToSendBarcode);
						if (item && item.photo_url) {
							photoUrl = item.photo_url;
							break;
						}
					}
				}
			}

			// Determine task reason: barcode not found or system date mismatch
			const isDateMismatch = isExpiryDateMismatch(taskToSendProduct?.expiryDate, taskToSendProduct?.systemExpiryDate);
			const isNotFound = taskToSendProduct?.notFound || !isDateMismatch;

			// Create quick task with appropriate title and description
			let taskTitle: string;
			let taskDescription: string;
			let issueType: string;

			if (isDateMismatch) {
				// Task for system date mismatch
				const formattedImportedDate = formatExpiryDate(String(taskToSendProduct?.expiryDate || ''));
				taskTitle = `System Date Mismatch | عدم توافق تاريخ النظام: ${taskToSendBarcode}`;
				taskDescription = `Product: ${taskToSendProduct?.englishName || taskToSendBarcode}\nBarcode: ${taskToSendBarcode}\nProduct AR: ${taskToSendProduct?.arabicName || ''}\n\nImported Expiry Date: ${formattedImportedDate || '—'}\nSystem Expiry Date: ${taskToSendProduct?.systemExpiryDate || '—'}\n\nPlease verify and reconcile the expiry date mismatch in the ERP system.`;
				issueType = 'date_verification';
			} else {
				// Task for barcode not found
				taskTitle = `Barcode Not Found | لم يتم العثور على الباركود: ${taskToSendBarcode}`;
				taskDescription = `Product: ${taskToSendProduct?.englishName || taskToSendBarcode}\nBarcode: ${taskToSendBarcode}\nProduct AR: ${taskToSendProduct?.arabicName || ''}\n\nPlease check inventory and provide product information for this barcode.`;
				issueType = 'product_verification';
			}
			
			// Add photo URL to description if available
			if (photoUrl) {
				taskDescription += `\n\n📸 Photo URL: ${photoUrl}`;
			}
			
			const { data: quickTaskData, error: taskError } = await supabase
				.from('quick_tasks')
				.insert({
					title: taskTitle,
					description: taskDescription,
					priority: 'medium',
					issue_type: issueType,
					assigned_by: userId,
					assigned_to_branch_id: selectedBranchId,
					price_tag: taskToSendBarcode,
					require_task_finished: true,
					require_photo_upload: true,
					require_erp_reference: false
				})
				.select()
				.single();

			if (taskError) {
				console.error('❌ Task creation error:', taskError);
				throw taskError;
			}

			console.log('✅ Quick task created:', { id: quickTaskData.id, title: taskTitle });

			// Create assignment for selected user with photo upload requirement
			const assignmentPayload = {
				quick_task_id: quickTaskData.id,
				assigned_to_user_id: taskSelectedUser,
				require_task_finished: true,
				require_photo_upload: true, // CRITICAL: Always require photo upload
				require_erp_reference: false
			};

			console.log('📝 Assignment creation:');
			console.log('  Task ID:', quickTaskData.id);
			console.log('  Assigned to user:', taskSelectedUser);
			console.log('  Photo upload required:', true);
			console.log('  Full payload:', assignmentPayload);

			const { data: assignmentData, error: assignmentError } = await supabase
				.from('quick_task_assignments')
				.insert(assignmentPayload)
				.select('id, quick_task_id, assigned_to_user_id, require_task_finished, require_photo_upload, require_erp_reference')
				.single();

			if (assignmentError) {
				console.error('❌ Assignment creation FAILED:');
				console.error('  Error:', assignmentError.message);
				console.error('  Code:', assignmentError.code);
				console.error('  Details:', assignmentError.details);
				console.error('  Payload attempted:', assignmentPayload);
				throw assignmentError;
			}

			console.log('✅ Assignment created successfully');
			console.log('  ID:', assignmentData?.id);
			console.log('  require_photo_upload from DB:', assignmentData?.require_photo_upload);
			
			// CRITICAL: Verify photo requirement was saved
			if (assignmentData?.require_photo_upload !== true) {
				console.error('❌ CRITICAL ERROR: Photo upload requirement NOT saved!');
				console.error('  Expected: true, Got:', assignmentData?.require_photo_upload);
			}
			
			// Mark barcode as having task sent
			importedData = importedData.map(row => 
				row.barcode === taskToSendBarcode 
					? { ...row, taskSent: true } 
					: row
			);

			// Close modal
			showSendTaskModal = false;
			taskUserSearchQuery = ''; // Clear search
			alert(`Task successfully sent to ${taskSelectedUserName} for barcode ${taskToSendBarcode}`);
		} catch (err: any) {
			console.error('Error sending task:', err);
			alert(`Error sending task: ${err.message}`);
		} finally {
			sendingTask = false;
		}
	}

	function scrollToInvalidRow(index: number) {
		const tableRows = document.querySelectorAll('tbody tr');
		if (tableRows[index]) {
			tableRows[index].scrollIntoView({ behavior: 'smooth', block: 'center' });
			// Flash the row
			const row = tableRows[index] as HTMLElement;
			row.classList.add('animate-pulse');
			setTimeout(() => {
				row.classList.remove('animate-pulse');
			}, 2000);
		}
	}

	// Filter products by search query
	$: {
		if (!searchQuery.trim()) {
			filteredData = importedData;
		} else {
			const query = searchQuery.toLowerCase();
			filteredData = importedData.filter(product => {
				const englishName = (product.englishName || '').toLowerCase();
				const arabicName = (product.arabicName || '').toLowerCase();
				const barcode = (product.barcode || '').toLowerCase();
				return englishName.includes(query) || arabicName.includes(query) || barcode.includes(query);
			});
		}
	}

	async function onImportFromExcel() {
		fileInput.click();
	}

	// Load shelf paper templates from database
	async function loadTemplates() {
		isLoadingTemplates = true;
		try {
			const { data, error } = await supabase
				.from('shelf_paper_templates')
				.select('*')
				.order('created_at', { ascending: false });

			if (error) {
				console.error('Error loading templates:', error);
				templates = [];
			} else {
				templates = data || [];
			}
		} catch (error) {
			console.error('Error loading templates:', error);
			templates = [];
		} finally {
			isLoadingTemplates = false;
		}
	}

	// Print shelf paper using selected template
	function printShelfPaper() {
		if (!selectedTemplateId) {
			alert('Please select a template first');
			return;
		}

		if (filteredData.length === 0) {
			alert('No products to print');
			return;
		}

		const template = templates.find(t => t.id === selectedTemplateId);
		if (!template) {
			alert('Template not found');
			return;
		}

		const printWindow = window.open('', '_blank');
		if (!printWindow) {
			alert('Please allow pop-ups to print');
			return;
		}

		// A4 dimensions in pixels at 96 DPI
		const a4Width = 794;
		const a4Height = 1123;

		// Build HTML for printing
		let allPagesHtml = '';

		// Load template image and process each product
		const tempImg = new Image();
		
		tempImg.onload = function () {
			const fields = template.field_configuration || [];

			// Calculate scale factors if metadata exists
			let scaleX = 1;
			let scaleY = 1;
			if (template.metadata) {
				scaleX = a4Width / (template.metadata.preview_width || a4Width);
				scaleY = a4Height / (template.metadata.preview_height || a4Height);
			}

			let serialCounter = 1;

			// Process each product
			filteredData.forEach((product) => {
				let productFieldsHtml = '';

				// Render each field on the template
				fields.forEach((field: any) => {
					let value = '';

					// Map field label to product data
					switch (field.label) {
						case 'product_name_en':
							value = product.englishName || '';
							break;
						case 'product_name_ar':
							value = product.arabicName || '';
							break;
						case 'barcode':
							value = product.barcode || '';
							break;
						case 'serial_number':
							value = serialCounter.toString();
							break;
						case 'unit_name':
							value = product.unit || '';
							break;
						case 'price':
							// Calculate total sales price: salesPrice * offerQty
							const salesPrice = product.salesPrice ? parseFloat(product.salesPrice) : 0;
							const qty = product.offerQty ? parseInt(product.offerQty) : 1;
							const totalSalesPrice = (salesPrice * qty).toFixed(2);
							value = totalSalesPrice;
							break;
						case 'offer_price':
							// Calculate total offer price: offerPrice * offerQty, using roundTo95 logic
							const offerPriceUnit = product.offerPrice || product.offer_price;
							const qtyOffer = product.offerQty ? parseInt(product.offerQty) : 1;
							if (offerPriceUnit) {
								const totalOfferPriceRaw = parseFloat(offerPriceUnit) * qtyOffer;
								// Apply roundTo95 logic
								const intPart = Math.floor(totalOfferPriceRaw);
								const candidate1 = intPart + 0.95;
								const candidate2 = (intPart - 1) + 0.95;
								const distance1 = Math.abs(totalOfferPriceRaw - candidate1);
								const distance2 = Math.abs(totalOfferPriceRaw - candidate2);
								const rounded = distance1 <= distance2 ? candidate1 : candidate2;
								value = rounded.toFixed(2);
							} else {
								value = '';
							}
							break;
						case 'offer_qty':
							value = product.offerQty ? product.offerQty.toString() : '1';
							break;
						case 'limit_qty':
							value = product.limitQty ? product.limitQty.toString() : '';
							break;
						case 'expire_date':
							if (product.expiryDate) {
								try {
									const dateParts = product.expiryDate.split('-');
									if (dateParts.length === 3) {
										// Format is DD-MM-YYYY
										const day = parseInt(dateParts[0]);
										const month = parseInt(dateParts[1]) - 1;
										const year = parseInt(dateParts[2]);
										const dateObj = new Date(year, month, day);
										
										if (!isNaN(dateObj.getTime())) {
											const dateEnglish = dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
											const dateArabic = dateObj.toLocaleDateString('ar-SA', { month: 'long', day: 'numeric', year: 'numeric' });
											value = '<div>Product expires on (' + dateEnglish + ')</div><div>ينتهي المنتج في (' + dateArabic + ')</div>';
										} else {
											value = product.expiryDate;
										}
									} else {
										value = product.expiryDate;
									}
								} catch (e) {
									value = product.expiryDate;
									console.error('Error parsing expire date:', e);
								}
							} else {
								value = '';
							}
							break;
						case 'offer_end_date':
							if (product.offerEndDate) {
								try {
									let dateObj: Date;
									const offerEndStr = String(product.offerEndDate).trim();
									
									// Try to parse different date formats
									if (offerEndStr.includes('-')) {
										const dateParts = offerEndStr.split('-');
										if (dateParts.length === 3) {
											// Try DD-MM-YYYY format first
											if (dateParts[0].length === 2 && dateParts[1].length === 2 && dateParts[2].length === 4) {
												const day = parseInt(dateParts[0]);
												const month = parseInt(dateParts[1]) - 1;
												const year = parseInt(dateParts[2]);
												dateObj = new Date(year, month, day);
											} else {
												// Try YYYY-MM-DD format
												dateObj = new Date(offerEndStr);
											}
										} else {
											dateObj = new Date(offerEndStr);
										}
									} else if (typeof product.offerEndDate === 'number') {
										// Handle Excel serial date format
										const excelDate = new Date(1900, 0, product.offerEndDate);
										dateObj = excelDate;
									} else {
										dateObj = new Date(offerEndStr);
									}
									
									if (!isNaN(dateObj.getTime())) {
										const dateEnglish = dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
										const dateArabic = dateObj.toLocaleDateString('ar-SA', { month: 'long', day: 'numeric', year: 'numeric' });
										value = '<div>Offer expires on ' + dateEnglish + '</div><div>ينتهي العرض في ' + dateArabic + '</div>';
									} else {
										value = offerEndStr;
									}
								} catch (e) {
									value = String(product.offerEndDate);
									console.error('Error parsing offer_end_date:', e);
								}
							} else {
								value = '';
							}
							break;
						case 'product_expiry_date':
							if (product.expiryDate) {
								try {
									let dateObj: Date;
									const expiryVal = product.expiryDate;
									
									// Handle if it's already a Date object
									if (expiryVal instanceof Date) {
										dateObj = expiryVal;
									} else {
										const expiryStr = String(expiryVal).trim();
										const dateParts = expiryStr.split('-');
										if (dateParts.length === 3) {
											// Format is DD-MM-YYYY
											const day = parseInt(dateParts[0]);
											const month = parseInt(dateParts[1]) - 1;
											const year = parseInt(dateParts[2]);
											dateObj = new Date(year, month, day);
										} else {
											// Try parsing as Date string
											dateObj = new Date(expiryStr);
										}
									}
									
									if (!isNaN(dateObj.getTime())) {
										const dateEnglish = dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
										const dateArabic = dateObj.toLocaleDateString('ar-SA', { month: 'long', day: 'numeric', year: 'numeric' });
										value = '<div>Product expires on ' + dateEnglish + '</div><div>ينتهي المنتج في ' + dateArabic + '</div>';
									} else {
										value = String(product.expiryDate);
									}
								} catch (e) {
									value = String(product.expiryDate);
									console.error('Error parsing product_expiry_date:', e);
								}
							} else {
								value = '';
								console.log('product.expiryDate is empty or undefined for product:', product);
							}
							break;
					}

					if (value) {
						const scaledX = Math.round(field.x * scaleX);
						const scaledY = Math.round(field.y * scaleY);
						const scaledWidth = Math.round(field.width * scaleX);
						const scaledHeight = Math.round(field.height * scaleY);
						const scaledFontSize = Math.round(field.fontSize * scaleX);

						const justifyContent = field.alignment === 'center' ? 'center' : field.alignment === 'right' ? 'flex-end' : 'flex-start';
						const dirAttr = field.label === 'product_name_ar' ? 'direction:rtl;' : '';
						const fontWeight = field.label.includes('price') || field.label.includes('offer') ? 'font-weight:bold;' : 'font-weight:600;';
						const fontFamilyStyle = field.fontFamily ? "font-family:'" + field.fontFamily + "',sans-serif;" : '';

						let displayValue = value;
						if ((field.label === 'price' || field.label === 'offer_price') && value.includes('.')) {
							const parts = value.split('.');
							const halfFontSize = Math.round(scaledFontSize * 0.5);
							if (field.label === 'price') {
								// Price field: same font size for integer and decimal, with strikethrough, half-size currency
								displayValue = '<div style="display:flex;align-items:baseline;"><img src="' + ($iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png') + '" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR"><span style="font-size:' + scaledFontSize + 'px;text-decoration:line-through;text-decoration-thickness:5px;">' + parts[0] + '.' + parts[1] + '</span></div>';
							} else {
								// Offer price field: smaller font for decimal
								displayValue = '<div style="display:flex;align-items:baseline;"><img src="' + ($iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png') + '" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR"><span style="font-size:' + scaledFontSize + 'px;">' + parts[0] + '</span><span style="font-size:' + halfFontSize + 'px;">.' + parts[1] + '</span></div>';
							}
						} else if (field.label === 'price' || field.label === 'offer_price') {
							const halfFontSize = Math.round(scaledFontSize * 0.5);
							const currencySymbol = '<img src="' + ($iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png') + '" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR">';
							if (field.label === 'price') {
								displayValue = currencySymbol + '<span style="text-decoration:line-through;text-decoration-thickness:5px;">' + value + '</span>';
							} else {
								displayValue = currencySymbol + value;
							}
						}

						// Determine if this field contains line breaks (check for <div> tags)
						const hasLineBreaks = displayValue.includes('<div>');
						const flexDirection = hasLineBreaks ? 'flex-direction:column;justify-content:flex-start;align-items:center;' : '';

						productFieldsHtml += '<div style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;"><div style="width:100%;height:100%;font-size:' + scaledFontSize + 'px;text-align:' + field.alignment + ';color:' + (field.color || '#000000') + ';display:flex;align-items:center;justify-content:' + justifyContent + ';' + flexDirection + fontWeight + dirAttr + fontFamilyStyle + '">' + displayValue + '</div></div>';
					}
			});

			let pageHtml = '<div style="position:relative;width:' + a4Width + 'px;height:' + a4Height + 'px;overflow:hidden;page-break-inside:avoid;background:white;display:block;">';
			pageHtml += '<img src="' + template.template_image_url + '" style="width:' + a4Width + 'px;height:' + a4Height + 'px;position:absolute;top:0;left:0;z-index:1;display:block;" alt="Template">';
			pageHtml += productFieldsHtml;
			pageHtml += '</div>';
			allPagesHtml += pageHtml;

			serialCounter++;
		});

			const htmlDoc = printWindow.document;
			htmlDoc.open();
			htmlDoc.write('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Shelf Paper</title></head><body>' + allPagesHtml + '</body></html>');
			htmlDoc.close();

			const styleEl = htmlDoc.createElement('style');
			styleEl.textContent = buildFontFaceCss() + '@page{size:A4;margin:0}body{margin:0;padding:0;font-family:Arial,sans-serif}div{page-break-inside:avoid}@media print{html,body{width:210mm;height:297mm;margin:0;padding:0}}';
			htmlDoc.head.appendChild(styleEl);

			setTimeout(() => {
				printWindow.print();
			}, 1000);
		};

		tempImg.src = template.template_image_url;
	}

	async function handleFileImport(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (!file) return;

		try {
			const arrayBuffer = await file.arrayBuffer();
			const workbook = new ExcelJS.Workbook();
			await workbook.xlsx.load(arrayBuffer);
			
			const worksheet = workbook.worksheets[0];
			if (!worksheet) {
				alert('No worksheet found in the file');
				return;
			}

			importedData = [];

			// Skip header row and process data rows
			worksheet.eachRow((row, rowNumber) => {
				if (rowNumber === 1) return; // Skip header

				const rowData = {
					barcode: row.getCell(1).value?.toString() || '',
					englishName: row.getCell(2).value?.toString() || '',
					arabicName: row.getCell(3).value?.toString() || '',
					salesPrice: row.getCell(4).value || '',
					unit: row.getCell(5).value?.toString() || '',
					cost: row.getCell(6).value || '',
					expiryDate: row.getCell(7).value?.toString() || '',
					offerPrice: row.getCell(8).value || '',
					offerQty: row.getCell(9).value?.toString() || '',
					limitQty: row.getCell(10).value?.toString() || '',
					offerEndDate: row.getCell(11).value?.toString() || ''
				};

				// Only add non-empty rows
				if (rowData.barcode || rowData.englishName || rowData.arabicName) {
					importedData.push(rowData);
				}
			});

			importedData = importedData; // Trigger reactivity
			
			// Sort by expiry date (earliest first)
			sortByExpiryDate();
			
			if (importedData.length === 0) {
				alert('No data found in the file');
			} else {
				alert(`Successfully imported ${importedData.length} products`);
			}
		} catch (error) {
			console.error('Error importing file:', error);
			alert('Error importing file. Please make sure it\'s a valid Excel file.');
		}

		// Reset file input
		target.value = '';
	}

	function onGenerateOfferEndDate() {
		// Calculate offer end dates for all products
		// Rule: Maximum 8 unique end dates ONLY
		// If remaining days > 35, prefer 12th of next month (but respect 5-day minimum)
		// Otherwise: Offer must end 5-20 days before expiry date
		
		if (importedData.length === 0) {
			alert('No products to generate offer end dates for');
			return;
		}

		const today = new Date();
		today.setHours(0, 0, 0, 0);

		// Calculate the 12th of next month
		const nextMonthDate = new Date(today);
		nextMonthDate.setMonth(nextMonthDate.getMonth() + 1);
		nextMonthDate.setDate(12);

		// Set minimum offer end date: at least 6 days from today
		const minOfferDate = new Date(today);
		minOfferDate.setDate(minOfferDate.getDate() + 6);

		// Step 1: Collect all valid products and their date ranges
		const validProducts = importedData.map((product, index) => {
			const remainingDays = getRemainingDays(product.expiryDate);
			const expiryDate = parseExpiryDateToTimestamp(product.expiryDate);
			
			if (expiryDate === Infinity) {
				return null;
			}

			const expiryObj = new Date(expiryDate);
			
			// Offer must end between 5-20 days BEFORE expiry
			// Latest end date: 5 days before expiry
			// Earliest end date: 20 days before expiry
			const latestEndDate = new Date(expiryObj);
			latestEndDate.setDate(latestEndDate.getDate() - 5); 
			
			const earliestEndDate = new Date(expiryObj);
			earliestEndDate.setDate(earliestEndDate.getDate() - 20); 
			
			// Skip products that expire too soon (latest end date is in the past)
			if (latestEndDate < today) {
				return null;
			}
			
			return {
				index,
				remainingDays: typeof remainingDays === 'number' ? remainingDays : 0,
				earliestEndDate,
				latestEndDate,
				expiryObj
			};
		}).filter(p => p !== null);

		if (validProducts.length === 0) {
			alert('No valid products to generate offer end dates for');
			return;
		}

		// Step 2: Create exactly 8 candidate dates (12-03-2026 is primary, alternatives for early expiries)
		const candidateDates: Date[] = [];
		
		// Helper function to check if date is in forbidden range (25-28 of any month)
		const isForbiddenDate = (date: Date) => {
			const day = date.getDate();
			return day >= 25 && day <= 28;
		};
		
		// First candidate: 12th of next month (PRIMARY)
		candidateDates.push(new Date(nextMonthDate));
		
		// Find products that expire before 12-03-2026 (need alternative dates)
		const earlyExpiryProducts = validProducts.filter(vp => vp.latestEndDate < nextMonthDate);
		
		if (earlyExpiryProducts.length > 0) {
			// Create up to 7 more dates spread across early expiry range
			// BUT respect minimum offer date (at least 6 days from today)
			const earliestEarlyDate = new Date(Math.max(
				minOfferDate.getTime(),
				Math.min(...earlyExpiryProducts.map(p => p.earliestEndDate.getTime()))
			));
			const latestEarlyDate = new Date(Math.max(...earlyExpiryProducts.map(p => p.latestEndDate.getTime())));
			
			const daysBetween = Math.ceil((nextMonthDate.getTime() - earliestEarlyDate.getTime()) / (1000 * 60 * 60 * 24));
			const stepSize = Math.max(1, Math.ceil(daysBetween / 7));
			
			for (let i = 0; i < 7 && candidateDates.length < 8; i++) {
				let candidate = new Date(earliestEarlyDate);
				candidate.setDate(candidate.getDate() + i * stepSize);
				
				// Skip forbidden dates (25-28 of any month)
				while (isForbiddenDate(candidate) && candidate < nextMonthDate) {
					candidate.setDate(candidate.getDate() + 1);
				}
				
				if (candidate >= minOfferDate && candidate < nextMonthDate && !candidateDates.some(d => d.getTime() === candidate.getTime())) {
					candidateDates.push(candidate);
				}
			}
		}

		// Ensure we have exactly 8 dates (pad with copies of 12-03-2026 if needed)
		while (candidateDates.length < 8) {
			candidateDates.push(new Date(nextMonthDate));
		}
		
		candidateDates.length = 8; // Trim to exactly 8

		console.log('Candidate dates:', candidateDates.map(d => formatExpiryDate(d)));

		// Step 3: Assign each product to best candidate date, ensuring minimum 5 days between offer end and expiry
		const nextMonthTwelfth = candidateDates[0]; // Always 12-03-2026
		
		importedData = importedData.map((product, index) => {
			const vp = validProducts.find(p => p.index === index);
			
			if (!vp) {
				return product; // Skip invalid products
			}

			let bestDate = nextMonthTwelfth;
			let bestDaysLeft = Math.round((vp.expiryObj.getTime() - nextMonthTwelfth.getTime()) / (1000 * 60 * 60 * 24));
			
			// If 12-03-2026 gives at least 5 days left, prefer it
			if (bestDaysLeft >= 5) {
				// 12-03-2026 is valid, use it unless another candidate is better
				let found = false;
				for (const candidate of candidateDates) {
					const daysLeft = Math.round((vp.expiryObj.getTime() - candidate.getTime()) / (1000 * 60 * 60 * 24));
					// Look for 5-15 day range
					if (daysLeft >= 5 && daysLeft <= 15) {
						bestDate = candidate;
						bestDaysLeft = daysLeft;
						found = true;
						break;
					}
				}
			} else {
				// 12-03-2026 gives less than 5 days, find best candidate with minimum 5 days
				let found = false;
				for (const candidate of candidateDates) {
					const daysLeft = Math.round((vp.expiryObj.getTime() - candidate.getTime()) / (1000 * 60 * 60 * 24));
					if (daysLeft >= 5 && daysLeft <= 15) {
						bestDate = candidate;
						bestDaysLeft = daysLeft;
						found = true;
						break;
					}
				}
				
				// If still no candidate gives 5+ days, skip this product
				if (!found) {
					return product; // Product can't meet 5-day minimum requirement
				}
			}

			return {
				...product,
				offerEndDate: formatExpiryDate(bestDate)
			};
		});

		const uniqueDates = [...new Set(importedData.filter(row => row.offerEndDate).map(row => row.offerEndDate))];
		alert(`✓ Generated offer end dates for ${importedData.length} products!\n✓ Primary date (12th of next month): ${formatExpiryDate(nextMonthDate)}\n✓ Alternative dates used: ${uniqueDates.length}\n✓ Dates: ${uniqueDates.join(', ')}`);
	}

	async function onGenerateOfferPrice() {
		if (!targetPrice || Number(targetPrice) <= 0) {
			alert('Please enter a valid target profit percentage');
			return;
		}

		// Process ALL products through all 7 steps
		let successful = 0;
		let skipped = 0;
		
		importedData = importedData.map((product) => {
			// Apply all 7 steps sequentially
			const result = generateOfferPriceAllSteps(product, Number(targetPrice));
			
			// Count results
			if (result.offer_price > 0) {
				successful++;
			} else {
				skipped++;
			}
			
			// Return product with all result fields, whether offer exists or not
			const offerType = result.offer_price > 0 
				? getOfferType(result.offer_qty, result.limit_qty, result.free_qty, result.offer_price)
				: 'Not Applicable';
			
			return {
				...product,
				offerPrice: result.offer_price,
				offerQty: result.offer_qty,
				offerFree: result.free_qty,
				offerLimit: result.limit_qty || '',
				offerType: offerType,
				generationStatus: result.generation_status || ''
			};
		});

		alert(`Generated offers: ${successful} successful, ${skipped} not applicable. Total: ${importedData.length} products processed.`);
	}

	async function onExportForEntry() {
		if (importedData.length === 0) {
			alert('No data to export');
			return;
		}

		try {
			const workbook = new ExcelJS.Workbook();
			const worksheet = workbook.addWorksheet('Export for Entry');

			// Define columns to export
			const columns = [
				{ header: 'S.No', key: 'sNo', width: 8 },
				{ header: 'Barcode', key: 'barcode', width: 15 },
				{ header: 'Product Name', key: 'productName', width: 30 },
				{ header: 'Unit', key: 'unit', width: 12 },
				{ header: 'Expiry Date', key: 'expiryDate', width: 15 },
				{ header: 'To-Do', key: 'toDo', width: 12 },
				{ header: 'Total Sales Price', key: 'totalSalesPrice', width: 18 },
				{ header: 'Total Offer Price', key: 'totalOfferPrice', width: 18 },
				{ header: 'Offer Qty', key: 'offerQty', width: 12 },
				{ header: 'Free', key: 'free', width: 12 },
				{ header: 'Limit', key: 'limit', width: 12 },
				{ header: 'Offer Type', key: 'offerType', width: 20 },
				{ header: 'Offer End Date', key: 'offerEndDate', width: 15 }
			];

			worksheet.columns = columns;

			// Style header row
			worksheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
			worksheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E40AF' } };
			worksheet.getRow(1).alignment = { horizontal: 'center', vertical: 'middle' };

			// Sort data by Offer End Date, then by Offer Type
			const sortedData = [...importedData].sort((a, b) => {
				// Sort by Offer End Date
				const dateA = a.offerEndDate || '';
				const dateB = b.offerEndDate || '';
				const dateCompare = dateA.localeCompare(dateB);
				
				if (dateCompare !== 0) return dateCompare;
				
				// If dates are equal, sort by Offer Type
				const typeA = getOfferType(
					Number(a.offerQty) || 1,
					a.offerLimit ? Number(a.offerLimit) : null,
					Number(a.offerFree) || 0,
					Number(a.offerPrice) || 0
				) || '';
				const typeB = getOfferType(
					Number(b.offerQty) || 1,
					b.offerLimit ? Number(b.offerLimit) : null,
					Number(b.offerFree) || 0,
					Number(b.offerPrice) || 0
				) || '';
				
				return typeA.localeCompare(typeB);
			});

			// Add rows with serial number
			let serialNumber = 1;
			sortedData.forEach((row) => {
				const remainingDays = getRemainingDays(row.expiryDate);
				const toDo = typeof remainingDays === 'number'
					? remainingDays < 20
						? '🗑️ Remove'
						: '🏷️ Offer'
					: '-';

				const totalOfferPrice = Number(row.offerPrice) > 0 && Number(row.offerQty) > 0
					? roundTo95(Number(row.offerPrice) * Number(row.offerQty)).toFixed(2)
					: '-';

				const offerType = getOfferType(
					Number(row.offerQty) || 1,
					row.offerLimit ? Number(row.offerLimit) : null,
					Number(row.offerFree) || 0,
					Number(row.offerPrice) || 0
				);

				worksheet.addRow({
					sNo: serialNumber++,
					barcode: row.barcode || '',
					productName: row.englishName || '',
					unit: row.unit || '',
					expiryDate: formatExpiryDate(String(row.expiryDate)),
					toDo: toDo,
					totalSalesPrice: (Number(row.salesPrice) * (Number(row.offerQty) || 1)).toFixed(2),
					totalOfferPrice: totalOfferPrice,
					offerQty: row.offerQty || '',
					free: row.offerFree || '',
					limit: row.offerLimit || '',
					offerType: offerType,
					offerEndDate: row.offerEndDate || ''
				});
			});

			// Apply unique colors to Offer End Date cells by unique date
			const dateColorMap: { [key: string]: string } = {};
			const colors = [
				'FFFFE0', // Light Yellow
				'FFE4E1', // Misty Rose (Light Pink)
				'E0FFFF', // Light Cyan
				'F0FFF0', // Honeydew (Light Green)
				'FFF0F5', // Lavender Blush (Light Purple)
				'F5F5DC', // Beige
				'F0F8FF', // Alice Blue
				'FFF8DC', // Cornsilk
				'FFE4B5', // Moccasin
				'F5FFFA', // Mint Cream
				'FFEFD5', // Papaya Whip
				'FFE4C4'  // Bisque
			];
			let colorIndex = 0;

			// Iterate through rows to assign colors based on unique dates
			for (let rowNum = 2; rowNum <= worksheet.rowCount; rowNum++) {
				const dateCell = worksheet.getRow(rowNum).getCell('offerEndDate');
				const dateValue = dateCell.value?.toString() || '';

				if (dateValue && dateValue !== '') {
					if (!dateColorMap[dateValue]) {
						dateColorMap[dateValue] = colors[colorIndex % colors.length];
						colorIndex++;
					}

					const color = dateColorMap[dateValue];
					dateCell.fill = {
						type: 'pattern',
						pattern: 'solid',
						fgColor: { argb: 'FF' + color }
					};
				}
			}
			const buffer = await workbook.xlsx.writeBuffer();
			const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
			const url = window.URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = `Export_for_Entry_${new Date().toISOString().split('T')[0]}.xlsx`;
			document.body.appendChild(a);
			a.click();
			window.URL.revokeObjectURL(url);
			document.body.removeChild(a);

			alert(`✓ Exported ${sortedData.length} products successfully!`);
		} catch (error) {
			console.error('Error exporting data:', error);
			alert('Error exporting data. Please try again.');
		}
	}

	async function onDownloadTemplate() {
		try {
			// Create a new workbook
			const workbook = new ExcelJS.Workbook();
			const worksheet = workbook.addWorksheet('Near Expiry Products');

			// Define columns with headers
			const headers = [
				'Barcode',
				'English name',
				'Arabic name',
				'Sales price',
				'Unit',
				'Cost (cost + VAT)',
				'Expiry date (DD-MM-YYYY)'
			];

			// Add headers to the first row
			const headerRow = worksheet.addRow(headers);

			// Style the header row
			headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
			headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2563EB' } }; // Blue background
			headerRow.alignment = { horizontal: 'center', vertical: 'middle' };

			// Set column widths
			worksheet.columns = [
				{ key: 'barcode', width: 15 },
				{ key: 'englishName', width: 25 },
				{ key: 'arabicName', width: 25 },
				{ key: 'salesPrice', width: 15 },
				{ key: 'unit', width: 15 },
				{ key: 'cost', width: 18 },
				{ key: 'expiryDate', width: 20 }
			];

			// Add sample rows (empty rows for user to fill)
			for (let i = 0; i < 10; i++) {
				worksheet.addRow([
					'',
					'',
					'',
					'',
					'',
					'',
					''
				]);
			}

			// Format data cells
			for (let i = 2; i <= 11; i++) {
				const row = worksheet.getRow(i);
				row.font = { color: { argb: 'FF000000' } };
				row.alignment = { horizontal: 'left', vertical: 'middle' };

				// Format price and cost columns as numbers
				row.getCell(4).numFmt = '#,##0.00'; // Sales price
				row.getCell(6).numFmt = '#,##0.00'; // Cost
				
				// Format expiry date column
				row.getCell(7).alignment = { horizontal: 'center' };
			}

			// Add borders to all cells
			worksheet.eachRow((row) => {
				row.eachCell((cell) => {
					cell.border = {
						top: { style: 'thin', color: { argb: 'FFD1D5DB' } },
						left: { style: 'thin', color: { argb: 'FFD1D5DB' } },
						bottom: { style: 'thin', color: { argb: 'FFD1D5DB' } },
						right: { style: 'thin', color: { argb: 'FFD1D5DB' } }
					};
				});
			});

			// Freeze the header row
			worksheet.views = [{ state: 'frozen', ySplit: 1 }];

			// Generate the file and download
			const buffer = await workbook.xlsx.writeBuffer();
			const blob = new Blob([buffer], {
				type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
			});

			const url = window.URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = url;
			link.download = 'Near_Expiry_Template.xlsx';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
			window.URL.revokeObjectURL(url);
		} catch (error) {
			console.error('Error downloading template:', error);
			alert('Error downloading template. Please try again.');
		}
	}

	const buttons = [
		{
			id: 'download',
			label: 'Download Template',
			icon: '⬇️',
			color: 'blue',
			handler: onDownloadTemplate
		},
		{
			id: 'import',
			label: 'Import from Excel',
			icon: '📥',
			color: 'green',
			handler: onImportFromExcel
		},
		{
			id: 'endDate',
			label: 'Generate Offer End Date',
			icon: '📅',
			color: 'purple',
			handler: onGenerateOfferEndDate
		},
		{
			id: 'price',
			label: 'Generate Offer Price',
			icon: '💰',
			color: 'orange',
			handler: onGenerateOfferPrice
		},
		{
			id: 'export',
			label: 'Export for Entry',
			icon: '📤',
			color: 'red',
			handler: onExportForEntry
		},
		{
			id: 'reports',
			label: 'Near Expiry Reports',
			icon: '⏰',
			color: 'red',
			handler: () => window.dispatchEvent(new CustomEvent('open-near-expiry-requests'))
		}
	];

	function formatExpiryDate(dateValue: any): string {
		if (!dateValue) return '';

		let dateObj: Date;

		// Handle Excel date serial numbers (starts around 44927 for recent dates)
		if (typeof dateValue === 'number' && dateValue > 40000) {
			// Excel date serial (days since 1900-01-01)
			const excelDateStart = new Date(1900, 0, 1);
			dateObj = new Date(excelDateStart.getTime() + (dateValue - 1) * 24 * 60 * 60 * 1000);
		} else if (typeof dateValue === 'string') {
			// Try to parse string dates in various formats
			dateObj = new Date(dateValue);
		} else if (dateValue instanceof Date) {
			dateObj = dateValue;
		} else {
			return String(dateValue);
		}

		// Check if valid date
		if (isNaN(dateObj.getTime())) {
			return String(dateValue);
		}

		// Format as DD-MM-YYYY
		const day = String(dateObj.getDate()).padStart(2, '0');
		const month = String(dateObj.getMonth() + 1).padStart(2, '0');
		const year = dateObj.getFullYear();

		return `${day}-${month}-${year}`;
	}

	function isValidDate(dateValue: any): boolean {
		if (!dateValue) return false;

		let dateObj: Date;

		// Handle Excel date serial numbers
		if (typeof dateValue === 'number' && dateValue > 40000) {
			const excelDateStart = new Date(1900, 0, 1);
			dateObj = new Date(excelDateStart.getTime() + (dateValue - 1) * 24 * 60 * 60 * 1000);
		} else if (typeof dateValue === 'string') {
			dateObj = new Date(dateValue);
		} else if (dateValue instanceof Date) {
			dateObj = dateValue;
		} else {
			return false;
		}

		return !isNaN(dateObj.getTime());
	}

	function isCostZero(costValue: any): boolean {
		if (costValue === null || costValue === undefined || costValue === '') return true;
		const numCost = Number(costValue);
		return isNaN(numCost) || numCost === 0;
	}

	async function copyBarcodeToClipboard(barcode: string) {
		try {
			await navigator.clipboard.writeText(barcode);
			// Visual feedback: show brief notification
			const tmpEl = document.createElement('div');
			tmpEl.textContent = '✓ Copied!';
			tmpEl.style.cssText = 'position:fixed;top:20px;right:20px;background:#10b981;color:white;padding:12px 20px;border-radius:8px;font-weight:bold;z-index:9999;animation:fadeOut 2s ease-in-out forwards;';
			document.body.appendChild(tmpEl);
			setTimeout(() => tmpEl.remove(), 2000);
		} catch (err) {
			console.error('Failed to copy barcode:', err);
		}
	}

	async function fetchSystemExpiryDates() {
		try {
			const barcodes = importedData.map(row => row.barcode).filter(bc => bc);
			if (barcodes.length === 0 || !selectedBranchId) return;

			// Call RPC function to get system expiry dates
			const { data: expiryResults, error } = await supabase.rpc('get_system_expiry_dates', {
				barcode_list: barcodes,
				branch_id_param: selectedBranchId
			});

			if (error) throw error;

			// Create a map of barcode -> system expiry date
			const expiryMap = new Map<string, string>();
			if (expiryResults && Array.isArray(expiryResults)) {
				for (const result of expiryResults) {
					expiryMap.set(result.barcode, result.expiry_date_formatted || '—');
				}
			}

			// Update imported data with system expiry dates
			importedData = importedData.map(row => ({
				...row,
				systemExpiryDate: expiryMap.get(row.barcode) || '—'
			}));

			console.log('✅ System expiry dates fetched via RPC:', Array.from(expiryMap.entries()));
		} catch (err) {
			console.error('Error fetching system expiry dates:', err);
		}
	}

	function savePriceEdit() {
		if (editingRowIndex !== null && editingField && filteredData[editingRowIndex]) {
			const newValue = parseFloat(editingValue);
			if (!isNaN(newValue) && newValue >= 0) {
				filteredData[editingRowIndex][editingField] = newValue;
				filteredData = filteredData; // trigger reactivity
			}
		}
		editingRowIndex = null;
		editingField = null;
		editingValue = '';
	}

	function cancelPriceEdit() {
		editingRowIndex = null;
		editingField = null;
		editingValue = '';
	}

	function isExpiryDateMismatch(importedDate: any, systemDate: any): boolean {
		// Return true if dates are different
		if (!importedDate || systemDate === '—') return false;
		
		// Normalize both dates to DD-MM-YYYY format for comparison
		const imported = formatExpiryDate(String(importedDate)); // returns DD-MM-YYYY
		const system = String(systemDate); // already in DD-MM-YYYY from RPC
		
		return imported !== system;
	}

	function parseExpiryDateToTimestamp(dateValue: any): number {
		if (!dateValue) return Infinity; // Invalid dates go to the end

		let dateObj: Date;

		// Handle Excel date serial numbers
		if (typeof dateValue === 'number' && dateValue > 40000) {
			const excelDateStart = new Date(1900, 0, 1);
			dateObj = new Date(excelDateStart.getTime() + (dateValue - 1) * 24 * 60 * 60 * 1000);
		} else if (typeof dateValue === 'string') {
			dateObj = new Date(dateValue);
		} else if (dateValue instanceof Date) {
			dateObj = dateValue;
		} else {
			return Infinity;
		}

		return isNaN(dateObj.getTime()) ? Infinity : dateObj.getTime();
	}

	function sortByExpiryDate() {
		importedData.sort((a, b) => {
			const dateA = parseExpiryDateToTimestamp(a.expiryDate);
			const dateB = parseExpiryDateToTimestamp(b.expiryDate);
			return dateA - dateB;
		});
		importedData = importedData; // Trigger reactivity
	}

	// Delete a product from the list and trigger reactivity
	function deleteProduct(index: number) {
		importedData.splice(index, 1);
		importedData = importedData; // Trigger reactivity to renumber rows
	}

	// Helper: Round down to nearest .95
	function roundDownTo95(value: number): number {
		const intPart = Math.floor(value);
		const candidate = intPart + 0.95;
		// If the candidate is less than or equal to the value, use it
		// Otherwise go to the previous .95
		if (candidate <= value) {
			return candidate;
		} else {
			return intPart - 1 + 0.95;
		}
	}

	// Helper: Round to nearest .95 ending (finds closest .95)
	function roundTo95(value: number): number {
		const intPart = Math.floor(value);
		
		// Two candidates: current int + 0.95, or previous int + 0.95
		const candidate1 = intPart + 0.95;
		const candidate2 = (intPart - 1) + 0.95;
		
		// Pick whichever is closest to value
		const distance1 = Math.abs(value - candidate1);
		const distance2 = Math.abs(value - candidate2);
		
		if (distance1 <= distance2) {
			return candidate1;
		} else {
			return candidate2;
		}
	}

	// Helper: Round to .50 or .95 (whichever is closest and <= value)
	function roundToHalfOrNineFive(value: number): number | null {
		const intPart = Math.floor(value);
		
		// Try .95 first
		const candidate95 = intPart + 0.95;
		if (candidate95 <= value) {
			return candidate95;
		}
		
		// Try .50
		const candidate50 = intPart + 0.50;
		if (candidate50 <= value) {
			return candidate50;
		}
		
		// Try previous integer + .95
		const prevInteger95 = intPart - 1 + 0.95;
		if (prevInteger95 > 0) {
			return prevInteger95;
		}
		
		// Try previous integer + .50
		const prevInteger50 = intPart - 1 + 0.50;
		if (prevInteger50 > 0) {
			return prevInteger50;
		}
		
		return null; // No valid price found
	}

	// Helper: Check if offer decrease is valid (>= 1.05 SAR minimum)
	function isValidOfferDecrease(salesPriceTotal: number, offerPriceTotal: number): boolean {
		return (salesPriceTotal - offerPriceTotal) >= 1.05;
	}

	// Helper: Get allowed quantities based on price, with 15.95 cap
	function getAllowedQuantities(priceUnit: number): number[] {
		// For high-value items, cap at qty=1 to not exceed 15.95 total
		if (priceUnit > 15.95) {
			return [1];
		}
		if (priceUnit < 6) return [1, 2, 3, 4];
		if (priceUnit <= 10) return [1, 2, 3];
		return [1, 2];
	}

	// Generate offer price based on target profit percentage (EXACT MATCH with PricingManager)
	function generateOfferPriceCalc(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		
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
			
			// Skip if total offer price would exceed 15.95 (cap constraint)
			if (priceTotal > 15.95) {
				continue;
			}
			
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
			
			// Must give discount AND minimum 1.05 SAR decrease
			if (discountActual >= 1.05) {
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

	// ============= 7-STEP PRICING BUTTONS (Matching PricingManager) =============

	// BUTTON 1: Target profit with minimum 1.05 SAR decrease
	function generateOfferPriceButton1(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;

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
			const candidates: any[] = [];

			// Try qty=1 first
			const targetProfitAmount = cost * (targetProfit / 100);
			let offerWithTargetProfit = cost + targetProfitAmount;
			offerWithTargetProfit = roundDownTo95(offerWithTargetProfit);

			// Check if qty=1 with target profit works (must have minimum 2.05 decrease)
			const decreaseQty1 = priceUnit - offerWithTargetProfit;
			if (offerWithTargetProfit > cost && offerWithTargetProfit < priceUnit && decreaseQty1 >= 1.05) {
				const profitQty1 = ((offerWithTargetProfit - cost) / cost) * 100;
				candidates.push({
					qty: 1,
					offerPrice: offerWithTargetProfit,
					profitPercent: profitQty1,
					decreaseAmount: decreaseQty1
				});
			}

			// For high-margin products where qty=1 doesn't work well, try qty 2, 3, 4, 5
			for (let qty of [2, 3, 4, 5]) {
				const priceTotal = priceUnit * qty;
				const targetOfferTotal = priceTotal - 1.05;
				const targetOfferUnit = targetOfferTotal / qty;

				let offerPrice = roundDownTo95(targetOfferUnit);

				if (offerPrice > cost && offerPrice < priceUnit) {
					const costTotal = cost * qty;
					const offerTotal = offerPrice * qty;
					const decreaseAmount = priceTotal - offerTotal;
					const profitPercent = ((offerTotal - costTotal) / costTotal) * 100;

					// Must have at least 1.05 SAR decrease
					if (decreaseAmount >= 1.05 && profitPercent >= 0) {
						candidates.push({
							qty,
							offerPrice,
							profitPercent,
							decreaseAmount
						});
					}
				}
			}

			// Pick the best candidate
			if (candidates.length > 0) {
				// Prefer qty=1 if it exists and is good, otherwise pick highest profit
				let best = candidates.find(c => c.qty === 1);
				if (!best) {
					candidates.sort((a, b) => b.profitPercent - a.profitPercent);
					best = candidates[0];
				}

				// NEW: Skip B1 if best candidate requires qty > 2 (let fallback handle simpler qty=1 offers)
				if (best.qty > 2) {
					return {
						...product,
						offer_qty: 1,
						offer_price: 0,
						free_qty: 0,
						limit_qty: null,
						generation_status: 'B1 Skip (best needs qty > 2, let fallback create qty=1 offer)'
					};
				}

				return {
					...product,
					offer_qty: best.qty,
					offer_price: best.offerPrice,
					free_qty: 0,
					limit_qty: null,
					generation_status: `B1 Success (Qty: ${best.qty}, Profit: ${best.profitPercent.toFixed(2)}%)`
				};
			}

			return {
				...product,
				offer_qty: 1,
				offer_price: 0,
				free_qty: 0,
				limit_qty: null,
				generation_status: 'No Step 1 possible (high margin, no valid qty found)'
			};
		}

		return {
			...product,
			offer_qty: 1,
			offer_price: 0,
			free_qty: 0,
			limit_qty: null,
			generation_status: `B1 Not Applicable (Current profit: ${currentProfitPercent.toFixed(2)}% >= target: ${targetProfit}%)`
		};
	}

	// BUTTON 3: Adjust to minimum 1.05 SAR decrease (or create offer if none exists)
	function generateOfferPriceButton3(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const offerPrice = product.offer_price || 0;
		const offerQty = product.offer_qty || 1;
		const currentStatus = product.generation_status || '';

		// Validation - skip only if completely invalid
		if (cost <= 0 || priceUnit <= 0) {
			return product;
		}

		// If cost >= price, try minimal offer
		if (cost >= priceUnit) {
			// Edge case: cost very close to price - create minimal loss/break-even offer
			const minOfferPrice = Math.max(cost * 0.99, priceUnit * 0.95);
			if (minOfferPrice < priceUnit && minOfferPrice > 0) {
				return {
					...product,
					offer_qty: 1,
					offer_price: roundDownTo95(minOfferPrice),
					generation_status: 'B3 Edge Case (minimal discount)'
				};
			}
			return product;
		}

		// If there's an existing offer and it already has enough decrease, skip
		if (offerPrice > 0) {
			const priceTotal = priceUnit * offerQty;
			const offerTotal = offerPrice * offerQty;
			const currentDecreaseAmount = priceTotal - offerTotal;
			
			if (currentDecreaseAmount >= 1.05) {
				return {
					...product,
					generation_status: currentStatus ? currentStatus : `B3 Skip (Already ${currentDecreaseAmount.toFixed(2)} decrease)`
				};
			}
		}

		// Create or adjust offer to get at least 1.05 decrease
		const priceTotal = priceUnit * offerQty;
		const targetOfferTotal = priceTotal - 1.05;
		const targetOfferUnit = targetOfferTotal / offerQty;

		// Round to .95 ending
		let newOfferPrice = roundDownTo95(targetOfferUnit);

		// Ensure it's above cost
		if (newOfferPrice <= cost) {
			newOfferPrice = Math.floor(cost) + 1.95;
		}

		// If still doesn't work, try smaller decrease
		if (newOfferPrice >= priceUnit) {
			// Try 1.95 decrease instead
			const smallerTarget = priceTotal - 1.95;
			newOfferPrice = roundDownTo95(smallerTarget / offerQty);
			
			if (newOfferPrice <= cost || newOfferPrice >= priceUnit) {
				// Try 0.95 minimum decrease
				newOfferPrice = roundDownTo95((priceTotal - 0.95) / offerQty);
				
				if (newOfferPrice <= cost || newOfferPrice >= priceUnit) {
					// Last resort - just below sales price
					newOfferPrice = Math.floor(priceUnit - 0.05) + 0.95;
					
					if (newOfferPrice <= cost || newOfferPrice >= priceUnit) {
						return {
							...product,
							generation_status: currentStatus ? currentStatus : `B3 No Valid Price (margin too small)`
						};
					}
				}
			}
		}

		// Calculate metrics with final price
		const newOfferTotal = newOfferPrice * offerQty;
		const newDecreaseAmount = priceTotal - newOfferTotal;
		const newProfitPercent = ((newOfferTotal - (cost * offerQty)) / (cost * offerQty)) * 100;

		const newStatus = currentStatus.includes('Success') 
			? currentStatus 
			: `B3 Created (Decrease: ${Math.max(newDecreaseAmount, 0).toFixed(2)} SAR, Profit: ${newProfitPercent.toFixed(2)}%)`;

		return {
			...product,
			offer_qty: offerQty,
			offer_price: newOfferPrice,
			generation_status: newStatus
		};
	}

	// BUTTON 6: Adjust high-margin products (profit 3x higher than target)
	function generateOfferPriceButton6(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const offerPrice = product.offer_price || 0;
		const offerQty = product.offer_qty || 1;
		const currentStatus = product.generation_status || '';

		// Skip if created by B7 (don't modify B7 results)
		if (currentStatus.includes('B7 Created')) {
			return product;
		}

		// Only process products with qty=1 and existing offer
		if (offerQty !== 1 || offerPrice <= 0) {
			return product;
		}

		// Validation
		if (cost <= 0 || priceUnit <= 0) {
			return product;
		}

		// Calculate current profit % after offer
		const currentProfitPercent = ((offerPrice - cost) / cost) * 100;

		// Check if profit is 3x higher than target
		const threeTimesTarget = targetProfit * 3;

		if (currentProfitPercent >= threeTimesTarget) {
			// Adjust to target + 10%
			const newTargetProfit = targetProfit + 10;
			const newProfitAmount = cost * (newTargetProfit / 100);
			let newOfferPrice = cost + newProfitAmount;

			// Round to .95 ending
			newOfferPrice = roundDownTo95(newOfferPrice);

			// Make sure it's still below sales price and above cost
			if (newOfferPrice <= cost) {
				newOfferPrice = Math.floor(cost) + 1.95;
			}

			if (newOfferPrice >= priceUnit) {
				return {
					...product,
					generation_status: `B6 Not Applicable (new price >= sales price)`
				};
			}

			// Calculate final profit
			const finalProfit = ((newOfferPrice - cost) / cost) * 100;
			const decrease = priceUnit - newOfferPrice;

			return {
				...product,
				offer_price: newOfferPrice,
				generation_status: `B6 Adjusted (Profit: ${finalProfit.toFixed(2)}%, Decrease: ${decrease.toFixed(2)})`
			};
		} else {
			return {
				...product,
				generation_status: `B6 Skip (Profit ${currentProfitPercent.toFixed(2)}% < ${threeTimesTarget}%)`
			};
		}
	}

	// BUTTON 7: Fallback for B1 rejects (qty 2-4 with min 1.05 decrease)
	function generateOfferPriceButton7(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const currentStatus = product.generation_status || '';

		// Only process items that were skipped by B1
		if (!currentStatus.includes('No Step 1 possible') && !currentStatus.includes('Not Applicable (Current')) {
			return product;
		}

		// Validation
		if (cost <= 0 || priceUnit <= 0) {
			return {
				...product,
				generation_status: 'B7 Not Applicable (invalid cost/price)'
			};
		}

		if (cost >= priceUnit) {
			return {
				...product,
				generation_status: 'B7 Not Applicable (cost >= price)'
			};
		}

		const candidates: any[] = [];

		// Try quantities 2, 3, 4, 5 to find a viable offer with ≥1.05 SAR decrease
		for (let qty of [2, 3, 4, 5]) {
			const priceTotal = priceUnit * qty;

			// Target offer total: price total - 1.05 SAR minimum decrease
			const targetOfferTotal = priceTotal - 1.05;
			const targetOfferUnit = targetOfferTotal / qty;

			// Round down to .95 ending
			let offerPrice = roundDownTo95(targetOfferUnit);

			// Must be above cost
			if (offerPrice <= cost) continue;

			// Must be below price (to give discount)
			if (offerPrice >= priceUnit) continue;

			// Calculate metrics
			const costTotal = cost * qty;
			const offerTotal = offerPrice * qty;
			const decreaseAmount = priceTotal - offerTotal;
			const profitPercent = ((offerTotal - costTotal) / costTotal) * 100;

			// Must have profit (no loss)
			if (profitPercent >= 0) {
				candidates.push({
					qty,
					offerPrice,
					decreaseAmount,
					profitPercent,
					costTotal,
					offerTotal
				});
			}
		}

		// Select the candidate with best profit
		if (candidates.length > 0) {
			candidates.sort((a, b) => b.profitPercent - a.profitPercent);
			const best = candidates[0];

			return {
				...product,
				offer_qty: best.qty,
				offer_price: best.offerPrice,
				free_qty: 0,
				limit_qty: null,
				generation_status: `B7 Created (Qty: ${best.qty}, Profit: ${best.profitPercent.toFixed(2)}%, Decrease: ${best.decreaseAmount.toFixed(2)})`
			};
		} else {
			return {
				...product,
				generation_status: 'B7 No Valid Price (cannot create offer with qty 2-4)'
			};
		}
	}

	// BUTTON 2: Increase quantity for low profit (profit < 5% AND price < 10)
	function generateOfferPriceButton2(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const offerPrice = product.offer_price || 0;
		const currentQty = product.offer_qty || 1;

		// Skip if B1 already created a valid offer with qty >= 3
		if (product.generation_status?.includes('B1 Success')) {
			return product;
		}

		// Only process products that have an offer
		if (offerPrice <= 0) {
			return product;
		}

		// Check conditions: Profit % After Offer < 5% AND Unit Price < 10
		const currentCostTotal = cost * currentQty;
		const currentOfferTotal = offerPrice * currentQty;
		const currentProfitPercent = ((currentOfferTotal - currentCostTotal) / currentCostTotal) * 100;

		// Only apply if profit < 5% AND price < 10
		if (currentProfitPercent >= 5 || priceUnit >= 10) {
			const existingStatus = product.generation_status || '';
			return {
				...product,
				generation_status: existingStatus ? existingStatus : `B2 Skip (Profit: ${currentProfitPercent.toFixed(2)}%, Price: ${priceUnit})`
			};
		}

		// Calculate maximum quantity allowed (total price <= 15.95 only if cost allows it, qty <= 5)
		let maxQtyAllowed = 5;
		if (cost <= 15.95) {
			maxQtyAllowed = Math.min(5, Math.floor(15.95 / priceUnit));
		}

		// Try increasing quantity
		const candidates: any[] = [];

		for (let newQty = currentQty + 1; newQty <= maxQtyAllowed; newQty++) {
			// Stop if total price would exceed 15.95 or qty exceeds 5 (but only check 15.95 if cost allows)
			if ((cost <= 15.95 && priceUnit * newQty >= 15.95) || newQty > 5) break;

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
			candidates.sort((a, b) => b.profitPercent - a.profitPercent);
			const best = candidates[0];

			return {
				...product,
				offer_qty: best.qty,
				offer_price: best.offerPrice,
				generation_status: `B2 Adjusted (Qty: ${best.qty}, Offer: ${best.offerPrice}, Profit: ${best.profitPercent.toFixed(2)}%)`
			};
		} else {
			return {
				...product,
				generation_status: `B2 Not Applicable (no better option found)`
			};
		}
	}

	// BUTTON 4: Increase quantity to fill price up to 19.95 SAR
	function generateOfferPriceButton4(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const currentQty = product.offer_qty || 1;
		const offerPricePerUnit = product.offer_price || 0;
		const currentStatus = product.generation_status || '';

		// Skip if created by B7
		if (currentStatus.includes('B7 Created')) {
			return product;
		}

		// Skip if B1 already created a valid offer with qty >= 3
		if (currentStatus.includes('B1 Success') && currentQty >= 3) {
			return product;
		}

		// Skip if no valid offer price
		if (offerPricePerUnit <= 0) {
			return { ...product, generation_status: 'B4 Skip (No Offer)' };
		}

		// Skip if unit price is NOT less than 10
		if (priceUnit >= 10) {
			return { ...product, generation_status: 'B4 Skip (Price >= 10 SAR)' };
		}

		// Skip if cost/price invalid
		if (cost <= 0 || priceUnit <= 0 || cost >= priceUnit) {
			return { ...product, generation_status: 'B4 Not Applicable' };
		}

		// Calculate maximum quantity where total offer price <= 15.95 and qty <= 5 (but only check 15.95 if cost allows)
		let maxQty = 5;
		if (cost <= 15.95) {
			maxQty = Math.min(5, Math.floor(15.95 / offerPricePerUnit));
		}

		// Don't decrease quantity
		if (maxQty <= currentQty) {
			return { ...product, generation_status: 'B4 Skip (Max Qty)' };
		}

		// Set new quantity
		const newQty = maxQty;
		const newTotalOfferPrice = offerPricePerUnit * newQty;

		return {
			...product,
			offer_qty: newQty,
			generation_status: `B4 Adjusted (Qty: ${currentQty}→${newQty}, Total: ${newTotalOfferPrice.toFixed(2)})`
		};
	}

	// BUTTON 5: Recalculate based on current quantity
	function generateOfferPriceButton5(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const currentQty = product.offer_qty || 1;
		const oldOfferPrice = product.offer_price || 0;
		const currentStatus = product.generation_status || '';

		// Skip if created by B7
		if (currentStatus.includes('B7 Created')) {
			return product;
		}

		// Skip if quantity is 1 or less
		if (currentQty <= 1) {
			return { ...product, generation_status: 'B5 Skip (Qty ≤ 1)' };
		}

		// Skip if no valid cost/price
		if (cost <= 0 || priceUnit <= 0 || cost >= priceUnit) {
			return { ...product, generation_status: 'B5 Not Applicable' };
		}

		// Calculate total sales price
		const totalSalesPrice = priceUnit * currentQty;

		// Target total decrease of at least 1.05 SAR
		const minTotalDecrease = 1.05;
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
			return { ...product, generation_status: 'B5 No Valid Price' };
		}

		// Also check total price doesn't exceed 15.95 (but only if cost allows)
		if (totalOfferPriceRounded > 15.95 && cost <= 15.95) {
			return { ...product, generation_status: 'B5 Exceeds Max Total Price' };
		}

		// Calculate actual decrease to verify
		const actualTotalDecrease = totalSalesPrice - totalOfferPriceRounded;
		const profitPercent = ((offerPricePerUnit - cost) / cost) * 100;

		return {
			...product,
			offer_price: offerPricePerUnit,
			generation_status: `B5 Recalculated (Total: ${totalOfferPriceRounded.toFixed(2)}, Decrease: ${actualTotalDecrease.toFixed(2)} SAR)`
		};
	}

	// EMERGENCY FALLBACK: Ensure every product gets an offer with minimum decrease
	function generateOfferPriceFallback(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const currentStatus = product.generation_status || '';
		const offerPrice = product.offer_price || 0;
		const offerQty = product.offer_qty || 1;

		// Skip ONLY if already has valid offer with >= 1.05 SAR total decrease
		if (offerPrice > cost) {
			const priceTotal = priceUnit * offerQty;
			const offerTotal = offerPrice * offerQty;
			const decreaseAmount = priceTotal - offerTotal;
			if (decreaseAmount >= 1.05) {
				return product; // Valid offer exists
			}
		}

		// If completely invalid data, create placeholder
		if (!cost || !priceUnit || cost <= 0 || priceUnit <= 0) {
			return {
				...product,
				offer_qty: 1,
				offer_price: 0,
				generation_status: `${currentStatus || 'Fallback'} - Invalid cost/price`
			};
		}

		if (cost < priceUnit) {
			// Try all quantities with prices ending in .50 or .95 only
			const allowedQtys = getAllowedQuantities(priceUnit);
			let bestOption = null;
			let bestDistance = Infinity;

			// FIRST: Try to find option with 1.05+ total decrease
			for (const qty of allowedQtys) {
				const priceTotal = priceUnit * qty;
				const costTotal = cost * qty;
				
				// Try descending from priceUnit looking for valid ending (.50 or .95)
				for (let i = 0; i < 20; i++) { // Try up to 20 SAR down
					const candidate = Math.floor(priceUnit - i) + 0.95;
					const candidateTotal = candidate * qty;
					const decreaseAmount = priceTotal - candidateTotal;
					
					// Check: is total decrease >= 1.05 AND price ends in .95
					if (decreaseAmount >= 1.05 && candidate > cost) {
						const profitPercent = ((candidateTotal - costTotal) / costTotal) * 100;
						const distance = Math.abs(profitPercent - targetProfit);
						
						if (distance < bestDistance) {
							bestDistance = distance;
							bestOption = {
								qty,
								price: candidate,
								decreaseAmount,
								profitPercent
							};
						}
					}
					
					// Also try .50 ending
					const candidate50 = Math.floor(priceUnit - i) + 0.50;
					const candidateTotal50 = candidate50 * qty;
					const decreaseAmount50 = priceTotal - candidateTotal50;
					
					if (decreaseAmount50 >= 1.05 && candidate50 > cost) {
						const profitPercent = ((candidateTotal50 - costTotal) / costTotal) * 100;
						const distance = Math.abs(profitPercent - targetProfit);
						
						if (distance < bestDistance) {
							bestDistance = distance;
							bestOption = {
								qty,
								price: candidate50,
								decreaseAmount: decreaseAmount50,
								profitPercent
							};
						}
					}
				}
			}

			// If found valid option with 1.05+ decrease, use it
			if (bestOption) {
				return {
					...product,
					offer_qty: bestOption.qty,
					offer_price: bestOption.price,
					generation_status: `Fallback Created (Qty: ${bestOption.qty}, Price: ${bestOption.price.toFixed(2)}, Total Decrease: ${bestOption.decreaseAmount.toFixed(2)}, Profit: ${bestOption.profitPercent.toFixed(2)}%)`
				};
			}

			// ADDITIONAL FALLBACK: Try qty=5 with prices ending in .95 for moderate items (2.00-6.00)
			if (priceUnit >= 2.00 && priceUnit <= 6.00) {
				const priceTotal = priceUnit * 5;
				const costTotal = cost * 5;
				
				// Try all prices ending in .95 from (price*5 - 2.00) down to (cost + 0.10)*5
				for (let totalPrice = Math.floor(priceTotal - 2); totalPrice > costTotal; totalPrice--) {
					const candidate95 = totalPrice + 0.95;
					const decreaseAmount = priceTotal - candidate95;
					
					if (decreaseAmount >= 1.05 && candidate95 > costTotal) {
						const profitPercent = ((candidate95 - costTotal) / costTotal) * 100;
						return {
							...product,
							offer_qty: 5,
							offer_price: candidate95 / 5,
							generation_status: `Fallback Qty5 (Qty: 5, Total: ${candidate95.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate95 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
						};
					}
				}
			}

			// NEW FALLBACK: For very low items (0.50-2.00), try qty=5 with flexible total prices (up to 10.95)
			if (priceUnit >= 0.50 && priceUnit < 2.00) {
				const priceTotal = priceUnit * 5;
				const costTotal = cost * 5;
				
				// Try prices ending in .95 and .50 from priceTotal down to costTotal
				for (let baseTotal = Math.ceil(priceTotal); baseTotal >= costTotal; baseTotal--) {
					// Try .95 ending first
					const candidate95 = baseTotal + 0.95;
					if (candidate95 <= 10.95) { // Don't go above 10.95 for qty=5 items
						const decreaseAmount = priceTotal - candidate95;
						
						if (decreaseAmount >= 1.05 && candidate95 > costTotal && candidate95 < priceTotal) {
							const profitPercent = ((candidate95 - costTotal) / costTotal) * 100;
							return {
								...product,
								offer_qty: 5,
								offer_price: candidate95 / 5,
								generation_status: `Fallback Qty5-VeryLow (Qty: 5, Total: ${candidate95.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate95 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
							};
						}
					}
					
					// Try .50 ending
					const candidate50 = baseTotal + 0.50;
					if (candidate50 <= 10.95) {
						const decreaseAmount = priceTotal - candidate50;
						
						if (decreaseAmount >= 1.05 && candidate50 > costTotal && candidate50 < priceTotal) {
							const profitPercent = ((candidate50 - costTotal) / costTotal) * 100;
							return {
								...product,
								offer_qty: 5,
								offer_price: candidate50 / 5,
								generation_status: `Fallback Qty5-VeryLow50 (Qty: 5, Total: ${candidate50.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate50 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
							};
						}
					}
				}
			}

			// FALLBACK: For very low-price items, allow qty=5 with price cap (5.95 max) even if per-unit decrease is low
			if (priceUnit < 2.00) {
				const priceTotal = priceUnit * 5;
				const costTotal = cost * 5;
				
				// Try price ending in .95 up to max total of 5.95
				const maxOfferTotal = 5.95;
				const decreaseAmount = priceTotal - maxOfferTotal;
				
				if (maxOfferTotal > costTotal && maxOfferTotal < priceTotal && decreaseAmount >= 1.05) {
					const profitPercent = ((maxOfferTotal - costTotal) / costTotal) * 100;
					
					return {
						...product,
						offer_qty: 5,
						offer_price: maxOfferTotal / 5,
						generation_status: `Fallback Low-Price (Qty: 5, Total: ${maxOfferTotal.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(maxOfferTotal / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}

			// No valid option found
			return {
				...product,
				offer_qty: 1,
				offer_price: 0,
				generation_status: `${currentStatus || 'Fallback'} - No valid price (cannot meet 1.05 SAR minimum decrease)`
			};
		}

		// If all else fails, cannot create profitable offer
		return {
			...product,
			offer_qty: 1,
			offer_price: 0,
			generation_status: `${currentStatus || 'Fallback'} - Cannot create profitable offer (cost ≥ price or other constraint)`
		};
	}

	// ============= Sequential 7-Step Processing (Matches PricingManager Order) =============
	// BUTTON 11: Final fallback for remaining unpriced items - qty=5 with any price ending in .95 or .50, decrease >= 0.45
	function generateOfferPriceButton11(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const currentOfferPrice = product.offerPrice || product.offer_price || 0; // Check both field names

		// ONLY process if NO offer exists
		if (currentOfferPrice > 0) {
			console.log(`B11 Skip - Item ${priceUnit} already has offer: ${currentOfferPrice}`);
			return product;
		}

		// Skip items below 0.50
		if (priceUnit < 0.50) {
			return product;
		}

		// Validation
		if (cost <= 0 || priceUnit <= 0 || cost >= priceUnit) {
			return product;
		}

		const priceTotal = priceUnit * 5;
		const costTotal = cost * 5;

		console.log(`B11 Processing - Item ${priceUnit} SAR: priceTotal=${priceTotal.toFixed(2)}, costTotal=${costTotal.toFixed(2)}`);

		// Try qty=5 with prices ending in .95 and .50, looking for decrease >= 0.45
		// Start from priceTotal and go down
		for (let baseTotal = Math.floor(priceTotal); baseTotal >= Math.floor(costTotal); baseTotal--) {
			// Try .95 ending first
			const candidate95 = baseTotal + 0.95;
			if (candidate95 > 0 && candidate95 < priceTotal) {
				const decreaseAmount = priceTotal - candidate95;

				console.log(`B11 Try .95: baseTotal=${baseTotal}, candidate95=${candidate95.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}`);

				if (decreaseAmount >= 0.45 && candidate95 > costTotal) {
					const profitPercent = ((candidate95 - costTotal) / costTotal) * 100;
					console.log(`B11 SUCCESS .95: qty=5, price=${(candidate95/5).toFixed(2)}, total=${candidate95.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}, profit=${profitPercent.toFixed(2)}%`);
					return {
						...product,
						offer_qty: 5,
						offer_price: candidate95 / 5,
						generation_status: `B11 Qty5-Final (Qty: 5, Total: ${candidate95.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}

			// Try .50 ending
			const candidate50 = baseTotal + 0.50;
			if (candidate50 > 0 && candidate50 < priceTotal) {
				const decreaseAmount = priceTotal - candidate50;

				console.log(`B11 Try .50: baseTotal=${baseTotal}, candidate50=${candidate50.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}`);

				if (decreaseAmount >= 0.45 && candidate50 > costTotal) {
					const profitPercent = ((candidate50 - costTotal) / costTotal) * 100;
					console.log(`B11 SUCCESS .50: qty=5, price=${(candidate50/5).toFixed(2)}, total=${candidate50.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}, profit=${profitPercent.toFixed(2)}%`);
					return {
						...product,
						offer_qty: 5,
						offer_price: candidate50 / 5,
						generation_status: `B11 Qty5-Final50 (Qty: 5, Total: ${candidate50.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}
		}

		console.log(`B11 Failed for ${priceUnit} SAR - no price with decrease >= 0.45`);
		return product;
	}

	// BUTTON 10: Special handling for higher-price items with qty=5 (up to 20.95 max)
	function generateOfferPriceButton10(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const currentOfferPrice = product.offerPrice || product.offer_price || 0; // Check both field names

		// ONLY process if NO offer exists (after fallback has run)
		if (currentOfferPrice > 0) {
			console.log(`B10 Skip - Item ${priceUnit} already has offer: ${currentOfferPrice}`);
			return product;
		}

		// Skip very low items (already handled by B8)
		if (priceUnit <= 0.50) {
			return product;
		}

		// Validation
		if (cost <= 0 || priceUnit <= 0 || cost >= priceUnit) {
			return product;
		}

		const priceTotal = priceUnit * 5;
		const costTotal = cost * 5;

		console.log(`B10 Processing - Item ${priceUnit} SAR: priceTotal=${priceTotal.toFixed(2)}, costTotal=${costTotal.toFixed(2)}`);

		// Try prices ending in .95 and .50 from 20.95 down to just above costTotal
		for (let baseTotal = 20; baseTotal > Math.floor(costTotal) - 1; baseTotal--) {
			// Try .95 ending first
			const candidate95 = baseTotal + 0.95;
			if (candidate95 <= 20.95) {
				const decreaseAmount = priceTotal - candidate95;

				console.log(`B10 Try .95: baseTotal=${baseTotal}, candidate95=${candidate95.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}`);

				if (decreaseAmount >= 1.05 && candidate95 > costTotal && candidate95 < priceTotal) {
					const profitPercent = ((candidate95 - costTotal) / costTotal) * 100;
					console.log(`B10 SUCCESS .95: qty=5, price=${(candidate95/5).toFixed(2)}, total=${candidate95.toFixed(2)}, profit=${profitPercent.toFixed(2)}%`);
					return {
						...product,
						offer_qty: 5,
						offer_price: candidate95 / 5,
						generation_status: `B10 Qty5-High (Qty: 5, Total: ${candidate95.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate95 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}

			// Try .50 ending
			const candidate50 = baseTotal + 0.50;
			if (candidate50 <= 20.95) {
				const decreaseAmount = priceTotal - candidate50;

				console.log(`B10 Try .50: baseTotal=${baseTotal}, candidate50=${candidate50.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}`);

				if (decreaseAmount >= 1.05 && candidate50 > costTotal && candidate50 < priceTotal) {
					const profitPercent = ((candidate50 - costTotal) / costTotal) * 100;
					console.log(`B10 SUCCESS .50: qty=5, price=${(candidate50/5).toFixed(2)}, total=${candidate50.toFixed(2)}, profit=${profitPercent.toFixed(2)}%`);
					return {
						...product,
						offer_qty: 5,
						offer_price: candidate50 / 5,
						generation_status: `B10 Qty5-High50 (Qty: 5, Total: ${candidate50.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate50 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}
		}

		console.log(`B10 Failed for ${priceUnit} SAR - no valid offer found`);
		return product;
	}

	// BUTTON 9: Special handling for moderate-price items (2.00-6.00) with qty=5
	function generateOfferPriceButton9(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const currentOfferPrice = product.offerPrice || product.offer_price || 0; // Check both field names

		// Only for moderate-price items (2.00-6.00) that still need pricing
		if (priceUnit <= 2.00 || priceUnit > 6.00) {
			return product;
		}

		// If already has valid offer, skip
		if (currentOfferPrice > 0) {
			return product;
		}

		// Validation
		if (cost <= 0 || priceUnit <= 0 || cost >= priceUnit) {
			return product;
		}

		const priceTotal = priceUnit * 5;
		const costTotal = cost * 5;

		console.log(`B9 Debug - Item ${priceUnit} SAR: priceTotal=${priceTotal.toFixed(2)}, costTotal=${costTotal.toFixed(2)}`);

		// Try prices ending in .95 and .50 from priceTotal down, up to 10.95 max
		for (let baseTotal = Math.floor(priceTotal); baseTotal > Math.floor(costTotal) - 1; baseTotal--) {
			// Try .95 ending first
			const candidate95 = baseTotal + 0.95;
			if (candidate95 <= 10.95) {
				const decreaseAmount = priceTotal - candidate95;

				console.log(`B9 Try .95: baseTotal=${baseTotal}, candidate95=${candidate95.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}`);

				if (decreaseAmount >= 1.05 && candidate95 > costTotal && candidate95 < priceTotal) {
					const profitPercent = ((candidate95 - costTotal) / costTotal) * 100;
					console.log(`B9 SUCCESS .95: qty=5, price=${(candidate95/5).toFixed(2)}, total=${candidate95.toFixed(2)}, profit=${profitPercent.toFixed(2)}%`);
					return {
						...product,
						offer_qty: 5,
						offer_price: candidate95 / 5,
						generation_status: `B9 Qty5-Moderate (Qty: 5, Total: ${candidate95.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate95 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}

			// Try .50 ending
			const candidate50 = baseTotal + 0.50;
			if (candidate50 <= 10.95) {
				const decreaseAmount = priceTotal - candidate50;

				console.log(`B9 Try .50: baseTotal=${baseTotal}, candidate50=${candidate50.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}`);

				if (decreaseAmount >= 1.05 && candidate50 > costTotal && candidate50 < priceTotal) {
					const profitPercent = ((candidate50 - costTotal) / costTotal) * 100;
					console.log(`B9 SUCCESS .50: qty=5, price=${(candidate50/5).toFixed(2)}, total=${candidate50.toFixed(2)}, profit=${profitPercent.toFixed(2)}%`);
					return {
						...product,
						offer_qty: 5,
						offer_price: candidate50 / 5,
						generation_status: `B9 Qty5-Moderate50 (Qty: 5, Total: ${candidate50.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate50 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}
		}

		console.log(`B9 Failed for ${priceUnit} SAR`);
		return product;
	}

	// BUTTON 8: Special handling for very low-price items with qty=5 offers
	function generateOfferPriceButton8(product: any, targetProfit: number): any {
		const cost = product.cost || 0;
		const priceUnit = product.salesPrice || 0;
		const currentOfferPrice = product.offerPrice || product.offer_price || 0; // Check both field names

		// Only for very low-price items (0.50-2.00) that still need pricing
		if (priceUnit <= 0.50 || priceUnit > 2.00) {
			return product;
		}

		// If already has valid offer, skip
		if (currentOfferPrice > 0) {
			console.log(`B8 Skip - Item ${priceUnit} already has offer: ${currentOfferPrice}`);
			return product;
		}

		// Validation
		if (cost <= 0 || priceUnit <= 0 || cost >= priceUnit) {
			return product;
		}

		const priceTotal = priceUnit * 5;
		const costTotal = cost * 5;

		// Log for debugging
		console.log(`B8 Debug - Item ${priceUnit} SAR: priceTotal=${priceTotal.toFixed(2)}, costTotal=${costTotal.toFixed(2)}`);

		// Try prices ending in .95 and .50 from priceTotal down to just above costTotal
		for (let baseTotal = Math.floor(priceTotal); baseTotal > Math.floor(costTotal) - 1; baseTotal--) {
			// Try .95 ending first
			const candidate95 = baseTotal + 0.95;
			if (candidate95 <= 10.95) {
				const decreaseAmount = priceTotal - candidate95;

				console.log(`B8 Try .95: baseTotal=${baseTotal}, candidate95=${candidate95.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}`);

				if (decreaseAmount >= 1.05 && candidate95 > costTotal && candidate95 < priceTotal) {
					const profitPercent = ((candidate95 - costTotal) / costTotal) * 100;
					console.log(`B8 SUCCESS .95: qty=5, price=${(candidate95/5).toFixed(2)}, total=${candidate95.toFixed(2)}, profit=${profitPercent.toFixed(2)}%`);
					return {
						...product,
						offer_qty: 5,
						offer_price: candidate95 / 5,
						generation_status: `B8 Qty5-Low (Qty: 5, Total: ${candidate95.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate95 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}

			// Try .50 ending
			const candidate50 = baseTotal + 0.50;
			if (candidate50 <= 10.95) {
				const decreaseAmount = priceTotal - candidate50;

				console.log(`B8 Try .50: baseTotal=${baseTotal}, candidate50=${candidate50.toFixed(2)}, decrease=${decreaseAmount.toFixed(2)}`);

				if (decreaseAmount >= 1.05 && candidate50 > costTotal && candidate50 < priceTotal) {
					const profitPercent = ((candidate50 - costTotal) / costTotal) * 100;
					console.log(`B8 SUCCESS .50: qty=5, price=${(candidate50/5).toFixed(2)}, total=${candidate50.toFixed(2)}, profit=${profitPercent.toFixed(2)}%`);
					return {
						...product,
						offer_qty: 5,
						offer_price: candidate50 / 5,
						generation_status: `B8 Qty5-Low50 (Qty: 5, Total: ${candidate50.toFixed(2)}, Decrease: ${decreaseAmount.toFixed(2)}, Per-Unit: ${(candidate50 / 5).toFixed(2)}, Profit: ${profitPercent.toFixed(2)}%)`
					};
				}
			}
		}

		console.log(`B8 Failed for ${priceUnit} SAR`);
		return product;
	}

	function generateOfferPriceAllSteps(product: any, targetProfit: number): any {
		let result = product;

		// Step 1: Try target profit with qty and minimum decrease
		result = generateOfferPriceButton1(result, targetProfit);

		// Step 2: Increase quantity for low profit
		result = generateOfferPriceButton2(result, targetProfit);

		// Step 3: Adjust to minimum 2.05 SAR decrease
		result = generateOfferPriceButton3(result, targetProfit);

		// Step 7: Fallback for rejected items (BEFORE B4!)
		result = generateOfferPriceButton7(result, targetProfit);

		// Step 4: Increase quantity to fill price
		result = generateOfferPriceButton4(result, targetProfit);

		// Step 5: Recalculate based on current quantity
		result = generateOfferPriceButton5(result, targetProfit);

		// Step 6: Fix high-margin products
		result = generateOfferPriceButton6(result, targetProfit);

		// Step 8: Special handling for very low-price items with qty=5
		result = generateOfferPriceButton8(result, targetProfit);

		// Step 9: Special handling for moderate-price items (2.00-6.00) with qty=5
		result = generateOfferPriceButton9(result, targetProfit);

		// Emergency Fallback: Catch any remaining products without offers
		result = generateOfferPriceFallback(result, targetProfit);

		// Step 10: Special handling for higher-price items with qty=5 (up to 20.95) - RUNS LAST
		result = generateOfferPriceButton10(result, targetProfit);

		// Step 11: Final fallback for remaining items - qty=5 with price=0.99 (total=4.95) if decrease >= 0.55
		result = generateOfferPriceButton11(result, targetProfit);

		return result;
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

	function getRemainingDays(dateValue: any): number | string {
		if (!dateValue) return '-';

		let dateObj: Date;

		// Handle Excel date serial numbers
		if (typeof dateValue === 'number' && dateValue > 40000) {
			const excelDateStart = new Date(1900, 0, 1);
			dateObj = new Date(excelDateStart.getTime() + (dateValue - 1) * 24 * 60 * 60 * 1000);
		} else if (typeof dateValue === 'string') {
			dateObj = new Date(dateValue);
		} else if (dateValue instanceof Date) {
			dateObj = dateValue;
		} else {
			return '-';
		}

		if (isNaN(dateObj.getTime())) {
			return '-';
		}

		// Calculate remaining days from today
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		dateObj.setHours(0, 0, 0, 0);

		const timeDiff = dateObj.getTime() - today.getTime();
		const daysDiff = Math.ceil(timeDiff / (1000 * 60 * 60 * 24));

		return daysDiff;
	}
</script>

<input 
	bind:this={fileInput}
	type="file"
	accept=".xlsx,.xls"
	on:change={handleFileImport}
	style="display: none;"
/>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header/Navigation with Action Buttons -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm flex-wrap gap-4">
		<div class="flex gap-2 bg-slate-100 p-1.5 rounded-2xl border border-slate-200/50 shadow-inner flex-wrap">
			{#each buttons as button (button.id)}
				<button 
					class="group relative flex items-center gap-2.5 px-6 py-2.5 text-xs font-black uppercase tracking-fast transition-all duration-500 rounded-xl overflow-hidden
					{activeButton === button.id 
						? (button.color === 'blue' ? 'bg-blue-600 text-white shadow-lg shadow-blue-200 scale-[1.02]' : 
						   button.color === 'green' ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-200 scale-[1.02]' :
						   button.color === 'purple' ? 'bg-purple-600 text-white shadow-lg shadow-purple-200 scale-[1.02]' :
						   button.color === 'orange' ? 'bg-orange-600 text-white shadow-lg shadow-orange-200 scale-[1.02]' :
						   'bg-red-600 text-white shadow-lg shadow-red-200 scale-[1.02]')
						: 'text-slate-500 hover:bg-white hover:text-slate-800 hover:shadow-md'}"
					on:click={() => {
						activeButton = button.id;
						button.handler();
					}}
					title={button.label}
				>
					<span class="text-lg filter drop-shadow-sm transition-transform duration-500 group-hover:rotate-12">{button.icon}</span>
					<span class="relative z-10">{button.label}</span>
					
					{#if activeButton === button.id}
						<div class="absolute inset-0 bg-white/10 animate-pulse"></div>
					{/if}
				</button>
			{/each}
		</div>

		<div class="flex gap-3 items-center flex-wrap">
			<!-- Target Profit Entry in Header -->
			{#if importedData.length > 0}
				<div class="bg-slate-100 rounded-2xl p-1.5 border border-slate-200/50 shadow-inner">
					<div class="bg-white rounded-xl px-4 py-2 border border-slate-200 flex items-center gap-3 whitespace-nowrap h-[42px]">
						<label for="profit-input" class="text-xs font-semibold text-slate-700">📊 Target %</label>
						<input 
							id="profit-input"
							type="number" 
							bind:value={targetPrice}
							placeholder="16"
							class="w-32 px-2 py-1 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm text-center font-semibold"
						/>
					</div>
				</div>
			{/if}

			<!-- VAT % Entry in Header -->
			{#if importedData.length > 0}
				<div class="bg-slate-100 rounded-2xl p-1.5 border border-slate-200/50 shadow-inner">
					<div class="bg-white rounded-xl px-4 py-2 border border-slate-200 flex items-center gap-3 whitespace-nowrap h-[42px]">
						<label for="vat-input" class="text-xs font-semibold text-slate-700">🏛️ VAT %</label>
						<input 
							id="vat-input"
							type="number" 
							bind:value={vatPercent}
							placeholder="15"
							min="0"
							max="100"
							step="0.5"
							class="w-24 px-2 py-1 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent text-sm text-center font-semibold"
						/>
					</div>
				</div>
			{/if}

			<!-- Print Shelf Paper in Header -->
			{#if importedData.length > 0}
				<div class="bg-slate-100 rounded-2xl p-1.5 border border-slate-200/50 shadow-inner">
					<div class="bg-white rounded-xl px-4 py-2 border border-slate-200 flex items-center gap-3 h-[42px]">
						<label for="template-select" class="text-xs font-semibold text-slate-700 whitespace-nowrap">🖨️ Print</label>
						<select 
							id="template-select"
							bind:value={selectedTemplateId}
							disabled={isLoadingTemplates}
							class="px-2 py-1 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-xs min-w-[180px]"
						>
							<option value="">-- Select template --</option>
							{#each templates as template}
								<option value={template.id}>{template.name}</option>
							{/each}
						</select>
						<button 
							on:click={printShelfPaper}
							disabled={!selectedTemplateId || filteredData.length === 0 || isLoadingTemplates}
							class="px-3 py-1 bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white rounded-lg text-xs font-semibold transition-colors whitespace-nowrap"
						>
							Print
						</button>
					</div>
				</div>
			{/if}

			<!-- Manage Columns in Header -->
			{#if importedData.length > 0}
				<div class="relative group">
					<div class="bg-slate-100 rounded-2xl p-1.5 border border-slate-200/50 shadow-inner">
						<button class="bg-white rounded-xl px-4 py-2 border border-slate-200 flex items-center gap-2 whitespace-nowrap h-[42px] hover:bg-slate-50 transition-colors">
							<span class="text-lg">⚙️</span>
							<span class="text-xs font-semibold text-slate-700">Manage Columns</span>
						</button>
					</div>
					<!-- Dropdown Menu -->
					<div class="absolute right-0 mt-1 bg-white border border-slate-300 rounded-lg shadow-xl z-50 hidden group-hover:block min-w-[280px] max-h-[400px] overflow-y-auto">
						<div class="p-3">
							<div class="font-semibold text-sm text-slate-800 mb-3 pb-2 border-b border-slate-200">Show/Hide Columns</div>
							{#each columnList as column}
								<label class="flex items-center gap-2 p-2 hover:bg-slate-100 rounded-lg cursor-pointer transition-colors">
									<input 
										type="checkbox" 
										bind:checked={visibleColumns[column.key]}
										class="w-4 h-4 accent-blue-600"
									/>
									<span class="text-sm text-slate-700">{column.label}</span>
								</label>
							{/each}
						</div>
					</div>
				</div>
			{/if}

			<!-- Branch Selector in Header -->
			<div class="bg-slate-100 rounded-2xl p-1.5 border border-slate-200/50 shadow-inner">
				<div class="bg-white rounded-xl px-4 py-2 border border-slate-200 flex items-center gap-3 h-[42px]">
					<label for="branch-select" class="text-xs font-semibold text-slate-700 whitespace-nowrap">🏢 Branch</label>
					<select 
						id="branch-select"
						bind:value={selectedBranchId}
						on:change={fetchProductNamesFromBranch}
						disabled={loadingBranches || branches.length === 0}
						class="px-2 py-1 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-xs min-w-[200px]"
					>
						<option value="">-- Select Branch --</option>
						{#each branches as branch}
							<option value={branch.branch_id}>{branch.branch_name_en} ({branch.location_en})</option>
						{/each}
					</select>
					{#if fetchingProductNames}
						<span class="text-xs text-blue-600 font-semibold">Fetching...</span>
					{/if}
				</div>
			</div>

			<!-- Search Bar in Header -->
			{#if importedData.length > 0}
				<div class="bg-slate-100 rounded-2xl p-1.5 border border-slate-200/50 shadow-inner flex-1 min-w-[300px]">
					<div class="flex items-center gap-2 bg-white rounded-xl px-4 py-2 border border-slate-200 h-[42px]">
						<span class="text-lg">🔍</span>
						<input 
							type="text" 
							bind:value={searchQuery}
							placeholder="Search by name or barcode..."
							class="flex-1 px-0 py-0 border-0 focus:outline-none focus:ring-0 text-sm bg-white"
						/>
						{#if searchQuery}
							<button 
								on:click={() => searchQuery = ''}
								class="text-xs text-slate-500 hover:text-slate-700 font-bold"
								title="Clear search"
							>
								✕
							</button>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Futuristic background decorative elements -->
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if importedData.length === 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-center">
						<div class="text-6xl mb-4">📦</div>
						<h2 class="text-2xl font-bold text-slate-900 mb-2">Near Expiry Manager</h2>
						<p class="text-slate-600 text-lg">Download template and import data to get started</p>
					</div>
				</div>
			{:else}
				<!-- Imported Data Table -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
					<!-- Table Info Header -->
					<div class="px-6 py-4 bg-gradient-to-r from-blue-50 to-emerald-50 border-b border-slate-200">
						<div class="flex items-center justify-between">
							<div>
								<h3 class="text-lg font-bold text-slate-900">Imported Products</h3>
								<p class="text-sm text-slate-600 mt-1">{filteredData.length} / {importedData.length} product{importedData.length !== 1 ? 's' : ''} {searchQuery ? 'found' : 'loaded'}</p>
							</div>
							<div class="flex gap-4 flex-wrap">
								{#if importedData.filter(row => isCostZero(row.cost) || Number(row.cost) > Number(row.salesPrice)).length > 0}
									<div class="bg-red-50 rounded-xl p-4 shadow-md border border-red-200">
										<p class="text-xs font-semibold text-red-700 mb-2">⚠️ Invalid Cards</p>
										<div class="flex flex-wrap gap-2 mb-3">
											{#each importedData as row, index}
												{#if isCostZero(row.cost) || Number(row.cost) > Number(row.salesPrice)}
													<button
														on:click={() => scrollToInvalidRow(index)}
														title="Offer End: {row.offerEndDate || 'Not set'}"
														class="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded-lg text-sm font-bold cursor-pointer transition-colors"
													>
														{index + 1} {row.offerEndDate ? `(${row.offerEndDate})` : ''}
													</button>
												{/if}
											{/each}
										</div>
										<p class="text-xs text-red-600">Click to scroll • Fix these cards (cost must be > 0 and less than sales price)</p>
									</div>
								{/if}
								
								{#if importedData.filter(row => row.offerPrice).length > 0}
									{@const totalSalesPrice = importedData.reduce((sum, row) => sum + (Number(row.salesPrice) * (Number(row.offerQty) || 1) || 0), 0)}
									{@const totalCost = importedData.reduce((sum, row) => sum + (Number(row.cost) * (1 + vatPercent / 100) * (Number(row.offerQty) || 1) || 0), 0)}
									{@const totalOfferPrice = importedData.reduce((sum, row) => {
										if (!row.offerPrice) return sum;
										const price = Number(row.offerPrice) * (Number(row.offerQty) || 1);
										return sum + (isNaN(price) ? 0 : price);
									}, 0)}
									{@const profitBeforeOffer = totalSalesPrice - totalCost}
									{@const profitAfterOffer = totalOfferPrice - totalCost}
									{@const profitPercentBefore = totalCost > 0 ? ((profitBeforeOffer / totalCost) * 100).toFixed(2) : 0}
									{@const profitPercentAfter = totalCost > 0 ? ((profitAfterOffer / totalCost) * 100).toFixed(2) : 0}
									<div class="bg-blue-50 rounded-xl p-4 shadow-md border border-blue-200">
										<p class="text-xs font-semibold text-blue-700 mb-3">💰 Pricing Summary (Target: {targetPrice}%)</p>
										<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
											<div class="bg-green-100 rounded-lg p-3 border border-green-300">
												<div class="text-xs text-green-700 font-semibold">Before Offer</div>
												<div class="text-lg font-bold text-green-800">{profitPercentBefore}%</div>
												<div class="text-xs text-green-600">{profitBeforeOffer.toFixed(2)} SAR profit</div>
											</div>
											<div class="bg-orange-100 rounded-lg p-3 border border-orange-300">
												<div class="text-xs text-orange-700 font-semibold">After Offer</div>
												<div class="text-lg font-bold text-orange-800">{profitPercentAfter}%</div>
												<div class="text-xs text-orange-600">{profitAfterOffer.toFixed(2)} SAR profit</div>
											</div>
											<div class="bg-purple-100 rounded-lg p-3 border border-purple-300">
												<div class="text-xs text-purple-700 font-semibold">Average Profit</div>
												<div class="text-lg font-bold text-purple-800">{((parseFloat(String(profitPercentBefore)) + parseFloat(String(profitPercentAfter))) / 2).toFixed(2)}%</div>
												<div class="text-xs text-purple-600">Change: {(parseFloat(String(profitPercentAfter)) - parseFloat(String(profitPercentBefore))).toFixed(2)}%</div>
											</div>
										</div>
									</div>
								{/if}
								
								{#if importedData.filter(row => row.offerEndDate).length > 0}
									<div class="bg-purple-50 rounded-xl p-4 shadow-md border border-purple-200">
										<p class="text-xs font-semibold text-purple-700 mb-2">📅 Offer End Dates Summary</p>
										<div class="grid grid-cols-6 gap-3">
											{#each [...new Set(importedData.filter(row => row.offerEndDate).map(row => row.offerEndDate))] as endDate}
												{@const count = importedData.filter(row => row.offerEndDate === endDate).length}
												<div class="bg-white rounded-lg p-2 border border-purple-200">
													<div class="text-sm font-bold text-purple-700">{endDate}</div>
													<div class="text-xs text-purple-600">{count} product{count !== 1 ? 's' : ''}</div>
												</div>
											{/each}
										</div>
										<p class="text-xs text-purple-600 mt-3">
											<strong>Total Unique Dates:</strong> {[...new Set(importedData.filter(row => row.offerEndDate).map(row => row.offerEndDate))].length} |
											<strong>Total Products:</strong> {importedData.filter(row => row.offerEndDate).length}
										</p>
									</div>
								{/if}
							</div>
						</div>
					</div>

					<!-- Table Wrapper with horizontal scroll -->
					<div class="overflow-x-auto flex-1">
						<table class="w-full border-collapse">
							<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
								<tr>
									{#if visibleColumns.delete}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Delete</th>{/if}
									{#if visibleColumns.sNo}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">S.No</th>{/if}
									{#if visibleColumns.barcode}<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Barcode</th>{/if}
									{#if visibleColumns.systemExpiryDate}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">System Expiry Date</th>{/if}
									{#if visibleColumns.productName}<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Product Name</th>{/if}
									{#if visibleColumns.salesPrice}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Sales Price</th>{/if}
									{#if visibleColumns.totalSalesPrice}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Total Sales Price</th>{/if}
									{#if visibleColumns.unit}<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Unit</th>{/if}
									{#if visibleColumns.cost}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Cost (VAT)</th>{/if}
									{#if visibleColumns.totalCost}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Total Cost</th>{/if}
									{#if visibleColumns.expiryDate}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Expiry Date</th>{/if}
									{#if visibleColumns.offerEndDate}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer End Date</th>{/if}
									{#if visibleColumns.daysLeft}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Days Left</th>{/if}
									{#if visibleColumns.remainingDays}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Remaining Days</th>{/if}
									{#if visibleColumns.toDo}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">To Do</th>{/if}
									{#if visibleColumns.offerPrice}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Price</th>{/if}
									{#if visibleColumns.totalOfferPrice}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Total Offer Price</th>{/if}
									{#if visibleColumns.offerDecrease}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Decrease</th>{/if}
									{#if visibleColumns.profitPercent}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Profit %</th>{/if}
									{#if visibleColumns.offerType}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Type</th>{/if}
									{#if visibleColumns.offerQty}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Qty</th>{/if}
									{#if visibleColumns.free}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Free</th>{/if}
									{#if visibleColumns.limit}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Limit</th>{/if}
									{#if visibleColumns.sendTask}<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Send Task</th>{/if}
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each filteredData as row, index}
									<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'} {
										isCostZero(row.cost) || Number(row.cost) > Number(row.salesPrice)
											? 'bg-red-300 text-red-900'
											: ''
									}">
										{#if visibleColumns.delete}
										<td class="px-4 py-3 text-sm text-center whitespace-nowrap">
											<button 
												on:click={() => deleteProduct(index)}
												class="px-1.5 py-0.5 bg-red-500 text-white rounded hover:bg-red-600 font-bold text-sm"
												title="Delete this product"
											>
												✕
											</button>
										</td>
										{/if}
										{#if visibleColumns.sNo}
										<td class="px-4 py-3 text-sm font-bold text-slate-800 whitespace-nowrap text-center">{index + 1}</td>
										{/if}
										{#if visibleColumns.barcode}
										<td class="px-4 py-3 text-sm font-mono text-slate-800 whitespace-nowrap cursor-pointer hover:bg-blue-100 hover:text-blue-900 rounded transition-all" on:dblclick={() => copyBarcodeToClipboard(row.barcode)} title="Double-click to copy barcode">{row.barcode}</td>
										{/if}
										{#if visibleColumns.systemExpiryDate}
										<td class="px-4 py-3 text-sm font-mono text-center whitespace-nowrap {row.systemExpiryDate === '—' ? 'text-slate-400' : 'text-orange-700 font-semibold'}">{row.systemExpiryDate || '—'}</td>
										{/if}
										{#if visibleColumns.productName}
										<td class="px-4 py-3 text-sm text-slate-700">
											<div class="font-semibold text-slate-800">{row.englishName}</div>
											<div class="text-xs text-slate-600">{row.arabicName}</div>
										</td>
										{/if}
										{#if visibleColumns.salesPrice}
										{#if editingRowIndex === index && editingField === 'salesPrice'}
											<td class="px-4 py-3 text-sm text-center whitespace-nowrap">
												<input
													type="number"
													bind:value={editingValue}
													step="0.01"
													min="0"
													on:keydown={(e) => {
														if (e.key === 'Enter') savePriceEdit();
														if (e.key === 'Escape') cancelPriceEdit();
													}}
													class="w-full px-2 py-1 border-2 border-blue-500 rounded bg-blue-50 text-blue-700 font-semibold focus:outline-none focus:ring-2 focus:ring-blue-400"
												/>
												<div class="flex gap-1 mt-1">
													<button on:click={savePriceEdit} class="px-2 py-0.5 bg-green-500 text-white rounded text-xs font-bold hover:bg-green-600">✓</button>
													<button on:click={cancelPriceEdit} class="px-2 py-0.5 bg-red-500 text-white rounded text-xs font-bold hover:bg-red-600">✕</button>
												</div>
											</td>
										{:else}
											<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap cursor-pointer hover:bg-blue-100 rounded transition-all" on:dblclick={() => { editingRowIndex = index; editingField = 'salesPrice'; editingValue = String(row.salesPrice || ''); }} title="Double-click to edit">
												{typeof row.salesPrice === 'number' ? row.salesPrice.toFixed(2) : row.salesPrice}
											</td>
										{/if}
										{/if}
										{#if visibleColumns.totalSalesPrice}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap bg-blue-100/50">
											{(Number(row.salesPrice) * (Number(row.offerQty) || 1)).toFixed(2)}
										</td>
										{/if}
										{#if visibleColumns.unit}
										<td class="px-4 py-3 text-sm text-slate-700 whitespace-nowrap">{row.unit}</td>
										{/if}
										{#if visibleColumns.cost}
										{#if editingRowIndex === index && editingField === 'cost'}
											<td class="px-4 py-3 text-sm text-center whitespace-nowrap">
												<input
													type="number"
													bind:value={editingValue}
													step="0.01"
													min="0"
													on:keydown={(e) => {
														if (e.key === 'Enter') savePriceEdit();
														if (e.key === 'Escape') cancelPriceEdit();
													}}
													class="w-full px-2 py-1 border-2 border-purple-500 rounded bg-purple-50 text-purple-700 font-semibold focus:outline-none focus:ring-2 focus:ring-purple-400"
												/>
												<div class="flex gap-1 mt-1">
													<button on:click={savePriceEdit} class="px-2 py-0.5 bg-green-500 text-white rounded text-xs font-bold hover:bg-green-600">✓</button>
													<button on:click={cancelPriceEdit} class="px-2 py-0.5 bg-red-500 text-white rounded text-xs font-bold hover:bg-red-600">✕</button>
												</div>
											</td>
										{:else}
											<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap cursor-pointer hover:bg-purple-100 rounded transition-all {isCostZero(row.cost) ? 'bg-red-400 text-white font-bold' : ''}" on:dblclick={() => { editingRowIndex = index; editingField = 'cost'; editingValue = String(row.cost || ''); }} title="Double-click to edit">
												{typeof row.cost === 'number' ? (Number(row.cost) * (1 + vatPercent / 100)).toFixed(2) : row.cost}
											</td>
										{/if}
										{/if}
										{#if visibleColumns.totalCost}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap bg-slate-200/50">
											{(Number(row.cost) * (1 + vatPercent / 100) * (Number(row.offerQty) || 1)).toFixed(2)}
										</td>
										{/if}
										{#if visibleColumns.expiryDate}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-mono whitespace-nowrap {!isValidDate(row.expiryDate) ? 'bg-red-400 text-white font-bold' : isExpiryDateMismatch(row.expiryDate, row.systemExpiryDate) ? 'bg-red-200 text-red-900 font-bold border-2 border-red-500 heartbeat' : ''}">
											{formatExpiryDate(String(row.expiryDate))}
										</td>
										{/if}
										{#if visibleColumns.offerEndDate}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-mono whitespace-nowrap bg-purple-100/50">
											<input 
												type="text" 
												placeholder="DD-MM-YYYY"
												value={row.offerEndDate || ''}
												on:input={(e) => {
													row.offerEndDate = e.currentTarget.value;
													importedData = importedData;
												}}
												class="w-24 px-2 py-1 border border-purple-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
											/>
										</td>
										{/if}
										{#if visibleColumns.daysLeft}
										<td class="px-4 py-3 text-sm text-center font-bold whitespace-nowrap bg-indigo-100/50">
											{#if row.offerEndDate && row.expiryDate}
												{@const d1 = new Date(String(row.offerEndDate).split('-').reverse().join('-')).getTime()}
												{@const d2 = new Date(String(row.expiryDate).split('-').reverse().join('-')).getTime()}
												{@const days = Math.round((d2 - d1) / 86400000)}
												<span class="{days < 0 ? 'text-red-600 font-bold' : days <= 7 ? 'text-orange-600 font-bold' : 'text-green-600'}">{days} days</span>
											{:else}
												-
											{/if}
										</td>
										{/if}
										{#if visibleColumns.remainingDays}
										{@const remainingDays = getRemainingDays(row.expiryDate)}
										<td class="px-4 py-3 text-sm text-center font-bold whitespace-nowrap {
											typeof remainingDays === 'number'
												? remainingDays <= 7
													? 'bg-red-500 text-white'
													: remainingDays <= 30
													? 'bg-orange-500 text-white'
													: 'bg-emerald-500 text-white'
												: 'text-slate-400'
										}">
											{remainingDays} days
										</td>
										{/if}
										{#if visibleColumns.toDo}
										{@const remainingDaysForToDo = getRemainingDays(row.expiryDate)}
										<td class="px-4 py-3 text-sm text-center font-bold whitespace-nowrap {
											typeof remainingDaysForToDo === 'number'
												? remainingDaysForToDo < 20
													? 'bg-red-600 text-white'
													: 'bg-blue-600 text-white'
												: 'bg-slate-400 text-white'
										}">
											{typeof remainingDaysForToDo === 'number'
												? remainingDaysForToDo < 20
													? '🗑️ Remove'
													: '🏷️ Offer'
												: '-'}
										</td>
										{/if}
										{#if visibleColumns.offerPrice}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap bg-emerald-100/50">
											<input 
												type="number" 
												placeholder="Enter price"
												value={row.offerPrice || ''}
												on:input={(e) => {
													row.offerPrice = e.currentTarget.value;
													importedData = importedData;
												}}
												class="w-full px-2 py-1 border border-emerald-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
												step="0.01"
											/>
										</td>
										{/if}
										{#if visibleColumns.totalOfferPrice}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-bold whitespace-nowrap bg-amber-100/50">
											{#if Number(row.offerPrice) > 0 && Number(row.offerQty) > 0}
												{roundTo95(Number(row.offerPrice) * Number(row.offerQty)).toFixed(2)}
											{:else}
												-
											{/if}
										</td>
										{/if}
										{#if visibleColumns.offerDecrease}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-bold whitespace-nowrap {
											(() => {
												if (Number(row.salesPrice) <= 0 || Number(row.offerPrice) <= 0 || Number(row.offerQty) <= 0) {
													return 'bg-orange-100/50';
												}
												const decrease = Number(row.salesPrice) * Number(row.offerQty) - Number(row.offerPrice) * Number(row.offerQty);
												if (decrease < 0.55) {
													return 'bg-red-500 text-white';
												} else if (decrease >= 0.55 && decrease < 1.05) {
													return 'bg-orange-500 text-white';
												} else if (decrease >= 2) {
													return decrease >= 3 ? 'bg-green-600 text-white' : 'bg-green-400 text-white';
												}
												return 'bg-orange-100/50';
											})()
										}">
											{#if Number(row.salesPrice) > 0 && Number(row.offerPrice) > 0 && Number(row.offerQty) > 0}
												{(Number(row.salesPrice) * Number(row.offerQty) - Number(row.offerPrice) * Number(row.offerQty)).toFixed(2)}
											{:else}
												-
											{/if}
										</td>
										{/if}
										{#if visibleColumns.profitPercent}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-bold whitespace-nowrap bg-yellow-100/50">
											{#if Number(row.cost) > 0 && Number(row.offerPrice) > 0}
												{@const costWithVat = Number(row.cost) * (1 + vatPercent / 100)}
												{((((Number(row.offerPrice) * (Number(row.offerQty) || 1)) - (costWithVat * (Number(row.offerQty) || 1))) / (costWithVat * (Number(row.offerQty) || 1))) * 100).toFixed(2)}%
											{:else}
												-
											{/if}
										</td>
										{/if}
										{#if visibleColumns.offerType}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap">
											<div class="px-2 py-1">
												{getOfferType(
													Number(row.offerQty) || 1,
													row.offerLimit ? Number(row.offerLimit) : null,
													Number(row.offerFree) || 0,
													Number(row.offerPrice) || 0
												)}
											</div>
										</td>
										{/if}
										{#if visibleColumns.offerQty}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap">
											<input 
												type="number" 
												placeholder="Qty"
												value={row.offerQty || ''}
												on:input={(e) => {
													row.offerQty = e.currentTarget.value;
													importedData = importedData;
												}}
												class="w-20 px-2 py-1 border border-slate-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
												min="1"
											/>
										</td>
										{/if}
										{#if visibleColumns.free}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap">
											<input 
												type="number" 
												placeholder="Free"
												value={row.offerFree || ''}
												on:input={(e) => {
													row.offerFree = e.currentTarget.value;
													importedData = importedData;
												}}
												class="w-20 px-2 py-1 border border-slate-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
												min="0"
											/>
										</td>
										{/if}
										{#if visibleColumns.limit}
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap">
											<input 
												type="number" 
												placeholder="Limit"
												value={row.offerLimit || ''}
												on:input={(e) => {
													row.offerLimit = e.currentTarget.value;
													importedData = importedData;
												}}
												class="w-20 px-2 py-1 border border-slate-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
												min="1"
											/>
										</td>
										{/if}
										{#if visibleColumns.sendTask}
										<td class="px-4 py-3 text-sm text-center whitespace-nowrap">
											{#if row.notFound || isExpiryDateMismatch(row.expiryDate, row.systemExpiryDate)}
												<button
													on:click={() => openSendTaskModal(row.barcode, row)}
													class="px-3 py-1 {row.notFound ? 'bg-amber-500 hover:bg-amber-600' : 'bg-red-500 hover:bg-red-600'} text-white rounded-lg font-semibold text-xs transition-colors"
													title="{row.notFound ? 'Barcode not found' : 'System date mismatch'}"
												>
													📋 Task
												</button>
											{:else if row.taskSent}
												<span class="px-3 py-1 bg-green-200 text-green-700 rounded-lg font-semibold text-xs">✅ Sent</span>
											{:else}
												<span class="px-3 py-1 bg-slate-200 text-slate-500 rounded-lg text-xs">-</span>
											{/if}
										</td>
										{/if}
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}
		</div>
	</div>

	<!-- Send Task Modal -->
	{#if showSendTaskModal}
	<div class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
		<div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 p-6 border border-slate-200">
			<!-- Modal Header -->
			<div class="mb-6">
				<h2 class="text-xl font-bold text-slate-900">Send Quick Task</h2>
				<p class="text-sm text-slate-600 mt-2">Barcode: <span class="font-mono font-bold">{taskToSendBarcode}</span></p>
				{#if taskToSendProduct?.englishName}
					<p class="text-sm text-slate-600 mt-1">Product: {taskToSendProduct.englishName}</p>
				{/if}
				
				<!-- Product Photo Preview -->
				{#if taskToSendProduct?.photo_url}
					<div class="mt-4 flex justify-center">
						<img 
							src={taskToSendProduct.photo_url} 
							alt="" 
							class="max-w-xs max-h-48 rounded-lg border-2 border-blue-200 object-cover"
						/>
					</div>
				{:else}
					<div class="mt-4 flex justify-center p-4 bg-slate-100 rounded-lg border-2 border-dashed border-slate-300">
						<p class="text-xs text-slate-500">No product photo available</p>
					</div>
				{/if}
			</div>

			<!-- User Selection -->
			<div class="mb-6">
				<!-- svelte-ignore a11y-label-has-associated-control -->
				<div class="block text-sm font-semibold text-slate-700 mb-2">Select User</div>
				<p class="text-xs text-slate-600 mb-3">All users system-wide • ⭐ = Recent report targets</p>
				{#if loadingUsers}
					<div class="flex items-center justify-center py-4">
						<span class="text-sm text-slate-600">Loading users...</span>
					</div>
				{:else if availableUsers.length === 0}
					<div class="text-sm text-amber-700 bg-amber-50 rounded-lg p-3 border border-amber-200">
						No users available in the system
					</div>
				{:else}
					<!-- Search Input -->
					<input
						type="text"
						placeholder="🔍 Search user..."
						bind:value={taskUserSearchQuery}
						class="w-full px-3 py-2 border border-slate-300 rounded-lg mb-3 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
					/>
					
					<!-- Filtered User List -->
					{@const filteredTaskUsers = availableUsers.filter(user =>
						(user.name_en || '').toLowerCase().includes(taskUserSearchQuery.toLowerCase()) ||
						(user.name_ar || '').toLowerCase().includes(taskUserSearchQuery.toLowerCase()) ||
						(user.id || '').toLowerCase().includes(taskUserSearchQuery.toLowerCase())
					)}
					
					{#if filteredTaskUsers.length === 0}
						<div class="text-sm text-slate-600 bg-slate-50 rounded-lg p-3 border border-slate-200">
							No users found matching "{taskUserSearchQuery}"
						</div>
					{:else}
						<div class="max-h-64 overflow-y-auto">
							{#each filteredTaskUsers as user}
								<label class="flex items-center gap-3 p-3 rounded-lg cursor-pointer transition-colors mb-2 {user.isHighlighted ? 'bg-amber-50 hover:bg-amber-100 border border-amber-200' : 'hover:bg-slate-50 border border-transparent'}">
									<input
										type="radio"
										bind:group={taskSelectedUser}
										value={user.user_id}
										on:change={() => {
											taskSelectedUserName = user.name_en || user.name_ar || user.id;
										}}
										class="w-4 h-4 accent-blue-600"
									/>
									<div class="flex-1">
										<div class="flex items-center gap-2">
											<div class="font-semibold {user.isHighlighted ? 'text-amber-900' : 'text-slate-800'}">
												{user.name_en || user.id}
											</div>
											{#if user.isHighlighted}
												<span class="inline-block bg-amber-200 text-amber-800 text-xs font-bold px-2 py-0.5 rounded-full" title="Recent report target">
													⭐
												</span>
											{/if}
										</div>
										{#if user.name_ar}
											<div class="text-xs {user.isHighlighted ? 'text-amber-700' : 'text-slate-600'}">{user.name_ar}</div>
										{/if}
									</div>
								</label>
							{/each}
						</div>
					{/if}
				{/if}
			</div>

			<!-- Task Details Preview -->
			<div class="bg-slate-50 rounded-lg p-4 mb-6 border border-slate-200">
				<p class="text-xs font-semibold text-slate-700 mb-2">Task Details:</p>
				<ul class="text-xs text-slate-600 space-y-1">
					<li>• Issue Type: Product Verification</li>
					<li>• Priority: Medium</li>
					<li>• Barcode: {taskToSendBarcode}</li>
					<li>• Branch: {branches.find(b => b.branch_id === selectedBranchId)?.branch_name_en || 'Unknown'}</li>
				</ul>
			</div>

			<!-- Modal Actions -->
			<div class="flex gap-3">
				<button
					on:click={() => {
						showSendTaskModal = false;
						taskToSendBarcode = null;
						taskToSendProduct = null;
						taskUserSearchQuery = ''; // Clear search
					}}
					disabled={sendingTask}
					class="flex-1 px-4 py-2 border border-slate-300 text-slate-700 font-semibold rounded-lg hover:bg-slate-50 transition-colors disabled:opacity-50"
				>
					Cancel
				</button>
				<button
					on:click={sendQuickTask}
					disabled={sendingTask || !taskSelectedUser}
					class="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white font-semibold rounded-lg transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
				>
					{#if sendingTask}
						<span class="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
						Sending...
					{:else}
						📬 Send Task
					{/if}
				</button>
			</div>
		</div>
	</div>
	{/if}
</div>

<style>
	:global(.font-sans) {
		font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
	}

	.tracking-fast {
		letter-spacing: 0.05em;
	}

	@keyframes heartbeat {
		0% {
			transform: scale(1);
			box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
		}
		25% {
			transform: scale(1.05);
			box-shadow: 0 0 0 4px rgba(239, 68, 68, 0);
		}
		50% {
			transform: scale(1);
			box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
		}
		75% {
			transform: scale(1.05);
			box-shadow: 0 0 0 4px rgba(239, 68, 68, 0);
		}
		100% {
			transform: scale(1);
			box-shadow: 0 0 0 0 rgba(239, 68, 68, 0);
		}
	}

	.heartbeat {
		animation: heartbeat 1.5s infinite;
	}
</style>
