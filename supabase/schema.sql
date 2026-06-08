-- ============================================================
--  🚗💦  CarWash Pro — Complete Supabase Schema
--  Colors: #1E1E22 | #2B2B31 | #D94A4A | #F7F7F7 | #D4AF37
--  Run in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- ── EXTENSIONS ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- ============================================================
--  1.  EMPLOYEES
-- ============================================================
CREATE TABLE IF NOT EXISTS employees (
  id                    UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name             TEXT        NOT NULL,
  contact_number        TEXT,
  commission_percentage NUMERIC(5,2) NOT NULL DEFAULT 40
                          CHECK (commission_percentage BETWEEN 0 AND 100),
  is_active             BOOLEAN     NOT NULL DEFAULT TRUE,
  avatar_color          TEXT        DEFAULT '#D94A4A',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  employees                       IS 'Car wash staff members';
COMMENT ON COLUMN employees.commission_percentage IS 'Percentage of transaction total paid as commission';

-- ============================================================
--  2.  SERVICES
-- ============================================================
CREATE TABLE IF NOT EXISTS services (
  id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT         NOT NULL,
  description TEXT,
  price       NUMERIC(10,2) NOT NULL DEFAULT 0
                CHECK (price >= 0),
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  icon        TEXT         DEFAULT '🚿',
  sort_order  INTEGER      DEFAULT 0,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE services IS 'Car wash service menu items';

-- ============================================================
--  3.  CAR WASHES  (main transaction table)
-- ============================================================
CREATE TABLE IF NOT EXISTS car_washes (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_name     TEXT,
  plate_number      TEXT,
  employee_id       UUID         REFERENCES employees(id) ON DELETE SET NULL,
  employee_name     TEXT         NOT NULL,
  -- denormalised snapshot of services at time of transaction
  services          JSONB        NOT NULL DEFAULT '[]',
  total_amount      NUMERIC(10,2) NOT NULL DEFAULT 0  CHECK (total_amount  >= 0),
  amount_paid       NUMERIC(10,2) NOT NULL DEFAULT 0  CHECK (amount_paid   >= 0),
  commission_rate   NUMERIC(5,2)  NOT NULL DEFAULT 0  CHECK (commission_rate BETWEEN 0 AND 100),
  commission_amount NUMERIC(10,2) NOT NULL DEFAULT 0  CHECK (commission_amount >= 0),
  transaction_date  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  notes             TEXT,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  car_washes          IS 'One row per car-wash transaction';
COMMENT ON COLUMN car_washes.services IS 'JSON snapshot: [{id, name, price}, ...]';

-- ============================================================
--  4.  CAR WASH ↔ SERVICES  (normalised junction)
-- ============================================================
CREATE TABLE IF NOT EXISTS car_wash_services (
  id            UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  car_wash_id   UUID         NOT NULL REFERENCES car_washes(id) ON DELETE CASCADE,
  service_id    UUID         REFERENCES services(id) ON DELETE SET NULL,
  service_name  TEXT         NOT NULL,
  service_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE car_wash_services IS 'Normalised line items per transaction';

-- ============================================================
--  5.  REWARD CAMPAIGNS
-- ============================================================
CREATE TABLE IF NOT EXISTS reward_campaigns (
  id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_name       TEXT         NOT NULL,
  month               SMALLINT     NOT NULL CHECK (month BETWEEN 1 AND 12),
  year                SMALLINT     NOT NULL CHECK (year  BETWEEN 2020 AND 2100),
  first_place_reward  NUMERIC(10,2) NOT NULL DEFAULT 0,
  second_place_reward NUMERIC(10,2) NOT NULL DEFAULT 0,
  third_place_reward  NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_active           BOOLEAN      NOT NULL DEFAULT FALSE,
  description         TEXT,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (month, year)   -- one campaign per month
);

COMMENT ON TABLE reward_campaigns IS 'Monthly top-performer reward definitions';

-- ============================================================
--  6.  APP USERS  (role-based access)
-- ============================================================
CREATE TABLE IF NOT EXISTS app_users (
  id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  email      TEXT        UNIQUE NOT NULL,
  full_name  TEXT,
  role       TEXT        NOT NULL DEFAULT 'staff'
               CHECK (role IN ('admin', 'manager', 'staff')),
  is_active  BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE app_users IS 'System users and their roles';

-- ============================================================
--  INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_cw_transaction_date  ON car_washes(transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_cw_employee_id       ON car_washes(employee_id);
CREATE INDEX IF NOT EXISTS idx_cw_date_emp          ON car_washes(transaction_date DESC, employee_id);
CREATE INDEX IF NOT EXISTS idx_cw_plate             ON car_washes(plate_number);
CREATE INDEX IF NOT EXISTS idx_cws_car_wash_id      ON car_wash_services(car_wash_id);
CREATE INDEX IF NOT EXISTS idx_cws_service_id       ON car_wash_services(service_id);
CREATE INDEX IF NOT EXISTS idx_emp_active           ON employees(is_active);
CREATE INDEX IF NOT EXISTS idx_svc_active           ON services(is_active);
CREATE INDEX IF NOT EXISTS idx_svc_sort             ON services(sort_order);
CREATE INDEX IF NOT EXISTS idx_campaign_month_year  ON reward_campaigns(year DESC, month DESC);
CREATE INDEX IF NOT EXISTS idx_campaign_active      ON reward_campaigns(is_active);

-- ============================================================
--  AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DO $$ BEGIN
  CREATE TRIGGER trg_employees_updated_at
    BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER trg_services_updated_at
    BEFORE UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER trg_car_washes_updated_at
    BEFORE UPDATE ON car_washes
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER trg_reward_campaigns_updated_at
    BEFORE UPDATE ON reward_campaigns
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TRIGGER trg_app_users_updated_at
    BEFORE UPDATE ON app_users
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
--  VIEWS
-- ============================================================

-- ── Daily leaderboard ───────────────────────────────────────
CREATE OR REPLACE VIEW v_daily_performance AS
SELECT
  e.id                                          AS employee_id,
  e.full_name                                   AS employee_name,
  e.avatar_color,
  e.commission_percentage,
  COUNT(cw.id)::INT                             AS cars_washed,
  COALESCE(SUM(cw.total_amount),    0)          AS total_sales,
  COALESCE(SUM(cw.commission_amount),0)         AS total_commission,
  COALESCE(SUM(cw.amount_paid),     0)          AS total_collected,
  CURRENT_DATE                                  AS report_date,
  RANK() OVER (ORDER BY COUNT(cw.id) DESC, SUM(cw.total_amount) DESC NULLS LAST) AS rank
FROM employees e
LEFT JOIN car_washes cw
  ON  cw.employee_id    = e.id
  AND cw.transaction_date::date = CURRENT_DATE
WHERE e.is_active = TRUE
GROUP BY e.id, e.full_name, e.avatar_color, e.commission_percentage;

-- ── Monthly leaderboard ─────────────────────────────────────
CREATE OR REPLACE VIEW v_monthly_performance AS
SELECT
  e.id                                          AS employee_id,
  e.full_name                                   AS employee_name,
  e.avatar_color,
  e.commission_percentage,
  COUNT(cw.id)::INT                             AS cars_washed,
  COALESCE(SUM(cw.total_amount),    0)          AS total_sales,
  COALESCE(SUM(cw.commission_amount),0)         AS total_commission,
  COALESCE(SUM(cw.amount_paid),     0)          AS total_collected,
  EXTRACT(MONTH FROM NOW())::SMALLINT           AS month,
  EXTRACT(YEAR  FROM NOW())::SMALLINT           AS year,
  RANK() OVER (ORDER BY COUNT(cw.id) DESC, SUM(cw.total_amount) DESC NULLS LAST) AS rank
FROM employees e
LEFT JOIN car_washes cw
  ON  cw.employee_id = e.id
  AND EXTRACT(MONTH FROM cw.transaction_date) = EXTRACT(MONTH FROM NOW())
  AND EXTRACT(YEAR  FROM cw.transaction_date) = EXTRACT(YEAR  FROM NOW())
WHERE e.is_active = TRUE
GROUP BY e.id, e.full_name, e.avatar_color, e.commission_percentage;

-- ── Today's dashboard summary ───────────────────────────────
CREATE OR REPLACE VIEW v_today_summary AS
SELECT
  COUNT(*)::INT                          AS total_cars,
  COALESCE(SUM(total_amount),   0)       AS total_sales,
  COALESCE(SUM(commission_amount),0)     AS total_commission,
  COALESCE(SUM(amount_paid),    0)       AS total_collected,
  COALESCE(AVG(total_amount),   0)       AS avg_sale,
  COALESCE(SUM(total_amount - amount_paid), 0) AS total_balance,
  CURRENT_DATE                           AS summary_date
FROM car_washes
WHERE transaction_date::date = CURRENT_DATE;

-- ── Monthly summary ─────────────────────────────────────────
CREATE OR REPLACE VIEW v_monthly_summary AS
SELECT
  EXTRACT(YEAR  FROM transaction_date)::SMALLINT  AS year,
  EXTRACT(MONTH FROM transaction_date)::SMALLINT  AS month,
  COUNT(*)::INT                                   AS total_cars,
  COALESCE(SUM(total_amount),    0)               AS total_sales,
  COALESCE(SUM(commission_amount),0)              AS total_commission,
  COALESCE(SUM(amount_paid),     0)               AS total_collected,
  COALESCE(AVG(total_amount),    0)               AS avg_sale
FROM car_washes
GROUP BY 1, 2
ORDER BY 1 DESC, 2 DESC;

-- ── Recent transactions (last 50) ───────────────────────────
CREATE OR REPLACE VIEW v_recent_transactions AS
SELECT
  cw.id,
  cw.transaction_date,
  cw.customer_name,
  cw.plate_number,
  cw.employee_name,
  cw.services,
  cw.total_amount,
  cw.amount_paid,
  (cw.total_amount - cw.amount_paid)  AS balance,
  cw.commission_rate,
  cw.commission_amount,
  cw.notes
FROM car_washes cw
ORDER BY cw.transaction_date DESC
LIMIT 50;

-- ============================================================
--  HELPER FUNCTIONS
-- ============================================================

-- Get employee stats for a custom date range
CREATE OR REPLACE FUNCTION fn_employee_stats(
  p_start DATE DEFAULT CURRENT_DATE,
  p_end   DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  employee_id         UUID,
  employee_name       TEXT,
  avatar_color        TEXT,
  cars_washed         BIGINT,
  total_sales         NUMERIC,
  total_commission    NUMERIC,
  rank                BIGINT
)
LANGUAGE sql STABLE AS $$
  SELECT
    e.id,
    e.full_name,
    e.avatar_color,
    COUNT(cw.id),
    COALESCE(SUM(cw.total_amount),0),
    COALESCE(SUM(cw.commission_amount),0),
    RANK() OVER (ORDER BY COUNT(cw.id) DESC, SUM(cw.total_amount) DESC NULLS LAST)
  FROM employees e
  LEFT JOIN car_washes cw
    ON  cw.employee_id = e.id
    AND cw.transaction_date::date BETWEEN p_start AND p_end
  WHERE e.is_active = TRUE
  GROUP BY e.id, e.full_name, e.avatar_color;
$$;

-- ============================================================
--  ROW LEVEL SECURITY  (uncomment when Supabase Auth is set up)
-- ============================================================
-- ALTER TABLE employees        ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE services         ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE car_washes       ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE car_wash_services ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE reward_campaigns ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE app_users        ENABLE ROW LEVEL SECURITY;
--
-- -- Allow admins full access
-- CREATE POLICY admin_all ON car_washes
--   USING (auth.jwt() ->> 'role' = 'admin');

-- ============================================================
--  VERIFY  (run after to confirm everything was created)
-- ============================================================
SELECT
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_name = t.table_name AND table_schema = 'public') AS column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
  AND table_type   = 'BASE TABLE'
ORDER BY table_name;

-- ============================================================
--  6.  COMMISSION PAYOUTS  (added 2026-06-01)
-- ============================================================
CREATE TABLE IF NOT EXISTS commission_payouts (
  id            UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id   UUID         REFERENCES employees(id) ON DELETE SET NULL,
  employee_name TEXT         NOT NULL,
  amount        NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  note          TEXT         DEFAULT 'Advance payout',
  payout_date   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE commission_payouts IS 'Tracks advance / full commission payouts per employee per month';

CREATE INDEX IF NOT EXISTS idx_comm_payouts_employee ON commission_payouts(employee_id);
CREATE INDEX IF NOT EXISTS idx_comm_payouts_date     ON commission_payouts(payout_date);

-- Trigger: auto-update updated_at
CREATE TRIGGER trg_commission_payouts_updated_at
  BEFORE UPDATE ON commission_payouts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
--  7.  ACTIVITY LOG  (added 2026-06-01)
-- ============================================================
CREATE TABLE IF NOT EXISTS activity_logs (
  id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_type  TEXT         NOT NULL,
  title       TEXT         NOT NULL,
  description TEXT,
  actor_name  TEXT,
  entity_id   UUID,
  amount      NUMERIC(10,2) DEFAULT 0,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_event  ON activity_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_activity_logs_date   ON activity_logs(created_at DESC);

COMMENT ON TABLE activity_logs IS 'Audit trail for all key events: washes, payouts, employee/service changes';

-- ═══════════════════════════════════════════════════════════
-- VULCANIZING MODULE — added 2026-06-09
-- ═══════════════════════════════════════════════════════════

-- Add business_type to employees (carwash | vulcanizing)
ALTER TABLE employees ADD COLUMN IF NOT EXISTS business_type TEXT NOT NULL DEFAULT 'carwash'
  CHECK (business_type IN ('carwash','vulcanizing'));

-- Add business_type to services
ALTER TABLE services ADD COLUMN IF NOT EXISTS business_type TEXT NOT NULL DEFAULT 'carwash'
  CHECK (business_type IN ('carwash','vulcanizing'));

-- Add business_type to reward_campaigns
ALTER TABLE reward_campaigns ADD COLUMN IF NOT EXISTS business_type TEXT NOT NULL DEFAULT 'carwash'
  CHECK (business_type IN ('carwash','vulcanizing'));

-- Add business_type to commission_payouts
ALTER TABLE commission_payouts ADD COLUMN IF NOT EXISTS business_type TEXT NOT NULL DEFAULT 'carwash'
  CHECK (business_type IN ('carwash','vulcanizing'));

-- ── Vulcanizing Products (manageable list, e.g. PP1 ₱30) ──
CREATE TABLE IF NOT EXISTS vulcanizing_products (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT         NOT NULL,
  default_cost      NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (default_cost >= 0),
  description       TEXT,
  is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE vulcanizing_products IS 'Products used in vulcanizing jobs (e.g. PP1, Sealant) with default costs deducted before commission calc';

CREATE TRIGGER trg_vulc_products_updated_at
  BEFORE UPDATE ON vulcanizing_products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── Vulcanizing Jobs (mirrors car_washes) ──
CREATE TABLE IF NOT EXISTS vulcanizing_jobs (
  id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name     TEXT,
  vehicle_info      TEXT,                          -- e.g. tire size, vehicle type
  employee_id       UUID         REFERENCES employees(id) ON DELETE SET NULL,
  employee_name     TEXT,
  employees         JSONB,                         -- array for multi-employee
  services          JSONB,                         -- array of service objects
  products_used     JSONB,                         -- array of {id,name,cost} — optional
  total_product_cost NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_amount      NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  net_amount        NUMERIC(10,2) NOT NULL DEFAULT 0, -- total_amount - total_product_cost
  amount_paid       NUMERIC(10,2) NOT NULL DEFAULT 0,
  commission_rate   NUMERIC(5,2)  NOT NULL DEFAULT 0,
  commission_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  commission_splits JSONB,                         -- multi-employee splits
  transaction_date  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  notes             TEXT,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE vulcanizing_jobs IS 'Vulcanizing transactions — commission is based on net_amount (after product costs)';

CREATE INDEX IF NOT EXISTS idx_vlc_employee_id ON vulcanizing_jobs(employee_id);
CREATE INDEX IF NOT EXISTS idx_vlc_date        ON vulcanizing_jobs(transaction_date DESC);

CREATE TRIGGER trg_vulc_jobs_updated_at
  BEFORE UPDATE ON vulcanizing_jobs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

