-- Reusable "Offer Context" list for the Generate Flyer (AI) workflow. The Offer Context tells the
-- AI what type of promotion is being created (general supermarket, fruit & veg, bakery, Ramadan,
-- etc.) so it can pick a matching visual direction — it is internal AI guidance only and must never
-- be printed on the generated flyer. See "Do not delete/offer_context_ai_flyer_spec.md" for the
-- full spec this implements, and AiFlyerGenerator.svelte for where it's selected and threaded
-- through design/artwork/improve.
BEGIN;

CREATE TABLE IF NOT EXISTS public.flyer_offer_contexts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  description text NOT NULL CHECK (length(description) BETWEEN 1 AND 500),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS flyer_offer_contexts_sort_order_idx ON public.flyer_offer_contexts(sort_order) WHERE is_active;

ALTER TABLE public.flyer_offer_contexts ENABLE ROW LEVEL SECURITY;
-- Read-only from the app (dropdown); only the active contexts list is ever needed client-side.
-- Rows are managed by migration/service role for now — no admin UI for this table yet.
GRANT SELECT ON public.flyer_offer_contexts TO anon, authenticated;
GRANT ALL ON public.flyer_offer_contexts TO service_role;
DROP POLICY IF EXISTS flyer_offer_contexts_read ON public.flyer_offer_contexts;
CREATE POLICY flyer_offer_contexts_read ON public.flyer_offer_contexts FOR SELECT TO anon, authenticated USING (true);

COMMENT ON TABLE public.flyer_offer_contexts IS 'Internal AI visual-direction guidance for the Generate Flyer workflow. Never displayed on the flyer itself.';

INSERT INTO public.flyer_offer_contexts (name, description, sort_order) VALUES
('General Supermarket Offer', 'A supermarket-wide promotion covering all product categories without focusing on any single department.', 0),
('Fruit & Vegetable Offer', 'A fresh-produce promotion focused on fruits, vegetables, herbs, and leafy greens.', 1),
('Bakery Offer', 'A bakery promotion featuring bread, pastries, cakes, croissants, biscuits, and baked products.', 2),
('Cheese, Bakery, Fruit & Vegetable Offer', 'A combined promotion focused on cheese, bakery products, fresh vegetables, and fruits.', 3),
('Fruit, Vegetable & Bakery Offer', 'A combined fresh-section promotion focused on vegetables, fruits, bread, pastries, and bakery products.', 4),
('Frozen Food Offer', 'A frozen-section promotion covering frozen chicken, seafood, vegetables, fries, snacks, and meals.', 5),
('Grocery Offer', 'A grocery promotion covering rice, flour, sugar, oil, canned goods, spices, sauces, and pantry essentials.', 6),
('Breakfast Offer', 'A breakfast promotion featuring milk, bread, eggs, cheese, cereals, spreads, coffee, and breakfast essentials.', 7),
('Snacks & Sweets Offer', 'A promotion featuring chips, biscuits, chocolates, candies, nuts, wafers, and snacks.', 8),
('Beverage Offer', 'A drinks promotion covering water, juices, soft drinks, energy drinks, and other beverages.', 9),
('Cleaning & Laundry Offer', 'A household-cleaning promotion covering detergents, cleaners, dishwashing products, fabric care, and disinfectants.', 10),
('Personal Care Offer', 'A personal-care promotion covering shampoo, soap, toothpaste, deodorant, skincare, and hygiene products.', 11),
('Baby Products Offer', 'A baby-care promotion covering diapers, wipes, baby food, baby milk, and baby toiletries.', 12),
('Household Essentials Offer', 'A household promotion featuring tissues, disposable products, kitchen supplies, storage products, and home essentials.', 13),
('Healthy Living Offer', 'A health-focused promotion featuring fresh produce, oats, whole grains, low-fat dairy, nuts, water, and healthy foods.', 14),
('Daily Essentials Offer', 'A practical promotion covering frequently purchased grocery, dairy, beverage, fresh-food, and household essentials.', 15),
('Weekend Offer', 'A short-term weekend supermarket promotion featuring selected deals across multiple departments.', 16),
('One-Day Offer', 'A limited one-day promotion featuring selected high-value supermarket deals.', 17),
('Multi-Day Savings Offer', 'A limited two-, three-, or four-day supermarket promotion featuring selected deals across multiple categories.', 18),
('Weekly Offer', 'A weekly supermarket promotion covering grocery, fresh food, dairy, household, beverages, and other products.', 19),
('Monthly Offer', 'A major monthly supermarket promotion featuring discounts across most departments.', 20),
('Mega Sale', 'A high-impact supermarket promotion featuring strong discounts and prominent price messaging across all categories.', 21),
('Save More Offer', 'A value-focused campaign emphasizing savings, reduced prices, multipacks, and everyday essentials.', 22),
('Flash Sale', 'A short-duration promotion featuring highly discounted products for a limited period.', 23),
('Limited Stock Offer', 'A promotion emphasizing selected products available at special prices while stocks last.', 24),
('Salary Week Offer', 'A supermarket promotion designed around salary week with family shopping deals and everyday essentials.', 25),
('Month-End Offer', 'A month-end promotion featuring strong savings across grocery, household, and everyday essentials.', 26),
('Grand Opening Offer', 'A celebratory supermarket opening campaign featuring strong deals across all departments.', 27),
('Anniversary Offer', 'A supermarket anniversary promotion featuring celebratory branding and special discounts across multiple categories.', 28),
('Ramadan Offer', 'A Ramadan supermarket promotion covering dates, rice, oil, juices, dairy, frozen foods, cooking essentials, and household products.', 29),
('Iftar & Suhoor Offer', 'A Ramadan meal promotion covering dates, juices, dairy, bread, cereals, frozen foods, and meal essentials.', 30),
('Eid Al-Fitr Offer', 'A festive Eid Al-Fitr supermarket promotion covering groceries, sweets, beverages, meat, dairy, and celebration essentials.', 31),
('Eid Al-Adha Offer', 'An Eid Al-Adha supermarket promotion focused on meat, rice, beverages, groceries, and family celebration products.', 32),
('Saudi National Day Offer', 'A supermarket-wide Saudi National Day promotion using Saudi-inspired celebratory elements without focusing on one product category.', 33),
('Saudi Founding Day Offer', 'A supermarket promotion inspired by Saudi heritage and traditional visual elements, covering multiple product categories.', 34),
('Hajj & Umrah Offer', 'A seasonal promotion featuring water, snacks, travel essentials, personal-care items, and convenient grocery products.', 35),
('Summer Offer', 'A summer promotion focused on water, juices, soft drinks, fruits, ice cream, and refreshing products.', 36),
('Winter Offer', 'A winter promotion featuring coffee, tea, soups, chocolates, bakery products, and seasonal comfort foods.', 37),
('Back-to-School Offer', 'A school-season promotion covering snacks, juices, milk, stationery, lunch products, and family essentials.', 38),
('BBQ & Picnic Offer', 'An outdoor-food promotion featuring meat, chicken, sauces, beverages, snacks, disposable items, and picnic essentials.', 39),
('Kids Offer', 'A child-focused promotion featuring milk, cereals, juices, biscuits, snacks, chocolates, and family-friendly products.', 40),
('Loyalty Member Offer', 'An exclusive supermarket promotion featuring special prices and selected deals for loyalty-program members.', 41)
ON CONFLICT DO NOTHING;

COMMIT;
