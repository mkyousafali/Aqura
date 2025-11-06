-- Test the updated function in the frontend without needing database migration

-- Create notification for admin
INSERT INTO public.notifications (
    title,
    message,
    type,
    priority,
    metadata
) VALUES (
    'Customer Access Code Recovery Request - Test',
    'Customer test has requested their access code. Please verify their identity via WhatsApp before sharing the access code: 123456',
    'customer_recovery',
    'high',
    json_build_object(
        'whatsapp_number', '+966548236627',
        'customer_name', 'Test Customer',
        'access_code', '123456',
        'request_time', now(),
        'customer_id', gen_random_uuid(),
        'request_type', 'account_recovery',
        'verification_required', true,
        'action_required', 'verify_identity_and_share_access_code'
    )
);