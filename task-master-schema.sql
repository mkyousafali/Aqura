-- Task Master System Database Schema
-- Complete task management system with assignments, criteria, and file uploads

-- =====================================================
-- 1. TASK MANAGEMENT TABLES
-- =====================================================

-- Drop existing objects if they exist (for clean reinstall)
DROP TABLE IF EXISTS public.task_completions CASCADE;
DROP TABLE IF EXISTS public.task_assignments CASCADE;
DROP TABLE IF EXISTS public.task_images CASCADE;
DROP TABLE IF EXISTS public.tasks CASCADE;

-- Tasks table - main task information
CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    title text NOT NULL,
    description text,
    
    -- Task completion criteria (multiple criteria can be selected)
    require_task_finished boolean DEFAULT false, -- User must tick "Task finished"
    require_photo_upload boolean DEFAULT false,  -- User must "Upload photo or take photo"
    require_erp_reference boolean DEFAULT false, -- User must provide "ERP reference number"
    
    -- Task options - Enable/Disable features
    can_escalate boolean DEFAULT false,  -- Can Escalate Task
    can_reassign boolean DEFAULT false,  -- Can Reassign Task
    
    -- Task creator and metadata
    created_by text NOT NULL, -- user_id who created the task
    created_by_name text, -- display name
    created_by_role text, -- user role
    
    -- Task status and lifecycle
    status text DEFAULT 'draft', -- 'draft', 'active', 'paused', 'completed', 'cancelled'
    priority text DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')), -- Priority Section dropdown
    
    -- Timestamps
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone NULL,
    
    -- Separate Date and Time fields (12-hour format with AM/PM stored as timestamp)
    due_date date NULL,                    -- Date field (separate)
    due_time time NULL,                    -- Time field (12-hour format with AM/PM)
    due_datetime timestamp with time zone NULL, -- Computed combined date+time
    
    -- Search and indexing
    search_vector tsvector GENERATED ALWAYS AS (to_tsvector('english', title || ' ' || COALESCE(description, ''))) STORED
);

-- Task images table - for task creation images and completion photos
CREATE TABLE public.task_images (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    
    -- Image metadata
    file_name text NOT NULL,
    file_size bigint NOT NULL,
    file_type text NOT NULL, -- 'image/jpeg', 'image/png', etc.
    file_url text NOT NULL, -- URL to the stored image
    
    -- Image context
    image_type text NOT NULL, -- 'task_creation', 'task_completion'
    uploaded_by text NOT NULL, -- user_id who uploaded
    uploaded_by_name text, -- display name
    
    -- Timestamps
    created_at timestamp with time zone DEFAULT now(),
    
    -- Optional: Image metadata
    image_width integer,
    image_height integer
);

-- Task assignments table - who the task is assigned to
CREATE TABLE public.task_assignments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    
    -- Assignment target (can be user, branch, or all)
    assignment_type text NOT NULL, -- 'user', 'branch', 'all'
    assigned_to_user_id text NULL, -- specific user_id if assignment_type = 'user'
    assigned_to_branch_id uuid NULL, -- specific branch_id if assignment_type = 'branch'
    
    -- Assignment metadata
    assigned_by text NOT NULL, -- user_id who made the assignment
    assigned_by_name text, -- display name
    assigned_at timestamp with time zone DEFAULT now(),
    
    -- Assignment status per assignee
    status text DEFAULT 'assigned', -- 'assigned', 'in_progress', 'completed', 'escalated', 'reassigned'
    
    -- Completion tracking
    started_at timestamp with time zone NULL,
    completed_at timestamp with time zone NULL,
    
    -- Unique constraint: one assignment per task per target
    UNIQUE(task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id)
);

