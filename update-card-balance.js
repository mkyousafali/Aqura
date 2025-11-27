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

async function updateCardBalance() {
  try {
    console.log('Connecting to ERP database...\n');
    const pool = await sql.connect(config);
    
    const cardNumber = '966548357066';
    const newBalance = -249.4185;
    
    // First, get current card details
    console.log('=== FETCHING CURRENT CARD DATA ===\n');
    const currentData = await pool.request()
      .input('cardNumber', sql.VarChar, cardNumber)
      .query(`
        SELECT PrivilegeCardsID, CardNumber, Mobile, CardHolderName, CardBalance
        FROM PrivilegeCards
        WHERE Mobile = @cardNumber
      `);
    
    if (currentData.recordset.length === 0) {
      console.log('❌ Card not found');
      await pool.close();
      return;
    }
    
    const card = currentData.recordset[0];
    console.log(`Card ID: ${card.PrivilegeCardsID}`);
    console.log(`Card Number: ${card.CardNumber}`);
    console.log(`Card Holder: ${card.CardHolderName}`);
    console.log(`Current Balance: ${card.CardBalance} SAR`);
    console.log(`New Balance: ${newBalance} SAR\n`);
    
    // Update the balance
    console.log('=== UPDATING CARD BALANCE ===\n');
    const result = await pool.request()
      .input('newBalance', sql.Decimal(18, 4), newBalance)
      .input('cardId', sql.Int, card.PrivilegeCardsID)
      .query(`
        UPDATE PrivilegeCards
        SET CardBalance = @newBalance,
            ModifiedDate = GETDATE()
        WHERE PrivilegeCardsID = @cardId
      `);
    
    console.log(`✅ Updated ${result.rowsAffected[0]} record(s)`);
    
    // Verify the update
    console.log('\n=== VERIFYING UPDATE ===\n');
    const verify = await pool.request()
      .input('cardId', sql.Int, card.PrivilegeCardsID)
      .query(`
        SELECT CardBalance, ModifiedDate
        FROM PrivilegeCards
        WHERE PrivilegeCardsID = @cardId
      `);
    
    console.log(`New Balance: ${verify.recordset[0].CardBalance} SAR`);
    console.log(`Modified Date: ${verify.recordset[0].ModifiedDate}`);
    
    await pool.close();
    console.log('\n✅ Connection closed successfully');
    
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

updateCardBalance();
