# Aqura — Instructions for Claude Code

## Secrets: the one rule that matters most

**Never put a real secret value in source code, and never let the browser hold a
credential it doesn't strictly need.** On 2026-09-08 this repo went through a full
security remediation after a public-repo audit found hardcoded credentials in 15+
files and browser code calling third-party/internal services directly with real
keys. See `AQURA_Secret_Exposure_Audit_2026-09-08.md` for the full history if you
need context on *why* these rules exist — but follow the patterns below rather than
re-reading that file each time.

If a task involves a password, API key, tunnel URL, or anything that authenticates
to another system, stop and use one of the patterns below instead of typing the
value into a file or fetching it into a `.svelte` component.

---

## Pattern 1 — Talking to a branch's ERP bridge

**Never** do this in a `.svelte` file or any browser-run code:
```js
// ❌ WRONG — never do this in browser code
const tunnelUrl = 'https://erp-branchX.urbanaqura.com'; // or fetched from erp_connections client-side
fetch(`${tunnelUrl}/query`, { headers: { 'x-api-secret': 'some-hardcoded-value' }, ... })
```

**Instead**, call the existing server proxy and let it look up the branch's tunnel
URL and secret itself:
```js
// ✅ CORRECT — browser code
const response = await fetch('/api/erp-bridge-proxy', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ branchId: branch.id, sql })  // your Aqura branch_id, not a tunnel URL
});
```

If you're writing new **server-side** code (`+server.ts`) that needs to query a
branch's ERP directly (not from the browser), look up the secret from the database
per-branch — never hardcode it:
```js
const { data: conn } = await supabase
  .from('erp_connections')
  .select('tunnel_url, erp_branch_id, bridge_api_secret')
  .eq('branch_id', branchId)
  .eq('is_active', true)
  .single();
// use conn.bridge_api_secret in the x-api-secret header — never a literal string
```

See `frontend/src/routes/api/erp-bridge-proxy/+server.ts` and
`frontend/src/routes/api/batch-erp-check/+server.ts` for full working examples.

---

## Pattern 2 — Calling a third-party API (OpenAI, Google Vision/Gemini/TTS/Routes, etc.)

**Never** fetch a key from `system_api_keys` into browser code and call the
provider directly from there. That table holds real, billable credentials.

**Instead**, for Google's Vision/Gemini/Text-to-Speech/Routes APIs, call the
existing shared proxy:
```js
// ✅ CORRECT — browser code
const res = await fetch('/api/google-ai-proxy', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ service: 'gemini', body: { /* the actual Google request body */ } })
});
```
`service` is one of `'vision' | 'gemini' | 'tts' | 'routes'`. See
`frontend/src/routes/api/google-ai-proxy/+server.ts`.

For a **different** provider not covered by that proxy, add a new
`service` case there (or a new small `+server.ts` route following the same
shape) rather than reading `system_api_keys` from the browser. The one narrow
exception is the Google **Maps JavaScript** key specifically — that key type is
designed by Google to run in the browser (secured by HTTP referrer restriction on
their side, not secrecy) — use `/api/maps-key` for that one, nothing else.

To manage the keys themselves (add/edit/disable), use the existing admin CRUD
endpoint (`/api/system-api-keys`) via the ApiKeysManager settings screen — don't
add a new direct browser read/write of that table.

---

## Pattern 3 — Naming environment variables

Any env var whose name starts with `VITE_` gets **baked into the public website
bundle** — assume anyone can read it. Never use a `VITE_`-prefixed name for a
service-role key, a bridge secret, or any credential meant to stay server-only.
(`VITE_SUPABASE_SERVICE_KEY` is a known-bad legacy name still in use in this repo
— don't copy that pattern for anything new; ideally it gets renamed to
`SUPABASE_SERVICE_ROLE_KEY` at some point, but until then, at least don't add
more variables like it.)

---

## Pattern 4 — Row Level Security

Before adding a new Supabase table that holds anything sensitive (credentials,
tokens, internal identifiers), think about who can reach it via the public REST
API with just the anon key — not just who sees it through the app's UI. The
app's own login screen does **not** gate direct database access; RLS policies do.
If a table needs to be readable only by your server, restrict its policy
accordingly rather than defaulting to `USING (true)`.
