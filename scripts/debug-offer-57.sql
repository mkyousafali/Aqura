-- Check the exact dates stored for offer ID 57

SELECT 
    id,
    name_en,
    type,
    is_active,
    start_date,
    end_date,
    branch_id,
    service_type,
    show_on_product_page,
    NOW() as current_utc_time,
    start_date <= NOW() as start_date_ok,
    end_date >= NOW() as end_date_ok,
    (start_date <= NOW() AND end_date >= NOW()) as should_display,
    -- Show the difference
    (NOW() - start_date) as time_since_start,
    (end_date - NOW()) as time_until_end
FROM offers
WHERE id = 57;
