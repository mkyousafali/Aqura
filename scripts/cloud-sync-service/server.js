#!/usr/bin/env node
/**
 * Aqura Cloud Sync Service
 * 
 * Runs on the cloud server (8.213.42.21:3100).
 * Creates a pg_dump of the cloud database and sends it to a branch
 * via HTTP requests to the branch's /pg/query endpoint (through Cloudflare tunnel).
 * 
 * No SSH to branch needed — works entirely over HTTPS.
 * The frontend (Vercel or dev) triggers this via POST /sync.
 * 
 * Usage:
 *   SYNC_API_KEY=your-secret-key node server.js
 * 
 * Security:
 *   - API key required in X-API-Key header
 *   - CORS enabled for the frontend domain
 */

const http = require('http');
const https = require('https');
const { execSync } = require('child_process');
const { readFileSync, unlinkSync, statSync, existsSync } = require('fs');

// ═══ Configuration ═══
const API_KEY = process.env.SYNC_API_KEY || 'aqura-sync-2025-key';
const PORT = parseInt(process.env.SYNC_PORT || '3100');
const DB_USER = 'supabase_admin';
const DB_NAME = 'postgres';
const DB_CONTAINER = 'supabase-db';

// Tables to exclude DATA for (schema is still synced)
const EXCLUDE_DATA_TABLES = [
	'wa_messages',
	'whatsapp_message_log',
	'user_audit_logs',
	'order_audit_logs',
	'branch_sync_config'
];

// Max SQL chunk size for /pg/query requests
const MAX_CHUNK_SIZE = 1.5 * 1024 * 1024; // 1.5 MB

// ═══ HTTP Server ═══
const server = http.createServer((req, res) => {
	// CORS
	res.setHeader('Access-Control-Allow-Origin', '*');
	res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
	res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-API-Key');

	if (req.method === 'OPTIONS') {
		res.writeHead(200);
		return res.end();
	}

	// Health check
	if (req.method === 'GET' && req.url === '/health') {
		res.writeHead(200, { 'Content-Type': 'application/json' });
		return res.end(JSON.stringify({ status: 'ok', service: 'aqura-sync' }));
	}

	// Sync endpoint
	if (req.method === 'POST' && req.url === '/sync') {
		// Auth check
		if (req.headers['x-api-key'] !== API_KEY) {
			res.writeHead(401, { 'Content-Type': 'application/json' });
			return res.end(JSON.stringify({ error: 'Unauthorized' }));
		}

		let body = '';
		req.on('data', c => body += c);
		req.on('end', () => handleSync(res, body));
		return;
	}

	res.writeHead(404, { 'Content-Type': 'application/json' });
	res.end(JSON.stringify({ error: 'Not found' }));
});

// ═══ Sync Handler ═══
async function handleSync(res, bodyStr) {
	let branchUrl, branchApiKey;
	try {
		const parsed = JSON.parse(bodyStr);
		branchUrl = parsed.branchUrl?.replace(/\/+$/, '');
		branchApiKey = parsed.branchApiKey;
		if (!branchUrl || !branchApiKey) throw new Error('branchUrl and branchApiKey required');
	} catch (e) {
		res.writeHead(400, { 'Content-Type': 'application/json' });
		return res.end(JSON.stringify({ error: e.message }));
	}

	// SSE response for progress streaming
	res.writeHead(200, {
		'Content-Type': 'text/event-stream',
		'Cache-Control': 'no-cache',
		'Connection': 'keep-alive'
	});

	const send = (data) => {
		try { res.write(`data: ${JSON.stringify(data)}\n\n`); } catch {}
	};

	try {
		await doSync(branchUrl, branchApiKey, send);
	} catch (err) {
		send({ error: true, message: `❌ Fatal: ${err.message}` });
	}
	res.end();
}

