--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

--
-- Name: access_code_otp access_code_otp_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_code_otp
    ADD CONSTRAINT access_code_otp_pkey PRIMARY KEY (id);


--
-- Name: ai_chat_guide ai_chat_guide_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_chat_guide
    ADD CONSTRAINT ai_chat_guide_pkey PRIMARY KEY (id);


--
-- Name: app_icons app_icons_icon_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_icons
    ADD CONSTRAINT app_icons_icon_key_key UNIQUE (icon_key);


--
-- Name: app_icons app_icons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_icons
    ADD CONSTRAINT app_icons_pkey PRIMARY KEY (id);


--
-- Name: approval_permissions approval_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_pkey PRIMARY KEY (id);


--
-- Name: approval_permissions approval_permissions_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_permissions
    ADD CONSTRAINT approval_permissions_user_id_key UNIQUE (user_id);


--
-- Name: approver_branch_access approver_branch_access_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_pkey PRIMARY KEY (id);


--
-- Name: approver_branch_access approver_branch_access_user_id_branch_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_user_id_branch_id_key UNIQUE (user_id, branch_id);


--
-- Name: approver_visibility_config approver_visibility_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_pkey PRIMARY KEY (id);


--
-- Name: approver_visibility_config approver_visibility_config_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_user_id_key UNIQUE (user_id);


--
-- Name: asset_sub_categories asset_items_group_code_name_en_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_sub_categories
    ADD CONSTRAINT asset_items_group_code_name_en_key UNIQUE (group_code, name_en);


--
-- Name: asset_sub_categories asset_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_sub_categories
    ADD CONSTRAINT asset_items_pkey PRIMARY KEY (id);


--
-- Name: asset_main_categories asset_main_categories_group_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_main_categories
    ADD CONSTRAINT asset_main_categories_group_code_key UNIQUE (group_code);


--
-- Name: asset_main_categories asset_main_categories_name_en_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_main_categories
    ADD CONSTRAINT asset_main_categories_name_en_key UNIQUE (name_en);


--
-- Name: asset_main_categories asset_main_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_main_categories
    ADD CONSTRAINT asset_main_categories_pkey PRIMARY KEY (id);


