-- Create hr_positions table for managing HR position definitions
-- This table stores position titles with department and level associations

-- Create the hr_positions table
CREATE TABLE IF NOT EXISTS public.hr_positions (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    position_title_en CHARACTER VARYING(100) NOT NULL,
    position_title_ar CHARACTER VARYING(100) NOT NULL,
    department_id UUID NOT NULL,
    level_id UUID NOT NULL,
    is_active BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_positions_pkey PRIMARY KEY (id),
    CONSTRAINT hr_positions_department_id_fkey 
        FOREIGN KEY (department_id) REFERENCES hr_departments (id),
    CONSTRAINT hr_positions_level_id_fkey 
        FOREIGN KEY (level_id) REFERENCES hr_levels (id)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_positions_department_id 
ON public.hr_positions (department_id);

CREATE INDEX IF NOT EXISTS idx_hr_positions_level_id 
ON public.hr_positions (level_id);

CREATE INDEX IF NOT EXISTS idx_hr_positions_active 
ON public.hr_positions (is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_positions_title_en 
ON public.hr_positions (position_title_en);

CREATE INDEX IF NOT EXISTS idx_hr_positions_title_ar 
ON public.hr_positions (position_title_ar);

CREATE INDEX IF NOT EXISTS idx_hr_positions_dept_level 
ON public.hr_positions (department_id, level_id) 
WHERE is_active = true;

-- Create text search indexes for both languages
CREATE INDEX IF NOT EXISTS idx_hr_positions_search_en 
ON public.hr_positions USING gin (to_tsvector('english', position_title_en));

CREATE INDEX IF NOT EXISTS idx_hr_positions_search_ar 
ON public.hr_positions USING gin (to_tsvector('arabic', position_title_ar));

-- Add unique constraints for active positions
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_positions_unique_title_en 
ON public.hr_positions (LOWER(position_title_en), department_id) 
WHERE is_active = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_positions_unique_title_ar 
ON public.hr_positions (LOWER(position_title_ar), department_id) 
WHERE is_active = true;

-- Add updated_at column and trigger
ALTER TABLE public.hr_positions 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- Add position_name columns for compatibility
ALTER TABLE public.hr_positions 
ADD COLUMN IF NOT EXISTS position_name_en CHARACTER VARYING(100);

ALTER TABLE public.hr_positions 
ADD COLUMN IF NOT EXISTS position_name_ar CHARACTER VARYING(100);

-- Update position_name columns from position_title columns
UPDATE public.hr_positions 
SET position_name_en = position_title_en,
    position_name_ar = position_title_ar
WHERE position_name_en IS NULL OR position_name_ar IS NULL;

CREATE OR REPLACE FUNCTION update_hr_positions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    -- Keep position_name in sync with position_title
    NEW.position_name_en = NEW.position_title_en;
    NEW.position_name_ar = NEW.position_title_ar;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_positions_updated_at 
BEFORE UPDATE ON hr_positions 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_positions_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_positions 
ADD CONSTRAINT chk_position_title_en_not_empty 
CHECK (TRIM(position_title_en) != '');

ALTER TABLE public.hr_positions 
ADD CONSTRAINT chk_position_title_ar_not_empty 
CHECK (TRIM(position_title_ar) != '');

-- Add table and column comments
COMMENT ON TABLE public.hr_positions IS 'HR positions with bilingual titles and organizational hierarchy';
COMMENT ON COLUMN public.hr_positions.id IS 'Unique identifier for the position';
COMMENT ON COLUMN public.hr_positions.position_title_en IS 'Position title in English';
COMMENT ON COLUMN public.hr_positions.position_title_ar IS 'Position title in Arabic';
COMMENT ON COLUMN public.hr_positions.position_name_en IS 'Position name in English (compatibility)';
COMMENT ON COLUMN public.hr_positions.position_name_ar IS 'Position name in Arabic (compatibility)';
COMMENT ON COLUMN public.hr_positions.department_id IS 'Reference to the department';
COMMENT ON COLUMN public.hr_positions.level_id IS 'Reference to the organizational level';
COMMENT ON COLUMN public.hr_positions.is_active IS 'Whether the position is currently active';
COMMENT ON COLUMN public.hr_positions.created_at IS 'Timestamp when the position was created';
COMMENT ON COLUMN public.hr_positions.updated_at IS 'Timestamp when the position was last updated';

-- Create view for active positions with details
CREATE OR REPLACE VIEW active_positions AS
SELECT 
    p.id,
    p.position_title_en,
    p.position_title_ar,
    p.position_name_en,
    p.position_name_ar,
    d.department_name_en,
    d.department_name_ar,
    l.level_name_en,
    l.level_name_ar,
    l.level_order,
    p.created_at,
    p.updated_at
FROM hr_positions p
JOIN hr_departments d ON p.department_id = d.id
JOIN hr_levels l ON p.level_id = l.id
WHERE p.is_active = true 
  AND d.is_active = true 
  AND l.is_active = true
ORDER BY d.department_name_en, l.level_order, p.position_title_en;

-- Create function to get position by language
CREATE OR REPLACE FUNCTION get_position_title(pos_id UUID, lang_code VARCHAR DEFAULT 'en')
RETURNS VARCHAR AS $$
BEGIN
    RETURN CASE 
        WHEN lang_code = 'ar' THEN 
            (SELECT position_title_ar FROM hr_positions WHERE id = pos_id)
        ELSE 
            (SELECT position_title_en FROM hr_positions WHERE id = pos_id)
    END;
END;
$$ LANGUAGE plpgsql;

-- Create function to sync user roles (placeholder)
CREATE OR REPLACE FUNCTION sync_user_roles_from_positions()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will sync user roles based on position changes
    -- Implementation depends on your user role system
    
    IF TG_OP = 'INSERT' THEN
        RAISE NOTICE 'Position created: % (ID: %)', NEW.position_title_en, NEW.id;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        RAISE NOTICE 'Position updated: % (ID: %)', NEW.position_title_en, NEW.id;
        
        -- If position is deactivated, handle role changes
        IF OLD.is_active = true AND NEW.is_active = false THEN
            RAISE NOTICE 'Position deactivated: %', NEW.position_title_en;
            -- Add logic to handle role changes for employees in this position
        END IF;
        
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        RAISE NOTICE 'Position deleted: % (ID: %)', OLD.position_title_en, OLD.id;
        -- Add logic to handle role changes for employees who had this position
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create function to get positions by department
CREATE OR REPLACE FUNCTION get_department_positions(dept_id UUID, active_only BOOLEAN DEFAULT true)
RETURNS TABLE(
    position_id UUID,
    position_title_en VARCHAR,
    position_title_ar VARCHAR,
    level_name_en VARCHAR,
    level_name_ar VARCHAR,
    level_order INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.position_title_en,
        p.position_title_ar,
        l.level_name_en,
        l.level_name_ar,
        l.level_order
    FROM hr_positions p
    JOIN hr_levels l ON p.level_id = l.id
    WHERE p.department_id = dept_id
      AND (NOT active_only OR p.is_active = true)
      AND (NOT active_only OR l.is_active = true)
    ORDER BY l.level_order, p.position_title_en;
END;
$$ LANGUAGE plpgsql;

-- Create function to get positions by level
CREATE OR REPLACE FUNCTION get_level_positions(lvl_id UUID, active_only BOOLEAN DEFAULT true)
RETURNS TABLE(
    position_id UUID,
    position_title_en VARCHAR,
    position_title_ar VARCHAR,
    department_name_en VARCHAR,
    department_name_ar VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.position_title_en,
        p.position_title_ar,
        d.department_name_en,
        d.department_name_ar
    FROM hr_positions p
    JOIN hr_departments d ON p.department_id = d.id
    WHERE p.level_id = lvl_id
      AND (NOT active_only OR p.is_active = true)
      AND (NOT active_only OR d.is_active = true)
    ORDER BY d.department_name_en, p.position_title_en;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger for syncing roles
CREATE TRIGGER sync_roles_on_position_changes
AFTER INSERT OR DELETE OR UPDATE ON hr_positions 
FOR EACH ROW 
EXECUTE FUNCTION sync_user_roles_from_positions();

RAISE NOTICE 'hr_positions table created with role synchronization and organizational features';