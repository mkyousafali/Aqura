-- =====================================================================
-- Expand branch sync to include ALL master/config tables (27 → 72)
-- Also updates the RPC allowlists so branches can clear & import them
-- =====================================================================

-- 1. Update clear_sync_tables allowlist
CREATE OR REPLACE FUNCTION public.clear_sync_tables(p_tables text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_table text;
    v_allowed text[] := ARRAY[
        'desktop_themes','settings','ai_chat_guide','social_links',
        'branches','users','user_sessions','user_device_sessions',
        'user_favorite_buttons','user_theme_assignments','user_voice_preferences',
        'button_main_sections','button_sub_sections','sidebar_buttons',
        'button_permissions','interface_permissions','approval_permissions',
        'nationalities','hr_departments','hr_levels','hr_positions',
        'hr_employee_master','hr_employees','hr_position_assignments',
        'hr_position_reporting_template','hr_employee_contacts','hr_employee_documents',
        'hr_basic_salary','hr_insurance_companies',
        'branch_default_positions','receiving_user_defaults',
        'regular_shift','special_shift_weekday','special_shift_date_wise',
        'day_off','day_off_weekday','day_off_reasons',
        'official_holidays','employee_official_holidays','overtime_registrations',
        'hr_checklists','hr_checklist_questions','hr_checklist_operations',
        'employee_checklist_assignments',
        'incident_types','default_incident_users',
        'warning_main_category','warning_sub_category','warning_violation',
        'product_categories','product_units','products','product_details',
        'erp_connections','erp_synced_products','erp_sync_logs',
        'offers','offer_products','offer_names','offer_bundles','offer_cart_tiers',
        'bogo_offer_rules','flyer_offers','flyer_offer_products',
        'flyer_templates','shelf_paper_templates','shelf_paper_fonts',
        'customers','privilege_cards_master','privilege_cards_branch',
        'coupon_campaigns','coupon_products','coupon_eligible_customers',
        'delivery_service_settings','delivery_fee_tiers','branch_default_delivery_receivers',
        'vendors','requesters','denomination_types','tax_categories',
        'expense_sub_categories','pos_deduction_transfers',
        'asset_main_categories','asset_sub_categories',
        'system_api_keys'];
BEGIN
    PERFORM set_config('session_replication_role','replica',true);
    FOREACH v_table IN ARRAY p_tables LOOP
        IF v_table = ANY(v_allowed) THEN EXECUTE format('DELETE FROM %I',v_table); END IF;
    END LOOP;
    PERFORM set_config('session_replication_role','origin',true);
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('session_replication_role','origin',true); RAISE;
END;$$;
GRANT EXECUTE ON FUNCTION public.clear_sync_tables(text[]) TO authenticated, anon, service_role;

-- 2. Update import_sync_batch allowlist
CREATE OR REPLACE FUNCTION public.import_sync_batch(p_table_name text, p_data jsonb)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer := 0;
    v_allowed text[] := ARRAY[
        'desktop_themes','settings','ai_chat_guide','social_links',
        'branches','users','user_sessions','user_device_sessions',
        'user_favorite_buttons','user_theme_assignments','user_voice_preferences',
        'button_main_sections','button_sub_sections','sidebar_buttons',
        'button_permissions','interface_permissions','approval_permissions',
        'nationalities','hr_departments','hr_levels','hr_positions',
        'hr_employee_master','hr_employees','hr_position_assignments',
        'hr_position_reporting_template','hr_employee_contacts','hr_employee_documents',
        'hr_basic_salary','hr_insurance_companies',
        'branch_default_positions','receiving_user_defaults',
        'regular_shift','special_shift_weekday','special_shift_date_wise',
        'day_off','day_off_weekday','day_off_reasons',
        'official_holidays','employee_official_holidays','overtime_registrations',
        'hr_checklists','hr_checklist_questions','hr_checklist_operations',
        'employee_checklist_assignments',
        'incident_types','default_incident_users',
        'warning_main_category','warning_sub_category','warning_violation',
        'product_categories','product_units','products','product_details',
        'erp_connections','erp_synced_products','erp_sync_logs',
        'offers','offer_products','offer_names','offer_bundles','offer_cart_tiers',
        'bogo_offer_rules','flyer_offers','flyer_offer_products',
        'flyer_templates','shelf_paper_templates','shelf_paper_fonts',
        'customers','privilege_cards_master','privilege_cards_branch',
        'coupon_campaigns','coupon_products','coupon_eligible_customers',
        'delivery_service_settings','delivery_fee_tiers','branch_default_delivery_receivers',
        'vendors','requesters','denomination_types','tax_categories',
        'expense_sub_categories','pos_deduction_transfers',
        'asset_main_categories','asset_sub_categories',
        'system_api_keys'];
BEGIN
    IF NOT (p_table_name = ANY(v_allowed)) THEN RAISE EXCEPTION 'Table % not allowed',p_table_name; END IF;
    IF p_data IS NULL OR jsonb_array_length(p_data) = 0 THEN RETURN 0; END IF;
    PERFORM set_config('session_replication_role','replica',true);
    EXECUTE format('INSERT INTO %I OVERRIDING SYSTEM VALUE SELECT * FROM jsonb_populate_recordset(null::%I,$1)',p_table_name,p_table_name) USING p_data;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    PERFORM set_config('session_replication_role','origin',true);
    RETURN v_count;
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('session_replication_role','origin',true); RAISE;
END;$$;
GRANT EXECUTE ON FUNCTION public.import_sync_batch(text,jsonb) TO authenticated, anon, service_role;

-- 3. Update existing branch_sync_config rows to include ALL sync tables
UPDATE branch_sync_config SET sync_tables = ARRAY[
    'desktop_themes','settings','ai_chat_guide','social_links',
    'branches','users','user_sessions','user_device_sessions',
    'user_favorite_buttons','user_theme_assignments','user_voice_preferences',
    'button_main_sections','button_sub_sections','sidebar_buttons',
    'button_permissions','interface_permissions','approval_permissions',
    'nationalities','hr_departments','hr_levels','hr_positions',
    'hr_employee_master','hr_employees','hr_position_assignments',
    'hr_position_reporting_template','hr_employee_contacts','hr_employee_documents',
    'hr_basic_salary','hr_insurance_companies',
    'branch_default_positions','receiving_user_defaults',
    'regular_shift','special_shift_weekday','special_shift_date_wise',
    'day_off','day_off_weekday','day_off_reasons',
    'official_holidays','employee_official_holidays','overtime_registrations',
    'hr_checklists','hr_checklist_questions','hr_checklist_operations',
    'employee_checklist_assignments',
    'incident_types','default_incident_users',
    'warning_main_category','warning_sub_category','warning_violation',
    'product_categories','product_units','products','product_details',
    'erp_connections','erp_synced_products','erp_sync_logs',
    'offers','offer_products','offer_names','offer_bundles','offer_cart_tiers',
    'bogo_offer_rules','flyer_offers','flyer_offer_products',
    'flyer_templates','shelf_paper_templates','shelf_paper_fonts',
    'customers','privilege_cards_master','privilege_cards_branch',
    'coupon_campaigns','coupon_products','coupon_eligible_customers',
    'delivery_service_settings','delivery_fee_tiers','branch_default_delivery_receivers',
    'vendors','requesters','denomination_types','tax_categories',
    'expense_sub_categories','pos_deduction_transfers',
    'asset_main_categories','asset_sub_categories',
    'system_api_keys'
];

-- 4. Update the DEFAULT so new branch configs get all tables
ALTER TABLE branch_sync_config ALTER COLUMN sync_tables SET DEFAULT ARRAY[
    'desktop_themes','settings','ai_chat_guide','social_links',
    'branches','users','user_sessions','user_device_sessions',
    'user_favorite_buttons','user_theme_assignments','user_voice_preferences',
    'button_main_sections','button_sub_sections','sidebar_buttons',
    'button_permissions','interface_permissions','approval_permissions',
    'nationalities','hr_departments','hr_levels','hr_positions',
    'hr_employee_master','hr_employees','hr_position_assignments',
    'hr_position_reporting_template','hr_employee_contacts','hr_employee_documents',
    'hr_basic_salary','hr_insurance_companies',
    'branch_default_positions','receiving_user_defaults',
    'regular_shift','special_shift_weekday','special_shift_date_wise',
    'day_off','day_off_weekday','day_off_reasons',
    'official_holidays','employee_official_holidays','overtime_registrations',
    'hr_checklists','hr_checklist_questions','hr_checklist_operations',
    'employee_checklist_assignments',
    'incident_types','default_incident_users',
    'warning_main_category','warning_sub_category','warning_violation',
    'product_categories','product_units','products','product_details',
    'erp_connections','erp_synced_products','erp_sync_logs',
    'offers','offer_products','offer_names','offer_bundles','offer_cart_tiers',
    'bogo_offer_rules','flyer_offers','flyer_offer_products',
    'flyer_templates','shelf_paper_templates','shelf_paper_fonts',
    'customers','privilege_cards_master','privilege_cards_branch',
    'coupon_campaigns','coupon_products','coupon_eligible_customers',
    'delivery_service_settings','delivery_fee_tiers','branch_default_delivery_receivers',
    'vendors','requesters','denomination_types','tax_categories',
    'expense_sub_categories','pos_deduction_transfers',
    'asset_main_categories','asset_sub_categories',
    'system_api_keys'
]::text[];

SELECT 'Sync tables expanded from 27 to 72 tables' as result;
