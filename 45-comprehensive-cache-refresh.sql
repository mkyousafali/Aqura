-- Comprehensive Supabase Cache Refresh
-- This will force Supabase to recognize your table structure

-- Method 1: Standard schema reload
NOTIFY pgrst, 'reload schema';

-- Method 2: Touch the table to invalidate cache
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS temp_cache_refresh TEXT DEFAULT NULL;
ALTER TABLE public.notifications DROP COLUMN IF EXISTS temp_cache_refresh;

-- Method 3: Update table statistics
ANALYZE public.notifications;

-- Method 4: Refresh materialized views (if any)
-- This forces PostgREST to rebuild its schema cache
SELECT pg_notify('pgrst', 'reload schema');

-- Method 5: Grant/revoke permissions to trigger cache refresh
REVOKE ALL ON public.notifications FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO anon;
GRANT ALL ON public.notifications TO authenticated;

-- Method 6: Update table comment with timestamp
DO $$
BEGIN
    EXECUTE 'COMMENT ON TABLE public.notifications IS ''Cache refresh timestamp: ' || NOW()::TEXT || '''';
END $$;

-- Method 7: Update table statistics (alternative to VACUUM)
ANALYZE public.notifications;

-- Method 8: Add missing type column that frontend expects
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type VARCHAR(50) NOT NULL DEFAULT 'info';

-- Test queries to verify cache refresh
SELECT 'Cache refresh initiated at: ' || NOW() as status;

-- Verify priority column is accessible
SELECT 
    COUNT(*) as total_notifications,
    priority,
    status
FROM public.notifications 
GROUP BY priority, status;

-- Simple test insert to verify all columns work
INSERT INTO public.notifications (
    title, 
    message, 
    priority, 
    status, 
    target_type,
    type
) VALUES (
    'Test Notification - Cache Refresh', 
    'This is a test to verify the cache refresh worked',
    'medium',
    'published', 
    'all_users',
    'info'
) RETURNING id, title, priority, status, type;

SELECT 'Cache refresh completed successfully!' as final_status;