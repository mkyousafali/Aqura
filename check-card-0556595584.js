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
    
    const cardNumber = '0556595584';
    
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
      console.log('\nSearching for similar numbers...\n');
      
      const similar = await pool.request()
        .query(`
          SELECT TOP 5 CardNumber, Mobile, CardHolderName, BranchID, CardBalance
          FROM PrivilegeCards
          WHERE CardNumber LIKE '%556595584%'
             OR Mobile LIKE '%556595584%'
        `);
      
      if (similar.recordset.length > 0) {
        console.log('Found similar cards:');
        similar.recordset.forEach(card => {
          console.log(`  - Card: ${card.CardNumber}, Mobile: ${card.Mobile}, Name: ${card.CardHolderName}, Balance: ${card.CardBalance}`);
        });
      } else {
        console.log('No similar cards found');
      }
    } else {
      console.log(`✅ Found ${result.recordset.length} matching card(s):\n`);
      
      result.recordset.forEach((card, idx) => {
        console.log(`Card ${idx + 1}:`);
        console.log(`  ID: ${card.PrivilegeCardsID}`);
        console.log(`  Card Number: ${card.CardNumber}`);
        console.log(`  Card Holder: ${card.CardHolderName || '(empty)'}`);
        console.log(`  Mobile: ${card.Mobile}`);
        console.log(`  Email: ${card.email || '(empty)'}`);
        console.log(`  Branch ID: ${card.BranchID}`);
        console.log(`  Card Type: ${card.CardType}`);
        console.log(`  Card Balance: ${card.CardBalance}`);
        console.log(`  Opening Balance: ${card.OBalance}`);
        console.log(`  Price Category: ${card.PriceCategoryID}`);
        console.log(`  Activated Date: ${card.ActivatedDate}`);
        console.log(`  Expiry Date: ${card.ExpiryDate}`);
        console.log(`  Created Date: ${card.CreatedDate}`);
        console.log(`  Modified Date: ${card.ModifiedDate}`);
        console.log(`  DOB: ${card.DOB}`);
        console.log('');
      });
      
      // Check transaction history if card exists
      console.log('=== CHECKING TRANSACTION HISTORY ===\n');
      
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
