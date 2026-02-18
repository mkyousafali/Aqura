-- RPC function: get all properties with their spaces in one fast call
-- Returns a flat result set with LEFT JOIN so properties without spaces still appear
-- Client groups by property_id to build the dropdown + spaces list

CREATE OR REPLACE FUNCTION get_lease_rent_properties_with_spaces()
RETURNS TABLE (
    property_id UUID,
    property_name_en VARCHAR,
    property_name_ar VARCHAR,
    property_location_en VARCHAR,
    property_location_ar VARCHAR,
    property_is_leased BOOLEAN,
    property_is_rented BOOLEAN,
    space_id UUID,
    space_number VARCHAR
) AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to all roles
GRANT EXECUTE ON FUNCTION get_lease_rent_properties_with_spaces() TO authenticated;
GRANT EXECUTE ON FUNCTION get_lease_rent_properties_with_spaces() TO service_role;
GRANT EXECUTE ON FUNCTION get_lease_rent_properties_with_spaces() TO anon;
