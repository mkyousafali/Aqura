import { json } from '@sveltejs/kit';
import sql from 'mssql';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { server_ip, database_name, username, password } = await request.json();

		if (!server_ip || !database_name || !username || !password) {
			return json({
				success: false,
				error: 'Missing required connection parameters'
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
				connectTimeout: 10000 // 10 seconds timeout
			}
		};

		// Try to connect
		const pool = await sql.connect(config);
		
		// Test with a simple query
		const result = await pool.request().query('SELECT @@VERSION AS version');
		
		// Close connection
		await pool.close();

		return json({
			success: true,
			message: 'Connection successful',
			version: result.recordset[0].version
		});

	} catch (error: any) {
		console.error('Connection test error:', error);
		return json({
			success: false,
			error: error.message || 'Connection failed'
		}, { status: 500 });
	}
};
