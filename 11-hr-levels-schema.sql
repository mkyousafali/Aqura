-- HR Levels Schema
-- This table stores hierarchical levels with bilingual support (English/Arabic)

CREATE TABLE public.hr_levels (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  level_name_en character varying(100) NOT NULL,
  level_name_ar character varying(100) NOT NULL,
  level_order integer NOT NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_levels_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;