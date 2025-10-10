-- Create branches table for managing company branches
-- This table stores branch information with bilingual support (English/Arabic)

-- Create the branches table
CREATE TABLE IF NOT EXISTS public.branches (
    id BIGSERIAL NOT NULL,
    name_en CHARACTER VARYING(255) NOT NULL,
    name_ar CHARACTER VARYING(255) NOT NULL,
    location_en CHARACTER VARYING(500) NOT NULL,
    location_ar CHARACTER VARYING(500) NOT NULL,
    is_active BOOLEAN NULL DEFAULT true,
    is_main_branch BOOLEAN NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    created_by BIGINT NULL,
    updated_by BIGINT NULL,
    
    CONSTRAINT branches_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_branches_name_en 
ON public.branches USING btree (name_en) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_name_ar 
ON public.branches USING btree (name_ar) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_active 
ON public.branches USING btree (is_active) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_main 
ON public.branches USING btree (is_main_branch) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_branches_active_main 
ON public.branches (is_active, is_main_branch) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_branches_created_at 
ON public.branches (created_at DESC);

-- Create trigger for automatic updated_at timestamp
-- First, create the update function if it doesn't exist
CREATE OR REPLACE FUNCTION update_branches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_update_branches_updated_at 
BEFORE UPDATE ON branches 
FOR EACH ROW 
EXECUTE FUNCTION update_branches_updated_at();

-- Add table and column comments for documentation
COMMENT ON TABLE public.branches IS 'Company branches with bilingual support (English/Arabic)';
COMMENT ON COLUMN public.branches.id IS 'Unique identifier for the branch';
COMMENT ON COLUMN public.branches.name_en IS 'Branch name in English';
COMMENT ON COLUMN public.branches.name_ar IS 'Branch name in Arabic';
COMMENT ON COLUMN public.branches.location_en IS 'Branch location in English';
COMMENT ON COLUMN public.branches.location_ar IS 'Branch location in Arabic';
COMMENT ON COLUMN public.branches.is_active IS 'Whether the branch is currently active';
COMMENT ON COLUMN public.branches.is_main_branch IS 'Whether this is the main/headquarters branch';
COMMENT ON COLUMN public.branches.created_at IS 'Timestamp when the branch was created';
COMMENT ON COLUMN public.branches.updated_at IS 'Timestamp when the branch was last updated';
COMMENT ON COLUMN public.branches.created_by IS 'ID of user who created the branch';
COMMENT ON COLUMN public.branches.updated_by IS 'ID of user who last updated the branch';

-- Add constraint to ensure only one main branch can be active
CREATE UNIQUE INDEX IF NOT EXISTS idx_branches_unique_main_active 
ON public.branches (is_main_branch) 
WHERE is_main_branch = true AND is_active = true;

-- Table, indexes, and trigger created successfully
RAISE NOTICE 'branches table created with indexes, trigger, and constraints';