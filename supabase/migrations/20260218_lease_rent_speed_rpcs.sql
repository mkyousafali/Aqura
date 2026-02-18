-- ============================================================
-- Lease & Rent Speed RPCs
-- Consolidate multiple client queries into single RPC calls
-- All use POST body (no URL length issues with UUID arrays)
-- ============================================================

-- 1) get_lease_rent_tab_data: Returns parties (with property/space joins) + all special changes in ONE call
--    Replaces: loadLeasePartiesForTab/loadRentPartiesForTab + loadChangesForParties
CREATE OR REPLACE FUNCTION get_lease_rent_tab_data(p_party_type TEXT)
RETURNS JSON AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_lease_rent_tab_data(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_lease_rent_tab_data(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION get_lease_rent_tab_data(TEXT) TO anon;


-- 2) get_party_payment_data: Returns special changes + payment entries for a single party in ONE call
--    Replaces: loadPaymentScheduleChanges + loadPaymentEntries (2 sequential queries)
CREATE OR REPLACE FUNCTION get_party_payment_data(p_party_type TEXT, p_party_id UUID)
RETURNS JSON AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_party_payment_data(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_party_payment_data(TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION get_party_payment_data(TEXT, UUID) TO anon;


-- 3) get_report_data: Returns entries + changes for multiple parties using UUID[] (POST body, no URL length issue)
--    Replaces: 2x .in('party_id', [...]) queries that can overflow URL length
CREATE OR REPLACE FUNCTION get_report_data(p_party_type TEXT, p_party_ids UUID[])
RETURNS JSON AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_report_data(TEXT, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_report_data(TEXT, UUID[]) TO service_role;
GRANT EXECUTE ON FUNCTION get_report_data(TEXT, UUID[]) TO anon;


-- 4) get_report_party_paid_totals: Server-side SUM instead of loading all rows to client
--    Replaces: SELECT party_id, amount FROM entries → client loops to sum
CREATE OR REPLACE FUNCTION get_report_party_paid_totals(p_party_type TEXT)
RETURNS JSON AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_report_party_paid_totals(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_report_party_paid_totals(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION get_report_party_paid_totals(TEXT) TO anon;