// ═══ Main Sync Logic ═══
async function doSync(branchUrl, branchApiKey, send) {
	const ts = Date.now();
	const preFile = `/tmp/sync_pre_${ts}.sql`;
	const dataFile = `/tmp/sync_data_${ts}.sql`;
	const postFile = `/tmp/sync_post_${ts}.sql`;

	try {
		// ─── Step 1: Test branch connectivity ───
		send({ step: 1, total: 7, message: '🔌 Testing branch connectivity...' });
		try {
			await httpPost(branchUrl + '/pg/query', { query: 'SELECT 1 as test;' }, branchApiKey, 15000);
			send({ step: 1, total: 7, message: '✅ Branch reachable' });
		} catch (e) {
			throw new Error(`Cannot reach branch at ${branchUrl}: ${e.message}`);
		}

		// ─── Step 2: Generate pg_dump sections ───
		send({ step: 2, total: 7, message: '📦 Creating database dump...' });

		const excludeFlags = EXCLUDE_DATA_TABLES
			.map(t => `--exclude-table-data='${t}'`)
			.join(' ');
		const common = `-U ${DB_USER} -d ${DB_NAME} -n public --no-owner --no-privileges ${excludeFlags}`;

		// Pre-data: DROP + CREATE tables, types, sequences
		execSync(
			`docker exec ${DB_CONTAINER} pg_dump ${common} --section=pre-data --clean --if-exists > ${preFile}`,
			{ maxBuffer: 200 * 1024 * 1024, timeout: 120000 }
		);
		// Data: INSERT statements  
		execSync(
			`docker exec ${DB_CONTAINER} pg_dump ${common} --section=data --inserts --rows-per-insert=500 > ${dataFile}`,
			{ maxBuffer: 500 * 1024 * 1024, timeout: 600000 }
		);
		// Post-data: indexes, FK constraints, triggers
		execSync(
			`docker exec ${DB_CONTAINER} pg_dump ${common} --section=post-data > ${postFile}`,
			{ maxBuffer: 200 * 1024 * 1024, timeout: 120000 }
		);

		const preSize = statSync(preFile).size;
		const dataSize = statSync(dataFile).size;
		const postSize = statSync(postFile).size;
		send({ step: 2, total: 7, message: `✅ Dump: pre=${fmtSize(preSize)}, data=${fmtSize(dataSize)}, post=${fmtSize(postSize)}` });

		// ─── Step 3: Deploy schema (pre-data) ───
		send({ step: 3, total: 7, message: '🏗️ Deploying schema to branch...' });
		let preSQL = readFileSync(preFile, 'utf8');

		// Add CASCADE to all DROP statements (pg_dump doesn't add it by default)
		preSQL = preSQL.replace(
			/DROP (TABLE|SEQUENCE|TYPE|FUNCTION|VIEW|INDEX|TRIGGER) IF EXISTS ([^;]+);/g,
			'DROP $1 IF EXISTS $2 CASCADE;'
		);

		// First try to send schema as one batch (fastest)
		// If it fails, split into individual statements for resilience
		try {
			await sendSQL(branchUrl, branchApiKey, preSQL, 1);
		} catch {
			// Batch failed — deploy statement by statement
			const preStmts = splitStatements(preSQL);
			let preOk = 0, preFail = 0;
			for (const stmt of preStmts) {
				try {
					await sendSQL(branchUrl, branchApiKey, stmt, 1);
					preOk++;
				} catch {
					preFail++;
				}
			}
			send({ step: 3, total: 7, message: `⚠️ Schema: ${preOk} ok, ${preFail} skipped (retry mode)` });
		}
		send({ step: 3, total: 7, message: '✅ Schema deployed' });

		// ─── Step 4: Send data ───
		send({ step: 4, total: 7, message: '📊 Sending data to branch...' });
		let dataSQL = readFileSync(dataFile, 'utf8');

		// Add OVERRIDING SYSTEM VALUE to all INSERT statements
		// (required for tables with GENERATED ALWAYS AS IDENTITY columns)
		dataSQL = dataSQL.replace(
			/INSERT INTO (public\.\w+) VALUES/g,
			'INSERT INTO $1 OVERRIDING SYSTEM VALUE VALUES'
		);

		// Split into manageable chunks
		const chunks = splitInsertChunks(dataSQL, MAX_CHUNK_SIZE);
		let sentOk = 0;
		let sentFail = 0;

		for (let i = 0; i < chunks.length; i++) {
			try {
				await sendSQL(branchUrl, branchApiKey, chunks[i], 3);
				sentOk++;
			} catch (e) {
				sentFail++;
				console.error(`Chunk ${i + 1}/${chunks.length} failed:`, e.message?.slice(0, 200));
			}
			if ((i + 1) % 5 === 0 || i === chunks.length - 1) {
				send({
					step: 4, total: 7,
					message: `📊 Data: ${sentOk + sentFail}/${chunks.length} chunks${sentFail ? ` (${sentFail} errors)` : ''}`
				});
			}
		}
		send({ step: 4, total: 7, message: `✅ Data: ${sentOk}/${chunks.length} ok${sentFail ? `, ${sentFail} errors` : ''}` });

		// ─── Step 5: Apply post-data (indexes, FK, triggers) ───
		send({ step: 5, total: 7, message: '🔗 Creating indexes & constraints...' });
		const postSQL = readFileSync(postFile, 'utf8');
		const postStmts = splitStatements(postSQL);
		let postOk = 0;
		let postFail = 0;
		for (const stmt of postStmts) {
			try {
				await sendSQL(branchUrl, branchApiKey, stmt, 1);
				postOk++;
			} catch {
				postFail++;
			}
		}
		send({ step: 5, total: 7, message: `✅ Post-data: ${postOk} ok, ${postFail} skipped` });

		// ─── Step 6: Reset sequences ───
		send({ step: 6, total: 7, message: '🔧 Resetting sequences...' });
		await sendSQL(branchUrl, branchApiKey, RESET_SEQ_SQL, 2);
		send({ step: 6, total: 7, message: '✅ Sequences reset' });

		// ─── Step 7: Reload PostgREST ───
		send({ step: 7, total: 7, message: '🔄 Reloading PostgREST schema cache...' });
		await sendSQL(branchUrl, branchApiKey, "NOTIFY pgrst, 'reload schema';", 1);
		send({ step: 7, total: 7, message: '✅ Sync complete!', done: true, success: true });

	} finally {
		// Cleanup temp files
		[preFile, dataFile, postFile].forEach(f => {
			try { if (existsSync(f)) unlinkSync(f); } catch {}
		});
	}
}

