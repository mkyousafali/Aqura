<script lang="ts">
	import ExcelJS from 'exceljs';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import JsBarcode from 'jsbarcode';

	// One Day Offer Manager Component
	let activeButton: string | null = null;
	let importedData: any[] = [];
	let filteredData: any[] = [];
	let searchQuery: string = '';
	let fileInput: HTMLInputElement;
	let offerStartDate: string = '';
	let offerEndDate: string = '';
	let showDateInputs: boolean = false;
	let startDateInput: string = '';
	let endDateInput: string = '';

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
	});

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

		let allPagesHtml = '';

		const tempImg = new Image();

		tempImg.onload = function () {
			const fields = template.field_configuration || [];

			let scaleX = 1;
			let scaleY = 1;
			if (template.metadata) {
				scaleX = a4Width / (template.metadata.preview_width || a4Width);
				scaleY = a4Height / (template.metadata.preview_height || a4Height);
			}

			let serialCounter = 1;

			filteredData.forEach((product) => {
				const printQty = parseInt(product.qty) || 1;
				for (let copyIdx = 0; copyIdx < printQty; copyIdx++) {
				let productFieldsHtml = '';

				fields.forEach((field: any) => {
					let value = '';

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
						case 'price': {
							// Use stored totalSalesPrice if manually edited, otherwise calculate
							if (product.totalSalesPrice) {
								value = parseFloat(product.totalSalesPrice).toFixed(2);
							} else {
								const salesPrice = product.salesPrice ? parseFloat(product.salesPrice) : 0;
								const qty = product.offerQty ? parseInt(product.offerQty) : 1;
								value = (salesPrice * qty).toFixed(2);
							}
							break;
						}
						case 'offer_price': {
							// Use stored totalOfferPrice if manually edited, otherwise calculate
							if (product.totalOfferPrice) {
								value = parseFloat(product.totalOfferPrice).toFixed(2);
							} else {
								const offerPriceUnit = product.offerPrice;
								const qtyOffer = product.offerQty ? parseInt(product.offerQty) : 1;
								if (offerPriceUnit) {
									const totalOfferPriceRaw = parseFloat(offerPriceUnit) * qtyOffer;
									const rounded = roundTo95(totalOfferPriceRaw);
									value = rounded.toFixed(2);
								} else {
									value = '';
								}
							}
							break;
						}
						case 'offer_qty':
							value = product.offerQty ? product.offerQty.toString() : '1';
							break;
						case 'limit_qty':
							value = product.offerLimit ? product.offerLimit.toString() : '';
							break;
						case 'expire_date':
						case 'offer_end_date':
						case 'product_expiry_date': {
							// For One Day Offer: show offer period in DD-MM-YYYY format
							const startStr = product.offerStartDate || '';
							const endStr = product.offerEndDate || '';
							if (startStr && endStr) {
								value = '<div>صالحة من ' + startStr + ' إلى ' + endStr + '</div>';
							} else {
								value = '';
							}
							break;
						}
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
								displayValue = '<div style="display:flex;align-items:baseline;"><img src="/icons/saudi-currency.png" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR"><span style="font-size:' + scaledFontSize + 'px;text-decoration:line-through;text-decoration-thickness:5px;">' + parts[0] + '.' + parts[1] + '</span></div>';
							} else {
								displayValue = '<div style="display:flex;align-items:baseline;"><img src="/icons/saudi-currency.png" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR"><span style="font-size:' + scaledFontSize + 'px;">' + parts[0] + '</span><span style="font-size:' + halfFontSize + 'px;">.' + parts[1] + '</span></div>';
							}
						} else if (field.label === 'price' || field.label === 'offer_price') {
							const halfFontSize = Math.round(scaledFontSize * 0.5);
							const currencySymbol = '<img src="/icons/saudi-currency.png" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR">';
							if (field.label === 'price') {
								displayValue = currencySymbol + '<span style="text-decoration:line-through;text-decoration-thickness:5px;">' + value + '</span>';
							} else {
								displayValue = currencySymbol + value;
							}
						}

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
				} // end printQty loop

				serialCounter++;
			});

			const htmlDoc = printWindow.document;
			htmlDoc.open();
			htmlDoc.write('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>One Day Offer</title></head><body>' + allPagesHtml + '</body></html>');
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

	// Convert YYYY-MM-DD to DD-MM-YYYY
	function toDisplayDate(isoDate: string): string {
		if (!isoDate) return '';
		const [y, m, d] = isoDate.split('-');
		return `${d}-${m}-${y}`;
	}

	// Sync date picker to display format
	$: offerStartDate = toDisplayDate(startDateInput);
	$: offerEndDate = toDisplayDate(endDateInput);

	// Average Profit % calculations
	$: avgProfitBefore = (() => {
		const valid = filteredData.filter(r => Number(r.cost) > 0);
		if (valid.length === 0) return null;
		return valid.reduce((sum, r) => sum + ((Number(r.salesPrice) - Number(r.cost)) / Number(r.cost)) * 100, 0) / valid.length;
	})();

	$: avgProfitAfter = (() => {
		const valid = filteredData.filter(r => Number(r.cost) > 0 && Number(r.offerPrice) > 0);
		if (valid.length === 0) return null;
		return valid.reduce((sum, r) => {
			const qty = Number(r.offerQty) || 1;
			return sum + (((Number(r.offerPrice) * qty) - (Number(r.cost) * qty)) / (Number(r.cost) * qty)) * 100;
		}, 0) / valid.length;
	})();

	// Reactive filtering
	$: {
		if (searchQuery.trim()) {
			const q = searchQuery.toLowerCase();
			filteredData = importedData.filter(row =>
				(row.barcode && row.barcode.toLowerCase().includes(q)) ||
				(row.englishName && row.englishName.toLowerCase().includes(q)) ||
				(row.arabicName && row.arabicName.toLowerCase().includes(q))
			);
		} else {
			filteredData = importedData;
		}
	}

	function deleteProduct(index: number) {
		const actualIndex = importedData.indexOf(filteredData[index]);
		if (actualIndex !== -1) {
			importedData.splice(actualIndex, 1);
			importedData = importedData;
		}
	}

	// Placeholder functions for buttons - to be implemented later
	async function onDownloadTemplate() {
		try {
			const workbook = new ExcelJS.Workbook();
			const worksheet = workbook.addWorksheet('One Day Offer Products');

			const headers = [
				'Barcode',
				'English name',
				'Arabic name',
				'QTY',
				'Unit',
				'Sales price',
				'Cost (cost + VAT)'
			];

			const headerRow = worksheet.addRow(headers);

			headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
			headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2563EB' } };
			headerRow.alignment = { horizontal: 'center', vertical: 'middle' };

			worksheet.columns = [
				{ key: 'barcode', width: 15 },
				{ key: 'englishName', width: 25 },
				{ key: 'arabicName', width: 25 },
				{ key: 'qty', width: 10 },
				{ key: 'unit', width: 15 },
				{ key: 'salesPrice', width: 15 },
				{ key: 'cost', width: 18 }
			];

			for (let i = 0; i < 10; i++) {
				worksheet.addRow(['', '', '', '', '', '', '']);
			}

			for (let i = 2; i <= 11; i++) {
				const row = worksheet.getRow(i);
				row.font = { color: { argb: 'FF000000' } };
				row.alignment = { horizontal: 'left', vertical: 'middle' };

				row.getCell(4).numFmt = '#,##0';    // QTY
				row.getCell(6).numFmt = '#,##0.00';  // Sales price
				row.getCell(7).numFmt = '#,##0.00';  // Cost
			}

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

			worksheet.views = [{ state: 'frozen', ySplit: 1 }];

			const buffer = await workbook.xlsx.writeBuffer();
			const blob = new Blob([buffer], {
				type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
			});

			const url = window.URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = url;
			link.download = 'One_Day_Offer_Template.xlsx';
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
			window.URL.revokeObjectURL(url);
		} catch (error) {
			console.error('Error downloading template:', error);
			alert('Error downloading template. Please try again.');
		}
	}

	function onImportFromExcel() {
		fileInput.click();
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

			worksheet.eachRow((row, rowNumber) => {
				if (rowNumber === 1) return;

				const rowData = {
					barcode: row.getCell(1).value?.toString() || '',
					englishName: row.getCell(2).value?.toString() || '',
					arabicName: row.getCell(3).value?.toString() || '',
					qty: row.getCell(4).value || '',
					unit: row.getCell(5).value?.toString() || '',
					salesPrice: row.getCell(6).value || '',
					cost: row.getCell(7).value || ''
				};

				if (rowData.barcode || rowData.englishName || rowData.arabicName) {
					importedData.push(rowData);
				}
			});

			importedData = importedData;
			
			if (importedData.length === 0) {
				alert('No data found in the file');
			} else {
				alert(`Successfully imported ${importedData.length} products`);
			}
		} catch (error) {
			console.error('Error importing file:', error);
			alert('Error importing file. Please make sure it\'s a valid Excel file.');
		}

		target.value = '';
	}

	function onGenerateOfferEndDate() {
		showDateInputs = !showDateInputs;
	}

	function assignOfferDates() {
		if (!offerStartDate || !offerEndDate) {
			alert('Please enter both start date and end date');
			return;
		}
		if (importedData.length === 0) {
			alert('No products to assign dates to');
			return;
		}
		importedData = importedData.map(row => ({
			...row,
			offerStartDate,
			offerEndDate
		}));
		alert(`Assigned offer dates to ${importedData.length} products`);
	}

	function onGenerateOfferPrice() {
		if (importedData.length === 0) {
			alert('No products to generate offer prices for');
			return;
		}

		importedData = importedData.map(row => {
			const cost = Number(row.cost) || 0;
			let salesPrice = Number(row.salesPrice) || 0;
			let salesPriceIncreased = false;

			if (cost <= 0 || salesPrice <= 0) return { ...row, offerQty: '1' };

			// Find lowest offer price >= cost that ends in .50 or .95, preferring .95
			function findLowest50or95Above(val: number): number {
				const intPart = Math.floor(val);
				// Build candidates, but prefer .95 over .50 at the same integer level
				const candidates = [
					intPart + 0.95,
					(intPart + 1) + 0.95,
					(intPart + 2) + 0.95
				];
				// Only fall back to .50 if .95 at that level is below cost
				const fallbacks = [
					intPart + 0.50,
					(intPart + 1) + 0.50,
					(intPart + 2) + 0.50
				];
				// Merge and sort all, but pick .95 first when both are valid
				const all = [...candidates, ...fallbacks].filter(c => c >= val).sort((a, b) => a - b);
				if (all.length === 0) return (intPart + 2) + 0.95;
				// Among the lowest candidates, prefer .95
				const lowest = all[0];
				const lowestInt = Math.floor(lowest);
				const prefer95 = lowestInt + 0.95;
				if (prefer95 >= val && prefer95 - lowest <= 0.45) return prefer95;
				return lowest;
			}

			// Round UP to nearest .50 or .95
			function roundUpTo50or95(val: number): number {
				const intPart = Math.floor(val);
				if (val <= intPart + 0.50) return intPart + 0.50;
				if (val <= intPart + 0.95) return intPart + 0.95;
				return (intPart + 1) + 0.50;
			}

			// Best offer price = lowest .50/.95 that is >= cost (no loss)
			const offerPrice = findLowest50or95Above(cost);

			// Check if decrease >= 2.05
			if (salesPrice - offerPrice < 2.05) {
				// Need to increase sales price
				const minSalesPrice = offerPrice + 2.05;
				salesPrice = roundUpTo50or95(minSalesPrice);
				salesPriceIncreased = true;
			}

			return {
				...row,
				offerPrice: offerPrice.toFixed(2),
				offerQty: '1',
				originalSalesPrice: Number(row.originalSalesPrice || row.salesPrice),
				salesPrice: salesPrice,
				salesPriceIncreased
			};
		});

		const increased = importedData.filter(r => r.salesPriceIncreased).length;
		const msg = increased > 0 
			? `Generated offer prices for ${importedData.length} products. ${increased} sale prices were increased (highlighted in yellow).`
			: `Generated offer prices for ${importedData.length} products.`;
		alert(msg);
	}

	async function onExportForEntry() {
		activeButton = 'export';

		if (filteredData.length === 0) {
			alert('No products to export');
			return;
		}

		try {
			const workbook = new ExcelJS.Workbook();
			const worksheet = workbook.addWorksheet('Offer Entry');

			const headers = [
				'S.No',
				'Barcode',
				'Barcode Image',
				'Product Name',
				'Unit',
				'Total Sales Price',
				'Total Offer Price',
				'Offer Type',
				'Offer Qty',
				'Free',
				'Limit'
			];

			const headerRow = worksheet.addRow(headers);
			headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
			headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2563EB' } };
			headerRow.alignment = { horizontal: 'center', vertical: 'middle' };

			worksheet.columns = [
				{ key: 'sno', width: 8 },
				{ key: 'barcode', width: 18 },
				{ key: 'barcodeImage', width: 30 },
				{ key: 'name', width: 35 },
				{ key: 'unit', width: 12 },
				{ key: 'totalSalesPrice', width: 18 },
				{ key: 'totalOfferPrice', width: 18 },
				{ key: 'offerType', width: 22 },
				{ key: 'offerQty', width: 12 },
				{ key: 'free', width: 10 },
				{ key: 'limit', width: 10 }
			];

			for (let i = 0; i < filteredData.length; i++) {
				const row = filteredData[i];
				const index = i;
				const offerQty = Number(row.offerQty) || 1;
				const salesPrice = Number(row.salesPrice) || 0;
				const offerPrice = Number(row.offerPrice) || 0;

				// Total Sales Price
				let totalSales = row.totalSalesPrice ? Number(row.totalSalesPrice) : salesPrice * offerQty;

				// Total Offer Price
				let totalOffer: number;
				if (row.totalOfferPrice) {
					totalOffer = Number(row.totalOfferPrice);
				} else {
					totalOffer = offerPrice > 0 ? roundTo95(offerPrice * offerQty) : 0;
				}

				const offerType = getOfferType(
					offerQty,
					row.offerLimit ? Number(row.offerLimit) : null,
					Number(row.offerFree) || 0,
					offerPrice
				);

				const dataRow = worksheet.addRow([
					index + 1,
					row.barcode || '',
					'', // barcode image placeholder
					row.englishName || '',
					row.unit || '',
					totalSales,
					totalOffer,
					offerType,
					offerQty,
					Number(row.offerFree) || 0,
					row.offerLimit ? Number(row.offerLimit) : ''
				]);

				dataRow.alignment = { horizontal: 'center', vertical: 'middle' };
				dataRow.getCell(3).alignment = { horizontal: 'left', vertical: 'middle' };
				dataRow.getCell(6).numFmt = '#,##0.00';
				dataRow.getCell(7).numFmt = '#,##0.00';

				// Generate barcode image
				if (row.barcode) {
					try {
						const canvas = document.createElement('canvas');
						JsBarcode(canvas, row.barcode, {
							format: 'CODE128',
							width: 2,
							height: 40,
							displayValue: true,
							fontSize: 12,
							margin: 5
						});
						const base64 = canvas.toDataURL('image/png').split(',')[1];
						const imageId = workbook.addImage({
							base64: base64,
							extension: 'png'
						});
						const rowNum = index + 2; // +2 because header is row 1
						worksheet.addImage(imageId, {
							tl: { col: 2, row: rowNum - 1 },
							ext: { width: 200, height: 40 }
						});
						dataRow.height = 45;
					} catch (e) {
						console.error('Error generating barcode for:', row.barcode, e);
					}
				}
			}

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

			worksheet.views = [{ state: 'frozen', ySplit: 1 }];

			const buffer = await workbook.xlsx.writeBuffer();
			const blob = new Blob([buffer], {
				type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
			});

			// File name: start_date_to_end_date.xlsx
			const startDate = offerStartDate || 'no-start';
			const endDate = offerEndDate || 'no-end';
			const fileName = `${startDate}_to_${endDate}.xlsx`;

			const url = window.URL.createObjectURL(blob);
			const link = document.createElement('a');
			link.href = url;
			link.download = fileName;
			document.body.appendChild(link);
			link.click();
			document.body.removeChild(link);
			window.URL.revokeObjectURL(url);
		} catch (error) {
			console.error('Error exporting:', error);
			alert('Error exporting file. Please try again.');
		}
	}

	function roundTo95(value: number): number {
		const intPart = Math.floor(value);
		const candidate1 = intPart + 0.95;
		const candidate2 = (intPart - 1) + 0.95;
		const distance1 = Math.abs(value - candidate1);
		const distance2 = Math.abs(value - candidate2);
		return distance1 <= distance2 ? candidate1 : candidate2;
	}

	function getOfferType(offerQty: number = 1, limitQty: number | null, freeQty: number = 0, offerPrice: number = 0): string {
		if (!offerPrice || offerPrice === 0) return 'Not Applicable';
		if (freeQty > 0) return `FOC ${offerQty}+${freeQty}`;
		if (offerQty === 1) {
			return !limitQty ? 'Single No Limit' : `Single ${limitQty} pcs Limit`;
		}
		if (offerQty > 1) {
			return !limitQty ? `${offerQty} pcs No Limit` : `${offerQty} pcs ${limitQty} Limit`;
		}
		return 'Unknown';
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
			label: 'Assign Offer Date',
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
		}
	];
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
			<!-- Offer Date Inputs -->
			{#if showDateInputs}
				<div class="bg-purple-50 rounded-2xl p-1.5 border border-purple-200/50 shadow-inner">
					<div class="bg-white rounded-xl px-4 py-2 border border-purple-200 flex items-center gap-3 h-[42px]">
						<label class="text-xs font-semibold text-purple-700 whitespace-nowrap">📅 Start</label>
						<input 
							type="date" 
							bind:value={startDateInput}
							class="w-36 px-2 py-1 border border-purple-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent text-sm text-center font-semibold"
						/>
						<label class="text-xs font-semibold text-purple-700 whitespace-nowrap">📅 End</label>
						<input 
							type="date" 
							bind:value={endDateInput}
							class="w-36 px-2 py-1 border border-purple-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent text-sm text-center font-semibold"
						/>
						<button 
							on:click={assignOfferDates}
							class="px-3 py-1 bg-purple-600 text-white rounded-lg text-xs font-bold hover:bg-purple-700 transition-colors"
						>
							Assign
						</button>
					</div>
				</div>
			{/if}

				<!-- Print Shelf Paper in Header -->
			{#if importedData.length > 0}
				<div class="bg-slate-100 rounded-2xl p-1.5 border border-slate-200/50 shadow-inner">
					<div class="bg-white rounded-xl px-4 py-2 border border-slate-200 flex items-center gap-3 h-[42px]">
						<label for="template-select" class="text-xs font-semibold text-slate-700 whitespace-nowrap">🖨️ Print</label>
						{#if isLoadingTemplates}
							<div class="flex items-center gap-2 min-w-[180px]">
								<svg class="animate-spin h-4 w-4 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
									<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
									<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
								</svg>
								<span class="text-xs text-slate-500">Loading templates...</span>
							</div>
						{:else}
							<select 
								id="template-select"
								bind:value={selectedTemplateId}
								class="px-2 py-1 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-xs min-w-[180px]"
							>
								<option value="">-- Select template --</option>
								{#each templates as tmpl}
									<option value={tmpl.id}>{tmpl.name}</option>
								{/each}
							</select>
						{/if}
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
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if importedData.length === 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-center">
						<div class="text-6xl mb-4">📅</div>
						<h2 class="text-2xl font-bold text-slate-900 mb-2">One Day Offer Manager</h2>
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
						</div>
					</div>

					<!-- Table Wrapper with horizontal scroll -->
					<div class="overflow-x-auto flex-1">
						<table class="w-full border-collapse">
							<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Delete</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">S.No</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Barcode</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Product Name</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Print Qty</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Unit</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Sales Price</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Changed</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Cost (VAT)</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Current Profit</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Date</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Profit %</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Price</th>							<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Total Sales Price</th>									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Total Offer Price</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Decrease</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Profit % (After)</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Type</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Offer Qty</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Free</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Limit</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each filteredData as row, index}
									<tr class="hover:bg-blue-50/30 transition-colors duration-200 {index % 2 === 0 ? 'bg-slate-50/20' : 'bg-white/20'}">
										<td class="px-4 py-3 text-sm text-center whitespace-nowrap">
											<button 
												on:click={() => deleteProduct(index)}
												class="px-1.5 py-0.5 bg-red-500 text-white rounded hover:bg-red-600 font-bold text-sm"
												title="Delete this product"
											>
												✕
											</button>
										</td>
										<td class="px-4 py-3 text-sm font-bold text-slate-800 whitespace-nowrap text-center">{index + 1}</td>
										<td class="px-4 py-3 text-sm font-mono text-slate-800 whitespace-nowrap cursor-pointer select-all" 
											title="Double-click to copy barcode"
											on:dblclick={() => {
												if (row.barcode) {
													navigator.clipboard.writeText(row.barcode).then(() => {
														const el = document.createElement('div');
														el.textContent = '✓ Copied!';
														el.className = 'fixed top-4 right-4 bg-green-600 text-white px-4 py-2 rounded-lg shadow-lg z-[99999] text-sm font-bold';
														document.body.appendChild(el);
														setTimeout(() => el.remove(), 1500);
													});
												}
											}}>{row.barcode}</td>
										<td class="px-4 py-3 text-sm text-slate-700 cursor-pointer" on:dblclick={(e) => {
											const td = e.currentTarget;
											if (td.querySelector('input')) return;
											td.innerHTML = '';
											const enInput = document.createElement('input');
											enInput.type = 'text';
											enInput.value = row.englishName || '';
											enInput.className = 'w-full px-1 py-0.5 border border-blue-300 rounded text-sm font-semibold text-slate-800 mb-1 focus:outline-none focus:ring-1 focus:ring-blue-500';
											enInput.placeholder = 'English name';
											const arInput = document.createElement('input');
											arInput.type = 'text';
											arInput.value = row.arabicName || '';
											arInput.className = 'w-full px-1 py-0.5 border border-blue-300 rounded text-xs text-slate-600 focus:outline-none focus:ring-1 focus:ring-blue-500';
											arInput.placeholder = 'Arabic name';
											arInput.dir = 'rtl';
											td.appendChild(enInput);
											td.appendChild(arInput);
											enInput.focus();
											function save() {
												row.englishName = enInput.value;
												row.arabicName = arInput.value;
												importedData = importedData;
												td.innerHTML = '';
												const enDiv = document.createElement('div');
												enDiv.className = 'font-semibold text-slate-800';
												enDiv.textContent = row.englishName;
												const arDiv = document.createElement('div');
												arDiv.className = 'text-xs text-slate-600';
												arDiv.textContent = row.arabicName;
												td.appendChild(enDiv);
												td.appendChild(arDiv);
											}
											enInput.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') arInput.focus(); if (ev.key === 'Escape') save(); });
											arInput.addEventListener('keydown', (ev) => { if (ev.key === 'Enter' || ev.key === 'Escape') save(); });
											enInput.addEventListener('blur', () => { setTimeout(() => { if (document.activeElement !== arInput) save(); }, 100); });
											arInput.addEventListener('blur', () => { setTimeout(() => { if (document.activeElement !== enInput) save(); }, 100); });
										}}>
											<div class="font-semibold text-slate-800">{row.englishName}</div>
											<div class="text-xs text-slate-600">{row.arabicName}</div>
										</td>
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap">
											<input 
												type="number" 
												value={row.qty || ''}
												on:input={(e) => {
													row.qty = e.currentTarget.value;
													importedData = importedData;
												}}
												class="w-16 px-2 py-1 border border-slate-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
												min="1"
											/>
										</td>
										<td class="px-4 py-3 text-sm text-slate-700 whitespace-nowrap">{row.unit}</td>
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap {row.salesPriceIncreased ? 'bg-yellow-300 text-yellow-900 font-bold' : ''}">
											<input 
												type="number" 
												value={typeof row.salesPrice === 'number' ? row.salesPrice.toFixed(2) : row.salesPrice}
												on:input={(e) => {
													row.salesPrice = Number(e.currentTarget.value) || 0;												row.totalSalesPrice = null;													importedData = importedData;
												}}
												class="w-24 px-2 py-1 border border-slate-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center {row.salesPriceIncreased ? 'bg-yellow-200' : ''}"
												step="0.01"
											/>
										</td>
										<td class="px-4 py-3 text-center text-sm whitespace-nowrap">
											{#if row.salesPriceIncreased}
												<span class="text-green-600" title="Sales price was increased">✅</span>
												<div class="text-xs text-slate-500 line-through">{typeof row.originalSalesPrice === 'number' ? row.originalSalesPrice.toFixed(2) : row.originalSalesPrice}</div>
											{:else}
												<span class="text-red-500" title="Sales price unchanged">❌</span>
											{/if}
										</td>
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap">
											{typeof row.cost === 'number' ? row.cost.toFixed(2) : row.cost}
										</td>
										<td class="px-4 py-3 text-sm text-center font-bold whitespace-nowrap {Number(row.salesPrice) - Number(row.cost) > 0 ? 'text-green-700 bg-green-100/50' : 'text-red-700 bg-red-100/50'}">
											{(Number(row.salesPrice) - Number(row.cost)).toFixed(2)}
										</td>
										<td class="px-4 py-3 text-sm text-center text-slate-800 whitespace-nowrap bg-purple-50/50">
											{#if row.offerStartDate && row.offerEndDate}
												<div class="text-xs font-semibold text-purple-700">{row.offerStartDate}</div>
												<div class="text-xs text-purple-500">{row.offerEndDate}</div>
											{:else}
												<span class="text-slate-400">-</span>
											{/if}
										</td>
										<td class="px-4 py-3 text-sm text-center font-bold whitespace-nowrap {Number(row.cost) > 0 ? (((Number(row.salesPrice) - Number(row.cost)) / Number(row.cost)) * 100 >= 0 ? 'text-green-700 bg-green-100/50' : 'text-red-700 bg-red-100/50') : 'text-slate-400'}">
											{#if Number(row.cost) > 0}
												{(((Number(row.salesPrice) - Number(row.cost)) / Number(row.cost)) * 100).toFixed(2)}%
											{:else}
												-
											{/if}
										</td>
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-semibold whitespace-nowrap bg-emerald-100/50">
											<input 
												type="number" 
												placeholder="Enter price"
												value={row.offerPrice || ''}
												on:input={(e) => {
													row.offerPrice = e.currentTarget.value;												row.totalOfferPrice = null;													importedData = importedData;
												}}
												class="w-full px-2 py-1 border border-emerald-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
												step="0.01"
											/>
										</td>									<td class="px-4 py-3 text-sm text-center text-slate-800 font-bold whitespace-nowrap bg-blue-100/50">
										<input 
											type="number" 
										value={row.totalSalesPrice || (Number(row.salesPrice) > 0 && Number(row.offerQty) > 0 ? (Number(row.salesPrice) * Number(row.offerQty)).toFixed(2) : '')}
										on:input={(e) => {
											const total = Number(e.currentTarget.value) || 0;
											const qty = Number(row.offerQty) || 1;
											row.totalSalesPrice = e.currentTarget.value;
											if (qty > 0 && total > 0) {
												row.salesPrice = total / qty;
											}
											importedData = importedData;
											}}
											class="w-24 px-2 py-1 border border-blue-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
											step="0.01"
										/>
									</td>										<td class="px-4 py-3 text-sm text-center text-slate-800 font-bold whitespace-nowrap bg-amber-100/50">
										<input 
											type="number" 
										value={row.totalOfferPrice || (Number(row.offerPrice) > 0 && Number(row.offerQty) > 0 ? roundTo95(Number(row.offerPrice) * Number(row.offerQty)).toFixed(2) : '')}
										on:input={(e) => {
											const total = Number(e.currentTarget.value) || 0;
											const qty = Number(row.offerQty) || 1;
											row.totalOfferPrice = e.currentTarget.value;
											if (qty > 0 && total > 0) {
												row.offerPrice = (total / qty).toFixed(2);
											}
											importedData = importedData;
											}}
											class="w-24 px-2 py-1 border border-amber-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm text-center"
											step="0.01"
										/>
									</td>
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-bold whitespace-nowrap {
											(() => {
												if (Number(row.salesPrice) <= 0 || Number(row.offerPrice) <= 0 || Number(row.offerQty) <= 0) return 'bg-orange-100/50';
												const decrease = Number(row.salesPrice) * Number(row.offerQty) - Number(row.offerPrice) * Number(row.offerQty);
												if (decrease < 0.55) return 'bg-red-500 text-white';
												if (decrease < 1.05) return 'bg-orange-500 text-white';
												if (decrease >= 3) return 'bg-green-600 text-white';
												if (decrease >= 2) return 'bg-green-400 text-white';
												return 'bg-orange-100/50';
											})()
										}">
											{#if Number(row.salesPrice) > 0 && Number(row.offerPrice) > 0 && Number(row.offerQty) > 0}
												{(Number(row.salesPrice) * Number(row.offerQty) - Number(row.offerPrice) * Number(row.offerQty)).toFixed(2)}
											{:else}
												-
											{/if}
										</td>
										<td class="px-4 py-3 text-sm text-center text-slate-800 font-bold whitespace-nowrap bg-yellow-100/50">
											{#if Number(row.cost) > 0 && Number(row.offerPrice) > 0}
												{((((Number(row.offerPrice) * (Number(row.offerQty) || 1)) - (Number(row.cost) * (Number(row.offerQty) || 1))) / (Number(row.cost) * (Number(row.offerQty) || 1))) * 100).toFixed(2)}%
											{:else}
												-
											{/if}
										</td>
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
									</tr>
								{/each}
							</tbody>
							<tfoot class="sticky bottom-0 bg-slate-800 text-white shadow-lg z-10">
								<tr>
									<td colspan="11" class="px-4 py-3 text-right text-xs font-bold uppercase tracking-wider">Average →</td>
									<td class="px-4 py-3 text-center text-sm font-bold whitespace-nowrap {avgProfitBefore !== null && avgProfitBefore >= 0 ? 'text-green-400' : 'text-red-400'}">
										{avgProfitBefore !== null ? avgProfitBefore.toFixed(2) + '%' : '-'}
									</td>
									<td colspan="4"></td>
									<td class="px-4 py-3 text-center text-sm font-bold whitespace-nowrap {avgProfitAfter !== null && avgProfitAfter >= 0 ? 'text-green-400' : 'text-red-400'}">
										{avgProfitAfter !== null ? avgProfitAfter.toFixed(2) + '%' : '-'}
									</td>
									<td colspan="4"></td>
								</tr>
							</tfoot>
						</table>
					</div>
				</div>
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
</style>
