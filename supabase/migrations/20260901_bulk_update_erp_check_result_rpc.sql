-- One-time backfill support: batches many erp_check_result writes into a single round trip
-- (12k+ receiving_records rows would otherwise mean 12k+ individual PATCH requests).
CREATE OR REPLACE FUNCTION public.bulk_update_erp_check_result(p_updates jsonb)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count integer := 0;
    v_item jsonb;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_updates)
    LOOP
        UPDATE receiving_records
        SET erp_check_result = v_item->'result'
        WHERE id = (v_item->>'id')::uuid;
        IF FOUND THEN
            v_count := v_count + 1;
        END IF;
    END LOOP;
    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.bulk_update_erp_check_result(jsonb) TO service_role;
