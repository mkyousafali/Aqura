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

async function checkCard() {
  try {
    console.log('Connecting to ERP database...\n');
    const pool = await sql.connect(config);
    
    const cardNumber = '0505918053';
    
    console.log('=== SEARCHING FOR CARD: ' + cardNumber + ' ===\n');
    
    const result = await pool.request()
      .input('cardNumber', sql.VarChar, cardNumber)
      .query(`
        SELECT *
        FROM PrivilegeCards
        WHERE CardNumber = @cardNumber
           OR CardNumber LIKE '%' + @cardNumber + '%'
           OR Mobile = @cardNumber
           OR Mobile LIKE '%' + @cardNumber + '%'
      `);
    
    if (result.recordset.length === 0) {
      console.log('❌ Card not found');
    } else {
      console.log(`✅ Found ${result.recordset.length} matching card(s):\n`);
      
      result.recordset.forEach((card, idx) => {
        console.log(`Card ${idx + 1}:`);
        console.log(`  ID: ${card.PrivilegeCardsID}`);
        console.log(`  Card Number: ${card.CardNumber}`);
        console.log(`  Card Holder: ${card.CardHolderName || '(empty)'}`);
        console.log(`  Mobile: ${card.Mobile}`);
        console.log(`  Branch ID: ${card.BranchID}`);
        console.log(`  Card Type: ${card.CardType}`);
        console.log(`  Card Balance: ${card.CardBalance} SAR`);
        console.log(`  Opening Balance: ${card.OBalance} SAR`);
        console.log(`  Expiry Date: ${card.ExpiryDate}`);
        console.log(`  Modified Date: ${card.ModifiedDate}`);
        console.log('');
      });
      
      // Check transaction history
      console.log('=== TRANSACTION HISTORY ===\n');
      
      const cardId = result.recordset[0].PrivilegeCardsID;
      
      const transactions = await pool.request()
        .input('cardId', sql.Int, cardId)
        .query(`
          SELECT TOP 10
            TransactionDate,
            VoucherType,
            GrandTotal,
            TotalDiscount,
            BranchID
          FROM InvTransactionMaster
          WHERE PrivCardID = @cardId
          ORDER BY TransactionDate DESC
        `);
      
      if (transactions.recordset.length > 0) {
        console.log(`Found ${transactions.recordset.length} transactions:`);
        transactions.recordset.forEach(trans => {
          console.log(`  - ${trans.TransactionDate}: ${trans.VoucherType}, Total: ${trans.GrandTotal}, Discount: ${trans.TotalDiscount}, Branch: ${trans.BranchID}`);
        });
      } else {
        console.log('No transactions found for this card');
      }
    }
    
    await pool.close();
    console.log('\n✅ Connection closed');
    
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

checkCard();
