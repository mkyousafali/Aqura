import type { RequestHandler } from './$types';
import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import { tmpdir, homedir } from 'node:os';
import { join } from 'node:path';
import { writeFileSync, unlinkSync, existsSync, statSync } from 'node:fs';

const execAsync = promisify(exec);

const CLOUD_SSH = 'root@8.213.42.21';
// Use forward slashes for cross-platform compatibility (even on Windows)
const SSH_KEY = join(homedir(), '.ssh', 'id_ed25519_nopass').replace(/\\/g, '/');
const SSH_OPTS = `-i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=15`;

// Tables to exclude DATA for (schema is still synced)
const EXCLUDE_DATA_TABLES = [
	'wa_messages',
	'whatsapp_message_log',
	'user_audit_logs',
	'order_audit_logs',
	'branch_sync_config'
];

export const POST: RequestHandler = async ({ request }) => {
	const body = await request.json();
	const { branchIP, branchSSHUser = 'u' } = body;

	if (!branchIP) {
		return new Response(JSON.stringify({ error: 'branchIP is required' }), {
			status: 400,
			headers: { 'Content-Type': 'application/json' }
		});
	}

	const branchSSH = `${branchSSHUser}@${branchIP}`;
	const ts = Date.now();
	const dumpFile = `aqura_sync_${ts}.sql.gz`;
	const seqFile = `aqura_seq_reset_${ts}.sql`;

	// Paths on each machine
	const cloudDump = `/tmp/${dumpFile}`;
	const localDump = join(tmpdir(), dumpFile);
	const branchDump = `/tmp/${dumpFile}`;
	const localSeqSQL = join(tmpdir(), seqFile);
	const branchSeqSQL = `/tmp/${seqFile}`;

	const encoder = new TextEncoder();

	const stream = new ReadableStream({
		async start(controller) {
			const send = (data: any) => {
				try {
					controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`));
				} catch { /* stream closed */ }
			};

			try {
				// ═══ Step 1: Create pg_dump on cloud server ═══
				send({ step: 1, total: 6, message: '📦 Creating database dump on cloud...' });

				// Build dump script (avoids complex escaping through SSH)
				const excludeFlags = EXCLUDE_DATA_TABLES
					.map(t => `  --exclude-table-data='${t}' \\`)
					.join('\n');

				const dumpScriptContent = [
					'#!/bin/bash',
					'set -eo pipefail',
					'docker exec supabase-db pg_dump \\',
					'  -U supabase_admin -d postgres \\',
					'  -n public \\',
					'  --clean --if-exists \\',
					'  --no-owner --no-privileges \\',
					excludeFlags,
					`  | gzip > ${cloudDump}`,
					`ls -lh ${cloudDump} | awk '{print $5}'`
				].join('\n');

				const dumpScriptLocal = join(tmpdir(), `dump_script_${ts}.sh`);
				writeFileSync(dumpScriptLocal, dumpScriptContent, 'utf8');

				// Upload script to cloud and run it
				await scp(`"${dumpScriptLocal}"`, `${CLOUD_SSH}:/tmp/dump_script_${ts}.sh`);
				const sizeStr = await sshExec(CLOUD_SSH, `bash /tmp/dump_script_${ts}.sh`);
				cleanup(dumpScriptLocal);

				send({ step: 1, total: 6, message: `✅ Dump created (${sizeStr.trim()})` });

				// ═══ Step 2: Download dump from cloud ═══
				send({ step: 2, total: 6, message: '⬇️ Downloading dump from cloud...' });
				await scp(`${CLOUD_SSH}:${cloudDump}`, `"${localDump}"`);
				const localSize = formatBytes(statSync(localDump).size);
				send({ step: 2, total: 6, message: `✅ Downloaded (${localSize})` });

				// ═══ Step 3: Upload dump to branch ═══
				send({ step: 3, total: 6, message: '⬆️ Uploading to branch...' });
				const dumpSize = statSync(localDump).size;
				const dumpSizeStr = formatBytes(dumpSize);
				send({ step: 3, total: 6, message: `⬆️ Uploading ${dumpSizeStr} to branch (this may take a few minutes)...` });
				// Allow up to 1 hour for large dumps to transfer over network
				await scp(`"${localDump}"`, `${branchSSH}:${branchDump}`, 3600000);
				send({ step: 3, total: 6, message: '✅ Uploaded to branch' });

				// ═══ Step 4: Restore database on branch ═══
				send({ step: 4, total: 6, message: '🔄 Restoring database on branch (this may take a while)...' });

				// Build restore script
				const restoreScriptContent = [
					'#!/bin/bash',
					`docker cp ${branchDump} supabase-db:${branchDump}`,
					// Restore: gunzip + pipe into psql. Errors from DROP IF EXISTS are expected.
					`docker exec supabase-db bash -c "gunzip -c ${branchDump} | psql -U supabase_admin -d postgres 2>&1" | tail -20`,
					'echo "___RESTORE_DONE___"'
				].join('\n');

				const restoreScriptLocal = join(tmpdir(), `restore_script_${ts}.sh`);
				writeFileSync(restoreScriptLocal, restoreScriptContent, 'utf8');

				await scp(`"${restoreScriptLocal}"`, `${branchSSH}:/tmp/restore_script_${ts}.sh`);
				const restoreOut = await sshExec(branchSSH, `bash /tmp/restore_script_${ts}.sh`, 600000);
				cleanup(restoreScriptLocal);

				if (!restoreOut.includes('___RESTORE_DONE___')) {
					throw new Error('Restore did not complete: ' + restoreOut.slice(0, 500));
				}

				send({ step: 4, total: 6, message: '✅ Database restored' });

				// ═══ Step 5: Reset sequences + reload PostgREST ═══
				send({ step: 5, total: 6, message: '🔧 Resetting sequences & reloading schema...' });

				// Write sequence reset SQL to file (avoids escaping nightmares)
				const seqSQL = `-- Reset all sequences to max(id) so new inserts get correct IDs
DO $$ DECLARE r record; BEGIN
  FOR r IN (
    SELECT t.relname as tbl, a.attname as col, pg_get_serial_sequence(t.relname, a.attname) as seq
    FROM pg_class t
    JOIN pg_namespace n ON t.relnamespace = n.oid
    JOIN pg_attribute a ON a.attrelid = t.oid
    WHERE n.nspname = 'public' AND t.relkind = 'r'
      AND pg_get_serial_sequence(t.relname, a.attname) IS NOT NULL
  ) LOOP
    EXECUTE format('SELECT setval(%L, COALESCE((SELECT MAX(%I) FROM %I), 1))', r.seq, r.col, r.tbl);
  END LOOP;
END $$;

-- Tell PostgREST to reload the schema cache
NOTIFY pgrst, 'reload schema';
`;
				writeFileSync(localSeqSQL, seqSQL, 'utf8');
				await scp(`"${localSeqSQL}"`, `${branchSSH}:${branchSeqSQL}`);
				await sshExec(branchSSH, `docker cp ${branchSeqSQL} supabase-db:${branchSeqSQL} && docker exec supabase-db psql -U supabase_admin -d postgres -f ${branchSeqSQL}`, 60000);
				cleanup(localSeqSQL);

				// Restart PostgREST to pick up new/changed tables
				await sshExec(branchSSH, 'docker restart supabase-rest', 30000);

				send({ step: 5, total: 6, message: '✅ Sequences reset & PostgREST reloaded' });

				// ═══ Step 6: Cleanup ═══
				send({ step: 6, total: 6, message: '🧹 Cleaning up temp files...' });
				try { await sshExec(CLOUD_SSH, `rm -f ${cloudDump} /tmp/dump_script_${ts}.sh`, 10000); } catch {}
				try { await sshExec(branchSSH, `rm -f ${branchDump} ${branchSeqSQL} /tmp/restore_script_${ts}.sh && docker exec supabase-db rm -f ${branchDump} ${branchSeqSQL}`, 10000); } catch {}
				cleanup(localDump);

				send({ step: 6, total: 6, message: '✅ Sync complete!', done: true, success: true });

			} catch (err: any) {
				console.error('Branch pg_dump sync error:', err);
				send({ error: true, message: `❌ ${err.message}` });

				// Best-effort cleanup
				try { await sshExec(CLOUD_SSH, `rm -f ${cloudDump} /tmp/dump_script_${ts}.sh`, 5000); } catch {}
				try { await sshExec(branchSSH, `rm -f ${branchDump} ${branchSeqSQL} /tmp/restore_script_${ts}.sh`, 5000); } catch {}
				cleanup(localDump);
				cleanup(localSeqSQL);
			} finally {
				controller.close();
			}
		}
	});

	return new Response(stream, {
		headers: {
			'Content-Type': 'text/event-stream',
			'Cache-Control': 'no-cache',
			'Connection': 'keep-alive'
		}
	});
};

/** Run a command on a remote host via SSH */
async function sshExec(host: string, cmd: string, timeout = 300000): Promise<string> {
	const escapedCmd = cmd.replace(/"/g, '\\"').replace(/`/g, '\\`');
	const command = `ssh ${SSH_OPTS} ${host} "${escapedCmd}"`;
	console.log('Executing SSH command on', host, '(command hidden for security)');
	const { stdout } = await execAsync(command, { maxBuffer: 100 * 1024 * 1024, timeout });
	return stdout;
}

/** SCP a file between local and remote */
async function scp(from: string, to: string, timeout = 600000): Promise<void> {
	// Normalize Windows paths to forward slashes for cross-platform compatibility
	const fromNormalized = from.replace(/\\/g, '/');
	const toNormalized = to.replace(/\\/g, '/');
	const cmd = `scp ${SSH_OPTS} "${fromNormalized}" "${toNormalized}"`;
	console.log('Executing SCP command (sanitized):', cmd.replace(SSH_KEY, '***'));
	await execAsync(cmd, { timeout, maxBuffer: 10 * 1024 * 1024 });
}

/** Silently delete a local temp file */
function cleanup(filePath: string): void {
	try { if (existsSync(filePath)) unlinkSync(filePath); } catch {}
}

/** Format bytes to human-readable */
function formatBytes(bytes: number): string {
	if (bytes < 1024) return bytes + ' B';
	if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
	if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
	return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
}
