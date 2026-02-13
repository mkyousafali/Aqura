import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { action, serverIp, databaseName, username, password } = await request.json();

		if (action === 'test') {
			return await testConnection(serverIp, databaseName, username, password);
		} else if (action === 'sync') {
			return await syncProducts(serverIp, databaseName, username, password);
		}

		return json({ error: 'Invalid action' }, { status: 400 });
	} catch (error: any) {
		console.error('ERP Products API error:', error);
		return json({ error: error.message || 'Internal server error' }, { status: 500 });
	}
};

async function testConnection(serverIp: string, databaseName: string, username: string, password: string) {
	try {
		const sql = await import('mssql');
		
		const config: any = {
			user: username,
			password: password,
			server: serverIp,
			database: databaseName,
			options: {
				encrypt: false,
				trustServerCertificate: true
			},
			connectionTimeout: 10000,
			requestTimeout: 10000
		};

		const pool = await sql.default.connect(config);
		
		// Count all barcode sources
		const counts = await pool.request().query(`
			SELECT
				(SELECT COUNT(*) FROM ProductBatches WHERE MannualBarcode IS NOT NULL AND MannualBarcode != '') AS ManualBarcodes,
				(SELECT COUNT(*) FROM ProductBatches WHERE AutoBarcode IS NOT NULL AND AutoBarcode != '') AS AutoBarcodes,
				(SELECT COUNT(*) FROM ProductBatches WHERE Unit2Barcode IS NOT NULL AND Unit2Barcode != '') AS Unit2Barcodes,
				(SELECT COUNT(*) FROM ProductBatches WHERE Unit3Barcode IS NOT NULL AND Unit3Barcode != '') AS Unit3Barcodes,
				(SELECT COUNT(*) FROM ProductUnits WHERE BarCode IS NOT NULL AND BarCode != '') AS UnitBarcodes,
				(SELECT COUNT(*) FROM ProductBarcodes WHERE Barcode IS NOT NULL AND Barcode != '') AS ExtraBarcodes,
				(SELECT COUNT(DISTINCT ProductID) FROM Products) AS TotalProducts,
				(SELECT COUNT(*) FROM ProductBatches) AS TotalBatches,
				(SELECT COUNT(*) FROM (
					SELECT CAST(MannualBarcode AS NVARCHAR(100)) as bc FROM ProductBatches WHERE MannualBarcode IS NOT NULL AND MannualBarcode != ''
					UNION SELECT CAST(AutoBarcode AS NVARCHAR(100)) FROM ProductBatches WHERE AutoBarcode IS NOT NULL AND AutoBarcode != ''
					UNION SELECT CAST(Unit2Barcode AS NVARCHAR(100)) FROM ProductBatches WHERE Unit2Barcode IS NOT NULL AND Unit2Barcode != ''
					UNION SELECT CAST(Unit3Barcode AS NVARCHAR(100)) FROM ProductBatches WHERE Unit3Barcode IS NOT NULL AND Unit3Barcode != ''
					UNION SELECT CAST(BarCode AS NVARCHAR(100)) FROM ProductUnits WHERE BarCode IS NOT NULL AND BarCode != ''
					UNION SELECT CAST(Barcode AS NVARCHAR(100)) FROM ProductBarcodes WHERE Barcode IS NOT NULL AND Barcode != ''
				) u) AS UniqueBarcodes
		`);
		const c = counts.recordset[0];
		await pool.close();

		return json({
			success: true,
			message: `Connection successful!`,
			counts: {
				manualBarcodes: c.ManualBarcodes,
				autoBarcodes: c.AutoBarcodes,
				unit2Barcodes: c.Unit2Barcodes,
				unit3Barcodes: c.Unit3Barcodes,
				unitBarcodes: c.UnitBarcodes,
				extraBarcodes: c.ExtraBarcodes,
				totalProducts: c.TotalProducts,
				totalBatches: c.TotalBatches,
				totalAll: c.ManualBarcodes + c.AutoBarcodes + c.Unit2Barcodes + c.Unit3Barcodes + c.UnitBarcodes + c.ExtraBarcodes,
				uniqueBarcodes: c.UniqueBarcodes
			}
		});
	} catch (error: any) {
		console.error('Test connection error:', error);
		return json({
			success: false,
			message: `Connection failed: ${error.message}`
		});
	}
}

