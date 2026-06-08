-- ═══════════════════════════════════════════════════════════════
-- KGCAR Carwash + KG Car Services (Vulcanizing) — Full Schema
-- Updated: 2026-06-09
-- Run this in: Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── Extensions ──
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ════════════════════════════════════════════
-- CAR WASH TABLES
-- ════════════════════════════════════════════

-- Employees (shared between both businesses)
CREATE TABLE IF NOT EXISTS employees (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name           TEXT NOT NULL,
  contact_number      TEXT,
  commission_percentage NUMERIC DEFAULT 40,
  is_active           BOOLEAN DEFAULT true,
  avatar_color        TEXT DEFAULT '#D94A4A',
  avatar_url          TEXT,
  business_type       TEXT DEFAULT 'carwash',  -- 'carwash' | 'vulcanizing'
  created_date        TIMESTAMPTZ DEFAULT now(),
  updated_date        TIMESTAMPTZ DEFAULT now()
);

-- Services (shared, distinguished by business_type)
CREATE TABLE IF NOT EXISTS services (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL,
  description     TEXT,
  price           NUMERIC DEFAULT 0,
  is_active       BOOLEAN DEFAULT true,
  icon            TEXT,
  business_type   TEXT DEFAULT 'carwash',  -- 'carwash' | 'vulcanizing'
  created_date    TIMESTAMPTZ DEFAULT now(),
  updated_date    TIMESTAMPTZ DEFAULT now()
);

-- Car Wash Transactions
CREATE TABLE IF NOT EXISTS car_washes (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_name     TEXT,
  plate_number      TEXT,
  employee_id       UUID REFERENCES employees(id) ON DELETE SET NULL,
  employee_name     TEXT,
  services          JSONB DEFAULT '[]',      -- array of service objects
  employees         JSONB DEFAULT '[]',      -- multi-employee array
  commission_splits JSONB DEFAULT '[]',      -- split details
  total_amount      NUMERIC DEFAULT 0,
  amount_paid       NUMERIC DEFAULT 0,
  commission_rate   NUMERIC DEFAULT 40,
  commission_amount NUMERIC DEFAULT 0,
  transaction_date  TIMESTAMPTZ DEFAULT now(),
  notes             TEXT,
  created_date      TIMESTAMPTZ DEFAULT now(),
  updated_date      TIMESTAMPTZ DEFAULT now()
);

-- Reward Campaigns
CREATE TABLE IF NOT EXISTS reward_campaigns (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_name         TEXT NOT NULL,
  month                 INTEGER,
  year                  INTEGER,
  first_place_reward    NUMERIC DEFAULT 3000,
  second_place_reward   NUMERIC DEFAULT 2000,
  third_place_reward    NUMERIC DEFAULT 1000,
  is_active             BOOLEAN DEFAULT false,
  description           TEXT,
  created_date          TIMESTAMPTZ DEFAULT now(),
  updated_date          TIMESTAMPTZ DEFAULT now()
);

-- Commission Payouts
CREATE TABLE IF NOT EXISTS commission_payouts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id     UUID REFERENCES employees(id) ON DELETE SET NULL,
  employee_name   TEXT,
  amount          NUMERIC DEFAULT 0,
  note            TEXT,
  payout_date     TIMESTAMPTZ DEFAULT now(),
  business_type   TEXT DEFAULT 'carwash',
  created_date    TIMESTAMPTZ DEFAULT now(),
  updated_date    TIMESTAMPTZ DEFAULT now()
);

-- Activity Logs
CREATE TABLE IF NOT EXISTS activity_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_type  TEXT,
  title       TEXT,
  description TEXT,
  actor_name  TEXT,
  entity_id   UUID,
  amount      NUMERIC,
  created_date TIMESTAMPTZ DEFAULT now(),
  updated_date TIMESTAMPTZ DEFAULT now()
);

-- ════════════════════════════════════════════
-- VULCANIZING TABLES
-- ════════════════════════════════════════════

-- Vulcanizing Products (PP1, Sealant, Valve, etc.)
CREATE TABLE IF NOT EXISTS vulcanizing_products (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT NOT NULL,
  default_cost  NUMERIC DEFAULT 0,
  description   TEXT,
  is_active     BOOLEAN DEFAULT true,
  created_date  TIMESTAMPTZ DEFAULT now(),
  updated_date  TIMESTAMPTZ DEFAULT now()
);