-- Task completions table - track individual user task completions
CREATE TABLE public.task_completions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    assignment_id uuid NOT NULL REFERENCES public.task_assignments(id) ON DELETE CASCADE,
    
    -- Who completed the task
    completed_by text NOT NULL, -- user_id
    completed_by_name text, -- display name
    completed_by_branch_id uuid, -- user's branch
    
    -- Completion criteria tracking (user must tick each required criteria)
    task_finished_completed boolean DEFAULT false,     -- User ticked "Task finished"
    photo_uploaded_completed boolean DEFAULT false,    -- User uploaded photo/took photo
    erp_reference_completed boolean DEFAULT false,     -- User provided ERP reference
    erp_reference_number text NULL,                     -- The actual ERP reference number
    
    -- Completion details
    completion_notes text,
    
    -- Completion verification
    verified_by text NULL, -- user_id who verified (for escalated tasks)
    verified_at timestamp with time zone NULL,
    verification_notes text,
    
    -- Timestamps
    completed_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    
    -- Unique constraint: one completion per user per task
    UNIQUE(task_id, completed_by)
);

-- =====================================================
-- 2. INDEXES FOR PERFORMANCE
-- =====================================================

-- Task indexes
CREATE INDEX idx_tasks_created_by ON public.tasks(created_by);
CREATE INDEX idx_tasks_status ON public.tasks(status);
CREATE INDEX idx_tasks_created_at ON public.tasks(created_at DESC);
CREATE INDEX idx_tasks_deleted_at ON public.tasks(deleted_at);
CREATE INDEX idx_tasks_search_vector ON public.tasks USING gin(search_vector);
CREATE INDEX idx_tasks_due_date ON public.tasks(due_date) WHERE due_date IS NOT NULL;

-- Task images indexes
CREATE INDEX idx_task_images_task_id ON public.task_images(task_id);
CREATE INDEX idx_task_images_uploaded_by ON public.task_images(uploaded_by);
CREATE INDEX idx_task_images_image_type ON public.task_images(image_type);

-- Task assignments indexes
CREATE INDEX idx_task_assignments_task_id ON public.task_assignments(task_id);
CREATE INDEX idx_task_assignments_assigned_to_user_id ON public.task_assignments(assigned_to_user_id);
CREATE INDEX idx_task_assignments_assigned_to_branch_id ON public.task_assignments(assigned_to_branch_id);
CREATE INDEX idx_task_assignments_assignment_type ON public.task_assignments(assignment_type);
CREATE INDEX idx_task_assignments_status ON public.task_assignments(status);
CREATE INDEX idx_task_assignments_assigned_by ON public.task_assignments(assigned_by);

-- Task completions indexes
CREATE INDEX idx_task_completions_task_id ON public.task_completions(task_id);
CREATE INDEX idx_task_completions_assignment_id ON public.task_completions(assignment_id);
CREATE INDEX idx_task_completions_completed_by ON public.task_completions(completed_by);
CREATE INDEX idx_task_completions_completed_by_branch_id ON public.task_completions(completed_by_branch_id);
CREATE INDEX idx_task_completions_task_finished ON public.task_completions(task_finished_completed);
CREATE INDEX idx_task_completions_photo_uploaded ON public.task_completions(photo_uploaded_completed);
CREATE INDEX idx_task_completions_erp_reference ON public.task_completions(erp_reference_completed);
CREATE INDEX idx_task_completions_completed_at ON public.task_completions(completed_at DESC);

-- =====================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_completions ENABLE ROW LEVEL SECURITY;

-- Tasks policies
CREATE POLICY "Users can view all non-deleted tasks" ON public.tasks
    FOR SELECT USING (deleted_at IS NULL);

CREATE POLICY "Users can create tasks" ON public.tasks
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their own tasks" ON public.tasks
    FOR UPDATE USING (true); -- Allow all for admin management

CREATE POLICY "Users can soft delete their own tasks" ON public.tasks
    FOR DELETE USING (true); -- Allow all for admin management

-- Task images policies
CREATE POLICY "Users can view task images" ON public.task_images
    FOR SELECT USING (true);

