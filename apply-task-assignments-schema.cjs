const { Client } = require('pg');
const fs = require('fs');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function applySchema() {
  try {
    await client.connect();
    console.log('Connected to database');

    // Create task_assignments table
    const createTableSQL = `
      CREATE TABLE IF NOT EXISTS public.task_assignments (
        id uuid NOT NULL DEFAULT gen_random_uuid(),
        task_id uuid NOT NULL,
        assignment_type text NOT NULL,
        assigned_to_user_id text NULL,
        assigned_to_branch_id uuid NULL,
        assigned_by text NOT NULL,
        assigned_by_name text NULL,
        assigned_at timestamp with time zone NULL DEFAULT now(),
        status text NULL DEFAULT 'assigned'::text,
        started_at timestamp with time zone NULL,
        completed_at timestamp with time zone NULL,
        CONSTRAINT task_assignments_pkey PRIMARY KEY (id),
        CONSTRAINT task_assignments_task_id_assignment_type_assigned_to_user_i_key UNIQUE (
          task_id,
          assignment_type,
          assigned_to_user_id,
          assigned_to_branch_id
        ),
        CONSTRAINT task_assignments_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      ) TABLESPACE pg_default;
    `;

    await client.query(createTableSQL);
    console.log('✅ task_assignments table created/updated successfully!');

    // Create indexes
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id ON public.task_assignments USING btree (task_id) TABLESPACE pg_default;',
      'CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_user_id ON public.task_assignments USING btree (assigned_to_user_id) TABLESPACE pg_default;',
      'CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_branch_id ON public.task_assignments USING btree (assigned_to_branch_id) TABLESPACE pg_default;',
      'CREATE INDEX IF NOT EXISTS idx_task_assignments_assignment_type ON public.task_assignments USING btree (assignment_type) TABLESPACE pg_default;',
      'CREATE INDEX IF NOT EXISTS idx_task_assignments_status ON public.task_assignments USING btree (status) TABLESPACE pg_default;',
      'CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_by ON public.task_assignments USING btree (assigned_by) TABLESPACE pg_default;'
    ];

    for (const indexSQL of indexes) {
      await client.query(indexSQL);
    }
    console.log('✅ All indexes created successfully!');

    // Check table structure
    const { rows } = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'task_assignments'
      ORDER BY ordinal_position;
    `);
    
    console.log('\n📋 task_assignments table structure:');
    rows.forEach(row => {
      console.log(`  ${row.column_name}: ${row.data_type}`);
    });

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await client.end();
  }
}

applySchema();