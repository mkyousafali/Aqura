-- Test Query for Recurring Schedule Notifications
-- This file helps you verify that recurring schedules will trigger notifications correctly

-- ================================
-- 1. Check your created recurring schedules
-- ================================

-- Check expense_scheduler for recurring schedules
SELECT 
    id,
    schedule_type,
    recurring_type,
    branch_name,
    expense_category_name_en,
    amount,
    status,
    is_paid,
    recurring_metadata->>'until_date' as until_date,
    created_at
FROM expense_scheduler
WHERE schedule_type = 'recurring'
ORDER BY created_at DESC;

-- Check non_approved_payment_scheduler for pending approval recurring schedules
SELECT 
    id,
    schedule_type,
    recurring_type,
    branch_name,
    expense_category_name_en,
    amount,
    approval_status,
    approver_name,
    recurring_metadata->>'until_date' as until_date,
    created_at
FROM non_approved_payment_scheduler
WHERE schedule_type = 'recurring'
ORDER BY created_at DESC;

-- ================================
-- 2. Test what notifications would be sent TODAY
-- ================================

-- Simulate what the function would do for daily schedules
SELECT 
    id,
    schedule_type,
    recurring_type,
    branch_name,
    expense_category_name_en,
    amount,
    CURRENT_DATE as today,
    CURRENT_DATE + INTERVAL '2 days' as occurrence_date_to_notify,
    (recurring_metadata->>'until_date')::DATE as until_date,
    CASE 
        WHEN CURRENT_DATE + INTERVAL '2 days' <= (recurring_metadata->>'until_date')::DATE 
        THEN '✅ WILL SEND NOTIFICATION'
        ELSE '❌ No notification (past until_date)'
    END as notification_status
FROM expense_scheduler
WHERE schedule_type = 'recurring'
    AND recurring_type = 'daily'
    AND status = 'pending'
    AND is_paid = FALSE

UNION ALL

SELECT 
    id,
    schedule_type,
    recurring_type,
    branch_name,
    expense_category_name_en,
    amount,
    CURRENT_DATE as today,
    CURRENT_DATE + INTERVAL '2 days' as occurrence_date_to_notify,
    (recurring_metadata->>'until_date')::DATE as until_date,
    CASE 
        WHEN CURRENT_DATE + INTERVAL '2 days' <= (recurring_metadata->>'until_date')::DATE 
        THEN '✅ WILL SEND NOTIFICATION'
        ELSE '❌ No notification (past until_date)'
    END as notification_status
FROM non_approved_payment_scheduler
WHERE schedule_type = 'recurring'
    AND recurring_type = 'daily'
    AND approval_status = 'pending';

-- ================================
-- 3. Expected notifications for YOUR schedule (until 31-10-2025)
-- ================================

-- If today is 28-10-2025 and until_date is 31-10-2025
-- Expected notifications:
-- ✅ 28-10-2025: Notification for 30-10-2025 occurrence
-- ✅ 29-10-2025: Notification for 31-10-2025 occurrence
-- ❌ 30-10-2025: No notification (would be for 01-11-2025, which is > until_date)

WITH date_simulation AS (
    SELECT 
        date_val::DATE as simulation_date,
        (date_val + INTERVAL '2 days')::DATE as occurrence_date
    FROM generate_series(
        '2025-10-28'::DATE,
        '2025-11-02'::DATE,
        '1 day'::INTERVAL
    ) as date_val
)
SELECT 
    simulation_date,
    occurrence_date,
    '2025-10-31'::DATE as until_date,
    CASE 
        WHEN occurrence_date <= '2025-10-31'::DATE 
        THEN '✅ NOTIFICATION SENT'
        ELSE '❌ NO NOTIFICATION (past until_date)'
    END as status
FROM date_simulation;

-- ================================
-- 4. Manually trigger the notification function (TEST)
-- ================================

-- Run this to actually test the function and see results
-- SELECT * FROM check_and_notify_recurring_schedules();

-- ================================
-- 5. Check if notifications were already sent
-- ================================

SELECT 
    id,
    title,
    message,
    priority,
    target_users,
    read_count,
    total_recipients,
    status,
    metadata->>'schedule_id' as schedule_id,
    metadata->>'occurrence_date' as occurrence_date,
    created_at,
    sent_at
FROM notifications
WHERE type = 'approval_request'
    AND metadata->>'schedule_type' = 'recurring'
ORDER BY created_at DESC
LIMIT 10;

-- ================================
-- 6. Check execution logs
-- ================================

SELECT 
    check_date,
    schedules_checked,
    notifications_sent,
    created_at
FROM recurring_schedule_check_log
ORDER BY created_at DESC
LIMIT 10;

-- ================================
-- 7. FOR YOUR SPECIFIC CASE (28-10-2025 to 31-10-2025)
-- ================================

-- This shows exactly what should happen
SELECT 
    '28-10-2025' as today,
    '30-10-2025' as notification_for,
    '31-10-2025' as until_date,
    '✅ Should send notification' as status
UNION ALL
SELECT 
    '29-10-2025',
    '31-10-2025',
    '31-10-2025',
    '✅ Should send notification'
UNION ALL
SELECT 
    '30-10-2025',
    '01-11-2025',
    '31-10-2025',
    '❌ Should NOT send (01-11 > until_date)'
UNION ALL
SELECT 
    '31-10-2025',
    '02-11-2025',
    '31-10-2025',
    '❌ Should NOT send (02-11 > until_date)';
