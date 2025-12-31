import { json } from '@sveltejs/kit';
import sql from 'mssql';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { server_ip, database_name, username, password, date, branch_name } = await request.json();

		if (!server_ip || !database_name || !username || !password || !date) {
			return json({
				success: false,
				error: 'Missing required parameters'
			}, { status: 400 });
		}

		// Configure connection
		const config: sql.config = {
			server: server_ip,
			database: database_name,
			user: username,
			password: password,
			options: {
				encrypt: false,
				trustServerCertificate: true,
				enableArithAbort: true,
				connectTimeout: 15000
			}
		};

		// Connect to database
		const pool = await sql.connect(config);

		// Get Sales (SI - Sales Invoice)
		const salesResult = await pool.request()
			.input('date', sql.Date, date)
			.query(`
				SELECT 
					COUNT(*) AS TotalBills,
					ISNULL(SUM(GrandTotal), 0) AS GrossSales,
					ISNULL(SUM(VatAmount), 0) AS TotalTax,
					ISNULL(SUM(TotalDiscount), 0) AS TotalDiscount
				FROM InvTransactionMaster
				WHERE CAST(TransactionDate AS DATE) = @date
				AND VoucherType = 'SI'
			`);

		// Get Returns (SR - Sales Return)
		const returnsResult = await pool.request()
			.input('date', sql.Date, date)
			.query(`
				SELECT 
					COUNT(*) AS TotalReturns,
					ISNULL(SUM(GrandTotal), 0) AS ReturnAmount,
					ISNULL(SUM(VatAmount), 0) AS ReturnTax
				FROM InvTransactionMaster
				WHERE CAST(TransactionDate AS DATE) = @date
				AND VoucherType = 'SR'
			`);

		// Close connection
		await pool.close();

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

		return json({
			success: true,
			data: {
				branch_name: branch_name || 'N/A',
				date: date,
				gross_sales: grossSales,
				gross_bills: totalBills,
				gross_tax: grossTax,
				returns: returnAmount,
				return_bills: totalReturns,
				return_tax: returnTax,
				net_sales: netSales,
				net_bills: netBills,
				net_tax: netTax,
				discount: totalDiscount
			}
		});

	} catch (error: any) {
		console.error('Get sales error:', error);
		return json({
			success: false,
			error: error.message || 'Failed to fetch sales data'
		}, { status: 500 });
	}
};
