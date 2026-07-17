-- ═══════════════════════════════════════════════════════════════
-- KG Staff: has_commission + payout_type columns
-- Generated: 2026-07-17
-- Run in: Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── 1. employees: flag for salaried staff who also earn commission ──
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS has_commission BOOLEAN DEFAULT false;

-- ── 2. commission_payouts: distinguish salary vs commission payouts ──
ALTER TABLE commission_payouts
  ADD COLUMN IF NOT EXISTS is_advance   BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS payout_type  TEXT DEFAULT 'commission'; -- 'salary' | 'commission'

-- Back-fill existing KG salary payouts that have no payout_type:
-- employees with salary_type != 'commission' had their payouts treated as salary
UPDATE commission_payouts cp
SET payout_type = 'salary'
WHERE cp.business_type = 'kgemployees'
  AND cp.payout_type IS NULL
  AND EXISTS (
    SELECT 1 FROM employees e
    WHERE e.id = cp.employee_id
      AND e.salary_type != 'commission'
      AND e.has_commission = false
  );

-- All other existing payouts stay as 'commission' (the DEFAULT handles new rows)
