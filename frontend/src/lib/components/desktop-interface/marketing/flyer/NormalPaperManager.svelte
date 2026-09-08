<script lang="ts">
	import ExcelJS from 'exceljs';
	import JsBarcode from 'jsbarcode';
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { iconUrlMap } from '$lib/stores/iconStore';

	let activeButton: string | null = null;
	let importedData: any[] = [];
	let fileInput: HTMLInputElement;

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

	onMount(async () => {
		await Promise.all([loadTemplates(), loadCustomFonts()]);
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

	function printShelfPaper() {
		if (!selectedTemplateId) {
			alert('Please select a template first');
			return;
		}

		if (importedData.length === 0) {
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

			importedData.forEach((product) => {
				const copies = product.printQty || 1;

				for (let copy = 0; copy < copies; copy++) {
					let productFieldsHtml = '';

					fields.forEach((field: any) => {
						let value = '';

						switch (field.label) {
							case 'product_name_en':
								value = product.productNameEn || '';
								break;
							case 'product_name_ar':
								value = product.productNameAr || '';
								break;
							case 'barcode':
								value = product.barcode || '';
								break;
							case 'serial_number':
								value = serialCounter.toString();
								break;
							case 'unit_name':
								value = product.unitName || '';
								break;
							case 'price':
								value = product.salesPrice ? Number(product.salesPrice).toFixed(2) : '';
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
							const fontWeight = field.label.includes('price') ? 'font-weight:bold;' : 'font-weight:600;';
							const fontFamilyStyle = field.fontFamily ? "font-family:'" + field.fontFamily + "',sans-serif;" : '';

							let displayValue = value;

							// Render barcode as scannable image
							if (field.label === 'barcode' && value) {
								try {
									const canvas = document.createElement('canvas');
									JsBarcode(canvas, value, {
										format: 'CODE128',
										width: 2,
										height: Math.max(scaledHeight - scaledFontSize - 4, 30),
										displayValue: true,
										fontSize: scaledFontSize,
										margin: 2
									});
									const imgSrc = canvas.toDataURL('image/png');
									productFieldsHtml += '<div style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;display:flex;align-items:center;justify-content:' + justifyContent + ';"><img src="' + imgSrc + '" style="max-width:100%;max-height:100%;object-fit:contain;" alt="barcode"></div>';
									return;
								} catch (e) {
									console.error('Error generating barcode:', e);
								}
							}

							if (field.label === 'price' && value.includes('.')) {
								const parts = value.split('.');
								const halfFontSize = Math.round(scaledFontSize * 0.5);
								displayValue = '<div style="display:flex;align-items:baseline;"><img src="' + ($iconUrlMap['saudi-currency'] || '/icons/saudi-currency.png') + '" style="width:auto;height:' + halfFontSize + 'px;margin-right:4px;" alt="SAR"><span style="font-size:' + scaledFontSize + 'px;">' + parts[0] + '</span><span style="font-size:' + halfFontSize + 'px;">.' + parts[1] + '</span></div>';
							}

							productFieldsHtml += '<div style="position:absolute;left:' + scaledX + 'px;top:' + scaledY + 'px;width:' + scaledWidth + 'px;height:' + scaledHeight + 'px;z-index:10;overflow:hidden;"><div style="width:100%;height:100%;font-size:' + scaledFontSize + 'px;text-align:' + field.alignment + ';color:' + (field.color || '#000000') + ';display:flex;align-items:center;justify-content:' + justifyContent + ';' + fontWeight + dirAttr + fontFamilyStyle + '">' + displayValue + '</div></div>';
						}
					});

					let pageHtml = '<div style="position:relative;width:' + a4Width + 'px;height:' + a4Height + 'px;overflow:hidden;page-break-inside:avoid;background:white;display:block;">';
					pageHtml += '<img src="' + template.template_image_url + '" style="width:' + a4Width + 'px;height:' + a4Height + 'px;position:absolute;top:0;left:0;z-index:1;display:block;" alt="Template">';
					pageHtml += productFieldsHtml;
					pageHtml += '</div>';
					allPagesHtml += pageHtml;
				}

				serialCounter++;
			});

			const htmlDoc = printWindow.document;
			htmlDoc.open();
			htmlDoc.write('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Normal Paper Print</title></head><body>' + allPagesHtml + '</body></html>');
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

	async function onDownloadTemplate() {
		try {
			const workbook = new ExcelJS.Workbook();
			const worksheet = workbook.addWorksheet('Normal Paper Products');

			const headers = [
				'Barcode',
				'Product Name (English)',
				'Product Name (Arabic)',
				'Print Qty',
				'Unit Name',
				'Sales Price'
			];

			const headerRow = worksheet.addRow(headers);

			headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
			headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2563EB' } };
			headerRow.alignment = { horizontal: 'center', vertical: 'middle' };

			worksheet.columns = [
				{ key: 'barcode', width: 18 },
				{ key: 'productNameEn', width: 30 },
				{ key: 'productNameAr', width: 30 },
				{ key: 'printQty', width: 12 },
				{ key: 'unitName', width: 15 },
				{ key: 'salesPrice', width: 15 }
			];

			for (let i = 0; i < 10; i++) {
				worksheet.addRow(['', '', '', '', '', '']);
			}

			for (let i = 2; i <= 11; i++) {
				const row = worksheet.getRow(i);
				row.font = { color: { argb: 'FF000000' } };
				row.alignment = { horizontal: 'left', vertical: 'middle' };
				row.getCell(4).numFmt = '#,##0';
				row.getCell(6).numFmt = '#,##0.00';
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
			link.download = 'Normal_Paper_Template.xlsx';
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
					productNameEn: row.getCell(2).value?.toString() || '',
					productNameAr: row.getCell(3).value?.toString() || '',
					printQty: Number(row.getCell(4).value) || 1,
					unitName: row.getCell(5).value?.toString() || '',
					salesPrice: Number(row.getCell(6).value) || 0
				};

				if (rowData.barcode || rowData.productNameEn || rowData.productNameAr) {
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
			alert("Error importing file. Please make sure it's a valid Excel file.");
		}

		target.value = '';
	}

	function deleteProduct(index: number) {
		importedData = importedData.filter((_, i) => i !== index);
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
		}
	];
</script>

<input
	type="file"
	accept=".xlsx,.xls"
	bind:this={fileInput}
	on:change={handleFileImport}
	style="display: none;"
/>

<div class="h-full flex flex-col bg-[#f8fafc] overflow-hidden font-sans">
{#if isLoadingTemplates}
	<div class="flex-1 flex items-center justify-center">
		<div class="text-center">
			<div class="text-4xl mb-3 animate-spin">⏳</div>
			<p class="text-slate-500 text-sm font-semibold">Loading templates...</p>
		</div>
	</div>
{:else}
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

		<!-- Print Template Dropdown -->
		<div class="bg-slate-100 rounded-2xl p-1.5 border border-slate-200/50 shadow-inner">
			<div class="bg-white rounded-xl px-4 py-2 border border-slate-200 flex items-center gap-3 h-[42px]">
				<label for="template-select" class="text-xs font-semibold text-slate-700 whitespace-nowrap">🖨️ Print</label>
				<select 
					id="template-select"
					bind:value={selectedTemplateId}
					disabled={isLoadingTemplates}
					class="px-2 py-1 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-xs min-w-[180px]"
				>
					{#if isLoadingTemplates}
						<option value="">Loading templates...</option>
					{:else}
						<option value="">-- Select template ({templates.length}) --</option>
						{#each templates as template}
							<option value={template.id}>{template.name}</option>
						{/each}
					{/if}
				</select>
				<button 
					on:click={printShelfPaper}
					disabled={!selectedTemplateId || importedData.length === 0 || isLoadingTemplates}
					class="px-3 py-1 bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 text-white rounded-lg text-xs font-semibold transition-colors whitespace-nowrap"
				>
					Print
				</button>
			</div>
		</div>
	</div>

	<!-- Content Area -->
	<div class="flex-1 p-8 relative overflow-y-auto bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white via-slate-50/50 to-slate-100/50">
		<div class="absolute top-0 right-0 w-[500px] h-[500px] bg-blue-100/20 rounded-full blur-[120px] -mr-64 -mt-64 animate-pulse"></div>
		<div class="absolute bottom-0 left-0 w-[500px] h-[500px] bg-orange-100/20 rounded-full blur-[120px] -ml-64 -mb-64 animate-pulse" style="animation-delay: 2s;"></div>

		<div class="relative max-w-[99%] mx-auto h-full flex flex-col">
			{#if importedData.length === 0}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] p-12 h-full flex flex-col items-center justify-center border-dashed border-2 border-slate-200">
					<div class="text-center">
						<div class="text-6xl mb-4">📄</div>
						<h2 class="text-2xl font-bold text-slate-900 mb-2">Normal Paper Manager</h2>
						<p class="text-slate-600 text-lg">Download template and import data to get started</p>
					</div>
				</div>
			{:else}
				<div class="bg-white/40 backdrop-blur-xl rounded-[2.5rem] border border-white shadow-[0_32px_64px_-16px_rgba(0,0,0,0.08)] overflow-hidden flex flex-col">
					<!-- Table Info Header -->
					<div class="px-6 py-4 bg-gradient-to-r from-blue-50 to-emerald-50 border-b border-slate-200">
						<div class="flex items-center justify-between">
							<div>
								<h3 class="text-lg font-bold text-slate-900">Imported Products</h3>
								<p class="text-sm text-slate-600 mt-1">{importedData.length} product{importedData.length !== 1 ? 's' : ''} loaded</p>
							</div>
						</div>
					</div>

					<!-- Table -->
					<div class="overflow-x-auto flex-1">
						<table class="w-full border-collapse">
							<thead class="sticky top-0 bg-blue-600 text-white shadow-lg z-10">
								<tr>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Delete</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">S.No</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Barcode</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Product Name (EN)</th>
									<th class="px-4 py-3 text-right text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Product Name (AR)</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Print Qty</th>
									<th class="px-4 py-3 text-left text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Unit</th>
									<th class="px-4 py-3 text-center text-xs font-black uppercase tracking-wider border-b-2 border-blue-400">Sales Price</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-slate-200">
								{#each importedData as row, index}
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
										<td class="px-4 py-3 text-sm text-center font-bold text-slate-500">{index + 1}</td>
										<td class="px-4 py-3 text-sm font-mono text-slate-700">{row.barcode}</td>
										<td class="px-4 py-3 text-sm text-slate-800">{row.productNameEn}</td>
										<td class="px-4 py-3 text-sm text-slate-800 text-right" dir="rtl">{row.productNameAr}</td>
										<td class="px-4 py-3 text-sm text-center">
											<input 
												type="number"
												min="1"
												bind:value={row.printQty}
												class="w-16 px-2 py-1 border border-slate-300 rounded-lg text-center text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
											/>
										</td>
										<td class="px-4 py-3 text-sm text-slate-700">{row.unitName}</td>
										<td class="px-4 py-3 text-sm text-center font-semibold text-slate-700">{Number(row.salesPrice).toFixed(2)}</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}
		</div>
	</div>
{/if}
</div>
