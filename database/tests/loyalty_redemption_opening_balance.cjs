// Run with @electric-sql/pglite available, or PGLITE_MODULE pointing to its package.
// All SQL runs in an isolated in-memory database. No live credentials or services.
const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

async function main() {
  const db = new PGlite();
  try {
    await db.exec(`
      CREATE TABLE public.customers (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text, whatsapp_number text,
        total_points_earned numeric, total_redemptions numeric,
        final_loyalty_point_balance numeric, loyalty_program_opening_balance numeric,
        loyalty_tier_id uuid, registration_status text, is_deleted boolean DEFAULT false,
        updated_at timestamptz
      );
      CREATE TABLE public.loyalty_tiers (id uuid PRIMARY KEY, min_redeem_points numeric);
      CREATE TABLE public.loyalty_redemptions (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(), customer_id uuid,
        whatsapp_number text, points_redeemed numeric, coupon_code text, coupon_value numeric,
        redemption_type text, status text, otp_code text, otp_sent_at timestamptz,
        otp_attempts integer DEFAULT 0, otp_confirmed_at timestamptz, confirmed_at timestamptz,
        cashier_id text, branch_id text, erp_branch_id text
      );
      INSERT INTO loyalty_tiers VALUES ('00000000-0000-0000-0000-000000000001', 0);
    `);
    await db.exec(fs.readFileSync(path.join(__dirname, '../migrations/20261101_loyalty_redemption_opening_balance.sql'), 'utf8'));

    async function customer(opening, earned, redeemed) {
      await db.exec('TRUNCATE loyalty_redemptions, customers');
      const { rows } = await db.query(`INSERT INTO customers
        (name, whatsapp_number, total_points_earned, total_redemptions,
         final_loyalty_point_balance, loyalty_program_opening_balance, loyalty_tier_id, registration_status)
        VALUES ('Fixture', '966500000001', $1, $2, $3, $4, '00000000-0000-0000-0000-000000000001', 'approved') RETURNING id`,
        [earned, redeemed, earned + (opening || 0) - redeemed, opening]);
      return rows[0].id;
    }
    async function initiate(points) {
      const { rows } = await db.query("SELECT initiate_loyalty_redemption('0500000001', $1, 'partial') AS result", [points]);
      return rows[0].result;
    }
    async function redeem(points, expectedBalance) {
      const result = await initiate(points);
      assert.equal(result.success, true, JSON.stringify(result));
      const { rows } = await db.query('SELECT confirm_loyalty_redemption($1, $2) AS result', [result.redemption_id, result.otp_code]);
      assert.equal(rows[0].result.success, true);
      const balance = await db.query('SELECT final_loyalty_point_balance FROM customers');
      assert.equal(Number(balance.rows[0].final_loyalty_point_balance), expectedBalance);
    }

    await customer(100, 0, 0);
    assert.equal((await initiate(101)).error, 'exceeds_available');
    await redeem(30, 70);
    await redeem(20, 50);
    await redeem(50, 0);
    assert.equal((await initiate(1)).error, 'no_points_available');
    await customer(100, 20, 15);
    await redeem(25, 80);
    await customer(null, 50, 10);
    await redeem(10, 30);
    await customer(40, 0, 0);
    await db.exec('UPDATE loyalty_tiers SET min_redeem_points=50');
    assert.equal((await initiate(10)).error, 'below_minimum');
    console.log('PASS: opening-only, repeated partial, full, mixed, null opening, insufficient balance and tier minimum');
  } finally { await db.close(); }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