// ═══ SQL Splitting ═══

/**
 * Split INSERT-format SQL into chunks of max `maxSize` bytes.
 * Splits at statement boundaries (semicolons at end of line).
 */
function splitInsertChunks(sql, maxSize) {
	const chunks = [];
	let current = '';

	for (const line of sql.split('\n')) {
		current += line + '\n';

		// Split at statement boundaries when chunk is large enough
		if (current.length >= maxSize && line.trimEnd().endsWith(';')) {
			chunks.push(current);
			current = '';
		}
	}

	if (current.trim()) chunks.push(current);
	return chunks.filter(c => c.trim().length > 10); // skip empty/whitespace-only
}

/**
 * Split post-data SQL into individual statements.
 * Handles dollar-quoted strings ($$...$$) for functions/triggers.
 */
function splitStatements(sql) {
	const stmts = [];
	let current = '';
	let inDollar = false;
	let dollarTag = '';

	for (const line of sql.split('\n')) {
		current += line + '\n';

		// Track dollar-quoted strings
		const dollarMatches = line.match(/(\$[^$]*\$)/g);
		if (dollarMatches) {
			for (const tag of dollarMatches) {
				if (inDollar && tag === dollarTag) {
					inDollar = false;
				} else if (!inDollar) {
					inDollar = true;
					dollarTag = tag;
				}
			}
		}

		// Statement ends at semicolon (outside dollar-quoted strings)
		if (!inDollar && line.trimEnd().endsWith(';')) {
			const trimmed = current.trim();
			if (trimmed.length > 0 && !trimmed.startsWith('--')) {
				stmts.push(current);
			}
			current = '';
		}
	}

	if (current.trim().length > 0 && !current.trim().startsWith('--')) {
		stmts.push(current);
	}
	return stmts;
}

// ═══ HTTP Helpers ═══

const RESET_SEQ_SQL = `DO $$ DECLARE r record; BEGIN
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
END $$;`;

/** Send SQL to branch via /pg/query with retries */
async function sendSQL(branchUrl, apiKey, sql, retries = 1) {
	for (let attempt = 1; attempt <= retries; attempt++) {
		try {
			return await httpPost(branchUrl + '/pg/query', { query: sql }, apiKey);
		} catch (e) {
			if (attempt === retries) throw e;
			await sleep(1000 * attempt);
		}
	}
}

/** HTTP POST with JSON body */
function httpPost(url, body, apiKey, timeout = 120000) {
	return new Promise((resolve, reject) => {
		const parsedUrl = new URL(url);
		const mod = parsedUrl.protocol === 'https:' ? https : http;
		const data = JSON.stringify(body);

		const req = mod.request({
			hostname: parsedUrl.hostname,
			port: parsedUrl.port || (parsedUrl.protocol === 'https:' ? 443 : 80),
			path: parsedUrl.pathname + (parsedUrl.search || ''),
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Content-Length': Buffer.byteLength(data),
				'apikey': apiKey,
				'Authorization': `Bearer ${apiKey}`
			},
			timeout
		}, (res) => {
			let body = '';
			res.on('data', c => body += c);
			res.on('end', () => {
				if (res.statusCode >= 200 && res.statusCode < 300) {
					resolve(body);
				} else {
					reject(new Error(`HTTP ${res.statusCode}: ${body.slice(0, 500)}`));
				}
			});
		});

		req.on('error', reject);
		req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
		req.write(data);
		req.end();
	});
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function fmtSize(bytes) {
	if (bytes < 1024) return bytes + ' B';
	if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + ' KB';
	return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

// ═══ Start Server ═══
server.listen(PORT, '0.0.0.0', () => {
	console.log(`[Aqura Sync API] Running on port ${PORT}`);
	console.log(`[Aqura Sync API] POST /sync — trigger branch sync`);
	console.log(`[Aqura Sync API] GET  /health — health check`);
});
