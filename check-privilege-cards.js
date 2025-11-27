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

async function checkPrivilegeCards() {
  try {
    console.log('Connecting to ERP database...\n');
    const pool = await sql.connect(config);
    
    // Get table structure
    console.log('=== PRIVILEGE CARDS TABLE STRUCTURE ===\n');
    const structure = await pool.request().query(`
      SELECT 
        COLUMN_NAME,
        DATA_TYPE,
        CHARACTER_MAXIMUM_LENGTH,
        IS_NULLABLE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = 'PrivilegeCards'
      ORDER BY ORDINAL_POSITION
    `);
    
    console.log('Columns:');
    structure.recordset.forEach(col => {
      const length = col.CHARACTER_MAXIMUM_LENGTH ? `(${col.CHARACTER_MAXIMUM_LENGTH})` : '';
      const nullable = col.IS_NULLABLE === 'YES' ? 'NULL' : 'NOT NULL';
      console.log(`  - ${col.COLUMN_NAME}: ${col.DATA_TYPE}${length} ${nullable}`);
    });
    
    // Get sample data
    console.log('\n=== SAMPLE DATA (First 5 Cards) ===\n');
    const sample = await pool.request().query(`
      SELECT TOP 5 *
      FROM PrivilegeCards
      ORDER BY PrivilegeCardsID DESC
    `);
    
    if (sample.recordset.length > 0) {
      sample.recordset.forEach((card, idx) => {
        console.log(`Card ${idx + 1}:`);
        Object.keys(card).forEach(key => {
          console.log(`  ${key}: ${card[key]}`);
        });
        console.log('');
      });
    }
    
    // Get count and statistics
    console.log('=== STATISTICS ===\n');
    const stats = await pool.request().query(`
      SELECT 
        COUNT(*) as TotalCards,
        MIN(CardNumber) as MinCardNo,
        MAX(CardNumber) as MaxCardNo,
        COUNT(DISTINCT BranchID) as TotalBranches,
        COUNT(DISTINCT CardType) as CardTypes
      FROM PrivilegeCards
    `);
    
    console.log(`Total Cards: ${stats.recordset[0].TotalCards}`);
    console.log(`Card Number Range: ${stats.recordset[0].MinCardNo} - ${stats.recordset[0].MaxCardNo}`);
    console.log(`Total Branches: ${stats.recordset[0].TotalBranches}`);
    console.log(`Card Types: ${stats.recordset[0].CardTypes}`);
    
    // Check card types
    console.log('\n=== CARD TYPES BREAKDOWN ===\n');
    const cardTypes = await pool.request().query(`
      SELECT 
        CardType,
        COUNT(*) as Count
      FROM PrivilegeCards
      GROUP BY CardType
    `);
    
    cardTypes.recordset.forEach(type => {
      console.log(`${type.CardType}: ${type.Count} cards`);
    });
    
    // Check cards with balances
    console.log('\n=== CARDS WITH BALANCE ===\n');
    const withBalance = await pool.request().query(`
      SELECT 
        COUNT(*) as CardsWithBalance,
        SUM(CardBalance) as TotalBalance,
        AVG(CardBalance) as AvgBalance,
        MAX(CardBalance) as MaxBalance
      FROM PrivilegeCards
      WHERE CardBalance > 0
    `);
    
    console.log(`Cards with Balance: ${withBalance.recordset[0].CardsWithBalance}`);
    console.log(`Total Balance: ${withBalance.recordset[0].TotalBalance}`);
    console.log(`Average Balance: ${withBalance.recordset[0].AvgBalance}`);
    console.log(`Max Balance: ${withBalance.recordset[0].MaxBalance}`);
    
    await pool.close();
    console.log('\n✅ Connection closed successfully');
    
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

checkPrivilegeCards();
