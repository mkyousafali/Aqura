/**
 * ERP Bridge API Server
 * 
 * This runs on each branch's SQL Server machine and exposes
 * the ERP database via HTTP API through a Cloudflare Tunnel.
 * 
 * Vercel serverless functions call this HTTP API instead of
 * connecting directly to SQL Server (which requires raw TCP).
 * 
 * Setup on each branch server:
 *   1. Install Node.js
 *   2. mkdir C:\erp-api && cd C:\erp-api
 *   3. npm init -y && npm install express mssql cors
 *   4. Copy this file to C:\erp-api\server.js
 *   5. node server.js (or install as Windows service with node-windows)
 * 
 * Environment (edit the constants below per branch):
 *   - SQL_SERVER: localhost (or the SQL Server IP on the same machine)
 *   - SQL_DATABASE: e.g. URBAN2_2025
 *   - SQL_USER: sa
 *   - SQL_PASSWORD: Polosys*123
 *   - API_SECRET: shared secret to authenticate requests from Vercel
 *   - PORT: 3333
 */

const express = require('express');
const sql = require('mssql');
const cors = require('cors');

// ========== CONFIGURATION - EDIT PER BRANCH ==========
const SQL_SERVER = 'localhost';
const SQL_DATABASE = 'URBAN2_2025';
const SQL_USER = 'sa';
const SQL_PASSWORD = 'Polosys*123';
const API_SECRET = 'aqura-erp-bridge-2026';  // Must match the secret in Vercel env
const PORT = 3333;
// =====================================================

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// SQL connection config
const sqlConfig = {
  user: SQL_USER,
  password: SQL_PASSWORD,
  server: SQL_SERVER,
  database: SQL_DATABASE,
  options: {
    encrypt: false,
    trustServerCertificate: true
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000
  },
  connectionTimeout: 15000,
  requestTimeout: 120000
};

// Connection pool (reused across requests)
let pool = null;

async function getPool() {
  if (!pool) {
    pool = await sql.connect(sqlConfig);
    pool.on('error', (err) => {
      console.error('SQL Pool Error:', err);
      pool = null;
    });
  }
  return pool;
}

