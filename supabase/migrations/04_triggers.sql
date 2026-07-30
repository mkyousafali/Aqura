-- ============================================
-- TRIGGER: ai_chat_guide_timestamp_update ON ai_chat_guide
-- ============================================
CREATE TRIGGER ai_chat_guide_timestamp_update BEFORE UPDATE ON ai_chat_guide FOR EACH ROW EXECUTE FUNCTION update_ai_chat_guide_timestamp();

-- ============================================
-- TRIGGER: trg_app_icons_updated_at ON app_icons
-- ============================================
CREATE TRIGGER trg_app_icons_updated_at BEFORE UPDATE ON app_icons FOR EACH ROW EXECUTE FUNCTION update_app_icons_updated_at();

-- ============================================
-- TRIGGER: update_approval_permissions_timestamp ON approval_permissions
-- ============================================
CREATE TRIGGER update_approval_permissions_timestamp BEFORE UPDATE ON approval_permissions FOR EACH ROW EXECUTE FUNCTION update_approval_permissions_updated_at();

-- ============================================
-- TRIGGER: approver_visibility_config_timestamp_update ON approver_visibility_config
-- ============================================
CREATE TRIGGER approver_visibility_config_timestamp_update BEFORE UPDATE ON approver_visibility_config FOR EACH ROW EXECUTE FUNCTION update_approver_visibility_config_timestamp();

-- ============================================
-- TRIGGER: trg_background_templates_updated_at ON background_templates
-- ============================================
CREATE TRIGGER trg_background_templates_updated_at BEFORE UPDATE ON background_templates FOR EACH ROW EXECUTE FUNCTION set_background_templates_updated_at();

-- ============================================
-- TRIGGER: bank_reconciliations_timestamp_update ON bank_reconciliations
-- ============================================
CREATE TRIGGER bank_reconciliations_timestamp_update BEFORE UPDATE ON bank_reconciliations FOR EACH ROW EXECUTE FUNCTION update_bank_reconciliations_timestamp();

-- ============================================
-- TRIGGER: trigger_update_bogo_offer_rules_updated_at ON bogo_offer_rules
-- ============================================
CREATE TRIGGER trigger_update_bogo_offer_rules_updated_at BEFORE UPDATE ON bogo_offer_rules FOR EACH ROW EXECUTE FUNCTION update_bogo_offer_rules_updated_at();

-- ============================================
-- TRIGGER: box_operations_updated_at ON box_operations
-- ============================================
CREATE TRIGGER box_operations_updated_at BEFORE UPDATE ON box_operations FOR EACH ROW EXECUTE FUNCTION update_box_operations_updated_at();

-- ============================================
-- TRIGGER: set_branch_delivery_receivers_updated_at ON branch_default_delivery_receivers
-- ============================================
CREATE TRIGGER set_branch_delivery_receivers_updated_at BEFORE UPDATE ON branch_default_delivery_receivers FOR EACH ROW EXECUTE FUNCTION update_branch_delivery_receivers_updated_at();

-- ============================================
-- TRIGGER: branch_default_positions_timestamp_update ON branch_default_positions
-- ============================================
CREATE TRIGGER branch_default_positions_timestamp_update BEFORE UPDATE ON branch_default_positions FOR EACH ROW EXECUTE FUNCTION update_branch_default_positions_timestamp();

-- ============================================
-- TRIGGER: branches_notify_trigger ON branches
-- ============================================
CREATE TRIGGER branches_notify_trigger AFTER INSERT OR DELETE OR UPDATE ON branches FOR EACH ROW EXECUTE FUNCTION notify_branches_change();

-- ============================================
-- TRIGGER: trigger_update_branches_updated_at ON branches
-- ============================================
CREATE TRIGGER trigger_update_branches_updated_at BEFORE UPDATE ON branches FOR EACH ROW EXECUTE FUNCTION update_branches_updated_at();

-- ============================================
-- TRIGGER: trigger_update_coupon_campaigns_updated_at ON coupon_campaigns
-- ============================================
CREATE TRIGGER trigger_update_coupon_campaigns_updated_at BEFORE UPDATE ON coupon_campaigns FOR EACH ROW EXECUTE FUNCTION update_coupon_campaigns_updated_at();

-- ============================================
-- TRIGGER: trigger_update_coupon_products_updated_at ON coupon_products
-- ============================================
CREATE TRIGGER trigger_update_coupon_products_updated_at BEFORE UPDATE ON coupon_products FOR EACH ROW EXECUTE FUNCTION update_coupon_products_updated_at();

-- ============================================
-- TRIGGER: track_media_activation ON customer_app_media
-- ============================================
CREATE TRIGGER track_media_activation BEFORE UPDATE ON customer_app_media FOR EACH ROW EXECUTE FUNCTION track_media_activation();

-- ============================================
-- TRIGGER: update_customer_app_media_timestamp ON customer_app_media
-- ============================================
CREATE TRIGGER update_customer_app_media_timestamp BEFORE UPDATE ON customer_app_media FOR EACH ROW EXECUTE FUNCTION update_customer_app_media_timestamp();

-- ============================================
-- TRIGGER: trigger_update_customer_recovery_requests_updated_at ON customer_recovery_requests
-- ============================================
CREATE TRIGGER trigger_update_customer_recovery_requests_updated_at BEFORE UPDATE ON customer_recovery_requests FOR EACH ROW EXECUTE FUNCTION update_customer_recovery_requests_updated_at();

