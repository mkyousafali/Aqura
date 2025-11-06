-- ================================================================
-- Function: generate_unique_customer_access_code
-- Category: customer
-- Return Type: text
-- Arguments: none
-- Description: Generates a unique 6-digit access code for customers
-- ================================================================

CREATE OR REPLACE FUNCTION generate_unique_customer_access_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_access_code text;
    code_exists boolean;
    attempts integer := 0;
    max_attempts integer := 100;
BEGIN
    LOOP
        -- Generate random 6-digit code
        v_access_code := LPAD(FLOOR(random() * 1000000)::text, 6, '0');
        
        -- Check if code already exists
        SELECT EXISTS(
            SELECT 1 FROM public.customers c
            WHERE c.access_code = v_access_code
        ) INTO code_exists;
        
        -- If unique, return the code
        IF NOT code_exists THEN
            RETURN v_access_code;
        END IF;
        
        -- Increment attempts and check limit
        attempts := attempts + 1;
        IF attempts >= max_attempts THEN
            RAISE EXCEPTION 'Unable to generate unique access code after % attempts', max_attempts;
        END IF;
    END LOOP;
END;
$$;