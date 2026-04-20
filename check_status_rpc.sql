-- Check the function source
SELECT prosrc FROM pg_proc WHERE proname = 'gift_wheel_check_status';

-- Test calling it
SELECT gift_wheel_check_status();
