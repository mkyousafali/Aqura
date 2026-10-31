import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { homedir } from 'node:os';
import { resolve } from 'node:path';
const migration = readFileSync('database/migrations/20261031_denomination_closed_requisition_split.sql','utf8')
 .replace(/^begin;\s*/i,'').replace(/commit;\s*$/i,'').replace(/notify pgrst[^;]*;/gi,'')
 .replaceAll('public.','pg_temp.').replaceAll('set search_path = public','set search_path = pg_temp, public');
const sql = readFileSync('database/tests/denomination_closed_requisition_split.sql','utf8').replace('-- INSTALL_MIGRATION_HERE',()=>migration);
console.log(execFileSync('ssh',['-o','BatchMode=yes','-o','ConnectTimeout=10','-o','IdentitiesOnly=yes','-i',resolve(homedir(),'.ssh/id_ed25519_nopass'),'root@8.213.42.21','docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1'],{input:sql,encoding:'utf8',timeout:30000}));
