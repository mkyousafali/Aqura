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

async function checkReportTable() {
  try {
    console.log('Connecting to ERP database...\n');
    const pool = await sql.connect(config);
    
    // Check if there's a privilege card report table or view
    console.log('=== SEARCHING FOR PRIVILEGE CARD REPORT TABLES/VIEWS ===\n');
    
    const tables = await pool.request().query(`
      SELECT 
        TABLE_NAME,
        TABLE_TYPE
      FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_NAME LIKE '%Priv%' 
         OR TABLE_NAME LIKE '%Card%'
         OR TABLE_NAME LIKE '%Report%'
      ORDER BY TABLE_NAME
    `);
    
    console.log('Found tables/views related to privilege cards or reports:\n');
    tables.recordset.forEach(t => {
      console.log(`  - ${t.TABLE_NAME} (${t.TABLE_TYPE})`);
    });
    
    // Based on the image, let's check if we can query similar data
    console.log('\n\n=== GENERATING PRIVILEGE CARD REPORT (Similar to image) ===\n');
    
    const report = await pool.request().query(`
      SELECT TOP 10
        itm.InvTransactionMasterID as BillNo,
        CONVERT(varchar, itm.TransactionDate, 103) as Date,
        itm.GrandTotal as BillAmount,
        pc.CardNumber as CardNumber,
        ISNULL(itm.TotalDiscount, 0) as AddAmt,
        50.00 as Redeem
      FROM InvTransactionMaster itm
      INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
      WHERE itm.PrivCardID IS NOT NULL 
        AND itm.VoucherType = 'SI'
      ORDER BY itm.TransactionDate DESC
    `);
    
    console.log('Privilege Card Report (Last 10 transactions):\n');
    console.log('BillNo\t\tDate\t\tBillAmount\tCardNumber\tAddAmt\t\tRedeem');
    console.log('='.repeat(90));
    
    report.recordset.forEach(r => {
      console.log(`${r.BillNo}\t\t${r.Date}\t${r.BillAmount.toFixed(4)}\t${r.CardNumber}\t\t${r.AddAmt.toFixed(2)}\t\t${r.Redeem.toFixed(2)}`);
    });
    
    // Check specific cards from the image
    console.log('\n\n=== CHECKING SPECIFIC CARDS FROM IMAGE ===\n');
    
    const cardNumbers = ['0559395543', '0533443749', '0501307048', '0555184428'];
    
    for (const cardNum of cardNumbers) {
      const cardData = await pool.request()
        .input('cardNum', sql.VarChar, cardNum)
        .query(`
          SELECT 
            pc.CardNumber,
            pc.CardHolderName,
            pc.CardBalance,
            pc.BranchID,
            COUNT(itm.InvTransactionMasterID) as TransactionCount,
            SUM(itm.GrandTotal) as TotalSpent
          FROM PrivilegeCards pc
          LEFT JOIN InvTransactionMaster itm ON pc.PrivilegeCardsID = itm.PrivCardID
          WHERE pc.CardNumber LIKE '%' + @cardNum + '%'
             OR pc.Mobile LIKE '%' + @cardNum + '%'
          GROUP BY pc.CardNumber, pc.CardHolderName, pc.CardBalance, pc.BranchID
        `);
      
      if (cardData.recordset.length > 0) {
        const card = cardData.recordset[0];
        console.log(`Card: ${card.CardNumber}`);
        console.log(`  Holder: ${card.CardHolderName || '(empty)'}`);
        console.log(`  Balance: ${card.CardBalance} SAR`);
        console.log(`  Transactions: ${card.TransactionCount}`);
        console.log(`  Total Spent: ${card.TotalSpent || 0} SAR`);
        console.log('');
      } else {
        console.log(`Card ${cardNum}: Not found`);
        console.log('');
      }
    }
    
    await pool.close();
    console.log('✅ Connection closed');
    
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

checkReportTable();