-- ============================================
-- TRIGGER: trigger_update_customers_updated_at ON customers
-- ============================================
CREATE TRIGGER trigger_update_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_customers_updated_at();

-- ============================================
-- TRIGGER: day_off_timestamp_trigger ON day_off
-- ============================================
CREATE TRIGGER day_off_timestamp_trigger BEFORE UPDATE ON day_off FOR EACH ROW EXECUTE FUNCTION update_day_off_timestamp();

-- ============================================
-- TRIGGER: day_off_reasons_timestamp_update ON day_off_reasons
-- ============================================
CREATE TRIGGER day_off_reasons_timestamp_update BEFORE UPDATE ON day_off_reasons FOR EACH ROW EXECUTE FUNCTION update_day_off_reasons_timestamp();

-- ============================================
-- TRIGGER: day_off_weekday_updated_at_trigger ON day_off_weekday
-- ============================================
CREATE TRIGGER day_off_weekday_updated_at_trigger BEFORE UPDATE ON day_off_weekday FOR EACH ROW EXECUTE FUNCTION update_day_off_weekday_updated_at();

-- ============================================
-- TRIGGER: trigger_update_delivery_tiers_timestamp ON delivery_fee_tiers
-- ============================================
CREATE TRIGGER trigger_update_delivery_tiers_timestamp BEFORE UPDATE ON delivery_fee_tiers FOR EACH ROW EXECUTE FUNCTION update_delivery_tiers_timestamp();

-- ============================================
-- TRIGGER: trigger_update_delivery_settings_timestamp ON delivery_service_settings
-- ============================================
CREATE TRIGGER trigger_update_delivery_settings_timestamp BEFORE UPDATE ON delivery_service_settings FOR EACH ROW EXECUTE FUNCTION update_delivery_tiers_timestamp();

-- ============================================
-- TRIGGER: denomination_records_audit ON denomination_records
-- ============================================
CREATE TRIGGER denomination_records_audit AFTER INSERT OR DELETE OR UPDATE ON denomination_records FOR EACH ROW EXECUTE FUNCTION denomination_audit_trigger();

-- ============================================
-- TRIGGER: denomination_records_updated_at ON denomination_records
-- ============================================
CREATE TRIGGER denomination_records_updated_at BEFORE UPDATE ON denomination_records FOR EACH ROW EXECUTE FUNCTION update_denomination_updated_at();

-- ============================================
-- TRIGGER: denomination_transactions_timestamp_update ON denomination_transactions
-- ============================================
CREATE TRIGGER denomination_transactions_timestamp_update BEFORE UPDATE ON denomination_transactions FOR EACH ROW EXECUTE FUNCTION update_denomination_transactions_timestamp();

-- ============================================
-- TRIGGER: denomination_types_updated_at ON denomination_types
-- ============================================
CREATE TRIGGER denomination_types_updated_at BEFORE UPDATE ON denomination_types FOR EACH ROW EXECUTE FUNCTION update_denomination_updated_at();

-- ============================================
-- TRIGGER: desktop_themes_timestamp_update ON desktop_themes
-- ============================================
CREATE TRIGGER desktop_themes_timestamp_update BEFORE UPDATE ON desktop_themes FOR EACH ROW EXECUTE FUNCTION update_desktop_themes_timestamp();

-- ============================================
-- TRIGGER: trg_email_account_secrets_updated_at ON email_account_secrets
-- ============================================
CREATE TRIGGER trg_email_account_secrets_updated_at BEFORE UPDATE ON email_account_secrets FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_accounts_single_default ON email_accounts
-- ============================================
CREATE TRIGGER trg_email_accounts_single_default BEFORE INSERT OR UPDATE ON email_accounts FOR EACH ROW EXECUTE FUNCTION email_enforce_single_default();

-- ============================================
-- TRIGGER: trg_email_accounts_updated_at ON email_accounts
-- ============================================
CREATE TRIGGER trg_email_accounts_updated_at BEFORE UPDATE ON email_accounts FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_ai_settings_updated_at ON email_ai_settings
-- ============================================
CREATE TRIGGER trg_email_ai_settings_updated_at BEFORE UPDATE ON email_ai_settings FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_attachments_updated_at ON email_attachments
-- ============================================
CREATE TRIGGER trg_email_attachments_updated_at BEFORE UPDATE ON email_attachments FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_campaign_recipients_updated_at ON email_campaign_recipients
-- ============================================
CREATE TRIGGER trg_email_campaign_recipients_updated_at BEFORE UPDATE ON email_campaign_recipients FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_campaigns_updated_at ON email_campaigns
-- ============================================
CREATE TRIGGER trg_email_campaigns_updated_at BEFORE UPDATE ON email_campaigns FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_folders_updated_at ON email_folders
-- ============================================
CREATE TRIGGER trg_email_folders_updated_at BEFORE UPDATE ON email_folders FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_group_members_updated_at ON email_group_members
-- ============================================
CREATE TRIGGER trg_email_group_members_updated_at BEFORE UPDATE ON email_group_members FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_groups_updated_at ON email_groups
-- ============================================
CREATE TRIGGER trg_email_groups_updated_at BEFORE UPDATE ON email_groups FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_message_recipients_updated_at ON email_message_recipients
-- ============================================
CREATE TRIGGER trg_email_message_recipients_updated_at BEFORE UPDATE ON email_message_recipients FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_messages_updated_at ON email_messages
-- ============================================
CREATE TRIGGER trg_email_messages_updated_at BEFORE UPDATE ON email_messages FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_provider_presets_updated_at ON email_provider_presets
-- ============================================
CREATE TRIGGER trg_email_provider_presets_updated_at BEFORE UPDATE ON email_provider_presets FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_queue_updated_at ON email_queue
-- ============================================
CREATE TRIGGER trg_email_queue_updated_at BEFORE UPDATE ON email_queue FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_settings_updated_at ON email_settings
-- ============================================
CREATE TRIGGER trg_email_settings_updated_at BEFORE UPDATE ON email_settings FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_signatures_updated_at ON email_signatures
-- ============================================
CREATE TRIGGER trg_email_signatures_updated_at BEFORE UPDATE ON email_signatures FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_suppressions_updated_at ON email_suppressions
-- ============================================
CREATE TRIGGER trg_email_suppressions_updated_at BEFORE UPDATE ON email_suppressions FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_templates_updated_at ON email_templates
-- ============================================
CREATE TRIGGER trg_email_templates_updated_at BEFORE UPDATE ON email_templates FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: trg_email_threads_updated_at ON email_threads
-- ============================================
CREATE TRIGGER trg_email_threads_updated_at BEFORE UPDATE ON email_threads FOR EACH ROW EXECUTE FUNCTION email_update_timestamp();