--
-- Name: assets assets_asset_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_asset_id_key UNIQUE (asset_id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: background_templates background_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.background_templates
    ADD CONSTRAINT background_templates_pkey PRIMARY KEY (id);


--
-- Name: bank_reconciliations bank_reconciliations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_reconciliations
    ADD CONSTRAINT bank_reconciliations_pkey PRIMARY KEY (id);


--
-- Name: biometric_connections biometric_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biometric_connections
    ADD CONSTRAINT biometric_connections_pkey PRIMARY KEY (id);


--
-- Name: bogo_offer_rules bogo_offer_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bogo_offer_rules
    ADD CONSTRAINT bogo_offer_rules_pkey PRIMARY KEY (id);


--
-- Name: box_operations box_operations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.box_operations
    ADD CONSTRAINT box_operations_pkey PRIMARY KEY (id);


--
-- Name: branch_default_delivery_receivers branch_default_delivery_receivers_branch_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_delivery_receivers
    ADD CONSTRAINT branch_default_delivery_receivers_branch_id_user_id_key UNIQUE (branch_id, user_id);


--
-- Name: branch_default_delivery_receivers branch_default_delivery_receivers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_delivery_receivers
    ADD CONSTRAINT branch_default_delivery_receivers_pkey PRIMARY KEY (id);


--
-- Name: branch_default_positions branch_default_positions_branch_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_branch_id_key UNIQUE (branch_id);


--
-- Name: branch_default_positions branch_default_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_pkey PRIMARY KEY (id);


--
-- Name: branch_sync_config branch_sync_config_branch_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_sync_config
    ADD CONSTRAINT branch_sync_config_branch_id_key UNIQUE (branch_id);


--
-- Name: branch_sync_config branch_sync_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_sync_config
    ADD CONSTRAINT branch_sync_config_pkey PRIMARY KEY (id);


--
-- Name: branches branches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_pkey PRIMARY KEY (id);


--
-- Name: break_reasons break_reasons_name_en_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.break_reasons
    ADD CONSTRAINT break_reasons_name_en_unique UNIQUE (name_en);


--
-- Name: break_reasons break_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.break_reasons
    ADD CONSTRAINT break_reasons_pkey PRIMARY KEY (id);


--
-- Name: break_register break_register_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.break_register
    ADD CONSTRAINT break_register_pkey PRIMARY KEY (id);


--
-- Name: break_security_seed break_security_seed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.break_security_seed
    ADD CONSTRAINT break_security_seed_pkey PRIMARY KEY (id);


--
-- Name: button_main_sections button_main_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_main_sections
    ADD CONSTRAINT button_main_sections_pkey PRIMARY KEY (id);


--
-- Name: button_main_sections button_main_sections_section_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_main_sections
    ADD CONSTRAINT button_main_sections_section_code_key UNIQUE (section_code);


--
-- Name: button_permissions button_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_permissions
    ADD CONSTRAINT button_permissions_pkey PRIMARY KEY (id);


--
-- Name: button_permissions button_permissions_user_id_button_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_permissions
    ADD CONSTRAINT button_permissions_user_id_button_id_key UNIQUE (user_id, button_id);


--
-- Name: button_sub_sections button_sub_sections_main_section_id_subsection_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_sub_sections
    ADD CONSTRAINT button_sub_sections_main_section_id_subsection_code_key UNIQUE (main_section_id, subsection_code);


--
-- Name: button_sub_sections button_sub_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_sub_sections
    ADD CONSTRAINT button_sub_sections_pkey PRIMARY KEY (id);


--
-- Name: cashier_device_bindings cashier_device_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cashier_device_bindings
    ADD CONSTRAINT cashier_device_bindings_pkey PRIMARY KEY (user_id);


--
-- Name: coupon_campaigns coupon_campaigns_campaign_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_campaigns
    ADD CONSTRAINT coupon_campaigns_campaign_code_key UNIQUE (campaign_code);


--
-- Name: coupon_campaigns coupon_campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_campaigns
    ADD CONSTRAINT coupon_campaigns_pkey PRIMARY KEY (id);


--
-- Name: coupon_claims coupon_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_pkey PRIMARY KEY (id);


--
-- Name: coupon_eligible_customers coupon_eligible_customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_eligible_customers
    ADD CONSTRAINT coupon_eligible_customers_pkey PRIMARY KEY (id);


--
-- Name: coupon_products coupon_products_campaign_barcode_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_campaign_barcode_unique UNIQUE (campaign_id, special_barcode);


--
-- Name: coupon_products coupon_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_pkey PRIMARY KEY (id);


--
-- Name: customer_access_code_history customer_access_code_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_access_code_history
    ADD CONSTRAINT customer_access_code_history_pkey PRIMARY KEY (id);


--
-- Name: customer_app_media customer_app_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_app_media
    ADD CONSTRAINT customer_app_media_pkey PRIMARY KEY (id);


--
-- Name: customer_product_requests customer_product_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_product_requests
    ADD CONSTRAINT customer_product_requests_pkey PRIMARY KEY (id);


--
-- Name: customer_recovery_requests customer_recovery_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_recovery_requests
    ADD CONSTRAINT customer_recovery_requests_pkey PRIMARY KEY (id);


--
-- Name: customers customers_access_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_access_code_key UNIQUE (access_code);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: customers customers_whatsapp_number_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_whatsapp_number_unique UNIQUE (whatsapp_number);


--
-- Name: day_off day_off_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_pkey PRIMARY KEY (id);


--
-- Name: day_off_reasons day_off_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off_reasons
    ADD CONSTRAINT day_off_reasons_pkey PRIMARY KEY (id);


--
-- Name: day_off_reasons day_off_reasons_reason_en_reason_ar_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off_reasons
    ADD CONSTRAINT day_off_reasons_reason_en_reason_ar_key UNIQUE (reason_en, reason_ar);


--
-- Name: day_off_weekday day_off_weekday_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off_weekday
    ADD CONSTRAINT day_off_weekday_pkey PRIMARY KEY (id);


--
-- Name: default_incident_users default_incident_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_incident_users
    ADD CONSTRAINT default_incident_users_pkey PRIMARY KEY (id);


--
-- Name: default_incident_users default_incident_users_user_id_incident_type_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_incident_users
    ADD CONSTRAINT default_incident_users_user_id_incident_type_id_key UNIQUE (user_id, incident_type_id);


--
-- Name: deleted_bundle_offers deleted_bundle_offers_original_offer_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_bundle_offers
    ADD CONSTRAINT deleted_bundle_offers_original_offer_id_key UNIQUE (original_offer_id);


--
-- Name: deleted_bundle_offers deleted_bundle_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_bundle_offers
    ADD CONSTRAINT deleted_bundle_offers_pkey PRIMARY KEY (id);


--
-- Name: delivery_fee_tiers delivery_fee_tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_fee_tiers
    ADD CONSTRAINT delivery_fee_tiers_pkey PRIMARY KEY (id);


--
-- Name: delivery_service_settings delivery_service_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_service_settings
    ADD CONSTRAINT delivery_service_settings_pkey PRIMARY KEY (id);


--
-- Name: denomination_audit_log denomination_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_audit_log
    ADD CONSTRAINT denomination_audit_log_pkey PRIMARY KEY (id);


--
-- Name: denomination_records denomination_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_records
    ADD CONSTRAINT denomination_records_pkey PRIMARY KEY (id);


--
-- Name: denomination_transactions denomination_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_transactions
    ADD CONSTRAINT denomination_transactions_pkey PRIMARY KEY (id);


--
-- Name: denomination_types denomination_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_types
    ADD CONSTRAINT denomination_types_code_key UNIQUE (code);


--
-- Name: denomination_types denomination_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_types
    ADD CONSTRAINT denomination_types_pkey PRIMARY KEY (id);


--
-- Name: denomination_user_preferences denomination_user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_user_preferences
    ADD CONSTRAINT denomination_user_preferences_pkey PRIMARY KEY (id);


--
-- Name: denomination_user_preferences denomination_user_preferences_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_user_preferences
    ADD CONSTRAINT denomination_user_preferences_user_id_key UNIQUE (user_id);


--
-- Name: desktop_themes desktop_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.desktop_themes
    ADD CONSTRAINT desktop_themes_pkey PRIMARY KEY (id);


--
-- Name: edge_functions_cache edge_functions_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edge_functions_cache
    ADD CONSTRAINT edge_functions_cache_pkey PRIMARY KEY (func_name);


--
-- Name: employee_checklist_assignments employee_checklist_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_checklist_assignments
    ADD CONSTRAINT employee_checklist_assignments_pkey PRIMARY KEY (id);


--
-- Name: employee_fine_payments employee_fine_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_fine_payments
    ADD CONSTRAINT employee_fine_payments_pkey PRIMARY KEY (id);


--
-- Name: employee_official_holidays employee_official_holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_official_holidays
    ADD CONSTRAINT employee_official_holidays_pkey PRIMARY KEY (id);


--
-- Name: erp_connections erp_connections_branch_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_connections
    ADD CONSTRAINT erp_connections_branch_id_key UNIQUE (branch_id);


--
-- Name: erp_connections erp_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_connections
    ADD CONSTRAINT erp_connections_pkey PRIMARY KEY (id);


--
-- Name: erp_daily_sales erp_daily_sales_branch_id_sale_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_daily_sales
    ADD CONSTRAINT erp_daily_sales_branch_id_sale_date_key UNIQUE (branch_id, sale_date);


--
-- Name: erp_daily_sales erp_daily_sales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_daily_sales
    ADD CONSTRAINT erp_daily_sales_pkey PRIMARY KEY (id);


--
-- Name: erp_sync_logs erp_sync_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_sync_logs
    ADD CONSTRAINT erp_sync_logs_pkey PRIMARY KEY (id);


--
-- Name: erp_synced_products erp_synced_products_barcode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_synced_products
    ADD CONSTRAINT erp_synced_products_barcode_key UNIQUE (barcode);


--
-- Name: erp_synced_products erp_synced_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_synced_products
    ADD CONSTRAINT erp_synced_products_pkey PRIMARY KEY (id);


--
-- Name: expense_parent_categories expense_parent_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_parent_categories
    ADD CONSTRAINT expense_parent_categories_pkey PRIMARY KEY (id);


--
-- Name: expense_requisitions expense_requisitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_pkey PRIMARY KEY (id);


--
-- Name: expense_requisitions expense_requisitions_requisition_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_requisition_number_key UNIQUE (requisition_number);


--
-- Name: expense_scheduler expense_scheduler_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT expense_scheduler_pkey PRIMARY KEY (id);


--
-- Name: expense_sub_categories expense_sub_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_sub_categories
    ADD CONSTRAINT expense_sub_categories_pkey PRIMARY KEY (id);


--
-- Name: flyer_offer_products flyer_offer_products_offer_id_product_barcode_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_offer_products
    ADD CONSTRAINT flyer_offer_products_offer_id_product_barcode_key UNIQUE (offer_id, product_barcode);


--
-- Name: flyer_offer_products flyer_offer_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_offer_products
    ADD CONSTRAINT flyer_offer_products_pkey PRIMARY KEY (id);


--
-- Name: flyer_offers flyer_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_offers
    ADD CONSTRAINT flyer_offers_pkey PRIMARY KEY (id);


--
-- Name: flyer_offers flyer_offers_template_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_offers
    ADD CONSTRAINT flyer_offers_template_id_key UNIQUE (template_id);


--
-- Name: products flyer_products_pkey1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_pkey1 PRIMARY KEY (id);


--
-- Name: flyer_templates flyer_templates_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_templates
    ADD CONSTRAINT flyer_templates_name_unique UNIQUE (name);


--
-- Name: flyer_templates flyer_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_templates
    ADD CONSTRAINT flyer_templates_pkey PRIMARY KEY (id);


--
-- Name: frontend_builds frontend_builds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frontend_builds
    ADD CONSTRAINT frontend_builds_pkey PRIMARY KEY (id);


--
-- Name: gift_wheel_coupons gift_wheel_coupons_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_wheel_coupons
    ADD CONSTRAINT gift_wheel_coupons_code_key UNIQUE (code);


--
-- Name: gift_wheel_coupons gift_wheel_coupons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_wheel_coupons
    ADD CONSTRAINT gift_wheel_coupons_pkey PRIMARY KEY (id);


--
-- Name: gift_wheel_rewards gift_wheel_rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_wheel_rewards
    ADD CONSTRAINT gift_wheel_rewards_pkey PRIMARY KEY (id);


--
-- Name: gift_wheel_settings gift_wheel_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_wheel_settings
    ADD CONSTRAINT gift_wheel_settings_pkey PRIMARY KEY (id);


--
-- Name: gift_wheel_spins gift_wheel_spins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_wheel_spins
    ADD CONSTRAINT gift_wheel_spins_pkey PRIMARY KEY (id);


--
-- Name: helper_apps helper_apps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.helper_apps
    ADD CONSTRAINT helper_apps_pkey PRIMARY KEY (id);


--
-- Name: hr_analysed_attendance_data hr_analysed_attendance_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_analysed_attendance_data
    ADD CONSTRAINT hr_analysed_attendance_data_pkey PRIMARY KEY (id);


--
-- Name: hr_basic_salary hr_basic_salary_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_basic_salary
    ADD CONSTRAINT hr_basic_salary_pkey PRIMARY KEY (employee_id);


--
-- Name: hr_checklist_operations hr_checklist_operations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_checklist_operations
    ADD CONSTRAINT hr_checklist_operations_pkey PRIMARY KEY (id);


--
-- Name: hr_checklist_questions hr_checklist_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_checklist_questions
    ADD CONSTRAINT hr_checklist_questions_pkey PRIMARY KEY (id);


--
-- Name: hr_checklists hr_checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_checklists
    ADD CONSTRAINT hr_checklists_pkey PRIMARY KEY (id);


--
-- Name: hr_departments hr_departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_departments
    ADD CONSTRAINT hr_departments_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_applicability_rule_periods hr_employee_applicability_rule_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_applicability_rule_periods
    ADD CONSTRAINT hr_employee_applicability_rule_periods_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_applicability_rule_periods hr_employee_applicability_rule_periods_unique_seq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_applicability_rule_periods
    ADD CONSTRAINT hr_employee_applicability_rule_periods_unique_seq UNIQUE (employee_id, rule_type, sequence_no);


--
-- Name: hr_employee_esob_records hr_employee_esob_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_esob_records
    ADD CONSTRAINT hr_employee_esob_records_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_leave_approvals hr_employee_leave_approvals_employee_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_leave_approvals
    ADD CONSTRAINT hr_employee_leave_approvals_employee_date_key UNIQUE (employee_id, leave_date);


--
-- Name: hr_employee_leave_approvals hr_employee_leave_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_leave_approvals
    ADD CONSTRAINT hr_employee_leave_approvals_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_master hr_employee_master_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_master
    ADD CONSTRAINT hr_employee_master_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_master hr_employee_master_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_master
    ADD CONSTRAINT hr_employee_master_user_id_key UNIQUE (user_id);


--
-- Name: hr_employee_settlement_applicability hr_employee_settlement_applicability_employee_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_settlement_applicability
    ADD CONSTRAINT hr_employee_settlement_applicability_employee_id_key UNIQUE (employee_id);


--
-- Name: hr_employee_settlement_applicability hr_employee_settlement_applicability_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_settlement_applicability
    ADD CONSTRAINT hr_employee_settlement_applicability_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_ticket_issuances hr_employee_ticket_issuances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_ticket_issuances
    ADD CONSTRAINT hr_employee_ticket_issuances_pkey PRIMARY KEY (id);


--
-- Name: hr_employees hr_employees_employee_id_branch_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employees
    ADD CONSTRAINT hr_employees_employee_id_branch_id_unique UNIQUE (employee_id, branch_id);


--
-- Name: hr_employees hr_employees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employees
    ADD CONSTRAINT hr_employees_pkey PRIMARY KEY (id);


--
-- Name: hr_esob_base_rules hr_esob_base_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_esob_base_rules
    ADD CONSTRAINT hr_esob_base_rules_pkey PRIMARY KEY (id);


--
-- Name: hr_esob_resignation_factors hr_esob_resignation_factors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_esob_resignation_factors
    ADD CONSTRAINT hr_esob_resignation_factors_pkey PRIMARY KEY (id);


--
-- Name: hr_fingerprint_transactions hr_fingerprint_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_fingerprint_transactions
    ADD CONSTRAINT hr_fingerprint_transactions_pkey PRIMARY KEY (id);


--
-- Name: hr_insurance_companies hr_insurance_companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_insurance_companies
    ADD CONSTRAINT hr_insurance_companies_pkey PRIMARY KEY (id);


--
-- Name: hr_levels hr_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_levels
    ADD CONSTRAINT hr_levels_pkey PRIMARY KEY (id);


--
-- Name: hr_position_assignments hr_position_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_pkey PRIMARY KEY (id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_pkey PRIMARY KEY (id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_subordinate_position_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_subordinate_position_id_key UNIQUE (subordinate_position_id);


--
-- Name: hr_positions hr_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_positions
    ADD CONSTRAINT hr_positions_pkey PRIMARY KEY (id);


--
-- Name: hr_salary_notes hr_salary_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_salary_notes
    ADD CONSTRAINT hr_salary_notes_pkey PRIMARY KEY (id);


--
-- Name: hr_salary_statements hr_salary_statements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_salary_statements
    ADD CONSTRAINT hr_salary_statements_pkey PRIMARY KEY (id);


--
-- Name: incident_actions incident_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident_actions
    ADD CONSTRAINT incident_actions_pkey PRIMARY KEY (id);


--
-- Name: incident_types incident_types_incident_type_ar_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident_types
    ADD CONSTRAINT incident_types_incident_type_ar_key UNIQUE (incident_type_ar);


--
-- Name: incident_types incident_types_incident_type_en_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident_types
    ADD CONSTRAINT incident_types_incident_type_en_key UNIQUE (incident_type_en);


--
-- Name: incident_types incident_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident_types
    ADD CONSTRAINT incident_types_pkey PRIMARY KEY (id);


--
-- Name: incidents incidents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_pkey PRIMARY KEY (id);


--
-- Name: interface_permissions interface_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interface_permissions
    ADD CONSTRAINT interface_permissions_pkey PRIMARY KEY (id);


--
-- Name: interface_permissions interface_permissions_user_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interface_permissions
    ADD CONSTRAINT interface_permissions_user_unique UNIQUE (user_id);


--
-- Name: lease_rent_lease_parties lease_rent_lease_parties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_lease_parties
    ADD CONSTRAINT lease_rent_lease_parties_pkey PRIMARY KEY (id);


--
-- Name: lease_rent_payment_entries lease_rent_payment_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_payment_entries
    ADD CONSTRAINT lease_rent_payment_entries_pkey PRIMARY KEY (id);


--
-- Name: lease_rent_payments lease_rent_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_payments
    ADD CONSTRAINT lease_rent_payments_pkey PRIMARY KEY (id);


--
-- Name: lease_rent_payments lease_rent_payments_unique_period; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_payments
    ADD CONSTRAINT lease_rent_payments_unique_period UNIQUE (party_type, party_id, period_num);


--
-- Name: lease_rent_properties lease_rent_property_spaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_properties
    ADD CONSTRAINT lease_rent_property_spaces_pkey PRIMARY KEY (id);


--
-- Name: lease_rent_property_spaces lease_rent_property_spaces_pkey1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_property_spaces
    ADD CONSTRAINT lease_rent_property_spaces_pkey1 PRIMARY KEY (id);


--
-- Name: lease_rent_rent_parties lease_rent_rent_parties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_rent_parties
    ADD CONSTRAINT lease_rent_rent_parties_pkey PRIMARY KEY (id);


--
-- Name: lease_rent_special_changes lease_rent_special_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_special_changes
    ADD CONSTRAINT lease_rent_special_changes_pkey PRIMARY KEY (id);


--
-- Name: loyalty_customer_bills loyalty_customer_bills_bill_number_branch_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_customer_bills
    ADD CONSTRAINT loyalty_customer_bills_bill_number_branch_unique UNIQUE (bill_number, erp_branch_id);


--
-- Name: loyalty_customer_bills loyalty_customer_bills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_customer_bills
    ADD CONSTRAINT loyalty_customer_bills_pkey PRIMARY KEY (id);


--
-- Name: loyalty_redemptions loyalty_redemptions_coupon_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_redemptions
    ADD CONSTRAINT loyalty_redemptions_coupon_code_key UNIQUE (coupon_code);


--
-- Name: loyalty_redemptions loyalty_redemptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_redemptions
    ADD CONSTRAINT loyalty_redemptions_pkey PRIMARY KEY (id);


--
-- Name: loyalty_tiers loyalty_tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_tiers
    ADD CONSTRAINT loyalty_tiers_pkey PRIMARY KEY (id);


--
-- Name: mobile_themes mobile_themes_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_themes
    ADD CONSTRAINT mobile_themes_name_key UNIQUE (name);


--
-- Name: mobile_themes mobile_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_themes
    ADD CONSTRAINT mobile_themes_pkey PRIMARY KEY (id);


--
-- Name: multi_shift_date_wise multi_shift_date_wise_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multi_shift_date_wise
    ADD CONSTRAINT multi_shift_date_wise_pkey PRIMARY KEY (id);


--
-- Name: multi_shift_regular multi_shift_regular_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multi_shift_regular
    ADD CONSTRAINT multi_shift_regular_pkey PRIMARY KEY (id);


--
-- Name: multi_shift_weekday multi_shift_weekday_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multi_shift_weekday
    ADD CONSTRAINT multi_shift_weekday_pkey PRIMARY KEY (id);


--
-- Name: nationalities nationalities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nationalities
    ADD CONSTRAINT nationalities_pkey PRIMARY KEY (id);


--
-- Name: near_expiry_reports near_expiry_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.near_expiry_reports
    ADD CONSTRAINT near_expiry_reports_pkey PRIMARY KEY (id);


--
-- Name: non_approved_payment_scheduler non_approved_payment_scheduler_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT non_approved_payment_scheduler_pkey PRIMARY KEY (id);


--
-- Name: notification_attachments notification_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_attachments
    ADD CONSTRAINT notification_attachments_pkey PRIMARY KEY (id);


--
-- Name: notification_read_states notification_read_states_notification_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_read_states
    ADD CONSTRAINT notification_read_states_notification_id_user_id_key UNIQUE (notification_id, user_id);


--
-- Name: notification_read_states notification_read_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_read_states
    ADD CONSTRAINT notification_read_states_pkey PRIMARY KEY (id);


--
-- Name: notification_recipients notification_recipients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_recipients
    ADD CONSTRAINT notification_recipients_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: offer_bundles offer_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_bundles
    ADD CONSTRAINT offer_bundles_pkey PRIMARY KEY (id);


--
-- Name: offer_cart_tiers offer_cart_tiers_offer_id_min_amount_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_cart_tiers
    ADD CONSTRAINT offer_cart_tiers_offer_id_min_amount_key UNIQUE (offer_id, min_amount);


--
-- Name: offer_cart_tiers offer_cart_tiers_offer_id_tier_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_cart_tiers
    ADD CONSTRAINT offer_cart_tiers_offer_id_tier_number_key UNIQUE (offer_id, tier_number);


--
-- Name: offer_cart_tiers offer_cart_tiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_cart_tiers
    ADD CONSTRAINT offer_cart_tiers_pkey PRIMARY KEY (id);


--
-- Name: offer_names offer_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_names
    ADD CONSTRAINT offer_names_pkey PRIMARY KEY (id);


--
-- Name: offer_products offer_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT offer_products_pkey PRIMARY KEY (id);


--
-- Name: offer_usage_logs offer_usage_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_usage_logs
    ADD CONSTRAINT offer_usage_logs_pkey PRIMARY KEY (id);


--
-- Name: offers offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_pkey PRIMARY KEY (id);


--
-- Name: official_holidays official_holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.official_holidays
    ADD CONSTRAINT official_holidays_pkey PRIMARY KEY (id);


--
-- Name: order_audit_logs order_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_audit_logs
    ADD CONSTRAINT order_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_order_number_key UNIQUE (order_number);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: overtime_registrations overtime_registrations_employee_id_overtime_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.overtime_registrations
    ADD CONSTRAINT overtime_registrations_employee_id_overtime_date_key UNIQUE (employee_id, overtime_date);


--
-- Name: overtime_registrations overtime_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.overtime_registrations
    ADD CONSTRAINT overtime_registrations_pkey PRIMARY KEY (id);


--
-- Name: pos_deduction_transfers pos_deduction_transfers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_pkey PRIMARY KEY (id, box_number, date_closed_box);


--
-- Name: privilege_cards_branch privilege_cards_branch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privilege_cards_branch
    ADD CONSTRAINT privilege_cards_branch_pkey PRIMARY KEY (id);


--
-- Name: privilege_cards_branch privilege_cards_branch_privilege_card_id_branch_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privilege_cards_branch
    ADD CONSTRAINT privilege_cards_branch_privilege_card_id_branch_id_key UNIQUE (privilege_card_id, branch_id);


--
-- Name: privilege_cards_master privilege_cards_master_card_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privilege_cards_master
    ADD CONSTRAINT privilege_cards_master_card_number_key UNIQUE (card_number);


--
-- Name: privilege_cards_master privilege_cards_master_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privilege_cards_master
    ADD CONSTRAINT privilege_cards_master_pkey PRIMARY KEY (id);


--
-- Name: processed_fingerprint_transactions processed_fingerprint_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.processed_fingerprint_transactions
    ADD CONSTRAINT processed_fingerprint_transactions_pkey PRIMARY KEY (id);


--
-- Name: product_categories product_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);


--
-- Name: product_request_bt product_request_bt_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_pkey PRIMARY KEY (id);


--
-- Name: product_request_po product_request_po_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_po
    ADD CONSTRAINT product_request_po_pkey PRIMARY KEY (id);


--
-- Name: product_request_st product_request_st_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_st
    ADD CONSTRAINT product_request_st_pkey PRIMARY KEY (id);


--
-- Name: product_units product_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_units
    ADD CONSTRAINT product_units_pkey PRIMARY KEY (id);


--
-- Name: purchase_voucher_issue_types purchase_voucher_issue_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_issue_types
    ADD CONSTRAINT purchase_voucher_issue_types_pkey PRIMARY KEY (id);


--
-- Name: purchase_voucher_issue_types purchase_voucher_issue_types_type_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_issue_types
    ADD CONSTRAINT purchase_voucher_issue_types_type_name_key UNIQUE (type_name);


--
-- Name: purchase_voucher_items purchase_voucher_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_pkey PRIMARY KEY (id);


--
-- Name: purchase_voucher_items purchase_voucher_items_purchase_voucher_id_serial_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_purchase_voucher_id_serial_number_key UNIQUE (purchase_voucher_id, serial_number);


--
-- Name: purchase_vouchers purchase_vouchers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_vouchers
    ADD CONSTRAINT purchase_vouchers_pkey PRIMARY KEY (id);


--
-- Name: push_subscriptions push_subscriptions_endpoint_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: quick_task_assignments quick_task_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_assignments
    ADD CONSTRAINT quick_task_assignments_pkey PRIMARY KEY (id);


--
-- Name: quick_task_assignments quick_task_assignments_quick_task_id_assigned_to_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_assignments
    ADD CONSTRAINT quick_task_assignments_quick_task_id_assigned_to_user_id_key UNIQUE (quick_task_id, assigned_to_user_id);


--
-- Name: quick_task_comments quick_task_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_comments
    ADD CONSTRAINT quick_task_comments_pkey PRIMARY KEY (id);


--
-- Name: quick_task_completions quick_task_completions_assignment_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_assignment_unique UNIQUE (assignment_id);


--
-- Name: quick_task_completions quick_task_completions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_pkey PRIMARY KEY (id);


--
-- Name: quick_task_files quick_task_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_files
    ADD CONSTRAINT quick_task_files_pkey PRIMARY KEY (id);


--
-- Name: quick_task_user_preferences quick_task_user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_user_preferences
    ADD CONSTRAINT quick_task_user_preferences_pkey PRIMARY KEY (id);


--
-- Name: quick_task_user_preferences quick_task_user_preferences_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_user_preferences
    ADD CONSTRAINT quick_task_user_preferences_user_id_key UNIQUE (user_id);


--
-- Name: quick_tasks quick_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_pkey PRIMARY KEY (id);


--
-- Name: receiving_records receiving_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_records
    ADD CONSTRAINT receiving_records_pkey PRIMARY KEY (id);


--
-- Name: receiving_task_templates receiving_task_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_task_templates
    ADD CONSTRAINT receiving_task_templates_pkey PRIMARY KEY (id);


--
-- Name: receiving_task_templates receiving_task_templates_role_type_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_task_templates
    ADD CONSTRAINT receiving_task_templates_role_type_unique UNIQUE (role_type);


--
-- Name: receiving_tasks receiving_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_tasks
    ADD CONSTRAINT receiving_tasks_pkey PRIMARY KEY (id);


--
-- Name: receiving_user_defaults receiving_user_defaults_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_user_defaults
    ADD CONSTRAINT receiving_user_defaults_pkey PRIMARY KEY (id);


--
-- Name: receiving_user_defaults receiving_user_defaults_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_user_defaults
    ADD CONSTRAINT receiving_user_defaults_user_id_key UNIQUE (user_id);


--
-- Name: recurring_assignment_schedules recurring_assignment_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_assignment_schedules
    ADD CONSTRAINT recurring_assignment_schedules_pkey PRIMARY KEY (id);


--
-- Name: recurring_schedule_check_log recurring_schedule_check_log_check_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_schedule_check_log
    ADD CONSTRAINT recurring_schedule_check_log_check_date_key UNIQUE (check_date);


--
-- Name: recurring_schedule_check_log recurring_schedule_check_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_schedule_check_log
    ADD CONSTRAINT recurring_schedule_check_log_pkey PRIMARY KEY (id);


--
-- Name: regular_shift regular_shift_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regular_shift
    ADD CONSTRAINT regular_shift_pkey PRIMARY KEY (id);


--
-- Name: requesters requesters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requesters
    ADD CONSTRAINT requesters_pkey PRIMARY KEY (id);


--
-- Name: requesters requesters_requester_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requesters
    ADD CONSTRAINT requesters_requester_id_key UNIQUE (requester_id);


--
-- Name: security_code_scroll_texts security_code_scroll_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_code_scroll_texts
    ADD CONSTRAINT security_code_scroll_texts_pkey PRIMARY KEY (id);


--
-- Name: settlement_rules settlement_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_rules
    ADD CONSTRAINT settlement_rules_pkey PRIMARY KEY (id);


--
-- Name: shelf_paper_fonts shelf_paper_fonts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shelf_paper_fonts
    ADD CONSTRAINT shelf_paper_fonts_pkey PRIMARY KEY (id);


--
-- Name: shelf_paper_templates shelf_paper_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shelf_paper_templates
    ADD CONSTRAINT shelf_paper_templates_pkey PRIMARY KEY (id);


--
-- Name: sidebar_buttons sidebar_buttons_main_section_id_subsection_id_button_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_buttons
    ADD CONSTRAINT sidebar_buttons_main_section_id_subsection_id_button_code_key UNIQUE (main_section_id, subsection_id, button_code);


--
-- Name: sidebar_buttons sidebar_buttons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_buttons
    ADD CONSTRAINT sidebar_buttons_pkey PRIMARY KEY (id);


--
-- Name: social_links social_links_branch_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_links
    ADD CONSTRAINT social_links_branch_id_key UNIQUE (branch_id);


--
-- Name: social_links social_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_links
    ADD CONSTRAINT social_links_pkey PRIMARY KEY (id);


--
-- Name: special_shift_date_wise special_shift_date_wise_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_shift_date_wise
    ADD CONSTRAINT special_shift_date_wise_pkey PRIMARY KEY (id);


--
-- Name: special_shift_weekday special_shift_weekday_employee_id_weekday_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_shift_weekday
    ADD CONSTRAINT special_shift_weekday_employee_id_weekday_key UNIQUE (employee_id, weekday);


--
-- Name: special_shift_weekday special_shift_weekday_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_shift_weekday
    ADD CONSTRAINT special_shift_weekday_pkey PRIMARY KEY (id);


--
-- Name: surprise_box_plays surprise_box_plays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprise_box_plays
    ADD CONSTRAINT surprise_box_plays_pkey PRIMARY KEY (id);


--
-- Name: surprise_box_rewards surprise_box_rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprise_box_rewards
    ADD CONSTRAINT surprise_box_rewards_pkey PRIMARY KEY (id);


--
-- Name: surprise_box_settings surprise_box_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprise_box_settings
    ADD CONSTRAINT surprise_box_settings_pkey PRIMARY KEY (id);


--
-- Name: surprise_box_vouchers surprise_box_vouchers_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprise_box_vouchers
    ADD CONSTRAINT surprise_box_vouchers_code_key UNIQUE (code);


--
-- Name: surprise_box_vouchers surprise_box_vouchers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprise_box_vouchers
    ADD CONSTRAINT surprise_box_vouchers_pkey PRIMARY KEY (id);


--
-- Name: system_api_keys system_api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_api_keys
    ADD CONSTRAINT system_api_keys_pkey PRIMARY KEY (id);


--
-- Name: system_api_keys system_api_keys_service_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_api_keys
    ADD CONSTRAINT system_api_keys_service_name_key UNIQUE (service_name);


--
-- Name: task_assignments task_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_pkey PRIMARY KEY (id);


--
-- Name: task_assignments task_assignments_task_id_assignment_type_assigned_to_user_i_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_task_id_assignment_type_assigned_to_user_i_key UNIQUE (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id);


--
-- Name: task_completions task_completions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_completions
    ADD CONSTRAINT task_completions_pkey PRIMARY KEY (id);


--
-- Name: task_images task_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_images
    ADD CONSTRAINT task_images_pkey PRIMARY KEY (id);


--
-- Name: task_reminder_logs task_reminder_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: biometric_connections unique_branch_device; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biometric_connections
    ADD CONSTRAINT unique_branch_device UNIQUE (branch_id, device_id);


--
-- Name: coupon_eligible_customers unique_customer_campaign; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_eligible_customers
    ADD CONSTRAINT unique_customer_campaign UNIQUE (campaign_id, mobile_number);


--
-- Name: special_shift_date_wise unique_employee_date; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_shift_date_wise
    ADD CONSTRAINT unique_employee_date UNIQUE (employee_id, shift_date);


--
-- Name: day_off unique_employee_day_off; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT unique_employee_day_off UNIQUE (employee_id, day_off_date);


--
-- Name: employee_official_holidays unique_employee_official_holiday; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_official_holidays
    ADD CONSTRAINT unique_employee_official_holiday UNIQUE (employee_id, official_holiday_id);


--
-- Name: hr_analysed_attendance_data unique_employee_shift_date; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_analysed_attendance_data
    ADD CONSTRAINT unique_employee_shift_date UNIQUE (employee_id, shift_date);


--
-- Name: day_off_weekday unique_employee_weekday_dayoff; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off_weekday
    ADD CONSTRAINT unique_employee_weekday_dayoff UNIQUE (employee_id, weekday);


--
-- Name: hr_fingerprint_transactions unique_fingerprint_transaction; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_fingerprint_transactions
    ADD CONSTRAINT unique_fingerprint_transaction UNIQUE (employee_id, date, "time", status, branch_id);


--
-- Name: notification_recipients unique_notification_recipient; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_recipients
    ADD CONSTRAINT unique_notification_recipient UNIQUE (notification_id, user_id);


--
-- Name: offer_products unique_offer_product; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT unique_offer_product UNIQUE (offer_id, product_id);


--
-- Name: official_holidays unique_official_holiday_date; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.official_holidays
    ADD CONSTRAINT unique_official_holiday_date UNIQUE (holiday_date);


--
-- Name: lease_rent_property_spaces unique_property_space_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_property_spaces
    ADD CONSTRAINT unique_property_space_number UNIQUE (property_id, space_number);


--
-- Name: customer_app_media unique_slot_per_type; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_app_media
    ADD CONSTRAINT unique_slot_per_type UNIQUE (media_type, slot_number);


--
-- Name: user_favorite_buttons unique_user_favorite; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorite_buttons
    ADD CONSTRAINT unique_user_favorite UNIQUE (user_id);


--
-- Name: user_erp_credentials uq_user_erp_credentials_user_branch; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_erp_credentials
    ADD CONSTRAINT uq_user_erp_credentials_user_branch UNIQUE (user_id, branch_id);


--
-- Name: user_audit_logs user_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_audit_logs
    ADD CONSTRAINT user_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: user_device_sessions user_device_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_device_sessions
    ADD CONSTRAINT user_device_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_device_sessions user_device_sessions_user_id_device_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_device_sessions
    ADD CONSTRAINT user_device_sessions_user_id_device_id_key UNIQUE (user_id, device_id);


--
-- Name: user_erp_credentials user_erp_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_erp_credentials
    ADD CONSTRAINT user_erp_credentials_pkey PRIMARY KEY (id);


--
-- Name: user_favorite_buttons user_favorite_buttons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorite_buttons
    ADD CONSTRAINT user_favorite_buttons_pkey PRIMARY KEY (id);


--
-- Name: user_mobile_theme_assignments user_mobile_theme_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_mobile_theme_assignments
    ADD CONSTRAINT user_mobile_theme_assignments_pkey PRIMARY KEY (id);


--
-- Name: user_mobile_theme_assignments user_mobile_theme_assignments_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_mobile_theme_assignments
    ADD CONSTRAINT user_mobile_theme_assignments_user_id_key UNIQUE (user_id);


--
-- Name: user_password_history user_password_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_password_history
    ADD CONSTRAINT user_password_history_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_session_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_session_token_key UNIQUE (session_token);


--
-- Name: user_theme_assignments user_theme_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_pkey PRIMARY KEY (id);


--
-- Name: user_theme_assignments user_theme_assignments_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_user_id_key UNIQUE (user_id);


--
-- Name: user_voice_preferences user_voice_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_voice_preferences
    ADD CONSTRAINT user_voice_preferences_pkey PRIMARY KEY (id);


--
-- Name: user_voice_preferences user_voice_preferences_user_id_locale_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_voice_preferences
    ADD CONSTRAINT user_voice_preferences_user_id_locale_key UNIQUE (user_id, locale);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_quick_access_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_quick_access_code_key UNIQUE (quick_access_code);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: variation_audit_log variation_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variation_audit_log
    ADD CONSTRAINT variation_audit_log_pkey PRIMARY KEY (id);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_pkey PRIMARY KEY (id);


--
-- Name: vendors vendors_erp_vendor_branch_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_erp_vendor_branch_unique UNIQUE (erp_vendor_id, branch_id);


--
-- Name: CONSTRAINT vendors_erp_vendor_branch_unique ON vendors; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT vendors_erp_vendor_branch_unique ON public.vendors IS 'Ensures ERP vendor ID is unique within each branch, allowing same vendor ID across different branches';


--
-- Name: vendors vendors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_pkey PRIMARY KEY (erp_vendor_id, branch_id);


--
-- Name: view_offer view_offer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_offer
    ADD CONSTRAINT view_offer_pkey PRIMARY KEY (id);


--
-- Name: vip_campaign_settings vip_campaign_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vip_campaign_settings
    ADD CONSTRAINT vip_campaign_settings_pkey PRIMARY KEY (id);


--
-- Name: vip_redemptions vip_redemptions_number_date_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vip_redemptions
    ADD CONSTRAINT vip_redemptions_number_date_unique UNIQUE (whatsapp_number, redeemed_date);


--
-- Name: vip_redemptions vip_redemptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vip_redemptions
    ADD CONSTRAINT vip_redemptions_pkey PRIMARY KEY (id);


--
-- Name: wa_accounts wa_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_accounts
    ADD CONSTRAINT wa_accounts_pkey PRIMARY KEY (id);


--
-- Name: wa_ai_bot_config wa_ai_bot_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_ai_bot_config
    ADD CONSTRAINT wa_ai_bot_config_pkey PRIMARY KEY (id);


--
-- Name: wa_auto_reply_triggers wa_auto_reply_triggers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_auto_reply_triggers
    ADD CONSTRAINT wa_auto_reply_triggers_pkey PRIMARY KEY (id);


--
-- Name: wa_bot_flows wa_bot_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_bot_flows
    ADD CONSTRAINT wa_bot_flows_pkey PRIMARY KEY (id);


--
-- Name: wa_broadcast_recipients wa_broadcast_recipients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_broadcast_recipients
    ADD CONSTRAINT wa_broadcast_recipients_pkey PRIMARY KEY (id);


--
-- Name: wa_broadcasts wa_broadcasts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_broadcasts
    ADD CONSTRAINT wa_broadcasts_pkey PRIMARY KEY (id);


--
-- Name: wa_catalog_orders wa_catalog_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_catalog_orders
    ADD CONSTRAINT wa_catalog_orders_pkey PRIMARY KEY (id);


--
-- Name: wa_catalog_products wa_catalog_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_catalog_products
    ADD CONSTRAINT wa_catalog_products_pkey PRIMARY KEY (id);


--
-- Name: wa_catalogs wa_catalogs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_catalogs
    ADD CONSTRAINT wa_catalogs_pkey PRIMARY KEY (id);


--
-- Name: wa_contact_group_members wa_contact_group_members_group_id_customer_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_contact_group_members
    ADD CONSTRAINT wa_contact_group_members_group_id_customer_id_key UNIQUE (group_id, customer_id);


--
-- Name: wa_contact_group_members wa_contact_group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_contact_group_members
    ADD CONSTRAINT wa_contact_group_members_pkey PRIMARY KEY (id);


--
-- Name: wa_contact_groups wa_contact_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_contact_groups
    ADD CONSTRAINT wa_contact_groups_pkey PRIMARY KEY (id);


--
-- Name: wa_conversations wa_conversations_account_phone_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_conversations
    ADD CONSTRAINT wa_conversations_account_phone_unique UNIQUE (wa_account_id, customer_phone);


--
-- Name: wa_conversations wa_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_conversations
    ADD CONSTRAINT wa_conversations_pkey PRIMARY KEY (id);


--
-- Name: wa_messages wa_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_messages
    ADD CONSTRAINT wa_messages_pkey PRIMARY KEY (id);


--
-- Name: wa_messages wa_messages_whatsapp_message_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_messages
    ADD CONSTRAINT wa_messages_whatsapp_message_id_unique UNIQUE (whatsapp_message_id);


--
-- Name: wa_settings wa_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_settings
    ADD CONSTRAINT wa_settings_pkey PRIMARY KEY (id);


--
-- Name: wa_settings wa_settings_wa_account_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_settings
    ADD CONSTRAINT wa_settings_wa_account_id_unique UNIQUE (wa_account_id);


--
-- Name: wa_templates wa_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_templates
    ADD CONSTRAINT wa_templates_pkey PRIMARY KEY (id);


--
-- Name: warning_main_category warning_main_category_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warning_main_category
    ADD CONSTRAINT warning_main_category_pkey PRIMARY KEY (id);


--
-- Name: warning_sub_category warning_sub_category_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warning_sub_category
    ADD CONSTRAINT warning_sub_category_pkey PRIMARY KEY (id);


--
-- Name: warning_violation warning_violation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warning_violation
    ADD CONSTRAINT warning_violation_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_message_log whatsapp_message_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_message_log
    ADD CONSTRAINT whatsapp_message_log_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_applicability_rule_periods_effective_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hr_employee_applicability_rule_periods_effective_idx ON public.hr_employee_applicability_rule_periods USING btree (employee_id, rule_type, effective_from, effective_to);


--
-- Name: hr_employee_applicability_rule_periods_employee_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hr_employee_applicability_rule_periods_employee_type_idx ON public.hr_employee_applicability_rule_periods USING btree (employee_id, rule_type);


--
-- Name: hr_employee_leave_approvals_employee_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hr_employee_leave_approvals_employee_date_idx ON public.hr_employee_leave_approvals USING btree (employee_id, leave_date);


--
-- Name: hr_employee_settlement_applicability_leave_rule_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hr_employee_settlement_applicability_leave_rule_idx ON public.hr_employee_settlement_applicability USING btree (leave_salary_rule_id);


--
-- Name: hr_employee_settlement_applicability_ticket_rule_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hr_employee_settlement_applicability_ticket_rule_idx ON public.hr_employee_settlement_applicability USING btree (ticket_rule_id);


--
-- Name: hr_employee_ticket_issuances_employee_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hr_employee_ticket_issuances_employee_date_idx ON public.hr_employee_ticket_issuances USING btree (employee_id, issuance_date);


--
-- Name: hr_salary_statements_dates_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hr_salary_statements_dates_idx ON public.hr_salary_statements USING btree (start_date, end_date);


--
-- Name: hr_salary_statements_updated_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX hr_salary_statements_updated_at_idx ON public.hr_salary_statements USING btree (updated_at DESC);


--
-- Name: idx_access_code_otp_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_access_code_otp_expires ON public.access_code_otp USING btree (expires_at);


--
-- Name: idx_access_code_otp_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_access_code_otp_user ON public.access_code_otp USING btree (user_id);


--
-- Name: idx_analysed_att_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analysed_att_branch ON public.hr_analysed_attendance_data USING btree (branch_id);


--
-- Name: idx_analysed_att_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analysed_att_date ON public.hr_analysed_attendance_data USING btree (shift_date);


--
-- Name: idx_analysed_att_emp_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analysed_att_emp_date ON public.hr_analysed_attendance_data USING btree (employee_id, shift_date);


--
-- Name: idx_analysed_att_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analysed_att_employee_id ON public.hr_analysed_attendance_data USING btree (employee_id);


--
-- Name: idx_analysed_att_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_analysed_att_status ON public.hr_analysed_attendance_data USING btree (status);


--
-- Name: idx_app_icons_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_icons_category ON public.app_icons USING btree (category);


--
-- Name: idx_app_icons_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_icons_key ON public.app_icons USING btree (icon_key);


--
-- Name: idx_approval_permissions_add_missing_punches; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_add_missing_punches ON public.approval_permissions USING btree (can_add_missing_punches) WHERE ((can_add_missing_punches = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_customer_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_customer_incidents ON public.approval_permissions USING btree (can_receive_customer_incidents) WHERE ((can_receive_customer_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_employee_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_employee_incidents ON public.approval_permissions USING btree (can_receive_employee_incidents) WHERE ((can_receive_employee_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_finance_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_finance_incidents ON public.approval_permissions USING btree (can_receive_finance_incidents) WHERE ((can_receive_finance_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_government_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_government_incidents ON public.approval_permissions USING btree (can_receive_government_incidents) WHERE ((can_receive_government_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_is_active ON public.approval_permissions USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_approval_permissions_leave_requests; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_leave_requests ON public.approval_permissions USING btree (can_approve_leave_requests) WHERE ((can_approve_leave_requests = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_maintenance_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_maintenance_incidents ON public.approval_permissions USING btree (can_receive_maintenance_incidents) WHERE ((can_receive_maintenance_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_multiple_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_multiple_bill ON public.approval_permissions USING btree (can_approve_multiple_bill) WHERE ((can_approve_multiple_bill = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_other_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_other_incidents ON public.approval_permissions USING btree (can_receive_other_incidents) WHERE ((can_receive_other_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_pos_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_pos_incidents ON public.approval_permissions USING btree (can_receive_pos_incidents) WHERE ((can_receive_pos_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_purchase_vouchers; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_purchase_vouchers ON public.approval_permissions USING btree (can_approve_purchase_vouchers) WHERE ((can_approve_purchase_vouchers = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_recurring_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_recurring_bill ON public.approval_permissions USING btree (can_approve_recurring_bill) WHERE ((can_approve_recurring_bill = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_requisitions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_requisitions ON public.approval_permissions USING btree (can_approve_requisitions) WHERE ((can_approve_requisitions = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_single_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_single_bill ON public.approval_permissions USING btree (can_approve_single_bill) WHERE ((can_approve_single_bill = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_user_id ON public.approval_permissions USING btree (user_id);


--
-- Name: idx_approval_permissions_vehicle_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_vehicle_incidents ON public.approval_permissions USING btree (can_receive_vehicle_incidents) WHERE ((can_receive_vehicle_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_vendor_incidents; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_vendor_incidents ON public.approval_permissions USING btree (can_receive_vendor_incidents) WHERE ((can_receive_vendor_incidents = true) AND (is_active = true));


--
-- Name: idx_approval_permissions_vendor_payments; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_permissions_vendor_payments ON public.approval_permissions USING btree (can_approve_vendor_payments) WHERE ((can_approve_vendor_payments = true) AND (is_active = true));


--
-- Name: idx_approver_branch_access_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approver_branch_access_active ON public.approver_branch_access USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_approver_branch_access_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approver_branch_access_branch_id ON public.approver_branch_access USING btree (branch_id);


--
-- Name: idx_approver_branch_access_user_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approver_branch_access_user_branch ON public.approver_branch_access USING btree (user_id, branch_id);


--
-- Name: idx_approver_branch_access_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approver_branch_access_user_id ON public.approver_branch_access USING btree (user_id);


--
-- Name: idx_approver_visibility_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approver_visibility_active ON public.approver_visibility_config USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_approver_visibility_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approver_visibility_type ON public.approver_visibility_config USING btree (visibility_type);


--
-- Name: idx_approver_visibility_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approver_visibility_user_id ON public.approver_visibility_config USING btree (user_id);


--
-- Name: idx_asset_main_categories_group_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_asset_main_categories_group_code ON public.asset_main_categories USING btree (group_code);


--
-- Name: idx_asset_main_categories_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_asset_main_categories_name_en ON public.asset_main_categories USING btree (name_en);


--
-- Name: idx_asset_sub_categories_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_asset_sub_categories_category_id ON public.asset_sub_categories USING btree (category_id);


--
-- Name: idx_asset_sub_categories_group_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_asset_sub_categories_group_code ON public.asset_sub_categories USING btree (group_code);


--
-- Name: idx_assets_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assets_asset_id ON public.assets USING btree (asset_id);


--
-- Name: idx_assets_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assets_branch_id ON public.assets USING btree (branch_id);


--
-- Name: idx_assets_sub_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assets_sub_category_id ON public.assets USING btree (sub_category_id);


--
-- Name: idx_bank_reconciliations_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_reconciliations_branch_id ON public.bank_reconciliations USING btree (branch_id);


--
-- Name: idx_bank_reconciliations_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_reconciliations_created_at ON public.bank_reconciliations USING btree (created_at);


--
-- Name: idx_bank_reconciliations_operation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_reconciliations_operation_id ON public.bank_reconciliations USING btree (operation_id);


--
-- Name: idx_biometric_connections_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biometric_connections_active ON public.biometric_connections USING btree (is_active);


--
-- Name: idx_biometric_connections_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biometric_connections_branch ON public.biometric_connections USING btree (branch_id);


--
-- Name: idx_biometric_connections_device; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biometric_connections_device ON public.biometric_connections USING btree (device_id);


--
-- Name: idx_biometric_connections_terminal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biometric_connections_terminal ON public.biometric_connections USING btree (terminal_sn);


--
-- Name: idx_bogo_offer_rules_buy_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bogo_offer_rules_buy_product ON public.bogo_offer_rules USING btree (buy_product_id);


--
-- Name: idx_bogo_offer_rules_buy_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bogo_offer_rules_buy_product_id ON public.bogo_offer_rules USING btree (buy_product_id);


--
-- Name: idx_bogo_offer_rules_get_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bogo_offer_rules_get_product ON public.bogo_offer_rules USING btree (get_product_id);


--
-- Name: idx_bogo_offer_rules_get_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bogo_offer_rules_get_product_id ON public.bogo_offer_rules USING btree (get_product_id);


--
-- Name: idx_bogo_offer_rules_offer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bogo_offer_rules_offer_id ON public.bogo_offer_rules USING btree (offer_id);


--
-- Name: idx_box_operations_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_box_operations_active ON public.box_operations USING btree (branch_id, status) WHERE ((status)::text = 'in_use'::text);


--
-- Name: idx_box_operations_box; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_box_operations_box ON public.box_operations USING btree (box_number);


--
-- Name: idx_box_operations_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_box_operations_branch ON public.box_operations USING btree (branch_id);


--
-- Name: idx_box_operations_denomination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_box_operations_denomination ON public.box_operations USING btree (denomination_record_id);


--
-- Name: idx_box_operations_pos_before_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_box_operations_pos_before_url ON public.box_operations USING btree (pos_before_url);


--
-- Name: idx_box_operations_start_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_box_operations_start_time ON public.box_operations USING btree (start_time DESC);


--
-- Name: idx_box_operations_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_box_operations_status ON public.box_operations USING btree (status);


--
-- Name: idx_box_operations_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_box_operations_user ON public.box_operations USING btree (user_id);


--
-- Name: idx_branch_default_positions_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_default_positions_branch_id ON public.branch_default_positions USING btree (branch_id);


--
-- Name: idx_branch_delivery_receivers_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_delivery_receivers_branch ON public.branch_default_delivery_receivers USING btree (branch_id) WHERE (is_active = true);


--
-- Name: idx_branch_delivery_receivers_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_delivery_receivers_user ON public.branch_default_delivery_receivers USING btree (user_id) WHERE (is_active = true);


--
-- Name: idx_branches_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branches_active ON public.branches USING btree (is_active);


--
-- Name: idx_branches_main; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branches_main ON public.branches USING btree (is_main_branch);


--
-- Name: idx_branches_name_ar; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branches_name_ar ON public.branches USING btree (name_ar);


--
-- Name: idx_branches_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branches_name_en ON public.branches USING btree (name_en);


--
-- Name: idx_branches_vat_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branches_vat_number ON public.branches USING btree (vat_number) WHERE (vat_number IS NOT NULL);


--
-- Name: idx_break_register_employee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_break_register_employee ON public.break_register USING btree (employee_id);


--
-- Name: idx_break_register_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_break_register_start ON public.break_register USING btree (start_time DESC);


--
-- Name: idx_break_register_user_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_break_register_user_status ON public.break_register USING btree (user_id, status);


--
-- Name: idx_button_main_sections_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_button_main_sections_active ON public.button_main_sections USING btree (is_active);


--
-- Name: idx_button_permissions_button; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_button_permissions_button ON public.button_permissions USING btree (button_id);


--
-- Name: idx_button_permissions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_button_permissions_user ON public.button_permissions USING btree (user_id);


--
-- Name: idx_button_sub_sections_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_button_sub_sections_active ON public.button_sub_sections USING btree (is_active);


--
-- Name: idx_button_sub_sections_main; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_button_sub_sections_main ON public.button_sub_sections USING btree (main_section_id);


--
-- Name: idx_campaigns_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campaigns_active ON public.coupon_campaigns USING btree (is_active) WHERE (deleted_at IS NULL);


--
-- Name: idx_campaigns_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campaigns_code ON public.coupon_campaigns USING btree (campaign_code);


--
-- Name: idx_campaigns_validity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campaigns_validity ON public.coupon_campaigns USING btree (validity_start_date, validity_end_date);


--
-- Name: idx_cashier_device_bindings_device; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cashier_device_bindings_device ON public.cashier_device_bindings USING btree (device_id);


--
-- Name: idx_checklist_operations_submission_type_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_checklist_operations_submission_type_en ON public.hr_checklist_operations USING btree (submission_type_en);


--
-- Name: idx_coupon_claims_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_claims_branch ON public.coupon_claims USING btree (branch_id);


--
-- Name: idx_coupon_claims_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_claims_campaign ON public.coupon_claims USING btree (campaign_id);


--
-- Name: idx_coupon_claims_customer_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_claims_customer_campaign ON public.coupon_claims USING btree (campaign_id, customer_mobile);


--
-- Name: idx_coupon_claims_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_claims_date ON public.coupon_claims USING btree (claimed_at);


--
-- Name: idx_coupon_claims_mobile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_claims_mobile ON public.coupon_claims USING btree (customer_mobile);


--
-- Name: idx_coupon_claims_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_claims_product ON public.coupon_claims USING btree (product_id);


--
-- Name: idx_coupon_products_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_products_barcode ON public.coupon_products USING btree (special_barcode);


--
-- Name: idx_coupon_products_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_products_campaign ON public.coupon_products USING btree (campaign_id);


--
-- Name: idx_coupon_products_stock; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_products_stock ON public.coupon_products USING btree (stock_remaining) WHERE (is_active = true);


--
-- Name: idx_customer_access_code_history_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_access_code_history_created_at ON public.customer_access_code_history USING btree (created_at);


--
-- Name: idx_customer_access_code_history_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_access_code_history_customer_id ON public.customer_access_code_history USING btree (customer_id);


--
-- Name: idx_customer_access_code_history_generated_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_access_code_history_generated_by ON public.customer_access_code_history USING btree (generated_by);


--
-- Name: idx_customer_app_media_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_app_media_active ON public.customer_app_media USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_customer_app_media_display_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_app_media_display_order ON public.customer_app_media USING btree (display_order);


--
-- Name: idx_customer_app_media_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_app_media_expiry ON public.customer_app_media USING btree (expiry_date) WHERE (expiry_date IS NOT NULL);


--
-- Name: idx_customer_app_media_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_app_media_type ON public.customer_app_media USING btree (media_type);


--
-- Name: idx_customer_product_requests_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_product_requests_branch ON public.customer_product_requests USING btree (branch_id);


--
-- Name: idx_customer_product_requests_requester; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_product_requests_requester ON public.customer_product_requests USING btree (requester_user_id);


--
-- Name: idx_customer_product_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_product_requests_status ON public.customer_product_requests USING btree (status);


--
-- Name: idx_customer_product_requests_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_product_requests_target ON public.customer_product_requests USING btree (target_user_id);


--
-- Name: idx_customer_recovery_requests_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_recovery_requests_created_at ON public.customer_recovery_requests USING btree (created_at);


--
-- Name: idx_customer_recovery_requests_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_recovery_requests_customer_id ON public.customer_recovery_requests USING btree (customer_id);


--
-- Name: idx_customer_recovery_requests_processed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_recovery_requests_processed_by ON public.customer_recovery_requests USING btree (processed_by);


--
-- Name: idx_customer_recovery_requests_request_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_recovery_requests_request_type ON public.customer_recovery_requests USING btree (request_type);


--
-- Name: idx_customer_recovery_requests_verification_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_recovery_requests_verification_status ON public.customer_recovery_requests USING btree (verification_status);


--
-- Name: idx_customer_recovery_requests_whatsapp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_recovery_requests_whatsapp ON public.customer_recovery_requests USING btree (whatsapp_number);


--
-- Name: idx_customers_access_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_access_code ON public.customers USING btree (access_code) WHERE (access_code IS NOT NULL);


--
-- Name: idx_customers_approved_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_approved_by ON public.customers USING btree (approved_by);


--
-- Name: idx_customers_is_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_is_deleted ON public.customers USING btree (is_deleted) WHERE (is_deleted = true);


--
-- Name: idx_customers_registration_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_registration_status ON public.customers USING btree (registration_status);


--
-- Name: idx_customers_whatsapp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_whatsapp ON public.customers USING btree (whatsapp_number) WHERE (whatsapp_number IS NOT NULL);


--
-- Name: idx_day_off_approval_requested_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_approval_requested_by ON public.day_off USING btree (approval_requested_by);


--
-- Name: idx_day_off_approval_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_approval_status ON public.day_off USING btree (approval_status);


--
-- Name: idx_day_off_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_date ON public.day_off USING btree (day_off_date);


--
-- Name: idx_day_off_description; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_description ON public.day_off USING btree (description);


--
-- Name: idx_day_off_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_employee_id ON public.day_off USING btree (employee_id);


--
-- Name: idx_day_off_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_reason_id ON public.day_off USING btree (day_off_reason_id);


--
-- Name: idx_day_off_reasons_deductible; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_reasons_deductible ON public.day_off_reasons USING btree (is_deductible);


--
-- Name: idx_day_off_reasons_document_mandatory; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_reasons_document_mandatory ON public.day_off_reasons USING btree (is_document_mandatory);


--
-- Name: idx_day_off_weekday_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_weekday_employee_id ON public.day_off_weekday USING btree (employee_id);


--
-- Name: idx_day_off_weekday_weekday; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_off_weekday_weekday ON public.day_off_weekday USING btree (weekday);


--
-- Name: idx_default_incident_users_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_default_incident_users_type ON public.default_incident_users USING btree (incident_type_id);


--
-- Name: idx_default_incident_users_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_default_incident_users_user ON public.default_incident_users USING btree (user_id);


--
-- Name: idx_deleted_bundle_offers_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deleted_bundle_offers_deleted_at ON public.deleted_bundle_offers USING btree (deleted_at DESC);


--
-- Name: idx_deleted_bundle_offers_deleted_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deleted_bundle_offers_deleted_by ON public.deleted_bundle_offers USING btree (deleted_by);


--
-- Name: idx_deleted_bundle_offers_original_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deleted_bundle_offers_original_id ON public.deleted_bundle_offers USING btree (original_offer_id);


--
-- Name: idx_delivery_tiers_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_tiers_active ON public.delivery_fee_tiers USING btree (is_active);


--
-- Name: idx_delivery_tiers_branch_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_tiers_branch_order ON public.delivery_fee_tiers USING btree (branch_id, tier_order);


--
-- Name: idx_delivery_tiers_branch_order_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_tiers_branch_order_amount ON public.delivery_fee_tiers USING btree (branch_id, min_order_amount, max_order_amount) WHERE (is_active = true);


--
-- Name: idx_delivery_tiers_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_tiers_order ON public.delivery_fee_tiers USING btree (tier_order);


--
-- Name: idx_delivery_tiers_order_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_tiers_order_amount ON public.delivery_fee_tiers USING btree (min_order_amount, max_order_amount);


--
-- Name: idx_denomination_audit_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_audit_action ON public.denomination_audit_log USING btree (action);


--
-- Name: idx_denomination_audit_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_audit_branch ON public.denomination_audit_log USING btree (branch_id);


--
-- Name: idx_denomination_audit_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_audit_created ON public.denomination_audit_log USING btree (created_at DESC);


--
-- Name: idx_denomination_audit_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_audit_record ON public.denomination_audit_log USING btree (record_id);


--
-- Name: idx_denomination_audit_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_audit_user ON public.denomination_audit_log USING btree (user_id);


--
-- Name: idx_denomination_records_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_records_branch ON public.denomination_records USING btree (branch_id);


--
-- Name: idx_denomination_records_branch_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_records_branch_created ON public.denomination_records USING btree (branch_id, created_at DESC);


--
-- Name: idx_denomination_records_branch_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_records_branch_type ON public.denomination_records USING btree (branch_id, record_type);


--
-- Name: idx_denomination_records_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_records_created_at ON public.denomination_records USING btree (created_at);


--
-- Name: idx_denomination_records_history; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_records_history ON public.denomination_records USING btree (branch_id, record_type, created_at DESC);


--
-- Name: idx_denomination_records_petty_cash_operation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_records_petty_cash_operation ON public.denomination_records USING gin (petty_cash_operation);


--
-- Name: idx_denomination_records_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_records_type ON public.denomination_records USING btree (record_type);


--
-- Name: idx_denomination_records_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_records_user ON public.denomination_records USING btree (user_id);


--
-- Name: idx_denomination_transactions_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_transactions_branch_id ON public.denomination_transactions USING btree (branch_id);


--
-- Name: idx_denomination_transactions_branch_section; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_transactions_branch_section ON public.denomination_transactions USING btree (branch_id, section);


--
-- Name: idx_denomination_transactions_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_transactions_created_at ON public.denomination_transactions USING btree (created_at DESC);


--
-- Name: idx_denomination_transactions_section; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_transactions_section ON public.denomination_transactions USING btree (section);


--
-- Name: idx_denomination_transactions_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_transactions_type ON public.denomination_transactions USING btree (transaction_type);


--
-- Name: idx_denomination_types_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_types_active ON public.denomination_types USING btree (is_active, sort_order);


--
-- Name: idx_denomination_user_preferences_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_denomination_user_preferences_user_id ON public.denomination_user_preferences USING btree (user_id);


--
-- Name: idx_desktop_themes_is_default; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_desktop_themes_is_default ON public.desktop_themes USING btree (is_default);


--
-- Name: idx_eligible_customers_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_eligible_customers_campaign ON public.coupon_eligible_customers USING btree (campaign_id);


--
-- Name: idx_eligible_customers_mobile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_eligible_customers_mobile ON public.coupon_eligible_customers USING btree (mobile_number);


--
-- Name: idx_employee_checklist_assignments_assigned_to_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employee_checklist_assignments_assigned_to_user_id ON public.employee_checklist_assignments USING btree (assigned_to_user_id);


--
-- Name: idx_employee_checklist_assignments_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employee_checklist_assignments_branch_id ON public.employee_checklist_assignments USING btree (branch_id);


--
-- Name: idx_employee_checklist_assignments_checklist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employee_checklist_assignments_checklist_id ON public.employee_checklist_assignments USING btree (checklist_id);


--
-- Name: idx_employee_checklist_assignments_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employee_checklist_assignments_deleted_at ON public.employee_checklist_assignments USING btree (deleted_at);


--
-- Name: idx_employee_checklist_assignments_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employee_checklist_assignments_employee_id ON public.employee_checklist_assignments USING btree (employee_id);


--
-- Name: idx_employment_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employment_status ON public.hr_employee_master USING btree (employment_status);


--
-- Name: idx_employment_status_effective_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employment_status_effective_date ON public.hr_employee_master USING btree (employment_status_effective_date);


--
-- Name: idx_eoh_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_eoh_employee_id ON public.employee_official_holidays USING btree (employee_id);


--
-- Name: idx_eoh_holiday_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_eoh_holiday_id ON public.employee_official_holidays USING btree (official_holiday_id);


--
-- Name: idx_erp_connections_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_connections_branch_id ON public.erp_connections USING btree (branch_id);


--
-- Name: idx_erp_connections_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_connections_device_id ON public.erp_connections USING btree (device_id);


--
-- Name: idx_erp_connections_erp_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_connections_erp_branch_id ON public.erp_connections USING btree (erp_branch_id);


--
-- Name: idx_erp_connections_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_connections_is_active ON public.erp_connections USING btree (is_active);


--
-- Name: idx_erp_daily_sales_branch_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_daily_sales_branch_date ON public.erp_daily_sales USING btree (branch_id, sale_date);


--
-- Name: idx_erp_daily_sales_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_daily_sales_branch_id ON public.erp_daily_sales USING btree (branch_id);


--
-- Name: idx_erp_daily_sales_sale_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_daily_sales_sale_date ON public.erp_daily_sales USING btree (sale_date);


--
-- Name: idx_erp_sync_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_sync_logs_created_at ON public.erp_sync_logs USING btree (created_at DESC);


--
-- Name: idx_erp_synced_products_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_synced_products_barcode ON public.erp_synced_products USING btree (barcode);


--
-- Name: idx_erp_synced_products_expiry_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_synced_products_expiry_dates ON public.erp_synced_products USING gin (expiry_dates);


--
-- Name: idx_erp_synced_products_expiry_hidden; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_synced_products_expiry_hidden ON public.erp_synced_products USING btree (expiry_hidden) WHERE (expiry_hidden = true);


--
-- Name: idx_erp_synced_products_in_process; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_synced_products_in_process ON public.erp_synced_products USING gin (in_process);


--
-- Name: idx_erp_synced_products_managed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_synced_products_managed_by ON public.erp_synced_products USING gin (managed_by);


--
-- Name: idx_erp_synced_products_parent_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_synced_products_parent_barcode ON public.erp_synced_products USING btree (parent_barcode);


--
-- Name: idx_erp_synced_products_product_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_erp_synced_products_product_name_en ON public.erp_synced_products USING btree (product_name_en);


--
-- Name: idx_expense_parent_categories_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_parent_categories_is_active ON public.expense_parent_categories USING btree (is_active);


--
-- Name: idx_expense_requisitions_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_requisitions_due_date ON public.expense_requisitions USING btree (due_date);


--
-- Name: idx_expense_requisitions_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_requisitions_is_active ON public.expense_requisitions USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_expense_requisitions_remaining_balance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_requisitions_remaining_balance ON public.expense_requisitions USING btree (remaining_balance);


--
-- Name: idx_expense_requisitions_requester_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_requisitions_requester_ref ON public.expense_requisitions USING btree (requester_ref_id);


--
-- Name: idx_expense_requisitions_status_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_requisitions_status_active ON public.expense_requisitions USING btree (status, is_active);


--
-- Name: idx_expense_scheduler_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_approver_id ON public.expense_scheduler USING btree (approver_id) WHERE (approver_id IS NOT NULL);


--
-- Name: idx_expense_scheduler_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_branch_id ON public.expense_scheduler USING btree (branch_id);


--
-- Name: idx_expense_scheduler_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_category_id ON public.expense_scheduler USING btree (expense_category_id);


--
-- Name: idx_expense_scheduler_co_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_co_user_id ON public.expense_scheduler USING btree (co_user_id);


--
-- Name: idx_expense_scheduler_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_created_at ON public.expense_scheduler USING btree (created_at DESC);


--
-- Name: idx_expense_scheduler_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_created_by ON public.expense_scheduler USING btree (created_by);


--
-- Name: idx_expense_scheduler_credit_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_credit_period ON public.expense_scheduler USING btree (credit_period);


--
-- Name: idx_expense_scheduler_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_due_date ON public.expense_scheduler USING btree (due_date);


--
-- Name: idx_expense_scheduler_due_date_paid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_due_date_paid ON public.expense_scheduler USING btree (due_date, is_paid);


--
-- Name: idx_expense_scheduler_is_paid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_is_paid ON public.expense_scheduler USING btree (is_paid);


--
-- Name: idx_expense_scheduler_payment_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_payment_reference ON public.expense_scheduler USING btree (payment_reference) WHERE (payment_reference IS NOT NULL);


--
-- Name: idx_expense_scheduler_recurring_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_recurring_type ON public.expense_scheduler USING btree (recurring_type) WHERE (recurring_type IS NOT NULL);


--
-- Name: idx_expense_scheduler_requisition_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_requisition_id ON public.expense_scheduler USING btree (requisition_id);


--
-- Name: idx_expense_scheduler_schedule_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_schedule_type ON public.expense_scheduler USING btree (schedule_type);


--
-- Name: idx_expense_scheduler_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_scheduler_status ON public.expense_scheduler USING btree (status);


--
-- Name: idx_expense_sub_categories_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_sub_categories_is_active ON public.expense_sub_categories USING btree (is_active);


--
-- Name: idx_expense_sub_categories_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_sub_categories_parent ON public.expense_sub_categories USING btree (parent_category_id);


--
-- Name: idx_fine_payments_payment_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fine_payments_payment_date ON public.employee_fine_payments USING btree (payment_date);


--
-- Name: idx_fine_payments_processed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fine_payments_processed_by ON public.employee_fine_payments USING btree (processed_by);


--
-- Name: idx_fine_payments_warning_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fine_payments_warning_id ON public.employee_fine_payments USING btree (warning_id);


--
-- Name: idx_fingerprint_transactions_processed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fingerprint_transactions_processed ON public.hr_fingerprint_transactions USING btree (processed);


--
-- Name: idx_flyer_offer_products_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_offer_products_barcode ON public.flyer_offer_products USING btree (product_barcode);


--
-- Name: idx_flyer_offer_products_offer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_offer_products_offer_id ON public.flyer_offer_products USING btree (offer_id);


--
-- Name: idx_flyer_offer_products_page; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_offer_products_page ON public.flyer_offer_products USING btree (offer_id, page_number, page_order);


--
-- Name: idx_flyer_offers_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_offers_dates ON public.flyer_offers USING btree (start_date, end_date);


--
-- Name: idx_flyer_offers_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_offers_is_active ON public.flyer_offers USING btree (is_active);


--
-- Name: idx_flyer_offers_offer_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_offers_offer_name ON public.flyer_offers USING btree (offer_name);


--
-- Name: idx_flyer_offers_offer_name_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_offers_offer_name_id ON public.flyer_offers USING btree (offer_name_id);


--
-- Name: idx_flyer_offers_template_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_offers_template_id ON public.flyer_offers USING btree (template_id);


--
-- Name: idx_flyer_templates_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_templates_category ON public.flyer_templates USING btree (category) WHERE (deleted_at IS NULL);


--
-- Name: idx_flyer_templates_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_templates_created_at ON public.flyer_templates USING btree (created_at DESC);


--
-- Name: idx_flyer_templates_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_templates_created_by ON public.flyer_templates USING btree (created_by);


--
-- Name: idx_flyer_templates_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_templates_is_active ON public.flyer_templates USING btree (is_active) WHERE (deleted_at IS NULL);


--
-- Name: idx_flyer_templates_is_default; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_templates_is_default ON public.flyer_templates USING btree (is_default) WHERE ((is_default = true) AND (deleted_at IS NULL));


--
-- Name: idx_flyer_templates_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flyer_templates_tags ON public.flyer_templates USING gin (tags);


--
-- Name: idx_gift_wheel_coupons_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gift_wheel_coupons_code ON public.gift_wheel_coupons USING btree (code);


--
-- Name: idx_gift_wheel_coupons_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gift_wheel_coupons_status ON public.gift_wheel_coupons USING btree (status);


--
-- Name: idx_gift_wheel_spins_bill_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gift_wheel_spins_bill_number ON public.gift_wheel_spins USING btree (bill_number);


--
-- Name: idx_gift_wheel_spins_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gift_wheel_spins_created_at ON public.gift_wheel_spins USING btree (created_at);


--
-- Name: idx_hr_assignments_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_assignments_branch_id ON public.hr_position_assignments USING btree (branch_id);


--
-- Name: idx_hr_assignments_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_assignments_employee_id ON public.hr_position_assignments USING btree (employee_id);


--
-- Name: idx_hr_basic_salary_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_basic_salary_employee_id ON public.hr_basic_salary USING btree (employee_id);


--
-- Name: idx_hr_checklist_operations_box; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_operations_box ON public.hr_checklist_operations USING btree (box_operation_id);


--
-- Name: idx_hr_checklist_operations_box_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_operations_box_number ON public.hr_checklist_operations USING btree (box_number);


--
-- Name: idx_hr_checklist_operations_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_operations_branch ON public.hr_checklist_operations USING btree (branch_id);


--
-- Name: idx_hr_checklist_operations_checklist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_operations_checklist ON public.hr_checklist_operations USING btree (checklist_id);


--
-- Name: idx_hr_checklist_operations_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_operations_created ON public.hr_checklist_operations USING btree (created_at DESC);


--
-- Name: idx_hr_checklist_operations_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_operations_date ON public.hr_checklist_operations USING btree (operation_date DESC);


--
-- Name: idx_hr_checklist_operations_employee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_operations_employee ON public.hr_checklist_operations USING btree (employee_id);


--
-- Name: idx_hr_checklist_operations_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_operations_user ON public.hr_checklist_operations USING btree (user_id);


--
-- Name: idx_hr_checklist_questions_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklist_questions_created ON public.hr_checklist_questions USING btree (created_at DESC);


--
-- Name: idx_hr_checklists_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_checklists_created ON public.hr_checklists USING btree (created_at DESC);


--
-- Name: idx_hr_employee_driving_licence_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_driving_licence_expiry ON public.hr_employee_master USING btree (driving_licence_expiry_date);


--
-- Name: idx_hr_employee_esob_records_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_esob_records_employee_id ON public.hr_employee_esob_records USING btree (employee_id);


--
-- Name: idx_hr_employee_esob_records_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_esob_records_updated_at ON public.hr_employee_esob_records USING btree (updated_at DESC);


--
-- Name: idx_hr_employee_health_card_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_health_card_expiry ON public.hr_employee_master USING btree (health_card_expiry_date);


--
-- Name: idx_hr_employee_id_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_id_expiry ON public.hr_employee_master USING btree (id_expiry_date);


--
-- Name: idx_hr_employee_master_bank_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_bank_name ON public.hr_employee_master USING btree (bank_name);


--
-- Name: idx_hr_employee_master_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_branch_id ON public.hr_employee_master USING btree (current_branch_id);


--
-- Name: idx_hr_employee_master_date_of_birth; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_date_of_birth ON public.hr_employee_master USING btree (date_of_birth);


--
-- Name: idx_hr_employee_master_driving_licence_expiry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_driving_licence_expiry_date ON public.hr_employee_master USING btree (driving_licence_expiry_date);


--
-- Name: idx_hr_employee_master_employee_mapping; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_employee_mapping ON public.hr_employee_master USING gin (employee_id_mapping);


--
-- Name: idx_hr_employee_master_health_card_expiry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_health_card_expiry_date ON public.hr_employee_master USING btree (health_card_expiry_date);


--
-- Name: idx_hr_employee_master_health_educational_renewal_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_health_educational_renewal_date ON public.hr_employee_master USING btree (health_educational_renewal_date);


--
-- Name: idx_hr_employee_master_id_expiry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_id_expiry_date ON public.hr_employee_master USING btree (id_expiry_date);


--
-- Name: idx_hr_employee_master_insurance_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_insurance_company_id ON public.hr_employee_master USING btree (insurance_company_id);


--
-- Name: idx_hr_employee_master_insurance_expiry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_insurance_expiry_date ON public.hr_employee_master USING btree (insurance_expiry_date);


--
-- Name: idx_hr_employee_master_join_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_join_date ON public.hr_employee_master USING btree (join_date);


--
-- Name: idx_hr_employee_master_nationality_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_nationality_id ON public.hr_employee_master USING btree (nationality_id);


--
-- Name: idx_hr_employee_master_permitted_early_leave_hours; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_permitted_early_leave_hours ON public.hr_employee_master USING btree (permitted_early_leave_hours);


--
-- Name: idx_hr_employee_master_position_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_position_id ON public.hr_employee_master USING btree (current_position_id);


--
-- Name: idx_hr_employee_master_probation_period_expiry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_probation_period_expiry_date ON public.hr_employee_master USING btree (probation_period_expiry_date);


--
-- Name: idx_hr_employee_master_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_user_id ON public.hr_employee_master USING btree (user_id);


--
-- Name: idx_hr_employee_master_work_permit_expiry_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_master_work_permit_expiry_date ON public.hr_employee_master USING btree (work_permit_expiry_date);


--
-- Name: idx_hr_employees_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employees_branch_id ON public.hr_employees USING btree (branch_id);


--
-- Name: idx_hr_employees_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employees_employee_id ON public.hr_employees USING btree (employee_id);


--
-- Name: idx_hr_employees_employee_id_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employees_employee_id_branch_id ON public.hr_employees USING btree (employee_id, branch_id);


--
-- Name: idx_hr_employees_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employees_updated_at ON public.hr_employees USING btree (updated_at);


--
-- Name: idx_hr_esob_base_rules_years; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_esob_base_rules_years ON public.hr_esob_base_rules USING btree (years_from, years_to);


--
-- Name: idx_hr_esob_resignation_factors_years; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_esob_resignation_factors_years ON public.hr_esob_resignation_factors USING btree (years_from, years_to);


--
-- Name: idx_hr_fingerprint_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_fingerprint_branch_id ON public.hr_fingerprint_transactions USING btree (branch_id);


--
-- Name: idx_hr_fingerprint_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_fingerprint_date ON public.hr_fingerprint_transactions USING btree (date);


--
-- Name: idx_hr_fingerprint_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_fingerprint_employee_id ON public.hr_fingerprint_transactions USING btree (employee_id);


--
-- Name: idx_hr_fingerprint_punch_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_fingerprint_punch_state ON public.hr_fingerprint_transactions USING btree (status);


--
-- Name: idx_hr_insurance_companies_name_ar; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_insurance_companies_name_ar ON public.hr_insurance_companies USING btree (name_ar);


--
-- Name: idx_hr_insurance_companies_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_insurance_companies_name_en ON public.hr_insurance_companies USING btree (name_en);


--
-- Name: idx_hr_position_template_mgr1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_position_template_mgr1 ON public.hr_position_reporting_template USING btree (manager_position_1);


--
-- Name: idx_hr_position_template_mgr2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_position_template_mgr2 ON public.hr_position_reporting_template USING btree (manager_position_2);


--
-- Name: idx_hr_position_template_mgr3; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_position_template_mgr3 ON public.hr_position_reporting_template USING btree (manager_position_3);


--
-- Name: idx_hr_position_template_mgr4; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_position_template_mgr4 ON public.hr_position_reporting_template USING btree (manager_position_4);


--
-- Name: idx_hr_position_template_mgr5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_position_template_mgr5 ON public.hr_position_reporting_template USING btree (manager_position_5);


--
-- Name: idx_hr_position_template_subordinate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_position_template_subordinate ON public.hr_position_reporting_template USING btree (subordinate_position_id);


--
-- Name: idx_hr_salary_notes_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_salary_notes_created_at ON public.hr_salary_notes USING btree (created_at DESC);


--
-- Name: idx_hr_salary_notes_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_salary_notes_employee_id ON public.hr_salary_notes USING btree (employee_id);


--
-- Name: idx_incident_actions_action_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incident_actions_action_type ON public.incident_actions USING btree (action_type);


--
-- Name: idx_incident_actions_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incident_actions_employee_id ON public.incident_actions USING btree (employee_id);


--
-- Name: idx_incident_actions_has_fine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incident_actions_has_fine ON public.incident_actions USING btree (has_fine);


--
-- Name: idx_incident_actions_incident_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incident_actions_incident_id ON public.incident_actions USING btree (incident_id);


--
-- Name: idx_incident_actions_is_paid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incident_actions_is_paid ON public.incident_actions USING btree (is_paid);


--
-- Name: idx_incident_types_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incident_types_is_active ON public.incident_types USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_incidents_attachments; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_attachments ON public.incidents USING gin (attachments);


--
-- Name: idx_incidents_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_branch_id ON public.incidents USING btree (branch_id);


--
-- Name: idx_incidents_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_created_at ON public.incidents USING btree (created_at DESC);


--
-- Name: idx_incidents_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_employee_id ON public.incidents USING btree (employee_id);


--
-- Name: idx_incidents_incident_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_incident_type_id ON public.incidents USING btree (incident_type_id);


--
-- Name: idx_incidents_related_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_related_party ON public.incidents USING gin (related_party) WHERE (related_party IS NOT NULL);


--
-- Name: idx_incidents_reports_to_user_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_reports_to_user_ids ON public.incidents USING gin (reports_to_user_ids);


--
-- Name: idx_incidents_resolution_report; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_resolution_report ON public.incidents USING gin (resolution_report) WHERE (resolution_report IS NOT NULL);


--
-- Name: idx_incidents_resolution_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_resolution_status ON public.incidents USING btree (resolution_status);


--
-- Name: idx_incidents_violation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_violation_id ON public.incidents USING btree (violation_id);


--
-- Name: idx_interface_permissions_cashier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interface_permissions_cashier ON public.interface_permissions USING btree (cashier_enabled) WHERE (cashier_enabled = true);


--
-- Name: idx_interface_permissions_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interface_permissions_customer ON public.interface_permissions USING btree (customer_enabled);


--
-- Name: idx_interface_permissions_desktop; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interface_permissions_desktop ON public.interface_permissions USING btree (desktop_enabled);


--
-- Name: idx_interface_permissions_mobile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interface_permissions_mobile ON public.interface_permissions USING btree (mobile_enabled);


--
-- Name: idx_interface_permissions_updated_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interface_permissions_updated_by ON public.interface_permissions USING btree (updated_by);


--
-- Name: idx_interface_permissions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interface_permissions_user_id ON public.interface_permissions USING btree (user_id);


--
-- Name: idx_issue_types_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_issue_types_name ON public.purchase_voucher_issue_types USING btree (type_name);


--
-- Name: idx_lcb_bill_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lcb_bill_date ON public.loyalty_customer_bills USING btree (bill_date);


--
-- Name: idx_lcb_whatsapp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lcb_whatsapp ON public.loyalty_customer_bills USING btree (whatsapp_number);


--
-- Name: idx_lease_rent_properties_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lease_rent_properties_created_by ON public.lease_rent_properties USING btree (created_by);


--
-- Name: idx_lease_rent_properties_is_leased; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lease_rent_properties_is_leased ON public.lease_rent_properties USING btree (is_leased);


--
-- Name: idx_lease_rent_properties_is_rented; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lease_rent_properties_is_rented ON public.lease_rent_properties USING btree (is_rented);


--
-- Name: idx_lease_rent_property_spaces_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lease_rent_property_spaces_created_by ON public.lease_rent_property_spaces USING btree (created_by);


--
-- Name: idx_lease_rent_property_spaces_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lease_rent_property_spaces_property_id ON public.lease_rent_property_spaces USING btree (property_id);


--
-- Name: idx_lrlp_collection_incharge; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrlp_collection_incharge ON public.lease_rent_lease_parties USING btree (collection_incharge_id);


--
-- Name: idx_lrlp_contract_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrlp_contract_dates ON public.lease_rent_lease_parties USING btree (contract_start_date, contract_end_date);


--
-- Name: idx_lrlp_payment_mode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrlp_payment_mode ON public.lease_rent_lease_parties USING btree (payment_mode);


--
-- Name: idx_lrlp_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrlp_property_id ON public.lease_rent_lease_parties USING btree (property_id);


--
-- Name: idx_lrlp_property_space_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrlp_property_space_id ON public.lease_rent_lease_parties USING btree (property_space_id);


--
-- Name: idx_lrrp_collection_incharge; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrrp_collection_incharge ON public.lease_rent_rent_parties USING btree (collection_incharge_id);


--
-- Name: idx_lrrp_contract_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrrp_contract_dates ON public.lease_rent_rent_parties USING btree (contract_start_date, contract_end_date);


--
-- Name: idx_lrrp_payment_mode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrrp_payment_mode ON public.lease_rent_rent_parties USING btree (payment_mode);


--
-- Name: idx_lrrp_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrrp_property_id ON public.lease_rent_rent_parties USING btree (property_id);


--
-- Name: idx_lrrp_property_space_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lrrp_property_space_id ON public.lease_rent_rent_parties USING btree (property_space_id);


--
-- Name: idx_mobile_themes_is_default; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mobile_themes_is_default ON public.mobile_themes USING btree (is_default);


--
-- Name: idx_multi_shift_date_wise_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_multi_shift_date_wise_dates ON public.multi_shift_date_wise USING btree (date_from, date_to);


--
-- Name: idx_multi_shift_date_wise_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_multi_shift_date_wise_employee_id ON public.multi_shift_date_wise USING btree (employee_id);


--
-- Name: idx_multi_shift_regular_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_multi_shift_regular_employee_id ON public.multi_shift_regular USING btree (employee_id);


--
-- Name: idx_multi_shift_weekday_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_multi_shift_weekday_employee_id ON public.multi_shift_weekday USING btree (employee_id);


--
-- Name: idx_multi_shift_weekday_weekday; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_multi_shift_weekday_weekday ON public.multi_shift_weekday USING btree (weekday);


--
-- Name: idx_mv_expiry_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mv_expiry_barcode ON public.mv_expiry_products USING btree (barcode);


--
-- Name: idx_mv_expiry_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mv_expiry_branch ON public.mv_expiry_products USING btree (branch_id);


--
-- Name: idx_mv_expiry_days; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mv_expiry_days ON public.mv_expiry_products USING btree (days_left);


--
-- Name: idx_mv_expiry_hidden; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mv_expiry_hidden ON public.mv_expiry_products USING btree (expiry_hidden);


--
-- Name: idx_mv_expiry_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mv_expiry_unique ON public.mv_expiry_products USING btree (barcode, branch_id, expiry_date);


--
-- Name: idx_near_expiry_reports_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_near_expiry_reports_branch ON public.near_expiry_reports USING btree (branch_id);


--
-- Name: idx_near_expiry_reports_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_near_expiry_reports_created ON public.near_expiry_reports USING btree (created_at DESC);


--
-- Name: idx_near_expiry_reports_reporter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_near_expiry_reports_reporter ON public.near_expiry_reports USING btree (reporter_user_id);


--
-- Name: idx_near_expiry_reports_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_near_expiry_reports_status ON public.near_expiry_reports USING btree (status);


--
-- Name: idx_near_expiry_reports_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_near_expiry_reports_target ON public.near_expiry_reports USING btree (target_user_id);


--
-- Name: idx_non_approved_scheduler_approval_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_approval_status ON public.non_approved_payment_scheduler USING btree (approval_status);


--
-- Name: idx_non_approved_scheduler_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_approver_id ON public.non_approved_payment_scheduler USING btree (approver_id);


--
-- Name: idx_non_approved_scheduler_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_branch_id ON public.non_approved_payment_scheduler USING btree (branch_id);


--
-- Name: idx_non_approved_scheduler_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_category_id ON public.non_approved_payment_scheduler USING btree (expense_category_id);


--
-- Name: idx_non_approved_scheduler_co_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_co_user_id ON public.non_approved_payment_scheduler USING btree (co_user_id) WHERE (co_user_id IS NOT NULL);


--
-- Name: idx_non_approved_scheduler_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_created_at ON public.non_approved_payment_scheduler USING btree (created_at DESC);


--
-- Name: idx_non_approved_scheduler_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_created_by ON public.non_approved_payment_scheduler USING btree (created_by);


--
-- Name: idx_non_approved_scheduler_expense_scheduler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_expense_scheduler_id ON public.non_approved_payment_scheduler USING btree (expense_scheduler_id) WHERE (expense_scheduler_id IS NOT NULL);


--
-- Name: idx_non_approved_scheduler_schedule_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_non_approved_scheduler_schedule_type ON public.non_approved_payment_scheduler USING btree (schedule_type);


--
-- Name: idx_notification_attachments_notification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_attachments_notification_id ON public.notification_attachments USING btree (notification_id);


--
-- Name: idx_notification_attachments_uploaded_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_attachments_uploaded_by ON public.notification_attachments USING btree (uploaded_by);


--
-- Name: idx_notification_read_states_notification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_read_states_notification_id ON public.notification_read_states USING btree (notification_id);


--
-- Name: idx_notification_read_states_notification_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_read_states_notification_user ON public.notification_read_states USING btree (notification_id, user_id);


--
-- Name: idx_notification_read_states_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_read_states_user_id ON public.notification_read_states USING btree (user_id);


--
-- Name: idx_notification_recipients_delivery_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_recipients_delivery_status ON public.notification_recipients USING btree (delivery_status) WHERE ((delivery_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('failed'::character varying)::text]));


--
-- Name: idx_notifications_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_created_at ON public.notifications USING btree (created_at DESC);


--
-- Name: idx_offer_bundles_offer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_bundles_offer_id ON public.offer_bundles USING btree (offer_id);


--
-- Name: idx_offer_cart_tiers_amount_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_cart_tiers_amount_range ON public.offer_cart_tiers USING btree (min_amount, max_amount);


--
-- Name: idx_offer_cart_tiers_offer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_cart_tiers_offer_id ON public.offer_cart_tiers USING btree (offer_id);


--
-- Name: idx_offer_products_active_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_products_active_lookup ON public.offer_products USING btree (offer_id, product_id);


--
-- Name: idx_offer_products_is_variation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_products_is_variation ON public.offer_products USING btree (is_part_of_variation_group) WHERE (is_part_of_variation_group = true);


--
-- Name: idx_offer_products_offer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_products_offer_id ON public.offer_products USING btree (offer_id);


--
-- Name: idx_offer_products_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_products_product_id ON public.offer_products USING btree (product_id);


--
-- Name: idx_offer_products_variation_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_products_variation_group_id ON public.offer_products USING btree (variation_group_id) WHERE (variation_group_id IS NOT NULL);


--
-- Name: idx_offer_products_variation_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_products_variation_parent ON public.offer_products USING btree (variation_parent_barcode) WHERE (variation_parent_barcode IS NOT NULL);


--
-- Name: idx_offer_usage_logs_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_usage_logs_customer_id ON public.offer_usage_logs USING btree (customer_id);


--
-- Name: idx_offer_usage_logs_offer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_usage_logs_offer_id ON public.offer_usage_logs USING btree (offer_id);


--
-- Name: idx_offer_usage_logs_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_usage_logs_order_id ON public.offer_usage_logs USING btree (order_id);


--
-- Name: idx_offer_usage_logs_order_offer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_usage_logs_order_offer ON public.offer_usage_logs USING btree (order_id, offer_id);


--
-- Name: idx_offer_usage_logs_used_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offer_usage_logs_used_at ON public.offer_usage_logs USING btree (used_at DESC);


--
-- Name: idx_offers_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offers_branch_id ON public.offers USING btree (branch_id);


--
-- Name: idx_offers_date_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offers_date_range ON public.offers USING btree (start_date, end_date);


--
-- Name: idx_offers_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offers_is_active ON public.offers USING btree (is_active);


--
-- Name: idx_offers_service_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offers_service_type ON public.offers USING btree (service_type);


--
-- Name: idx_offers_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offers_type ON public.offers USING btree (type);


--
-- Name: idx_official_holidays_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_official_holidays_date ON public.official_holidays USING btree (holiday_date);


--
-- Name: idx_order_audit_logs_action_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_audit_logs_action_type ON public.order_audit_logs USING btree (action_type);


--
-- Name: idx_order_audit_logs_assigned_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_audit_logs_assigned_user ON public.order_audit_logs USING btree (assigned_user_id);


--
-- Name: idx_order_audit_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_audit_logs_created_at ON public.order_audit_logs USING btree (created_at DESC);


--
-- Name: idx_order_audit_logs_order_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_audit_logs_order_action ON public.order_audit_logs USING btree (order_id, action_type);


--
-- Name: idx_order_audit_logs_order_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_audit_logs_order_created ON public.order_audit_logs USING btree (order_id, created_at DESC);


--
-- Name: idx_order_audit_logs_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_audit_logs_order_id ON public.order_audit_logs USING btree (order_id);


--
-- Name: idx_order_audit_logs_performed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_audit_logs_performed_by ON public.order_audit_logs USING btree (performed_by);


--
-- Name: idx_order_items_bundle_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_bundle_id ON public.order_items USING btree (bundle_id);


--
-- Name: idx_order_items_item_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_item_type ON public.order_items USING btree (item_type);


--
-- Name: idx_order_items_offer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_offer_id ON public.order_items USING btree (offer_id);


--
-- Name: idx_order_items_order_bundle; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_order_bundle ON public.order_items USING btree (order_id, bundle_id);


--
-- Name: idx_order_items_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_order_id ON public.order_items USING btree (order_id);


--
-- Name: idx_order_items_order_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_order_product ON public.order_items USING btree (order_id, product_id);


--
-- Name: idx_order_items_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_product_id ON public.order_items USING btree (product_id);


--
-- Name: idx_order_items_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_unit_id ON public.order_items USING btree (unit_id);


--
-- Name: idx_orders_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_branch_id ON public.orders USING btree (branch_id);


--
-- Name: idx_orders_branch_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_branch_status ON public.orders USING btree (branch_id, order_status);


--
-- Name: idx_orders_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_created_at ON public.orders USING btree (created_at DESC);


--
-- Name: idx_orders_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_customer_id ON public.orders USING btree (customer_id);


--
-- Name: idx_orders_customer_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_customer_status ON public.orders USING btree (customer_id, order_status);


--
-- Name: idx_orders_delivery_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_delivery_person_id ON public.orders USING btree (delivery_person_id);


--
-- Name: idx_orders_fulfillment_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_fulfillment_method ON public.orders USING btree (fulfillment_method);


--
-- Name: idx_orders_order_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_order_number ON public.orders USING btree (order_number);


--
-- Name: idx_orders_order_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_order_status ON public.orders USING btree (order_status);


--
-- Name: idx_orders_payment_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_payment_status ON public.orders USING btree (payment_status);


--
-- Name: idx_orders_picker_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_picker_id ON public.orders USING btree (picker_id);


--
-- Name: idx_orders_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_status_created ON public.orders USING btree (order_status, created_at DESC);


--
-- Name: idx_password_history_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_password_history_user_created ON public.user_password_history USING btree (user_id, created_at DESC);


--
-- Name: idx_payment_entries_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_entries_party ON public.lease_rent_payment_entries USING btree (party_type, party_id, period_num, column_name);


--
-- Name: idx_payments_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_party ON public.lease_rent_payments USING btree (party_type, party_id);


--
-- Name: idx_payments_party_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_payments_party_period ON public.lease_rent_payments USING btree (party_type, party_id, period_num);


--
-- Name: idx_pos_deduction_transfers_applied; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pos_deduction_transfers_applied ON public.pos_deduction_transfers USING btree (applied);


--
-- Name: idx_pos_deduction_transfers_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pos_deduction_transfers_branch ON public.pos_deduction_transfers USING btree (branch_id);


--
-- Name: idx_pos_deduction_transfers_cashier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pos_deduction_transfers_cashier ON public.pos_deduction_transfers USING btree (cashier_user_id);


--
-- Name: idx_pos_deduction_transfers_date_closed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pos_deduction_transfers_date_closed ON public.pos_deduction_transfers USING btree (date_closed_box);


--
-- Name: idx_privilege_cards_branch_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_privilege_cards_branch_branch_id ON public.privilege_cards_branch USING btree (branch_id);


--
-- Name: idx_privilege_cards_branch_card_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_privilege_cards_branch_card_number ON public.privilege_cards_branch USING btree (card_number);


--
-- Name: idx_privilege_cards_branch_composite; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_privilege_cards_branch_composite ON public.privilege_cards_branch USING btree (branch_id, card_number);


--
-- Name: idx_privilege_cards_master_card_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_privilege_cards_master_card_number ON public.privilege_cards_master USING btree (card_number);


--
-- Name: idx_processed_fingerprint_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_processed_fingerprint_branch_id ON public.processed_fingerprint_transactions USING btree (branch_id);


--
-- Name: idx_processed_fingerprint_center_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_processed_fingerprint_center_id ON public.processed_fingerprint_transactions USING btree (center_id);


--
-- Name: idx_processed_fingerprint_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_processed_fingerprint_employee_id ON public.processed_fingerprint_transactions USING btree (employee_id);


--
-- Name: idx_processed_fingerprint_punch_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_processed_fingerprint_punch_date ON public.processed_fingerprint_transactions USING btree (punch_date);


--
-- Name: idx_product_categories_display_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_categories_display_order ON public.product_categories USING btree (display_order);


--
-- Name: idx_product_categories_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_categories_is_active ON public.product_categories USING btree (is_active);


--
-- Name: idx_product_request_bt_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_bt_created ON public.product_request_bt USING btree (created_at);


--
-- Name: idx_product_request_bt_from_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_bt_from_branch ON public.product_request_bt USING btree (from_branch_id);


--
-- Name: idx_product_request_bt_requester; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_bt_requester ON public.product_request_bt USING btree (requester_user_id);


--
-- Name: idx_product_request_bt_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_bt_status ON public.product_request_bt USING btree (status);


--
-- Name: idx_product_request_bt_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_bt_target ON public.product_request_bt USING btree (target_user_id);


--
-- Name: idx_product_request_bt_to_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_bt_to_branch ON public.product_request_bt USING btree (to_branch_id);


--
-- Name: idx_product_request_po_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_po_branch ON public.product_request_po USING btree (from_branch_id);


--
-- Name: idx_product_request_po_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_po_created ON public.product_request_po USING btree (created_at);


--
-- Name: idx_product_request_po_requester; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_po_requester ON public.product_request_po USING btree (requester_user_id);


--
-- Name: idx_product_request_po_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_po_status ON public.product_request_po USING btree (status);


--
-- Name: idx_product_request_po_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_po_target ON public.product_request_po USING btree (target_user_id);


--
-- Name: idx_product_request_st_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_st_branch ON public.product_request_st USING btree (branch_id);


--
-- Name: idx_product_request_st_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_st_created ON public.product_request_st USING btree (created_at);


--
-- Name: idx_product_request_st_requester; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_st_requester ON public.product_request_st USING btree (requester_user_id);


--
-- Name: idx_product_request_st_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_st_status ON public.product_request_st USING btree (status);


--
-- Name: idx_product_request_st_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_request_st_target ON public.product_request_st USING btree (target_user_id);


--
-- Name: idx_product_units_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_units_is_active ON public.product_units USING btree (is_active);


--
-- Name: idx_products_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_barcode ON public.products USING btree (barcode);


--
-- Name: idx_products_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_category_id ON public.products USING btree (category_id);


--
-- Name: idx_products_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_created_at ON public.products USING btree (created_at);


--
-- Name: idx_products_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_is_active ON public.products USING btree (is_active);


--
-- Name: idx_products_is_customer_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_is_customer_product ON public.products USING btree (is_customer_product);


--
-- Name: idx_products_is_variation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_is_variation ON public.products USING btree (is_variation);


--
-- Name: idx_products_parent_product_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_parent_product_barcode ON public.products USING btree (parent_product_barcode);


--
-- Name: idx_products_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_unit_id ON public.products USING btree (unit_id);


--
-- Name: idx_purchase_voucher_items_pv_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_voucher_items_pv_id ON public.purchase_voucher_items USING btree (purchase_voucher_id);


--
-- Name: idx_purchase_voucher_items_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_voucher_items_status ON public.purchase_voucher_items USING btree (status);


--
-- Name: idx_purchase_vouchers_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_vouchers_created_at ON public.purchase_vouchers USING btree (created_at);


--
-- Name: idx_purchase_vouchers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_vouchers_status ON public.purchase_vouchers USING btree (status);


--
-- Name: idx_push_subscriptions_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_subscriptions_active ON public.push_subscriptions USING btree (user_id, is_active) WHERE (is_active = true);


--
-- Name: idx_push_subscriptions_customer_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_subscriptions_customer_active ON public.push_subscriptions USING btree (customer_id, is_active) WHERE ((is_active = true) AND (customer_id IS NOT NULL));


--
-- Name: idx_push_subscriptions_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_subscriptions_customer_id ON public.push_subscriptions USING btree (customer_id) WHERE (customer_id IS NOT NULL);


--
-- Name: idx_push_subscriptions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_subscriptions_user_id ON public.push_subscriptions USING btree (user_id);


--
-- Name: idx_pvi_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_approver_id ON public.purchase_voucher_items USING btree (approver_id);


--
-- Name: idx_pvi_close_bill_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_close_bill_number ON public.purchase_voucher_items USING btree (close_bill_number);


--
-- Name: idx_pvi_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_created_at ON public.purchase_voucher_items USING btree (created_at);


--
-- Name: idx_pvi_issued_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_issued_by ON public.purchase_voucher_items USING btree (issued_by);


--
-- Name: idx_pvi_issued_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_issued_to ON public.purchase_voucher_items USING btree (issued_to);


--
-- Name: idx_pvi_pending_stock_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_pending_stock_location ON public.purchase_voucher_items USING btree (pending_stock_location);


--
-- Name: idx_pvi_pending_stock_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_pending_stock_person ON public.purchase_voucher_items USING btree (pending_stock_person);


--
-- Name: idx_pvi_purchase_voucher_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_purchase_voucher_id ON public.purchase_voucher_items USING btree (purchase_voucher_id);


--
-- Name: idx_pvi_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_status ON public.purchase_voucher_items USING btree (status);


--
-- Name: idx_pvi_stock_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_stock_location ON public.purchase_voucher_items USING btree (stock_location);


--
-- Name: idx_pvi_stock_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pvi_stock_person ON public.purchase_voucher_items USING btree (stock_person);


--
-- Name: idx_quick_task_assignments_assignment_id_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_assignments_assignment_id_status ON public.quick_task_assignments USING btree (quick_task_id, status);


--
-- Name: idx_quick_task_assignments_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_assignments_created_at ON public.quick_task_assignments USING btree (created_at);


--
-- Name: idx_quick_task_assignments_require_erp_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_assignments_require_erp_reference ON public.quick_task_assignments USING btree (require_erp_reference) WHERE (require_erp_reference = true);


--
-- Name: idx_quick_task_assignments_require_photo_upload; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_assignments_require_photo_upload ON public.quick_task_assignments USING btree (require_photo_upload) WHERE (require_photo_upload = true);


--
-- Name: idx_quick_task_assignments_require_task_finished; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_assignments_require_task_finished ON public.quick_task_assignments USING btree (require_task_finished);


--
-- Name: idx_quick_task_assignments_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_assignments_status ON public.quick_task_assignments USING btree (status);


--
-- Name: idx_quick_task_assignments_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_assignments_task ON public.quick_task_assignments USING btree (quick_task_id);


--
-- Name: idx_quick_task_assignments_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_assignments_user ON public.quick_task_assignments USING btree (assigned_to_user_id);


--
-- Name: idx_quick_task_comments_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_comments_created_by ON public.quick_task_comments USING btree (created_by);


--
-- Name: idx_quick_task_comments_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_comments_task ON public.quick_task_comments USING btree (quick_task_id);


--
-- Name: idx_quick_task_completions_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_completions_assignment ON public.quick_task_completions USING btree (assignment_id);


--
-- Name: idx_quick_task_completions_completed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_completions_completed_by ON public.quick_task_completions USING btree (completed_by_user_id);


--
-- Name: idx_quick_task_completions_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_completions_created_at ON public.quick_task_completions USING btree (created_at DESC);


--
-- Name: idx_quick_task_completions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_completions_status ON public.quick_task_completions USING btree (completion_status);


--
-- Name: idx_quick_task_completions_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_completions_task ON public.quick_task_completions USING btree (quick_task_id);


--
-- Name: idx_quick_task_completions_verified_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_completions_verified_by ON public.quick_task_completions USING btree (verified_by_user_id) WHERE (verified_by_user_id IS NOT NULL);


--
-- Name: idx_quick_task_files_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_files_task ON public.quick_task_files USING btree (quick_task_id);


--
-- Name: idx_quick_task_files_uploaded_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_files_uploaded_by ON public.quick_task_files USING btree (uploaded_by);


--
-- Name: idx_quick_task_user_preferences_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_user_preferences_branch ON public.quick_task_user_preferences USING btree (default_branch_id);


--
-- Name: idx_quick_task_user_preferences_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_task_user_preferences_user ON public.quick_task_user_preferences USING btree (user_id);


--
-- Name: idx_quick_tasks_assigned_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_assigned_by ON public.quick_tasks USING btree (assigned_by);


--
-- Name: idx_quick_tasks_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_branch ON public.quick_tasks USING btree (assigned_to_branch_id);


--
-- Name: idx_quick_tasks_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_created_at ON public.quick_tasks USING btree (created_at);


--
-- Name: idx_quick_tasks_deadline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_deadline ON public.quick_tasks USING btree (deadline_datetime);


--
-- Name: idx_quick_tasks_incident_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_incident_id ON public.quick_tasks USING btree (incident_id);


--
-- Name: idx_quick_tasks_issue_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_issue_type ON public.quick_tasks USING btree (issue_type);


--
-- Name: idx_quick_tasks_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_order_id ON public.quick_tasks USING btree (order_id);


--
-- Name: idx_quick_tasks_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_priority ON public.quick_tasks USING btree (priority);


--
-- Name: idx_quick_tasks_product_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_product_request_id ON public.quick_tasks USING btree (product_request_id);


--
-- Name: idx_quick_tasks_product_request_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_product_request_type ON public.quick_tasks USING btree (product_request_type);


--
-- Name: idx_quick_tasks_require_erp_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_require_erp_reference ON public.quick_tasks USING btree (require_erp_reference) WHERE (require_erp_reference = true);


--
-- Name: idx_quick_tasks_require_photo_upload; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_require_photo_upload ON public.quick_tasks USING btree (require_photo_upload) WHERE (require_photo_upload = true);


--
-- Name: idx_quick_tasks_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quick_tasks_status ON public.quick_tasks USING btree (status);


--
-- Name: idx_receiving_records_accountant_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_accountant_user_id ON public.receiving_records USING btree (accountant_user_id);


--
-- Name: idx_receiving_records_bank_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_bank_name ON public.receiving_records USING btree (bank_name);


--
-- Name: idx_receiving_records_bill_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_bill_amount ON public.receiving_records USING btree (bill_amount);


--
-- Name: idx_receiving_records_bill_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_bill_date ON public.receiving_records USING btree (bill_date);


--
-- Name: idx_receiving_records_bill_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_bill_number ON public.receiving_records USING btree (bill_number);


--
-- Name: idx_receiving_records_bill_vat_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_bill_vat_number ON public.receiving_records USING btree (bill_vat_number);


--
-- Name: idx_receiving_records_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_branch_id ON public.receiving_records USING btree (branch_id);


--
-- Name: idx_receiving_records_branch_manager_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_branch_manager_user_id ON public.receiving_records USING btree (branch_manager_user_id);


--
-- Name: idx_receiving_records_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_created_at ON public.receiving_records USING btree (created_at);


--
-- Name: idx_receiving_records_credit_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_credit_period ON public.receiving_records USING btree (credit_period);


--
-- Name: idx_receiving_records_damage_erp_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_damage_erp_document_number ON public.receiving_records USING btree (damage_erp_document_number);


--
-- Name: idx_receiving_records_damage_vendor_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_damage_vendor_document_number ON public.receiving_records USING btree (damage_vendor_document_number);


--
-- Name: idx_receiving_records_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_due_date ON public.receiving_records USING btree (due_date);


--
-- Name: idx_receiving_records_erp_purchase_invoice_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_erp_purchase_invoice_reference ON public.receiving_records USING btree (erp_purchase_invoice_reference);


--
-- Name: idx_receiving_records_erp_purchase_invoice_uploaded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_erp_purchase_invoice_uploaded ON public.receiving_records USING btree (erp_purchase_invoice_uploaded);


--
-- Name: idx_receiving_records_expired_erp_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_expired_erp_document_number ON public.receiving_records USING btree (expired_erp_document_number);


--
-- Name: idx_receiving_records_expired_vendor_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_expired_vendor_document_number ON public.receiving_records USING btree (expired_vendor_document_number);


--
-- Name: idx_receiving_records_final_bill_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_final_bill_amount ON public.receiving_records USING btree (final_bill_amount);


--
-- Name: idx_receiving_records_iban; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_iban ON public.receiving_records USING btree (iban);


--
-- Name: idx_receiving_records_inventory_manager_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_inventory_manager_user_id ON public.receiving_records USING btree (inventory_manager_user_id);


--
-- Name: idx_receiving_records_near_expiry_erp_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_near_expiry_erp_document_number ON public.receiving_records USING btree (near_expiry_erp_document_number);


--
-- Name: idx_receiving_records_near_expiry_vendor_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_near_expiry_vendor_document_number ON public.receiving_records USING btree (near_expiry_vendor_document_number);


--
-- Name: idx_receiving_records_night_supervisor_user_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_night_supervisor_user_ids ON public.receiving_records USING gin (night_supervisor_user_ids);


--
-- Name: idx_receiving_records_original_bill_uploaded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_original_bill_uploaded ON public.receiving_records USING btree (original_bill_uploaded);


--
-- Name: idx_receiving_records_original_bill_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_original_bill_url ON public.receiving_records USING btree (original_bill_url);


--
-- Name: idx_receiving_records_over_stock_erp_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_over_stock_erp_document_number ON public.receiving_records USING btree (over_stock_erp_document_number);


--
-- Name: idx_receiving_records_over_stock_vendor_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_over_stock_vendor_document_number ON public.receiving_records USING btree (over_stock_vendor_document_number);


--
-- Name: idx_receiving_records_payment_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_payment_method ON public.receiving_records USING btree (payment_method);


--
-- Name: idx_receiving_records_pr_excel_file_uploaded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_pr_excel_file_uploaded ON public.receiving_records USING btree (pr_excel_file_uploaded);


--
-- Name: idx_receiving_records_pr_excel_file_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_pr_excel_file_url ON public.receiving_records USING btree (pr_excel_file_url) WHERE (pr_excel_file_url IS NOT NULL);


--
-- Name: idx_receiving_records_purchasing_manager_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_purchasing_manager_user_id ON public.receiving_records USING btree (purchasing_manager_user_id);


--
-- Name: idx_receiving_records_shelf_stocker_user_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_shelf_stocker_user_ids ON public.receiving_records USING gin (shelf_stocker_user_ids);


--
-- Name: idx_receiving_records_total_return_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_total_return_amount ON public.receiving_records USING btree (total_return_amount);


--
-- Name: idx_receiving_records_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_updated_at ON public.receiving_records USING btree (updated_at DESC);


--
-- Name: idx_receiving_records_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_user_id ON public.receiving_records USING btree (user_id);


--
-- Name: idx_receiving_records_vat_numbers_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_vat_numbers_match ON public.receiving_records USING btree (vat_numbers_match);


--
-- Name: idx_receiving_records_vendor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_vendor_id ON public.receiving_records USING btree (vendor_id);


--
-- Name: idx_receiving_records_vendor_vat_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_vendor_vat_number ON public.receiving_records USING btree (vendor_vat_number);


--
-- Name: idx_receiving_records_warehouse_handler_user_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_records_warehouse_handler_user_ids ON public.receiving_records USING gin (warehouse_handler_user_ids);


--
-- Name: idx_receiving_task_templates_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_task_templates_priority ON public.receiving_task_templates USING btree (priority);


--
-- Name: idx_receiving_task_templates_role_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_task_templates_role_type ON public.receiving_task_templates USING btree (role_type);


--
-- Name: idx_receiving_tasks_assigned_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_assigned_user_id ON public.receiving_tasks USING btree (assigned_user_id);


--
-- Name: idx_receiving_tasks_completion_photo_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_completion_photo_url ON public.receiving_tasks USING btree (completion_photo_url) WHERE (completion_photo_url IS NOT NULL);


--
-- Name: idx_receiving_tasks_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_created_at ON public.receiving_tasks USING btree (created_at DESC);


--
-- Name: idx_receiving_tasks_receiving_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_receiving_record_id ON public.receiving_tasks USING btree (receiving_record_id);


--
-- Name: idx_receiving_tasks_record_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_record_role ON public.receiving_tasks USING btree (receiving_record_id, role_type);


--
-- Name: idx_receiving_tasks_role_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_role_type ON public.receiving_tasks USING btree (role_type);


--
-- Name: idx_receiving_tasks_status_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_status_role ON public.receiving_tasks USING btree (task_status, role_type);


--
-- Name: idx_receiving_tasks_task_completed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_task_completed ON public.receiving_tasks USING btree (task_completed);


--
-- Name: idx_receiving_tasks_task_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_task_status ON public.receiving_tasks USING btree (task_status);


--
-- Name: idx_receiving_tasks_template_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_template_id ON public.receiving_tasks USING btree (template_id);


--
-- Name: idx_receiving_tasks_user_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_user_role ON public.receiving_tasks USING btree (assigned_user_id, role_type);


--
-- Name: idx_receiving_tasks_user_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_tasks_user_status ON public.receiving_tasks USING btree (assigned_user_id, task_status);


--
-- Name: idx_receiving_user_defaults_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_user_defaults_branch_id ON public.receiving_user_defaults USING btree (default_branch_id);


--
-- Name: idx_receiving_user_defaults_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receiving_user_defaults_user_id ON public.receiving_user_defaults USING btree (user_id);


--
-- Name: idx_recurring_schedules_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_schedules_active ON public.recurring_assignment_schedules USING btree (is_active, repeat_type);


--
-- Name: idx_recurring_schedules_assignment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_schedules_assignment_id ON public.recurring_assignment_schedules USING btree (assignment_id);


--
-- Name: idx_recurring_schedules_next_execution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_schedules_next_execution ON public.recurring_assignment_schedules USING btree (next_execution_at, is_active) WHERE (is_active = true);


--
-- Name: idx_regular_shift_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_regular_shift_created_at ON public.regular_shift USING btree (created_at);


--
-- Name: idx_regular_shift_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_regular_shift_updated_at ON public.regular_shift USING btree (updated_at);


--
-- Name: idx_requesters_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requesters_name ON public.requesters USING btree (requester_name);


--
-- Name: idx_requesters_requester_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requesters_requester_id ON public.requesters USING btree (requester_id);


--
-- Name: idx_requisitions_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requisitions_branch ON public.expense_requisitions USING btree (branch_id);


--
-- Name: idx_requisitions_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requisitions_created_at ON public.expense_requisitions USING btree (created_at DESC);


--
-- Name: idx_requisitions_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requisitions_number ON public.expense_requisitions USING btree (requisition_number);


--
-- Name: idx_requisitions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requisitions_status ON public.expense_requisitions USING btree (status);


--
-- Name: idx_shelf_paper_fonts_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shelf_paper_fonts_created_by ON public.shelf_paper_fonts USING btree (created_by);


--
-- Name: idx_shelf_paper_fonts_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shelf_paper_fonts_name ON public.shelf_paper_fonts USING btree (name);


--
-- Name: idx_shelf_paper_templates_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shelf_paper_templates_created_at ON public.shelf_paper_templates USING btree (created_at DESC);


--
-- Name: idx_shelf_paper_templates_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shelf_paper_templates_created_by ON public.shelf_paper_templates USING btree (created_by);


--
-- Name: idx_shelf_paper_templates_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shelf_paper_templates_is_active ON public.shelf_paper_templates USING btree (is_active);


--
-- Name: idx_sidebar_buttons_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sidebar_buttons_active ON public.sidebar_buttons USING btree (is_active);


--
-- Name: idx_sidebar_buttons_main; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sidebar_buttons_main ON public.sidebar_buttons USING btree (main_section_id);


--
-- Name: idx_sidebar_buttons_sub; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sidebar_buttons_sub ON public.sidebar_buttons USING btree (subsection_id);


--
-- Name: idx_social_links_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_social_links_branch_id ON public.social_links USING btree (branch_id);


--
-- Name: idx_special_changes_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_special_changes_dates ON public.lease_rent_special_changes USING btree (effective_from, effective_until);


--
-- Name: idx_special_changes_party; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_special_changes_party ON public.lease_rent_special_changes USING btree (party_type, party_id);


--
-- Name: idx_special_shift_date_wise_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_special_shift_date_wise_date ON public.special_shift_date_wise USING btree (shift_date);


--
-- Name: idx_special_shift_date_wise_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_special_shift_date_wise_employee_id ON public.special_shift_date_wise USING btree (employee_id);


--
-- Name: idx_special_shift_weekday_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_special_shift_weekday_created_at ON public.special_shift_weekday USING btree (created_at);


--
-- Name: idx_special_shift_weekday_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_special_shift_weekday_employee_id ON public.special_shift_weekday USING btree (employee_id);


--
-- Name: idx_special_shift_weekday_weekday; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_special_shift_weekday_weekday ON public.special_shift_weekday USING btree (weekday);


--
-- Name: idx_surprise_box_plays_bill_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_surprise_box_plays_bill_number ON public.surprise_box_plays USING btree (bill_number);


--
-- Name: idx_surprise_box_plays_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_surprise_box_plays_created_at ON public.surprise_box_plays USING btree (created_at);


--
-- Name: idx_surprise_box_plays_voucher_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_surprise_box_plays_voucher_code ON public.surprise_box_plays USING btree (voucher_code);


--
-- Name: idx_surprise_box_vouchers_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_surprise_box_vouchers_code ON public.surprise_box_vouchers USING btree (code);


--
-- Name: idx_surprise_box_vouchers_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_surprise_box_vouchers_expires_at ON public.surprise_box_vouchers USING btree (expires_at);


--
-- Name: idx_surprise_box_vouchers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_surprise_box_vouchers_status ON public.surprise_box_vouchers USING btree (status);


--
-- Name: idx_system_api_keys_service_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_api_keys_service_name ON public.system_api_keys USING btree (service_name);


--
-- Name: idx_task_assignments_assigned_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_assigned_by ON public.task_assignments USING btree (assigned_by);


--
-- Name: idx_task_assignments_assigned_to_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_assigned_to_branch_id ON public.task_assignments USING btree (assigned_to_branch_id);


--
-- Name: idx_task_assignments_assigned_to_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_assigned_to_user_id ON public.task_assignments USING btree (assigned_to_user_id);


--
-- Name: idx_task_assignments_assignment_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_assignment_type ON public.task_assignments USING btree (assignment_type);


--
-- Name: idx_task_assignments_deadline_datetime; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_deadline_datetime ON public.task_assignments USING btree (deadline_datetime) WHERE (deadline_datetime IS NOT NULL);


--
-- Name: idx_task_assignments_overdue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_overdue ON public.task_assignments USING btree (deadline_datetime, status) WHERE ((deadline_datetime IS NOT NULL) AND (status <> ALL (ARRAY['completed'::text, 'cancelled'::text])));


--
-- Name: idx_task_assignments_reassignable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_reassignable ON public.task_assignments USING btree (is_reassignable, status) WHERE (is_reassignable = true);


--
-- Name: idx_task_assignments_recurring; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_recurring ON public.task_assignments USING btree (is_recurring, status) WHERE (is_recurring = true);


--
-- Name: idx_task_assignments_schedule_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_schedule_date ON public.task_assignments USING btree (schedule_date) WHERE (schedule_date IS NOT NULL);


--
-- Name: idx_task_assignments_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_status ON public.task_assignments USING btree (status);


--
-- Name: idx_task_assignments_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_assignments_task_id ON public.task_assignments USING btree (task_id);


--
-- Name: idx_task_completions_assignment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_assignment_id ON public.task_completions USING btree (assignment_id);


--
-- Name: idx_task_completions_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_completed_at ON public.task_completions USING btree (completed_at DESC);


--
-- Name: idx_task_completions_completed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_completed_by ON public.task_completions USING btree (completed_by);


--
-- Name: idx_task_completions_completed_by_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_completed_by_branch_id ON public.task_completions USING btree (completed_by_branch_id);


--
-- Name: idx_task_completions_erp_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_erp_reference ON public.task_completions USING btree (erp_reference_completed);


--
-- Name: idx_task_completions_photo_uploaded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_photo_uploaded ON public.task_completions USING btree (photo_uploaded_completed);


--
-- Name: idx_task_completions_photo_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_photo_url ON public.task_completions USING btree (completion_photo_url) WHERE (completion_photo_url IS NOT NULL);


--
-- Name: idx_task_completions_task_finished; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_task_finished ON public.task_completions USING btree (task_finished_completed);


--
-- Name: idx_task_completions_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_completions_task_id ON public.task_completions USING btree (task_id);


--
-- Name: idx_task_images_attachment_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_images_attachment_type ON public.task_images USING btree (attachment_type);


--
-- Name: idx_task_images_image_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_images_image_type ON public.task_images USING btree (image_type);


--
-- Name: idx_task_images_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_images_task_id ON public.task_images USING btree (task_id);


--
-- Name: idx_task_images_uploaded_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_images_uploaded_by ON public.task_images USING btree (uploaded_by);


--
-- Name: idx_task_reminder_logs_quick_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_reminder_logs_quick_task ON public.task_reminder_logs USING btree (quick_task_assignment_id) WHERE (quick_task_assignment_id IS NOT NULL);


--
-- Name: idx_task_reminder_logs_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_reminder_logs_sent_at ON public.task_reminder_logs USING btree (reminder_sent_at);


--
-- Name: idx_task_reminder_logs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_reminder_logs_status ON public.task_reminder_logs USING btree (status);


--
-- Name: idx_task_reminder_logs_task_assignment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_reminder_logs_task_assignment ON public.task_reminder_logs USING btree (task_assignment_id) WHERE (task_assignment_id IS NOT NULL);


--
-- Name: idx_task_reminder_logs_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_task_reminder_logs_user ON public.task_reminder_logs USING btree (assigned_to_user_id);


--
-- Name: idx_tasks_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_created_at ON public.tasks USING btree (created_at DESC);


--
-- Name: idx_tasks_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_created_by ON public.tasks USING btree (created_by);


--
-- Name: idx_tasks_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_deleted_at ON public.tasks USING btree (deleted_at);


--
-- Name: idx_tasks_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_due_date ON public.tasks USING btree (due_date) WHERE (due_date IS NOT NULL);


--
-- Name: idx_tasks_metadata; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_metadata ON public.tasks USING gin (metadata);


--
-- Name: idx_tasks_search_vector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_search_vector ON public.tasks USING gin (search_vector);


--
-- Name: idx_tasks_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);


--
-- Name: idx_user_audit_logs_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_audit_logs_action ON public.user_audit_logs USING btree (action);


--
-- Name: idx_user_audit_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_audit_logs_created_at ON public.user_audit_logs USING btree (created_at);


--
-- Name: idx_user_audit_logs_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_audit_logs_user_id ON public.user_audit_logs USING btree (user_id);


--
-- Name: idx_user_device_sessions_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_device_sessions_active ON public.user_device_sessions USING btree (is_active);


--
-- Name: idx_user_device_sessions_device_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_device_sessions_device_id ON public.user_device_sessions USING btree (device_id);


--
-- Name: idx_user_device_sessions_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_device_sessions_expires_at ON public.user_device_sessions USING btree (expires_at);


--
-- Name: idx_user_device_sessions_last_activity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_device_sessions_last_activity ON public.user_device_sessions USING btree (last_activity);


--
-- Name: idx_user_device_sessions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_device_sessions_user_id ON public.user_device_sessions USING btree (user_id);


--
-- Name: idx_user_erp_credentials_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_erp_credentials_branch_id ON public.user_erp_credentials USING btree (branch_id);


--
-- Name: idx_user_erp_credentials_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_erp_credentials_user_id ON public.user_erp_credentials USING btree (user_id);


--
-- Name: idx_user_favorite_buttons_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_favorite_buttons_employee_id ON public.user_favorite_buttons USING btree (employee_id);


--
-- Name: idx_user_favorite_buttons_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_favorite_buttons_user_id ON public.user_favorite_buttons USING btree (user_id);


--
-- Name: idx_user_mobile_theme_assignments_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_mobile_theme_assignments_theme_id ON public.user_mobile_theme_assignments USING btree (theme_id);


--
-- Name: idx_user_mobile_theme_assignments_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_mobile_theme_assignments_user_id ON public.user_mobile_theme_assignments USING btree (user_id);


--
-- Name: idx_user_sessions_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_sessions_active ON public.user_sessions USING btree (is_active);


--
-- Name: idx_user_sessions_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_sessions_token ON public.user_sessions USING btree (session_token);


--
-- Name: idx_user_sessions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_sessions_user_id ON public.user_sessions USING btree (user_id);


--
-- Name: idx_user_theme_assignments_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_theme_assignments_theme_id ON public.user_theme_assignments USING btree (theme_id);


--
-- Name: idx_user_theme_assignments_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_theme_assignments_user_id ON public.user_theme_assignments USING btree (user_id);


--
-- Name: idx_user_theme_overrides; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_theme_overrides ON public.user_mobile_theme_assignments USING btree (user_id) WHERE (color_overrides IS NOT NULL);


--
-- Name: idx_user_voice_preferences_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_voice_preferences_user_id ON public.user_voice_preferences USING btree (user_id);


--
-- Name: idx_users_ai_translation_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_ai_translation_enabled ON public.users USING btree (ai_translation_enabled);


--
-- Name: idx_users_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_branch_id ON public.users USING btree (branch_id);


--
-- Name: idx_users_branch_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_branch_lookup ON public.users USING btree (branch_id) WHERE (branch_id IS NOT NULL);


--
-- Name: idx_users_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_created_at ON public.users USING btree (created_at);


--
-- Name: idx_users_employee_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_employee_id ON public.users USING btree (employee_id);


--
-- Name: idx_users_employee_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_employee_lookup ON public.users USING btree (employee_id) WHERE (employee_id IS NOT NULL);


--
-- Name: idx_users_is_admin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_is_admin ON public.users USING btree (is_admin);


--
-- Name: idx_users_is_master_admin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_is_master_admin ON public.users USING btree (is_master_admin);


--
-- Name: idx_users_last_login; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_last_login ON public.users USING btree (last_login_at);


--
-- Name: idx_users_position_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_position_lookup ON public.users USING btree (position_id) WHERE (position_id IS NOT NULL);


--
-- Name: idx_users_quick_access; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_users_quick_access ON public.users USING btree (quick_access_code);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: idx_variation_audit_log_action_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_variation_audit_log_action_type ON public.variation_audit_log USING btree (action_type);


--
-- Name: idx_variation_audit_log_parent_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_variation_audit_log_parent_barcode ON public.variation_audit_log USING btree (parent_barcode) WHERE (parent_barcode IS NOT NULL);


--
-- Name: idx_variation_audit_log_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_variation_audit_log_timestamp ON public.variation_audit_log USING btree ("timestamp" DESC);


--
-- Name: idx_variation_audit_log_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_variation_audit_log_user_id ON public.variation_audit_log USING btree (user_id);


--
-- Name: idx_variation_audit_log_variation_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_variation_audit_log_variation_group_id ON public.variation_audit_log USING btree (variation_group_id) WHERE (variation_group_id IS NOT NULL);


--
-- Name: idx_vendor_payment_approval_requested_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_approval_requested_by ON public.vendor_payment_schedule USING btree (approval_requested_by);


--
-- Name: idx_vendor_payment_approval_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_approval_status ON public.vendor_payment_schedule USING btree (approval_status) WHERE (approval_status = 'sent_for_approval'::text);


--
-- Name: idx_vendor_payment_approved_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_approved_by ON public.vendor_payment_schedule USING btree (approved_by);


--
-- Name: idx_vendor_payment_assigned_approver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_assigned_approver ON public.vendor_payment_schedule USING btree (assigned_approver_id);


--
-- Name: idx_vendor_payment_schedule_accountant_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_accountant_user_id ON public.vendor_payment_schedule USING btree (accountant_user_id);


--
-- Name: idx_vendor_payment_schedule_adjustments; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_adjustments ON public.vendor_payment_schedule USING btree (last_adjustment_date) WHERE (last_adjustment_date IS NOT NULL);


--
-- Name: idx_vendor_payment_schedule_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_branch_id ON public.vendor_payment_schedule USING btree (branch_id);


--
-- Name: idx_vendor_payment_schedule_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_due_date ON public.vendor_payment_schedule USING btree (due_date);


--
-- Name: idx_vendor_payment_schedule_due_date_paid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_due_date_paid ON public.vendor_payment_schedule USING btree (due_date, is_paid);


--
-- Name: idx_vendor_payment_schedule_grr_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_grr_ref ON public.vendor_payment_schedule USING btree (grr_reference_number) WHERE (grr_reference_number IS NOT NULL);


--
-- Name: idx_vendor_payment_schedule_is_paid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_is_paid ON public.vendor_payment_schedule USING btree (is_paid);


--
-- Name: idx_vendor_payment_schedule_paid_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_paid_date ON public.vendor_payment_schedule USING btree (paid_date);


--
-- Name: idx_vendor_payment_schedule_pr_excel_verified; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_pr_excel_verified ON public.vendor_payment_schedule USING btree (pr_excel_verified);


--
-- Name: idx_vendor_payment_schedule_pr_excel_verified_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_pr_excel_verified_by ON public.vendor_payment_schedule USING btree (pr_excel_verified_by);


--
-- Name: idx_vendor_payment_schedule_pri_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_pri_ref ON public.vendor_payment_schedule USING btree (pri_reference_number) WHERE (pri_reference_number IS NOT NULL);


--
-- Name: idx_vendor_payment_schedule_receiving_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_receiving_record_id ON public.vendor_payment_schedule USING btree (receiving_record_id);


--
-- Name: idx_vendor_payment_schedule_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_task_id ON public.vendor_payment_schedule USING btree (task_id);


--
-- Name: idx_vendor_payment_schedule_vendor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_vendor_id ON public.vendor_payment_schedule USING btree (vendor_id);


--
-- Name: idx_vendor_payment_schedule_verification_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_schedule_verification_status ON public.vendor_payment_schedule USING btree (verification_status);


--
-- Name: idx_vendors_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_branch_id ON public.vendors USING btree (branch_id) WHERE (branch_id IS NOT NULL);


--
-- Name: idx_vendors_branch_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_branch_status ON public.vendors USING btree (branch_id, status) WHERE (branch_id IS NOT NULL);


--
-- Name: idx_vendors_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_created_at ON public.vendors USING btree (created_at);


--
-- Name: idx_vendors_erp_vendor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_erp_vendor_id ON public.vendors USING btree (erp_vendor_id);


--
-- Name: idx_vendors_payment_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_payment_method ON public.vendors USING gin (to_tsvector('english'::regconfig, payment_method));


--
-- Name: idx_vendors_payment_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_payment_priority ON public.vendors USING btree (payment_priority);


--
-- Name: idx_vendors_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_status ON public.vendors USING btree (status);


--
-- Name: idx_vendors_vat_applicable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_vat_applicable ON public.vendors USING btree (vat_applicable);


--
-- Name: idx_vendors_vendor_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendors_vendor_name ON public.vendors USING btree (vendor_name);


--
-- Name: idx_view_offer_branch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_view_offer_branch_id ON public.view_offer USING btree (branch_id);


--
-- Name: idx_view_offer_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_view_offer_dates ON public.view_offer USING btree (start_date, end_date);


--
-- Name: idx_view_offer_datetime; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_view_offer_datetime ON public.view_offer USING btree (start_date, start_time, end_date, end_time);


--
-- Name: idx_vip_redemptions_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vip_redemptions_customer_id ON public.vip_redemptions USING btree (customer_id);


--
-- Name: idx_vip_redemptions_redeemed_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vip_redemptions_redeemed_date ON public.vip_redemptions USING btree (redeemed_date);


--
-- Name: idx_vip_redemptions_whatsapp_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vip_redemptions_whatsapp_number ON public.vip_redemptions USING btree (whatsapp_number);


--
-- Name: idx_wa_auto_reply_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_auto_reply_account ON public.wa_auto_reply_triggers USING btree (wa_account_id);


--
-- Name: idx_wa_auto_reply_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_auto_reply_active ON public.wa_auto_reply_triggers USING btree (is_active);


--
-- Name: idx_wa_auto_reply_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_auto_reply_order ON public.wa_auto_reply_triggers USING btree (sort_order);


--
-- Name: idx_wa_bot_flows_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_bot_flows_account ON public.wa_bot_flows USING btree (wa_account_id);


--
-- Name: idx_wa_bot_flows_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_bot_flows_active ON public.wa_bot_flows USING btree (is_active);


--
-- Name: idx_wa_broadcast_recip_broadcast; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_broadcast_recip_broadcast ON public.wa_broadcast_recipients USING btree (broadcast_id);


--
-- Name: idx_wa_broadcast_recip_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_broadcast_recip_status ON public.wa_broadcast_recipients USING btree (status);


--
-- Name: idx_wa_broadcasts_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_broadcasts_account ON public.wa_broadcasts USING btree (wa_account_id);


--
-- Name: idx_wa_broadcasts_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_broadcasts_created ON public.wa_broadcasts USING btree (created_at DESC);


--
-- Name: idx_wa_broadcasts_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_broadcasts_status ON public.wa_broadcasts USING btree (status);


--
-- Name: idx_wa_catalog_orders_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_catalog_orders_account ON public.wa_catalog_orders USING btree (wa_account_id);


--
-- Name: idx_wa_catalog_orders_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_catalog_orders_status ON public.wa_catalog_orders USING btree (order_status);


--
-- Name: idx_wa_catalog_products_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_catalog_products_account ON public.wa_catalog_products USING btree (wa_account_id);


--
-- Name: idx_wa_catalog_products_catalog; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_catalog_products_catalog ON public.wa_catalog_products USING btree (catalog_id);


--
-- Name: idx_wa_catalog_products_sku; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_catalog_products_sku ON public.wa_catalog_products USING btree (sku);


--
-- Name: idx_wa_catalogs_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_catalogs_account ON public.wa_catalogs USING btree (wa_account_id);


--
-- Name: idx_wa_conv_account_status_lastmsg; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_conv_account_status_lastmsg ON public.wa_conversations USING btree (wa_account_id, status, last_message_at DESC);


--
-- Name: idx_wa_conversations_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_conversations_account ON public.wa_conversations USING btree (wa_account_id);


--
-- Name: idx_wa_conversations_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_conversations_customer ON public.wa_conversations USING btree (customer_id);


--
-- Name: idx_wa_conversations_last_msg; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_conversations_last_msg ON public.wa_conversations USING btree (last_message_at DESC);


--
-- Name: idx_wa_conversations_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_conversations_phone ON public.wa_conversations USING btree (customer_phone);


--
-- Name: idx_wa_conversations_sos; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_conversations_sos ON public.wa_conversations USING btree (is_sos) WHERE (is_sos = true);


--
-- Name: idx_wa_group_members_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_group_members_customer ON public.wa_contact_group_members USING btree (customer_id);


--
-- Name: idx_wa_group_members_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_group_members_group ON public.wa_contact_group_members USING btree (group_id);


--
-- Name: idx_wa_messages_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_messages_account ON public.wa_messages USING btree (wa_account_id);


--
-- Name: idx_wa_messages_conv_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_messages_conv_created ON public.wa_messages USING btree (conversation_id, created_at DESC);


--
-- Name: idx_wa_messages_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_messages_conversation ON public.wa_messages USING btree (conversation_id);


--
-- Name: idx_wa_messages_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_messages_created ON public.wa_messages USING btree (created_at DESC);


--
-- Name: idx_wa_messages_direction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_messages_direction ON public.wa_messages USING btree (direction);


--
-- Name: idx_wa_messages_wa_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_messages_wa_id ON public.wa_messages USING btree (whatsapp_message_id);


--
-- Name: idx_wa_settings_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_settings_account ON public.wa_settings USING btree (wa_account_id);


--
-- Name: idx_wa_templates_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_templates_account ON public.wa_templates USING btree (wa_account_id);


--
-- Name: idx_wa_templates_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_templates_name ON public.wa_templates USING btree (name);


--
-- Name: idx_wa_templates_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wa_templates_status ON public.wa_templates USING btree (status);


--
-- Name: idx_warning_main_category_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_warning_main_category_name_en ON public.warning_main_category USING btree (name_en);


--
-- Name: idx_warning_sub_category_main_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_warning_sub_category_main_id ON public.warning_sub_category USING btree (main_category_id);


--
-- Name: idx_warning_sub_category_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_warning_sub_category_name_en ON public.warning_sub_category USING btree (name_en);


--
-- Name: idx_warning_violation_main_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_warning_violation_main_id ON public.warning_violation USING btree (main_category_id);


--
-- Name: idx_warning_violation_name_en; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_warning_violation_name_en ON public.warning_violation USING btree (name_en);


--
-- Name: idx_warning_violation_sub_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_warning_violation_sub_id ON public.warning_violation USING btree (sub_category_id);


--
-- Name: idx_whatsapp_log_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_whatsapp_log_created ON public.whatsapp_message_log USING btree (created_at DESC);


--
-- Name: idx_whatsapp_log_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_whatsapp_log_phone ON public.whatsapp_message_log USING btree (phone_number);


--
-- Name: settlement_rules_is_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlement_rules_is_active_idx ON public.settlement_rules USING btree (is_active);


--
-- Name: settlement_rules_rule_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX settlement_rules_rule_type_idx ON public.settlement_rules USING btree (rule_type);


--
-- Name: surprise_box_settings_singleton; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX surprise_box_settings_singleton ON public.surprise_box_settings USING btree ((true));


--
-- Name: uq_products_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_products_barcode ON public.products USING btree (barcode);


--
-- Name: ux_delivery_tiers_scope_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_delivery_tiers_scope_order ON public.delivery_fee_tiers USING btree (COALESCE(branch_id, ('-1'::integer)::bigint), tier_order);


--
-- Name: wa_messages_wamid_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX wa_messages_wamid_unique ON public.wa_messages USING btree (whatsapp_message_id) WHERE ((whatsapp_message_id IS NOT NULL) AND (whatsapp_message_id <> ''::text));


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


--
-- Name: approver_branch_access approver_branch_access_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: approver_branch_access approver_branch_access_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approver_branch_access approver_branch_access_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_branch_access
    ADD CONSTRAINT approver_branch_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: approver_visibility_config approver_visibility_config_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approver_visibility_config approver_visibility_config_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: approver_visibility_config approver_visibility_config_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approver_visibility_config
    ADD CONSTRAINT approver_visibility_config_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: asset_sub_categories asset_items_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.asset_sub_categories
    ADD CONSTRAINT asset_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.asset_main_categories(id) ON DELETE CASCADE;


--
-- Name: assets assets_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: assets assets_sub_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_sub_category_id_fkey FOREIGN KEY (sub_category_id) REFERENCES public.asset_sub_categories(id) ON DELETE RESTRICT;


--
-- Name: bank_reconciliations bank_reconciliations_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_reconciliations
    ADD CONSTRAINT bank_reconciliations_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: bank_reconciliations bank_reconciliations_cashier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_reconciliations
    ADD CONSTRAINT bank_reconciliations_cashier_id_fkey FOREIGN KEY (cashier_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: bank_reconciliations bank_reconciliations_operation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_reconciliations
    ADD CONSTRAINT bank_reconciliations_operation_id_fkey FOREIGN KEY (operation_id) REFERENCES public.box_operations(id) ON DELETE CASCADE;


--
-- Name: bank_reconciliations bank_reconciliations_supervisor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_reconciliations
    ADD CONSTRAINT bank_reconciliations_supervisor_id_fkey FOREIGN KEY (supervisor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: biometric_connections biometric_connections_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biometric_connections
    ADD CONSTRAINT biometric_connections_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: bogo_offer_rules bogo_offer_rules_buy_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bogo_offer_rules
    ADD CONSTRAINT bogo_offer_rules_buy_product_id_fkey FOREIGN KEY (buy_product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: bogo_offer_rules bogo_offer_rules_get_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bogo_offer_rules
    ADD CONSTRAINT bogo_offer_rules_get_product_id_fkey FOREIGN KEY (get_product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: bogo_offer_rules bogo_offer_rules_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bogo_offer_rules
    ADD CONSTRAINT bogo_offer_rules_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: box_operations box_operations_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.box_operations
    ADD CONSTRAINT box_operations_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: box_operations box_operations_denomination_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.box_operations
    ADD CONSTRAINT box_operations_denomination_record_id_fkey FOREIGN KEY (denomination_record_id) REFERENCES public.denomination_records(id) ON DELETE CASCADE;


--
-- Name: box_operations box_operations_supervisor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.box_operations
    ADD CONSTRAINT box_operations_supervisor_id_fkey FOREIGN KEY (supervisor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: box_operations box_operations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.box_operations
    ADD CONSTRAINT box_operations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: branch_default_delivery_receivers branch_default_delivery_receivers_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_delivery_receivers
    ADD CONSTRAINT branch_default_delivery_receivers_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: branch_default_delivery_receivers branch_default_delivery_receivers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_delivery_receivers
    ADD CONSTRAINT branch_default_delivery_receivers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: branch_default_positions branch_default_positions_accountant_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_accountant_user_id_fkey FOREIGN KEY (accountant_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions branch_default_positions_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: branch_default_positions branch_default_positions_branch_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_branch_manager_user_id_fkey FOREIGN KEY (branch_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions branch_default_positions_inventory_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_inventory_manager_user_id_fkey FOREIGN KEY (inventory_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions branch_default_positions_purchasing_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_purchasing_manager_user_id_fkey FOREIGN KEY (purchasing_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_default_positions branch_default_positions_warehouse_handler_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_default_positions
    ADD CONSTRAINT branch_default_positions_warehouse_handler_user_id_fkey FOREIGN KEY (warehouse_handler_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: branch_sync_config branch_sync_config_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_sync_config
    ADD CONSTRAINT branch_sync_config_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: break_register break_register_reason_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.break_register
    ADD CONSTRAINT break_register_reason_id_fkey FOREIGN KEY (reason_id) REFERENCES public.break_reasons(id);


--
-- Name: coupon_campaigns coupon_campaigns_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_campaigns
    ADD CONSTRAINT coupon_campaigns_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: coupon_claims coupon_claims_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: coupon_claims coupon_claims_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.coupon_campaigns(id) ON DELETE CASCADE;


--
-- Name: coupon_claims coupon_claims_claimed_by_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_claimed_by_user_fkey FOREIGN KEY (claimed_by_user) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: coupon_claims coupon_claims_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_claims
    ADD CONSTRAINT coupon_claims_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.coupon_products(id) ON DELETE SET NULL;


--
-- Name: coupon_eligible_customers coupon_eligible_customers_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_eligible_customers
    ADD CONSTRAINT coupon_eligible_customers_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.coupon_campaigns(id) ON DELETE CASCADE;


--
-- Name: coupon_eligible_customers coupon_eligible_customers_imported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_eligible_customers
    ADD CONSTRAINT coupon_eligible_customers_imported_by_fkey FOREIGN KEY (imported_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: coupon_products coupon_products_campaign_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.coupon_campaigns(id) ON DELETE CASCADE;


--
-- Name: coupon_products coupon_products_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: coupon_products coupon_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_products
    ADD CONSTRAINT coupon_products_product_id_fkey FOREIGN KEY (flyer_product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: customer_access_code_history customer_access_code_history_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_access_code_history
    ADD CONSTRAINT customer_access_code_history_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: customer_access_code_history customer_access_code_history_generated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_access_code_history
    ADD CONSTRAINT customer_access_code_history_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES public.users(id);


--
-- Name: customer_app_media customer_app_media_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_app_media
    ADD CONSTRAINT customer_app_media_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id);


--
-- Name: customer_product_requests customer_product_requests_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_product_requests
    ADD CONSTRAINT customer_product_requests_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: customer_product_requests customer_product_requests_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_product_requests
    ADD CONSTRAINT customer_product_requests_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: customer_product_requests customer_product_requests_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_product_requests
    ADD CONSTRAINT customer_product_requests_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: customer_recovery_requests customer_recovery_requests_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_recovery_requests
    ADD CONSTRAINT customer_recovery_requests_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: customer_recovery_requests customer_recovery_requests_processed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_recovery_requests
    ADD CONSTRAINT customer_recovery_requests_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES public.users(id);


--
-- Name: customers customers_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: customers customers_loyalty_tier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_loyalty_tier_id_fkey FOREIGN KEY (loyalty_tier_id) REFERENCES public.loyalty_tiers(id) ON DELETE SET NULL;


--
-- Name: day_off day_off_approval_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_approval_approved_by_fkey FOREIGN KEY (approval_approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: day_off day_off_approval_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_approval_requested_by_fkey FOREIGN KEY (approval_requested_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: day_off day_off_day_off_reason_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_day_off_reason_id_fkey FOREIGN KEY (day_off_reason_id) REFERENCES public.day_off_reasons(id) ON DELETE SET NULL;


--
-- Name: day_off day_off_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off
    ADD CONSTRAINT day_off_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: day_off_weekday day_off_weekday_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_off_weekday
    ADD CONSTRAINT day_off_weekday_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: default_incident_users default_incident_users_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_incident_users
    ADD CONSTRAINT default_incident_users_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: default_incident_users default_incident_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_incident_users
    ADD CONSTRAINT default_incident_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: deleted_bundle_offers deleted_bundle_offers_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_bundle_offers
    ADD CONSTRAINT deleted_bundle_offers_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.users(id);


--
-- Name: delivery_fee_tiers delivery_fee_tiers_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_fee_tiers
    ADD CONSTRAINT delivery_fee_tiers_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: delivery_fee_tiers delivery_fee_tiers_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_fee_tiers
    ADD CONSTRAINT delivery_fee_tiers_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: delivery_fee_tiers delivery_fee_tiers_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_fee_tiers
    ADD CONSTRAINT delivery_fee_tiers_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: delivery_service_settings delivery_service_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_service_settings
    ADD CONSTRAINT delivery_service_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: denomination_records denomination_records_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_records
    ADD CONSTRAINT denomination_records_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: denomination_records denomination_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_records
    ADD CONSTRAINT denomination_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: denomination_transactions denomination_transactions_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_transactions
    ADD CONSTRAINT denomination_transactions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: denomination_transactions denomination_transactions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_transactions
    ADD CONSTRAINT denomination_transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: denomination_user_preferences denomination_user_preferences_default_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_user_preferences
    ADD CONSTRAINT denomination_user_preferences_default_branch_id_fkey FOREIGN KEY (default_branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: denomination_user_preferences denomination_user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denomination_user_preferences
    ADD CONSTRAINT denomination_user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: desktop_themes desktop_themes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.desktop_themes
    ADD CONSTRAINT desktop_themes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: employee_checklist_assignments employee_checklist_assignments_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_checklist_assignments
    ADD CONSTRAINT employee_checklist_assignments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: employee_checklist_assignments employee_checklist_assignments_checklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_checklist_assignments
    ADD CONSTRAINT employee_checklist_assignments_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES public.hr_checklists(id) ON DELETE CASCADE;


--
-- Name: employee_checklist_assignments employee_checklist_assignments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_checklist_assignments
    ADD CONSTRAINT employee_checklist_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: employee_fine_payments employee_fine_payments_processed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_fine_payments
    ADD CONSTRAINT employee_fine_payments_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: employee_official_holidays employee_official_holidays_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_official_holidays
    ADD CONSTRAINT employee_official_holidays_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: employee_official_holidays employee_official_holidays_official_holiday_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_official_holidays
    ADD CONSTRAINT employee_official_holidays_official_holiday_id_fkey FOREIGN KEY (official_holiday_id) REFERENCES public.official_holidays(id) ON DELETE CASCADE;


--
-- Name: erp_connections erp_connections_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_connections
    ADD CONSTRAINT erp_connections_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: erp_daily_sales erp_daily_sales_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.erp_daily_sales
    ADD CONSTRAINT erp_daily_sales_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: expense_requisitions expense_requisitions_expense_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_expense_category_id_fkey FOREIGN KEY (expense_category_id) REFERENCES public.expense_sub_categories(id);


--
-- Name: expense_requisitions expense_requisitions_internal_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_internal_user_id_fkey FOREIGN KEY (internal_user_id) REFERENCES public.users(id);


--
-- Name: expense_requisitions expense_requisitions_requester_ref_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT expense_requisitions_requester_ref_id_fkey FOREIGN KEY (requester_ref_id) REFERENCES public.requesters(id);


--
-- Name: expense_sub_categories expense_sub_categories_parent_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_sub_categories
    ADD CONSTRAINT expense_sub_categories_parent_category_id_fkey FOREIGN KEY (parent_category_id) REFERENCES public.expense_parent_categories(id) ON DELETE CASCADE;


--
-- Name: hr_analysed_attendance_data fk_analysed_employee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_analysed_attendance_data
    ADD CONSTRAINT fk_analysed_employee FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: button_permissions fk_button; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_permissions
    ADD CONSTRAINT fk_button FOREIGN KEY (button_id) REFERENCES public.sidebar_buttons(id) ON DELETE CASCADE;


--
-- Name: expense_requisitions fk_expense_requisitions_branch; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_requisitions
    ADD CONSTRAINT fk_expense_requisitions_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: CONSTRAINT fk_expense_requisitions_branch ON expense_requisitions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT fk_expense_requisitions_branch ON public.expense_requisitions IS 'Links expense requisitions to their branch. ON DELETE RESTRICT prevents deletion of branches with existing requisitions.';


--
-- Name: expense_scheduler fk_expense_scheduler_approver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_approver FOREIGN KEY (approver_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: expense_scheduler fk_expense_scheduler_branch; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: expense_scheduler fk_expense_scheduler_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_category FOREIGN KEY (expense_category_id) REFERENCES public.expense_sub_categories(id) ON DELETE SET NULL;


--
-- Name: expense_scheduler fk_expense_scheduler_co_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_co_user FOREIGN KEY (co_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: expense_scheduler fk_expense_scheduler_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_created_by FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: expense_scheduler fk_expense_scheduler_requisition; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense_scheduler
    ADD CONSTRAINT fk_expense_scheduler_requisition FOREIGN KEY (requisition_id) REFERENCES public.expense_requisitions(id) ON DELETE SET NULL;


--
-- Name: button_sub_sections fk_main_section; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_sub_sections
    ADD CONSTRAINT fk_main_section FOREIGN KEY (main_section_id) REFERENCES public.button_main_sections(id) ON DELETE CASCADE;


--
-- Name: sidebar_buttons fk_main_section; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_buttons
    ADD CONSTRAINT fk_main_section FOREIGN KEY (main_section_id) REFERENCES public.button_main_sections(id) ON DELETE CASCADE;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_approved_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_approved_by FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_approver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_approver FOREIGN KEY (approver_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_branch; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_category FOREIGN KEY (expense_category_id) REFERENCES public.expense_sub_categories(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_co_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_co_user FOREIGN KEY (co_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_created_by FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: non_approved_payment_scheduler fk_non_approved_scheduler_expense_scheduler; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_approved_payment_scheduler
    ADD CONSTRAINT fk_non_approved_scheduler_expense_scheduler FOREIGN KEY (expense_scheduler_id) REFERENCES public.expense_scheduler(id) ON DELETE SET NULL;


--
-- Name: notification_recipients fk_notification_recipients_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_recipients
    ADD CONSTRAINT fk_notification_recipients_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: push_subscriptions fk_push_sub_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT fk_push_sub_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: recurring_assignment_schedules fk_recurring_schedules_assignment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_assignment_schedules
    ADD CONSTRAINT fk_recurring_schedules_assignment FOREIGN KEY (assignment_id) REFERENCES public.task_assignments(id) ON DELETE CASCADE;


--
-- Name: social_links fk_social_links_branch; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_links
    ADD CONSTRAINT fk_social_links_branch FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: sidebar_buttons fk_sub_section; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_buttons
    ADD CONSTRAINT fk_sub_section FOREIGN KEY (subsection_id) REFERENCES public.button_sub_sections(id) ON DELETE CASCADE;


--
-- Name: task_assignments fk_task_assignments_reassigned_from; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT fk_task_assignments_reassigned_from FOREIGN KEY (reassigned_from) REFERENCES public.task_assignments(id) ON DELETE SET NULL;


--
-- Name: button_permissions fk_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.button_permissions
    ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: flyer_offer_products flyer_offer_products_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_offer_products
    ADD CONSTRAINT flyer_offer_products_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.flyer_offers(id) ON DELETE CASCADE;


--
-- Name: flyer_offer_products flyer_offer_products_product_barcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_offer_products
    ADD CONSTRAINT flyer_offer_products_product_barcode_fkey FOREIGN KEY (product_barcode) REFERENCES public.products(barcode) ON DELETE CASCADE;


--
-- Name: flyer_offers flyer_offers_offer_name_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_offers
    ADD CONSTRAINT flyer_offers_offer_name_id_fkey FOREIGN KEY (offer_name_id) REFERENCES public.offer_names(id) ON DELETE SET NULL;


--
-- Name: products flyer_products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.product_categories(id) ON DELETE SET NULL;


--
-- Name: products flyer_products_created_by_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_created_by_fkey1 FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: products flyer_products_modified_by_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_modified_by_fkey1 FOREIGN KEY (modified_by) REFERENCES auth.users(id);


--
-- Name: products flyer_products_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT flyer_products_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.product_units(id) ON DELETE RESTRICT;


--
-- Name: flyer_templates flyer_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_templates
    ADD CONSTRAINT flyer_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: flyer_templates flyer_templates_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyer_templates
    ADD CONSTRAINT flyer_templates_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: frontend_builds frontend_builds_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frontend_builds
    ADD CONSTRAINT frontend_builds_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id);


--
-- Name: gift_wheel_coupons gift_wheel_coupons_reward_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_wheel_coupons
    ADD CONSTRAINT gift_wheel_coupons_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES public.gift_wheel_rewards(id) ON DELETE CASCADE;


--
-- Name: gift_wheel_spins gift_wheel_spins_reward_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gift_wheel_spins
    ADD CONSTRAINT gift_wheel_spins_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES public.gift_wheel_rewards(id);


--
-- Name: hr_basic_salary hr_basic_salary_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_basic_salary
    ADD CONSTRAINT hr_basic_salary_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_checklist_operations hr_checklist_operations_box_operation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_checklist_operations
    ADD CONSTRAINT hr_checklist_operations_box_operation_id_fkey FOREIGN KEY (box_operation_id) REFERENCES public.box_operations(id) ON DELETE SET NULL;


--
-- Name: hr_checklist_operations hr_checklist_operations_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_checklist_operations
    ADD CONSTRAINT hr_checklist_operations_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: hr_checklist_operations hr_checklist_operations_checklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_checklist_operations
    ADD CONSTRAINT hr_checklist_operations_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES public.hr_checklists(id) ON DELETE CASCADE;


--
-- Name: hr_checklist_operations hr_checklist_operations_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_checklist_operations
    ADD CONSTRAINT hr_checklist_operations_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE SET NULL;


--
-- Name: hr_employee_applicability_rule_periods hr_employee_applicability_rule_periods_employee_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_applicability_rule_periods
    ADD CONSTRAINT hr_employee_applicability_rule_periods_employee_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_employee_applicability_rule_periods hr_employee_applicability_rule_periods_rule_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_applicability_rule_periods
    ADD CONSTRAINT hr_employee_applicability_rule_periods_rule_fkey FOREIGN KEY (rule_id) REFERENCES public.settlement_rules(id) ON DELETE CASCADE;


--
-- Name: hr_employee_esob_records hr_employee_esob_records_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_esob_records
    ADD CONSTRAINT hr_employee_esob_records_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_employee_leave_approvals hr_employee_leave_approvals_employee_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_leave_approvals
    ADD CONSTRAINT hr_employee_leave_approvals_employee_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_employee_master hr_employee_master_current_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_master
    ADD CONSTRAINT hr_employee_master_current_branch_id_fkey FOREIGN KEY (current_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: hr_employee_master hr_employee_master_current_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_master
    ADD CONSTRAINT hr_employee_master_current_position_id_fkey FOREIGN KEY (current_position_id) REFERENCES public.hr_positions(id) ON DELETE SET NULL;


--
-- Name: hr_employee_master hr_employee_master_nationality_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_master
    ADD CONSTRAINT hr_employee_master_nationality_id_fkey FOREIGN KEY (nationality_id) REFERENCES public.nationalities(id);


--
-- Name: hr_employee_master hr_employee_master_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_master
    ADD CONSTRAINT hr_employee_master_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: hr_employee_settlement_applicability hr_employee_settlement_applicability_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_settlement_applicability
    ADD CONSTRAINT hr_employee_settlement_applicability_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_employee_settlement_applicability hr_employee_settlement_applicability_leave_salary_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_settlement_applicability
    ADD CONSTRAINT hr_employee_settlement_applicability_leave_salary_rule_id_fkey FOREIGN KEY (leave_salary_rule_id) REFERENCES public.settlement_rules(id) ON DELETE SET NULL;


--
-- Name: hr_employee_settlement_applicability hr_employee_settlement_applicability_ticket_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_settlement_applicability
    ADD CONSTRAINT hr_employee_settlement_applicability_ticket_rule_id_fkey FOREIGN KEY (ticket_rule_id) REFERENCES public.settlement_rules(id) ON DELETE SET NULL;


--
-- Name: hr_employee_ticket_issuances hr_employee_ticket_issuances_employee_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_ticket_issuances
    ADD CONSTRAINT hr_employee_ticket_issuances_employee_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: hr_employees hr_employees_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employees
    ADD CONSTRAINT hr_employees_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: hr_fingerprint_transactions hr_fingerprint_transactions_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_fingerprint_transactions
    ADD CONSTRAINT hr_fingerprint_transactions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: hr_position_assignments hr_position_assignments_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: hr_position_assignments hr_position_assignments_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.hr_departments(id);


--
-- Name: hr_position_assignments hr_position_assignments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employees(id);


--
-- Name: hr_position_assignments hr_position_assignments_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.hr_levels(id);


--
-- Name: hr_position_assignments hr_position_assignments_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_assignments
    ADD CONSTRAINT hr_position_assignments_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_1_fkey FOREIGN KEY (manager_position_1) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_2_fkey FOREIGN KEY (manager_position_2) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_3_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_3_fkey FOREIGN KEY (manager_position_3) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_4_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_4_fkey FOREIGN KEY (manager_position_4) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_manager_position_5_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_manager_position_5_fkey FOREIGN KEY (manager_position_5) REFERENCES public.hr_positions(id);


--
-- Name: hr_position_reporting_template hr_position_reporting_template_subordinate_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_position_reporting_template
    ADD CONSTRAINT hr_position_reporting_template_subordinate_position_id_fkey FOREIGN KEY (subordinate_position_id) REFERENCES public.hr_positions(id);


--
-- Name: hr_positions hr_positions_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_positions
    ADD CONSTRAINT hr_positions_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.hr_departments(id);


--
-- Name: hr_positions hr_positions_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_positions
    ADD CONSTRAINT hr_positions_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.hr_levels(id);


--
-- Name: hr_salary_notes hr_salary_notes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_salary_notes
    ADD CONSTRAINT hr_salary_notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: hr_salary_notes hr_salary_notes_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_salary_notes
    ADD CONSTRAINT hr_salary_notes_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: incident_actions incident_actions_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident_actions
    ADD CONSTRAINT incident_actions_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: incident_actions incident_actions_incident_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident_actions
    ADD CONSTRAINT incident_actions_incident_type_id_fkey FOREIGN KEY (incident_type_id) REFERENCES public.incident_types(id);


--
-- Name: incidents incidents_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: incidents incidents_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id);


--
-- Name: incidents incidents_incident_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_incident_type_id_fkey FOREIGN KEY (incident_type_id) REFERENCES public.incident_types(id);


--
-- Name: incidents incidents_violation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_violation_id_fkey FOREIGN KEY (violation_id) REFERENCES public.warning_violation(id);


--
-- Name: interface_permissions interface_permissions_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interface_permissions
    ADD CONSTRAINT interface_permissions_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: interface_permissions interface_permissions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interface_permissions
    ADD CONSTRAINT interface_permissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: lease_rent_lease_parties lease_rent_lease_parties_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_lease_parties
    ADD CONSTRAINT lease_rent_lease_parties_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lease_rent_lease_parties lease_rent_lease_parties_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_lease_parties
    ADD CONSTRAINT lease_rent_lease_parties_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.lease_rent_properties(id) ON DELETE CASCADE;


--
-- Name: lease_rent_lease_parties lease_rent_lease_parties_property_space_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_lease_parties
    ADD CONSTRAINT lease_rent_lease_parties_property_space_id_fkey FOREIGN KEY (property_space_id) REFERENCES public.lease_rent_property_spaces(id) ON DELETE SET NULL;


--
-- Name: lease_rent_payments lease_rent_payments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_payments
    ADD CONSTRAINT lease_rent_payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: lease_rent_properties lease_rent_property_spaces_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_properties
    ADD CONSTRAINT lease_rent_property_spaces_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lease_rent_property_spaces lease_rent_property_spaces_created_by_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_property_spaces
    ADD CONSTRAINT lease_rent_property_spaces_created_by_fkey1 FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lease_rent_property_spaces lease_rent_property_spaces_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_property_spaces
    ADD CONSTRAINT lease_rent_property_spaces_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.lease_rent_properties(id) ON DELETE CASCADE;


--
-- Name: lease_rent_rent_parties lease_rent_rent_parties_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_rent_parties
    ADD CONSTRAINT lease_rent_rent_parties_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: lease_rent_rent_parties lease_rent_rent_parties_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_rent_parties
    ADD CONSTRAINT lease_rent_rent_parties_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.lease_rent_properties(id) ON DELETE CASCADE;


--
-- Name: lease_rent_rent_parties lease_rent_rent_parties_property_space_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_rent_parties
    ADD CONSTRAINT lease_rent_rent_parties_property_space_id_fkey FOREIGN KEY (property_space_id) REFERENCES public.lease_rent_property_spaces(id) ON DELETE SET NULL;


--
-- Name: lease_rent_special_changes lease_rent_special_changes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lease_rent_special_changes
    ADD CONSTRAINT lease_rent_special_changes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: loyalty_customer_bills loyalty_customer_bills_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_customer_bills
    ADD CONSTRAINT loyalty_customer_bills_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: loyalty_redemptions loyalty_redemptions_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_redemptions
    ADD CONSTRAINT loyalty_redemptions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE RESTRICT;


--
-- Name: mobile_themes mobile_themes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_themes
    ADD CONSTRAINT mobile_themes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: multi_shift_date_wise multi_shift_date_wise_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multi_shift_date_wise
    ADD CONSTRAINT multi_shift_date_wise_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: multi_shift_regular multi_shift_regular_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multi_shift_regular
    ADD CONSTRAINT multi_shift_regular_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: multi_shift_weekday multi_shift_weekday_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.multi_shift_weekday
    ADD CONSTRAINT multi_shift_weekday_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: near_expiry_reports near_expiry_reports_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.near_expiry_reports
    ADD CONSTRAINT near_expiry_reports_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: near_expiry_reports near_expiry_reports_reporter_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.near_expiry_reports
    ADD CONSTRAINT near_expiry_reports_reporter_user_id_fkey FOREIGN KEY (reporter_user_id) REFERENCES public.users(id);


--
-- Name: near_expiry_reports near_expiry_reports_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.near_expiry_reports
    ADD CONSTRAINT near_expiry_reports_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id);


--
-- Name: notification_attachments notification_attachments_notification_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_attachments
    ADD CONSTRAINT notification_attachments_notification_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id) ON DELETE CASCADE;


--
-- Name: notification_read_states notification_read_states_notification_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_read_states
    ADD CONSTRAINT notification_read_states_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id) ON DELETE CASCADE;


--
-- Name: notification_recipients notification_recipients_notification_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_recipients
    ADD CONSTRAINT notification_recipients_notification_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_task_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_task_assignment_id_fkey FOREIGN KEY (task_assignment_id) REFERENCES public.task_assignments(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: offer_bundles offer_bundles_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_bundles
    ADD CONSTRAINT offer_bundles_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: offer_cart_tiers offer_cart_tiers_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_cart_tiers
    ADD CONSTRAINT offer_cart_tiers_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: offer_products offer_products_added_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT offer_products_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.users(id);


--
-- Name: offer_products offer_products_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT offer_products_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: offer_products offer_products_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_products
    ADD CONSTRAINT offer_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;


--
-- Name: offer_usage_logs offer_usage_logs_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_usage_logs
    ADD CONSTRAINT offer_usage_logs_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: offer_usage_logs offer_usage_logs_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_usage_logs
    ADD CONSTRAINT offer_usage_logs_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE CASCADE;


--
-- Name: offers offers_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: offers offers_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: order_audit_logs order_audit_logs_assigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_audit_logs
    ADD CONSTRAINT order_audit_logs_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: order_audit_logs order_audit_logs_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_audit_logs
    ADD CONSTRAINT order_audit_logs_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_audit_logs order_audit_logs_performed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_audit_logs
    ADD CONSTRAINT order_audit_logs_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: order_items order_items_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE SET NULL;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: order_items order_items_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.product_units(id) ON DELETE SET NULL;


--
-- Name: orders orders_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: orders orders_cancelled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders orders_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders orders_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE RESTRICT;


--
-- Name: orders orders_delivery_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_delivery_person_id_fkey FOREIGN KEY (delivery_person_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders orders_picker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_picker_id_fkey FOREIGN KEY (picker_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: orders orders_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: overtime_registrations overtime_registrations_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.overtime_registrations
    ADD CONSTRAINT overtime_registrations_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_box_operation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_box_operation_id_fkey FOREIGN KEY (box_operation_id) REFERENCES public.box_operations(id) ON DELETE CASCADE;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_cashier_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_cashier_user_id_fkey FOREIGN KEY (cashier_user_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: pos_deduction_transfers pos_deduction_transfers_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_deduction_transfers
    ADD CONSTRAINT pos_deduction_transfers_id_fkey FOREIGN KEY (id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: processed_fingerprint_transactions processed_fingerprint_transactions_center_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.processed_fingerprint_transactions
    ADD CONSTRAINT processed_fingerprint_transactions_center_id_fkey FOREIGN KEY (center_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: product_categories product_categories_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: product_request_bt product_request_bt_from_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_from_branch_id_fkey FOREIGN KEY (from_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: product_request_bt product_request_bt_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: product_request_bt product_request_bt_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: product_request_bt product_request_bt_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_bt
    ADD CONSTRAINT product_request_bt_to_branch_id_fkey FOREIGN KEY (to_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: product_request_po product_request_po_from_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_po
    ADD CONSTRAINT product_request_po_from_branch_id_fkey FOREIGN KEY (from_branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: product_request_po product_request_po_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_po
    ADD CONSTRAINT product_request_po_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: product_request_po product_request_po_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_po
    ADD CONSTRAINT product_request_po_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: product_request_st product_request_st_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_st
    ADD CONSTRAINT product_request_st_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: product_request_st product_request_st_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_st
    ADD CONSTRAINT product_request_st_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: product_request_st product_request_st_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_request_st
    ADD CONSTRAINT product_request_st_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: product_units product_units_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_units
    ADD CONSTRAINT product_units_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: purchase_voucher_items purchase_voucher_items_approver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: purchase_voucher_items purchase_voucher_items_issued_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_issued_by_fkey FOREIGN KEY (issued_by) REFERENCES public.users(id);


--
-- Name: purchase_voucher_items purchase_voucher_items_pending_stock_location_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_pending_stock_location_fkey FOREIGN KEY (pending_stock_location) REFERENCES public.branches(id);


--
-- Name: purchase_voucher_items purchase_voucher_items_pending_stock_person_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_pending_stock_person_fkey FOREIGN KEY (pending_stock_person) REFERENCES public.users(id);


--
-- Name: purchase_voucher_items purchase_voucher_items_purchase_voucher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_purchase_voucher_id_fkey FOREIGN KEY (purchase_voucher_id) REFERENCES public.purchase_vouchers(id);


--
-- Name: purchase_voucher_items purchase_voucher_items_stock_location_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_stock_location_fkey FOREIGN KEY (stock_location) REFERENCES public.branches(id);


--
-- Name: purchase_voucher_items purchase_voucher_items_stock_person_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_voucher_items
    ADD CONSTRAINT purchase_voucher_items_stock_person_fkey FOREIGN KEY (stock_person) REFERENCES public.users(id);


--
-- Name: quick_task_assignments quick_task_assignments_assigned_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_assignments
    ADD CONSTRAINT quick_task_assignments_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: quick_task_assignments quick_task_assignments_quick_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_assignments
    ADD CONSTRAINT quick_task_assignments_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES public.quick_tasks(id) ON DELETE CASCADE;


--
-- Name: quick_task_comments quick_task_comments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_comments
    ADD CONSTRAINT quick_task_comments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: quick_task_comments quick_task_comments_quick_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_comments
    ADD CONSTRAINT quick_task_comments_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES public.quick_tasks(id) ON DELETE CASCADE;


--
-- Name: quick_task_completions quick_task_completions_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.quick_task_assignments(id) ON DELETE CASCADE;


--
-- Name: quick_task_completions quick_task_completions_completed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_completed_by_user_id_fkey FOREIGN KEY (completed_by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: quick_task_completions quick_task_completions_quick_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES public.quick_tasks(id) ON DELETE CASCADE;


--
-- Name: quick_task_completions quick_task_completions_verified_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_completions
    ADD CONSTRAINT quick_task_completions_verified_by_user_id_fkey FOREIGN KEY (verified_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: quick_task_files quick_task_files_quick_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_files
    ADD CONSTRAINT quick_task_files_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES public.quick_tasks(id) ON DELETE CASCADE;


--
-- Name: quick_task_files quick_task_files_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_files
    ADD CONSTRAINT quick_task_files_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: quick_task_user_preferences quick_task_user_preferences_default_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_user_preferences
    ADD CONSTRAINT quick_task_user_preferences_default_branch_id_fkey FOREIGN KEY (default_branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: quick_task_user_preferences quick_task_user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_task_user_preferences
    ADD CONSTRAINT quick_task_user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: quick_tasks quick_tasks_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: quick_tasks quick_tasks_assigned_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_assigned_to_branch_id_fkey FOREIGN KEY (assigned_to_branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: quick_tasks quick_tasks_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id);


--
-- Name: quick_tasks quick_tasks_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_tasks
    ADD CONSTRAINT quick_tasks_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;


--
-- Name: receiving_records receiving_records_accountant_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_records
    ADD CONSTRAINT receiving_records_accountant_user_id_fkey FOREIGN KEY (accountant_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: receiving_records receiving_records_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_records
    ADD CONSTRAINT receiving_records_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE RESTRICT;


--
-- Name: receiving_records receiving_records_branch_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_records
    ADD CONSTRAINT receiving_records_branch_manager_user_id_fkey FOREIGN KEY (branch_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: receiving_records receiving_records_inventory_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_records
    ADD CONSTRAINT receiving_records_inventory_manager_user_id_fkey FOREIGN KEY (inventory_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: receiving_records receiving_records_purchasing_manager_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_records
    ADD CONSTRAINT receiving_records_purchasing_manager_user_id_fkey FOREIGN KEY (purchasing_manager_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: receiving_records receiving_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_records
    ADD CONSTRAINT receiving_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: receiving_records receiving_records_vendor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_records
    ADD CONSTRAINT receiving_records_vendor_fkey FOREIGN KEY (vendor_id, branch_id) REFERENCES public.vendors(erp_vendor_id, branch_id) ON DELETE RESTRICT;


--
-- Name: CONSTRAINT receiving_records_vendor_fkey ON receiving_records; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT receiving_records_vendor_fkey ON public.receiving_records IS 'Foreign key constraint linking receiving_records to vendors using composite key (vendor_id -> erp_vendor_id, branch_id -> branch_id)';


--
-- Name: receiving_tasks receiving_tasks_assigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_tasks
    ADD CONSTRAINT receiving_tasks_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: receiving_tasks receiving_tasks_receiving_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_tasks
    ADD CONSTRAINT receiving_tasks_receiving_record_id_fkey FOREIGN KEY (receiving_record_id) REFERENCES public.receiving_records(id) ON DELETE CASCADE;


--
-- Name: receiving_tasks receiving_tasks_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_tasks
    ADD CONSTRAINT receiving_tasks_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.receiving_task_templates(id) ON DELETE SET NULL;


--
-- Name: receiving_user_defaults receiving_user_defaults_default_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_user_defaults
    ADD CONSTRAINT receiving_user_defaults_default_branch_id_fkey FOREIGN KEY (default_branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: receiving_user_defaults receiving_user_defaults_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receiving_user_defaults
    ADD CONSTRAINT receiving_user_defaults_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: regular_shift regular_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.regular_shift
    ADD CONSTRAINT regular_shift_id_fkey FOREIGN KEY (id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: security_code_scroll_texts security_code_scroll_texts_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_code_scroll_texts
    ADD CONSTRAINT security_code_scroll_texts_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: shelf_paper_templates shelf_paper_templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shelf_paper_templates
    ADD CONSTRAINT shelf_paper_templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: special_shift_date_wise special_shift_date_wise_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_shift_date_wise
    ADD CONSTRAINT special_shift_date_wise_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: special_shift_weekday special_shift_weekday_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_shift_weekday
    ADD CONSTRAINT special_shift_weekday_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employee_master(id) ON DELETE CASCADE;


--
-- Name: surprise_box_plays surprise_box_plays_reward_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprise_box_plays
    ADD CONSTRAINT surprise_box_plays_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES public.surprise_box_rewards(id) ON DELETE SET NULL;


--
-- Name: surprise_box_vouchers surprise_box_vouchers_play_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprise_box_vouchers
    ADD CONSTRAINT surprise_box_vouchers_play_id_fkey FOREIGN KEY (play_id) REFERENCES public.surprise_box_plays(id) ON DELETE SET NULL;


--
-- Name: surprise_box_vouchers surprise_box_vouchers_reward_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surprise_box_vouchers
    ADD CONSTRAINT surprise_box_vouchers_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES public.surprise_box_rewards(id) ON DELETE SET NULL;


--
-- Name: task_assignments task_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: task_assignments task_assignments_assigned_to_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_assigned_to_branch_id_fkey FOREIGN KEY (assigned_to_branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: CONSTRAINT task_assignments_assigned_to_branch_id_fkey ON task_assignments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT task_assignments_assigned_to_branch_id_fkey ON public.task_assignments IS 'Foreign key relationship to branches table for branch assignments';


--
-- Name: task_assignments task_assignments_assigned_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: task_assignments task_assignments_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_assignments
    ADD CONSTRAINT task_assignments_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_completions task_completions_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_completions
    ADD CONSTRAINT task_completions_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES public.task_assignments(id) ON DELETE CASCADE;


--
-- Name: task_completions task_completions_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_completions
    ADD CONSTRAINT task_completions_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_images task_images_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_images
    ADD CONSTRAINT task_images_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;


--
-- Name: task_reminder_logs task_reminder_logs_assigned_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES public.users(id);


--
-- Name: task_reminder_logs task_reminder_logs_notification_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notifications(id);


--
-- Name: task_reminder_logs task_reminder_logs_quick_task_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_quick_task_assignment_id_fkey FOREIGN KEY (quick_task_assignment_id) REFERENCES public.quick_task_assignments(id) ON DELETE CASCADE;


--
-- Name: task_reminder_logs task_reminder_logs_task_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.task_reminder_logs
    ADD CONSTRAINT task_reminder_logs_task_assignment_id_fkey FOREIGN KEY (task_assignment_id) REFERENCES public.task_assignments(id) ON DELETE CASCADE;


--
-- Name: user_audit_logs user_audit_logs_performed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_audit_logs
    ADD CONSTRAINT user_audit_logs_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.users(id);


--
-- Name: user_audit_logs user_audit_logs_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_audit_logs
    ADD CONSTRAINT user_audit_logs_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_audit_logs user_audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_audit_logs
    ADD CONSTRAINT user_audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_device_sessions user_device_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_device_sessions
    ADD CONSTRAINT user_device_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_erp_credentials user_erp_credentials_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_erp_credentials
    ADD CONSTRAINT user_erp_credentials_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: user_erp_credentials user_erp_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_erp_credentials
    ADD CONSTRAINT user_erp_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_mobile_theme_assignments user_mobile_theme_assignments_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_mobile_theme_assignments
    ADD CONSTRAINT user_mobile_theme_assignments_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.mobile_themes(id) ON DELETE CASCADE;


--
-- Name: user_password_history user_password_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_password_history
    ADD CONSTRAINT user_password_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_sessions user_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_theme_assignments user_theme_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_theme_assignments user_theme_assignments_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.desktop_themes(id) ON DELETE CASCADE;


--
-- Name: user_theme_assignments user_theme_assignments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_theme_assignments
    ADD CONSTRAINT user_theme_assignments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: users users_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.hr_employees(id) ON DELETE SET NULL;


--
-- Name: users users_locked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES public.users(id);


--
-- Name: variation_audit_log variation_audit_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variation_audit_log
    ADD CONSTRAINT variation_audit_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: vendor_payment_schedule vendor_payment_approval_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_approval_requested_by_fkey FOREIGN KEY (approval_requested_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule vendor_payment_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule vendor_payment_assigned_approver_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_assigned_approver_fkey FOREIGN KEY (assigned_approver_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule vendor_payment_schedule_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_pr_excel_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_pr_excel_verified_by_fkey FOREIGN KEY (pr_excel_verified_by) REFERENCES public.users(id);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_receiving_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_receiving_record_id_fkey FOREIGN KEY (receiving_record_id) REFERENCES public.receiving_records(id) ON DELETE CASCADE;


--
-- Name: vendor_payment_schedule vendor_payment_schedule_task_assignment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_task_assignment_id_fkey FOREIGN KEY (task_assignment_id) REFERENCES public.task_assignments(id) ON DELETE SET NULL;


--
-- Name: vendor_payment_schedule vendor_payment_schedule_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_schedule
    ADD CONSTRAINT vendor_payment_schedule_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE SET NULL;


--
-- Name: vendors vendors_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendors
    ADD CONSTRAINT vendors_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE SET NULL;


--
-- Name: view_offer view_offer_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_offer
    ADD CONSTRAINT view_offer_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: wa_auto_reply_triggers wa_auto_reply_triggers_follow_up_trigger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_auto_reply_triggers
    ADD CONSTRAINT wa_auto_reply_triggers_follow_up_trigger_id_fkey FOREIGN KEY (follow_up_trigger_id) REFERENCES public.wa_auto_reply_triggers(id) ON DELETE SET NULL;


--
-- Name: wa_auto_reply_triggers wa_auto_reply_triggers_reply_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_auto_reply_triggers
    ADD CONSTRAINT wa_auto_reply_triggers_reply_template_id_fkey FOREIGN KEY (reply_template_id) REFERENCES public.wa_templates(id) ON DELETE SET NULL;


--
-- Name: wa_auto_reply_triggers wa_auto_reply_triggers_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_auto_reply_triggers
    ADD CONSTRAINT wa_auto_reply_triggers_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_bot_flows wa_bot_flows_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_bot_flows
    ADD CONSTRAINT wa_bot_flows_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_broadcast_recipients wa_broadcast_recipients_broadcast_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_broadcast_recipients
    ADD CONSTRAINT wa_broadcast_recipients_broadcast_id_fkey FOREIGN KEY (broadcast_id) REFERENCES public.wa_broadcasts(id) ON DELETE CASCADE;


--
-- Name: wa_broadcast_recipients wa_broadcast_recipients_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_broadcast_recipients
    ADD CONSTRAINT wa_broadcast_recipients_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: wa_broadcasts wa_broadcasts_recipient_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_broadcasts
    ADD CONSTRAINT wa_broadcasts_recipient_group_id_fkey FOREIGN KEY (recipient_group_id) REFERENCES public.wa_contact_groups(id) ON DELETE SET NULL;


--
-- Name: wa_broadcasts wa_broadcasts_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_broadcasts
    ADD CONSTRAINT wa_broadcasts_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.wa_templates(id) ON DELETE SET NULL;


--
-- Name: wa_broadcasts wa_broadcasts_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_broadcasts
    ADD CONSTRAINT wa_broadcasts_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_catalog_orders wa_catalog_orders_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_catalog_orders
    ADD CONSTRAINT wa_catalog_orders_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.wa_catalogs(id);


--
-- Name: wa_catalog_orders wa_catalog_orders_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_catalog_orders
    ADD CONSTRAINT wa_catalog_orders_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_catalog_products wa_catalog_products_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_catalog_products
    ADD CONSTRAINT wa_catalog_products_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.wa_catalogs(id) ON DELETE CASCADE;


--
-- Name: wa_catalog_products wa_catalog_products_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_catalog_products
    ADD CONSTRAINT wa_catalog_products_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_catalogs wa_catalogs_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_catalogs
    ADD CONSTRAINT wa_catalogs_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_contact_group_members wa_contact_group_members_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_contact_group_members
    ADD CONSTRAINT wa_contact_group_members_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- Name: wa_contact_group_members wa_contact_group_members_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_contact_group_members
    ADD CONSTRAINT wa_contact_group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.wa_contact_groups(id) ON DELETE CASCADE;


--
-- Name: wa_conversations wa_conversations_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_conversations
    ADD CONSTRAINT wa_conversations_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- Name: wa_conversations wa_conversations_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_conversations
    ADD CONSTRAINT wa_conversations_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_messages wa_messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_messages
    ADD CONSTRAINT wa_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.wa_conversations(id) ON DELETE CASCADE;


--
-- Name: wa_messages wa_messages_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_messages
    ADD CONSTRAINT wa_messages_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_settings wa_settings_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_settings
    ADD CONSTRAINT wa_settings_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: wa_templates wa_templates_wa_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wa_templates
    ADD CONSTRAINT wa_templates_wa_account_id_fkey FOREIGN KEY (wa_account_id) REFERENCES public.wa_accounts(id) ON DELETE CASCADE;


--
-- Name: warning_sub_category warning_sub_category_main_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warning_sub_category
    ADD CONSTRAINT warning_sub_category_main_category_id_fkey FOREIGN KEY (main_category_id) REFERENCES public.warning_main_category(id) ON DELETE CASCADE;


--
-- Name: warning_violation warning_violation_main_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warning_violation
    ADD CONSTRAINT warning_violation_main_category_id_fkey FOREIGN KEY (main_category_id) REFERENCES public.warning_main_category(id) ON DELETE CASCADE;


--
-- Name: warning_violation warning_violation_sub_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warning_violation
    ADD CONSTRAINT warning_violation_sub_category_id_fkey FOREIGN KEY (sub_category_id) REFERENCES public.warning_sub_category(id) ON DELETE CASCADE;


--
-- Name: employee_fine_payments Admins can manage all fine payments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can manage all fine payments" ON public.employee_fine_payments USING ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND (u.user_type = 'global'::public.user_type_enum)))));


--
-- Name: user_device_sessions Admins can view all device sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can view all device sessions" ON public.user_device_sessions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.user_type = 'global'::public.user_type_enum)))));


--
-- Name: expense_parent_categories Allow admin users to delete parent categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow admin users to delete parent categories" ON public.expense_parent_categories FOR DELETE TO authenticated USING (true);


--
-- Name: expense_sub_categories Allow admin users to delete sub categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow admin users to delete sub categories" ON public.expense_sub_categories FOR DELETE TO authenticated USING (true);


--
-- Name: expense_parent_categories Allow admin users to insert parent categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow admin users to insert parent categories" ON public.expense_parent_categories FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: expense_sub_categories Allow admin users to insert sub categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow admin users to insert sub categories" ON public.expense_sub_categories FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: expense_parent_categories Allow admin users to update parent categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow admin users to update parent categories" ON public.expense_parent_categories FOR UPDATE TO authenticated USING (true);


--
-- Name: expense_sub_categories Allow admin users to update sub categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow admin users to update sub categories" ON public.expense_sub_categories FOR UPDATE TO authenticated USING (true);


--
-- Name: ai_chat_guide Allow all access to ai_chat_guide; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to ai_chat_guide" ON public.ai_chat_guide USING (true) WITH CHECK (true);


--
-- Name: approval_permissions Allow all access to approval_permissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to approval_permissions" ON public.approval_permissions USING (true) WITH CHECK (true);


--
-- Name: approver_branch_access Allow all access to approver_branch_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to approver_branch_access" ON public.approver_branch_access USING (true) WITH CHECK (true);


--
-- Name: approver_visibility_config Allow all access to approver_visibility_config; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to approver_visibility_config" ON public.approver_visibility_config USING (true) WITH CHECK (true);


--
-- Name: asset_main_categories Allow all access to asset_main_categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to asset_main_categories" ON public.asset_main_categories USING (true) WITH CHECK (true);


--
-- Name: asset_sub_categories Allow all access to asset_sub_categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to asset_sub_categories" ON public.asset_sub_categories USING (true) WITH CHECK (true);


--
-- Name: assets Allow all access to assets; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to assets" ON public.assets USING (true) WITH CHECK (true);


--
-- Name: bank_reconciliations Allow all access to bank_reconciliations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to bank_reconciliations" ON public.bank_reconciliations USING (true) WITH CHECK (true);


--
-- Name: branch_default_delivery_receivers Allow all access to branch_default_delivery_receivers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to branch_default_delivery_receivers" ON public.branch_default_delivery_receivers USING (true) WITH CHECK (true);


--
-- Name: branch_default_positions Allow all access to branch_default_positions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to branch_default_positions" ON public.branch_default_positions USING (true) WITH CHECK (true);


--
-- Name: break_reasons Allow all access to break_reasons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to break_reasons" ON public.break_reasons USING (true) WITH CHECK (true);


--
-- Name: break_register Allow all access to break_register; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to break_register" ON public.break_register USING (true) WITH CHECK (true);


--
-- Name: customer_product_requests Allow all access to customer_product_requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to customer_product_requests" ON public.customer_product_requests USING (true) WITH CHECK (true);


--
-- Name: day_off_reasons Allow all access to day_off_reasons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to day_off_reasons" ON public.day_off_reasons USING (true) WITH CHECK (true);


--
-- Name: default_incident_users Allow all access to default_incident_users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to default_incident_users" ON public.default_incident_users USING (true) WITH CHECK (true);


--
-- Name: denomination_transactions Allow all access to denomination_transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to denomination_transactions" ON public.denomination_transactions USING (true) WITH CHECK (true);


--
-- Name: desktop_themes Allow all access to desktop_themes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to desktop_themes" ON public.desktop_themes USING (true) WITH CHECK (true);


--
-- Name: employee_checklist_assignments Allow all access to employee_checklist_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to employee_checklist_assignments" ON public.employee_checklist_assignments USING (true) WITH CHECK (true);


--
-- Name: erp_synced_products Allow all access to erp_synced_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to erp_synced_products" ON public.erp_synced_products USING (true) WITH CHECK (true);


--
-- Name: hr_analysed_attendance_data Allow all access to hr_analysed_attendance_data; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_analysed_attendance_data" ON public.hr_analysed_attendance_data USING (true) WITH CHECK (true);


--
-- Name: hr_basic_salary Allow all access to hr_basic_salary; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_basic_salary" ON public.hr_basic_salary USING (true) WITH CHECK (true);


--
-- Name: hr_checklist_operations Allow all access to hr_checklist_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_checklist_operations" ON public.hr_checklist_operations USING (true) WITH CHECK (true);


--
-- Name: hr_checklist_questions Allow all access to hr_checklist_questions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_checklist_questions" ON public.hr_checklist_questions USING (true) WITH CHECK (true);


--
-- Name: hr_checklists Allow all access to hr_checklists; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_checklists" ON public.hr_checklists USING (true) WITH CHECK (true);


--
-- Name: hr_employee_esob_records Allow all access to hr_employee_esob_records; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_employee_esob_records" ON public.hr_employee_esob_records TO anon USING (true) WITH CHECK (true);


--
-- Name: hr_employee_master Allow all access to hr_employee_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_employee_master" ON public.hr_employee_master USING (true) WITH CHECK (true);


--
-- Name: hr_esob_base_rules Allow all access to hr_esob_base_rules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_esob_base_rules" ON public.hr_esob_base_rules TO anon USING (true) WITH CHECK (true);


--
-- Name: hr_esob_resignation_factors Allow all access to hr_esob_resignation_factors; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_esob_resignation_factors" ON public.hr_esob_resignation_factors TO anon USING (true) WITH CHECK (true);


--
-- Name: hr_insurance_companies Allow all access to hr_insurance_companies; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to hr_insurance_companies" ON public.hr_insurance_companies USING (true) WITH CHECK (true);


--
-- Name: incident_actions Allow all access to incident_actions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to incident_actions" ON public.incident_actions USING (true) WITH CHECK (true);


--
-- Name: incident_types Allow all access to incident_types; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to incident_types" ON public.incident_types USING (true) WITH CHECK (true);


--
-- Name: incidents Allow all access to incidents; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to incidents" ON public.incidents USING (true) WITH CHECK (true);


--
-- Name: lease_rent_lease_parties Allow all access to lease_rent_lease_parties; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to lease_rent_lease_parties" ON public.lease_rent_lease_parties USING (true) WITH CHECK (true);


--
-- Name: lease_rent_payments Allow all access to lease_rent_payments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to lease_rent_payments" ON public.lease_rent_payments USING (true) WITH CHECK (true);


--
-- Name: lease_rent_properties Allow all access to lease_rent_properties; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to lease_rent_properties" ON public.lease_rent_properties USING (true) WITH CHECK (true);


--
-- Name: lease_rent_property_spaces Allow all access to lease_rent_property_spaces; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to lease_rent_property_spaces" ON public.lease_rent_property_spaces USING (true) WITH CHECK (true);


--
-- Name: lease_rent_rent_parties Allow all access to lease_rent_rent_parties; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to lease_rent_rent_parties" ON public.lease_rent_rent_parties USING (true) WITH CHECK (true);


--
-- Name: mobile_themes Allow all access to mobile_themes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to mobile_themes" ON public.mobile_themes USING (true) WITH CHECK (true);


--
-- Name: multi_shift_date_wise Allow all access to multi_shift_date_wise; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to multi_shift_date_wise" ON public.multi_shift_date_wise USING (true) WITH CHECK (true);


--
-- Name: multi_shift_regular Allow all access to multi_shift_regular; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to multi_shift_regular" ON public.multi_shift_regular USING (true) WITH CHECK (true);


--
-- Name: multi_shift_weekday Allow all access to multi_shift_weekday; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to multi_shift_weekday" ON public.multi_shift_weekday USING (true) WITH CHECK (true);


--
-- Name: nationalities Allow all access to nationalities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to nationalities" ON public.nationalities USING (true) WITH CHECK (true);


--
-- Name: near_expiry_reports Allow all access to near_expiry_reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to near_expiry_reports" ON public.near_expiry_reports USING (true) WITH CHECK (true);


--
-- Name: offer_names Allow all access to offer_names; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to offer_names" ON public.offer_names USING (true) WITH CHECK (true);


--
-- Name: pos_deduction_transfers Allow all access to pos_deduction_transfers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to pos_deduction_transfers" ON public.pos_deduction_transfers USING (true) WITH CHECK (true);


--
-- Name: processed_fingerprint_transactions Allow all access to processed_fingerprint_transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to processed_fingerprint_transactions" ON public.processed_fingerprint_transactions USING (true) WITH CHECK (true);


--
-- Name: product_categories Allow all access to product_categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to product_categories" ON public.product_categories USING (true) WITH CHECK (true);


--
-- Name: product_request_bt Allow all access to product_request_bt; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to product_request_bt" ON public.product_request_bt USING (true) WITH CHECK (true);


--
-- Name: product_request_po Allow all access to product_request_po; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to product_request_po" ON public.product_request_po USING (true) WITH CHECK (true);


--
-- Name: product_request_st Allow all access to product_request_st; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to product_request_st" ON public.product_request_st USING (true) WITH CHECK (true);


--
-- Name: product_units Allow all access to product_units; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to product_units" ON public.product_units USING (true) WITH CHECK (true);


--
-- Name: push_subscriptions Allow all access to push_subscriptions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to push_subscriptions" ON public.push_subscriptions USING (true) WITH CHECK (true);


--
-- Name: receiving_user_defaults Allow all access to receiving_user_defaults; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to receiving_user_defaults" ON public.receiving_user_defaults USING (true) WITH CHECK (true);


--
-- Name: regular_shift Allow all access to regular_shift; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to regular_shift" ON public.regular_shift USING (true) WITH CHECK (true);


--
-- Name: shelf_paper_fonts Allow all access to shelf_paper_fonts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to shelf_paper_fonts" ON public.shelf_paper_fonts USING (true) WITH CHECK (true);


--
-- Name: user_favorite_buttons Allow all access to user_favorite_buttons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to user_favorite_buttons" ON public.user_favorite_buttons USING (true) WITH CHECK (true);


--
-- Name: user_mobile_theme_assignments Allow all access to user_mobile_theme_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to user_mobile_theme_assignments" ON public.user_mobile_theme_assignments USING (true) WITH CHECK (true);


--
-- Name: user_theme_assignments Allow all access to user_theme_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to user_theme_assignments" ON public.user_theme_assignments USING (true) WITH CHECK (true);


--
-- Name: user_voice_preferences Allow all access to user_voice_preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to user_voice_preferences" ON public.user_voice_preferences USING (true) WITH CHECK (true);


--
-- Name: wa_accounts Allow all access to wa_accounts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to wa_accounts" ON public.wa_accounts USING (true) WITH CHECK (true);


--
-- Name: wa_broadcast_recipients Allow all access to wa_broadcast_recipients; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to wa_broadcast_recipients" ON public.wa_broadcast_recipients USING (true) WITH CHECK (true);


--
-- Name: wa_broadcasts Allow all access to wa_broadcasts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to wa_broadcasts" ON public.wa_broadcasts USING (true) WITH CHECK (true);


--
-- Name: wa_conversations Allow all access to wa_conversations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to wa_conversations" ON public.wa_conversations USING (true) WITH CHECK (true);


--
-- Name: wa_templates Allow all access to wa_templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to wa_templates" ON public.wa_templates USING (true) WITH CHECK (true);


--
-- Name: warning_main_category Allow all access to warning_main_category; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to warning_main_category" ON public.warning_main_category USING (true) WITH CHECK (true);


--
-- Name: warning_sub_category Allow all access to warning_sub_category; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to warning_sub_category" ON public.warning_sub_category USING (true) WITH CHECK (true);


--
-- Name: warning_violation Allow all access to warning_violation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all access to warning_violation" ON public.warning_violation USING (true) WITH CHECK (true);


--
-- Name: user_voice_preferences Allow all operations for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all operations for authenticated users" ON public.user_voice_preferences TO authenticated USING (true) WITH CHECK (true);


--
-- Name: day_off Allow all operations on day_off; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all operations on day_off" ON public.day_off USING (true) WITH CHECK (true);


--
-- Name: day_off_weekday Allow all operations on day_off_weekday; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all operations on day_off_weekday" ON public.day_off_weekday USING (true) WITH CHECK (true);


--
-- Name: employee_official_holidays Allow all operations on employee_official_holidays; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all operations on employee_official_holidays" ON public.employee_official_holidays USING (true) WITH CHECK (true);


--
-- Name: official_holidays Allow all operations on official_holidays; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all operations on official_holidays" ON public.official_holidays USING (true) WITH CHECK (true);


--
-- Name: special_shift_date_wise Allow all operations on special_shift_date_wise; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all operations on special_shift_date_wise" ON public.special_shift_date_wise USING (true) WITH CHECK (true);


--
-- Name: approval_permissions Allow all to view approval permissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all to view approval permissions" ON public.approval_permissions FOR SELECT USING (true);


--
-- Name: hr_employee_master Allow all users to view hr_employee_master table; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all users to view hr_employee_master table" ON public.hr_employee_master FOR SELECT USING (true);


--
-- Name: users Allow all users to view users table; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all users to view users table" ON public.users FOR SELECT USING (true);


--
-- Name: gift_wheel_coupons Allow anon all gift_wheel_coupons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all gift_wheel_coupons" ON public.gift_wheel_coupons TO anon USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_rewards Allow anon all gift_wheel_rewards; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all gift_wheel_rewards" ON public.gift_wheel_rewards TO anon USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_settings Allow anon all gift_wheel_settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all gift_wheel_settings" ON public.gift_wheel_settings TO anon USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_spins Allow anon all gift_wheel_spins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all gift_wheel_spins" ON public.gift_wheel_spins TO anon USING (true) WITH CHECK (true);


--
-- Name: hr_employee_applicability_rule_periods Allow anon all hr_employee_applicability_rule_periods; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all hr_employee_applicability_rule_periods" ON public.hr_employee_applicability_rule_periods TO anon USING (true) WITH CHECK (true);


--
-- Name: hr_employee_leave_approvals Allow anon all hr_employee_leave_approvals; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all hr_employee_leave_approvals" ON public.hr_employee_leave_approvals TO anon USING (true) WITH CHECK (true);


--
-- Name: hr_employee_settlement_applicability Allow anon all hr_employee_settlement_applicability; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all hr_employee_settlement_applicability" ON public.hr_employee_settlement_applicability TO anon USING (true) WITH CHECK (true);


--
-- Name: hr_employee_ticket_issuances Allow anon all hr_employee_ticket_issuances; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all hr_employee_ticket_issuances" ON public.hr_employee_ticket_issuances TO anon USING (true) WITH CHECK (true);


--
-- Name: settlement_rules Allow anon all settlement_rules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon all settlement_rules" ON public.settlement_rules TO anon USING (true) WITH CHECK (true);


--
-- Name: approval_permissions Allow anon insert approval_permissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert approval_permissions" ON public.approval_permissions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: biometric_connections Allow anon insert biometric_connections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert biometric_connections" ON public.biometric_connections FOR INSERT TO anon WITH CHECK (true);


--
-- Name: bogo_offer_rules Allow anon insert bogo_offer_rules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert bogo_offer_rules" ON public.bogo_offer_rules FOR INSERT TO anon WITH CHECK (true);


--
-- Name: coupon_campaigns Allow anon insert coupon_campaigns; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert coupon_campaigns" ON public.coupon_campaigns FOR INSERT TO anon WITH CHECK (true);


--
-- Name: coupon_claims Allow anon insert coupon_claims; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert coupon_claims" ON public.coupon_claims FOR INSERT TO anon WITH CHECK (true);


--
-- Name: coupon_eligible_customers Allow anon insert coupon_eligible_customers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert coupon_eligible_customers" ON public.coupon_eligible_customers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: coupon_products Allow anon insert coupon_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert coupon_products" ON public.coupon_products FOR INSERT TO anon WITH CHECK (true);


--
-- Name: customer_access_code_history Allow anon insert customer_access_code_history; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert customer_access_code_history" ON public.customer_access_code_history FOR INSERT TO anon WITH CHECK (true);


--
-- Name: customer_app_media Allow anon insert customer_app_media; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert customer_app_media" ON public.customer_app_media FOR INSERT TO anon WITH CHECK (true);


--
-- Name: customer_recovery_requests Allow anon insert customer_recovery_requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert customer_recovery_requests" ON public.customer_recovery_requests FOR INSERT TO anon WITH CHECK (true);


--
-- Name: customers Allow anon insert customers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert customers" ON public.customers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: deleted_bundle_offers Allow anon insert deleted_bundle_offers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert deleted_bundle_offers" ON public.deleted_bundle_offers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: delivery_fee_tiers Allow anon insert delivery_fee_tiers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert delivery_fee_tiers" ON public.delivery_fee_tiers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: delivery_service_settings Allow anon insert delivery_service_settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert delivery_service_settings" ON public.delivery_service_settings FOR INSERT TO anon WITH CHECK (true);


--
-- Name: employee_fine_payments Allow anon insert employee_fine_payments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert employee_fine_payments" ON public.employee_fine_payments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: erp_connections Allow anon insert erp_connections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert erp_connections" ON public.erp_connections FOR INSERT TO anon WITH CHECK (true);


--
-- Name: erp_daily_sales Allow anon insert erp_daily_sales; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert erp_daily_sales" ON public.erp_daily_sales FOR INSERT TO anon WITH CHECK (true);


--
-- Name: expense_parent_categories Allow anon insert expense_parent_categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert expense_parent_categories" ON public.expense_parent_categories FOR INSERT TO anon WITH CHECK (true);


--
-- Name: expense_requisitions Allow anon insert expense_requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert expense_requisitions" ON public.expense_requisitions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: expense_scheduler Allow anon insert expense_scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert expense_scheduler" ON public.expense_scheduler FOR INSERT TO anon WITH CHECK (true);


--
-- Name: expense_sub_categories Allow anon insert expense_sub_categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert expense_sub_categories" ON public.expense_sub_categories FOR INSERT TO anon WITH CHECK (true);


--
-- Name: flyer_offer_products Allow anon insert flyer_offer_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert flyer_offer_products" ON public.flyer_offer_products FOR INSERT TO anon WITH CHECK (true);


--
-- Name: flyer_offers Allow anon insert flyer_offers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert flyer_offers" ON public.flyer_offers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: flyer_templates Allow anon insert flyer_templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert flyer_templates" ON public.flyer_templates FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_departments Allow anon insert hr_departments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert hr_departments" ON public.hr_departments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_employee_master Allow anon insert hr_employee_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert hr_employee_master" ON public.hr_employee_master FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_employees Allow anon insert hr_employees; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert hr_employees" ON public.hr_employees FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_fingerprint_transactions Allow anon insert hr_fingerprint_transactions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert hr_fingerprint_transactions" ON public.hr_fingerprint_transactions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_levels Allow anon insert hr_levels; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert hr_levels" ON public.hr_levels FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_position_assignments Allow anon insert hr_position_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert hr_position_assignments" ON public.hr_position_assignments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_position_reporting_template Allow anon insert hr_position_reporting_template; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert hr_position_reporting_template" ON public.hr_position_reporting_template FOR INSERT TO anon WITH CHECK (true);


--
-- Name: hr_positions Allow anon insert hr_positions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert hr_positions" ON public.hr_positions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: interface_permissions Allow anon insert interface_permissions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert interface_permissions" ON public.interface_permissions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler Allow anon insert non_approved_payment_scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert non_approved_payment_scheduler" ON public.non_approved_payment_scheduler FOR INSERT TO anon WITH CHECK (true);


--
-- Name: notification_attachments Allow anon insert notification_attachments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert notification_attachments" ON public.notification_attachments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: notification_read_states Allow anon insert notification_read_states; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert notification_read_states" ON public.notification_read_states FOR INSERT TO anon WITH CHECK (true);


--
-- Name: notification_recipients Allow anon insert notification_recipients; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert notification_recipients" ON public.notification_recipients FOR INSERT TO anon WITH CHECK (true);


--
-- Name: notifications Allow anon insert notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert notifications" ON public.notifications FOR INSERT TO anon WITH CHECK (true);


--
-- Name: offer_bundles Allow anon insert offer_bundles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert offer_bundles" ON public.offer_bundles FOR INSERT TO anon WITH CHECK (true);


--
-- Name: offer_cart_tiers Allow anon insert offer_cart_tiers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert offer_cart_tiers" ON public.offer_cart_tiers FOR INSERT TO anon WITH CHECK (true);


--
-- Name: offer_products Allow anon insert offer_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert offer_products" ON public.offer_products FOR INSERT TO anon WITH CHECK (true);


--
-- Name: offer_usage_logs Allow anon insert offer_usage_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert offer_usage_logs" ON public.offer_usage_logs FOR INSERT TO anon WITH CHECK (true);


--
-- Name: order_audit_logs Allow anon insert order_audit_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert order_audit_logs" ON public.order_audit_logs FOR INSERT TO anon WITH CHECK (true);


--
-- Name: order_items Allow anon insert order_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert order_items" ON public.order_items FOR INSERT TO anon WITH CHECK (true);


--
-- Name: orders Allow anon insert orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert orders" ON public.orders FOR INSERT TO anon WITH CHECK (true);


--
-- Name: privilege_cards_branch Allow anon insert privilege_cards_branch; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert privilege_cards_branch" ON public.privilege_cards_branch FOR INSERT TO anon WITH CHECK (true);


--
-- Name: privilege_cards_master Allow anon insert privilege_cards_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert privilege_cards_master" ON public.privilege_cards_master FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_task_assignments Allow anon insert quick_task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert quick_task_assignments" ON public.quick_task_assignments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_task_comments Allow anon insert quick_task_comments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert quick_task_comments" ON public.quick_task_comments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_task_completions Allow anon insert quick_task_completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert quick_task_completions" ON public.quick_task_completions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_task_files Allow anon insert quick_task_files; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert quick_task_files" ON public.quick_task_files FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_task_user_preferences Allow anon insert quick_task_user_preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert quick_task_user_preferences" ON public.quick_task_user_preferences FOR INSERT TO anon WITH CHECK (true);


--
-- Name: quick_tasks Allow anon insert quick_tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert quick_tasks" ON public.quick_tasks FOR INSERT TO anon WITH CHECK (true);


--
-- Name: receiving_task_templates Allow anon insert receiving_task_templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert receiving_task_templates" ON public.receiving_task_templates FOR INSERT TO anon WITH CHECK (true);


--
-- Name: receiving_tasks Allow anon insert receiving_tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert receiving_tasks" ON public.receiving_tasks FOR INSERT TO anon WITH CHECK (true);


--
-- Name: recurring_assignment_schedules Allow anon insert recurring_assignment_schedules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert recurring_assignment_schedules" ON public.recurring_assignment_schedules FOR INSERT TO anon WITH CHECK (true);


--
-- Name: recurring_schedule_check_log Allow anon insert recurring_schedule_check_log; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert recurring_schedule_check_log" ON public.recurring_schedule_check_log FOR INSERT TO anon WITH CHECK (true);


--
-- Name: requesters Allow anon insert requesters; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert requesters" ON public.requesters FOR INSERT TO anon WITH CHECK (true);


--
-- Name: shelf_paper_templates Allow anon insert shelf_paper_templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert shelf_paper_templates" ON public.shelf_paper_templates FOR INSERT TO anon WITH CHECK (true);


--
-- Name: task_assignments Allow anon insert task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert task_assignments" ON public.task_assignments FOR INSERT TO anon WITH CHECK (true);


--
-- Name: task_completions Allow anon insert task_completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert task_completions" ON public.task_completions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: task_images Allow anon insert task_images; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert task_images" ON public.task_images FOR INSERT TO anon WITH CHECK (true);


--
-- Name: task_reminder_logs Allow anon insert task_reminder_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert task_reminder_logs" ON public.task_reminder_logs FOR INSERT TO anon WITH CHECK (true);


--
-- Name: tasks Allow anon insert tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert tasks" ON public.tasks FOR INSERT TO anon WITH CHECK (true);


--
-- Name: user_audit_logs Allow anon insert user_audit_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert user_audit_logs" ON public.user_audit_logs FOR INSERT TO anon WITH CHECK (true);


--
-- Name: user_device_sessions Allow anon insert user_device_sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert user_device_sessions" ON public.user_device_sessions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: user_password_history Allow anon insert user_password_history; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert user_password_history" ON public.user_password_history FOR INSERT TO anon WITH CHECK (true);


--
-- Name: user_sessions Allow anon insert user_sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert user_sessions" ON public.user_sessions FOR INSERT TO anon WITH CHECK (true);


--
-- Name: users Allow anon insert users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert users" ON public.users FOR INSERT TO anon WITH CHECK (true);


--
-- Name: variation_audit_log Allow anon insert variation_audit_log; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert variation_audit_log" ON public.variation_audit_log FOR INSERT TO anon WITH CHECK (true);


--
-- Name: view_offer Allow anon insert view_offer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert view_offer" ON public.view_offer FOR INSERT WITH CHECK (true);


--
-- Name: security_code_scroll_texts Allow anon read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon read" ON public.security_code_scroll_texts FOR SELECT TO anon USING (true);


--
-- Name: gift_wheel_coupons Allow authenticated all gift_wheel_coupons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated all gift_wheel_coupons" ON public.gift_wheel_coupons TO authenticated USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_rewards Allow authenticated all gift_wheel_rewards; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated all gift_wheel_rewards" ON public.gift_wheel_rewards TO authenticated USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_settings Allow authenticated all gift_wheel_settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated all gift_wheel_settings" ON public.gift_wheel_settings TO authenticated USING (true) WITH CHECK (true);


--
-- Name: gift_wheel_spins Allow authenticated all gift_wheel_spins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated all gift_wheel_spins" ON public.gift_wheel_spins TO authenticated USING (true) WITH CHECK (true);


--
-- Name: security_code_scroll_texts Allow authenticated delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated delete" ON public.security_code_scroll_texts FOR DELETE TO authenticated USING (true);


--
-- Name: wa_catalog_orders Allow authenticated full access on wa_catalog_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated full access on wa_catalog_orders" ON public.wa_catalog_orders TO authenticated USING (true) WITH CHECK (true);


--
-- Name: wa_catalog_products Allow authenticated full access on wa_catalog_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated full access on wa_catalog_products" ON public.wa_catalog_products TO authenticated USING (true) WITH CHECK (true);


--
-- Name: wa_catalogs Allow authenticated full access on wa_catalogs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated full access on wa_catalogs" ON public.wa_catalogs TO authenticated USING (true) WITH CHECK (true);


--
-- Name: security_code_scroll_texts Allow authenticated insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated insert" ON public.security_code_scroll_texts FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: security_code_scroll_texts Allow authenticated read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated read" ON public.security_code_scroll_texts FOR SELECT TO authenticated USING (true);


--
-- Name: security_code_scroll_texts Allow authenticated update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated update" ON public.security_code_scroll_texts FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: deleted_bundle_offers Allow authenticated users to archive offers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to archive offers" ON public.deleted_bundle_offers FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: erp_connections Allow authenticated users to create ERP connections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to create ERP connections" ON public.erp_connections FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: expense_requisitions Allow authenticated users to create expense requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to create expense requisitions" ON public.expense_requisitions FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: expense_scheduler Allow authenticated users to create expense scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to create expense scheduler" ON public.expense_scheduler FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler Allow authenticated users to create non approved scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to create non approved scheduler" ON public.non_approved_payment_scheduler FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: privilege_cards_branch Allow authenticated users to create privilege_cards_branch; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to create privilege_cards_branch" ON public.privilege_cards_branch FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: privilege_cards_master Allow authenticated users to create privilege_cards_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to create privilege_cards_master" ON public.privilege_cards_master FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: view_offer Allow authenticated users to create view_offer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to create view_offer" ON public.view_offer FOR INSERT WITH CHECK (true);


--
-- Name: erp_connections Allow authenticated users to delete ERP connections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to delete ERP connections" ON public.erp_connections FOR DELETE TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to delete requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to delete requisitions" ON public.expense_requisitions FOR DELETE TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to insert requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to insert requisitions" ON public.expense_requisitions FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: erp_connections Allow authenticated users to read ERP connections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read ERP connections" ON public.erp_connections FOR SELECT TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to read expense requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read expense requisitions" ON public.expense_requisitions FOR SELECT TO authenticated USING (true);


--
-- Name: expense_scheduler Allow authenticated users to read expense scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read expense scheduler" ON public.expense_scheduler FOR SELECT TO authenticated USING (true);


--
-- Name: non_approved_payment_scheduler Allow authenticated users to read non approved scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read non approved scheduler" ON public.non_approved_payment_scheduler FOR SELECT TO authenticated USING (true);


--
-- Name: expense_parent_categories Allow authenticated users to read parent categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read parent categories" ON public.expense_parent_categories FOR SELECT TO authenticated USING (true);


--
-- Name: privilege_cards_branch Allow authenticated users to read privilege_cards_branch; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read privilege_cards_branch" ON public.privilege_cards_branch FOR SELECT TO authenticated USING (true);


--
-- Name: privilege_cards_master Allow authenticated users to read privilege_cards_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read privilege_cards_master" ON public.privilege_cards_master FOR SELECT TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to read requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read requisitions" ON public.expense_requisitions FOR SELECT TO authenticated USING (true);


--
-- Name: erp_daily_sales Allow authenticated users to read sales data; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read sales data" ON public.erp_daily_sales FOR SELECT TO authenticated USING (true);


--
-- Name: expense_sub_categories Allow authenticated users to read sub categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read sub categories" ON public.expense_sub_categories FOR SELECT TO authenticated USING (true);


--
-- Name: view_offer Allow authenticated users to read view_offer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read view_offer" ON public.view_offer FOR SELECT USING (true);


--
-- Name: erp_connections Allow authenticated users to update ERP connections; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to update ERP connections" ON public.erp_connections FOR UPDATE TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to update expense requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to update expense requisitions" ON public.expense_requisitions FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: expense_scheduler Allow authenticated users to update expense scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to update expense scheduler" ON public.expense_scheduler FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler Allow authenticated users to update non approved scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to update non approved scheduler" ON public.non_approved_payment_scheduler FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: privilege_cards_branch Allow authenticated users to update privilege_cards_branch; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to update privilege_cards_branch" ON public.privilege_cards_branch FOR UPDATE TO authenticated USING (true);


--
-- Name: privilege_cards_master Allow authenticated users to update privilege_cards_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to update privilege_cards_master" ON public.privilege_cards_master FOR UPDATE TO authenticated USING (true);


--
-- Name: expense_requisitions Allow authenticated users to update requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to update requisitions" ON public.expense_requisitions FOR UPDATE TO authenticated USING (true);


--
-- Name: view_offer Allow authenticated users to update view_offer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to update view_offer" ON public.view_offer FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: deleted_bundle_offers Allow authenticated users to view deleted offers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to view deleted offers" ON public.deleted_bundle_offers FOR SELECT TO authenticated USING (true);


--
-- Name: bogo_offer_rules Allow read access to bogo_offer_rules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow read access to bogo_offer_rules" ON public.bogo_offer_rules FOR SELECT TO authenticated USING (true);


--
-- Name: bogo_offer_rules Allow service role full access to bogo_offer_rules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to bogo_offer_rules" ON public.bogo_offer_rules TO service_role USING (true) WITH CHECK (true);


--
-- Name: hr_employee_master Allow service role full access to hr_employee_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to hr_employee_master" ON public.hr_employee_master TO authenticated USING (true) WITH CHECK (true);


--
-- Name: quick_task_assignments Allow service role full access to quick_task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to quick_task_assignments" ON public.quick_task_assignments TO authenticated USING (true) WITH CHECK (true);


--
-- Name: quick_task_completions Allow service role full access to quick_task_completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to quick_task_completions" ON public.quick_task_completions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: quick_tasks Allow service role full access to quick_tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to quick_tasks" ON public.quick_tasks TO authenticated USING (true) WITH CHECK (true);


--
-- Name: task_assignments Allow service role full access to task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to task_assignments" ON public.task_assignments TO authenticated USING (true) WITH CHECK (true);


--
-- Name: task_completions Allow service role full access to task_completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to task_completions" ON public.task_completions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: tasks Allow service role full access to tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to tasks" ON public.tasks TO authenticated USING (true) WITH CHECK (true);


--
-- Name: users Allow service role full access to users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role full access to users" ON public.users TO authenticated USING (true) WITH CHECK (true);


--
-- Name: erp_daily_sales Allow service role to manage sales data; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow service role to manage sales data" ON public.erp_daily_sales TO service_role USING (true);


--
-- Name: app_icons Anyone can view app icons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view app icons" ON public.app_icons FOR SELECT USING (true);


--
-- Name: app_icons Authenticated users can delete app icons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can delete app icons" ON public.app_icons FOR DELETE TO authenticated USING (true);


--
-- Name: app_icons Authenticated users can insert app icons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can insert app icons" ON public.app_icons FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: frontend_builds Authenticated users can insert frontend_builds; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can insert frontend_builds" ON public.frontend_builds FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: offer_products Authenticated users can manage offer products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can manage offer products" ON public.offer_products TO authenticated USING (true) WITH CHECK (true);


--
-- Name: frontend_builds Authenticated users can read frontend_builds; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read frontend_builds" ON public.frontend_builds FOR SELECT TO authenticated USING (true);


--
-- Name: app_icons Authenticated users can update app icons; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can update app icons" ON public.app_icons FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: task_reminder_logs Authenticated users can view all reminder logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can view all reminder logs" ON public.task_reminder_logs FOR SELECT USING ((auth.uid() IS NOT NULL));


--
-- Name: notifications Emergency: Allow all inserts for notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Emergency: Allow all inserts for notifications" ON public.notifications FOR INSERT WITH CHECK (true);


--
-- Name: task_assignments Emergency: Allow all inserts for task_assignments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Emergency: Allow all inserts for task_assignments" ON public.task_assignments FOR INSERT WITH CHECK (true);


--
-- Name: tasks Emergency: Allow all inserts for tasks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Emergency: Allow all inserts for tasks" ON public.tasks FOR INSERT WITH CHECK (true);


--
-- Name: social_links Enable all access for social_links; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all access for social_links" ON public.social_links USING (true) WITH CHECK (true);


--
-- Name: view_offer Enable all access for view_offer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all access for view_offer" ON public.view_offer USING (true) WITH CHECK (true);


--
-- Name: system_api_keys Enable all access to system_api_keys; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all access to system_api_keys" ON public.system_api_keys USING (true) WITH CHECK (true);


--
-- Name: biometric_connections Enable delete for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable delete for authenticated users" ON public.biometric_connections FOR DELETE USING ((auth.role() = 'authenticated'::text));


--
-- Name: biometric_connections Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable insert for authenticated users" ON public.biometric_connections FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--
-- Name: biometric_connections Enable read for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable read for authenticated users" ON public.biometric_connections FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: biometric_connections Enable update for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable update for authenticated users" ON public.biometric_connections FOR UPDATE USING ((auth.role() = 'authenticated'::text));


--
-- Name: quick_task_completions Managers can verify completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Managers can verify completions" ON public.quick_task_completions FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.user_type = 'global'::public.user_type_enum)))));


--
-- Name: quick_task_completions Managers can view all completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Managers can view all completions" ON public.quick_task_completions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.user_type = 'global'::public.user_type_enum)))));


--
-- Name: recurring_schedule_check_log Only global users can view check logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only global users can view check logs" ON public.recurring_schedule_check_log FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.id = auth.uid()) AND (users.user_type = 'global'::public.user_type_enum)))));


--
-- Name: offer_products Public can view active offer products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public can view active offer products" ON public.offer_products FOR SELECT USING ((offer_id IN ( SELECT offers.id
   FROM public.offers
  WHERE ((offers.is_active = true) AND (offers.start_date <= now()) AND (offers.end_date >= now())))));


--
-- Name: task_reminder_logs Service role can insert reminder logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role can insert reminder logs" ON public.task_reminder_logs FOR INSERT WITH CHECK (true);


--
-- Name: erp_sync_logs Service role full access on erp_sync_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on erp_sync_logs" ON public.erp_sync_logs USING (true) WITH CHECK (true);


--
-- Name: wa_ai_bot_config Service role full access on wa_ai_bot_config; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on wa_ai_bot_config" ON public.wa_ai_bot_config USING (true) WITH CHECK (true);


--
-- Name: wa_auto_reply_triggers Service role full access on wa_auto_reply_triggers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on wa_auto_reply_triggers" ON public.wa_auto_reply_triggers USING (true) WITH CHECK (true);


--
-- Name: wa_contact_group_members Service role full access on wa_contact_group_members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on wa_contact_group_members" ON public.wa_contact_group_members USING (true) WITH CHECK (true);


--
-- Name: wa_contact_groups Service role full access on wa_contact_groups; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on wa_contact_groups" ON public.wa_contact_groups USING (true) WITH CHECK (true);


--
-- Name: wa_messages Service role full access on wa_messages; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on wa_messages" ON public.wa_messages USING (true) WITH CHECK (true);


--
-- Name: wa_settings Service role full access on wa_settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on wa_settings" ON public.wa_settings USING (true) WITH CHECK (true);


--
-- Name: whatsapp_message_log Service role full access on whatsapp_message_log; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on whatsapp_message_log" ON public.whatsapp_message_log USING (true) WITH CHECK (true);


--
-- Name: frontend_builds Service role full access to frontend_builds; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access to frontend_builds" ON public.frontend_builds TO service_role USING (true) WITH CHECK (true);


--
-- Name: expense_requisitions Service role has full access to expense requisitions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role has full access to expense requisitions" ON public.expense_requisitions TO service_role USING (true) WITH CHECK (true);


--
-- Name: expense_scheduler Service role has full access to expense scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role has full access to expense scheduler" ON public.expense_scheduler TO service_role USING (true) WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler Service role has full access to non approved scheduler; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role has full access to non approved scheduler" ON public.non_approved_payment_scheduler TO service_role USING (true) WITH CHECK (true);


--
-- Name: privilege_cards_branch Service role has full access to privilege_cards_branch; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role has full access to privilege_cards_branch" ON public.privilege_cards_branch TO service_role USING (true);


--
-- Name: privilege_cards_master Service role has full access to privilege_cards_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role has full access to privilege_cards_master" ON public.privilege_cards_master TO service_role USING (true);


--
-- Name: view_offer Service role has full access to view_offer; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role has full access to view_offer" ON public.view_offer USING (true) WITH CHECK (true);


--
-- Name: task_assignments Simple create task assignments policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple create task assignments policy" ON public.task_assignments FOR INSERT WITH CHECK (true);


--
-- Name: POLICY "Simple create task assignments policy" ON task_assignments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple create task assignments policy" ON public.task_assignments IS 'Allow all users to create task assignments';


--
-- Name: task_completions Simple create task completions policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple create task completions policy" ON public.task_completions FOR INSERT WITH CHECK (true);


--
-- Name: POLICY "Simple create task completions policy" ON task_completions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple create task completions policy" ON public.task_completions IS 'Allow all users to create task completions';


--
-- Name: task_images Simple create task images policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple create task images policy" ON public.task_images FOR INSERT WITH CHECK (true);


--
-- Name: POLICY "Simple create task images policy" ON task_images; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple create task images policy" ON public.task_images IS 'Allow all users to create task images';


--
-- Name: tasks Simple create tasks policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple create tasks policy" ON public.tasks FOR INSERT WITH CHECK (true);


--
-- Name: POLICY "Simple create tasks policy" ON tasks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple create tasks policy" ON public.tasks IS 'Allow all users to create tasks';


--
-- Name: task_images Simple delete task images policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple delete task images policy" ON public.task_images FOR DELETE USING (true);


--
-- Name: POLICY "Simple delete task images policy" ON task_images; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple delete task images policy" ON public.task_images IS 'Allow all users to delete task images';


--
-- Name: task_assignments Simple update task assignments policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple update task assignments policy" ON public.task_assignments FOR UPDATE USING (true);


--
-- Name: POLICY "Simple update task assignments policy" ON task_assignments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple update task assignments policy" ON public.task_assignments IS 'Allow all users to update task assignments';


--
-- Name: task_completions Simple update task completions policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple update task completions policy" ON public.task_completions FOR UPDATE USING (true);


--
-- Name: POLICY "Simple update task completions policy" ON task_completions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple update task completions policy" ON public.task_completions IS 'Allow all users to update task completions';


--
-- Name: task_images Simple update task images policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple update task images policy" ON public.task_images FOR UPDATE USING (true);


--
-- Name: POLICY "Simple update task images policy" ON task_images; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple update task images policy" ON public.task_images IS 'Allow all users to update task images';


--
-- Name: tasks Simple update tasks policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple update tasks policy" ON public.tasks FOR UPDATE USING (true);


--
-- Name: POLICY "Simple update tasks policy" ON tasks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple update tasks policy" ON public.tasks IS 'Allow all users to update tasks';


--
-- Name: task_assignments Simple view task assignments policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple view task assignments policy" ON public.task_assignments FOR SELECT USING (true);


--
-- Name: POLICY "Simple view task assignments policy" ON task_assignments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple view task assignments policy" ON public.task_assignments IS 'Allow viewing all task assignments';


--
-- Name: task_completions Simple view task completions policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple view task completions policy" ON public.task_completions FOR SELECT USING (true);


--
-- Name: POLICY "Simple view task completions policy" ON task_completions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple view task completions policy" ON public.task_completions IS 'Allow viewing all task completions';


--
-- Name: task_images Simple view task images policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple view task images policy" ON public.task_images FOR SELECT USING (true);


--
-- Name: POLICY "Simple view task images policy" ON task_images; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple view task images policy" ON public.task_images IS 'Allow viewing all task images';


--
-- Name: tasks Simple view tasks policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Simple view tasks policy" ON public.tasks FOR SELECT USING ((deleted_at IS NULL));


--
-- Name: POLICY "Simple view tasks policy" ON tasks; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Simple view tasks policy" ON public.tasks IS 'Allow viewing all non-deleted tasks';


--
-- Name: variation_audit_log System can insert variation audit logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "System can insert variation audit logs" ON public.variation_audit_log FOR INSERT WITH CHECK (true);


--
-- Name: shelf_paper_templates Users can create templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can create templates" ON public.shelf_paper_templates FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: offer_products Users can delete offer products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete offer products" ON public.offer_products FOR DELETE USING (true);


--
-- Name: shelf_paper_templates Users can delete own templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own templates" ON public.shelf_paper_templates FOR DELETE USING ((created_by = auth.uid()));


--
-- Name: quick_task_user_preferences Users can delete their own preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete their own preferences" ON public.quick_task_user_preferences FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: offer_products Users can insert offer products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert offer products" ON public.offer_products FOR INSERT WITH CHECK (true);


--
-- Name: notification_read_states Users can insert own read states; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own read states" ON public.notification_read_states FOR INSERT WITH CHECK (true);


--
-- Name: requesters Users can insert requesters; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert requesters" ON public.requesters FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_completions Users can insert their own completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own completions" ON public.quick_task_completions FOR INSERT WITH CHECK ((completed_by_user_id = auth.uid()));


--
-- Name: quick_task_user_preferences Users can insert their own preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert their own preferences" ON public.quick_task_user_preferences FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_device_sessions Users can manage their own device sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can manage their own device sessions" ON public.user_device_sessions USING ((user_id = auth.uid()));


--
-- Name: offer_products Users can update offer products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update offer products" ON public.offer_products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: notification_read_states Users can update own read states; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own read states" ON public.notification_read_states FOR UPDATE USING (true);


--
-- Name: shelf_paper_templates Users can update own templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own templates" ON public.shelf_paper_templates FOR UPDATE USING ((created_by = auth.uid()));


--
-- Name: requesters Users can update requesters; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update requesters" ON public.requesters FOR UPDATE USING (true);


--
-- Name: quick_task_completions Users can update their own completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own completions" ON public.quick_task_completions FOR UPDATE USING ((completed_by_user_id = auth.uid()));


--
-- Name: quick_task_user_preferences Users can update their own preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update their own preferences" ON public.quick_task_user_preferences FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: flyer_templates Users can view active flyer templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view active flyer templates" ON public.flyer_templates FOR SELECT TO authenticated USING (((is_active = true) AND (deleted_at IS NULL)));


--
-- Name: shelf_paper_templates Users can view active templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view active templates" ON public.shelf_paper_templates FOR SELECT USING ((is_active = true));


--
-- Name: requesters Users can view all requesters; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view all requesters" ON public.requesters FOR SELECT USING (true);


--
-- Name: offer_products Users can view offer products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view offer products" ON public.offer_products FOR SELECT USING (true);


--
-- Name: notification_read_states Users can view own read states; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own read states" ON public.notification_read_states FOR SELECT USING (true);


--
-- Name: quick_task_completions Users can view their own completions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own completions" ON public.quick_task_completions FOR SELECT USING ((completed_by_user_id = auth.uid()));


--
-- Name: quick_task_user_preferences Users can view their own preferences; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own preferences" ON public.quick_task_user_preferences FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: task_reminder_logs Users can view their own reminder logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own reminder logs" ON public.task_reminder_logs FOR SELECT USING ((assigned_to_user_id = auth.uid()));


--
-- Name: variation_audit_log Users can view variation audit logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view variation audit logs" ON public.variation_audit_log FOR SELECT USING (true);


--
-- Name: access_code_otp; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.access_code_otp ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_cart_tiers admin_all_offer_cart_tiers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_all_offer_cart_tiers ON public.offer_cart_tiers USING (true) WITH CHECK (true);


--
-- Name: ai_chat_guide; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_chat_guide ENABLE ROW LEVEL SECURITY;

--
-- Name: lease_rent_special_changes allow_all_lease_rent_special_changes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_lease_rent_special_changes ON public.lease_rent_special_changes USING (true) WITH CHECK (true);


--
-- Name: approval_permissions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.approval_permissions USING (true) WITH CHECK (true);


--
-- Name: biometric_connections allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.biometric_connections USING (true) WITH CHECK (true);


--
-- Name: bogo_offer_rules allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.bogo_offer_rules USING (true) WITH CHECK (true);


--
-- Name: coupon_campaigns allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.coupon_campaigns USING (true) WITH CHECK (true);


--
-- Name: coupon_claims allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.coupon_claims USING (true) WITH CHECK (true);


--
-- Name: coupon_eligible_customers allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.coupon_eligible_customers USING (true) WITH CHECK (true);


--
-- Name: coupon_products allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.coupon_products USING (true) WITH CHECK (true);


--
-- Name: customer_access_code_history allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.customer_access_code_history USING (true) WITH CHECK (true);


--
-- Name: customer_app_media allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.customer_app_media USING (true) WITH CHECK (true);


--
-- Name: customer_recovery_requests allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.customer_recovery_requests USING (true) WITH CHECK (true);


--
-- Name: customers allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.customers USING (true) WITH CHECK (true);


--
-- Name: deleted_bundle_offers allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.deleted_bundle_offers USING (true) WITH CHECK (true);


--
-- Name: delivery_fee_tiers allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.delivery_fee_tiers USING (true) WITH CHECK (true);


--
-- Name: delivery_service_settings allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.delivery_service_settings USING (true) WITH CHECK (true);


--
-- Name: employee_fine_payments allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.employee_fine_payments USING (true) WITH CHECK (true);


--
-- Name: erp_connections allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.erp_connections USING (true) WITH CHECK (true);


--
-- Name: erp_daily_sales allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.erp_daily_sales USING (true) WITH CHECK (true);


--
-- Name: expense_parent_categories allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.expense_parent_categories USING (true) WITH CHECK (true);


--
-- Name: expense_requisitions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.expense_requisitions USING (true) WITH CHECK (true);


--
-- Name: expense_scheduler allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.expense_scheduler USING (true) WITH CHECK (true);


--
-- Name: expense_sub_categories allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.expense_sub_categories USING (true) WITH CHECK (true);


--
-- Name: flyer_offer_products allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.flyer_offer_products USING (true) WITH CHECK (true);


--
-- Name: flyer_offers allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.flyer_offers USING (true) WITH CHECK (true);


--
-- Name: flyer_templates allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.flyer_templates USING (true) WITH CHECK (true);


--
-- Name: hr_departments allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.hr_departments USING (true) WITH CHECK (true);


--
-- Name: hr_employees allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.hr_employees USING (true) WITH CHECK (true);


--
-- Name: hr_fingerprint_transactions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.hr_fingerprint_transactions USING (true) WITH CHECK (true);


--
-- Name: hr_levels allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.hr_levels USING (true) WITH CHECK (true);


--
-- Name: hr_position_assignments allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.hr_position_assignments USING (true) WITH CHECK (true);


--
-- Name: hr_position_reporting_template allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.hr_position_reporting_template USING (true) WITH CHECK (true);


--
-- Name: hr_positions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.hr_positions USING (true) WITH CHECK (true);


--
-- Name: interface_permissions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.interface_permissions USING (true) WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.non_approved_payment_scheduler USING (true) WITH CHECK (true);


--
-- Name: notification_attachments allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.notification_attachments USING (true) WITH CHECK (true);


--
-- Name: notification_read_states allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.notification_read_states USING (true) WITH CHECK (true);


--
-- Name: notification_recipients allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.notification_recipients USING (true) WITH CHECK (true);


--
-- Name: notifications allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.notifications USING (true) WITH CHECK (true);


--
-- Name: offer_bundles allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.offer_bundles USING (true) WITH CHECK (true);


--
-- Name: offer_cart_tiers allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.offer_cart_tiers USING (true) WITH CHECK (true);


--
-- Name: offer_products allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.offer_products USING (true) WITH CHECK (true);


--
-- Name: offer_usage_logs allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.offer_usage_logs USING (true) WITH CHECK (true);


--
-- Name: order_audit_logs allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.order_audit_logs USING (true) WITH CHECK (true);


--
-- Name: order_items allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.order_items USING (true) WITH CHECK (true);


--
-- Name: orders allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.orders USING (true) WITH CHECK (true);


--
-- Name: privilege_cards_branch allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.privilege_cards_branch USING (true);


--
-- Name: privilege_cards_master allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.privilege_cards_master USING (true);


--
-- Name: quick_task_assignments allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.quick_task_assignments USING (true) WITH CHECK (true);


--
-- Name: quick_task_comments allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.quick_task_comments USING (true) WITH CHECK (true);


--
-- Name: quick_task_completions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.quick_task_completions USING (true) WITH CHECK (true);


--
-- Name: quick_task_files allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.quick_task_files USING (true) WITH CHECK (true);


--
-- Name: quick_task_user_preferences allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.quick_task_user_preferences USING (true) WITH CHECK (true);


--
-- Name: quick_tasks allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.quick_tasks USING (true) WITH CHECK (true);


--
-- Name: receiving_task_templates allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.receiving_task_templates USING (true) WITH CHECK (true);


--
-- Name: receiving_tasks allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.receiving_tasks USING (true) WITH CHECK (true);


--
-- Name: recurring_assignment_schedules allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.recurring_assignment_schedules USING (true) WITH CHECK (true);


--
-- Name: recurring_schedule_check_log allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.recurring_schedule_check_log USING (true) WITH CHECK (true);


--
-- Name: requesters allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.requesters USING (true) WITH CHECK (true);


--
-- Name: shelf_paper_templates allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.shelf_paper_templates USING (true) WITH CHECK (true);


--
-- Name: task_assignments allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.task_assignments USING (true) WITH CHECK (true);


--
-- Name: task_completions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.task_completions USING (true) WITH CHECK (true);


--
-- Name: task_images allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.task_images USING (true) WITH CHECK (true);


--
-- Name: task_reminder_logs allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.task_reminder_logs USING (true) WITH CHECK (true);


--
-- Name: tasks allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.tasks USING (true) WITH CHECK (true);


--
-- Name: user_audit_logs allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.user_audit_logs USING (true) WITH CHECK (true);


--
-- Name: user_device_sessions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.user_device_sessions USING (true) WITH CHECK (true);


--
-- Name: user_erp_credentials allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.user_erp_credentials USING (true) WITH CHECK (true);


--
-- Name: user_password_history allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.user_password_history USING (true) WITH CHECK (true);


--
-- Name: user_sessions allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.user_sessions USING (true) WITH CHECK (true);


--
-- Name: users allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.users USING (true) WITH CHECK (true);


--
-- Name: variation_audit_log allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.variation_audit_log USING (true) WITH CHECK (true);


--
-- Name: view_offer allow_all_operations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_operations ON public.view_offer USING (true) WITH CHECK (true);


--
-- Name: lease_rent_payment_entries allow_all_payment_entries; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_payment_entries ON public.lease_rent_payment_entries USING (true) WITH CHECK (true);


--
-- Name: wa_auto_reply_triggers allow_all_wa_auto_reply; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_wa_auto_reply ON public.wa_auto_reply_triggers USING (true) WITH CHECK (true);


--
-- Name: wa_bot_flows allow_all_wa_bot_flows; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_wa_bot_flows ON public.wa_bot_flows USING (true) WITH CHECK (true);


--
-- Name: wa_settings allow_all_wa_settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_all_wa_settings ON public.wa_settings USING (true) WITH CHECK (true);


--
-- Name: approval_permissions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.approval_permissions FOR DELETE USING (true);


--
-- Name: biometric_connections allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.biometric_connections FOR DELETE USING (true);


--
-- Name: bogo_offer_rules allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.bogo_offer_rules FOR DELETE USING (true);


--
-- Name: branches allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.branches FOR DELETE USING (true);


--
-- Name: button_main_sections allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.button_main_sections FOR DELETE USING (true);


--
-- Name: button_permissions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.button_permissions FOR DELETE USING (true);


--
-- Name: button_sub_sections allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.button_sub_sections FOR DELETE USING (true);


--
-- Name: coupon_campaigns allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.coupon_campaigns FOR DELETE USING (true);


--
-- Name: coupon_claims allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.coupon_claims FOR DELETE USING (true);


--
-- Name: coupon_eligible_customers allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.coupon_eligible_customers FOR DELETE USING (true);


--
-- Name: coupon_products allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.coupon_products FOR DELETE USING (true);


--
-- Name: customer_access_code_history allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.customer_access_code_history FOR DELETE USING (true);


--
-- Name: customer_app_media allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.customer_app_media FOR DELETE USING (true);


--
-- Name: customer_recovery_requests allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.customer_recovery_requests FOR DELETE USING (true);


--
-- Name: customers allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.customers FOR DELETE USING (true);


--
-- Name: deleted_bundle_offers allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.deleted_bundle_offers FOR DELETE USING (true);


--
-- Name: delivery_fee_tiers allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.delivery_fee_tiers FOR DELETE USING (true);


--
-- Name: delivery_service_settings allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.delivery_service_settings FOR DELETE USING (true);


--
-- Name: employee_fine_payments allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.employee_fine_payments FOR DELETE USING (true);


--
-- Name: erp_connections allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.erp_connections FOR DELETE USING (true);


--
-- Name: erp_daily_sales allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.erp_daily_sales FOR DELETE USING (true);


--
-- Name: expense_parent_categories allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.expense_parent_categories FOR DELETE USING (true);


--
-- Name: expense_requisitions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.expense_requisitions FOR DELETE USING (true);


--
-- Name: expense_scheduler allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.expense_scheduler FOR DELETE USING (true);


--
-- Name: expense_sub_categories allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.expense_sub_categories FOR DELETE USING (true);


--
-- Name: flyer_offer_products allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.flyer_offer_products FOR DELETE USING (true);


--
-- Name: flyer_offers allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.flyer_offers FOR DELETE USING (true);


--
-- Name: flyer_templates allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.flyer_templates FOR DELETE USING (true);


--
-- Name: hr_departments allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.hr_departments FOR DELETE USING (true);


--
-- Name: hr_employees allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.hr_employees FOR DELETE USING (true);


--
-- Name: hr_fingerprint_transactions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.hr_fingerprint_transactions FOR DELETE USING (true);


--
-- Name: hr_levels allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.hr_levels FOR DELETE USING (true);


--
-- Name: hr_position_assignments allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.hr_position_assignments FOR DELETE USING (true);


--
-- Name: hr_position_reporting_template allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.hr_position_reporting_template FOR DELETE USING (true);


--
-- Name: hr_positions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.hr_positions FOR DELETE USING (true);


--
-- Name: interface_permissions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.interface_permissions FOR DELETE USING (true);


--
-- Name: non_approved_payment_scheduler allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.non_approved_payment_scheduler FOR DELETE USING (true);


--
-- Name: notification_attachments allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.notification_attachments FOR DELETE USING (true);


--
-- Name: notification_read_states allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.notification_read_states FOR DELETE USING (true);


--
-- Name: notification_recipients allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.notification_recipients FOR DELETE USING (true);


--
-- Name: notifications allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.notifications FOR DELETE USING (true);


--
-- Name: offer_bundles allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.offer_bundles FOR DELETE USING (true);


--
-- Name: offer_cart_tiers allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.offer_cart_tiers FOR DELETE USING (true);


--
-- Name: offer_products allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.offer_products FOR DELETE USING (true);


--
-- Name: offer_usage_logs allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.offer_usage_logs FOR DELETE USING (true);


--
-- Name: order_audit_logs allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.order_audit_logs FOR DELETE USING (true);


--
-- Name: order_items allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.order_items FOR DELETE USING (true);


--
-- Name: orders allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.orders FOR DELETE USING (true);


--
-- Name: privilege_cards_branch allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.privilege_cards_branch FOR DELETE USING (true);


--
-- Name: privilege_cards_master allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.privilege_cards_master FOR DELETE USING (true);


--
-- Name: quick_task_assignments allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.quick_task_assignments FOR DELETE USING (true);


--
-- Name: quick_task_comments allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.quick_task_comments FOR DELETE USING (true);


--
-- Name: quick_task_completions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.quick_task_completions FOR DELETE USING (true);


--
-- Name: quick_task_files allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.quick_task_files FOR DELETE USING (true);


--
-- Name: quick_task_user_preferences allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.quick_task_user_preferences FOR DELETE USING (true);


--
-- Name: quick_tasks allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.quick_tasks FOR DELETE USING (true);


--
-- Name: receiving_records allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.receiving_records FOR DELETE USING (true);


--
-- Name: receiving_task_templates allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.receiving_task_templates FOR DELETE USING (true);


--
-- Name: receiving_tasks allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.receiving_tasks FOR DELETE USING (true);


--
-- Name: recurring_assignment_schedules allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.recurring_assignment_schedules FOR DELETE USING (true);


--
-- Name: recurring_schedule_check_log allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.recurring_schedule_check_log FOR DELETE USING (true);


--
-- Name: requesters allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.requesters FOR DELETE USING (true);


--
-- Name: shelf_paper_templates allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.shelf_paper_templates FOR DELETE USING (true);


--
-- Name: sidebar_buttons allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.sidebar_buttons FOR DELETE USING (true);


--
-- Name: task_assignments allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.task_assignments FOR DELETE USING (true);


--
-- Name: task_completions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.task_completions FOR DELETE USING (true);


--
-- Name: task_images allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.task_images FOR DELETE USING (true);


--
-- Name: task_reminder_logs allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.task_reminder_logs FOR DELETE USING (true);


--
-- Name: tasks allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.tasks FOR DELETE USING (true);


--
-- Name: user_audit_logs allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.user_audit_logs FOR DELETE USING (true);


--
-- Name: user_device_sessions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.user_device_sessions FOR DELETE USING (true);


--
-- Name: user_password_history allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.user_password_history FOR DELETE USING (true);


--
-- Name: user_sessions allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.user_sessions FOR DELETE USING (true);


--
-- Name: users allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.users FOR DELETE USING (true);


--
-- Name: variation_audit_log allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.variation_audit_log FOR DELETE USING (true);


--
-- Name: vendors allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.vendors FOR DELETE USING (true);


--
-- Name: view_offer allow_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete ON public.view_offer FOR DELETE USING (true);


--
-- Name: products allow_delete_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete_all ON public.products FOR DELETE USING (true);


--
-- Name: offers allow_delete_offers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_delete_offers ON public.offers FOR DELETE USING (true);


--
-- Name: approval_permissions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.approval_permissions FOR INSERT WITH CHECK (true);


--
-- Name: biometric_connections allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.biometric_connections FOR INSERT WITH CHECK (true);


--
-- Name: bogo_offer_rules allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.bogo_offer_rules FOR INSERT WITH CHECK (true);


--
-- Name: branches allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.branches FOR INSERT WITH CHECK (true);


--
-- Name: button_main_sections allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.button_main_sections FOR INSERT WITH CHECK (true);


--
-- Name: button_permissions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.button_permissions FOR INSERT WITH CHECK (true);


--
-- Name: button_sub_sections allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.button_sub_sections FOR INSERT WITH CHECK (true);


--
-- Name: coupon_campaigns allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.coupon_campaigns FOR INSERT WITH CHECK (true);


--
-- Name: coupon_claims allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.coupon_claims FOR INSERT WITH CHECK (true);


--
-- Name: coupon_eligible_customers allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.coupon_eligible_customers FOR INSERT WITH CHECK (true);


--
-- Name: coupon_products allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.coupon_products FOR INSERT WITH CHECK (true);


--
-- Name: customer_access_code_history allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.customer_access_code_history FOR INSERT WITH CHECK (true);


--
-- Name: customer_app_media allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.customer_app_media FOR INSERT WITH CHECK (true);


--
-- Name: customer_recovery_requests allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.customer_recovery_requests FOR INSERT WITH CHECK (true);


--
-- Name: customers allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.customers FOR INSERT WITH CHECK (true);


--
-- Name: deleted_bundle_offers allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.deleted_bundle_offers FOR INSERT WITH CHECK (true);


--
-- Name: delivery_fee_tiers allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.delivery_fee_tiers FOR INSERT WITH CHECK (true);


--
-- Name: delivery_service_settings allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.delivery_service_settings FOR INSERT WITH CHECK (true);


--
-- Name: employee_fine_payments allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.employee_fine_payments FOR INSERT WITH CHECK (true);


--
-- Name: erp_connections allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.erp_connections FOR INSERT WITH CHECK (true);


--
-- Name: erp_daily_sales allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.erp_daily_sales FOR INSERT WITH CHECK (true);


--
-- Name: expense_parent_categories allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.expense_parent_categories FOR INSERT WITH CHECK (true);


--
-- Name: expense_requisitions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.expense_requisitions FOR INSERT WITH CHECK (true);


--
-- Name: expense_scheduler allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.expense_scheduler FOR INSERT WITH CHECK (true);


--
-- Name: expense_sub_categories allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.expense_sub_categories FOR INSERT WITH CHECK (true);


--
-- Name: flyer_offer_products allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.flyer_offer_products FOR INSERT WITH CHECK (true);


--
-- Name: flyer_offers allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.flyer_offers FOR INSERT WITH CHECK (true);


--
-- Name: flyer_templates allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.flyer_templates FOR INSERT WITH CHECK (true);


--
-- Name: hr_departments allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.hr_departments FOR INSERT WITH CHECK (true);


--
-- Name: hr_employees allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.hr_employees FOR INSERT WITH CHECK (true);


--
-- Name: hr_fingerprint_transactions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.hr_fingerprint_transactions FOR INSERT WITH CHECK (true);


--
-- Name: hr_levels allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.hr_levels FOR INSERT WITH CHECK (true);


--
-- Name: hr_position_assignments allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.hr_position_assignments FOR INSERT WITH CHECK (true);


--
-- Name: hr_position_reporting_template allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.hr_position_reporting_template FOR INSERT WITH CHECK (true);


--
-- Name: hr_positions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.hr_positions FOR INSERT WITH CHECK (true);


--
-- Name: interface_permissions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.interface_permissions FOR INSERT WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.non_approved_payment_scheduler FOR INSERT WITH CHECK (true);


--
-- Name: notification_attachments allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.notification_attachments FOR INSERT WITH CHECK (true);


--
-- Name: notification_read_states allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.notification_read_states FOR INSERT WITH CHECK (true);


--
-- Name: notification_recipients allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.notification_recipients FOR INSERT WITH CHECK (true);


--
-- Name: notifications allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.notifications FOR INSERT WITH CHECK (true);


--
-- Name: offer_bundles allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.offer_bundles FOR INSERT WITH CHECK (true);


--
-- Name: offer_cart_tiers allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.offer_cart_tiers FOR INSERT WITH CHECK (true);


--
-- Name: offer_products allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.offer_products FOR INSERT WITH CHECK (true);


--
-- Name: offer_usage_logs allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.offer_usage_logs FOR INSERT WITH CHECK (true);


--
-- Name: order_audit_logs allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.order_audit_logs FOR INSERT WITH CHECK (true);


--
-- Name: order_items allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.order_items FOR INSERT WITH CHECK (true);


--
-- Name: orders allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.orders FOR INSERT WITH CHECK (true);


--
-- Name: privilege_cards_branch allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.privilege_cards_branch FOR INSERT WITH CHECK (true);


--
-- Name: privilege_cards_master allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.privilege_cards_master FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_assignments allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.quick_task_assignments FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_comments allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.quick_task_comments FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_completions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.quick_task_completions FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_files allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.quick_task_files FOR INSERT WITH CHECK (true);


--
-- Name: quick_task_user_preferences allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.quick_task_user_preferences FOR INSERT WITH CHECK (true);


--
-- Name: quick_tasks allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.quick_tasks FOR INSERT WITH CHECK (true);


--
-- Name: receiving_records allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.receiving_records FOR INSERT WITH CHECK (true);


--
-- Name: receiving_task_templates allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.receiving_task_templates FOR INSERT WITH CHECK (true);


--
-- Name: receiving_tasks allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.receiving_tasks FOR INSERT WITH CHECK (true);


--
-- Name: recurring_assignment_schedules allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.recurring_assignment_schedules FOR INSERT WITH CHECK (true);


--
-- Name: recurring_schedule_check_log allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.recurring_schedule_check_log FOR INSERT WITH CHECK (true);


--
-- Name: requesters allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.requesters FOR INSERT WITH CHECK (true);


--
-- Name: shelf_paper_templates allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.shelf_paper_templates FOR INSERT WITH CHECK (true);


--
-- Name: sidebar_buttons allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.sidebar_buttons FOR INSERT WITH CHECK (true);


--
-- Name: task_assignments allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.task_assignments FOR INSERT WITH CHECK (true);


--
-- Name: task_completions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.task_completions FOR INSERT WITH CHECK (true);


--
-- Name: task_images allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.task_images FOR INSERT WITH CHECK (true);


--
-- Name: task_reminder_logs allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.task_reminder_logs FOR INSERT WITH CHECK (true);


--
-- Name: tasks allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.tasks FOR INSERT WITH CHECK (true);


--
-- Name: user_audit_logs allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.user_audit_logs FOR INSERT WITH CHECK (true);


--
-- Name: user_device_sessions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.user_device_sessions FOR INSERT WITH CHECK (true);


--
-- Name: user_password_history allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.user_password_history FOR INSERT WITH CHECK (true);


--
-- Name: user_sessions allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.user_sessions FOR INSERT WITH CHECK (true);


--
-- Name: users allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.users FOR INSERT WITH CHECK (true);


--
-- Name: variation_audit_log allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.variation_audit_log FOR INSERT WITH CHECK (true);


--
-- Name: vendors allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.vendors FOR INSERT WITH CHECK (true);


--
-- Name: view_offer allow_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert ON public.view_offer FOR INSERT WITH CHECK (true);


--
-- Name: products allow_insert_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert_all ON public.products FOR INSERT WITH CHECK (true);


--
-- Name: offers allow_insert_offers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert_offers ON public.offers FOR INSERT WITH CHECK (true);


--
-- Name: order_items allow_insert_order_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_insert_order_items ON public.order_items FOR INSERT WITH CHECK (true);


--
-- Name: bogo_offer_rules allow_public_read_bogo; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_public_read_bogo ON public.bogo_offer_rules FOR SELECT TO authenticated, anon USING (true);


--
-- Name: offer_bundles allow_public_read_bundles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_public_read_bundles ON public.offer_bundles FOR SELECT TO authenticated, anon USING (true);


--
-- Name: approval_permissions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.approval_permissions FOR SELECT USING (true);


--
-- Name: biometric_connections allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.biometric_connections FOR SELECT USING (true);


--
-- Name: bogo_offer_rules allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.bogo_offer_rules FOR SELECT USING (true);


--
-- Name: branches allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.branches FOR SELECT USING (true);


--
-- Name: button_main_sections allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.button_main_sections FOR SELECT USING (true);


--
-- Name: button_permissions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.button_permissions FOR SELECT USING (true);


--
-- Name: button_sub_sections allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.button_sub_sections FOR SELECT USING (true);


--
-- Name: coupon_campaigns allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.coupon_campaigns FOR SELECT USING (true);


--
-- Name: coupon_claims allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.coupon_claims FOR SELECT USING (true);


--
-- Name: coupon_eligible_customers allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.coupon_eligible_customers FOR SELECT USING (true);


--
-- Name: coupon_products allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.coupon_products FOR SELECT USING (true);


--
-- Name: customer_access_code_history allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.customer_access_code_history FOR SELECT USING (true);


--
-- Name: customer_app_media allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.customer_app_media FOR SELECT USING (true);


--
-- Name: customer_recovery_requests allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.customer_recovery_requests FOR SELECT USING (true);


--
-- Name: customers allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.customers FOR SELECT USING (true);


--
-- Name: deleted_bundle_offers allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.deleted_bundle_offers FOR SELECT USING (true);


--
-- Name: delivery_fee_tiers allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.delivery_fee_tiers FOR SELECT USING (true);


--
-- Name: delivery_service_settings allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.delivery_service_settings FOR SELECT USING (true);


--
-- Name: employee_fine_payments allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.employee_fine_payments FOR SELECT USING (true);


--
-- Name: erp_connections allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.erp_connections FOR SELECT USING (true);


--
-- Name: erp_daily_sales allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.erp_daily_sales FOR SELECT USING (true);


--
-- Name: expense_parent_categories allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.expense_parent_categories FOR SELECT USING (true);


--
-- Name: expense_requisitions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.expense_requisitions FOR SELECT USING (true);


--
-- Name: expense_scheduler allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.expense_scheduler FOR SELECT USING (true);


--
-- Name: expense_sub_categories allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.expense_sub_categories FOR SELECT USING (true);


--
-- Name: flyer_offer_products allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.flyer_offer_products FOR SELECT USING (true);


--
-- Name: flyer_offers allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.flyer_offers FOR SELECT USING (true);


--
-- Name: flyer_templates allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.flyer_templates FOR SELECT USING (true);


--
-- Name: hr_departments allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.hr_departments FOR SELECT USING (true);


--
-- Name: hr_employees allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.hr_employees FOR SELECT USING (true);


--
-- Name: hr_fingerprint_transactions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.hr_fingerprint_transactions FOR SELECT USING (true);


--
-- Name: hr_levels allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.hr_levels FOR SELECT USING (true);


--
-- Name: hr_position_assignments allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.hr_position_assignments FOR SELECT USING (true);


--
-- Name: hr_position_reporting_template allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.hr_position_reporting_template FOR SELECT USING (true);


--
-- Name: hr_positions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.hr_positions FOR SELECT USING (true);


--
-- Name: interface_permissions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.interface_permissions FOR SELECT USING (true);


--
-- Name: non_approved_payment_scheduler allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.non_approved_payment_scheduler FOR SELECT USING (true);


--
-- Name: notification_attachments allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.notification_attachments FOR SELECT USING (true);


--
-- Name: notification_read_states allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.notification_read_states FOR SELECT USING (true);


--
-- Name: notification_recipients allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.notification_recipients FOR SELECT USING (true);


--
-- Name: notifications allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.notifications FOR SELECT USING (true);


--
-- Name: offer_bundles allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.offer_bundles FOR SELECT USING (true);


--
-- Name: offer_cart_tiers allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.offer_cart_tiers FOR SELECT USING (true);


--
-- Name: offer_products allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.offer_products FOR SELECT USING (true);


--
-- Name: offer_usage_logs allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.offer_usage_logs FOR SELECT USING (true);


--
-- Name: order_audit_logs allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.order_audit_logs FOR SELECT USING (true);


--
-- Name: order_items allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.order_items FOR SELECT USING (true);


--
-- Name: orders allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.orders FOR SELECT USING (true);


--
-- Name: privilege_cards_branch allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.privilege_cards_branch FOR SELECT USING (true);


--
-- Name: privilege_cards_master allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.privilege_cards_master FOR SELECT USING (true);


--
-- Name: quick_task_assignments allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.quick_task_assignments FOR SELECT USING (true);


--
-- Name: quick_task_comments allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.quick_task_comments FOR SELECT USING (true);


--
-- Name: quick_task_completions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.quick_task_completions FOR SELECT USING (true);


--
-- Name: quick_task_files allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.quick_task_files FOR SELECT USING (true);


--
-- Name: quick_task_user_preferences allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.quick_task_user_preferences FOR SELECT USING (true);


--
-- Name: quick_tasks allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.quick_tasks FOR SELECT USING (true);


--
-- Name: receiving_records allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.receiving_records FOR SELECT USING (true);


--
-- Name: receiving_task_templates allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.receiving_task_templates FOR SELECT USING (true);


--
-- Name: receiving_tasks allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.receiving_tasks FOR SELECT USING (true);


--
-- Name: recurring_assignment_schedules allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.recurring_assignment_schedules FOR SELECT USING (true);


--
-- Name: recurring_schedule_check_log allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.recurring_schedule_check_log FOR SELECT USING (true);


--
-- Name: requesters allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.requesters FOR SELECT USING (true);


--
-- Name: shelf_paper_templates allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.shelf_paper_templates FOR SELECT USING (true);


--
-- Name: sidebar_buttons allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.sidebar_buttons FOR SELECT USING (true);


--
-- Name: task_assignments allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.task_assignments FOR SELECT USING (true);


--
-- Name: task_completions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.task_completions FOR SELECT USING (true);


--
-- Name: task_images allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.task_images FOR SELECT USING (true);


--
-- Name: task_reminder_logs allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.task_reminder_logs FOR SELECT USING (true);


--
-- Name: tasks allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.tasks FOR SELECT USING (true);


--
-- Name: user_audit_logs allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.user_audit_logs FOR SELECT USING (true);


--
-- Name: user_device_sessions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.user_device_sessions FOR SELECT USING (true);


--
-- Name: user_password_history allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.user_password_history FOR SELECT USING (true);


--
-- Name: user_sessions allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.user_sessions FOR SELECT USING (true);


--
-- Name: users allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.users FOR SELECT USING (true);


--
-- Name: variation_audit_log allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.variation_audit_log FOR SELECT USING (true);


--
-- Name: vendors allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.vendors FOR SELECT USING (true);


--
-- Name: view_offer allow_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select ON public.view_offer FOR SELECT USING (true);


--
-- Name: products allow_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select_all ON public.products FOR SELECT USING (true);


--
-- Name: offers allow_select_offers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_select_offers ON public.offers FOR SELECT USING (true);


--
-- Name: approval_permissions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.approval_permissions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: biometric_connections allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.biometric_connections FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: bogo_offer_rules allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.bogo_offer_rules FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: branches allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.branches FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: button_main_sections allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.button_main_sections FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: button_permissions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.button_permissions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: button_sub_sections allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.button_sub_sections FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: coupon_campaigns allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.coupon_campaigns FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: coupon_claims allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.coupon_claims FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: coupon_eligible_customers allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.coupon_eligible_customers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: coupon_products allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.coupon_products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: customer_access_code_history allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.customer_access_code_history FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: customer_app_media allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.customer_app_media FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: customer_recovery_requests allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.customer_recovery_requests FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: customers allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.customers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: deleted_bundle_offers allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.deleted_bundle_offers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: delivery_fee_tiers allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.delivery_fee_tiers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: delivery_service_settings allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.delivery_service_settings FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: employee_fine_payments allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.employee_fine_payments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: erp_connections allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.erp_connections FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: erp_daily_sales allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.erp_daily_sales FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: expense_parent_categories allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.expense_parent_categories FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: expense_requisitions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.expense_requisitions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: expense_scheduler allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.expense_scheduler FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: expense_sub_categories allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.expense_sub_categories FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: flyer_offer_products allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.flyer_offer_products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: flyer_offers allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.flyer_offers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: flyer_templates allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.flyer_templates FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_departments allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.hr_departments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_employees allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.hr_employees FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_fingerprint_transactions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.hr_fingerprint_transactions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_levels allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.hr_levels FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_position_assignments allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.hr_position_assignments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_position_reporting_template allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.hr_position_reporting_template FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: hr_positions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.hr_positions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: interface_permissions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.interface_permissions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: non_approved_payment_scheduler allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.non_approved_payment_scheduler FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: notification_attachments allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.notification_attachments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: notification_read_states allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.notification_read_states FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: notification_recipients allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.notification_recipients FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: notifications allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.notifications FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_bundles allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.offer_bundles FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_cart_tiers allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.offer_cart_tiers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_products allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.offer_products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offer_usage_logs allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.offer_usage_logs FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: order_audit_logs allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.order_audit_logs FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: order_items allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.order_items FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: orders allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.orders FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: privilege_cards_branch allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.privilege_cards_branch FOR UPDATE USING (true);


--
-- Name: privilege_cards_master allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.privilege_cards_master FOR UPDATE USING (true);


--
-- Name: quick_task_assignments allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.quick_task_assignments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_task_comments allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.quick_task_comments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_task_completions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.quick_task_completions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_task_files allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.quick_task_files FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_task_user_preferences allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.quick_task_user_preferences FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: quick_tasks allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.quick_tasks FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: receiving_records allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.receiving_records FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: receiving_task_templates allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.receiving_task_templates FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: receiving_tasks allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.receiving_tasks FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: recurring_assignment_schedules allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.recurring_assignment_schedules FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: recurring_schedule_check_log allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.recurring_schedule_check_log FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: requesters allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.requesters FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: shelf_paper_templates allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.shelf_paper_templates FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: sidebar_buttons allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.sidebar_buttons FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: task_assignments allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.task_assignments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: task_completions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.task_completions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: task_images allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.task_images FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: task_reminder_logs allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.task_reminder_logs FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: tasks allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.tasks FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: user_audit_logs allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.user_audit_logs FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: user_device_sessions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.user_device_sessions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: user_password_history allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.user_password_history FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: user_sessions allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.user_sessions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: users allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.users FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: variation_audit_log allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.variation_audit_log FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: vendors allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.vendors FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: view_offer allow_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update ON public.view_offer FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: products allow_update_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update_all ON public.products FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: offers allow_update_offers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY allow_update_offers ON public.offers FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: background_templates anon_all_background_templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_all_background_templates ON public.background_templates TO anon USING (true) WITH CHECK (true);


--
-- Name: surprise_box_plays anon_all_surprise_box_plays; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_all_surprise_box_plays ON public.surprise_box_plays TO anon USING (true) WITH CHECK (true);


--
-- Name: surprise_box_rewards anon_all_surprise_box_rewards; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_all_surprise_box_rewards ON public.surprise_box_rewards TO anon USING (true) WITH CHECK (true);


--
-- Name: surprise_box_settings anon_all_surprise_box_settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_all_surprise_box_settings ON public.surprise_box_settings TO anon USING (true) WITH CHECK (true);


--
-- Name: surprise_box_vouchers anon_all_surprise_box_vouchers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_all_surprise_box_vouchers ON public.surprise_box_vouchers TO anon USING (true) WITH CHECK (true);


--
-- Name: approval_permissions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.approval_permissions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: biometric_connections anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.biometric_connections USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: bogo_offer_rules anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.bogo_offer_rules USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: coupon_campaigns anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.coupon_campaigns USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: coupon_claims anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.coupon_claims USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: coupon_eligible_customers anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.coupon_eligible_customers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: coupon_products anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.coupon_products USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: customer_access_code_history anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.customer_access_code_history USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: customer_app_media anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.customer_app_media USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: customer_recovery_requests anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.customer_recovery_requests USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: customers anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.customers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: deleted_bundle_offers anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.deleted_bundle_offers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: delivery_fee_tiers anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.delivery_fee_tiers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: delivery_service_settings anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.delivery_service_settings USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: employee_fine_payments anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.employee_fine_payments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: erp_connections anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.erp_connections USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: erp_daily_sales anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.erp_daily_sales USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: expense_parent_categories anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.expense_parent_categories USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: expense_requisitions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.expense_requisitions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: expense_scheduler anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.expense_scheduler USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: expense_sub_categories anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.expense_sub_categories USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: flyer_offer_products anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.flyer_offer_products USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: flyer_offers anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.flyer_offers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: flyer_templates anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.flyer_templates USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_departments anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.hr_departments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_employee_master anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.hr_employee_master FOR SELECT USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_employees anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.hr_employees USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_fingerprint_transactions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.hr_fingerprint_transactions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_levels anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.hr_levels USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_position_assignments anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.hr_position_assignments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_position_reporting_template anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.hr_position_reporting_template USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: hr_positions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.hr_positions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: interface_permissions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.interface_permissions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: non_approved_payment_scheduler anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.non_approved_payment_scheduler USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: notification_attachments anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.notification_attachments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: notification_read_states anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.notification_read_states USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: notification_recipients anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.notification_recipients USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: notifications anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.notifications USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: offer_bundles anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.offer_bundles USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: offer_cart_tiers anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.offer_cart_tiers USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: offer_products anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.offer_products USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: offer_usage_logs anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.offer_usage_logs USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: order_audit_logs anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.order_audit_logs USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: order_items anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.order_items USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: orders anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.orders USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: privilege_cards_branch anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.privilege_cards_branch USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: privilege_cards_master anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.privilege_cards_master USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_task_assignments anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.quick_task_assignments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_task_comments anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.quick_task_comments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_task_completions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.quick_task_completions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_task_files anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.quick_task_files USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_task_user_preferences anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.quick_task_user_preferences USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: quick_tasks anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.quick_tasks USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: receiving_task_templates anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.receiving_task_templates USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: receiving_tasks anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.receiving_tasks USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: recurring_assignment_schedules anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.recurring_assignment_schedules USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: recurring_schedule_check_log anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.recurring_schedule_check_log USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: requesters anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.requesters USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: shelf_paper_templates anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.shelf_paper_templates USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: task_assignments anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.task_assignments USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: task_completions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.task_completions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: task_images anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.task_images USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: task_reminder_logs anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.task_reminder_logs USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: tasks anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.tasks USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: user_audit_logs anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.user_audit_logs USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: user_device_sessions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.user_device_sessions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: user_password_history anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.user_password_history USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: user_sessions anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.user_sessions USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: users anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.users USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: variation_audit_log anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.variation_audit_log USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: view_offer anon_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_full_access ON public.view_offer USING (((auth.jwt() ->> 'role'::text) = 'anon'::text));


--
-- Name: access_code_otp anon_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert ON public.access_code_otp FOR INSERT TO anon WITH CHECK (true);


--
-- Name: app_icons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_icons ENABLE ROW LEVEL SECURITY;

--
-- Name: approval_permissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approval_permissions ENABLE ROW LEVEL SECURITY;

--
-- Name: approver_branch_access; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approver_branch_access ENABLE ROW LEVEL SECURITY;

--
-- Name: approver_visibility_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approver_visibility_config ENABLE ROW LEVEL SECURITY;

--
-- Name: asset_main_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.asset_main_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: asset_sub_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.asset_sub_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: assets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;

--
-- Name: background_templates auth_all_background_templates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_all_background_templates ON public.background_templates TO authenticated USING (true) WITH CHECK (true);


--
-- Name: surprise_box_plays auth_all_surprise_box_plays; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_all_surprise_box_plays ON public.surprise_box_plays TO authenticated USING (true) WITH CHECK (true);


--
-- Name: surprise_box_rewards auth_all_surprise_box_rewards; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_all_surprise_box_rewards ON public.surprise_box_rewards TO authenticated USING (true) WITH CHECK (true);


--
-- Name: surprise_box_settings auth_all_surprise_box_settings; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_all_surprise_box_settings ON public.surprise_box_settings TO authenticated USING (true) WITH CHECK (true);


--
-- Name: surprise_box_vouchers auth_all_surprise_box_vouchers; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_all_surprise_box_vouchers ON public.surprise_box_vouchers TO authenticated USING (true) WITH CHECK (true);


--
-- Name: coupon_eligible_customers authenticated_check_eligibility; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_check_eligibility ON public.coupon_eligible_customers FOR SELECT TO authenticated USING (true);


--
-- Name: coupon_claims authenticated_create_claims; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_create_claims ON public.coupon_claims FOR INSERT TO authenticated WITH CHECK ((claimed_by_user = auth.uid()));


--
-- Name: approval_permissions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.approval_permissions USING ((auth.uid() IS NOT NULL));


--
-- Name: biometric_connections authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.biometric_connections USING ((auth.uid() IS NOT NULL));


--
-- Name: bogo_offer_rules authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.bogo_offer_rules USING ((auth.uid() IS NOT NULL));


--
-- Name: coupon_campaigns authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.coupon_campaigns USING ((auth.uid() IS NOT NULL));


--
-- Name: coupon_claims authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.coupon_claims USING ((auth.uid() IS NOT NULL));


--
-- Name: coupon_eligible_customers authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.coupon_eligible_customers USING ((auth.uid() IS NOT NULL));


--
-- Name: coupon_products authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.coupon_products USING ((auth.uid() IS NOT NULL));


--
-- Name: customer_access_code_history authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.customer_access_code_history USING ((auth.uid() IS NOT NULL));


--
-- Name: customer_app_media authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.customer_app_media USING ((auth.uid() IS NOT NULL));


--
-- Name: customer_recovery_requests authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.customer_recovery_requests USING ((auth.uid() IS NOT NULL));


--
-- Name: customers authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.customers USING ((auth.uid() IS NOT NULL));


--
-- Name: deleted_bundle_offers authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.deleted_bundle_offers USING ((auth.uid() IS NOT NULL));


--
-- Name: delivery_fee_tiers authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.delivery_fee_tiers USING ((auth.uid() IS NOT NULL));


--
-- Name: delivery_service_settings authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.delivery_service_settings USING ((auth.uid() IS NOT NULL));


--
-- Name: employee_fine_payments authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.employee_fine_payments USING ((auth.uid() IS NOT NULL));


--
-- Name: erp_connections authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.erp_connections USING ((auth.uid() IS NOT NULL));


--
-- Name: erp_daily_sales authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.erp_daily_sales USING ((auth.uid() IS NOT NULL));


--
-- Name: expense_parent_categories authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.expense_parent_categories USING ((auth.uid() IS NOT NULL));


--
-- Name: expense_requisitions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.expense_requisitions USING ((auth.uid() IS NOT NULL));


--
-- Name: expense_scheduler authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.expense_scheduler USING ((auth.uid() IS NOT NULL));


--
-- Name: expense_sub_categories authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.expense_sub_categories USING ((auth.uid() IS NOT NULL));


--
-- Name: flyer_offer_products authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.flyer_offer_products USING ((auth.uid() IS NOT NULL));


--
-- Name: flyer_offers authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.flyer_offers USING ((auth.uid() IS NOT NULL));


--
-- Name: flyer_templates authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.flyer_templates USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_departments authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.hr_departments USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_employee_master authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.hr_employee_master FOR SELECT USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_employees authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.hr_employees USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_fingerprint_transactions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.hr_fingerprint_transactions USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_levels authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.hr_levels USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_position_assignments authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.hr_position_assignments USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_position_reporting_template authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.hr_position_reporting_template USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_positions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.hr_positions USING ((auth.uid() IS NOT NULL));


--
-- Name: interface_permissions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.interface_permissions USING ((auth.uid() IS NOT NULL));


--
-- Name: non_approved_payment_scheduler authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.non_approved_payment_scheduler USING ((auth.uid() IS NOT NULL));


--
-- Name: notification_attachments authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.notification_attachments USING ((auth.uid() IS NOT NULL));


--
-- Name: notification_read_states authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.notification_read_states USING ((auth.uid() IS NOT NULL));


--
-- Name: notification_recipients authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.notification_recipients USING ((auth.uid() IS NOT NULL));


--
-- Name: notifications authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.notifications USING ((auth.uid() IS NOT NULL));


--
-- Name: offer_bundles authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.offer_bundles USING ((auth.uid() IS NOT NULL));


--
-- Name: offer_cart_tiers authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.offer_cart_tiers USING ((auth.uid() IS NOT NULL));


--
-- Name: offer_products authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.offer_products USING ((auth.uid() IS NOT NULL));


--
-- Name: offer_usage_logs authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.offer_usage_logs USING ((auth.uid() IS NOT NULL));


--
-- Name: order_audit_logs authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.order_audit_logs USING ((auth.uid() IS NOT NULL));


--
-- Name: order_items authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.order_items USING ((auth.uid() IS NOT NULL));


--
-- Name: orders authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.orders USING ((auth.uid() IS NOT NULL));


--
-- Name: privilege_cards_branch authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.privilege_cards_branch USING ((auth.uid() IS NOT NULL));


--
-- Name: privilege_cards_master authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.privilege_cards_master USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_task_assignments authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.quick_task_assignments USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_task_comments authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.quick_task_comments USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_task_completions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.quick_task_completions USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_task_files authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.quick_task_files USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_task_user_preferences authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.quick_task_user_preferences USING ((auth.uid() IS NOT NULL));


--
-- Name: quick_tasks authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.quick_tasks USING ((auth.uid() IS NOT NULL));


--
-- Name: receiving_task_templates authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.receiving_task_templates USING ((auth.uid() IS NOT NULL));


--
-- Name: receiving_tasks authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.receiving_tasks USING ((auth.uid() IS NOT NULL));


--
-- Name: recurring_assignment_schedules authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.recurring_assignment_schedules USING ((auth.uid() IS NOT NULL));


--
-- Name: recurring_schedule_check_log authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.recurring_schedule_check_log USING ((auth.uid() IS NOT NULL));


--
-- Name: requesters authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.requesters USING ((auth.uid() IS NOT NULL));


--
-- Name: settlement_rules authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.settlement_rules USING ((auth.uid() IS NOT NULL)) WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: shelf_paper_templates authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.shelf_paper_templates USING ((auth.uid() IS NOT NULL));


--
-- Name: task_assignments authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.task_assignments USING ((auth.uid() IS NOT NULL));


--
-- Name: task_completions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.task_completions USING ((auth.uid() IS NOT NULL));


--
-- Name: task_images authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.task_images USING ((auth.uid() IS NOT NULL));


--
-- Name: task_reminder_logs authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.task_reminder_logs USING ((auth.uid() IS NOT NULL));


--
-- Name: tasks authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.tasks USING ((auth.uid() IS NOT NULL));


--
-- Name: user_audit_logs authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.user_audit_logs USING ((auth.uid() IS NOT NULL));


--
-- Name: user_device_sessions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.user_device_sessions USING ((auth.uid() IS NOT NULL));


--
-- Name: user_password_history authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.user_password_history USING ((auth.uid() IS NOT NULL));


--
-- Name: user_sessions authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.user_sessions USING ((auth.uid() IS NOT NULL));


--
-- Name: users authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.users USING ((auth.uid() IS NOT NULL));


--
-- Name: variation_audit_log authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.variation_audit_log USING ((auth.uid() IS NOT NULL));


--
-- Name: view_offer authenticated_full_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access ON public.view_offer USING ((auth.uid() IS NOT NULL));


--
-- Name: hr_employee_applicability_rule_periods authenticated_full_access_hr_employee_applicability_rule_period; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access_hr_employee_applicability_rule_period ON public.hr_employee_applicability_rule_periods USING ((auth.uid() IS NOT NULL)) WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: hr_employee_leave_approvals authenticated_full_access_hr_employee_leave_approvals; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access_hr_employee_leave_approvals ON public.hr_employee_leave_approvals USING ((auth.uid() IS NOT NULL)) WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: hr_employee_settlement_applicability authenticated_full_access_hr_employee_settlement_applicability; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access_hr_employee_settlement_applicability ON public.hr_employee_settlement_applicability USING ((auth.uid() IS NOT NULL)) WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: hr_employee_ticket_issuances authenticated_full_access_hr_employee_ticket_issuances; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_full_access_hr_employee_ticket_issuances ON public.hr_employee_ticket_issuances USING ((auth.uid() IS NOT NULL)) WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: coupon_campaigns authenticated_view_active_campaigns; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_view_active_campaigns ON public.coupon_campaigns FOR SELECT TO authenticated USING (((is_active = true) AND (deleted_at IS NULL)));


--
-- Name: coupon_products authenticated_view_active_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY authenticated_view_active_products ON public.coupon_products FOR SELECT TO authenticated USING (((is_active = true) AND (deleted_at IS NULL)));


--
-- Name: background_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.background_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: bank_reconciliations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bank_reconciliations ENABLE ROW LEVEL SECURITY;

--
-- Name: biometric_connections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biometric_connections ENABLE ROW LEVEL SECURITY;

--
-- Name: bogo_offer_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bogo_offer_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: box_operations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.box_operations ENABLE ROW LEVEL SECURITY;

--
-- Name: box_operations box_operations_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY box_operations_delete ON public.box_operations FOR DELETE USING (true);


--
-- Name: box_operations box_operations_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY box_operations_insert ON public.box_operations FOR INSERT WITH CHECK (true);


--
-- Name: box_operations box_operations_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY box_operations_select ON public.box_operations FOR SELECT USING (true);


--
-- Name: box_operations box_operations_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY box_operations_update ON public.box_operations FOR UPDATE USING (true);


--
-- Name: branch_default_delivery_receivers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branch_default_delivery_receivers ENABLE ROW LEVEL SECURITY;

--
-- Name: branch_default_positions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branch_default_positions ENABLE ROW LEVEL SECURITY;

--
-- Name: branch_sync_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branch_sync_config ENABLE ROW LEVEL SECURITY;

--
-- Name: branch_sync_config branch_sync_config_modify; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branch_sync_config_modify ON public.branch_sync_config TO authenticated USING (true) WITH CHECK (true);


--
-- Name: branch_sync_config branch_sync_config_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branch_sync_config_select ON public.branch_sync_config FOR SELECT TO authenticated USING (true);


--
-- Name: branches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

--
-- Name: break_reasons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.break_reasons ENABLE ROW LEVEL SECURITY;

--
-- Name: break_register; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.break_register ENABLE ROW LEVEL SECURITY;

--
-- Name: break_security_seed; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.break_security_seed ENABLE ROW LEVEL SECURITY;

--
-- Name: button_main_sections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.button_main_sections ENABLE ROW LEVEL SECURITY;

--
-- Name: button_permissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.button_permissions ENABLE ROW LEVEL SECURITY;

--
-- Name: button_sub_sections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.button_sub_sections ENABLE ROW LEVEL SECURITY;

--
-- Name: cashier_device_bindings cashier_bindings_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cashier_bindings_select ON public.cashier_device_bindings FOR SELECT USING (true);


--
-- Name: cashier_device_bindings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cashier_device_bindings ENABLE ROW LEVEL SECURITY;

--
-- Name: coupon_campaigns; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coupon_campaigns ENABLE ROW LEVEL SECURITY;

--
-- Name: coupon_claims; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coupon_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: coupon_eligible_customers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coupon_eligible_customers ENABLE ROW LEVEL SECURITY;

--
-- Name: coupon_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coupon_products ENABLE ROW LEVEL SECURITY;

--
-- Name: customer_access_code_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customer_access_code_history ENABLE ROW LEVEL SECURITY;

--
-- Name: customer_access_code_history customer_access_code_history_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_access_code_history_insert_policy ON public.customer_access_code_history FOR INSERT WITH CHECK (true);


--
-- Name: customer_access_code_history customer_access_code_history_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_access_code_history_select_policy ON public.customer_access_code_history FOR SELECT USING (true);


--
-- Name: customer_app_media; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customer_app_media ENABLE ROW LEVEL SECURITY;

--
-- Name: customer_product_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customer_product_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: customer_recovery_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customer_recovery_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: customer_recovery_requests customer_recovery_requests_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_recovery_requests_delete_policy ON public.customer_recovery_requests FOR DELETE USING (true);


--
-- Name: customer_recovery_requests customer_recovery_requests_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_recovery_requests_insert_policy ON public.customer_recovery_requests FOR INSERT WITH CHECK (true);


--
-- Name: customer_recovery_requests customer_recovery_requests_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_recovery_requests_select_policy ON public.customer_recovery_requests FOR SELECT USING (true);


--
-- Name: customer_recovery_requests customer_recovery_requests_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_recovery_requests_update_policy ON public.customer_recovery_requests FOR UPDATE USING (true);


--
-- Name: customers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

--
-- Name: orders customers_create_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customers_create_orders ON public.orders FOR INSERT WITH CHECK ((auth.uid() = customer_id));


--
-- Name: customers customers_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customers_delete_policy ON public.customers FOR DELETE USING (true);


--
-- Name: customers customers_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customers_insert_policy ON public.customers FOR INSERT WITH CHECK (true);


--
-- Name: customers customers_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customers_select_policy ON public.customers FOR SELECT USING (true);


--
-- Name: customers customers_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customers_update_policy ON public.customers FOR UPDATE USING (true);


--
-- Name: orders customers_view_own_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customers_view_own_orders ON public.orders FOR SELECT USING (((auth.uid() = customer_id) OR public.has_order_management_access(auth.uid()) OR public.is_delivery_staff(auth.uid())));


--
-- Name: POLICY customers_view_own_orders ON orders; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY customers_view_own_orders ON public.orders IS 'Customers can view their own orders, management and delivery staff can view all';


--
-- Name: day_off; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.day_off ENABLE ROW LEVEL SECURITY;

--
-- Name: day_off_reasons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.day_off_reasons ENABLE ROW LEVEL SECURITY;

--
-- Name: day_off_weekday; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.day_off_weekday ENABLE ROW LEVEL SECURITY;

--
-- Name: default_incident_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.default_incident_users ENABLE ROW LEVEL SECURITY;

--
-- Name: deleted_bundle_offers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deleted_bundle_offers ENABLE ROW LEVEL SECURITY;

--
-- Name: delivery_fee_tiers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.delivery_fee_tiers ENABLE ROW LEVEL SECURITY;

--
-- Name: delivery_service_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.delivery_service_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: delivery_service_settings delivery_settings_allow_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delivery_settings_allow_read ON public.delivery_service_settings FOR SELECT USING (true);


--
-- Name: delivery_fee_tiers delivery_tiers_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delivery_tiers_select_all ON public.delivery_fee_tiers FOR SELECT USING (true);


--
-- Name: orders delivery_update_assigned_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delivery_update_assigned_orders ON public.orders FOR UPDATE USING (((delivery_person_id = auth.uid()) OR public.is_delivery_staff(auth.uid()))) WITH CHECK ((((delivery_person_id = auth.uid()) OR public.is_delivery_staff(auth.uid())) AND ((order_status)::text = ANY (ARRAY[('out_for_delivery'::character varying)::text, ('delivered'::character varying)::text]))));


--
-- Name: orders delivery_view_assigned_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY delivery_view_assigned_orders ON public.orders FOR SELECT USING (((delivery_person_id = auth.uid()) OR public.is_delivery_staff(auth.uid()) OR public.has_order_management_access(auth.uid())));


--
-- Name: POLICY delivery_view_assigned_orders ON orders; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY delivery_view_assigned_orders ON public.orders IS 'Delivery personnel can view their assigned orders';


--
-- Name: denomination_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.denomination_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: denomination_audit_log denomination_audit_log_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_audit_log_insert ON public.denomination_audit_log FOR INSERT WITH CHECK (true);


--
-- Name: denomination_audit_log denomination_audit_log_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_audit_log_select ON public.denomination_audit_log FOR SELECT USING (true);


--
-- Name: denomination_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.denomination_records ENABLE ROW LEVEL SECURITY;

--
-- Name: denomination_records denomination_records_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_records_delete ON public.denomination_records FOR DELETE USING (true);


--
-- Name: denomination_records denomination_records_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_records_insert ON public.denomination_records FOR INSERT WITH CHECK (true);


--
-- Name: denomination_records denomination_records_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_records_select ON public.denomination_records FOR SELECT USING (true);


--
-- Name: denomination_records denomination_records_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_records_update ON public.denomination_records FOR UPDATE USING (true);


--
-- Name: denomination_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.denomination_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: denomination_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.denomination_types ENABLE ROW LEVEL SECURITY;

--
-- Name: denomination_types denomination_types_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_types_delete ON public.denomination_types FOR DELETE USING (true);


--
-- Name: denomination_types denomination_types_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_types_insert ON public.denomination_types FOR INSERT WITH CHECK (true);


--
-- Name: denomination_types denomination_types_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_types_select ON public.denomination_types FOR SELECT USING (true);


--
-- Name: denomination_types denomination_types_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY denomination_types_update ON public.denomination_types FOR UPDATE USING (true);


--
-- Name: desktop_themes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.desktop_themes ENABLE ROW LEVEL SECURITY;

--
-- Name: employee_checklist_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.employee_checklist_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: employee_fine_payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.employee_fine_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: employee_official_holidays; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.employee_official_holidays ENABLE ROW LEVEL SECURITY;

--
-- Name: erp_connections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.erp_connections ENABLE ROW LEVEL SECURITY;

--
-- Name: erp_daily_sales; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.erp_daily_sales ENABLE ROW LEVEL SECURITY;

--
-- Name: erp_sync_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.erp_sync_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: erp_synced_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.erp_synced_products ENABLE ROW LEVEL SECURITY;

--
-- Name: expense_parent_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.expense_parent_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: expense_requisitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.expense_requisitions ENABLE ROW LEVEL SECURITY;

--
-- Name: expense_scheduler; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.expense_scheduler ENABLE ROW LEVEL SECURITY;

--
-- Name: expense_sub_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.expense_sub_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: flyer_offer_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.flyer_offer_products ENABLE ROW LEVEL SECURITY;

--
-- Name: flyer_offer_products flyer_offer_products_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offer_products_delete_policy ON public.flyer_offer_products FOR DELETE TO authenticated USING (true);


--
-- Name: flyer_offer_products flyer_offer_products_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offer_products_insert_policy ON public.flyer_offer_products FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: flyer_offer_products flyer_offer_products_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offer_products_select_policy ON public.flyer_offer_products FOR SELECT USING (true);


--
-- Name: POLICY flyer_offer_products_select_policy ON flyer_offer_products; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY flyer_offer_products_select_policy ON public.flyer_offer_products IS 'Allows public read access to flyer offer products';


--
-- Name: flyer_offer_products flyer_offer_products_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offer_products_update_policy ON public.flyer_offer_products FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: flyer_offers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.flyer_offers ENABLE ROW LEVEL SECURITY;

--
-- Name: flyer_offers flyer_offers_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offers_delete_policy ON public.flyer_offers FOR DELETE TO authenticated USING (true);


--
-- Name: flyer_offers flyer_offers_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offers_insert_policy ON public.flyer_offers FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: flyer_offers flyer_offers_select_all_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offers_select_all_policy ON public.flyer_offers FOR SELECT TO authenticated USING (true);


--
-- Name: POLICY flyer_offers_select_all_policy ON flyer_offers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY flyer_offers_select_all_policy ON public.flyer_offers IS 'Allows authenticated users to view all flyer offers including inactive';


--
-- Name: flyer_offers flyer_offers_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offers_select_policy ON public.flyer_offers FOR SELECT USING ((is_active = true));


--
-- Name: POLICY flyer_offers_select_policy ON flyer_offers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY flyer_offers_select_policy ON public.flyer_offers IS 'Allows public read access to active flyer offers only';


--
-- Name: flyer_offers flyer_offers_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY flyer_offers_update_policy ON public.flyer_offers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: flyer_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.flyer_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: frontend_builds; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.frontend_builds ENABLE ROW LEVEL SECURITY;

--
-- Name: gift_wheel_coupons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gift_wheel_coupons ENABLE ROW LEVEL SECURITY;

--
-- Name: gift_wheel_rewards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gift_wheel_rewards ENABLE ROW LEVEL SECURITY;

--
-- Name: gift_wheel_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gift_wheel_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: gift_wheel_spins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gift_wheel_spins ENABLE ROW LEVEL SECURITY;

--
-- Name: helper_apps; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.helper_apps ENABLE ROW LEVEL SECURITY;

--
-- Name: helper_apps helper_apps_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY helper_apps_delete ON public.helper_apps FOR DELETE TO authenticated, anon USING (true);


--
-- Name: helper_apps helper_apps_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY helper_apps_insert ON public.helper_apps FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: helper_apps helper_apps_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY helper_apps_select ON public.helper_apps FOR SELECT TO authenticated, anon USING (true);


--
-- Name: helper_apps helper_apps_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY helper_apps_update ON public.helper_apps FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);


--
-- Name: hr_analysed_attendance_data; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_analysed_attendance_data ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_basic_salary; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_basic_salary ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_checklist_operations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_checklist_operations ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_checklist_questions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_checklist_questions ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_checklists; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_checklists ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_departments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_departments ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_employee_applicability_rule_periods; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_employee_applicability_rule_periods ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_employee_esob_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_employee_esob_records ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_employee_leave_approvals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_employee_leave_approvals ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_employee_master; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_employee_master ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_employee_settlement_applicability; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_employee_settlement_applicability ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_employee_ticket_issuances; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_employee_ticket_issuances ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_employees; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_employees ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_esob_base_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_esob_base_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_esob_resignation_factors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_esob_resignation_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_fingerprint_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_fingerprint_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_insurance_companies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_insurance_companies ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_levels; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_levels ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_position_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_position_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_position_reporting_template; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_position_reporting_template ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_positions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_positions ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_salary_notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_salary_notes ENABLE ROW LEVEL SECURITY;

--
-- Name: hr_salary_notes hr_salary_notes_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY hr_salary_notes_delete ON public.hr_salary_notes FOR DELETE TO authenticated USING (true);


--
-- Name: hr_salary_notes hr_salary_notes_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY hr_salary_notes_insert ON public.hr_salary_notes FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: hr_salary_notes hr_salary_notes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY hr_salary_notes_select ON public.hr_salary_notes FOR SELECT TO authenticated USING (true);


--
-- Name: hr_salary_statements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hr_salary_statements ENABLE ROW LEVEL SECURITY;

--
-- Name: incident_actions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.incident_actions ENABLE ROW LEVEL SECURITY;

--
-- Name: incident_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.incident_types ENABLE ROW LEVEL SECURITY;

--
-- Name: incidents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

--
-- Name: interface_permissions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.interface_permissions ENABLE ROW LEVEL SECURITY;

--
-- Name: interface_permissions interface_permissions_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY interface_permissions_delete_policy ON public.interface_permissions FOR DELETE USING (true);


--
-- Name: interface_permissions interface_permissions_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY interface_permissions_insert_policy ON public.interface_permissions FOR INSERT WITH CHECK (true);


--
-- Name: interface_permissions interface_permissions_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY interface_permissions_select_policy ON public.interface_permissions FOR SELECT USING (true);


--
-- Name: interface_permissions interface_permissions_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY interface_permissions_update_policy ON public.interface_permissions FOR UPDATE USING (true);


--
-- Name: lease_rent_lease_parties; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lease_rent_lease_parties ENABLE ROW LEVEL SECURITY;

--
-- Name: lease_rent_payment_entries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lease_rent_payment_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: lease_rent_payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lease_rent_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: lease_rent_properties; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lease_rent_properties ENABLE ROW LEVEL SECURITY;

--
-- Name: lease_rent_property_spaces; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lease_rent_property_spaces ENABLE ROW LEVEL SECURITY;

--
-- Name: lease_rent_rent_parties; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lease_rent_rent_parties ENABLE ROW LEVEL SECURITY;

--
-- Name: lease_rent_special_changes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lease_rent_special_changes ENABLE ROW LEVEL SECURITY;

--
-- Name: loyalty_customer_bills; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.loyalty_customer_bills ENABLE ROW LEVEL SECURITY;

--
-- Name: loyalty_customer_bills loyalty_customer_bills_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY loyalty_customer_bills_anon ON public.loyalty_customer_bills TO anon USING (true) WITH CHECK (true);


--
-- Name: loyalty_customer_bills loyalty_customer_bills_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY loyalty_customer_bills_authenticated ON public.loyalty_customer_bills TO authenticated USING (true) WITH CHECK (true);


--
-- Name: loyalty_redemptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.loyalty_redemptions ENABLE ROW LEVEL SECURITY;

--
-- Name: loyalty_redemptions loyalty_redemptions_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY loyalty_redemptions_anon ON public.loyalty_redemptions TO anon USING (true) WITH CHECK (true);


--
-- Name: loyalty_redemptions loyalty_redemptions_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY loyalty_redemptions_authenticated ON public.loyalty_redemptions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: loyalty_tiers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.loyalty_tiers ENABLE ROW LEVEL SECURITY;

--
-- Name: loyalty_tiers loyalty_tiers_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY loyalty_tiers_authenticated ON public.loyalty_tiers TO authenticated USING (true) WITH CHECK (true);


--
-- Name: loyalty_tiers loyalty_tiers_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY loyalty_tiers_public_read ON public.loyalty_tiers FOR SELECT USING (true);


--
-- Name: order_items management_delete_order_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY management_delete_order_items ON public.order_items FOR DELETE USING (public.has_order_management_access(auth.uid()));


--
-- Name: order_items management_update_order_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY management_update_order_items ON public.order_items FOR UPDATE USING (public.has_order_management_access(auth.uid()));


--
-- Name: orders management_update_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY management_update_orders ON public.orders FOR UPDATE USING (public.has_order_management_access(auth.uid()));


--
-- Name: order_audit_logs management_view_all_audit_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY management_view_all_audit_logs ON public.order_audit_logs FOR SELECT USING (public.has_order_management_access(auth.uid()));


--
-- Name: orders management_view_all_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY management_view_all_orders ON public.orders FOR SELECT USING ((public.has_order_management_access(auth.uid()) OR (picker_id = auth.uid()) OR (delivery_person_id = auth.uid())));


--
-- Name: POLICY management_view_all_orders ON orders; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY management_view_all_orders ON public.orders IS 'Management, pickers, and delivery staff can view orders';


--
-- Name: mobile_themes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mobile_themes ENABLE ROW LEVEL SECURITY;

--
-- Name: multi_shift_date_wise; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.multi_shift_date_wise ENABLE ROW LEVEL SECURITY;

--
-- Name: multi_shift_regular; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.multi_shift_regular ENABLE ROW LEVEL SECURITY;

--
-- Name: multi_shift_weekday; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.multi_shift_weekday ENABLE ROW LEVEL SECURITY;

--
-- Name: nationalities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nationalities ENABLE ROW LEVEL SECURITY;

--
-- Name: near_expiry_reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.near_expiry_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: non_approved_payment_scheduler; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.non_approved_payment_scheduler ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_read_states; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_read_states ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_recipients; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_recipients ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_bundles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_bundles ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_cart_tiers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_cart_tiers ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_names; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_names ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_products ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_usage_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_usage_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: offers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;

--
-- Name: official_holidays; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.official_holidays ENABLE ROW LEVEL SECURITY;

--
-- Name: order_audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.order_audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: order_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

--
-- Name: orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

--
-- Name: overtime_registrations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.overtime_registrations ENABLE ROW LEVEL SECURITY;

--
-- Name: overtime_registrations overtime_registrations_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY overtime_registrations_all ON public.overtime_registrations USING (true) WITH CHECK (true);


--
-- Name: orders pickers_update_assigned_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pickers_update_assigned_orders ON public.orders FOR UPDATE USING ((picker_id = auth.uid())) WITH CHECK (((picker_id = auth.uid()) AND ((order_status)::text = ANY (ARRAY[('in_picking'::character varying)::text, ('ready'::character varying)::text]))));


--
-- Name: orders pickers_view_assigned_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pickers_view_assigned_orders ON public.orders FOR SELECT USING (((picker_id = auth.uid()) OR public.has_order_management_access(auth.uid())));


--
-- Name: POLICY pickers_view_assigned_orders ON orders; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY pickers_view_assigned_orders ON public.orders IS 'Pickers can view orders assigned to them';


--
-- Name: pos_deduction_transfers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pos_deduction_transfers ENABLE ROW LEVEL SECURITY;

--
-- Name: privilege_cards_branch; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.privilege_cards_branch ENABLE ROW LEVEL SECURITY;

--
-- Name: privilege_cards_master; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.privilege_cards_master ENABLE ROW LEVEL SECURITY;

--
-- Name: processed_fingerprint_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.processed_fingerprint_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: product_categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;

--
-- Name: product_request_bt; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_request_bt ENABLE ROW LEVEL SECURITY;

--
-- Name: product_request_po; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_request_po ENABLE ROW LEVEL SECURITY;

--
-- Name: product_request_st; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_request_st ENABLE ROW LEVEL SECURITY;

--
-- Name: product_units; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_units ENABLE ROW LEVEL SECURITY;

--
-- Name: products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_voucher_issue_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.purchase_voucher_issue_types ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_voucher_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.purchase_voucher_items ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_vouchers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.purchase_vouchers ENABLE ROW LEVEL SECURITY;

--
-- Name: push_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: purchase_vouchers pv_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pv_authenticated_all ON public.purchase_vouchers USING (true);


--
-- Name: purchase_voucher_issue_types pv_issue_types_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pv_issue_types_authenticated_all ON public.purchase_voucher_issue_types USING (true);


--
-- Name: purchase_voucher_issue_types pv_issue_types_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pv_issue_types_service_role_all ON public.purchase_voucher_issue_types USING (true);


--
-- Name: purchase_vouchers pv_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pv_service_role_all ON public.purchase_vouchers USING (true);


--
-- Name: purchase_voucher_items pvi_authenticated_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pvi_authenticated_all ON public.purchase_voucher_items USING (true);


--
-- Name: purchase_voucher_items pvi_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pvi_service_role_all ON public.purchase_voucher_items USING (true);


--
-- Name: quick_task_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quick_task_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: quick_task_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quick_task_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: quick_task_completions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quick_task_completions ENABLE ROW LEVEL SECURITY;

--
-- Name: quick_task_files; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quick_task_files ENABLE ROW LEVEL SECURITY;

--
-- Name: quick_task_user_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quick_task_user_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: quick_tasks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quick_tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: customer_access_code_history realtime_access_code_history_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY realtime_access_code_history_select ON public.customer_access_code_history FOR SELECT TO authenticated, anon USING (true);


--
-- Name: customers realtime_customers_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY realtime_customers_select ON public.customers FOR SELECT TO authenticated, anon USING (true);


--
-- Name: wa_messages realtime_wa_messages_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY realtime_wa_messages_select ON public.wa_messages FOR SELECT TO authenticated, anon USING (true);


--
-- Name: receiving_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.receiving_records ENABLE ROW LEVEL SECURITY;

--
-- Name: receiving_task_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.receiving_task_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: receiving_tasks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.receiving_tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: receiving_user_defaults; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.receiving_user_defaults ENABLE ROW LEVEL SECURITY;

--
-- Name: recurring_assignment_schedules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recurring_assignment_schedules ENABLE ROW LEVEL SECURITY;

--
-- Name: recurring_schedule_check_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recurring_schedule_check_log ENABLE ROW LEVEL SECURITY;

--
-- Name: regular_shift; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.regular_shift ENABLE ROW LEVEL SECURITY;

--
-- Name: requesters; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.requesters ENABLE ROW LEVEL SECURITY;

--
-- Name: branches rls_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_delete ON public.branches FOR DELETE USING (true);


--
-- Name: receiving_records rls_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_delete ON public.receiving_records FOR DELETE USING (true);


--
-- Name: vendors rls_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_delete ON public.vendors FOR DELETE USING (true);


--
-- Name: branches rls_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_insert ON public.branches FOR INSERT WITH CHECK (true);


--
-- Name: receiving_records rls_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_insert ON public.receiving_records FOR INSERT WITH CHECK (true);


--
-- Name: vendors rls_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_insert ON public.vendors FOR INSERT WITH CHECK (true);


--
-- Name: branches rls_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_select ON public.branches FOR SELECT USING (true);


--
-- Name: receiving_records rls_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_select ON public.receiving_records FOR SELECT USING (true);


--
-- Name: vendors rls_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_select ON public.vendors FOR SELECT USING (true);


--
-- Name: branches rls_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_update ON public.branches FOR UPDATE WITH CHECK (true);


--
-- Name: receiving_records rls_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_update ON public.receiving_records FOR UPDATE WITH CHECK (true);


--
-- Name: vendors rls_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rls_update ON public.vendors FOR UPDATE WITH CHECK (true);


--
-- Name: security_code_scroll_texts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.security_code_scroll_texts ENABLE ROW LEVEL SECURITY;

--
-- Name: access_code_otp service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY service_role_all ON public.access_code_otp TO service_role USING (true) WITH CHECK (true);


--
-- Name: settlement_rules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.settlement_rules ENABLE ROW LEVEL SECURITY;

--
-- Name: shelf_paper_fonts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shelf_paper_fonts ENABLE ROW LEVEL SECURITY;

--
-- Name: shelf_paper_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shelf_paper_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: sidebar_buttons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sidebar_buttons ENABLE ROW LEVEL SECURITY;

--
-- Name: social_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.social_links ENABLE ROW LEVEL SECURITY;

--
-- Name: special_shift_date_wise; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.special_shift_date_wise ENABLE ROW LEVEL SECURITY;

--
-- Name: special_shift_weekday; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.special_shift_weekday ENABLE ROW LEVEL SECURITY;

--
-- Name: special_shift_weekday special_shift_weekday_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY special_shift_weekday_policy ON public.special_shift_weekday USING (true) WITH CHECK (true);


--
-- Name: surprise_box_plays; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.surprise_box_plays ENABLE ROW LEVEL SECURITY;

--
-- Name: surprise_box_rewards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.surprise_box_rewards ENABLE ROW LEVEL SECURITY;

--
-- Name: surprise_box_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.surprise_box_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: surprise_box_vouchers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.surprise_box_vouchers ENABLE ROW LEVEL SECURITY;

--
-- Name: system_api_keys; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.system_api_keys ENABLE ROW LEVEL SECURITY;

--
-- Name: order_audit_logs system_insert_audit_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY system_insert_audit_logs ON public.order_audit_logs FOR INSERT WITH CHECK (true);


--
-- Name: order_items system_insert_order_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY system_insert_order_items ON public.order_items FOR INSERT WITH CHECK ((order_id IN ( SELECT orders.id
   FROM public.orders
  WHERE ((orders.customer_id = auth.uid()) OR public.has_order_management_access(auth.uid())))));


--
-- Name: task_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: task_completions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_completions ENABLE ROW LEVEL SECURITY;

--
-- Name: task_images; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_images ENABLE ROW LEVEL SECURITY;

--
-- Name: task_reminder_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.task_reminder_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: tasks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: user_audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: user_device_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_device_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_erp_credentials; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_erp_credentials ENABLE ROW LEVEL SECURITY;

--
-- Name: user_favorite_buttons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_favorite_buttons ENABLE ROW LEVEL SECURITY;

--
-- Name: user_mobile_theme_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_mobile_theme_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: user_password_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_password_history ENABLE ROW LEVEL SECURITY;

--
-- Name: user_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: user_theme_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_theme_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: user_voice_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_voice_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: order_audit_logs users_view_order_audit_logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_view_order_audit_logs ON public.order_audit_logs FOR SELECT USING ((order_id IN ( SELECT orders.id
   FROM public.orders
  WHERE ((orders.customer_id = auth.uid()) OR (orders.picker_id = auth.uid()) OR (orders.delivery_person_id = auth.uid()) OR public.has_order_management_access(auth.uid()) OR public.is_delivery_staff(auth.uid())))));


--
-- Name: POLICY users_view_order_audit_logs ON order_audit_logs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY users_view_order_audit_logs ON public.order_audit_logs IS 'Users can view audit logs for their orders';


--
-- Name: order_items users_view_order_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_view_order_items ON public.order_items FOR SELECT USING ((order_id IN ( SELECT orders.id
   FROM public.orders
  WHERE ((orders.customer_id = auth.uid()) OR (orders.picker_id = auth.uid()) OR (orders.delivery_person_id = auth.uid()) OR public.has_order_management_access(auth.uid()) OR public.is_delivery_staff(auth.uid())))));


--
-- Name: POLICY users_view_order_items ON order_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY users_view_order_items ON public.order_items IS 'Users can view items for orders they have access to';


--
-- Name: variation_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.variation_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: vendor_payment_schedule; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vendor_payment_schedule ENABLE ROW LEVEL SECURITY;

--
-- Name: vendor_payment_schedule vendor_payment_schedule_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vendor_payment_schedule_delete ON public.vendor_payment_schedule FOR DELETE USING (true);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vendor_payment_schedule_insert ON public.vendor_payment_schedule FOR INSERT WITH CHECK (true);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vendor_payment_schedule_select ON public.vendor_payment_schedule FOR SELECT USING (true);


--
-- Name: vendor_payment_schedule vendor_payment_schedule_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vendor_payment_schedule_update ON public.vendor_payment_schedule FOR UPDATE USING (true);


--
-- Name: vendors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;

--
-- Name: view_offer; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.view_offer ENABLE ROW LEVEL SECURITY;

--
-- Name: vip_campaign_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vip_campaign_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: vip_campaign_settings vip_campaign_settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vip_campaign_settings_delete ON public.vip_campaign_settings FOR DELETE TO authenticated, anon USING (true);


--
-- Name: vip_campaign_settings vip_campaign_settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vip_campaign_settings_insert ON public.vip_campaign_settings FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: vip_campaign_settings vip_campaign_settings_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vip_campaign_settings_select ON public.vip_campaign_settings FOR SELECT TO authenticated, anon USING (true);


--
-- Name: vip_campaign_settings vip_campaign_settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vip_campaign_settings_update ON public.vip_campaign_settings FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);


--
-- Name: vip_redemptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vip_redemptions ENABLE ROW LEVEL SECURITY;

--
-- Name: vip_redemptions vip_redemptions_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vip_redemptions_delete ON public.vip_redemptions FOR DELETE TO authenticated, anon USING (true);


--
-- Name: vip_redemptions vip_redemptions_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vip_redemptions_insert ON public.vip_redemptions FOR INSERT TO authenticated, anon WITH CHECK (true);


--
-- Name: vip_redemptions vip_redemptions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vip_redemptions_select ON public.vip_redemptions FOR SELECT TO authenticated, anon USING (true);


--
-- Name: vip_redemptions vip_redemptions_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vip_redemptions_update ON public.vip_redemptions FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);


--
-- Name: wa_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_ai_bot_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_ai_bot_config ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_auto_reply_triggers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_auto_reply_triggers ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_bot_flows; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_bot_flows ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_broadcast_recipients; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_broadcast_recipients ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_broadcasts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_broadcasts ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_catalog_orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_catalog_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_catalog_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_catalog_products ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_catalogs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_catalogs ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_contact_group_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_contact_group_members ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_contact_groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_contact_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: wa_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wa_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: warning_main_category; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.warning_main_category ENABLE ROW LEVEL SECURITY;

--
-- Name: warning_sub_category; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.warning_sub_category ENABLE ROW LEVEL SECURITY;

--
-- Name: warning_violation; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.warning_violation ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_message_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_message_log ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

