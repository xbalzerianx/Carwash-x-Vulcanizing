-- ═══════════════════════════════════════════════════════════════
-- KG Employees (KG Staff) module — schema catch-up
-- Generated: 2026-07-03
-- Run in: Supabase Dashboard → SQL Editor
-- Adds the employee salary columns + KgWorkOrder/KgAbsence tables
-- used by the KG Staff tab (monthly / weekly / custom / commission
-- based employees), including the new weekly & custom pay-period
-- support (rate_basis + period_days).
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Employee salary columns ──
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS monthly_rate           NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS salary_type            TEXT DEFAULT 'commission', -- commission | monthly | weekly | custom
  ADD COLUMN IF NOT EXISTS rate_basis             TEXT DEFAULT 'total',      -- total (period total) | daily (daily rate, period total derived)
  ADD COLUMN IF NOT EXISTS period_days            INTEGER DEFAULT 7,        -- only used when salary_type='custom'
  ADD COLUMN IF NOT EXISTS employment_start_date  DATE;                     -- pay-cycle anchor / reset date

-- ── 2. Manual commission work orders (KG Staff, commission-based) ──
CREATE TABLE IF NOT EXISTS kg_work_orders (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id       UUID REFERENCES employees(id) ON DELETE SET NULL,
  employee_name     TEXT,
  work_description  TEXT,
  work_amount       NUMERIC DEFAULT 0,   -- total job/order value
  worker_commission NUMERIC DEFAULT 0,   -- manually entered commission for this job
  notes             TEXT,
  transaction_date  DATE DEFAULT CURRENT_DATE,
  created_date      TIMESTAMPTZ DEFAULT now(),
  updated_date      TIMESTAMPTZ DEFAULT now()
);

-- ── 3. Absence records (KG Staff, monthly/weekly/custom salaried) ──
CREATE TABLE IF NOT EXISTS kg_absences (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id   UUID REFERENCES employees(id) ON DELETE SET NULL,
  employee_name TEXT,
  absent_date   DATE NOT NULL,
  note          TEXT,
  created_date  TIMESTAMPTZ DEFAULT now(),
  updated_date  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kg_work_orders_emp ON kg_work_orders(employee_id);
CREATE INDEX IF NOT EXISTS idx_kg_absences_emp    ON kg_absences(employee_id);
