// Isolated PostgreSQL runtime only. Set PGLITE_MODULE to the installed package.
const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

async function main() {
  const db = new PGlite();
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;
      CREATE TABLE loyalty_redemptions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), coupon_code text UNIQUE, coupon_value numeric, status text);
      CREATE TABLE box_operations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid DEFAULT gen_random_uuid(), branch_id integer DEFAULT 2,
        status text DEFAULT 'in_use', closing_details jsonb, end_time timestamptz, updated_at timestamptz DEFAULT now());
      INSERT INTO loyalty_redemptions (coupon_code,coupon_value,status) VALUES
        ('LYL-00000001',100,'confirmed'),('LYL-00000002',20,'confirmed'),('LYL-00000003',30,'confirmed'),
        ('LYL-00000004',40,'pending'),('LYL-00000005',50,'confirmed'),('LYL-00000006',60,'confirmed');
      INSERT INTO box_operations(status,closing_details) VALUES ('completed',
        '{"loyalty_vouchers":[{"serial":"LYL-00000006","amount":60}],"loyalty_vouchers_total":60}');
    `);
    await db.exec(fs.readFileSync(path.join(__dirname, '../migrations/20261101_loyalty_coupon_counter_use.sql'), 'utf8'));
    const scalar = async sql => (await db.query(sql)).rows[0].n;
    assert.equal(await scalar('SELECT count(*)::int AS n FROM loyalty_coupon_uses'), 1, 'backfill prior closed counters');

    async function box(items, total) {
      const result = await db.query('INSERT INTO box_operations(closing_details) VALUES ($1) RETURNING id', [JSON.stringify({ loyalty_vouchers: items.map(([serial, amount]) => ({ serial, amount })), loyalty_vouchers_total: total })]);
      return result.rows[0].id;
    }
    const close = id => db.query("UPDATE box_operations SET status='pending_close' WHERE id=$1", [id]);
    const first = await box([['LYL-00000001', 100]], 100);
    assert.equal(await scalar('SELECT count(*)::int AS n FROM loyalty_coupon_uses'), 1, 'draft does not consume');
    await close(first);
    await close(first);
    await db.query("UPDATE box_operations SET status='completed' WHERE id=$1", [first]);
    assert.equal(await scalar('SELECT count(*)::int AS n FROM loyalty_coupon_uses'), 2, 'retry/completion does not consume twice');

    const reused = await box([['LYL-00000001', 100]], 100);
    await assert.rejects(close(reused), /already been used/);
    assert.equal((await db.query('SELECT status FROM box_operations WHERE id=$1', [reused])).rows[0].status, 'in_use');
    await assert.rejects(db.query("UPDATE box_operations SET closing_details='{}' WHERE id=$1", [first]), /cannot be removed/);

    const wrongAmount = await box([['LYL-00000002', 99]], 99);
    await assert.rejects(close(wrongAmount), /amount does not match/);
    const duplicate = await box([['LYL-00000002', 20], ['LYL-00000002', 20]], 40);
    await assert.rejects(close(duplicate), /Duplicate loyalty coupon/);
    const unconfirmed = await box([['LYL-00000004', 40]], 40);
    await assert.rejects(close(unconfirmed), /not confirmed/);
    const totalMismatch = await box([['LYL-00000002', 20]], 25);
    await assert.rejects(close(totalMismatch), /total does not match/);
    assert.equal(await scalar("SELECT count(*)::int AS n FROM loyalty_coupon_uses WHERE amount=20"), 0, 'failed close rolls back use');

    const mixed = await box([['LYL-00000002', 20], ['LYL-00000003', 99]], 119);
    await assert.rejects(close(mixed), /amount does not match/);
    assert.equal(await scalar('SELECT count(*)::int AS n FROM loyalty_coupon_uses'), 2, 'whole coupon list rolls back');
    const valid = await box([['LYL-00000002', 20], ['LYL-00000003', 30]], 50);
    await close(valid);
    assert.equal(await scalar('SELECT count(*)::int AS n FROM loyalty_coupon_uses'), 4);
    assert.equal(await scalar("SELECT count(*)::int AS n FROM loyalty_redemptions WHERE status='confirmed'"), 5, 'redemption status remains confirmed for balance calculations');

    // A later failure in the same closing transaction must undo the coupon use too.
    const failedTransaction = await box([['LYL-00000005', 50]], 50);
    await db.exec('BEGIN'); await close(failedTransaction); await db.exec('ROLLBACK');
    assert.equal(await scalar("SELECT count(*)::int AS n FROM loyalty_coupon_uses WHERE amount=50"), 0);
    await close(failedTransaction);
    console.log('PASS: draft, atomic close, used-coupon rejection, retry, duplicate/amount checks, full rollback, backfill and preserved redemption status');
  } finally { await db.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