-- ============================================
-- TRIGGER: update_erp_connections_updated_at ON erp_connections
-- ============================================
CREATE TRIGGER update_erp_connections_updated_at BEFORE UPDATE ON erp_connections FOR EACH ROW EXECUTE FUNCTION update_erp_connections_updated_at();

-- ============================================
-- TRIGGER: erp_daily_sales_notify_trigger ON erp_daily_sales
-- ============================================
CREATE TRIGGER erp_daily_sales_notify_trigger AFTER INSERT OR DELETE OR UPDATE ON erp_daily_sales FOR EACH ROW EXECUTE FUNCTION notify_erp_daily_sales_change();

-- ============================================
-- TRIGGER: update_erp_daily_sales_updated_at ON erp_daily_sales
-- ============================================
CREATE TRIGGER update_erp_daily_sales_updated_at BEFORE UPDATE ON erp_daily_sales FOR EACH ROW EXECUTE FUNCTION update_erp_daily_sales_updated_at();

-- ============================================
-- TRIGGER: expense_scheduler_updated_at ON expense_scheduler
-- ============================================
CREATE TRIGGER expense_scheduler_updated_at BEFORE UPDATE ON expense_scheduler FOR EACH ROW EXECUTE FUNCTION update_expense_scheduler_updated_at();

-- ============================================
-- TRIGGER: sync_requisition_balance_trigger ON expense_scheduler
-- ============================================
CREATE TRIGGER sync_requisition_balance_trigger AFTER INSERT OR UPDATE ON expense_scheduler FOR EACH ROW EXECUTE FUNCTION sync_requisition_balance();

-- ============================================
-- TRIGGER: trigger_update_requisition_balance ON expense_scheduler
-- ============================================
CREATE TRIGGER trigger_update_requisition_balance AFTER INSERT OR DELETE OR UPDATE ON expense_scheduler FOR EACH ROW EXECUTE FUNCTION update_requisition_balance();

-- ============================================
-- TRIGGER: trigger_update_requisition_balance_old ON expense_scheduler
-- ============================================
CREATE TRIGGER trigger_update_requisition_balance_old BEFORE DELETE OR UPDATE ON expense_scheduler FOR EACH ROW EXECUTE FUNCTION update_requisition_balance_old();

-- ============================================
-- TRIGGER: update_flyer_offers_updated_at ON flyer_offers
-- ============================================
CREATE TRIGGER update_flyer_offers_updated_at BEFORE UPDATE ON flyer_offers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- TRIGGER: trigger_ensure_single_default_flyer_template ON flyer_templates
-- ============================================
CREATE TRIGGER trigger_ensure_single_default_flyer_template BEFORE INSERT OR UPDATE OF is_default ON flyer_templates FOR EACH ROW WHEN (new.is_default = true) EXECUTE FUNCTION ensure_single_default_flyer_template();

-- ============================================
-- TRIGGER: trigger_update_flyer_templates_updated_at ON flyer_templates
-- ============================================
CREATE TRIGGER trigger_update_flyer_templates_updated_at BEFORE UPDATE ON flyer_templates FOR EACH ROW EXECUTE FUNCTION update_flyer_templates_updated_at();

-- ============================================
-- TRIGGER: hr_checklist_operations_timestamp_update ON hr_checklist_operations
-- ============================================
CREATE TRIGGER hr_checklist_operations_timestamp_update BEFORE UPDATE ON hr_checklist_operations FOR EACH ROW EXECUTE FUNCTION update_hr_checklist_operations_timestamp();

-- ============================================
-- TRIGGER: hr_checklist_questions_timestamp_update ON hr_checklist_questions
-- ============================================
CREATE TRIGGER hr_checklist_questions_timestamp_update BEFORE UPDATE ON hr_checklist_questions FOR EACH ROW EXECUTE FUNCTION update_hr_checklist_questions_timestamp();

-- ============================================
-- TRIGGER: hr_checklists_timestamp_update ON hr_checklists
-- ============================================
CREATE TRIGGER hr_checklists_timestamp_update BEFORE UPDATE ON hr_checklists FOR EACH ROW EXECUTE FUNCTION update_hr_checklists_timestamp();

