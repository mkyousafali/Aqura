<script>
	import { onMount } from 'svelte';
	import XLSX from 'xlsx-js-style';

	export let record = null;

	let loading = true;
	let error = null;
	let headers = [];
	let displayHeaders = []; // Headers after merging name columns
	let rows = [];
	let displayRows = []; // Rows after merging name columns
	let mergedNameColIdx = -1; // Index of merged Product Name column in displayHeaders
	let mergedBarcodeColIdx = -1; // Index of merged Barcode+Unit column in displayHeaders
	let costColIdx = -1; // Index of Cost column in displayHeaders (for VAT calc)
	let salesPriceColIdx = -1; // Index of Sales Price column
	let receivedQtyColIdx = -1; // Index of Received Qty column
	let freeQtyColIdx = -1; // Index of Free Qty column
	let profitColIdx = -1; // Index of computed Profit column
	let profitPctColIdx = -1; // Index of computed Profit % column
	let tasksColIdx = -1; // Index of Tasks column
	let multiFactorColIdx = -1; // Index of MultiFactor column
	let costSrcIdx = -1; // Source index of cost column in raw data
	let salesPriceSrcIdx = -1; // Source index of sales price column in raw data
	let receivedQtySrcIdx = -1;
	let freeQtySrcIdx = -1;
	let vatPercent = 15;
	let editingCell = null; // { rowIdx, colIdx }
	let editValue = '';
	let sheetName = '';
	let colMap = []; // kept at component level for recalc
	let totalCostWithVat = 0;
	let totalSalesPrice = 0;
	let totalProfit = 0;
	let totalProfitPct = 0;
	let branches = []; // { branch_id, branch_name, tunnel_url, erp_branch_id }
	let selectedBranchIds = [];
	let branchDropdownOpen = false;
	let barcodeSrcIdx = -1; // Source index of barcode column in raw data
	let branchPriceData = {}; // { [rowIdx]: { [branch_id]: { cost, salesPrice, unitName, mfCount } } }
	let branchMfData = {}; // { [branch_id]: { [rowIdx]: { count, batchId, details: [...] } } }
	let branchMfPopup = null; // { rowIdx, branchId, branchName } for branch MF detail popup
	let loadingBranchPrices = {}; // { [branch_id]: true/false }
	let fetchingPrices = false;
	let currentBranchErp = null; // { tunnel_url, erp_branch_id } for the PR's own branch
	let multiFactorData = {}; // { [rowIdx]: { count, batchId, details: [{barcode, unit, multiFactor, sprice}] } }
	let checkingMultiFactor = false;
	let multiFactorChecked = false;
	let multiFactorPopup = null; // { rowIdx, x, y } for showing detail popup
	let _skipPopupClose = false;
	let popupVat = 15; // VAT % for popup calculations
	/** Check if any branch has a different price for any unit of this product */
	function hasBranchPriceDiff(rowIdx) {
		const local = multiFactorData[rowIdx];
		if (!local?.details?.length) return false;
		// Build map of multiFactor → sprice from current branch
		const localPrices = new Map();
		for (const d of local.details) {
			localPrices.set(d.multiFactor, d.sprice);
		}
		// Compare with each other branch
		for (const branchId of Object.keys(branchMfData)) {
			const branchInfo = branchMfData[branchId]?.[rowIdx];
			if (!branchInfo?.details?.length) continue;
			for (const bd of branchInfo.details) {
				const localPrice = localPrices.get(bd.multiFactor);
				if (localPrice !== undefined && Math.abs(localPrice - bd.sprice) > 0.001) return true;
			}
		}
		return false;
	}
	/** Check if any branch has a different cost than the Excel (current branch) cost */
	function hasBranchCostDiff(rowIdx) {
		if (costSrcIdx === -1) return false;
		const excelCost = parseFloat(rows[rowIdx]?.[costSrcIdx]) * (1 + vatPercent / 100);
		if (isNaN(excelCost)) return false;
		for (const branchId of Object.keys(branchPriceData[rowIdx] || {})) {
			const bd = branchPriceData[rowIdx][branchId];
			if (bd?.cost != null) {
				const brCostVat = bd.cost * (1 + vatPercent / 100);
				if (Math.abs(brCostVat - excelCost) > 0.01) return true;
			}
		}
		return false;
	}
	/** Check if any branch has a different sales price than the Excel (current branch) sales price */
	function hasBranchSalesDiff(rowIdx) {
		if (salesPriceSrcIdx === -1) return false;
		const excelSales = parseFloat(rows[rowIdx]?.[salesPriceSrcIdx]);
		if (isNaN(excelSales)) return false;
		for (const branchId of Object.keys(branchPriceData[rowIdx] || {})) {
			const bd = branchPriceData[rowIdx][branchId];
			if (bd?.salesPrice != null) {
				if (Math.abs(bd.salesPrice - excelSales) > 0.01) return true;
			}
		}
		return false;
	}
	let popupEditIdx = -1; // index within details array being edited
	let popupEditValue = '';
	let popupSendingIdx = -1; // index currently sending task
	let popupSentIdxs = new Set(); // indices already sent
	let sendModeIdx = -1; // which detail index shows send-mode dialog
	let sendMultiBranch = false; // show branch checkboxes
	let sendSelectedBranches = new Set(); // branch_ids selected for multi-send
	let allBranches = []; // all branches including current (for send dialog)
	// Main table task sending
	let mainOriginalPrices = {}; // { [rowIdx]: originalSalesPrice }
	let mainSendModeRowIdx = -1; // which main table row shows send dialog
	let mainSendMultiBranch = false;
	let mainSendSelectedBranches = new Set();
	let mainSendingRowIdx = -1;
	let mainSentRows = new Set();

	function startPopupPriceEdit(detailIdx, currentPrice) {
		popupEditIdx = detailIdx;
		popupEditValue = currentPrice > 0 ? currentPrice.toFixed(2) : '';
	}

	function commitPopupPriceEdit() {
		if (popupEditIdx === -1 || !multiFactorPopup) return;
		const rowIdx = multiFactorPopup.rowIdx;
		const info = multiFactorData[rowIdx];
		if (info && info.details[popupEditIdx]) {
			const val = parseFloat(popupEditValue);
			const detail = info.details[popupEditIdx];
			// Store original price on first edit
			if (detail.originalSprice === undefined) {
				detail.originalSprice = detail.sprice;
			}
			detail.sprice = isNaN(val) ? 0 : val;
			multiFactorData = { ...multiFactorData };
		}
		popupEditIdx = -1;
	}

	function handlePopupEditKeydown(e) {
		if (e.key === 'Enter') commitPopupPriceEdit();
		if (e.key === 'Escape') popupEditIdx = -1;
	}

	async function sendPopupPriceTask(detailIdx, targetBranchIds = null) {
		if (!multiFactorPopup) return;
		const rowIdx = multiFactorPopup.rowIdx;
		const info = multiFactorData[rowIdx];
		if (!info || !info.details[detailIdx]) return;
		const d = info.details[detailIdx];
		if (!d.originalSprice || d.sprice === d.originalSprice) return;

		popupSendingIdx = detailIdx;
		sendModeIdx = -1;
		sendMultiBranch = false;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { currentUser } = await import('$lib/utils/persistentAuth');
			let userId = null;
			const unsub = currentUser.subscribe(u => userId = u?.id);
			unsub();

			// Determine which branch IDs to send to
			const branchIds = targetBranchIds || [record?.branch_id].filter(Boolean);
			if (branchIds.length === 0) return;

			// Get inventory managers for all target branches
			const { data: posData } = await supabase
				.from('branch_default_positions')
				.select('branch_id, inventory_manager_user_id')
				.in('branch_id', branchIds);

			// Build branch names for description
			const branchNames = branchIds.map(bid => {
				const b = allBranches.find(br => String(br.branch_id) === String(bid));
				return b ? b.branch_name : bid;
			}).join(', ');

			const taskTitle = `Price Change | تغيير السعر: ${d.barcode} (${d.unit})`;
			const descEn = `Sales Price Change Required\n\nBarcode: ${d.barcode}\nUnit: ${d.unit}\nQty (MultiFactor): ${d.multiFactor}\nOld Price: ${d.originalSprice.toFixed(2)}\nNew Price: ${d.sprice.toFixed(2)}\nBranches: ${branchNames}`;
			const descAr = `مطلوب تغيير سعر البيع\n\nباركود: ${d.barcode}\nالوحدة: ${d.unit}\nالكمية: ${d.multiFactor}\nالسعر القديم: ${d.originalSprice.toFixed(2)}\nالسعر الجديد: ${d.sprice.toFixed(2)}\nالفروع: ${branchNames}`;

			const { data: taskData, error: taskError } = await supabase
				.from('quick_tasks')
				.insert({
					title: taskTitle,
					description: `${descEn}\n---\n${descAr}`,
					issue_type: 'price_change',
					priority: 'high',
					assigned_by: userId,
					status: 'pending',
					deadline_datetime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
				})
				.select()
				.single();

			if (taskError) {
				console.error('Error creating quick task:', taskError);
				return;
			}

			if (taskData && posData) {
				// Deduplicate inventory managers
				const uniqueManagers = [...new Set(posData.filter(p => p.inventory_manager_user_id).map(p => p.inventory_manager_user_id))];
				for (const managerId of uniqueManagers) {
					await supabase
						.from('quick_task_assignments')
						.insert({
							quick_task_id: taskData.id,
							assigned_to_user_id: managerId,
							require_task_finished: true,
							require_photo_upload: false,
							require_erp_reference: true
						});
				}
			}

			console.log('✅ Price change task sent:', taskData?.id, 'for barcode:', d.barcode, 'branches:', branchIds);
			popupSentIdxs.add(detailIdx);
			popupSentIdxs = new Set(popupSentIdxs);
		} catch (err) {
			console.error('Error sending price change task:', err);
		} finally {
			popupSendingIdx = -1;
		}
	}

	function openSendMode(detailIdx) {
		sendModeIdx = detailIdx;
		sendMultiBranch = false;
		sendSelectedBranches = new Set();
	}

	// Main table send functions
	function openMainSendMode(rowIdx) {
		mainSendModeRowIdx = rowIdx;
		mainSendMultiBranch = false;
		mainSendSelectedBranches = new Set();
	}

	function mainSendCurrentBranch(rowIdx) {
		sendMainTableTask(rowIdx, [record?.branch_id].filter(Boolean));
	}

	function mainSendMultipleBranches() {
		mainSendMultiBranch = true;
		if (record?.branch_id) mainSendSelectedBranches.add(String(record.branch_id));
		mainSendSelectedBranches = new Set(mainSendSelectedBranches);
	}

	function toggleMainSendBranch(branchId) {
		const id = String(branchId);
		if (mainSendSelectedBranches.has(id)) {
			mainSendSelectedBranches.delete(id);
		} else {
			mainSendSelectedBranches.add(id);
		}
		mainSendSelectedBranches = new Set(mainSendSelectedBranches);
	}

	function confirmMainMultiBranchSend(rowIdx) {
		if (mainSendSelectedBranches.size === 0) return;
		sendMainTableTask(rowIdx, [...mainSendSelectedBranches]);
	}

	async function sendMainTableTask(rowIdx, targetBranchIds) {
		if (!targetBranchIds || targetBranchIds.length === 0) return;
		const origPrice = mainOriginalPrices[rowIdx];
		const newPrice = parseFloat(rows[rowIdx][salesPriceSrcIdx]) || 0;
		if (origPrice === undefined || origPrice === newPrice) return;

		mainSendingRowIdx = rowIdx;
		mainSendModeRowIdx = -1;
		mainSendMultiBranch = false;
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { currentUser } = await import('$lib/utils/persistentAuth');
			let userId = null;
			const unsub = currentUser.subscribe(u => userId = u?.id);
			unsub();

			// Get barcode/unit for description
			const barcode = barcodeSrcIdx !== -1 ? rows[rowIdx][barcodeSrcIdx] : 'N/A';
			const unitName = '';

			const { data: posData } = await supabase
				.from('branch_default_positions')
				.select('branch_id, inventory_manager_user_id')
				.in('branch_id', targetBranchIds);

			const branchNames = targetBranchIds.map(bid => {
				const b = allBranches.find(br => String(br.branch_id) === String(bid));
				return b ? b.branch_name : bid;
			}).join(', ');

			const taskTitle = `Price Change | تغيير السعر: ${barcode}`;
			const descEn = `Sales Price Change Required\n\nBarcode: ${barcode}\nOld Price: ${origPrice.toFixed(2)}\nNew Price: ${newPrice.toFixed(2)}\nBranches: ${branchNames}`;
			const descAr = `مطلوب تغيير سعر البيع\n\nباركود: ${barcode}\nالسعر القديم: ${origPrice.toFixed(2)}\nالسعر الجديد: ${newPrice.toFixed(2)}\nالفروع: ${branchNames}`;

			const { data: taskData, error: taskError } = await supabase
				.from('quick_tasks')
				.insert({
					title: taskTitle,
					description: `${descEn}\n---\n${descAr}`,
					issue_type: 'price_change',
					priority: 'high',
					assigned_by: userId,
					status: 'pending',
					deadline_datetime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
				})
				.select()
				.single();

			if (taskError) {
				console.error('Error creating quick task:', taskError);
				return;
			}

			if (taskData && posData) {
				const uniqueManagers = [...new Set(posData.filter(p => p.inventory_manager_user_id).map(p => p.inventory_manager_user_id))];
				for (const managerId of uniqueManagers) {
					await supabase
						.from('quick_task_assignments')
						.insert({
							quick_task_id: taskData.id,
							assigned_to_user_id: managerId,
							require_task_finished: true,
							require_photo_upload: false,
							require_erp_reference: true
						});
				}
			}

			console.log('✅ Main table price task sent:', taskData?.id, 'row:', rowIdx);
			mainSentRows.add(rowIdx);
			mainSentRows = new Set(mainSentRows);
		} catch (err) {
			console.error('Error sending main table task:', err);
		} finally {
			mainSendingRowIdx = -1;
		}
	}

	function sendCurrentBranch(detailIdx) {
		sendPopupPriceTask(detailIdx, [record?.branch_id].filter(Boolean));
	}

	function sendMultipleBranches(detailIdx) {
		sendMultiBranch = true;
		// Pre-select current branch
		if (record?.branch_id) sendSelectedBranches.add(String(record.branch_id));
		sendSelectedBranches = new Set(sendSelectedBranches);
	}

	function toggleSendBranch(branchId) {
		const id = String(branchId);
		if (sendSelectedBranches.has(id)) {
			sendSelectedBranches.delete(id);
		} else {
			sendSelectedBranches.add(id);
		}
		sendSelectedBranches = new Set(sendSelectedBranches);
	}

	function confirmMultiBranchSend(detailIdx) {
		if (sendSelectedBranches.size === 0) return;
		sendPopupPriceTask(detailIdx, [...sendSelectedBranches]);
	}

	onMount(async () => {
		// Fetch branches from erp_connections with tunnel_url for ERP queries
		try {
			const { supabase } = await import('$lib/utils/supabase');
			const { data: erpConns, error: fetchErr } = await supabase
				.from('erp_connections')
				.select('branch_id, branch_name, tunnel_url, erp_branch_id')
				.eq('is_active', true)
				.order('branch_name');
			if (!fetchErr && erpConns) {
				// Store current branch's ERP connection for MultiFactor check
				const currentConn = erpConns.find(c => c.tunnel_url && String(c.branch_id) === String(record?.branch_id));
				if (currentConn) {
					currentBranchErp = { tunnel_url: currentConn.tunnel_url, erp_branch_id: currentConn.erp_branch_id };
				}
				// Exclude the PR Excel's own branch since its prices are already in the Excel
				branches = erpConns.filter(c => c.tunnel_url && String(c.branch_id) !== String(record?.branch_id));
				// Store all branches (including current) for multi-branch send
				allBranches = erpConns.filter(c => c.tunnel_url);
				// Don't auto-select any branch
			}
		} catch (e) {
			console.error('Failed to fetch ERP branches:', e);
		}
		if (!record?.pr_excel_file_url) {
			error = 'No PR Excel file available';
			loading = false;
			return;
		}
		await loadExcel(record.pr_excel_file_url);
	});

	async function loadExcel(url) {
		loading = true;
		error = null;
		try {
			const response = await fetch(url);
			if (!response.ok) throw new Error('Failed to fetch Excel file');
			const arrayBuffer = await response.arrayBuffer();
			const workbook = XLSX.read(arrayBuffer, { type: 'array' });
			sheetName = workbook.SheetNames[0];
			const worksheet = workbook.Sheets[sheetName];
			const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

			if (jsonData.length === 0) {
				error = 'Excel file is empty';
				loading = false;
				return;
			}

			headers = jsonData[0] || [];
			rows = jsonData.slice(1).filter(row => row.some(cell => cell !== null && cell !== undefined && cell !== ''));
			
			// Find columns to merge
			const nameEnIdx = headers.findIndex(h => h && h.toString().toLowerCase().includes('name_en'));
			const nameArIdx = headers.findIndex(h => h && h.toString().toLowerCase().includes('name_ar'));
			const barcodeIdx = headers.findIndex(h => h && h.toString().toLowerCase() === 'barcode');
			const unitIdx = headers.findIndex(h => h && h.toString().toLowerCase() === 'unit');
			barcodeSrcIdx = barcodeIdx;

			// Columns to skip (they get merged into another column)
			const skipCols = new Set();
			if (nameEnIdx !== -1 && nameArIdx !== -1) skipCols.add(nameArIdx);
			if (barcodeIdx !== -1 && unitIdx !== -1) skipCols.add(unitIdx);

			// Build merged headers and column map
			displayHeaders = [];
			colMap = [];
			mergedNameColIdx = -1;
			mergedBarcodeColIdx = -1;
			costColIdx = -1;
			salesPriceColIdx = -1;
			receivedQtyColIdx = -1;
			freeQtyColIdx = -1;
			profitColIdx = -1;
			profitPctColIdx = -1;
			costSrcIdx = -1;
			salesPriceSrcIdx = -1;
			receivedQtySrcIdx = -1;
			freeQtySrcIdx = -1;

			for (let i = 0; i < headers.length; i++) {
				if (skipCols.has(i)) continue;
				const hLower = headers[i] ? headers[i].toString().toLowerCase().trim() : '';
				if (i === nameEnIdx && nameArIdx !== -1) {
					mergedNameColIdx = displayHeaders.length;
					displayHeaders.push('Product Name');
					colMap.push({ type: 'merged', idx1: nameEnIdx, idx2: nameArIdx });
				} else if (i === barcodeIdx && unitIdx !== -1) {
					mergedBarcodeColIdx = displayHeaders.length;
					displayHeaders.push('Barcode');
					colMap.push({ type: 'barcode-unit', barcodeIdx, unitIdx });
				} else if (hLower === 'cost' || hLower === 'cost before vat') {
					costColIdx = displayHeaders.length;
					costSrcIdx = i;
					displayHeaders.push('Cost + VAT');
					colMap.push({ type: 'cost', srcIdx: i });
				} else if (hLower === 'sales price' || hLower === 'salesprice' || hLower === 'selling price') {
					salesPriceColIdx = displayHeaders.length;
					salesPriceSrcIdx = i;
					displayHeaders.push('Sales Price');
					colMap.push({ type: 'salesprice', srcIdx: i });
				} else if (hLower === 'received qty' || hLower === 'receivedqty' || hLower === 'qty') {
					receivedQtyColIdx = displayHeaders.length;
					receivedQtySrcIdx = i;
					displayHeaders.push(headers[i]);
					colMap.push({ type: 'receivedqty', srcIdx: i });
				} else if (hLower === 'free qty' || hLower === 'freeqty' || hLower === 'free') {
					freeQtyColIdx = displayHeaders.length;
					freeQtySrcIdx = i;
					displayHeaders.push(headers[i]);
					colMap.push({ type: 'freeqty', srcIdx: i });
				} else {
					displayHeaders.push(headers[i]);
					colMap.push({ type: 'normal', srcIdx: i });
				}
			}

			// Append computed Profit and Profit % columns if both cost and sales price exist
			if (costSrcIdx !== -1 && salesPriceSrcIdx !== -1) {
				profitColIdx = displayHeaders.length;
				displayHeaders.push('Profit');
				colMap.push({ type: 'profit' });

				profitPctColIdx = displayHeaders.length;
				displayHeaders.push('Profit %');
				colMap.push({ type: 'profit-pct' });
			}

			// Append MultiFactor column
			multiFactorColIdx = displayHeaders.length;
			displayHeaders.push('MF');
			colMap.push({ type: 'multifactor' });

			// Append Tasks column
			tasksColIdx = displayHeaders.length;
			displayHeaders.push('Tasks');
			colMap.push({ type: 'tasks' });

			// Build display rows
			rebuildDisplayRows();

			loading = false;

			// Auto-run MultiFactor check if branch ERP is available
			if (currentBranchErp && barcodeSrcIdx !== -1) {
				checkMultiFactor();
			}
		} catch (err) {
			console.error('Error loading Excel:', err);
			error = err.message || 'Failed to load Excel file';
			loading = false;
		}
	}

	function rebuildDisplayRows() {
		const vatMultiplier = 1 + (vatPercent / 100);
		let sumCostVat = 0;
		let sumSalesPrice = 0;

		displayRows = rows.map(row => {
			// Pre-calculate cost+VAT and sales price for profit columns
			const rawCost = costSrcIdx !== -1 ? parseFloat(row[costSrcIdx]) : NaN;
			const costWithVat = !isNaN(rawCost) ? rawCost * vatMultiplier : NaN;
			const salesPrice = salesPriceSrcIdx !== -1 ? parseFloat(row[salesPriceSrcIdx]) : NaN;
			const qty = receivedQtySrcIdx !== -1 ? parseFloat(row[receivedQtySrcIdx]) : 1;
			const freeQty = freeQtySrcIdx !== -1 ? parseFloat(row[freeQtySrcIdx]) : 0;
			const validQty = !isNaN(qty) ? qty : 1;
			const validFreeQty = !isNaN(freeQty) ? freeQty : 0;
			// Free qty is part of received qty: paid items = qty - freeQty
			const paidQty = validQty - validFreeQty;

			// Adjusted cost per unit: spread cost only over paid items across total qty
			const adjustedCost = (!isNaN(costWithVat) && validQty > 0) ? costWithVat * (paidQty / validQty) : NaN;

			if (!isNaN(costWithVat)) sumCostVat += costWithVat * paidQty;
			if (!isNaN(salesPrice)) sumSalesPrice += salesPrice * validQty;

			return colMap.map(col => {
				if (col.type === 'merged') {
					return { en: row[col.idx1] ?? '', ar: row[col.idx2] ?? '' };
				}
				if (col.type === 'barcode-unit') {
					return { barcode: row[col.barcodeIdx] ?? '', unit: row[col.unitIdx] ?? '' };
				}
				if (col.type === 'cost') {
					if (isNaN(adjustedCost)) return row[col.srcIdx] ?? '';
					if (adjustedCost !== costWithVat) return { adjusted: adjustedCost.toFixed(2), original: costWithVat.toFixed(2) };
					return adjustedCost.toFixed(2);
				}
				if (col.type === 'profit') {
					if (isNaN(adjustedCost) || isNaN(salesPrice)) return '';
					return (salesPrice - adjustedCost).toFixed(2);
				}
				if (col.type === 'profit-pct') {
					if (isNaN(adjustedCost) || isNaN(salesPrice) || adjustedCost === 0) return '';
					return (((salesPrice - adjustedCost) / adjustedCost) * 100).toFixed(1) + '%';
				}
				if (col.type === 'tasks') {
					return '';
				}
				return row[col.srcIdx] ?? '';
			});
		});

		totalCostWithVat = sumCostVat;
		totalSalesPrice = sumSalesPrice;
		totalProfit = sumSalesPrice - sumCostVat;
		totalProfitPct = sumCostVat > 0 ? ((sumSalesPrice - sumCostVat) / sumCostVat) * 100 : 0;
	}

	function onVatChange() {
		if (rows.length > 0) rebuildDisplayRows();
	}

	function isEditableCol(colIdx) {
		return colIdx === receivedQtyColIdx || colIdx === freeQtyColIdx || colIdx === costColIdx || colIdx === salesPriceColIdx;
	}

	function startEdit(rowIdx, colIdx) {
		if (!isEditableCol(colIdx)) return;
		editingCell = { rowIdx, colIdx };
		// Get the raw source value for editing
		if (colIdx === costColIdx) {
			editValue = rows[rowIdx][costSrcIdx] ?? '';
		} else if (colIdx === salesPriceColIdx) {
			editValue = rows[rowIdx][salesPriceSrcIdx] ?? '';
		} else if (colIdx === receivedQtyColIdx) {
			editValue = rows[rowIdx][receivedQtySrcIdx] ?? '';
		} else if (colIdx === freeQtyColIdx) {
			editValue = rows[rowIdx][freeQtySrcIdx] ?? '';
		}
		editValue = String(editValue);
	}

	function commitEdit() {
		if (!editingCell) return;
		const { rowIdx, colIdx } = editingCell;
		const numVal = parseFloat(editValue);
		const val = isNaN(numVal) ? editValue : numVal;

		if (colIdx === costColIdx) {
			rows[rowIdx][costSrcIdx] = val;
		} else if (colIdx === salesPriceColIdx) {
			// Track original sales price on first edit
			if (mainOriginalPrices[rowIdx] === undefined) {
				mainOriginalPrices[rowIdx] = parseFloat(rows[rowIdx][salesPriceSrcIdx]) || 0;
			}
			rows[rowIdx][salesPriceSrcIdx] = val;
		} else if (colIdx === receivedQtyColIdx) {
			rows[rowIdx][receivedQtySrcIdx] = val;
		} else if (colIdx === freeQtyColIdx) {
			rows[rowIdx][freeQtySrcIdx] = val;
		}

		editingCell = null;
		editValue = '';
		rebuildDisplayRows();
	}

	function cancelEdit() {
		editingCell = null;
		editValue = '';
	}

	function handleEditKeydown(e) {
		if (e.key === 'Enter') commitEdit();
		if (e.key === 'Escape') cancelEdit();
	}

	function toggleBranch(branchId) {
		if (selectedBranchIds.includes(branchId)) {
			selectedBranchIds = selectedBranchIds.filter(id => id !== branchId);
		} else {
			selectedBranchIds = [...selectedBranchIds, branchId];
		}
	}

	function toggleAllBranches() {
		if (selectedBranchIds.length === branches.length) {
			selectedBranchIds = [];
		} else {
			selectedBranchIds = branches.map(b => b.branch_id);
		}
	}

	function handleBranchDropdownClick(e) {
		e.stopPropagation();
		branchDropdownOpen = !branchDropdownOpen;
	}

	function closeBranchDropdown() {
		branchDropdownOpen = false;
	}

	$: selectedBranches = branches.filter(b => selectedBranchIds.includes(b.branch_id));

	async function checkMultiFactor() {
		if (!currentBranchErp || barcodeSrcIdx === -1 || rows.length === 0) return;
		checkingMultiFactor = true;
		multiFactorData = {};

		const barcodes = rows
			.map(row => row[barcodeSrcIdx])
			.filter(bc => bc !== null && bc !== undefined && bc !== '')
			.map(bc => String(bc).trim());

		if (barcodes.length === 0) {
			checkingMultiFactor = false;
			return;
		}

		const barcodeList = barcodes.map(bc => `'${bc.replace(/'/g, "''")}'`).join(',');
		const branchFilter = currentBranchErp.erp_branch_id != null ? `AND pb.BranchID = ${currentBranchErp.erp_branch_id}` : '';

		// Query to get count + BatchID for each searched barcode
		const sql = `
			SELECT SearchBarcode, BarcodeCount, BatchID
			FROM (
				SELECT SearchBarcode, BarcodeCount, BatchID,
					ROW_NUMBER() OVER (PARTITION BY SearchBarcode ORDER BY BatchID DESC) AS rn
				FROM (
					SELECT pu.BarCode AS SearchBarcode,
						pb.ProductBatchID AS BatchID,
						(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.BranchID = pb.BranchID AND pu2.BarCode IS NOT NULL AND pu2.BarCode != '') AS BarcodeCount
					FROM ProductUnits pu
					INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
					WHERE pu.BarCode IN (${barcodeList}) ${branchFilter}

					UNION ALL

					SELECT pb.MannualBarcode AS SearchBarcode,
						pb.ProductBatchID AS BatchID,
						(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.BranchID = pb.BranchID AND pu2.BarCode IS NOT NULL AND pu2.BarCode != '') AS BarcodeCount
					FROM ProductBatches pb
					WHERE pb.MannualBarcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))

					UNION ALL

					SELECT CAST(pb.AutoBarcode AS NVARCHAR(100)) AS SearchBarcode,
						pb.ProductBatchID AS BatchID,
						(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.BranchID = pb.BranchID AND pu2.BarCode IS NOT NULL AND pu2.BarCode != '') AS BarcodeCount
					FROM ProductBatches pb
					WHERE CAST(pb.AutoBarcode AS NVARCHAR(100)) IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
					AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))

					UNION ALL

					SELECT pbc.Barcode AS SearchBarcode,
						pbc.ProductBatchID AS BatchID,
						(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pbc.ProductBatchID AND pu2.BranchID = pb.BranchID AND pu2.BarCode IS NOT NULL AND pu2.BarCode != '') AS BarcodeCount
					FROM ProductBarcodes pbc
					INNER JOIN ProductBatches pb ON pbc.ProductBatchID = pb.ProductBatchID
					WHERE pbc.Barcode IN (${barcodeList}) ${branchFilter}
					AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pbc.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
				) AS Combined
			) AS Ranked
			WHERE rn = 1
		`;

		try {
			const response = await fetch('/api/erp-products', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ action: 'query', tunnelUrl: currentBranchErp.tunnel_url, sql })
			});
			const result = await response.json();
			if (result.success && result.recordset) {
				// Build map: SearchBarcode → { count, batchId }
				const countMap = new Map();
				for (const row of result.recordset) {
					countMap.set(String(row.SearchBarcode).trim(), { count: row.BarcodeCount ?? 0, batchId: row.BatchID });
				}

				// Collect all unique BatchIDs for detail query
				const batchIds = [...new Set([...countMap.values()].map(v => v.batchId).filter(Boolean))];

				// Fetch barcode details for all BatchIDs in one query
				let detailMap = new Map(); // batchId → [{barcode, unit, multiFactor, sprice}]
				if (batchIds.length > 0) {
					const batchIdList = batchIds.join(',');
					const detailSql = `
						SELECT pu.ProductBatchID, pu.BarCode, pu.MultiFactor, pu.Sprice,
							COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS BaseCost,
							(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um WHERE um.UnitID = pu.UnitID) AS UnitName
						FROM ProductUnits pu
						INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
						WHERE pu.ProductBatchID IN (${batchIdList}) ${branchFilter}
						AND pu.BarCode IS NOT NULL AND pu.BarCode != ''
						ORDER BY pu.ProductBatchID, pu.MultiFactor ASC
					`;
					try {
						const detailResp = await fetch('/api/erp-products', {
							method: 'POST',
							headers: { 'Content-Type': 'application/json' },
							body: JSON.stringify({ action: 'query', tunnelUrl: currentBranchErp.tunnel_url, sql: detailSql })
						});
						const detailResult = await detailResp.json();
						if (detailResult.success && detailResult.recordset) {
							for (const d of detailResult.recordset) {
								const bKey = String(d.ProductBatchID);
								if (!detailMap.has(bKey)) detailMap.set(bKey, []);
								detailMap.get(bKey).push({
									barcode: d.BarCode,
									unit: d.UnitName || '—',
									multiFactor: d.MultiFactor ?? 1,
									sprice: d.Sprice ?? 0,
									baseCost: d.BaseCost ?? 0
								});
							}
						}
					} catch (detailErr) {
						console.error('Error fetching barcode details:', detailErr);
					}
				}

				rows.forEach((row, rowIdx) => {
					const bc = String(row[barcodeSrcIdx] || '').trim();
					const info = countMap.get(bc);
					if (info) {
						multiFactorData[rowIdx] = {
							count: info.count,
							batchId: info.batchId,
							details: detailMap.get(String(info.batchId)) || []
						};
					}
				});
				multiFactorData = { ...multiFactorData };
			}
		} catch (err) {
			console.error('Error checking MultiFactor:', err);
		}

		checkingMultiFactor = false;
		multiFactorChecked = true;
	}

	function showMultiFactorPopup(rowIdx, event) {
		event.stopPropagation();
		event.preventDefault();
		const info = multiFactorData[rowIdx];
		if (!info || !info.details || info.details.length === 0) return;
		if (multiFactorPopup && multiFactorPopup.rowIdx === rowIdx) {
			multiFactorPopup = null;
			return;
		}
		const rect = event.currentTarget.getBoundingClientRect();
		multiFactorPopup = { rowIdx, x: rect.left, y: rect.bottom + 4 };
		_skipPopupClose = true;
		setTimeout(() => _skipPopupClose = false, 0);
	}

	function closeMultiFactorPopup() {
		if (_skipPopupClose) return;
		multiFactorPopup = null;
		branchMfPopup = null;
	}

	function showBranchMfPopup(rowIdx, branchId, branchName, event) {
		event.stopPropagation();
		event.preventDefault();
		const info = branchMfData[branchId]?.[rowIdx];
		if (!info || !info.details || info.details.length === 0) return;
		if (branchMfPopup && branchMfPopup.rowIdx === rowIdx && branchMfPopup.branchId === branchId) {
			branchMfPopup = null;
			return;
		}
		multiFactorPopup = null; // close current branch popup if open
		branchMfPopup = { rowIdx, branchId, branchName };
		_skipPopupClose = true;
		setTimeout(() => _skipPopupClose = false, 0);
	}

	// Portal action: moves element to document.body so it escapes overflow:hidden containers
	function portal(node) {
		document.body.appendChild(node);
		return {
			destroy() {
				if (node.parentNode) node.parentNode.removeChild(node);
			}
		};
	}

	async function fetchBranchPrices() {
		if (barcodeSrcIdx === -1 || selectedBranches.length === 0 || rows.length === 0) return;
		fetchingPrices = true;

		// Collect all barcodes from rows
		const barcodes = rows
			.map(row => row[barcodeSrcIdx])
			.filter(bc => bc !== null && bc !== undefined && bc !== '')
			.map(bc => String(bc).trim());

		if (barcodes.length === 0) {
			fetchingPrices = false;
			return;
		}

		// Set loading state for each branch
		selectedBranches.forEach(b => {
			loadingBranchPrices[b.branch_id] = true;
		});
		loadingBranchPrices = { ...loadingBranchPrices };

		// Use the same /price-check endpoint as mobile price checker — guarantees 100% matching logic
		const promises = selectedBranches.map(async (branch) => {
			try {
				// Call price-check per barcode in parallel batches (max 10 concurrent)
				const batchSize = 10;
				const priceMap = new Map();

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
							if (result.success && result.prices && result.prices.length > 0) {
								const price = result.prices[0];
								priceMap.set(bc, {
									cost: null,  // price-check doesn't return cost
									salesPrice: price.sprice ?? null,
									unitName: price.unit_name ?? null,
									mfCount: null
								});
							}
						} catch (err) {
							// Individual barcode error — skip silently
						}
					});
					await Promise.all(batchPromises);
				}

				// Now do a single bulk SQL query for cost data only
				const barcodeList = barcodes.map(bc => `'${bc.replace(/'/g, "''")}'`).join(',');
				const branchFilter = branch.erp_branch_id != null ? `AND pb.BranchID = ${branch.erp_branch_id}` : '';
				const costSql = `
				SELECT SearchBarcode, Cost AS LandingCost, MFCount, BatchID
				FROM (
					SELECT SearchBarcode, Cost, MFCount, BatchID,
						ROW_NUMBER() OVER (PARTITION BY SearchBarcode ORDER BY BatchID DESC) AS rn
					FROM (
						SELECT pu.BarCode AS SearchBarcode,
							COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) * pu.MultiFactor AS Cost,
							pb.ProductBatchID AS BatchID,
							(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.BranchID = pb.BranchID) AS MFCount
						FROM ProductUnits pu
						INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
						WHERE pu.BarCode IN (${barcodeList}) ${branchFilter}

						UNION ALL

						SELECT pb.MannualBarcode AS SearchBarcode,
							COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
							pb.ProductBatchID AS BatchID,
							(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.BranchID = pb.BranchID) AS MFCount
						FROM ProductBatches pb
						WHERE pb.MannualBarcode IN (${barcodeList}) ${branchFilter}
						AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))

						UNION ALL

						SELECT CAST(pb.AutoBarcode AS NVARCHAR(100)) AS SearchBarcode,
							COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
							pb.ProductBatchID AS BatchID,
							(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.BranchID = pb.BranchID) AS MFCount
						FROM ProductBatches pb
						WHERE CAST(pb.AutoBarcode AS NVARCHAR(100)) IN (${barcodeList}) ${branchFilter}
						AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
						AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))

						UNION ALL

						SELECT pb.Unit2Barcode AS SearchBarcode,
							COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
							pb.ProductBatchID AS BatchID,
							(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.BranchID = pb.BranchID) AS MFCount
						FROM ProductBatches pb
						WHERE pb.Unit2Barcode IN (${barcodeList}) ${branchFilter}
						AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
						AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))
						AND (CAST(pb.AutoBarcode AS NVARCHAR(100)) IS NULL OR CAST(pb.AutoBarcode AS NVARCHAR(100)) NOT IN (${barcodeList}))

						UNION ALL

						SELECT pb.Unit3Barcode AS SearchBarcode,
							COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
							pb.ProductBatchID AS BatchID,
							(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pb.ProductBatchID AND pu2.BranchID = pb.BranchID) AS MFCount
						FROM ProductBatches pb
						WHERE pb.Unit3Barcode IN (${barcodeList}) ${branchFilter}
						AND NOT EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = pb.ProductBatchID AND pu3.BranchID = pb.BranchID AND pu3.BarCode IN (${barcodeList}))
						AND (pb.MannualBarcode IS NULL OR pb.MannualBarcode NOT IN (${barcodeList}))
						AND (CAST(pb.AutoBarcode AS NVARCHAR(100)) IS NULL OR CAST(pb.AutoBarcode AS NVARCHAR(100)) NOT IN (${barcodeList}))
						AND (pb.Unit2Barcode IS NULL OR pb.Unit2Barcode NOT IN (${barcodeList}))

						UNION ALL

						SELECT pbc.Barcode AS SearchBarcode,
							COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS Cost,
							pbc.ProductBatchID AS BatchID,
							(SELECT COUNT(*) FROM ProductUnits pu2 WHERE pu2.ProductBatchID = pbc.ProductBatchID AND pu2.BranchID = pb.BranchID) AS MFCount
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
					if (costResult.success && costResult.recordset) {
						for (const row of costResult.recordset) {
							const bc = String(row.SearchBarcode).trim();
							const existing = priceMap.get(bc) || { cost: null, salesPrice: null, unitName: null, mfCount: null, batchId: null };
							existing.cost = row.LandingCost ?? null;
							existing.mfCount = row.MFCount ?? null;
							existing.batchId = row.BatchID ?? null;
							priceMap.set(bc, existing);
						}
					}
				} catch (err) {
					console.error(`Error fetching cost for branch ${branch.branch_id}:`, err);
				}

				// Fetch MF details for this branch (batchIds from cost results)
				const batchIds = [...new Set([...priceMap.values()].map(v => v.batchId).filter(Boolean))];
				let branchDetailMap = new Map();
				if (batchIds.length > 0) {
					const batchIdList = batchIds.join(',');
					const detailSql = `
						SELECT pu.ProductBatchID, pu.BarCode, pu.MultiFactor, pu.Sprice,
							COALESCE(NULLIF(pb.StdPurchasePrice, 0), NULLIF(pb.LastPurchaseCost, 0), NULLIF(pb.LandingCost, 0), NULLIF(pb.AvgPurchaseCost, 0), 0) AS BaseCost,
							(SELECT TOP 1 um.UnitName FROM UnitOfMeasures um WHERE um.UnitID = pu.UnitID) AS UnitName
						FROM ProductUnits pu
						INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
						WHERE pu.ProductBatchID IN (${batchIdList}) ${branchFilter}
						AND pu.BarCode IS NOT NULL AND pu.BarCode != ''
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
							for (const d of detailResult.recordset) {
								const bKey = String(d.ProductBatchID);
								if (!branchDetailMap.has(bKey)) branchDetailMap.set(bKey, []);
								branchDetailMap.get(bKey).push({
									barcode: d.BarCode,
									unit: d.UnitName || '—',
									multiFactor: d.MultiFactor ?? 1,
									sprice: d.Sprice ?? 0,
									baseCost: d.BaseCost ?? 0
								});
							}
						}
					} catch (detailErr) {
						console.error(`Error fetching MF details for branch ${branch.branch_id}:`, detailErr);
					}
				}

				// Update branchPriceData per row + store batchId for MF details
				if (!branchMfData[branch.branch_id]) branchMfData[branch.branch_id] = {};
				rows.forEach((row, rowIdx) => {
					const bc = String(row[barcodeSrcIdx] || '').trim();
					const data = priceMap.get(bc) || { cost: null, salesPrice: null, unitName: null, mfCount: null, batchId: null };
					if (!branchPriceData[rowIdx]) branchPriceData[rowIdx] = {};
					branchPriceData[rowIdx][branch.branch_id] = data;

					// Store MF details for this branch row
					if (data.batchId) {
						const details = branchDetailMap.get(String(data.batchId)) || [];
						branchMfData[branch.branch_id][rowIdx] = {
							count: data.mfCount ?? details.length,
							batchId: data.batchId,
							details
						};
					}
				});
				branchPriceData = { ...branchPriceData };
				branchMfData = { ...branchMfData };
			} catch (err) {
				console.error(`Error fetching prices for branch ${branch.branch_id}:`, err);
			} finally {
				loadingBranchPrices[branch.branch_id] = false;
				loadingBranchPrices = { ...loadingBranchPrices };
			}
		});

		await Promise.all(promises);
		fetchingPrices = false;
	}

	$: selectedBranchLabel = (() => {
		if (selectedBranchIds.length === 0) return 'None';
		if (selectedBranchIds.length === branches.length) return 'All Branches';
		if (selectedBranchIds.length === 1) {
			const b = branches.find(br => br.branch_id === selectedBranchIds[0]);
			return b?.branch_name || 'Unknown';
		}
		return `${selectedBranchIds.length} Branches`;
	})();
