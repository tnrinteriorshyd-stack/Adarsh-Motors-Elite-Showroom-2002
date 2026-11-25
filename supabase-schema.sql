-- ========================================================================
-- ADARSH MOTORS — COMPLETE SUPABASE DATABASE SETUP SCRIPT
-- Paste this entire SQL into your Supabase Dashboard:
-- https://supabase.com/dashboard/project/_/sql/new
-- Click "Run" to create all tables, views, RLS policies, and seed data.
-- ========================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Clean drop any old tables/views with mismatched column types from earlier attempts
DROP VIEW IF EXISTS public.invoices CASCADE;
DROP TABLE IF EXISTS public.invoices CASCADE;
DROP TABLE IF EXISTS public.accessory_orders CASCADE;
DROP TABLE IF EXISTS public.user_services CASCADE;
DROP TABLE IF EXISTS public.user_bikes CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.leads CASCADE;
DROP TABLE IF EXISTS public.site_settings CASCADE;
DROP TABLE IF EXISTS public.branches CASCADE;
DROP TABLE IF EXISTS public.accessories CASCADE;
DROP TABLE IF EXISTS public.bikes CASCADE;

-- ------------------------------------------------------------------------
-- 2. SHOWROOM FLEET INVENTORY (bikes)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bikes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  brand TEXT NOT NULL,
  category TEXT NOT NULL,
  year INTEGER NOT NULL,
  km TEXT NOT NULL,
  engine TEXT NOT NULL,
  hp TEXT NOT NULL,
  price_raw BIGINT NOT NULL,
  price TEXT NOT NULL,
  location TEXT NOT NULL,
  image_url TEXT NOT NULL,
  badge TEXT DEFAULT 'VERIFIED',
  fuel TEXT DEFAULT 'Petrol',
  acceleration TEXT DEFAULT '3.2s',
  tagline TEXT,
  addon_name TEXT,
  addon_price TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 3. DEDICATED SUPERBIKE ACCESSORIES & PERFORMANCE PARTS (accessories)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.accessories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL, -- 'Exhausts', 'Riding Gear', 'Performance', 'Protection'
  brand TEXT NOT NULL,
  price_raw BIGINT NOT NULL,
  price TEXT NOT NULL,
  spec TEXT NOT NULL,
  fitment TEXT NOT NULL,
  in_stock BOOLEAN DEFAULT TRUE,
  badge TEXT DEFAULT 'RACE SPEC',
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 4. SHOWROOM & LOUNGE BRANCHES (branches)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.branches (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  city TEXT NOT NULL,
  address TEXT NOT NULL,
  timings TEXT NOT NULL,
  maps_query TEXT NOT NULL,
  phone TEXT DEFAULT '+91 9014540489',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 5. DYNAMIC SITE SETTINGS (site_settings)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.site_settings (
  key TEXT PRIMARY KEY,
  phone TEXT DEFAULT '+91 9014540489',
  instagram TEXT DEFAULT 'https://instagram.com/adarsh_motors',
  hero_slides JSONB,
  value JSONB,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 6. CUSTOMER PROFILES (OTP-Protected Customer Accounts & Garage)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_profiles (
  phone TEXT PRIMARY KEY,
  owner TEXT NOT NULL,
  email TEXT,
  city TEXT DEFAULT 'Hyderabad',
  vip_status TEXT DEFAULT 'Emerald Superbike Elite',
  vehicles JSONB DEFAULT '[]'::jsonb,
  services JSONB DEFAULT '[]'::jsonb,
  accessory_orders JSONB DEFAULT '[]'::jsonb,
  joined TEXT DEFAULT '2024',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 7. CUSTOMER PURCHASED VEHICLES & RTO DOCUMENT TRANSFER TRACKER (user_bikes)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_bikes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_phone TEXT REFERENCES public.user_profiles(phone) ON DELETE CASCADE,
  name TEXT NOT NULL,
  reg_no TEXT NOT NULL,
  vin TEXT NOT NULL,
  invoice_id TEXT UNIQUE NOT NULL,
  delivery_date TEXT NOT NULL,
  warranty TEXT NOT NULL,
  warranty_status TEXT DEFAULT 'Active',
  -- RTO & Paper Transfer Tracker
  transfer_status TEXT DEFAULT 'In Progress', -- 'Pending', 'In Progress', 'Documents Submitted', 'Completed'
  transfer_step_idx INTEGER DEFAULT 2,       -- 1, 2, 3, or 4
  transfer_steps JSONB DEFAULT '[]'::jsonb,
  transfer_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 8. SERVICE HISTORY & UPCOMING MAINTENANCE (user_services)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_phone TEXT REFERENCES public.user_profiles(phone) ON DELETE CASCADE,
  vehicle TEXT NOT NULL,
  date TEXT NOT NULL,
  odometer TEXT NOT NULL,
  type TEXT NOT NULL,
  technician TEXT NOT NULL,
  cost TEXT NOT NULL,
  status TEXT DEFAULT 'Completed', -- 'Completed', 'Upcoming Scheduled'
  items TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_user_service UNIQUE (user_phone, vehicle, date)
);

-- ------------------------------------------------------------------------
-- 9. ACCESSORY ORDERS & HISTORY (accessory_orders)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.accessory_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_phone TEXT REFERENCES public.user_profiles(phone) ON DELETE CASCADE,
  receipt TEXT UNIQUE NOT NULL,
  item TEXT NOT NULL,
  date TEXT NOT NULL,
  amount TEXT NOT NULL,
  status TEXT DEFAULT 'Delivered & Fitted',
  warranty TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 10. CUSTOMER LEADS & INQUIRIES (leads)
-- Handles Service Bookings, Sell Bike Valuations, Test Rides & Finance Loans
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL, -- 'service_appointment', 'sell_bike_valuation', 'test_ride_booking', 'finance_loan'
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  bike_model TEXT,
  registration_number TEXT,
  service_type TEXT,
  preferred_date TEXT,
  branch TEXT,
  license_status TEXT,
  year TEXT,
  km TEXT,
  expected_price TEXT,
  condition TEXT,
  photos_count INTEGER DEFAULT 0,
  uploaded_photos TEXT[],
  loan_amount TEXT,
  tenure TEXT,
  employment TEXT,
  employment_type TEXT,
  notes TEXT,
  status TEXT DEFAULT 'New Lead',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 11. INVOICES & OWNERSHIP VIEW (Backward-compatibility view)
-- ------------------------------------------------------------------------
DROP TABLE IF EXISTS public.invoices CASCADE;
DROP VIEW IF EXISTS public.invoices CASCADE;

CREATE VIEW public.invoices AS
SELECT 
  ub.id,
  ub.user_phone AS phone,
  up.owner,
  up.email,
  ub.name AS vehicle,
  ub.reg_no,
  ub.vin,
  ub.invoice_id,
  ub.delivery_date,
  ub.warranty,
  ub.transfer_status,
  ub.transfer_step_idx,
  ub.transfer_notes
FROM public.user_bikes ub
LEFT JOIN public.user_profiles up ON ub.user_phone = up.phone;

-- ------------------------------------------------------------------------
-- 12. ROW LEVEL SECURITY (RLS) & PUBLIC ACCESS POLICIES
-- ------------------------------------------------------------------------
ALTER TABLE public.bikes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accessories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_bikes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accessory_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

-- Clean drop existing policies to prevent conflict errors if re-run
DROP POLICY IF EXISTS "Public Read Bikes" ON public.bikes;
DROP POLICY IF EXISTS "Public Read Accessories" ON public.accessories;
DROP POLICY IF EXISTS "Public Read Branches" ON public.branches;
DROP POLICY IF EXISTS "Public Read Site Settings" ON public.site_settings;
DROP POLICY IF EXISTS "Public Read Profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Public Read User Bikes" ON public.user_bikes;
DROP POLICY IF EXISTS "Public Read User Services" ON public.user_services;
DROP POLICY IF EXISTS "Public Read Accessory Orders" ON public.accessory_orders;
DROP POLICY IF EXISTS "Public Insert Leads" ON public.leads;
DROP POLICY IF EXISTS "Public Insert Profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Public Update Profiles" ON public.user_profiles;

-- Allow public read of inventory, accessories, branches & settings
CREATE POLICY "Public Read Bikes" ON public.bikes FOR SELECT USING (true);
CREATE POLICY "Public Read Accessories" ON public.accessories FOR SELECT USING (true);
CREATE POLICY "Public Read Branches" ON public.branches FOR SELECT USING (true);
CREATE POLICY "Public Read Site Settings" ON public.site_settings FOR SELECT USING (true);

-- Allow public read of customer profile and vehicle records
CREATE POLICY "Public Read Profiles" ON public.user_profiles FOR SELECT USING (true);
CREATE POLICY "Public Read User Bikes" ON public.user_bikes FOR SELECT USING (true);
CREATE POLICY "Public Read User Services" ON public.user_services FOR SELECT USING (true);
CREATE POLICY "Public Read Accessory Orders" ON public.accessory_orders FOR SELECT USING (true);

-- Allow customer submissions of bookings, test rides, sell inquiries, loans & profiles
CREATE POLICY "Public Insert Leads" ON public.leads FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Insert Profiles" ON public.user_profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update Profiles" ON public.user_profiles FOR UPDATE USING (true);

-- ========================================================================
-- 13. SEED INITIAL SHOWROOM DATA
-- ========================================================================

-- Seed Showroom Fleet
INSERT INTO public.bikes (id, name, brand, category, year, km, engine, hp, price_raw, price, location, image_url, badge, fuel, acceleration, tagline, addon_name, addon_price)
VALUES
  ('bike-1', 'KAWASAKI NINJA Z900', 'Kawasaki', 'Superbikes', 2024, '1,456 km', '948 cc Inline-4', '125 hp', 920000, '₹9,20,000', 'Hyderabad – Main Showroom', '/assets/aistudio/image_f4045ab9.png', 'PRE-OWNED', 'Petrol', '3.4s', 'Raw inline-4 symphony with Sugomi attitude.', 'KTM / Kawasaki Racing Jacket', '₹16,500'),
  ('bike-2', 'BMW S1000RR M-SPORT', 'BMW', 'Superbikes', 2024, '3,200 km', '999 cc ShiftCam', '205 hp', 2350000, '₹23,50,000', 'Hyderabad – Banjara Hills', '/assets/aistudio/image_f406ab38.png', 'PRE-OWNED', 'Petrol', '2.9s', 'Track weapon with aerodynamic carbon winglets.', 'BMW M Carbon Helmet', '₹42,000'),
  ('bike-3', 'DUCATI DIAVEL V4', 'Ducati', 'Superbikes', 2024, '1,112 km', 'V4 1158 cc Granturismo', '168 hp', 2890000, '₹28,90,000', 'Hyderabad – Main Showroom', '/assets/aistudio/image_f406ab38.png', 'PRE-OWNED', 'Petrol', '3.1s', 'Muscular stance with superbike heart.', 'Ducati Corse Riding Leather', '₹38,500'),
  ('bike-4', 'KTM 1290 SUPER DUKE R', 'KTM', 'Superbikes', 2023, '1,845 km', '1301 cc LC8 V-Twin', '180 hp', 1850000, '₹18,50,000', 'Bengaluru Branch', '/assets/aistudio/image_5a6010cd.png', 'PRE-OWNED', 'Petrol', '3.1s', 'The Beast. The ultimate hyper-naked machine.', 'KTM PowerWear Jacket', '₹18,500'),
  ('bike-5', 'HONDA ACTIVA 6G PREMIUM', 'Honda', 'Scooters', 2023, '5,000 km', '110 cc eSP HET', '7.8 hp', 85000, '₹85,000', 'Hyderabad – Main Showroom', '/assets/aistudio/image_f4045ab9.png', 'PRE-OWNED', 'Petrol', '7.2s', 'India highest reliability daily commuter.', 'Studds Urban Shield Helmet', '₹2,200'),
  ('bike-6', 'KAWASAKI NINJA ZX-10R', 'Kawasaki', 'Superbikes', 2023, '4,100 km', '998 cc WSBK Spec', '203 hp', 1680000, '₹16,80,000', 'Mumbai Branch', '/assets/aistudio/image_f4045ab9.png', 'PRE-OWNED', 'Petrol', '2.8s', 'Multiple World Superbike Championship winner.', 'Akrapovic Full Titanium Decat', '₹85,000'),
  ('bike-7', 'ROYAL ENFIELD CONTINENTAL GT 650', 'Royal Enfield', 'Mid-Range', 2023, '6,200 km', '648 cc Parallel Twin', '47 hp', 345000, '₹3,45,000', 'Hyderabad – Banjara Hills', '/assets/aistudio/image_f4045ab9.png', 'PRE-OWNED', 'Petrol', '5.8s', 'Authentic cafe racer with clip-on handlebars.', 'Royal Enfield Leather Gloves', '₹4,500')
ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name,
  brand = EXCLUDED.brand,
  category = EXCLUDED.category,
  price = EXCLUDED.price,
  price_raw = EXCLUDED.price_raw,
  image_url = EXCLUDED.image_url;

-- Seed Accessories Catalog
INSERT INTO public.accessories (id, name, category, brand, price_raw, price, spec, fitment, in_stock, badge, image_url)
VALUES
  ('acc-1', 'Akrapovič Evolution Titanium Full System', 'Exhausts', 'Akrapovič', 265000, '₹2,65,000', 'Full Titanium Decat · WSBK Spec · 4.8kg Weight Reduction', 'Kawasaki Ninja ZX-10R / Z900', TRUE, 'WSBK TRACK ONLY', '/assets/aistudio/image_f4045ab9.png'),
  ('acc-2', 'SC-Project CR-T Titanium Slip-on', 'Exhausts', 'SC-Project', 98000, '₹98,000', 'Titanium with Mesh Screen · Pure MotoGP Decibel Sound', 'Ducati Streetfighter V4 / Panigale V4', TRUE, 'MOTOGP REPLICA', '/assets/aistudio/image_f406ab38.png'),
  ('acc-3', 'Brembo GP4-RX CNC Radial Monobloc Calipers', 'Performance', 'Brembo', 185000, '₹1,85,000', 'Nickel Coated CNC Billet Aluminum · 4x32mm Pistons', 'Universal 108mm Radial Mount (BMW/Yamaha/Kawasaki)', TRUE, 'RACE SPEC', '/assets/aistudio/image_5a6010cd.png'),
  ('acc-4', 'Dainese Mugello 3 D-Air Race Leather Suit', 'Riding Gear', 'Dainese', 345000, '₹3,45,000', 'Kangaroo Leather · Wireless Intelligent D-Air Airbag · Titanium Sliders', 'Available in Euro Sizes 48, 50, 52, 54', TRUE, 'AIRBAG ACTIVE', '/assets/aistudio/image_5a6010cd.png'),
  ('acc-5', 'AGV Pista GP RR Carbon Winter Test Limited Edition', 'Riding Gear', 'AGV', 145000, '₹1,45,000', '100% 3K Carbon Shell · FIM Homologated · Hydration System', 'Sizes S, M, L, XL with 360 Adaptive Fit', TRUE, 'FIM RACING', '/assets/aistudio/image_f406ab38.png'),
  ('acc-6', 'Öhlins TTX GP Rear Monoshock Absorber', 'Performance', 'Öhlins', 168000, '₹1,68,000', 'Twin Tube Technology · Separate Compression & Rebound Valves', 'BMW S1000RR / Yamaha YZF-R1 / Ducati V4', TRUE, 'FACTORY RACE', '/assets/aistudio/image_f4045ab9.png'),
  ('acc-7', 'Evotech Performance Crash Protection & Radiator Guard Pack', 'Protection', 'Evotech', 42000, '₹42,000', 'Aircraft Grade Billet Aluminum · Powder Coated Steel Matrix', 'Kawasaki Z900 / Ninja 1000SX / Triumph Street Triple', TRUE, 'ESSENTIAL ARMOR', '/assets/aistudio/image_5a6010cd.png'),
  ('acc-8', 'GBRacing Complete Engine Cover Protection Set', 'Protection', 'GBRacing', 28500, '₹28,500', '60% Long Glass Fibered Nylon 6.6 · FIM Approved Protection', 'Direct Bolt-On for Clutch, Alternator & Pulse Covers', TRUE, 'FIM APPROVED', '/assets/aistudio/image_f406ab38.png')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  price = EXCLUDED.price,
  price_raw = EXCLUDED.price_raw;

-- Seed Showroom Branches
INSERT INTO public.branches (id, name, city, address, timings, maps_query, phone)
VALUES
  ('hyd-main', 'Hyderabad – Main Superbike Showroom', 'Hyderabad', 'Plot 48, Road No. 36, Jubilee Hills, Hyderabad, Telangana 500033', 'Mon – Sun: 10:00 AM – 8:30 PM (Air-conditioned valet lounge)', 'Adarsh+Motors+Jubilee+Hills+Hyderabad', '+91 9014540489'),
  ('hyd-banjara', 'Hyderabad – Banjara Hills Superbike Lounge', 'Hyderabad', 'Road No. 12, MLA Colony, Banjara Hills, Hyderabad, Telangana 500034', 'Mon – Sun: 10:30 AM – 8:00 PM', 'Adarsh+Motors+Banjara+Hills+Hyderabad', '+91 9014540489'),
  ('blr-hub', 'Bengaluru – Indiranagar Experience Centre', 'Bengaluru', '100 Feet Road, HAL 2nd Stage, Indiranagar, Bengaluru, Karnataka 560038', 'Mon – Sun: 10:00 AM – 9:00 PM', 'Adarsh+Motors+Indiranagar+Bengaluru', '+91 9014540489'),
  ('mum-west', 'Mumbai – Andheri West Showroom', 'Mumbai', 'New Link Road, Next to Lotus Petrol Pump, Andheri West, Mumbai, MH 400053', 'Mon – Sun: 10:00 AM – 8:30 PM', 'Adarsh+Motors+Andheri+West+Mumbai', '+91 9014540489')
ON CONFLICT (id) DO NOTHING;

-- Seed Site Settings
INSERT INTO public.site_settings (key, phone, instagram, value)
VALUES
  ('general', '+91 9014540489', 'https://instagram.com/adarsh_motors', '{"phone": "+91 9014540489", "instagram": "https://instagram.com/adarsh_motors"}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- Seed Demo Customer Profiles
INSERT INTO public.user_profiles (phone, owner, email, city, vip_status, joined, vehicles, services, accessory_orders)
VALUES
  (
    '9014540489',
    'Kanna Pavan',
    'kannapavan30@gmail.com',
    'Hyderabad, Jubilee Hills',
    'Emerald Superbike Elite',
    'December 2022',
    '[
      {
        "id": "v-1",
        "name": "Kawasaki Ninja Z900 (Special Edition)",
        "reg_no": "TS 09 EG 7744",
        "vin": "JKAZR900PPA092144",
        "invoice_id": "INV-2024-ADM-8492",
        "delivery_date": "14 January 2024",
        "warranty": "Active · 2-Year Engine & RSA Protection (Valid till Jan 2026)",
        "warranty_status": "Active",
        "transfer": {
          "status": "Completed",
          "badge_class": "bg-emerald-950/90 text-emerald-400 border-emerald-700/50",
          "step_idx": 4,
          "steps": [
            {"title": "Dealership Sale Invoice Issued", "date": "14 Jan 2024", "done": true},
            {"title": "RTO Form 29 & 30 Endorsed", "date": "18 Jan 2024", "done": true},
            {"title": "Documents Submitted to RTO Khairatabad", "date": "24 Jan 2024", "done": true},
            {"title": "Smart Card RC Dispatched to Owner", "date": "08 Feb 2024", "done": true}
          ],
          "notes": "Original Smart Card RC handed over at Jubilee Hills lounge. Comprehensive Bumper-to-Bumper Insurance active till Jan 2025."
        }
      },
      {
        "id": "v-2",
        "name": "BMW S1000RR M-Sport (Track Spec)",
        "reg_no": "TS 10 EX 9901",
        "vin": "WB10E2108PZ849120",
        "invoice_id": "INV-2024-ADM-9104",
        "delivery_date": "28 October 2024",
        "warranty": "Active · 3-Year Factory Warranty",
        "warranty_status": "Active",
        "transfer": {
          "status": "Documents Submitted",
          "badge_class": "bg-blue-950/90 text-blue-400 border-blue-700/50",
          "step_idx": 3,
          "steps": [
            {"title": "Dealership Sale Invoice Issued", "date": "28 Oct 2024", "done": true},
            {"title": "RTO Form 29 & 30 Endorsed", "date": "02 Nov 2024", "done": true},
            {"title": "Documents Submitted to RTO Secunderabad", "date": "04 Nov 2024", "done": true},
            {"title": "Awaiting Smart Card RC Dispatch", "date": "Expected in 7 days", "done": false}
          ],
          "notes": "RTO filing reference #HYD-RTO-2024-941829. NOC verified and transferred."
        }
      }
    ]'::jsonb,
    '[
      {
        "id": "srv-1",
        "vehicle": "Kawasaki Ninja Z900",
        "date": "22 Feb 2024",
        "odometer": "1,050 km",
        "type": "First 1,000 KM Break-in Inspection & Oil Flush",
        "technician": "Vikram Reddy (Master Tech)",
        "cost": "₹6,800",
        "status": "Completed",
        "items": "Motul 300V Factory Line 10W40, OEM Kawasaki Oil Filter, Chain slack & torque spec check"
      },
      {
        "id": "srv-2",
        "vehicle": "Kawasaki Ninja Z900",
        "date": "Upcoming · Due in 800 km",
        "odometer": "6,000 km",
        "type": "Periodic Track & Road Inspection",
        "technician": "Vikram Reddy (+91 9014540489)",
        "cost": "Est. ₹9,200",
        "status": "Upcoming Scheduled",
        "items": "Throttle body sync, coolant gravity check, brake fluid flush, dyno verification"
      }
    ]'::jsonb,
    '[
      {
        "id": "acc-1",
        "receipt": "REC-ADM-ACC-902",
        "item": "Akrapovič Evolution Titanium Full System",
        "date": "20 Jan 2024",
        "amount": "₹2,65,000",
        "status": "Delivered & Fitted",
        "warranty": "2 Years International Akrapovic Warranty"
      },
      {
        "id": "acc-2",
        "receipt": "REC-ADM-ACC-948",
        "item": "AGV Pista GP RR Carbon Helmet (Winter Test)",
        "date": "14 Feb 2024",
        "amount": "₹1,45,000",
        "status": "Delivered to Residence",
        "warranty": "5 Years AGV Official Protection"
      }
    ]'::jsonb
  ),
  (
    '9876543210',
    'Rajesh Kumar',
    'rajesh.kumar@gmail.com',
    'Hyderabad, Banjara Hills',
    'Ducati Club Member',
    'March 2023',
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb
  )