-- ============================================
-- TRIGGER: set_hr_employee_applicability_rule_periods_updated_at ON hr_employee_applicability_rule_periods
-- ============================================
CREATE TRIGGER set_hr_employee_applicability_rule_periods_updated_at BEFORE UPDATE ON hr_employee_applicability_rule_periods FOR EACH ROW EXECUTE FUNCTION update_hr_employee_applicability_rule_periods_updated_at();

-- ============================================
-- TRIGGER: trg_touch_hr_employee_esob_records ON hr_employee_esob_records
-- ============================================
CREATE TRIGGER trg_touch_hr_employee_esob_records BEFORE UPDATE ON hr_employee_esob_records FOR EACH ROW EXECUTE FUNCTION touch_hr_esob_updated_at();

-- ============================================
-- TRIGGER: set_hr_employee_leave_approvals_updated_at ON hr_employee_leave_approvals
-- ============================================
CREATE TRIGGER set_hr_employee_leave_approvals_updated_at BEFORE UPDATE ON hr_employee_leave_approvals FOR EACH ROW EXECUTE FUNCTION update_hr_employee_leave_approvals_updated_at();

-- ============================================
-- TRIGGER: hr_employee_master_timestamp_update ON hr_employee_master
-- ============================================
CREATE TRIGGER hr_employee_master_timestamp_update BEFORE UPDATE ON hr_employee_master FOR EACH ROW EXECUTE FUNCTION update_hr_employee_master_timestamp();

-- ============================================
-- TRIGGER: set_hr_employee_settlement_applicability_updated_at ON hr_employee_settlement_applicability
-- ============================================
CREATE TRIGGER set_hr_employee_settlement_applicability_updated_at BEFORE UPDATE ON hr_employee_settlement_applicability FOR EACH ROW EXECUTE FUNCTION update_hr_employee_settlement_applicability_updated_at();

-- ============================================
-- TRIGGER: set_hr_employee_ticket_issuances_updated_at ON hr_employee_ticket_issuances
-- ============================================
CREATE TRIGGER set_hr_employee_ticket_issuances_updated_at BEFORE UPDATE ON hr_employee_ticket_issuances FOR EACH ROW EXECUTE FUNCTION update_hr_employee_ticket_issuances_updated_at();

-- ============================================
-- TRIGGER: trg_touch_hr_esob_base_rules ON hr_esob_base_rules
-- ============================================
CREATE TRIGGER trg_touch_hr_esob_base_rules BEFORE UPDATE ON hr_esob_base_rules FOR EACH ROW EXECUTE FUNCTION touch_hr_esob_updated_at();

-- ============================================
-- TRIGGER: trg_touch_hr_esob_resignation_factors ON hr_esob_resignation_factors
-- ============================================
CREATE TRIGGER trg_touch_hr_esob_resignation_factors BEFORE UPDATE ON hr_esob_resignation_factors FOR EACH ROW EXECUTE FUNCTION touch_hr_esob_updated_at();

-- ============================================
-- TRIGGER: trg_auto_process_fingerprints ON hr_fingerprint_transactions
-- ============================================
CREATE TRIGGER trg_auto_process_fingerprints AFTER INSERT ON hr_fingerprint_transactions FOR EACH STATEMENT EXECUTE FUNCTION trigger_process_fingerprints();

-- ============================================
-- TRIGGER: trg_generate_insurance_company_id ON hr_insurance_companies
-- ============================================
CREATE TRIGGER trg_generate_insurance_company_id BEFORE INSERT ON hr_insurance_companies FOR EACH ROW EXECUTE FUNCTION generate_insurance_company_id();

-- ============================================
-- TRIGGER: sync_roles_on_position_changes ON hr_positions
-- ============================================
CREATE TRIGGER sync_roles_on_position_changes AFTER INSERT OR DELETE OR UPDATE ON hr_positions FOR EACH ROW EXECUTE FUNCTION sync_user_roles_from_positions();

-- ============================================
-- TRIGGER: trg_hr_salary_notes_updated_at ON hr_salary_notes
-- ============================================
CREATE TRIGGER trg_hr_salary_notes_updated_at BEFORE UPDATE ON hr_salary_notes FOR EACH ROW EXECUTE FUNCTION set_hr_salary_notes_updated_at();

-- ============================================
-- TRIGGER: hr_salary_statements_set_updated_at ON hr_salary_statements
-- ============================================
CREATE TRIGGER hr_salary_statements_set_updated_at BEFORE UPDATE ON hr_salary_statements FOR EACH ROW EXECUTE FUNCTION tg_hr_salary_statements_set_updated_at();

-- ============================================
-- TRIGGER: trigger_update_interface_permissions_updated_at ON interface_permissions
-- ============================================
CREATE TRIGGER trigger_update_interface_permissions_updated_at BEFORE UPDATE ON interface_permissions FOR EACH ROW EXECUTE FUNCTION update_interface_permissions_updated_at();

-- ============================================
-- TRIGGER: lease_rent_lease_parties_timestamp_update ON lease_rent_lease_parties
-- ============================================
CREATE TRIGGER lease_rent_lease_parties_timestamp_update BEFORE UPDATE ON lease_rent_lease_parties FOR EACH ROW EXECUTE FUNCTION update_lease_rent_lease_parties_timestamp();

-- ============================================
-- TRIGGER: lease_rent_properties_timestamp_update ON lease_rent_properties
-- ============================================
CREATE TRIGGER lease_rent_properties_timestamp_update BEFORE UPDATE ON lease_rent_properties FOR EACH ROW EXECUTE FUNCTION update_lease_rent_property_spaces_timestamp();