</script>

<svelte:window on:click={() => { closeBranchDropdown(); closeMultiFactorPopup(); }} />

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
	<!-- Header -->
	<div class="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between shadow-sm">
		<div class="flex items-center gap-3">
			<span class="text-xl filter drop-shadow-sm">🔍</span>
			<div>
				<h2 class="text-sm font-black text-slate-700 uppercase tracking-wide">Price Verifier</h2>
				<p class="text-xs text-slate-400">
					{#if record}
						Bill #{record.bill_number || 'N/A'} &middot; {record.vendors?.vendor_name || 'Unknown Vendor'}
						<br/>
						{record.branches?.name_en || record.branch_name_en || ''}{#if record.branches?.location_en || record.branch_location_en} ({record.branches?.location_en || record.branch_location_en}){/if}
					{/if}
				</p>
			</div>
		</div>
		<div class="flex items-center gap-3">
			{#if branches.length > 0}
				<div class="relative flex items-center gap-2 bg-slate-100 px-3 py-1.5 rounded-xl border border-slate-200/50">
					<span class="text-xs font-bold text-slate-500 whitespace-nowrap">Select branches to compare prices</span>
					<button
						on:click={handleBranchDropdownClick}
						class="flex items-center gap-1 px-2 py-1 text-xs font-bold bg-white border border-slate-200 rounded-lg hover:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500 cursor-pointer min-w-[100px] justify-between"
					>
						<span class="truncate">{selectedBranchLabel}</span>
						<svg class="w-3 h-3 text-slate-400 flex-shrink-0 transition-transform {branchDropdownOpen ? 'rotate-180' : ''}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
					</button>
					{#if branchDropdownOpen}
						<!-- svelte-ignore a11y-click-events-have-key-events -->
						<div
							on:click|stopPropagation
							class="absolute top-full right-0 mt-1 bg-white border border-slate-200 rounded-xl shadow-xl z-50 min-w-[200px] max-h-[280px] overflow-y-auto py-1"
						>
							<!-- Select All -->
							<label class="flex items-center gap-2.5 px-3 py-2 hover:bg-emerald-50 cursor-pointer border-b border-slate-100">
								<input
									type="checkbox"
									checked={selectedBranchIds.length === branches.length}
									on:change={toggleAllBranches}
									class="w-3.5 h-3.5 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer"
								/>
								<span class="text-xs font-bold text-slate-600">Select All</span>
							</label>
							{#each branches as branch}
								<label class="flex items-center gap-2.5 px-3 py-2 hover:bg-emerald-50 cursor-pointer">
									<input
										type="checkbox"
										checked={selectedBranchIds.includes(branch.branch_id)}
										on:change={() => toggleBranch(branch.branch_id)}
										class="w-3.5 h-3.5 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 cursor-pointer"
									/>
									<span class="text-xs font-medium text-slate-700">{branch.branch_name}</span>
								</label>
							{/each}
						</div>
					{/if}
				</div>
			{/if}
			{#if !loading && rows.length > 0}
				<div class="flex items-center gap-2 bg-slate-100 px-3 py-1.5 rounded-xl border border-slate-200/50">
					<label class="text-xs font-bold text-slate-500 whitespace-nowrap" for="vat-input">VAT %</label>
					<input
						id="vat-input"
						type="number"
						bind:value={vatPercent}
						on:change={onVatChange}
						min="0"
						max="100"
						step="0.5"
						class="w-16 px-2 py-1 text-xs font-bold text-center bg-white border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
					/>
				</div>
				<button
					on:click={() => loadExcel(record.pr_excel_file_url)}
					class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-white bg-emerald-600 rounded-xl hover:bg-emerald-700 hover:shadow-lg transition-all duration-200"
					title="Reload original Excel data"
				>
					🔄 Reload
				</button>
				<a
					href={record?.pr_excel_file_url}
					download="PR_Excel_{record?.bill_number || 'file'}.xlsx"
					class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-white bg-violet-600 rounded-xl hover:bg-violet-700 hover:shadow-lg transition-all duration-200 no-underline"
					title="Download Excel file"
				>
					⬇️ Download
				</a>
				{#if selectedBranchIds.length > 0 && barcodeSrcIdx !== -1}
					<button
						on:click={fetchBranchPrices}
						disabled={fetchingPrices}
						class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-white rounded-xl hover:shadow-lg transition-all duration-200 {fetchingPrices ? 'bg-amber-500 cursor-wait' : 'bg-blue-600 hover:bg-blue-700'}"
						title="Fetch cost & sales price from selected branch ERP servers"
					>
						{#if fetchingPrices}
							<span class="animate-spin inline-block w-3 h-3 border-2 border-white/30 border-t-white rounded-full"></span>
							Fetching...
						{:else}
							📡 Fetch Prices
						{/if}
					</button>
				{/if}
				{#if currentBranchErp && barcodeSrcIdx !== -1 && checkingMultiFactor}
					<span class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-white rounded-xl bg-amber-500">
						<span class="animate-spin inline-block w-3 h-3 border-2 border-white/30 border-t-white rounded-full"></span>
						Loading MultiFactor...
					</span>
				{/if}
				<span class="text-xs font-bold text-slate-500 bg-slate-100 px-3 py-1.5 rounded-xl border border-slate-200/50">{rows.length} rows &middot; {displayHeaders.length} columns</span>
			{/if}
		</div>
	</div>

	<!-- Main Content Area -->
	<div class="flex-1 p-6 relative overflow-hidden bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<!-- Decorative blur orbs -->
		<div class="absolute top-0 right-0 w-[400px] h-[400px] bg-emerald-100/20 rounded-full blur-[120px] -mr-48 -mt-48 animate-pulse pointer-events-none"></div>
		<div class="absolute bottom-0 left-0 w-[400px] h-[400px] bg-blue-100/20 rounded-full blur-[120px] -ml-48 -mb-48 animate-pulse pointer-events-none" style="animation-delay: 2s;"></div>

		<div class="relative h-full flex flex-col">
			{#if loading}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="animate-spin inline-block">
							<div class="w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full"></div>
						</div>
						<p class="mt-4 text-slate-600 font-semibold">Loading Excel data...</p>
					</div>
				</div>
			{:else if error}
				<div class="bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
					<div class="text-4xl mb-3">⚠️</div>
					<p class="text-red-700 font-semibold">{error}</p>
				</div>
			{:else if rows.length === 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-5xl mb-4">📄</div>
					<p class="text-slate-600 font-semibold">Excel file has no data rows</p>
				</div>
			{:else}
				<!-- Table Container -->
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col h-full">
					<!-- Table Wrapper with scroll -->
					<div class="overflow-auto flex-1">
						<table class="w-full border-collapse [&_th]:border-x [&_th]:border-emerald-500/30 [&_td]:border-x [&_td]:border-slate-200">
							<thead class="sticky top-0 bg-emerald-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400 w-12">#</th>
									{#each displayHeaders as header, i}
										<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-emerald-400 whitespace-nowrap">{header || `Col ${i + 1}`}</th>
									{/each}
									{#each selectedBranches as branch}
										<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400 whitespace-nowrap bg-blue-700" colspan="3">
											{branch.branch_name}
											{#if loadingBranchPrices[branch.branch_id]}
												<span class="inline-block w-3 h-3 ml-1 border-2 border-white/30 border-t-white rounded-full animate-spin align-middle"></span>
											{/if}
										</th>
									{/each}
								</tr>
								{#if selectedBranches.length > 0 && Object.keys(branchPriceData).length > 0}
									<tr class="bg-emerald-600">
										<th class="px-4 py-1 border-b border-emerald-400 w-12"></th>
										{#each displayHeaders as _}
											<th class="px-4 py-1 border-b border-emerald-400"></th>
										{/each}
										{#each selectedBranches as _}
											<th class="px-3 py-1 text-[10px] font-bold uppercase text-blue-100 border-b border-blue-500 bg-blue-700">Cost</th>
											<th class="px-3 py-1 text-[10px] font-bold uppercase text-blue-100 border-b border-blue-500 bg-blue-700">Sales</th>
											<th class="px-3 py-1 text-[10px] font-bold uppercase text-amber-200 border-b border-blue-500 bg-blue-700">MF</th>
										{/each}
									</tr>
								{/if}
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each displayRows as row, rowIdx}
									<tr class="hover:bg-emerald-50/30 transition-colors duration-200 {rowIdx % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
										<td class="px-4 py-3 text-xs text-slate-400 text-center font-mono">{rowIdx + 1}</td>
										{#each displayHeaders as _, colIdx}
											<td
												class="px-4 py-3 text-sm text-slate-700 {colIdx === mergedNameColIdx ? '' : 'whitespace-nowrap'} {isEditableCol(colIdx) ? 'cursor-pointer hover:bg-yellow-50/50' : ''}"
												on:dblclick={() => startEdit(rowIdx, colIdx)}
											>
												{#if editingCell && editingCell.rowIdx === rowIdx && editingCell.colIdx === colIdx}
													<input
														type="text"
														bind:value={editValue}
														on:blur={commitEdit}
														on:keydown={handleEditKeydown}
														class="w-20 px-1.5 py-0.5 text-sm font-medium text-center bg-white border-2 border-emerald-500 rounded-md focus:outline-none focus:ring-2 focus:ring-emerald-300"
														autofocus
													/>
												{:else if typeof row[colIdx] === 'object' && row[colIdx]?.en !== undefined}
													<div class="leading-tight">
														<div class="font-medium text-slate-800">{row[colIdx].en}</div>
														<div class="text-xs text-slate-400">{row[colIdx].ar}</div>
													</div>
												{:else if typeof row[colIdx] === 'object' && row[colIdx]?.barcode !== undefined}
													<div class="leading-tight">
														<div class="font-medium text-slate-800">{row[colIdx].barcode}</div>
														<div class="text-xs text-slate-800 font-medium">{row[colIdx].unit}</div>
													</div>
												{:else if colIdx === multiFactorColIdx}
													{#if checkingMultiFactor}
														<span class="inline-block w-3 h-3 border-2 border-slate-300 border-t-orange-500 rounded-full animate-spin"></span>
													{:else if multiFactorChecked && multiFactorData[rowIdx] !== undefined}
														<!-- svelte-ignore a11y_click_events_have_key_events -->
														<!-- svelte-ignore a11y_no_static_element_interactions -->
														{@const priceDiff = hasBranchPriceDiff(rowIdx)}
														<span class="inline-flex items-center gap-0.5">
															<span
																class="inline-flex items-center justify-center min-w-[22px] h-[22px] px-1.5 text-[11px] font-black rounded-full cursor-pointer hover:scale-110 transition-transform {multiFactorData[rowIdx].count > 1 ? 'bg-orange-100 text-orange-700 border border-orange-300 hover:bg-orange-200' : 'bg-slate-100 text-slate-400 border border-slate-200 hover:bg-slate-200'}"
																title="Click to see barcode details"
																on:click={(e) => showMultiFactorPopup(rowIdx, e)}
															>{multiFactorData[rowIdx].count}</span>
															{#if priceDiff}
																<span class="text-amber-500 text-[13px] leading-none" title="Branch price difference detected">⚠️</span>
															{/if}
														</span>
													{:else}
														<span class="text-slate-300">—</span>
													{/if}
												{:else if typeof row[colIdx] === 'object' && row[colIdx]?.adjusted !== undefined}
													<div class="leading-tight">
														<span class="font-bold text-slate-800">{row[colIdx].adjusted}</span>
														<span class="text-xs text-slate-400 ml-1">({row[colIdx].original})</span>
													</div>
												{:else if colIdx === tasksColIdx}
													{#if mainSentRows.has(rowIdx)}
														<span class="text-emerald-600 font-bold text-[10px]">✓ Sent</span>
													{:else if mainSendingRowIdx === rowIdx}
														<span class="inline-block w-3 h-3 border-2 border-orange-300 border-t-orange-600 rounded-full animate-spin"></span>
													{:else if mainOriginalPrices[rowIdx] !== undefined && (parseFloat(rows[rowIdx][salesPriceSrcIdx]) || 0) !== mainOriginalPrices[rowIdx]}
														<button
															on:click|stopPropagation={() => openMainSendMode(rowIdx)}
															class="px-2 py-0.5 text-[10px] font-bold rounded bg-orange-500 text-white hover:bg-orange-600 whitespace-nowrap"
														>📤 Send</button>
													{:else}
														<span class="text-slate-300">—</span>
													{/if}
												{:else if colIdx === profitColIdx || colIdx === profitPctColIdx}
													<span class="font-bold {parseFloat(row[colIdx]) > 0 ? 'text-emerald-600' : parseFloat(row[colIdx]) < 0 ? 'text-red-600' : 'text-slate-400'}">{row[colIdx]}</span>
												{:else if colIdx === costColIdx && Object.keys(branchPriceData).length > 0}
													<span class="inline-flex items-center gap-0.5">
														<span>{row[colIdx] ?? ''}</span>
														{#if hasBranchCostDiff(rowIdx)}
															<span class="text-amber-500 text-[11px] leading-none" title="Cost differs across branches">⚠️</span>
														{/if}
													</span>
												{:else if colIdx === salesPriceColIdx && Object.keys(branchPriceData).length > 0}
													<span class="inline-flex items-center gap-0.5">
														<span>{row[colIdx] ?? ''}</span>
														{#if hasBranchSalesDiff(rowIdx)}
															<span class="text-amber-500 text-[11px] leading-none" title="Sales price differs across branches">⚠️</span>
														{/if}
													</span>
												{:else}
													{row[colIdx] ?? ''}
												{/if}
											</td>
										{/each}
										{#each selectedBranches as branch}
											{@const bd = branchPriceData[rowIdx]?.[branch.branch_id]}
											{@const excelCost = costSrcIdx !== -1 ? parseFloat(rows[rowIdx][costSrcIdx]) * (1 + vatPercent / 100) : NaN}
											{@const branchCostVat = bd?.cost != null ? bd.cost * (1 + vatPercent / 100) : NaN}
											{@const excelSales = salesPriceSrcIdx !== -1 ? parseFloat(rows[rowIdx][salesPriceSrcIdx]) : NaN}
											{@const branchSales = bd?.salesPrice ?? NaN}
											<td class="px-3 py-3 text-xs text-center whitespace-nowrap font-bold {bd?.cost != null ? (!isNaN(excelCost) && branchCostVat > excelCost ? 'bg-red-100 text-red-700' : !isNaN(excelCost) && branchCostVat < excelCost ? 'bg-emerald-100 text-emerald-700' : 'bg-blue-50/30 text-slate-700') : 'bg-blue-50/30 text-slate-300'}">
												{#if loadingBranchPrices[branch.branch_id]}
													<span class="inline-block w-3 h-3 border-2 border-slate-300 border-t-blue-500 rounded-full animate-spin"></span>
												{:else}
													{bd?.cost != null ? branchCostVat.toFixed(2) : '—'}
												{/if}
											</td>
											<td class="px-3 py-3 text-xs text-center whitespace-nowrap font-bold {bd?.salesPrice != null ? (!isNaN(excelSales) && branchSales > excelSales ? 'bg-emerald-100 text-emerald-700' : !isNaN(excelSales) && branchSales < excelSales ? 'bg-red-100 text-red-700' : 'bg-blue-50/30 text-slate-700') : 'bg-blue-50/30 text-slate-300'}">
												{#if loadingBranchPrices[branch.branch_id]}
													<span class="inline-block w-3 h-3 border-2 border-slate-300 border-t-blue-500 rounded-full animate-spin"></span>
												{:else}
													{bd?.salesPrice != null ? bd.salesPrice.toFixed(2) : '—'}
												{/if}
											</td>
											{@const localMf = multiFactorData[rowIdx]?.count ?? null}
											{@const branchMf = bd?.mfCount ?? null}
											{@const mfMismatch = localMf != null && branchMf != null && localMf !== branchMf}
											{@const hasBranchMfDetails = branchMfData[branch.branch_id]?.[rowIdx]?.details?.length > 0}
											<td class="px-3 py-3 text-xs text-center whitespace-nowrap font-bold {branchMf != null ? (mfMismatch ? 'bg-red-100 text-red-700' : 'bg-blue-50/30 text-slate-700') : 'bg-blue-50/30 text-slate-300'}">
												{#if loadingBranchPrices[branch.branch_id]}
													<span class="inline-block w-3 h-3 border-2 border-slate-300 border-t-amber-500 rounded-full animate-spin"></span>
												{:else if branchMf != null && hasBranchMfDetails}
													<!-- svelte-ignore a11y_click_events_have_key_events -->
													<!-- svelte-ignore a11y_no_static_element_interactions -->
													<span
														class="inline-flex items-center justify-center min-w-[22px] h-[22px] px-1.5 text-[11px] font-black rounded-full cursor-pointer hover:scale-110 transition-transform {mfMismatch ? 'bg-red-100 text-red-700 border border-red-300 hover:bg-red-200' : branchMf > 1 ? 'bg-blue-100 text-blue-700 border border-blue-300 hover:bg-blue-200' : 'bg-slate-100 text-slate-400 border border-slate-200 hover:bg-slate-200'}"
														title="Click to see {branch.branch_name} barcode details"
														on:click={(e) => showBranchMfPopup(rowIdx, branch.branch_id, branch.branch_name, e)}
													>{branchMf}</span>
												{:else}
													{branchMf != null ? branchMf : '—'}
												{/if}
											</td>
										{/each}
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<!-- Footer -->
					<div class="px-6 py-3 bg-slate-100/50 border-t border-slate-200 flex items-center justify-between flex-wrap gap-2">
						<span class="text-xs text-slate-600 font-semibold">Showing {rows.length} rows &middot; {displayHeaders.length} columns &middot; Sheet: {sheetName}</span>
						{#if profitColIdx !== -1}
							<div class="flex items-center gap-4 flex-wrap">
								<span class="text-xs font-bold text-blue-700">
									Purchase: {totalCostWithVat.toFixed(2)}
								</span>
								<span class="text-xs font-bold text-indigo-700">
									Sales: {totalSalesPrice.toFixed(2)}
								</span>
								<span class="text-xs font-bold {totalProfit >= 0 ? 'text-emerald-700' : 'text-red-700'}">
									Profit: {totalProfit >= 0 ? '+' : ''}{totalProfit.toFixed(2)}
								</span>
								<span class="text-xs font-bold px-2 py-0.5 rounded-full {totalProfitPct >= 0 ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'}">
									{totalProfitPct >= 0 ? '+' : ''}{totalProfitPct.toFixed(1)}%
								</span>
							</div>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- MultiFactor Detail Popup -->
{#if multiFactorPopup && multiFactorData[multiFactorPopup.rowIdx]}
	{@const info = multiFactorData[multiFactorPopup.rowIdx]}
	{@const baseUnit = info.details.find(d => d.multiFactor === 1)}
	{@const basePrice = baseUnit ? baseUnit.sprice : 0}
	{@const baseCost = baseUnit ? baseUnit.baseCost : 0}
	{@const vatMult = 1 + (popupVat / 100)}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		use:portal
		class="fixed z-[99999] bg-white rounded-xl border border-slate-200 shadow-2xl overflow-hidden min-w-[620px] max-w-[90vw] max-h-[80vh] overflow-y-auto"
		style="left: 50%; top: 50%; transform: translate(-50%, -50%);"
		on:click|stopPropagation
	>
		<div class="bg-orange-600 text-white px-4 py-2 flex items-center justify-between gap-3">
			<span class="text-xs font-black uppercase tracking-wide">📦 Barcode Details ({info.details.length})</span>
			<div class="flex items-center gap-2">
				<label class="flex items-center gap-1 text-[10px] font-bold text-white/90">
					VAT %
					<input
						type="number"
						bind:value={popupVat}
						class="w-12 px-1 py-0.5 text-[10px] font-bold text-orange-800 bg-white/90 rounded border border-orange-300 text-center"
						min="0" max="100" step="0.5"
						on:click|stopPropagation
					/>
				</label>
				<button
					on:click|stopPropagation={() => { multiFactorChecked = false; multiFactorData = {}; multiFactorPopup = null; checkMultiFactor(); }}
					class="text-white/80 hover:text-white text-sm" title="Reload"
				>↻</button>
				<button
					on:click|stopPropagation={closeMultiFactorPopup}
					class="text-white/80 hover:text-white text-sm font-bold"
				>✕</button>
			</div>
		</div>
		<table class="w-full border-collapse text-xs">
			<thead>
				<tr class="bg-slate-50 border-b border-slate-200">
					<th class="px-2 py-1.5 text-left font-bold text-slate-600 uppercase tracking-wide">Barcode</th>
					<th class="px-2 py-1.5 text-center font-bold text-slate-600 uppercase tracking-wide">Unit</th>
					<th class="px-2 py-1.5 text-center font-bold text-slate-600 uppercase tracking-wide">Qty</th>
					<th class="px-2 py-1.5 text-right font-bold text-slate-600 uppercase tracking-wide">Price</th>
					<th class="px-2 py-1.5 text-right font-bold text-blue-600 uppercase tracking-wide">Qty×Price</th>
					<th class="px-2 py-1.5 text-right font-bold text-purple-600 uppercase tracking-wide">Cost</th>
					<th class="px-2 py-1.5 text-right font-bold text-rose-600 uppercase tracking-wide">Cost+VAT</th>
					<th class="px-2 py-1.5 text-right font-bold text-emerald-600 uppercase tracking-wide">Profit</th>
					<th class="px-2 py-1.5 text-right font-bold text-emerald-600 uppercase tracking-wide">Profit%</th>
					<th class="px-2 py-1.5 text-center font-bold text-orange-600 uppercase tracking-wide">Task</th>
				</tr>
			</thead>
			<tbody>
				{#each info.details as d, i}
					{@const calcPrice = d.multiFactor * basePrice}
					{@const calcCost = d.multiFactor * baseCost}
					{@const costVat = calcCost * vatMult}
					{@const profit = d.sprice - costVat}
					{@const profitPct = costVat > 0 ? (profit / costVat) * 100 : 0}
					<tr class="border-b border-slate-100 {i % 2 === 0 ? 'bg-white' : 'bg-slate-50/50'} hover:bg-orange-50/30">
						<td class="px-2 py-1.5 font-mono text-slate-700">{d.barcode}</td>
						<td class="px-2 py-1.5 text-center text-slate-600 font-medium">{d.unit}</td>
						<td class="px-2 py-1.5 text-center font-bold text-slate-800">{d.multiFactor}</td>
						<td
							class="px-2 py-1.5 text-right font-bold cursor-pointer hover:bg-yellow-50 {d.sprice > 0 ? 'text-emerald-700' : 'text-slate-400'}"
							on:dblclick|stopPropagation={() => startPopupPriceEdit(i, d.sprice)}
							title="Double-click to edit"
						>
							{#if popupEditIdx === i}
								<input
									type="text"
									inputmode="decimal"
									bind:value={popupEditValue}
									on:blur={commitPopupPriceEdit}
									on:keydown={handlePopupEditKeydown}
									on:click|stopPropagation
									class="w-16 px-1 py-0.5 text-xs font-bold text-center bg-white border-2 border-emerald-500 rounded focus:outline-none"
									autofocus
								/>
							{:else}
								{d.sprice > 0 ? d.sprice.toFixed(2) : '—'}
							{/if}
						</td>
						<td class="px-2 py-1.5 text-right font-bold {calcPrice > 0 ? 'text-blue-700' : 'text-slate-400'}">{calcPrice > 0 ? calcPrice.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {calcCost > 0 ? 'text-purple-700' : 'text-slate-400'}">{calcCost > 0 ? calcCost.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {costVat > 0 ? 'text-rose-700' : 'text-slate-400'}">{costVat > 0 ? costVat.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {profit > 0 ? 'text-emerald-700' : profit < 0 ? 'text-red-600' : 'text-slate-400'}">{d.sprice > 0 && costVat > 0 ? profit.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {profitPct > 0 ? 'text-emerald-700' : profitPct < 0 ? 'text-red-600' : 'text-slate-400'}">{d.sprice > 0 && costVat > 0 ? profitPct.toFixed(1) + '%' : '—'}</td>
						<td class="px-2 py-1.5 text-center">
							{#if popupSentIdxs.has(i)}
								<span class="text-emerald-600 font-bold text-[10px]">✓ Sent</span>
							{:else if popupSendingIdx === i}
								<span class="inline-block w-3 h-3 border-2 border-orange-300 border-t-orange-600 rounded-full animate-spin"></span>
							{:else if d.originalSprice !== undefined && d.sprice !== d.originalSprice}
								<button
									on:click|stopPropagation={() => openSendMode(i)}
									class="px-2 py-0.5 text-[10px] font-bold rounded bg-orange-500 text-white hover:bg-orange-600 whitespace-nowrap"
								>📤 Send</button>
							{:else}
								<span class="text-slate-300">—</span>
							{/if}
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>

	<!-- Send mode overlay (outside table for full visibility) -->
	{#if sendModeIdx >= 0}
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div use:portal class="fixed inset-0 z-[100000]" on:click|stopPropagation={() => { sendModeIdx = -1; sendMultiBranch = false; }}>
			<div
				class="fixed z-[100001] bg-white rounded-xl border-2 border-orange-400 shadow-2xl p-4"
				style="left: 50%; top: 50%; transform: translate(-50%, -50%);"
				on:click|stopPropagation
			>
				{#if sendMultiBranch}
					<!-- Multi-branch selection -->
					<div class="text-sm font-bold text-orange-700 mb-2 border-b border-orange-200 pb-2">Select Branches | اختر الفروع</div>
					<div class="max-h-[240px] overflow-y-auto space-y-1 min-w-[220px]">
						{#each allBranches as branch}
							<!-- svelte-ignore a11y_click_events_have_key_events -->
							<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
							<label class="flex items-center gap-2 px-2 py-1 rounded hover:bg-orange-50 cursor-pointer text-xs" on:click|stopPropagation>
								<input
									type="checkbox"
									checked={sendSelectedBranches.has(String(branch.branch_id))}
									on:change|stopPropagation={() => toggleSendBranch(branch.branch_id)}
									class="w-3.5 h-3.5 accent-orange-500"
								/>
								<span class="text-slate-700 {String(branch.branch_id) === String(record?.branch_id) ? 'font-bold text-orange-700' : ''}">{branch.branch_name}{String(branch.branch_id) === String(record?.branch_id) ? ' ★' : ''}</span>
							</label>
						{/each}
					</div>
					<div class="flex gap-2 mt-3 pt-2 border-t border-orange-200">
						<button
							on:click|stopPropagation={() => confirmMultiBranchSend(sendModeIdx)}
							disabled={sendSelectedBranches.size === 0}
							class="flex-1 px-3 py-1.5 text-xs font-bold rounded-lg bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-40"
						>📤 Send to {sendSelectedBranches.size} branch{sendSelectedBranches.size !== 1 ? 'es' : ''}</button>
						<button
							on:click|stopPropagation={() => { sendModeIdx = -1; sendMultiBranch = false; }}
							class="px-3 py-1.5 text-xs font-bold rounded-lg bg-slate-200 text-slate-600 hover:bg-slate-300"
						>Cancel</button>
					</div>
				{:else}
					<!-- Send mode choice -->
					<div class="text-sm font-bold text-orange-700 mb-3">Send Price Change | إرسال تغيير السعر</div>
					<div class="flex flex-col gap-2 min-w-[200px]">
						<button
							on:click|stopPropagation={() => sendCurrentBranch(sendModeIdx)}
							class="w-full px-4 py-2 text-xs font-bold rounded-lg bg-emerald-500 text-white hover:bg-emerald-600 whitespace-nowrap"
						>🏢 Current Branch</button>
						<button
							on:click|stopPropagation={() => sendMultipleBranches(sendModeIdx)}
							class="w-full px-4 py-2 text-xs font-bold rounded-lg bg-blue-500 text-white hover:bg-blue-600 whitespace-nowrap"
						>🏬 Multiple Branches</button>
					</div>
				{/if}
			</div>
		</div>
	{/if}
{/if}

<!-- Main table send mode overlay -->
{#if mainSendModeRowIdx >= 0}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div use:portal class="fixed inset-0 z-[100000]" on:click|stopPropagation={() => { mainSendModeRowIdx = -1; mainSendMultiBranch = false; }}>
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			class="fixed z-[100001] bg-white rounded-xl border-2 border-orange-400 shadow-2xl p-4"
			style="left: 50%; top: 50%; transform: translate(-50%, -50%);"
			on:click|stopPropagation
		>
			{#if mainSendMultiBranch}
				<div class="text-sm font-bold text-orange-700 mb-2 border-b border-orange-200 pb-2">Select Branches | اختر الفروع</div>
				<div class="max-h-[240px] overflow-y-auto space-y-1 min-w-[220px]">
					{#each allBranches as branch}
						<!-- svelte-ignore a11y_click_events_have_key_events -->
						<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
						<label class="flex items-center gap-2 px-2 py-1 rounded hover:bg-orange-50 cursor-pointer text-xs" on:click|stopPropagation>
							<input
								type="checkbox"
								checked={mainSendSelectedBranches.has(String(branch.branch_id))}
								on:change|stopPropagation={() => toggleMainSendBranch(branch.branch_id)}
								class="w-3.5 h-3.5 accent-orange-500"
							/>
							<span class="text-slate-700 {String(branch.branch_id) === String(record?.branch_id) ? 'font-bold text-orange-700' : ''}">{branch.branch_name}{String(branch.branch_id) === String(record?.branch_id) ? ' ★' : ''}</span>
						</label>
					{/each}
				</div>
				<div class="flex gap-2 mt-3 pt-2 border-t border-orange-200">
					<button
						on:click|stopPropagation={() => confirmMainMultiBranchSend(mainSendModeRowIdx)}
						disabled={mainSendSelectedBranches.size === 0}
						class="flex-1 px-3 py-1.5 text-xs font-bold rounded-lg bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-40"
					>📤 Send to {mainSendSelectedBranches.size} branch{mainSendSelectedBranches.size !== 1 ? 'es' : ''}</button>
					<button
						on:click|stopPropagation={() => { mainSendModeRowIdx = -1; mainSendMultiBranch = false; }}
						class="px-3 py-1.5 text-xs font-bold rounded-lg bg-slate-200 text-slate-600 hover:bg-slate-300"
					>Cancel</button>
				</div>
			{:else}
				<div class="text-sm font-bold text-orange-700 mb-3">Send Price Change | إرسال تغيير السعر</div>
				<div class="flex flex-col gap-2 min-w-[200px]">
					<button
						on:click|stopPropagation={() => mainSendCurrentBranch(mainSendModeRowIdx)}
						class="w-full px-4 py-2 text-xs font-bold rounded-lg bg-emerald-500 text-white hover:bg-emerald-600 whitespace-nowrap"
					>🏢 Current Branch</button>
					<button
						on:click|stopPropagation={() => mainSendMultipleBranches()}
						class="w-full px-4 py-2 text-xs font-bold rounded-lg bg-blue-500 text-white hover:bg-blue-600 whitespace-nowrap"
					>🏬 Multiple Branches</button>
				</div>
			{/if}
		</div>
	</div>
{/if}

<!-- Branch MultiFactor Detail Popup -->
{#if branchMfPopup && branchMfData[branchMfPopup.branchId]?.[branchMfPopup.rowIdx]}
	{@const bInfo = branchMfData[branchMfPopup.branchId][branchMfPopup.rowIdx]}
	{@const bBaseUnit = bInfo.details.find(d => d.multiFactor === 1)}
	{@const bBasePrice = bBaseUnit ? bBaseUnit.sprice : 0}
	{@const bBaseCost = bBaseUnit ? bBaseUnit.baseCost : 0}
	{@const bVatMult = 1 + (popupVat / 100)}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		use:portal
		class="fixed z-[99999] bg-white rounded-xl border border-slate-200 shadow-2xl overflow-hidden min-w-[560px] max-w-[90vw] max-h-[80vh] overflow-y-auto"
		style="left: 50%; top: 50%; transform: translate(-50%, -50%);"
		on:click|stopPropagation
	>
		<div class="bg-blue-600 text-white px-4 py-2 flex items-center justify-between gap-3">
			<span class="text-xs font-black uppercase tracking-wide">📦 {branchMfPopup.branchName} — Barcode Details ({bInfo.details.length})</span>
			<div class="flex items-center gap-2">
				<label class="flex items-center gap-1 text-[10px] font-bold text-white/90">
					VAT %
					<input
						type="number"
						bind:value={popupVat}
						class="w-12 px-1 py-0.5 text-[10px] font-bold text-blue-800 bg-white/90 rounded border border-blue-300 text-center"
						min="0" max="100" step="0.5"
						on:click|stopPropagation
					/>
				</label>
				<button
					on:click|stopPropagation={closeMultiFactorPopup}
					class="text-white/80 hover:text-white text-sm font-bold"
				>✕</button>
			</div>
		</div>
		<table class="w-full border-collapse text-xs">
			<thead>
				<tr class="bg-slate-50 border-b border-slate-200">
					<th class="px-2 py-1.5 text-left font-bold text-slate-600 uppercase tracking-wide">Barcode</th>
					<th class="px-2 py-1.5 text-center font-bold text-slate-600 uppercase tracking-wide">Unit</th>
					<th class="px-2 py-1.5 text-center font-bold text-slate-600 uppercase tracking-wide">Qty</th>
					<th class="px-2 py-1.5 text-right font-bold text-slate-600 uppercase tracking-wide">Price</th>
					<th class="px-2 py-1.5 text-right font-bold text-blue-600 uppercase tracking-wide">Qty×Price</th>
					<th class="px-2 py-1.5 text-right font-bold text-purple-600 uppercase tracking-wide">Cost</th>
					<th class="px-2 py-1.5 text-right font-bold text-rose-600 uppercase tracking-wide">Cost+VAT</th>
					<th class="px-2 py-1.5 text-right font-bold text-emerald-600 uppercase tracking-wide">Profit</th>
					<th class="px-2 py-1.5 text-right font-bold text-emerald-600 uppercase tracking-wide">Profit%</th>
				</tr>
			</thead>
			<tbody>
				{#each bInfo.details as d, i}
					{@const calcPrice = d.multiFactor * bBasePrice}
					{@const calcCost = d.multiFactor * bBaseCost}
					{@const costVat = calcCost * bVatMult}
					{@const profit = d.sprice - costVat}
					{@const profitPct = costVat > 0 ? (profit / costVat) * 100 : 0}
					<tr class="border-b border-slate-100 {i % 2 === 0 ? 'bg-white' : 'bg-slate-50/50'} hover:bg-blue-50/30">
						<td class="px-2 py-1.5 font-mono text-slate-700">{d.barcode}</td>
						<td class="px-2 py-1.5 text-center text-slate-600 font-medium">{d.unit}</td>
						<td class="px-2 py-1.5 text-center font-bold text-slate-800">{d.multiFactor}</td>
						<td class="px-2 py-1.5 text-right font-bold {d.sprice > 0 ? 'text-emerald-700' : 'text-slate-400'}">{d.sprice > 0 ? d.sprice.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {calcPrice > 0 ? 'text-blue-700' : 'text-slate-400'}">{calcPrice > 0 ? calcPrice.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {calcCost > 0 ? 'text-purple-700' : 'text-slate-400'}">{calcCost > 0 ? calcCost.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {costVat > 0 ? 'text-rose-700' : 'text-slate-400'}">{costVat > 0 ? costVat.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {profit > 0 ? 'text-emerald-700' : profit < 0 ? 'text-red-600' : 'text-slate-400'}">{d.sprice > 0 && costVat > 0 ? profit.toFixed(2) : '—'}</td>
						<td class="px-2 py-1.5 text-right font-bold {profitPct > 0 ? 'text-emerald-700' : profitPct < 0 ? 'text-red-600' : 'text-slate-400'}">{d.sprice > 0 && costVat > 0 ? profitPct.toFixed(1) + '%' : '—'}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}