CREATE POLICY "Users can upload task images" ON public.task_images
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their uploaded images" ON public.task_images
    FOR UPDATE USING (true);

CREATE POLICY "Users can delete their uploaded images" ON public.task_images
    FOR DELETE USING (true);

-- Task assignments policies
CREATE POLICY "Users can view task assignments" ON public.task_assignments
    FOR SELECT USING (true);

CREATE POLICY "Users can create task assignments" ON public.task_assignments
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update task assignments" ON public.task_assignments
    FOR UPDATE USING (true);

-- Task completions policies
CREATE POLICY "Users can view task completions" ON public.task_completions
    FOR SELECT USING (true);

CREATE POLICY "Users can create task completions" ON public.task_completions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update task completions" ON public.task_completions
    FOR UPDATE USING (true);

-- =====================================================
-- 4. GRANT PERMISSIONS
-- =====================================================

-- Grant permissions to different roles
GRANT ALL ON public.tasks TO postgres;
GRANT ALL ON public.task_images TO postgres;
GRANT ALL ON public.task_assignments TO postgres;
GRANT ALL ON public.task_completions TO postgres;

GRANT ALL ON public.tasks TO anon;
GRANT ALL ON public.task_images TO anon;
GRANT ALL ON public.task_assignments TO anon;
GRANT ALL ON public.task_completions TO anon;

GRANT ALL ON public.tasks TO authenticated;
GRANT ALL ON public.task_images TO authenticated;
GRANT ALL ON public.task_assignments TO authenticated;
GRANT ALL ON public.task_completions TO authenticated;

-- =====================================================
-- 5. HELPER FUNCTIONS
-- =====================================================

-- Function to check if all required completion criteria are met
CREATE OR REPLACE FUNCTION check_task_completion_criteria(
    task_uuid uuid,
    task_finished_val boolean,
    photo_uploaded_val boolean,
    erp_reference_val boolean
) RETURNS boolean AS $$
DECLARE
    task_record record;
BEGIN
    SELECT require_task_finished, require_photo_upload, require_erp_reference
    INTO task_record
    FROM tasks 
    WHERE id = task_uuid;
    
    -- Check if all required criteria are met
    IF (task_record.require_task_finished = false OR task_finished_val = true) AND
       (task_record.require_photo_upload = false OR photo_uploaded_val = true) AND
       (task_record.require_erp_reference = false OR erp_reference_val = true) THEN
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to get task statistics
CREATE OR REPLACE FUNCTION get_task_statistics(user_id_param text DEFAULT NULL)
RETURNS TABLE (
    total_tasks bigint,
    active_tasks bigint,
    completed_tasks bigint,
    my_assigned_tasks bigint,
    my_completed_tasks bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) FILTER (WHERE t.deleted_at IS NULL) as total_tasks,
        COUNT(*) FILTER (WHERE t.status = 'active' AND t.deleted_at IS NULL) as active_tasks,
        COUNT(*) FILTER (WHERE t.status = 'completed' AND t.deleted_at IS NULL) as completed_tasks,
        COUNT(DISTINCT ta.task_id) FILTER (WHERE ta.assigned_to_user_id = user_id_param OR ta.assignment_type = 'all') as my_assigned_tasks,
        COUNT(DISTINCT tc.task_id) FILTER (WHERE tc.completed_by = user_id_param) as my_completed_tasks
    FROM public.tasks t
    LEFT JOIN public.task_assignments ta ON t.id = ta.task_id
    LEFT JOIN public.task_completions tc ON t.id = tc.task_id;
END;
$$ LANGUAGE plpgsql;

