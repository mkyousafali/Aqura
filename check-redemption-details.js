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
    
    const cardNumber = '0505918053';
    
    // Get card details first
    const cardResult = await pool.request()
      .input('cardNumber', sql.VarChar, cardNumber)
      .query(`
        SELECT PrivilegeCardsID, CardNumber, CardHolderName, Mobile, BranchID, CardBalance
        FROM PrivilegeCards
        WHERE CardNumber LIKE '%' + @cardNumber + '%'
           OR Mobile LIKE '%' + @cardNumber + '%'
      `);
    
    if (cardResult.recordset.length === 0) {
      console.log('❌ Card not found');
      await pool.close();
      return;
    }
    
    const card = cardResult.recordset[0];
    console.log('=== CARD DETAILS ===\n');
    console.log(`Card Holder: ${card.CardHolderName}`);
    console.log(`Card Number: ${card.CardNumber}`);
    console.log(`Mobile: ${card.Mobile}`);
    console.log(`Current Balance: ${card.CardBalance} SAR`);
    console.log(`Branch: ${card.BranchID}`);
    
    // Get detailed redemption history
    console.log('\n=== DETAILED REDEMPTION HISTORY ===\n');
    
    const redemptions = await pool.request()
      .input('cardId', sql.Int, card.PrivilegeCardsID)
      .query(`
        SELECT 
          itm.InvTransactionMasterID,
          itm.TransactionDate,
          itm.VoucherType,
          itm.GrandTotal,
          itm.TotalDiscount,
          itm.TotalGross,
          itm.VatAmount,
          itm.BranchID,
          pc.CardNumber,
          pc.CardHolderName
        FROM InvTransactionMaster itm
        INNER JOIN PrivilegeCards pc ON itm.PrivCardID = pc.PrivilegeCardsID
        WHERE itm.PrivCardID = @cardId
        ORDER BY itm.TransactionDate DESC, itm.InvTransactionMasterID DESC
      `);
    
    if (redemptions.recordset.length === 0) {
      console.log('No redemptions found for this card');
    } else {
      console.log(`Total Redemptions: ${redemptions.recordset.length}\n`);
      
      let totalSpent = 0;
      
      redemptions.recordset.forEach((trans, idx) => {
        console.log(`${idx + 1}. Transaction ID: ${trans.InvTransactionMasterID}`);
        console.log(`   Date: ${trans.TransactionDate}`);
        console.log(`   Type: ${trans.VoucherType}`);
        console.log(`   Gross Amount: ${trans.TotalGross} SAR`);
        console.log(`   VAT: ${trans.VatAmount} SAR`);
        console.log(`   Discount: ${trans.TotalDiscount} SAR`);
        console.log(`   Grand Total: ${trans.GrandTotal} SAR`);
        console.log(`   Branch: ${trans.BranchID}`);
        console.log('');
        
        totalSpent += parseFloat(trans.GrandTotal || 0);
      });
      
      console.log(`\n=== SUMMARY ===`);
      console.log(`Total Transactions: ${redemptions.recordset.length}`);
      console.log(`Total Amount Spent: ${totalSpent.toFixed(2)} SAR`);
      console.log(`Current Balance: ${card.CardBalance} SAR`);
      
      // Get transaction details for last redemption
      console.log('\n=== LAST REDEMPTION ITEMS ===\n');
      
      const lastTransId = redemptions.recordset[0].InvTransactionMasterID;
      
      const items = await pool.request()
        .input('transId', sql.Int, lastTransId)
        .query(`
          SELECT TOP 10
            ProductDescription,
            Quantity,
            UnitPrice,
            NetAmount,
            TotalDiscount,
            TotalVatAmount
          FROM InvTransactionDetails
          WHERE InvTransactionMasterID = @transId
        `);
      
      if (items.recordset.length > 0) {
        items.recordset.forEach((item, idx) => {
          console.log(`${idx + 1}. ${item.ProductDescription}`);
          console.log(`   Qty: ${item.Quantity}, Price: ${item.UnitPrice} SAR`);
          console.log(`   Subtotal: ${item.NetAmount} SAR, VAT: ${item.TotalVatAmount} SAR`);
          if (item.TotalDiscount > 0) {
            console.log(`   Discount: ${item.TotalDiscount} SAR`);
          }
          console.log('');
        });
      }
    }
    
    await pool.close();
    console.log('✅ Connection closed');
    
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

checkRedemptions();
