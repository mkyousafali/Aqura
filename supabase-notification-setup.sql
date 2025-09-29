-- Run this in Supabase SQL Editor to create notification system with test data
-- Make sure to run this in order (don't skip any sections)

-- Step 0: Drop existing objects if they exist (for clean re-runs)
DROP VIEW IF EXISTS public.notification_summary CASCADE;

DROP TABLE IF EXISTS public.notification_recipients CASCADE;
DROP TABLE IF EXISTS public.notification_attachments CASCADE; 
DROP TABLE IF EXISTS public.notifications CASCADE;

DROP TYPE IF EXISTS public.notification_target_type_enum CASCADE;
DROP TYPE IF EXISTS public.notification_status_enum CASCADE;
DROP TYPE IF EXISTS public.notification_priority_enum CASCADE;
DROP TYPE IF EXISTS public.notification_type_enum CASCADE;

-- Step 1: Create enums first
CREATE TYPE public.notification_type_enum AS ENUM (
    'info', 'success', 'warning', 'error', 'marketing'
);

CREATE TYPE public.notification_priority_enum AS ENUM (
    'low', 'medium', 'high', 'urgent'  
);

CREATE TYPE public.notification_status_enum AS ENUM (
    'draft', 'published', 'scheduled', 'expired', 'cancelled'
);

CREATE TYPE public.notification_target_type_enum AS ENUM (
    'all_users', 'all_admins', 'specific_users', 'specific_roles', 'specific_branches'
);

-- Step 2: Create main notifications table
CREATE TABLE public.notifications (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL, 
    type public.notification_type_enum NOT NULL DEFAULT 'info',
    priority public.notification_priority_enum NOT NULL DEFAULT 'medium',
    status public.notification_status_enum NOT NULL DEFAULT 'published',
    
    -- Creator info (using strings to avoid dependency issues)
    created_by VARCHAR(255) NOT NULL DEFAULT 'system',
    created_by_name VARCHAR(100) NOT NULL DEFAULT 'System',
    created_by_role VARCHAR(50) NOT NULL DEFAULT 'Admin',
    
    -- Targeting
    target_type public.notification_target_type_enum NOT NULL DEFAULT 'all_users',
    target_users JSONB NULL,
    target_roles JSONB NULL, 
    target_branches JSONB NULL,
    
    -- Scheduling
    scheduled_for TIMESTAMP WITH TIME ZONE NULL,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Metadata
    has_attachments BOOLEAN NOT NULL DEFAULT FALSE,
    read_count INTEGER NOT NULL DEFAULT 0,
    total_recipients INTEGER NOT NULL DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE NULL,
    
    CONSTRAINT notifications_pkey PRIMARY KEY (id)
);

-- Step 3: Create attachments table
CREATE TABLE public.notification_attachments (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    file_type VARCHAR(100) NOT NULL,
    uploaded_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT notification_attachments_pkey PRIMARY KEY (id),
    CONSTRAINT notification_attachments_notification_fkey FOREIGN KEY (notification_id) 
        REFERENCES notifications (id) ON DELETE CASCADE
);

-- Step 4: Create recipients table  
CREATE TABLE public.notification_recipients (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,
    user_id VARCHAR(255) NOT NULL, -- Using string to avoid user table dependency
    role VARCHAR(100) NULL,
    branch_id VARCHAR(255) NULL,
    
    -- Read tracking
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE NULL,
    is_dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    dismissed_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT notification_recipients_pkey PRIMARY KEY (id),
    CONSTRAINT notification_recipients_notification_fkey FOREIGN KEY (notification_id) 
        REFERENCES notifications (id) ON DELETE CASCADE,
    CONSTRAINT notification_recipients_unique UNIQUE (notification_id, user_id)
);

-- Step 5: Create indexes for performance
CREATE INDEX idx_notifications_type ON public.notifications (type);
CREATE INDEX idx_notifications_priority ON public.notifications (priority);
CREATE INDEX idx_notifications_status ON public.notifications (status);
CREATE INDEX idx_notifications_created_at ON public.notifications (created_at DESC);
CREATE INDEX idx_notifications_target_type ON public.notifications (target_type);

CREATE INDEX idx_notification_recipients_user_id ON public.notification_recipients (user_id);
CREATE INDEX idx_notification_recipients_unread ON public.notification_recipients (user_id, is_read) WHERE is_read = FALSE;

-- Step 6: Insert test data
INSERT INTO public.notifications (
    title, message, type, priority, status, target_type, 
    created_by, created_by_name, created_by_role, total_recipients
) VALUES 
(
    'System Maintenance Scheduled',
    'Scheduled maintenance will occur tonight from 2:00 AM to 4:00 AM. The system will be temporarily unavailable during this time.',
    'warning',
    'high', 
    'published',
    'all_users',
    'admin-001',
    'System Admin',
    'Admin',
    50
),
(
    'New Feature: Advanced Reporting',
    'We''ve launched our new advanced reporting dashboard! Check out the enhanced analytics and customizable reports in the Reports section.',
    'info',
    'medium',
    'published', 
    'all_users',
    'admin-001',
    'System Admin', 
    'Admin',
    50
),
(
    'Welcome to the Notification System', 
    'This is your notification center. You''ll receive important updates, announcements, and system alerts here.',
    'success',
    'medium',
    'published',
    'all_users', 
    'admin-001',
    'System Admin',
    'Admin',
    50
),
(
    'Security Update Required',
    'Please update your password to comply with new security policies. Go to Settings > Security to update your password.',
    'error',
    'urgent',
    'published',
    'all_users',
    'admin-001', 
    'System Admin',
    'Admin',
    50
),
(
    'Monthly Newsletter Available',
    'The monthly company newsletter is now available in the Documents section. Read about recent achievements and upcoming events.',
    'marketing',
    'low',
    'published',
    'all_users',
    'admin-001',
    'System Admin', 
    'Admin',
    50
);

-- Step 7: Create some recipients for the notifications (sample users)
INSERT INTO public.notification_recipients (notification_id, user_id, role, is_read) 
SELECT 
    n.id,
    'user-001',
    'Employee', 
    CASE WHEN random() > 0.6 THEN TRUE ELSE FALSE END -- Randomly mark some as read
FROM notifications n;

INSERT INTO public.notification_recipients (notification_id, user_id, role, is_read)
SELECT 
    n.id,
    'user-002', 
    'Manager',
    CASE WHEN random() > 0.7 THEN TRUE ELSE FALSE END
FROM notifications n;

INSERT INTO public.notification_recipients (notification_id, user_id, role, is_read)
SELECT 
    n.id,
    'admin-001',
    'Admin', 
    TRUE -- Admin has read all notifications
FROM notifications n;

-- Step 8: Update read counts based on recipients
UPDATE public.notifications 
SET read_count = (
    SELECT COUNT(*) 
    FROM notification_recipients nr 
    WHERE nr.notification_id = notifications.id 
    AND nr.is_read = TRUE
);

-- Step 9: Create a simple view for easy querying
CREATE OR REPLACE VIEW public.notification_summary AS
SELECT 
    n.id,
    n.title,
    n.message,
    n.type,
    n.priority, 
    n.status,
    n.created_by_name,
    n.created_by_role,
    n.target_type,
    n.has_attachments,
    n.read_count,
    n.total_recipients,
    n.created_at,
    n.updated_at,
    CASE 
        WHEN n.total_recipients > 0 THEN ROUND((n.read_count::DECIMAL / n.total_recipients) * 100, 1)
        ELSE 0
    END as read_percentage
FROM notifications n
WHERE n.deleted_at IS NULL
ORDER BY n.created_at DESC;

-- Step 10: Test query to verify everything works
SELECT 
    'Total notifications created:' as info,
    COUNT(*) as count
FROM notifications
UNION ALL
SELECT 
    'Total recipients created:' as info, 
    COUNT(*) as count
FROM notification_recipients
UNION ALL
SELECT
    'Notifications by type:' as info,
    NULL as count
UNION ALL
SELECT 
    type::text as info,
    COUNT(*) as count
FROM notifications
GROUP BY type;

-- Success message
SELECT 'Notification system created successfully! ✅' as result;