-- Table 11: HR Positions
-- Purpose: Manages job positions with bilingual support and organizational hierarchy
-- Created: 2025-09-29

CREATE TABLE public.hr_positions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  position_title_en character varying(100) NOT NULL,
  position_title_ar character varying(100) NOT NULL,
  department_id uuid NOT NULL,
  level_id uuid NOT NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_positions_pkey PRIMARY KEY (id),
  CONSTRAINT hr_positions_department_id_fkey FOREIGN KEY (department_id) REFERENCES hr_departments (id),
  CONSTRAINT hr_positions_level_id_fkey FOREIGN KEY (level_id) REFERENCES hr_levels (id)
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_positions_title_en 
  ON public.hr_positions USING btree (position_title_en) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_positions_title_ar 
  ON public.hr_positions USING btree (position_title_ar) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_positions_department_id 
  ON public.hr_positions USING btree (department_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_positions_level_id 
  ON public.hr_positions USING btree (level_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_positions_active 
  ON public.hr_positions USING btree (is_active) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_positions_dept_level 
  ON public.hr_positions USING btree (department_id, level_id) TABLESPACE pg_default;

-- Trigger to synchronize user roles when positions change
CREATE TRIGGER sync_roles_on_position_changes
  AFTER INSERT OR DELETE OR UPDATE 
  ON hr_positions 
  FOR EACH ROW 
  EXECUTE FUNCTION sync_user_roles_from_positions();

-- Comments for documentation
COMMENT ON TABLE public.hr_positions IS 'Job positions with bilingual support linked to departments and organizational levels';
COMMENT ON COLUMN public.hr_positions.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_positions.position_title_en IS 'Position title in English (required)';
COMMENT ON COLUMN public.hr_positions.position_title_ar IS 'Position title in Arabic (required)';
COMMENT ON COLUMN public.hr_positions.department_id IS 'Foreign key reference to hr_departments table (required)';
COMMENT ON COLUMN public.hr_positions.level_id IS 'Foreign key reference to hr_levels table (required)';
COMMENT ON COLUMN public.hr_positions.is_active IS 'Whether the position is currently active/available';
COMMENT ON COLUMN public.hr_positions.created_at IS 'Timestamp when the record was created';