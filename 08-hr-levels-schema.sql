-- Table 8: HR Levels
-- Purpose: Manages organizational hierarchy levels with bilingual support
-- Created: 2025-09-29

CREATE TABLE public.hr_levels (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  level_name_en character varying(100) NOT NULL,
  level_name_ar character varying(100) NOT NULL,
  level_order integer NOT NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_levels_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_levels_name_en 
  ON public.hr_levels USING btree (level_name_en) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_levels_name_ar 
  ON public.hr_levels USING btree (level_name_ar) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_levels_order 
  ON public.hr_levels USING btree (level_order) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_levels_active 
  ON public.hr_levels USING btree (is_active) TABLESPACE pg_default;

-- Unique constraint on level_order to prevent duplicate ordering
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_levels_order_unique 
  ON public.hr_levels USING btree (level_order) WHERE is_active = true;

-- Comments for documentation
COMMENT ON TABLE public.hr_levels IS 'Organizational hierarchy levels with bilingual (English/Arabic) support and ordering';
COMMENT ON COLUMN public.hr_levels.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_levels.level_name_en IS 'Level name in English (required)';
COMMENT ON COLUMN public.hr_levels.level_name_ar IS 'Level name in Arabic (required)';
COMMENT ON COLUMN public.hr_levels.level_order IS 'Numeric order for level hierarchy (required, unique for active levels)';
COMMENT ON COLUMN public.hr_levels.is_active IS 'Whether the level is currently active/operational';
COMMENT ON COLUMN public.hr_levels.created_at IS 'Timestamp when the record was created';