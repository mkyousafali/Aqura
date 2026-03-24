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
require('dotenv').config();

// ========== CONFIGURATION - from .env or defaults ==========
const SQL_SERVER = process.env.SQL_SERVER || 'localhost';
const SQL_DATABASE = process.env.SQL_DATABASE || 'URBAN2_2025';
const SQL_USER = process.env.SQL_USER || 'sa';
const SQL_PASSWORD = process.env.SQL_PASSWORD || '';
const API_SECRET = process.env.API_SECRET || '';
const PORT = process.env.PORT || 3333;
// ===========================================================

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

// In-memory cache for batch sync (avoids re-running SQL for each batch)
let syncCache = null;
let syncCacheTime = 0;
const SYNC_CACHE_TTL = 300000; // 5 minutes
let syncBuildingPromise = null; // tracks if a build is in progress

// Background function to build product list from SQL
async function buildProductList(erpBranchId, appBranchId, cacheKey) {
    const p = await getPool();

    // Build branch filter - if erpBranchId is provided, only sync that branch's products
    const branchFilter = erpBranchId ? `AND pb.BranchID = ${parseInt(erpBranchId)}` : '';
    const branchFilterWhere = erpBranchId ? `WHERE pb.BranchID = ${parseInt(erpBranchId)}` : '';

    console.log(`[sync-build] erpBranchId=${erpBranchId || 'ALL'}, appBranchId=${appBranchId || 'N/A'}, filter: ${branchFilter || 'NONE'}`);

    // Get products from ProductBatches (filtered by branch if provided)
    const baseProductsResult = await p.request().query(`
      SELECT 
        pb.ProductBatchID, pb.ProductID, pb.AutoBarcode, pb.MannualBarcode,
        pb.Unit2Barcode, pb.Unit3Barcode, pb.ExpiryDate, pb.BranchID,
        p.ProductName, p.ItemNameinSecondLanguage
      FROM ProductBatches pb
      INNER JOIN Products p ON pb.ProductID = p.ProductID
      WHERE ((pb.MannualBarcode IS NOT NULL AND pb.MannualBarcode != '')
         OR (pb.AutoBarcode IS NOT NULL AND pb.AutoBarcode != '')
         OR (pb.Unit2Barcode IS NOT NULL AND pb.Unit2Barcode != '')
         OR (pb.Unit3Barcode IS NOT NULL AND pb.Unit3Barcode != ''))
      ${branchFilter}
    `);
    const baseProducts = baseProductsResult.recordset;
    console.log(`[sync-build] Got ${baseProducts.length} base products from SQL`);

    // Get units only for the filtered batches
    const unitsResult = await p.request().query(`
      SELECT pu.ProductBatchID, pu.UnitID, pu.MultiFactor,
        ISNULL(pu.BarCode, '') as BarCode, pu.Sprice, u.UnitName
      FROM ProductUnits pu
      INNER JOIN UnitOfMeasures u ON pu.UnitID = u.UnitID
      INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
      WHERE 1=1 ${branchFilter}
      ORDER BY pu.ProductBatchID, pu.MultiFactor
    `);
    const allUnits = unitsResult.recordset;

    // Get extra barcodes only for the filtered batches
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
      ${branchFilter}
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

    // Build a fast lookup map for base products by batch ID (avoids O(n*m) .find() loops)
    const baseProductByBatchId = new Map();
    for (const bp of baseProducts) {
      baseProductByBatchId.set(String(bp.ProductBatchID), bp);
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
      const parentBatch = baseProductByBatchId.get(String(u.ProductBatchID));
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

    // Cache the full product list
    syncCache = { key: cacheKey, products };
    syncCacheTime = Date.now();
    console.log(`[sync-build] Built and cached ${products.length} products`);
    return products;
}

// Sync products - fetch barcodes with product info (supports limit/offset batching)
// First call triggers async build and returns immediately. Client retries until cache is ready.
app.post('/sync', authenticate, async (req, res) => {
  try {
    const { erpBranchId, appBranchId, limit, offset } = req.body;
    const fetchLimit = parseInt(limit) || 0;   // 0 = no limit (return all)
    const fetchOffset = parseInt(offset) || 0;
    const cacheKey = `${erpBranchId || 'ALL'}-${appBranchId || 'N/A'}`;
    const now = Date.now();

    // 1) If cache is valid, return from it
    if (syncCache && syncCache.key === cacheKey && (now - syncCacheTime) < SYNC_CACHE_TTL) {
      const products = syncCache.products;
      const totalCount = products.length;
      console.log(`[sync] Serving from cache (${totalCount} items, age: ${Math.round((now - syncCacheTime) / 1000)}s)`);

      if (fetchLimit > 0) {
        const sliced = products.slice(fetchOffset, fetchOffset + fetchLimit);
        const hasMore = (fetchOffset + fetchLimit) < totalCount;
        return res.json({
          success: true, products: sliced, totalCount, hasMore,
          offset: fetchOffset, limit: fetchLimit,
          message: `Batch ${Math.floor(fetchOffset / fetchLimit) + 1}: ${sliced.length} of ${totalCount}`
        });
      } else {
        return res.json({
          success: true, products, totalProducts: totalCount,
          totalCount, hasMore: false,
          baseProductsCount: totalCount,
          message: `Fetched ${totalCount} barcodes`
        });
      }
    }

    // 2) If build is already in progress, tell client to retry
    if (syncBuildingPromise) {
      console.log(`[sync] Build in progress, telling client to retry...`);
      return res.json({
        success: true, status: 'building', retry: true,
        message: 'Building product list from SQL... please wait'
      });
    }

    // 3) Start building in background, return immediately
    console.log(`[sync] Starting async build for ${cacheKey}...`);
    syncBuildingPromise = buildProductList(erpBranchId, appBranchId, cacheKey)
      .then(() => {
        syncBuildingPromise = null;
        console.log(`[sync] Async build complete!`);
      })
      .catch(err => {
        syncBuildingPromise = null;
        console.error(`[sync] Async build FAILED:`, err.message);
      });

    return res.json({
      success: true, status: 'building', retry: true,
      message: 'Started building product list from SQL... please retry in a few seconds'
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

// Temporary: Read-only SQL query endpoint (SELECT only)
app.post('/query', authenticate, async (req, res) => {
  try {
    const { sql: queryText } = req.body;
    if (!queryText || typeof queryText !== 'string') {
      return res.status(400).json({ success: false, error: 'Missing sql parameter' });
    }
    // Safety: only allow SELECT statements
    const trimmed = queryText.trim().toUpperCase();
    if (!trimmed.startsWith('SELECT')) {
      return res.status(403).json({ success: false, error: 'Only SELECT queries are allowed' });
    }
    const p = await getPool();
    const result = await p.request().query(queryText);
    res.json({ success: true, recordset: result.recordset, rowCount: result.recordset.length });
  } catch (err) {
    pool = null;
    console.error('Query error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ========== PRICE CHECK — single round-trip endpoint ==========
// Does all barcode lookup + offer detection in one call (all SQL local)
app.post('/price-check', authenticate, async (req, res) => {
  try {
    const { barcode, erpBranchId } = req.body;
    if (!barcode) return res.status(400).json({ success: false, error: 'Missing barcode' });

    const p = await getPool();
    const safeBarcode = barcode.replace(/'/g, "''");
    const branchFilter = erpBranchId ? `AND pb.BranchID = ${parseInt(erpBranchId)}` : '';

    let productName = '', productNameAr = '', unitPrice = 0, unitName = '', multiFactor = 1, batchId = null, foundBarcode = barcode;

    // ---------- Step 1: Find product by barcode ----------

    // 1a) ProductUnits
    const r1 = await p.request().query(`
      SELECT pu.BarCode, pu.ProductBatchID, MAX(pu.Sprice) AS Sprice, pu.MultiFactor,
        u.UnitName, p.ProductName, p.ItemNameinSecondLanguage
      FROM ProductUnits pu
      INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
      INNER JOIN Products p ON pb.ProductID = p.ProductID
      LEFT JOIN UnitOfMeasures u ON pu.UnitID = u.UnitID
      WHERE pu.BarCode = '${safeBarcode}' ${branchFilter}
      GROUP BY pu.BarCode, pu.ProductBatchID, pu.MultiFactor, u.UnitName, p.ProductName, p.ItemNameinSecondLanguage
    `);

    if (r1.recordset.length > 0) {
      const row = r1.recordset[0];
      productName = row.ProductName || '';
      productNameAr = row.ItemNameinSecondLanguage || '';
      unitPrice = row.Sprice || 0;
      unitName = row.UnitName || '';
      multiFactor = row.MultiFactor || 1;
      batchId = row.ProductBatchID;
      foundBarcode = row.BarCode || barcode;
    }

    // 1b) ProductBarcodes
    if (!batchId) {
      const r2 = await p.request().query(`
        SELECT DISTINCT TOP 1 pbc.ProductBatchID
        FROM ProductBarcodes pbc
        INNER JOIN ProductBatches pb ON pbc.ProductBatchID = pb.ProductBatchID
        WHERE pbc.Barcode = '${safeBarcode}' ${branchFilter}
      `);
      if (r2.recordset.length > 0) batchId = r2.recordset[0].ProductBatchID;
    }

    // 1c) ProductBatches direct columns
    if (!batchId) {
      const r3 = await p.request().query(`
        SELECT TOP 1 pb.ProductBatchID, pb.StdSalesPrice, p.ProductName, p.ItemNameinSecondLanguage
        FROM ProductBatches pb
        INNER JOIN Products p ON pb.ProductID = p.ProductID
        WHERE (pb.MannualBarcode = '${safeBarcode}' OR CAST(pb.AutoBarcode AS NVARCHAR(100)) = '${safeBarcode}'
           OR pb.Unit2Barcode = '${safeBarcode}' OR pb.Unit3Barcode = '${safeBarcode}') ${branchFilter}
      `);
      if (r3.recordset.length > 0) {
        const row = r3.recordset[0];
        batchId = row.ProductBatchID;
        productName = row.ProductName || '';
        productNameAr = row.ItemNameinSecondLanguage || '';
        unitPrice = row.StdSalesPrice || 0;
      }
    }

    if (!batchId) {
      return res.json({ success: false, error: 'Barcode not found in ERP' });
    }

    // If we found batchId from step 1b/1c but don't have unit price/name yet, get it
    if (!unitPrice || !productName || !unitName) {
      const rUnits = await p.request().query(`
        SELECT TOP 1 pu.BarCode, MAX(pu.Sprice) AS Sprice, pu.MultiFactor, u.UnitName,
          p.ProductName, p.ItemNameinSecondLanguage
        FROM ProductUnits pu
        INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID AND pu.BranchID = pb.BranchID
        INNER JOIN Products p ON pb.ProductID = p.ProductID
        LEFT JOIN UnitOfMeasures u ON pu.UnitID = u.UnitID
        WHERE pu.ProductBatchID = ${parseInt(String(batchId))} ${branchFilter} AND pu.MultiFactor = 1
        GROUP BY pu.BarCode, pu.MultiFactor, u.UnitName, p.ProductName, p.ItemNameinSecondLanguage
      `);
      if (rUnits.recordset.length > 0) {
        const row = rUnits.recordset[0];
        if (!productName) productName = row.ProductName || '';
        if (!productNameAr) productNameAr = row.ItemNameinSecondLanguage || '';
        if (!unitPrice) unitPrice = row.Sprice || 0;
        if (!unitName) unitName = row.UnitName || '';
        if (row.BarCode) foundBarcode = row.BarCode;
      }
      
      // If still missing unit name (batch has no ProductUnits), get from Products.BasicUnitID
      if (!unitName) {
        const rBasicUnit = await p.request().query(`
          SELECT TOP 1 u.UnitName, p.ProductName, p.ItemNameinSecondLanguage
          FROM ProductBatches pb
          INNER JOIN Products p ON pb.ProductID = p.ProductID
          LEFT JOIN UnitOfMeasures u ON p.BasicUnitID = u.UnitID
          WHERE pb.ProductBatchID = ${parseInt(String(batchId))} ${branchFilter}
        `);
        if (rBasicUnit.recordset.length > 0) {
          const row = rBasicUnit.recordset[0];
          if (!productName) productName = row.ProductName || '';
          if (!productNameAr) productNameAr = row.ItemNameinSecondLanguage || '';
          if (!unitName) unitName = row.UnitName || '';
        }
      }
    }

    // StdSalesPrice fallback when unit price is still 0
    if (!unitPrice) {
      const rFb = await p.request().query(`SELECT StdSalesPrice FROM ProductBatches WHERE ProductBatchID = ${parseInt(String(batchId))} ${branchFilter.replace('pb.', '')}`);
      if (rFb.recordset.length > 0) unitPrice = rFb.recordset[0].StdSalesPrice || 0;
    }

    // ---------- Step 2: Find active offers (all 3 sources in parallel) ----------
    const bId = parseInt(String(batchId));
    const spBranch = erpBranchId ? `AND sp.BranchID = ${parseInt(String(erpBranchId))}` : '';
    const qdBranch = erpBranchId ? `AND qd.BranchID = ${parseInt(String(erpBranchId))}` : '';
    const gobBranch = erpBranchId ? `AND g.BranchID = ${parseInt(String(erpBranchId))}` : '';

    const [offerR1, offerR2, offerR3] = await Promise.all([
      p.request().query(`
        SELECT TOP 1 sp.SalesPrice, s.SchemeName, s.SchemeType, s.QtyLimit, s.FreeQty, s.DateFrom, s.DateTo
        FROM SpecialPriceScheme sp INNER JOIN Schemes s ON sp.SchemeID = s.SchemeID
        WHERE sp.ProductBatchID = ${bId} ${spBranch} AND s.SchemeStatus = 'Active'
          AND GETDATE() BETWEEN s.DateFrom AND s.DateTo
        ORDER BY sp.SalesPrice ASC
      `),
      p.request().query(`
        SELECT TOP 1 qd.QtyLimit, qd.FreeQty, s.SchemeName, s.SchemeType,
          s.QtyLimit AS SchemeQtyLimit, s.FreeQty AS SchemeFreeQty, s.DateFrom, s.DateTo
        FROM QuantityDiscountScheme qd INNER JOIN Schemes s ON qd.SchemeID = s.SchemeID
        WHERE qd.ProductBatchID = ${bId} ${qdBranch} AND s.SchemeStatus = 'Active'
          AND GETDATE() BETWEEN s.DateFrom AND s.DateTo
      `),
      p.request().query(`
        SELECT TOP 1 g.RangeFrom, g.RangeTo, g.SpecialPrice, g.Quantity
        FROM GiftOnBilling g
        WHERE g.GiftProductBatchID = ${bId} ${gobBranch} AND g.RangeFrom > 0
        ORDER BY g.RangeFrom ASC
      `)
    ]);

    let offer = null;

    if (offerR1.recordset.length > 0) {
      const row = offerR1.recordset[0];
      offer = {
        scheme_name: row.SchemeName || '', scheme_type: row.SchemeType || '',
        scheme_price: row.SalesPrice, qty_limit: row.QtyLimit || 0,
        free_qty: row.FreeQty || 0, date_from: row.DateFrom || '', date_to: row.DateTo || ''
      };
    } else if (offerR2.recordset.length > 0) {
      const row = offerR2.recordset[0];
      offer = {
        scheme_name: row.SchemeName || '', scheme_type: row.SchemeType || '',
        scheme_price: 0, qty_limit: row.SchemeQtyLimit || row.QtyLimit || 0,
        free_qty: row.SchemeFreeQty || row.FreeQty || 0,
        date_from: row.DateFrom || '', date_to: row.DateTo || ''
      };
    } else if (offerR3.recordset.length > 0) {
      const row = offerR3.recordset[0];
      offer = {
        scheme_name: 'Gift on Billing', scheme_type: 'Gift on Billing',
        scheme_price: row.SpecialPrice || 0, qty_limit: row.Quantity || 1,
        free_qty: 0, date_from: '', date_to: '',
        range_from: row.RangeFrom || 0, range_to: row.RangeTo || 0
      };
    }

    res.json({
      success: true, productName, productNameAr,
      prices: [{ barcode: foundBarcode, sprice: unitPrice, multi_factor: multiFactor, unit_name: unitName }],
      offer
    });
  } catch (err) {
    pool = null;
    console.error('Price-check error:', err);
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
