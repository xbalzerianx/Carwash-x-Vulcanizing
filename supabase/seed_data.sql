-- ============================================================
-- 🚗💦 CarWash Pro — Seed Data
-- Run AFTER schema.sql
-- This inserts all current data from Base44 into Supabase
-- ============================================================

-- Clear existing data (safe re-run)
TRUNCATE car_wash_services, car_washes, reward_campaigns, services, employees
  RESTART IDENTITY CASCADE;

-- ============================================================
-- EMPLOYEES
-- ============================================================
INSERT INTO employees (id, full_name, contact_number, commission_percentage, is_active, avatar_color, created_at) VALUES
  ('11111111-0001-0000-0000-000000000001', 'John Doe',    '09171234567', 40, TRUE, '#3B82F6', '2026-05-31T14:39:33Z'),
  ('11111111-0002-0000-0000-000000000002', 'Mark Santos', '09182345678', 38, TRUE, '#10B981', '2026-05-31T14:39:33Z'),
  ('11111111-0003-0000-0000-000000000003', 'Kevin Reyes', '09193456789', 35, TRUE, '#F59E0B', '2026-05-31T14:39:33Z'),
  ('11111111-0004-0000-0000-000000000004', 'Ryan Cruz',   '09204567890', 30, TRUE, '#84CC16', '2026-05-31T14:39:33Z');

-- ============================================================
-- SERVICES
-- ============================================================
INSERT INTO services (id, name, description, price, is_active, icon, created_at) VALUES
  ('22222222-0001-0000-0000-000000000001', 'Basic Wash',         'Quick exterior rinse and soap wash',       150,  TRUE, '💧', '2026-05-31T14:39:33Z'),
  ('22222222-0002-0000-0000-000000000002', 'Premium Wash',       'Full exterior wash with hand dry',          250,  TRUE, '✨', '2026-05-31T14:39:33Z'),
  ('22222222-0003-0000-0000-000000000003', 'Interior Cleaning',  'Vacuuming and interior wipe down',          200,  TRUE, '🪑', '2026-05-31T14:39:33Z'),
  ('22222222-0004-0000-0000-000000000004', 'Waxing',             'Full car wax for shine and protection',     500,  TRUE, '💎', '2026-05-31T14:39:33Z'),
  ('22222222-0005-0000-0000-000000000005', 'Full Detailing',     'Complete interior and exterior detailing',  1500, TRUE, '🏆', '2026-05-31T14:39:33Z'),
  ('22222222-0006-0000-0000-000000000006', 'Engine Bay Cleaning','Degreasing and cleaning of engine bay',     350,  TRUE, '⚙️', '2026-05-31T14:39:33Z'),
  ('22222222-0007-0000-0000-000000000007', 'Tire Shine',         'Tire dressing for glossy finish',           100,  TRUE, '🔄', '2026-05-31T14:39:33Z');

-- ============================================================
-- CAR WASHES (Transactions)
-- ============================================================
INSERT INTO car_washes (id, customer_name, plate_number, employee_id, employee_name, services, total_amount, amount_paid, commission_rate, commission_amount, transaction_date, created_at) VALUES

  -- Transaction 1: Mark Santos — Basic Wash
  ('33333333-0001-0000-0000-000000000001',
   'Test 1', 'ABC123',
   '11111111-0002-0000-0000-000000000002', 'Mark Santos',
   '[{"id":"22222222-0001-0000-0000-000000000001","name":"Basic Wash","price":150}]',
   150, 150, 38, 57,
   '2026-05-31T21:12:24Z', '2026-05-31T21:12:26Z'),

  -- Transaction 2: Ryan Cruz — Full Detailing
  ('33333333-0002-0000-0000-000000000002',
   '', 'KWZ123',
   '11111111-0004-0000-0000-000000000004', 'Ryan Cruz',
   '[{"id":"22222222-0005-0000-0000-000000000005","name":"Full Detailing","price":1500}]',
   1500, 200, 40, 600,
   '2026-05-31T21:19:21Z', '2026-05-31T21:19:21Z'),

  -- Transaction 3: Kevin Reyes — Engine Bay + Basic Wash
  ('33333333-0003-0000-0000-000000000003',
   'JJ', 'ZAF 125',
   '11111111-0003-0000-0000-000000000003', 'Kevin Reyes',
   '[{"id":"22222222-0006-0000-0000-000000000006","name":"Engine Bay Cleaning","price":350},{"id":"22222222-0001-0000-0000-000000000001","name":"Basic Wash","price":150}]',
   500, 500, 35, 175,
   '2026-05-31T21:24:14Z', '2026-05-31T21:24:15Z'),

  -- Transaction 4: Ryan Cruz — Full Detailing + Premium Wash
  ('33333333-0004-0000-0000-000000000004',
   'Gov', 'FAR 242',
   '11111111-0004-0000-0000-000000000004', 'Ryan Cruz',
   '[{"id":"22222222-0005-0000-0000-000000000005","name":"Full Detailing","price":1500},{"id":"22222222-0002-0000-0000-000000000002","name":"Premium Wash","price":250}]',
   1750, 1750, 30, 525,
   '2026-05-31T21:26:04Z', '2026-05-31T21:26:05Z');

-- ============================================================
-- CAR WASH SERVICES (junction table — populated from above)
-- ============================================================
INSERT INTO car_wash_services (car_wash_id, service_id, service_name, service_price) VALUES
  ('33333333-0001-0000-0000-000000000001', '22222222-0001-0000-0000-000000000001', 'Basic Wash',          150),
  ('33333333-0002-0000-0000-000000000002', '22222222-0005-0000-0000-000000000005', 'Full Detailing',      1500),
  ('33333333-0003-0000-0000-000000000003', '22222222-0006-0000-0000-000000000006', 'Engine Bay Cleaning', 350),
  ('33333333-0003-0000-0000-000000000003', '22222222-0001-0000-0000-000000000001', 'Basic Wash',          150),
  ('33333333-0004-0000-0000-000000000004', '22222222-0005-0000-0000-000000000005', 'Full Detailing',      1500),
  ('33333333-0004-0000-0000-000000000004', '22222222-0002-0000-0000-000000000002', 'Premium Wash',        250);

-- ============================================================
-- REWARD CAMPAIGNS
-- ============================================================
INSERT INTO reward_campaigns (id, campaign_name, month, year, first_place_reward, second_place_reward, third_place_reward, is_active, description, created_at) VALUES
  ('44444444-0001-0000-0000-000000000001',
   'June 2026 Champions',
   6, 2026,
   3000, 2000, 1000,
   TRUE,
   'Top performers for June 2026 get cash bonuses!',
   '2026-05-31T14:39:33Z');

-- ============================================================
-- ADMIN USER (optional — update email as needed)
-- ============================================================
INSERT INTO app_users (email, role) VALUES
  ('jjbalz1994@gmail.com', 'admin')
ON CONFLICT (email) DO NOTHING;

-- ============================================================
-- VERIFY — quick check after seeding
-- ============================================================
SELECT 'employees'        AS table_name, COUNT(*) AS rows FROM employees
UNION ALL
SELECT 'services',         COUNT(*) FROM services
UNION ALL
SELECT 'car_washes',       COUNT(*) FROM car_washes
UNION ALL
SELECT 'car_wash_services',COUNT(*) FROM car_wash_services
UNION ALL
SELECT 'reward_campaigns', COUNT(*) FROM reward_campaigns
UNION ALL
SELECT 'app_users',        COUNT(*) FROM app_users;
