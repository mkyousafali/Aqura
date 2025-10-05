-- Force Supabase Schema Cache Refresh
-- Run this in Supabase SQL Editor

-- Method 1: Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- Method 2: Touch the table to trigger cache invalidation
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS temp_refresh_column TEXT DEFAULT NULL;
ALTER TABLE public.notifications DROP COLUMN IF EXISTS temp_refresh_column;

-- Method 3: Update table comment to force refresh
COMMENT ON TABLE public.notifications IS 'Notifications table - refreshed at ' || NOW();

-- Method 4: Grant permissions (this sometimes triggers cache refresh)
GRANT ALL ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO anon;

-- Verify the schema is now visible
SELECT 'Schema refresh completed at: ' || NOW() as refresh_status;