// Auth middleware
function authenticate(req, res, next) {
  const secret = req.headers['x-api-secret'];
  if (secret !== API_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

// Health check
app.get('/health', async (req, res) => {
  try {
    const p = await getPool();
    await p.request().query('SELECT 1 AS ok');
    res.json({ status: 'healthy', database: SQL_DATABASE, server: SQL_SERVER });
  } catch (err) {
    pool = null;
    res.status(500).json({ status: 'unhealthy', error: err.message });
  }
});

// Test connection - returns stats about barcodes
app.post('/test', authenticate, async (req, res) => {
  try {
    const p = await getPool();
    const counts = await p.request().query(`
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
    res.json({
      success: true,
      message: 'Connection successful!',
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
  } catch (err) {
    pool = null;
    res.json({ success: false, message: `Connection failed: ${err.message}` });
  }
});

// Sync products - fetch all barcodes with product info
app.post('/sync', authenticate, async (req, res) => {
  try {
    const { erpBranchId, appBranchId } = req.body;
    const p = await getPool();

    // Get all products from ProductBatches
    const baseProductsResult = await p.request().query(`
      SELECT 
        pb.ProductBatchID, pb.ProductID, pb.AutoBarcode, pb.MannualBarcode,
        pb.Unit2Barcode, pb.Unit3Barcode, pb.ExpiryDate, pb.BranchID,
        p.ProductName, p.ItemNameinSecondLanguage
      FROM ProductBatches pb
      INNER JOIN Products p ON pb.ProductID = p.ProductID
      WHERE (pb.MannualBarcode IS NOT NULL AND pb.MannualBarcode != '')
         OR (pb.AutoBarcode IS NOT NULL AND pb.AutoBarcode != '')
         OR (pb.Unit2Barcode IS NOT NULL AND pb.Unit2Barcode != '')
         OR (pb.Unit3Barcode IS NOT NULL AND pb.Unit3Barcode != '')
    `);
    const baseProducts = baseProductsResult.recordset;

    // Get ALL units from ProductUnits
    const unitsResult = await p.request().query(`
      SELECT pu.ProductBatchID, pu.UnitID, pu.MultiFactor,
        ISNULL(pu.BarCode, '') as BarCode, pu.Sprice, u.UnitName
      FROM ProductUnits pu
      INNER JOIN UnitOfMeasures u ON pu.UnitID = u.UnitID
      ORDER BY pu.ProductBatchID, pu.MultiFactor
    `);
    const allUnits = unitsResult.recordset;

    // Get extra barcodes from ProductBarcodes table
    const extraBarcodesResult = await p.request().query(`
      SELECT pbc.ProductBatchID, pbc.Barcode, pbc.UnitID,
        ISNULL(u.UnitName, '') as UnitName,
        pb.MannualBarcode, pb.AutoBarcode, pb.ExpiryDate, pb.BranchID,
        p.ProductName, p.ItemNameinSecondLanguage
      FROM ProductBarcodes pbc
      INNER JOIN ProductBatches pb ON pbc.ProductBatchID = pb.ProductBatchID
      INNER JOIN Products p ON pb.ProductID = p.ProductID
      LEFT JOIN UnitOfMeasures u ON pbc.UnitID = u.UnitID
      WHERE pbc.Barcode IS NOT NULL AND pbc.Barcode != ''
    `);
    const extraBarcodes = extraBarcodesResult.recordset;

    // Build flat list of all barcodes with product info
    const products = [];
    const addedBarcodes = new Set();
    const expiryMap = new Map();

    function addExpiryEntry(barcode, expiryDate, erpBranchIdFromRow) {
      if (!barcode) return;
      const expStr = expiryDate ? new Date(expiryDate).toISOString().split('T')[0] : null;
      if (!expStr || expStr === '1900-01-01' || expStr === '2000-01-01') return;
      const entry = { expiry_date: expStr };
      if (appBranchId) entry.branch_id = appBranchId;
      if (erpBranchId) entry.erp_branch_id = erpBranchId;
      if (erpBranchIdFromRow != null) entry.erp_row_branch_id = Number(erpBranchIdFromRow);
      if (!expiryMap.has(barcode)) expiryMap.set(barcode, []);
      const existing = expiryMap.get(barcode);
      const isDup = existing.some(e => e.expiry_date === expStr && e.branch_id === entry.branch_id);
      if (!isDup) existing.push(entry);
    }

    // Pre-populate expiryMap
    for (const bp of baseProducts) {
      const manualBC = String(bp.MannualBarcode || '').trim();
      const autoBC = String(bp.AutoBarcode || '').trim();
      const unit2BC = String(bp.Unit2Barcode || '').trim();
      const unit3BC = String(bp.Unit3Barcode || '').trim();
      if (manualBC) addExpiryEntry(manualBC, bp.ExpiryDate, bp.BranchID);
      if (autoBC) addExpiryEntry(autoBC, bp.ExpiryDate, bp.BranchID);
      if (unit2BC) addExpiryEntry(unit2BC, bp.ExpiryDate, bp.BranchID);
      if (unit3BC) addExpiryEntry(unit3BC, bp.ExpiryDate, bp.BranchID);
    }
    for (const u of allUnits) {
      const unitBC = String(u.BarCode || '').trim();
      if (!unitBC) continue;
      const parentBatch = baseProducts.find(bp => String(bp.ProductBatchID) === String(u.ProductBatchID));
      if (parentBatch) addExpiryEntry(unitBC, parentBatch.ExpiryDate, parentBatch.BranchID);
    }
    for (const eb of extraBarcodes) {
      const ebBC = String(eb.Barcode || '').trim();
      if (ebBC) addExpiryEntry(ebBC, eb.ExpiryDate, eb.BranchID);
    }

    // Group units by batch ID
    const unitsByBatchId = new Map();
    for (const u of allUnits) {
      const batchId = String(u.ProductBatchID);
      if (!unitsByBatchId.has(batchId)) unitsByBatchId.set(batchId, []);
      unitsByBatchId.get(batchId).push(u);
    }

    // Build products list
    for (const bp of baseProducts) {
      const productUnits = unitsByBatchId.get(String(bp.ProductBatchID)) || [];
      const baseUnit = productUnits.find(u => parseFloat(u.MultiFactor) === 1) || productUnits[0];
      const parentBarcode = String(bp.MannualBarcode || bp.AutoBarcode || '').trim();
      const unitByBarcode = new Map();
      for (const u of productUnits) {
        const bc = String(u.BarCode || '').trim();
        if (bc) unitByBarcode.set(bc, u);
      }

      const manualBC = String(bp.MannualBarcode || '').trim();
      if (manualBC && !addedBarcodes.has(manualBC)) {
        const matchedUnit = unitByBarcode.get(manualBC);
        products.push({
          barcode: manualBC, auto_barcode: String(bp.AutoBarcode || '').trim(),
          parent_barcode: parentBarcode,
          product_name_en: bp.ProductName || '', product_name_ar: bp.ItemNameinSecondLanguage || '',
          unit_name: matchedUnit ? matchedUnit.UnitName : (baseUnit ? baseUnit.UnitName : ''),
          unit_qty: matchedUnit ? (parseFloat(matchedUnit.MultiFactor) || 1) : 1,
          is_base_unit: true, expiry_dates: expiryMap.get(manualBC) || []
        });
        addedBarcodes.add(manualBC);
      }

      const autoBC = String(bp.AutoBarcode || '').trim();
      if (autoBC && !addedBarcodes.has(autoBC)) {
        if (!manualBC) {
          const matchedUnit = unitByBarcode.get(autoBC);
          products.push({
            barcode: autoBC, auto_barcode: autoBC, parent_barcode: parentBarcode,
            product_name_en: bp.ProductName || '', product_name_ar: bp.ItemNameinSecondLanguage || '',
            unit_name: matchedUnit ? matchedUnit.UnitName : (baseUnit ? baseUnit.UnitName : ''),
            unit_qty: matchedUnit ? (parseFloat(matchedUnit.MultiFactor) || 1) : 1,
            is_base_unit: true, expiry_dates: expiryMap.get(autoBC) || []
          });
        }
        addedBarcodes.add(autoBC);
      }

      const unit2BC = String(bp.Unit2Barcode || '').trim();
      if (unit2BC && !addedBarcodes.has(unit2BC)) {
        const matchedUnit = unitByBarcode.get(unit2BC);
        products.push({
          barcode: unit2BC, auto_barcode: autoBC, parent_barcode: parentBarcode,
          product_name_en: bp.ProductName || '', product_name_ar: bp.ItemNameinSecondLanguage || '',
          unit_name: matchedUnit ? matchedUnit.UnitName : '',
          unit_qty: matchedUnit ? (parseFloat(matchedUnit.MultiFactor) || 1) : 1,
          is_base_unit: false, expiry_dates: expiryMap.get(unit2BC) || []
        });
        addedBarcodes.add(unit2BC);
      }

      const unit3BC = String(bp.Unit3Barcode || '').trim();
      if (unit3BC && !addedBarcodes.has(unit3BC)) {
        const matchedUnit = unitByBarcode.get(unit3BC);
        products.push({
          barcode: unit3BC, auto_barcode: autoBC, parent_barcode: parentBarcode,
          product_name_en: bp.ProductName || '', product_name_ar: bp.ItemNameinSecondLanguage || '',
          unit_name: matchedUnit ? matchedUnit.UnitName : '',
          unit_qty: matchedUnit ? (parseFloat(matchedUnit.MultiFactor) || 1) : 1,
          is_base_unit: false, expiry_dates: expiryMap.get(unit3BC) || []
        });
        addedBarcodes.add(unit3BC);
      }

      for (const unit of productUnits) {
        const unitBC = String(unit.BarCode || '').trim();
        if (!unitBC || addedBarcodes.has(unitBC)) continue;
        products.push({
          barcode: unitBC, auto_barcode: autoBC, parent_barcode: parentBarcode,
          product_name_en: bp.ProductName || '', product_name_ar: bp.ItemNameinSecondLanguage || '',
          unit_name: unit.UnitName || '', unit_qty: parseFloat(unit.MultiFactor) || 1,
          is_base_unit: parseFloat(unit.MultiFactor) === 1,
          expiry_dates: expiryMap.get(unitBC) || []
        });
        addedBarcodes.add(unitBC);
      }
    }

    for (const eb of extraBarcodes) {
      const ebBC = String(eb.Barcode || '').trim();
      if (!ebBC || addedBarcodes.has(ebBC)) continue;
      products.push({
        barcode: ebBC, auto_barcode: String(eb.AutoBarcode || '').trim(),
        parent_barcode: String(eb.MannualBarcode || '').trim(),
        product_name_en: eb.ProductName || '', product_name_ar: eb.ItemNameinSecondLanguage || '',
        unit_name: eb.UnitName || '', unit_qty: 1, is_base_unit: false,
        expiry_dates: expiryMap.get(ebBC) || []
      });
      addedBarcodes.add(ebBC);
    }

    res.json({
      success: true, products, totalProducts: products.length,
      baseProductsCount: baseProducts.length,
      message: `Fetched ${products.length} barcodes from ${baseProducts.length} products`
    });
  } catch (err) {
    pool = null;
    console.error('Sync error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Update expiry date
app.post('/update-expiry', authenticate, async (req, res) => {
  try {
    const { barcode, newExpiryDate } = req.body;
    const p = await getPool();

    const findResult = await p.request()
      .input('barcode', sql.NVarChar, barcode)
      .query(`
        SELECT DISTINCT pb.ProductBatchID FROM ProductBatches pb
        WHERE pb.MannualBarcode = @barcode OR CAST(pb.AutoBarcode AS NVARCHAR(100)) = @barcode
           OR pb.Unit2Barcode = @barcode OR pb.Unit3Barcode = @barcode
        UNION
        SELECT DISTINCT pu.ProductBatchID FROM ProductUnits pu WHERE pu.BarCode = @barcode
        UNION
        SELECT DISTINCT pbc.ProductBatchID FROM ProductBarcodes pbc WHERE pbc.Barcode = @barcode
      `);

    const batchIds = findResult.recordset.map(r => r.ProductBatchID);
    if (batchIds.length === 0) {
      return res.json({ success: false, error: `Barcode ${barcode} not found in ERP` });
    }

    const idList = batchIds.map(id => `'${id}'`).join(',');
    const safeDateStr = newExpiryDate.replace(/-/g, '');

    const updateResult = await p.request()
      .input('newExpiry', sql.NVarChar, safeDateStr)
      .query(`UPDATE ProductBatches SET ExpiryDate = CONVERT(datetime, @newExpiry, 112) WHERE ProductBatchID IN (${idList})`);

    const verifyResult = await p.request()
      .query(`SELECT ProductBatchID, ExpiryDate FROM ProductBatches WHERE ProductBatchID IN (${idList})`);

    res.json({
      success: true, updatedRows: updateResult.rowsAffected[0],
      batchIds, verifiedDates: verifyResult.recordset,
      message: `Updated ${updateResult.rowsAffected[0]} batch(es) in ERP`
    });
  } catch (err) {
    pool = null;
    console.error('Update expiry error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n========================================`);
  console.log(`  ERP Bridge API Server`);
  console.log(`  Port: ${PORT}`);
  console.log(`  Database: ${SQL_DATABASE}`);
  console.log(`  SQL Server: ${SQL_SERVER}`);
  console.log(`========================================\n`);
});
