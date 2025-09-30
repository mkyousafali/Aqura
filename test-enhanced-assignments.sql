-- Test script for enhanced task assignments functionality
-- This script tests scheduling, deadlines, and reassignment features

-- 1. Test creating a scheduled assignment with deadline
SELECT 'Testing scheduled assignment creation...' as test_step;

DO $$
DECLARE
    assignment_id UUID;
    test_task_id UUID := '123e4567-e89b-12d3-a456-426614174000'; -- Replace with actual task ID
    test_user_id UUID := '123e4567-e89b-12d3-a456-426614174001'; -- Replace with actual user ID
BEGIN
    -- Create a scheduled assignment with deadline
    SELECT create_scheduled_assignment(
        p_task_id := test_task_id,
        p_assignment_type := 'user',
        p_assigned_by := test_user_id,
        p_assigned_by_name := 'Test Manager',
        p_schedule_date := CURRENT_DATE + INTERVAL '1 day',
        p_schedule_time := '09:00:00',
        p_deadline_date := CURRENT_DATE + INTERVAL '3 days',
        p_deadline_time := '17:00:00',
        p_assigned_to_user_id := test_user_id
    ) INTO assignment_id;
    
    RAISE NOTICE 'Created scheduled assignment with ID: %', assignment_id;
    
    -- Verify the assignment was created correctly
    PERFORM * FROM task_assignments 
    WHERE id = assignment_id 
    AND schedule_date = CURRENT_DATE + INTERVAL '1 day'
    AND schedule_time = '09:00:00'::TIME
    AND deadline_date = CURRENT_DATE + INTERVAL '3 days'
    AND deadline_time = '17:00:00'::TIME
    AND deadline_datetime = (CURRENT_DATE + INTERVAL '3 days')::DATE + '17:00:00'::TIME;
    
    IF FOUND THEN
        RAISE NOTICE 'Scheduled assignment created successfully with correct deadline calculation';
    ELSE
        RAISE EXCEPTION 'Scheduled assignment creation failed';
    END IF;
END $$;

-- 2. Test creating a recurring assignment
SELECT 'Testing recurring assignment creation...' as test_step;

DO $$
DECLARE
    assignment_id UUID;
    recurring_id UUID;
    test_task_id UUID := '123e4567-e89b-12d3-a456-426614174000';
    test_user_id UUID := '123e4567-e89b-12d3-a456-426614174001';
BEGIN
    -- Create a recurring assignment (weekly)
    SELECT create_recurring_assignment(
        p_task_id := test_task_id,
        p_assignment_type := 'user',
        p_assigned_by := test_user_id,
        p_assigned_by_name := 'Test Manager',
        p_repeat_pattern := 'weekly',
        p_repeat_interval := 1,
        p_start_date := CURRENT_DATE,
        p_end_date := CURRENT_DATE + INTERVAL '30 days',
        p_assigned_to_user_id := test_user_id
    ) INTO assignment_id;
    
    RAISE NOTICE 'Created recurring assignment with ID: %', assignment_id;
    
    -- Check that recurring schedule was created
    SELECT id INTO recurring_id FROM recurring_assignment_schedules
    WHERE assignment_id = assignment_id;
    
    IF recurring_id IS NOT NULL THEN
        RAISE NOTICE 'Recurring schedule created successfully with ID: %', recurring_id;
    ELSE
        RAISE EXCEPTION 'Recurring schedule creation failed';
    END IF;
END $$;

-- 3. Test task reassignment
SELECT 'Testing task reassignment...' as test_step;

DO $$
DECLARE
    assignment_id UUID;
    new_user_id UUID := '123e4567-e89b-12d3-a456-426614174002';
    reassigned_by_id UUID := '123e4567-e89b-12d3-a456-426614174001';
    old_assigned_to UUID;
    new_assigned_to UUID;
BEGIN
    -- Get the first reassignable assignment
    SELECT id INTO assignment_id FROM task_assignments 
    WHERE is_reassignable = true 
    LIMIT 1;
    
    IF assignment_id IS NOT NULL THEN
        -- Get original assignee
        SELECT assigned_to_user_id INTO old_assigned_to 
        FROM task_assignments WHERE id = assignment_id;
        
        -- Reassign the task
        PERFORM reassign_task(
            p_assignment_id := assignment_id,
            p_new_assigned_to_user_id := new_user_id,
            p_new_assigned_to_branch_id := NULL,
            p_new_assignment_type := 'user',
            p_reassigned_by := reassigned_by_id,
            p_reassigned_by_name := 'Test Supervisor',
            p_reason := 'Test reassignment'
        );
        
        -- Verify reassignment
        SELECT assigned_to_user_id INTO new_assigned_to 
        FROM task_assignments WHERE id = assignment_id;
        
        IF new_assigned_to = new_user_id AND new_assigned_to != old_assigned_to THEN
            RAISE NOTICE 'Task successfully reassigned from % to %', old_assigned_to, new_assigned_to;
        ELSE
            RAISE EXCEPTION 'Task reassignment failed';
        END IF;
    ELSE
        RAISE NOTICE 'No reassignable assignments found to test';
    END IF;
END $$;

-- 4. Test deadline calculations and overdue detection
SELECT 'Testing deadline calculations...' as test_step;

-- Show assignments with their deadline information
SELECT 
    ta.id,
    ta.task_id,
    ta.schedule_date,
    ta.schedule_time,
    ta.deadline_date,
    ta.deadline_time,
    ta.deadline_datetime,
    CASE 
        WHEN ta.deadline_datetime < NOW() THEN 'OVERDUE'
        WHEN ta.deadline_datetime < NOW() + INTERVAL '1 day' THEN 'DUE_SOON'
        ELSE 'ON_TRACK'
    END as deadline_status,
    CASE 
        WHEN ta.deadline_datetime < NOW() THEN 
            EXTRACT(EPOCH FROM (NOW() - ta.deadline_datetime)) / 3600 || ' hours overdue'
        ELSE 
            EXTRACT(EPOCH FROM (ta.deadline_datetime - NOW())) / 3600 || ' hours remaining'
    END as time_info
FROM task_assignments ta
WHERE ta.deadline_datetime IS NOT NULL
ORDER BY ta.deadline_datetime;

-- 5. Test the get_assignments_with_deadlines function
SELECT 'Testing get_assignments_with_deadlines function...' as test_step;

SELECT * FROM get_assignments_with_deadlines(NULL, NULL) LIMIT 5;

-- Summary
SELECT 'Enhanced task assignments test completed!' as test_result;
SELECT 'Check the output above for any errors or issues.' as note;