-- Create hr_levels table for managing HR level/position hierarchy
-- This table stores organizational levels with bilingual support and ordering

-- Create the hr_levels table
CREATE TABLE IF NOT EXISTS public.hr_levels (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    level_name_en CHARACTER VARYING(100) NOT NULL,
    level_name_ar CHARACTER VARYING(100) NOT NULL,
    level_order INTEGER NOT NULL,
    is_active BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_levels_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_levels_order 
ON public.hr_levels (level_order);

CREATE INDEX IF NOT EXISTS idx_hr_levels_active 
ON public.hr_levels (is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_levels_name_en 
ON public.hr_levels (level_name_en);

CREATE INDEX IF NOT EXISTS idx_hr_levels_name_ar 
ON public.hr_levels (level_name_ar);

CREATE INDEX IF NOT EXISTS idx_hr_levels_active_order 
ON public.hr_levels (level_order) 
WHERE is_active = true;

-- Create text search indexes for both languages
CREATE INDEX IF NOT EXISTS idx_hr_levels_search_en 
ON public.hr_levels USING gin (to_tsvector('english', level_name_en));

CREATE INDEX IF NOT EXISTS idx_hr_levels_search_ar 
ON public.hr_levels USING gin (to_tsvector('arabic', level_name_ar));

-- Add unique constraints
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_levels_unique_order 
ON public.hr_levels (level_order) 
WHERE is_active = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_levels_unique_name_en 
ON public.hr_levels (LOWER(level_name_en)) 
WHERE is_active = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_levels_unique_name_ar 
ON public.hr_levels (LOWER(level_name_ar)) 
WHERE is_active = true;

-- Add updated_at column and trigger
ALTER TABLE public.hr_levels 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_levels_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_levels_updated_at 
BEFORE UPDATE ON hr_levels 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_levels_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_levels 
ADD CONSTRAINT chk_level_name_en_not_empty 
CHECK (TRIM(level_name_en) != '');

ALTER TABLE public.hr_levels 
ADD CONSTRAINT chk_level_name_ar_not_empty 
CHECK (TRIM(level_name_ar) != '');

ALTER TABLE public.hr_levels 
ADD CONSTRAINT chk_level_order_positive 
CHECK (level_order > 0);

-- Add table and column comments
COMMENT ON TABLE public.hr_levels IS 'HR organizational levels with hierarchy ordering and bilingual support';
COMMENT ON COLUMN public.hr_levels.id IS 'Unique identifier for the level';
COMMENT ON COLUMN public.hr_levels.level_name_en IS 'Level name in English';
COMMENT ON COLUMN public.hr_levels.level_name_ar IS 'Level name in Arabic';
COMMENT ON COLUMN public.hr_levels.level_order IS 'Hierarchical order (1=highest, increasing=lower)';
COMMENT ON COLUMN public.hr_levels.is_active IS 'Whether the level is currently active';
COMMENT ON COLUMN public.hr_levels.created_at IS 'Timestamp when the level was created';
COMMENT ON COLUMN public.hr_levels.updated_at IS 'Timestamp when the level was last updated';

-- Create view for active levels ordered by hierarchy
CREATE OR REPLACE VIEW active_levels AS
SELECT 
    id,
    level_name_en,
    level_name_ar,
    level_order,
    created_at,
    updated_at
FROM hr_levels 
WHERE is_active = true
ORDER BY level_order;

-- Create function to get level by language
CREATE OR REPLACE FUNCTION get_level_name(level_id UUID, lang_code VARCHAR DEFAULT 'en')
RETURNS VARCHAR AS $$
BEGIN
    RETURN CASE 
        WHEN lang_code = 'ar' THEN 
            (SELECT level_name_ar FROM hr_levels WHERE id = level_id)
        ELSE 
            (SELECT level_name_en FROM hr_levels WHERE id = level_id)
    END;
END;
$$ LANGUAGE plpgsql;

-- Create function to reorder levels
CREATE OR REPLACE FUNCTION reorder_levels()
RETURNS VOID AS $$
DECLARE
    level_record RECORD;
    new_order INTEGER := 1;
BEGIN
    FOR level_record IN 
        SELECT id FROM hr_levels 
        WHERE is_active = true 
        ORDER BY level_order, level_name_en
    LOOP
        UPDATE hr_levels 
        SET level_order = new_order, updated_at = now()
        WHERE id = level_record.id;
        
        new_order := new_order + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create function to get next available order
CREATE OR REPLACE FUNCTION get_next_level_order()
RETURNS INTEGER AS $$
BEGIN
    RETURN COALESCE(
        (SELECT MAX(level_order) + 1 FROM hr_levels WHERE is_active = true),
        1
    );
END;
$$ LANGUAGE plpgsql;

-- Create function to move level up/down in hierarchy
CREATE OR REPLACE FUNCTION move_level_order(level_id UUID, direction VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    current_order INTEGER;
    target_order INTEGER;
    target_level_id UUID;
BEGIN
    -- Get current order
    SELECT level_order INTO current_order 
    FROM hr_levels 
    WHERE id = level_id AND is_active = true;
    
    IF current_order IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Determine target order based on direction
    IF direction = 'up' THEN
        target_order := current_order - 1;
    ELSIF direction = 'down' THEN
        target_order := current_order + 1;
    ELSE
        RETURN FALSE;
    END IF;
    
    -- Find level at target order
    SELECT id INTO target_level_id 
    FROM hr_levels 
    WHERE level_order = target_order AND is_active = true;
    
    IF target_level_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Swap orders
    UPDATE hr_levels SET level_order = -1 WHERE id = level_id;
    UPDATE hr_levels SET level_order = current_order WHERE id = target_level_id;
    UPDATE hr_levels SET level_order = target_order WHERE id = level_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_levels table created with hierarchy management and bilingual support';