-- Function to search tasks with full-text search
DROP FUNCTION IF EXISTS search_tasks(text, text, integer, integer);
CREATE OR REPLACE FUNCTION search_tasks(search_query text, user_id_param text DEFAULT NULL, limit_param integer DEFAULT 50, offset_param integer DEFAULT 0)
RETURNS TABLE (
    id uuid,
    title text,
    description text,
    require_task_finished boolean,
    require_photo_upload boolean,
    require_erp_reference boolean,
    can_escalate boolean,
    can_reassign boolean,
    created_by text,
    created_by_name text,
    status text,
    priority text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    due_date date,
    due_time time,
    rank real
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id, t.title, t.description, t.require_task_finished, t.require_photo_upload, t.require_erp_reference,
        t.can_escalate, t.can_reassign, t.created_by, t.created_by_name, t.status, t.priority,
        t.created_at, t.updated_at, t.due_date, t.due_time,
        ts_rank(t.search_vector, plainto_tsquery('english', search_query)) as rank
    FROM public.tasks t
    WHERE t.deleted_at IS NULL
    AND (
        search_query IS NULL 
        OR search_query = '' 
        OR t.search_vector @@ plainto_tsquery('english', search_query)
        OR t.title ILIKE '%' || search_query || '%'
        OR t.description ILIKE '%' || search_query || '%'
    )
    ORDER BY 
        CASE WHEN search_query IS NOT NULL AND search_query != '' 
        THEN ts_rank(t.search_vector, plainto_tsquery('english', search_query)) 
        ELSE 0 END DESC,
        t.created_at DESC
    LIMIT limit_param OFFSET offset_param;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. SAMPLE DATA INSERTION (for testing)
-- =====================================================

-- Note: This is commented out - you can uncomment to insert sample data
/*
-- Insert sample tasks
INSERT INTO public.tasks (title, description, completion_criteria, can_escalate, can_reassign, created_by, created_by_name, status, priority) VALUES
('Monthly Report Submission', 'Submit monthly department report with all metrics and KPIs', 'upload_photo', true, true, 'admin-user-1', 'Admin User', 'active', 'high'),
('Equipment Maintenance Check', 'Perform routine maintenance check on all office equipment', 'task_finished', false, true, 'admin-user-1', 'Admin User', 'active', 'medium'),
('ERP Data Entry', 'Enter all new customer data into the ERP system', 'erp_reference', true, false, 'admin-user-1', 'Admin User', 'active', 'medium'),
('Office Cleaning Inspection', 'Inspect and document office cleaning standards', 'upload_photo', false, true, 'admin-user-1', 'Admin User', 'active', 'low');

-- Insert sample assignments
INSERT INTO public.task_assignments (task_id, assignment_type, assigned_to_user_id, assigned_by, assigned_by_name) 
SELECT id, 'all', NULL, 'admin-user-1', 'Admin User' FROM public.tasks WHERE title = 'Monthly Report Submission';

INSERT INTO public.task_assignments (task_id, assignment_type, assigned_to_branch_id, assigned_by, assigned_by_name) 
SELECT t.id, 'branch', b.id, 'admin-user-1', 'Admin User' 
FROM public.tasks t, public.branches b 
WHERE t.title = 'Equipment Maintenance Check' AND b.name_en = 'Main Branch';
*/

-- =====================================================
-- SCHEMA COMPLETE
-- =====================================================

-- This completes the Task Master database schema.
-- The schema includes:
-- 1. Tasks with full metadata and search capabilities
-- 2. Task images for creation and completion photos
-- 3. Task assignments with flexible targeting (user/branch/all)
-- 4. Task completions with verification workflow
-- 5. Performance indexes for all major queries
-- 6. Row Level Security policies
-- 7. Helper functions for statistics and search
-- 8. Proper foreign key relationships and constraints

COMMENT ON TABLE public.tasks IS 'Main task information and metadata';
COMMENT ON TABLE public.task_images IS 'Task creation images and completion photos';
COMMENT ON TABLE public.task_assignments IS 'Task assignments to users, branches, or all';
COMMENT ON TABLE public.task_completions IS 'Individual user task completion records';