-- ============================================
-- TRIGGER: lease_rent_property_spaces_timestamp_update ON lease_rent_property_spaces
-- ============================================
CREATE TRIGGER lease_rent_property_spaces_timestamp_update BEFORE UPDATE ON lease_rent_property_spaces FOR EACH ROW EXECUTE FUNCTION update_lease_rent_property_spaces_timestamp();

-- ============================================
-- TRIGGER: lease_rent_rent_parties_timestamp_update ON lease_rent_rent_parties
-- ============================================
CREATE TRIGGER lease_rent_rent_parties_timestamp_update BEFORE UPDATE ON lease_rent_rent_parties FOR EACH ROW EXECUTE FUNCTION update_lease_rent_rent_parties_timestamp();

-- ============================================
-- TRIGGER: sync_customer_loyalty_on_bill ON loyalty_customer_bills
-- ============================================
CREATE TRIGGER sync_customer_loyalty_on_bill AFTER INSERT ON loyalty_customer_bills FOR EACH ROW EXECUTE FUNCTION trg_sync_customer_loyalty_on_bill();

-- ============================================
-- TRIGGER: multi_shift_date_wise_timestamp_update ON multi_shift_date_wise
-- ============================================
CREATE TRIGGER multi_shift_date_wise_timestamp_update BEFORE UPDATE ON multi_shift_date_wise FOR EACH ROW EXECUTE FUNCTION update_multi_shift_date_wise_timestamp();

-- ============================================
-- TRIGGER: multi_shift_regular_timestamp_update ON multi_shift_regular
-- ============================================
CREATE TRIGGER multi_shift_regular_timestamp_update BEFORE UPDATE ON multi_shift_regular FOR EACH ROW EXECUTE FUNCTION update_multi_shift_regular_timestamp();

-- ============================================
-- TRIGGER: multi_shift_weekday_timestamp_update ON multi_shift_weekday
-- ============================================
CREATE TRIGGER multi_shift_weekday_timestamp_update BEFORE UPDATE ON multi_shift_weekday FOR EACH ROW EXECUTE FUNCTION update_multi_shift_weekday_timestamp();

-- ============================================
-- TRIGGER: trigger_update_near_expiry_reports_updated_at ON near_expiry_reports
-- ============================================
CREATE TRIGGER trigger_update_near_expiry_reports_updated_at BEFORE UPDATE ON near_expiry_reports FOR EACH ROW EXECUTE FUNCTION update_near_expiry_reports_updated_at();

-- ============================================
-- TRIGGER: non_approved_scheduler_updated_at ON non_approved_payment_scheduler
-- ============================================
CREATE TRIGGER non_approved_scheduler_updated_at BEFORE UPDATE ON non_approved_payment_scheduler FOR EACH ROW EXECUTE FUNCTION update_non_approved_scheduler_updated_at();

-- ============================================
-- TRIGGER: trigger_create_notification_recipients ON notifications
-- ============================================
CREATE TRIGGER trigger_create_notification_recipients AFTER INSERT ON notifications FOR EACH ROW WHEN (new.status::text = 'published'::text) EXECUTE FUNCTION create_notification_recipients();

-- ============================================
-- TRIGGER: trigger_update_offer_bundles_updated_at ON offer_bundles
-- ============================================
CREATE TRIGGER trigger_update_offer_bundles_updated_at BEFORE UPDATE ON offer_bundles FOR EACH ROW EXECUTE FUNCTION update_offers_updated_at();

-- ============================================
-- TRIGGER: trigger_validate_bundle_offer_type ON offer_bundles
-- ============================================
CREATE TRIGGER trigger_validate_bundle_offer_type BEFORE INSERT OR UPDATE ON offer_bundles FOR EACH ROW EXECUTE FUNCTION validate_bundle_offer_type();

-- ============================================
-- TRIGGER: update_offer_cart_tiers_updated_at ON offer_cart_tiers
-- ============================================
CREATE TRIGGER update_offer_cart_tiers_updated_at BEFORE UPDATE ON offer_cart_tiers FOR EACH ROW EXECUTE FUNCTION update_offer_cart_tiers_updated_at();

-- ============================================
-- TRIGGER: update_offer_products_updated_at ON offer_products
-- ============================================
CREATE TRIGGER update_offer_products_updated_at BEFORE UPDATE ON offer_products FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- TRIGGER: trigger_update_offers_updated_at ON offers
-- ============================================
CREATE TRIGGER trigger_update_offers_updated_at BEFORE UPDATE ON offers FOR EACH ROW EXECUTE FUNCTION update_offers_updated_at();

-- ============================================
-- TRIGGER: official_holidays_timestamp_trigger ON official_holidays
-- ============================================
CREATE TRIGGER official_holidays_timestamp_trigger BEFORE UPDATE ON official_holidays FOR EACH ROW EXECUTE FUNCTION update_official_holidays_timestamp();

-- ============================================
-- TRIGGER: trigger_customer_push_on_status_change ON order_audit_logs
-- ============================================
CREATE TRIGGER trigger_customer_push_on_status_change AFTER INSERT ON order_audit_logs FOR EACH ROW WHEN (new.action_type::text = 'status_change'::text) EXECUTE FUNCTION notify_customer_order_status_change();

-- ============================================
-- TRIGGER: trigger_adjust_product_stock ON order_items
-- ============================================
CREATE TRIGGER trigger_adjust_product_stock BEFORE INSERT ON order_items FOR EACH ROW EXECUTE FUNCTION adjust_product_stock_on_order_insert();