ON CONFLICT (phone) DO UPDATE SET 
  owner = EXCLUDED.owner, 
  email = EXCLUDED.email,
  vehicles = EXCLUDED.vehicles,
  services = EXCLUDED.services,
  accessory_orders = EXCLUDED.accessory_orders;

-- Seed Customer Vehicles (user_bikes table)
INSERT INTO public.user_bikes (user_phone, name, reg_no, vin, invoice_id, delivery_date, warranty, transfer_status, transfer_step_idx, transfer_steps, transfer_notes)
VALUES
  (
    '9014540489',
    'Kawasaki Ninja Z900 (Special Edition)',
    'TS 09 EG 7744',
    'JKAZR900PPA092144',
    'INV-2024-ADM-8492',
    '14 January 2024',
    'Active · 2-Year Engine & RSA Protection (Valid till Jan 2026)',
    'Completed',
    4,
    '[
      {"title": "Dealership Sale Invoice Issued", "date": "14 Jan 2024", "done": true},
      {"title": "RTO Form 29 & 30 Endorsed", "date": "18 Jan 2024", "done": true},
      {"title": "Documents Submitted to RTO Khairatabad", "date": "24 Jan 2024", "done": true},
      {"title": "Smart Card RC Dispatched to Owner", "date": "08 Feb 2024", "done": true}
    ]'::jsonb,
    'Original Smart Card RC handed over at Jubilee Hills lounge. Comprehensive Bumper-to-Bumper Insurance active till Jan 2025.'
  ),
  (
    '9014540489',
    'BMW S1000RR M-Sport (Track Spec)',
    'TS 10 EX 9901',
    'WB10E2108PZ849120',
    'INV-2024-ADM-9104',
    '28 October 2024',
    'Active · 3-Year Factory Warranty',
    'Documents Submitted',
    3,
    '[
      {"title": "Dealership Sale Invoice Issued", "date": "28 Oct 2024", "done": true},
      {"title": "RTO Form 29 & 30 Endorsed", "date": "02 Nov 2024", "done": true},
      {"title": "Documents Submitted to RTO Secunderabad", "date": "04 Nov 2024", "done": true},
      {"title": "Awaiting Smart Card RC Dispatch", "date": "Expected in 7 days", "done": false}
    ]'::jsonb,
    'RTO filing reference #HYD-RTO-2024-941829. NOC verified and transferred.'
  )
