// Aqura PC Lock Guard — Supabase client factory
// Reuses the same pattern as Aqura Action Sync.

const { createClient } = require('@supabase/supabase-js');
const WebSocket = require('ws');
const { loadConfig } = require('./config');

let cachedClient = null;

function getSupabaseClient() {
	const cfg = loadConfig();
	if (!cfg.supabaseUrl || !cfg.supabaseServiceKey) {
		throw new Error('Supabase URL/Service Key not configured.');
	}
	if (cachedClient && cachedClient.__url === cfg.supabaseUrl && cachedClient.__key === cfg.supabaseServiceKey) {
		return cachedClient;
	}
	cachedClient = createClient(cfg.supabaseUrl, cfg.supabaseServiceKey, {
		auth: { autoRefreshToken: false, persistSession: false },
		realtime: { transport: WebSocket }
	});
	cachedClient.__url = cfg.supabaseUrl;
	cachedClient.__key = cfg.supabaseServiceKey;
	return cachedClient;
}

module.exports = { getSupabaseClient };
