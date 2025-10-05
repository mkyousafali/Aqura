-- Enum Types Schema
-- This file defines all the enum types used by the application

-- Drop existing types if they exist (be careful with this in production)
DO $$ BEGIN
    DROP TYPE IF EXISTS public.notification_type_enum CASCADE;
    DROP TYPE IF EXISTS public.notification_priority_enum CASCADE;
    DROP TYPE IF EXISTS public.notification_status_enum CASCADE;
    DROP TYPE IF EXISTS public.notification_target_type_enum CASCADE;
    DROP TYPE IF EXISTS public.task_status_enum CASCADE;
    DROP TYPE IF EXISTS public.task_priority_enum CASCADE;
    DROP TYPE IF EXISTS public.employee_status_enum CASCADE;
    DROP TYPE IF EXISTS public.user_status_enum CASCADE;
    DROP TYPE IF EXISTS public.warning_status_enum CASCADE;
    DROP TYPE IF EXISTS public.fine_payment_status_enum CASCADE;
    DROP TYPE IF EXISTS public.push_subscription_status_enum CASCADE;
    DROP TYPE IF EXISTS public.notification_queue_status_enum CASCADE;
    DROP TYPE IF EXISTS public.document_type_enum CASCADE;
    DROP TYPE IF EXISTS public.session_status_enum CASCADE;
    DROP TYPE IF EXISTS public.audit_action_enum CASCADE;
EXCEPTION
    WHEN undefined_object THEN null;
END $$;

-- Notification type enum
CREATE TYPE public.notification_type_enum AS ENUM (
    'info',
    'warning', 
    'error',
    'success',
    'announcement',
    'task_assigned',
    'task_completed',
    'task_overdue',
    'task_assignment',
    'task_reminder',
    'employee_warning',
    'system_alert',
    'system_maintenance',
    'system_announcement',
    'policy_update',
    'birthday_reminder',
    'leave_approved',
    'leave_rejected',
    'document_uploaded',
    'meeting_scheduled',
    'assignment_updated',
    'deadline_reminder',
    'assignment_rejected',
    'assignment_approved',
    'marketing'
);

-- Notification priority enum
CREATE TYPE public.notification_priority_enum AS ENUM (
    'low',
    'medium',
    'high',
    'urgent',
    'critical'
);

-- Notification status enum
CREATE TYPE public.notification_status_enum AS ENUM (
    'draft',
    'scheduled',
    'published',
    'sent',
    'failed',
    'cancelled',
    'expired'
);

-- Notification target type enum
CREATE TYPE public.notification_target_type_enum AS ENUM (
    'all_users',
    'specific_users',
    'specific_roles',
    'specific_branches',
    'specific_departments',
    'specific_positions'
);

-- Task status enum
CREATE TYPE public.task_status_enum AS ENUM (
    'pending',
    'in_progress',
    'completed',
    'overdue',
    'cancelled',
    'rejected',
    'approved'
);

-- Task priority enum
CREATE TYPE public.task_priority_enum AS ENUM (
    'low',
    'medium',
    'high',
    'urgent',
    'critical'
);

-- Employee status enum
CREATE TYPE public.employee_status_enum AS ENUM (
    'active',
    'inactive',
    'terminated',
    'on_leave',
    'suspended'
);

-- User status enum
CREATE TYPE public.user_status_enum AS ENUM (
    'active',
    'inactive',
    'pending',
    'suspended',
    'locked'
);

-- Warning status enum
CREATE TYPE public.warning_status_enum AS ENUM (
    'active',
    'resolved',
    'escalated',
    'dismissed',
    'pending'
);

-- Fine payment status enum
CREATE TYPE public.fine_payment_status_enum AS ENUM (
    'pending',
    'paid',
    'overdue',
    'cancelled',
    'waived'
);

-- Push subscription status enum
CREATE TYPE public.push_subscription_status_enum AS ENUM (
    'active',
    'inactive',
    'expired',
    'revoked'
);

-- Notification queue status enum
CREATE TYPE public.notification_queue_status_enum AS ENUM (
    'pending',
    'processing',
    'sent',
    'failed',
    'retrying',
    'cancelled'
);

-- Document type enum
CREATE TYPE public.document_type_enum AS ENUM (
    'contract',
    'id_copy',
    'resume',
    'certificate',
    'medical_report',
    'performance_review',
    'disciplinary_action',
    'other'
);

-- Session status enum
CREATE TYPE public.session_status_enum AS ENUM (
    'active',
    'expired',
    'revoked',
    'inactive'
);

-- Audit action enum
CREATE TYPE public.audit_action_enum AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'LOGIN',
    'LOGOUT',
    'ACCESS',
    'PERMISSION_CHANGE',
    'PASSWORD_CHANGE'
);