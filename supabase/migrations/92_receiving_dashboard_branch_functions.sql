-- Migration: Add branch-specific dashboard functions for receiving
-- File: 92_receiving_dashboard_branch_functions.sql
-- Description: Creates functions to count receiving records filtered by branch

BEGIN;

-- Function to count bills without original by branch
CREATE OR REPLACE FUNCTION count_bills_without_original_by_branch(branch_id_param BIGINT DEFAULT NULL)
RETURNS INTEGER AS $$
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
$$ LANGUAGE plpgsql;

-- Function to count bills without ERP reference by branch
CREATE OR REPLACE FUNCTION count_bills_without_erp_reference_by_branch(branch_id_param BIGINT DEFAULT NULL)
RETURNS INTEGER AS $$
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
$$ LANGUAGE plpgsql;

-- Function to count bills without PR Excel by branch
CREATE OR REPLACE FUNCTION count_bills_without_pr_excel_by_branch(branch_id_param BIGINT DEFAULT NULL)
RETURNS INTEGER AS $$
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
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON FUNCTION count_bills_without_original_by_branch(BIGINT) IS 
'Counts receiving records without original bill file, optionally filtered by branch';

COMMENT ON FUNCTION count_bills_without_erp_reference_by_branch(BIGINT) IS 
'Counts receiving records without ERP purchase invoice reference, optionally filtered by branch';

COMMENT ON FUNCTION count_bills_without_pr_excel_by_branch(BIGINT) IS 
'Counts receiving records without PR Excel file, optionally filtered by branch';

COMMIT;

-- Verification queries
SELECT 'Branch-specific dashboard functions created successfully' AS status;

-- Test the functions
SELECT 
    'count_bills_without_original_by_branch' as function_name,
    count_bills_without_original_by_branch() as all_branches,
    count_bills_without_original_by_branch(1) as branch_1
UNION ALL
SELECT 
    'count_bills_without_erp_reference_by_branch' as function_name,
    count_bills_without_erp_reference_by_branch() as all_branches,
    count_bills_without_erp_reference_by_branch(1) as branch_1
UNION ALL
SELECT 
    'count_bills_without_pr_excel_by_branch' as function_name,
    count_bills_without_pr_excel_by_branch() as all_branches,
    count_bills_without_pr_excel_by_branch(1) as branch_1;