ON CONFLICT (invoice_id) DO NOTHING;

-- Seed Service Logs
INSERT INTO public.user_services (user_phone, vehicle, date, odometer, type, technician, cost, status, items)
VALUES
  ('9014540489', 'Kawasaki Ninja Z900', '22 Feb 2024', '1,050 km', 'First 1,000 KM Break-in Inspection & Oil Flush', 'Vikram Reddy (Master Tech)', '₹6,800', 'Completed', 'Motul 300V Factory Line 10W40, OEM Kawasaki Oil Filter, Chain slack & torque spec check'),
  ('9014540489', 'Kawasaki Ninja Z900', 'Upcoming · Due in 800 km', '6,000 km', 'Periodic Track & Road Inspection', 'Vikram Reddy (+91 9014540489)', 'Est. ₹9,200', 'Upcoming Scheduled', 'Throttle body sync, coolant gravity check, brake fluid flush, dyno verification')
ON CONFLICT (user_phone, vehicle, date) DO NOTHING;

-- Seed Accessory Orders
INSERT INTO public.accessory_orders (user_phone, receipt, item, date, amount, status, warranty)
VALUES
  ('9014540489', 'REC-ADM-ACC-902', 'Akrapovič Evolution Titanium Full System', '20 Jan 2024', '₹2,65,000', 'Delivered & Fitted', '2 Years International Akrapovic Warranty'),
  ('9014540489', 'REC-ADM-ACC-948', 'AGV Pista GP RR Carbon Helmet (Winter Test)', '14 Feb 2024', '₹1,45,000', 'Delivered to Residence', '5 Years AGV Official Protection')
