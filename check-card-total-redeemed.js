import sql from 'mssql';

const config = {
  user: 'sa',
  password: 'Polosys*123',
  server: '192.168.0.3',
  database: 'URBAN2_2025',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

async function checkCardRedemptions() {
  try {
    const pool = await sql.connect(config);
    
    const cardNumber = '0559395543';
    
    // First, find the card details
    console.log(`=== PRIVILEGE CARD: ${cardNumber} ===\n`);
    const cardInfo = await pool.request()
      .input('cardNumber', sql.VarChar, `%${cardNumber}%`)
      .query(`
        SELECT 
          PrivilegeCardsID,
          CardNumber,
          Mobile,
          CardBalance,
          BranchID
        FROM PrivilegeCards
        WHERE CardNumber LIKE @cardNumber OR Mobile LIKE @cardNumber
      `);
    
    if (cardInfo.recordset.length === 0) {
      console.log('❌ Card not found!');
      await pool.close();
      return;
    }
    
    console.log('Card Details:');
    cardInfo.recordset.forEach(card => {
      console.log(`  Card ID: ${card.PrivilegeCardsID}`);
      console.log(`  Card Number: ${card.CardNumber}`);
      console.log(`  Mobile: ${card.Mobile}`);
      console.log(`  Current Balance: ${card.CardBalance} SAR`);
      console.log(`  Branch: ${card.BranchID}`);
      console.log('');
    });
    
    // Get all card IDs for this card number
    const cardIds = cardInfo.recordset.map(c => c.PrivilegeCardsID);
    
    // Calculate total redemptions
    console.log('\n=== TOTAL REDEMPTIONS ===\n');
    const redemptionStats = await pool.request().query(`
      SELECT 
        COUNT(*) as TotalTransactions,
        SUM(PrivRedeem) as TotalRedeemed,
        SUM(PrivAddAmount) as TotalEarned,
        MIN(TransactionDate) as FirstRedemption,
        MAX(TransactionDate) as LastRedemption
      FROM InvTransactionMaster
      WHERE PrivCardID IN (${cardIds.join(',')})
        AND PrivRedeem IS NOT NULL
        AND PrivRedeem > 0
    `);
    
    const stats = redemptionStats.recordset[0];
    console.log(`Total Transactions with Redemptions: ${stats.TotalTransactions}`);
    console.log(`Total Amount Redeemed: ${stats.TotalRedeemed || 0} SAR`);
    console.log(`Total Amount Earned Back: ${stats.TotalEarned || 0} SAR`);
    console.log(`First Redemption: ${stats.FirstRedemption ? new Date(stats.FirstRedemption).toLocaleDateString() : 'N/A'}`);
    console.log(`Last Redemption: ${stats.LastRedemption ? new Date(stats.LastRedemption).toLocaleDateString() : 'N/A'}`);
    
    // Show recent redemptions
    console.log('\n\n=== RECENT REDEMPTIONS (Last 10) ===\n');
    const recentRedemptions = await pool.request().query(`
      SELECT TOP 10
        InvTransactionMasterID,
        TransactionDate,
        VoucherNumber,
        GrandTotal,
        PrivRedeem,
        PrivAddAmount,
        BranchID
      FROM InvTransactionMaster
      WHERE PrivCardID IN (${cardIds.join(',')})
        AND PrivRedeem IS NOT NULL
        AND PrivRedeem > 0
      ORDER BY TransactionDate DESC
    `);
    
    if (recentRedemptions.recordset.length > 0) {
      recentRedemptions.recordset.forEach((txn, idx) => {
        console.log(`${idx + 1}. Bill #${txn.VoucherNumber} - ${new Date(txn.TransactionDate).toLocaleDateString()}`);
        console.log(`   Bill Total: ${txn.GrandTotal} SAR`);
        console.log(`   Redeemed: ${txn.PrivRedeem} SAR`);
        console.log(`   Earned: ${txn.PrivAddAmount} SAR`);
        console.log(`   Branch: ${txn.BranchID}`);
        console.log('');
      });
    } else {
      console.log('No redemption history found.');
    }
    
    await pool.close();
  } catch (err) {
    console.error('Error:', err.message);
  }
}

checkCardRedemptions();
