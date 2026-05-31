-- ============================================================
--  🚗💦  CarWash Pro — Seed Data
--  Run AFTER schema.sql
-- ============================================================

-- Safe re-run: clear existing data
TRUNCATE car_wash_services, car_washes, reward_campaigns, services, employees, app_users
  RESTART IDENTITY CASCADE;

-- ============================================================
--  EMPLOYEES
-- ============================================================
INSERT INTO employees (id, full_name, contact_number, commission_percentage, is_active, avatar_color) VALUES
  ('11111111-0001-0000-0000-000000000001', 'John Doe',    '09171234567', 40, TRUE, '#D94A4A'),
  ('11111111-0002-0000-0000-000000000002', 'Mark Santos', '09182345678', 38, TRUE, '#D4AF37'),
  ('11111111-0003-0000-0000-000000000003', 'Kevin Reyes', '09193456789', 35, TRUE, '#B8BCC2'),
  ('11111111-0004-0000-0000-000000000004', 'Ryan Cruz',   '09204567890', 30, TRUE, '#B87333');

-- ============================================================
--  SERVICES
-- ============================================================
INSERT INTO services (id, name, description, price, is_active, icon, sort_order) VALUES
  ('22222222-0001-0000-0000-000000000001', 'Basic Wash',          'Quick exterior rinse and soap wash',      150,  TRUE, '💧', 1),
  ('22222222-0002-0000-0000-000000000002', 'Premium Wash',        'Full exterior wash with hand dry',         250,  TRUE, '✨', 2),
  ('22222222-0003-0000-0000-000000000003', 'Interior Cleaning',   'Vacuuming and interior wipe down',         200,  TRUE, '🪑', 3),
  ('22222222-0004-0000-0000-000000000004', 'Waxing',              'Full car wax for shine and protection',    500,  TRUE, '💎', 4),
  ('22222222-0005-0000-0000-000000000005', 'Full Detailing',      'Complete interior and exterior detailing', 1500, TRUE, '🏆', 5),
  ('22222222-0006-0000-0000-000000000006', 'Engine Bay Cleaning', 'Degreasing and cleaning of engine bay',   350,  TRUE, '⚙️', 6),
  ('22222222-0007-0000-0000-000000000007', 'Tire Shine',          'Tire dressing for glossy finish',          100,  TRUE, '🔄', 7);

-- ============================================================
--  CAR WASHES  (4 real transactions from Base44)
-- ============================================================
INSERT INTO car_washes
  (id, customer_name, plate_number, employee_id, employee_name, services,
   total_amount, amount_paid, commission_rate, commission_amount, transaction_date)
VALUES
  (
    '33333333-0001-0000-0000-000000000001',
    'Test 1', 'ABC123',
    '11111111-0002-0000-0000-000000000002', 'Mark Santos',
    '[{"id":"22222222-0001-0000-0000-000000000001","name":"Basic Wash","price":150}]',
    150, 150, 38, 57,
    '2026-05-31T21:12:24+00:00'
  ),
  (
    '33333333-0002-0000-0000-000000000002',
    '', 'KWZ123',
    '11111111-0004-0000-0000-000000000004', 'Ryan Cruz',
    '[{"id":"22222222-0005-0000-0000-000000000005","name":"Full Detailing","price":1500}]',
    1500, 200, 40, 600,
    '2026-05-31T21:19:21+00:00'
  ),
  (
    '33333333-0003-0000-0000-000000000003',
    'JJ', 'ZAF 125',
    '11111111-0003-0000-0000-000000000003', 'Kevin Reyes',
    '[{"id":"22222222-0006-0000-0000-000000000006","name":"Engine Bay Cleaning","price":350},{"id":"22222222-0001-0000-0000-000000000001","name":"Basic Wash","price":150}]',
    500, 500, 35, 175,
    '2026-05-31T21:24:14+00:00'
  ),
  (
    '33333333-0004-0000-0000-000000000004',
    'Gov', 'FAR 242',
    '11111111-0004-0000-0000-000000000004', 'Ryan Cruz',
    '[{"id":"22222222-0005-0000-0000-000000000005","name":"Full Detailing","price":1500},{"id":"22222222-0002-0000-0000-000000000002","name":"Premium Wash","price":250}]',
    1750, 1750, 30, 525,
    '2026-05-31T21:26:04+00:00'
  );

-- ============================================================
--  CAR WASH SERVICES  (normalised junction)
-- ============================================================
INSERT INTO car_wash_services (car_wash_id, service_id, service_name, service_price) VALUES
  ('33333333-0001-0000-0000-000000000001', '22222222-0001-0000-0000-000000000001', 'Basic Wash',          150),
  ('33333333-0002-0000-0000-000000000002', '22222222-0005-0000-0000-000000000005', 'Full Detailing',      1500),
  ('33333333-0003-0000-0000-000000000003', '22222222-0006-0000-0000-000000000006', 'Engine Bay Cleaning', 350),
  ('33333333-0003-0000-0000-000000000003', '22222222-0001-0000-0000-000000000001', 'Basic Wash',          150),
  ('33333333-0004-0000-0000-000000000004', '22222222-0005-0000-0000-000000000005', 'Full Detailing',      1500),
  ('33333333-0004-0000-0000-000000000004', '22222222-0002-0000-0000-000000000002', 'Premium Wash',        250);

-- ============================================================
--  REWARD CAMPAIGNS
-- ============================================================
INSERT INTO reward_campaigns
  (id, campaign_name, month, year, first_place_reward, second_place_reward, third_place_reward, is_active, description)
VALUES
  (
    '44444444-0001-0000-0000-000000000001',
    'June 2026 Champions', 6, 2026,
    3000, 2000, 1000,
    TRUE,
    'Top performers for June 2026 get cash bonuses!'
  );

-- ============================================================
--  APP USERS
-- ============================================================
INSERT INTO app_users (email, full_name, role) VALUES
  ('jjbalz1994@gmail.com', 'John Joseph Abala', 'admin')
ON CONFLICT (email) DO NOTHING;

-- ============================================================
--  VERIFY
-- ============================================================
SELECT 'employees'         AS "table", COUNT(*)::INT AS rows FROM employees
UNION ALL
SELECT 'services',                      COUNT(*)::INT FROM services
UNION ALL
SELECT 'car_washes',                    COUNT(*)::INT FROM car_washes
UNION ALL
SELECT 'car_wash_services',             COUNT(*)::INT FROM car_wash_services
UNION ALL
SELECT 'reward_campaigns',              COUNT(*)::INT FROM reward_campaigns
UNION ALL
SELECT 'app_users',                     COUNT(*)::INT FROM app_users
ORDER BY 1;