-- ============================================
-- TRIGGER: trigger_link_offer_usage_to_order ON order_items
-- ============================================
CREATE TRIGGER trigger_link_offer_usage_to_order AFTER INSERT ON order_items FOR EACH ROW WHEN (new.has_offer = true AND new.offer_id IS NOT NULL) EXECUTE FUNCTION trigger_log_order_offer_usage();

-- ============================================
-- TRIGGER: trigger_order_items_delete_totals ON order_items
-- ============================================
CREATE TRIGGER trigger_order_items_delete_totals AFTER DELETE ON order_items FOR EACH ROW EXECUTE FUNCTION trigger_update_order_totals();

-- ============================================
-- TRIGGER: trigger_order_items_insert_totals ON order_items
-- ============================================
CREATE TRIGGER trigger_order_items_insert_totals AFTER INSERT ON order_items FOR EACH ROW EXECUTE FUNCTION trigger_update_order_totals();

-- ============================================
-- TRIGGER: trigger_order_items_update_totals ON order_items
-- ============================================
CREATE TRIGGER trigger_order_items_update_totals AFTER UPDATE ON order_items FOR EACH ROW EXECUTE FUNCTION trigger_update_order_totals();

-- ============================================
-- TRIGGER: trigger_new_order_notification ON orders
-- ============================================
CREATE TRIGGER trigger_new_order_notification AFTER INSERT ON orders FOR EACH ROW EXECUTE FUNCTION trigger_notify_new_order();

-- ============================================
-- TRIGGER: trigger_order_status_change_audit ON orders
-- ============================================
CREATE TRIGGER trigger_order_status_change_audit AFTER UPDATE ON orders FOR EACH ROW WHEN (old.order_status::text IS DISTINCT FROM new.order_status::text) EXECUTE FUNCTION trigger_order_status_audit();

-- ============================================
-- TRIGGER: update_orders_updated_at ON orders
-- ============================================
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- TRIGGER: trigger_update_pos_deduction_transfers_updated_at ON pos_deduction_transfers
-- ============================================
CREATE TRIGGER trigger_update_pos_deduction_transfers_updated_at BEFORE UPDATE ON pos_deduction_transfers FOR EACH ROW EXECUTE FUNCTION update_pos_deduction_transfers_updated_at();

-- ============================================
-- TRIGGER: product_request_bt_timestamp_update ON product_request_bt
-- ============================================
CREATE TRIGGER product_request_bt_timestamp_update BEFORE UPDATE ON product_request_bt FOR EACH ROW EXECUTE FUNCTION update_product_request_bt_timestamp();

-- ============================================
-- TRIGGER: product_request_po_timestamp_update ON product_request_po
-- ============================================
CREATE TRIGGER product_request_po_timestamp_update BEFORE UPDATE ON product_request_po FOR EACH ROW EXECUTE FUNCTION update_product_request_po_timestamp();

-- ============================================
-- TRIGGER: product_request_st_timestamp_update ON product_request_st
-- ============================================
CREATE TRIGGER product_request_st_timestamp_update BEFORE UPDATE ON product_request_st FOR EACH ROW EXECUTE FUNCTION update_product_request_st_timestamp();

-- ============================================
-- TRIGGER: trigger_calculate_flyer_product_profit ON products
-- ============================================
CREATE TRIGGER trigger_calculate_flyer_product_profit BEFORE INSERT OR UPDATE OF sale_price, cost ON products FOR EACH ROW EXECUTE FUNCTION calculate_flyer_product_profit();

-- ============================================
-- TRIGGER: issue_types_updated_at_trigger ON purchase_voucher_issue_types
-- ============================================
CREATE TRIGGER issue_types_updated_at_trigger BEFORE UPDATE ON purchase_voucher_issue_types FOR EACH ROW EXECUTE FUNCTION update_issue_types_updated_at();

-- ============================================
-- TRIGGER: purchase_voucher_items_updated_at_trigger ON purchase_voucher_items
-- ============================================
CREATE TRIGGER purchase_voucher_items_updated_at_trigger BEFORE UPDATE ON purchase_voucher_items FOR EACH ROW EXECUTE FUNCTION update_purchase_voucher_items_updated_at();

-- ============================================
-- TRIGGER: purchase_vouchers_updated_at_trigger ON purchase_vouchers
-- ============================================
CREATE TRIGGER purchase_vouchers_updated_at_trigger BEFORE UPDATE ON purchase_vouchers FOR EACH ROW EXECUTE FUNCTION update_purchase_vouchers_updated_at();

-- ============================================
-- TRIGGER: set_push_subscriptions_updated_at ON push_subscriptions
-- ============================================
CREATE TRIGGER set_push_subscriptions_updated_at BEFORE UPDATE ON push_subscriptions FOR EACH ROW EXECUTE FUNCTION update_push_subscriptions_updated_at();

-- ============================================
-- TRIGGER: trigger_copy_completion_requirements ON quick_task_assignments
-- ============================================
CREATE TRIGGER trigger_copy_completion_requirements AFTER INSERT ON quick_task_assignments FOR EACH ROW EXECUTE FUNCTION copy_completion_requirements_to_assignment();

-- ============================================
-- TRIGGER: trigger_create_quick_task_notification ON quick_task_assignments
-- ============================================
CREATE TRIGGER trigger_create_quick_task_notification AFTER INSERT ON quick_task_assignments FOR EACH ROW EXECUTE FUNCTION create_quick_task_notification();