-- Vulcanizing Jobs
CREATE TABLE IF NOT EXISTS vulcanizing_jobs (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_name       TEXT,
  vehicle_info        TEXT,
  employee_id         UUID REFERENCES employees(id) ON DELETE SET NULL,
  employee_name       TEXT,
  employees           JSONB DEFAULT '[]',     -- multi-employee array
  services            JSONB DEFAULT '[]',     -- services array
  products_used       JSONB DEFAULT '[]',     -- products array with actual cost
  total_product_cost  NUMERIC DEFAULT 0,
  total_amount        NUMERIC DEFAULT 0,
  net_amount          NUMERIC DEFAULT 0,      -- total_amount - total_product_cost
  amount_paid         NUMERIC DEFAULT 0,
  commission_rate     NUMERIC DEFAULT 40,
  commission_amount   NUMERIC DEFAULT 0,      -- commission on net_amount
  commission_splits   JSONB DEFAULT '[]',     -- split details
  transaction_date    TIMESTAMPTZ DEFAULT now(),
  notes               TEXT,
  created_date        TIMESTAMPTZ DEFAULT now(),
  updated_date        TIMESTAMPTZ DEFAULT now()
);

-- ════════════════════════════════════════════
-- INDEXES (performance)
-- ════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_car_washes_employee    ON car_washes(employee_id);
CREATE INDEX IF NOT EXISTS idx_car_washes_date        ON car_washes(transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_vlc_jobs_employee      ON vulcanizing_jobs(employee_id);
CREATE INDEX IF NOT EXISTS idx_vlc_jobs_date          ON vulcanizing_jobs(transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_payouts_employee       ON commission_payouts(employee_id);
CREATE INDEX IF NOT EXISTS idx_employees_biz          ON employees(business_type);
CREATE INDEX IF NOT EXISTS idx_services_biz           ON services(business_type);

-- ════════════════════════════════════════════
-- SEED DATA
-- ════════════════════════════════════════════

-- Car Wash Employees
INSERT INTO employees (full_name, contact_number, commission_percentage, is_active, avatar_color, business_type) VALUES
  ('John Doe',  '09171234567', 40, true, '#D94A4A', 'carwash'),
  ('Mark Cruz', '09182345678', 40, true, '#22C55E', 'carwash'),
  ('Kevin Tan', '09193456789', 40, true, '#D4AF37', 'carwash'),
  ('Ryan Lim',  '09204567890', 40, true, '#6C63FF', 'carwash')
ON CONFLICT DO NOTHING;

-- Vulcanizing Employees (add your own names here)
-- INSERT INTO employees (full_name, commission_percentage, is_active, avatar_color, business_type) VALUES
--   ('Pedro Santos', 40, true, '#E91E8C', 'vulcanizing');

-- Car Wash Services
INSERT INTO services (name, description, price, is_active, business_type) VALUES
  ('Regular Wash',   'Standard exterior wash',              150, true,  'carwash'),
  ('Premium Wash',   'Full exterior & interior cleaning',   350, true,  'carwash'),
  ('Engine Wash',    'Engine bay cleaning',                 500, true,  'carwash'),
  ('Undercarriage',  'Undercarriage pressure wash',         200, true,  'carwash'),
  ('Wax & Polish',   'Hand wax and paint polish',           400, true,  'carwash'),
  ('Interior Clean', 'Full interior vacuum & wipe-down',    300, true,  'carwash'),
  ('Full Detail',    'Complete inside and outside detail', 1200, true,  'carwash')
ON CONFLICT DO NOTHING;

-- Vulcanizing Services
INSERT INTO services (name, description, price, is_active, business_type) VALUES
  ('Tire Repair / Patching', 'Standard tire repair and patching',   120, true, 'vulcanizing'),
  ('Valve Replacement',      'Tire valve stem replacement',          80, true, 'vulcanizing'),
  ('Balancing',              'Tire balancing service',              150, true, 'vulcanizing'),
  ('Nitrogen (Nitro) Fill',  'Nitrogen tire inflation',             100, true, 'vulcanizing'),
  ('Tire Mounting',          'Tire mounting and fitting',           200, true, 'vulcanizing')
ON CONFLICT DO NOTHING;

-- Vulcanizing Products
INSERT INTO vulcanizing_products (name, default_cost, description, is_active) VALUES
  ('PP1 (Puncture Patch)', 30, 'Standard rubber puncture patch', true),
  ('Sealant',              50, 'Tire sealant liquid',            true),
  ('Valve Stem',           25, 'Replacement valve stem',         true),
  ('Patch Kit (Large)',    60, 'Large sidewall patch kit',       true),
  ('Rim Tape',             40, 'Rim protective tape',            true)
ON CONFLICT DO NOTHING;

-- Reward Campaign
INSERT INTO reward_campaigns (campaign_name, month, year, first_place_reward, second_place_reward, third_place_reward, is_active, description) VALUES
  ('June 2026 Champions', 6, 2026, 3000, 2000, 1000, true, 'Monthly performance reward for top car wash staff')
ON CONFLICT DO NOTHING;

