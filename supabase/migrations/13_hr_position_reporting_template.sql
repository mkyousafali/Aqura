-- Create hr_position_reporting_template table for managing reporting hierarchy
-- This table defines the reporting structure template for positions with up to 5 management levels

-- Create the hr_position_reporting_template table
CREATE TABLE IF NOT EXISTS public.hr_position_reporting_template (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    subordinate_position_id UUID NOT NULL,
    manager_position_1 UUID NULL,
    manager_position_2 UUID NULL,
    manager_position_3 UUID NULL,
    manager_position_4 UUID NULL,
    manager_position_5 UUID NULL,
    is_active BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_position_reporting_template_pkey PRIMARY KEY (id),
    CONSTRAINT hr_position_reporting_template_subordinate_position_id_key 
        UNIQUE (subordinate_position_id),
    CONSTRAINT hr_position_reporting_template_subordinate_position_id_fkey 
        FOREIGN KEY (subordinate_position_id) REFERENCES hr_positions (id),
    CONSTRAINT hr_position_reporting_template_manager_position_1_fkey 
        FOREIGN KEY (manager_position_1) REFERENCES hr_positions (id),
    CONSTRAINT hr_position_reporting_template_manager_position_2_fkey 
        FOREIGN KEY (manager_position_2) REFERENCES hr_positions (id),
    CONSTRAINT hr_position_reporting_template_manager_position_3_fkey 
        FOREIGN KEY (manager_position_3) REFERENCES hr_positions (id),
    CONSTRAINT hr_position_reporting_template_manager_position_4_fkey 
        FOREIGN KEY (manager_position_4) REFERENCES hr_positions (id),
    CONSTRAINT hr_position_reporting_template_manager_position_5_fkey 
        FOREIGN KEY (manager_position_5) REFERENCES hr_positions (id),
    CONSTRAINT chk_no_self_report_1 
        CHECK (subordinate_position_id <> manager_position_1),
    CONSTRAINT chk_no_self_report_2 
        CHECK (subordinate_position_id <> manager_position_2),
    CONSTRAINT chk_no_self_report_3 
        CHECK (subordinate_position_id <> manager_position_3),
    CONSTRAINT chk_no_self_report_4 
        CHECK (subordinate_position_id <> manager_position_4),
    CONSTRAINT chk_no_self_report_5 
        CHECK (subordinate_position_id <> manager_position_5)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_position_template_subordinate 
ON public.hr_position_reporting_template USING btree (subordinate_position_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr1 
ON public.hr_position_reporting_template USING btree (manager_position_1) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr2 
ON public.hr_position_reporting_template USING btree (manager_position_2) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr3 
ON public.hr_position_reporting_template USING btree (manager_position_3) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr4 
ON public.hr_position_reporting_template USING btree (manager_position_4) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_mgr5 
ON public.hr_position_reporting_template USING btree (manager_position_5) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_hr_position_template_active 
ON public.hr_position_reporting_template (is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_created_at 
ON public.hr_position_reporting_template (created_at DESC);

-- Create composite indexes for hierarchy queries
CREATE INDEX IF NOT EXISTS idx_hr_position_template_hierarchy_1 
ON public.hr_position_reporting_template (manager_position_1, subordinate_position_id) 
WHERE manager_position_1 IS NOT NULL AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_position_template_hierarchy_2 
ON public.hr_position_reporting_template (manager_position_2, subordinate_position_id) 
WHERE manager_position_2 IS NOT NULL AND is_active = true;

-- Add updated_at column and trigger
ALTER TABLE public.hr_position_reporting_template 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_position_reporting_template_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_position_reporting_template_updated_at 
BEFORE UPDATE ON hr_position_reporting_template 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_position_reporting_template_updated_at();

-- Add additional validation constraints
ALTER TABLE public.hr_position_reporting_template 
ADD CONSTRAINT chk_hierarchical_order 
CHECK (
    (manager_position_1 IS NOT NULL) OR 
    (manager_position_1 IS NULL AND manager_position_2 IS NULL AND 
     manager_position_3 IS NULL AND manager_position_4 IS NULL AND manager_position_5 IS NULL)
);

ALTER TABLE public.hr_position_reporting_template 
ADD CONSTRAINT chk_no_duplicate_managers 
CHECK (
    (manager_position_1 IS NULL OR manager_position_1 NOT IN (manager_position_2, manager_position_3, manager_position_4, manager_position_5)) AND
    (manager_position_2 IS NULL OR manager_position_2 NOT IN (manager_position_3, manager_position_4, manager_position_5)) AND
    (manager_position_3 IS NULL OR manager_position_3 NOT IN (manager_position_4, manager_position_5)) AND
    (manager_position_4 IS NULL OR manager_position_4 <> manager_position_5)
);

-- Add table and column comments
COMMENT ON TABLE public.hr_position_reporting_template IS 'Reporting hierarchy template defining manager-subordinate relationships for positions';
COMMENT ON COLUMN public.hr_position_reporting_template.id IS 'Unique identifier for the reporting template';
COMMENT ON COLUMN public.hr_position_reporting_template.subordinate_position_id IS 'Position that reports to managers';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_1 IS 'Direct manager position (level 1)';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_2 IS 'Second level manager position';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_3 IS 'Third level manager position';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_4 IS 'Fourth level manager position';
COMMENT ON COLUMN public.hr_position_reporting_template.manager_position_5 IS 'Fifth level manager position';
COMMENT ON COLUMN public.hr_position_reporting_template.is_active IS 'Whether this reporting template is currently active';
COMMENT ON COLUMN public.hr_position_reporting_template.created_at IS 'Timestamp when the template was created';
COMMENT ON COLUMN public.hr_position_reporting_template.updated_at IS 'Timestamp when the template was last updated';

-- Create view for active reporting relationships
CREATE OR REPLACE VIEW active_reporting_structure AS
SELECT 
    rt.id,
    rt.subordinate_position_id,
    sp.position_name_en as subordinate_position_name,
    rt.manager_position_1,
    mp1.position_name_en as manager_1_name,
    rt.manager_position_2,
    mp2.position_name_en as manager_2_name,
    rt.manager_position_3,
    mp3.position_name_en as manager_3_name,
    rt.manager_position_4,
    mp4.position_name_en as manager_4_name,
    rt.manager_position_5,
    mp5.position_name_en as manager_5_name,
    rt.created_at,
    rt.updated_at
FROM hr_position_reporting_template rt
JOIN hr_positions sp ON rt.subordinate_position_id = sp.id
LEFT JOIN hr_positions mp1 ON rt.manager_position_1 = mp1.id
LEFT JOIN hr_positions mp2 ON rt.manager_position_2 = mp2.id
LEFT JOIN hr_positions mp3 ON rt.manager_position_3 = mp3.id
LEFT JOIN hr_positions mp4 ON rt.manager_position_4 = mp4.id
LEFT JOIN hr_positions mp5 ON rt.manager_position_5 = mp5.id
WHERE rt.is_active = true
ORDER BY sp.position_name_en;

-- Create function to get position hierarchy
CREATE OR REPLACE FUNCTION get_position_hierarchy(pos_id UUID)
RETURNS TABLE(
    level_number INTEGER,
    position_id UUID,
    position_name VARCHAR,
    is_current_position BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH hierarchy AS (
        SELECT 
            5 as level_number,
            rt.manager_position_5 as position_id,
            false as is_current_position
        FROM hr_position_reporting_template rt
        WHERE rt.subordinate_position_id = pos_id 
          AND rt.is_active = true
          AND rt.manager_position_5 IS NOT NULL
        
        UNION ALL
        
        SELECT 
            4 as level_number,
            rt.manager_position_4 as position_id,
            false as is_current_position
        FROM hr_position_reporting_template rt
        WHERE rt.subordinate_position_id = pos_id 
          AND rt.is_active = true
          AND rt.manager_position_4 IS NOT NULL
        
        UNION ALL
        
        SELECT 
            3 as level_number,
            rt.manager_position_3 as position_id,
            false as is_current_position
        FROM hr_position_reporting_template rt
        WHERE rt.subordinate_position_id = pos_id 
          AND rt.is_active = true
          AND rt.manager_position_3 IS NOT NULL
        
        UNION ALL
        
        SELECT 
            2 as level_number,
            rt.manager_position_2 as position_id,
            false as is_current_position
        FROM hr_position_reporting_template rt
        WHERE rt.subordinate_position_id = pos_id 
          AND rt.is_active = true
          AND rt.manager_position_2 IS NOT NULL
        
        UNION ALL
        
        SELECT 
            1 as level_number,
            rt.manager_position_1 as position_id,
            false as is_current_position
        FROM hr_position_reporting_template rt
        WHERE rt.subordinate_position_id = pos_id 
          AND rt.is_active = true
          AND rt.manager_position_1 IS NOT NULL
        
        UNION ALL
        
        SELECT 
            0 as level_number,
            pos_id as position_id,
            true as is_current_position
    )
    SELECT 
        h.level_number,
        h.position_id,
        p.position_name_en,
        h.is_current_position
    FROM hierarchy h
    JOIN hr_positions p ON h.position_id = p.id
    WHERE h.position_id IS NOT NULL
    ORDER BY h.level_number DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get subordinate positions
CREATE OR REPLACE FUNCTION get_subordinate_positions(mgr_pos_id UUID, level_number INTEGER DEFAULT 1)
RETURNS TABLE(
    subordinate_position_id UUID,
    subordinate_position_name VARCHAR,
    reporting_level INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rt.subordinate_position_id,
        p.position_name_en,
        level_number as reporting_level
    FROM hr_position_reporting_template rt
    JOIN hr_positions p ON rt.subordinate_position_id = p.id
    WHERE rt.is_active = true
      AND (
          (level_number = 1 AND rt.manager_position_1 = mgr_pos_id) OR
          (level_number = 2 AND rt.manager_position_2 = mgr_pos_id) OR
          (level_number = 3 AND rt.manager_position_3 = mgr_pos_id) OR
          (level_number = 4 AND rt.manager_position_4 = mgr_pos_id) OR
          (level_number = 5 AND rt.manager_position_5 = mgr_pos_id)
      )
    ORDER BY p.position_name_en;
END;
$$ LANGUAGE plpgsql;

-- Create function to validate reporting structure
CREATE OR REPLACE FUNCTION validate_reporting_structure()
RETURNS TABLE(
    template_id UUID,
    subordinate_position VARCHAR,
    issue_type VARCHAR,
    issue_description TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Check for circular reporting
    WITH RECURSIVE circular_check AS (
        SELECT 
            rt.subordinate_position_id,
            rt.manager_position_1 as manager_id,
            1 as level,
            ARRAY[rt.subordinate_position_id] as path
        FROM hr_position_reporting_template rt
        WHERE rt.is_active = true AND rt.manager_position_1 IS NOT NULL
        
        UNION ALL
        
        SELECT 
            cc.subordinate_position_id,
            rt.manager_position_1,
            cc.level + 1,
            cc.path || rt.manager_position_1
        FROM circular_check cc
        JOIN hr_position_reporting_template rt ON cc.manager_id = rt.subordinate_position_id
        WHERE rt.is_active = true 
          AND rt.manager_position_1 IS NOT NULL
          AND cc.level < 10
          AND NOT (rt.manager_position_1 = ANY(cc.path))
    )
    SELECT 
        rt.id,
        sp.position_name_en,
        'circular_reporting'::VARCHAR,
        'Circular reporting detected in hierarchy'::TEXT
    FROM hr_position_reporting_template rt
    JOIN hr_positions sp ON rt.subordinate_position_id = sp.id
    WHERE rt.is_active = true
      AND rt.subordinate_position_id IN (
          SELECT subordinate_position_id 
          FROM circular_check 
          WHERE manager_id = subordinate_position_id
      );
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_position_reporting_template table created with hierarchy management features';