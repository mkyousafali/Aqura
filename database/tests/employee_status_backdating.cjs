const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const db = new PGlite();
  const actor = '11111111-1111-1111-1111-111111111111';
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
      CREATE SCHEMA auth;
      CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql AS $$ SELECT 'authenticated'::text $$;
      CREATE FUNCTION public.aqura_current_user_id() RETURNS uuid LANGUAGE sql AS $$ SELECT '${actor}'::uuid $$;
      CREATE TABLE public.users(id uuid PRIMARY KEY);
      INSERT INTO public.users VALUES ('${actor}');
      CREATE TABLE public.hr_employee_master(id text PRIMARY KEY);
      INSERT INTO public.hr_employee_master VALUES ('EMP_TEST'), ('EMP_OTHER');
    `);
    // Reuse the production history constraints and the actual audit trigger.
    const schema = fs.readFileSync(path.join(__dirname, '../deploy/01_public_schema.sql'), 'utf8');
    const table = schema.match(/CREATE TABLE public\.hr_employee_status_history \([\s\S]*?\n\);/)[0];
    await db.exec(table.replace('id bigint NOT NULL', 'id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY'));
    await db.exec(`CREATE UNIQUE INDEX hr_employee_status_history_one_open_idx
      ON public.hr_employee_status_history(employee_id) WHERE effective_to IS NULL`);
    const audit = fs.readFileSync(path.join(__dirname, '../migrations/20261010_audit_employee_status_and_shifts.sql'), 'utf8');
    await db.exec(audit.slice(0, audit.indexOf('create or replace function public.change_employee_status(')) + 'commit;');
    await db.exec(fs.readFileSync(path.join(__dirname, '../migrations/20261107_allow_non_conflicting_backdated_employee_status.sql'), 'utf8'));

    const seed = async (periods) => {
      await db.exec('TRUNCATE hr_employee_status_history, hr_employee_status_audit_log RESTART IDENTITY');
      for (const [status, from, to] of periods) {
        await db.query(`INSERT INTO hr_employee_status_history(employee_id,status,effective_from,effective_to,reason)
          VALUES ('EMP_TEST',$1,$2,$3,'original')`, [status, from, to]);
      }
      await db.exec('TRUNCATE hr_employee_status_audit_log');
    };
    const change = async (date, status = 'Remote Job', reason = '  historical correction  ', employee = 'EMP_TEST') =>
      (await db.query(`SELECT id, employee_id, status, effective_from::text, effective_to::text, reason
        FROM change_employee_status($1,$2,$3,$4,$5)`, [employee, status, date, reason, actor])).rows[0];
    const history = async () => (await db.query(`SELECT id, status, effective_from::text, effective_to::text, reason
      FROM hr_employee_status_history WHERE employee_id='EMP_TEST' ORDER BY id`)).rows;
    const assertNoOverlap = async () => assert.equal((await db.query(`SELECT count(*)::int AS n
      FROM hr_employee_status_history a JOIN hr_employee_status_history b
      ON a.employee_id=b.employee_id AND a.id<b.id
      AND daterange(a.effective_from,a.effective_to,'[]') && daterange(b.effective_from,b.effective_to,'[]')`)).rows[0].n, 0);

    // The screenshot case: Oct 1 is before the first recorded start on Oct 7.
    await seed([['Job (With Finger)', '2026-10-07', null]]);
    const original = await history();
    const inserted = await change('2026-10-01');
    assert.equal(inserted.effective_from, '2026-10-01');
    assert.equal(inserted.effective_to, '2026-10-06');
    assert.equal(inserted.reason, 'historical correction');
    assert.deepEqual((await history()).filter(row => row.id === original[0].id), original);
    assert.equal((await db.query('SELECT action FROM hr_employee_status_audit_log')).rows[0].action, 'create');
    assert.equal((await db.query('SELECT created_by::text FROM hr_employee_status_history WHERE id=$1', [inserted.id])).rows[0].created_by, actor);
    await assertNoOverlap();

    // Fill a gap up to a closed period, preserving that period and the open row.
    await seed([
      ['Job (With Finger)', '2026-09-01', '2026-09-15'],
      ['Vacation', '2026-10-05', '2026-10-06'],
      ['Job (With Finger)', '2026-10-07', null]
    ]);
    const beforeGap = await history();
    assert.equal((await change('2026-10-01')).effective_to, '2026-10-04');
    assert.deepEqual((await history()).filter(row => beforeGap.some(old => old.id === row.id)), beforeGap);
    await assertNoOverlap();

    // Conflicting closed dates, inclusive boundaries, and an existing open
    // transition date fail atomically, leaving history and audit untouched.
    for (const date of ['2026-09-01', '2026-09-10', '2026-09-15', '2026-10-05', '2026-10-06', '2026-10-07']) {
      const before = await history();
      const auditBefore = (await db.query('SELECT count(*)::int AS n FROM hr_employee_status_audit_log')).rows[0].n;
      await assert.rejects(change(date), /conflicts with an existing/);
      assert.deepEqual(await history(), before);
      assert.equal((await db.query('SELECT count(*)::int AS n FROM hr_employee_status_audit_log')).rows[0].n, auditBefore);
    }

    // Forward transitions retain the existing close-and-open behavior and audit.
    await seed([['Job (With Finger)', '2026-10-07', null]]);
    assert.equal((await change('2026-10-10')).effective_to, null);
    assert.equal((await history())[0].effective_to, '2026-10-09');
    assert.deepEqual((await db.query('SELECT action FROM hr_employee_status_audit_log ORDER BY id')).rows.map(row => row.action), ['update', 'create']);
    await assertNoOverlap();

    await seed([['Job (With Finger)', null, null]]);
    await change('2026-10-01');
    assert.equal((await history())[0].effective_to, '2026-09-30');
    await assertNoOverlap();

    // Unknown historical start covers all earlier dates and is a conflict.
    await seed([['Vacation', null, '2026-09-30'], ['Job (With Finger)', '2026-10-07', null]]);
    await assert.rejects(change('2026-09-01'), /conflicts with an existing/);

    await seed([]);
    assert.equal((await change('2026-10-01')).effective_to, null);
    const unchanged = await history();
    await assert.rejects(change(null), /Start date is required/);
    await assert.rejects(change('2026-10-02', 'invalid'), /Invalid employment status/);
    await assert.rejects(change('2026-10-02', null), /Invalid employment status/);
    await assert.rejects(change('2026-10-02', 'Remote Job', '   '), /Reason is required/);
    await assert.rejects(change('2026-10-02', 'Remote Job', 'reason', 'MISSING'), /Employee not found/);
    assert.deepEqual(await history(), unchanged);
    assert.equal((await db.query(`SELECT has_function_privilege('anon', 'change_employee_status(text,text,date,text,uuid)', 'execute') AS allowed`)).rows[0].allowed, false);
    assert.equal((await db.query(`SELECT has_function_privilege('authenticated', 'change_employee_status(text,text,date,text,uuid)', 'execute') AS allowed`)).rows[0].allowed, true);
    console.log('PASS backdating before first status, gaps, preserved later periods, overlap boundaries, forward changes, unknown starts, audit, validation and grants.');
  } finally {
    await db.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
