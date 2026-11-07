const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      CREATE TABLE branches(id int PRIMARY KEY,location_en text,is_24_hours boolean,operating_start_time time,operating_end_time time,delivery_is_24_hours boolean,pickup_is_24_hours boolean,delivery_service_enabled boolean,pickup_service_enabled boolean);
      INSERT INTO branches VALUES(1,'Abu Arish',false,'06:00','02:00',false,false,false,false),(3,'Al-Aridhah',false,'06:00','02:00',false,false,false,false);
      CREATE TABLE wa_ai_bot_config(id uuid PRIMARY KEY,wa_account_id uuid,custom_instructions text,bot_rules text);
      INSERT INTO wa_ai_bot_config VALUES
        ('00000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',E'## Identity\nKeep identity.\n## Store Opening Hours | old\nBoth stores 6 AM to 2 AM.\n## Other Policy\nKeep this section.','Human support 12 PM - 8 PM'),
        ('22222222-2222-2222-2222-222222222222','22222222-2222-2222-2222-222222222222','Internal assistant unchanged','Internal rules');
      CREATE TABLE wa_settings(id uuid PRIMARY KEY,wa_account_id uuid,business_hours jsonb,outside_hours_message text);
      INSERT INTO wa_settings VALUES
        ('dc4da415-957c-43b9-a00e-bcd9c2ef383d','11111111-1111-1111-1111-111111111111','{}','Old customer hours'),
        ('33333333-3333-3333-3333-333333333333','22222222-2222-2222-2222-222222222222','{"unchanged":true}','Internal hours');
    `);
    const beforeBranch = (await db.query('SELECT * FROM branches WHERE id=3')).rows;
    const internal = (await db.query("SELECT * FROM wa_ai_bot_config WHERE id='22222222-2222-2222-2222-222222222222'")).rows;
    const internalSettings = (await db.query("SELECT * FROM wa_settings WHERE id='33333333-3333-3333-3333-333333333333'")).rows;
    const migration = fs.readFileSync(path.join(__dirname,'../migrations/20261107_abu_arish_store_open_24_hours.sql'),'utf8');
    await db.exec(migration);
    const branch = (await db.query('SELECT * FROM branches WHERE id=1')).rows[0];
    assert.equal(branch.is_24_hours,true);
    assert.equal(branch.operating_start_time,null);
    assert.equal(branch.delivery_service_enabled,false);
    assert.equal(branch.pickup_service_enabled,false);
    assert.equal(branch.delivery_is_24_hours,false);
    assert.equal(branch.pickup_is_24_hours,false);
    assert.deepEqual((await db.query('SELECT * FROM branches WHERE id=3')).rows,beforeBranch);
    assert.deepEqual((await db.query("SELECT * FROM wa_ai_bot_config WHERE id='22222222-2222-2222-2222-222222222222'")).rows,internal);
    assert.deepEqual((await db.query("SELECT * FROM wa_settings WHERE id='33333333-3333-3333-3333-333333333333'")).rows,internalSettings);
    const config = (await db.query("SELECT * FROM wa_ai_bot_config WHERE id='00000000-0000-0000-0000-000000000001'")).rows[0];
    assert.ok(config.custom_instructions.startsWith('## Identity\nKeep identity.\n'));
    assert.ok(config.custom_instructions.includes('## Other Policy\nKeep this section.'));
    assert.ok(config.custom_instructions.includes('أبو عريش مفتوح ٢٤ ساعة'));
    assert.ok(config.custom_instructions.includes('Al Aridah | العارضة: 6:00 AM to 2:00 AM'));
    assert.equal(config.bot_rules,'Human support 12 PM - 8 PM');
    const settings = (await db.query("SELECT * FROM wa_settings WHERE id='dc4da415-957c-43b9-a00e-bcd9c2ef383d'")).rows[0];
    assert.equal(Object.keys(settings.business_hours).length,7);
    assert.ok(Object.values(settings.business_hours).every(day=>day.allDay && day.open));
    await db.exec(migration);
    assert.deepEqual((await db.query("SELECT * FROM wa_ai_bot_config WHERE id='00000000-0000-0000-0000-000000000001'")).rows[0],config);
    console.log('PASS Abu Arish 24-hour store schedule, unchanged Al-Aridhah/services/support/internal assistant, bilingual customer AI and repeatable migration.');
  } finally { await db.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
