import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const JSON_HEADERS = { 'Content-Type': 'application/json' };
const ALLOWED_TEST_BRANCH = 3;
const MAX_WINDOW_DAYS = 3;
const BRIDGE_TIMEOUT_MS = 45_000;

type JsonRecord = Record<string, unknown>;

function json(status: number, body: JsonRecord) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function requireServiceRole(req: Request, serviceRoleKey: string) {
  const token = req.headers.get('authorization')?.replace(/^Bearer\s+/i, '') || '';
  return token.length > 0 && token === serviceRoleKey;
}

function datePart(value: unknown) {
  const text = String(value || '');
  return text.slice(0, 10);
}

function timePart(value: unknown) {
  const text = String(value || '');
  const match = text.match(/T(\d{2}:\d{2}:\d{2})/);
  return match?.[1] || text.slice(11, 19);
}

function punchStatus(value: unknown) {
  return ({ 0: 'Check In', 1: 'Check Out', 2: 'Break Out', 3: 'Break In', 4: 'Overtime In', 5: 'Overtime Out' } as Record<number, string>)[Number(value)] || null;
}

function punchKey(row: JsonRecord) {
  return `${row.employee_id}-${row.date}-${row.time}-${row.status}-${row.branch_id}`;
}

async function bridgePost(url: string, secret: string, path: string, body: JsonRecord) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), BRIDGE_TIMEOUT_MS);
  try {
    const response = await fetch(`${url.replace(/\/$/, '')}${path}`, {
      method: 'POST',
      headers: { ...JSON_HEADERS, 'x-api-secret': secret },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await response.text();
    let payload: JsonRecord;
    try { payload = JSON.parse(text); } catch { throw new Error(`Bridge returned non-JSON (${response.status})`); }
    if (!response.ok || payload.success !== true) throw new Error(String(payload.error || `Bridge returned HTTP ${response.status}`));
    return Array.isArray(payload.recordset) ? payload.recordset as JsonRecord[] : [];
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req: Request) => {
  const startedAt = new Date();
  const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

  if (!supabaseUrl || !serviceRoleKey) return json(500, { success: false, error: 'Server configuration is incomplete' });
  if (!requireServiceRole(req, serviceRoleKey)) return json(401, { success: false, error: 'Service-role authorization required' });
  if (req.method !== 'POST') return json(405, { success: false, error: 'POST required' });

  try {
    let body: JsonRecord = {};
    try { body = await req.json(); } catch { /* default request */ }
    const branchId = Number(body.branchId ?? ALLOWED_TEST_BRANCH);
    const windowDays = Math.max(1, Math.min(Number(body.windowDays ?? MAX_WINDOW_DAYS), MAX_WINDOW_DAYS));

    // Safety interlocks: this test function cannot target another branch or write data.
    if (branchId !== ALLOWED_TEST_BRANCH) return json(400, { success: false, error: `Dry-run is restricted to Branch ${ALLOWED_TEST_BRANCH}` });
    if (body.dryRun === false) return json(400, { success: false, error: 'Write mode is disabled in this function' });

    const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });
    const { data: erp, error: erpError } = await supabase
      .from('erp_connections')
      .select('branch_id, branch_name, tunnel_url, bridge_api_secret, is_active')
      .eq('branch_id', branchId)
      .eq('is_active', true)
      .single();
    if (erpError || !erp) throw new Error(`Active ERP connection not found: ${erpError?.message || 'missing row'}`);
    if (!erp.tunnel_url || !erp.bridge_api_secret) throw new Error('Bridge URL or API secret is missing');

    const { data: biometric, error: biometricError } = await supabase
      .from('biometric_connections')
      .select('branch_id, branch_name, branch_location_code, device_id, terminal_sn, is_active, last_sync_at, last_employee_sync_at')
      .eq('branch_id', branchId)
      .eq('is_active', true)
      .limit(1)
      .single();
    if (biometricError || !biometric) throw new Error(`Active biometric connection not found: ${biometricError?.message || 'missing row'}`);

    const to = new Date();
    const from = new Date(to.getTime() - windowDays * 86_400_000);
    console.log(JSON.stringify({ event: 'biometric_dry_run_started', branchId, branchName: erp.branch_name, from: from.toISOString(), to: to.toISOString() }));

    const [sourceEmployees, sourcePunches] = await Promise.all([
      bridgePost(erp.tunnel_url, erp.bridge_api_secret, '/biometric/employees', {}),
      bridgePost(erp.tunnel_url, erp.bridge_api_secret, '/biometric/punches', { from: from.toISOString(), to: to.toISOString() }),
    ]);

    const prefix = String(biometric.branch_location_code || '');
    const employees = sourceEmployees
      .filter((row) => row.emp_code != null && row.first_name != null)
      .map((row) => ({ employee_id: `${prefix}${row.emp_code}`, name: String(row.first_name) }));

    const { data: existingEmployees, error: employeesError } = await supabase
      .from('hr_employees').select('employee_id, name').eq('branch_id', branchId);
    if (employeesError) throw new Error(`Could not compare employees: ${employeesError.message}`);
    const employeeMap = new Map((existingEmployees || []).map((row) => [String(row.employee_id), String(row.name || '')]));
    const employeesToCreate = employees.filter((row) => !employeeMap.has(row.employee_id));
    const employeesWithNameChanges = employees.filter((row) => employeeMap.has(row.employee_id) && employeeMap.get(row.employee_id) !== row.name);

    const transformed = sourcePunches.map((row) => {
      const status = punchStatus(row.punch_state);
      if (!status) return null;
      return {
        employee_id: `${prefix}${row.emp_code}`,
        date: datePart(row.punch_time),
        time: timePart(row.punch_time),
        status,
        device_id: String(row.terminal_sn || row.terminal_alias || 'Unknown'),
        location: String(row.area_alias || 'Unknown'),
        branch_id: branchId,
      } as JsonRecord;
    }).filter(Boolean) as JsonRecord[];

    const byEmployee = new Map<string, JsonRecord[]>();
    for (const row of transformed) {
      const key = String(row.employee_id);
      byEmployee.set(key, [...(byEmployee.get(key) || []), row]);
    }
    const filtered: JsonRecord[] = [];
    for (const rows of byEmployee.values()) {
      rows.sort((a, b) => `${a.date}T${a.time}`.localeCompare(`${b.date}T${b.time}`));
      for (let i = 0; i < rows.length; i++) {
        const current = rows[i];
        const next = rows[i + 1];
        if (next) {
          const difference = new Date(`${next.date}T${next.time}Z`).getTime() - new Date(`${current.date}T${current.time}Z`).getTime();
          if (difference >= 0 && difference <= 120_000) continue;
        }
        filtered.push(current);
      }
    }

    const minDate = filtered.map((row) => String(row.date)).sort()[0] || datePart(from.toISOString());
    const maxDate = filtered.map((row) => String(row.date)).sort().at(-1) || datePart(to.toISOString());
    const { data: existingPunches, error: punchesError } = await supabase
      .from('hr_fingerprint_transactions')
      .select('employee_id, date, time, status, branch_id')
      .eq('branch_id', branchId).gte('date', minDate).lte('date', maxDate);
    if (punchesError) throw new Error(`Could not compare punches: ${punchesError.message}`);
    const existingKeys = new Set((existingPunches || []).map((row) => punchKey(row as JsonRecord)));
    const punchesToInsert = filtered.filter((row) => !existingKeys.has(punchKey(row)));

    const result = {
      success: true,
      dryRun: true,
      writesPerformed: 0,
      branch: { id: branchId, name: erp.branch_name, locationCode: prefix },
      window: { from: from.toISOString(), to: to.toISOString(), days: windowDays },
      bridge: { employeesFetched: sourceEmployees.length, punchesFetched: sourcePunches.length },
      employees: { sourceValid: employees.length, existing: employeeMap.size, wouldCreate: employeesToCreate.length, wouldUpdateName: employeesWithNameChanges.length },
      punches: { sourceValid: transformed.length, removedWithinTwoMinutes: transformed.length - filtered.length, alreadyExisting: filtered.length - punchesToInsert.length, wouldInsert: punchesToInsert.length },
      durationMs: Date.now() - startedAt.getTime(),
    };
    console.log(JSON.stringify({ event: 'biometric_dry_run_completed', ...result }));
    return json(200, result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(JSON.stringify({ event: 'biometric_dry_run_failed', branchId: ALLOWED_TEST_BRANCH, error: message, durationMs: Date.now() - startedAt.getTime() }));
    return json(500, { success: false, dryRun: true, writesPerformed: 0, branchId: ALLOWED_TEST_BRANCH, error: message });
  }
});
