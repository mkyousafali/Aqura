-- ==========================================
-- GET TABLES WITHOUT RLS PROTECTION
-- ==========================================
-- Run this to see exactly which 37 tables need RLS

SELECT 
    t.tablename as table_name,
    CASE 
        -- Critical: Customer & Order data
        WHEN t.tablename IN ('customers', 'orders', 'order_items', 'order_audit_logs', 
                              'customer_recovery_requests', 'customer_access_code_history',
                              'customer_app_media') 
        THEN '🔴 CRITICAL - Customer Data'
        
        -- Critical: Financial data
        WHEN t.tablename IN ('expense_requisitions', 'expense_scheduler', 'vendor_payment_schedule',
                              'non_approved_payment_scheduler', 'employee_fine_payments')
        THEN '🔴 CRITICAL - Financial Data'
        
        -- High: HR & Employee
        WHEN t.tablename LIKE 'hr_%' OR t.tablename LIKE 'employee_%'
        THEN '🟡 HIGH - HR/Employee Data'
        
        -- High: Tasks & Operations
        WHEN t.tablename LIKE 'task%' OR t.tablename LIKE '%task%' OR 
             t.tablename LIKE 'receiving%' OR t.tablename LIKE 'quick_%'
        THEN '🟡 HIGH - Task Management'
        
        -- Medium: Products & Offers
        WHEN t.tablename IN ('products', 'offers', 'offer_products', 'offer_bundles',
                              'flyer_products', 'flyer_offers', 'coupon_campaigns',
                              'coupon_products', 'coupon_claims')
        THEN '🟢 MEDIUM - Products/Offers'
        
        -- Medium: Configuration
        WHEN t.tablename IN ('branches', 'vendors', 'app_functions', 'product_categories',
                              'product_units', 'tax_categories', 'delivery_fee_tiers')
        THEN '🟢 MEDIUM - Configuration'
        
        ELSE '⚪ LOW - Other'
    END as priority,
    pg_size_pretty(pg_total_relation_size(quote_ident(t.tablename)::regclass)) as table_size,
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_schema = 'public' AND table_name = t.tablename) as column_count
FROM 
    pg_tables t
WHERE 
    t.schemaname = 'public'
    AND t.rowsecurity = false
    AND t.tablename NOT LIKE 'pg_%'
    AND t.tablename NOT LIKE 'sql_%'
ORDER BY 
    CASE 
        WHEN t.tablename IN ('customers', 'orders', 'order_items', 'expense_requisitions', 
                              'expense_scheduler', 'vendor_payment_schedule') THEN 1
        WHEN t.tablename LIKE 'hr_%' OR t.tablename LIKE 'employee_%' OR 
             t.tablename LIKE 'task%' OR t.tablename LIKE 'receiving%' THEN 2
        WHEN t.tablename IN ('products', 'offers', 'branches', 'vendors') THEN 3
        ELSE 4
    END,
    t.tablename;


-- ==========================================
-- SUMMARY BY PRIORITY
-- ==========================================

WITH priority_counts AS (
    SELECT 
        CASE 
            WHEN t.tablename IN ('customers', 'orders', 'order_items', 'order_audit_logs', 
                                  'customer_recovery_requests', 'expense_requisitions', 
                                  'expense_scheduler', 'vendor_payment_schedule') 
            THEN '🔴 CRITICAL'
            WHEN t.tablename LIKE 'hr_%' OR t.tablename LIKE 'employee_%' OR 
                 t.tablename LIKE 'task%' OR t.tablename LIKE 'receiving%' OR t.tablename LIKE 'quick_%'
            THEN '🟡 HIGH'
            WHEN t.tablename IN ('products', 'offers', 'offer_products', 'branches', 'vendors',
                                  'flyer_products', 'coupon_campaigns')
            THEN '🟢 MEDIUM'
            ELSE '⚪ LOW'
        END as priority
    FROM 
        pg_tables t
    WHERE 
        t.schemaname = 'public'
        AND t.rowsecurity = false
        AND t.tablename NOT LIKE 'pg_%'
        AND t.tablename NOT LIKE 'sql_%'
)
SELECT 
    priority,
    COUNT(*) as table_count
FROM priority_counts
GROUP BY priority
ORDER BY 
    CASE 
        WHEN priority = '🔴 CRITICAL' THEN 1
        WHEN priority = '🟡 HIGH' THEN 2
        WHEN priority = '🟢 MEDIUM' THEN 3
        ELSE 4
    END;
