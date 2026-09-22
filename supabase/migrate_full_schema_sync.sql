-- ═══════════════════════════════════════════════════════════════
-- KG Car Services — FULL SCHEMA SYNC (bring Supabase up to date
-- with the real Base44 data model, add missing tables/columns,
-- and open safe direct access so the app can query Supabase
-- WITHOUT going through Base44's backend anymore).
--
-- IMPORTANT: all IDs are TEXT (not UUID) because the real historical
-- data being migrated uses Base44's existing string IDs, and many
-- records (commission_splits, employees[] arrays, etc.) reference
-- those exact IDs. Keeping them as TEXT preserves every relationship
-- without having to remap thousands of records.
--
-- Run this ONCE in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to re-run — every statement is idempotent (IF NOT EXISTS / OR REPLACE).
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop old leftover dashboard views from the original setup — they are not
-- used anywhere in the current app (all aggregation happens client-side in
-- JS) and they block the employee_id/id TEXT conversions below because
-- Postgres won't change a column type a view still depends on.
DROP VIEW IF EXISTS v_today_summary CASCADE;
DROP VIEW IF EXISTS v_daily_performance CASCADE;
DROP VIEW IF EXISTS v_monthly_performance CASCADE;
DROP VIEW IF EXISTS v_monthly_summary CASCADE;
DROP VIEW IF EXISTS v_recent_transactions CASCADE;

-- Also quiet the two "Function Search Path Mutable" advisories from the
-- original setup by pinning a fixed search_path on those functions.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname IN ('fn_set_updated_at','fn_employee_stats')
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public;', r.sig);
  END LOOP;
END $$;

-- Drop any old foreign-key constraints tying employee_id/id columns to a
-- UUID-typed employees.id, so the TEXT-id conversions below don't fail.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT conname, conrelid::regclass AS tbl
    FROM pg_constraint
    WHERE contype = 'f'
      AND confrelid = 'employees'::regclass
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I;', r.tbl, r.conname);
  END LOOP;
EXCEPTION WHEN undefined_table THEN
  NULL; -- employees table doesn't exist yet on a brand-new project, fine
END $$;

-- ── EMPLOYEES ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employees (
  id                     TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  full_name              TEXT NOT NULL,
  contact_number         TEXT,
  commission_percentage  NUMERIC DEFAULT 0,
  is_active              BOOLEAN DEFAULT true,
  avatar_color           TEXT DEFAULT '#D94A4A',
  avatar_url             TEXT,
  business_type          TEXT DEFAULT 'carwash',
  monthly_rate           NUMERIC DEFAULT 0,
  salary_type            TEXT,
  rate_basis             TEXT,
  period_days            INTEGER,
  employment_start_date  DATE,
  has_commission         BOOLEAN DEFAULT false,
  created_by             TEXT,
  created_date           TIMESTAMPTZ DEFAULT now(),
  updated_date           TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE employees ADD COLUMN IF NOT EXISTS monthly_rate NUMERIC DEFAULT 0;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS salary_type TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS rate_basis TEXT;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS period_days INTEGER;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS employment_start_date DATE;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS has_commission BOOLEAN DEFAULT false;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS created_by TEXT;

-- ── SERVICES ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS services (
  id             TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name           TEXT NOT NULL,
  description    TEXT,
  price          NUMERIC DEFAULT 0,
  is_active      BOOLEAN DEFAULT true,
  icon           TEXT,
  business_type  TEXT DEFAULT 'carwash',
  created_by     TEXT,
  created_date   TIMESTAMPTZ DEFAULT now(),
  updated_date   TIMESTAMPTZ DEFAULT now()
);

-- ── CAR WASH TRANSACTIONS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS car_washes (
  id                 TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  customer_name      TEXT,
  plate_number       TEXT,
  employee_id        TEXT,
  employee_name      TEXT,
  services           JSONB DEFAULT '[]',
  products_used      JSONB DEFAULT '[]',
  employees          JSONB DEFAULT '[]',
  commission_splits  JSONB DEFAULT '[]',
  total_amount       NUMERIC DEFAULT 0,
  amount_paid        NUMERIC DEFAULT 0,
  payment_status     TEXT DEFAULT 'paid',
  commission_rate    NUMERIC DEFAULT 0,
  commission_amount  NUMERIC DEFAULT 0,
  transaction_date   TIMESTAMPTZ DEFAULT now(),
  notes              TEXT,
  created_by         TEXT,
  created_date       TIMESTAMPTZ DEFAULT now(),
  updated_date       TIMESTAMPTZ DEFAULT now()
);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='car_washes' AND column_name='employee_id' AND data_type='uuid') THEN
    ALTER TABLE car_washes ALTER COLUMN employee_id TYPE TEXT;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='car_washes' AND column_name='id' AND data_type='uuid') THEN
    ALTER TABLE car_washes ALTER COLUMN id TYPE TEXT, ALTER COLUMN id DROP DEFAULT;
    ALTER TABLE car_washes ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  END IF;
