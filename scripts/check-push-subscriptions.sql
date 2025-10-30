-- Check push subscriptions for user: 1ffcb299-3d1f-4609-856f-fa5dcb71b11e
-- This will show all subscriptions and help identify duplicates

-- Count total subscriptions for this user
SELECT 
    COUNT(*) as total_subscriptions,
    COUNT(DISTINCT device_id) as unique_devices,
    COUNT(DISTINCT endpoint) as unique_endpoints
FROM push_subscriptions
WHERE user_id = '1ffcb299-3d1f-4609-856f-fa5dcb71b11e';

-- List all subscriptions with details
SELECT 
    id,
    device_id,
    endpoint,
    device_type,
    browser_name,
    is_active,
    created_at,
    last_seen,
    CASE 
        WHEN created_at > NOW() - INTERVAL '5 minutes' THEN '🆕 Very Recent'
        WHEN created_at > NOW() - INTERVAL '1 hour' THEN '⏰ Recent'
        WHEN created_at > NOW() - INTERVAL '1 day' THEN '📅 Today'
        ELSE '📆 Older'
    END as age_indicator
FROM push_subscriptions
WHERE user_id = '1ffcb299-3d1f-4609-856f-fa5dcb71b11e'
ORDER BY created_at DESC;

-- Check for duplicate device_ids (should be 0 with the fix)
SELECT 
    device_id,
    COUNT(*) as count,
    ARRAY_AGG(created_at ORDER BY created_at) as creation_times
FROM push_subscriptions
WHERE user_id = '1ffcb299-3d1f-4609-856f-fa5dcb71b11e'
GROUP BY device_id
HAVING COUNT(*) > 1;

-- Check for duplicate endpoints (should be 0 with the fix)
SELECT 
    endpoint,
    COUNT(*) as count,
    ARRAY_AGG(device_id) as device_ids,
    ARRAY_AGG(created_at ORDER BY created_at) as creation_times
FROM push_subscriptions
WHERE user_id = '1ffcb299-3d1f-4609-856f-fa5dcb71b11e'
GROUP BY endpoint
HAVING COUNT(*) > 1;

-- Show recent activity (subscriptions created in last hour)
SELECT 
    id,
    device_id,
    LEFT(endpoint, 50) || '...' as endpoint_preview,
    created_at,
    last_seen,
    EXTRACT(EPOCH FROM (NOW() - created_at)) as seconds_since_creation
FROM push_subscriptions
WHERE user_id = '1ffcb299-3d1f-4609-856f-fa5dcb71b11e'
  AND created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