-- ============================================
-- TRIGGER: trigger_order_task_completion ON quick_task_assignments
-- ============================================
CREATE TRIGGER trigger_order_task_completion AFTER UPDATE ON quick_task_assignments FOR EACH ROW WHEN (old.status::text IS DISTINCT FROM new.status::text AND new.status::text = 'completed'::text) EXECUTE FUNCTION handle_order_task_completion();

-- ============================================
-- TRIGGER: trigger_update_quick_task_status ON quick_task_assignments
-- ============================================
CREATE TRIGGER trigger_update_quick_task_status AFTER UPDATE ON quick_task_assignments FOR EACH ROW EXECUTE FUNCTION update_quick_task_status();

-- ============================================
-- TRIGGER: trigger_update_quick_task_completions_updated_at ON quick_task_completions
-- ============================================
CREATE TRIGGER trigger_update_quick_task_completions_updated_at BEFORE UPDATE ON quick_task_completions FOR EACH ROW EXECUTE FUNCTION update_quick_task_completions_updated_at();

-- ============================================
-- TRIGGER: calculate_receiving_amounts_trigger ON receiving_records
-- ============================================
CREATE TRIGGER calculate_receiving_amounts_trigger BEFORE INSERT OR UPDATE ON receiving_records FOR EACH ROW EXECUTE FUNCTION calculate_receiving_amounts();

-- ============================================
-- TRIGGER: trigger_auto_create_payment_schedule ON receiving_records
-- ============================================
CREATE TRIGGER trigger_auto_create_payment_schedule AFTER INSERT OR UPDATE OF certificate_url ON receiving_records FOR EACH ROW EXECUTE FUNCTION auto_create_payment_schedule();

-- ============================================
-- TRIGGER: trigger_update_receiving_task_templates_updated_at ON receiving_task_templates
-- ============================================
CREATE TRIGGER trigger_update_receiving_task_templates_updated_at BEFORE UPDATE ON receiving_task_templates FOR EACH ROW EXECUTE FUNCTION update_receiving_task_templates_updated_at();

-- ============================================
-- TRIGGER: trigger_update_receiving_tasks_updated_at ON receiving_tasks
-- ============================================
CREATE TRIGGER trigger_update_receiving_tasks_updated_at BEFORE UPDATE ON receiving_tasks FOR EACH ROW EXECUTE FUNCTION update_receiving_tasks_updated_at();

-- ============================================
-- TRIGGER: receiving_user_defaults_timestamp_update ON receiving_user_defaults
-- ============================================
CREATE TRIGGER receiving_user_defaults_timestamp_update BEFORE UPDATE ON receiving_user_defaults FOR EACH ROW EXECUTE FUNCTION update_receiving_user_defaults_timestamp();

-- ============================================
-- TRIGGER: calculate_working_hours_trigger ON regular_shift
-- ============================================
CREATE TRIGGER calculate_working_hours_trigger BEFORE INSERT OR UPDATE ON regular_shift FOR EACH ROW EXECUTE FUNCTION calculate_working_hours();

-- ============================================
-- TRIGGER: regular_shift_timestamp_update ON regular_shift
-- ============================================
CREATE TRIGGER regular_shift_timestamp_update BEFORE UPDATE ON regular_shift FOR EACH ROW EXECUTE FUNCTION update_regular_shift_timestamp();

-- ============================================
-- TRIGGER: update_requesters_updated_at ON requesters
-- ============================================
CREATE TRIGGER update_requesters_updated_at BEFORE UPDATE ON requesters FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- TRIGGER: set_settlement_rules_updated_at ON settlement_rules
-- ============================================
CREATE TRIGGER set_settlement_rules_updated_at BEFORE UPDATE ON settlement_rules FOR EACH ROW EXECUTE FUNCTION update_settlement_rules_updated_at();

-- ============================================
-- TRIGGER: update_shelf_paper_templates_updated_at ON shelf_paper_templates
-- ============================================
CREATE TRIGGER update_shelf_paper_templates_updated_at BEFORE UPDATE ON shelf_paper_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- TRIGGER: social_links_updated_at_trigger ON social_links
-- ============================================
CREATE TRIGGER social_links_updated_at_trigger BEFORE UPDATE ON social_links FOR EACH ROW EXECUTE FUNCTION update_social_links_updated_at();

-- ============================================
-- TRIGGER: special_shift_date_wise_timestamp_trigger ON special_shift_date_wise
-- ============================================
CREATE TRIGGER special_shift_date_wise_timestamp_trigger BEFORE UPDATE ON special_shift_date_wise FOR EACH ROW EXECUTE FUNCTION update_special_shift_date_wise_timestamp();

-- ============================================
-- TRIGGER: special_shift_weekday_timestamp_update ON special_shift_weekday
-- ============================================
CREATE TRIGGER special_shift_weekday_timestamp_update BEFORE UPDATE ON special_shift_weekday FOR EACH ROW EXECUTE FUNCTION update_special_shift_weekday_timestamp();

-- ============================================
-- TRIGGER: trg_surprise_box_rewards_updated_at ON surprise_box_rewards
-- ============================================
CREATE TRIGGER trg_surprise_box_rewards_updated_at BEFORE UPDATE ON surprise_box_rewards FOR EACH ROW EXECUTE FUNCTION surprise_box_rewards_set_updated_at();

