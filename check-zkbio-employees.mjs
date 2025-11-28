import sql from 'mssql';

const config = {
  user: 'sa',
  password: 'Polosys*123',
  server: '192.168.0.3',
  database: 'Zkurbard',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

try {
  console.log('🔍 Checking ZKBioTime employee tables...\n');
  
  await sql.connect(config);
  
  // Check what employee tables exist
  const tablesResult = await sql.query`
    SELECT TABLE_NAME 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_NAME LIKE '%emp%' OR TABLE_NAME LIKE '%person%'
    ORDER BY TABLE_NAME
  `;
  
  console.log('📊 Employee-related tables:');
  tablesResult.recordset.forEach(t => console.log(`   - ${t.TABLE_NAME}`));
  
  // Check personnel_employee table (common in ZKBioTime)
  console.log('\n🔍 Checking personnel_employee table...');
  const empResult = await sql.query`
    SELECT TOP 5 * FROM personnel_employee
  `;
  
  if (empResult.recordset.length > 0) {
    console.log('\n📋 Columns in personnel_employee:');
    console.log(Object.keys(empResult.recordset[0]).join(', '));
    
    console.log('\n👤 Sample employees:');
    empResult.recordset.forEach((emp, i) => {
      console.log(`\n   ${i+1}. Employee Code: ${emp.emp_code}`);
      console.log(`      First Name: ${emp.first_name || 'N/A'}`);
      console.log(`      Last Name: ${emp.last_name || 'N/A'}`);
      console.log(`      Department: ${emp.department_id || 'N/A'}`);
    });
  }
  
  await sql.close();
  console.log('\n✅ Check complete!');
  
} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
