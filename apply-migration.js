import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Supabase configuration
const supabaseUrl = 'https://xgzsdagdqsqjtlgrksml.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhnenNkYWdkcXNxanRsZ3Jrc21sIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyODI5NTQxNywiZXhwIjoyMDQzODcxNDE3fQ.UhEUL6-WYMIXlhxUDzUjEW-QWYh4JA4JJcjkp6GdVpc';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function applyMigration() {
    try {
        console.log('Reading migration file...');
        const migrationPath = path.join(__dirname, 'supabase', 'migrations', '73_receiving_tasks_system.sql');
        const migrationSql = fs.readFileSync(migrationPath, 'utf8');
        
        console.log('Applying migration...');
        const { data, error } = await supabase.rpc('exec_sql', {
            sql: migrationSql
        });
        
        if (error) {
            console.error('Error applying migration:', error);
        } else {
            console.log('Migration applied successfully!');
        }
    } catch (err) {
        console.error('Error:', err);
    }
}

applyMigration();