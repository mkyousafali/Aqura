import pg from 'pg';
import fs from 'fs';

const { Client } = pg;

const client = new Client({
  host: 'aws-0-eu-central-1.pooler.supabase.com',
  port: 5432,
  database: 'postgres',
  user: 'postgres.vmypotfsyrvuublyddyt',
  password: 'dNxV0FfW3FyWn8zQ',
  ssl: { rejectUnauthorized: false }
});

async function deployFunction() {
  try {
    await client.connect();
    console.log('✅ Connected to database');
    
    const sql = fs.readFileSync('./supabase/migrations/process_clearance_certificate_generation.sql', 'utf8');
    
    console.log('📤 Deploying function...');
    await client.query(sql);
    
    console.log('✅ Function deployed successfully!');
    
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

deployFunction();
