import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { homedir } from 'node:os';
import { resolve } from 'node:path';
const migration = name => readFileSync(resolve('database/migrations', name), 'utf8')
  .replace(/^begin;\s*/i, '').replace(/commit;\s*$/i, '')
  .replace(/notify pgrst[^;]*;/gi, '').replaceAll('public.', 'pg_temp.')
  .replaceAll('set search_path = public', 'set search_path = pg_temp, public');
let sql = readFileSync('database/tests/assistant_completed_payments_mark_paid.sql', 'utf8');
const setup = `
create temp table users (id uuid primary key, status text, is_master_admin boolean);
alter table pg_temp.assistant_workflow_tasks add column result jsonb;
create function pg_temp.aqura_current_user_id() returns uuid language sql stable as $$
 select nullif(current_setting('test.actor', true), '')::uuid;
$$;
`;
sql = sql.replace('-- INSTALL_MIGRATION_HERE', () => setup + migration('20261019_assistant_completed_payments_mark_paid.sql') + migration('20261031_master_complete_assistant_task.sql'));
sql = sql.replace("select 'PASS: '", () => readFileSync('database/tests/master_complete_assistant_task.sql', 'utf8') + "\nselect 'PASS: '");
const output = execFileSync('ssh', ['-o','BatchMode=yes','-o','ConnectTimeout=10','-o','IdentitiesOnly=yes','-i',resolve(homedir(),'.ssh/id_ed25519_nopass'),'root@8.213.42.21','docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1'], { input: sql, encoding:'utf8', timeout:60000 });
console.log(output);
