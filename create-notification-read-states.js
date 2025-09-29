console.log('🔄 Setting up notification_read_states table...');

// SQL for creating the notification_read_states table
const sqlQuery = `
-- Create notification_read_states table for per-user read tracking
CREATE TABLE IF NOT EXISTS public.notification_read_states (
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
CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_id 
    ON public.notification_read_states(notification_id);
    
CREATE INDEX IF NOT EXISTS idx_notification_read_states_user_id 
    ON public.notification_read_states(user_id);
    
CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_user 
    ON public.notification_read_states(notification_id, user_id);

-- Grant permissions
GRANT ALL ON public.notification_read_states TO postgres;
GRANT ALL ON public.notification_read_states TO anon;
GRANT ALL ON public.notification_read_states TO authenticated;
`;

console.log('📝 SQL Query to execute in Supabase SQL Editor:');
console.log('='.repeat(60));
console.log(sqlQuery);
console.log('='.repeat(60));
console.log('\n✅ Please copy and paste the above SQL into your Supabase SQL Editor and run it.');
console.log('🔗 Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/sql/new');
console.log('\n🎉 After running the SQL, the notification read states table will be ready!');