ON CONFLICT (receipt) DO NOTHING;

-- ------------------------------------------------------------------------
-- 14. BRAND SPONSORSHIP AD BANNERS (ad_banners)
-- Placements: 'hero', 'between_listings', 'detail_page'
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ad_banners (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT,
  image_url TEXT NOT NULL,
  target_url TEXT NOT NULL,
  placement TEXT NOT NULL CHECK (placement IN ('hero', 'between_listings', 'detail_page')),
  is_active BOOLEAN DEFAULT TRUE,
  clicks INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------
-- 15. AUTO NEWS, LAUNCHES & EXPERT REVIEWS (auto_news)
-- ------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.auto_news (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'Reviews',
  image_url TEXT NOT NULL,
  summary TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.ad_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auto_news ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public Read Ad Banners" ON public.ad_banners;
DROP POLICY IF EXISTS "Public Update Ad Banner Clicks" ON public.ad_banners;
DROP POLICY IF EXISTS "Public Read Auto News" ON public.auto_news;

CREATE POLICY "Public Read Ad Banners" ON public.ad_banners FOR SELECT USING (true);
CREATE POLICY "Public Update Ad Banner Clicks" ON public.ad_banners FOR UPDATE USING (true);
CREATE POLICY "Public Read Auto News" ON public.auto_news FOR SELECT USING (true);

-- Seed Sponsored Partner Banners
INSERT INTO public.ad_banners (id, title, subtitle, image_url, target_url, placement, is_active, clicks)
VALUES
  ('partner-hero-1', 'Motul 300V Factory Line · Official Track Lubrication & Detailing Partner', 'Free 150-point fluid & brake health check included on every showroom booking.', '/assets/generated/partner_banner_performance_1795411965915.jpg', '#service', 'hero', TRUE, 0),
  ('partner-feed-1', 'Adarsh Protect+ · Zero-Depreciation Superbike & Supercar Insurance', 'Instant cashless claim approval & 24/7 flatbed roadside assistance across India.', '/assets/generated/partner_banner_performance_1795411965915.jpg', '#finance', 'between_listings', TRUE, 0),
  ('partner-detail-1', 'Pirelli Diablo & Akrapovič Official Fitment Desk', 'Bundle OEM titanium exhausts or track tires with up to 90% showroom loan approval.', '/assets/generated/partner_banner_performance_1795411965915.jpg', '#accessories', 'detail_page', TRUE, 0)
ON CONFLICT (id) DO NOTHING;

-- Seed Auto News & Expert Reviews
INSERT INTO public.auto_news (id, title, category, image_url, summary, created_at)
VALUES
  ('news-1', '2025 Superbike Track Test: Inline-4 vs V4 Telemetry Breakdown', 'Reviews', '/assets/generated/news_superbike_launch_1795411965373.jpg', 'Our master dyno technicians put flagship liter-class superbikes through back-to-back telemetry runs in Hyderabad. We cover mid-range torque curves, quickshifter calibration, electronics intervention at lean angle, and key inspection checkpoints when buying a pre-owned track machine.', '2025-02-14T09:00:00Z'),
  ('news-2', 'Pre-Owned Supercar Checklist: 150-Point Carbon Brake & PDK Guide', 'Buying Guide', '/assets/generated/news_supercar_review_1795411965067.jpg', 'Buying a pre-owned Porsche 911 or AMG coupe requires far more than an exterior walkaround. Learn how our diagnostics bay verifies over-rev DME logs, dual-clutch hydraulic pressure, ceramic rotor wear density, and clean RTO NOC clearance before listing any supercar.', '2025-02-10T11:30:00Z'),
  ('news-3', 'Best Urban Budget Bikes & Scooters Under ₹2 Lakhs for Daily Rides', 'Launches', '/assets/generated/news_budget_commuter_1795411965542.jpg', 'From 45 km/l daily commuters and reliable family scooters to 350cc-650cc retro roadsters, budget two-wheelers remain India''s smartest everyday value. We rank low-maintenance models with verified service records, warranty coverage, and easy 15-minute showroom EMI approvals.', '2025-02-05T08:15:00Z')
ON CONFLICT (id) DO NOTHING;

-- Seed Showroom Supercar Sample (Additive)
INSERT INTO public.bikes (id, name, brand, category, year, km, engine, hp, price_raw, price, location, image_url, badge, fuel, acceleration, tagline, addon_name, addon_price)
VALUES
  ('bike-8', 'PORSCHE 911 CARRERA S (992)', 'Porsche', 'Supercars', 2023, '4,800 km', '2981 cc Twin-Turbo Flat-6', '443 hp', 18500000, '₹1,85,00,000', 'Hyderabad – Main Superbike Showroom', '/assets/generated/news_supercar_review_1795411965067.jpg', 'CERTIFIED SUPERCAR', 'Petrol', '3.5s', '8-speed PDK dual-clutch rear-engine icon with Sport Chrono.', 'Porsche Tequipment Carbon Package', '₹2,40,000')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  brand = EXCLUDED.brand,
  category = EXCLUDED.category,
  price = EXCLUDED.price,
  price_raw = EXCLUDED.price_raw,
  image_url = EXCLUDED.image_url;

