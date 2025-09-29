-- Table 2: Branches
-- Purpose: Manages organization branches with bilingual support
-- Created: 2025-09-29

CREATE TABLE public.branches (
  id bigserial NOT NULL,
  name_en character varying(255) NOT NULL,
  name_ar character varying(255) NOT NULL,
  location_en character varying(500) NOT NULL,
  location_ar character varying(500) NOT NULL,
  is_active boolean NULL DEFAULT true,
  is_main_branch boolean NULL DEFAULT false,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  created_by bigint NULL,
  updated_by bigint NULL,
  CONSTRAINT branches_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_branches_name_en 
  ON public.branches USING btree (name_en) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_name_ar 
  ON public.branches USING btree (name_ar) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_active 
  ON public.branches USING btree (is_active) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_main 
  ON public.branches USING btree (is_main_branch) TABLESPACE pg_default;

-- Trigger to automatically update the updated_at column
CREATE TRIGGER trigger_update_branches_updated_at 
  BEFORE UPDATE ON branches 
  FOR EACH ROW 
  EXECUTE FUNCTION update_branches_updated_at();

-- Comments for documentation
COMMENT ON TABLE public.branches IS 'Organization branches with bilingual (English/Arabic) support';
COMMENT ON COLUMN public.branches.id IS 'Primary key - Auto-incrementing big integer';
COMMENT ON COLUMN public.branches.name_en IS 'Branch name in English (required)';
COMMENT ON COLUMN public.branches.name_ar IS 'Branch name in Arabic (required)';
COMMENT ON COLUMN public.branches.location_en IS 'Branch location/address in English (required)';
COMMENT ON COLUMN public.branches.location_ar IS 'Branch location/address in Arabic (required)';
COMMENT ON COLUMN public.branches.is_active IS 'Whether the branch is currently active/operational';
COMMENT ON COLUMN public.branches.is_main_branch IS 'Whether this is the main/headquarters branch';
COMMENT ON COLUMN public.branches.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.branches.updated_at IS 'Timestamp when the record was last updated';
COMMENT ON COLUMN public.branches.created_by IS 'ID of user who created this record';
COMMENT ON COLUMN public.branches.updated_by IS 'ID of user who last updated this record';