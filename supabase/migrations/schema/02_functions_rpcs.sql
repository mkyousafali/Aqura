-- Name: _ai_brand_enforce_single_default(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._ai_brand_enforce_single_default() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.is_default = true THEN
    UPDATE public.ai_brand_libraries SET is_default = false WHERE id <> NEW.id AND is_default = true;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: accept_order(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.accept_order(p_order_id uuid, p_user_id uuid) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_current_status VARCHAR(50);
    v_user_name VARCHAR(255);
BEGIN
    -- Get current status
    SELECT order_status INTO v_current_status
    FROM orders
    WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Order not found';
        RETURN;
    END IF;
    
    IF v_current_status != 'new' THEN
        RETURN QUERY SELECT FALSE, 'Order can only be accepted from new status';
        RETURN;
    END IF;
    
    -- Get user name
    SELECT username INTO v_user_name
    FROM users
    WHERE id = p_user_id;
    
    -- Update order
    UPDATE orders
    SET order_status = 'accepted',
        accepted_at = NOW(),
        updated_at = NOW(),
        updated_by = p_user_id
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        from_status,
        to_status,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'status_changed',
        'new',
        'accepted',
        p_user_id,
        v_user_name,
--

--
-- Name: acknowledge_warning(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.acknowledge_warning(warning_id_param uuid, acknowledged_by_param uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE employee_warnings 
    SET 
        warning_status = 'acknowledged',
        acknowledged_at = CURRENT_TIMESTAMP,
        acknowledged_by = acknowledged_by_param,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = warning_id_param
    AND warning_status = 'active';
    
    RETURN FOUND;
END;
$$;


--
-- Name: adjust_product_stock_on_order_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.adjust_product_stock_on_order_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_quantity INTEGER;
BEGIN
    -- Validate that product_id exists
    IF NEW.product_id IS NULL THEN
        RAISE EXCEPTION 'product_id is required';
    END IF;

    -- Get current stock
    SELECT current_stock INTO current_quantity 
    FROM products 
    WHERE id = NEW.product_id;

    -- If product not found, raise error
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product with id % does not exist', NEW.product_id;
    END IF;

    -- Decrease stock
    UPDATE products 
    SET current_stock = current_stock - NEW.quantity,
        updated_at = NOW()
    WHERE id = NEW.product_id;

    RAISE NOTICE 'Product % stock decreased by %. New stock: %', 
        NEW.product_id, NEW.quantity, (current_quantity - NEW.quantity);

    RETURN NEW;
END;
$$;


--
-- Name: approve_customer_account(uuid, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approve_customer_account(p_customer_id uuid, p_status text, p_notes text DEFAULT ''::text, p_approved_by uuid DEFAULT NULL::uuid) RETURNS TABLE(success boolean, message text, customer_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_current_status TEXT;
    v_approved_by UUID;
    v_is_admin BOOLEAN;
    v_is_master_admin BOOLEAN;
BEGIN
    -- p_approved_by is required since we use custom auth (not Supabase Auth)
    IF p_approved_by IS NULL THEN
        RAISE EXCEPTION 'User ID (p_approved_by) is required.';
    END IF;

    -- Check if the user making the request has admin privileges
    SELECT is_admin, is_master_admin 
    INTO v_is_admin, v_is_master_admin
    FROM users 
    WHERE id = p_approved_by;

    -- Verify user exists and has admin privileges
    IF v_is_admin IS NULL THEN
        RAISE EXCEPTION 'User not found.';
    END IF;

    IF NOT (v_is_admin = true OR v_is_master_admin = true) THEN
        RAISE EXCEPTION 'Access denied. Admin privileges required.';
    END IF;

    -- Validate status parameter
    IF p_status NOT IN ('approved', 'rejected') THEN
        RETURN QUERY SELECT FALSE, 'Invalid status. Must be approved or rejected.', NULL::UUID;
        RETURN;
    END IF;

    -- Use the provided user ID
    v_approved_by := p_approved_by;

    -- Get current customer status
    SELECT registration_status INTO v_current_status
    FROM customers
    WHERE id = p_customer_id;

    -- Check if customer exists
    IF v_current_status IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Customer not found.', NULL::UUID;
        RETURN;
    END IF;

    -- Check if customer is already processed
    IF v_current_status != 'pending' THEN
--

--
-- Name: approve_customer_registration(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approve_customer_registration(p_customer_id uuid, p_approved_by uuid, p_notes text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_access_code text;
    v_customer_name text;
    v_whatsapp_number text;
    result json;
BEGIN
    -- Validate customer exists and is pending
    SELECT c.name, c.whatsapp_number
    INTO v_customer_name, v_whatsapp_number
    FROM public.customers c
    WHERE c.id = p_customer_id AND c.registration_status = 'pending';
    
    IF v_customer_name IS NULL THEN
        RAISE EXCEPTION 'Customer not found or not in pending status';
    END IF;
    
    -- Generate unique access code
    SELECT generate_unique_customer_access_code() INTO v_access_code;
    
    -- Update customer record
    UPDATE public.customers SET
        registration_status = 'approved',
        access_code = v_access_code,
        approved_by = p_approved_by,
        approved_at = now(),
        access_code_generated_at = now(),
        registration_notes = COALESCE(p_notes, registration_notes),
        updated_at = now()
    WHERE id = p_customer_id;
    
    -- Create approval notification
    INSERT INTO public.notifications (
        title,
        message,
        type,
        priority,
        metadata,
        deleted_at
    ) VALUES (
        'Customer Registration Approved',
        'Customer ' || v_customer_name || ' has been approved with access code ' || v_access_code,
        'customer_approved',
        'high',
        json_build_object(
            'customer_id', p_customer_id,
            'access_code', v_access_code,
            'approved_by', p_approved_by,
            'customer_name', v_customer_name,
--

--
-- Name: assign_order_delivery(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_order_delivery(p_order_id uuid, p_delivery_person_id uuid, p_assigned_by uuid) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_delivery_name VARCHAR(255);
    v_assigned_by_name VARCHAR(255);
BEGIN
    -- Get delivery person name
    SELECT username INTO v_delivery_name
    FROM users
    WHERE id = p_delivery_person_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Delivery person not found';
        RETURN;
    END IF;
    
    -- Get assigner name
    SELECT username INTO v_assigned_by_name
    FROM users
    WHERE id = p_assigned_by;
    
    -- Update order
    UPDATE orders
    SET delivery_person_id = p_delivery_person_id,
        delivery_assigned_at = NOW(),
        order_status = CASE 
            WHEN order_status = 'ready' THEN 'out_for_delivery'
            ELSE order_status
        END,
        updated_at = NOW(),
        updated_by = p_assigned_by
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        assigned_user_id,
        assigned_user_name,
        assignment_type,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'assigned_delivery',
        p_delivery_person_id,
        v_delivery_name,
        'delivery',
        p_assigned_by,
--

--
-- Name: assign_order_picker(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_order_picker(p_order_id uuid, p_picker_id uuid, p_assigned_by uuid) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_picker_name VARCHAR(255);
    v_assigned_by_name VARCHAR(255);
BEGIN
    -- Get picker name
    SELECT username INTO v_picker_name
    FROM users
    WHERE id = p_picker_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Picker not found';
        RETURN;
    END IF;
    
    -- Get assigner name
    SELECT username INTO v_assigned_by_name
    FROM users
    WHERE id = p_assigned_by;
    
    -- Update order
    UPDATE orders
    SET picker_id = p_picker_id,
        picker_assigned_at = NOW(),
        order_status = CASE 
            WHEN order_status = 'accepted' THEN 'in_picking'
            ELSE order_status
        END,
        updated_at = NOW(),
        updated_by = p_assigned_by
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        assigned_user_id,
        assigned_user_name,
        assignment_type,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'assigned_picker',
        p_picker_id,
        v_picker_name,
        'picker',
        p_assigned_by,
--

--
-- Name: assign_task_simple(uuid, uuid, text, text, timestamp with time zone, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_task_simple(task_id_param uuid, assigned_to_user_id_param uuid, assigned_by_param text, assigned_by_name_param text, deadline_datetime_param timestamp with time zone, priority_param text, notes_param text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO task_assignments (
        task_id,
        assignment_type,
        assigned_to_user_id,
        assigned_by,
        assigned_by_name,
        deadline_datetime,
        priority_override,
        notes,
        status
    ) VALUES (
        task_id_param,
        'user',
        assigned_to_user_id_param,
        assigned_by_param,
        assigned_by_name_param,
        deadline_datetime_param,
        priority_param,
        notes_param,
        'assigned'
    ) RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$;


--
-- Name: authenticate_customer_access_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.authenticate_customer_access_code(p_access_code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
    v_customer record;
    v_hashed_code text;
BEGIN
    v_hashed_code := encode(digest(p_access_code::bytea, 'sha256'), 'hex');

    SELECT id, name, whatsapp_number, registration_status
    INTO v_customer
    FROM public.customers
    WHERE access_code = v_hashed_code
    LIMIT 1;

    IF v_customer.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid access code. Please check and try again.'
        );
    END IF;

    IF v_customer.registration_status = 'deleted' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACCOUNT_DELETED',
            'message', 'This account has been deleted. Please register again.'
        );
    END IF;

    IF v_customer.registration_status != 'approved' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Your account is pending approval. Please wait for admin confirmation.'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'customer_id', v_customer.id,
        'customer_name', v_customer.name,
        'whatsapp_number', v_customer.whatsapp_number,
        'registration_status', v_customer.registration_status
    );
END;
$$;


--
-- Name: auto_create_payment_schedule(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auto_create_payment_schedule() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    schedule_date TIMESTAMPTZ;
    existing_schedule_id UUID;
    v_vendor_name TEXT;
    v_branch_name TEXT;
    v_final_amount NUMERIC;
BEGIN
    -- Only proceed if certificate_url was updated (from NULL to a value)
    IF (TG_OP = 'UPDATE' AND OLD.certificate_url IS NULL AND NEW.certificate_url IS NOT NULL) OR
       (TG_OP = 'INSERT' AND NEW.certificate_url IS NOT NULL) THEN
        
        -- Check if payment schedule already exists
        SELECT id INTO existing_schedule_id
        FROM vendor_payment_schedule
        WHERE receiving_record_id = NEW.id
        LIMIT 1;
        
        -- Only create if it doesn't exist
        IF existing_schedule_id IS NULL THEN
            -- Get vendor name from vendors table
            SELECT vendor_name INTO v_vendor_name
            FROM vendors
            WHERE erp_vendor_id = NEW.vendor_id
            LIMIT 1;
            
            -- Get branch name from branches table
            SELECT name_en INTO v_branch_name
            FROM branches
            WHERE id = NEW.branch_id
            LIMIT 1;
            
            -- Calculate final bill amount (bill_amount - total returns)
            v_final_amount := NEW.bill_amount - 
                COALESCE(NEW.expired_return_amount, 0) -
                COALESCE(NEW.near_expiry_return_amount, 0) -
                COALESCE(NEW.over_stock_return_amount, 0) -
                COALESCE(NEW.damage_return_amount, 0);
            
            -- Calculate schedule date based on due date or credit period
            IF NEW.due_date IS NOT NULL THEN
                schedule_date := NEW.due_date;
            ELSIF NEW.credit_period IS NOT NULL THEN
                schedule_date := (NEW.created_at + (NEW.credit_period || ' days')::INTERVAL);
            ELSE
                schedule_date := (NEW.created_at + INTERVAL '30 days'); -- Default 30 days
            END IF;
            
            -- Insert into vendor_payment_schedule
--

--
-- Name: broadcast_watchdog(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.broadcast_watchdog() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  rec RECORD;
  edge_url TEXT := 'https://supabase.urbanaqura.com/functions/v1/whatsapp-manage';
  svc_key  TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
BEGIN
  FOR rec IN
    SELECT b.id, b.wa_account_id, t.name AS template_name, t.language
    FROM wa_broadcasts b
    JOIN wa_templates t ON t.id = b.template_id
    WHERE b.status = 'sending'
      AND b.last_activity_at < NOW() - INTERVAL '3 minutes'
  LOOP
    PERFORM net.http_post(
      url     := edge_url,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || svc_key,
        'Content-Type',  'application/json'
      ),
      body    := jsonb_build_object(
        'action',         'send_broadcast',
        'account_id',     rec.wa_account_id::text,
        'broadcast_id',   rec.id::text,
        'template_name',  rec.template_name,
        'language',       rec.language
      )
    );
  END LOOP;
END;
$$;


--
-- Name: bulk_import_customers(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bulk_import_customers(p_phone_numbers text[]) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_phone text;
    v_formatted text;
    v_inserted int := 0;
    v_skipped int := 0;
    v_total int := array_length(p_phone_numbers, 1);
    v_exists boolean;
BEGIN
    IF v_total IS NULL OR v_total = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No phone numbers provided'
        );
    END IF;

    FOREACH v_phone IN ARRAY p_phone_numbers
    LOOP
        -- Clean and format phone number
        v_formatted := regexp_replace(v_phone, '[^0-9]', '', 'g');
        
        -- Skip empty
        IF length(v_formatted) = 0 THEN
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;
        
        -- Ensure 966 prefix
        IF length(v_formatted) = 9 THEN
            v_formatted := '966' || v_formatted;
        ELSIF length(v_formatted) = 10 AND v_formatted LIKE '0%' THEN
            v_formatted := '966' || substring(v_formatted from 2);
        END IF;
        
        -- Check if already exists (any format)
        SELECT EXISTS(
            SELECT 1 FROM public.customers
            WHERE regexp_replace(whatsapp_number, '[^0-9]', '', 'g') = v_formatted
               OR whatsapp_number = v_formatted
               OR whatsapp_number = '+' || v_formatted
        ) INTO v_exists;
        
        IF v_exists THEN
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;
        
        -- Insert as pre_registered (no name, no access code)
        INSERT INTO public.customers (
--

--
-- Name: bulk_toggle_customer_product(text[], boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bulk_toggle_customer_product(p_barcodes text[], p_value boolean) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE products
    SET is_customer_product = p_value
    WHERE barcode = ANY(p_barcodes);

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'updated_count', v_count
    );
END;
$$;


--
-- Name: calculate_category_days(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_category_days() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Auto-calculate days for leave categories
    IF NEW.document_category IN ('sick_leave', 'special_leave', 'annual_leave') 
       AND NEW.category_start_date IS NOT NULL 
       AND NEW.category_end_date IS NOT NULL THEN
        NEW.category_days := NEW.category_end_date - NEW.category_start_date + 1;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: calculate_flyer_product_profit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_flyer_product_profit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Calculate profit amount
  NEW.profit := NEW.sale_price - NEW.cost;
  
  -- Calculate profit percentage
  IF NEW.cost > 0 THEN
    NEW.profit_percentage := ((NEW.sale_price - NEW.cost) / NEW.cost) * 100;
  ELSE
    NEW.profit_percentage := 0;
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: calculate_next_visit_date(text, text, text, integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_next_visit_date(visit_type text, weekday_name text DEFAULT NULL::text, fresh_type text DEFAULT NULL::text, day_number integer DEFAULT NULL::integer, skip_days integer DEFAULT NULL::integer, start_date date DEFAULT NULL::date, current_next_date date DEFAULT NULL::date) RETURNS date
    LANGUAGE plpgsql
    AS $$
DECLARE
    next_date DATE;
    current_date DATE := CURRENT_DATE;
    weekday_num INTEGER;
BEGIN
    CASE visit_type
        WHEN 'weekly' THEN
            -- Calculate next occurrence of the specified weekday
            weekday_num := CASE weekday_name
                WHEN 'sunday' THEN 0
                WHEN 'monday' THEN 1
                WHEN 'tuesday' THEN 2
                WHEN 'wednesday' THEN 3
                WHEN 'thursday' THEN 4
                WHEN 'friday' THEN 5
                WHEN 'saturday' THEN 6
            END;
            
            -- If updating existing record, calculate from current next_date
            IF current_next_date IS NOT NULL THEN
                next_date := current_next_date + INTERVAL '7 days';
            ELSE
                -- Find next occurrence of weekday from today
                next_date := current_date + (weekday_num - EXTRACT(DOW FROM current_date))::INTEGER;
                IF next_date <= current_date THEN
                    next_date := next_date + INTERVAL '7 days';
                END IF;
            END IF;
            
        WHEN 'daily' THEN
            -- Daily visits: next day
            IF current_next_date IS NOT NULL THEN
                next_date := current_next_date + INTERVAL '1 day';
            ELSE
                next_date := current_date + INTERVAL '1 day';
            END IF;
            
        WHEN 'monthly' THEN
            -- Monthly visits on specific day number
            IF current_next_date IS NOT NULL THEN
                -- Add one month to current next date
                next_date := (current_next_date + INTERVAL '1 month')::DATE;
                -- Adjust to correct day of month
                next_date := DATE_TRUNC('month', next_date) + (day_number - 1) * INTERVAL '1 day';
            ELSE
                -- Calculate from current month
                next_date := DATE_TRUNC('month', current_date) + (day_number - 1) * INTERVAL '1 day';
                IF next_date <= current_date THEN
--

--
-- Name: calculate_profit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_profit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Calculate profit
    NEW.profit = NEW.sale_price - NEW.cost;
    
    -- Calculate profit percentage
    IF NEW.cost > 0 THEN
        NEW.profit_percentage = ((NEW.sale_price - NEW.cost) / NEW.cost) * 100;
    ELSE
        NEW.profit_percentage = 0;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: calculate_receiving_amounts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_receiving_amounts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Calculate total_return_amount
    NEW.total_return_amount := 
        COALESCE(NEW.expired_return_amount, 0) +
        COALESCE(NEW.near_expiry_return_amount, 0) +
        COALESCE(NEW.over_stock_return_amount, 0) +
        COALESCE(NEW.damage_return_amount, 0);
    
    -- Calculate final_bill_amount (bill_amount - total_return_amount)
    NEW.final_bill_amount := NEW.bill_amount - NEW.total_return_amount;
    
    -- Ensure final amount is not negative
    IF NEW.final_bill_amount < 0 THEN
        NEW.final_bill_amount := 0;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: calculate_return_totals(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_return_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Calculate total return amount
  NEW.total_return_amount = COALESCE(NEW.expired_return_amount, 0) + 
                           COALESCE(NEW.near_expiry_return_amount, 0) + 
                           COALESCE(NEW.over_stock_return_amount, 0) + 
                           COALESCE(NEW.damage_return_amount, 0);
  
  -- Calculate final bill amount
  NEW.final_bill_amount = COALESCE(NEW.bill_amount, 0) - NEW.total_return_amount;
  
  RETURN NEW;
END;
$$;


--
-- Name: calculate_schedule_details(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_schedule_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Auto-detect overnight shift if not explicitly set
    IF NEW.is_overnight IS NULL THEN
        NEW.is_overnight := is_overnight_shift(NEW.scheduled_start_time, NEW.scheduled_end_time);
    END IF;
    
    -- Auto-calculate working hours if not provided
    IF NEW.scheduled_hours IS NULL OR NEW.scheduled_hours = 0 THEN
        NEW.scheduled_hours := calculate_working_hours(
            NEW.scheduled_start_time, 
            NEW.scheduled_end_time, 
            NEW.is_overnight
        );
    END IF;
    
    -- Update timestamp
    NEW.updated_at := NOW();
    
    RETURN NEW;
END;
$$;


--
-- Name: calculate_working_hours(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_working_hours() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  start_minutes INTEGER;
  end_minutes INTEGER;
  hours_diff NUMERIC;
BEGIN
  -- Convert times to minutes since midnight
  start_minutes := EXTRACT(HOUR FROM NEW.shift_start_time)::INTEGER * 60 + 
                   EXTRACT(MINUTE FROM NEW.shift_start_time)::INTEGER;
  end_minutes := EXTRACT(HOUR FROM NEW.shift_end_time)::INTEGER * 60 + 
                 EXTRACT(MINUTE FROM NEW.shift_end_time)::INTEGER;

  -- Calculate hours
  IF NEW.is_shift_overlapping_next_day THEN
    -- If shift overlaps to next day: (1440 - start_minutes + end_minutes) / 60
    hours_diff := (1440 - start_minutes + end_minutes)::NUMERIC / 60;
  ELSE
    -- If shift doesn't overlap: (end_minutes - start_minutes) / 60
    hours_diff := (end_minutes - start_minutes)::NUMERIC / 60;
  END IF;

  NEW.working_hours := ROUND(hours_diff, 2);
  RETURN NEW;
END;
$$;


--
-- Name: calculate_working_hours(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_working_hours(check_in timestamp with time zone, check_out timestamp with time zone) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF check_in IS NULL OR check_out IS NULL THEN
        RETURN 0.00;
    END IF;
    
    IF check_out <= check_in THEN
        RETURN 0.00;
    END IF;
    
    RETURN ROUND(
        EXTRACT(EPOCH FROM (check_out - check_in)) / 3600.0,
        2
    );
END;
$$;


--
-- Name: calculate_working_hours(time without time zone, time without time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_working_hours(start_time time without time zone, end_time time without time zone, is_overnight_shift boolean DEFAULT false) RETURNS numeric
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    IF is_overnight_shift THEN
        -- For overnight shifts: (24:00 - start_time) + end_time
        RETURN ROUND(
            (EXTRACT(EPOCH FROM (TIME '24:00:00' - start_time)) + 
             EXTRACT(EPOCH FROM end_time)) / 3600.0, 2
        );
    ELSE
        -- For regular shifts: end_time - start_time
        RETURN ROUND(
            EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0, 2
        );
    END IF;
END;
$$;


--
-- Name: cancel_order(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cancel_order(p_order_id uuid, p_user_id uuid, p_cancellation_reason text) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_current_status VARCHAR(50);
    v_user_name VARCHAR(255);
BEGIN
    -- Get current status
    SELECT order_status INTO v_current_status
    FROM orders
    WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Order not found';
        RETURN;
    END IF;
    
    IF v_current_status = 'delivered' THEN
        RETURN QUERY SELECT FALSE, 'Cannot cancel delivered order';
        RETURN;
    END IF;
    
    IF v_current_status = 'cancelled' THEN
        RETURN QUERY SELECT FALSE, 'Order is already cancelled';
        RETURN;
    END IF;
    
    -- Get user name
    SELECT username INTO v_user_name
    FROM users
    WHERE id = p_user_id;
    
    -- Update order
    UPDATE orders
    SET order_status = 'cancelled',
        cancelled_at = NOW(),
        cancelled_by = p_user_id,
        cancellation_reason = p_cancellation_reason,
        updated_at = NOW(),
        updated_by = p_user_id
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        from_status,
        to_status,
        performed_by,
        performed_by_name,
        notes
--

--
-- Name: check_accountant_dependency(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_accountant_dependency(receiving_record_id_param uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_receiving_record RECORD;
  missing_files TEXT[];
BEGIN
  -- Get the receiving record
  SELECT * INTO v_receiving_record
  FROM receiving_records
  WHERE id = receiving_record_id_param;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'can_complete', false,
      'error', 'Receiving record not found',
      'error_code', 'RECORD_NOT_FOUND',
      'message', 'Receiving record not found'
    );
  END IF;
  
  missing_files := ARRAY[]::TEXT[];
  
  -- Check if original bill URL exists (not the boolean flag)
  IF v_receiving_record.original_bill_url IS NULL OR 
     TRIM(v_receiving_record.original_bill_url) = '' THEN
    missing_files := array_append(missing_files, 'Original Bill');
  END IF;
  
  -- Check if PR Excel URL exists (not the boolean flag)
  IF v_receiving_record.pr_excel_file_url IS NULL OR 
     TRIM(v_receiving_record.pr_excel_file_url) = '' THEN
    missing_files := array_append(missing_files, 'PR Excel File');
  END IF;
  
  -- If any files are missing, return error
  IF array_length(missing_files, 1) > 0 THEN
    RETURN jsonb_build_object(
      'can_complete', false,
      'error', 'Missing required files: ' || array_to_string(missing_files, ', ') || '. Please ensure all files are uploaded before completing this task.',
      'error_code', 'REQUIRED_FILES_NOT_UPLOADED',
      'message', 'Missing required files: ' || array_to_string(missing_files, ', ') || '. Please ensure all files are uploaded before completing this task.',
      'missing_files', missing_files
    );
  END IF;
  
  -- All files present, accountant can complete
  RETURN jsonb_build_object(
    'can_complete', true,
    'message', 'All required files are uploaded'
  );
--

--
-- Name: check_and_notify_recurring_schedules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_and_notify_recurring_schedules() RETURNS TABLE(schedule_id integer, notification_sent boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
    notification_exists BOOLEAN;
BEGIN
    -- Process all scheduled single_bill occurrences that are 2 days away
    -- These occurrences were created by generate_recurring_occurrences() function
    FOR rec IN 
        SELECT 
            id,
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
            recurring_metadata,
            approver_id,
            approver_name,
            'non_approved_payment_scheduler' as source_table
        FROM non_approved_payment_scheduler
        WHERE schedule_type = 'single_bill'
        AND approval_status = 'pending'
        AND due_date = CURRENT_DATE + INTERVAL '2 days'
        AND recurring_metadata->>'parent_schedule_id' IS NOT NULL -- Only recurring occurrences
        
        UNION ALL
        
        SELECT 
            id,
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
            recurring_metadata,
--

--
-- Name: check_and_notify_recurring_schedules_with_logging(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_and_notify_recurring_schedules_with_logging() RETURNS TABLE(schedules_checked integer, notifications_sent integer, execution_date date, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    checked_count INTEGER := 0;
    notified_count INTEGER := 0;
    rec RECORD;
BEGIN
    -- Run the notification check
    FOR rec IN SELECT * FROM check_and_notify_recurring_schedules()
    LOOP
        checked_count := checked_count + 1;
        IF rec.notification_sent THEN
            notified_count := notified_count + 1;
        END IF;
    END LOOP;
    
    -- Log the execution
    INSERT INTO recurring_schedule_check_log (
        check_date,
        schedules_checked,
        notifications_sent
    ) VALUES (
        CURRENT_DATE,
        checked_count,
        notified_count
    )
    ON CONFLICT (check_date) 
    DO UPDATE SET
        schedules_checked = recurring_schedule_check_log.schedules_checked + EXCLUDED.schedules_checked,
        notifications_sent = recurring_schedule_check_log.notifications_sent + EXCLUDED.notifications_sent;
    
    -- Return summary
    schedules_checked := checked_count;
    notifications_sent := notified_count;
    execution_date := CURRENT_DATE;
    message := FORMAT('Checked %s schedules, sent %s notifications', checked_count, notified_count);
    RETURN NEXT;
END;
$$;


--
-- Name: FUNCTION check_and_notify_recurring_schedules_with_logging(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.check_and_notify_recurring_schedules_with_logging() IS 'Wrapper function that calls check_and_notify_recurring_schedules() and logs execution. Use this for cron jobs or manual execution.';


--
-- Name: check_erp_sync_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_erp_sync_status() RETURNS TABLE(total_inventory_completions bigint, synced_records bigint, unsynced_records bigint, sync_percentage numeric, status text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_completions,
        COUNT(CASE WHEN rr.erp_purchase_invoice_reference IS NOT NULL THEN 1 END) as synced,
        COUNT(CASE WHEN rr.erp_purchase_invoice_reference IS NULL THEN 1 END) as unsynced,
        ROUND(
            (COUNT(CASE WHEN rr.erp_purchase_invoice_reference IS NOT NULL THEN 1 END)::NUMERIC / 
             COUNT(*)::NUMERIC) * 100, 2
        ) as percentage,
        CASE 
            WHEN COUNT(CASE WHEN rr.erp_purchase_invoice_reference IS NULL THEN 1 END) = 0 
            THEN 'Γ£à ALL SYNCED'
            ELSE 'ΓÜá∩╕Å SOME UNSYNCED'
        END as sync_status
    FROM task_completions tc
    JOIN receiving_tasks rt ON tc.task_id = rt.task_id AND tc.assignment_id = rt.assignment_id
    JOIN receiving_records rr ON rt.receiving_record_id = rr.id
    WHERE tc.erp_reference_completed = true 
      AND tc.erp_reference_number IS NOT NULL 
      AND tc.erp_reference_number != ''
      AND rt.role_type = 'inventory_manager';
END;
$$;


--
-- Name: check_erp_sync_status_for_record(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_erp_sync_status_for_record(receiving_record_id_param uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    status_record RECORD;
    result_json JSONB;
    has_tasks BOOLEAN := false;
BEGIN
    RAISE NOTICE 'Checking sync status for receiving_record_id: %', receiving_record_id_param;
    
    -- Check if this record has any receiving tasks
    SELECT EXISTS (
        SELECT 1 FROM receiving_tasks rt 
        WHERE rt.receiving_record_id = receiving_record_id_param
    ) INTO has_tasks;
    
    RAISE NOTICE 'Record has receiving tasks: %', has_tasks;
    
    IF has_tasks THEN
        -- Get task-based sync status information
        SELECT 
            rr.erp_purchase_invoice_reference,
            tc.erp_reference_number as task_erp_reference,
            tc.erp_reference_completed,
            tc.completed_at as task_completed_at,
            tc.completed_by,
            rt.role_type,
            rt.task_completed as receiving_task_completed,
            CASE 
                WHEN tc.erp_reference_completed = true 
                     AND tc.erp_reference_number IS NOT NULL 
                     AND TRIM(tc.erp_reference_number) != ''
                     AND rr.erp_purchase_invoice_reference = TRIM(tc.erp_reference_number)
                THEN 'SYNCED'
                WHEN tc.erp_reference_completed = true 
                     AND tc.erp_reference_number IS NOT NULL 
                     AND TRIM(tc.erp_reference_number) != ''
                     AND (rr.erp_purchase_invoice_reference IS NULL 
                          OR rr.erp_purchase_invoice_reference != TRIM(tc.erp_reference_number))
                THEN 'NEEDS_SYNC'
                WHEN tc.erp_reference_completed = false 
                     OR tc.erp_reference_number IS NULL 
                     OR TRIM(tc.erp_reference_number) = ''
                THEN 'NO_ERP_REFERENCE'
                ELSE 'UNKNOWN'
            END as sync_status
        INTO status_record
        FROM receiving_records rr
        LEFT JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id AND rt.role_type = 'inventory_manager'
        LEFT JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
        WHERE rr.id = receiving_record_id_param
--

--
-- Name: check_helper_apps_permission(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_helper_apps_permission() RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT
        COALESCE((SELECT is_master_admin FROM public.users WHERE id = auth.uid()), false)
        OR
        EXISTS (
            SELECT 1
            FROM public.sidebar_buttons sb
            JOIN public.button_permissions bp ON bp.button_id = sb.id
            WHERE sb.button_code = 'HELPER_APPS'
              AND bp.user_id = auth.uid()
              AND bp.is_enabled = true
        );
$$;


--
-- Name: check_loyalty_points(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_loyalty_points(p_phone text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_normalized text;
    v_customer   record;
    v_tier       record;
    v_available  numeric(14,2);
BEGIN
    v_normalized := regexp_replace(p_phone, '\D', '', 'g');
    IF v_normalized LIKE '0%' THEN
        v_normalized := '966' || substring(v_normalized FROM 2);
    ELSIF NOT v_normalized LIKE '966%' THEN
        v_normalized := '966' || v_normalized;
    END IF;

    SELECT id, name, whatsapp_number,
           COALESCE(total_points_earned, 0)         AS total_points_earned,
           COALESCE(total_redemptions, 0)            AS total_redemptions,
           COALESCE(final_loyalty_point_balance, 0)  AS final_loyalty_point_balance,
           loyalty_tier_id, loyalty_tier_name, loyalty_tier_name_ar, registration_status
    INTO v_customer
    FROM public.customers
    WHERE whatsapp_number = v_normalized AND is_deleted = false
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'customer_not_found');
    END IF;

    IF v_customer.registration_status != 'approved' THEN
        RETURN jsonb_build_object('success', false, 'error', 'customer_not_approved');
    END IF;

    v_available := v_customer.final_loyalty_point_balance;

    SELECT id, name, name_ar, COALESCE(min_redeem_points, 0) AS min_redeem_points
    INTO v_tier
    FROM public.loyalty_tiers
    WHERE id = v_customer.loyalty_tier_id
    LIMIT 1;

    RETURN jsonb_build_object(
        'success',              true,
        'customer_id',          v_customer.id,
        'customer_name',        v_customer.name,
        'whatsapp_number',      v_customer.whatsapp_number,
        'total_points_earned',  v_customer.total_points_earned,
        'total_redemptions',    v_customer.total_redemptions,
        'available_points',     v_available,
--

--
-- Name: check_offer_eligibility(integer, uuid, numeric, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_offer_eligibility(p_offer_id integer, p_customer_id uuid, p_cart_total numeric DEFAULT 0, p_cart_quantity integer DEFAULT 0) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_offer RECORD;
    v_customer_usage_count INTEGER;
BEGIN
    -- Get offer details
    SELECT * INTO v_offer FROM offers WHERE id = p_offer_id;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    -- Check if offer is active
    IF v_offer.is_active = false THEN
        RETURN false;
    END IF;
    
    -- Check date range
    IF NOW() NOT BETWEEN v_offer.start_date AND v_offer.end_date THEN
        RETURN false;
    END IF;
    
    -- Check minimum amount
    IF v_offer.min_amount IS NOT NULL AND p_cart_total < v_offer.min_amount THEN
        RETURN false;
    END IF;
    
    -- Check minimum quantity
    IF v_offer.min_quantity IS NOT NULL AND p_cart_quantity < v_offer.min_quantity THEN
        RETURN false;
    END IF;
    
    -- Check max uses per customer
    IF v_offer.max_uses_per_customer IS NOT NULL THEN
        SELECT COUNT(*) INTO v_customer_usage_count
        FROM offer_usage_logs
        WHERE offer_id = p_offer_id AND customer_id = p_customer_id;
        
        IF v_customer_usage_count >= v_offer.max_uses_per_customer THEN
            RETURN false;
        END IF;
    END IF;
    
    -- Check max total uses
    IF v_offer.max_total_uses IS NOT NULL AND v_offer.current_total_uses >= v_offer.max_total_uses THEN
        RETURN false;
    END IF;
    
    -- If customer-specific, check assignment
--

--
-- Name: check_orphaned_variations(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_orphaned_variations() RETURNS TABLE(barcode text, product_name_en text, product_name_ar text, parent_product_barcode text, reason text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.barcode,
    p.product_name_en,
    p.product_name_ar,
    p.parent_product_barcode,
    CASE 
      WHEN p.parent_product_barcode IS NOT NULL 
           AND NOT EXISTS (
             SELECT 1 FROM products parent 
             WHERE parent.barcode = p.parent_product_barcode
           ) THEN 'Parent product does not exist'
      WHEN p.parent_product_barcode = p.barcode THEN 'Self-referencing parent'
      ELSE 'Unknown issue'
    END as reason
  FROM products p
  WHERE p.is_variation = true
    AND (
      (p.parent_product_barcode IS NOT NULL 
       AND NOT EXISTS (
         SELECT 1 FROM products parent 
         WHERE parent.barcode = p.parent_product_barcode
       ))
      OR p.parent_product_barcode = p.barcode
    )
  ORDER BY p.product_name_en;
END;
$$;


--
-- Name: check_overdue_tasks_and_send_reminders(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_overdue_tasks_and_send_reminders() RETURNS TABLE(task_id uuid, task_title text, user_id uuid, user_name text, hours_overdue numeric, reminder_sent boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  task_record RECORD;
  notification_id UUID;
  reminder_count INTEGER := 0;
BEGIN
  RAISE NOTICE 'Starting overdue task reminder check at %', NOW();

  -- ========================================
  -- Check regular task assignments
  -- ========================================
  FOR task_record IN
    SELECT 
      ta.id as assignment_id,
      t.id as task_id,
      t.title as task_title,
      ta.assigned_to_user_id,
      u.username as user_name,
      COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) as deadline,
      EXTRACT(EPOCH FROM (NOW() - COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime))) / 3600 as hours_overdue
    FROM task_assignments ta
    JOIN tasks t ON t.id = ta.task_id
    JOIN users u ON u.id = ta.assigned_to_user_id
    LEFT JOIN task_completions tc ON tc.assignment_id = ta.id
    WHERE tc.id IS NULL  -- Not completed
      AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) IS NOT NULL  -- Has deadline
      AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW()  -- Overdue
      AND NOT EXISTS (  -- No reminder sent yet
        SELECT 1 FROM task_reminder_logs trl 
        WHERE trl.task_assignment_id = ta.id
      )
    ORDER BY hours_overdue DESC
  LOOP
    BEGIN
      -- Insert notification
      INSERT INTO notifications (
        title,
        message,
        type,
        target_users,
        target_type,
        status,
        sent_at,
        created_at,
        created_by,
        created_by_name,
        created_by_role,
        task_id,
--

--
-- Name: check_receiving_task_dependencies(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_receiving_task_dependencies(receiving_record_id_param uuid, role_type_param text) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  template_record RECORD;
  dependency_role TEXT;
  missing_dependencies TEXT[] := ARRAY[]::TEXT[];
  blocking_roles TEXT[] := ARRAY[]::TEXT[];
  completed_dependencies TEXT[] := ARRAY[]::TEXT[];
  v_total_tasks INT;
  v_completed_tasks INT;
BEGIN
  -- Get the template for the role
  SELECT * INTO template_record
  FROM receiving_task_templates
  WHERE role_type = role_type_param;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'can_complete', false,
      'error', 'Template not found for role: ' || role_type_param,
      'missing_dependencies', ARRAY[]::TEXT[],
      'blocking_roles', ARRAY[]::TEXT[],
      'completed_dependencies', ARRAY[]::TEXT[]
    );
  END IF;

  -- If no dependencies, can complete
  IF template_record.depends_on_role_types IS NULL OR array_length(template_record.depends_on_role_types, 1) = 0 THEN
    RETURN json_build_object(
      'can_complete', true,
      'missing_dependencies', ARRAY[]::TEXT[],
      'blocking_roles', ARRAY[]::TEXT[],
      'completed_dependencies', ARRAY[]::TEXT[]
    );
  END IF;

  -- Check each dependency
  -- For array roles (shelf_stocker, warehouse_handler, night_supervisor),
  -- ALL tasks must be completed before the dependent role can proceed
  FOREACH dependency_role IN ARRAY template_record.depends_on_role_types
  LOOP
    -- Count total and completed tasks for this role
    SELECT
      COUNT(*),
      COUNT(*) FILTER (WHERE task_completed = true)
    INTO v_total_tasks, v_completed_tasks
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = dependency_role;

--

--
-- Name: check_task_completion_criteria(uuid, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_task_completion_criteria(task_uuid uuid, task_finished_val boolean, photo_uploaded_val boolean, erp_reference_val boolean) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    task_record record;
BEGIN
    SELECT require_task_finished, require_photo_upload, require_erp_reference
    INTO task_record
    FROM tasks 
    WHERE id = task_uuid;
    
    -- Check if all required criteria are met
    IF (task_record.require_task_finished = false OR task_finished_val = true) AND
       (task_record.require_photo_upload = false OR photo_uploaded_val = true) AND
       (task_record.require_erp_reference = false OR erp_reference_val = true) THEN
        RETURN true;
    ELSE
        RETURN false;
    END IF;
END;
$$;


--
-- Name: check_user_permission(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_user_permission(p_function_code text, p_permission text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Old role system removed - this function is deprecated
  -- Return false since we now use button_permissions system
  -- TODO: Remove calls to this function from application code
  RETURN false;
END;
$$;


--
-- Name: check_vip_campaign_schedule(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_vip_campaign_schedule() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  rec RECORD;
  should_be_active boolean;
BEGIN
  FOR rec IN SELECT * FROM vip_campaign_settings WHERE start_datetime IS NOT NULL AND end_datetime IS NOT NULL LOOP
    should_be_active := (NOW() AT TIME ZONE 'UTC' >= rec.start_datetime AND NOW() AT TIME ZONE 'UTC' <= rec.end_datetime);
    IF should_be_active IS DISTINCT FROM rec.is_active THEN
      UPDATE vip_campaign_settings
        SET is_active = should_be_active, updated_at = NOW()
        WHERE id = rec.id;
    END IF;
  END LOOP;
END;
$$;


--
-- Name: check_visit_conflicts(uuid, date, time without time zone, integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_visit_conflicts(branch_uuid uuid, visit_date_param date, visit_time_param time without time zone, duration_minutes integer DEFAULT 60, exclude_visit_id uuid DEFAULT NULL::uuid) RETURNS TABLE(conflict_count integer, conflicting_visits text[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    start_time TIME;
    end_time TIME;
BEGIN
    -- Calculate time range
    start_time := visit_time_param;
    end_time := visit_time_param + (duration_minutes || ' minutes')::INTERVAL;
    
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as conflict_count,
        ARRAY_AGG(
            'Visit with ' || v.company || ' at ' || vv.visit_time::TEXT
        ) as conflicting_visits
    FROM vendor_visits vv
    JOIN vendors v ON vv.vendor_id = v.id
    WHERE vv.branch_id = branch_uuid 
    AND vv.visit_date = visit_date_param
    AND vv.status IN ('scheduled', 'confirmed', 'in_progress')
    AND (exclude_visit_id IS NULL OR vv.id != exclude_visit_id)
    AND vv.visit_time IS NOT NULL
    AND (
        -- Check for time overlap
        (vv.visit_time BETWEEN start_time AND end_time) OR
        (vv.visit_time + (vv.expected_duration_minutes || ' minutes')::INTERVAL BETWEEN start_time AND end_time) OR
        (start_time BETWEEN vv.visit_time AND vv.visit_time + (vv.expected_duration_minutes || ' minutes')::INTERVAL)
    );
END;
$$;


--
-- Name: claim_broadcast_recipients(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.claim_broadcast_recipients(p_broadcast_id uuid, p_limit integer DEFAULT 5000) RETURNS TABLE(id uuid, phone_number text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  UPDATE wa_broadcast_recipients
  SET status = 'claimed',
      error_details = NULL
  WHERE id IN (
    SELECT r.id
    FROM wa_broadcast_recipients r
    WHERE r.broadcast_id = p_broadcast_id
      AND r.status = 'pending'
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED  -- skip rows locked by another concurrent claim
  )
  RETURNING id, phone_number;
$$;


--
-- Name: claim_cashier_session(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.claim_cashier_session(p_user_id uuid, p_device_id text, p_device_name text DEFAULT NULL::text, p_app_kind text DEFAULT 'windows'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
    v_token text;
BEGIN
    IF p_user_id IS NULL OR p_device_id IS NULL OR length(p_device_id) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid arguments');
    END IF;

    v_token := encode(extensions.gen_random_bytes(24), 'hex');

    INSERT INTO public.cashier_device_bindings
        (user_id, device_id, device_name, app_kind, session_token, bound_at, last_seen_at)
    VALUES
        (p_user_id, p_device_id, p_device_name, COALESCE(p_app_kind, 'windows'), v_token, now(), now())
    ON CONFLICT (user_id) DO UPDATE
        SET device_id     = EXCLUDED.device_id,
            device_name   = EXCLUDED.device_name,
            app_kind      = EXCLUDED.app_kind,
            session_token = EXCLUDED.session_token,
            bound_at      = now(),
            last_seen_at  = now();

    RETURN jsonb_build_object('success', true, 'session_token', v_token);
END;
$$;


--
-- Name: claim_coupon(uuid, character varying, uuid, bigint, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.claim_coupon(p_campaign_id uuid, p_mobile_number character varying, p_product_id uuid, p_branch_id bigint, p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_claim_id UUID;
  v_product_details JSONB;
  v_stock_remaining INTEGER;
  v_max_claims_per_customer INTEGER;
  v_current_claim_count INTEGER;
BEGIN
  -- Get max claims per customer for this campaign
  SELECT COALESCE(max_claims_per_customer, 1)
  INTO v_max_claims_per_customer
  FROM coupon_campaigns
  WHERE id = p_campaign_id;
  
  -- Count current claims
  SELECT COUNT(*)
  INTO v_current_claim_count
  FROM coupon_claims
  WHERE campaign_id = p_campaign_id
    AND customer_mobile = p_mobile_number;
  
  -- Check if reached maximum claims
  IF v_current_claim_count >= v_max_claims_per_customer THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_message', 'Customer has already claimed ' || v_current_claim_count || ' time(s). Maximum allowed: ' || v_max_claims_per_customer
    );
  END IF;
  
  -- Check product stock
  SELECT stock_remaining INTO v_stock_remaining
  FROM coupon_products
  WHERE id = p_product_id
    AND is_active = true
    AND deleted_at IS NULL
  FOR UPDATE;
  
  IF v_stock_remaining IS NULL OR v_stock_remaining <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_message', 'Product is out of stock'
    );
  END IF;
  
  -- Insert claim record
  INSERT INTO coupon_claims (
    campaign_id,
    customer_mobile,
    product_id,
--

--
-- Name: cleanup_expired_otps(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_expired_otps() RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  DELETE FROM access_code_otp WHERE expires_at < NOW();
$$;


--
-- Name: cleanup_expired_sessions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_expired_sessions() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Clean up expired device sessions
    UPDATE user_device_sessions
    SET is_active = false
    WHERE expires_at < NOW()
    AND is_active = true;
    
    -- Mark old push subscriptions as inactive
    UPDATE push_subscriptions
    SET is_active = false
    WHERE last_seen < NOW() - INTERVAL '30 days'
    AND is_active = true;
    
    -- Clean up old notification queue entries
    DELETE FROM notification_queue
    WHERE created_at < NOW() - INTERVAL '7 days'
    AND status IN ('sent', 'delivered', 'failed');
    
    -- Clean up old audit logs (keep last 90 days)
    DELETE FROM user_audit_logs
    WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$;


--
-- Name: clear_analytics_logs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_analytics_logs() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  tbl record;
  cnt int := 0;
  total_freed bigint := 0;
  tbl_size bigint;
  db_size_before bigint;
  db_size_after bigint;
BEGIN
  -- Get _supabase database size before
  SELECT pg_database_size('_supabase') INTO db_size_before;

  -- Use dblink to truncate tables in _supabase database
  PERFORM dblink_connect('analytics_conn', 'dbname=_supabase user=supabase_admin');

  FOR tbl IN
    SELECT t.tablename FROM dblink('analytics_conn',
      'SELECT tablename::text FROM pg_tables WHERE schemaname = ''_analytics'' AND tablename LIKE ''log_events_%'''
    ) AS t(tablename text)
  LOOP
    PERFORM dblink_exec('analytics_conn', format('TRUNCATE TABLE _analytics.%I', tbl.tablename));
    cnt := cnt + 1;
  END LOOP;

  -- Vacuum to reclaim space
  IF cnt > 0 THEN
    PERFORM dblink_exec('analytics_conn', 'VACUUM FULL');
  END IF;

  PERFORM dblink_disconnect('analytics_conn');

  -- Get _supabase database size after
  SELECT pg_database_size('_supabase') INTO db_size_after;

  RETURN format('Cleared %s log tables, freed ~%s', cnt, pg_size_pretty(GREATEST(db_size_before - db_size_after, 0)));
END;
$$;


--
-- Name: clear_main_document_columns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_main_document_columns() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Clear the dedicated columns based on document type
    IF OLD.document_type = 'health_card' THEN
        OLD.health_card_number := NULL;
        OLD.health_card_expiry := NULL;
    ELSIF OLD.document_type = 'resident_id' THEN
        OLD.resident_id_number := NULL;
        OLD.resident_id_expiry := NULL;
    ELSIF OLD.document_type = 'passport' THEN
        OLD.passport_number := NULL;
        OLD.passport_expiry := NULL;
    ELSIF OLD.document_type = 'driving_license' THEN
        OLD.driving_license_number := NULL;
        OLD.driving_license_expiry := NULL;
    ELSIF OLD.document_type = 'resume' THEN
        OLD.resume_uploaded := FALSE;
    END IF;
    
    RETURN OLD;
END;
$$;


--
-- Name: clear_sync_tables(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_sync_tables(p_tables text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_table text;
    v_allowed_tables text[] := ARRAY[
        'branches', 'users', 'user_sessions', 'user_device_sessions',
        'button_permissions', 'sidebar_buttons', 'button_main_sections', 'button_sub_sections',
        'interface_permissions', 'user_favorite_buttons',
        'erp_synced_products', 'product_categories', 'products', 'product_units',
        'offers', 'offer_products', 'offer_names', 'offer_bundles', 'offer_cart_tiers',
        'bogo_offer_rules', 'flyer_offers', 'flyer_offer_products',
        'customers', 'privilege_cards_master', 'privilege_cards_branch',
        'desktop_themes', 'user_theme_assignments',
        'erp_connections', 'erp_sync_logs'
    ];
BEGIN
    -- Disable FK constraint triggers
    PERFORM set_config('session_replication_role', 'replica', true);
    
    FOREACH v_table IN ARRAY p_tables LOOP
        IF v_table = ANY(v_allowed_tables) THEN
            EXECUTE format('DELETE FROM %I', v_table);
        END IF;
    END LOOP;
    
    -- Re-enable
    PERFORM set_config('session_replication_role', 'origin', true);
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('session_replication_role', 'origin', true);
    RAISE;
END;
$$;


--
-- Name: complete_receiving_task(uuid, uuid, character varying, text, boolean, boolean, boolean, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_receiving_task(receiving_task_id_param uuid, user_id_param uuid, erp_reference_param character varying DEFAULT NULL::character varying, original_bill_file_path_param text DEFAULT NULL::text, has_erp_purchase_invoice boolean DEFAULT false, has_pr_excel_file boolean DEFAULT false, has_original_bill boolean DEFAULT false, completion_photo_url_param text DEFAULT NULL::text, completion_notes_param text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_task RECORD;
  v_receiving_record_id UUID;
  v_template RECORD;
  dependency_check_result JSONB;  -- Changed from JSON to JSONB
  accountant_dependency_result JSONB;  -- Changed from JSON to JSONB
  blocking_roles_array TEXT[];
BEGIN
  -- Get the task
  SELECT * INTO v_task
  FROM receiving_tasks
  WHERE id = receiving_task_id_param;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(  -- Changed from json_build_object
      'success', false,
      'error', 'Task not found',
      'error_code', 'TASK_NOT_FOUND'
    );
  END IF;

  v_receiving_record_id := v_task.receiving_record_id;

  -- Get template for requirements
  SELECT * INTO v_template
  FROM receiving_task_templates
  WHERE role_type = v_task.role_type;

  -- SPECIAL CHECK FOR ACCOUNTANT: Must wait for files to be uploaded
  IF v_task.role_type = 'accountant' THEN
    accountant_dependency_result := check_accountant_dependency(v_receiving_record_id);
    
    IF NOT (accountant_dependency_result->>'can_complete')::BOOLEAN THEN
      RETURN jsonb_build_object(  -- Changed from json_build_object
        'success', false,
        'error', accountant_dependency_result->>'error',
        'error_code', accountant_dependency_result->>'error_code',
        'message', accountant_dependency_result->>'message'
      );
    END IF;
  END IF;

  -- Check photo requirement (for non-exempt tasks)
  IF v_template.require_photo_upload AND completion_photo_url_param IS NULL THEN
    -- Check if task is exempt from new rules (backward compatibility)
    IF v_task.rule_effective_date IS NOT NULL THEN
      RETURN jsonb_build_object(  -- Changed from json_build_object
        'success', false,
--

--
-- Name: complete_receiving_task_fixed(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_receiving_task_fixed(receiving_task_id_param uuid, user_id_param uuid, completion_photo_url_param text DEFAULT NULL::text, completion_notes_param text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_task RECORD;
  v_receiving_record RECORD;
  v_payment_schedule RECORD;
  v_result JSONB;
BEGIN
  -- Get task details
  SELECT * INTO v_task
  FROM receiving_tasks
  WHERE id = receiving_task_id_param
    AND assigned_user_id = user_id_param;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task not found or not assigned to user',
      'error_code', 'TASK_NOT_FOUND'
    );
  END IF;
  
  -- Check if task is already completed
  IF v_task.task_completed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task is already completed',
      'error_code', 'TASK_ALREADY_COMPLETED'
    );
  END IF;
  
  -- Get receiving record
  SELECT * INTO v_receiving_record
  FROM receiving_records
  WHERE id = v_task.receiving_record_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Receiving record not found',
      'error_code', 'RECEIVING_RECORD_NOT_FOUND'
    );
  END IF;

  -- Role-specific validations
  IF v_task.role_type = 'inventory_manager' THEN
    -- Check inventory manager requirements
    IF NOT v_receiving_record.erp_purchase_invoice_uploaded THEN
      RETURN json_build_object(
        'success', false,
--

--
-- Name: complete_receiving_task_simple(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_receiving_task_simple(receiving_task_id_param uuid, user_id_param uuid, completion_photo_url_param text DEFAULT NULL::text, completion_notes_param text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_task RECORD;
  v_receiving_record RECORD;
  v_result JSONB;
BEGIN
  -- Get task details
  SELECT * INTO v_task
  FROM receiving_tasks
  WHERE id = receiving_task_id_param
    AND assigned_user_id = user_id_param;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task not found or not assigned to user',
      'error_code', 'TASK_NOT_FOUND'
    );
  END IF;
  
  -- Check if task is already completed
  IF v_task.task_completed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task is already completed',
      'error_code', 'TASK_ALREADY_COMPLETED'
    );
  END IF;
  
  -- Get receiving record
  SELECT * INTO v_receiving_record
  FROM receiving_records
  WHERE id = v_task.receiving_record_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Receiving record not found',
      'error_code', 'RECEIVING_RECORD_NOT_FOUND'
    );
  END IF;

  -- Simplified role-specific validations (no payment schedule checks!)
  IF v_task.role_type = 'purchase_manager' THEN
    -- Purchase manager ONLY needs PR Excel URL to exist (not the boolean flag!)
    -- CHANGED: Check URL column instead of boolean flag
    IF v_receiving_record.pr_excel_file_url IS NULL OR v_receiving_record.pr_excel_file_url = '' THEN
      RETURN json_build_object(
        'success', false,
--

--
-- Name: complete_visit_and_update_next(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_visit_and_update_next(visit_id uuid) RETURNS date
    LANGUAGE plpgsql
    AS $$
DECLARE
    visit_record vendor_visits%ROWTYPE;
    new_next_date DATE;
BEGIN
    -- Get the visit record
    SELECT * INTO visit_record FROM vendor_visits WHERE id = visit_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Visit schedule not found with id: %', visit_id;
    END IF;
    
    -- Calculate new next visit date
    new_next_date := calculate_next_visit_date(
        visit_record.visit_type,
        visit_record.weekday_name,
        visit_record.fresh_type,
        visit_record.day_number,
        visit_record.skip_days,
        visit_record.start_date,
        visit_record.next_visit_date
    );
    
    -- Update the record with new next visit date
    UPDATE vendor_visits 
    SET next_visit_date = new_next_date, updated_at = NOW()
    WHERE id = visit_id;
    
    RETURN new_next_date;
END;
$$;


--
-- Name: confirm_loyalty_redemption(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_loyalty_redemption(p_redemption_id uuid, p_otp_code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_redemp   record;
BEGIN
    SELECT * INTO v_redemp
    FROM public.loyalty_redemptions
    WHERE id = p_redemption_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'redemption_not_found');
    END IF;

    IF v_redemp.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'redemption_not_pending',
            'status', v_redemp.status);
    END IF;

    -- Check OTP expiry (10 minutes)
    IF now() - v_redemp.otp_sent_at > interval '10 minutes' THEN
        UPDATE public.loyalty_redemptions SET status = 'expired' WHERE id = p_redemption_id;
        RETURN jsonb_build_object('success', false, 'error', 'otp_expired');
    END IF;

    -- Validate OTP
    IF v_redemp.otp_code != p_otp_code THEN
        -- Increment attempts
        UPDATE public.loyalty_redemptions
        SET otp_attempts = otp_attempts + 1
        WHERE id = p_redemption_id;

        -- Lock after 5 failed attempts
        IF v_redemp.otp_attempts + 1 >= 5 THEN
            UPDATE public.loyalty_redemptions SET status = 'cancelled' WHERE id = p_redemption_id;
            RETURN jsonb_build_object('success', false, 'error', 'max_otp_attempts');
        END IF;

        RETURN jsonb_build_object('success', false, 'error', 'invalid_otp',
            'attempts_remaining', 5 - (v_redemp.otp_attempts + 1));
    END IF;

    -- OTP valid ΓÇö confirm and update balances atomically
    UPDATE public.loyalty_redemptions
    SET status = 'confirmed', otp_confirmed_at = now(), confirmed_at = now()
    WHERE id = p_redemption_id;

    UPDATE public.customers
    SET
--

--
-- Name: copy_completion_requirements_to_assignment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.copy_completion_requirements_to_assignment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the assignment with completion requirements from the task
    UPDATE quick_task_assignments 
    SET 
        require_task_finished = (
            SELECT require_task_finished 
            FROM quick_tasks 
            WHERE id = NEW.quick_task_id
        ),
        require_photo_upload = (
            SELECT require_photo_upload 
            FROM quick_tasks 
            WHERE id = NEW.quick_task_id
        ),
        require_erp_reference = (
            SELECT require_erp_reference 
            FROM quick_tasks 
            WHERE id = NEW.quick_task_id
        )
    WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$;


--
-- Name: count_bills_without_erp_reference(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_bills_without_erp_reference() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    no_erp_count INTEGER;
BEGIN
    -- Count receiving records where erp_purchase_invoice_reference is NULL or empty
    SELECT COUNT(*) INTO no_erp_count
    FROM receiving_records rr
    WHERE rr.erp_purchase_invoice_reference IS NULL 
    OR rr.erp_purchase_invoice_reference = ''
    OR TRIM(rr.erp_purchase_invoice_reference) = '';
    
    RETURN COALESCE(no_erp_count, 0);
END;
$$;


--
-- Name: count_bills_without_erp_reference_by_branch(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_bills_without_erp_reference_by_branch(branch_id_param bigint DEFAULT NULL::bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    result_count INTEGER;
BEGIN
    IF branch_id_param IS NULL THEN
        -- If no branch specified, return all
        SELECT COUNT(*) INTO result_count
        FROM receiving_records
        WHERE erp_purchase_invoice_reference IS NULL OR erp_purchase_invoice_reference = '' OR TRIM(erp_purchase_invoice_reference) = '';
    ELSE
        -- Count for specific branch
        SELECT COUNT(*) INTO result_count
        FROM receiving_records
        WHERE (erp_purchase_invoice_reference IS NULL OR erp_purchase_invoice_reference = '' OR TRIM(erp_purchase_invoice_reference) = '')
        AND branch_id = branch_id_param;
    END IF;
    
    RETURN COALESCE(result_count, 0);
END;
$$;


--
-- Name: FUNCTION count_bills_without_erp_reference_by_branch(branch_id_param bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.count_bills_without_erp_reference_by_branch(branch_id_param bigint) IS 'Counts receiving records without ERP purchase invoice reference, optionally filtered by branch';


--
-- Name: count_bills_without_original(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_bills_without_original() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    no_original_count INTEGER;
BEGIN
    -- Count receiving records where original_bill_url is NULL or empty
    SELECT COUNT(*) INTO no_original_count
    FROM receiving_records rr
    WHERE rr.original_bill_url IS NULL 
    OR rr.original_bill_url = ''
    OR TRIM(rr.original_bill_url) = '';
    
    RETURN COALESCE(no_original_count, 0);
END;
$$;


--
-- Name: count_bills_without_original_by_branch(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_bills_without_original_by_branch(branch_id_param bigint DEFAULT NULL::bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    result_count INTEGER;
BEGIN
    IF branch_id_param IS NULL THEN
        -- If no branch specified, return all
        SELECT COUNT(*) INTO result_count
        FROM receiving_records
        WHERE original_bill_url IS NULL OR original_bill_url = '' OR TRIM(original_bill_url) = '';
    ELSE
        -- Count for specific branch
        SELECT COUNT(*) INTO result_count
        FROM receiving_records
        WHERE (original_bill_url IS NULL OR original_bill_url = '' OR TRIM(original_bill_url) = '')
        AND branch_id = branch_id_param;
    END IF;
    
    RETURN COALESCE(result_count, 0);
END;
$$;


--
-- Name: FUNCTION count_bills_without_original_by_branch(branch_id_param bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.count_bills_without_original_by_branch(branch_id_param bigint) IS 'Counts receiving records without original bill file, optionally filtered by branch';


--
-- Name: count_bills_without_pr_excel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_bills_without_pr_excel() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM receiving_records
        WHERE pr_excel_file_url IS NULL 
           OR pr_excel_file_url = ''
    );
END;
$$;


--
-- Name: count_bills_without_pr_excel_by_branch(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_bills_without_pr_excel_by_branch(branch_id_param bigint DEFAULT NULL::bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    result_count INTEGER;
BEGIN
    IF branch_id_param IS NULL THEN
        -- If no branch specified, return all
        SELECT COUNT(*) INTO result_count
        FROM receiving_records
        WHERE pr_excel_file_url IS NULL OR pr_excel_file_url = '';
    ELSE
        -- Count for specific branch
        SELECT COUNT(*) INTO result_count
        FROM receiving_records
        WHERE (pr_excel_file_url IS NULL OR pr_excel_file_url = '')
        AND branch_id = branch_id_param;
    END IF;
    
    RETURN COALESCE(result_count, 0);
END;
$$;


--
-- Name: FUNCTION count_bills_without_pr_excel_by_branch(branch_id_param bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.count_bills_without_pr_excel_by_branch(branch_id_param bigint) IS 'Counts receiving records without PR Excel file, optionally filtered by branch';


--
-- Name: count_completed_receiving_tasks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_completed_receiving_tasks() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    completed_count INTEGER;
BEGIN
    -- Simple logic: if task_id from receiving_tasks exists in task_completions table, count as completed
    SELECT COUNT(DISTINCT rt.id) INTO completed_count
    FROM receiving_tasks rt
    WHERE EXISTS (
        SELECT 1 
        FROM task_completions tc 
        WHERE tc.task_id = rt.task_id
    );
    
    RETURN COALESCE(completed_count, 0);
END;
$$;


--
-- Name: count_finished_receiving_tasks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_finished_receiving_tasks() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    finished_count INTEGER;
BEGIN
    -- Count receiving tasks that are marked as task_finished_completed = true
    SELECT COUNT(DISTINCT rt.id) INTO finished_count
    FROM receiving_tasks rt
    WHERE EXISTS (
        SELECT 1 
        FROM task_completions tc 
        WHERE tc.task_id = rt.task_id 
        AND tc.task_finished_completed = true
    );
    
    RETURN COALESCE(finished_count, 0);
END;
$$;


--
-- Name: count_incomplete_receiving_tasks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_incomplete_receiving_tasks() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    incomplete_count INTEGER;
BEGIN
    -- Take task_id from receiving_tasks and check if NOT completed in task_completions table
    -- Count as incomplete if there's no matching task_completion OR task_finished_completed = false
    SELECT COUNT(DISTINCT rt.id) INTO incomplete_count
    FROM receiving_tasks rt
    WHERE NOT EXISTS (
        SELECT 1 
        FROM task_completions tc 
        WHERE tc.task_id = rt.task_id 
        AND tc.task_finished_completed = true
    );
    
    RETURN COALESCE(incomplete_count, 0);
END;
$$;


--
-- Name: count_incomplete_receiving_tasks_detailed(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.count_incomplete_receiving_tasks_detailed() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    incomplete_count INTEGER;
BEGIN
    -- Count receiving tasks where either:
    -- 1. The receiving task is not marked as completed, OR
    -- 2. The task itself is not completed, OR
    -- 3. There's no task_completion record, OR
    -- 4. The task_completion is not fully finished
    SELECT COUNT(*) INTO incomplete_count
    FROM receiving_tasks rt
    LEFT JOIN tasks t ON rt.task_id = t.id
    LEFT JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
    WHERE (
        rt.task_completed = false 
        OR t.status != 'completed'
        OR tc.id IS NULL
        OR tc.task_finished_completed = false
    );
    
    RETURN COALESCE(incomplete_count, 0);
END;
$$;


--
-- Name: create_customer_order(uuid, bigint, jsonb, character varying, character varying, numeric, numeric, numeric, numeric, numeric, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_customer_order(p_customer_id uuid, p_branch_id bigint, p_selected_location jsonb, p_fulfillment_method character varying, p_payment_method character varying, p_subtotal_amount numeric, p_delivery_fee numeric, p_discount_amount numeric, p_tax_amount numeric, p_total_amount numeric, p_total_items integer, p_total_quantity integer, p_customer_notes text DEFAULT NULL::text) RETURNS TABLE(order_id uuid, order_number character varying, success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_order_id UUID;
    v_order_number VARCHAR(50);
    v_customer_name VARCHAR(255);
    v_customer_phone VARCHAR(20);
    v_customer_whatsapp VARCHAR(20);
BEGIN
    -- Get customer information
    SELECT name, whatsapp_number, whatsapp_number
    INTO v_customer_name, v_customer_phone, v_customer_whatsapp
    FROM customers
    WHERE id = p_customer_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL::UUID, NULL::VARCHAR, FALSE, 'Customer not found';
        RETURN;
    END IF;
    
    -- Generate order number
    v_order_number := generate_order_number();
    
    -- Create order (will bypass RLS due to SECURITY DEFINER)
    INSERT INTO orders (
        order_number,
        customer_id,
        customer_name,
        customer_phone,
        customer_whatsapp,
        branch_id,
        selected_location,
        order_status,
        fulfillment_method,
        subtotal_amount,
        delivery_fee,
        discount_amount,
        tax_amount,
        total_amount,
        payment_method,
        payment_status,
        total_items,
        total_quantity,
        customer_notes
    ) VALUES (
        v_order_number,
        p_customer_id,
        v_customer_name,
        v_customer_phone,
--

--
-- Name: create_customer_registration(text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_customer_registration(p_name text, p_whatsapp_number text, p_branch_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
    v_customer_id uuid;
    v_access_code text;
    v_hashed_code text;
    v_formatted_number text;
    v_existing_customer record;
    v_system_user_id uuid := 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b';
BEGIN
    v_formatted_number := regexp_replace(p_whatsapp_number, '[^0-9]', '', 'g');
    IF length(v_formatted_number) = 9 THEN
        v_formatted_number := '966' || v_formatted_number;
    END IF;

    SELECT id, name, registration_status, access_code
    INTO v_existing_customer
    FROM public.customers
    WHERE regexp_replace(whatsapp_number, '[^0-9]', '', 'g') = v_formatted_number
       OR whatsapp_number = v_formatted_number
       OR whatsapp_number = '+' || v_formatted_number
    LIMIT 1;

    IF v_existing_customer.id IS NOT NULL THEN
        -- Pre-registered or deleted: upgrade to approved
        IF v_existing_customer.registration_status IN ('pre_registered', 'deleted') THEN
            v_access_code := generate_unique_customer_access_code();
            v_hashed_code := encode(digest(v_access_code::bytea, 'sha256'), 'hex');

            UPDATE public.customers
            SET name = p_name,
                access_code = v_hashed_code,
                access_code_generated_at = now(),
                registration_status = 'approved',
                updated_at = now()
            WHERE id = v_existing_customer.id
            RETURNING id INTO v_customer_id;

            INSERT INTO public.customer_access_code_history (
                customer_id, old_access_code, new_access_code,
                generated_by, reason, notes
            ) VALUES (
                v_customer_id, v_existing_customer.access_code, v_hashed_code,
                v_system_user_id,
                CASE WHEN v_existing_customer.registration_status = 'deleted'
                     THEN 're_registration'
                     ELSE 'pre_registered_upgrade'
                END,
                CASE WHEN v_existing_customer.registration_status = 'deleted'
--

--
-- Name: create_default_auto_schedule_config(bigint, time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_default_auto_schedule_config(p_branch_id bigint, p_start_time time without time zone DEFAULT '09:00:00'::time without time zone, p_end_time time without time zone DEFAULT '17:00:00'::time without time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO auto_schedule_config (
        branch_id,
        default_start_time,
        default_end_time,
        default_hours
    ) VALUES (
        p_branch_id,
        p_start_time,
        p_end_time,
        calculate_working_hours(p_start_time, p_end_time, FALSE)
    ) ON CONFLICT (branch_id) DO NOTHING;
END;
$$;


--
-- Name: create_default_auto_schedule_config(uuid, time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_default_auto_schedule_config(p_branch_id uuid, p_start_time time without time zone DEFAULT '09:00:00'::time without time zone, p_end_time time without time zone DEFAULT '17:00:00'::time without time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO auto_schedule_config (
        branch_id,
        default_start_time,
        default_end_time,
        default_hours,
        basic_hours
    ) VALUES (
        p_branch_id,
        p_start_time,
        p_end_time,
        calculate_working_hours(p_start_time, p_end_time, FALSE),
        calculate_working_hours(p_start_time, p_end_time, FALSE)
    ) ON CONFLICT (branch_id) DO NOTHING;
END;
$$;


--
-- Name: create_default_interface_permissions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_default_interface_permissions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO public.interface_permissions (user_id, updated_by)
    VALUES (NEW.id, NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$;


--
-- Name: create_hr_salary_note(text, text, text, date, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_hr_salary_note(p_employee_id text, p_note_type text, p_note_text text, p_from_date date DEFAULT NULL::date, p_to_date date DEFAULT NULL::date, p_until_date date DEFAULT NULL::date) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO public.hr_salary_notes
        (employee_id, note_type, note_text, from_date, to_date, until_date, created_by)
    VALUES
        (p_employee_id, p_note_type, p_note_text, p_from_date, p_to_date, p_until_date, auth.uid())
    RETURNING id INTO v_id;

    RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


--
-- Name: create_notification_recipients(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_notification_recipients() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id uuid;
    v_role text;
    v_branch_id uuid;
BEGIN
    -- Handle specific users
    IF NEW.target_type = 'specific_users' AND NEW.target_users IS NOT NULL THEN
        FOR v_user_id IN
            SELECT (jsonb_array_elements_text(NEW.target_users))::uuid
        LOOP
            INSERT INTO notification_recipients (
                notification_id,
                user_id,
                delivery_status,
                created_at
            ) VALUES (
                NEW.id,
                v_user_id,
                'pending',
                NOW()
            );
        END LOOP;
    END IF;

    -- Handle roles
    IF NEW.target_type = 'roles' AND NEW.target_roles IS NOT NULL THEN
        FOR v_user_id IN
            SELECT id FROM users
            WHERE role IN (SELECT jsonb_array_elements_text(NEW.target_roles))
            AND deleted_at IS NULL
        LOOP
            INSERT INTO notification_recipients (
                notification_id,
                user_id,
                delivery_status,
                created_at
            ) VALUES (
                NEW.id,
                v_user_id,
                'pending',
                NOW()
            );
        END LOOP;
    END IF;

    -- Handle branches
    IF NEW.target_type = 'branches' AND NEW.target_branches IS NOT NULL THEN
        FOR v_user_id IN
--

--
-- Name: create_notification_simple(text, text, text, text, uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_notification_simple(title_param text, message_param text, created_by_param text, created_by_name_param text, target_user_id_param uuid, task_id_param uuid, assignment_id_param uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO notifications (
        title,
        message,
        created_by,
        created_by_name,
        target_type,
        target_users,
        type,
        priority,
        task_id,
        task_assignment_id
    ) VALUES (
        title_param,
        message_param,
        created_by_param,
        created_by_name_param,
        'specific_users',
        to_jsonb(ARRAY[target_user_id_param::TEXT]),
        'task',
        'high',
        task_id_param,
        assignment_id_param
    ) RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$;


--
-- Name: create_quick_task_notification(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_quick_task_notification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    assigned_by_name TEXT;
    assigned_to_name TEXT;
BEGIN
    -- Get the name of who assigned the task (from hr_employees if available, otherwise username)
    SELECT COALESCE(he.name, u.username, 'Admin') INTO assigned_by_name
    FROM users u
    LEFT JOIN hr_employees he ON u.employee_id = he.id
    WHERE u.id = (SELECT assigned_by FROM quick_tasks WHERE id = NEW.quick_task_id);
    
    -- Get the name of who the task is assigned to (from hr_employees if available, otherwise username)
    SELECT COALESCE(he.name, u.username, 'User') INTO assigned_to_name
    FROM users u
    LEFT JOIN hr_employees he ON u.employee_id = he.id
    WHERE u.id = NEW.assigned_to_user_id;
    
    -- Insert notification for each assigned user
    INSERT INTO notifications (
        title,
        message,
        type,
        priority,
        target_type,
        target_users,
        created_by,
        created_by_name,
        metadata,
        created_at
    )
    SELECT 
        'New Quick Task: ' || qt.title,
        'You have been assigned a new quick task: "' || qt.title || 
        '" by ' || COALESCE(assigned_by_name, 'Admin') || 
        '. Priority: ' || qt.priority || 
        '. Deadline: ' || to_char(qt.deadline_datetime, 'YYYY-MM-DD HH24:MI') ||
        CASE 
            WHEN qt.description IS NOT NULL AND qt.description != '' 
            THEN E'\n\nDescription: ' || qt.description
            ELSE ''
        END,
        'task_assignment',
        qt.priority,
        'specific_users',
        jsonb_build_array(NEW.assigned_to_user_id),
        qt.assigned_by::text,
        COALESCE(assigned_by_name, 'Admin'),
        jsonb_build_object(
            'quick_task_id', qt.id,
--

--
-- Name: create_quick_task_with_assignments(character varying, text, character varying, timestamp with time zone, uuid, uuid[], boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_quick_task_with_assignments(title_param character varying, description_param text, priority_param character varying DEFAULT 'medium'::character varying, deadline_param timestamp with time zone DEFAULT NULL::timestamp with time zone, created_by_param uuid DEFAULT NULL::uuid, assigned_user_ids uuid[] DEFAULT NULL::uuid[], require_task_finished_param boolean DEFAULT true, require_photo_upload_param boolean DEFAULT false, require_erp_reference_param boolean DEFAULT false) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    task_id UUID;
    user_id UUID;
BEGIN
    -- Create the quick task with completion requirements
    INSERT INTO quick_tasks (
        title,
        description,
        priority,
        deadline_datetime,
        created_by_user_id,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        status
    ) VALUES (
        title_param,
        description_param,
        priority_param,
        deadline_param,
        created_by_param,
        require_task_finished_param,
        require_photo_upload_param,
        require_erp_reference_param,
        'active'
    ) RETURNING id INTO task_id;
    
    -- Create assignments for each user if provided
    IF assigned_user_ids IS NOT NULL THEN
        FOREACH user_id IN ARRAY assigned_user_ids
        LOOP
            INSERT INTO quick_task_assignments (
                quick_task_id,
                assigned_to_user_id,
                require_task_finished,
                require_photo_upload,
                require_erp_reference,
                status
            ) VALUES (
                task_id,
                user_id,
                require_task_finished_param,
                require_photo_upload_param,
                require_erp_reference_param,
                'pending'
            );
        END LOOP;
    END IF;
--

--
-- Name: create_recurring_assignment(uuid, uuid, uuid, character varying, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_recurring_assignment(task_id uuid, assigned_to uuid, assigned_by uuid, recurrence_pattern character varying, start_date date, end_date date DEFAULT NULL::date) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    schedule_id UUID;
BEGIN
    INSERT INTO recurring_assignment_schedules (
        task_id,
        assigned_to,
        assigned_by,
        recurrence_pattern,
        start_date,
        end_date,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        task_id,
        assigned_to,
        assigned_by,
        recurrence_pattern,
        start_date,
        end_date,
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO schedule_id;
    
    RETURN schedule_id;
END;
$$;


--
-- Name: create_recurring_assignment(uuid, text, text, text, text, uuid, text, integer, integer[], time without time zone, date, date, integer, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_recurring_assignment(p_task_id uuid, p_assignment_type text, p_assigned_by text, p_repeat_type text, p_assigned_to_user_id text DEFAULT NULL::text, p_assigned_to_branch_id uuid DEFAULT NULL::uuid, p_assigned_by_name text DEFAULT NULL::text, p_repeat_interval integer DEFAULT 1, p_repeat_on_days integer[] DEFAULT NULL::integer[], p_execute_time time without time zone DEFAULT '09:00:00'::time without time zone, p_start_date date DEFAULT CURRENT_DATE, p_end_date date DEFAULT NULL::date, p_max_occurrences integer DEFAULT NULL::integer, p_notes text DEFAULT NULL::text, p_is_reassignable boolean DEFAULT true) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    assignment_id UUID;
    next_exec_time TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Calculate first execution time
    next_exec_time := (p_start_date::text || ' ' || p_execute_time::text)::timestamp with time zone;
    
    -- Create the assignment record
    INSERT INTO public.task_assignments (
        task_id,
        assignment_type,
        assigned_to_user_id,
        assigned_to_branch_id,
        assigned_by,
        assigned_by_name,
        is_recurring,
        is_reassignable,
        notes
    ) VALUES (
        p_task_id,
        p_assignment_type,
        p_assigned_to_user_id,
        p_assigned_to_branch_id,
        p_assigned_by,
        p_assigned_by_name,
        true,
        p_is_reassignable,
        p_notes
    )
    RETURNING id INTO assignment_id;
    
    -- Create the recurring schedule
    INSERT INTO public.recurring_assignment_schedules (
        assignment_id,
        repeat_type,
        repeat_interval,
        repeat_on_days,
        execute_time,
        start_date,
        end_date,
        max_occurrences,
        next_execution_at,
        created_by
    ) VALUES (
        assignment_id,
        p_repeat_type,
        p_repeat_interval,
        p_repeat_on_days,
--

--
-- Name: create_salary_statement(text, date, date, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_salary_statement(p_statement_name text, p_start_date date, p_end_date date, p_data_json jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_id  uuid;
    v_uid uuid;
BEGIN
    IF p_statement_name IS NULL OR length(trim(p_statement_name)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'statement_name is required');
    END IF;
    IF p_start_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'start_date is required');
    END IF;
    IF p_end_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'end_date is required');
    END IF;
    IF p_end_date < p_start_date THEN
        RETURN jsonb_build_object('success', false, 'error', 'end_date must be >= start_date');
    END IF;
    IF p_data_json IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'data_json is required');
    END IF;

    BEGIN
        v_uid := auth.uid();
    EXCEPTION WHEN OTHERS THEN
        v_uid := NULL;
    END;

    INSERT INTO public.hr_salary_statements (statement_name, start_date, end_date, data_json, created_by)
    VALUES (trim(p_statement_name), p_start_date, p_end_date, p_data_json, v_uid)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


--
-- Name: create_schedule_template(bigint, character varying, time without time zone, time without time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_schedule_template(p_branch_id bigint, p_template_name character varying, p_start_time time without time zone, p_end_time time without time zone, p_weekdays_only boolean DEFAULT true) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    template_id BIGINT;
BEGIN
    INSERT INTO schedule_templates (
        branch_id,
        template_name,
        default_start_time,
        default_end_time,
        is_overnight,
        default_hours,
        applies_to_weekdays,
        applies_to_weekends
    ) VALUES (
        p_branch_id,
        p_template_name,
        p_start_time,
        p_end_time,
        is_overnight_shift(p_start_time, p_end_time),
        calculate_working_hours(p_start_time, p_end_time, is_overnight_shift(p_start_time, p_end_time)),
        p_weekdays_only,
        NOT p_weekdays_only
    ) RETURNING id INTO template_id;
    
    RETURN template_id;
END;
$$;


--
-- Name: create_schedule_template(uuid, character varying, time without time zone, time without time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_schedule_template(p_branch_id uuid, p_template_name character varying, p_start_time time without time zone, p_end_time time without time zone, p_weekdays_only boolean DEFAULT true) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    template_id UUID;
BEGIN
    INSERT INTO schedule_templates (
        branch_id,
        template_name,
        default_start_time,
        default_end_time,
        is_overnight,
        default_hours,
        applies_to_weekdays,
        applies_to_weekends
    ) VALUES (
        p_branch_id,
        p_template_name,
        p_start_time,
        p_end_time,
        is_overnight_shift(p_start_time, p_end_time),
        calculate_working_hours(p_start_time, p_end_time, is_overnight_shift(p_start_time, p_end_time)),
        p_weekdays_only,
        NOT p_weekdays_only
    ) RETURNING id INTO template_id;
    
    RETURN template_id;
END;
$$;


--
-- Name: create_scheduled_assignment(uuid, uuid, uuid, timestamp with time zone, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_scheduled_assignment(task_id uuid, assigned_to uuid, assigned_by uuid, scheduled_for timestamp with time zone, priority character varying DEFAULT 'medium'::character varying) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO task_assignments (
        task_id,
        assigned_to,
        assigned_by,
        status,
        priority,
        assigned_at,
        created_at,
        updated_at
    ) VALUES (
        task_id,
        assigned_to,
        assigned_by,
        'pending',
        priority,
        scheduled_for,
        NOW(),
        NOW()
    ) RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$;


--
-- Name: create_scheduled_assignment(uuid, text, text, text, uuid, text, date, time without time zone, date, time without time zone, boolean, text, text, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_scheduled_assignment(p_task_id uuid, p_assignment_type text, p_assigned_by text, p_assigned_to_user_id text DEFAULT NULL::text, p_assigned_to_branch_id uuid DEFAULT NULL::uuid, p_assigned_by_name text DEFAULT NULL::text, p_schedule_date date DEFAULT NULL::date, p_schedule_time time without time zone DEFAULT NULL::time without time zone, p_deadline_date date DEFAULT NULL::date, p_deadline_time time without time zone DEFAULT NULL::time without time zone, p_is_reassignable boolean DEFAULT true, p_notes text DEFAULT NULL::text, p_priority_override text DEFAULT NULL::text, p_require_task_finished boolean DEFAULT true, p_require_photo_upload boolean DEFAULT false, p_require_erp_reference boolean DEFAULT false) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO public.task_assignments (
        task_id,
        assignment_type,
        assigned_to_user_id,
        assigned_to_branch_id,
        assigned_by,
        assigned_by_name,
        schedule_date,
        schedule_time,
        deadline_date,
        deadline_time,
        is_reassignable,
        notes,
        priority_override,
        require_task_finished,
        require_photo_upload,
        require_erp_reference
    ) VALUES (
        p_task_id,
        p_assignment_type,
        p_assigned_to_user_id,
        p_assigned_to_branch_id,
        p_assigned_by,
        p_assigned_by_name,
        p_schedule_date,
        p_schedule_time,
        p_deadline_date,
        p_deadline_time,
        p_is_reassignable,
        p_notes,
        p_priority_override,
        p_require_task_finished,
        p_require_photo_upload,
        p_require_erp_reference
    )
    RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$;


--
-- Name: FUNCTION create_scheduled_assignment(p_task_id uuid, p_assignment_type text, p_assigned_by text, p_assigned_to_user_id text, p_assigned_to_branch_id uuid, p_assigned_by_name text, p_schedule_date date, p_schedule_time time without time zone, p_deadline_date date, p_deadline_time time without time zone, p_is_reassignable boolean, p_notes text, p_priority_override text, p_require_task_finished boolean, p_require_photo_upload boolean, p_require_erp_reference boolean); Type: COMMENT; Schema: public; Owner: -
--
--

--
-- Name: create_system_admin(text, text, text, boolean, public.user_type_enum); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_system_admin(p_username text, p_password text, p_quick_access_code text DEFAULT NULL::text, p_is_master_admin boolean DEFAULT true, p_user_type public.user_type_enum DEFAULT 'global'::public.user_type_enum) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    password_salt TEXT;
    qr_salt TEXT;
    admin_user_id UUID;
    main_branch_id BIGINT;
    final_quick_code TEXT;
BEGIN
    -- Get main branch ID (or any branch)
    SELECT id INTO main_branch_id FROM branches WHERE is_main_branch = true LIMIT 1;
    IF main_branch_id IS NULL THEN
        SELECT id INTO main_branch_id FROM branches LIMIT 1;
    END IF;
    
    -- Generate salts
    password_salt := generate_salt();
    qr_salt := generate_salt();
    
    -- Use provided quick access code or generate unique one
    IF p_quick_access_code IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM users WHERE quick_access_code = p_quick_access_code) THEN
            RAISE EXCEPTION 'Quick access code % is already in use', p_quick_access_code;
        END IF;
        final_quick_code := p_quick_access_code;
    ELSE
        final_quick_code := generate_unique_quick_access_code();
    END IF;
    
    -- Insert the admin user with is_master_admin flag instead of role_type
    INSERT INTO users (
        username, 
        password_hash, 
        salt,
        quick_access_code, 
        quick_access_salt,
        user_type,
        branch_id,
        is_master_admin,
        is_admin,
        status,
        is_first_login,
        password_expires_at
    ) VALUES (
        p_username,
        hash_password(p_password, password_salt),
        password_salt,
        final_quick_code,
        hash_password(final_quick_code, qr_salt),
        p_user_type,
--

--
-- Name: create_system_admin(text, text, text, public.role_type_enum, public.user_type_enum); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_system_admin(p_username text, p_password text, p_quick_access_code text DEFAULT NULL::text, p_role_type public.role_type_enum DEFAULT 'Master Admin'::public.role_type_enum, p_user_type public.user_type_enum DEFAULT 'global'::public.user_type_enum) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    password_salt TEXT;
    qr_salt TEXT;
    admin_user_id UUID;
    main_branch_id BIGINT;
    final_quick_code TEXT;
BEGIN
    -- Get main branch ID (or any branch)
    SELECT id INTO main_branch_id FROM branches WHERE is_main_branch = true LIMIT 1;
    IF main_branch_id IS NULL THEN
        SELECT id INTO main_branch_id FROM branches LIMIT 1;
    END IF;
    
    -- Generate salts
    password_salt := generate_salt();
    qr_salt := generate_salt();
    
    -- Use provided quick access code or generate unique one
    IF p_quick_access_code IS NOT NULL THEN
        -- Check if provided code is already in use
        IF EXISTS (SELECT 1 FROM users WHERE quick_access_code = p_quick_access_code) THEN
            RAISE EXCEPTION 'Quick access code % is already in use', p_quick_access_code;
        END IF;
        final_quick_code := p_quick_access_code;
    ELSE
        final_quick_code := generate_unique_quick_access_code();
    END IF;
    
    -- Insert the admin user
    INSERT INTO users (
        username, 
        password_hash, 
        salt,
        quick_access_code, 
        quick_access_salt,
        user_type,
        branch_id,
        role_type, 
        status,
        is_first_login,
        password_expires_at
    ) VALUES (
        p_username,
        hash_password(p_password, password_salt),
        password_salt,
        final_quick_code,
        hash_password(final_quick_code, qr_salt),
        p_user_type,
--

--
-- Name: create_task(text, text, text, text, text, text, date, time without time zone, boolean, boolean, boolean, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_task(title_param text, description_param text, created_by_param text, created_by_name_param text, created_by_role_param text, priority_param text, due_date_param date, due_time_param time without time zone, require_task_finished_param boolean, require_photo_upload_param boolean, require_erp_reference_param boolean, can_escalate_param boolean, can_reassign_param boolean) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    task_id UUID;
    calculated_due_datetime TIMESTAMPTZ;
BEGIN
    -- Calculate due_datetime if due_date is provided
    IF due_date_param IS NOT NULL THEN
        calculated_due_datetime := due_date_param + COALESCE(due_time_param, '23:59:59'::TIME);
    END IF;
    
    -- Insert only columns that exist in the tasks table
    INSERT INTO tasks (
        title,
        description,
        created_by,
        created_by_name,
        created_by_role,
        priority,
        due_date,
        due_time,
        due_datetime,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        can_escalate,
        can_reassign,
        status
    ) VALUES (
        title_param,
        description_param,
        created_by_param,
        created_by_name_param,
        created_by_role_param,
        priority_param,
        due_date_param,
        due_time_param,
        calculated_due_datetime,
        require_task_finished_param,
        require_photo_upload_param,
        require_erp_reference_param,
        can_escalate_param,
        can_reassign_param,
        'active'
    ) RETURNING id INTO task_id;
    
    RETURN task_id;
END;
$$;


--
-- Name: create_user(character varying, character varying, boolean, boolean, character varying, bigint, uuid, uuid, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_user(p_username character varying, p_password character varying, p_is_master_admin boolean DEFAULT false, p_is_admin boolean DEFAULT false, p_user_type character varying DEFAULT 'branch_specific'::character varying, p_branch_id bigint DEFAULT NULL::bigint, p_employee_id uuid DEFAULT NULL::uuid, p_position_id uuid DEFAULT NULL::uuid, p_quick_access_code character varying DEFAULT NULL::character varying) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_quick_access_code VARCHAR(6);
  v_quick_access_hash TEXT;
  v_password_hash TEXT;
  v_salt TEXT;
  v_quick_access_salt TEXT;
BEGIN
  v_salt := extensions.gen_salt('bf');
  v_quick_access_salt := extensions.gen_salt('bf');

  IF p_quick_access_code IS NULL THEN
    -- Generate a unique random 6-digit code
    v_quick_access_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');

    -- Loop until we find a unique code (check against hashed values)
    WHILE EXISTS (
      SELECT 1 FROM users 
      WHERE extensions.crypt(v_quick_access_code, quick_access_code) = quick_access_code
    ) LOOP
      v_quick_access_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    END LOOP;
  ELSE
    v_quick_access_code := p_quick_access_code;

    -- Check if this code already exists (by hashing and comparing)
    IF EXISTS (
      SELECT 1 FROM users 
      WHERE extensions.crypt(v_quick_access_code, quick_access_code) = quick_access_code
    ) THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Quick access code already exists'
      );
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Username already exists'
    );
  END IF;

  v_password_hash := extensions.crypt(p_password, v_salt);
  
  -- Hash the quick access code with bcrypt
--

--
-- Name: create_user_profile(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_user_profile() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO user_profiles (user_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$;


--
-- Name: create_variation_group(text, text[], text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_variation_group(p_parent_barcode text, p_variation_barcodes text[], p_group_name_en text, p_group_name_ar text, p_image_override text DEFAULT NULL::text, p_user_id uuid DEFAULT NULL::uuid) RETURNS TABLE(success boolean, message text, affected_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_affected_count INTEGER := 0;
  v_barcode TEXT;
  v_order INTEGER := 1;
BEGIN
  -- Validate parent product exists
  IF NOT EXISTS (SELECT 1 FROM products WHERE barcode = p_parent_barcode) THEN
    RETURN QUERY SELECT false, 'Parent product barcode does not exist', 0;
    RETURN;
  END IF;

  -- Validate no circular references
  IF p_parent_barcode = ANY(p_variation_barcodes) THEN
    -- Remove parent from variations array if present
    p_variation_barcodes := array_remove(p_variation_barcodes, p_parent_barcode);
  END IF;

  -- Update parent product
  UPDATE products
  SET 
    is_variation = true,
    parent_product_barcode = p_parent_barcode,
    variation_group_name_en = p_group_name_en,
    variation_group_name_ar = p_group_name_ar,
    variation_order = 0,
    variation_image_override = p_image_override,
    created_by = COALESCE(p_user_id, created_by),
    modified_by = p_user_id,
    modified_at = NOW()
  WHERE barcode = p_parent_barcode;

  v_affected_count := v_affected_count + 1;

  -- Update variation products
  FOREACH v_barcode IN ARRAY p_variation_barcodes
  LOOP
    UPDATE products
    SET 
      is_variation = true,
      parent_product_barcode = p_parent_barcode,
      variation_group_name_en = p_group_name_en,
      variation_group_name_ar = p_group_name_ar,
      variation_order = v_order,
      created_by = COALESCE(p_user_id, created_by),
      modified_by = p_user_id,
      modified_at = NOW()
    WHERE barcode = v_barcode;

--

--
-- Name: create_warning_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_warning_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Handle different trigger operations
    IF TG_OP = 'INSERT' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            new_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            NEW.id,
            'created',
            row_to_json(NEW),
            NEW.issued_by,
            NEW.issued_by_username,
            'Warning created'
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            old_values,
            new_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            NEW.id,
            'updated',
            row_to_json(OLD),
            row_to_json(NEW),
            NEW.issued_by,
            NEW.issued_by_username,
            'Warning updated'
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            old_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            OLD.id,
--

--
-- Name: current_user_is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_is_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN current_setting('app.is_master_admin', true)::BOOLEAN 
         OR current_setting('app.is_admin', true)::BOOLEAN;
EXCEPTION
  WHEN OTHERS THEN
    RETURN false;
END;
$$;


--
-- Name: daily_erp_sync_maintenance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.daily_erp_sync_maintenance() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    sync_result RECORD;
    result_text TEXT;
BEGIN
    -- Run the sync function
    SELECT * INTO sync_result FROM sync_all_missing_erp_references();
    
    result_text := format('Daily ERP sync maintenance completed: %s records synced', 
                         sync_result.synced_count);
    
    IF sync_result.synced_count > 0 THEN
        result_text := result_text || format('. Details: %s', sync_result.details);
    END IF;
    
    RETURN result_text;
END;
$$;


--
-- Name: deactivate_expired_media(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deactivate_expired_media() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE customer_app_media
    SET 
        is_active = false,
        deactivated_at = NOW(),
        updated_at = NOW()
    WHERE 
        is_active = true
        AND is_infinite = false
        AND expiry_date <= NOW();
END;
$$;


--
-- Name: FUNCTION deactivate_expired_media(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.deactivate_expired_media() IS 'Automatically deactivates media that has passed its expiry date';


--
-- Name: debug_get_dependency_photos(uuid, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.debug_get_dependency_photos(receiving_record_id_param uuid, dependency_role_types text[]) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  result_photos JSONB := '{}'::JSONB;
  role_type TEXT;
  task_record RECORD;
  found_count INTEGER := 0;
BEGIN
  RAISE NOTICE 'Debug: Starting function with receiving_record_id = %, roles = %', receiving_record_id_param, dependency_role_types;
  
  -- Loop through each dependency role type
  FOREACH role_type IN ARRAY dependency_role_types
  LOOP
    RAISE NOTICE 'Debug: Looking for role_type = %', role_type;
    
    -- Get the completion photo for this role type
    SELECT completion_photo_url, role_type as task_role_type INTO task_record
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = role_type
      AND task_completed = true
      AND completion_photo_url IS NOT NULL
    LIMIT 1;
    
    IF FOUND THEN
      found_count := found_count + 1;
      RAISE NOTICE 'Debug: Found task with photo for role %, URL = %', role_type, task_record.completion_photo_url;
      
      result_photos := result_photos || jsonb_build_object(
        task_record.task_role_type, task_record.completion_photo_url
      );
    ELSE
      RAISE NOTICE 'Debug: No photo found for role %', role_type;
    END IF;
  END LOOP;
  
  RAISE NOTICE 'Debug: Found % photos, returning %', found_count, result_photos;
  
  -- Convert JSONB to JSON for return
  RETURN result_photos::JSON;
  
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Debug: Error occurred - %', SQLERRM;
  RETURN '{}'::JSON;
END;
$$;


--
-- Name: debug_receiving_tasks_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.debug_receiving_tasks_data() RETURNS TABLE(total_receiving_tasks integer, total_task_completions integer, receiving_task_ids text, task_completion_task_ids text, matching_completed_tasks integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM receiving_tasks) as total_receiving_tasks,
        (SELECT COUNT(*)::INTEGER FROM task_completions) as total_task_completions,
        (SELECT string_agg(rt.task_id::TEXT, ', ') FROM receiving_tasks rt LIMIT 10) as receiving_task_ids,
        (SELECT string_agg(tc.task_id::TEXT, ', ') FROM task_completions tc WHERE tc.task_finished_completed = true LIMIT 10) as task_completion_task_ids,
        (SELECT COUNT(DISTINCT rt.id)::INTEGER 
         FROM receiving_tasks rt 
         WHERE EXISTS (
             SELECT 1 FROM task_completions tc 
             WHERE tc.task_id = rt.task_id 
             AND tc.task_finished_completed = true
         )) as matching_completed_tasks;
END;
$$;


--
-- Name: debug_users(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.debug_users() RETURNS TABLE(user_id uuid, username character varying, status character varying, employee_id uuid, branch_id bigint, position_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        u.username,
        u.status::VARCHAR,
        u.employee_id,
        u.branch_id,
        u.position_id
    FROM users u
    ORDER BY u.created_at DESC;
END;
$$;


--
-- Name: decrement_voucher_stock(numeric, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.decrement_voucher_stock(voucher_value numeric, decrement_amount integer DEFAULT 1) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE purchase_voucher_stock
    SET quantity = quantity - decrement_amount,
        updated_at = NOW()
    WHERE value = voucher_value
      AND quantity >= decrement_amount;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient stock for voucher value %', voucher_value;
    END IF;
END;
$$;


--
-- Name: delete_app_icon(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_app_icon(p_icon_key text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    DELETE FROM public.app_icons WHERE icon_key = p_icon_key;
    RETURN FOUND;
END;
$$;


--
-- Name: delete_branch_sync_config(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_branch_sync_config(p_id bigint) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    DELETE FROM branch_sync_config WHERE id = p_id;
$$;


--
-- Name: delete_customer_account(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_customer_account(p_customer_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_customer record;
BEGIN
    -- Check if customer exists
    SELECT id, name, is_deleted
    INTO v_customer
    FROM public.customers
    WHERE id = p_customer_id;
    
    IF v_customer.id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Customer not found'
        );
    END IF;
    
    IF v_customer.is_deleted = true THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Account already deleted'
        );
    END IF;
    
    -- Soft delete: mark as deleted, clear access code so it can be reused
    UPDATE public.customers
    SET is_deleted = true,
        deleted_at = now(),
        access_code = NULL,
        registration_status = 'suspended',
        updated_at = now()
    WHERE id = p_customer_id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Account deleted successfully'
    );
END;
$$;


--
-- Name: delete_hr_salary_note(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_hr_salary_note(p_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    DELETE FROM public.hr_salary_notes WHERE id = p_id;
    RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


--
-- Name: delete_incident_cascade(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_incident_cascade(p_incident_id text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_task_ids uuid[];
BEGIN
    -- Collect quick_task IDs linked to this incident
    SELECT ARRAY(SELECT id FROM quick_tasks WHERE incident_id = p_incident_id)
    INTO v_task_ids;

    -- Delete quick_task children
    IF array_length(v_task_ids, 1) > 0 THEN
        DELETE FROM quick_task_assignments WHERE quick_task_id = ANY(v_task_ids);
        DELETE FROM quick_task_comments    WHERE quick_task_id = ANY(v_task_ids);
        DELETE FROM quick_task_completions WHERE quick_task_id = ANY(v_task_ids);
        DELETE FROM quick_task_files       WHERE quick_task_id = ANY(v_task_ids);
    END IF;

    -- Delete quick_tasks
    DELETE FROM quick_tasks WHERE incident_id = p_incident_id;

    -- Delete incident_actions
    DELETE FROM incident_actions WHERE incident_id = p_incident_id;

    -- Delete the incident itself
    DELETE FROM incidents WHERE id = p_incident_id;
END;
$$;


--
-- Name: delete_loyalty_tier(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_loyalty_tier(p_id uuid) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  DELETE FROM loyalty_tiers WHERE id = p_id;
$$;


--
-- Name: denomination_audit_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.denomination_audit_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO denomination_audit_log (
            record_id, branch_id, user_id, action, record_type, box_number,
            old_counts, new_counts,
            old_erp_balance, new_erp_balance,
            old_grand_total, new_grand_total,
            old_difference, new_difference
        ) VALUES (
            NEW.id, NEW.branch_id, NEW.user_id, 'INSERT', NEW.record_type, NEW.box_number,
            NULL, NEW.counts,
            NULL, NEW.erp_balance,
            NULL, NEW.grand_total,
            NULL, NEW.difference
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO denomination_audit_log (
            record_id, branch_id, user_id, action, record_type, box_number,
            old_counts, new_counts,
            old_erp_balance, new_erp_balance,
            old_grand_total, new_grand_total,
            old_difference, new_difference
        ) VALUES (
            NEW.id, NEW.branch_id, NEW.user_id, 'UPDATE', NEW.record_type, NEW.box_number,
            OLD.counts, NEW.counts,
            OLD.erp_balance, NEW.erp_balance,
            OLD.grand_total, NEW.grand_total,
            OLD.difference, NEW.difference
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO denomination_audit_log (
            record_id, branch_id, user_id, action, record_type, box_number,
            old_counts, new_counts,
            old_erp_balance, new_erp_balance,
            old_grand_total, new_grand_total,
            old_difference, new_difference
        ) VALUES (
            OLD.id, OLD.branch_id, OLD.user_id, 'DELETE', OLD.record_type, OLD.box_number,
            OLD.counts, NULL,
            OLD.erp_balance, NULL,
            OLD.grand_total, NULL,
            OLD.difference, NULL
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
--

--
-- Name: duplicate_flyer_template(uuid, character varying, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.duplicate_flyer_template(template_id uuid, new_name character varying, user_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  new_template_id UUID;
  template_record RECORD;
BEGIN
  -- Get the original template
  SELECT * INTO template_record
  FROM flyer_templates
  WHERE id = template_id
    AND deleted_at IS NULL;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Template not found';
  END IF;
  
  -- Create duplicate
  INSERT INTO flyer_templates (
    name,
    description,
    first_page_image_url,
    sub_page_image_urls,
    first_page_configuration,
    sub_page_configurations,
    metadata,
    is_active,
    is_default,
    category,
    tags,
    created_by,
    updated_by
  ) VALUES (
    new_name,
    'Copy of: ' || COALESCE(template_record.description, template_record.name),
    template_record.first_page_image_url,
    template_record.sub_page_image_urls,
    template_record.first_page_configuration,
    template_record.sub_page_configurations,
    template_record.metadata,
    true,
    false, -- Duplicates are never default
    template_record.category,
    template_record.tags,
    user_id,
    user_id
  )
  RETURNING id INTO new_template_id;
  
  RETURN new_template_id;
END;
--

--
-- Name: end_break(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.end_break(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_break RECORD;
  v_duration INTEGER;
BEGIN
  SELECT id, start_time INTO v_break
  FROM break_register
  WHERE user_id = p_user_id AND status = 'open'
  LIMIT 1;

  IF v_break IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No open break found');
  END IF;

  v_duration := EXTRACT(EPOCH FROM (NOW() - v_break.start_time))::INTEGER;

  UPDATE break_register
  SET end_time = NOW(),
      duration_seconds = v_duration,
      status = 'closed'
  WHERE id = v_break.id;

  RETURN jsonb_build_object('success', true, 'break_id', v_break.id, 'duration_seconds', v_duration);
END;
$$;


--
-- Name: end_break(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.end_break(p_user_id uuid, p_security_code text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_break_id uuid;
    v_start_time timestamptz;
    v_duration integer;
BEGIN
    -- Validate security code (required)
    IF p_security_code IS NULL OR p_security_code = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Security code is required. Please scan the QR code.');
    END IF;
    
    IF NOT validate_break_code(p_security_code) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid or expired QR code. Please scan the current QR code displayed on the screen.');
    END IF;

    -- Find the open break
    SELECT id, start_time INTO v_break_id, v_start_time
    FROM break_register
    WHERE user_id = p_user_id AND status = 'open'
    ORDER BY start_time DESC
    LIMIT 1;

    IF v_break_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No open break found');
    END IF;

    -- Calculate duration
    v_duration := EXTRACT(EPOCH FROM (NOW() - v_start_time))::integer;

    -- Close the break
    UPDATE break_register
    SET end_time = NOW(),
        duration_seconds = v_duration,
        status = 'closed'
    WHERE id = v_break_id;

    RETURN jsonb_build_object('success', true, 'break_id', v_break_id, 'duration_seconds', v_duration);
END;
$$;


--
-- Name: ensure_single_default_flyer_template(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_single_default_flyer_template() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.is_default = true THEN
    -- Unset all other default templates
    UPDATE flyer_templates 
    SET is_default = false 
    WHERE id != NEW.id 
      AND is_default = true 
      AND deleted_at IS NULL;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: export_schema_ddl(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.export_schema_ddl() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
    v_functions text := '';
    v_triggers text := '';
    v_types text := '';
    v_policies text := '';
    v_grants text := '';
    v_tables text := '';
    v_indexes text := '';
    v_sequences text := '';
    v_columns text := '';
    r record;
BEGIN
    -- ΓòÉΓòÉΓòÉ SEQUENCES ΓòÉΓòÉΓòÉ
    -- Export all sequences in public schema (must come before tables that reference them)
    FOR r IN
        SELECT c.relname AS seq_name,
               s.seqtypid,
               pg_catalog.format_type(s.seqtypid, NULL) AS seq_type,
               s.seqstart, s.seqincrement, s.seqmin, s.seqmax, s.seqcache, s.seqcycle
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        JOIN pg_sequence s ON s.seqrelid = c.oid
        WHERE n.nspname = 'public'
          AND c.relkind = 'S' -- sequences
        ORDER BY c.relname
    LOOP
        v_sequences := v_sequences || format(
            'CREATE SEQUENCE IF NOT EXISTS public.%I AS %s INCREMENT BY %s MINVALUE %s MAXVALUE %s START WITH %s CACHE %s%s;',
            r.seq_name, r.seq_type, r.seqincrement, r.seqmin, r.seqmax, r.seqstart, r.seqcache,
            CASE WHEN r.seqcycle THEN ' CYCLE' ELSE '' END
        ) || E'\n';
        v_sequences := v_sequences || format(
            'GRANT USAGE, SELECT ON SEQUENCE public.%I TO authenticated, anon, service_role;',
            r.seq_name
        ) || E'\n';
    END LOOP;

    -- ΓòÉΓòÉΓòÉ FUNCTIONS ΓòÉΓòÉΓòÉ
    -- Export all user-defined functions in public schema
    -- Use DROP + CREATE to handle return type changes (CREATE OR REPLACE can't change return type)
    FOR r IN
        SELECT p.oid, p.proname,
               pg_get_functiondef(p.oid) AS funcdef,
               pg_get_function_identity_arguments(p.oid) AS identity_args,
               p.prokind
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
--

--
-- Name: export_table_for_sync(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.export_table_for_sync(p_table_name text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_result jsonb;
    v_allowed_tables text[] := ARRAY[
        'branches', 'users', 'user_sessions', 'user_device_sessions',
        'button_permissions', 'sidebar_buttons', 'button_main_sections', 'button_sub_sections',
        'interface_permissions', 'user_favorite_buttons',
        'erp_synced_products', 'product_categories', 'products', 'product_units',
        'offers', 'offer_products', 'offer_names', 'offer_bundles', 'offer_cart_tiers',
        'bogo_offer_rules', 'flyer_offers', 'flyer_offer_products',
        'customers', 'privilege_cards_master', 'privilege_cards_branch',
        'desktop_themes', 'user_theme_assignments',
        'erp_connections', 'erp_sync_logs',
        'coupon_campaigns', 'coupon_products', 'coupon_eligible_customers',
        'delivery_fee_tiers', 'delivery_service_settings',
        'social_links', 'ai_chat_guide',
        'nationalities', 'vendors',
        'expense_parent_categories', 'expense_sub_categories',
        'notification_attachments', 'notifications', 'notification_recipients',
        'push_subscriptions'
    ];
BEGIN
    -- Security: Only allow whitelisted tables
    IF NOT (p_table_name = ANY(v_allowed_tables)) THEN
        RAISE EXCEPTION 'Table % is not allowed for sync', p_table_name;
    END IF;

    EXECUTE format('SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), ''[]''::jsonb) FROM %I t', p_table_name)
    INTO v_result;

    RETURN v_result;
END;
$$;


--
-- Name: format_file_size(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.format_file_size(size_bytes bigint) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    size_kb numeric := size_bytes / 1024.0;
    size_mb numeric := size_kb / 1024.0;
    size_gb numeric := size_mb / 1024.0;
BEGIN
    IF size_gb >= 1 THEN
        RETURN round(size_gb, 2) || ' GB';
    ELSIF size_mb >= 1 THEN
        RETURN round(size_mb, 2) || ' MB';
    ELSIF size_kb >= 1 THEN
        RETURN round(size_kb, 2) || ' KB';
    ELSE
        RETURN size_bytes || ' Bytes';
    END IF;
END;
$$;


--
-- Name: generate_branch_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_branch_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    prefix VARCHAR(2);
    next_num INTEGER;
BEGIN
    -- Always generate branch_id if not provided or empty
    IF NEW.branch_id IS NULL OR NEW.branch_id = '' THEN
        -- Determine prefix based on branch type
        prefix := CASE 
            WHEN NEW.branch_type = 'head_branch' THEN 'HB'
            ELSE 'BR'
        END;
        
        -- Get next number for this branch type by finding the highest existing number
        SELECT COALESCE(MAX(
            CASE 
                WHEN branch_id ~ ('^' || prefix || '[0-9]+$') 
                THEN CAST(SUBSTRING(branch_id FROM LENGTH(prefix) + 1) AS INTEGER)
                ELSE 0
            END
        ), 0) + 1
        INTO next_num
        FROM branches 
        WHERE branch_id LIKE prefix || '%';
        
        -- Generate new branch_id with zero-padded number
        NEW.branch_id := prefix || LPAD(next_num::TEXT, 3, '0');
    END IF;
    
    RETURN NEW;
END;
$_$;


--
-- Name: generate_campaign_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_campaign_code() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_code VARCHAR(8);
  code_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate 8 character alphanumeric code
    new_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));
    
    -- Check if code already exists
    SELECT EXISTS(SELECT 1 FROM coupon_campaigns WHERE campaign_code = new_code)
    INTO code_exists;
    
    EXIT WHEN NOT code_exists;
  END LOOP;
  
  RETURN new_code;
END;
$$;


--
-- Name: generate_clearance_certificate_tasks(uuid, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_clearance_certificate_tasks(receiving_record_id_param uuid, clearance_certificate_url_param text, created_by_user_id text, created_by_name text DEFAULT NULL::text, created_by_role text DEFAULT NULL::text) RETURNS TABLE(task_count integer, notification_count integer, task_ids uuid[], assignment_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    receiving_record RECORD;
    vendor_record RECORD;
    task_id UUID;
    assignment_id UUID;
    notification_id UUID;
    deadline_datetime TIMESTAMPTZ;
    task_description TEXT;
    user_id UUID;
    total_tasks INTEGER := 0;
    total_notifications INTEGER := 0;
    created_task_ids UUID[] := '{}';
    created_assignment_ids UUID[] := '{}';
BEGIN
    deadline_datetime := now() + INTERVAL '24 hours';
    
    -- Get receiving record details
    SELECT * INTO receiving_record 
    FROM receiving_records 
    WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    -- Get vendor details for description
    SELECT vendor_name INTO vendor_record 
    FROM vendors 
    WHERE erp_vendor_id = receiving_record.vendor_id;
    
    task_description := format('Vendor: %s, Bill #: %s, Bill Amount: %s, Bill Date: %s, Received by: %s',
        COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
        COALESCE(receiving_record.bill_number, 'N/A'),
        COALESCE(receiving_record.bill_amount::TEXT, 'N/A'),
        receiving_record.bill_date::TEXT,
        COALESCE(created_by_name, 'Unknown User')
    );
    
    -- 1. Branch Manager Task
    IF receiving_record.branch_manager_user_id IS NOT NULL THEN
        task_id := create_task(
            'New delivery arrivedΓÇöstart placing.',
            task_description,
            created_by_user_id,
            COALESCE(created_by_name, ''),
            COALESCE(created_by_role, ''),
            'high',
            deadline_datetime::DATE,
--

--
-- Name: generate_insurance_company_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_insurance_company_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  max_id INTEGER;
  new_id VARCHAR(15);
BEGIN
  -- Extract the numeric part from the last ID and increment it
  SELECT COALESCE(MAX(CAST(SUBSTRING(id, 4) AS INTEGER)), 0) + 1
  INTO max_id
  FROM hr_insurance_companies
  WHERE id LIKE 'INC%';
  
  -- Format as INC001, INC002, etc.
  new_id := 'INC' || LPAD(max_id::TEXT, 3, '0');
  NEW.id := new_id;
  
  RETURN NEW;
END;
$$;


--
-- Name: generate_new_customer_access_code(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_new_customer_access_code(p_customer_id uuid, p_admin_user_id uuid, p_notes text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
    v_new_access_code text;
    v_hashed_new_code text;
    v_customer_name text;
    v_whatsapp_number text;
    v_old_hashed_code text;
    v_admin_name text;
    v_current_time timestamp with time zone := now();
    result json;
BEGIN
    SELECT username INTO v_admin_name
    FROM public.users WHERE id = p_admin_user_id AND status = 'active';
    
    IF v_admin_name IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invalid admin user');
    END IF;
    
    SELECT c.access_code, c.whatsapp_number, c.name
    INTO v_old_hashed_code, v_whatsapp_number, v_customer_name
    FROM public.customers c WHERE c.id = p_customer_id;
    
    IF v_customer_name IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Customer not found');
    END IF;
    
    v_new_access_code := generate_unique_customer_access_code();
    v_hashed_new_code := encode(digest(v_new_access_code::bytea, 'sha256'), 'hex');
    
    IF v_new_access_code IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Failed to generate unique access code');
    END IF;
    
    UPDATE public.customers
    SET access_code = v_hashed_new_code,
        access_code_generated_at = v_current_time,
        updated_at = v_current_time
    WHERE id = p_customer_id;

    INSERT INTO public.customer_access_code_history (
        customer_id, old_access_code, new_access_code,
        generated_by, reason, notes
    ) VALUES (
        p_customer_id, v_old_hashed_code, v_hashed_new_code,
        p_admin_user_id, 'admin_regeneration', COALESCE(p_notes, 'Regenerated by admin')
    );
    
    INSERT INTO public.notifications (title, message, type, priority, metadata, deleted_at)
--

--
-- Name: generate_order_number(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_order_number() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_order_number VARCHAR(50);
    counter INTEGER;
BEGIN
    -- Format: ORD-YYYYMMDD-XXXX
    SELECT COUNT(*) + 1 INTO counter
    FROM orders
    WHERE DATE(created_at) = CURRENT_DATE;
    
    new_order_number := 'ORD-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(counter::TEXT, 4, '0');
    
    RETURN new_order_number;
END;
$$;


--
-- Name: FUNCTION generate_order_number(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.generate_order_number() IS 'Generates unique order number in format ORD-YYYYMMDD-XXXX';


--
-- Name: generate_recurring_occurrences(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_recurring_occurrences(p_parent_id integer, p_source_table text) RETURNS TABLE(occurrence_count integer, message text)
    LANGUAGE plpgsql
    AS $$
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
--

--
-- Name: generate_salt(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_salt() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN gen_salt('bf', 8);
END;
$$;


--
-- Name: generate_unique_customer_access_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_unique_customer_access_code() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_access_code text;
    code_exists boolean;
    attempts integer := 0;
    max_attempts integer := 100;
BEGIN
    LOOP
        v_access_code := LPAD(FLOOR(random() * 1000000)::text, 6, '0');
        SELECT EXISTS(
            SELECT 1 FROM public.customers c
            WHERE c.access_code = encode(extensions.digest(v_access_code::bytea, 'sha256'), 'hex')
        ) INTO code_exists;
        IF NOT code_exists THEN
            RETURN v_access_code;
        END IF;
        attempts := attempts + 1;
        IF attempts >= max_attempts THEN
            RAISE EXCEPTION 'Unable to generate unique access code after % attempts', max_attempts;
        END IF;
    END LOOP;
END;
$$;


--
-- Name: generate_unique_quick_access_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_unique_quick_access_code() RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_code VARCHAR(6);
BEGIN
  LOOP
    v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM users
      WHERE extensions.crypt(v_code, quick_access_code) = quick_access_code
    );
  END LOOP;
  RETURN v_code;
END;
$$;


--
-- Name: generate_warning_reference(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_warning_reference() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.warning_reference IS NULL OR NEW.warning_reference = '' THEN
        NEW.warning_reference = 'WRN-' || TO_CHAR(NEW.created_at, 'YYYYMMDD') || '-' || LPAD(nextval('warning_ref_seq')::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: get_active_break(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_active_break(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_break RECORD;
  v_reason RECORD;
BEGIN
  SELECT br.*, br.reason_id as rid
  INTO v_break
  FROM break_register br
  WHERE br.user_id = p_user_id AND br.status = 'open'
  LIMIT 1;

  IF v_break IS NULL THEN
    RETURN jsonb_build_object('active', false);
  END IF;

  SELECT name_en, name_ar INTO v_reason
  FROM break_reasons WHERE id = v_break.rid;

  RETURN jsonb_build_object(
    'active', true,
    'break_id', v_break.id,
    'start_time', v_break.start_time,
    'reason_en', v_reason.name_en,
    'reason_ar', v_reason.name_ar,
    'reason_note', v_break.reason_note
  );
END;
$$;


--
-- Name: get_active_customer_media(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_active_customer_media() RETURNS TABLE(id uuid, media_type character varying, slot_number integer, title_en character varying, title_ar character varying, file_url text, duration integer, display_order integer)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cam.id,
        cam.media_type,
        cam.slot_number,
        cam.title_en,
        cam.title_ar,
        cam.file_url,
        cam.duration,
        cam.display_order
    FROM customer_app_media cam
    WHERE cam.is_active = true
      AND (
          cam.is_infinite = true 
          OR cam.expiry_date > NOW()
      )
    ORDER BY cam.display_order ASC, cam.created_at DESC;
END;
$$;


--
-- Name: FUNCTION get_active_customer_media(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_active_customer_media() IS 'Returns all active non-expired media for customer home page display';


--
-- Name: get_active_employees_by_branch(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_active_employees_by_branch(branch_uuid uuid) RETURNS TABLE(id uuid, employee_id character varying, first_name character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.employee_id,
        e.first_name
    FROM employees e
    WHERE e.branch_id = branch_uuid 
    AND e.status = 'active'
    ORDER BY e.first_name;
END;
$$;


--
-- Name: get_active_flyer_templates(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_active_flyer_templates() RETURNS TABLE(id uuid, name character varying, description text, first_page_image_url text, sub_page_image_urls text[], first_page_configuration jsonb, sub_page_configurations jsonb, metadata jsonb, is_default boolean, category character varying, tags text[], usage_count integer, last_used_at timestamp with time zone, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.name,
    t.description,
    t.first_page_image_url,
    t.sub_page_image_urls,
    t.first_page_configuration,
    t.sub_page_configurations,
    t.metadata,
    t.is_default,
    t.category,
    t.tags,
    t.usage_count,
    t.last_used_at,
    t.created_at
  FROM flyer_templates t
  WHERE t.is_active = true 
    AND t.deleted_at IS NULL
  ORDER BY 
    t.is_default DESC,
    t.usage_count DESC,
    t.created_at DESC;
END;
$$;


--
-- Name: get_active_offers_for_customer(uuid, integer, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_active_offers_for_customer(p_customer_id uuid, p_branch_id integer DEFAULT NULL::integer, p_service_type character varying DEFAULT 'both'::character varying) RETURNS TABLE(offer_id integer, offer_type character varying, name_ar character varying, name_en character varying, discount_type character varying, discount_value numeric, start_date timestamp with time zone, end_date timestamp with time zone, service_type character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.type,
        o.name_ar,
        o.name_en,
        o.discount_type,
        o.discount_value,
        o.start_date,
        o.end_date,
        o.service_type
    FROM offers o
    WHERE o.is_active = true
        AND NOW() BETWEEN o.start_date AND o.end_date
        AND (o.branch_id IS NULL OR o.branch_id = p_branch_id)
        AND (o.service_type = 'both' OR o.service_type = p_service_type)
        AND (
            -- General offers (not customer-specific)
            o.type != 'customer'
            OR
            -- Customer-specific offers assigned to this customer
            EXISTS (
                SELECT 1 FROM customer_offers co
                WHERE co.offer_id = o.id
                    AND co.customer_id = p_customer_id
                    AND co.is_used = false
            )
        )
        AND (
            -- Check max total uses not exceeded
            o.max_total_uses IS NULL OR o.current_total_uses < o.max_total_uses
        )
    ORDER BY o.priority DESC, o.created_at DESC;
END;
$$;


--
-- Name: get_all_branches_delivery_settings(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_branches_delivery_settings() RETURNS TABLE(branch_id bigint, branch_name_en text, branch_name_ar text, minimum_order_amount numeric, delivery_service_enabled boolean, delivery_is_24_hours boolean, delivery_start_time time without time zone, delivery_end_time time without time zone, pickup_service_enabled boolean, pickup_is_24_hours boolean, pickup_start_time time without time zone, pickup_end_time time without time zone, delivery_message_ar text, delivery_message_en text, location_url text, latitude double precision, longitude double precision)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id,
        b.name_en::text,
        b.name_ar::text,
        COALESCE(b.minimum_order_amount, 15.00)::numeric,
        COALESCE(b.delivery_service_enabled, true)::boolean,
        COALESCE(b.delivery_is_24_hours, true)::boolean,
        b.delivery_start_time,
        b.delivery_end_time,
        COALESCE(b.pickup_service_enabled, true)::boolean,
        COALESCE(b.pickup_is_24_hours, true)::boolean,
        b.pickup_start_time,
        b.pickup_end_time,
        COALESCE(b.delivery_message_ar, '╪º┘ä╪¬┘ê╪╡┘è┘ä ┘à╪¬╪º╪¡ ╪╣┘ä┘ë ┘à╪»╪º╪▒ ╪º┘ä╪│╪º╪╣╪⌐')::text,
        COALESCE(b.delivery_message_en, 'Delivery available 24/7')::text,
        b.location_url,
        b.latitude,
        b.longitude
    FROM public.branches b
    ORDER BY b.name_en;
END;
$$;


--
-- Name: get_all_breaks(date, date, integer, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_breaks(p_date_from date DEFAULT NULL::date, p_date_to date DEFAULT NULL::date, p_branch_id integer DEFAULT NULL::integer, p_status character varying DEFAULT NULL::character varying) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.start_time DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      br.id,
      br.employee_id,
      br.employee_name_en,
      br.employee_name_ar,
      br.branch_id,
      b.name_en as branch_name_en,
      b.name_ar as branch_name_ar,
      r.name_en as reason_en,
      r.name_ar as reason_ar,
      br.reason_note,
      br.start_time,
      br.end_time,
      br.duration_seconds,
      br.status
    FROM break_register br
    JOIN break_reasons r ON r.id = br.reason_id
    LEFT JOIN branches b ON b.id = br.branch_id
    WHERE (p_date_from IS NULL OR br.start_time::DATE >= p_date_from)
      AND (p_date_to IS NULL OR br.start_time::DATE <= p_date_to)
      AND (p_branch_id IS NULL OR br.branch_id = p_branch_id)
      AND (p_status IS NULL OR br.status = p_status)
    ORDER BY br.start_time DESC
    LIMIT 500
  ) t;

  RETURN jsonb_build_object('breaks', v_result);
END;
$$;


--
-- Name: get_all_customer_total_points(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_customer_total_points() RETURNS TABLE(customer_id uuid, total_points numeric)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    lcb.customer_id,
    COALESCE(SUM(lcb.points_earned), 0) AS total_points
  FROM loyalty_customer_bills lcb
  WHERE lcb.customer_id IS NOT NULL
  GROUP BY lcb.customer_id;
$$;


--
-- Name: get_all_delivery_tiers(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_delivery_tiers() RETURNS TABLE(id uuid, min_order_amount numeric, max_order_amount numeric, delivery_fee numeric, tier_order integer, is_active boolean, description_en text, description_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.min_order_amount,
        t.max_order_amount,
        t.delivery_fee,
        t.tier_order,
        t.is_active,
        t.description_en,
        t.description_ar
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
    ORDER BY t.tier_order ASC;
END;
$$;


--
-- Name: FUNCTION get_all_delivery_tiers(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_all_delivery_tiers() IS 'Get all active delivery fee tiers ordered for display';


--
-- Name: get_all_expiry_products(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_expiry_products() RETURNS TABLE(branch_id integer, barcode character varying, product_name_en character varying, product_name_ar character varying, expiry_date date, days_left integer, managed_by jsonb)
    LANGUAGE sql STABLE
    AS $$
  SELECT
    (entry->>'branch_id')::integer AS branch_id,
    p.barcode,
    p.product_name_en,
    p.product_name_ar,
    (entry->>'expiry_date')::date AS expiry_date,
    ((entry->>'expiry_date')::date - CURRENT_DATE) AS days_left,
    p.managed_by
  FROM erp_synced_products p,
    jsonb_array_elements(p.expiry_dates) AS entry
  WHERE jsonb_array_length(p.expiry_dates) > 0
    AND (p.expiry_hidden IS NOT TRUE)
    AND (entry->>'expiry_date') IS NOT NULL
    AND (entry->>'branch_id') IS NOT NULL
  ORDER BY ((entry->>'expiry_date')::date - CURRENT_DATE) ASC, p.barcode;
$$;


--
-- Name: get_all_expiry_products(integer, integer, text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_expiry_products(p_page integer DEFAULT 1, p_page_size integer DEFAULT 1000, p_search_barcode text DEFAULT NULL::text, p_search_name text DEFAULT NULL::text, p_branch_id integer DEFAULT NULL::integer) RETURNS TABLE(branch_id integer, barcode character varying, product_name_en character varying, product_name_ar character varying, expiry_date date, days_left integer, managed_by jsonb, total_count bigint)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_offset integer;
  v_limit integer;
BEGIN
  v_offset := CASE WHEN (p_search_barcode IS NOT NULL OR p_search_name IS NOT NULL) THEN 0 ELSE (p_page - 1) * p_page_size END;
  v_limit := CASE WHEN (p_search_barcode IS NOT NULL OR p_search_name IS NOT NULL) THEN NULL ELSE p_page_size END;

  RETURN QUERY
  SELECT
    (entry->>'branch_id')::integer AS branch_id,
    p.barcode,
    p.product_name_en,
    p.product_name_ar,
    (entry->>'expiry_date')::date AS expiry_date,
    ((entry->>'expiry_date')::date - CURRENT_DATE)::integer AS days_left,
    p.managed_by,
    count(*) OVER() AS total_count
  FROM erp_synced_products p,
    jsonb_array_elements(p.expiry_dates) AS entry
  WHERE p.expiry_hidden IS NOT TRUE
    AND jsonb_array_length(p.expiry_dates) > 0
    AND (entry->>'expiry_date') IS NOT NULL
    AND (entry->>'branch_id') IS NOT NULL
    AND (p_branch_id IS NULL OR (entry->>'branch_id')::integer = p_branch_id)
    AND (p_search_barcode IS NULL OR p.barcode ILIKE '%' || p_search_barcode || '%')
    AND (p_search_name IS NULL OR p.product_name_en ILIKE '%' || p_search_name || '%' OR p.product_name_ar ILIKE '%' || p_search_name || '%')
  ORDER BY ((entry->>'expiry_date')::date - CURRENT_DATE) ASC, p.barcode
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;


--
-- Name: get_all_products_master(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_products_master() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'barcode', p.barcode,
      'product_name_en', p.product_name_en,
      'product_name_ar', p.product_name_ar,
      'image_url', p.image_url,
      'unit_name', COALESCE(u.name_en, ''),
      'unit_name_ar', COALESCE(u.name_ar, ''),
      'parent_category', COALESCE(c.name_en, ''),
      'parent_category_ar', COALESCE(c.name_ar, '')
    )
    ORDER BY (CASE WHEN p.image_url IS NOT NULL AND p.image_url <> '' THEN 0 ELSE 1 END), p.product_name_en
  ), '[]'::jsonb) INTO v_result
  FROM products p
  LEFT JOIN product_units u ON p.unit_id = u.id
  LEFT JOIN product_categories c ON p.category_id = c.id;
  
  RETURN v_result;
END;
$$;


--
-- Name: get_all_receiving_tasks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_receiving_tasks() RETURNS TABLE(id uuid, receiving_record_id uuid, template_id uuid, role_type character varying, title text, description text, priority character varying, task_status character varying, task_completed boolean, due_date timestamp with time zone, assigned_user_id uuid, completed_at timestamp with time zone, completed_by_user_id uuid, clearance_certificate_url text, created_at timestamp with time zone, bill_number character varying, bill_amount numeric, vendor_name text, branch_name text, assigned_user_name text, completed_by_user_name text, is_overdue boolean, days_until_due integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rt.id,
    rt.receiving_record_id,
    rt.template_id,
    rt.role_type,
    rt.title,
    rt.description,
    rt.priority,
    rt.task_status,
    rt.task_completed,
    rt.due_date,
    rt.assigned_user_id,
    rt.completed_at,
    rt.completed_by_user_id,
    rt.clearance_certificate_url,
    rt.created_at,
    -- Receiving record details
    rr.bill_number,
    rr.bill_amount,
    v.vendor_name,
    b.name_en as branch_name,
    -- User details
    u1.username as assigned_user_name,
    u2.username as completed_by_user_name,
    -- Calculated fields
    (rt.due_date < NOW() AND rt.task_status != 'completed') as is_overdue,
    EXTRACT(DAY FROM (rt.due_date - NOW()))::INTEGER as days_until_due
  FROM receiving_tasks rt
  LEFT JOIN receiving_records rr ON rr.id = rt.receiving_record_id
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  LEFT JOIN users u1 ON u1.id = rt.assigned_user_id
  LEFT JOIN users u2 ON u2.id = rt.completed_by_user_id
  ORDER BY rt.created_at DESC, rt.priority DESC;
END;
$$;


--
-- Name: get_all_users(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_all_users() RETURNS TABLE(id uuid, username character varying, email character varying, role_type character varying, status character varying, employee_id uuid, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.email,
        -- Use admin flags instead of role_type column
        CASE 
            WHEN u.is_master_admin THEN 'Master Admin'::VARCHAR
            WHEN u.is_admin THEN 'Admin'::VARCHAR
            ELSE 'User'::VARCHAR
        END as role_type,
        'active'::VARCHAR as status,
        u.employee_id,
        u.created_at,
        u.updated_at
    FROM users u
    WHERE u.deleted_at IS NULL
    ORDER BY u.created_at DESC;
END;
$$;


--
-- Name: get_analytics_log_tables(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_analytics_log_tables() RETURNS TABLE(table_name text, total_size text, raw_size bigint, row_estimate bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.tablename AS table_name,
    r.total_size,
    r.raw_size,
    r.row_estimate
  FROM dblink(
    'dbname=_supabase user=supabase_admin',
    'SELECT
      t.tablename::text,
      pg_size_pretty(pg_total_relation_size(quote_ident(t.schemaname) || ''.'' || quote_ident(t.tablename)))::text AS total_size,
      pg_total_relation_size(quote_ident(t.schemaname) || ''.'' || quote_ident(t.tablename)) AS raw_size,
      COALESCE(c.reltuples, 0)::bigint AS row_estimate
    FROM pg_tables t
    LEFT JOIN pg_class c ON c.relname = t.tablename AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = t.schemaname)
    WHERE t.schemaname = ''_analytics'' AND t.tablename LIKE ''log_events_%''
    ORDER BY pg_total_relation_size(quote_ident(t.schemaname) || ''.'' || quote_ident(t.tablename)) DESC'
  ) AS r(tablename text, total_size text, raw_size bigint, row_estimate bigint);
END;
$$;


--
-- Name: get_app_icons(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_app_icons() RETURNS TABLE(id uuid, name text, icon_key text, category text, storage_path text, mime_type text, file_size bigint, description text, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT id, name, icon_key, category, storage_path, mime_type, file_size, description, is_active, created_at, updated_at
    FROM public.app_icons
    ORDER BY category, name;
$$;


--
-- Name: get_applicability_nationalities(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_applicability_nationalities() RETURNS TABLE(id text, name_en text, name_ar text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT
        n.id::text,
        n.name_en::text,
        n.name_ar::text
    FROM public.nationalities n
    ORDER BY
        CASE
            WHEN LOWER(COALESCE(n.name_en, '')) = 'saudi arabia'
                OR COALESCE(n.name_ar, '') LIKE '%╪º┘ä╪│╪╣┘ê╪»%'
            THEN 0
            ELSE 1
        END,
        LOWER(COALESCE(n.name_en, '')),
        n.id;
$$;


--
-- Name: get_approval_center_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_approval_center_data(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_permissions JSONB;
  v_can_approve_vendor_payments BOOLEAN := FALSE;
  v_can_approve_leave_requests BOOLEAN := FALSE;
  v_can_approve_purchase_vouchers BOOLEAN := FALSE;
  v_visibility_type VARCHAR;
  v_vendor_payment_amount_limit NUMERIC := 0;
  v_two_days_date DATE;
  v_result JSONB;
  v_requisitions JSONB;
  v_payment_schedules JSONB;
  v_vendor_payments JSONB;
  v_purchase_vouchers JSONB;
  v_my_requisitions JSONB;
  v_my_schedules JSONB;
  v_my_vouchers JSONB;
  v_day_off_requests JSONB;
  v_my_day_off_requests JSONB;
  v_user_names JSONB;
  v_employee_names JSONB;
  v_current_user_employee JSONB;
BEGIN
  -- 1) Get approval permissions
  SELECT jsonb_build_object(
    'id', ap.id,
    'user_id', ap.user_id,
    'can_approve_requisitions', ap.can_approve_requisitions,
    'requisition_amount_limit', ap.requisition_amount_limit,
    'can_approve_single_bill', ap.can_approve_single_bill,
    'single_bill_amount_limit', ap.single_bill_amount_limit,
    'can_approve_multiple_bill', ap.can_approve_multiple_bill,
    'multiple_bill_amount_limit', ap.multiple_bill_amount_limit,
    'can_approve_recurring_bill', ap.can_approve_recurring_bill,
    'recurring_bill_amount_limit', ap.recurring_bill_amount_limit,
    'can_approve_vendor_payments', ap.can_approve_vendor_payments,
    'vendor_payment_amount_limit', ap.vendor_payment_amount_limit,
    'can_approve_leave_requests', ap.can_approve_leave_requests,
    'can_approve_purchase_vouchers', ap.can_approve_purchase_vouchers,
    'can_add_missing_punches', ap.can_add_missing_punches,
    'is_active', ap.is_active
  ) INTO v_permissions
  FROM approval_permissions ap
  WHERE ap.user_id = p_user_id AND ap.is_active = TRUE
  LIMIT 1;

  -- Extract permission flags
  IF v_permissions IS NOT NULL THEN
    v_can_approve_vendor_payments := COALESCE((v_permissions->>'can_approve_vendor_payments')::BOOLEAN, FALSE);
--

--
-- Name: get_assignments_with_deadlines(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_assignments_with_deadlines(user_id uuid DEFAULT NULL::uuid, days_ahead integer DEFAULT 7) RETURNS TABLE(id uuid, task_id uuid, task_title character varying, assigned_to uuid, assignee_name character varying, due_date date, priority character varying, status character varying, days_until_due integer)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id,
        t.id as task_id,
        t.title as task_title,
        ta.assigned_to,
        u.username as assignee_name,
        t.due_date,
        ta.priority,
        ta.status,
        (t.due_date - CURRENT_DATE)::INTEGER as days_until_due
    FROM task_assignments ta
    JOIN tasks t ON ta.task_id = t.id
    LEFT JOIN users u ON ta.assigned_to = u.id
    WHERE (user_id IS NULL OR ta.assigned_to = user_id)
      AND t.due_date IS NOT NULL
      AND t.due_date <= CURRENT_DATE + INTERVAL '1 day' * days_ahead
      AND ta.status != 'completed'
      AND t.deleted_at IS NULL
    ORDER BY t.due_date ASC;
END;
$$;


--
-- Name: get_assignments_with_deadlines(text, uuid, boolean, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_assignments_with_deadlines(p_user_id text DEFAULT NULL::text, p_branch_id uuid DEFAULT NULL::uuid, p_include_overdue boolean DEFAULT true, p_days_ahead integer DEFAULT 7) RETURNS TABLE(assignment_id uuid, task_id uuid, task_title text, task_description text, task_priority text, assignment_status text, assigned_to_user_id text, assigned_to_branch_id uuid, deadline_datetime timestamp with time zone, schedule_date date, schedule_time time without time zone, is_overdue boolean, hours_until_deadline numeric, is_reassignable boolean, notes text, require_task_finished boolean, require_photo_upload boolean, require_erp_reference boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id as assignment_id,
        t.id as task_id,
        t.title as task_title,
        t.description as task_description,
        COALESCE(ta.priority_override, t.priority) as task_priority,
        ta.status as assignment_status,
        ta.assigned_to_user_id,
        ta.assigned_to_branch_id,
        ta.deadline_datetime,
        ta.schedule_date,
        ta.schedule_time,
        CASE 
            WHEN ta.deadline_datetime IS NOT NULL AND ta.deadline_datetime < now() 
                AND ta.status NOT IN ('completed', 'cancelled') 
            THEN true 
            ELSE false 
        END as is_overdue,
        CASE 
            WHEN ta.deadline_datetime IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (ta.deadline_datetime - now()))/3600 
            ELSE NULL 
        END as hours_until_deadline,
        ta.is_reassignable,
        ta.notes,
        ta.require_task_finished,
        ta.require_photo_upload,
        ta.require_erp_reference
    FROM public.task_assignments ta
    JOIN public.tasks t ON ta.task_id = t.id
    WHERE 
        (p_user_id IS NULL OR ta.assigned_to_user_id = p_user_id) AND
        (p_branch_id IS NULL OR ta.assigned_to_branch_id = p_branch_id) AND
        ta.status NOT IN ('cancelled', 'reassigned') AND
        (
            p_include_overdue = true OR 
            ta.deadline_datetime IS NULL OR 
            ta.deadline_datetime >= now()
        ) AND
        (
            ta.deadline_datetime IS NULL OR 
            ta.deadline_datetime <= now() + (p_days_ahead || ' days')::interval
        )
    ORDER BY 
        CASE WHEN ta.deadline_datetime IS NOT NULL AND ta.deadline_datetime < now() THEN 1 ELSE 2 END,
        ta.deadline_datetime ASC NULLS LAST,
--

--
-- Name: get_branch_delivery_settings(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_branch_delivery_settings(p_branch_id bigint) RETURNS TABLE(branch_id bigint, branch_name_en text, branch_name_ar text, minimum_order_amount numeric, delivery_service_enabled boolean, delivery_is_24_hours boolean, delivery_start_time time without time zone, delivery_end_time time without time zone, pickup_service_enabled boolean, pickup_is_24_hours boolean, pickup_start_time time without time zone, pickup_end_time time without time zone, delivery_message_ar text, delivery_message_en text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.name_en::text,
        b.name_ar::text,
        COALESCE(b.minimum_order_amount, 15.00)::numeric,
        COALESCE(b.delivery_service_enabled, true)::boolean,
        COALESCE(b.delivery_is_24_hours, true)::boolean,
        b.delivery_start_time,
        b.delivery_end_time,
        COALESCE(b.pickup_service_enabled, true)::boolean,
        COALESCE(b.pickup_is_24_hours, true)::boolean,
        b.pickup_start_time,
        b.pickup_end_time,
        COALESCE(b.delivery_message_ar, '╪º┘ä╪¬┘ê╪╡┘è┘ä ┘à╪¬╪º╪¡ ╪╣┘ä┘ë ┘à╪»╪º╪▒ ╪º┘ä╪│╪º╪╣╪⌐')::text,
        COALESCE(b.delivery_message_en, 'Delivery available 24/7')::text
    FROM public.branches b
    WHERE b.id = p_branch_id
    LIMIT 1;
END;
$$;


--
-- Name: FUNCTION get_branch_delivery_settings(p_branch_id bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_branch_delivery_settings(p_branch_id bigint) IS 'Get delivery settings for a specific branch with separate timings for delivery and pickup';


--
-- Name: get_branch_performance_dashboard(integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_branch_performance_dashboard(p_days_back integer DEFAULT 30, p_specific_date date DEFAULT NULL::date) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_from timestamp;
  v_to timestamp;
  v_branch_stats json;
  v_task_type_stats json;
  v_daily_stats json;
  v_top_employees json;
  v_assigned_by_stats json;
  v_checklist_stats json;
  v_totals json;
BEGIN
  IF p_specific_date IS NOT NULL THEN
    v_from := p_specific_date::timestamp;
    v_to := (p_specific_date + 1)::timestamp;
  ELSE
    v_from := NOW() - (p_days_back || ' days')::interval;
    v_to := NOW();
  END IF;

  -- 1. Overall totals
  SELECT json_build_object(
    'total_tasks', COALESCE(SUM(total), 0),
    'completed_tasks', COALESCE(SUM(completed), 0),
    'pending_tasks', COALESCE(SUM(pending), 0),
    'overdue_tasks', COALESCE(SUM(overdue), 0),
    'avg_completion_hours', ROUND(COALESCE(AVG(NULLIF(avg_hrs, 0)), 0)::numeric, 1),
    'total_checklists', COALESCE((SELECT COUNT(*) FROM hr_checklist_operations WHERE created_at >= v_from AND created_at < v_to), 0),
    'avg_checklist_score', COALESCE((SELECT ROUND(AVG(total_points::numeric / NULLIF(max_points, 0) * 100), 1) FROM hr_checklist_operations WHERE created_at >= v_from AND created_at < v_to), 0)
  ) INTO v_totals
  FROM (
    SELECT
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE ta.status = 'completed') as completed,
      COUNT(*) FILTER (WHERE ta.status NOT IN ('completed','cancelled')) as pending,
      COUNT(*) FILTER (WHERE ta.status NOT IN ('completed','cancelled') AND ta.deadline_date < CURRENT_DATE) as overdue,
      EXTRACT(EPOCH FROM AVG(ta.completed_at - ta.assigned_at) FILTER (WHERE ta.status = 'completed')) / 3600 as avg_hrs
    FROM task_assignments ta
    WHERE ta.assigned_at >= v_from AND ta.assigned_at < v_to

    UNION ALL

    SELECT
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE qta.status = 'completed') as completed,
      COUNT(*) FILTER (WHERE qta.status NOT IN ('completed','cancelled')) as pending,
      COUNT(*) FILTER (WHERE qta.status NOT IN ('completed','cancelled') AND qt.deadline_datetime < NOW()) as overdue,
      EXTRACT(EPOCH FROM AVG(qta.completed_at - qta.created_at) FILTER (WHERE qta.status = 'completed')) / 3600 as avg_hrs
    FROM quick_task_assignments qta
--

--
-- Name: get_branch_promissory_notes_summary(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_branch_promissory_notes_summary(branch_uuid uuid) RETURNS TABLE(total_notes integer, total_active_amount numeric, total_collected_amount numeric, active_notes_count integer, collected_notes_count integer, cancelled_notes_count integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_notes,
        COALESCE(SUM(CASE WHEN status = 'active' THEN amount ELSE 0 END), 0) as total_active_amount,
        COALESCE(SUM(CASE WHEN status = 'collected' THEN amount ELSE 0 END), 0) as total_collected_amount,
        COUNT(CASE WHEN status = 'active' THEN 1 END)::INTEGER as active_notes_count,
        COUNT(CASE WHEN status = 'collected' THEN 1 END)::INTEGER as collected_notes_count,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END)::INTEGER as cancelled_notes_count
    FROM promissory_notes 
    WHERE branch_id = branch_uuid;
END;
$$;


--
-- Name: get_branch_service_availability(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_branch_service_availability(branch_id uuid) RETURNS TABLE(delivery_enabled boolean, pickup_enabled boolean, branch_name_en text, branch_name_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.delivery_service_enabled,
        b.pickup_service_enabled,
        b.name_en,
        b.name_ar
    FROM public.branches b
    WHERE b.id = branch_id
    LIMIT 1;
END;
$$;


--
-- Name: FUNCTION get_branch_service_availability(branch_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_branch_service_availability(branch_id uuid) IS 'Check delivery and pickup service availability for a specific branch';


--
-- Name: get_branch_sync_configs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_branch_sync_configs() RETURNS TABLE(id bigint, branch_id bigint, branch_name_en text, branch_name_ar text, local_supabase_url text, local_supabase_key text, tunnel_url text, ssh_user text, is_active boolean, last_sync_at timestamp with time zone, last_sync_status text, last_sync_details jsonb, sync_tables text[])
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    c.id, c.branch_id,
    b.name_en as branch_name_en,
    b.name_ar as branch_name_ar,
    c.local_supabase_url, c.local_supabase_key,
    c.tunnel_url, COALESCE(c.ssh_user, 'u') as ssh_user,
    c.is_active,
    c.last_sync_at, c.last_sync_status, c.last_sync_details,
    c.sync_tables
  FROM branch_sync_config c
  JOIN branches b ON b.id = c.branch_id
  WHERE c.is_active = true
  ORDER BY b.name_en;
$$;


--
-- Name: get_branch_visits_summary(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_branch_visits_summary(branch_uuid uuid, start_date date DEFAULT CURRENT_DATE, end_date date DEFAULT (CURRENT_DATE + '30 days'::interval)) RETURNS TABLE(total_visits integer, scheduled_visits integer, confirmed_visits integer, completed_visits integer, high_priority_visits integer, visits_requiring_followup integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_visits,
        COUNT(CASE WHEN status = 'scheduled' THEN 1 END)::INTEGER as scheduled_visits,
        COUNT(CASE WHEN status = 'confirmed' THEN 1 END)::INTEGER as confirmed_visits,
        COUNT(CASE WHEN status = 'completed' THEN 1 END)::INTEGER as completed_visits,
        COUNT(CASE WHEN priority IN ('high', 'urgent') THEN 1 END)::INTEGER as high_priority_visits,
        COUNT(CASE WHEN follow_up_required = true THEN 1 END)::INTEGER as visits_requiring_followup
    FROM vendor_visits 
    WHERE branch_id = branch_uuid 
    AND visit_date BETWEEN start_date AND end_date;
END;
$$;


--
-- Name: get_break_security_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_break_security_code() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_seed text;
    v_epoch bigint;
    v_code text;
    v_ttl integer;
BEGIN
    SELECT seed INTO v_seed FROM break_security_seed WHERE id = 1;
    
    IF v_seed IS NULL THEN
        RETURN jsonb_build_object('error', 'No security seed configured');
    END IF;
    
    -- Current 10-second epoch
    v_epoch := floor(extract(epoch from now()) / 10)::bigint;
    
    -- Generate code: md5 of seed + epoch, take first 12 chars
    v_code := substring(md5(v_seed || v_epoch::text) from 1 for 12);
    
    -- Time remaining in this window (seconds)
    v_ttl := 10 - (extract(epoch from now())::integer % 10);
    
    RETURN jsonb_build_object(
        'code', v_code,
        'ttl', v_ttl,
        'epoch', v_epoch
    );
END;
$$;


--
-- Name: get_break_summary_all_employees(date, date, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_break_summary_all_employees(p_date_from date DEFAULT NULL::date, p_date_to date DEFAULT NULL::date, p_branch_id integer DEFAULT NULL::integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_date_from DATE;
    v_date_to DATE;
    v_result JSONB;
BEGIN
    -- Default to last 7 days if not specified
    v_date_to := COALESCE(p_date_to, (NOW() AT TIME ZONE 'Asia/Riyadh')::DATE);
    v_date_from := COALESCE(p_date_from, v_date_to - INTERVAL '6 days');

    -- Build summary: all active employees LEFT JOINed with break data
    SELECT COALESCE(jsonb_agg(emp_row ORDER BY emp_row->>'employee_name_en'), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'employee_id', e.id,
            'employee_name_en', e.name_en,
            'employee_name_ar', e.name_ar,
            'branch_id', e.current_branch_id,
            'days', COALESCE(
                (SELECT jsonb_agg(day_data ORDER BY day_data->>'date')
                 FROM (
                    SELECT jsonb_build_object(
                        'date', d.dt::DATE::TEXT,
                        'total_seconds', COALESCE(SUM(br.duration_seconds), 0),
                        'break_count', COUNT(br.id)
                    ) AS day_data
                    FROM generate_series(v_date_from, v_date_to, '1 day'::INTERVAL) AS d(dt)
                    LEFT JOIN break_register br
                        ON br.user_id = e.user_id
                        AND br.status = 'closed'
                        AND (br.start_time AT TIME ZONE 'Asia/Riyadh')::DATE = d.dt::DATE
                    GROUP BY d.dt
                 ) sub
                ),
                '[]'::JSONB
            ),
            'grand_total_seconds', COALESCE(
                (SELECT SUM(br2.duration_seconds)
                 FROM break_register br2
                 WHERE br2.user_id = e.user_id
                   AND br2.status = 'closed'
                   AND (br2.start_time AT TIME ZONE 'Asia/Riyadh')::DATE BETWEEN v_date_from AND v_date_to
                ), 0
            )
        ) AS emp_row
        FROM hr_employee_master e
        WHERE e.user_id IS NOT NULL
          AND COALESCE(e.employment_status, '') NOT IN ('Remote Job', 'Vacation', 'Resigned', 'Terminated', 'Run Away')
--

--
-- Name: get_broadcast_recipients(uuid, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_broadcast_recipients(p_broadcast_id uuid, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0, p_status_filter text DEFAULT NULL::text) RETURNS TABLE(id uuid, phone_number character varying, customer_name text, status character varying, sent_at timestamp with time zone, error_details text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT r.id, r.phone_number, r.customer_name, r.status, r.sent_at, r.error_details
    FROM wa_broadcast_recipients r
    WHERE r.broadcast_id = p_broadcast_id
      AND (p_status_filter IS NULL OR r.status = p_status_filter)
    ORDER BY r.sent_at DESC NULLS LAST
    LIMIT p_limit
    OFFSET p_offset;
$$;


--
-- Name: get_broadcast_summary(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_broadcast_summary(p_broadcast_id uuid) RETURNS TABLE(total_count bigint, pending_count bigint, sent_count bigint, delivered_count bigint, read_count bigint, failed_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT 
        COUNT(*)::bigint AS total_count,
        COUNT(*) FILTER (WHERE status = 'pending')::bigint AS pending_count,
        COUNT(*) FILTER (WHERE status = 'sent')::bigint AS sent_count,
        COUNT(*) FILTER (WHERE status = 'delivered')::bigint AS delivered_count,
        COUNT(*) FILTER (WHERE status = 'read')::bigint AS read_count,
        COUNT(*) FILTER (WHERE status = 'failed')::bigint AS failed_count
    FROM wa_broadcast_recipients
    WHERE broadcast_id = p_broadcast_id;
$$;


--
-- Name: get_bt_assigned_ims(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bt_assigned_ims(p_request_ids uuid[]) RETURNS TABLE(product_request_id uuid, assigned_to_user_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        qt.product_request_id,
        qta.assigned_to_user_id
    FROM quick_tasks qt
    INNER JOIN quick_task_assignments qta ON qta.quick_task_id = qt.id
    WHERE qt.product_request_type = 'BT'
    AND qt.product_request_id = ANY(p_request_ids);
END;
$$;


--
-- Name: get_bt_requests_with_details(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bt_requests_with_details() RETURNS TABLE(id uuid, requester_user_id uuid, from_branch_id integer, to_branch_id integer, target_user_id uuid, status character varying, items jsonb, document_url text, created_at timestamp with time zone, updated_at timestamp with time zone, requester_name_en text, requester_name_ar text, target_name_en text, target_name_ar text, from_branch_name_en text, from_branch_name_ar text, from_branch_location_en text, from_branch_location_ar text, to_branch_name_en text, to_branch_name_ar text, to_branch_location_en text, to_branch_location_ar text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.requester_user_id,
        r.from_branch_id,
        r.to_branch_id,
        r.target_user_id,
        r.status,
        r.items,
        r.document_url,
        r.created_at,
        r.updated_at,
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        COALESCE(fb.name_en, '')::TEXT AS from_branch_name_en,
        COALESCE(fb.name_ar, fb.name_en, '')::TEXT AS from_branch_name_ar,
        COALESCE(fb.location_en, '')::TEXT AS from_branch_location_en,
        COALESCE(fb.location_ar, fb.location_en, '')::TEXT AS from_branch_location_ar,
        COALESCE(tb.name_en, '')::TEXT AS to_branch_name_en,
        COALESCE(tb.name_ar, tb.name_en, '')::TEXT AS to_branch_name_ar,
        COALESCE(tb.location_en, '')::TEXT AS to_branch_location_en,
        COALESCE(tb.location_ar, tb.location_en, '')::TEXT AS to_branch_location_ar
    FROM product_request_bt r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches fb ON fb.id = r.from_branch_id
    LEFT JOIN branches tb ON tb.id = r.to_branch_id
    ORDER BY r.created_at DESC;
END;
$$;


--
-- Name: get_bucket_files(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bucket_files(p_bucket_id text) RETURNS TABLE(file_name text, full_path text, file_size bigint, created_at timestamp with time zone, mime_type text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    o.name::text AS file_name,
    o.name::text AS full_path,
    COALESCE((o.metadata->>'size')::bigint, 0) AS file_size,
    o.created_at,
    COALESCE(o.metadata->>'mimetype', o.metadata->>'mimeType', '') AS mime_type
  FROM storage.objects o
  WHERE o.bucket_id = p_bucket_id
  ORDER BY o.name;
$$;


--
-- Name: get_campaign_statistics(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_campaign_statistics(p_campaign_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_stats JSONB;
  v_products JSONB;
  v_max_claims INTEGER;
BEGIN
  -- Get campaign max claims
  SELECT COALESCE(max_claims_per_customer, 1)
  INTO v_max_claims
  FROM coupon_campaigns
  WHERE id = p_campaign_id;
  
  -- Get overall campaign stats
  SELECT jsonb_build_object(
    'max_claims_per_customer', v_max_claims,
    'total_eligible_customers', (
      SELECT COUNT(*) 
      FROM coupon_eligible_customers 
      WHERE campaign_id = p_campaign_id
    ),
    'total_claims', (
      SELECT COUNT(*) 
      FROM coupon_claims 
      WHERE campaign_id = p_campaign_id
    ),
    'unique_customers_claimed', (
      SELECT COUNT(DISTINCT customer_mobile)
      FROM coupon_claims
      WHERE campaign_id = p_campaign_id
    ),
    'remaining_potential_claims', (
      SELECT COUNT(*) * v_max_claims
      FROM coupon_eligible_customers ec
      WHERE ec.campaign_id = p_campaign_id
    ) - (
      SELECT COUNT(*)
      FROM coupon_claims
      WHERE campaign_id = p_campaign_id
    ),
    'total_stock_limit', (
      SELECT COALESCE(SUM(stock_limit), 0)
      FROM coupon_products
      WHERE campaign_id = p_campaign_id
        AND deleted_at IS NULL
    ),
    'total_stock_remaining', (
      SELECT COALESCE(SUM(stock_remaining), 0)
      FROM coupon_products
      WHERE campaign_id = p_campaign_id
--

--
-- Name: get_cart_tier_discount(integer, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_cart_tier_discount(p_offer_id integer, p_cart_amount numeric) RETURNS TABLE(tier_number integer, discount_type character varying, discount_value numeric, min_amount numeric, max_amount numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.tier_number,
        t.discount_type,
        t.discount_value,
        t.min_amount,
        t.max_amount
    FROM offer_cart_tiers t
    WHERE t.offer_id = p_offer_id
      AND p_cart_amount >= t.min_amount
      AND (t.max_amount IS NULL OR p_cart_amount <= t.max_amount)
    ORDER BY t.tier_number DESC
    LIMIT 1;
END;
$$;


--
-- Name: get_close_purchase_voucher_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_close_purchase_voucher_data() RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT jsonb_build_object(
    'vouchers', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', pvi.id,
          'purchase_voucher_id', pvi.purchase_voucher_id,
          'serial_number', pvi.serial_number,
          'value', pvi.value,
          'status', pvi.status,
          'issue_type', pvi.issue_type,
          'stock_location', pvi.stock_location,
          'stock_location_name', COALESCE(b.name_en || ' - ' || b.location_en, '-'),
          'issued_by', pvi.issued_by,
          'issued_by_name', COALESCE(eby.name_en, uby.username, '-'),
          'issued_to', pvi.issued_to,
          'issued_to_name', COALESCE(eto.name_en, uto.username, '-'),
          'issued_date', pvi.issued_date,
          'issue_remarks', pvi.issue_remarks,
          'approval_status', pvi.approval_status
        )
        ORDER BY pvi.issued_date DESC
      )
      FROM purchase_voucher_items pvi
      LEFT JOIN branches b ON b.id = pvi.stock_location
      LEFT JOIN users uby ON uby.id = pvi.issued_by
      LEFT JOIN hr_employee_master eby ON eby.id = uby.employee_id::text
      LEFT JOIN users uto ON uto.id = pvi.issued_to
      LEFT JOIN hr_employee_master eto ON eto.id = uto.employee_id::text
      WHERE pvi.status = 'issued' OR pvi.approval_status = 'pending'
    ), '[]'::jsonb),
    'branches', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', id, 'name_en', name_en, 'location_en', location_en))
      FROM branches
    ), '[]'::jsonb),
    'expense_categories', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', id, 'name_en', name_en, 'name_ar', name_ar, 'parent_category_id', parent_category_id))
      FROM expense_sub_categories WHERE is_active = true
    ), '[]'::jsonb)
  );
$$;


--
-- Name: get_closed_boxes(text, timestamp with time zone, timestamp with time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_closed_boxes(p_branch_id text DEFAULT 'all'::text, p_date_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_date_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_total_count bigint;
  v_boxes jsonb;
BEGIN
  -- Get total count for the filtered set
  SELECT COUNT(*)
  INTO v_total_count
  FROM box_operations bo
  WHERE bo.status = 'completed'
    AND (p_branch_id = 'all' OR bo.branch_id = p_branch_id::int)
    AND (p_date_from IS NULL OR bo.updated_at >= p_date_from)
    AND (p_date_to IS NULL OR bo.updated_at <= p_date_to);

  -- Get boxes with their transfer status included
  SELECT COALESCE(jsonb_agg(row_data ORDER BY (row_data->>'updated_at') DESC), '[]'::jsonb)
  INTO v_boxes
  FROM (
    SELECT jsonb_build_object(
      'id', bo.id,
      'box_number', bo.box_number,
      'branch_id', bo.branch_id,
      'user_id', bo.user_id,
      'status', bo.status,
      'notes', bo.notes,
      'complete_details', bo.complete_details,
      'completed_by_name', bo.completed_by_name,
      'completed_by_user_id', bo.completed_by_user_id,
      'total_before', bo.total_before,
      'total_after', bo.total_after,
      'created_at', bo.created_at,
      'updated_at', bo.updated_at,
      'transfer_status', pdt.status::text,
      'transfer_key', CASE WHEN pdt.box_number IS NOT NULL 
        THEN pdt.box_number::text || '-' || pdt.branch_id::text || '-' || pdt.date_closed_box::text
        ELSE NULL END
    ) as row_data
    FROM box_operations bo
    LEFT JOIN pos_deduction_transfers pdt 
      ON pdt.box_operation_id = bo.id
    WHERE bo.status = 'completed'
      AND (p_branch_id = 'all' OR bo.branch_id = p_branch_id::int)
      AND (p_date_from IS NULL OR bo.updated_at >= p_date_from)
      AND (p_date_to IS NULL OR bo.updated_at <= p_date_to)
    ORDER BY bo.updated_at DESC
    LIMIT p_limit
    OFFSET p_offset
  ) sub;
--

--
-- Name: get_completed_receiving_tasks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_completed_receiving_tasks() RETURNS TABLE(id uuid, receiving_record_id uuid, template_id uuid, role_type character varying, title text, description text, priority character varying, task_status character varying, task_completed boolean, due_date timestamp with time zone, assigned_user_id uuid, completed_at timestamp with time zone, completed_by_user_id uuid, clearance_certificate_url text, created_at timestamp with time zone, bill_number character varying, bill_amount numeric, vendor_name text, branch_name text, assigned_user_name text, completed_by_user_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rt.id,
    rt.receiving_record_id,
    rt.template_id,
    rt.role_type,
    rt.title,
    rt.description,
    rt.priority,
    rt.task_status,
    rt.task_completed,
    rt.due_date,
    rt.assigned_user_id,
    rt.completed_at,
    rt.completed_by_user_id,
    rt.clearance_certificate_url,
    rt.created_at,
    rr.bill_number,
    rr.bill_amount,
    v.vendor_name,
    b.name_en as branch_name,
    u1.username as assigned_user_name,
    u2.username as completed_by_user_name
  FROM receiving_tasks rt
  LEFT JOIN receiving_records rr ON rr.id = rt.receiving_record_id
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  LEFT JOIN users u1 ON u1.id = rt.assigned_user_id
  LEFT JOIN users u2 ON u2.id = rt.completed_by_user_id
  WHERE rt.task_completed = true OR rt.task_status = 'completed'
  ORDER BY rt.completed_at DESC;
END;
$$;


--
-- Name: get_completed_tasks(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_completed_tasks(p_limit integer DEFAULT 500) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'tasks', COALESCE(tasks_arr, '[]'::json),
    'total_count', COALESCE(json_array_length(tasks_arr), 0)
  ) INTO v_result
  FROM (
    SELECT json_agg(row_to_json(t)) as tasks_arr
    FROM (
      SELECT * FROM (
      -- Task Assignments (completed)
      SELECT
        ta.id,
        'regular' as task_type,
        COALESCE(tk.title, 'Task Assignment #' || LEFT(ta.id::text, 8)) as task_title,
        COALESCE(tk.description, '') as task_description,
        ta.status,
        COALESCE(ta.priority_override, tk.priority, 'medium') as priority,
        COALESCE(b.name_en, 'No Branch') as branch_name,
        COALESCE(b.name_ar, b.name_en, 'No Branch') as branch_name_ar,
        ta.assigned_to_branch_id as branch_id,
        COALESCE(u_to.username, 'Unassigned') as assigned_to_name,
        COALESCE(e_to.name_en, u_to.username, 'Unassigned') as assigned_to_name_en,
        COALESCE(e_to.name_ar, e_to.name_en, u_to.username, 'Unassigned') as assigned_to_name_ar,
        ta.assigned_to_user_id,
        COALESCE(u_by.username, 'System') as assigned_by_name,
        ta.assigned_at as assigned_date,
        COALESCE(ta.deadline_datetime::text, ta.deadline_date::text) as deadline,
        ta.completed_at as completed_date,
        ta.notes,
        ROUND(EXTRACT(EPOCH FROM (ta.completed_at - ta.assigned_at)) / 3600, 1) as completion_hours,
        tc.completion_photo_url as completion_photo_url,
        tc.completion_notes as completion_notes_detail,
        tc.completed_by_name as completed_by_name,
        tc.erp_reference_number as erp_reference
      FROM task_assignments ta
      LEFT JOIN tasks tk ON tk.id = ta.task_id
      LEFT JOIN branches b ON b.id = ta.assigned_to_branch_id
      LEFT JOIN users u_to ON u_to.id = ta.assigned_to_user_id
      LEFT JOIN users u_by ON u_by.id = ta.assigned_by
      LEFT JOIN hr_employee_master e_to ON e_to.user_id = ta.assigned_to_user_id
      LEFT JOIN LATERAL (
        SELECT tc2.completion_photo_url, tc2.completion_notes, tc2.completed_by_name, tc2.erp_reference_number
        FROM task_completions tc2
        WHERE tc2.assignment_id = ta.id
        ORDER BY tc2.completed_at DESC
        LIMIT 1
--

--
-- Name: get_contact_broadcast_stats(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_contact_broadcast_stats(phone_number text) RETURNS TABLE(sent integer, delivered integer, read integer, failed integer, total integer)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
  SELECT
    COALESCE(COUNT(*) FILTER (WHERE status = 'sent'), 0) as sent,
    COALESCE(COUNT(*) FILTER (WHERE status = 'delivered'), 0) as delivered,
    COALESCE(COUNT(*) FILTER (WHERE status = 'read'), 0) as read,
    COALESCE(COUNT(*) FILTER (WHERE status = 'failed'), 0) as failed,
    COUNT(*) as total
  FROM wa_broadcast_recipients
  WHERE phone_number = $1;
$_$;


--
-- Name: get_current_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_current_user_id() RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN current_setting('app.current_user_id', true)::UUID;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$;


--
-- Name: get_customer_login_code(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customer_login_code(p_customer_id uuid) RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT access_code FROM public.customers WHERE id = p_customer_id AND is_deleted = false;
$$;


--
-- Name: get_customer_pending_loyalty_otp(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customer_pending_loyalty_otp(p_phone text) RETURNS TABLE(redemption_id uuid, otp_code text, created_at timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    id AS redemption_id,
    otp_code,
    created_at
  FROM public.loyalty_redemptions
  WHERE whatsapp_number = p_phone
    AND status != 'confirmed'
    AND otp_code IS NOT NULL
    AND otp_confirmed_at IS NULL
    AND created_at > (now() - interval '15 minutes')
  ORDER BY created_at DESC
  LIMIT 1;
$$;


--
-- Name: get_customer_products_with_offers(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customer_products_with_offers(p_branch_id text DEFAULT NULL::text, p_service_type text DEFAULT 'both'::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_result json;
  v_now timestamptz := NOW();
BEGIN
  WITH
  -- Step 1: Get active offers filtered by branch and service type
  active_offers AS (
    SELECT *
    FROM offers o
    WHERE o.is_active = true
      AND o.type IN ('product', 'bogo', 'bundle')
      AND o.start_date <= v_now
      AND o.end_date >= v_now
      AND (o.branch_id IS NULL OR o.branch_id::text = p_branch_id)
      AND (o.service_type IS NULL OR o.service_type = 'both' OR o.service_type = p_service_type)
  ),

  -- Step 2: Get offer products with enriched product + offer data
  enriched_offer_products AS (
    SELECT
      p.id,
      p.barcode,
      p.product_name_en AS "nameEn",
      p.product_name_ar AS "nameAr",
      p.category_id AS category,
      COALESCE(pc.name_en, 'Uncategorized') AS "categoryNameEn",
      COALESCE(pc.name_ar, '╪║┘è╪▒ ┘à╪╡┘å┘ü') AS "categoryNameAr",
      p.image_url AS image,
      p.current_stock AS stock,
      p.minimum_qty_alert AS "lowStockThreshold",
      COALESCE(pu.name_en, 'Unit') AS "unitEn",
      COALESCE(pu.name_ar, '┘ê╪¡╪»╪⌐') AS "unitAr",
      COALESCE(p.unit_qty, 1) AS "unitQty",
      p.sale_price::float AS "originalPrice",
      -- Calculate offer price
      CASE
        WHEN op.offer_percentage IS NOT NULL AND op.offer_percentage > 0 THEN
          (p.sale_price - (p.sale_price * op.offer_percentage / 100))::float
        WHEN op.offer_price IS NOT NULL AND op.offer_price > 0 THEN
          op.offer_price::float
        ELSE NULL
      END AS "offerPrice",
      -- Calculate savings
      CASE
        WHEN op.offer_percentage IS NOT NULL AND op.offer_percentage > 0 THEN
          (p.sale_price * op.offer_percentage / 100)::float
        WHEN op.offer_price IS NOT NULL AND op.offer_price > 0 THEN
          (p.sale_price - op.offer_price)::float
--

--
-- Name: get_customer_requests_with_details(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customer_requests_with_details() RETURNS TABLE(id uuid, requester_user_id uuid, branch_id integer, target_user_id uuid, status text, items jsonb, notes text, created_at timestamp with time zone, updated_at timestamp with time zone, requester_name_en text, requester_name_ar text, target_name_en text, target_name_ar text, branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.requester_user_id,
        r.branch_id,
        r.target_user_id,
        r.status,
        r.items,
        r.notes,
        r.created_at,
        r.updated_at,
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        COALESCE(b.name_en, '')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, b.name_en, '')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, b.location_en, '')::TEXT AS branch_location_ar
    FROM customer_product_requests r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches b ON b.id = r.branch_id
    ORDER BY r.created_at DESC;
END;
$$;


--
-- Name: get_customers_list(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customers_list() RETURNS TABLE(id uuid, name text, access_code text, whatsapp_number text, registration_status text, registration_notes text, approved_by uuid, approved_at timestamp with time zone, access_code_generated_at timestamp with time zone, last_login_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone, location1_name text, location1_url text, location1_lat double precision, location1_lng double precision, location2_name text, location2_url text, location2_lat double precision, location2_lng double precision, location3_name text, location3_url text, location3_lat double precision, location3_lng double precision, is_deleted boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.access_code,
    c.whatsapp_number::text,
    c.registration_status,
    c.registration_notes,
    c.approved_by,
    c.approved_at,
    c.access_code_generated_at,
    c.last_login_at,
    c.created_at,
    c.updated_at,
    c.location1_name,
    c.location1_url,
    c.location1_lat,
    c.location1_lng,
    c.location2_name,
    c.location2_url,
    c.location2_lat,
    c.location2_lng,
    c.location3_name,
    c.location3_url,
    c.location3_lat,
    c.location3_lng,
    c.is_deleted
  FROM customers c
  ORDER BY
    CASE
      WHEN c.registration_status = 'pending' THEN 1
      WHEN c.registration_status = 'approved' THEN 2
      WHEN c.registration_status = 'rejected' THEN 3
      WHEN c.registration_status = 'suspended' THEN 4
      ELSE 5
    END,
    c.created_at DESC;
END;
$$;


--
-- Name: get_customers_list_paginated(text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customers_list_paginated(p_search text DEFAULT ''::text, p_status text DEFAULT 'all'::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  result json;
  total_count bigint;
  rows_data json;
BEGIN
  -- Get total count with filters
  SELECT count(*)
  INTO total_count
  FROM customers c
  WHERE
    (p_status = 'all' OR c.registration_status = p_status)
    AND (
      p_search = ''
      OR c.name ILIKE '%' || p_search || '%'
      OR c.whatsapp_number ILIKE '%' || p_search || '%'
    );

  -- Get paginated rows
  SELECT json_agg(row_data)
  INTO rows_data
  FROM (
    SELECT
      c.id,
      c.name,
      c.access_code,
      c.whatsapp_number::text,
      c.registration_status,
      c.registration_notes,
      c.approved_by,
      c.approved_at,
      c.access_code_generated_at,
      c.last_login_at,
      c.created_at,
      c.updated_at,
      c.location1_name,
      c.location1_url,
      c.location1_lat,
      c.location1_lng,
      c.location2_name,
      c.location2_url,
      c.location2_lat,
      c.location2_lng,
      c.location3_name,
      c.location3_url,
      c.location3_lat,
      c.location3_lng,
      c.is_deleted,
--

--
-- Name: get_database_functions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_database_functions() RETURNS TABLE(func_name text, func_args text, return_type text, func_language text, func_type text, is_security_definer boolean, func_definition text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
  rec RECORD;
  ddl text;
  arg_list text;
  ret text;
BEGIN
  FOR rec IN
    SELECT
      p.oid,
      p.proname::text AS fname,
      pg_get_function_arguments(p.oid) AS fargs,
      pg_get_function_result(p.oid) AS fresult,
      l.lanname::text AS flang,
      CASE p.prokind
        WHEN 'f' THEN 'FUNCTION'
        WHEN 'p' THEN 'PROCEDURE'
        WHEN 'a' THEN 'AGGREGATE'
        WHEN 'w' THEN 'WINDOW'
        ELSE 'FUNCTION'
      END AS ftype,
      p.prosecdef AS secdef,
      p.prosrc AS fsrc,
      p.proretset,
      p.provolatile,
      p.proisstrict
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_language l ON l.oid = p.prolang
    WHERE n.nspname = 'public'
    ORDER BY p.proname
  LOOP
    -- Build CREATE OR REPLACE
    ddl := 'CREATE OR REPLACE ' || rec.ftype || ' public.' || quote_ident(rec.fname) || '(' || rec.fargs || ')' || E'\n';
    ddl := ddl || 'RETURNS ' || rec.fresult || E'\n';
    ddl := ddl || 'LANGUAGE ' || rec.flang || E'\n';

    -- Volatility
    IF rec.provolatile = 'i' THEN
      ddl := ddl || 'IMMUTABLE' || E'\n';
    ELSIF rec.provolatile = 's' THEN
      ddl := ddl || 'STABLE' || E'\n';
    END IF;

    IF rec.proisstrict THEN
      ddl := ddl || 'STRICT' || E'\n';
    END IF;

--

--
-- Name: get_database_schema(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_database_schema() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  result jsonb;
BEGIN
  -- Get basic table and column information only
  SELECT jsonb_build_object(
    'tables', jsonb_agg(
      jsonb_build_object(
        'table_name', table_info.table_name,
        'columns', table_info.columns
      ) ORDER BY table_info.table_name
    )
  ) INTO result
  FROM (
    SELECT 
      t.table_name,
      jsonb_agg(
        jsonb_build_object(
          'column_name', c.column_name,
          'data_type', c.data_type,
          'is_nullable', c.is_nullable,
          'column_default', c.column_default
        ) ORDER BY c.ordinal_position
      ) as columns
    FROM information_schema.tables t
    LEFT JOIN information_schema.columns c 
      ON c.table_schema = t.table_schema 
      AND c.table_name = t.table_name
    WHERE t.table_schema = 'public'
      AND t.table_type = 'BASE TABLE'
    GROUP BY t.table_name
  ) as table_info;

  RETURN result;
END;
$$;


--
-- Name: get_database_triggers(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_database_triggers() RETURNS TABLE(trigger_name text, event_manipulation text, event_object_table text, action_statement text, action_timing text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tg.trigger_name::text,
        tg.event_manipulation::text,
        tg.event_object_table::text,
        tg.action_statement::text,
        tg.action_timing::text
    FROM information_schema.triggers tg
    WHERE tg.trigger_schema = 'public'
    ORDER BY tg.event_object_table, tg.trigger_name;
END;
$$;


--
-- Name: get_day_offs_with_details(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_day_offs_with_details(p_date_from date, p_date_to date) RETURNS TABLE(id text, employee_id text, employee_id_number text, employee_name_en text, employee_name_ar text, employee_email text, employee_whatsapp text, branch_id text, branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text, nationality_id text, nationality_name_en text, nationality_name_ar text, sponsorship_status text, employment_status text, day_off_date date, approval_status text, reason_en text, reason_ar text, document_url text, description text, is_deductible_on_salary boolean, approval_requested_at timestamp with time zone, day_off_reason_id text, approver_name_en text, approver_name_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.id::TEXT,
        d.employee_id::TEXT,
        COALESCE(e.id_number, '')::TEXT AS employee_id_number,
        COALESCE(e.name_en, 'N/A')::TEXT AS employee_name_en,
        COALESCE(e.name_ar, 'N/A')::TEXT AS employee_name_ar,
        COALESCE(e.email, '')::TEXT AS employee_email,
        COALESCE(e.whatsapp_number, '')::TEXT AS employee_whatsapp,
        e.current_branch_id::TEXT AS branch_id,
        COALESCE(b.name_en, 'N/A')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, 'N/A')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, '')::TEXT AS branch_location_ar,
        e.nationality_id::TEXT,
        COALESCE(n.name_en, 'N/A')::TEXT AS nationality_name_en,
        COALESCE(n.name_ar, 'N/A')::TEXT AS nationality_name_ar,
        e.sponsorship_status::TEXT,
        e.employment_status::TEXT,
        d.day_off_date,
        COALESCE(d.approval_status, 'pending')::TEXT AS approval_status,
        COALESCE(r.reason_en, 'N/A')::TEXT AS reason_en,
        COALESCE(r.reason_ar, 'N/A')::TEXT AS reason_ar,
        d.document_url::TEXT,
        d.description::TEXT,
        COALESCE(d.is_deductible_on_salary, false) AS is_deductible_on_salary,
        d.approval_requested_at,
        d.day_off_reason_id::TEXT,
        COALESCE(a.name_en, '')::TEXT AS approver_name_en,
        COALESCE(a.name_ar, '')::TEXT AS approver_name_ar
    FROM day_off d
    LEFT JOIN hr_employee_master e ON e.id = d.employee_id
    LEFT JOIN branches b ON b.id = e.current_branch_id
    LEFT JOIN nationalities n ON n.id = e.nationality_id
    LEFT JOIN day_off_reasons r ON r.id = d.day_off_reason_id
    LEFT JOIN hr_employee_master a ON a.user_id = d.approval_approved_by
    WHERE d.day_off_date >= p_date_from
      AND d.day_off_date <= p_date_to
    ORDER BY d.day_off_date DESC;
END;
$$;


--
-- Name: get_default_flyer_template(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_default_flyer_template() RETURNS TABLE(id uuid, name character varying, description text, first_page_image_url text, sub_page_image_urls text[], first_page_configuration jsonb, sub_page_configurations jsonb, metadata jsonb)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.name,
    t.description,
    t.first_page_image_url,
    t.sub_page_image_urls,
    t.first_page_configuration,
    t.sub_page_configurations,
    t.metadata
  FROM flyer_templates t
  WHERE t.is_default = true 
    AND t.is_active = true 
    AND t.deleted_at IS NULL
  LIMIT 1;
END;
$$;


--
-- Name: get_delivery_fee_for_amount(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_delivery_fee_for_amount(order_amount numeric) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    calculated_fee numeric;
BEGIN
    -- Find the appropriate tier for the given order amount
    SELECT delivery_fee INTO calculated_fee
    FROM public.delivery_fee_tiers
    WHERE is_active = true
      AND min_order_amount <= order_amount
      AND (max_order_amount IS NULL OR max_order_amount >= order_amount)
    ORDER BY min_order_amount DESC
    LIMIT 1;
    
    -- If no tier found, return 0 (shouldn't happen with proper setup)
    RETURN COALESCE(calculated_fee, 0);
END;
$$;


--
-- Name: FUNCTION get_delivery_fee_for_amount(order_amount numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_delivery_fee_for_amount(order_amount numeric) IS 'Calculate delivery fee based on order amount using active tier structure';


--
-- Name: get_delivery_fee_for_amount_by_branch(bigint, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_delivery_fee_for_amount_by_branch(p_branch_id bigint, p_order_amount numeric) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_fee numeric;
BEGIN
    -- Require a branch id; without it, no fee can be determined
    IF p_branch_id IS NULL THEN
        RETURN 0;
    END IF;

    -- Attempt branch-specific tier match
    SELECT t.delivery_fee INTO v_fee
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND t.branch_id = p_branch_id
      AND t.min_order_amount <= p_order_amount
      AND (t.max_order_amount IS NULL OR t.max_order_amount >= p_order_amount)
    ORDER BY t.min_order_amount DESC
    LIMIT 1;

    RETURN COALESCE(v_fee, 0);
END;
$$;


--
-- Name: FUNCTION get_delivery_fee_for_amount_by_branch(p_branch_id bigint, p_order_amount numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_delivery_fee_for_amount_by_branch(p_branch_id bigint, p_order_amount numeric) IS 'Calculate delivery fee for order amount using branch tiers only';


--
-- Name: get_delivery_service_settings(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_delivery_service_settings() RETURNS TABLE(minimum_order_amount numeric, is_24_hours boolean, operating_start_time time without time zone, operating_end_time time without time zone, is_active boolean, display_message_ar text, display_message_en text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.minimum_order_amount,
        s.is_24_hours,
        s.operating_start_time,
        s.operating_end_time,
        s.is_active,
        s.display_message_ar,
        s.display_message_en
    FROM public.delivery_service_settings s
    WHERE s.id = '00000000-0000-0000-0000-000000000001'::uuid
    LIMIT 1;
END;
$$;


--
-- Name: FUNCTION get_delivery_service_settings(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_delivery_service_settings() IS 'Get global delivery service configuration settings';


--
-- Name: get_delivery_tiers_by_branch(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_delivery_tiers_by_branch(p_branch_id bigint) RETURNS TABLE(id uuid, branch_id bigint, min_order_amount numeric, max_order_amount numeric, delivery_fee numeric, tier_order integer, is_active boolean, description_en text, description_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    -- Strictly branch-specific tiers; if branch_id is NULL, return empty set
    IF p_branch_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        t.id,
        t.branch_id,
        t.min_order_amount,
        t.max_order_amount,
        t.delivery_fee,
        t.tier_order,
        t.is_active,
        t.description_en,
        t.description_ar
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND t.branch_id = p_branch_id
    ORDER BY t.tier_order ASC;
END;
$$;


--
-- Name: FUNCTION get_delivery_tiers_by_branch(p_branch_id bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_delivery_tiers_by_branch(p_branch_id bigint) IS 'Get active delivery fee tiers for a specific branch only';


--
-- Name: get_dependency_completion_photos(uuid, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_dependency_completion_photos(receiving_record_id_param uuid, dependency_role_types text[]) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  result_photos JSONB := '{}'::JSONB;
  current_role_type TEXT;
  task_record RECORD;
BEGIN
  -- Loop through each dependency role type
  FOREACH current_role_type IN ARRAY dependency_role_types
  LOOP
    -- Get the completion photo for this role type
    SELECT completion_photo_url, role_type INTO task_record
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = current_role_type
      AND task_completed = true
      AND completion_photo_url IS NOT NULL
    LIMIT 1;
    
    -- If photo exists, add it to the result
    IF FOUND AND task_record.completion_photo_url IS NOT NULL THEN
      result_photos := result_photos || jsonb_build_object(
        current_role_type, task_record.completion_photo_url
      );
    END IF;
  END LOOP;
  
  -- Convert JSONB to JSON for return
  RETURN result_photos::JSON;
  
EXCEPTION WHEN OTHERS THEN
  -- Return empty object on error
  RETURN '{}'::JSON;
END;
$$;


--
-- Name: get_edge_function_logs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_edge_function_logs(p_limit integer DEFAULT 100) RETURNS TABLE(runid bigint, jobname text, status text, return_message text, start_time timestamp with time zone, end_time timestamp with time zone, duration_ms double precision)
    LANGUAGE sql SECURITY DEFINER
    AS $$
  SELECT 
    d.runid,
    j.jobname,
    d.status,
    d.return_message,
    d.start_time,
    d.end_time,
    EXTRACT(EPOCH FROM (d.end_time - d.start_time)) * 1000 as duration_ms
  FROM cron.job_run_details d
  JOIN cron.job j ON j.jobid = d.jobid
  ORDER BY d.start_time DESC
  LIMIT p_limit;
$$;


--
-- Name: get_edge_functions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_edge_functions() RETURNS TABLE(func_name text, func_size text, file_count integer, last_modified timestamp with time zone, has_index boolean, func_code text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT func_name, func_size, file_count, last_modified, has_index, func_code
  FROM public.edge_functions_cache
  ORDER BY func_name;
$$;


--
-- Name: get_employee_basic_hours(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_employee_basic_hours(p_employee_id bigint) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    emp_basic_hours DECIMAL(4,2);
BEGIN
    SELECT basic_hours INTO emp_basic_hours
    FROM employee_basic_hours 
    WHERE employee_id = p_employee_id;
    
    -- Return employee-specific hours or default to 8.0
    RETURN COALESCE(emp_basic_hours, 8.0);
END;
$$;


--
-- Name: get_employee_basic_hours(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_employee_basic_hours(p_employee_id uuid, p_date date DEFAULT CURRENT_DATE) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    basic_hours DECIMAL(4,2);
BEGIN
    SELECT ebh.basic_hours_per_day
    INTO basic_hours
    FROM employee_basic_hours ebh
    WHERE ebh.employee_id = p_employee_id
      AND ebh.is_active = true
      AND p_date >= ebh.effective_from
      AND (ebh.effective_to IS NULL OR p_date <= ebh.effective_to)
    ORDER BY ebh.effective_from DESC
    LIMIT 1;
    
    RETURN COALESCE(basic_hours, 8.0); -- Default to 8 hours if not configured
END;
$$;


--
-- Name: get_employee_document_category_stats(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_employee_document_category_stats(emp_id uuid) RETURNS TABLE(category public.document_category_enum, count bigint, total_days integer, latest_date timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.document_category::document_category_enum,
        COUNT(*)::BIGINT,
        SUM(COALESCE(d.category_days, 0))::INTEGER,
        MAX(d.upload_date)
    FROM hr_employee_documents d
    WHERE d.employee_id = emp_id 
      AND d.is_active = true 
      AND d.document_category IS NOT NULL
    GROUP BY d.document_category;
END;
$$;


--
-- Name: get_employee_master_list(text, integer, integer, text, integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_employee_master_list(p_search text DEFAULT ''::text, p_page integer DEFAULT 1, p_limit integer DEFAULT 50, p_status_filter text DEFAULT NULL::text, p_branch_filter integer DEFAULT NULL::integer, p_position_filter uuid DEFAULT NULL::uuid) RETURNS TABLE(id text, name_en character varying, name_ar character varying, current_branch_id integer, branch_name_en character varying, branch_name_ar character varying, branch_location_en character varying, branch_location_ar character varying, current_position_id uuid, position_title_en character varying, position_title_ar character varying, employment_status text, whatsapp_number text, email text, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    e.id,
    e.name_en,
    e.name_ar,
    e.current_branch_id,
    b.name_en AS branch_name_en,
    b.name_ar AS branch_name_ar,
    b.location_en AS branch_location_en,
    b.location_ar AS branch_location_ar,
    e.current_position_id,
    pos.position_title_en,
    pos.position_title_ar,
    e.employment_status,
    e.whatsapp_number,
    e.email,
    COUNT(*) OVER() AS total_count
  FROM hr_employee_master e
  LEFT JOIN branches b ON b.id = e.current_branch_id
  LEFT JOIN hr_positions pos ON pos.id = e.current_position_id
  WHERE
    (COALESCE(p_search, '') = ''
      OR e.name_en ILIKE '%' || p_search || '%'
      OR e.name_ar ILIKE '%' || p_search || '%'
      OR e.id ILIKE '%' || p_search || '%'
      OR e.whatsapp_number ILIKE '%' || p_search || '%'
      OR e.email ILIKE '%' || p_search || '%')
    AND (p_status_filter IS NULL OR p_status_filter = '' OR e.employment_status = p_status_filter)
    AND (p_branch_filter IS NULL OR e.current_branch_id = p_branch_filter)
    AND (p_position_filter IS NULL OR e.current_position_id = p_position_filter)
  ORDER BY e.name_en ASC NULLS LAST
  LIMIT GREATEST(1, LEAST(p_limit, 200))
  OFFSET (GREATEST(1, p_page) - 1) * GREATEST(1, LEAST(p_limit, 200));
$$;


--
-- Name: get_employee_master_list(text, integer, integer, text, integer, uuid, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_employee_master_list(p_search text DEFAULT ''::text, p_page integer DEFAULT 1, p_limit integer DEFAULT 50, p_status_filter text DEFAULT NULL::text, p_branch_filter integer DEFAULT NULL::integer, p_position_filter uuid DEFAULT NULL::uuid, p_exclude_statuses text[] DEFAULT NULL::text[]) RETURNS TABLE(id text, name_en character varying, name_ar character varying, current_branch_id integer, branch_name_en character varying, branch_name_ar character varying, branch_location_en character varying, branch_location_ar character varying, current_position_id uuid, position_title_en character varying, position_title_ar character varying, employment_status text, whatsapp_number text, email text, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    e.id, e.name_en, e.name_ar, e.current_branch_id,
    b.name_en AS branch_name_en, b.name_ar AS branch_name_ar,
    b.location_en AS branch_location_en, b.location_ar AS branch_location_ar,
    e.current_position_id, pos.position_title_en, pos.position_title_ar,
    e.employment_status, e.whatsapp_number, e.email,
    COUNT(*) OVER() AS total_count
  FROM hr_employee_master e
  LEFT JOIN branches b ON b.id = e.current_branch_id
  LEFT JOIN hr_positions pos ON pos.id = e.current_position_id
  WHERE
    (COALESCE(p_search, '') = ''
      OR e.name_en ILIKE '%' || p_search || '%'
      OR e.name_ar ILIKE '%' || p_search || '%'
      OR e.id ILIKE '%' || p_search || '%'
      OR e.whatsapp_number ILIKE '%' || p_search || '%'
      OR e.email ILIKE '%' || p_search || '%')
    AND (p_status_filter IS NULL OR p_status_filter = '' OR e.employment_status = p_status_filter)
    AND (p_branch_filter IS NULL OR e.current_branch_id = p_branch_filter)
    AND (p_position_filter IS NULL OR e.current_position_id = p_position_filter)
    AND (p_exclude_statuses IS NULL
         OR array_length(p_exclude_statuses, 1) IS NULL
         OR NOT (e.employment_status = ANY(p_exclude_statuses)))
  ORDER BY e.name_en ASC NULLS LAST
  LIMIT GREATEST(1, LEAST(p_limit, 200))
  OFFSET (GREATEST(1, p_page) - 1) * GREATEST(1, LEAST(p_limit, 200));
$$;


--
-- Name: get_employee_products(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_employee_products(p_employee_id text, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'products', COALESCE((
      SELECT json_agg(row_to_json(t))
      FROM (
        SELECT 
          barcode, 
          product_name_en, 
          product_name_ar, 
          parent_barcode,
          expiry_dates,
          managed_by
        FROM erp_synced_products
        WHERE managed_by @> ('[{"employee_id":"' || p_employee_id || '"}]')::jsonb
        ORDER BY product_name_en
        LIMIT p_limit
        OFFSET p_offset
      ) t
    ), '[]'::json),
    'total_count', (
      SELECT count(*)
      FROM erp_synced_products
      WHERE managed_by @> ('[{"employee_id":"' || p_employee_id || '"}]')::jsonb
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


--
-- Name: get_employee_schedules(bigint, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_employee_schedules(p_employee_id bigint, p_start_date date, p_end_date date) RETURNS TABLE(schedule_id bigint, schedule_date date, start_time time without time zone, end_time time without time zone, hours numeric, is_overnight boolean, is_auto boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ds.id,
        ds.schedule_date,
        ds.scheduled_start_time,
        ds.scheduled_end_time,
        ds.scheduled_hours,
        ds.is_overnight,
        ds.is_auto_generated
    FROM duty_schedules ds
    WHERE ds.employee_id = p_employee_id
      AND ds.schedule_date >= p_start_date
      AND ds.schedule_date <= p_end_date
    ORDER BY ds.schedule_date;
END;
$$;


--
-- Name: get_employee_schedules(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_employee_schedules(p_employee_id uuid, p_start_date date, p_end_date date) RETURNS TABLE(schedule_id uuid, schedule_date date, start_time time without time zone, end_time time without time zone, hours numeric, is_overnight boolean, is_auto boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ds.id,
        ds.schedule_date,
        ds.scheduled_start_time,
        ds.scheduled_end_time,
        ds.scheduled_hours,
        ds.is_overnight,
        ds.is_auto_generated
    FROM duty_schedules ds
    WHERE ds.employee_id = p_employee_id
      AND ds.schedule_date >= p_start_date
      AND ds.schedule_date <= p_end_date
    ORDER BY ds.schedule_date;
END;
$$;


--
-- Name: get_expense_category_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_expense_category_stats() RETURNS TABLE(total_parent_categories integer, enabled_parent_categories integer, disabled_parent_categories integer, total_sub_categories integer, enabled_sub_categories integer, disabled_sub_categories integer, vat_applicable_categories integer, vat_not_applicable_categories integer, both_vat_categories integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INT FROM expense_parent_categories) as total_parent_categories,
        (SELECT COUNT(*)::INT FROM expense_parent_categories WHERE is_enabled = true) as enabled_parent_categories,
        (SELECT COUNT(*)::INT FROM expense_parent_categories WHERE is_enabled = false) as disabled_parent_categories,
        COUNT(*)::INT as total_sub_categories,
        COUNT(*) FILTER (WHERE is_enabled = true)::INT as enabled_sub_categories,
        COUNT(*) FILTER (WHERE is_enabled = false)::INT as disabled_sub_categories,
        COUNT(*) FILTER (WHERE vat_applicable = true AND vat_not_applicable = false)::INT as vat_applicable_categories,
        COUNT(*) FILTER (WHERE vat_applicable = false AND vat_not_applicable = true)::INT as vat_not_applicable_categories,
        COUNT(*) FILTER (WHERE vat_applicable = true AND vat_not_applicable = true)::INT as both_vat_categories
    FROM expense_categories;
END;
$$;


--
-- Name: get_expiring_products_count(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_expiring_products_count(p_employee_id text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_branch_id INTEGER;
  v_count INTEGER := 0;
BEGIN
  -- Get employee's current branch
  SELECT current_branch_id INTO v_branch_id
  FROM hr_employee_master
  WHERE id = p_employee_id;

  IF v_branch_id IS NULL THEN
    RETURN jsonb_build_object('count', 0);
  END IF;

  -- Count products managed by this employee where expiry for their branch is < 15 days from now
  SELECT COUNT(DISTINCT p.barcode)
  INTO v_count
  FROM erp_synced_products p,
       LATERAL jsonb_array_elements(COALESCE(p.expiry_dates, '[]'::jsonb)) AS ed
  WHERE p.managed_by @> ('[{"employee_id":"' || p_employee_id || '"}]')::jsonb
    AND (ed->>'branch_id')::INTEGER = v_branch_id
    AND (ed->>'expiry_date') IS NOT NULL
    AND (ed->>'expiry_date')::DATE >= CURRENT_DATE
    AND (ed->>'expiry_date')::DATE < (CURRENT_DATE + INTERVAL '15 days');

  RETURN jsonb_build_object('count', v_count);
END;
$$;


--
-- Name: get_file_extension(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_file_extension(filename text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN lower(split_part(filename, '.', array_length(string_to_array(filename, '.'), 1)));
END;
$$;


--
-- Name: get_flyer_generator_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_flyer_generator_data(p_offer_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  result jsonb;
BEGIN
  WITH 
  -- Step 1: Get all offer products for this offer
  offer_products AS (
    SELECT 
      fop.id,
      fop.offer_id,
      fop.product_barcode,
      fop.cost,
      fop.sales_price,
      fop.offer_price,
      fop.profit_amount,
      fop.profit_percent,
      fop.profit_after_offer,
      fop.decrease_amount,
      fop.offer_qty,
      fop.limit_qty,
      fop.free_qty,
      fop.created_at,
      fop.page_number,
      fop.page_order,
      fop.total_sales_price,
      fop.total_offer_price
    FROM flyer_offer_products fop
    WHERE fop.offer_id = p_offer_id
  ),
  -- Step 2: Get product details for all barcodes in the offer
  product_details AS (
    SELECT 
      p.barcode,
      p.product_name_en,
      p.product_name_ar,
      p.image_url,
      p.is_variation,
      p.parent_product_barcode,
      p.variation_group_name_en,
      p.variation_group_name_ar,
      p.variation_image_override,
      p.variation_order,
      pu.name_ar AS unit_name_ar,
      pu.name_en AS unit_name_en
    FROM products p
    LEFT JOIN product_units pu ON p.unit_id = pu.id
    WHERE p.barcode IN (SELECT product_barcode FROM offer_products)
  ),
  -- Step 3: Get variation images for all variations in the offer
--

--
-- Name: get_hr_departments_list(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hr_departments_list(p_search text DEFAULT ''::text, p_page integer DEFAULT 1, p_limit integer DEFAULT 50) RETURNS TABLE(id uuid, department_name_en character varying, department_name_ar character varying, is_active boolean, created_at timestamp with time zone, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    d.id,
    d.department_name_en,
    d.department_name_ar,
    d.is_active,
    d.created_at,
    COUNT(*) OVER() AS total_count
  FROM hr_departments d
  WHERE
    COALESCE(p_search, '') = ''
    OR d.department_name_en ILIKE '%' || p_search || '%'
    OR d.department_name_ar ILIKE '%' || p_search || '%'
  ORDER BY d.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200))
  OFFSET (GREATEST(1, p_page) - 1) * GREATEST(1, LEAST(p_limit, 200));
$$;


--
-- Name: get_hr_dropdown_options(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hr_dropdown_options() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT json_build_object(
    'branches', (
      SELECT json_agg(json_build_object(
        'id', id,
        'name_en', name_en,
        'name_ar', name_ar,
        'location_en', location_en,
        'location_ar', location_ar
      ) ORDER BY name_en)
      FROM branches
      WHERE is_active = true
    ),
    'positions', (
      SELECT json_agg(json_build_object(
        'id', id,
        'title_en', position_title_en,
        'title_ar', position_title_ar,
        'department_id', department_id,
        'level_id', level_id
      ) ORDER BY position_title_en)
      FROM hr_positions
      WHERE is_active = true
    ),
    'departments', (
      SELECT json_agg(json_build_object(
        'id', id,
        'name_en', department_name_en,
        'name_ar', department_name_ar
      ) ORDER BY department_name_en)
      FROM hr_departments
      WHERE is_active = true
    ),
    'levels', (
      SELECT json_agg(json_build_object(
        'id', id,
        'name_en', level_name_en,
        'name_ar', level_name_ar,
        'order', level_order
      ) ORDER BY level_order)
      FROM hr_levels
      WHERE is_active = true
    ),
    'employment_statuses', (
      SELECT COALESCE(json_agg(s ORDER BY s), '[]'::json)
      FROM (
        SELECT DISTINCT employment_status AS s
        FROM hr_employee_master
--

--
-- Name: get_hr_employee_applicability(integer, integer, text, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hr_employee_applicability(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_name_search text DEFAULT NULL::text, p_nationality_id text DEFAULT NULL::text, p_ticket_enabled boolean DEFAULT NULL::boolean, p_leave_enabled boolean DEFAULT NULL::boolean) RETURNS TABLE(applicability_id bigint, employee_id text, employee_name_en text, employee_name_ar text, nationality_id text, nationality_name_en text, nationality_name_ar text, sponsorship_status boolean, join_date date, employment_status text, ticket_rule_id bigint, ticket_rule_enabled boolean, ticket_rule_name_en text, ticket_rule_name_ar text, qualified_ticket_count integer, ticket_periods_count integer, leave_salary_rule_id bigint, leave_salary_rule_enabled boolean, leave_rule_name_en text, leave_rule_name_ar text, qualified_leave_days integer, leave_periods_count integer, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    WITH base AS (
        SELECT
            a.id AS applicability_id,
            e.id::text AS employee_id,
            e.name_en::text AS employee_name_en,
            e.name_ar::text AS employee_name_ar,
            e.nationality_id::text AS nationality_id,
            n.name_en::text AS nationality_name_en,
            n.name_ar::text AS nationality_name_ar,
            e.sponsorship_status,
            e.join_date,
            e.employment_status::text AS employment_status,
            COALESCE(tp.rule_id, a.ticket_rule_id) AS ticket_rule_id,
            CASE WHEN tp.rule_id IS NOT NULL THEN true ELSE COALESCE(a.ticket_rule_enabled, false) END AS ticket_rule_enabled,
            COALESCE(tp.rule_name_en, tr.rule_name_en)::text AS ticket_rule_name_en,
            COALESCE(tp.rule_name_ar, tr.rule_name_ar)::text AS ticket_rule_name_ar,
            a.qualified_ticket_count,
            (
                SELECT COUNT(*)::integer
                FROM public.hr_employee_applicability_rule_periods p
                WHERE p.employee_id = e.id
                    AND p.rule_type = 'ticket'
            ) AS ticket_periods_count,
            COALESCE(lp.rule_id, a.leave_salary_rule_id) AS leave_salary_rule_id,
            CASE WHEN lp.rule_id IS NOT NULL THEN true ELSE COALESCE(a.leave_salary_rule_enabled, false) END AS leave_salary_rule_enabled,
            COALESCE(lp.rule_name_en, lr.rule_name_en)::text AS leave_rule_name_en,
            COALESCE(lp.rule_name_ar, lr.rule_name_ar)::text AS leave_rule_name_ar,
            a.qualified_leave_days,
            (
                SELECT COUNT(*)::integer
                FROM public.hr_employee_applicability_rule_periods p
                WHERE p.employee_id = e.id
                    AND p.rule_type = 'leave_salary'
            ) AS leave_periods_count
        FROM public.hr_employee_master e
        LEFT JOIN public.hr_employee_settlement_applicability a
            ON a.employee_id = e.id
        LEFT JOIN public.nationalities n
            ON n.id = e.nationality_id
        LEFT JOIN public.settlement_rules tr
            ON tr.id = a.ticket_rule_id
        LEFT JOIN public.settlement_rules lr
            ON lr.id = a.leave_salary_rule_id
        LEFT JOIN LATERAL (
            SELECT
                p.rule_id,
                r.rule_name_en,
--

--
-- Name: get_hr_employee_qualification_usage(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hr_employee_qualification_usage(p_employee_ids text[]) RETURNS TABLE(employee_id text, ticket_issued_count integer, leave_approved_days integer, leave_paid_days integer)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    WITH employees AS (
        SELECT DISTINCT e_id::text AS employee_id
        FROM unnest(COALESCE(p_employee_ids, ARRAY[]::text[])) AS e_id
        WHERE e_id IS NOT NULL AND btrim(e_id) <> ''
    ),
    active_ticket_period AS (
        SELECT DISTINCT ON (p.employee_id)
            p.employee_id,
            p.effective_from,
            p.effective_to,
            p.is_infinite
        FROM public.hr_employee_applicability_rule_periods p
        JOIN employees e ON e.employee_id = p.employee_id
        WHERE p.rule_type = 'ticket'
            AND p.effective_from <= CURRENT_DATE
            AND (p.is_infinite = true OR p.effective_to >= CURRENT_DATE)
        ORDER BY p.employee_id, p.effective_from DESC
    ),
    active_leave_period AS (
        SELECT DISTINCT ON (p.employee_id)
            p.employee_id,
            p.effective_from,
            p.effective_to,
            p.is_infinite
        FROM public.hr_employee_applicability_rule_periods p
        JOIN employees e ON e.employee_id = p.employee_id
        WHERE p.rule_type = 'leave_salary'
            AND p.effective_from <= CURRENT_DATE
            AND (p.is_infinite = true OR p.effective_to >= CURRENT_DATE)
        ORDER BY p.employee_id, p.effective_from DESC
    ),
    ticket_usage AS (
        SELECT
            e.employee_id,
            COALESCE(SUM(t.ticket_count), 0)::integer AS ticket_issued_count
        FROM employees e
        LEFT JOIN active_ticket_period ap ON ap.employee_id = e.employee_id
        LEFT JOIN public.hr_employee_ticket_issuances t
            ON t.employee_id = e.employee_id
            AND ap.employee_id IS NOT NULL
            AND t.issuance_date >= ap.effective_from
            AND (ap.is_infinite = true OR t.issuance_date <= ap.effective_to)
        GROUP BY e.employee_id
    ),
    leave_usage AS (
        SELECT
            e.employee_id,
--

--
-- Name: get_hr_employee_rule_periods(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hr_employee_rule_periods(p_employee_id text, p_rule_type text) RETURNS TABLE(id bigint, sequence_no integer, rule_id bigint, rule_name_en text, rule_name_ar text, duration_years integer, duration_months integer, effective_from date, effective_to date, is_infinite boolean)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT
        p.id,
        p.sequence_no,
        p.rule_id,
        r.rule_name_en::text,
        r.rule_name_ar::text,
        p.duration_years,
        p.duration_months,
        p.effective_from,
        p.effective_to,
        p.is_infinite
    FROM public.hr_employee_applicability_rule_periods p
    JOIN public.settlement_rules r
        ON r.id = p.rule_id
    WHERE p.employee_id = p_employee_id
        AND p.rule_type = p_rule_type
    ORDER BY p.sequence_no ASC;
$$;


--
-- Name: get_hr_levels_list(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hr_levels_list(p_search text DEFAULT ''::text, p_page integer DEFAULT 1, p_limit integer DEFAULT 50) RETURNS TABLE(id uuid, level_name_en character varying, level_name_ar character varying, level_order integer, is_active boolean, created_at timestamp with time zone, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    l.id,
    l.level_name_en,
    l.level_name_ar,
    l.level_order,
    l.is_active,
    l.created_at,
    COUNT(*) OVER() AS total_count
  FROM hr_levels l
  WHERE
    COALESCE(p_search, '') = ''
    OR l.level_name_en ILIKE '%' || p_search || '%'
    OR l.level_name_ar ILIKE '%' || p_search || '%'
  ORDER BY l.level_order ASC, l.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200))
  OFFSET (GREATEST(1, p_page) - 1) * GREATEST(1, LEAST(p_limit, 200));
$$;


--
-- Name: get_hr_positions_list(text, integer, integer, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hr_positions_list(p_search text DEFAULT ''::text, p_page integer DEFAULT 1, p_limit integer DEFAULT 50, p_department_id uuid DEFAULT NULL::uuid, p_level_id uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, position_title_en character varying, position_title_ar character varying, department_id uuid, department_name_en character varying, department_name_ar character varying, level_id uuid, level_name_en character varying, level_name_ar character varying, is_active boolean, created_at timestamp with time zone, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    p.id,
    p.position_title_en,
    p.position_title_ar,
    p.department_id,
    d.department_name_en,
    d.department_name_ar,
    p.level_id,
    l.level_name_en,
    l.level_name_ar,
    p.is_active,
    p.created_at,
    COUNT(*) OVER() AS total_count
  FROM hr_positions p
  LEFT JOIN hr_departments d ON d.id = p.department_id
  LEFT JOIN hr_levels l ON l.id = p.level_id
  WHERE
    (COALESCE(p_search, '') = ''
      OR p.position_title_en ILIKE '%' || p_search || '%'
      OR p.position_title_ar ILIKE '%' || p_search || '%'
      OR d.department_name_en ILIKE '%' || p_search || '%'
      OR d.department_name_ar ILIKE '%' || p_search || '%')
    AND (p_department_id IS NULL OR p.department_id = p_department_id)
    AND (p_level_id IS NULL OR p.level_id = p_level_id)
  ORDER BY p.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200))
  OFFSET (GREATEST(1, p_page) - 1) * GREATEST(1, LEAST(p_limit, 200));
$$;


--
-- Name: get_hr_salary_notes(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hr_salary_notes(p_employee_id text) RETURNS TABLE(id uuid, employee_id text, note_type text, note_text text, from_date date, to_date date, until_date date, created_by uuid, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT id, employee_id, note_type, note_text,
           from_date, to_date, until_date, created_by, created_at, updated_at
    FROM public.hr_salary_notes
    WHERE employee_id = p_employee_id
    ORDER BY created_at DESC;
$$;


--
-- Name: get_incident_manager_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_incident_manager_data() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_agg(incident_row ORDER BY 
        CASE WHEN (incident_row->>'resolution_status') = 'resolved' THEN 1 ELSE 0 END ASC,
        (incident_row->>'created_at') DESC)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', i.id,
            'incident_type_id', i.incident_type_id,
            'employee_id', i.employee_id,
            'branch_id', i.branch_id,
            'violation_id', i.violation_id,
            'what_happened', i.what_happened,
            'witness_details', i.witness_details,
            'report_type', i.report_type,
            'reports_to_user_ids', i.reports_to_user_ids,
            'resolution_status', i.resolution_status::TEXT,
            'resolution_report', i.resolution_report,
            'user_statuses', i.user_statuses,
            'attachments', i.attachments,
            'investigation_report', i.investigation_report,
            'created_at', i.created_at,
            'created_by', i.created_by,
            -- Joined incident type
            'incident_types', CASE WHEN it.id IS NOT NULL THEN jsonb_build_object(
                'id', it.id,
                'incident_type_en', it.incident_type_en,
                'incident_type_ar', it.incident_type_ar
            ) ELSE NULL END,
            -- Joined warning violation
            'warning_violation', CASE WHEN wv.id IS NOT NULL THEN jsonb_build_object(
                'id', wv.id,
                'name_en', wv.name_en,
                'name_ar', wv.name_ar
            ) ELSE NULL END,
            -- Employee name (from hr_employee_master by employee_id = id)
            'employee_name_en', emp.name_en,
            'employee_name_ar', emp.name_ar,
            -- Branch info
            'branch_name_en', b.name_en,
            'branch_name_ar', b.name_ar,
            'branch_location_en', b.location_en,
            'branch_location_ar', b.location_ar,
            -- Reporter name (from hr_employee_master by user_id = created_by)
            'reporter_name_en', reporter.name_en,
            'reporter_name_ar', reporter.name_ar,
--

--
-- Name: get_incomplete_receiving_tasks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_incomplete_receiving_tasks() RETURNS TABLE(id uuid, receiving_record_id uuid, template_id uuid, role_type character varying, title text, description text, priority character varying, task_status character varying, task_completed boolean, due_date timestamp with time zone, assigned_user_id uuid, completed_at timestamp with time zone, completed_by_user_id uuid, clearance_certificate_url text, created_at timestamp with time zone, bill_number character varying, bill_amount numeric, vendor_name text, branch_name text, assigned_user_name text, is_overdue boolean, days_until_due integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rt.id,
    rt.receiving_record_id,
    rt.template_id,
    rt.role_type,
    rt.title,
    rt.description,
    rt.priority,
    rt.task_status,
    rt.task_completed,
    rt.due_date,
    rt.assigned_user_id,
    rt.completed_at,
    rt.completed_by_user_id,
    rt.clearance_certificate_url,
    rt.created_at,
    rr.bill_number,
    rr.bill_amount,
    v.vendor_name,
    b.name_en as branch_name,
    u1.username as assigned_user_name,
    (rt.due_date < NOW() AND rt.task_status != 'completed') as is_overdue,
    EXTRACT(DAY FROM (rt.due_date - NOW()))::INTEGER as days_until_due
  FROM receiving_tasks rt
  LEFT JOIN receiving_records rr ON rr.id = rt.receiving_record_id
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  LEFT JOIN users u1 ON u1.id = rt.assigned_user_id
  WHERE rt.task_completed = false AND rt.task_status != 'completed'
  ORDER BY rt.due_date ASC, rt.priority DESC;
END;
$$;


--
-- Name: get_incomplete_receiving_tasks_breakdown(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_incomplete_receiving_tasks_breakdown() RETURNS TABLE(total_receiving_tasks integer, incomplete_receiving_tasks integer, missing_task_completions integer, incomplete_task_completions integer, tasks_not_completed integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            COUNT(*) as total_tasks,
            COUNT(CASE WHEN rt.task_completed = false OR t.status != 'completed' THEN 1 END) as incomplete_tasks,
            COUNT(CASE WHEN tc.id IS NULL THEN 1 END) as missing_completions,
            COUNT(CASE WHEN tc.id IS NOT NULL AND tc.task_finished_completed = false THEN 1 END) as incomplete_completions,
            COUNT(CASE WHEN t.status != 'completed' THEN 1 END) as tasks_not_completed
        FROM receiving_tasks rt
        LEFT JOIN tasks t ON rt.task_id = t.id
        LEFT JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
    )
    SELECT 
        s.total_tasks::INTEGER,
        s.incomplete_tasks::INTEGER,
        s.missing_completions::INTEGER,
        s.incomplete_completions::INTEGER,
        s.tasks_not_completed::INTEGER
    FROM stats s;
END;
$$;


--
-- Name: get_incomplete_tasks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_incomplete_tasks() RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'tasks', COALESCE(tasks_arr, '[]'::json),
    'total_count', COALESCE(json_array_length(tasks_arr), 0)
  ) INTO v_result
  FROM (
    SELECT json_agg(row_to_json(t) ORDER BY t.assigned_date DESC) as tasks_arr
    FROM (
      -- Task Assignments (incomplete)
      SELECT
        ta.id,
        'regular' as task_type,
        COALESCE(tk.title, 'Task Assignment #' || LEFT(ta.id::text, 8)) as task_title,
        COALESCE(tk.description, '') as task_description,
        ta.status,
        COALESCE(ta.priority_override, tk.priority, 'medium') as priority,
        COALESCE(b.name_en, 'No Branch') as branch_name,
        COALESCE(b.name_ar, b.name_en, 'No Branch') as branch_name_ar,
        ta.assigned_to_branch_id as branch_id,
        COALESCE(u_to.username, 'Unassigned') as assigned_to_name,
        COALESCE(e_to.name_en, u_to.username, 'Unassigned') as assigned_to_name_en,
        COALESCE(e_to.name_ar, e_to.name_en, u_to.username, 'Unassigned') as assigned_to_name_ar,
        ta.assigned_to_user_id,
        COALESCE(u_by.username, 'System') as assigned_by_name,
        ta.assigned_at as assigned_date,
        COALESCE(ta.deadline_datetime::text, ta.deadline_date::text) as deadline,
        ta.notes
      FROM task_assignments ta
      LEFT JOIN tasks tk ON tk.id = ta.task_id
      LEFT JOIN branches b ON b.id = ta.assigned_to_branch_id
      LEFT JOIN users u_to ON u_to.id = ta.assigned_to_user_id
      LEFT JOIN users u_by ON u_by.id = ta.assigned_by
      LEFT JOIN hr_employee_master e_to ON e_to.user_id = ta.assigned_to_user_id
      WHERE ta.status NOT IN ('completed', 'cancelled')

      UNION ALL

      -- Quick Task Assignments (incomplete)
      SELECT
        qta.id,
        'quick' as task_type,
        COALESCE(qt.title, 'Quick Task #' || LEFT(qta.id::text, 8)) as task_title,
        COALESCE(qt.description, '') as task_description,
        qta.status,
        COALESCE(qt.priority, 'medium') as priority,
        COALESCE(b.name_en, 'No Branch') as branch_name,
--

--
-- Name: get_issue_pv_vouchers(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_issue_pv_vouchers(p_pv_id text DEFAULT NULL::text, p_serial_number bigint DEFAULT NULL::bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  result jsonb;
BEGIN
  IF p_pv_id IS NULL AND p_serial_number IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
  INTO result
  FROM (
    SELECT
      pvi.id,
      pvi.purchase_voucher_id,
      pvi.serial_number,
      pvi.value,
      pvi.stock,
      pvi.status,
      pvi.issue_type,
      pvi.stock_location,
      pvi.stock_person,
      COALESCE(b.name_en || ' - ' || b.location_en, '') as stock_location_name,
      COALESCE(
        u.username || ' - ' || emp.name_en,
        u.username,
        ''
      ) as stock_person_name
    FROM purchase_voucher_items pvi
    LEFT JOIN branches b ON b.id = pvi.stock_location
    LEFT JOIN users u ON u.id = pvi.stock_person
    LEFT JOIN hr_employee_master emp ON emp.id = u.employee_id::text
    WHERE pvi.issue_type = 'not issued'
      AND (p_pv_id IS NULL OR pvi.purchase_voucher_id = p_pv_id)
      AND (p_serial_number IS NULL OR pvi.serial_number = p_serial_number)
    ORDER BY pvi.serial_number
  ) t;

  RETURN result;
END;
$$;


--
-- Name: get_latest_frontend_build(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_latest_frontend_build() RETURNS TABLE(id integer, version text, file_name text, file_size bigint, storage_path text, notes text, created_at timestamp with time zone, download_url text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT 
        fb.id,
        fb.version,
        fb.file_name,
        fb.file_size,
        fb.storage_path,
        fb.notes,
        fb.created_at,
        '/storage/v1/object/public/frontend-builds/' || fb.storage_path as download_url
    FROM public.frontend_builds fb
    ORDER BY fb.created_at DESC
    LIMIT 1;
$$;


--
-- Name: get_lease_rent_properties_with_spaces(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_lease_rent_properties_with_spaces() RETURNS TABLE(property_id uuid, property_name_en character varying, property_name_ar character varying, property_location_en character varying, property_location_ar character varying, property_is_leased boolean, property_is_rented boolean, space_id uuid, space_number character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id AS property_id,
        p.name_en AS property_name_en,
        p.name_ar AS property_name_ar,
        p.location_en AS property_location_en,
        p.location_ar AS property_location_ar,
        p.is_leased AS property_is_leased,
        p.is_rented AS property_is_rented,
        s.id AS space_id,
        s.space_number AS space_number
    FROM lease_rent_properties p
    LEFT JOIN lease_rent_property_spaces s ON s.property_id = p.id
    ORDER BY p.name_en, s.space_number;
END;
$$;


--
-- Name: get_lease_rent_tab_data(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_lease_rent_tab_data(p_party_type text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    parties_json JSON;
    changes_json JSON;
BEGIN
    IF p_party_type = 'lease' THEN
        SELECT COALESCE(json_agg(sub ORDER BY sub.party_name_en), '[]'::json) INTO parties_json
        FROM (
            SELECT lp.*,
                json_build_object('name_en', prop.name_en, 'name_ar', prop.name_ar) as property,
                json_build_object('space_number', sp.space_number) as space
            FROM lease_rent_lease_parties lp
            LEFT JOIN lease_rent_properties prop ON prop.id = lp.property_id
            LEFT JOIN lease_rent_property_spaces sp ON sp.id = lp.property_space_id
        ) sub;
    ELSIF p_party_type = 'rent' THEN
        SELECT COALESCE(json_agg(sub ORDER BY sub.party_name_en), '[]'::json) INTO parties_json
        FROM (
            SELECT rp.*,
                json_build_object('name_en', prop.name_en, 'name_ar', prop.name_ar) as property,
                json_build_object('space_number', sp.space_number) as space
            FROM lease_rent_rent_parties rp
            LEFT JOIN lease_rent_properties prop ON prop.id = rp.property_id
            LEFT JOIN lease_rent_property_spaces sp ON sp.id = rp.property_space_id
        ) sub;
    ELSE
        parties_json := '[]'::json;
    END IF;
    SELECT COALESCE(json_agg(c ORDER BY c.created_at DESC), '[]'::json) INTO changes_json
    FROM lease_rent_special_changes c
    WHERE c.party_type = p_party_type;
    RETURN json_build_object('parties', parties_json, 'changes', changes_json);
END;
$$;


--
-- Name: get_loyalty_customer_bills(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_loyalty_customer_bills(p_search text DEFAULT ''::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, whatsapp_number text, customer_id uuid, employee_id text, erp_branch_id text, bill_date date, bill_time time without time zone, bill_number text, bill_gross_total numeric, bill_net_total numeric, points_earned numeric, created_at timestamp with time zone, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT
        id,
        whatsapp_number,
        customer_id,
        employee_id,
        erp_branch_id,
        bill_date,
        bill_time,
        bill_number,
        bill_gross_total,
        bill_net_total,
        points_earned,
        created_at,
        COUNT(*) OVER() AS total_count
    FROM public.loyalty_customer_bills
    WHERE (
        p_search = '' OR
        whatsapp_number              ILIKE '%' || p_search || '%' OR
        customer_id::text            ILIKE '%' || p_search || '%' OR
        COALESCE(employee_id, '')    ILIKE '%' || p_search || '%' OR
        COALESCE(erp_branch_id, '')  ILIKE '%' || p_search || '%' OR
        COALESCE(bill_number, '')    ILIKE '%' || p_search || '%' OR
        bill_date::text              ILIKE '%' || p_search || '%'
    )
    ORDER BY bill_date DESC, bill_time DESC
    LIMIT  p_limit
    OFFSET p_offset;
$$;


--
-- Name: get_loyalty_tier_for_customer(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_loyalty_tier_for_customer(p_whatsapp text) RETURNS TABLE(tier_id uuid, tier_name text, tier_color text, points_percentage numeric, ecash_start_from numeric, lifetime_total numeric)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    WITH lifetime AS (
        SELECT COALESCE(SUM(bill_amount), 0) AS total
        FROM loyalty_customer_bills
        WHERE whatsapp_number = p_whatsapp
    )
    SELECT
        t.id,
        t.name,
        t.color,
        t.points_percentage,
        t.ecash_start_from,
        l.total
    FROM loyalty_tiers t
    CROSS JOIN lifetime l
    WHERE t.is_active = true
      AND t.total_purchase_from <= l.total
      AND (t.total_purchase_to IS NULL OR t.total_purchase_to >= l.total)
    ORDER BY t.sort_order DESC
    LIMIT 1;
$$;


--
-- Name: get_mobile_dashboard_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_mobile_dashboard_data(p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_employee_id TEXT;
    v_employee_branch_id INTEGER;
    v_employee_id_mapping JSONB;
    v_all_employee_codes TEXT[];
    v_today TEXT;
    v_yesterday TEXT;
    v_today_weekday INTEGER;
    v_yesterday_weekday INTEGER;
    v_attendance_today JSONB;
    v_attendance_yesterday JSONB;
    v_shift_info JSONB;
    v_yesterday_shift_info JSONB;
    v_punches JSONB;
    v_box_pending_close INTEGER;
    v_box_completed INTEGER;
    v_box_in_use INTEGER;
    v_checklist_assignments JSONB;
    v_checklist_submissions JSONB;
    v_pending_tasks INTEGER;
    v_key TEXT;
    v_val TEXT;
    -- Break totals
    v_break_total_today INTEGER;
    v_break_total_yesterday INTEGER;
    v_shift_start TEXT;
    v_shift_end TEXT;
    v_shift_overlapping BOOLEAN;
    v_window_start TIMESTAMPTZ;
    v_window_end TIMESTAMPTZ;
BEGIN
    -- 1. Get employee record
    SELECT id, current_branch_id, employee_id_mapping
    INTO v_employee_id, v_employee_branch_id, v_employee_id_mapping
    FROM hr_employee_master
    WHERE user_id = p_user_id
    LIMIT 1;

    IF v_employee_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Employee record not found');
    END IF;

    -- Extract all employee codes from mapping
    IF v_employee_id_mapping IS NOT NULL THEN
        SELECT array_agg(value::TEXT)
        INTO v_all_employee_codes
        FROM jsonb_each_text(v_employee_id_mapping);
    END IF;
--

--
-- Name: get_my_assignments(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_assignments(p_user_id uuid, p_limit integer DEFAULT 500) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'tasks', COALESCE(tasks_arr, '[]'::json),
    'total_count', COALESCE(json_array_length(tasks_arr), 0)
  ) INTO v_result
  FROM (
    SELECT json_agg(row_to_json(t)) as tasks_arr
    FROM (
      SELECT * FROM (
      -- Regular Task Assignments (assigned by this user)
      SELECT
        ta.id,
        'regular' as task_type,
        COALESCE(tk.title, 'Task #' || LEFT(ta.id::text, 8)) as task_title,
        COALESCE(tk.description, '') as task_description,
        ta.status,
        COALESCE(ta.priority_override, tk.priority, 'medium') as priority,
        COALESCE(b.name_en, 'No Branch') as branch_name,
        COALESCE(b.name_ar, b.name_en, 'No Branch') as branch_name_ar,
        ta.assigned_to_branch_id as branch_id,
        COALESCE(u_to.username, 'Unassigned') as assigned_to_name,
        COALESCE(e_to.name_en, u_to.username, 'Unassigned') as assigned_to_name_en,
        COALESCE(e_to.name_ar, e_to.name_en, u_to.username, 'Unassigned') as assigned_to_name_ar,
        ta.assigned_to_user_id,
        COALESCE(u_by.username, 'System') as assigned_by_name,
        ta.assigned_by as assigned_by_id,
        ta.assigned_at as assigned_date,
        COALESCE(ta.deadline_datetime::text, ta.deadline_date::text) as deadline,
        ta.completed_at as completed_date,
        ta.notes,
        CASE WHEN ta.status = 'completed' AND ta.completed_at IS NOT NULL AND ta.assigned_at IS NOT NULL
          THEN ROUND(EXTRACT(EPOCH FROM (ta.completed_at - ta.assigned_at)) / 3600, 1)
          ELSE NULL
        END as completion_hours,
        NULL as price_tag,
        NULL as issue_type
      FROM task_assignments ta
      LEFT JOIN tasks tk ON tk.id = ta.task_id
      LEFT JOIN branches b ON b.id = ta.assigned_to_branch_id
      LEFT JOIN users u_to ON u_to.id = ta.assigned_to_user_id
      LEFT JOIN users u_by ON u_by.id = ta.assigned_by
      LEFT JOIN hr_employee_master e_to ON e_to.user_id = ta.assigned_to_user_id
      WHERE ta.assigned_by = p_user_id

      UNION ALL

--

--
-- Name: get_my_closed_boxes(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_closed_boxes(p_user_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_total_count bigint;
  v_boxes json;
  v_cutoff timestamptz;
BEGIN
  -- 35 days back at midnight Riyadh time (UTC+3)
  v_cutoff := (now() AT TIME ZONE 'Asia/Riyadh')::date - interval '35 days';
  v_cutoff := v_cutoff AT TIME ZONE 'Asia/Riyadh';

  -- Total completed count (all time)
  SELECT COUNT(*)
    INTO v_total_count
    FROM box_operations
   WHERE user_id = p_user_id
     AND status = 'completed';

  -- Last 35 days detail rows with branch info
  SELECT json_agg(row_order)
    INTO v_boxes
    FROM (
      SELECT
        bo.id,
        bo.box_number,
        bo.branch_id,
        bo.start_time,
        bo.end_time,
        bo.status,
        bo.closing_details,
        bo.complete_details,
        bo.completed_by_name,
        json_build_object(
          'id',          b.id,
          'name_en',     b.name_en,
          'name_ar',     b.name_ar,
          'location_en', b.location_en,
          'location_ar', b.location_ar
        ) AS branches
      FROM box_operations bo
      LEFT JOIN branches b ON b.id = bo.branch_id
      WHERE bo.user_id = p_user_id
        AND bo.status = 'completed'
        AND bo.end_time >= v_cutoff
      ORDER BY bo.end_time DESC
    ) row_order;

  RETURN json_build_object(
    'total_count', v_total_count,
--

--
-- Name: get_my_tasks(uuid, boolean, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_tasks(p_user_id uuid, p_include_completed boolean DEFAULT false, p_limit integer DEFAULT 500) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'tasks', COALESCE(tasks_arr, '[]'::json),
    'total_count', COALESCE(json_array_length(tasks_arr), 0)
  ) INTO v_result
  FROM (
    SELECT json_agg(row_to_json(t)) as tasks_arr
    FROM (
      SELECT * FROM (
      -- Regular Task Assignments (assigned TO this user)
      SELECT
        ta.task_id as id,
        'regular' as task_type,
        COALESCE(tk.title, 'Task #' || LEFT(ta.id::text, 8)) as title,
        COALESCE(tk.description, '') as description,
        COALESCE(ta.priority_override, tk.priority, 'medium') as priority,
        COALESCE(tk.status, 'pending') as status,
        ta.status as assignment_status,
        ta.id as assignment_id,
        ta.assigned_at,
        COALESCE(ta.deadline_datetime::text, ta.deadline_date::text) as deadline_datetime,
        ta.assigned_by,
        COALESCE(u_by.username, 'Unknown') as assigned_by_name,
        ta.assigned_to_user_id,
        COALESCE(b.name_en, 'No Branch') as branch_name,
        COALESCE(b.name_ar, b.name_en, 'No Branch') as branch_name_ar,
        COALESCE(e_to.name_en, u_to.username, 'You') as assigned_to_name_en,
        COALESCE(e_to.name_ar, e_to.name_en, u_to.username, '╪ú┘å╪¬') as assigned_to_name_ar,
        tk.created_at,
        -- Completion requirements
        false as require_task_finished,
        false as require_photo_upload,
        false as require_erp_reference,
        -- Quick task extras
        NULL::text as issue_type,
        NULL::text as incident_id,
        NULL::uuid as product_request_id,
        NULL::text as product_request_type,
        NULL::text as price_tag,
        -- Receiving extras
        NULL::text as role_type,
        NULL::uuid as receiving_record_id,
        NULL::text as clearance_certificate_url,
        ta.completed_at
      FROM task_assignments ta
      LEFT JOIN tasks tk ON tk.id = ta.task_id
--

--
-- Name: get_next_delivery_tier(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_next_delivery_tier(current_amount numeric) RETURNS TABLE(next_tier_min_amount numeric, next_tier_delivery_fee numeric, amount_needed numeric, potential_savings numeric, description_en text, description_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    current_fee numeric;
BEGIN
    -- Get current delivery fee
    current_fee := public.get_delivery_fee_for_amount(current_amount);
    
    -- Find next better tier
    RETURN QUERY
    SELECT 
        t.min_order_amount,
        t.delivery_fee,
        (t.min_order_amount - current_amount) as amount_needed,
        (current_fee - t.delivery_fee) as potential_savings,
        t.description_en,
        t.description_ar
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND t.min_order_amount > current_amount
      AND t.delivery_fee < current_fee
    ORDER BY t.min_order_amount ASC
    LIMIT 1;
END;
$$;


--
-- Name: FUNCTION get_next_delivery_tier(current_amount numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_next_delivery_tier(current_amount numeric) IS 'Get the next tier that would reduce delivery fee with amount needed to reach it';


--
-- Name: get_next_delivery_tier_by_branch(bigint, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_next_delivery_tier_by_branch(p_branch_id bigint, p_current_amount numeric) RETURNS TABLE(next_tier_min_amount numeric, next_tier_delivery_fee numeric, amount_needed numeric, potential_savings numeric, description_en text, description_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_current_fee numeric;
BEGIN
    -- Require branch id
    IF p_branch_id IS NULL THEN
        RETURN; -- empty set
    END IF;

    v_current_fee := public.get_delivery_fee_for_amount_by_branch(p_branch_id, p_current_amount);

    RETURN QUERY
    SELECT 
        t.min_order_amount,
        t.delivery_fee,
        (t.min_order_amount - p_current_amount) AS amount_needed,
        (v_current_fee - t.delivery_fee) AS potential_savings,
        t.description_en,
        t.description_ar
    FROM public.delivery_fee_tiers t
    WHERE t.is_active = true
      AND t.branch_id = p_branch_id
      AND t.min_order_amount > p_current_amount
      AND t.delivery_fee < v_current_fee
    ORDER BY t.min_order_amount ASC
    LIMIT 1;
END;
$$;


--
-- Name: FUNCTION get_next_delivery_tier_by_branch(p_branch_id bigint, p_current_amount numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_next_delivery_tier_by_branch(p_branch_id bigint, p_current_amount numeric) IS 'Get next tier for branch reducing delivery fee with savings info';


--
-- Name: get_next_product_serial(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_next_product_serial() RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE
    next_number INTEGER;
    next_serial TEXT;
BEGIN
    -- Get the highest serial number
    SELECT COALESCE(
        MAX(CAST(SUBSTRING(product_serial FROM 3) AS INTEGER)),
        0
    ) + 1 INTO next_number
    FROM products
    WHERE product_serial ~ '^UR[0-9]+$';
    
    -- Format as UR0001, UR0002, etc.
    next_serial := 'UR' || LPAD(next_number::TEXT, 4, '0');
    
    RETURN next_serial;
END;
$_$;


--
-- Name: get_offer_products_data(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_offer_products_data(p_exclude_offer_id integer DEFAULT 0) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'products', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id', p.id,
          'name_ar', p.product_name_ar,
          'name_en', p.product_name_en,
          'barcode', p.barcode,
          'product_serial', COALESCE(p.barcode, ''),
          'price', COALESCE(p.sale_price, 0),
          'cost', COALESCE(p.cost, 0),
          'unit_name_en', COALESCE(u.name_en, ''),
          'unit_name_ar', COALESCE(u.name_ar, ''),
          'unit_qty', COALESCE(p.unit_qty, 1),
          'image_url', p.image_url,
          'stock', COALESCE(p.current_stock, 0),
          'minim_qty', 1
        ) ORDER BY p.barcode
      ), '[]'::json)
      FROM products p
      LEFT JOIN product_units u ON u.id = p.unit_id
      WHERE p.is_active = true
        AND p.is_customer_product = true
    ),
    'products_in_other_offers', (
      SELECT COALESCE(json_agg(DISTINCT pid), '[]'::json)
      FROM (
        -- Products in offer_products (percentage, fixed price offers)
        SELECT op.product_id AS pid
        FROM offer_products op
        JOIN offers o ON o.id = op.offer_id
        WHERE o.is_active = true
          AND o.end_date >= NOW()
          AND o.id != p_exclude_offer_id

        UNION

        -- Products in BOGO offers (buy product)
        SELECT bor.buy_product_id AS pid
        FROM bogo_offer_rules bor
        JOIN offers o ON o.id = bor.offer_id
        WHERE o.is_active = true
          AND o.end_date >= NOW()
          AND o.id != p_exclude_offer_id

--

--
-- Name: get_offer_variation_summary(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_offer_variation_summary(p_offer_id integer) RETURNS TABLE(variation_group_id uuid, parent_barcode text, group_name_en text, group_name_ar text, selected_count integer, total_count integer, has_price_mismatch boolean)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  WITH variation_groups AS (
    SELECT DISTINCT 
      op.variation_group_id,
      op.variation_parent_barcode
    FROM offer_products op
    WHERE op.offer_id = p_offer_id
      AND op.is_part_of_variation_group = true
      AND op.variation_group_id IS NOT NULL
  ),
  selected_variations AS (
    SELECT 
      op.variation_group_id,
      COUNT(DISTINCT op.product_id) as selected_count,
      COUNT(DISTINCT op.offer_price) as price_count,
      COUNT(DISTINCT op.offer_percentage) as percentage_count
    FROM offer_products op
    WHERE op.offer_id = p_offer_id
      AND op.variation_group_id IS NOT NULL
    GROUP BY op.variation_group_id
  ),
  total_variations AS (
    SELECT 
      vg.variation_group_id,
      COUNT(DISTINCT p.id) as total_count
    FROM variation_groups vg
    JOIN products p ON p.parent_product_barcode = vg.variation_parent_barcode
      OR p.barcode = vg.variation_parent_barcode
    WHERE p.is_variation = true
    GROUP BY vg.variation_group_id
  )
  SELECT 
    vg.variation_group_id,
    vg.variation_parent_barcode as parent_barcode,
    p.variation_group_name_en as group_name_en,
    p.variation_group_name_ar as group_name_ar,
    sv.selected_count::INTEGER,
    tv.total_count::INTEGER,
    CASE 
      WHEN sv.price_count > 1 OR sv.percentage_count > 1 THEN true
      ELSE false
    END as has_price_mismatch
  FROM variation_groups vg
  JOIN products p ON p.barcode = vg.variation_parent_barcode
  LEFT JOIN selected_variations sv ON sv.variation_group_id = vg.variation_group_id
  LEFT JOIN total_variations tv ON tv.variation_group_id = vg.variation_group_id
  ORDER BY p.variation_group_name_en;
--

--
-- Name: get_ongoing_quick_assignment_count(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_ongoing_quick_assignment_count(p_user_id uuid) RETURNS bigint
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT count(*)
  FROM quick_task_assignments qta
  INNER JOIN quick_tasks qt ON qt.id = qta.quick_task_id
  WHERE qt.assigned_by = p_user_id
    AND qta.status NOT IN ('completed', 'cancelled');
$$;


--
-- Name: get_or_create_app_function(text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_or_create_app_function(p_function_code text, p_function_name text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_category text DEFAULT 'Application'::text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    function_id UUID;
BEGIN
    -- Try to get existing function
    SELECT id INTO function_id 
    FROM app_functions 
    WHERE function_code = p_function_code;
    
    -- If not found, create it
    IF function_id IS NULL THEN
        function_id := register_app_function(
            COALESCE(p_function_name, initcap(replace(p_function_code, '_', ' '))),
            p_function_code,
            p_description,
            p_category
        );
    END IF;
    
    RETURN function_id;
END;
$$;


--
-- Name: get_overdue_tasks_without_reminders(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_overdue_tasks_without_reminders() RETURNS TABLE(assignment_id uuid, task_id uuid, task_title text, assigned_to_user_id uuid, user_name character varying, deadline timestamp with time zone, hours_overdue numeric)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ta.id as assignment_id,
    t.id as task_id,
    t.title as task_title,
    ta.assigned_to_user_id,
    u.username as user_name,
    COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) as deadline,
    EXTRACT(EPOCH FROM (NOW() - COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime))) / 3600 as hours_overdue
  FROM task_assignments ta
  JOIN tasks t ON t.id = ta.task_id
  JOIN users u ON u.id = ta.assigned_to_user_id
  LEFT JOIN task_completions tc ON tc.assignment_id = ta.id
  WHERE tc.id IS NULL  -- Not completed
    AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) IS NOT NULL  -- Has deadline
    AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW()  -- Overdue
    AND NOT EXISTS (  -- No reminder sent yet
      SELECT 1 FROM task_reminder_logs trl 
      WHERE trl.task_assignment_id = ta.id
    )
  ORDER BY hours_overdue DESC;
END;
$$;


--
-- Name: FUNCTION get_overdue_tasks_without_reminders(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_overdue_tasks_without_reminders() IS 'Returns overdue tasks that havent received reminders yet - used by Edge Function';


--
-- Name: get_paid_expense_payments(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_paid_expense_payments(p_date_from date, p_date_to date) RETURNS TABLE(id bigint, amount numeric, is_paid boolean, paid_date timestamp with time zone, status text, branch_id bigint, payment_method text, expense_category_name_en text, expense_category_name_ar text, description text, schedule_type text, due_date date, co_user_name text, created_by uuid, requisition_id bigint, requisition_number text, payment_reference character varying, creator_username text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    e.id, e.amount, e.is_paid, e.paid_date, e.status,
    e.branch_id, e.payment_method,
    e.expense_category_name_en, e.expense_category_name_ar,
    e.description, e.schedule_type, e.due_date,
    e.co_user_name, e.created_by,
    e.requisition_id, e.requisition_number,
    e.payment_reference,
    u.username AS creator_username
  FROM expense_scheduler e
  LEFT JOIN public.users u ON u.id = e.created_by
  WHERE e.is_paid = true
    AND e.due_date >= p_date_from
    AND e.due_date <= p_date_to
  ORDER BY e.due_date DESC;
$$;


--
-- Name: get_paid_vendor_payments(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_paid_vendor_payments(p_date_from date, p_date_to date) RETURNS TABLE(id uuid, bill_number character varying, vendor_name character varying, final_bill_amount numeric, bill_date date, branch_id integer, payment_method character varying, bank_name character varying, iban character varying, is_paid boolean, paid_date timestamp without time zone, due_date date, payment_reference character varying)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT
    v.id, v.bill_number, v.vendor_name, v.final_bill_amount,
    v.bill_date, v.branch_id, v.payment_method, v.bank_name, v.iban,
    v.is_paid, v.paid_date, v.due_date, v.payment_reference
  FROM vendor_payment_schedule v
  WHERE v.is_paid = true
    AND v.due_date >= p_date_from
    AND v.due_date <= p_date_to
  ORDER BY v.due_date DESC;
$$;


--
-- Name: get_party_payment_data(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_party_payment_data(p_party_type text, p_party_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN json_build_object(
        'changes', (
            SELECT COALESCE(json_agg(sub), '[]'::json)
            FROM (
                SELECT * FROM lease_rent_special_changes
                WHERE party_type = p_party_type AND party_id = p_party_id
                ORDER BY effective_from ASC
            ) sub
        ),
        'entries', (
            SELECT COALESCE(json_agg(sub), '[]'::json)
            FROM (
                SELECT * FROM lease_rent_payment_entries
                WHERE party_type = p_party_type AND party_id = p_party_id
                ORDER BY created_at ASC
            ) sub
        )
    );
END;
$$;


--
-- Name: get_po_requests_with_details(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_po_requests_with_details() RETURNS TABLE(id uuid, requester_user_id uuid, from_branch_id integer, target_user_id uuid, status character varying, items jsonb, document_url text, created_at timestamp with time zone, updated_at timestamp with time zone, requester_name_en text, requester_name_ar text, target_name_en text, target_name_ar text, branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.requester_user_id,
        r.from_branch_id,
        r.target_user_id,
        r.status,
        r.items,
        r.document_url,
        r.created_at,
        r.updated_at,
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        COALESCE(b.name_en, '')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, b.name_en, '')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, b.location_en, '')::TEXT AS branch_location_ar
    FROM product_request_po r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches b ON b.id = r.from_branch_id
    ORDER BY r.created_at DESC;
END;
$$;


--
-- Name: get_pos_report(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_pos_report(p_date_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_date_to timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(row_data ORDER BY (row_data->>'created_at') DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'id', bo.id,
      'box_number', bo.box_number,
      'branch_id', bo.branch_id,
      'user_id', bo.user_id,
      'total_difference', COALESCE(
        (bo.complete_details->>'total_difference')::numeric,
        bo.total_difference,
        0
      ),
      'created_at', bo.created_at,
      'branch_name_en', COALESCE(b.name_en, b.name_ar, 'N/A'),
      'branch_name_ar', COALESCE(b.name_ar, b.name_en, 'N/A'),
      'branch_location_en', COALESCE(b.location_en, b.location_ar, 'N/A'),
      'branch_location_ar', COALESCE(b.location_ar, b.location_en, 'N/A'),
      'cashier_name_en', COALESCE(e.name_en, 'N/A'),
      'cashier_name_ar', COALESCE(e.name_ar, 'N/A'),
      'transfer_status', COALESCE(
        (SELECT pdt.status::text FROM pos_deduction_transfers pdt WHERE pdt.box_operation_id = bo.id ORDER BY pdt.created_at DESC LIMIT 1),
        'Not Transferred'
      )
    ) as row_data
    FROM box_operations bo
    LEFT JOIN branches b ON b.id = bo.branch_id
    LEFT JOIN hr_employee_master e ON e.user_id = bo.user_id
    WHERE bo.status = 'completed'
      AND (p_date_from IS NULL OR bo.created_at >= p_date_from)
      AND (p_date_to IS NULL OR bo.created_at <= p_date_to)
    ORDER BY bo.created_at DESC
  ) sub;

  RETURN v_result;
END;
$$;


--
-- Name: get_product_master_init_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_product_master_init_data() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_total_products int;
  v_with_images int;
  v_without_images int;
  v_units jsonb;
  v_categories jsonb;
BEGIN
  -- Get total products count
  SELECT count(*) INTO v_total_products FROM products;
  
  -- Get products with images count
  SELECT count(*) INTO v_with_images 
  FROM products 
  WHERE image_url IS NOT NULL AND image_url <> '';
  
  -- Get products without images count
  v_without_images := v_total_products - v_with_images;
  
  -- Get all units
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object('id', id, 'name_en', name_en, 'name_ar', name_ar)
    ORDER BY name_en
  ), '[]'::jsonb) INTO v_units
  FROM product_units;
  
  -- Get all categories
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object('id', id, 'name_en', name_en, 'name_ar', name_ar)
    ORDER BY name_en
  ), '[]'::jsonb) INTO v_categories
  FROM product_categories;
  
  RETURN jsonb_build_object(
    'total_products', v_total_products,
    'products_with_images', v_with_images,
    'products_without_images', v_without_images,
    'units', v_units,
    'categories', v_categories
  );
END;
$$;


--
-- Name: get_product_offers(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_product_offers(p_product_id uuid) RETURNS TABLE(offer_id integer, offer_name_en text, offer_name_ar text, offer_type text, discount_type text, offer_qty integer, offer_percentage numeric, offer_price numeric, original_price numeric, savings numeric, end_date timestamp with time zone, service_type text, branch_id integer)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id AS offer_id,
    o.name_en AS offer_name_en,
    o.name_ar AS offer_name_ar,
    o.type AS offer_type,
    o.discount_type,
    op.offer_qty,
    op.offer_percentage,
    op.offer_price,
    p.sale_price AS original_price,
    CASE 
      WHEN op.offer_percentage IS NOT NULL THEN 
        (p.sale_price * op.offer_qty) - ((p.sale_price * op.offer_qty) * (1 - op.offer_percentage / 100))
      WHEN op.offer_price IS NOT NULL THEN 
        (p.sale_price * op.offer_qty) - op.offer_price
      ELSE 0
    END AS savings,
    o.end_date,
    o.service_type,
    o.branch_id
  FROM offers o
  INNER JOIN offer_products op ON o.id = op.offer_id
  INNER JOIN products p ON op.product_id = p.id
  WHERE op.product_id = p_product_id
    AND o.is_active = true
    AND o.type = 'product'
    AND o.start_date <= NOW()
    AND o.end_date >= NOW()
  ORDER BY savings DESC;
END;
$$;


--
-- Name: FUNCTION get_product_offers(p_product_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_product_offers(p_product_id uuid) IS 'Get all active product offers for a specific product, ordered by best savings';


--
-- Name: get_product_variations(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_product_variations(p_barcode text) RETURNS TABLE(id character varying, barcode text, product_name_en text, product_name_ar text, unit_name text, image_url text, variation_order integer, is_parent boolean, parent_barcode text, group_name_en text, group_name_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  WITH target_product AS (
    SELECT 
      COALESCE(p.parent_product_barcode, p.barcode) as parent_ref
    FROM products p
    WHERE p.barcode = p_barcode
  )
  SELECT 
    p.id,
    p.barcode,
    p.product_name_en,
    p.product_name_ar,
    pu.name_en as unit_name,
    p.image_url,
    p.variation_order,
    (p.barcode = (SELECT parent_ref FROM target_product)) as is_parent,
    p.parent_product_barcode as parent_barcode,
    p.variation_group_name_en as group_name_en,
    p.variation_group_name_ar as group_name_ar
  FROM products p
  LEFT JOIN product_units pu ON p.unit_id = pu.id
  WHERE p.is_variation = true
    AND (p.parent_product_barcode = (SELECT parent_ref FROM target_product)
         OR p.barcode = (SELECT parent_ref FROM target_product))
  ORDER BY p.variation_order ASC, p.product_name_en ASC;
END;
$$;


--
-- Name: get_products_dashboard_data(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_products_dashboard_data(p_limit integer DEFAULT 500, p_offset integer DEFAULT 0) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'products', COALESCE((
      SELECT jsonb_agg(row_data ORDER BY rn)
      FROM (
        SELECT 
          jsonb_build_object(
            'id', p.id,
            'barcode', p.barcode,
            'product_name_en', COALESCE(p.product_name_en, ''),
            'product_name_ar', COALESCE(p.product_name_ar, ''),
            'category_id', p.category_id,
            'category_name_en', pc.name_en,
            'category_name_ar', pc.name_ar,
            'unit_id', p.unit_id,
            'unit_name_en', pu.name_en,
            'unit_name_ar', pu.name_ar
          ) AS row_data,
          ROW_NUMBER() OVER (ORDER BY p.product_name_en) AS rn
        FROM products p
        LEFT JOIN product_categories pc ON p.category_id = pc.id
        LEFT JOIN product_units pu ON p.unit_id = pu.id
        ORDER BY p.product_name_en
        LIMIT p_limit
        OFFSET p_offset
      ) sub
    ), '[]'::jsonb),
    'categories', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', pc.id,
          'name_en', pc.name_en,
          'name_ar', pc.name_ar
        ) ORDER BY pc.name_en
      )
      FROM product_categories pc
    ), '[]'::jsonb),
    'units', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', pu.id,
          'name_en', pu.name_en,
          'name_ar', pu.name_ar
        ) ORDER BY pu.name_en
      )
      FROM product_units pu
--

--
-- Name: get_products_in_active_offers(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_products_in_active_offers() RETURNS TABLE(product_id uuid, offer_id integer, offer_name_en text, offer_name_ar text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    op.product_id,
    o.id AS offer_id,
    o.name_en AS offer_name_en,
    o.name_ar AS offer_name_ar
  FROM offer_products op
  INNER JOIN offers o ON op.offer_id = o.id
  WHERE o.is_active = true
    AND o.type = 'product'
    AND o.start_date <= NOW()
    AND o.end_date >= NOW();
END;
$$;


--
-- Name: FUNCTION get_products_in_active_offers(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_products_in_active_offers() IS 'Get all products in active product offers for admin filtering';


--
-- Name: get_purchase_voucher_manager_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_purchase_voucher_manager_data() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  result jsonb;
  not_issued_stats jsonb;
  issued_stats jsonb;
  closed_stats jsonb;
  book_summary_data jsonb;
  branches_data jsonb;
  users_data jsonb;
  employees_data jsonb;
BEGIN

  -- 1. Not Issued Stats: group by stock_location, value
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
  INTO not_issued_stats
  FROM (
    SELECT 
      COALESCE(stock_location::text, 'unassigned') as stock_location,
      value,
      count(*) as voucher_count,
      count(DISTINCT purchase_voucher_id) as book_count
    FROM purchase_voucher_items
    WHERE issue_type = 'not issued'
    GROUP BY COALESCE(stock_location::text, 'unassigned'), value
  ) t;

  -- 2. Issued Stats: group by stock_location, value, issue_type (excluding 'not issued')
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
  INTO issued_stats
  FROM (
    SELECT 
      COALESCE(stock_location::text, 'unassigned') as stock_location,
      value,
      COALESCE(issue_type, 'unknown') as issue_type,
      count(*) as voucher_count,
      count(DISTINCT purchase_voucher_id) as book_count
    FROM purchase_voucher_items
    WHERE issue_type != 'not issued'
    GROUP BY COALESCE(stock_location::text, 'unassigned'), value, COALESCE(issue_type, 'unknown')
  ) t;

  -- 3. Closed Stats: group by stock_location, value, issue_type (status = 'closed')
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
  INTO closed_stats
  FROM (
    SELECT 
      COALESCE(stock_location::text, 'unassigned') as stock_location,
      value,
--

--
-- Name: get_pv_stock_manager_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_pv_stock_manager_data() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'book_summary', COALESCE((
      SELECT jsonb_agg(to_jsonb(bs.*) ORDER BY bs.has_unassigned DESC, bs.voucher_id ASC)
      FROM (
        SELECT 
          pv.id AS voucher_id,
          pv.book_number,
          pv.serial_start || ' - ' || pv.serial_end AS serial_range,
          COUNT(pvi.id)::int AS total_count,
          COALESCE(SUM(pvi.value), 0)::numeric AS total_value,
          COUNT(CASE WHEN pvi.stock > 0 THEN 1 END)::int AS stock_count,
          COUNT(CASE WHEN pvi.status = 'stocked' THEN 1 END)::int AS stocked_count,
          COUNT(CASE WHEN pvi.status = 'issued' THEN 1 END)::int AS issued_count,
          COUNT(CASE WHEN pvi.status = 'closed' THEN 1 END)::int AS closed_count,
          COALESCE(
            (SELECT jsonb_agg(DISTINCT sl) FROM unnest(array_agg(DISTINCT pvi.stock_location)) sl WHERE sl IS NOT NULL),
            '[]'::jsonb
          ) AS stock_locations,
          COALESCE(
            (SELECT jsonb_agg(DISTINCT sp) FROM unnest(array_agg(DISTINCT pvi.stock_person)) sp WHERE sp IS NOT NULL),
            '[]'::jsonb
          ) AS stock_persons,
          CASE WHEN bool_or(pvi.stock_location IS NULL OR pvi.stock_person IS NULL) THEN 1 ELSE 0 END AS has_unassigned
        FROM purchase_vouchers pv
        LEFT JOIN purchase_voucher_items pvi ON pvi.purchase_voucher_id = pv.id
        GROUP BY pv.id, pv.book_number, pv.serial_start, pv.serial_end
      ) bs
    ), '[]'::jsonb),
    'branches', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', b.id, 'name_en', b.name_en, 'location_en', b.location_en))
      FROM branches b
    ), '[]'::jsonb),
    'users', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', u.id, 'username', u.username, 'employee_id', u.employee_id))
      FROM users u
    ), '[]'::jsonb),
    'employees', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', e.id, 'name', e.name))
      FROM hr_employees e
    ), '[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
--

--
-- Name: get_pv_stock_voucher_items(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_pv_stock_voucher_items() RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT jsonb_build_object(
    'items', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', pvi.id,
          'purchase_voucher_id', pvi.purchase_voucher_id,
          'serial_number', pvi.serial_number,
          'value', pvi.value,
          'stock', pvi.stock,
          'status', pvi.status,
          'issue_type', pvi.issue_type,
          'stock_location', pvi.stock_location,
          'stock_person', pvi.stock_person,
          'stock_location_name', COALESCE(b.name_en, '-'),
          'stock_person_name', COALESCE(e.name_en, u.username, '-')
        )
        ORDER BY pvi.purchase_voucher_id, pvi.serial_number
      )
      FROM purchase_voucher_items pvi
      LEFT JOIN branches b ON b.id = pvi.stock_location
      LEFT JOIN users u ON u.id = pvi.stock_person
      LEFT JOIN hr_employee_master e ON e.id = u.employee_id::text
    ), '[]'::jsonb)
  );
$$;


--
-- Name: get_pv_stock_voucher_items(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_pv_stock_voucher_items(p_offset integer DEFAULT 0, p_limit integer DEFAULT 2000) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT jsonb_build_object(
    'total_count', (SELECT count(*) FROM purchase_voucher_items),
    'items', COALESCE((
      SELECT jsonb_agg(row_data)
      FROM (
        SELECT jsonb_build_object(
          'id', pvi.id,
          'purchase_voucher_id', pvi.purchase_voucher_id,
          'serial_number', pvi.serial_number,
          'value', pvi.value,
          'stock', pvi.stock,
          'status', pvi.status,
          'issue_type', pvi.issue_type,
          'stock_location', pvi.stock_location,
          'stock_person', pvi.stock_person,
          'stock_location_name', COALESCE(b.name_en, '-'),
          'stock_person_name', COALESCE(e.name_en, u.username, '-')
        ) as row_data
        FROM purchase_voucher_items pvi
        LEFT JOIN branches b ON b.id = pvi.stock_location
        LEFT JOIN users u ON u.id = pvi.stock_person
        LEFT JOIN hr_employee_master e ON e.id = u.employee_id::text
        ORDER BY pvi.purchase_voucher_id, pvi.serial_number
        LIMIT p_limit OFFSET p_offset
      ) sub
    ), '[]'::jsonb)
  );
$$;


--
-- Name: get_quick_access_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_quick_access_stats() RETURNS TABLE(total_codes bigint, active_codes bigint, unused_codes bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_codes,
        COUNT(CASE WHEN status = 'active' THEN 1 END)::BIGINT as active_codes,
        COUNT(CASE WHEN quick_access_code IS NOT NULL AND last_login_at IS NULL THEN 1 END)::BIGINT as unused_codes
    FROM users
    WHERE deleted_at IS NULL;
END;
$$;


--
-- Name: get_quick_expiry_report(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_quick_expiry_report(days_threshold integer DEFAULT 15) RETURNS TABLE(branch_id integer, barcode character varying, product_name_en character varying, product_name_ar character varying, expiry_date date, days_left integer)
    LANGUAGE sql STABLE
    AS $$
  SELECT
    (entry->>'branch_id')::integer AS branch_id,
    p.barcode,
    p.product_name_en,
    p.product_name_ar,
    (entry->>'expiry_date')::date AS expiry_date,
    ((entry->>'expiry_date')::date - CURRENT_DATE) AS days_left
  FROM erp_synced_products p,
    jsonb_array_elements(p.expiry_dates) AS entry
  WHERE jsonb_array_length(p.expiry_dates) > 0
    AND (p.expiry_hidden IS NOT TRUE)
    AND (entry->>'expiry_date') IS NOT NULL
    AND (entry->>'branch_id') IS NOT NULL
    AND ((entry->>'expiry_date')::date - CURRENT_DATE) <= days_threshold
  ORDER BY p.barcode, ((entry->>'expiry_date')::date - CURRENT_DATE) ASC;
$$;


--
-- Name: get_quick_task_completion_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_quick_task_completion_stats() RETURNS TABLE(total_completions bigint, submitted_count bigint, verified_count bigint, rejected_count bigint, pending_review_count bigint, completions_with_photos bigint, completions_with_erp bigint, avg_verification_time interval)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_completions,
        COUNT(*) FILTER (WHERE completion_status = 'submitted') as submitted_count,
        COUNT(*) FILTER (WHERE completion_status = 'verified') as verified_count,
        COUNT(*) FILTER (WHERE completion_status = 'rejected') as rejected_count,
        COUNT(*) FILTER (WHERE completion_status = 'pending_review') as pending_review_count,
        COUNT(*) FILTER (WHERE photo_path IS NOT NULL) as completions_with_photos,
        COUNT(*) FILTER (WHERE erp_reference IS NOT NULL) as completions_with_erp,
        AVG(verified_at - created_at) FILTER (WHERE verified_at IS NOT NULL) as avg_verification_time
    FROM quick_task_completions;
END;
$$;


--
-- Name: get_receiving_records_with_details(integer, integer, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_receiving_records_with_details(p_limit integer DEFAULT 500, p_offset integer DEFAULT 0, p_branch_id text DEFAULT NULL::text, p_vendor_search text DEFAULT NULL::text, p_pr_excel_filter text DEFAULT NULL::text, p_erp_ref_filter text DEFAULT NULL::text) RETURNS TABLE(id text, bill_number text, vendor_id text, branch_id text, bill_date date, bill_amount numeric, created_at timestamp with time zone, user_id text, original_bill_url text, erp_purchase_invoice_reference text, certificate_url text, due_date date, pr_excel_file_url text, final_bill_amount numeric, payment_method text, credit_period integer, bank_name text, iban text, branch_name_en text, branch_location_en text, vendor_name text, vat_number text, username text, user_display_name text, is_scheduled boolean, is_paid boolean, pr_excel_verified boolean, pr_excel_verified_by text, pr_excel_verified_date timestamp with time zone, total_count bigint)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_total BIGINT;
BEGIN
    -- Get total count with same filters (for pagination info)
    SELECT COUNT(*) INTO v_total
    FROM receiving_records r
    LEFT JOIN branches b ON b.id = r.branch_id
    LEFT JOIN vendors v ON v.erp_vendor_id = r.vendor_id AND v.branch_id = r.branch_id
    LEFT JOIN LATERAL (
        SELECT vps.pr_excel_verified
        FROM vendor_payment_schedule vps
        WHERE vps.receiving_record_id = r.id
        LIMIT 1
    ) ps_count ON true
    WHERE (p_branch_id IS NULL OR r.branch_id::TEXT = p_branch_id)
      AND (p_vendor_search IS NULL OR p_vendor_search = '' OR LOWER(v.vendor_name) LIKE '%' || LOWER(p_vendor_search) || '%')
      AND (p_pr_excel_filter IS NULL OR p_pr_excel_filter = '' 
           OR (p_pr_excel_filter = 'verified' AND COALESCE(ps_count.pr_excel_verified, false) = true)
           OR (p_pr_excel_filter = 'unverified' AND COALESCE(ps_count.pr_excel_verified, false) = false))
      AND (p_erp_ref_filter IS NULL OR p_erp_ref_filter = ''
           OR (p_erp_ref_filter = 'entered' AND r.erp_purchase_invoice_reference IS NOT NULL AND TRIM(r.erp_purchase_invoice_reference::TEXT) <> '')
           OR (p_erp_ref_filter = 'not_entered' AND (r.erp_purchase_invoice_reference IS NULL OR TRIM(r.erp_purchase_invoice_reference::TEXT) = '')));

    RETURN QUERY
    SELECT
        r.id::TEXT,
        r.bill_number::TEXT,
        r.vendor_id::TEXT,
        r.branch_id::TEXT,
        r.bill_date,
        r.bill_amount,
        r.created_at,
        r.user_id::TEXT,
        r.original_bill_url::TEXT,
        r.erp_purchase_invoice_reference::TEXT,
        r.certificate_url::TEXT,
        r.due_date,
        r.pr_excel_file_url::TEXT,
        r.final_bill_amount,
        r.payment_method::TEXT,
        r.credit_period,
        r.bank_name::TEXT,
        r.iban::TEXT,
        -- Branch
        COALESCE(b.name_en, 'N/A')::TEXT AS branch_name_en,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        -- Vendor (match by erp_vendor_id AND branch_id)
        COALESCE(v.vendor_name, 'N/A')::TEXT AS vendor_name,
--

--
-- Name: get_receiving_task_statistics(integer, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_receiving_task_statistics(branch_id_param integer DEFAULT NULL::integer, date_from date DEFAULT NULL::date, date_to date DEFAULT NULL::date) RETURNS TABLE(total_tasks bigint, pending_tasks bigint, in_progress_tasks bigint, completed_tasks bigint, overdue_tasks bigint, high_priority_tasks bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE t.status = 'pending') as pending_tasks,
        COUNT(*) FILTER (WHERE t.status = 'in_progress') as in_progress_tasks,
        COUNT(*) FILTER (WHERE t.status = 'completed') as completed_tasks,
        COUNT(*) FILTER (WHERE t.status != 'completed' AND t.due_datetime < NOW()) as overdue_tasks,
        COUNT(*) FILTER (WHERE t.priority = 'high') as high_priority_tasks
    FROM tasks t
    LEFT JOIN receiving_records rr ON rr.id::text = SUBSTRING(t.description FROM 'receiving record ([0-9a-f-]+)')
    WHERE t.description LIKE '%receiving record%'
    AND (branch_id_param IS NULL OR rr.branch_id = branch_id_param)
    AND (date_from IS NULL OR DATE(t.created_at) >= date_from)
    AND (date_to IS NULL OR DATE(t.created_at) <= date_to);
END;
$$;


--
-- Name: get_receiving_task_statistics(integer, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_receiving_task_statistics(branch_id_param integer DEFAULT NULL::integer, date_from timestamp with time zone DEFAULT NULL::timestamp with time zone, date_to timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE(total_tasks bigint, completed_tasks bigint, pending_tasks bigint, overdue_tasks bigint, tasks_by_role jsonb, completion_rate numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE task_completed = true) as completed_tasks,
        COUNT(*) FILTER (WHERE task_completed = false) as pending_tasks,
        COUNT(*) FILTER (WHERE is_overdue = true AND task_completed = false) as overdue_tasks,
        jsonb_object_agg(
            role_type, 
            jsonb_build_object(
                'total', role_count,
                'completed', role_completed
            )
        ) as tasks_by_role,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(*) FILTER (WHERE task_completed = true) * 100.0) / COUNT(*), 2)
            ELSE 0
        END as completion_rate
    FROM (
        SELECT 
            rtd.role_type,
            rtd.task_completed,
            rtd.is_overdue,
            COUNT(*) OVER (PARTITION BY rtd.role_type) as role_count,
            COUNT(*) FILTER (WHERE rtd.task_completed = true) OVER (PARTITION BY rtd.role_type) as role_completed
        FROM receiving_tasks_detailed rtd
        WHERE (branch_id_param IS NULL OR rtd.branch_id = branch_id_param)
          AND (date_from IS NULL OR rtd.created_at >= date_from)
          AND (date_to IS NULL OR rtd.created_at <= date_to)
    ) stats
    GROUP BY ();
END;
$$;


--
-- Name: get_receiving_tasks_for_user(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_receiving_tasks_for_user(p_user_id uuid, p_completed_days integer DEFAULT 7) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_my_tasks json;
  v_team_tasks json;
  v_is_branch_manager boolean := false;
  v_employee_names json;
  v_cutoff timestamp;
BEGIN
  -- Calculate cutoff for completed tasks
  v_cutoff := NOW() - (p_completed_days || ' days')::interval;

  -- 1. Get user's own tasks: all pending + completed from last N days
  SELECT json_agg(t ORDER BY t.created_at DESC)
  INTO v_my_tasks
  FROM (
    SELECT id, title, description, priority, role_type, task_status, due_date,
           created_at, assigned_user_id, receiving_record_id, clearance_certificate_url,
           requires_original_bill_upload, requires_erp_reference
    FROM receiving_tasks
    WHERE assigned_user_id = p_user_id
      AND (task_status != 'completed' OR created_at >= v_cutoff)
  ) t;

  -- Default to empty array
  IF v_my_tasks IS NULL THEN
    v_my_tasks := '[]'::json;
  END IF;

  -- 2. Check if user is branch manager
  SELECT EXISTS (
    SELECT 1 FROM receiving_tasks
    WHERE assigned_user_id = p_user_id AND role_type = 'branch_manager'
    LIMIT 1
  ) INTO v_is_branch_manager;

  -- 3. If branch manager, load team tasks (shelf_stocker + night_supervisor)
  -- All pending tasks (no time limit) + completed from last N days
  IF v_is_branch_manager THEN
    SELECT json_agg(t ORDER BY t.created_at DESC)
    INTO v_team_tasks
    FROM (
      SELECT rt.id, rt.title, rt.description, rt.priority, rt.role_type, rt.task_status,
             rt.due_date, rt.created_at, rt.assigned_user_id, rt.receiving_record_id,
             rt.clearance_certificate_url, rt.completion_photo_url, rt.completed_at
      FROM receiving_tasks rt
      WHERE rt.receiving_record_id IN (
        SELECT DISTINCT receiving_record_id
        FROM receiving_tasks
        WHERE assigned_user_id = p_user_id
--

--
-- Name: get_reminder_statistics(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_reminder_statistics(p_user_id uuid DEFAULT NULL::uuid, p_days integer DEFAULT 30) RETURNS TABLE(total_reminders bigint, reminders_today bigint, reminders_this_week bigint, reminders_this_month bigint, avg_hours_overdue numeric, most_overdue_task text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  WITH stats AS (
    SELECT
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE DATE(reminder_sent_at) = CURRENT_DATE) as today,
      COUNT(*) FILTER (WHERE reminder_sent_at >= CURRENT_DATE - INTERVAL '7 days') as week,
      COUNT(*) FILTER (WHERE reminder_sent_at >= CURRENT_DATE - INTERVAL '30 days') as month,
      AVG(hours_overdue) as avg_overdue
    FROM task_reminder_logs
    WHERE (p_user_id IS NULL OR assigned_to_user_id = p_user_id)
      AND reminder_sent_at >= CURRENT_DATE - (p_days || ' days')::INTERVAL
  ),
  most_overdue AS (
    SELECT task_title
    FROM task_reminder_logs
    WHERE (p_user_id IS NULL OR assigned_to_user_id = p_user_id)
    ORDER BY hours_overdue DESC NULLS LAST
    LIMIT 1
  )
  SELECT 
    COALESCE(s.total, 0),
    COALESCE(s.today, 0),
    COALESCE(s.week, 0),
    COALESCE(s.month, 0),
    ROUND(COALESCE(s.avg_overdue, 0), 1),
    COALESCE(m.task_title, 'N/A')
  FROM stats s
  CROSS JOIN most_overdue m;
END;
$$;


--
-- Name: FUNCTION get_reminder_statistics(p_user_id uuid, p_days integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_reminder_statistics(p_user_id uuid, p_days integer) IS 'Returns statistics about sent reminders for a user or all users';


--
-- Name: get_report_data(text, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_report_data(p_party_type text, p_party_ids uuid[]) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN json_build_object(
        'entries', (
            SELECT COALESCE(json_agg(sub), '[]'::json)
            FROM (
                SELECT * FROM lease_rent_payment_entries
                WHERE party_type = p_party_type AND party_id = ANY(p_party_ids)
                ORDER BY created_at ASC
            ) sub
        ),
        'changes', (
            SELECT COALESCE(json_agg(sub), '[]'::json)
            FROM (
                SELECT * FROM lease_rent_special_changes
                WHERE party_type = p_party_type AND party_id = ANY(p_party_ids)
                ORDER BY created_at DESC
            ) sub
        )
    );
END;
$$;


--
-- Name: get_report_party_paid_totals(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_report_party_paid_totals(p_party_type text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN (
        SELECT COALESCE(json_object_agg(party_id, total_paid), '{}'::json)
        FROM (
            SELECT party_id, SUM(amount)::numeric as total_paid
            FROM lease_rent_payment_entries
            WHERE party_type = p_party_type
            GROUP BY party_id
        ) sub
    );
END;
$$;


--
-- Name: get_salary_statement_by_id(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_salary_statement_by_id(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_row public.hr_salary_statements;
BEGIN
    IF p_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'id is required');
    END IF;
    SELECT * INTO v_row FROM public.hr_salary_statements WHERE id = p_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'not found');
    END IF;
    RETURN jsonb_build_object(
        'success', true,
        'item', jsonb_build_object(
            'id', v_row.id,
            'statement_name', v_row.statement_name,
            'start_date', v_row.start_date,
            'end_date', v_row.end_date,
            'data_json', v_row.data_json,
            'created_at', v_row.created_at,
            'updated_at', v_row.updated_at
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


--
-- Name: get_server_disk_usage(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_server_disk_usage() RETURNS TABLE(filesystem text, total_size text, used_size text, available_size text, use_percent integer, mount_point text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _disk_raw (line text) ON COMMIT DROP;
  TRUNCATE _disk_raw;

  COPY _disk_raw (line) FROM PROGRAM
    'df -h / | tail -n 1 | awk ''{print $1"|"$2"|"$3"|"$4"|"$5"|"$6}''';

  RETURN QUERY
  SELECT
    split_part(line, '|', 1),
    split_part(line, '|', 2),
    split_part(line, '|', 3),
    split_part(line, '|', 4),
    REPLACE(split_part(line, '|', 5), '%', '')::int,
    split_part(line, '|', 6)
  FROM _disk_raw
  LIMIT 1;
END;
$_$;


--
-- Name: get_special_shift_date_wise(integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_special_shift_date_wise(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date) RETURNS TABLE(id text, employee_id text, employee_name_en text, employee_name_ar text, branch_id text, branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text, nationality_id text, nationality_name_en text, nationality_name_ar text, sponsorship_status boolean, employment_status text, shift_date text, shift_start_time text, shift_start_buffer integer, shift_end_time text, shift_end_buffer integer, is_shift_overlapping_next_day boolean, working_hours numeric, total_count bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT
        s.id::text,
        s.employee_id::text,
        COALESCE(e.name_en, 'N/A')           AS employee_name_en,
        COALESCE(e.name_ar, 'N/A')           AS employee_name_ar,
        e.current_branch_id::text            AS branch_id,
        COALESCE(b.name_en, 'N/A')           AS branch_name_en,
        COALESCE(b.name_ar, 'N/A')           AS branch_name_ar,
        COALESCE(b.location_en, '')          AS branch_location_en,
        COALESCE(b.location_ar, '')          AS branch_location_ar,
        e.nationality_id::text,
        COALESCE(n.name_en, 'N/A')           AS nationality_name_en,
        COALESCE(n.name_ar, 'N/A')           AS nationality_name_ar,
        e.sponsorship_status,
        COALESCE(e.employment_status, '')    AS employment_status,
        s.shift_date::text,
        s.shift_start_time::text,
        s.shift_start_buffer,
        s.shift_end_time::text,
        s.shift_end_buffer,
        s.is_shift_overlapping_next_day,
        s.working_hours,
        COUNT(*) OVER ()                     AS total_count
    FROM special_shift_date_wise s
    LEFT JOIN hr_employee_master e ON e.id = s.employee_id
    LEFT JOIN branches           b ON b.id = e.current_branch_id
    LEFT JOIN nationalities      n ON n.id::text = e.nationality_id::text
    WHERE
        (p_start_date IS NULL OR s.shift_date >= p_start_date)
        AND (p_end_date IS NULL OR s.shift_date <= p_end_date)
    ORDER BY s.shift_date DESC
    LIMIT  p_limit
    OFFSET p_offset;
$$;


--
-- Name: get_stock_requests_with_details(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_stock_requests_with_details() RETURNS TABLE(id uuid, requester_user_id uuid, branch_id integer, target_user_id uuid, status character varying, items jsonb, document_url text, created_at timestamp with time zone, updated_at timestamp with time zone, requester_name_en text, requester_name_ar text, target_name_en text, target_name_ar text, branch_name_en text, branch_name_ar text, branch_location_en text, branch_location_ar text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.requester_user_id,
        r.branch_id,
        r.target_user_id,
        r.status,
        r.items,
        r.document_url,
        r.created_at,
        r.updated_at,
        -- Requester name
        COALESCE(req.name_en, req.user_id::TEXT)::TEXT AS requester_name_en,
        COALESCE(req.name_ar, req.name_en, req.user_id::TEXT)::TEXT AS requester_name_ar,
        -- Target name
        COALESCE(tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_en,
        COALESCE(tgt.name_ar, tgt.name_en, tgt.user_id::TEXT)::TEXT AS target_name_ar,
        -- Branch info
        COALESCE(b.name_en, '')::TEXT AS branch_name_en,
        COALESCE(b.name_ar, b.name_en, '')::TEXT AS branch_name_ar,
        COALESCE(b.location_en, '')::TEXT AS branch_location_en,
        COALESCE(b.location_ar, b.location_en, '')::TEXT AS branch_location_ar
    FROM product_request_st r
    LEFT JOIN hr_employee_master req ON req.user_id = r.requester_user_id
    LEFT JOIN hr_employee_master tgt ON tgt.user_id = r.target_user_id
    LEFT JOIN branches b ON b.id = r.branch_id
    ORDER BY r.created_at DESC;
END;
$$;


--
-- Name: get_storage_buckets_info(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_storage_buckets_info() RETURNS TABLE(bucket_id text, bucket_name text, is_public boolean, created_at timestamp with time zone, updated_at timestamp with time zone, file_size_limit bigint, allowed_mime_types text[], file_count bigint, total_size bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'storage'
    AS $$
  SELECT 
    b.id::text AS bucket_id,
    b.name::text AS bucket_name,
    b.public AS is_public,
    b.created_at,
    b.updated_at,
    b.file_size_limit,
    b.allowed_mime_types,
    COALESCE(stats.file_count, 0) AS file_count,
    COALESCE(stats.total_size, 0) AS total_size
  FROM storage.buckets b
  LEFT JOIN (
    SELECT 
      bucket_id,
      COUNT(*) AS file_count,
      SUM(COALESCE((metadata->>'size')::bigint, 0)) AS total_size
    FROM storage.objects
    GROUP BY bucket_id
  ) stats ON stats.bucket_id = b.id
  ORDER BY total_size DESC NULLS LAST;
$$;


--
-- Name: get_storage_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_storage_stats() RETURNS TABLE(bucket_id text, bucket_name text, file_count bigint, total_size bigint)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT 
        b.id::text AS bucket_id,
        b.name::text AS bucket_name,
        COALESCE(COUNT(o.id), 0) AS file_count,
        COALESCE(SUM((o.metadata->>'size')::bigint), 0) AS total_size
    FROM storage.buckets b
    LEFT JOIN storage.objects o ON o.bucket_id = b.id
    GROUP BY b.id, b.name
    ORDER BY total_size DESC;
$$;


--
-- Name: get_system_expiry_dates(text[], integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_system_expiry_dates(barcode_list text[], branch_id_param integer) RETURNS TABLE(barcode text, expiry_date_formatted text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT 
    esp.barcode,
    COALESCE(
      (SELECT TO_CHAR((e->>'expiry_date')::date, 'DD-MM-YYYY')
       FROM jsonb_array_elements(esp.expiry_dates) as e
       WHERE (e->>'branch_id')::integer = branch_id_param
       LIMIT 1),
      '├óΓé¼ΓÇ¥'
    ) as expiry_date_formatted
  FROM erp_synced_products esp
  WHERE esp.barcode = ANY(barcode_list)
  ORDER BY esp.barcode;
$$;


--
-- Name: get_table_schemas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_table_schemas() RETURNS TABLE(table_name text, column_count bigint, row_estimate bigint, table_size text, total_size text, schema_ddl text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  rec RECORD;
  col RECORD;
  con RECORD;
  idx RECORD;
  trg RECORD;
  pol RECORD;
  ddl text;
  col_line text;
  first_col boolean;
  tbl_oid oid;
  rls_enabled boolean;
BEGIN
  FOR rec IN
    SELECT
      t.tablename::text AS tname,
      (SELECT count(*) FROM information_schema.columns c WHERE c.table_schema = 'public' AND c.table_name = t.tablename) AS col_cnt,
      COALESCE(s.n_live_tup, 0) AS row_est,
      pg_size_pretty(pg_table_size(('public.' || quote_ident(t.tablename))::regclass)) AS tbl_size,
      pg_size_pretty(pg_total_relation_size(('public.' || quote_ident(t.tablename))::regclass)) AS tot_size
    FROM pg_tables t
    LEFT JOIN pg_stat_user_tables s ON s.schemaname = 'public' AND s.relname = t.tablename
    WHERE t.schemaname = 'public'
    ORDER BY pg_total_relation_size(('public.' || quote_ident(t.tablename))::regclass) DESC
  LOOP
    -- Get table OID
    tbl_oid := ('public.' || quote_ident(rec.tname))::regclass::oid;

    -- ==================== COLUMNS ====================
    ddl := 'CREATE TABLE public.' || quote_ident(rec.tname) || ' (' || E'\n';
    first_col := true;

    FOR col IN
      SELECT
        c.column_name,
        c.data_type,
        c.character_maximum_length,
        c.column_default,
        c.is_nullable,
        c.udt_name
      FROM information_schema.columns c
      WHERE c.table_schema = 'public' AND c.table_name = rec.tname
      ORDER BY c.ordinal_position
    LOOP
      IF NOT first_col THEN
        ddl := ddl || ',' || E'\n';
      END IF;
--

--
-- Name: get_task_dashboard(text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_task_dashboard(user_id_param text DEFAULT NULL::text, branch_id_param uuid DEFAULT NULL::uuid) RETURNS TABLE(total_tasks bigint, my_tasks bigint, completed_today bigint, overdue_count bigint, high_priority_count bigint, recent_completions json)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM tasks WHERE deleted_at IS NULL) as total_tasks,
        (
            SELECT COUNT(DISTINCT ta.task_id) 
            FROM task_assignments ta 
            JOIN tasks t ON ta.task_id = t.id
            WHERE (ta.assigned_to_user_id = user_id_param OR ta.assignment_type = 'all' 
                   OR (ta.assignment_type = 'branch' AND ta.assigned_to_branch_id = branch_id_param))
            AND t.deleted_at IS NULL
        ) as my_tasks,
        (
            SELECT COUNT(*) 
            FROM task_completions tc 
            JOIN tasks t ON tc.task_id = t.id
            WHERE tc.completed_by = user_id_param 
            AND tc.completed_at::date = CURRENT_DATE
            AND t.deleted_at IS NULL
        ) as completed_today,
        (SELECT COUNT(*) FROM tasks WHERE due_date < CURRENT_DATE AND status IN ('active', 'draft', 'paused') AND deleted_at IS NULL) as overdue_count,
        (SELECT COUNT(*) FROM tasks WHERE priority = 'high' AND status IN ('active', 'draft', 'paused') AND deleted_at IS NULL) as high_priority_count,
        (
            SELECT json_agg(json_build_object(
                'task_id', tc.task_id,
                'task_title', t.title,
                'completed_at', tc.completed_at,
                'completed_by_name', tc.completed_by_name
            ))
            FROM task_completions tc
            JOIN tasks t ON tc.task_id = t.id
            WHERE tc.completed_at >= CURRENT_DATE - INTERVAL '7 days'
            AND t.deleted_at IS NULL
            ORDER BY tc.completed_at DESC
            LIMIT 10
        ) as recent_completions;
END;
$$;


--
-- Name: get_task_master_stats(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_task_master_stats(p_user_id uuid) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_result json;
  v_total_tasks bigint;
  v_completed_tasks bigint;
  v_incomplete_tasks bigint;
  v_my_assigned_tasks bigint;
  v_my_completed_tasks bigint;
  v_my_assignments bigint;
BEGIN
  -- Total tasks (all assignment types)
  SELECT
    (SELECT COUNT(*) FROM task_assignments) +
    (SELECT COUNT(*) FROM quick_task_assignments) +
    (SELECT COUNT(*) FROM receiving_tasks)
  INTO v_total_tasks;

  -- Completed tasks
  SELECT
    (SELECT COUNT(*) FROM task_completions) +
    (SELECT COUNT(*) FROM quick_task_completions) +
    (SELECT COUNT(*) FROM receiving_tasks WHERE task_status = 'completed')
  INTO v_completed_tasks;

  -- Incomplete tasks
  SELECT
    (SELECT COUNT(*) FROM task_assignments WHERE status NOT IN ('completed', 'closed')) +
    (SELECT COUNT(*) FROM quick_task_assignments WHERE status NOT IN ('completed', 'closed')) +
    (SELECT COUNT(*) FROM receiving_tasks WHERE task_status != 'completed' AND task_completed = false)
  INTO v_incomplete_tasks;

  -- My assigned tasks (active only)
  SELECT
    (SELECT COUNT(*) FROM task_assignments WHERE assigned_to_user_id = p_user_id AND status IN ('assigned', 'in_progress', 'pending')) +
    (SELECT COUNT(*) FROM quick_task_assignments WHERE assigned_to_user_id = p_user_id AND status IN ('assigned', 'in_progress', 'pending')) +
    (SELECT COUNT(*) FROM receiving_tasks WHERE assigned_user_id = p_user_id AND task_status IN ('pending', 'in_progress'))
  INTO v_my_assigned_tasks;

  -- My completed tasks
  SELECT
    (SELECT COUNT(*) FROM task_completions WHERE completed_by = p_user_id::text) +
    (SELECT COUNT(*) FROM quick_task_completions WHERE completed_by_user_id = p_user_id) +
    (SELECT COUNT(*) FROM receiving_tasks WHERE completed_by_user_id = p_user_id AND task_status = 'completed')
  INTO v_my_completed_tasks;

  -- My assignments (tasks I assigned to others)
  SELECT
    (SELECT COUNT(*) FROM task_assignments WHERE assigned_by = p_user_id) +
    (SELECT COUNT(*) FROM quick_tasks WHERE assigned_by = p_user_id)
--

--
-- Name: get_task_statistics(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_task_statistics(user_id_param text DEFAULT NULL::text) RETURNS TABLE(total_tasks bigint, active_tasks bigint, completed_tasks bigint, draft_tasks bigint, paused_tasks bigint, cancelled_tasks bigint, my_assigned_tasks bigint, my_completed_tasks bigint, overdue_tasks bigint, due_today bigint, high_priority_tasks bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) FILTER (WHERE t.deleted_at IS NULL) as total_tasks,
        COUNT(*) FILTER (WHERE t.status = 'active' AND t.deleted_at IS NULL) as active_tasks,
        COUNT(*) FILTER (WHERE t.status = 'completed' AND t.deleted_at IS NULL) as completed_tasks,
        COUNT(*) FILTER (WHERE t.status = 'draft' AND t.deleted_at IS NULL) as draft_tasks,
        COUNT(*) FILTER (WHERE t.status = 'paused' AND t.deleted_at IS NULL) as paused_tasks,
        COUNT(*) FILTER (WHERE t.status = 'cancelled' AND t.deleted_at IS NULL) as cancelled_tasks,
        COUNT(DISTINCT ta.task_id) FILTER (WHERE (ta.assigned_to_user_id = user_id_param OR ta.assignment_type = 'all') AND t.deleted_at IS NULL) as my_assigned_tasks,
        COUNT(DISTINCT tc.task_id) FILTER (WHERE tc.completed_by = user_id_param AND t.deleted_at IS NULL) as my_completed_tasks,
        COUNT(*) FILTER (WHERE t.due_date < CURRENT_DATE AND t.status IN ('active', 'draft', 'paused') AND t.deleted_at IS NULL) as overdue_tasks,
        COUNT(*) FILTER (WHERE t.due_date = CURRENT_DATE AND t.status IN ('active', 'draft', 'paused') AND t.deleted_at IS NULL) as due_today,
        COUNT(*) FILTER (WHERE t.priority = 'high' AND t.status IN ('active', 'draft', 'paused') AND t.deleted_at IS NULL) as high_priority_tasks
    FROM public.tasks t
    LEFT JOIN public.task_assignments ta ON t.id = ta.task_id
    LEFT JOIN public.task_completions tc ON t.id = tc.task_id AND tc.completed_by = user_id_param;
END;
$$;


--
-- Name: get_task_statistics(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_task_statistics(user_id uuid DEFAULT NULL::uuid) RETURNS TABLE(total_tasks bigint, pending_tasks bigint, in_progress_tasks bigint, completed_tasks bigint, overdue_tasks bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_tasks,
        COUNT(CASE WHEN t.status = 'pending' THEN 1 END)::BIGINT as pending_tasks,
        COUNT(CASE WHEN t.status = 'in_progress' THEN 1 END)::BIGINT as in_progress_tasks,
        COUNT(CASE WHEN t.status = 'completed' THEN 1 END)::BIGINT as completed_tasks,
        COUNT(CASE WHEN t.status = 'overdue' THEN 1 END)::BIGINT as overdue_tasks
    FROM tasks t
    LEFT JOIN task_assignments ta ON t.id = ta.task_id
    WHERE (user_id IS NULL OR ta.assigned_to = user_id OR t.created_by = user_id)
      AND t.deleted_at IS NULL;
END;
$$;


--
-- Name: get_tasks_for_receiving_record(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_tasks_for_receiving_record(receiving_record_id_param uuid) RETURNS TABLE(task_id uuid, receiving_record_id uuid, role_type text, title text, description text, priority text, task_status text, task_completed boolean, due_date timestamp with time zone, created_at timestamp with time zone, completed_at timestamp with time zone, completed_by_user_id uuid, assigned_user_id uuid, requires_erp_reference boolean, requires_original_bill_upload boolean, erp_reference_number text, original_bill_uploaded boolean, original_bill_file_path text, clearance_certificate_url text, is_overdue boolean, days_until_due integer, bill_number text, vendor_name text, branch_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rt.id AS task_id,
    rt.receiving_record_id,
    rt.role_type::TEXT,
    rt.title,
    rt.description,
    rt.priority::TEXT,
    rt.task_status::TEXT,
    rt.task_completed,
    rt.due_date,
    rt.created_at,
    rt.completed_at,
    rt.completed_by_user_id,
    rt.assigned_user_id,
    rt.requires_erp_reference,
    rt.requires_original_bill_upload,
    rt.erp_reference_number::TEXT,
    rt.original_bill_uploaded,
    rt.original_bill_file_path,
    rt.clearance_certificate_url,
    -- Calculate if overdue
    CASE 
      WHEN rt.task_completed = false AND rt.due_date < NOW() THEN true
      ELSE false
    END AS is_overdue,
    -- Calculate days until due
    CASE 
      WHEN rt.task_completed = false THEN 
        EXTRACT(DAY FROM (rt.due_date - NOW()))::INTEGER
      ELSE 
        NULL
    END AS days_until_due,
    rr.bill_number::TEXT,
    v.vendor_name::TEXT,
    b.name_en::TEXT AS branch_name
  FROM receiving_tasks rt
  LEFT JOIN receiving_records rr ON rr.id = rt.receiving_record_id
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  WHERE rt.receiving_record_id = receiving_record_id_param
  ORDER BY 
    CASE rt.task_status
      WHEN 'pending' THEN 1
      WHEN 'in_progress' THEN 2
      WHEN 'completed' THEN 3
      ELSE 4
--

--
-- Name: get_todays_scheduled_visits(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_todays_scheduled_visits(target_date date DEFAULT CURRENT_DATE) RETURNS TABLE(id uuid, vendor_name text, branch_name text, visit_type text, pattern_info text, notes text, branch_id uuid, vendor_id uuid, weekday_name text, fresh_type text, day_number integer, skip_days integer, start_date date, next_visit_date date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vv.id,
        v.name::TEXT as vendor_name,
        b.name::TEXT as branch_name,
        vv.visit_type::TEXT,
        CASE 
            WHEN vv.visit_type = 'weekly' THEN ('Weekly on ' || COALESCE(vv.weekday_name, ''))::TEXT
            WHEN vv.visit_type = 'daily' THEN ('Daily (' || COALESCE(vv.fresh_type, '') || ')')::TEXT
            WHEN vv.visit_type = 'monthly' THEN ('Monthly on day ' || COALESCE(vv.day_number::TEXT, ''))::TEXT
            WHEN vv.visit_type = 'skip_days' THEN ('Every ' || COALESCE(vv.skip_days::TEXT, '') || ' days')::TEXT
            ELSE vv.visit_type::TEXT
        END as pattern_info,
        COALESCE(vv.notes, '')::TEXT,
        vv.branch_id,
        vv.vendor_id,
        COALESCE(vv.weekday_name, '')::TEXT,
        COALESCE(vv.fresh_type, '')::TEXT,
        vv.day_number,
        vv.skip_days,
        vv.start_date,
        vv.next_visit_date
    FROM vendor_visits vv
    JOIN vendors v ON vv.vendor_id = v.id
    JOIN branches b ON vv.branch_id = b.id
    WHERE vv.next_visit_date = target_date
    AND vv.status = 'active'
    ORDER BY b.name, v.name;
END;
$$;


--
-- Name: get_todays_scheduled_visits(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_todays_scheduled_visits(branch_uuid uuid DEFAULT NULL::uuid) RETURNS TABLE(visit_id uuid, vendor_name text, vendor_company text, visit_type text, fresh_type text, notes text, branch_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vv.id as visit_id,
        v.name as vendor_name,
        v.company as vendor_company,
        vv.visit_type,
        vv.fresh_type,
        vv.notes,
        b.name as branch_name
    FROM vendor_visits vv
    JOIN vendors v ON vv.vendor_id = v.id
    JOIN branches b ON vv.branch_id = b.id
    WHERE vv.next_visit_date = CURRENT_DATE
    AND vv.status = 'active'
    AND (branch_uuid IS NULL OR vv.branch_id = branch_uuid)
    ORDER BY v.company;
END;
$$;


--
-- Name: get_todays_vendor_visits(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_todays_vendor_visits(branch_uuid uuid) RETURNS TABLE(visit_id uuid, vendor_name text, vendor_company text, visit_time time without time zone, purpose text, status text, priority text, contact_person text, expected_duration_minutes integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vv.id as visit_id,
        v.name as vendor_name,
        v.company as vendor_company,
        vv.visit_time,
        vv.purpose,
        vv.status,
        vv.priority,
        vv.contact_person,
        vv.expected_duration_minutes
    FROM vendor_visits vv
    JOIN vendors v ON vv.vendor_id = v.id
    WHERE vv.branch_id = branch_uuid 
    AND vv.visit_date = CURRENT_DATE
    AND vv.status IN ('scheduled', 'confirmed', 'in_progress')
    ORDER BY vv.visit_time ASC NULLS LAST, vv.priority DESC;
END;
$$;


--
-- Name: get_todays_visits(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_todays_visits(branch_uuid uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, vendor_name text, branch_name text, visit_type text, next_visit_date date, pattern_config jsonb, notes text, last_visit_date date, visit_count integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vv.id,
        v.name::TEXT as vendor_name,
        b.name::TEXT as branch_name,
        vv.visit_type::TEXT,
        vv.next_visit_date,
        COALESCE(vv.pattern_config, '{}'::jsonb) as pattern_config,
        COALESCE(vv.notes, '')::TEXT,
        vv.last_visit_date,
        COALESCE(
            (SELECT COUNT(*)::INTEGER 
             FROM visit_history vh 
             WHERE vh.visit_schedule_id = vv.id 
             AND vh.status = 'completed'), 
            0
        ) as visit_count
    FROM vendor_visits vv
    JOIN vendors v ON vv.vendor_id = v.id
    JOIN branches b ON vv.branch_id = b.id
    WHERE vv.next_visit_date = CURRENT_DATE
    AND COALESCE(vv.is_active, true) = true
    AND (branch_uuid IS NULL OR vv.branch_id = branch_uuid)
    ORDER BY v.name ASC;
END;
$$;


--
-- Name: get_upcoming_visits(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_upcoming_visits(branch_uuid uuid DEFAULT NULL::uuid, days_ahead integer DEFAULT 7) RETURNS TABLE(visit_id uuid, vendor_name text, vendor_company text, visit_type text, next_visit_date date, days_until_visit integer, notes text, branch_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vv.id as visit_id,
        v.name as vendor_name,
        v.company as vendor_company,
        vv.visit_type,
        vv.next_visit_date,
        (vv.next_visit_date - CURRENT_DATE)::INTEGER as days_until_visit,
        vv.notes,
        b.name as branch_name
    FROM vendor_visits vv
    JOIN vendors v ON vv.vendor_id = v.id
    JOIN branches b ON vv.branch_id = b.id
    WHERE vv.next_visit_date BETWEEN CURRENT_DATE AND CURRENT_DATE + days_ahead
    AND vv.status = 'active'
    AND (branch_uuid IS NULL OR vv.branch_id = branch_uuid)
    ORDER BY vv.next_visit_date, v.company;
END;
$$;


--
-- Name: get_user_assigned_tasks(text, uuid, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_assigned_tasks(user_id_param text, branch_id_param uuid DEFAULT NULL::uuid, status_filter text DEFAULT NULL::text, limit_param integer DEFAULT 50, offset_param integer DEFAULT 0) RETURNS TABLE(id uuid, title text, description text, require_task_finished boolean, require_photo_upload boolean, require_erp_reference boolean, can_escalate boolean, can_reassign boolean, created_by text, created_by_name text, status text, priority text, created_at timestamp with time zone, updated_at timestamp with time zone, due_date date, due_time time without time zone, assignment_status text, assigned_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id, t.title, t.description, t.require_task_finished, t.require_photo_upload, t.require_erp_reference,
        t.can_escalate, t.can_reassign, t.created_by, t.created_by_name, t.status, t.priority,
        t.created_at, t.updated_at, t.due_date, t.due_time,
        ta.status as assignment_status, ta.assigned_at
    FROM public.tasks t
    INNER JOIN public.task_assignments ta ON t.id = ta.task_id
    WHERE t.deleted_at IS NULL
    AND (
        ta.assignment_type = 'all' 
        OR (ta.assignment_type = 'user' AND ta.assigned_to_user_id = user_id_param)
        OR (ta.assignment_type = 'branch' AND ta.assigned_to_branch_id = branch_id_param)
    )
    AND (status_filter IS NULL OR t.status = status_filter)
    ORDER BY t.created_at DESC
    LIMIT limit_param OFFSET offset_param;
END;
$$;


--
-- Name: get_user_interface_permissions(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_interface_permissions(p_user_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_permissions record;
    v_user_type text;
    result json;
BEGIN
    -- Get user type
    SELECT user_type INTO v_user_type
    FROM public.users
    WHERE id = p_user_id;
    
    IF v_user_type IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Get interface permissions
    SELECT 
        desktop_enabled,
        mobile_enabled,
        customer_enabled
    INTO v_permissions
    FROM public.interface_permissions
    WHERE user_id = p_user_id;
    
    -- If no permissions record exists, create default
    IF v_permissions IS NULL THEN
        INSERT INTO public.interface_permissions (
            user_id,
            desktop_enabled,
            mobile_enabled,
            customer_enabled,
            updated_by
        ) VALUES (
            p_user_id,
            CASE WHEN v_user_type = 'customer' THEN false ELSE true END,
            CASE WHEN v_user_type = 'customer' THEN false ELSE true END,
            CASE WHEN v_user_type = 'customer' THEN true ELSE false END,
            p_user_id
        ) RETURNING desktop_enabled, mobile_enabled, customer_enabled
        INTO v_permissions;
    END IF;
    
    -- Return permissions
    result := json_build_object(
        'success', true,
        'user_id', p_user_id,
        'user_type', v_user_type,
        'permissions', json_build_object(
            'desktop_enabled', v_permissions.desktop_enabled,
--

--
-- Name: get_user_receiving_tasks_dashboard(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_receiving_tasks_dashboard(user_id_param uuid) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_result JSON;
  v_pending_count INT;
  v_completed_count INT;
  v_overdue_count INT;
BEGIN
  -- Count statistics
  SELECT COUNT(*) INTO v_pending_count
  FROM receiving_tasks
  WHERE assigned_user_id = user_id_param
  AND task_completed = false
  AND task_status != 'completed';
  
  SELECT COUNT(*) INTO v_completed_count
  FROM receiving_tasks
  WHERE assigned_user_id = user_id_param
  AND (task_completed = true OR task_status = 'completed');
  
  SELECT COUNT(*) INTO v_overdue_count
  FROM receiving_tasks
  WHERE assigned_user_id = user_id_param
  AND due_date < NOW()
  AND task_completed = false
  AND task_status != 'completed';
  
  -- Build JSON result
  SELECT json_build_object(
    'user_id', user_id_param,
    'statistics', json_build_object(
      'pending_count', v_pending_count,
      'completed_count', v_completed_count,
      'overdue_count', v_overdue_count,
      'total_count', v_pending_count + v_completed_count
    ),
    'recent_tasks', (
      SELECT COALESCE(json_agg(tasks_json), '[]'::json)
      FROM (
        SELECT json_build_object(
          'id', rt.id,
          'receiving_record_id', rt.receiving_record_id,
          'role_type', rt.role_type,
          'title', rt.title,
          'description', rt.description,
          'priority', rt.priority,
          'task_status', rt.task_status,
          'task_completed', rt.task_completed,
          'due_date', rt.due_date,
          'completed_at', rt.completed_at,
--

--
-- Name: get_users_with_employee_details(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_users_with_employee_details() RETURNS TABLE(id uuid, username character varying, email character varying, role_type character varying, status character varying, employee_id uuid, employee_name character varying, employee_code character varying, employee_status character varying, department_name character varying, position_title character varying, branch_name character varying, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        ''::VARCHAR as email,
        -- Use admin flags instead of role_type column
        CASE 
            WHEN u.is_master_admin THEN 'Master Admin'::VARCHAR
            WHEN u.is_admin THEN 'Admin'::VARCHAR
            ELSE 'User'::VARCHAR
        END as role_type,
        COALESCE(u.status::VARCHAR, 'active') as status,
        u.employee_id,
        COALESCE(e.name, u.username)::VARCHAR as employee_name,
        COALESCE(e.employee_id, '')::VARCHAR as employee_code,
        COALESCE(e.status, 'active')::VARCHAR as employee_status,
        COALESCE(d.department_name_en, 'No Department')::VARCHAR as department_name,
        COALESCE(p.position_title_en, 'No Position')::VARCHAR as position_title,
        COALESCE(b.name_en, 'No Branch')::VARCHAR as branch_name,
        u.created_at,
        u.updated_at
    FROM users u
    LEFT JOIN hr_employees e ON u.employee_id = e.id
    LEFT JOIN branches b ON u.branch_id = b.id
    LEFT JOIN hr_positions p ON u.position_id = p.id
    LEFT JOIN hr_departments d ON p.department_id = d.id
    WHERE u.status = 'active'
    ORDER BY u.created_at DESC;
END;
$$;


--
-- Name: get_variation_group_info(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_variation_group_info(p_barcode text) RETURNS TABLE(parent_barcode text, group_name_en text, group_name_ar text, total_variations integer, variation_image_override text, created_by uuid, modified_by uuid, modified_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  WITH parent_info AS (
    SELECT 
      COALESCE(p.parent_product_barcode, p.barcode) as parent_ref
    FROM products p
    WHERE p.barcode = p_barcode
  )
  SELECT 
    parent.barcode as parent_barcode,
    parent.variation_group_name_en as group_name_en,
    parent.variation_group_name_ar as group_name_ar,
    COUNT(DISTINCT variations.barcode)::INTEGER as total_variations,
    parent.variation_image_override,
    parent.created_by,
    parent.modified_by,
    parent.modified_at
  FROM products parent
  LEFT JOIN products variations 
    ON variations.parent_product_barcode = parent.barcode 
    OR variations.barcode = parent.barcode
  WHERE parent.barcode = (SELECT parent_ref FROM parent_info)
    AND parent.is_variation = true
  GROUP BY 
    parent.barcode,
    parent.variation_group_name_en,
    parent.variation_group_name_ar,
    parent.variation_image_override,
    parent.created_by,
    parent.modified_by,
    parent.modified_at;
END;
$$;


--
-- Name: get_vendor_count_by_branch(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vendor_count_by_branch() RETURNS TABLE(branch_id bigint, branch_name text, vendor_count bigint, active_vendor_count bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id as branch_id,
        b.name_en as branch_name,
        COUNT(v.erp_vendor_id) as vendor_count,
        COUNT(CASE WHEN v.status = 'Active' THEN 1 END) as active_vendor_count
    FROM branches b
    LEFT JOIN vendors v ON b.id = v.branch_id
    GROUP BY b.id, b.name_en
    ORDER BY b.name_en;
END;
$$;


--
-- Name: get_vendor_for_receiving_record(integer, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vendor_for_receiving_record(vendor_id_param integer, branch_id_param bigint) RETURNS TABLE(erp_vendor_id integer, vendor_name text, vat_number text, salesman_name text, salesman_contact text, branch_id bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.erp_vendor_id,
        v.vendor_name,
        v.vat_number,
        v.salesman_name,
        v.salesman_contact,
        v.branch_id
    FROM vendors v
    WHERE v.erp_vendor_id = vendor_id_param
    AND (v.branch_id = branch_id_param OR v.branch_id IS NULL)
    LIMIT 1;
END;
$$;


--
-- Name: FUNCTION get_vendor_for_receiving_record(vendor_id_param integer, branch_id_param bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_vendor_for_receiving_record(vendor_id_param integer, branch_id_param bigint) IS 'Gets vendor details for a receiving record, ensuring branch compatibility';


--
-- Name: get_vendor_pending_summary(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vendor_pending_summary() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  result jsonb;
  vps_paid numeric := 0;
  vps_unpaid numeric := 0;
  exp_paid numeric := 0;
  exp_unpaid numeric := 0;
  vendor_count integer := 0;
  vendors_arr jsonb;
  methods_arr jsonb;
BEGIN
  -- 1. Aggregate totals from vendor_payment_schedule
  SELECT
    COALESCE(SUM(CASE WHEN is_paid THEN final_bill_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN NOT is_paid THEN final_bill_amount ELSE 0 END), 0)
  INTO vps_paid, vps_unpaid
  FROM vendor_payment_schedule;

  -- 2. Aggregate totals from expense_scheduler (vendor expenses only)
  SELECT
    COALESCE(SUM(CASE WHEN is_paid THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN NOT is_paid THEN amount ELSE 0 END), 0)
  INTO exp_paid, exp_unpaid
  FROM expense_scheduler
  WHERE vendor_id IS NOT NULL;

  -- 3. Get distinct vendors by vendor_id only (deduplicated), prefer vps name
  WITH all_vendors AS (
    SELECT vendor_id::text AS vid, vendor_name AS vname, 1 AS priority
    FROM vendor_payment_schedule
    WHERE vendor_id IS NOT NULL AND vendor_name IS NOT NULL
    UNION ALL
    SELECT vendor_id::text AS vid, vendor_name AS vname, 2 AS priority
    FROM expense_scheduler
    WHERE vendor_id IS NOT NULL AND vendor_name IS NOT NULL
  ),
  deduped AS (
    SELECT DISTINCT ON (vid) vid, vname
    FROM all_vendors
    ORDER BY vid, priority, vname
  )
  SELECT
    COUNT(*),
    COALESCE(jsonb_agg(jsonb_build_object('vendor_id', vid, 'vendor_name', vname) ORDER BY vname), '[]'::jsonb)
  INTO vendor_count, vendors_arr
  FROM deduped;

  -- 4. Get distinct payment methods from both tables
--

--
-- Name: get_vendor_promissory_notes_summary(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vendor_promissory_notes_summary(vendor_uuid uuid) RETURNS TABLE(total_notes integer, total_active_amount numeric, total_collected_amount numeric, oldest_active_date date, newest_note_date date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_notes,
        COALESCE(SUM(CASE WHEN status = 'active' THEN amount ELSE 0 END), 0) as total_active_amount,
        COALESCE(SUM(CASE WHEN status = 'collected' THEN amount ELSE 0 END), 0) as total_collected_amount,
        MIN(CASE WHEN status = 'active' THEN signed_date END) as oldest_active_date,
        MAX(signed_date) as newest_note_date
    FROM promissory_notes 
    WHERE vendor_id = vendor_uuid;
END;
$$;


--
-- Name: get_vendor_visits_summary(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vendor_visits_summary(vendor_uuid uuid) RETURNS TABLE(total_visits integer, completed_visits integer, scheduled_visits integer, cancelled_visits integer, last_visit_date date, next_visit_date date, avg_duration_minutes numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_visits,
        COUNT(CASE WHEN status = 'completed' THEN 1 END)::INTEGER as completed_visits,
        COUNT(CASE WHEN status IN ('scheduled', 'confirmed') THEN 1 END)::INTEGER as scheduled_visits,
        COUNT(CASE WHEN status = 'cancelled' THEN 1 END)::INTEGER as cancelled_visits,
        MAX(CASE WHEN status = 'completed' THEN visit_date END) as last_visit_date,
        MIN(CASE WHEN status IN ('scheduled', 'confirmed') AND visit_date >= CURRENT_DATE THEN visit_date END) as next_visit_date,
        AVG(CASE 
            WHEN actual_start_time IS NOT NULL AND actual_end_time IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (actual_end_time - actual_start_time))/60 
            ELSE expected_duration_minutes 
        END)::NUMERIC(10,2) as avg_duration_minutes
    FROM vendor_visits 
    WHERE vendor_id = vendor_uuid;
END;
$$;


--
-- Name: get_vendors_by_branch(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vendors_by_branch(branch_id_param bigint DEFAULT NULL::bigint) RETURNS TABLE(erp_vendor_id integer, vendor_name text, salesman_name text, vendor_contact_number text, payment_method text, status text, branch_id bigint, categories text[], delivery_modes text[], place text, vat_number text, created_at timestamp without time zone, updated_at timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF branch_id_param IS NULL THEN
        -- Return all vendors if no branch specified
        RETURN QUERY
        SELECT 
            v.erp_vendor_id,
            v.vendor_name,
            v.salesman_name,
            v.vendor_contact_number,
            v.payment_method,
            v.status,
            v.branch_id,
            v.categories,
            v.delivery_modes,
            v.place,
            v.vat_number,
            v.created_at,
            v.updated_at
        FROM vendors v
        ORDER BY v.vendor_name;
    ELSE
        -- Return vendors for specific branch
        RETURN QUERY
        SELECT 
            v.erp_vendor_id,
            v.vendor_name,
            v.salesman_name,
            v.vendor_contact_number,
            v.payment_method,
            v.status,
            v.branch_id,
            v.categories,
            v.delivery_modes,
            v.place,
            v.vat_number,
            v.created_at,
            v.updated_at
        FROM vendors v
        WHERE v.branch_id = branch_id_param
        ORDER BY v.vendor_name;
    END IF;
END;
$$;


--
-- Name: get_vendors_with_unpaid_balances(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vendors_with_unpaid_balances() RETURNS TABLE(vendor_id text, vendor_name text, unpaid_payments numeric, unpaid_expenses numeric, total_unpaid numeric)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT 
    COALESCE(vps.vendor_id, es.vendor_id::text) AS vendor_id,
    COALESCE(vps.vendor_name, es.vendor_name) AS vendor_name,
    COALESCE(SUM(CASE WHEN vps.is_paid = false THEN vps.final_bill_amount ELSE 0 END), 0) AS unpaid_payments,
    COALESCE(SUM(CASE WHEN es.is_paid = false THEN es.amount ELSE 0 END), 0) AS unpaid_expenses,
    COALESCE(SUM(CASE WHEN vps.is_paid = false THEN vps.final_bill_amount ELSE 0 END), 0) +
    COALESCE(SUM(CASE WHEN es.is_paid = false THEN es.amount ELSE 0 END), 0) AS total_unpaid
  FROM vendor_payment_schedule vps
  FULL OUTER JOIN expense_scheduler es 
    ON vps.vendor_id::integer = es.vendor_id AND vps.vendor_name = es.vendor_name
  WHERE vps.vendor_id IS NOT NULL OR es.vendor_id IS NOT NULL
  GROUP BY COALESCE(vps.vendor_id, es.vendor_id::text), COALESCE(vps.vendor_name, es.vendor_name)
  ORDER BY total_unpaid DESC;
$$;


--
-- Name: get_vip_redemption_stats(text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_vip_redemption_stats(p_from text DEFAULT NULL::text, p_to text DEFAULT NULL::text, p_branch_id text DEFAULT NULL::text, p_search text DEFAULT NULL::text) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
WITH params AS (
    SELECT
        NULLIF(p_from, '')::date      AS p_from_d,
        NULLIF(p_to, '')::date        AS p_to_d,
        NULLIF(p_branch_id, '')       AS p_branch,
        NULLIF(TRIM(p_search), '')    AS p_q
),
filtered AS (
    SELECT vr.*
    FROM vip_redemptions vr, params
    WHERE (params.p_from_d IS NULL OR vr.redeemed_date >= params.p_from_d)
      AND (params.p_to_d   IS NULL OR vr.redeemed_date <= params.p_to_d)
      AND (params.p_branch IS NULL OR vr.branch_id = params.p_branch)
      AND (
            params.p_q IS NULL
         OR vr.whatsapp_number ILIKE '%' || params.p_q || '%'
         OR vr.bill_number     ILIKE '%' || params.p_q || '%'
          )
)
SELECT json_build_object(
    'total_redemptions',  (SELECT COUNT(*)                                 FROM filtered),
    'today_redemptions',  (SELECT COUNT(*)                                 FROM filtered WHERE redeemed_date = CURRENT_DATE),
    'total_discount',     (SELECT COALESCE(SUM(discounted_value), 0)       FROM filtered),
    'today_discount',     (SELECT COALESCE(SUM(discounted_value), 0)       FROM filtered WHERE redeemed_date = CURRENT_DATE),
    'total_bill_amount',  (SELECT COALESCE(SUM(bill_amount), 0)            FROM filtered),
    'today_bill_amount',  (SELECT COALESCE(SUM(bill_amount), 0)            FROM filtered WHERE redeemed_date = CURRENT_DATE),
    'recent', (
        SELECT COALESCE(json_agg(r ORDER BY r.redeemed_at DESC), '[]'::json)
        FROM (
            SELECT
                f.id,
                f.whatsapp_number,
                f.bill_number,
                f.bill_amount,
                f.discounted_value,
                f.redeemed_date,
                f.redeemed_at,
                f.cashier_id,
                COALESCE(emp.name_en, f.cashier_id, '-') AS cashier_name_en,
                COALESCE(emp.name_ar, f.cashier_id, '-') AS cashier_name_ar,
                f.branch_id,
                br.name_en      AS branch_name_en,
                br.name_ar      AS branch_name_ar,
                br.location_en  AS branch_location_en,
                br.location_ar  AS branch_location_ar
            FROM filtered f
            LEFT JOIN hr_employee_master emp ON emp.user_id::text = f.cashier_id
--

--
-- Name: get_visit_history(date, date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_visit_history(start_date_param date DEFAULT (CURRENT_DATE - '30 days'::interval), end_date_param date DEFAULT CURRENT_DATE, branch_uuid uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, vendor_name text, branch_name text, visit_type text, scheduled_date date, actual_date date, status text, outcome_notes text, completed_by text, duration_minutes integer, next_scheduled_date date, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vh.id,
        v.name::TEXT as vendor_name,
        b.name::TEXT as branch_name,
        vv.visit_type::TEXT,
        vh.scheduled_date,
        vh.actual_date,
        vh.status::TEXT,
        COALESCE(vh.outcome_notes, '')::TEXT,
        COALESCE(vh.completed_by, '')::TEXT,
        vh.duration_minutes,
        vh.next_scheduled_date,
        vh.created_at
    FROM visit_history vh
    JOIN vendor_visits vv ON vh.visit_schedule_id = vv.id
    JOIN vendors v ON vh.vendor_id = v.id
    JOIN branches b ON vh.branch_id = b.id
    WHERE vh.scheduled_date BETWEEN start_date_param AND end_date_param
    AND (branch_uuid IS NULL OR vh.branch_id = branch_uuid)
    ORDER BY vh.scheduled_date DESC, vh.created_at DESC;
END;
$$;


--
-- Name: get_visits_by_date_range(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_visits_by_date_range(start_date date DEFAULT CURRENT_DATE, end_date date DEFAULT CURRENT_DATE) RETURNS TABLE(id uuid, vendor_name text, branch_name text, visit_type text, pattern_info text, notes text, branch_id uuid, vendor_id uuid, weekday_name text, fresh_type text, day_number integer, skip_days integer, start_date_schedule date, next_visit_date date, is_past boolean, is_today boolean, is_future boolean, days_difference integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vv.id,
        v.name::TEXT as vendor_name,
        b.name::TEXT as branch_name,
        vv.visit_type::TEXT,
        CASE 
            WHEN vv.visit_type = 'weekly' THEN ('Weekly on ' || COALESCE(vv.weekday_name, ''))::TEXT
            WHEN vv.visit_type = 'daily' THEN ('Daily (' || COALESCE(vv.fresh_type, '') || ')')::TEXT
            WHEN vv.visit_type = 'monthly' THEN ('Monthly on day ' || COALESCE(vv.day_number::TEXT, ''))::TEXT
            WHEN vv.visit_type = 'skip_days' THEN ('Every ' || COALESCE(vv.skip_days::TEXT, '') || ' days')::TEXT
            ELSE vv.visit_type::TEXT
        END as pattern_info,
        COALESCE(vv.notes, '')::TEXT,
        vv.branch_id,
        vv.vendor_id,
        COALESCE(vv.weekday_name, '')::TEXT,
        COALESCE(vv.fresh_type, '')::TEXT,
        vv.day_number,
        vv.skip_days,
        vv.start_date as start_date_schedule,
        vv.next_visit_date,
        (vv.next_visit_date < CURRENT_DATE) as is_past,
        (vv.next_visit_date = CURRENT_DATE) as is_today,
        (vv.next_visit_date > CURRENT_DATE) as is_future,
        (vv.next_visit_date - CURRENT_DATE)::INTEGER as days_difference
    FROM vendor_visits vv
    JOIN vendors v ON vv.vendor_id = v.id
    JOIN branches b ON vv.branch_id = b.id
    WHERE vv.next_visit_date BETWEEN start_date AND end_date
    AND vv.status = 'active'
    ORDER BY vv.next_visit_date DESC, b.name, v.name;
END;
$$;


--
-- Name: get_visits_by_date_range(date, date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_visits_by_date_range(start_date_param date DEFAULT CURRENT_DATE, end_date_param date DEFAULT (CURRENT_DATE + '7 days'::interval), branch_uuid uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, vendor_name text, branch_name text, visit_type text, next_visit_date date, pattern_config jsonb, notes text, is_active boolean, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vv.id,
        v.name::TEXT as vendor_name,
        b.name::TEXT as branch_name,
        vv.visit_type::TEXT,
        vv.next_visit_date,
        COALESCE(vv.pattern_config, '{}'::jsonb) as pattern_config,
        COALESCE(vv.notes, '')::TEXT,
        COALESCE(vv.is_active, true) as is_active,
        vv.created_at
    FROM vendor_visits vv
    JOIN vendors v ON vv.vendor_id = v.id
    JOIN branches b ON vv.branch_id = b.id
    WHERE vv.next_visit_date BETWEEN start_date_param AND end_date_param
    AND COALESCE(vv.is_active, true) = true
    AND (branch_uuid IS NULL OR vv.branch_id = branch_uuid)
    ORDER BY vv.next_visit_date ASC;
END;
$$;


--
-- Name: get_wa_catalog_stats(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_wa_catalog_stats(p_account_id uuid) RETURNS TABLE(total_catalogs bigint, total_products bigint, active_products bigint, hidden_products bigint, total_orders bigint, pending_orders bigint, total_revenue numeric)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT
        (SELECT count(*) FROM wa_catalogs WHERE wa_account_id = p_account_id),
        (SELECT count(*) FROM wa_catalog_products WHERE wa_account_id = p_account_id),
        (SELECT count(*) FROM wa_catalog_products WHERE wa_account_id = p_account_id AND status = 'active' AND NOT is_hidden),
        (SELECT count(*) FROM wa_catalog_products WHERE wa_account_id = p_account_id AND is_hidden),
        (SELECT count(*) FROM wa_catalog_orders WHERE wa_account_id = p_account_id),
        (SELECT count(*) FROM wa_catalog_orders WHERE wa_account_id = p_account_id AND order_status = 'pending'),
        (SELECT COALESCE(sum(total), 0) FROM wa_catalog_orders WHERE wa_account_id = p_account_id AND order_status NOT IN ('cancelled', 'refunded'));
$$;


--
-- Name: get_wa_contacts(integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_wa_contacts(p_limit integer DEFAULT 100, p_offset integer DEFAULT 0, p_search text DEFAULT NULL::text) RETURNS TABLE(id uuid, name text, whatsapp_number character varying, registration_status text, whatsapp_available boolean, created_at timestamp with time zone, approved_at timestamp with time zone, last_login_at timestamp with time zone, is_deleted boolean, conversation_id uuid, last_message_at timestamp with time zone, last_interaction_at timestamp with time zone, unread_count integer, is_inside_24hr boolean, handled_by text, is_bot_handling boolean, total_count bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $$
  SELECT
    c.id,
    c.name::text AS name,
    c.whatsapp_number,
    c.registration_status,
    c.whatsapp_available,
    c.created_at,
    c.approved_at,
    c.last_login_at,
    COALESCE(c.is_deleted, false) AS is_deleted,
    conv.id AS conversation_id,
    conv.last_message_at,
    GREATEST(conv.last_message_at, code_hist.last_code_at, c.created_at) AS last_interaction_at,
    COALESCE(conv.unread_count, 0)::int AS unread_count,
    CASE
      WHEN conv.last_message_at IS NOT NULL
        AND conv.last_message_at > (now() - interval '24 hours')
      THEN true
      ELSE false
    END AS is_inside_24hr,
    COALESCE(conv.handled_by, 'bot') AS handled_by,
    COALESCE(conv.is_bot_handling, true) AS is_bot_handling,
    COUNT(*) OVER() AS total_count
  FROM customers c
  LEFT JOIN LATERAL (
    SELECT wc.id, wc.last_message_at, wc.unread_count, wc.handled_by, wc.is_bot_handling
    FROM wa_conversations wc
    WHERE wc.customer_phone = c.whatsapp_number
      AND wc.status = 'active'
    ORDER BY wc.created_at DESC
    LIMIT 1
  ) conv ON true
  LEFT JOIN LATERAL (
    SELECT MAX(ach.created_at) AS last_code_at
    FROM customer_access_code_history ach
    WHERE ach.customer_id = c.id
  ) code_hist ON true
  WHERE c.whatsapp_number IS NOT NULL
    AND c.whatsapp_number != ''
    AND COALESCE(c.is_deleted, false) = false
    AND (
      p_search IS NULL
      OR c.name ILIKE '%' || p_search || '%'
      OR c.whatsapp_number ILIKE '%' || p_search || '%'
    )
  ORDER BY GREATEST(conv.last_message_at, code_hist.last_code_at, c.created_at) DESC NULLS LAST
  LIMIT p_limit
  OFFSET p_offset;
--

--
-- Name: get_wa_conversations_fast(uuid, integer, integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_wa_conversations_fast(p_account_id uuid, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_search text DEFAULT NULL::text, p_filter text DEFAULT 'all'::text) RETURNS TABLE(id uuid, customer_phone character varying, customer_name text, last_message_at timestamp with time zone, last_message_preview text, unread_count integer, is_bot_handling boolean, bot_type character varying, handled_by character varying, needs_human boolean, status character varying, is_inside_24hr boolean, is_sos boolean, total_count bigint)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.customer_phone,
        c.customer_name,
        c.last_message_at,
        c.last_message_preview,
        c.unread_count,
        c.is_bot_handling,
        c.bot_type,
        c.handled_by,
        c.needs_human,
        c.status,
        CASE
            WHEN c.last_message_at IS NOT NULL
                 AND c.last_message_at > (NOW() - INTERVAL '24 hours')
            THEN TRUE
            ELSE FALSE
        END AS is_inside_24hr,
        c.is_sos,
        COUNT(*) OVER() AS total_count
    FROM wa_conversations c
    WHERE c.wa_account_id = p_account_id
      AND c.status = 'active'
      -- Exclude priority conversations (SOS / needs_human) ΓÇö they go in their own section
      AND c.is_sos IS NOT TRUE
      AND c.needs_human IS NOT TRUE
      -- Search filter
      AND (
          p_search IS NULL
          OR p_search = ''
          OR c.customer_name ILIKE '%' || p_search || '%'
          OR c.customer_phone ILIKE '%' || p_search || '%'
      )
      -- Chat filter
      AND (
          p_filter = 'all'
          OR (p_filter = 'unread' AND c.unread_count > 0)
          OR (p_filter = 'ai' AND c.is_bot_handling = TRUE AND c.bot_type = 'ai')
          OR (p_filter = 'bot' AND c.is_bot_handling = TRUE AND c.bot_type = 'auto_reply')
          OR (p_filter = 'human' AND c.is_bot_handling = FALSE)
      )
    ORDER BY c.last_message_at DESC NULLS LAST
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;
--

--
-- Name: get_wa_priority_conversations(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_wa_priority_conversations(p_account_id uuid) RETURNS TABLE(id uuid, customer_phone character varying, customer_name text, last_message_at timestamp with time zone, last_message_preview text, unread_count integer, is_bot_handling boolean, bot_type character varying, handled_by character varying, needs_human boolean, status character varying, is_inside_24hr boolean, is_sos boolean, total_count bigint)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.customer_phone,
        c.customer_name,
        c.last_message_at,
        c.last_message_preview,
        c.unread_count,
        c.is_bot_handling,
        c.bot_type,
        c.handled_by,
        c.needs_human,
        c.status,
        CASE
            WHEN c.last_message_at IS NOT NULL
                 AND c.last_message_at > (NOW() - INTERVAL '24 hours')
            THEN TRUE
            ELSE FALSE
        END AS is_inside_24hr,
        c.is_sos,
        COUNT(*) OVER() AS total_count
    FROM wa_conversations c
    WHERE c.wa_account_id = p_account_id
      AND c.status = 'active'
      AND (c.is_sos = TRUE OR c.needs_human = TRUE)
    ORDER BY
        CASE WHEN c.is_sos = TRUE THEN 0 ELSE 1 END ASC,
        c.last_message_at DESC NULLS LAST;
END;
$$;


--
-- Name: gift_wheel_check_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gift_wheel_check_status() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    settings_row gift_wheel_settings%ROWTYPE;
    spins_today integer;
    now_riyadh timestamptz;
    result jsonb;
BEGIN
    SELECT * INTO settings_row FROM gift_wheel_settings LIMIT 1;

    IF settings_row IS NULL THEN
        RETURN jsonb_build_object('active', false, 'reason', 'not_configured');
    END IF;

    IF NOT settings_row.active THEN
        RETURN jsonb_build_object('active', false, 'reason', 'disabled');
    END IF;

    now_riyadh := now() AT TIME ZONE settings_row.timezone;

    -- Check scheduled time
    IF settings_row.start_datetime IS NOT NULL AND now() < settings_row.start_datetime THEN
        RETURN jsonb_build_object('active', false, 'reason', 'not_started');
    END IF;

    IF settings_row.end_datetime IS NOT NULL AND now() > settings_row.end_datetime THEN
        RETURN jsonb_build_object('active', false, 'reason', 'ended');
    END IF;

    -- Check daily limit
    SELECT count(*) INTO spins_today
    FROM gift_wheel_spins
    WHERE (created_at AT TIME ZONE settings_row.timezone)::date = now_riyadh::date
      AND rejected = false;

    IF spins_today >= settings_row.daily_limit THEN
        RETURN jsonb_build_object('active', false, 'reason', 'daily_limit_reached', 'spins_today', spins_today);
    END IF;

    RETURN jsonb_build_object(
        'active', true,
        'spins_today', spins_today,
        'daily_limit', settings_row.daily_limit,
        'remaining', settings_row.daily_limit - spins_today
    );
END;
$$;


--
-- Name: gift_wheel_dashboard_stats(date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gift_wheel_dashboard_stats(p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    from_date date;
    to_date date;
    result jsonb;
    daily_data jsonb;
    reward_dist jsonb;
BEGIN
    from_date := COALESCE(p_from, CURRENT_DATE);
    to_date := COALESCE(p_to, CURRENT_DATE);

    SELECT jsonb_build_object(
        'total_spins', count(*) FILTER (WHERE rejected = false),
        'total_spins_today', count(*) FILTER (WHERE rejected = false AND (created_at AT TIME ZONE 'Asia/Riyadh')::date = CURRENT_DATE),
        'unique_bills', count(DISTINCT bill_number) FILTER (WHERE rejected = false),
        'winning_spins', count(*) FILTER (WHERE is_winner = true AND rejected = false),
        'losing_spins', count(*) FILTER (WHERE is_winner = false AND rejected = false),
        'rejected_bills', count(*) FILTER (WHERE rejected = true)
    ) INTO result
    FROM gift_wheel_spins
    WHERE (created_at AT TIME ZONE 'Asia/Riyadh')::date BETWEEN from_date AND to_date;

    -- Coupon stats
    SELECT result || jsonb_build_object(
        'coupons_printed', count(*) FILTER (WHERE printed_at IS NOT NULL),
        'coupons_redeemed', count(*) FILTER (WHERE redeemed_at IS NOT NULL),
        'coupons_active', count(*) FILTER (WHERE status = 'active'),
        'coupons_expired', count(*) FILTER (WHERE status = 'expired')
    ) INTO result
    FROM gift_wheel_coupons
    WHERE created_at::date BETWEEN from_date AND to_date;

    -- Reward distribution
    SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO reward_dist
    FROM (
        SELECT jsonb_build_object(
            'label', reward_label,
            'count', count(*)
        ) as row_data
        FROM gift_wheel_spins
        WHERE rejected = false
          AND (created_at AT TIME ZONE 'Asia/Riyadh')::date BETWEEN from_date AND to_date
        GROUP BY reward_label
        ORDER BY count(*) DESC
    ) sub;

    result := result || jsonb_build_object('reward_distribution', reward_dist);

--

--
-- Name: gift_wheel_redeem_coupon(text, text, text, text, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gift_wheel_redeem_coupon(p_code text, p_action text DEFAULT 'print'::text, p_branch_id text DEFAULT NULL::text, p_redeemed_bill_number text DEFAULT NULL::text, p_redeemed_amount numeric DEFAULT NULL::numeric) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    coupon_row gift_wheel_coupons%ROWTYPE;
BEGIN
    SELECT * INTO coupon_row FROM gift_wheel_coupons WHERE code = trim(p_code);

    IF coupon_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon not found');
    END IF;

    IF coupon_row.status = 'redeemed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon already redeemed');
    END IF;

    IF coupon_row.expiry_date IS NOT NULL AND coupon_row.expiry_date < CURRENT_DATE THEN
        UPDATE gift_wheel_coupons SET status = 'expired' WHERE id = coupon_row.id;
        RETURN jsonb_build_object('success', false, 'error', 'Coupon has expired');
    END IF;

    IF p_action = 'print' THEN
        UPDATE gift_wheel_coupons SET status = 'printed', printed_at = now(), branch_id = p_branch_id WHERE id = coupon_row.id;
        RETURN jsonb_build_object('success', true, 'action', 'printed');
    ELSIF p_action = 'redeem' THEN
        UPDATE gift_wheel_coupons SET status = 'redeemed', redeemed_at = now(), redeemed_bill_number = p_redeemed_bill_number, redeemed_amount = p_redeemed_amount, branch_id = COALESCE(p_branch_id, branch_id) WHERE id = coupon_row.id;
        RETURN jsonb_build_object('success', true, 'action', 'redeemed');
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid action');
    END IF;
END;
$$;


--
-- Name: gift_wheel_spin(text, numeric, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gift_wheel_spin(p_bill_number text, p_bill_amount numeric, p_bill_image_url text DEFAULT NULL::text, p_bill_date text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    settings_row gift_wheel_settings%ROWTYPE;
    spins_today integer;
    now_riyadh timestamptz;
    existing_spin gift_wheel_spins%ROWTYPE;
    eligible_rewards gift_wheel_rewards[];
    reward_row gift_wheel_rewards%ROWTYPE;
    total_weight integer;
    random_val integer;
    cumulative integer;
    coupon_code_val text;
    new_coupon_id uuid;
    computed_expiry date;
BEGIN
    -- Get settings
    SELECT * INTO settings_row FROM gift_wheel_settings LIMIT 1;

    IF settings_row IS NULL OR NOT settings_row.active THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel is not active');
    END IF;

    now_riyadh := now() AT TIME ZONE settings_row.timezone;

    -- Validate bill date = today
    IF p_bill_date IS NOT NULL AND p_bill_date != to_char(now_riyadh, 'YYYY-MM-DD') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Your chance has expired', 'error_code', 'bill_date_expired');
    END IF;

    -- Check scheduled time
    IF settings_row.start_datetime IS NOT NULL AND now() < settings_row.start_datetime THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel has not started yet');
    END IF;

    IF settings_row.end_datetime IS NOT NULL AND now() > settings_row.end_datetime THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel has ended');
    END IF;

    -- Check daily limit
    SELECT count(*) INTO spins_today
    FROM gift_wheel_spins
    WHERE (created_at AT TIME ZONE settings_row.timezone)::date = now_riyadh::date
      AND rejected = false;

    IF spins_today >= settings_row.daily_limit THEN
        RETURN jsonb_build_object('success', false, 'error', 'Daily limit reached. Please try again tomorrow');
    END IF;

--

--
-- Name: gift_wheel_spin(text, numeric, text, text, boolean, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gift_wheel_spin(p_bill_number text, p_bill_amount numeric, p_bill_image_url text DEFAULT NULL::text, p_bill_date text DEFAULT NULL::text, p_manual_entry boolean DEFAULT false, p_manual_entry_by uuid DEFAULT NULL::uuid, p_manual_entry_username text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
    settings_row gift_wheel_settings%ROWTYPE;
    spins_today integer;
    now_riyadh timestamptz;
    existing_spin gift_wheel_spins%ROWTYPE;
    eligible_rewards gift_wheel_rewards[];
    reward_row gift_wheel_rewards%ROWTYPE;
    total_weight integer;
    random_val integer;
    cumulative integer;
    coupon_code_val text;
    new_coupon_id uuid;
    computed_expiry date;
BEGIN
    SELECT * INTO settings_row FROM gift_wheel_settings LIMIT 1;

    IF settings_row IS NULL OR NOT settings_row.active THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel is not active');
    END IF;

    now_riyadh := now() AT TIME ZONE settings_row.timezone;

    IF p_bill_date IS NOT NULL AND p_bill_date != to_char(now_riyadh, 'YYYY-MM-DD') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Your chance has expired', 'error_code', 'bill_date_expired');
    END IF;

    IF settings_row.start_datetime IS NOT NULL AND now() < settings_row.start_datetime THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel has not started yet');
    END IF;

    IF settings_row.end_datetime IS NOT NULL AND now() > settings_row.end_datetime THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gift Wheel has ended');
    END IF;

    SELECT count(*) INTO spins_today
    FROM gift_wheel_spins
    WHERE (created_at AT TIME ZONE settings_row.timezone)::date = now_riyadh::date
      AND rejected = false;

    IF spins_today >= settings_row.daily_limit THEN
        RETURN jsonb_build_object('success', false, 'error', 'Daily limit reached. Please try again tomorrow');
    END IF;

    SELECT * INTO existing_spin FROM gift_wheel_spins WHERE bill_number = p_bill_number AND bill_amount = p_bill_amount AND rejected = false LIMIT 1;
    IF existing_spin.id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'This bill with the same amount has already been used');
    END IF;
--

--
-- Name: gift_wheel_validate_coupon(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gift_wheel_validate_coupon(p_code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    coupon_row gift_wheel_coupons%ROWTYPE;
BEGIN
    SELECT * INTO coupon_row FROM gift_wheel_coupons WHERE code = trim(p_code);

    IF coupon_row.id IS NULL THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Coupon not found');
    END IF;

    IF coupon_row.status = 'redeemed' THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Coupon already redeemed',
            'code', coupon_row.code,
            'reward_label', coupon_row.reward_label,
            'reward_label_en', coupon_row.reward_label_en,
            'reward_label_ar', coupon_row.reward_label_ar,
            'reward_type', coupon_row.reward_type,
            'reward_value', coupon_row.reward_value,
            'max_discount', coupon_row.max_discount,
            'expiry_date', coupon_row.expiry_date,
            'status', coupon_row.status,
            'bill_number', coupon_row.bill_number,
            'bill_amount', coupon_row.bill_amount,
            'bill_date', coupon_row.bill_date,
            'redeemed_bill_number', coupon_row.redeemed_bill_number,
            'redeemed_amount', coupon_row.redeemed_amount,
            'redeemed_at', coupon_row.redeemed_at
        );
    END IF;

    IF coupon_row.status = 'expired' OR (coupon_row.expiry_date IS NOT NULL AND coupon_row.expiry_date < CURRENT_DATE) THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Coupon has expired');
    END IF;

    IF coupon_row.status = 'cancelled' THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Coupon has been cancelled');
    END IF;

    RETURN jsonb_build_object(
        'valid', true,
        'code', coupon_row.code,
        'reward_label', coupon_row.reward_label,
        'reward_label_en', coupon_row.reward_label_en,
        'reward_label_ar', coupon_row.reward_label_ar,
        'reward_type', coupon_row.reward_type,
        'reward_value', coupon_row.reward_value,
--

--
-- Name: handle_document_deactivation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_document_deactivation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- If document is being deactivated, clear the main document columns
    IF OLD.is_active = TRUE AND NEW.is_active = FALSE THEN
        IF NEW.document_type = 'health_card' THEN
            NEW.health_card_number := NULL;
            NEW.health_card_expiry := NULL;
        ELSIF NEW.document_type = 'resident_id' THEN
            NEW.resident_id_number := NULL;
            NEW.resident_id_expiry := NULL;
        ELSIF NEW.document_type = 'passport' THEN
            NEW.passport_number := NULL;
            NEW.passport_expiry := NULL;
        ELSIF NEW.document_type = 'driving_license' THEN
            NEW.driving_license_number := NULL;
            NEW.driving_license_expiry := NULL;
        ELSIF NEW.document_type = 'resume' THEN
            NEW.resume_uploaded := FALSE;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: handle_order_task_completion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_order_task_completion() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_task RECORD;
    v_order RECORD;
    v_notification_id UUID;
    v_admin_user RECORD;
    v_notif_title TEXT;
    v_notif_message TEXT;
    v_finish_task_id UUID;
BEGIN
    -- Only proceed if status changed to 'completed'
    IF NEW.status <> 'completed' OR OLD.status = 'completed' THEN
        RETURN NEW;
    END IF;

    -- Get the task details
    SELECT * INTO v_task FROM quick_tasks WHERE id = NEW.quick_task_id;
    
    -- Only handle order-related tasks
    IF v_task.order_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Get the order
    SELECT * INTO v_order FROM orders WHERE id = v_task.order_id;
    
    IF v_order IS NULL THEN
        RETURN NEW;
    END IF;

    -- Update quick_tasks status to completed too
    UPDATE quick_tasks SET status = 'completed', completed_at = NOW(), updated_at = NOW() WHERE id = v_task.id;

    -- ==========================================
    -- STEP 1: Start Picking completed
    -- ==========================================
    IF v_task.issue_type = 'order-start-picking' THEN
        -- Update order status to in_picking (Preparing)
        UPDATE orders SET 
            order_status = 'in_picking',
            updated_at = NOW()
        WHERE id = v_order.id;

        -- Log audit: picking started/preparing
        INSERT INTO order_audit_logs (order_id, action_type, from_status, to_status, performed_by, notes)
        VALUES (v_order.id, 'status_change', v_order.order_status, 'in_picking', NEW.assigned_to_user_id, 
                'Start picking completed - preparing order');

        -- Auto-create "Finish Picking" task for the same picker
--

--
-- Name: has_order_management_access(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_order_management_access(user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users u
        LEFT JOIN user_roles ur ON u.position_id::text = ur.role_code
        WHERE u.id = user_id
        AND (
            -- Use boolean flags instead of role_type
            u.is_admin = true 
            OR u.is_master_admin = true
            OR ur.role_code IN (
                'CEO',
                'OPERATIONS_MANAGER',
                'BRANCH_MANAGER',
                'CUSTOMER_SERVICE_SUPERVISOR',
                'NIGHT_SUPERVISORS',
                'IT_SYSTEMS_MANAGER'
            )
        )
    );
END;
$$;


--
-- Name: FUNCTION has_order_management_access(user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.has_order_management_access(user_id uuid) IS 'Check if user has management-level access to orders (Admin, Master Admin, CEO, Operations Manager, Branch Manager, Customer Service Supervisor, Night Supervisors, IT Systems Manager)';


--
-- Name: hash_password(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hash_password(password text, salt text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN crypt(password, salt);
END;
$$;


--
-- Name: heartbeat_cashier_session(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heartbeat_cashier_session(p_user_id uuid, p_session_token text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_current text;
BEGIN
    SELECT session_token INTO v_current
    FROM public.cashier_device_bindings
    WHERE user_id = p_user_id;

    IF v_current IS NULL OR v_current <> p_session_token THEN
        RETURN jsonb_build_object('success', false, 'valid', false);
    END IF;

    UPDATE public.cashier_device_bindings
       SET last_seen_at = now()
     WHERE user_id = p_user_id
       AND session_token = p_session_token;

    RETURN jsonb_build_object('success', true, 'valid', true);
END;
$$;


--
-- Name: import_sync_batch(text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.import_sync_batch(p_table_name text, p_data jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE 
    v_count integer := 0;
    v_allowed_tables text[] := ARRAY[
        'branches', 'users', 'user_sessions', 'user_device_sessions',
        'button_permissions', 'sidebar_buttons', 'button_main_sections', 'button_sub_sections',
        'interface_permissions', 'user_favorite_buttons',
        'erp_synced_products', 'product_categories', 'products', 'product_units',
        'offers', 'offer_products', 'offer_names', 'offer_bundles', 'offer_cart_tiers',
        'bogo_offer_rules', 'flyer_offers', 'flyer_offer_products',
        'customers', 'privilege_cards_master', 'privilege_cards_branch',
        'desktop_themes', 'user_theme_assignments',
        'erp_connections', 'erp_sync_logs'
    ];
BEGIN
    IF NOT (p_table_name = ANY(v_allowed_tables)) THEN
        RAISE EXCEPTION 'Table % is not allowed for sync import', p_table_name;
    END IF;

    IF p_data IS NULL OR jsonb_array_length(p_data) = 0 THEN 
        RETURN 0; 
    END IF;

    -- Disable FK constraint triggers
    PERFORM set_config('session_replication_role', 'replica', true);
    
    -- Insert with OVERRIDING SYSTEM VALUE to handle GENERATED ALWAYS identity columns
    EXECUTE format(
        'INSERT INTO %I OVERRIDING SYSTEM VALUE SELECT * FROM jsonb_populate_recordset(null::%I, $1)',
        p_table_name, p_table_name
    ) USING p_data;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    -- Re-enable
    PERFORM set_config('session_replication_role', 'origin', true);
    
    RETURN v_count;
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('session_replication_role', 'origin', true);
    RAISE;
END;
$_$;


--
-- Name: increment_ai_token_usage(uuid, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_ai_token_usage(config_id uuid, p_tokens integer, p_prompt integer, p_completion integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  UPDATE wa_ai_bot_config SET
    tokens_used = COALESCE(tokens_used, 0) + p_tokens,
    prompt_tokens_used = COALESCE(prompt_tokens_used, 0) + p_prompt,
    completion_tokens_used = COALESCE(completion_tokens_used, 0) + p_completion,
    total_requests = COALESCE(total_requests, 0) + 1
  WHERE id = config_id;
END;
$$;


--
-- Name: increment_flyer_template_usage(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_flyer_template_usage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE flyer_templates
  SET 
    usage_count = usage_count + 1,
    last_used_at = now()
  WHERE id = NEW.template_id;
  
  RETURN NEW;
END;
$$;


--
-- Name: increment_page_visit_count(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_page_visit_count(offer_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE view_offer
  SET page_visit_count = page_visit_count + 1
  WHERE id = offer_id;
END;
$$;


--
-- Name: increment_social_link_click(bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_social_link_click(_branch_id bigint, _platform text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_count BIGINT;
BEGIN
  IF _platform = 'facebook' THEN
    UPDATE social_links SET facebook_clicks = facebook_clicks + 1 WHERE branch_id = _branch_id;
    SELECT facebook_clicks INTO v_count FROM social_links WHERE branch_id = _branch_id;
  ELSIF _platform = 'whatsapp' THEN
    UPDATE social_links SET whatsapp_clicks = whatsapp_clicks + 1 WHERE branch_id = _branch_id;
    SELECT whatsapp_clicks INTO v_count FROM social_links WHERE branch_id = _branch_id;
  ELSIF _platform = 'instagram' THEN
    UPDATE social_links SET instagram_clicks = instagram_clicks + 1 WHERE branch_id = _branch_id;
    SELECT instagram_clicks INTO v_count FROM social_links WHERE branch_id = _branch_id;
  ELSIF _platform = 'tiktok' THEN
    UPDATE social_links SET tiktok_clicks = tiktok_clicks + 1 WHERE branch_id = _branch_id;
    SELECT tiktok_clicks INTO v_count FROM social_links WHERE branch_id = _branch_id;
  ELSIF _platform = 'snapchat' THEN
    UPDATE social_links SET snapchat_clicks = snapchat_clicks + 1 WHERE branch_id = _branch_id;
    SELECT snapchat_clicks INTO v_count FROM social_links WHERE branch_id = _branch_id;
  ELSIF _platform = 'website' THEN
    UPDATE social_links SET website_clicks = website_clicks + 1 WHERE branch_id = _branch_id;
    SELECT website_clicks INTO v_count FROM social_links WHERE branch_id = _branch_id;
  ELSIF _platform = 'location_link' THEN
    UPDATE social_links SET location_link_clicks = location_link_clicks + 1 WHERE branch_id = _branch_id;
    SELECT location_link_clicks INTO v_count FROM social_links WHERE branch_id = _branch_id;
  END IF;

  RETURN json_build_object('branch_id', _branch_id, 'platform', _platform, 'click_count', v_count);
END;
$$;


--
-- Name: increment_view_button_count(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_view_button_count(offer_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE view_offer
  SET view_button_count = view_button_count + 1
  WHERE id = offer_id;
END;
$$;


--
-- Name: initiate_loyalty_redemption(text, numeric, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.initiate_loyalty_redemption(p_phone text, p_points_to_redeem numeric, p_redemption_type text, p_cashier_id text DEFAULT NULL::text, p_branch_id text DEFAULT NULL::text, p_erp_branch_id text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_normalized  text;
    v_customer    record;
    v_tier        record;
    v_available   numeric(14,2);
    v_otp         text;
    v_coupon_code text;
    v_redemp_id   uuid;
BEGIN
    v_normalized := regexp_replace(p_phone, '\D', '', 'g');
    IF v_normalized LIKE '0%' THEN
        v_normalized := '966' || substring(v_normalized FROM 2);
    ELSIF NOT v_normalized LIKE '966%' THEN
        v_normalized := '966' || v_normalized;
    END IF;

    SELECT id, name, whatsapp_number,
           COALESCE(total_points_earned, 0) AS total_points_earned,
           COALESCE(total_redemptions, 0)   AS total_redemptions,
           loyalty_tier_id, registration_status
    INTO v_customer
    FROM public.customers
    WHERE whatsapp_number = v_normalized AND is_deleted = false
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'customer_not_found');
    END IF;

    IF v_customer.registration_status != 'approved' THEN
        RETURN jsonb_build_object('success', false, 'error', 'customer_not_approved');
    END IF;

    v_available := v_customer.total_points_earned - v_customer.total_redemptions;

    SELECT COALESCE(min_redeem_points, 0) AS min_redeem_points
    INTO v_tier
    FROM public.loyalty_tiers
    WHERE id = v_customer.loyalty_tier_id
    LIMIT 1;

    IF v_available <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'no_points_available');
    END IF;

    IF v_available < COALESCE(v_tier.min_redeem_points, 0) THEN
        RETURN jsonb_build_object('success', false, 'error', 'below_minimum',
--

--
-- Name: insert_order_items(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_order_items(p_order_items jsonb) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_count integer;
  v_error_msg text;
BEGIN
  -- Log input
  RAISE NOTICE 'insert_order_items called with % items', jsonb_array_length(p_order_items);
  
  INSERT INTO order_items (
    order_id,
    product_id,
    product_name_ar,
    product_name_en,
    quantity,
    unit_price,
    original_price,
    discount_amount,
    final_price,
    line_total,
    has_offer,
    offer_id,
    item_type,
    is_bundle_item,
    is_bogo_free
  )
  SELECT
    (item->>'order_id')::uuid,
    item->>'product_id',
    item->>'product_name_ar',
    item->>'product_name_en',
    (item->>'quantity')::integer,
    (item->>'unit_price')::numeric,
    (item->>'original_price')::numeric,
    (item->>'discount_amount')::numeric,
    (item->>'final_price')::numeric,
    (item->>'line_total')::numeric,
    (item->>'has_offer')::boolean,
    CASE 
      WHEN item->>'offer_id' IS NULL OR item->>'offer_id' = 'null' THEN NULL::integer
      ELSE (item->>'offer_id')::integer
    END,
    item->>'item_type',
    (item->>'is_bundle_item')::boolean,
    (item->>'is_bogo_free')::boolean
  FROM jsonb_array_elements(p_order_items) AS item;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE NOTICE 'Inserted % order items', v_count;
  
--

--
-- Name: insert_vendor_from_excel(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_vendor_from_excel(p_erp_vendor_code character varying, p_vendor_name character varying, p_vat_number character varying DEFAULT NULL::character varying) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    vendor_id UUID;
BEGIN
    INSERT INTO public.vendors (
        erp_vendor_code,
        name,
        vat_number,
        company,
        category,
        status
    ) VALUES (
        p_erp_vendor_code,
        p_vendor_name,
        p_vat_number,
        COALESCE(p_vendor_name, 'Unknown Company'),
        'General',
        'active'
    )
    ON CONFLICT (erp_vendor_code) 
    DO UPDATE SET
        name = EXCLUDED.name,
        vat_number = EXCLUDED.vat_number,
        company = EXCLUDED.company,
        updated_at = NOW()
    RETURNING id INTO vendor_id;
    
    RETURN vendor_id;
END;
$$;


--
-- Name: insert_vendor_from_excel(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_vendor_from_excel(p_erp_vendor_code character varying, p_vendor_name_english character varying, p_vendor_name_arabic character varying DEFAULT NULL::character varying, p_vat_number character varying DEFAULT NULL::character varying) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    vendor_id UUID;
    vendor_company CHARACTER VARYING(255);
BEGIN
    -- Use English name as company if provided, otherwise use the main vendor name
    vendor_company := COALESCE(p_vendor_name_english, p_vendor_name_arabic, 'Unknown Company');
    
    -- Insert vendor with Excel column mapping
    INSERT INTO public.vendors (
        erp_vendor_code,
        name,
        name_ar,
        vat_number,
        company,
        tax_id,
        category,
        status,
        payment_terms
    ) VALUES (
        p_erp_vendor_code,
        COALESCE(p_vendor_name_english, p_vendor_name_arabic),
        p_vendor_name_arabic,
        p_vat_number,
        vendor_company,
        p_vat_number, -- Map VAT number to tax_id as well
        'General',
        'active',
        'N/A'
    )
    ON CONFLICT (erp_vendor_code) 
    DO UPDATE SET
        name = EXCLUDED.name,
        name_ar = EXCLUDED.name_ar,
        vat_number = EXCLUDED.vat_number,
        company = EXCLUDED.company,
        tax_id = EXCLUDED.tax_id,
        payment_terms = EXCLUDED.payment_terms,
        updated_at = NOW()
    RETURNING id INTO vendor_id;
    
    RETURN vendor_id;
END;
$$;


--
-- Name: is_current_user_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_current_user_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND (u.is_master_admin = true OR u.is_admin = true)
  );
$$;


--
-- Name: is_delivery_staff(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_delivery_staff(user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users u
        LEFT JOIN user_roles ur ON u.position_id::text = ur.role_code
        WHERE u.id = user_id
        AND ur.role_code IN ('DELIVERY_STAFF', 'DRIVER')
    );
END;
$$;


--
-- Name: FUNCTION is_delivery_staff(user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_delivery_staff(user_id uuid) IS 'Check if user is delivery staff (Delivery Staff, Driver)';


--
-- Name: is_overnight_shift(time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_overnight_shift(start_time time without time zone, end_time time without time zone) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    RETURN start_time > end_time;
END;
$$;


--
-- Name: is_product_in_active_bundle(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_product_in_active_bundle(p_product_id uuid, p_exclude_offer_id integer DEFAULT NULL::integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_found BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1
        FROM offer_bundles ob
        INNER JOIN offers o ON ob.offer_id = o.id
        WHERE o.is_active = true
          AND o.end_date > NOW()
          AND (p_exclude_offer_id IS NULL OR o.id != p_exclude_offer_id)
          AND ob.required_products::jsonb @> jsonb_build_array(
              jsonb_build_object('product_id', p_product_id::text)
          )
    ) INTO v_found;
    
    RETURN v_found;
END;
$$;


--
-- Name: is_quick_access_code_available(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_quick_access_code_available(p_quick_access_code text) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
BEGIN
    -- Validate format first
    IF LENGTH(p_quick_access_code) != 6 OR p_quick_access_code !~ '^[0-9]{6}$' THEN
        RETURN false;
    END IF;
    
    -- Check if code exists
    RETURN NOT EXISTS (SELECT 1 FROM users WHERE quick_access_code = p_quick_access_code);
END;
$_$;


--
-- Name: is_quick_access_code_available(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_quick_access_code_available(p_quick_access_code character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1 FROM users
    WHERE extensions.crypt(p_quick_access_code, quick_access_code) = quick_access_code
  );
END;
$$;


--
-- Name: is_user_admin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_user_admin(check_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  user_is_master_admin BOOLEAN;
  user_is_admin BOOLEAN;
BEGIN
  SELECT is_master_admin, is_admin
  INTO user_is_master_admin, user_is_admin
  FROM users
  WHERE id = check_user_id;
  
  RETURN COALESCE(user_is_master_admin, false) OR COALESCE(user_is_admin, false);
END;
$$;


--
-- Name: is_user_master_admin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_user_master_admin(check_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  user_is_master_admin BOOLEAN;
BEGIN
  SELECT is_master_admin
  INTO user_is_master_admin
  FROM users
  WHERE id = check_user_id;
  
  RETURN COALESCE(user_is_master_admin, false);
END;
$$;


--
-- Name: link_finger_transaction_to_employee(character varying, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.link_finger_transaction_to_employee(p_employee_code character varying, p_branch_id uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_employee_id UUID;
BEGIN
    -- Find employee by employee_code and branch
    SELECT e.id INTO v_employee_id
    FROM public.employees e
    WHERE e.employee_id = p_employee_code
    AND e.branch_id = p_branch_id
    AND e.status = 'active';
    
    RETURN v_employee_id;
END;
$$;


--
-- Name: list_salary_statements(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_salary_statements() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_rows jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(r ORDER BY r.updated_at DESC), '[]'::jsonb) INTO v_rows
    FROM (
        SELECT id, statement_name, start_date, end_date, created_at, updated_at
        FROM public.hr_salary_statements
        ORDER BY updated_at DESC
    ) r;
    RETURN jsonb_build_object('success', true, 'items', v_rows);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


--
-- Name: log_offer_usage(integer, uuid, integer, numeric, numeric, numeric, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_offer_usage(p_offer_id integer, p_customer_id uuid, p_order_id integer, p_discount_applied numeric, p_original_amount numeric, p_final_amount numeric, p_cart_items jsonb DEFAULT NULL::jsonb) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_log_id INTEGER;
BEGIN
    -- Insert usage log
    INSERT INTO offer_usage_logs (
        offer_id, customer_id, order_id,
        discount_applied, original_amount, final_amount,
        cart_items
    ) VALUES (
        p_offer_id, p_customer_id, p_order_id,
        p_discount_applied, p_original_amount, p_final_amount,
        p_cart_items
    ) RETURNING id INTO v_log_id;
    
    -- Increment offer usage counter
    UPDATE offers
    SET current_total_uses = current_total_uses + 1
    WHERE id = p_offer_id;
    
    -- Update customer_offers if customer-specific
    UPDATE customer_offers
    SET is_used = true,
        used_at = NOW(),
        usage_count = usage_count + 1
    WHERE offer_id = p_offer_id AND customer_id = p_customer_id;
    
    RETURN v_log_id;
END;
$$;


--
-- Name: log_user_action(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_user_action() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO user_audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values,
        created_at
    ) VALUES (
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id
            ELSE NEW.id
        END,
        TG_OP,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id
            ELSE NEW.id
        END,
        CASE 
            WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD)
            WHEN TG_OP = 'DELETE' THEN row_to_json(OLD)
            ELSE NULL
        END,
        CASE 
            WHEN TG_OP = 'INSERT' THEN row_to_json(NEW)
            WHEN TG_OP = 'UPDATE' THEN row_to_json(NEW)
            ELSE NULL
        END,
        now()
    );
    
    RETURN CASE 
        WHEN TG_OP = 'DELETE' THEN OLD
        ELSE NEW
    END;
END;
$$;


--
-- Name: mark_overdue_quick_tasks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_overdue_quick_tasks() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Mark main tasks as overdue
    UPDATE quick_tasks 
    SET status = 'overdue', updated_at = NOW()
    WHERE deadline_datetime < NOW() 
    AND status NOT IN ('completed', 'overdue');
    
    -- Mark individual assignments as overdue
    UPDATE quick_task_assignments
    SET status = 'overdue', updated_at = NOW()
    WHERE quick_task_id IN (
        SELECT id FROM quick_tasks 
        WHERE deadline_datetime < NOW()
    )
    AND status NOT IN ('completed', 'overdue');
END;
$$;


--
-- Name: notify_branches_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_branches_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM pg_notify(
        'branches_changed',
        json_build_object(
            'operation', TG_OP,
            'id', COALESCE(NEW.id, OLD.id),
            'timestamp', NOW()
        )::text
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: notify_customer_order_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_customer_order_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_order RECORD;
    v_customer_id UUID;
    v_title TEXT;
    v_body TEXT;
    v_url TEXT;
    v_type TEXT;
    v_service_role_key TEXT;
    v_supabase_url TEXT;
    v_request_id BIGINT;
BEGIN
    -- Only handle status_change actions
    IF NEW.action_type <> 'status_change' THEN
        RETURN NEW;
    END IF;

    -- Get the order with customer_id
    SELECT id, order_number, customer_id, customer_name, fulfillment_method
    INTO v_order
    FROM orders
    WHERE id = NEW.order_id;

    IF v_order IS NULL OR v_order.customer_id IS NULL THEN
        RETURN NEW;
    END IF;

    v_customer_id := v_order.customer_id;

    -- Check if this customer has any active push subscriptions
    IF NOT EXISTS (
        SELECT 1 FROM push_subscriptions 
        WHERE customer_id = v_customer_id AND is_active = true
    ) THEN
        RETURN NEW;
    END IF;

    -- Build bilingual push notification content (Arabic primary)
    CASE NEW.to_status
        WHEN 'accepted' THEN
            v_title := '╪¬┘à ┘é╪¿┘ê┘ä ╪╖┘ä╪¿┘â Γ£à';
            v_body := '╪¬┘à ┘é╪¿┘ê┘ä ╪╖┘ä╪¿┘â ╪▒┘é┘à #' || v_order.order_number || ' ┘ê╪¼╪º╪▒┘è ╪¬╪¼┘ç┘è╪▓┘ç.' || chr(10) || 'Your order #' || v_order.order_number || ' has been accepted.';
            v_type := 'order_accepted';
        WHEN 'in_picking' THEN
            v_title := '╪¼╪º╪▒┘è ╪¬╪¡╪╢┘è╪▒ ╪╖┘ä╪¿┘â ≡ƒôª';
            v_body := '╪╖┘ä╪¿┘â ╪▒┘é┘à #' || v_order.order_number || ' ┘é┘è╪» ╪º┘ä╪¬╪¡╪╢┘è╪▒ ╪º┘ä╪ó┘å.' || chr(10) || 'Your order #' || v_order.order_number || ' is being prepared.';
            v_type := 'order_picking';
        WHEN 'ready' THEN
            IF v_order.fulfillment_method = 'pickup' THEN
--

--
-- Name: notify_erp_daily_sales_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_erp_daily_sales_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM pg_notify(
        'erp_daily_sales_changed',
        json_build_object(
            'operation', TG_OP,
            'id', COALESCE(NEW.id, OLD.id),
            'sale_date', COALESCE(NEW.sale_date, OLD.sale_date),
            'timestamp', extract(epoch from now())
        )::text
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: process_clearance_certificate_generation(uuid, text, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_clearance_certificate_generation(receiving_record_id_param uuid, clearance_certificate_url_param text, generated_by_user_id uuid, generated_by_name text DEFAULT NULL::text, generated_by_role text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_tasks_created INT := 0;
  v_notifications_sent INT := 0;
  v_receiving_record RECORD;
  v_template RECORD;
  v_task_id UUID;
  v_title TEXT;
  v_description TEXT;
  v_due_date TIMESTAMP;
  v_assigned_user_id UUID;
  v_notification_id UUID;
  v_user_idx INT;
  v_array_len INT;
BEGIN

  -- =======================================================
  -- STEP 1: PREVENT DUPLICATE TASK CREATION
  -- =======================================================
  IF EXISTS (
    SELECT 1 FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Tasks already exist for this receiving record',
      'error_code', 'DUPLICATE_TASKS',
      'tasks_created', 0,
      'notifications_sent', 0
    );
  END IF;

  -- =======================================================
  -- STEP 2: LOAD RECEIVING RECORD WITH RELATED DATA
  -- =======================================================
  SELECT
    rr.*,
    v.vendor_name,
    b.name_en as branch_name,
    COALESCE(emp.name, u.username) as received_by_name
  INTO v_receiving_record
  FROM receiving_records rr
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  LEFT JOIN users u ON u.id = rr.user_id
  LEFT JOIN hr_employees emp ON emp.id = u.employee_id
  WHERE rr.id = receiving_record_id_param;

  IF NOT FOUND THEN
--

--
-- Name: process_customer_recovery(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_customer_recovery(p_request_id uuid, p_admin_user_id uuid, p_action text, p_notes text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_request_record record;
    v_admin_name text;
    v_new_access_code text;
    v_current_time timestamp with time zone := now();
    result json;
BEGIN
    -- Validate admin user
    SELECT username INTO v_admin_name
    FROM public.users
    WHERE id = p_admin_user_id
    AND status = 'active';
    
    IF v_admin_name IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invalid admin user'
        );
    END IF;
    
    -- Validate action
    IF p_action NOT IN ('approve', 'reject') THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Action must be either "approve" or "reject"'
        );
    END IF;
    
    -- Get recovery request details
    SELECT 
        r.id,
        r.customer_id,
        r.customer_name,
        r.whatsapp_number,
        r.verification_status,
        r.request_type
    INTO v_request_record
    FROM public.customer_recovery_requests r
    WHERE r.id = p_request_id
    AND r.verification_status = 'pending';
    
    IF v_request_record.id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Recovery request not found or already processed'
        );
    END IF;
    
--

--
-- Name: process_finger_transaction_linking(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_finger_transaction_linking() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Link with employee if not already set
    IF NEW.employee_id IS NULL THEN
        NEW.employee_id := link_finger_transaction_to_employee(
            NEW.employee_code,
            NEW.branch_id
        );
    END IF;
    
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: queue_push_notification(uuid, text, jsonb, text[], uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.queue_push_notification(p_notification_id uuid, p_target_type text, p_target_users jsonb DEFAULT NULL::jsonb, p_target_roles text[] DEFAULT NULL::text[], p_target_branches uuid[] DEFAULT NULL::uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_record RECORD;
    subscription_record RECORD;
    notification_data RECORD;
BEGIN
    -- Get notification data
    SELECT 
        title,
        body,
        type,
        created_at
    INTO notification_data
    FROM notifications 
    WHERE id = p_notification_id;
    
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    -- Process based on target type
    CASE p_target_type
        WHEN 'all_users' THEN
            -- Queue for all active users with push subscriptions
            FOR subscription_record IN 
                SELECT DISTINCT ps.user_id, ps.endpoint, ps.p256dh, ps.auth
                FROM push_subscriptions ps
                JOIN users u ON ps.user_id = u.id
                WHERE u.status = 'active'
                  AND ps.status = 'active'
            LOOP
                INSERT INTO notification_queue (
                    notification_id,
                    user_id,
                    endpoint,
                    p256dh,
                    auth,
                    payload,
                    status,
                    created_at
                ) VALUES (
                    p_notification_id,
                    subscription_record.user_id,
                    subscription_record.endpoint,
                    subscription_record.p256dh,
                    subscription_record.auth,
                    jsonb_build_object(
                        'title', notification_data.title,
                        'body', notification_data.body,
--

--
-- Name: queue_quick_task_push_notifications(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.queue_quick_task_push_notifications() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_record RECORD;
    notification_payload jsonb;
BEGIN
    -- Only process if this is a task assignment notification
    IF NEW.type = 'task_assignment' AND NEW.target_users IS NOT NULL THEN
        -- Extract assignment details from metadata
        notification_payload := jsonb_build_object(
            'title', NEW.title,
            'body', NEW.message,
            'icon', '/favicon.ico',
            'badge', '/favicon.ico',
            'data', jsonb_build_object(
                'notificationId', NEW.id,
                'type', NEW.type,
                'quick_task_id', (NEW.metadata->>'quick_task_id'),
                'assignment_details', (NEW.metadata->>'assignment_details'),
                'url', '/mobile/quick-task'
            )
        );

        -- Queue push notifications for each target user
        FOR user_record IN 
            SELECT DISTINCT jsonb_array_elements_text(NEW.target_users) as user_id
        LOOP
            INSERT INTO notification_queue (
                notification_id,
                user_id,
                status,
                payload,
                created_at
            ) VALUES (
                NEW.id,
                user_record.user_id::uuid,
                'pending',
                notification_payload,
                NOW()
            );
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION queue_quick_task_push_notifications(); Type: COMMENT; Schema: public; Owner: -
--

--
-- Name: reassign_receiving_task(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reassign_receiving_task(receiving_task_id_param uuid, new_assigned_user_id uuid, reassigned_by_user_id text, reassignment_reason text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    receiving_task RECORD;
    new_assignment_id UUID;
    response JSONB;
BEGIN
    -- Get the current receiving task
    SELECT * INTO receiving_task 
    FROM receiving_tasks 
    WHERE id = receiving_task_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving task not found: %', receiving_task_id_param;
    END IF;
    
    -- Check if reassignment is allowed for this task type
    IF NOT receiving_task.requires_reassignment THEN
        RAISE EXCEPTION 'This task type does not allow reassignment';
    END IF;
    
    -- Reassign the task assignment
    SELECT reassign_task(
        receiving_task.assignment_id,
        new_assigned_user_id::TEXT,
        NULL, -- branch_id
        reassigned_by_user_id,
        reassignment_reason
    ) INTO new_assignment_id;
    
    -- Update the receiving task with new assignment
    UPDATE receiving_tasks 
    SET 
        assignment_id = new_assignment_id,
        assigned_user_id = new_assigned_user_id,
        updated_at = now()
    WHERE id = receiving_task_id_param;
    
    -- Create notification for new assignee
    INSERT INTO notifications (
        title, message, created_by, created_by_name,
        target_type, target_users, type, priority,
        task_id, task_assignment_id, has_attachments,
        metadata
    ) VALUES (
        'Task Reassigned to You',
        format('A %s task has been reassigned to you. Reason: %s', 
               receiving_task.role_type, 
               COALESCE(reassignment_reason, 'No reason provided')),
        reassigned_by_user_id, 'System',
--

--
-- Name: reassign_task(uuid, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reassign_task(assignment_id uuid, new_assignee uuid, reassigned_by uuid, reason text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE task_assignments 
    SET 
        assigned_to = new_assignee,
        reassigned_by = reassigned_by,
        reassignment_reason = reason,
        updated_at = NOW()
    WHERE id = assignment_id;
    
    RETURN FOUND;
END;
$$;


--
-- Name: reassign_task(uuid, text, text, uuid, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reassign_task(p_assignment_id uuid, p_reassigned_by text, p_new_user_id text DEFAULT NULL::text, p_new_branch_id uuid DEFAULT NULL::uuid, p_reassignment_reason text DEFAULT NULL::text, p_copy_deadline boolean DEFAULT true) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_assignment_id UUID;
    original_assignment RECORD;
BEGIN
    -- Get original assignment details
    SELECT * INTO original_assignment 
    FROM public.task_assignments 
    WHERE id = p_assignment_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assignment not found: %', p_assignment_id;
    END IF;
    
    IF NOT original_assignment.is_reassignable THEN
        RAISE EXCEPTION 'Assignment is not reassignable: %', p_assignment_id;
    END IF;
    
    -- Create new assignment
    INSERT INTO public.task_assignments (
        task_id,
        assignment_type,
        assigned_to_user_id,
        assigned_to_branch_id,
        assigned_by,
        assigned_by_name,
        schedule_date,
        schedule_time,
        deadline_date,
        deadline_time,
        is_reassignable,
        notes,
        priority_override,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        reassigned_from,
        reassignment_reason,
        reassigned_at
    ) VALUES (
        original_assignment.task_id,
        original_assignment.assignment_type,
        p_new_user_id,
        p_new_branch_id,
        p_reassigned_by,
        NULL, -- Will be filled by the application
        CASE WHEN p_copy_deadline THEN original_assignment.schedule_date ELSE NULL END,
        CASE WHEN p_copy_deadline THEN original_assignment.schedule_time ELSE NULL END,
        CASE WHEN p_copy_deadline THEN original_assignment.deadline_date ELSE NULL END,
--

--
-- Name: record_fine_payment(uuid, numeric, character varying, character varying, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_fine_payment(warning_id_param uuid, payment_amount_param numeric, payment_method_param character varying, payment_reference_param character varying, processed_by_param uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    payment_id UUID;
    total_paid DECIMAL(10,2);
    fine_amount DECIMAL(10,2);
BEGIN
    -- Get the fine amount
    SELECT ew.fine_amount INTO fine_amount
    FROM employee_warnings ew
    WHERE ew.id = warning_id_param;
    
    -- Insert payment record
    INSERT INTO employee_fine_payments (
        warning_id, payment_amount, payment_method, 
        payment_reference, processed_by
    ) VALUES (
        warning_id_param, payment_amount_param, payment_method_param,
        payment_reference_param, processed_by_param
    ) RETURNING id INTO payment_id;
    
    -- Calculate total paid
    SELECT COALESCE(SUM(payment_amount), 0) INTO total_paid
    FROM employee_fine_payments
    WHERE warning_id = warning_id_param;
    
    -- Update warning status based on payment
    UPDATE employee_warnings
    SET 
        fine_paid_amount = total_paid,
        fine_status = CASE 
            WHEN total_paid >= fine_amount THEN 'paid'
            WHEN total_paid > 0 THEN 'partial'
            ELSE 'pending'
        END,
        fine_paid_date = CASE 
            WHEN total_paid >= fine_amount THEN CURRENT_TIMESTAMP
            ELSE fine_paid_date
        END,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = warning_id_param;
    
    RETURN payment_id;
END;
$$;


--
-- Name: refresh_broadcast_status(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_broadcast_status(p_broadcast_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_total int;
    v_sent_count int;
    v_delivered_count int;
    v_read_count int;
    v_failed_count int;
    v_pending_count int;
    v_broadcast_status text;
    v_old_status text;
BEGIN
    -- Step 1: Update broadcast recipients whose wa_messages have a higher status
    UPDATE wa_broadcast_recipients r
    SET status = sub.new_status
    FROM (
        SELECT 
            r2.id AS recipient_id,
            (
                SELECT m.status
                FROM wa_messages m
                WHERE m.whatsapp_message_id = r2.whatsapp_message_id
                ORDER BY 
                    CASE m.status
                        WHEN 'read' THEN 3
                        WHEN 'delivered' THEN 2
                        WHEN 'sent' THEN 1
                        ELSE 0
                    END DESC
                LIMIT 1
            ) AS new_status
        FROM wa_broadcast_recipients r2
        WHERE r2.broadcast_id = p_broadcast_id
          AND r2.whatsapp_message_id IS NOT NULL
    ) sub
    WHERE r.id = sub.recipient_id
      AND sub.new_status IS NOT NULL
      AND (
          CASE sub.new_status
              WHEN 'read' THEN 3
              WHEN 'delivered' THEN 2
              WHEN 'sent' THEN 1
              ELSE 0
          END
      ) > (
          CASE r.status
              WHEN 'read' THEN 3
              WHEN 'delivered' THEN 2
              WHEN 'sent' THEN 1
--

--
-- Name: refresh_edge_functions_cache(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_edge_functions_cache(p_functions jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  DELETE FROM public.edge_functions_cache;
  INSERT INTO public.edge_functions_cache (func_name, func_size, file_count, last_modified, has_index, func_code)
  SELECT
    (f->>'func_name')::text,
    (f->>'func_size')::text,
    (f->>'file_count')::int,
    to_timestamp((f->>'last_modified')::bigint),
    (f->>'has_index')::boolean,
    (f->>'func_code')::text
  FROM jsonb_array_elements(p_functions) AS f;
END;
$$;


--
-- Name: refresh_expiry_cache(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_expiry_cache() RETURNS void
    LANGUAGE sql
    AS $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_expiry_products;
$$;


--
-- Name: refresh_user_roles_from_positions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_user_roles_from_positions() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    roles_updated INTEGER := 0;
BEGIN
    -- Insert new roles from positions that don't exist yet
    INSERT INTO user_roles (role_name, role_code, description, is_system_role)
    SELECT 
        hp.position_title_en,
        UPPER(REPLACE(REPLACE(hp.position_title_en, ' ', '_'), '/', '_')),
        CONCAT('Access level for ', hp.position_title_en, ' position'),
        false
    FROM hr_positions hp
    WHERE hp.position_title_en IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM user_roles ur 
        WHERE ur.role_name = hp.position_title_en
    );
    
    GET DIAGNOSTICS roles_updated = ROW_COUNT;
    
    -- Update existing roles to ensure they're active
    UPDATE user_roles 
    SET is_active = true, updated_at = NOW()
    WHERE role_name IN (
        SELECT position_title_en 
        FROM hr_positions 
        WHERE position_title_en IS NOT NULL
    )
    AND is_system_role = false;
    
    RETURN roles_updated;
END;
$$;


--
-- Name: register_app_function(text, text, text, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.register_app_function(p_function_name text, p_function_code text, p_description text DEFAULT NULL::text, p_category text DEFAULT 'Application'::text, p_enabled boolean DEFAULT true) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_id UUID;
BEGIN
    -- Check if function already exists
    IF EXISTS (SELECT 1 FROM app_functions WHERE function_code = p_function_code) THEN
        -- Update existing function
        UPDATE app_functions 
        SET function_name = p_function_name,
            description = COALESCE(p_description, description),
            category = p_category,
            is_active = p_enabled,
            updated_at = CURRENT_TIMESTAMP
        WHERE function_code = p_function_code
        RETURNING id INTO new_id;
        
        RETURN new_id;
    ELSE
        -- Insert new function
        INSERT INTO app_functions (function_name, function_code, description, category, is_active)
        VALUES (p_function_name, p_function_code, p_description, p_category, p_enabled)
        RETURNING id INTO new_id;
        
        RETURN new_id;
    END IF;
END;
$$;


--
-- Name: register_push_subscription(uuid, character varying, text, text, text, character varying, character varying, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.register_push_subscription(p_user_id uuid, p_device_id character varying, p_endpoint text, p_p256dh text, p_auth text, p_device_type character varying DEFAULT 'desktop'::character varying, p_browser_name character varying DEFAULT NULL::character varying, p_user_agent text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    subscription_id UUID;
BEGIN
    -- Try to update existing subscription first
    UPDATE push_subscriptions 
    SET 
        endpoint = p_endpoint,
        p256dh = p_p256dh,
        auth = p_auth,
        device_type = p_device_type,
        browser_name = p_browser_name,
        user_agent = p_user_agent,
        is_active = true,
        last_seen = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id AND device_id = p_device_id
    RETURNING id INTO subscription_id;
    
    -- If no existing subscription found, create new one
    IF subscription_id IS NULL THEN
        INSERT INTO push_subscriptions (
            user_id,
            device_id,
            endpoint,
            p256dh,
            auth,
            device_type,
            browser_name,
            user_agent,
            is_active,
            last_seen,
            created_at,
            updated_at
        ) VALUES (
            p_user_id,
            p_device_id,
            p_endpoint,
            p_p256dh,
            p_auth,
            p_device_type,
            p_browser_name,
            p_user_agent,
            true,
            NOW(),
            NOW(),
            NOW()
        ) RETURNING id INTO subscription_id;
    END IF;
--

--
-- Name: register_system_role(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.register_system_role(p_role_name text, p_role_code text, p_description text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_role_id UUID;
BEGIN
    INSERT INTO user_roles (role_name, role_code, description, is_system_role)
    VALUES (p_role_name, p_role_code, p_description, true)
    ON CONFLICT (role_name) DO UPDATE SET
        role_code = p_role_code,
        description = p_description,
        updated_at = NOW()
    RETURNING id INTO new_role_id;
    
    RETURN new_role_id;
END;
$$;


--
-- Name: release_cashier_session(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.release_cashier_session(p_user_id uuid, p_session_token text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    DELETE FROM public.cashier_device_bindings
     WHERE user_id = p_user_id
       AND session_token = p_session_token;

    RETURN jsonb_build_object('success', true);
END;
$$;


--
-- Name: request_access_code_change(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_access_code_change(p_email character varying, p_whatsapp character varying) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_otp VARCHAR(6);
  v_whatsapp_clean VARCHAR(20);
BEGIN
  -- Clean WhatsApp number (remove spaces, dashes)
  v_whatsapp_clean := REGEXP_REPLACE(p_whatsapp, '[\s\-]', '', 'g');

  -- Find the user by matching email AND whatsapp_number in hr_employee_master
  -- Correct relationship: hr_employee_master.user_id = users.id
  SELECT u.id INTO v_user_id
  FROM users u
  JOIN hr_employee_master e ON e.user_id = u.id
  WHERE LOWER(TRIM(e.email)) = LOWER(TRIM(p_email))
    AND REGEXP_REPLACE(e.whatsapp_number, '[\s\-]', '', 'g') = v_whatsapp_clean
    AND u.status = 'active'
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'No matching user found. Please check your email and WhatsApp number.'
    );
  END IF;

  -- Rate limit: max 3 OTP requests per hour per user
  IF (
    SELECT COUNT(*) FROM access_code_otp
    WHERE user_id = v_user_id
      AND created_at > NOW() - INTERVAL '1 hour'
  ) >= 3 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Too many requests. Please try again later.'
    );
  END IF;

  -- Delete any existing unused OTPs for this user
  DELETE FROM access_code_otp WHERE user_id = v_user_id AND verified = false;

  -- Generate 6-digit OTP
  v_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');

  -- Store OTP (expires in 5 minutes)
  INSERT INTO access_code_otp (user_id, otp_code, email, whatsapp_number, expires_at)
  VALUES (v_user_id, v_otp, p_email, v_whatsapp_clean, NOW() + INTERVAL '5 minutes');

--

--
-- Name: request_access_code_resend(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_access_code_resend(p_whatsapp_number text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
    v_customer record;
    v_new_access_code text;
    v_hashed_new_code text;
    v_system_user_id uuid := 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b';
BEGIN
    SELECT id, name, access_code, registration_status, whatsapp_number
    INTO v_customer
    FROM public.customers
    WHERE whatsapp_number = p_whatsapp_number
       OR whatsapp_number = '+' || p_whatsapp_number
       OR regexp_replace(whatsapp_number, '[^0-9]', '', 'g') = regexp_replace(p_whatsapp_number, '[^0-9]', '', 'g')
    LIMIT 1;
    
    IF v_customer.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_found',
            'message', 'No account found with this WhatsApp number.');
    END IF;
    
    IF v_customer.registration_status != 'approved' THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_approved',
            'message', 'Your account is not active. Please register again or contact support.');
    END IF;
    
    -- Generate NEW code (can't retrieve hashed one)
    v_new_access_code := generate_unique_customer_access_code();
    v_hashed_new_code := encode(digest(v_new_access_code::bytea, 'sha256'), 'hex');

    UPDATE public.customers
    SET access_code = v_hashed_new_code,
        access_code_generated_at = now(),
        updated_at = now()
    WHERE id = v_customer.id;

    INSERT INTO public.customer_access_code_history (
        customer_id, old_access_code, new_access_code,
        generated_by, reason, notes
    ) VALUES (
        v_customer.id, v_customer.access_code, v_hashed_new_code,
        v_system_user_id, 'customer_request', 'Customer requested code resend (new code generated)'
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'customer_id', v_customer.id,
        'access_code', v_new_access_code,
        'whatsapp_number', v_customer.whatsapp_number,
--

--
-- Name: request_new_access_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_new_access_code(p_whatsapp_number text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_customer_id uuid;
    v_customer_name text;
    v_current_time timestamp with time zone := now();
    v_request_id uuid;
    result json;
BEGIN
    -- Validate input
    IF p_whatsapp_number IS NULL OR trim(p_whatsapp_number) = '' THEN
        RETURN json_build_object(
            'success', false,
            'error', 'WhatsApp number is required'
        );
    END IF;
    
    -- Clean WhatsApp number (remove non-digits)
    p_whatsapp_number := regexp_replace(p_whatsapp_number, '[^0-9]', '', 'g');
    
    -- Add country code if not present (assume Saudi +966 for 9-digit numbers)
    IF length(p_whatsapp_number) = 9 THEN
        p_whatsapp_number := '966' || p_whatsapp_number;
    END IF;
    
    -- Find customer by WhatsApp number (check both formats: with and without +)
    SELECT 
        id,
        name
    INTO 
        v_customer_id,
        v_customer_name
    FROM public.customers
    WHERE (whatsapp_number = p_whatsapp_number 
           OR whatsapp_number = '+' || p_whatsapp_number
           OR regexp_replace(whatsapp_number, '[^0-9]', '', 'g') = p_whatsapp_number)
    AND registration_status = 'approved'
    LIMIT 1;
    
    -- Check if customer exists
    IF v_customer_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'No approved customer account found with this WhatsApp number. Please contact support if you believe this is an error.'
        );
    END IF;
    
    -- Create recovery request record
    BEGIN
        INSERT INTO public.customer_recovery_requests (
--

--
-- Name: request_server_restart(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_server_restart() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Write a trigger file to the shared volume (PG data dir)
  -- Host path: /opt/supabase/supabase/docker/volumes/db/data/restart_trigger
  -- Container path: /var/lib/postgresql/data/restart_trigger
  COPY (SELECT 'restart_requested_at_' || now()::text) 
    TO '/var/lib/postgresql/data/restart_trigger';
  
  RETURN 'Restart requested successfully. Services will restart within 30 seconds.';
END;
$$;


--
-- Name: reschedule_visit(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reschedule_visit(visit_id uuid, new_date date) RETURNS date
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the visit with the new date
    UPDATE vendor_visits 
    SET next_visit_date = new_date, updated_at = NOW()
    WHERE id = visit_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Visit schedule not found with id: %', visit_id;
    END IF;
    
    RETURN new_date;
END;
$$;


--
-- Name: save_hr_employee_rule_periods(text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_hr_employee_rule_periods(p_employee_id text, p_rule_type text, p_periods jsonb DEFAULT '[]'::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_join_date date;
    v_item jsonb;
    v_seq integer := 0;
    v_start_date date;
    v_end_date date;
    v_rule_id bigint;
    v_is_infinite boolean;
    v_duration_years integer;
    v_duration_months integer;
    v_rule public.settlement_rules%ROWTYPE;
    v_active_rule_id bigint;
    v_active_rule public.settlement_rules%ROWTYPE;
    v_total_months integer;
    v_cycle_months integer;
    v_completed_cycles integer;
    v_qualified integer;
BEGIN
    IF p_employee_id IS NULL OR BTRIM(p_employee_id) = '' THEN
        RAISE EXCEPTION 'p_employee_id is required';
    END IF;

    IF p_rule_type NOT IN ('ticket', 'leave_salary') THEN
        RAISE EXCEPTION 'p_rule_type must be ticket or leave_salary';
    END IF;

    SELECT e.join_date INTO v_join_date
    FROM public.hr_employee_master e
    WHERE e.id = p_employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee % was not found', p_employee_id;
    END IF;

    DELETE FROM public.hr_employee_applicability_rule_periods
    WHERE employee_id = p_employee_id
      AND rule_type = p_rule_type;

    IF p_periods IS NULL OR jsonb_typeof(p_periods) <> 'array' OR jsonb_array_length(p_periods) = 0 THEN
        INSERT INTO public.hr_employee_settlement_applicability (employee_id)
        VALUES (p_employee_id)
        ON CONFLICT (employee_id) DO NOTHING;

        IF p_rule_type = 'ticket' THEN
            UPDATE public.hr_employee_settlement_applicability
            SET
                ticket_rule_id = NULL,
--

--
-- Name: search_tasks(text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_tasks(search_query text, user_id_param text DEFAULT NULL::text, limit_param integer DEFAULT 50, offset_param integer DEFAULT 0) RETURNS TABLE(id uuid, title text, description text, require_task_finished boolean, require_photo_upload boolean, require_erp_reference boolean, can_escalate boolean, can_reassign boolean, created_by text, created_by_name text, status text, priority text, created_at timestamp with time zone, updated_at timestamp with time zone, due_date date, due_time time without time zone, rank real)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id, t.title, t.description, t.require_task_finished, t.require_photo_upload, t.require_erp_reference,
        t.can_escalate, t.can_reassign, t.created_by, t.created_by_name, t.status, t.priority,
        t.created_at, t.updated_at, t.due_date, t.due_time,
        ts_rank(t.search_vector, plainto_tsquery('english', search_query)) as rank
    FROM public.tasks t
    WHERE t.deleted_at IS NULL
    AND (
        search_query IS NULL 
        OR search_query = '' 
        OR t.search_vector @@ plainto_tsquery('english', search_query)
        OR t.title ILIKE '%' || search_query || '%'
        OR t.description ILIKE '%' || search_query || '%'
    )
    ORDER BY 
        CASE WHEN search_query IS NOT NULL AND search_query != '' 
        THEN ts_rank(t.search_vector, plainto_tsquery('english', search_query)) 
        ELSE 0 END DESC,
        t.created_at DESC
    LIMIT limit_param OFFSET offset_param;
END;
$$;


--
-- Name: search_tasks(text, text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_tasks(search_term text DEFAULT NULL::text, task_status text DEFAULT NULL::text, assigned_user_id uuid DEFAULT NULL::uuid, created_by_user_id uuid DEFAULT NULL::uuid) RETURNS TABLE(id uuid, title character varying, description text, status character varying, priority character varying, assigned_to uuid, created_by uuid, created_at timestamp with time zone, updated_at timestamp with time zone, due_date date, assignee_name character varying, creator_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.title,
        t.description,
        t.status,
        t.priority,
        ta.assigned_to,
        t.created_by,
        t.created_at,
        t.updated_at,
        t.due_date,
        COALESCE(u_assignee.username, 'Unassigned')::VARCHAR as assignee_name,
        COALESCE(u_creator.username, 'Unknown')::VARCHAR as creator_name
    FROM tasks t
    LEFT JOIN task_assignments ta ON t.id = ta.task_id
    LEFT JOIN users u_assignee ON ta.assigned_to = u_assignee.id
    LEFT JOIN users u_creator ON t.created_by = u_creator.id
    WHERE (search_term IS NULL OR t.title ILIKE '%' || search_term || '%' OR t.description ILIKE '%' || search_term || '%')
      AND (task_status IS NULL OR t.status = task_status)
      AND (assigned_user_id IS NULL OR ta.assigned_to = assigned_user_id)
      AND (created_by_user_id IS NULL OR t.created_by = created_by_user_id)
      AND t.deleted_at IS NULL
    ORDER BY t.created_at DESC;
END;
$$;


--
-- Name: select_random_product(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.select_random_product(p_campaign_id uuid) RETURNS TABLE(id uuid, product_name_en character varying, product_name_ar character varying, product_image_url text, original_price numeric, offer_price numeric, special_barcode character varying, stock_remaining integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.product_name_en,
    p.product_name_ar,
    p.product_image_url,
    p.original_price,
    p.offer_price,
    p.special_barcode,
    p.stock_remaining
  FROM coupon_products p
  WHERE p.campaign_id = p_campaign_id
    AND p.is_active = true
    AND p.stock_remaining > 0
    AND p.deleted_at IS NULL
  ORDER BY RANDOM()
  LIMIT 1
  FOR UPDATE SKIP LOCKED;
END;
$$;


--
-- Name: send_order_notification(uuid, text, text, text, text, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.send_order_notification(p_order_id uuid, p_title text, p_message text, p_type text DEFAULT 'info'::text, p_priority text DEFAULT 'medium'::text, p_performed_by uuid DEFAULT NULL::uuid, p_target_user_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_notification_id UUID;
    v_admin_user RECORD;
BEGIN
    INSERT INTO notifications (
        title, message, type, created_by, created_by_name, created_by_role,
        priority, status, target_type, target_roles, sent_at
    ) VALUES (
        p_title, p_message, p_type,
        COALESCE(p_performed_by::text, 'system'), 'System', 'System',
        p_priority, 'published',
        CASE WHEN p_target_user_id IS NOT NULL THEN 'specific_users' ELSE 'role_based' END,
        to_jsonb(ARRAY['Admin', 'Master Admin']),
        NOW()
    ) RETURNING id INTO v_notification_id;

    -- If targeting a specific user
    IF p_target_user_id IS NOT NULL THEN
        INSERT INTO notification_recipients (notification_id, user_id, role, is_read, delivery_status)
        VALUES (v_notification_id, p_target_user_id, 'User', FALSE, 'delivered');
    END IF;

    -- Always notify admins
    FOR v_admin_user IN
        SELECT id,
               CASE WHEN is_master_admin THEN 'Master Admin'
                    WHEN is_admin THEN 'Admin'
                    ELSE 'User' END as role_type
        FROM users
        WHERE status = 'active' AND (is_admin = true OR is_master_admin = true)
        AND id <> COALESCE(p_target_user_id, '00000000-0000-0000-0000-000000000000'::uuid)
    LOOP
        INSERT INTO notification_recipients (notification_id, user_id, role, is_read, delivery_status)
        VALUES (v_notification_id, v_admin_user.id, v_admin_user.role_type, FALSE, 'delivered');
    END LOOP;

    RETURN v_notification_id;
END;
$$;


--
-- Name: set_background_templates_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_background_templates_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;


--
-- Name: set_hr_salary_notes_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_hr_salary_notes_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;


--
-- Name: set_user_context(uuid, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_user_context(user_id uuid, is_master_admin boolean DEFAULT false, is_admin boolean DEFAULT false) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- Set configuration variables that RLS policies can access
  PERFORM set_config('app.current_user_id', user_id::text, false);
  PERFORM set_config('app.is_master_admin', is_master_admin::text, false);
  PERFORM set_config('app.is_admin', is_admin::text, false);
END;
$$;


--
-- Name: set_user_erp_credentials_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_user_erp_credentials_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: set_vip_redemptions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_vip_redemptions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: setup_role_permissions(text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.setup_role_permissions(p_role_code text, p_permissions jsonb DEFAULT '{"can_add": false, "can_edit": false, "can_view": true, "can_delete": false, "can_export": false}'::jsonb) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_role_id UUID;
    func_record RECORD;
    permissions_set INTEGER := 0;
BEGIN
    -- Get role ID
    SELECT id INTO v_role_id FROM user_roles WHERE role_code = p_role_code;
    
    IF v_role_id IS NULL THEN
        RAISE NOTICE 'Role % not found', p_role_code;
        RETURN 0;
    END IF;
    
    -- Set permissions for all active functions
    FOR func_record IN SELECT id FROM app_functions WHERE is_active = true LOOP
        INSERT INTO role_permissions (
            role_id, 
            function_id, 
            can_view, 
            can_add, 
            can_edit, 
            can_delete, 
            can_export
        ) VALUES (
            v_role_id, 
            func_record.id,
            COALESCE((p_permissions->>'can_view')::BOOLEAN, false),
            COALESCE((p_permissions->>'can_add')::BOOLEAN, false),
            COALESCE((p_permissions->>'can_edit')::BOOLEAN, false),
            COALESCE((p_permissions->>'can_delete')::BOOLEAN, false),
            COALESCE((p_permissions->>'can_export')::BOOLEAN, false)
        ) ON CONFLICT (role_id, function_id) DO UPDATE SET
            can_view = COALESCE((p_permissions->>'can_view')::BOOLEAN, false),
            can_add = COALESCE((p_permissions->>'can_add')::BOOLEAN, false),
            can_edit = COALESCE((p_permissions->>'can_edit')::BOOLEAN, false),
            can_delete = COALESCE((p_permissions->>'can_delete')::BOOLEAN, false),
            can_export = COALESCE((p_permissions->>'can_export')::BOOLEAN, false),
            updated_at = NOW();
        
        permissions_set := permissions_set + 1;
    END LOOP;
    
    RETURN permissions_set;
END;
$$;


--
-- Name: skip_visit(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.skip_visit(visit_id uuid, skip_reason text DEFAULT ''::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the record to mark as handled (no date change for skip)
    UPDATE vendor_visits 
    SET updated_at = NOW()
    WHERE id = visit_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Visit schedule not found with id: %', visit_id;
    END IF;
    
    -- Note: In a full system, you might want to log this skip in a separate visits_log table
    -- For now, we just return success
    RETURN TRUE;
END;
$$;


--
-- Name: soft_delete_flyer_template(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.soft_delete_flyer_template(template_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  is_default_template BOOLEAN;
BEGIN
  -- Check if it's the default template
  SELECT is_default INTO is_default_template
  FROM flyer_templates
  WHERE id = template_id;
  
  -- Prevent deletion of default template
  IF is_default_template = true THEN
    RAISE EXCEPTION 'Cannot delete the default template. Please set another template as default first.';
  END IF;
  
  -- Soft delete
  UPDATE flyer_templates
  SET 
    deleted_at = now(),
    is_active = false
  WHERE id = template_id
    AND deleted_at IS NULL;
  
  RETURN FOUND;
END;
$$;


--
-- Name: start_break(uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.start_break(p_user_id uuid, p_reason_id integer, p_reason_note text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_emp RECORD;
  v_existing UUID;
  v_break_id UUID;
BEGIN
  -- Check for already-open break
  SELECT id INTO v_existing
  FROM break_register
  WHERE user_id = p_user_id AND status = 'open'
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You already have an open break', 'break_id', v_existing);
  END IF;

  -- Get employee info
  SELECT id, name_en, name_ar, current_branch_id
  INTO v_emp
  FROM hr_employee_master
  WHERE user_id = p_user_id
  LIMIT 1;

  IF v_emp IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Employee record not found');
  END IF;

  -- Insert break
  INSERT INTO break_register (user_id, employee_id, employee_name_en, employee_name_ar, branch_id, reason_id, reason_note, start_time, status)
  VALUES (p_user_id, v_emp.id, v_emp.name_en, v_emp.name_ar, v_emp.current_branch_id, p_reason_id, p_reason_note, NOW(), 'open')
  RETURNING id INTO v_break_id;

  RETURN jsonb_build_object('success', true, 'break_id', v_break_id);
END;
$$;


--
-- Name: submit_quick_task_completion(uuid, uuid, text, text[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.submit_quick_task_completion(p_assignment_id uuid, p_user_id uuid, p_completion_notes text DEFAULT NULL::text, p_photos text[] DEFAULT NULL::text[], p_erp_reference text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_quick_task_id uuid;
    v_completion_id uuid;
    v_existing_completion_id uuid;
    v_require_photo boolean;
    v_require_erp boolean;
    v_assignment_record RECORD;
BEGIN
    -- Get the assignment details including requirements
    SELECT 
        qta.quick_task_id,
        qta.require_photo_upload,
        qta.require_erp_reference,
        qta.status
    INTO v_assignment_record
    FROM quick_task_assignments qta
    WHERE qta.id = p_assignment_id;

    -- Check if assignment exists
    IF v_assignment_record.quick_task_id IS NULL THEN
        RAISE EXCEPTION 'Assignment not found with ID: %', p_assignment_id;
    END IF;

    -- Check if assignment is already completed
    IF v_assignment_record.status = 'completed' THEN
        RAISE EXCEPTION 'This assignment is already completed';
    END IF;

    v_quick_task_id := v_assignment_record.quick_task_id;
    v_require_photo := v_assignment_record.require_photo_upload;
    v_require_erp := v_assignment_record.require_erp_reference;

    -- ====================================================================
    -- VALIDATE COMPLETION REQUIREMENTS
    -- ====================================================================
    
    -- Check if photo is required but not provided
    IF v_require_photo = true AND (p_photos IS NULL OR array_length(p_photos, 1) IS NULL OR array_length(p_photos, 1) = 0) THEN
        RAISE EXCEPTION 'Photo upload is required for this task. Please upload at least one photo before completing.';
    END IF;
    
    -- Check if ERP reference is required but not provided
    IF v_require_erp = true AND (p_erp_reference IS NULL OR trim(p_erp_reference) = '') THEN
        RAISE EXCEPTION 'ERP reference is required for this task. Please provide an ERP reference before completing.';
    END IF;

    -- ====================================================================
    -- CREATE OR UPDATE COMPLETION RECORD
--

--
-- Name: surprise_box_check_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.surprise_box_check_status() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_settings RECORD;
    v_now timestamptz := now() AT TIME ZONE 'UTC';
    v_today_count integer;
BEGIN
    SELECT * INTO v_settings FROM public.surprise_box_settings LIMIT 1;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('active', false, 'reason', 'not_configured');
    END IF;
    IF NOT v_settings.active THEN
        RETURN jsonb_build_object('active', false, 'reason', 'disabled');
    END IF;
    IF v_settings.start_datetime IS NOT NULL AND v_now < v_settings.start_datetime THEN
        RETURN jsonb_build_object('active', false, 'reason', 'not_started');
    END IF;
    IF v_settings.end_datetime IS NOT NULL AND v_now > v_settings.end_datetime THEN
        RETURN jsonb_build_object('active', false, 'reason', 'ended');
    END IF;
    -- Daily limit check
    SELECT COUNT(*) INTO v_today_count
    FROM public.surprise_box_plays
    WHERE created_at >= (now() AT TIME ZONE v_settings.timezone)::date
      AND rejected = false;
    IF v_today_count >= v_settings.daily_limit THEN
        RETURN jsonb_build_object('active', false, 'reason', 'daily_limit_reached');
    END IF;
    RETURN jsonb_build_object(
        'active', true,
        'minimum_bill_amount', v_settings.minimum_bill_amount,
        'box_count', v_settings.box_count,
        'enforce_bill_date', v_settings.enforce_bill_date,
        'terms_en', v_settings.terms_en,
        'terms_ar', v_settings.terms_ar,
        'daily_remaining', v_settings.daily_limit - v_today_count
    );
END;
$$;


--
-- Name: surprise_box_dashboard_stats(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.surprise_box_dashboard_stats(p_from timestamp with time zone DEFAULT (now() - '30 days'::interval), p_to timestamp with time zone DEFAULT now()) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'total_plays',       COUNT(*) FILTER (WHERE rejected = false),
        'total_winners',     COUNT(*) FILTER (WHERE is_winner = true),
        'total_rejected',    COUNT(*) FILTER (WHERE rejected = true),
        'total_voucher_value', COALESCE(SUM(v.voucher_value) FILTER (WHERE p.is_winner = true), 0),
        'total_redeemed',    COUNT(*) FILTER (WHERE v.status = 'redeemed'),
        'total_redeemed_value', COALESCE(SUM(v.voucher_value) FILTER (WHERE v.status = 'redeemed'), 0),
        'redemption_rate',   ROUND(
            CASE WHEN COUNT(*) FILTER (WHERE p.is_winner = true) > 0
                 THEN COUNT(*) FILTER (WHERE v.status = 'redeemed')::numeric
                    / COUNT(*) FILTER (WHERE p.is_winner = true) * 100
                 ELSE 0
            END, 1)
    )
    INTO v_result
    FROM public.surprise_box_plays p
    LEFT JOIN public.surprise_box_vouchers v ON v.play_id = p.id
    WHERE p.created_at BETWEEN p_from AND p_to;

    RETURN v_result;
END;
$$;


--
-- Name: surprise_box_play(text, numeric, text, text, integer, boolean, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.surprise_box_play(p_bill_number text, p_bill_amount numeric, p_bill_image_url text DEFAULT NULL::text, p_bill_date text DEFAULT NULL::text, p_box_selected integer DEFAULT NULL::integer, p_manual_entry boolean DEFAULT false, p_manual_entry_by uuid DEFAULT NULL::uuid, p_manual_entry_username text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
    v_settings     RECORD;
    v_now          timestamptz := now() AT TIME ZONE 'UTC';
    v_today_count  integer;
    v_existing     RECORD;
    v_reward       RECORD;
    v_voucher_code text;
    v_play_id      uuid;
    v_voucher_id   uuid;
    v_expires_at   date;
    v_total_weight bigint;
    v_rand_val     bigint;
    v_cumulative   bigint := 0;
    v_today        date;
BEGIN
    -- Lock settings row to prevent concurrent races
    SELECT * INTO v_settings FROM public.surprise_box_settings LIMIT 1 FOR UPDATE;
    IF NOT FOUND OR NOT v_settings.active THEN
        RETURN jsonb_build_object('success', false, 'reason', 'campaign_inactive');
    END IF;
    -- Date window
    IF v_settings.start_datetime IS NOT NULL AND v_now < v_settings.start_datetime THEN
        RETURN jsonb_build_object('success', false, 'reason', 'not_started');
    END IF;
    IF v_settings.end_datetime IS NOT NULL AND v_now > v_settings.end_datetime THEN
        RETURN jsonb_build_object('success', false, 'reason', 'ended');
    END IF;
    -- Daily limit
    SELECT COUNT(*) INTO v_today_count
    FROM public.surprise_box_plays
    WHERE created_at >= (now() AT TIME ZONE v_settings.timezone)::date
      AND rejected = false;
    IF v_today_count >= v_settings.daily_limit THEN
        RETURN jsonb_build_object('success', false, 'reason', 'daily_limit_reached');
    END IF;
    -- Minimum bill amount
    IF p_bill_amount < v_settings.minimum_bill_amount THEN
        RETURN jsonb_build_object('success', false, 'reason', 'below_minimum');
    END IF;
    -- Bill date enforcement (KSA / configured timezone)
    IF v_settings.enforce_bill_date THEN
        v_today := (now() AT TIME ZONE v_settings.timezone)::date;
        IF p_bill_date IS NULL OR p_bill_date::date <> v_today THEN
            RETURN jsonb_build_object('success', false, 'reason', 'wrong_bill_date');
        END IF;
    END IF;
    -- Bill already played
--

--
-- Name: surprise_box_redeem_voucher(text, text, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.surprise_box_redeem_voucher(p_code text, p_redeemed_bill_number text DEFAULT NULL::text, p_redeemed_amount numeric DEFAULT NULL::numeric) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_voucher RECORD;
BEGIN
    SELECT * INTO v_voucher
    FROM public.surprise_box_vouchers
    WHERE code = upper(trim(p_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'reason', 'not_found');
    END IF;
    IF v_voucher.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'reason', v_voucher.status);
    END IF;
    IF v_voucher.expires_at < now()::date THEN
        UPDATE public.surprise_box_vouchers SET status = 'expired' WHERE id = v_voucher.id;
        RETURN jsonb_build_object('success', false, 'reason', 'expired');
    END IF;

    UPDATE public.surprise_box_vouchers
    SET status = 'redeemed',
        redeemed_at = now(),
        redeemed_bill_number = p_redeemed_bill_number,
        redeemed_amount = p_redeemed_amount
    WHERE id = v_voucher.id;

    RETURN jsonb_build_object(
        'success', true,
        'voucher_value', v_voucher.voucher_value,
        'label_en', v_voucher.label_en,
        'label_ar', v_voucher.label_ar
    );
END;
$$;


--
-- Name: surprise_box_rewards_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.surprise_box_rewards_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: surprise_box_settings_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.surprise_box_settings_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: surprise_box_validate_bill(text, numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.surprise_box_validate_bill(p_bill_number text, p_bill_amount numeric, p_bill_date text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_settings RECORD;
    v_existing RECORD;
    v_today    date;
BEGIN
    SELECT * INTO v_settings FROM public.surprise_box_settings LIMIT 1;
    IF NOT FOUND OR NOT v_settings.active THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'campaign_inactive');
    END IF;

    -- Minimum bill amount
    IF p_bill_amount < v_settings.minimum_bill_amount THEN
        RETURN jsonb_build_object(
            'valid', false,
            'reason', 'below_minimum',
            'minimum', v_settings.minimum_bill_amount
        );
    END IF;

    -- Bill date enforcement (KSA / configured timezone)
    IF v_settings.enforce_bill_date THEN
        v_today := (now() AT TIME ZONE v_settings.timezone)::date;
        IF p_bill_date IS NULL OR p_bill_date::date <> v_today THEN
            RETURN jsonb_build_object(
                'valid', false,
                'reason', 'wrong_bill_date',
                'expected_date', v_today::text
            );
        END IF;
    END IF;

    -- Bill already used
    SELECT id INTO v_existing
    FROM public.surprise_box_plays
    WHERE bill_number = p_bill_number
      AND rejected = false
    LIMIT 1;
    IF FOUND THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'already_played');
    END IF;

    RETURN jsonb_build_object('valid', true);
END;
$$;


--
-- Name: surprise_box_validate_voucher(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.surprise_box_validate_voucher(p_code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_voucher RECORD;
BEGIN
    -- Expire overdue vouchers first
    UPDATE public.surprise_box_vouchers
    SET status = 'expired'
    WHERE status = 'active' AND expires_at < now()::date;

    SELECT v.*, r.label_en, r.label_ar
    INTO v_voucher
    FROM public.surprise_box_vouchers v
    LEFT JOIN public.surprise_box_rewards r ON r.id = v.reward_id
    WHERE v.code = upper(trim(p_code));

    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'not_found');
    END IF;
    IF v_voucher.status = 'redeemed' THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'already_redeemed', 'redeemed_at', v_voucher.redeemed_at);
    END IF;
    IF v_voucher.status = 'expired' OR v_voucher.expires_at < now()::date THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'expired');
    END IF;
    IF v_voucher.status = 'cancelled' THEN
        RETURN jsonb_build_object('valid', false, 'reason', 'cancelled');
    END IF;
    RETURN jsonb_build_object(
        'valid', true,
        'voucher_id', v_voucher.id,
        'voucher_value', v_voucher.voucher_value,
        'label_en', v_voucher.label_en,
        'label_ar', v_voucher.label_ar,
        'expires_at', v_voucher.expires_at,
        'bill_number', v_voucher.bill_number,
        'bill_amount', v_voucher.bill_amount,
        'issued_at', v_voucher.issued_at
    );
END;
$$;


--
-- Name: sync_all_missing_erp_references(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_all_missing_erp_references() RETURNS TABLE(synced_count integer, details text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    sync_record RECORD;
    total_synced INTEGER := 0;
    sync_details TEXT := '';
BEGIN
    -- Process all unsynced inventory manager task completions
    FOR sync_record IN
        SELECT 
            tc.id as completion_id,
            tc.task_id,
            tc.erp_reference_number,
            rt.receiving_record_id,
            rt.role_type,
            rr.erp_purchase_invoice_reference as current_erp
        FROM task_completions tc
        JOIN receiving_tasks rt ON tc.task_id = rt.task_id AND tc.assignment_id = rt.assignment_id
        JOIN receiving_records rr ON rt.receiving_record_id = rr.id
        WHERE tc.erp_reference_completed = true 
          AND tc.erp_reference_number IS NOT NULL 
          AND TRIM(tc.erp_reference_number) != ''
          AND rt.role_type = 'inventory_manager'
          AND (rr.erp_purchase_invoice_reference IS NULL 
               OR rr.erp_purchase_invoice_reference != TRIM(tc.erp_reference_number))
    LOOP
        -- Update the receiving record
        UPDATE receiving_records 
        SET 
            erp_purchase_invoice_reference = TRIM(sync_record.erp_reference_number),
            updated_at = now()
        WHERE id = sync_record.receiving_record_id;
        
        total_synced := total_synced + 1;
        sync_details := sync_details || format('Synced receiving_record %s with ERP %s; ', 
                                              sync_record.receiving_record_id, 
                                              TRIM(sync_record.erp_reference_number));
        
    END LOOP;
    
    RETURN QUERY SELECT total_synced, sync_details;
END;
$$;


--
-- Name: sync_all_pending_erp_references(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_all_pending_erp_references() RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    sync_record RECORD;
    total_synced INTEGER := 0;
    sync_details JSONB := '[]'::JSONB;
    record_detail JSONB;
BEGIN
    -- Find all receiving records that need ERP sync
    FOR sync_record IN
        SELECT 
            rr.id as receiving_record_id,
            tc.erp_reference_number,
            rr.erp_purchase_invoice_reference as current_erp,
            tc.completed_by
        FROM receiving_records rr
        JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id
        JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
        WHERE rt.role_type = 'inventory_manager'
          AND tc.erp_reference_completed = true
          AND tc.erp_reference_number IS NOT NULL
          AND TRIM(tc.erp_reference_number) != ''
          AND (rr.erp_purchase_invoice_reference IS NULL 
               OR rr.erp_purchase_invoice_reference != TRIM(tc.erp_reference_number))
        ORDER BY tc.completed_at DESC
    LOOP
        -- Update the receiving record
        UPDATE receiving_records 
        SET 
            erp_purchase_invoice_reference = TRIM(sync_record.erp_reference_number),
            updated_at = now()
        WHERE id = sync_record.receiving_record_id;
        
        total_synced := total_synced + 1;
        
        -- Add details to the result
        record_detail := jsonb_build_object(
            'receiving_record_id', sync_record.receiving_record_id,
            'erp_reference', TRIM(sync_record.erp_reference_number),
            'previous_erp', sync_record.current_erp,
            'completed_by', sync_record.completed_by
        );
        
        sync_details := sync_details || record_detail;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'total_synced', total_synced,
        'details', sync_details,
--

--
-- Name: sync_app_functions_from_components(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_app_functions_from_components(component_metadata jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    component JSONB;
    function_record JSONB;
    result_count INTEGER := 0;
    result_text TEXT := '';
BEGIN
    -- Loop through each component in the metadata
    FOR component IN SELECT jsonb_array_elements(component_metadata->'components')
    LOOP
        -- Loop through functions in each component
        FOR function_record IN SELECT jsonb_array_elements(component->'functions')
        LOOP
            -- Register each function
            PERFORM register_app_function(
                function_record->>'name',
                function_record->>'code',
                function_record->>'description',
                COALESCE(function_record->>'category', component->>'category', 'Application')
            );
            
            result_count := result_count + 1;
        END LOOP;
    END LOOP;
    
    result_text := format('Synchronized %s app functions from component metadata', result_count);
    RETURN result_text;
END;
$$;


--
-- Name: sync_employee_with_hr(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_employee_with_hr(p_employee_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Update user information based on employee record
    UPDATE users u
    SET 
        updated_at = NOW()
    FROM hr_employees e
    WHERE u.employee_id = e.id
      AND e.id = p_employee_id;
    
    RETURN FOUND;
END;
$$;


--
-- Name: sync_erp_reference_for_receiving_record(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_erp_reference_for_receiving_record(receiving_record_id_param uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    sync_record RECORD;
    updated_count INTEGER := 0;
    result_json JSONB;
BEGIN
    RAISE NOTICE 'Starting ERP sync for receiving_record_id: %', receiving_record_id_param;
    
    -- First, try to find task completion with ERP reference
    SELECT 
        tc.erp_reference_number,
        tc.erp_reference_completed,
        rt.role_type,
        rr.erp_purchase_invoice_reference as current_erp,
        tc.completed_at,
        tc.completed_by
    INTO sync_record
    FROM receiving_records rr
    JOIN receiving_tasks rt ON rr.id = rt.receiving_record_id
    JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
    WHERE rr.id = receiving_record_id_param
      AND rt.role_type = 'inventory_manager'
      AND tc.erp_reference_completed = true
      AND tc.erp_reference_number IS NOT NULL
      AND TRIM(tc.erp_reference_number) != ''
    ORDER BY tc.completed_at DESC
    LIMIT 1;

    -- If we found a task completion with ERP reference
    IF FOUND THEN
        RAISE NOTICE 'Found task completion with ERP: %', sync_record.erp_reference_number;
        
        -- Check if sync is needed
        IF sync_record.current_erp IS NULL OR sync_record.current_erp != TRIM(sync_record.erp_reference_number) THEN
            -- Update the receiving record
            UPDATE receiving_records 
            SET 
                erp_purchase_invoice_reference = TRIM(sync_record.erp_reference_number),
                updated_at = now()
            WHERE id = receiving_record_id_param;
            
            GET DIAGNOSTICS updated_count = ROW_COUNT;
            
            result_json := jsonb_build_object(
                'success', true,
                'synced', true,
                'updated_count', updated_count,
                'erp_reference', TRIM(sync_record.erp_reference_number),
                'previous_erp', sync_record.current_erp,
--

--
-- Name: sync_erp_references_from_task_completions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_erp_references_from_task_completions() RETURNS TABLE(receiving_record_id uuid, erp_reference_updated text, sync_status text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH erp_updates AS (
        UPDATE receiving_records rr
        SET 
            erp_purchase_invoice_reference = tc.erp_reference_number,
            updated_at = now()
        FROM task_completions tc
        JOIN receiving_tasks rt ON tc.task_id = rt.task_id AND tc.assignment_id = rt.assignment_id
        WHERE rt.receiving_record_id = rr.id
        AND rt.role_type = 'inventory_manager'
        AND tc.erp_reference_completed = true
        AND tc.erp_reference_number IS NOT NULL
        AND tc.erp_reference_number != ''
        AND (rr.erp_purchase_invoice_reference IS NULL OR rr.erp_purchase_invoice_reference != tc.erp_reference_number)
        RETURNING rr.id as receiving_record_id, tc.erp_reference_number::TEXT, 'updated'::TEXT as sync_status
    )
    SELECT 
        eu.receiving_record_id,
        eu.erp_reference_number,
        eu.sync_status
    FROM erp_updates eu;
END;
$$;


--
-- Name: sync_loyalty_tiers(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_loyalty_tiers() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_updated integer := 0;
BEGIN
    WITH customer_totals AS (
        SELECT
            c.id AS customer_id,
            COALESCE(SUM(lcb.bill_net_total), 0) AS total_amt,
            COALESCE(SUM(lcb.points_earned),  0) AS total_pts,
            COALESCE(c.loyalty_program_opening_balance, 0) AS opening_bal
        FROM public.customers c
        LEFT JOIN public.loyalty_customer_bills lcb ON lcb.customer_id = c.id
        WHERE c.is_deleted = false
        GROUP BY c.id, c.loyalty_program_opening_balance
    ),
    redemption_totals AS (
        SELECT
            customer_id,
            COALESCE(SUM(points_redeemed), 0) AS total_redeemd
        FROM public.loyalty_redemptions
        WHERE status = 'confirmed'
        GROUP BY customer_id
    ),
    tier_assignments AS (
        SELECT
            ct.customer_id,
            ct.total_amt,
            ct.total_pts,
            ct.opening_bal,
            COALESCE(rt.total_redeemd, 0)                                          AS total_redeemd,
            ct.total_pts - COALESCE(rt.total_redeemd, 0) + ct.opening_bal          AS final_balance,
            lt.id               AS tier_id,
            lt.name             AS tier_name,
            lt.name_ar          AS tier_name_ar,
            lt.points_percentage
        FROM customer_totals ct
        LEFT JOIN redemption_totals rt ON rt.customer_id = ct.customer_id
        LEFT JOIN LATERAL (
            SELECT id, name, name_ar, points_percentage
            FROM public.loyalty_tiers
            WHERE is_active = true
              AND ct.total_amt >= total_purchase_from
              AND (total_purchase_to IS NULL OR ct.total_amt <= total_purchase_to)
            ORDER BY total_purchase_from DESC
            LIMIT 1
        ) lt ON true
    )
    UPDATE public.customers c
--

--
-- Name: sync_privilege_cards_opening_balance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_privilege_cards_opening_balance() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_total_scanned   integer;
    v_total_updated   integer;
    v_total_skipped   integer;
    v_points_synced   numeric;
BEGIN
    -- Count distinct mobiles in privilege_cards_branch
    SELECT COUNT(DISTINCT mobile)
    INTO v_total_scanned
    FROM public.privilege_cards_branch
    WHERE mobile IS NOT NULL AND mobile != '';

    -- Single bulk UPDATE ΓÇö no row-by-row loop
    WITH aggregated AS (
        SELECT
            mobile,
            COALESCE(SUM(card_balance), 0) AS opening_balance
        FROM public.privilege_cards_branch
        WHERE mobile IS NOT NULL AND mobile != ''
        GROUP BY mobile
    )
    UPDATE public.customers c
    SET
        loyalty_program_opening_balance = a.opening_balance,
        final_loyalty_point_balance     = COALESCE(c.total_points_earned, 0)
                                          - COALESCE(c.total_redemptions, 0)
                                          + a.opening_balance,
        updated_at                      = now()
    FROM aggregated a
    WHERE c.whatsapp_number = a.mobile
      AND c.is_deleted = false;

    GET DIAGNOSTICS v_total_updated = ROW_COUNT;

    -- Collect summary stats
    SELECT COALESCE(SUM(loyalty_program_opening_balance), 0)
    INTO v_points_synced
    FROM public.customers
    WHERE whatsapp_number IN (
        SELECT DISTINCT mobile FROM public.privilege_cards_branch
        WHERE mobile IS NOT NULL AND mobile != ''
    )
    AND is_deleted = false;

    v_total_skipped := v_total_scanned - v_total_updated;

    RETURN jsonb_build_object(
--

--
-- Name: sync_requisition_balance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_requisition_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    scheduler_balance NUMERIC(10,2);
    original_amount NUMERIC(10,2);
BEGIN
    -- Only process if this is a requisition-related scheduler entry
    IF NEW.requisition_id IS NOT NULL AND NEW.schedule_type = 'expense_requisition' THEN
        
        -- Get the current balance from the scheduler (unpaid entry)
        SELECT COALESCE(amount, 0) INTO scheduler_balance
        FROM expense_scheduler
        WHERE requisition_id = NEW.requisition_id
        AND schedule_type = 'expense_requisition'
        AND is_paid = false
        LIMIT 1;
        
        -- Get the original request amount
        SELECT amount INTO original_amount
        FROM expense_requisitions
        WHERE id = NEW.requisition_id;
        
        -- Update the requisition table
        IF scheduler_balance = 0 OR NEW.is_paid = true THEN
            -- Balance is zero or marked as paid - close the request
            UPDATE expense_requisitions
            SET 
                remaining_balance = 0,
                used_amount = original_amount,
                status = 'closed',
                is_active = false,
                updated_at = NOW()
            WHERE id = NEW.requisition_id;
        ELSE
            -- Balance still exists - update the amounts
            UPDATE expense_requisitions
            SET 
                remaining_balance = scheduler_balance,
                used_amount = original_amount - scheduler_balance,
                updated_at = NOW()
            WHERE id = NEW.requisition_id;
        END IF;
        
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: sync_user_roles_from_positions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_user_roles_from_positions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- This function would sync user roles based on position changes
    -- Implementation depends on business logic
    RETURN NEW;
END;
$$;


--
-- Name: tg_hr_salary_statements_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tg_hr_salary_statements_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


--
-- Name: touch_hr_esob_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_hr_esob_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;


--
-- Name: track_media_activation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.track_media_activation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.is_active = true AND (OLD.is_active IS NULL OR OLD.is_active = false) THEN
        NEW.activated_at = NOW();
    END IF;
    
    IF NEW.is_active = false AND OLD.is_active = true THEN
        NEW.deactivated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: trg_sync_customer_loyalty_on_bill(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_sync_customer_loyalty_on_bill() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_total_amt     numeric;
    v_total_pts     numeric;
    v_total_redeemd numeric;
    v_final_balance numeric;
    v_tier_id       uuid;
    v_tier_name     text;
    v_tier_name_ar  text;
    v_points_pct    numeric;
    v_opening_bal   numeric;
BEGIN
    SELECT
        COALESCE(SUM(bill_net_total), 0),
        COALESCE(SUM(points_earned),  0)
    INTO v_total_amt, v_total_pts
    FROM public.loyalty_customer_bills
    WHERE customer_id = NEW.customer_id;

    SELECT COALESCE(SUM(points_redeemed), 0)
    INTO v_total_redeemd
    FROM public.loyalty_redemptions
    WHERE customer_id = NEW.customer_id
      AND status = 'confirmed';

    -- Include opening balance from privilege_cards_branch migration
    SELECT COALESCE(loyalty_program_opening_balance, 0)
    INTO v_opening_bal
    FROM public.customers
    WHERE id = NEW.customer_id;

    v_final_balance := v_total_pts - v_total_redeemd + COALESCE(v_opening_bal, 0);

    SELECT id, name, name_ar, points_percentage
    INTO v_tier_id, v_tier_name, v_tier_name_ar, v_points_pct
    FROM public.loyalty_tiers
    WHERE is_active = true
      AND v_total_amt >= total_purchase_from
      AND (total_purchase_to IS NULL OR v_total_amt <= total_purchase_to)
    ORDER BY total_purchase_from DESC
    LIMIT 1;

    UPDATE public.customers
    SET
        loyalty_tier_id             = v_tier_id,
        loyalty_tier_name           = v_tier_name,
        loyalty_tier_name_ar        = v_tier_name_ar,
        points_percentage           = v_points_pct,
--

--
-- Name: trigger_cleanup_assignment_notifications(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_cleanup_assignment_notifications() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Clean up notifications related to the deleted assignment
    DELETE FROM notifications 
    WHERE task_assignment_id = OLD.id;
    RETURN OLD;
END;
$$;


--
-- Name: FUNCTION trigger_cleanup_assignment_notifications(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.trigger_cleanup_assignment_notifications() IS 'Trigger function to clean up notifications when task assignments are deleted';


--
-- Name: trigger_cleanup_task_notifications(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_cleanup_task_notifications() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Clean up notifications related to the deleted task
    DELETE FROM notifications 
    WHERE task_id = OLD.id;
    RETURN OLD;
END;
$$;


--
-- Name: FUNCTION trigger_cleanup_task_notifications(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.trigger_cleanup_task_notifications() IS 'Trigger function to clean up notifications when tasks are deleted';


--
-- Name: trigger_log_order_offer_usage(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_log_order_offer_usage() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update offer_usage_logs with order_id for items that have offers
    UPDATE offer_usage_logs
    SET order_id = NEW.order_id
    WHERE offer_id IN (
        SELECT offer_id
        FROM order_items
        WHERE order_id = NEW.order_id
        AND has_offer = TRUE
        AND offer_id IS NOT NULL
    )
    AND order_id IS NULL
    AND customer_id = (
        SELECT customer_id FROM orders WHERE id = NEW.order_id
    )
    AND used_at >= (
        SELECT created_at FROM orders WHERE id = NEW.order_id
    ) - INTERVAL '1 minute';
    
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION trigger_log_order_offer_usage(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.trigger_log_order_offer_usage() IS 'Links offer usage logs to orders for tracking';


--
-- Name: trigger_notify_new_order(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_notify_new_order() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_customer_name VARCHAR(255);
    v_notification_id UUID;
    v_admin_user RECORD;
    v_title TEXT;
    v_message TEXT;
    v_fulfillment_label_en TEXT;
    v_fulfillment_label_ar TEXT;
    -- Push notification vars
    v_push_title TEXT;
    v_push_body TEXT;
    v_service_role_key TEXT;
    v_supabase_url TEXT;
    v_request_id BIGINT;
    v_user_ids JSONB;
BEGIN
    -- Get customer name
    SELECT name INTO v_customer_name
    FROM customers
    WHERE id = NEW.customer_id;

    -- Determine fulfillment labels
    IF NEW.fulfillment_method = 'pickup' THEN
        v_fulfillment_label_en := 'Pickup';
        v_fulfillment_label_ar := '??????';
    ELSE
        v_fulfillment_label_en := 'Delivery';
        v_fulfillment_label_ar := '?????';
    END IF;

    -- Bilingual title and message for in-app notification
    v_title := 'New Order #' || NEW.order_number || ' (' || v_fulfillment_label_en || ')|||??? ???? #' || NEW.order_number || ' (' || v_fulfillment_label_ar || ')';
    v_message := 'Order #' || NEW.order_number || ' from ' || COALESCE(v_customer_name, NEW.customer_name) || ' - Total: ' || NEW.total_amount || ' SAR - ' || v_fulfillment_label_en || '|||??? #' || NEW.order_number || ' ?? ' || COALESCE(v_customer_name, NEW.customer_name) || ' - ??????: ' || NEW.total_amount || ' ?.? - ' || v_fulfillment_label_ar;

    -- Create the in-app notification
    INSERT INTO notifications (
        title, message, type, created_by, created_by_name, created_by_role,
        priority, status, target_type, target_roles, sent_at
    ) VALUES (
        v_title, v_message, 'order_new',
        NEW.customer_id::text,
        COALESCE(v_customer_name, NEW.customer_name),
        'Customer',
        'high', 'published', 'role_based',
        to_jsonb(ARRAY['Admin', 'Master Admin']),
        NOW()
    ) RETURNING id INTO v_notification_id;

--

--
-- Name: trigger_order_status_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_order_status_audit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Only log if status actually changed
    IF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
        INSERT INTO order_audit_logs (
            order_id,
            action_type,
            from_status,
            to_status,
            performed_by,
            notes
        ) VALUES (
            NEW.id,
            'status_changed',
            OLD.order_status,
            NEW.order_status,
            NEW.updated_by,
            'Status changed from ' || OLD.order_status || ' to ' || NEW.order_status
        );
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION trigger_order_status_audit(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.trigger_order_status_audit() IS 'Automatically creates audit log when order status changes';


--
-- Name: trigger_sync_erp_reference_on_task_completion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_sync_erp_reference_on_task_completion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    update_count INTEGER := 0;
BEGIN
    -- Only process if ERP reference is provided and completed
    IF NEW.erp_reference_completed = true 
       AND NEW.erp_reference_number IS NOT NULL 
       AND TRIM(NEW.erp_reference_number) != '' THEN
        
        -- Check if this is a regular task completion (not receiving task)
        -- Regular tasks (like payment tasks) don't need this trigger
        -- This trigger only handles receiving_tasks (inventory manager tasks)
        
        -- Since receiving_tasks is a separate system with its own completion logic,
        -- and regular tasks/task_assignments are separate,
        -- we don't need to do anything here for regular task completions.
        
        -- The receiving tasks have their own completion system via:
        -- complete_receiving_task() function which is called directly
        
        RAISE NOTICE 'Γä╣∩╕Å  Task completion with ERP reference: Task ID %, ERP: %', 
                     NEW.task_id, 
                     TRIM(NEW.erp_reference_number);
        
        -- Note: For payment tasks, the ERP reference sync is handled in the application code
        -- (TaskCompletionModal.svelte) which updates vendor_payment_schedule.payment_reference
        
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: trigger_update_order_totals(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_update_order_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Recalculate total items and quantities when order_items change
    UPDATE orders
    SET total_items = (
            SELECT COUNT(*)
            FROM order_items
            WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
        ),
        total_quantity = (
            SELECT COALESCE(SUM(quantity), 0)
            FROM order_items
            WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
        ),
        updated_at = NOW()
    WHERE id = COALESCE(NEW.order_id, OLD.order_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: FUNCTION trigger_update_order_totals(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.trigger_update_order_totals() IS 'Recalculates order item counts when order_items change';


--
-- Name: update_ai_chat_guide_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_ai_chat_guide_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_app_icons_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_app_icons_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_approval_permissions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_approval_permissions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_approver_visibility_config_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_approver_visibility_config_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_attendance_hours(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_attendance_hours() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Calculate actual hours
    NEW.actual_hours = calculate_working_hours(NEW.check_in_time, NEW.check_out_time);
    
    -- Calculate overtime (if there's a duty schedule)
    IF NEW.duty_schedule_id IS NOT NULL THEN
        SELECT 
            GREATEST(0, NEW.actual_hours - ds.scheduled_hours)
        INTO NEW.overtime_hours
        FROM duty_schedules ds
        WHERE ds.id = NEW.duty_schedule_id;
    END IF;
    
    -- Update status based on attendance
    IF NEW.check_in_time IS NOT NULL AND NEW.check_out_time IS NOT NULL THEN
        NEW.status = 'present';
    ELSIF NEW.check_in_time IS NOT NULL THEN
        NEW.status = 'present';
    ELSE
        NEW.status = 'absent';
    END IF;
    
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_bank_reconciliations_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_bank_reconciliations_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_bogo_offer_rules_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_bogo_offer_rules_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_box_operations_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_box_operations_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_branch_default_positions_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_branch_default_positions_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_branch_delivery_receivers_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_branch_delivery_receivers_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_branch_sync_status(bigint, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_branch_sync_status(p_branch_id bigint, p_status text, p_details jsonb DEFAULT '{}'::jsonb) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    UPDATE branch_sync_config
    SET last_sync_at = now(),
        last_sync_status = p_status,
        last_sync_details = p_details,
        updated_at = now()
    WHERE branch_id = p_branch_id;
$$;


--
-- Name: update_branches_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_branches_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_coupon_campaigns_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_coupon_campaigns_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: update_coupon_products_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_coupon_products_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: update_customer_app_media_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_customer_app_media_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_customer_recovery_requests_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_customer_recovery_requests_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_customers_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_customers_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_day_off_reasons_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_day_off_reasons_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_day_off_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_day_off_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_day_off_weekday_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_day_off_weekday_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_deadline_datetime(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_deadline_datetime() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.deadline_date IS NOT NULL THEN
        NEW.deadline_datetime = (NEW.deadline_date || ' ' || COALESCE(NEW.deadline_time::text, '23:59:59'))::timestamp with time zone;
    ELSE
        NEW.deadline_datetime = NULL;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: update_delivery_tiers_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_delivery_tiers_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_denomination_transactions_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_denomination_transactions_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_denomination_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_denomination_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_departments_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_departments_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_desktop_themes_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_desktop_themes_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_duty_schedule_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_duty_schedule_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_early_leave_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_early_leave_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_employee_master_basic(text, text, text, integer, uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_employee_master_basic(p_id text, p_name_en text DEFAULT NULL::text, p_name_ar text DEFAULT NULL::text, p_current_branch_id integer DEFAULT NULL::integer, p_current_position_id uuid DEFAULT NULL::uuid, p_employment_status text DEFAULT NULL::text, p_whatsapp_number text DEFAULT NULL::text, p_email text DEFAULT NULL::text) RETURNS TABLE(id text, name_en character varying, name_ar character varying, current_branch_id integer, current_position_id uuid, employment_status text, whatsapp_number text, email text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_valid_statuses TEXT[] := ARRAY['Resigned','Job (With Finger)','Vacation','Terminated','Run Away','Remote Job','Job (No Finger)'];
BEGIN
  IF COALESCE(trim(p_id), '') = '' THEN
    RAISE EXCEPTION 'Employee ID is required';
  END IF;

  -- Validate employment_status if provided
  IF p_employment_status IS NOT NULL AND p_employment_status != '' AND NOT (p_employment_status = ANY(v_valid_statuses)) THEN
    RAISE EXCEPTION 'Invalid employment status value: %', p_employment_status;
  END IF;

  -- Validate branch exists if provided
  IF p_current_branch_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM branches b WHERE b.id = p_current_branch_id) THEN
      RAISE EXCEPTION 'Branch not found';
    END IF;
  END IF;

  -- Validate position exists if provided (allow NULL to clear)
  IF p_current_position_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM hr_positions pos WHERE pos.id = p_current_position_id) THEN
      RAISE EXCEPTION 'Position not found';
    END IF;
  END IF;

  RETURN QUERY
  UPDATE hr_employee_master e
  SET
    name_en = COALESCE(NULLIF(trim(p_name_en), ''), e.name_en),
    name_ar = COALESCE(NULLIF(trim(p_name_ar), ''), e.name_ar),
    current_branch_id = COALESCE(p_current_branch_id, e.current_branch_id),
    current_position_id = CASE
      WHEN p_current_position_id IS NOT NULL THEN p_current_position_id
      ELSE e.current_position_id
    END,
    employment_status = COALESCE(NULLIF(p_employment_status, ''), e.employment_status),
    whatsapp_number = CASE
      WHEN p_whatsapp_number IS NOT NULL THEN NULLIF(trim(p_whatsapp_number), '')
      ELSE e.whatsapp_number
    END,
    email = CASE
      WHEN p_email IS NOT NULL THEN NULLIF(trim(p_email), '')
      ELSE e.email
    END,
    updated_at = NOW()
  WHERE e.id = p_id
--

--
-- Name: update_employee_positions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_employee_positions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_erp_connections_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_erp_connections_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_erp_daily_sales_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_erp_daily_sales_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_expense_categories_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_expense_categories_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_expense_parent_categories_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_expense_parent_categories_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_expense_scheduler_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_expense_scheduler_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: update_final_bill_amount_on_adjustment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_final_bill_amount_on_adjustment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Only recalculate if there are actual adjustments (discount, GRR, or PRI)
  -- This prevents the trigger from interfering with split payments
  IF (COALESCE(NEW.discount_amount, 0) > 0 OR 
      COALESCE(NEW.grr_amount, 0) > 0 OR 
      COALESCE(NEW.pri_amount, 0) > 0) THEN
    
    DECLARE
      base_amount DECIMAL(15, 2);
    BEGIN
      -- Determine the base amount to deduct from
      base_amount := COALESCE(NEW.original_final_amount, NEW.bill_amount);
      
      -- Calculate new final_bill_amount by deducting discount, GRR, and PRI amounts
      NEW.final_bill_amount := base_amount - 
        COALESCE(NEW.discount_amount, 0) - 
        COALESCE(NEW.grr_amount, 0) - 
        COALESCE(NEW.pri_amount, 0);
    END;
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: update_flyer_templates_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_flyer_templates_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: update_hr_checklist_operations_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_hr_checklist_operations_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_hr_checklist_questions_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_hr_checklist_questions_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_hr_checklists_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_hr_checklists_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_hr_employee_applicability_rule_periods_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_hr_employee_applicability_rule_periods_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_hr_employee_leave_approvals_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_hr_employee_leave_approvals_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_hr_employee_master_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_hr_employee_master_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_hr_employee_settlement_applicability_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_hr_employee_settlement_applicability_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_hr_employee_ticket_issuances_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_hr_employee_ticket_issuances_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_interface_permissions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_interface_permissions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_issue_types_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_issue_types_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_lease_rent_lease_parties_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_lease_rent_lease_parties_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_lease_rent_property_spaces_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_lease_rent_property_spaces_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_lease_rent_rent_parties_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_lease_rent_rent_parties_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_levels_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_levels_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_loyalty_tier(uuid, text, text, text, numeric, numeric, numeric, integer, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_loyalty_tier(p_id uuid, p_name text, p_name_ar text, p_color text, p_total_purchase_from numeric, p_total_purchase_to numeric, p_points_percentage numeric, p_min_redeem_points integer, p_is_active boolean) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  UPDATE loyalty_tiers SET
    name                = p_name,
    name_ar             = p_name_ar,
    color               = p_color,
    total_purchase_from = p_total_purchase_from,
    total_purchase_to   = p_total_purchase_to,
    points_percentage   = p_points_percentage,
    min_redeem_points   = p_min_redeem_points,
    is_active           = p_is_active,
    updated_at          = now()
  WHERE id = p_id;
$$;


--
-- Name: update_main_document_columns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_main_document_columns() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the dedicated columns based on document type
    IF NEW.document_type = 'health_card' THEN
        NEW.health_card_number := NEW.document_number;
        NEW.health_card_expiry := NEW.expiry_date;
    ELSIF NEW.document_type = 'resident_id' THEN
        NEW.resident_id_number := NEW.document_number;
        NEW.resident_id_expiry := NEW.expiry_date;
    ELSIF NEW.document_type = 'passport' THEN
        NEW.passport_number := NEW.document_number;
        NEW.passport_expiry := NEW.expiry_date;
    ELSIF NEW.document_type = 'driving_license' THEN
        NEW.driving_license_number := NEW.document_number;
        NEW.driving_license_expiry := NEW.expiry_date;
    ELSIF NEW.document_type = 'resume' THEN
        NEW.resume_uploaded := TRUE;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: update_multi_shift_date_wise_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_multi_shift_date_wise_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_multi_shift_regular_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_multi_shift_regular_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_multi_shift_weekday_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_multi_shift_weekday_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_near_expiry_reports_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_near_expiry_reports_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_next_visit_date(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_next_visit_date(visit_id uuid) RETURNS date
    LANGUAGE plpgsql
    AS $$
DECLARE
    visit_record vendor_visits%ROWTYPE;
    new_next_date DATE;
BEGIN
    -- Get the visit record
    SELECT * INTO visit_record FROM vendor_visits WHERE id = visit_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Visit schedule not found with id: %', visit_id;
    END IF;
    
    -- Calculate new next visit date
    new_next_date := calculate_next_visit_date(
        visit_record.visit_type,
        visit_record.weekday_name,
        visit_record.fresh_type,
        visit_record.day_number,
        visit_record.skip_days,
        visit_record.start_date,
        visit_record.next_visit_date
    );
    
    -- Update the record
    UPDATE vendor_visits 
    SET next_visit_date = new_next_date, updated_at = NOW()
    WHERE id = visit_id;
    
    RETURN new_next_date;
END;
$$;


--
-- Name: update_non_approved_scheduler_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_non_approved_scheduler_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


--
-- Name: update_notification_attachments_flag(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_notification_attachments_flag() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE notifications 
        SET has_attachments = TRUE,
            updated_at = NOW()
        WHERE id = NEW.notification_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE notifications 
        SET has_attachments = (
            SELECT COUNT(*) > 0 
            FROM notification_attachments 
            WHERE notification_id = OLD.notification_id
        ),
        updated_at = NOW()
        WHERE id = OLD.notification_id;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$;


--
-- Name: update_notification_delivery_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_notification_delivery_status() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- When a notification_queue item is marked as 'sent', update the recipient's delivery status
    IF NEW.status = 'sent' AND OLD.status != 'sent' THEN
        UPDATE notification_recipients
        SET 
            delivery_status = 'delivered',
            delivery_attempted_at = NEW.sent_at,
            updated_at = NOW()
        WHERE notification_id = NEW.notification_id
        AND user_id = NEW.user_id;
        
        RAISE NOTICE 'Updated delivery status for notification % user %', NEW.notification_id, NEW.user_id;
    
    -- When a notification_queue item is marked as 'failed', update the recipient's delivery status
    ELSIF NEW.status = 'failed' AND OLD.status != 'failed' THEN
        UPDATE notification_recipients
        SET 
            delivery_status = 'failed',
            delivery_attempted_at = NEW.last_attempt_at,
            error_message = NEW.error_message,
            updated_at = NOW()
        WHERE notification_id = NEW.notification_id
        AND user_id = NEW.user_id;
        
        RAISE NOTICE 'Marked delivery as failed for notification % user %', NEW.notification_id, NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION update_notification_delivery_status(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.update_notification_delivery_status() IS 'Updates notification_recipients.delivery_status when push notifications are sent or failed.';


--
-- Name: update_notification_queue_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_notification_queue_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_notification_read_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_notification_read_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update read_count in notifications table when recipient read status changes
    IF TG_OP = 'UPDATE' AND OLD.is_read = FALSE AND NEW.is_read = TRUE THEN
        UPDATE notifications 
        SET read_count = read_count + 1,
            updated_at = NOW()
        WHERE id = NEW.notification_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.is_read = TRUE AND NEW.is_read = FALSE THEN
        UPDATE notifications 
        SET read_count = GREATEST(read_count - 1, 0),
            updated_at = NOW()
        WHERE id = NEW.notification_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: update_offer_cart_tiers_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_offer_cart_tiers_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_offers_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_offers_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_official_holidays_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_official_holidays_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_order_status(uuid, character varying, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_order_status(p_order_id uuid, p_new_status character varying, p_user_id uuid, p_notes text DEFAULT NULL::text) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_current_status VARCHAR(50);
    v_user_name VARCHAR(255);
BEGIN
    -- Get current status
    SELECT order_status INTO v_current_status
    FROM orders
    WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Order not found';
        RETURN;
    END IF;
    
    -- Get user name
    SELECT username INTO v_user_name
    FROM users
    WHERE id = p_user_id;
    
    -- Update order with status-specific timestamps
    UPDATE orders
    SET order_status = p_new_status,
        ready_at = CASE WHEN p_new_status = 'ready' THEN NOW() ELSE ready_at END,
        delivered_at = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE delivered_at END,
        actual_delivery_time = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE actual_delivery_time END,
        payment_status = CASE WHEN p_new_status = 'delivered' AND payment_method = 'cash' THEN 'paid' ELSE payment_status END,
        updated_at = NOW(),
        updated_by = p_user_id
    WHERE id = p_order_id;
    
    -- Create audit log
    INSERT INTO order_audit_logs (
        order_id,
        action_type,
        from_status,
        to_status,
        performed_by,
        performed_by_name,
        notes
    ) VALUES (
        p_order_id,
        'status_changed',
        v_current_status,
        p_new_status,
        p_user_id,
        v_user_name,
        COALESCE(p_notes, 'Status changed to ' || p_new_status)
    );
--

--
-- Name: update_payment_transactions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_payment_transactions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_pos_deduction_transfers_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_pos_deduction_transfers_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_positions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_positions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_product_categories_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_product_categories_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_product_request_bt_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_product_request_bt_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_product_request_po_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_product_request_po_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_product_request_st_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_product_request_st_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_product_units_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_product_units_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_products_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_products_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_purchase_voucher_items_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_purchase_voucher_items_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_purchase_vouchers_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_purchase_vouchers_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_push_subscriptions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_push_subscriptions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_quick_task_completions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_quick_task_completions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    
    -- Auto-set verification timestamp
    IF NEW.completion_status = 'verified' AND OLD.completion_status != 'verified' AND NEW.verified_at IS NULL THEN
        NEW.verified_at = now();
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: update_quick_task_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_quick_task_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update main task status based on individual assignments
    IF TG_OP = 'UPDATE' THEN
        -- Check if all assignments are completed
        IF (SELECT COUNT(*) FROM quick_task_assignments 
            WHERE quick_task_id = NEW.quick_task_id AND status != 'completed') = 0 THEN
            
            UPDATE quick_tasks 
            SET status = 'completed', completed_at = NOW(), updated_at = NOW()
            WHERE id = NEW.quick_task_id;
            
        -- Check if task is overdue
        ELSIF NOW() > (SELECT deadline_datetime FROM quick_tasks WHERE id = NEW.quick_task_id) THEN
            UPDATE quick_tasks 
            SET status = 'overdue', updated_at = NOW()
            WHERE id = NEW.quick_task_id AND status != 'completed';
            
            -- Mark individual assignments as overdue if not completed
            UPDATE quick_task_assignments
            SET status = 'overdue', updated_at = NOW()
            WHERE quick_task_id = NEW.quick_task_id AND status IN ('pending', 'accepted', 'in_progress');
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: update_receiving_records_pr_excel_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receiving_records_pr_excel_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.pr_excel_file_url IS DISTINCT FROM NEW.pr_excel_file_url THEN
        NEW.updated_at = now();
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: update_receiving_records_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receiving_records_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_receiving_task_completion(uuid, character varying, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receiving_task_completion(receiving_task_id_param uuid, erp_reference_param character varying DEFAULT NULL::character varying, original_bill_uploaded_param boolean DEFAULT NULL::boolean, original_bill_file_path_param text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    receiving_task RECORD;
    can_complete BOOLEAN := true;
BEGIN
    -- Get receiving task details
    SELECT * INTO receiving_task 
    FROM receiving_tasks 
    WHERE id = receiving_task_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving task not found: %', receiving_task_id_param;
    END IF;
    
    -- Update the receiving task
    UPDATE receiving_tasks 
    SET 
        erp_reference_number = COALESCE(erp_reference_param, erp_reference_number),
        original_bill_uploaded = COALESCE(original_bill_uploaded_param, original_bill_uploaded),
        original_bill_file_path = COALESCE(original_bill_file_path_param, original_bill_file_path),
        updated_at = now()
    WHERE id = receiving_task_id_param;
    
    -- Check if task can be completed based on requirements
    SELECT * INTO receiving_task FROM receiving_tasks WHERE id = receiving_task_id_param;
    
    -- Check ERP reference requirement
    IF receiving_task.requires_erp_reference AND receiving_task.erp_reference_number IS NULL THEN
        can_complete := false;
    END IF;
    
    -- Check original bill upload requirement
    IF receiving_task.requires_original_bill_upload AND NOT receiving_task.original_bill_uploaded THEN
        can_complete := false;
    END IF;
    
    -- If all requirements are met, mark as completed
    IF can_complete AND NOT receiving_task.task_completed THEN
        UPDATE receiving_tasks 
        SET 
            task_completed = true,
            completed_at = now(),
            updated_at = now()
        WHERE id = receiving_task_id_param;
        
        -- Update the main task assignment status
        UPDATE task_assignments 
        SET 
            status = 'completed',
--

--
-- Name: update_receiving_task_templates_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receiving_task_templates_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_receiving_tasks_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receiving_tasks_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_receiving_user_defaults_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receiving_user_defaults_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_regular_shift_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_regular_shift_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_requisition_balance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_requisition_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Only update if requisition_id is not null
  IF NEW.requisition_id IS NOT NULL THEN
    -- Update the expense_requisitions table
    UPDATE public.expense_requisitions
    SET 
      used_amount = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.expense_scheduler
        WHERE requisition_id = NEW.requisition_id
          AND status != 'cancelled'
      ),
      remaining_balance = amount - (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.expense_scheduler
        WHERE requisition_id = NEW.requisition_id
          AND status != 'cancelled'
      ),
      updated_at = now()
    WHERE id = NEW.requisition_id;
  END IF;
  
  RETURN NEW;
END;
$$;


--
-- Name: update_requisition_balance_old(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_requisition_balance_old() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Handle the old requisition_id if it exists and is different
  IF OLD.requisition_id IS NOT NULL AND (TG_OP = 'DELETE' OR OLD.requisition_id != NEW.requisition_id) THEN
    UPDATE public.expense_requisitions
    SET 
      used_amount = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.expense_scheduler
        WHERE requisition_id = OLD.requisition_id
          AND status != 'cancelled'
      ),
      remaining_balance = amount - (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.expense_scheduler
        WHERE requisition_id = OLD.requisition_id
          AND status != 'cancelled'
      ),
      updated_at = now()
    WHERE id = OLD.requisition_id;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: update_salary_statement(uuid, text, date, date, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_salary_statement(p_id uuid, p_statement_name text, p_start_date date, p_end_date date, p_data_json jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_count int;
BEGIN
    IF p_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'id is required');
    END IF;
    IF p_statement_name IS NULL OR length(trim(p_statement_name)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'statement_name is required');
    END IF;
    IF p_start_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'start_date is required');
    END IF;
    IF p_end_date IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'end_date is required');
    END IF;
    IF p_end_date < p_start_date THEN
        RETURN jsonb_build_object('success', false, 'error', 'end_date must be >= start_date');
    END IF;
    IF p_data_json IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'data_json is required');
    END IF;

    UPDATE public.hr_salary_statements
    SET statement_name = trim(p_statement_name),
        start_date     = p_start_date,
        end_date       = p_end_date,
        data_json      = p_data_json
    WHERE id = p_id;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'not found');
    END IF;
    RETURN jsonb_build_object('success', true, 'id', p_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


--
-- Name: update_settlement_rules_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_settlement_rules_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_social_links_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_social_links_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_special_shift_date_wise_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_special_shift_date_wise_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_special_shift_weekday_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_special_shift_weekday_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_stock_request_status(uuid, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_stock_request_status(p_request_id uuid, p_new_status character varying) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_requester_user_id UUID;
    v_status_label TEXT;
    v_status_label_ar TEXT;
    v_notif_type TEXT;
    v_message TEXT;
    v_title TEXT;
    v_tasks_completed INTEGER := 0;
    v_task_record RECORD;
BEGIN
    -- 1. Update the request status
    UPDATE product_request_st
    SET status = p_new_status, updated_at = NOW()
    WHERE id = p_request_id
    RETURNING requester_user_id INTO v_requester_user_id;

    IF v_requester_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;

    -- 2. Auto-complete linked quick tasks
    FOR v_task_record IN
        SELECT id FROM quick_tasks
        WHERE product_request_id = p_request_id
          AND product_request_type = 'ST'
    LOOP
        -- Complete task assignments
        UPDATE quick_task_assignments
        SET status = 'completed', completed_at = NOW()
        WHERE quick_task_id = v_task_record.id;

        -- Complete the task itself
        UPDATE quick_tasks
        SET status = 'completed', completed_at = NOW()
        WHERE id = v_task_record.id;

        v_tasks_completed := v_tasks_completed + 1;
    END LOOP;

    -- 3. Build notification content
    IF p_new_status = 'approved' THEN
        v_status_label := 'Accepted Γ£à';
        v_status_label_ar := '┘à┘é╪¿┘ê┘ä Γ£à';
        v_notif_type := 'success';
        v_message := 'Your Stock Request has been approved.' || E'\n---\n' || '╪╖┘ä╪¿ ╪º┘ä┘à╪«╪▓┘ê┘å ╪º┘ä╪«╪º╪╡ ╪¿┘â ╪¬┘à ┘é╪¿┘ê┘ä┘ç.';
    ELSE
        v_status_label := 'Rejected Γ¥î';
        v_status_label_ar := '┘à╪▒┘ü┘ê╪╢ Γ¥î';
--

--
-- Name: update_system_api_keys_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_system_api_keys_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_tax_categories_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_tax_categories_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: update_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION update_updated_at_column(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.update_updated_at_column() IS 'Automatically updates the updated_at timestamp on row modification';


--
-- Name: update_user(uuid, character varying, boolean, boolean, character varying, bigint, uuid, uuid, character varying, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user(p_user_id uuid, p_username character varying DEFAULT NULL::character varying, p_is_master_admin boolean DEFAULT NULL::boolean, p_is_admin boolean DEFAULT NULL::boolean, p_user_type character varying DEFAULT NULL::character varying, p_branch_id bigint DEFAULT NULL::bigint, p_employee_id uuid DEFAULT NULL::uuid, p_position_id uuid DEFAULT NULL::uuid, p_status character varying DEFAULT NULL::character varying, p_avatar text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User not found'
    );
  END IF;

  -- Check if username is being changed and if it's already taken
  IF p_username IS NOT NULL AND p_username != (SELECT username FROM users WHERE id = p_user_id) THEN
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username AND id != p_user_id) THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Username already exists'
      );
    END IF;
  END IF;

  -- Update user with provided fields
  -- Use conditional updates to avoid type casting issues
  IF p_username IS NOT NULL THEN
    UPDATE users SET username = p_username, updated_at = NOW() WHERE id = p_user_id;
  END IF;
  
  IF p_is_master_admin IS NOT NULL THEN
    UPDATE users SET is_master_admin = p_is_master_admin, updated_at = NOW() WHERE id = p_user_id;
  END IF;
  
  IF p_is_admin IS NOT NULL THEN
    UPDATE users SET is_admin = p_is_admin, updated_at = NOW() WHERE id = p_user_id;
  END IF;
  
  IF p_user_type IS NOT NULL THEN
    UPDATE users SET user_type = p_user_type::user_type_enum, updated_at = NOW() WHERE id = p_user_id;
  END IF;
  
  IF p_branch_id IS NOT NULL THEN
    UPDATE users SET branch_id = p_branch_id, updated_at = NOW() WHERE id = p_user_id;
  END IF;
  
  IF p_employee_id IS NOT NULL THEN
    UPDATE users SET employee_id = p_employee_id, updated_at = NOW() WHERE id = p_user_id;
  END IF;
  
  IF p_position_id IS NOT NULL THEN
    UPDATE users SET position_id = p_position_id, updated_at = NOW() WHERE id = p_user_id;
--

--
-- Name: update_user_device_sessions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_device_sessions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_user_theme_assignments_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_user_theme_assignments_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_vendor_payment_with_exact_calculation(uuid, numeric, numeric, numeric, text, text, text, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_vendor_payment_with_exact_calculation(payment_id uuid, new_discount_amount numeric DEFAULT NULL::numeric, new_grr_amount numeric DEFAULT NULL::numeric, new_pri_amount numeric DEFAULT NULL::numeric, discount_notes_val text DEFAULT NULL::text, grr_reference_val text DEFAULT NULL::text, grr_notes_val text DEFAULT NULL::text, pri_reference_val text DEFAULT NULL::text, pri_notes_val text DEFAULT NULL::text, history_val jsonb DEFAULT NULL::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  current_bill_amount NUMERIC;
  total_deductions NUMERIC;
  calculated_final_amount NUMERIC;
BEGIN
  -- Get the bill_amount (this is always our base for calculation)
  SELECT bill_amount
  INTO current_bill_amount
  FROM vendor_payment_schedule
  WHERE id = payment_id;
  
  -- STEP 1: First reset final_bill_amount to bill_amount (original amount)
  UPDATE vendor_payment_schedule
  SET final_bill_amount = current_bill_amount
  WHERE id = payment_id;
  
  -- STEP 2: Calculate total deductions using bill_amount as base
  total_deductions := COALESCE(new_discount_amount, 0) + COALESCE(new_grr_amount, 0) + COALESCE(new_pri_amount, 0);
  
  -- STEP 3: Calculate final amount after deductions: bill_amount - deductions
  calculated_final_amount := current_bill_amount - total_deductions;
  
  -- Validate that final amount is not negative
  IF calculated_final_amount < 0 THEN
    RAISE EXCEPTION 'Total deductions (%) exceed the bill amount (%). Final amount would be negative.', 
      total_deductions, current_bill_amount;
  END IF;
  
  -- STEP 4: Apply deductions and set final_bill_amount after deductions
  UPDATE vendor_payment_schedule
  SET 
    original_final_amount = current_bill_amount,  -- Preserve original bill amount for constraint
    final_bill_amount = calculated_final_amount,  -- Set final amount after deductions
    discount_amount = new_discount_amount,
    discount_notes = discount_notes_val,
    grr_amount = new_grr_amount,
    grr_reference_number = grr_reference_val,
    grr_notes = grr_notes_val,
    pri_amount = new_pri_amount,
    pri_reference_number = pri_reference_val,
    pri_notes = pri_notes_val,
    adjustment_history = COALESCE(history_val, adjustment_history),
    updated_at = NOW()
  WHERE id = payment_id;
  
  -- Verify the update succeeded
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment record not found: %', payment_id;
--

--
-- Name: update_warning_main_category_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_warning_main_category_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_warning_sub_category_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_warning_sub_category_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: update_warning_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_warning_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: update_warning_violation_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_warning_violation_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


--
-- Name: upsert_app_icon(text, text, text, text, text, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_app_icon(p_icon_key text, p_name text, p_category text, p_storage_path text, p_mime_type text DEFAULT NULL::text, p_file_size bigint DEFAULT 0, p_description text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO public.app_icons (icon_key, name, category, storage_path, mime_type, file_size, description, created_by)
    VALUES (p_icon_key, p_name, p_category, p_storage_path, p_mime_type, p_file_size, p_description, auth.uid())
    ON CONFLICT (icon_key) DO UPDATE SET
        name = EXCLUDED.name,
        category = EXCLUDED.category,
        storage_path = EXCLUDED.storage_path,
        mime_type = EXCLUDED.mime_type,
        file_size = EXCLUDED.file_size,
        description = EXCLUDED.description,
        updated_at = now()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$;


--
-- Name: upsert_branch_sync_config(bigint, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_branch_sync_config(p_branch_id bigint, p_local_supabase_url text, p_local_supabase_key text, p_tunnel_url text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO branch_sync_config (branch_id, local_supabase_url, local_supabase_key, tunnel_url, is_active)
    VALUES (p_branch_id, p_local_supabase_url, p_local_supabase_key, p_tunnel_url, true)
    ON CONFLICT (branch_id) DO UPDATE SET
        local_supabase_url = EXCLUDED.local_supabase_url,
        local_supabase_key = EXCLUDED.local_supabase_key,
        tunnel_url = COALESCE(EXCLUDED.tunnel_url, branch_sync_config.tunnel_url),
        updated_at = now()
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;


--
-- Name: upsert_branch_sync_config(bigint, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_branch_sync_config(p_branch_id bigint, p_local_supabase_url text, p_local_supabase_key text, p_tunnel_url text DEFAULT NULL::text, p_ssh_user text DEFAULT 'u'::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO branch_sync_config (branch_id, local_supabase_url, local_supabase_key, tunnel_url, ssh_user)
  VALUES (p_branch_id, p_local_supabase_url, p_local_supabase_key, p_tunnel_url, COALESCE(p_ssh_user, 'u'))
  ON CONFLICT (branch_id) DO UPDATE SET
    local_supabase_url = EXCLUDED.local_supabase_url,
    local_supabase_key = EXCLUDED.local_supabase_key,
    tunnel_url = COALESCE(EXCLUDED.tunnel_url, branch_sync_config.tunnel_url),
    ssh_user = COALESCE(EXCLUDED.ssh_user, branch_sync_config.ssh_user, 'u'),
    updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;


--
-- Name: upsert_erp_products_with_expiry(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_erp_products_with_expiry(p_products jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  v_inserted int := 0;
  v_updated int := 0;
  v_product jsonb;
  v_existing_expiry jsonb;
  v_new_expiry jsonb;
  v_merged_expiry jsonb;
  v_branch_id bigint;
BEGIN
  FOR v_product IN SELECT * FROM jsonb_array_elements(p_products)
  LOOP
    v_new_expiry := COALESCE(v_product->'expiry_dates', '[]'::jsonb);
    
    -- Try to get existing record
    SELECT expiry_dates INTO v_existing_expiry
    FROM erp_synced_products
    WHERE barcode = v_product->>'barcode';
    
    IF v_existing_expiry IS NOT NULL THEN
      -- Record exists - merge expiry dates
      -- Remove entries for the same branch_id(s) we're inserting, then append new ones
      v_merged_expiry := COALESCE(v_existing_expiry, '[]'::jsonb);
      
      FOR v_branch_id IN SELECT (elem->>'branch_id')::bigint FROM jsonb_array_elements(v_new_expiry) AS elem
      LOOP
        -- Remove existing entry for this branch_id
        SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
        INTO v_merged_expiry
        FROM jsonb_array_elements(v_merged_expiry) AS elem
        WHERE (elem->>'branch_id')::bigint != v_branch_id;
      END LOOP;
      
      -- Append new entries
      v_merged_expiry := v_merged_expiry || v_new_expiry;
      
      UPDATE erp_synced_products
      SET 
        auto_barcode = COALESCE(v_product->>'auto_barcode', auto_barcode),
        parent_barcode = COALESCE(v_product->>'parent_barcode', parent_barcode),
        product_name_en = COALESCE(v_product->>'product_name_en', product_name_en),
        product_name_ar = COALESCE(v_product->>'product_name_ar', product_name_ar),
        unit_name = COALESCE(v_product->>'unit_name', unit_name),
        unit_qty = COALESCE((v_product->>'unit_qty')::numeric, unit_qty),
        is_base_unit = COALESCE((v_product->>'is_base_unit')::boolean, is_base_unit),
        expiry_dates = v_merged_expiry,
        synced_at = NOW()
      WHERE barcode = v_product->>'barcode';
      
--

--
-- Name: upsert_hr_department(text, text, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_hr_department(p_name_en text, p_name_ar text, p_id uuid DEFAULT NULL::uuid, p_is_active boolean DEFAULT true) RETURNS TABLE(id uuid, department_name_en character varying, department_name_ar character varying, is_active boolean, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF trim(COALESCE(p_name_en, '')) = '' OR trim(COALESCE(p_name_ar, '')) = '' THEN
    RAISE EXCEPTION 'Both English and Arabic names are required';
  END IF;

  IF p_id IS NULL THEN
    RETURN QUERY
    INSERT INTO hr_departments (department_name_en, department_name_ar, is_active)
    VALUES (trim(p_name_en), trim(p_name_ar), COALESCE(p_is_active, true))
    RETURNING
      hr_departments.id,
      hr_departments.department_name_en,
      hr_departments.department_name_ar,
      hr_departments.is_active,
      hr_departments.created_at;
  ELSE
    RETURN QUERY
    UPDATE hr_departments
    SET
      department_name_en = trim(p_name_en),
      department_name_ar = trim(p_name_ar),
      is_active = COALESCE(p_is_active, true)
    WHERE hr_departments.id = p_id
    RETURNING
      hr_departments.id,
      hr_departments.department_name_en,
      hr_departments.department_name_ar,
      hr_departments.is_active,
      hr_departments.created_at;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Department not found';
    END IF;
  END IF;
END;
$$;


--
-- Name: upsert_hr_employee_applicability_rule(text, text, bigint, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_hr_employee_applicability_rule(p_employee_id text, p_rule_type text, p_rule_id bigint DEFAULT NULL::bigint, p_enabled boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_rule public.settlement_rules%ROWTYPE;
    v_join_date date;
    v_total_months integer;
    v_cycle_months integer;
    v_completed_cycles integer;
    v_qualified integer;
BEGIN
    IF p_employee_id IS NULL OR BTRIM(p_employee_id) = '' THEN
        RAISE EXCEPTION 'p_employee_id is required';
    END IF;

    IF p_rule_type NOT IN ('ticket', 'leave_salary') THEN
        RAISE EXCEPTION 'p_rule_type must be ticket or leave_salary';
    END IF;

    SELECT e.join_date INTO v_join_date
    FROM public.hr_employee_master e
    WHERE e.id = p_employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee % was not found', p_employee_id;
    END IF;

    INSERT INTO public.hr_employee_settlement_applicability (employee_id)
    VALUES (p_employee_id)
    ON CONFLICT (employee_id) DO NOTHING;

    IF COALESCE(p_enabled, false) = false THEN
        IF p_rule_type = 'ticket' THEN
            UPDATE public.hr_employee_settlement_applicability
            SET
                ticket_rule_id = NULL,
                ticket_rule_enabled = false,
                qualified_ticket_count = NULL
            WHERE employee_id = p_employee_id;
        ELSE
            UPDATE public.hr_employee_settlement_applicability
            SET
                leave_salary_rule_id = NULL,
                leave_salary_rule_enabled = false,
                qualified_leave_days = NULL
            WHERE employee_id = p_employee_id;
        END IF;
        RETURN;
    END IF;

--

--
-- Name: upsert_hr_level(text, text, integer, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_hr_level(p_name_en text, p_name_ar text, p_level_order integer, p_id uuid DEFAULT NULL::uuid, p_is_active boolean DEFAULT true) RETURNS TABLE(id uuid, level_name_en character varying, level_name_ar character varying, level_order integer, is_active boolean, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF trim(COALESCE(p_name_en, '')) = '' OR trim(COALESCE(p_name_ar, '')) = '' THEN
    RAISE EXCEPTION 'Both English and Arabic names are required';
  END IF;
  IF p_level_order IS NULL OR p_level_order < 1 THEN
    RAISE EXCEPTION 'Level order must be a positive integer';
  END IF;

  IF p_id IS NULL THEN
    RETURN QUERY
    INSERT INTO hr_levels (level_name_en, level_name_ar, level_order, is_active)
    VALUES (trim(p_name_en), trim(p_name_ar), p_level_order, COALESCE(p_is_active, true))
    RETURNING
      hr_levels.id,
      hr_levels.level_name_en,
      hr_levels.level_name_ar,
      hr_levels.level_order,
      hr_levels.is_active,
      hr_levels.created_at;
  ELSE
    RETURN QUERY
    UPDATE hr_levels
    SET
      level_name_en = trim(p_name_en),
      level_name_ar = trim(p_name_ar),
      level_order = p_level_order,
      is_active = COALESCE(p_is_active, true)
    WHERE hr_levels.id = p_id
    RETURNING
      hr_levels.id,
      hr_levels.level_name_en,
      hr_levels.level_name_ar,
      hr_levels.level_order,
      hr_levels.is_active,
      hr_levels.created_at;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Level not found';
    END IF;
  END IF;
END;
$$;


--
-- Name: upsert_hr_position(text, text, uuid, uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_hr_position(p_title_en text, p_title_ar text, p_department_id uuid, p_level_id uuid, p_id uuid DEFAULT NULL::uuid, p_is_active boolean DEFAULT true) RETURNS TABLE(id uuid, position_title_en character varying, position_title_ar character varying, department_id uuid, level_id uuid, is_active boolean, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF trim(COALESCE(p_title_en, '')) = '' OR trim(COALESCE(p_title_ar, '')) = '' THEN
    RAISE EXCEPTION 'Both English and Arabic titles are required';
  END IF;
  IF p_department_id IS NULL THEN
    RAISE EXCEPTION 'Department is required';
  END IF;
  IF p_level_id IS NULL THEN
    RAISE EXCEPTION 'Level is required';
  END IF;

  IF p_id IS NULL THEN
    RETURN QUERY
    INSERT INTO hr_positions (position_title_en, position_title_ar, department_id, level_id, is_active)
    VALUES (trim(p_title_en), trim(p_title_ar), p_department_id, p_level_id, COALESCE(p_is_active, true))
    RETURNING
      hr_positions.id,
      hr_positions.position_title_en,
      hr_positions.position_title_ar,
      hr_positions.department_id,
      hr_positions.level_id,
      hr_positions.is_active,
      hr_positions.created_at;
  ELSE
    RETURN QUERY
    UPDATE hr_positions
    SET
      position_title_en = trim(p_title_en),
      position_title_ar = trim(p_title_ar),
      department_id = p_department_id,
      level_id = p_level_id,
      is_active = COALESCE(p_is_active, true)
    WHERE hr_positions.id = p_id
    RETURNING
      hr_positions.id,
      hr_positions.position_title_en,
      hr_positions.position_title_ar,
      hr_positions.department_id,
      hr_positions.level_id,
      hr_positions.is_active,
      hr_positions.created_at;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Position not found';
    END IF;
  END IF;
END;
--

--
-- Name: upsert_social_links(bigint, text, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_social_links(_branch_id bigint, _facebook text DEFAULT NULL::text, _whatsapp text DEFAULT NULL::text, _instagram text DEFAULT NULL::text, _tiktok text DEFAULT NULL::text, _snapchat text DEFAULT NULL::text, _website text DEFAULT NULL::text, _location_link text DEFAULT NULL::text) RETURNS TABLE(id uuid, branch_id bigint, facebook text, whatsapp text, instagram text, tiktok text, snapchat text, website text, location_link text, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE sql
    AS $$
  INSERT INTO public.social_links (branch_id, facebook, whatsapp, instagram, tiktok, snapchat, website, location_link)
  VALUES (_branch_id, _facebook, _whatsapp, _instagram, _tiktok, _snapchat, _website, _location_link)
  ON CONFLICT (branch_id) DO UPDATE SET
    facebook = _facebook,
    whatsapp = _whatsapp,
    instagram = _instagram,
    tiktok = _tiktok,
    snapchat = _snapchat,
    website = _website,
    location_link = _location_link,
    updated_at = NOW()
  RETURNING id, branch_id, facebook, whatsapp, instagram, tiktok, snapchat, website, location_link, created_at, updated_at
$$;


--
-- Name: validate_break_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_break_code(p_code text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_seed text;
    v_epoch bigint;
    v_current_code text;
    v_previous_code text;
BEGIN
    SELECT seed INTO v_seed FROM break_security_seed WHERE id = 1;
    
    IF v_seed IS NULL THEN
        RETURN false;
    END IF;
    
    v_epoch := floor(extract(epoch from now()) / 10)::bigint;
    
    -- Current 10-sec window code
    v_current_code := substring(md5(v_seed || v_epoch::text) from 1 for 12);
    
    -- Previous 10-sec window code (for network delay tolerance)
    v_previous_code := substring(md5(v_seed || (v_epoch - 1)::text) from 1 for 12);
    
    RETURN (p_code = v_current_code OR p_code = v_previous_code);
END;
$$;


--
-- Name: validate_bundle_offer_type(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_bundle_offer_type() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_offer_type VARCHAR;
BEGIN
    -- Get the offer type
    SELECT type INTO v_offer_type FROM offers WHERE id = NEW.offer_id;
    
    IF v_offer_type IS NULL THEN
        RAISE EXCEPTION 'Offer with id % does not exist', NEW.offer_id;
    END IF;
    
    IF v_offer_type != 'bundle' THEN
        RAISE EXCEPTION 'Offer with id % must be of type "bundle" but is "%"', NEW.offer_id, v_offer_type;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: validate_coupon_eligibility(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_coupon_eligibility(p_campaign_code character varying, p_mobile_number character varying) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_campaign_id UUID;
  v_campaign_name VARCHAR;
  v_is_active BOOLEAN;
  v_validity_start TIMESTAMP WITH TIME ZONE;
  v_validity_end TIMESTAMP WITH TIME ZONE;
  v_max_claims_per_customer INTEGER;
  v_is_eligible BOOLEAN;
  v_current_claim_count INTEGER;
BEGIN
  -- Get campaign details
  SELECT 
    id, 
    campaign_name, 
    is_active,
    validity_start_date,
    validity_end_date,
    COALESCE(max_claims_per_customer, 1)
  INTO 
    v_campaign_id,
    v_campaign_name,
    v_is_active,
    v_validity_start,
    v_validity_end,
    v_max_claims_per_customer
  FROM coupon_campaigns
  WHERE campaign_code = p_campaign_code
    AND deleted_at IS NULL;
  
  -- Check if campaign exists
  IF v_campaign_id IS NULL THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'error_message', 'Campaign code not found'
    );
  END IF;
  
  -- Check if campaign is active
  IF NOT v_is_active THEN
    RETURN jsonb_build_object(
      'eligible', false,
      'error_message', 'Campaign is not active'
    );
  END IF;
  
  -- Check if within validity period
  IF now() < v_validity_start OR now() > v_validity_end THEN
    RETURN jsonb_build_object(
--

--
-- Name: validate_flyer_template_configuration(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_flyer_template_configuration(config jsonb) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  field JSONB;
  required_keys TEXT[] := ARRAY['id', 'number', 'x', 'y', 'width', 'height', 'fields'];
BEGIN
  -- Check if config is an array
  IF jsonb_typeof(config) != 'array' THEN
    RAISE EXCEPTION 'Configuration must be a JSON array';
  END IF;
  
  -- Validate each field
  FOR field IN SELECT * FROM jsonb_array_elements(config)
  LOOP
    -- Check required keys exist
    IF NOT (field ?& required_keys) THEN
      RAISE EXCEPTION 'Field missing required keys. Required: %', required_keys;
    END IF;
    
    -- Validate data types
    IF jsonb_typeof(field->'fields') != 'array' THEN
      RAISE EXCEPTION 'Field "fields" must be an array';
    END IF;
    
    -- Validate numeric ranges
    IF (field->>'width')::int <= 0 OR (field->>'height')::int <= 0 THEN
      RAISE EXCEPTION 'Field width and height must be positive';
    END IF;
  END LOOP;
  
  RETURN true;
END;
$$;


--
-- Name: validate_payment_methods(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_payment_methods(payment_methods text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    valid_methods TEXT[] := ARRAY['Cash on Delivery', 'Bank on Delivery', 'Cash Credit', 'Bank Credit'];
    method TEXT;
    methods TEXT[];
BEGIN
    IF payment_methods IS NULL OR LENGTH(TRIM(payment_methods)) = 0 THEN
        RETURN TRUE;
    END IF;
    
    -- Split comma-separated values
    methods := string_to_array(payment_methods, ',');
    
    -- Check each method
    FOREACH method IN ARRAY methods
    LOOP
        IF TRIM(method) != ANY(valid_methods) THEN
            RETURN FALSE;
        END IF;
    END LOOP;
    
    RETURN TRUE;
END;
$$;


--
-- Name: validate_product_offer(integer, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_product_offer(p_offer_id integer, p_product_id uuid, p_quantity integer) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
  v_offer_qty INTEGER;
  v_is_active BOOLEAN;
  v_start_date TIMESTAMPTZ;
  v_end_date TIMESTAMPTZ;
BEGIN
  SELECT 
    op.offer_qty,
    o.is_active,
    o.start_date,
    o.end_date
  INTO 
    v_offer_qty,
    v_is_active,
    v_start_date,
    v_end_date
  FROM offer_products op
  INNER JOIN offers o ON op.offer_id = o.id
  WHERE op.offer_id = p_offer_id 
    AND op.product_id = p_product_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  IF NOT v_is_active THEN
    RETURN FALSE;
  END IF;
  
  IF NOW() < v_start_date OR NOW() > v_end_date THEN
    RETURN FALSE;
  END IF;
  
  IF p_quantity < v_offer_qty THEN
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$$;


--
-- Name: FUNCTION validate_product_offer(p_offer_id integer, p_product_id uuid, p_quantity integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.validate_product_offer(p_offer_id integer, p_product_id uuid, p_quantity integer) IS 'Validate if product offer can be applied';


--
-- Name: validate_task_completion_requirements(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_task_completion_requirements(receiving_task_id_param uuid, user_id_param uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    receiving_task RECORD;
    receiving_record RECORD;
    validation_result JSONB;
    missing_requirements TEXT[] := '{}';
BEGIN
    -- Get receiving task
    SELECT * INTO receiving_task 
    FROM receiving_tasks 
    WHERE id = receiving_task_id_param AND assigned_user_id = user_id_param;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Task not found or user not authorized'
        );
    END IF;
    
    -- Get receiving record
    SELECT * INTO receiving_record 
    FROM receiving_records 
    WHERE id = receiving_task.receiving_record_id;
    
    -- Check ERP reference requirement
    IF receiving_task.requires_erp_reference AND receiving_task.erp_reference_number IS NULL THEN
        missing_requirements := missing_requirements || 'ERP reference number required';
    END IF;
    
    -- Check original bill upload requirement (especially for inventory manager)
    IF receiving_task.requires_original_bill_upload THEN
        -- Check if original bill has been uploaded to receiving record
        IF receiving_record.original_bill_url IS NULL OR receiving_record.original_bill_url = '' THEN
            missing_requirements := missing_requirements || 'Original bill must be uploaded through Receive Record window';
        ELSE
            -- Auto-update the receiving task if bill is already uploaded
            UPDATE receiving_tasks 
            SET 
                original_bill_uploaded = true,
                original_bill_file_path = receiving_record.original_bill_url,
                updated_at = now()
            WHERE id = receiving_task_id_param;
        END IF;
    END IF;
    
    validation_result := jsonb_build_object(
        'valid', array_length(missing_requirements, 1) IS NULL,
        'missing_requirements', missing_requirements,
        'task_id', receiving_task.task_id,
--

--
-- Name: validate_variation_prices(integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_variation_prices(p_offer_id integer, p_group_id uuid) RETURNS TABLE(barcode text, product_name_en text, offer_price numeric, offer_percentage numeric, price_mismatch boolean)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  RETURN QUERY
  WITH group_prices AS (
    SELECT 
      op.offer_price,
      op.offer_percentage,
      COUNT(DISTINCT op.offer_price) OVER () as price_count,
      COUNT(DISTINCT op.offer_percentage) OVER () as percentage_count
    FROM offer_products op
    WHERE op.offer_id = p_offer_id
      AND op.variation_group_id = p_group_id
    LIMIT 1
  )
  SELECT 
    p.barcode,
    p.product_name_en,
    op.offer_price,
    op.offer_percentage,
    CASE 
      WHEN gp.price_count > 1 OR gp.percentage_count > 1 THEN true
      ELSE false
    END as price_mismatch
  FROM offer_products op
  JOIN products p ON op.product_id = p.id
  CROSS JOIN group_prices gp
  WHERE op.offer_id = p_offer_id
    AND op.variation_group_id = p_group_id
  ORDER BY p.variation_order, p.product_name_en;
END;
$$;


--
-- Name: validate_vendor_branch_match(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_vendor_branch_match() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if vendor belongs to the selected branch or is unassigned
    IF NOT EXISTS (
        SELECT 1 FROM vendors 
        WHERE erp_vendor_id = NEW.vendor_id 
        AND (branch_id = NEW.branch_id OR branch_id IS NULL)
    ) THEN
        RAISE EXCEPTION 'Vendor % does not belong to branch % or is not assigned to any branch', 
            NEW.vendor_id, NEW.branch_id;
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION validate_vendor_branch_match(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.validate_vendor_branch_match() IS 'Validates that vendor belongs to the branch specified in receiving record';


--
-- Name: verify_otp_and_change_access_code(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verify_otp_and_change_access_code(p_email character varying, p_whatsapp character varying, p_otp character varying, p_new_code character varying) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_otp_record RECORD;
  v_whatsapp_clean VARCHAR(20);
  v_hashed_code VARCHAR(255);
  v_existing_count INT;
BEGIN
  v_whatsapp_clean := REGEXP_REPLACE(p_whatsapp, '[\s\-]', '', 'g');

  -- Find matching user (correct JOIN: e.user_id = u.id)
  SELECT u.id INTO v_user_id
  FROM users u
  JOIN hr_employee_master e ON e.user_id = u.id
  WHERE LOWER(TRIM(e.email)) = LOWER(TRIM(p_email))
    AND REGEXP_REPLACE(e.whatsapp_number, '[\s\-]', '', 'g') = v_whatsapp_clean
    AND u.status = 'active'
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'User not found.');
  END IF;

  -- Find valid OTP
  SELECT id, otp_code, attempts INTO v_otp_record
  FROM access_code_otp
  WHERE user_id = v_user_id
    AND verified = false
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_otp_record IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No valid OTP found. Please request a new one.');
  END IF;

  -- Check attempts
  IF v_otp_record.attempts >= 5 THEN
    UPDATE access_code_otp SET verified = true WHERE id = v_otp_record.id;
    RETURN json_build_object('success', false, 'message', 'Too many failed attempts. Please request a new OTP.');
  END IF;

  -- Verify OTP
  IF v_otp_record.otp_code != p_otp THEN
    UPDATE access_code_otp SET attempts = attempts + 1 WHERE id = v_otp_record.id;
    RETURN json_build_object('success', false, 'message', 'Invalid OTP code.');
  END IF;

--

--
-- Name: verify_password(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verify_password(password text, hash text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN hash = crypt(password, hash);
END;
$$;


--
-- Name: verify_password(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verify_password(input_username character varying, input_password character varying) RETURNS TABLE(user_id uuid, username character varying, email character varying, role_type character varying, is_valid boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        u.username,
        u.email,
        -- Return derived role_type for backward compatibility
        CASE 
            WHEN u.is_master_admin = true THEN 'Master Admin'::character varying
            WHEN u.is_admin = true THEN 'Admin'::character varying
            ELSE 'User'::character varying
        END as role_type,
        (u.password_hash = crypt(input_password, u.password_hash)) as is_valid
    FROM users u
    WHERE u.username = input_username
      AND u.deleted_at IS NULL
    LIMIT 1;
END;
$$;


--
-- Name: verify_quick_access_code(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verify_quick_access_code(p_code character varying) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
  v_user RECORD;
BEGIN
  -- Validate input format
  IF p_code IS NULL OR LENGTH(p_code) != 6 OR p_code !~ '^[0-9]{6}$' THEN
    RETURN json_build_object('success', false, 'error', 'Invalid access code format');
  END IF;

  -- Find user where crypt(input, stored_hash) = stored_hash
  SELECT id, username, user_type, status, is_master_admin, is_admin,
         employee_id, branch_id, position_id, avatar, quick_access_code, quick_access_salt
  INTO v_user
  FROM users
  WHERE status = 'active'
    AND extensions.crypt(p_code, quick_access_code) = quick_access_code;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Invalid access code');
  END IF;

  RETURN json_build_object(
    'success', true,
    'user', json_build_object(
      'id', v_user.id,
      'username', v_user.username,
      'user_type', v_user.user_type,
      'status', v_user.status,
      'is_master_admin', v_user.is_master_admin,
      'is_admin', v_user.is_admin,
      'employee_id', v_user.employee_id,
      'branch_id', v_user.branch_id,
      'position_id', v_user.position_id,
      'avatar', v_user.avatar
    )
  );
END;
$_$;


--
-- Name: verify_quick_task_completion(uuid, uuid, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verify_quick_task_completion(completion_id_param uuid, verified_by_user_id_param uuid, verification_notes_param text DEFAULT NULL::text, is_approved boolean DEFAULT true) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_status VARCHAR(50);
BEGIN
    IF is_approved THEN
        new_status := 'verified';
    ELSE
        new_status := 'rejected';
    END IF;
    
    UPDATE quick_task_completions 
    SET completion_status = new_status,
        verified_by_user_id = verified_by_user_id_param,
        verified_at = now(),
        verification_notes = verification_notes_param,
        updated_at = now()
    WHERE id = completion_id_param;
    
    RETURN FOUND;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: access_code_otp; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.access_code_otp (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    otp_code character varying(6) NOT NULL,
    email character varying(255) NOT NULL,
    whatsapp_number character varying(20) NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:05:00'::interval) NOT NULL,
    verified boolean DEFAULT false,
    attempts integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_chat_guide; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_chat_guide (
--

--
-- Name: ai_chat_guide ai_chat_guide_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ai_chat_guide_timestamp_update BEFORE UPDATE ON public.ai_chat_guide FOR EACH ROW EXECUTE FUNCTION public.update_ai_chat_guide_timestamp();


--
-- Name: approver_visibility_config approver_visibility_config_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER approver_visibility_config_timestamp_update BEFORE UPDATE ON public.approver_visibility_config FOR EACH ROW EXECUTE FUNCTION public.update_approver_visibility_config_timestamp();


--
-- Name: bank_reconciliations bank_reconciliations_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER bank_reconciliations_timestamp_update BEFORE UPDATE ON public.bank_reconciliations FOR EACH ROW EXECUTE FUNCTION public.update_bank_reconciliations_timestamp();


--
-- Name: box_operations box_operations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER box_operations_updated_at BEFORE UPDATE ON public.box_operations FOR EACH ROW EXECUTE FUNCTION public.update_box_operations_updated_at();


--
-- Name: branch_default_positions branch_default_positions_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER branch_default_positions_timestamp_update BEFORE UPDATE ON public.branch_default_positions FOR EACH ROW EXECUTE FUNCTION public.update_branch_default_positions_timestamp();


--
-- Name: branches branches_notify_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER branches_notify_trigger AFTER INSERT OR DELETE OR UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION public.notify_branches_change();


--
-- Name: receiving_records calculate_receiving_amounts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER calculate_receiving_amounts_trigger BEFORE INSERT OR UPDATE ON public.receiving_records FOR EACH ROW EXECUTE FUNCTION public.calculate_receiving_amounts();


--
-- Name: regular_shift calculate_working_hours_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER calculate_working_hours_trigger BEFORE INSERT OR UPDATE ON public.regular_shift FOR EACH ROW EXECUTE FUNCTION public.calculate_working_hours();


--
-- Name: task_assignments cleanup_assignment_notifications_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER cleanup_assignment_notifications_trigger AFTER DELETE ON public.task_assignments FOR EACH ROW EXECUTE FUNCTION public.trigger_cleanup_assignment_notifications();


--
-- Name: tasks cleanup_task_notifications_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER cleanup_task_notifications_trigger AFTER DELETE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.trigger_cleanup_task_notifications();


--
-- Name: day_off_reasons day_off_reasons_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER day_off_reasons_timestamp_update BEFORE UPDATE ON public.day_off_reasons FOR EACH ROW EXECUTE FUNCTION public.update_day_off_reasons_timestamp();


--
-- Name: day_off day_off_timestamp_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER day_off_timestamp_trigger BEFORE UPDATE ON public.day_off FOR EACH ROW EXECUTE FUNCTION public.update_day_off_timestamp();


--
-- Name: day_off_weekday day_off_weekday_updated_at_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER day_off_weekday_updated_at_trigger BEFORE UPDATE ON public.day_off_weekday FOR EACH ROW EXECUTE FUNCTION public.update_day_off_weekday_updated_at();


--
-- Name: denomination_records denomination_records_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER denomination_records_audit AFTER INSERT OR DELETE OR UPDATE ON public.denomination_records FOR EACH ROW EXECUTE FUNCTION public.denomination_audit_trigger();


--
-- Name: denomination_records denomination_records_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER denomination_records_updated_at BEFORE UPDATE ON public.denomination_records FOR EACH ROW EXECUTE FUNCTION public.update_denomination_updated_at();


--
-- Name: denomination_transactions denomination_transactions_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER denomination_transactions_timestamp_update BEFORE UPDATE ON public.denomination_transactions FOR EACH ROW EXECUTE FUNCTION public.update_denomination_transactions_timestamp();


--
-- Name: denomination_types denomination_types_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER denomination_types_updated_at BEFORE UPDATE ON public.denomination_types FOR EACH ROW EXECUTE FUNCTION public.update_denomination_updated_at();


--
-- Name: desktop_themes desktop_themes_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER desktop_themes_timestamp_update BEFORE UPDATE ON public.desktop_themes FOR EACH ROW EXECUTE FUNCTION public.update_desktop_themes_timestamp();


--
-- Name: erp_daily_sales erp_daily_sales_notify_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER erp_daily_sales_notify_trigger AFTER INSERT OR DELETE OR UPDATE ON public.erp_daily_sales FOR EACH ROW EXECUTE FUNCTION public.notify_erp_daily_sales_change();


--
-- Name: expense_scheduler expense_scheduler_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER expense_scheduler_updated_at BEFORE UPDATE ON public.expense_scheduler FOR EACH ROW EXECUTE FUNCTION public.update_expense_scheduler_updated_at();


--
-- Name: hr_checklist_operations hr_checklist_operations_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER hr_checklist_operations_timestamp_update BEFORE UPDATE ON public.hr_checklist_operations FOR EACH ROW EXECUTE FUNCTION public.update_hr_checklist_operations_timestamp();


--
-- Name: hr_checklist_questions hr_checklist_questions_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER hr_checklist_questions_timestamp_update BEFORE UPDATE ON public.hr_checklist_questions FOR EACH ROW EXECUTE FUNCTION public.update_hr_checklist_questions_timestamp();


--
-- Name: hr_checklists hr_checklists_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER hr_checklists_timestamp_update BEFORE UPDATE ON public.hr_checklists FOR EACH ROW EXECUTE FUNCTION public.update_hr_checklists_timestamp();


--
-- Name: hr_employee_master hr_employee_master_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER hr_employee_master_timestamp_update BEFORE UPDATE ON public.hr_employee_master FOR EACH ROW EXECUTE FUNCTION public.update_hr_employee_master_timestamp();


--
-- Name: hr_salary_statements hr_salary_statements_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER hr_salary_statements_set_updated_at BEFORE UPDATE ON public.hr_salary_statements FOR EACH ROW EXECUTE FUNCTION public.tg_hr_salary_statements_set_updated_at();


--
-- Name: purchase_voucher_issue_types issue_types_updated_at_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER issue_types_updated_at_trigger BEFORE UPDATE ON public.purchase_voucher_issue_types FOR EACH ROW EXECUTE FUNCTION public.update_issue_types_updated_at();


--
-- Name: lease_rent_lease_parties lease_rent_lease_parties_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lease_rent_lease_parties_timestamp_update BEFORE UPDATE ON public.lease_rent_lease_parties FOR EACH ROW EXECUTE FUNCTION public.update_lease_rent_lease_parties_timestamp();


--
-- Name: lease_rent_properties lease_rent_properties_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lease_rent_properties_timestamp_update BEFORE UPDATE ON public.lease_rent_properties FOR EACH ROW EXECUTE FUNCTION public.update_lease_rent_property_spaces_timestamp();


--
-- Name: lease_rent_property_spaces lease_rent_property_spaces_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lease_rent_property_spaces_timestamp_update BEFORE UPDATE ON public.lease_rent_property_spaces FOR EACH ROW EXECUTE FUNCTION public.update_lease_rent_property_spaces_timestamp();


--
-- Name: lease_rent_rent_parties lease_rent_rent_parties_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lease_rent_rent_parties_timestamp_update BEFORE UPDATE ON public.lease_rent_rent_parties FOR EACH ROW EXECUTE FUNCTION public.update_lease_rent_rent_parties_timestamp();


--
-- Name: multi_shift_date_wise multi_shift_date_wise_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER multi_shift_date_wise_timestamp_update BEFORE UPDATE ON public.multi_shift_date_wise FOR EACH ROW EXECUTE FUNCTION public.update_multi_shift_date_wise_timestamp();


--
-- Name: multi_shift_regular multi_shift_regular_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER multi_shift_regular_timestamp_update BEFORE UPDATE ON public.multi_shift_regular FOR EACH ROW EXECUTE FUNCTION public.update_multi_shift_regular_timestamp();


--
-- Name: multi_shift_weekday multi_shift_weekday_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER multi_shift_weekday_timestamp_update BEFORE UPDATE ON public.multi_shift_weekday FOR EACH ROW EXECUTE FUNCTION public.update_multi_shift_weekday_timestamp();


--
-- Name: non_approved_payment_scheduler non_approved_scheduler_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER non_approved_scheduler_updated_at BEFORE UPDATE ON public.non_approved_payment_scheduler FOR EACH ROW EXECUTE FUNCTION public.update_non_approved_scheduler_updated_at();


--
-- Name: official_holidays official_holidays_timestamp_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER official_holidays_timestamp_trigger BEFORE UPDATE ON public.official_holidays FOR EACH ROW EXECUTE FUNCTION public.update_official_holidays_timestamp();


--
-- Name: product_request_bt product_request_bt_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_request_bt_timestamp_update BEFORE UPDATE ON public.product_request_bt FOR EACH ROW EXECUTE FUNCTION public.update_product_request_bt_timestamp();


--
-- Name: product_request_po product_request_po_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_request_po_timestamp_update BEFORE UPDATE ON public.product_request_po FOR EACH ROW EXECUTE FUNCTION public.update_product_request_po_timestamp();


--
-- Name: product_request_st product_request_st_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_request_st_timestamp_update BEFORE UPDATE ON public.product_request_st FOR EACH ROW EXECUTE FUNCTION public.update_product_request_st_timestamp();


--
-- Name: purchase_voucher_items purchase_voucher_items_updated_at_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER purchase_voucher_items_updated_at_trigger BEFORE UPDATE ON public.purchase_voucher_items FOR EACH ROW EXECUTE FUNCTION public.update_purchase_voucher_items_updated_at();


--
-- Name: purchase_vouchers purchase_vouchers_updated_at_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER purchase_vouchers_updated_at_trigger BEFORE UPDATE ON public.purchase_vouchers FOR EACH ROW EXECUTE FUNCTION public.update_purchase_vouchers_updated_at();


--
-- Name: receiving_user_defaults receiving_user_defaults_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER receiving_user_defaults_timestamp_update BEFORE UPDATE ON public.receiving_user_defaults FOR EACH ROW EXECUTE FUNCTION public.update_receiving_user_defaults_timestamp();


--
-- Name: regular_shift regular_shift_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER regular_shift_timestamp_update BEFORE UPDATE ON public.regular_shift FOR EACH ROW EXECUTE FUNCTION public.update_regular_shift_timestamp();


--
-- Name: branch_default_delivery_receivers set_branch_delivery_receivers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_branch_delivery_receivers_updated_at BEFORE UPDATE ON public.branch_default_delivery_receivers FOR EACH ROW EXECUTE FUNCTION public.update_branch_delivery_receivers_updated_at();


--
-- Name: hr_employee_applicability_rule_periods set_hr_employee_applicability_rule_periods_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_hr_employee_applicability_rule_periods_updated_at BEFORE UPDATE ON public.hr_employee_applicability_rule_periods FOR EACH ROW EXECUTE FUNCTION public.update_hr_employee_applicability_rule_periods_updated_at();


--
-- Name: hr_employee_leave_approvals set_hr_employee_leave_approvals_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_hr_employee_leave_approvals_updated_at BEFORE UPDATE ON public.hr_employee_leave_approvals FOR EACH ROW EXECUTE FUNCTION public.update_hr_employee_leave_approvals_updated_at();


--
-- Name: hr_employee_settlement_applicability set_hr_employee_settlement_applicability_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_hr_employee_settlement_applicability_updated_at BEFORE UPDATE ON public.hr_employee_settlement_applicability FOR EACH ROW EXECUTE FUNCTION public.update_hr_employee_settlement_applicability_updated_at();


--
-- Name: hr_employee_ticket_issuances set_hr_employee_ticket_issuances_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_hr_employee_ticket_issuances_updated_at BEFORE UPDATE ON public.hr_employee_ticket_issuances FOR EACH ROW EXECUTE FUNCTION public.update_hr_employee_ticket_issuances_updated_at();


--
-- Name: push_subscriptions set_push_subscriptions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_push_subscriptions_updated_at BEFORE UPDATE ON public.push_subscriptions FOR EACH ROW EXECUTE FUNCTION public.update_push_subscriptions_updated_at();


--
-- Name: settlement_rules set_settlement_rules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_settlement_rules_updated_at BEFORE UPDATE ON public.settlement_rules FOR EACH ROW EXECUTE FUNCTION public.update_settlement_rules_updated_at();


--
-- Name: social_links social_links_updated_at_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER social_links_updated_at_trigger BEFORE UPDATE ON public.social_links FOR EACH ROW EXECUTE FUNCTION public.update_social_links_updated_at();


--
-- Name: special_shift_date_wise special_shift_date_wise_timestamp_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER special_shift_date_wise_timestamp_trigger BEFORE UPDATE ON public.special_shift_date_wise FOR EACH ROW EXECUTE FUNCTION public.update_special_shift_date_wise_timestamp();


--
-- Name: special_shift_weekday special_shift_weekday_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER special_shift_weekday_timestamp_update BEFORE UPDATE ON public.special_shift_weekday FOR EACH ROW EXECUTE FUNCTION public.update_special_shift_weekday_timestamp();


--
-- Name: loyalty_customer_bills sync_customer_loyalty_on_bill; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_customer_loyalty_on_bill AFTER INSERT ON public.loyalty_customer_bills FOR EACH ROW EXECUTE FUNCTION public.trg_sync_customer_loyalty_on_bill();


--
-- Name: expense_scheduler sync_requisition_balance_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_requisition_balance_trigger AFTER INSERT OR UPDATE ON public.expense_scheduler FOR EACH ROW EXECUTE FUNCTION public.sync_requisition_balance();


--
-- Name: hr_positions sync_roles_on_position_changes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_roles_on_position_changes AFTER INSERT OR DELETE OR UPDATE ON public.hr_positions FOR EACH ROW EXECUTE FUNCTION public.sync_user_roles_from_positions();


--
-- Name: system_api_keys system_api_keys_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER system_api_keys_timestamp_update BEFORE UPDATE ON public.system_api_keys FOR EACH ROW EXECUTE FUNCTION public.update_system_api_keys_timestamp();


--
-- Name: customer_app_media track_media_activation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER track_media_activation BEFORE UPDATE ON public.customer_app_media FOR EACH ROW EXECUTE FUNCTION public.track_media_activation();


--
-- Name: app_icons trg_app_icons_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_app_icons_updated_at BEFORE UPDATE ON public.app_icons FOR EACH ROW EXECUTE FUNCTION public.update_app_icons_updated_at();


--
-- Name: background_templates trg_background_templates_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_background_templates_updated_at BEFORE UPDATE ON public.background_templates FOR EACH ROW EXECUTE FUNCTION public.set_background_templates_updated_at();


--
-- Name: hr_insurance_companies trg_generate_insurance_company_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_generate_insurance_company_id BEFORE INSERT ON public.hr_insurance_companies FOR EACH ROW EXECUTE FUNCTION public.generate_insurance_company_id();


--
-- Name: hr_salary_notes trg_hr_salary_notes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_hr_salary_notes_updated_at BEFORE UPDATE ON public.hr_salary_notes FOR EACH ROW EXECUTE FUNCTION public.set_hr_salary_notes_updated_at();


--
-- Name: surprise_box_rewards trg_surprise_box_rewards_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_surprise_box_rewards_updated_at BEFORE UPDATE ON public.surprise_box_rewards FOR EACH ROW EXECUTE FUNCTION public.surprise_box_rewards_set_updated_at();


--
-- Name: surprise_box_settings trg_surprise_box_settings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_surprise_box_settings_updated_at BEFORE UPDATE ON public.surprise_box_settings FOR EACH ROW EXECUTE FUNCTION public.surprise_box_settings_set_updated_at();


--
-- Name: hr_employee_esob_records trg_touch_hr_employee_esob_records; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_touch_hr_employee_esob_records BEFORE UPDATE ON public.hr_employee_esob_records FOR EACH ROW EXECUTE FUNCTION public.touch_hr_esob_updated_at();


--
-- Name: hr_esob_base_rules trg_touch_hr_esob_base_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_touch_hr_esob_base_rules BEFORE UPDATE ON public.hr_esob_base_rules FOR EACH ROW EXECUTE FUNCTION public.touch_hr_esob_updated_at();


--
-- Name: hr_esob_resignation_factors trg_touch_hr_esob_resignation_factors; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_touch_hr_esob_resignation_factors BEFORE UPDATE ON public.hr_esob_resignation_factors FOR EACH ROW EXECUTE FUNCTION public.touch_hr_esob_updated_at();


--
-- Name: vendor_payment_schedule trg_update_final_bill_amount; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_final_bill_amount BEFORE INSERT OR UPDATE OF discount_amount, grr_amount, pri_amount, bill_amount ON public.vendor_payment_schedule FOR EACH ROW EXECUTE FUNCTION public.update_final_bill_amount_on_adjustment();


--
-- Name: user_erp_credentials trg_user_erp_credentials_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_erp_credentials_updated_at BEFORE UPDATE ON public.user_erp_credentials FOR EACH ROW EXECUTE FUNCTION public.set_user_erp_credentials_updated_at();


--
-- Name: vip_campaign_settings trg_vip_campaign_settings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vip_campaign_settings_updated_at BEFORE UPDATE ON public.vip_campaign_settings FOR EACH ROW EXECUTE FUNCTION public.set_vip_redemptions_updated_at();


--
-- Name: vip_redemptions trg_vip_redemptions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vip_redemptions_updated_at BEFORE UPDATE ON public.vip_redemptions FOR EACH ROW EXECUTE FUNCTION public.set_vip_redemptions_updated_at();


--
-- Name: order_items trigger_adjust_product_stock; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_adjust_product_stock BEFORE INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.adjust_product_stock_on_order_insert();


--
-- Name: receiving_records trigger_auto_create_payment_schedule; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_auto_create_payment_schedule AFTER INSERT OR UPDATE OF certificate_url ON public.receiving_records FOR EACH ROW EXECUTE FUNCTION public.auto_create_payment_schedule();


--
-- Name: products trigger_calculate_flyer_product_profit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_calculate_flyer_product_profit BEFORE INSERT OR UPDATE OF sale_price, cost ON public.products FOR EACH ROW EXECUTE FUNCTION public.calculate_flyer_product_profit();


--
-- Name: quick_task_assignments trigger_copy_completion_requirements; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_copy_completion_requirements AFTER INSERT ON public.quick_task_assignments FOR EACH ROW EXECUTE FUNCTION public.copy_completion_requirements_to_assignment();


--
-- Name: users trigger_create_default_interface_permissions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_create_default_interface_permissions AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.create_default_interface_permissions();


--
-- Name: notifications trigger_create_notification_recipients; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_create_notification_recipients AFTER INSERT ON public.notifications FOR EACH ROW WHEN (((new.status)::text = 'published'::text)) EXECUTE FUNCTION public.create_notification_recipients();


--
-- Name: quick_task_assignments trigger_create_quick_task_notification; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_create_quick_task_notification AFTER INSERT ON public.quick_task_assignments FOR EACH ROW EXECUTE FUNCTION public.create_quick_task_notification();


--
-- Name: order_audit_logs trigger_customer_push_on_status_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_customer_push_on_status_change AFTER INSERT ON public.order_audit_logs FOR EACH ROW WHEN (((new.action_type)::text = 'status_change'::text)) EXECUTE FUNCTION public.notify_customer_order_status_change();


--
-- Name: flyer_templates trigger_ensure_single_default_flyer_template; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_ensure_single_default_flyer_template BEFORE INSERT OR UPDATE OF is_default ON public.flyer_templates FOR EACH ROW WHEN ((new.is_default = true)) EXECUTE FUNCTION public.ensure_single_default_flyer_template();


--
-- Name: order_items trigger_link_offer_usage_to_order; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_link_offer_usage_to_order AFTER INSERT ON public.order_items FOR EACH ROW WHEN (((new.has_offer = true) AND (new.offer_id IS NOT NULL))) EXECUTE FUNCTION public.trigger_log_order_offer_usage();


--
-- Name: orders trigger_new_order_notification; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_new_order_notification AFTER INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.trigger_notify_new_order();


--
-- Name: order_items trigger_order_items_delete_totals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_order_items_delete_totals AFTER DELETE ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.trigger_update_order_totals();


--
-- Name: order_items trigger_order_items_insert_totals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_order_items_insert_totals AFTER INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.trigger_update_order_totals();


--
-- Name: order_items trigger_order_items_update_totals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_order_items_update_totals AFTER UPDATE ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.trigger_update_order_totals();


--
-- Name: orders trigger_order_status_change_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_order_status_change_audit AFTER UPDATE ON public.orders FOR EACH ROW WHEN (((old.order_status)::text IS DISTINCT FROM (new.order_status)::text)) EXECUTE FUNCTION public.trigger_order_status_audit();


--
-- Name: quick_task_assignments trigger_order_task_completion; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_order_task_completion AFTER UPDATE ON public.quick_task_assignments FOR EACH ROW WHEN ((((old.status)::text IS DISTINCT FROM (new.status)::text) AND ((new.status)::text = 'completed'::text))) EXECUTE FUNCTION public.handle_order_task_completion();


--
-- Name: task_completions trigger_sync_erp_on_completion; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_sync_erp_on_completion AFTER INSERT OR UPDATE ON public.task_completions FOR EACH ROW EXECUTE FUNCTION public.trigger_sync_erp_reference_on_task_completion();


--
-- Name: bogo_offer_rules trigger_update_bogo_offer_rules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_bogo_offer_rules_updated_at BEFORE UPDATE ON public.bogo_offer_rules FOR EACH ROW EXECUTE FUNCTION public.update_bogo_offer_rules_updated_at();


--
-- Name: branches trigger_update_branches_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_branches_updated_at BEFORE UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION public.update_branches_updated_at();


--
-- Name: coupon_campaigns trigger_update_coupon_campaigns_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_coupon_campaigns_updated_at BEFORE UPDATE ON public.coupon_campaigns FOR EACH ROW EXECUTE FUNCTION public.update_coupon_campaigns_updated_at();


--
-- Name: coupon_products trigger_update_coupon_products_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_coupon_products_updated_at BEFORE UPDATE ON public.coupon_products FOR EACH ROW EXECUTE FUNCTION public.update_coupon_products_updated_at();


--
-- Name: customer_recovery_requests trigger_update_customer_recovery_requests_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_customer_recovery_requests_updated_at BEFORE UPDATE ON public.customer_recovery_requests FOR EACH ROW EXECUTE FUNCTION public.update_customer_recovery_requests_updated_at();


--
-- Name: customers trigger_update_customers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.update_customers_updated_at();


--
-- Name: task_assignments trigger_update_deadline_datetime; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_deadline_datetime BEFORE INSERT OR UPDATE OF deadline_date, deadline_time ON public.task_assignments FOR EACH ROW EXECUTE FUNCTION public.update_deadline_datetime();


--
-- Name: delivery_service_settings trigger_update_delivery_settings_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_delivery_settings_timestamp BEFORE UPDATE ON public.delivery_service_settings FOR EACH ROW EXECUTE FUNCTION public.update_delivery_tiers_timestamp();


--
-- Name: delivery_fee_tiers trigger_update_delivery_tiers_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_delivery_tiers_timestamp BEFORE UPDATE ON public.delivery_fee_tiers FOR EACH ROW EXECUTE FUNCTION public.update_delivery_tiers_timestamp();


--
-- Name: flyer_templates trigger_update_flyer_templates_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_flyer_templates_updated_at BEFORE UPDATE ON public.flyer_templates FOR EACH ROW EXECUTE FUNCTION public.update_flyer_templates_updated_at();


--
-- Name: interface_permissions trigger_update_interface_permissions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_interface_permissions_updated_at BEFORE UPDATE ON public.interface_permissions FOR EACH ROW EXECUTE FUNCTION public.update_interface_permissions_updated_at();


--
-- Name: near_expiry_reports trigger_update_near_expiry_reports_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_near_expiry_reports_updated_at BEFORE UPDATE ON public.near_expiry_reports FOR EACH ROW EXECUTE FUNCTION public.update_near_expiry_reports_updated_at();


--
-- Name: offer_bundles trigger_update_offer_bundles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_offer_bundles_updated_at BEFORE UPDATE ON public.offer_bundles FOR EACH ROW EXECUTE FUNCTION public.update_offers_updated_at();


--
-- Name: offers trigger_update_offers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_offers_updated_at BEFORE UPDATE ON public.offers FOR EACH ROW EXECUTE FUNCTION public.update_offers_updated_at();


--
-- Name: pos_deduction_transfers trigger_update_pos_deduction_transfers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_pos_deduction_transfers_updated_at BEFORE UPDATE ON public.pos_deduction_transfers FOR EACH ROW EXECUTE FUNCTION public.update_pos_deduction_transfers_updated_at();


--
-- Name: quick_task_completions trigger_update_quick_task_completions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_quick_task_completions_updated_at BEFORE UPDATE ON public.quick_task_completions FOR EACH ROW EXECUTE FUNCTION public.update_quick_task_completions_updated_at();


--
-- Name: quick_task_assignments trigger_update_quick_task_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_quick_task_status AFTER UPDATE ON public.quick_task_assignments FOR EACH ROW EXECUTE FUNCTION public.update_quick_task_status();


--
-- Name: receiving_task_templates trigger_update_receiving_task_templates_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_receiving_task_templates_updated_at BEFORE UPDATE ON public.receiving_task_templates FOR EACH ROW EXECUTE FUNCTION public.update_receiving_task_templates_updated_at();


--
-- Name: receiving_tasks trigger_update_receiving_tasks_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_receiving_tasks_updated_at BEFORE UPDATE ON public.receiving_tasks FOR EACH ROW EXECUTE FUNCTION public.update_receiving_tasks_updated_at();


--
-- Name: expense_scheduler trigger_update_requisition_balance; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_requisition_balance AFTER INSERT OR DELETE OR UPDATE ON public.expense_scheduler FOR EACH ROW EXECUTE FUNCTION public.update_requisition_balance();


--
-- Name: expense_scheduler trigger_update_requisition_balance_old; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_requisition_balance_old BEFORE DELETE OR UPDATE ON public.expense_scheduler FOR EACH ROW EXECUTE FUNCTION public.update_requisition_balance_old();


--
-- Name: user_device_sessions trigger_user_device_sessions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_user_device_sessions_updated_at BEFORE UPDATE ON public.user_device_sessions FOR EACH ROW EXECUTE FUNCTION public.update_user_device_sessions_updated_at();


--
-- Name: offer_bundles trigger_validate_bundle_offer_type; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_validate_bundle_offer_type BEFORE INSERT OR UPDATE ON public.offer_bundles FOR EACH ROW EXECUTE FUNCTION public.validate_bundle_offer_type();


--
-- Name: approval_permissions update_approval_permissions_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_approval_permissions_timestamp BEFORE UPDATE ON public.approval_permissions FOR EACH ROW EXECUTE FUNCTION public.update_approval_permissions_updated_at();


--
-- Name: customer_app_media update_customer_app_media_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_customer_app_media_timestamp BEFORE UPDATE ON public.customer_app_media FOR EACH ROW EXECUTE FUNCTION public.update_customer_app_media_timestamp();


--
-- Name: erp_connections update_erp_connections_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_erp_connections_updated_at BEFORE UPDATE ON public.erp_connections FOR EACH ROW EXECUTE FUNCTION public.update_erp_connections_updated_at();


--
-- Name: erp_daily_sales update_erp_daily_sales_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_erp_daily_sales_updated_at BEFORE UPDATE ON public.erp_daily_sales FOR EACH ROW EXECUTE FUNCTION public.update_erp_daily_sales_updated_at();


--
-- Name: flyer_offers update_flyer_offers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_flyer_offers_updated_at BEFORE UPDATE ON public.flyer_offers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: offer_cart_tiers update_offer_cart_tiers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_offer_cart_tiers_updated_at BEFORE UPDATE ON public.offer_cart_tiers FOR EACH ROW EXECUTE FUNCTION public.update_offer_cart_tiers_updated_at();


--
-- Name: offer_products update_offer_products_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_offer_products_updated_at BEFORE UPDATE ON public.offer_products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: orders update_orders_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: requesters update_requesters_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_requesters_updated_at BEFORE UPDATE ON public.requesters FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: shelf_paper_templates update_shelf_paper_templates_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_shelf_paper_templates_updated_at BEFORE UPDATE ON public.shelf_paper_templates FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: user_theme_assignments user_theme_assignments_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_theme_assignments_timestamp_update BEFORE UPDATE ON public.user_theme_assignments FOR EACH ROW EXECUTE FUNCTION public.update_user_theme_assignments_timestamp();


--
-- Name: users users_audit_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER users_audit_trigger AFTER INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.log_user_action();


--
-- Name: warning_main_category warning_main_category_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER warning_main_category_timestamp_update BEFORE UPDATE ON public.warning_main_category FOR EACH ROW EXECUTE FUNCTION public.update_warning_main_category_timestamp();


--
-- Name: warning_sub_category warning_sub_category_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER warning_sub_category_timestamp_update BEFORE UPDATE ON public.warning_sub_category FOR EACH ROW EXECUTE FUNCTION public.update_warning_sub_category_timestamp();


--
-- Name: warning_violation warning_violation_timestamp_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER warning_violation_timestamp_update BEFORE UPDATE ON public.warning_violation FOR EACH ROW EXECUTE FUNCTION public.update_warning_violation_timestamp();


--
-- Name: access_code_otp access_code_otp_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_code_otp
    ADD CONSTRAINT access_code_otp_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: ai_chat_guide ai_chat_guide_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_chat_guide
    ADD CONSTRAINT ai_chat_guide_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: app_icons app_icons_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_icons
    ADD CONSTRAINT app_icons_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: approval_permissions approval_permissions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approval_permissions approval_permissions_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approval_permissions approval_permissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


