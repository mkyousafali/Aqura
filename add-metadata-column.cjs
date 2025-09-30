const { Client } = require('pg');

// Database connection string
const connectionString = 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres';

async function addMetadataColumn() {
    const client = new Client({ connectionString });
    
    try {
        await client.connect();
        console.log('Connected to database successfully!');

        // Add metadata column to notifications table
        console.log('Adding metadata column to notifications table...');
        
        const addColumnQuery = `
            ALTER TABLE notifications 
            ADD COLUMN IF NOT EXISTS metadata JSONB;
        `;
        
        await client.query(addColumnQuery);
        console.log('✅ Successfully added metadata column to notifications table!');

        // Verify the column was added
        console.log('Verifying the column was added...');
        const verifyQuery = `
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'notifications' AND column_name = 'metadata';
        `;
        
        const result = await client.query(verifyQuery);
        
        if (result.rows.length > 0) {
            console.log('✅ Metadata column verified:');
            console.table(result.rows);
        } else {
            console.log('❌ Metadata column not found after addition');
        }

        // Show updated table structure
        console.log('\nUpdated notifications table structure:');
        const structureQuery = `
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'notifications' 
            ORDER BY ordinal_position;
        `;
        
        const structureResult = await client.query(structureQuery);
        console.table(structureResult.rows);

    } catch (error) {
        console.error('❌ Error adding metadata column:', error.message);
        throw error;
    } finally {
        await client.end();
        console.log('Database connection closed.');
    }
}

// Run the migration
addMetadataColumn()
    .then(() => {
        console.log('🎉 Metadata column migration completed successfully!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('💥 Migration failed:', error.message);
        process.exit(1);
    });