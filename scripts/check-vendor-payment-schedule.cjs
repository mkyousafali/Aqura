const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client with service role key
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkVendorPaymentSchedule() {
	console.log('\n🔍 Checking vendor_payment_schedule table structure...\n');

	try {
		// Get table structure using information_schema
		const { data: columns, error: columnsError } = await supabase
			.from('information_schema.columns')
			.select('column_name, data_type, is_nullable, column_default')
			.eq('table_name', 'vendor_payment_schedule')
			.eq('table_schema', 'public')
			.order('ordinal_position');

		if (columnsError) {
			console.error('❌ Error fetching columns:', columnsError);
			
			// Alternative: Get a sample record to see structure
			console.log('\n📝 Fetching sample record instead...\n');
			const { data: sample, error: sampleError } = await supabase
				.from('vendor_payment_schedule')
				.select('*')
				.limit(1)
				.single();

			if (sampleError) {
				console.error('❌ Error fetching sample:', sampleError);
			} else {
				console.log('✅ Sample record structure:');
				const columnNames = Object.keys(sample);
				
				// Look for payment-related columns
				const paymentColumns = columnNames.filter(col => 
					col.includes('paid') || 
					col.includes('payment') || 
					col.includes('status')
				);
				
				console.log('\n📊 Payment-related columns found:');
				paymentColumns.forEach(col => {
					console.log(`   • ${col}: ${typeof sample[col]} = ${sample[col]}`);
				});
				
				console.log('\n📋 All columns in table:');
				columnNames.forEach((col, idx) => {
					console.log(`   ${idx + 1}. ${col}`);
				});
			}
		} else {
			console.log('✅ Table structure (columns):');
			console.log(`Total columns: ${columns?.length || 0}\n`);
			
			if (columns) {
				// Look for payment-related columns
				const paymentColumns = columns.filter(col => 
					col.column_name.includes('paid') || 
					col.column_name.includes('payment') || 
					col.column_name.includes('status')
				);
				
				console.log('📊 Payment-related columns:');
				paymentColumns.forEach(col => {
					console.log(`   • ${col.column_name} (${col.data_type}) - Nullable: ${col.is_nullable}`);
					if (col.column_default) {
						console.log(`     Default: ${col.column_default}`);
					}
				});
				
				console.log('\n📋 All columns:');
				columns.forEach((col, idx) => {
					console.log(`   ${idx + 1}. ${col.column_name} (${col.data_type})`);
				});
			}
		}

		// Get row count
		const { count, error: countError } = await supabase
			.from('vendor_payment_schedule')
			.select('*', { count: 'exact', head: true });

		if (!countError) {
			console.log(`\n📈 Total records: ${count}`);
		}

		// Check for records with both is_paid and payment_status
		const { data: records, error: recordsError } = await supabase
			.from('vendor_payment_schedule')
			.select('id, is_paid, payment_status, paid_date')
			.limit(10);

		if (!recordsError && records) {
			console.log('\n📝 Sample records (first 10):');
			console.log('ID | is_paid | payment_status | paid_date');
			console.log('---|---------|----------------|----------');
			records.forEach(r => {
				console.log(`${r.id.substring(0, 8)} | ${r.is_paid || 'null'} | ${r.payment_status || 'null'} | ${r.paid_date || 'null'}`);
			});
		}

	} catch (error) {
		console.error('❌ Error:', error);
	}
}

checkVendorPaymentSchedule();
