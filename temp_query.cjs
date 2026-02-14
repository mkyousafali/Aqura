const sql = require('mssql');

const config = {
  server: '192.168.0.3',
  database: 'URBAN2_2025',
  user: 'sa',
  password: 'Polosys*123',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

async function main() {
  try {
    const pool = await sql.connect(config);
    
    const barcode = '5285000398608';

    // Get expiry from ProductBatches using ProductBatchID from ProductUnits
    const result = await pool.request().query(`
      SELECT pb.ProductBatchID, pb.ProductID, pb.MannualBarcode, pb.AutoBarcode,
             pb.ExpiryDate, pb.MfgDate, pb.BatchNo, pb.Stock, pb.BranchID,
             pb.StdSalesPrice, pb.MRP,
             pu.BarCode, pu.MultiFactor, pu.UnitID,
             vw.ProductName
      FROM ProductUnits pu
      INNER JOIN ProductBatches pb ON pu.ProductBatchID = pb.ProductBatchID
      LEFT JOIN VW_PRODUCTPRICE1 vw ON vw.Barcode = pu.BarCode
      WHERE pu.BarCode = '${barcode}'
    `);
    console.log('=== Product Expiry Details ===');
    console.log(JSON.stringify(result.recordset, null, 2));
    
    process.exit(0);
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
}

main();