END $$;
ALTER TABLE car_washes ADD COLUMN IF NOT EXISTS products_used JSONB DEFAULT '[]';
ALTER TABLE car_washes ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'paid';
ALTER TABLE car_washes ADD COLUMN IF NOT EXISTS created_by TEXT;

-- ── REWARD CAMPAIGNS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reward_campaigns (
  id                   TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  campaign_name        TEXT NOT NULL,
  month                INTEGER,
  year                 INTEGER,
  first_place_reward   NUMERIC DEFAULT 3000,
  second_place_reward  NUMERIC DEFAULT 2000,
  third_place_reward   NUMERIC DEFAULT 1000,
  is_active            BOOLEAN DEFAULT false,
  description          TEXT,
  created_by           TEXT,
  created_date         TIMESTAMPTZ DEFAULT now(),
  updated_date         TIMESTAMPTZ DEFAULT now()
);

-- ── COMMISSION / SALARY PAYOUTS ────────────────────────────────
CREATE TABLE IF NOT EXISTS commission_payouts (
  id             TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  employee_id    TEXT,
  employee_name  TEXT,
  amount         NUMERIC DEFAULT 0,
  note           TEXT,
  payout_date    TIMESTAMPTZ DEFAULT now(),
  is_advance     BOOLEAN DEFAULT false,
  business_type  TEXT DEFAULT 'carwash',
  payout_type    TEXT DEFAULT 'commission',
  created_by     TEXT,
  created_date   TIMESTAMPTZ DEFAULT now(),
  updated_date   TIMESTAMPTZ DEFAULT now()
);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='commission_payouts' AND column_name='employee_id' AND data_type='uuid') THEN
    ALTER TABLE commission_payouts ALTER COLUMN employee_id TYPE TEXT;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='commission_payouts' AND column_name='id' AND data_type='uuid') THEN
    ALTER TABLE commission_payouts ALTER COLUMN id TYPE TEXT, ALTER COLUMN id DROP DEFAULT;
    ALTER TABLE commission_payouts ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  END IF;
END $$;
ALTER TABLE commission_payouts ADD COLUMN IF NOT EXISTS is_advance BOOLEAN DEFAULT false;
ALTER TABLE commission_payouts ADD COLUMN IF NOT EXISTS payout_type TEXT DEFAULT 'commission';
ALTER TABLE commission_payouts ADD COLUMN IF NOT EXISTS created_by TEXT;

-- ── ACTIVITY LOG (centralized audit trail) ─────────────────────
CREATE TABLE IF NOT EXISTS activity_logs (
  id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  event_type    TEXT,
  title         TEXT,
  description   TEXT,
  actor_name    TEXT,
  entity_id     TEXT,
  amount        NUMERIC,
  created_by    TEXT,
  created_date  TIMESTAMPTZ DEFAULT now(),
  updated_date  TIMESTAMPTZ DEFAULT now()
);

-- ── VULCANIZING PRODUCTS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vulcanizing_products (
  id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name          TEXT NOT NULL,
  price         NUMERIC DEFAULT 0,
  default_cost  NUMERIC DEFAULT 0,
  description   TEXT,
  is_active     BOOLEAN DEFAULT true,
  stock         NUMERIC DEFAULT 0,
  created_by    TEXT,
  created_date  TIMESTAMPTZ DEFAULT now(),
  updated_date  TIMESTAMPTZ DEFAULT now()
);

-- ── VULCANIZING JOBS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vulcanizing_jobs (
  id                   TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  customer_name        TEXT,
  vehicle_info         TEXT,
  employee_id          TEXT,
  employee_name        TEXT,
  employees            JSONB DEFAULT '[]',
  services             JSONB DEFAULT '[]',
  products_used        JSONB DEFAULT '[]',
  total_product_cost   NUMERIC DEFAULT 0,
  total_amount         NUMERIC DEFAULT 0,
  net_amount           NUMERIC DEFAULT 0,
  amount_paid          NUMERIC DEFAULT 0,
  payment_status       TEXT DEFAULT 'paid',
  commission_rate      NUMERIC DEFAULT 0,
  commission_amount    NUMERIC DEFAULT 0,
  commission_splits    JSONB DEFAULT '[]',
  transaction_date     TIMESTAMPTZ DEFAULT now(),
  notes                TEXT,
  created_by           TEXT,
  created_date         TIMESTAMPTZ DEFAULT now(),
  updated_date         TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE vulcanizing_jobs ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'paid';
ALTER TABLE vulcanizing_jobs ADD COLUMN IF NOT EXISTS created_by TEXT;

-- ── KG WORK ORDERS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS kg_work_orders (
  id                  TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  employee_id         TEXT,
  employee_name       TEXT,
  work_description    TEXT,
  work_amount         NUMERIC DEFAULT 0,
  worker_commission   NUMERIC DEFAULT 0,
  products_used       JSONB DEFAULT '[]',
  notes               TEXT,
  transaction_date    TIMESTAMPTZ DEFAULT now(),
  created_by          TEXT,
  created_date        TIMESTAMPTZ DEFAULT now(),
  updated_date        TIMESTAMPTZ DEFAULT now()
);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='kg_work_orders' AND column_name='employee_id' AND data_type='uuid') THEN
    ALTER TABLE kg_work_orders ALTER COLUMN employee_id TYPE TEXT;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='kg_work_orders' AND column_name='id' AND data_type='uuid') THEN
    ALTER TABLE kg_work_orders ALTER COLUMN id TYPE TEXT, ALTER COLUMN id DROP DEFAULT;
    ALTER TABLE kg_work_orders ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  END IF;
