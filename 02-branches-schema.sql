-- Branches Schema
-- Manages company branches with bilingual support

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

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_branches_name_en ON public.branches USING btree (name_en) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_name_ar ON public.branches USING btree (name_ar) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_active ON public.branches USING btree (is_active) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_main ON public.branches USING btree (is_main_branch) TABLESPACE pg_default;

-- Trigger to automatically update the updated_at column
CREATE TRIGGER trigger_update_branches_updated_at BEFORE
UPDATE ON branches FOR EACH ROW
EXECUTE FUNCTION update_branches_updated_at();