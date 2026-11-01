const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const db = new PGlite();
  try {
    await db.exec('CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role; CREATE TABLE branches(id bigint PRIMARY KEY); INSERT INTO branches VALUES(1)');
    await db.exec(fs.readFileSync(path.join(__dirname, '../migrations/20261012_erp_posting_ledger_links.sql'), 'utf8'));
    await db.exec("INSERT INTO erp_posting_ledger_links(branch_id,account_key,ledger_code,ledger_name) VALUES(1,'branch_cash','CS','Cash')");
    await db.exec(fs.readFileSync(path.join(__dirname, '../migrations/20261101_pos_non_cash_ledger_links.sql'), 'utf8'));
    for (const key of ['purchase_vouchers','charity_sales','loyalty_redemption']) {
      await db.query('INSERT INTO erp_posting_ledger_links(branch_id,account_key,ledger_code,ledger_name) VALUES(1,$1,$1,$1)', [key]);
    }
    assert.equal((await db.query('SELECT count(*)::int AS n FROM erp_posting_ledger_links')).rows[0].n, 4);
    await assert.rejects(db.exec("INSERT INTO erp_posting_ledger_links(branch_id,account_key,ledger_code,ledger_name) VALUES(1,'invalid','x','x')"), /check constraint/);
    await assert.rejects(db.exec("INSERT INTO erp_posting_ledger_links(branch_id,account_key,pos_number,ledger_code,ledger_name) VALUES(1,'charity_sales',3,'x','x')"), /check constraint/);
    console.log('PASS new account types, preserved existing link, unknown-account rejection and POS-number rules.');
  } finally { await db.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
