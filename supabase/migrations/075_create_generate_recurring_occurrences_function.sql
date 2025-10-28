-- Migration: Create function to generate all future occurrences when a recurring schedule is created
-- This function will be called immediately after creating a recurring schedule

-- Create function to generate all recurring occurrences
CREATE OR REPLACE FUNCTION generate_recurring_occurrences(
    p_parent_id INTEGER,
    p_source_table TEXT -- 'expense_scheduler' or 'non_approved_payment_scheduler'
)
RETURNS TABLE (
    occurrence_count INTEGER,
    message TEXT
) AS $$
DECLARE
    rec RECORD;
    occurrence_date DATE;
    start_date DATE;
    end_date DATE;
    current_date_iter DATE;
    occurrences_created INTEGER := 0;
    co_user_id_value UUID;
    co_user_name_value TEXT;
BEGIN
    -- Fetch the parent recurring schedule
    IF p_source_table = 'expense_scheduler' THEN
        SELECT * INTO rec
        FROM expense_scheduler
        WHERE id = p_parent_id
        AND schedule_type = 'recurring';
    ELSIF p_source_table = 'non_approved_payment_scheduler' THEN
        SELECT * INTO rec
        FROM non_approved_payment_scheduler
        WHERE id = p_parent_id
        AND schedule_type = 'recurring';
    ELSE
        RAISE EXCEPTION 'Invalid source_table: %', p_source_table;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Recurring schedule not found with ID: % in table: %', p_parent_id, p_source_table;
    END IF;
    
    -- Get creator's info to use as CO user for single_bill occurrences
    -- If parent has co_user, use that; otherwise use creator
    IF rec.co_user_id IS NOT NULL THEN
        co_user_id_value := rec.co_user_id;
        co_user_name_value := rec.co_user_name;
    ELSE
        -- Use creator's ID and username from public.users table
        co_user_id_value := rec.created_by;
        SELECT username INTO co_user_name_value
        FROM public.users
        WHERE id = rec.created_by;
        
        -- If still null, use a default
        IF co_user_name_value IS NULL THEN
            co_user_name_value := 'System User';
        END IF;
    END IF;

    -- Generate occurrences based on recurring type
    CASE rec.recurring_type
        WHEN 'daily' THEN
            -- Generate daily occurrences
            start_date := CURRENT_DATE;
            end_date := (rec.recurring_metadata->>'until_date')::DATE;
            
            current_date_iter := start_date;
            WHILE current_date_iter <= end_date LOOP
                -- Create occurrence for this date
                IF p_source_table = 'non_approved_payment_scheduler' THEN
                    INSERT INTO non_approved_payment_scheduler (
                        schedule_type,
                        branch_id,
                        branch_name,
                        expense_category_id,
                        expense_category_name_en,
                        expense_category_name_ar,
                        co_user_id,
                        co_user_name,
                        payment_method,
                        amount,
                        description,
                        bill_type,
                        due_date,
                        approver_id,
                        approver_name,
                        approval_status,
                        created_by,
                        recurring_metadata
                    ) VALUES (
                        'single_bill',
                        rec.branch_id,
                        rec.branch_name,
                        rec.expense_category_id,
                        rec.expense_category_name_en,
                        rec.expense_category_name_ar,
                        co_user_id_value,
                        co_user_name_value,
                        rec.payment_method,
                        rec.amount,
                        COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', current_date_iter::TEXT),
                        rec.bill_type,
                        current_date_iter,
                        rec.approver_id,
                        rec.approver_name,
                        'pending',
                        rec.created_by,
                        jsonb_build_object(
                            'parent_schedule_id', rec.id,
                            'occurrence_date', current_date_iter,
                            'recurring_type', rec.recurring_type
                        )
                    );
                ELSE
                    INSERT INTO expense_scheduler (
                        schedule_type,
                        branch_id,
                        branch_name,
                        expense_category_id,
                        expense_category_name_en,
                        expense_category_name_ar,
                        requisition_id,
                        requisition_number,
                        co_user_id,
                        co_user_name,
                        payment_method,
                        amount,
                        description,
                        bill_type,
                        due_date,
                        status,
                        is_paid,
                        created_by,
                        recurring_metadata
                    ) VALUES (
                        'single_bill',
                        rec.branch_id,
                        rec.branch_name,
                        rec.expense_category_id,
                        rec.expense_category_name_en,
                        rec.expense_category_name_ar,
                        rec.requisition_id,
                        rec.requisition_number,
                        co_user_id_value,
                        co_user_name_value,
                        rec.payment_method,
                        rec.amount,
                        COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', current_date_iter::TEXT),
                        rec.bill_type,
                        current_date_iter,
                        'pending',
                        FALSE,
                        rec.created_by,
                        jsonb_build_object(
                            'parent_schedule_id', rec.id,
                            'occurrence_date', current_date_iter,
                            'recurring_type', rec.recurring_type
                        )
                    );
                END IF;
                
                occurrences_created := occurrences_created + 1;
                current_date_iter := current_date_iter + INTERVAL '1 day';
            END LOOP;
            
        WHEN 'weekly' THEN
            -- Generate weekly occurrences
            DECLARE
                target_weekday INTEGER;
            BEGIN
                target_weekday := (rec.recurring_metadata->>'weekday')::INTEGER;
                start_date := CURRENT_DATE;
                end_date := (rec.recurring_metadata->>'until_date')::DATE;
                
                current_date_iter := start_date;
                WHILE current_date_iter <= end_date LOOP
                    IF EXTRACT(DOW FROM current_date_iter) = target_weekday THEN
                        -- Create occurrence
                        IF p_source_table = 'non_approved_payment_scheduler' THEN
                            INSERT INTO non_approved_payment_scheduler (
                                schedule_type, branch_id, branch_name, expense_category_id,
                                expense_category_name_en, expense_category_name_ar,
                                co_user_id, co_user_name, payment_method, amount,
                                description, bill_type, due_date, approver_id,
                                approver_name, approval_status, created_by, recurring_metadata
                            ) VALUES (
                                'single_bill', rec.branch_id, rec.branch_name, rec.expense_category_id,
                                rec.expense_category_name_en, rec.expense_category_name_ar,
                                co_user_id_value, co_user_name_value, rec.payment_method, rec.amount,
                                COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', current_date_iter::TEXT),
                                rec.bill_type, current_date_iter, rec.approver_id,
                                rec.approver_name, 'pending', rec.created_by,
                                jsonb_build_object('parent_schedule_id', rec.id, 'occurrence_date', current_date_iter, 'recurring_type', rec.recurring_type)
                            );
                        ELSE
                            INSERT INTO expense_scheduler (
                                schedule_type, branch_id, branch_name, expense_category_id,
                                expense_category_name_en, expense_category_name_ar,
                                requisition_id, requisition_number, co_user_id, co_user_name,
                                payment_method, amount, description, bill_type, due_date,
                                status, is_paid, created_by, recurring_metadata
                            ) VALUES (
                                'single_bill', rec.branch_id, rec.branch_name, rec.expense_category_id,
                                rec.expense_category_name_en, rec.expense_category_name_ar,
                                rec.requisition_id, rec.requisition_number, co_user_id_value, co_user_name_value,
                                rec.payment_method, rec.amount,
                                COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', current_date_iter::TEXT),
                                rec.bill_type, current_date_iter, 'pending', FALSE, rec.created_by,
                                jsonb_build_object('parent_schedule_id', rec.id, 'occurrence_date', current_date_iter, 'recurring_type', rec.recurring_type)
                            );
                        END IF;
                        occurrences_created := occurrences_created + 1;
                    END IF;
                    current_date_iter := current_date_iter + INTERVAL '1 day';
                END LOOP;
            END;
            
        WHEN 'monthly_date' THEN
            -- Generate monthly occurrences by date position
            DECLARE
                month_position TEXT;
                target_date DATE;
                current_month DATE;
                end_month DATE;
            BEGIN
                month_position := rec.recurring_metadata->>'month_position';
                current_month := DATE_TRUNC('month', CURRENT_DATE);
                end_month := TO_DATE(rec.recurring_metadata->>'until_month' || '-01', 'YYYY-MM-DD');
                
                WHILE current_month <= end_month LOOP
                    -- Calculate target date based on position
                    IF month_position = 'start' THEN
                        target_date := current_month;
                    ELSIF month_position = 'middle' THEN
                        target_date := current_month + INTERVAL '15 days';
                    ELSIF month_position = 'end' THEN
                        target_date := (current_month + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
                    END IF;
                    
                    IF target_date >= CURRENT_DATE THEN
                        -- Create occurrence
                        IF p_source_table = 'non_approved_payment_scheduler' THEN
                            INSERT INTO non_approved_payment_scheduler (
                                schedule_type, branch_id, branch_name, expense_category_id,
                                expense_category_name_en, expense_category_name_ar,
                                co_user_id, co_user_name, payment_method, amount,
                                description, bill_type, due_date, approver_id,
                                approver_name, approval_status, created_by, recurring_metadata
                            ) VALUES (
                                'single_bill', rec.branch_id, rec.branch_name, rec.expense_category_id,
                                rec.expense_category_name_en, rec.expense_category_name_ar,
                                co_user_id_value, co_user_name_value, rec.payment_method, rec.amount,
                                COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', target_date::TEXT),
                                rec.bill_type, target_date, rec.approver_id,
                                rec.approver_name, 'pending', rec.created_by,
                                jsonb_build_object('parent_schedule_id', rec.id, 'occurrence_date', target_date, 'recurring_type', rec.recurring_type)
                            );
                        ELSE
                            INSERT INTO expense_scheduler (
                                schedule_type, branch_id, branch_name, expense_category_id,
                                expense_category_name_en, expense_category_name_ar,
                                requisition_id, requisition_number, co_user_id, co_user_name,
                                payment_method, amount, description, bill_type, due_date,
                                status, is_paid, created_by, recurring_metadata
                            ) VALUES (
                                'single_bill', rec.branch_id, rec.branch_name, rec.expense_category_id,
                                rec.expense_category_name_en, rec.expense_category_name_ar,
                                rec.requisition_id, rec.requisition_number, co_user_id_value, co_user_name_value,
                                rec.payment_method, rec.amount,
                                COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', target_date::TEXT),
                                rec.bill_type, target_date, 'pending', FALSE, rec.created_by,
                                jsonb_build_object('parent_schedule_id', rec.id, 'occurrence_date', target_date, 'recurring_type', rec.recurring_type)
                            );
                        END IF;
                        occurrences_created := occurrences_created + 1;
                    END IF;
                    
                    current_month := current_month + INTERVAL '1 month';
                END LOOP;
            END;
            
        WHEN 'monthly_day' THEN
            -- Generate monthly occurrences by specific day
            DECLARE
                day_of_month INTEGER;
                current_month DATE;
                end_month DATE;
                target_date DATE;
            BEGIN
                day_of_month := (rec.recurring_metadata->>'day_of_month')::INTEGER;
                current_month := DATE_TRUNC('month', CURRENT_DATE);
                end_month := TO_DATE(rec.recurring_metadata->>'until_month' || '-01', 'YYYY-MM-DD');
                
                WHILE current_month <= end_month LOOP
                    target_date := current_month + (day_of_month - 1) * INTERVAL '1 day';
                    
                    IF target_date >= CURRENT_DATE AND EXTRACT(DAY FROM target_date) = day_of_month THEN
                        -- Create occurrence
                        IF p_source_table = 'non_approved_payment_scheduler' THEN
                            INSERT INTO non_approved_payment_scheduler (
                                schedule_type, branch_id, branch_name, expense_category_id,
                                expense_category_name_en, expense_category_name_ar,
                                co_user_id, co_user_name, payment_method, amount,
                                description, bill_type, due_date, approver_id,
                                approver_name, approval_status, created_by, recurring_metadata
                            ) VALUES (
                                'single_bill', rec.branch_id, rec.branch_name, rec.expense_category_id,
                                rec.expense_category_name_en, rec.expense_category_name_ar,
                                co_user_id_value, co_user_name_value, rec.payment_method, rec.amount,
                                COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', target_date::TEXT),
                                rec.bill_type, target_date, rec.approver_id,
                                rec.approver_name, 'pending', rec.created_by,
                                jsonb_build_object('parent_schedule_id', rec.id, 'occurrence_date', target_date, 'recurring_type', rec.recurring_type)
                            );
                        ELSE
                            INSERT INTO expense_scheduler (
                                schedule_type, branch_id, branch_name, expense_category_id,
                                expense_category_name_en, expense_category_name_ar,
                                requisition_id, requisition_number, co_user_id, co_user_name,
                                payment_method, amount, description, bill_type, due_date,
                                status, is_paid, created_by, recurring_metadata
                            ) VALUES (
                                'single_bill', rec.branch_id, rec.branch_name, rec.expense_category_id,
                                rec.expense_category_name_en, rec.expense_category_name_ar,
                                rec.requisition_id, rec.requisition_number, co_user_id_value, co_user_name_value,
                                rec.payment_method, rec.amount,
                                COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', target_date::TEXT),
                                rec.bill_type, target_date, 'pending', FALSE, rec.created_by,
                                jsonb_build_object('parent_schedule_id', rec.id, 'occurrence_date', target_date, 'recurring_type', rec.recurring_type)
                            );
                        END IF;
                        occurrences_created := occurrences_created + 1;
                    END IF;
                    
                    current_month := current_month + INTERVAL '1 month';
                END LOOP;
            END;
            
        WHEN 'custom' THEN
            -- Generate custom date occurrences
            DECLARE
                custom_dates_json JSONB;
                custom_date TEXT;
            BEGIN
                custom_dates_json := rec.recurring_metadata->'custom_dates';
                
                IF custom_dates_json IS NOT NULL THEN
                    FOR custom_date IN SELECT jsonb_array_elements_text(custom_dates_json)
                    LOOP
                        IF custom_date::DATE >= CURRENT_DATE THEN
                            -- Create occurrence
                            IF p_source_table = 'non_approved_payment_scheduler' THEN
                                INSERT INTO non_approved_payment_scheduler (
                                    schedule_type, branch_id, branch_name, expense_category_id,
                                    expense_category_name_en, expense_category_name_ar,
                                    co_user_id, co_user_name, payment_method, amount,
                                    description, bill_type, due_date, approver_id,
                                    approver_name, approval_status, created_by, recurring_metadata
                                ) VALUES (
                                    'single_bill', rec.branch_id, rec.branch_name, rec.expense_category_id,
                                    rec.expense_category_name_en, rec.expense_category_name_ar,
                                    co_user_id_value, co_user_name_value, rec.payment_method, rec.amount,
                                    COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', custom_date::DATE::TEXT),
                                    rec.bill_type, custom_date::DATE, rec.approver_id,
                                    rec.approver_name, 'pending', rec.created_by,
                                    jsonb_build_object('parent_schedule_id', rec.id, 'occurrence_date', custom_date::DATE, 'recurring_type', rec.recurring_type)
                                );
                            ELSE
                                INSERT INTO expense_scheduler (
                                    schedule_type, branch_id, branch_name, expense_category_id,
                                    expense_category_name_en, expense_category_name_ar,
                                    requisition_id, requisition_number, co_user_id, co_user_name,
                                    payment_method, amount, description, bill_type, due_date,
                                    status, is_paid, created_by, recurring_metadata
                                ) VALUES (
                                    'single_bill', rec.branch_id, rec.branch_name, rec.expense_category_id,
                                    rec.expense_category_name_en, rec.expense_category_name_ar,
                                    rec.requisition_id, rec.requisition_number, co_user_id_value, co_user_name_value,
                                    rec.payment_method, rec.amount,
                                    COALESCE(rec.description, '') || FORMAT(' (Recurring: %s)', custom_date::DATE::TEXT),
                                    rec.bill_type, custom_date::DATE, 'pending', FALSE, rec.created_by,
                                    jsonb_build_object('parent_schedule_id', rec.id, 'occurrence_date', custom_date::DATE, 'recurring_type', rec.recurring_type)
                                );
                            END IF;
                            occurrences_created := occurrences_created + 1;
                        END IF;
                    END LOOP;
                END IF;
            END;
            
        ELSE
            RAISE EXCEPTION 'Unsupported recurring_type: %', rec.recurring_type;
    END CASE;

    -- Delete the parent recurring schedule after creating all occurrences
    -- The occurrences are now independent and linked via recurring_metadata
    IF p_source_table = 'expense_scheduler' THEN
        DELETE FROM expense_scheduler WHERE id = p_parent_id;
    ELSIF p_source_table = 'non_approved_payment_scheduler' THEN
        DELETE FROM non_approved_payment_scheduler WHERE id = p_parent_id;
    END IF;

    occurrence_count := occurrences_created;
    message := FORMAT('Successfully created %s occurrences for recurring schedule ID %s (parent deleted)', occurrences_created, p_parent_id);
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Add comment to function
COMMENT ON FUNCTION generate_recurring_occurrences(INTEGER, TEXT) IS 
'Generates all future occurrences immediately when a recurring schedule is created. This allows users to see, modify, or cancel individual occurrences.';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION generate_recurring_occurrences(INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_recurring_occurrences(INTEGER, TEXT) TO service_role;
