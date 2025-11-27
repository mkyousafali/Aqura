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

async function checkCardBranch4() {
  try {
    console.log('Connecting to ERP database...\n');
    const pool = await sql.connect(config);
    
    // Check all branches first
    console.log('=== CHECKING ALL BRANCHES ===\n');
    const allBranches = await pool.request()
      .input('mobile', sql.VarChar, '966548357066')
      .query(`
        SELECT 
          PrivilegeCardsID,
          CardNumber,
          BranchID,
          CardBalance,
          ModifiedDate
        FROM PrivilegeCards
        WHERE Mobile = @mobile
        ORDER BY BranchID
      `);
    
    console.log('Card 966548357066 exists in these branches:\n');
    allBranches.recordset.forEach(card => {
      console.log(`  Branch ${card.BranchID}: Balance = ${card.CardBalance} SAR (ID: ${card.PrivilegeCardsID})`);
    });
    
    // Now check Branch 4 specifically
    console.log('\n=== BRANCH 4 SPECIFIC ===\n');
    const result = await pool.request()
      .input('mobile', sql.VarChar, '966548357066')
      .input('branchId', sql.Int, 4)
      .query(`
        SELECT 
          PrivilegeCardsID,
          CardNumber,
          CardHolderName,
          Mobile,
          BranchID,
          CardBalance,
          OBalance,
          ModifiedDate
        FROM PrivilegeCards
        WHERE Mobile = @mobile AND BranchID = @branchId
      `);
    
    if (result.recordset.length === 0) {
      console.log('❌ Card not found in Branch 4');
    } else {
      console.log('✅ Card 966548357066 in Branch 4:\n');
      result.recordset.forEach(card => {
        console.log(`  ID: ${card.PrivilegeCardsID}`);
        console.log(`  Card Number: ${card.CardNumber}`);
        console.log(`  Card Holder: ${card.CardHolderName}`);
        console.log(`  Branch ID: ${card.BranchID}`);
        console.log(`  Card Balance: ${card.CardBalance} SAR`);
        console.log(`  Opening Balance: ${card.OBalance} SAR`);
        console.log(`  Last Modified: ${card.ModifiedDate}`);
      });
    }
    
    await pool.close();
    console.log('\n✅ Connection closed');
  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkCardBranch4();
