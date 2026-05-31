// setupSupabase.ts — Create Supabase schema + seed all data

import pg from "npm:pg@8.11.3";
const { Client } = pg;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_DB_PASSWORD = Deno.env.get("SUPABASE_DB_PASSWORD")!;

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, x-base44-app-id",
  };
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });

  const body = await req.json().catch(() => ({}));
  const { mode = "all" } = body;

  const projectRef = SUPABASE_URL.replace("https://", "").replace(".supabase.co", "");
  const dbHost = `db.${projectRef}.supabase.co`;

  const client = new Client({
    host: dbHost,
    port: 5432,
    database: "postgres",
    user: "postgres",
    password: SUPABASE_DB_PASSWORD,
    ssl: { rejectUnauthorized: false },
  });

  try {
    await client.connect();
    const results: string[] = [];

    // ── SCHEMA ──────────────────────────────────────────────
    if (mode === "schema" || mode === "all") {
      const ddl = [
        `CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`,

        `CREATE TABLE IF NOT EXISTS employees (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          full_name TEXT NOT NULL,
          contact_number TEXT,
          commission_percentage NUMERIC(5,2) NOT NULL DEFAULT 40,
          is_active BOOLEAN NOT NULL DEFAULT TRUE,
          avatar_color TEXT DEFAULT '#3B82F6',
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
        )`,

        `CREATE TABLE IF NOT EXISTS services (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          name TEXT NOT NULL,
          description TEXT,
          price NUMERIC(10,2) NOT NULL DEFAULT 0,
          is_active BOOLEAN NOT NULL DEFAULT TRUE,
          icon TEXT DEFAULT '🚿',
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
        )`,

        `CREATE TABLE IF NOT EXISTS car_washes (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          customer_name TEXT,
          plate_number TEXT,
          employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
          employee_name TEXT,
          services JSONB DEFAULT '[]',
          total_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
          amount_paid NUMERIC(10,2) DEFAULT 0,
          commission_rate NUMERIC(5,2) DEFAULT 0,
          commission_amount NUMERIC(10,2) DEFAULT 0,
          transaction_date TIMESTAMPTZ DEFAULT NOW(),
          notes TEXT,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
        )`,

        `CREATE TABLE IF NOT EXISTS car_wash_services (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          car_wash_id UUID REFERENCES car_washes(id) ON DELETE CASCADE,
          service_id UUID REFERENCES services(id) ON DELETE SET NULL,
          service_name TEXT,
          service_price NUMERIC(10,2) DEFAULT 0,
          created_at TIMESTAMPTZ DEFAULT NOW()
        )`,

        `CREATE TABLE IF NOT EXISTS reward_campaigns (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          campaign_name TEXT NOT NULL,
          month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
          year INTEGER NOT NULL,
          first_place_reward NUMERIC(10,2) DEFAULT 0,
          second_place_reward NUMERIC(10,2) DEFAULT 0,
          third_place_reward NUMERIC(10,2) DEFAULT 0,
          is_active BOOLEAN NOT NULL DEFAULT FALSE,
          description TEXT,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
        )`,

        `CREATE TABLE IF NOT EXISTS app_users (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          email TEXT UNIQUE NOT NULL,
          role TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('admin','staff')),
          is_active BOOLEAN NOT NULL DEFAULT TRUE,
          created_at TIMESTAMPTZ DEFAULT NOW()
        )`,

        `CREATE INDEX IF NOT EXISTS idx_cw_date   ON car_washes(transaction_date)`,
        `CREATE INDEX IF NOT EXISTS idx_cw_emp    ON car_washes(employee_id)`,
        `CREATE INDEX IF NOT EXISTS idx_cw_svc    ON car_wash_services(car_wash_id)`,
        `CREATE INDEX IF NOT EXISTS idx_emp_active ON employees(is_active)`,
        `CREATE INDEX IF NOT EXISTS idx_svc_active ON services(is_active)`,

        `CREATE OR REPLACE FUNCTION update_updated_at()
         RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql`,

        `DROP TRIGGER IF EXISTS trg_emp ON employees`,
        `CREATE TRIGGER trg_emp BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION update_updated_at()`,
        `DROP TRIGGER IF EXISTS trg_svc ON services`,
        `CREATE TRIGGER trg_svc BEFORE UPDATE ON services FOR EACH ROW EXECUTE FUNCTION update_updated_at()`,
        `DROP TRIGGER IF EXISTS trg_cw ON car_washes`,
        `CREATE TRIGGER trg_cw BEFORE UPDATE ON car_washes FOR EACH ROW EXECUTE FUNCTION update_updated_at()`,
        `DROP TRIGGER IF EXISTS trg_rc ON reward_campaigns`,
        `CREATE TRIGGER trg_rc BEFORE UPDATE ON reward_campaigns FOR EACH ROW EXECUTE FUNCTION update_updated_at()`,

        `CREATE OR REPLACE VIEW v_daily_performance AS
         SELECT e.id AS employee_id, e.full_name AS employee_name, e.avatar_color, e.commission_percentage,
           COUNT(cw.id) AS cars_washed,
           COALESCE(SUM(cw.total_amount),0) AS total_sales,
           COALESCE(SUM(cw.commission_amount),0) AS total_commission,
           CURRENT_DATE AS report_date
         FROM employees e
         LEFT JOIN car_washes cw ON cw.employee_id=e.id AND cw.transaction_date::date=CURRENT_DATE
         WHERE e.is_active=TRUE
         GROUP BY e.id,e.full_name,e.avatar_color,e.commission_percentage
         ORDER BY cars_washed DESC, total_sales DESC`,

        `CREATE OR REPLACE VIEW v_monthly_performance AS
         SELECT e.id AS employee_id, e.full_name AS employee_name, e.avatar_color, e.commission_percentage,
           COUNT(cw.id) AS cars_washed,
           COALESCE(SUM(cw.total_amount),0) AS total_sales,
           COALESCE(SUM(cw.commission_amount),0) AS total_commission,
           EXTRACT(MONTH FROM NOW())::INTEGER AS month,
           EXTRACT(YEAR FROM NOW())::INTEGER AS year
         FROM employees e
         LEFT JOIN car_washes cw ON cw.employee_id=e.id
           AND EXTRACT(MONTH FROM cw.transaction_date)=EXTRACT(MONTH FROM NOW())
           AND EXTRACT(YEAR FROM cw.transaction_date)=EXTRACT(YEAR FROM NOW())
         WHERE e.is_active=TRUE
         GROUP BY e.id,e.full_name,e.avatar_color,e.commission_percentage
         ORDER BY cars_washed DESC, total_sales DESC`,

        `CREATE OR REPLACE VIEW v_today_summary AS
         SELECT COUNT(*) AS total_cars,
           COALESCE(SUM(total_amount),0) AS total_sales,
           COALESCE(SUM(commission_amount),0) AS total_commission,
           COALESCE(AVG(total_amount),0) AS avg_sale,
           CURRENT_DATE AS summary_date
         FROM car_washes WHERE transaction_date::date=CURRENT_DATE`,
      ];

      for (const sql of ddl) {
        await client.query(sql);
        results.push(`✅ ${sql.trim().split("\n")[0].slice(0, 70)}`);
      }
    }

    // ── SEED ────────────────────────────────────────────────
    if (mode === "seed" || mode === "all") {
      await client.query(
        "TRUNCATE car_wash_services, car_washes, reward_campaigns, services, employees RESTART IDENTITY CASCADE"
      );

      await client.query(`
        INSERT INTO employees (id,full_name,contact_number,commission_percentage,is_active,avatar_color,created_at) VALUES
        ('11111111-0001-0000-0000-000000000001','John Doe','09171234567',40,TRUE,'#3B82F6','2026-05-31T14:39:33Z'),
        ('11111111-0002-0000-0000-000000000002','Mark Santos','09182345678',38,TRUE,'#10B981','2026-05-31T14:39:33Z'),
        ('11111111-0003-0000-0000-000000000003','Kevin Reyes','09193456789',35,TRUE,'#F59E0B','2026-05-31T14:39:33Z'),
        ('11111111-0004-0000-0000-000000000004','Ryan Cruz','09204567890',30,TRUE,'#84CC16','2026-05-31T14:39:33Z')
      `);
      results.push("✅ Seeded 4 employees");

      await client.query(`
        INSERT INTO services (id,name,description,price,is_active,icon,created_at) VALUES
        ('22222222-0001-0000-0000-000000000001','Basic Wash','Quick exterior rinse and soap wash',150,TRUE,'💧','2026-05-31T14:39:33Z'),
        ('22222222-0002-0000-0000-000000000002','Premium Wash','Full exterior wash with hand dry',250,TRUE,'✨','2026-05-31T14:39:33Z'),
        ('22222222-0003-0000-0000-000000000003','Interior Cleaning','Vacuuming and interior wipe down',200,TRUE,'🪑','2026-05-31T14:39:33Z'),
        ('22222222-0004-0000-0000-000000000004','Waxing','Full car wax for shine and protection',500,TRUE,'💎','2026-05-31T14:39:33Z'),
        ('22222222-0005-0000-0000-000000000005','Full Detailing','Complete interior and exterior detailing',1500,TRUE,'🏆','2026-05-31T14:39:33Z'),
        ('22222222-0006-0000-0000-000000000006','Engine Bay Cleaning','Degreasing and cleaning of engine bay',350,TRUE,'⚙️','2026-05-31T14:39:33Z'),
        ('22222222-0007-0000-0000-000000000007','Tire Shine','Tire dressing for glossy finish',100,TRUE,'🔄','2026-05-31T14:39:33Z')
      `);
      results.push("✅ Seeded 7 services");

      await client.query(`
        INSERT INTO car_washes (id,customer_name,plate_number,employee_id,employee_name,services,total_amount,amount_paid,commission_rate,commission_amount,transaction_date,created_at) VALUES
        ('33333333-0001-0000-0000-000000000001','Test 1','ABC123','11111111-0002-0000-0000-000000000002','Mark Santos','[{"id":"22222222-0001-0000-0000-000000000001","name":"Basic Wash","price":150}]',150,150,38,57,'2026-05-31T21:12:24Z','2026-05-31T21:12:26Z'),
        ('33333333-0002-0000-0000-000000000002','','KWZ123','11111111-0004-0000-0000-000000000004','Ryan Cruz','[{"id":"22222222-0005-0000-0000-000000000005","name":"Full Detailing","price":1500}]',1500,200,40,600,'2026-05-31T21:19:21Z','2026-05-31T21:19:21Z'),
        ('33333333-0003-0000-0000-000000000003','JJ','ZAF 125','11111111-0003-0000-0000-000000000003','Kevin Reyes','[{"id":"22222222-0006-0000-0000-000000000006","name":"Engine Bay Cleaning","price":350},{"id":"22222222-0001-0000-0000-000000000001","name":"Basic Wash","price":150}]',500,500,35,175,'2026-05-31T21:24:14Z','2026-05-31T21:24:15Z'),
        ('33333333-0004-0000-0000-000000000004','Gov','FAR 242','11111111-0004-0000-0000-000000000004','Ryan Cruz','[{"id":"22222222-0005-0000-0000-000000000005","name":"Full Detailing","price":1500},{"id":"22222222-0002-0000-0000-000000000002","name":"Premium Wash","price":250}]',1750,1750,30,525,'2026-05-31T21:26:04Z','2026-05-31T21:26:05Z')
      `);
      results.push("✅ Seeded 4 car wash transactions");

      await client.query(`
        INSERT INTO car_wash_services (car_wash_id,service_id,service_name,service_price) VALUES
        ('33333333-0001-0000-0000-000000000001','22222222-0001-0000-0000-000000000001','Basic Wash',150),
        ('33333333-0002-0000-0000-000000000002','22222222-0005-0000-0000-000000000005','Full Detailing',1500),
        ('33333333-0003-0000-0000-000000000003','22222222-0006-0000-0000-000000000006','Engine Bay Cleaning',350),
        ('33333333-0003-0000-0000-000000000003','22222222-0001-0000-0000-000000000001','Basic Wash',150),
        ('33333333-0004-0000-0000-000000000004','22222222-0005-0000-0000-000000000005','Full Detailing',1500),
        ('33333333-0004-0000-0000-000000000004','22222222-0002-0000-0000-000000000002','Premium Wash',250)
      `);
      results.push("✅ Seeded 6 car_wash_services rows");

      await client.query(`
        INSERT INTO reward_campaigns (id,campaign_name,month,year,first_place_reward,second_place_reward,third_place_reward,is_active,description,created_at) VALUES
        ('44444444-0001-0000-0000-000000000001','June 2026 Champions',6,2026,3000,2000,1000,TRUE,'Top performers for June 2026 get cash bonuses!','2026-05-31T14:39:33Z')
      `);
      results.push("✅ Seeded 1 reward campaign");

      await client.query(`INSERT INTO app_users (email,role) VALUES ('jjbalz1994@gmail.com','admin') ON CONFLICT (email) DO NOTHING`);
      results.push("✅ Seeded admin user");

      const verify = await client.query(`
        SELECT 'employees' AS t, COUNT(*)::int AS n FROM employees
        UNION ALL SELECT 'services', COUNT(*)::int FROM services
        UNION ALL SELECT 'car_washes', COUNT(*)::int FROM car_washes
        UNION ALL SELECT 'reward_campaigns', COUNT(*)::int FROM reward_campaigns
      `);
      results.push("📊 " + verify.rows.map((r: any) => `${r.t}=${r.n}`).join(" | "));
    }

    await client.end();
    return Response.json({ ok: true, results }, { headers: cors });

  } catch (err: any) {
    try { await client.end(); } catch {}
    return Response.json({ ok: false, error: err.message }, { status: 500, headers: cors });
  }
});
