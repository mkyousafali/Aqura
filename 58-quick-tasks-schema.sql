-- Quick Tasks Schema
-- This schema supports the Quick Task feature with file storage and notifications
-- Properly mapped to existing tables: users, branches, hr_employees, notifications

-- 1. Quick Tasks Table
CREATE TABLE IF NOT EXISTS quick_tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Task Classification
    price_tag VARCHAR(50), -- 'low', 'medium', 'high', 'critical'
    issue_type VARCHAR(100) NOT NULL, -- 'cleaning', 'display', 'filling', 'maintenance'
    priority VARCHAR(50) NOT NULL, -- 'low', 'medium', 'high', 'urgent'
    
    -- Assignment Details (mapped to existing tables)
    assigned_by UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    assigned_to_branch_id BIGINT REFERENCES branches(id) ON DELETE SET NULL,
    
    -- Timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deadline_datetime TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Status Tracking
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'overdue'
    
    -- Metadata
    created_from VARCHAR(50) DEFAULT 'quick_task', -- source tracking
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Quick Task Assignments (for multiple user assignments)
CREATE TABLE IF NOT EXISTS quick_task_assignments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    quick_task_id UUID REFERENCES quick_tasks(id) ON DELETE CASCADE NOT NULL,
    assigned_to_user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    
    -- Individual Assignment Status
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'accepted', 'in_progress', 'completed', 'overdue'
    accepted_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- Timing
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(quick_task_id, assigned_to_user_id)
);

