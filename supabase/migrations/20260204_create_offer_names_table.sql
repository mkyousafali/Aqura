-- Create offer_names table with predefined offer names
-- Primary key format: OF1, OF2, OF3, etc.

CREATE TABLE public.offer_names (
  id text NOT NULL,
  name_en text NOT NULL,
  name_ar text NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT offer_names_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Insert predefined offer names
INSERT INTO public.offer_names (id, name_en, name_ar) VALUES
('OF1', 'Week 1', 'الأسبوع 1'),
('OF2', 'Week 2', 'الأسبوع 2'),
('OF3', 'Week 3', 'الأسبوع 3'),
('OF4', 'Week 4 Salary Week', 'الأسبوع 4 أسبوع الراتب'),
('OF5', 'Ramadan Special', 'عرض رمضان'),
('OF6', 'Eid al-Adha Special', 'عرض عيد الأضحى'),
('OF7', 'Eid al-Fitr Special', 'عرض عيد الفطر'),
('OF8', 'Saudi National Day Special', 'عرض اليوم الوطني السعودي'),
('OF9', 'Saudi Foundation Day Special', 'عرض يوم التأسيس السعودي'),
('OF10', '1 Day Departments', 'يوم واحد للأقسام'),
('OF11', '1 Day Retired Salary', 'يوم واحد راتب المتقاعدين'),
('OF12', '1 Day Salary', 'يوم واحد راتب'),
('OF13', '2 Days Retired Salary', 'يومان راتب المتقاعدين'),
('OF14', '2 Days Salary', 'يومان راتب'),
('OF15', '3 Days Retired Salary', '3 أيام راتب المتقاعدين'),
('OF16', '3 Days Salary', '3 أيام راتب'),
('OF17', '4 Days Retired Salary', '4 أيام راتب المتقاعدين'),
('OF18', '4 Days Salary', '4 أيام راتب'),
('OF19', '1 Day Special', 'عرض يوم واحد'),
('OF20', '2 Days Special', 'عرض يومان'),
('OF21', '3 Days Special', 'عرض 3 أيام'),
('OF22', '4 Days Special', 'عرض 4 أيام');

-- Add offer_name_id to flyer_offers table
ALTER TABLE public.flyer_offers
ADD COLUMN offer_name_id text NULL;

-- Add foreign key constraint
ALTER TABLE public.flyer_offers
ADD CONSTRAINT flyer_offers_offer_name_id_fkey 
FOREIGN KEY (offer_name_id) 
REFERENCES offer_names (id) 
ON DELETE SET NULL;

-- Add index
CREATE INDEX IF NOT EXISTS idx_flyer_offers_offer_name_id 
ON public.flyer_offers 
USING btree (offer_name_id) 
TABLESPACE pg_default;

-- Add comments
COMMENT ON TABLE public.offer_names IS 'Predefined offer name templates';
COMMENT ON COLUMN public.flyer_offers.offer_name_id IS 'Reference to predefined offer name from offer_names table';
