import sql from 'mssql';

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

async function checkRedemptions() {
  try {
    console.log('Connecting to ERP database...\n');
    const pool = await sql.connect(config);
    
    console.log('=== CHECKING REDEMPTION/TRANSACTION TABLES ===\n');
    
    // Check PrivilegeCardTransaction table
    console.log('1. PrivilegeCardTransaction table:');
    const privTrans = await pool.request().query(`
      SELECT COUNT(*) as count FROM PrivilegeCardTransaction
    `);
    console.log(`   Total records: ${privTrans.recordset[0].count}`);
    
    if (privTrans.recordset[0].count > 0) {
      const sample = await pool.request().query(`
        SELECT TOP 3 * FROM PrivilegeCardTransaction 
        ORDER BY PrivilegeCardTransactionID DESC
      `);
      console.log('   Sample records:');
      sample.recordset.forEach((r, idx) => {
        console.log(`\n   Record ${idx + 1}:`);
        Object.keys(r).forEach(key => {
          console.log(`     ${key}: ${r[key]}`);
        });
      });
    }
    
    // Check InvTransCouponDetails
    console.log('\n\n2. InvTransCouponDetails table:');
    const couponTrans = await pool.request().query(`
      SELECT COUNT(*) as count FROM InvTransCouponDetails
    `);
    console.log(`   Total records: ${couponTrans.recordset[0].count}`);
    
    if (couponTrans.recordset[0].count > 0) {
      const sample = await pool.request().query(`
        SELECT TOP 3 * FROM InvTransCouponDetails
      `);
      console.log('   Sample records:');
      sample.recordset.forEach((r, idx) => {
        console.log(`\n   Record ${idx + 1}:`);
        Object.keys(r).forEach(key => {
          console.log(`     ${key}: ${r[key]}`);
        });
      });
    }
    
    // Check InvTransactionMaster with PrivCardID
    console.log('\n\n3. InvTransactionMaster (with PrivCardID):');
    const invMaster = await pool.request().query(`
      SELECT COUNT(*) as count 
      FROM InvTransactionMaster 
      WHERE PrivCardID IS NOT NULL AND PrivCardID > 0
    `);
    console.log(`   Total transactions with privilege cards: ${invMaster.recordset[0].count}`);
    
    if (invMaster.recordset[0].count > 0) {
      const sample = await pool.request().query(`
        SELECT TOP 5 
          InvTransactionMasterID,
          TransactionDate,
          VoucherType,
          PrivCardID,
          GrandTotal,
          TotalDiscount,
          BranchID
        FROM InvTransactionMaster 
        WHERE PrivCardID IS NOT NULL AND PrivCardID > 0
        ORDER BY TransactionDate DESC
      `);
      console.log('\n   Sample transactions:');
      sample.recordset.forEach(r => {
        console.log(`   - ID ${r.InvTransactionMasterID}: Date ${r.TransactionDate}, Card ${r.PrivCardID}, Total ${r.GrandTotal}, Discount ${r.TotalDiscount}, Branch ${r.BranchID}`);
      });
    }
    
    // Check specific card redemption example
    console.log('\n\n4. Example: Card 966548357066 redemptions:');
    const cardRedemptions = await pool.request()
      .input('cardId', sql.Int, 1)
      .query(`
        SELECT TOP 5
          itm.InvTransactionMasterID,
          itm.TransactionDate,
          itm.VoucherType,
          itm.GrandTotal,
          itm.TotalDiscount,
          itm.BranchID,
          pc.CardNumber,
          pc.Mobile,
          pc.CardHolderName
        FROM InvTransactionMaster itm
        INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
        WHERE itm.PrivCardID = @cardId
        ORDER BY itm.TransactionDate DESC
      `);
    
    if (cardRedemptions.recordset.length > 0) {
      cardRedemptions.recordset.forEach(r => {
        console.log(`   - ${r.TransactionDate}: ${r.VoucherType}, Total ${r.GrandTotal}, Branch ${r.BranchID}`);
      });
    } else {
      console.log('   No redemptions found');
    }
    
    await pool.close();
    console.log('\n✅ Connection closed');
    
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

checkRedemptions();
