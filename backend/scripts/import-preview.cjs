'use strict';

/**
 * One-shot CafeFlow import from backend/migration-preview/ into PostgreSQL.
 * Single transaction. Preview UUIDs only. No invented data.
 */

const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const BACKEND_ROOT = path.resolve(__dirname, '..');
const PREVIEW_DIR = path.join(BACKEND_ROOT, 'migration-preview');

function loadEnv() {
  const envPath = path.join(BACKEND_ROOT, '.env');
  const text = fs.readFileSync(envPath, 'utf8');
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq < 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

function readJson(name) {
  const file = path.join(PREVIEW_DIR, name);
  const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!Array.isArray(rows)) {
    throw new Error(`${name} is not a JSON array`);
  }
  return rows.filter((row) => {
    const status = row.migration_status;
    if (status == null) return true;
    const normalized = String(status).toLowerCase();
    return normalized !== 'unresolved' && normalized !== 'ambiguous';
  });
}

function ids(rows) {
  return rows.map((r) => r.id).sort();
}

function sameIdSet(previewRows, dbRows) {
  const a = ids(previewRows);
  const b = dbRows.map((r) => r.id).sort();
  if (a.length !== b.length) return false;
  return a.every((id, i) => id === b[i]);
}

async function main() {
  loadEnv();

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is not set');
  }

  const parsed = new URL(databaseUrl);
  if (parsed.hostname !== '127.0.0.1' && parsed.hostname !== 'localhost') {
    throw new Error(`Refusing non-local host: ${parsed.hostname}`);
  }
  if (parsed.port !== '5432') {
    throw new Error(`Refusing non-CafeFlow port: ${parsed.port}`);
  }
  const dbName = parsed.pathname.replace(/^\//, '');
  if (dbName !== 'cafeflow') {
    throw new Error(`Refusing non-CafeFlow database: ${dbName}`);
  }

  const preview = {
    users: readJson('users.json'),
    locations: readJson('locations.json'),
    products: readJson('products.json'),
    cleaning_lists: readJson('cleaning_lists.json'),
    user_locations: readJson('user_locations.json'),
    shifts: readJson('shifts.json'),
    availability: readJson('availability.json'),
    vacations: readJson('vacations.json'),
    cleaning_tasks: readJson('cleaning_tasks.json'),
    cleaning_completions: readJson('cleaning_completions.json'),
    scheduling_config: readJson('scheduling_config.json'),
    consumptions: readJson('consumptions.json'),
  };

  if (preview.consumptions.length !== 0) {
    throw new Error(
      `consumptions.json must be empty for this import; found ${preview.consumptions.length} rows`,
    );
  }

  const client = new Client({ connectionString: databaseUrl });
  await client.connect();

  let transaction = 'ROLLED BACK';
  let insertError = null;

  try {
    const target = await client.query(`
      SELECT
        current_database() AS db,
        inet_server_addr()::text AS addr,
        inet_server_port() AS port,
        current_setting('server_version') AS version
    `);
    const t = target.rows[0];
    console.log('TARGET DATABASE');
    console.log('===============');
    console.log(`db=${t.db} addr=${t.addr} port=${t.port} version=${t.version}`);

    if (t.db !== 'cafeflow') {
      throw new Error(`Connected database is not cafeflow: ${t.db}`);
    }
    if (String(t.port) !== '5432') {
      throw new Error(`Connected port is not 5432: ${t.port}`);
    }

    const schema = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_type = 'BASE TABLE'
      ORDER BY table_name
    `);
    const tables = new Set(schema.rows.map((r) => r.table_name));
    const required = [
      'users',
      'locations',
      'products',
      'cleaning_lists',
      'user_locations',
      'shifts',
      'availability',
      'vacations',
      'cleaning_tasks',
      'cleaning_completions',
      'scheduling_configs',
      'consumptions',
    ];
    const missing = required.filter((name) => !tables.has(name));
    if (missing.length) {
      throw new Error(`Schema missing tables: ${missing.join(', ')}`);
    }
    console.log(`schema tables present: ${required.join(', ')}`);

    const existing = await client.query(`
      SELECT
        (SELECT count(*)::int FROM users) AS users,
        (SELECT count(*)::int FROM locations) AS locations,
        (SELECT count(*)::int FROM products) AS products,
        (SELECT count(*)::int FROM cleaning_lists) AS cleaning_lists,
        (SELECT count(*)::int FROM user_locations) AS user_locations,
        (SELECT count(*)::int FROM shifts) AS shifts,
        (SELECT count(*)::int FROM availability) AS availability,
        (SELECT count(*)::int FROM vacations) AS vacations,
        (SELECT count(*)::int FROM cleaning_tasks) AS cleaning_tasks,
        (SELECT count(*)::int FROM cleaning_completions) AS cleaning_completions,
        (SELECT count(*)::int FROM scheduling_configs) AS scheduling_configs,
        (SELECT count(*)::int FROM consumptions) AS consumptions
    `);
    const nonempty = Object.entries(existing.rows[0]).filter(([, n]) => n > 0);
    if (nonempty.length) {
      throw new Error(
        `Refusing import: target tables are not empty: ${nonempty
          .map(([k, n]) => `${k}=${n}`)
          .join(', ')}`,
      );
    }
    console.log('target import tables are empty; beginning transaction');

    await client.query('BEGIN');

    for (const row of preview.users) {
      await client.query(
        `INSERT INTO users (
           id, firebase_uid, email, name, role, contract_type,
           monthly_target_hours, needs_contract_type, auth_provider,
           employment_started_on, fcm_token
         ) VALUES (
           $1::uuid, $2, $3, $4, $5::user_role, $6::contract_type,
           $7, $8, $9::auth_provider, $10::date, $11
         )`,
        [
          row.id,
          row.firebase_uid,
          row.email,
          row.name,
          row.role,
          row.contract_type,
          row.monthly_target_hours,
          row.needs_contract_type,
          row.auth_provider,
          row.employment_started_on,
          row.fcm_token,
        ],
      );
    }

    for (const row of preview.locations) {
      await client.query(
        `INSERT INTO locations (id, code, name)
         VALUES ($1::uuid, $2, $3)`,
        [row.id, row.code, row.name],
      );
    }

    for (const row of preview.products) {
      await client.query(
        `INSERT INTO products (id, name)
         VALUES ($1::uuid, $2)`,
        [row.id, row.name],
      );
    }

    for (const row of preview.cleaning_lists) {
      await client.query(
        `INSERT INTO cleaning_lists (id, location_id, key)
         VALUES ($1::uuid, $2::uuid, $3::cleaning_list_key)`,
        [row.id, row.location_id, row.key],
      );
    }

    for (const row of preview.user_locations) {
      await client.query(
        `INSERT INTO user_locations (
           id, user_id, location_id, is_primary, valid_from, valid_until
         ) VALUES (
           $1::uuid, $2::uuid, $3::uuid, $4, $5::date, $6::date
         )`,
        [
          row.id,
          row.user_id,
          row.location_id,
          row.is_primary,
          row.valid_from,
          row.valid_until,
        ],
      );
    }

    for (const row of preview.shifts) {
      await client.query(
        `INSERT INTO shifts (
           id, user_id, location_id, work_date, start_at, end_at, type, status
         ) VALUES (
           $1::uuid, $2::uuid, $3::uuid, $4::date,
           $5::timestamptz, $6::timestamptz, $7::shift_type, $8::shift_status
         )`,
        [
          row.id,
          row.user_id,
          row.location_id,
          row.work_date,
          row.start_at,
          row.end_at,
          row.type,
          row.status,
        ],
      );
    }

    for (const row of preview.availability) {
      await client.query(
        `INSERT INTO availability (
           id, user_id, work_date, shift_type,
           custom_start_time, custom_end_time, submitted_at
         ) VALUES (
           $1::uuid, $2::uuid, $3::date, $4::availability_shift_type,
           $5::time, $6::time, $7::timestamptz
         )`,
        [
          row.id,
          row.user_id,
          row.work_date,
          row.shift_type,
          row.custom_start_time,
          row.custom_end_time,
          row.submitted_at,
        ],
      );
    }

    for (const row of preview.vacations) {
      await client.query(
        `INSERT INTO vacations (
           id, user_id, start_on, end_on, status, requested_at, admin_comment
         ) VALUES (
           $1::uuid, $2::uuid, $3::date, $4::date,
           $5::vacation_status, $6::timestamptz, $7
         )`,
        [
          row.id,
          row.user_id,
          row.start_on,
          row.end_on,
          row.status,
          row.requested_at,
          row.admin_comment,
        ],
      );
    }

    for (const row of preview.cleaning_tasks) {
      await client.query(
        `INSERT INTO cleaning_tasks (id, list_id, title, sort_order, is_active)
         VALUES ($1::uuid, $2::uuid, $3, $4, $5)`,
        [row.id, row.list_id, row.title, row.sort_order, row.is_active],
      );
    }

    for (const row of preview.cleaning_completions) {
      await client.query(
        `INSERT INTO cleaning_completions (
           id, user_id, task_id, week_id, completed, completed_at
         ) VALUES (
           $1::uuid, $2::uuid, $3::uuid, $4, $5, $6::timestamptz
         )`,
        [
          row.id,
          row.user_id,
          row.task_id,
          row.week_id,
          row.completed,
          row.completed_at,
        ],
      );
    }

    for (const row of preview.scheduling_config) {
      await client.query(
        `INSERT INTO scheduling_configs (
           id, year, month, location_id, scheduling_enabled,
           locked_month, enabled_by, enabled_at
         ) VALUES (
           $1::uuid, $2, $3, $4::uuid, $5, $6, $7::uuid, $8::timestamptz
         )`,
        [
          row.id,
          row.year,
          row.month,
          row.location_id,
          row.scheduling_enabled,
          row.locked_month,
          row.enabled_by,
          row.enabled_at,
        ],
      );
    }

    if (preview.consumptions.length > 0) {
      throw new Error('consumptions must remain without INSERT statements');
    }

    await client.query('COMMIT');
    transaction = 'COMMITTED';
    console.log('TRANSACTION COMMITTED');
  } catch (err) {
    insertError = err;
    try {
      await client.query('ROLLBACK');
    } catch {
      // ignore rollback failure if BEGIN never succeeded
    }
    transaction = 'ROLLED BACK';
    console.error('INSERT FAILED — ROLLBACK');
    console.error(err && err.stack ? err.stack : String(err));
  }

  const counts = {
    users: { pg: null, preview: preview.users.length },
    locations: { pg: null, preview: preview.locations.length },
    products: { pg: null, preview: preview.products.length },
    cleaning_lists: { pg: null, preview: preview.cleaning_lists.length },
    user_locations: { pg: null, preview: preview.user_locations.length },
    shifts: { pg: null, preview: preview.shifts.length },
    availability: { pg: null, preview: preview.availability.length },
    vacations: { pg: null, preview: preview.vacations.length },
    cleaning_tasks: { pg: null, preview: preview.cleaning_tasks.length },
    cleaning_completions: {
      pg: null,
      preview: preview.cleaning_completions.length,
    },
    scheduling_config: {
      pg: null,
      preview: preview.scheduling_config.length,
    },
    consumptions: { pg: null, preview: preview.consumptions.length },
  };

  let fkErrors = 0;
  let constraintErrors = 0;
  const details = {};

  if (transaction === 'COMMITTED') {
    const countSql = await client.query(`
      SELECT
        (SELECT count(*)::int FROM users) AS users,
        (SELECT count(*)::int FROM locations) AS locations,
        (SELECT count(*)::int FROM products) AS products,
        (SELECT count(*)::int FROM cleaning_lists) AS cleaning_lists,
        (SELECT count(*)::int FROM user_locations) AS user_locations,
        (SELECT count(*)::int FROM shifts) AS shifts,
        (SELECT count(*)::int FROM availability) AS availability,
        (SELECT count(*)::int FROM vacations) AS vacations,
        (SELECT count(*)::int FROM cleaning_tasks) AS cleaning_tasks,
        (SELECT count(*)::int FROM cleaning_completions) AS cleaning_completions,
        (SELECT count(*)::int FROM scheduling_configs) AS scheduling_config,
        (SELECT count(*)::int FROM consumptions) AS consumptions
    `);
    for (const [key, value] of Object.entries(countSql.rows[0])) {
      counts[key].pg = value;
    }

    const tableSelects = {
      users: `SELECT id, firebase_uid, email, name, role::text, contract_type::text,
                     monthly_target_hours, needs_contract_type, auth_provider::text,
                     employment_started_on::text, fcm_token
              FROM users ORDER BY firebase_uid`,
      locations: `SELECT id, code, name FROM locations ORDER BY code`,
      products: `SELECT id, name FROM products ORDER BY name`,
      user_locations: `SELECT id, user_id, location_id, is_primary,
                              valid_from::text, valid_until::text
                       FROM user_locations ORDER BY id`,
      shifts: `SELECT id, user_id, location_id, work_date::text,
                      start_at, end_at, type::text, status::text
               FROM shifts ORDER BY id`,
      availability: `SELECT id, user_id, work_date::text, shift_type::text,
                            custom_start_time::text, custom_end_time::text, submitted_at
                     FROM availability ORDER BY work_date, id`,
      vacations: `SELECT id, user_id, start_on::text, end_on::text,
                         status::text, requested_at, admin_comment
                  FROM vacations ORDER BY start_on, id`,
      cleaning_lists: `SELECT id, location_id, key::text
                       FROM cleaning_lists ORDER BY key, id`,
      cleaning_tasks: `SELECT id, list_id, title, sort_order, is_active
                       FROM cleaning_tasks ORDER BY list_id, sort_order, id`,
      cleaning_completions: `SELECT id, user_id, task_id, week_id, completed, completed_at
                             FROM cleaning_completions ORDER BY week_id, id`,
      scheduling_config: `SELECT id, year, month, location_id, scheduling_enabled,
                                 locked_month, enabled_by, enabled_at
                          FROM scheduling_configs ORDER BY year, month, id`,
      consumptions: `SELECT id FROM consumptions ORDER BY id`,
    };

    for (const [name, sql] of Object.entries(tableSelects)) {
      const result = await client.query(sql);
      details[name] = result.rows;
    }

    const idMatch = {
      users: sameIdSet(preview.users, details.users),
      locations: sameIdSet(preview.locations, details.locations),
      products: sameIdSet(preview.products, details.products),
      cleaning_lists: sameIdSet(preview.cleaning_lists, details.cleaning_lists),
      user_locations: sameIdSet(preview.user_locations, details.user_locations),
      shifts: sameIdSet(preview.shifts, details.shifts),
      availability: sameIdSet(preview.availability, details.availability),
      vacations: sameIdSet(preview.vacations, details.vacations),
      cleaning_tasks: sameIdSet(preview.cleaning_tasks, details.cleaning_tasks),
      cleaning_completions: sameIdSet(
        preview.cleaning_completions,
        details.cleaning_completions,
      ),
      scheduling_config: sameIdSet(
        preview.scheduling_config,
        details.scheduling_config,
      ),
      consumptions: sameIdSet(preview.consumptions, details.consumptions),
    };

    const fk = await client.query(`
      SELECT 'user_locations.user_id' AS fk, count(*)::int AS n
        FROM user_locations ul LEFT JOIN users u ON u.id = ul.user_id
        WHERE u.id IS NULL
      UNION ALL
      SELECT 'user_locations.location_id', count(*)::int
        FROM user_locations ul LEFT JOIN locations l ON l.id = ul.location_id
        WHERE l.id IS NULL
      UNION ALL
      SELECT 'shifts.user_id', count(*)::int
        FROM shifts s LEFT JOIN users u ON u.id = s.user_id
        WHERE u.id IS NULL
      UNION ALL
      SELECT 'shifts.location_id', count(*)::int
        FROM shifts s LEFT JOIN locations l ON l.id = s.location_id
        WHERE l.id IS NULL
      UNION ALL
      SELECT 'availability.user_id', count(*)::int
        FROM availability a LEFT JOIN users u ON u.id = a.user_id
        WHERE u.id IS NULL
      UNION ALL
      SELECT 'vacations.user_id', count(*)::int
        FROM vacations v LEFT JOIN users u ON u.id = v.user_id
        WHERE u.id IS NULL
      UNION ALL
      SELECT 'cleaning_lists.location_id', count(*)::int
        FROM cleaning_lists cl LEFT JOIN locations l ON l.id = cl.location_id
        WHERE l.id IS NULL
      UNION ALL
      SELECT 'cleaning_tasks.list_id', count(*)::int
        FROM cleaning_tasks ct LEFT JOIN cleaning_lists cl ON cl.id = ct.list_id
        WHERE cl.id IS NULL
      UNION ALL
      SELECT 'cleaning_completions.user_id', count(*)::int
        FROM cleaning_completions cc LEFT JOIN users u ON u.id = cc.user_id
        WHERE u.id IS NULL
      UNION ALL
      SELECT 'cleaning_completions.task_id', count(*)::int
        FROM cleaning_completions cc LEFT JOIN cleaning_tasks t ON t.id = cc.task_id
        WHERE t.id IS NULL
      UNION ALL
      SELECT 'scheduling_configs.location_id', count(*)::int
        FROM scheduling_configs sc
        LEFT JOIN locations l ON l.id = sc.location_id
        WHERE sc.location_id IS NOT NULL AND l.id IS NULL
      UNION ALL
      SELECT 'scheduling_configs.enabled_by', count(*)::int
        FROM scheduling_configs sc
        LEFT JOIN users u ON u.id = sc.enabled_by
        WHERE sc.enabled_by IS NOT NULL AND u.id IS NULL
      UNION ALL
      SELECT 'consumptions.user_id', count(*)::int
        FROM consumptions c LEFT JOIN users u ON u.id = c.user_id
        WHERE u.id IS NULL
      UNION ALL
      SELECT 'consumptions.product_id', count(*)::int
        FROM consumptions c LEFT JOIN products p ON p.id = c.product_id
        WHERE p.id IS NULL
      UNION ALL
      SELECT 'consumptions.location_id', count(*)::int
        FROM consumptions c LEFT JOIN locations l ON l.id = c.location_id
        WHERE l.id IS NULL
    `);
    const fkBroken = fk.rows.filter((r) => r.n > 0);
    fkErrors = fkBroken.reduce((sum, r) => sum + r.n, 0);

    const unique = await client.query(`
      SELECT 'users.firebase_uid' AS constraint_name, count(*)::int AS n
        FROM (
          SELECT firebase_uid FROM users GROUP BY firebase_uid HAVING count(*) > 1
        ) d
      UNION ALL
      SELECT 'locations.code', count(*)::int
        FROM (SELECT code FROM locations GROUP BY code HAVING count(*) > 1) d
      UNION ALL
      SELECT 'user_locations(user_id,location_id,valid_from)', count(*)::int
        FROM (
          SELECT user_id, location_id, valid_from
          FROM user_locations
          GROUP BY user_id, location_id, valid_from
          HAVING count(*) > 1
        ) d
      UNION ALL
      SELECT 'availability(user_id,work_date)', count(*)::int
        FROM (
          SELECT user_id, work_date
          FROM availability
          GROUP BY user_id, work_date
          HAVING count(*) > 1
        ) d
      UNION ALL
      SELECT 'cleaning_lists(location_id,key)', count(*)::int
        FROM (
          SELECT location_id, key
          FROM cleaning_lists
          GROUP BY location_id, key
          HAVING count(*) > 1
        ) d
      UNION ALL
      SELECT 'cleaning_completions(user_id,task_id,week_id)', count(*)::int
        FROM (
          SELECT user_id, task_id, week_id
          FROM cleaning_completions
          GROUP BY user_id, task_id, week_id
          HAVING count(*) > 1
        ) d
      UNION ALL
      SELECT 'scheduling_configs(year,month,location_id)', count(*)::int
        FROM (
          SELECT year, month, location_id
          FROM scheduling_configs
          GROUP BY year, month, location_id
          HAVING count(*) > 1
        ) d
    `);

    const checks = await client.query(`
      SELECT 'users_monthly_target_hours_positive' AS constraint_name, count(*)::int AS n
        FROM users WHERE NOT (monthly_target_hours > 0)
      UNION ALL
      SELECT 'locations_closed_on_gte_opened_on', count(*)::int
        FROM locations
        WHERE NOT (closed_on IS NULL OR opened_on IS NULL OR closed_on >= opened_on)
      UNION ALL
      SELECT 'user_locations_valid_until_gte_valid_from', count(*)::int
        FROM user_locations
        WHERE NOT (valid_until IS NULL OR valid_until >= valid_from)
      UNION ALL
      SELECT 'consumptions_quantity_positive', count(*)::int
        FROM consumptions WHERE NOT (quantity > 0)
      UNION ALL
      SELECT 'shifts_end_at_gte_start_at', count(*)::int
        FROM shifts WHERE NOT (end_at >= start_at)
      UNION ALL
      SELECT 'availability_shift_times_consistent', count(*)::int
        FROM availability
        WHERE NOT (
          (shift_type = 'full_time' AND custom_start_time IS NULL AND custom_end_time IS NULL)
          OR
          (shift_type = 'custom_hours' AND custom_start_time IS NOT NULL
            AND custom_end_time IS NOT NULL AND custom_end_time > custom_start_time)
        )
      UNION ALL
      SELECT 'vacations_end_on_gte_start_on', count(*)::int
        FROM vacations WHERE NOT (end_on >= start_on)
      UNION ALL
      SELECT 'scheduling_configs_month_range', count(*)::int
        FROM scheduling_configs WHERE NOT (month >= 1 AND month <= 12)
      UNION ALL
      SELECT 'scheduling_configs_year_range', count(*)::int
        FROM scheduling_configs WHERE NOT (year >= 2000 AND year <= 2100)
      UNION ALL
      SELECT 'scheduling_configs_max_hours_positive', count(*)::int
        FROM scheduling_configs
        WHERE NOT (max_hours_per_day IS NULL OR max_hours_per_day > 0)
      UNION ALL
      SELECT 'scheduling_configs_max_employees_positive', count(*)::int
        FROM scheduling_configs
        WHERE NOT (max_employees_per_shift IS NULL OR max_employees_per_shift > 0)
      UNION ALL
      SELECT 'cleaning_completions_week_id_format', count(*)::int
        FROM cleaning_completions
        WHERE NOT (week_id ~ '^[0-9]{4}-W[0-9]{2}$')
    `);

    const uniqueBroken = unique.rows.filter((r) => r.n > 0);
    const checkBroken = checks.rows.filter((r) => r.n > 0);
    constraintErrors =
      uniqueBroken.reduce((sum, r) => sum + r.n, 0) +
      checkBroken.reduce((sum, r) => sum + r.n, 0);

    console.log('\nVERIFICATION SELECTS');
    console.log('====================');
    for (const [name, row] of Object.entries(counts)) {
      const match = row.pg === row.preview && idMatch[name];
      console.log(
        `${name}: pg=${row.pg} preview=${row.preview} ids_match=${match}`,
      );
    }
    console.log('FK orphans:', fkBroken.length ? fkBroken : 'none');
    console.log('UNIQUE duplicates:', uniqueBroken.length ? uniqueBroken : 'none');
    console.log('CHECK violations:', checkBroken.length ? checkBroken : 'none');

    for (const [name, rows] of Object.entries(details)) {
      console.log(`\n${name.toUpperCase()} (${rows.length})`);
      console.log(JSON.stringify(rows, null, 2));
    }
  }

  const countMatch = Object.values(counts).every(
    (row) => row.pg === row.preview,
  );
  const successful =
    transaction === 'COMMITTED' &&
    countMatch &&
    fkErrors === 0 &&
    constraintErrors === 0 &&
    !insertError;

  console.log('\nPOSTGRESQL IMPORT');
  console.log('=================');
  console.log(`Transaction: ${transaction}`);
  console.log(`users: ${counts.users.pg}/${counts.users.preview}`);
  console.log(`locations: ${counts.locations.pg}/${counts.locations.preview}`);
  console.log(`products: ${counts.products.pg}/${counts.products.preview}`);
  console.log(
    `cleaning_lists: ${counts.cleaning_lists.pg}/${counts.cleaning_lists.preview}`,
  );
  console.log(
    `user_locations: ${counts.user_locations.pg}/${counts.user_locations.preview}`,
  );
  console.log(`shifts: ${counts.shifts.pg}/${counts.shifts.preview}`);
  console.log(
    `availability: ${counts.availability.pg}/${counts.availability.preview}`,
  );
  console.log(`vacations: ${counts.vacations.pg}/${counts.vacations.preview}`);
  console.log(
    `cleaning_tasks: ${counts.cleaning_tasks.pg}/${counts.cleaning_tasks.preview}`,
  );
  console.log(
    `cleaning_completions: ${counts.cleaning_completions.pg}/${counts.cleaning_completions.preview}`,
  );
  console.log(
    `scheduling_config: ${counts.scheduling_config.pg}/${counts.scheduling_config.preview}`,
  );
  console.log(
    `consumptions: ${counts.consumptions.pg}/${counts.consumptions.preview}`,
  );
  console.log(`FK ERRORS: ${fkErrors}`);
  console.log(`CONSTRAINT ERRORS: ${constraintErrors}`);
  console.log('');
  console.log('FINAL VERDICT:');
  console.log(successful ? 'IMPORT SUCCESSFUL' : 'IMPORT ROLLED BACK');

  await client.end();

  if (!successful) {
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exit(1);
});
