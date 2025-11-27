import sql from 'mssql';

// Database configuration
const config = {
  server: '192.168.0.3',
  database: 'URBAN2_2025',
  user: 'sa',
  password: 'Polosys*123',
  options: {
    encrypt: false,
    trustServerCertificate: true,
    enableArithAbort: true
  }
};

async function getTodaySales() {
  try {
    console.log('🔌 Connecting to ERP database...\n');
    
    // Connect to database
    await sql.connect(config);
    console.log('✅ Connected to URBAN2_2025 database\n');

    // Get today's date in SQL Server format
    const today = new Date();
    const todayStr = today.toISOString().split('T')[0]; // YYYY-MM-DD format
    
    console.log(`📅 Fetching sales for: ${todayStr}\n`);
    console.log('='.repeat(70));

    // Query 1: Get Sales (SI - Sales Invoice)
    const salesQuery = `
      SELECT 
        COUNT(*) AS TotalBills,
        SUM(GrandTotal) AS GrossSales,
        SUM(VatAmount) AS TotalTax,
        SUM(TotalDiscount) AS TotalDiscount
      FROM InvTransactionMaster
      WHERE CAST(TransactionDate AS DATE) = @date
      AND VoucherType = 'SI'
    `;

    const salesResult = await sql.query`
      SELECT 
        COUNT(*) AS TotalBills,
        SUM(GrandTotal) AS GrossSales,
        SUM(VatAmount) AS TotalTax,
        SUM(TotalDiscount) AS TotalDiscount
      FROM InvTransactionMaster
      WHERE CAST(TransactionDate AS DATE) = ${todayStr}
      AND VoucherType = 'SI'
    `;

    // Query 2: Get Returns (SR - Sales Return)
    const returnsResult = await sql.query`
      SELECT 
        COUNT(*) AS TotalReturns,
        SUM(GrandTotal) AS ReturnAmount,
        SUM(VatAmount) AS ReturnTax
      FROM InvTransactionMaster
      WHERE CAST(TransactionDate AS DATE) = ${todayStr}
      AND VoucherType = 'SR'
    `;

    // Extract results
    const sales = salesResult.recordset[0];
    const returns = returnsResult.recordset[0];

    // Calculate net sales
    const grossSales = sales.GrossSales || 0;
    const returnAmount = returns.ReturnAmount || 0;
    const netSales = grossSales - returnAmount;

    const grossTax = sales.TotalTax || 0;
    const returnTax = returns.ReturnTax || 0;
    const netTax = grossTax - returnTax;

    const totalBills = sales.TotalBills || 0;
    const totalReturns = returns.TotalReturns || 0;
    const netBills = totalBills - totalReturns;

    const totalDiscount = sales.TotalDiscount || 0;

    // Display results
    console.log('\n📊 TODAY\'S SALES SUMMARY');
    console.log('='.repeat(70));
    
    console.log('\n💰 GROSS SALES:');
    console.log(`   Total Bills: ${totalBills}`);
    console.log(`   Gross Amount: ₹${grossSales.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);
    console.log(`   Tax (VAT): ₹${grossTax.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);
    console.log(`   Discount: ₹${totalDiscount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);

    console.log('\n🔄 RETURNS:');
    console.log(`   Total Returns: ${totalReturns}`);
    console.log(`   Return Amount: ₹${returnAmount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);
    console.log(`   Return Tax: ₹${returnTax.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);

    console.log('\n✅ NET SALES:');
    console.log(`   Net Bills: ${netBills}`);
    console.log(`   Net Amount: ₹${netSales.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);
    console.log(`   Net Tax: ₹${netTax.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);

    console.log('\n' + '='.repeat(70));

    // Query 3: Get top selling products today
    console.log('\n🏆 TOP 10 SELLING PRODUCTS TODAY:');
    console.log('='.repeat(70));

    const topProductsResult = await sql.query`
      SELECT TOP 10
        itd.ProductDescription,
        SUM(itd.Quantity) AS TotalQty,
        SUM(itd.NetAmount) AS TotalAmount
      FROM InvTransactionDetails itd
      INNER JOIN InvTransactionMaster itm 
        ON itd.InvTransactionMasterID = itm.InvTransactionMasterID
      WHERE CAST(itm.TransactionDate AS DATE) = ${todayStr}
      AND itm.VoucherType = 'SI'
      GROUP BY itd.ProductDescription
      ORDER BY SUM(itd.Quantity) DESC
    `;

    const topProducts = topProductsResult.recordset;

    if (topProducts.length > 0) {
      console.log('\n');
      topProducts.forEach((product, index) => {
        console.log(`${index + 1}. ${product.ProductDescription}`);
        console.log(`   Qty: ${product.TotalQty} | Amount: ₹${product.TotalAmount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`);
      });
    } else {
      console.log('\n   No sales recorded yet for today.');
    }

    console.log('\n' + '='.repeat(70));

    // Close connection
    await sql.close();
    console.log('\n✅ Connection closed successfully');

  } catch (err) {
    console.error('❌ Error:', err.message);
    if (err.code === 'ESOCKET') {
      console.error('\n💡 Troubleshooting:');
      console.error('   - Check if SQL Server is running on 192.168.0.3');
      console.error('   - Verify network connectivity: ping 192.168.0.3');
      console.error('   - Ensure SQL Server is configured to accept remote connections');
      console.error('   - Check firewall settings');
    }
  }
}

// Run the function
getTodaySales();