async function syncProducts(serverIp: string, databaseName: string, username: string, password: string) {
	try {
		const sql = await import('mssql');
		
		const config: any = {
			user: username,
			password: password,
			server: serverIp,
			database: databaseName,
			options: {
				encrypt: false,
				trustServerCertificate: true
			},
			connectionTimeout: 30000,
			requestTimeout: 120000
		};

		const pool = await sql.default.connect(config);

		// Step 1: Get all products from ProductBatches (manual AND auto barcodes)
		const baseProductsResult = await pool.request().query(`
			SELECT 
				pb.ProductBatchID,
				pb.ProductID,
				pb.AutoBarcode,
				pb.MannualBarcode,
				pb.Unit2Barcode,
				pb.Unit3Barcode,
				p.ProductName,
				p.ItemNameinSecondLanguage
			FROM ProductBatches pb
			INNER JOIN Products p ON pb.ProductID = p.ProductID
			WHERE (pb.MannualBarcode IS NOT NULL AND pb.MannualBarcode != '')
			   OR (pb.AutoBarcode IS NOT NULL AND pb.AutoBarcode != '')
			   OR (pb.Unit2Barcode IS NOT NULL AND pb.Unit2Barcode != '')
			   OR (pb.Unit3Barcode IS NOT NULL AND pb.Unit3Barcode != '')
		`);

		const baseProducts = baseProductsResult.recordset;

		// Step 2: Get ALL units from ProductUnits (including those without barcodes, for unit name resolution)
		const unitsResult = await pool.request().query(`
			SELECT 
				pu.ProductBatchID,
				pu.UnitID,
				pu.MultiFactor,
				ISNULL(pu.BarCode, '') as BarCode,
				pu.Sprice,
				u.UnitName
			FROM ProductUnits pu
			INNER JOIN UnitOfMeasures u ON pu.UnitID = u.UnitID
			ORDER BY pu.ProductBatchID, pu.MultiFactor
		`);

		const allUnits = unitsResult.recordset;

		// Step 3: Get extra barcodes from ProductBarcodes table
		const extraBarcodesResult = await pool.request().query(`
			SELECT 
				pbc.ProductBatchID,
				pbc.Barcode,
				pbc.UnitID,
				ISNULL(u.UnitName, '') as UnitName,
				pb.MannualBarcode,
				pb.AutoBarcode,
				p.ProductName,
				p.ItemNameinSecondLanguage
			FROM ProductBarcodes pbc
			INNER JOIN ProductBatches pb ON pbc.ProductBatchID = pb.ProductBatchID
			INNER JOIN Products p ON pb.ProductID = p.ProductID
			LEFT JOIN UnitOfMeasures u ON pbc.UnitID = u.UnitID
			WHERE pbc.Barcode IS NOT NULL AND pbc.Barcode != ''
		`);

		const extraBarcodes = extraBarcodesResult.recordset;
		await pool.close();

		// Step 4: Build flat list of all barcodes with product info
		const products: any[] = [];
		const addedBarcodes = new Set<string>(); // Track to avoid duplicates

		// Pre-group units by ProductBatchID for O(1) lookup
		const unitsByBatchId = new Map<string, any[]>();
		for (const u of allUnits) {
			const batchId = String(u.ProductBatchID);
			if (!unitsByBatchId.has(batchId)) unitsByBatchId.set(batchId, []);
			unitsByBatchId.get(batchId)!.push(u);
		}

		// For each base product, add manual barcode, auto barcode, and all unit barcodes
		for (const bp of baseProducts) {
			const productUnits = unitsByBatchId.get(String(bp.ProductBatchID)) || [];
			// baseUnit = unit with MultiFactor=1 (from ALL units, including those without barcodes)
			const baseUnit = productUnits.find((u: any) => parseFloat(u.MultiFactor) === 1) || productUnits[0];
			const parentBarcode = String(bp.MannualBarcode || bp.AutoBarcode || '').trim();

			// Build barcode→unit lookup for this product (only units that HAVE barcodes)
			const unitByBarcode = new Map<string, any>();
			for (const u of productUnits) {
				const bc = String(u.BarCode || '').trim();
				if (bc) unitByBarcode.set(bc, u);
			}

			// Add MannualBarcode as a row
			const manualBC = String(bp.MannualBarcode || '').trim();
			if (manualBC && !addedBarcodes.has(manualBC)) {
				const matchedUnit = unitByBarcode.get(manualBC);
				products.push({
					barcode: manualBC,
					auto_barcode: String(bp.AutoBarcode || '').trim(),
					parent_barcode: parentBarcode,
					product_name_en: bp.ProductName || '',
					product_name_ar: bp.ItemNameinSecondLanguage || '',
					unit_name: matchedUnit ? matchedUnit.UnitName : (baseUnit ? baseUnit.UnitName : ''),
					unit_qty: matchedUnit ? (parseFloat(matchedUnit.MultiFactor) || 1) : 1,
					is_base_unit: true
				});
				addedBarcodes.add(manualBC);
			}

			// Add AutoBarcode as its own row ONLY if no MannualBarcode exists
			// Otherwise it's the same product — just mark it as added to prevent duplicates
			const autoBC = String(bp.AutoBarcode || '').trim();
			if (autoBC && !addedBarcodes.has(autoBC)) {
				if (!manualBC) {
					// No manual barcode — auto barcode is the primary identifier
					const matchedUnit = unitByBarcode.get(autoBC);
					products.push({
						barcode: autoBC,
						auto_barcode: autoBC,
						parent_barcode: parentBarcode,
						product_name_en: bp.ProductName || '',
						product_name_ar: bp.ItemNameinSecondLanguage || '',
						unit_name: matchedUnit ? matchedUnit.UnitName : (baseUnit ? baseUnit.UnitName : ''),
						unit_qty: matchedUnit ? (parseFloat(matchedUnit.MultiFactor) || 1) : 1,
						is_base_unit: true
					});
				}
				// Always mark as added so it won't appear again from unit/extra barcodes
				addedBarcodes.add(autoBC);
			}

			// Add Unit2Barcode as its own row
			const unit2BC = String(bp.Unit2Barcode || '').trim();
			if (unit2BC && !addedBarcodes.has(unit2BC)) {
				const matchedUnit = unitByBarcode.get(unit2BC);
				products.push({
					barcode: unit2BC,
					auto_barcode: autoBC,
					parent_barcode: parentBarcode,
					product_name_en: bp.ProductName || '',
					product_name_ar: bp.ItemNameinSecondLanguage || '',
					unit_name: matchedUnit ? matchedUnit.UnitName : '',
					unit_qty: matchedUnit ? (parseFloat(matchedUnit.MultiFactor) || 1) : 1,
					is_base_unit: false
				});
				addedBarcodes.add(unit2BC);
			}

			// Add Unit3Barcode as its own row
			const unit3BC = String(bp.Unit3Barcode || '').trim();
			if (unit3BC && !addedBarcodes.has(unit3BC)) {
				const matchedUnit = unitByBarcode.get(unit3BC);
				products.push({
					barcode: unit3BC,
					auto_barcode: autoBC,
					parent_barcode: parentBarcode,
					product_name_en: bp.ProductName || '',
					product_name_ar: bp.ItemNameinSecondLanguage || '',
					unit_name: matchedUnit ? matchedUnit.UnitName : '',
					unit_qty: matchedUnit ? (parseFloat(matchedUnit.MultiFactor) || 1) : 1,
					is_base_unit: false
				});
				addedBarcodes.add(unit3BC);
			}

			// Add all unit barcodes (only those that have actual barcodes)
			for (const unit of productUnits) {
				const unitBC = String(unit.BarCode || '').trim();
				if (!unitBC) continue; // Skip units without barcodes
				if (addedBarcodes.has(unitBC)) continue;
				
				products.push({
					barcode: unitBC,
					auto_barcode: autoBC,
					parent_barcode: parentBarcode,
					product_name_en: bp.ProductName || '',
					product_name_ar: bp.ItemNameinSecondLanguage || '',
					unit_name: unit.UnitName || '',
					unit_qty: parseFloat(unit.MultiFactor) || 1,
					is_base_unit: parseFloat(unit.MultiFactor) === 1
				});
				addedBarcodes.add(unitBC);
			}
		}

		// Step 5: Add barcodes from ProductBarcodes table (extras not already added)
		for (const eb of extraBarcodes) {
			const ebBC = String(eb.Barcode || '').trim();
			if (!ebBC || addedBarcodes.has(ebBC)) continue;
			
			products.push({
				barcode: ebBC,
				auto_barcode: String(eb.AutoBarcode || '').trim(),
				parent_barcode: String(eb.MannualBarcode || '').trim(),
				product_name_en: eb.ProductName || '',
				product_name_ar: eb.ItemNameinSecondLanguage || '',
				unit_name: eb.UnitName || '',
				unit_qty: 1,
				is_base_unit: false
			});
			addedBarcodes.add(ebBC);
		}

		return json({
			success: true,
			products: products,
			totalProducts: products.length,
			baseProductsCount: baseProducts.length,
			message: `Fetched ${products.length} barcodes from ${baseProducts.length} products`
		});
	} catch (error: any) {
		console.error('Sync products error:', error);
		return json({
			success: false,
			error: error.message || 'Failed to sync products'
		}, { status: 500 });
	}
}