-- 3. Quick Task Files (for attachments)
CREATE TABLE IF NOT EXISTS quick_task_files (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    quick_task_id UUID REFERENCES quick_tasks(id) ON DELETE CASCADE NOT NULL,
    
    -- File Details
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(100), -- 'image', 'pdf', 'excel', 'document'
    file_size INTEGER, -- in bytes
    mime_type VARCHAR(100),
    
    -- Storage
    storage_path TEXT NOT NULL, -- path in Supabase storage
    storage_bucket VARCHAR(100) DEFAULT 'quick-task-files',
    
    -- Metadata (mapped to existing users table)
    uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Quick Task Comments/Updates
CREATE TABLE IF NOT EXISTS quick_task_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    quick_task_id UUID REFERENCES quick_tasks(id) ON DELETE CASCADE NOT NULL,
    
    -- Comment Details
    comment TEXT NOT NULL,
    comment_type VARCHAR(50) DEFAULT 'comment', -- 'comment', 'status_update', 'file_upload'
    
    -- Author (mapped to existing users table)
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. User Preferences for Quick Tasks (mapped to existing users table)
CREATE TABLE IF NOT EXISTS quick_task_user_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    
    -- Default Settings (mapped to existing branches table)
    default_branch_id BIGINT REFERENCES branches(id) ON DELETE SET NULL,
    default_price_tag VARCHAR(50),
    default_issue_type VARCHAR(100),
    default_priority VARCHAR(50),
    
    -- UI Preferences (array of user IDs from existing users table)
    selected_user_ids UUID[], -- array of default selected users
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Integration with existing notifications table
-- Create notification triggers for quick tasks
CREATE OR REPLACE FUNCTION create_quick_task_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert notification for each assigned user
    INSERT INTO notifications (
        title,
        message,
        type,
        priority,
        target_type,
        target_users,
        metadata,
        created_at
    )
    SELECT 
        'New Quick Task: ' || qt.title,
        'You have been assigned a new quick task: ' || qt.title || 
        '. Priority: ' || qt.priority || '. Deadline: ' || 
        to_char(qt.deadline_datetime, 'YYYY-MM-DD HH24:MI'),
        'task_assignment',
        qt.priority,
        'specific_users',
        jsonb_build_array(NEW.assigned_to_user_id),
        jsonb_build_object(
            'quick_task_id', qt.id,
            'task_title', qt.title,
            'deadline', qt.deadline_datetime,
            'priority', qt.priority,
            'issue_type', qt.issue_type,
            'assigned_by', qt.assigned_by,
            'quick_task_assignment_id', NEW.id
        ),
        NOW()
    FROM quick_tasks qt
    WHERE qt.id = NEW.quick_task_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Integration with existing notification_queue table
CREATE OR REPLACE FUNCTION queue_quick_task_push_notifications()
RETURNS TRIGGER AS $$
BEGIN
    -- Queue push notifications for each assigned user
    -- Extract user IDs from target_users array and create queue entries
    INSERT INTO notification_queue (
        notification_id,
        user_id,
        status,
        payload,
        scheduled_at,
        created_at
    )
    SELECT 
        NEW.id,
        (jsonb_array_elements_text(NEW.target_users))::uuid,
        'pending',
        jsonb_build_object(
            'title', NEW.title,
            'body', NEW.message,
            'data', NEW.metadata
        ),
        NEW.scheduled_for,
        NOW()
    WHERE NEW.type = 'task_assignment' 
    AND NEW.target_type = 'specific_users'
    AND NEW.target_users IS NOT NULL;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_quick_tasks_assigned_by ON quick_tasks(assigned_by);
CREATE INDEX IF NOT EXISTS idx_quick_tasks_branch ON quick_tasks(assigned_to_branch_id);
CREATE INDEX IF NOT EXISTS idx_quick_tasks_status ON quick_tasks(status);
CREATE INDEX IF NOT EXISTS idx_quick_tasks_deadline ON quick_tasks(deadline_datetime);
CREATE INDEX IF NOT EXISTS idx_quick_tasks_created_at ON quick_tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_quick_tasks_issue_type ON quick_tasks(issue_type);
CREATE INDEX IF NOT EXISTS idx_quick_tasks_priority ON quick_tasks(priority);

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_task ON quick_task_assignments(quick_task_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_user ON quick_task_assignments(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_status ON quick_task_assignments(status);
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_created_at ON quick_task_assignments(created_at);

CREATE INDEX IF NOT EXISTS idx_quick_task_files_task ON quick_task_files(quick_task_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_files_uploaded_by ON quick_task_files(uploaded_by);

CREATE INDEX IF NOT EXISTS idx_quick_task_comments_task ON quick_task_comments(quick_task_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_created_by ON quick_task_comments(created_by);

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_user ON quick_task_user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_branch ON quick_task_user_preferences(default_branch_id);

-- RLS Policies (Row Level Security)
ALTER TABLE quick_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_task_user_preferences ENABLE ROW LEVEL SECURITY;

-- RLS policies for quick_tasks
DROP POLICY IF EXISTS quick_tasks_policy ON quick_tasks;
CREATE POLICY quick_tasks_policy ON quick_tasks FOR ALL USING (
    auth.uid() = assigned_by OR 
    auth.uid() IN (
        SELECT assigned_to_user_id FROM quick_task_assignments WHERE quick_task_id = id
    )
);

-- RLS policies for quick_task_assignments
DROP POLICY IF EXISTS quick_task_assignments_policy ON quick_task_assignments;
CREATE POLICY quick_task_assignments_policy ON quick_task_assignments FOR ALL USING (
    auth.uid() = assigned_to_user_id OR 
    auth.uid() = (SELECT assigned_by FROM quick_tasks WHERE id = quick_task_id)
);

-- RLS policies for quick_task_files
DROP POLICY IF EXISTS quick_task_files_policy ON quick_task_files;
CREATE POLICY quick_task_files_policy ON quick_task_files FOR ALL USING (
    auth.uid() = uploaded_by OR
    auth.uid() = (SELECT assigned_by FROM quick_tasks WHERE id = quick_task_id) OR
    auth.uid() IN (
        SELECT assigned_to_user_id FROM quick_task_assignments WHERE quick_task_id = quick_task_files.quick_task_id
    )
);

-- RLS policies for quick_task_comments
DROP POLICY IF EXISTS quick_task_comments_policy ON quick_task_comments;
CREATE POLICY quick_task_comments_policy ON quick_task_comments FOR ALL USING (
    auth.uid() = created_by OR
    auth.uid() = (SELECT assigned_by FROM quick_tasks WHERE id = quick_task_id) OR
    auth.uid() IN (
        SELECT assigned_to_user_id FROM quick_task_assignments WHERE quick_task_id = quick_task_comments.quick_task_id
    )
);

-- RLS policies for quick_task_user_preferences
DROP POLICY IF EXISTS quick_task_user_preferences_policy ON quick_task_user_preferences;
CREATE POLICY quick_task_user_preferences_policy ON quick_task_user_preferences FOR ALL USING (
    auth.uid() = user_id
);

-- Triggers for automatic notifications
DROP TRIGGER IF EXISTS trigger_create_quick_task_notification ON quick_task_assignments;
CREATE TRIGGER trigger_create_quick_task_notification
    AFTER INSERT ON quick_task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION create_quick_task_notification();

DROP TRIGGER IF EXISTS trigger_queue_quick_task_push_notifications ON notifications;
CREATE TRIGGER trigger_queue_quick_task_push_notifications
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION queue_quick_task_push_notifications();

-- Functions for automatic status updates
CREATE OR REPLACE FUNCTION update_quick_task_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Update main task status based on individual assignments
    IF TG_OP = 'UPDATE' THEN
        -- Check if all assignments are completed
        IF (SELECT COUNT(*) FROM quick_task_assignments 
            WHERE quick_task_id = NEW.quick_task_id AND status != 'completed') = 0 THEN
            
            UPDATE quick_tasks 
            SET status = 'completed', completed_at = NOW(), updated_at = NOW()
            WHERE id = NEW.quick_task_id;
            
        -- Check if task is overdue
        ELSIF NOW() > (SELECT deadline_datetime FROM quick_tasks WHERE id = NEW.quick_task_id) THEN
            UPDATE quick_tasks 
            SET status = 'overdue', updated_at = NOW()
            WHERE id = NEW.quick_task_id AND status != 'completed';
            
            -- Mark individual assignments as overdue if not completed
            UPDATE quick_task_assignments
            SET status = 'overdue', updated_at = NOW()
            WHERE quick_task_id = NEW.quick_task_id AND status IN ('pending', 'accepted', 'in_progress');
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for status updates
DROP TRIGGER IF EXISTS trigger_update_quick_task_status ON quick_task_assignments;
CREATE TRIGGER trigger_update_quick_task_status
    AFTER UPDATE ON quick_task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_quick_task_status();

-- Function to mark overdue tasks (to be called by a cron job)
CREATE OR REPLACE FUNCTION mark_overdue_quick_tasks()
RETURNS void AS $$
BEGIN
    -- Mark main tasks as overdue
    UPDATE quick_tasks 
    SET status = 'overdue', updated_at = NOW()
    WHERE deadline_datetime < NOW() 
    AND status NOT IN ('completed', 'overdue');
    
    -- Mark individual assignments as overdue
    UPDATE quick_task_assignments
    SET status = 'overdue', updated_at = NOW()
    WHERE quick_task_id IN (
        SELECT id FROM quick_tasks 
        WHERE deadline_datetime < NOW()
    )
    AND status NOT IN ('completed', 'overdue');
END;
$$ LANGUAGE plpgsql;

-- Views for easier querying with related data
CREATE OR REPLACE VIEW quick_tasks_with_details AS
SELECT 
    qt.*,
    u_assigned_by.username as assigned_by_username,
    he_assigned_by.name as assigned_by_name,
    b.name_en as branch_name,
    b.name_ar as branch_name_ar,
    COUNT(qta.id) as total_assignments,
    COUNT(CASE WHEN qta.status = 'completed' THEN 1 END) as completed_assignments,
    COUNT(CASE WHEN qta.status = 'overdue' THEN 1 END) as overdue_assignments
FROM quick_tasks qt
LEFT JOIN users u_assigned_by ON qt.assigned_by = u_assigned_by.id
LEFT JOIN hr_employees he_assigned_by ON u_assigned_by.employee_id = he_assigned_by.id
LEFT JOIN branches b ON qt.assigned_to_branch_id = b.id
LEFT JOIN quick_task_assignments qta ON qt.id = qta.quick_task_id
GROUP BY 
    qt.id, qt.title, qt.description, qt.price_tag, qt.issue_type, qt.priority,
    qt.assigned_by, qt.assigned_to_branch_id, qt.created_at, qt.deadline_datetime,
    qt.completed_at, qt.status, qt.created_from, qt.updated_at,
    u_assigned_by.username, he_assigned_by.name, b.name_en, b.name_ar;

-- Grant necessary permissions (adjust based on your RLS setup)
GRANT ALL ON quick_tasks TO authenticated;
GRANT ALL ON quick_task_assignments TO authenticated;
GRANT ALL ON quick_task_files TO authenticated;
GRANT ALL ON quick_task_comments TO authenticated;
GRANT ALL ON quick_task_user_preferences TO authenticated;
GRANT SELECT ON quick_tasks_with_details TO authenticated;