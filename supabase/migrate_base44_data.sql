-- ═══════════════════════════════════════════════════════════════
-- KGCAR Full Schema Update + Data Migration from Base44 → Supabase
-- Generated: 2026-06-17
-- Run in: Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── 1. ALTER existing tables to add missing columns ──
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS business_type TEXT DEFAULT 'carwash',
  ADD COLUMN IF NOT EXISTS avatar_url    TEXT;

ALTER TABLE services
  ADD COLUMN IF NOT EXISTS business_type TEXT DEFAULT 'carwash';

ALTER TABLE car_washes
  ADD COLUMN IF NOT EXISTS products_used     JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS employees         JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS commission_splits JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS payment_status    TEXT  DEFAULT 'paid';

ALTER TABLE reward_campaigns
  ADD COLUMN IF NOT EXISTS business_type TEXT DEFAULT 'carwash';

-- ── 2. CREATE missing tables ──
CREATE TABLE IF NOT EXISTS vulcanizing_products (
  id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name         TEXT NOT NULL,
  price        NUMERIC DEFAULT 0,
  default_cost NUMERIC DEFAULT 0,
  description  TEXT DEFAULT '',
  is_active    BOOLEAN DEFAULT true,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vulcanizing_jobs (
  id                 TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  customer_name      TEXT,
  vehicle_info       TEXT,
  employee_id        TEXT,
  employee_name      TEXT,
  employees          JSONB DEFAULT '[]',
  services           JSONB DEFAULT '[]',
  products_used      JSONB DEFAULT '[]',
  total_product_cost NUMERIC DEFAULT 0,
  total_amount       NUMERIC DEFAULT 0,
  net_amount         NUMERIC DEFAULT 0,
  amount_paid        NUMERIC DEFAULT 0,
  payment_status     TEXT DEFAULT 'paid',
  commission_rate    NUMERIC DEFAULT 40,
  commission_amount  NUMERIC DEFAULT 0,
  commission_splits  JSONB DEFAULT '[]',
  transaction_date   TIMESTAMPTZ DEFAULT now(),
  notes              TEXT DEFAULT '',
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS commission_payouts (
  id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  employee_id   TEXT,
  employee_name TEXT,
  amount        NUMERIC DEFAULT 0,
  note          TEXT DEFAULT '',
  payout_date   TIMESTAMPTZ DEFAULT now(),
  is_advance    BOOLEAN DEFAULT false,
  business_type TEXT DEFAULT 'carwash',
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS activity_logs (
  id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  event_type  TEXT,
  title       TEXT,
  description TEXT,
  actor_name  TEXT,
  entity_id   TEXT,
  amount      NUMERIC DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- ── 3. Upsert Employees (all 15 from Base44) ──
INSERT INTO employees (id, full_name, contact_number, commission_percentage, is_active, avatar_color, avatar_url, business_type) VALUES
  ('6a311d75c72e6ab79149cd7f','RONNIE','',40,true,'#D94A4A',NULL,'vulcanizing'),
  ('6a30b495c6655188e3dbb1f1','GERALD','',35,true,'#E91E8C',NULL,'carwash'),
  ('6a2fa548ab8ac88dc8e1f6d5','TABA','',35,true,'#D4AF37',NULL,'carwash'),
  ('6a2f6b74839375cb9834956e','ONEL','',40,true,'#22C55E',NULL,'carwash'),
  ('6a2f306447788181c0c26b46','JOVIN','09034930489',40,true,'#D4AF37',NULL,'vulcanizing'),
  ('6a2f3005a234618fac4a8883','KALONG','',40,true,'#22C55E',NULL,'vulcanizing'),
  ('6a2a283b18f5aa768aaca8d9','D-BOY','',40,true,'#D94A4A',NULL,'carwash'),
  ('6a2a282ad4b0de86947f4a10','JONATHAN','',40,true,'#B8BCC2',NULL,'carwash'),
  ('6a2a26427639e71df534d8bc','DODO','',40,true,'#B87333',NULL,'carwash'),
  ('6a2a0cb4fa1ab6f2b534fa99','M. DODOY','380',40,true,'#6C63FF',NULL,'carwash'),
  ('6a2a0ca642d453c64c750764','NOBERT','',40,true,'#D94A4A',NULL,'carwash'),
  ('6a28d5221d44084da9483061','WAWA','',40,true,'#D94A4A',NULL,'vulcanizing'),
  ('6a1e9efb6532d49ddd885d38','LESTER','',40,true,'#D94A4A',NULL,'carwash'),
  ('6a1c48250c5502e7c9fdbacf','LOY2x','',40,true,'#F59E0B',NULL,'carwash'),
  ('6a1c48250c5502e7c9fdbad0','TOY2X','',40,true,'#84CC16',NULL,'carwash')
ON CONFLICT (id) DO UPDATE SET
  full_name=EXCLUDED.full_name, commission_percentage=EXCLUDED.commission_percentage,
  is_active=EXCLUDED.is_active, avatar_color=EXCLUDED.avatar_color,
  business_type=EXCLUDED.business_type;

-- ── 4. Upsert Services ──
INSERT INTO services (id, name, description, price, is_active, icon, business_type) VALUES
  ('6a30e078d0ccd2cabdf0ada7','COMPLETE WASH KOTSE/MINIVAN','Fall wash,underchassis w/sabon & engine',380,true,NULL,'carwash'),
  ('6a2fb75d2af41ff9838ededb','BODY WASH VAN','Body wash & vacumm',230,true,NULL,'carwash'),
  ('6a2f7cd35c8e67ffffcf5e21','Basic wash half(small)','fall wash &vacumm',90,true,NULL,'carwash'),
  ('6a2f7258332e44ab405bb9ad','BAC TO ZERO','BAC TO ZERO',350,true,NULL,'carwash'),
  ('6a2a3e3ad48dbeccb44b77f9','BODY WASH COMPLETE (LARGE)','Body wash,under chassis,w/ engine wash',400,true,NULL,'carwash'),
  ('6a2a3e0e880e74d734bb924d','BASIC WASH (X-LARGE)','BODY WASH, VACUMM',430,true,NULL,'carwash'),
  ('6a2a3de7cff42ac39ae26341','BODY WASH W/ UNDER CHASSIS (SMALL)','',280,true,NULL,'carwash'),
  ('6a2a2a1e84394bb434499c8d','BAC TO ZERO (SANITIZE)','Sanitize',700,true,NULL,'carwash'),
  ('6a27506722fe5640a8f95a92','Tire Repair / Patching','Standard tire repair and patching',120,true,NULL,'vulcanizing'),
  ('6a27506722fe5640a8f95a93','Valve Replacement','Tire valve stem replacement',80,true,NULL,'vulcanizing'),
  ('6a27506722fe5640a8f95a94','Balancing','Tire balancing service',150,true,NULL,'vulcanizing'),
  ('6a27506722fe5640a8f95a95','Nitrogen (Nitro) Fill','Nitrogen tire inflation',100,true,NULL,'vulcanizing'),
  ('6a27506722fe5640a8f95a96','Tire Mounting','Tire mounting and fitting',200,true,NULL,'vulcanizing'),
  ('6a1c48250c5502e7c9fdbad2','Basic Wash (Small)','Quick exterior rinse and soap wash',180,true,'💧','carwash'),
  ('6a1c48250c5502e7c9fdbad3','Basic Wash (Large)','Full exterior wash with hand dry',200,true,'✨','carwash'),
  ('6a1c48250c5502e7c9fdbad4','BODY WASH W/UNDER CHASSIS (LARGE)','Vacuuming,Body wash,under chassis',250,true,'🪑','carwash'),
  ('6a1c48250c5502e7c9fdbad5','Waxing','Full car wax for shine and protection',500,true,'💎','carwash'),
  ('6a1c48250c5502e7c9fdbad6','Full Detailing','Complete interior and exterior detailing',1500,true,'🏆','carwash'),
  ('6a1c48250c5502e7c9fdbad7','Engine wash','Cleaning and spray',50,true,'⚙️','carwash'),
  ('6a1c48250c5502e7c9fdbad8','Tire Shine','Tire dressing for glossy finish',100,true,'🔄','carwash')
ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, price=EXCLUDED.price, is_active=EXCLUDED.is_active,
  business_type=EXCLUDED.business_type;

-- ── 5. Upsert Vulcanizing Products ──
INSERT INTO vulcanizing_products (id, name, price, default_cost, description, is_active) VALUES
  ('6a3104146f9b107d6cee58cc','PPO',100,15,'',true),
  ('6a2f9d9b30c43fbbc8fc8d0a','TIRE ROTATION',200,0,'',true),
  ('6a2f8378133b9e6af8b878a9','TIRE SEAL',100,15,'',true),
  ('6a2f67f01f50f16c0f72b1cc','CARWASH',200,0,'',true),
  ('6a2f460e1e57f3634832cda8','NITROGEN',50,0,'',true),
  ('6a2bae1cb49d5514075fbd12','CHANGE TIRE',50,0,'',true),
  ('6a2bad59c7b08b69be0ad362','MCX20',600,180,'',true),
  ('6a2bad1eeb72e1f96d644c41','MCX14',500,130,'',true),
  ('6a2bacf26bb9c8f0dcebc14a','MCX12',450,100,'',true),
  ('6a2baccd1d801ac56b6c4b44','MCX10',350,40,'',true),
  ('6a2bac4b9e433ac3eac00732','PP4',350,50,'',true),
  ('6a2babd7f461fc63408a7018','PP3',250,35,'',true),
  ('6a28d3cb71d6c03b882f8f76','PP2',200,30,'',true),
  ('6a2752a3549310bc661051ee','PP1 (Puncture Patch)',150,20,'Standard rubber puncture patch',true),
  ('6a2752a3549310bc661051ef','Sealant',120,50,'Tire sealant liquid',true),
  ('6a2752a3549310bc661051f1','Patch Kit (Large)',150,60,'Large sidewall patch kit',true),
  ('6a2752a3549310bc661051f2','Rim Tape',100,40,'Rim protective tape',true)
ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, price=EXCLUDED.price, default_cost=EXCLUDED.default_cost, is_active=EXCLUDED.is_active;

-- ── 6. Upsert Commission Payouts ──
INSERT INTO commission_payouts (id, employee_id, employee_name, amount, note, payout_date, is_advance, business_type) VALUES
  ('6a31d73f071327f8218b3e10','6a311d75c72e6ab79149cd7f','RONNIE',882,'Earned Payout','2026-06-16T23:07:41Z',false,'vulcanizing'),
  ('6a31201a423ca4e14f097f7a','6a2f3005a234618fac4a8883','KALONG',200,'Cash Advance','2026-06-16T10:06:17Z',true,'vulcanizing'),
  ('6a311fc5c92f750ea03c6fba','6a2a0ca642d453c64c750764','NOBERT',200,'Cash Advance','2026-06-16T10:04:52Z',true,'carwash'),
  ('6a311f9e2c7f5bf157a8f07c','6a2fa548ab8ac88dc8e1f6d5','TABA',200,'Cash Advance','2026-06-16T10:04:13Z',true,'carwash'),
  ('6a311f80c2432fcbe535a784','6a2f6b74839375cb9834956e','ONEL',200,'Cash Advance','2026-06-16T10:03:43Z',true,'carwash'),
  ('6a311eb9cd1c1d04600cc50d','6a28d5221d44084da9483061','WAWA',1084,'Earned Payout','2026-06-16T10:00:23Z',false,'vulcanizing'),
  ('6a30ba97863a3d77a3c65a65','6a2f306447788181c0c26b46','JOVIN',300,'Cash Advance','2026-06-16T02:53:11Z',true,'vulcanizing'),
  ('6a3088da1da0dfe84d7e8867','6a2a0ca642d453c64c750764','NOBERT',500,'Cash Advance','2026-06-15T23:20:58Z',true,'carwash'),
  ('6a2fcf07314a60073cc2808b','6a2a0ca642d453c64c750764','NOBERT',342,'Advance payout','2026-06-15T10:07:39Z',true,'carwash'),
  ('6a25f5961e5e6bae9d9b8d14','6a1c48250c5502e7c9fdbacf','LOY2x',1241,'Advance payout','2026-06-07T22:49:56Z',true,'carwash'),
  ('6a25f536cfe7f27a4bb14e6e','6a1e9efb6532d49ddd885d38','LESTER',450,'Advance payout','2026-06-07T22:48:21Z',true,'carwash'),
  ('6a25f4f4a806813bcd787bb3','6a1c48250c5502e7c9fdbad0','TOY2X',62,'Advance payout','2026-06-07T22:47:15Z',true,'carwash'),
  ('6a25f40100ace5a09b37bb88','6a1e9efb6532d49ddd885d38','LESTER',40,'Advance payout','2026-06-07T22:43:11Z',true,'carwash'),
  ('6a1ea1372b1364f4174879e6','6a1c48250c5502e7c9fdbad0','TOY2X',500,'Advance payout','2026-06-02T09:24:06Z',true,'carwash'),
  ('6a1e9fec7f429d724f613595','6a1e9efb6532d49ddd885d38','LESTER',100,'Advance payout','2026-06-02T09:18:35Z',true,'carwash'),
  ('6a1d0de0ea7acbb51fa53c70','6a1c48250c5502e7c9fdbacd','',50,'Advance payout','2026-06-01T04:43:12Z',true,'carwash'),
  ('6a1d0d365e627151bc3d2f7c','6a1c48250c5502e7c9fdbad0','TOY2X',1000,'Advance payout','2026-06-01T04:40:20Z',true,'carwash')
ON CONFLICT (id) DO UPDATE SET amount=EXCLUDED.amount, note=EXCLUDED.note, is_advance=EXCLUDED.is_advance, business_type=EXCLUDED.business_type;