END $$;
ALTER TABLE kg_work_orders ADD COLUMN IF NOT EXISTS products_used JSONB DEFAULT '[]';
ALTER TABLE kg_work_orders ADD COLUMN IF NOT EXISTS created_by TEXT;

-- ── KG ABSENCES ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS kg_absences (
  id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  employee_id   TEXT,
  employee_name TEXT,
  absent_date   DATE,
  note          TEXT,
  created_by    TEXT,
  created_date  TIMESTAMPTZ DEFAULT now(),
  updated_date  TIMESTAMPTZ DEFAULT now()
);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='kg_absences' AND column_name='employee_id' AND data_type='uuid') THEN
    ALTER TABLE kg_absences ALTER COLUMN employee_id TYPE TEXT;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='kg_absences' AND column_name='id' AND data_type='uuid') THEN
    ALTER TABLE kg_absences ALTER COLUMN id TYPE TEXT, ALTER COLUMN id DROP DEFAULT;
    ALTER TABLE kg_absences ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  END IF;
END $$;

-- Also loosen employees.id to TEXT if it was created as UUID in an earlier run
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='employees' AND column_name='id' AND data_type='uuid') THEN
    ALTER TABLE employees ALTER COLUMN id TYPE TEXT, ALTER COLUMN id DROP DEFAULT;
    ALTER TABLE employees ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='services' AND column_name='id' AND data_type='uuid') THEN
    ALTER TABLE services ALTER COLUMN id TYPE TEXT, ALTER COLUMN id DROP DEFAULT;
    ALTER TABLE services ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='reward_campaigns' AND column_name='id' AND data_type='uuid') THEN
    ALTER TABLE reward_campaigns ALTER COLUMN id TYPE TEXT, ALTER COLUMN id DROP DEFAULT;
    ALTER TABLE reward_campaigns ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  END IF;
END $$;

-- ── INDEXES ─────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_car_washes_employee   ON car_washes(employee_id);
CREATE INDEX IF NOT EXISTS idx_car_washes_date        ON car_washes(transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_vlc_jobs_employee      ON vulcanizing_jobs(employee_id);
CREATE INDEX IF NOT EXISTS idx_vlc_jobs_date          ON vulcanizing_jobs(transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_payouts_employee       ON commission_payouts(employee_id);
CREATE INDEX IF NOT EXISTS idx_kg_wo_employee         ON kg_work_orders(employee_id);
CREATE INDEX IF NOT EXISTS idx_kg_abs_employee        ON kg_absences(employee_id);
CREATE INDEX IF NOT EXISTS idx_employees_biz          ON employees(business_type);
CREATE INDEX IF NOT EXISTS idx_services_biz           ON services(business_type);
CREATE INDEX IF NOT EXISTS idx_activity_logs_date     ON activity_logs(created_date DESC);

-- ── ROW LEVEL SECURITY ──────────────────────────────────────────
-- The app will talk to Supabase directly with the public "anon" key
-- (no Base44 backend in between) and keeps its own PIN gate
-- client-side — same effective security model as today. These
-- policies let the anon key read/write every table so the app works.
ALTER TABLE employees            ENABLE ROW LEVEL SECURITY;
ALTER TABLE services             ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_washes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_campaigns     ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_payouts   ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs        ENABLE ROW LEVEL SECURITY;
ALTER TABLE vulcanizing_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE vulcanizing_jobs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE kg_work_orders       ENABLE ROW LEVEL SECURITY;
ALTER TABLE kg_absences          ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['employees','services','car_washes','reward_campaigns',
    'commission_payouts','activity_logs','vulcanizing_products','vulcanizing_jobs',
    'kg_work_orders','kg_absences']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS anon_full_access ON %I;', t);
    EXECUTE format('CREATE POLICY anon_full_access ON %I FOR ALL USING (true) WITH CHECK (true);', t);
  END LOOP;
END $$;

-- Done. Once this finishes without errors, tell Carwash "schema is ready"
-- and the full data migration + app switch-over can proceed.