-- ============================================
-- TRIGGER: trg_surprise_box_settings_updated_at ON surprise_box_settings
-- ============================================
CREATE TRIGGER trg_surprise_box_settings_updated_at BEFORE UPDATE ON surprise_box_settings FOR EACH ROW EXECUTE FUNCTION surprise_box_settings_set_updated_at();

-- ============================================
-- TRIGGER: system_api_keys_timestamp_update ON system_api_keys
-- ============================================
CREATE TRIGGER system_api_keys_timestamp_update BEFORE UPDATE ON system_api_keys FOR EACH ROW EXECUTE FUNCTION update_system_api_keys_timestamp();

-- ============================================
-- TRIGGER: cleanup_assignment_notifications_trigger ON task_assignments
-- ============================================
CREATE TRIGGER cleanup_assignment_notifications_trigger AFTER DELETE ON task_assignments FOR EACH ROW EXECUTE FUNCTION trigger_cleanup_assignment_notifications();

-- ============================================
-- TRIGGER: trigger_update_deadline_datetime ON task_assignments
-- ============================================
CREATE TRIGGER trigger_update_deadline_datetime BEFORE INSERT OR UPDATE OF deadline_date, deadline_time ON task_assignments FOR EACH ROW EXECUTE FUNCTION update_deadline_datetime();

-- ============================================
-- TRIGGER: trigger_sync_erp_on_completion ON task_completions
-- ============================================
CREATE TRIGGER trigger_sync_erp_on_completion AFTER INSERT OR UPDATE ON task_completions FOR EACH ROW EXECUTE FUNCTION trigger_sync_erp_reference_on_task_completion();

-- ============================================
-- TRIGGER: cleanup_task_notifications_trigger ON tasks
-- ============================================
CREATE TRIGGER cleanup_task_notifications_trigger AFTER DELETE ON tasks FOR EACH ROW EXECUTE FUNCTION trigger_cleanup_task_notifications();

-- ============================================
-- TRIGGER: trigger_user_device_sessions_updated_at ON user_device_sessions
-- ============================================
CREATE TRIGGER trigger_user_device_sessions_updated_at BEFORE UPDATE ON user_device_sessions FOR EACH ROW EXECUTE FUNCTION update_user_device_sessions_updated_at();

-- ============================================
-- TRIGGER: trg_user_erp_credentials_updated_at ON user_erp_credentials
-- ============================================
CREATE TRIGGER trg_user_erp_credentials_updated_at BEFORE UPDATE ON user_erp_credentials FOR EACH ROW EXECUTE FUNCTION set_user_erp_credentials_updated_at();

-- ============================================
-- TRIGGER: user_theme_assignments_timestamp_update ON user_theme_assignments
-- ============================================
CREATE TRIGGER user_theme_assignments_timestamp_update BEFORE UPDATE ON user_theme_assignments FOR EACH ROW EXECUTE FUNCTION update_user_theme_assignments_timestamp();

-- ============================================
-- TRIGGER: trigger_create_default_interface_permissions ON users
-- ============================================
CREATE TRIGGER trigger_create_default_interface_permissions AFTER INSERT ON users FOR EACH ROW EXECUTE FUNCTION create_default_interface_permissions();

-- ============================================
-- TRIGGER: update_users_updated_at ON users
-- ============================================
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- TRIGGER: users_audit_trigger ON users
-- ============================================
CREATE TRIGGER users_audit_trigger AFTER INSERT OR DELETE OR UPDATE ON users FOR EACH ROW EXECUTE FUNCTION log_user_action();

-- ============================================
-- TRIGGER: trg_update_final_bill_amount ON vendor_payment_schedule
-- ============================================
CREATE TRIGGER trg_update_final_bill_amount BEFORE INSERT OR UPDATE OF discount_amount, grr_amount, pri_amount, bill_amount ON vendor_payment_schedule FOR EACH ROW EXECUTE FUNCTION update_final_bill_amount_on_adjustment();

-- ============================================
-- TRIGGER: trg_vip_campaign_settings_updated_at ON vip_campaign_settings
-- ============================================
CREATE TRIGGER trg_vip_campaign_settings_updated_at BEFORE UPDATE ON vip_campaign_settings FOR EACH ROW EXECUTE FUNCTION set_vip_redemptions_updated_at();

-- ============================================
-- TRIGGER: trg_vip_redemptions_updated_at ON vip_redemptions
-- ============================================
CREATE TRIGGER trg_vip_redemptions_updated_at BEFORE UPDATE ON vip_redemptions FOR EACH ROW EXECUTE FUNCTION set_vip_redemptions_updated_at();

-- ============================================
-- TRIGGER: warning_main_category_timestamp_update ON warning_main_category
-- ============================================
CREATE TRIGGER warning_main_category_timestamp_update BEFORE UPDATE ON warning_main_category FOR EACH ROW EXECUTE FUNCTION update_warning_main_category_timestamp();

-- ============================================
-- TRIGGER: warning_sub_category_timestamp_update ON warning_sub_category
-- ============================================
CREATE TRIGGER warning_sub_category_timestamp_update BEFORE UPDATE ON warning_sub_category FOR EACH ROW EXECUTE FUNCTION update_warning_sub_category_timestamp();

-- ============================================
-- TRIGGER: warning_violation_timestamp_update ON warning_violation
-- ============================================
CREATE TRIGGER warning_violation_timestamp_update BEFORE UPDATE ON warning_violation FOR EACH ROW EXECUTE FUNCTION update_warning_violation_timestamp();

