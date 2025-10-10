-- Create quick_task_user_preferences table for managing user-specific quick task preferences
-- This table stores default settings and preferences for each user when creating quick tasks

-- Create the quick_task_user_preferences table
CREATE TABLE IF NOT EXISTS public.quick_task_user_preferences (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    default_branch_id BIGINT NULL,
    default_price_tag CHARACTER VARYING(50) NULL,
    default_issue_type CHARACTER VARYING(100) NULL,
    default_priority CHARACTER VARYING(50) NULL,
    selected_user_ids UUID[] NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT quick_task_user_preferences_pkey PRIMARY KEY (id),
    CONSTRAINT quick_task_user_preferences_user_id_key UNIQUE (user_id),
    CONSTRAINT quick_task_user_preferences_default_branch_id_fkey 
        FOREIGN KEY (default_branch_id) REFERENCES branches (id) ON DELETE SET NULL,
    CONSTRAINT quick_task_user_preferences_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_user 
ON public.quick_task_user_preferences USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_branch 
ON public.quick_task_user_preferences USING btree (default_branch_id) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_priority 
ON public.quick_task_user_preferences (default_priority);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_issue_type 
ON public.quick_task_user_preferences (default_issue_type);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_price_tag 
ON public.quick_task_user_preferences (default_price_tag);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_updated_at 
ON public.quick_task_user_preferences (updated_at DESC);

-- Create GIN index for selected_user_ids array
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_selected_users 
ON public.quick_task_user_preferences USING gin (selected_user_ids);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_quick_task_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_quick_task_user_preferences_updated_at 
BEFORE UPDATE ON quick_task_user_preferences 
FOR EACH ROW 
EXECUTE FUNCTION update_quick_task_user_preferences_updated_at();

-- Add data validation constraints
ALTER TABLE public.quick_task_user_preferences 
ADD CONSTRAINT chk_priority_valid 
CHECK (default_priority IS NULL OR default_priority IN (
    'low', 'medium', 'high', 'urgent', 'critical'
));

ALTER TABLE public.quick_task_user_preferences 
ADD CONSTRAINT chk_issue_type_valid 
CHECK (default_issue_type IS NULL OR default_issue_type IN (
    'bug', 'feature', 'improvement', 'task', 'maintenance', 'urgent', 'other'
));

ALTER TABLE public.quick_task_user_preferences 
ADD CONSTRAINT chk_price_tag_format 
CHECK (default_price_tag IS NULL OR default_price_tag ~ '^[A-Z0-9_-]+$');

-- Add additional columns for enhanced functionality
ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS default_status CHARACTER VARYING(50);

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS default_department_id BIGINT;

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT '{}';

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS display_preferences JSONB DEFAULT '{}';

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS workflow_preferences JSONB DEFAULT '{}';

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS auto_assign_to_self BOOLEAN DEFAULT false;

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS default_estimated_hours DECIMAL(5,2);

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS favorite_templates UUID[];

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS quick_actions JSONB DEFAULT '[]';

ALTER TABLE public.quick_task_user_preferences 
ADD COLUMN IF NOT EXISTS last_used_settings JSONB DEFAULT '{}';

-- Add foreign key for default_department_id if hr_departments table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_departments') THEN
        ALTER TABLE public.quick_task_user_preferences 
        ADD CONSTRAINT quick_task_user_preferences_default_department_id_fkey 
        FOREIGN KEY (default_department_id) REFERENCES hr_departments (id) ON DELETE SET NULL;
    END IF;
END $$;

-- Add validation for additional columns
ALTER TABLE public.quick_task_user_preferences 
ADD CONSTRAINT chk_default_status_valid 
CHECK (default_status IS NULL OR default_status IN (
    'pending', 'in_progress', 'review', 'completed', 'cancelled', 'on_hold'
));

ALTER TABLE public.quick_task_user_preferences 
ADD CONSTRAINT chk_estimated_hours_positive 
CHECK (default_estimated_hours IS NULL OR default_estimated_hours > 0);

ALTER TABLE public.quick_task_user_preferences 
ADD CONSTRAINT chk_estimated_hours_reasonable 
CHECK (default_estimated_hours IS NULL OR default_estimated_hours <= 1000);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_status 
ON public.quick_task_user_preferences (default_status);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_department 
ON public.quick_task_user_preferences (default_department_id);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_auto_assign 
ON public.quick_task_user_preferences (auto_assign_to_self) 
WHERE auto_assign_to_self = true;

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_notification_prefs 
ON public.quick_task_user_preferences USING gin (notification_preferences);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_display_prefs 
ON public.quick_task_user_preferences USING gin (display_preferences);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_workflow_prefs 
ON public.quick_task_user_preferences USING gin (workflow_preferences);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_favorite_templates 
ON public.quick_task_user_preferences USING gin (favorite_templates);

-- Add table and column comments
COMMENT ON TABLE public.quick_task_user_preferences IS 'User-specific preferences and default settings for quick task creation';
COMMENT ON COLUMN public.quick_task_user_preferences.id IS 'Unique identifier for the preferences record';
COMMENT ON COLUMN public.quick_task_user_preferences.user_id IS 'Reference to the user (unique)';
COMMENT ON COLUMN public.quick_task_user_preferences.default_branch_id IS 'Default branch for new tasks';
COMMENT ON COLUMN public.quick_task_user_preferences.default_price_tag IS 'Default price tag/label for tasks';
COMMENT ON COLUMN public.quick_task_user_preferences.default_issue_type IS 'Default issue type for new tasks';
COMMENT ON COLUMN public.quick_task_user_preferences.default_priority IS 'Default priority level for new tasks';
COMMENT ON COLUMN public.quick_task_user_preferences.selected_user_ids IS 'Array of frequently selected user IDs';
COMMENT ON COLUMN public.quick_task_user_preferences.default_status IS 'Default status for new tasks';
COMMENT ON COLUMN public.quick_task_user_preferences.default_department_id IS 'Default department for new tasks';
COMMENT ON COLUMN public.quick_task_user_preferences.notification_preferences IS 'Notification settings as JSON';
COMMENT ON COLUMN public.quick_task_user_preferences.display_preferences IS 'UI display preferences as JSON';
COMMENT ON COLUMN public.quick_task_user_preferences.workflow_preferences IS 'Workflow and process preferences as JSON';
COMMENT ON COLUMN public.quick_task_user_preferences.auto_assign_to_self IS 'Whether to automatically assign new tasks to self';
COMMENT ON COLUMN public.quick_task_user_preferences.default_estimated_hours IS 'Default estimated hours for new tasks';
COMMENT ON COLUMN public.quick_task_user_preferences.favorite_templates IS 'Array of favorite task template IDs';
COMMENT ON COLUMN public.quick_task_user_preferences.quick_actions IS 'Quick action buttons configuration as JSON';
COMMENT ON COLUMN public.quick_task_user_preferences.last_used_settings IS 'Last used settings for quick restore';
COMMENT ON COLUMN public.quick_task_user_preferences.created_at IS 'When the preferences were created';
COMMENT ON COLUMN public.quick_task_user_preferences.updated_at IS 'When the preferences were last updated';

-- Create view for preferences with related data
CREATE OR REPLACE VIEW quick_task_user_preferences_detailed AS
SELECT 
    qup.id,
    qup.user_id,
    u.username,
    u.full_name as user_name,
    qup.default_branch_id,
    b.name as default_branch_name,
    qup.default_price_tag,
    qup.default_issue_type,
    qup.default_priority,
    qup.default_status,
    qup.default_department_id,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_departments') 
        THEN (SELECT name FROM hr_departments WHERE id = qup.default_department_id)
        ELSE NULL
    END as default_department_name,
    qup.selected_user_ids,
    qup.notification_preferences,
    qup.display_preferences,
    qup.workflow_preferences,
    qup.auto_assign_to_self,
    qup.default_estimated_hours,
    qup.favorite_templates,
    qup.quick_actions,
    qup.last_used_settings,
    qup.created_at,
    qup.updated_at
FROM quick_task_user_preferences qup
LEFT JOIN users u ON qup.user_id = u.id
LEFT JOIN branches b ON qup.default_branch_id = b.id
ORDER BY qup.updated_at DESC;

-- Create function to get or create user preferences
CREATE OR REPLACE FUNCTION get_or_create_user_preferences(user_id_param UUID)
RETURNS UUID AS $$
DECLARE
    prefs_id UUID;
BEGIN
    -- Try to get existing preferences
    SELECT id INTO prefs_id 
    FROM quick_task_user_preferences 
    WHERE user_id = user_id_param;
    
    -- If not found, create default preferences
    IF prefs_id IS NULL THEN
        INSERT INTO quick_task_user_preferences (
            user_id,
            default_priority,
            default_issue_type,
            notification_preferences,
            display_preferences,
            workflow_preferences
        ) VALUES (
            user_id_param,
            'medium',
            'task',
            '{"email": true, "push": true, "in_app": true}',
            '{"theme": "light", "density": "normal", "sidebar_collapsed": false}',
            '{"auto_save": true, "confirm_delete": true, "show_hints": true}'
        ) RETURNING id INTO prefs_id;
    END IF;
    
    RETURN prefs_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update user preferences
CREATE OR REPLACE FUNCTION update_user_preferences(
    user_id_param UUID,
    preferences_data JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
    prefs_id UUID;
BEGIN
    -- Get or create preferences
    prefs_id := get_or_create_user_preferences(user_id_param);
    
    -- Update preferences based on provided data
    UPDATE quick_task_user_preferences 
    SET 
        default_branch_id = COALESCE((preferences_data->>'default_branch_id')::BIGINT, default_branch_id),
        default_price_tag = COALESCE(preferences_data->>'default_price_tag', default_price_tag),
        default_issue_type = COALESCE(preferences_data->>'default_issue_type', default_issue_type),
        default_priority = COALESCE(preferences_data->>'default_priority', default_priority),
        default_status = COALESCE(preferences_data->>'default_status', default_status),
        default_department_id = COALESCE((preferences_data->>'default_department_id')::BIGINT, default_department_id),
        selected_user_ids = COALESCE(
            ARRAY(SELECT jsonb_array_elements_text(preferences_data->'selected_user_ids'))::UUID[], 
            selected_user_ids
        ),
        notification_preferences = COALESCE(preferences_data->'notification_preferences', notification_preferences),
        display_preferences = COALESCE(preferences_data->'display_preferences', display_preferences),
        workflow_preferences = COALESCE(preferences_data->'workflow_preferences', workflow_preferences),
        auto_assign_to_self = COALESCE((preferences_data->>'auto_assign_to_self')::BOOLEAN, auto_assign_to_self),
        default_estimated_hours = COALESCE((preferences_data->>'default_estimated_hours')::DECIMAL(5,2), default_estimated_hours),
        favorite_templates = COALESCE(
            ARRAY(SELECT jsonb_array_elements_text(preferences_data->'favorite_templates'))::UUID[], 
            favorite_templates
        ),
        quick_actions = COALESCE(preferences_data->'quick_actions', quick_actions),
        updated_at = now()
    WHERE id = prefs_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to save last used settings
CREATE OR REPLACE FUNCTION save_last_used_settings(
    user_id_param UUID,
    settings_data JSONB
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Update last used settings
    UPDATE quick_task_user_preferences 
    SET last_used_settings = settings_data,
        updated_at = now()
    WHERE user_id = user_id_param;
    
    -- If no preferences exist, create them
    IF NOT FOUND THEN
        PERFORM get_or_create_user_preferences(user_id_param);
        
        UPDATE quick_task_user_preferences 
        SET last_used_settings = settings_data,
            updated_at = now()
        WHERE user_id = user_id_param;
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Create function to add favorite template
CREATE OR REPLACE FUNCTION add_favorite_template(
    user_id_param UUID,
    template_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    prefs_id UUID;
BEGIN
    -- Get or create preferences
    prefs_id := get_or_create_user_preferences(user_id_param);
    
    -- Add template to favorites if not already present
    UPDATE quick_task_user_preferences 
    SET favorite_templates = array_append(
            COALESCE(favorite_templates, '{}'),
            template_id
        ),
        updated_at = now()
    WHERE id = prefs_id 
      AND NOT (template_id = ANY(COALESCE(favorite_templates, '{}')));
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to remove favorite template
CREATE OR REPLACE FUNCTION remove_favorite_template(
    user_id_param UUID,
    template_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE quick_task_user_preferences 
    SET favorite_templates = array_remove(favorite_templates, template_id),
        updated_at = now()
    WHERE user_id = user_id_param 
      AND template_id = ANY(COALESCE(favorite_templates, '{}'));
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get user preferences with defaults
CREATE OR REPLACE FUNCTION get_user_preferences_with_defaults(user_id_param UUID)
RETURNS TABLE(
    user_id UUID,
    default_branch_id BIGINT,
    default_branch_name VARCHAR,
    default_price_tag VARCHAR,
    default_issue_type VARCHAR,
    default_priority VARCHAR,
    default_status VARCHAR,
    default_department_id BIGINT,
    default_department_name VARCHAR,
    selected_user_ids UUID[],
    notification_preferences JSONB,
    display_preferences JSONB,
    workflow_preferences JSONB,
    auto_assign_to_self BOOLEAN,
    default_estimated_hours DECIMAL,
    favorite_templates UUID[],
    quick_actions JSONB,
    last_used_settings JSONB
) AS $$
BEGIN
    -- Ensure preferences exist
    PERFORM get_or_create_user_preferences(user_id_param);
    
    RETURN QUERY
    SELECT 
        qup.user_id,
        qup.default_branch_id,
        b.name as default_branch_name,
        qup.default_price_tag,
        qup.default_issue_type,
        qup.default_priority,
        qup.default_status,
        qup.default_department_id,
        CASE 
            WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_departments') 
            THEN (SELECT name FROM hr_departments WHERE id = qup.default_department_id)
            ELSE NULL
        END as default_department_name,
        qup.selected_user_ids,
        qup.notification_preferences,
        qup.display_preferences,
        qup.workflow_preferences,
        qup.auto_assign_to_self,
        qup.default_estimated_hours,
        qup.favorite_templates,
        qup.quick_actions,
        qup.last_used_settings
    FROM quick_task_user_preferences qup
    LEFT JOIN branches b ON qup.default_branch_id = b.id
    WHERE qup.user_id = user_id_param;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'quick_task_user_preferences table created with comprehensive user preference management features';