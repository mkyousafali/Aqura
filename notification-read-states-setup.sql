-- Drop existing objects if they exist (for clean reinstall)
DROP POLICY IF EXISTS "Users can view own read states" ON public.notification_read_states;
DROP POLICY IF EXISTS "Users can insert own read states" ON public.notification_read_states;
DROP POLICY IF EXISTS "Users can update own read states" ON public.notification_read_states;

DROP INDEX IF EXISTS idx_notification_read_states_notification_id;
DROP INDEX IF EXISTS idx_notification_read_states_user_id;
DROP INDEX IF EXISTS idx_notification_read_states_notification_user;

DROP TABLE IF EXISTS public.notification_read_states CASCADE;

-- Create notification_read_states table for per-user read tracking
CREATE TABLE public.notification_read_states (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
    user_id text NOT NULL, -- Store user identifier (email, username, or user_id)
    read_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),

    -- Ensure one read state per user per notification
    UNIQUE(notification_id, user_id)
);

-- Add RLS (Row Level Security) policies
ALTER TABLE public.notification_read_states ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own read states
CREATE POLICY "Users can view own read states" ON public.notification_read_states
    FOR SELECT USING (true); -- Allow all for now, can be restricted later

-- Policy: Users can insert their own read states
CREATE POLICY "Users can insert own read states" ON public.notification_read_states
    FOR INSERT WITH CHECK (true); -- Allow all for now

-- Policy: Users can update their own read states
CREATE POLICY "Users can update own read states" ON public.notification_read_states
    FOR UPDATE USING (true); -- Allow all for now

-- Add index for performance
CREATE INDEX idx_notification_read_states_notification_id
    ON public.notification_read_states(notification_id);

CREATE INDEX idx_notification_read_states_user_id
    ON public.notification_read_states(user_id);

CREATE INDEX idx_notification_read_states_notification_user
    ON public.notification_read_states(notification_id, user_id);

-- Grant permissions
GRANT ALL ON public.notification_read_states TO postgres;
GRANT ALL ON public.notification_read_states TO anon;
GRANT ALL ON public.notification_read_states TO authenticated;