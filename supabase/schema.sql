-- ============================================================
-- 🚗💦 CarWash Pro — Supabase Schema
-- Run this in Supabase SQL Editor > New Query
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. EMPLOYEES
-- ============================================================
CREATE TABLE IF NOT EXISTS employees (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name             TEXT NOT NULL,
  contact_number        TEXT,
  commission_percentage NUMERIC(5,2) NOT NULL DEFAULT 40,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  avatar_color          TEXT DEFAULT '#3B82F6',
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. SERVICES
-- ============================================================
CREATE TABLE IF NOT EXISTS services (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  description TEXT,
  price       NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  icon        TEXT DEFAULT '🚿',
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. CAR WASHES (Transactions)
-- ============================================================
CREATE TABLE IF NOT EXISTS car_washes (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_name    TEXT,
  plate_number     TEXT,
  employee_id      UUID REFERENCES employees(id) ON DELETE SET NULL,
  employee_name    TEXT,
  services         JSONB DEFAULT '[]',       -- array of {id, name, price}
  total_amount     NUMERIC(10,2) NOT NULL DEFAULT 0,
  amount_paid      NUMERIC(10,2) DEFAULT 0,
  commission_rate  NUMERIC(5,2) DEFAULT 0,
  commission_amount NUMERIC(10,2) DEFAULT 0,
  transaction_date TIMESTAMPTZ DEFAULT NOW(),
  notes            TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. CAR WASH SERVICES (Junction table — future expansion)
-- ============================================================
CREATE TABLE IF NOT EXISTS car_wash_services (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  car_wash_id   UUID REFERENCES car_washes(id) ON DELETE CASCADE,
  service_id    UUID REFERENCES services(id) ON DELETE SET NULL,
  service_name  TEXT,
  service_price NUMERIC(10,2) DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. REWARD CAMPAIGNS
-- ============================================================
CREATE TABLE IF NOT EXISTS reward_campaigns (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_name        TEXT NOT NULL,
  month                INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  year                 INTEGER NOT NULL,
  first_place_reward   NUMERIC(10,2) DEFAULT 0,
  second_place_reward  NUMERIC(10,2) DEFAULT 0,
  third_place_reward   NUMERIC(10,2) DEFAULT 0,
  is_active            BOOLEAN NOT NULL DEFAULT FALSE,
  description          TEXT,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. USERS (for future auth — role-based access)
-- ============================================================
CREATE TABLE IF NOT EXISTS app_users (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email      TEXT UNIQUE NOT NULL,
  role       TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('admin', 'staff')),
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES — for fast dashboard queries
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_car_washes_transaction_date ON car_washes(transaction_date);
CREATE INDEX IF NOT EXISTS idx_car_washes_employee_id      ON car_washes(employee_id);
CREATE INDEX IF NOT EXISTS idx_car_washes_date_emp         ON car_washes(transaction_date, employee_id);
CREATE INDEX IF NOT EXISTS idx_car_wash_services_wash_id   ON car_wash_services(car_wash_id);
CREATE INDEX IF NOT EXISTS idx_employees_is_active         ON employees(is_active);
CREATE INDEX IF NOT EXISTS idx_services_is_active          ON services(is_active);
CREATE INDEX IF NOT EXISTS idx_campaigns_is_active         ON reward_campaigns(is_active);

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_employees_updated_at
  BEFORE UPDATE ON employees
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_services_updated_at
  BEFORE UPDATE ON services
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_car_washes_updated_at
  BEFORE UPDATE ON car_washes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_reward_campaigns_updated_at
  BEFORE UPDATE ON reward_campaigns
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- VIEWS — pre-built for dashboard & rankings
-- ============================================================

-- Daily employee performance
CREATE OR REPLACE VIEW v_daily_performance AS
SELECT
  e.id                                        AS employee_id,
  e.full_name                                 AS employee_name,
  e.avatar_color,
  e.commission_percentage,
  COUNT(cw.id)                                AS cars_washed,
  COALESCE(SUM(cw.total_amount), 0)           AS total_sales,
  COALESCE(SUM(cw.commission_amount), 0)      AS total_commission,
  CURRENT_DATE                                AS report_date
FROM employees e
LEFT JOIN car_washes cw
  ON cw.employee_id = e.id
  AND cw.transaction_date::date = CURRENT_DATE
WHERE e.is_active = TRUE
GROUP BY e.id, e.full_name, e.avatar_color, e.commission_percentage
ORDER BY cars_washed DESC, total_sales DESC;

-- Monthly employee performance
CREATE OR REPLACE VIEW v_monthly_performance AS
SELECT
  e.id                                        AS employee_id,
  e.full_name                                 AS employee_name,
  e.avatar_color,
  e.commission_percentage,
  COUNT(cw.id)                                AS cars_washed,
  COALESCE(SUM(cw.total_amount), 0)           AS total_sales,
  COALESCE(SUM(cw.commission_amount), 0)      AS total_commission,
  EXTRACT(MONTH FROM NOW())::INTEGER          AS month,
  EXTRACT(YEAR  FROM NOW())::INTEGER          AS year
FROM employees e
LEFT JOIN car_washes cw
  ON cw.employee_id = e.id
  AND EXTRACT(MONTH FROM cw.transaction_date) = EXTRACT(MONTH FROM NOW())
  AND EXTRACT(YEAR  FROM cw.transaction_date) = EXTRACT(YEAR  FROM NOW())
WHERE e.is_active = TRUE
GROUP BY e.id, e.full_name, e.avatar_color, e.commission_percentage
ORDER BY cars_washed DESC, total_sales DESC;

-- Today's dashboard summary
CREATE OR REPLACE VIEW v_today_summary AS
SELECT
  COUNT(*)                                    AS total_cars,
  COALESCE(SUM(total_amount), 0)              AS total_sales,
  COALESCE(SUM(commission_amount), 0)         AS total_commission,
  COALESCE(AVG(total_amount), 0)              AS avg_sale,
  CURRENT_DATE                                AS summary_date
FROM car_washes
WHERE transaction_date::date = CURRENT_DATE;

-- ============================================================
-- ROW LEVEL SECURITY (RLS) — enable for production
-- ============================================================
-- ALTER TABLE employees        ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE services         ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE car_washes       ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE reward_campaigns ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE app_users        ENABLE ROW LEVEL SECURITY;
-- (Uncomment after setting up Supabase Auth policies)
